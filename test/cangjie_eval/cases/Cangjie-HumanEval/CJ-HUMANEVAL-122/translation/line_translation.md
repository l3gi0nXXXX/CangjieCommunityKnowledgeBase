# Line Translation: CJ-HUMANEVAL-122

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([1,-2,-3,41,57,76,87,88,99], 3) == -4` | `CJ-HUMANEVAL-122_l4_c001` |
| 5 | `    assert candidate([111,121,3,4000,5,6], 2) == 0` | `CJ-HUMANEVAL-122_l5_c002` |
| 6 | `    assert candidate([11,21,3,90,5,6,7,8,9], 4) == 125` | `CJ-HUMANEVAL-122_l6_c003` |
| 7 | `    assert candidate([111,21,3,4000,5,6,7,8,9], 4) == 24, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-122_l7_c004` |
| 8 | `` | `` |
| 9 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 10 | `    assert candidate([1], 1) == 1, "This prints if this assert fails 2 (also good for debugging!)"` | `CJ-HUMANEVAL-122_l10_c005` |
| 11 | `` | `` |
