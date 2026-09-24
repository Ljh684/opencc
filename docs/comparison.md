# 与现有方案的区别和优势

初审关心三件事：选题是否真实、范围是否清晰、和已有作品是否重复。这一页只用可核查的数据回答，
不用形容词。

## 1. 查重结论（2026-09-25 实测）

mooncakes.io 全量包清单 **2648 个包**（比前一天多 14 个，生态在持续增长）：

| 检索词 | 命中 |
| --- | --- |
| `opencc` | 0 |
| `简繁` / `简体` / `繁体` / `简繁转换` | 0 / 0 / 0 / 0 |
| `traditional chinese` / `simplified chinese` | 0 / 0 |
| `s2t` / `t2s` | 0 / 0 |

GitHub：

| 检索 | 结果 |
| --- | --- |
| `moonbit opencc` | 1 —— 只有本项目自己（Ljh684/opencc） |
| `moonbit 简繁` | 1 —— 同上 |
| `moonbit traditional chinese` | 0 |

结论：MoonBit 生态的中文文本处理已经凑齐了分词、拼音、中文数字等基础件，**唯独没有简繁与地区
用词转换**；本包是当前唯一一个。

## 2. 相邻包的能力边界

| 领域 | 已有包 | 与本项目的关系 |
| --- | --- | --- |
| 中文分词 | `colmugx/jieba`、`ppyq882/moonnlp` | 分词不改变字形；本项目不做分词，并把 jieba 变体列为非目标 |
| 拼音 | `walkzzz/pinyin`、`hcrrtte/MoonSpeech` | 不同任务 |
| 中文数字 / 金额 | `dongxuan2012/cnnum` | 数字域 |
| Unicode 归一化 / 字符属性 / 宽度 | `moonbit-community/unicode`、`unicodewidth`、`ucd` | 字符级属性，不含词级字形与地区用词映射 |
| 编码转换 | `tonyfettes/encoding` 等 | 字节编码，不是字形 |

它们既不是替代品，也无法组合出本项目的功能：简繁转换的关键在**词级词典 + 分词边界**，
而不是字符属性表。

## 3. 与 OpenCC (C++) 的关系与优势

本项目是 OpenCC 语义的 MoonBit 复刻，而且这一点是被验证过的，不是宣称的：

| 维度 | OpenCC (C++) | opencc.mbt |
| --- | --- | --- |
| 语义基准 | 本身即基准 | 官方 golden 语料 **5/5 逐字节一致**；CLI 文件输出与期望文件逐字节相同（22038 bytes） |
| 依赖形态 | C++ 工具链 + 运行时 `.ocd2` 资源 | 纯 MoonBit、零 FFI、数据在编译期内联 |
| 目标后端 | 原生与语言绑定 | wasm / wasm-gc / js / native 同一份代码 |
| 数据管线 | 构建期生成二进制词典（不可见） | 文本快照 + revision + 逐文件 SHA-256 + `--verify` 幂等校验 |
| 差异披露 | — | 每个配置引用但快照未提供的词典列在 `missing`；jieba 变体明确不覆盖 |
| 输入方式 | 支持 stdin 管道 | 文件 / `--text`（stdin 见「已知限制」） |

优势不是"比 OpenCC 更快"（我们不这样声称），而是：**同样的语义、可嵌入的形态、可审计的数据**。

## 4. 可核查的优势清单

1. **一致性可量化**：`opencc verify` 输出 `5 passed, 0 failed`；不是"看起来对"。
2. **数据可审计**：`data/opencc/REVISION` + `SHA256SUMS` + `tools/gen_dict --verify`
   让"数据从哪来、有没有被改过"变成一条命令可验证的事实。
3. **语义完整**：normalization / segmentation / 逐段 conversion 三段式；连 OpenCC 构建期
   生成的派生词典（`STPhrases_GeneratedFromRegionalPhrases`）也按上游规则复刻。
4. **零 FFI + 编译期内联数据**：库不读文件系统，同一份代码可编到 wasm / js / native。
5. **边界诚实**：missing 词典、非目标、stdio 限制都写在仓库里，而不是留给评审去发现。

## 5. 审阅者三分钟内能验证什么

```bash
moon check                                  # 类型检查，无警告
moon test                                   # 30 个单元测试（含 76099 条目的全量属性测试）
moon run cmd/opencc --target native -- verify              # 官方语料 5/5 + 往返一致性
moon run tools/gen_dict --target native -- --verify        # 数据与生成结果一致
moon run cmd/opencc --target native -- -c s2twp --text "内存泄漏与软件优化"
# => 記憶體洩漏與軟體最佳化
```

`verify` 还会把每份官方输出用反向配置转回去：`s2t → t2s` 与 `s2tw → tw2s` 逐字节回到源文本；
其余三对因快照缺少 OpenCC 构建期生成的词典而存在已知差异，命令会**列出缺哪一本**，
并把"反向链完整却出现差异"单独判为失败。

最后一行值得停留一秒：逐字替换只会得到 `內存泄漏與軟體優化`，而本项目给出的是台湾用词
`記憶體` / `軟體` / `最佳化`，并保持 `級別` 这类词不被误切——这正是词级词典 + 分词边界
约束的价值。

## 6. 已知限制（写在这里，而不是藏在后面）

- 不覆盖 OpenCC 的 `staging/` 实验字典与 `*_jieba` 分词变体配置。
- 部分配置（如 `t2s`）引用了 OpenCC 构建期生成的词典（`TSCharactersExt`），当前快照未提供，
  CLI 会在 `list-configs` 里标出 `[missing: …]`。
- 标准输入暂不支持：MoonBit 的 core 与 `moonbitlang/x` 目前没有标准输入 API，
  加 FFI 会让"零 FFI"这一条失效，因此先支持文件与 `--text`。
