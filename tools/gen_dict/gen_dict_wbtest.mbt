// Tests for the pure parts of the generator: parsing and name derivation.

///|
test "parse skips comments and blank lines" {
  let text = "# header\n\n# another\n㐷\t傌\n\n"
  let parsed = parse_dictionary(text)
  assert_eq(parsed.skipped, 0)
  assert_eq(parsed.entries.length(), 1)
  assert_eq(parsed.entries[0].key, "㐷")
  assert_eq(parsed.entries[0].values[0], "傌")
}

///|
test "parse keeps every candidate of a multi-value entry" {
  let text = "㐹\t㑶 㐹\n一出\t一齣 一出\n"
  let parsed = parse_dictionary(text)
  assert_eq(parsed.entries.length(), 2)
  assert_eq(parsed.entries[0].values.length(), 2)
  assert_eq(parsed.entries[0].values[0], "㑶")
  assert_eq(parsed.entries[0].values[1], "㐹")
  assert_eq(parsed.entries[1].key, "一出")
}

///|
test "parse counts lines without a tab as skipped" {
  let parsed = parse_dictionary("broken line\nok\t值\n")
  assert_eq(parsed.skipped, 1)
  assert_eq(parsed.entries.length(), 1)
}

///|
test "module names are derived from file names" {
  assert_eq(module_name("STPhrases.txt"), "st_phrases")
  assert_eq(module_name("TSCharacters.txt"), "ts_characters")
  assert_eq(
    module_name("CJK_Compatibility_Ideographs.txt"),
    "cjk_compatibility_ideographs",
  )
}

///|
test "emitted literals escape quotes and backslashes" {
  let entries : Array[Entry] = [{ key: "a\"b", values: ["c\\d"], }]
  let source = emit_dictionary("sample", "Sample.txt", entries)
  assert_true(source.contains("(\"a\\\"b\", \"c\\\\d\"),"))
}
