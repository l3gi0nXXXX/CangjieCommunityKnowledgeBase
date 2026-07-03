# CJ-HUMANEVAL-069: search

- Source task: `HumanEval/69`
- Cangjie signature: `public func search(lst: ArrayList<Int64>): Int64`
- Test calls expanded from official HumanEval: `25`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def search(lst):` | `public func search(lst: ArrayList<Int64>): Int64 {` |
| 3 | `    '''` | `// '''` |
| 4 | `    You are given a non-empty list of positive integers. Return the greatest integer that is greater than ` | `// You are given a non-empty list of positive integers. Return the greatest integer that is greater than` |
| 5 | `    zero, and has a frequency greater than or equal to the value of the integer itself. ` | `// zero, and has a frequency greater than or equal to the value of the integer itself.` |
| 6 | `    The frequency of an integer is the number of times it appears in the list.` | `// The frequency of an integer is the number of times it appears in the list.` |
| 7 | `    If no such a value exist, return -1.` | `// If no such a value exist, return -1.` |
| 8 | `    Examples:` | `// Examples:` |
| 9 | `        search([4, 1, 2, 2, 3, 1]) == 2` | `// search([4, 1, 2, 2, 3, 1]) == 2` |
| 10 | `        search([1, 2, 2, 3, 3, 3, 4, 4, 4]) == 3` | `// search([1, 2, 2, 3, 3, 3, 4, 4, 4]) == 3` |
| 11 | `        search([5, 5, 4, 4, 4]) == -1` | `// search([5, 5, 4, 4, 4]) == -1` |
| 12 | `    '''` | `// '''` |
