# 2026 MoonBit 黑客松 · 项目申报书

| 项目名称 | opencc — MoonBit 原生简繁与地区用词转换 |
| --- | --- |
| 参赛者 | Ljh684 |
| 开源仓库 | https://github.com/Ljh684/opencc （公开，Apache-2.0，CI 绿） |
| 语言与依赖 | MoonBit；库本身零依赖，命令行 / 生成器 / 基准用官方扩展库 `moonbitlang/x`（文件读写、SHA-256、命令行参数、UTF-8 编码） |
| 规模 | 手写实现 14 个文件 2749 行，生成数据 42 个文件 79818 行；测试 3 个文件 418 行、33 个测试全部通过 |

## 一、项目目标与应用场景

**目标**：给 MoonBit 生态一个可以被**别的程序直接调用**的简繁与地区用词转换器——给定配置名与文本，输出与 OpenCC 逐字节一致的结果。生态里没有这一层，而它又是中文文本处理绕不开的基础能力；OpenCC 只有 C++ 实现，进不了 wasm 与边缘场景。

**场景**：内容平台与搜索索引在入库时统一字形；跨境电商与出版在分发时切换简体 / 台湾正体 / 香港繁体用词；数据管线清洗历史语料；教学里每条结论都对应一条可重跑的命令。

## 二、拟实现的功能

| 编号 | 功能 | 交付物 | 状态 |
| --- | --- | --- | --- |
| F1 | 纯 MoonBit 引擎：首字索引、可嵌套词典组（`union` / `short_circuit`）、normalization → segmentation → 逐段 conversion | `core/` | 已完成 |
| F2 | 数据管线：快照固定 revision、逐文件 SHA-256、生成 20 个词典 / 76099 条目 | `tools/gen_dict/`、`data/`、`dict/` | 已完成 |
| F3 | 复刻 OpenCC 构建期派生词典（`STPhrases_GeneratedFromRegionalPhrases`） | `tools/gen_dict/derive.mbt`、`data/derived/` | 已完成 |
| F4 | 19 个配置的装配与单配置包（只链入该配置需要的词典） | `config/` | 已完成 |
| F5 | CLI：`list-configs` / `convert`（`-c/-i/-o/--text`）/ `verify`（含往返检查） | `cmd/opencc/` | 已完成 |
| F6 | 库 API：`convert(name, text)`、`chain(name)`、`missing_dictionaries(name)` | `config/build.mbt` | 已完成 |
| F7 | 官方一致性：golden 语料逐字节比对 + 往返一致性 | `test/fixtures/golden/`、`opencc verify` | 5/5 通过 |
| F8 | 测试与属性：全量条目属性（76099 条）、分词边界、行粒度、二次转换稳定性 | `core/*_wbtest.mbt`、`config/*_wbtest.mbt` | 33 个测试 |
| F9 | 体积与热路径：词典/配置分包、跳过不可匹配片段 | `config/<name>/`、`core/match.mbt` | 已完成 |
| F10 | 演示：导出 JS 可调用的两个函数（浏览器 / Node） | `examples/web/` | 已完成 |

不在本次范围：中文分词 / 拼音 / 中文数字（生态已有）；OpenCC 的 `staging/` 实验字典与 `*_jieba` 分词变体；标准输入（MoonBit 无标准输入 API，加 FFI 会破坏「零 FFI」）。明细见 [README](../README.md)。

## 三、验收说明

全部验收由 `moon test`（33 个测试）、`opencc verify`（官方语料 + 往返）与 `tools/gen_dict --verify`（数据幂等）覆盖；下表里 `opencc` 指 `moon run cmd/opencc --target native --`。

| 编号 | 怎么验 | 通过标准 |
| --- | --- | --- |
| F1 | `moon test` 中的嵌套组与分词边界用例 | 嵌套 `short_circuit(union(...), ...)` 语义与 OpenCC 一致；`较低级别` 保持 `較低級別` 而非 `較低階別` |
| F2 | `moon run tools/gen_dict --target native -- --verify` | 20 个词典 / 76099 条目与仓库内容逐字节一致，SHA-256 全部匹配 |
| F3 | 同上（派生词典由生成器重算） | 派生条目与仓库文本一致；简体投影冲突数为 0 |
| F4 | `opencc list-configs` | 19 个配置全部可装配；缺失词典逐条列出（当前 6 本，均为 OpenCC 构建期生成） |
| F5 | `opencc -c s2twp --text "内存泄漏与软件优化"` | 输出 `記憶體洩漏與軟體最佳化` |
| F6 | `moon test` 中的库 API 用例 | 未知配置返回 `None`；真实配置结果与词典数据一致 |
| F7 | `opencc verify` | 正向 5/5 逐字节；`s2t → t2s`、`s2tw → tw2s` 往返逐字节回到原文 |
| F8 | `moon test`（wasm / wasm-gc / js / native） | 33/33；76099 条词条逐条命中自身 key |
| F9 | `moon build examples/t2s --target wasm-gc --release` | t2s 249 KB、s2t 913 KB、全量 CLI 1341 KB |
| F10 | `moon build examples/web --target js --release` 后跑 `node examples/web/demo.mjs` | 两个导出函数可调用；浏览器 demo 无网络请求 |

## 四、复用性：下游怎么依赖它

**命令行只是库的一个使用者**：`cmd/opencc` 建在 `config/*` 与 `core` 之上，`examples/*` 与它并列。

- **接口与稳定面**：`moon add Ljh684/opencc` 之后直接调用 `config.convert(name, text)`；需要最小体积时改为 import `config/<name>` 包，只链入该方向需要的词典。内核对象字段私有、经方法读取，行为由官方语料与 `--verify` 锁定（见 [acceptance.md](acceptance.md)）。
- **证据与价值**：`examples/t2s`（249 KB）与 `examples/web` 是不使用命令行入口的消费者，CI 会构建它们；把「字形与地区用词」这件容易出错的事变成一条可重跑、可逐字节比对的命令。

## 五、与已有生态的区别

与生态里已有的中文文本包不在同一层：jieba / moonnlp 做分词，pinyin、MoonSpeech 做注音与输入法，cnnum 做数字，Unicode 各包做字符属性——都不含词级字形与地区用词映射，也组合不出来。与 OpenCC（C++）的关系是**同语义、不同形态**：官方 golden 语料 5/5 逐字节一致，而本项目纯 MoonBit、零 FFI、数据编译期内联，wasm / wasm-gc / js / native 四个后端都能构建并测试。查重：mooncakes 全量 2752 个包中 `opencc`、`简繁`、`简体`、`繁体`、`s2t`、`t2s` 命中数全部为 0。详见 [comparison.md](comparison.md)。

## 六、边界

- 反方向配置引用的 6 本词典由 OpenCC 构建期生成、当前快照未提供，`verify` 会逐条列出而不是静默降级；
- 不支持标准输入；不覆盖 `staging/` 与 `*_jieba` 变体；
- `s2*` 方向的体积由 `STPhrases`（1178 KB，占全量 70%）决定，无法进一步显著裁剪——这一点如实写进性能文档而不是含糊过去。明细见 [design.md](design.md) 与 [performance.md](performance.md)。

## 七、个人背景

MoonBit 开发者，已在 mooncakes.io 发布解析器组合子库 `Ljh684/MoonParse`，并完成确定性网络仿真项目 `moonnet-lab`；词法分析、状态机与错误处理的实现经验与本项目（词典索引、分词边界、逐段转换）直接相关。

## 八、其他材料

[README](../README.md) · [一页说明](one-pager.md) · [差异对比](comparison.md) · [验收](acceptance.md) · [设计](design.md) · [性能](performance.md) · [变更日志](../CHANGELOG.md) · [Release v0.1.0](https://github.com/Ljh684/opencc/releases/tag/v0.1.0)
