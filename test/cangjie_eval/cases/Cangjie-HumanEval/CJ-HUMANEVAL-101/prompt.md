# CJ-HUMANEVAL-101: words_string

- Source task: `HumanEval/101`
- Cangjie signature: `public func words_string(s: String): ArrayList<String>`
- Test calls expanded from official HumanEval plus public contract boundaries: `7`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Static-Language Contract

The source oracle replaces commas with spaces and then applies Python's no-argument whitespace split. The completion-only starter exposes `wordsStringSourceWhitespace(Rune)`, which recognizes that source whitespace set. Iterate over `s.runes()`, treat a comma or a Rune accepted by that helper as a separator, preserve every non-separator Rune exactly, and omit empty tokens produced by leading, trailing, or consecutive separators. Byte-wise splitting or checking only ASCII space is not source-equivalent and corrupts non-ASCII text.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def words_string(s):` | `public func words_string(s: String): ArrayList<String> {` |
| 3 | `    """` | `// ` |
| 4 | `    You will be given a string of words separated by commas or spaces. Your task is` | `// You will be given a string of words separated by commas or spaces. Your task is` |
| 5 | `    to split the string into words and return an array of the words.` | `// to split the string into words and return an array of the words.` |
| 6 | `    ` | `` |
| 7 | `    For example:` | `// For example:` |
| 8 | `    words_string("Hi, my name is John") == ["Hi", "my", "name", "is", "John"]` | `// words_string("Hi, my name is John") == ["Hi", "my", "name", "is", "John"]` |
| 9 | `    words_string("One, two, three, four, five, six") == ["One", "two", "three", "four", "five", "six"]` | `// words_string("One, two, three, four, five, six") == ["One", "two", "three", "four", "five", "six"]` |
| 10 | `    """` | `// ` |
