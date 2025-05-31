@echo off
call "%~dp0\o4w_env.bat"
call "%~dp0\gdal-dev-py-env.bat"
if not exist "%OSGEO4W_ROOT%\apps\@package@\bin\qgisgrass@grassmajor@.dll" goto nograss
if not exist "%OSGEO4W_ROOT%\apps\grass\@grasspath@\etc\env.bat" goto nograss
set savedpath=%PATH%
call "%OSGEO4W_ROOT%\apps\grass\@grasspath@\etc\env.bat"
path %OSGEO4W_ROOT%\apps\grass\@grasspath@\lib;%OSGEO4W_ROOT%\apps\grass\@grasspath@\bin;%savedpath%
:nograss
@echo off
path %OSGEO4W_ROOT%\apps\@package@\bin;%PATH%
set QGIS_PREFIX_PATH=%OSGEO4W_ROOT:\=/%/apps/@package@
set GDAL_FILENAME_IS_UTF8=YES
rem Set VSI cache to be used as buffer, see #6448
set VSI_CACHE=TRUE
set VSI_CACHE_SIZE=1000000
set QT_PLUGIN_PATH=%OSGEO4W_ROOT%\apps\@package@\qtplugins;%OSGEO4W_ROOT%\apps\qt5\plugins
start "QGIS" /B "%OSGEO4W_ROOT%\bin\@package@-bin.exe" %*
