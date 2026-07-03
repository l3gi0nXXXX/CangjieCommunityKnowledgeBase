# Line Translation: CJ-HUMANEVAL-124

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate('03-11-2000') == True` | `CJ-HUMANEVAL-124_l4_c001` |
| 5 | `` | `` |
| 6 | `    assert candidate('15-01-2012') == False` | `CJ-HUMANEVAL-124_l6_c002` |
| 7 | `` | `` |
| 8 | `    assert candidate('04-0-2040') == False` | `CJ-HUMANEVAL-124_l8_c003` |
| 9 | `` | `` |
| 10 | `    assert candidate('06-04-2020') == True` | `CJ-HUMANEVAL-124_l10_c004` |
| 11 | `` | `` |
| 12 | `    assert candidate('01-01-2007') == True` | `CJ-HUMANEVAL-124_l12_c005` |
| 13 | `` | `` |
| 14 | `    assert candidate('03-32-2011') == False` | `CJ-HUMANEVAL-124_l14_c006` |
| 15 | `` | `` |
| 16 | `    assert candidate('') == False` | `CJ-HUMANEVAL-124_l16_c007` |
| 17 | `` | `` |
| 18 | `    assert candidate('04-31-3000') == False` | `CJ-HUMANEVAL-124_l18_c008` |
| 19 | `` | `` |
| 20 | `    assert candidate('06-06-2005') == True` | `CJ-HUMANEVAL-124_l20_c009` |
| 21 | `` | `` |
| 22 | `    assert candidate('21-31-2000') == False` | `CJ-HUMANEVAL-124_l22_c010` |
| 23 | `` | `` |
| 24 | `    assert candidate('04-12-2003') == True` | `CJ-HUMANEVAL-124_l24_c011` |
| 25 | `` | `` |
| 26 | `    assert candidate('04122003') == False` | `CJ-HUMANEVAL-124_l26_c012` |
| 27 | `` | `` |
| 28 | `    assert candidate('20030412') == False` | `CJ-HUMANEVAL-124_l28_c013` |
| 29 | `` | `` |
| 30 | `    assert candidate('2003-04') == False` | `CJ-HUMANEVAL-124_l30_c014` |
| 31 | `` | `` |
| 32 | `    assert candidate('2003-04-12') == False` | `CJ-HUMANEVAL-124_l32_c015` |
| 33 | `` | `` |
| 34 | `    assert candidate('04-2003') == False` | `CJ-HUMANEVAL-124_l34_c016` |
