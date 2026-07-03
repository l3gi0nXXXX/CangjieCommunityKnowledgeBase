# CJ-HUMANEVAL-058: common

- Source task: `HumanEval/58`
- Cangjie signature: `public func common(l1: ArrayList<Int64>, l2: ArrayList<Int64>): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `4`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def common(l1: list, l2: list):` | `public func common(l1: ArrayList<Int64>, l2: ArrayList<Int64>): ArrayList<Int64> {` |
| 4 | `    """Return sorted unique common elements for two lists.` | `// Return sorted unique common elements for two lists.` |
| 5 | `    >>> common([1, 4, 3, 34, 653, 2, 5], [5, 7, 1, 5, 9, 653, 121])` | `// Example: common([1, 4, 3, 34, 653, 2, 5], [5, 7, 1, 5, 9, 653, 121])` |
| 6 | `    [1, 5, 653]` | `// [1, 5, 653]` |
| 7 | `    >>> common([5, 3, 2, 8], [3, 2])` | `// Example: common([5, 3, 2, 8], [3, 2])` |
| 8 | `    [2, 3]` | `// [2, 3]` |
| 9 | `` | `` |
| 10 | `    """` | `// ` |
