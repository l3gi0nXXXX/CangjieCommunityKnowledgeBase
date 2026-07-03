# CJ-HUMANEVAL-129: minPath

- Source task: `HumanEval/129`
- Cangjie signature: `public func minPath(grid: ArrayList<ArrayList<Int64>>, k: Int64): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `11`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def minPath(grid, k):` | `public func minPath(grid: ArrayList<ArrayList<Int64>>, k: Int64): ArrayList<Int64> {` |
| 3 | `    """` | `// ` |
| 4 | `    Given a grid with N rows and N columns (N >= 2) and a positive integer k, ` | `// Given a grid with N rows and N columns (N >= 2) and a positive integer k,` |
| 5 | `    each cell of the grid contains a value. Every integer in the range [1, N * N]` | `// each cell of the grid contains a value. Every integer in the range [1, N * N]` |
| 6 | `    inclusive appears exactly once on the cells of the grid.` | `// inclusive appears exactly once on the cells of the grid.` |
| 7 | `` | `` |
| 8 | `    You have to find the minimum path of length k in the grid. You can start` | `// You have to find the minimum path of length k in the grid. You can start` |
| 9 | `    from any cell, and in each step you can move to any of the neighbor cells,` | `// from any cell, and in each step you can move to any of the neighbor cells,` |
| 10 | `    in other words, you can go to cells which share an edge with you current` | `// in other words, you can go to cells which share an edge with you current` |
| 11 | `    cell.` | `// cell.` |
| 12 | `    Please note that a path of length k means visiting exactly k cells (not` | `// Please note that a path of length k means visiting exactly k cells (not` |
| 13 | `    necessarily distinct).` | `// necessarily distinct).` |
| 14 | `    You CANNOT go off the grid.` | `// You CANNOT go off the grid.` |
| 15 | `    A path A (of length k) is considered less than a path B (of length k) if` | `// A path A (of length k) is considered less than a path B (of length k) if` |
| 16 | `    after making the ordered lists of the values on the cells that A and B go` | `// after making the ordered lists of the values on the cells that A and B go` |
| 17 | `    through (let's call them lst_A and lst_B), lst_A is lexicographically less` | `// through (let's call them lst_A and lst_B), lst_A is lexicographically less` |
| 18 | `    than lst_B, in other words, there exist an integer index i (1 <= i <= k)` | `// than lst_B, in other words, there exist an integer index i (1 <= i <= k)` |
| 19 | `    such that lst_A[i] < lst_B[i] and for any j (1 <= j < i) we have` | `// such that lst_A[i] < lst_B[i] and for any j (1 <= j < i) we have` |
| 20 | `    lst_A[j] = lst_B[j].` | `// lst_A[j] = lst_B[j].` |
| 21 | `    It is guaranteed that the answer is unique.` | `// It is guaranteed that the answer is unique.` |
| 22 | `    Return an ordered list of the values on the cells that the minimum path go through.` | `// Return an ordered list of the values on the cells that the minimum path go through.` |
| 23 | `` | `` |
| 24 | `    Examples:` | `// Examples:` |
| 25 | `` | `` |
| 26 | `        Input: grid = [ [1,2,3], [4,5,6], [7,8,9]], k = 3` | `// Input: grid = [ [1,2,3], [4,5,6], [7,8,9]], k = 3` |
| 27 | `        Output: [1, 2, 1]` | `// Output: [1, 2, 1]` |
| 28 | `` | `` |
| 29 | `        Input: grid = [ [5,9,3], [4,1,6], [7,8,2]], k = 1` | `// Input: grid = [ [5,9,3], [4,1,6], [7,8,2]], k = 1` |
| 30 | `        Output: [1]` | `// Output: [1]` |
| 31 | `    """` | `// ` |
