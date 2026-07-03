# Line Translation: CJ-HUMANEVAL-075

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    assert candidate(5) == False` | `CJ-HUMANEVAL-075_l3_c001` |
| 4 | `    assert candidate(30) == True` | `CJ-HUMANEVAL-075_l4_c002` |
| 5 | `    assert candidate(8) == True` | `CJ-HUMANEVAL-075_l5_c003` |
| 6 | `    assert candidate(10) == False` | `CJ-HUMANEVAL-075_l6_c004` |
| 7 | `    assert candidate(125) == True` | `CJ-HUMANEVAL-075_l7_c005` |
| 8 | `    assert candidate(3 * 5 * 7) == True` | `CJ-HUMANEVAL-075_l8_c006` |
| 9 | `    assert candidate(3 * 6 * 7) == False` | `CJ-HUMANEVAL-075_l9_c007` |
| 10 | `    assert candidate(9 * 9 * 9) == False` | `CJ-HUMANEVAL-075_l10_c008` |
| 11 | `    assert candidate(11 * 9 * 9) == False` | `CJ-HUMANEVAL-075_l11_c009` |
| 12 | `    assert candidate(11 * 13 * 7) == True` | `CJ-HUMANEVAL-075_l12_c010` |
| 13 | `` | `` |
