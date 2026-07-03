# CJ-HUMANEVAL-026: remove_duplicates

- Source task: `HumanEval/26`
- Cangjie signature: `public func remove_duplicates(numbers: ArrayList<Int64>): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `3`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def remove_duplicates(numbers: List[int]) -> List[int]:` | `public func remove_duplicates(numbers: ArrayList<Int64>): ArrayList<Int64> {` |
| 5 | `    """ From a list of integers, remove all elements that occur more than once.` | `//  From a list of integers, remove all elements that occur more than once.` |
| 6 | `    Keep order of elements left the same as in the input.` | `// Keep order of elements left the same as in the input.` |
| 7 | `    >>> remove_duplicates([1, 2, 3, 2, 4])` | `// Example: remove_duplicates([1, 2, 3, 2, 4])` |
| 8 | `    [1, 3, 4]` | `// [1, 3, 4]` |
| 9 | `    """` | `// ` |
