# Line Translation: CJ-HUMANEVAL-019

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
| 10 | `    assert candidate('') == ''` | `CJ-HUMANEVAL-019_l10_c001` |
| 11 | `    assert candidate('three') == 'three'` | `CJ-HUMANEVAL-019_l11_c002` |
| 12 | `    assert candidate('three five nine') == 'three five nine'` | `CJ-HUMANEVAL-019_l12_c003` |
| 13 | `    assert candidate('five zero four seven nine eight') == 'zero four five seven eight nine'` | `CJ-HUMANEVAL-019_l13_c004` |
| 14 | `    assert candidate('six five four three two one zero') == 'zero one two three four five six'` | `CJ-HUMANEVAL-019_l14_c005` |
