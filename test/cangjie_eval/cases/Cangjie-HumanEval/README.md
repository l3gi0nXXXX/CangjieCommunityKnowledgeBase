# Cangjie-HumanEval

This directory contains a full 164-case CangjieEval translation pack derived from OpenAI HumanEval.

- Source dataset: https://github.com/openai/human-eval
- Source license: MIT, copied under `test/cangjie_eval/sources/openai-human-eval/LICENSE`.
- Cases: 164
- Candidate invocations translated to Cangjie assertions: 1534

The authority preserves official calls and expected values while expressing them through explicit Cangjie types. These typed Cangjie contracts do not claim full Python duck-typing compatibility. Whenever Python subtype, iterable, `None`, or container identity semantics are narrowed or represented differently, `metadata.json`, `prompt.md`, and `translation/line_translation.md` must state that adaptation without changing the official observed values.

## Directory Contract

Each case contains:

- `prompt.md`: model-facing task and line-by-line prompt translation.
- `metadata.json`: source mapping, signature, type adaptations, and call count.
- `starter/`: package copied for model execution; the model edits only `starter/src/solution.cj`.
- `tests/TestMain.cj`: executable assertion main generated from official HumanEval tests.
- `tests/cjpm.executable.toml`: test-time `cjpm.toml` replacing the static starter config.
- `reference/`: original HumanEval prompt, canonical solution, and test for traceability. Do not expose this directory to models during evaluation.
- `translation/line_translation.md`: official Python test lines mapped to generated Cangjie assertion labels.

## Manual Run Shape

```bash
CASE=test/cangjie_eval/cases/Cangjie-HumanEval/CJ-HUMANEVAL-000
RUN=/tmp/cangjie-humaneval-000
rm -rf "$RUN"
cp -R "$CASE/starter" "$RUN"
cp "$CASE/tests/TestMain.cj" "$RUN/src/test_main.cj"
cp "$CASE/tests/cjpm.executable.toml" "$RUN/cjpm.toml"
cd "$RUN"
cjpm run
```

With the generated TODO starter, the package should compile and fail assertions for most cases. A model-produced solution passes only when `cjpm run` exits 0 and prints `<CASE_ID> ok`.

## Static-Language Adaptation Policy

Python dynamic constructs are translated conservatively:

- Python `None` result unions become `Option<T>`.
- Python `int`/`float` unions become `Float64` where the problem is numeric.
- Python mixed dynamic values become `EvalValue` / `EvalEntry`.
- Python variable-length tuple returns become typed `ArrayList<T>`.

These adaptations are recorded per case in `metadata.json`.

## Case Summary

| Case | Source | Entry point | Calls | Signature | Adaptations |
|---|---|---|---:|---|---|
| `CJ-HUMANEVAL-000` | `HumanEval/0` | `has_close_elements` | 7 | `public func has_close_elements(numbers: ArrayList<Float64>, threshold: Float64): Bool` | none |
| `CJ-HUMANEVAL-001` | `HumanEval/1` | `separate_paren_groups` | 4 | `public func separate_paren_groups(paren_string: String): ArrayList<String>` | none |
| `CJ-HUMANEVAL-002` | `HumanEval/2` | `truncate_number` | 3 | `public func truncate_number(number: Float64): Float64` | none |
| `CJ-HUMANEVAL-003` | `HumanEval/3` | `below_zero` | 6 | `public func below_zero(operations: ArrayList<Int64>): Bool` | none |
| `CJ-HUMANEVAL-004` | `HumanEval/4` | `mean_absolute_deviation` | 3 | `public func mean_absolute_deviation(numbers: ArrayList<Float64>): Float64` | none |
| `CJ-HUMANEVAL-005` | `HumanEval/5` | `intersperse` | 3 | `public func intersperse(numbers: ArrayList<Int64>, delimeter: Int64): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-006` | `HumanEval/6` | `parse_nested_parens` | 3 | `public func parse_nested_parens(paren_string: String): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-007` | `HumanEval/7` | `filter_by_substring` | 4 | `public func filter_by_substring(strings: ArrayList<String>, substring: String): ArrayList<String>` | none |
| `CJ-HUMANEVAL-008` | `HumanEval/8` | `sum_product` | 5 | `public func sum_product(numbers: ArrayList<Int64>): (Int64, Int64)` | none |
| `CJ-HUMANEVAL-009` | `HumanEval/9` | `rolling_max` | 4 | `public func rolling_max(numbers: ArrayList<Int64>): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-010` | `HumanEval/10` | `make_palindrome` | 5 | `public func make_palindrome(string: String): String` | none |
| `CJ-HUMANEVAL-011` | `HumanEval/11` | `string_xor` | 3 | `public func string_xor(a: String, b: String): String` | none |
| `CJ-HUMANEVAL-012` | `HumanEval/12` | `longest` | 3 | `public func longest(strings: ArrayList<String>): Option<String>` | Python None returns are represented by Option<T>. |
| `CJ-HUMANEVAL-013` | `HumanEval/13` | `greatest_common_divisor` | 4 | `public func greatest_common_divisor(a: Int64, b: Int64): Int64` | none |
| `CJ-HUMANEVAL-014` | `HumanEval/14` | `all_prefixes` | 3 | `public func all_prefixes(string: String): ArrayList<String>` | none |
| `CJ-HUMANEVAL-015` | `HumanEval/15` | `string_sequence` | 3 | `public func string_sequence(n: Int64): String` | none |
| `CJ-HUMANEVAL-016` | `HumanEval/16` | `count_distinct_characters` | 5 | `public func count_distinct_characters(string: String): Int64` | none |
| `CJ-HUMANEVAL-017` | `HumanEval/17` | `parse_music` | 5 | `public func parse_music(music_string: String): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-018` | `HumanEval/18` | `how_many_times` | 4 | `public func how_many_times(string: String, substring: String): Int64` | none |
| `CJ-HUMANEVAL-019` | `HumanEval/19` | `sort_numbers` | 5 | `public func sort_numbers(numbers: String): String` | none |
| `CJ-HUMANEVAL-020` | `HumanEval/20` | `find_closest_elements` | 5 | `public func find_closest_elements(numbers: ArrayList<Float64>): (Float64, Float64)` | none |
| `CJ-HUMANEVAL-021` | `HumanEval/21` | `rescale_to_unit` | 5 | `public func rescale_to_unit(numbers: ArrayList<Float64>): ArrayList<Float64>` | none |
| `CJ-HUMANEVAL-022` | `HumanEval/22` | `filter_integers` | 3 | `public func filter_integers(values: ArrayList<EvalValue>): ArrayList<Int64>` | Python dynamic values use EvalValue/EvalEntry; Cangjie Bool is not accepted as Int64, unlike Python bool-as-int. |
| `CJ-HUMANEVAL-023` | `HumanEval/23` | `strlen` | 3 | `public func strlen(string: String): Int64` | none |
| `CJ-HUMANEVAL-024` | `HumanEval/24` | `largest_divisor` | 5 | `public func largest_divisor(n: Int64): Int64` | none |
| `CJ-HUMANEVAL-025` | `HumanEval/25` | `factorize` | 8 | `public func factorize(n: Int64): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-026` | `HumanEval/26` | `remove_duplicates` | 3 | `public func remove_duplicates(numbers: ArrayList<Int64>): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-027` | `HumanEval/27` | `flip_case` | 3 | `public func flip_case(string: String): String` | none |
| `CJ-HUMANEVAL-028` | `HumanEval/28` | `concatenate` | 3 | `public func concatenate(strings: ArrayList<String>): String` | none |
| `CJ-HUMANEVAL-029` | `HumanEval/29` | `filter_by_prefix` | 2 | `public func filter_by_prefix(strings: ArrayList<String>, prefix: String): ArrayList<String>` | none |
| `CJ-HUMANEVAL-030` | `HumanEval/30` | `get_positive` | 4 | `public func get_positive(l: ArrayList<Int64>): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-031` | `HumanEval/31` | `is_prime` | 13 | `public func is_prime(n: Int64): Bool` | none |
| `CJ-HUMANEVAL-032` | `HumanEval/32` | `find_zero` | 100 | `public func find_zero(xs: ArrayList<Int64>): Float64` | none |
| `CJ-HUMANEVAL-033` | `HumanEval/33` | `sort_third` | 7 | `public func sort_third(l: ArrayList<Int64>): ArrayList<Int64>` | Python tuple(candidate(...)) iterable acceptance is projected to ArrayList<Int64>. |
| `CJ-HUMANEVAL-034` | `HumanEval/34` | `unique` | 1 | `public func unique(l: ArrayList<Int64>): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-035` | `HumanEval/35` | `max_element` | 2 | `public func max_element(l: ArrayList<Int64>): Int64` | none |
| `CJ-HUMANEVAL-036` | `HumanEval/36` | `fizz_buzz` | 8 | `public func fizz_buzz(n: Int64): Int64` | none |
| `CJ-HUMANEVAL-037` | `HumanEval/37` | `sort_even` | 3 | `public func sort_even(l: ArrayList<Int64>): ArrayList<Int64>` | Python tuple(candidate(...)) iterable acceptance is projected to ArrayList<Int64>. |
| `CJ-HUMANEVAL-038` | `HumanEval/38` | `decode_cyclic` | 100 | `public func decode_cyclic(s: String): String` | none |
| `CJ-HUMANEVAL-039` | `HumanEval/39` | `prime_fib` | 10 | `public func prime_fib(n: Int64): Int64` | none |
| `CJ-HUMANEVAL-040` | `HumanEval/40` | `triples_sum_to_zero` | 9 | `public func triples_sum_to_zero(l: ArrayList<Int64>): Bool` | none |
| `CJ-HUMANEVAL-041` | `HumanEval/41` | `car_race_collision` | 5 | `public func car_race_collision(n: Int64): Int64` | none |
| `CJ-HUMANEVAL-042` | `HumanEval/42` | `incr_list` | 3 | `public func incr_list(l: ArrayList<Int64>): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-043` | `HumanEval/43` | `pairs_sum_to_zero` | 9 | `public func pairs_sum_to_zero(l: ArrayList<Int64>): Bool` | none |
| `CJ-HUMANEVAL-044` | `HumanEval/44` | `change_base` | 12 | `public func change_base(x: Int64, base: Int64): String` | none |
| `CJ-HUMANEVAL-045` | `HumanEval/45` | `triangle_area` | 3 | `public func triangle_area(a: Int64, h: Int64): Float64` | none |
| `CJ-HUMANEVAL-046` | `HumanEval/46` | `fib4` | 4 | `public func fib4(n: Int64): Int64` | none |
| `CJ-HUMANEVAL-047` | `HumanEval/47` | `median` | 5 | `public func median(l: ArrayList<Int64>): Float64` | Python int/float numeric unions are represented with Float64 where needed. |
| `CJ-HUMANEVAL-048` | `HumanEval/48` | `is_palindrome` | 7 | `public func is_palindrome(text: String): Bool` | none |
| `CJ-HUMANEVAL-049` | `HumanEval/49` | `modp` | 7 | `public func modp(n: Int64, p: Int64): Int64` | none |
| `CJ-HUMANEVAL-050` | `HumanEval/50` | `decode_shift` | 100 | `public func decode_shift(s: String): String` | none |
| `CJ-HUMANEVAL-051` | `HumanEval/51` | `remove_vowels` | 7 | `public func remove_vowels(text: String): String` | none |
| `CJ-HUMANEVAL-052` | `HumanEval/52` | `below_threshold` | 6 | `public func below_threshold(l: ArrayList<Int64>, t: Int64): Bool` | none |
| `CJ-HUMANEVAL-053` | `HumanEval/53` | `add` | 105 | `public func add(x: Int64, y: Int64): Int64` | none |
| `CJ-HUMANEVAL-054` | `HumanEval/54` | `same_chars` | 7 | `public func same_chars(s0: String, s1: String): Bool` | none |
| `CJ-HUMANEVAL-055` | `HumanEval/55` | `fib` | 5 | `public func fib(n: Int64): Int64` | none |
| `CJ-HUMANEVAL-056` | `HumanEval/56` | `correct_bracketing` | 12 | `public func correct_bracketing(brackets: String): Bool` | none |
| `CJ-HUMANEVAL-057` | `HumanEval/57` | `monotonic` | 8 | `public func monotonic(l: ArrayList<Int64>): Bool` | none |
| `CJ-HUMANEVAL-058` | `HumanEval/58` | `common` | 4 | `public func common(l1: ArrayList<Int64>, l2: ArrayList<Int64>): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-059` | `HumanEval/59` | `largest_prime_factor` | 5 | `public func largest_prime_factor(n: Int64): Int64` | none |
| `CJ-HUMANEVAL-060` | `HumanEval/60` | `sum_to_n` | 5 | `public func sum_to_n(n: Int64): Int64` | none |
| `CJ-HUMANEVAL-061` | `HumanEval/61` | `correct_bracketing` | 12 | `public func correct_bracketing(brackets: String): Bool` | none |
| `CJ-HUMANEVAL-062` | `HumanEval/62` | `derivative` | 5 | `public func derivative(xs: ArrayList<Int64>): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-063` | `HumanEval/63` | `fibfib` | 7 | `public func fibfib(n: Int64): Int64` | none |
| `CJ-HUMANEVAL-064` | `HumanEval/64` | `vowels_count` | 7 | `public func vowels_count(s: String): Int64` | none |
| `CJ-HUMANEVAL-065` | `HumanEval/65` | `circular_shift` | 5 | `public func circular_shift(x: Int64, shift: Int64): String` | none |
| `CJ-HUMANEVAL-066` | `HumanEval/66` | `digitSum` | 8 | `public func digitSum(s: String): Int64` | none |
| `CJ-HUMANEVAL-067` | `HumanEval/67` | `fruit_distribution` | 7 | `public func fruit_distribution(s: String, n: Int64): Int64` | none |
| `CJ-HUMANEVAL-068` | `HumanEval/68` | `pluck` | 8 | `public func pluck(arr: ArrayList<Int64>): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-069` | `HumanEval/69` | `search` | 25 | `public func search(lst: ArrayList<Int64>): Int64` | none |
| `CJ-HUMANEVAL-070` | `HumanEval/70` | `strange_sort_list` | 9 | `public func strange_sort_list(lst: ArrayList<Int64>): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-071` | `HumanEval/71` | `triangle_area` | 9 | `public func triangle_area(a: Int64, b: Int64, c: Int64): Float64` | Python int/float numeric unions are represented with Float64 where needed. |
| `CJ-HUMANEVAL-072` | `HumanEval/72` | `will_it_fly` | 6 | `public func will_it_fly(q: ArrayList<Int64>, w: Int64): Bool` | none |
| `CJ-HUMANEVAL-073` | `HumanEval/73` | `smallest_change` | 8 | `public func smallest_change(arr: ArrayList<Int64>): Int64` | none |
| `CJ-HUMANEVAL-074` | `HumanEval/74` | `total_match` | 9 | `public func total_match(lst1: ArrayList<String>, lst2: ArrayList<String>): ArrayList<String>` | none |
| `CJ-HUMANEVAL-075` | `HumanEval/75` | `is_multiply_prime` | 10 | `public func is_multiply_prime(a: Int64): Bool` | none |
| `CJ-HUMANEVAL-076` | `HumanEval/76` | `is_simple_power` | 10 | `public func is_simple_power(x: Int64, n: Int64): Bool` | none |
| `CJ-HUMANEVAL-077` | `HumanEval/77` | `iscube` | 8 | `public func iscube(a: Int64): Bool` | none |
| `CJ-HUMANEVAL-078` | `HumanEval/78` | `hex_key` | 7 | `public func hex_key(num: EvalValue): Int64` | Official strings use `evalString`; the official empty-list input uses `evalEmptyList`, preserving distinct runtime type identities. |
| `CJ-HUMANEVAL-079` | `HumanEval/79` | `decimal_to_binary` | 4 | `public func decimal_to_binary(decimal: Int64): String` | none |
| `CJ-HUMANEVAL-080` | `HumanEval/80` | `is_happy` | 8 | `public func is_happy(s: String): Bool` | none |
| `CJ-HUMANEVAL-081` | `HumanEval/81` | `numerical_letter_grade` | 6 | `public func numerical_letter_grade(grades: ArrayList<Float64>): ArrayList<String>` | Python int/float numeric unions are represented with Float64 where needed. |
| `CJ-HUMANEVAL-082` | `HumanEval/82` | `prime_length` | 16 | `public func prime_length(string: String): Bool` | none |
| `CJ-HUMANEVAL-083` | `HumanEval/83` | `starts_one_ends` | 5 | `public func starts_one_ends(n: Int64): Int64` | none |
| `CJ-HUMANEVAL-084` | `HumanEval/84` | `solve` | 5 | `public func solve(N: Int64): String` | none |
| `CJ-HUMANEVAL-085` | `HumanEval/85` | `add` | 4 | `public func add(lst: ArrayList<Int64>): Int64` | none |
| `CJ-HUMANEVAL-086` | `HumanEval/86` | `anti_shuffle` | 7 | `public func anti_shuffle(s: String): String` | none |
| `CJ-HUMANEVAL-087` | `HumanEval/87` | `get_row` | 6 | `public func get_row(lst: ArrayList<ArrayList<Int64>>, x: Int64): ArrayList<(Int64, Int64)>` | none |
| `CJ-HUMANEVAL-088` | `HumanEval/88` | `sort_array` | 7 | `public func sort_array(array: ArrayList<Int64>): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-089` | `HumanEval/89` | `encrypt` | 8 | `public func encrypt(s: String): String` | none |
| `CJ-HUMANEVAL-090` | `HumanEval/90` | `next_smallest` | 7 | `public func next_smallest(lst: ArrayList<Int64>): Option<Int64>` | Python None returns are represented by Option<T>. |
| `CJ-HUMANEVAL-091` | `HumanEval/91` | `is_bored` | 6 | `public func is_bored(S: String): Int64` | none |
| `CJ-HUMANEVAL-092` | `HumanEval/92` | `any_int` | 10 | `public func any_int(x: EvalValue, y: EvalValue, z: EvalValue): Bool` | `evalInt`/`evalFloat` preserve Python numeric type identity; integer payloads use Int64. |
| `CJ-HUMANEVAL-093` | `HumanEval/93` | `encode` | 5 | `public func encode(message: String): String` | none |
| `CJ-HUMANEVAL-094` | `HumanEval/94` | `skjkasdkd` | 9 | `public func skjkasdkd(lst: ArrayList<Int64>): Int64` | none |
| `CJ-HUMANEVAL-095` | `HumanEval/95` | `check_dict_case` | 7 | `public func check_dict_case(dictValue: ArrayList<EvalEntry>): Bool` | Python dynamic values are represented by EvalValue/EvalEntry helper types. |
| `CJ-HUMANEVAL-096` | `HumanEval/96` | `count_up_to` | 10 | `public func count_up_to(n: Int64): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-097` | `HumanEval/97` | `multiply` | 8 | `public func multiply(a: Int64, b: Int64): Int64` | none |
| `CJ-HUMANEVAL-098` | `HumanEval/98` | `count_upper` | 7 | `public func count_upper(s: String): Int64` | none |
| `CJ-HUMANEVAL-099` | `HumanEval/99` | `closest_integer` | 5 | `public func closest_integer(value: String): Int64` | none |
| `CJ-HUMANEVAL-100` | `HumanEval/100` | `make_a_pile` | 5 | `public func make_a_pile(n: Int64): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-101` | `HumanEval/101` | `words_string` | 6 | `public func words_string(s: String): ArrayList<String>` | none |
| `CJ-HUMANEVAL-102` | `HumanEval/102` | `choose_num` | 8 | `public func choose_num(x: Int64, y: Int64): Int64` | none |
| `CJ-HUMANEVAL-103` | `HumanEval/103` | `rounded_avg` | 12 | `public func rounded_avg(n: Int64, m: Int64): EvalValue` | Python dynamic values are represented by EvalValue/EvalEntry helper types. |
| `CJ-HUMANEVAL-104` | `HumanEval/104` | `unique_digits` | 4 | `public func unique_digits(x: ArrayList<Int64>): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-105` | `HumanEval/105` | `by_length` | 5 | `public func by_length(arr: ArrayList<Int64>): ArrayList<String>` | none |
| `CJ-HUMANEVAL-106` | `HumanEval/106` | `f` | 4 | `public func f(n: Int64): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-107` | `HumanEval/107` | `even_odd_palindrome` | 8 | `public func even_odd_palindrome(n: Int64): (Int64, Int64)` | none |
| `CJ-HUMANEVAL-108` | `HumanEval/108` | `count_nums` | 8 | `public func count_nums(arr: ArrayList<Int64>): Int64` | none |
| `CJ-HUMANEVAL-109` | `HumanEval/109` | `move_one_ball` | 5 | `public func move_one_ball(arr: ArrayList<Int64>): Bool` | none |
| `CJ-HUMANEVAL-110` | `HumanEval/110` | `exchange` | 7 | `public func exchange(lst1: ArrayList<Int64>, lst2: ArrayList<Int64>): String` | none |
| `CJ-HUMANEVAL-111` | `HumanEval/111` | `histogram` | 8 | `public func histogram(test: String): HashMap<String, Int64>` | none |
| `CJ-HUMANEVAL-112` | `HumanEval/112` | `reverse_delete` | 9 | `public func reverse_delete(s: String, c: String): (String, Bool)` | none |
| `CJ-HUMANEVAL-113` | `HumanEval/113` | `odd_count` | 3 | `public func odd_count(lst: ArrayList<String>): ArrayList<String>` | none |
| `CJ-HUMANEVAL-114` | `HumanEval/114` | `minSubArraySum` | 12 | `public func minSubArraySum(nums: ArrayList<Int64>): Int64` | none |
| `CJ-HUMANEVAL-115` | `HumanEval/115` | `max_fill` | 5 | `public func max_fill(grid: ArrayList<ArrayList<Int64>>, capacity: Int64): Int64` | none |
| `CJ-HUMANEVAL-116` | `HumanEval/116` | `sort_array` | 8 | `public func sort_array(arr: ArrayList<Int64>): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-117` | `HumanEval/117` | `select_words` | 7 | `public func select_words(s: String, n: Int64): ArrayList<String>` | none |
| `CJ-HUMANEVAL-118` | `HumanEval/118` | `get_closest_vowel` | 13 | `public func get_closest_vowel(word: String): String` | none |
| `CJ-HUMANEVAL-119` | `HumanEval/119` | `match_parens` | 12 | `public func match_parens(lst: ArrayList<String>): String` | none |
| `CJ-HUMANEVAL-120` | `HumanEval/120` | `maximum` | 11 | `public func maximum(arr: ArrayList<Int64>, k: Int64): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-121` | `HumanEval/121` | `solution` | 7 | `public func solution(lst: ArrayList<Int64>): Int64` | none |
| `CJ-HUMANEVAL-122` | `HumanEval/122` | `add_elements` | 5 | `public func add_elements(arr: ArrayList<Int64>, k: Int64): Int64` | none |
| `CJ-HUMANEVAL-123` | `HumanEval/123` | `get_odd_collatz` | 4 | `public func get_odd_collatz(n: Int64): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-124` | `HumanEval/124` | `valid_date` | 16 | `public func valid_date(date: String): Bool` | none |
| `CJ-HUMANEVAL-125` | `HumanEval/125` | `split_words` | 8 | `public func split_words(txt: String): EvalValue` | Python `list[str] \| int` is preserved with exact `string_list` and `int` tagged payloads; serialized list text is rejected. |
| `CJ-HUMANEVAL-126` | `HumanEval/126` | `is_sorted` | 13 | `public func is_sorted(lst: ArrayList<Int64>): Bool` | none |
| `CJ-HUMANEVAL-127` | `HumanEval/127` | `intersection` | 8 | `public func intersection(interval1: (Int64, Int64), interval2: (Int64, Int64)): String` | none |
| `CJ-HUMANEVAL-128` | `HumanEval/128` | `prod_signs` | 8 | `public func prod_signs(arr: ArrayList<Int64>): Option<Int64>` | Python None returns are represented by Option<T>. |
| `CJ-HUMANEVAL-129` | `HumanEval/129` | `minPath` | 11 | `public func minPath(grid: ArrayList<ArrayList<Int64>>, k: Int64): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-130` | `HumanEval/130` | `tri` | 10 | `public func tri(n: Int64): ArrayList<Float64>` | Python int/float numeric unions are represented with Float64 where needed. |
| `CJ-HUMANEVAL-131` | `HumanEval/131` | `digits` | 7 | `public func digits(n: Int64): Int64` | none |
| `CJ-HUMANEVAL-132` | `HumanEval/132` | `is_nested` | 14 | `public func is_nested(string: String): Bool` | none |
| `CJ-HUMANEVAL-133` | `HumanEval/133` | `sum_squares` | 12 | `public func sum_squares(lst: ArrayList<Float64>): Int64` | Python int/float numeric unions are represented with Float64 where needed. |
| `CJ-HUMANEVAL-134` | `HumanEval/134` | `check_if_last_char_is_a_letter` | 10 | `public func check_if_last_char_is_a_letter(txt: String): Bool` | none |
| `CJ-HUMANEVAL-135` | `HumanEval/135` | `can_arrange` | 5 | `public func can_arrange(arr: ArrayList<Int64>): Int64` | none |
| `CJ-HUMANEVAL-136` | `HumanEval/136` | `largest_smallest_integers` | 11 | `public func largest_smallest_integers(lst: ArrayList<Int64>): (Option<Int64>, Option<Int64>)` | Python None/integer tuple positions map to None<Int64>/Some<Int64>(value). |
| `CJ-HUMANEVAL-137` | `HumanEval/137` | `compare_one` | 8 | `public func compare_one(a: EvalValue, b: EvalValue): EvalValue` | Python dynamic values are represented by EvalValue/EvalEntry helper types. |
| `CJ-HUMANEVAL-138` | `HumanEval/138` | `is_equal_to_sum_even` | 8 | `public func is_equal_to_sum_even(n: Int64): Bool` | none |
| `CJ-HUMANEVAL-139` | `HumanEval/139` | `special_factorial` | 4 | `public func special_factorial(n: Int64): Int64` | none |
| `CJ-HUMANEVAL-140` | `HumanEval/140` | `fix_spaces` | 5 | `public func fix_spaces(text: String): String` | none |
| `CJ-HUMANEVAL-141` | `HumanEval/141` | `file_name_check` | 26 | `public func file_name_check(file_name: String): String` | none |
| `CJ-HUMANEVAL-142` | `HumanEval/142` | `sum_squares` | 11 | `public func sum_squares(lst: ArrayList<Int64>): Int64` | none |
| `CJ-HUMANEVAL-143` | `HumanEval/143` | `words_in_sentence` | 7 | `public func words_in_sentence(sentence: String): String` | none |
| `CJ-HUMANEVAL-144` | `HumanEval/144` | `simplify` | 13 | `public func simplify(x: String, n: String): Bool` | none |
| `CJ-HUMANEVAL-145` | `HumanEval/145` | `order_by_points` | 6 | `public func order_by_points(nums: ArrayList<Int64>): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-146` | `HumanEval/146` | `specialFilter` | 7 | `public func specialFilter(nums: ArrayList<Int64>): Int64` | none |
| `CJ-HUMANEVAL-147` | `HumanEval/147` | `get_max_triples` | 4 | `public func get_max_triples(n: Int64): Int64` | none |
| `CJ-HUMANEVAL-148` | `HumanEval/148` | `bf` | 7 | `public func bf(planet1: String, planet2: String): EvalValue` | Python variable-length tuple return uses tuple-tagged `EvalValue` with exact ordered string payload; list tags are rejected. |
| `CJ-HUMANEVAL-149` | `HumanEval/149` | `sorted_list_sum` | 7 | `public func sorted_list_sum(lst: ArrayList<String>): ArrayList<String>` | none |
| `CJ-HUMANEVAL-150` | `HumanEval/150` | `x_or_y` | 10 | `public func x_or_y(n: Int64, x: Int64, y: Int64): Int64` | none |
| `CJ-HUMANEVAL-151` | `HumanEval/151` | `double_the_difference` | 9 | `public func double_the_difference(lst: ArrayList<EvalValue>): Int64` | Python int and float identities are preserved with EvalValue tags. |
| `CJ-HUMANEVAL-152` | `HumanEval/152` | `compare` | 4 | `public func compare(game: ArrayList<Int64>, guess: ArrayList<Int64>): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-153` | `HumanEval/153` | `Strongest_Extension` | 9 | `public func Strongest_Extension(class_name: String, extensions: ArrayList<String>): String` | none |
| `CJ-HUMANEVAL-154` | `HumanEval/154` | `cycpattern_check` | 6 | `public func cycpattern_check(a: String, b: String): Bool` | none |
| `CJ-HUMANEVAL-155` | `HumanEval/155` | `even_odd_count` | 8 | `public func even_odd_count(num: Int64): (Int64, Int64)` | none |
| `CJ-HUMANEVAL-156` | `HumanEval/156` | `int_to_mini_roman` | 14 | `public func int_to_mini_roman(number: Int64): String` | none |
| `CJ-HUMANEVAL-157` | `HumanEval/157` | `right_angle_triangle` | 11 | `public func right_angle_triangle(a: Int64, b: Int64, c: Int64): Bool` | none |
| `CJ-HUMANEVAL-158` | `HumanEval/158` | `find_max` | 10 | `public func find_max(words: ArrayList<String>): String` | none |
| `CJ-HUMANEVAL-159` | `HumanEval/159` | `eat` | 6 | `public func eat(number: Int64, need: Int64, remaining: Int64): ArrayList<Int64>` | none |
| `CJ-HUMANEVAL-160` | `HumanEval/160` | `do_algebra` | 3 | `public func do_algebra(operatorValue: ArrayList<String>, operand: ArrayList<Int64>): Int64` | none |
| `CJ-HUMANEVAL-161` | `HumanEval/161` | `solve` | 8 | `public func solve(s: String): String` | none |
| `CJ-HUMANEVAL-162` | `HumanEval/162` | `string_to_md5` | 4 | `public func string_to_md5(text: String): Option<String>` | Python None returns are represented by Option<T>. |
| `CJ-HUMANEVAL-163` | `HumanEval/163` | `generate_integers` | 4 | `public func generate_integers(a: Int64, b: Int64): ArrayList<Int64>` | none |
