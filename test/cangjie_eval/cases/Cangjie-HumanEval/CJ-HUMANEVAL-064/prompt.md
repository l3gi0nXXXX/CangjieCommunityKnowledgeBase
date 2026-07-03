# CJ-HUMANEVAL-064: vowels_count

- Source task: `HumanEval/64`
- Cangjie signature: `public func vowels_count(s: String): Int64`
- Test calls expanded from official HumanEval: `7`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `FIX = """` | `// FIX = ` |
| 3 | `Add more test cases.` | `// Add more test cases.` |
| 4 | `"""` | `// ` |
| 5 | `` | `` |
| 6 | `def vowels_count(s):` | `public func vowels_count(s: String): Int64 {` |
| 7 | `    """Write a function vowels_count which takes a string representing` | `// Write a function vowels_count which takes a string representing` |
| 8 | `    a word as input and returns the number of vowels in the string.` | `// a word as input and returns the number of vowels in the string.` |
| 9 | `    Vowels in this case are 'a', 'e', 'i', 'o', 'u'. Here, 'y' is also a` | `// Vowels in this case are 'a', 'e', 'i', 'o', 'u'. Here, 'y' is also a` |
| 10 | `    vowel, but only when it is at the end of the given word.` | `// vowel, but only when it is at the end of the given word.` |
| 11 | `` | `` |
| 12 | `    Example:` | `// Example:` |
| 13 | `    >>> vowels_count("abcde")` | `// Example: vowels_count("abcde")` |
| 14 | `    2` | `// 2` |
| 15 | `    >>> vowels_count("ACEDY")` | `// Example: vowels_count("ACEDY")` |
| 16 | `    3` | `// 3` |
| 17 | `    """` | `// ` |
