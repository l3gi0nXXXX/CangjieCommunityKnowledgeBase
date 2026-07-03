# CJ-HUMANEVAL-087: get_row

- Source task: `HumanEval/87`
- Cangjie signature: `public func get_row(lst: ArrayList<ArrayList<Int64>>, x: Int64): ArrayList<(Int64, Int64)>`
- Test calls expanded from official HumanEval: `6`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def get_row(lst, x):` | `public func get_row(lst: ArrayList<ArrayList<Int64>>, x: Int64): ArrayList<(Int64, Int64)> {` |
| 3 | `    """` | `// ` |
| 4 | `    You are given a 2 dimensional data, as a nested lists,` | `// You are given a 2 dimensional data, as a nested lists,` |
| 5 | `    which is similar to matrix, however, unlike matrices,` | `// which is similar to matrix, however, unlike matrices,` |
| 6 | `    each row may contain a different number of columns.` | `// each row may contain a different number of columns.` |
| 7 | `    Given lst, and integer x, find integers x in the list,` | `// Given lst, and integer x, find integers x in the list,` |
| 8 | `    and return list of tuples, [(x1, y1), (x2, y2) ...] such that` | `// and return list of tuples, [(x1, y1), (x2, y2) ...] such that` |
| 9 | `    each tuple is a coordinate - (row, columns), starting with 0.` | `// each tuple is a coordinate - (row, columns), starting with 0.` |
| 10 | `    Sort coordinates initially by rows in ascending order.` | `// Sort coordinates initially by rows in ascending order.` |
| 11 | `    Also, sort coordinates of the row by columns in descending order.` | `// Also, sort coordinates of the row by columns in descending order.` |
| 12 | `    ` | `` |
| 13 | `    Examples:` | `// Examples:` |
| 14 | `    get_row([` | `// get_row([` |
| 15 | `      [1,2,3,4,5,6],` | `// [1,2,3,4,5,6],` |
| 16 | `      [1,2,3,4,1,6],` | `// [1,2,3,4,1,6],` |
| 17 | `      [1,2,3,4,5,1]` | `// [1,2,3,4,5,1]` |
| 18 | `    ], 1) == [(0, 0), (1, 4), (1, 0), (2, 5), (2, 0)]` | `// ], 1) == [(0, 0), (1, 4), (1, 0), (2, 5), (2, 0)]` |
| 19 | `    get_row([], 1) == []` | `// get_row([], 1) == []` |
| 20 | `    get_row([[], [1], [1, 2, 3]], 3) == [(2, 2)]` | `// get_row([[], [1], [1, 2, 3]], 3) == [(2, 2)]` |
| 21 | `    """` | `// ` |
