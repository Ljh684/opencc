# 验收标准与自查清单

对照黑客松官方验收口径，逐条给出可执行的自查方式。

| 官方要求 | 本项目的满足方式 | 自查命令 / 证据 |
| --- | --- | --- |
| 以 MoonBit 为主要实现语言 | 引擎、生成器、CLI、测试全部 MoonBit，零 FFI | `moon check --target all`，仓库内无 `extern` FFI 绑定 |
| 仓库公开、开发记录连续可追踪 | 公开 GitHub 仓库，W1–W4 每周 2 次以上提交并打 tag | `git log --oneline`、Releases 页 |
| 清晰 README、可运行示例与必要测试 | README 含 quickstart、19 配置对照表、CLI 示例；`moon test` 一键全跑 | `moon test` 全绿输出 |
| 已有项目须含本期实质新增工作 | 全新项目；mooncakes 与 GitHub 均无同等能力的包 | 见下方「查重记录」 |
| 使用认可的开源许可证并说明来源 | 代码 Apache-2.0；数据派生自 Apache-2.0 的 OpenCC，NOTICE 署名 + 生成物哈希 | `LICENSE`、`NOTICE` |
| AI 可辅助但质量由参赛者掌握 | README 说明 AI 使用范围；算法、词典语义、验收口径由作者设计并复核 | README「AI 使用说明」章节 |

## 核心验收指标

| 指标 | 目标 | 产出 |
| --- | --- | --- |
| 数据可审计 | 上游快照带 revision 与逐文件 SHA-256，生成前校验 | `data/opencc/REVISION`、`data/opencc/SHA256SUMS` |
| 生成代码可复现 | `tools/gen_dict --verify` 在生成结果与仓库不符时退出码 1 | `moon run tools/gen_dict -- --verify` |
| OpenCC 官方 golden 一致性 | 100% 逐字节通过（5 条链各 1 份期望输出） | `moon run cmd/opencc -- verify` |
| 结果可核对、不可过期 | `verify --report` 生成覆盖 / 往返 / 数据快照 / 代码规模报告，CI 重新生成后逐字节 diff | `docs/verification-report.md`、`docs/verification-report.json` |
| CLI 输出逐字节一致 | 文件输出与期望文件字节相同（s2twp：22038 bytes） | `opencc convert -c s2twp --input … --output …` 后比对 |
| 反方向覆盖（t2s / tw2s / hk2s） | 自建语料 + 词表覆盖率报告 | `reports/coverage.json` |
| 属性测试 | 分块一致性、非中文不变、幂等性 | `moon test` 中的属性用例 |
| wasm 产物体积 | 公开各配置的 minimal / standard 体积对比 | README 表格 |
| 性能 | 吞吐记录，与 OpenCC 参考实现对照 | [performance.md](performance.md) |

## 官方语料实测（2026-09-25）

```
$ moon run cmd/opencc --target native -- verify
golden input : test/fixtures/golden/input/us_constitution_zhs.txt (7735 code units)
  ok   s2t
  ok   s2hk
  ok   s2tw
  ok   s2hkp
  ok   s2twp
golden result: 5 passed, 0 failed, 5 skipped (unsupported variants)
```

5 条链逐字节一致；跳过的是 `*_jieba` 变体（分词器差异，见 design 的非目标）。
另外 19 个配置里凡引用快照未提供词典的，`gen_dict` 会在生成的 ChainSpec 里列出
`missing`，CLI 也会在报告里标出——不隐藏差异。

## 工程指标实测（2026-09-25，数据表示改造后）

| 指标 | 数值 |
| --- | --- |
| 单元测试 | 26 个；四个后端（wasm / wasm-gc / js / native）全部通过 |
| 测试耗时 | wasm-gc 0.8 s，plain wasm 1.6 s，native 7 s |
| `opencc verify`（native，含首次构建） | 3.4 s |
| 生成数据体积 | 1.68 MB（20 个词典 / 76099 条目） |
| CLI 产物 | wasm-gc 1.31 MB / js 1.66 MB / native 1.54 MB |

改造前后对比（同一台机器）：native 测试 341 s → 7 s，plain wasm 由"编译失败"
变为通过。详见 [performance.md](performance.md)。

## 反方向与属性覆盖（2026-09-25）

`opencc verify` 除了正向逐字节比对外，还会把每份官方输出用对应的反向配置转回去：

| 往返对 | 结果 | 说明 |
| --- | --- | --- |
| `s2t → t2s` | 逐字节回到源文本 | 反向链完整 |
| `s2tw → tw2s` | 逐字节回到源文本 | 反向链完整 |
| `s2twp → tw2sp` | 30 个码元不同 | 缺 `tw_variants_rev`、`ts_characters_ext` |
| `s2hk → hk2s` | 2 个码元不同 | 缺 `hk_variants_rev`、`ts_characters_ext` |
| `s2hkp → hk2sp` | 6 个码元不同 | 同上 |

判定规则写在命令里：**反向链完整却出现差异就是 FAIL（回归）**；缺词典造成的差异记为
`note` 并列出缺哪一本。这样"已知缺口"和"回归"不会混在一起。

单元测试里的属性覆盖（30 个测试）：

- **全量条目属性**：20 个词典共 76099 条，逐条以 key 自身为输入，索引必须返回该条的 value；
- **缺失词典台账**：任何配置缺的词典必须落在已知的 6 本之内；被验证的 5 条正向链必须完整；
- **行粒度性质**：按行转换与整体转换结果一致（词典 key 不含换行、分词也不会跨行，这同时是未来流式 API 的依据）；
- **二次转换稳定**：5 条正向链对自己的输出再次转换保持不变；
- **分词边界与嵌套词典组语义**：见 `core` 的白盒测试。

## 查重记录（2026-09-24）

在 mooncakes.io 全量包清单（2634 个包）与 GitHub MoonBit 仓库（topic:moonbit，341 个）中检索：

| 检索项 | 命中 |
| --- | --- |
| `opencc` | 0 |
| `简繁` / `简体` / `繁体` / `traditional chinese` | 0 |
| GitHub `moonbit opencc` / `moonbit 简繁` | 0 |

相邻但不同领域的包：`colmugx/jieba`、`ppyq882/moonnlp`（分词）、`walkzzz/pinyin`、`hcrrtte/MoonSpeech`（拼音 / 输入法）、`dongxuan2012/cnnum`（中文数字）。

## 提交纪律

- 每个提交聚焦一件事，信息用 Conventional Commits：`feat:`、`fix:`、`test:`、`docs:`、`chore:`。
- 词典或配置更新必须附带一致性报告的通过率变化。
- 任何行为差异都在 `docs/design.md` 记录，不做静默修改。

## 下游可用性（2026-10-03 实测）

用一个**独立的消费者模块**验证过：在 `moon.work` 里同时挂上本模块与消费者模块，
消费者只需在 `moon.pkg` 里 `import { "Ljh684/opencc/config" }`，随后
`config.convert("s2twp", …)` 与 `config.convert_sequence(["s2t", "t2s"], …)` 都能直接跑出结果
（输出分别为 `記憶體洩漏與軟體最佳化` 与原文，后者对应已验证的往返性质）。
也就是说「下游怎么依赖它」不是承诺，而是跑通过的路径。

## 覆盖层次（2026-10-03）

| 层次 | 覆盖 | 说明 |
| --- | --- | --- |
| 官方 oracle | 正向 5 条链（s2t / s2hk / s2tw / s2hkp / s2twp） | 逐字节比对；另含往返检查 |
| 回归锁 | **全部 19 个配置** | `test/fixtures/regression/` + `regression/` 包的测试；锁行为，不主张正确性 |
| 数据 | 20 个词典 / 76099 条 | SHA-256 + 重新生成比对 |
| 属性 | 76099 条词条 | 逐条命中自身 key，另含分词边界、行粒度、稳定性 |

## 可核对报告（2026-10-07）

`opencc verify --report <path>` 把同一批结果落成文档（路径以 `.json` 结尾则出 JSON）：19 个配置
各自的覆盖状态与缺失词典、5 条正向往返、数据快照（上游 revision、20 个词典 / 76099 条、
SHA-256 校验方式），以及**代码规模**（手写实现 15 个文件 3559 行、生成数据 42 个文件 79776 行、
测试 5 个文件 535 行）。

报告不含时间戳、主机名或耗时，是「输入 + 仓库内容」的纯函数，因此 CI 会重新生成
`docs/verification-report.md` 与 `.json` 并 `git diff --exit-code`：过期即构建失败。赛方要
核对申报书里的任何数字，跑一条命令就能复现：

```bash
moon run cmd/opencc --target native -- verify --report docs/verification-report.md
```

同时 `moon test` 里有一条测试（`cmd/opencc/report_wbtest.mbt`）锁住「报告必须列出全部 19 个
配置、且两次生成逐字节相同」，避免报告渲染在重构中悄悄退化。
