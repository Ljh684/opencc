// Shared types for the conversion engine.
//
// The shape mirrors OpenCC's model: a conversion configuration is a sequence of
// passes ("conversion_chain"), every pass consults a group of dictionaries, and
// a group is either union or short_circuit.

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
/// How the dictionaries of a group are consulted.
pub(all) enum GroupPolicy {
  /// Consider every dictionary and keep the longest match.
  Union
  /// Use the first dictionary that matches.
  ShortCircuit
}

///|
/// One conversion pass: a group of dictionaries plus its lookup policy.
pub struct DictGroup {
  policy : GroupPolicy
  dicts : Array[Dict]
}

///|
/// A full conversion configuration: passes applied in order, first to last.
pub struct Chain {
  name : String
  groups : Array[DictGroup]
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
/// Build a dictionary group.
pub fn DictGroup::new(policy : GroupPolicy, dicts : Array[Dict]) -> DictGroup {
  { policy, dicts, }
}

///|
/// Build a chain from its passes.
pub fn Chain::from_groups(name : String, groups : Array[DictGroup]) -> Chain {
  { name, groups, }
}
