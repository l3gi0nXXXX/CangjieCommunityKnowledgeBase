# CJ-HUMANEVAL-030: get_positive

- Source task: `HumanEval/30`
- Cangjie signature: `public func get_positive(l: ArrayList<Int64>): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `4`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def get_positive(l: list):` | `public func get_positive(l: ArrayList<Int64>): ArrayList<Int64> {` |
| 4 | `    """Return only positive numbers in the list.` | `// Return only positive numbers in the list.` |
| 5 | `    >>> get_positive([-1, 2, -4, 5, 6])` | `// Example: get_positive([-1, 2, -4, 5, 6])` |
| 6 | `    [2, 5, 6]` | `// [2, 5, 6]` |
| 7 | `    >>> get_positive([5, 3, -5, 2, -3, 3, 9, 0, 123, 1, -10])` | `// Example: get_positive([5, 3, -5, 2, -3, 3, 9, 0, 123, 1, -10])` |
| 8 | `    [5, 3, 2, 3, 9, 123, 1]` | `// [5, 3, 2, 3, 9, 123, 1]` |
| 9 | `    """` | `// ` |
