# CJ-HUMANEVAL-160: do_algebra

- Source task: `HumanEval/160`
- Cangjie signature: `public func do_algebra(operatorValue: ArrayList<String>, operand: ArrayList<Int64>): Int64`
- Test calls expanded from official HumanEval: `3`
- Static-language adaptations:
  - Python integer arithmetic uses arbitrary-precision intermediates. The scaffold imports `std.math.numeric.*`; construct each operand with `BigInt(Int64)`, keep `+`, `-`, `*`, division, and exponentiation intermediates as `BigInt`, and call `toInt64()` only once on the final result.
  - `BigInt /` truncates toward zero and `BigInt %` keeps the dividend's sign. To implement Python `//`, subtract one from a non-exact quotient when the operands have different signs.
  - `BigInt **` accepts a `UInt64` exponent. Convert only after proving the non-negative exponent fits `UInt64`; otherwise retain a `BigInt` exponent in a square-and-multiply helper. Exponentiation remains right-associative.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def do_algebra(operator, operand):` | `public func do_algebra(operatorValue: ArrayList<String>, operand: ArrayList<Int64>): Int64 {` |
| 3 | `    """` | `// ` |
| 4 | `    Given two lists operator, and operand. The first list has basic algebra operations, and ` | `// Given two lists operator, and operand. The first list has basic algebra operations, and` |
| 5 | `    the second list is a list of integers. Use the two given lists to build the algebric ` | `// the second list is a list of integers. Use the two given lists to build the algebric` |
| 6 | `    expression and return the evaluation of this expression.` | `// expression and return the evaluation of this expression.` |
| 7 | `` | `` |
| 8 | `    The basic algebra operations:` | `// The basic algebra operations:` |
| 9 | `    Addition ( + ) ` | `// Addition ( + )` |
| 10 | `    Subtraction ( - ) ` | `// Subtraction ( - )` |
| 11 | `    Multiplication ( * ) ` | `// Multiplication ( * )` |
| 12 | `    Floor division ( // ) ` | `// Floor division ( // )` |
| 13 | `    Exponentiation ( ** ) ` | `// Exponentiation ( ** )` |
| 14 | `` | `` |
| 15 | `    Example:` | `// Example:` |
| 16 | `    operator['+', '*', '-']` | `// operator['+', '*', '-']` |
| 17 | `    array = [2, 3, 4, 5]` | `// array = [2, 3, 4, 5]` |
| 18 | `    result = 2 + 3 * 4 - 5` | `// result = 2 + 3 * 4 - 5` |
| 19 | `    => result = 9` | `// => result = 9` |
| 20 | `` | `` |
| 21 | `    Note:` | `// Note:` |
| 22 | `        The length of operator list is equal to the length of operand list minus one.` | `// The length of operator list is equal to the length of operand list minus one.` |
| 23 | `        Operand is a list of of non-negative integers.` | `// Operand is a list of of non-negative integers.` |
| 24 | `        Operator list has at least one operator, and operand list has at least two operands.` | `// Operator list has at least one operator, and operand list has at least two operands.` |
| 25 | `` | `` |
| 26 | `    """` | `// ` |
