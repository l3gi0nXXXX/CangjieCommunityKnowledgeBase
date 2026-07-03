# Line Translation: CJ-HUMANEVAL-144

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate("1/5", "5/1") == True, 'test1'` | `CJ-HUMANEVAL-144_l4_c001` |
| 5 | `    assert candidate("1/6", "2/1") == False, 'test2'` | `CJ-HUMANEVAL-144_l5_c002` |
| 6 | `    assert candidate("5/1", "3/1") == True, 'test3'` | `CJ-HUMANEVAL-144_l6_c003` |
| 7 | `    assert candidate("7/10", "10/2") == False, 'test4'` | `CJ-HUMANEVAL-144_l7_c004` |
| 8 | `    assert candidate("2/10", "50/10") == True, 'test5'` | `CJ-HUMANEVAL-144_l8_c005` |
| 9 | `    assert candidate("7/2", "4/2") == True, 'test6'` | `CJ-HUMANEVAL-144_l9_c006` |
| 10 | `    assert candidate("11/6", "6/1") == True, 'test7'` | `CJ-HUMANEVAL-144_l10_c007` |
| 11 | `    assert candidate("2/3", "5/2") == False, 'test8'` | `CJ-HUMANEVAL-144_l11_c008` |
| 12 | `    assert candidate("5/2", "3/5") == False, 'test9'` | `CJ-HUMANEVAL-144_l12_c009` |
| 13 | `    assert candidate("2/4", "8/4") == True, 'test10'` | `CJ-HUMANEVAL-144_l13_c010` |
| 14 | `` | `` |
| 15 | `` | `` |
| 16 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 17 | `    assert candidate("2/4", "4/2") == True, 'test11'` | `CJ-HUMANEVAL-144_l17_c011` |
| 18 | `    assert candidate("1/5", "5/1") == True, 'test12'` | `CJ-HUMANEVAL-144_l18_c012` |
| 19 | `    assert candidate("1/5", "1/5") == False, 'test13'` | `CJ-HUMANEVAL-144_l19_c013` |
| 20 | `` | `` |
