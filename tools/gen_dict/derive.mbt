// Derivation of the dictionaries OpenCC builds from other dictionaries.
//
// OpenCC ships most dictionaries as text, but a few are produced during its own
// build. `STPhrases_GeneratedFromRegionalPhrases` is the one that matters for the
// configurations this project covers; its rule (see OpenCC's
// data/scripts/generate_st_phrases_from_regional_phrases.py) is to take every key
// of the Hong Kong and Taiwan phrase dictionaries, convert that key to Simplified
// Chinese through the `t2s` configuration, and map the result back to the regional
// phrase — skipping projections shorter than three code units, because a short key
// would split longer Simplified words.

///|
/// Keys of a parsed dictionary, in file order.
fn keys_of(
  data : Map[String, Array[(String, String)]],
  binding : String,
) -> Array[String] {
  let keys : Array[String] = []
  match data.get(binding) {
    Some(pairs) =>
      for pair in pairs {
        keys.push(pair.0)
      }
    None => ()
  }
  keys
}

///|
/// Build an engine node from a spec, resolving names against freshly parsed data.
fn node_of(
  spec : Spec,
  data : Map[String, Array[(String, String)]],
) -> @core.Node? {
  match spec {
    Leaf(binding) =>
      match data.get(binding) {
        Some(pairs) => Some(@core.Node::leaf(@core.Dict::new(binding, pairs)))
        None => None
      }
    Group(policy, children) => {
      let nodes : Array[@core.Node] = []
      for child in children {
        match node_of(child, data) {
          Some(node) => nodes.push(node)
          None => ()
        }
      }
      if nodes.is_empty() {
        None
      } else {
        let engine_policy = match policy {
          Union => @core.Union
          ShortCircuit => @core.ShortCircuit
        }
        Some(@core.Node::group(engine_policy, nodes))
      }
    }
  }
}

///|
/// Compare keys lexicographically (MoonBit's default order is length-first).
fn compare_keys(left : (String, String), right : (String, String)) -> Int {
  let limit = if left.0.length() < right.0.length() {
    left.0.length()
  } else {
    right.0.length()
  }
  let mut index = 0
  while index < limit {
    let order = left.0.unsafe_get(index).compare(right.0.unsafe_get(index))
    if order != 0 {
      return order
    }
    index = index + 1
  }
  left.0.length().compare(right.0.length())
}

///|
/// Derive `st_phrases_generated_from_regional_phrases`.
///
/// Returns the derived entries and the Simplified projections that map to more
/// than one regional phrase. OpenCC treats such a conflict as a build error, and
/// so do we: it means our `t2s` conversion disagrees with upstream.
pub fn derive_regional_phrases(
  t2s_config : String,
  data : Map[String, Array[(String, String)]],
) -> (Array[(String, String)], Array[String]) {
  let (spec, _) = parse_config("t2s", t2s_config)
  match spec {
    None => ([], [])
    Some(chain_spec) => {
      let chain = node_chain(chain_spec, data)
      let mapping : Map[String, String] = Map([])
      let conflicts : Array[String] = []
      for binding in ["hk_phrases", "tw_phrases"] {
        for key in keys_of(data, binding) {
          let converted = chain.apply(key)
          if converted.length() < 3 {
            continue
          }
          match mapping.get(converted) {
            Some(existing) =>
              if existing != key && !conflicts.contains(converted) {
                conflicts.push(converted)
              }
            None => mapping.set(converted, key)
          }
        }
      }
      let derived : Array[(String, String)] = []
      for entry in mapping.iter() {
        derived.push(entry)
      }
      derived.sort_by(compare_keys)
      (derived, conflicts)
    }
  }
}

///|
/// Assemble a chain from a parsed spec, using freshly parsed dictionaries.
fn nodes_of(
  specs : Array[Spec],
  data : Map[String, Array[(String, String)]],
) -> Array[@core.Node] {
  let nodes : Array[@core.Node] = []
  for spec in specs {
    match node_of(spec, data) {
      Some(node) => nodes.push(node)
      None => ()
    }
  }
  nodes
}

///|
/// Assemble the whole chain (normalisation, segmentation, conversions).
fn node_chain(
  spec : ChainSpec,
  data : Map[String, Array[(String, String)]],
) -> @core.Chain {
  @core.Chain::new(
    spec.name,
    nodes_of(spec.normalization, data),
    match spec.segmentation {
      Some(pass) => node_of(pass, data)
      None => None
    },
    nodes_of(spec.conversion, data),
  )
}

///|
/// Render a derived dictionary as text in the upstream file layout, so the
/// derivation stays auditable instead of hiding inside generated MoonBit.
pub fn render_derived(
  file_name : String,
  source_note : String,
  entries : Array[(String, String)],
) -> String {
  let out = StringBuilder()
  out.write_string("# Open Chinese Convert (OpenCC) Dictionary\n")
  out.write_string("# File: ")
  out.write_string(file_name)
  out.write_string("\n")
  out.write_string("# Format: key\tvalue(s) (values separated by spaces)\n")
  out.write_string("# License: Apache-2.0 (see LICENSE)\n")
  out.write_string("# Source: derived by tools/gen_dict — ")
  out.write_string(source_note)
  out.write_string("\n")
  out.write_string("#\n")
  out.write_string(
    "# This derived dictionary preserves Simplified-input spans before applying\n",
  )
  out.write_string("# regional phrase vocabulary.\n")
  out.write_string("\n")
  for entry in entries {
    out.write_string(entry.0)
    out.write_string("\t")
    out.write_string(entry.1)
    out.write_string("\n")
  }
  out.to_string()
}
