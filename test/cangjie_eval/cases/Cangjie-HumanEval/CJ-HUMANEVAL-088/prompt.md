# CJ-HUMANEVAL-088: sort_array

- Source task: `HumanEval/88`
- Cangjie signature: `public func sort_array(array: ArrayList<Int64>): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `7`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def sort_array(array):` | `public func sort_array(array: ArrayList<Int64>): ArrayList<Int64> {` |
| 3 | `    """` | `// ` |
| 4 | `    Given an array of non-negative integers, return a copy of the given array after sorting,` | `// Given an array of non-negative integers, return a copy of the given array after sorting,` |
| 5 | `    you will sort the given array in ascending order if the sum( first index value, last index value) is odd,` | `// you will sort the given array in ascending order if the sum( first index value, last index value) is odd,` |
| 6 | `    or sort it in descending order if the sum( first index value, last index value) is even.` | `// or sort it in descending order if the sum( first index value, last index value) is even.` |
| 7 | `` | `` |
| 8 | `    Note:` | `// Note:` |
| 9 | `    * don't change the given array.` | `// * don't change the given array.` |
| 10 | `` | `` |
| 11 | `    Examples:` | `// Examples:` |
| 12 | `    * sort_array([]) => []` | `// * sort_array([]) => []` |
| 13 | `    * sort_array([5]) => [5]` | `// * sort_array([5]) => [5]` |
| 14 | `    * sort_array([2, 4, 3, 0, 1, 5]) => [0, 1, 2, 3, 4, 5]` | `// * sort_array([2, 4, 3, 0, 1, 5]) => [0, 1, 2, 3, 4, 5]` |
| 15 | `    * sort_array([2, 4, 3, 0, 1, 5, 6]) => [6, 5, 4, 3, 2, 1, 0]` | `// * sort_array([2, 4, 3, 0, 1, 5, 6]) => [6, 5, 4, 3, 2, 1, 0]` |
| 16 | `    """` | `// ` |
