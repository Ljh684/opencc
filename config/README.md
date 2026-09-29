# config — 配置的三种形态

这个包把 OpenCC 的 19 个配置提供成三层，按使用场景选择：

| 位置 | 形态 | 适用 |
| --- | --- | --- |
| `config/<name>/`（生成） | 单个配置，只 import 它用到的词典包 | 体积敏感：`examples/t2s` 249 KB、`examples/s2t` 913 KB（wasm-gc） |
| `config/chains.mbt`（生成） | 19 个配置的声明式数据（normalization / segmentation / conversion + missing） | 需要枚举配置、或自己做装配 |
| `config/build.mbt`（手写） | 按名字构建链：`chain(name)` / `convert(name, text)` | 名字只有运行期才知道（CLI、测试） |

`configs.mbt` 只保存 CLI 列表用的中文描述；机器可读的部分全部来自生成的 `chains.mbt`，
因此描述与行为不会各自漂移。

```moonbit
// 单一方向，体积最小
let chain = @s2t.chain()

// 名字在运行期才知道（代价是链入全部词典）
let out = @config.convert("s2twp", "内存泄漏与软件优化")
```
