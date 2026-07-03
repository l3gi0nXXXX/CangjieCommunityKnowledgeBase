# CJ-HUMANEVAL-054: same_chars

- Source task: `HumanEval/54`
- Cangjie signature: `public func same_chars(s0: String, s1: String): Bool`
- Test calls expanded from official HumanEval: `7`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def same_chars(s0: str, s1: str):` | `public func same_chars(s0: String, s1: String): Bool {` |
| 4 | `    """` | `// ` |
| 5 | `    Check if two words have the same characters.` | `// Check if two words have the same characters.` |
| 6 | `    >>> same_chars('eabcdzzzz', 'dddzzzzzzzddeddabc')` | `// Example: same_chars('eabcdzzzz', 'dddzzzzzzzddeddabc')` |
| 7 | `    True` | `// True` |
| 8 | `    >>> same_chars('abcd', 'dddddddabc')` | `// Example: same_chars('abcd', 'dddddddabc')` |
| 9 | `    True` | `// True` |
| 10 | `    >>> same_chars('dddddddabc', 'abcd')` | `// Example: same_chars('dddddddabc', 'abcd')` |
| 11 | `    True` | `// True` |
| 12 | `    >>> same_chars('eabcd', 'dddddddabc')` | `// Example: same_chars('eabcd', 'dddddddabc')` |
| 13 | `    False` | `// False` |
| 14 | `    >>> same_chars('abcd', 'dddddddabce')` | `// Example: same_chars('abcd', 'dddddddabce')` |
| 15 | `    False` | `// False` |
| 16 | `    >>> same_chars('eabcdzzzz', 'dddzzzzzzzddddabc')` | `// Example: same_chars('eabcdzzzz', 'dddzzzzzzzddddabc')` |
| 17 | `    False` | `// False` |
| 18 | `    """` | `// ` |
