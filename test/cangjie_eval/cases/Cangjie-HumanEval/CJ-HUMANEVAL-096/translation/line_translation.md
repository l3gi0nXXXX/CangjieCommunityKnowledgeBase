# Line Translation: CJ-HUMANEVAL-096

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    assert candidate(5) == [2,3]` | `CJ-HUMANEVAL-096_l3_c001` |
| 4 | `    assert candidate(6) == [2,3,5]` | `CJ-HUMANEVAL-096_l4_c002` |
| 5 | `    assert candidate(7) == [2,3,5]` | `CJ-HUMANEVAL-096_l5_c003` |
| 6 | `    assert candidate(10) == [2,3,5,7]` | `CJ-HUMANEVAL-096_l6_c004` |
| 7 | `    assert candidate(0) == []` | `CJ-HUMANEVAL-096_l7_c005` |
| 8 | `    assert candidate(22) == [2,3,5,7,11,13,17,19]` | `CJ-HUMANEVAL-096_l8_c006` |
| 9 | `    assert candidate(1) == []` | `CJ-HUMANEVAL-096_l9_c007` |
| 10 | `    assert candidate(18) == [2,3,5,7,11,13,17]` | `CJ-HUMANEVAL-096_l10_c008` |
| 11 | `    assert candidate(47) == [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43]` | `CJ-HUMANEVAL-096_l11_c009` |
| 12 | `    assert candidate(101) == [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97]` | `CJ-HUMANEVAL-096_l12_c010` |
| 13 | `` | `` |
