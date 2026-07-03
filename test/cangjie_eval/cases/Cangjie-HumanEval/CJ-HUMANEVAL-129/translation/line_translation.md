# Line Translation: CJ-HUMANEVAL-129

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    print` | `` |
| 5 | `    assert candidate([[1, 2, 3], [4, 5, 6], [7, 8, 9]], 3) == [1, 2, 1]` | `CJ-HUMANEVAL-129_l5_c001` |
| 6 | `    assert candidate([[5, 9, 3], [4, 1, 6], [7, 8, 2]], 1) == [1]` | `CJ-HUMANEVAL-129_l6_c002` |
| 7 | `    assert candidate([[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12], [13, 14, 15, 16]], 4) == [1, 2, 1, 2]` | `CJ-HUMANEVAL-129_l7_c003` |
| 8 | `    assert candidate([[6, 4, 13, 10], [5, 7, 12, 1], [3, 16, 11, 15], [8, 14, 9, 2]], 7) == [1, 10, 1, 10, 1, 10, 1]` | `CJ-HUMANEVAL-129_l8_c004` |
| 9 | `    assert candidate([[8, 14, 9, 2], [6, 4, 13, 15], [5, 7, 1, 12], [3, 10, 11, 16]], 5) == [1, 7, 1, 7, 1]` | `CJ-HUMANEVAL-129_l9_c005` |
| 10 | `    assert candidate([[11, 8, 7, 2], [5, 16, 14, 4], [9, 3, 15, 6], [12, 13, 10, 1]], 9) == [1, 6, 1, 6, 1, 6, 1, 6, 1]` | `CJ-HUMANEVAL-129_l10_c006` |
| 11 | `    assert candidate([[12, 13, 10, 1], [9, 3, 15, 6], [5, 16, 14, 4], [11, 8, 7, 2]], 12) == [1, 6, 1, 6, 1, 6, 1, 6, 1, 6, 1, 6]` | `CJ-HUMANEVAL-129_l11_c007` |
| 12 | `    assert candidate([[2, 7, 4], [3, 1, 5], [6, 8, 9]], 8) == [1, 3, 1, 3, 1, 3, 1, 3]` | `CJ-HUMANEVAL-129_l12_c008` |
| 13 | `    assert candidate([[6, 1, 5], [3, 8, 9], [2, 7, 4]], 8) == [1, 5, 1, 5, 1, 5, 1, 5]` | `CJ-HUMANEVAL-129_l13_c009` |
| 14 | `` | `` |
| 15 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 16 | `    assert candidate([[1, 2], [3, 4]], 10) == [1, 2, 1, 2, 1, 2, 1, 2, 1, 2]` | `CJ-HUMANEVAL-129_l16_c010` |
| 17 | `    assert candidate([[1, 3], [3, 2]], 10) == [1, 3, 1, 3, 1, 3, 1, 3, 1, 3]` | `CJ-HUMANEVAL-129_l17_c011` |
| 18 | `` | `` |
