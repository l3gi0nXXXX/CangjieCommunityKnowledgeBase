# CJ-HUMANEVAL-099: closest_integer

- Source task: `HumanEval/99`
- Cangjie signature: `public func closest_integer(value: String): Int64`
- Test calls expanded from official HumanEval: `5`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def closest_integer(value):` | `public func closest_integer(value: String): Int64 {` |
| 3 | `    '''` | `// '''` |
| 4 | `    Create a function that takes a value (string) representing a number` | `// Create a function that takes a value (string) representing a number` |
| 5 | `    and returns the closest integer to it. If the number is equidistant` | `// and returns the closest integer to it. If the number is equidistant` |
| 6 | `    from two integers, round it away from zero.` | `// from two integers, round it away from zero.` |
| 7 | `` | `` |
| 8 | `    Examples` | `// Examples` |
| 9 | `    >>> closest_integer("10")` | `// Example: closest_integer("10")` |
| 10 | `    10` | `// 10` |
| 11 | `    >>> closest_integer("15.3")` | `// Example: closest_integer("15.3")` |
| 12 | `    15` | `// 15` |
| 13 | `` | `` |
| 14 | `    Note:` | `// Note:` |
| 15 | `    Rounding away from zero means that if the given number is equidistant` | `// Rounding away from zero means that if the given number is equidistant` |
| 16 | `    from two integers, the one you should return is the one that is the` | `// from two integers, the one you should return is the one that is the` |
| 17 | `    farthest from zero. For example closest_integer("14.5") should` | `// farthest from zero. For example closest_integer("14.5") should` |
| 18 | `    return 15 and closest_integer("-14.5") should return -15.` | `// return 15 and closest_integer("-14.5") should return -15.` |
| 19 | `    '''` | `// '''` |
