// Tests for the pure parts of the generator: parsing, naming and emission.

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
test "lines_of drops the empty piece after a trailing newline" {
  let lines = lines_of("a\nb\n")
  assert_eq(lines.length(), 2)
  assert_eq(lines[0], "a")
  assert_eq(lines[1], "b")
  assert_eq(lines_of("").length(), 0)
}

///|
test "emitted modules embed the dictionary text verbatim" {
  let source = emit_dictionary("sample", "Sample.txt", "# header\n甲\tA\n")
  assert_true(source.contains("let sample_chunk_0 : String ="))
  assert_true(source.contains("  #|# header\n"))
  assert_true(source.contains("  #|甲\tA\n"))
  assert_true(source.contains("pub let sample : Array[String] = ["))
}

///|
test "long dictionaries are split into chunks" {
  // chunk_lines is 4000, so 4001 lines must produce a second chunk.
  let out = StringBuilder()
  let mut index = 0
  while index < 4001 {
    out.write_string("甲\tA\n")
    index = index + 1
  }
  let source = emit_dictionary("sample", "Sample.txt", out.to_string())
  assert_true(source.contains("sample_chunk_1 : String ="))
}
