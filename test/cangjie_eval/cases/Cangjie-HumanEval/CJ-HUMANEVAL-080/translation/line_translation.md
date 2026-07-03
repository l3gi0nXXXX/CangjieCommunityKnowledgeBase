# Line Translation: CJ-HUMANEVAL-080

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate("a") == False , "a"` | `CJ-HUMANEVAL-080_l4_c001` |
| 5 | `    assert candidate("aa") == False , "aa"` | `CJ-HUMANEVAL-080_l5_c002` |
| 6 | `    assert candidate("abcd") == True , "abcd"` | `CJ-HUMANEVAL-080_l6_c003` |
| 7 | `    assert candidate("aabb") == False , "aabb"` | `CJ-HUMANEVAL-080_l7_c004` |
| 8 | `    assert candidate("adb") == True , "adb"` | `CJ-HUMANEVAL-080_l8_c005` |
| 9 | `    assert candidate("xyy") == False , "xyy"` | `CJ-HUMANEVAL-080_l9_c006` |
| 10 | `    assert candidate("iopaxpoi") == True , "iopaxpoi"` | `CJ-HUMANEVAL-080_l10_c007` |
| 11 | `    assert candidate("iopaxioi") == False , "iopaxioi"` | `CJ-HUMANEVAL-080_l11_c008` |
