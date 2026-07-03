# Line Translation: CJ-HUMANEVAL-089

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate('hi') == 'lm', "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-089_l4_c001` |
| 5 | `    assert candidate('asdfghjkl') == 'ewhjklnop', "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-089_l5_c002` |
| 6 | `    assert candidate('gf') == 'kj', "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-089_l6_c003` |
| 7 | `    assert candidate('et') == 'ix', "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-089_l7_c004` |
| 8 | `` | `` |
| 9 | `    assert candidate('faewfawefaewg')=='jeiajeaijeiak', "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-089_l9_c005` |
| 10 | `    assert candidate('hellomyfriend')=='lippsqcjvmirh', "This prints if this assert fails 2 (good for debugging!)"` | `CJ-HUMANEVAL-089_l10_c006` |
| 11 | `    assert candidate('dxzdlmnilfuhmilufhlihufnmlimnufhlimnufhfucufh')=='hbdhpqrmpjylqmpyjlpmlyjrqpmqryjlpmqryjljygyjl', "This prints if this assert fails 3 (good for debugging!)"` | `CJ-HUMANEVAL-089_l11_c007` |
| 12 | `` | `` |
| 13 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 14 | `    assert candidate('a')=='e', "This prints if this assert fails 2 (also good for debugging!)"` | `CJ-HUMANEVAL-089_l14_c008` |
| 15 | `` | `` |
