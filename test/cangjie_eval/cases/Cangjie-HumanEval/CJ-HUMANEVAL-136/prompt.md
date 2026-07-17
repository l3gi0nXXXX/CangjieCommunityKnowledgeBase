# CJ-HUMANEVAL-136: largest_smallest_integers

- Source task: `HumanEval/136`
- Cangjie signature: `public func largest_smallest_integers(lst: ArrayList<Int64>): (Option<Int64>, Option<Int64>)`
- Test calls expanded from official HumanEval: `11`
- Static-language adaptations:
  - Each Python tuple position is either an integer or `None`. The Cangjie return type represents that union explicitly: Python `None` becomes `None<Int64>`, and an integer becomes `Some<Int64>(value)`. Tuple position and integer value remain exact.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def largest_smallest_integers(lst):` | `public func largest_smallest_integers(lst: ArrayList<Int64>): (Option<Int64>, Option<Int64>) {` |
| 3 | `    '''` | `// '''` |
| 4 | `    Create a function that returns a tuple (a, b), where 'a' is` | `// Create a function that returns a tuple (a, b), where 'a' is` |
| 5 | `    the largest of negative integers, and 'b' is the smallest` | `// the largest of negative integers, and 'b' is the smallest` |
| 6 | `    of positive integers in a list.` | `// of positive integers in a list.` |
| 7 | `    If there is no negative or positive integers, return them as None.` | `// If there is no negative or positive integers, return them as None.` |
| 8 | `` | `` |
| 9 | `    Examples:` | `// Examples:` |
| 10 | `    largest_smallest_integers([2, 4, 1, 3, 5, 7]) == (None, 1)` | `// largest_smallest_integers([2, 4, 1, 3, 5, 7]) == (None, 1)` |
| 11 | `    largest_smallest_integers([]) == (None, None)` | `// largest_smallest_integers([]) == (None, None)` |
| 12 | `    largest_smallest_integers([0]) == (None, None)` | `// largest_smallest_integers([0]) == (None, None)` |
| 13 | `    '''` | `// '''` |
