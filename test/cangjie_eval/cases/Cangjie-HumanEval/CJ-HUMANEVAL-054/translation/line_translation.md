# Line Translation: CJ-HUMANEVAL-054

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
| 7 | `    assert candidate('eabcdzzzz', 'dddzzzzzzzddeddabc') == True` | `CJ-HUMANEVAL-054_l7_c001` |
| 8 | `    assert candidate('abcd', 'dddddddabc') == True` | `CJ-HUMANEVAL-054_l8_c002` |
| 9 | `    assert candidate('dddddddabc', 'abcd') == True` | `CJ-HUMANEVAL-054_l9_c003` |
| 10 | `    assert candidate('eabcd', 'dddddddabc') == False` | `CJ-HUMANEVAL-054_l10_c004` |
| 11 | `    assert candidate('abcd', 'dddddddabcf') == False` | `CJ-HUMANEVAL-054_l11_c005` |
| 12 | `    assert candidate('eabcdzzzz', 'dddzzzzzzzddddabc') == False` | `CJ-HUMANEVAL-054_l12_c006` |
| 13 | `    assert candidate('aabb', 'aaccc') == False` | `CJ-HUMANEVAL-054_l13_c007` |
| 14 | `` | `` |
