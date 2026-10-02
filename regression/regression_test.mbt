// Black-box regression tests: one baseline file per configuration.

///|
/// Directory holding the corpus and the baselines.
const BASELINE_DIR : String = "test/fixtures/regression"

///|
test "every configuration matches its regression baseline" {
  let source = @fs.read_file_to_string(BASELINE_DIR + "/input.txt")
  let missing : Array[String] = []
  let mismatched : Array[String] = []
  for name in @config.chain_names() {
    let path = BASELINE_DIR + "/" + name + ".txt"
    match @config.chain(name) {
      None => mismatched.push(name + " (no chain)")
      Some(chain) => {
        let actual = chain.apply(source)
        // The baselines are stored with a trailing newline so they diff cleanly.
        let expected_actual = if actual.has_suffix("\n") {
          actual
        } else {
          actual + "\n"
        }
        if !@fs.path_exists(path) {
          missing.push(name)
        } else if @fs.read_file_to_string(path) != expected_actual {
          mismatched.push(name)
        }
      }
    }
  }
  assert_eq(missing, [])
  assert_eq(mismatched, [])
}

///|
test "the baseline directory has no unexpected files" {
  let names = @config.chain_names()
  let extra : Array[String] = []
  for file in @fs.read_dir(BASELINE_DIR) {
    if file.has_suffix(".txt") && file != "input.txt" {
      let stem = match file.strip_suffix(".txt") {
        Some(stem) => stem.to_owned()
        None => file
      }
      if !names.contains(stem) {
        extra.push(file)
      }
    }
  }
  assert_eq(extra, [])
}

///|
test "the corpus exercises both scripts and non-Chinese text" {
  let source = @fs.read_file_to_string(BASELINE_DIR + "/input.txt")
  // A guard so the corpus cannot silently degrade into something trivial: it has
  // to contain simplified-only, traditional-only, kana and ASCII material.
  assert_true(source.contains("内存"))
  assert_true(source.contains("漢字"))
  assert_true(source.contains("ひらがな"))
  assert_true(source.contains("ASCII"))
}
