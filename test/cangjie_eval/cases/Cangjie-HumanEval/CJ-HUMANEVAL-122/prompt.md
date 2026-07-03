# CJ-HUMANEVAL-122: add_elements

- Source task: `HumanEval/122`
- Cangjie signature: `public func add_elements(arr: ArrayList<Int64>, k: Int64): Int64`
- Test calls expanded from official HumanEval: `5`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def add_elements(arr, k):` | `public func add_elements(arr: ArrayList<Int64>, k: Int64): Int64 {` |
| 3 | `    """` | `// ` |
| 4 | `    Given a non-empty array of integers arr and an integer k, return` | `// Given a non-empty array of integers arr and an integer k, return` |
| 5 | `    the sum of the elements with at most two digits from the first k elements of arr.` | `// the sum of the elements with at most two digits from the first k elements of arr.` |
| 6 | `` | `` |
| 7 | `    Example:` | `// Example:` |
| 8 | `` | `` |
| 9 | `        Input: arr = [111,21,3,4000,5,6,7,8,9], k = 4` | `// Input: arr = [111,21,3,4000,5,6,7,8,9], k = 4` |
| 10 | `        Output: 24 # sum of 21 + 3` | `// Output: 24 # sum of 21 + 3` |
| 11 | `` | `` |
| 12 | `    Constraints:` | `// Constraints:` |
| 13 | `        1. 1 <= len(arr) <= 100` | `// 1. 1 <= len(arr) <= 100` |
| 14 | `        2. 1 <= k <= len(arr)` | `// 2. 1 <= k <= len(arr)` |
| 15 | `    """` | `// ` |
