# CJ-HUMANEVAL-115: max_fill

- Source task: `HumanEval/115`
- Cangjie signature: `public func max_fill(grid: ArrayList<ArrayList<Int64>>, capacity: Int64): Int64`
- Test calls expanded from official HumanEval: `5`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def max_fill(grid, capacity):` | `public func max_fill(grid: ArrayList<ArrayList<Int64>>, capacity: Int64): Int64 {` |
| 3 | `    import math` | `// import math` |
| 4 | `    """` | `// ` |
| 5 | `    You are given a rectangular grid of wells. Each row represents a single well,` | `// You are given a rectangular grid of wells. Each row represents a single well,` |
| 6 | `    and each 1 in a row represents a single unit of water.` | `// and each 1 in a row represents a single unit of water.` |
| 7 | `    Each well has a corresponding bucket that can be used to extract water from it, ` | `// Each well has a corresponding bucket that can be used to extract water from it,` |
| 8 | `    and all buckets have the same capacity.` | `// and all buckets have the same capacity.` |
| 9 | `    Your task is to use the buckets to empty the wells.` | `// Your task is to use the buckets to empty the wells.` |
| 10 | `    Output the number of times you need to lower the buckets.` | `// Output the number of times you need to lower the buckets.` |
| 11 | `` | `` |
| 12 | `    Example 1:` | `// Example 1:` |
| 13 | `        Input: ` | `// Input:` |
| 14 | `            grid : [[0,0,1,0], [0,1,0,0], [1,1,1,1]]` | `// grid : [[0,0,1,0], [0,1,0,0], [1,1,1,1]]` |
| 15 | `            bucket_capacity : 1` | `// bucket_capacity : 1` |
| 16 | `        Output: 6` | `// Output: 6` |
| 17 | `` | `` |
| 18 | `    Example 2:` | `// Example 2:` |
| 19 | `        Input: ` | `// Input:` |
| 20 | `            grid : [[0,0,1,1], [0,0,0,0], [1,1,1,1], [0,1,1,1]]` | `// grid : [[0,0,1,1], [0,0,0,0], [1,1,1,1], [0,1,1,1]]` |
| 21 | `            bucket_capacity : 2` | `// bucket_capacity : 2` |
| 22 | `        Output: 5` | `// Output: 5` |
| 23 | `    ` | `` |
| 24 | `    Example 3:` | `// Example 3:` |
| 25 | `        Input: ` | `// Input:` |
| 26 | `            grid : [[0,0,0], [0,0,0]]` | `// grid : [[0,0,0], [0,0,0]]` |
| 27 | `            bucket_capacity : 5` | `// bucket_capacity : 5` |
| 28 | `        Output: 0` | `// Output: 0` |
| 29 | `` | `` |
| 30 | `    Constraints:` | `// Constraints:` |
| 31 | `        * all wells have the same length` | `// * all wells have the same length` |
| 32 | `        * 1 <= grid.length <= 10^2` | `// * 1 <= grid.length <= 10^2` |
| 33 | `        * 1 <= grid[:,1].length <= 10^2` | `// * 1 <= grid[:,1].length <= 10^2` |
| 34 | `        * grid[i][j] -> 0 \| 1` | `// * grid[i][j] -> 0 \| 1` |
| 35 | `        * 1 <= capacity <= 10` | `// * 1 <= capacity <= 10` |
| 36 | `    """` | `// ` |
