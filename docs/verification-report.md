# Verification report

Generated - do not edit by hand. The CLI recomputes every number below
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

## Official test cases

Upstream's `test/testcases/testcases.json` pairs an input with the output
every listed configuration must produce. It covers all nineteen
configurations, including the reverse and regional directions the golden
corpus stops short of, so reproducing it is what backs the claim that this
engine behaves like OpenCC everywhere, not only in the five `s2*` chains.

| configuration | passed | failed |
| --- | --- | --- |
| `hk2s` | 22 | 0 |
| `hk2sp` | 9 | 0 |
| `hk2t` | 17 | 0 |
| `jp2t` | 4 | 0 |
| `s2hk` | 53 | 0 |
| `s2hkp` | 9 | 0 |
| `s2seal` | 1 | 0 |
| `s2t` | 108 | 0 |
| `s2tw` | 67 | 0 |
| `s2twp` | 86 | 0 |
| `seal2t` | 6 | 0 |
| `t2hk` | 17 | 0 |
| `t2jp` | 4 | 0 |
| `t2s` | 56 | 0 |
| `t2seal` | 8 | 0 |
| `t2tw` | 11 | 0 |
| `tw2s` | 33 | 0 |
| `tw2sp` | 54 | 0 |
| `tw2t` | 18 | 0 |
| **total** | **583** | **0** |

262 case(s), 583 expectation(s); 583 reproduced byte for byte, 0 differ.

## Round trip

Every golden output is converted back with its reverse configuration and
compared with the source text, byte for byte. This is an observation, not a
gate: `TWPhrasesRev` is not the exact inverse of `TWPhrases` (it maps Taiwan
wording back to the Traditional form the forward pass never produced), so a
difference here is a property of the upstream data. The official test cases
above are the correctness gate.

| direction | result | differing code units | missing dictionaries |
| --- | --- | --- | --- |
| `s2t -> t2s` | identical | 0 | - |
| `s2tw -> tw2s` | identical | 0 | - |
| `s2twp -> tw2sp` | differs | 30 | - |
| `s2hk -> hk2s` | identical | 0 | - |
| `s2hkp -> hk2sp` | differs | 4 | - |

## Configurations

All 19 built-in configurations. `golden corpus` marks the ones the golden corpus
pins byte for byte; the official test cases above cover all of them, which is
where the reverse and regional directions get their evidence. `missing
dictionaries` is empty across the board: every dictionary a configuration
references is either shipped in the snapshot or derived from it by
`tools/gen_dict`, the same way OpenCC derives it in its own build.

| configuration | golden corpus | missing dictionaries |
| --- | --- | --- |
| `hk2s` | not covered | - |
| `hk2sp` | not covered | - |
| `hk2t` | not covered | - |
| `jp2t` | not covered | - |
| `s2hk` | covered | - |
| `s2hkp` | covered | - |
| `s2seal` | not covered | - |
| `s2t` | covered | - |
| `s2tw` | covered | - |
| `s2twp` | covered | - |
| `seal2t` | not covered | - |
| `t2hk` | not covered | - |
| `t2jp` | not covered | - |
| `t2s` | not covered | - |
| `t2seal` | not covered | - |
| `t2tw` | not covered | - |
| `tw2s` | not covered | - |
| `tw2sp` | not covered | - |
| `tw2t` | not covered | - |

5 covered, 14 not covered.

## Data snapshot

| field | value |
| --- | --- |
| repository | https://github.com/BYVoid/OpenCC |
| revision | b087c2612ce808f464b0925fc1c497d24971d179 (master) |
| dictionaries | 26 (19 upstream files, 7 derived) |
| entries | 89817 |
| verification | SHA-256 of every source file, re-checked by `moon run tools/gen_dict --target native -- --verify` |

## Source size

Counted by walking the checkout's `.mbt` files (build output and installed
dependencies are skipped), so the figures quoted in the write-up are checked
here instead of being maintained by hand.

| group | files | lines |
| --- | --- | --- |
| hand-written implementation | 15 | 4196 |
| generated data | 48 | 93671 |
| tests | 6 | 682 |
