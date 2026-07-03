# CJ-HUMANEVAL-050: decode_shift

- Source task: `HumanEval/50`
- Cangjie signature: `public func decode_shift(s: String): String`
- Test calls expanded from official HumanEval: `100`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `def encode_shift(s: str):` | `public func decode_shift(s: String): String {` |
| 4 | `    """` | `// ` |
| 5 | `    returns encoded string by shifting every character by 5 in the alphabet.` | `// returns encoded string by shifting every character by 5 in the alphabet.` |
| 6 | `    """` | `// ` |
| 7 | `    return "".join([chr(((ord(ch) + 5 - ord("a")) % 26) + ord("a")) for ch in s])` | `// return "".join([chr(((ord(ch) + 5 - ord("a")) % 26) + ord("a")) for ch in s])` |
| 8 | `` | `` |
| 9 | `` | `` |
| 10 | `def decode_shift(s: str):` | `public func decode_shift(s: String): String {` |
| 11 | `    """` | `// ` |
| 12 | `    takes as input string encoded with encode_shift function. Returns decoded string.` | `// takes as input string encoded with encode_shift function. Returns decoded string.` |
| 13 | `    """` | `// ` |
