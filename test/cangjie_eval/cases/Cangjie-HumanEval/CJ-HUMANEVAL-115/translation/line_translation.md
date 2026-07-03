# Line Translation: CJ-HUMANEVAL-115

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `    # Check some simple cases` | `` |
| 5 | `    assert True, "This prints if this assert fails 1 (good for debugging!)"` | `` |
| 6 | `    assert candidate([[0,0,1,0], [0,1,0,0], [1,1,1,1]], 1) == 6, "Error"` | `CJ-HUMANEVAL-115_l6_c001` |
| 7 | `    assert candidate([[0,0,1,1], [0,0,0,0], [1,1,1,1], [0,1,1,1]], 2) == 5, "Error"` | `CJ-HUMANEVAL-115_l7_c002` |
| 8 | `    assert candidate([[0,0,0], [0,0,0]], 5) == 0, "Error"` | `CJ-HUMANEVAL-115_l8_c003` |
| 9 | `` | `` |
| 10 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 11 | `    assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 12 | `    assert candidate([[1,1,1,1], [1,1,1,1]], 2) == 4, "Error"` | `CJ-HUMANEVAL-115_l12_c004` |
| 13 | `    assert candidate([[1,1,1,1], [1,1,1,1]], 9) == 2, "Error"` | `CJ-HUMANEVAL-115_l13_c005` |
| 14 | `` | `` |
