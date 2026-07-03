# CJ-HUMANEVAL-142: sum_squares

- Source task: `HumanEval/142`
- Cangjie signature: `public func sum_squares(lst: ArrayList<Int64>): Int64`
- Test calls expanded from official HumanEval: `11`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `` | `` |
| 3 | `` | `` |
| 4 | `def sum_squares(lst):` | `public func sum_squares(lst: ArrayList<Int64>): Int64 {` |
| 5 | `    """"` | `// ` |
| 6 | `    This function will take a list of integers. For all entries in the list, the function shall square the integer entry if its index is a ` | `// This function will take a list of integers. For all entries in the list, the function shall square the integer entry if its index is a` |
| 7 | `    multiple of 3 and will cube the integer entry if its index is a multiple of 4 and not a multiple of 3. The function will not ` | `// multiple of 3 and will cube the integer entry if its index is a multiple of 4 and not a multiple of 3. The function will not` |
| 8 | `    change the entries in the list whose indexes are not a multiple of 3 or 4. The function shall then return the sum of all entries. ` | `// change the entries in the list whose indexes are not a multiple of 3 or 4. The function shall then return the sum of all entries.` |
| 9 | `    ` | `` |
| 10 | `    Examples:` | `// Examples:` |
| 11 | `    For lst = [1,2,3] the output should be 6` | `// For lst = [1,2,3] the output should be 6` |
| 12 | `    For lst = []  the output should be 0` | `// For lst = []  the output should be 0` |
| 13 | `    For lst = [-1,-5,2,-1,-5]  the output should be -126` | `// For lst = [-1,-5,2,-1,-5]  the output should be -126` |
| 14 | `    """` | `// ` |
