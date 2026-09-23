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
src/data/<dict_name>.mbt     每个词典一个模块：排序后的 (key, value) 数组 + 元数据
src/data/manifest.mbt        词典清单、来源 revision、每个文件的 SHA-256
src/config/chain_data.mbt    由 config/*.json 转写出的转换链定义
test/fixtures/golden/        从 vendor 复制的一致性语料（随仓库提交）
```

## 约定的数据形状

词典在生成期完成三件事，运行期不再做任何解析：

1. 去除注释行与空行，按 `key` 去重（后出现的条目覆盖先出现的，与 OpenCC 语义一致）。
2. 按 key 长度降序、长度相同按字典序排序，使最大匹配可以顺序扫描并提前退出。
3. 对值多于一个的条目，保留原始顺序并以数组形式输出。

## 使用

```powershell
pwsh -File scripts/fetch-opencc-data.ps1
moon run tools/gen_dict -- --input data/opencc --out src/data
moon run tools/gen_dict -- --verify      # 只校验，不写文件；CI 用
```

生成器进入 `data/opencc` 前先按 `SHA256SUMS` 校验，任何不一致都直接失败，
避免在数据被改动的情况下生成代码。

## 状态

尚未实现（W1 任务）。当前仓库里的 `src/core` 是手写的最小转换引擎，用于先打通
「词典 → 最大匹配 → 转换链」这条链路，生成器接入后由它产出真实数据。
