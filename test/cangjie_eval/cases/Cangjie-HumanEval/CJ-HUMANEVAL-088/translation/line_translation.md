# Line Translation: CJ-HUMANEVAL-088

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert True, "This prints if this assert fails 1 (good for debugging!)"` | `` |
| 5 | `    assert candidate([]) == [], "Error"` | `CJ-HUMANEVAL-088_l5_c001` |
| 6 | `    assert candidate([5]) == [5], "Error"` | `CJ-HUMANEVAL-088_l6_c002` |
| 7 | `    assert candidate([2, 4, 3, 0, 1, 5]) == [0, 1, 2, 3, 4, 5], "Error"` | `CJ-HUMANEVAL-088_l7_c003` |
| 8 | `    assert candidate([2, 4, 3, 0, 1, 5, 6]) == [6, 5, 4, 3, 2, 1, 0], "Error"` | `CJ-HUMANEVAL-088_l8_c004` |
| 9 | `` | `` |
| 10 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 11 | `    assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 12 | `    assert candidate([2, 1]) == [1, 2], "Error"` | `CJ-HUMANEVAL-088_l12_c005` |
| 13 | `    assert candidate([15, 42, 87, 32 ,11, 0]) == [0, 11, 15, 32, 42, 87], "Error"` | `CJ-HUMANEVAL-088_l13_c006` |
| 14 | `    assert candidate([21, 14, 23, 11]) == [23, 21, 14, 11], "Error"` | `CJ-HUMANEVAL-088_l14_c007` |
| 15 | `` | `` |
