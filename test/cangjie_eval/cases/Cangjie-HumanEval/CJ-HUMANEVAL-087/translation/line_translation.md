# Line Translation: CJ-HUMANEVAL-087

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([` | `CJ-HUMANEVAL-087_l4_c001` |
| 5 | `        [1,2,3,4,5,6],` | `` |
| 6 | `        [1,2,3,4,1,6],` | `` |
| 7 | `        [1,2,3,4,5,1]` | `` |
| 8 | `    ], 1) == [(0, 0), (1, 4), (1, 0), (2, 5), (2, 0)]` | `` |
| 9 | `    assert candidate([` | `CJ-HUMANEVAL-087_l9_c002` |
| 10 | `        [1,2,3,4,5,6],` | `` |
| 11 | `        [1,2,3,4,5,6],` | `` |
| 12 | `        [1,2,3,4,5,6],` | `` |
| 13 | `        [1,2,3,4,5,6],` | `` |
| 14 | `        [1,2,3,4,5,6],` | `` |
| 15 | `        [1,2,3,4,5,6]` | `` |
| 16 | `    ], 2) == [(0, 1), (1, 1), (2, 1), (3, 1), (4, 1), (5, 1)]` | `` |
| 17 | `    assert candidate([` | `CJ-HUMANEVAL-087_l17_c003` |
| 18 | `        [1,2,3,4,5,6],` | `` |
| 19 | `        [1,2,3,4,5,6],` | `` |
| 20 | `        [1,1,3,4,5,6],` | `` |
| 21 | `        [1,2,1,4,5,6],` | `` |
| 22 | `        [1,2,3,1,5,6],` | `` |
| 23 | `        [1,2,3,4,1,6],` | `` |
| 24 | `        [1,2,3,4,5,1]` | `` |
| 25 | `    ], 1) == [(0, 0), (1, 0), (2, 1), (2, 0), (3, 2), (3, 0), (4, 3), (4, 0), (5, 4), (5, 0), (6, 5), (6, 0)]` | `` |
| 26 | `    assert candidate([], 1) == []` | `CJ-HUMANEVAL-087_l26_c004` |
| 27 | `    assert candidate([[1]], 2) == []` | `CJ-HUMANEVAL-087_l27_c005` |
| 28 | `    assert candidate([[], [1], [1, 2, 3]], 3) == [(2, 2)]` | `CJ-HUMANEVAL-087_l28_c006` |
| 29 | `` | `` |
| 30 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 31 | `    assert True` | `` |
| 32 | `` | `` |
