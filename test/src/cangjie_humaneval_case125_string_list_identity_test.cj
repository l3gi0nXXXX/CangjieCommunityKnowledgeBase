package cangjie_community_knowledge_base_test

import std.fs.{Directory, File, Path, exists}
import std.process.launch
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.json.*

private let CASE125_ROOT = Path("cangjie_eval/cases/Cangjie-HumanEval/CJ-HUMANEVAL-125")

private func case125ReadUtf8(relativePath: String): String {
    try {
        return String.fromUtf8(File.readFrom(CASE125_ROOT.join(relativePath)))
    } catch (_: Exception) {
        return ""
    }
}

private func case125RunFixture(name: String, solution: String, testMain: String): (Int64, String) {
    let root = Path("target/${name}")
    if (exists(root)) { _ = launch("/bin/rm", ["-rf", root.toString()]).wait() }
    Directory.create(root.join("src"), recursive: true)
    File.writeTo(root.join("cjpm.toml"), File.readFrom(CASE125_ROOT.join("tests/cjpm.executable.toml")))
    File.writeTo(root.join("src/eval_support.cj"), File.readFrom(CASE125_ROOT.join("starter/src/eval_support.cj")))
    File.writeTo(root.join("src/solution.cj"), solution.toArray())
    File.writeTo(root.join("src/test_main.cj"), testMain.toArray())
    let log = root.join("run.log")
    let command = "cd ${root.toString()} && cjpm clean && cjpm build -i && cjpm run > run.log 2>&1; exit_code=$?; if /usr/bin/grep -q 'An exception has occurred' run.log; then exit 1; else exit $exit_code; fi"
    let exitCode = launch("/bin/zsh", ["-c", command]).wait()
    let output = try { String.fromUtf8(File.readFrom(log)) } catch (_: Exception) { "invalid_response_encoding" }
    (exitCode, output)
}

@Test
public class CangjieHumanEvalCase125StringListIdentityTest {
    @TestCase
    public func officialListCallsUseStructuralPayload(): Unit {
        let tests = case125ReadUtf8("tests/TestMain.cj")
        let support = case125ReadUtf8("starter/src/eval_support.cj")
        @Expect(tests.contains("evalStringList([\"Hello\", \"world!\"])") , true)
        @Expect(tests.contains("evalString(\"[\\\"Hello\\\", "), false)
        @Expect(tests.contains("expectStringList(actual.stringListValue, expected.stringListValue, label)"), true)
        @Expect(tests.contains("unsupported EvalValue kind"), true)
        @Expect(support.contains("public var stringListValue: ArrayList<String>"), true)
        @Expect(support.contains("public func evalStringList(values: Array<String>): EvalValue"), true)
        @Expect(support.contains("public func evalInt(value: Int64): EvalValue"), true)
        @Expect(support.contains("evalInt64"), false)
        @Expect(support.contains("v.kind = \"string_list\""), true)
    }

    @TestCase
    public func metadataAndPromptDeclareExactUnionContract(): Unit {
        let metadata = case125ReadUtf8("metadata.json")
        let prompt = case125ReadUtf8("prompt.md")
        let translation = case125ReadUtf8("translation/line_translation.md")
        let readme = case125ReadUtf8("../README.md")
        @Expect(metadata.contains("list[str] | int"), true)
        @Expect(prompt.contains("evalStringList(Array<String>)"), true)
        @Expect(prompt.contains("evalInt(Int64)"), true)
        @Expect(prompt.contains("`evalInt64` does not exist"), true)
        @Expect(metadata.contains("evalInt(Int64) helper"), true)
        @Expect(translation.contains("evalInt(Int64)"), true)
        @Expect(readme.contains("integer results use `evalInt(Int64)`"), true)
        @Expect(translation.contains("kind, size, order, and every String element exactly"), true)
        @Expect(readme.contains("serialized list text is rejected"), true)
        var malformedRejected = false
        try { _ = JsonValue.fromStr("{\"id\":") } catch (_: Exception) { malformedRejected = true }
        @Expect(malformedRejected, true)
    }

    @TestCase
    public func unicodeAndInvalidUtf8RemainFailClosed(): Unit {
        let root = Path("target/case125-字符串列表🙂")
        if (!exists(root)) { Directory.create(root, recursive: true) }
        let invalid = root.join("invalid.bin")
        File.writeTo(invalid, [UInt8(255), UInt8(254)])
        var decoded = "not-empty"
        try { decoded = String.fromUtf8(File.readFrom(invalid)) } catch (_: Exception) { decoded = "" }
        @Expect(decoded, "")
        @Expect("中文🙂".toRuneArray().size, 3)
    }

    @TestCase
    public func correctCandidatePassesOfficialAndBoundaryCases(): Unit {
        let official = case125ReadUtf8("tests/TestMain.cj")
        let boundary = official.replace("    println(\"CJ-HUMANEVAL-125 ok\")", """
    expectEvalValue(split_words(" "), evalStringList([]), "H125-BND-empty-list")
    expectEvalValue(split_words("中文 🙂"), evalStringList(["中文", "🙂"]), "H125-BND-unicode-emoji")
    expectEvalValue(split_words("abcdefghijklmnopqrstuvwxyz abcdefghijklmnopqrstuvwxyz"), evalStringList(["abcdefghijklmnopqrstuvwxyz", "abcdefghijklmnopqrstuvwxyz"]), "H125-BND-long")
    println("CJ-HUMANEVAL-125 ok")
""")
        let solution = """
package cangjie_humaneval_125

import std.collection.*

private func nonEmptyParts(parts: Array<String>): Array<String> {
    let out = ArrayList<String>()
    for (part in parts) { if (part != "") { out.add(part) } }
    out.toArray()
}

public func split_words(txt: String): EvalValue {
    if (txt.contains(" ")) {
        return evalStringList(nonEmptyParts(txt.split(" ")))
    }
    if (txt.contains(",")) {
        return evalStringList(nonEmptyParts(txt.replace(",", " ").split(" ")))
    }
    var count: Int64 = 0
    for (value in txt.runes()) {
        if (value == r'b' || value == r'd' || value == r'f' || value == r'h' || value == r'j' || value == r'l' || value == r'n' || value == r'p' || value == r'r' || value == r't' || value == r'v' || value == r'x' || value == r'z') { count += 1 }
    }
    evalInt(count)
}
"""
        let result = case125RunFixture("case125-string-list-positive", solution, boundary)
        @Expect(result[0], 0)
        @Expect(result[1].contains("CJ-HUMANEVAL-125 ok"), true)
    }

    @TestCase
    public func starterForgeryAndMalformedPayloadsAreRejected(): Unit {
        let official = case125ReadUtf8("tests/TestMain.cj")
        let starter = case125RunFixture("case125-starter-negative", case125ReadUtf8("starter/src/solution.cj"), official)
        @Expect(starter[0] != 0, true)
        @Expect(starter[1].contains("CJ-HUMANEVAL-125_l3_c001"), true)

        let forgedSolution = """
package cangjie_humaneval_125
public func split_words(txt: String): EvalValue { evalString("[\\\"Hello\\\", \\\"world!\\\"]") }
"""
        let forged = case125RunFixture("case125-serialized-string-negative", forgedSolution, official)
        @Expect(forged[0] != 0, true)
        @Expect(forged[1].contains("expected kind string_list, actual kind string"), true)

        let prefix = official.split("main(): Int64 {")[0]
        let malformedMain = prefix + """
func expectRejected(actual: EvalValue, expected: EvalValue, label: String): Unit {
    var rejected = false
    try { expectEvalValue(actual, expected, label) } catch (_: Exception) { rejected = true }
    if (!rejected) { cjeFail(label, "malformed value unexpectedly accepted") }
}

main(): Int64 {
    expectEvalValue(evalInt(9223372036854775807), evalInt(9223372036854775807), "H125-BND-int-max")
    expectEvalValue(evalInt(-9223372036854775807 - 1), evalInt(-9223372036854775807 - 1), "H125-BND-int-min")
    expectEvalValue(evalStringList([]), evalStringList([]), "H125-BND-empty-list")
    expectEvalValue(evalStringList(["中文", "🙂"]), evalStringList(["中文", "🙂"]), "H125-BND-unicode")
    expectRejected(evalStringList(["world!", "Hello"]), evalStringList(["Hello", "world!"]), "H125-NEG-order")
    expectRejected(evalStringList(["Hello"]), evalStringList(["Hello", "world!"]), "H125-NEG-fewer")
    expectRejected(evalStringList(["Hello", "world!", "extra"]), evalStringList(["Hello", "world!"]), "H125-NEG-more")
    expectRejected(evalString("[\\\"Hello\\\", \\\"world!\\\"]"), evalStringList(["Hello", "world!"]), "H125-NEG-same-text-different-structure")
    let invalidKind = evalStringList(["Hello", "world!"])
    invalidKind.kind = "invalid"
    expectRejected(invalidKind, evalStringList(["Hello", "world!"]), "H125-NEG-invalid-kind")
    let pollutedList = evalStringList(["Hello", "world!"])
    pollutedList.stringValue = "[\\\"Hello\\\", \\\"world!\\\"]"
    expectRejected(pollutedList, evalStringList(["Hello", "world!"]), "H125-NEG-polluted-list")
    let listWithInt = evalStringList(["Hello", "world!"])
    listWithInt.intValue = 1
    expectRejected(listWithInt, evalStringList(["Hello", "world!"]), "H125-NEG-list-int-smuggling")
    let listWithBool = evalStringList(["Hello", "world!"])
    listWithBool.boolValue = true
    expectRejected(listWithBool, evalStringList(["Hello", "world!"]), "H125-NEG-list-bool-smuggling")
    let zero: Float64 = 0.0
    let listWithNaN = evalStringList(["Hello", "world!"])
    listWithNaN.floatValue = zero / zero
    expectRejected(listWithNaN, evalStringList(["Hello", "world!"]), "H125-NEG-list-nan-smuggling")
    let pollutedInt = evalInt(3)
    pollutedInt.stringListValue.add("unexpected")
    expectRejected(pollutedInt, evalInt(3), "H125-NEG-polluted-int")
    let intWithString = evalInt(3)
    intWithString.stringValue = "3"
    expectRejected(intWithString, evalInt(3), "H125-NEG-int-string-smuggling")
    let intWithBool = evalInt(3)
    intWithBool.boolValue = true
    expectRejected(intWithBool, evalInt(3), "H125-NEG-int-bool-smuggling")
    let intWithNaN = evalInt(3)
    intWithNaN.floatValue = zero / zero
    expectRejected(intWithNaN, evalInt(3), "H125-NEG-int-nan-smuggling")
    println("H125 malformed payloads rejected")
    return 0
}
"""
        let malformed = case125RunFixture(
            "case125-malformed-payload-negative",
            case125ReadUtf8("starter/src/solution.cj"),
            malformedMain)
        @Expect(malformed[0], 0)
        @Expect(malformed[1].contains("H125 malformed payloads rejected"), true)
    }
}
