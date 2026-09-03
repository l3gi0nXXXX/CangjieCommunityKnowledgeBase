# Line Translation: CJ-HUMANEVAL-151

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

Type-identity preservation: official integer literals and the integer range are translated with `evalInt`; official float literals are translated with `evalFloat`. The additional adaptation pair `evalInt(3)` / `evalFloat(3.0)` proves that equal numeric payloads retain the Python `int`/`float` distinction required by the canonical integer-type filter. Python bool is an int subtype: evalBool(true) projects to integer 1 and contributes 1, while evalBool(false) projects to integer 0 and contributes 0.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate([]) == 0 , "This prints if this assert fails 1 (good for debugging!)"` | `CJ-HUMANEVAL-151_l4_c001` |
| 5 | `    assert candidate([5, 4]) == 25 , "This prints if this assert fails 2 (good for debugging!)"` | `CJ-HUMANEVAL-151_l5_c002` |
| 6 | `    assert candidate([0.1, 0.2, 0.3]) == 0 , "This prints if this assert fails 3 (good for debugging!)"` | `CJ-HUMANEVAL-151_l6_c003` |
| 7 | `    assert candidate([-10, -20, -30]) == 0 , "This prints if this assert fails 4 (good for debugging!)"` | `CJ-HUMANEVAL-151_l7_c004` |
| 8 | `` | `` |
| 9 | `` | `` |
| 10 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 11 | `    assert candidate([-1, -2, 8]) == 0, "This prints if this assert fails 5 (also good for debugging!)"` | `CJ-HUMANEVAL-151_l11_c005` |
| 12 | `    assert candidate([0.2, 3, 5]) == 34, "This prints if this assert fails 6 (also good for debugging!)"` | `CJ-HUMANEVAL-151_l12_c006` |
| 13 | `    lst = list(range(-99, 100, 2))` | `` |
| 14 | `    odd_sum = sum([i**2 for i in lst if i%2!=0 and i > 0])` | `` |
| 15 | `    assert candidate(lst) == odd_sum , "This prints if this assert fails 7 (good for debugging!)"` | `CJ-HUMANEVAL-151_l15_c007` |
| 16 | `` | `` |

## Static-Adaptation Boundary Assertions

| Purpose | CangjieEval assertion | Expected |
|---|---|---:|
| Python integer identity | `double_the_difference([evalInt(3)])` | `9` |
| Python float identity with the same numeric payload | `double_the_difference([evalFloat(3.0)])` | `0` |
| Python `True` projected through the bool-as-int subtype rule | `double_the_difference([evalBool(true)])` | `1` |
| Python `False` projected through the bool-as-int subtype rule | `double_the_difference([evalBool(false)])` | `0` |
