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
/// Add one entry to a bucket index under construction.
fn add_entry(
  buckets : Map[UInt16, Array[(String, String)]],
  groups : Array[Array[(String, String)]],
  key : String,
  value : String,
) -> Unit {
  let entry = (key, value)
  let first_code_unit = key.unsafe_get(0)
  match buckets.get(first_code_unit) {
    Some(bucket) => bucket.push(entry)
    None => {
      let bucket : Array[(String, String)] = [entry]
      buckets.set(first_code_unit, bucket)
      groups.push(bucket)
    }
  }
}

///|
/// Build a dictionary and its index from raw pairs.
///
/// Entries with an empty key are dropped: they could never advance the cursor.
pub fn Dict::of_pairs(name : String, pairs : Array[(String, String)]) -> Dict {
  let buckets : Map[UInt16, Array[(String, String)]] = Map([])
  let groups : Array[Array[(String, String)]] = []
  let mut size = 0
  for pair in pairs {
    if pair.0.is_empty() {
      continue
    }
    size = size + 1
    add_entry(buckets, groups, pair.0, pair.1)
  }
  for bucket in groups {
    bucket.sort_by(longest_first)
  }
  { name, buckets, size, }
}

///|
/// Parse an OpenCC dictionary and index it.
///
/// The chunks are the dictionary's own text, embedded at build time. The format
/// is the one upstream documents in every file header: one entry per line,
/// `key<TAB>value(s)` with values separated by spaces; blank lines and lines
/// starting with `#` are ignored. Only the first value is kept, because the
/// remaining candidates take part in segmentation scoring, which this engine
/// does not perform (see docs/design.md).
///
/// Lines that cannot be parsed are skipped rather than failing: `tools/gen_dict`
/// already refuses to generate such data, so at this point they can only come
/// from a corrupted embed.
pub fn Dict::parse(name : String, chunks : Array[String]) -> Dict {
  let buckets : Map[UInt16, Array[(String, String)]] = Map([])
  let groups : Array[Array[(String, String)]] = []
  let mut size = 0
  for chunk in chunks {
    for raw in chunk.split("\n") {
      let line = raw.trim_end()
      if line.is_empty() {
        continue
      }
      if line.has_prefix("#") {
        continue
      }
      match line.split_once("\t") {
        Some((key, rest)) => {
          if key.is_empty() {
            continue
          }
          let value = match rest.split_once(" ") {
            Some((first, _)) => first
            None => rest
          }
          size = size + 1
          add_entry(buckets, groups, key.to_owned(), value.to_owned())
        }
        None => ()
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
