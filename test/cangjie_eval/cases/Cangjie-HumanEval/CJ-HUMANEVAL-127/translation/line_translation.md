# Line Translation: CJ-HUMANEVAL-127

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate((1, 2), (2, 3)) == "NO"` | `CJ-HUMANEVAL-127_l4_c001` |
| 5 | `    assert candidate((-1, 1), (0, 4)) == "NO"` | `CJ-HUMANEVAL-127_l5_c002` |
| 6 | `    assert candidate((-3, -1), (-5, 5)) == "YES"` | `CJ-HUMANEVAL-127_l6_c003` |
| 7 | `    assert candidate((-2, 2), (-4, 0)) == "YES"` | `CJ-HUMANEVAL-127_l7_c004` |
| 8 | `` | `` |
| 9 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 10 | `    assert candidate((-11, 2), (-1, -1)) == "NO"` | `CJ-HUMANEVAL-127_l10_c005` |
| 11 | `    assert candidate((1, 2), (3, 5)) == "NO"` | `CJ-HUMANEVAL-127_l11_c006` |
| 12 | `    assert candidate((1, 2), (1, 2)) == "NO"` | `CJ-HUMANEVAL-127_l12_c007` |
| 13 | `    assert candidate((-2, -2), (-3, -2)) == "NO"` | `CJ-HUMANEVAL-127_l13_c008` |
| 14 | `` | `` |
