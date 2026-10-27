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
