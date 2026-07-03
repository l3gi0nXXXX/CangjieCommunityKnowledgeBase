# Line Translation: CJ-HUMANEVAL-002

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
| 10 | `    assert candidate(3.5) == 0.5` | `CJ-HUMANEVAL-002_l10_c001` |
| 11 | `    assert abs(candidate(1.33) - 0.33) < 1e-6` | `CJ-HUMANEVAL-002_l11_c002` |
| 12 | `    assert abs(candidate(123.456) - 0.456) < 1e-6` | `CJ-HUMANEVAL-002_l12_c003` |
