# CJ-HUMANEVAL-147: get_max_triples

- Source task: `HumanEval/147`
- Cangjie signature: `public func get_max_triples(n: Int64): Int64`
- Test calls expanded from official HumanEval: `4`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def get_max_triples(n):` | `public func get_max_triples(n: Int64): Int64 {` |
| 3 | `    """` | `// ` |
| 4 | `    You are given a positive integer n. You have to create an integer array a of length n.` | `// You are given a positive integer n. You have to create an integer array a of length n.` |
| 5 | `        For each i (1 ≤ i ≤ n), the value of a[i] = i * i - i + 1.` | `// For each i (1 ≤ i ≤ n), the value of a[i] = i * i - i + 1.` |
| 6 | `        Return the number of triples (a[i], a[j], a[k]) of a where i < j < k, ` | `// Return the number of triples (a[i], a[j], a[k]) of a where i < j < k,` |
| 7 | `    and a[i] + a[j] + a[k] is a multiple of 3.` | `// and a[i] + a[j] + a[k] is a multiple of 3.` |
| 8 | `` | `` |
| 9 | `    Example :` | `// Example :` |
| 10 | `        Input: n = 5` | `// Input: n = 5` |
| 11 | `        Output: 1` | `// Output: 1` |
| 12 | `        Explanation: ` | `// Explanation:` |
| 13 | `        a = [1, 3, 7, 13, 21]` | `// a = [1, 3, 7, 13, 21]` |
| 14 | `        The only valid triple is (1, 7, 13).` | `// The only valid triple is (1, 7, 13).` |
| 15 | `    """` | `// ` |
