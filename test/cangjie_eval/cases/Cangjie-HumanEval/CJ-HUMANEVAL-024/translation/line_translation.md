# Line Translation: CJ-HUMANEVAL-024

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
| 10 | `    assert candidate(3) == 1` | `CJ-HUMANEVAL-024_l10_c001` |
| 11 | `    assert candidate(7) == 1` | `CJ-HUMANEVAL-024_l11_c002` |
| 12 | `    assert candidate(10) == 5` | `CJ-HUMANEVAL-024_l12_c003` |
| 13 | `    assert candidate(100) == 50` | `CJ-HUMANEVAL-024_l13_c004` |
| 14 | `    assert candidate(49) == 7` | `CJ-HUMANEVAL-024_l14_c005` |
