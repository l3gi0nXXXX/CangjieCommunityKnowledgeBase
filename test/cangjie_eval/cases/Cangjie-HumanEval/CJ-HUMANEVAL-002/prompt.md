# CJ-HUMANEVAL-002: truncate_number

- Source task: `HumanEval/2`
- Cangjie signature: `public func truncate_number(number: Float64): Float64`
- Test calls expanded from official HumanEval: `3`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def truncate_number(number: float) -> float:` | `public func truncate_number(number: Float64): Float64 {` |
| 4 | `    """ Given a positive floating point number, it can be decomposed into` | `//  Given a positive floating point number, it can be decomposed into` |
| 5 | `    and integer part (largest integer smaller than given number) and decimals` | `// and integer part (largest integer smaller than given number) and decimals` |
| 6 | `    (leftover part always smaller than 1).` | `// (leftover part always smaller than 1).` |
| 7 | `` | `` |
| 8 | `    Return the decimal part of the number.` | `// Return the decimal part of the number.` |
| 9 | `    >>> truncate_number(3.5)` | `// Example: truncate_number(3.5)` |
| 10 | `    0.5` | `// 0.5` |
| 11 | `    """` | `// ` |
