# Line Translation: CJ-HUMANEVAL-120

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([-3, -4, 5], 3) == [-4, -3, 5]` | `CJ-HUMANEVAL-120_l4_c001` |
| 5 | `    assert candidate([4, -4, 4], 2) == [4, 4]` | `CJ-HUMANEVAL-120_l5_c002` |
| 6 | `    assert candidate([-3, 2, 1, 2, -1, -2, 1], 1) == [2]` | `CJ-HUMANEVAL-120_l6_c003` |
| 7 | `    assert candidate([123, -123, 20, 0 , 1, 2, -3], 3) == [2, 20, 123]` | `CJ-HUMANEVAL-120_l7_c004` |
| 8 | `    assert candidate([-123, 20, 0 , 1, 2, -3], 4) == [0, 1, 2, 20]` | `CJ-HUMANEVAL-120_l8_c005` |
| 9 | `    assert candidate([5, 15, 0, 3, -13, -8, 0], 7) == [-13, -8, 0, 0, 3, 5, 15]` | `CJ-HUMANEVAL-120_l9_c006` |
| 10 | `    assert candidate([-1, 0, 2, 5, 3, -10], 2) == [3, 5]` | `CJ-HUMANEVAL-120_l10_c007` |
| 11 | `    assert candidate([1, 0, 5, -7], 1) == [5]` | `CJ-HUMANEVAL-120_l11_c008` |
| 12 | `    assert candidate([4, -4], 2) == [-4, 4]` | `CJ-HUMANEVAL-120_l12_c009` |
| 13 | `    assert candidate([-10, 10], 2) == [-10, 10]` | `CJ-HUMANEVAL-120_l13_c010` |
| 14 | `` | `` |
| 15 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 16 | `    assert candidate([1, 2, 3, -23, 243, -400, 0], 0) == []` | `CJ-HUMANEVAL-120_l16_c011` |
| 17 | `` | `` |
