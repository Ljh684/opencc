// opencc CLI.
//
// Commands:
//     opencc list-configs
//     opencc convert -c <config> --input <file> [--output <file>]
//     opencc convert -c <config> --text "<string>"
//     opencc verify [--golden <dir>] [--report <path>]
//
// When no output file is given the converted text goes to stdout and nothing
// else is printed, so the command can be redirected. MoonBit's console API only
// offers `println` (always with a newline); `--output` is the byte-exact path.
//
// `verify --report <path>` writes the same results as a document: Markdown for
// any path, JSON when the path ends in `.json`. The document is deterministic
// (no timestamps, no run-to-run ordering), so continuous integration can
// regenerate it and fail on drift - that is what keeps the committed report and
// the code from disagreeing.

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
/// How many code units differ between two strings.
fn count_differences(left : String, right : String) -> Int {
  let limit = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  let mut index = 0
  let mut differences = 0
  while index < limit {
    if left.unsafe_get(index) != right.unsafe_get(index) {
      differences = differences + 1
    }
    index = index + 1
  }
  differences +
  (if left.length() > right.length() {
    left.length() - right.length()
  } else {
    right.length() - left.length()
  })
}

///|
/// Convert each golden output back with its reverse configuration.
///
/// Round-tripping is only claimed where the reverse chain is complete: when the
/// snapshot is missing a dictionary that OpenCC generates during its own build,
/// the pair is reported as a note instead of a failure. A difference with a
/// complete chain is a genuine regression.
///
/// Returns the number of failures.
/// One configuration's result against the golden corpus.
struct GoldenResult {
  name : String
  passed : Bool
  missing : Array[String]
}

///|
/// One reverse-direction round-trip result.
struct RoundTripResult {
  pair : String
  identical : Bool
  differences : Int
  missing : Array[String]
}

///|
/// Convert each golden output back with its reverse configuration and report.
fn verify_round_trips(dir : String, source : String) -> Array[RoundTripResult] {
  let pairs = [
    ("s2t", "t2s"),
    ("s2tw", "tw2s"),
    ("s2twp", "tw2sp"),
    ("s2hk", "hk2s"),
    ("s2hkp", "hk2sp"),
  ]
  let results : Array[RoundTripResult] = []
  for pair in pairs {
    let forward = pair.0
    let backward = pair.1
    let path = dir + "/output/us_constitution_zhs." + forward + ".txt"
    if !@fs.path_exists(path) {
      continue
    }
    match @config.chain(backward) {
      None => ()
      Some(chain) => {
        let back = chain.apply(read_text(path))
        let name = forward + " -> " + backward
        let identical = back == source
        let differences = count_differences(back, source)
        let missing = @config.missing_dictionaries(backward)
        if identical {
          println("  ok   " + name + "  identical to the source text")
        } else if missing.is_empty() {
          println(
            "  FAIL " +
            name +
            "  " +
            differences.to_string() +
            " differing code units, but the reverse chain is complete",
          )
        } else {
          println(
            "  note " +
            name +
            "  " +
            differences.to_string() +
            " differing code units; missing: " +
            missing.join(", "),
          )
        }
        results.push({ pair: name, identical, differences, missing, })
      }
    }
  }
  results
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
/// Convert every file with the given extension in a directory.
///
/// Returns the number of files that could not be converted, so the caller can
/// decide the exit code.
fn convert_dir(
  config_names : Array[String],
  input_dir : String,
  output_dir : String,
  extension : String,
) -> Int {
  if output_dir == "" {
    println("opencc: --input-dir needs --output-dir")
    @sys.exit(2)
  }
  let files = files_with_suffix(input_dir, extension)
  if files.is_empty() {
    println("opencc: no " + extension + " files found in " + input_dir)
    return 1
  }
  if !@fs.path_exists(output_dir) {
    @fs.create_dir(output_dir) catch {
      _ => ()
    }
  }
  let mut written = 0
  let mut units_in = 0
  let mut units_out = 0
  let mut failures = 0
  for file in files {
    let text = read_text(input_dir + "/" + file)
    match @config.convert_sequence(config_names, text) {
      None => failures = failures + 1
      Some(converted) => {
        write_text(output_dir + "/" + file, converted)
        written = written + 1
        units_in = units_in + text.length()
        units_out = units_out + converted.length()
      }
    }
  }
  println(
    "opencc: " +
    written.to_string() +
    " file(s) → " +
    output_dir +
    " (" +
    units_in.to_string() +
    " → " +
    units_out.to_string() +
    " code units) via " +
    config_names.join(" → "),
  )
  failures
}

///|
/// Convert one text or a whole directory.
///
/// Repeated `-c` flags compose in order, the way the upstream CLI does it;
/// `--input-dir` with `--output-dir` converts every `--ext` file in a directory.
fn convert_command(
  config_names : Array[String],
  input_path : String,
  text_arg : String?,
  output_path : String,
  input_dir : String,
  output_dir : String,
  extension : String,
) -> Unit {
  if config_names.is_empty() {
    println("opencc: convert needs a configuration, e.g. -c s2t")
    println("opencc: run 'opencc list-configs' to see the built-in names")
    @sys.exit(2)
  }
  if input_dir != "" {
    if convert_dir(config_names, input_dir, output_dir, extension) > 0 {
      @sys.exit(1)
    }
    return
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
  match @config.convert_sequence(config_names, text) {
    None => {
      println("opencc: unknown configuration in " + config_names.join(", "))
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
fn verify_golden(dir : String, report_path : String) -> Int {
  let input_path = dir + "/input/us_constitution_zhs.txt"
  let input = read_text(input_path)
  println(
    "golden input : " +
    input_path +
    " (" +
    input.length().to_string() +
    " code units)",
  )
  let golden : Array[GoldenResult] = []
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
            golden.push({ name, passed: false, missing: [], })
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
              golden.push({ name, passed: true, missing, })
            } else {
              failed = failed + 1
              golden.push({ name, passed: false, missing, })
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
  println("round-trip    :")
  let trips = verify_round_trips(dir, input)
  let mut trip_failures = 0
  for trip in trips {
    if !trip.identical && trip.missing.is_empty() {
      trip_failures = trip_failures + 1
    }
  }
  let failures = failed + trip_failures
  if report_path != "" {
    let size = count_source(repository_root(dir))
    let report = if report_path.has_suffix(".json") {
      render_report_json(input.length(), golden, trips, skipped, size)
    } else {
      render_report_markdown(input.length(), golden, trips, skipped, size)
    }
    write_text(report_path, report)
    println("report        : " + report_path + " written")
  }
  failures
}

///|
/// Whether the golden corpus covers a configuration.
fn covered_by_golden(golden : Array[GoldenResult], name : String) -> Bool {
  for entry in golden {
    if entry.name == name {
      return true
    }
  }
  false
}

///|
/// Escape a string for a JSON document.
///
/// Everything the report inserts is an ASCII identifier, path or revision, so
/// only `"`, `\` and control characters need handling - but handling them is
/// what makes the file parseable by any JSON reader.
fn json_escape(text : String) -> String {
  let quote : UInt16 = 34
  let backslash : UInt16 = 92
  let out = StringBuilder()
  let mut index = 0
  while index < text.length() {
    let unit = text.unsafe_get(index)
    if unit == quote {
      out.write_string("\\\"")
    } else if unit == backslash {
      out.write_string("\\\\")
    } else if unit < 32 {
      out.write_string("\\u")
      out.write_string(hex4(unit))
    } else {
      out.write_substring(text, index, 1)
    }
    index = index + 1
  }
  out.to_string()
}

///|
/// The four-digit `\uXXXX` form of a code unit.
fn hex4(unit : UInt16) -> String {
  let digits = "0123456789abcdef"
  let value = unit.to_int()
  let out = StringBuilder()
  for shift in [12, 8, 4, 0] {
    out.write_substring(digits, value / (1 << shift) % 16, 1)
  }
  out.to_string()
}

///|
/// `["a", "b"]`, or `[]` when the list is empty.
fn json_string_array(items : Array[String]) -> String {
  let out = StringBuilder()
  out.write_string("[")
  let mut index = 0
  for item in items {
    if index > 0 {
      out.write_string(", ")
    }
    out.write_string("\"")
    out.write_string(json_escape(item))
    out.write_string("\"")
    index = index + 1
  }
  out.write_string("]")
  out.to_string()
}

///|
/// Dictionary names for a report cell, or `-` when nothing is missing.
fn missing_note(items : Array[String]) -> String {
  if items.is_empty() {
    "-"
  } else {
    items.join(", ")
  }
}

///|
/// Total entries across the compiled dictionaries and how many of the
/// dictionaries are derived at build time.
fn snapshot_totals() -> (Int, Int) {
  let mut entries = 0
  let mut derived = 0
  for source in @dict.sources {
    entries = entries + source.entries
    if source.derived {
      derived = derived + 1
    }
  }
  (entries, derived)
}

///|
/// Size of the repository, in the three groups the proposal quotes.
///
/// Counting from the checkout (instead of quoting numbers by hand) is what
/// keeps the figures in the write-up from drifting away from the code.
struct SourceSize {
  implementation_files : Int
  implementation_lines : Int
  generated_files : Int
  generated_lines : Int
  test_files : Int
  test_lines : Int
}

///|
/// The checkout root implied by a golden directory, e.g. `test/fixtures/golden`
/// is three levels below the root. Falls back to the working directory.
fn repository_root(golden_dir : String) -> String {
  let parts = golden_dir.replace_all(old="\\", new="/").split("/")
  let kept : Array[StringView] = []
  for part in parts {
    if part.length() > 0 {
      kept.push(part)
    }
  }
  if kept.length() <= 3 {
    return "."
  }
  let out = StringBuilder()
  let mut index = 0
  while index < kept.length() - 3 {
    if index > 0 {
      out.write_string("/")
    }
    out.write_string(kept[index].to_owned())
    index = index + 1
  }
  out.to_string()
}

///|
/// Every `.mbt` file under the checkout, as a path relative to it.
///
/// Names starting with `.` or `_` are skipped: those are exactly the ignored
/// directories (`_build`, `.mooncakes`), so the count describes the repository
/// and not its build output.
fn mbt_files_under(root : String) -> Array[String] {
  let files : Array[String] = []
  collect_mbt(root, "", files)
  files.sort()
  files
}

///|
/// Recursive half of `mbt_files_under`.
fn collect_mbt(
  dir : String,
  prefix : String,
  accumulator : Array[String],
) -> Unit {
  let entries = @fs.read_dir(dir) catch { _ => [] }
  for name in entries {
    if name.length() == 0 {
      continue
    }
    let first = name.unsafe_get(0)
    if first == 46 || first == 95 {
      continue
    }
    let path = if dir == "." { name } else { dir + "/" + name }
    let relative = if prefix == "" { name } else { prefix + "/" + name }
    let is_directory = @fs.is_dir(path) catch { _ => false }
    if is_directory {
      collect_mbt(path, relative, accumulator)
    } else if name.has_suffix(".mbt") {
      accumulator.push(relative)
    }
  }
}

///|
/// Newline-terminated line count of a file, or 0 when it cannot be read.
fn count_lines(path : String) -> Int {
  let text = @fs.read_file_to_string(path) catch { _ => "" }
  let mut lines = 0
  let mut index = 0
  while index < text.length() {
    if text.unsafe_get(index) == 10 {
      lines = lines + 1
    }
    index = index + 1
  }
  lines
}

///|
/// A test file, in any of MoonBit's three test flavours.
fn is_test_path(relative : String) -> Bool {
  relative.has_suffix("_test.mbt") || relative.has_suffix("_wbtest.mbt")
}

///|
/// A generated file: the compiled dictionaries and the assembly of the 19
/// configurations, all produced by `tools/gen_dict`.
fn is_generated_path(relative : String) -> Bool {
  relative.has_prefix("dict/") ||
  relative == "config/chains.mbt" ||
  (relative.has_prefix("config/") && relative.has_suffix("/chain.mbt"))
}

///|
/// Measure the checkout: hand-written implementation, generated data and tests.
fn count_source(root : String) -> SourceSize {
  let mut implementation_files = 0
  let mut implementation_lines = 0
  let mut generated_files = 0
  let mut generated_lines = 0
  let mut test_files = 0
  let mut test_lines = 0
  for relative in mbt_files_under(root) {
    let path = if root == "." { relative } else { root + "/" + relative }
    let lines = count_lines(path)
    if is_test_path(relative) {
      test_files = test_files + 1
      test_lines = test_lines + lines
    } else if is_generated_path(relative) {
      generated_files = generated_files + 1
      generated_lines = generated_lines + lines
    } else {
      implementation_files = implementation_files + 1
      implementation_lines = implementation_lines + lines
    }
  }
  {
    implementation_files,
    implementation_lines,
    generated_files,
    generated_lines,
    test_files,
    test_lines,
  }
}

///|
/// The verification report as Markdown.
///
/// Deliberately timeless: no date, no host, no durations - only facts the CLI
/// recomputes identically on every run, so `git diff --exit-code` in CI can
/// prove the committed copy still matches the code.
fn render_report_markdown(
  input_units : Int,
  golden : Array[GoldenResult],
  trips : Array[RoundTripResult],
  skipped : Int,
  size : SourceSize,
) -> String {
  let (entries, derived) = snapshot_totals()
  let names = @config.chain_names()
  let mut passed = 0
  let mut uncovered = 0
  for entry in golden {
    if entry.passed {
      passed = passed + 1
    }
  }
  for name in names {
    if !covered_by_golden(golden, name) {
      uncovered = uncovered + 1
    }
  }
  let out = StringBuilder()
  out.write_string("# Verification report\n\n")
  out.write_string(
    "Generated - do not edit by hand. The CLI recomputes every number below\n" +
    "from the data compiled into this repository, and continuous integration\n" +
    "regenerates this file and fails on any difference, so it cannot go stale:\n\n",
  )
  out.write_string(
    "    moon run cmd/opencc --target native -- verify --report docs/verification-report.md\n\n",
  )
  out.write_string("## Golden corpus\n\n")
  out.write_string(
    "OpenCC ships expected output for a handful of configurations. The CLI\n" +
    "converts the source text with each one and compares byte for byte.\n" +
    "Source file: `test/fixtures/golden/input/us_constitution_zhs.txt` (" +
    input_units.to_string() +
    " code units).\n\n",
  )
  out.write_string("| configuration | result | missing dictionaries |\n")
  out.write_string("| --- | --- | --- |\n")
  for entry in golden {
    let result = if entry.passed { "pass" } else { "**fail**" }
    out.write_string(
      "| `" +
      entry.name +
      "` | " +
      result +
      " | " +
      missing_note(entry.missing) +
      " |\n",
    )
  }
  out.write_string(
    "\n" +
    passed.to_string() +
    " passed, " +
    (golden.length() - passed).to_string() +
    " failed; " +
    skipped.to_string() +
    " `*_jieba` variant(s) skipped (word segmentation is a non-goal, see docs/design.md).\n\n",
  )
  out.write_string("## Round trip\n\n")
  out.write_string(
    "Every golden output is converted back with its reverse configuration and\n" +
    "compared with the source text, byte for byte. `note` means the reverse chain\n" +
    "is incomplete in this snapshot, so the pair is reported rather than claimed.\n\n",
  )
  out.write_string(
    "| direction | result | differing code units | missing dictionaries |\n",
  )
  out.write_string("| --- | --- | --- | --- |\n")
  for trip in trips {
    let result = if trip.identical {
      "identical"
    } else if trip.missing.is_empty() {
      "**FAIL**"
    } else {
      "note"
    }
    out.write_string(
      "| `" +
      trip.pair +
      "` | " +
      result +
      " | " +
      trip.differences.to_string() +
      " | " +
      missing_note(trip.missing) +
      " |\n",
    )
  }
  out.write_string("\n## Configurations\n\n")
  out.write_string(
    "All " +
    names.length().to_string() +
    " built-in configurations. `not covered` means upstream ships no golden\n" +
    "output for it, so this project does not claim byte-exactness for it;\n" +
    "`missing dictionaries` lists dictionaries the pinned snapshot does not ship\n" +
    "(upstream OpenCC generates them during its own build), which the runtime\n" +
    "skips instead of failing the whole chain.\n\n",
  )
  out.write_string("| configuration | golden corpus | missing dictionaries |\n")
  out.write_string("| --- | --- | --- |\n")
  for name in names {
    let coverage = if covered_by_golden(golden, name) {
      "covered"
    } else {
      "not covered"
    }
    out.write_string(
      "| `" +
      name +
      "` | " +
      coverage +
      " | " +
      missing_note(@config.missing_dictionaries(name)) +
      " |\n",
    )
  }
  out.write_string(
    "\n" +
    covered_by_golden_count(golden, names).to_string() +
    " covered, " +
    uncovered.to_string() +
    " not covered.\n\n",
  )
  out.write_string("## Data snapshot\n\n")
  out.write_string("| field | value |\n")
  out.write_string("| --- | --- |\n")
  out.write_string("| repository | " + @dict.upstream_repository + " |\n")
  out.write_string("| revision | " + @dict.upstream_revision + " |\n")
  out.write_string(
    "| dictionaries | " +
    @dict.sources.length().to_string() +
    " (" +
    (@dict.sources.length() - derived).to_string() +
    " upstream files, " +
    derived.to_string() +
    " derived) |\n",
  )
  out.write_string("| entries | " + entries.to_string() + " |\n")
  out.write_string(
    "| verification | SHA-256 of every source file, re-checked by `moon run tools/gen_dict --target native -- --verify` |\n",
  )
  out.write_string("\n## Source size\n\n")
  out.write_string(
    "Counted by walking the checkout's `.mbt` files (build output and installed\n" +
    "dependencies are skipped), so the figures quoted in the write-up are checked\n" +
    "here instead of being maintained by hand.\n\n",
  )
  out.write_string("| group | files | lines |\n")
  out.write_string("| --- | --- | --- |\n")
  out.write_string(
    "| hand-written implementation | " +
    size.implementation_files.to_string() +
    " | " +
    size.implementation_lines.to_string() +
    " |\n",
  )
  out.write_string(
    "| generated data | " +
    size.generated_files.to_string() +
    " | " +
    size.generated_lines.to_string() +
    " |\n",
  )
  out.write_string(
    "| tests | " +
    size.test_files.to_string() +
    " | " +
    size.test_lines.to_string() +
    " |\n",
  )
  out.to_string()
}

///|
/// How many configurations the golden corpus covers.
fn covered_by_golden_count(
  golden : Array[GoldenResult],
  names : Array[String],
) -> Int {
  let mut count = 0
  for name in names {
    if covered_by_golden(golden, name) {
      count = count + 1
    }
  }
  count
}

///|
/// The same report as JSON, for dashboards and scripts.
fn render_report_json(
  input_units : Int,
  golden : Array[GoldenResult],
  trips : Array[RoundTripResult],
  skipped : Int,
  size : SourceSize,
) -> String {
  let (entries, derived) = snapshot_totals()
  let names = @config.chain_names()
  let out = StringBuilder()
  out.write_string("{\n")
  out.write_string("  \"input_units\": " + input_units.to_string() + ",\n")
  out.write_string("  \"golden\": [\n")
  let mut index = 0
  for entry in golden {
    let result = if entry.passed { "pass" } else { "fail" }
    out.write_string(
      "    {\"configuration\": \"" +
      json_escape(entry.name) +
      "\", \"result\": \"" +
      result +
      "\", \"missing\": " +
      json_string_array(entry.missing) +
      "}",
    )
    index = index + 1
    if index < golden.length() {
      out.write_string(",")
    }
    out.write_string("\n")
  }
  out.write_string("  ],\n")
  out.write_string("  \"golden_skipped\": " + skipped.to_string() + ",\n")
  out.write_string("  \"chains\": [\n")
  index = 0
  for name in names {
    out.write_string(
      "    {\"configuration\": \"" +
      json_escape(name) +
      "\", \"golden\": " +
      (if covered_by_golden(golden, name) { "true" } else { "false" }) +
      ", \"missing_required\": " +
      json_string_array(@config.missing_dictionaries(name)) +
      "}",
    )
    index = index + 1
    if index < names.length() {
      out.write_string(",")
    }
    out.write_string("\n")
  }
  out.write_string("  ],\n")
  out.write_string("  \"round_trips\": [\n")
  index = 0
  for trip in trips {
    let result = if trip.identical {
      "identical"
    } else if trip.missing.is_empty() {
      "fail"
    } else {
      "note"
    }
    out.write_string(
      "    {\"pair\": \"" +
      json_escape(trip.pair) +
      "\", \"result\": \"" +
      result +
      "\", \"differences\": " +
      trip.differences.to_string() +
      ", \"missing\": " +
      json_string_array(trip.missing) +
      "}",
    )
    index = index + 1
    if index < trips.length() {
      out.write_string(",")
    }
    out.write_string("\n")
  }
  out.write_string("  ],\n")
  out.write_string("  \"data\": {\n")
  out.write_string(
    "    \"repository\": \"" + json_escape(@dict.upstream_repository) + "\",\n",
  )
  out.write_string(
    "    \"revision\": \"" + json_escape(@dict.upstream_revision) + "\",\n",
  )
  out.write_string(
    "    \"dictionaries\": " + @dict.sources.length().to_string() + ",\n",
  )
  out.write_string("    \"entries\": " + entries.to_string() + ",\n")
  out.write_string("    \"derived\": " + derived.to_string() + "\n")
  out.write_string("  },\n")
  out.write_string("  \"source\": {\n")
  out.write_string(
    "    \"implementation_files\": " +
    size.implementation_files.to_string() +
    ",\n",
  )
  out.write_string(
    "    \"implementation_lines\": " +
    size.implementation_lines.to_string() +
    ",\n",
  )
  out.write_string(
    "    \"generated_files\": " + size.generated_files.to_string() + ",\n",
  )
  out.write_string(
    "    \"generated_lines\": " + size.generated_lines.to_string() + ",\n",
  )
  out.write_string("    \"test_files\": " + size.test_files.to_string() + ",\n")
  out.write_string("    \"test_lines\": " + size.test_lines.to_string() + "\n")
  out.write_string("  }\n")
  out.write_string("}\n")
  out.to_string()
}

///|
/// Entry point.
fn main {
  let args = @env.args()
  let mut command = ""
  let config_names : Array[String] = []
  let mut input_path = ""
  let mut output_path = ""
  let mut input_dir = ""
  let mut output_dir = ""
  let mut extension = ".txt"
  let mut text_arg : String? = None
  let mut golden = "test/fixtures/golden"
  let mut report_path = ""
  let mut index = 0
  while index < args.length() {
    let arg = args[index]
    if arg == "convert" || arg == "list-configs" || arg == "verify" {
      command = arg
      index = index + 1
    } else if (arg == "-c" || arg == "--config") && index + 1 < args.length() {
      config_names.push(args[index + 1])
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
    } else if arg == "--input-dir" && index + 1 < args.length() {
      input_dir = args[index + 1]
      index = index + 2
    } else if arg == "--output-dir" && index + 1 < args.length() {
      output_dir = args[index + 1]
      index = index + 2
    } else if arg == "--ext" && index + 1 < args.length() {
      extension = args[index + 1]
      index = index + 2
    } else if arg == "--golden" && index + 1 < args.length() {
      golden = args[index + 1]
      index = index + 2
    } else if arg == "--report" && index + 1 < args.length() {
      report_path = args[index + 1]
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
    if verify_golden(golden, report_path) > 0 {
      @sys.exit(1)
    }
  } else if command == "list-configs" {
    list_configs()
  } else if command == "convert" {
    convert_command(
      config_names, input_path, text_arg, output_path, input_dir, output_dir, extension,
    )
  } else if !config_names.is_empty() ||
    input_path != "" ||
    input_dir != "" ||
    text_arg is Some(_) {
    // `opencc -c s2t --text "..."` works without spelling out `convert`.
    convert_command(
      config_names, input_path, text_arg, output_path, input_dir, output_dir, extension,
    )
  } else {
    println("opencc.mbt 0.1.0 — OpenCC-compatible Chinese script conversion")
    println("")
    list_configs()
    println("")
    println("Usage:")
    println("  opencc list-configs")
    println("  opencc convert -c <config> --input <file> [-o <file>]")
    println("  opencc convert -c <config> --text \"<string>\"")
    println(
      "  opencc convert -c <config> [ -c <config> … ] --input-dir <dir> --output-dir <dir> [--ext .txt]",
    )
    println("  opencc verify [--golden <dir>] [--report <path>]")
  }
}
