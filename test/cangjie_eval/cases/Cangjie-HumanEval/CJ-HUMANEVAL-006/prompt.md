# CJ-HUMANEVAL-006: parse_nested_parens

- Source task: `HumanEval/6`
- Cangjie signature: `public func parse_nested_parens(paren_string: String): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `3`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def parse_nested_parens(paren_string: str) -> List[int]:` | `public func parse_nested_parens(paren_string: String): ArrayList<Int64> {` |
| 5 | `    """ Input to this function is a string represented multiple groups for nested parentheses separated by spaces.` | `//  Input to this function is a string represented multiple groups for nested parentheses separated by spaces.` |
| 6 | `    For each of the group, output the deepest level of nesting of parentheses.` | `// For each of the group, output the deepest level of nesting of parentheses.` |
| 7 | `    E.g. (()()) has maximum two levels of nesting while ((())) has three.` | `// E.g. (()()) has maximum two levels of nesting while ((())) has three.` |
| 8 | `` | `` |
| 9 | `    >>> parse_nested_parens('(()()) ((())) () ((())()())')` | `// Example: parse_nested_parens('(()()) ((())) () ((())()())')` |
| 10 | `    [2, 3, 1, 3]` | `// [2, 3, 1, 3]` |
| 11 | `    """` | `// ` |
