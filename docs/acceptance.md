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
| OpenCC 官方 golden 一致性 | 100% 逐字节通过（10 份期望输出，覆盖 5 条链） | `opencc verify` 报告 + CI 记录 |
| 反方向覆盖（t2s / tw2s / hk2s） | 自建语料 + 词表覆盖率报告 | `reports/coverage.json` |
| 属性测试 | 分块一致性、非中文不变、幂等性 | `moon test` 中的属性用例 |
| wasm 产物体积 | 公开各配置的 minimal / standard 体积对比 | README 表格 |
| 性能 | 吞吐（MB/s）记录，与 OpenCC 参考实现对照 | `reports/benchmark.md` |

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
