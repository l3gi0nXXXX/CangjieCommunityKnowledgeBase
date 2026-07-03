# CJ-HUMANEVAL-163: generate_integers

- Source task: `HumanEval/163`
- Cangjie signature: `public func generate_integers(a: Int64, b: Int64): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `4`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def generate_integers(a, b):` | `public func generate_integers(a: Int64, b: Int64): ArrayList<Int64> {` |
| 3 | `    """` | `// ` |
| 4 | `    Given two positive integers a and b, return the even digits between a` | `// Given two positive integers a and b, return the even digits between a` |
| 5 | `    and b, in ascending order.` | `// and b, in ascending order.` |
| 6 | `` | `` |
| 7 | `    For example:` | `// For example:` |
| 8 | `    generate_integers(2, 8) => [2, 4, 6, 8]` | `// generate_integers(2, 8) => [2, 4, 6, 8]` |
| 9 | `    generate_integers(8, 2) => [2, 4, 6, 8]` | `// generate_integers(8, 2) => [2, 4, 6, 8]` |
| 10 | `    generate_integers(10, 14) => []` | `// generate_integers(10, 14) => []` |
| 11 | `    """` | `// ` |
