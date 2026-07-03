# CJ-HUMANEVAL-073: smallest_change

- Source task: `HumanEval/73`
- Cangjie signature: `public func smallest_change(arr: ArrayList<Int64>): Int64`
- Test calls expanded from official HumanEval: `8`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def smallest_change(arr):` | `public func smallest_change(arr: ArrayList<Int64>): Int64 {` |
| 3 | `    """` | `// ` |
| 4 | `    Given an array arr of integers, find the minimum number of elements that` | `// Given an array arr of integers, find the minimum number of elements that` |
| 5 | `    need to be changed to make the array palindromic. A palindromic array is an array that` | `// need to be changed to make the array palindromic. A palindromic array is an array that` |
| 6 | `    is read the same backwards and forwards. In one change, you can change one element to any other element.` | `// is read the same backwards and forwards. In one change, you can change one element to any other element.` |
| 7 | `` | `` |
| 8 | `    For example:` | `// For example:` |
| 9 | `    smallest_change([1,2,3,5,4,7,9,6]) == 4` | `// smallest_change([1,2,3,5,4,7,9,6]) == 4` |
| 10 | `    smallest_change([1, 2, 3, 4, 3, 2, 2]) == 1` | `// smallest_change([1, 2, 3, 4, 3, 2, 2]) == 1` |
| 11 | `    smallest_change([1, 2, 3, 2, 1]) == 0` | `// smallest_change([1, 2, 3, 2, 1]) == 0` |
| 12 | `    """` | `// ` |
