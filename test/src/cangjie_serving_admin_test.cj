package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieServingAdminTest {
    @TestCase
    public func p6Pos001CandidateValidationPassesForOfflineServingFeed(): Unit {
        let kb = newOfflineKnowledgeBase()
        kb.normalize()
        let candidateVersion = kb.stageCandidateIndex(cangjieLiveSyncCandidateVersion())

        let validation = validateCandidateServingIndex(kb.candidateRecordSnapshot(), candidateVersion)

        @Expect(validation.ok, true)
        @Expect(validation.status, "candidate_validation_passed")
        @Expect(validation.exactSymbolHits > 0, true)
        @Expect(validation.docSectionHits > 0, true)
        @Expect(validation.coveragePass, true)
        @Expect(validation.evidenceHash.startsWith("h"), true)
    }

    @TestCase
    public func p6Neg001ValidationFailureKeepsOldActiveVersion(): Unit {
        let kb = newOfflineKnowledgeBase()
        let before = kb.status().activeKnowledgeVersion
        kb.normalize()

        let promotion = cangjiePromoteCandidateAfterValidation(kb, FileKnowledgeStore("target/ckb-p6-neg-store"), forceFailure: true)
        let after = kb.status()

        @Expect(promotion.ok, false)
        @Expect(promotion.activePromoted, false)
        @Expect(promotion.validation.status, "candidate_validation_forced_failure")
        @Expect(after.activeKnowledgeVersion, before)
        @Expect(after.failedCandidateVersion.contains("candidate"), true)
    }

    @TestCase
    public func f4ValidationChecksExactDocToolNegativeTransportAndPerformanceSignals(): Unit {
        let records = ArrayList<NormalizedRecord>()
        records.add(cangjieF4AdminRecord("sym-arraylist-add", CangjieTypedRecordKinds.SYMBOL_CARD, "ArrayList.add", "symbolKey=ArrayList.add\nmodule=std.collection\nsignature=func add(value: T): Unit", CangjieSourceSets.STD, "vr-std-1"))
        records.add(cangjieF4AdminRecord("doc-arraylist-add", CangjieTypedRecordKinds.DOC_SECTION, "ArrayList.add docs", "ArrayList.add appends values. Do not use append.", CangjieSourceSets.DOCS, "vr-docs-1"))
        records.add(cangjieF4AdminRecord("tool-cjpm-test", CangjieTypedRecordKinds.TOOL_MANUAL, "cjpm test", "Run cjpm test to execute package tests.", CangjieSourceSets.TOOLS, "vr-tools-1"))

        let validation = validateCandidateServingIndex(records, "ckb-f4-candidate")

        @Expect(validation.ok, true)
        @Expect(validation.exactSymbolHits > 0, true)
        @Expect(validation.docSectionHits > 0, true)
        @Expect(validation.toolManualHits > 0, true)
        @Expect(validation.negativeRuleHits > 0, true)
        @Expect(validation.taskPackCoveragePass, true)
        @Expect(validation.transportParityPass, true)
        @Expect(validation.vectorHealthPass, true)
        @Expect(validation.performancePass, true)
        @Expect(cangjieF4AdminDiagnosticsContain(validation, "rest_mcp_parity_passed"), true)
        @Expect(cangjieF4AdminDiagnosticsContain(validation, "vector_health_passed"), true)
        @Expect(cangjieF4AdminDiagnosticsContain(validation, "performance_threshold_passed"), true)
    }

    @TestCase
    public func f4ValidationReportsMissingToolManualCoverageInsteadOfCountingOnlyDocs(): Unit {
        let records = ArrayList<NormalizedRecord>()
        records.add(cangjieF4AdminRecord("sym-arraylist-add", CangjieTypedRecordKinds.SYMBOL_CARD, "ArrayList.add", "symbolKey=ArrayList.add\nmodule=std.collection\nsignature=func add(value: T): Unit", CangjieSourceSets.STD, "vr-std-1"))
        records.add(cangjieF4AdminRecord("doc-arraylist-add", CangjieTypedRecordKinds.DOC_SECTION, "ArrayList.add docs", "ArrayList.add appends values. Do not use append.", CangjieSourceSets.DOCS, "vr-docs-1"))

        let validation = validateCandidateServingIndex(records, "ckb-f4-candidate")

        @Expect(validation.servingDocumentCount > 0, true)
        @Expect(validation.toolManualHits, 0)
        @Expect(cangjieF4AdminDiagnosticsContain(validation, "tool_manual_coverage_missing"), true)
        @Expect(cangjieF4AdminDiagnosticsContain(validation, "task_pack_coverage_missing"), true)
    }

    @TestCase
    public func p4Neg001VectorDimensionMismatchFailsCandidateGate(): Unit {
        let records = ArrayList<NormalizedRecord>()
        records.add(cangjieF4AdminRecord("sym-arraylist-add", CangjieTypedRecordKinds.SYMBOL_CARD, "ArrayList.add", "symbolKey=ArrayList.add\nmodule=std.collection\nsignature=func add(value: T): Unit", CangjieSourceSets.STD, "vr-std-1"))
        records.add(cangjieF4AdminRecord("doc-arraylist-add", CangjieTypedRecordKinds.DOC_SECTION, "ArrayList.add docs", "ArrayList.add appends values. Do not use append.", CangjieSourceSets.DOCS, "vr-docs-1"))
        records.add(cangjieF4AdminRecord("tool-cjpm-test", CangjieTypedRecordKinds.TOOL_MANUAL, "cjpm test", "Run cjpm test to execute package tests.", CangjieSourceSets.TOOLS, "vr-tools-1"))
        let vector = VectorStoreStatus()
        vector.backend = "qdrant"
        vector.collection = "ckb_active"
        vector.dimension = 1024
        vector.count = 3
        vector.state = EmbeddingProviderState.DEGRADED
        vector.degradedReason = "dimension_mismatch"

        let validation = validateCandidateServingIndexWithVectorStatus(records, "ckb-f4-candidate", vector)

        @Expect(validation.ok, false)
        @Expect(validation.vectorHealthPass, false)
        @Expect(validation.vectorState, EmbeddingProviderState.DEGRADED)
        @Expect(validation.vectorDegradedReason, "dimension_mismatch")
        @Expect(cangjieF4AdminDiagnosticsContainPrefix(validation, "vector_health_failed:dimension_mismatch"), true)
    }

    @TestCase
    public func p4E2E001HundredQueryPerformanceProbeHasStableHashAndP95(): Unit {
        let records = ArrayList<NormalizedRecord>()
        records.add(cangjieF4AdminRecord("sym-arraylist-add", CangjieTypedRecordKinds.SYMBOL_CARD, "ArrayList.add", "symbolKey=ArrayList.add\nmodule=std.collection\nsignature=func add(value: T): Unit\naliases=ArrayList.add;add", CangjieSourceSets.STD, "vr-std-1"))
        records.add(cangjieF4AdminRecord("doc-arraylist-add", CangjieTypedRecordKinds.DOC_SECTION, "ArrayList.add docs", "ArrayList.add appends values. Do not use append.", CangjieSourceSets.DOCS, "vr-docs-1"))
        records.add(cangjieF4AdminRecord("tool-cjpm-test", CangjieTypedRecordKinds.TOOL_MANUAL, "cjpm test", "Run cjpm test to execute package tests.", CangjieSourceSets.TOOLS, "vr-tools-1"))
        let index = buildCangjieServingIndex(records, activeKnowledgeVersion: "ckb-f4-active")
        let queries = ArrayList<String>()
        for (i in 0..100) {
            queries.add("ArrayList.add query ${i}")
        }

        let first = cangjieServingPerformanceProbe(index, queries, budget: 3, p95Threshold: 1000)
        let second = cangjieServingPerformanceProbe(index, queries, budget: 3, p95Threshold: 1000)

        @Expect(first.pass, true)
        @Expect(first.queryCount, 100)
        @Expect(first.p95Cost > 0, true)
        @Expect(first.p95Cost <= 1000, true)
        @Expect(first.evidenceHash.startsWith("h"), true)
        @Expect(second.evidenceHash, first.evidenceHash)
        @Expect(second.p95Cost, first.p95Cost)
    }
}

private func cangjieF4AdminRecord(sourceId: String, kind: String, title: String, chunk: String, sourceSet: String, versionResolutionId: String): NormalizedRecord {
    let record = NormalizedRecord()
    record.sourceId = sourceId
    record.recordKind = kind
    record.title = title
    record.chunk = chunk
    record.citation = "test:${sourceId}"
    record.metadata.sourceId = sourceId
    record.metadata.sourceType = if (sourceSet == CangjieSourceSets.STD || sourceSet == CangjieSourceSets.STDX) { SourceTypes.REPO } else { SourceTypes.DOC }
    record.metadata.sourceSet = sourceSet
    record.metadata.targetVersion = "1.0.0"
    record.metadata.versionResolutionId = versionResolutionId
    record.metadata.knowledgeVersion = "ckb-f4-active"
    record.metadata.path = if (kind == CangjieTypedRecordKinds.TOOL_MANUAL) { "tools/cjpm.md" } else { "docs/${sourceId}.md" }
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.TRUSTED
    record
}

private func cangjieF4AdminDiagnosticsContain(validation: CangjieCandidateValidationResult, diagnostic: String): Bool {
    for (item in validation.diagnostics) {
        if (item == diagnostic) {
            return true
        }
    }
    false
}

private func cangjieF4AdminDiagnosticsContainPrefix(validation: CangjieCandidateValidationResult, prefix: String): Bool {
    for (item in validation.diagnostics) {
        if (item.startsWith(prefix)) {
            return true
        }
    }
    false
}
