# CJ-HUMANEVAL-005: intersperse

- Source task: `HumanEval/5`
- Cangjie signature: `public func intersperse(numbers: ArrayList<Int64>, delimeter: Int64): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `3`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def intersperse(numbers: List[int], delimeter: int) -> List[int]:` | `public func intersperse(numbers: ArrayList<Int64>, delimeter: Int64): ArrayList<Int64> {` |
| 5 | `    """ Insert a number 'delimeter' between every two consecutive elements of input list \`numbers'` | `//  Insert a number 'delimeter' between every two consecutive elements of input list \`numbers'` |
| 6 | `    >>> intersperse([], 4)` | `// Example: intersperse([], 4)` |
| 7 | `    []` | `// []` |
| 8 | `    >>> intersperse([1, 2, 3], 4)` | `// Example: intersperse([1, 2, 3], 4)` |
| 9 | `    [1, 4, 2, 4, 3]` | `// [1, 4, 2, 4, 3]` |
| 10 | `    """` | `// ` |
