# Line Translation: CJ-HUMANEVAL-086

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate('Hi') == 'Hi'` | `CJ-HUMANEVAL-086_l4_c001` |
| 5 | `    assert candidate('hello') == 'ehllo'` | `CJ-HUMANEVAL-086_l5_c002` |
| 6 | `    assert candidate('number') == 'bemnru'` | `CJ-HUMANEVAL-086_l6_c003` |
| 7 | `    assert candidate('abcd') == 'abcd'` | `CJ-HUMANEVAL-086_l7_c004` |
| 8 | `    assert candidate('Hello World!!!') == 'Hello !!!Wdlor'` | `CJ-HUMANEVAL-086_l8_c005` |
| 9 | `    assert candidate('') == ''` | `CJ-HUMANEVAL-086_l9_c006` |
| 10 | `    assert candidate('Hi. My name is Mister Robot. How are you?') == '.Hi My aemn is Meirst .Rboot How aer ?ouy'` | `CJ-HUMANEVAL-086_l10_c007` |
| 11 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 12 | `    assert True` | `` |
| 13 | `` | `` |
