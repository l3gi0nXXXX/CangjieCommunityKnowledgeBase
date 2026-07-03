# CJ-HUMANEVAL-126: is_sorted

- Source task: `HumanEval/126`
- Cangjie signature: `public func is_sorted(lst: ArrayList<Int64>): Bool`
- Test calls expanded from official HumanEval: `13`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def is_sorted(lst):` | `public func is_sorted(lst: ArrayList<Int64>): Bool {` |
| 3 | `    '''` | `// '''` |
| 4 | `    Given a list of numbers, return whether or not they are sorted` | `// Given a list of numbers, return whether or not they are sorted` |
| 5 | `    in ascending order. If list has more than 1 duplicate of the same` | `// in ascending order. If list has more than 1 duplicate of the same` |
| 6 | `    number, return False. Assume no negative numbers and only integers.` | `// number, return False. Assume no negative numbers and only integers.` |
| 7 | `` | `` |
| 8 | `    Examples` | `// Examples` |
| 9 | `    is_sorted([5]) ➞ True` | `// is_sorted([5]) ➞ True` |
| 10 | `    is_sorted([1, 2, 3, 4, 5]) ➞ True` | `// is_sorted([1, 2, 3, 4, 5]) ➞ True` |
| 11 | `    is_sorted([1, 3, 2, 4, 5]) ➞ False` | `// is_sorted([1, 3, 2, 4, 5]) ➞ False` |
| 12 | `    is_sorted([1, 2, 3, 4, 5, 6]) ➞ True` | `// is_sorted([1, 2, 3, 4, 5, 6]) ➞ True` |
| 13 | `    is_sorted([1, 2, 3, 4, 5, 6, 7]) ➞ True` | `// is_sorted([1, 2, 3, 4, 5, 6, 7]) ➞ True` |
| 14 | `    is_sorted([1, 3, 2, 4, 5, 6, 7]) ➞ False` | `// is_sorted([1, 3, 2, 4, 5, 6, 7]) ➞ False` |
| 15 | `    is_sorted([1, 2, 2, 3, 3, 4]) ➞ True` | `// is_sorted([1, 2, 2, 3, 3, 4]) ➞ True` |
| 16 | `    is_sorted([1, 2, 2, 2, 3, 4]) ➞ False` | `// is_sorted([1, 2, 2, 2, 3, 4]) ➞ False` |
| 17 | `    '''` | `// '''` |
