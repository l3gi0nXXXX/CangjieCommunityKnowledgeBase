# CJ-HUMANEVAL-018: how_many_times

- Source task: `HumanEval/18`
- Cangjie signature: `public func how_many_times(string: String, substring: String): Int64`
- Test calls expanded from official HumanEval: `4`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def how_many_times(string: str, substring: str) -> int:` | `public func how_many_times(string: String, substring: String): Int64 {` |
| 4 | `    """ Find how many times a given substring can be found in the original string. Count overlaping cases.` | `//  Find how many times a given substring can be found in the original string. Count overlaping cases.` |
| 5 | `    >>> how_many_times('', 'a')` | `// Example: how_many_times('', 'a')` |
| 6 | `    0` | `// 0` |
| 7 | `    >>> how_many_times('aaa', 'a')` | `// Example: how_many_times('aaa', 'a')` |
| 8 | `    3` | `// 3` |
| 9 | `    >>> how_many_times('aaaa', 'aa')` | `// Example: how_many_times('aaaa', 'aa')` |
| 10 | `    3` | `// 3` |
| 11 | `    """` | `// ` |
