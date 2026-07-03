# CJ-HUMANEVAL-110: exchange

- Source task: `HumanEval/110`
- Cangjie signature: `public func exchange(lst1: ArrayList<Int64>, lst2: ArrayList<Int64>): String`
- Test calls expanded from official HumanEval: `7`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def exchange(lst1, lst2):` | `public func exchange(lst1: ArrayList<Int64>, lst2: ArrayList<Int64>): String {` |
| 3 | `    """In this problem, you will implement a function that takes two lists of numbers,` | `// In this problem, you will implement a function that takes two lists of numbers,` |
| 4 | `    and determines whether it is possible to perform an exchange of elements` | `// and determines whether it is possible to perform an exchange of elements` |
| 5 | `    between them to make lst1 a list of only even numbers.` | `// between them to make lst1 a list of only even numbers.` |
| 6 | `    There is no limit on the number of exchanged elements between lst1 and lst2.` | `// There is no limit on the number of exchanged elements between lst1 and lst2.` |
| 7 | `    If it is possible to exchange elements between the lst1 and lst2 to make` | `// If it is possible to exchange elements between the lst1 and lst2 to make` |
| 8 | `    all the elements of lst1 to be even, return "YES".` | `// all the elements of lst1 to be even, return "YES".` |
| 9 | `    Otherwise, return "NO".` | `// Otherwise, return "NO".` |
| 10 | `    For example:` | `// For example:` |
| 11 | `    exchange([1, 2, 3, 4], [1, 2, 3, 4]) => "YES"` | `// exchange([1, 2, 3, 4], [1, 2, 3, 4]) => "YES"` |
| 12 | `    exchange([1, 2, 3, 4], [1, 5, 3, 4]) => "NO"` | `// exchange([1, 2, 3, 4], [1, 5, 3, 4]) => "NO"` |
| 13 | `    It is assumed that the input lists will be non-empty.` | `// It is assumed that the input lists will be non-empty.` |
| 14 | `    """` | `// ` |
