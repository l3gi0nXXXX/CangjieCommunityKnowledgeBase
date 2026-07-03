# CJ-HUMANEVAL-008: sum_product

- Source task: `HumanEval/8`
- Cangjie signature: `public func sum_product(numbers: ArrayList<Int64>): (Int64, Int64)`
- Test calls expanded from official HumanEval: `5`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List, Tuple` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def sum_product(numbers: List[int]) -> Tuple[int, int]:` | `public func sum_product(numbers: ArrayList<Int64>): (Int64, Int64) {` |
| 5 | `    """ For a given list of integers, return a tuple consisting of a sum and a product of all the integers in a list.` | `//  For a given list of integers, return a tuple consisting of a sum and a product of all the integers in a list.` |
| 6 | `    Empty sum should be equal to 0 and empty product should be equal to 1.` | `// Empty sum should be equal to 0 and empty product should be equal to 1.` |
| 7 | `    >>> sum_product([])` | `// Example: sum_product([])` |
| 8 | `    (0, 1)` | `// (0, 1)` |
| 9 | `    >>> sum_product([1, 2, 3, 4])` | `// Example: sum_product([1, 2, 3, 4])` |
| 10 | `    (10, 24)` | `// (10, 24)` |
| 11 | `    """` | `// ` |
