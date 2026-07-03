# CJ-HUMANEVAL-113: odd_count

- Source task: `HumanEval/113`
- Cangjie signature: `public func odd_count(lst: ArrayList<String>): ArrayList<String>`
- Test calls expanded from official HumanEval: `3`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def odd_count(lst):` | `public func odd_count(lst: ArrayList<String>): ArrayList<String> {` |
| 3 | `    """Given a list of strings, where each string consists of only digits, return a list.` | `// Given a list of strings, where each string consists of only digits, return a list.` |
| 4 | `    Each element i of the output should be "the number of odd elements in the` | `// Each element i of the output should be "the number of odd elements in the` |
| 5 | `    string i of the input." where all the i's should be replaced by the number` | `// string i of the input." where all the i's should be replaced by the number` |
| 6 | `    of odd digits in the i'th string of the input.` | `// of odd digits in the i'th string of the input.` |
| 7 | `` | `` |
| 8 | `    >>> odd_count(['1234567'])` | `// Example: odd_count(['1234567'])` |
| 9 | `    ["the number of odd elements 4n the str4ng 4 of the 4nput."]` | `// ["the number of odd elements 4n the str4ng 4 of the 4nput."]` |
| 10 | `    >>> odd_count(['3',"11111111"])` | `// Example: odd_count(['3',"11111111"])` |
| 11 | `    ["the number of odd elements 1n the str1ng 1 of the 1nput.",` | `// ["the number of odd elements 1n the str1ng 1 of the 1nput.",` |
| 12 | `     "the number of odd elements 8n the str8ng 8 of the 8nput."]` | `// "the number of odd elements 8n the str8ng 8 of the 8nput."]` |
| 13 | `    """` | `// ` |
