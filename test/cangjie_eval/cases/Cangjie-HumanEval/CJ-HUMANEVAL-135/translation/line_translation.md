# Line Translation: CJ-HUMANEVAL-135

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([1,2,4,3,5])==3` | `CJ-HUMANEVAL-135_l4_c001` |
| 5 | `    assert candidate([1,2,4,5])==-1` | `CJ-HUMANEVAL-135_l5_c002` |
| 6 | `    assert candidate([1,4,2,5,6,7,8,9,10])==2` | `CJ-HUMANEVAL-135_l6_c003` |
| 7 | `    assert candidate([4,8,5,7,3])==4` | `CJ-HUMANEVAL-135_l7_c004` |
| 8 | `` | `` |
| 9 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 10 | `    assert candidate([])==-1` | `CJ-HUMANEVAL-135_l10_c005` |
| 11 | `` | `` |
