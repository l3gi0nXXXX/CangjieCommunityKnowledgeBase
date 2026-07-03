# Line Translation: CJ-HUMANEVAL-118

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate("yogurt") == "u"` | `CJ-HUMANEVAL-118_l4_c001` |
| 5 | `    assert candidate("full") == "u"` | `CJ-HUMANEVAL-118_l5_c002` |
| 6 | `    assert candidate("easy") == ""` | `CJ-HUMANEVAL-118_l6_c003` |
| 7 | `    assert candidate("eAsy") == ""` | `CJ-HUMANEVAL-118_l7_c004` |
| 8 | `    assert candidate("ali") == ""` | `CJ-HUMANEVAL-118_l8_c005` |
| 9 | `    assert candidate("bad") == "a"` | `CJ-HUMANEVAL-118_l9_c006` |
| 10 | `    assert candidate("most") == "o"` | `CJ-HUMANEVAL-118_l10_c007` |
| 11 | `    assert candidate("ab") == ""` | `CJ-HUMANEVAL-118_l11_c008` |
| 12 | `    assert candidate("ba") == ""` | `CJ-HUMANEVAL-118_l12_c009` |
| 13 | `    assert candidate("quick") == ""` | `CJ-HUMANEVAL-118_l13_c010` |
| 14 | `    assert candidate("anime") == "i"` | `CJ-HUMANEVAL-118_l14_c011` |
| 15 | `    assert candidate("Asia") == ""` | `CJ-HUMANEVAL-118_l15_c012` |
| 16 | `    assert candidate("Above") == "o"` | `CJ-HUMANEVAL-118_l16_c013` |
| 17 | `` | `` |
| 18 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 19 | `    assert True` | `` |
| 20 | `` | `` |
