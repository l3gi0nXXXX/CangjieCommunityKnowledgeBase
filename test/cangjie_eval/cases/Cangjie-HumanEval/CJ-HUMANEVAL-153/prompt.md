# CJ-HUMANEVAL-153: Strongest_Extension

- Source task: `HumanEval/153`
- Cangjie signature: `public func Strongest_Extension(class_name: String, extensions: ArrayList<String>): String`
- Test calls expanded from official HumanEval: `9`

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def Strongest_Extension(class_name, extensions):` | `public func Strongest_Extension(class_name: String, extensions: ArrayList<String>): String {` |
| 3 | `    """You will be given the name of a class (a string) and a list of extensions.` | `// You will be given the name of a class (a string) and a list of extensions.` |
| 4 | `    The extensions are to be used to load additional classes to the class. The` | `// The extensions are to be used to load additional classes to the class. The` |
| 5 | `    strength of the extension is as follows: Let CAP be the number of the uppercase` | `// strength of the extension is as follows: Let CAP be the number of the uppercase` |
| 6 | `    letters in the extension's name, and let SM be the number of lowercase letters ` | `// letters in the extension's name, and let SM be the number of lowercase letters` |
| 7 | `    in the extension's name, the strength is given by the fraction CAP - SM. ` | `// in the extension's name, the strength is given by the fraction CAP - SM.` |
| 8 | `    You should find the strongest extension and return a string in this ` | `// You should find the strongest extension and return a string in this` |
| 9 | `    format: ClassName.StrongestExtensionName.` | `// format: ClassName.StrongestExtensionName.` |
| 10 | `    If there are two or more extensions with the same strength, you should` | `// If there are two or more extensions with the same strength, you should` |
| 11 | `    choose the one that comes first in the list.` | `// choose the one that comes first in the list.` |
| 12 | `    For example, if you are given "Slices" as the class and a list of the` | `// For example, if you are given "Slices" as the class and a list of the` |
| 13 | `    extensions: ['SErviNGSliCes', 'Cheese', 'StuFfed'] then you should` | `// extensions: ['SErviNGSliCes', 'Cheese', 'StuFfed'] then you should` |
| 14 | `    return 'Slices.SErviNGSliCes' since 'SErviNGSliCes' is the strongest extension ` | `// return 'Slices.SErviNGSliCes' since 'SErviNGSliCes' is the strongest extension` |
| 15 | `    (its strength is -1).` | `// (its strength is -1).` |
| 16 | `    Example:` | `// Example:` |
| 17 | `    for Strongest_Extension('my_class', ['AA', 'Be', 'CC']) == 'my_class.AA'` | `// for Strongest_Extension('my_class', ['AA', 'Be', 'CC']) == 'my_class.AA'` |
| 18 | `    """` | `// ` |
