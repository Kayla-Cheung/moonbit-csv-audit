///|
test "quoted comma and escaped quote" {
  match
    @moonbit-csv-audit.parse_csv("id,note\n0007,\"a,b\"\n8,\"say \"\"hi\"\"\"") {
    Ok(rows) => {
      assert_eq(rows.length(), 3)
      assert_eq(rows[1][1], "a,b")
      assert_eq(rows[2][1], "say \"hi\"")
    }
    Err(_) => fail("valid CSV rejected")
  }
}

///|
test "embedded newline and malformed quote" {
  match @moonbit-csv-audit.parse_csv("id,note\n1,\"first\nsecond\"") {
    Ok(rows) => assert_eq(rows[1][1], "first\nsecond")
    Err(_) => fail("embedded newline rejected")
  }
  match @moonbit-csv-audit.parse_csv("id\n\"unfinished") {
    Err(_) => ()
    Ok(_) => fail("unclosed quote accepted")
  }
}

///|
test "audit identifiers and malformed rows" {
  let issues = @moonbit-csv-audit.audit_csv("id,id\n0007,a\n0007\n", 0)
  assert_eq(issues.length(), 5)
}

///|
test "CRLF, Chinese text, and clean input" {
  match @moonbit-csv-audit.parse_csv("编号,名称\r\n0007,月兔\r\n") {
    Ok(rows) => {
      assert_eq(rows.length(), 2)
      assert_eq(rows[1][1], "月兔")
    }
    Err(_) => fail("valid CRLF CSV rejected")
  }
  assert_eq(
    @moonbit-csv-audit.audit_csv("id,name\n7,月兔\n8,小明\n", 0).length(),
    0,
  )
}

///|
test "trailing junk after quote is rejected" {
  match @moonbit-csv-audit.parse_csv("id\n\"7\"x") {
    Err(_) => ()
    Ok(_) => fail("invalid CSV accepted")
  }
}

///|
test "decoded UTF-8 BOM is not part of the first header" {
  match @moonbit-csv-audit.parse_csv("\uFEFFid,name\n7,月兔\n") {
    Ok(rows) => assert_eq(rows[0][0], "id")
    Err(_) => fail("BOM-prefixed CSV rejected")
  }
}

///|
test "missing keys have a dedicated warning" {
  let issues = @moonbit-csv-audit.audit_csv("id,name\n,A\n,B\n", 0)
  assert_eq(issues.length(), 2)
  assert_eq(issues[0], "Row 2 has an empty key")
  assert_eq(issues[1], "Row 3 has an empty key")
}

///|
test "parse errors identify their physical line" {
  match @moonbit-csv-audit.parse_csv("id\n1\n\"bad") {
    Err(message) => assert_eq(message, "Line 3: unclosed quoted field")
    Ok(_) => fail("unclosed quote accepted")
  }
}

///|
test "different identifiers that coerce to one number are flagged" {
  let issues = @moonbit-csv-audit.audit_csv("sku,name\n0007,A\n7,B\n", 0)
  assert_eq(issues.length(), 2)
  assert_eq(issues[1], "Row 3 key may collide numerically with row 2: 7")
}

///|
test "sixteen-digit key is flagged for spreadsheet precision" {
  let issues = @moonbit-csv-audit.audit_csv("id\n1234567890123456\n", 0)
  assert_eq(issues.length(), 1)
  assert_eq(issues[0], "Row 2 key exceeds 15 digits: 1234567890123456")
}

///|
test "formula-like values are located without modifying CSV" {
  let issues = @moonbit-csv-audit.audit_csv("id,note\n7,=1+1\n8,＠SUM(1)\n", 0)
  assert_eq(issues.length(), 2)
  assert_eq(issues[0], "Row 2 column 2 may be interpreted as a formula")
  assert_eq(issues[1], "Row 3 column 2 may be interpreted as a formula")
}

///|
test "audit can locate a uniquely named key column" {
  let issues = @moonbit-csv-audit.audit_csv_by_header(
    "name,sku\nA,0007\nB,0007\n", "sku",
  )
  assert_eq(issues.length(), 3)
  assert_eq(issues[2], "Row 3 repeats key from row 2: 0007")
  assert_eq(
    @moonbit-csv-audit.audit_csv_by_header("name\nA\n", "sku")[0],
    "Key header not found: sku",
  )
  assert_eq(
    @moonbit-csv-audit.audit_csv_by_header("sku,sku\n1,2\n", "sku")[0],
    "Key header is ambiguous: sku",
  )
}

///|
test "repeated keys point to the first occurrence" {
  let issues = @moonbit-csv-audit.audit_csv("sku\nA\nA\nA\n", 0)
  assert_eq(issues.length(), 2)
  assert_eq(issues[0], "Row 3 repeats key from row 2: A")
  assert_eq(issues[1], "Row 4 repeats key from row 2: A")
}
