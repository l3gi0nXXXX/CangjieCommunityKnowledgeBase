# Line Translation: CJ-HUMANEVAL-109

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([3, 4, 5, 1, 2])==True, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-109_l4_c001` |
| 5 | `    assert candidate([3, 5, 10, 1, 2])==True` | `CJ-HUMANEVAL-109_l5_c002` |
| 6 | `    assert candidate([4, 3, 1, 2])==False` | `CJ-HUMANEVAL-109_l6_c003` |
| 7 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 8 | `    assert candidate([3, 5, 4, 1, 2])==False, "This prints if this assert fails 2 (also good for debugging!)"` | `CJ-HUMANEVAL-109_l8_c004` |
| 9 | `    assert candidate([])==True` | `CJ-HUMANEVAL-109_l9_c005` |
