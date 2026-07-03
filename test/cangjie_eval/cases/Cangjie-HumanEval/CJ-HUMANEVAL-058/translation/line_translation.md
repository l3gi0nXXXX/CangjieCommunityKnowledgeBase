# Line Translation: CJ-HUMANEVAL-058

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
| 7 | `    assert candidate([1, 4, 3, 34, 653, 2, 5], [5, 7, 1, 5, 9, 653, 121]) == [1, 5, 653]` | `CJ-HUMANEVAL-058_l7_c001` |
| 8 | `    assert candidate([5, 3, 2, 8], [3, 2]) == [2, 3]` | `CJ-HUMANEVAL-058_l8_c002` |
| 9 | `    assert candidate([4, 3, 2, 8], [3, 2, 4]) == [2, 3, 4]` | `CJ-HUMANEVAL-058_l9_c003` |
| 10 | `    assert candidate([4, 3, 2, 8], []) == []` | `CJ-HUMANEVAL-058_l10_c004` |
| 11 | `` | `` |
