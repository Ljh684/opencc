# 2026 MoonBit 黑客松 · 项目申报书

| 项目名称 | opencc — MoonBit 原生简繁与地区用词转换 |
| --- | --- |
| 参赛者 | Ljh684 |
| 开源仓库 | https://github.com/Ljh684/opencc （公开，Apache-2.0，CI 绿） |
| 已发布包 | https://mooncakes.io/docs/Ljh684/opencc （`moon add Ljh684/opencc`） |
| 语言与依赖 | MoonBit；库本身零依赖，命令行 / 生成器 / 基准用官方扩展库 `moonbitlang/x` |
| 规模 | 手写实现 15 个文件 3559 行，生成数据 42 个文件 79776 行；测试 5 个文件 535 行、39 个测试全部通过（数字由 `verify --report` 生成，见验收表） |

## 一、目标与场景

**目标**：给 MoonBit 生态一个可以被**其它程序直接调用**的简繁与地区用词转换器——给定配置名与文本，输出与 OpenCC 逐字节一致的结果。生态里已有分词、拼音、中文数字，唯独没有这一层；而 OpenCC 只有 C++ 实现，进不了 wasm 与边缘场景。

**场景**：内容平台与搜索索引在入库时统一字形；跨境电商与出版按地区切换用词；数据管线批量清洗历史语料；每一条结论都对应一条可重跑的命令。

## 二、交付功能

| 功能 | 交付物 | 状态 |
| --- | --- | --- |
| 纯 MoonBit 引擎：首字索引、可嵌套词典组（`union` / `short_circuit`）、normalization → segmentation → 逐段转换 | `core/` | 已完成 |
| 数据管线：快照固定 revision、逐文件 SHA-256、生成 20 个词典 / 76099 条目，并复刻 OpenCC 构建期的派生词典 | `tools/gen_dict/`、`data/`、`dict/` | 已完成 |
| 19 个配置装配；每个配置单独成包，只链入自己需要的词典（t2s 构建 249 KB） | `config/` | 已完成 |
| CLI 与库 API：`list-configs` / `convert`（`-c` 可重复串行、`--input-dir` 目录批量）/ `verify`（含往返）；`convert(name, text)` | `cmd/opencc/`、`config/build.mbt` | 已完成 |
| 官方一致性 5/5 逐字节；39 个测试（含 76099 条词条全量属性测试，以及 19 个配置的回归基线） | `test/fixtures/golden/`、`test/fixtures/regression/`、`*_test.mbt` | 已完成 |
| 可核对报告：`verify --report` 把 19 个配置的覆盖状态、往返、数据快照与代码规模落成 Markdown 或 JSON；CI 重新生成后逐字节 diff，过期即失败 | `docs/verification-report.md`、`docs/verification-report.json` | 已完成 |
| 已发布到 mooncakes（v0.1.0，干净模块实测可安装）；热路径优化（ASCII 密集 1.59×）与浏览器/Node 演示 | `moon.mod`、`core/match.mbt`、`examples/web/` | 已完成 |

不在本次范围：中文分词 / 拼音 / 中文数字（生态已有）；OpenCC 的 `staging/` 实验字典与 `*_jieba` 分词变体；标准输入（MoonBit 尚无标准输入 API，加 FFI 会破坏「零 FFI」）。明细见 [README](../README.md)。

## 三、验收

下表里 `opencc` 指 `moon run cmd/opencc --target native --`。

| 怎么验 | 通过标准 |
| --- | --- |
| `opencc verify` | 官方语料 5/5 逐字节；`s2t → t2s`、`s2tw → tw2s` 往返逐字节回到原文 |
| `moon test`（native 39 个 / 其余后端 36 个） | 全部通过；76099 条词条逐条命中自身 key；19 个配置与回归基线一致 |
| `opencc verify --report docs/verification-report.md` | 报告与仓库中的同名文件逐字节相同（CI 就是这么比的）；报告列出全部 19 个配置、缺失词典台账、往返结果与代码规模 |
| `moon run tools/gen_dict --target native -- --verify` | 20 个词典 / 76099 条目与仓库逐字节一致，SHA-256 全部匹配 |
| `opencc convert -c s2twp --text "内存泄漏与软件优化"` | 输出 `記憶體洩漏與軟體最佳化`（逐字替换只能得到 `內存泄漏與軟體優化`） |
| `opencc convert -c s2t -c t2s --text …` 与 `--input-dir … --output-dir …` | 多配置按顺序串联生效；目录批量逐文件输出并汇总 |
| `moon build examples/t2s --target wasm-gc --release` | 249 KB（s2t 913 KB、全量 CLI 1341 KB） |

## 四、复用性：下游怎么依赖它

**命令行只是库的一个使用者**：`cmd/opencc` 建在 `config/*` 与 `core` 之上，`examples/*` 与它并列。`moon add Ljh684/opencc` 之后可直接调用 `config.convert(name, text)`；需要最小体积时改为 import `config/<name>`，只链入该方向的词典。行为由官方语料与 `--verify` 锁定（见 [acceptance.md](acceptance.md)）。

## 五、与已有生态的区别

生态里的中文文本包不在同一层：jieba / moonnlp 做分词，pinyin、MoonSpeech 做注音与输入法，cnnum 做数字，Unicode 各包做字符属性——都不含词级字形与地区用词映射，也组合不出来。与 OpenCC 的关系是**同语义、不同形态**：官方 golden 语料 5/5 逐字节一致，而本项目纯 MoonBit、零 FFI、数据编译期内联，四个后端都能构建并测试。查重：mooncakes 全量 2752 个包中 `opencc`、`简繁`、`简体`、`繁体`、`s2t`、`t2s` 命中数全部为 0（见 [comparison.md](comparison.md)）。

## 六、边界

- 反方向配置引用的 6 本词典由 OpenCC 构建期生成、当前快照未提供，`verify` 会逐条列出而不是静默降级；
- 不支持标准输入；不覆盖 `staging/` 与 `*_jieba` 变体；
- `s2*` 方向的体积由 `STPhrases`（1178 KB，占全量 70%）决定，无法进一步显著裁剪——如实写进 [performance.md](performance.md)。

## 七、个人背景

MoonBit 开发者，已在 mooncakes.io 发布解析器组合子库 `Ljh684/MoonParse`，并完成确定性网络仿真项目 `moonnet-lab`；词法分析、状态机与错误处理的实现经验与本项目（词典索引、分词边界、逐段转换）直接相关。

## 八、其他材料

[README](../README.md) · [验收报告](verification-report.md) · [一页说明](one-pager.md) · [差异对比](comparison.md) · [验收](acceptance.md) · [设计](design.md) · [性能](performance.md) · [mooncakes](https://mooncakes.io/docs/Ljh684/opencc) · [Release v0.1.0](https://github.com/Ljh684/opencc/releases/tag/v0.1.0)
