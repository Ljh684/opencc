// Longest-match lookup and per-pass application.
//
// This first iteration scans the dictionary array linearly: it is correct and
// easy to read, and it is replaced by a sorted-array / prefix index once
// tools/gen_dict produces the real dictionaries (see docs/design.md).

/// Longest match of `text` starting at `start`.
///
/// Returns the matched length and its replacement, or `None` when nothing
/// matches at that position.
pub fn Dict::match_at(self : Dict, text : String, start : Int) -> Option[(Int, String)] {
  let end = text.length()
  let mut best_len = 0
  let mut best_value = ""
  for entry in self.entries {
    let key = entry.0
    let key_len = key.length()
    if key_len > best_len && start + key_len <= end && text[start:start + key_len] == key {
      best_len = key_len
      best_value = entry.1
    }
  }
  if best_len > 0 {
    Some((best_len, best_value))
  } else {
    None
  }
}

/// Look up a position in a dictionary group, honouring its policy.
pub fn DictGroup::lookup(self : DictGroup, text : String, start : Int) -> Option[(Int, String)] {
  match self.policy {
    Union => {
      let mut best : Option[(Int, String)] = None
      for dict in self.dicts {
        match dict.match_at(text, start) {
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
    ShortCircuit => {
      let mut found : Option[(Int, String)] = None
      for dict in self.dicts {
        match found {
          Some(_) => ()
          None => found = dict.match_at(text, start)
        }
      }
      found
    }
  }
}

/// Apply one pass over the whole text.
///
/// Characters without a match are copied through unchanged, which is what keeps
/// digits, punctuation, Latin letters and whitespace intact.
pub fn DictGroup::apply(self : DictGroup, text : String) -> String {
  let end = text.length()
  let mut out : String = ""
  let mut cursor = 0
  while cursor < end {
    match self.lookup(text, cursor) {
      Some((len, value)) => {
        out = out + value
        cursor = cursor + len
      }
      None => {
        out = out + text[cursor:cursor + 1]
        cursor = cursor + 1
      }
    }
  }
  out
}

/// Apply every pass of a chain in order.
///
/// Order is semantics, not an optimisation: OpenCC's `s2twp`, for example,
/// converts phrases before characters and applies the Taiwan wording pass last.
pub fn Chain::apply(self : Chain, text : String) -> String {
  let mut current = text
  for group in self.groups {
    current = group.apply(current)
  }
  current
}
