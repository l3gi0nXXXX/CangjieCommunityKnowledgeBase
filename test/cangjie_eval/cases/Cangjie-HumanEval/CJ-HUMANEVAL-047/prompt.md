# CJ-HUMANEVAL-047: median

- Source task: `HumanEval/47`
- Cangjie signature: `public func median(l: ArrayList<Int64>): Float64`
- Test calls expanded from official HumanEval: `5`
- Static-language adaptations:
  - Python int/float numeric unions are represented with Float64 where needed.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def median(l: list):` | `public func median(l: ArrayList<Int64>): Float64 {` |
| 4 | `    """Return median of elements in the list l.` | `// Return median of elements in the list l.` |
| 5 | `    >>> median([3, 1, 2, 4, 5])` | `// Example: median([3, 1, 2, 4, 5])` |
| 6 | `    3` | `// 3` |
| 7 | `    >>> median([-10, 4, 6, 1000, 10, 20])` | `// Example: median([-10, 4, 6, 1000, 10, 20])` |
| 8 | `    15.0` | `// 15.0` |
| 9 | `    """` | `// ` |
