///|
/// Entry point for the CLI or runnable program in this template.
/// Keep main focused; move logic into the library package.
/// Run with `moon run cmd/main` from the project root.
fn main {
  let sample = "sku,quantity\n0007,2\n0007,3\n"
  for issue in @lib.audit_csv(sample, 0) {
    println(issue)
  }
}
