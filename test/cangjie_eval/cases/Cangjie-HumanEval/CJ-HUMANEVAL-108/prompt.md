# CJ-HUMANEVAL-108: count_nums

- Source task: `HumanEval/108`
- Cangjie signature: `public func count_nums(arr: ArrayList<Int64>): Int64`
- Test calls expanded from official HumanEval: `8`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def count_nums(arr):` | `public func count_nums(arr: ArrayList<Int64>): Int64 {` |
| 3 | `    """` | `// ` |
| 4 | `    Write a function count_nums which takes an array of integers and returns` | `// Write a function count_nums which takes an array of integers and returns` |
| 5 | `    the number of elements which has a sum of digits > 0.` | `// the number of elements which has a sum of digits > 0.` |
| 6 | `    If a number is negative, then its first signed digit will be negative:` | `// If a number is negative, then its first signed digit will be negative:` |
| 7 | `    e.g. -123 has signed digits -1, 2, and 3.` | `// e.g. -123 has signed digits -1, 2, and 3.` |
| 8 | `    >>> count_nums([]) == 0` | `// Example: count_nums([]) == 0` |
| 9 | `    >>> count_nums([-1, 11, -11]) == 1` | `// Example: count_nums([-1, 11, -11]) == 1` |
| 10 | `    >>> count_nums([1, 1, 2]) == 3` | `// Example: count_nums([1, 1, 2]) == 3` |
| 11 | `    """` | `// ` |
