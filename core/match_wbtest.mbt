// White-box tests for the matching and chain semantics.

///|
test "short_circuit uses the first matching dictionary" {
  let phrases = Dict::new("phrases", [("软件", "軟體")])
  let characters = Dict::new("characters", [("软", "軟")])
  let pass = Node::group(ShortCircuit, [
    Node::leaf(phrases),
    Node::leaf(characters),
  ])
  let chain = Chain::new("test", [], None, [pass])
  assert_eq(chain.apply("软件"), "軟體")
  assert_eq(chain.apply("软盘"), "軟盘")
}

///|
test "union keeps the longest match across dictionaries" {
  let characters = Dict::new("characters", [("台", "臺")])
  let phrases = Dict::new("phrases", [("台湾", "臺灣")])
  let pass = Node::group(Union, [Node::leaf(characters), Node::leaf(phrases)])
  let chain = Chain::new("test", [], None, [pass])
  assert_eq(chain.apply("台湾"), "臺灣")
  assert_eq(chain.apply("台风"), "臺风")
}

///|
test "nested groups keep their own policy" {
  // short_circuit(union(phrases, regional), characters): the union picks the
  // longer phrase, and only when the union misses does the character pass run.
  let phrases = Dict::new("phrases", [("内存", "記憶體")])
  let regional = Dict::new("regional", [("内存泄漏", "記憶體洩漏")])
  let characters = Dict::new("characters", [("内", "內"), ("存", "存")])
  let inner = Node::group(Union, [Node::leaf(phrases), Node::leaf(regional)])
  let pass = Node::group(ShortCircuit, [inner, Node::leaf(characters)])
  let chain = Chain::new("test", [], None, [pass])
  assert_eq(chain.apply("内存泄漏"), "記憶體洩漏")
  assert_eq(chain.apply("内存"), "記憶體")
  assert_eq(chain.apply("内里"), "內里")
}

///|
test "passes run in order" {
  let first = Dict::new("p1", [("里", "裏")])
  let second = Dict::new("p2", [("裏", "裡")])
  let chain = Chain::new("test", [], None, [
    Node::leaf(first),
    Node::leaf(second),
  ])
  assert_eq(chain.apply("里"), "裡")
}

///|
test "text without a match is copied unchanged" {
  let chain = Chain::new("test", [], None, [
    Node::leaf(Dict::new("d", [("软", "軟")])),
  ])
  assert_eq(chain.apply("v1.2.3 - ok!"), "v1.2.3 - ok!")
  assert_eq(chain.apply(""), "")
}

///|
test "the longest key wins regardless of the order it was listed in" {
  let dict = Dict::new("d", [("软", "軟"), ("软件", "軟體")])
  let chain = Chain::new("test", [], None, [Node::leaf(dict)])
  assert_eq(chain.apply("软件"), "軟體")
  assert_eq(chain.apply("软盘"), "軟盘")
}

///|
test "a key longer than the remaining text never matches" {
  let chain = Chain::new("test", [], None, [
    Node::leaf(Dict::new("d", [("软件工程", "軟體工程")])),
  ])
  assert_eq(chain.apply("软件"), "软件")
  assert_eq(chain.apply("软件工程"), "軟體工程")
}

///|
test "keys that start with an astral character match too" {
  // U+2B748 is stored as a surrogate pair in UTF-16, so this key exercises the
  // code-unit level slicing the engine relies on.
  let chain = Chain::new("test", [], None, [
    Node::leaf(Dict::new("d", [("𫝈", "X")])),
  ])
  assert_eq(chain.apply("𫝈一"), "X一")
}

///|
test "conversion does not cross segment boundaries" {
  // Mirrors the s2twp case: the phrase pass turns 级别 into 級別, and the wording
  // pass would then happily match 低級 inside "較低級別" — unless segmentation
  // keeps the two apart. OpenCC's own output for that text is 較低級別.
  let phrases = Dict::new("phrases", [
    ("较低", "較低"),
    ("级别", "級別"),
  ])
  let wording = Dict::new("wording", [("低級", "低階")])
  let boundaries = Dict::new("segmentation", [("级别", "级别")])
  let unsegmented = Chain::new("no-segmentation", [], None, [
    Node::leaf(phrases),
    Node::leaf(wording),
  ])
  assert_eq(unsegmented.apply("较低级别"), "較低階別")
  let segmented = Chain::new("segmented", [], Some(Node::leaf(boundaries)), [
    Node::leaf(phrases),
    Node::leaf(wording),
  ])
  assert_eq(segmented.apply("较低级别"), "較低級別")
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
