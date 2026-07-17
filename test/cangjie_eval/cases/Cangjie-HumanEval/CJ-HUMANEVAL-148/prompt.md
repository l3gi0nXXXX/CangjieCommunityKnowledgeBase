# CJ-HUMANEVAL-148: bf

- Source task: `HumanEval/148`
- Cangjie signature: `public func bf(planet1: String, planet2: String): EvalValue`
- Test calls expanded from official HumanEval: `7`
- Static-language adaptations:
  - Python variable-length tuple return is represented by `evalStringTuple([...])`: an `EvalValue` with `kind == "tuple"` and ordered elements in `stringValues: ArrayList<String>`.
  - A list-tagged or string value is not a tuple and does not satisfy the contract, even when its elements or display text match.
  - Tuple values must not carry unrelated scalar payload; those fields must remain at their default values.

## Model-Facing Task

Implement the function in `starter/src/solution.cj` according to the source task. Keep the public Cangjie signature unchanged.

## Line-by-Line Prompt Translation

| Source line | HumanEval Python prompt | CangjieEval translation |
|---:|---|---|
| 1 | `` | `` |
| 2 | `def bf(planet1, planet2):` | `public func bf(planet1: String, planet2: String): EvalValue {` |
| 3 | `    '''` | `// '''` |
| 4 | `    There are eight planets in our solar system: the closerst to the Sun ` | `// There are eight planets in our solar system: the closerst to the Sun` |
| 5 | `    is Mercury, the next one is Venus, then Earth, Mars, Jupiter, Saturn, ` | `// is Mercury, the next one is Venus, then Earth, Mars, Jupiter, Saturn,` |
| 6 | `    Uranus, Neptune.` | `// Uranus, Neptune.` |
| 7 | `    Write a function that takes two planet names as strings planet1 and planet2. ` | `// Write a function that takes two planet names as strings planet1 and planet2.` |
| 8 | `    The function should return a tuple containing all planets whose orbits are ` | `// The function should return a tuple containing all planets whose orbits are` |
| 9 | `    located between the orbit of planet1 and the orbit of planet2, sorted by ` | `// located between the orbit of planet1 and the orbit of planet2, sorted by` |
| 10 | `    the proximity to the sun. ` | `// the proximity to the sun.` |
| 11 | `    The function should return an empty tuple if planet1 or planet2` | `// The function should return an empty tuple if planet1 or planet2` |
| 12 | `    are not correct planet names. ` | `// are not correct planet names.` |
| 13 | `    Examples` | `// Examples` |
| 14 | `    bf("Jupiter", "Neptune") ==> ("Saturn", "Uranus")` | `// bf("Jupiter", "Neptune") ==> ("Saturn", "Uranus")` |
| 15 | `    bf("Earth", "Mercury") ==> ("Venus")` | `// bf("Earth", "Mercury") ==> ("Venus")` |
| 16 | `    bf("Mercury", "Uranus") ==> ("Venus", "Earth", "Mars", "Jupiter", "Saturn")` | `// bf("Mercury", "Uranus") ==> ("Venus", "Earth", "Mars", "Jupiter", "Saturn")` |
| 17 | `    '''` | `// '''` |
