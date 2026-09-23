# test/fixtures/golden — 官方一致性语料

来自 OpenCC 仓库的 `test/golden/`：

```
input/us_constitution_zhs.txt                     中文（简体）输入
output/us_constitution_zhs.<config>.txt           各配置的期望输出
```

当前上游包含 1 份输入与 10 份期望输出，覆盖 `s2hk`、`s2hkp`、`s2t`、`s2tw`、`s2twp`
五条转换链（另有 `*_jieba` 变体，本项目暂不覆盖，见 `docs/design.md` 的非目标）。

获取方式：

```powershell
pwsh -File scripts/fetch-opencc-data.ps1
Copy-Item -Recurse vendor/opencc/test/golden/* test/fixtures/golden/
```

语料按 OpenCC 的 Apache-2.0 许可随仓库分发，来源记录在根目录 `NOTICE`。

校验方式：

```bash
opencc verify --golden test/fixtures/golden
```

输出每个配置的逐字节比对结果与通过率，作为项目的核心验收指标。
