# Line Translation: CJ-HUMANEVAL-064

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate("abcde") == 2, "Test 1"` | `CJ-HUMANEVAL-064_l4_c001` |
| 5 | `    assert candidate("Alone") == 3, "Test 2"` | `CJ-HUMANEVAL-064_l5_c002` |
| 6 | `    assert candidate("key") == 2, "Test 3"` | `CJ-HUMANEVAL-064_l6_c003` |
| 7 | `    assert candidate("bye") == 1, "Test 4"` | `CJ-HUMANEVAL-064_l7_c004` |
| 8 | `    assert candidate("keY") == 2, "Test 5"` | `CJ-HUMANEVAL-064_l8_c005` |
| 9 | `    assert candidate("bYe") == 1, "Test 6"` | `CJ-HUMANEVAL-064_l9_c006` |
| 10 | `    assert candidate("ACEDY") == 3, "Test 7"` | `CJ-HUMANEVAL-064_l10_c007` |
| 11 | `` | `` |
| 12 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 13 | `    assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 14 | `` | `` |
