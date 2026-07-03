# Line Translation: CJ-HUMANEVAL-134

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate("apple") == False` | `CJ-HUMANEVAL-134_l4_c001` |
| 5 | `    assert candidate("apple pi e") == True` | `CJ-HUMANEVAL-134_l5_c002` |
| 6 | `    assert candidate("eeeee") == False` | `CJ-HUMANEVAL-134_l6_c003` |
| 7 | `    assert candidate("A") == True` | `CJ-HUMANEVAL-134_l7_c004` |
| 8 | `    assert candidate("Pumpkin pie ") == False` | `CJ-HUMANEVAL-134_l8_c005` |
| 9 | `    assert candidate("Pumpkin pie 1") == False` | `CJ-HUMANEVAL-134_l9_c006` |
| 10 | `    assert candidate("") == False` | `CJ-HUMANEVAL-134_l10_c007` |
| 11 | `    assert candidate("eeeee e ") == False` | `CJ-HUMANEVAL-134_l11_c008` |
| 12 | `    assert candidate("apple pie") == False` | `CJ-HUMANEVAL-134_l12_c009` |
| 13 | `    assert candidate("apple pi e ") == False` | `CJ-HUMANEVAL-134_l13_c010` |
| 14 | `` | `` |
| 15 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 16 | `    assert True` | `` |
| 17 | `` | `` |
