# CJ-HUMANEVAL-019: sort_numbers

- Source task: `HumanEval/19`
- Cangjie signature: `public func sort_numbers(numbers: String): String`
- Test calls expanded from official HumanEval: `5`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def sort_numbers(numbers: str) -> str:` | `public func sort_numbers(numbers: String): String {` |
| 5 | `    """ Input is a space-delimited string of numberals from 'zero' to 'nine'.` | `//  Input is a space-delimited string of numberals from 'zero' to 'nine'.` |
| 6 | `    Valid choices are 'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight' and 'nine'.` | `// Valid choices are 'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight' and 'nine'.` |
| 7 | `    Return the string with numbers sorted from smallest to largest` | `// Return the string with numbers sorted from smallest to largest` |
| 8 | `    >>> sort_numbers('three one five')` | `// Example: sort_numbers('three one five')` |
| 9 | `    'one three five'` | `// 'one three five'` |
| 10 | `    """` | `// ` |
