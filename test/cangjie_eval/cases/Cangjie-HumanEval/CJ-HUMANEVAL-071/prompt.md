# CJ-HUMANEVAL-071: triangle_area

- Source task: `HumanEval/71`
- Cangjie signature: `public func triangle_area(a: Int64, b: Int64, c: Int64): Float64`
- Test calls expanded from official HumanEval: `9`
- Static-language adaptations:
  - Python int/float numeric unions are represented with Float64 where needed.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def triangle_area(a, b, c):` | `public func triangle_area(a: Int64, b: Int64, c: Int64): Float64 {` |
| 3 | `    '''` | `// '''` |
| 4 | `    Given the lengths of the three sides of a triangle. Return the area of` | `// Given the lengths of the three sides of a triangle. Return the area of` |
| 5 | `    the triangle rounded to 2 decimal points if the three sides form a valid triangle. ` | `// the triangle rounded to 2 decimal points if the three sides form a valid triangle.` |
| 6 | `    Otherwise return -1` | `// Otherwise return -1` |
| 7 | `    Three sides make a valid triangle when the sum of any two sides is greater ` | `// Three sides make a valid triangle when the sum of any two sides is greater` |
| 8 | `    than the third side.` | `// than the third side.` |
| 9 | `    Example:` | `// Example:` |
| 10 | `    triangle_area(3, 4, 5) == 6.00` | `// triangle_area(3, 4, 5) == 6.00` |
| 11 | `    triangle_area(1, 2, 10) == -1` | `// triangle_area(1, 2, 10) == -1` |
| 12 | `    '''` | `// '''` |
