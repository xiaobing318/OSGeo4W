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
