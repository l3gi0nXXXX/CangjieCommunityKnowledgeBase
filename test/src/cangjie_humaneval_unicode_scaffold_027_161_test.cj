package cangjie_community_knowledge_base_test

import std.fs.{File, Path}
import std.unicode.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.json.*

private let HU_ROOT = Path("cangjie_eval/cases/Cangjie-HumanEval")
private let HU_SCAFFOLD_CONTRACT =
    "The completion-only starter imports std.unicode.* so Rune.toLowerCase(), Rune.toUpperCase(), and Rune.isLetter() are available without modifying the file prologue."
private let HU_027_FULL_CASE_CONTRACT =
    "String.toUpper(CasingOption.Other) and String.toLower(CasingOption.Other) return String and preserve full Unicode mappings that may expand one Rune to multiple Runes; Rune.toUpperCase() and Rune.toLowerCase() return only one Rune."

private func huRead(path: Path): (Bool, String) {
    try {
        return (true, String.fromUtf8(File.readFrom(path)))
    } catch (_: Exception) {
        return (false, "")
    }
}

private func huCase(caseId: String, relative: String): String {
    let decoded = huRead(HU_ROOT.join(caseId).join(relative))
    if (!decoded[0]) { return "" }
    decoded[1]
}

private func huHasUnicode(text: String): Bool {
    text.size != text.toRuneArray().size
}

private func huAligned(caseId: String, baseEvidence: String,
    plusCall: String): Bool {
    let prompt = huCase(caseId, "prompt.md")
    let metadata = huCase(caseId, "metadata.json")
    let starter = huCase(caseId, "starter/src/solution.cj")
    let base = huCase(caseId, "tests/TestMain.cj")
    let plus = huCase(caseId, "tests-plus/TestMain.cj")
    let translation = huCase(caseId, "translation/line_translation.md")
    let expectedContract = if (caseId == "CJ-HUMANEVAL-027") {
        HU_027_FULL_CASE_CONTRACT
    } else {
        HU_SCAFFOLD_CONTRACT
    }
    prompt.contains(expectedContract) &&
        metadata.contains(expectedContract) &&
        translation.contains(expectedContract) &&
        starter.contains("import std.unicode.*") &&
        base.contains(baseEvidence) && plus.contains(plusCall) &&
        huHasUnicode(plus)
}

private func huOtherCaseHash(): (Bool, Int64, String) {
    let decoded = huRead(Path("cangjie_eval/cangjie_humaneval_manifest.jsonl"))
    if (!decoded[0]) { return (false, 0, "") }
    let input = StringBuilder()
    var count: Int64 = 0
    try {
        for (line in decoded[1].split("\n")) {
            if (line.trimAscii() == "") { continue }
            let row = JsonValue.fromStr(line).asObject()
            let caseId = row.get("caseId").getOrThrow().asString().getValue()
            if (caseId == "CJ-HUMANEVAL-027") {
                continue
            }
            let caseHash = row.get("caseHash").getOrThrow().asString().getValue()
            input.append("${caseId}|${caseHash}\n")
            count += 1
        }
    } catch (_: Exception) {
        return (false, count, "")
    }
    (true, count, benchmarkGapSha256(input.toString()))
}

@Test
public class CangjieHumanEvalUnicodeScaffold027161Test {
    @TestCase
    public func huUt027CompletionOnlyUnicodeApiIsAvailable(): Unit {
        @Expect(r'é'.toUpperCase(), r'É')
        @Expect(r'É'.toLowerCase(), r'é')
        @Expect("ß".toUpper(CasingOption.Other), "SS")
        @Expect("İ".toLower(CasingOption.Other), "i̇")
        @Expect(huCase("CJ-HUMANEVAL-027", "starter/src/solution.cj").contains(
            "import std.unicode.*"), true)
        @Expect(huCase("CJ-HUMANEVAL-027", "metadata.json").contains(
            HU_027_FULL_CASE_CONTRACT), true)
    }

    @TestCase
    public func huUt161CompletionOnlyUnicodeApiIsAvailable(): Unit {
        @Expect(r'é'.isLetter(), true)
        @Expect(r'🙂'.isLetter(), false)
        @Expect(huCase("CJ-HUMANEVAL-161", "starter/src/solution.cj").contains(
            "import std.unicode.*"), true)
        @Expect(huCase("CJ-HUMANEVAL-161", "metadata.json").contains(
            HU_SCAFFOLD_CONTRACT), true)
    }

    @TestCase
    public func huBndUnicodeEmojiAndNoLetterReverseBoundaries(): Unit {
        let base027 = huCase("CJ-HUMANEVAL-027", "tests/TestMain.cj")
        let base161 = huCase("CJ-HUMANEVAL-161", "tests/TestMain.cj")
        @Expect(base027.contains("éÉ🙂"), true)
        @Expect(base027.contains("Éé🙂"), true)
        @Expect(base027.contains("ßİ🙂"), true)
        @Expect(base027.contains("SSi̇🙂"), true)
        @Expect(base161.contains("éÉ🙂"), true)
        @Expect(base161.contains("🙂😂"), true)
        @Expect(base161.contains("😂🙂"), true)
    }

    @TestCase
    public func huPosPromptMetadataTranslationBaseAndPlusAreAligned(): Unit {
        @Expect(huAligned("CJ-HUMANEVAL-027", "flip_case(\"éÉ🙂\")",
            "plusExpectString(flip_case("), true)
        @Expect(huAligned("CJ-HUMANEVAL-161", "solve(\"éÉ🙂\")",
            "plusExpectString(solve("), true)
        @Expect(huCase("CJ-HUMANEVAL-027", "metadata.json").contains(
            "\"callCount\": 5"), true)
        @Expect(huCase("CJ-HUMANEVAL-161", "metadata.json").contains(
            "\"callCount\": 10"), true)
    }

    @TestCase
    public func huNegMissingImportAndAsciiOnlyDriftAreRejected(): Unit {
        @Expect(huAligned("CJ-HUMANEVAL-027", "flip_case(\"éÉ🙂\")",
            "plusExpectString(flip_case("), true)
        @Expect(huAligned("CJ-HUMANEVAL-161", "solve(\"🙂😂\")",
            "plusExpectString(solve("), true)
        let contracts = huCase("CJ-HUMANEVAL-027", "prompt.md") +
            huCase("CJ-HUMANEVAL-161", "prompt.md")
        @Expect(contracts.contains("ASCII-only case conversion is sufficient"), false)
        @Expect(contracts.contains(
            "Rune.toUpperCase() and Rune.toLowerCase() return only one Rune"), true)
    }

    @TestCase
    public func huHistOther163CaseHashesRemainUnchanged(): Unit {
        let history = huOtherCaseHash()
        @Expect(history[0], true)
        @Expect(history[1], 163)
        @Expect(history[2],
            "sha256:e010046193f09c0bc9c04a5a3d18d6133a2b03df104667df27849fd457b67351")
    }
}
