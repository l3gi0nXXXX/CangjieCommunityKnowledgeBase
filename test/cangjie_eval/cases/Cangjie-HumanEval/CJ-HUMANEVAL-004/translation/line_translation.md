# Line Translation: CJ-HUMANEVAL-004

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
| 10 | `    assert abs(candidate([1.0, 2.0, 3.0]) - 2.0/3.0) < 1e-6` | `CJ-HUMANEVAL-004_l10_c001` |
| 11 | `    assert abs(candidate([1.0, 2.0, 3.0, 4.0]) - 1.0) < 1e-6` | `CJ-HUMANEVAL-004_l11_c002` |
| 12 | `    assert abs(candidate([1.0, 2.0, 3.0, 4.0, 5.0]) - 6.0/5.0) < 1e-6` | `CJ-HUMANEVAL-004_l12_c003` |
| 13 | `` | `` |
