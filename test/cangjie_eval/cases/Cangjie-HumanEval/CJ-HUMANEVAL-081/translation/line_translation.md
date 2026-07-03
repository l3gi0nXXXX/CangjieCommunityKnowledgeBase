# Line Translation: CJ-HUMANEVAL-081

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([4.0, 3, 1.7, 2, 3.5]) == ['A+', 'B', 'C-', 'C', 'A-']` | `CJ-HUMANEVAL-081_l4_c001` |
| 5 | `    assert candidate([1.2]) == ['D+']` | `CJ-HUMANEVAL-081_l5_c002` |
| 6 | `    assert candidate([0.5]) == ['D-']` | `CJ-HUMANEVAL-081_l6_c003` |
| 7 | `    assert candidate([0.0]) == ['E']` | `CJ-HUMANEVAL-081_l7_c004` |
| 8 | `    assert candidate([1, 0.3, 1.5, 2.8, 3.3]) == ['D', 'D-', 'C-', 'B', 'B+']` | `CJ-HUMANEVAL-081_l8_c005` |
| 9 | `    assert candidate([0, 0.7]) == ['E', 'D-']` | `CJ-HUMANEVAL-081_l9_c006` |
| 10 | `` | `` |
| 11 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 12 | `    assert True` | `` |
| 13 | `` | `` |
