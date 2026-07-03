# Line Translation: CJ-HUMANEVAL-084

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert True, "This prints if this assert fails 1 (good for debugging!)"` | `` |
| 5 | `    assert candidate(1000) == "1", "Error"` | `CJ-HUMANEVAL-084_l5_c001` |
| 6 | `    assert candidate(150) == "110", "Error"` | `CJ-HUMANEVAL-084_l6_c002` |
| 7 | `    assert candidate(147) == "1100", "Error"` | `CJ-HUMANEVAL-084_l7_c003` |
| 8 | `` | `` |
| 9 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 10 | `    assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 11 | `    assert candidate(333) == "1001", "Error"` | `CJ-HUMANEVAL-084_l11_c004` |
| 12 | `    assert candidate(963) == "10010", "Error"` | `CJ-HUMANEVAL-084_l12_c005` |
| 13 | `` | `` |
