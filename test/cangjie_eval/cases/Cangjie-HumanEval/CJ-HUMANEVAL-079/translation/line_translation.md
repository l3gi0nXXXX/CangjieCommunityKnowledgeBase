# Line Translation: CJ-HUMANEVAL-079

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(0) == "db0db"` | `CJ-HUMANEVAL-079_l4_c001` |
| 5 | `    assert candidate(32) == "db100000db"` | `CJ-HUMANEVAL-079_l5_c002` |
| 6 | `    assert candidate(103) == "db1100111db"` | `CJ-HUMANEVAL-079_l6_c003` |
| 7 | `    assert candidate(15) == "db1111db", "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-079_l7_c004` |
| 8 | `` | `` |
| 9 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 10 | `    assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 11 | `` | `` |
