# Line Translation: CJ-HUMANEVAL-051

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
| 7 | `    assert candidate('') == ''` | `CJ-HUMANEVAL-051_l7_c001` |
| 8 | `    assert candidate("abcdef\nghijklm") == 'bcdf\nghjklm'` | `CJ-HUMANEVAL-051_l8_c002` |
| 9 | `    assert candidate('fedcba') == 'fdcb'` | `CJ-HUMANEVAL-051_l9_c003` |
| 10 | `    assert candidate('eeeee') == ''` | `CJ-HUMANEVAL-051_l10_c004` |
| 11 | `    assert candidate('acBAA') == 'cB'` | `CJ-HUMANEVAL-051_l11_c005` |
| 12 | `    assert candidate('EcBOO') == 'cB'` | `CJ-HUMANEVAL-051_l12_c006` |
| 13 | `    assert candidate('ybcd') == 'ybcd'` | `CJ-HUMANEVAL-051_l13_c007` |
| 14 | `` | `` |
