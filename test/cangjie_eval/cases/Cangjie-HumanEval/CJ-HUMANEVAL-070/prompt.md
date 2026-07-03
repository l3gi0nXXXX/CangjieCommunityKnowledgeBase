# CJ-HUMANEVAL-070: strange_sort_list

- Source task: `HumanEval/70`
- Cangjie signature: `public func strange_sort_list(lst: ArrayList<Int64>): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `9`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def strange_sort_list(lst):` | `public func strange_sort_list(lst: ArrayList<Int64>): ArrayList<Int64> {` |
| 3 | `    '''` | `// '''` |
| 4 | `    Given list of integers, return list in strange order.` | `// Given list of integers, return list in strange order.` |
| 5 | `    Strange sorting, is when you start with the minimum value,` | `// Strange sorting, is when you start with the minimum value,` |
| 6 | `    then maximum of the remaining integers, then minimum and so on.` | `// then maximum of the remaining integers, then minimum and so on.` |
| 7 | `` | `` |
| 8 | `    Examples:` | `// Examples:` |
| 9 | `    strange_sort_list([1, 2, 3, 4]) == [1, 4, 2, 3]` | `// strange_sort_list([1, 2, 3, 4]) == [1, 4, 2, 3]` |
| 10 | `    strange_sort_list([5, 5, 5, 5]) == [5, 5, 5, 5]` | `// strange_sort_list([5, 5, 5, 5]) == [5, 5, 5, 5]` |
| 11 | `    strange_sort_list([]) == []` | `// strange_sort_list([]) == []` |
| 12 | `    '''` | `// '''` |
