# CJ-HUMANEVAL-159: eat

- Source task: `HumanEval/159`
- Cangjie signature: `public func eat(number: Int64, need: Int64, remaining: Int64): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `6`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def eat(number, need, remaining):` | `public func eat(number: Int64, need: Int64, remaining: Int64): ArrayList<Int64> {` |
| 3 | `    """` | `// ` |
| 4 | `    You're a hungry rabbit, and you already have eaten a certain number of carrots,` | `// You're a hungry rabbit, and you already have eaten a certain number of carrots,` |
| 5 | `    but now you need to eat more carrots to complete the day's meals.` | `// but now you need to eat more carrots to complete the day's meals.` |
| 6 | `    you should return an array of [ total number of eaten carrots after your meals,` | `// you should return an array of [ total number of eaten carrots after your meals,` |
| 7 | `                                    the number of carrots left after your meals ]` | `// the number of carrots left after your meals ]` |
| 8 | `    if there are not enough remaining carrots, you will eat all remaining carrots, but will still be hungry.` | `// if there are not enough remaining carrots, you will eat all remaining carrots, but will still be hungry.` |
| 9 | `    ` | `` |
| 10 | `    Example:` | `// Example:` |
| 11 | `    * eat(5, 6, 10) -> [11, 4]` | `// * eat(5, 6, 10) -> [11, 4]` |
| 12 | `    * eat(4, 8, 9) -> [12, 1]` | `// * eat(4, 8, 9) -> [12, 1]` |
| 13 | `    * eat(1, 10, 10) -> [11, 0]` | `// * eat(1, 10, 10) -> [11, 0]` |
| 14 | `    * eat(2, 11, 5) -> [7, 0]` | `// * eat(2, 11, 5) -> [7, 0]` |
| 15 | `    ` | `` |
| 16 | `    Variables:` | `// Variables:` |
| 17 | `    @number : integer` | `// @number : integer` |
| 18 | `        the number of carrots that you have eaten.` | `// the number of carrots that you have eaten.` |
| 19 | `    @need : integer` | `// @need : integer` |
| 20 | `        the number of carrots that you need to eat.` | `// the number of carrots that you need to eat.` |
| 21 | `    @remaining : integer` | `// @remaining : integer` |
| 22 | `        the number of remaining carrots thet exist in stock` | `// the number of remaining carrots thet exist in stock` |
| 23 | `    ` | `` |
| 24 | `    Constrain:` | `// Constrain:` |
| 25 | `    * 0 <= number <= 1000` | `// * 0 <= number <= 1000` |
| 26 | `    * 0 <= need <= 1000` | `// * 0 <= need <= 1000` |
| 27 | `    * 0 <= remaining <= 1000` | `// * 0 <= remaining <= 1000` |
| 28 | `` | `` |
| 29 | `    Have fun :)` | `// Have fun :)` |
| 30 | `    """` | `// ` |
