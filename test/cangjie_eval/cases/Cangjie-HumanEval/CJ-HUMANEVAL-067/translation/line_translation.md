# Line Translation: CJ-HUMANEVAL-067

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate("5 apples and 6 oranges",19) == 8` | `CJ-HUMANEVAL-067_l4_c001` |
| 5 | `    assert candidate("5 apples and 6 oranges",21) == 10` | `CJ-HUMANEVAL-067_l5_c002` |
| 6 | `    assert candidate("0 apples and 1 oranges",3) == 2` | `CJ-HUMANEVAL-067_l6_c003` |
| 7 | `    assert candidate("1 apples and 0 oranges",3) == 2` | `CJ-HUMANEVAL-067_l7_c004` |
| 8 | `    assert candidate("2 apples and 3 oranges",100) == 95` | `CJ-HUMANEVAL-067_l8_c005` |
| 9 | `    assert candidate("2 apples and 3 oranges",5) == 0` | `CJ-HUMANEVAL-067_l9_c006` |
| 10 | `    assert candidate("1 apples and 100 oranges",120) == 19` | `CJ-HUMANEVAL-067_l10_c007` |
