# opencc.mbt

**OpenCC-compatible Chinese script conversion in pure MoonBit — no FFI, no runtime I/O, runs on wasm, wasm-gc, js and native.**

简体 ↔ 繁体 ↔ 台湾正体 ↔ 香港繁体 ↔ 日本新字体，包含词组与地区用词转换，行为对齐 [OpenCC](https://github.com/BYVoid/OpenCC)，并以 OpenCC 官方语料的一致性通过率作为验收标准。

仓库：<https://github.com/Ljh684/opencc>

> 状态：**开发中（WIP）**。已完成：仓库骨架与 Apache-2.0 许可、转换引擎的核心链路
> （词典 → 最长匹配 → 转换链）、上游 OpenCC 数据快照（19 个词典 / 19 个配置 / 官方
> golden 语料，含 revision 与逐文件校验和）。进行中：词典生成器与官方一致性测试，
> 见下方[路线图](#路线图)。

---

## 为什么做这个

简繁转换是中文文本处理里使用频率最高的基础能力之一：搜索索引、内容分发、跨境电商、
出版排版、语料清洗、模型训练预处理都要用到它。

MoonBit 生态目前已经具备中文分词的移植、拼音、中文数字等能力，**唯独缺简繁转换这一层**；
而 OpenCC 只有 C++ 实现，无法直接用于 wasm 与边缘场景。

简繁转换是纯计算、无网络、无平台依赖的字符串处理，非常适合编译成体积可控的 wasm 在
浏览器、边缘节点与移动端离线运行 —— 这正是 MoonBit 的主场。

## 范围

### 支持

- OpenCC 全部 19 个官方转换配置（见下表）。
- 词典组合语义：`union` 与 `short_circuit`。
- 词组优先于单字的多段转换链（归一化 → 词组/单字 → 地区变体短语 → 变体字）。
- 最大匹配分词驱动的词组替换，避免逐字转换造成的错译。
- 非中文内容（数字、标点、拉丁字母、emoji、空白）原样保留。

### 19 个内置配置

| 配置 | 说明 |
| --- | --- |
| `s2t` | 简体 → 繁体（通用） |
| `t2s` | 繁体 → 简体 |
| `s2tw` | 简体 → 台湾正体 |
| `tw2s` | 台湾正体 → 简体 |
| `s2twp` | 简体 → 台湾正体（含台湾用词） |
| `tw2sp` | 台湾正体 → 简体（含大陆用词） |
| `s2hk` | 简体 → 香港繁体 |
| `hk2s` | 香港繁体 → 简体 |
| `s2hkp` | 简体 → 香港繁体（含香港用词） |
| `hk2sp` | 香港繁体 → 简体（含大陆用词） |
| `t2tw` | 繁体 → 台湾正体 |
| `tw2t` | 台湾正体 → 繁体（通用） |
| `t2hk` | 繁体 → 香港繁体 |
| `hk2t` | 香港繁体 → 繁体（通用） |
| `jp2t` | 日本新字体 → 繁体 |
| `t2jp` | 繁体 → 日本新字体 |
| `s2seal` | 简体 → 篆书 |
| `seal2t` | 篆书 → 繁体 |
| `t2seal` | 繁体 → 篆书 |

### 明确的非目标

- 不做分词 / 词性 / 命名实体识别（见 `colmugx/jieba`、`moonnlp`）。
- 不做拼音与输入法。
- 暂不覆盖 OpenCC 的 `staging/` 实验字典与 `jieba` 分词变体配置。
- 不提供 GUI。

## 使用（计划中的接口）

```bash
# CLI
opencc --config s2twp input.txt -o output.txt
cat in.txt | opencc -c t2s
opencc list-configs
opencc verify --golden test/fixtures/golden
```

```moonbit
// 库
let chain = @opencc.chain("s2twp")
let out = chain.apply("内存泄漏与软件优化")
```

## 数据来源与许可

- 本仓库的 MoonBit 代码以 **Apache-2.0** 发布，见 [LICENSE](LICENSE)。
- 词典、转换配置与一致性语料派生自 **OpenCC**（Apache-2.0），
  来源、固定 revision 与归档哈希记录在 [NOTICE](NOTICE) 与 `data/opencc/REVISION`。
- 上游数据**随仓库提交**，项目与 CI 全流程离线可跑；`data/opencc/SHA256SUMS`
  记录每个文件的 SHA-256，生成器与 CI 在生成代码前先校验。

```
data/opencc/dictionary/   19 个词典（单字、词组、地区变体、兼容汉字、篆书）
data/opencc/config/       19 个转换配置 + schema
data/opencc/SHA256SUMS    逐文件校验和
data/opencc/REVISION      上游仓库、revision、归档哈希与选择理由
test/fixtures/golden/     官方一致性语料（1 份输入 + 10 份期望输出）
```

仅在需要升级上游 revision 时刷新数据快照：

```powershell
pwsh -File scripts/fetch-opencc-data.ps1 -Revision <新 revision>
```

## 开发

```powershell
# 1. 安装 MoonBit 工具链（Windows）
pwsh -c "irm https://cli.moonbitlang.com/install/win.ps1 | iex"

# 2. 安装 Git 并完成仓库初始化（写入本仓库的 user.name / user.email 并首次提交）
winget install --id Git.Git -e
pwsh -File scripts/setup-git.ps1

# 3. 编译与测试
moon check
moon test

# 4. 可选：刷新上游 OpenCC 数据快照（已在仓库内，仅升级 revision 时执行）
#    pwsh -File scripts/fetch-opencc-data.ps1 -Revision <新 revision>
```

### 仓库结构

```
moon.mod               模块清单
data/opencc/           上游词典与配置快照（含 REVISION / SHA256SUMS）
src/core/              词典、最长匹配、转换链（引擎核心）
src/config/            19 个内置配置的定义
src/data/              编译期词典数据模块（由 tools/gen_dict 产出）
cmd/opencc/            CLI 入口
tools/gen_dict/        词典 → MoonBit 数据 生成器
scripts/               环境与数据准备的 PowerShell 脚本
test/fixtures/golden/  OpenCC 官方一致性语料（验收基准）
docs/                  设计文档与验收标准
```

## 路线图

| 周次 | 目标 | 完成标志 |
| --- | --- | --- |
| W1 | 词典生成器 + 引擎接入真实数据 + `s2t` / `t2s` 链路 | `moon check` / `moon test` 通过，`s2t` 通过官方 golden |
| W2 | `union` / `short_circuit` 组合语义 + 19 配置 + CLI | `opencc -c <config>` 端到端可用 |
| W3 | 全量官方一致性 + 属性测试 + 体积与性能优化 | 一致性报告与基准数据入库 |
| W4 | 文档、CI（多后端）、发布到 mooncakes | README / 演示 / 正式发布 |

## 已知限制

- 当前引擎按 UTF-16 码元切分字符串。CJK 兼容汉字（U+2F800 区）属于增补平面，
  需要按码点归并处理；归一化步骤会在 W1 与词典管线一起落地。
- 初始化阶段的词典是内存中的线性查找，W1 引入排序数组 + 二分 / 前缀索引后替换。

## 许可证

Apache License 2.0，见 [LICENSE](LICENSE) 与 [NOTICE](NOTICE)。
