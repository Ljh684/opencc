# Changelog

本项目按功能推进，每个功能一个提交；这里记录对外可见的变化。

## Unreleased

- 暂无。

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
