# CJ-HUMANEVAL-072: will_it_fly

- Source task: `HumanEval/72`
- Cangjie signature: `public func will_it_fly(q: ArrayList<Int64>, w: Int64): Bool`
- Test calls expanded from official HumanEval: `6`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def will_it_fly(q,w):` | `public func will_it_fly(q: ArrayList<Int64>, w: Int64): Bool {` |
| 3 | `    '''` | `// '''` |
| 4 | `    Write a function that returns True if the object q will fly, and False otherwise.` | `// Write a function that returns True if the object q will fly, and False otherwise.` |
| 5 | `    The object q will fly if it's balanced (it is a palindromic list) and the sum of its elements is less than or equal the maximum possible weight w.` | `// The object q will fly if it's balanced (it is a palindromic list) and the sum of its elements is less than or equal the maximum possible weight w.` |
| 6 | `` | `` |
| 7 | `    Example:` | `// Example:` |
| 8 | `    will_it_fly([1, 2], 5) ➞ False ` | `// will_it_fly([1, 2], 5) ➞ False` |
| 9 | `    # 1+2 is less than the maximum possible weight, but it's unbalanced.` | `// # 1+2 is less than the maximum possible weight, but it's unbalanced.` |
| 10 | `` | `` |
| 11 | `    will_it_fly([3, 2, 3], 1) ➞ False` | `// will_it_fly([3, 2, 3], 1) ➞ False` |
| 12 | `    # it's balanced, but 3+2+3 is more than the maximum possible weight.` | `// # it's balanced, but 3+2+3 is more than the maximum possible weight.` |
| 13 | `` | `` |
| 14 | `    will_it_fly([3, 2, 3], 9) ➞ True` | `// will_it_fly([3, 2, 3], 9) ➞ True` |
| 15 | `    # 3+2+3 is less than the maximum possible weight, and it's balanced.` | `// # 3+2+3 is less than the maximum possible weight, and it's balanced.` |
| 16 | `` | `` |
| 17 | `    will_it_fly([3], 5) ➞ True` | `// will_it_fly([3], 5) ➞ True` |
| 18 | `    # 3 is less than the maximum possible weight, and it's balanced.` | `// # 3 is less than the maximum possible weight, and it's balanced.` |
| 19 | `    '''` | `// '''` |
