# Line Translation: CJ-HUMANEVAL-133

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([1,2,3])==14, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-133_l4_c001` |
| 5 | `    assert candidate([1.0,2,3])==14, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-133_l5_c002` |
| 6 | `    assert candidate([1,3,5,7])==84, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-133_l6_c003` |
| 7 | `    assert candidate([1.4,4.2,0])==29, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-133_l7_c004` |
| 8 | `    assert candidate([-2.4,1,1])==6, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-133_l8_c005` |
| 9 | `` | `` |
| 10 | `    assert candidate([100,1,15,2])==10230, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-133_l10_c006` |
| 11 | `    assert candidate([10000,10000])==200000000, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-133_l11_c007` |
| 12 | `    assert candidate([-1.4,4.6,6.3])==75, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-133_l12_c008` |
| 13 | `    assert candidate([-1.4,17.9,18.9,19.9])==1086, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-133_l13_c009` |
| 14 | `` | `` |
| 15 | `` | `` |
| 16 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 17 | `    assert candidate([0])==0, "This prints if this assert fails 2 (also good for debugging!)"` | `CJ-HUMANEVAL-133_l17_c010` |
| 18 | `    assert candidate([-1])==1, "This prints if this assert fails 2 (also good for debugging!)"` | `CJ-HUMANEVAL-133_l18_c011` |
| 19 | `    assert candidate([-1,1,0])==2, "This prints if this assert fails 2 (also good for debugging!)"` | `CJ-HUMANEVAL-133_l19_c012` |
| 20 | `` | `` |
