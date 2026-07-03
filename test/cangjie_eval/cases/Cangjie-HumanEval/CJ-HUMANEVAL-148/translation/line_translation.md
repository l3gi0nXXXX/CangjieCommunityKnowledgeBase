# Line Translation: CJ-HUMANEVAL-148

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate("Jupiter", "Neptune") == ("Saturn", "Uranus"), "First test error: " + str(len(candidate("Jupiter", "Neptune")))      ` | `CJ-HUMANEVAL-148_l4_c001` |
| 5 | `    assert candidate("Earth", "Mercury") == ("Venus",), "Second test error: " + str(candidate("Earth", "Mercury"))  ` | `CJ-HUMANEVAL-148_l5_c002` |
| 6 | `    assert candidate("Mercury", "Uranus") == ("Venus", "Earth", "Mars", "Jupiter", "Saturn"), "Third test error: " + str(candidate("Mercury", "Uranus"))      ` | `CJ-HUMANEVAL-148_l6_c003` |
| 7 | `    assert candidate("Neptune", "Venus") == ("Earth", "Mars", "Jupiter", "Saturn", "Uranus"), "Fourth test error: " + str(candidate("Neptune", "Venus"))  ` | `CJ-HUMANEVAL-148_l7_c004` |
| 8 | `` | `` |
| 9 | `` | `` |
| 10 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 11 | `    assert candidate("Earth", "Earth") == ()` | `CJ-HUMANEVAL-148_l11_c005` |
| 12 | `    assert candidate("Mars", "Earth") == ()` | `CJ-HUMANEVAL-148_l12_c006` |
| 13 | `    assert candidate("Jupiter", "Makemake") == ()` | `CJ-HUMANEVAL-148_l13_c007` |
| 14 | `` | `` |
