# CJ-HUMANEVAL-106: f

- Source task: `HumanEval/106`
- Cangjie signature: `public func f(n: Int64): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `4`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def f(n):` | `public func f(n: Int64): ArrayList<Int64> {` |
| 3 | `    """ Implement the function f that takes n as a parameter,` | `//  Implement the function f that takes n as a parameter,` |
| 4 | `    and returns a list of size n, such that the value of the element at index i is the factorial of i if i is even` | `// and returns a list of size n, such that the value of the element at index i is the factorial of i if i is even` |
| 5 | `    or the sum of numbers from 1 to i otherwise.` | `// or the sum of numbers from 1 to i otherwise.` |
| 6 | `    i starts from 1.` | `// i starts from 1.` |
| 7 | `    the factorial of i is the multiplication of the numbers from 1 to i (1 * 2 * ... * i).` | `// the factorial of i is the multiplication of the numbers from 1 to i (1 * 2 * ... * i).` |
| 8 | `    Example:` | `// Example:` |
| 9 | `    f(5) == [1, 2, 6, 24, 15]` | `// f(5) == [1, 2, 6, 24, 15]` |
| 10 | `    """` | `// ` |
