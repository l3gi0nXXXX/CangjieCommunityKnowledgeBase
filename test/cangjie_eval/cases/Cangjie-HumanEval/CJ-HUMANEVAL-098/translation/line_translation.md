# Line Translation: CJ-HUMANEVAL-098

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate('aBCdEf')  == 1` | `CJ-HUMANEVAL-098_l4_c001` |
| 5 | `    assert candidate('abcdefg') == 0` | `CJ-HUMANEVAL-098_l5_c002` |
| 6 | `    assert candidate('dBBE') == 0` | `CJ-HUMANEVAL-098_l6_c003` |
| 7 | `    assert candidate('B')  == 0` | `CJ-HUMANEVAL-098_l7_c004` |
| 8 | `    assert candidate('U')  == 1` | `CJ-HUMANEVAL-098_l8_c005` |
| 9 | `    assert candidate('') == 0` | `CJ-HUMANEVAL-098_l9_c006` |
| 10 | `    assert candidate('EEEE') == 2` | `CJ-HUMANEVAL-098_l10_c007` |
| 11 | `` | `` |
| 12 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 13 | `    assert True` | `` |
| 14 | `` | `` |
