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
        @Expect(validation.transportParityPass, true)
        @Expect(validation.performancePass, true)
        @Expect(cangjieF4AdminDiagnosticsContain(validation, "transport_diagnostic_placeholder"), true)
        @Expect(cangjieF4AdminDiagnosticsContain(validation, "performance_diagnostic_placeholder"), true)
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
