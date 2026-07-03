# CJ-HUMANEVAL-032: find_zero

- Source task: `HumanEval/32`
- Cangjie signature: `public func find_zero(xs: ArrayList<Int64>): Float64`
- Test calls expanded from official HumanEval: `100`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `import math` | `// import math` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def poly(xs: list, x: float):` | `public func find_zero(xs: ArrayList<Int64>): Float64 {` |
| 5 | `    """` | `// ` |
| 6 | `    Evaluates polynomial with coefficients xs at point x.` | `// Evaluates polynomial with coefficients xs at point x.` |
| 7 | `    return xs[0] + xs[1] * x + xs[1] * x^2 + .... xs[n] * x^n` | `// return xs[0] + xs[1] * x + xs[1] * x^2 + .... xs[n] * x^n` |
| 8 | `    """` | `// ` |
| 9 | `    return sum([coeff * math.pow(x, i) for i, coeff in enumerate(xs)])` | `// return sum([coeff * math.pow(x, i) for i, coeff in enumerate(xs)])` |
| 10 | `` | `` |
| 11 | `` | `` |
| 12 | `def find_zero(xs: list):` | `public func find_zero(xs: ArrayList<Int64>): Float64 {` |
| 13 | `    """ xs are coefficients of a polynomial.` | `//  xs are coefficients of a polynomial.` |
| 14 | `    find_zero find x such that poly(x) = 0.` | `// find_zero find x such that poly(x) = 0.` |
| 15 | `    find_zero returns only only zero point, even if there are many.` | `// find_zero returns only only zero point, even if there are many.` |
| 16 | `    Moreover, find_zero only takes list xs having even number of coefficients` | `// Moreover, find_zero only takes list xs having even number of coefficients` |
| 17 | `    and largest non zero coefficient as it guarantees` | `// and largest non zero coefficient as it guarantees` |
| 18 | `    a solution.` | `// a solution.` |
| 19 | `    >>> round(find_zero([1, 2]), 2) # f(x) = 1 + 2x` | `// Example: round(find_zero([1, 2]), 2) # f(x) = 1 + 2x` |
| 20 | `    -0.5` | `// -0.5` |
| 21 | `    >>> round(find_zero([-6, 11, -6, 1]), 2) # (x - 1) * (x - 2) * (x - 3) = -6 + 11x - 6x^2 + x^3` | `// Example: round(find_zero([-6, 11, -6, 1]), 2) # (x - 1) * (x - 2) * (x - 3) = -6 + 11x - 6x^2 + x^3` |
| 22 | `    1.0` | `// 1.0` |
| 23 | `    """` | `// ` |
