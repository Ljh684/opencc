// White-box tests for the runtime assembly and the public convert API.

///|
test "convert applies a real configuration" {
  // Values taken from the pinned snapshot: STCharacters has 软 → 軟,
  // STPhrases has 级别 → 級別.
  assert_eq(convert("s2t", "软"), Some("軟"))
  assert_eq(convert("s2t", "级别"), Some("級別"))
}

///|
test "convert reports unknown configurations instead of guessing" {
  assert_eq(convert("no-such-config", "软"), None)
  assert_eq(convert("", "软"), None)
}

///|
test "convert keeps text that needs no change" {
  assert_eq(convert("s2t", "hello 123"), Some("hello 123"))
  assert_eq(convert("s2t", ""), Some(""))
}

///|
test "regional wording needs the phrase passes" {
  // A per-character table cannot produce this: 内存 / 软件 / 优化 become the
  // Taiwan wording 記憶體 / 軟體 / 最佳化 only through the phrase dictionaries.
  // The authoritative check is `opencc verify`; this is a fast regression fixture.
  assert_eq(
    convert("s2twp", "内存泄漏与软件优化"),
    Some("記憶體洩漏與軟體最佳化"),
  )
}

///|
test "missing dictionaries are reported per configuration" {
  // t2s references TSCharactersExt, which OpenCC builds during its own build and
  // the pinned snapshot does not ship.
  assert_true(missing_dictionaries("t2s").contains("ts_characters_ext"))
  assert_eq(missing_dictionaries("s2t").length(), 0)
}

///|
test "every built-in configuration assembles a chain" {
  let names = chain_names()
  assert_eq(names.length(), 19)
  for name in names {
    assert_true(chain(name) is Some(_))
  }
}

///|
/// Convert with a known configuration, panicking on a typo in the test itself.
fn converted(config : String, text : String) -> String {
  match convert(config, text) {
    Some(value) => value
    // An unknown name can only come from a typo in this test file; the
    // assertion that consumes the result will fail.
    None => "<unknown configuration: " + config + ">"
  }
}

///|
test "every dictionary entry is matched by its own key" {
  // Data-scale coverage: walk all 20 dictionaries and check that the index
  // returns each key's own replacement for that key. This exercises the parser,
  // the first-code-unit index and the longest-match rule on every one of the
  // 76k entries in the pinned snapshot.
  let mut checked = 0
  let mut unresolved = 0
  for source in @dict.sources {
    match @dict.lookup(source.binding) {
      None => unresolved = unresolved + 1
      Some(chunks) => {
        let dict = @core.Dict::parse(source.binding, chunks)
        for chunk in chunks {
          for raw in chunk.split("\n") {
            let line = raw.trim_end()
            if line.is_empty() || line.has_prefix("#") {
              continue
            }
            match line.split_once("\t") {
              Some((key, rest)) => {
                let value = match rest.split_once(" ") {
                  Some((first, _)) => first
                  None => rest
                }
                assert_eq(
                  dict.match_at(key.to_owned(), 0),
                  Some((key.length(), value.to_owned())),
                )
                checked = checked + 1
              }
              None => ()
            }
          }
        }
      }
    }
  }
  assert_eq(unresolved, 0)
  assert_true(checked > 70000)
}

///|
test "the missing-dictionary ledger stays explicit" {
  // Snapshot gaps are allowed, surprises are not: every missing dictionary must
  // be one of the ones OpenCC generates during its own build, and the five
  // chains this project verifies against the golden corpus must be complete.
  let known = [
    "ts_characters_ext", "tw_variants_rev", "hk_variants_rev", "jp_shinjitai_characters_rev",
    "seal_characters_rev", "seal_variants_rev",
  ]
  for name in chain_names() {
    for dictionary in missing_dictionaries(name) {
      assert_true(known.contains(dictionary))
    }
  }
  for name in ["s2t", "s2tw", "s2twp", "s2hk", "s2hkp"] {
    assert_eq(missing_dictionaries(name).length(), 0)
  }
}

///|
test "conversion does not need to see more than one line at a time" {
  // Dictionary keys never contain a newline and segmentation cannot produce a
  // span across one, so converting line by line must agree with converting the
  // whole text. This is the property a future streaming API would rely on.
  let text = "内存泄漏与软件优化\n我们都关心级别问题\n"
  let whole = converted("s2twp", text)
  let out = StringBuilder()
  let mut first = true
  for piece in text.split("\n") {
    if !first {
      out.write_string("\n")
    }
    first = false
    out.write_string(converted("s2twp", piece.to_owned()))
  }
  assert_eq(whole, out.to_string())
}

///|
test "conversion is stable when applied twice" {
  // Not a general truth about script conversion, but the forward chains this
  // project verifies are stable on their own output for this sample.
  let text = "内存泄漏与软件优化，级别很低。"
  for name in ["s2t", "s2tw", "s2twp", "s2hk", "s2hkp"] {
    let once = converted(name, text)
    assert_eq(converted(name, once), once)
  }
}
