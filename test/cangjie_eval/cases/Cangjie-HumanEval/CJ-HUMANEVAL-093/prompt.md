# CJ-HUMANEVAL-093: encode

- Source task: `HumanEval/93`
- Cangjie signature: `public func encode(message: String): String`
- Test calls expanded from official HumanEval: `5`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def encode(message):` | `public func encode(message: String): String {` |
| 3 | `    """` | `// ` |
| 4 | `    Write a function that takes a message, and encodes in such a ` | `// Write a function that takes a message, and encodes in such a` |
| 5 | `    way that it swaps case of all letters, replaces all vowels in ` | `// way that it swaps case of all letters, replaces all vowels in` |
| 6 | `    the message with the letter that appears 2 places ahead of that ` | `// the message with the letter that appears 2 places ahead of that` |
| 7 | `    vowel in the english alphabet. ` | `// vowel in the english alphabet.` |
| 8 | `    Assume only letters. ` | `// Assume only letters.` |
| 9 | `    ` | `` |
| 10 | `    Examples:` | `// Examples:` |
| 11 | `    >>> encode('test')` | `// Example: encode('test')` |
| 12 | `    'TGST'` | `// 'TGST'` |
| 13 | `    >>> encode('This is a message')` | `// Example: encode('This is a message')` |
| 14 | `    'tHKS KS C MGSSCGG'` | `// 'tHKS KS C MGSSCGG'` |
| 15 | `    """` | `// ` |
