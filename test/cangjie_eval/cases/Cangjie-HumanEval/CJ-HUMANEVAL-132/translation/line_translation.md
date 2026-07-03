# Line Translation: CJ-HUMANEVAL-132

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate('[[]]') == True, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-132_l4_c001` |
| 5 | `    assert candidate('[]]]]]]][[[[[]') == False` | `CJ-HUMANEVAL-132_l5_c002` |
| 6 | `    assert candidate('[][]') == False` | `CJ-HUMANEVAL-132_l6_c003` |
| 7 | `    assert candidate(('[]')) == False` | `CJ-HUMANEVAL-132_l7_c004` |
| 8 | `    assert candidate('[[[[]]]]') == True` | `CJ-HUMANEVAL-132_l8_c005` |
| 9 | `    assert candidate('[]]]]]]]]]]') == False` | `CJ-HUMANEVAL-132_l9_c006` |
| 10 | `    assert candidate('[][][[]]') == True` | `CJ-HUMANEVAL-132_l10_c007` |
| 11 | `    assert candidate('[[]') == False` | `CJ-HUMANEVAL-132_l11_c008` |
| 12 | `    assert candidate('[]]') == False` | `CJ-HUMANEVAL-132_l12_c009` |
| 13 | `    assert candidate('[[]][[') == True` | `CJ-HUMANEVAL-132_l13_c010` |
| 14 | `    assert candidate('[[][]]') == True` | `CJ-HUMANEVAL-132_l14_c011` |
| 15 | `` | `` |
| 16 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 17 | `    assert candidate('') == False, "This prints if this assert fails 2 (also good for debugging!)"` | `CJ-HUMANEVAL-132_l17_c012` |
| 18 | `    assert candidate('[[[[[[[[') == False` | `CJ-HUMANEVAL-132_l18_c013` |
| 19 | `    assert candidate(']]]]]]]]') == False` | `CJ-HUMANEVAL-132_l19_c014` |
| 20 | `` | `` |
