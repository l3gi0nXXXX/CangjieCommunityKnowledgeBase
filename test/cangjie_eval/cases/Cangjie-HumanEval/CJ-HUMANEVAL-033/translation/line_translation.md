# Line Translation: CJ-HUMANEVAL-033

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
| 7 | `    assert tuple(candidate([1, 2, 3])) == tuple(sort_third([1, 2, 3]))` | `CJ-HUMANEVAL-033_l7_c001` |
| 8 | `    assert tuple(candidate([5, 3, -5, 2, -3, 3, 9, 0, 123, 1, -10])) == tuple(sort_third([5, 3, -5, 2, -3, 3, 9, 0, 123, 1, -10]))` | `CJ-HUMANEVAL-033_l8_c002` |
| 9 | `    assert tuple(candidate([5, 8, -12, 4, 23, 2, 3, 11, 12, -10])) == tuple(sort_third([5, 8, -12, 4, 23, 2, 3, 11, 12, -10]))` | `CJ-HUMANEVAL-033_l9_c003` |
| 10 | `    assert tuple(candidate([5, 6, 3, 4, 8, 9, 2])) == tuple([2, 6, 3, 4, 8, 9, 5])` | `CJ-HUMANEVAL-033_l10_c004` |
| 11 | `    assert tuple(candidate([5, 8, 3, 4, 6, 9, 2])) == tuple([2, 8, 3, 4, 6, 9, 5])` | `CJ-HUMANEVAL-033_l11_c005` |
| 12 | `    assert tuple(candidate([5, 6, 9, 4, 8, 3, 2])) == tuple([2, 6, 9, 4, 8, 3, 5])` | `CJ-HUMANEVAL-033_l12_c006` |
| 13 | `    assert tuple(candidate([5, 6, 3, 4, 8, 9, 2, 1])) == tuple([2, 6, 3, 4, 8, 9, 5, 1])` | `CJ-HUMANEVAL-033_l13_c007` |
| 14 | `` | `` |
