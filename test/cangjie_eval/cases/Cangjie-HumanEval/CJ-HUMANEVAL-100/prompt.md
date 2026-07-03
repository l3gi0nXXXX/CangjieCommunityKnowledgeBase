# CJ-HUMANEVAL-100: make_a_pile

- Source task: `HumanEval/100`
- Cangjie signature: `public func make_a_pile(n: Int64): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `5`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def make_a_pile(n):` | `public func make_a_pile(n: Int64): ArrayList<Int64> {` |
| 3 | `    """` | `// ` |
| 4 | `    Given a positive integer n, you have to make a pile of n levels of stones.` | `// Given a positive integer n, you have to make a pile of n levels of stones.` |
| 5 | `    The first level has n stones.` | `// The first level has n stones.` |
| 6 | `    The number of stones in the next level is:` | `// The number of stones in the next level is:` |
| 7 | `        - the next odd number if n is odd.` | `// - the next odd number if n is odd.` |
| 8 | `        - the next even number if n is even.` | `// - the next even number if n is even.` |
| 9 | `    Return the number of stones in each level in a list, where element at index` | `// Return the number of stones in each level in a list, where element at index` |
| 10 | `    i represents the number of stones in the level (i+1).` | `// i represents the number of stones in the level (i+1).` |
| 11 | `` | `` |
| 12 | `    Examples:` | `// Examples:` |
| 13 | `    >>> make_a_pile(3)` | `// Example: make_a_pile(3)` |
| 14 | `    [3, 5, 7]` | `// [3, 5, 7]` |
| 15 | `    """` | `// ` |
