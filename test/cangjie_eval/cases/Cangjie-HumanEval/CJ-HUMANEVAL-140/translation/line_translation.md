# Line Translation: CJ-HUMANEVAL-140

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate("Example") == "Example", "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-140_l4_c001` |
| 5 | `    assert candidate("Mudasir Hanif ") == "Mudasir_Hanif_", "This prints if this assert fails 2 (good for debugging!)"` | `CJ-HUMANEVAL-140_l5_c002` |
| 6 | `    assert candidate("Yellow Yellow  Dirty  Fellow") == "Yellow_Yellow__Dirty__Fellow", "This prints if this assert fails 3 (good for debugging!)"` | `CJ-HUMANEVAL-140_l6_c003` |
| 7 | `    ` | `` |
| 8 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 9 | `    assert candidate("Exa   mple") == "Exa-mple", "This prints if this assert fails 4 (good for debugging!)"` | `CJ-HUMANEVAL-140_l9_c004` |
| 10 | `    assert candidate("   Exa 1 2 2 mple") == "-Exa_1_2_2_mple", "This prints if this assert fails 4 (good for debugging!)"` | `CJ-HUMANEVAL-140_l10_c005` |
| 11 | `` | `` |
