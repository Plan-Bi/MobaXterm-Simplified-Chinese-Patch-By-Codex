# MobaXterm 26.4 简体中文汉化 / Simplified Chinese Patch

本项目以官方 MobaXterm 26.4 Personal 便携版为基础，提供两种汉化结果。原版 EXE 保持不覆盖，便于校验和恢复。

## 文件说明

| 文件 | 用途 |
| --- | --- |
| `MobaXterm_Personal_26.4.exe` | 官方原版基线。构建脚本会校验 SHA-256，禁止误用其他版本。 |
| `MobaXterm_Personal_26.4_zh-CN.exe` | 基础汉化版：在官方文件中替换 Delphi/VCL 的 Caption、Hint、Text 等资源，以及少量运行时字符串。 |
| `MobaXterm_Personal_26.4_zh-CN_self-rebuilt.exe` | `.rsrc` 重建版：以基础汉化版为输入，重新排列资源数据并移除中文字段的零填充，改善首页和右键菜单的自动宽度计算。 |
| `Build-MobaXterm-ZH-CN.ps1` | 从官方原版重新生成基础汉化版。 |
| `rebuild_official_resources.py` | 从基础汉化版重新生成 `.rsrc` 重建版。仅使用本项目文件，不读取第三方 EXE。 |
| `captions.csv` / `hints.csv` | 汉化扫描得到的 Caption 和 Hint 清单，供审阅和扩展翻译。 |
| `CygUtils.plugin` / `CygUtils64.plugin` | MobaXterm 便携版运行所需的官方组件。 |

## 汉化原理

### 基础汉化

`Build-MobaXterm-ZH-CN.ps1` 首先验证官方原版 SHA-256，然后复制到新文件。脚本解析 PE 的 `.rsrc` 和 `CODE` 区段，在 Delphi 二进制 DFM 资源中定位 `Caption`、`Hint`、`Text`、`Title` 等字符串属性，并使用 GBK 编码写入中文；少量界面运行时字符串位于 `CODE` 区段，也按固定长度安全替换。原版文件不会被修改。

### `.rsrc` 重建

VCL 菜单会根据字符串字段长度自动计算菜单宽度。若只在原字段中写入较短中文并补零，可能留下异常空白。因此 `rebuild_official_resources.py` 枚举官方资源树中的 RCData/DFM 资源，删除已汉化字段末尾的零填充，重新排列资源数据，并同步更新资源数据目录、节大小和每个资源的 RVA。它不新增代码段、不改变导入表，也不使用第三方版本的资源或二进制。

## 构建

环境：Windows PowerShell 7、Python 3.10+。在项目目录运行：

```powershell
./Build-MobaXterm-ZH-CN.ps1 -Force
python ./rebuild_official_resources.py
```

如需指定输入或输出，可使用 PowerShell 脚本的 `-Source`、`-Destination` 参数。构建后应重新计算 SHA-256，并在隔离环境中启动测试。

## 安全与签名说明

- 官方原版的 SHA-256：`C581F9313C56C4B848D652420A04E3FB45CEBBE3111CE02BB8A92343F01D87E4`。
- 基础汉化版的 SHA-256：`E60F1633F3EA3A779B694D78914CAC59607496531B9F9205DAE679838BE6671B`。
- `.rsrc` 重建版的 SHA-256：构建后以命令输出为准。
- 任何修改过的 EXE 都不能保留 Mobatek 的原始数字签名；Windows 显示“签名无效/未签名”是预期结果。
- 项目不包含、也不依赖来自破解网站的 EXE、`.movehcs` 或附加代码段。发布前请自行核对文件哈希，并保留官方原版作为恢复备份。

## 再分发注意事项

本项目只说明汉化脚本和资源重建脚本的处理方法，不授予 Mobatek 官方 EXE、`CygUtils.plugin` 或 `CygUtils64.plugin` 的再分发许可。这些文件是否可以上传到 GitHub，应以 Mobatek 的最终用户许可和 GitHub 的适用政策为准。若无法确认许可，建议仓库只发布脚本、翻译表和说明，让使用者自行放入合法取得的官方文件后构建。

## 翻译范围

目前覆盖首页、左侧栏、工具栏、菜单和提示、会话编辑器、服务器管理、终端操作、MultiExec、常用文件操作及常用设置。`SSH`、`Telnet`、`RDP`、`Serial` 等协议名称保留英文；游戏内容暂不翻译；少量诊断信息和低频对话框仍可能显示英文。

## 参考来源与致谢

- MobaXterm 23.0 简体中文项目：[RipplePiam/MobaXterm-Chinese-Simplified](https://github.com/RipplePiam/MobaXterm-Chinese-Simplified)。本版本参考其部分中文术语、界面译法和翻译组织方式。
- 52 破解相关资料：[作者主页](https://www.52pojie.cn/?1222738)。本版本参考其中关于 `.rsrc` 界面资源重建、资源重排和菜单布局处理的技术思路。

以上内容仅作为翻译和技术研究参考。本版本没有直接移植上述项目或文章中的 EXE、插件、代码段、`.movehcs` 文件或其他二进制；26.4 汉化结果由官方原版和本目录脚本独立构建。

## English summary

This repository contains a self-built Chinese patch for the official MobaXterm 26.4 executable. The base patch edits only identified Delphi/VCL strings and selected runtime messages. The optional resource-rebuild pass repacks our own RCData/DFM resources to remove NUL padding that can distort VCL menu measurements. No third-party executable, code section, custom section, or `.movehcs` data is used. Modified executables are unsigned by design; keep and verify the vendor-signed original before running any patched build.

