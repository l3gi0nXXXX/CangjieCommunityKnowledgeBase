package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}
import std.process.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbVectorBootstrapRebuildTest {
    @TestCase
    public func vectorBootstrapCreatesMissingActiveAndCandidateCollections(): Unit {
        let config = qdrantRuntimeConfig()
        let store = BootstrapFakeVectorStore()

        let result = ckbVectorBootstrapWithStore(config, store)

        @Expect(result.ok, true)
        @Expect(result.activeState, EmbeddingProviderState.READY)
        @Expect(result.candidateState, EmbeddingProviderState.READY)
        @Expect(result.diagnostics.size, 2)
        @Expect(vectorTestContains(result.diagnostics, "qdrant_collection_created:active:ckb_active"), true)
        @Expect(vectorTestContains(result.diagnostics, "qdrant_collection_created:candidate:ckb_candidate"), true)
        @Expect(store.ensureCalls, 2)
    }

    @TestCase
    public func vectorBootstrapTreatsExistingQdrantCollectionsAsReady(): Unit {
        let config = qdrantRuntimeConfig()
        let store = BootstrapExistingVectorStore()

        let result = ckbVectorBootstrapWithStore(config, store)

        @Expect(result.ok, true)
        @Expect(result.activeState, EmbeddingProviderState.READY)
        @Expect(result.candidateState, EmbeddingProviderState.READY)
        @Expect(vectorTestContains(result.diagnostics, "qdrant_collection_ready:active:ckb_active"), true)
        @Expect(vectorTestContains(result.diagnostics, "qdrant_collection_ready:candidate:ckb_candidate"), true)
        @Expect(store.ensureCalls, 2)
    }

    @TestCase
    public func vectorBootstrapPreflightFailsFastWhenEmbeddingSmokeFails(): Unit {
        let config = qdrantRuntimeConfig()
        let vectorStore = BootstrapFakeVectorStore()
        let embedding = ChunkedFakeEmbeddingProvider(2, failAtCall: 1, failReason: "ollama_timeout")

        let result = ckbRoutineRuntimePreflightWithBootstrap(config, "target", "4096M", "", vectorStore, embedding)

        @Expect(result.ok, false)
        @Expect(result.vectorReadiness, EmbeddingProviderState.READY)
        @Expect(result.embeddingReadiness, EmbeddingProviderState.DOWN)
        @Expect(vectorTestContains(result.diagnostics, "ollama_timeout"), true)
        @Expect(vectorTestContains(result.diagnostics, "dyld_library_path_not_set"), true)
    }

    @TestCase
    public func httpAdminVectorBootstrapRouteReturnsStructuredEnvelope(): Unit {
        let config = CkbRuntimeConfig()
        let root = "target/ckb-vector-bootstrap-http"
        ckbVectorTestWriteFile(root, "admin.token", "admin-secret\n")
        config.serviceAdminTokenFile = "${root}/admin.token"
        let service = CkbCommandLoopService(config, FileKnowledgeStore("target/ckb-vector-bootstrap-http-store"))
        let httpConfig = ckbHttpServiceConfigFromRuntime(config)

        let response = handleCkbHttpRequest(service, "POST", "/v1/admin/vector/bootstrap", "{}", ["Authorization: Bearer admin-secret"], httpConfig)

        @Expect(response.statusCode, 200)
        @Expect(response.body.contains("\"ok\":true"), true)
        @Expect(response.body.contains("\"activeCollection\":\"active\""), true)
        @Expect(response.body.contains("vector_bootstrap_skipped_backend:local-file"), true)
    }

    @TestCase
    public func rebuildIndexEmbedsAndUpsertsVectorsInChunks(): Unit {
        let provider = ChunkedFakeEmbeddingProvider(2)
        let vectorStore = LocalVectorStore()
        let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
        kb.bootstrapOffline()

        let result = kb.rebuildIndex(false)
        let status = kb.status()
        let progress = kb.vectorBuildProgress()

        @Expect(result.ok, true)
        @Expect(provider.calls > 1, true)
        @Expect(progress.state, EmbeddingProviderState.READY)
        @Expect(progress.completed, result.count)
        @Expect(status.storage.vectorState, EmbeddingProviderState.READY)
        @Expect(status.storage.vectorIndexCount, result.count)
    }

    @TestCase
    public func ckbRebuildIndexPersistsSnapshotWithoutFullBatchEmbedding(): Unit {
        let provider = ChunkedFakeEmbeddingProvider(2)
        let kb = KnowledgeBase(FakeClock(0), provider, LocalVectorStore(), LocalGraphStore())
        kb.bootstrapOffline()
        let root = "target/ckb-vector-bootstrap-persist-store"
        ckbVectorBootstrapEnsureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        provider.resetCalls()

        let result = ckbRebuildIndex(kb, store)
        let expectedCalls = (result.count + 1) / 2

        @Expect(result.ok, true)
        @Expect(provider.calls, expectedCalls)
        @Expect(kb.lastVectorIndexBuild().vectorRecords.size, result.count)
        @Expect(store.has("index/vector-active.ckb"), true)
        let snapshot = store.loadActiveSnapshot()
        @Expect(snapshot.valid, true)
        @Expect(snapshot.vectorRecords.size, result.count)
        @Expect(snapshot.vectorRecords[0].pointId != "", true)
        @Expect(snapshot.vectorRecords[0].id, snapshot.activeIndex[0].sourceId)
    }

    @TestCase
    public func ckbRebuildIndexDoesNotPersistSnapshotWhenVectorBuildFails(): Unit {
        let provider = ChunkedFakeEmbeddingProvider(2, failReason: "ollama_timeout")
        let kb = KnowledgeBase(FakeClock(0), provider, LocalVectorStore(), LocalGraphStore())
        kb.bootstrapOffline()
        provider.resetCalls()
        provider.failAtCall = 2
        let root = "target/ckb-vector-bootstrap-persist-fail-store"
        ckbVectorBootstrapEnsureEmptyDir(root)
        let store = FileKnowledgeStore(root)

        let result = ckbRebuildIndex(kb, store)

        @Expect(result.ok, false)
        @Expect(provider.calls, 2)
        @Expect(kb.lastVectorIndexBuild().diagnostic.contains("embedding_batch_failed:batch=1:ollama_timeout"), true)
        @Expect(store.has("metadata/status.ckb"), false)
        @Expect(store.has("index/vector-active.ckb"), false)
    }

    @TestCase
    public func rebuildIndexStopsAndReportsBatchFailureWithoutThrowing(): Unit {
        let provider = ChunkedFakeEmbeddingProvider(2, failReason: "ollama_timeout")
        let kb = KnowledgeBase(FakeClock(0), provider, LocalVectorStore(), LocalGraphStore())
        kb.bootstrapOffline()
        provider.failAtCall = provider.calls + 2

        let result = kb.rebuildIndex(false)
        let status = kb.status()
        let progress = kb.vectorBuildProgress()

        @Expect(result.ok, true)
        @Expect(status.storage.vectorState, EmbeddingProviderState.DEGRADED)
        @Expect(status.storage.vectorDegradedReason.contains("embedding_batch_failed:batch=1:ollama_timeout"), true)
        @Expect(progress.state, EmbeddingProviderState.DEGRADED)
        @Expect(progress.completed, 2)
    }

    @TestCase
    public func restoreActiveSnapshotMarksRebuildRequiredWhenVectorDimensionMismatchesRuntime(): Unit {
        let source = KnowledgeBase(FakeClock(0), ChunkedFakeEmbeddingProvider(2), LocalVectorStore(), LocalGraphStore())
        source.bootstrapOffline()
        let sourceStatus = source.status()
        let snapshot = ActiveSnapshot()
        snapshot.valid = true
        snapshot.diagnostic = "ok"
        snapshot.activeVersion = sourceStatus.activeKnowledgeVersion
        snapshot.activeIndex = source.activeRecordSnapshot()
        let wrong = VectorRecord()
        wrong.id = snapshot.activeIndex[0].sourceId
        wrong.vector.add(1.0)
        wrong.vector.add(2.0)
        snapshot.vectorRecords.add(wrong)
        let vectorStore = RestoreTrackingVectorStore()
        let target = KnowledgeBase(FakeClock(0), ChunkedFakeEmbeddingProvider(2), vectorStore, LocalGraphStore())

        let restored = target.restoreActiveSnapshot(snapshot)
        let status = target.status()

        @Expect(restored, true)
        @Expect(vectorStore.restoreCalls, 0)
        @Expect(vectorStore.recreateCalls, 0)
        @Expect(vectorStore.upsertBatchCalls, 0)
        @Expect(status.storage.vectorState, EmbeddingProviderState.DEGRADED)
        @Expect(status.restoreDiagnostic.contains("vector_rebuild_required:dimension_mismatch:2:3"), true)
    }

    @TestCase
    public func restoreActiveSnapshotMarksRebuildRequiredWhenVectorArtifactMissing(): Unit {
        let source = KnowledgeBase(FakeClock(0), ChunkedFakeEmbeddingProvider(2), LocalVectorStore(), LocalGraphStore())
        source.bootstrapOffline()
        let sourceStatus = source.status()
        let snapshot = ActiveSnapshot()
        snapshot.valid = true
        snapshot.diagnostic = "ok"
        snapshot.activeVersion = sourceStatus.activeKnowledgeVersion
        snapshot.activeIndex = source.activeRecordSnapshot()
        let vectorStore = RestoreTrackingVectorStore()
        let target = KnowledgeBase(FakeClock(0), ChunkedFakeEmbeddingProvider(2), vectorStore, LocalGraphStore())

        let restored = target.restoreActiveSnapshot(snapshot)
        let status = target.status()

        @Expect(restored, true)
        @Expect(vectorStore.restoreCalls, 0)
        @Expect(vectorStore.recreateCalls, 0)
        @Expect(vectorStore.upsertBatchCalls, 0)
        @Expect(status.storage.vectorState, EmbeddingProviderState.DEGRADED)
        @Expect(status.restoreDiagnostic.contains("vector_snapshot_missing"), true)
    }
}

private class BootstrapFakeVectorStore <: VectorStore {
    private var seenStatus: ArrayList<String> = ArrayList<String>()
    public var ensureCalls: Int64 = 0

    init() {}

    public func upsert(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.readyStatus(collection)
    }

    public func upsertBatch(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        let status = this.readyStatus(collection)
        status.count = vectors.size
        status
    }

    public func search(collection: String, queryVector: ArrayList<Float64>, filters: VectorSearchFilters, topK: Int64): ArrayList<VectorSearchResult> {
        ArrayList<VectorSearchResult>()
    }

    public func status(collection: String): VectorStoreStatus {
        if (!vectorTestSeen(this.seenStatus, collection)) {
            this.seenStatus.add(collection)
            let status = this.readyStatus(collection)
            status.state = EmbeddingProviderState.DEGRADED
            status.degradedReason = "collection_missing"
            return status
        }
        this.readyStatus(collection)
    }

    public func ensureReadyCollection(collection: String): VectorStoreStatus {
        this.ensureCalls += 1
        this.readyStatus(collection)
    }

    public func clear(collection: String): VectorStoreStatus {
        this.readyStatus(collection)
    }

    public func deleteCollection(collection: String): VectorStoreStatus {
        this.readyStatus(collection)
    }

    public func recreate(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.readyStatus(collection)
    }

    public func backup(collection: String): VectorBackup {
        let backup = VectorBackup()
        backup.collection = collection
        backup.valid = true
        backup
    }

    public func restore(backup: VectorBackup): VectorStoreStatus {
        this.readyStatus(backup.collection)
    }

    private func readyStatus(collection: String): VectorStoreStatus {
        let status = VectorStoreStatus()
        status.backend = "qdrant"
        status.collection = collection
        status.activeCollection = "ckb_active"
        status.candidateCollection = "ckb_candidate"
        status.dimension = 3
        status.state = EmbeddingProviderState.READY
        status
    }
}

private class BootstrapExistingVectorStore <: VectorStore {
    public var ensureCalls: Int64 = 0

    init() {}

    public func upsert(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.readyStatus(collection)
    }

    public func upsertBatch(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        let status = this.readyStatus(collection)
        status.count = vectors.size
        status
    }

    public func search(collection: String, queryVector: ArrayList<Float64>, filters: VectorSearchFilters, topK: Int64): ArrayList<VectorSearchResult> {
        ArrayList<VectorSearchResult>()
    }

    public func status(collection: String): VectorStoreStatus {
        this.readyStatus(collection)
    }

    public func ensureReadyCollection(collection: String): VectorStoreStatus {
        this.ensureCalls += 1
        this.readyStatus(collection)
    }

    public func clear(collection: String): VectorStoreStatus {
        this.readyStatus(collection)
    }

    public func deleteCollection(collection: String): VectorStoreStatus {
        this.readyStatus(collection)
    }

    public func recreate(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.readyStatus(collection)
    }

    public func backup(collection: String): VectorBackup {
        let backup = VectorBackup()
        backup.collection = collection
        backup.valid = true
        backup
    }

    public func restore(backup: VectorBackup): VectorStoreStatus {
        this.readyStatus(backup.collection)
    }

    private func readyStatus(collection: String): VectorStoreStatus {
        let status = VectorStoreStatus()
        status.backend = "qdrant"
        status.collection = collection
        status.activeCollection = "ckb_active"
        status.candidateCollection = "ckb_candidate"
        status.dimension = 3
        status.distance = "Cosine"
        status.state = EmbeddingProviderState.READY
        status
    }
}

private class RestoreTrackingVectorStore <: VectorStore {
    public var recreateCalls: Int64 = 0
    public var restoreCalls: Int64 = 0
    public var upsertBatchCalls: Int64 = 0

    init() {}

    public func upsert(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.readyStatus(collection, vectors.size)
    }

    public func upsertBatch(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.upsertBatchCalls += 1
        this.readyStatus(collection, vectors.size)
    }

    public func search(collection: String, queryVector: ArrayList<Float64>, filters: VectorSearchFilters, topK: Int64): ArrayList<VectorSearchResult> {
        ArrayList<VectorSearchResult>()
    }

    public func status(collection: String): VectorStoreStatus {
        this.readyStatus(collection, 0)
    }

    public func ensureReadyCollection(collection: String): VectorStoreStatus {
        this.readyStatus(collection, 0)
    }

    public func clear(collection: String): VectorStoreStatus {
        this.readyStatus(collection, 0)
    }

    public func deleteCollection(collection: String): VectorStoreStatus {
        this.readyStatus(collection, 0)
    }

    public func recreate(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.recreateCalls += 1
        this.readyStatus(collection, vectors.size)
    }

    public func backup(collection: String): VectorBackup {
        let backup = VectorBackup()
        backup.collection = collection
        backup.valid = true
        backup
    }

    public func restore(backup: VectorBackup): VectorStoreStatus {
        this.restoreCalls += 1
        this.readyStatus(backup.collection, backup.records.size)
    }

    private func readyStatus(collection: String, count: Int64): VectorStoreStatus {
        let status = VectorStoreStatus()
        status.backend = "tracking"
        status.collection = collection
        status.dimension = 3
        status.count = count
        status.state = EmbeddingProviderState.READY
        status
    }
}

private class ChunkedFakeEmbeddingProvider <: EmbeddingProvider {
    private let configuredBatchSize: Int64
    private let failReason: String
    public var calls: Int64 = 0
    public var failAtCall: Int64 = -1
    public var maxRequested: Int64 = 0

    init(batchSize: Int64, failAtCall!: Int64 = -1, failReason!: String = "") {
        this.configuredBatchSize = batchSize
        this.failAtCall = failAtCall
        this.failReason = failReason
    }

    public func embed(texts: ArrayList<String>, model: String, dimensions: Int64): EmbeddingBatch {
        this.calls += 1
        if (texts.size > this.maxRequested) {
            this.maxRequested = texts.size
        }
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
        for (text in texts) {
            let vector = ArrayList<Float64>()
            vector.add(1.0)
            vector.add(2.0)
            vector.add(0.5)
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
        status.timeoutMillis = 100
        status.retryCount = 0
        status.production = true
        status.state = EmbeddingProviderState.READY
        status
    }

    public func resetCalls(): Unit {
        this.calls = 0
        this.maxRequested = 0
    }
}

private func qdrantRuntimeConfig(): CkbRuntimeConfig {
    let config = CkbRuntimeConfig()
    config.embeddingProvider = "ollama"
    config.embeddingModel = "bge-m3:latest"
    config.embeddingDimensions = 3
    config.embeddingEndpoint = "http://127.0.0.1:11434/api/embed"
    config.embeddingAllowPrivateEndpoint = true
    config.vectorBackend = "qdrant"
    config.vectorEndpoint = "http://127.0.0.1:6333"
    config.vectorActiveCollection = "ckb_active"
    config.vectorCandidateCollection = "ckb_candidate"
    config.vectorDimensions = 3
    config.vectorAllowPrivateEndpoint = true
    config
}

private func vectorTestSeen(values: ArrayList<String>, needle: String): Bool {
    for (value in values) {
        if (value == needle) {
            return true
        }
    }
    false
}

private func vectorTestContains(values: ArrayList<String>, needle: String): Bool {
    for (value in values) {
        if (value.contains(needle)) {
            return true
        }
    }
    false
}

private func ckbVectorTestWriteFile(root: String, relative: String, body: String): Unit {
    let path = Path(root).join(relative)
    if (!exists(path.parent)) {
        Directory.create(path.parent, recursive: true)
    }
    File.writeTo(path, body.toArray())
}

private func ckbVectorBootstrapEnsureEmptyDir(path: String): Unit {
    if (exists(Path(path))) {
        _ = launch("/bin/rm", ["-rf", path]).wait()
    }
    Directory.create(Path(path), recursive: true)
}
