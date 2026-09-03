# CJ-HUMANEVAL-161: solve

- Source task: `HumanEval/161`
- Cangjie signature: `public func solve(s: String): String`
- Test calls expanded from official HumanEval plus Unicode/emoji boundaries: `10`
- Static-language adaptations:
  - The completion-only starter imports std.unicode.* so Rune.toLowerCase(), Rune.toUpperCase(), and Rune.isLetter() are available without modifying the file prologue.
  - Iterate the input by Rune boundaries; direct String iteration exposes UTF-8 bytes and cannot safely implement Unicode case conversion or no-letter reversal.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def solve(s):` | `public func solve(s: String): String {` |
| 3 | `    """You are given a string s.` | `// You are given a string s.` |
| 4 | `    if s[i] is a letter, reverse its case from lower to upper or vise versa, ` | `// if s[i] is a letter, reverse its case from lower to upper or vise versa,` |
| 5 | `    otherwise keep it as it is.` | `// otherwise keep it as it is.` |
| 6 | `    If the string contains no letters, reverse the string.` | `// If the string contains no letters, reverse the string.` |
| 7 | `    The function should return the resulted string.` | `// The function should return the resulted string.` |
| 8 | `    Examples` | `// Examples` |
| 9 | `    solve("1234") = "4321"` | `// solve("1234") = "4321"` |
| 10 | `    solve("ab") = "AB"` | `// solve("ab") = "AB"` |
| 11 | `    solve("#a@C") = "#A@c"` | `// solve("#a@C") = "#A@c"` |
| 12 | `    """` | `// ` |
