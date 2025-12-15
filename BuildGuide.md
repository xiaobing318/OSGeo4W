# 在 Windows 10 + Visual Studio 2022 上构建 QGIS 3.44.3

本指南基于 OSGeo4W package.sh 的逻辑，适配为原生 Windows 环境的手动构建流程。

## 前提条件

### 1. 已安装的软件

- **Visual Studio 2022**（需包含 C++ 桌面开发工作负载）
- **CMake** 3.20+（建议安装到 PATH）
- **Git for Windows**
- **OSGeo4W** 完整安装（包含所有 QGIS 依赖）

### 2. 目录结构

```
C:\OSGeo4W\                  # OSGeo4W 安装根目录
├── bin\                     # 工具和运行时
├── include\                 # 头文件
├── lib\                     # 库文件
├── apps\
│   ├── Qt5\                 # Qt 5 框架
│   └── Python312\           # Python 3.12
└── QGIS\                    # QGIS 源码（需下载）
    ├── CMakeLists.txt
    ├── src\
    └── ...
```

### 3. 验证依赖

打开 **OSGeo4W Shell**（开始菜单中），运行：

```bash
# 检查关键依赖
which python3     # 应显示：/cygdrive/c/OSGeo4W/bin/python3
which qmake       # 应显示：/cygdrive/c/OSGeo4W/apps/Qt5/bin/qmake
gdal-config --version  # 应显示 GDAL 版本，如 3.9.2
geos-config --version  # 应显示 GEOS 版本
```

---

## 步骤 1：获取 QGIS 3.44.3 源码

### 方式 A：使用 Git（推荐）

在 **OSGeo4W Shell** 中：

```bash
cd /cygdrive/c/OSGeo4W

# 如果已有 QGIS 目录，先清理
if [ -d QGIS ]; then
    cd QGIS
    git fetch --tags
    git clean -fd
    git reset --hard
    git checkout final-3_44_3
else
    # 首次克隆（约 1GB）
    git clone https://github.com/qgis/QGIS.git --branch final-3_44_3 --depth 1
    cd QGIS
fi
```

### 方式 B：下载源码包

1. 访问：https://github.com/qgis/QGIS/releases/tag/final-3_44_3
2. 下载 `qgis-3.44.3.tar.gz`
3. 解压到 `C:\OSGeo4W\QGIS\`

---

## 步骤 2：准备构建目录

在 **OSGeo4W Shell** 中：

```bash
cd /cygdrive/c/OSGeo4W
mkdir -p build-qgis
mkdir -p install-qgis

export BUILDDIR=/cygdrive/c/OSGeo4W/build-qgis
export INSTDIR=/cygdrive/c/OSGeo4W/install-qgis
export SRCDIR=/cygdrive/c/OSGeo4W/QGIS
export O4W_ROOT=/cygdrive/c/OSGeo4W
```

---

## 步骤 3：设置 Visual Studio 2022 环境

在 **OSGeo4W Shell** 中运行：

```bash
# 加载 VS 2022 环境变量
# 根据你的 VS 安装路径调整
call() { cmd /c "$@"; }
call '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat"' x64

# 或者使用 OSGeo4W 提供的工具
call "$(cygpath -w "$O4W_ROOT/bin/o4w_env.bat")"
```

**重要**：确认环境加载成功：

```bash
which cl.exe      # 应显示 VS 2022 的 cl.exe 路径
cl.exe 2>&1 | head -1  # 应显示：Microsoft (R) C/C++ Optimizing Compiler Version 19.4x
```

---

## 步骤 4：配置 CMake（核心步骤）

创建配置脚本 `C:\OSGeo4W\configure-qgis.sh`：

```bash
#!/bin/bash
# 配置 QGIS 3.44.3 构建

# 路径设置
export BUILDDIR=/cygdrive/c/OSGeo4W/build-qgis
export INSTDIR=/cygdrive/c/OSGeo4W/install-qgis
export SRCDIR=/cygdrive/c/OSGeo4W/QGIS
export O4W_ROOT=/cygdrive/c/OSGeo4W

# 清理旧构建（可选）
# rm -rf $BUILDDIR/*

cd $BUILDDIR

# 获取 GRASS 信息
GRASS_BAT=$(cygpath -aw "$O4W_ROOT/bin/grass*.bat")
GRASS_VERSION=$(cmd /c "$GRASS_BAT" --config version 2>&1 | tr -d '\r')
GRASS_PREFIX=$(cmd /c "$GRASS_BAT" --config path 2>&1 | tr -d '\r')

echo "========================================"
echo "QGIS 3.44.3 构建配置"
echo "========================================"
echo "源码目录: $SRCDIR"
echo "构建目录: $BUILDDIR"
echo "安装目录: $INSTDIR"
echo "OSGeo4W: $O4W_ROOT"
echo "GRASS: $GRASS_VERSION at $GRASS_PREFIX"
echo "========================================"

# 运行 CMake 配置
# 使用 Visual Studio 2022 生成器
cmake -G "Visual Studio 17 2022" -A x64 \
    -D CMAKE_CONFIGURATION_TYPES="RelWithDebInfo;Release;Debug" \
    -D CMAKE_CXX_FLAGS_RELWITHDEBINFO="/MD /Zi /O2 /Ob1 /DNDEBUG /std:c++17 /permissive-" \
    -D CMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO="/DEBUG /INCREMENTAL:NO /OPT:REF /OPT:ICF" \
    -D CMAKE_MODULE_LINKER_FLAGS_RELWITHDEBINFO="/DEBUG /INCREMENTAL:NO /OPT:REF /OPT:ICF" \
    \
    -D CMAKE_INSTALL_PREFIX="$(cygpath -am $INSTDIR)" \
    -D CMAKE_PREFIX_PATH="$(cygpath -am $O4W_ROOT)" \
    \
    -D ENABLE_TESTS=FALSE \
    -D WITH_QSPATIALITE=TRUE \
    -D WITH_SERVER=TRUE \
    -D WITH_3D=TRUE \
    -D WITH_PDAL=TRUE \
    -D WITH_GRASS=TRUE \
    -D WITH_GRASS8=TRUE \
    -D WITH_ORACLE=FALSE \
    -D WITH_HANA=FALSE \
    -D WITH_CUSTOM_WIDGETS=TRUE \
    \
    -D GRASS_PREFIX8="$(cygpath -m "$GRASS_PREFIX")" \
    \
    -D PROJ_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/include)" \
    -D PROJ_LIBRARY="$(cygpath -am $O4W_ROOT/lib/proj.lib)" \
    \
    -D GEOS_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/include)" \
    -D GEOS_LIBRARY="$(cygpath -am $O4W_ROOT/lib/geos_c.lib)" \
    \
    -D GDAL_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/include)" \
    -D GDAL_LIBRARY="$(cygpath -am $O4W_ROOT/lib/gdal_i.lib)" \
    \
    -D SQLITE3_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/include)" \
    -D SQLITE3_LIBRARY="$(cygpath -am $O4W_ROOT/lib/sqlite3_i.lib)" \
    \
    -D SPATIALITE_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/include)" \
    -D SPATIALITE_LIBRARY="$(cygpath -am $O4W_ROOT/lib/spatialite_i.lib)" \
    \
    -D SPATIALINDEX_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/include/spatialindex)" \
    -D SPATIALINDEX_LIBRARY="$(cygpath -am $O4W_ROOT/lib/spatialindex-64.lib)" \
    \
    -D POSTGRES_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/include)" \
    -D POSTGRES_LIBRARY="$(cygpath -am $O4W_ROOT/lib/libpq.lib)" \
    \
    -D EXPAT_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/include)" \
    -D EXPAT_LIBRARY="$(cygpath -am $O4W_ROOT/lib/expat.lib)" \
    \
    -D GSL_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/include)" \
    -D GSL_LIBRARY="$(cygpath -am $O4W_ROOT/lib/gsl.lib)" \
    -D GSL_CBLAS_LIBRARY="$(cygpath -am $O4W_ROOT/lib/gslcblas.lib)" \
    \
    -D LIBZIP_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/include)" \
    -D LIBZIP_LIBRARY="$(cygpath -am $O4W_ROOT/lib/zip.lib)" \
    \
    -D ZSTD_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/include)" \
    -D ZSTD_LIBRARY="$(cygpath -am $O4W_ROOT/lib/zstd.lib)" \
    \
    -D EXIV2_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/include)" \
    -D EXIV2_LIBRARY="$(cygpath -am $O4W_ROOT/lib/exiv2.lib)" \
    \
    -D PROTOBUF_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/include)" \
    -D PROTOBUF_LIBRARY="$(cygpath -am $O4W_ROOT/lib/libprotobuf.lib)" \
    -D PROTOBUF_PROTOC_EXECUTABLE="$(cygpath -am $O4W_ROOT/bin/protoc.exe)" \
    \
    -D HDF5_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/include)" \
    -D HDF5_C_LIBRARY="$(cygpath -am $O4W_ROOT/lib/hdf5.lib)" \
    -D HDF5_HL_LIBRARY="$(cygpath -am $O4W_ROOT/lib/hdf5_hl.lib)" \
    \
    -D NETCDF_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/include)" \
    -D NETCDF_LIBRARY="$(cygpath -am $O4W_ROOT/lib/netcdf.lib)" \
    \
    -D PDAL_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/include)" \
    -D PDAL_LIBRARY="$(cygpath -am $O4W_ROOT/lib/pdal.lib)" \
    \
    -D DRACO_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/include)" \
    -D DRACO_LIBRARY="$(cygpath -am $O4W_ROOT/lib/draco.lib)" \
    \
    -D Python_ROOT_DIR="$(cygpath -am $O4W_ROOT/apps/Python312)" \
    -D Python_EXECUTABLE="$(cygpath -am $O4W_ROOT/bin/python3.exe)" \
    -D Python_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/apps/Python312/include)" \
    -D Python_LIBRARY="$(cygpath -am $O4W_ROOT/apps/Python312/libs/python312.lib)" \
    \
    -D SIP_MODULE_EXECUTABLE="$(cygpath -am $O4W_ROOT/apps/Python312/Scripts/sip-module.exe)" \
    -D PYUIC_PROGRAM="$(cygpath -am $O4W_ROOT/apps/Python312/Scripts/pyuic5.exe)" \
    -D PYRCC_PROGRAM="$(cygpath -am $O4W_ROOT/apps/Python312/Scripts/pyrcc5.exe)" \
    \
    -D Qt5_DIR="$(cygpath -am $O4W_ROOT/apps/Qt5/lib/cmake/Qt5)" \
    -D QT_LIBRARY_DIR="$(cygpath -am $O4W_ROOT/apps/Qt5/lib)" \
    -D QT_HEADERS_DIR="$(cygpath -am $O4W_ROOT/apps/Qt5/include)" \
    -D QT_BINARY_DIR="$(cygpath -am $O4W_ROOT/apps/Qt5/bin)" \
    \
    -D QCA_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/apps/Qt5/include/QtCrypto)" \
    -D QCA_LIBRARY="$(cygpath -am $O4W_ROOT/apps/Qt5/lib/qca-qt5.lib)" \
    \
    -D QWT_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/apps/Qt5/include/qwt)" \
    -D QWT_LIBRARY="$(cygpath -am $O4W_ROOT/apps/Qt5/lib/qwt.lib)" \
    \
    -D QSCINTILLA_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/apps/Qt5/include)" \
    -D QSCINTILLA_LIBRARY="$(cygpath -am $O4W_ROOT/apps/Qt5/lib/qscintilla2.lib)" \
    \
    -D QT_WEBKIT_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/apps/Qt5/include/QtWebKit)" \
    -D QT_WEBKIT_LIBRARY="$(cygpath -am $O4W_ROOT/apps/Qt5/lib/Qt5WebKit.lib)" \
    \
    -D QT_WEBKITWIDGETS_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/apps/Qt5/include/QtWebKitWidgets)" \
    -D QT_WEBKITWIDGETS_LIBRARY="$(cygpath -am $O4W_ROOT/apps/Qt5/lib/Qt5WebKitWidgets.lib)" \
    \
    -D QTKEYCHAIN_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/include/qt5keychain)" \
    -D QTKEYCHAIN_LIBRARY="$(cygpath -am $O4W_ROOT/lib/qt5keychain.lib)" \
    \
    -D FCGI_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/include)" \
    -D FCGI_LIBRARY="$(cygpath -am $O4W_ROOT/lib/libfcgi.lib)" \
    \
    -D OPENCL_INCLUDE_DIR="$(cygpath -am $O4W_ROOT/include)" \
    -D OPENCL_LIBRARY="$(cygpath -am $O4W_ROOT/lib/OpenCL.lib)" \
    \
    "$(cygpath -am $SRCDIR)"

echo ""
echo "========================================"
echo "配置完成！"
echo "========================================"
echo "下一步："
echo "  1. 检查 CMake 输出是否有错误"
echo "  2. 运行: bash build-qgis.sh"
echo "========================================"
```

运行配置：

```bash
cd /cygdrive/c/OSGeo4W
bash configure-qgis.sh 2>&1 | tee configure.log
```

**检查配置输出**：

- 查找 "CMake Error" 或 "Could NOT find"
- 确认所有库都被找到
- 如有缺失，调整对应的 `-D` 参数

---

## 步骤 5：编译 QGIS

创建构建脚本 `C:\OSGeo4W\build-qgis.sh`：

```bash
#!/bin/bash

export BUILDDIR=/cygdrive/c/OSGeo4W/build-qgis

cd $BUILDDIR

echo "========================================"
echo "开始编译 QGIS 3.44.3"
echo "时间: $(date)"
echo "========================================"

# 使用 MSBuild 构建（Visual Studio 2022）
cmake --build . --config RelWithDebInfo --parallel

BUILD_RESULT=$?

echo ""
echo "========================================"
if [ $BUILD_RESULT -eq 0 ]; then
    echo "✓ 编译成功！"
    echo "========================================"
    echo "下一步："
    echo "  运行: bash install-qgis.sh"
else
    echo "✗ 编译失败！"
    echo "========================================"
    echo "请检查错误信息，常见问题："
    echo "  1. 缺少依赖库"
    echo "  2. 路径配置错误"
    echo "  3. VS 环境未正确加载"
fi
echo "========================================"

exit $BUILD_RESULT
```

运行编译：

```bash
cd /cygdrive/c/OSGeo4W
bash build-qgis.sh 2>&1 | tee build.log
```

**编译时间**：根据 CPU，通常需要 30-90 分钟。

**并行编译**：如果内存充足（16GB+），可以增加并行度：

```bash
cmake --build . --config RelWithDebInfo --parallel 16
```

---

## 步骤 6：安装 QGIS

创建安装脚本 `C:\OSGeo4W\install-qgis.sh`：

```bash
#!/bin/bash

export BUILDDIR=/cygdrive/c/OSGeo4W/build-qgis
export INSTDIR=/cygdrive/c/OSGeo4W/install-qgis

cd $BUILDDIR

echo "========================================"
echo "安装 QGIS 到: $INSTDIR"
echo "========================================"

# 清理旧安装
rm -rf $INSTDIR/*

# 执行安装
cmake --install . --config RelWithDebInfo

echo ""
echo "========================================"
echo "✓ 安装完成！"
echo "========================================"
echo "QGIS 文件位于: $INSTDIR"
echo ""
echo "下一步："
echo "  运行: bash create-launcher.sh"
echo "========================================"
```

运行安装：

```bash
cd /cygdrive/c/OSGeo4W
bash install-qgis.sh
```

---

## 步骤 7：创建启动脚本

QGIS 需要正确的环境变量才能运行。创建 `C:\OSGeo4W\qgis-launch.bat`：

```batch
@echo off
REM QGIS 3.44.3 启动脚本

REM 设置 OSGeo4W 环境
call "C:\OSGeo4W\bin\o4w_env.bat"

REM 设置 QGIS 路径
set QGIS_PREFIX_PATH=C:\OSGeo4W\install-qgis
set PATH=%QGIS_PREFIX_PATH%\bin;%PATH%

REM 设置 Qt 插件路径
set QT_PLUGIN_PATH=%QGIS_PREFIX_PATH%\qtplugins;%OSGEO4W_ROOT%\apps\Qt5\plugins

REM 设置 Python 路径
set PYTHONPATH=%QGIS_PREFIX_PATH%\python;%PYTHONPATH%

REM 设置 GDAL 数据
set GDAL_DATA=%OSGEO4W_ROOT%\share\gdal
set PROJ_LIB=%OSGEO4W_ROOT%\share\proj

REM 设置 GRASS
set GRASS_PREFIX=%OSGEO4W_ROOT%\apps\grass\grass84

REM 启动 QGIS
echo ========================================
echo 启动 QGIS 3.44.3
echo ========================================
echo QGIS: %QGIS_PREFIX_PATH%
echo OSGeo4W: %OSGEO4W_ROOT%
echo ========================================
echo.

"%QGIS_PREFIX_PATH%\bin\qgis.exe" %*

if errorlevel 1 (
    echo.
    echo ========================================
    echo QGIS 启动失败！
    echo ========================================
    pause
)
```

创建对应的 bash 版本 `create-launcher.sh`：

```bash
#!/bin/bash

cat > /cygdrive/c/OSGeo4W/qgis-launch.bat <<'EOF'
@echo off
call "C:\OSGeo4W\bin\o4w_env.bat"
set QGIS_PREFIX_PATH=C:\OSGeo4W\install-qgis
set PATH=%QGIS_PREFIX_PATH%\bin;%PATH%
set QT_PLUGIN_PATH=%QGIS_PREFIX_PATH%\qtplugins;%OSGEO4W_ROOT%\apps\Qt5\plugins
set PYTHONPATH=%QGIS_PREFIX_PATH%\python;%PYTHONPATH%
set GDAL_DATA=%OSGEO4W_ROOT%\share\gdal
set PROJ_LIB=%OSGEO4W_ROOT%\share\proj
"%QGIS_PREFIX_PATH%\bin\qgis.exe" %*
EOF

chmod +x /cygdrive/c/OSGeo4W/qgis-launch.bat

echo "启动脚本已创建: C:\OSGeo4W\qgis-launch.bat"
echo ""
echo "使用方法："
echo "  双击 qgis-launch.bat 启动 QGIS"
```

运行：

```bash
bash create-launcher.sh
```

---

## 步骤 8：启动 QGIS

### 方式 A：使用启动脚本（推荐）

双击 `C:\OSGeo4W\qgis-launch.bat`

### 方式 B：从 OSGeo4W Shell

```bash
cd /cygdrive/c/OSGeo4W/install-qgis/bin
export PATH=$PWD:$PATH
export QT_PLUGIN_PATH=$PWD/../qtplugins:$OSGEO4W_ROOT/apps/Qt5/plugins
export PYTHONPATH=$PWD/../python

./qgis.exe
```

---

## 常见问题排查

### 问题 1：CMake 找不到库

**症状**：
```
Could NOT find GDAL (missing: GDAL_LIBRARY)
```

**解决**：
```bash
# 检查库文件是否存在
ls -l /cygdrive/c/OSGeo4W/lib/gdal_i.lib

# 如果不存在，需要安装对应的 -devel 包
cd /cygdrive/c/OSGeo4W
setup-x86_64.exe -q -P gdal-devel
```

### 问题 2：编译错误 - 找不到头文件

**症状**：
```
fatal error C1083: Cannot open include file: 'gdal.h'
```

**解决**：
在 `configure-qgis.sh` 中添加：

```bash
-D CMAKE_INCLUDE_PATH="$(cygpath -am $O4W_ROOT/include)" \
```

### 问题 3：链接错误 - 未解析的外部符号

**症状**：
```
error LNK2001: unresolved external symbol "QgsProviderRegistry::instance"
```

**解决**：通常是库路径问题，检查：

```bash
-D CMAKE_LIBRARY_PATH="$(cygpath -am $O4W_ROOT/lib)" \
```

### 问题 4：QGIS 启动崩溃

**症状**：启动后立即崩溃，无错误提示

**解决**：

1. 检查依赖 DLL：
   ```bash
   cd /cygdrive/c/OSGeo4W/install-qgis/bin
   ldd qgis.exe | grep "not found"
   ```

2. 复制缺失的 DLL 到 `install-qgis/bin/`

3. 或调整 PATH：
   ```batch
   set PATH=C:\OSGeo4W\bin;C:\OSGeo4W\apps\Qt5\bin;%PATH%
   ```

### 问题 5：Python 插件不工作

**症状**：无法加载 Python 插件

**解决**：

1. 检查 PYTHONPATH：
   ```bash
   echo $PYTHONPATH
   # 应包含: C:\OSGeo4W\install-qgis\python
   ```

2. 测试 Python 绑定：
   ```python
   python3 -c "from qgis.core import QgsApplication; print('OK')"
   ```

### 问题 6：缺少 Qt 插件

**症状**：
```
QSqlDatabase: QSQLITE driver not loaded
```

**解决**：

1. 复制 Qt 插件：
   ```bash
   mkdir -p /cygdrive/c/OSGeo4W/install-qgis/qtplugins
   cp -r /cygdrive/c/OSGeo4W/apps/Qt5/plugins/* /cygdrive/c/OSGeo4W/install-qgis/qtplugins/
   ```

2. 设置环境变量：
   ```batch
   set QT_PLUGIN_PATH=C:\OSGeo4W\install-qgis\qtplugins
   ```

---

## 高级选项

### 启用更多功能

编辑 `configure-qgis.sh`，取消注释或添加：

```bash
# Oracle 支持（需要安装 Oracle Instant Client）
-D WITH_ORACLE=TRUE \
-D ORACLE_INCLUDEDIR="C:/oracle/instantclient/sdk/include" \
-D ORACLE_LIBRARY="C:/oracle/instantclient/oci.lib" \

# SAP HANA 支持
-D WITH_HANA=TRUE \

# EPT (点云) 支持
-D WITH_EPT=TRUE \
```

### 优化编译速度

```bash
# 使用 ccache（需要先安装）
-D CMAKE_CXX_COMPILER_LAUNCHER=ccache \

# 减少调试信息大小
-D CMAKE_CXX_FLAGS_RELWITHDEBINFO="/MD /Zi /O2 /DNDEBUG /std:c++17" \
```

### 创建 Debug 版本

```bash
# 在 configure-qgis.sh 中改为
-D CMAKE_BUILD_TYPE=Debug \
-D CMAKE_CONFIGURATION_TYPES="Debug" \

# 编译时
cmake --build . --config Debug
```

---

## 总结

按照以上步骤，你应该能够：

1. ✅ 在 Windows 10 + VS 2022 环境下构建 QGIS 3.44.3
2. ✅ 使用已安装的 OSGeo4W 依赖库
3. ✅ 创建可运行的 QGIS 程序

**关键点**：

- 所有库路径必须指向 `C:\OSGeo4W`
- 使用 `cygpath` 转换路径格式
- 正确设置运行时环境变量

**后续**：

- 如需打包分发，参考 package.sh 的打包逻辑（步骤 9）
- 如需在 Visual Studio 2022 IDE 中调试：
  1. 打开 `C:\OSGeo4W\build-qgis\QGIS.sln`
  2. 右键点击 `qgis` 项目 -> 设为启动项目
  3. 配置调试环境变量（项目属性 -> 调试 -> 环境）
  4. 按 F5 开始调试
- 如需修改源码，直接编辑 `C:\OSGeo4W\QGIS\` 后重新编译或在 VS 2022 中修改并编译

祝构建顺利！🎉