# CJ-HUMANEVAL-021: rescale_to_unit

- Source task: `HumanEval/21`
- Cangjie signature: `public func rescale_to_unit(numbers: ArrayList<Float64>): ArrayList<Float64>`
- Test calls expanded from official HumanEval: `5`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def rescale_to_unit(numbers: List[float]) -> List[float]:` | `public func rescale_to_unit(numbers: ArrayList<Float64>): ArrayList<Float64> {` |
| 5 | `    """ Given list of numbers (of at least two elements), apply a linear transform to that list,` | `//  Given list of numbers (of at least two elements), apply a linear transform to that list,` |
| 6 | `    such that the smallest number will become 0 and the largest will become 1` | `// such that the smallest number will become 0 and the largest will become 1` |
| 7 | `    >>> rescale_to_unit([1.0, 2.0, 3.0, 4.0, 5.0])` | `// Example: rescale_to_unit([1.0, 2.0, 3.0, 4.0, 5.0])` |
| 8 | `    [0.0, 0.25, 0.5, 0.75, 1.0]` | `// [0.0, 0.25, 0.5, 0.75, 1.0]` |
| 9 | `    """` | `// ` |
