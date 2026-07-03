# Line Translation: CJ-HUMANEVAL-100

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(3) == [3, 5, 7], "Test 3"` | `CJ-HUMANEVAL-100_l4_c001` |
| 5 | `    assert candidate(4) == [4,6,8,10], "Test 4"` | `CJ-HUMANEVAL-100_l5_c002` |
| 6 | `    assert candidate(5) == [5, 7, 9, 11, 13]` | `CJ-HUMANEVAL-100_l6_c003` |
| 7 | `    assert candidate(6) == [6, 8, 10, 12, 14, 16]` | `CJ-HUMANEVAL-100_l7_c004` |
| 8 | `    assert candidate(8) == [8, 10, 12, 14, 16, 18, 20, 22]` | `CJ-HUMANEVAL-100_l8_c005` |
| 9 | `` | `` |
| 10 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 11 | `    assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 12 | `` | `` |
