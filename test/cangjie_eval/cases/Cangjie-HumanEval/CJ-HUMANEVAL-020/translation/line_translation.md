# Line Translation: CJ-HUMANEVAL-020

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

Oracle preservation: Python tuple equality is translated to exact element-wise `Float64` equality. No epsilon is introduced, and NaN is rejected.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `METADATA = {` | `` |
| 4 | `    'author': 'jt',` | `` |
| 5 | `    'dataset': 'test'` | `` |
| 6 | `}` | `` |
| 7 | `` | `` |
| 8 | `` | `` |
| 9 | `def check(candidate):` | `` |
| 10 | `    assert candidate([1.0, 2.0, 3.9, 4.0, 5.0, 2.2]) == (3.9, 4.0)` | `CJ-HUMANEVAL-020_l10_c001` |
| 11 | `    assert candidate([1.0, 2.0, 5.9, 4.0, 5.0]) == (5.0, 5.9)` | `CJ-HUMANEVAL-020_l11_c002` |
| 12 | `    assert candidate([1.0, 2.0, 3.0, 4.0, 5.0, 2.2]) == (2.0, 2.2)` | `CJ-HUMANEVAL-020_l12_c003` |
| 13 | `    assert candidate([1.0, 2.0, 3.0, 4.0, 5.0, 2.0]) == (2.0, 2.0)` | `CJ-HUMANEVAL-020_l13_c004` |
| 14 | `    assert candidate([1.1, 2.2, 3.1, 4.1, 5.1]) == (2.2, 3.1)` | `CJ-HUMANEVAL-020_l14_c005` |
| 15 | `` | `` |
