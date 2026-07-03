# Line Translation: CJ-HUMANEVAL-085

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([4, 88]) == 88` | `CJ-HUMANEVAL-085_l4_c001` |
| 5 | `    assert candidate([4, 5, 6, 7, 2, 122]) == 122` | `CJ-HUMANEVAL-085_l5_c002` |
| 6 | `    assert candidate([4, 0, 6, 7]) == 0` | `CJ-HUMANEVAL-085_l6_c003` |
| 7 | `    assert candidate([4, 4, 6, 8]) == 12` | `CJ-HUMANEVAL-085_l7_c004` |
| 8 | `` | `` |
| 9 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 10 | `    ` | `` |
