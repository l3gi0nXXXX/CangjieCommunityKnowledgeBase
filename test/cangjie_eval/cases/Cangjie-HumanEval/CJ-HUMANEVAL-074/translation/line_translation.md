# Line Translation: CJ-HUMANEVAL-074

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert True, "This prints if this assert fails 1 (good for debugging!)"` | `` |
| 5 | `    assert candidate([], []) == []` | `CJ-HUMANEVAL-074_l5_c001` |
| 6 | `    assert candidate(['hi', 'admin'], ['hi', 'hi']) == ['hi', 'hi']` | `CJ-HUMANEVAL-074_l6_c002` |
| 7 | `    assert candidate(['hi', 'admin'], ['hi', 'hi', 'admin', 'project']) == ['hi', 'admin']` | `CJ-HUMANEVAL-074_l7_c003` |
| 8 | `    assert candidate(['4'], ['1', '2', '3', '4', '5']) == ['4']` | `CJ-HUMANEVAL-074_l8_c004` |
| 9 | `    assert candidate(['hi', 'admin'], ['hI', 'Hi']) == ['hI', 'Hi']` | `CJ-HUMANEVAL-074_l9_c005` |
| 10 | `    assert candidate(['hi', 'admin'], ['hI', 'hi', 'hi']) == ['hI', 'hi', 'hi']` | `CJ-HUMANEVAL-074_l10_c006` |
| 11 | `    assert candidate(['hi', 'admin'], ['hI', 'hi', 'hii']) == ['hi', 'admin']` | `CJ-HUMANEVAL-074_l11_c007` |
| 12 | `` | `` |
| 13 | `` | `` |
| 14 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 15 | `    assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 16 | `    assert candidate([], ['this']) == []` | `CJ-HUMANEVAL-074_l16_c008` |
| 17 | `    assert candidate(['this'], []) == []` | `CJ-HUMANEVAL-074_l17_c009` |
| 18 | `` | `` |
