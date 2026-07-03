# Line Translation: CJ-HUMANEVAL-141

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate("example.txt") == 'Yes'` | `CJ-HUMANEVAL-141_l4_c001` |
| 5 | `    assert candidate("1example.dll") == 'No'` | `CJ-HUMANEVAL-141_l5_c002` |
| 6 | `    assert candidate('s1sdf3.asd') == 'No'` | `CJ-HUMANEVAL-141_l6_c003` |
| 7 | `    assert candidate('K.dll') == 'Yes'` | `CJ-HUMANEVAL-141_l7_c004` |
| 8 | `    assert candidate('MY16FILE3.exe') == 'Yes'` | `CJ-HUMANEVAL-141_l8_c005` |
| 9 | `    assert candidate('His12FILE94.exe') == 'No'` | `CJ-HUMANEVAL-141_l9_c006` |
| 10 | `    assert candidate('_Y.txt') == 'No'` | `CJ-HUMANEVAL-141_l10_c007` |
| 11 | `    assert candidate('?aREYA.exe') == 'No'` | `CJ-HUMANEVAL-141_l11_c008` |
| 12 | `    assert candidate('/this_is_valid.dll') == 'No'` | `CJ-HUMANEVAL-141_l12_c009` |
| 13 | `    assert candidate('this_is_valid.wow') == 'No'` | `CJ-HUMANEVAL-141_l13_c010` |
| 14 | `    assert candidate('this_is_valid.txt') == 'Yes'` | `CJ-HUMANEVAL-141_l14_c011` |
| 15 | `    assert candidate('this_is_valid.txtexe') == 'No'` | `CJ-HUMANEVAL-141_l15_c012` |
| 16 | `    assert candidate('#this2_i4s_5valid.ten') == 'No'` | `CJ-HUMANEVAL-141_l16_c013` |
| 17 | `    assert candidate('@this1_is6_valid.exe') == 'No'` | `CJ-HUMANEVAL-141_l17_c014` |
| 18 | `    assert candidate('this_is_12valid.6exe4.txt') == 'No'` | `CJ-HUMANEVAL-141_l18_c015` |
| 19 | `    assert candidate('all.exe.txt') == 'No'` | `CJ-HUMANEVAL-141_l19_c016` |
| 20 | `    assert candidate('I563_No.exe') == 'Yes'` | `CJ-HUMANEVAL-141_l20_c017` |
| 21 | `    assert candidate('Is3youfault.txt') == 'Yes'` | `CJ-HUMANEVAL-141_l21_c018` |
| 22 | `    assert candidate('no_one#knows.dll') == 'Yes'` | `CJ-HUMANEVAL-141_l22_c019` |
| 23 | `    assert candidate('1I563_Yes3.exe') == 'No'` | `CJ-HUMANEVAL-141_l23_c020` |
| 24 | `    assert candidate('I563_Yes3.txtt') == 'No'` | `CJ-HUMANEVAL-141_l24_c021` |
| 25 | `    assert candidate('final..txt') == 'No'` | `CJ-HUMANEVAL-141_l25_c022` |
| 26 | `    assert candidate('final132') == 'No'` | `CJ-HUMANEVAL-141_l26_c023` |
| 27 | `    assert candidate('_f4indsartal132.') == 'No'` | `CJ-HUMANEVAL-141_l27_c024` |
| 28 | `    ` | `` |
| 29 | `        ` | `` |
| 30 | `` | `` |
| 31 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 32 | `    assert candidate('.txt') == 'No'` | `CJ-HUMANEVAL-141_l32_c025` |
| 33 | `    assert candidate('s.') == 'No'` | `CJ-HUMANEVAL-141_l33_c026` |
| 34 | `` | `` |
