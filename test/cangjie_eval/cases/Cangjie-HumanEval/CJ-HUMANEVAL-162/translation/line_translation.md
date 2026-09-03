# Line Translation: CJ-HUMANEVAL-162

The official Python `check(candidate)` was executed against the official canonical solution through a recorder. Each candidate invocation below is translated into a concrete Cangjie assertion in `tests/TestMain.cj`.

## Static-Language Adaptation

Python `None` is represented by `Option<T>`. Python `hashlib.md5(text.encode()).hexdigest()` is projected to the official Cangjie library composition `toHexString(digest(MD5(), text.toArray()))` using `std.crypto.digest.digest`, `stdx.crypto.digest.MD5`, and `stdx.encoding.hex.toHexString`. `String.toArray()` supplies UTF-8 bytes; the hex result is lowercase and 32 characters long.

## Official Test Lines

| Source line | HumanEval test line | CangjieEval assertion label(s) |
|---:|---|---|
| 1 | `def check(candidate):` | `` |
| 2 | `` | `` |
| 3 | `    # Check some simple cases` | `` |
| 4 | `    assert candidate('Hello world') == '3e25960a79dbc69b674cd4ec67a72c62'` | `CJ-HUMANEVAL-162_l4_c001` |
| 5 | `    assert candidate('') == None` | `CJ-HUMANEVAL-162_l5_c002` |
| 6 | `    assert candidate('A B C') == '0ef78513b0cb8cef12743f5aeb35f888'` | `CJ-HUMANEVAL-162_l6_c003` |
| 7 | `    assert candidate('password') == '5f4dcc3b5aa765d61d8327deb882cf99'` | `CJ-HUMANEVAL-162_l7_c004` |
| 8 | `` | `` |
| 9 | `    # Check some edge cases that are easy to work out by hand.` | `` |
| 10 | `    assert True` | `` |
| 11 | `` | `` |
