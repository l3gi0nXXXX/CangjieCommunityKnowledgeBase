# CJ-HUMANEVAL-095: check_dict_case

- Source task: `HumanEval/95`
- Cangjie signature: `public func check_dict_case(dictValue: ArrayList<EvalEntry>): Bool`
- Test calls expanded from official HumanEval: `7`
- Static-language adaptations:
  - Python dynamic values are represented by EvalValue/EvalEntry helper types.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def check_dict_case(dict):` | `public func check_dict_case(dictValue: ArrayList<EvalEntry>): Bool {` |
| 3 | `    """` | `// ` |
| 4 | `    Given a dictionary, return True if all keys are strings in lower ` | `// Given a dictionary, return True if all keys are strings in lower` |
| 5 | `    case or all keys are strings in upper case, else return False.` | `// case or all keys are strings in upper case, else return False.` |
| 6 | `    The function should return False is the given dictionary is empty.` | `// The function should return False is the given dictionary is empty.` |
| 7 | `    Examples:` | `// Examples:` |
| 8 | `    check_dict_case({"a":"apple", "b":"banana"}) should return True.` | `// check_dict_case({"a":"apple", "b":"banana"}) should return True.` |
| 9 | `    check_dict_case({"a":"apple", "A":"banana", "B":"banana"}) should return False.` | `// check_dict_case({"a":"apple", "A":"banana", "B":"banana"}) should return False.` |
| 10 | `    check_dict_case({"a":"apple", 8:"banana", "a":"apple"}) should return False.` | `// check_dict_case({"a":"apple", 8:"banana", "a":"apple"}) should return False.` |
| 11 | `    check_dict_case({"Name":"John", "Age":"36", "City":"Houston"}) should return False.` | `// check_dict_case({"Name":"John", "Age":"36", "City":"Houston"}) should return False.` |
| 12 | `    check_dict_case({"STATE":"NC", "ZIP":"12345" }) should return True.` | `// check_dict_case({"STATE":"NC", "ZIP":"12345" }) should return True.` |
| 13 | `    """` | `// ` |
