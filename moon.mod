// MoonBit module manifest (new `moon.mod` format).
//
// NOTE: `name` must start with your mooncakes.io username before you run
// `moon publish`. Rename it here (and update the imports in
// cmd/opencc/moon.pkg) if your mooncakes username is not `Ljh684`.

name = "Ljh684/opencc"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/Ljh684/opencc"

license = "Apache-2.0"

// wasm-gc is the backend MoonBit recommends, and the one that compiles the whole
// data set comfortably; see the known limitations in README.md.

preferred_target = "wasm-gc"

keywords = [
  "opencc",
  "chinese",
  "traditional-chinese",
  "simplified-chinese",
  "text-processing",
]

description = "OpenCC-compatible Chinese script conversion (simplified, traditional, Taiwan, Hong Kong, Japanese shinjitai) in pure MoonBit, with no FFI."

import {
  "moonbitlang/x@0.5.5",
}
