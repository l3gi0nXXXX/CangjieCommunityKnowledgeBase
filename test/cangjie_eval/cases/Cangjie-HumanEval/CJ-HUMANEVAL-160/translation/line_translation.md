# Line Translation: CJ-HUMANEVAL-160

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Static-Language Adaptation

Python integer operands and intermediate values are projected to `std.math.numeric.BigInt`. Cangjie `BigInt /` truncates toward zero, so Python `//` requires a remainder/sign floor correction. `BigInt **` accepts `UInt64`; conversion is valid only after proving the non-negative exponent is representable, otherwise a BigInt-exponent square-and-multiply helper preserves the source semantics. Only the final expression result is narrowed with `toInt64()`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate(['**', '*', '+'], [2, 3, 4, 5]) == 37` | `CJ-HUMANEVAL-160_l4_c001` |
| 5 | `    assert candidate(['+', '*', '-'], [2, 3, 4, 5]) == 9` | `CJ-HUMANEVAL-160_l5_c002` |
| 6 | `    assert candidate(['//', '*'], [7, 3, 4]) == 8, "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-160_l6_c003` |
| 7 | `` | `` |
| 8 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 9 | `    assert True, "This prints if this assert fails 2 (also good for debugging!)"` | `` |
| 10 | `` | `` |
