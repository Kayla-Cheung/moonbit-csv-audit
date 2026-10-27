///|
/// Parse CSV with quoted commas, escaped quotes, and embedded newlines.
pub fn parse_csv(source : String) -> Result[Array[Array[String]], String] {
  let chars : Array[Char] = [..source]
  let rows : Array[Array[String]] = []
  let mut row : Array[String] = []
  let mut field = ""
  let mut quoted = false
  let mut after_quote = false
  let mut at_field_start = true
  // UTF-8 BOM arrives as U+FEFF once the caller decodes the source.
  let mut i = if chars.length() > 0 && chars[0] == '\uFEFF' { 1 } else { 0 }
  while i < chars.length() {
    let c = chars[i]
    if quoted {
      if c == '"' {
        if i + 1 < chars.length() && chars[i + 1] == '"' {
          field = [..field, '"']
          i = i + 1
        } else {
          quoted = false
          after_quote = true
        }
      } else {
        field = [..field, c]
      }
    } else if c == ',' || c == '\n' || c == '\r' {
      row.push(field)
      field = ""
      after_quote = false
      at_field_start = true
      if c == '\n' || c == '\r' {
        rows.push(row)
        row = []
        if c == '\r' && i + 1 < chars.length() && chars[i + 1] == '\n' {
          i = i + 1
        }
      }
    } else if c == '"' && at_field_start {
      quoted = true
      at_field_start = false
    } else if c == '"' || after_quote {
      return Err(
        "Unexpected character after closing quote or quote in unquoted field",
      )
    } else {
      field = [..field, c]
      at_field_start = false
    }
    i = i + 1
  }
  if quoted {
    return Err("Unclosed quoted field")
  }
  if chars.length() > 0 &&
    chars[chars.length() - 1] != '\n' &&
    chars[chars.length() - 1] != '\r' {
    row.push(field)
    rows.push(row)
  }
  Ok(rows)
}

///|
/// Audit structural problems and identifier strings prone to numeric coercion.
pub fn audit_csv(source : String, key_column : Int32) -> Array[String] {
  let issues : Array[String] = []
  match parse_csv(source) {
    Err(message) => issues.push(message)
    Ok(rows) =>
      if rows.length() == 0 {
        issues.push("CSV is empty")
      } else {
        let header = rows[0]
        for i in 0..<header.length() {
          if header[i] == "" {
            issues.push("Empty header at column \{i + 1}")
          }
          for j in 0..<i {
            if header[i] == header[j] {
              issues.push("Duplicate header: \{header[i]}")
            }
          }
        }
        if key_column < 0 || key_column >= header.length() {
          issues.push("Key column is outside the header")
        }
        for r in 1..<rows.length() {
          let row = rows[r]
          if row.length() != header.length() {
            issues.push(
              "Row \{r + 1} has \{row.length()} fields; expected \{header.length()}",
            )
          }
          if key_column >= 0 && key_column < row.length() {
            let key = row[key_column]
            if key == "" {
              issues.push("Row \{r + 1} has an empty key")
            } else if key.length() > 1 &&
              key.has_prefix("0") &&
              is_ascii_digits(key) {
              issues.push("Row \{r + 1} key has leading zeros: \{key}")
            }
            if key != "" {
              for earlier in 1..<r {
                if key_column < rows[earlier].length() &&
                  key == rows[earlier][key_column] {
                  issues.push(
                    "Row \{r + 1} repeats key from row \{earlier + 1}: \{key}",
                  )
                }
              }
            }
          }
        }
      }
  }
  issues
}

///|
fn is_ascii_digits(value : String) -> Bool {
  if value == "" {
    return false
  }
  for c in value {
    if c < '0' || c > '9' {
      return false
    }
  }
  true
}
