# CJ-HUMANEVAL-052: below_threshold

- Source task: `HumanEval/52`
- Cangjie signature: `public func below_threshold(l: ArrayList<Int64>, t: Int64): Bool`
- Test calls expanded from official HumanEval: `6`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def below_threshold(l: list, t: int):` | `public func below_threshold(l: ArrayList<Int64>, t: Int64): Bool {` |
| 4 | `    """Return True if all numbers in the list l are below threshold t.` | `// Return True if all numbers in the list l are below threshold t.` |
| 5 | `    >>> below_threshold([1, 2, 4, 10], 100)` | `// Example: below_threshold([1, 2, 4, 10], 100)` |
| 6 | `    True` | `// True` |
| 7 | `    >>> below_threshold([1, 20, 4, 10], 5)` | `// Example: below_threshold([1, 20, 4, 10], 5)` |
| 8 | `    False` | `// False` |
| 9 | `    """` | `// ` |
