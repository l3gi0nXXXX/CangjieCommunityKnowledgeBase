package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists, remove}
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.json.*

@Test
public class CangjieStudentContaminationGateAccuracyTest {
    @TestCase
    public func s3Ut01AttackAndControlCorpusHavePerfectClassification(): Unit {
        let attacks = s3LoadCorpus("fixtures/cangjie_student_leakage_attack.jsonl")
        let controls = s3LoadCorpus("fixtures/cangjie_student_clean_control.jsonl")
        @Expect(attacks.diagnostic, "ok")
        @Expect(controls.diagnostic, "ok")
        @Expect(attacks.rows.size, 8)
        @Expect(controls.rows.size, 4)
        var falseNegative: Int64 = 0
        var falsePositive: Int64 = 0
        for (row in attacks.rows) {
            let diagnostic = cangjieStudentRecordDiagnostic(s3Record("attack-${row.id}", row.payload))
            let atomDiagnostic = validateKnowledgeAtomServingProjection(row.payload, "")
            if (row.targetGate == "record") {
                if (diagnostic.ok) { falseNegative += 1 }
                @Expect(diagnostic.code, row.expectedCode)
            } else {
                if (atomDiagnostic == "") { falseNegative += 1 }
                @Expect(atomDiagnostic, row.expectedCode)
            }
            @Expect(diagnostic.reason.contains(row.payload), false)
        }
        for (row in controls.rows) {
            let diagnostic = cangjieStudentRecordDiagnostic(s3Record("control-${row.id}", row.knowledgeText))
            if (!diagnostic.ok) { falsePositive += 1 }
        }
        @Expect(falseNegative, 0)
        @Expect(falsePositive, 0)
    }

    @TestCase
    public func s3Bnd01Utf8EncodingMalformedAndOversizedInputsFailClosed(): Unit {
        @Expect(validateKnowledgeAtomServingProjection("CJ-HUMAN\u{200b}EVAL-900 synthetic", ""), "atom_content_contamination")
        @Expect(validateKnowledgeAtomServingProjection("中文😀 general Rune guidance", ""), "")
        @Expect(validateKnowledgeAtomServingProjection(s3Repeat("中😀", 2049), ""), "atom_serving_field_too_long")

        let root = s3TempRoot("boundary")
        let malformed = Path(root).join("malformed.jsonl")
        File.writeTo(malformed, "{\"id\":\"broken\"\n".toArray())
        @Expect(s3LoadCorpus(malformed.toString()).diagnostic, "malformed_json")
        let invalidUtf8 = Path(root).join("invalid-utf8.jsonl")
        File.writeTo(invalidUtf8, [UInt8(0xff), UInt8(0xfe)])
        @Expect(s3LoadCorpus(invalidUtf8.toString()).diagnostic, "invalid_response_encoding")
        s3Remove(root)
    }

    @TestCase
    public func s3Pos01OfficialAndEmpiricalAtomsCrossCurationAndServing(): Unit {
        let controls = s3LoadCorpus("fixtures/cangjie_student_clean_control.jsonl")
        var accepted: Int64 = 0
        for (row in controls.rows) {
            let bundle = s3AtomBundle(row)
            let atom = runKnowledgeAtomTestBundle(bundle)
            @Expect(atom.ok, true)
            @Expect(atom.passed, 3)
            let gap = s3Gap(row, bundle)
            let inputs = ArrayList<CangjieBenchmarkGapInput>()
            inputs.add(gap)
            let curated = curateBenchmarkGapRecords(inputs)
            @Expect(curated.diagnostic, "ok")
            @Expect(curated.ok, true)
            @Expect(curated.records.size, 1)
            if (curated.records.size == 0) { continue }
            let feed = buildServingDocuments(curated.records)
            @Expect(feed.ok, true)
            @Expect(feed.documents.size > 0, true)
            @Expect(curated.records[0].chunk.contains("Task:"), false)
            @Expect(curated.records[0].chunk.contains("Visible tests:"), false)
            accepted += 1
        }
        @Expect(accepted, 4)
    }

    @TestCase
    public func s3Neg01PollutionIsBlockedAtFormalIngestCurationServingMcpAndPrecommitBoundaries(): Unit {
        let payload = "CJ-HUMANEVAL-900 synthetic identity"

        let firstInitRoot = s3TempRoot("first-init-900")
        let evalRoot = Path(firstInitRoot).join("eval")
        let caseRoot = evalRoot.join("CJ-HUMANEVAL-900")
        s3WriteFile(caseRoot.join("prompt.md"),
            "# Synthetic 900\ncanonical_solution synthetic marker\n")
        s3WriteFile(caseRoot.join("metadata.json"),
            "{\"id\":\"CJ-HUMANEVAL-900\"}\n")
        s3WriteFile(caseRoot.join("starter/src/eval_support.cj"),
            "public class SyntheticEval900 {}\n")
        s3WriteFile(caseRoot.join("tests/TestMain.cj"),
            "public func syntheticVisible900(): Unit {}\n")
        let firstInitOptions = CkbFirstInitOptions()
        firstInitOptions.evalRoot = evalRoot.toString()
        firstInitOptions.targetVersion = "1.0.0"
        let assembly = assembleCkbFirstInitializationRecords(firstInitOptions)
        @Expect(assembly.ok, false)
        @Expect(assembly.evalSupportAuthority.ok, false)
        @Expect(s3Contains(assembly.evalSupportAuthority.diagnostics,
            "forbidden_reference_solution_source"), true)

        let pollutedRow = S3CorpusRow()
        pollutedRow.id = "polluted"
        pollutedRow.sourceClass = "official"
        pollutedRow.citation = "https://docs.cangjie-lang.cn/docs/1.0.0/"
        pollutedRow.atomId = "G-SYNTHETIC-POLLUTION"
        pollutedRow.knowledgeText = payload
        pollutedRow.example = "general example"
        let pollutedBundle = s3AtomBundle(pollutedRow)
        @Expect(validateKnowledgeAtomTestBundle(pollutedBundle).diagnostic, "atom_content_contamination")
        let inputs = ArrayList<CangjieBenchmarkGapInput>()
        inputs.add(s3Gap(pollutedRow, pollutedBundle))
        @Expect(curateBenchmarkGapRecords(inputs).diagnostic, "atom_content_contamination")

        let record = s3Record("polluted", payload)
        let records = ArrayList<NormalizedRecord>()
        records.add(record)
        let feed = buildServingDocuments(records)
        @Expect(feed.ok, false)
        @Expect(feed.documents.size, 0)

        let kb = newOfflineKnowledgeBase()
        kb.stageCandidateRecords("s3-query-candidate", records)
        _ = kb.promoteCandidateToActive("s3-query-active")
        let query = cangjieServingSearch(kb, "synthetic identity", 3, targetVersion: "1.0.0")
        @Expect(query.records.size, 0)
        @Expect(query.fallbackReason.contains(payload), false)

        let mcpRoot = s3TempRoot("mcp")
        let mcpStore = FileKnowledgeStore(mcpRoot)
        _ = kb.persistActiveSnapshot(mcpStore)
        let mcp = CkbMcpStdioServer(CkbCommandLoopService(CkbRuntimeConfig(), mcpStore))
        let mcpRequest = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"cangjie_task_knowledge_pack\",\"arguments\":{\"taskId\":\"SYNTHETIC-900\",\"benchmark\":\"synthetic\",\"taskText\":\"synthetic identity\",\"compilerOutput\":\"synthetic compiler output\",\"targetVersion\":\"1.0.0\"}}}"
        let mcpResponse = mcp.handleRequest(mcpRequest)
        @Expect(mcpResponse.contains("\"error\""), true)
        @Expect(mcpResponse.contains("student_knowledge_leakage_blocked"), true)
        @Expect(mcpResponse.contains(payload), false)
        s3Remove(mcpRoot)

        let certified = CkbCertifiedKnowledgeRecord()
        certified.canonicalIdentity = "s3:polluted"
        certified.revision = 1
        certified.record = record
        certified.evidenceHash = ckbCertifiedKnowledgeRecordEvidenceHash(certified)
        let certifiedRecords = ArrayList<CkbCertifiedKnowledgeRecord>()
        certifiedRecords.add(certified)
        let preCommit = CkbCertifiedProductionPreCommitGate(kb, "s3-production-candidate",
            kb.status().activeKnowledgeVersion, CkbProductionReleaseProof(), certifiedRecords)
        let preCommitResult = preCommit.evaluate("s3-production-candidate", kb.status().activeKnowledgeVersion)
        @Expect(preCommitResult.passed, false)
        @Expect(preCommitResult.status, "student_knowledge_leakage_blocked")
        @Expect(preCommitResult.diagnostics[0].contains(payload), false)
        s3Remove(firstInitRoot)
    }

    @TestCase
    public func s3E2e01PollutedCandidateCannotChangeActiveVersion(): Unit {
        let root = s3TempRoot("production-901")
        let kb = r7CleanKnowledgeBase()
        let store = FileKnowledgeStore(Path(root).join("store").toString())
        @Expect(kb.persistActiveSnapshot(store).ok, true)
        let cleanRecords = s3CertifiedRecords(kb.activeRecordSnapshot())
        let fixture = r7BuildRealRunnerProof(cleanRecords)
        @Expect(fixture.ok, true)
        if (!fixture.ok) {
            s3Remove(root)
            return
        }
        let activeBefore = kb.status().activeKnowledgeVersion
        let snapshotBefore = store.loadActiveSnapshot()
        let checksumBefore = ckbCertifiedNormalizedRecordsChecksum(
            snapshotBefore.normalizedRecords)
        let pointerBefore = ckbActiveSnapshotPointerIdentityHash(
            store.loadActiveSnapshotPointer())

        let authority = parseCangjieHumanEvalAuthorityManifest(
            fixture.proof.authorityManifestJsonl)
        @Expect(authority.ok, true)
        let authorityOnlyFragment = authority.rows[0].signature
        let polluted = s3Record("polluted-candidate-901",
            authorityOnlyFragment)
        @Expect(cangjieStudentRecordDiagnostic(polluted).ok, true)
        let pollutedRecords = ArrayList<NormalizedRecord>()
        for (record in kb.activeRecordSnapshot()) {
            pollutedRecords.add(record)
        }
        pollutedRecords.add(polluted)
        let ordinaryValidation = validateCandidateServingIndex(pollutedRecords,
            "s3-authority-aware-901-candidate")
        @Expect(ordinaryValidation.ok, true)
        let pollutedCertified = s3CertifiedRecords(pollutedRecords)
        let candidateVersion = "s3-authority-aware-901-candidate"
        let gate = CkbCertifiedProductionPreCommitGate(kb, candidateVersion,
            activeBefore, fixture.proof, pollutedCertified)
        let promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(
            kb, store, candidateVersion, pollutedRecords,
            preCommitGate: gate, expectedBaseActiveVersion: activeBefore,
            expectedBaseActivePointerHash: pointerBefore)
        @Expect(promotion.ok, false)
        @Expect(promotion.validation.status,
            "student_knowledge_leakage_blocked")
        @Expect(s3Contains(promotion.validation.diagnostics,
            authorityOnlyFragment), false)
        @Expect(kb.status().activeKnowledgeVersion, activeBefore)
        let snapshotAfter = store.loadActiveSnapshot()
        @Expect(snapshotAfter.activeVersion, snapshotBefore.activeVersion)
        @Expect(ckbCertifiedNormalizedRecordsChecksum(
            snapshotAfter.normalizedRecords), checksumBefore)
        @Expect(ckbActiveSnapshotPointerIdentityHash(
            store.loadActiveSnapshotPointer()), pointerBefore)
        s3Remove(root)
    }
}

private class S3CorpusRow {
    var id: String = ""
    var targetGate: String = ""
    var payload: String = ""
    var expectedCode: String = ""
    var sourceClass: String = ""
    var citation: String = ""
    var atomId: String = ""
    var knowledgeText: String = ""
    var example: String = ""
    var originalFailureEvidenceHash: String = ""
    var completedRunManifestHash: String = ""
    var solutionBindingHash: String = ""
    var experiments: String = ""
    var commandEvidence: String = ""
    init() {}
}

private class S3Corpus {
    var diagnostic: String = "ok"
    var rows: ArrayList<S3CorpusRow> = ArrayList<S3CorpusRow>()
    init() {}
}

private func s3LoadCorpus(path: String): S3Corpus {
    let result = S3Corpus()
    let text = try {
        String.fromUtf8(File.readFrom(Path(path)))
    } catch (_: Exception) {
        result.diagnostic = "invalid_response_encoding"
        return result
    }
    for (line in text.split("\n")) {
        if (line.trimAscii() == "") { continue }
        try {
            let object = JsonValue.fromStr(line).asObject()
            let row = S3CorpusRow()
            row.id = s3JsonString(object, "id")
            row.targetGate = s3JsonString(object, "targetGate")
            row.payload = s3JsonString(object, "payload")
            row.expectedCode = s3JsonString(object, "expectedCode")
            row.sourceClass = s3JsonString(object, "sourceClass")
            row.citation = s3JsonString(object, "citation")
            row.atomId = s3JsonString(object, "atomId")
            row.knowledgeText = s3JsonString(object, "knowledgeText")
            row.example = s3JsonString(object, "example")
            row.originalFailureEvidenceHash = s3JsonString(object, "originalFailureEvidenceHash")
            row.completedRunManifestHash = s3JsonString(object, "completedRunManifestHash")
            row.solutionBindingHash = s3JsonString(object, "solutionBindingHash")
            row.commandEvidence = s3JsonString(object, "commandEvidence")
            match (object.get("experiments")) {
                case Some(value) => row.experiments = value.toString()
                case None => ()
            }
            if (row.id == "") {
                result.diagnostic = "fixture_contract_invalid"
                result.rows.clear()
                return result
            }
            result.rows.add(row)
        } catch (_: Exception) {
            result.diagnostic = "malformed_json"
            result.rows.clear()
            return result
        }
    }
    result
}

private func s3AtomBundle(row: S3CorpusRow): String {
    let tests = if (row.experiments == "") {
        "[{\"category\":\"positive\",\"operation\":\"arraylist_size\",\"input\":\"[1,2,3]\",\"expected\":\"3\"},{\"category\":\"negative\",\"operation\":\"contains\",\"input\":\"stable\",\"needle\":\"unstable\",\"expected\":\"false\"},{\"category\":\"boundary\",\"operation\":\"rune_count\",\"input\":\"中文😀\",\"expected\":\"3\"}]"
    } else { row.experiments }
    let empirical = if (row.sourceClass == "teacher_empirical") {
        ",\"teacherEmpiricalProvenance\":{\"originalFailureEvidenceHash\":\"${row.originalFailureEvidenceHash}\",\"completedRunManifestHash\":\"${row.completedRunManifestHash}\",\"solutionBindingHash\":\"${row.solutionBindingHash}\"},\"execution\":{\"total\":3,\"passed\":3,\"failed\":0,\"status\":\"passed\",\"commandEvidence\":\"${row.commandEvidence}\",\"commandEvidenceHash\":\"${benchmarkGapSha256(row.commandEvidence)}\"}"
    } else { "" }
    let raw = "{\"atomId\":\"${row.atomId}\",\"sourceClass\":\"${row.sourceClass}\",\"citation\":\"${row.citation}\",\"targetVersion\":\"1.0.0\",\"candidateHash\":\"sha256:0000000000000000000000000000000000000000000000000000000000000000\",\"knowledgeText\":\"${s3Escape(row.knowledgeText)}\",\"example\":\"${s3Escape(row.example)}\",\"purificationPassed\":true,\"tests\":${tests}${empirical}}"
    s3Rehash(raw)
}

private func s3Gap(row: S3CorpusRow, bundle: String): CangjieBenchmarkGapInput {
    let input = CangjieBenchmarkGapInput()
    input.sourceClass = row.sourceClass
    input.caseId = "SYNTHETIC-CONTROL"
    input.taskText = "Synthetic audit task"
    input.compilerOutput = "Synthetic audit output"
    input.missingKnowledge = "G-ARRAYLIST"
    input.interfaceId = "KI-02"
    input.contentFamily = "KC-02"
    input.updateMechanism = "KU-11"
    input.targetVersion = "1.0.0"
    input.officialCitation = row.citation
    input.knowledgeAtomCandidate = true
    input.knowledgeAtomTestBundle = bundle
    input
}

private func s3Record(sourceId: String, chunk: String): NormalizedRecord {
    let record = NormalizedRecord()
    record.sourceId = sourceId
    record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    record.title = "Synthetic general knowledge"
    record.chunk = chunk
    record.citation = "https://docs.cangjie-lang.cn/docs/1.0.0/synthetic"
    record.metadata.sourceId = sourceId
    record.metadata.sourceType = SourceTypes.DOC
    record.metadata.sourceSet = CangjieSourceSets.DOCS
    record.metadata.path = "docs/synthetic.md"
    record.metadata.symbol = "Synthetic.general"
    record.metadata.targetVersion = "1.0.0"
    record.metadata.versionResolutionId = "s3-v1"
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.TRUSTED
    record
}

private func s3CertifiedRecords(
    records: ArrayList<NormalizedRecord>): ArrayList<CkbCertifiedKnowledgeRecord> {
    let out = ArrayList<CkbCertifiedKnowledgeRecord>()
    for (record in records) {
        let item = CkbCertifiedKnowledgeRecord()
        item.canonicalIdentity = "s3:${record.sourceId}"
        item.revision = 1
        item.record = record
        item.evidenceHash = ckbCertifiedKnowledgeRecordEvidenceHash(item)
        out.add(item)
    }
    out
}

private func s3Contains(values: ArrayList<String>, fragment: String): Bool {
    for (value in values) { if (value.contains(fragment)) { return true } }
    false
}

private func s3WriteFile(path: Path, text: String): Unit {
    if (!exists(path.parent)) { Directory.create(path.parent, recursive: true) }
    File.writeTo(path, text.toArray())
}

private func s3JsonString(object: JsonObject, key: String): String {
    match (object.get(key)) {
        case Some(value) => value.asString().getValue()
        case None => ""
    }
}

private func s3Rehash(raw: String): String {
    let marker = "sha256:"
    match (raw.indexOf(marker)) {
        case Some(start) =>
            let old = raw[start..(start + 71)]
            raw.replace(old, cangjieKnowledgeAtomCandidateHash(raw))
        case None => raw
    }
}

private func s3Escape(raw: String): String {
    raw.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r")
}

private func s3Repeat(value: String, count: Int64): String {
    let out = StringBuilder()
    for (_ in 0..count) { out.append(value) }
    out.toString()
}

private func s3TempRoot(name: String): String {
    let root = "target/s3-contamination-${name}"
    s3Remove(root)
    Directory.create(Path(root), recursive: true)
    root
}

private func s3Remove(root: String): Unit {
    if (exists(Path(root))) { remove(Path(root), recursive: true) }
}
