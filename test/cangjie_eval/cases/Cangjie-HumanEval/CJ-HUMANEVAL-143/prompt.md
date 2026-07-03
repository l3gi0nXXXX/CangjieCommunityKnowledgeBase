# CJ-HUMANEVAL-143: words_in_sentence

- Source task: `HumanEval/143`
- Cangjie signature: `public func words_in_sentence(sentence: String): String`
- Test calls expanded from official HumanEval: `7`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def words_in_sentence(sentence):` | `public func words_in_sentence(sentence: String): String {` |
| 3 | `    """` | `// ` |
| 4 | `    You are given a string representing a sentence,` | `// You are given a string representing a sentence,` |
| 5 | `    the sentence contains some words separated by a space,` | `// the sentence contains some words separated by a space,` |
| 6 | `    and you have to return a string that contains the words from the original sentence,` | `// and you have to return a string that contains the words from the original sentence,` |
| 7 | `    whose lengths are prime numbers,` | `// whose lengths are prime numbers,` |
| 8 | `    the order of the words in the new string should be the same as the original one.` | `// the order of the words in the new string should be the same as the original one.` |
| 9 | `` | `` |
| 10 | `    Example 1:` | `// Example 1:` |
| 11 | `        Input: sentence = "This is a test"` | `// Input: sentence = "This is a test"` |
| 12 | `        Output: "is"` | `// Output: "is"` |
| 13 | `` | `` |
| 14 | `    Example 2:` | `// Example 2:` |
| 15 | `        Input: sentence = "lets go for swimming"` | `// Input: sentence = "lets go for swimming"` |
| 16 | `        Output: "go for"` | `// Output: "go for"` |
| 17 | `` | `` |
| 18 | `    Constraints:` | `// Constraints:` |
| 19 | `        * 1 <= len(sentence) <= 100` | `// * 1 <= len(sentence) <= 100` |
| 20 | `        * sentence contains only letters` | `// * sentence contains only letters` |
| 21 | `    """` | `// ` |
