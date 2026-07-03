# CJ-HUMANEVAL-149: sorted_list_sum

- Source task: `HumanEval/149`
- Cangjie signature: `public func sorted_list_sum(lst: ArrayList<String>): ArrayList<String>`
- Test calls expanded from official HumanEval: `7`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def sorted_list_sum(lst):` | `public func sorted_list_sum(lst: ArrayList<String>): ArrayList<String> {` |
| 3 | `    """Write a function that accepts a list of strings as a parameter,` | `// Write a function that accepts a list of strings as a parameter,` |
| 4 | `    deletes the strings that have odd lengths from it,` | `// deletes the strings that have odd lengths from it,` |
| 5 | `    and returns the resulted list with a sorted order,` | `// and returns the resulted list with a sorted order,` |
| 6 | `    The list is always a list of strings and never an array of numbers,` | `// The list is always a list of strings and never an array of numbers,` |
| 7 | `    and it may contain duplicates.` | `// and it may contain duplicates.` |
| 8 | `    The order of the list should be ascending by length of each word, and you` | `// The order of the list should be ascending by length of each word, and you` |
| 9 | `    should return the list sorted by that rule.` | `// should return the list sorted by that rule.` |
| 10 | `    If two words have the same length, sort the list alphabetically.` | `// If two words have the same length, sort the list alphabetically.` |
| 11 | `    The function should return a list of strings in sorted order.` | `// The function should return a list of strings in sorted order.` |
| 12 | `    You may assume that all words will have the same length.` | `// You may assume that all words will have the same length.` |
| 13 | `    For example:` | `// For example:` |
| 14 | `    assert list_sort(["aa", "a", "aaa"]) => ["aa"]` | `// assert list_sort(["aa", "a", "aaa"]) => ["aa"]` |
| 15 | `    assert list_sort(["ab", "a", "aaa", "cd"]) => ["ab", "cd"]` | `// assert list_sort(["ab", "a", "aaa", "cd"]) => ["ab", "cd"]` |
| 16 | `    """` | `// ` |
