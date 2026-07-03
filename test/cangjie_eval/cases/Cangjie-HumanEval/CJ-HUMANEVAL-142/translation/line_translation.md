# Line Translation: CJ-HUMANEVAL-142

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    ` | `` |
| 5 | `    assert candidate([1,2,3]) == 6` | `CJ-HUMANEVAL-142_l5_c001` |
| 6 | `    assert candidate([1,4,9]) == 14` | `CJ-HUMANEVAL-142_l6_c002` |
| 7 | `    assert candidate([]) == 0` | `CJ-HUMANEVAL-142_l7_c003` |
| 8 | `    assert candidate([1,1,1,1,1,1,1,1,1]) == 9` | `CJ-HUMANEVAL-142_l8_c004` |
| 9 | `    assert candidate([-1,-1,-1,-1,-1,-1,-1,-1,-1]) == -3` | `CJ-HUMANEVAL-142_l9_c005` |
| 10 | `    assert candidate([0]) == 0` | `CJ-HUMANEVAL-142_l10_c006` |
| 11 | `    assert candidate([-1,-5,2,-1,-5]) == -126` | `CJ-HUMANEVAL-142_l11_c007` |
| 12 | `    assert candidate([-56,-99,1,0,-2]) == 3030` | `CJ-HUMANEVAL-142_l12_c008` |
| 13 | `    assert candidate([-1,0,0,0,0,0,0,0,-1]) == 0` | `CJ-HUMANEVAL-142_l13_c009` |
| 14 | `    assert candidate([-16, -9, -2, 36, 36, 26, -20, 25, -40, 20, -4, 12, -26, 35, 37]) == -14196` | `CJ-HUMANEVAL-142_l14_c010` |
| 15 | `    assert candidate([-1, -3, 17, -1, -15, 13, -1, 14, -14, -12, -5, 14, -14, 6, 13, 11, 16, 16, 4, 10]) == -1448` | `CJ-HUMANEVAL-142_l15_c011` |
| 16 | `    ` | `` |
| 17 | `    ` | `` |
| 18 | `    # Don't remove this line:` | `` |
