# CJ-HUMANEVAL-000: has_close_elements

- Source task: `HumanEval/0`
- Cangjie signature: `public func has_close_elements(numbers: ArrayList<Float64>, threshold: Float64): Bool`
- Test calls expanded from official HumanEval: `7`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def has_close_elements(numbers: List[float], threshold: float) -> bool:` | `public func has_close_elements(numbers: ArrayList<Float64>, threshold: Float64): Bool {` |
| 5 | `    """ Check if in given list of numbers, are any two numbers closer to each other than` | `//  Check if in given list of numbers, are any two numbers closer to each other than` |
| 6 | `    given threshold.` | `// given threshold.` |
| 7 | `    >>> has_close_elements([1.0, 2.0, 3.0], 0.5)` | `// Example: has_close_elements([1.0, 2.0, 3.0], 0.5)` |
| 8 | `    False` | `// False` |
| 9 | `    >>> has_close_elements([1.0, 2.8, 3.0, 4.0, 5.0, 2.0], 0.3)` | `// Example: has_close_elements([1.0, 2.8, 3.0, 4.0, 5.0, 2.0], 0.3)` |
| 10 | `    True` | `// True` |
| 11 | `    """` | `// ` |
