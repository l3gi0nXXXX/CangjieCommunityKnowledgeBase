# Line Translation: CJ-HUMANEVAL-145

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([1, 11, -1, -11, -12]) == [-1, -11, 1, -12, 11]` | `CJ-HUMANEVAL-145_l4_c001` |
| 5 | `    assert candidate([1234,423,463,145,2,423,423,53,6,37,3457,3,56,0,46]) == [0, 2, 3, 6, 53, 423, 423, 423, 1234, 145, 37, 46, 56, 463, 3457]` | `CJ-HUMANEVAL-145_l5_c002` |
| 6 | `    assert candidate([]) == []` | `CJ-HUMANEVAL-145_l6_c003` |
| 7 | `    assert candidate([1, -11, -32, 43, 54, -98, 2, -3]) == [-3, -32, -98, -11, 1, 2, 43, 54]` | `CJ-HUMANEVAL-145_l7_c004` |
| 8 | `    assert candidate([1,2,3,4,5,6,7,8,9,10,11]) == [1, 10, 2, 11, 3, 4, 5, 6, 7, 8, 9]` | `CJ-HUMANEVAL-145_l8_c005` |
| 9 | `    assert candidate([0,6,6,-76,-21,23,4]) == [-76, -21, 0, 4, 23, 6, 6]` | `CJ-HUMANEVAL-145_l9_c006` |
| 10 | `` | `` |
| 11 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 12 | `    assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 13 | `` | `` |
