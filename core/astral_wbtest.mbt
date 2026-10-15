// Characters outside the basic plane.
//
// OpenCC's seal script configurations and its `@tofu-risk` characters are all in
// the supplementary planes, so a conversion that loses them fails upstream's own
// test cases. MoonBit stores strings as UTF-16 and its slicing returns an empty
// view for a slice that starts at a low surrogate, which is why the pass-through
// path steps over whole characters (`char_width`) instead of single code units.

///|
test "char_width counts surrogate pairs as one character" {
  let text = "A𽀃天"
  assert_eq(char_width(text, 0), 1)
  assert_eq(char_width(text, 1), 2)
  assert_eq(char_width(text, 3), 1)
}

///|
test "unmatched characters outside the basic plane are copied through" {
  let node = Node::leaf(Dict::of_pairs("probe", [("天", "甲")]))
  assert_eq(node.apply("𽀃"), "𽀃")
  assert_eq(node.apply("𽀃𽀀"), "𽀃𽀀")
  assert_eq(node.apply("a𽀃b"), "a𽀃b")
  assert_eq(node.apply("𽀃天𽀃"), "𽀃甲𽀃")
}

///|
test "dictionary keys outside the basic plane match and convert" {
  let node = Node::leaf(
    Dict::of_pairs("probe", [("𽀃", "天"), ("𽀀", "一")]),
  )
  assert_eq(node.apply("𽀃"), "天")
  assert_eq(node.apply("𽀃𽀀"), "天一")
  assert_eq(node.apply("一𽀃"), "一天")
  assert_eq(node.apply("x𽀃y"), "x天y")
}

///|
test "segmentation never splits a character outside the basic plane" {
  // The segmentation dictionary matches nothing here, so the whole text becomes
  // one span: it has to come back unchanged, pair by pair.
  let dict = Node::leaf(Dict::of_pairs("segments", [("天", "甲")]))
  let spans = segment("𽀃𽀀天", dict)
  assert_eq(spans.length(), 2)
  assert_eq(spans[0].0, 0)
  assert_eq(spans[0].1, 4)
  assert_eq(spans[1].0, 4)
  assert_eq(spans[1].1, 1)
}
