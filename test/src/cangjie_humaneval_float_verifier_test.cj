package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*
import std.fs.{File, Path}
import std.math.*

private let hfvExactCaseIds: Array<String> = ["020", "021", "045", "047", "071", "130", "137"]

private func hfvReadUtf8(caseId: String, relativePath: String): String {
    let root = Path("cangjie_eval/cases/Cangjie-HumanEval/CJ-HUMANEVAL-${caseId}")
    try {
        return String.fromUtf8(File.readFrom(root.join(relativePath)))
    } catch (_: Exception) {
        return ""
    }
}

private func hfvExactAccepted(actual: Float64, expected: Float64): Bool {
    return actual == expected
}

private func hfvStrictEpsilonAccepted(actual: Float64, expected: Float64): Bool {
    return abs(actual - expected) < 0.000001
}

private func hfvStrictDifferenceAccepted(difference: Float64): Bool {
    return difference < 0.000001
}

@Test
public class CangjieHumanEvalFloatVerifierTest {
    @TestCase
    public func hfvUt01OfficialPositivePredicatesArePreserved(): Unit {
        @Expect(hfvExactAccepted(7.5, 7.5), true)
        @Expect(hfvStrictEpsilonAccepted(0.3300005, 0.33), true)
        @Expect(hfvStrictEpsilonAccepted(1.2, 1.2), true)
    }

    @TestCase
    public func hfvBnd01StrictBoundaryIsOpen(): Unit {
        @Expect(hfvStrictDifferenceAccepted(0.000000999), true)
        @Expect(hfvStrictDifferenceAccepted(0.000001), false)
        @Expect(hfvStrictDifferenceAccepted(0.000001001), false)
    }

    @TestCase
    public func hfvNeg01NaNAndEqualityDriftFailClosed(): Unit {
        let zero: Float64 = 0.0
        let nan = zero / zero
        @Expect(hfvExactAccepted(nan, 1.0), false)
        @Expect(hfvStrictEpsilonAccepted(nan, 1.0), false)
        @Expect(hfvExactAccepted(7.5000001, 7.5), false)
    }

    @TestCase
    public func hfvAudit01NineFixturesDeclareAndImplementOfficialOracles(): Unit {
        let case002 = hfvReadUtf8("002", "tests/TestMain.cj")
        @Expect(case002.contains("if (actual != expected)"), true)
        @Expect(case002.contains("if (!(abs(actual - expected) < 0.000001))"), true)
        @Expect(case002.contains("expectFloat64(truncate_number(3.5), 0.5"), true)
        @Expect(case002.contains("expectFloat64StrictEpsilon(truncate_number(1.33), 0.33"), true)
        @Expect(case002.contains("expectFloat64StrictEpsilon(truncate_number(123.456), 0.456"), true)
        @Expect(case002.contains("abs(actual - expected) > 0.000001"), false)

        let case004 = hfvReadUtf8("004", "tests/TestMain.cj")
        @Expect(case004.contains("if (!(abs(actual - expected) < 0.000001))"), true)
        @Expect(case004.contains("abs(actual - expected) > 0.000001"), false)

        for (caseId in hfvExactCaseIds) {
            let source = hfvReadUtf8(caseId, "tests/TestMain.cj")
            let metadata = hfvReadUtf8(caseId, "metadata.json")
            let translation = hfvReadUtf8(caseId, "translation/line_translation.md")
            @Expect(source != "", true)
            @Expect(source.contains("func expectFloat64(actual: Float64, expected: Float64, label: String): Unit { if (actual != expected)"), true)
            @Expect(source.contains("abs(actual - expected) > 0.000001"), false)
            @Expect(metadata.contains("exact"), true)
            @Expect(metadata.contains("NaN fails closed"), true)
            @Expect(translation.contains("exact"), true)
            @Expect(translation.contains("NaN is rejected"), true)
        }

        @Expect(hfvReadUtf8("002", "metadata.json").contains("strict abs(actual - official expected) < 1e-6"), true)
        @Expect(hfvReadUtf8("004", "metadata.json").contains("strict abs(actual - official expected) < 1e-6"), true)
        @Expect(hfvReadUtf8("002", "translation/line_translation.md").contains("strict `abs(actual - expected) < 1e-6`"), true)
        @Expect(hfvReadUtf8("004", "translation/line_translation.md").contains("strict `abs(actual - expected) < 1e-6`"), true)
    }
}
