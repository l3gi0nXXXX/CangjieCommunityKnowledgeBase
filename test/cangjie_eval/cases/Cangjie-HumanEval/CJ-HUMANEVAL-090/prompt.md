# CJ-HUMANEVAL-090: next_smallest

- Source task: `HumanEval/90`
- Cangjie signature: `public func next_smallest(lst: ArrayList<Int64>): Option<Int64>`
- Test calls expanded from official HumanEval: `7`
- Static-language adaptations:
  - Python None returns are represented by Option<T>.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def next_smallest(lst):` | `public func next_smallest(lst: ArrayList<Int64>): Option<Int64> {` |
| 3 | `    """` | `// ` |
| 4 | `    You are given a list of integers.` | `// You are given a list of integers.` |
| 5 | `    Write a function next_smallest() that returns the 2nd smallest element of the list.` | `// Write a function next_smallest() that returns the 2nd smallest element of the list.` |
| 6 | `    Return None if there is no such element.` | `// Return None if there is no such element.` |
| 7 | `    ` | `` |
| 8 | `    next_smallest([1, 2, 3, 4, 5]) == 2` | `// next_smallest([1, 2, 3, 4, 5]) == 2` |
| 9 | `    next_smallest([5, 1, 4, 3, 2]) == 2` | `// next_smallest([5, 1, 4, 3, 2]) == 2` |
| 10 | `    next_smallest([]) == None` | `// next_smallest([]) == None` |
| 11 | `    next_smallest([1, 1]) == None` | `// next_smallest([1, 1]) == None` |
| 12 | `    """` | `// ` |
