// Developer tool: measure dictionary lookup on the real OpenCC data.
//
// It exists so that "the index made lookups fast enough" is a number in the
// repository rather than an opinion, and so regressions show up as a slower run.
//
// Usage:
//     moon run tools/bench_lookup --target native
//     moon run tools/bench_lookup --target native -- --input <file>

///|
/// Read a text file, exiting with a message when it cannot be read.
fn read_text(path : String) -> String {
  @fs.read_file_to_string(path) catch {
    _ => {
      println("bench_lookup: cannot read " + path)
      @sys.exit(1)
      ""
    }
  }
}

///|
/// Entry point.
fn main {
  let args = @env.args()
  let mut input_path = "test/fixtures/golden/input/us_constitution_zhs.txt"
  let mut index = 0
  while index < args.length() && !args[index].has_prefix("--") {
    index = index + 1
  }
  while index < args.length() {
    let arg = args[index]
    if arg == "--input" && index + 1 < args.length() {
      input_path = args[index + 1]
      index = index + 2
    } else {
      index = index + 1
    }
  }

  let text = read_text(input_path)
  println(
    "input        : " +
    input_path +
    " (" +
    text.length().to_string() +
    " code units)",
  )

  let build_start = @env.now()
  let phrases = @core.Dict::new("STPhrases", @dict.st_phrases)
  let characters = @core.Dict::new("STCharacters", @dict.st_characters)
  let build_ms = @env.now() - build_start
  println(
    "index build  : " +
    build_ms.to_string() +
    " ms (" +
    phrases.size().to_string() +
    " + " +
    characters.size().to_string() +
    " entries)",
  )

  // Bucket statistics are the whole point of the index: they say what a single
  // lookup actually has to scan.
  let mut max_bucket = 0
  let mut total = 0
  for entry in phrases.buckets.iter() {
    let length = entry.1.length()
    total = total + length
    if length > max_bucket {
      max_bucket = length
    }
  }
  let buckets = phrases.buckets.length()
  println(
    "buckets      : " +
    buckets.to_string() +
    " first-code-unit groups, largest " +
    max_bucket.to_string() +
    ", average " +
    (total / buckets).to_string(),
  )

  let pass = @core.Node::group(@core.ShortCircuit, [
    @core.Node::leaf(phrases),
    @core.Node::leaf(characters),
  ])
  let chain = @core.Chain::new("s2t-lite", [], None, [pass])

  // Grow the batch until the clock is meaningful: `now()` has millisecond
  // resolution, so a single pass over a small document would read as 0 ms.
  let mut rounds = 1
  let mut elapsed : UInt64 = 0
  let mut output = ""
  while rounds <= 4096 {
    let start = @env.now()
    let mut round = 0
    while round < rounds {
      output = chain.apply(text)
      round = round + 1
    }
    elapsed = @env.now() - start
    if elapsed >= 50 {
      break
    }
    rounds = rounds * 2
  }

  let units = text.length() * rounds
  let milliseconds = elapsed.to_int() + 1
  println(
    "converted    : " +
    units.to_string() +
    " code units over " +
    rounds.to_string() +
    " pass(es) in " +
    elapsed.to_string() +
    " ms",
  )
  println(
    "throughput   : " + (units / milliseconds).to_string() + " code units/ms",
  )
  println(
    "output       : " +
    output.length().to_string() +
    " code units, starts with " +
    output[:120].to_owned(),
  )
  println(
    "note         : s2t-lite = short_circuit(STPhrases, STCharacters); the",
  )
  println("               official chain adds the CJK normalisation pass (F5).")
}
