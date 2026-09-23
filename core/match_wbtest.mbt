// White-box tests for the matching and chain semantics.

///|
test "short_circuit uses the first matching dictionary" {
  let phrases : Dict = { name: "phrases", entries: [("软件", "軟體")], }
  let characters : Dict = { name: "characters", entries: [("软", "軟")], }
  let group : DictGroup = {
    policy: ShortCircuit,
    dicts: [phrases, characters],
  }
  let chain = Chain::from_groups("test", [group])
  assert_eq(chain.apply("软件"), "軟體")
  assert_eq(chain.apply("软盘"), "軟盘")
}

///|
test "union keeps the longest match across dictionaries" {
  let characters : Dict = { name: "characters", entries: [("台", "臺")], }
  let phrases : Dict = { name: "phrases", entries: [("台湾", "臺灣")], }
  let group : DictGroup = { policy: Union, dicts: [characters, phrases], }
  let chain = Chain::from_groups("test", [group])
  assert_eq(chain.apply("台湾"), "臺灣")
  assert_eq(chain.apply("台风"), "臺风")
}

///|
test "passes run in order" {
  let first : Dict = { name: "p1", entries: [("里", "裏")], }
  let second : Dict = { name: "p2", entries: [("裏", "裡")], }
  let group1 : DictGroup = { policy: ShortCircuit, dicts: [first], }
  let group2 : DictGroup = { policy: ShortCircuit, dicts: [second], }
  let chain = Chain::from_groups("test", [group1, group2])
  assert_eq(chain.apply("里"), "裡")
}

///|
test "text without a match is copied unchanged" {
  let characters : Dict = { name: "characters", entries: [("软", "軟")], }
  let group : DictGroup = { policy: ShortCircuit, dicts: [characters], }
  let chain = Chain::from_groups("test", [group])
  assert_eq(chain.apply("v1.2.3 - ok!"), "v1.2.3 - ok!")
  assert_eq(chain.apply(""), "")
}
