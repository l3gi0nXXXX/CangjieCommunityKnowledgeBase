# Line Translation: CJ-HUMANEVAL-072

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([3, 2, 3], 9) is True` | `CJ-HUMANEVAL-072_l4_c001` |
| 5 | `    assert candidate([1, 2], 5) is False` | `CJ-HUMANEVAL-072_l5_c002` |
| 6 | `    assert candidate([3], 5) is True` | `CJ-HUMANEVAL-072_l6_c003` |
| 7 | `    assert candidate([3, 2, 3], 1) is False` | `CJ-HUMANEVAL-072_l7_c004` |
| 8 | `` | `` |
| 9 | `` | `` |
| 10 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 11 | `    assert candidate([1, 2, 3], 6) is False` | `CJ-HUMANEVAL-072_l11_c005` |
| 12 | `    assert candidate([5], 5) is True` | `CJ-HUMANEVAL-072_l12_c006` |
| 13 | `` | `` |
