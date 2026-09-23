# 设计文档

## 目标

用纯 MoonBit 实现与 OpenCC 行为一致的简繁与地区用词转换，且满足：

1. **零 FFI、零运行时 I/O**：词典在构建期编译为 MoonBit 常量，便于 wasm 与边缘部署。
2. **行为可验证**：以 OpenCC 官方 golden 语料的逐字节比对作为唯一仲裁标准。
3. **可复现**：上游数据固定 revision，生成物带哈希，CI 重新生成并比对。

## 数据流

```
OpenCC 词典 (.txt)                OpenCC 配置 (.json)
        │                                  │
        ▼                                  ▼
   tools/gen_dict  ──────────────►  src/data/*.mbt, src/config/chain_data.mbt
        │                                  │
        └──────────► 编译期常量 ◄──────────┘
                            │
                            ▼
                    运行期转换引擎（无 I/O）
```

生成期负责去注释、去重、排序、值合并；运行期只做查表与匹配。

## 转换模型

OpenCC 的一次转换由三部分组成（以 `s2twp` 为例）：

1. **归一化（normalization）**：`CJK_Compatibility_Ideographs` 把兼容汉字归一为规范字形，
   保证后续词典查得到。
2. **分词（segmentation）**：以词组词典做最大匹配分词，输出可用于后续替换的切分结果。
3. **转换链（conversion_chain）**：按顺序执行多趟替换，每趟是一个词典组：

   ```
   chain[0] = short_circuit( union(STPhrases, STPhrases_GeneratedFromRegionalPhrases),
                             STCharacters )
   chain[1] = short_circuit( TWPhrases, TWVariantsPhrases, TWVariants )
   ```

   即：先查词组词典（命中即用），未命中再落到单字词典；随后把台湾用词与变体字
   再走一遍。**顺序即语义**，不能重排。

### 词典组语义

| 策略 | 含义 |
| --- | --- |
| `union` | 在所有子词典中取最长匹配；长度相同则取先出现的子词典 |
| `short_circuit` | 按子词典顺序查找，第一个命中即为结果 |

### 匹配

在位置 `i` 上，对词典做最长匹配：命中最长的 key 则输出其 value 并把游标前移
`key.length()`；无命中则原样输出一个字符并前移 1。词组优先于单字由
`short_circuit` 的顺序保证，而不是靠「更长的 key 优先」这一条规则单独完成。

## 字符模型

MoonBit 的 `String` 以 UTF-16 码元存储，增补平面字符占两个码元。对本项目的影响：

- 绝大多数词典 key 位于 BMP，按码元匹配与按码点匹配结果一致。
- CJK 兼容汉字（U+2F800–U+2FA1F）属于增补平面，必须先生成规范字形再匹配。

因此引擎在入口处把输入规范化为 `Array[Char]` 处理，输出时再还原为 `String`；
归一化字典与代理对处理是 W1 的交付内容。

## 体积与性能策略

wasm 场景下词典体积是首要约束，因此提供三档取舍：

| 档位 | 内容 | 适用 |
| --- | --- | --- |
| `minimal` | 仅单字词典 + 常用词组 | 体积敏感（< 100 KB 量级） |
| `standard` | 一个配置所需的全部词典 | 默认 |
| `full` | 全部 19 个配置的词典 | 服务端 / 桌面 |

每个配置只引用自己需要的词典，避免「装一个配置、背全部数据」。

## 测试策略

1. **官方一致性**：`test/fixtures/golden` 中的输入与期望输出逐字节比对。
2. **属性测试**：随机分块与整体转换结果一致；非中文字符不变；幂等性。
3. **单元测试**：词典组合语义、最长匹配边界、空串、纯 ASCII、emoji。
4. **回归**：每次词典更新都重跑全部一致性用例，并记录通过率变化。

## 非目标

不做分词服务、不做拼音、不做 GUI；不追求与 OpenCC 的 `staging` 实验字典一致。
