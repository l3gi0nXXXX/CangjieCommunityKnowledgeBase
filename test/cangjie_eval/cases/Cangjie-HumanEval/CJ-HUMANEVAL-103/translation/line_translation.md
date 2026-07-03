# Line Translation: CJ-HUMANEVAL-103

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(1, 5) == "0b11"` | `CJ-HUMANEVAL-103_l4_c001` |
| 5 | `    assert candidate(7, 13) == "0b1010"` | `CJ-HUMANEVAL-103_l5_c002` |
| 6 | `    assert candidate(964,977) == "0b1111001010"` | `CJ-HUMANEVAL-103_l6_c003` |
| 7 | `    assert candidate(996,997) == "0b1111100100"` | `CJ-HUMANEVAL-103_l7_c004` |
| 8 | `    assert candidate(560,851) == "0b1011000010"` | `CJ-HUMANEVAL-103_l8_c005` |
| 9 | `    assert candidate(185,546) == "0b101101110"` | `CJ-HUMANEVAL-103_l9_c006` |
| 10 | `    assert candidate(362,496) == "0b110101101"` | `CJ-HUMANEVAL-103_l10_c007` |
| 11 | `    assert candidate(350,902) == "0b1001110010"` | `CJ-HUMANEVAL-103_l11_c008` |
| 12 | `    assert candidate(197,233) == "0b11010111"` | `CJ-HUMANEVAL-103_l12_c009` |
| 13 | `` | `` |
| 14 | `` | `` |
| 15 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 16 | `    assert candidate(7, 5) == -1` | `CJ-HUMANEVAL-103_l16_c010` |
| 17 | `    assert candidate(5, 1) == -1` | `CJ-HUMANEVAL-103_l17_c011` |
| 18 | `    assert candidate(5, 5) == "0b101"` | `CJ-HUMANEVAL-103_l18_c012` |
| 19 | `` | `` |
