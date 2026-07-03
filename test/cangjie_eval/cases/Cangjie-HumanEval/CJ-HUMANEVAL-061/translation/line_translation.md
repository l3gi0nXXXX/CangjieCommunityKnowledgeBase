# Line Translation: CJ-HUMANEVAL-061

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `METADATA = {}` | `` |
| 4 | `` | `` |
| 5 | `` | `` |
| 6 | `def check(candidate):` | `` |
| 7 | `    assert candidate("()")` | `CJ-HUMANEVAL-061_l7_c001` |
| 8 | `    assert candidate("(()())")` | `CJ-HUMANEVAL-061_l8_c002` |
| 9 | `    assert candidate("()()(()())()")` | `CJ-HUMANEVAL-061_l9_c003` |
| 10 | `    assert candidate("()()((()()())())(()()(()))")` | `CJ-HUMANEVAL-061_l10_c004` |
| 11 | `    assert not candidate("((()())))")` | `CJ-HUMANEVAL-061_l11_c005` |
| 12 | `    assert not candidate(")(()")` | `CJ-HUMANEVAL-061_l12_c006` |
| 13 | `    assert not candidate("(")` | `CJ-HUMANEVAL-061_l13_c007` |
| 14 | `    assert not candidate("((((")` | `CJ-HUMANEVAL-061_l14_c008` |
| 15 | `    assert not candidate(")")` | `CJ-HUMANEVAL-061_l15_c009` |
| 16 | `    assert not candidate("(()")` | `CJ-HUMANEVAL-061_l16_c010` |
| 17 | `    assert not candidate("()()(()())())(()")` | `CJ-HUMANEVAL-061_l17_c011` |
| 18 | `    assert not candidate("()()(()())()))()")` | `CJ-HUMANEVAL-061_l18_c012` |
| 19 | `` | `` |
