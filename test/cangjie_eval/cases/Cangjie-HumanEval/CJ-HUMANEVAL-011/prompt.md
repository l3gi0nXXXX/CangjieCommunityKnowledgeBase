# CJ-HUMANEVAL-011: string_xor

- Source task: `HumanEval/11`
- Cangjie signature: `public func string_xor(a: String, b: String): String`
- Test calls expanded from official HumanEval: `3`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def string_xor(a: str, b: str) -> str:` | `public func string_xor(a: String, b: String): String {` |
| 5 | `    """ Input are two strings a and b consisting only of 1s and 0s.` | `//  Input are two strings a and b consisting only of 1s and 0s.` |
| 6 | `    Perform binary XOR on these inputs and return result also as a string.` | `// Perform binary XOR on these inputs and return result also as a string.` |
| 7 | `    >>> string_xor('010', '110')` | `// Example: string_xor('010', '110')` |
| 8 | `    '100'` | `// '100'` |
| 9 | `    """` | `// ` |
