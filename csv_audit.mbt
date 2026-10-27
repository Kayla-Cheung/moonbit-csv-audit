///|
/// Parse CSV with quoted commas, escaped quotes, and embedded newlines.
pub fn parse_csv(source : String) -> Result[Array[Array[String]], String] {
  let chars : Array[Char] = [..source]
  let rows : Array[Array[String]] = []
  let mut row : Array[String] = []
  let mut field = StringBuilder()
  let mut quoted = false
  let mut after_quote = false
  let mut at_field_start = true
  let mut line = 1
  // UTF-8 BOM arrives as U+FEFF once the caller decodes the source.
  let mut i = if chars.length() > 0 && chars[0] == '\uFEFF' { 1 } else { 0 }
  while i < chars.length() {
    let c = chars[i]
    if c == '\n' ||
      (c == '\r' && (i + 1 >= chars.length() || chars[i + 1] != '\n')) {
      line = line + 1
    }
    if quoted {
      if c == '"' {
        if i + 1 < chars.length() && chars[i + 1] == '"' {
          field.write_char('"')
          i = i + 1
        } else {
          quoted = false
          after_quote = true
        }
      } else {
        field.write_char(c)
      }
    } else if c == ',' || c == '\n' || c == '\r' {
      row.push(field.to_string())
      field = StringBuilder()
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
        "Line \{line}: unexpected character after closing quote or quote in unquoted field",
      )
    } else {
      field.write_char(c)
      at_field_start = false
    }
    i = i + 1
  }
  if quoted {
    return Err("Line \{line}: unclosed quoted field")
  }
  if chars.length() > 0 &&
    chars[chars.length() - 1] != '\n' &&
    chars[chars.length() - 1] != '\r' {
    row.push(field.to_string())
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
        let seen_exact : Map[String, Int32] = Map([])
        let seen_numeric : Map[String, (String, Int32)] = Map([])
        for r in 1..<rows.length() {
          let row = rows[r]
          if row.length() != header.length() {
            issues.push(
              "Row \{r + 1} has \{row.length()} fields; expected \{header.length()}",
            )
          }
          for c in 0..<row.length() {
            if may_be_formula(row[c]) {
              issues.push(
                "Row \{r + 1} column \{c + 1} may be interpreted as a formula",
              )
            }
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
            if key.length() > 15 && is_ascii_digits(key) {
              issues.push("Row \{r + 1} key exceeds 15 digits: \{key}")
            }
            if key != "" {
              match seen_exact.get(key) {
                Some(earlier) =>
                  issues.push(
                    "Row \{r + 1} repeats key from row \{earlier + 1}: \{key}",
                  )
                None => seen_exact.set(key, r)
              }
              match numeric_canonical(key) {
                Some(canonical) =>
                  match seen_numeric.get(canonical) {
                    Some((original, earlier)) =>
                      if original != key {
                        issues.push(
                          "Row \{r + 1} key may collide numerically with row \{earlier + 1}: \{key}",
                        )
                      }
                    None => seen_numeric.set(canonical, (key, r))
                  }
                None => ()
              }
            }
          }
        }
      }
  }
  issues
}

///|
/// Locate the key column by header name, avoiding fragile numeric indexes.
/// A missing or ambiguous header is an explicit finding.
pub fn audit_csv_by_header(
  source : String,
  key_header : String,
) -> Array[String] {
  match parse_csv(source) {
    Err(message) => [message]
    Ok(rows) => {
      if rows.length() == 0 {
        return ["CSV is empty"]
      }
      let mut found = -1
      for i in 0..<rows[0].length() {
        if rows[0][i] == key_header {
          if found >= 0 {
            return ["Key header is ambiguous: \{key_header}"]
          }
          found = i
        }
      }
      if found < 0 {
        return ["Key header not found: \{key_header}"]
      }
      audit_csv(source, found)
    }
  }
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

///|
fn numeric_canonical(value : String) -> String? {
  if !is_ascii_digits(value) {
    return None
  }
  let chars : Array[Char] = [..value]
  let mut i = 0
  while i + 1 < chars.length() && chars[i] == '0' {
    i = i + 1
  }
  let builder = StringBuilder()
  while i < chars.length() {
    builder.write_char(chars[i])
    i = i + 1
  }
  Some(builder.to_string())
}

///|
fn may_be_formula(value : String) -> Bool {
  let chars : Array[Char] = [..value]
  if chars.length() == 0 {
    return false
  }
  let c = chars[0]
  c == '=' ||
  c == '+' ||
  c == '-' ||
  c == '@' ||
  c == '\t' ||
  c == '\r' ||
  c == '\n' ||
  c == '＝' ||
  c == '＋' ||
  c == '－' ||
  c == '＠'
}
