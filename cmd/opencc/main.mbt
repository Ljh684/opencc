// opencc CLI.
//
// Commands:
//     opencc list-configs
//     opencc convert -c <config> --input <file> [--output <file>]
//     opencc convert -c <config> --text "<string>"
//     opencc verify [--golden <dir>]
//
// When no output file is given the converted text goes to stdout and nothing
// else is printed, so the command can be redirected. MoonBit's console API only
// offers `println` (always with a newline); `--output` is the byte-exact path.

///|
/// Print text to standard output, cancelling the newline `println` adds when the
/// text already ends with one. A text file that ends with a newline therefore
/// round-trips byte for byte; text that does not end with a newline gains one.
fn print_text(text : String) -> Unit {
  if text.has_suffix("\n") {
    println(text[:text.length() - 1].to_owned())
  } else {
    println(text)
  }
}

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
/// Write a text file, exiting with a message when it cannot be written.
fn write_text(path : String, content : String) -> Unit {
  @fs.write_string_to_file(path, content) catch {
    _ => {
      println("opencc: cannot write " + path)
      @sys.exit(1)
    }
  }
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
/// List the built-in configurations, flagging any dictionary they reference but
/// the pinned snapshot does not ship.
fn list_configs() -> Unit {
  println("Built-in configurations:")
  for config in @config.all() {
    let missing = @config.missing_dictionaries(config.name)
    let note = if missing.is_empty() {
      ""
    } else {
      "  [missing: " + missing.join(", ") + "]"
    }
    println("  \{config.name}  \{config.description}\{note}")
  }
}

///|
/// Convert one text: `--text` wins over `--input`, and an unknown configuration
/// or a missing input is a usage error.
fn convert_command(
  config_name : String,
  input_path : String,
  text_arg : String?,
  output_path : String,
) -> Unit {
  if config_name == "" {
    println("opencc: convert needs a configuration, e.g. -c s2t")
    println("opencc: run 'opencc list-configs' to see the built-in names")
    @sys.exit(2)
  }
  let text = match text_arg {
    Some(value) => value
    None =>
      if input_path != "" {
        read_text(input_path)
      } else {
        println("opencc: convert needs --input <file> or --text <string>")
        println(
          "opencc: reading stdin is not supported yet — MoonBit's standard library has no standard-input API",
        )
        @sys.exit(2)
        ""
      }
  }
  match @config.convert(config_name, text) {
    None => {
      println("opencc: unknown configuration '" + config_name + "'")
      println("opencc: run 'opencc list-configs' to see the built-in names")
      @sys.exit(2)
    }
    Some(converted) =>
      if output_path == "" {
        // Nothing else may go to stdout, so the command stays pipeable.
        print_text(converted)
      } else {
        write_text(output_path, converted)
        println(
          "opencc: wrote " +
          output_path +
          " (" +
          text.length().to_string() +
          " → " +
          converted.length().to_string() +
          " code units)",
        )
      }
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
            println("  FAIL " + name + "  (unknown configuration)")
            failed = failed + 1
          }
          Some(chain) => {
            let expected = read_text(dir + "/output/" + file)
            let actual = chain.apply(input)
            let missing = @config.missing_dictionaries(name)
            let note = if missing.is_empty() {
              ""
            } else {
              "  (missing: " + missing.join(", ") + ")"
            }
            if actual == expected {
              passed = passed + 1
              println("  ok   " + name + note)
            } else {
              failed = failed + 1
              let offset = first_difference(actual, expected)
              println("  FAIL " + name + note)
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
/// Entry point.
fn main {
  let args = @env.args()
  let mut command = ""
  let mut config_name = ""
  let mut input_path = ""
  let mut output_path = ""
  let mut text_arg : String? = None
  let mut golden = "test/fixtures/golden"
  let mut index = 0
  while index < args.length() {
    let arg = args[index]
    if arg == "convert" || arg == "list-configs" || arg == "verify" {
      command = arg
      index = index + 1
    } else if (arg == "-c" || arg == "--config") && index + 1 < args.length() {
      config_name = args[index + 1]
      index = index + 2
    } else if (arg == "-i" || arg == "--input") && index + 1 < args.length() {
      input_path = args[index + 1]
      index = index + 2
    } else if (arg == "-o" || arg == "--output") && index + 1 < args.length() {
      output_path = args[index + 1]
      index = index + 2
    } else if (arg == "-t" || arg == "--text") && index + 1 < args.length() {
      text_arg = Some(args[index + 1])
      index = index + 2
    } else if arg == "--golden" && index + 1 < args.length() {
      golden = args[index + 1]
      index = index + 2
    } else if !arg.has_prefix("-") && input_path == "" {
      // A bare path is the input file, like the original CLI.
      input_path = arg
      index = index + 1
    } else {
      println("opencc: unknown argument " + arg)
      println("opencc: run 'opencc' without arguments for usage")
      @sys.exit(2)
    }
  }

  if command == "verify" {
    if verify_golden(golden) > 0 {
      @sys.exit(1)
    }
  } else if command == "list-configs" {
    list_configs()
  } else if command == "convert" {
    convert_command(config_name, input_path, text_arg, output_path)
  } else if config_name != "" || input_path != "" || text_arg is Some(_) {
    // `opencc -c s2t --text "..."` works without spelling out `convert`.
    convert_command(config_name, input_path, text_arg, output_path)
  } else {
    println("opencc.mbt 0.1.0 — OpenCC-compatible Chinese script conversion")
    println("")
    list_configs()
    println("")
    println("Usage:")
    println("  opencc list-configs")
    println("  opencc convert -c <config> --input <file> [-o <file>]")
    println("  opencc convert -c <config> --text \"<string>\"")
    println("  opencc verify [--golden <dir>]")
  }
}
