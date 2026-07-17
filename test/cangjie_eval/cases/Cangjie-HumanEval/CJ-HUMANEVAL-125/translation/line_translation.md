# Line Translation: CJ-HUMANEVAL-125

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

Oracle preservation: Python `list[str]` results use the `EvalValue` kind `string_list` and an ordered `ArrayList<String>` payload. The verifier compares kind, size, order, and every String element exactly. A scalar String containing JSON-like list text is not structurally equal. Integer results remain the distinct `int` kind.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    assert candidate("Hello world!") == ["Hello","world!"]` | `CJ-HUMANEVAL-125_l3_c001` |
| 4 | `    assert candidate("Hello,world!") == ["Hello","world!"]` | `CJ-HUMANEVAL-125_l4_c002` |
| 5 | `    assert candidate("Hello world,!") == ["Hello","world,!"]` | `CJ-HUMANEVAL-125_l5_c003` |
| 6 | `    assert candidate("Hello,Hello,world !") == ["Hello,Hello,world","!"]` | `CJ-HUMANEVAL-125_l6_c004` |
| 7 | `    assert candidate("abcdef") == 3` | `CJ-HUMANEVAL-125_l7_c005` |
| 8 | `    assert candidate("aaabb") == 2` | `CJ-HUMANEVAL-125_l8_c006` |
| 9 | `    assert candidate("aaaBb") == 1` | `CJ-HUMANEVAL-125_l9_c007` |
| 10 | `    assert candidate("") == 0` | `CJ-HUMANEVAL-125_l10_c008` |
