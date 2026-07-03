# Line Translation: CJ-HUMANEVAL-105

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert True, "This prints if this assert fails 1 (good for debugging!)"` | `` |
| 5 | `    assert candidate([2, 1, 1, 4, 5, 8, 2, 3]) == ["Eight", "Five", "Four", "Three", "Two", "Two", "One", "One"], "Error"` | `CJ-HUMANEVAL-105_l5_c001` |
| 6 | `    assert candidate([]) == [], "Error"` | `CJ-HUMANEVAL-105_l6_c002` |
| 7 | `    assert candidate([1, -1 , 55]) == ['One'], "Error"` | `CJ-HUMANEVAL-105_l7_c003` |
| 8 | `` | `` |
| 9 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 10 | `    assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 11 | `    assert candidate([1, -1, 3, 2]) == ["Three", "Two", "One"]` | `CJ-HUMANEVAL-105_l11_c004` |
| 12 | `    assert candidate([9, 4, 8]) == ["Nine", "Eight", "Four"]` | `CJ-HUMANEVAL-105_l12_c005` |
| 13 | `` | `` |
