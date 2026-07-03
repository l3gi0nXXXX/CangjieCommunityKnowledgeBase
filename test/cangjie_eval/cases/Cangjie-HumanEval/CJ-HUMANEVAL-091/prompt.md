# CJ-HUMANEVAL-091: is_bored

- Source task: `HumanEval/91`
- Cangjie signature: `public func is_bored(S: String): Int64`
- Test calls expanded from official HumanEval: `6`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def is_bored(S):` | `public func is_bored(S: String): Int64 {` |
| 3 | `    """` | `// ` |
| 4 | `    You'll be given a string of words, and your task is to count the number` | `// You'll be given a string of words, and your task is to count the number` |
| 5 | `    of boredoms. A boredom is a sentence that starts with the word "I".` | `// of boredoms. A boredom is a sentence that starts with the word "I".` |
| 6 | `    Sentences are delimited by '.', '?' or '!'.` | `// Sentences are delimited by '.', '?' or '!'.` |
| 7 | `   ` | `` |
| 8 | `    For example:` | `// For example:` |
| 9 | `    >>> is_bored("Hello world")` | `// Example: is_bored("Hello world")` |
| 10 | `    0` | `// 0` |
| 11 | `    >>> is_bored("The sky is blue. The sun is shining. I love this weather")` | `// Example: is_bored("The sky is blue. The sun is shining. I love this weather")` |
| 12 | `    1` | `// 1` |
| 13 | `    """` | `// ` |
