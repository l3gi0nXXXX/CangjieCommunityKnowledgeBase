# Line Translation: CJ-HUMANEVAL-101

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert True, "This prints if this assert fails 1 (good for debugging!)"` | `` |
| 5 | `    assert candidate("Hi, my name is John") == ["Hi", "my", "name", "is", "John"]` | `CJ-HUMANEVAL-101_l5_c001` |
| 6 | `    assert candidate("One, two, three, four, five, six") == ["One", "two", "three", "four", "five", "six"]` | `CJ-HUMANEVAL-101_l6_c002` |
| 7 | `    assert candidate("Hi, my name") == ["Hi", "my", "name"]` | `CJ-HUMANEVAL-101_l7_c003` |
| 8 | `    assert candidate("One,, two, three, four, five, six,") == ["One", "two", "three", "four", "five", "six"]` | `CJ-HUMANEVAL-101_l8_c004` |
| 9 | `` | `` |
| 10 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 11 | `    assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 12 | `    assert candidate("") == []` | `CJ-HUMANEVAL-101_l12_c005` |
| 13 | `    assert candidate("ahmed     , gamal") == ["ahmed", "gamal"]` | `CJ-HUMANEVAL-101_l13_c006` |
| 14 | `` | `` |

## Public Static-Language Boundary

The independently constructed public assertion `CJ-HUMANEVAL-101_public_unicode_whitespace_c007` verifies Rune-preserving tokenization across a comma, a newline, Unicode words, and emoji. `wordsStringSourceWhitespace(Rune)` additionally documents and exposes the complete source no-argument whitespace predicate, including Python's U+001C..U+001F behavior.
