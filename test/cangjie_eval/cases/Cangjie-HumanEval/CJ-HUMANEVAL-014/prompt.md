# CJ-HUMANEVAL-014: all_prefixes

- Source task: `HumanEval/14`
- Cangjie signature: `public func all_prefixes(string: String): ArrayList<String>`
- Test calls expanded from official HumanEval: `3`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def all_prefixes(string: str) -> List[str]:` | `public func all_prefixes(string: String): ArrayList<String> {` |
| 5 | `    """ Return list of all prefixes from shortest to longest of the input string` | `//  Return list of all prefixes from shortest to longest of the input string` |
| 6 | `    >>> all_prefixes('abc')` | `// Example: all_prefixes('abc')` |
| 7 | `    ['a', 'ab', 'abc']` | `// ['a', 'ab', 'abc']` |
| 8 | `    """` | `// ` |
