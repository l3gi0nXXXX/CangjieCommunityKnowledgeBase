# Line Translation: CJ-HUMANEVAL-008

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
| 10 | `    assert candidate([]) == (0, 1)` | `CJ-HUMANEVAL-008_l10_c001` |
| 11 | `    assert candidate([1, 1, 1]) == (3, 1)` | `CJ-HUMANEVAL-008_l11_c002` |
| 12 | `    assert candidate([100, 0]) == (100, 0)` | `CJ-HUMANEVAL-008_l12_c003` |
| 13 | `    assert candidate([3, 5, 7]) == (3 + 5 + 7, 3 * 5 * 7)` | `CJ-HUMANEVAL-008_l13_c004` |
| 14 | `    assert candidate([10]) == (10, 10)` | `CJ-HUMANEVAL-008_l14_c005` |
