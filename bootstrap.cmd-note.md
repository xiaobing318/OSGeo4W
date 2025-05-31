# 20250529

以下内容将帮助入门开发者理解 **bootstrap.cmd** 与 **bootstrap.sh** 在 OSGeo4W 项目中的角色、差异以及它们解决的问题。

## 概要

两个脚本共同承担“**一键化**”初始化和引导 OSGeo4W 构建环境的功能：

* 在 **Windows** 平台上，`bootstrap.cmd`（Windows 批处理脚本）会自动下载并安装一个精简的 Cygwin 环境及必要软件包，然后将控制权移交给 `bootstrap.sh`；
* 在 **Linux/类 UNIX（包括 macOS）** 平台上，`bootstrap.sh`（Bash 脚本）直接完成克隆/更新仓库、配置安全目录、并调用 `scripts/build.sh` 启动后续构建流程。

此设计消除了手动安装依赖、配置环境和执行多条命令的繁琐，保证在不同操作系统上的可重现自动化构建。

---

## 1. 脚本对应的平台

* `bootstrap.cmd` 是一个 **Windows** 下的批处理（Batch）脚本，扩展名 `.cmd` 表明它由 `cmd.exe` 解释执行 ([Wikipedia][1])。
* `bootstrap.sh` 是一个 **POSIX**（Bash）风格的 shell 脚本，首行含有 `#!/bin/bash` 的 shebang 指令，适用于 Linux、macOS 及 Cygwin 环境 ([GitHub][2])。

GitHub 仓库中同时包含这两个文件，即可在对应平台无缝使用 ([GitHub][3])。

---

## 2. 作用是否相同？

* **相同点**：二者都用于“引导”（bootstrap）OSGeo4W 的构建流程——安装/准备依赖、拉取或更新源码、并最终调用核心的 `scripts/build.sh`。
* **差异点**：仅脚本语言与调用环境不同，所执行的命令集与平台特性（如 Cygwin 安装 vs. 直接使用系统包管理器）有所区别 ([GitLab][4])([Qt Forum][5])。

---

## 3. `bootstrap.cmd` 详解与使用

1. **文件类型与执行方式**

   * Windows 下的批处理文件（Batch File），由 `cmd.exe` 或 PowerShell（兼容 `.cmd`）执行 ([Wikipedia][1])。
2. **主要流程**

   * 在当前目录创建 `scripts` 子目录；
   * 若定义了 CI 环境变量，会在 GitHub Actions 等 CI 流程中打印分组信息；
   * 如果未下载 Cygwin 安装器，则使用 `curl` 拉取 `setup-x86_64.exe`；
   * 调用该安装器静默安装一系列构建依赖包（如 `bison, flex, git, mingw64-x86_64-gcc-core` 等）到 `%CD%/cygwin`；
   * 将 `bootstrap.sh` 复制到 Cygwin 的临时目录并在 Cygwin Bash 中执行它（`bash /tmp/bootstrap.sh`）。
3. **如何使用**

   ```bat
   mkdir osgeo4w-build
   cd osgeo4w-build
   curl -JLO https://raw.githubusercontent.com/jef-n/OSGeo4W/master/bootstrap.cmd
   bootstrap.cmd qgis-dev
   ```

   以上示例来自 QGIS Windows 源码构建指南 ([Qt Forum][5])。

---

## 4. `bootstrap.sh` 详解与使用

1. **文件类型与执行方式**

   * 标准 Bash 脚本，首行为 `#!/bin/bash` shebang，用于指示内核调用 Bash 解释器执行 ([GitHub][2])([Wikipedia][6])。
2. **主要流程**

   * 设置严格错误退出 (`set -e`) 并配置 PATH；
   * 通过环境变量确定 Git 仓库地址和分支（默认 `https://github.com/jef-n/OSGeo4W` 的 `master` 分支）；
   * 若当前目录尚未初始化 Git，则执行 `git init`、`git remote add origin`、`git fetch` 并检出远程分支；否则执行 `git pull --rebase` 更新代码；
   * 最后调用 `bash scripts/build.sh "$@"` 启动真正的包构建脚本。
3. **如何使用**

   ```bash
   chmod +x bootstrap.sh        # 使脚本可执行
   ./bootstrap.sh              # 在 Linux/macOS 终端中运行
   # 或者
   bash bootstrap.sh           # 不依赖执行权限，直接调用 bash
   ```

   运行方式参考常见的 Shell 脚本执行方法 ([Unix & Linux Stack Exchange][7])。

---

## 5. 解决的问题

* **依赖安装自动化**：免去手动配置 Cygwin（Windows）或在各类 Linux 发行版中安装相同软件包的重复劳动 ([GitHub][8])([Informa TechTarget][9])。
* **源码获取与更新**：统一了 Git 仓库克隆与切换分支的流程，避免新手在分支管理上出错 ([GitHub][2])。
* **一键化构建入口**：通过简单的 `bootstrap.* [目标包名]` 命令即可进入完整的构建流程，大幅提高可维护性与可重现性 ([GitLab][4])。
* **跨平台一致性**：同一套脚本分别兼容 Windows（Cygwin）与类 UNIX 系统，保证 OSGeo4W 包在不同平台的构建结果一致。

若省略这两个脚本，则需要用户手工：安装正确版本的编译器与工具链、配置环境变量、克隆并切换分支、手动调用内部脚本……极易出错且效率低下。

---

**总结**：
`bootstrap.cmd` 与 `bootstrap.sh` 的协同作用，解决了 OSGeo4W 在 Windows 与类 UNIX 平台上依赖安装、源码管理和构建流程自动化的问题，为开发者提供了一键化、可重现的构建环境。

[1]: https://en.wikipedia.org/wiki/Batch_file?utm_source=chatgpt.com "Batch file"
[2]: https://raw.githubusercontent.com/jef-n/OSGeo4W/refs/heads/master/bootstrap.sh?utm_source=chatgpt.com "https://raw.githubusercontent.com/jef-n/OSGeo4W/re..."
[3]: https://github.com/jef-n/OSGeo4W?utm_source=chatgpt.com "jef-n/OSGeo4W - GitHub"
[4]: https://gitlab.b-data.ch/qgis/qgis/-/blob/ltr-3_40/INSTALL.md?utm_source=chatgpt.com "INSTALL.md · ltr-3_40 - qgis - GitLab"
[5]: https://forum.qt.io/topic/160843/qgis-installation-from-source-with-qt-5-in-windows?utm_source=chatgpt.com "QGIS installation from Source with Qt 5 in Windows - Qt Forum"
[6]: https://en.wikipedia.org/wiki/Shebang_%28Unix%29?utm_source=chatgpt.com "Shebang (Unix)"
[7]: https://unix.stackexchange.com/questions/136547/what-is-the-difference-between-running-bash-script-sh-and-script-sh?utm_source=chatgpt.com "What is the difference between running \"bash script.sh\" and \"./script ..."
[8]: https://raw.githubusercontent.com/qgis/QGIS/master/INSTALL.md?utm_source=chatgpt.com "https://raw.githubusercontent.com/qgis/QGIS/master..."
[9]: https://www.techtarget.com/searchwindowsserver/definition/batch-file?utm_source=chatgpt.com "What is a Batch File? | Definition from TechTarget"

# 20250531
在 OSGeo4W 仓库里的 **bootstrap.cmd** 其实就是一个面向 Windows `cmd.exe` 的批处理脚本；它用来静默下载并安装 Cygwin 及一大批构建 QGIS/OSGeo4W 所需的软件包，然后把后续的 *bootstrap.sh* 转交给刚装好的 Cygwin 去执行。下面先快速概览结论，再逐条说明——.cmd 与 .bat 同属批处理，但 .cmd 诞生于 Windows NT 时代，对 cmd.exe 更友好且在 **PATHEXT** 搜索顺序中优先；脚本中的 `^` 把一条很长的安装命令拆成多行；注释可用 `REM` 或 `::`；整个流程在 Linux bash 下不会直接解析。

## 1 bootstrap.cmd 是不是脚本文件

* **是。** “.cmd”/“.bat” 都是纯文本批处理脚本，由 `cmd.exe` 解释执行。([Server Fault][1], [Stack Overflow][2])

## 2 能否在 Linux bash 下直接运行

* Windows 批处理语法（IF/REM、环境变量 `%VAR%` 等）只受 `cmd.exe` 支持；bash 不认识这套语法，因此在原生 Linux 上直接运行会报错。若确实要用，可借 Wine 或在 WSL 里执行 `cmd /c bootstrap.cmd`。([Super User][3], [Cygwin][4])

## 3 为什么用“.cmd”而非“.bat”

1. **历史差异**：.bat 最早给 16-bit `COMMAND.COM` 用；.cmd 随 Windows NT 出现，专属 `cmd.exe`。([Server Fault][1], [Stack Overflow][5])
2. **优先级**：在 **PATHEXT** 搜索顺序里 .cmd 通常排在 .bat 前，能避免“同名双扩展”时执行到旧的 .bat。([Stack Overflow][5])
3. **错误级别行为**：某些内部命令（SET/ASSOC 等）在 .cmd 里总会设置 `ERRORLEVEL`，而 .bat 只在出错时设置，脚本作者更容易做可靠的错误检测。([Stack Overflow][2])

## 4 在 bootstrap.cmd 里添加注释的方法

* **`REM`** 行：`REM 这是注释`   ([Microsoft Learn][6])
* **`::`** 行：`:: 也是注释`（速度快，但偶尔受 `ENABLEEXTENSIONS` 影响）。([Stack Overflow][7], [Microsoft Answers][8])

## 5 逐行详解 bootstrap.cmd

| 行号   | 代码                                              | 作用                                                                                                                                                                                   | 关键点                                                              |
| ---- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------- |
| 1    | `if not exist scripts mkdir scripts`            | 若不存在 scripts 目录则创建                                                                                                                                                                   | 典型的 `IF NOT EXIST dir MKDIR dir` 写法，用于保持源码根干净。([hexnode.com][9]) |
| 3    | `if defined CI echo ::group::Installing cygwin` | 在 CI 环境（GitHub Actions 等）里向日志输出分组标签，方便折叠显示                                                                                                                                           | `IF DEFINED var` 检测环境变量是否存在                                      |
| 4-5  | `if not exist scripts/setup-x86_64.exe curl …`  | 缺少安装器时，用 curl 下载安装器 `setup-x86_64.exe`                                                                                                                                               | `curl --output <目标> <URL>` 下载文件                                  |
| 6-12 | `scripts\setup-x86_64.exe ^`                    | 调用 Cygwin 安装器并用 `^` 把长命令分行                                                                                                                                                           | `^` 是批处理的续行符号，可将一条命令拆到多行([Stack Overflow][10])                   |
|      | `  -qnNdOW ^`                                   | 组合开关：<br>-q = quiet (静默)；<br>-n = --no-shortcuts；<br>-N = --no-admin；<br>-dO /W 常与下载/无桌面图标相关（官方写法为 `--no-desktop --no-startmenu --download`，这里作者简写）。([Super User][11], [Cygwin][12]) |                                                                  |
|      | `  -R %CD%/cygwin ^`                            | 指定 Cygwin 根目录为 `<当前git根>/cygwin`                                                                                                                                                     |                                                                  |
|      | `  -s http://cygwin.mirror.constant.com ^`      | 选定镜像站点（-s/site）                                                                                                                                                                      |                                                                  |
|      | `  -l %TEMP%/cygwin ^`                          | 把下载的包缓存到临时目录 %TEMP%\cygwin                                                                                                                                                           |                                                                  |
|      | `  -P "bison,flex,…perl-YAML-Tiny"`             | 一次性安装所列全部包（-P/--packages）([Stack Overflow][13], [Stack Overflow][14])                                                                                                                |                                                                  |
| 13   | `if defined CI echo ::endgroup::`               | 在 CI 日志里结束分组标签                                                                                                                                                                       |                                                                  |
| 15   | `copy bootstrap.sh cygwin\tmp`                  | 把随仓库提供的 bootstrap.sh 复制进 Cygwin 临时目录，方便后一步由 bash 执行                                                                                                                                  |                                                                  |
| 16   | `cygwin\bin\bash /tmp/bootstrap.sh %*`          | 用刚装好的 Cygwin bash 执行脚本，并把当前 cmd 收到的全部参数(`%*`)原样传递过去，实现后续构建步骤                                                                                                                         | OSGeo4W 的整个自动化构建随后都在类 POSIX 环境内完成。([trac.osgeo.org][15])         |

> **小提示**：如需在脚本中再插入注释，可直接在上述行前加 `REM` 或 `::`；若要临时禁用某行命令，也可在行首加 `::` 或 `REM`.

这样，bootstrap.cmd 完成了：①确保本地有 Cygwin 与所需包；②在 CI 环境输出可折叠日志段；③把控制权交给 bootstrap.sh 进入 POSIX 流水线。

[1]: https://serverfault.com/questions/17899/whats-the-difference-between-cmd-and-bat-files?utm_source=chatgpt.com "What's the difference between .cmd and .bat files? - Server Fault"
[2]: https://stackoverflow.com/questions/148968/windows-batch-files-bat-vs-cmd?utm_source=chatgpt.com "Windows batch files: .bat vs .cmd? - Stack Overflow"
[3]: https://superuser.com/questions/897644/how-does-windows-decide-which-executable-to-run?utm_source=chatgpt.com "How does windows decide which executable to run - Super User"
[4]: https://www.cygwin.com/faq/faq.html?utm_source=chatgpt.com "Cygwin FAQ"
[5]: https://stackoverflow.com/questions/605101/order-in-which-command-prompt-executes-files-with-the-same-name-a-bat-vs-a-cmd?utm_source=chatgpt.com "Order in which command prompt executes files with the same name ..."
[6]: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/rem?utm_source=chatgpt.com "rem | Microsoft Learn"
[7]: https://stackoverflow.com/questions/11269338/how-to-comment-out-add-comment-in-a-batch-cmd?utm_source=chatgpt.com "How to \"comment-out\" (add comment) in a batch/cmd?"
[8]: https://answers.microsoft.com/en-us/windows/forum/all/comments-in-batch-files/bb73da92-5bfc-41ff-9d59-c1b82de2c0d8?utm_source=chatgpt.com "Comments in batch files - Microsoft Community"
[9]: https://www.hexnode.com/mobile-device-management/help/script-to-create-a-new-folder-if-it-doesnt-exist-on-windows-10/?utm_source=chatgpt.com "Script to create a new folder if it doesn't exist on Windows 10"
[10]: https://stackoverflow.com/questions/69068/split-long-commands-in-multiple-lines-through-windows-batch-file?utm_source=chatgpt.com "Split long commands in multiple lines through Windows batch file"
[11]: https://superuser.com/questions/214831/how-to-update-cygwin-from-cygwins-command-line?utm_source=chatgpt.com "How to update Cygwin from Cygwin's command line? - Super User"
[12]: https://cygwin.readthedocs.io/en/stable/install/?utm_source=chatgpt.com "Install and maintain Cygwin"
[13]: https://stackoverflow.com/questions/9260014/how-do-i-install-cygwin-components-from-the-command-line?utm_source=chatgpt.com "How do I install cygwin components from the command line?"
[14]: https://stackoverflow.com/questions/44354169/how-to-install-g-in-cygwin?utm_source=chatgpt.com "How to install g++ in Cygwin? - Stack Overflow"
[15]: https://trac.osgeo.org/osgeo4w/wiki/SetupDevelopment?utm_source=chatgpt.com "SetupDevelopment – OSGeo4W - OSGeo Trac Instances"
