## 概要

`acceptable.lst` 是 OSGeo4W 根目录下的一个文本文件，内部列出了 **已知且被允许** 的各个开源组件或库的**许可证文本的校验和（checksum）**及其对应的名称。它主要解决了**自动化打包流程中对上游包的许可证文件进行识别和验真**的问题，避免对所有库的许可证都人工审核或因未知许可证而导致打包中断。

---

## 1、acceptable.lst 文件解决了什么问题？

* **统一许可证识别**：不同的上游项目可能会随源码包提供各式各样的许可证文件（GPL、MIT、Apache、专有等），内容略有差异。`acceptable.lst` 使用对照表的方式，把“已审核、可接受”的许可证文本的**SHA1（或 MD5）校验和**与其“人类可读的名称”对应起来，从而让打包脚本一眼就能识别出该许可证属于哪个开源协议，而无需逐个比对全文。 ([GitHub][1])
* **自动化验真与白名单**：在 CI 或本地打包时，脚本会计算每个包中 `LICENSE.txt`（或类似文件）的校验和，并去 `acceptable.lst` 中查表。若匹配，说明该许可证已被项目管理员事先审核过，就直接跳过人工确认；若不匹配，则标记为“restricted”（需人工干预或新增条目）。 ([trac.osgeo.org][2])

---

## 2、在 OSGeo4W 项目中如何使用这个 acceptable.lst？

1. **构建启动脚本** (`bootstrap.sh`)

   * `bootstrap.sh` 会调用 `scripts/build.sh`，后者遍历各个子包并执行 `package.sh`，其中会触发对许可证文件的检查。 ([GitHub][3])
2. **打包脚本中的校验逻辑**

   * 在 `scripts/package.sh`（或沿用的 Perl 脚本）中，会读取根目录下的 `acceptable.lst`，将每个包的许可证文件计算校验和后与之比对。如果在列表中找到对应的条目，脚本便视为“已接受”（accepted）并继续后续打包流程。否则，则把该包标记为“restricted”，并在安装程序或 CI 报告中提示“许可证未通过白名单审核”。
3. **安装程序（osgeo4w-setup.exe）**

   * 对于 Windows 用户，通过 GUI 或命令行进行安装时，Setup 会尝试下载每个包的 `.txt` 形式许可证，并用本地的 `acceptable.lst` 判断它是否已经“accepted”。若尚未接受，则反复提醒用户同意该许可证，直到用户手动批准或管理员在 `acceptable.lst` 中新增条目为止。

---

## 3、如果没有 acceptable.lst 文件将会造成什么结果？

* **所有许可证都会被认为“restricted”**
  安装/打包脚本遇到任何许可证文件，均因无法匹配到白名单而标记为“未接受”（restricted）。
* **安装/打包流程中断或无限循环**
  如 Trac 上针对“szip”包的票据所示，缺少对应的白名单条目会导致安装程序在“Agreement of Restrictive Package”步骤反复下载同一许可证却始终提示“not yet accepted”，用户无法继续安装： ([trac.osgeo.org][2])
* **需人工干预**
  打包维护者必须手动识别新许可证，计算其校验和，编辑并提交更新后的 `acceptable.lst`，才可恢复打包或安装流程的自动化运行。

---

**小结**：
`acceptable.lst` 是 OSGeo4W 用来**自动化识别和验证上游包许可证**的关键“白名单”——通过对照校验和，跳过已知许可证的人工审核；若缺失，则所有许可证都被拒绝，打包和安装会因“restricted”状态而无法前进。维护者在引入新软件包或新许可证时，需要先把相应的许可证文本校验和加入此列表，确保流程顺畅。

[1]: https://github.com/jef-n/OSGeo4W/blob/master/acceptable.lst "OSGeo4W/acceptable.lst at master · jef-n/OSGeo4W · GitHub"
[2]: https://trac.osgeo.org/osgeo4w/ticket/486?utm_source=chatgpt.com "486 (Infinite license download during quite installation of szip)"
[3]: https://github.com/jef-n/OSGeo4W/raw/master/bootstrap.sh?raw=true "raw.githubusercontent.com"
