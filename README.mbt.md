# MoonBit CSV Audit

An original, dependency-free MoonBit library for checking CSV structure and
identifier integrity before a spreadsheet import. It is a prototype for the
October 2026 MoonBit hackathon; no acceptance, award, or customer demand is
claimed.

## What it does

`parse_csv` handles a decoded UTF-8 BOM, quoted commas, doubled quotes, CRLF, and newlines inside
quoted fields. It reports malformed quote placement with a physical line number. `audit_csv` then reports
empty or duplicate column names, row-width mismatches, repeated values in a
chosen key column, missing keys, numeric-looking keys with leading zeroes, and distinct keys
that collapse to the same number, plus digit-only keys longer than 15 digits.
These warnings reflect [Microsoft's documented Excel conversion behavior](https://support.microsoft.com/en-us/excel/keeping-leading-zeros-and-large-numbers). Leading-zero
findings are warnings: the library does not claim that data has already been
corrupted. It does not modify the input.

It also locates cells starting with common spreadsheet formula trigger
characters, following [OWASP's CSV injection guidance](https://community.owasp.org/attacks/CSV_Injection).
These are conservative warnings, including possible false positives such as
negative numbers; the library does not sanitize or execute cell contents.

The initial scope assumes an already-decoded Unicode string. Encoding checks,
formula injection screening, huge-file streaming, and full spreadsheet import
simulation are outside this version.

## Reproduce

With the MoonBit toolchain installed, run from this directory:

```sh
moon test
moon run cmd/main
```

The runnable example prints three warnings for an invented two-row CSV:

```text
Row 2 key has leading zeros: 0007
Row 3 key has leading zeros: 0007
Row 3 repeats key from row 2: 0007
```

The module coordinate uses the existing authorized GitHub account name;
Mooncakes ownership has not been verified and no package has been published.
Apache-2.0 license.
