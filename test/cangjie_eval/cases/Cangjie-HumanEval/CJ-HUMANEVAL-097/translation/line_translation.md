# Line Translation: CJ-HUMANEVAL-097

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(148, 412) == 16, "First test error: " + str(candidate(148, 412))                    ` | `CJ-HUMANEVAL-097_l4_c001` |
| 5 | `    assert candidate(19, 28) == 72, "Second test error: " + str(candidate(19, 28))           ` | `CJ-HUMANEVAL-097_l5_c002` |
| 6 | `    assert candidate(2020, 1851) == 0, "Third test error: " + str(candidate(2020, 1851))` | `CJ-HUMANEVAL-097_l6_c003` |
| 7 | `    assert candidate(14,-15) == 20, "Fourth test error: " + str(candidate(14,-15))      ` | `CJ-HUMANEVAL-097_l7_c004` |
| 8 | `    assert candidate(76, 67) == 42, "Fifth test error: " + str(candidate(76, 67))      ` | `CJ-HUMANEVAL-097_l8_c005` |
| 9 | `    assert candidate(17, 27) == 49, "Sixth test error: " + str(candidate(17, 27))      ` | `CJ-HUMANEVAL-097_l9_c006` |
| 10 | `` | `` |
| 11 | `` | `` |
| 12 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 13 | `    assert candidate(0, 1) == 0, "1st edge test error: " + str(candidate(0, 1))` | `CJ-HUMANEVAL-097_l13_c007` |
| 14 | `    assert candidate(0, 0) == 0, "2nd edge test error: " + str(candidate(0, 0))` | `CJ-HUMANEVAL-097_l14_c008` |
| 15 | `` | `` |
