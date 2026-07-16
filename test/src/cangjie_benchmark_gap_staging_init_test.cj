package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{File, Path}
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbBenchmarkGapStagingInitTest {
    @TestCase
    public func stagingInitUtValidatesExplicitCliAndOfflineCredentialFreeConfig(): Unit {
        @Expect(ckbBenchmarkGapStagingInitCliArgs(["cangjie-benchmark-gap-staging-init"] ).diagnostic,
            "required_argument_missing:--config")
        @Expect(ckbBenchmarkGapStagingInitCliArgs(["cangjie-benchmark-gap-staging-init", "--config", "a", "--store", "b", "--json"]).diagnostic, "ok")
        @Expect(ckbBenchmarkGapStagingInitCliArgs(["cangjie-benchmark-gap-staging-init", "--config", "a", "--config", "b", "--store", "c"]).diagnostic, "duplicate_argument:--config")
        @Expect(ckbBenchmarkGapStagingInitCliArgs(["cangjie-benchmark-gap-staging-init", "--config", "a", "--store", "b", "--unknown"]).diagnostic, "unknown_argument:--unknown")

        let config = stagingInitConfig()
        @Expect(ckbBenchmarkGapStagingConfigDiagnostic(config), "ok")
        config.networkEnabled = true
        @Expect(ckbBenchmarkGapStagingConfigDiagnostic(config), "network_must_be_disabled")
        config.networkEnabled = false; config.gitCodeTokenRef = "secret-value"
        @Expect(ckbBenchmarkGapStagingConfigDiagnostic(config), "credential_configuration_forbidden")
        config.gitCodeTokenRef = ""; config.vectorCandidateCollection = config.vectorActiveCollection
        @Expect(ckbBenchmarkGapStagingConfigDiagnostic(config), "vector_collections_must_be_unique")
        config.vectorCandidateCollection = "candidate"
        @Expect(ckbBenchmarkGapStagingConfigDiagnostic(config), "legacy_collection_forbidden")
    }

    @TestCase
    public func stagingInitBndAllowsOnlyExplicitZeroRecordSnapshotToReload(): Unit {
        let store = FileKnowledgeStore(stagingInitRoot("zero"))
        let status = KnowledgeStatus()
        status.activeKnowledgeVersion = "ckb-benchmark-gap-staging-empty-v1"
        status.activeStateSource = "benchmark_gap_staging_init"
        status.storage.vectorBackend = "qdrant"
        status.storage.vectorState = EmbeddingProviderState.READY
        status.storage.vectorActiveCollection = "ckb_humaneval_staging_active_20260717"
        status.storage.vectorCandidateCollection = "ckb_humaneval_staging_candidate_20260717"
        let transaction = store.writeActiveSnapshotTransaction(status,
            ArrayList<RawRecord>(), ArrayList<NormalizedRecord>(),
            ArrayList<NormalizedRecord>(), ArrayList<VectorRecord>(),
            status.storage.vectorActiveCollection, GraphBuildResult())

        @Expect(transaction.ok, true)
        let reloaded = store.loadActiveSnapshot()
        @Expect(reloaded.valid, true)
        @Expect(reloaded.activeIndex.size, 0)
        @Expect(reloaded.activeStateSource, "benchmark_gap_staging_init")
    }

    @TestCase
    public func stagingInitPosCreatesCollectionsCommitsAndReloadsZeroCounts(): Unit {
        let config = stagingInitConfig()
        let vectorStore = LocalVectorStore()
        let store = FileKnowledgeStore(stagingInitRoot("positive-中文-emoji"))
        let result = ckbBenchmarkGapStagingInit(config, store, vectorStore)

        @Expect(result.ok, true)
        @Expect(result.status, "initialized")
        @Expect(result.rawCount, 0)
        @Expect(result.indexCount, 0)
        @Expect(result.vectorCount, 0)
        @Expect(store.loadActiveSnapshotPointer().valid, true)
        @Expect(store.loadActiveSnapshot().valid, true)
        @Expect(vectorStore.status(config.vectorActiveCollection).count, 0)
        @Expect(vectorStore.status(config.vectorCandidateCollection).count, 0)
    }

    @TestCase
    public func stagingInitNegRejectsNonemptyStorePointerAndCollections(): Unit {
        let config = stagingInitConfig()
        let nonempty = FileKnowledgeStore(stagingInitRoot("nonempty"))
        nonempty.writeLinesAtomically("metadata/user.ckb", "do-not-replace\n")
        @Expect(ckbBenchmarkGapStagingInit(config, nonempty, LocalVectorStore()).diagnostic,
            "store_not_empty")

        let initializedStore = FileKnowledgeStore(stagingInitRoot("pointer"))
        let initializedVectors = LocalVectorStore()
        @Expect(ckbBenchmarkGapStagingInit(config, initializedStore, initializedVectors).ok, true)
        @Expect(ckbBenchmarkGapStagingInit(config, initializedStore, initializedVectors).diagnostic,
            "authoritative_active_pointer_present")

        let occupiedVectors = LocalVectorStore()
        _ = occupiedVectors.ensureReadyCollection(config.vectorActiveCollection)
        let vector = VectorRecord(); vector.id = "occupied"; vector.vector.add(1.0)
        let vectors = ArrayList<VectorRecord>(); vectors.add(vector)
        _ = occupiedVectors.upsert(config.vectorActiveCollection, vectors)
        @Expect(ckbBenchmarkGapStagingInit(config, FileKnowledgeStore(stagingInitRoot("occupied")), occupiedVectors).diagnostic,
            "active_collection_not_empty")

        let cleanupExecutor = StagingInitQdrantFailureExecutor(false)
        let cleanupVectors = QdrantVectorStore("http://qdrant.staging.test", 16,
            "Cosine", executor: cleanupExecutor)
        let cleanupStore = FileKnowledgeStore(stagingInitRoot("cleanup"))
        let cleanupResult = ckbBenchmarkGapStagingInit(config, cleanupStore, cleanupVectors)
        @Expect(cleanupResult.diagnostic, "candidate_create_collection_unavailable")
        @Expect(cleanupExecutor.activeCreateCalls, 1)
        @Expect(cleanupExecutor.candidateCreateCalls, 1)
        @Expect(cleanupExecutor.activeDeleteCalls, 1)
        @Expect(cleanupExecutor.originalActiveDeleted, false)
        @Expect(cleanupStore.has("metadata/active-snapshot.manifest"), false)
        @Expect(cleanupStore.has("transactions"), false)

        let existingExecutor = StagingInitQdrantFailureExecutor(true)
        let existingVectors = QdrantVectorStore("http://qdrant.staging.test", 16,
            "Cosine", executor: existingExecutor)
        let existingStore = FileKnowledgeStore(stagingInitRoot("cleanup-existing"))
        let existingResult = ckbBenchmarkGapStagingInit(config, existingStore, existingVectors)
        @Expect(existingResult.diagnostic, "candidate_create_collection_unavailable")
        @Expect(existingExecutor.activeCreateCalls, 0)
        @Expect(existingExecutor.candidateCreateCalls, 1)
        @Expect(existingExecutor.activeDeleteCalls, 0)
        @Expect(existingExecutor.originalActiveDeleted, false)
        @Expect(existingStore.has("metadata/active-snapshot.manifest"), false)
        @Expect(existingStore.has("transactions"), false)
    }

    @TestCase
    public func stagingInitNegRejectsUncommittedTamperedAndPseudoEmptySnapshots(): Unit {
        let pseudo = FileKnowledgeStore(stagingInitRoot("pseudo"))
        pseudo.writeLinesAtomically("index/active.version", "pseudo-empty\n")
        pseudo.writeLinesAtomically("index/active.ckb", "")
        pseudo.writeLinesAtomically("metadata/status.ckb", "active=pseudo-empty\nactiveStateSource=benchmark_gap_staging_init\nrawCount=0\nnormalizedCount=0\nindexCount=0\nvectorIndexCount=0\n")
        @Expect(pseudo.loadActiveSnapshot().valid, false)

        let uncommitted = FileKnowledgeStore(stagingInitRoot("uncommitted"))
        uncommitted.writeLinesAtomically("metadata/active-snapshot.manifest", "schema=ckb-active-pointer-v2\ntxId=missing\nactive=empty\nvectorActiveCollection=staging_active\ncommitted=true\n")
        @Expect(uncommitted.loadActiveSnapshot().valid, false)

        let committed = FileKnowledgeStore(stagingInitRoot("tampered"))
        let vectors = LocalVectorStore()
        @Expect(ckbBenchmarkGapStagingInit(stagingInitConfig(), committed, vectors).ok, true)
        let manifest = committed.readText("metadata/active-snapshot.manifest")
        committed.writeLinesAtomically("metadata/active-snapshot.manifest",
            manifest.replace("ckb-benchmark-gap-staging-empty-v1", "wrong-version"))
        @Expect(committed.loadActiveSnapshot().valid, false)

        let collectionMismatch = FileKnowledgeStore(stagingInitRoot("collection-mismatch"))
        @Expect(ckbBenchmarkGapStagingInit(stagingInitConfig(), collectionMismatch,
            LocalVectorStore()).ok, true)
        let collectionManifest = collectionMismatch.readText("metadata/active-snapshot.manifest")
        collectionMismatch.writeLinesAtomically("metadata/active-snapshot.manifest",
            collectionManifest.replace("ckb_humaneval_staging_active_20260717",
                "ckb_humaneval_staging_active_wrong"))
        @Expect(collectionMismatch.loadActiveSnapshot().valid, false)
    }

    @TestCase
    public func stagingInitBndRejectsEmptyIndexWithNonzeroPersistedCountsAndKeepsNonemptyHistory(): Unit {
        let invalidStore = FileKnowledgeStore(stagingInitRoot("empty-mismatch"))
        let status = KnowledgeStatus(); status.activeKnowledgeVersion = "invalid-empty"
        status.storage.rawCount = 1; status.storage.vectorActiveCollection = "staging_active_mismatch"
        status.storage.vectorCandidateCollection = "staging_candidate_mismatch"
        let invalidRaw = RawRecord(); invalidRaw.sourceId = "orphan-raw"; invalidRaw.title = "orphan"
        invalidRaw.content = "raw without an active index"; invalidRaw.metadata.sourceId = invalidRaw.sourceId
        invalidRaw.metadata.sourceType = SourceTypes.DOC; invalidRaw.contentHash = benchmarkGapSha256(invalidRaw.content)
        let invalidRawRecords = ArrayList<RawRecord>(); invalidRawRecords.add(invalidRaw)
        let tx = invalidStore.writeActiveSnapshotTransaction(status, invalidRawRecords,
            ArrayList<NormalizedRecord>(), ArrayList<NormalizedRecord>(), ArrayList<VectorRecord>(),
            status.storage.vectorActiveCollection, GraphBuildResult())
        @Expect(tx.ok, true)
        @Expect(invalidStore.loadActiveSnapshot().valid, false)
        @Expect(invalidStore.loadActiveSnapshot().diagnostic,
            "active_snapshot_v2_payload_identity_mismatch")

        let vectorStore = FileKnowledgeStore(stagingInitRoot("empty-vector-mismatch"))
        let vectorStatus = KnowledgeStatus(); vectorStatus.activeKnowledgeVersion = "invalid-vector-empty"
        vectorStatus.storage.vectorIndexCount = 1
        vectorStatus.storage.vectorActiveCollection = "staging_active_vector_mismatch"
        vectorStatus.storage.vectorCandidateCollection = "staging_candidate_vector_mismatch"
        let orphanVector = VectorRecord(); orphanVector.id = "orphan-vector"; orphanVector.vector.add(1.0)
        let orphanVectors = ArrayList<VectorRecord>(); orphanVectors.add(orphanVector)
        let vectorTx = vectorStore.writeActiveSnapshotTransaction(vectorStatus, ArrayList<RawRecord>(),
            ArrayList<NormalizedRecord>(), ArrayList<NormalizedRecord>(), orphanVectors,
            vectorStatus.storage.vectorActiveCollection, GraphBuildResult())
        @Expect(vectorTx.ok, true)
        @Expect(vectorStore.loadActiveSnapshot().valid, false)

        let historical = newOfflineKnowledgeBase()
        let historicalSnapshot = historical.activeSnapshotForRollback()
        let historicalStore = FileKnowledgeStore(stagingInitRoot("historical"))
        let historicalTx = historicalStore.writeActiveSnapshotTransaction(historical.status(),
            historicalSnapshot.rawRecords, historicalSnapshot.normalizedRecords,
            historicalSnapshot.activeIndex, ArrayList<VectorRecord>(),
            historical.status().storage.vectorActiveCollection, historical.activeGraphBuild(),
            persistVectorFile: false)
        @Expect(historicalTx.ok, true)
        @Expect(historicalStore.loadActiveSnapshot().valid, true)
        @Expect(historicalStore.loadActiveSnapshot().activeIndex.size > 0, true)
    }

    @TestCase
    public func stagingInitBndConfigEncodingAndHumanOutputStaySafe(): Unit {
        let root = stagingInitRoot("config")
        let invalid = Path("${root}-invalid.conf")
        File.writeTo(invalid, [UInt8(0xff), UInt8(0xfe)])
        @Expect(ckbBenchmarkGapStagingRawConfigDiagnostic(invalid.toString()),
            "invalid_config_encoding")
        let malformed = Path("${root}-malformed.conf")
        File.writeTo(malformed, "network.enabled=false\nmalformed🙂\n".toArray())
        @Expect(ckbBenchmarkGapStagingRawConfigDiagnostic(malformed.toString()), "malformed_config")
        let secret = Path("${root}-secret.conf")
        File.writeTo(secret, "network.enabled=false\ncustom.secret=private-value\n".toArray())
        @Expect(ckbBenchmarkGapStagingRawConfigDiagnostic(secret.toString()),
            "credential_configuration_forbidden")

        let result = CkbBenchmarkGapStagingInitResult(); result.ok = true; result.status = "initialized"
        result.diagnostic = "ok"; result.activeCollection = "staging_仓颉🙂"; result.candidateCollection = "candidate"
        let human = renderCkbBenchmarkGapStagingInitText(result)
        @Expect(human.contains("\"ok\""), false)
        @Expect(human.contains("\"result\""), false)
        @Expect(human.contains("\"status\""), false)
        @Expect(renderCkbBenchmarkGapStagingInitJson(result).contains("\"ok\":true"), true)
    }
}

private class StagingInitQdrantFailureExecutor <: HttpRequestExecutor {
    private let activeInitiallyExists: Bool
    private var activeCreated: Bool = false
    public var activeCreateCalls: Int64 = 0
    public var candidateCreateCalls: Int64 = 0
    public var activeDeleteCalls: Int64 = 0
    public var originalActiveDeleted: Bool = false

    public init(activeInitiallyExists: Bool) { this.activeInitiallyExists = activeInitiallyExists }

    public func execute(request: HttpExecutionRequest): HttpExecutionResponse {
        let response = HttpExecutionResponse()
        let active = request.url.contains("/collections/ckb_humaneval_staging_active_20260717")
        let candidate = request.url.contains("/collections/ckb_humaneval_staging_candidate_20260717")
        if (request.method == "GET" && active) {
            if (this.activeInitiallyExists || this.activeCreated) {
                response.statusCode = 200; response.status = "http_200"
                response.body = "{\"status\":\"ok\",\"result\":{\"status\":\"green\",\"points_count\":0,\"config\":{\"params\":{\"vectors\":{\"size\":16,\"distance\":\"Cosine\"}}}}}"
            } else { response.statusCode = 404; response.status = "http_404"; response.body = "{\"status\":\"error\"}" }
            return response
        }
        if (request.method == "GET" && candidate) {
            response.statusCode = 404; response.status = "http_404"; response.body = "{\"status\":\"error\"}"
            return response
        }
        if (request.method == "PUT" && active) {
            this.activeCreateCalls += 1; this.activeCreated = true
            response.statusCode = 200; response.status = "http_200"; response.body = "{\"status\":\"ok\",\"result\":true}"
            return response
        }
        if (request.method == "PUT" && candidate) {
            this.candidateCreateCalls += 1
            response.statusCode = 503; response.status = "transport_error"
            response.transportErrorClass = "connection_refused"; response.transportDiagnostic = "connection_refused"
            response.body = "{\"status\":\"error\"}"
            return response
        }
        if (request.method == "DELETE" && active) {
            this.activeDeleteCalls += 1
            if (this.activeInitiallyExists) { this.originalActiveDeleted = true }
            this.activeCreated = false
            response.statusCode = 200; response.status = "http_200"; response.body = "{\"status\":\"ok\",\"result\":true}"
            return response
        }
        response.statusCode = 500; response.status = "http_500"; response.body = "{\"status\":\"error\"}"
        response
    }

    public func get(request: HttpExecutionRequest): HttpExecutionResponse { this.execute(request) }
}

private func stagingInitConfig(): CkbRuntimeConfig {
    let config = CkbRuntimeConfig()
    config.networkEnabled = false
    config.vectorBackend = "qdrant"
    config.vectorActiveCollection = "ckb_humaneval_staging_active_20260717"
    config.vectorCandidateCollection = "ckb_humaneval_staging_candidate_20260717"
    config
}

private func stagingInitRoot(label: String): String {
    "target/staging-init-${label}-${ckbCoreNowMillis()}"
}
