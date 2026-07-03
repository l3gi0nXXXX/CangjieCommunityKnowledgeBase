# CJ-HUMANEVAL-062: derivative

- Source task: `HumanEval/62`
- Cangjie signature: `public func derivative(xs: ArrayList<Int64>): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `5`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def derivative(xs: list):` | `public func derivative(xs: ArrayList<Int64>): ArrayList<Int64> {` |
| 4 | `    """ xs represent coefficients of a polynomial.` | `//  xs represent coefficients of a polynomial.` |
| 5 | `    xs[0] + xs[1] * x + xs[2] * x^2 + ....` | `// xs[0] + xs[1] * x + xs[2] * x^2 + ....` |
| 6 | `     Return derivative of this polynomial in the same form.` | `// Return derivative of this polynomial in the same form.` |
| 7 | `    >>> derivative([3, 1, 2, 4, 5])` | `// Example: derivative([3, 1, 2, 4, 5])` |
| 8 | `    [1, 4, 12, 20]` | `// [1, 4, 12, 20]` |
| 9 | `    >>> derivative([1, 2, 3])` | `// Example: derivative([1, 2, 3])` |
| 10 | `    [2, 6]` | `// [2, 6]` |
| 11 | `    """` | `// ` |
