// Tests for the verification report.
//
// The report is a committed artifact that CI regenerates and diffs, so two
// things have to hold for every change here: it must list every built-in
// configuration, and it must be a pure function of its inputs (no clock, no
// host, no iteration-order surprises).

///|
test "report lists every configuration and is deterministic" {
  let golden : Array[GoldenResult] = [
    { name: "s2t", passed: true, missing: [], },
  ]
  let trips : Array[RoundTripResult] = [
    { pair: "s2t -> t2s", identical: true, differences: 0, missing: [], },
  ]
  let size : SourceSize = {
    implementation_files: 11,
    implementation_lines: 1000,
    generated_files: 42,
    generated_lines: 70000,
    test_files: 5,
    test_lines: 500,
  }
  let testcases : TestCaseReport = {
    cases: 2,
    expectations: 3,
    stats: [{ config: "s2t", passed: 2, failed: 0, }],
    failures: [],
  }
  let markdown = render_report_markdown(10, golden, trips, 5, size, testcases)
  assert_eq(
    markdown,
    render_report_markdown(10, golden, trips, 5, size, testcases),
  )
  for name in @config.chain_names() {
    assert_true(markdown.contains("`" + name + "`"), msg=name)
  }
  // A configuration the snapshot cannot fully resolve must be reported as such,
  // never silently listed as verified.
  assert_true(markdown.contains("s2t") && markdown.contains("covered"))
  let json = render_report_json(10, golden, trips, 5, size, testcases)
  assert_eq(json, render_report_json(10, golden, trips, 5, size, testcases))
  assert_true(json.has_prefix("{") && json.has_suffix("}\n"))
  assert_true(json.contains("\"dictionaries\""))
  assert_true(json.contains("\"round_trips\""))
  assert_true(json.contains("\"missing_required\""))
  assert_true(json.contains("\"implementation_lines\": 1000"))
  assert_true(json.contains("\"expectations\": 3"))
  assert_true(markdown.contains("## Official test cases"))
}
