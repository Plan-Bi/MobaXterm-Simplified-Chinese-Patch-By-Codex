[CmdletBinding()]
param(
    [string]$Source = (Join-Path $PSScriptRoot 'MobaXterm_Personal_26.4.exe'),
    [string]$Destination = (Join-Path $PSScriptRoot 'MobaXterm_Personal_26.4_zh-CN.exe'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$ExpectedSourceHash = 'C581F9313C56C4B848D652420A04E3FB45CEBBE3111CE02BB8A92343F01D87E4'

function Get-GbkEncoding {
    try {
        return [System.Text.Encoding]::GetEncoding(936)
    }
    catch {
        [System.Text.Encoding]::RegisterProvider([System.Text.CodePagesEncodingProvider]::Instance)
        return [System.Text.Encoding]::GetEncoding(936)
    }
}

function Test-BytesAt {
    param([byte[]]$Bytes, [int]$Offset, [byte[]]$Needle)

    if ($Offset -lt 0 -or $Offset + $Needle.Length -gt $Bytes.Length) {
        return $false
    }
    for ($i = 0; $i -lt $Needle.Length; $i++) {
        if ($Bytes[$Offset + $i] -ne $Needle[$i]) {
            return $false
        }
    }
    return $true
}

function Get-ResourceSection {
    param([byte[]]$Bytes)

    $peOffset = [BitConverter]::ToInt32($Bytes, 0x3C)
    $sectionCount = [BitConverter]::ToUInt16($Bytes, $peOffset + 6)
    $optionalHeaderSize = [BitConverter]::ToUInt16($Bytes, $peOffset + 20)
    $sectionOffset = $peOffset + 24 + $optionalHeaderSize

    for ($i = 0; $i -lt $sectionCount; $i++) {
        $entry = $sectionOffset + (40 * $i)
        $name = [Text.Encoding]::ASCII.GetString($Bytes, $entry, 8).Trim([char]0)
        if ($name -eq '.rsrc') {
            return [pscustomobject]@{
                VirtualAddress = [BitConverter]::ToUInt32($Bytes, $entry + 12)
                RawOffset = [BitConverter]::ToUInt32($Bytes, $entry + 20)
                RawSize = [BitConverter]::ToUInt32($Bytes, $entry + 16)
            }
        }
    }
    throw 'The executable has no .rsrc section.'
}

function Get-CodeSection {
    param([byte[]]$Bytes)

    $peOffset = [BitConverter]::ToInt32($Bytes, 0x3C)
    $sectionCount = [BitConverter]::ToUInt16($Bytes, $peOffset + 6)
    $optionalHeaderSize = [BitConverter]::ToUInt16($Bytes, $peOffset + 20)
    $sectionOffset = $peOffset + 24 + $optionalHeaderSize

    for ($i = 0; $i -lt $sectionCount; $i++) {
        $entry = $sectionOffset + (40 * $i)
        $name = [Text.Encoding]::ASCII.GetString($Bytes, $entry, 8).Trim([char]0)
        if ($name -eq 'CODE') {
            return [pscustomobject]@{
                RawOffset = [BitConverter]::ToUInt32($Bytes, $entry + 20)
                RawSize = [BitConverter]::ToUInt32($Bytes, $entry + 16)
            }
        }
    }
    throw 'The executable has no CODE section.'
}

$sourcePath = (Resolve-Path -LiteralPath $Source).Path
$sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
if ($sourceHash -ne $ExpectedSourceHash) {
    throw "Unsupported source file. Expected SHA-256: $ExpectedSourceHash; actual: $sourceHash"
}

$destinationPath = [IO.Path]::GetFullPath($Destination)
if ((Test-Path -LiteralPath $destinationPath) -and -not $Force) {
    throw "Destination already exists: $destinationPath. Use -Force only to replace a previous generated copy."
}

# These are Delphi DFM UI values. Every translation must fit the original ANSI byte field.
$Translations = [ordered]@{
    'Show Terminal' = '显示终端'
    'Show popup terminal' = '显示弹出终端'
    'Sessions' = '会话夹'
    'Sessions ' = '会话'
    'Session' = '会话'
    'User sessions' = '我的会话'
    'New Session' = '新建会话'
    'Manage my sessions' = '管理我的会话'
    'Recent sessions' = '最近会话'
    'Start X server' = '启动 X 服务器'
    'MobaTextEditor' = 'Moba文本编辑器'
    'TextEdit' = '文本编辑'
    'Documentation' = '文档'
    'About MobaXterm' = '关于 MobaXterm'
    'Exit MobaXterm' = '退出 MobaXterm'
    'Settings' = '设置'
    'Terminal' = '终端'
    'View' = '查看'
    'Tools' = '工具'
    'Tools ' = '工具'
    'Help' = '帮助'
    'Split' = '拆分'
    'MultiExec' = '多终端'
    'New tab' = '新标签'
    'New terminal' = '新建终端'
    'Sidebar' = '侧边栏'
    'Fullscreen' = '全屏'
    'Zoom out' = '缩小'
    'Zoom in' = '放大'
    'Detach' = '分离'
    'Cycle' = '切换'
    'Tunneling' = '隧道'
    'Servers' = '服务器'
    'Home' = '主页'
    'Macro' = '宏'
    'Shortkeys' = '快捷键'
    'Duplicate' = '复制'
    'Find' = '查找'
    'Set title' = '设置标题'
    'Close' = '关闭'
    'Packages' = '软件包'
    'X server' = 'X 服务器'
    'Exit' = '退出'
    'Configuration' = '配置'
    'Keyboard shortcuts' = '键盘快捷键'
    'Key mapping' = '按键映射'
    'Import configuration' = '导入配置'
    'Export configuration' = '导出配置'
    'Reset configuration' = '重置配置'
    'Manage shared sessions' = '管理共享会话'
    'Edit session presets' = '编辑会话预设'
    'General' = '常规'
    'Display' = '显示'
    'Toolbar' = '工具栏'
    'Misc' = '其他'
    'MobaXterm Configuration' = 'MobaXterm 配置'
    'Terminal home directory: ' = '终端主目录：'
    'Terminal root (/) directory: ' = '终端根目录：'
    'Default text editor program: ' = '默认文本编辑器：'
    'Windows right-click menu entries' = 'Windows 右键菜单项'
    'MobaXterm keyboard shortcuts' = 'MobaXterm 键盘快捷键'
    'MobaXterm passwords management' = 'MobaXterm 密码管理'
    'Manage my shared sessions' = '管理我的共享会话'
    'Edit my sessions presets' = '编辑我的会话预设'
    'Automatically backup MobaXterm configuration file' = '自动备份 MobaXterm 配置文件'
    'Available buttons:' = '可用按钮：'
    'Toolbar buttons:' = '工具栏按钮：'
    'Button name' = '按钮名称'
    'Root (/) directory location: ' = '根目录位置：'
    'Home directory location: ' = '主目录位置：'
    'Configuration file location: ' = '配置文件位置：'
    'Default user profile folder: ' = '默认用户配置文件夹：'
    'Local shell settings' = '本地 Shell 设置'
    'SSH settings' = 'SSH 设置'
    'X server settings' = 'X 服务器设置'
    'Change the SSH-browser position' = '更改 SSH 浏览器位置'
    'List of listening DISPLAYS' = '正在监听的 DISPLAY 列表'
    'MobaXterm X server is running ' = 'MobaXterm X 服务器正在运行'
    'More options' = '更多选项'
    'Toggle dark / light theme' = '切换深色/浅色主题'
    'Show tab list' = '显示标签列表'
    'Compact menu' = '紧凑菜单'
    'Pin sidebar' = '固定侧边栏'
    'Browse Home folder' = '浏览主目录'
    'Browse "/" folder' = '浏览“/”目录'
    'Select the MobaXterm items shown in the right-click menu of Windows explorer' = '选择 Windows 资源管理器右键菜单中的 MobaXterm 项目'
    'Define MobaXterm hotkeys' = '设置 MobaXterm 快捷键'
    'Point to sessions files shared by your team members in order to easily share your sessions definitions with colleagues' = '指定团队成员共享的会话文件，方便与同事共享会话定义'
    'Edit the default values for each new session' = '编辑新建会话的默认值'
    'Toggle absolute or relative path' = '切换绝对路径或相对路径'
    'Show "Sessions" tab' = '显示“会话”标签'
    'Show "Tools" tab' = '显示“工具”标签'
    'Show "Macros" tab' = '显示“宏”标签'
    'Show "Tabs" tab' = '标签'
    'Show "Log" tab' = '日志'
    'Macros' = '宏'
    'Macros ' = '宏'
    'Sftp ' = 'SFTP'
    'Record new macro' = '录制新宏'
    'Manage saved macros' = '管理已保存宏'
    'Saved macros' = '已保存的宏'
    '  Quick connect...' = '  快速连接...'
    'Create new empty macro' = '新建空白宏'
    'Rename macro' = '重命名宏'
    'Edit macro' = '编辑宏'
    'Delete macro' = '删除宏'
    'Assign hotkey' = '分配快捷键'
    'Use single-click to run macros' = '单击运行宏'
    'Check for updates' = '检查更新'
    'View MobaXterm log file' = '查看 MobaXterm 日志'
    'Plugin creator' = '插件创建器'
    'Open' = '打开'
    'Open with...' = '打开方式...'
    'Open with default text editor' = '用默认文本编辑器打开'
    'Compare text files' = '比较文本文件'
    'Download' = '下载'
    'Delete' = '删除'
    'Rename' = '重命名'
    'Copy file path' = '复制文件路径'
    'Properties' = '属性'
    'Permissions' = '权限'
    'Parent directory' = '上级目录'
    'New directory' = '新建文件夹'
    'New empty file' = '新建空文件'
    'Refresh current folder' = '刷新当前文件夹'
    'Upload to current folder' = '上传到当前文件夹'
    'SFTP session' = 'SFTP 会话'
    'Ping host' = 'Ping 主机'
    'New folder' = '新建文件夹'
    'Edit' = '编辑'
    'Save' = '保存'
    'Copy' = '复制'
    'Paste' = '粘贴'
    'Apply' = '应用'
    'Cancel' = '取消'
    'Yes' = '是'
    'No' = '否'
    'OK' = '确定'
    'Back' = '返回'
    'Start' = '开始'
    'Stop' = '停止'
    'Configure' = '配置'
    'Connect as...' = '连接身份...'
    'Save to file' = '保存到文件'
    'Start local terminal' = '启动本地终端'
    'Start a new remote session' = '启动新的远程会话'
    'Show MobaXterm help section' = '显示 MobaXterm 帮助'
    'Edit MobaXterm configuration' = '编辑 MobaXterm 配置'
    'Toolbars, menus and buttons options' = '工具栏、菜单和按钮选项'
    'Send commands to all terminals at once' = '向所有终端同时发送命令'
    'Servers management' = '服务器管理'
    'TFTP server' = 'TFTP 服务器'
    'FTP server' = 'FTP 服务器'
    'HTTP server' = 'HTTP 服务器'
    'SSH/SFTP server' = 'SSH/SFTP 服务器'
    'Telnet server' = 'Telnet 服务器'
    'NFS server' = 'NFS 服务器'
    'VNC server' = 'VNC 服务器'
    'Cron server' = 'Cron 服务器'
    'Iperf server' = 'Iperf服务'
    'TFTP server settings' = 'TFTP 服务器设置'
    'FTP server settings' = 'FTP 服务器设置'
    'HTTP server settings' = 'HTTP 服务器设置'
    'SSH/SFTP server settings' = 'SSH/SFTP 服务器设置'
    'Telnet server settings' = 'Telnet 服务器设置'
    'NFS server settings (experimental)' = 'NFS 服务器设置（实验性）'
    'VNC server settings' = 'VNC 服务器设置'
    'Cron server settings' = 'Cron 服务器设置'
    'IPERF server settings' = 'IPERF 服务器设置'
    'This is a simple SSH/SFTP server: you can only log on using your current Windows login () and the associated password.' = '这是一个简单的 SSH/SFTP 服务器：只能使用当前 Windows 登录账户及其密码登录。'
    'For a complete SSH server for Windows, please download MobaSSH.' = '如需完整的 Windows SSH 服务器，请下载 MobaSSH。'
    'Root directory' = '根目录'
    'Show message after successful download' = '下载成功后显示消息'
    'Show message after successful upload' = '上传成功后显示消息'
    'Listening port' = '监听端口'
    'TFTP buffer size' = 'TFTP 缓冲大小'
    'Bytes' = '字节'
    'Stop server after' = '延时停止'
    'seconds' = '秒'
    'Server output' = '输出'
    'Allow anonymous connections' = '允许匿名连接'
    'Implicit SSL encryption' = '隐式 SSL 加密'
    'Use UTF-8 charset' = '使用 UTF-8 字符集'
    'Prompt me before accepting any incoming connection' = '接受传入连接前提示'
    'Menu and buttons toolbars' = '菜单和按钮工具栏'
    'Show menu and buttons bars' = '显示菜单和按钮栏'
    'Buttons toolbar' = '按钮工具栏'
    'Customize buttons' = '自定义按钮'
    'Toggle sidebar titles' = '切换侧边栏标题'
    'Tabbar' = '标签栏'
    'Show/hide vertical tabs' = '显示/隐藏竖向标签'
    'Terminal splitting options' = '终端拆分选项'
    'Start a previously saved session' = '启动已保存的会话'
    'Open a new terminal in a tab' = '在标签页中打开新终端'
    'Show the session manager (sidebar)' = '显示会话管理器（侧边栏）'
    'Decrease the terminal font size' = '减小终端字体大小'
    'Increase the terminal font size' = '增大终端字体大小'
    'Start MobaSSHTunnel - a graphical port forwarding builder' = '启动 MobaSSHTunnel 图形端口转发工具'
    'Network services' = '网络服务'
    'Record macro' = '录制宏'
    'Find some text in current terminal' = '在当前终端中查找文本'
    'Save terminal text' = '保存终端文本'
    'Print terminal text' = '打印终端文本'
    'Find in terminal' = '在终端中查找'
    'Find next' = '查找下个'
    'Duplicate current tab' = '复制当前标签'
    'Write commands on all terminals' = '向所有终端发送命令'
    'Quit' = '退出'
    'Terminal zoom' = '终端放大'
    'Terminal unzoom' = '终端缩小'
    'Save terminal output' = '保存终端输出'
    'Print terminal output' = '打印终端输出'
    'Paste to all terminals' = '粘贴到所有终端'
    'List open network ports' = '列出已开放网络端口'
    'X11 window with Fvwm2 window manager' = 'Fvwm2 X11 窗口'
    'X11 window with Twm window manager' = 'Twm X11 窗口'
    'X11 tab with DWM window manager' = 'DWM X11 标签页'
    'MobApt package manager (experimental)' = 'MobApt 软件包管理器（实验性）'
    'X server is stopped' = 'X 服务器已停止'
    'Modify Home settings' = '修改首页设置'
    'Recover previous sessions' = '恢复之前的会话'
    'Select your favorite theme' = '选择喜欢的主题'
    'Light' = '浅色'
    'Dark' = '深色'
    'Options' = '选项'
    'Disconnect' = '断开连接'
    'Refresh' = '刷新'
    'View-only' = '仅查看'
    'Respect ratio' = '保持比例'
    'Reset size' = '重置大小'
    'Shared clipboard' = '共享剪贴板'
    'Record' = '录制'
    'Session settings' = '会话设置'
    'Choose a session type...' = '选择会话类型...'
    'Select directory' = '选择目录'
    'Select color' = '选择颜色'
    'Folder edition' = '文件夹编辑'
    'Import sessions' = '导入会话'
    'Hardcoded sessions' = '内置会话'
    'Embedded plugins' = '内置插件'
    'Browse' = '浏览'
    'Current custom logo' = '当前自定义徽标'
    'Default logo' = '默认徽标'
    'Logo' = '徽标'
    'Banner' = '欢迎信息'
    'Profile' = '配置文件'
    'Save to file as...' = '另存为...'
    'Load from file' = '从文件加载'
    'Advanced SSH settings' = '高级 SSH 设置'
    'Basic SSH settings' = '基本 SSH 设置'
    'SSH session' = 'SSH 会话'
    'Session Icon' = '会话图标'
    'Create a desktop shortcut to this session' = '为此会话创建桌面快捷方式'
    'Lock terminal title' = '锁定终端标题'
    'Customize tab color' = '自定义标签颜色'
    'Specify username' = '指定用户名'
    'Reset default SSH settings' = '重置默认 SSH 设置'
    'Shared sessions management' = '共享会话管理'
    'Folder name' = '文件夹名'
    'minutes' = '分钟'
    'Delete entry' = '删除条目'
    'Edit entry' = '编辑条目'
    'Add new entry' = '添加条目'
    'Select a smart card certificate' = '选择智能卡证书'
    'Refresh list' = '刷新列表'
    'Certificates store' = '证书存储'
    'Copy public key' = '复制公钥'
    'Copy Fingerprint' = '复制指纹'
    'Create certificate' = '创建证书'
    'Delete certificate' = '删除证书'
    'Advanced SSH protocol settings' = '高级 SSH 协议设置'
    'Allow agent forwarding' = '允许代理转发'
    'Restore default settings' = '恢复默认设置'
    'Network scan' = '网络扫描'
    'Network status' = '网络状态'
    'Local terminal' = '本地终端'
    'Remote monitoring' = '远程监控'
    'Terminal settings' = '终端设置'
    'Color settings' = '颜色设置'
    'Font settings' = '字体设置'
    'Expert settings' = '专家设置'
    'Network settings' = '网络设置'
    'Bookmark settings' = '书签设置'
    'SSH' = 'SSH'
    'Telnet' = 'Telnet'
    'RDP' = 'RDP'
    'VNC' = 'VNC'
    'FTP' = 'FTP'
    'SFTP' = 'SFTP'
    'Shell' = 'Shell'
    'File' = '文件'
    'Browser' = '浏览器'
    'WSL' = 'WSL'
    'System' = '系统'
    'Office' = '办公'
    'Network' = '网络'
    'Remote sessions' = '远程会话'
    'MobApt packages manager (experimental)' = 'MobApt 软件包管理器（实验性）'
    'X11 tab with Dwm' = 'Dwm X11 标签页'
    'X11 window with Fvwm' = 'Fvwm X11 窗口'
    'X11 window with Twm' = 'Twm X11 窗口'
    'List hardware devices' = '列出硬件设备'
    'List installed software' = '列出已安装软件'
    'List running processes' = '列出运行中的进程'
    'Command Prompt (admin)' = '命令提示符（管理员）'
    'Windows Powershell (admin)' = 'PowerShell（管理员）'
    'Ascii table' = 'ASCII 表'
    'MobaSSHTunnel (port forwarding)' = 'MobaSSHTunnel（端口转发）'
    'MobaKeyGen (SSH key generator)' = 'MobaKeyGen（SSH 密钥生成器）'
    'Wake On Lan' = '网络唤醒'
    'Network scanner' = '网络扫描器'
    'Ports scanner' = '端口扫描器'
    'Network packets capture' = '网络数据包捕获'
    'SSH (Secure shell)' = 'SSH（安全外壳）'
    'XDMCP (Remote Unix Desktop)' = 'XDMCP（远程 Unix 桌面）'
    'MobaRDP (Terminal Service)' = 'MobaRDP（终端服务）'
    'MobaVNC (VNC client)' = 'MobaVNC（客户端）'
    'MobaFTP (FTP client)' = 'MobaFTP（客户端）'
    'MobaSFTP (SFTP client)' = 'MobaSFTP（客户端）'
    'Microcom (Serial connection)' = 'Microcom（串口连接）'
    'Filter sessions' = '筛选会话'
    'Paste in terminal' = '粘贴到终端'
    'Clear saved sessions' = '清除已保存会话'
    'Edit session' = '编辑会话'
    'Delete session' = '删除会话'
    'Duplicate session' = '复制会话'
    'Rename session' = '重命名会话'
    'Edit folder' = '编辑文件夹'
    'Delete folder' = '删除文件夹'
    'Import sessions into this folder' = '将会话导入此文件夹'
    'Export sessions from this folder' = '从此文件夹导出会话'
    'Execute' = '执行'
    'Import sessions from file' = '从文件导入会话'
    'Export all sessions to file' = '将所有会话导出到文件'
    'Import sessions from third-party programs' = '从第三方导入会话'
    'Generate HTML web page' = '生成 HTML'
    'Import WSL sessions' = '导入 WSL'
    'Import External Bash sessions' = '导入外部 Bash'
    'Import PuTTY sessions' = '导入 PuTTY'
    'Import PuTTYCM sessions' = '导入 PuTTYCM'
    'Import SuperPuTTY sessions' = '导入 SuperPuTTY'
    'Import MRemote sessions' = '导入 MRemote'
    'Import Exceed sessions' = '导入 Exceed 会话'
    'Import SCRT sessions' = '导入 SCRT 会话'
    'Import RDM sessions' = '导入 RDM 会话'
    'Import sessions from a CSV file' = '从 CSV 导入'
    'Duplicate macro' = '复制宏'
    'Execute macro' = '执行宏'
    'Import macros' = '导入宏'
    'Export macros' = '导出宏'
    'Enter the MAC address of the server:' = '请输入服务器的 MAC 地址：'
    'Open with default program...' = '用默认程序打开...'
    'Copy file path to terminal (Middle mouse click)' = '将文件路径复制到终端（鼠标中键点击）'
    'SSH-browser position: sidebar' = 'SSH 浏览器位置：侧边栏'
    'SSH-browser position: right' = 'SSH 浏览器位置：右侧'
    'SSH-browser position: left' = 'SSH 浏览器位置：左侧'
    'SSH-browser position: bottom' = 'SSH 浏览器位置：底部'
    'SSH-browser position: top' = 'SSH 浏览器位置：顶部'
    'Save log file' = '保存日志文件'
    'Copy selected line' = '复制选中行'
    'Show more information about these options' = '显示这些选项的更多信息'
    ('Record a new graphic session macro (experimental)' + "`r`n" + '(keyboard and mouse events inside any session will be recorded)') = ('录制新的图形会话宏（实验性）' + "`r`n" + '（将录制会话中的键盘和鼠标操作）')
    ('Record a new standard macro' + "`r`n" + '(eveything that I type inside terminal-based sessions will be recorded)') = ('录制新的标准宏' + "`r`n" + '（将录制终端会话中的所有输入）')
    ('Record a new MobaXterm macro (experimental)' + "`r`n" + '(keyboard and mouse events inside MobaXterm will be recorded)') = ('录制新的 MobaXterm 宏（实验性）' + "`r`n" + '（将录制 MobaXterm 中的键盘和鼠标操作）')
    ('Record a new desktop macro (experimental)' + "`r`n" + '(keyboard and mouse events in the whole desktop will be recorded)') = ('录制新的桌面宏（实验性）' + "`r`n" + '（将录制整个桌面的键盘和鼠标操作）')
    'Open new tab' = '打开新标签'
    'Close current tab' = '关闭当前标签'
    'Go to previous tab' = '转到上一个标签'
    'Go to next tab' = '转到下一个标签'
    'Cycle through tabs' = '循环切换标签'
    'Reverse cycle' = '反向切换'
    'Set tab title' = '设置标签标题'
    'Detach tab' = '分离标签'
    'Re-attach tab' = '重新附加标签'
    'Rename tab' = '重命名标签'
    'Set tab color' = '设置标签颜色'
    'Close tab' = '关闭标签'
    'Close all tabs' = '关闭所有标签'
    'Close all tabs to the left' = '关闭左侧所有标签'
    'Close all tabs to the right' = '关闭右侧所有标签'
    'Close all inactive tabs' = '关闭所有非活动标签'
    'Close all except this tab' = '关闭其他所有标签'
    'Single terminal mode' = '单终端模式'
    '2 terminals mode (horizontal split)' = '双终端模式（水平拆分）'
    '2 terminals mode (vertical split)' = '双终端模式（垂直拆分）'
    '4 terminals mode' = '四终端模式'
    'Compact mode' = '紧凑模式'
    'Fullscreen mode' = '全屏模式'
    'Show menu bar' = '显示菜单栏'
    'Show buttons bar' = '显示按钮栏'
    'Show both' = '全部显示'
    'Small buttons' = '小按钮'
    'Standard buttons' = '标准按钮'
    'Standard buttons with captions' = '带文字的标准按钮'
    'Show/hide sidebar' = '显示/隐藏侧边栏'
    'Put sidebar on the left' = '将侧边栏置于左侧'
    'Put sidebar on the right' = '将侧边栏置于右侧'
    'Show tab numbers' = '显示标签编号'
    'Show close button' = '显示关闭按钮'
    'Toggle light/dark theme' = '切换浅色/深色主题'
    'Show/hide sidebar tab titles' = '显示/隐藏侧边栏标签标题'
    'Take a screenshot' = '截取屏幕'
    'Create a folder' = '创建文件夹'
    'Save session to file' = '保存会话文件'
    'Create a desktop shortcut' = '创建桌面快捷方式'
    'Import MobaXterm sessions' = '导入 MobaXterm 会话'
    'Export MobaXterm sessions' = '导出 MobaXterm 会话'
    'Close all folders' = '关闭所有文件夹'
    'Execute all sessions from this folder' = '执行此文件夹会话'
    'Refresh shared sessions' = '刷新共享会话'
    'Share these sessions with my team' = '与团队共享会话'
    'Manage existing shared sessions' = '管理共享会话'
    'Save session settings as default presets' = '保存为默认会话设置'
    'Copy session settings' = '复制会话设置'
    'Paste session settings' = '粘贴会话设置'

    # Additional common captions and dialog labels found by scanning the
    # 26.4 resources. Short Chinese wording is used where the original
    # fixed-size Delphi field cannot hold a literal full sentence.
    'About' = '关于'
    'Homepage' = '主页'
    'Updates' = '更新'
    'Changelog' = '更新日志'
    'E-Mail' = '邮件'
    'Advanced RDP settings' = '高级 RDP 设置'
    'Graphic settings' = '图形设置'
    'Auto-adapt graphics' = '自动适配图形'
    'Display wallpaper' = '显示壁纸'
    'Display themes' = '显示主题'
    'Fonts smoothing' = '字体平滑'
    'Desktop composition' = '桌面合成'
    'Hardware mode' = '硬件模式'
    'Multi monitors' = '多显示器'
    'Use CredSSP' = '使用 CredSSP'
    'Restricted admin' = '受限管理员'
    'Remote credentials guard' = '远程凭据保护'
    'Use a web account' = '使用 Web 账户'
    'Automatic reconnection' = '自动重连'
    'Use redirection server name' = '使用重定向服务器名'
    'Redirect only selected drives' = '仅重定向选中的驱动器'
    'Advanced terminal settings' = '高级终端设置'
    'Auto-copy selected text' = '自动复制选中文本'
    'MobaXterm paste confirmation' = 'MobaXterm 粘贴确认'
    'Continue' = '继续'
    'Read' = '读取'
    'Write' = '写入'
    'Set permissions recursively' = '递归设置权限'
    'Terminal colors selection' = '终端颜色选择'
    'Foreground (standard text)' = '前景色（标准文本）'
    'Background color' = '背景色'
    'Cursor color' = '光标颜色'
    'Show bold font as brighter color' = '粗体显示为亮色'
    'CSV import' = 'CSV 导入'
    'The first line of the file contains headers' = '文件第一行包含列标题'
    'Please choose the content type for each column:' = '请选择每列的内容类型：'
    'MobaXterm Customizer' = 'MobaXterm 定制器'
    'Welcome' = '欢迎'
    'MobaXterm Professional settings customization' = 'MobaXterm 专业版设置定制'
    'Edit the default bash profile script' = '编辑默认 Bash 配置脚本'
    'Choose the default settings for all MobaXterm users' = '选择所有用户的默认设置'
    'Hardcode MobaXterm sessions' = '内置 MobaXterm 会话'
    'Import or export existing custom settings' = '导入或导出现有自定义设置'
    'Import from file' = '从文件导入'
    'export to file' = '导出到文件'
    'Customization wizard for MobaXterm Professional' = 'MobaXterm 专业版定制向导'
    'Rlogin' = 'Rlogin'
    'Version number' = '版本号'
    'Exported DISPLAY' = '导出的 DISPLAY'
    'IP address' = 'IP 地址'
    'Tab number' = '标签编号'
    'Computername' = '计算机名'
    'Username' = '用户名'
    'Connection info' = '连接信息'
    'Compression status' = '压缩状态'
    'Gateway status' = '网关状态'
    'Local terminal profile script' = '本地终端配置脚本'
    'Default settings' = '默认设置'
    'Please choose a logo to display in the splash screen and the about box' = '请选择启动画面和关于窗口中显示的徽标'
    'Click here if you want to download more plugins for MobaXterm' = '点击此处下载更多 MobaXterm 插件'
    'Select the plugins directory' = '选择插件目录'
    'Shortcut options' = '快捷方式选项'
    'Hide terminal on startup' = '启动时隐藏终端'
    'Close MobaXterm on exit' = '退出时关闭 MobaXterm'
    'Stay on top' = '置于顶层'
    'Toggle scaling' = '切换缩放'
    'Set connection password' = '设置连接密码'
    'Fit to window size' = '适应窗口大小'
    'Hide toolbar' = '隐藏工具栏'
    'Please wait while opening file...' = '正在打开文件，请稍候...'
    'Macro edition' = '宏编辑'
    'Key press:' = '按键：'
    'Sleep:' = '等待：'
    'Text:' = '文本'
    'Wait for pattern:' = '等待匹配：'
    'Call another macro:' = '调用其他宏：'
    'Keyboard event:' = '键盘事件：'
    'Mouse event:' = '鼠标事件：'
    'Wait for:' = '等待：'
    'Find...' = '查找...'
    '&Text to find:' = '要查找的文本：'
    'Match &case' = '区分大小写'
    '&Regular expressions' = '正则表达式'
    'Reverse search' = '反向搜索'
    'Terminal font selection' = '终端字体选择'
    'Bold' = '粗体'
    'Antialiasing' = '抗锯齿'
    'Ligatures' = '连字'
    'Terminal size' = '终端大小'
    'Force fixed rows / columns number:' = '固定行数/列数：'
    'Host key validation - more information' = '主机密钥验证 - 更多信息'
    'Hotkeys edition' = '快捷键编辑'
    'Please choose an icon' = '请选择图标'
    'Custom icons' = '自定义图标'
    'Select a specific icon for this session' = '为此会话选择指定图标'
    'Only reset the local terminal content' = '仅重置本地终端内容'
    'Export only the selected elements' = '仅导出选中项目'
    'Export entire MobaXterm configuration' = '导出完整 MobaXterm 配置'
    'Please wait while downloading file...' = '正在下载文件，请稍候...'
    'Name' = '名称'
    'Show password' = '显示密码'
    'Remember me on this computer' = '在此计算机上记住我'
    'MobaXterm jump hosts configuration' = 'MobaXterm 跳转主机配置'
    'Define one or several SSH jump hosts' = '设置一个或多个 SSH 跳转主机'
    'Add another jump host' = '添加其他跳转主机'
    'Edit selected line' = '编辑选中行'
    'Insert new line above' = '在上方插入新行'
    'Insert new line below' = '在下方插入新行'
    'Delete line' = '删除行'
    'Edit line' = '编辑行'
    'MobaXterm passwords settings' = 'MobaXterm 密码设置'
    'Delete selected' = '删除选中项'
    'Delete all' = '全部删除'
    'Save sessions passwords' = '保存会话密码'
    'Always' = '始终'
    'Never' = '从不'
    # This three-byte ANSI field cannot hold two GBK Chinese characters;
    # use the compact Chinese label rather than leaving the original English.
    'Ask' = '问'
    ' Always' = ' 始终'
    ' Never' = ' 从不'
    ' Ask' = ' 问'
    'Save SSH keys passphrases as well' = '同时保存 SSH 密钥口令'
    'Choose where to save passwords' = '选择密码保存位置'
    'User registry' = '用户注册表'
    'Configuration file' = '配置文件'
    'Show passwords' = '显示密码'
    'Master Password settings' = '主密码设置'
    'Passwords' = '密码'
    'Protocol' = '协议'
    'Servername' = '服务器名'
    'Password' = '密码'
    'Credentials' = '凭据'
    'New' = '新'
    'Copy username' = '复制用户名'
    'Copy servername' = '复制服务器名'
    'Copy password' = '复制密码'
    'Secure my stored passwords' = '保护已保存的密码'
    'Master password strength:' = '主密码强度：'
    'Prompt me for my master password ' = '询问主密码'
    'Do you want to save this password?' = '是否保存此密码？'
    'Session name:' = '会话名称：'
    'Start session in' = '会话启动位置'
    'Comments:' = '备注：'
    'Remote host' = '远程主机'
    'Port' = '端口'
    'Normal tab' = '普通标签页'
    'Do not show this message again' = '不再显示此消息'
    'MobaXterm packages manager' = 'MobaXterm 软件包管理器'
    'Install / update' = '安装/更新'
    'Building packages list, please wait...' = '正在生成软件包列表，请稍候...'
    'Show installed packages' = '显示已安装软件包'
    'Show available updates' = '显示可用更新'
    'Show available packages' = '显示可用软件包'
    'Package name' = '软件包名称'
    'Description' = '说明'
    'Version' = '版本'
    'Uninstall' = '卸载'
    'Create plugin' = '创建插件'
    'MobaXterm Home Edition' = 'MobaXterm 家庭版'
    'For more information, please click here...' = '更多信息请点击此处...'
    'Restart scan' = '重新扫描'
    'Other ports' = '其他端口'
    'MAC Address' = 'MAC 地址'
    'Protocol template' = '协议模板'
    'Scan ports template' = '端口扫描模板'
    'Lookup mac addr template' = 'MAC 地址查询模板'
    'Ports scan' = '端口扫描'
    'Scan only known ports' = '仅扫描已知端口'
    'Scan ports range' = '扫描端口范围'
    'Start scan' = '开始扫描'
    'Local Address' = '本地地址'
    'Local Port' = '本地端口'
    'Remote Address' = '远程地址'
    'Remote Port' = '远程端口'
    'State' = '状态'
    'Use Windows PATH' = '用 Windows PATH'
    'Backspace sends ^H' = '退格键发送 ^H'
    'Customize' = '自定义'
    'Default color settings' = '默认颜色设置'
    'Default font settings' = '默认字体设置'
    'Paste using right-click' = '使用右键粘贴'
    'Log terminal output to the following directory' = '将终端输出记录到以下目录'
    'Close prompt' = '关闭提示'
    'Paste warning settings' = '粘贴警告设置'
    'Automatically start X server at MobaXterm start up' = 'MobaXterm 启动时自动启动 X 服务器'
    'Display SSH banner' = '显示 SSH 欢迎信息'
    'GSSAPI Kerberos' = 'GSSAPI Kerberos'
    'SSH keepalive' = 'SSH 保活'
    'Validate host identity at first connection' = '首次连接时验证主机身份'
    'Use PuTTY agent' = '使用 PuTTY 代理'
    'Show keys currently loaded in MobAgent' = '显示 MobAgent 中已加载的密钥'
    'Prompt before serving keys' = '提供密钥前提示'
    'Use Windows SSH agent' = '使用 Windows SSH 代理'
    'Transparency' = '透明度'
    'Color saturation' = '颜色饱和度'
    'Rounded tabs' = '圆角标签'
    'Show close buttons' = '显示关闭按钮'
    'Home tab is replaced when starting new tab' = '打开新标签时替换主页标签'
    'Do not exit MobaXterm when last tab is closed' = '关闭最后一个标签时不退出 MobaXterm'
    'Popup terminal is sizeable' = '弹出终端可调整大小'
    'Hide popup terminal instead of closing it' = '隐藏弹出终端而不是关闭'
    'Allow multiple instances of MobaXterm' = '允许运行多个 MobaXterm 实例'
    'Security' = '安全'
    'No SSH keys passwd cache' = '不缓存 SSH 密钥口令'
    'Disable passwords saving' = '禁用保存密码'
    'Do not store master password' = '不保存主密码'
    'Disable settings edition' = '禁用设置编辑'
    'Defaults' = '默认值'
    'High security' = '高安全性'
    'Restricted features' = '受限功能'
    'Select which warnings to show before pasting' = '选择粘贴前显示的警告'
    'MobaSSHTunnel' = 'MobaSSHTunnel'
    'Start/stop' = '启动/停止'
    'Type' = '类型'
    'Forward port' = '转发端口'
    'Destination server' = '目标服务器'
    'SSH server' = 'SSH 服务器'
    'Order' = '顺序'
    'New SSH tunnel' = '新建 SSH 隧道'
    'Start all tunnels' = '启动所有隧道'
    'Stop all tunnels' = '停止所有隧道'
    'Local port forwarding' = '本地端口转发'
    'Remote port forwarding' = '远程端口转发'
    'Remote server' = '远程服务器'
    'Local clients' = '本地客户端'
    'Firewall' = '防火墙'
    'SSH tunnel' = 'SSH 隧道'
    'Use Windows Hello to authenticate' = '使用 Windows Hello 身份验证'
    'Yes to all' = '全部是'
    'Autosave (do not ask me again)' = '自动保存（不再询问）'
    'Main' = '主要'
    'Allow users to list directory content' = '允许用户列出目录内容'
    'Allow users to browse outside root directory' = '允许用户浏览根目录之外'
    'Start Cron server when MobaXterm starts' = 'MobaXterm 启动时启动 Cron 服务器'
    'Do not exit after command ends' = '命令结束后不退出'
    'Compression' = '压缩'
    'Use private key' = '使用私钥'
    'Try to follow SSH path in browser' = '尝试在浏览器中跟随 SSH 路径'
    'Expert SSH settings' = '专家 SSH 设置'
    'Advanced Telnet settings' = '高级 Telnet 设置'
    'Enable Telnet KeepAlive' = '启用 Telnet 保活'
    'Advanced Rsh settings' = '高级 Rsh 设置'
    'Advanced Xdmcp settings' = '高级 XDMCP 设置'
    'Enable font server' = '启用字体服务器'
    'Set Numlock off' = '关闭 NumLock'
    'Smart sizing' = '智能调整大小'
    'Enable compression' = '启用压缩'
    'Autoscale' = '自动缩放'
    'Enhanced graphics' = '增强图形'
    'Display settings bar' = '显示设置栏'
    'Redirect ports' = '重定向端口'
    'Redirect smartcards' = '重定向智能卡'
    'Redirect clipboard' = '重定向剪贴板'
    'Redirect printers' = '重定向打印机'
    'Redirect drives' = '重定向驱动器'
    'Redirect microphone' = '重定向麦克风'
    'Native authentication' = '本机身份验证'
    'Forward keyboard shortcuts' = '转发键盘快捷键'
    'Admin console' = '管理员控制台'
    'Expert RDP settings' = '专家 RDP 设置'
    'Advanced Vnc settings' = '高级 VNC 设置'
    'Display VNC settings bar' = '显示 VNC 设置栏'
    'Use new embedded VNC engine' = '使用新版内置 VNC 引擎'
    'Use SSL tunneling to secure the connection' = '使用 SSL 隧道保护连接'
    'Use IPv6' = '用 IPv6'
    'Advanced Ftp settings' = '高级 FTP 设置'
    'Passive mode' = '被动模式'
    'FTPS mode' = 'FTPS 模式'
    'Encrypt data channel' = '加密数据通道'
    'ASCII mode' = 'ASCII 模式'
    'Implicit SSL' = '隐式 SSL'
    'Advanced Sftp settings' = '高级 SFTP 设置'
    'UTF-8 Charset' = 'UTF-8 字符集'
    '2-steps authentication' = '两步身份验证'
    'Preserve files dates' = '保留文件日期'
    'Advanced Serial settings' = '高级 Serial 设置'
    'Reset defaults' = '重置默认值'
    'Advanced File/folder settings' = '高级文件/文件夹设置'
    'Advanced Shell settings' = '高级 Shell 设置'
    'Execute the following commands at startup:' = '启动时执行以下命令：'
    'Advanced Browser settings' = '高级浏览器设置'
    'Display top bar' = '显示顶部栏'
    'Display back button' = '显示后退按钮'
    'Display forward button' = '显示前进按钮'
    'Display refresh button' = '显示刷新按钮'
    'Display stop button' = '显示停止按钮'
    'Display home button' = '显示主页按钮'
    'Display address bar' = '显示地址栏'
    'Disable external popup windows' = '禁用外部弹出窗口'
    'Enable external popup windows' = '启用外部弹出窗口'
    'Enable Smartscreen' = '启用 SmartScreen'
    'Allow insecure localhost' = '允许不安全的 localhost'
    'Use Edge stored passwords' = '使用 Edge 保存的密码'
    'Enable context menus' = '启用上下文菜单'
    'Advanced Mosh settings' = '高级 Mosh 设置'
    'Advanced Aws S3 (experimental) settings' = '高级 AWS S3（实验性）设置'
    'Advanced WSL settings' = '高级 WSL 设置'
    'Proxy settings (experimental)' = '代理设置（实验性）'
    'SSH gateway (jump host)' = 'SSH 网关（跳转主机）'
    'Display reconnection message at session end' = '会话结束时显示重连提示'
    'Basic Telnet settings' = '基本 Telnet 设置'
    'Basic Rsh settings' = '基本 Rsh 设置'
    'Basic Xdmcp settings' = '基本 XDMCP 设置'
    'Connect to any server' = '连接到任意服务器'
    'Specify server to connect to:' = '指定要连接的服务器：'
    'Basic Rdp settings' = '基本 RDP 设置'
    'Basic Vnc settings' = '基本 VNC 设置'
    'Basic Ftp settings' = '基本 FTP 设置'
    'Basic Sftp settings' = '基本 SFTP 设置'
    'Basic Serial settings' = '基本 Serial 设置'
    'Basic File/folder settings' = '基本文件/文件夹设置'
    'Basic Shell settings' = '基本 Shell 设置'
    'Basic Browser settings' = '基本浏览器设置'
    'Basic Mosh settings' = '基本 Mosh 设置'
    'Basic Aws S3 (experimental) settings' = '基本 AWS S3（实验性）设置'
    'Basic WSL settings' = '基本 WSL 设置'
    'Shared sessions locations' = '共享会话位置'
    'Add' = '加'
    'URL' = '网址'
    'Shared sessions root folder' = '共享会话根文件夹'
    'Refresh folder entries every' = '刷新文件夹条目间隔'
    'Shared sessions file location' = '共享会话文件位置'
    'Nobody' = '无人'
    'Everyone' = '所有人'
    'Only me' = '仅自己'
    'Custom list' = '自定义列表'
    'Shared sessions modifications' = '共享会话修改权限'
    'Shared sessions file creation' = '创建共享会话文件'
    'Share sessions with your team' = '与团队共享会话'
    'Choose a smart card certificate' = '选择智能卡证书'
    'Reattach this tab' = '重新附加标签'
    'Delete selected files' = '删除选中文件'
    'Open selected file/folder' = '打开选中文件/文件夹'
    'Create new file' = '新建文件'
    'Create new directory' = '新建目录'
    'Refresh folder' = '刷新文件夹'
    'Download selected files' = '下载选中文件'
    'Show hidden (dot) files' = '显示隐藏文件'
    'Use SUDO for SSH-browser' = 'SSH 浏览器使用 SUDO'
    'Automatically browse to SSH current folder' = '自动浏览 SSH 当前文件夹'
    'Show/hide tab bar' = '显示/隐藏标签栏'
    'Print' = '打印'
    'Start a MobaXterm embedded program' = '启动 MobaXterm 内置程序'
    'Detach current tab' = '分离当前标签'
    'Open home folder' = '打开主文件夹'
    'Put current tab in fullscreen mode' = '将当前标签设为全屏'
    'Define keyboard shortcuts' = '设置键盘快捷键'
    'Generate and show MobaXterm documentation' = '生成并显示 MobaXterm 文档'
    'Set current tab title' = '设置当前标签标题'
    'Iconify MobaXterm' = '最小化 MobaXterm'
    'Iconify' = '最小化'
    'Multi-execution mode: commands are typed to all terminals (use Ctrl+Shift+Insert to paste)' = '多终端模式：命令会输入到所有终端（使用 Ctrl+Shift+Insert 粘贴）'
    'Exit multi-execution mode' = '退出多终端模式'
    'Multi-paste' = '多终端粘贴'
    'Welcome  ' = '欢迎'
    'Banner  ' = '欢迎信息'
    'Profile  ' = '配置文件'
    'Settings  ' = '设置'
    'Logo  ' = '徽标'
    'Sessions  ' = '会话'
    'Plugins  ' = '插件'
    'Edit sessions presets' = '编辑会话预设'
    'MobaXterm information' = 'MobaXterm 信息'
    'MobaXterm Master Password' = 'MobaXterm 主密码'
    'HTTP' = 'HTTP'
    'Composite' = 'Composite'
    'Damage' = 'Damage'
    'Randr' = 'RandR'
    'Xfixes' = 'XFixes'
    'Xtest' = 'XTest'
    'Xinerama' = 'Xinerama'
    'DirectDraw' = 'DirectDraw'
    'Up' = '上'
    'Down' = '下移'
    'Reset' = '重置'
    'MobaXterm paste settings' = 'MobaXterm 粘贴设置'
    'TFTP' = 'TFTP'
    'NFS' = 'NFS'
    'Cron' = 'Cron'
    'Iperf' = 'Iperf'
    'Use private key ' = '使用私钥 '
    'TabVide' = '标签'
    'Shared sessions locations                ' = '共享会话位置'
    'Shared sessions modifications ' = '共享会话修改权限'
    'Please choose a smart card certificate' = '请选择智能卡证书'
    'Attempt authentication using the SSH agent' = '尝试使用 SSH 代理进行身份验证'
    'Adapt locales on remote server' = '适配远程服务器语言环境'
    'Customize syntax highlighting' = '自定义语法高亮'
    'Save modifications' = '保存修改'
    'Remove this custom syntax' = '删除此自定义语法'
    'Custom syntax help and samples' = '自定义语法帮助和示例'
    'Import syntax from file' = '从文件导入语法'
    'Export syntax to file' = '将语法导出到文件'
    'Underline' = '下划线'
    'Red' = '红'
    'Green' = '绿色'
    'Yellow' = '黄色'
    'Blue' = '蓝色'
    'Magenta' = '洋红色'
    'Cyan' = '青色'
    'Blinking' = '闪烁'
    'Do not ask me again' = '不再询问'
    'Regular expression' = '正则表达式'
    'Match case' = '区分大小写'
    'Last modified' = '修改日期'
    'Owner' = '属主'
    'Group' = '组'
    'Access' = '权限'
    'Duplicate tab' = '复制标签'
    'Fullscreen on all monitors' = '所有显示器全屏'
    'Put this tab always on top' = '当前标签始终置顶'
    'Toggle smart sizing' = '切换智能调整大小'
    'Refresh VNC screen' = '刷新 VNC 屏幕'
    'Increase font size' = '增大字体'
    'Decrease font size' = '减小字体'
    'Rename Terminal' = '重命名终端'
    'XDMCP session' = 'XDMCP 会话'
    'MobaDiff' = 'MobaDiff'
    'Vim editor' = 'Vim 编辑器'
    'Mathomatic' = 'Mathomatic'
    'NEdit' = 'NEdit'
    'Start MobaTextEditor' = '启动 MobaTextEditor'
    'MobaTaskList' = 'MobaTaskList'
    'Display host information' = '显示主机信息'
    'Display CPU information' = '显示 CPU 信息'
    'Display RAM information' = '显示内存信息'
    'Display network connected clients' = '显示网络连接客户端'
    'Display number of processes' = '显示进程数'
    'Display number of file descriptors' = '显示文件描述符数'
    'Display uptime' = '显示运行时间'
    'Display connected users' = '显示已连接用户'
    'Display partitions information' = '显示分区信息'
    'Display NFS partitions' = '显示 NFS 分区'
    'Activate all' = '全部启用'
    'Activate none' = '全部禁用'
    'Invert selection' = '反选'
    'Synchronize mouse wheel scrolling' = '同步鼠标滚轮滚动'
    'Open with MobaTextEditor' = '用 MobaTextEditor 打开'
    'Open with default program' = '用默认程序打开'
    'Compare files' = '比较文件'
    'Create' = '创建'
    'Redo' = '重做'
    'Undo' = '撤销'
    'Save File' = '保存文件'
    'Reload default template' = '重新加载默认模板'
    'MobaXterm version number' = 'MobaXterm 版本号'
    'Local IP address' = '本地 IP 地址'
    'MobaXterm tab number' = 'MobaXterm 标签编号'
    'Local computer name' = '本地计算机名'
    'Local user name' = '本地用户名'
    'Status of SSH compression' = 'SSH 压缩状态'
    'List of SSH jump hosts for the SSH connection' = 'SSH 连接跳转主机列表'
    'Set window title' = '设置窗口标题'
    'Enter fullscreen mode' = '进入全屏模式'
    'Save terminal output to file' = '将终端输出保存到文件'
    'Put this window on top of all other windows' = '将此窗口置于所有窗口顶层'
    'Store the password for this connection' = '保存此连接的密码'
    'Refresh window content' = '刷新窗口内容'
    'Fit window content to window size' = '使窗口内容适应窗口大小'
    'Hide this toolbar' = '隐藏此工具栏'
    'Abort file transfer' = '中止文件传输'
    'Move up' = '上移'
    'Move down' = '下移'
    'Remove selected SSH jump host' = '删除选中的 SSH 跳转主机'
    'Edit the currently selected macro line' = '编辑当前选中的宏行'
    'Insert a new line above the selected line' = '在选中行上方插入新行'
    'Insert a new line below the selected line' = '在选中行下方插入新行'
    'Delete the selected line' = '删除选中行'
    'Default security settings' = '默认安全设置'
    'localhost' = '本地主机'
    'Compress RDP communication channel' = '压缩 RDP 通信通道'
    'Show local ports on remote server' = '在远程服务器显示本地端口'
    'Redirect local smartcards to remote server' = '将本地智能卡重定向到远程服务器'
    'Show local printers on remote server' = '在远程服务器显示本地打印机'
    'Show local drives on remote server' = '在远程服务器显示本地驱动器'
    'Connect to server console' = '连接到服务器控制台'
    'Browse for folder' = '浏览文件夹'
    'Enable default Edge context menus' = '启用 Edge 默认上下文菜单'
    'SSH server listening port' = 'SSH 服务器监听端口'
    'Customize terminal colors scheme' = '自定义终端配色方案'
    'Proxy server name or IP address' = '代理服务器名称或 IP 地址'
    'Proxy server port' = '代理服务器端口'
    'Proxy server login name' = '代理服务器登录名'
    'Telnet session' = 'Telnet 会话'
    'RSH session' = 'RSH 会话'
    'VNC session' = 'VNC 会话'
    'FTP session' = 'FTP 会话'
    'Local shell session' = '本地 Shell 会话'
    'Embedded internet browser' = '内置浏览器'
    'SSH server name or IP address' = 'SSH 服务器名称或 IP 地址'
    'Create or manage credentials' = '创建或管理凭据'
    'Telnet Remote Hostname' = 'Telnet 远程主机名'
    'Telnet server listening port' = 'Telnet 服务器监听端口'
    'Rsh  Remote Hostname' = 'Rsh 远程主机名'
    'RDP server name or IP address' = 'RDP 服务器名称或 IP 地址'
    'RDP server listening port' = 'RDP 服务器监听端口'
    'VNC  Remote Hostname' = 'VNC 远程主机名'
    'FTP  Remote Hostname' = 'FTP 远程主机名'
    'SFTP  Remote Hostname' = 'SFTP 远程主机名'
    'Browse for file' = '浏览文件'
    'URL or local path' = '网址或本地路径'
    'Amazon Web Services Key ID' = 'AWS 密钥 ID'
    'Try to connect using the following username' = '尝试使用以下用户名连接'
    'Add a new shared sessions file entry' = '添加共享会话文件条目'
    'Move up selected shared sessions file entry' = '上移选中的共享会话文件条目'
    'Move down selected shared sessions file entry' = '下移选中的共享会话文件条目'
    'Delete selected shared sessions file entry' = '删除选中的共享会话文件条目'
    'Open the Windows certificate manager' = '打开 Windows 证书管理器'
    'Copy the key fingerprint to the clipboard' = '将密钥指纹复制到剪贴板'
    'Create a new certificate in the smart card' = '在智能卡中创建新证书'
    'Delete the selected certificate from the smart card' = '从智能卡删除选中的证书'
    'Restore the default expert SSH settings' = '恢复默认专家 SSH 设置'
    'Remove the configured smart card certificate' = '删除已配置的智能卡证书'
    'Status of SSH-browser' = 'SSH 浏览器状态'
    'Status of X11-forwarding' = 'X11 转发状态'
    'Re-attach this window to MobaXterm main window' = '重新附加到 MobaXterm 主窗口'
    'Enable/disable desktop scaling' = '启用/禁用桌面缩放'
    'Send Ctrl+Alt+Del to remote desktop' = '向远程桌面发送 Ctrl+Alt+Del'
    'Allow copy/paste from/to RDP tab' = '允许与 RDP 标签复制粘贴'
    'Try to reconnect the SSH-browser' = '尝试重新连接 SSH 浏览器'
    'Show a confirmation dialog on terminal close request, when a session is still running inside it' = '终端仍在运行时关闭前显示确认'
    'Stay connected to the remote server after command has been executed' = '命令执行后保持连接'
}

# These disabled menu items are visual section headers. MobaXterm's owner-drawn
# menu hides Chinese captions when they are disabled, so enable only these inert headers.
$MenuSectionHeaders = @(
    'Menu and buttons toolbars',
    'Buttons toolbar',
    'Toggle sidebar titles',
    'Tabbar'
)

# The first row on the home page is the owner-drawn MainMenu3. Its root menu
# items are separate from the icon toolbar below, so the generic caption pass
# does not give them a consistent width. Keep each replacement within the
# original ANSI field and use trailing spaces to normalize the menu cells.
# Games is intentionally left in English per the requested scope.
$HomepageMenuCaptions = [ordered]@{
    '0xF9EB3F' = '终端    '     # Terminal (8-byte field)
    '0xF9F23E' = '会话夹  '     # Sessions (8-byte field)
    '0xF9F372' = '查看'        # View (4-byte field)
    '0xF9FFCB' = 'X服务器 '     # X server (8-byte field)
    '0xFA00D6' = '工具 '        # Tools (5-byte field)
    '0xFA0F4F' = 'Games'       # Games (5-byte field)
    '0xFA15BD' = '设置    '     # Settings (8-byte field)
    '0xFA192B' = '宏    '       # Macros (6-byte field)
    '0xFA1A95' = '帮助'        # Help (4-byte field)
}

# Raw offsets of the Caption values in the 26.4 homepage toolbar DFM.  These
# are deliberately kept separate from the generic caption table because the
# same words occur in many dialogs.  The source executable hash below makes
# these offsets deterministic and the patch remains size-preserving.
$HomepageButtonCaptionOffsets = @{
    0xF97F12 = ' 终端  '     # BtnNewSession (7-byte field)
    0xF98728 = '我的会话'    # BtnBookmarks (8-byte field)
    0xF98221 = '查看'       # ToolButton2
    0xF985E6 = '工具 '       # BtnMenuComdes (5-byte field)
    0xF980F3 = '设置'       # BtnColor
    0xF98362 = ' 多终端  '    # BtnMultiExec (9-byte field)
    0xF98497 = '分屏 '       # BtnSplitMode (5-byte field)
    0xF98FF5 = '  隧道   '   # BtnTunneling (9-byte field)
    0xF990E2 = '服务器 '     # BtnServices (7-byte field)
    0xF9A2B2 = '   包   '    # BtnMobapt (8-byte field)
    0xF9A4BC = 'X服务器 '    # sBitBtn7 (8-byte field)
    0xF992C2 = ' 宏  '       # BtnMacros (5-byte field)
    0xF98004 = '帮助'       # BtnHelp
}

# The session and macro context menus use VCL's automatic shortcut column.
# Keep their longest captions compact so that column does not become an
# oversized empty area on the right.  These overrides are limited to the
# PopupSessions/PopupMacros raw fields and do not alter dialog wording.
$PopupCaptionOverrides = @{
    0xFA3A3A = 'SFTP会话'
    0xFA3A9A = 'Ping主机'
    0xFA3CD1 = '保存会话文件'
    0xFA3D41 = '创建快捷方式'
    0xFA3DD0 = '导入MobaXterm'
    0xFA3E40 = '导出MobaXterm'
    0xFA3EA2 = '第三方导入'
    0xFA3F01 = '导入WSL'
    0xFA3F75 = '导入Bash'
    0xFA3FF5 = '导入PuTTY'
    0xFA40E0 = '导入SuperPuTTY'
    0xFA41D1 = '导入Exceed'
    0xFA4242 = '导入SCRT'
    0xFA42AE = '导入RDM'
    0xFA4319 = '从CSV导入'
    0xFA4392 = '生成HTML'
    0xFA445D = '执行文件夹会话'
    0xFA456B = '共享给团队'
    0xFA45EF = '管理共享会话'
    0xFA467E = '保存默认设置'
    0xFA46F2 = '复制会话设置'
    0xFA4754 = '粘贴会话设置'
    0xFA4CDE = '创建文件夹 '
}

# PopupSessions in the 23.0 reference uses Delphi WideString captions. The
# 26.4 resource switched these few short fields to ANSI. Convert only fields
# whose existing byte capacity is an exact fit, keeping all following DFM
# offsets unchanged.
$WidePopupCaptionOffsets = @{
    '0xFA397C' = '执行'       # Execute1, 7-byte ANSI field -> 2 UTF-16 chars
    '0xFA3B0C' = '新建会话'   # NewSession1, 11-byte ANSI field -> 4 UTF-16 chars
    '0xFA3C87' = '复制'       # Duplicate1, 9-byte ANSI field -> 3 UTF-16 chars
    '0xFA43F1' = '关闭所有文件夹' # C8, 17-byte ANSI field -> 7 UTF-16 chars
    '0xFA3DD0' = '导入MobaXterm' # Import MobaXterm sessions, 25-byte ANSI field -> 11 UTF-16 chars
    '0xFA3E40' = '导出MobaXterm' # Export MobaXterm sessions, 25-byte ANSI field -> 11 UTF-16 chars
    '0xFA4067' = '导入 PuTTYCM' # Import PuTTYCM sessions, 23-byte ANSI field -> 10 UTF-16 chars
    '0xFA415C' = '导入 MRemote' # Import MRemote sessions, 23-byte ANSI field -> 10 UTF-16 chars
    '0xFA4C82' = '分配快捷键'   # Assign hotkey, 13-byte ANSI field -> 5 UTF-16 chars
    '0xFA4CDE' = '创建文件夹 '  # Create a folder, 15-byte ANSI field -> 6 UTF-16 chars
    '0xF3C984' = '新建会话'   # Sidebar popup duplicate, 11-byte ANSI field -> 4 UTF-16 chars
    '0xF3CAFF' = '复制'       # Sidebar popup duplicate, 9-byte ANSI field -> 2 UTF-16 chars
}

# Homepage labels are Delphi long-string constants in the CODE section, not DFM properties.
$CodeTranslations = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::Ordinal)
$CodeTranslations.Add('Quick connect', '快速连接')
$CodeTranslations.Add('User sessions', '我的会话')
$CodeTranslations.Add('Start local terminal', '启动本地终端')
$CodeTranslations.Add('New session', '新建会话')
$CodeTranslations.Add('List of previous sessions:', '最近会话列表：')
$CodeTranslations.Add('Recover previous sessions', '恢复之前的会话')
$CodeTranslations.Add("Welcome to MobaXterm`r`rPress <return> to start a local terminal", "欢迎使用 MobaXterm`r`r按回车键启动本地终端")
$CodeTranslations.Add("Welcome to MobaXterm`r`rPress <return> to start a new session", "欢迎使用 MobaXterm`r`r按回车键新建会话")
$CodeTranslations.Add('Edit', '编辑')
$CodeTranslations.Add('Delete', '删除')
$CodeTranslations.Add('New folder', '新建文件夹')
$CodeTranslations.Add('Upload', '上传')
$CodeTranslations.Add('Download', '下载')
$CodeTranslations.Add('Copy', '复制')
$CodeTranslations.Add('Folder', '文件夹')
$CodeTranslations.Add('Quick connect...', '快速连接...')
$CodeTranslations.Add('Saved macros', '已保存的宏')
$CodeTranslations.Add('Record macro', '录制宏')
$CodeTranslations.Add('Terminal', '终端')
$CodeTranslations.Add('Detach', '分离')
$CodeTranslations.Add('Terminal zoom', '终端放大')
$CodeTranslations.Add('Terminal unzoom', '终端缩小')
$CodeTranslations.Add('Save terminal output', '保存终端输出')
$CodeTranslations.Add('Print terminal output', '打印终端输出')
$CodeTranslations.Add('Find in terminal', '在终端中查找')
$CodeTranslations.Add('Find next', '查找下个')
$CodeTranslations.Add('Duplicate current tab', '复制当前标签')
$CodeTranslations.Add('Write commands on all terminals', '向所有终端发送命令')
$CodeTranslations.Add('Session', '会话')
$CodeTranslations.Add('Sessions', '会话夹')
$CodeTranslations.Add('Servers', '服务器')
$CodeTranslations.Add('Tools', '工具')
$CodeTranslations.Add('View', '查看')
$CodeTranslations.Add('X server', 'X 服务器')
$CodeTranslations.Add('Split', '拆分')
$CodeTranslations.Add('MultiExec', '多终端')
$CodeTranslations.Add('Tunneling', '隧道')
$CodeTranslations.Add('Packages', '软件包')
$CodeTranslations.Add('Settings', '设置')
$CodeTranslations.Add('Macros', '宏')
$CodeTranslations.Add('Help', '帮助')
$CodeTranslations.Add('Exit', '退出')
$CodeTranslations.Add('Pin/unpin this tab', '固定标签')
$CodeTranslations.Add('Start a new remote session', '启动新的远程会话')
$CodeTranslations.Add('Network services', '网络服务')
$CodeTranslations.Add('Toolbars, menus and buttons options', '工具栏、菜单和按钮选项')
$CodeTranslations.Add('Show the session manager (sidebar)', '显示会话管理器（侧边栏）')
$CodeTranslations.Add('Pin sidebar', '固定侧边栏')
$CodeTranslations.Add('Show Terminal', '显示终端')
$CodeTranslations.Add('Show popup terminal', '显示弹出终端')
$CodeTranslations.Add('Modify Home settings', '修改首页设置')
$CodeTranslations.Add('Enter the MAC address of the server:', '请输入服务器的 MAC 地址：')
$CodeTranslations.Add('List ports', '端口列表')
$CodeTranslations.Add('Tasks list', '任务列表')
$CodeTranslations.Add('Systray', '托盘')
$CodeTranslations.Add('Duplicate this tab', '复制此标签')
$CodeTranslations.Add('Define the local shell prompt type', '设置 Shell 提示符')
$CodeTranslations.Add('Create your own syntax coloration definition', '创建语法高亮定义')
$CodeTranslations.Add('Choose keyboard language', '选择键盘语言')
$CodeTranslations.Add('Domain name to use for GSSAPI authentication', 'GSSAPI 域名')
$CodeTranslations.Add('Library to use for GSSAPI authentication', 'GSSAPI 库')
$CodeTranslations.Add('Add a smart card to the Agent list', '将智能卡添加到代理')
$CodeTranslations.Add('Start a MobaXterm embedded program', '启动内置程序')
$CodeTranslations.Add('Start MobaTextEditor', '启动文本编辑器')
$CodeTranslations.Add('MobaTaskList', '任务列表')
$CodeTranslations.Add('MobaHwInfo', '硬件信息')
$CodeTranslations.Add('MobaSwInfo', '软件信息')
$CodeTranslations.Add('MobaXterm', 'MobaXterm')
$CodeTranslations.Add('Restore the default expert RDP settings', '恢复默认专家 RDP 设置')
$CodeTranslations.Add('Restore the default expert terminal settings', '恢复默认专家终端设置')
$CodeTranslations.Add('Rename the current color theme', '重命名当前颜色主题')
$CodeTranslations.Add('Import a color theme from a file', '从文件导入颜色主题')
$CodeTranslations.Add('Export the current color theme to a file', '将当前颜色主题导出到文件')
$CodeTranslations.Add('Remove the current color theme from the list', '从列表删除当前颜色主题')
$CodeTranslations.Add('Choose the terminal text color', '选择终端文本颜色')
$CodeTranslations.Add('Choose the terminal background color', '选择终端背景色')
$CodeTranslations.Add('Choose the terminal cursor color', '选择终端光标颜色')
$CodeTranslations.Add('Choose the terminal cursor shape', '选择终端光标形状')
$CodeTranslations.Add('Redo', '重做')
$CodeTranslations.Add('Undo', '撤销')
$CodeTranslations.Add('Save File', '保存文件')
$CodeTranslations.Add('Reload default template', '重新加载默认模板')
$CodeTranslations.Add('Local IP address', '本地 IP 地址')
$CodeTranslations.Add('Local computer name', '本地计算机名')
$CodeTranslations.Add('Local user name', '本地用户名')
$CodeTranslations.Add('Set window title', '设置窗口标题')
$CodeTranslations.Add('Enter fullscreen mode', '进入全屏模式')
$CodeTranslations.Add('Save terminal output to file', '保存终端输出到文件')
$CodeTranslations.Add('Put this window on top of all other windows', '将窗口置于顶层')
$CodeTranslations.Add('Store the password for this connection', '保存此连接密码')
$CodeTranslations.Add('Refresh window content', '刷新窗口内容')
$CodeTranslations.Add('Fit window content to window size', '适应窗口大小')
$CodeTranslations.Add('Hide this toolbar', '隐藏此工具栏')
$CodeTranslations.Add('Abort file transfer', '中止文件传输')
$CodeTranslations.Add('Remove selected SSH jump host', '删除选中的 SSH 跳转主机')
$CodeTranslations.Add('Edit the currently selected macro line', '编辑选中的宏行')
$CodeTranslations.Add('Insert a new line above the selected line', '在选中行上方插入新行')
$CodeTranslations.Add('Insert a new line below the selected line', '在选中行下方插入新行')
$CodeTranslations.Add('Delete the selected line', '删除选中行')
$CodeTranslations.Add('Default security settings', '默认安全设置')
$CodeTranslations.Add('Compress RDP communication channel', '压缩 RDP 通信通道')
$CodeTranslations.Add('Show local ports on remote server', '在远程显示本地端口')
$CodeTranslations.Add('Redirect local smartcards to remote server', '重定向本地智能卡')
$CodeTranslations.Add('Show local printers on remote server', '在远程显示本地打印机')
$CodeTranslations.Add('Show local drives on remote server', '在远程显示本地驱动器')
$CodeTranslations.Add('Connect to server console', '连接服务器控制台')
$CodeTranslations.Add('Browse for folder', '浏览文件夹')
$CodeTranslations.Add('Enable default Edge context menus', '启用 Edge 默认菜单')
$CodeTranslations.Add('SSH server listening port', 'SSH 服务器监听端口')
$CodeTranslations.Add('Customize terminal colors scheme', '自定义终端配色')
$CodeTranslations.Add('Proxy server name or IP address', '代理服务器名称或 IP')
$CodeTranslations.Add('Proxy server port', '代理服务器端口')
$CodeTranslations.Add('Proxy server login name', '代理服务器登录名')
$CodeTranslations.Add('Telnet session', 'Telnet 会话')
$CodeTranslations.Add('RSH session', 'RSH 会话')
$CodeTranslations.Add('VNC session', 'VNC 会话')
$CodeTranslations.Add('FTP session', 'FTP 会话')
$CodeTranslations.Add('Local shell session', '本地 Shell 会话')
$CodeTranslations.Add('Embedded internet browser', '内置浏览器')
$CodeTranslations.Add('SSH server name or IP address', 'SSH 服务器名称或 IP')
$CodeTranslations.Add('Create or manage credentials', '创建或管理凭据')
$CodeTranslations.Add('Telnet Remote Hostname', 'Telnet 远程主机名')
$CodeTranslations.Add('Telnet server listening port', 'Telnet 服务器监听端口')
$CodeTranslations.Add('Rsh  Remote Hostname', 'Rsh 远程主机名')
$CodeTranslations.Add('RDP server name or IP address', 'RDP 服务器名称或 IP')
$CodeTranslations.Add('RDP server listening port', 'RDP 服务器监听端口')
$CodeTranslations.Add('VNC  Remote Hostname', 'VNC 远程主机名')
$CodeTranslations.Add('FTP  Remote Hostname', 'FTP 远程主机名')
$CodeTranslations.Add('SFTP  Remote Hostname', 'SFTP 远程主机名')
$CodeTranslations.Add('Browse for file', '浏览文件')
$CodeTranslations.Add('URL or local path', '网址或本地路径')
$CodeTranslations.Add('Try to connect using the following username', '尝试使用以下用户名连接')
$CodeTranslations.Add('Add a new shared sessions file entry', '添加共享会话文件条目')
$CodeTranslations.Add('Move up selected shared sessions file entry', '上移共享会话文件条目')
$CodeTranslations.Add('Move down selected shared sessions file entry', '下移共享会话文件条目')
$CodeTranslations.Add('Delete selected shared sessions file entry', '删除共享会话文件条目')
$CodeTranslations.Add('Open the Windows certificate manager', '打开 Windows 证书管理器')
$CodeTranslations.Add('Copy the key fingerprint to the clipboard', '复制密钥指纹')
$CodeTranslations.Add('Create a new certificate in the smart card', '在智能卡创建证书')
$CodeTranslations.Add('Delete the selected certificate from the smart card', '删除智能卡中的证书')
$CodeTranslations.Add('Remove the configured smart card certificate', '删除已配置的智能卡证书')
$CodeTranslations.Add('Reattach this tab', '重新附加标签')
$CodeTranslations.Add('Delete selected files', '删除选中文件')
$CodeTranslations.Add('Create new file', '新建文件')
$CodeTranslations.Add('Create new directory', '新建目录')
$CodeTranslations.Add('Refresh folder', '刷新文件夹')
$CodeTranslations.Add('Download selected files', '下载选中文件')
$CodeTranslations.Add('ASCII mode', 'ASCII 模式')
$CodeTranslations.Add('Automatically browse to SSH current folder', '自动浏览 SSH 当前文件夹')
$CodeTranslations.Add('Show/hide tab bar', '显示/隐藏标签栏')
$CodeTranslations.Add('Print', '打印')
$CodeTranslations.Add('Start the terminal game', '启动终端游戏')
$CodeTranslations.Add('Detach current tab', '分离当前标签')
$CodeTranslations.Add('Open home folder', '打开主文件夹')
$CodeTranslations.Add('Put current tab in fullscreen mode', '当前标签全屏')
$CodeTranslations.Add('Define keyboard shortcuts', '设置键盘快捷键')
$CodeTranslations.Add('Generate and show MobaXterm documentation', '生成并显示 MobaXterm 文档')
$CodeTranslations.Add('Set current tab title', '设置当前标签标题')
$CodeTranslations.Add('Iconify MobaXterm', '最小化 MobaXterm')
$CodeTranslations.Add('Iconify', '最小化')
$CodeTranslations.Add('Exit multi-execution mode', '退出多终端模式')
$CodeTranslations.Add('Multi-paste', '多终端粘贴')
$CodeTranslations.Add('Import sessions from file', '从文件导入')
$CodeTranslations.Add('Export all sessions to file', '导出全部')
$CodeTranslations.Add('Import sessions from third-party programs', '第三方导入')
$CodeTranslations.Add('Generate HTML web page', '生成HTML')
$CodeTranslations.Add('Close all folders', '关闭所有文件夹')
$CodeTranslations.Add('Refresh shared sessions', '刷新共享会话')
$CodeTranslations.Add('Updating packages list, please wait...', '正在更新软件包列表，请稍候...')
$CodeTranslations.Add('Type "y" to continue or any other key to exit:', '输入 y 继续，按其他键退出：')
$CodeTranslations.Add('Share these sessions with my team', '共享给团队')
$CodeTranslations.Add('Manage existing shared sessions', '管理现有共享会话')
$CodeTranslations.Add('Execute all sessions from this folder', '执行此文件夹中的所有会话')
$CodeTranslations.Add('This is a simple SSH/SFTP server: you can only log on using your current Windows login () and the associated password.', '这是一个简单的 SSH/SFTP 服务器：只能使用当前 Windows 登录账户及其密码登录。')
$CodeTranslations.Add('For a complete SSH server for Windows, please download MobaSSH.', '如需完整的 Windows SSH 服务器，请下载 MobaSSH。')
$CodeTranslations.Add('Listening port', '监听端口')
$CodeTranslations.Add('Server output', '服务器输出')
$CodeTranslations.Add('Stop server after', '服务器停止延时')
$CodeTranslations.Add('Remote host', '远程主机')
$CodeTranslations.Add('Username', '用户名')
$CodeTranslations.Add('Port', '端口')
$CodeTranslations.Add('Session name:', '会话名称：')
$CodeTranslations.Add('Start session in', '会话启动位置')
$CodeTranslations.Add('Comments:', '备注：')
$CodeTranslations.Add('Normal tab', '普通标签页')
$CodeTranslations.Add('MobaXterm Master Password', 'MobaXterm 主密码')
$CodeTranslations.Add('Prompt me for my master password ', '询问主密码')
$CodeTranslations.Add('Do you want to save this password?', '是否保存此密码？')
$CodeTranslations.Add('Please enter a "Master Password" in order to protect your password vault.\r\nThe master password is used to encrypt all your stored passwords.\r\n\r\nIMPORTANT:  DO NOT FORGET YOUR MASTER PASSWORD,\r\notherwise you will lose all your stored passwords!', '请输入“主密码”以保护密码库。\r\n主密码用于加密所有已保存的密码。\r\n\r\n重要提示：请务必记住主密码，否则将丢失所有已保存的密码！')

# A few runtime messages are NUL-terminated CODE strings rather than Delphi long strings.
# Their byte pattern is checked and is only replaced within the CODE section.
$RawCodeTranslations = @(
    [pscustomobject]@{
        Source = 'Multi-execution mode allows you to run a single command on all opened terminals.' + "`r" + 'Using this feature with less than 2 terminals opened is useless:' + "`r" + 'you should try to open several terminals before clicking on this option.'
        Target = '多终端执行模式可将同一条命令发送到所有已打开的终端。' + "`r" + '少于两个终端时此功能没有意义：' + "`r" + '请先打开多个终端，再使用此选项。'
        ExpectedOccurrences = 1
    }
)

# These captions contain punctuation/line breaks and are kept as exact DFM
# strings so the fixed-length resource fields can be replaced safely.
$Translations['MobaXterm Master Password'] = 'MobaXterm 主密码'
$Translations[' Prompt me for my master password '] = ' 询问主密码 '
$Translations['Do you want to save this password?'] = '是否保存此密码？'
$masterPromptSource = 'Please enter a "Master Password" in order to protect your password vault.' + "`r`n" + 'The master password is used to encrypt all your stored passwords.' + "`r`n`r`n" + 'IMPORTANT:  DO NOT FORGET YOUR MASTER PASSWORD,' + "`r`n" + 'otherwise you will lose all your stored passwords!'
$Translations[$masterPromptSource] = "请输入主密码以保护密码库。`r`n主密码用于加密所有已保存的密码。`r`n`r`n重要提示：请务必记住主密码，否则将丢失所有已保存的密码！"
$Translations['MobaXterm will use your "Master Password" in order to secure' + "`r`n" + 'all your stored passwords with strong encryption.' + "`r`n"] = "MobaXterm 将使用主密码通过强加密保护所有已保存的密码。`r`n"
$Translations['Session name:'] = '会话名称：'
$Translations['Start session in'] = '会话启动位置'
$Translations['Comments:'] = '备注：'
$Translations['Normal tab'] = '普通标签页'

$encoding = Get-GbkEncoding
$bytes = [IO.File]::ReadAllBytes($sourcePath)
$rsrc = Get-ResourceSection -Bytes $bytes
$rsrcStart = [int]$rsrc.RawOffset
$rsrcEnd = $rsrcStart + [int]$rsrc.RawSize
$code = Get-CodeSection -Bytes $bytes
$codeStart = [int]$code.RawOffset
$codeEnd = $codeStart + [int]$code.RawSize
$sourceEncoding = [Text.Encoding]::ASCII

$patched = @{}
$codePatched = @{}
$rawCodePatched = @{}
$eligible = [ordered]@{}
$skipped = [System.Collections.Generic.List[string]]::new()

foreach ($sourceText in $Translations.Keys) {
    $sourceBytes = $sourceEncoding.GetBytes($sourceText)
    $targetBytes = $encoding.GetBytes($Translations[$sourceText])
    if ($targetBytes.Length -gt $sourceBytes.Length) {
        $skipped.Add($sourceText)
        continue
    }
    $eligible[$sourceText] = $Translations[$sourceText]
    $patched[$sourceText] = 0
}

foreach ($sourceText in $CodeTranslations.Keys) {
    $sourceLength = $sourceEncoding.GetByteCount($sourceText)
    $targetBytes = $encoding.GetBytes($CodeTranslations[$sourceText])
    if ($targetBytes.Length -gt $sourceLength) {
        throw "Code-section translation is too long: $sourceText"
    }
    $codePatched[$sourceText] = 0
}

foreach ($translation in $RawCodeTranslations) {
    $sourceLength = $sourceEncoding.GetByteCount($translation.Source)
    $targetBytes = $encoding.GetBytes($translation.Target)
    if ($targetBytes.Length -gt $sourceLength) {
        throw "Raw code-section translation is too long: $($translation.Source)"
    }
    $rawCodePatched[$translation.Source] = 0
}

$dfmProperties = @('Caption', 'HelpKeyword', 'Hint', 'Text', 'Title')
$enabledPropertyBytes = $sourceEncoding.GetBytes('Enabled')

for ($offset = $rsrcStart; $offset -lt $rsrcEnd - 16; $offset++) {
    # Delphi binary DFM: short-string property name, vaString, length, ANSI text.
    $propertyLength = [int]$bytes[$offset]
    if ($propertyLength -lt 4 -or $propertyLength -gt 64 -or $offset + $propertyLength + 3 -ge $rsrcEnd) {
        continue
    }
    $propertyName = $sourceEncoding.GetString($bytes, $offset + 1, $propertyLength)
    $propertyLeaf = ($propertyName -split '\.')[-1]
    if ($propertyLeaf -notin $dfmProperties -or $bytes[$offset + $propertyLength + 1] -ne 6) {
        continue
    }
    $length = [int]$bytes[$offset + $propertyLength + 2]
    $valueOffset = $offset + $propertyLength + 3
    if ($length -eq 0 -or $valueOffset + $length -gt $rsrcEnd) {
        continue
    }
    $sourceText = $sourceEncoding.GetString($bytes, $valueOffset, $length)
    if (-not $eligible.Contains($sourceText)) {
        continue
    }
    $replacementText = $eligible[$sourceText]
    if ($HomepageButtonCaptionOffsets.ContainsKey($valueOffset)) {
        $replacementText = $HomepageButtonCaptionOffsets[$valueOffset]
    }
    $targetBytes = $encoding.GetBytes($replacementText)
    [Array]::Clear($bytes, $valueOffset, $length)
    [Array]::Copy($targetBytes, 0, $bytes, $valueOffset, $targetBytes.Length)
    for ($i = $targetBytes.Length; $i -lt $length; $i++) {
        $bytes[$valueOffset + $i] = 0x00
    }
    if ($sourceText -in $MenuSectionHeaders) {
        $enabledSearchEnd = [Math]::Min($rsrcEnd - $enabledPropertyBytes.Length - 1, $valueOffset + $length + 128)
        for ($enabledOffset = $valueOffset + $length; $enabledOffset -le $enabledSearchEnd; $enabledOffset++) {
            if ((Test-BytesAt -Bytes $bytes -Offset $enabledOffset -Needle $enabledPropertyBytes) -and
                $bytes[$enabledOffset + $enabledPropertyBytes.Length] -eq 0x08) {
                $bytes[$enabledOffset + $enabledPropertyBytes.Length] = 0x09
                break
            }
        }
    }
    $patched[$sourceText]++
}

# Apply the top-level menu width overrides at their exact raw file locations.
# The keys identify the Caption value itself (not the property header).
foreach ($menuOffset in $HomepageMenuCaptions.Keys) {
    $captionTextOffset = [Convert]::ToInt32($menuOffset.Substring(2), 16)
    if ($captionTextOffset -lt $rsrcStart -or $captionTextOffset -ge $rsrcEnd) {
        continue
    }
    $captionLength = [int]$bytes[$captionTextOffset - 1]
    $menuCaption = $HomepageMenuCaptions[$menuOffset]
    if ($null -eq $menuCaption) {
        continue
    }
    $targetBytes = $encoding.GetBytes([string]$menuCaption)
    if ($targetBytes.Length -gt $captionLength) {
        continue
    }
    [Array]::Clear($bytes, $captionTextOffset, $captionLength)
    [Array]::Copy($targetBytes, 0, $bytes, $captionTextOffset, $targetBytes.Length)
}

# Apply concise captions to the two context-menu DFM blocks after the generic
# translation pass.  The original ANSI field lengths remain unchanged.
foreach ($popupOffset in $PopupCaptionOverrides.Keys) {
    $valueOffset = [int]$popupOffset
    if ($valueOffset -lt $rsrcStart -or $valueOffset -ge $rsrcEnd) {
        continue
    }
    $captionLength = [int]$bytes[$valueOffset - 1]
    $targetBytes = $encoding.GetBytes([string]$PopupCaptionOverrides[$popupOffset])
    if ($targetBytes.Length -gt $captionLength) {
        continue
    }
    [Array]::Clear($bytes, $valueOffset, $captionLength)
    [Array]::Copy($targetBytes, 0, $bytes, $valueOffset, $targetBytes.Length)
}

# Convert exact-fit PopupSessions Caption fields to WideString (DFM type 0x12).
$utf16 = [Text.Encoding]::Unicode
foreach ($wideOffset in $WidePopupCaptionOffsets.Keys) {
    $valueOffset = [Convert]::ToInt32($wideOffset.Substring(2), 16)
    if ($valueOffset -lt $rsrcStart -or $valueOffset -ge $rsrcEnd) {
        continue
    }
    $propertyOffset = $valueOffset - 3
    $ansiLength = [int]$bytes[$propertyOffset + 2]
    $targetBytes = $utf16.GetBytes([string]$WidePopupCaptionOffsets[$wideOffset])
    $capacity = 2 + $ansiLength
    if (5 + $targetBytes.Length -ne $capacity) {
        continue
    }
    $bytes[$propertyOffset + 1] = 0x12
    [BitConverter]::GetBytes([int]($targetBytes.Length / 2)).CopyTo($bytes, $propertyOffset + 2)
    [Array]::Clear($bytes, $propertyOffset + 6, $targetBytes.Length)
    [Array]::Copy($targetBytes, 0, $bytes, $propertyOffset + 6, $targetBytes.Length)
}

for ($offset = $codeStart + 8; $offset -lt $codeEnd - 2; $offset++) {
    # Only inspect Delphi long-string constants: [refcount=-1][length][text][NUL].
    if ($bytes[$offset - 8] -ne 0xFF -or $bytes[$offset - 7] -ne 0xFF -or
        $bytes[$offset - 6] -ne 0xFF -or $bytes[$offset - 5] -ne 0xFF) {
        continue
    }
    $sourceLength = [BitConverter]::ToInt32($bytes, $offset - 4)
    if ($sourceLength -lt 1 -or $sourceLength -gt 512 -or $offset + $sourceLength -ge $codeEnd -or
        $bytes[$offset + $sourceLength] -ne 0) {
        continue
    }
    $sourceText = $sourceEncoding.GetString($bytes, $offset, $sourceLength)
    if (-not $CodeTranslations.ContainsKey($sourceText)) {
        continue
    }
    $targetBytes = $encoding.GetBytes($CodeTranslations[$sourceText])
    [BitConverter]::GetBytes([int]$targetBytes.Length).CopyTo($bytes, $offset - 4)
    [Array]::Clear($bytes, $offset, $sourceLength)
    [Array]::Copy($targetBytes, 0, $bytes, $offset, $targetBytes.Length)
    $codePatched[$sourceText]++
    $offset += $sourceLength
}

 $codeText = $sourceEncoding.GetString($bytes, $codeStart, $codeEnd - $codeStart)
foreach ($translation in $RawCodeTranslations) {
    $sourceBytes = $sourceEncoding.GetBytes($translation.Source)
    $targetBytes = $encoding.GetBytes($translation.Target)
    $searchStart = 0
    while ($true) {
        $relativeOffset = $codeText.IndexOf($translation.Source, $searchStart, [StringComparison]::Ordinal)
        if ($relativeOffset -lt 0) {
            break
        }
        $offset = $codeStart + $relativeOffset
        $searchStart = $relativeOffset + $sourceBytes.Length
        if ($bytes[$offset + $sourceBytes.Length] -ne 0) {
            continue
        }
        [Array]::Clear($bytes, $offset, $sourceBytes.Length)
        [Array]::Copy($targetBytes, 0, $bytes, $offset, $targetBytes.Length)
        $rawCodePatched[$translation.Source]++
    }
    if ($rawCodePatched[$translation.Source] -ne $translation.ExpectedOccurrences) {
        throw "Unexpected number of raw code strings replaced: $($translation.Source)"
    }
}

if (($patched.Values | Measure-Object -Sum).Sum -eq 0) {
    throw 'No captions were changed. The source may not match the expected DFM layout.'
}

[IO.File]::WriteAllBytes($destinationPath, $bytes)
$outputHash = (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash
$changed = ($patched.Values | Measure-Object -Sum).Sum
$codeChanged = ($codePatched.Values | Measure-Object -Sum).Sum
$rawCodeChanged = ($rawCodePatched.Values | Measure-Object -Sum).Sum
$covered = ($patched.Values | Where-Object { $_ -gt 0 }).Count

[pscustomobject]@{
    Source = $sourcePath
    SourceSha256 = $sourceHash
    Output = $destinationPath
    OutputSha256 = $outputHash
    CaptionReplacements = $changed
    TranslationKeysApplied = $covered
    CodeStringReplacements = $codeChanged
    RawCodeStringReplacements = $rawCodeChanged
    SkippedForLength = if ($skipped.Count) { $skipped -join ', ' } else { '(none)' }
    Note = 'The output is intentionally unsigned because it differs from the Mobatek-signed original.'
} | Format-List

