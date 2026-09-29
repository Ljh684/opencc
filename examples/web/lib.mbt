///|
/// Simplified → Traditional Chinese with Taiwan wording.
///
/// This is the direction that a character-by-character table cannot do: 内存 /
/// 软件 / 优化 become 記憶體 / 軟體 / 最佳化.
#export_name("opencc_to_taiwan")
pub fn to_taiwan(text : String) -> String {
  @to_taiwan.chain().apply(text)
}

///|
/// Traditional → Simplified Chinese.
#export_name("opencc_to_simplified")
pub fn to_simplified(text : String) -> String {
  @to_simplified.chain().apply(text)
}
