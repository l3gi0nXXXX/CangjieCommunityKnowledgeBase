package cangjie_community_knowledge_base_test

import std.fs.{File, Path}
import std.unittest.*
import std.unittest.testmacro.*
import std.unicode.*
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

private let HC_DATASET_ROOT = Path("cangjie_eval/cases/Cangjie-HumanEval")
private let HC_141_UNICODE_CONTRACT =
    "The source oracle uses Python str.isalpha(): the first Unicode code point before the dot must be alphabetic; this is not limited to ASCII or the Latin alphabet."
private let HC_151_BOOL_CONTRACT =
    "Python bool is an int subtype: evalBool(true) projects to integer 1 and contributes 1, while evalBool(false) projects to integer 0 and contributes 0."

private func hcReadUtf8(path: Path): (Bool, String) {
    try {
        return (true, String.fromUtf8(File.readFrom(path)))
    } catch (_: Exception) {
        return (false, "")
    }
}

private func hcCaseText(caseId: String, relativePath: String): String {
    let result = hcReadUtf8(HC_DATASET_ROOT.join(caseId).join(relativePath))
    if (!result[0]) { return "" }
    result[1]
}

private func hc151ProjectedSquare(kind: String, intValue: Int64,
    boolValue: Bool): Int64 {
    var value: Int64 = 0
    if (kind == "int") {
        value = intValue
    } else if (kind == "bool") {
        value = if (boolValue) { 1 } else { 0 }
    } else {
        return 0
    }
    if (value > 0 && value % 2 != 0) { value * value } else { 0 }
}

private func hcContractAligned(caseId: String, contract: String,
    requiredBaseAssertion: String, requiredPlusEvidence: String): Bool {
    let prompt = hcCaseText(caseId, "prompt.md")
    let metadata = hcCaseText(caseId, "metadata.json")
    let starter = hcCaseText(caseId, "starter/src/solution.cj")
    let base = hcCaseText(caseId, "tests/TestMain.cj")
    let plus = hcCaseText(caseId, "tests-plus/TestMain.cj")
    let translation = hcCaseText(caseId, "translation/line_translation.md")
    prompt.contains(contract) && metadata.contains(contract) &&
        starter.contains(contract) && translation.contains(contract) &&
        base.contains(requiredBaseAssertion) && plus.contains(requiredPlusEvidence)
}

private func hcHex(value: UInt8): String {
    if (value < UInt8(10)) { return "${value}" }
    if (value == UInt8(10)) { return "a" }
    if (value == UInt8(11)) { return "b" }
    if (value == UInt8(12)) { return "c" }
    if (value == UInt8(13)) { return "d" }
    if (value == UInt8(14)) { return "e" }
    "f"
}

private func hcOtherCaseHash(): (Bool, Int64, String) {
    let decoded = hcReadUtf8(Path("cangjie_eval/cangjie_humaneval_manifest.jsonl"))
    if (!decoded[0]) { return (false, 0, "") }
    let digest = SHA256()
    var count: Int64 = 0
    try {
        for (line in decoded[1].split("\n")) {
            if (line.trimAscii() == "") { continue }
            let row = JsonValue.fromStr(line).asObject()
            let caseId = row.get("caseId").getOrThrow().asString().getValue()
            if (caseId == "CJ-HUMANEVAL-141" || caseId == "CJ-HUMANEVAL-151") {
                continue
            }
            let caseHash = row.get("caseHash").getOrThrow().asString().getValue()
            digest.write("${caseId}|${caseHash}\n".toArray())
            count += 1
        }
    } catch (_: Exception) {
        return (false, count, "")
    }
    let out = StringBuilder()
    for (byte in digest.finish()) {
        out.append(hcHex(byte / UInt8(16)))
        out.append(hcHex(byte % UInt8(16)))
    }
    (true, count, "sha256:${out.toString()}")
}

@Test
public class CangjieHumanEvalCase141151ContractTest {
    @TestCase
    public func hcUt141UnicodeAlphabeticContract(): Unit {
        let prompt = hcCaseText("CJ-HUMANEVAL-141", "prompt.md")
        let metadata = hcCaseText("CJ-HUMANEVAL-141", "metadata.json")
        @Expect(prompt.contains(HC_141_UNICODE_CONTRACT), true)
        @Expect(metadata.contains(HC_141_UNICODE_CONTRACT), true)
        @Expect(prompt.contains("Cangjie translation must implement the source oracle semantics"), true)
        @Expect(hcCaseText("CJ-HUMANEVAL-141", "starter/src/solution.cj").contains(
            "import std.unicode.*"), true)
        @Expect(r'é'.isLetter(), true)
        @Expect(r'🙂'.isLetter(), false)
    }

    @TestCase
    public func hcUt151PythonBoolIsIntSourceSemanticProjection(): Unit {
        @Expect(hc151ProjectedSquare("bool", 0, true), 1)
        @Expect(hc151ProjectedSquare("bool", 0, false), 0)
        @Expect(hc151ProjectedSquare("int", 3, false), 9)
        @Expect(hc151ProjectedSquare("float", 3, false), 0)
        @Expect(hcCaseText("CJ-HUMANEVAL-151", "metadata.json").contains(
            HC_151_BOOL_CONTRACT), true)
    }

    @TestCase
    public func hcBndUtf8EmojiAndBoolIntBoundaries(): Unit {
        let prompt141 = hcCaseText("CJ-HUMANEVAL-141", "prompt.md")
        let base141 = hcCaseText("CJ-HUMANEVAL-141", "tests/TestMain.cj")
        @Expect(prompt141.contains("Unicode"), true)
        @Expect(base141.contains("éxample.exe"), true)
        @Expect(base141.contains("🙂example.exe"), true)
        @Expect(hc151ProjectedSquare("bool", 0, true),
            hc151ProjectedSquare("int", 1, false))
        @Expect(hc151ProjectedSquare("bool", 0, false),
            hc151ProjectedSquare("int", 0, false))
        @Expect(hc151ProjectedSquare("float", 1, false), 0)
    }

    @TestCase
    public func hcPosPromptMetadataAndOracleAreAligned(): Unit {
        @Expect(hcContractAligned("CJ-HUMANEVAL-141", HC_141_UNICODE_CONTRACT,
            "file_name_check(\"éxample.exe\")", "file_name_check(\"éxample.exe\")"), true)
        @Expect(hcContractAligned("CJ-HUMANEVAL-151", HC_151_BOOL_CONTRACT,
            "evalBool(true)", "evalBool(true)"), true)
        @Expect(hcCaseText("CJ-HUMANEVAL-141", "metadata.json").contains(
            "\"callCount\": 28"), true)
        @Expect(hcCaseText("CJ-HUMANEVAL-151", "metadata.json").contains(
            "\"callCount\": 11"), true)
    }

    @TestCase
    public func hcNegSemanticDriftIsRejected(): Unit {
        @Expect(hcContractAligned("CJ-HUMANEVAL-141", HC_141_UNICODE_CONTRACT,
            "file_name_check(\"éxample.exe\")", "file_name_check(\"éxample.exe\")"), true)
        @Expect(hcContractAligned("CJ-HUMANEVAL-151", HC_151_BOOL_CONTRACT,
            "evalBool(false)", "evalBool(false)"), true)
        let prompt151 = hcCaseText("CJ-HUMANEVAL-151", "prompt.md")
        @Expect(prompt151.contains("Only values with `kind == \"int\"` are Python integers"), false)
    }

    @TestCase
    public func hcHistOther162CaseHashesRemainUnchanged(): Unit {
        let history = hcOtherCaseHash()
        @Expect(history[0], true)
        @Expect(history[1], 162)
        @Expect(history[2],
            "sha256:8304644ab95fe1746f652f4d7a33a4edb1faa3e7a588da724f54fd1b5af9e721")
    }
}
