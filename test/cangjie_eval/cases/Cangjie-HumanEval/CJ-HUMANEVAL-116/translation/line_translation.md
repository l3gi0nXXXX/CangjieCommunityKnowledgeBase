# Line Translation: CJ-HUMANEVAL-116

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert True, "This prints if this assert fails 1 (good for debugging!)"` | `` |
| 5 | `    assert candidate([1,5,2,3,4]) == [1, 2, 4, 3, 5]` | `CJ-HUMANEVAL-116_l5_c001` |
| 6 | `    assert candidate([-2,-3,-4,-5,-6]) == [-4, -2, -6, -5, -3]` | `CJ-HUMANEVAL-116_l6_c002` |
| 7 | `    assert candidate([1,0,2,3,4]) == [0, 1, 2, 4, 3]` | `CJ-HUMANEVAL-116_l7_c003` |
| 8 | `    assert candidate([]) == []` | `CJ-HUMANEVAL-116_l8_c004` |
| 9 | `    assert candidate([2,5,77,4,5,3,5,7,2,3,4]) == [2, 2, 4, 4, 3, 3, 5, 5, 5, 7, 77]` | `CJ-HUMANEVAL-116_l9_c005` |
| 10 | `    assert candidate([3,6,44,12,32,5]) == [32, 3, 5, 6, 12, 44]` | `CJ-HUMANEVAL-116_l10_c006` |
| 11 | `    assert candidate([2,4,8,16,32]) == [2, 4, 8, 16, 32]` | `CJ-HUMANEVAL-116_l11_c007` |
| 12 | `    assert candidate([2,4,8,16,32]) == [2, 4, 8, 16, 32]` | `CJ-HUMANEVAL-116_l12_c008` |
| 13 | `` | `` |
| 14 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 15 | `    assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 16 | `` | `` |
