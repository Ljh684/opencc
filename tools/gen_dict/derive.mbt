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
        Some(pairs) =>
          Some(@core.Node::leaf(@core.Dict::of_pairs(binding, pairs)))
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
    "# Regenerate with: moon run tools/gen_dict --target native\n",
  )
  out.write_string("\n")
  for entry in entries {
    out.write_string(entry.0)
    out.write_string("\t")
    out.write_string(entry.1)
    out.write_string("\n")
  }
  out.to_string()
}

///|
/// The code point starting at `index`, and how many UTF-16 code units it spans.
///
/// The upstream scripts sort with Python, which compares code points; MoonBit
/// strings are UTF-16, and the seal dictionaries carry characters outside the
/// basic plane (U+20000 and up), where the two orders disagree.
fn code_point_at(text : String, index : Int) -> (Int, Int) {
  let unit = text.unsafe_get(index).to_int()
  if unit >= 0xD800 && unit <= 0xDBFF && index + 1 < text.length() {
    let low = text.unsafe_get(index + 1).to_int()
    if low >= 0xDC00 && low <= 0xDFFF {
      return (0x10000 + (unit - 0xD800) * 1024 + (low - 0xDC00), 2)
    }
  }
  (unit, 1)
}

///|
/// Compare two strings by code point, the way Python's `str` comparison does.
pub fn compare_code_points(left : String, right : String) -> Int {
  let mut left_index = 0
  let mut right_index = 0
  while left_index < left.length() && right_index < right.length() {
    let (left_point, left_width) = code_point_at(left, left_index)
    let (right_point, right_width) = code_point_at(right, right_index)
    if left_point != right_point {
      return left_point.compare(right_point)
    }
    left_index = left_index + left_width
    right_index = right_index + right_width
  }
  left.length().compare(right.length())
}

///|
/// `# @reverse-prefer: <key> [<value>]` — see OpenCC's `data/scripts/common.py`.
const REVERSE_PREFERENCE : String = "# @reverse-prefer:"

///|
/// `# @tofu-risk: <reason>` — see OpenCC's `data/scripts/extract_tofu_risk.py`.
const TOFU_RISK : String = "# @tofu-risk:"

///|
/// Whether a code unit is whitespace for Python's `str.split()`: space, tab,
/// newline, carriage return, vertical tab and form feed.
fn is_python_space(unit : Int) -> Bool {
  unit == 32 ||
  unit == 9 ||
  unit == 10 ||
  unit == 13 ||
  unit == 11 ||
  unit == 12
}

///|
/// Split on runs of whitespace, the way Python's `str.split()` does.
fn whitespace_fields(text : String) -> Array[String] {
  let fields : Array[String] = []
  let mut start = -1
  let mut index = 0
  while index < text.length() {
    if is_python_space(text.unsafe_get(index).to_int()) {
      if start >= 0 {
        fields.push(text[start:index].to_owned())
        start = -1
      }
    } else if start < 0 {
      start = index
    }
    index = index + 1
  }
  if start >= 0 {
    fields.push(text[start:text.length()].to_owned())
  }
  fields
}

///|
/// Compare derived entries by their key, the way the upstream scripts sort.
fn compare_derived_keys(
  left : (String, String),
  right : (String, String),
) -> Int {
  compare_code_points(left.0, right.0)
}

///|
/// Reverse a dictionary exactly as OpenCC's `data/scripts/reverse.py` does.
///
/// Every value becomes a key whose candidate list collects the keys that mapped
/// to it, in the order they were first seen; a `# @reverse-prefer:` comment
/// moves one candidate to the front; the result is sorted by code point. This is
/// what turns `TWVariants`, `HKVariants`, `JPShinjitaiCharacters`,
/// `SealCharacters` and `SealVariants` into the `*Rev` dictionaries the reverse
/// configurations need.
///
/// Returns the derived entries and the problems upstream would treat as build
/// errors, so a changed snapshot fails loudly instead of silently diverging.
pub fn derive_reverse(
  text : String,
) -> (Array[(String, String)], Array[String]) {
  let problems : Array[String] = []
  let preferences : Array[(String, String)] = []
  let order : Array[String] = []
  let reversed : Map[String, Array[String]] = Map([])
  for raw in text.split("\n") {
    let line = raw.to_owned()
    if line.is_empty() {
      continue
    }
    if line.has_prefix("#") {
      if line.has_prefix(REVERSE_PREFERENCE) {
        let fields = whitespace_fields(
          line[REVERSE_PREFERENCE.length():].to_owned(),
        )
        if fields.length() == 1 {
          // A single field means "keep this key first", which is what upstream
          // does for entries such as `梁\t梁`.
          preferences.push((fields[0], fields[0]))
        } else if fields.length() == 2 {
          preferences.push((fields[0], fields[1]))
        } else {
          problems.push("invalid reverse preference: " + line)
        }
      }
      continue
    }
    match line.split_once("\t") {
      None => problems.push("dictionary line without a tab: " + line)
      Some((key, rest)) =>
        for value in rest.split(" ") {
          if value.is_empty() {
            // Upstream splits on a single space, so a double space would insert
            // an empty key. The snapshot has none; refuse to guess if it ever does.
            problems.push("empty value field in: " + line)
            continue
          }
          let reversed_key = value.to_owned()
          match reversed.get(reversed_key) {
            Some(candidates) => candidates.push(key.to_owned())
            None => {
              reversed.set(reversed_key, [key.to_owned()])
              order.push(reversed_key)
            }
          }
        }
    }
  }
  for preference in preferences {
    let (key, preferred) = preference
    match reversed.get(key) {
      None => problems.push("reverse preference has no mapping: " + key)
      Some(candidates) =>
        match candidates.search(preferred) {
          None =>
            problems.push(
              "reverse preference value missing: " + key + " -> " + preferred,
            )
          Some(index) => {
            let reordered : Array[String] = [preferred]
            let mut position = 0
            while position < candidates.length() {
              if position != index {
                reordered.push(candidates[position])
              }
              position = position + 1
            }
            reversed.set(key, reordered)
          }
        }
    }
  }
  let entries : Array[(String, String)] = []
  for key in order {
    match reversed.get(key) {
      Some(candidates) => entries.push((key, candidates.join(" ")))
      None => ()
    }
  }
  entries.sort_by(compare_derived_keys)
  (entries, problems)
}

///|
/// Extract the mappings OpenCC's `data/scripts/extract_tofu_risk.py` copies out
/// of `TSCharacters.txt` into `TSCharactersExt.txt`.
///
/// A mapping tagged `@tofu-risk` keeps the original character as its first
/// candidate — rare simplified forms can render as tofu — so the extracted
/// dictionary drops that first candidate and exposes the rest. Order is the
/// order of the annotations, as upstream writes them.
pub fn derive_tofu_risk(
  text : String,
) -> (Array[(String, String)], Array[String]) {
  let problems : Array[String] = []
  let entries : Array[(String, String)] = []
  let lines = lines_of(text)
  let mut index = 0
  while index < lines.length() {
    let line = lines[index]
    if !line.has_prefix(TOFU_RISK) {
      index = index + 1
      continue
    }
    if index + 1 >= lines.length() {
      problems.push("tofu-risk annotation without a mapping: " + line)
      index = index + 1
      continue
    }
    let mapping = lines[index + 1]
    if mapping.trim().is_empty() || mapping.has_prefix("#") {
      problems.push("expected a mapping after: " + line)
      index = index + 1
      continue
    }
    match mapping.split_once("\t") {
      None => problems.push("mapping line without a tab: " + mapping)
      Some((key, rest)) => {
        let key_text = key.to_owned()
        let kept : Array[String] = []
        let mut position = 0
        for value in whitespace_fields(rest.to_owned()) {
          if position > 0 || value != key_text {
            kept.push(value)
          }
          position = position + 1
        }
        if kept.is_empty() {
          problems.push("no extension mapping for: " + mapping)
        } else {
          entries.push((key_text, kept.join(" ")))
        }
      }
    }
    index = index + 1
  }
  (entries, problems)
}
