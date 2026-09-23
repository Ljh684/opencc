// White-box tests for the matching and chain semantics.

///|
test "short_circuit uses the first matching dictionary" {
  let phrases = Dict::new("phrases", [("软件", "軟體")])
  let characters = Dict::new("characters", [("软", "軟")])
  let group = DictGroup::new(ShortCircuit, [phrases, characters])
  let chain = Chain::from_groups("test", [group])
  assert_eq(chain.apply("软件"), "軟體")
  assert_eq(chain.apply("软盘"), "軟盘")
}

///|
test "union keeps the longest match across dictionaries" {
  let characters = Dict::new("characters", [("台", "臺")])
  let phrases = Dict::new("phrases", [("台湾", "臺灣")])
  let group = DictGroup::new(Union, [characters, phrases])
  let chain = Chain::from_groups("test", [group])
  assert_eq(chain.apply("台湾"), "臺灣")
  assert_eq(chain.apply("台风"), "臺风")
}

///|
test "passes run in order" {
  let first = Dict::new("p1", [("里", "裏")])
  let second = Dict::new("p2", [("裏", "裡")])
  let group1 = DictGroup::new(ShortCircuit, [first])
  let group2 = DictGroup::new(ShortCircuit, [second])
  let chain = Chain::from_groups("test", [group1, group2])
  assert_eq(chain.apply("里"), "裡")
}

///|
test "text without a match is copied unchanged" {
  let characters = Dict::new("characters", [("软", "軟")])
  let group = DictGroup::new(ShortCircuit, [characters])
  let chain = Chain::from_groups("test", [group])
  assert_eq(chain.apply("v1.2.3 - ok!"), "v1.2.3 - ok!")
  assert_eq(chain.apply(""), "")
}

///|
test "the longest key wins regardless of the order it was listed in" {
  let dict = Dict::new("d", [("软", "軟"), ("软件", "軟體")])
  let chain = Chain::from_groups("test", [DictGroup::new(ShortCircuit, [dict])])
  assert_eq(chain.apply("软件"), "軟體")
  assert_eq(chain.apply("软盘"), "軟盘")
}

///|
test "a key longer than the remaining text never matches" {
  let dict = Dict::new("d", [("软件工程", "軟體工程")])
  let chain = Chain::from_groups("test", [DictGroup::new(ShortCircuit, [dict])])
  assert_eq(chain.apply("软件"), "软件")
  assert_eq(chain.apply("软件工程"), "軟體工程")
}

///|
test "keys that start with an astral character match too" {
  // U+2B748 is stored as a surrogate pair in UTF-16, so this key exercises the
  // code-unit level slicing the engine relies on.
  let dict = Dict::new("d", [("𫝈", "X")])
  let chain = Chain::from_groups("test", [DictGroup::new(ShortCircuit, [dict])])
  assert_eq(chain.apply("𫝈一"), "X一")
}

///|
test "empty keys are dropped and reported by size" {
  let dict = Dict::new("d", [("", "X"), ("甲", "Y")])
  assert_eq(dict.size(), 1)
  assert_eq(dict.match_at("甲", 0), Some((1, "Y")))
  let empty = Dict::new("empty", [])
  assert_eq(empty.size(), 0)
  assert_eq(empty.match_at("甲", 0), None)
  // A position past the end of the text never matches.
  assert_eq(dict.match_at("甲", 1), None)
}
