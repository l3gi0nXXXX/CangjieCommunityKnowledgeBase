# Line Translation: CJ-HUMANEVAL-154

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    #assert True, "This prints if this assert fails 1 (good for debugging!)"` | `` |
| 5 | `` | `` |
| 6 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 7 | `    #assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 8 | `    assert  candidate("xyzw","xyw") == False , "test #0"` | `CJ-HUMANEVAL-154_l8_c001` |
| 9 | `    assert  candidate("yello","ell") == True , "test #1"` | `CJ-HUMANEVAL-154_l9_c002` |
| 10 | `    assert  candidate("whattup","ptut") == False , "test #2"` | `CJ-HUMANEVAL-154_l10_c003` |
| 11 | `    assert  candidate("efef","fee") == True , "test #3"` | `CJ-HUMANEVAL-154_l11_c004` |
| 12 | `    assert  candidate("abab","aabb") == False , "test #4"` | `CJ-HUMANEVAL-154_l12_c005` |
| 13 | `    assert  candidate("winemtt","tinem") == True , "test #5"` | `CJ-HUMANEVAL-154_l13_c006` |
| 14 | `` | `` |
