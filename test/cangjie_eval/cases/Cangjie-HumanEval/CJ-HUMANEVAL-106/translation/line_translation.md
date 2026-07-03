# Line Translation: CJ-HUMANEVAL-106

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    assert candidate(5) == [1, 2, 6, 24, 15]` | `CJ-HUMANEVAL-106_l3_c001` |
| 4 | `    assert candidate(7) == [1, 2, 6, 24, 15, 720, 28]` | `CJ-HUMANEVAL-106_l4_c002` |
| 5 | `    assert candidate(1) == [1]` | `CJ-HUMANEVAL-106_l5_c003` |
| 6 | `    assert candidate(3) == [1, 2, 6]` | `CJ-HUMANEVAL-106_l6_c004` |
