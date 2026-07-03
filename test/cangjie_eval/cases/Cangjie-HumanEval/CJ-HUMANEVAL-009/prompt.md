# CJ-HUMANEVAL-009: rolling_max

- Source task: `HumanEval/9`
- Cangjie signature: `public func rolling_max(numbers: ArrayList<Int64>): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `4`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List, Tuple` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def rolling_max(numbers: List[int]) -> List[int]:` | `public func rolling_max(numbers: ArrayList<Int64>): ArrayList<Int64> {` |
| 5 | `    """ From a given list of integers, generate a list of rolling maximum element found until given moment` | `//  From a given list of integers, generate a list of rolling maximum element found until given moment` |
| 6 | `    in the sequence.` | `// in the sequence.` |
| 7 | `    >>> rolling_max([1, 2, 3, 2, 3, 4, 2])` | `// Example: rolling_max([1, 2, 3, 2, 3, 4, 2])` |
| 8 | `    [1, 2, 3, 3, 3, 4, 4]` | `// [1, 2, 3, 3, 3, 4, 4]` |
| 9 | `    """` | `// ` |
