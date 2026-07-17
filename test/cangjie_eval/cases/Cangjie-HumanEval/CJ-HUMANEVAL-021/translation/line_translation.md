# Line Translation: CJ-HUMANEVAL-021

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

Oracle preservation: Python list equality is translated to exact element-wise `Float64` equality. No epsilon is introduced, and NaN is rejected.

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
| 10 | `    assert candidate([2.0, 49.9]) == [0.0, 1.0]` | `CJ-HUMANEVAL-021_l10_c001` |
| 11 | `    assert candidate([100.0, 49.9]) == [1.0, 0.0]` | `CJ-HUMANEVAL-021_l11_c002` |
| 12 | `    assert candidate([1.0, 2.0, 3.0, 4.0, 5.0]) == [0.0, 0.25, 0.5, 0.75, 1.0]` | `CJ-HUMANEVAL-021_l12_c003` |
| 13 | `    assert candidate([2.0, 1.0, 5.0, 3.0, 4.0]) == [0.25, 0.0, 1.0, 0.5, 0.75]` | `CJ-HUMANEVAL-021_l13_c004` |
| 14 | `    assert candidate([12.0, 11.0, 15.0, 13.0, 14.0]) == [0.25, 0.0, 1.0, 0.5, 0.75]` | `CJ-HUMANEVAL-021_l14_c005` |
