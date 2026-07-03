# CJ-HUMANEVAL-049: modp

- Source task: `HumanEval/49`
- Cangjie signature: `public func modp(n: Int64, p: Int64): Int64`
- Test calls expanded from official HumanEval: `7`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def modp(n: int, p: int):` | `public func modp(n: Int64, p: Int64): Int64 {` |
| 4 | `    """Return 2^n modulo p (be aware of numerics).` | `// Return 2^n modulo p (be aware of numerics).` |
| 5 | `    >>> modp(3, 5)` | `// Example: modp(3, 5)` |
| 6 | `    3` | `// 3` |
| 7 | `    >>> modp(1101, 101)` | `// Example: modp(1101, 101)` |
| 8 | `    2` | `// 2` |
| 9 | `    >>> modp(0, 101)` | `// Example: modp(0, 101)` |
| 10 | `    1` | `// 1` |
| 11 | `    >>> modp(3, 11)` | `// Example: modp(3, 11)` |
| 12 | `    8` | `// 8` |
| 13 | `    >>> modp(100, 101)` | `// Example: modp(100, 101)` |
| 14 | `    1` | `// 1` |
| 15 | `    """` | `// ` |
