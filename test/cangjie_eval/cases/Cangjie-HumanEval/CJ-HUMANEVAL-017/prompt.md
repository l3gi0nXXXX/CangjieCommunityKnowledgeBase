# CJ-HUMANEVAL-017: parse_music

- Source task: `HumanEval/17`
- Cangjie signature: `public func parse_music(music_string: String): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `5`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `from typing import List` | `import std.collection.*` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def parse_music(music_string: str) -> List[int]:` | `public func parse_music(music_string: String): ArrayList<Int64> {` |
| 5 | `    """ Input to this function is a string representing musical notes in a special ASCII format.` | `//  Input to this function is a string representing musical notes in a special ASCII format.` |
| 6 | `    Your task is to parse this string and return list of integers corresponding to how many beats does each` | `// Your task is to parse this string and return list of integers corresponding to how many beats does each` |
| 7 | `    not last.` | `// not last.` |
| 8 | `` | `` |
| 9 | `    Here is a legend:` | `// Here is a legend:` |
| 10 | `    'o' - whole note, lasts four beats` | `// 'o' - whole note, lasts four beats` |
| 11 | `    'o\|' - half note, lasts two beats` | `// 'o\|' - half note, lasts two beats` |
| 12 | `    '.\|' - quater note, lasts one beat` | `// '.\|' - quater note, lasts one beat` |
| 13 | `` | `` |
| 14 | `    >>> parse_music('o o\| .\| o\| o\| .\| .\| .\| .\| o o')` | `// Example: parse_music('o o\| .\| o\| o\| .\| .\| .\| .\| o o')` |
| 15 | `    [4, 2, 1, 2, 2, 1, 1, 1, 1, 4, 4]` | `// [4, 2, 1, 2, 2, 1, 1, 1, 1, 4, 4]` |
| 16 | `    """` | `// ` |
