# Line Translation: CJ-HUMANEVAL-117

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate("Mary had a little lamb", 4) == ["little"], "First test error: " + str(candidate("Mary had a little lamb", 4))      ` | `CJ-HUMANEVAL-117_l4_c001` |
| 5 | `    assert candidate("Mary had a little lamb", 3) == ["Mary", "lamb"], "Second test error: " + str(candidate("Mary had a little lamb", 3))  ` | `CJ-HUMANEVAL-117_l5_c002` |
| 6 | `    assert candidate("simple white space", 2) == [], "Third test error: " + str(candidate("simple white space", 2))      ` | `CJ-HUMANEVAL-117_l6_c003` |
| 7 | `    assert candidate("Hello world", 4) == ["world"], "Fourth test error: " + str(candidate("Hello world", 4))  ` | `CJ-HUMANEVAL-117_l7_c004` |
| 8 | `    assert candidate("Uncle sam", 3) == ["Uncle"], "Fifth test error: " + str(candidate("Uncle sam", 3))` | `CJ-HUMANEVAL-117_l8_c005` |
| 9 | `` | `` |
| 10 | `` | `` |
| 11 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 12 | `    assert candidate("", 4) == [], "1st edge test error: " + str(candidate("", 4))` | `CJ-HUMANEVAL-117_l12_c006` |
| 13 | `    assert candidate("a b c d e f", 1) == ["b", "c", "d", "f"], "2nd edge test error: " + str(candidate("a b c d e f", 1))` | `CJ-HUMANEVAL-117_l13_c007` |
| 14 | `` | `` |
