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

# 20250603
以下示例演示了 Bash 中的参数扩展写法 `: ${OSGEO4W_SKIP_UPLOAD:=1}` 等同于“如果环境变量未定义或为空，则为其赋予默认值”，并与 C 语言中“先判断再赋值”的思路具有相似性。下面先简要总结，再对各部分进行分节详细说明。

## 总览

在 Bash 脚本中，形如 `: ${VAR:=default}` 的写法利用了一个空命令（no-op）`:` 以及“参数扩展（parameter expansion）”机制，实现了：**如果变量 `VAR` 不存在或其值为空，则把 `default` 赋给 `VAR`，否则保持原值不变**；随后再将该变量的值扩展用于脚本的后续逻辑。([GNU][1], [GNU][2], [Medium][3]) 这相当于在 C 语言里写成：

```c
if (var == NULL || *var == '\0') {
    var = default_value;
}
```

或者利用条件表达式（ternary operator）简写为：

```c
var = (var && *var) ? var : default_value;
```

从根本上看，二者都体现了“先检测变量是否已有值，如果没有则赋予默认值”的共通思路。([Wikipedia][4], [Wikipedia][5])

下面分三个大段展开：

1. `: ${VAR:=default}` 的语法与作用
2. 具体示例演示如何在脚本中使用
3. 与 C 语言中对应概念的比较（包括 if-赋值与条件运算符示例）。

## 1. `: ${VAR:=default}` 的语法与作用

### 1.1 空命令 `:`

1. 在 Bash 中，冒号 `:` 是一个内置的空命令（no-op），执行时不产生任何输出且返回状态码为 0。([GNU][1], [Linux Documentation Project][6])
2. 常见用途包括占位、占行，或者与参数扩展结合，以保证脚本执行参数检测却不实际运行其他命令。([GNU][1], [Opensource.com][7])
3. 写作 `: ${VAR:=value}` 时，先执行参数扩展 `${VAR:=value}` 将可能会为 `VAR` 赋默认值；再执行空命令 `:`，实现“只为变量赋值、而不做其他操作”的效果。([GNU][1], [GNU][2])

### 1.2 参数扩展 `${parameter:=word}`

1. Bash 参数扩展语法 `${parameter:=word}` 的含义是：如果 `parameter` 未定义或其值为空，则先把 `word` 赋给 `parameter`，随后再将 `parameter` 的新值替换到命令行中。([GNU][1], [Stack Overflow][8])
2. 如果 `parameter` 已经存在且非空，则不做任何赋值，仅将其当前值作为扩展结果。([GNU][1], [Medium][3])
3. 与之相近但不赋值的写法是 `${parameter:-word}`，后者只在扩展时使用 `word` 作为临时默认值，而不改变 `parameter` 本身。([GNU][1], [Stack Overflow][8])
4. 合并将冒号 `:` 与 `${parameter:=word}` 写成 `: ${parameter:=word}`，可以在脚本未启用 “`set -u`（unbound variables cause error）” 的情况下，默认赋值且保持逻辑简洁。([GNU][1], [Linux Documentation Project][6])

### 1.3 脚本片段中的用途

在用户提供的脚本中，有多行如下写法：

```bash
: ${OSGEO4W_SKIP_UPLOAD:=1}
: ${OSGEO4W_SKIP_CLEAN:=1}
: ${OSGEO4W_BUILD_RDEPS:=1}
: ${OSGEO4W_CONTINUE_BUILD:=0}
: ${OSGEO4W_SKIP_MASTER_REPO:=0}
```

其作用依次为：

* 如果环境变量 `OSGEO4W_SKIP_UPLOAD` 未定义或为空，则设置为 `1`；否则保持原值。([GNU][1], [Stack Overflow][8])
* 如果环境变量 `OSGEO4W_SKIP_CLEAN` 未定义或为空，则设置为 `1`；否则保持原值。([GNU][1], [Stack Overflow][8])
* 如果环境变量 `OSGEO4W_BUILD_RDEPS` 未定义或为空，则设置为 `1`；否则保持原值。([GNU][1], [Stack Overflow][8])
* 如果环境变量 `OSGEO4W_CONTINUE_BUILD` 未定义或为空，则设置为 `0`；否则保持原值。([GNU][1], [Stack Overflow][8])
* 如果环境变量 `OSGEO4W_SKIP_MASTER_REPO` 未定义或为空，则设置为 `0`；否则保持原值。([GNU][1], [Stack Overflow][8])

这样写的好处在于：无论脚本从外部调用时是否已预先导出对应环境变量，脚本内部都能保证每个变量至少有一个合理的“默认值”，避免后续流程中的未定义或者空值导致逻辑错误。([GNU][1], [LabEx][9])

## 2. 具体示例演示

为了帮助理解，下面用几个简单示例演示 `${VAR:=default}` 及 `: ${VAR:=default}` 的效果。

### 2.1 简单交互演示

```bash
#!/bin/bash

echo "执行前，FOO=${FOO}"
: ${FOO:=bar}
echo "执行后，FOO=${FOO}"
```

1. 当脚本中并未预先定义 `FOO` 时，第一行会输出 `执行前，FOO=`（空）。([GNU][1], [Linux Documentation Project][6])
2. 执行 `: ${FOO:=bar}` 时，因为 `FOO` 未定义或为空，故将 `bar` 赋予 `FOO`，同时该表达式本身会扩展为 `bar`，但因为前面有一个空命令 `: `，不会输出任何内容。([GNU][1], [Stack Overflow][8])
3. 随后 `echo "执行后，FOO=${FOO}"` 会输出 `执行后，FOO=bar`，证明 `FOO` 已被赋值为 `bar`。([GNU][1], [Linux Documentation Project][6])

若将上述两行改为 `${FOO:-bar}`（不带等号写法），脚本变为：

```bash
#!/bin/bash

FOO=''
echo "执行前，FOO='${FOO}'"
echo "展开时临时默认：${FOO:-bar}"
echo "展开后，FOO='${FOO}'"
```

1. `FOO` 虽然已定义为 `''`（空字符串），但 `${FOO:-bar}` 仅在展开时使用 `bar` 作为默认值，并不修改 `FOO`。([GNU][1], [Medium][3])
2. 因此输出将是：

   ```
   执行前，FOO=''
   展开时临时默认：bar
   展开后，FOO=''
   ```

   证明 `${VAR:-value}` 不会改变原变量。([Stack Overflow][8], [Linux Documentation Project][6])

### 2.2 结合 `set -u` 检测未绑定变量

```bash
#!/bin/bash
set -u  # 启用未定义变量报错
# 下面若直接用 $MISSING 就会触发错误
: ${MISSING:=fallback}  # 先给 MISSING 赋默认值
echo "MISSING is now '$MISSING'"
```

1. 如果不使用 `${MISSING:=fallback}`，而直接写 `echo "$MISSING"`，脚本会因 `set -u` 报错并退出。([LabEx][10], [GNU][1])
2. 通过 `: ${MISSING:=fallback}` 先为 `MISSING` 赋默认值，再使用 `echo "$MISSING"`，就可以避免 “未绑定变量” 错误。([Linux Documentation Project][6], [earthly.dev][11])

### 2.3 在实际构建脚本中的作用

回到题中脚本，首先这样写：

```bash
: ${OSGEO4W_SKIP_UPLOAD:=1}
: ${OSGEO4W_SKIP_CLEAN:=1}
...
```

1. 脚本作者希望，如果调用者事先将环境变量 `OSGEO4W_SKIP_UPLOAD` 设为 `0`（意味着“不要跳过上传”），则保留该值为 `0`；如果调用者未设置该变量，则赋值为默认值 `1`（意味着“跳过上传”）。([GNU][1], [Stack Overflow][8])
2. 之后脚本会通过检查 `if [ "$OSGEO4W_SKIP_UPLOAD" = "0" ]` 来决定是否清空这个变量，从而影响上传逻辑。([Stack Overflow][8], [LabEx][9])
3. 这样就实现了一种“允许脚本外部覆盖，也可以脚本内部默认赋值”的灵活方式。([Medium][3], [Linux Documentation Project][6])

## 3. 与 C 语言中对应概念的比较

### 3.1 C 语言中常见的“先判断再赋值”写法

1. 在 C 语言里，如果要在运行时检查某个指针或变量是否已有值，如果没有再赋默认值，常见做法如下：

   ```c
   if (ptr == NULL) {
       ptr = default_ptr;
   }
   ```

   或者对于字符串：

   ```c
   if (str == NULL || *str == '\0') {
       str = "default";
   }
   ```

([Wikipedia][5], [Wikipedia][4])
2\. 上述写法与 Bash 中 `${VAR:=default}` 的效果是一致的：**都在首次使用变量前检查其是否“空”或“未定义”，若是则赋默认值**。([Wikipedia][4], [Wikipedia][5])

### 3.2 使用 C 的条件运算符（ternary operator）

1. 如果要在一行内既检查又赋值，可以借助 C 的三元运算符：

   ```c
   var = (var && *var) ? var : default_value;
   ```

   这句代码意味着：如果 `var` 非空且其首字符非 `\0`，则保持 `var` 不变，否则将 `default_value` 赋给 `var`。([Wikipedia][4])
2. 虽然与 Bash `${VAR:=default}` 语义完全相同，但 Bash 提供了更加简洁的“内置”方式进行变量存在性和空值检测与赋默认值。([Wikipedia][4], [GNU][1])

### 3.3 与更现代语言的“空合并赋值运算符”对比

1. C# 8.0 引入了空合并赋值运算符 `??=`，其用法如下：

   ```csharp
   someValue ??= someOtherValue;
   ```

   表示：如果 `someValue` 为 `null`，则将 `someOtherValue` 赋给它。([Wikipedia][5])
2. Bash 中的 `${VAR:=default}` 则相当于 C# 的 `VAR ??= default`，同样地 **先判断、再赋默认值**。([Wikipedia][5], [GNU][1])
3. 只是由于历史原因，纯 C 语言本身并不支持 `??=` 之类的“空合并赋值”运算符，只有通过 `if` 加赋值或三元运算符来实现。([Wikipedia][5], [Wikipedia][4])

### 3.4 具体 C 示例

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char *argv[]) {
    char *config_path = NULL;  // 模拟未定义
    // 如果没有从外部传入，就设默认值
    if (config_path == NULL || *config_path == '\0') {
        config_path = "/etc/myapp/config.ini";
    }
    printf("配置文件路径：%s\n", config_path);

    // 类似三元运算符写法
    char *user = getenv("USER");
    user = (user && *user) ? user : "default_user";
    printf("当前用户：%s\n", user);

    return 0;
}
```

1. 第一段 `if (config_path == NULL || *config_path == '\0')` 等价于 `${config_path:=/etc/myapp/config.ini}` 的功能：如果 `config_path` 未设置，则赋默认值。([Wikipedia][5], [Wikipedia][4])
2. 第二段借助三元运算符实现“一行内检测并赋值”，与 Bash `${VAR:=default}` 的作用相同。([Wikipedia][4], [Wikipedia][5])

## 4. 小结

* Bash 中的 `: ${VAR:=default}` 由两部分组成：

  1. 先用 `${VAR:=default}` 完成“如果变量未定义或空，则赋值；否则保持原值”的操作；
  2. 再用空命令 `:` 避免产生实际输出，仅借助参数扩展的赋值副作用。([GNU][1], [Linux Documentation Project][6])
* 其效果等价于 C 中的 “如果变量 `var` 为空/NULL，则给它赋默认值”，可通过显式 `if` 语句或三元运算符来实现。([Wikipedia][4], [Wikipedia][5])
* 对比现代语言（如 C#）中内置的 “空合并赋值运算符（`??=`）”，也体现了“先检查、再赋默认值”的编程思路。这种思路在多种语言里都有对应的等价写法，只是语法各异。([Wikipedia][5], [GNU][1])

通过上述说明与示例，希望您能够准确理解 `: ${OSGEO4W_SKIP_UPLOAD:=1}` 等写法在 Bash 脚本中如何工作，以及与 C 语言中“先判断再赋默认值”这一概念的对应关系。

[1]: https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html?ref=seongjin.me&utm_source=chatgpt.com "Shell Parameter Expansion (Bash Reference Manual) - GNU"
[2]: https://www.gnu.org/software///bash/manual/bash.html?utm_source=chatgpt.com "Bash Reference Manual - GNU"
[3]: https://medium.com/%40python-javascript-php-html-css/understanding-bracket-notation-in-bash-environment-variables-767844a79c4f?utm_source=chatgpt.com "Understanding Bracket Notation in Bash Environment Variables"
[4]: https://en.wikipedia.org/wiki/Ternary_conditional_operator?utm_source=chatgpt.com "Ternary conditional operator"
[5]: https://en.wikipedia.org/wiki/Null_coalescing_operator?utm_source=chatgpt.com "Null coalescing operator"
[6]: https://tldp.org/LDP/abs/html/parameter-substitution.html?utm_source=chatgpt.com "10.2. Parameter Substitution"
[7]: https://opensource.com/article/17/6/bash-parameter-expansion?utm_source=chatgpt.com "An introduction to parameter expansion in Bash - Opensource.com"
[8]: https://stackoverflow.com/questions/24405606/var-default-vs-var-default-what-is-difference?utm_source=chatgpt.com "${var:=default} vs ${var:-default} - what is difference? - Stack Overflow"
[9]: https://labex.io/tutorials/shell-how-to-set-default-values-in-bash-scripts-413755?utm_source=chatgpt.com "How to Set Default Values in Bash Scripts - LabEx"
[10]: https://labex.io/tutorials/shell-how-to-troubleshoot-unbound-variables-in-bash-scripts-400168?utm_source=chatgpt.com "How to Troubleshoot Unbound Variables in Bash Scripts - LabEx"
[11]: https://earthly.dev/blog/makefile-variables/?utm_source=chatgpt.com "Understanding and Using Makefile Variables - Earthly Blog"
