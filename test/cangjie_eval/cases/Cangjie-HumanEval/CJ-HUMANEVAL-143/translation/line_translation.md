# Line Translation: CJ-HUMANEVAL-143

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate("This is a test") == "is"` | `CJ-HUMANEVAL-143_l4_c001` |
| 5 | `    assert candidate("lets go for swimming") == "go for"` | `CJ-HUMANEVAL-143_l5_c002` |
| 6 | `    assert candidate("there is no place available here") == "there is no place"` | `CJ-HUMANEVAL-143_l6_c003` |
| 7 | `    assert candidate("Hi I am Hussein") == "Hi am Hussein"` | `CJ-HUMANEVAL-143_l7_c004` |
| 8 | `    assert candidate("go for it") == "go for it"` | `CJ-HUMANEVAL-143_l8_c005` |
| 9 | `` | `` |
| 10 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 11 | `    assert candidate("here") == ""` | `CJ-HUMANEVAL-143_l11_c006` |
| 12 | `    assert candidate("here is") == "is"` | `CJ-HUMANEVAL-143_l12_c007` |
| 13 | `` | `` |
