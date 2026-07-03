# CJ-HUMANEVAL-145: order_by_points

- Source task: `HumanEval/145`
- Cangjie signature: `public func order_by_points(nums: ArrayList<Int64>): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `6`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def order_by_points(nums):` | `public func order_by_points(nums: ArrayList<Int64>): ArrayList<Int64> {` |
| 3 | `    """` | `// ` |
| 4 | `    Write a function which sorts the given list of integers` | `// Write a function which sorts the given list of integers` |
| 5 | `    in ascending order according to the sum of their digits.` | `// in ascending order according to the sum of their digits.` |
| 6 | `    Note: if there are several items with similar sum of their digits,` | `// Note: if there are several items with similar sum of their digits,` |
| 7 | `    order them based on their index in original list.` | `// order them based on their index in original list.` |
| 8 | `` | `` |
| 9 | `    For example:` | `// For example:` |
| 10 | `    >>> order_by_points([1, 11, -1, -11, -12]) == [-1, -11, 1, -12, 11]` | `// Example: order_by_points([1, 11, -1, -11, -12]) == [-1, -11, 1, -12, 11]` |
| 11 | `    >>> order_by_points([]) == []` | `// Example: order_by_points([]) == []` |
| 12 | `    """` | `// ` |
