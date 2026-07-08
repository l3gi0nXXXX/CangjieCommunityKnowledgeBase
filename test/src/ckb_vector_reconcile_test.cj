package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}
import std.process.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbVectorReconcileTest {
    @TestCase
    public func derivedVectorCleanupDryRunDoesNotDeleteArtifacts(): Unit {
        let root = "target/ckb-vector-cleanup-dry-run"
        ckbVectorReconcileEnsureEmptyDir(root)
        ckbVectorReconcileWriteFile(root, "index/active.ckb", "active-record\n")
        ckbVectorReconcileWriteFile(root, "index/active.version", "ckb-active\n")
        ckbVectorReconcileWriteFile(root, "raw/records.ckb", "raw-record\n")
        ckbVectorReconcileWriteFile(root, "normalized/records.ckb", "normalized-record\n")
        ckbVectorReconcileWriteFile(root, "metadata/status.ckb", "active=ckb-active\n")
        ckbVectorReconcileWriteFile(root, "index/vector-ckb_active.ckb", "vector-active\n")
        ckbVectorReconcileWriteFile(root, "index/vector-ckb_candidate.ckb", "vector-candidate\n")
        let store = FileKnowledgeStore(root)

        let result = store.deleteAllDerivedVectorArtifacts("ckb_active", "ckb_candidate")

        @Expect(result.ok, true)
        @Expect(result.dryRun, true)
        @Expect(result.deletedFiles.size, 0)
        @Expect(ckbVectorReconcileContains(result.plannedFiles, "index/vector-ckb_active.ckb"), true)
        @Expect(ckbVectorReconcileContains(result.plannedFiles, "index/vector-ckb_candidate.ckb"), true)
        @Expect(store.has("index/vector-ckb_active.ckb"), true)
        @Expect(store.has("index/vector-ckb_candidate.ckb"), true)
        @Expect(store.has("index/active.ckb"), true)
        @Expect(store.has("raw/records.ckb"), true)
    }

    @TestCase
    public func derivedVectorCleanupForceDeletesOnlyVectorArtifacts(): Unit {
        let root = "target/ckb-vector-cleanup-force"
        ckbVectorReconcileEnsureEmptyDir(root)
        ckbVectorReconcileWriteFile(root, "index/active.ckb", "active-record\n")
        ckbVectorReconcileWriteFile(root, "index/active.version", "ckb-active\n")
        ckbVectorReconcileWriteFile(root, "raw/records.ckb", "raw-record\n")
        ckbVectorReconcileWriteFile(root, "normalized/records.ckb", "normalized-record\n")
        ckbVectorReconcileWriteFile(root, "metadata/status.ckb", "active=ckb-active\n")
        ckbVectorReconcileWriteFile(root, "index/vector-ckb_active.ckb", "vector-active\n")
        ckbVectorReconcileWriteFile(root, "index/vector-ckb_candidate.ckb", "vector-candidate\n")
        let store = FileKnowledgeStore(root)

        let result = store.deleteAllDerivedVectorArtifacts("ckb_active", "ckb_candidate", force: true)

        @Expect(result.ok, true)
        @Expect(result.dryRun, false)
        @Expect(ckbVectorReconcileContains(result.deletedFiles, "index/vector-ckb_active.ckb"), true)
        @Expect(ckbVectorReconcileContains(result.deletedFiles, "index/vector-ckb_candidate.ckb"), true)
        @Expect(store.has("index/vector-ckb_active.ckb"), false)
        @Expect(store.has("index/vector-ckb_candidate.ckb"), false)
        @Expect(store.has("index/active.ckb"), true)
        @Expect(store.has("index/active.version"), true)
        @Expect(store.has("raw/records.ckb"), true)
        @Expect(store.has("normalized/records.ckb"), true)
        @Expect(store.has("metadata/status.ckb"), true)
    }

    @TestCase
    public func derivedVectorCleanupEmptyArtifactsIsOk(): Unit {
        let root = "target/ckb-vector-cleanup-empty"
        ckbVectorReconcileEnsureEmptyDir(root)
        ckbVectorReconcileWriteFile(root, "index/active.ckb", "active-record\n")
        let store = FileKnowledgeStore(root)

        let result = store.deleteAllDerivedVectorArtifacts("ckb_active", "ckb_candidate", force: true)

        @Expect(result.ok, true)
        @Expect(result.deletedFiles.size, 0)
        @Expect(ckbVectorReconcileContains(result.diagnostics, "no_derived_vector_artifacts"), true)
        @Expect(store.has("index/active.ckb"), true)
    }

    @TestCase
    public func vectorReconcileDryRunReportsPlannedWithoutRebuild(): Unit {
        let root = "target/ckb-vector-reconcile-dry-run"
        ckbVectorReconcileEnsureEmptyDir(root)
        ckbVectorReconcileWriteFile(root, "index/vector-ckb_active.ckb", "old-vector\n")
        let store = FileKnowledgeStore(root)
        let vectorStore = ReconcileTrackingVectorStore(initialCount: 1)
        let kb = ckbVectorReconcileKnowledgeBase(vectorStore)
        let activeRecords = kb.status().storage.indexCount
        let beforeRecreateCalls = vectorStore.recreateCalls
        let beforeUpsertBatchCalls = vectorStore.upsertBatchCalls

        let result = ckbVectorReconcileWithVectorStore(kb, store, ckbVectorReconcileRuntimeConfig(), vectorStore, false)

        @Expect(result.ok, true)
        @Expect(result.dryRun, true)
        @Expect(result.activeRecords, activeRecords)
        @Expect(ckbVectorReconcileContains(result.plannedVectorArtifacts, "index/vector-ckb_active.ckb"), true)
        @Expect(ckbVectorReconcileContains(result.diagnostics, "dry_run"), true)
        @Expect(vectorStore.recreateCalls, beforeRecreateCalls)
        @Expect(vectorStore.upsertBatchCalls, beforeUpsertBatchCalls)
        @Expect(store.has("index/vector-ckb_active.ckb"), true)
    }

    @TestCase
    public func vectorReconcileForceDeletesDerivedArtifactsAndRebuildsVectors(): Unit {
        let root = "target/ckb-vector-reconcile-force"
        ckbVectorReconcileEnsureEmptyDir(root)
        ckbVectorReconcileWriteFile(root, "index/vector-ckb_active.ckb", "old-vector\n")
        let store = FileKnowledgeStore(root)
        let vectorStore = ReconcileTrackingVectorStore(initialCount: 1)
        let provider = ReconcileEmbeddingProvider(batchSize: 2)
        let kb = ckbVectorReconcileKnowledgeBaseWithProvider(vectorStore, provider)
        let activeRecords = kb.status().storage.indexCount
        let beforeRecreateCalls = vectorStore.recreateCalls
        let beforeUpsertBatchCalls = vectorStore.upsertBatchCalls
        provider.resetCalls()

        let result = ckbVectorReconcileWithVectorStore(kb, store, ckbVectorReconcileRuntimeConfig(), vectorStore, true)
        let expectedCalls = (activeRecords + 1) / 2

        @Expect(result.ok, true)
        @Expect(result.dryRun, false)
        @Expect(result.activeRecords, activeRecords)
        @Expect(result.rebuiltVectorCount, activeRecords)
        @Expect(result.qdrantAfterCount, activeRecords)
        @Expect(ckbVectorReconcileContains(result.deletedVectorArtifacts, "index/vector-ckb_active.ckb"), true)
        @Expect(vectorStore.recreateCalls, beforeRecreateCalls + 1)
        @Expect(vectorStore.upsertBatchCalls > beforeUpsertBatchCalls, true)
        @Expect(provider.calls, expectedCalls)
        @Expect(store.has("index/vector-ckb_active.ckb"), true)
        @Expect(store.has("index/active.ckb"), true)
        @Expect(store.has("raw/records.ckb"), true)
        @Expect(store.has("metadata/status.ckb"), true)
    }

    @TestCase
    public func vectorReconcileFailsWhenQdrantCountDoesNotMatchRebuiltRecords(): Unit {
        let root = "target/ckb-vector-reconcile-count-mismatch"
        ckbVectorReconcileEnsureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let vectorStore = ReconcileTrackingVectorStore()
        vectorStore.reportCountMismatchAfterRebuild = true
        let kb = ckbVectorReconcileKnowledgeBase(vectorStore)

        let result = ckbVectorReconcileWithVectorStore(kb, store, ckbVectorReconcileRuntimeConfig(), vectorStore, true)

        @Expect(result.ok, false)
        @Expect(ckbVectorReconcileContainsPrefix(result.diagnostics, "qdrant_point_count_mismatch:"), true)
        @Expect(result.qdrantAfterCount < result.rebuiltVectorCount, true)
    }

    @TestCase
    public func vectorReconcileFailsWhenVectorStoreRejectsRebuildBatch(): Unit {
        let root = "target/ckb-vector-reconcile-upsert-failure"
        ckbVectorReconcileEnsureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let vectorStore = ReconcileTrackingVectorStore()
        vectorStore.failUpsertBatch = true
        let kb = ckbVectorReconcileKnowledgeBase(vectorStore)

        let result = ckbVectorReconcileWithVectorStore(kb, store, ckbVectorReconcileRuntimeConfig(), vectorStore, true)

        @Expect(result.ok, false)
        @Expect(ckbVectorReconcileContainsPrefix(result.diagnostics, "vector_store_not_ready:"), true)
        @Expect(result.vectorState, EmbeddingProviderState.DEGRADED)
    }

    @TestCase
    public func httpAdminVectorCleanupRouteDeletesDerivedArtifactsOnlyWithForce(): Unit {
        let root = "target/ckb-vector-cleanup-http"
        let storeRoot = "target/ckb-vector-cleanup-http-store"
        ckbVectorReconcileEnsureEmptyDir(root)
        ckbVectorReconcileEnsureEmptyDir(storeRoot)
        ckbVectorReconcileWriteFile(root, "admin.token", "admin-secret\n")
        ckbVectorReconcileWriteFile(storeRoot, "index/active.ckb", "active-record\n")
        ckbVectorReconcileWriteFile(storeRoot, "index/vector-active.ckb", "old-vector\n")
        let config = CkbRuntimeConfig()
        config.serviceAdminTokenFile = "${root}/admin.token"
        let store = FileKnowledgeStore(storeRoot)
        let service = CkbCommandLoopService(config, store)
        let httpConfig = ckbHttpServiceConfigFromRuntime(config)

        let response = handleCkbHttpRequest(service, "POST", "/v1/admin/vector/clean-derived", "{\"force\":true}", ["Authorization: Bearer admin-secret"], httpConfig)

        @Expect(response.statusCode, 200)
        @Expect(response.body.contains("\"ok\":true"), true)
        @Expect(response.body.contains("\"deletedFiles\""), true)
        @Expect(store.has("index/vector-active.ckb"), false)
        @Expect(store.has("index/active.ckb"), true)
    }

    @TestCase
    public func httpAdminVectorReconcileRouteReturnsDryRunEnvelope(): Unit {
        let root = "target/ckb-vector-reconcile-http"
        let storeRoot = "target/ckb-vector-reconcile-http-store"
        ckbVectorReconcileEnsureEmptyDir(root)
        ckbVectorReconcileEnsureEmptyDir(storeRoot)
        ckbVectorReconcileWriteFile(root, "admin.token", "admin-secret\n")
        let config = CkbRuntimeConfig()
        config.serviceAdminTokenFile = "${root}/admin.token"
        let service = CkbCommandLoopService(config, FileKnowledgeStore(storeRoot))
        let httpConfig = ckbHttpServiceConfigFromRuntime(config)

        let response = handleCkbHttpRequest(service, "POST", "/v1/admin/vector/reconcile", "{}", ["Authorization: Bearer admin-secret"], httpConfig)

        @Expect(response.statusCode, 200)
        @Expect(response.body.contains("\"ok\":true"), true)
        @Expect(response.body.contains("\"dryRun\":true"), true)
        @Expect(response.body.contains("\"activeRecords\":"), true)
        @Expect(response.body.contains("\"diagnostics\""), true)
    }
}

private class ReconcileEmbeddingProvider <: EmbeddingProvider {
    private let configuredBatchSize: Int64
    public var calls: Int64 = 0

    public init(batchSize!: Int64 = 2) {
        this.configuredBatchSize = batchSize
    }

    public func embed(texts: ArrayList<String>, model: String, dimensions: Int64): EmbeddingBatch {
        this.calls += 1
        let batch = EmbeddingBatch()
        batch.requested = texts.size
        batch.batchSize = this.configuredBatchSize
        batch.status = this.status()
        for (text in texts) {
            let vector = ArrayList<Float64>()
            vector.add(1.0)
            vector.add(2.0)
            vector.add(3.0)
            batch.vectors.add(vector)
        }
        batch.succeeded = texts.size
        batch
    }

    public func status(): EmbeddingStatus {
        let status = EmbeddingStatus()
        status.provider = "ollama"
        status.model = "bge-m3:latest"
        status.dimensions = 3
        status.endpointConfigured = true
        status.batchSize = this.configuredBatchSize
        status.maxBatchBytes = 65536
        status.maxTextBytes = 8192
        status.timeoutMillis = 100
        status.retryCount = 0
        status.production = true
        status.state = EmbeddingProviderState.READY
        status
    }

    public func resetCalls(): Unit {
        this.calls = 0
    }
}

private class ReconcileTrackingVectorStore <: VectorStore {
    public var recreateCalls: Int64 = 0
    public var upsertBatchCalls: Int64 = 0
    public var failUpsertBatch: Bool = false
    public var reportCountMismatchAfterRebuild: Bool = false
    private var storedCount: Int64 = 0
    private var state: String = EmbeddingProviderState.READY
    private var diagnostic: String = ""

    public init(initialCount!: Int64 = 0) {
        this.storedCount = initialCount
    }

    public func upsert(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.upsertBatch(collection, vectors)
    }

    public func upsertBatch(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.upsertBatchCalls += 1
        if (this.failUpsertBatch) {
            this.state = EmbeddingProviderState.DEGRADED
            this.diagnostic = "upsert_failed"
            return this.status(collection)
        }
        this.storedCount += vectors.size
        this.status(collection)
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
        status.state = this.state
        status.degradedReason = this.diagnostic
        status.count = this.storedCount
        if (this.reportCountMismatchAfterRebuild && this.upsertBatchCalls > 0 && status.count > 0) {
            status.count -= 1
        }
        status
    }

    public func ensureReadyCollection(collection: String): VectorStoreStatus {
        this.status(collection)
    }

    public func clear(collection: String): VectorStoreStatus {
        this.storedCount = 0
        this.state = EmbeddingProviderState.READY
        this.diagnostic = ""
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

private func ckbVectorReconcileKnowledgeBase(vectorStore: ReconcileTrackingVectorStore): KnowledgeBase {
    let kb = KnowledgeBase(FakeClock(0), ReconcileEmbeddingProvider(), vectorStore, LocalGraphStore())
    kb.configureVectorCollections("ckb_active", "ckb_candidate")
    kb.bootstrapOffline()
    kb
}

private func ckbVectorReconcileKnowledgeBaseWithProvider(vectorStore: ReconcileTrackingVectorStore, provider: ReconcileEmbeddingProvider): KnowledgeBase {
    let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
    kb.configureVectorCollections("ckb_active", "ckb_candidate")
    kb.bootstrapOffline()
    kb
}

private func ckbVectorReconcileRuntimeConfig(): CkbRuntimeConfig {
    let config = CkbRuntimeConfig()
    config.embeddingProvider = "ollama"
    config.embeddingModel = "bge-m3:latest"
    config.embeddingDimensions = 3
    config.embeddingEndpoint = "http://127.0.0.1:11434/api/embed"
    config.embeddingAllowPrivateEndpoint = true
    config.embeddingBatchSize = 2
    config.vectorBackend = "qdrant"
    config.vectorEndpoint = "http://127.0.0.1:6333"
    config.vectorActiveCollection = "ckb_active"
    config.vectorCandidateCollection = "ckb_candidate"
    config.vectorDimensions = 3
    config.vectorDistance = "Cosine"
    config.vectorAllowPrivateEndpoint = true
    config
}

private func ckbVectorReconcileEnsureEmptyDir(path: String): Unit {
    if (exists(Path(path))) {
        _ = launch("/bin/rm", ["-rf", path]).wait()
    }
    Directory.create(Path(path), recursive: true)
}

private func ckbVectorReconcileWriteFile(root: String, relative: String, body: String): Unit {
    let path = Path(root).join(relative)
    if (!exists(path.parent)) {
        Directory.create(path.parent, recursive: true)
    }
    File.writeTo(path, body.toArray())
}

private func ckbVectorReconcileContains(values: ArrayList<String>, needle: String): Bool {
    for (value in values) {
        if (value == needle || value.contains(needle)) {
            return true
        }
    }
    false
}

private func ckbVectorReconcileContainsPrefix(values: ArrayList<String>, prefix: String): Bool {
    for (value in values) {
        if (value.startsWith(prefix)) {
            return true
        }
    }
    false
}
