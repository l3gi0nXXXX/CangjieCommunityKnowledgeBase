# Line Translation: CJ-HUMANEVAL-108

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([]) == 0` | `CJ-HUMANEVAL-108_l4_c001` |
| 5 | `    assert candidate([-1, -2, 0]) == 0` | `CJ-HUMANEVAL-108_l5_c002` |
| 6 | `    assert candidate([1, 1, 2, -2, 3, 4, 5]) == 6` | `CJ-HUMANEVAL-108_l6_c003` |
| 7 | `    assert candidate([1, 6, 9, -6, 0, 1, 5]) == 5` | `CJ-HUMANEVAL-108_l7_c004` |
| 8 | `    assert candidate([1, 100, 98, -7, 1, -1]) == 4` | `CJ-HUMANEVAL-108_l8_c005` |
| 9 | `    assert candidate([12, 23, 34, -45, -56, 0]) == 5` | `CJ-HUMANEVAL-108_l9_c006` |
| 10 | `    assert candidate([-0, 1**0]) == 1` | `CJ-HUMANEVAL-108_l10_c007` |
| 11 | `    assert candidate([1]) == 1` | `CJ-HUMANEVAL-108_l11_c008` |
| 12 | `` | `` |
| 13 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 14 | `    assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 15 | `` | `` |
