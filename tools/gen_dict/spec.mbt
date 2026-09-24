// Parsing of OpenCC conversion configurations.
//
// A configuration names its input dictionaries as `.ocd2` files. This module
// turns those references into the binding names used by the generated `dict`
// package (so `STPhrases.ocd2` becomes `st_phrases`) and keeps the nesting of
// `match_policy` groups intact, because the nesting is semantics.

///|
/// Read a field of a JSON object.
fn field(json : Json, key : String) -> Json? {
  if json is Object(object) {
    object.get(key)
  } else {
    None
  }
}

///|
/// Read a JSON string.
fn as_text(json : Json) -> String? {
  if json is String(text) {
    Some(text)
  } else {
    None
  }
}

///|
/// Read a JSON array.
fn as_list(json : Json) -> Array[Json]? {
  if json is Array(items) {
    Some(items)
  } else {
    None
  }
}

///|
/// Policy of a dictionary group, as declared in a configuration.
pub(all) enum SpecPolicy {
  Union
  ShortCircuit
}

///|
/// A conversion pass: a dictionary, or a group of passes.
pub(all) enum Spec {
  Leaf(String)
  Group(SpecPolicy, Array[Spec])
}

///|
/// One conversion configuration.
pub struct ChainSpec {
  name : String
  title : String
  normalization : Array[Spec]
  segmentation : Spec?
  conversion : Array[Spec]
}

///|
/// Every leaf dictionary name of a pass, in order.
pub fn Spec::leaves(self : Spec) -> Array[String] {
  match self {
    Leaf(name) => [name]
    Group(_, children) => {
      let out : Array[String] = []
      for child in children {
        for name in child.leaves() {
          out.push(name)
        }
      }
      out
    }
  }
}

///|
/// `STPhrases.ocd2` -> `st_phrases`.
fn binding_of(file : String) -> String {
  let stem = match file.strip_suffix(".ocd2") {
    Some(stem) => stem
    None => file.to_string_view()
  }
  module_name(stem.to_owned() + ".txt")
}

///|
/// Read a `{ "dict": <spec> }` wrapper.
fn spec_of_holder(json : Json) -> Spec? {
  match field(json, "dict") {
    Some(dict) => spec_of(dict)
    None => None
  }
}

///|
/// Read a leaf dictionary or a nested group.
pub fn spec_of(json : Json) -> Spec? {
  match field(json, "type") {
    Some(kind) =>
      match as_text(kind) {
        Some("group") => {
          let policy = match field(json, "match_policy") {
            Some(node) =>
              match as_text(node) {
                Some("union") => Union
                _ => ShortCircuit
              }
            None => ShortCircuit
          }
          let children : Array[Spec] = []
          match field(json, "dicts") {
            Some(node) =>
              match as_list(node) {
                Some(items) =>
                  for item in items {
                    match spec_of(item) {
                      Some(child) => children.push(child)
                      None => ()
                    }
                  }
                None => ()
              }
            None => ()
          }
          Some(Group(policy, children))
        }
        Some(_) => leaf_of(json)
        None => leaf_of(json)
      }
    None => leaf_of(json)
  }
}

///|
/// Read `{ "file": "X.ocd2" }` as a leaf.
fn leaf_of(json : Json) -> Spec? {
  match field(json, "file") {
    Some(node) =>
      match as_text(node) {
        Some(name) => Some(Leaf(binding_of(name)))
        None => None
      }
    None => None
  }
}

///|
/// Parse one configuration file.
///
/// Returns the spec and how many parts of it could not be understood.
pub fn parse_config(name : String, text : String) -> (ChainSpec?, Int) {
  try {
    let json = @json.parse(text)
    let mut problems = 0
    let title = match field(json, "name") {
      Some(node) =>
        match as_text(node) {
          Some(title) => title
          None => ""
        }
      None => ""
    }
    let normalization : Array[Spec] = []
    match field(json, "normalization") {
      Some(node) =>
        match as_list(node) {
          Some(items) =>
            for item in items {
              match spec_of_holder(item) {
                Some(spec) => normalization.push(spec)
                None => problems = problems + 1
              }
            }
          None => problems = problems + 1
        }
      None => ()
    }
    // Segmentation decides which spans may be converted independently.
    let segmentation = match field(json, "segmentation") {
      Some(node) =>
        match field(node, "dict") {
          Some(dict) => spec_of(dict)
          None => None
        }
      None => None
    }
    let conversion : Array[Spec] = []
    match field(json, "conversion_chain") {
      Some(node) =>
        match as_list(node) {
          Some(items) =>
            for item in items {
              match spec_of_holder(item) {
                Some(spec) => conversion.push(spec)
                None => problems = problems + 1
              }
            }
          None => problems = problems + 1
        }
      None => problems = problems + 1
    }
    (Some({ name, title, normalization, segmentation, conversion, }), problems)
  } catch {
    _ => (None, 1)
  }
}
