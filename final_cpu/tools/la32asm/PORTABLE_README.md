# LA32 Studio 便携版

## 启动

1. 将整个 `LA32-Studio-Portable` 文件夹复制到本机硬盘或U盘；
2. 双击根目录的 `LA32-Studio.cmd`；
3. 浏览器会自动打开 `http://127.0.0.1:8765`；
4. 关闭命令行窗口即可停止服务。

请先完整解压ZIP再启动，不要直接在压缩包预览窗口中运行。`BUILD_INFO.json`中的
`source_commit`可用于和GitHub提交核对版本；正式发布包的`source_dirty`应为
`false`。发布页提供的`.sha256`用于检查下载文件是否完整。

Python、FastAPI、串口库和网页资源均已包含在便携包中，不需要安装 Python、uv 或 pip。
便携运行时面向64位Windows 10/11；Linux和macOS不在当前硬件串口工具的发布范围内。

## C语言编译

LA32R课程GCC是Linux程序。便携包包含该工具链压缩包；如果电脑已经启用WSL，首次启动会自动解压到当前用户的 `~/.la32studio`，无需管理员权限，之后直接使用。

如果电脑未启用WSL，Studio页面和UART/NAND功能仍可使用，但“构建赛车”和“构建并运行C程序”会不可用。Windows系统组件WSL无法由普通U盘程序在不重启、不授权的情况下便携替代。

## 串口

电脑仍需能识别USB转RS-232适配器。串口驱动属于Windows内核驱动，不能安全地由网页程序静默安装。

## 目录要求

便携包可以放在任意盘符和任意不含特殊权限限制的目录中，不要求 `D:\CPU_DESIGN\final_cpu`。

## 自动自检

遇到启动问题时，可在`final_cpu\tools\la32asm`目录执行：

```powershell
.\start_studio.ps1 -Port 18765 -NoBrowser -SmokeTest
```

看到`LA32 Studio smoke test passed`表示Python依赖、网页服务和串口枚举均可用；
该检查不会连接开发板，也不会读写NAND。
