# Line Translation: CJ-HUMANEVAL-048

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `METADATA = {}` | `` |
| 4 | `` | `` |
| 5 | `` | `` |
| 6 | `def check(candidate):` | `` |
| 7 | `    assert candidate('') == True` | `CJ-HUMANEVAL-048_l7_c001` |
| 8 | `    assert candidate('aba') == True` | `CJ-HUMANEVAL-048_l8_c002` |
| 9 | `    assert candidate('aaaaa') == True` | `CJ-HUMANEVAL-048_l9_c003` |
| 10 | `    assert candidate('zbcd') == False` | `CJ-HUMANEVAL-048_l10_c004` |
| 11 | `    assert candidate('xywyx') == True` | `CJ-HUMANEVAL-048_l11_c005` |
| 12 | `    assert candidate('xywyz') == False` | `CJ-HUMANEVAL-048_l12_c006` |
| 13 | `    assert candidate('xywzx') == False` | `CJ-HUMANEVAL-048_l13_c007` |
| 14 | `` | `` |
