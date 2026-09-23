// Parsing of OpenCC dictionary text.
//
// The upstream format is documented in the header of every dictionary file:
//
//     # Format: key<TAB>value(s) (values separated by spaces)
//
// Blank lines and lines starting with `#` are ignored. Every data line carries a
// tab in the current snapshot; a line that does not is counted as skipped so the
// caller can fail loudly instead of silently dropping entries.

///|
/// One dictionary entry: the source key and its replacement candidates.
pub struct Entry {
  key : String
  values : Array[String]
}

///|
/// Result of parsing one dictionary file.
pub struct ParsedDict {
  entries : Array[Entry]
  skipped : Int
}

///|
/// Parse an OpenCC dictionary text.
pub fn parse_dictionary(text : String) -> ParsedDict {
  let entries : Array[Entry] = []
  let mut skipped = 0
  for raw in text.split("\n") {
    let line = raw.trim()
    if line.is_empty() {
      continue
    }
    if line.has_prefix("#") {
      continue
    }
    match line.split_once("\t") {
      Some((key, rest)) => {
        let values : Array[String] = []
        for value in rest.split(" ") {
          if !value.is_empty() {
            values.push(value.to_owned())
          }
        }
        if values.is_empty() {
          skipped = skipped + 1
        } else {
          entries.push({ key: key.to_owned(), values, })
        }
      }
      None => skipped = skipped + 1
    }
  }
  { entries, skipped, }
}
