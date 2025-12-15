# OSGeo4W - Open Source Geospatial for Windows

OSGeo4W 是一个面向 Windows 平台的开源地理空间软件二进制发行版构建系统。它提供了一个完整的、可扩展的地理信息系统（GIS）软件栈，包括 QGIS、GDAL、GRASS GIS 等核心地理空间工具及其所有依赖库。
 - OSGeo4W 是一个二进制发行版的构建系统
 - OSGeo4W 面向 Windows 平台而不是其他平台
 - 操作对象是开源地理空间软件
   - QGIS
   - GDAL
   - GRASS GIS
   - 等等
---

## 项目概述

本项目是一个自动化构建系统，用于编译、打包和分发超过 380 个地理空间相关的软件包。它使用 Cygwin 环境在 Windows 上构建这些软件包，并生成可安装的二进制分发包。

### 主要特性

- **完整的构建系统**：自动化编译从底层库到高层应用的整个软件栈
- **依赖管理**：智能处理包之间的依赖关系，支持按正确顺序构建
- **许可证合规**：严格的许可证审核和追踪机制
- **CI/CD 集成**：目前还不支持或者说不成熟
- **架构支持**：支持 x86_64 架构的 Windows 系统，目前针对 Windows 10/11

## 目录结构详解

### 根目录文件

#### `acceptable.lst`
**用途**：许可证合规性管理文件

这是一个关键的许可证审核清单，包含所有已批准使用的第三方库许可证的 MD5 哈希值。格式为每行一个条目：
```
<MD5哈希值> <包名/许可证类型>
```

**作用**：
- 记录每个软件包许可证文件的 MD5 指纹
- 用于验证许可证文本未被篡改
- 当软件包更新时，如果许可证变更会被检测到
- 确保项目的法律合规性，防止意外引入不兼容的许可证

**示例条目**：
```
067e9870bba57e1ce20695c4d5672f30 libzip
1ebbd3e34237af26da5dc08a4e440464 GPL 3
3b83ef96387f14655fc854ddc3c6bd57 Apache License 2.0
```

包含的主要许可证类型包括：GPL (2/3)、LGPL、BSD、MIT、Apache 2.0、PostgreSQL License 等。

#### `bootstrap.sh`
**用途**：Linux/Cygwin 环境下的项目引导脚本

**功能**：
- 设置安全的 PATH 环境变量（仅包含系统关键路径）
- 配置 Git 仓库设置（默认从 `https://github.com/jef-n/OSGeo4W` 克隆）
- 初始化或更新 Git 仓库
- 自动拉取最新代码（非 CI 环境下）
- 调用主构建脚本 `scripts/build.sh`

**环境变量**：
- `O4W_GIT_REPO`：Git 仓库 URL（默认：https://github.com/jef-n/OSGeo4W）
- `O4W_GIT_BRANCH`：要检出的分支（默认：master）
- `CI`：CI 环境标志，设置后跳过 git pull

**使用方式**：
```bash
bash bootstrap.sh [包名...]
```

#### `bootstrap.cmd`
**用途**：Windows 原生环境下的引导脚本

**功能**：
- 自动下载并安装 Cygwin 环境（如果不存在）
- 安装构建所需的所有 Cygwin 包：
  - 编译工具：`bison`, `flex`, `make`, `gcc`, `binutils`
  - 文档工具：`doxygen`, `poppler`, `catdoc`, `enscript`
  - 实用工具：`git`, `curl`, `wget`, `tar`, `unzip`, `patch`, `p7zip`
  - 脚本语言：`perl`, `ruby=2.6.4-1`, `perl-Data-UUID`, `perl-YAML-Tiny`
  - 代码签名：`osslsigncode`
- 配置 Cygwin 镜像源（默认：http://cygwin.mirror.constant.com）
- 将 `bootstrap.sh` 复制到 Cygwin 临时目录并执行

**使用方式**：
```cmd
bootstrap.cmd [包名...]
```

**输出**：
- 在 CI 环境中，使用 `::group::` 标记输出以便折叠
- Cygwin 安装在项目目录的 `cygwin/` 子目录中

### 主要目录

#### `.git/`
标准的 Git 版本控制目录，包含仓库的所有历史记录、分支、标签等元数据。

**当前分支**：`master-learning-20250924`
**主分支**：`master`

#### `.github/`
GitHub 特定配置目录

**内容**：
- `workflows/build-packages.yml`：GitHub Actions 工作流配置

**工作流功能**：
- 手动触发包构建（workflow_dispatch）
- 可配置参数：
  - `packages`：要构建的包列表（默认：qgis-dev）
  - `buildmsi`：是否构建 MSI 安装包
  - `forcebuild`：强制重新构建即使包已存在
  - `skiptests`：跳过测试
  - `buildrdeps`：构建反向依赖
  - `skipmasterrepo`：不从主仓库下载依赖
  - `continuebuild`：构建失败后继续

#### `.vscode/`
Visual Studio Code 编辑器配置目录

包含项目特定的 VSCode 设置、调试配置、扩展推荐等。这使得团队成员可以使用统一的开发环境配置。

#### `scripts/`
构建系统核心脚本目录，包含所有自动化构建、打包、上传相关的工具脚本

**主要脚本文件**：

##### `build.sh`
**核心构建脚本**，负责协调整个构建流程

**主要功能**：
- 确定构建仓库位置（`OSGEO4W_REP`）
- 处理分支特定的构建逻辑
- 支持按依赖顺序构建包（通过 `build-inorder.pl`）
- 管理构建状态（记录已完成的包）
- 错误处理和构建日志

**环境变量**：
- `OSGEO4W_REP`：本地包仓库路径
- `OSGEO4W_SKIP_UPLOAD`：跳过上传（默认：1）
- `OSGEO4W_SKIP_CLEAN`：跳过清理（默认：1）
- `OSGEO4W_BUILD_RDEPS`：构建反向依赖（默认：1）
- `OSGEO4W_CONTINUE_BUILD`：构建失败后继续（默认：0）
- `OSGEO4W_SKIP_MASTER_REPO`：跳过主仓库（默认：0）

**工作流程**：
1. 加载环境配置（`.buildenv`）
2. 解析依赖关系，确定构建顺序
3. 遍历包列表，依次构建
4. 进入 `src/<包名>/osgeo4w/` 目录
5. 执行 `package.sh` 脚本
6. 记录构建状态到 `tmp/<包名>.done`

##### `build-helpers`
**构建辅助函数库**，定义了大量构建过程中使用的通用函数和变量

**核心配置**：
- `MASTER_HOST=download.osgeo.org`：主仓库主机
- `MASTER_BASE=osgeo4w/v2`：仓库基础路径
- `MASTER_REPO`：主仓库完整 URL
- `MASTER_SCP`：上传目标 SCP 地址
- `PYTHON=Python312`：默认 Python 版本
- `CCACHE_CACHE_SIZE=50G`：编译缓存大小

**主要函数**：
- `savelog()`：日志文件轮转（保留最近 10 个版本）
- `log()`：带时间戳的日志输出
- `startlog()`：初始化日志系统，设置环境
- 其他构建辅助函数（需要查看完整文件以了解）

##### `build-inorder.pl`
**依赖关系解析脚本**（Perl）

功能：分析包之间的依赖关系，生成正确的构建顺序。确保依赖库在使用它们的包之前被构建。

##### `genini`
**生成 setup.ini 文件的脚本**

setup.ini 是 OSGeo4W 安装器使用的包索引文件，包含所有包的元数据、版本、依赖关系等信息。

##### `createmsi.pl`
**MSI 安装包生成脚本**（Perl）

使用 WiX Toolset 创建 Windows Installer (MSI) 包，用于分发 QGIS 等主要应用。

##### `msis.sh`
**MSI 构建自动化脚本**

批量生成多个包的 MSI 安装包。

##### `upload.sh` / `upload.pl`
**包上传脚本**

将构建完成的包上传到 OSGeo4W 主仓库（download.osgeo.org）。

##### `regen.sh`
**仓库重新生成脚本**

触发远程服务器重新生成包索引和仓库元数据。

##### `lint.sh`
**代码质量检查脚本**

对构建脚本和包配置进行静态分析，检查常见问题。

##### `pippkg.py`
**Python 包打包工具**

将 PyPI 上的 Python 包转换为 OSGeo4W 格式的包。

##### `pyshebangcheck.sh`
**Python shebang 检查工具**

确保 Python 脚本的 shebang 行（`#!/usr/bin/env python`）在 Windows 环境下正确。

##### `QGISInstallDirDlg.wxs` / `QGISUI_InstallDir.wxs`
**WiX 对话框定义文件**（XML）

定义 QGIS MSI 安装程序中的自定义对话框界面。

#### `src/`
**软件包源代码和构建定义目录**

这是项目的核心，包含 **383 个**地理空间软件包的构建定义。每个包都有自己的子目录。

**目录结构**：
```
src/
├── <包名>/
│   └── osgeo4w/
│       ├── package.sh        # 构建脚本
│       ├── *.patch           # 补丁文件（可选）
│       ├── depends           # 依赖声明（可选）
│       └── 其他构建资源
```

**主要软件包类别**：

1. **核心 GIS 应用**：
   - `qgis*`：QGIS 桌面 GIS 软件（多个版本）
   - `grass*`：GRASS GIS
   - `gdal*`：地理空间数据抽象库
   - `saga`：SAGA GIS

2. **地理空间库**：
   - `geos`：几何引擎
   - `proj`：坐标转换库
   - `libgeotiff`：GeoTIFF 支持
   - `libspatialite`：SQLite 空间扩展
   - `netcdf`：网络通用数据格式

3. **基础库**：
   - `boost`：C++ 工具库
   - `curl`：HTTP 客户端库
   - `openssl`：加密库
   - `zlib`：压缩库
   - `libpng`, `libjpeg-turbo`, `libtiff`：图像库
   - `libxml2`, `libxslt`：XML 处理
   - `icu`：国际化组件

4. **数据库**：
   - `libpq`：PostgreSQL 客户端库
   - `libmysql`：MySQL 客户端库
   - `sqlite3`：SQLite 数据库
   - `msodbcsql`：MS SQL Server ODBC 驱动

5. **Python 生态**：
   - `python3-*`：超过 200 个 Python 包
   - 包括：numpy, scipy, pandas, matplotlib, jupyter 等

6. **Web 服务**：
   - `apache`：Apache HTTP 服务器
   - `mod_fcgid`：FastCGI 模块
   - `node`：Node.js 运行时
   - `qwc-services`：QGIS Web Client 服务

7. **开发工具**：
   - `*-devel`：开发头文件和库
   - `*-dev`：开发版本包

**每个包的 `package.sh` 脚本**通常包含：
- 源码下载逻辑
- 配置和编译命令
- 补丁应用
- 文件安装和打包
- 依赖声明
- 许可证文件处理

### 临时/生成目录（通常在 .gitignore 中）

虽然在当前目录列表中不可见，但构建过程会生成以下目录：

- `tmp/`：构建状态文件（`*.done` 标记）
- `cygwin/`：Cygwin 安装目录（通过 bootstrap.cmd 创建）
- `package.log`：当前构建日志
- `package.log.0` - `package.log.9`：历史日志备份

## 构建流程

### 快速开始

**在 Windows 上**：
```cmd
# 方式 1: 从 Windows 命令行启动
bootstrap.cmd gdal qgis-dev

# 方式 2: 在已安装的 Cygwin 中
bash bootstrap.sh gdal qgis-dev
```

**在 Linux/Cygwin 上**：
```bash
bash bootstrap.sh gdal qgis-dev
```

### 详细构建流程

1. **环境初始化**：
   - `bootstrap.cmd` 安装 Cygwin（仅首次）
   - 设置 Git 仓库
   - 更新代码

2. **依赖解析**：
   - `build-inorder.pl` 分析依赖关系
   - 生成构建顺序列表

3. **包构建循环**：
   对于每个包：
   - 进入 `src/<包名>/osgeo4w/`
   - 加载 `build-helpers` 函数库
   - 执行 `package.sh`：
     - 下载源码
     - 应用补丁
     - 配置编译选项
     - 编译源码
     - 创建包文件
     - 验证许可证
   - 记录构建完成状态

4. **包上传**（可选）：
   - 上传到 OSGeo4W 仓库
   - 触发仓库索引重新生成

5. **MSI 生成**（可选）：
   - 使用 WiX 创建安装程序
   - 代码签名

## 包格式

OSGeo4W 使用自定义的包格式，类似于 Cygwin 的包系统：

- **包文件**：`.tar.bz2` 压缩档案
- **元数据**：setup.hint 文件（包含在包中）
- **命名规则**：`<包名>-<版本>-<构建号>.tar.bz2`

**setup.hint 示例**：
```
sdesc: "Geospatial Data Abstraction Library"
ldesc: "GDAL is a translator library for raster and vector geospatial data formats"
category: Libs
requires: libcurl zlib libpng libjpeg-turbo
maintainer: OSGeo4W Team
```

## 许可证管理

项目对许可证合规性有严格要求：

1. **审核流程**：
   - 所有新包必须提供许可证文件
   - 许可证经审核后，其 MD5 哈希添加到 `acceptable.lst`
   - 后续构建会验证许可证未变更

2. **支持的许可证类型**：
   - 开源许可证：GPL, LGPL, BSD, MIT, Apache, PostgreSQL License
   - 特殊许可证：Qt Commercial, Oracle OCI, Microsoft ODBC
   - 部分包使用双重许可

3. **许可证冲突检测**：
   构建系统会检测不兼容的许可证组合（如 GPL 与专有许可）

## 高级配置

### 环境变量

构建行为可通过环境变量自定义：

- `OSGEO4W_REP`：本地仓库路径
- `OSGEO4W_SKIP_UPLOAD=1`：不上传包
- `OSGEO4W_SKIP_CLEAN=1`：不清理构建目录
- `OSGEO4W_BUILD_RDEPS=1`：构建反向依赖
- `OSGEO4W_CONTINUE_BUILD=1`：忽略构建错误继续
- `TX_TOKEN`：Transifex API 令牌（用于翻译）
- `PYTHON=Python312`：Python 版本选择

### 自定义构建环境

创建 `.buildenv` 文件（在项目根目录）：
```bash
export OSGEO4W_SKIP_UPLOAD=0
export TX_TOKEN="your-transifex-token"
export CCACHE_DIR=/custom/ccache/dir
```

## CI/CD 集成

GitHub Actions 工作流提供自动化构建：

**触发方式**：
- 手动触发：GitHub 仓库页面 -> Actions -> Build OSGeo4W packages -> Run workflow
- 配置包名、构建选项等参数

**构建环境**：
- Windows Server 2019/2022
- 自动安装 Cygwin 和依赖
- 构建产物上传到 OSGeo4W 仓库

## 开发指南

### 添加新包

1. 在 `src/` 下创建新目录：
   ```bash
   mkdir -p src/mynewlib/osgeo4w
   cd src/mynewlib/osgeo4w
   ```

2. 创建 `package.sh`：
   ```bash
   export P=mynewlib
   export V=1.0.0
   export B=next
   export MAINTAINER=yourname
   export BUILDDEPENDS="libcurl zlib"

   source $OSGEO4W_SCRIPTS/build-helpers

   startlog

   # 下载源码
   [ -f $P-$V.tar.gz ] || wget https://example.com/$P-$V.tar.gz

   # 解压和构建
   tar xzf $P-$V.tar.gz
   cd $P-$V

   # 配置
   ./configure --prefix=/opt/osgeo4w

   # 编译
   make -j$(nproc)

   # 安装
   make install DESTDIR=$OSGEO4W_PKG

   # 创建包
   endlog
   ```

3. 添加许可证到 `acceptable.lst`：
   ```bash
   md5sum LICENSE >> ../../acceptable.lst
   ```

4. 测试构建：
   ```bash
   bash ../../scripts/build.sh mynewlib
   ```

### 包维护

- **版本更新**：修改 `package.sh` 中的 `V` 变量
- **补丁管理**：将补丁文件放在 `osgeo4w/*.patch`，构建脚本中应用
- **依赖更新**：更新 `BUILDDEPENDS` 和运行时依赖声明

## 常见问题

### 构建失败排查

1. **检查日志**：
   ```bash
   cat package.log
   ```

2. **依赖缺失**：
   确保所有依赖包已构建或从主仓库下载

3. **路径问题**：
   Windows 长路径限制，确保启用长路径支持

4. **许可证问题**：
   许可证 MD5 不匹配，需重新审核并更新 `acceptable.lst`

### 清理构建环境

```bash
# 清理所有构建状态
rm -rf tmp/

# 清理特定包的状态
rm tmp/mynewlib.done
```

## 相关资源

- **官方网站**：https://trac.osgeo.org/osgeo4w/
- **下载页面**：https://download.osgeo.org/osgeo4w/v2/
- **源码仓库**：https://github.com/jef-n/OSGeo4W
- **问题追踪**：GitHub Issues
- **邮件列表**：OSGeo4W 邮件列表

## 项目统计

- **软件包总数**：383 个
- **Python 包**：200+ 个
- **核心 GIS 应用**：QGIS, GRASS, SAGA, MapServer
- **支持的架构**：x86_64 Windows
- **许可证类型**：30+ 种开源许可证

## 贡献指南

欢迎贡献！提交 Pull Request 前请确保：

1. 所有新包都有有效的许可证
2. 构建脚本遵循项目约定
3. 依赖关系正确声明
4. 在本地成功构建
5. 不引入长路径或特殊字符问题

## 维护团队

- **主要维护者**：Jürgen Fischer (jef-n)
- **贡献者**：OSGeo 社区

## 许可证

项目构建系统本身采用 GPL 2.0 许可证。各软件包遵循各自的许可证（见 `acceptable.lst`）。

---

**最后更新**：2025-09-30
**版本**：OSGeo4W v2