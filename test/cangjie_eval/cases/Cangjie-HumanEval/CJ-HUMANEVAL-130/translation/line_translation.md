# Line Translation: CJ-HUMANEVAL-130

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    ` | `` |
| 5 | `    assert candidate(3) == [1, 3, 2.0, 8.0]` | `CJ-HUMANEVAL-130_l5_c001` |
| 6 | `    assert candidate(4) == [1, 3, 2.0, 8.0, 3.0]` | `CJ-HUMANEVAL-130_l6_c002` |
| 7 | `    assert candidate(5) == [1, 3, 2.0, 8.0, 3.0, 15.0]` | `CJ-HUMANEVAL-130_l7_c003` |
| 8 | `    assert candidate(6) == [1, 3, 2.0, 8.0, 3.0, 15.0, 4.0]` | `CJ-HUMANEVAL-130_l8_c004` |
| 9 | `    assert candidate(7) == [1, 3, 2.0, 8.0, 3.0, 15.0, 4.0, 24.0]` | `CJ-HUMANEVAL-130_l9_c005` |
| 10 | `    assert candidate(8) == [1, 3, 2.0, 8.0, 3.0, 15.0, 4.0, 24.0, 5.0]` | `CJ-HUMANEVAL-130_l10_c006` |
| 11 | `    assert candidate(9) == [1, 3, 2.0, 8.0, 3.0, 15.0, 4.0, 24.0, 5.0, 35.0]` | `CJ-HUMANEVAL-130_l11_c007` |
| 12 | `    assert candidate(20) == [1, 3, 2.0, 8.0, 3.0, 15.0, 4.0, 24.0, 5.0, 35.0, 6.0, 48.0, 7.0, 63.0, 8.0, 80.0, 9.0, 99.0, 10.0, 120.0, 11.0]` | `CJ-HUMANEVAL-130_l12_c008` |
| 13 | `` | `` |
| 14 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 15 | `    assert candidate(0) == [1]` | `CJ-HUMANEVAL-130_l15_c009` |
| 16 | `    assert candidate(1) == [1, 3]` | `CJ-HUMANEVAL-130_l16_c010` |
