# CJ-HUMANEVAL-105: by_length

- Source task: `HumanEval/105`
- Cangjie signature: `public func by_length(arr: ArrayList<Int64>): ArrayList<String>`
- Test calls expanded from official HumanEval: `5`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def by_length(arr):` | `public func by_length(arr: ArrayList<Int64>): ArrayList<String> {` |
| 3 | `    """` | `// ` |
| 4 | `    Given an array of integers, sort the integers that are between 1 and 9 inclusive,` | `// Given an array of integers, sort the integers that are between 1 and 9 inclusive,` |
| 5 | `    reverse the resulting array, and then replace each digit by its corresponding name from` | `// reverse the resulting array, and then replace each digit by its corresponding name from` |
| 6 | `    "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine".` | `// "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine".` |
| 7 | `` | `` |
| 8 | `    For example:` | `// For example:` |
| 9 | `      arr = [2, 1, 1, 4, 5, 8, 2, 3]   ` | `// arr = [2, 1, 1, 4, 5, 8, 2, 3]` |
| 10 | `            -> sort arr -> [1, 1, 2, 2, 3, 4, 5, 8] ` | `// -> sort arr -> [1, 1, 2, 2, 3, 4, 5, 8]` |
| 11 | `            -> reverse arr -> [8, 5, 4, 3, 2, 2, 1, 1]` | `// -> reverse arr -> [8, 5, 4, 3, 2, 2, 1, 1]` |
| 12 | `      return ["Eight", "Five", "Four", "Three", "Two", "Two", "One", "One"]` | `// return ["Eight", "Five", "Four", "Three", "Two", "Two", "One", "One"]` |
| 13 | `    ` | `` |
| 14 | `      If the array is empty, return an empty array:` | `// If the array is empty, return an empty array:` |
| 15 | `      arr = []` | `// arr = []` |
| 16 | `      return []` | `// return []` |
| 17 | `    ` | `` |
| 18 | `      If the array has any strange number ignore it:` | `// If the array has any strange number ignore it:` |
| 19 | `      arr = [1, -1 , 55] ` | `// arr = [1, -1 , 55]` |
| 20 | `            -> sort arr -> [-1, 1, 55]` | `// -> sort arr -> [-1, 1, 55]` |
| 21 | `            -> reverse arr -> [55, 1, -1]` | `// -> reverse arr -> [55, 1, -1]` |
| 22 | `      return = ['One']` | `// return = ['One']` |
| 23 | `    """` | `// ` |
