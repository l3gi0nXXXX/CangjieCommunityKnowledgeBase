# Line Translation: CJ-HUMANEVAL-149

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(["aa", "a", "aaa"]) == ["aa"]` | `CJ-HUMANEVAL-149_l4_c001` |
| 5 | `    assert candidate(["school", "AI", "asdf", "b"]) == ["AI", "asdf", "school"]` | `CJ-HUMANEVAL-149_l5_c002` |
| 6 | `    assert candidate(["d", "b", "c", "a"]) == []` | `CJ-HUMANEVAL-149_l6_c003` |
| 7 | `    assert candidate(["d", "dcba", "abcd", "a"]) == ["abcd", "dcba"]` | `CJ-HUMANEVAL-149_l7_c004` |
| 8 | `` | `` |
| 9 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 10 | `    assert candidate(["AI", "ai", "au"]) == ["AI", "ai", "au"]` | `CJ-HUMANEVAL-149_l10_c005` |
| 11 | `    assert candidate(["a", "b", "b", "c", "c", "a"]) == []` | `CJ-HUMANEVAL-149_l11_c006` |
| 12 | `    assert candidate(['aaaa', 'bbbb', 'dd', 'cc']) == ["cc", "dd", "aaaa", "bbbb"]` | `CJ-HUMANEVAL-149_l12_c007` |
| 13 | `` | `` |
