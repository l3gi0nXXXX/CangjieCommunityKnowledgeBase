# Line Translation: CJ-HUMANEVAL-071

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

Oracle preservation: after the declared Python numeric-union adaptation to `Float64`, every official `==` assertion uses exact equality. No epsilon is introduced, and NaN is rejected.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(3, 4, 5) == 6.00, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-071_l4_c001` |
| 5 | `    assert candidate(1, 2, 10) == -1` | `CJ-HUMANEVAL-071_l5_c002` |
| 6 | `    assert candidate(4, 8, 5) == 8.18` | `CJ-HUMANEVAL-071_l6_c003` |
| 7 | `    assert candidate(2, 2, 2) == 1.73` | `CJ-HUMANEVAL-071_l7_c004` |
| 8 | `    assert candidate(1, 2, 3) == -1` | `CJ-HUMANEVAL-071_l8_c005` |
| 9 | `    assert candidate(10, 5, 7) == 16.25` | `CJ-HUMANEVAL-071_l9_c006` |
| 10 | `    assert candidate(2, 6, 3) == -1` | `CJ-HUMANEVAL-071_l10_c007` |
| 11 | `` | `` |
| 12 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 13 | `    assert candidate(1, 1, 1) == 0.43, "This prints if this assert fails 2 (also good for debugging!)"` | `CJ-HUMANEVAL-071_l13_c008` |
| 14 | `    assert candidate(2, 2, 10) == -1` | `CJ-HUMANEVAL-071_l14_c009` |
| 15 | `` | `` |
