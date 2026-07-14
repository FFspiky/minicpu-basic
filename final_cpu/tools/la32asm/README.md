# la32asm 与 LA32 Studio

`la32asm`面向`final_cpu`实际译码器，实现LA32R两遍汇编、固定地址静态布局、LA32IMG打包、UART下载和NAND程序槽管理。

## 工具链边界

```text
C源码 -> GNU GCC -S -> LA32R汇编文本 -> 自研la32asm -> LA32IMG
```

GNU GCC只负责生成汇编文本。机器码、地址布局和镜像生成不调用GNU `as`、`ld`或`objcopy`。

## LA32 Studio

```powershell
git clone https://github.com/FFspiky/minicpu-basic.git
cd .\minicpu-basic
.\LA32-Studio.cmd
```

源码启动器不依赖固定盘符：它优先使用便携运行时或现有虚拟环境，否则使用本机
Python 3.10+创建`.venv`并安装锁定依赖。无Python的电脑请下载GitHub Release中的
便携ZIP，而不是只下载仓库源码。

浏览器默认打开`http://127.0.0.1:8765`。页面支持：

Studio默认不发送250 ms的`0x55`字节洪流：UART使用固定分频而非自动波特率，训练字节不会校准硬件，反而可能在Boot Monitor扫描NAND期间填满16字节RX FIFO。仅在诊断时可设置环境变量`LA32_UART_SYNC_BYTES`显式启用前导字节。

- 编辑和构建简单freestanding C；
- 同时查看C源码、GCC生成的LA32R汇编和自研机器码listing；
- 经UART临时下载到RAM、运行并显示开发板真实输出；
- 构建赛车和完整流水线EXP16；
- 安装、读取、校验和初始化NAND程序槽。

通用C运行库位于`sw/generic/runtime.c`，提供`putchar`、`puts`、`print_int`和简化`printf`。推荐示例：

```c
int printf(const char *format, ...);

int main(void) {
    int a = 1, b = 2;
    printf("c = %d\n", a + b);
    return 0;
}
```

通用程序的字符结果经UART显示在Studio网页；VGA显示`GENERIC PROGRAM / RUNNING`。赛车仍使用原有VGA画面。

## 命令行

```text
la32asm build start.S app.c -o app.la32img --type generic
la32asm install app.la32img --slot 0 --port COMx
la32asm run-temporary app.la32img --port COMx
la32asm list --port COMx
la32asm remove --slot 1 --port COMx
la32asm verify --slot 0 --port COMx
la32asm format --port COMx
la32asm studio
```

## 测试

```powershell
$env:PYTHONPATH=(Get-Location).Path
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

## 生成U盘便携版

在开发电脑上执行：

```powershell
cd .\final_cpu\tools\la32asm
.\make_portable.ps1 -Destination ..\..\..\LA32-Studio-Portable -CreateArchive
```

将生成的整个目录复制到U盘或其他电脑，双击根目录的
`LA32-Studio.cmd`即可启动。便携包自带Python和网页依赖，也会携带压缩后的
LA32R GCC；C语言编译仍要求目标Windows已启用WSL。详细说明见便携包中的
`PORTABLE_README.md`。

发布时将生成的`.zip`和`.zip.sha256`作为GitHub Release附件上传，不要提交约
150 MiB的生成目录。组员下载ZIP、核对SHA256并完整解压后，即可从任意盘符双击
`LA32-Studio.cmd`。`BUILD_INFO.json`记录源码提交；正式发布前应确认其中
`source_dirty`为`false`，避免把未提交文件混入旧提交版本的便携包。

当前测试覆盖核心编码、标签与伪指令、立即数报错、EXP16兼容、跨GCC文件局部符号隔离、LA32IMG CRC、串口帧和赛车GNU机器码差分。

## 限制

- v1不输出ELF，也不支持动态链接；
- 通用C为freestanding环境，没有完整libc、操作系统调用、文件系统、堆和线程；
- 简化`printf`支持`%d/%u/%x/%X/%c/%s/%%`，不支持宽度、精度和浮点格式；
- 板上只接收机器码，不在FPGA内编译C源码。
