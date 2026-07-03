# CJ-HUMANEVAL-119: match_parens

- Source task: `HumanEval/119`
- Cangjie signature: `public func match_parens(lst: ArrayList<String>): String`
- Test calls expanded from official HumanEval: `12`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def match_parens(lst):` | `public func match_parens(lst: ArrayList<String>): String {` |
| 3 | `    '''` | `// '''` |
| 4 | `    You are given a list of two strings, both strings consist of open` | `// You are given a list of two strings, both strings consist of open` |
| 5 | `    parentheses '(' or close parentheses ')' only.` | `// parentheses '(' or close parentheses ')' only.` |
| 6 | `    Your job is to check if it is possible to concatenate the two strings in` | `// Your job is to check if it is possible to concatenate the two strings in` |
| 7 | `    some order, that the resulting string will be good.` | `// some order, that the resulting string will be good.` |
| 8 | `    A string S is considered to be good if and only if all parentheses in S` | `// A string S is considered to be good if and only if all parentheses in S` |
| 9 | `    are balanced. For example: the string '(())()' is good, while the string` | `// are balanced. For example: the string '(())()' is good, while the string` |
| 10 | `    '())' is not.` | `// '())' is not.` |
| 11 | `    Return 'Yes' if there's a way to make a good string, and return 'No' otherwise.` | `// Return 'Yes' if there's a way to make a good string, and return 'No' otherwise.` |
| 12 | `` | `` |
| 13 | `    Examples:` | `// Examples:` |
| 14 | `    match_parens(['()(', ')']) == 'Yes'` | `// match_parens(['()(', ')']) == 'Yes'` |
| 15 | `    match_parens([')', ')']) == 'No'` | `// match_parens([')', ')']) == 'No'` |
| 16 | `    '''` | `// '''` |
