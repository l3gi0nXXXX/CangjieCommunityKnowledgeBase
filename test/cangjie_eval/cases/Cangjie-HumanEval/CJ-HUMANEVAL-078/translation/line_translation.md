# Line Translation: CJ-HUMANEVAL-078

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate("AB") == 1, "First test error: " + str(candidate("AB"))      ` | `CJ-HUMANEVAL-078_l4_c001` |
| 5 | `    assert candidate("1077E") == 2, "Second test error: " + str(candidate("1077E"))  ` | `CJ-HUMANEVAL-078_l5_c002` |
| 6 | `    assert candidate("ABED1A33") == 4, "Third test error: " + str(candidate("ABED1A33"))      ` | `CJ-HUMANEVAL-078_l6_c003` |
| 7 | `    assert candidate("2020") == 2, "Fourth test error: " + str(candidate("2020"))  ` | `CJ-HUMANEVAL-078_l7_c004` |
| 8 | `    assert candidate("123456789ABCDEF0") == 6, "Fifth test error: " + str(candidate("123456789ABCDEF0"))      ` | `CJ-HUMANEVAL-078_l8_c005` |
| 9 | `    assert candidate("112233445566778899AABBCCDDEEFF00") == 12, "Sixth test error: " + str(candidate("112233445566778899AABBCCDDEEFF00"))  ` | `CJ-HUMANEVAL-078_l9_c006` |
| 10 | `` | `` |
| 11 | `` | `` |
| 12 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 13 | `    assert candidate([]) == 0` | `CJ-HUMANEVAL-078_l13_c007` |
| 14 | `` | `` |
