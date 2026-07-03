# CJ-HUMANEVAL-112: reverse_delete

- Source task: `HumanEval/112`
- Cangjie signature: `public func reverse_delete(s: String, c: String): (String, Bool)`
- Test calls expanded from official HumanEval: `9`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def reverse_delete(s,c):` | `public func reverse_delete(s: String, c: String): (String, Bool) {` |
| 3 | `    """Task` | `// Task` |
| 4 | `    We are given two strings s and c, you have to deleted all the characters in s that are equal to any character in c` | `// We are given two strings s and c, you have to deleted all the characters in s that are equal to any character in c` |
| 5 | `    then check if the result string is palindrome.` | `// then check if the result string is palindrome.` |
| 6 | `    A string is called palindrome if it reads the same backward as forward.` | `// A string is called palindrome if it reads the same backward as forward.` |
| 7 | `    You should return a tuple containing the result string and True/False for the check.` | `// You should return a tuple containing the result string and True/False for the check.` |
| 8 | `    Example` | `// Example` |
| 9 | `    For s = "abcde", c = "ae", the result should be ('bcd',False)` | `// For s = "abcde", c = "ae", the result should be ('bcd',False)` |
| 10 | `    For s = "abcdef", c = "b"  the result should be ('acdef',False)` | `// For s = "abcdef", c = "b"  the result should be ('acdef',False)` |
| 11 | `    For s = "abcdedcba", c = "ab", the result should be ('cdedc',True)` | `// For s = "abcdedcba", c = "ab", the result should be ('cdedc',True)` |
| 12 | `    """` | `// ` |
