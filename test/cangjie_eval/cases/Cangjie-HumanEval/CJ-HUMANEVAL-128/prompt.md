# CJ-HUMANEVAL-128: prod_signs

- Source task: `HumanEval/128`
- Cangjie signature: `public func prod_signs(arr: ArrayList<Int64>): Option<Int64>`
- Test calls expanded from official HumanEval: `8`
- Static-language adaptations:
  - Python None returns are represented by Option<T>.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def prod_signs(arr):` | `public func prod_signs(arr: ArrayList<Int64>): Option<Int64> {` |
| 3 | `    """` | `// ` |
| 4 | `    You are given an array arr of integers and you need to return` | `// You are given an array arr of integers and you need to return` |
| 5 | `    sum of magnitudes of integers multiplied by product of all signs` | `// sum of magnitudes of integers multiplied by product of all signs` |
| 6 | `    of each number in the array, represented by 1, -1 or 0.` | `// of each number in the array, represented by 1, -1 or 0.` |
| 7 | `    Note: return None for empty arr.` | `// Note: return None for empty arr.` |
| 8 | `` | `` |
| 9 | `    Example:` | `// Example:` |
| 10 | `    >>> prod_signs([1, 2, 2, -4]) == -9` | `// Example: prod_signs([1, 2, 2, -4]) == -9` |
| 11 | `    >>> prod_signs([0, 1]) == 0` | `// Example: prod_signs([0, 1]) == 0` |
| 12 | `    >>> prod_signs([]) == None` | `// Example: prod_signs([]) == None` |
| 13 | `    """` | `// ` |
