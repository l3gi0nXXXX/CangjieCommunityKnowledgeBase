# Line Translation: CJ-HUMANEVAL-091

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate("Hello world") == 0, "Test 1"` | `CJ-HUMANEVAL-091_l4_c001` |
| 5 | `    assert candidate("Is the sky blue?") == 0, "Test 2"` | `CJ-HUMANEVAL-091_l5_c002` |
| 6 | `    assert candidate("I love It !") == 1, "Test 3"` | `CJ-HUMANEVAL-091_l6_c003` |
| 7 | `    assert candidate("bIt") == 0, "Test 4"` | `CJ-HUMANEVAL-091_l7_c004` |
| 8 | `    assert candidate("I feel good today. I will be productive. will kill It") == 2, "Test 5"` | `CJ-HUMANEVAL-091_l8_c005` |
| 9 | `    assert candidate("You and I are going for a walk") == 0, "Test 6"` | `CJ-HUMANEVAL-091_l9_c006` |
| 10 | `` | `` |
| 11 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 12 | `    assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 13 | `` | `` |
