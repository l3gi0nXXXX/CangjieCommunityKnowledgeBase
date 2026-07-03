# CJ-HUMANEVAL-025: factorize

- Source task: `HumanEval/25`
- Cangjie signature: `public func factorize(n: Int64): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `8`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def factorize(n: int) -> List[int]:` | `public func factorize(n: Int64): ArrayList<Int64> {` |
| 5 | `    """ Return list of prime factors of given integer in the order from smallest to largest.` | `//  Return list of prime factors of given integer in the order from smallest to largest.` |
| 6 | `    Each of the factors should be listed number of times corresponding to how many times it appeares in factorization.` | `// Each of the factors should be listed number of times corresponding to how many times it appeares in factorization.` |
| 7 | `    Input number should be equal to the product of all factors` | `// Input number should be equal to the product of all factors` |
| 8 | `    >>> factorize(8)` | `// Example: factorize(8)` |
| 9 | `    [2, 2, 2]` | `// [2, 2, 2]` |
| 10 | `    >>> factorize(25)` | `// Example: factorize(25)` |
| 11 | `    [5, 5]` | `// [5, 5]` |
| 12 | `    >>> factorize(70)` | `// Example: factorize(70)` |
| 13 | `    [2, 5, 7]` | `// [2, 5, 7]` |
| 14 | `    """` | `// ` |
