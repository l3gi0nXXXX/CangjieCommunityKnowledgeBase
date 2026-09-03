# CJ-HUMANEVAL-162: string_to_md5

- Source task: `HumanEval/162`
- Cangjie signature: `public func string_to_md5(text: String): Option<String>`
- Test calls expanded from official HumanEval: `4`
- Static-language adaptations:
  - Python None returns are represented by Option<T>.
  - The scaffold provides the official equivalent of `hashlib.md5(text.encode()).hexdigest()`: import `std.crypto.digest.digest`, `stdx.crypto.digest.MD5`, and `stdx.encoding.hex.toHexString`, then call `toHexString(digest(MD5(), text.toArray()))`. `String.toArray()` supplies UTF-8 bytes and the result is a lowercase 32-character hexadecimal string.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def string_to_md5(text):` | `public func string_to_md5(text: String): Option<String> {` |
| 3 | `    """` | `// ` |
| 4 | `    Given a string 'text', return its md5 hash equivalent string.` | `// Given a string 'text', return its md5 hash equivalent string.` |
| 5 | `    If 'text' is an empty string, return None.` | `// If 'text' is an empty string, return None.` |
| 6 | `` | `` |
| 7 | `    >>> string_to_md5('Hello world') == '3e25960a79dbc69b674cd4ec67a72c62'` | `// Example: string_to_md5('Hello world') == '3e25960a79dbc69b674cd4ec67a72c62'` |
| 8 | `    """` | `// ` |
