# CJ-HUMANEVAL-022: filter_integers

- Source task: `HumanEval/22`
- Cangjie signature: `public func filter_integers(values: ArrayList<EvalValue>): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `3`
- Static-language adaptations:
  - Python dynamic values are represented by EvalValue/EvalEntry helper types.
  - Python `bool` is an `int` subtype, but Cangjie `Bool` and `Int64` are distinct. This typed projection accepts only `EvalValue` values whose `kind` is `"int"`; it does not reproduce Python's bool-as-int subtype rule. The three official calls contain no Boolean value.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List, Any` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def filter_integers(values: List[Any]) -> List[int]:` | `public func filter_integers(values: ArrayList<EvalValue>): ArrayList<Int64> {` |
| 5 | `    """ Filter given list of any python values only for integers` | `//  Filter given list of any python values only for integers` |
| 6 | `    >>> filter_integers(['a', 3.14, 5])` | `// Example: filter_integers(['a', 3.14, 5])` |
| 7 | `    [5]` | `// [5]` |
| 8 | `    >>> filter_integers([1, 2, 3, 'abc', {}, []])` | `// Example: filter_integers([1, 2, 3, 'abc', {}, []])` |
| 9 | `    [1, 2, 3]` | `// [1, 2, 3]` |
| 10 | `    """` | `// ` |
