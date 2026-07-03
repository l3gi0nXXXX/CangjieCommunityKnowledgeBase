# CJ-HUMANEVAL-080: is_happy

- Source task: `HumanEval/80`
- Cangjie signature: `public func is_happy(s: String): Bool`
- Test calls expanded from official HumanEval: `8`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def is_happy(s):` | `public func is_happy(s: String): Bool {` |
| 3 | `    """You are given a string s.` | `// You are given a string s.` |
| 4 | `    Your task is to check if the string is happy or not.` | `// Your task is to check if the string is happy or not.` |
| 5 | `    A string is happy if its length is at least 3 and every 3 consecutive letters are distinct` | `// A string is happy if its length is at least 3 and every 3 consecutive letters are distinct` |
| 6 | `    For example:` | `// For example:` |
| 7 | `    is_happy(a) => False` | `// is_happy(a) => False` |
| 8 | `    is_happy(aa) => False` | `// is_happy(aa) => False` |
| 9 | `    is_happy(abcd) => True` | `// is_happy(abcd) => True` |
| 10 | `    is_happy(aabb) => False` | `// is_happy(aabb) => False` |
| 11 | `    is_happy(adb) => True` | `// is_happy(adb) => True` |
| 12 | `    is_happy(xyy) => False` | `// is_happy(xyy) => False` |
| 13 | `    """` | `// ` |
