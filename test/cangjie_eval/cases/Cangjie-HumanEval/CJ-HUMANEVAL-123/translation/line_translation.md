# Line Translation: CJ-HUMANEVAL-123

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(14) == [1, 5, 7, 11, 13, 17]` | `CJ-HUMANEVAL-123_l4_c001` |
| 5 | `    assert candidate(5) == [1, 5]` | `CJ-HUMANEVAL-123_l5_c002` |
| 6 | `    assert candidate(12) == [1, 3, 5], "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-123_l6_c003` |
| 7 | `` | `` |
| 8 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 9 | `    assert candidate(1) == [1], "This prints if this assert fails 2 (also good for debugging!)"` | `CJ-HUMANEVAL-123_l9_c004` |
| 10 | `` | `` |
