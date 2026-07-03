# Line Translation: CJ-HUMANEVAL-163

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(2, 10) == [2, 4, 6, 8], "Test 1"` | `CJ-HUMANEVAL-163_l4_c001` |
| 5 | `    assert candidate(10, 2) == [2, 4, 6, 8], "Test 2"` | `CJ-HUMANEVAL-163_l5_c002` |
| 6 | `    assert candidate(132, 2) == [2, 4, 6, 8], "Test 3"` | `CJ-HUMANEVAL-163_l6_c003` |
| 7 | `    assert candidate(17,89) == [], "Test 4"` | `CJ-HUMANEVAL-163_l7_c004` |
| 8 | `` | `` |
| 9 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 10 | `    assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 11 | `` | `` |
