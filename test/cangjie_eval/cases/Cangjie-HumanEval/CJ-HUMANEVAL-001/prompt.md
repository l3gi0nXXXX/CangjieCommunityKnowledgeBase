# CJ-HUMANEVAL-001: separate_paren_groups

- Source task: `HumanEval/1`
- Cangjie signature: `public func separate_paren_groups(paren_string: String): ArrayList<String>`
- Test calls expanded from official HumanEval: `4`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def separate_paren_groups(paren_string: str) -> List[str]:` | `public func separate_paren_groups(paren_string: String): ArrayList<String> {` |
| 5 | `    """ Input to this function is a string containing multiple groups of nested parentheses. Your goal is to` | `//  Input to this function is a string containing multiple groups of nested parentheses. Your goal is to` |
| 6 | `    separate those group into separate strings and return the list of those.` | `// separate those group into separate strings and return the list of those.` |
| 7 | `    Separate groups are balanced (each open brace is properly closed) and not nested within each other` | `// Separate groups are balanced (each open brace is properly closed) and not nested within each other` |
| 8 | `    Ignore any spaces in the input string.` | `// Ignore any spaces in the input string.` |
| 9 | `    >>> separate_paren_groups('( ) (( )) (( )( ))')` | `// Example: separate_paren_groups('( ) (( )) (( )( ))')` |
| 10 | `    ['()', '(())', '(()())']` | `// ['()', '(())', '(()())']` |
| 11 | `    """` | `// ` |
