# Line Translation: CJ-HUMANEVAL-155

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(7) == (0, 1)` | `CJ-HUMANEVAL-155_l4_c001` |
| 5 | `    assert candidate(-78) == (1, 1)` | `CJ-HUMANEVAL-155_l5_c002` |
| 6 | `    assert candidate(3452) == (2, 2)` | `CJ-HUMANEVAL-155_l6_c003` |
| 7 | `    assert candidate(346211) == (3, 3)` | `CJ-HUMANEVAL-155_l7_c004` |
| 8 | `    assert candidate(-345821) == (3, 3)` | `CJ-HUMANEVAL-155_l8_c005` |
| 9 | `    assert candidate(-2) == (1, 0)` | `CJ-HUMANEVAL-155_l9_c006` |
| 10 | `    assert candidate(-45347) == (2, 3)` | `CJ-HUMANEVAL-155_l10_c007` |
| 11 | `    assert candidate(0) == (1, 0)` | `CJ-HUMANEVAL-155_l11_c008` |
| 12 | `` | `` |
| 13 | `` | `` |
| 14 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 15 | `    assert True` | `` |
| 16 | `` | `` |
