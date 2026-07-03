# Line Translation: CJ-HUMANEVAL-065

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(100, 2) == "001"` | `CJ-HUMANEVAL-065_l4_c001` |
| 5 | `    assert candidate(12, 2) == "12"` | `CJ-HUMANEVAL-065_l5_c002` |
| 6 | `    assert candidate(97, 8) == "79"` | `CJ-HUMANEVAL-065_l6_c003` |
| 7 | `    assert candidate(12, 1) == "21", "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-065_l7_c004` |
| 8 | `` | `` |
| 9 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 10 | `    assert candidate(11, 101) == "11", "This prints if this assert fails 2 (also good for debugging!)"` | `CJ-HUMANEVAL-065_l10_c005` |
| 11 | `` | `` |
