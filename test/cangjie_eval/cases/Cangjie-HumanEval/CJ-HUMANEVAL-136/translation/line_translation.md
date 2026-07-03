# Line Translation: CJ-HUMANEVAL-136

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([2, 4, 1, 3, 5, 7]) == (None, 1)` | `CJ-HUMANEVAL-136_l4_c001` |
| 5 | `    assert candidate([2, 4, 1, 3, 5, 7, 0]) == (None, 1)` | `CJ-HUMANEVAL-136_l5_c002` |
| 6 | `    assert candidate([1, 3, 2, 4, 5, 6, -2]) == (-2, 1)` | `CJ-HUMANEVAL-136_l6_c003` |
| 7 | `    assert candidate([4, 5, 3, 6, 2, 7, -7]) == (-7, 2)` | `CJ-HUMANEVAL-136_l7_c004` |
| 8 | `    assert candidate([7, 3, 8, 4, 9, 2, 5, -9]) == (-9, 2)` | `CJ-HUMANEVAL-136_l8_c005` |
| 9 | `    assert candidate([]) == (None, None)` | `CJ-HUMANEVAL-136_l9_c006` |
| 10 | `    assert candidate([0]) == (None, None)` | `CJ-HUMANEVAL-136_l10_c007` |
| 11 | `    assert candidate([-1, -3, -5, -6]) == (-1, None)` | `CJ-HUMANEVAL-136_l11_c008` |
| 12 | `    assert candidate([-1, -3, -5, -6, 0]) == (-1, None)` | `CJ-HUMANEVAL-136_l12_c009` |
| 13 | `    assert candidate([-6, -4, -4, -3, 1]) == (-3, 1)` | `CJ-HUMANEVAL-136_l13_c010` |
| 14 | `    assert candidate([-6, -4, -4, -3, -100, 1]) == (-3, 1)` | `CJ-HUMANEVAL-136_l14_c011` |
| 15 | `` | `` |
| 16 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 17 | `    assert True` | `` |
