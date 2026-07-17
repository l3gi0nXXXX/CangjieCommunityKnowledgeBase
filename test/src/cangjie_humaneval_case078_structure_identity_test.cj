package cangjie_community_knowledge_base_test

import std.fs.{Directory, File, Path, exists}
import std.process.launch
import std.unittest.*
import std.unittest.testmacro.*

private let CASE078_ROOT = Path("cangjie_eval/cases/Cangjie-HumanEval/CJ-HUMANEVAL-078")

private func case078ReadUtf8(relativePath: String): String {
    try { String.fromUtf8(File.readFrom(CASE078_ROOT.join(relativePath))) } catch (_: Exception) { "" }
}

private func case078RunFixture(name: String, solution: String, testMain: String): (Int64, String) {
    let root = Path("target/${name}")
    if (exists(root)) { _ = launch("/bin/rm", ["-rf", root.toString()]).wait() }
    Directory.create(root.join("src"), recursive: true)
    File.writeTo(root.join("cjpm.toml"), File.readFrom(CASE078_ROOT.join("tests/cjpm.executable.toml")))
    File.writeTo(root.join("src/eval_support.cj"), File.readFrom(CASE078_ROOT.join("starter/src/eval_support.cj")))
    File.writeTo(root.join("src/solution.cj"), solution.toArray())
    File.writeTo(root.join("src/test_main.cj"), testMain.toArray())
    let log = root.join("run.log")
    let command = "cd ${root.toString()} && cjpm clean && cjpm build -i && cjpm run > run.log 2>&1; exit_code=$?; if /usr/bin/grep -q 'An exception has occurred' run.log; then exit 1; else exit $exit_code; fi"
    let exitCode = launch("/bin/zsh", ["-c", command]).wait()
    let output = try { String.fromUtf8(File.readFrom(log)) } catch (_: Exception) { "invalid_response_encoding" }
    (exitCode, output)
}

private func case078CorrectSolution(): String {
    """
package cangjie_humaneval_078

public func hex_key(num: EvalValue): Int64 {
    if (num.kind == "list") {
        if (num.intValue != 0 || num.floatValue != 0.0 || num.stringValue != "" || num.boolValue) { throw Exception("invalid non-empty list encoding") }
        return 0
    }
    if (num.kind != "string") { throw Exception("invalid hex_key input kind") }
    var count: Int64 = 0
    for (digit in num.stringValue.runes()) {
        if (digit == r'2' || digit == r'3' || digit == r'5' || digit == r'7' || digit == r'B' || digit == r'D') { count += 1 }
    }
    count
}
"""
}

@Test
public class CangjieHumanEvalCase078StructureIdentityTest {
    @TestCase
    public func h078Ut01OfficialCallsUseDistinctTags(): Unit {
        let tests = case078ReadUtf8("tests/TestMain.cj")
        let support = case078ReadUtf8("starter/src/eval_support.cj")
        @Expect(tests.contains("hex_key(evalString(\"AB\"))"), true)
        @Expect(tests.contains("hex_key(evalEmptyList())"), true)
        @Expect(tests.contains("hex_key(\"\")"), false)
        @Expect(support.contains("v.kind = \"string\""), true)
        @Expect(support.contains("v.kind = \"list\""), true)
    }

    @TestCase
    public func h078Bnd01EmptyUnicodeInvalidUtf8AndIllegalKind(): Unit {
        let official = case078ReadUtf8("tests/TestMain.cj")
        let boundary = official.replace("    println(\"CJ-HUMANEVAL-078 ok\")", """
    expectInt64(hex_key(evalString("")), 0, "H078-BND-empty-string")
    expectInt64(hex_key(evalString("中文🙂")), 0, "H078-BND-unicode")
    println("CJ-HUMANEVAL-078 ok")
""")
        let passed = case078RunFixture("case078-boundary-positive", case078CorrectSolution(), boundary)
        @Expect(passed[0], 0)
        @Expect(passed[1].contains("CJ-HUMANEVAL-078 ok"), true)

        let illegalMain = """
package cangjie_humaneval_078
main(): Int64 { let invalid = EvalValue(); invalid.kind = "非法🙂"; _ = hex_key(invalid); return 0 }
"""
        let illegal = case078RunFixture("case078-illegal-kind-negative", case078CorrectSolution(), illegalMain)
        @Expect(illegal[0] != 0, true)

        let smuggledListMain = """
package cangjie_humaneval_078
main(): Int64 { let invalid = evalEmptyList(); invalid.stringValue = "not-empty"; _ = hex_key(invalid); return 0 }
"""
        let smuggled = case078RunFixture("case078-smuggled-list-negative", case078CorrectSolution(), smuggledListMain)
        @Expect(smuggled[0] != 0, true)

        let invalidPath = Path("target/case078-invalid-utf8.bin")
        File.writeTo(invalidPath, [UInt8(255), UInt8(254)])
        var decoded = "unexpected"
        try { decoded = String.fromUtf8(File.readFrom(invalidPath)) } catch (_: Exception) { decoded = "invalid_response_encoding" }
        @Expect(decoded, "invalid_response_encoding")
    }

    @TestCase
    public func h078Pos01CorrectCandidatePassesOfficialVerifier(): Unit {
        let result = case078RunFixture("case078-official-positive", case078CorrectSolution(), case078ReadUtf8("tests/TestMain.cj"))
        @Expect(result[0], 0)
        @Expect(result[1].contains("CJ-HUMANEVAL-078 ok"), true)
    }

    @TestCase
    public func h078Neg01StarterAndLegacyStringReplacementFail(): Unit {
        let official = case078ReadUtf8("tests/TestMain.cj")
        let starter = case078RunFixture("case078-starter-negative", case078ReadUtf8("starter/src/solution.cj"), official)
        @Expect(starter[0] != 0, true)
        @Expect(starter[1].contains("CJ-HUMANEVAL-078_l4_c001"), true)

        let legacy = """
package cangjie_humaneval_078
public func hex_key(num: String): Int64 { return 0 }
"""
        let replacement = case078RunFixture("case078-empty-string-replacement-negative", legacy, official)
        @Expect(replacement[0] != 0, true)
    }

    @TestCase
    public func h078Manifest01ContractFilesAreSynchronized(): Unit {
        let signature = "public func hex_key(num: EvalValue): Int64"
        @Expect(case078ReadUtf8("metadata.json").contains(signature), true)
        @Expect(case078ReadUtf8("prompt.md").contains(signature), true)
        @Expect(case078ReadUtf8("starter/src/solution.cj").contains(signature), true)
        @Expect(case078ReadUtf8("translation/line_translation.md").contains("evalEmptyList()"), true)
    }
}
