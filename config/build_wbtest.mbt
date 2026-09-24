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
