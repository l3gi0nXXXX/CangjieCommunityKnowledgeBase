# Line Translation: CJ-HUMANEVAL-016

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
| 10 | `    assert candidate('') == 0` | `CJ-HUMANEVAL-016_l10_c001` |
| 11 | `    assert candidate('abcde') == 5` | `CJ-HUMANEVAL-016_l11_c002` |
| 12 | `    assert candidate('abcde' + 'cade' + 'CADE') == 5` | `CJ-HUMANEVAL-016_l12_c003` |
| 13 | `    assert candidate('aaaaAAAAaaaa') == 1` | `CJ-HUMANEVAL-016_l13_c004` |
| 14 | `    assert candidate('Jerry jERRY JeRRRY') == 5` | `CJ-HUMANEVAL-016_l14_c005` |
