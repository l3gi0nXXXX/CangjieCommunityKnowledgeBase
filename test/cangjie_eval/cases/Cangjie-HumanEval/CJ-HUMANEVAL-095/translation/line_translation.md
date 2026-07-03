# Line Translation: CJ-HUMANEVAL-095

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate({"p":"pineapple", "b":"banana"}) == True, "First test error: " + str(candidate({"p":"pineapple", "b":"banana"}))` | `CJ-HUMANEVAL-095_l4_c001` |
| 5 | `    assert candidate({"p":"pineapple", "A":"banana", "B":"banana"}) == False, "Second test error: " + str(candidate({"p":"pineapple", "A":"banana", "B":"banana"}))` | `CJ-HUMANEVAL-095_l5_c002` |
| 6 | `    assert candidate({"p":"pineapple", 5:"banana", "a":"apple"}) == False, "Third test error: " + str(candidate({"p":"pineapple", 5:"banana", "a":"apple"}))` | `CJ-HUMANEVAL-095_l6_c003` |
| 7 | `    assert candidate({"Name":"John", "Age":"36", "City":"Houston"}) == False, "Fourth test error: " + str(candidate({"Name":"John", "Age":"36", "City":"Houston"}))` | `CJ-HUMANEVAL-095_l7_c004` |
| 8 | `    assert candidate({"STATE":"NC", "ZIP":"12345" }) == True, "Fifth test error: " + str(candidate({"STATE":"NC", "ZIP":"12345" }))      ` | `CJ-HUMANEVAL-095_l8_c005` |
| 9 | `    assert candidate({"fruit":"Orange", "taste":"Sweet" }) == True, "Fourth test error: " + str(candidate({"fruit":"Orange", "taste":"Sweet" }))      ` | `CJ-HUMANEVAL-095_l9_c006` |
| 10 | `` | `` |
| 11 | `` | `` |
| 12 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 13 | `    assert candidate({}) == False, "1st edge test error: " + str(candidate({}))` | `CJ-HUMANEVAL-095_l13_c007` |
| 14 | `` | `` |
