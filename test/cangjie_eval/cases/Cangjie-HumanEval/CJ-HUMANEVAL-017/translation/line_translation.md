# Line Translation: CJ-HUMANEVAL-017

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
| 10 | `    assert candidate('') == []` | `CJ-HUMANEVAL-017_l10_c001` |
| 11 | `    assert candidate('o o o o') == [4, 4, 4, 4]` | `CJ-HUMANEVAL-017_l11_c002` |
| 12 | `    assert candidate('.\| .\| .\| .\|') == [1, 1, 1, 1]` | `CJ-HUMANEVAL-017_l12_c003` |
| 13 | `    assert candidate('o\| o\| .\| .\| o o o o') == [2, 2, 1, 1, 4, 4, 4, 4]` | `CJ-HUMANEVAL-017_l13_c004` |
| 14 | `    assert candidate('o\| .\| o\| .\| o o\| o o\|') == [2, 1, 2, 1, 4, 2, 4, 2]` | `CJ-HUMANEVAL-017_l14_c005` |
