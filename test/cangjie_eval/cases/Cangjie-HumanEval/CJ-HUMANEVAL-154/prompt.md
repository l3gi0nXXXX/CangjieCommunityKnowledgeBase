# CJ-HUMANEVAL-154: cycpattern_check

- Source task: `HumanEval/154`
- Cangjie signature: `public func cycpattern_check(a: String, b: String): Bool`
- Test calls expanded from official HumanEval: `6`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def cycpattern_check(a , b):` | `public func cycpattern_check(a: String, b: String): Bool {` |
| 3 | `    """You are given 2 words. You need to return True if the second word or any of its rotations is a substring in the first word` | `// You are given 2 words. You need to return True if the second word or any of its rotations is a substring in the first word` |
| 4 | `    cycpattern_check("abcd","abd") => False` | `// cycpattern_check("abcd","abd") => False` |
| 5 | `    cycpattern_check("hello","ell") => True` | `// cycpattern_check("hello","ell") => True` |
| 6 | `    cycpattern_check("whassup","psus") => False` | `// cycpattern_check("whassup","psus") => False` |
| 7 | `    cycpattern_check("abab","baa") => True` | `// cycpattern_check("abab","baa") => True` |
| 8 | `    cycpattern_check("efef","eeff") => False` | `// cycpattern_check("efef","eeff") => False` |
| 9 | `    cycpattern_check("himenss","simen") => True` | `// cycpattern_check("himenss","simen") => True` |
| 10 | `` | `` |
| 11 | `    """` | `// ` |
