# Line Translation: CJ-HUMANEVAL-121

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([5, 8, 7, 1])    == 12` | `CJ-HUMANEVAL-121_l4_c001` |
| 5 | `    assert candidate([3, 3, 3, 3, 3]) == 9` | `CJ-HUMANEVAL-121_l5_c002` |
| 6 | `    assert candidate([30, 13, 24, 321]) == 0` | `CJ-HUMANEVAL-121_l6_c003` |
| 7 | `    assert candidate([5, 9]) == 5` | `CJ-HUMANEVAL-121_l7_c004` |
| 8 | `    assert candidate([2, 4, 8]) == 0` | `CJ-HUMANEVAL-121_l8_c005` |
| 9 | `    assert candidate([30, 13, 23, 32]) == 23` | `CJ-HUMANEVAL-121_l9_c006` |
| 10 | `    assert candidate([3, 13, 2, 9]) == 3` | `CJ-HUMANEVAL-121_l10_c007` |
| 11 | `` | `` |
| 12 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 13 | `` | `` |
