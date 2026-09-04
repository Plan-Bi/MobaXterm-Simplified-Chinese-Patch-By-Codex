"""Repack MobaXterm's official RCData resources after our own translations.

The existing Chinese patch preserves each original Delphi DFM string field's
length. VCL consequently measures blank padding after shortened GBK labels.
This tool removes only NUL padding from translated DFM Caption/Hint/Text-like
properties, then rebuilds the PE resource payload and its data-entry RVAs.
It never reads a third-party executable.
"""

from __future__ import annotations

import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "MobaXterm_Personal_26.4_zh-CN.exe"
DESTINATION = ROOT / "MobaXterm_Personal_26.4_zh-CN_self-rebuilt.exe"

STRING_PROPERTIES = {b"Caption", b"HelpKeyword", b"Hint", b"Text", b"Title"}
RT_RCDATA = 10


def pe_layout(data: bytearray) -> tuple[int, int, int, int, int]:
    pe_offset = struct.unpack_from("<I", data, 0x3C)[0]
    optional_offset = pe_offset + 24
    section_count = struct.unpack_from("<H", data, pe_offset + 6)[0]
    optional_size = struct.unpack_from("<H", data, pe_offset + 20)[0]
    section_offset = optional_offset + optional_size
    for index in range(section_count):
        entry = section_offset + index * 40
        if data[entry : entry + 8].rstrip(b"\0") == b".rsrc":
            virtual_size, virtual_address, raw_size, raw_offset = struct.unpack_from(
                "<IIII", data, entry + 8
            )
            return optional_offset, entry, virtual_address, raw_offset, raw_size
    raise RuntimeError("The input has no .rsrc section")


def resource_leaves(data: bytearray, rsrc_offset: int) -> list[tuple[int, int, int, int]]:
    """Return (type, data_entry_offset, raw_offset, size) for every resource leaf."""

    leaves: list[tuple[int, int, int, int]] = []

    def walk(relative: int, resource_type: int | None) -> None:
        directory = rsrc_offset + relative
        named, numeric = struct.unpack_from("<HH", data, directory + 12)
        for index in range(named + numeric):
            entry = directory + 16 + index * 8
            name_or_id, target = struct.unpack_from("<II", data, entry)
            current_type = resource_type
            if relative == 0 and not (name_or_id & 0x80000000):
                current_type = name_or_id
            if target & 0x80000000:
                walk(target & 0x7FFFFFFF, current_type)
                continue
            data_entry = rsrc_offset + target
            data_rva, size = struct.unpack_from("<II", data, data_entry)
            leaves.append((current_type or -1, data_entry, data_rva, size))

    walk(0, None)
    return leaves


def compact_dfm_strings(blob: bytes) -> tuple[bytes, int]:
    """Remove only NUL padding from well-formed Delphi vaString UI properties."""

    output = bytearray()
    cursor = 0
    removed = 0
    limit = len(blob)
    while cursor < limit:
        property_length = blob[cursor]
        candidate_end = cursor + 1 + property_length + 2
        if (
            4 <= property_length <= 64
            and candidate_end <= limit
            and blob[cursor + 1 : cursor + 1 + property_length].split(b".")[-1]
            in STRING_PROPERTIES
            and blob[cursor + 1 + property_length] == 0x06
        ):
            value_length = blob[cursor + 2 + property_length]
            value_start = cursor + 3 + property_length
            value_end = value_start + value_length
            if value_end <= limit:
                value = blob[value_start:value_end]
                nul = value.find(b"\0")
                if nul >= 0:
                    output.extend(blob[cursor : cursor + 2 + property_length])
                    output.append(nul)
                    output.extend(value[:nul])
                    removed += value_length - nul
                    cursor = value_end
                    continue
        output.append(blob[cursor])
        cursor += 1
    return bytes(output), removed


def align(value: int, boundary: int = 4) -> int:
    return (value + boundary - 1) & -boundary


def main() -> None:
    if not SOURCE.is_file():
        raise FileNotFoundError(SOURCE)
    data = bytearray(SOURCE.read_bytes())
    optional, section_entry, rsrc_rva, rsrc_offset, rsrc_size = pe_layout(data)
    leaves = resource_leaves(data, rsrc_offset)
    if len(leaves) != 220:
        raise RuntimeError(f"Unexpected resource count: {len(leaves)}")

    # The resource tree/data-entry table precedes every resource blob.
    blob_start = min(data_rva - rsrc_rva for _, _, data_rva, _ in leaves)
    if blob_start <= 0 or blob_start >= rsrc_size:
        raise RuntimeError("Invalid resource payload boundary")

    packed: list[tuple[int, bytes]] = []
    compacted_resources = 0
    removed_bytes = 0
    for resource_type, data_entry, data_rva, size in sorted(leaves, key=lambda item: item[2]):
        raw = rsrc_offset + data_rva - rsrc_rva
        blob = bytes(data[raw : raw + size])
        if resource_type == RT_RCDATA and blob.startswith(b"TPF0"):
            blob, removed = compact_dfm_strings(blob)
            if removed:
                compacted_resources += 1
                removed_bytes += removed
        packed.append((data_entry, blob))

    rebuilt = bytearray(data[rsrc_offset : rsrc_offset + blob_start])
    for data_entry, blob in packed:
        relative = align(len(rebuilt))
        rebuilt.extend(b"\0" * (relative - len(rebuilt)))
        rebuilt.extend(blob)
        struct.pack_into("<II", rebuilt, data_entry - rsrc_offset, rsrc_rva + relative, len(blob))

    final_size = align(len(rebuilt), 0x200)
    rebuilt.extend(b"\0" * (final_size - len(rebuilt)))
    if final_size > rsrc_size:
        raise RuntimeError("Rebuilt resource section unexpectedly grew")

    data[rsrc_offset : rsrc_offset + final_size] = rebuilt
    # Keep the PE file size stable but make all bytes after the new section inert.
    data[rsrc_offset + final_size : rsrc_offset + rsrc_size] = b"\0" * (rsrc_size - final_size)
    struct.pack_into("<I", data, section_entry + 8, len(rebuilt))
    struct.pack_into("<I", data, section_entry + 16, final_size)
    # IMAGE_DIRECTORY_ENTRY_RESOURCE size lives at optional header + 96 + 16.
    struct.pack_into("<I", data, optional + 96 + 16 + 4, len(rebuilt))
    DESTINATION.write_bytes(data)
    print(f"Output: {DESTINATION}")
    print(f"Resources compacted: {compacted_resources}; removed padding bytes: {removed_bytes}")
    print(f".rsrc: 0x{rsrc_size:X} -> 0x{final_size:X}")


if __name__ == "__main__":
    main()

