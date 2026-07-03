# CJ-HUMANEVAL-117: select_words

- Source task: `HumanEval/117`
- Cangjie signature: `public func select_words(s: String, n: Int64): ArrayList<String>`
- Test calls expanded from official HumanEval: `7`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def select_words(s, n):` | `public func select_words(s: String, n: Int64): ArrayList<String> {` |
| 3 | `    """Given a string s and a natural number n, you have been tasked to implement ` | `// Given a string s and a natural number n, you have been tasked to implement` |
| 4 | `    a function that returns a list of all words from string s that contain exactly ` | `// a function that returns a list of all words from string s that contain exactly` |
| 5 | `    n consonants, in order these words appear in the string s.` | `// n consonants, in order these words appear in the string s.` |
| 6 | `    If the string s is empty then the function should return an empty list.` | `// If the string s is empty then the function should return an empty list.` |
| 7 | `    Note: you may assume the input string contains only letters and spaces.` | `// Note: you may assume the input string contains only letters and spaces.` |
| 8 | `    Examples:` | `// Examples:` |
| 9 | `    select_words("Mary had a little lamb", 4) ==> ["little"]` | `// select_words("Mary had a little lamb", 4) ==> ["little"]` |
| 10 | `    select_words("Mary had a little lamb", 3) ==> ["Mary", "lamb"]` | `// select_words("Mary had a little lamb", 3) ==> ["Mary", "lamb"]` |
| 11 | `    select_words("simple white space", 2) ==> []` | `// select_words("simple white space", 2) ==> []` |
| 12 | `    select_words("Hello world", 4) ==> ["world"]` | `// select_words("Hello world", 4) ==> ["world"]` |
| 13 | `    select_words("Uncle sam", 3) ==> ["Uncle"]` | `// select_words("Uncle sam", 3) ==> ["Uncle"]` |
| 14 | `    """` | `// ` |
