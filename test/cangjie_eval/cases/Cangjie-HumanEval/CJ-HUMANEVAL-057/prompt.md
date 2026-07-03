# CJ-HUMANEVAL-057: monotonic

- Source task: `HumanEval/57`
- Cangjie signature: `public func monotonic(l: ArrayList<Int64>): Bool`
- Test calls expanded from official HumanEval: `8`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def monotonic(l: list):` | `public func monotonic(l: ArrayList<Int64>): Bool {` |
| 4 | `    """Return True is list elements are monotonically increasing or decreasing.` | `// Return True is list elements are monotonically increasing or decreasing.` |
| 5 | `    >>> monotonic([1, 2, 4, 20])` | `// Example: monotonic([1, 2, 4, 20])` |
| 6 | `    True` | `// True` |
| 7 | `    >>> monotonic([1, 20, 4, 10])` | `// Example: monotonic([1, 20, 4, 10])` |
| 8 | `    False` | `// False` |
| 9 | `    >>> monotonic([4, 1, 0, -10])` | `// Example: monotonic([4, 1, 0, -10])` |
| 10 | `    True` | `// True` |
| 11 | `    """` | `// ` |
