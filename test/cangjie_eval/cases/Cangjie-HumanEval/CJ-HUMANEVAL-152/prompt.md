# CJ-HUMANEVAL-152: compare

- Source task: `HumanEval/152`
- Cangjie signature: `public func compare(game: ArrayList<Int64>, guess: ArrayList<Int64>): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `4`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def compare(game,guess):` | `public func compare(game: ArrayList<Int64>, guess: ArrayList<Int64>): ArrayList<Int64> {` |
| 3 | `    """I think we all remember that feeling when the result of some long-awaited` | `// I think we all remember that feeling when the result of some long-awaited` |
| 4 | `    event is finally known. The feelings and thoughts you have at that moment are` | `// event is finally known. The feelings and thoughts you have at that moment are` |
| 5 | `    definitely worth noting down and comparing.` | `// definitely worth noting down and comparing.` |
| 6 | `    Your task is to determine if a person correctly guessed the results of a number of matches.` | `// Your task is to determine if a person correctly guessed the results of a number of matches.` |
| 7 | `    You are given two arrays of scores and guesses of equal length, where each index shows a match. ` | `// You are given two arrays of scores and guesses of equal length, where each index shows a match.` |
| 8 | `    Return an array of the same length denoting how far off each guess was. If they have guessed correctly,` | `// Return an array of the same length denoting how far off each guess was. If they have guessed correctly,` |
| 9 | `    the value is 0, and if not, the value is the absolute difference between the guess and the score.` | `// the value is 0, and if not, the value is the absolute difference between the guess and the score.` |
| 10 | `    ` | `` |
| 11 | `    ` | `` |
| 12 | `    example:` | `// example:` |
| 13 | `` | `` |
| 14 | `    compare([1,2,3,4,5,1],[1,2,3,4,2,-2]) -> [0,0,0,0,3,3]` | `// compare([1,2,3,4,5,1],[1,2,3,4,2,-2]) -> [0,0,0,0,3,3]` |
| 15 | `    compare([0,5,0,0,0,4],[4,1,1,0,0,-2]) -> [4,4,1,0,0,6]` | `// compare([0,5,0,0,0,4],[4,1,1,0,0,-2]) -> [4,4,1,0,0,6]` |
| 16 | `    """` | `// ` |
