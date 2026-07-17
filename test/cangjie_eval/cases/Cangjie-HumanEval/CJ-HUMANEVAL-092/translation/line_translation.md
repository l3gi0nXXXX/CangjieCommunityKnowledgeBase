# Line Translation: CJ-HUMANEVAL-092

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

Python `int` and `float` identity is preserved with the existing tagged `EvalValue` adapter: an integer literal becomes `evalInt(Int64)` and a floating-point literal becomes `evalFloat(Float64)`. This is required because the official check distinguishes `candidate(3,4,7)` from `candidate(3.0,4,7)` through Python's `isinstance(value, int)` semantics.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(2, 3, 1)==True, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-092_l4_c001` (`evalInt(2), evalInt(3), evalInt(1)`) |
| 5 | `    assert candidate(2.5, 2, 3)==False, "This prints if this assert fails 2 (good for debugging!)"` | `CJ-HUMANEVAL-092_l5_c002` |
| 6 | `    assert candidate(1.5, 5, 3.5)==False, "This prints if this assert fails 3 (good for debugging!)"` | `CJ-HUMANEVAL-092_l6_c003` |
| 7 | `    assert candidate(2, 6, 2)==False, "This prints if this assert fails 4 (good for debugging!)"` | `CJ-HUMANEVAL-092_l7_c004` |
| 8 | `    assert candidate(4, 2, 2)==True, "This prints if this assert fails 5 (good for debugging!)"` | `CJ-HUMANEVAL-092_l8_c005` |
| 9 | `    assert candidate(2.2, 2.2, 2.2)==False, "This prints if this assert fails 6 (good for debugging!)"` | `CJ-HUMANEVAL-092_l9_c006` |
| 10 | `    assert candidate(-4, 6, 2)==True, "This prints if this assert fails 7 (good for debugging!)"` | `CJ-HUMANEVAL-092_l10_c007` |
| 11 | `` | `` |
| 12 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 13 | `    assert candidate(2,1,1)==True, "This prints if this assert fails 8 (also good for debugging!)"` | `CJ-HUMANEVAL-092_l13_c008` |
| 14 | `    assert candidate(3,4,7)==True, "This prints if this assert fails 9 (also good for debugging!)"` | `CJ-HUMANEVAL-092_l14_c009` (`evalInt(3), evalInt(4), evalInt(7)`) |
| 15 | `    assert candidate(3.0,4,7)==False, "This prints if this assert fails 10 (also good for debugging!)"` | `CJ-HUMANEVAL-092_l15_c010` (`evalFloat(3.0), evalInt(4), evalInt(7)`) |
| 16 | `` | `` |
