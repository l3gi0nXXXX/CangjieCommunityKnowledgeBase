# CJ-HUMANEVAL-137: compare_one

- Source task: `HumanEval/137`
- Cangjie signature: `public func compare_one(a: EvalValue, b: EvalValue): EvalValue`
- Test calls expanded from official HumanEval: `8`
- Static-language adaptations:
  - Python dynamic values are represented by EvalValue/EvalEntry helper types.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def compare_one(a, b):` | `public func compare_one(a: EvalValue, b: EvalValue): EvalValue {` |
| 3 | `    """` | `// ` |
| 4 | `    Create a function that takes integers, floats, or strings representing` | `// Create a function that takes integers, floats, or strings representing` |
| 5 | `    real numbers, and returns the larger variable in its given variable type.` | `// real numbers, and returns the larger variable in its given variable type.` |
| 6 | `    Return None if the values are equal.` | `// Return None if the values are equal.` |
| 7 | `    Note: If a real number is represented as a string, the floating point might be . or ,` | `// Note: If a real number is represented as a string, the floating point might be . or ,` |
| 8 | `` | `` |
| 9 | `    compare_one(1, 2.5) ➞ 2.5` | `// compare_one(1, 2.5) ➞ 2.5` |
| 10 | `    compare_one(1, "2,3") ➞ "2,3"` | `// compare_one(1, "2,3") ➞ "2,3"` |
| 11 | `    compare_one("5,1", "6") ➞ "6"` | `// compare_one("5,1", "6") ➞ "6"` |
| 12 | `    compare_one("1", 1) ➞ None` | `// compare_one("1", 1) ➞ None` |
| 13 | `    """` | `// ` |
