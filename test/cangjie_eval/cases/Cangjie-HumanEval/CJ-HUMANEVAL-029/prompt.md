# CJ-HUMANEVAL-029: filter_by_prefix

- Source task: `HumanEval/29`
- Cangjie signature: `public func filter_by_prefix(strings: ArrayList<String>, prefix: String): ArrayList<String>`
- Test calls expanded from official HumanEval: `2`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def filter_by_prefix(strings: List[str], prefix: str) -> List[str]:` | `public func filter_by_prefix(strings: ArrayList<String>, prefix: String): ArrayList<String> {` |
| 5 | `    """ Filter an input list of strings only for ones that start with a given prefix.` | `//  Filter an input list of strings only for ones that start with a given prefix.` |
| 6 | `    >>> filter_by_prefix([], 'a')` | `// Example: filter_by_prefix([], 'a')` |
| 7 | `    []` | `// []` |
| 8 | `    >>> filter_by_prefix(['abc', 'bcd', 'cde', 'array'], 'a')` | `// Example: filter_by_prefix(['abc', 'bcd', 'cde', 'array'], 'a')` |
| 9 | `    ['abc', 'array']` | `// ['abc', 'array']` |
| 10 | `    """` | `// ` |
