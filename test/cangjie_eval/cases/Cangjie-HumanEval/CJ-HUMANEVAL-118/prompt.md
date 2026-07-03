# CJ-HUMANEVAL-118: get_closest_vowel

- Source task: `HumanEval/118`
- Cangjie signature: `public func get_closest_vowel(word: String): String`
- Test calls expanded from official HumanEval: `13`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def get_closest_vowel(word):` | `public func get_closest_vowel(word: String): String {` |
| 3 | `    """You are given a word. Your task is to find the closest vowel that stands between ` | `// You are given a word. Your task is to find the closest vowel that stands between` |
| 4 | `    two consonants from the right side of the word (case sensitive).` | `// two consonants from the right side of the word (case sensitive).` |
| 5 | `    ` | `` |
| 6 | `    Vowels in the beginning and ending doesn't count. Return empty string if you didn't` | `// Vowels in the beginning and ending doesn't count. Return empty string if you didn't` |
| 7 | `    find any vowel met the above condition. ` | `// find any vowel met the above condition.` |
| 8 | `` | `` |
| 9 | `    You may assume that the given string contains English letter only.` | `// You may assume that the given string contains English letter only.` |
| 10 | `` | `` |
| 11 | `    Example:` | `// Example:` |
| 12 | `    get_closest_vowel("yogurt") ==> "u"` | `// get_closest_vowel("yogurt") ==> "u"` |
| 13 | `    get_closest_vowel("FULL") ==> "U"` | `// get_closest_vowel("FULL") ==> "U"` |
| 14 | `    get_closest_vowel("quick") ==> ""` | `// get_closest_vowel("quick") ==> ""` |
| 15 | `    get_closest_vowel("ab") ==> ""` | `// get_closest_vowel("ab") ==> ""` |
| 16 | `    """` | `// ` |
