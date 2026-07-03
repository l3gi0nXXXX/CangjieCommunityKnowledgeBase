# Line Translation: CJ-HUMANEVAL-150

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(7, 34, 12) == 34` | `CJ-HUMANEVAL-150_l4_c001` |
| 5 | `    assert candidate(15, 8, 5) == 5` | `CJ-HUMANEVAL-150_l5_c002` |
| 6 | `    assert candidate(3, 33, 5212) == 33` | `CJ-HUMANEVAL-150_l6_c003` |
| 7 | `    assert candidate(1259, 3, 52) == 3` | `CJ-HUMANEVAL-150_l7_c004` |
| 8 | `    assert candidate(7919, -1, 12) == -1` | `CJ-HUMANEVAL-150_l8_c005` |
| 9 | `    assert candidate(3609, 1245, 583) == 583` | `CJ-HUMANEVAL-150_l9_c006` |
| 10 | `    assert candidate(91, 56, 129) == 129` | `CJ-HUMANEVAL-150_l10_c007` |
| 11 | `    assert candidate(6, 34, 1234) == 1234` | `CJ-HUMANEVAL-150_l11_c008` |
| 12 | `    ` | `` |
| 13 | `` | `` |
| 14 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 15 | `    assert candidate(1, 2, 0) == 0` | `CJ-HUMANEVAL-150_l15_c009` |
| 16 | `    assert candidate(2, 2, 0) == 2` | `CJ-HUMANEVAL-150_l16_c010` |
| 17 | `` | `` |
