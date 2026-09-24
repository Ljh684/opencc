// opencc CLI.
//
// Today it does two things: report the built-in configurations, and verify the
// conversion against OpenCC's own golden corpus (`verify`). File and stream
// conversion arrives with the next milestone.

///|
/// Read a text file, exiting with a message when it cannot be read.
fn read_text(path : String) -> String {
  @fs.read_file_to_string(path) catch {
    _ => {
      println("opencc: cannot read " + path)
      @sys.exit(1)
      ""
    }
  }
}

///|
/// Sentence-case status label for a comparison result.
fn label(ok : Bool) -> String {
  if ok {
    "ok  "
  } else {
    "FAIL"
  }
}

///|
/// Index of the first differing code unit, or -1 when the strings are equal.
fn first_difference(left : String, right : String) -> Int {
  let limit = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  let mut index = 0
  while index < limit {
    if left.unsafe_get(index) != right.unsafe_get(index) {
      return index
    }
    index = index + 1
  }
  if left.length() == right.length() {
    -1
  } else {
    limit
  }
}

///|
/// A readable slice of a string around an offset, for difference reports.
fn window(text : String, offset : Int) -> String {
  let start = if offset > 30 { offset - 30 } else { 0 }
  let stop = if start + 60 < text.length() { start + 60 } else { text.length() }
  text[start:stop].to_owned().replace_all(old="\n", new="\\n")
}

///|
/// `us_constitution_zhs.s2t.txt` -> `Some("s2t")`.
///
/// Returns `None` for variants this project does not cover yet, such as the
/// `*_jieba` outputs (see docs/design.md, non-goals).
fn config_of_golden(file : String) -> String? {
  let stem = match file.strip_suffix(".txt") {
    Some(stem) => stem
    None => file.to_string_view()
  }
  let name = match stem.rev_split_once(".") {
    Some((_, name)) => name.to_owned()
    None => stem.to_owned()
  }
  if name.has_suffix("_jieba") {
    None
  } else {
    Some(name)
  }
}

///|
/// Verify every covered configuration against the golden corpus.
///
/// Returns the number of failures, so `main` can decide the exit code.
fn verify_golden(dir : String) -> Int {
  let input_path = dir + "/input/us_constitution_zhs.txt"
  let input = read_text(input_path)
  println(
    "golden input : " +
    input_path +
    " (" +
    input.length().to_string() +
    " code units)",
  )
  let mut passed = 0
  let mut failed = 0
  let mut skipped = 0
  for file in files_with_suffix(dir + "/output", ".txt") {
    match config_of_golden(file) {
      None => skipped = skipped + 1
      Some(name) =>
        match @config.chain(name) {
          None => {
            println(
              "  " + label(false) + " " + name + "  (unknown configuration)",
            )
            failed = failed + 1
          }
          Some(chain) => {
            let expected = read_text(dir + "/output/" + file)
            let actual = chain.apply(input)
            let missing = @config.missing_dictionaries(name)
            let mut note = ""
            if !missing.is_empty() {
              note = "  (missing: " + missing.join(", ") + ")"
            }
            if actual == expected {
              passed = passed + 1
              println("  " + label(true) + " " + name + note)
            } else {
              failed = failed + 1
              let offset = first_difference(actual, expected)
              println("  " + label(false) + " " + name + note)
              println(
                "         first difference at code unit " +
                offset.to_string() +
                " of " +
                expected.length().to_string(),
              )
              println("         expected: " + window(expected, offset))
              println("         actual  : " + window(actual, offset))
            }
          }
        }
    }
  }
  println(
    "golden result: " +
    passed.to_string() +
    " passed, " +
    failed.to_string() +
    " failed, " +
    skipped.to_string() +
    " skipped (unsupported variants)",
  )
  failed
}

///|
/// Names of the text files with the given suffix, sorted.
fn files_with_suffix(dir : String, suffix : String) -> Array[String] {
  let names : Array[String] = []
  let entries = @fs.read_dir(dir) catch {
    _ => {
      println("opencc: cannot list " + dir)
      @sys.exit(1)
      []
    }
  }
  for name in entries.iter() {
    if name.has_suffix(suffix) {
      names.push(name)
    }
  }
  names.sort()
  names
}

///|
/// Entry point.
fn main {
  let args = @env.args()
  let mut golden = "test/fixtures/golden"
  let mut verify = false
  let mut index = 0
  while index < args.length() {
    let arg = args[index]
    if arg == "verify" {
      verify = true
      index = index + 1
    } else if arg == "--golden" && index + 1 < args.length() {
      golden = args[index + 1]
      index = index + 2
    } else {
      index = index + 1
    }
  }

  if verify {
    let failures = verify_golden(golden)
    if failures > 0 {
      @sys.exit(1)
    }
  } else {
    println("opencc.mbt 0.1.0 - OpenCC-compatible conversion in MoonBit (WIP)")
    println("")
    println("Built-in configurations:")
    for config in @config.all() {
      println("  \{config.name}  \{config.description}")
    }
    println("")
    println("Usage:")
    println(
      "  opencc verify [--golden <dir>]   compare against OpenCC's golden corpus",
    )
    println(
      "  opencc                           list the built-in configurations",
    )
  }
}
