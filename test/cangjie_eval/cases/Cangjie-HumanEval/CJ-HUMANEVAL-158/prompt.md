# CJ-HUMANEVAL-158: find_max

- Source task: `HumanEval/158`
- Cangjie signature: `public func find_max(words: ArrayList<String>): String`
- Test calls expanded from official HumanEval: `10`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def find_max(words):` | `public func find_max(words: ArrayList<String>): String {` |
| 3 | `    """Write a function that accepts a list of strings.` | `// Write a function that accepts a list of strings.` |
| 4 | `    The list contains different words. Return the word with maximum number` | `// The list contains different words. Return the word with maximum number` |
| 5 | `    of unique characters. If multiple strings have maximum number of unique` | `// of unique characters. If multiple strings have maximum number of unique` |
| 6 | `    characters, return the one which comes first in lexicographical order.` | `// characters, return the one which comes first in lexicographical order.` |
| 7 | `` | `` |
| 8 | `    find_max(["name", "of", "string"]) == "string"` | `// find_max(["name", "of", "string"]) == "string"` |
| 9 | `    find_max(["name", "enam", "game"]) == "enam"` | `// find_max(["name", "enam", "game"]) == "enam"` |
| 10 | `    find_max(["aaaaaaa", "bb" ,"cc"]) == ""aaaaaaa"` | `// find_max(["aaaaaaa", "bb" ,"cc"]) == ""aaaaaaa"` |
| 11 | `    """` | `// ` |
