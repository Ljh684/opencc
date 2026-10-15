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
  let source = emit_dict_data("sample", "Sample.txt", "# header\n甲\tA\n")
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
  let source = emit_dict_data("sample", "Sample.txt", out.to_string())
  assert_true(source.contains("sample_chunk_1 : String ="))
}

///|
test "reverse merges values into keys and keeps first-seen order" {
  let (entries, problems) = derive_reverse("# header\n甲\tA B\n乙\tA\n")
  assert_eq(problems.length(), 0)
  assert_eq(entries.length(), 2)
  assert_eq(entries[0].0, "A")
  assert_eq(entries[0].1, "甲 乙")
  assert_eq(entries[1].0, "B")
  assert_eq(entries[1].1, "甲")
}

///|
test "reverse applies @reverse-prefer before sorting" {
  let (entries, problems) = derive_reverse(
    "# @reverse-prefer: A 乙\n甲\tA\n乙\tA\n",
  )
  assert_eq(problems.length(), 0)
  assert_eq(entries[0].1, "乙 甲")
  // A one-field preference means "keep this key first", which is what upstream
  // writes for entries such as the identity mapping `梁\t梁`; the candidate list
  // of each reversed key is unaffected.
  let (kept, second) = derive_reverse("# @reverse-prefer: 梁\n梁\t梁 樑\n")
  assert_eq(second.length(), 0)
  assert_eq(kept.length(), 2)
  assert_eq(kept[0].0, "梁")
  assert_eq(kept[0].1, "梁")
  assert_eq(kept[1].0, "樑")
  assert_eq(kept[1].1, "梁")
}

///|
test "reverse sorts by code point, not by UTF-16 code unit" {
  // U+20000 is a surrogate pair (0xD840 0xDC00) in UTF-16, which orders below
  // U+FFFD there but above it by code point, and Python sorts by code point.
  let (entries, problems) = derive_reverse("甲\t\u{20000}\n乙\t\u{FFFD}\n")
  assert_eq(problems.length(), 0)
  assert_eq(entries[0].0, "\u{FFFD}")
  assert_eq(entries[1].0, "\u{20000}")
  assert_true(compare_code_points("\u{20000}", "\u{FFFD}") > 0)
  assert_true(compare_code_points("A", "AB") < 0)
}

///|
test "reverse reports what upstream treats as a build error" {
  let (_, broken) = derive_reverse("line without a tab\n")
  assert_eq(broken.length(), 1)
  let (_, orphan) = derive_reverse("# @reverse-prefer: 么 幺\n么\t么\n")
  assert_eq(orphan.length(), 1)
}

///|
test "tofu-risk extraction drops the tagged self-mapping" {
  let text = "# @tofu-risk: rare form\n㑮\t㑮 X\nplain\t值\n# @tofu-risk: another\n㒓\tY\n"
  let (entries, problems) = derive_tofu_risk(text)
  assert_eq(problems.length(), 0)
  assert_eq(entries.length(), 2)
  assert_eq(entries[0].0, "㑮")
  assert_eq(entries[0].1, "X")
  assert_eq(entries[1].0, "㒓")
  assert_eq(entries[1].1, "Y")
}

///|
test "tofu-risk reports a missing or self-only mapping" {
  let (_, dangling) = derive_tofu_risk("# @tofu-risk: dangling\n")
  assert_eq(dangling.length(), 1)
  let (_, self_only) = derive_tofu_risk("# @tofu-risk: self only\n甲\t甲\n")
  assert_eq(self_only.length(), 1)
}

///|
test "config packages reference only the dictionaries they use" {
  let spec : ChainSpec = {
    name: "sample",
    title: "Sample configuration",
    normalization: [Leaf("cjk")],
    segmentation: Some(Group(Union, [Leaf("phrases"), Leaf("absent")])),
    conversion: [Group(ShortCircuit, [Leaf("phrases"), Leaf("characters")])],
  }
  let available = ["cjk", "phrases", "characters"]
  let used = used_bindings(spec, available)
  assert_eq(used.length(), 3)
  let pkg = emit_config_subpkg("mod/name", used)
  assert_true(pkg.contains("\"mod/name/core\""))
  assert_true(pkg.contains("\"mod/name/dict/phrases\""))
  assert_true(!pkg.contains("absent"))
  let chain = emit_config_chain(spec, available, missing_of(spec, available))
  assert_true(chain.contains("@phrases.phrases"))
  // The absent dictionary is reported, never referenced.
  assert_true(chain.contains("pub let missing : Array[String] = [\"absent\""))
  assert_true(!chain.contains("@absent"))
}
