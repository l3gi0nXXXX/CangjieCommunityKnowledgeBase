# CJ-HUMANEVAL-151: double_the_difference

- Source task: `HumanEval/151`
- Cangjie signature: `public func double_the_difference(lst: ArrayList<EvalValue>): Int64`
- Test calls expanded from official HumanEval plus type-identity adaptation checks: `9`
- Static-language adaptations:
  - Python int and float identities are preserved with EvalValue tags.
  - Only values with `kind == "int"` are Python integers; a float-tagged value such as `evalFloat(3.0)` must be ignored.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def double_the_difference(lst):` | `public func double_the_difference(lst: ArrayList<EvalValue>): Int64 {` |
| 3 | `    '''` | `// '''` |
| 4 | `    Given a list of numbers, return the sum of squares of the numbers` | `// Given a list of numbers, return the sum of squares of the numbers` |
| 5 | `    in the list that are odd. Ignore numbers that are negative or not integers.` | `// in the list that are odd. Ignore numbers that are negative or not integers.` |
| 6 | `    ` | `` |
| 7 | `    double_the_difference([1, 3, 2, 0]) == 1 + 9 + 0 + 0 = 10` | `// double_the_difference([1, 3, 2, 0]) == 1 + 9 + 0 + 0 = 10` |
| 8 | `    double_the_difference([-1, -2, 0]) == 0` | `// double_the_difference([-1, -2, 0]) == 0` |
| 9 | `    double_the_difference([9, -2]) == 81` | `// double_the_difference([9, -2]) == 81` |
| 10 | `    double_the_difference([0]) == 0  ` | `// double_the_difference([0]) == 0` |
| 11 | `   ` | `` |
| 12 | `    If the input list is empty, return 0.` | `// If the input list is empty, return 0.` |
| 13 | `    '''` | `// '''` |
