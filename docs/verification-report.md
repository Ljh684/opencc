# Verification report

Generated 鈥?do not edit by hand. The CLI recomputes every number below
from the data compiled into this repository, and continuous integration
regenerates this file and fails on any difference, so it cannot go stale:

    moon run cmd/opencc --target native -- verify --report docs/verification-report.md

## Golden corpus

OpenCC ships expected output for a handful of configurations. The CLI
converts the source text with each one and compares byte for byte.
Source file: `test/fixtures/golden/input/us_constitution_zhs.txt` (7735 code units).

| configuration | result | missing dictionaries |
| --- | --- | --- |
| `s2t` | pass | - |
| `s2hk` | pass | - |
| `s2tw` | pass | - |
| `s2hkp` | pass | - |
| `s2twp` | pass | - |

5 passed, 0 failed; 5 `*_jieba` variant(s) skipped (word segmentation is a non-goal, see docs/design.md).

## Round trip

Every golden output is converted back with its reverse configuration and
compared with the source text, byte for byte. `note` means the reverse chain
is incomplete in this snapshot, so the pair is reported rather than claimed.

| direction | result | differing code units | missing dictionaries |
| --- | --- | --- | --- |
| `s2t -> t2s` | identical | 0 | ts_characters_ext |
| `s2tw -> tw2s` | identical | 0 | tw_variants_rev, ts_characters_ext |
| `s2twp -> tw2sp` | note | 30 | tw_variants_rev, ts_characters_ext |
| `s2hk -> hk2s` | note | 2 | hk_variants_rev, ts_characters_ext |
| `s2hkp -> hk2sp` | note | 6 | hk_variants_rev, ts_characters_ext |

## Configurations

All 19 built-in configurations. `not covered` means upstream ships no golden
output for it, so this project does not claim byte-exactness for it;
`missing dictionaries` lists dictionaries the pinned snapshot does not ship
(upstream OpenCC generates them during its own build), which the runtime
skips instead of failing the whole chain.

| configuration | golden corpus | missing dictionaries |
| --- | --- | --- |
| `hk2s` | not covered | hk_variants_rev, ts_characters_ext |
| `hk2sp` | not covered | hk_variants_rev, ts_characters_ext |
| `hk2t` | not covered | hk_variants_rev |
| `jp2t` | not covered | - |
| `s2hk` | covered | - |
| `s2hkp` | covered | - |
| `s2seal` | not covered | seal_characters_rev |
| `s2t` | covered | - |
| `s2tw` | covered | - |
| `s2twp` | covered | - |
| `seal2t` | not covered | seal_variants_rev |
| `t2hk` | not covered | - |
| `t2jp` | not covered | jp_shinjitai_characters_rev |
| `t2s` | not covered | ts_characters_ext |
| `t2seal` | not covered | seal_characters_rev |
| `t2tw` | not covered | - |
| `tw2s` | not covered | tw_variants_rev, ts_characters_ext |
| `tw2sp` | not covered | tw_variants_rev, ts_characters_ext |
| `tw2t` | not covered | tw_variants_rev |

5 covered, 14 not covered.

## Data snapshot

| field | value |
| --- | --- |
| repository | https://github.com/BYVoid/OpenCC |
| revision | b087c2612ce808f464b0925fc1c497d24971d179 (master) |
| dictionaries | 20 (19 upstream files, 1 derived) |
| entries | 76099 |
| verification | SHA-256 of every source file, re-checked by `moon run tools/gen_dict --target native -- --verify` |

## Source size

Counted by walking the checkout's `.mbt` files (build output and installed
dependencies are skipped), so the figures quoted in the write-up are checked
here instead of being maintained by hand.

| group | files | lines |
| --- | --- | --- |
| hand-written implementation | 15 | 3559 |
| generated data | 42 | 79776 |
| tests | 5 | 535 |
