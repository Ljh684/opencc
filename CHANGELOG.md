# Changelog

本项目按功能推进，每个功能一个提交；这里记录对外可见的变化。

## 0.1.1 — 2026-10-16

- **补齐派生词典**：按上游脚本（`data/scripts/reverse.py`、`extract_tofu_risk.py`）在
  MoonBit 中复刻 OpenCC 构建期生成的 6 个词典——`TWVariantsRev`、`HKVariantsRev`、
  `JPShinjitaiCharactersRev`、`SealCharactersRev`、`SealVariantsRev`、`TSCharactersExt`。
  词典总数 20 → 26、条目 76099 → 89817，**19 个配置再没有缺失的 pass**（`missing` 全为空）。
  复刻结果与一份独立实现逐字节比对（6/6、13718 条），并补 6 条规则单元测试
  （值合并顺序、`@reverse-prefer` 前置、`@tofu-risk` 去掉自身映射、按码点排序）。
- **接入官方 testcases 语料**：`data/opencc/testcases/testcases.json`（上游自带期望输出）
  入库并在 `opencc verify` 中逐条比对，覆盖全部 19 个配置：262 例 / 583 条期望，
  **583/583 逐字节复现**。反方向与地区方向（`t2s`、`tw2s`、`tw2sp`、`hk2s`、`seal2t`…）
  第一次有了官方证据。
- **修复代理对缺陷**：官方语料暴露了一个真实 bug——未命中时透传按单个 UTF-16 码元前进，
  而 MoonBit 的字符串切片在起点落在低代理项时返回空视图，于是基本平面以外的字符（罕见
  汉字、小篆）会被吞掉。引擎改为按字符前进（`core::char_width`），新增
  `core/astral_wbtest.mbt` 的 4 条回归测试；官方 testcases 通过数 576/583 → 583/583。
- `verify` 的往返检查改为**观察项**（`TWPhrasesRev` 不是 `TWPhrases` 的精确逆，差异属上游
  数据性质），正确性判定改为官方 golden + 官方 testcases；报告新增 testcases 段落，
  CI 步骤相应更名。
- **可核对报告**：`opencc verify --report <path>` 把同一批结果落成文档（`.json` 后缀出 JSON）——
  19 个配置各自的覆盖状态与缺失词典、5 条正向往返、数据快照（revision / 词典数 / 词条数 /
  SHA-256 校验方式）以及代码规模（手写实现 15 个文件 4196 行、生成数据 48 个文件 93671 行、
  测试 6 个文件 682 行）。报告不含时间戳，是仓库内容的纯函数，CI 重新生成
  `docs/verification-report.md` 与 `.json` 后 `git diff --exit-code`，因此申报书里的数字
  不会与代码脱节；`cmd/opencc/report_wbtest.mbt` 另有一条测试锁住「列全 19 个配置 + 两次生成
  逐字节相同」。
- 网页/Node 演示 `examples/web`：`foreign_library` + `#export_name` 导出
  `opencc_to_taiwan` / `opencc_to_simplified`，附 `demo.mjs` 与 `index.html`。
- 热路径优化：跳过不可能命中任何词条的连续片段，ASCII 密集文本 4724 → 7503 码元/ms。
- CI 修复并转绿：安装脚本的两个主机都试、下载失败不再伪装成成功、干净 runner 上先
  `moon update` 建注册表索引；读文件的步骤显式用 `--target native`；两个 job 合并为一次
  工具链下载。仓库首页现在显示绿色 CI 徽章。
- CLI 支持多个 `-c` 按顺序串联（与上游一致），以及 `--input-dir` / `--output-dir` 目录批量
  转换（逐文件输出并汇总）；库侧新增 `config.convert_sequence(names, text)`。
- 回归基线：`test/fixtures/regression/` 给全部 19 个配置各留一份固定语料的输出，
  `regression/` 包的测试逐个比对——正确性仍由官方 golden 语料保证，基线只锁行为；
  配套工具 `tools/gen_baseline`（`--verify` 供 CI 使用）。

## 0.1.0 — 2026-09-24 起

### 发布

- **已发布**：`Ljh684/opencc` v0.1.0 上线 mooncakes（<https://mooncakes.io/docs/Ljh684/opencc>）。
  安装路径实测：干净模块里 `moon add Ljh684/opencc` → 下载 → 调用 `config.convert("s2twp", …)`
  输出 `記憶體洩漏與軟體最佳化`，并报告 19 个配置可用。
- GitHub Release [v0.1.0](https://github.com/Ljh684/opencc/releases/tag/v0.1.0)。

### 新增

- 纯 MoonBit 转换引擎：首字索引、可嵌套词典组（`union` / `short_circuit`）、
  normalization → segmentation → 逐段 conversion 三段式管线。
- 数据管线 `tools/gen_dict`：编译 20 个词典 / 76099 条目为内嵌文本块，
  逐文件 SHA-256 校验，`--verify` 幂等校验，缺失词典台账。
- 复刻 OpenCC 构建期生成的 `STPhrases_GeneratedFromRegionalPhrases`（含可读文本产物）。
- CLI：`list-configs`、`convert`（`-c/-i/-o/--text`）、`verify`（含往返检查）。
- 库 API：`config.chain(name)`、`config.convert(name, text)`、`config.missing_dictionaries(name)`。
- 每个词典与每个配置各自成包，单方向构建体积从 1341 KB 降到 249 KB（t2s，wasm-gc）。
- 示例：`examples/s2t`、`examples/t2s`。

### 测试与证据

- 31 个单元测试：匹配语义、分词边界、嵌套组、解析、缺失词典台账、行粒度、稳定性，
  以及覆盖 76099 条目的全量属性测试。
- 官方 golden 语料 5/5 逐字节通过；`s2t → t2s` 与 `s2tw → tw2s` 往返逐字节一致。
- 四个后端（wasm / wasm-gc / js / native）构建并运行测试；构建耗时与体积记录在
  `docs/performance.md`。
