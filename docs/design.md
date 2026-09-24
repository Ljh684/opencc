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
   tools/gen_dict  ──────────────►  dict/*.mbt, config/chain_data.mbt
        │                                  │
        └──────────► 编译期常量 ◄──────────┘
                            │
                            ▼
                     运行期转换引擎（无 I/O）
```

生成期负责去注释、去重、排序、值合并；运行期只做查表与匹配。

### 数据快照

上游数据保存在 `data/opencc/`（词典、配置）与 `test/fixtures/golden/`（一致性语料），
随仓库提交，来源 revision、归档哈希与逐文件 SHA-256 分别记录在
`data/opencc/REVISION` 与 `data/opencc/SHA256SUMS`。

这样做有三个后果，都是有意的：

1. 测试与 CI 不需要网络，评审可以离线复现全部结果。
2. 数据更新是一次显式的、可 review 的提交，而不是构建期的隐式下载。
3. 生成器在读取前先比对校验和，数据被改动时不生成代码。

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

### 三段式管线

一个配置由三部分组成，顺序即语义（与 OpenCC 的 `normalization` / `segmentation` /
`conversion_chain` 一一对应）：

1. **归一化（normalization）**：对整段文本按顺序做若干趟替换（如 CJK 兼容汉字归一）。
2. **分词（segmentation）**：用分词词典做最大匹配，得到若干**词段**：命中的词自成一
   段，未命中的字符累积成一段。
3. **转换（conversion）**：把转换链**逐段**应用——每个词段独立走完整条链，再拼回。

第 3 步的「逐段」不是优化，而是语义：词典匹配不允许跨越词段边界，否则
`较低级别` 会因为 TW 用词词典里的 `低級` 而变成 `較低階別`，而 OpenCC 的输出是
`較低級別`（`级别` 已是词段，`低` 与 `級別` 分属两段）。

### 匹配

词典在构建时按 **首字（首个 UTF-16 码元）分组**，组内按 key 长度降序排列。
在位置 `i` 上只扫描首字匹配的那一组：第一次命中即最长匹配，随即输出其 value 并把
游标前移 `key.length()`；无命中则原样输出一个字符并前移 1。

词组优先于单字由 `short_circuit` 的顺序保证，而不是靠「更长的 key 优先」这一条规则
单独完成。实测组大小与吞吐见 [performance.md](performance.md)。

### 数据的表示

生成的 `dict/*.mbt` 不再逐条列出 `(key, value)`，而是**内嵌词典自身的文本**：

```moonbit
let st_characters_chunk_0 : String =
  #|㐷	傌
  #|㐹	㑶 㐹

pub let st_characters : Array[String] = [st_characters_chunk_0]
```

运行期由 `core/Dict::parse` 扫描一次建立首字索引。这样做的原因：

1. **编译代价**：7.6 万条目逐条字面量会让 native 编译器生成巨大单元（实测 `moon test
   --target native` 341 s），改成一个词典一个字符串块后降到 7 s。
2. **后端上限**：plain wasm 后端对单个函数的局部变量数量有上限，逐条字面量会直接编译失败；
   文本块形式四个后端都能通过。
3. **可审计**：内嵌文本与 `data/opencc/dictionary/*.txt` 逐字节相同，哈希记录在
   `dict/manifest.mbt`；要核对数据是否被改动，不需要读生成代码的语法，只要比对文本。

代价是启动时多一次扫描（约 16 ms / 20 个词典），以及 `#|` 原样字符串会吃掉每行一个前导空格，
因此生成器拒绝任何以空格开头的数据行（当前快照没有这种行）。

### 派生词典

OpenCC 有几个词典是它自己在构建期生成的。本项目复刻了其中的
`STPhrases_GeneratedFromRegionalPhrases`：取 HK / TW 词组词典的每个 key，用 `t2s`
配置转成简体，再映射回原来的地区词组；简体投影短于 3 个码元的条目被丢弃（否则会
切断更长的简体词）。生成结果同时落成可审计的文本 `data/derived/…txt` 与编译期数据。

没有这一步，`马里兰` 会变成 `馬裏蘭` 而不是 OpenCC 的 `馬里蘭`。

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
