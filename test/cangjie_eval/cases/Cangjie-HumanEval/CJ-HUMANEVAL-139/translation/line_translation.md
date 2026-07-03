# Line Translation: CJ-HUMANEVAL-139

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(4) == 288, "Test 4"` | `CJ-HUMANEVAL-139_l4_c001` |
| 5 | `    assert candidate(5) == 34560, "Test 5"` | `CJ-HUMANEVAL-139_l5_c002` |
| 6 | `    assert candidate(7) == 125411328000, "Test 7"` | `CJ-HUMANEVAL-139_l6_c003` |
| 7 | `` | `` |
| 8 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 9 | `    assert candidate(1) == 1, "Test 1"` | `CJ-HUMANEVAL-139_l9_c004` |
| 10 | `` | `` |
