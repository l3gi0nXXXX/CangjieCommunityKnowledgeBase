# CJ-HUMANEVAL-044: change_base

- Source task: `HumanEval/44`
- Cangjie signature: `public func change_base(x: Int64, base: Int64): String`
- Test calls expanded from official HumanEval: `12`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def change_base(x: int, base: int):` | `public func change_base(x: Int64, base: Int64): String {` |
| 4 | `    """Change numerical base of input number x to base.` | `// Change numerical base of input number x to base.` |
| 5 | `    return string representation after the conversion.` | `// return string representation after the conversion.` |
| 6 | `    base numbers are less than 10.` | `// base numbers are less than 10.` |
| 7 | `    >>> change_base(8, 3)` | `// Example: change_base(8, 3)` |
| 8 | `    '22'` | `// '22'` |
| 9 | `    >>> change_base(8, 2)` | `// Example: change_base(8, 2)` |
| 10 | `    '1000'` | `// '1000'` |
| 11 | `    >>> change_base(7, 2)` | `// Example: change_base(7, 2)` |
| 12 | `    '111'` | `// '111'` |
| 13 | `    """` | `// ` |
