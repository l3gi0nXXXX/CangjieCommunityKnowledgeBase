# Line Translation: CJ-HUMANEVAL-083

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert True, "This prints if this assert fails 1 (good for debugging!)"` | `` |
| 5 | `    assert candidate(1) == 1` | `CJ-HUMANEVAL-083_l5_c001` |
| 6 | `    assert candidate(2) == 18` | `CJ-HUMANEVAL-083_l6_c002` |
| 7 | `    assert candidate(3) == 180` | `CJ-HUMANEVAL-083_l7_c003` |
| 8 | `    assert candidate(4) == 1800` | `CJ-HUMANEVAL-083_l8_c004` |
| 9 | `    assert candidate(5) == 18000` | `CJ-HUMANEVAL-083_l9_c005` |
| 10 | `` | `` |
| 11 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 12 | `    assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 13 | `` | `` |
