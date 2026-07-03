# Line Translation: CJ-HUMANEVAL-076

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(16, 2)== True, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-076_l4_c001` |
| 5 | `    assert candidate(143214, 16)== False, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-076_l5_c002` |
| 6 | `    assert candidate(4, 2)==True, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-076_l6_c003` |
| 7 | `    assert candidate(9, 3)==True, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-076_l7_c004` |
| 8 | `    assert candidate(16, 4)==True, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-076_l8_c005` |
| 9 | `    assert candidate(24, 2)==False, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-076_l9_c006` |
| 10 | `    assert candidate(128, 4)==False, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-076_l10_c007` |
| 11 | `    assert candidate(12, 6)==False, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-076_l11_c008` |
| 12 | `` | `` |
| 13 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 14 | `    assert candidate(1, 1)==True, "This prints if this assert fails 2 (also good for debugging!)"` | `CJ-HUMANEVAL-076_l14_c009` |
| 15 | `    assert candidate(1, 12)==True, "This prints if this assert fails 2 (also good for debugging!)"` | `CJ-HUMANEVAL-076_l15_c010` |
| 16 | `` | `` |
