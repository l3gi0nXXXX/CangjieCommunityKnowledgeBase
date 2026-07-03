# CJ-HUMANEVAL-132: is_nested

- Source task: `HumanEval/132`
- Cangjie signature: `public func is_nested(string: String): Bool`
- Test calls expanded from official HumanEval: `14`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def is_nested(string):` | `public func is_nested(string: String): Bool {` |
| 3 | `    '''` | `// '''` |
| 4 | `    Create a function that takes a string as input which contains only square brackets.` | `// Create a function that takes a string as input which contains only square brackets.` |
| 5 | `    The function should return True if and only if there is a valid subsequence of brackets ` | `// The function should return True if and only if there is a valid subsequence of brackets` |
| 6 | `    where at least one bracket in the subsequence is nested.` | `// where at least one bracket in the subsequence is nested.` |
| 7 | `` | `` |
| 8 | `    is_nested('[[]]') ➞ True` | `// is_nested('[[]]') ➞ True` |
| 9 | `    is_nested('[]]]]]]][[[[[]') ➞ False` | `// is_nested('[]]]]]]][[[[[]') ➞ False` |
| 10 | `    is_nested('[][]') ➞ False` | `// is_nested('[][]') ➞ False` |
| 11 | `    is_nested('[]') ➞ False` | `// is_nested('[]') ➞ False` |
| 12 | `    is_nested('[[][]]') ➞ True` | `// is_nested('[[][]]') ➞ True` |
| 13 | `    is_nested('[[]][[') ➞ True` | `// is_nested('[[]][[') ➞ True` |
| 14 | `    '''` | `// '''` |
