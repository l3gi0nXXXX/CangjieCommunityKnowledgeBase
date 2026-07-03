# CJ-HUMANEVAL-046: fib4

- Source task: `HumanEval/46`
- Cangjie signature: `public func fib4(n: Int64): Int64`
- Test calls expanded from official HumanEval: `4`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def fib4(n: int):` | `public func fib4(n: Int64): Int64 {` |
| 4 | `    """The Fib4 number sequence is a sequence similar to the Fibbonacci sequnece that's defined as follows:` | `// The Fib4 number sequence is a sequence similar to the Fibbonacci sequnece that's defined as follows:` |
| 5 | `    fib4(0) -> 0` | `// fib4(0) -> 0` |
| 6 | `    fib4(1) -> 0` | `// fib4(1) -> 0` |
| 7 | `    fib4(2) -> 2` | `// fib4(2) -> 2` |
| 8 | `    fib4(3) -> 0` | `// fib4(3) -> 0` |
| 9 | `    fib4(n) -> fib4(n-1) + fib4(n-2) + fib4(n-3) + fib4(n-4).` | `// fib4(n) -> fib4(n-1) + fib4(n-2) + fib4(n-3) + fib4(n-4).` |
| 10 | `    Please write a function to efficiently compute the n-th element of the fib4 number sequence.  Do not use recursion.` | `// Please write a function to efficiently compute the n-th element of the fib4 number sequence.  Do not use recursion.` |
| 11 | `    >>> fib4(5)` | `// Example: fib4(5)` |
| 12 | `    4` | `// 4` |
| 13 | `    >>> fib4(6)` | `// Example: fib4(6)` |
| 14 | `    8` | `// 8` |
| 15 | `    >>> fib4(7)` | `// Example: fib4(7)` |
| 16 | `    14` | `// 14` |
| 17 | `    """` | `// ` |
