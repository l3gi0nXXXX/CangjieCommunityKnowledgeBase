# Line Translation: CJ-HUMANEVAL-126

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([5]) == True` | `CJ-HUMANEVAL-126_l4_c001` |
| 5 | `    assert candidate([1, 2, 3, 4, 5]) == True` | `CJ-HUMANEVAL-126_l5_c002` |
| 6 | `    assert candidate([1, 3, 2, 4, 5]) == False` | `CJ-HUMANEVAL-126_l6_c003` |
| 7 | `    assert candidate([1, 2, 3, 4, 5, 6]) == True` | `CJ-HUMANEVAL-126_l7_c004` |
| 8 | `    assert candidate([1, 2, 3, 4, 5, 6, 7]) == True` | `CJ-HUMANEVAL-126_l8_c005` |
| 9 | `    assert candidate([1, 3, 2, 4, 5, 6, 7]) == False, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-126_l9_c006` |
| 10 | `    assert candidate([]) == True, "This prints if this assert fails 2 (good for debugging!)"` | `CJ-HUMANEVAL-126_l10_c007` |
| 11 | `    assert candidate([1]) == True, "This prints if this assert fails 3 (good for debugging!)"` | `CJ-HUMANEVAL-126_l11_c008` |
| 12 | `    assert candidate([3, 2, 1]) == False, "This prints if this assert fails 4 (good for debugging!)"` | `CJ-HUMANEVAL-126_l12_c009` |
| 13 | `    ` | `` |
| 14 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 15 | `    assert candidate([1, 2, 2, 2, 3, 4]) == False, "This prints if this assert fails 5 (good for debugging!)"` | `CJ-HUMANEVAL-126_l15_c010` |
| 16 | `    assert candidate([1, 2, 3, 3, 3, 4]) == False, "This prints if this assert fails 6 (good for debugging!)"` | `CJ-HUMANEVAL-126_l16_c011` |
| 17 | `    assert candidate([1, 2, 2, 3, 3, 4]) == True, "This prints if this assert fails 7 (good for debugging!)"` | `CJ-HUMANEVAL-126_l17_c012` |
| 18 | `    assert candidate([1, 2, 3, 4]) == True, "This prints if this assert fails 8 (good for debugging!)"` | `CJ-HUMANEVAL-126_l18_c013` |
| 19 | `` | `` |
