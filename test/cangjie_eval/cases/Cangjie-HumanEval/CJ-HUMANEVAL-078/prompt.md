# CJ-HUMANEVAL-078: hex_key

- Source task: `HumanEval/78`
- Cangjie signature: `public func hex_key(num: String): Int64`
- Test calls expanded from official HumanEval: `7`
- Static-language adaptations:
  - The official empty-list edge input is translated to the empty string because the task parameter is a hexadecimal string.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def hex_key(num):` | `public func hex_key(num: String): Int64 {` |
| 3 | `    """You have been tasked to write a function that receives ` | `// You have been tasked to write a function that receives` |
| 4 | `    a hexadecimal number as a string and counts the number of hexadecimal ` | `// a hexadecimal number as a string and counts the number of hexadecimal` |
| 5 | `    digits that are primes (prime number, or a prime, is a natural number ` | `// digits that are primes (prime number, or a prime, is a natural number` |
| 6 | `    greater than 1 that is not a product of two smaller natural numbers).` | `// greater than 1 that is not a product of two smaller natural numbers).` |
| 7 | `    Hexadecimal digits are 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, A, B, C, D, E, F.` | `// Hexadecimal digits are 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, A, B, C, D, E, F.` |
| 8 | `    Prime numbers are 2, 3, 5, 7, 11, 13, 17,...` | `// Prime numbers are 2, 3, 5, 7, 11, 13, 17,...` |
| 9 | `    So you have to determine a number of the following digits: 2, 3, 5, 7, ` | `// So you have to determine a number of the following digits: 2, 3, 5, 7,` |
| 10 | `    B (=decimal 11), D (=decimal 13).` | `// B (=decimal 11), D (=decimal 13).` |
| 11 | `    Note: you may assume the input is always correct or empty string, ` | `// Note: you may assume the input is always correct or empty string,` |
| 12 | `    and symbols A,B,C,D,E,F are always uppercase.` | `// and symbols A,B,C,D,E,F are always uppercase.` |
| 13 | `    Examples:` | `// Examples:` |
| 14 | `    For num = "AB" the output should be 1.` | `// For num = "AB" the output should be 1.` |
| 15 | `    For num = "1077E" the output should be 2.` | `// For num = "1077E" the output should be 2.` |
| 16 | `    For num = "ABED1A33" the output should be 4.` | `// For num = "ABED1A33" the output should be 4.` |
| 17 | `    For num = "123456789ABCDEF0" the output should be 6.` | `// For num = "123456789ABCDEF0" the output should be 6.` |
| 18 | `    For num = "2020" the output should be 2.` | `// For num = "2020" the output should be 2.` |
| 19 | `    """` | `// ` |
