# CJ-HUMANEVAL-067: fruit_distribution

- Source task: `HumanEval/67`
- Cangjie signature: `public func fruit_distribution(s: String, n: Int64): Int64`
- Test calls expanded from official HumanEval: `7`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def fruit_distribution(s,n):` | `public func fruit_distribution(s: String, n: Int64): Int64 {` |
| 3 | `    """` | `// ` |
| 4 | `    In this task, you will be given a string that represents a number of apples and oranges ` | `// In this task, you will be given a string that represents a number of apples and oranges` |
| 5 | `    that are distributed in a basket of fruit this basket contains ` | `// that are distributed in a basket of fruit this basket contains` |
| 6 | `    apples, oranges, and mango fruits. Given the string that represents the total number of ` | `// apples, oranges, and mango fruits. Given the string that represents the total number of` |
| 7 | `    the oranges and apples and an integer that represent the total number of the fruits ` | `// the oranges and apples and an integer that represent the total number of the fruits` |
| 8 | `    in the basket return the number of the mango fruits in the basket.` | `// in the basket return the number of the mango fruits in the basket.` |
| 9 | `    for examble:` | `// for examble:` |
| 10 | `    fruit_distribution("5 apples and 6 oranges", 19) ->19 - 5 - 6 = 8` | `// fruit_distribution("5 apples and 6 oranges", 19) ->19 - 5 - 6 = 8` |
| 11 | `    fruit_distribution("0 apples and 1 oranges",3) -> 3 - 0 - 1 = 2` | `// fruit_distribution("0 apples and 1 oranges",3) -> 3 - 0 - 1 = 2` |
| 12 | `    fruit_distribution("2 apples and 3 oranges", 100) -> 100 - 2 - 3 = 95` | `// fruit_distribution("2 apples and 3 oranges", 100) -> 100 - 2 - 3 = 95` |
| 13 | `    fruit_distribution("100 apples and 1 oranges",120) -> 120 - 100 - 1 = 19` | `// fruit_distribution("100 apples and 1 oranges",120) -> 120 - 100 - 1 = 19` |
| 14 | `    """` | `// ` |
