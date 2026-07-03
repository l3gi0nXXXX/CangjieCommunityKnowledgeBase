# CJ-HUMANEVAL-068: pluck

- Source task: `HumanEval/68`
- Cangjie signature: `public func pluck(arr: ArrayList<Int64>): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `8`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def pluck(arr):` | `public func pluck(arr: ArrayList<Int64>): ArrayList<Int64> {` |
| 3 | `    """` | `// ` |
| 4 | `    "Given an array representing a branch of a tree that has non-negative integer nodes` | `// "Given an array representing a branch of a tree that has non-negative integer nodes` |
| 5 | `    your task is to pluck one of the nodes and return it.` | `// your task is to pluck one of the nodes and return it.` |
| 6 | `    The plucked node should be the node with the smallest even value.` | `// The plucked node should be the node with the smallest even value.` |
| 7 | `    If multiple nodes with the same smallest even value are found return the node that has smallest index.` | `// If multiple nodes with the same smallest even value are found return the node that has smallest index.` |
| 8 | `` | `` |
| 9 | `    The plucked node should be returned in a list, [ smalest_value, its index ],` | `// The plucked node should be returned in a list, [ smalest_value, its index ],` |
| 10 | `    If there are no even values or the given array is empty, return [].` | `// If there are no even values or the given array is empty, return [].` |
| 11 | `` | `` |
| 12 | `    Example 1:` | `// Example 1:` |
| 13 | `        Input: [4,2,3]` | `// Input: [4,2,3]` |
| 14 | `        Output: [2, 1]` | `// Output: [2, 1]` |
| 15 | `        Explanation: 2 has the smallest even value, and 2 has the smallest index.` | `// Explanation: 2 has the smallest even value, and 2 has the smallest index.` |
| 16 | `` | `` |
| 17 | `    Example 2:` | `// Example 2:` |
| 18 | `        Input: [1,2,3]` | `// Input: [1,2,3]` |
| 19 | `        Output: [2, 1]` | `// Output: [2, 1]` |
| 20 | `        Explanation: 2 has the smallest even value, and 2 has the smallest index. ` | `// Explanation: 2 has the smallest even value, and 2 has the smallest index.` |
| 21 | `` | `` |
| 22 | `    Example 3:` | `// Example 3:` |
| 23 | `        Input: []` | `// Input: []` |
| 24 | `        Output: []` | `// Output: []` |
| 25 | `    ` | `` |
| 26 | `    Example 4:` | `// Example 4:` |
| 27 | `        Input: [5, 0, 3, 0, 4, 2]` | `// Input: [5, 0, 3, 0, 4, 2]` |
| 28 | `        Output: [0, 1]` | `// Output: [0, 1]` |
| 29 | `        Explanation: 0 is the smallest value, but  there are two zeros,` | `// Explanation: 0 is the smallest value, but  there are two zeros,` |
| 30 | `                     so we will choose the first zero, which has the smallest index.` | `// so we will choose the first zero, which has the smallest index.` |
| 31 | `` | `` |
| 32 | `    Constraints:` | `// Constraints:` |
| 33 | `        * 1 <= nodes.length <= 10000` | `// * 1 <= nodes.length <= 10000` |
| 34 | `        * 0 <= node.value` | `// * 0 <= node.value` |
| 35 | `    """` | `// ` |
