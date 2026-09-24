// Longest-match lookup and per-pass application.
//
// Lookups go through the first-code-unit index built in `Dict::new`, so a
// position only scans entries whose key can start there (see docs/design.md).

///|
/// Longest match of `text` starting at `start`.
///
/// Returns the matched length and its replacement, or `None` when nothing
/// matches at that position.
pub fn Dict::match_at(
  self : Dict,
  text : String,
  start : Int,
) -> (Int, String)? {
  let end = text.length()
  if start >= end {
    return None
  }
  match self.buckets.get(text.unsafe_get(start)) {
    None => None
    Some(bucket) => {
      // Buckets are sorted longest-first, so the first hit is the longest match.
      for pair in bucket {
        let key = pair.0
        let key_len = key.length()
        if start + key_len <= end {
          if text[start:start + key_len].equal_to_string(key) {
            return Some((key_len, pair.1))
          }
        }
      }
      None
    }
  }
}

///|
/// Longest match of `text` starting at `start` according to a pass node.
pub fn Node::lookup(self : Node, text : String, start : Int) -> (Int, String)? {
  match self {
    Leaf(dict) => dict.match_at(text, start)
    Group(Union, children) => {
      let mut best : (Int, String)? = None
      for child in children {
        match child.lookup(text, start) {
          Some((len, value)) => {
            let take = match best {
              Some((best_len, _)) => len > best_len
              None => true
            }
            if take {
              best = Some((len, value))
            }
          }
          None => ()
        }
      }
      best
    }
    Group(ShortCircuit, children) => {
      let mut found : (Int, String)? = None
      for child in children {
        match found {
          Some(_) => ()
          None => found = child.lookup(text, start)
        }
      }
      found
    }
  }
}

///|
/// Apply one pass over the whole text.
///
/// Characters without a match are copied through unchanged, which is what keeps
/// digits, punctuation, Latin letters and whitespace intact.
pub fn Node::apply(self : Node, text : String) -> String {
  let end = text.length()
  let out = StringBuilder()
  let mut cursor = 0
  while cursor < end {
    match self.lookup(text, cursor) {
      Some((len, value)) => {
        out.write_string(value)
        cursor = cursor + len
      }
      None => {
        // `write_substring` takes (start, length) — not an end offset.
        out.write_substring(text, cursor, 1)
        cursor = cursor + 1
      }
    }
  }
  out.to_string()
}

///|
/// Apply every pass of a chain to one span, in order.
///
/// Order is semantics, not an optimisation: `s2twp`, for example, converts
/// phrases before characters and applies the Taiwan wording pass last.
fn Chain::convert_all(self : Chain, text : String) -> String {
  let mut current = text
  for pass in self.conversion {
    current = pass.apply(current)
  }
  current
}

///|
/// Split `text` into spans, using a segmentation dictionary.
///
/// This mirrors OpenCC's `MaxMatchSegmentation`: a dictionary match becomes its
/// own span, and the characters between matches accumulate into one span.
fn segment(text : String, dict : Node) -> Array[(Int, Int)] {
  let spans : Array[(Int, Int)] = []
  let end = text.length()
  let mut cursor = 0
  let mut run_start = 0
  let mut run_length = 0
  while cursor < end {
    match dict.lookup(text, cursor) {
      Some((length, _)) => {
        if run_length > 0 {
          spans.push((run_start, run_length))
          run_length = 0
        }
        spans.push((cursor, length))
        cursor = cursor + length
        run_start = cursor
      }
      None => {
        if run_length == 0 {
          run_start = cursor
        }
        run_length = run_length + 1
        cursor = cursor + 1
      }
    }
  }
  if run_length > 0 {
    spans.push((run_start, run_length))
  }
  spans
}

///|
/// Convert a text: normalise, segment, then run the conversion chain per span.
pub fn Chain::apply(self : Chain, text : String) -> String {
  let mut normalized = text
  for pass in self.normalization {
    normalized = pass.apply(normalized)
  }
  match self.segmentation {
    None => self.convert_all(normalized)
    Some(dict) => {
      let out = StringBuilder()
      for span in segment(normalized, dict) {
        out.write_string(
          self.convert_all(normalized[span.0:span.0 + span.1].to_owned()),
        )
      }
      out.to_string()
    }
  }
}
