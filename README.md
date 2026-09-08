# WCHLinkExHPM

> 基于**上游 OpenOCD master**(2026-08-15 快照 `da3920b`)自编译的 OpenOCD,用于通过 **WCH-LinkE(CH347)高速 JTAG 模式** 给 **HPMicro HPM5E31 等 HPM 系列 RISC-V MCU** 烧录固件。
>
> 关键特性:**同时内置 `ch347` 适配器驱动与 `hpm_xpi` Flash 驱动**,实测可用 WCH-LinkE 的 JTAG 模式完整烧录 HPM5E31 的 XPI NOR Flash(`** Verified OK **`)。

## 为什么需要这个仓库

要用 **WCH-LinkE(CH347)的 JTAG 模式**直接烧录 HPM 芯片,OpenOCD 必须**同时**包含两个驱动:

| 驱动 | 类型 | 作用 |
|---|---|---|
| `ch347` | 适配器驱动 | 让 OpenOCD 认识并驱动 CH347 / WCH-LinkE 高速 JTAG 探针(经 libusb-1.0 访问 USB) |
| `hpm_xpi` | Flash 驱动 | 把 HPMicro BootROM 的 `rom_xpi_nor_*` 烧写算法载入芯片 RAM,完成 XPI NOR Flash 擦写(HPMicro 2025 年贡献并合入上游) |

常见的各厂商/发行版 OpenOCD 往往只满足其一(见下节对比),因此需要基于上游最新源码自行构建——本仓库即该构建产物与配套文档。

## 与其它 OpenOCD 版本的差异

| 能力 | A. HPMicro sdk_env | B. xPack 0.12.0-7 | **C. 本仓库** | D. WCH / MounRiver |
|---|---|---|---|---|
| `ch347` 适配器驱动 | ❌ | ✅(仅 WCH 旧式语法) | ✅(上游标准语法) | ✅(IoCHubDLL,免 WinUSB) |
| `hpm_xpi` Flash 驱动 | ✅ | ❌(快照早于合入) | ✅ | ❌ |
| 连 CH347(换成 WinUSB 后) | ❌ | ✅ | ✅ | ❌(与 WinUSB 互斥) |
| 烧录 HPM5E31 | 需另配 J-Link | ❌ | ✅ 完整烧录 | ❌ |

- 上游 master 的 `src/jtag/drivers/ch347.c` 与 `src/flash/nor/hpm_xpi.c` **同时存在**,本仓库即该状态;
- A(sdk_env,HPMicro fork)只带 `hpm_xpi`、不带 `ch347`;D(MounRiver Studio 2,WCH fork)正好相反——两家厂商 fork 都只面向自家芯片;
- B(xPack)基于 2025-10 快照,早于 `hpm_xpi` 合入,且其 `ch347` 只支持 WCH 旧式 `ch347 vid_pid` 命令;
- 逐版本实测过程与结论详见 [`OpenOCD对比与处理过程.md`](OpenOCD对比与处理过程.md)。

## Release:GitHub Actions 自动编译发布

本仓库配置了 `.github/workflows/release.yml`,推送后自动在官方 runner 上构建 **四个平台** 的产物并发布:

- **Windows x64 / Windows x86**:Ubuntu 上用 MinGW 交叉编译,压缩包内含 `openocd.exe` + 运行库 DLL + `tcl` 脚本(解压即用);
- **Linux / macOS**:原生编译,压缩包内为 `bin/openocd` + `share/openocd`。

触发方式:

- 推送到 `master` → 自动更新 **`latest` 预发布**;
- 推送标签(如 `v1.0.0`,`v*`)→ 自动发布**正式 Release**,以标签命名;
- 也可在 Actions 页面手动 `Run workflow`。

解压后先自检两个关键驱动是否已编译进去(不报 `not found` 即通过):

```sh
bin/openocd -c "adapter driver ch347" -c "shutdown"
# hpm_xpi:报 "target not defined" 说明驱动已编译进去;报 "flash driver not found" 才是没编进去
bin/openocd -c "flash bank xpi0 hpm_xpi 0x80000000 0x2000000 1 1 cpu0 0xF3000000 0x5 0x1000" -c "shutdown"
```

## 快速开始:用 WCH-LinkE 的 JTAG 模式烧录(下载)固件

> 以烧录 **HPMicro HPM5E31** 的板载 XPI NOR Flash 为例。OpenOCD 采用「探针 + SoC + 板卡 Flash」三段式配置:SoC(`soc/hpm5e00.cfg`)与板卡 Flash(`hpm_xpi` bank、`init_clock`)通常来自 HPM SDK 与你的板卡目录,这里重点讲 **WCH-LinkE 探针** 侧。

### 1. 把 WCH-LinkE 切到高速 JTAG 模式

- WCH-LinkE 需处于 **CH347 高速 JTAG 模式**(USB 枚举为 `VID_1a86 / PID_55dd`,即 CH347 mode 3 = UART + JTAG);
- 切换方法见 WCH 官方《WCH-Link 使用说明》(7.4 节)或 WCH-LinkUtility 工具;
- 接线:4 线 JTAG(TMS / TCK / TDI / TDO + GND)接目标板;该接口无 SRST,复位交由 RISC-V 调试模块(`reset_config none`)。

### 2. USB 驱动:把 JTAG 口(MI_02)换成 WinUSB

- 本仓库 `ch347` 驱动经 **libusb-1.0** 访问 USB,Windows 下 libusb 只能打开绑定 **WinUSB / libusbK** 驱动的设备;
- CH347 的 JTAG 口默认是 WCH 私有驱动 `CH341_A64`,必须换掉(**COM 串口那一项不要动**,操作可逆):
  1. 打开 **Zadig**(sdk_env 自带 `tools/zadig/zadig.exe`,或官网 <https://zadig.akeo.ie/>);
  2. `Options → List All Devices`,选择 CH347 的 **JTAG / I2C / SPI 接口**(当前驱动显示 `CH341_A64`);
  3. 目标驱动选 **WinUSB** → `Replace Driver`;
- 若 OpenOCD 报 `LIBUSB_ERROR_NOT_FOUND` / `CH347 not found`,基本都是这一步没做。

### 3. 探针配置 `ch347.cfg`(上游版语法)

```tcl
# ch347.cfg —— WCH-LinkE(CH347)高速 JTAG 探针
adapter driver ch347
adapter usb vid_pid 0x1a86 0x55dd   ; 上游标准语法(不是 WCH fork 的 ch347 vid_pid)
transport select jtag
adapter speed 10000
reset_config none                    ; 4 线 JTAG 无 SRST
```

### 4. 组装 SoC + Flash 配置并执行烧录

把探针配置与目标芯片的 SoC / 板卡 Flash 配置组合成一个 all-in-one 配置(示例,路径以你的环境为准):

```tcl
# wchlinke.cfg
source C:/path/to/ch347.cfg                                        ; WCH-LinkE 探针
source C:/hpm_sdk/boards/openocd/soc/hpm5e00.cfg                   ; 创建 RISC-V 目标
source C:/path/to/board/hpm5e31_LuckyCAT/hpm5e31_LuckyCAT.cfg      ; hpm_xpi flash bank + init_clock
```

执行烧录(`program` = 擦除 + 写入 + 校验 + 复位运行):

```sh
bin/openocd \
  -s C:/hpm_sdk/boards/openocd \
  -f build/wchlinke.cfg \
  -c "program build/output/demo.elf verify reset exit"
```

烧录成功的关键日志:

```
Info : CH347 ... found
Info : JTAG tap: hpm5e00.cpu tap/device found: 0x1000563d
** Programming Started ** / ** Programming Finished **
** Verified OK **
** Resetting Target **
```

### 常见问题

| 现象 | 原因 / 处理 |
|---|---|
| `The specified adapter driver was not found (ch347)` | 所用 OpenOCD 不含 `ch347` → 改用本仓库 Release |
| `LIBUSB_ERROR_NOT_FOUND` / `CH347 not found` | JTAG 口没换 WinUSB → 见第 2 步 |
| `flash driver not found (hpm_xpi)` | 所用 OpenOCD 不含 `hpm_xpi` → 改用本仓库 Release |
| 连上探针但烧录异常 | 检查板卡 cfg 中 `hpm_xpi` bank 参数与 `init_clock` |

## 相关文档

- [`OpenOCD对比与处理过程.md`](OpenOCD对比与处理过程.md) —— 四个 OpenOCD 逐版本实测对比、驱动原理、自编译完整流程及待 WCH 确认问题;
- [`test_wch_openocd.ps1`](test_wch_openocd.ps1) —— ASCII 版功能自检脚本(驱动 / 传输 / 命令识别);
- 完整工程编译与烧录(J-Link 流程与本文差异)见 LuckyCAT 软硬件仓库《编译与烧录指南》。

## 本仓库相对上游的改动

相对 `openocd-org/openocd` 快照 `da3920b` 仅 5 处差异(可用 `git diff` 核对):`configure.ac`(autoconf 2.72+ 兼容修复)、新增对比文档、新增 `test_wch_openocd.ps1`、增补 `.gitignore`、`doc/openocd.info-3`。**核心源码与上游一致。**

## 许可

上游 OpenOCD 遵循 GPL-2.0-or-later,本仓库随上游许可证分发。

Optional development script checkpatch needs:

- perl
- python
- python-ply
- pymarkdownlnt

### Compiling OpenOCD

To build OpenOCD, use the following sequence of commands:

```sh
./bootstrap
./configure [options]
make
sudo make install
```

The `bootstrap` command is only necessary when building from the Git repository.
The `configure` step generates the Makefiles required to build OpenOCD, usually
with one or more options provided to it.
The first 'make' step will build OpenOCD and place the final executable in './src/'.
The final (optional) step, `make install`, places all of the files in the
required location.

To see the list of all the supported options, run `./configure --help`

### Cross-compiling Options

Cross-compiling is supported the standard autotools way, you just need
to specify the cross-compiling target triplet in the --host option,
e.g. for cross-building for Windows 32-bit with MinGW on Debian:

```sh
./configure --host=i686-w64-mingw32 [options]
```

To make pkg-config work nicely for cross-compiling, you might need an additional
wrapper script as described at <https://autotools.io/pkgconfig/cross-compiling.html>.

This is needed to tell pkg-config where to look for the target
libraries that OpenOCD depends on. Alternatively, you can specify
`*_CFLAGS` and `*_LIBS` environment variables directly, see `./configure
--help` for the details.

For a more or less complete script that does all this for you, see `contrib/cross-build.sh`.

### Parallel Port Dongles

If you want to access the parallel port using the PPDEV interface you
have to specify both `--enable-parport` and `--enable-parport-ppdev`, since
the later option is an option to the parport driver.

The same is true for the `--enable-parport-giveio` option, you have to
use both the `--enable-parport` and the `--enable-parport-giveio` option
if you want to use giveio instead of ioperm parallel port access
method.

### Obtaining OpenOCD From Git

You can download the current Git version with a Git client of your
choice from the main repository: `git://git.code.sf.net/p/openocd/code`

You may prefer to use a mirror:

- <http://repo.or.cz/r/openocd.git>
- git://repo.or.cz/openocd.git

Using the Git command line client, you might use the following command
to set up a local copy of the current repository (make sure there is no
directory called "openocd" in the current directory):

```sh
git clone git://git.code.sf.net/p/openocd/code openocd
```

Then you can update that at your convenience using `git pull`.

There is also a gitweb interface, which you can use either to browse the
repository or to download arbitrary snapshots using HTTP: <http://repo.or.cz/w/openocd.git>.

Snapshots are compressed tarballs of the source tree, about 1.3 MBytes
each at this writing.

## Permissions delegation

Running OpenOCD with root/administrative permissions is strongly
discouraged for security reasons.

For USB devices on GNU/Linux you should use the contrib/60-openocd.rules
file. It probably belongs somewhere in /etc/udev/rules.d, but
consult your operating system documentation to be sure. Do not forget
to add yourself to the "plugdev" group.

For parallel port adapters on GNU/Linux and FreeBSD please change your
"ppdev" (parport* or ppi*) device node permissions accordingly.

For parport adapters on Windows you need to run install_giveio.bat
(it's also possible to use "ioperm" with Cygwin instead) to give
ordinary users permissions for accessing the "LPT" registers directly.
