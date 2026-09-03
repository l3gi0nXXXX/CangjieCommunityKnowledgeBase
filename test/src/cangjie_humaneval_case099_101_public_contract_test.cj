package cangjie_community_knowledge_base_test

import std.fs.{Directory, File, Path, exists}
import std.process.launch
import std.unittest.*
import std.unittest.testmacro.*
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

private let H99101_ROOT = Path("cangjie_eval/cases/Cangjie-HumanEval")
private let H99_CONTRACT =
    "The source oracle first converts"
private let H101_CONTRACT =
    "The source oracle replaces commas with spaces and then applies Python's no-argument whitespace split."

private func h99101Read(path: Path): (Bool, String) {
    try { (true, String.fromUtf8(File.readFrom(path))) } catch (_: Exception) { (false, "") }
}

private func h99101Case(caseId: String, relative: String): String {
    let decoded = h99101Read(H99101_ROOT.join(caseId).join(relative))
    if (decoded[0]) { decoded[1] } else { "" }
}

private func h99101Run(caseId: String, name: String, solution: String): (Int64, String) {
    let caseRoot = H99101_ROOT.join(caseId)
    let root = Path("target/${name}")
    if (exists(root)) { _ = launch("/bin/rm", ["-rf", root.toString()]).wait() }
    Directory.create(root.join("src"), recursive: true)
    File.writeTo(root.join("cjpm.toml"), File.readFrom(caseRoot.join("tests/cjpm.executable.toml")))
    File.writeTo(root.join("src/eval_support.cj"), File.readFrom(caseRoot.join("starter/src/eval_support.cj")))
    File.writeTo(root.join("src/solution.cj"), solution.toArray())
    File.writeTo(root.join("src/test_main.cj"), File.readFrom(caseRoot.join("tests/TestMain.cj")))
    let command = "cd ${root.toString()} && cjpm clean && cjpm build -i && cjpm run > run.log 2>&1; code=$?; if /usr/bin/grep -q 'An exception has occurred' run.log; then exit 1; else exit $code; fi"
    let code = launch("/bin/zsh", ["-c", command]).wait()
    let log = h99101Read(root.join("run.log"))
    (code, if (log[0]) { log[1] } else { "invalid_response_encoding" })
}

private func h99101Hex(value: UInt8): String {
    if (value < UInt8(10)) { return "${value}" }
    if (value == UInt8(10)) { return "a" }
    if (value == UInt8(11)) { return "b" }
    if (value == UInt8(12)) { return "c" }
    if (value == UInt8(13)) { return "d" }
    if (value == UInt8(14)) { return "e" }
    "f"
}

private func h99101OtherCaseHash(): (Bool, Int64, String) {
    let decoded = h99101Read(Path("cangjie_eval/cangjie_humaneval_manifest.jsonl"))
    if (!decoded[0]) { return (false, 0, "") }
    let digest = SHA256()
    var count: Int64 = 0
    try {
        for (line in decoded[1].split("\n")) {
            if (line.trimAscii() == "") { continue }
            let row = JsonValue.fromStr(line).asObject()
            let caseId = row.get("caseId").getOrThrow().asString().getValue()
            if (caseId == "CJ-HUMANEVAL-099" || caseId == "CJ-HUMANEVAL-101") { continue }
            let caseHash = row.get("caseHash").getOrThrow().asString().getValue()
            digest.write("${caseId}|${caseHash}\n".toArray())
            count += 1
        }
    } catch (_: Exception) { return (false, count, "") }
    let out = StringBuilder()
    for (byte in digest.finish()) {
        out.append(h99101Hex(byte / UInt8(16)))
        out.append(h99101Hex(byte % UInt8(16)))
    }
    (true, count, "sha256:${out.toString()}")
}

@Test
public class CangjieHumanEvalCase099101PublicContractTest {
    @TestCase
    public func h99101UtPublicInterfacesAreComplete(): Unit {
        @Expect(h99101Case("CJ-HUMANEVAL-099", "starter/src/solution.cj").contains("import std.convert.Parsable"), true)
        let support101 = h99101Case("CJ-HUMANEVAL-101", "starter/src/eval_support.cj")
        @Expect(support101.contains("public func wordsStringSourceWhitespace(value: Rune): Bool"), true)
        @Expect(support101.contains("value.isWhiteSpace()"), true)
        @Expect(support101.contains("UInt32(28)"), true)
        @Expect(support101.contains("UInt32(31)"), true)
    }

    @TestCase
    public func h99101PosCorrectCandidatesPassPublicBase(): Unit {
        let solution99 = """
package cangjie_humaneval_099
import std.collection.*
import std.convert.Parsable
public func closest_integer(value: String): Int64 {
    let parsed = Float64.parse(value)
    if (parsed >= 0.0) { Int64(parsed + 0.5) } else { Int64(parsed - 0.5) }
}
"""
        let result99 = h99101Run("CJ-HUMANEVAL-099", "case099-public-contract-positive", solution99)
        @Expect(result99[0], 0)
        @Expect(result99[1].contains("CJ-HUMANEVAL-099 ok"), true)

        let solution101 = """
package cangjie_humaneval_101
import std.collection.*
public func words_string(s: String): ArrayList<String> {
    let result = ArrayList<String>()
    var token = StringBuilder()
    for (value in s.runes()) {
        if (value == r',' || wordsStringSourceWhitespace(value)) {
            if (token.size > 0) { result.add(token.toString()); token = StringBuilder() }
        } else { token.append(value) }
    }
    if (token.size > 0) { result.add(token.toString()) }
    result
}
"""
        let result101 = h99101Run("CJ-HUMANEVAL-101", "case101-public-contract-positive", solution101)
        @Expect(result101[0], 0)
        @Expect(result101[1].contains("CJ-HUMANEVAL-101 ok"), true)
    }

    @TestCase
    public func h99101NegKnownSemanticDriftIsRejected(): Unit {
        let bad99 = """
package cangjie_humaneval_099
import std.collection.*
import std.convert.Parsable
public func closest_integer(value: String): Int64 {
    let negative = value.startsWith("-")
    let unsigned = if (negative) { value.replace("-", "") } else { value }
    let parts = unsigned.split(".")
    var total = Int64.parse(parts[0])
    if (parts.size > 1 && parts[1] != "" && parts[1].startsWith("5")) { total += 1 }
    if (negative) { -total } else { total }
}
"""
        let result99 = h99101Run("CJ-HUMANEVAL-099", "case099-public-contract-negative", bad99)
        @Expect(result99[0] != 0, true)
        @Expect(result99[1].contains("CJ-HUMANEVAL-099_public_binary64_c006"), true)

        let bad101 = """
package cangjie_humaneval_101
import std.collection.*
public func words_string(s: String): ArrayList<String> {
    let result = ArrayList<String>()
    for (part in s.replace(",", " ").split(" ")) { if (part != "") { result.add(part) } }
    result
}
"""
        let result101 = h99101Run("CJ-HUMANEVAL-101", "case101-public-contract-negative", bad101)
        @Expect(result101[0] != 0, true)
        @Expect(result101[1].contains("CJ-HUMANEVAL-101_public_unicode_whitespace_c007"), true)
    }

    @TestCase
    public func h99101BndUnicodeBinary64AndInvalidUtf8FailClosed(): Unit {
        @Expect(h99101Case("CJ-HUMANEVAL-099", "tests/TestMain.cj").contains("9007199254740993"), true)
        @Expect(h99101Case("CJ-HUMANEVAL-101", "tests/TestMain.cj").contains("你好,\\n🙂 world"), true)
        let root = Path("target/h99101-invalid-utf8-中文🙂")
        if (!exists(root)) { Directory.create(root, recursive: true) }
        let invalid = root.join("invalid.bin")
        File.writeTo(invalid, [UInt8(255), UInt8(254)])
        @Expect(h99101Read(invalid)[0], false)
    }

    @TestCase
    public func h99101HistContractsAlignAndOtherCasesRemainStable(): Unit {
        for (caseId in ["CJ-HUMANEVAL-099", "CJ-HUMANEVAL-101"]) {
            let prompt = h99101Case(caseId, "prompt.md")
            let metadata = h99101Case(caseId, "metadata.json")
            let translation = h99101Case(caseId, "translation/line_translation.md")
            let contract = if (caseId == "CJ-HUMANEVAL-099") { H99_CONTRACT } else { H101_CONTRACT }
            @Expect(prompt.contains(contract), true)
            @Expect(metadata.contains(contract), true)
            @Expect(translation.contains("Public Static-Language Boundary"), true)
        }
        @Expect(h99101Case("CJ-HUMANEVAL-099", "metadata.json").contains("\"callCount\": 6"), true)
        @Expect(h99101Case("CJ-HUMANEVAL-101", "metadata.json").contains("\"callCount\": 7"), true)
        let history = h99101OtherCaseHash()
        @Expect(history[0], true)
        @Expect(history[1], 162)
        @Expect(history[2],
            "sha256:1ebbee55e844a0a5470899dbfcab4d17f2fbfe9ec4adcc40907d84d906d33e05")
    }
}
