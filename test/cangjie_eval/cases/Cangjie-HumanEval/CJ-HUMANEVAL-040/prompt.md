# CJ-HUMANEVAL-040: triples_sum_to_zero

- Source task: `HumanEval/40`
- Cangjie signature: `public func triples_sum_to_zero(l: ArrayList<Int64>): Bool`
- Test calls expanded from official HumanEval: `9`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def triples_sum_to_zero(l: list):` | `public func triples_sum_to_zero(l: ArrayList<Int64>): Bool {` |
| 4 | `    """` | `// ` |
| 5 | `    triples_sum_to_zero takes a list of integers as an input.` | `// triples_sum_to_zero takes a list of integers as an input.` |
| 6 | `    it returns True if there are three distinct elements in the list that` | `// it returns True if there are three distinct elements in the list that` |
| 7 | `    sum to zero, and False otherwise.` | `// sum to zero, and False otherwise.` |
| 8 | `` | `` |
| 9 | `    >>> triples_sum_to_zero([1, 3, 5, 0])` | `// Example: triples_sum_to_zero([1, 3, 5, 0])` |
| 10 | `    False` | `// False` |
| 11 | `    >>> triples_sum_to_zero([1, 3, -2, 1])` | `// Example: triples_sum_to_zero([1, 3, -2, 1])` |
| 12 | `    True` | `// True` |
| 13 | `    >>> triples_sum_to_zero([1, 2, 3, 7])` | `// Example: triples_sum_to_zero([1, 2, 3, 7])` |
| 14 | `    False` | `// False` |
| 15 | `    >>> triples_sum_to_zero([2, 4, -5, 3, 9, 7])` | `// Example: triples_sum_to_zero([2, 4, -5, 3, 9, 7])` |
| 16 | `    True` | `// True` |
| 17 | `    >>> triples_sum_to_zero([1])` | `// Example: triples_sum_to_zero([1])` |
| 18 | `    False` | `// False` |
| 19 | `    """` | `// ` |
