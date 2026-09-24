// CLI entry point: turns the pinned OpenCC snapshot into compiled MoonBit data.
//
// Usage:
//     moon run tools/gen_dict -- --input data/opencc --out dict --config-out config
//     moon run tools/gen_dict -- --verify
//
// `--verify` regenerates everything in memory and compares it with what is on
// disk, so CI fails when the committed data no longer matches the generator.

///|
/// Read a text file, exiting with a message when it cannot be read.
fn read_text(path : String) -> String {
  @fs.read_file_to_string(path) catch {
    _ => {
      println("gen_dict: cannot read " + path)
      @sys.exit(1)
      ""
    }
  }
}

///|
/// Read a file as raw bytes, exiting with a message when it cannot be read.
fn read_bytes(path : String) -> Bytes {
  @fs.read_file_to_bytes(path) catch {
    _ => {
      println("gen_dict: cannot read " + path)
      @sys.exit(1)
      b""
    }
  }
}

///|
/// Write a text file, exiting with a message when it cannot be written.
fn write_text(path : String, content : String) -> Unit {
  @fs.write_string_to_file(path, content) catch {
    _ => {
      println("gen_dict: cannot write " + path)
      @sys.exit(1)
    }
  }
}

///|
/// Create a directory when it is missing.
fn ensure_dir(path : String) -> Unit {
  if !@fs.path_exists(path) {
    @fs.create_dir(path) catch {
      _ => ()
    }
  }
}

///|
/// Lowercase SHA-256 hex digest of a byte buffer.
fn sha256_hex(data : Bytes) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(data)).to_lower()
}

///|
/// Lowercase SHA-256 hex digest of a string, encoded as UTF-8.
fn sha256_of_text(text : String) -> String {
  sha256_hex(@encoding.encode(@encoding.UTF8, text))
}

///|
/// Parse `SHA256SUMS` (lines of `<hash>  <path>`) into a lookup table.
fn read_checksums(path : String) -> Map[String, String] {
  let checksums : Map[String, String] = Map([])
  if !@fs.path_exists(path) {
    return checksums
  }
  for raw in read_text(path).split("\n") {
    let line = raw.trim()
    if line.is_empty() {
      continue
    }
    match line.split_once("  ") {
      Some((hash, file)) => checksums.set(file.to_owned(), hash.to_owned())
      None => ()
    }
  }
  checksums
}

///|
/// Read the pinned upstream revision out of `REVISION`.
fn read_revision(path : String) -> String {
  for raw in read_text(path).split("\n") {
    let line = raw.trim()
    match line.strip_prefix("Revision:") {
      Some(rest) => {
        let value = rest.trim().to_owned()
        return value
      }
      None => ()
    }
  }
  "(unknown revision)"
}

///|
/// Compare names lexicographically.
///
/// MoonBit's built-in `String` order compares length first, which reads oddly in
/// a generated index, so this sorts by code unit instead.
fn compare_names(left : String, right : String) -> Int {
  let limit = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  let mut index = 0
  while index < limit {
    let order = left.unsafe_get(index).compare(right.unsafe_get(index))
    if order != 0 {
      return order
    }
    index = index + 1
  }
  left.length().compare(right.length())
}

///|
/// Names of the files with the given suffix, sorted for reproducible output.
fn files_with_suffix(dir : String, suffix : String) -> Array[String] {
  let names : Array[String] = []
  try {
    for name in @fs.read_dir(dir).iter() {
      if name.has_suffix(suffix) {
        names.push(name)
      }
    }
  } catch {
    _ => {
      println("gen_dict: cannot list " + dir)
      @sys.exit(1)
    }
  }
  names.sort_by(compare_names)
  names
}

///|
/// Write a generated file, or compare it with the committed one in verify mode.
///
/// Returns 1 when verify mode found drift, 0 otherwise.
fn sync_file(path : String, content : String, verify : Bool) -> Int {
  if verify {
    if !@fs.path_exists(path) {
      println("gen_dict: missing " + path)
      return 1
    }
    if read_text(path) == content {
      0
    } else {
      println("gen_dict: stale " + path + " (re-run without --verify)")
      1
    }
  } else {
    write_text(path, content)
    0
  }
}

///|
/// In verify mode, check that a package configuration still ignores every
/// generated file it should.
///
/// The configuration file is not compared byte for byte: `moon fmt` owns the
/// formatting of package configuration, so the generator only guarantees its
/// content, and regeneration rewrites it whenever a file is added.
fn verify_pkg_ignores(path : String, required : Array[String]) -> Int {
  if !@fs.path_exists(path) {
    println("gen_dict: missing " + path)
    return 1
  }
  let text = read_text(path)
  let mut problems = 0
  for name in required {
    if !text.contains("\"" + name + "\"") {
      println("gen_dict: " + path + " does not ignore " + name)
      problems = problems + 1
    }
  }
  problems
}

///|
/// Build the manifest module that records where every dictionary came from.
fn emit_manifest(
  repository : String,
  revision : String,
  rows : Array[String],
  bindings : Array[String],
) -> String {
  let out = StringBuilder()
  out.write_string("// Generated by tools/gen_dict — do not edit by hand.\n")
  out.write_string("//\n")
  out.write_string(
    "// One row per dictionary: the generated binding, the file it came from, how\n",
  )
  out.write_string(
    "// many entries it holds, and the SHA-256 of that file. `derived` marks the\n",
  )
  out.write_string("// dictionaries OpenCC generates during its own build.\n\n")
  out.write_string("///|\n")
  out.write_string("pub struct DictSource {\n")
  out.write_string("  binding : String\n")
  out.write_string("  file : String\n")
  out.write_string("  entries : Int\n")
  out.write_string("  sha256 : String\n")
  out.write_string("  derived : Bool\n")
  out.write_string("}\n\n")
  out.write_string("///| Upstream repository of the data snapshot.\n")
  out.write_string("pub let upstream_repository : String = \"")
  out.write_string(repository)
  out.write_string("\"\n\n")
  out.write_string("///| Upstream revision of the data snapshot.\n")
  out.write_string("pub let upstream_revision : String = \"")
  out.write_string(revision)
  out.write_string("\"\n\n")
  out.write_string("///| Every dictionary compiled into this module.\n")
  out.write_string("pub let sources : Array[DictSource] = [\n")
  for row in rows {
    out.write_string(row)
  }
  out.write_string("]\n")
  out.write_string(emit_lookup(bindings))
  out.to_string()
}

///|
/// Entry point.
fn main {
  let args = @env.args()
  let mut input = "data/opencc"
  let mut out_dir = "dict"
  let mut config_out = "config"
  let mut derived_dir = "data/derived"
  let mut verify = false
  // Args may or may not carry the executable as argv[0] depending on the
  // backend, so start at the first flag.
  let mut index = 0
  while index < args.length() && !args[index].has_prefix("--") {
    index = index + 1
  }
  while index < args.length() {
    let arg = args[index]
    if arg == "--input" && index + 1 < args.length() {
      input = args[index + 1]
      index = index + 2
    } else if arg == "--out" && index + 1 < args.length() {
      out_dir = args[index + 1]
      index = index + 2
    } else if arg == "--config-out" && index + 1 < args.length() {
      config_out = args[index + 1]
      index = index + 2
    } else if arg == "--derived-out" && index + 1 < args.length() {
      derived_dir = args[index + 1]
      index = index + 2
    } else if arg == "--verify" {
      verify = true
      index = index + 1
    } else {
      println("gen_dict: ignoring argument " + arg)
      index = index + 1
    }
  }

  let checksums = read_checksums(input + "/SHA256SUMS")
  let revision = read_revision(input + "/REVISION")
  let dict_dir = input + "/dictionary"
  let files = files_with_suffix(dict_dir, ".txt")
  if files.is_empty() {
    println("gen_dict: no dictionary files found in " + dict_dir)
    @sys.exit(1)
  }

  let bindings : Array[String] = []
  let rows : Array[String] = []
  let data : Map[String, Array[(String, String)]] = Map([])
  let mut problems = 0
  let mut total_entries = 0

  for file in files {
    let path = dict_dir + "/" + file
    let digest = sha256_hex(read_bytes(path))
    let rel = "dictionary/" + file
    match checksums.get(rel) {
      Some(expected) =>
        if expected != digest {
          println("gen_dict: checksum mismatch for " + rel)
          problems = problems + 1
        }
      None => {
        println("gen_dict: no checksum recorded for " + rel)
        problems = problems + 1
      }
    }

    let parsed = parse_dictionary(read_text(path))
    if parsed.skipped > 0 {
      println(
        "gen_dict: " +
        file +
        " has " +
        parsed.skipped.to_string() +
        " unparsable line(s)",
      )
      problems = problems + 1
    }

    let binding = module_name(file)
    let pairs : Array[(String, String)] = []
    for entry in parsed.entries {
      pairs.push((entry.key, entry.values[0]))
    }
    bindings.push(binding)
    data.set(binding, pairs)
    total_entries = total_entries + parsed.entries.length()
    problems = problems +
      sync_file(
        out_dir + "/" + binding + ".mbt",
        emit_dictionary(
          binding,
          "data/opencc/dictionary/" + file,
          parsed.entries,
        ),
        verify,
      )
    rows.push(
      "  { binding: \"" +
      binding +
      "\", file: \"" +
      file +
      "\", entries: " +
      parsed.entries.length().to_string() +
      ", sha256: \"" +
      digest +
      "\", derived: false },\n",
    )
  }

  // Derived dictionaries: OpenCC builds `STPhrases_GeneratedFromRegionalPhrases`
  // from the regional phrase keys, so the configurations that reference it can be
  // reproduced. Without it, `马里兰` → `馬裏蘭` instead of `馬里蘭`.
  let derived_file = "STPhrases_GeneratedFromRegionalPhrases.txt"
  let derived_binding = module_name(derived_file)
  let t2s_path = input + "/config/t2s.json"
  if @fs.path_exists(t2s_path) {
    let (derived, conflicts) = derive_regional_phrases(
      read_text(t2s_path),
      data,
    )
    if !conflicts.is_empty() {
      println(
        "gen_dict: " +
        conflicts.length().to_string() +
        " conflicting regional phrase projection(s):",
      )
      for conflict in conflicts {
        println("  " + conflict)
      }
      problems = problems + conflicts.length()
    }
    let text = render_derived(
      derived_file, "keys of HKPhrases.txt and TWPhrases.txt converted with t2s.json",
      derived,
    )
    if !verify {
      ensure_dir(derived_dir)
    }
    problems = problems +
      sync_file(derived_dir + "/" + derived_file, text, verify)
    let entries : Array[Entry] = []
    for pair in derived {
      entries.push({ key: pair.0, values: [pair.1], })
    }
    bindings.push(derived_binding)
    total_entries = total_entries + entries.length()
    problems = problems +
      sync_file(
        out_dir + "/" + derived_binding + ".mbt",
        emit_dictionary(
          derived_binding,
          derived_dir + "/" + derived_file,
          entries,
        ),
        verify,
      )
    rows.push(
      "  { binding: \"" +
      derived_binding +
      "\", file: \"derived/" +
      derived_file +
      "\", entries: " +
      entries.length().to_string() +
      ", sha256: \"" +
      sha256_of_text(text) +
      "\", derived: true },\n",
    )
  } else {
    println(
      "gen_dict: " + t2s_path + " is missing; derived dictionaries skipped",
    )
    problems = problems + 1
  }

  problems = problems +
    sync_file(
      out_dir + "/manifest.mbt",
      emit_manifest(
        "https://github.com/BYVoid/OpenCC", revision, rows, bindings,
      ),
      verify,
    )

  let dict_pkg = out_dir + "/moon.pkg"
  let ignored : Array[String] = ["manifest.mbt"]
  for binding in bindings {
    ignored.push(binding + ".mbt")
  }
  if verify {
    problems = problems + verify_pkg_ignores(dict_pkg, ignored)
  } else {
    write_text(dict_pkg, emit_pkg(bindings))
  }

  // Configurations: parsed from the same snapshot, emitted as pass trees.
  let specs : Array[ChainSpec] = []
  for file in files_with_suffix(input + "/config", ".json") {
    if file == "opencc_config.schema.json" {
      continue
    }
    let name = match file.strip_suffix(".json") {
      Some(stem) => stem.to_owned()
      None => file
    }
    let (spec, failed) = parse_config(
      name,
      read_text(input + "/config/" + file),
    )
    match spec {
      Some(parsed) => specs.push(parsed)
      None => ()
    }
    problems = problems + failed
  }
  if specs.is_empty() {
    println("gen_dict: no configurations parsed")
    problems = problems + 1
  }
  problems = problems +
    sync_file(config_out + "/chains.mbt", emit_chains(specs, bindings), verify)
  let config_pkg = config_out + "/moon.pkg"
  if verify {
    problems = problems + verify_pkg_ignores(config_pkg, ["chains.mbt"])
  }

  if problems > 0 {
    println("gen_dict: " + problems.to_string() + " problem(s) found")
    @sys.exit(1)
  }
  let summary = bindings.length().to_string() +
    " dictionaries, " +
    total_entries.to_string() +
    " entries, " +
    specs.length().to_string() +
    " configurations, revision " +
    revision +
    ")"
  if verify {
    println("gen_dict: up to date (" + summary)
  } else {
    println("gen_dict: wrote " + summary)
  }
}
