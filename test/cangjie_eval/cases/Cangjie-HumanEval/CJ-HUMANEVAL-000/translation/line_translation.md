# Line Translation: CJ-HUMANEVAL-000

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
| 10 | `    assert candidate([1.0, 2.0, 3.9, 4.0, 5.0, 2.2], 0.3) == True` | `CJ-HUMANEVAL-000_l10_c001` |
| 11 | `    assert candidate([1.0, 2.0, 3.9, 4.0, 5.0, 2.2], 0.05) == False` | `CJ-HUMANEVAL-000_l11_c002` |
| 12 | `    assert candidate([1.0, 2.0, 5.9, 4.0, 5.0], 0.95) == True` | `CJ-HUMANEVAL-000_l12_c003` |
| 13 | `    assert candidate([1.0, 2.0, 5.9, 4.0, 5.0], 0.8) == False` | `CJ-HUMANEVAL-000_l13_c004` |
| 14 | `    assert candidate([1.0, 2.0, 3.0, 4.0, 5.0, 2.0], 0.1) == True` | `CJ-HUMANEVAL-000_l14_c005` |
| 15 | `    assert candidate([1.1, 2.2, 3.1, 4.1, 5.1], 1.0) == True` | `CJ-HUMANEVAL-000_l15_c006` |
| 16 | `    assert candidate([1.1, 2.2, 3.1, 4.1, 5.1], 0.5) == False` | `CJ-HUMANEVAL-000_l16_c007` |
| 17 | `` | `` |
