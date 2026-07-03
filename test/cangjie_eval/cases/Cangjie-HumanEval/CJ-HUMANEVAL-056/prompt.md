# CJ-HUMANEVAL-056: correct_bracketing

- Source task: `HumanEval/56`
- Cangjie signature: `public func correct_bracketing(brackets: String): Bool`
- Test calls expanded from official HumanEval: `12`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def correct_bracketing(brackets: str):` | `public func correct_bracketing(brackets: String): Bool {` |
| 4 | `    """ brackets is a string of "<" and ">".` | `//  brackets is a string of "<" and ">".` |
| 5 | `    return True if every opening bracket has a corresponding closing bracket.` | `// return True if every opening bracket has a corresponding closing bracket.` |
| 6 | `` | `` |
| 7 | `    >>> correct_bracketing("<")` | `// Example: correct_bracketing("<")` |
| 8 | `    False` | `// False` |
| 9 | `    >>> correct_bracketing("<>")` | `// Example: correct_bracketing("<>")` |
| 10 | `    True` | `// True` |
| 11 | `    >>> correct_bracketing("<<><>>")` | `// Example: correct_bracketing("<<><>>")` |
| 12 | `    True` | `// True` |
| 13 | `    >>> correct_bracketing("><<>")` | `// Example: correct_bracketing("><<>")` |
| 14 | `    False` | `// False` |
| 15 | `    """` | `// ` |
