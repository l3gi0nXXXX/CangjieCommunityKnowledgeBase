# Line Translation: CJ-HUMANEVAL-102

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(12, 15) == 14` | `CJ-HUMANEVAL-102_l4_c001` |
| 5 | `    assert candidate(13, 12) == -1` | `CJ-HUMANEVAL-102_l5_c002` |
| 6 | `    assert candidate(33, 12354) == 12354` | `CJ-HUMANEVAL-102_l6_c003` |
| 7 | `    assert candidate(5234, 5233) == -1` | `CJ-HUMANEVAL-102_l7_c004` |
| 8 | `    assert candidate(6, 29) == 28` | `CJ-HUMANEVAL-102_l8_c005` |
| 9 | `    assert candidate(27, 10) == -1` | `CJ-HUMANEVAL-102_l9_c006` |
| 10 | `` | `` |
| 11 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 12 | `    assert candidate(7, 7) == -1` | `CJ-HUMANEVAL-102_l12_c007` |
| 13 | `    assert candidate(546, 546) == 546` | `CJ-HUMANEVAL-102_l13_c008` |
| 14 | `` | `` |
