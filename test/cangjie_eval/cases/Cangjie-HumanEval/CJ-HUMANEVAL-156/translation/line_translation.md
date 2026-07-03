# Line Translation: CJ-HUMANEVAL-156

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(19) == 'xix'` | `CJ-HUMANEVAL-156_l4_c001` |
| 5 | `    assert candidate(152) == 'clii'` | `CJ-HUMANEVAL-156_l5_c002` |
| 6 | `    assert candidate(251) == 'ccli'` | `CJ-HUMANEVAL-156_l6_c003` |
| 7 | `    assert candidate(426) == 'cdxxvi'` | `CJ-HUMANEVAL-156_l7_c004` |
| 8 | `    assert candidate(500) == 'd'` | `CJ-HUMANEVAL-156_l8_c005` |
| 9 | `    assert candidate(1) == 'i'` | `CJ-HUMANEVAL-156_l9_c006` |
| 10 | `    assert candidate(4) == 'iv'` | `CJ-HUMANEVAL-156_l10_c007` |
| 11 | `    assert candidate(43) == 'xliii'` | `CJ-HUMANEVAL-156_l11_c008` |
| 12 | `    assert candidate(90) == 'xc'` | `CJ-HUMANEVAL-156_l12_c009` |
| 13 | `    assert candidate(94) == 'xciv'` | `CJ-HUMANEVAL-156_l13_c010` |
| 14 | `    assert candidate(532) == 'dxxxii'` | `CJ-HUMANEVAL-156_l14_c011` |
| 15 | `    assert candidate(900) == 'cm'` | `CJ-HUMANEVAL-156_l15_c012` |
| 16 | `    assert candidate(994) == 'cmxciv'` | `CJ-HUMANEVAL-156_l16_c013` |
| 17 | `    assert candidate(1000) == 'm'` | `CJ-HUMANEVAL-156_l17_c014` |
| 18 | `` | `` |
| 19 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 20 | `    assert True` | `` |
| 21 | `` | `` |
