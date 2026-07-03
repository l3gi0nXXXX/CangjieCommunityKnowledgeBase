# Line Translation: CJ-HUMANEVAL-040

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
| 7 | `    assert candidate([1, 3, 5, 0]) == False` | `CJ-HUMANEVAL-040_l7_c001` |
| 8 | `    assert candidate([1, 3, 5, -1]) == False` | `CJ-HUMANEVAL-040_l8_c002` |
| 9 | `    assert candidate([1, 3, -2, 1]) == True` | `CJ-HUMANEVAL-040_l9_c003` |
| 10 | `    assert candidate([1, 2, 3, 7]) == False` | `CJ-HUMANEVAL-040_l10_c004` |
| 11 | `    assert candidate([1, 2, 5, 7]) == False` | `CJ-HUMANEVAL-040_l11_c005` |
| 12 | `    assert candidate([2, 4, -5, 3, 9, 7]) == True` | `CJ-HUMANEVAL-040_l12_c006` |
| 13 | `    assert candidate([1]) == False` | `CJ-HUMANEVAL-040_l13_c007` |
| 14 | `    assert candidate([1, 3, 5, -100]) == False` | `CJ-HUMANEVAL-040_l14_c008` |
| 15 | `    assert candidate([100, 3, 5, -100]) == False` | `CJ-HUMANEVAL-040_l15_c009` |
| 16 | `` | `` |
