# Line Translation: CJ-HUMANEVAL-043

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
| 7 | `    assert candidate([1, 3, 5, 0]) == False` | `CJ-HUMANEVAL-043_l7_c001` |
| 8 | `    assert candidate([1, 3, -2, 1]) == False` | `CJ-HUMANEVAL-043_l8_c002` |
| 9 | `    assert candidate([1, 2, 3, 7]) == False` | `CJ-HUMANEVAL-043_l9_c003` |
| 10 | `    assert candidate([2, 4, -5, 3, 5, 7]) == True` | `CJ-HUMANEVAL-043_l10_c004` |
| 11 | `    assert candidate([1]) == False` | `CJ-HUMANEVAL-043_l11_c005` |
| 12 | `` | `` |
| 13 | `    assert candidate([-3, 9, -1, 3, 2, 30]) == True` | `CJ-HUMANEVAL-043_l13_c006` |
| 14 | `    assert candidate([-3, 9, -1, 3, 2, 31]) == True` | `CJ-HUMANEVAL-043_l14_c007` |
| 15 | `    assert candidate([-3, 9, -1, 4, 2, 30]) == False` | `CJ-HUMANEVAL-043_l15_c008` |
| 16 | `    assert candidate([-3, 9, -1, 4, 2, 31]) == False` | `CJ-HUMANEVAL-043_l16_c009` |
| 17 | `` | `` |
