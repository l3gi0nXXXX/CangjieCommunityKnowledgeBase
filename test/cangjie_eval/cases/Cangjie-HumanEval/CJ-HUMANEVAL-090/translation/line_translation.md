# Line Translation: CJ-HUMANEVAL-090

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([1, 2, 3, 4, 5]) == 2` | `CJ-HUMANEVAL-090_l4_c001` |
| 5 | `    assert candidate([5, 1, 4, 3, 2]) == 2` | `CJ-HUMANEVAL-090_l5_c002` |
| 6 | `    assert candidate([]) == None` | `CJ-HUMANEVAL-090_l6_c003` |
| 7 | `    assert candidate([1, 1]) == None` | `CJ-HUMANEVAL-090_l7_c004` |
| 8 | `    assert candidate([1,1,1,1,0]) == 1` | `CJ-HUMANEVAL-090_l8_c005` |
| 9 | `    assert candidate([1, 0**0]) == None` | `CJ-HUMANEVAL-090_l9_c006` |
| 10 | `    assert candidate([-35, 34, 12, -45]) == -35` | `CJ-HUMANEVAL-090_l10_c007` |
| 11 | `` | `` |
| 12 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 13 | `    assert True` | `` |
| 14 | `` | `` |
