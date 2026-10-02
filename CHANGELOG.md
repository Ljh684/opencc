# Changelog

本项目按功能推进，每个功能一个提交；这里记录对外可见的变化。

## Unreleased

- 网页/Node 演示 `examples/web`：`foreign_library` + `#export_name` 导出
  `opencc_to_taiwan` / `opencc_to_simplified`，附 `demo.mjs` 与 `index.html`。
- 热路径优化：跳过不可能命中任何词条的连续片段，ASCII 密集文本 4724 → 7503 码元/ms。
- GitHub Release [v0.1.0](https://github.com/Ljh684/opencc/releases/tag/v0.1.0)。
- CI 修复并转绿：安装脚本的两个主机都试、下载失败不再伪装成成功、干净 runner 上先
  `moon update` 建注册表索引；读文件的步骤显式用 `--target native`；两个 job 合并为一次
  工具链下载。仓库首页现在显示绿色 CI 徽章。
- CLI 支持多个 `-c` 按顺序串联（与上游一致），以及 `--input-dir` / `--output-dir` 目录批量
  转换（逐文件输出并汇总）；库侧新增 `config.convert_sequence(names, text)`。
- 回归基线：`test/fixtures/regression/` 给全部 19 个配置各留一份固定语料的输出，
  `regression/` 包的测试逐个比对——正确性仍由官方 golden 语料保证，基线只锁行为；
  配套工具 `tools/gen_baseline`（`--verify` 供 CI 使用）。

## 0.1.0 — 2026-09-24 起

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
