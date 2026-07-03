# Line Translation: CJ-HUMANEVAL-131

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(5) == 5` | `CJ-HUMANEVAL-131_l4_c001` |
| 5 | `    assert candidate(54) == 5` | `CJ-HUMANEVAL-131_l5_c002` |
| 6 | `    assert candidate(120) ==1` | `CJ-HUMANEVAL-131_l6_c003` |
| 7 | `    assert candidate(5014) == 5` | `CJ-HUMANEVAL-131_l7_c004` |
| 8 | `    assert candidate(98765) == 315` | `CJ-HUMANEVAL-131_l8_c005` |
| 9 | `    assert candidate(5576543) == 2625` | `CJ-HUMANEVAL-131_l9_c006` |
| 10 | `` | `` |
| 11 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 12 | `    assert candidate(2468) == 0` | `CJ-HUMANEVAL-131_l12_c007` |
| 13 | `` | `` |
