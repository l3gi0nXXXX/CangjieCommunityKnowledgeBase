# Line Translation: CJ-HUMANEVAL-082

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate('Hello') == True` | `CJ-HUMANEVAL-082_l4_c001` |
| 5 | `    assert candidate('abcdcba') == True` | `CJ-HUMANEVAL-082_l5_c002` |
| 6 | `    assert candidate('kittens') == True` | `CJ-HUMANEVAL-082_l6_c003` |
| 7 | `    assert candidate('orange') == False` | `CJ-HUMANEVAL-082_l7_c004` |
| 8 | `    assert candidate('wow') == True` | `CJ-HUMANEVAL-082_l8_c005` |
| 9 | `    assert candidate('world') == True` | `CJ-HUMANEVAL-082_l9_c006` |
| 10 | `    assert candidate('MadaM') == True` | `CJ-HUMANEVAL-082_l10_c007` |
| 11 | `    assert candidate('Wow') == True` | `CJ-HUMANEVAL-082_l11_c008` |
| 12 | `    assert candidate('') == False` | `CJ-HUMANEVAL-082_l12_c009` |
| 13 | `    assert candidate('HI') == True` | `CJ-HUMANEVAL-082_l13_c010` |
| 14 | `    assert candidate('go') == True` | `CJ-HUMANEVAL-082_l14_c011` |
| 15 | `    assert candidate('gogo') == False` | `CJ-HUMANEVAL-082_l15_c012` |
| 16 | `    assert candidate('aaaaaaaaaaaaaaa') == False` | `CJ-HUMANEVAL-082_l16_c013` |
| 17 | `` | `` |
| 18 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 19 | `    assert candidate('Madam') == True` | `CJ-HUMANEVAL-082_l19_c014` |
| 20 | `    assert candidate('M') == False` | `CJ-HUMANEVAL-082_l20_c015` |
| 21 | `    assert candidate('0') == False` | `CJ-HUMANEVAL-082_l21_c016` |
| 22 | `` | `` |
