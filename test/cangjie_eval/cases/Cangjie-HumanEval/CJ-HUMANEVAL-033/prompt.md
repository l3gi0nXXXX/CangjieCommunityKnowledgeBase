# CJ-HUMANEVAL-033: sort_third

- Source task: `HumanEval/33`
- Cangjie signature: `public func sort_third(l: ArrayList<Int64>): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `7`
- Static-language adaptations:
  - The official Python verifier applies `tuple(candidate(...))`, so Python accepts any iterable yielding the expected integers. The Cangjie signature intentionally projects that dynamic return domain to `ArrayList<Int64>` and does not claim arbitrary Python iterable return compatibility. All seven official inputs and expected elements remain exact.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def sort_third(l: list):` | `public func sort_third(l: ArrayList<Int64>): ArrayList<Int64> {` |
| 4 | `    """This function takes a list l and returns a list l' such that` | `// This function takes a list l and returns a list l' such that` |
| 5 | `    l' is identical to l in the indicies that are not divisible by three, while its values at the indicies that are divisible by three are equal` | `// l' is identical to l in the indicies that are not divisible by three, while its values at the indicies that are divisible by three are equal` |
| 6 | `    to the values of the corresponding indicies of l, but sorted.` | `// to the values of the corresponding indicies of l, but sorted.` |
| 7 | `    >>> sort_third([1, 2, 3])` | `// Example: sort_third([1, 2, 3])` |
| 8 | `    [1, 2, 3]` | `// [1, 2, 3]` |
| 9 | `    >>> sort_third([5, 6, 3, 4, 8, 9, 2])` | `// Example: sort_third([5, 6, 3, 4, 8, 9, 2])` |
| 10 | `    [2, 6, 3, 4, 8, 9, 5]` | `// [2, 6, 3, 4, 8, 9, 5]` |
| 11 | `    """` | `// ` |
