# CJ-HUMANEVAL-125: split_words

- Source task: `HumanEval/125`
- Cangjie signature: `public func split_words(txt: String): EvalValue`
- Test calls expanded from official HumanEval: `8`
- Static-language adaptations:
  - Python `list[str] | int` is represented by `EvalValue` with exact `string_list` and `int` tagged payloads.
  - Return a list branch with `evalStringList(Array<String>)`; serialized list text in `evalString(...)` is a different value and will not pass.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def split_words(txt):` | `public func split_words(txt: String): EvalValue {` |
| 3 | `    '''` | `// '''` |
| 4 | `    Given a string of words, return a list of words split on whitespace, if no whitespaces exists in the text you` | `// Given a string of words, return a list of words split on whitespace, if no whitespaces exists in the text you` |
| 5 | `    should split on commas ',' if no commas exists you should return the number of lower-case letters with odd order in the` | `// should split on commas ',' if no commas exists you should return the number of lower-case letters with odd order in the` |
| 6 | `    alphabet, ord('a') = 0, ord('b') = 1, ... ord('z') = 25` | `// alphabet, ord('a') = 0, ord('b') = 1, ... ord('z') = 25` |
| 7 | `    Examples` | `// Examples` |
| 8 | `    split_words("Hello world!") ➞ ["Hello", "world!"]` | `// split_words("Hello world!") ➞ ["Hello", "world!"]` |
| 9 | `    split_words("Hello,world!") ➞ ["Hello", "world!"]` | `// split_words("Hello,world!") ➞ ["Hello", "world!"]` |
| 10 | `    split_words("abcdef") == 3 ` | `// split_words("abcdef") == 3` |
| 11 | `    '''` | `// '''` |
