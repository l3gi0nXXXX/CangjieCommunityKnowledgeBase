# Line Translation: CJ-HUMANEVAL-161

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

The completion-only starter imports std.unicode.* so Rune.toLowerCase(), Rune.toUpperCase(), and Rune.isLetter() are available without modifying the file prologue. Iterate the input by Rune boundaries; direct String iteration exposes UTF-8 bytes and cannot safely implement Unicode case conversion or no-letter reversal.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate("AsDf") == "aSdF"` | `CJ-HUMANEVAL-161_l4_c001` |
| 5 | `    assert candidate("1234") == "4321"` | `CJ-HUMANEVAL-161_l5_c002` |
| 6 | `    assert candidate("ab") == "AB"` | `CJ-HUMANEVAL-161_l6_c003` |
| 7 | `    assert candidate("#a@C") == "#A@c"` | `CJ-HUMANEVAL-161_l7_c004` |
| 8 | `    assert candidate("#AsdfW^45") == "#aSDFw^45"` | `CJ-HUMANEVAL-161_l8_c005` |
| 9 | `    assert candidate("#6@2") == "2@6#"` | `CJ-HUMANEVAL-161_l9_c006` |
| 10 | `` | `` |
| 11 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 12 | `    assert candidate("#$a^D") == "#$A^d"` | `CJ-HUMANEVAL-161_l12_c007` |
| 13 | `    assert candidate("#ccc") == "#CCC"` | `CJ-HUMANEVAL-161_l13_c008` |
| 14 | `` | `` |
| 15 | `    # Don't remove this line:` | `` |

## Static-Adaptation Boundary Assertions

| Purpose | CangjieEval assertion | Expected |
|---|---|---:|
| Unicode case conversion with emoji preservation | `solve("éÉ🙂")` | `"Éé🙂"` |
| No-letter reversal by Rune rather than UTF-8 byte | `solve("🙂😂")` | `"😂🙂"` |
