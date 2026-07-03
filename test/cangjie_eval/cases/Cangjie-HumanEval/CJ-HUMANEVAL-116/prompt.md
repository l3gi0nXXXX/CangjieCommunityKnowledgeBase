# CJ-HUMANEVAL-116: sort_array

- Source task: `HumanEval/116`
- Cangjie signature: `public func sort_array(arr: ArrayList<Int64>): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `8`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def sort_array(arr):` | `public func sort_array(arr: ArrayList<Int64>): ArrayList<Int64> {` |
| 3 | `    """` | `// ` |
| 4 | `    In this Kata, you have to sort an array of non-negative integers according to` | `// In this Kata, you have to sort an array of non-negative integers according to` |
| 5 | `    number of ones in their binary representation in ascending order.` | `// number of ones in their binary representation in ascending order.` |
| 6 | `    For similar number of ones, sort based on decimal value.` | `// For similar number of ones, sort based on decimal value.` |
| 7 | `` | `` |
| 8 | `    It must be implemented like this:` | `// It must be implemented like this:` |
| 9 | `    >>> sort_array([1, 5, 2, 3, 4]) == [1, 2, 3, 4, 5]` | `// Example: sort_array([1, 5, 2, 3, 4]) == [1, 2, 3, 4, 5]` |
| 10 | `    >>> sort_array([-2, -3, -4, -5, -6]) == [-6, -5, -4, -3, -2]` | `// Example: sort_array([-2, -3, -4, -5, -6]) == [-6, -5, -4, -3, -2]` |
| 11 | `    >>> sort_array([1, 0, 2, 3, 4]) [0, 1, 2, 3, 4]` | `// Example: sort_array([1, 0, 2, 3, 4]) [0, 1, 2, 3, 4]` |
| 12 | `    """` | `// ` |
