# CJ-HUMANEVAL-020: find_closest_elements

- Source task: `HumanEval/20`
- Cangjie signature: `public func find_closest_elements(numbers: ArrayList<Float64>): (Float64, Float64)`
- Test calls expanded from official HumanEval: `5`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List, Tuple` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def find_closest_elements(numbers: List[float]) -> Tuple[float, float]:` | `public func find_closest_elements(numbers: ArrayList<Float64>): (Float64, Float64) {` |
| 5 | `    """ From a supplied list of numbers (of length at least two) select and return two that are the closest to each` | `//  From a supplied list of numbers (of length at least two) select and return two that are the closest to each` |
| 6 | `    other and return them in order (smaller number, larger number).` | `// other and return them in order (smaller number, larger number).` |
| 7 | `    >>> find_closest_elements([1.0, 2.0, 3.0, 4.0, 5.0, 2.2])` | `// Example: find_closest_elements([1.0, 2.0, 3.0, 4.0, 5.0, 2.2])` |
| 8 | `    (2.0, 2.2)` | `// (2.0, 2.2)` |
| 9 | `    >>> find_closest_elements([1.0, 2.0, 3.0, 4.0, 5.0, 2.0])` | `// Example: find_closest_elements([1.0, 2.0, 3.0, 4.0, 5.0, 2.0])` |
| 10 | `    (2.0, 2.0)` | `// (2.0, 2.0)` |
| 11 | `    """` | `// ` |
