# CJ-HUMANEVAL-038: decode_cyclic

- Source task: `HumanEval/38`
- Cangjie signature: `public func decode_cyclic(s: String): String`
- Test calls expanded from official HumanEval: `100`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def encode_cyclic(s: str):` | `public func decode_cyclic(s: String): String {` |
| 4 | `    """` | `// ` |
| 5 | `    returns encoded string by cycling groups of three characters.` | `// returns encoded string by cycling groups of three characters.` |
| 6 | `    """` | `// ` |
| 7 | `    # split string to groups. Each of length 3.` | `// # split string to groups. Each of length 3.` |
| 8 | `    groups = [s[(3 * i):min((3 * i + 3), len(s))] for i in range((len(s) + 2) // 3)]` | `// groups = [s[(3 * i):min((3 * i + 3), len(s))] for i in range((len(s) + 2) // 3)]` |
| 9 | `    # cycle elements in each group. Unless group has fewer elements than 3.` | `// # cycle elements in each group. Unless group has fewer elements than 3.` |
| 10 | `    groups = [(group[1:] + group[0]) if len(group) == 3 else group for group in groups]` | `// groups = [(group[1:] + group[0]) if len(group) == 3 else group for group in groups]` |
| 11 | `    return "".join(groups)` | `// return "".join(groups)` |
| 12 | `` | `` |
| 13 | `` | `` |
| 14 | `def decode_cyclic(s: str):` | `public func decode_cyclic(s: String): String {` |
| 15 | `    """` | `// ` |
| 16 | `    takes as input string encoded with encode_cyclic function. Returns decoded string.` | `// takes as input string encoded with encode_cyclic function. Returns decoded string.` |
| 17 | `    """` | `// ` |
