# Line Translation: CJ-HUMANEVAL-037

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

The official assertions normalize `candidate(...)` with Python `tuple`, which accepts any iterable. Cangjie has no equivalent untyped iterable return contract here, so the public signature and assertions use the typed projection `ArrayList<Int64>`. This preserves every official integer and its order but does not claim arbitrary Python iterable return compatibility.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `METADATA = {}` | `` |
| 4 | `` | `` |
| 5 | `` | `` |
| 6 | `def check(candidate):` | `` |
| 7 | `    assert tuple(candidate([1, 2, 3])) == tuple([1, 2, 3])` | `CJ-HUMANEVAL-037_l7_c001` |
| 8 | `    assert tuple(candidate([5, 3, -5, 2, -3, 3, 9, 0, 123, 1, -10])) == tuple([-10, 3, -5, 2, -3, 3, 5, 0, 9, 1, 123])` | `CJ-HUMANEVAL-037_l8_c002` |
| 9 | `    assert tuple(candidate([5, 8, -12, 4, 23, 2, 3, 11, 12, -10])) == tuple([-12, 8, 3, 4, 5, 2, 12, 11, 23, -10])` | `CJ-HUMANEVAL-037_l9_c003` |
| 10 | `` | `` |
