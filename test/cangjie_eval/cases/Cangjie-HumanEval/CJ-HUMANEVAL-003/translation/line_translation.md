# Line Translation: CJ-HUMANEVAL-003

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
| 10 | `    assert candidate([]) == False` | `CJ-HUMANEVAL-003_l10_c001` |
| 11 | `    assert candidate([1, 2, -3, 1, 2, -3]) == False` | `CJ-HUMANEVAL-003_l11_c002` |
| 12 | `    assert candidate([1, 2, -4, 5, 6]) == True` | `CJ-HUMANEVAL-003_l12_c003` |
| 13 | `    assert candidate([1, -1, 2, -2, 5, -5, 4, -4]) == False` | `CJ-HUMANEVAL-003_l13_c004` |
| 14 | `    assert candidate([1, -1, 2, -2, 5, -5, 4, -5]) == True` | `CJ-HUMANEVAL-003_l14_c005` |
| 15 | `    assert candidate([1, -2, 2, -2, 5, -5, 4, -4]) == True` | `CJ-HUMANEVAL-003_l15_c006` |
