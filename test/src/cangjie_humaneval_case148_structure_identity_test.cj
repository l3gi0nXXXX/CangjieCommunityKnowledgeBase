package cangjie_community_knowledge_base_test

import std.fs.{Directory, File, Path, exists}
import std.process.launch
import std.unittest.*
import std.unittest.testmacro.*

private let CASE148_ROOT = Path("cangjie_eval/cases/Cangjie-HumanEval/CJ-HUMANEVAL-148")

private func case148ReadUtf8(relativePath: String): String {
    try { String.fromUtf8(File.readFrom(CASE148_ROOT.join(relativePath))) } catch (_: Exception) { "" }
}

private func case148RunFixture(name: String, solution: String, testMain: String): (Int64, String) {
    let root = Path("target/${name}")
    if (exists(root)) { _ = launch("/bin/rm", ["-rf", root.toString()]).wait() }
    Directory.create(root.join("src"), recursive: true)
    File.writeTo(root.join("cjpm.toml"), File.readFrom(CASE148_ROOT.join("tests/cjpm.executable.toml")))
    File.writeTo(root.join("src/eval_support.cj"), File.readFrom(CASE148_ROOT.join("starter/src/eval_support.cj")))
    File.writeTo(root.join("src/solution.cj"), solution.toArray())
    File.writeTo(root.join("src/test_main.cj"), testMain.toArray())
    let log = root.join("run.log")
    let command = "cd ${root.toString()} && cjpm clean && cjpm build -i && cjpm run > run.log 2>&1; exit_code=$?; if /usr/bin/grep -q 'An exception has occurred' run.log; then exit 1; else exit $exit_code; fi"
    let exitCode = launch("/bin/zsh", ["-c", command]).wait()
    let output = try { String.fromUtf8(File.readFrom(log)) } catch (_: Exception) { "invalid_response_encoding" }
    (exitCode, output)
}

private func case148CorrectSolution(): String {
    """
package cangjie_humaneval_148

import std.collection.*

public func bf(planet1: String, planet2: String): EvalValue {
    let planets = ["Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"]
    var first: Int64 = -1
    var second: Int64 = -1
    for (i in 0..planets.size) {
        if (planets[i] == planet1) { first = i }
        if (planets[i] == planet2) { second = i }
    }
    if (first < 0 || second < 0 || first == second) { return evalStringTuple([]) }
    let low = if (first < second) { first } else { second }
    let high = if (first < second) { second } else { first }
    let between = ArrayList<String>()
    for (i in (low + 1)..high) { between.add(planets[i]) }
    let out = EvalValue()
    out.kind = "tuple"
    out.stringValues = between
    out
}
"""
}

@Test
public class CangjieHumanEvalCase148StructureIdentityTest {
    @TestCase
    public func h148Ut01TupleTagAndOrderedPayloadAreExplicit(): Unit {
        let support = case148ReadUtf8("starter/src/eval_support.cj")
        let tests = case148ReadUtf8("tests/TestMain.cj")
        @Expect(support.contains("v.kind = \"tuple\""), true)
        @Expect(support.contains("v.kind = \"list\""), true)
        @Expect(support.contains("stringValues.add(value)"), true)
        @Expect(tests.contains("actual.kind != \"tuple\""), true)
        @Expect(tests.contains("unexpected scalar payload for string tuple"), true)
        @Expect(tests.contains("actual.stringValues[i]"), true)
    }

    @TestCase
    public func h148Bnd01EmptySingleMultipleUnicodeInvalidUtf8AndIllegalKind(): Unit {
        let official = case148ReadUtf8("tests/TestMain.cj")
        let boundary = official.replace("    println(\"CJ-HUMANEVAL-148 ok\")", """
    expectStringTuple(evalStringTuple([]), [], "H148-BND-empty")
    expectStringTuple(evalStringTuple(["Venus"]), ["Venus"], "H148-BND-single")
    expectStringTuple(evalStringTuple(["中文", "🙂"]), ["中文", "🙂"], "H148-BND-unicode-multiple")
    println("CJ-HUMANEVAL-148 ok")
""")
        let passed = case148RunFixture("case148-boundary-positive", case148CorrectSolution(), boundary)
        @Expect(passed[0], 0)
        @Expect(passed[1].contains("CJ-HUMANEVAL-148 ok"), true)

        let invalidKind = """
package cangjie_humaneval_148
public func bf(planet1: String, planet2: String): EvalValue { let out = EvalValue(); out.kind = "非法🙂"; return out }
"""
        let illegal = case148RunFixture("case148-illegal-kind-negative", invalidKind, official)
        @Expect(illegal[0] != 0, true)
        @Expect(illegal[1].contains("expected kind tuple"), true)

        let invalidPath = Path("target/case148-invalid-utf8.bin")
        File.writeTo(invalidPath, [UInt8(255), UInt8(254)])
        var decoded = "unexpected"
        try { decoded = String.fromUtf8(File.readFrom(invalidPath)) } catch (_: Exception) { decoded = "invalid_response_encoding" }
        @Expect(decoded, "invalid_response_encoding")
    }

    @TestCase
    public func h148Pos01CorrectCandidatePassesOfficialVerifier(): Unit {
        let result = case148RunFixture("case148-official-positive", case148CorrectSolution(), case148ReadUtf8("tests/TestMain.cj"))
        @Expect(result[0], 0)
        @Expect(result[1].contains("CJ-HUMANEVAL-148 ok"), true)
    }

    @TestCase
    public func h148Neg01StarterListStringAndWrongOrderFail(): Unit {
        let official = case148ReadUtf8("tests/TestMain.cj")
        let starter = case148RunFixture("case148-starter-negative", case148ReadUtf8("starter/src/solution.cj"), official)
        @Expect(starter[0] != 0, true)

        let listForgery = """
package cangjie_humaneval_148
public func bf(planet1: String, planet2: String): EvalValue { return evalStringList(["Saturn", "Uranus"]) }
"""
        let listResult = case148RunFixture("case148-list-tag-negative", listForgery, official)
        @Expect(listResult[0] != 0, true)
        @Expect(listResult[1].contains("expected kind tuple, actual kind list"), true)

        let legacyArrayList = """
package cangjie_humaneval_148
import std.collection.*
public func bf(planet1: String, planet2: String): ArrayList<String> { return ArrayList<String>() }
"""
        let legacyResult = case148RunFixture("case148-legacy-arraylist-negative", legacyArrayList, official)
        @Expect(legacyResult[0] != 0, true)

        let stringForgery = """
package cangjie_humaneval_148
public func bf(planet1: String, planet2: String): EvalValue { return evalString("Saturn,Uranus") }
"""
        let stringResult = case148RunFixture("case148-string-forgery-negative", stringForgery, official)
        @Expect(stringResult[0] != 0, true)

        let wrongOrder = """
package cangjie_humaneval_148
public func bf(planet1: String, planet2: String): EvalValue { return evalStringTuple(["Uranus", "Saturn"]) }
"""
        let orderResult = case148RunFixture("case148-wrong-order-negative", wrongOrder, official)
        @Expect(orderResult[0] != 0, true)
        @Expect(orderResult[1].contains("CJ-HUMANEVAL-148_l4_c001[0]"), true)

        let scalarSmuggling = """
package cangjie_humaneval_148
public func bf(planet1: String, planet2: String): EvalValue { let out = evalStringTuple(["Saturn", "Uranus"]); out.intValue = 1; return out }
"""
        let scalarResult = case148RunFixture("case148-scalar-smuggling-negative", scalarSmuggling, official)
        @Expect(scalarResult[0] != 0, true)
        @Expect(scalarResult[1].contains("unexpected scalar payload"), true)

        let nanSmuggling = """
package cangjie_humaneval_148
public func bf(planet1: String, planet2: String): EvalValue { let out = evalStringTuple(["Saturn", "Uranus"]); let zero: Float64 = 0.0; out.floatValue = zero / zero; return out }
"""
        let nanResult = case148RunFixture("case148-nan-smuggling-negative", nanSmuggling, official)
        @Expect(nanResult[0] != 0, true)
        @Expect(nanResult[1].contains("unexpected scalar payload"), true)
    }

    @TestCase
    public func h148Manifest01ContractFilesAreSynchronized(): Unit {
        let signature = "public func bf(planet1: String, planet2: String): EvalValue"
        @Expect(case148ReadUtf8("metadata.json").contains(signature), true)
        @Expect(case148ReadUtf8("prompt.md").contains(signature), true)
        @Expect(case148ReadUtf8("starter/src/solution.cj").contains(signature), true)
        @Expect(case148ReadUtf8("translation/line_translation.md").contains("kind == \"tuple\""), true)
    }
}
