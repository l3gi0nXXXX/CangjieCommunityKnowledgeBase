# Line Translation: CJ-HUMANEVAL-009

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `METADATA = {` | `` |
| 4 | `    'author': 'jt',` | `` |
| 5 | `    'dataset': 'test'` | `` |
| 6 | `}` | `` |
| 7 | `` | `` |
| 8 | `` | `` |
| 9 | `def check(candidate):` | `` |
| 10 | `    assert candidate([]) == []` | `CJ-HUMANEVAL-009_l10_c001` |
| 11 | `    assert candidate([1, 2, 3, 4]) == [1, 2, 3, 4]` | `CJ-HUMANEVAL-009_l11_c002` |
| 12 | `    assert candidate([4, 3, 2, 1]) == [4, 4, 4, 4]` | `CJ-HUMANEVAL-009_l12_c003` |
| 13 | `    assert candidate([3, 2, 3, 100, 3]) == [3, 3, 3, 100, 100]` | `CJ-HUMANEVAL-009_l13_c004` |
