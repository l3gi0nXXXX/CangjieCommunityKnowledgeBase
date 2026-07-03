# CJ-HUMANEVAL-124: valid_date

- Source task: `HumanEval/124`
- Cangjie signature: `public func valid_date(date: String): Bool`
- Test calls expanded from official HumanEval: `16`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def valid_date(date):` | `public func valid_date(date: String): Bool {` |
| 3 | `    """You have to write a function which validates a given date string and` | `// You have to write a function which validates a given date string and` |
| 4 | `    returns True if the date is valid otherwise False.` | `// returns True if the date is valid otherwise False.` |
| 5 | `    The date is valid if all of the following rules are satisfied:` | `// The date is valid if all of the following rules are satisfied:` |
| 6 | `    1. The date string is not empty.` | `// 1. The date string is not empty.` |
| 7 | `    2. The number of days is not less than 1 or higher than 31 days for months 1,3,5,7,8,10,12. And the number of days is not less than 1 or higher than 30 days for months 4,6,9,11. And, the number of days is not less than 1 or higher than 29 for the month 2.` | `// 2. The number of days is not less than 1 or higher than 31 days for months 1,3,5,7,8,10,12. And the number of days is not less than 1 or higher than 30 days for months 4,6,9,11. And, the number of days is not less than 1 or higher than 29 for the month 2.` |
| 8 | `    3. The months should not be less than 1 or higher than 12.` | `// 3. The months should not be less than 1 or higher than 12.` |
| 9 | `    4. The date should be in the format: mm-dd-yyyy` | `// 4. The date should be in the format: mm-dd-yyyy` |
| 10 | `` | `` |
| 11 | `    for example: ` | `// for example:` |
| 12 | `    valid_date('03-11-2000') => True` | `// valid_date('03-11-2000') => True` |
| 13 | `` | `` |
| 14 | `    valid_date('15-01-2012') => False` | `// valid_date('15-01-2012') => False` |
| 15 | `` | `` |
| 16 | `    valid_date('04-0-2040') => False` | `// valid_date('04-0-2040') => False` |
| 17 | `` | `` |
| 18 | `    valid_date('06-04-2020') => True` | `// valid_date('06-04-2020') => True` |
| 19 | `` | `` |
| 20 | `    valid_date('06/04/2020') => False` | `// valid_date('06/04/2020') => False` |
| 21 | `    """` | `// ` |
