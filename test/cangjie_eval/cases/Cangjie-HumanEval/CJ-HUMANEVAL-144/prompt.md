# CJ-HUMANEVAL-144: simplify

- Source task: `HumanEval/144`
- Cangjie signature: `public func simplify(x: String, n: String): Bool`
- Test calls expanded from official HumanEval: `13`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def simplify(x, n):` | `public func simplify(x: String, n: String): Bool {` |
| 3 | `    """Your task is to implement a function that will simplify the expression` | `// Your task is to implement a function that will simplify the expression` |
| 4 | `    x * n. The function returns True if x * n evaluates to a whole number and False` | `// x * n. The function returns True if x * n evaluates to a whole number and False` |
| 5 | `    otherwise. Both x and n, are string representation of a fraction, and have the following format,` | `// otherwise. Both x and n, are string representation of a fraction, and have the following format,` |
| 6 | `    <numerator>/<denominator> where both numerator and denominator are positive whole numbers.` | `// <numerator>/<denominator> where both numerator and denominator are positive whole numbers.` |
| 7 | `` | `` |
| 8 | `    You can assume that x, and n are valid fractions, and do not have zero as denominator.` | `// You can assume that x, and n are valid fractions, and do not have zero as denominator.` |
| 9 | `` | `` |
| 10 | `    simplify("1/5", "5/1") = True` | `// simplify("1/5", "5/1") = True` |
| 11 | `    simplify("1/6", "2/1") = False` | `// simplify("1/6", "2/1") = False` |
| 12 | `    simplify("7/10", "10/2") = False` | `// simplify("7/10", "10/2") = False` |
| 13 | `    """` | `// ` |
