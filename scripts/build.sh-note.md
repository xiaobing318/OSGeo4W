# 20250531
在这一版 **`scripts/build.sh`** 中，作者把 OSGeo4W 的“批量打包”逻辑封装成一个可在 Cygwin/Git-Bash/MSYS2 等 Bash 环境里调用的脚本：它先用严格模式确保任何错误都能被捕获，然后根据当前 Git 分支决定将构建产物放到哪里，按需要解析默认参数、递归解析反向依赖，再顺序编译并跟踪每个包的结果。下面先用一句话勾勒整体思路，再分三部分——背景知识、脚本全貌、逐行释义——详细拆解。

## 脚本整体流程概览

1. **严格模式**：`set -e -o pipefail` 确保任何命令或管道出错即中止脚本。([Ask Ubuntu][1], [bbs.archlinux.org][2])
2. **PATH 精简**：把可执行搜索路径限制在 `/bin:/usr/bin`。
3. **确定仓库/分支输出目录**：若在 *master* 分支就直接用当前仓库；否则在 `%TEMP%` 下建一个分支专属的临时 repo，并默认禁止上传。
4. **读取 `.buildenv`**：允许本地或 CI 通过该文件重写默认环境变量。
5. \*\*将布尔型“开关”变量从 `"0"`/空串转换成 Bash 风格的布尔存在性。
6. **根据用户参数与反向依赖关系得到最终包列表**（可调用 `scripts/build-inorder.pl` 重排）。
7. **按顺序循环构建**：对每个包 `src/<pkg>/osgeo4w/package.sh` 调用函数 `build()`；成功则打标记，失败时看是否允许继续。
8. **把已成功的包列表写回 GitHub Actions 的 `GITHUB_ENV`**，供后续步骤使用。([GitHub Docs][3])

---

## 关键 Bash 指令速查

| 语法                             | 作用                               | 参考                       |
| ------------------------------ | -------------------------------- | ------------------------ |
| `set -e`                       | 任一命令退出码≠0时立即退出脚本                 | ([Ask Ubuntu][1])        |
| `set -o pipefail`              | 若管道中任一子进程失败则整个管道返回失败             | ([bbs.archlinux.org][2]) |
| `${VAR:=default}`              | 若 `$VAR` 未设置/为空则设为 `default` 并返回 | ([Stack Overflow][4])    |
| `git branch --show-current`    | 输出当前分支名称                         | ([Stack Overflow][5])    |
| `case $b in … esac`            | 多分支匹配结构，`;;` 结束子分支               | ([linuxize.com][6])      |
| `[ -z "$X" ]`                  | 测试字符串为空                          | ([Stack Overflow][7])    |
| `paste -d" " -s`               | 将多行并排拼接成一行，分隔符为空格                | ([Wikipedia][8])         |
| `echo "VAR=val" >>$GITHUB_ENV` | 给 GitHub Actions 后续步骤写环境变量       | ([GitHub Docs][9])       |

---

## 逐行代码解读

| #     | 代码片段                                     | 详细含义                                                                                                                                                                                                                             |                                                  |                                                                         |
| ----- | ---------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ | ----------------------------------------------------------------------- |
| 1     | `#!/bin/bash`                            | Shebang，指示用 Bash 解释器执行。                                                                                                                                                                                                          |                                                  |                                                                         |
| 3     | `set -e`                                 | 打开“错误即退出”模式，任何非零退出状态都会终止脚本。([Ask Ubuntu][1])                                                                                                                                                                                     |                                                  |                                                                         |
| 4     | `set -o pipefail`                        | 让管道以其中**最早失败子进程**的状态码作为返回值，防止静默失败。([bbs.archlinux.org][2])                                                                                                                                                                       |                                                  |                                                                         |
| 6     | `export PATH=/bin:/usr/bin`              | 把搜索路径缩到最小，只用 Cygwin 的核心工具，避免调用到系统外部程序。([Stack Overflow][10])                                                                                                                                                                     |                                                  |                                                                         |
| 8-24  | 分支判断块                                    | 若 `$OSGEO4W_REP` 未预设：<br>① 通过 `git branch --show-current` 得到当前分支名存于变量 **b**；([Stack Overflow][5]) <br>② *master* 分支→把仓库根作为输出目录；其它分支→在 `%TEMP%/repo-<branch>` 建临时目录，同时把 `OSGEO4W_SKIP_UPLOAD=1`，避免把实验包上传到正式仓库。`mkdir -p` 可递归创建目录。 |                                                  |                                                                         |
| 26-30 | `: ${VAR:=default}` 五行                   | 设置五个“开关”变量的默认值（1 表示 *true*）：<br>`SKIP_UPLOAD`, `SKIP_CLEAN`, `BUILD_RDEPS`, `CONTINUE_BUILD`, `SKIP_MASTER_REPO`。参数展开语法见上表。([Stack Overflow][4])                                                                                 |                                                  |                                                                         |
| 32    | `export OSGEO4W_REP OSGEO4W_SKIP_UPLOAD` | 把关键变量导出到子进程环境。                                                                                                                                                                                                                   |                                                  |                                                                         |
| 34-36 | `build()` 函数                             | 目前只封装单条 `bash package.sh`，后续若有复杂逻辑可集中修改。                                                                                                                                                                                         |                                                  |                                                                         |
| 38    | `[ -f .buildenv ] && source .buildenv`   | 若存在本地配置文件 `.buildenv`，则加载它以覆盖/补充环境变量。                                                                                                                                                                                            |                                                  |                                                                         |
| 40-45 | 六条 `if`                                  | 把 `"0"` 字符串转换成“空串”以便后续逻辑直接用 `[ -z "$VAR" ]` 判断存在性。                                                                                                                                                                               |                                                  |                                                                         |
| 47    | `PKGS="$@"`                              | 收集用户在命令行传入的包名列表。                                                                                                                                                                                                                 |                                                  |                                                                         |
| 49    | 反向依赖解析                                   | 若要求构建反向依赖（默认 1），就调用 Perl 脚本 `scripts/build-inorder.pl`，再用 `paste -d" " -s` 把多行输出拼成一行包序列。([Wikipedia][8])                                                                                                                         |                                                  |                                                                         |
| 51-57 | 多行 `echo`                                | 打印当前构建设置，便于在日志中核对。                                                                                                                                                                                                               |                                                  |                                                                         |
| 59-73 | 主循环 `for i in $PKGS`                     | 依次处理每个包：<br>‒ `d=${i#-}`：允许用 `-foo` 表示“仅检查”，此处剥掉前缀。<br>‒ 若已存在 `tmp/$d.done` 则直接跳过。<br>‒ 进入 `src/$d/osgeo4w` 子目录，执行 `build()`；成功则打 `tmp/$i.done` 标记，失败则根据 `OSGEO4W_CONTINUE_BUILD` 决定是否中止整个脚本。                                    |                                                  |                                                                         |
| 75    | `cd ../../..`                            | 回到仓库根目录，准备构建下一个包。                                                                                                                                                                                                                |                                                  |                                                                         |
| 78    | \`\[ -z "\$GITHUB\_ENV" ]                |                                                                                                                                                                                                                                  | echo "BUILT\_PKGS=\${built# }" >>\$GITHUB\_ENV\` | 在 GitHub Actions 环境下，把本轮成功包列表写入 `GITHUB_ENV` 供后续步骤引用。([GitHub Docs][9]) |
| 80    | \`\[ "\$ok" ]                            |                                                                                                                                                                                                                                  | exit 1\`                                         | 若 `ok` 变量为空（即曾有失败且未允许继续），脚本以失败状态退出。                                     |

---

### 补充说明

* **`scripts/build-inorder.pl`** 根据 OSGeo4W 的包元数据计算“依赖树拓扑排序”，保证底层依赖先被构建，再构建上层包；`paste -s` 把结果展开成空格分隔的单行便于循环。([Wikipedia][8])
* **`.buildenv`** 机制让开发者在本地缓存登录令牌、上传账号等敏感信息，而不用把它们写进脚本或 CI 配置中。
* **布尔变量处理**：脚本将 `"0"` 视为 **false**，任何非空（含 `"1"`）视为 **true**；通过转换为空串/非空串来匹配 Bash `-z` / `-n` 判断习惯。|

---

通过上面的行级剖析，你可以快速定制自己的构建流程，例如：

```bash
# 只在本地打包 qgis-ltr，不递归依赖，也不上传
OSGEO4W_SKIP_UPLOAD=1 OSGEO4W_BUILD_RDEPS=0 bash scripts/build.sh qgis-ltr
```

若需要在 CI 中全量增量构建并推送，只要把对应环境变量设为 `0` 即可。

[1]: https://askubuntu.com/questions/1167965/what-does-set-x-do-in-a-bash-script?utm_source=chatgpt.com "What does \"set -x\" do in a bash script? - Ask Ubuntu"
[2]: https://bbs.archlinux.org/viewtopic.php?id=240984&utm_source=chatgpt.com "set -uo pipefail / Creating & Modifying Packages / Arch Linux Forums"
[3]: https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/store-information-in-variables?utm_source=chatgpt.com "Store information in variables - GitHub Docs"
[4]: https://stackoverflow.com/questions/2013547/assigning-default-values-to-shell-variables-with-a-single-command-in-bash?utm_source=chatgpt.com "Assigning default values to shell variables with a single command in ..."
[5]: https://stackoverflow.com/questions/6245570/how-do-i-get-the-current-branch-name-in-git?utm_source=chatgpt.com "How do I get the current branch name in Git? - Stack Overflow"
[6]: https://linuxize.com/post/bash-case-statement/?utm_source=chatgpt.com "Bash Case Statement | Linuxize"
[7]: https://stackoverflow.com/questions/21157435/how-can-i-compare-a-string-to-multiple-correct-values-in-bash?utm_source=chatgpt.com "How can I compare a string to multiple correct values in Bash?"
[8]: https://en.wikipedia.org/wiki/Paste_%28Unix%29?utm_source=chatgpt.com "Paste (Unix)"
[9]: https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/workflow-commands-for-github-actions?utm_source=chatgpt.com "Workflow commands for GitHub Actions"
[10]: https://stackoverflow.com/questions/8950695/shell-scripting-using-a-variable-to-define-a-path?utm_source=chatgpt.com "Shell Scripting: Using a variable to define a path - Stack Overflow"
