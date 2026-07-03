# Line Translation: CJ-HUMANEVAL-112

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    assert candidate("abcde","ae") == ('bcd',False)` | `CJ-HUMANEVAL-112_l3_c001` |
| 4 | `    assert candidate("abcdef", "b") == ('acdef',False)` | `CJ-HUMANEVAL-112_l4_c002` |
| 5 | `    assert candidate("abcdedcba","ab") == ('cdedc',True)` | `CJ-HUMANEVAL-112_l5_c003` |
| 6 | `    assert candidate("dwik","w") == ('dik',False)` | `CJ-HUMANEVAL-112_l6_c004` |
| 7 | `    assert candidate("a","a") == ('',True)` | `CJ-HUMANEVAL-112_l7_c005` |
| 8 | `    assert candidate("abcdedcba","") == ('abcdedcba',True)` | `CJ-HUMANEVAL-112_l8_c006` |
| 9 | `    assert candidate("abcdedcba","v") == ('abcdedcba',True)` | `CJ-HUMANEVAL-112_l9_c007` |
| 10 | `    assert candidate("vabba","v") == ('abba',True)` | `CJ-HUMANEVAL-112_l10_c008` |
| 11 | `    assert candidate("mamma", "mia") == ("", True)` | `CJ-HUMANEVAL-112_l11_c009` |
