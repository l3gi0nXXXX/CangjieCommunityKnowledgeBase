# Line Translation: CJ-HUMANEVAL-158

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert (candidate(["name", "of", "string"]) == "string"), "t1"` | `CJ-HUMANEVAL-158_l4_c001` |
| 5 | `    assert (candidate(["name", "enam", "game"]) == "enam"), 't2'` | `CJ-HUMANEVAL-158_l5_c002` |
| 6 | `    assert (candidate(["aaaaaaa", "bb", "cc"]) == "aaaaaaa"), 't3'` | `CJ-HUMANEVAL-158_l6_c003` |
| 7 | `    assert (candidate(["abc", "cba"]) == "abc"), 't4'` | `CJ-HUMANEVAL-158_l7_c004` |
| 8 | `    assert (candidate(["play", "this", "game", "of","footbott"]) == "footbott"), 't5'` | `CJ-HUMANEVAL-158_l8_c005` |
| 9 | `    assert (candidate(["we", "are", "gonna", "rock"]) == "gonna"), 't6'` | `CJ-HUMANEVAL-158_l9_c006` |
| 10 | `    assert (candidate(["we", "are", "a", "mad", "nation"]) == "nation"), 't7'` | `CJ-HUMANEVAL-158_l10_c007` |
| 11 | `    assert (candidate(["this", "is", "a", "prrk"]) == "this"), 't8'` | `CJ-HUMANEVAL-158_l11_c008` |
| 12 | `` | `` |
| 13 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 14 | `    assert (candidate(["b"]) == "b"), 't9'` | `CJ-HUMANEVAL-158_l14_c009` |
| 15 | `    assert (candidate(["play", "play", "play"]) == "play"), 't10'` | `CJ-HUMANEVAL-158_l15_c010` |
| 16 | `` | `` |
