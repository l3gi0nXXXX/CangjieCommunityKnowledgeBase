# Line Translation: CJ-HUMANEVAL-157

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(3, 4, 5) == True, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-157_l4_c001` |
| 5 | `    assert candidate(1, 2, 3) == False` | `CJ-HUMANEVAL-157_l5_c002` |
| 6 | `    assert candidate(10, 6, 8) == True` | `CJ-HUMANEVAL-157_l6_c003` |
| 7 | `    assert candidate(2, 2, 2) == False` | `CJ-HUMANEVAL-157_l7_c004` |
| 8 | `    assert candidate(7, 24, 25) == True` | `CJ-HUMANEVAL-157_l8_c005` |
| 9 | `    assert candidate(10, 5, 7) == False` | `CJ-HUMANEVAL-157_l9_c006` |
| 10 | `    assert candidate(5, 12, 13) == True` | `CJ-HUMANEVAL-157_l10_c007` |
| 11 | `    assert candidate(15, 8, 17) == True` | `CJ-HUMANEVAL-157_l11_c008` |
| 12 | `    assert candidate(48, 55, 73) == True` | `CJ-HUMANEVAL-157_l12_c009` |
| 13 | `` | `` |
| 14 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 15 | `    assert candidate(1, 1, 1) == False, "This prints if this assert fails 2 (also good for debugging!)"` | `CJ-HUMANEVAL-157_l15_c010` |
| 16 | `    assert candidate(2, 2, 10) == False` | `CJ-HUMANEVAL-157_l16_c011` |
| 17 | `` | `` |
