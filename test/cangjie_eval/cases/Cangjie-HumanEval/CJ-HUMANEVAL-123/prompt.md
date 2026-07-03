# CJ-HUMANEVAL-123: get_odd_collatz

- Source task: `HumanEval/123`
- Cangjie signature: `public func get_odd_collatz(n: Int64): ArrayList<Int64>`
- Test calls expanded from official HumanEval: `4`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def get_odd_collatz(n):` | `public func get_odd_collatz(n: Int64): ArrayList<Int64> {` |
| 3 | `    """` | `// ` |
| 4 | `    Given a positive integer n, return a sorted list that has the odd numbers in collatz sequence.` | `// Given a positive integer n, return a sorted list that has the odd numbers in collatz sequence.` |
| 5 | `` | `` |
| 6 | `    The Collatz conjecture is a conjecture in mathematics that concerns a sequence defined` | `// The Collatz conjecture is a conjecture in mathematics that concerns a sequence defined` |
| 7 | `    as follows: start with any positive integer n. Then each term is obtained from the ` | `// as follows: start with any positive integer n. Then each term is obtained from the` |
| 8 | `    previous term as follows: if the previous term is even, the next term is one half of ` | `// previous term as follows: if the previous term is even, the next term is one half of` |
| 9 | `    the previous term. If the previous term is odd, the next term is 3 times the previous` | `// the previous term. If the previous term is odd, the next term is 3 times the previous` |
| 10 | `    term plus 1. The conjecture is that no matter what value of n, the sequence will always reach 1.` | `// term plus 1. The conjecture is that no matter what value of n, the sequence will always reach 1.` |
| 11 | `` | `` |
| 12 | `    Note: ` | `// Note:` |
| 13 | `        1. Collatz(1) is [1].` | `// 1. Collatz(1) is [1].` |
| 14 | `        2. returned list sorted in increasing order.` | `// 2. returned list sorted in increasing order.` |
| 15 | `` | `` |
| 16 | `    For example:` | `// For example:` |
| 17 | `    get_odd_collatz(5) returns [1, 5] # The collatz sequence for 5 is [5, 16, 8, 4, 2, 1], so the odd numbers are only 1, and 5.` | `// get_odd_collatz(5) returns [1, 5] # The collatz sequence for 5 is [5, 16, 8, 4, 2, 1], so the odd numbers are only 1, and 5.` |
| 18 | `    """` | `// ` |
