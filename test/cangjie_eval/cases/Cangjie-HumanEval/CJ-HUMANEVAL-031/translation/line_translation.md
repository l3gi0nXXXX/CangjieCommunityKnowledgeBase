# Line Translation: CJ-HUMANEVAL-031

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
| 7 | `    assert candidate(6) == False` | `CJ-HUMANEVAL-031_l7_c001` |
| 8 | `    assert candidate(101) == True` | `CJ-HUMANEVAL-031_l8_c002` |
| 9 | `    assert candidate(11) == True` | `CJ-HUMANEVAL-031_l9_c003` |
| 10 | `    assert candidate(13441) == True` | `CJ-HUMANEVAL-031_l10_c004` |
| 11 | `    assert candidate(61) == True` | `CJ-HUMANEVAL-031_l11_c005` |
| 12 | `    assert candidate(4) == False` | `CJ-HUMANEVAL-031_l12_c006` |
| 13 | `    assert candidate(1) == False` | `CJ-HUMANEVAL-031_l13_c007` |
| 14 | `    assert candidate(5) == True` | `CJ-HUMANEVAL-031_l14_c008` |
| 15 | `    assert candidate(11) == True` | `CJ-HUMANEVAL-031_l15_c009` |
| 16 | `    assert candidate(17) == True` | `CJ-HUMANEVAL-031_l16_c010` |
| 17 | `    assert candidate(5 * 17) == False` | `CJ-HUMANEVAL-031_l17_c011` |
| 18 | `    assert candidate(11 * 7) == False` | `CJ-HUMANEVAL-031_l18_c012` |
| 19 | `    assert candidate(13441 * 19) == False` | `CJ-HUMANEVAL-031_l19_c013` |
| 20 | `` | `` |
