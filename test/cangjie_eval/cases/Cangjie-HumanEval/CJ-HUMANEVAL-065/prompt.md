# CJ-HUMANEVAL-065: circular_shift

- Source task: `HumanEval/65`
- Cangjie signature: `public func circular_shift(x: Int64, shift: Int64): String`
- Test calls expanded from official HumanEval: `5`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def circular_shift(x, shift):` | `public func circular_shift(x: Int64, shift: Int64): String {` |
| 3 | `    """Circular shift the digits of the integer x, shift the digits right by shift` | `// Circular shift the digits of the integer x, shift the digits right by shift` |
| 4 | `    and return the result as a string.` | `// and return the result as a string.` |
| 5 | `    If shift > number of digits, return digits reversed.` | `// If shift > number of digits, return digits reversed.` |
| 6 | `    >>> circular_shift(12, 1)` | `// Example: circular_shift(12, 1)` |
| 7 | `    "21"` | `// "21"` |
| 8 | `    >>> circular_shift(12, 2)` | `// Example: circular_shift(12, 2)` |
| 9 | `    "12"` | `// "12"` |
| 10 | `    """` | `// ` |
