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

    @TestCase
    public func f9Pos001CandidatePromotionUsesStagingVectorAndSingleEmbeddingPass(): Unit {
        let provider = CangjieAdminEmbeddingProvider(2)
        let vectorStore = CangjieAdminTrackingVectorStore(initialCount: 3)
        let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
        kb.configureVectorCollections("ckb_active", "ckb_candidate")
        let store = FileKnowledgeStore("target/ckb-admin-safe-candidate-promotion")
        let records = cangjieF4AdminPromotionRecords()

        let promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb, store, "ckb-admin-safe-candidate", records)
        let status = kb.status()

        @Expect(promotion.ok, true)
        @Expect(promotion.activePromoted, true)
        @Expect(provider.calls, 2)
        @Expect(vectorStore.deletedActiveCollection, false)
        @Expect(vectorStore.recreateCalls, 1)
        @Expect(status.storage.vectorActiveCollection.startsWith("ckb_candidate_stage_"), true)
        @Expect(status.storage.vectorIndexCount, records.size)
        @Expect(store.has("normalized/candidate/ckb-admin-safe-candidate.ckb"), true)
        @Expect(store.has("metadata/active-snapshot.manifest"), true)
    }

    @TestCase
    public func f9Bnd001CandidatePromotionKeepsStagingCollectionBoundedWhenActiveNameIsLong(): Unit {
        let kb = KnowledgeBase(FakeClock(0))
        var longActive = "active"
        for (i in 0..12) {
            longActive += "_candidate_1234567890123_h${i}"
        }
        kb.configureVectorCollections(longActive, "ckb_candidate")
        let store = FileKnowledgeStore("target/ckb-admin-bounded-candidate-collection")
        let records = cangjieF4AdminPromotionRecords()

        let promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb, store, "ckb-admin-long-active-candidate", records)
        let activeCollection = kb.status().storage.vectorActiveCollection

        @Expect(promotion.ok, true)
        @Expect(promotion.activePromoted, true)
        @Expect(activeCollection.startsWith("ckb_candidate_stage_"), true)
        @Expect(activeCollection.size < 80, true)
        @Expect(store.has("metadata/active-snapshot.manifest"), true)
    }

    @TestCase
    public func f9Neg001CandidatePromotionVectorFailureKeepsOldActiveAndDeletesStaging(): Unit {
        let provider = CangjieAdminEmbeddingProvider(2, failAtCall: 2, failReason: "ollama_timeout")
        let vectorStore = CangjieAdminTrackingVectorStore(initialCount: 3)
        let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
        kb.configureVectorCollections("ckb_active", "ckb_candidate")
        let before = kb.status().activeKnowledgeVersion
        let store = FileKnowledgeStore("target/ckb-admin-safe-candidate-failure")
        let records = cangjieF4AdminPromotionRecords()

        let promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb, store, "ckb-admin-fail-candidate", records)
        let after = kb.status()

        @Expect(promotion.ok, false)
        @Expect(promotion.activePromoted, false)
        @Expect(provider.calls, 2)
        @Expect(vectorStore.deletedActiveCollection, false)
        @Expect(vectorStore.deleteCollectionCalls, 1)
        @Expect(after.activeKnowledgeVersion, before)
        @Expect(promotion.validation.vectorDegradedReason.contains("ollama_timeout"), true)
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

private func cangjieF4AdminPromotionRecords(): ArrayList<NormalizedRecord> {
    let records = ArrayList<NormalizedRecord>()
    records.add(cangjieF4AdminRecord("sym-arraylist-add", CangjieTypedRecordKinds.SYMBOL_CARD, "ArrayList.add", "symbolKey=ArrayList.add\nmodule=std.collection\nsignature=func add(value: T): Unit\naliases=ArrayList.add;add", CangjieSourceSets.STD, "vr-std-1"))
    records.add(cangjieF4AdminRecord("doc-arraylist-add", CangjieTypedRecordKinds.DOC_SECTION, "ArrayList.add docs", "ArrayList.add appends values. Do not use append.", CangjieSourceSets.DOCS, "vr-docs-1"))
    records.add(cangjieF4AdminRecord("tool-cjpm-test", CangjieTypedRecordKinds.TOOL_MANUAL, "cjpm test", "Run cjpm test to execute package tests.", CangjieSourceSets.TOOLS, "vr-tools-1"))
    records
}

private class CangjieAdminEmbeddingProvider <: EmbeddingProvider {
    private let configuredBatchSize: Int64
    private let failReason: String
    public var calls: Int64 = 0
    public var failAtCall: Int64 = -1

    init(batchSize: Int64, failAtCall!: Int64 = -1, failReason!: String = "") {
        this.configuredBatchSize = batchSize
        this.failAtCall = failAtCall
        this.failReason = failReason
    }

    public func embed(texts: ArrayList<String>, model: String, dimensions: Int64): EmbeddingBatch {
        this.calls += 1
        let batch = EmbeddingBatch()
        batch.requested = texts.size
        batch.batchSize = this.configuredBatchSize
        batch.status = this.status()
        if (this.calls == this.failAtCall) {
            batch.status.state = EmbeddingProviderState.DOWN
            batch.status.degradedReason = if (this.failReason != "") { this.failReason } else { "embedding_failed" }
            batch.failed = texts.size
            return batch
        }
        for (_ in texts) {
            let vector = ArrayList<Float64>()
            vector.add(1.0)
            vector.add(2.0)
            vector.add(0.5)
            batch.vectors.add(vector)
        }
        batch.succeeded = texts.size
        batch
    }

    public func embedWithDeadline(texts: ArrayList<String>, model: String, dimensions: Int64, deadlineAtMillis: Int64): EmbeddingBatch {
        this.embed(texts, model, dimensions)
    }

    public func status(): EmbeddingStatus {
        let status = EmbeddingStatus()
        status.provider = "ollama"
        status.model = "bge-m3:latest"
        status.dimensions = 3
        status.endpointConfigured = true
        status.batchSize = this.configuredBatchSize
        status.timeoutMillis = 100
        status.retryCount = 0
        status.production = true
        status.state = EmbeddingProviderState.READY
        status
    }
}

private class CangjieAdminTrackingVectorStore <: VectorStore {
    public var recreateCalls: Int64 = 0
    public var upsertBatchCalls: Int64 = 0
    public var deleteCollectionCalls: Int64 = 0
    public var deletedActiveCollection: Bool = false
    private var activeCount: Int64 = 0
    private var stagingCollection: String = ""
    private var stagingCount: Int64 = 0

    init(initialCount!: Int64 = 0) {
        this.activeCount = initialCount
    }

    public func upsert(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.upsertBatch(collection, vectors)
    }

    public func upsertBatch(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.upsertBatchCalls += 1
        if (collection == "ckb_active") {
            this.activeCount += vectors.size
        } else {
            this.stagingCollection = collection
            this.stagingCount += vectors.size
        }
        this.status(collection)
    }

    public func upsertBatchWithDeadline(collection: String, vectors: ArrayList<VectorRecord>, deadlineAtMillis: Int64): VectorStoreStatus {
        this.upsertBatch(collection, vectors)
    }

    public func search(collection: String, queryVector: ArrayList<Float64>, filters: VectorSearchFilters, topK: Int64): ArrayList<VectorSearchResult> {
        ArrayList<VectorSearchResult>()
    }

    public func status(collection: String): VectorStoreStatus {
        let status = VectorStoreStatus()
        status.backend = "qdrant"
        status.collection = collection
        status.activeCollection = "ckb_active"
        status.candidateCollection = "ckb_candidate"
        status.dimension = 3
        status.distance = "Cosine"
        status.state = EmbeddingProviderState.READY
        status.count = if (collection == "ckb_active") {
            this.activeCount
        } else if (collection == this.stagingCollection) {
            this.stagingCount
        } else {
            0
        }
        status
    }

    public func ensureReadyCollection(collection: String): VectorStoreStatus {
        this.status(collection)
    }

    public func clear(collection: String): VectorStoreStatus {
        if (collection == "ckb_active") {
            this.deletedActiveCollection = true
            this.activeCount = 0
        } else {
            this.stagingCollection = collection
            this.stagingCount = 0
        }
        this.status(collection)
    }

    public func recreate(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.recreateCalls += 1
        this.clear(collection)
        if (vectors.size > 0) {
            return this.upsertBatch(collection, vectors)
        }
        this.status(collection)
    }

    public func recreateWithDeadline(collection: String, vectors: ArrayList<VectorRecord>, deadlineAtMillis: Int64): VectorStoreStatus {
        this.recreate(collection, vectors)
    }

    public func deleteCollection(collection: String): VectorStoreStatus {
        this.deleteCollectionCalls += 1
        if (collection == "ckb_active") {
            this.deletedActiveCollection = true
            this.activeCount = 0
        } else if (collection == this.stagingCollection) {
            this.stagingCount = 0
        }
        this.status(collection)
    }

    public func backup(collection: String): VectorBackup {
        let backup = VectorBackup()
        backup.collection = collection
        backup.valid = true
        backup.diagnostic = "ok"
        backup
    }

    public func restore(backup: VectorBackup): VectorStoreStatus {
        this.status(backup.collection)
    }
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
