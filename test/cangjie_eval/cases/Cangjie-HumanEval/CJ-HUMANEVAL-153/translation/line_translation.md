# Line Translation: CJ-HUMANEVAL-153

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate('Watashi', ['tEN', 'niNE', 'eIGHt8OKe']) == 'Watashi.eIGHt8OKe'` | `CJ-HUMANEVAL-153_l4_c001` |
| 5 | `    assert candidate('Boku123', ['nani', 'NazeDa', 'YEs.WeCaNe', '32145tggg']) == 'Boku123.YEs.WeCaNe'` | `CJ-HUMANEVAL-153_l5_c002` |
| 6 | `    assert candidate('__YESIMHERE', ['t', 'eMptY', 'nothing', 'zeR00', 'NuLl__', '123NoooneB321']) == '__YESIMHERE.NuLl__'` | `CJ-HUMANEVAL-153_l6_c003` |
| 7 | `    assert candidate('K', ['Ta', 'TAR', 't234An', 'cosSo']) == 'K.TAR'` | `CJ-HUMANEVAL-153_l7_c004` |
| 8 | `    assert candidate('__HAHA', ['Tab', '123', '781345', '-_-']) == '__HAHA.123'` | `CJ-HUMANEVAL-153_l8_c005` |
| 9 | `    assert candidate('YameRore', ['HhAas', 'okIWILL123', 'WorkOut', 'Fails', '-_-']) == 'YameRore.okIWILL123'` | `CJ-HUMANEVAL-153_l9_c006` |
| 10 | `    assert candidate('finNNalLLly', ['Die', 'NowW', 'Wow', 'WoW']) == 'finNNalLLly.WoW'` | `CJ-HUMANEVAL-153_l10_c007` |
| 11 | `` | `` |
| 12 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 13 | `    assert candidate('_', ['Bb', '91245']) == '_.Bb'` | `CJ-HUMANEVAL-153_l13_c008` |
| 14 | `    assert candidate('Sp', ['671235', 'Bb']) == 'Sp.671235'` | `CJ-HUMANEVAL-153_l14_c009` |
| 15 | `    ` | `` |
