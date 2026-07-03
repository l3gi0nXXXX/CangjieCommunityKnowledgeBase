# Line Translation: CJ-HUMANEVAL-070

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([1, 2, 3, 4]) == [1, 4, 2, 3]` | `CJ-HUMANEVAL-070_l4_c001` |
| 5 | `    assert candidate([5, 6, 7, 8, 9]) == [5, 9, 6, 8, 7]` | `CJ-HUMANEVAL-070_l5_c002` |
| 6 | `    assert candidate([1, 2, 3, 4, 5]) == [1, 5, 2, 4, 3]` | `CJ-HUMANEVAL-070_l6_c003` |
| 7 | `    assert candidate([5, 6, 7, 8, 9, 1]) == [1, 9, 5, 8, 6, 7]` | `CJ-HUMANEVAL-070_l7_c004` |
| 8 | `    assert candidate([5, 5, 5, 5]) == [5, 5, 5, 5]` | `CJ-HUMANEVAL-070_l8_c005` |
| 9 | `    assert candidate([]) == []` | `CJ-HUMANEVAL-070_l9_c006` |
| 10 | `    assert candidate([1,2,3,4,5,6,7,8]) == [1, 8, 2, 7, 3, 6, 4, 5]` | `CJ-HUMANEVAL-070_l10_c007` |
| 11 | `    assert candidate([0,2,2,2,5,5,-5,-5]) == [-5, 5, -5, 5, 0, 2, 2, 2]` | `CJ-HUMANEVAL-070_l11_c008` |
| 12 | `    assert candidate([111111]) == [111111]` | `CJ-HUMANEVAL-070_l12_c009` |
| 13 | `` | `` |
| 14 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 15 | `    assert True` | `` |
| 16 | `` | `` |
