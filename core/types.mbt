// Shared types for the conversion engine.
//
// The shape mirrors OpenCC's model: a conversion configuration is a sequence of
// passes (`normalization` followed by `conversion_chain`), and every pass is a
// tree of dictionary groups. Grouping nests, so a pass can express things like
// `short_circuit(union(phrases, regional_phrases), characters)`.

///|
/// A dictionary, indexed by the first UTF-16 code unit of every key.
///
/// Grouping by the first code unit is what keeps lookups cheap: a position only
/// ever scans the entries whose key could start there. Within a bucket the
/// longest key comes first, so the first hit is the longest match and the scan
/// can stop immediately.
pub struct Dict {
  name : String
  buckets : Map[UInt16, Array[(String, String)]]
  size : Int
}

///|
/// How the children of a group are consulted.
pub(all) enum GroupPolicy {
  /// Consider every child and keep the longest match.
  Union
  /// Use the first child that matches.
  ShortCircuit
}

///|
/// One node of a conversion pass: either a dictionary or a group of nodes.
pub(all) enum Node {
  Leaf(Dict)
  Group(GroupPolicy, Array[Node])
}

///|
/// A conversion configuration.
///
/// `normalization` runs over the whole text first, `segmentation` decides the
/// spans that may be converted independently, and `conversion` holds the passes
/// applied to each span in order. Keeping the three apart matters: a phrase
/// match must not straddle a segment boundary, which is exactly how OpenCC's
/// `较低级别` stays `較低級別` instead of becoming `較低階別`.
pub struct Chain {
  name : String
  normalization : Array[Node]
  segmentation : Node?
  conversion : Array[Node]
}

///|
/// Longer keys first, so a bucket scan stops at the longest match.
fn longest_first(left : (String, String), right : (String, String)) -> Int {
  right.0.length().compare(left.0.length())
}

///|
/// Build a dictionary and its index from raw pairs.
///
/// Entries with an empty key are dropped: they could never advance the cursor.
pub fn Dict::new(name : String, pairs : Array[(String, String)]) -> Dict {
  let buckets : Map[UInt16, Array[(String, String)]] = Map([])
  let groups : Array[Array[(String, String)]] = []
  let mut size = 0
  for pair in pairs {
    let key = pair.0
    if key.is_empty() {
      continue
    }
    size = size + 1
    let first = key.unsafe_get(0)
    match buckets.get(first) {
      Some(bucket) => bucket.push(pair)
      None => {
        let bucket : Array[(String, String)] = [pair]
        buckets.set(first, bucket)
        groups.push(bucket)
      }
    }
  }
  for bucket in groups {
    bucket.sort_by(longest_first)
  }
  { name, buckets, size, }
}

///|
/// Number of entries in the dictionary.
pub fn Dict::size(self : Dict) -> Int {
  self.size
}

///|
/// A pass made of a single dictionary.
pub fn Node::leaf(dict : Dict) -> Node {
  Leaf(dict)
}

///|
/// A pass made of a group of nodes.
pub fn Node::group(policy : GroupPolicy, children : Array[Node]) -> Node {
  Group(policy, children)
}

///|
/// Build a chain from its passes.
pub fn Chain::new(
  name : String,
  normalization : Array[Node],
  segmentation : Node?,
  conversion : Array[Node],
) -> Chain {
  { name, normalization, segmentation, conversion, }
}
