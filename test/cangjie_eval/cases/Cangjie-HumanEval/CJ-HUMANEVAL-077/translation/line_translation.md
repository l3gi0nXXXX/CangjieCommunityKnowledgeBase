# Line Translation: CJ-HUMANEVAL-077

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(1) == True, "First test error: " + str(candidate(1))` | `CJ-HUMANEVAL-077_l4_c001` |
| 5 | `    assert candidate(2) == False, "Second test error: " + str(candidate(2))` | `CJ-HUMANEVAL-077_l5_c002` |
| 6 | `    assert candidate(-1) == True, "Third test error: " + str(candidate(-1))` | `CJ-HUMANEVAL-077_l6_c003` |
| 7 | `    assert candidate(64) == True, "Fourth test error: " + str(candidate(64))` | `CJ-HUMANEVAL-077_l7_c004` |
| 8 | `    assert candidate(180) == False, "Fifth test error: " + str(candidate(180))` | `CJ-HUMANEVAL-077_l8_c005` |
| 9 | `    assert candidate(1000) == True, "Sixth test error: " + str(candidate(1000))` | `CJ-HUMANEVAL-077_l9_c006` |
| 10 | `` | `` |
| 11 | `` | `` |
| 12 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 13 | `    assert candidate(0) == True, "1st edge test error: " + str(candidate(0))` | `CJ-HUMANEVAL-077_l13_c007` |
| 14 | `    assert candidate(1729) == False, "2nd edge test error: " + str(candidate(1728))` | `CJ-HUMANEVAL-077_l14_c008` |
| 15 | `` | `` |
