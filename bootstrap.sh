#!/bin/bash

# 只要有任何命令返回非 0（失败）就立刻退出，避免后续步骤在错误状态下继续执行。
set -e

# 配置 PATH：优先使用 MSYS/Cygwin 的 /bin、/usr/bin，并追加系统目录（用于找到系统 git、tar 等工具）。
export PATH=/bin:/usr/bin:$(/bin/cygpath --sysdir)

# 若未显式设置 O4W_GIT_REPO，则使用默认远程仓库地址（通过 “:=” 在首次缺省时赋值）。
: ${O4W_GIT_REPO:=https://github.com/jef-n/OSGeo4W}
# 若未显式设置 O4W_GIT_BRANCH，则默认使用 master 分支（同样通过缺省赋值）。
: ${O4W_GIT_BRANCH:=master}

# 确保 $HOME 目录存在（git 全局配置等会依赖该目录）。
mkdir -p $HOME

# 将当前工作目录加入 git 的 safe.directory（避免在 CI/容器/不同用户环境下触发安全限制）。
git config --global --add safe.directory $PWD

# 若当前目录还不是 git 仓库，则初始化并从远程拉取指定分支。
[ -d .git ] || {
	# 初始化当前目录为 git 仓库（生成 .git/）。
	git init .
	# 添加远程 origin 指向目标仓库。
	git remote add origin $O4W_GIT_REPO
	# 从远程获取对象与分支信息（不改变工作区文件）。
	git fetch origin
	# 删除当前脚本文件，避免后续 checkout 时出现“未跟踪文件将被覆盖”的冲突。
	rm -f bootstrap.sh
	# 强制检出远程分支并建立本地跟踪分支（将工作区切换到目标分支内容）。
	git checkout -f -t origin/$O4W_GIT_BRANCH
}

# 非 CI 环境下，保持本地分支与远程同步（rebase 以保持线性历史）。
[ -n "$CI" ] || git pull --rebase

# 进入正式构建流程，并将本脚本收到的所有参数原样透传给构建脚本。
bash scripts/build.sh "$@"
