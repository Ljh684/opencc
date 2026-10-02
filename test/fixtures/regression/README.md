# test/fixtures/regression — 全配置回归基线

`input.txt` 是一份固定语料（简繁混排、日文假名、ASCII、标点、空行）。
同目录下的 `<config>.txt` 是 19 个配置各自对这份语料的输出。

**性质说明（重要）**：这些基线是**回归锁**，不是正确性 oracle。
正确性由 `test/fixtures/golden/` 里 OpenCC 官方语料逐字节比对保证（5 条链）；
基线只保证"行为不会在无人察觉的情况下改变"，覆盖了没有官方语料的另外 14 个配置。

什么时候需要更新基线：**只有当行为变化是有意为之**（例如修了一个真实 bug），
并且更新理由是可以在提交信息里写清楚的。更新命令：

```bash
moon run tools/gen_baseline --target native            # 写入基线
moon run tools/gen_baseline --target native -- --verify # 只校验（CI 用）
```

`regression/` 包里的测试会逐个配置比对；任何不一致都会失败并指出是哪个配置。
