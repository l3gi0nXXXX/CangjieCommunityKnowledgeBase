# Line Translation: CJ-HUMANEVAL-025

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

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
| 10 | `    assert candidate(2) == [2]` | `CJ-HUMANEVAL-025_l10_c001` |
| 11 | `    assert candidate(4) == [2, 2]` | `CJ-HUMANEVAL-025_l11_c002` |
| 12 | `    assert candidate(8) == [2, 2, 2]` | `CJ-HUMANEVAL-025_l12_c003` |
| 13 | `    assert candidate(3 * 19) == [3, 19]` | `CJ-HUMANEVAL-025_l13_c004` |
| 14 | `    assert candidate(3 * 19 * 3 * 19) == [3, 3, 19, 19]` | `CJ-HUMANEVAL-025_l14_c005` |
| 15 | `    assert candidate(3 * 19 * 3 * 19 * 3 * 19) == [3, 3, 3, 19, 19, 19]` | `CJ-HUMANEVAL-025_l15_c006` |
| 16 | `    assert candidate(3 * 19 * 19 * 19) == [3, 19, 19, 19]` | `CJ-HUMANEVAL-025_l16_c007` |
| 17 | `    assert candidate(3 * 2 * 3) == [2, 3, 3]` | `CJ-HUMANEVAL-025_l17_c008` |
