#!/bin/bash

# 只要有任何命令返回非零就立刻退出，避免后续步骤在错误状态下继续执行，其中非零返回码表示命令执行失败。
set -e

# 创建变量用来保存签名证书文件路径。
cert=$PWD/src/setup/osgeo4w/OSGeo_DigiCert_Signing_Cert
# 如果没有设置镜像地址则将镜像地址设置为默认值即官方网址。
: ${mirror:=https://download.osgeo.org/osgeo4w/v2}

# 创建变量用来保存签名参数，签名参数初始化为空
sign=
# 拼接文件路径并且判断当前进程对签名证书文件和密码文件是否有读权限，如果有则将这两个文件内容读取并组装成签名参数
if [ -r "$cert.p12" -a -r "$cert.pass" ]; then
	# 如果当前处于 CI 环境中那么需要隐藏证书密码
	[ -z "$CI" ] || echo "::add-mask::$(<$cert.pass)"
	# 组装签名参数用于 MSI 生成，签名的作用是为了证明制作的 MSI 来自可信任的发布者，防止被篡改。
	sign="-signwith=$cert.p12 -signpass=$(<$cert.pass)"
fi

# 遍历要生成 MSI 的包名列表，如果没有通过 PKGS 变量指定，那么默认生成 MSI 文件可以是 qgis/qgis-ltr 这两个包，需要注意的是 src 目录里中只有一部分包能够用来制作 MSI 文件。
for i in ${PKGS:-qgis qgis-ltr}; do
	# 创建变量用来保存本次包的额外参数，初始化为空
	o=
	# 如果判断条件中的四个文件存在，则使用着四个文件来构造参数，即设置发布命令名称、MSI 顶部横幅图、MSI 背景图和 ARP 中显示的图标。
	if [ -f "src/$i/qgis/CMakeLists.txt" -a src/$i/osgeo4w/qgis_msibanner.bmp -a src/$i/osgeo4w/qgis_msiinstaller.bmp -a src/$i/osgeo4w/qgis.ico ]; then
		# 从 CMakeLists.txt 文件中提取发布名称
		o="-releasename=$(sed -ne 's/^set(RELEASE_NAME "\(.*\)").*$/\1/ip' src/$i/qgis/CMakeLists.txt)"
		# 设置 MSI 顶部横幅图
		o="$o -banner=$PWD/src/$i/osgeo4w/qgis_msibanner.bmp"
		# 设置 MSI 背景图
		o="$o -background=$PWD/src/$i/osgeo4w/qgis_msiinstaller.bmp"
		# 设置 ARP(add/remove programs) 中显示的图标，即程序列表中显示的图标
		o="$o -arpicon=$PWD/src/$i/osgeo4w/qgis.ico"
	fi

	# 根据包名追加特定参数，这里针对的是 QGIS Qt6 变体，如果包名中包含 qt6 则进行代码块中的处理。
	case "$i" in
	*qt6*)
		# 为 qt6 变体指定包名
		o="$o -packagename='QGISQT6'"
		# 结束该分支
		;;
	# 结束 case 判断
	esac

	# 如果处于 CI 环境中则开启分组日志
	[ -z "$CI" ] || echo "::group::Creating MSI for $i"

	# 使用 perl 解释器调用 createmsi.pl 将本从而制作 MSI 格式文件，这里的 eval 是 Bash 中内置命令，用于处理参数中的引号和空格，从而确保参数能够正确传递给 createmsi.pl 脚本。
	eval perl scripts/createmsi.pl \
		$sign \
		$o \
		-verbose \
		-shortname="$i" \
		-mirror=$mirror \
		$i-full

	# 如果处于 CI 环境中则输出结束分组日志
	[ -z "$CI" ] || echo "::endgroup::"
done
