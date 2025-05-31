export P=netcdf
export V=4.9.2
export B=next
export MAINTAINER=JuergenFischer
export BUILDDEPENDS="hdf4-devel hdf5-devel curl-devel zlib-devel hdf5-tools szip-devel bzip2-devel zstd-devel libxml2-devel"
export PACKAGES="netcdf netcdf-devel netcdf-tools"

source ../../../scripts/build-helpers

startlog

[ -f $P-c-$V.tar.gz ] || wget https://downloads.unidata.ucar.edu/$P-c/$V/$P-c-$V.tar.gz
[ -f ../$P-c-$V/CMakeLists.txt ] || tar -C .. -xzf $P-c-$V.tar.gz

if ! [ -f ../$P-c-$V/patched ]; then
	patch -d ../$P-c-$V -p0 <<EOF
--- ../CMakeLists.txt	2016-11-21 19:27:08.000000000 +0100
+++ CMakeLists.txt	2017-05-21 18:55:29.046949000 +0200
@@ -110,7 +110,7 @@
 
 # Enable 'dist and distcheck'.
 # File adapted from http://ensc.de/cmake/FindMakeDist.cmake
-FIND_PACKAGE(MakeDist)
+# FIND_PACKAGE(MakeDist)
 # End 'enable dist and distcheck'
 
 # Set the build type.
@@ -1661,8 +1661,8 @@
 print_conf_summary()
 
 # Enable Makedist files.
-ADD_MAKEDIST()
-ENABLE_MAKEDIST(README.md COPYRIGHT RELEASE_NOTES.md INSTALL INSTALL.cmake test_prog.c lib_flags.am cmake CMakeLists.txt COMPILE.cmake.txt config.h.cmake.in cmake_uninstall.cmake.in netcdf-config-version.cmake.in netcdf-config.cmake.in FixBundle.cmake.in nc-config.cmake.in configure configure.ac install-sh config.h.in config.sub CTestConfig.cmake.in)
+# ADD_MAKEDIST()
+# ENABLE_MAKEDIST(README.md COPYRIGHT RELEASE_NOTES.md INSTALL INSTALL.cmake test_prog.c lib_flags.am cmake CMakeLists.txt COMPILE.cmake.txt config.h.cmake.in cmake_uninstall.cmake.in netcdf-config-version.cmake.in netcdf-config.cmake.in FixBundle.cmake.in nc-config.cmake.in configure configure.ac install-sh config.h.in config.sub CTestConfig.cmake.in)
 
 #####
 # Configure and print the libnetcdf.settings file.
EOF
	touch ../$P-c-$V/patched
fi

vsenv
cmakeenv
ninjaenv

mkdir -p build install
cd build

cmake -G Ninja \
	-D CMAKE_BUILD_TYPE=Release \
	-D CMAKE_INSTALL_PREFIX=$(cygpath -aw ../install) \
	-D CMAKE_MODULE_PATH='${CMAKE_ROOT}/cmake/modules/;${CMAKE_SOURCE_DIR}/cmake/modules/;${CMAKE_SOURCE_DIR}/cmake/modules/windows' \
	-D HDF5_DIR=$(cygpath -am ../osgeo4w/share/cmake) \
	-D HDF5_INCLUDE_DIR=$(cygpath -am ../osgeo4w/include) \
	-D CURL_INCLUDE_DIR=$(cygpath -am ../osgeo4w/include) \
	-D CURL_LIBRARY=$(cygpath -am ../osgeo4w/lib/libcurl_imp.lib) \
	-D ZLIB_INCLUDE_DIR=$(cygpath -am ../osgeo4w/include) \
	-D ZLIB_LIBRARY=$(cygpath -am ../osgeo4w/lib/zlib.lib) \
	-D Zstd_INCLUDE_DIR=$(cygpath -am ../osgeo4w/include) \
	-D Zstd_LIBRARIES=$(cygpath -am ../osgeo4w/lib/zstd.lib) \
	-D BZip2_LIBRARIES=$(cygpath -am ../osgeo4w/lib/libbz2.lib) \
	-D BZip2_INCLUDE_DIR=$(cygpath -am ../osgeo4w/include) \
	-D Szip_LIBRARIES=$(cygpath -am ../osgeo4w/lib/szip.lib) \
	-D Szip_INCLUDE_DIR=$(cygpath -am ../osgeo4w/include) \
	-D LIBXML2_INCLUDE_DIR=$(cygpath -am ../osgeo4w/include/libxml2) \
	-D LIBXML2_LIBRARY=$(cygpath -am ../osgeo4w/lib/libxml2.lib) \
	-D ENABLE_MMAP=OFF \
	-D BUILD_EXAMPLES=OFF \
	-D PACKAGE_PREFIX_DIR=$(cygpath -am ../osgeo4w/cmake) \
	../../$P-c-$V
cmake --build .
cmake --build . --target install
cmakefix ../install

cd ..

export R=$OSGEO4W_REP/x86_64/release/$P
mkdir -p $R/$P-{devel,tools}

cat <<EOF >$R/setup.hint
sdesc: "The NetCDF library and commands for reading and writing NetCDF format (Runtime)"
ldesc: "The NetCDF library and commands for reading and writing NetCDF format (Runtime)"
category: Libs
requires: base hdf4 hdf5 curl zlib szip
maintainer: $MAINTAINER
EOF

cat <<EOF >$R/$P-tools/setup.hint
sdesc: "The NetCDF library and commands for reading and writing NetCDF format (Tools)"
ldesc: "The NetCDF library and commands for reading and writing NetCDF format (Tools)"
category: Commandline_Utilities
requires: $P
external-source: $P
maintainer: $MAINTAINER
EOF

cat <<EOF >$R/$P-devel/setup.hint
sdesc: "The NetCDF library and commands for reading and writing NetCDF format (Development)"
ldesc: "The NetCDF library and commands for reading and writing NetCDF format (Development)"
category: Libs
requires: $P
external-source: $P
maintainer: $MAINTAINER
EOF

cp ../$P-c-$V/COPYRIGHT $R/$P-$V-$B.txt
cp ../$P-c-$V/COPYRIGHT $R/$P-devel/$P-devel-$V-$B.txt
cp ../$P-c-$V/COPYRIGHT $R/$P-tools/$P-tools-$V-$B.txt

sed -e "s#$(cygpath -am install)#@osgeo4w_msys@#" install/bin/nc-config >install/bin/nc-config.tmpl

mkdir -p install/etc/postinstall install/etc/preremove

cat >install/etc/postinstall/$P.bat <<EOF
textreplace -std -t "%OSGEO4W_ROOT%\\bin\\nc-config"
EOF

cat >install/etc/preremove/$P.bat <<EOF
del "%OSGEO4W_ROOT%\\bin\\nc-config"
EOF

tar -C install -cjf $R/$P-$V-$B.tar.bz2 \
	bin/nc-config.tmpl \
	bin/netcdf.dll

tar -C install -cjf $R/$P-tools/$P-tools-$V-$B.tar.bz2 \
	--exclude bin/nc-config \
	--exclude bin/nc-config.tmpl \
	--exclude "*.dll" \
	bin

tar -C install -cjf $R/$P-devel/$P-devel-$V-$B.tar.bz2 \
	include lib etc

tar -C .. -cjf $R/$P-$V-$B-src.tar.bz2 osgeo4w/package.sh

endlog
