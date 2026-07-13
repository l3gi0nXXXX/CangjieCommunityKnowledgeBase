package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieHumanEvalP0P4Test {
    @TestCase
    public func p0UtStrictCandidateRoundTripPreservesUnicodeAndCanonicalIdentity(): Unit {
        let input = p0P4Candidate("CJ-HUMANEVAL-中", 1)
        input.caseId = "CJ-HUMANEVAL-UTF8"
        input.taskText = "中文与 emoji 😀"
        input.candidateHash = canonicalBenchmarkGapCandidateHash(input)
        let parsed = parseBenchmarkGapInputsJsonl(p0P4Json(input))
        let curated = curateBenchmarkGapRecordsFromJsonl(p0P4Json(input))
        @Expect(parsed.ok, true)
        @Expect(parsed.inputs[0].taskText, "中文与 emoji 😀")
        @Expect(canonicalBenchmarkGapIdentity(parsed.inputs[0]).contains("dataset-2026-07-14"), true)
        @Expect(curated.ok, true)
    }

    @TestCase
    public func p0BndUnknownSchemaAndUnconfirmedGapFailClosed(): Unit {
        let schema = p0P4Candidate("CJ-P0-BND-SCHEMA", 1)
        schema.schemaVersion = "ckb-benchmark-gap-v2"
        schema.candidateHash = canonicalBenchmarkGapCandidateHash(schema)
        let confirmation = p0P4Candidate("CJ-P0-BND-CONFIRM", 1)
        confirmation.knowledgeGapConfirmations = 1
        confirmation.candidateHash = canonicalBenchmarkGapCandidateHash(confirmation)
        @Expect(curateBenchmarkGapRecordsFromJsonl(p0P4Json(schema)).diagnostic, "unsupported_schema_version")
        @Expect(curateBenchmarkGapRecordsFromJsonl(p0P4Json(confirmation)).diagnostic, "knowledge_gap_double_confirmation_required")
    }

    @TestCase
    public func p0NegForbiddenCandidateBoundariesAndRetryFailClosed(): Unit {
        for (path in ["../gap.jsonl", "teacher-solutions/gap.jsonl", "prod/ckb-data/gap.jsonl", "/tmp/gap.jsonl"]) {
            let input = p0P4Candidate("CJ-P0-NEG", 1)
            input.candidatePath = path
            input.candidateHash = canonicalBenchmarkGapCandidateHash(input)
            @Expect(curateBenchmarkGapRecordsFromJsonl(p0P4Json(input)).diagnostic, "candidate_path_forbidden")
        }
        let retry = p0P4Candidate("CJ-P0-RETRY", 1)
        retry.attempt = 2
        retry.candidateHash = canonicalBenchmarkGapCandidateHash(retry)
        @Expect(curateBenchmarkGapRecordsFromJsonl(p0P4Json(retry)).diagnostic, "first_attempt_required")
    }

    @TestCase
    public func p4UtHigherRevisionReplacesSameCanonicalGap(): Unit {
        let first = p0P4Candidate("CJ-P4-REV", 1)
        first.candidateHash = canonicalBenchmarkGapCandidateHash(first)
        let second = p0P4Candidate("CJ-P4-REV", 2)
        second.taskText = "revised general task"
        second.candidateHash = canonicalBenchmarkGapCandidateHash(second)
        let result = curateBenchmarkGapRecordsFromJsonl(p0P4Json(first) + p0P4Json(second))
        @Expect(result.ok, true)
        @Expect(result.accepted, 1)
        @Expect(result.records.size, 1)
        @Expect(result.records[0].chunk.contains("revised general task"), true)
        @Expect(result.replacements, 1)
        @Expect(result.replacementAudit.size, 1)
    }

    @TestCase
    public func p4PosAuthoritative164ManifestProducesStableVersionedSnapshot(): Unit {
        let first = buildVersionedEvalSupportSnapshot("test/cangjie_eval/cases/Cangjie-HumanEval", "humaneval-cangjie-164-v1")
        let second = buildVersionedEvalSupportSnapshot("test/cangjie_eval/cases/Cangjie-HumanEval", "humaneval-cangjie-164-v1")
        @Expect(first.ok, true)
        @Expect(first.recordCount, 164 * 4)
        @Expect(first.jsonl, second.jsonl)
        @Expect(first.checksum, second.checksum)
        @Expect(first.jsonl.contains("ckb-eval-support-v1"), true)
    }

    @TestCase
    public func p4NegSnapshotIdentityAndAbsoluteRecordPathFailClosed(): Unit {
        @Expect(buildVersionedEvalSupportSnapshot("test/cangjie_eval/cases/Cangjie-HumanEval", "").ok, false)
        let records = ArrayList<CangjieTypedRecord>()
        let record = CangjieTypedRecord()
        record.sourceId = "unsafe"
        record.path = "/absolute/reference/solution.cj"
        records.add(record)
        let safety = validateEvalSupportRecordSafety(records)
        @Expect(safety.ok, false)
        @Expect(safety.diagnostics.size, 1)
    }

    @TestCase
    public func p0NegFakeAndMismatchedSha256FailClosed(): Unit {
        let fake = p0P4Candidate("CJ-P0-FAKE", 1)
        fake.evidenceHash = "sha256:fake"
        fake.candidateHash = canonicalBenchmarkGapCandidateHash(fake)
        @Expect(curateBenchmarkGapRecordsFromJsonl(p0P4Json(fake)).diagnostic, "evidence_hash_invalid")
        let mismatch = p0P4Candidate("CJ-P0-MISMATCH", 1)
        mismatch.evidenceHash = benchmarkGapSha256("different evidence")
        mismatch.candidateHash = canonicalBenchmarkGapCandidateHash(mismatch)
        @Expect(curateBenchmarkGapRecordsFromJsonl(p0P4Json(mismatch)).diagnostic, "evidence_hash_mismatch")
    }

    @TestCase
    public func p4NegTamperedSnapshotChecksumFailsClosed(): Unit {
        let snapshot = buildVersionedEvalSupportSnapshot("test/cangjie_eval/cases/Cangjie-HumanEval", "humaneval-cangjie-164-v1")
        @Expect(validateVersionedEvalSupportSnapshot(snapshot).ok, true)
        snapshot.jsonl += "{}\n"
        let tampered = validateVersionedEvalSupportSnapshot(snapshot)
        @Expect(tampered.ok, false)
        @Expect(tampered.diagnostics[0], "eval_support_snapshot_checksum_mismatch")
    }

    @TestCase
    public func p4E2eDoubleConfirmedKnowledgeGapEmitsStrictAuthorityJsonl(): Unit {
        let gate = CangjieHumanEvalPass1GateResult()
        for (group in [CangjieHumanEvalPass1GateGroups.C, CangjieHumanEvalPass1GateGroups.D]) {
            let gap = CangjieHumanEvalRemainingGap()
            gap.caseId = "CJ-HUMANEVAL-001"; gap.group = group; gap.status = "knowledge_gap"; gap.targetVersion = "1.0.0"
            gap.taskText = "中文 Rune 😀"; gap.gapCodes.add("G-STRING"); gate.remainingGaps.add(gap)
        }
        let jsonl = emitCangjieHumanEvalAuthoritativeGapCurationInput(gate, "dataset-2026-07-14", "teacher-run-001")
        let curated = curateBenchmarkGapRecordsFromJsonl(jsonl)
        @Expect(curated.ok, true)
        @Expect(curated.records.size, 1)
        let original = parseBenchmarkGapInputsJsonl(jsonl).inputs[0]
        gate.remainingGaps[1].taskText = "被篡改的中文任务 😀"
        let changedJsonl = emitCangjieHumanEvalAuthoritativeGapCurationInput(gate, "dataset-2026-07-14", "teacher-run-001")
        let changed = parseBenchmarkGapInputsJsonl(changedJsonl).inputs[0]
        @Expect(changed.evidenceHash == original.evidenceHash, false)
        @Expect(changed.candidateHash == original.candidateHash, false)
        gate.remainingGaps[1].taskText = "中文 Rune 😀"
        gate.remainingGaps[1].status = "compile_error"
        @Expect(emitCangjieHumanEvalAuthoritativeGapCurationInput(gate, "dataset-2026-07-14", "teacher-run-001"), "")
        gate.remainingGaps[1].status = "knowledge_gap"
        gate.remainingGaps[1].group = "X-untrusted-classifier"
        @Expect(emitCangjieHumanEvalAuthoritativeGapCurationInput(gate, "dataset-2026-07-14", "teacher-run-001"), "")
    }

    @TestCase
    public func p0PosAuthorityImporterRequiresSchemaAndCanonicalRoot(): Unit {
        let root = "target/p0-p4-authority-import"
        if (!exists(Path(root))) { Directory.create(Path(root), recursive: true) }
        let input = p0P4Candidate("CJ-P0-IMPORT", 1)
        input.candidatePath = "gap.jsonl"
        input.candidateHash = canonicalBenchmarkGapCandidateHash(input)
        File.writeTo(Path(root).join("gap.jsonl"), p0P4Json(input).toArray())
        @Expect(importAuthoritativeBenchmarkGapJsonl(root, "gap.jsonl").ok, true)
        File.writeTo(Path(root).join("legacy.jsonl"), "{\"caseId\":\"legacy\"}\n".toArray())
        @Expect(importAuthoritativeBenchmarkGapJsonl(root, "legacy.jsonl").diagnostic, "schema_version_required")
        @Expect(importAuthoritativeBenchmarkGapJsonl(root, "../outside.jsonl").ok, false)
    }
}

private func p0P4Candidate(caseId: String, revision: Int64): CangjieBenchmarkGapInput {
    let input = CangjieBenchmarkGapInput()
    input.schemaVersion = "ckb-benchmark-gap-v1"
    input.datasetVersion = "dataset-2026-07-14"
    input.teacherRunId = "teacher-run-001"
    input.evidence = "first-attempt compiler evidence 中文😀"
    input.evidenceHash = benchmarkGapSha256(input.evidence)
    input.candidatePath = "exports/benchmark-gap.jsonl"
    input.revision = revision
    input.attempt = 1
    input.failureTaxonomy = "knowledge_gap"
    input.knowledgeGapConfirmations = 2
    input.caseId = caseId
    input.taskText = "general ArrayList task"
    input.compilerOutput = "compile_error"
    input.missingKnowledge = "G-ARRAYLIST"
    input.interfaceId = "KI-02"
    input.contentFamily = "KC-02"
    input.updateMechanism = "KU-11"
    input.targetVersion = "1.0.0"
    input.officialCitation = "https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection"
    input
}

private func p0P4Json(input: CangjieBenchmarkGapInput): String {
    "{\"schemaVersion\":\"${input.schemaVersion}\",\"datasetVersion\":\"${input.datasetVersion}\",\"teacherRunId\":\"${input.teacherRunId}\",\"evidence\":\"${input.evidence}\",\"evidenceHash\":\"${input.evidenceHash}\",\"candidateHash\":\"${input.candidateHash}\",\"candidatePath\":\"${input.candidatePath}\",\"revision\":${input.revision},\"attempt\":${input.attempt},\"failureTaxonomy\":\"${input.failureTaxonomy}\",\"knowledgeGapConfirmations\":${input.knowledgeGapConfirmations},\"caseId\":\"${input.caseId}\",\"benchmark\":\"${input.benchmark}\",\"taskText\":\"${input.taskText}\",\"compilerOutput\":\"${input.compilerOutput}\",\"missingKnowledge\":\"${input.missingKnowledge}\",\"interfaceId\":\"${input.interfaceId}\",\"contentFamily\":\"${input.contentFamily}\",\"updateMechanism\":\"${input.updateMechanism}\",\"targetVersion\":\"${input.targetVersion}\",\"officialCitation\":\"${input.officialCitation}\"}\n"
}
