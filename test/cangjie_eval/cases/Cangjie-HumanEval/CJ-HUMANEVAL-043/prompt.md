# CJ-HUMANEVAL-043: pairs_sum_to_zero

- Source task: `HumanEval/43`
- Cangjie signature: `public func pairs_sum_to_zero(l: ArrayList<Int64>): Bool`
- Test calls expanded from official HumanEval: `9`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def pairs_sum_to_zero(l):` | `public func pairs_sum_to_zero(l: ArrayList<Int64>): Bool {` |
| 4 | `    """` | `// ` |
| 5 | `    pairs_sum_to_zero takes a list of integers as an input.` | `// pairs_sum_to_zero takes a list of integers as an input.` |
| 6 | `    it returns True if there are two distinct elements in the list that` | `// it returns True if there are two distinct elements in the list that` |
| 7 | `    sum to zero, and False otherwise.` | `// sum to zero, and False otherwise.` |
| 8 | `    >>> pairs_sum_to_zero([1, 3, 5, 0])` | `// Example: pairs_sum_to_zero([1, 3, 5, 0])` |
| 9 | `    False` | `// False` |
| 10 | `    >>> pairs_sum_to_zero([1, 3, -2, 1])` | `// Example: pairs_sum_to_zero([1, 3, -2, 1])` |
| 11 | `    False` | `// False` |
| 12 | `    >>> pairs_sum_to_zero([1, 2, 3, 7])` | `// Example: pairs_sum_to_zero([1, 2, 3, 7])` |
| 13 | `    False` | `// False` |
| 14 | `    >>> pairs_sum_to_zero([2, 4, -5, 3, 5, 7])` | `// Example: pairs_sum_to_zero([2, 4, -5, 3, 5, 7])` |
| 15 | `    True` | `// True` |
| 16 | `    >>> pairs_sum_to_zero([1])` | `// Example: pairs_sum_to_zero([1])` |
| 17 | `    False` | `// False` |
| 18 | `    """` | `// ` |
