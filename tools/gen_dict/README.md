# tools/gen_dict — 数据生成器

把 OpenCC 快照与配置编译成 MoonBit 数据：词典 → `dict/*.mbt`，配置 → `config/chains.mbt`，
并复刻 OpenCC 构建期生成的派生词典。

## 为什么需要它

OpenCC 在运行时读取 `.ocd2` 二进制词典；MoonBit 侧不能依赖文件系统，更不能依赖 FFI，
因此本项目在**构建期**把词典编译成 MoonBit 源码常量，运行时零 I/O。

同时这也是「数据可审计」的一环：生成器固定上游 revision，校验每个输入文件的
SHA-256，并对每个输出负责——`--verify` 会把生成结果与仓库内容逐字节比对。

## 输入

`data/opencc/`（随仓库提交，由 `scripts/fetch-opencc-data.ps1` 刷新）：

```
data/opencc/dictionary/*.txt     词组与单字词典（每行 `key<TAB>value(s)`）
data/opencc/config/*.json        normalization / segmentation / conversion_chain
data/opencc/SHA256SUMS           每个数据文件的 SHA-256，读取前先校验
data/opencc/REVISION             上游仓库、revision、归档哈希
```

## 输出

```
dict/<binding>.mbt               每个词典一个模块：内嵌词典文本（每 4000 行一个字符串块）
dict/manifest.mbt                词典清单、上游 revision、逐文件 SHA-256、lookup()
dict/moon.pkg                    生成的包配置（含 formatter.ignore）
config/chains.mbt                19 个配置的三段式定义（normalization / segmentation / conversion）
data/derived/*.txt               派生词典的可审计文本
```

词典以 `#|` 原样字符串内嵌，内容与上游 `.txt` 逐字节相同；运行期由 `core/Dict::parse`
建立索引。这样编译器只需要处理每词典若干个大常量，而不是 7.6 万条字面量——
实测 native 测试从 341 s 降到 7 s，并解除了 plain wasm 后端的局部变量上限。

## 生成规则

1. **校验**：按 `SHA256SUMS` 校验每个词典；不一致直接失败。
2. **解析**：跳过空行与 `#` 注释，按 `key<TAB>value(s)` 切分，值以空格分隔；
   多值条目当前只取第一个值用于转换（其余值用于分词打分，见 `docs/design.md`）。
3. **去重与排序**：条目在生成时按需排序，运行时索引由 `core/Dict::new` 建立。
4. **配置转写**：JSON 里的 `match_policy` 嵌套结构被完整保留（生成 `Spec::Group`），
   并额外列出该配置引用但快照未提供的词典（`missing`）。
5. **派生词典**：复刻 OpenCC 的 `STPhrases_GeneratedFromRegionalPhrases`——取 HK / TW
   词组词典的每个 key，用 `t2s` 配置转成简体，映射回原词组；简体投影短于 3 个码元的
   条目丢弃。若同一个简体投影对应两个不同词组，按上游做法视为错误并让本次生成失败。

第 5 步用的是**本次刚解析出来的**词典数据与配置，不依赖上一次生成的产物，
所以从干净快照重新生成不需要额外步骤。

## 使用

```powershell
moon run tools/gen_dict --target native                       # 生成
moon run tools/gen_dict --target native -- --verify           # 只校验（CI 用）
moon run tools/gen_dict --target native -- --input data/opencc --out dict --config-out config
```

条目较多的词典会被切成多个私有分片（每片 4096 条）再由公开绑定合并，
以绕开编译器对单个文本段行数的限制。

## 状态

已实现并接入仓库：20 个词典（含 1 个派生）、76099 条目、19 个配置；
`moon check` 无警告，`--verify` 干净。
