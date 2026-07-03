# CJ-HUMANEVAL-003: below_zero

- Source task: `HumanEval/3`
- Cangjie signature: `public func below_zero(operations: ArrayList<Int64>): Bool`
- Test calls expanded from official HumanEval: `6`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def below_zero(operations: List[int]) -> bool:` | `public func below_zero(operations: ArrayList<Int64>): Bool {` |
| 5 | `    """ You're given a list of deposit and withdrawal operations on a bank account that starts with` | `//  You're given a list of deposit and withdrawal operations on a bank account that starts with` |
| 6 | `    zero balance. Your task is to detect if at any point the balance of account fallls below zero, and` | `// zero balance. Your task is to detect if at any point the balance of account fallls below zero, and` |
| 7 | `    at that point function should return True. Otherwise it should return False.` | `// at that point function should return True. Otherwise it should return False.` |
| 8 | `    >>> below_zero([1, 2, 3])` | `// Example: below_zero([1, 2, 3])` |
| 9 | `    False` | `// False` |
| 10 | `    >>> below_zero([1, 2, -4, 5])` | `// Example: below_zero([1, 2, -4, 5])` |
| 11 | `    True` | `// True` |
| 12 | `    """` | `// ` |
