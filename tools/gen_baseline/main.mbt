// Regression baselines for every configuration.
//
// The golden corpus (test/fixtures/golden) is the *correctness* oracle, but it
// only covers five chains. This tool records what the other fourteen produce on a
// fixed mixed-script sample, so an unintended behaviour change shows up as a diff
// instead of going unnoticed. See test/fixtures/regression/README.md.
//
//     moon run tools/gen_baseline --target native
//     moon run tools/gen_baseline --target native -- --verify

///|
/// Read a text file, exiting with a message when it cannot be read.
fn read_text(path : String) -> String {
  @fs.read_file_to_string(path) catch {
    _ => {
      println("gen_baseline: cannot read " + path)
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
      println("gen_baseline: cannot write " + path)
      @sys.exit(1)
    }
  }
}

///|
/// Write or check one baseline; returns 1 when verify mode found drift.
fn sync(path : String, content : String, verify : Bool) -> Int {
  if verify {
    if !@fs.path_exists(path) {
      println("gen_baseline: missing " + path)
      return 1
    }
    if read_text(path) == content {
      0
    } else {
      println("gen_baseline: stale " + path)
      1
    }
  } else {
    write_text(path, content)
    0
  }
}

///|
/// Entry point.
fn main {
  let args = @env.args()
  let mut corpus = "test/fixtures/regression/input.txt"
  let mut out_dir = "test/fixtures/regression"
  let mut verify = false
  let mut index = 0
  while index < args.length() && !args[index].has_prefix("--") {
    index = index + 1
  }
  while index < args.length() {
    let arg = args[index]
    if arg == "--input" && index + 1 < args.length() {
      corpus = args[index + 1]
      index = index + 2
    } else if arg == "--out" && index + 1 < args.length() {
      out_dir = args[index + 1]
      index = index + 2
    } else if arg == "--verify" {
      verify = true
      index = index + 1
    } else {
      println("gen_baseline: ignoring argument " + arg)
      index = index + 1
    }
  }

  let source = read_text(corpus)
  let names = @config.chain_names()
  let mut problems = 0
  let mut written = 0
  for name in names {
    match @config.chain(name) {
      None => {
        println("gen_baseline: no chain for " + name)
        problems = problems + 1
      }
      Some(chain) => {
        // A trailing newline on the baseline keeps the files diff-friendly and
        // makes the comparison explicit rather than relying on file browsers.
        let output = chain.apply(source)
        let text = if output.has_suffix("\n") { output } else { output + "\n" }
        problems = problems + sync(out_dir + "/" + name + ".txt", text, verify)
        written = written + 1
      }
    }
  }
  if problems > 0 {
    println("gen_baseline: " + problems.to_string() + " problem(s)")
    @sys.exit(1)
  }
  println(
    "gen_baseline: " +
    written.to_string() +
    " baseline(s) " +
    (if verify { "verified" } else { "written" }),
  )
}
