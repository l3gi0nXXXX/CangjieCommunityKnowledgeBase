# CJ-HUMANEVAL-028: concatenate

- Source task: `HumanEval/28`
- Cangjie signature: `public func concatenate(strings: ArrayList<String>): String`
- Test calls expanded from official HumanEval: `3`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def concatenate(strings: List[str]) -> str:` | `public func concatenate(strings: ArrayList<String>): String {` |
| 5 | `    """ Concatenate list of strings into a single string` | `//  Concatenate list of strings into a single string` |
| 6 | `    >>> concatenate([])` | `// Example: concatenate([])` |
| 7 | `    ''` | `// ''` |
| 8 | `    >>> concatenate(['a', 'b', 'c'])` | `// Example: concatenate(['a', 'b', 'c'])` |
| 9 | `    'abc'` | `// 'abc'` |
| 10 | `    """` | `// ` |
