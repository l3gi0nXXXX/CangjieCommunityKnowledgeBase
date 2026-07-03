# Line Translation: CJ-HUMANEVAL-057

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `METADATA = {}` | `` |
| 4 | `` | `` |
| 5 | `` | `` |
| 6 | `def check(candidate):` | `` |
| 7 | `    assert candidate([1, 2, 4, 10]) == True` | `CJ-HUMANEVAL-057_l7_c001` |
| 8 | `    assert candidate([1, 2, 4, 20]) == True` | `CJ-HUMANEVAL-057_l8_c002` |
| 9 | `    assert candidate([1, 20, 4, 10]) == False` | `CJ-HUMANEVAL-057_l9_c003` |
| 10 | `    assert candidate([4, 1, 0, -10]) == True` | `CJ-HUMANEVAL-057_l10_c004` |
| 11 | `    assert candidate([4, 1, 1, 0]) == True` | `CJ-HUMANEVAL-057_l11_c005` |
| 12 | `    assert candidate([1, 2, 3, 2, 5, 60]) == False` | `CJ-HUMANEVAL-057_l12_c006` |
| 13 | `    assert candidate([1, 2, 3, 4, 5, 60]) == True` | `CJ-HUMANEVAL-057_l13_c007` |
| 14 | `    assert candidate([9, 9, 9, 9]) == True` | `CJ-HUMANEVAL-057_l14_c008` |
| 15 | `` | `` |
