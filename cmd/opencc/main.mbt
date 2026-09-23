// opencc CLI.
//
// This first iteration only reports the toolchain-facing surface (version and
// the built-in configurations). File and stream conversion lands in W2, once
// the dictionaries are generated and the engine can be wired to real data.

fn main {
  println("opencc.mbt 0.1.0 - OpenCC-compatible conversion in MoonBit (WIP)")
  println("")
  println("Built-in configurations:")
  for config in @config.all() {
    println("  \{config.name}  \{config.description}")
  }
  println("")
  println("Conversion from files and stdin arrives with the first data release.")
}
