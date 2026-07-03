# Line Translation: CJ-HUMANEVAL-022

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
| 10 | `    assert candidate([]) == []` | `CJ-HUMANEVAL-022_l10_c001` |
| 11 | `    assert candidate([4, {}, [], 23.2, 9, 'adasd']) == [4, 9]` | `CJ-HUMANEVAL-022_l11_c002` |
| 12 | `    assert candidate([3, 'c', 3, 3, 'a', 'b']) == [3, 3, 3]` | `CJ-HUMANEVAL-022_l12_c003` |
