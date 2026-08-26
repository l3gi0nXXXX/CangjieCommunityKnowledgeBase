package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.*
import std.fs.{File, Path}
import std.math.*

private func case032Coefficients(values: Array<Int64>): ArrayList<Int64> {
    let out = ArrayList<Int64>()
    for (value in values) {
        out.add(value)
    }
    return out
}

private func case032PolynomialValue(coefficients: ArrayList<Int64>, x: Float64): Float64 {
    var result: Float64 = 0.0
    var i = coefficients.size
    while (i > 0) {
        i -= 1
        result = result * x + Float64(coefficients[i])
    }
    return result
}

private func case032RootAccepted(coefficients: ArrayList<Int64>, actual: Float64): Bool {
    let residual = abs(case032PolynomialValue(coefficients, actual))
    return residual < 0.0001
}

private func case032ReadUtf8(relativePath: String): String {
    try {
        return String.fromUtf8(File.readFrom(Path("cangjie_eval/cases/Cangjie-HumanEval/CJ-HUMANEVAL-032").join(relativePath)))
    } catch (_: Exception) {
        return ""
    }
}

@Test
public class CangjieHumanEvalCase032VerifierTest {
    @TestCase
    public func alternateValidRootsAreAccepted(): Unit {
        let coefficients = case032Coefficients([-4, -4, 7, 4])
        @Expect(case032RootAccepted(coefficients, -2.0), true)
        @Expect(case032RootAccepted(coefficients, 0.8430703308172534), true)
    }

    @TestCase
    public func nonRootAndResidualBoundaryAreRejected(): Unit {
        @Expect(case032RootAccepted(case032Coefficients([-4, -4, 7, 4]), 0.0), false)
        @Expect(case032RootAccepted(case032Coefficients([0, 1]), 0.000099), true)
        @Expect(case032RootAccepted(case032Coefficients([0, 1]), 0.0001), false)
        let zero: Float64 = 0.0
        @Expect(case032RootAccepted(case032Coefficients([0, 1]), zero / zero), false)
        @Expect(case032RootAccepted(case032Coefficients([0, 1]), 1.0 / zero), false)
    }

    @TestCase
    public func fixtureUsesOfficialPropertyForAllOneHundredCalls(): Unit {
        let source = case032ReadUtf8("tests/TestMain.cj")
        let plusSource = case032ReadUtf8("tests-plus/TestMain.cj")
        let metadata = case032ReadUtf8("metadata.json")
        let translation = case032ReadUtf8("translation/line_translation.md")
        @Expect(source != "", true)
        @Expect(plusSource != "", true)
        @Expect(source.split("    expectPolynomialRoot([").size - 1, 100)
        @Expect(source.contains("expectFloat64(find_zero"), false)
        @Expect(source.contains("let original = listOfInt64(values)"), true)
        @Expect(source.contains("let candidateInput = listOfInt64(values)"), true)
        @Expect(source.contains("if (!(residual < 0.0001))"), true)
        @Expect(plusSource.contains("let residual = abs(plusPolynomialValue(original, actual))"), true)
        @Expect(plusSource.contains("if (!(residual < 0.0001))"), true)
        @Expect(plusSource.contains("plusExpectFloat(actual, expected"), false)
        @Expect(metadata.contains("abs(poly(coeffs, candidateResult)) < 1e-4 property"), true)
        @Expect(translation.contains("not compared with the canonical solution's selected root"), true)
        @Expect(translation.contains("abs(poly(originalCoefficients, candidateResult)) < 0.0001"), true)
    }
}
