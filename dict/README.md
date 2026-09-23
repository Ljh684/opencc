# dict — 编译期词典数据

本目录由 `tools/gen_dict` 生成，**请勿手工编辑**。

```
dict/<dict_name>.mbt        单个词典：排序后的 (key, value) 数组 + 元数据
dict/manifest.mbt           词典清单、上游 revision、每个文件的 SHA-256
```

生成步骤：

```powershell
pwsh -File scripts/fetch-opencc-data.ps1                 # 下载上游数据到 vendor/
moon run tools/gen_dict -- --input data/opencc --out dict
```

约定：

- 词典内容派生自 OpenCC（Apache-2.0），来源与 revision 见仓库根目录的 `NOTICE`。
- 生成器同时写出 `manifest.mbt`；CI 会用 `tools/gen_dict --verify` 重新生成并比对哈希，
  确保仓库内的数据与固定的上游 revision 一致。
- 生成文件在 `moon fmt` 中通过 `formatter(ignore: ...)` 跳过，避免格式化噪声。
