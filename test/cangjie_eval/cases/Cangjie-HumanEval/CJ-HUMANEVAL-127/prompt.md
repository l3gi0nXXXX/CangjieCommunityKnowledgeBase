# CJ-HUMANEVAL-127: intersection

- Source task: `HumanEval/127`
- Cangjie signature: `public func intersection(interval1: (Int64, Int64), interval2: (Int64, Int64)): String`
- Test calls expanded from official HumanEval: `8`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def intersection(interval1, interval2):` | `public func intersection(interval1: (Int64, Int64), interval2: (Int64, Int64)): String {` |
| 3 | `    """You are given two intervals,` | `// You are given two intervals,` |
| 4 | `    where each interval is a pair of integers. For example, interval = (start, end) = (1, 2).` | `// where each interval is a pair of integers. For example, interval = (start, end) = (1, 2).` |
| 5 | `    The given intervals are closed which means that the interval (start, end)` | `// The given intervals are closed which means that the interval (start, end)` |
| 6 | `    includes both start and end.` | `// includes both start and end.` |
| 7 | `    For each given interval, it is assumed that its start is less or equal its end.` | `// For each given interval, it is assumed that its start is less or equal its end.` |
| 8 | `    Your task is to determine whether the length of intersection of these two ` | `// Your task is to determine whether the length of intersection of these two` |
| 9 | `    intervals is a prime number.` | `// intervals is a prime number.` |
| 10 | `    Example, the intersection of the intervals (1, 3), (2, 4) is (2, 3)` | `// Example, the intersection of the intervals (1, 3), (2, 4) is (2, 3)` |
| 11 | `    which its length is 1, which not a prime number.` | `// which its length is 1, which not a prime number.` |
| 12 | `    If the length of the intersection is a prime number, return "YES",` | `// If the length of the intersection is a prime number, return "YES",` |
| 13 | `    otherwise, return "NO".` | `// otherwise, return "NO".` |
| 14 | `    If the two intervals don't intersect, return "NO".` | `// If the two intervals don't intersect, return "NO".` |
| 15 | `` | `` |
| 16 | `` | `` |
| 17 | `    [input/output] samples:` | `// [input/output] samples:` |
| 18 | `    intersection((1, 2), (2, 3)) ==> "NO"` | `// intersection((1, 2), (2, 3)) ==> "NO"` |
| 19 | `    intersection((-1, 1), (0, 4)) ==> "NO"` | `// intersection((-1, 1), (0, 4)) ==> "NO"` |
| 20 | `    intersection((-3, -1), (-5, 5)) ==> "YES"` | `// intersection((-3, -1), (-5, 5)) ==> "YES"` |
| 21 | `    """` | `// ` |
