# Line Translation: CJ-HUMANEVAL-044

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `METADATA = {}` | `` |
| 4 | `` | `` |
| 5 | `` | `` |
| 6 | `def check(candidate):` | `` |
| 7 | `    assert candidate(8, 3) == "22"` | `CJ-HUMANEVAL-044_l7_c001` |
| 8 | `    assert candidate(9, 3) == "100"` | `CJ-HUMANEVAL-044_l8_c002` |
| 9 | `    assert candidate(234, 2) == "11101010"` | `CJ-HUMANEVAL-044_l9_c003` |
| 10 | `    assert candidate(16, 2) == "10000"` | `CJ-HUMANEVAL-044_l10_c004` |
| 11 | `    assert candidate(8, 2) == "1000"` | `CJ-HUMANEVAL-044_l11_c005` |
| 12 | `    assert candidate(7, 2) == "111"` | `CJ-HUMANEVAL-044_l12_c006` |
| 13 | `    for x in range(2, 8):` | `` |
| 14 | `        assert candidate(x, x + 1) == str(x)` | `CJ-HUMANEVAL-044_l14_c007, CJ-HUMANEVAL-044_l14_c008, CJ-HUMANEVAL-044_l14_c009, CJ-HUMANEVAL-044_l14_c010, CJ-HUMANEVAL-044_l14_c011, CJ-HUMANEVAL-044_l14_c012` |
| 15 | `` | `` |
