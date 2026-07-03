# Line Translation: CJ-HUMANEVAL-146

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([5, -2, 1, -5]) == 0  ` | `CJ-HUMANEVAL-146_l4_c001` |
| 5 | `    assert candidate([15, -73, 14, -15]) == 1` | `CJ-HUMANEVAL-146_l5_c002` |
| 6 | `    assert candidate([33, -2, -3, 45, 21, 109]) == 2` | `CJ-HUMANEVAL-146_l6_c003` |
| 7 | `    assert candidate([43, -12, 93, 125, 121, 109]) == 4` | `CJ-HUMANEVAL-146_l7_c004` |
| 8 | `    assert candidate([71, -2, -33, 75, 21, 19]) == 3` | `CJ-HUMANEVAL-146_l8_c005` |
| 9 | `` | `` |
| 10 | `` | `` |
| 11 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 12 | `    assert candidate([1]) == 0              ` | `CJ-HUMANEVAL-146_l12_c006` |
| 13 | `    assert candidate([]) == 0                   ` | `CJ-HUMANEVAL-146_l13_c007` |
| 14 | `` | `` |
