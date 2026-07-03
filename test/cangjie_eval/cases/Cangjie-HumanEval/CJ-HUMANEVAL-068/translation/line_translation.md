# Line Translation: CJ-HUMANEVAL-068

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert True, "This prints if this assert fails 1 (good for debugging!)"` | `` |
| 5 | `    assert candidate([4,2,3]) == [2, 1], "Error"` | `CJ-HUMANEVAL-068_l5_c001` |
| 6 | `    assert candidate([1,2,3]) == [2, 1], "Error"` | `CJ-HUMANEVAL-068_l6_c002` |
| 7 | `    assert candidate([]) == [], "Error"` | `CJ-HUMANEVAL-068_l7_c003` |
| 8 | `    assert candidate([5, 0, 3, 0, 4, 2]) == [0, 1], "Error"` | `CJ-HUMANEVAL-068_l8_c004` |
| 9 | `` | `` |
| 10 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 11 | `    assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 12 | `    assert candidate([1, 2, 3, 0, 5, 3]) == [0, 3], "Error"` | `CJ-HUMANEVAL-068_l12_c005` |
| 13 | `    assert candidate([5, 4, 8, 4 ,8]) == [4, 1], "Error"` | `CJ-HUMANEVAL-068_l13_c006` |
| 14 | `    assert candidate([7, 6, 7, 1]) == [6, 1], "Error"` | `CJ-HUMANEVAL-068_l14_c007` |
| 15 | `    assert candidate([7, 9, 7, 1]) == [], "Error"` | `CJ-HUMANEVAL-068_l15_c008` |
| 16 | `` | `` |
