# Line Translation: CJ-HUMANEVAL-110

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([1, 2, 3, 4], [1, 2, 3, 4]) == "YES"` | `CJ-HUMANEVAL-110_l4_c001` |
| 5 | `    assert candidate([1, 2, 3, 4], [1, 5, 3, 4]) == "NO"` | `CJ-HUMANEVAL-110_l5_c002` |
| 6 | `    assert candidate([1, 2, 3, 4], [2, 1, 4, 3]) == "YES" ` | `CJ-HUMANEVAL-110_l6_c003` |
| 7 | `    assert candidate([5, 7, 3], [2, 6, 4]) == "YES"` | `CJ-HUMANEVAL-110_l7_c004` |
| 8 | `    assert candidate([5, 7, 3], [2, 6, 3]) == "NO" ` | `CJ-HUMANEVAL-110_l8_c005` |
| 9 | `    assert candidate([3, 2, 6, 1, 8, 9], [3, 5, 5, 1, 1, 1]) == "NO"` | `CJ-HUMANEVAL-110_l9_c006` |
| 10 | `` | `` |
| 11 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 12 | `    assert candidate([100, 200], [200, 200]) == "YES"` | `CJ-HUMANEVAL-110_l12_c007` |
| 13 | `` | `` |
