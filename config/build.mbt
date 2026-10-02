// Runtime assembly: turn the generated specifications into engine chains.
//
// The generated `chains.mbt` is data only (names and nesting). Resolving names
// into indexed dictionaries is this module's job, which keeps the generated file
// free of engine types and makes "which dictionaries are missing" a runtime
// question that the CLI can report.

///|
/// Names of every built-in configuration, in upstream file order.
pub fn chain_names() -> Array[String] {
  let names : Array[String] = []
  for spec in chains {
    names.push(spec.name)
  }
  names
}

///|
/// The generated specification of a configuration.
pub fn chain_spec(name : String) -> ChainSpec? {
  for spec in chains {
    if spec.name == name {
      return Some(spec)
    }
  }
  None
}

///|
/// Dictionaries a configuration wants but the snapshot does not ship.
pub fn missing_dictionaries(name : String) -> Array[String] {
  match chain_spec(name) {
    Some(spec) => spec.missing
    None => []
  }
}

///|
/// Build the engine chain for a configuration.
///
/// Leaves whose dictionary is missing from the snapshot are skipped rather than
/// failing the whole chain; the caller can surface them from `missing`.
pub fn chain(name : String) -> @core.Chain? {
  match chain_spec(name) {
    None => None
    Some(spec) =>
      Some(
        @core.Chain::new(
          name,
          build_all(spec.normalization),
          match spec.segmentation {
            Some(pass) => build(pass)
            None => None
          },
          build_all(spec.conversion),
        ),
      )
  }
}

///|
/// Convert `text` with a configuration.
///
/// Returns `None` when the configuration name is unknown, so callers can tell
/// "no such configuration" apart from an empty result.
pub fn convert(name : String, text : String) -> String? {
  match chain(name) {
    Some(chain) => Some(chain.apply(text))
    None => None
  }
}

///|
/// Convert `text` through several configurations, in the order given.
///
/// This mirrors the upstream CLI, where `-c` may be repeated: `s2t` followed by
/// `t2t` composes two chains rather than picking one. Returns `None` as soon as
/// a name is unknown, so a typo cannot silently drop a pass.
pub fn convert_sequence(names : Array[String], text : String) -> String? {
  let mut current = text
  for name in names {
    match convert(name, current) {
      Some(next) => current = next
      None => return None
    }
  }
  Some(current)
}

///|
/// Build every pass of a list, skipping those the snapshot cannot resolve.
fn build_all(specs : Array[Spec]) -> Array[@core.Node] {
  let nodes : Array[@core.Node] = []
  for spec in specs {
    match build(spec) {
      Some(node) => nodes.push(node)
      None => ()
    }
  }
  nodes
}

///|
/// Turn one generated specification node into an engine node.
fn build(spec : Spec) -> @core.Node? {
  match spec {
    Leaf(binding) =>
      match @dict.lookup(binding) {
        Some(chunks) =>
          Some(@core.Node::leaf(@core.Dict::parse(binding, chunks)))
        None => None
      }
    Group(policy, children) => {
      let nodes : Array[@core.Node] = []
      for child in children {
        match build(child) {
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
