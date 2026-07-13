package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}
import std.process.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbRoutineUpdateE2ETest {
    @TestCase
    public func p5E2E01VectorReconcileSchedulerReloadAndLandingAcceptancePass(): Unit {
        let root = "target/ckb-routine-update-e2e-ok"
        p5EnsureEmptyDir(root)
        p5WriteBenchmarkGapInput(root)
        let config = p5RuntimeConfig(root)
        let store = FileKnowledgeStore("${root}/store")
        let provider = P5FakeEmbeddingProvider(2)
        let vectorStore = P5FakeQdrantStore("ckb_active", "ckb_candidate")
        let kb = p5SingleRecordKnowledgeBase(provider, vectorStore)
        let initialRebuild = ckbRebuildIndex(kb, store)
        store.saveCangjieVersionManifest(p5E2EVersionManifest())
        provider.resetCalls()

        let reconcile = ckbVectorReconcileWithVectorStore(kb, store, config, vectorStore, true)
        let preflight = ckbRoutineRuntimePreflightWithBootstrap(config, "${root}/store", "4096M", "/opt/homebrew/opt/openssl@3/lib", vectorStore, provider)
        let executor = SchedulerExecutor(kb.scheduler, CkbSchedulerTaskRunner(kb, config, store, sourceRunner: FakeSourceFetchRunner()), FileSchedulerProgressSink(store), 300000)
        let schedulerTaskNames = p5RepresentativeForceAllTaskNames()
        let scheduler = executor.runTaskNames(schedulerTaskNames, force: true)
        store.saveScheduler(kb.scheduler.entries)
        let reloaded = newKnowledgeBaseFromStore(store)
        let reloadedStatus = cangjie_knowledge_status(reloaded.kb)
        let metadata = store.loadMetadataStatus()
        let qdrant = vectorStore.status(metadata.vectorActiveCollection)
        p5WriteRoutineAcceptanceArtifacts(root, reconcile, scheduler, reloaded.source, reloaded.diagnostic, qdrant.count, reloadedStatus.storage.indexCount)
        let acceptanceMatrix = String.fromUtf8(File.readFrom(Path(root).join("routine-update-acceptance-matrix.jsonl")))

        @Expect(initialRebuild.ok, true)
        @Expect(reconcile.ok, true)
        @Expect(reconcile.progressPath != "", true)
        @Expect(store.has(reconcile.progressPath), true)
        @Expect(preflight.ok, true)
        @Expect(p5AllTasksAllowed(schedulerTaskNames), true)
        @Expect(scheduler.failed, 1)
        @Expect(scheduler.degraded, 0)
        @Expect(scheduler.details.contains("benchmark_gap_proof_complete"), true)
        @Expect(reloaded.source, "persisted")
        @Expect(reloaded.diagnostic, "ok")
        @Expect(qdrant.count, reloadedStatus.storage.indexCount)
        @Expect(qdrant.count > 0, true)
        @Expect(acceptanceMatrix.contains("\"acceptance\":\"vector_reconcile_completed\",\"status\":\"passed\""), true)
        @Expect(acceptanceMatrix.contains("\"acceptance\":\"qdrant_count_matches_active_index\",\"status\":\"passed\""), true)
        @Expect(acceptanceMatrix.contains("\"acceptance\":\"no_metadata_active_mismatch\",\"status\":\"passed\""), true)
        @Expect(acceptanceMatrix.contains("\"acceptance\":\"no_offline_baseline_after_reload\",\"status\":\"passed\""), true)
    }

    @TestCase
    public func p5E2E02OllamaBatchFailureKeepsOldActiveAndWritesProgress(): Unit {
        let root = "target/ckb-routine-update-e2e-ollama-fail"
        p5EnsureEmptyDir(root)
        let config = p5RuntimeConfig(root)
        let store = FileKnowledgeStore("${root}/store")
        let provider = P5FakeEmbeddingProvider(2)
        let vectorStore = P5FakeQdrantStore("ckb_active", "ckb_candidate")
        let kb = p5OfflineKnowledgeBase(provider, vectorStore)
        let initial = ckbRebuildIndex(kb, store)
        let oldActiveCount = vectorStore.status("ckb_active").count
        provider.resetCalls()
        provider.failAtCall = 1

        let reconcile = ckbVectorReconcileWithVectorStore(kb, store, config, vectorStore, true)
        let reloaded = newKnowledgeBaseFromStore(store)
        let reloadedStatus = cangjie_knowledge_status(reloaded.kb)

        @Expect(initial.ok, true)
        @Expect(reconcile.ok, false)
        @Expect(reconcile.progressPath != "", true)
        @Expect(store.has(reconcile.progressPath), true)
        @Expect(p5Contains(reconcile.diagnostics, "rebuild_failed"), true)
        @Expect(vectorStore.status("ckb_active").count, oldActiveCount)
        @Expect(reloaded.source, "persisted")
        @Expect(reloadedStatus.storage.indexCount, oldActiveCount)
    }

    @TestCase
    public func p5E2E03ZeroAndSingleRecordVectorBoundariesAreStable(): Unit {
        let emptyProvider = P5FakeEmbeddingProvider(2)
        let emptyVectorStore = P5FakeQdrantStore("ckb_active", "ckb_candidate")
        let emptyKb = KnowledgeBase(FakeClock(0), emptyProvider, emptyVectorStore, LocalGraphStore())
        emptyKb.configureVectorCollections("ckb_active", "ckb_candidate")

        let empty = emptyKb.rebuildIndex(false)

        let root = "target/ckb-routine-update-e2e-single-record"
        p5EnsureEmptyDir(root)
        let singleProvider = P5FakeEmbeddingProvider(2)
        let singleVectorStore = P5FakeQdrantStore("ckb_active", "ckb_candidate")
        let singleKb = p5SingleRecordKnowledgeBase(singleProvider, singleVectorStore)
        let store = FileKnowledgeStore("${root}/store")
        let config = p5RuntimeConfig(root)
        let persisted = ckbRebuildIndex(singleKb, store)
        singleProvider.resetCalls()
        let reconcile = ckbVectorReconcileWithVectorStore(singleKb, store, config, singleVectorStore, true)
        let reloaded = newKnowledgeBaseFromStore(store)
        let reloadedStatus = cangjie_knowledge_status(reloaded.kb)

        @Expect(empty.ok, false)
        @Expect(emptyProvider.calls, 0)
        @Expect(emptyVectorStore.status("ckb_active").count, 0)
        @Expect(persisted.ok, true)
        @Expect(reconcile.ok, true)
        @Expect(reloaded.source, "persisted")
        @Expect(reloadedStatus.storage.indexCount, 1)
        @Expect(singleVectorStore.status(store.loadMetadataStatus().vectorActiveCollection).count, 1)
    }

    @TestCase
    public func p5E2E04UncommittedTransactionManifestFallsBackToOldActive(): Unit {
        let root = "target/ckb-routine-update-e2e-uncommitted-tx"
        p5EnsureEmptyDir(root)
        let store = FileKnowledgeStore("${root}/store")
        let provider = P5FakeEmbeddingProvider(2)
        let vectorStore = P5FakeQdrantStore("ckb_active", "ckb_candidate")
        let kb = p5OfflineKnowledgeBase(provider, vectorStore)
        let initial = ckbRebuildIndex(kb, store)
        let oldVersion = cangjie_knowledge_status(kb).activeKnowledgeVersion
        let vectorActiveCollection = store.loadMetadataStatus().vectorActiveCollection
        let pendingTxId = "pending-tx"
        let pendingActiveVersion = "ckb-pending-active"
        let txIndexDir = Path("${root}/store/transactions/${pendingTxId}/index")
        Directory.create(txIndexDir, recursive: true)
        File.writeTo(txIndexDir.join("active.version"), "${pendingActiveVersion}\n".toArray())
        File.writeTo(Path("${root}/store/metadata/active-snapshot.manifest"), "txId=${pendingTxId}\nactive=${pendingActiveVersion}\nvectorActiveCollection=${vectorActiveCollection}\ncommitted=true\n".toArray())

        let snapshot = store.loadActiveSnapshot()
        let reloaded = newKnowledgeBaseFromStore(store)
        let status = cangjie_knowledge_status(reloaded.kb)

        @Expect(initial.ok, true)
        @Expect(snapshot.valid, true)
        @Expect(snapshot.diagnostic.contains("ignored_uncommitted_snapshot_tx:pending-tx"), true)
        @Expect(reloaded.source, "persisted")
        @Expect(status.activeKnowledgeVersion, oldVersion)
        @Expect(reloaded.diagnostic.contains("ignored_uncommitted_snapshot_tx:pending-tx"), true)
    }

    @TestCase
    public func p5E2E05StagedFullRebuildFailureKeepsOldActiveAndDeletesStaging(): Unit {
        let root = "target/ckb-routine-update-e2e-staged-rebuild-fail"
        p5EnsureEmptyDir(root)
        let config = p5RuntimeConfig(root)
        let store = FileKnowledgeStore("${root}/store")
        let provider = P5FakeEmbeddingProvider(2)
        let vectorStore = P5FakeQdrantStore("ckb_active", "ckb_candidate")
        let kb = p5OfflineKnowledgeBase(provider, vectorStore)
        let initial = ckbRebuildIndex(kb, store)
        let oldActiveCount = vectorStore.status("ckb_active").count
        provider.resetCalls()
        provider.failAtCall = 1

        let rebuild = ckbStagedFullRebuildWithVectorStore(kb, store, config, vectorStore, FileVectorBuildProgressSink(store), 0)
        let metadata = store.loadMetadataStatus()
        let status = cangjie_knowledge_status(kb)

        @Expect(initial.ok, true)
        @Expect(rebuild.ok, false)
        @Expect(rebuild.failedVersion.contains("vector_rebuild_failed") || rebuild.failedVersion.contains("embedding_batch_failed"), true)
        @Expect(vectorStore.status("ckb_active").count, oldActiveCount)
        @Expect(vectorStore.deleteCollectionCalls > 0, true)
        @Expect(metadata.vectorActiveCollection, "ckb_active")
        @Expect(status.storage.indexCount, oldActiveCount)
    }

    @TestCase
    public func p5E2E06VectorStatusMismatchMarksKnowledgeStatusDegraded(): Unit {
        let root = "target/ckb-routine-update-e2e-vector-status-mismatch"
        p5EnsureEmptyDir(root)
        let store = FileKnowledgeStore("${root}/store")
        let provider = P5FakeEmbeddingProvider(2)
        let vectorStore = P5FakeQdrantStore("ckb_active", "ckb_candidate")
        let kb = p5SingleRecordKnowledgeBase(provider, vectorStore)
        let initial = ckbRebuildIndex(kb, store)
        _ = vectorStore.deleteCollection("ckb_active")

        let verified = kb.verifyAndApplyVectorStoreStatus("ckb_active", 1)
        let status = cangjie_knowledge_status(kb)

        @Expect(initial.ok, true)
        @Expect(verified.state, EmbeddingProviderState.DEGRADED)
        @Expect(verified.degradedReason.contains("vector_store_count_mismatch:0:1:ckb_active"), true)
        @Expect(status.storage.vectorState, EmbeddingProviderState.DEGRADED)
        @Expect(status.indexManifest.entries[1].itemCount, 0)
    }

    @TestCase
    public func e2eS6003ShortDeadlineWorkerResultsAreStructuredAndNonEmpty(): Unit {
        let root = "target/e2e-s6-003-short-deadline"
        p5EnsureEmptyDir(root)
        p5WriteBenchmarkGapInput(root)
        let config = CkbRuntimeConfig()
        config.benchmarkGapCurationInputPath = "${root}/gap-curation-input.jsonl"
        let store = FileKnowledgeStore("${root}/store")
        let kb = newOfflineKnowledgeBase()
        let expired = ckbCoreNowMillis() - 1
        let weeklyPath = "metadata/scheduler-workers/e2e-s6-003-weekly.ckb"
        let benchmarkPath = "metadata/scheduler-workers/e2e-s6-003-benchmark.ckb"

        let weekly = ckbRunSchedulerTaskWorker(kb, config, store, "weekly_full_rebuild", "0", expired, weeklyPath)
        let benchmark = ckbRunSchedulerTaskWorker(kb, config, store, "cangjie_benchmark_gap_curation", "0", expired, benchmarkPath)

        @Expect(weekly.status, "task_timeout:weekly_full_rebuild")
        @Expect(benchmark.status, "task_timeout:cangjie_benchmark_gap_curation")
        @Expect(store.readText(weeklyPath).size > 0, true)
        @Expect(store.readText(benchmarkPath).size > 0, true)
        @Expect(store.readText(weeklyPath).contains("task_timeout:weekly_full_rebuild"), true)
        @Expect(store.readText(benchmarkPath).contains("task_timeout:cangjie_benchmark_gap_curation"), true)
    }
}

private class P5FakeEmbeddingProvider <: EmbeddingProvider {
    private let configuredBatchSize: Int64
    public var calls: Int64 = 0
    public var failAtCall: Int64 = -1

    init(batchSize: Int64) {
        this.configuredBatchSize = batchSize
    }

    public func embed(texts: ArrayList<String>, model: String, dimensions: Int64): EmbeddingBatch {
        this.calls += 1
        let batch = EmbeddingBatch()
        batch.requested = texts.size
        batch.batchSize = this.configuredBatchSize
        batch.status = this.status()
        if (this.calls == this.failAtCall) {
            batch.status.state = EmbeddingProviderState.DOWN
            batch.status.degradedReason = "ollama_timeout"
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

private class P5FakeQdrantStore <: VectorStore {
    public func lookupBatchWithDeadline(collection: String, pointIds: ArrayList<String>, deadlineAtMillis: Int64): VectorLookupResult { let result = VectorLookupResult(); result.ok = true; result.status = "ok"; result.requested = pointIds.size; result }
    private let activeCollection: String
    private let candidateCollection: String
    private var activeCount: Int64 = 0
    private var stagingCollection: String = ""
    private var stagingCount: Int64 = 0
    private var state: String = EmbeddingProviderState.READY
    private var diagnostic: String = ""
    public var upsertBatchCalls: Int64 = 0
    public var deleteCollectionCalls: Int64 = 0

    init(activeCollection: String, candidateCollection: String) {
        this.activeCollection = activeCollection
        this.candidateCollection = candidateCollection
    }

    public func upsert(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.upsertBatch(collection, vectors)
    }

    public func upsertBatch(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.upsertBatchCalls += 1
        if (collection == this.activeCollection) {
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
        status.activeCollection = this.activeCollection
        status.candidateCollection = this.candidateCollection
        status.dimension = 3
        status.distance = "Cosine"
        status.state = this.state
        status.degradedReason = this.diagnostic
        status.count = if (collection == this.activeCollection) {
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
        if (collection == this.activeCollection) {
            this.activeCount = 0
        } else {
            this.stagingCollection = collection
            this.stagingCount = 0
        }
        this.state = EmbeddingProviderState.READY
        this.diagnostic = ""
        this.status(collection)
    }

    public func deleteCollection(collection: String): VectorStoreStatus {
        this.deleteCollectionCalls += 1
        if (collection == this.activeCollection) {
            this.activeCount = 0
        } else if (collection == this.stagingCollection) {
            this.stagingCount = 0
        }
        this.state = EmbeddingProviderState.READY
        this.diagnostic = ""
        this.status(collection)
    }

    public func recreate(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        _ = this.clear(collection)
        if (vectors.size > 0) {
            return this.upsertBatch(collection, vectors)
        }
        this.status(collection)
    }

    public func recreateWithDeadline(collection: String, vectors: ArrayList<VectorRecord>, deadlineAtMillis: Int64): VectorStoreStatus {
        this.recreate(collection, vectors)
    }

    public func backup(collection: String): VectorBackup {
        let backup = VectorBackup()
        backup.collection = collection
        backup.valid = true
        backup.diagnostic = "ok"
        backup
    }

    public func backupWithDeadline(collection: String, deadlineAtMillis: Int64): VectorBackup {
        this.backup(collection)
    }

    public func restore(backup: VectorBackup): VectorStoreStatus {
        this.status(backup.collection)
    }
}

private func p5RuntimeConfig(root: String): CkbRuntimeConfig {
    let config = CkbRuntimeConfig()
    config.networkEnabled = true
    config.docsEnabled = true
    config.websiteEnabled = true
    config.embeddingProvider = "ollama"
    config.embeddingModel = "bge-m3:latest"
    config.embeddingEndpoint = "http://127.0.0.1:11434/api/embed"
    config.embeddingAllowPrivateEndpoint = true
    config.embeddingDimensions = 3
    config.embeddingBatchSize = 2
    config.vectorBackend = "qdrant"
    config.vectorEndpoint = "http://127.0.0.1:6333"
    config.vectorAllowPrivateEndpoint = true
    config.vectorActiveCollection = "ckb_active"
    config.vectorCandidateCollection = "ckb_candidate"
    config.vectorDimensions = 3
    config.vectorDistance = "Cosine"
    config.benchmarkGapCurationInputPath = "${root}/gap-curation-input.jsonl"
    config.firstInitEvalRoot = p5WriteEvalFixture(root)
    config.firstInitTargetVersion = "1.0.0"
    config
}

private func p5E2EVersionManifest(): CangjieVersionManifest {
    let manifest = CangjieVersionManifest()
    manifest.defaultTargetVersion = "1.0.0"
    p5AddE2EManifestSource(manifest, CangjieSourceSets.DOCS, "docs", "Cangjie/cangjie_docs")
    p5AddE2EManifestSource(manifest, CangjieSourceSets.STD, "stdlib", "Cangjie/cangjie_runtime")
    p5AddE2EManifestSource(manifest, CangjieSourceSets.STDX, "stdx", "Cangjie/cangjie_stdx")
    p5AddE2EManifestSource(manifest, CangjieSourceSets.TOOLS, "tools", "Cangjie/cangjie_tools")
    p5AddE2EManifestSource(manifest, CangjieSourceSets.EVAL_SUPPORT, "eval-support", "CangjieCommunityKnowledgeBase/Cangjie-HumanEval")
    manifest
}

private func p5AddE2EManifestSource(manifest: CangjieVersionManifest, sourceSet: String, sourceFamily: String, repo: String): Unit {
    let source = CangjieVersionSource()
    source.targetVersion = "1.0.0"
    source.sourceSet = sourceSet
    source.sourceFamily = sourceFamily
    source.sourceRepo = repo
    source.sourceRef = "release-1.0.0"
    source.refKind = "branch"
    source.resolvedCommit = "p5-e2e-${sourceSet}-commit"
    source.contentHash = "sha256:p5-e2e-${sourceSet}"
    source.rootKind = "scheduled:test"
    manifest.sources.add(source)
}

private func p5WriteEvalFixture(root: String): String {
    let evalRoot = "${root}/eval-fixture"
    p5WriteFile("${evalRoot}/CJ-HUMANEVAL-000/prompt.md", "# Task\nUse EvalValue and EvalEntry.\n")
    p5WriteFile("${evalRoot}/CJ-HUMANEVAL-000/metadata.json", "{\"id\":\"CJ-HUMANEVAL-000\"}\n")
    p5WriteFile("${evalRoot}/CJ-HUMANEVAL-000/starter/src/eval_support.cj", "public class EvalValue {}\npublic class EvalEntry {}\n")
    p5WriteFile("${evalRoot}/CJ-HUMANEVAL-000/tests/TestMain.cj", "public func helper(): Unit {}\nmain() {}\n")
    evalRoot
}

private func p5OfflineKnowledgeBase(provider: P5FakeEmbeddingProvider, vectorStore: P5FakeQdrantStore): KnowledgeBase {
    let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
    kb.configureVectorCollections("ckb_active", "ckb_candidate")
    kb.bootstrapOffline()
    kb
}

private func p5SingleRecordKnowledgeBase(provider: P5FakeEmbeddingProvider, vectorStore: P5FakeQdrantStore): KnowledgeBase {
    let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
    kb.configureVectorCollections("ckb_active", "ckb_candidate")
    let fetch = SourceFetchResult()
    fetch.ok = true
    fetch.status = "ok"
    fetch.statusCode = 200
    fetch.sourceUrl = "https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection"
    fetch.normalizedType = SourceKinds.CANGJIE_DOCS
    fetch.body = "ArrayList.add single record for routine update E2E."
    fetch.bytes = fetch.body.size
    fetch.bodyHash = stableSummaryHash(fetch.body)
    _ = kb.ingestFetchResult("p5-single-doc", SourceTypes.DOC, fetch, "P5 single doc", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    kb.normalize()
    kb
}

private func p5WriteBenchmarkGapInput(root: String): Unit {
    p5WriteFile("${root}/gap-curation-input.jsonl", "{\"caseId\":\"CJ-HUMANEVAL-P5\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"Use ArrayList.add for visible input.\",\"visibleTestExcerpt\":\"assert solve([1,2]) == 3\",\"compilerOutput\":\"compile_error\",\"missingKnowledge\":\"G-ARRAYLIST\",\"interfaceId\":\"KI-02\",\"contentFamily\":\"KC-02\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"1.0.0\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection\"}\n")
}

private func p5WriteRoutineAcceptanceArtifacts(root: String, reconcile: CkbVectorReconcileResult, scheduler: SchedulerExecutorResult, source: String, diagnostic: String, qdrantCount: Int64, indexCount: Int64): Unit {
    let vectorOk = reconcile.ok && reconcile.progressPath != ""
    let countOk = qdrantCount == indexCount && indexCount > 0
    let metadataOk = diagnostic == "ok"
    let reloadOk = source != "offline_baseline"
    var matrix = ""
    matrix += p5AcceptanceLine("P5-E2E-01", "vector_reconcile_completed", vectorOk, reconcile.progressPath)
    matrix += p5AcceptanceLine("P5-E2E-01", "qdrant_count_matches_active_index", countOk, "qdrant=${qdrantCount},index=${indexCount}")
    matrix += p5AcceptanceLine("P5-E2E-01", "no_metadata_active_mismatch", metadataOk, diagnostic)
    matrix += p5AcceptanceLine("P5-E2E-01", "no_offline_baseline_after_reload", reloadOk, source)
    p5WriteFile("${root}/routine-update-acceptance-matrix.jsonl", matrix)
    p5WriteFile("${root}/routine-update-contract.jsonl", renderCkbRoutineUpdateContractsJsonl())
    p5WriteFile("${root}/routine-update-task-results.jsonl", "{\"type\":\"summary\",\"ran\":${scheduler.ran},\"failed\":${scheduler.failed},\"degraded\":${scheduler.degraded}}\n")
}

private func p5RepresentativeForceAllTaskNames(): ArrayList<String> {
    let names = ArrayList<String>()
    names.add("weekly_full_rebuild")
    names.add("cangjie_docs_full_weekly")
    names.add("cangjie_benchmark_gap_curation")
    names
}

private func p5AllTasksAllowed(taskNames: ArrayList<String>): Bool {
    let allowed = ckbSchedulerAllowlistTaskNames()
    if (allowed.size < taskNames.size) {
        return false
    }
    for (name in taskNames) {
        if (!allowed.contains(name)) {
            return false
        }
    }
    true
}

private func p5AcceptanceLine(testId: String, acceptance: String, ok: Bool, evidence: String): String {
    "{\"phase\":\"P5\",\"testId\":\"${testId}\",\"acceptance\":\"${acceptance}\",\"status\":\"${if (ok) { "passed" } else { "failed" }}\",\"evidence\":\"${p5JsonEscape(evidence)}\"}\n"
}

private func p5Contains(values: ArrayList<String>, needle: String): Bool {
    for (value in values) {
        if (value.contains(needle)) {
            return true
        }
    }
    false
}

private func p5EnsureEmptyDir(path: String): Unit {
    if (exists(Path(path))) {
        _ = launch("/bin/rm", ["-rf", path]).wait()
    }
    Directory.create(Path(path), recursive: true)
}

private func p5WriteFile(path: String, content: String): Unit {
    let target = Path(path)
    let parent = target.parent
    if (!exists(parent)) {
        Directory.create(parent, recursive: true)
    }
    File.writeTo(target, content.toArray())
}

private func p5JsonEscape(raw: String): String {
    raw.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
}
