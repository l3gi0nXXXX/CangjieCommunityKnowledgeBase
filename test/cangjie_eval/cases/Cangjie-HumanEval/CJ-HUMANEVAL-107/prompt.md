# CJ-HUMANEVAL-107: even_odd_palindrome

- Source task: `HumanEval/107`
- Cangjie signature: `public func even_odd_palindrome(n: Int64): (Int64, Int64)`
- Test calls expanded from official HumanEval: `8`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def even_odd_palindrome(n):` | `public func even_odd_palindrome(n: Int64): (Int64, Int64) {` |
| 3 | `    """` | `// ` |
| 4 | `    Given a positive integer n, return a tuple that has the number of even and odd` | `// Given a positive integer n, return a tuple that has the number of even and odd` |
| 5 | `    integer palindromes that fall within the range(1, n), inclusive.` | `// integer palindromes that fall within the range(1, n), inclusive.` |
| 6 | `` | `` |
| 7 | `    Example 1:` | `// Example 1:` |
| 8 | `` | `` |
| 9 | `        Input: 3` | `// Input: 3` |
| 10 | `        Output: (1, 2)` | `// Output: (1, 2)` |
| 11 | `        Explanation:` | `// Explanation:` |
| 12 | `        Integer palindrome are 1, 2, 3. one of them is even, and two of them are odd.` | `// Integer palindrome are 1, 2, 3. one of them is even, and two of them are odd.` |
| 13 | `` | `` |
| 14 | `    Example 2:` | `// Example 2:` |
| 15 | `` | `` |
| 16 | `        Input: 12` | `// Input: 12` |
| 17 | `        Output: (4, 6)` | `// Output: (4, 6)` |
| 18 | `        Explanation:` | `// Explanation:` |
| 19 | `        Integer palindrome are 1, 2, 3, 4, 5, 6, 7, 8, 9, 11. four of them are even, and 6 of them are odd.` | `// Integer palindrome are 1, 2, 3, 4, 5, 6, 7, 8, 9, 11. four of them are even, and 6 of them are odd.` |
| 20 | `` | `` |
| 21 | `    Note:` | `// Note:` |
| 22 | `        1. 1 <= n <= 10^3` | `// 1. 1 <= n <= 10^3` |
| 23 | `        2. returned tuple has the number of even and odd integer palindromes respectively.` | `// 2. returned tuple has the number of even and odd integer palindromes respectively.` |
| 24 | `    """` | `// ` |
