# Line Translation: CJ-HUMANEVAL-104

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([15, 33, 1422, 1]) == [1, 15, 33]` | `CJ-HUMANEVAL-104_l4_c001` |
| 5 | `    assert candidate([152, 323, 1422, 10]) == []` | `CJ-HUMANEVAL-104_l5_c002` |
| 6 | `    assert candidate([12345, 2033, 111, 151]) == [111, 151]` | `CJ-HUMANEVAL-104_l6_c003` |
| 7 | `    assert candidate([135, 103, 31]) == [31, 135]` | `CJ-HUMANEVAL-104_l7_c004` |
| 8 | `` | `` |
| 9 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 10 | `    assert True` | `` |
| 11 | `` | `` |
