# Line Translation: CJ-HUMANEVAL-047

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

Oracle preservation: after the declared Python numeric-union adaptation to `Float64`, every official `==` assertion uses exact equality. No epsilon is introduced, and NaN is rejected.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `METADATA = {}` | `` |
| 4 | `` | `` |
| 5 | `` | `` |
| 6 | `def check(candidate):` | `` |
| 7 | `    assert candidate([3, 1, 2, 4, 5]) == 3` | `CJ-HUMANEVAL-047_l7_c001` |
| 8 | `    assert candidate([-10, 4, 6, 1000, 10, 20]) == 8.0` | `CJ-HUMANEVAL-047_l8_c002` |
| 9 | `    assert candidate([5]) == 5` | `CJ-HUMANEVAL-047_l9_c003` |
| 10 | `    assert candidate([6, 5]) == 5.5` | `CJ-HUMANEVAL-047_l10_c004` |
| 11 | `    assert candidate([8, 1, 3, 9, 9, 2, 7]) == 7 ` | `CJ-HUMANEVAL-047_l11_c005` |
| 12 | `` | `` |
