#!/bin/bash

# 只要有任何命令返回非 0（失败）就立刻退出，避免后续步骤在错误状态下继续执行。
set -e
# 让管道（cmd1 | cmd2）中任意一步失败都能被视为整体失败（返回非 0）。
set -o pipefail

# 配置 PATH：使用 MSYS/Cygwin 的基础工具路径，避免受到外部环境 PATH 干扰。
export PATH=/bin:/usr/bin

# 如果没有显式指定仓库根目录（OSGEO4W_REP），则根据当前 git 分支推断。
if [ -z "$OSGEO4W_REP" ]; then
	# 获取当前 git 分支名（用于区分 master 与其它分支的构建目录策略）。
	b=$(git branch --show-current)
	# 按分支名选择构建仓库目录与默认策略。
	case $b in
	master)
		# master 分支：使用当前目录作为仓库根目录。
		export OSGEO4W_REP=$PWD
		# 切换到仓库根目录（确保后续相对路径均从仓库根起算）。
		cd $OSGEO4W_REP
		;;

	*)
		# 非 master 分支：使用临时目录作为仓库根目录，避免污染主工作区。
		export OSGEO4W_REP=$TEMP/repo-$b
		# 非 master 分支默认不上传构建产物（避免误上传到公开仓库）。
		export OSGEO4W_SKIP_UPLOAD=1
		# 确保临时仓库目录存在。
		mkdir -p "$OSGEO4W_REP"
		;;
	esac
fi

# 若未显式设置 OSGEO4W_SKIP_UPLOAD，则默认 1（跳过上传）。
: ${OSGEO4W_SKIP_UPLOAD:=1}
# 若未显式设置 OSGEO4W_SKIP_CLEAN，则默认 1（跳过清理/clean 步骤）。
: ${OSGEO4W_SKIP_CLEAN:=1}
# 若未显式设置 OSGEO4W_BUILD_RDEPS，则默认 1（构建所选包的反向依赖）。
: ${OSGEO4W_BUILD_RDEPS:=1}
# 若未显式设置 OSGEO4W_CONTINUE_BUILD，则默认 0（构建失败时不继续）。
: ${OSGEO4W_CONTINUE_BUILD:=0}
# 若未显式设置 OSGEO4W_SKIP_MASTER_REPO，则默认 0（不跳过从 master 仓库下载依赖）。
: ${OSGEO4W_SKIP_MASTER_REPO:=0}

# 导出关键环境变量，供子脚本（例如各包的 package.sh）读取使用。
export OSGEO4W_REP OSGEO4W_SKIP_UPLOAD

# 定义 build()：在当前包目录下调用 package.sh 执行实际构建流程。
build() {
	# 执行当前目录中的 package.sh（使用 bash 运行以确保一致的解释器行为）。
	bash package.sh
}

# 若存在 .buildenv，则加载其中定义的环境变量/配置（可覆盖上方默认值）。
[ -f .buildenv ] && source .buildenv

# 将某些“显式关闭”值规范化为空值，便于后续用 -z/-n 判断开关状态。
if [ "$TX_TOKEN" = "none" ]; then TX_TOKEN=; fi
# 当 OSGEO4W_SKIP_UPLOAD=0 时，清空该变量，表示“不要跳过上传”（即允许上传）。
if [ "$OSGEO4W_SKIP_UPLOAD" = "0" ]; then OSGEO4W_SKIP_UPLOAD=; fi
# 当 OSGEO4W_SKIP_CLEAN=0 时，清空该变量，表示“不要跳过清理”。
if [ "$OSGEO4W_SKIP_CLEAN" = "0" ]; then OSGEO4W_SKIP_CLEAN=; fi
# 当 OSGEO4W_BUILD_RDEPS=0 时，清空该变量，表示“不构建反向依赖”。
if [ "$OSGEO4W_BUILD_RDEPS" = "0" ]; then OSGEO4W_BUILD_RDEPS=; fi
# 当 OSGEO4W_CONTINUE_BUILD=0 时，清空该变量，表示“失败即停止”。
if [ "$OSGEO4W_CONTINUE_BUILD" = "0" ]; then OSGEO4W_CONTINUE_BUILD=; fi
# 当 OSGEO4W_SKIP_MASTER_REPO=0 时，清空该变量，表示“不跳过 master 仓库依赖下载”。
if [ "$OSGEO4W_SKIP_MASTER_REPO" = "0" ]; then OSGEO4W_SKIP_MASTER_REPO=; fi

# 读取要构建的包列表（来自本脚本命令行参数）。
PKGS="$@"

# 若启用反向依赖构建，则用 build-inorder.pl 扩展/排序包列表，并用 paste 合并为一行空格分隔的参数串。
[ -z "$OSGEO4W_BUILD_RDEPS" ] || PKGS=$(perl scripts/build-inorder.pl $PKGS | paste -d" " -s)

# 输出本次构建使用的仓库目录（带时间戳，便于日志追踪）。
echo $(date): REPOSITORY: $OSGEO4W_REP
# 输出本次要构建的包列表（带时间戳）。
echo $(date): BUILDING: $PKGS
# 如果设置了跳过上传，则在日志中提示不会上传。
[ -z "$OSGEO4W_SKIP_UPLOAD" ] || echo $(date): NOT UPLOADING
# 如果未启用反向依赖构建，则在日志中提示不会构建反向依赖。
[ -n "$OSGEO4W_BUILD_RDEPS" ] || echo $(date): NOT BUILDING REVERSE DEPENDENCIES
# 如果设置了跳过清理，则在日志中提示会跳过清理。
[ -z "$OSGEO4W_SKIP_CLEAN" ] || echo $(date): SKIPPING CLEANS
# 如果启用“失败继续”，则在日志中提示失败后会继续构建后续包。
[ -z "$OSGEO4W_CONTINUE_BUILD" ] || echo $(date): CONTINUING ON BUILD FAILURES
# 如果设置了跳过 master 仓库依赖下载，则在日志中提示该行为。
[ -z "$OSGEO4W_SKIP_MASTER_REPO" ] || echo $(date): SKIPPING DOWNLOADING DEPENDENCIES FROM MASTER REPO

# 初始化整体状态标志（用于在允许继续构建时记录是否出现过失败）。
ok=1
# 记录仓库根目录的绝对路径（后续用于生成 tmp 标记文件的固定路径）。
P=$PWD
# 记录成功构建的包列表（用于后续向 CI 环境导出）。
built=
# 遍历包列表逐个构建。
for i in $PKGS; do
	# 去掉包名可能的前导 “-”（仅影响用于路径/标记文件的包名变量 d）。
	d=${i#-}

	# 如果该包已经有 done 标记文件，则跳过以避免重复构建。
	if [ -f $P/tmp/$d.done ]; then
		# 输出跳过信息（带时间戳）。
		echo $(date): $d ALREADY DONE
		# 进入下一包。
		continue
	fi

	# 切换到该包的 osgeo4w 构建目录（其中包含 package.sh）。
	cd src/$d/osgeo4w

	# 输出开始构建信息（带时间戳）。
	echo $(date): $d BUILDING

	# 确保 tmp 目录存在（用于保存 done 标记文件）。
	mkdir -p $P/tmp
	# 调用 build() 执行构建；根据返回码判断成功/失败。
	if build; then
		# 构建成功，输出成功信息。
		echo $(date): $d SUCCEEDED
		# 追加到成功构建列表（用空格分隔）。
		built="${built} $d"
		# 写入 done 标记文件，避免后续重复构建。
		touch $P/tmp/$i.done
	else
		# 记录失败的返回码（用于日志输出）。
		r=$?
		# 构建失败，输出失败信息及返回码。
		echo $(date): $d FAILED WITH $r
		# 若未启用“失败继续”，则直接以失败退出脚本。
		[ "$OSGEO4W_CONTINUE_BUILD" ] || exit 1
		# 否则标记整体状态为失败（供末尾统一判断）。
		ok=0
	fi

	# 回到仓库根目录（从 src/<pkg>/osgeo4w 退回三级）。
	cd ../../..
done

# 若在 GitHub Actions 中运行，则将成功构建的包列表写入 $GITHUB_ENV，供后续步骤使用。
[ -z "$GITHUB_ENV" ] || echo "BUILT_PKGS=${built# }" >>$GITHUB_ENV

# 若 ok 变量为空，则以失败退出（用于在末尾统一返回失败状态）。
[ "$ok" ] || exit 1
