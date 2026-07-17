# CJ-HUMANEVAL-037: sort_even

- Source task: `HumanEval/37`
- Cangjie signature: `public func sort_even(l: ArrayList<Int64>): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `3`
- Static-language adaptations:
  - The official Python verifier applies `tuple(candidate(...))`, so Python accepts any iterable yielding the expected integers. The Cangjie signature intentionally projects that dynamic return domain to `ArrayList<Int64>` and does not claim arbitrary Python iterable return compatibility. All three official inputs and expected elements remain exact.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def sort_even(l: list):` | `public func sort_even(l: ArrayList<Int64>): ArrayList<Int64> {` |
| 4 | `    """This function takes a list l and returns a list l' such that` | `// This function takes a list l and returns a list l' such that` |
| 5 | `    l' is identical to l in the odd indicies, while its values at the even indicies are equal` | `// l' is identical to l in the odd indicies, while its values at the even indicies are equal` |
| 6 | `    to the values of the even indicies of l, but sorted.` | `// to the values of the even indicies of l, but sorted.` |
| 7 | `    >>> sort_even([1, 2, 3])` | `// Example: sort_even([1, 2, 3])` |
| 8 | `    [1, 2, 3]` | `// [1, 2, 3]` |
| 9 | `    >>> sort_even([5, 6, 3, 4])` | `// Example: sort_even([5, 6, 3, 4])` |
| 10 | `    [3, 6, 5, 4]` | `// [3, 6, 5, 4]` |
| 11 | `    """` | `// ` |
