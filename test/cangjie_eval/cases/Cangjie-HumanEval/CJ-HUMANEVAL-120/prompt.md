# CJ-HUMANEVAL-120: maximum

- Source task: `HumanEval/120`
- Cangjie signature: `public func maximum(arr: ArrayList<Int64>, k: Int64): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `11`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def maximum(arr, k):` | `public func maximum(arr: ArrayList<Int64>, k: Int64): ArrayList<Int64> {` |
| 3 | `    """` | `// ` |
| 4 | `    Given an array arr of integers and a positive integer k, return a sorted list ` | `// Given an array arr of integers and a positive integer k, return a sorted list` |
| 5 | `    of length k with the maximum k numbers in arr.` | `// of length k with the maximum k numbers in arr.` |
| 6 | `` | `` |
| 7 | `    Example 1:` | `// Example 1:` |
| 8 | `` | `` |
| 9 | `        Input: arr = [-3, -4, 5], k = 3` | `// Input: arr = [-3, -4, 5], k = 3` |
| 10 | `        Output: [-4, -3, 5]` | `// Output: [-4, -3, 5]` |
| 11 | `` | `` |
| 12 | `    Example 2:` | `// Example 2:` |
| 13 | `` | `` |
| 14 | `        Input: arr = [4, -4, 4], k = 2` | `// Input: arr = [4, -4, 4], k = 2` |
| 15 | `        Output: [4, 4]` | `// Output: [4, 4]` |
| 16 | `` | `` |
| 17 | `    Example 3:` | `// Example 3:` |
| 18 | `` | `` |
| 19 | `        Input: arr = [-3, 2, 1, 2, -1, -2, 1], k = 1` | `// Input: arr = [-3, 2, 1, 2, -1, -2, 1], k = 1` |
| 20 | `        Output: [2]` | `// Output: [2]` |
| 21 | `` | `` |
| 22 | `    Note:` | `// Note:` |
| 23 | `        1. The length of the array will be in the range of [1, 1000].` | `// 1. The length of the array will be in the range of [1, 1000].` |
| 24 | `        2. The elements in the array will be in the range of [-1000, 1000].` | `// 2. The elements in the array will be in the range of [-1000, 1000].` |
| 25 | `        3. 0 <= k <= len(arr)` | `// 3. 0 <= k <= len(arr)` |
| 26 | `    """` | `// ` |
