# Line Translation: CJ-HUMANEVAL-107

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(123) == (8, 13)` | `CJ-HUMANEVAL-107_l4_c001` |
| 5 | `    assert candidate(12) == (4, 6)` | `CJ-HUMANEVAL-107_l5_c002` |
| 6 | `    assert candidate(3) == (1, 2)` | `CJ-HUMANEVAL-107_l6_c003` |
| 7 | `    assert candidate(63) == (6, 8)` | `CJ-HUMANEVAL-107_l7_c004` |
| 8 | `    assert candidate(25) == (5, 6)` | `CJ-HUMANEVAL-107_l8_c005` |
| 9 | `    assert candidate(19) == (4, 6)` | `CJ-HUMANEVAL-107_l9_c006` |
| 10 | `    assert candidate(9) == (4, 5), "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-107_l10_c007` |
| 11 | `` | `` |
| 12 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 13 | `    assert candidate(1) == (0, 1), "This prints if this assert fails 2 (also good for debugging!)"` | `CJ-HUMANEVAL-107_l13_c008` |
| 14 | `` | `` |
