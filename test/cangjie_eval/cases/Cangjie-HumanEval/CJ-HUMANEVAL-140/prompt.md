# CJ-HUMANEVAL-140: fix_spaces

- Source task: `HumanEval/140`
- Cangjie signature: `public func fix_spaces(text: String): String`
- Test calls expanded from official HumanEval: `5`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def fix_spaces(text):` | `public func fix_spaces(text: String): String {` |
| 3 | `    """` | `// ` |
| 4 | `    Given a string text, replace all spaces in it with underscores, ` | `// Given a string text, replace all spaces in it with underscores,` |
| 5 | `    and if a string has more than 2 consecutive spaces, ` | `// and if a string has more than 2 consecutive spaces,` |
| 6 | `    then replace all consecutive spaces with - ` | `// then replace all consecutive spaces with -` |
| 7 | `    ` | `` |
| 8 | `    fix_spaces("Example") == "Example"` | `// fix_spaces("Example") == "Example"` |
| 9 | `    fix_spaces("Example 1") == "Example_1"` | `// fix_spaces("Example 1") == "Example_1"` |
| 10 | `    fix_spaces(" Example 2") == "_Example_2"` | `// fix_spaces(" Example 2") == "_Example_2"` |
| 11 | `    fix_spaces(" Example   3") == "_Example-3"` | `// fix_spaces(" Example   3") == "_Example-3"` |
| 12 | `    """` | `// ` |
