// The 19 conversion configurations shipped by OpenCC.
//
// Only the descriptors live here for now; the conversion chains themselves are
// transcribed from OpenCC's data/config/*.json by tools/gen_dict (W1), so that
// the definitions stay traceable to an upstream revision.

///|
/// A conversion configuration offered by the CLI.
pub struct ConfigInfo {
  name : String
  description : String
}

///|
/// Every built-in configuration.
pub fn all() -> Array[ConfigInfo] {
  [
    { name: "s2t", description: "简体 → 繁体（通用）", },
    { name: "t2s", description: "繁体 → 简体", },
    { name: "s2tw", description: "简体 → 台湾正体", },
    { name: "tw2s", description: "台湾正体 → 简体", },
    {
      name: "s2twp",
      description: "简体 → 台湾正体（含台湾用词）",
    },
    {
      name: "tw2sp",
      description: "台湾正体 → 简体（含大陆用词）",
    },
    { name: "s2hk", description: "简体 → 香港繁体", },
    { name: "hk2s", description: "香港繁体 → 简体", },
    {
      name: "s2hkp",
      description: "简体 → 香港繁体（含香港用词）",
    },
    {
      name: "hk2sp",
      description: "香港繁体 → 简体（含大陆用词）",
    },
    { name: "t2tw", description: "繁体 → 台湾正体", },
    { name: "tw2t", description: "台湾正体 → 繁体（通用）", },
    { name: "t2hk", description: "繁体 → 香港繁体", },
    { name: "hk2t", description: "香港繁体 → 繁体（通用）", },
    { name: "jp2t", description: "日本新字体 → 繁体", },
    { name: "t2jp", description: "繁体 → 日本新字体", },
    { name: "s2seal", description: "简体 → 篆书", },
    { name: "seal2t", description: "篆书 → 繁体", },
    { name: "t2seal", description: "繁体 → 篆书", },
  ]
}

///|
/// Look up a configuration by name.
pub fn find(name : String) -> ConfigInfo? {
  for info in all() {
    if info.name == name {
      return Some(info)
    }
  }
  None
}
