# CJ-HUMANEVAL-141: file_name_check

- Source task: `HumanEval/141`
- Cangjie signature: `public func file_name_check(file_name: String): String`
- Test calls expanded from official HumanEval: `26`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def file_name_check(file_name):` | `public func file_name_check(file_name: String): String {` |
| 3 | `    """Create a function which takes a string representing a file's name, and returns` | `// Create a function which takes a string representing a file's name, and returns` |
| 4 | `    'Yes' if the the file's name is valid, and returns 'No' otherwise.` | `// 'Yes' if the the file's name is valid, and returns 'No' otherwise.` |
| 5 | `    A file's name is considered to be valid if and only if all the following conditions ` | `// A file's name is considered to be valid if and only if all the following conditions` |
| 6 | `    are met:` | `// are met:` |
| 7 | `    - There should not be more than three digits ('0'-'9') in the file's name.` | `// - There should not be more than three digits ('0'-'9') in the file's name.` |
| 8 | `    - The file's name contains exactly one dot '.'` | `// - The file's name contains exactly one dot '.'` |
| 9 | `    - The substring before the dot should not be empty, and it starts with a letter from ` | `// - The substring before the dot should not be empty, and it starts with a letter from` |
| 10 | `    the latin alphapet ('a'-'z' and 'A'-'Z').` | `// the latin alphapet ('a'-'z' and 'A'-'Z').` |
| 11 | `    - The substring after the dot should be one of these: ['txt', 'exe', 'dll']` | `// - The substring after the dot should be one of these: ['txt', 'exe', 'dll']` |
| 12 | `    Examples:` | `// Examples:` |
| 13 | `    file_name_check("example.txt") # => 'Yes'` | `// file_name_check("example.txt") # => 'Yes'` |
| 14 | `    file_name_check("1example.dll") # => 'No' (the name should start with a latin alphapet letter)` | `// file_name_check("1example.dll") # => 'No' (the name should start with a latin alphapet letter)` |
| 15 | `    """` | `// ` |
