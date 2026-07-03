# Line Translation: CJ-HUMANEVAL-111

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate('a b b a') == {'a':2,'b': 2}, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-111_l4_c001` |
| 5 | `    assert candidate('a b c a b') == {'a': 2, 'b': 2}, "This prints if this assert fails 2 (good for debugging!)"` | `CJ-HUMANEVAL-111_l5_c002` |
| 6 | `    assert candidate('a b c d g') == {'a': 1, 'b': 1, 'c': 1, 'd': 1, 'g': 1}, "This prints if this assert fails 3 (good for debugging!)"` | `CJ-HUMANEVAL-111_l6_c003` |
| 7 | `    assert candidate('r t g') == {'r': 1,'t': 1,'g': 1}, "This prints if this assert fails 4 (good for debugging!)"` | `CJ-HUMANEVAL-111_l7_c004` |
| 8 | `    assert candidate('b b b b a') == {'b': 4}, "This prints if this assert fails 5 (good for debugging!)"` | `CJ-HUMANEVAL-111_l8_c005` |
| 9 | `    assert candidate('r t g') == {'r': 1,'t': 1,'g': 1}, "This prints if this assert fails 6 (good for debugging!)"` | `CJ-HUMANEVAL-111_l9_c006` |
| 10 | `    ` | `` |
| 11 | `    ` | `` |
| 12 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 13 | `    assert candidate('') == {}, "This prints if this assert fails 7 (also good for debugging!)"` | `CJ-HUMANEVAL-111_l13_c007` |
| 14 | `    assert candidate('a') == {'a': 1}, "This prints if this assert fails 8 (also good for debugging!)"` | `CJ-HUMANEVAL-111_l14_c008` |
| 15 | `` | `` |
