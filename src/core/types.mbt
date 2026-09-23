// Shared types for the conversion engine.
//
// The shape mirrors OpenCC's model: a conversion configuration is a sequence of
// passes ("conversion_chain"), every pass consults a group of dictionaries, and
// a group is either union or short_circuit.

/// A single dictionary: an array of `key -> value` entries.
pub struct Dict {
  name : String
  entries : Array[(String, String)]
}

/// How the dictionaries of a group are consulted.
pub enum GroupPolicy {
  /// Consider every dictionary and keep the longest match.
  Union
  /// Use the first dictionary that matches.
  ShortCircuit
}

/// One conversion pass: a group of dictionaries plus its lookup policy.
pub struct DictGroup {
  policy : GroupPolicy
  dicts : Array[Dict]
}

/// A full conversion configuration: passes applied in order, first to last.
pub struct Chain {
  name : String
  groups : Array[DictGroup]
}

/// Build a dictionary from raw pairs.
///
/// Entries are kept as given; `tools/gen_dict` emits them sorted by key length
/// so the matcher can scan in one pass.
pub fn Dict::from_pairs(name : String, pairs : Array[(String, String)]) -> Dict {
  { name, entries: pairs }
}

/// Build a chain from its passes.
pub fn Chain::from_groups(name : String, groups : Array[DictGroup]) -> Chain {
  { name, groups }
}
