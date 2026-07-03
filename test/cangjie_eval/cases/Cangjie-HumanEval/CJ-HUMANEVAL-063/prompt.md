# CJ-HUMANEVAL-063: fibfib

- Source task: `HumanEval/63`
- Cangjie signature: `public func fibfib(n: Int64): Int64`
- Test calls expanded from official HumanEval: `7`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def fibfib(n: int):` | `public func fibfib(n: Int64): Int64 {` |
| 4 | `    """The FibFib number sequence is a sequence similar to the Fibbonacci sequnece that's defined as follows:` | `// The FibFib number sequence is a sequence similar to the Fibbonacci sequnece that's defined as follows:` |
| 5 | `    fibfib(0) == 0` | `// fibfib(0) == 0` |
| 6 | `    fibfib(1) == 0` | `// fibfib(1) == 0` |
| 7 | `    fibfib(2) == 1` | `// fibfib(2) == 1` |
| 8 | `    fibfib(n) == fibfib(n-1) + fibfib(n-2) + fibfib(n-3).` | `// fibfib(n) == fibfib(n-1) + fibfib(n-2) + fibfib(n-3).` |
| 9 | `    Please write a function to efficiently compute the n-th element of the fibfib number sequence.` | `// Please write a function to efficiently compute the n-th element of the fibfib number sequence.` |
| 10 | `    >>> fibfib(1)` | `// Example: fibfib(1)` |
| 11 | `    0` | `// 0` |
| 12 | `    >>> fibfib(5)` | `// Example: fibfib(5)` |
| 13 | `    4` | `// 4` |
| 14 | `    >>> fibfib(8)` | `// Example: fibfib(8)` |
| 15 | `    24` | `// 24` |
| 16 | `    """` | `// ` |
