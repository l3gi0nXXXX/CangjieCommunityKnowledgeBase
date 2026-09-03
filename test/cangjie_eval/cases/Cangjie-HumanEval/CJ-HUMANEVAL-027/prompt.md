# CJ-HUMANEVAL-027: flip_case

- Source task: `HumanEval/27`
- Cangjie signature: `public func flip_case(string: String): String`
- Test calls expanded from official HumanEval plus Unicode/emoji boundaries: `5`
- Static-language adaptations:
  - The completion-only starter imports `std.unicode.*` without requiring changes to the file prologue.
  - Iterate the input by Rune boundaries; direct String iteration exposes UTF-8 bytes and is not suitable for Unicode case conversion.
  - String.toUpper(CasingOption.Other) and String.toLower(CasingOption.Other) return String and preserve full Unicode mappings that may expand one Rune to multiple Runes; Rune.toUpperCase() and Rune.toLowerCase() return only one Rune.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def flip_case(string: str) -> str:` | `public func flip_case(string: String): String {` |
| 4 | `    """ For a given string, flip lowercase characters to uppercase and uppercase to lowercase.` | `//  For a given string, flip lowercase characters to uppercase and uppercase to lowercase.` |
| 5 | `    >>> flip_case('Hello')` | `// Example: flip_case('Hello')` |
| 6 | `    'hELLO'` | `// 'hELLO'` |
| 7 | `    """` | `// ` |
