# dict — 编译期词典数据

本目录由 `tools/gen_dict` 生成，**请勿手工编辑**。

```
dict/<binding>/data.mbt     单个词典：内嵌文本块（`Array[String]`，每 4000 行一块）
dict/<binding>/moon.pkg     该词典的包配置
dict/manifest.mbt           词典清单、上游 revision、每个文件的 SHA-256、按名字查找
dict/reexport.mbt           聚合包对每个词典的重导出（`@dict.st_phrases` 等）
dict/moon.pkg               聚合包的配置（import 上面所有词典包）
```

每个词典单独成包，是为了让"只想做一个方向"的程序不链进其它词典：
`config/<name>` 只 import 它需要的词典包。实测体积见
[../docs/performance.md](../docs/performance.md)。

内嵌文本与 `data/opencc/dictionary/*.txt` 逐字节相同，运行期由 `core/Dict::parse`
扫描一次建立首字索引；这样既避免逐条字面量带来的编译代价与 plain wasm 上限，
也让"数据有没有被改过"可以直接比文本。

当前快照：**20 个词典、76099 条目**（含一个派生词典
`st_phrases_generated_from_regional_phrases`，由 `data/derived/` 生成），
约 2.1 MB 生成源码；最大的是 `st_phrases.mbt`（49238 条，13 个分片）。

生成步骤：

```powershell
pwsh -File scripts/fetch-opencc-data.ps1                 # 下载上游数据到 vendor/
moon run tools/gen_dict -- --input data/opencc --out dict
```

约定：

- 词典内容派生自 OpenCC（Apache-2.0），来源与 revision 见仓库根目录的 `NOTICE`。
- 生成器同时写出 `manifest.mbt`；CI 会用 `tools/gen_dict --verify` 重新生成并比对哈希，
  确保仓库内的数据与固定的上游 revision 一致。
- 生成文件在 `moon fmt` 中通过 `formatter(ignore: ...)` 跳过，避免格式化噪声。
