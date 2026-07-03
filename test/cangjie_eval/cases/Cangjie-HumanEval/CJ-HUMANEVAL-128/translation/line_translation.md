# Line Translation: CJ-HUMANEVAL-128

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert True, "This prints if this assert fails 1 (good for debugging!)"` | `` |
| 5 | `    assert candidate([1, 2, 2, -4]) == -9` | `CJ-HUMANEVAL-128_l5_c001` |
| 6 | `    assert candidate([0, 1]) == 0` | `CJ-HUMANEVAL-128_l6_c002` |
| 7 | `    assert candidate([1, 1, 1, 2, 3, -1, 1]) == -10` | `CJ-HUMANEVAL-128_l7_c003` |
| 8 | `    assert candidate([]) == None` | `CJ-HUMANEVAL-128_l8_c004` |
| 9 | `    assert candidate([2, 4,1, 2, -1, -1, 9]) == 20` | `CJ-HUMANEVAL-128_l9_c005` |
| 10 | `    assert candidate([-1, 1, -1, 1]) == 4` | `CJ-HUMANEVAL-128_l10_c006` |
| 11 | `    assert candidate([-1, 1, 1, 1]) == -4` | `CJ-HUMANEVAL-128_l11_c007` |
| 12 | `    assert candidate([-1, 1, 1, 0]) == 0` | `CJ-HUMANEVAL-128_l12_c008` |
| 13 | `` | `` |
| 14 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 15 | `    assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 16 | `` | `` |
