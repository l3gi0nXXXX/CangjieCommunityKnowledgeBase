# CJ-HUMANEVAL-076: is_simple_power

- Source task: `HumanEval/76`
- Cangjie signature: `public func is_simple_power(x: Int64, n: Int64): Bool`
- Test calls expanded from official HumanEval: `10`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def is_simple_power(x, n):` | `public func is_simple_power(x: Int64, n: Int64): Bool {` |
| 3 | `    """Your task is to write a function that returns true if a number x is a simple` | `// Your task is to write a function that returns true if a number x is a simple` |
| 4 | `    power of n and false in other cases.` | `// power of n and false in other cases.` |
| 5 | `    x is a simple power of n if n**int=x` | `// x is a simple power of n if n**int=x` |
| 6 | `    For example:` | `// For example:` |
| 7 | `    is_simple_power(1, 4) => true` | `// is_simple_power(1, 4) => true` |
| 8 | `    is_simple_power(2, 2) => true` | `// is_simple_power(2, 2) => true` |
| 9 | `    is_simple_power(8, 2) => true` | `// is_simple_power(8, 2) => true` |
| 10 | `    is_simple_power(3, 2) => false` | `// is_simple_power(3, 2) => false` |
| 11 | `    is_simple_power(3, 1) => false` | `// is_simple_power(3, 1) => false` |
| 12 | `    is_simple_power(5, 3) => false` | `// is_simple_power(5, 3) => false` |
| 13 | `    """` | `// ` |
