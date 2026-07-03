# CJ-HUMANEVAL-007: filter_by_substring

- Source task: `HumanEval/7`
- Cangjie signature: `public func filter_by_substring(strings: ArrayList<String>, substring: String): ArrayList<String>`
- Test calls expanded from official HumanEval: `4`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def filter_by_substring(strings: List[str], substring: str) -> List[str]:` | `public func filter_by_substring(strings: ArrayList<String>, substring: String): ArrayList<String> {` |
| 5 | `    """ Filter an input list of strings only for ones that contain given substring` | `//  Filter an input list of strings only for ones that contain given substring` |
| 6 | `    >>> filter_by_substring([], 'a')` | `// Example: filter_by_substring([], 'a')` |
| 7 | `    []` | `// []` |
| 8 | `    >>> filter_by_substring(['abc', 'bacd', 'cde', 'array'], 'a')` | `// Example: filter_by_substring(['abc', 'bacd', 'cde', 'array'], 'a')` |
| 9 | `    ['abc', 'bacd', 'array']` | `// ['abc', 'bacd', 'array']` |
| 10 | `    """` | `// ` |
