# opencc.mbt

[![CI](https://github.com/Ljh684/opencc/actions/workflows/ci.yml/badge.svg)](https://github.com/Ljh684/opencc/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/Ljh684/opencc)](https://github.com/Ljh684/opencc/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)

**OpenCC-compatible Chinese script conversion in pure MoonBit — no FFI, no runtime I/O, runs on wasm, wasm-gc, js and native.**

简体 ↔ 繁体 ↔ 台湾正体 ↔ 香港繁体 ↔ 日本新字体，包含词组与地区用词转换，行为对齐 [OpenCC](https://github.com/BYVoid/OpenCC)，并以 OpenCC 官方语料的一致性通过率作为验收标准。

仓库：<https://github.com/Ljh684/opencc>

## 安装

```bash
moon add Ljh684/opencc              # 发布到 mooncakes 后即可这样引用
```

```moonbit
// 按名字调用（会链入全部词典）
let out = @config.convert("s2twp", "内存泄漏与软件优化")   // Some("記憶體洩漏與軟體最佳化")

// 只要一个方向、体积最小：import "Ljh684/opencc/config/s2twp"
let chain = @s2twp.chain()
```

`moon.pkg` 里需要 `import { "Ljh684/opencc/config" }`（或单配置包 `.../config/<name>`）。

> 状态：**开发中（WIP）**。已完成：仓库骨架与 Apache-2.0 许可、上游 OpenCC 数据快照
> （19 个词典 / 19 个配置 / 官方 golden 语料）、转换引擎（首字索引、嵌套词典组、归一化 →
> 分词 → 逐段转换）、词典生成器（`tools/gen_dict`：把 20 个词典共 76099 条数据编译成
> 内嵌文本块、复刻 OpenCC 构建期派生词典、SHA-256 校验与 `--verify` 幂等检查）、
> CLI 与库 API。
>
> **官方一致性：5/5 逐字节通过**（`s2t`、`s2hk`、`s2tw`、`s2hkp`、`s2twp`，
> 用仓库内 `test/fixtures/golden` 语料）。`moon check` 无警告，30 个单元测试通过
> （含覆盖 76099 条词典条目的全量属性测试）。
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

## 使用

```bash
# 列出全部 19 个配置（会标出引用但快照未提供的词典）
opencc list-configs

# 文本 / 文件转换；不给 -o 时结果写到 stdout
opencc -c s2twp --text "内存泄漏与软件优化"        # => 記憶體洩漏與軟體最佳化
opencc convert -c s2t --input in.txt --output out.txt

# 多个 -c 按顺序串联（同上游 CLI），以及整目录批量转换
opencc -c s2t -c t2s --text "内存泄漏与软件优化"
opencc convert -c s2twp --input-dir corpus --output-dir converted --ext .txt

# 与 OpenCC 官方语料逐字节比对
opencc verify --golden test/fixtures/golden
```

```moonbit
// 库：一次转换
let out = @opencc.convert("s2twp", "内存泄漏与软件优化")

// 库：复用链（构建词典索引一次，多次转换）
let chain = @opencc.chain("s2twp")
```

## 与现有方案的区别

- **生态里没有替代品**：mooncakes 2648 个包中，`opencc`、`简繁`、`简体`、`繁体`、
  `traditional chinese`、`s2t`、`t2s` 的命中数**全部为 0**；已有的是分词（jieba、moonnlp）、
  拼音、中文数字，都不做字形与地区用词转换。
- **与 OpenCC 语义一致且可验证**：官方 golden 语料 5/5 逐字节通过，CLI 文件输出与期望文件
  逐字节相同；而 OpenCC 是 C++ + 运行时二进制词典，本项目是纯 MoonBit、零 FFI、数据编译期
  内联，可编到 wasm / js / native。
- **数据可审计**：上游 revision、逐文件 SHA-256、`gen_dict --verify` 幂等校验，
  连 OpenCC 构建期生成的派生词典都按上游规则复刻并留下可读文本。

完整对比（含审阅者三分钟验证清单）见 [docs/comparison.md](docs/comparison.md)，
一页项目说明见 [docs/one-pager.md](docs/one-pager.md)。

## 演示

```bash
moon build examples/web --target js --release   # 产出可被 JS 调用的模块
node examples/web/demo.mjs                      # 命令行演示
python -m http.server                           # 再打开 examples/web/index.html 看网页 demo
```

`examples/web` 是一个 `foreign_library` 包，用 `#export_name` 导出 `opencc_to_taiwan` 与
`opencc_to_simplified` 两个函数（JS 侧的类型声明见构建产物 `web.d.ts`）。网页 demo 直接调用
编译后的模块，没有任何网络请求；产物 1.36 MB，只包含 s2twp 与 t2s 两个方向需要的词典。

```
$ node examples/web/demo.mjs
内存泄漏与软件优化
  → TW  記憶體洩漏與軟體最佳化
  → 简  记忆体泄漏与软体最佳化
较低级别的官员由总统任命。
  → TW  較低級別的官員由總統任命。
  → 简  较低级别的官员由总统任命。
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
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm https://cli.moonbitlang.cn/install/powershell.ps1 | iex

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
core/                  词典、最长匹配、转换链（引擎核心）
config/                19 个内置配置的定义与其转换链
dict/                  编译期词典数据模块（由 tools/gen_dict 产出）
cmd/opencc/            CLI 入口
tools/gen_dict/        词典 → MoonBit 数据 生成器
scripts/               环境与数据准备的 PowerShell 脚本
test/fixtures/golden/  OpenCC 官方一致性语料（验收基准）
docs/                  设计文档与验收标准
```

包布局遵循当前 `moon new` 模板：模块根目录本身就是源目录，`cmd/` 放可执行包，
不再使用旧的 `src/` 约定。

## 路线图

按「一次只做一个功能、做完并验证再进下一个」推进，每个阶段对应一个可验证的提交。

| 阶段 | 目标 | 状态 |
| --- | --- | --- |
| F1 骨架 | 仓库、Apache-2.0 许可、MoonBit 模块与三后端构建 | 已完成 |
| F2 数据快照 | 词典 / 配置 / golden 语料入库，含 revision 与逐文件 SHA-256 | 已完成 |
| F3 词典生成器 | 词典 → `dict/*.mbt` + manifest，`--verify` 幂等 | 已完成 |
| F4 索引 | 首字索引替换线性扫描，性能记录入库 | 已完成 |
| F5 官方一致性 | 配置驱动链路 + 派生词典 + 逐段转换，golden 5/5 逐字节通过 | 已完成 |
| F6 CLI 与配置覆盖 | `list-configs` / `convert` / `verify`，库入口 `convert(name, text)` | 已完成 |
| F7 数据表示 | 内嵌文本块 + 运行时建索引：native 测试 341 s → 7 s，解除 plain wasm 上限 | 已完成 |
| F8 覆盖与属性测试 | 全量条目属性测试、往返一致性检查、缺失词典台账、行粒度与稳定性属性 | 已完成 |
| F9 按配置裁剪 | 词典/配置各自成包：t2s 构建 249 KB、s2t 913 KB、全量 CLI 1341 KB（wasm-gc） | 已完成 |
| F10 发布 | 发布到 mooncakes、GitHub Release 与演示素材 | 下一步 |

## 已知限制

- 引擎按 UTF-16 码元切分与比较字符串；因为词典 key 与文本走同一套码元比较，匹配是一致的，
  增补平面字符（如 CJK 兼容汉字）由归一化词典映射到规范字形后参与匹配。
- CLI 还不支持标准输入：MoonBit 的 core 与 `moonbitlang/x` 目前没有标准输入 API，
  加 FFI 会破坏「零 FFI」，因此先用文件与 `--text`；stdout 输出在以换行结尾的文本上
  与输入等价，否则会补一个换行（`-o` 输出文件是逐字节精确的路径）。
- `cmd/opencc` 需要按名字查找配置，因此会链入全部词典（wasm-gc 1.31 MB）。只想做单一方向
  的程序请用 `config/<name>` 包，例如 `examples/t2s` 只有 249 KB（见
  [docs/performance.md](docs/performance.md)）。
- 反方向配置（`t2s`、`tw2s`、`hk2s`）缺少官方语料可对标，目前只有正向 5 条链的
  逐字节证据；覆盖与属性测试是下一步。

## 许可证

Apache License 2.0，见 [LICENSE](LICENSE) 与 [NOTICE](NOTICE)。
