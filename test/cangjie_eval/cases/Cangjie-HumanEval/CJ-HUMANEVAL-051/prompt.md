# CJ-HUMANEVAL-051: remove_vowels

- Source task: `HumanEval/51`
- Cangjie signature: `public func remove_vowels(text: String): String`
- Test calls expanded from official HumanEval: `7`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def remove_vowels(text):` | `public func remove_vowels(text: String): String {` |
| 4 | `    """` | `// ` |
| 5 | `    remove_vowels is a function that takes string and returns string without vowels.` | `// remove_vowels is a function that takes string and returns string without vowels.` |
| 6 | `    >>> remove_vowels('')` | `// Example: remove_vowels('')` |
| 7 | `    ''` | `// ''` |
| 8 | `    >>> remove_vowels("abcdef\nghijklm")` | `// Example: remove_vowels("abcdef\nghijklm")` |
| 9 | `    'bcdf\nghjklm'` | `// 'bcdf\nghjklm'` |
| 10 | `    >>> remove_vowels('abcdef')` | `// Example: remove_vowels('abcdef')` |
| 11 | `    'bcdf'` | `// 'bcdf'` |
| 12 | `    >>> remove_vowels('aaaaa')` | `// Example: remove_vowels('aaaaa')` |
| 13 | `    ''` | `// ''` |
| 14 | `    >>> remove_vowels('aaBAA')` | `// Example: remove_vowels('aaBAA')` |
| 15 | `    'B'` | `// 'B'` |
| 16 | `    >>> remove_vowels('zbcd')` | `// Example: remove_vowels('zbcd')` |
| 17 | `    'zbcd'` | `// 'zbcd'` |
| 18 | `    """` | `// ` |
