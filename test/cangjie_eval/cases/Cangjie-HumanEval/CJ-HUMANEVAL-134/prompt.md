# CJ-HUMANEVAL-134: check_if_last_char_is_a_letter

- Source task: `HumanEval/134`
- Cangjie signature: `public func check_if_last_char_is_a_letter(txt: String): Bool`
- Test calls expanded from official HumanEval: `10`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def check_if_last_char_is_a_letter(txt):` | `public func check_if_last_char_is_a_letter(txt: String): Bool {` |
| 3 | `    '''` | `// '''` |
| 4 | `    Create a function that returns True if the last character` | `// Create a function that returns True if the last character` |
| 5 | `    of a given string is an alphabetical character and is not` | `// of a given string is an alphabetical character and is not` |
| 6 | `    a part of a word, and False otherwise.` | `// a part of a word, and False otherwise.` |
| 7 | `    Note: "word" is a group of characters separated by space.` | `// Note: "word" is a group of characters separated by space.` |
| 8 | `` | `` |
| 9 | `    Examples:` | `// Examples:` |
| 10 | `    check_if_last_char_is_a_letter("apple pie") ➞ False` | `// check_if_last_char_is_a_letter("apple pie") ➞ False` |
| 11 | `    check_if_last_char_is_a_letter("apple pi e") ➞ True` | `// check_if_last_char_is_a_letter("apple pi e") ➞ True` |
| 12 | `    check_if_last_char_is_a_letter("apple pi e ") ➞ False` | `// check_if_last_char_is_a_letter("apple pi e ") ➞ False` |
| 13 | `    check_if_last_char_is_a_letter("") ➞ False ` | `// check_if_last_char_is_a_letter("") ➞ False` |
| 14 | `    '''` | `// '''` |
