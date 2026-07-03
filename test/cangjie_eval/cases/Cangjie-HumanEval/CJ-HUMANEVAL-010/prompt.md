# CJ-HUMANEVAL-010: make_palindrome

- Source task: `HumanEval/10`
- Cangjie signature: `public func make_palindrome(string: String): String`
- Test calls expanded from official HumanEval: `5`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def is_palindrome(string: str) -> bool:` | `public func make_palindrome(string: String): String {` |
| 4 | `    """ Test if given string is a palindrome """` | `//  Test if given string is a palindrome ` |
| 5 | `    return string == string[::-1]` | `// return string == string[::-1]` |
| 6 | `` | `` |
| 7 | `` | `` |
| 8 | `def make_palindrome(string: str) -> str:` | `public func make_palindrome(string: String): String {` |
| 9 | `    """ Find the shortest palindrome that begins with a supplied string.` | `//  Find the shortest palindrome that begins with a supplied string.` |
| 10 | `    Algorithm idea is simple:` | `// Algorithm idea is simple:` |
| 11 | `    - Find the longest postfix of supplied string that is a palindrome.` | `// - Find the longest postfix of supplied string that is a palindrome.` |
| 12 | `    - Append to the end of the string reverse of a string prefix that comes before the palindromic suffix.` | `// - Append to the end of the string reverse of a string prefix that comes before the palindromic suffix.` |
| 13 | `    >>> make_palindrome('')` | `// Example: make_palindrome('')` |
| 14 | `    ''` | `// ''` |
| 15 | `    >>> make_palindrome('cat')` | `// Example: make_palindrome('cat')` |
| 16 | `    'catac'` | `// 'catac'` |
| 17 | `    >>> make_palindrome('cata')` | `// Example: make_palindrome('cata')` |
| 18 | `    'catac'` | `// 'catac'` |
| 19 | `    """` | `// ` |
