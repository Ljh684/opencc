# 一页项目说明

**项目名**：`opencc.mbt` — MoonBit 原生简繁与地区用词转换
**仓库**：<https://github.com/Ljh684/opencc>
**方向**：数据处理 · 内容处理工具
**许可**：Apache-2.0（词典数据派生自同样是 Apache-2.0 的 OpenCC）

## 要解决的问题

中文文本处理离不开简繁与地区用词转换：搜索索引、内容分发、跨境电商、出版排版、语料清洗
都要用它。MoonBit 生态已经有中文分词（jieba、moonnlp）、拼音、中文数字，唯独缺这一层；
而 OpenCC 只有 C++ 实现，进不了 wasm 与边缘场景。

## 交付物

1. **纯 MoonBit 转换引擎**：首字索引、可嵌套词典组、normalization → segmentation →
   逐段转换三条链路；
2. **数据管线**：把 OpenCC 快照编译成内嵌文本块，逐文件 SHA-256 校验，`--verify` 幂等；
3. **CLI 与库 API**：`list-configs` / `convert` / `verify`，以及 `convert(name, text)`；
4. **派生词典复刻**：按上游脚本重建 OpenCC 构建期生成的全部 6 个派生词典
   （`*Rev`、`TSCharactersExt`、地区词组投影），并留下可读文本。
5. **官方 testcases 语料**：`verify` 逐条比对上游自带期望输出，覆盖全部 19 个配置。

## 与现有作品的区别（都可核查）

| 维度 | 事实 | 怎么核 |
| --- | --- | --- |
| 无重复 | mooncakes 全量 **2752** 个包中，`opencc`/`简繁`/`简体`/`繁体`/`s2t`/`t2s` 命中 **0**；GitHub `moonbit opencc` 只指向本项目 | 见 [comparison.md](comparison.md) 第 1 节 |
| 语义等价 | OpenCC 官方 golden 语料 **5/5 逐字节通过**，官方 testcases 语料 **583/583 逐字节复现**（19 个配置、262 例） | `opencc verify` |
| 可逆性 | `s2t → t2s`、`s2tw → tw2s`、`s2hk → hk2s` 往返逐字节回到源文本；`s2twp → tw2sp` 的差异属上游数据性质（见 design.md） | `opencc verify` 的 round-trip 段 |
| 形态 | 纯 MoonBit、零 FFI、编译期内联数据；wasm / wasm-gc / js / native 四后端都能构建并测 | `moon test --target <t>` |
| 体积 | 单方向构建 t2s **259 KB**、s2t **914 KB**（全量 CLI 1622 KB，wasm-gc release） | `moon build examples/t2s --target wasm-gc --release` |
| 可用性 | CLI（`convert` / `verify`）与库 API；`examples/web` 导出可在浏览器/Node 直接调用的函数 | `node examples/web/demo.mjs` |

## 当前进度

从 2026-09-24 起持续提交，每完成一个功能就打一个提交；`moon check` 无警告，
**50 个单元测试**（含覆盖 89817 条词典条目的全量属性测试），官方 golden 5/5 与
官方 testcases 583/583。
详细证据与复现命令见 [acceptance.md](acceptance.md)。

## 非目标（划清边界）

- 不做分词 / 拼音 / 中文数字（生态已有，且与本项目不同任务）；
- 不覆盖 OpenCC 的 `staging/` 实验字典与 `*_jieba` 分词变体；
- 暂不支持标准输入：MoonBit 的 core 与 `moonbitlang/x` 没有标准输入 API，加 FFI 会破坏
  「零 FFI」，因此先支持文件与 `--text`；

## 后续计划

1. ~~发布到 mooncakes~~ **已完成**：`Ljh684/opencc` v0.1.0，`moon add Ljh684/opencc` 可直接安装；
2. 演示素材：网页 demo 已完成（`examples/web`），README 动图仍有空间；
3. ~~继续扩大逐字节证据的覆盖面~~ **已完成**：官方 testcases 让 19 个配置都有逐字节证据。
