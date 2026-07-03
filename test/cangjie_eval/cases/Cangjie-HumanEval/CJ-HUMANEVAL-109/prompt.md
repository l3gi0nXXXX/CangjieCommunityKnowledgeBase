# CJ-HUMANEVAL-109: move_one_ball

- Source task: `HumanEval/109`
- Cangjie signature: `public func move_one_ball(arr: ArrayList<Int64>): Bool`
- Test calls expanded from official HumanEval: `5`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def move_one_ball(arr):` | `public func move_one_ball(arr: ArrayList<Int64>): Bool {` |
| 3 | `    """We have an array 'arr' of N integers arr[1], arr[2], ..., arr[N].The` | `// We have an array 'arr' of N integers arr[1], arr[2], ..., arr[N].The` |
| 4 | `    numbers in the array will be randomly ordered. Your task is to determine if` | `// numbers in the array will be randomly ordered. Your task is to determine if` |
| 5 | `    it is possible to get an array sorted in non-decreasing order by performing ` | `// it is possible to get an array sorted in non-decreasing order by performing` |
| 6 | `    the following operation on the given array:` | `// the following operation on the given array:` |
| 7 | `        You are allowed to perform right shift operation any number of times.` | `// You are allowed to perform right shift operation any number of times.` |
| 8 | `    ` | `` |
| 9 | `    One right shift operation means shifting all elements of the array by one` | `// One right shift operation means shifting all elements of the array by one` |
| 10 | `    position in the right direction. The last element of the array will be moved to` | `// position in the right direction. The last element of the array will be moved to` |
| 11 | `    the starting position in the array i.e. 0th index. ` | `// the starting position in the array i.e. 0th index.` |
| 12 | `` | `` |
| 13 | `    If it is possible to obtain the sorted array by performing the above operation` | `// If it is possible to obtain the sorted array by performing the above operation` |
| 14 | `    then return True else return False.` | `// then return True else return False.` |
| 15 | `    If the given array is empty then return True.` | `// If the given array is empty then return True.` |
| 16 | `` | `` |
| 17 | `    Note: The given list is guaranteed to have unique elements.` | `// Note: The given list is guaranteed to have unique elements.` |
| 18 | `` | `` |
| 19 | `    For Example:` | `// For Example:` |
| 20 | `    ` | `` |
| 21 | `    move_one_ball([3, 4, 5, 1, 2])==>True` | `// move_one_ball([3, 4, 5, 1, 2])==>True` |
| 22 | `    Explanation: By performin 2 right shift operations, non-decreasing order can` | `// Explanation: By performin 2 right shift operations, non-decreasing order can` |
| 23 | `                 be achieved for the given array.` | `// be achieved for the given array.` |
| 24 | `    move_one_ball([3, 5, 4, 1, 2])==>False` | `// move_one_ball([3, 5, 4, 1, 2])==>False` |
| 25 | `    Explanation:It is not possible to get non-decreasing order for the given` | `// Explanation:It is not possible to get non-decreasing order for the given` |
| 26 | `                array by performing any number of right shift operations.` | `// array by performing any number of right shift operations.` |
| 27 | `                ` | `` |
| 28 | `    """` | `// ` |
