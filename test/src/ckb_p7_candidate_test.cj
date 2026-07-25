package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, Path, exists}
import std.process.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbP7CandidateTest {
    @TestCase
    public func tR4UtAnonymousAtomPreviewUsesKnowledgePlane(): Unit {
        let atom = r4KnowledgeAtom("knowledge-atom-rune-count", "General Rune counting uses toRuneArray size.")
        let records = ArrayList<NormalizedRecord>(); records.add(atom)
        let query = ckbBenchmarkGapAnonymousQuery(atom)

        let preview = ckbBenchmarkGapPreviewAll(records, records)

        @Expect(query.contains(atom.sourceId), false)
        @Expect(query.toAsciiLower().contains("humaneval"), false)
        @Expect(query.contains(atom.metadata.path), false)
        @Expect(query.toAsciiLower().contains("visible"), false)
        @Expect(preview.ok, true)
        @Expect(preview.indexBuildCount, 1)
        @Expect(preview.queryCount, 1)
        @Expect(preview.passed, 1)
    }

    @TestCase
    public func tR4BndHistoricalProjectionDropsEvalLegacyAndDuplicateAtom(): Unit {
        let records = ArrayList<NormalizedRecord>()
        records.add(r4OfficialRecord())
        records.add(r4EvalRecord())
        records.add(r4LegacyGapRecord())
        records.add(r4KnowledgeAtom("knowledge-atom-rune-count", "General Rune counting 中文🙂."))
        records.add(r4KnowledgeAtom("knowledge-atom-rune-count", "General Rune counting 中文🙂."))

        let clean = ckbCleanHistoricalStudentRecords(records)

        @Expect(clean.ok, true)
        @Expect(clean.records.size, 2)
        @Expect(clean.removedCount, 3)
        @Expect(clean.evidenceHash.size > 0, true)
        @Expect(ckbStudentCleanRemovalDiagnostic("normalized", clean.removedCount, clean.evidenceHash).contains("CJ-HUMANEVAL"), false)
    }

    @TestCase
    public func tR4NegIncomingVisibleTestFailsWithoutEchoingPayload(): Unit {
        let incoming = ArrayList<NormalizedRecord>()
        let polluted = r4KnowledgeAtom("knowledge-atom-polluted", "Visible tests: assert secret answer.")
        incoming.add(polluted)

        let validation = ckbValidateIncomingStudentRecords(incoming)

        @Expect(validation.ok, false)
        @Expect(validation.errorCode, "student_knowledge_leakage_blocked")
        @Expect(validation.evidenceHash.contains("secret answer"), false)
    }

    @TestCase
    public func tR4UtTrustReportsAreDeterministicAndAggregateFields(): Unit {
        let polluted = r4OfficialRecord(); polluted.title = "CJ-HUMANEVAL-009 answer"
        polluted.chunk = "Task: secret recipe\nVisible tests: hidden"; polluted.metadata.path = "visible-benchmark/hidden"
        let records = ArrayList<NormalizedRecord>(); records.add(polluted)
        let first = ckbBuildStudentLeakageReport(records)
        let second = ckbBuildStudentLeakageReport(records)

        @Expect(first.ok, false)
        @Expect(first.leakageCount >= 3, true)
        @Expect(first.evidenceHash, second.evidenceHash)
        @Expect(first.json.contains("secret recipe"), false)
        @Expect(first.json.contains("CJ-HUMANEVAL-009"), false)
        let pathOnly = r4OfficialRecord(); pathOnly.title = polluted.title
        pathOnly.metadata.path = "safe/path-a"
        let symbolOnly = r4OfficialRecord(); symbolOnly.title = polluted.title
        symbolOnly.metadata.symbol = "SafeSymbolB"
        let derivedOnly = r4OfficialRecord(); derivedOnly.title = polluted.title
        derivedOnly.metadata.derivedFrom = ["safe-derived-c"]
        let pathRecords = ArrayList<NormalizedRecord>(); pathRecords.add(pathOnly)
        let symbolRecords = ArrayList<NormalizedRecord>(); symbolRecords.add(symbolOnly)
        let derivedRecords = ArrayList<NormalizedRecord>(); derivedRecords.add(derivedOnly)
        let pathReport = ckbBuildStudentLeakageReport(pathRecords)
        let symbolReport = ckbBuildStudentLeakageReport(symbolRecords)
        let derivedReport = ckbBuildStudentLeakageReport(derivedRecords)
        @Expect(pathReport.evidenceHash == symbolReport.evidenceHash, false)
        @Expect(symbolReport.evidenceHash == derivedReport.evidenceHash, false)
        @Expect(pathReport.json.contains("safe/path-a"), false)
        @Expect(symbolReport.json.contains("SafeSymbolB"), false)
        @Expect(derivedReport.json.contains("safe-derived-c"), false)

        let atom = r4KnowledgeAtom("knowledge-atom-rune-count", "General Rune counting uses toRuneArray size.")
        let atoms = ArrayList<NormalizedRecord>(); atoms.add(atom)
        let queryReport = ckbBuildAnonymousAtomQueryReport(atoms, atoms)
        @Expect(queryReport.ok, true)
        @Expect(queryReport.indexBuildCount, 1)
        @Expect(queryReport.passed, 1)
        @Expect(queryReport.jsonl.contains(atom.sourceId), false)
    }

    @TestCase
    public func tR4BndEqualLengthTrustInputsUseDistinctSha256Evidence(): Unit {
        let baseRootA = "target/t-r4-sha-base-aa"
        let baseRootB = "target/t-r4-sha-base-bb"
        p7S3Empty(baseRootA); p7S3Empty(baseRootB)
        let baseA = ckbCleanCandidateBaseDiagnostic(FileKnowledgeStore(baseRootA))
        let baseB = ckbCleanCandidateBaseDiagnostic(FileKnowledgeStore(baseRootB))
        @Expect(baseRootA.size, baseRootB.size)
        @Expect(baseA.evidenceHash.startsWith("sha256:"), true)
        @Expect(baseB.evidenceHash.startsWith("sha256:"), true)
        @Expect(baseA.evidenceHash == baseB.evidenceHash, false)

        let pollutedA = r4OfficialRecord(); pollutedA.title = "CJ-HUMANEVAL-101 answer"
        let pollutedB = r4OfficialRecord(); pollutedB.title = "CJ-HUMANEVAL-102 answer"
        let recordsA = ArrayList<NormalizedRecord>(); recordsA.add(pollutedA)
        let recordsB = ArrayList<NormalizedRecord>(); recordsB.add(pollutedB)
        let reportA = ckbBuildStudentLeakageReport(recordsA)
        let reportB = ckbBuildStudentLeakageReport(recordsB)
        @Expect(pollutedA.title.size, pollutedB.title.size)
        @Expect(reportA.evidenceHash.startsWith("sha256:"), true)
        @Expect(reportB.evidenceHash.startsWith("sha256:"), true)
        @Expect(reportA.evidenceHash == reportB.evidenceHash, false)
        @Expect(reportA.json.contains("\"findingsEvidenceHash\":\"sha256:"), true)

        let atomA = r4KnowledgeAtom("knowledge-atom-sha-a", "General Rune counting uses toRuneArray size A.")
        let atomB = r4KnowledgeAtom("knowledge-atom-sha-b", "General Rune counting uses toRuneArray size B.")
        let atomsA = ArrayList<NormalizedRecord>(); atomsA.add(atomA)
        let atomsB = ArrayList<NormalizedRecord>(); atomsB.add(atomB)
        let queryA = ckbBuildAnonymousAtomQueryReport(atomsA, atomsA)
        let queryB = ckbBuildAnonymousAtomQueryReport(atomsB, atomsB)
        @Expect(atomA.sourceId.size, atomB.sourceId.size)
        @Expect(atomA.chunk.size, atomB.chunk.size)
        @Expect(queryA.evidenceHash.startsWith("sha256:"), true)
        @Expect(queryB.evidenceHash.startsWith("sha256:"), true)
        @Expect(queryA.evidenceHash == queryB.evidenceHash, false)
        @Expect(queryA.jsonl.contains("\"atomHash\":\"sha256:"), true)
        @Expect(queryA.jsonl.contains("\"queryHash\":\"sha256:"), true)
    }

    @TestCase
    public func tR4NegIncomingIdentityConflictFailsClosedButExactDuplicateDedupes(): Unit {
        let first = r4OfficialRecord()
        let exact = r4OfficialRecord()
        let exactInput = ArrayList<NormalizedRecord>(); exactInput.add(first); exactInput.add(exact)
        let exactResult = ckbValidateIncomingStudentRecords(exactInput)
        @Expect(exactResult.ok, true)
        @Expect(exactResult.records.size, 1)

        let conflicting = r4OfficialRecord()
        conflicting.metadata.targetVersion = "9.9.9"
        let conflictInput = ArrayList<NormalizedRecord>(); conflictInput.add(first); conflictInput.add(conflicting)
        let conflict = ckbValidateIncomingStudentRecords(conflictInput)
        @Expect(conflict.ok, false)
        @Expect(conflict.errorCode, "student_record_identity_conflict")
        @Expect(conflict.evidenceHash.contains("9.9.9"), false)
    }

    @TestCase
    public func tR4BndCleanBaseAcceptsOnlyEmptyTemporaryStore(): Unit {
        let emptyRoot = "target/t-r4-clean-base-empty"
        p7S3Empty(emptyRoot)
        let emptyStore = FileKnowledgeStore(emptyRoot)
        let allowed = ckbCleanCandidateBaseDiagnostic(emptyStore)
        @Expect(allowed.ok, true)
        @Expect(allowed.code, "clean_candidate_base_allowed")

        let seededRoot = "target/t-r4-clean-base-seeded"
        p7S3Empty(seededRoot)
        let seededStore = FileKnowledgeStore(seededRoot)
        seededStore.writeLinesAtomically("metadata/active-snapshot.manifest", "active=seed\n")
        let blocked = ckbCleanCandidateBaseDiagnostic(seededStore)
        @Expect(blocked.ok, false)
        @Expect(blocked.code, "contaminated_base_forbidden")

        let protectedStore = FileKnowledgeStore("target/t-r4-final11-never-read")
        let protected = ckbCleanCandidateBaseDiagnostic(protectedStore)
        @Expect(protected.ok, false)
        @Expect(protected.code, "contaminated_base_forbidden")
        @Expect(seededStore.readText("metadata/active-snapshot.manifest"), "active=seed\n")
    }

    @TestCase
    public func p7S3U01PreviewBuildsOneIndexFor440Queries(): Unit {
        let records = p7S3Records(440)
        let preview = ckbBenchmarkGapPreviewAll(records, records)
        @Expect(preview.ok, true)
        @Expect(preview.indexBuildCount, 1)
        @Expect(preview.queryCount, 440)
        @Expect(preview.passed, 440)
    }

    @TestCase
    public func p7S3B01PreviewHandlesOneTwoHundredAndUnicodeBoundary(): Unit {
        for (count in [Int64(1), Int64(200)]) {
            let records = p7S3Records(count)
            let preview = ckbBenchmarkGapPreviewAll(records, records)
            @Expect(preview.ok, true)
            @Expect(preview.indexBuildCount, 1)
            @Expect(preview.queryCount, count)
        }
        let unicode = p7S3Records(1)
        unicode[0].chunk += "\n中文🙂"
        @Expect(ckbBenchmarkGapPreviewAll(unicode, unicode).ok, true)
    }

    @TestCase
    public func p7S3P01BatchArtifactPrecedesCursorAndAggregates440(): Unit {
        let root = "target/p7-s3-p01"
        p7S3Empty(root)
        let store = FileKnowledgeStore(root)
        let records = p7S3Records(440)
        let plan = ckbSaveBenchmarkGapScanPlan(store,
            ckbBuildBenchmarkGapScanPlan(records, "p7-s3-440", "1.0.0"))
        var current = plan
        var now: Int64 = 100
        while (current.state != "complete") {
            let claim = ckbClaimBenchmarkGapScanPlan(store, plan.planHash, plan.inputSha256,
                plan.targetVersion, "owner", now, 50)
            let batch = ckbSaveBenchmarkGapCandidateBatch(store, plan, records,
                claim.startOffset, claim.endOffset)
            @Expect(batch.ok, true)
            current = ckbCheckpointBenchmarkGapScanPlan(store, plan.planHash, plan.inputSha256,
                plan.targetVersion, "owner", claim.plan.revision, claim.startOffset,
                claim.endOffset, now + 1)
            now += 2
        }
        let aggregate = ckbLoadBenchmarkGapCandidateBatches(store, plan, records)
        @Expect(current.nextOffset, 440)
        @Expect(aggregate.ok, true)
        @Expect(aggregate.written, 440)
    }

    @TestCase
    public func p7S3N01MissingOrMismatchedTargetFailsClosed(): Unit {
        let records = p7S3Records(2)
        let absent = p7S3Records(3)[2]
        let missing = ArrayList<NormalizedRecord>()
        missing.add(records[0])
        let expected = ArrayList<NormalizedRecord>(); expected.add(records[0]); expected.add(absent)
        let preview = ckbBenchmarkGapPreviewAll(missing, expected)
        @Expect(preview.ok, false)
        @Expect(preview.errorCode, "benchmark_gap_preview_target_missed")

        let root = "target/p7-s3-n01"
        p7S3Empty(root)
        let store = FileKnowledgeStore(root)
        let plan = ckbSaveBenchmarkGapScanPlan(store,
            ckbBuildBenchmarkGapScanPlan(records, "p7-s3-negative", "1.0.0"))
        @Expect(ckbLoadBenchmarkGapCandidateBatches(store, plan, records).ok, false)
        @Expect(plan.nextOffset, 0)
    }
}

private func r4KnowledgeAtom(sourceId: String, knowledge: String): NormalizedRecord {
    let record = NormalizedRecord()
    record.sourceId = sourceId; record.recordKind = CangjieTypedRecordKinds.KNOWLEDGE_ATOM
    record.title = "Knowledge atom G-RUNE-COUNT"; record.chunk = "Knowledge: ${knowledge}"
    record.citation = "https://docs.cangjie-lang.cn/docs/1.0.0/language/basic_data_type"
    record.metadata.sourceId = sourceId; record.metadata.sourceSet = CangjieSourceSets.KNOWLEDGE_ATOMS
    record.metadata.path = "knowledge-atom/KC-01/rune-count"; record.metadata.symbol = "KI-01:G-RUNE-COUNT"
    record.metadata.targetVersion = "1.0.0"; record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.REVIEWED; record.metadata.derivedFrom = ["knowledge-atom:G-RUNE-COUNT"]
    record
}

private func r4OfficialRecord(): NormalizedRecord {
    let record = NormalizedRecord(); record.sourceId = "official-rune-doc"
    record.recordKind = CangjieTypedRecordKinds.DOC_SECTION; record.title = "Rune docs"
    record.chunk = "Rune is the Cangjie character type."; record.citation = "https://docs.cangjie-lang.cn/docs/1.0.0/"
    record.metadata.sourceId = record.sourceId; record.metadata.sourceSet = CangjieSourceSets.DOCS
    record.metadata.targetVersion = "1.0.0"; record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.TRUSTED; record
}

private func r4EvalRecord(): NormalizedRecord {
    let record = r4OfficialRecord(); record.sourceId = "eval-support-CJ-HUMANEVAL-001-prompt"
    record.recordKind = CangjieTypedRecordKinds.EVAL_SUPPORT; record.metadata.sourceSet = CangjieSourceSets.EVAL_SUPPORT
    record.metadata.sourceId = record.sourceId; record
}

private func r4LegacyGapRecord(): NormalizedRecord {
    let record = r4OfficialRecord(); record.sourceId = "curated-gap-legacy-deadbeef"
    record.title = "HumanEval gap"; record.chunk = "Task: hidden\nVisible tests: secret"
    record.metadata.sourceId = record.sourceId; record.metadata.sourceSet = CangjieSourceSets.EVAL_SUPPORT
    record.metadata.path = "visible-benchmark/Cangjie-HumanEval/CJ-HUMANEVAL-001/KI-01"; record
}

private func p7S3Records(count: Int64): ArrayList<NormalizedRecord> {
    let records = ArrayList<NormalizedRecord>()
    for (index in 0..count) {
        let record = r4KnowledgeAtom("knowledge-atom-p7-${index}",
            "ArrayList generic operation vocabulary-${index}")
        record.title = "Knowledge atom G-ARRAYLIST-${index}"
        record.metadata.path = "knowledge-atom/KC-02/arraylist-${index}"
        record.metadata.symbol = "KI-02:G-ARRAYLIST-${index}"
        record.metadata.derivedFrom = ["knowledge-atom:G-ARRAYLIST-${index}"]
        records.add(record)
    }
    records
}

private func p7S3Empty(root: String): Unit {
    if (exists(Path(root))) { _ = launch("/bin/rm", ["-rf", root]).wait() }
    Directory.create(Path(root), recursive: true)
}
