# GitHub 上传与发布说明

## 上传边界

源码通过Git提交和分支推送，正常`git push`只上传受版本控制的文件。下列本地目录
是生成物或个人工作文件，不应手工拖入GitHub仓库：

- `.Xil/`、`xsim.dir/`、Vivado的`*.runs/`、`*.sim/`、`project_lcd/`；
- `tmp/`、`outputs/`、`LA32-Studio-Portable/`；
- `github_upload/`本地发布暂存目录；
- `.bit`、`.zip`及其解压目录。

当前分支没有超过GitHub 100 MiB限制的Git对象。LA32 Studio便携ZIP超过100 MiB，
必须作为GitHub Release附件上传，不能执行`git add`。

## 推荐发布流程

1. 推送稳定分支：

   ```powershell
   git push -u origin codex/nand-debug-20260714
   ```

2. 在GitHub上创建Pull Request，将该分支合并到`main`。当前分支与远端`main`
   存在双方独有提交，不允许用`--force`覆盖远端。
3. 合并并确定最终提交后，运行`final_cpu/tools/la32asm/make_portable.ps1`重新生成
   便携包，确认`BUILD_INFO.json`中的`source_dirty`为`false`且提交号正确。
4. 创建GitHub Release，上传`github_upload/stable-20260714/release-assets/`中的
   bitstream、Studio ZIP和`SHA256SUMS.txt`。

## 组员使用方式

- 有Python 3.10+和网络：克隆仓库，双击根目录`LA32-Studio.cmd`；
- 无Python：下载Release中的LA32 Studio便携ZIP，完整解压后双击
  `LA32-Studio.cmd`；
- C编译仍需Windows启用WSL；UART/NAND操作仍需USB转RS-232驱动；
- FPGA配置SRAM断电会丢失bitstream，每次完全断电后需重新通过JTAG下载；NAND
  中安装的应用不会因此被擦除。
