package cangjie_community_knowledge_base_test

import std.fs.{File, Path}
import std.unicode.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.json.*

private let HU_ROOT = Path("cangjie_eval/cases/Cangjie-HumanEval")
private let HU_SCAFFOLD_CONTRACT =
    "The completion-only starter imports std.unicode.* so Rune.toLowerCase(), Rune.toUpperCase(), and Rune.isLetter() are available without modifying the file prologue."

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
    prompt.contains(HU_SCAFFOLD_CONTRACT) &&
        metadata.contains(HU_SCAFFOLD_CONTRACT) &&
        translation.contains(HU_SCAFFOLD_CONTRACT) &&
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
            if (caseId == "CJ-HUMANEVAL-027" || caseId == "CJ-HUMANEVAL-161") {
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
        @Expect(huCase("CJ-HUMANEVAL-027", "starter/src/solution.cj").contains(
            "import std.unicode.*"), true)
        @Expect(huCase("CJ-HUMANEVAL-027", "metadata.json").contains(
            HU_SCAFFOLD_CONTRACT), true)
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
            "\"callCount\": 4"), true)
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
    }

    @TestCase
    public func huHistOther162CaseHashesRemainUnchanged(): Unit {
        let history = huOtherCaseHash()
        @Expect(history[0], true)
        @Expect(history[1], 162)
        @Expect(history[2],
            "sha256:82201eb5c75bc6097e3d44e7e219fe32edd090b75e784fcb4062a3ffd48ec842")
    }
}
