# tools/gen_dict — 词典数据生成器

把 OpenCC 的词典与配置转换成可直接编译进 MoonBit 模块的数据。

## 为什么需要它

OpenCC 在运行时读取 `.ocd2` 二进制词典；MoonBit 侧不能依赖文件系统，尤其不能依赖 FFI
或运行时解析，因此本项目在**构建期**把词典编译成 MoonBit 源码常量，运行时零 I/O。

同时这也是「数据可审计」的一环：生成器固定上游 revision，并对每个输出文件记录
SHA-256，CI 重新生成后比对，确保仓库里的数据与上游一致。

## 输入

`data/opencc/`（随仓库提交，由 `scripts/fetch-opencc-data.ps1` 刷新）：

```
data/opencc/dictionary/*.txt             词组与单字词典（每行 `key<TAB>value [value...]`）
data/opencc/config/*.json                转换配置（normalization / segmentation / conversion_chain）
data/opencc/SHA256SUMS                   每个数据文件的 SHA-256，生成前先校验
data/opencc/REVISION                     上游仓库、revision、归档哈希
test/fixtures/golden/input/*.txt         一致性测试输入
test/fixtures/golden/output/*.txt        一致性测试期望输出
```

## 输出

```
dict/<dict_name>.mbt         每个词典一个模块：排序后的 (key, value) 数组 + 元数据
dict/manifest.mbt            词典清单、来源 revision、每个文件的 SHA-256
config/chain_data.mbt        由 config/*.json 转写出的转换链定义
test/fixtures/golden/        抽取自 data/opencc 的一致性语料（随仓库提交）
```

## 约定的数据形状

词典在生成期完成三件事，运行期不再做任何解析：

1. 去除注释行与空行，按 `key` 去重（后出现的条目覆盖先出现的，与 OpenCC 语义一致）。
2. 按 key 长度降序、长度相同按字典序排序，使最大匹配可以顺序扫描并提前退出。
3. 对值多于一个的条目，保留原始顺序并以数组形式输出。

## 使用

```powershell
pwsh -File scripts/fetch-opencc-data.ps1
moon run tools/gen_dict -- --input data/opencc --out dict
moon run tools/gen_dict -- --verify      # 只校验，不写文件；CI 用
```

生成器进入 `data/opencc` 前先按 `SHA256SUMS` 校验，任何不一致都直接失败，
避免在数据被改动的情况下生成代码。

## 状态

已实现并接入仓库（19 个词典 / 75543 条目）。每次运行都会：

1. 按 `data/opencc/SHA256SUMS` 校验每个词典文件的 SHA-256，不一致直接失败；
2. 解析词典，统计无法解析的行（当前为 0），有异常即失败；
3. 生成 `dict/*.mbt` 与 `dict/manifest.mbt`，并写入 `dict/moon.pkg` 的 `formatter.ignore`，
   避免 `moon fmt` 触碰生成代码；
4. `--verify` 模式下不写文件，只在生成结果与仓库内容不一致时退出码 1。

条目较多的词典会被切成多个私有分片（每片 4096 条）再由公开绑定合并，
以绕开编译器对单个文本段行数的限制。
