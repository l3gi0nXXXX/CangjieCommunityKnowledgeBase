# CJ-HUMANEVAL-103: rounded_avg

- Source task: `HumanEval/103`
- Cangjie signature: `public func rounded_avg(n: Int64, m: Int64): EvalValue`
- Test calls expanded from official HumanEval: `12`
- Static-language adaptations:
  - Python dynamic values are represented by EvalValue/EvalEntry helper types.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def rounded_avg(n, m):` | `public func rounded_avg(n: Int64, m: Int64): EvalValue {` |
| 3 | `    """You are given two positive integers n and m, and your task is to compute the` | `// You are given two positive integers n and m, and your task is to compute the` |
| 4 | `    average of the integers from n through m (including n and m). ` | `// average of the integers from n through m (including n and m).` |
| 5 | `    Round the answer to the nearest integer and convert that to binary.` | `// Round the answer to the nearest integer and convert that to binary.` |
| 6 | `    If n is greater than m, return -1.` | `// If n is greater than m, return -1.` |
| 7 | `    Example:` | `// Example:` |
| 8 | `    rounded_avg(1, 5) => "0b11"` | `// rounded_avg(1, 5) => "0b11"` |
| 9 | `    rounded_avg(7, 5) => -1` | `// rounded_avg(7, 5) => -1` |
| 10 | `    rounded_avg(10, 20) => "0b1111"` | `// rounded_avg(10, 20) => "0b1111"` |
| 11 | `    rounded_avg(20, 33) => "0b11010"` | `// rounded_avg(20, 33) => "0b11010"` |
| 12 | `    """` | `// ` |
