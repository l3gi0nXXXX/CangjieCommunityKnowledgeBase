# CJ-HUMANEVAL-130: tri

- Source task: `HumanEval/130`
- Cangjie signature: `public func tri(n: Int64): ArrayList<Float64>`
- Test calls expanded from official HumanEval: `10`
- Static-language adaptations:
  - Python int/float numeric unions are represented with Float64 where needed.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def tri(n):` | `public func tri(n: Int64): ArrayList<Float64> {` |
| 3 | `    """Everyone knows Fibonacci sequence, it was studied deeply by mathematicians in ` | `// Everyone knows Fibonacci sequence, it was studied deeply by mathematicians in` |
| 4 | `    the last couple centuries. However, what people don't know is Tribonacci sequence.` | `// the last couple centuries. However, what people don't know is Tribonacci sequence.` |
| 5 | `    Tribonacci sequence is defined by the recurrence:` | `// Tribonacci sequence is defined by the recurrence:` |
| 6 | `    tri(1) = 3` | `// tri(1) = 3` |
| 7 | `    tri(n) = 1 + n / 2, if n is even.` | `// tri(n) = 1 + n / 2, if n is even.` |
| 8 | `    tri(n) =  tri(n - 1) + tri(n - 2) + tri(n + 1), if n is odd.` | `// tri(n) =  tri(n - 1) + tri(n - 2) + tri(n + 1), if n is odd.` |
| 9 | `    For example:` | `// For example:` |
| 10 | `    tri(2) = 1 + (2 / 2) = 2` | `// tri(2) = 1 + (2 / 2) = 2` |
| 11 | `    tri(4) = 3` | `// tri(4) = 3` |
| 12 | `    tri(3) = tri(2) + tri(1) + tri(4)` | `// tri(3) = tri(2) + tri(1) + tri(4)` |
| 13 | `           = 2 + 3 + 3 = 8 ` | `// = 2 + 3 + 3 = 8` |
| 14 | `    You are given a non-negative integer number n, you have to a return a list of the ` | `// You are given a non-negative integer number n, you have to a return a list of the` |
| 15 | `    first n + 1 numbers of the Tribonacci sequence.` | `// first n + 1 numbers of the Tribonacci sequence.` |
| 16 | `    Examples:` | `// Examples:` |
| 17 | `    tri(3) = [1, 3, 2, 8]` | `// tri(3) = [1, 3, 2, 8]` |
| 18 | `    """` | `// ` |
