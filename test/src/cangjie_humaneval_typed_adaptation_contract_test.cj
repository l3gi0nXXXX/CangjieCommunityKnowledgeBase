package cangjie_community_knowledge_base_test

import std.collection.*
import std.fs.{Directory, File, Path, exists}
import std.process.launch
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.json.*

private let HTA_DATASET_ROOT = Path("cangjie_eval/cases/Cangjie-HumanEval")

private func htaReadUtf8(path: Path): (Bool, String, String) {
    try {
        return (true, String.fromUtf8(File.readFrom(path)), "ok")
    } catch (_: Exception) {
        return (false, "", "invalid_response_encoding")
    }
}

private func htaCaseText(caseId: String, relativePath: String): String {
    let decoded = htaReadUtf8(HTA_DATASET_ROOT.join(caseId).join(relativePath))
    if (!decoded[0]) { return "" }
    decoded[1]
}

private func htaHasAdaptation(metadataText: String, requiredText: String): Bool {
    try {
        let metadata = JsonValue.fromStr(metadataText).asObject()
        match (metadata.get("staticLanguageAdaptations")) {
            case Some(value) =>
                for (item in value.asArray().getItems()) {
                    if (item.asString().getValue() == requiredText) { return true }
                }
            case None => return false
        }
    } catch (_: Exception) {
        return false
    }
    false
}

private func htaNoConflictingExpected(rows: Array<(String, String)>): Bool {
    let expectedByCall = HashMap<String, String>()
    for (row in rows) {
        match (expectedByCall.get(row[0])) {
            case Some(expected) => if (expected != row[1]) { return false }
            case None => expectedByCall.add(row[0], row[1])
        }
    }
    true
}

private func htaCaseId(index: Int64): String {
    if (index < 10) { return "CJ-HUMANEVAL-00${index}" }
    if (index < 100) { return "CJ-HUMANEVAL-0${index}" }
    "CJ-HUMANEVAL-${index}"
}

private func htaSplitActualExpected(line: String): (Bool, String, String) {
    var started = false
    var inString = false
    var escaped = false
    var stringDelimiter = r'"'
    var parentheses: Int64 = 0
    var brackets: Int64 = 0
    var braces: Int64 = 0
    var part: Int64 = 0
    let actual = StringBuilder()
    let expected = StringBuilder()
    for (ch in line.toRuneArray()) {
        if (!started) {
            if (ch == r'(') { started = true; parentheses = 1 }
            continue
        }
        if (inString) {
            if (part == 0) { actual.append(ch) } else if (part == 1) { expected.append(ch) }
            if (escaped) { escaped = false }
            else if (ch == r'\\') { escaped = true }
            else if (ch == stringDelimiter) { inString = false }
            continue
        }
        if (ch == r'"' || ch == r'\'') {
            inString = true
            stringDelimiter = ch
        } else if (ch == r'(') { parentheses += 1 }
        else if (ch == r')') {
            parentheses -= 1
            if (parentheses == 0 && part == 1) {
                return (true, actual.toString().trimAscii(), "__property_verifier__")
            }
        }
        else if (ch == r'[') { brackets += 1 }
        else if (ch == r']') { brackets -= 1 }
        else if (ch == r'{') { braces += 1 }
        else if (ch == r'}') { braces -= 1 }
        if (ch == r',' && parentheses == 1 && brackets == 0 && braces == 0) {
            part += 1
            if (part == 2) { return (true, actual.toString().trimAscii(), expected.toString().trimAscii()) }
            continue
        }
        if (part == 0) { actual.append(ch) } else if (part == 1) { expected.append(ch) }
    }
    (false, "", "")
}

private func htaRealCorpusRows(): (Bool, Array<(String, String)>, Int64) {
    let rows = ArrayList<(String, String)>()
    var files: Int64 = 0
    for (index in 0..164) {
        let caseId = htaCaseId(index)
        let decoded = htaReadUtf8(HTA_DATASET_ROOT.join(caseId).join("tests/TestMain.cj"))
        if (!decoded[0]) { return (false, rows.toArray(), files) }
        files += 1
        for (line in decoded[1].split("\n")) {
            if (!line.contains("\"${caseId}_")) { continue }
            let split = htaSplitActualExpected(line.trimAscii())
            if (!split[0]) { return (false, rows.toArray(), files) }
            rows.add(("${caseId}:${split[1]}", split[2]))
        }
    }
    (true, rows.toArray(), files)
}

private func htaRunFixture(caseId: String, name: String, solution: String): (Int64, String) {
    let caseRoot = HTA_DATASET_ROOT.join(caseId)
    let root = Path("target/${name}")
    if (exists(root)) { _ = launch("/bin/rm", ["-rf", root.toString()]).wait() }
    Directory.create(root.join("src"), recursive: true)
    File.writeTo(root.join("cjpm.toml"), File.readFrom(caseRoot.join("tests/cjpm.executable.toml")))
    File.writeTo(root.join("src/eval_support.cj"), File.readFrom(caseRoot.join("starter/src/eval_support.cj")))
    File.writeTo(root.join("src/solution.cj"), solution.toArray())
    File.writeTo(root.join("src/test_main.cj"), File.readFrom(caseRoot.join("tests/TestMain.cj")))
    let command = "cd ${root.toString()} && cjpm clean && cjpm build -i && cjpm run > run.log 2>&1; exitCode=$?; if /usr/bin/grep -q 'An exception has occurred' run.log; then exit 1; else exit $exitCode; fi"
    let exitCode = launch("/bin/zsh", ["-c", command]).wait()
    let log = htaReadUtf8(root.join("run.log"))
    (exitCode, if (log[0]) { log[1] } else { log[2] })
}

@Test
public class CangjieHumanEvalTypedAdaptationContractTest {
    @TestCase
    public func htaUtDeclaredContractsAreMachineReadable(): Unit {
        let boolInt = "Python bool is an int subtype, but Cangjie Bool and Int64 are distinct; this typed projection accepts only EvalValue kind int."
        let iterable = "Python verifier accepts any return iterable through tuple(candidate(...)); this typed projection requires ArrayList<Int64>."
        let option = "Python None in each tuple position is represented by None<Int64>; an integer is represented by Some<Int64>(value)."
        @Expect(htaHasAdaptation(htaCaseText("CJ-HUMANEVAL-022", "metadata.json"), boolInt), true)
        @Expect(htaHasAdaptation(htaCaseText("CJ-HUMANEVAL-033", "metadata.json"), iterable), true)
        @Expect(htaHasAdaptation(htaCaseText("CJ-HUMANEVAL-037", "metadata.json"), iterable), true)
        @Expect(htaHasAdaptation(htaCaseText("CJ-HUMANEVAL-136", "metadata.json"), option), true)
    }

    @TestCase
    public func htaBndUnicodeEmojiMalformedJsonAndInvalidUtf8FailClosed(): Unit {
        @Expect(htaHasAdaptation("{\"staticLanguageAdaptations\":[\"中文🙂\"]}", "中文🙂"), true)
        @Expect(htaHasAdaptation("{\"staticLanguageAdaptations\":[", "中文🙂"), false)
        let invalid = Path("target/hta-invalid-编码🙂.bin")
        File.writeTo(invalid, [UInt8(255), UInt8(254)])
        let decoded = htaReadUtf8(invalid)
        @Expect(decoded[0], false)
        @Expect(decoded[1], "")
        @Expect(decoded[2], "invalid_response_encoding")
        @Expect(decoded[2].contains("target/"), false)
        @Expect(decoded[2].toAsciiLower().contains("token"), false)
    }

    @TestCase
    public func htaPosPromptTranslationAndCorpusStateExactLimits(): Unit {
        let case022 = htaCaseText("CJ-HUMANEVAL-022", "prompt.md") + htaCaseText("CJ-HUMANEVAL-022", "translation/line_translation.md")
        let case033 = htaCaseText("CJ-HUMANEVAL-033", "prompt.md") + htaCaseText("CJ-HUMANEVAL-033", "translation/line_translation.md")
        let case037 = htaCaseText("CJ-HUMANEVAL-037", "prompt.md") + htaCaseText("CJ-HUMANEVAL-037", "translation/line_translation.md")
        let case136 = htaCaseText("CJ-HUMANEVAL-136", "prompt.md") + htaCaseText("CJ-HUMANEVAL-136", "translation/line_translation.md")
        @Expect(case022.contains("does not reproduce Python's bool-as-int subtype rule"), true)
        @Expect(case033.contains("does not claim arbitrary Python iterable return compatibility"), true)
        @Expect(case037.contains("does not claim arbitrary Python iterable return compatibility"), true)
        @Expect(case136.contains("None<Int64>"), true)
        @Expect(case136.contains("Some<Int64>(value)"), true)
        let readme = htaCaseText("CJ-HUMANEVAL-022", "../README.md")
        @Expect(readme.contains("typed Cangjie contracts do not claim full Python duck-typing compatibility"), true)
        let canonical = htaReadUtf8(Path("cangjie_eval/cangjie_humaneval_manifest.jsonl"))
        @Expect(canonical[0], true)
        @Expect(canonical[1].contains("\"requiredKnowledgeTags\":[\"ArrayList\",\"Int64\",\"Bool\"]"), true)
        @Expect(canonical[1].contains("\"requiredKnowledgeTags\":[\"ArrayList\",\"Int64\",\"Option\"]"), true)
    }

    @TestCase
    public func htaNegConflictingExpectedAndExaggeratedClaimsAreRejected(): Unit {
        @Expect(htaNoConflictingExpected([("f([1])", "[1]"), ("f([2])", "[2]"), ("f([1])", "[1]")]), true)
        @Expect(htaNoConflictingExpected([("f([1])", "[1]"), ("f([1])", "[2]")]), false)
        for (caseId in ["CJ-HUMANEVAL-022", "CJ-HUMANEVAL-033", "CJ-HUMANEVAL-037", "CJ-HUMANEVAL-136"]) {
            let contract = htaCaseText(caseId, "metadata.json") + htaCaseText(caseId, "prompt.md") + htaCaseText(caseId, "translation/line_translation.md")
            @Expect(contract.contains("fully reproduces Python duck typing"), false)
            @Expect(contract.contains("accepts every Python iterable"), false)
        }
    }

    @TestCase
    public func htaRegAll164AuthoritativeAssertionsHaveOneExpectedValue(): Unit {
        let corpus = htaRealCorpusRows()
        @Expect(corpus[0], true)
        @Expect(corpus[2], 164)
        @Expect(corpus[1].size, 1546)
        @Expect(htaNoConflictingExpected(corpus[1]), true)
        let case151 = htaCaseText("CJ-HUMANEVAL-151", "tests/TestMain.cj")
        @Expect(case151.contains("CJ-HUMANEVAL-151_type_int_c008"), true)
        @Expect(case151.contains("CJ-HUMANEVAL-151_type_float_c009"), true)
        let readme = htaCaseText("CJ-HUMANEVAL-151", "../README.md")
        @Expect(readme.contains("Candidate invocations translated to Cangjie assertions: 1541"), true)
    }

    @TestCase
    public func htaPosOfficialFixturesPassAndStartersFail(): Unit {
        let solutions = [
            ("CJ-HUMANEVAL-022", """
package cangjie_humaneval_022
import std.collection.*
public func filter_integers(values: ArrayList<EvalValue>): ArrayList<Int64> {
    let out = ArrayList<Int64>()
    for (value in values) { if (value.kind == "int") { out.add(value.intValue) } }
    out
}
"""),
            ("CJ-HUMANEVAL-033", """
package cangjie_humaneval_033
import std.collection.*
import std.sort.*
public func sort_third(l: ArrayList<Int64>): ArrayList<Int64> {
    let out = ArrayList<Int64>(); let selected = ArrayList<Int64>()
    for (value in l) { out.add(value) }
    for (i in 0..l.size: 3) { selected.add(l[i]) }
    sort(selected)
    var index: Int64 = 0
    for (i in 0..l.size: 3) { out[i] = selected[index]; index += 1 }
    out
}
"""),
            ("CJ-HUMANEVAL-037", """
package cangjie_humaneval_037
import std.collection.*
import std.sort.*
public func sort_even(l: ArrayList<Int64>): ArrayList<Int64> {
    let out = ArrayList<Int64>(); let selected = ArrayList<Int64>()
    for (value in l) { out.add(value) }
    for (i in 0..l.size: 2) { selected.add(l[i]) }
    sort(selected)
    var index: Int64 = 0
    for (i in 0..l.size: 2) { out[i] = selected[index]; index += 1 }
    out
}
"""),
            ("CJ-HUMANEVAL-136", """
package cangjie_humaneval_136
import std.collection.*
public func largest_smallest_integers(lst: ArrayList<Int64>): (Option<Int64>, Option<Int64>) {
    var negative = None<Int64>; var positive = None<Int64>
    for (value in lst) {
        if (value < 0) { match (negative) { case Some(old) => if (value > old) { negative = Some<Int64>(value) }; case None => negative = Some<Int64>(value) } }
        if (value > 0) { match (positive) { case Some(old) => if (value < old) { positive = Some<Int64>(value) }; case None => positive = Some<Int64>(value) } }
    }
    (negative, positive)
}
""")
        ]
        for (fixture in solutions) {
            let positive = htaRunFixture(fixture[0], "hta-positive-${fixture[0]}", fixture[1])
            @Expect(positive[0], 0)
            @Expect(positive[1].contains("${fixture[0]} ok"), true)
            let starter = htaRunFixture(fixture[0], "hta-negative-${fixture[0]}", htaCaseText(fixture[0], "starter/src/solution.cj"))
            @Expect(starter[0] != 0, true)
            @Expect(starter[1].contains("CangjieEval failure"), true)
        }
    }

    @TestCase
    public func htaE2eAuthorityBindsAllTypedAdaptationArtifacts(): Unit {
        let authority = buildCangjieHumanEvalManifest(HTA_DATASET_ROOT.toString(), "")
        @Expect(authority.ok, true)
        @Expect(authority.rows.size, 164)
        for (caseId in ["CJ-HUMANEVAL-022", "CJ-HUMANEVAL-033", "CJ-HUMANEVAL-037", "CJ-HUMANEVAL-136"]) {
            var found = false
            for (row in authority.rows) {
                if (row.caseId == caseId) {
                    found = true
                    @Expect(row.metadataHash.startsWith("sha256:"), true)
                    @Expect(row.promptHash.startsWith("sha256:"), true)
                    @Expect(row.translationHash.startsWith("sha256:"), true)
                }
            }
            @Expect(found, true)
        }
    }
}
