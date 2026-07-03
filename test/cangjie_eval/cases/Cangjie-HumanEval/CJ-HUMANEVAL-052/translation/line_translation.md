# Line Translation: CJ-HUMANEVAL-052

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
| 7 | `    assert candidate([1, 2, 4, 10], 100)` | `CJ-HUMANEVAL-052_l7_c001` |
| 8 | `    assert not candidate([1, 20, 4, 10], 5)` | `CJ-HUMANEVAL-052_l8_c002` |
| 9 | `    assert candidate([1, 20, 4, 10], 21)` | `CJ-HUMANEVAL-052_l9_c003` |
| 10 | `    assert candidate([1, 20, 4, 10], 22)` | `CJ-HUMANEVAL-052_l10_c004` |
| 11 | `    assert candidate([1, 8, 4, 10], 11)` | `CJ-HUMANEVAL-052_l11_c005` |
| 12 | `    assert not candidate([1, 8, 4, 10], 10)` | `CJ-HUMANEVAL-052_l12_c006` |
| 13 | `` | `` |
