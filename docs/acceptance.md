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
| OpenCC 官方 testcases 一致性 | 19 个配置、262 例 / 583 条官方期望全部逐字节复现（含反方向与地区方向） | `data/opencc/testcases/testcases.json`、`moon run cmd/opencc -- verify` |
| 结果可核对、不可过期 | `verify --report` 生成覆盖 / 往返 / 数据快照 / 代码规模报告，CI 重新生成后逐字节 diff | `docs/verification-report.md`、`docs/verification-report.json` |
| CLI 输出逐字节一致 | 文件输出与期望文件字节相同（s2twp：22038 bytes） | `opencc convert -c s2twp --input … --output …` 后比对 |
| 派生词典与上游等价 | 6 个 OpenCC 构建期派生词典在 MoonBit 中按上游脚本复刻，并用独立实现逐字节校验 | `data/derived/`、`moon test -p tools/gen_dict` |
| 属性测试 | 分块一致性、非中文不变、幂等性 | `moon test` 中的属性用例 |
| wasm 产物体积 | 公开各配置的 minimal / standard 体积对比 | README 表格 |
| 性能 | 吞吐记录，与 OpenCC 参考实现对照 | [performance.md](performance.md) |

## 官方语料实测（2026-10-16）

```
$ moon run cmd/opencc --target native -- verify
golden input : test/fixtures/golden/input/us_constitution_zhs.txt (7735 code units)
  ok   s2t
  ok   s2hk
  ok   s2tw
  ok   s2hkp
  ok   s2twp
golden result: 5 passed, 0 failed, 5 skipped (unsupported variants)
test cases    : data/opencc/testcases/testcases.json
  583 official expectation(s) in 262 case(s), 583 reproduced
  ok   hk2s  22/22      ok   s2twp 86/86      ok   t2seal 8/8
  ok   hk2sp 9/9        ok   seal2t 6/6       ok   t2tw  11/11
  ok   hk2t  17/17      ok   t2hk  17/17      ok   tw2s  33/33
  ok   jp2t  4/4        ok   t2jp  4/4        ok   tw2sp 54/54
  ok   s2hk  53/53      ok   t2s   56/56      ok   tw2t  18/18
  ok   s2hkp 9/9        ok   s2seal 1/1
  ok   s2t   108/108    ok   s2tw  67/67
```

golden 5 条链逐字节一致；跳过的是 `*_jieba` 变体（分词器差异，见 design 的非目标）。
官方 testcases 覆盖全部 19 个配置（含 `t2s`、`tw2s`、`tw2sp`、`hk2s`、`seal2t` 等反方向
与地区方向），583 条期望全部复现。19 个配置的 `missing` 列表现在**全为空**：快照没带的
6 个派生词典已按上游脚本复刻（见下节）。

## 工程指标实测（2026-10-16）

| 指标 | 数值 |
| --- | --- |
| 单元测试 | 50 个（native；其余后端 47 个）；四个后端全部通过 |
| `opencc verify`（native，含首次构建与 583 条官方期望） | 约 60 s |
| 生成数据体积 | 1.9 MB（26 个词典 / 89817 条目，含 6 本派生词典） |
| 单方向产物 | wasm-gc：t2s 259 KB、s2t 914 KB、全量 CLI 1622 KB |

改造前后对比（同一台机器）：native 测试 341 s → 7 s，plain wasm 由"编译失败"
变为通过。详见 [performance.md](performance.md)。

## 派生词典与代理对修复（2026-10-16）

快照原本缺 6 本 OpenCC 构建期生成的词典（`TWVariantsRev`、`HKVariantsRev`、
`JPShinjitaiCharactersRev`、`SealCharactersRev`、`SealVariantsRev`、`TSCharactersExt`），
反向配置只能"带缺口运行"。现在 `tools/gen_dict` 按上游脚本（`data/scripts/reverse.py`、
`data/scripts/extract_tofu_risk.py`）在 MoonBit 里复刻这 6 本，并且：

- 复刻结果与一份**独立实现**（另一语言、另一运行时）逐字节一致（6/6，共 13718 条）；
- 排序按码点而非 UTF-16 码元（篆书词典里有 U+20000 以上的字）；
- 单元测试锁住规则本身：值合并顺序、`@reverse-prefer` 前置、`@tofu-risk` 去掉自身映射、
  以及"上游会当构建错误"的情形（无映射的偏好、空扩展映射）。

接上官方 testcases 后暴露了一个真实缺陷：**基本平面以外的字符会被吞掉**。原因是透传分支按
单个 UTF-16 码元前进，而 MoonBit 的字符串切片在起点落在低代理项时返回空视图。引擎现在按
**字符**前进（`core::char_width`），并新增 4 条回归测试。修复前后官方 testcases 通过数：
576/583 → **583/583**（`seal2t` 5 条、`t2s` 2 条）。

单元测试里的属性覆盖：

- **全量条目属性**：26 个词典共 89817 条，逐条以 key 自身为输入，索引必须返回该条的 value；
- **代理对完整性**：BMP 以外的字符在未命中时原样保留，命中时整体替换；
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

## 覆盖层次（2026-10-16）

| 层次 | 覆盖 | 说明 |
| --- | --- | --- |
| 官方 golden | 正向 5 条链（s2t / s2hk / s2tw / s2hkp / s2twp） | 长文本逐字节比对 |
| 官方 testcases | **全部 19 个配置**（262 例 / 583 条期望） | 上游自带期望输出，反方向与地区方向的正确性依据 |
| 回归锁 | **全部 19 个配置** | `test/fixtures/regression/` + `regression/` 包的测试；锁行为，不主张正确性 |
| 数据 | 26 个词典 / 89817 条 | 快照逐文件 SHA-256 + 重新生成比对 + 派生词典与独立实现比对 |
| 属性 | 89817 条词条 | 逐条命中自身 key，另含分词边界、行粒度、稳定性、代理对完整性 |
| 观察项 | 5 条正向往返 | `s2twp → tw2sp`、`s2hkp → hk2sp` 非恒等，属上游数据性质 |

## 可核对报告（2026-10-07）

`opencc verify --report <path>` 把同一批结果落成文档（路径以 `.json` 结尾则出 JSON）：官方
golden 与官方 testcases 的逐配置通过数、19 个配置的覆盖状态与缺失词典（现在全为空）、5 条
正向往返观察、数据快照（上游 revision、26 个词典 / 89817 条、SHA-256 校验方式），以及
**代码规模**（手写实现 15 个文件 4196 行、生成数据 48 个文件 93671 行、测试 6 个文件 682 行）。

报告不含时间戳、主机名或耗时，是「输入 + 仓库内容」的纯函数，因此 CI 会重新生成
`docs/verification-report.md` 与 `.json` 并 `git diff --exit-code`：过期即构建失败。赛方要
核对申报书里的任何数字，跑一条命令就能复现：

```bash
moon run cmd/opencc --target native -- verify --report docs/verification-report.md
```

同时 `moon test` 里有一条测试（`cmd/opencc/report_wbtest.mbt`）锁住「报告必须列出全部 19 个
配置、且两次生成逐字节相同」，避免报告渲染在重构中悄悄退化。
