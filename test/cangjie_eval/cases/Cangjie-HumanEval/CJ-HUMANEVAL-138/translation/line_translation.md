# Line Translation: CJ-HUMANEVAL-138

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `    assert candidate(4) == False` | `CJ-HUMANEVAL-138_l2_c001` |
| 3 | `    assert candidate(6) == False` | `CJ-HUMANEVAL-138_l3_c002` |
| 4 | `    assert candidate(8) == True` | `CJ-HUMANEVAL-138_l4_c003` |
| 5 | `    assert candidate(10) == True` | `CJ-HUMANEVAL-138_l5_c004` |
| 6 | `    assert candidate(11) == False` | `CJ-HUMANEVAL-138_l6_c005` |
| 7 | `    assert candidate(12) == True` | `CJ-HUMANEVAL-138_l7_c006` |
| 8 | `    assert candidate(13) == False` | `CJ-HUMANEVAL-138_l8_c007` |
| 9 | `    assert candidate(16) == True` | `CJ-HUMANEVAL-138_l9_c008` |
