# CJ-HUMANEVAL-096: count_up_to

- Source task: `HumanEval/96`
- Cangjie signature: `public func count_up_to(n: Int64): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `10`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def count_up_to(n):` | `public func count_up_to(n: Int64): ArrayList<Int64> {` |
| 3 | `    """Implement a function that takes an non-negative integer and returns an array of the first n` | `// Implement a function that takes an non-negative integer and returns an array of the first n` |
| 4 | `    integers that are prime numbers and less than n.` | `// integers that are prime numbers and less than n.` |
| 5 | `    for example:` | `// for example:` |
| 6 | `    count_up_to(5) => [2,3]` | `// count_up_to(5) => [2,3]` |
| 7 | `    count_up_to(11) => [2,3,5,7]` | `// count_up_to(11) => [2,3,5,7]` |
| 8 | `    count_up_to(0) => []` | `// count_up_to(0) => []` |
| 9 | `    count_up_to(20) => [2,3,5,7,11,13,17,19]` | `// count_up_to(20) => [2,3,5,7,11,13,17,19]` |
| 10 | `    count_up_to(1) => []` | `// count_up_to(1) => []` |
| 11 | `    count_up_to(18) => [2,3,5,7,11,13,17]` | `// count_up_to(18) => [2,3,5,7,11,13,17]` |
| 12 | `    """` | `// ` |
