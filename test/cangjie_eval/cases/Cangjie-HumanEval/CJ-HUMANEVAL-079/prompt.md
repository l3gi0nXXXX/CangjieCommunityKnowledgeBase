# CJ-HUMANEVAL-079: decimal_to_binary

- Source task: `HumanEval/79`
- Cangjie signature: `public func decimal_to_binary(decimal: Int64): String`
- Test calls expanded from official HumanEval: `4`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def decimal_to_binary(decimal):` | `public func decimal_to_binary(decimal: Int64): String {` |
| 3 | `    """You will be given a number in decimal form and your task is to convert it to` | `// You will be given a number in decimal form and your task is to convert it to` |
| 4 | `    binary format. The function should return a string, with each character representing a binary` | `// binary format. The function should return a string, with each character representing a binary` |
| 5 | `    number. Each character in the string will be '0' or '1'.` | `// number. Each character in the string will be '0' or '1'.` |
| 6 | `` | `` |
| 7 | `    There will be an extra couple of characters 'db' at the beginning and at the end of the string.` | `// There will be an extra couple of characters 'db' at the beginning and at the end of the string.` |
| 8 | `    The extra characters are there to help with the format.` | `// The extra characters are there to help with the format.` |
| 9 | `` | `` |
| 10 | `    Examples:` | `// Examples:` |
| 11 | `    decimal_to_binary(15)   # returns "db1111db"` | `// decimal_to_binary(15)   # returns "db1111db"` |
| 12 | `    decimal_to_binary(32)   # returns "db100000db"` | `// decimal_to_binary(32)   # returns "db100000db"` |
| 13 | `    """` | `// ` |
