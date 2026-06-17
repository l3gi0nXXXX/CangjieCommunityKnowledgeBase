package cangjie_eval_fixture_test

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class UnitBasicExpectedTest {
    @TestCase
    public func addOneReturnsNextValue(): Unit {
        @Expect(addOne(41), 42)
    }
}
