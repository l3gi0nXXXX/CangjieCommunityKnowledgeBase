# CJ-HUMANEVAL-133: sum_squares

- Source task: `HumanEval/133`
- Cangjie signature: `public func sum_squares(lst: ArrayList<Float64>): Int64`
- Test calls expanded from official HumanEval: `12`
- Static-language adaptations:
  - Python int/float numeric unions are represented with Float64 where needed.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def sum_squares(lst):` | `public func sum_squares(lst: ArrayList<Float64>): Int64 {` |
| 4 | `    """You are given a list of numbers.` | `// You are given a list of numbers.` |
| 5 | `    You need to return the sum of squared numbers in the given list,` | `// You need to return the sum of squared numbers in the given list,` |
| 6 | `    round each element in the list to the upper int(Ceiling) first.` | `// round each element in the list to the upper int(Ceiling) first.` |
| 7 | `    Examples:` | `// Examples:` |
| 8 | `    For lst = [1,2,3] the output should be 14` | `// For lst = [1,2,3] the output should be 14` |
| 9 | `    For lst = [1,4,9] the output should be 98` | `// For lst = [1,4,9] the output should be 98` |
| 10 | `    For lst = [1,3,5,7] the output should be 84` | `// For lst = [1,3,5,7] the output should be 84` |
| 11 | `    For lst = [1.4,4.2,0] the output should be 29` | `// For lst = [1.4,4.2,0] the output should be 29` |
| 12 | `    For lst = [-2.4,1,1] the output should be 6` | `// For lst = [-2.4,1,1] the output should be 6` |
| 13 | `    ` | `` |
| 14 | `` | `` |
| 15 | `    """` | `// ` |
