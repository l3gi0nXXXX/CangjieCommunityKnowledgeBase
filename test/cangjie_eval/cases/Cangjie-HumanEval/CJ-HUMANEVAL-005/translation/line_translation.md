# Line Translation: CJ-HUMANEVAL-005

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
| 10 | `    assert candidate([], 7) == []` | `CJ-HUMANEVAL-005_l10_c001` |
| 11 | `    assert candidate([5, 6, 3, 2], 8) == [5, 8, 6, 8, 3, 8, 2]` | `CJ-HUMANEVAL-005_l11_c002` |
| 12 | `    assert candidate([2, 2, 2], 2) == [2, 2, 2, 2, 2]` | `CJ-HUMANEVAL-005_l12_c003` |
