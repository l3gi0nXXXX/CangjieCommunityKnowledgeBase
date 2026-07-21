package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.*
import std.fs.{Directory, File, Path, exists, remove}

@Test
public class CangjieEvalSupportIngestTest {
    @TestCase
    public func p2Pos002ExtractsVisibleEvalSupportRecords(): Unit {
        let result = extractEvalSupportRecords("test/cangjie_eval/cases/Cangjie-HumanEval/CJ-HUMANEVAL-000")

        @Expect(result.ok, true)
        @Expect(result.records.size, 4)
        @Expect(cangjieEvalSupportTestContainsFamily(result, "prompt"), true)
        @Expect(cangjieEvalSupportTestContainsFamily(result, "metadata"), true)
        @Expect(cangjieEvalSupportTestContainsFamily(result, "eval_support"), true)
        @Expect(cangjieEvalSupportTestContainsFamily(result, "visible_test_helpers"), true)
        @Expect(cangjieEvalSupportTestContentContains(result, "EvalValue"), true)
        @Expect(cangjieEvalSupportTestContentContains(result, "EvalEntry"), true)
    }

    @TestCase
    public func p2Bnd002VisibleTestsExcludeMainAssertions(): Unit {
        let result = extractEvalSupportRecords("test/cangjie_eval/cases/Cangjie-HumanEval/CJ-HUMANEVAL-000")
        let helpers = cangjieEvalSupportTestFamilyContent(result, "visible_test_helpers")

        @Expect(helpers.contains("func listOfFloat64"), true)
        @Expect(helpers.contains("main(): Int64"), false)
        @Expect(helpers.contains("has_close_elements("), false)
    }

    @TestCase
    public func p2Neg002ReferenceSolutionPathIsRejected(): Unit {
        let result = extractEvalSupportRecords("test/cangjie_eval/cases/Cangjie-HumanEval/CJ-HUMANEVAL-000/reference")

        @Expect(result.ok, false)
        @Expect(result.diagnostics.contains("forbidden_reference_solution_source"), true)
        @Expect(result.records.size, 0)
    }

    @TestCase
    public func p2Pos003DiscoversAllVisibleHumanEvalCases(): Unit {
        let roots = discoverCangjieHumanEvalCaseRoots("test/cangjie_eval/cases/Cangjie-HumanEval")

        @Expect(roots.size, 164)
        @Expect(roots[0].contains("CJ-HUMANEVAL-000"), true)
    }

    @TestCase
    public func p2Pos004ExtractsAllVisibleHumanEvalSupportRecords(): Unit {
        let result = extractAllEvalSupportRecords("test/cangjie_eval/cases/Cangjie-HumanEval")

        @Expect(result.ok, true)
        @Expect(result.records.size >= 164 * 4, true)
        @Expect(cangjieEvalSupportTestContentContains(result, "EvalValue"), true)
        @Expect(cangjieEvalSupportTestContentContains(result, "EvalEntry"), true)
        @Expect(cangjieEvalSupportTestContainsForbiddenPath(result), false)
    }

    @TestCase
    public func p2Bnd003SafetyValidationRejectsHiddenReferenceSignals(): Unit {
        let records = ArrayList<CangjieTypedRecord>()
        let record = CangjieTypedRecord()
        record.sourceId = "bad-eval"
        record.path = "hidden/solution.cj"
        record.content = "reference solution"
        records.add(record)

        let safety = validateEvalSupportRecordSafety(records)

        @Expect(safety.ok, false)
        @Expect(safety.diagnostics[0].contains("forbidden_reference_solution_source"), true)
    }

    @TestCase
    public func tr0UtFourFamiliesAreCompleteForEveryAuthorityCase(): Unit {
        let result = extractAllEvalSupportRecords("test/cangjie_eval/cases/Cangjie-HumanEval")

        @Expect(result.ok, true)
        @Expect(result.records.size, 656)
        @Expect(cangjieEvalSupportEveryCaseHasFourFamilies(result), true)
    }

    @TestCase
    public func tr0BndSnapshotHas164UniqueCasesAndStableAuthorityHash(): Unit {
        let snapshot = buildVersionedEvalSupportSnapshot("test/cangjie_eval/cases/Cangjie-HumanEval",
            "humaneval-cangjie-164-v1")

        @Expect(snapshot.ok, true)
        @Expect(snapshot.recordCount, 656)
        @Expect(cangjieEvalSupportSnapshotUniqueCaseCount(snapshot), 164)
        @Expect(snapshot.authorityHash, snapshot.checksum)
        @Expect(validateVersionedEvalSupportSnapshot(snapshot).ok, true)
    }

    @TestCase
    public func tr0PosUnicodeContentSurvivesAuthoritySnapshot(): Unit {
        let root = "target/tr0-pos-unicode/CJ-HUMANEVAL-999"
        cangjieEvalSupportRemoveTestRoot("target/tr0-pos-unicode")
        cangjieEvalSupportWriteTestFile(Path(root).join("prompt.md"), "# 任务\n处理中文与 emoji 😀。\n")
        cangjieEvalSupportWriteTestFile(Path(root).join("metadata.json"), "{\"id\":\"CJ-HUMANEVAL-999\"}\n")
        cangjieEvalSupportWriteTestFile(Path(root).join("starter/src/eval_support.cj"), "public class EvalValue {}\npublic class EvalEntry {}\n")
        cangjieEvalSupportWriteTestFile(Path(root).join("tests/TestMain.cj"), "public func helper(): Unit {}\nmain() {}\n")

        let snapshot = buildVersionedEvalSupportSnapshot("target/tr0-pos-unicode", "unicode-v1")

        @Expect(snapshot.ok, true)
        @Expect(snapshot.recordCount, 4)
        @Expect(snapshot.jsonl.contains("处理中文与 emoji 😀"), true)
        @Expect(validateVersionedEvalSupportSnapshot(snapshot).ok, true)
    }

    @TestCase
    public func tr0NegMalformedUtf8FailsClosed(): Unit {
        let root = "target/tr0-neg-utf8/CJ-HUMANEVAL-999"
        cangjieEvalSupportRemoveTestRoot("target/tr0-neg-utf8")
        cangjieEvalSupportWriteTestFile(Path(root).join("metadata.json"), "{\"id\":\"CJ-HUMANEVAL-999\"}\n")
        cangjieEvalSupportWriteTestFile(Path(root).join("starter/src/eval_support.cj"), "public class EvalValue {}\npublic class EvalEntry {}\n")
        cangjieEvalSupportWriteTestFile(Path(root).join("tests/TestMain.cj"), "public func helper(): Unit {}\nmain() {}\n")
        if (!exists(Path(root))) { Directory.create(Path(root), recursive: true) }
        File.writeTo(Path(root).join("prompt.md"), [UInt8(0xf0), UInt8(0x28), UInt8(0x8c), UInt8(0x28)])

        let snapshot = buildVersionedEvalSupportSnapshot("target/tr0-neg-utf8", "invalid-utf8-v1")

        @Expect(snapshot.ok, false)
        @Expect(snapshot.diagnostics.contains("CJ-HUMANEVAL-999:invalid_eval_support_encoding:prompt.md"), true)
        @Expect(snapshot.jsonl, "")
        @Expect(snapshot.authorityHash, "")
    }

    @TestCase
    public func tr0NegDuplicateUnknownAndMissingFamiliesFailClosed(): Unit {
        let datasetRoot = "target/tr0-neg-families"
        cangjieEvalSupportWriteFourFileFixture(datasetRoot, "CJ-HUMANEVAL-998", "# Task\nGeneral task.\n")

        let duplicate = buildVersionedEvalSupportSnapshot(datasetRoot, "family-duplicate-v1")
        duplicate.jsonl = duplicate.jsonl.replace("\"sourceFamily\":\"metadata\"", "\"sourceFamily\":\"prompt\"")
        cangjieEvalSupportRehashSnapshot(duplicate)
        @Expect(validateVersionedEvalSupportSnapshot(duplicate).diagnostics.contains("eval_support_snapshot_family_duplicate"), true)

        let unknown = buildVersionedEvalSupportSnapshot(datasetRoot, "family-unknown-v1")
        unknown.jsonl = unknown.jsonl.replace("\"sourceFamily\":\"metadata\"", "\"sourceFamily\":\"unknown\"")
        cangjieEvalSupportRehashSnapshot(unknown)
        @Expect(validateVersionedEvalSupportSnapshot(unknown).diagnostics.contains("eval_support_snapshot_family_unknown"), true)

        let missing = buildVersionedEvalSupportSnapshot(datasetRoot, "family-missing-v1")
        let retained = StringBuilder()
        for (line in missing.jsonl.split("\n")) {
            if (line != "" && !line.contains("\"sourceFamily\":\"metadata\"")) { retained.append(line); retained.append("\n") }
        }
        missing.jsonl = retained.toString()
        missing.recordCount -= 1
        cangjieEvalSupportRehashSnapshot(missing)
        @Expect(validateVersionedEvalSupportSnapshot(missing).diagnostics.contains("eval_support_snapshot_family_missing:CJ-HUMANEVAL-998:metadata"), true)
    }
}

private func cangjieEvalSupportEveryCaseHasFourFamilies(result: CangjieTypedRecordResult): Bool {
    let caseIds = HashSet<String>()
    for (record in result.records) { caseIds.add(record.caseId) }
    if (caseIds.size != 164) { return false }
    for (caseId in caseIds) {
        let families = HashSet<String>()
        for (record in result.records) {
            if (record.caseId == caseId) { families.add(record.sourceFamily) }
        }
        if (families.size != 4 || !families.contains("prompt") || !families.contains("metadata") ||
            !families.contains("eval_support") || !families.contains("visible_test_helpers")) {
            return false
        }
    }
    true
}

private func cangjieEvalSupportSnapshotUniqueCaseCount(snapshot: CangjieEvalSupportSnapshot): Int64 {
    let caseIds = HashSet<String>()
    for (line in snapshot.jsonl.split("\n")) {
        let parts = line.split("\"caseId\":\"")
        if (parts.size == 2) {
            let tail = parts[1].split("\"")
            if (tail.size > 0 && tail[0].startsWith("CJ-HUMANEVAL-")) { caseIds.add(tail[0]) }
        }
    }
    caseIds.size
}

private func cangjieEvalSupportWriteTestFile(path: Path, text: String): Unit {
    if (!exists(path.parent)) { Directory.create(path.parent, recursive: true) }
    File.writeTo(path, text.toArray())
}

private func cangjieEvalSupportWriteFourFileFixture(datasetRoot: String, caseId: String, prompt: String): Unit {
    cangjieEvalSupportRemoveTestRoot(datasetRoot)
    let root = Path(datasetRoot).join(caseId)
    cangjieEvalSupportWriteTestFile(root.join("prompt.md"), prompt)
    cangjieEvalSupportWriteTestFile(root.join("metadata.json"), "{\"id\":\"${caseId}\"}\n")
    cangjieEvalSupportWriteTestFile(root.join("starter/src/eval_support.cj"), "public class EvalValue {}\npublic class EvalEntry {}\n")
    cangjieEvalSupportWriteTestFile(root.join("tests/TestMain.cj"), "public func helper(): Unit {}\nmain() {}\n")
}

private func cangjieEvalSupportRehashSnapshot(snapshot: CangjieEvalSupportSnapshot): Unit {
    snapshot.checksum = benchmarkGapSha256("${snapshot.schemaVersion}:${snapshot.datasetVersion}:${snapshot.revision}:${snapshot.jsonl}")
    snapshot.authorityHash = snapshot.checksum
}

private func cangjieEvalSupportRemoveTestRoot(root: String): Unit {
    let path = Path(root)
    if (exists(path)) { remove(path, recursive: true) }
}

private func cangjieEvalSupportTestContainsFamily(result: CangjieTypedRecordResult, family: String): Bool {
    for (record in result.records) {
        if (record.sourceFamily == family) {
            return true
        }
    }
    false
}

private func cangjieEvalSupportTestContentContains(result: CangjieTypedRecordResult, needle: String): Bool {
    for (record in result.records) {
        if (record.content.contains(needle)) {
            return true
        }
    }
    false
}

private func cangjieEvalSupportTestFamilyContent(result: CangjieTypedRecordResult, family: String): String {
    for (record in result.records) {
        if (record.sourceFamily == family) {
            return record.content
        }
    }
    ""
}

private func cangjieEvalSupportTestContainsForbiddenPath(result: CangjieTypedRecordResult): Bool {
    for (record in result.records) {
        let value = "${record.path}\n${record.citation}".toAsciiLower()
        if (value.contains("hidden") || value.contains("reference") || value.contains("solution.cj")) {
            return true
        }
    }
    false
}
