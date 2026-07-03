# CJ-HUMANEVAL-012: longest

- Source task: `HumanEval/12`
- Cangjie signature: `public func longest(strings: ArrayList<String>): Option<String>`
- Test calls expanded from official HumanEval: `3`
- Static-language adaptations:
  - Python None returns are represented by Option<T>.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List, Optional` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def longest(strings: List[str]) -> Optional[str]:` | `public func longest(strings: ArrayList<String>): Option<String> {` |
| 5 | `    """ Out of list of strings, return the longest one. Return the first one in case of multiple` | `//  Out of list of strings, return the longest one. Return the first one in case of multiple` |
| 6 | `    strings of the same length. Return None in case the input list is empty.` | `// strings of the same length. Return None in case the input list is empty.` |
| 7 | `    >>> longest([])` | `// Example: longest([])` |
| 8 | `` | `` |
| 9 | `    >>> longest(['a', 'b', 'c'])` | `// Example: longest(['a', 'b', 'c'])` |
| 10 | `    'a'` | `// 'a'` |
| 11 | `    >>> longest(['a', 'bb', 'ccc'])` | `// Example: longest(['a', 'bb', 'ccc'])` |
| 12 | `    'ccc'` | `// 'ccc'` |
| 13 | `    """` | `// ` |
