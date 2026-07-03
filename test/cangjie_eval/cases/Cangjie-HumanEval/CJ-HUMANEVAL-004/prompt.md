# CJ-HUMANEVAL-004: mean_absolute_deviation

- Source task: `HumanEval/4`
- Cangjie signature: `public func mean_absolute_deviation(numbers: ArrayList<Float64>): Float64`
- Test calls expanded from official HumanEval: `3`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def mean_absolute_deviation(numbers: List[float]) -> float:` | `public func mean_absolute_deviation(numbers: ArrayList<Float64>): Float64 {` |
| 5 | `    """ For a given list of input numbers, calculate Mean Absolute Deviation` | `//  For a given list of input numbers, calculate Mean Absolute Deviation` |
| 6 | `    around the mean of this dataset.` | `// around the mean of this dataset.` |
| 7 | `    Mean Absolute Deviation is the average absolute difference between each` | `// Mean Absolute Deviation is the average absolute difference between each` |
| 8 | `    element and a centerpoint (mean in this case):` | `// element and a centerpoint (mean in this case):` |
| 9 | `    MAD = average \| x - x_mean \|` | `// MAD = average \| x - x_mean \|` |
| 10 | `    >>> mean_absolute_deviation([1.0, 2.0, 3.0, 4.0])` | `// Example: mean_absolute_deviation([1.0, 2.0, 3.0, 4.0])` |
| 11 | `    1.0` | `// 1.0` |
| 12 | `    """` | `// ` |
