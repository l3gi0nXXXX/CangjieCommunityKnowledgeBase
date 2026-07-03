# Line Translation: CJ-HUMANEVAL-001

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
| 10 | `    assert candidate('(()()) ((())) () ((())()())') == [` | `CJ-HUMANEVAL-001_l10_c001` |
| 11 | `        '(()())', '((()))', '()', '((())()())'` | `` |
| 12 | `    ]` | `` |
| 13 | `    assert candidate('() (()) ((())) (((())))') == [` | `CJ-HUMANEVAL-001_l13_c002` |
| 14 | `        '()', '(())', '((()))', '(((())))'` | `` |
| 15 | `    ]` | `` |
| 16 | `    assert candidate('(()(())((())))') == [` | `CJ-HUMANEVAL-001_l16_c003` |
| 17 | `        '(()(())((())))'` | `` |
| 18 | `    ]` | `` |
| 19 | `    assert candidate('( ) (( )) (( )( ))') == ['()', '(())', '(()())']` | `CJ-HUMANEVAL-001_l19_c004` |
