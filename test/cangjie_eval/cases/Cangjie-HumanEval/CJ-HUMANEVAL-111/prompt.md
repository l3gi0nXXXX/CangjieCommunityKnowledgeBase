# CJ-HUMANEVAL-111: histogram

- Source task: `HumanEval/111`
- Cangjie signature: `public func histogram(test: String): HashMap<String, Int64>`
- Test calls expanded from official HumanEval: `8`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def histogram(test):` | `public func histogram(test: String): HashMap<String, Int64> {` |
| 3 | `    """Given a string representing a space separated lowercase letters, return a dictionary` | `// Given a string representing a space separated lowercase letters, return a dictionary` |
| 4 | `    of the letter with the most repetition and containing the corresponding count.` | `// of the letter with the most repetition and containing the corresponding count.` |
| 5 | `    If several letters have the same occurrence, return all of them.` | `// If several letters have the same occurrence, return all of them.` |
| 6 | `    ` | `` |
| 7 | `    Example:` | `// Example:` |
| 8 | `    histogram('a b c') == {'a': 1, 'b': 1, 'c': 1}` | `// histogram('a b c') == {'a': 1, 'b': 1, 'c': 1}` |
| 9 | `    histogram('a b b a') == {'a': 2, 'b': 2}` | `// histogram('a b b a') == {'a': 2, 'b': 2}` |
| 10 | `    histogram('a b c a b') == {'a': 2, 'b': 2}` | `// histogram('a b c a b') == {'a': 2, 'b': 2}` |
| 11 | `    histogram('b b b b a') == {'b': 4}` | `// histogram('b b b b a') == {'b': 4}` |
| 12 | `    histogram('') == {}` | `// histogram('') == {}` |
| 13 | `` | `` |
| 14 | `    """` | `// ` |
