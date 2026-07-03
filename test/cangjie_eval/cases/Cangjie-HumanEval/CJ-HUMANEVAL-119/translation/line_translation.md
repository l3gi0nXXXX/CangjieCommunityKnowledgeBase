# Line Translation: CJ-HUMANEVAL-119

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(['()(', ')']) == 'Yes'` | `CJ-HUMANEVAL-119_l4_c001` |
| 5 | `    assert candidate([')', ')']) == 'No'` | `CJ-HUMANEVAL-119_l5_c002` |
| 6 | `    assert candidate(['(()(())', '())())']) == 'No'` | `CJ-HUMANEVAL-119_l6_c003` |
| 7 | `    assert candidate([')())', '(()()(']) == 'Yes'` | `CJ-HUMANEVAL-119_l7_c004` |
| 8 | `    assert candidate(['(())))', '(()())((']) == 'Yes'` | `CJ-HUMANEVAL-119_l8_c005` |
| 9 | `    assert candidate(['()', '())']) == 'No'` | `CJ-HUMANEVAL-119_l9_c006` |
| 10 | `    assert candidate(['(()(', '()))()']) == 'Yes'` | `CJ-HUMANEVAL-119_l10_c007` |
| 11 | `    assert candidate(['((((', '((())']) == 'No'` | `CJ-HUMANEVAL-119_l11_c008` |
| 12 | `    assert candidate([')(()', '(()(']) == 'No'` | `CJ-HUMANEVAL-119_l12_c009` |
| 13 | `    assert candidate([')(', ')(']) == 'No'` | `CJ-HUMANEVAL-119_l13_c010` |
| 14 | `    ` | `` |
| 15 | `` | `` |
| 16 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 17 | `    assert candidate(['(', ')']) == 'Yes'` | `CJ-HUMANEVAL-119_l17_c011` |
| 18 | `    assert candidate([')', '(']) == 'Yes' ` | `CJ-HUMANEVAL-119_l18_c012` |
| 19 | `` | `` |
