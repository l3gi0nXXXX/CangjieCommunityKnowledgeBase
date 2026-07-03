# CJ-HUMANEVAL-074: total_match

- Source task: `HumanEval/74`
- Cangjie signature: `public func total_match(lst1: ArrayList<String>, lst2: ArrayList<String>): ArrayList<String>`
- Test calls expanded from official HumanEval: `9`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def total_match(lst1, lst2):` | `public func total_match(lst1: ArrayList<String>, lst2: ArrayList<String>): ArrayList<String> {` |
| 3 | `    '''` | `// '''` |
| 4 | `    Write a function that accepts two lists of strings and returns the list that has ` | `// Write a function that accepts two lists of strings and returns the list that has` |
| 5 | `    total number of chars in the all strings of the list less than the other list.` | `// total number of chars in the all strings of the list less than the other list.` |
| 6 | `` | `` |
| 7 | `    if the two lists have the same number of chars, return the first list.` | `// if the two lists have the same number of chars, return the first list.` |
| 8 | `` | `` |
| 9 | `    Examples` | `// Examples` |
| 10 | `    total_match([], []) ➞ []` | `// total_match([], []) ➞ []` |
| 11 | `    total_match(['hi', 'admin'], ['hI', 'Hi']) ➞ ['hI', 'Hi']` | `// total_match(['hi', 'admin'], ['hI', 'Hi']) ➞ ['hI', 'Hi']` |
| 12 | `    total_match(['hi', 'admin'], ['hi', 'hi', 'admin', 'project']) ➞ ['hi', 'admin']` | `// total_match(['hi', 'admin'], ['hi', 'hi', 'admin', 'project']) ➞ ['hi', 'admin']` |
| 13 | `    total_match(['hi', 'admin'], ['hI', 'hi', 'hi']) ➞ ['hI', 'hi', 'hi']` | `// total_match(['hi', 'admin'], ['hI', 'hi', 'hi']) ➞ ['hI', 'hi', 'hi']` |
| 14 | `    total_match(['4'], ['1', '2', '3', '4', '5']) ➞ ['4']` | `// total_match(['4'], ['1', '2', '3', '4', '5']) ➞ ['4']` |
| 15 | `    '''` | `// '''` |
