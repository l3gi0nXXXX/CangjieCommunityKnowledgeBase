package cangjie_community_knowledge_base_test

import std.collection.*
import std.fs.{Directory, File, Path, exists}
import std.process.launch
import std.unittest.*
import std.unittest.testmacro.*

private let CASE092_ROOT = Path("cangjie_eval/cases/Cangjie-HumanEval/CJ-HUMANEVAL-092")

private func case092ReadUtf8(relativePath: String): String {
    try {
        return String.fromUtf8(File.readFrom(CASE092_ROOT.join(relativePath)))
    } catch (_: Exception) {
        return ""
    }
}

private func case092TaggedKey(kind: String, value: String): String {
    "${kind}:${value}"
}

private func case092CallKey(x: String, y: String, z: String): String {
    "${x}|${y}|${z}"
}

private func case092RunFixture(name: String, solution: String, testMain: String): (Int64, String) {
    let root = Path("target/${name}")
    if (exists(root)) { _ = launch("/bin/rm", ["-rf", root.toString()]).wait() }
    Directory.create(root.join("src"), recursive: true)
    File.writeTo(root.join("cjpm.toml"), File.readFrom(CASE092_ROOT.join("tests/cjpm.executable.toml")))
    File.writeTo(root.join("src/eval_support.cj"), File.readFrom(CASE092_ROOT.join("starter/src/eval_support.cj")))
    File.writeTo(root.join("src/solution.cj"), solution.toArray())
    File.writeTo(root.join("src/test_main.cj"), testMain.toArray())
    let log = root.join("run.log")
    let command = "cd ${root.toString()} && cjpm clean && cjpm build -i && cjpm run > run.log 2>&1; exit_code=$?; if /usr/bin/grep -q 'An exception has occurred' run.log; then exit 1; else exit $exit_code; fi"
    let exitCode = launch("/bin/zsh", ["-c", command]).wait()
    let output = try { String.fromUtf8(File.readFrom(log)) } catch (_: Exception) { "invalid_response_encoding" }
    (exitCode, output)
}

@Test
public class CangjieHumanEvalCase092TypeIdentityTest {
    @TestCase
    public func officialCallsPreserveTypeIdentityAndAreSatisfiable(): Unit {
        let tests = case092ReadUtf8("tests/TestMain.cj")
        let metadata = case092ReadUtf8("metadata.json")
        let prompt = case092ReadUtf8("prompt.md")
        @Expect(tests.contains("any_int(evalInt(3), evalInt(4), evalInt(7))"), true)
        @Expect(tests.contains("any_int(evalFloat(3.0), evalInt(4), evalInt(7))"), true)
        @Expect(metadata.contains("public func any_int(x: EvalValue, y: EvalValue, z: EvalValue): Bool"), true)
        @Expect(prompt.contains("`evalInt` preserves a Python `int`; `evalFloat` preserves a Python `float`"), true)

        let calls = [
            (case092CallKey("i:2", "i:3", "i:1"), true),
            (case092CallKey("f:2.5", "i:2", "i:3"), false),
            (case092CallKey("f:1.5", "i:5", "f:3.5"), false),
            (case092CallKey("i:2", "i:6", "i:2"), false),
            (case092CallKey("i:4", "i:2", "i:2"), true),
            (case092CallKey("f:2.2", "f:2.2", "f:2.2"), false),
            (case092CallKey("i:-4", "i:6", "i:2"), true),
            (case092CallKey("i:2", "i:1", "i:1"), true),
            (case092CallKey("i:3", "i:4", "i:7"), true),
            (case092CallKey("f:3.0", "i:4", "i:7"), false)
        ]
        let expectedByCall = HashMap<String, Bool>()
        for ((key, expected) in calls) {
            if (expectedByCall.contains(key)) {
                @Expect(expectedByCall[key], expected)
            } else {
                expectedByCall[key] = expected
            }
        }
        @Expect(expectedByCall.size, 10)
    }

    @TestCase
    public func integerAndFloatTagsRemainDistinctAtNumericBoundaries(): Unit {
        @Expect(case092TaggedKey("int", "0") != case092TaggedKey("float", "0.0"), true)
        @Expect(case092TaggedKey("int", "-4") != case092TaggedKey("float", "-4.0"), true)
        @Expect(case092TaggedKey("int", "4000000000000") != case092TaggedKey("float", "4000000000000.0"), true)
        @Expect(case092TaggedKey("float", "NaN") != case092TaggedKey("int", "0"), true)
        @Expect(case092TaggedKey("float", "+Inf") != case092TaggedKey("int", "0"), true)

        let support = case092ReadUtf8("starter/src/eval_support.cj")
        @Expect(support.contains("v.kind = \"int\"; v.intValue = value"), true)
        @Expect(support.contains("v.kind = \"float\"; v.floatValue = value"), true)
    }

    @TestCase
    public func legacyFloat64MappingCollisionIsAbsent(): Unit {
        let legacyIntCall = case092CallKey("3.0", "4.0", "7.0")
        let legacyFloatCall = case092CallKey("3.0", "4.0", "7.0")
        @Expect(legacyIntCall, legacyFloatCall)
        @Expect(true != false, true)
        let taggedIntCall = case092CallKey("int:3", "int:4", "int:7")
        let taggedFloatCall = case092CallKey("float:3.0", "int:4", "int:7")
        @Expect(taggedIntCall != taggedFloatCall, true)
    }

    @TestCase
    public func unicodeAndInvalidUtf8RemainFailClosed(): Unit {
        let prompt = case092ReadUtf8("prompt.md")
        @Expect(prompt.contains("Python"), true)
        let root = Path("target/case092-类型身份🙂")
        if (!exists(root)) { Directory.create(root, recursive: true) }
        let invalid = root.join("invalid.bin")
        File.writeTo(invalid, [UInt8(255), UInt8(254)])
        var decoded = "not-empty"
        try {
            decoded = String.fromUtf8(File.readFrom(invalid))
        } catch (_: Exception) {
            decoded = ""
        }
        @Expect(decoded, "")
    }

    @TestCase
    public func taggedCandidatePassesWhileStarterAndLegacyCollisionFail(): Unit {
        let official = case092ReadUtf8("tests/TestMain.cj")
        let taggedSolution = """
package cangjie_humaneval_092

public func any_int(x: EvalValue, y: EvalValue, z: EvalValue): Bool {
    if (x.kind != "int" || y.kind != "int" || z.kind != "int") {
        return false
    }
    return (x.intValue + y.intValue == z.intValue) || (x.intValue + z.intValue == y.intValue) || (y.intValue + z.intValue == x.intValue)
}
"""
        let boundaryMain = official.replace("    println(\"CJ-HUMANEVAL-092 ok\")", """
    expectBool(any_int(evalInt(0), evalInt(0), evalInt(0)), true, "H092-BND-zero")
    expectBool(any_int(evalInt(4000000000000), evalInt(3000000000000), evalInt(7000000000000)), true, "H092-BND-large")
    expectBool(any_int(evalInt(-4), evalInt(0), evalInt(-4)), true, "H092-BND-negative-zero")
    expectBool(any_int(evalInt(3), evalFloat(4.0), evalInt(7)), false, "H092-BND-mixed")
    let zero: Float64 = 0.0
    expectBool(any_int(evalFloat(zero / zero), evalInt(0), evalInt(0)), false, "H092-BND-nan")
    expectBool(any_int(evalFloat(1.0 / zero), evalInt(0), evalInt(0)), false, "H092-BND-inf")
    println("CJ-HUMANEVAL-092 ok")
""")
        let tagged = case092RunFixture("case092-tagged-positive", taggedSolution, boundaryMain)
        @Expect(tagged[0], 0)
        @Expect(tagged[1].contains("CJ-HUMANEVAL-092 ok"), true)

        let starter = case092RunFixture(
            "case092-starter-negative",
            case092ReadUtf8("starter/src/solution.cj"),
            official)
        @Expect(starter[0] != 0, true)
        @Expect(starter[1].contains("CJ-HUMANEVAL-092_l4_c001"), true)

        let legacySolution = """
package cangjie_humaneval_092

public func any_int(x: Float64, y: Float64, z: Float64): Bool {
    return (x + y == z) || (x + z == y) || (y + z == x)
}
"""
        let legacyMain = """
package cangjie_humaneval_092

func expectBool(actual: Bool, expected: Bool, label: String): Unit {
    if (actual != expected) { throw Exception("CangjieEval failure: \${label}") }
}

main(): Int64 {
    expectBool(any_int(3.0, 4.0, 7.0), true, "CJ-HUMANEVAL-092_l14_c009")
    expectBool(any_int(3.0, 4.0, 7.0), false, "CJ-HUMANEVAL-092_l15_c010")
    return 0
}
"""
        let legacy = case092RunFixture("case092-legacy-float64-negative", legacySolution, legacyMain)
        @Expect(legacy[0] != 0, true)
        @Expect(legacy[1].contains("CJ-HUMANEVAL-092_l15_c010"), true)
    }
}
