# Line Translation: CJ-HUMANEVAL-018

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
| 10 | `    assert candidate('', 'x') == 0` | `CJ-HUMANEVAL-018_l10_c001` |
| 11 | `    assert candidate('xyxyxyx', 'x') == 4` | `CJ-HUMANEVAL-018_l11_c002` |
| 12 | `    assert candidate('cacacacac', 'cac') == 4` | `CJ-HUMANEVAL-018_l12_c003` |
| 13 | `    assert candidate('john doe', 'john') == 1` | `CJ-HUMANEVAL-018_l13_c004` |
