# Line Translation: CJ-HUMANEVAL-066

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert True, "This prints if this assert fails 1 (good for debugging!)"` | `` |
| 5 | `    assert candidate("") == 0, "Error"` | `CJ-HUMANEVAL-066_l5_c001` |
| 6 | `    assert candidate("abAB") == 131, "Error"` | `CJ-HUMANEVAL-066_l6_c002` |
| 7 | `    assert candidate("abcCd") == 67, "Error"` | `CJ-HUMANEVAL-066_l7_c003` |
| 8 | `    assert candidate("helloE") == 69, "Error"` | `CJ-HUMANEVAL-066_l8_c004` |
| 9 | `    assert candidate("woArBld") == 131, "Error"` | `CJ-HUMANEVAL-066_l9_c005` |
| 10 | `    assert candidate("aAaaaXa") == 153, "Error"` | `CJ-HUMANEVAL-066_l10_c006` |
| 11 | `` | `` |
| 12 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 13 | `    assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 14 | `    assert candidate(" How are yOu?") == 151, "Error"` | `CJ-HUMANEVAL-066_l14_c007` |
| 15 | `    assert candidate("You arE Very Smart") == 327, "Error"` | `CJ-HUMANEVAL-066_l15_c008` |
| 16 | `` | `` |
