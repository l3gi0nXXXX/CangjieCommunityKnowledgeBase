# Line Translation: CJ-HUMANEVAL-099

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate("10") == 10, "Test 1"` | `CJ-HUMANEVAL-099_l4_c001` |
| 5 | `    assert candidate("14.5") == 15, "Test 2"` | `CJ-HUMANEVAL-099_l5_c002` |
| 6 | `    assert candidate("-15.5") == -16, "Test 3"` | `CJ-HUMANEVAL-099_l6_c003` |
| 7 | `    assert candidate("15.3") == 15, "Test 3"` | `CJ-HUMANEVAL-099_l7_c004` |
| 8 | `` | `` |
| 9 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 10 | `    assert candidate("0") == 0, "Test 0"` | `CJ-HUMANEVAL-099_l10_c005` |
| 11 | `` | `` |
