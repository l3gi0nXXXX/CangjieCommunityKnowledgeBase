# Line Translation: CJ-HUMANEVAL-114

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([2, 3, 4, 1, 2, 4]) == 1, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-114_l4_c001` |
| 5 | `    assert candidate([-1, -2, -3]) == -6` | `CJ-HUMANEVAL-114_l5_c002` |
| 6 | `    assert candidate([-1, -2, -3, 2, -10]) == -14` | `CJ-HUMANEVAL-114_l6_c003` |
| 7 | `    assert candidate([-9999999999999999]) == -9999999999999999` | `CJ-HUMANEVAL-114_l7_c004` |
| 8 | `    assert candidate([0, 10, 20, 1000000]) == 0` | `CJ-HUMANEVAL-114_l8_c005` |
| 9 | `    assert candidate([-1, -2, -3, 10, -5]) == -6` | `CJ-HUMANEVAL-114_l9_c006` |
| 10 | `    assert candidate([100, -1, -2, -3, 10, -5]) == -6` | `CJ-HUMANEVAL-114_l10_c007` |
| 11 | `    assert candidate([10, 11, 13, 8, 3, 4]) == 3` | `CJ-HUMANEVAL-114_l11_c008` |
| 12 | `    assert candidate([100, -33, 32, -1, 0, -2]) == -33` | `CJ-HUMANEVAL-114_l12_c009` |
| 13 | `` | `` |
| 14 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 15 | `    assert candidate([-10]) == -10, "This prints if this assert fails 2 (also good for debugging!)"` | `CJ-HUMANEVAL-114_l15_c010` |
| 16 | `    assert candidate([7]) == 7` | `CJ-HUMANEVAL-114_l16_c011` |
| 17 | `    assert candidate([1, -1]) == -1` | `CJ-HUMANEVAL-114_l17_c012` |
