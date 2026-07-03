# CJ-HUMANEVAL-086: anti_shuffle

- Source task: `HumanEval/86`
- Cangjie signature: `public func anti_shuffle(s: String): String`
- Test calls expanded from official HumanEval: `7`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def anti_shuffle(s):` | `public func anti_shuffle(s: String): String {` |
| 3 | `    """` | `// ` |
| 4 | `    Write a function that takes a string and returns an ordered version of it.` | `// Write a function that takes a string and returns an ordered version of it.` |
| 5 | `    Ordered version of string, is a string where all words (separated by space)` | `// Ordered version of string, is a string where all words (separated by space)` |
| 6 | `    are replaced by a new word where all the characters arranged in` | `// are replaced by a new word where all the characters arranged in` |
| 7 | `    ascending order based on ascii value.` | `// ascending order based on ascii value.` |
| 8 | `    Note: You should keep the order of words and blank spaces in the sentence.` | `// Note: You should keep the order of words and blank spaces in the sentence.` |
| 9 | `` | `` |
| 10 | `    For example:` | `// For example:` |
| 11 | `    anti_shuffle('Hi') returns 'Hi'` | `// anti_shuffle('Hi') returns 'Hi'` |
| 12 | `    anti_shuffle('hello') returns 'ehllo'` | `// anti_shuffle('hello') returns 'ehllo'` |
| 13 | `    anti_shuffle('Hello World!!!') returns 'Hello !!!Wdlor'` | `// anti_shuffle('Hello World!!!') returns 'Hello !!!Wdlor'` |
| 14 | `    """` | `// ` |
