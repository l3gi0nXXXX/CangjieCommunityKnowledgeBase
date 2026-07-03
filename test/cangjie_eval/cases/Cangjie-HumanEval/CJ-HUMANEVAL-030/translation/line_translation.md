# Line Translation: CJ-HUMANEVAL-030

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
| 7 | `    assert candidate([-1, -2, 4, 5, 6]) == [4, 5, 6]` | `CJ-HUMANEVAL-030_l7_c001` |
| 8 | `    assert candidate([5, 3, -5, 2, 3, 3, 9, 0, 123, 1, -10]) == [5, 3, 2, 3, 3, 9, 123, 1]` | `CJ-HUMANEVAL-030_l8_c002` |
| 9 | `    assert candidate([-1, -2]) == []` | `CJ-HUMANEVAL-030_l9_c003` |
| 10 | `    assert candidate([]) == []` | `CJ-HUMANEVAL-030_l10_c004` |
| 11 | `` | `` |
