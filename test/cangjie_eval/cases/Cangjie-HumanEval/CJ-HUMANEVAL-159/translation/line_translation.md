# Line Translation: CJ-HUMANEVAL-159

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert True, "This prints if this assert fails 1 (good for debugging!)"` | `` |
| 5 | `    assert candidate(5, 6, 10) == [11, 4], "Error"` | `CJ-HUMANEVAL-159_l5_c001` |
| 6 | `    assert candidate(4, 8, 9) == [12, 1], "Error"` | `CJ-HUMANEVAL-159_l6_c002` |
| 7 | `    assert candidate(1, 10, 10) == [11, 0], "Error"` | `CJ-HUMANEVAL-159_l7_c003` |
| 8 | `    assert candidate(2, 11, 5) == [7, 0], "Error"` | `CJ-HUMANEVAL-159_l8_c004` |
| 9 | `` | `` |
| 10 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 11 | `    assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 12 | `    assert candidate(4, 5, 7) == [9, 2], "Error"` | `CJ-HUMANEVAL-159_l12_c005` |
| 13 | `    assert candidate(4, 5, 1) == [5, 0], "Error"` | `CJ-HUMANEVAL-159_l13_c006` |
| 14 | `` | `` |
