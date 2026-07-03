# Line Translation: CJ-HUMANEVAL-137

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(1, 2) == 2` | `CJ-HUMANEVAL-137_l4_c001` |
| 5 | `    assert candidate(1, 2.5) == 2.5` | `CJ-HUMANEVAL-137_l5_c002` |
| 6 | `    assert candidate(2, 3) == 3` | `CJ-HUMANEVAL-137_l6_c003` |
| 7 | `    assert candidate(5, 6) == 6` | `CJ-HUMANEVAL-137_l7_c004` |
| 8 | `    assert candidate(1, "2,3") == "2,3"` | `CJ-HUMANEVAL-137_l8_c005` |
| 9 | `    assert candidate("5,1", "6") == "6"` | `CJ-HUMANEVAL-137_l9_c006` |
| 10 | `    assert candidate("1", "2") == "2"` | `CJ-HUMANEVAL-137_l10_c007` |
| 11 | `    assert candidate("1", 1) == None` | `CJ-HUMANEVAL-137_l11_c008` |
| 12 | `` | `` |
| 13 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 14 | `    assert True` | `` |
| 15 | `` | `` |
