# Line Translation: CJ-HUMANEVAL-062

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
| 7 | `    assert candidate([3, 1, 2, 4, 5]) == [1, 4, 12, 20]` | `CJ-HUMANEVAL-062_l7_c001` |
| 8 | `    assert candidate([1, 2, 3]) == [2, 6]` | `CJ-HUMANEVAL-062_l8_c002` |
| 9 | `    assert candidate([3, 2, 1]) == [2, 2]` | `CJ-HUMANEVAL-062_l9_c003` |
| 10 | `    assert candidate([3, 2, 1, 0, 4]) == [2, 2, 0, 16]` | `CJ-HUMANEVAL-062_l10_c004` |
| 11 | `    assert candidate([1]) == []` | `CJ-HUMANEVAL-062_l11_c005` |
| 12 | `` | `` |
