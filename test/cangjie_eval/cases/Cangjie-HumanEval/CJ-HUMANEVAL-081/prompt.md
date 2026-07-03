# CJ-HUMANEVAL-081: numerical_letter_grade

- Source task: `HumanEval/81`
- Cangjie signature: `public func numerical_letter_grade(grades: ArrayList<Float64>): ArrayList<String>`
- Test calls expanded from official HumanEval: `6`
- Static-language adaptations:
  - Python int/float numeric unions are represented with Float64 where needed.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def numerical_letter_grade(grades):` | `public func numerical_letter_grade(grades: ArrayList<Float64>): ArrayList<String> {` |
| 3 | `    """It is the last week of the semester and the teacher has to give the grades` | `// It is the last week of the semester and the teacher has to give the grades` |
| 4 | `    to students. The teacher has been making her own algorithm for grading.` | `// to students. The teacher has been making her own algorithm for grading.` |
| 5 | `    The only problem is, she has lost the code she used for grading.` | `// The only problem is, she has lost the code she used for grading.` |
| 6 | `    She has given you a list of GPAs for some students and you have to write ` | `// She has given you a list of GPAs for some students and you have to write` |
| 7 | `    a function that can output a list of letter grades using the following table:` | `// a function that can output a list of letter grades using the following table:` |
| 8 | `             GPA       \|    Letter grade` | `// GPA       \|    Letter grade` |
| 9 | `              4.0                A+` | `// 4.0                A+` |
| 10 | `            > 3.7                A ` | `// > 3.7                A` |
| 11 | `            > 3.3                A- ` | `// > 3.3                A-` |
| 12 | `            > 3.0                B+` | `// > 3.0                B+` |
| 13 | `            > 2.7                B ` | `// > 2.7                B` |
| 14 | `            > 2.3                B-` | `// > 2.3                B-` |
| 15 | `            > 2.0                C+` | `// > 2.0                C+` |
| 16 | `            > 1.7                C` | `// > 1.7                C` |
| 17 | `            > 1.3                C-` | `// > 1.3                C-` |
| 18 | `            > 1.0                D+ ` | `// > 1.0                D+` |
| 19 | `            > 0.7                D ` | `// > 0.7                D` |
| 20 | `            > 0.0                D-` | `// > 0.0                D-` |
| 21 | `              0.0                E` | `// 0.0                E` |
| 22 | `    ` | `` |
| 23 | `` | `` |
| 24 | `    Example:` | `// Example:` |
| 25 | `    grade_equation([4.0, 3, 1.7, 2, 3.5]) ==> ['A+', 'B', 'C-', 'C', 'A-']` | `// grade_equation([4.0, 3, 1.7, 2, 3.5]) ==> ['A+', 'B', 'C-', 'C', 'A-']` |
| 26 | `    """` | `// ` |
