# CJ-HUMANEVAL-102: choose_num

- Source task: `HumanEval/102`
- Cangjie signature: `public func choose_num(x: Int64, y: Int64): Int64`
- Test calls expanded from official HumanEval: `8`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def choose_num(x, y):` | `public func choose_num(x: Int64, y: Int64): Int64 {` |
| 3 | `    """This function takes two positive numbers x and y and returns the` | `// This function takes two positive numbers x and y and returns the` |
| 4 | `    biggest even integer number that is in the range [x, y] inclusive. If ` | `// biggest even integer number that is in the range [x, y] inclusive. If` |
| 5 | `    there's no such number, then the function should return -1.` | `// there's no such number, then the function should return -1.` |
| 6 | `` | `` |
| 7 | `    For example:` | `// For example:` |
| 8 | `    choose_num(12, 15) = 14` | `// choose_num(12, 15) = 14` |
| 9 | `    choose_num(13, 12) = -1` | `// choose_num(13, 12) = -1` |
| 10 | `    """` | `// ` |
