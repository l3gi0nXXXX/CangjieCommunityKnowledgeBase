# Line Translation: CJ-HUMANEVAL-093

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate('TEST') == 'tgst', "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-093_l4_c001` |
| 5 | `    assert candidate('Mudasir') == 'mWDCSKR', "This prints if this assert fails 2 (good for debugging!)"` | `CJ-HUMANEVAL-093_l5_c002` |
| 6 | `    assert candidate('YES') == 'ygs', "This prints if this assert fails 3 (good for debugging!)"` | `CJ-HUMANEVAL-093_l6_c003` |
| 7 | `    ` | `` |
| 8 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 9 | `    assert candidate('This is a message') == 'tHKS KS C MGSSCGG', "This prints if this assert fails 2 (also good for debugging!)"` | `CJ-HUMANEVAL-093_l9_c004` |
| 10 | `    assert candidate("I DoNt KnOw WhAt tO WrItE") == 'k dQnT kNqW wHcT Tq wRkTg', "This prints if this assert fails 2 (also good for debugging!)"` | `CJ-HUMANEVAL-093_l10_c005` |
| 11 | `` | `` |
