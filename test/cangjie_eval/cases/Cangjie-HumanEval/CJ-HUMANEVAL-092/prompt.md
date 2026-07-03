# CJ-HUMANEVAL-092: any_int

- Source task: `HumanEval/92`
- Cangjie signature: `public func any_int(x: Float64, y: Float64, z: Float64): Bool`
- Test calls expanded from official HumanEval: `10`
- Static-language adaptations:
  - Python int/float numeric unions are represented with Float64 where needed.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def any_int(x, y, z):` | `public func any_int(x: Float64, y: Float64, z: Float64): Bool {` |
| 3 | `    '''` | `// '''` |
| 4 | `    Create a function that takes 3 numbers.` | `// Create a function that takes 3 numbers.` |
| 5 | `    Returns true if one of the numbers is equal to the sum of the other two, and all numbers are integers.` | `// Returns true if one of the numbers is equal to the sum of the other two, and all numbers are integers.` |
| 6 | `    Returns false in any other cases.` | `// Returns false in any other cases.` |
| 7 | `    ` | `` |
| 8 | `    Examples` | `// Examples` |
| 9 | `    any_int(5, 2, 7) ➞ True` | `// any_int(5, 2, 7) ➞ True` |
| 10 | `    ` | `` |
| 11 | `    any_int(3, 2, 2) ➞ False` | `// any_int(3, 2, 2) ➞ False` |
| 12 | `` | `` |
| 13 | `    any_int(3, -2, 1) ➞ True` | `// any_int(3, -2, 1) ➞ True` |
| 14 | `    ` | `` |
| 15 | `    any_int(3.6, -2.2, 2) ➞ False` | `// any_int(3.6, -2.2, 2) ➞ False` |
| 16 | `  ` | `` |
| 17 | `` | `` |
| 18 | `    ` | `` |
| 19 | `    '''` | `// '''` |
