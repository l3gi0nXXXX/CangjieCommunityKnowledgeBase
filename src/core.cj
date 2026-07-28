package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.collection.HashMap
import std.collection.HashSet
import std.convert.Parsable
import std.time.*
import stdx.crypto.digest.SHA256

public class SourceTypes {
    public static let REPO: String = "repo"
    public static let DOC: String = "doc"
    public static let WEBSITE: String = "website"
    public static let COMMUNITY: String = "community"
    public static let WEB_CANDIDATE: String = "web_candidate"
    public static let DERIVED: String = "derived"
}

public class IndexKinds {
    public static let TEXT: String = "text"
    public static let VECTOR: String = "vector"
    public static let SYMBOL: String = "symbol"
    public static let GRAPH: String = "graph"
    public static let SERVING: String = "serving"
}

public class TrustLevels {
    public static let OFFICIAL: String = "official"
    public static let COMMUNITY: String = "community"
    public static let WEB_CANDIDATE: String = "web_candidate"
    public static let DERIVED: String = "derived"
}

public class ReviewStates {
    public static let TRUSTED: String = "trusted"
    public static let REVIEWED: String = "reviewed"
    public static let CANDIDATE: String = "candidate"
    public static let REJECTED: String = "rejected"
}

public class FreshnessPolicies {
    public static let USE_ACTIVE: String = "use_active"
    public static let ENSURE_RECENT: String = "ensure_recent"
    public static let ENSURE_REF: String = "ensure_ref"
    public static let FORCE_CANDIDATE: String = "force_candidate"
}

public class SourceReference {
    public var sourceId: String = ""
    public var citation: String = ""
    public var knowledgeVersion: String = ""

    public init() {}

    public init(sourceId: String, citation: String, knowledgeVersion: String) {
        this.sourceId = sourceId
        this.citation = citation
        this.knowledgeVersion = knowledgeVersion
    }
}

public class KnowledgeMetadata {
    public var sourceId: String = ""
    public var sourceType: String = ""
    public var sourceUrl: String = ""
    public var repo: String = ""
    public var path: String = ""
    public var symbol: String = ""
    public var commit: String = ""
    public var docVersion: String = ""
    public var targetVersion: String = "1.0.0"
    public var sourceSet: String = ""
    public var versionResolutionId: String = ""
    public var crawlAt: String = ""
    public var indexedAt: String = ""
    public var knowledgeVersion: String = ""
    public var candidateVersion: String = ""
    public var contentSize: Int64 = 0
    public var trustLevel: String = ""
    public var reviewState: String = ""
    public var license: String = "unknown"
    public var repoVisibility: String = ""
    public var derivedFrom: Array<String> = []

    public init() {}
}

public class RawRecord {
    public var sourceId: String = ""
    public var title: String = ""
    public var content: String = ""
    public var metadata: KnowledgeMetadata = KnowledgeMetadata()
    public var contentHash: String = ""
    public var requiresReview: Bool = false

    public init() {}
}

public class NormalizedRecord {
    public var sourceId: String = ""
    public var recordKind: String = ""
    public var title: String = ""
    public var chunk: String = ""
    public var citation: String = ""
    public var score: Float64 = 0.0
    public var metadata: KnowledgeMetadata = KnowledgeMetadata()
    public var requiresReview: Bool = false

    public init() {}
}

public class SearchOptions {
    public var sourceType: String = ""
    public var trustLevel: String = ""
    public var reviewState: String = ""
    public var budget: Int64 = 5
    public var includeCandidates: Bool = false
    public var includeVector: Bool = true

    public init() {}
}

public class SearchResult {
    public var queryId: String = ""
    public var knowledgeVersion: String = ""
    public var records: ArrayList<NormalizedRecord> = ArrayList<NormalizedRecord>()
    public var truncated: Bool = false
    public var degraded: Bool = false
    public var vectorUsed: Bool = false
    public var fallbackReason: String = ""

    public init() {}
}

public class EmbeddingProviderState {
    public static let READY: String = "ready"
    public static let DEGRADED: String = "degraded"
    public static let DOWN: String = "down"
}

public class EmbeddingConfig {
    public var provider: String = "local-file"
    public var model: String = "deterministic-token-v1"
    public var dimensions: Int64 = 16
    public var endpoint: String = ""
    public var tokenFile: String = ""
    public var tokenRef: String = ""
    public var batchSize: Int64 = 16
    public var maxBatchBytes: Int64 = 65536
    public var maxTextBytes: Int64 = 8192
    public var totalTimeoutMillis: Int64 = 0
    public var timeoutMillis: Int64 = 10000
    public var retryCount: Int64 = 2
    public var production: Bool = true
    public var configured: Bool = true

    public init() {}

    public func credentialPresent(): Bool {
        this.tokenFile != "" || this.tokenRef != ""
    }
}

public class EmbeddingStatus {
    public var provider: String = ""
    public var model: String = ""
    public var dimensions: Int64 = 0
    public var endpointConfigured: Bool = false
    public var tokenConfigured: Bool = false
    public var batchSize: Int64 = 0
    public var maxBatchBytes: Int64 = 0
    public var maxTextBytes: Int64 = 0
    public var totalTimeoutMillis: Int64 = 0
    public var timeoutMillis: Int64 = 0
    public var retryCount: Int64 = 0
    public var state: String = EmbeddingProviderState.DEGRADED
    public var production: Bool = false
    public var degradedReason: String = ""

    public init() {}
}

public class EmbeddingBatch {
    public var vectors: ArrayList<ArrayList<Float64>> = ArrayList<ArrayList<Float64>>()
    public var status: EmbeddingStatus = EmbeddingStatus()
    public var requested: Int64 = 0
    public var succeeded: Int64 = 0
    public var failed: Int64 = 0
    public var batchSize: Int64 = 0
    public var processed: Int64 = 0
    public var inputBytes: Int64 = 0
    public var preparedBytes: Int64 = 0
    public var truncatedCount: Int64 = 0
    public var elapsedMillis: Int64 = 0
    public var chunksAttempted: Int64 = 0
    public var lastChunkPreparedBytes: Int64 = 0
    public var lastDiagnostic: String = ""

    public init() {}
}

public class CkbEmbeddingTextBudget {
    public var maxBatchItems: Int64 = 16
    public var maxBatchBytes: Int64 = 65536
    public var maxTextBytes: Int64 = 8192

    public init() {}
}

public class CkbEmbeddingPreparedText {
    public var text: String = ""
    public var originalBytes: Int64 = 0
    public var preparedBytes: Int64 = 0
    public var truncated: Bool = false

    public init() {}
}

public class CkbEmbeddingTextBatch {
    public var startIndex: Int64 = 0
    public var endIndex: Int64 = 0
    public var texts: ArrayList<String> = ArrayList<String>()
    public var originalBytes: Int64 = 0
    public var preparedBytes: Int64 = 0
    public var truncatedCount: Int64 = 0

    public init() {}
}

public class CkbEmbeddingTextBudgeter {
    private let budget: CkbEmbeddingTextBudget

    public init(budget: CkbEmbeddingTextBudget) {
        this.budget = budget
    }

    public func prepare(raw: String): CkbEmbeddingPreparedText {
        let prepared = CkbEmbeddingPreparedText()
        prepared.originalBytes = raw.size
        let maxTextBytes = this.effectiveMaxTextBytes()
        prepared.text = if (maxTextBytes > 0 && raw.size > maxTextBytes) {
            ckbUtf8SafePrefix(raw, maxTextBytes)
        } else {
            raw
        }
        prepared.preparedBytes = prepared.text.size
        prepared.truncated = prepared.preparedBytes < prepared.originalBytes
        prepared
    }

    public func batches(texts: ArrayList<String>): ArrayList<CkbEmbeddingTextBatch> {
        let out = ArrayList<CkbEmbeddingTextBatch>()
        if (texts.size == 0) {
            return out
        }
        var current = CkbEmbeddingTextBatch()
        current.startIndex = 0
        let maxItems = this.effectiveMaxBatchItems()
        let maxBytes = this.effectiveMaxBatchBytes()
        for (idx in 0..texts.size) {
            let prepared = this.prepare(texts[idx])
            let wouldExceedItems = current.texts.size > 0 && current.texts.size >= maxItems
            let wouldExceedBytes = current.texts.size > 0 && maxBytes > 0 && current.preparedBytes + prepared.preparedBytes > maxBytes
            if (wouldExceedItems || wouldExceedBytes) {
                current.endIndex = idx
                out.add(current)
                current = CkbEmbeddingTextBatch()
                current.startIndex = idx
            }
            current.texts.add(prepared.text)
            current.originalBytes += prepared.originalBytes
            current.preparedBytes += prepared.preparedBytes
            if (prepared.truncated) {
                current.truncatedCount += 1
            }
            current.endIndex = idx + 1
        }
        if (current.texts.size > 0) {
            out.add(current)
        }
        out
    }

    private func effectiveMaxBatchItems(): Int64 {
        if (this.budget.maxBatchItems <= 0) {
            return 16
        }
        this.budget.maxBatchItems
    }

    private func effectiveMaxBatchBytes(): Int64 {
        if (this.budget.maxBatchBytes < 0) {
            return 0
        }
        this.budget.maxBatchBytes
    }

    private func effectiveMaxTextBytes(): Int64 {
        if (this.budget.maxTextBytes < 0) {
            return 0
        }
        this.budget.maxTextBytes
    }
}

public class VectorBuildProgress {
    public var runId: String = ""
    public var collection: String = ""
    public var targetCollection: String = ""
    public var total: Int64 = 0
    public var dimension: Int64 = 0
    public var completed: Int64 = 0
    public var failed: Int64 = 0
    public var currentBatch: Int64 = 0
    public var currentBatchStart: Int64 = 0
    public var currentBatchEnd: Int64 = 0
    public var batchSize: Int64 = 0
    public var inputBytes: Int64 = 0
    public var preparedBytes: Int64 = 0
    public var reused: Int64 = 0
    public var embedded: Int64 = 0
    public var lookupRequested: Int64 = 0
    public var lookupFound: Int64 = 0
    public var lookupStatus: String = "not_started"
    public var lookupDurationMillis: Int64 = 0
    public var lookupTimedOut: Bool = false
    public var startedAtMillis: Int64 = 0
    public var updatedAtMillis: Int64 = 0
    public var elapsedMillis: Int64 = 0
    public var state: String = "idle"
    public var diagnostic: String = ""
    public var lastDiagnostic: String = ""

    public init() {}
}

public interface VectorBuildProgressSink {
    func onVectorBuildStarted(progress: VectorBuildProgress): Unit
    func onVectorBatchStarted(progress: VectorBuildProgress): Unit
    func onVectorBatchFinished(progress: VectorBuildProgress): Unit
    func onVectorBuildFinished(progress: VectorBuildProgress): Unit
}

public class NoopVectorBuildProgressSink <: VectorBuildProgressSink {
    public init() {}

    public func onVectorBuildStarted(progress: VectorBuildProgress): Unit {}

    public func onVectorBatchStarted(progress: VectorBuildProgress): Unit {}

    public func onVectorBatchFinished(progress: VectorBuildProgress): Unit {}

    public func onVectorBuildFinished(progress: VectorBuildProgress): Unit {}
}

public class VectorIndexBuildResult {
    public var ok: Bool = false
    public var status: String = "not_started"
    public var vectorRecords: ArrayList<VectorRecord> = ArrayList<VectorRecord>()
    public var vectorRecordsMaterialized: Bool = true
    public var persistedVectorCollection: String = ""
    public var vectorCount: Int64 = 0
    public var graphNodes: Int64 = 0
    public var servingCount: Int64 = 0
    public var diagnostic: String = ""
    public var truncatedCount: Int64 = 0
    public var elapsedMillis: Int64 = 0
    public var reused: Int64 = 0
    public var embedded: Int64 = 0
    public var peakBufferedRecords: Int64 = 0
    public var peakBufferedBytes: Int64 = 0
    public var spool: CkbVectorSpoolDescriptor = CkbVectorSpoolDescriptor()

    public init() {}
}

public class VectorRecordsBuildResult {
    public var ok: Bool = false
    public var status: String = "not_started"
    public var records: ArrayList<VectorRecord> = ArrayList<VectorRecord>()
    public var processed: Int64 = 0
    public var failed: Int64 = 0
    public var diagnostic: String = ""
    public var truncatedCount: Int64 = 0
    public var elapsedMillis: Int64 = 0

    public init() {}
}

public interface EmbeddingProvider {
    func embed(texts: ArrayList<String>, model: String, dimensions: Int64): EmbeddingBatch
    func embedWithDeadline(texts: ArrayList<String>, model: String, dimensions: Int64, deadlineAtMillis: Int64): EmbeddingBatch
    func status(): EmbeddingStatus
}

public func ckbEmbeddingTextBudgetFromStatus(status: EmbeddingStatus): CkbEmbeddingTextBudget {
    let budget = CkbEmbeddingTextBudget()
    budget.maxBatchItems = if (status.batchSize > 0) { status.batchSize } else { 16 }
    budget.maxBatchBytes = if (status.maxBatchBytes > 0) { status.maxBatchBytes } else { 65536 }
    budget.maxTextBytes = if (status.maxTextBytes > 0) { status.maxTextBytes } else { 8192 }
    budget
}

public func ckbEmbeddingTextBudgetFromConfig(config: EmbeddingConfig): CkbEmbeddingTextBudget {
    let budget = CkbEmbeddingTextBudget()
    budget.maxBatchItems = if (config.batchSize > 0) { config.batchSize } else { 16 }
    budget.maxBatchBytes = if (config.maxBatchBytes > 0) { config.maxBatchBytes } else { 65536 }
    budget.maxTextBytes = if (config.maxTextBytes > 0) { config.maxTextBytes } else { 8192 }
    budget
}

public func ckbCoreNowMillis(): Int64 {
    DateTime.now().toUnixTimeStamp().toMilliseconds()
}

public interface CkbMillisClock {
    func nowMillis(): Int64
}

public class SystemCkbMillisClock <: CkbMillisClock {
    public init() {}

    public func nowMillis(): Int64 {
        ckbCoreNowMillis()
    }
}

public func ckbDeadlineExceeded(deadlineAtMillis: Int64): Bool {
    deadlineAtMillis > 0 && ckbCoreNowMillis() >= deadlineAtMillis
}

public class CkbDeadlineCheckResult {
    public var exceeded: Bool = false
    public var status: String = "ok"
    public var diagnostic: String = ""
    public var stage: String = ""
    public var nowMillis: Int64 = 0
    public var deadlineAtMillis: Int64 = 0
    public var remainingMillis: Int64 = 0

    public init() {}
}

public func ckbDeadlineGuard(stage: String, deadlineAtMillis: Int64): CkbDeadlineCheckResult {
    let result = CkbDeadlineCheckResult()
    result.stage = stage
    result.deadlineAtMillis = deadlineAtMillis
    result.nowMillis = ckbCoreNowMillis()
    result.remainingMillis = if (deadlineAtMillis > 0) { deadlineAtMillis - result.nowMillis } else { 0 }
    result.exceeded = deadlineAtMillis > 0 && result.nowMillis >= deadlineAtMillis
    if (result.exceeded) {
        result.status = "deadline_exceeded"
        result.diagnostic = "deadline_exceeded:${stage}:now=${result.nowMillis}:deadline=${deadlineAtMillis}"
    }
    result
}

public func ckbRemainingMillis(deadlineAtMillis: Int64): Int64 {
    if (deadlineAtMillis <= 0) {
        return 0
    }
    deadlineAtMillis - ckbCoreNowMillis()
}

public func ckbDeadlineEmbeddingBatch(texts: ArrayList<String>, reason: String): EmbeddingBatch {
    let batch = EmbeddingBatch()
    batch.requested = texts.size
    batch.failed = texts.size
    batch.status.state = EmbeddingProviderState.DEGRADED
    batch.status.degradedReason = reason
    batch.lastDiagnostic = reason
    batch
}

private func ckbVectorBuildRunId(): String {
    "vector-reconcile-${ckbCoreNowMillis()}"
}

public class DeterministicEmbeddingProvider <: EmbeddingProvider {
    private let config: EmbeddingConfig

    public init() {
        this.config = EmbeddingConfig()
    }

    public init(config: EmbeddingConfig) {
        this.config = config
    }

    public func embed(texts: ArrayList<String>, model: String, dimensions: Int64): EmbeddingBatch {
        let batch = EmbeddingBatch()
        batch.requested = texts.size
        batch.batchSize = this.config.batchSize
        batch.status = this.status()
        if (batch.status.state != EmbeddingProviderState.READY) {
            batch.failed = texts.size
            return batch
        }
        for (text in texts) {
            batch.vectors.add(deterministicEmbedding(text, dimensions))
        }
        batch.succeeded = batch.vectors.size
        batch
    }

    public func embedWithDeadline(texts: ArrayList<String>, model: String, dimensions: Int64, deadlineAtMillis: Int64): EmbeddingBatch {
        if (ckbDeadlineExceeded(deadlineAtMillis)) {
            return ckbDeadlineEmbeddingBatch(texts, "embedding_deadline_exceeded")
        }
        this.embed(texts, model, dimensions)
    }

    public func status(): EmbeddingStatus {
        let status = EmbeddingStatus()
        status.provider = this.config.provider
        status.model = this.config.model
        status.dimensions = this.config.dimensions
        status.endpointConfigured = this.config.endpoint != ""
        status.tokenConfigured = this.config.credentialPresent()
        status.batchSize = this.config.batchSize
        status.maxBatchBytes = this.config.maxBatchBytes
        status.maxTextBytes = this.config.maxTextBytes
        status.totalTimeoutMillis = this.config.totalTimeoutMillis
        status.timeoutMillis = this.config.timeoutMillis
        status.retryCount = this.config.retryCount
        status.production = this.config.production
        if (!this.config.configured || this.config.dimensions <= 0) {
            status.state = EmbeddingProviderState.DEGRADED
            status.degradedReason = "embedding_provider_not_configured"
            return status
        }
        status.state = EmbeddingProviderState.READY
        status
    }
}

public class ProductionEmbeddingProvider <: EmbeddingProvider {
    private let config: EmbeddingConfig

    public init(config: EmbeddingConfig) {
        this.config = config
    }

    public func embed(texts: ArrayList<String>, model: String, dimensions: Int64): EmbeddingBatch {
        let batch = EmbeddingBatch()
        batch.requested = texts.size
        batch.batchSize = this.config.batchSize
        batch.status = this.status()
        batch.failed = texts.size
        batch
    }

    public func embedWithDeadline(texts: ArrayList<String>, model: String, dimensions: Int64, deadlineAtMillis: Int64): EmbeddingBatch {
        if (ckbDeadlineExceeded(deadlineAtMillis)) {
            return ckbDeadlineEmbeddingBatch(texts, "embedding_deadline_exceeded")
        }
        this.embed(texts, model, dimensions)
    }

    public func status(): EmbeddingStatus {
        let status = EmbeddingStatus()
        status.provider = this.config.provider
        status.model = this.config.model
        status.dimensions = this.config.dimensions
        status.endpointConfigured = this.config.endpoint != ""
        status.tokenConfigured = this.config.credentialPresent()
        status.batchSize = this.config.batchSize
        status.maxBatchBytes = this.config.maxBatchBytes
        status.maxTextBytes = this.config.maxTextBytes
        status.totalTimeoutMillis = this.config.totalTimeoutMillis
        status.timeoutMillis = this.config.timeoutMillis
        status.retryCount = this.config.retryCount
        status.production = true
        status.state = EmbeddingProviderState.DEGRADED
        status.degradedReason = "production_embedding_requires_external_adapter"
        if (!this.config.configured || this.config.endpoint == "" || !this.config.credentialPresent() || this.config.dimensions <= 0) {
            status.degradedReason = "production_embedding_missing_config"
        }
        status
    }
}

public class VectorRecord {
    public var id: String = ""
    public var pointId: String = ""
    public var vector: ArrayList<Float64> = ArrayList<Float64>()
    public var metadata: KnowledgeMetadata = KnowledgeMetadata()
    public var title: String = ""
    public var chunk: String = ""
    public var citation: String = ""

    public init() {}
}

public func vectorPointIdentity(record: VectorRecord): String {
    let pointId = record.pointId.trimAscii()
    if (pointId != "") {
        return pointId
    }
    record.id
}

public class VectorSearchFilters {
    public var repo: String = ""
    public var sourceType: String = ""
    public var trustLevel: String = ""
    public var reviewState: String = ""
    public var knowledgeVersion: String = ""
    public var includeCandidates: Bool = false

    public init() {}
}

public class VectorSearchResult {
    public var id: String = ""
    public var score: Float64 = 0.0
    public var record: VectorRecord = VectorRecord()

    public init() {}
}

public class VectorStoreStatus {
    public var backend: String = ""
    public var collection: String = ""
    public var activeCollection: String = "active"
    public var candidateCollection: String = "candidate"
    public var dimension: Int64 = 0
    public var distance: String = ""
    public var count: Int64 = 0
    public var state: String = EmbeddingProviderState.DEGRADED
    public var degradedReason: String = ""

    public init() {}
}

public interface VectorStore {
    func upsert(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus
    func upsertBatch(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus
    func upsertBatchWithDeadline(collection: String, vectors: ArrayList<VectorRecord>, deadlineAtMillis: Int64): VectorStoreStatus
    func search(collection: String, queryVector: ArrayList<Float64>, filters: VectorSearchFilters, topK: Int64): ArrayList<VectorSearchResult>
    func status(collection: String): VectorStoreStatus
    func ensureReadyCollection(collection: String): VectorStoreStatus
    func clear(collection: String): VectorStoreStatus
    func deleteCollection(collection: String): VectorStoreStatus
    func recreate(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus
    func recreateWithDeadline(collection: String, vectors: ArrayList<VectorRecord>, deadlineAtMillis: Int64): VectorStoreStatus
    func backup(collection: String): VectorBackup
    func backupWithDeadline(collection: String, deadlineAtMillis: Int64): VectorBackup
    func lookupBatchWithDeadline(collection: String, pointIds: ArrayList<String>, deadlineAtMillis: Int64): VectorLookupResult
    func restore(backup: VectorBackup): VectorStoreStatus
}

public class VectorBackup {
    public var collection: String = ""
    public var records: ArrayList<VectorRecord> = ArrayList<VectorRecord>()
    public var valid: Bool = false
    public var diagnostic: String = ""

    public init() {}
}

private class VectorBackupReuseIndex {
    public var byPoint: HashMap<String, VectorRecord> = HashMap<String, VectorRecord>()
    public var byContent: HashMap<String, VectorRecord> = HashMap<String, VectorRecord>()

    public init() {}
}

class LocalVectorCollection {
    public var name: String = ""
    public var records: ArrayList<VectorRecord> = ArrayList<VectorRecord>()
    public var dimension: Int64 = 0
    public var pointIndex: HashMap<String, Int64> = HashMap<String, Int64>()
    public var reuseIndex: HashMap<String, Int64> = HashMap<String, Int64>()

    public init() {}
}

public class LocalVectorStore <: VectorStore {
    private var collections: ArrayList<LocalVectorCollection> = ArrayList<LocalVectorCollection>()
    private var available: Bool = true
    private let backendName: String = "local-file"

    public init() {}

    public init(available: Bool) {
        this.available = available
    }

    public func upsert(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        if (!this.available) {
            return this.status(collection)
        }
        let stored = this.ensureCollection(collection)
        stored.records.clear()
        stored.pointIndex.clear()
        stored.reuseIndex.clear()
        stored.dimension = 0
        for (record in vectors) {
            if (stored.dimension == 0) {
                stored.dimension = record.vector.size
            }
            stored.records.add(record)
            stored.pointIndex[vectorPointIdentity(record)] = stored.records.size - 1
            stored.reuseIndex[ckbVectorRecordStablePointId(record)] = stored.records.size - 1
        }
        this.status(collection)
    }

    public func upsertBatch(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        if (!this.available) {
            return this.status(collection)
        }
        let stored = this.ensureCollection(collection)
        for (record in vectors) {
            if (stored.dimension == 0) {
                stored.dimension = record.vector.size
            }
            let pointId = vectorPointIdentity(record)
            if (stored.pointIndex.contains(pointId)) {
                stored.records[stored.pointIndex[pointId]] = record
            } else {
                stored.records.add(record)
                stored.pointIndex[pointId] = stored.records.size - 1
            }
            stored.reuseIndex[ckbVectorRecordStablePointId(record)] = stored.pointIndex[pointId]
        }
        this.status(collection)
    }

    public func upsertBatchWithDeadline(collection: String, vectors: ArrayList<VectorRecord>, deadlineAtMillis: Int64): VectorStoreStatus {
        if (ckbDeadlineExceeded(deadlineAtMillis)) {
            let status = this.status(collection)
            status.state = EmbeddingProviderState.DEGRADED
            status.degradedReason = "vector_store_deadline_exceeded:${collection}"
            return status
        }
        this.upsertBatch(collection, vectors)
    }

    public func search(collection: String, queryVector: ArrayList<Float64>, filters: VectorSearchFilters, topK: Int64): ArrayList<VectorSearchResult> {
        let out = ArrayList<VectorSearchResult>()
        if (!this.available || queryVector.size == 0) {
            return out
        }
        let stored = this.findCollection(collection)
        if (stored.name == "") {
            return out
        }
        for (record in stored.records) {
            if (!vectorRecordAllowed(record, filters)) {
                continue
            }
            let score = cosineSimilarity(queryVector, record.vector)
            if (score <= 0.0) {
                continue
            }
            insertVectorResult(out, record, score, topK)
        }
        out
    }

    public func status(collection: String): VectorStoreStatus {
        let status = VectorStoreStatus()
        status.backend = this.backendName
        status.collection = collection
        let stored = this.findCollection(collection)
        status.dimension = stored.dimension
        status.count = stored.records.size
        if (!this.available) {
            status.state = EmbeddingProviderState.DOWN
            status.degradedReason = "vector_store_unavailable"
            return status
        }
        status.state = EmbeddingProviderState.READY
        status
    }

    public func ensureReadyCollection(collection: String): VectorStoreStatus {
        if (!this.available) {
            return this.status(collection)
        }
        this.ensureCollection(collection)
        this.status(collection)
    }

    public func clear(collection: String): VectorStoreStatus {
        if (!this.available) {
            return this.status(collection)
        }
        let stored = this.findCollection(collection)
        if (stored.name != "") {
            stored.records.clear()
            stored.pointIndex.clear()
            stored.reuseIndex.clear()
            stored.dimension = 0
        }
        this.status(collection)
    }

    public func deleteCollection(collection: String): VectorStoreStatus {
        if (!this.available) {
            return this.status(collection)
        }
        let kept = ArrayList<LocalVectorCollection>()
        for (stored in this.collections) {
            if (stored.name != collection) {
                kept.add(stored)
            }
        }
        this.collections.clear()
        for (stored in kept) {
            this.collections.add(stored)
        }
        this.status(collection)
    }

    public func recreate(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.clear(collection)
        this.upsert(collection, vectors)
    }

    public func recreateWithDeadline(collection: String, vectors: ArrayList<VectorRecord>, deadlineAtMillis: Int64): VectorStoreStatus {
        if (ckbDeadlineExceeded(deadlineAtMillis)) {
            let status = this.status(collection)
            status.state = EmbeddingProviderState.DEGRADED
            status.degradedReason = "vector_store_deadline_exceeded:${collection}"
            return status
        }
        this.recreate(collection, vectors)
    }

    public func backup(collection: String): VectorBackup {
        this.backupWithDeadline(collection, 0)
    }

    public func backupWithDeadline(collection: String, deadlineAtMillis: Int64): VectorBackup {
        let backup = VectorBackup()
        backup.collection = collection
        if (ckbDeadlineExceeded(deadlineAtMillis)) {
            backup.valid = false
            backup.diagnostic = "vector_store_deadline_exceeded:${collection}"
            return backup
        }
        if (!this.available) {
            backup.valid = false
            backup.diagnostic = "vector_store_unavailable"
            return backup
        }
        let stored = this.findCollection(collection)
        if (stored.name == "") {
            backup.valid = false
            backup.diagnostic = "collection_missing"
            return backup
        }
        for (record in stored.records) {
            backup.records.add(record)
        }
        backup.valid = true
        backup.diagnostic = "ok"
        backup
    }

    public func restore(backup: VectorBackup): VectorStoreStatus {
        if (!backup.valid) {
            let status = this.status(backup.collection)
            status.state = EmbeddingProviderState.DEGRADED
            status.degradedReason = backup.diagnostic
            return status
        }
        this.recreate(backup.collection, backup.records)
    }

    public func lookupBatchWithDeadline(collection: String, pointIds: ArrayList<String>, deadlineAtMillis: Int64): VectorLookupResult {
        let result = VectorLookupResult()
        result.requested = pointIds.size
        result.peakBufferedRecords = pointIds.size
        if (pointIds.size > CkbCandidateDurableSchema.VECTOR_LOOKUP_BATCH_SIZE) {
            result.status = "vector_lookup_batch_limit_exceeded"
            result.diagnostic = "vector_lookup_batch_limit_exceeded:${pointIds.size}:${CkbCandidateDurableSchema.VECTOR_LOOKUP_BATCH_SIZE}"
            return result
        }
        if (ckbDeadlineExceeded(deadlineAtMillis)) {
            result.status = "vector_store_deadline_exceeded"
            result.diagnostic = "vector_store_deadline_exceeded:${collection}"
            return result
        }
        if (!this.available) {
            result.status = "vector_store_unavailable"
            result.diagnostic = result.status
            return result
        }
        let stored = this.findCollection(collection)
        let found = HashSet<String>()
        if (stored.name != "") {
            for (pointId in pointIds) {
                var record = VectorRecord()
                if (stored.pointIndex.contains(pointId)) {
                    record = stored.records[stored.pointIndex[pointId]]
                } else if (stored.reuseIndex.contains(pointId)) {
                    record = stored.records[stored.reuseIndex[pointId]]
                }
                if (record.id != "") {
                    let stable = ckbVectorRecordStablePointId(record)
                    if (!found.contains(stable)) { result.records.add(record); found.add(stable) }
                }
            }
        }
        result.ok = true
        result.status = "ok"
        result.found = result.records.size
        if (result.records.size > result.peakBufferedRecords) { result.peakBufferedRecords = result.records.size }
        result
    }

    private func findCollection(collection: String): LocalVectorCollection {
        for (stored in this.collections) {
            if (stored.name == collection) {
                return stored
            }
        }
        LocalVectorCollection()
    }

    private func ensureCollection(collection: String): LocalVectorCollection {
        for (stored in this.collections) {
            if (stored.name == collection) {
                return stored
            }
        }
        let stored = LocalVectorCollection()
        stored.name = collection
        this.collections.add(stored)
        stored
    }
}

public class QdrantVectorStoreConfig {
    public var endpoint: String = ""
    public var dimensions: Int64 = 0
    public var distance: String = "Cosine"
    public var timeoutMillis: Int64 = 10000
    public var retryCount: Int64 = 2
    public var apiKey: String = ""

    public init() {}
}

private class QdrantCachedCollection {
    public var collection: String = ""
    public var records: ArrayList<VectorRecord> = ArrayList<VectorRecord>()
    public var count: Int64 = 0
    public var disabled: Bool = false

    public init() {}
}

private class QdrantJsonStringScan {
    public var ok: Bool = false
    public var value: String = ""
    public var end: Int64 = 0
    public var malformed: Bool = false

    public init() {}
}

private class QdrantJsonStringUnescape {
    public var value: String = ""
    public var malformed: Bool = false

    public init() {}
}

private class QdrantScrollPage {
    public var ok: Bool = false
    public var diagnostic: String = ""
    public var records: ArrayList<VectorRecord> = ArrayList<VectorRecord>()
    public var nextOffsetJson: String = ""

    public init() {}
}

private class QdrantRetrievePage {
    public var ok: Bool = false
    public var diagnostic: String = ""
    public var records: ArrayList<VectorRecord> = ArrayList<VectorRecord>()

    public init() {}
}

public class QdrantVectorStore <: VectorStore {
    private let config: QdrantVectorStoreConfig
    private let executor: HttpRequestExecutor
    private var lastStatus: VectorStoreStatus = VectorStoreStatus()
    private var cache: ArrayList<QdrantCachedCollection> = ArrayList<QdrantCachedCollection>()

    public init(config: QdrantVectorStoreConfig, executor!: HttpRequestExecutor) {
        this.config = config
        this.executor = executor
    }

    public init(endpoint: String, dimensions: Int64, distance: String, executor!: HttpRequestExecutor) {
        let config = QdrantVectorStoreConfig()
        config.endpoint = endpoint
        config.dimensions = dimensions
        config.distance = distance
        this.config = config
        this.executor = executor
    }

    public func upsert(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        let validation = this.validateVectors(collection, vectors)
        if (validation.degradedReason != "") {
            this.lastStatus = validation
            return validation
        }
        if (vectors.size == 0) {
            let status = this.baseStatus(collection)
            status.state = EmbeddingProviderState.READY
            status.count = 0
            this.lastStatus = status
            return status
        }
        let response = this.execute("PUT", "${this.collectionUrl(collection)}/points?wait=true", qdrantUpsertBody(vectors))
        let status = this.statusFromWriteResponse(collection, response, "upsert")
        if (status.state == EmbeddingProviderState.READY) {
            status.count = vectors.size
            status.dimension = this.config.dimensions
            this.remember(collection, vectors)
        }
        this.lastStatus = status
        status
    }

    public func upsertBatch(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        let validation = this.validateVectors(collection, vectors)
        if (validation.degradedReason != "") {
            this.lastStatus = validation
            return validation
        }
        if (vectors.size == 0) {
            let status = this.baseStatus(collection)
            status.state = EmbeddingProviderState.READY
            status.count = this.cached(collection).count
            this.lastStatus = status
            return status
        }
        let response = this.execute("PUT", "${this.collectionUrl(collection)}/points?wait=true", qdrantUpsertBody(vectors))
        let status = this.statusFromWriteResponse(collection, response, "upsert")
        if (status.state == EmbeddingProviderState.READY) {
            this.rememberBatch(collection, vectors)
            status.count = this.cached(collection).count
            status.dimension = this.config.dimensions
        }
        this.lastStatus = status
        status
    }

    public func upsertBatchWithDeadline(collection: String, vectors: ArrayList<VectorRecord>, deadlineAtMillis: Int64): VectorStoreStatus {
        if (ckbDeadlineExceeded(deadlineAtMillis)) {
            let status = this.baseStatus(collection)
            status.state = EmbeddingProviderState.DEGRADED
            status.count = this.cached(collection).count
            status.degradedReason = "vector_store_deadline_exceeded:${collection}"
            this.lastStatus = status
            return status
        }
        let validation = this.validateVectors(collection, vectors)
        if (validation.degradedReason != "") {
            this.lastStatus = validation
            return validation
        }
        if (vectors.size == 0) {
            let status = this.baseStatus(collection)
            status.state = EmbeddingProviderState.READY
            status.count = this.cached(collection).count
            this.lastStatus = status
            return status
        }
        let response = this.executeWithDeadline("PUT", "${this.collectionUrl(collection)}/points?wait=true", qdrantUpsertBody(vectors), deadlineAtMillis)
        let status = this.statusFromWriteResponse(collection, response, "upsert")
        if (status.state == EmbeddingProviderState.READY) {
            this.rememberBatch(collection, vectors)
            status.count = this.cached(collection).count
            status.dimension = this.config.dimensions
        }
        this.lastStatus = status
        status
    }

    public func search(collection: String, queryVector: ArrayList<Float64>, filters: VectorSearchFilters, topK: Int64): ArrayList<VectorSearchResult> {
        let out = ArrayList<VectorSearchResult>()
        if (topK <= 0 || queryVector.size == 0) {
            return out
        }
        if (this.config.dimensions > 0 && queryVector.size != this.config.dimensions) {
            this.lastStatus = this.degradedStatus(collection, "dimension_mismatch")
            return out
        }
        let response = this.execute("POST", "${this.collectionUrl(collection)}/points/query", qdrantQueryBody(queryVector, filters, topK))
        if (!qdrantHttpOk(response)) {
            this.lastStatus = this.statusFromHttpResponse(collection, response, "query")
            return out
        }
        let parsed = qdrantParseSearchResponse(response.body, filters, topK)
        if (!qdrantBodyLooksOk(response.body)) {
            this.lastStatus = this.degradedStatus(collection, "malformed_json")
            return out
        }
        for (item in parsed) {
            insertVectorResult(out, item.record, item.score, topK)
        }
        let status = this.baseStatus(collection)
        status.state = EmbeddingProviderState.READY
        status.count = out.size
        this.lastStatus = status
        out
    }

    public func status(collection: String): VectorStoreStatus {
        let response = this.execute("GET", this.collectionUrl(collection), "")
        let status = this.statusFromCollectionResponse(collection, response)
        this.lastStatus = status
        status
    }

    public func ensureReadyCollection(collection: String): VectorStoreStatus {
        let current = this.status(collection)
        if (current.state == EmbeddingProviderState.READY) {
            return this.statusWithCollectionConfigCheck(collection, current)
        }
        if (current.degradedReason == "collection_missing") {
            let created = this.createCollection(collection)
            if (created.state == EmbeddingProviderState.READY) {
                this.lastStatus = created
                return created
            }
            if (created.degradedReason == "http_409") {
                let afterConflict = this.status(collection)
                if (afterConflict.state == EmbeddingProviderState.READY) {
                    let checked = this.statusWithCollectionConfigCheck(collection, afterConflict)
                    if (checked.state == EmbeddingProviderState.READY) {
                        checked.degradedReason = "already_exists_ready"
                    }
                    this.lastStatus = checked
                    return checked
                }
                this.lastStatus = afterConflict
                return afterConflict
            }
            this.lastStatus = created
            return created
        }
        current
    }

    public func clear(collection: String): VectorStoreStatus {
        let response = this.execute("DELETE", this.collectionUrl(collection), "")
        let status = this.statusFromClearResponse(collection, response)
        if (status.state == EmbeddingProviderState.READY) {
            this.remember(collection, ArrayList<VectorRecord>())
        }
        this.lastStatus = status
        status
    }

    private func clearWithDeadline(collection: String, deadlineAtMillis: Int64): VectorStoreStatus {
        if (ckbDeadlineExceeded(deadlineAtMillis)) {
            let status = this.baseStatus(collection)
            status.state = EmbeddingProviderState.DEGRADED
            status.count = this.cached(collection).count
            status.degradedReason = "vector_store_deadline_exceeded:${collection}"
            this.lastStatus = status
            return status
        }
        let response = this.executeWithDeadline("DELETE", this.collectionUrl(collection), "", deadlineAtMillis)
        let status = this.statusFromClearResponse(collection, response)
        if (status.state == EmbeddingProviderState.READY) {
            this.remember(collection, ArrayList<VectorRecord>())
        }
        this.lastStatus = status
        status
    }

    public func deleteCollection(collection: String): VectorStoreStatus {
        this.clear(collection)
    }

    public func recreate(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        let validation = this.validateVectors(collection, vectors)
        if (validation.degradedReason != "") {
            this.lastStatus = validation
            return validation
        }
        let cleared = this.clear(collection)
        if (cleared.state == EmbeddingProviderState.DOWN || (cleared.state == EmbeddingProviderState.DEGRADED && cleared.degradedReason != "collection_missing")) {
            this.lastStatus = cleared
            return cleared
        }
        let created = this.createCollection(collection)
        if (created.state != EmbeddingProviderState.READY) {
            this.lastStatus = created
            return created
        }
        if (vectors.size == 0) {
            this.lastStatus = created
            return created
        }
        this.upsert(collection, vectors)
    }

    public func recreateWithDeadline(collection: String, vectors: ArrayList<VectorRecord>, deadlineAtMillis: Int64): VectorStoreStatus {
        if (ckbDeadlineExceeded(deadlineAtMillis)) {
            let status = this.baseStatus(collection)
            status.state = EmbeddingProviderState.DEGRADED
            status.degradedReason = "vector_store_deadline_exceeded:${collection}"
            this.lastStatus = status
            return status
        }
        let validation = this.validateVectors(collection, vectors)
        if (validation.degradedReason != "") {
            this.lastStatus = validation
            return validation
        }
        let cleared = this.clearWithDeadline(collection, deadlineAtMillis)
        if (cleared.state == EmbeddingProviderState.DOWN || (cleared.state == EmbeddingProviderState.DEGRADED && cleared.degradedReason != "collection_missing")) {
            this.lastStatus = cleared
            return cleared
        }
        if (ckbDeadlineExceeded(deadlineAtMillis)) {
            let status = this.baseStatus(collection)
            status.state = EmbeddingProviderState.DEGRADED
            status.degradedReason = "vector_store_deadline_exceeded:${collection}"
            this.lastStatus = status
            return status
        }
        let created = this.createCollectionWithDeadline(collection, deadlineAtMillis)
        if (created.state != EmbeddingProviderState.READY) {
            this.lastStatus = created
            return created
        }
        if (vectors.size == 0) {
            this.lastStatus = created
            return created
        }
        this.upsertBatchWithDeadline(collection, vectors, deadlineAtMillis)
    }

    public func backup(collection: String): VectorBackup {
        this.backupWithDeadline(collection, 0)
    }

    public func backupWithDeadline(collection: String, deadlineAtMillis: Int64): VectorBackup {
        if (ckbDeadlineExceeded(deadlineAtMillis)) {
            let backup = VectorBackup()
            backup.collection = collection
            backup.valid = false
            backup.diagnostic = "vector_store_deadline_exceeded:${collection}"
            return backup
        }
        let backup = VectorBackup()
        backup.collection = collection
        let cached = this.cached(collection)
        if (cached.collection != "" && !cached.disabled) {
            for (record in cached.records) {
                backup.records.add(record)
            }
            backup.valid = true
            backup.diagnostic = "ok"
            return backup
        }
        this.scrollBackupWithDeadline(collection, deadlineAtMillis)
    }

    public func restore(backup: VectorBackup): VectorStoreStatus {
        if (!backup.valid) {
            let status = this.baseStatus(backup.collection)
            status.state = EmbeddingProviderState.DEGRADED
            status.degradedReason = backup.diagnostic
            this.lastStatus = status
            return status
        }
        this.recreate(backup.collection, backup.records)
    }

    public func lookupBatchWithDeadline(collection: String, pointIds: ArrayList<String>, deadlineAtMillis: Int64): VectorLookupResult {
        let result = VectorLookupResult()
        result.requested = pointIds.size
        result.peakBufferedRecords = pointIds.size
        if (pointIds.size > CkbCandidateDurableSchema.VECTOR_LOOKUP_BATCH_SIZE) {
            result.status = "vector_lookup_batch_limit_exceeded"
            result.diagnostic = "vector_lookup_batch_limit_exceeded:${pointIds.size}:${CkbCandidateDurableSchema.VECTOR_LOOKUP_BATCH_SIZE}"
            return result
        }
        if (ckbDeadlineExceeded(deadlineAtMillis)) {
            result.status = "vector_store_deadline_exceeded"
            result.diagnostic = "vector_store_deadline_exceeded:${collection}"
            return result
        }
        let cached = this.cached(collection)
        let requested = HashSet<String>(pointIds)
        let found = HashSet<String>()
        if (cached.collection != "" && !cached.disabled) {
            for (record in cached.records) {
                let pointId = ckbVectorRecordStablePointId(record)
                if (requested.contains(pointId) && !found.contains(pointId)) { result.records.add(record); found.add(pointId) }
            }
        }
        let missing = ArrayList<String>()
        for (pointId in pointIds) { if (!found.contains(pointId)) { missing.add(pointId) } }
        if (missing.size > 0) {
            let response = this.executeWithDeadline("POST", "${this.collectionUrl(collection)}/points", qdrantRetrieveBody(missing), deadlineAtMillis)
            if (!qdrantHttpOk(response)) {
                result.status = this.statusFromHttpResponse(collection, response, "retrieve").degradedReason
                result.diagnostic = result.status
                return result
            }
            if (!qdrantBodyLooksOk(response.body)) { result.status = "malformed_json"; result.diagnostic = "qdrant_retrieve_malformed_json"; return result }
            let page = qdrantParseRetrievePage(response.body, HashSet<String>(missing))
            if (!page.ok) { result.status = page.diagnostic; result.diagnostic = page.diagnostic; return result }
            for (record in page.records) {
                let pointId = ckbVectorRecordStablePointId(record)
                if (!found.contains(pointId)) { result.records.add(record); found.add(pointId) }
            }
        }
        result.ok = true
        result.status = "ok"
        result.found = result.records.size
        if (result.records.size > result.peakBufferedRecords) { result.peakBufferedRecords = result.records.size }
        result
    }

    public func lastOperationStatus(): VectorStoreStatus {
        this.lastStatus
    }

    private func createCollection(collection: String): VectorStoreStatus {
        if (this.config.dimensions <= 0) {
            return this.degradedStatus(collection, "qdrant_missing_dimensions")
        }
        let response = this.execute("PUT", this.collectionUrl(collection), qdrantCreateCollectionBody(this.config.dimensions, this.config.distance))
        this.statusFromWriteResponse(collection, response, "create_collection")
    }

    private func createCollectionWithDeadline(collection: String, deadlineAtMillis: Int64): VectorStoreStatus {
        if (this.config.dimensions <= 0) {
            return this.degradedStatus(collection, "qdrant_missing_dimensions")
        }
        let response = this.executeWithDeadline("PUT", this.collectionUrl(collection), qdrantCreateCollectionBody(this.config.dimensions, this.config.distance), deadlineAtMillis)
        this.statusFromWriteResponse(collection, response, "create_collection")
    }

    private func statusWithCollectionConfigCheck(collection: String, status: VectorStoreStatus): VectorStoreStatus {
        let mismatch = this.collectionConfigMismatch(status)
        if (mismatch == "") {
            return status
        }
        let degraded = this.baseStatus(collection)
        degraded.state = EmbeddingProviderState.DEGRADED
        degraded.count = status.count
        degraded.dimension = status.dimension
        degraded.distance = status.distance
        degraded.degradedReason = mismatch
        degraded
    }

    private func collectionConfigMismatch(status: VectorStoreStatus): String {
        if (this.config.dimensions > 0 && status.dimension > 0 && status.dimension != this.config.dimensions) {
            return "dimension_mismatch:${status.dimension}:${this.config.dimensions}"
        }
        let expectedDistance = this.config.distance.trimAscii().toAsciiLower()
        let actualDistance = status.distance.trimAscii().toAsciiLower()
        if (expectedDistance != "" && actualDistance != "" && expectedDistance != actualDistance) {
            return "distance_mismatch:${status.distance}:${this.config.distance}"
        }
        ""
    }

    private func execute(method: String, url: String, body: String): HttpExecutionResponse {
        let request = HttpExecutionRequest()
        request.method = method
        request.url = url
        request.accept = "application/json"
        request.timeoutMillis = this.config.timeoutMillis
        request.retryCount = this.config.retryCount
        if (body != "") {
            request.contentType = "application/json"
            request.body = body
            request.headers.add("Content-Type: application/json")
        }
        if (this.config.apiKey != "") {
            request.headers.add("api-key: ${this.config.apiKey}")
        }
        try {
            this.executor.execute(request)
        } catch (_: Exception) {
            let response = HttpExecutionResponse()
            response.status = "transport_error"
            response.transportErrorClass = "exception"
            response.transportDiagnostic = "qdrant_executor_exception"
            response
        }
    }

    private func executeWithDeadline(method: String, url: String, body: String, deadlineAtMillis: Int64): HttpExecutionResponse {
        if (ckbDeadlineExceeded(deadlineAtMillis)) {
            let response = HttpExecutionResponse()
            response.status = "timeout"
            response.transportErrorClass = "timeout"
            response.transportDiagnostic = "qdrant_deadline_exceeded"
            return response
        }
        let request = HttpExecutionRequest()
        request.method = method
        request.url = url
        request.accept = "application/json"
        let remaining = ckbRemainingMillis(deadlineAtMillis)
        request.timeoutMillis = if (remaining > 0 && remaining < this.config.timeoutMillis) { remaining } else { this.config.timeoutMillis }
        request.retryCount = this.config.retryCount
        if (body != "") {
            request.contentType = "application/json"
            request.body = body
            request.headers.add("Content-Type: application/json")
        }
        if (this.config.apiKey != "") {
            request.headers.add("api-key: ${this.config.apiKey}")
        }
        try {
            this.executor.execute(request)
        } catch (_: Exception) {
            let response = HttpExecutionResponse()
            response.status = "transport_error"
            response.transportErrorClass = "exception"
            response.transportDiagnostic = "qdrant_executor_exception"
            response
        }
    }

    private func validateVectors(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        let status = this.baseStatus(collection)
        if (this.config.endpoint == "") {
            status.state = EmbeddingProviderState.DOWN
            status.degradedReason = "qdrant_missing_endpoint"
            return status
        }
        if (this.config.dimensions <= 0) {
            status.state = EmbeddingProviderState.DEGRADED
            status.degradedReason = "qdrant_missing_dimensions"
            return status
        }
        for (record in vectors) {
            if (record.vector.size == 0) {
                status.state = EmbeddingProviderState.DEGRADED
                status.degradedReason = "empty_vector"
                return status
            }
            if (record.vector.size != this.config.dimensions) {
                status.state = EmbeddingProviderState.DEGRADED
                status.degradedReason = "dimension_mismatch"
                return status
            }
        }
        status
    }

    private func statusFromCollectionResponse(collection: String, response: HttpExecutionResponse): VectorStoreStatus {
        if (!qdrantHttpOk(response)) {
            return this.statusFromHttpResponse(collection, response, "status")
        }
        if (!qdrantBodyLooksOk(response.body)) {
            return this.degradedStatus(collection, "malformed_json")
        }
        let status = qdrantParseCollectionStatus(response.body)
        status.backend = "qdrant"
        status.collection = collection
        if (status.state == "") {
            status.state = EmbeddingProviderState.DEGRADED
            status.degradedReason = "malformed_json"
        }
        if (status.dimension == 0) {
            status.dimension = this.config.dimensions
        }
        status
    }

    private func statusFromClearResponse(collection: String, response: HttpExecutionResponse): VectorStoreStatus {
        let status = this.baseStatus(collection)
        if (response.statusCode == 404 || response.status == "http_404") {
            status.state = EmbeddingProviderState.READY
            status.count = 0
            status.degradedReason = ""
            return status
        }
        if (!qdrantHttpOk(response)) {
            return this.statusFromHttpResponse(collection, response, "clear")
        }
        if (!qdrantBodyLooksOk(response.body)) {
            status.state = EmbeddingProviderState.DEGRADED
            status.degradedReason = "malformed_json"
            return status
        }
        status.state = EmbeddingProviderState.READY
        status.count = 0
        status
    }

    private func statusFromWriteResponse(collection: String, response: HttpExecutionResponse, operation: String): VectorStoreStatus {
        let status = this.baseStatus(collection)
        if (!qdrantHttpOk(response)) {
            return this.statusFromHttpResponse(collection, response, operation)
        }
        if (!qdrantBodyLooksOk(response.body)) {
            status.state = EmbeddingProviderState.DEGRADED
            status.degradedReason = "malformed_json"
            return status
        }
        status.state = EmbeddingProviderState.READY
        status.dimension = this.config.dimensions
        status
    }

    private func statusFromHttpResponse(collection: String, response: HttpExecutionResponse, operation: String): VectorStoreStatus {
        let status = this.baseStatus(collection)
        if (response.statusCode == 404 || response.status == "http_404") {
            status.state = EmbeddingProviderState.DEGRADED
            status.degradedReason = "collection_missing"
            return status
        }
        if (response.statusCode == 409 || response.status == "http_409") {
            status.state = EmbeddingProviderState.DEGRADED
            status.degradedReason = "http_409"
            return status
        }
        if (response.status == "unsupported_method") {
            status.state = EmbeddingProviderState.DEGRADED
            status.degradedReason = "qdrant_http_execute_unavailable"
            return status
        }
        if (response.status == "timeout" || response.status == "transport_error" || response.statusCode >= 500) {
            status.state = EmbeddingProviderState.DOWN
            status.degradedReason = if (response.transportErrorClass != "") { response.transportErrorClass } else { "qdrant_${operation}_failed" }
            return status
        }
        status.state = EmbeddingProviderState.DEGRADED
        status.degradedReason = if (response.status != "") { response.status } else { "qdrant_${operation}_failed" }
        status
    }

    private func baseStatus(collection: String): VectorStoreStatus {
        let status = VectorStoreStatus()
        status.backend = "qdrant"
        status.collection = collection
        status.dimension = this.config.dimensions
        status.distance = this.config.distance
        status.state = EmbeddingProviderState.DEGRADED
        status
    }

    private func degradedStatus(collection: String, reason: String): VectorStoreStatus {
        let status = this.baseStatus(collection)
        status.state = EmbeddingProviderState.DEGRADED
        status.degradedReason = reason
        status
    }

    private func collectionUrl(collection: String): String {
        "${qdrantTrimRightSlash(this.config.endpoint)}/collections/${qdrantSafeCollection(collection)}"
    }

    private func cached(collection: String): QdrantCachedCollection {
        for (entry in this.cache) {
            if (entry.collection == collection) {
                return entry
            }
        }
        QdrantCachedCollection()
    }

    private func remember(collection: String, vectors: ArrayList<VectorRecord>): Unit {
        var entry = this.cached(collection)
        if (entry.collection == "") {
            entry = QdrantCachedCollection()
            entry.collection = collection
            this.cache.add(entry)
        }
        entry.records.clear()
        entry.count = vectors.size
        entry.disabled = vectors.size > CkbCandidateDurableSchema.QDRANT_CACHE_MAX_RECORDS
        if (!entry.disabled) {
            for (record in vectors) {
                entry.records.add(record)
            }
        }
    }

    private func rememberBatch(collection: String, vectors: ArrayList<VectorRecord>): Unit {
        var entry = this.cached(collection)
        if (entry.collection == "") {
            entry = QdrantCachedCollection()
            entry.collection = collection
            this.cache.add(entry)
        }
        if (entry.disabled) {
            entry.count += vectors.size
            return
        }
        let merged = ArrayList<VectorRecord>()
        for (existing in entry.records) {
            var replaced = false
            for (record in vectors) {
                if (vectorPointIdentity(existing) == vectorPointIdentity(record)) {
                    replaced = true
                }
            }
            if (!replaced) {
                merged.add(existing)
            }
        }
        for (record in vectors) {
            merged.add(record)
        }
        entry.records.clear()
        entry.count = merged.size
        if (merged.size > CkbCandidateDurableSchema.QDRANT_CACHE_MAX_RECORDS) {
            entry.disabled = true
            return
        }
        for (record in merged) {
            entry.records.add(record)
        }
    }

    private func scrollBackupWithDeadline(collection: String, deadlineAtMillis: Int64): VectorBackup {
        let backup = VectorBackup()
        backup.collection = collection
        var offsetJson = ""
        var pages: Int64 = 0
        while (pages < 1000) {
            if (ckbDeadlineExceeded(deadlineAtMillis)) {
                backup.valid = false
                backup.diagnostic = "qdrant_scroll_deadline_exceeded:${collection}:pages=${pages}"
                return backup
            }
            pages += 1
            let response = this.executeWithDeadline("POST", "${this.collectionUrl(collection)}/points/scroll", qdrantScrollBody(offsetJson), deadlineAtMillis)
            if (!qdrantHttpOk(response)) {
                backup.valid = false
                backup.diagnostic = this.statusFromHttpResponse(collection, response, "scroll").degradedReason
                return backup
            }
            if (!qdrantBodyLooksOk(response.body)) {
                backup.valid = false
                backup.diagnostic = "malformed_json"
                return backup
            }
            let page = qdrantParseScrollPage(response.body)
            if (!page.ok) {
                backup.valid = false
                backup.diagnostic = page.diagnostic
                return backup
            }
            for (record in page.records) {
                backup.records.add(record)
            }
            if (page.nextOffsetJson == "") {
                backup.valid = true
                backup.diagnostic = "ok"
                this.remember(collection, backup.records)
                return backup
            }
            offsetJson = page.nextOffsetJson
        }
        backup.valid = false
        backup.diagnostic = "qdrant_scroll_page_limit_exceeded"
        backup
    }
}

private func qdrantCreateCollectionBody(dimensions: Int64, distance: String): String {
    "{\"vectors\":{\"size\":${dimensions},\"distance\":\"${qdrantJsonEscape(distance)}\"}}"
}

private func qdrantUpsertBody(vectors: ArrayList<VectorRecord>): String {
    var out = "{\"points\":["
    for (i in 0..vectors.size) {
        if (i > 0) {
            out += ","
        }
        let record = vectors[i]
        out += "{\"id\":${qdrantStablePointId(vectorPointIdentity(record))},\"vector\":${qdrantVectorJson(record.vector)},\"payload\":${qdrantPayloadJson(record)}}"
    }
    out + "]}"
}

private func qdrantQueryBody(queryVector: ArrayList<Float64>, filters: VectorSearchFilters, topK: Int64): String {
    var out = "{\"query\":${qdrantVectorJson(queryVector)},\"limit\":${topK},\"with_payload\":true"
    let filter = qdrantFilterJson(filters)
    if (filter != "") {
        out += ",\"filter\":${filter}"
    }
    out + "}"
}

private func qdrantScrollBody(offsetJson: String): String {
    var out = "{\"limit\":256,\"with_payload\":true,\"with_vector\":true"
    if (offsetJson.trimAscii() != "") {
        out += ",\"offset\":${offsetJson.trimAscii()}"
    }
    out + "}"
}

private func qdrantRetrieveBody(pointIds: ArrayList<String>): String {
    var out = "{\"ids\":["
    for (index in 0..pointIds.size) {
        if (index > 0) { out += "," }
        out += qdrantStablePointId(pointIds[index])
    }
    out + "],\"with_payload\":true,\"with_vector\":true}"
}

public func qdrantStablePointId(raw: String): String {
    var hash: Int64 = 5381
    let modulus: Int64 = 100000000000000000
    let bytes = raw.toArray()
    for (b in bytes) {
        hash = ((hash * 33) % modulus + (Int64(b) % modulus)) % modulus
    }
    if (hash == 0) {
        hash = 1
    }
    "${hash}"
}

private func qdrantPayloadJson(record: VectorRecord): String {
    let metadata = record.metadata
    var out = "{"
    out += "\"ckb_id\":\"${qdrantJsonEscape(record.id)}\""
    out += ",\"pointId\":\"${qdrantJsonEscape(vectorPointIdentity(record))}\""
    out += ",\"title\":\"${qdrantJsonEscape(record.title)}\""
    out += ",\"chunk\":\"${qdrantJsonEscape(record.chunk)}\""
    out += ",\"citation\":\"${qdrantJsonEscape(record.citation)}\""
    out += ",\"sourceId\":\"${qdrantJsonEscape(metadata.sourceId)}\""
    out += ",\"sourceType\":\"${qdrantJsonEscape(metadata.sourceType)}\""
    out += ",\"sourceUrl\":\"${qdrantJsonEscape(metadata.sourceUrl)}\""
    out += ",\"repo\":\"${qdrantJsonEscape(metadata.repo)}\""
    out += ",\"path\":\"${qdrantJsonEscape(metadata.path)}\""
    out += ",\"symbol\":\"${qdrantJsonEscape(metadata.symbol)}\""
    out += ",\"trustLevel\":\"${qdrantJsonEscape(metadata.trustLevel)}\""
    out += ",\"reviewState\":\"${qdrantJsonEscape(metadata.reviewState)}\""
    out += ",\"knowledgeVersion\":\"${qdrantJsonEscape(metadata.knowledgeVersion)}\""
    out + "}"
}

private func qdrantFilterJson(filters: VectorSearchFilters): String {
    let clauses = ArrayList<String>()
    qdrantAddFilterClause(clauses, "repo", filters.repo)
    qdrantAddFilterClause(clauses, "sourceType", filters.sourceType)
    qdrantAddFilterClause(clauses, "trustLevel", filters.trustLevel)
    qdrantAddFilterClause(clauses, "reviewState", filters.reviewState)
    if (clauses.size == 0) {
        return ""
    }
    var out = "{\"must\":["
    for (i in 0..clauses.size) {
        if (i > 0) {
            out += ","
        }
        out += clauses[i]
    }
    out + "]}"
}

private func qdrantAddFilterClause(clauses: ArrayList<String>, key: String, value: String): Unit {
    if (value == "") {
        return
    }
    clauses.add("{\"key\":\"${qdrantJsonEscape(key)}\",\"match\":{\"value\":\"${qdrantJsonEscape(value)}\"}}")
}

private func qdrantVectorJson(vector: ArrayList<Float64>): String {
    var out = "["
    for (i in 0..vector.size) {
        if (i > 0) {
            out += ","
        }
        out += "${vector[i]}"
    }
    out + "]"
}

private func qdrantParseCollectionStatus(body: String): VectorStoreStatus {
    let status = VectorStoreStatus()
    let result = qdrantJsonObjectField(body, "result")
    if (result == "") {
        return status
    }
    let qdrantState = qdrantJsonStringField(result, "status")
    status.count = qdrantJsonIntField(result, "points_count", qdrantJsonIntField(result, "pointsCount", qdrantJsonIntField(result, "indexed_vectors_count", 0)))
    status.dimension = qdrantJsonIntField(result, "size", qdrantNestedVectorSize(result))
    status.distance = qdrantNestedVectorDistance(result)
    if (qdrantState == "green" || qdrantState == "ok" || qdrantState == "") {
        status.state = EmbeddingProviderState.READY
    } else {
        status.state = EmbeddingProviderState.DEGRADED
        status.degradedReason = "qdrant_status_${qdrantState}"
    }
    status
}

private func qdrantNestedVectorSize(result: String): Int64 {
    let config = qdrantJsonObjectField(result, "config")
    if (config == "") {
        return 0
    }
    let params = qdrantJsonObjectField(config, "params")
    if (params == "") {
        return 0
    }
    let vectors = qdrantJsonObjectField(params, "vectors")
    if (vectors == "") {
        return 0
    }
    qdrantJsonIntField(vectors, "size", 0)
}

private func qdrantNestedVectorDistance(result: String): String {
    let config = qdrantJsonObjectField(result, "config")
    if (config == "") {
        return ""
    }
    let params = qdrantJsonObjectField(config, "params")
    if (params == "") {
        return ""
    }
    let vectors = qdrantJsonObjectField(params, "vectors")
    if (vectors == "") {
        return ""
    }
    qdrantJsonStringField(vectors, "distance")
}

private func qdrantParseSearchResponse(body: String, filters: VectorSearchFilters, topK: Int64): ArrayList<VectorSearchResult> {
    let out = ArrayList<VectorSearchResult>()
    let result = qdrantResultPayload(body)
    if (result == "") {
        return out
    }
    var points = qdrantJsonArrayField(result, "points")
    if (points == "" && result.startsWith("[")) {
        points = result
    }
    for (object in qdrantJsonObjectChunks(points)) {
        let payload = qdrantJsonObjectField(object, "payload")
        let record = qdrantRecordFromPayload(payload)
        if (record.id == "" || record.title == "" || record.chunk == "" || record.citation == "") {
            continue
        }
        if (!vectorRecordAllowed(record, filters)) {
            continue
        }
        let score = qdrantJsonFloatField(object, "score", 0.0)
        insertVectorResult(out, record, score, topK)
    }
    out
}

private func qdrantParseScrollPage(body: String): QdrantScrollPage {
    let page = QdrantScrollPage()
    let result = qdrantJsonObjectField(body, "result")
    if (result == "") {
        page.diagnostic = "malformed_json"
        return page
    }
    let points = qdrantJsonArrayField(result, "points")
    if (points == "") {
        page.diagnostic = "malformed_json"
        return page
    }
    for (object in qdrantJsonObjectChunks(points)) {
        let payload = qdrantJsonObjectField(object, "payload")
        let vector = qdrantParseVectorArray(qdrantJsonArrayField(object, "vector"))
        let record = qdrantRecordFromPayload(payload)
        if (record.id == "" || record.title == "" || record.chunk == "" || record.citation == "" || vector.size == 0) {
            continue
        }
        record.vector = vector
        page.records.add(record)
    }
    page.nextOffsetJson = qdrantNextOffsetJson(result)
    page.ok = true
    page.diagnostic = "ok"
    page
}

private func qdrantParseRetrievePage(body: String, requested: HashSet<String>): QdrantRetrievePage {
    let page = QdrantRetrievePage()
    let result = qdrantResultPayload(body)
    if (!result.startsWith("[")) { page.diagnostic = "qdrant_retrieve_malformed_json"; return page }
    for (object in qdrantJsonObjectChunks(result)) {
        let payload = qdrantJsonObjectField(object, "payload")
        let vector = qdrantParseVectorArray(qdrantJsonArrayField(object, "vector"))
        let record = qdrantRecordFromPayload(payload)
        let pointId = ckbVectorRecordStablePointId(record)
        if (pointId == "" || vector.size == 0 || !requested.contains(pointId)) { page.diagnostic = "qdrant_retrieve_record_invalid"; return page }
        record.vector = vector
        page.records.add(record)
    }
    page.ok = true
    page.diagnostic = "ok"
    page
}

private func qdrantParseVectorArray(raw: String): ArrayList<Float64> {
    let out = ArrayList<Float64>()
    let clean = raw.trimAscii()
    if (clean.size < 2 || clean[0] != UInt8(91) || clean[clean.size - 1] != UInt8(93)) {
        return out
    }
    let inner = clean[1..clean.size - 1].trimAscii()
    if (inner == "") {
        return out
    }
    for (part in inner.split(",")) {
        let token = part.trimAscii()
        if (token == "") {
            return ArrayList<Float64>()
        }
        try {
            out.add(Float64.parse(token))
        } catch (_: Exception) {
            return ArrayList<Float64>()
        }
    }
    out
}

private func qdrantNextOffsetJson(result: String): String {
    let start = qdrantJsonValueStart(result, "next_page_offset")
    if (start < 0 || start >= result.size) {
        return ""
    }
    if (result[start] == UInt8(34)) {
        let scan = qdrantReadJsonStringAt(result, start)
        if (!scan.ok || scan.value == "") {
            return ""
        }
        return "\"${qdrantJsonEscape(scan.value)}\""
    }
    var end = start
    while (end < result.size && result[end] != UInt8(44) && result[end] != UInt8(125) && result[end] != UInt8(93) && result[end] != UInt8(32) && result[end] != UInt8(10) && result[end] != UInt8(13) && result[end] != UInt8(9)) {
        end += 1
    }
    let raw = result[start..end].trimAscii()
    if (raw == "" || raw == "null") {
        return ""
    }
    raw
}

private func qdrantRecordFromPayload(payload: String): VectorRecord {
    let record = VectorRecord()
    if (payload == "") {
        return record
    }
    let metadata = KnowledgeMetadata()
    record.id = qdrantJsonStringField(payload, "ckb_id")
    if (record.id == "") {
        record.id = qdrantJsonStringField(payload, "id")
    }
    record.pointId = qdrantJsonStringField(payload, "pointId")
    record.title = qdrantJsonStringField(payload, "title")
    record.chunk = qdrantJsonStringField(payload, "chunk")
    record.citation = qdrantJsonStringField(payload, "citation")
    metadata.sourceId = qdrantJsonStringField(payload, "sourceId")
    metadata.sourceType = qdrantJsonStringField(payload, "sourceType")
    metadata.sourceUrl = qdrantJsonStringField(payload, "sourceUrl")
    metadata.repo = qdrantJsonStringField(payload, "repo")
    metadata.path = qdrantJsonStringField(payload, "path")
    metadata.symbol = qdrantJsonStringField(payload, "symbol")
    metadata.trustLevel = qdrantJsonStringField(payload, "trustLevel")
    metadata.reviewState = qdrantJsonStringField(payload, "reviewState")
    metadata.knowledgeVersion = qdrantJsonStringField(payload, "knowledgeVersion")
    record.metadata = metadata
    record
}

private func qdrantResultPayload(body: String): String {
    let object = qdrantJsonObjectField(body, "result")
    if (object != "") {
        return object
    }
    qdrantJsonArrayField(body, "result")
}

private func qdrantBodyLooksOk(body: String): Bool {
    if (body.trimAscii() == "") {
        return false
    }
    if (qdrantJsonHasMalformedString(body)) {
        return false
    }
    if (qdrantJsonStringField(body, "status") == "ok") {
        return true
    }
    qdrantJsonObjectField(body, "result") != "" || qdrantJsonArrayField(body, "result") != ""
}

private func qdrantHttpOk(response: HttpExecutionResponse): Bool {
    response.statusCode >= 200 && response.statusCode < 300
}

private func qdrantTrimRightSlash(raw: String): String {
    var out = raw.trimAscii()
    while (out.endsWith("/") && out.size > 0) {
        out = out[0..out.size - 1]
    }
    out
}

private func qdrantSafeCollection(raw: String): String {
    raw.replace("/", "_").replace("\\", "_").replace(" ", "_")
}

private func qdrantJsonEscape(raw: String): String {
    raw.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
}

private func qdrantJsonStringField(raw: String, key: String): String {
    let start = qdrantJsonValueStart(raw, key)
    if (start < 0 || start >= raw.size || raw[start] != UInt8(34)) {
        return ""
    }
    let scan = qdrantReadJsonStringAt(raw, start)
    if (!scan.ok) {
        return ""
    }
    scan.value
}

private func qdrantJsonObjectField(raw: String, key: String): String {
    let start = qdrantJsonValueStart(raw, key)
    if (start < 0) {
        return ""
    }
    qdrantJsonEnclosedAt(raw, start, "{", "}")
}

private func qdrantJsonArrayField(raw: String, key: String): String {
    let start = qdrantJsonValueStart(raw, key)
    if (start < 0) {
        return ""
    }
    qdrantJsonEnclosedAt(raw, start, "[", "]")
}

private func qdrantJsonIntField(raw: String, key: String, fallback: Int64): Int64 {
    let value = qdrantJsonScalarField(raw, key)
    if (value == "") {
        return fallback
    }
    try { Int64.parse(value) } catch (_: Exception) { fallback }
}

private func qdrantJsonFloatField(raw: String, key: String, fallback: Float64): Float64 {
    let value = qdrantJsonScalarField(raw, key)
    if (value == "") {
        return fallback
    }
    try { Float64.parse(value) } catch (_: Exception) { fallback }
}

private func qdrantJsonScalarField(raw: String, key: String): String {
    let start = qdrantJsonValueStart(raw, key)
    if (start < 0 || start >= raw.size) {
        return ""
    }
    if (raw[start] == UInt8(34)) {
        return qdrantJsonStringField(raw, key)
    }
    var end = start
    while (end < raw.size && raw[end] != UInt8(44) && raw[end] != UInt8(125) && raw[end] != UInt8(93) && raw[end] != UInt8(32) && raw[end] != UInt8(10) && raw[end] != UInt8(13) && raw[end] != UInt8(9)) {
        end += 1
    }
    raw[start..end].trimAscii()
}

private func qdrantJsonValueStart(raw: String, key: String): Int64 {
    var i: Int64 = 0
    var escaped = false
    while (i < raw.size) {
        let ch = raw[i]
        if (ch == UInt8(34) && !escaped) {
            let scan = qdrantReadJsonStringAt(raw, i)
            if (scan.ok && scan.value == key) {
                var colon = qdrantSkipJsonWhitespace(raw, scan.end)
                if (colon < raw.size && raw[colon] == UInt8(58)) {
                    return qdrantSkipJsonWhitespace(raw, colon + 1)
                }
            }
            i = if (scan.end > i) { scan.end } else { i + 1 }
            escaped = false
            continue
        }
        if (ch == UInt8(92) && !escaped) {
            escaped = true
        } else {
            escaped = false
        }
        i += 1
    }
    -1
}

private func qdrantReadJsonStringAt(raw: String, start: Int64): QdrantJsonStringScan {
    let scan = QdrantJsonStringScan()
    if (start < 0 || start >= raw.size || raw[start] != UInt8(34)) {
        return scan
    }
    var i = start + 1
    var escaped = false
    while (i < raw.size) {
        let ch = raw[i]
        if (escaped) {
            escaped = false
        } else if (ch == UInt8(92)) {
            escaped = true
        } else if (ch == UInt8(34)) {
            scan.end = i + 1
            let unescaped = qdrantJsonUnescapeStringScan(raw[start + 1..i])
            if (unescaped.malformed) {
                scan.malformed = true
                return scan
            }
            scan.ok = true
            scan.value = unescaped.value
            return scan
        }
        i += 1
    }
    scan.end = raw.size
    scan.malformed = true
    scan
}

private func qdrantSkipJsonWhitespace(raw: String, start: Int64): Int64 {
    var i = start
    while (i < raw.size && (raw[i] == UInt8(32) || raw[i] == UInt8(10) || raw[i] == UInt8(13) || raw[i] == UInt8(9))) {
        i += 1
    }
    i
}

private func qdrantJsonUnescapeString(raw: String): String {
    qdrantJsonUnescapeStringScan(raw).value
}

private func qdrantJsonUnescapeStringScan(raw: String): QdrantJsonStringUnescape {
    let result = QdrantJsonStringUnescape()
    let chars = raw.toRuneArray()
    let out = StringBuilder()
    var i: Int64 = 0
    while (i < chars.size) {
        let ch = chars[i]
        if (ch != r'\\') {
            out.append(ch)
            i += 1
            continue
        }
        if (i + 1 >= chars.size) {
            result.malformed = true
            break
        }
        let escaped = chars[i + 1]
        if (escaped == r'"') {
            out.append(r'"')
            i += 2
        } else if (escaped == r'\\') {
            out.append(r'\\')
            i += 2
        } else if (escaped == r'/') {
            out.append(r'/')
            i += 2
        } else if (escaped == r'n') {
            out.append(r'\n')
            i += 2
        } else if (escaped == r'r') {
            out.append(r'\r')
            i += 2
        } else if (escaped == r't') {
            out.append(r'\t')
            i += 2
        } else if (escaped == r'b') {
            out.append(qdrantUnicodeCodePointString(8))
            i += 2
        } else if (escaped == r'f') {
            out.append(qdrantUnicodeCodePointString(12))
            i += 2
        } else if (escaped == r'u') {
            if (i + 5 >= chars.size) {
                result.malformed = true
                break
            }
            var code: Int64 = 0
            var valid = true
            for (j in 0..4) {
                let digit = qdrantJsonHexValue(chars[i + 2 + j])
                if (digit < 0) {
                    valid = false
                } else {
                    code = code * 16 + digit
                }
            }
            if (!valid || (code >= 55296 && code <= 57343)) {
                result.malformed = true
                break
            }
            out.append(qdrantUnicodeCodePointString(code))
            i += 6
        } else {
            result.malformed = true
            break
        }
    }
    result.value = out.toString()
    result
}

private func qdrantUnicodeCodePointString(code: Int64): String {
    if (code < 0 || code > 65535 || (code >= 55296 && code <= 57343)) {
        return ""
    }
    let out = StringBuilder()
    out.append(Rune(UInt32(code)))
    out.toString()
}

private func qdrantJsonHexValue(ch: Rune): Int64 {
    let code = Int64(UInt32(ch))
    if (code >= Int64(UInt32(r'0')) && code <= Int64(UInt32(r'9'))) {
        return code - Int64(UInt32(r'0'))
    }
    if (code >= Int64(UInt32(r'a')) && code <= Int64(UInt32(r'f'))) {
        return 10 + code - Int64(UInt32(r'a'))
    }
    if (code >= Int64(UInt32(r'A')) && code <= Int64(UInt32(r'F'))) {
        return 10 + code - Int64(UInt32(r'A'))
    }
    -1
}

private func qdrantJsonHasMalformedString(raw: String): Bool {
    var i: Int64 = 0
    while (i < raw.size) {
        if (raw[i] == UInt8(34)) {
            let scan = qdrantReadJsonStringAt(raw, i)
            if (scan.malformed) {
                return true
            }
            i = if (scan.end > i) { scan.end } else { i + 1 }
        } else {
            i += 1
        }
    }
    false
}

private func qdrantJsonEnclosedAt(raw: String, start: Int64, open: String, close: String): String {
    let openByte = qdrantDelimiterByte(open)
    let closeByte = qdrantDelimiterByte(close)
    if (start < 0 || start >= raw.size || raw[start] != openByte) {
        return ""
    }
    var depth: Int64 = 0
    var escaped = false
    var inString = false
    var i = start
    while (i < raw.size) {
        let ch = raw[i]
        if (inString) {
            if (escaped) {
                escaped = false
            } else if (ch == UInt8(92)) {
                escaped = true
            } else if (ch == UInt8(34)) {
                inString = false
            }
        } else if (ch == UInt8(34)) {
            inString = true
        } else if (ch == openByte) {
            depth += 1
        } else if (ch == closeByte) {
            depth -= 1
            if (depth == 0) {
                return raw[start..i + 1]
            }
        }
        i += 1
    }
    ""
}

private func qdrantDelimiterByte(value: String): UInt8 {
    if (value == "{") {
        return UInt8(123)
    }
    if (value == "}") {
        return UInt8(125)
    }
    if (value == "[") {
        return UInt8(91)
    }
    UInt8(93)
}

private func qdrantJsonObjectChunks(body: String): ArrayList<String> {
    let objects = ArrayList<String>()
    var depth: Int64 = 0
    var escaped = false
    var inString = false
    var current = StringBuilder()
    for (ch in body.toRuneArray()) {
        let text = "${ch}"
        if (inString) {
            current.append(ch)
            if (escaped) {
                escaped = false
            } else if (ch == r'\\') {
                escaped = true
            } else if (ch == r'"') {
                inString = false
            }
            continue
        }
        if (ch == r'"') {
            if (depth > 0) {
                current.append(ch)
            }
            inString = true
        } else if (text == "{") {
            depth += 1
            current.append(ch)
        } else if (text == "}") {
            if (depth > 0) {
                current.append(ch)
            }
            depth -= 1
            if (depth == 0) {
                objects.add(current.toString())
                current = StringBuilder()
            }
        } else if (depth > 0) {
            current.append(ch)
        }
    }
    objects
}

public class GraphNodeTypes {
    public static let REPO: String = "repo"
    public static let PATH: String = "path"
    public static let SYMBOL: String = "symbol"
    public static let DOC: String = "doc"
    public static let SECTION: String = "section"
    public static let ISSUE: String = "issue"
    public static let PR: String = "pr"
    public static let COMMENT: String = "comment"
    public static let CITATION: String = "citation"
    public static let DERIVED_KNOWLEDGE: String = "derivedKnowledge"
}

public class GraphEdgeTypes {
    public static let CONTAINS: String = "contains"
    public static let DEFINES: String = "defines"
    public static let CITES: String = "cites"
    public static let DISCUSSES: String = "discusses"
    public static let DERIVED_FROM: String = "derivedFrom"
}

public class GraphNode {
    public var nodeId: String = ""
    public var nodeType: String = ""
    public var label: String = ""
    public var sourceId: String = ""
    public var knowledgeVersion: String = ""

    public init() {}
}

public class GraphEdge {
    public var edgeId: String = ""
    public var edgeType: String = ""
    public var fromNodeId: String = ""
    public var toNodeId: String = ""
    public var sourceId: String = ""
    public var knowledgeVersion: String = ""

    public init() {}
}

public class GraphQuery {
    public var sourceId: String = ""
    public var symbol: String = ""
    public var repo: String = ""
    public var budget: Int64 = 8
    public var knowledgeVersion: String = ""

    public init() {}
}

public class GraphContext {
    public var knowledgeVersion: String = ""
    public var nodes: ArrayList<GraphNode> = ArrayList<GraphNode>()
    public var edges: ArrayList<GraphEdge> = ArrayList<GraphEdge>()
    public var truncated: Bool = false
    public var budget: Int64 = 0

    public init() {}
}

public class GraphBuildResult {
    public var ok: Bool = true
    public var diagnostic: String = ""
    public var processed: Int64 = 0
    public var total: Int64 = 0
    public var nodes: ArrayList<GraphNode> = ArrayList<GraphNode>()
    public var edges: ArrayList<GraphEdge> = ArrayList<GraphEdge>()

    public init() {}
}

private class CkbGraphBuildCache {
    var valid: Bool = false
    var recordsEvidenceHash: String = ""
    var activeVersion: String = ""
    var nodeCount: Int64 = 0
    var edgeCount: Int64 = 0
    var graphEvidenceHash: String = ""
    var graph: GraphBuildResult = GraphBuildResult()

    init() {}
}

public func ckbGraphSnapshotBindingMatches(cacheValid: Bool, cachedActiveVersion: String,
    activeVersion: String, cachedRecordsEvidenceHash: String, activeRecordsEvidenceHash: String,
    cachedNodeCount: Int64, graphNodeCount: Int64, cachedEdgeCount: Int64, graphEdgeCount: Int64,
    cachedGraphEvidenceHash: String, graphEvidenceHash: String, graphStatus: VectorStoreStatus): Bool {
    cacheValid && cachedActiveVersion == activeVersion &&
        cachedRecordsEvidenceHash == activeRecordsEvidenceHash &&
        cachedNodeCount == graphNodeCount && cachedEdgeCount == graphEdgeCount &&
        cachedGraphEvidenceHash == graphEvidenceHash &&
        graphStatus.state == EmbeddingProviderState.READY && graphStatus.dimension == cachedNodeCount &&
        graphStatus.count == cachedEdgeCount
}

public interface GraphStore {
    func upsert(nodes: ArrayList<GraphNode>, edges: ArrayList<GraphEdge>): Unit
    func replace(nodes: ArrayList<GraphNode>, edges: ArrayList<GraphEdge>): Unit
    func clear(): Unit
    func neighbors(query: GraphQuery): GraphContext
    func status(): VectorStoreStatus
}

public class LocalGraphStore <: GraphStore {
    private var nodes: ArrayList<GraphNode> = ArrayList<GraphNode>()
    private var edges: ArrayList<GraphEdge> = ArrayList<GraphEdge>()
    private var activeVersion: String = ""

    public init() {}

    public func upsert(nodes: ArrayList<GraphNode>, edges: ArrayList<GraphEdge>): Unit {
        let nextNodes = ArrayList<GraphNode>()
        let nextEdges = ArrayList<GraphEdge>()
        var nextActiveVersion = ""
        for (node in nodes) {
            if (nextActiveVersion == "" && node.knowledgeVersion != "") {
                nextActiveVersion = node.knowledgeVersion
            }
            nextNodes.add(node)
        }
        for (edge in edges) {
            nextEdges.add(edge)
        }
        this.nodes = nextNodes
        this.edges = nextEdges
        this.activeVersion = nextActiveVersion
    }

    public func replace(nodes: ArrayList<GraphNode>, edges: ArrayList<GraphEdge>): Unit {
        this.nodes = nodes
        this.edges = edges
        this.activeVersion = ""
        for (node in nodes) {
            if (node.knowledgeVersion != "") { this.activeVersion = node.knowledgeVersion; break }
        }
    }

    public func clear(): Unit {
        this.nodes = ArrayList<GraphNode>()
        this.edges = ArrayList<GraphEdge>()
        this.activeVersion = ""
    }

    public func neighbors(query: GraphQuery): GraphContext {
        let context = GraphContext()
        context.knowledgeVersion = if (query.knowledgeVersion != "") { query.knowledgeVersion } else { this.activeVersion }
        context.budget = query.budget
        for (edge in this.edges) {
            if (context.edges.size >= query.budget) {
                context.truncated = true
                break
            }
            if (query.knowledgeVersion != "" && edge.knowledgeVersion != query.knowledgeVersion) {
                continue
            }
            if (this.edgeMatches(edge, query)) {
                context.edges.add(edge)
                this.addGraphNodeById(context, edge.fromNodeId, query.budget)
                this.addGraphNodeById(context, edge.toNodeId, query.budget)
            }
        }
        context
    }

    public func status(): VectorStoreStatus {
        let status = VectorStoreStatus()
        status.backend = "local-graph"
        status.collection = "active-graph"
        status.count = this.edges.size
        status.dimension = this.nodes.size
        status.state = EmbeddingProviderState.READY
        status
    }

    private func edgeMatches(edge: GraphEdge, query: GraphQuery): Bool {
        if (query.sourceId != "" && edge.sourceId == query.sourceId) {
            return true
        }
        let from = this.findNode(edge.fromNodeId)
        let to = this.findNode(edge.toNodeId)
        if (query.symbol != "" && (from.label == query.symbol || to.label == query.symbol)) {
            return true
        }
        if (query.repo != "" && (from.label == query.repo || to.label == query.repo || from.nodeId.contains(safeGraphId(query.repo)) || to.nodeId.contains(safeGraphId(query.repo)))) {
            return true
        }
        false
    }

    private func addGraphNodeById(context: GraphContext, nodeId: String, budget: Int64): Unit {
        if (context.nodes.size >= budget) {
            context.truncated = true
            return
        }
        for (existing in context.nodes) {
            if (existing.nodeId == nodeId) {
                return
            }
        }
        let node = this.findNode(nodeId)
        if (node.nodeId != "") {
            context.nodes.add(node)
        }
    }

    private func findNode(nodeId: String): GraphNode {
        for (node in this.nodes) {
            if (node.nodeId == nodeId) {
                return node
            }
        }
        GraphNode()
    }
}

public class SourceEvidence {
    public var citation: String = ""
    public var repo: String = ""
    public var path: String = ""
    public var symbol: String = ""
    public var score: Float64 = 0.0
    public var knowledgeVersion: String = ""
    public var trustLevel: String = ""
    public var reviewState: String = ""

    public init() {}
}

public class DocEvidence {
    public var citation: String = ""
    public var title: String = ""
    public var docVersion: String = ""
    public var score: Float64 = 0.0
    public var knowledgeVersion: String = ""
    public var trustLevel: String = ""
    public var reviewState: String = ""

    public init() {}
}

public class WebsiteEvidence {
    public var citation: String = ""
    public var url: String = ""
    public var title: String = ""
    public var score: Float64 = 0.0
    public var knowledgeVersion: String = ""
    public var trustLevel: String = ""
    public var reviewState: String = ""

    public init() {}
}

public class CommunityEvidence {
    public var citation: String = ""
    public var repo: String = ""
    public var issueOrPr: String = ""
    public var score: Float64 = 0.0
    public var knowledgeVersion: String = ""
    public var trustLevel: String = ""
    public var reviewState: String = ""

    public init() {}
}

public class WebCandidateEvidence {
    public var citation: String = ""
    public var url: String = ""
    public var score: Float64 = 0.0
    public var knowledgeVersion: String = ""
    public var trustLevel: String = TrustLevels.WEB_CANDIDATE
    public var reviewState: String = ReviewStates.CANDIDATE
    public var requiresReview: Bool = true

    public init() {}
}

public class EvidencePack {
    public var queryId: String = ""
    public var knowledgeVersion: String = ""
    public var truncated: Bool = false
    public var degraded: Bool = false
    public var citations: ArrayList<SourceReference> = ArrayList<SourceReference>()
    public var sourceEvidence: ArrayList<SourceEvidence> = ArrayList<SourceEvidence>()
    public var docEvidence: ArrayList<DocEvidence> = ArrayList<DocEvidence>()
    public var websiteEvidence: ArrayList<WebsiteEvidence> = ArrayList<WebsiteEvidence>()
    public var communityEvidence: ArrayList<CommunityEvidence> = ArrayList<CommunityEvidence>()
    public var webCandidateEvidence: ArrayList<WebCandidateEvidence> = ArrayList<WebCandidateEvidence>()
    public var graphContext: GraphContext = GraphContext()
    public var hasGraphContext: Bool = false

    public init() {}
}

public class StorageStatus {
    public var rawPath: String = "data/raw"
    public var normalizedPath: String = "data/normalized"
    public var metadataPath: String = "data/metadata"
    public var indexesPath: String = "data/indexes"
    public var derivedPath: String = "data/derived"
    public var cachePath: String = "data/cache"
    public var rawCount: Int64 = 0
    public var normalizedCount: Int64 = 0
    public var indexCount: Int64 = 0
    public var derivedCount: Int64 = 0
    public var textIndexCount: Int64 = 0
    public var vectorIndexCount: Int64 = 0
    public var symbolIndexCount: Int64 = 0
    public var graphIndexCount: Int64 = 0
    public var vectorBackend: String = "local-file"
    public var vectorState: String = EmbeddingProviderState.DEGRADED
    public var vectorDimension: Int64 = 0
    public var vectorCollection: String = "active"
    public var vectorActiveCollection: String = "active"
    public var vectorCandidateCollection: String = "candidate"
    public var vectorDegradedReason: String = ""
    public var graphBackend: String = "local-graph"
    public var graphState: String = EmbeddingProviderState.DEGRADED
    public var graphNodeCount: Int64 = 0
    public var graphEdgeCount: Int64 = 0
    public var targetVersion: String = "1.0.0"
    public var versionManifestCount: Int64 = 0
    public var servingIndexCount: Int64 = 0
    public var servingIndexVersion: String = ""
    public var servingIndexDiagnostic: String = ""
    public var queryCacheSize: Int64 = 0
    public var queryCacheDiagnostic: String = ""

    public init() {}
}

public class IndexMetadata {
    public var kind: String = ""
    public var version: String = ""
    public var itemCount: Int64 = 0
    public var deterministic: Bool = true
    public var candidateIsolated: Bool = true
    public var notes: String = ""

    public init() {}
}

public class IndexManifest {
    public var activeVersion: String = ""
    public var candidateVersion: String = ""
    public var targetVersion: String = "1.0.0"
    public var versionResolutionId: String = ""
    public var entries: ArrayList<IndexMetadata> = ArrayList<IndexMetadata>()

    public init() {}
}

public class SourceScope {
    public var organizations: Array<String> = ["cangjie", "cangjie-sig", "cangjie-tpc"]
    public var repoScope: String = "all-public-repos"
    public var websiteUrls: Array<String> = ["https://cangjie-lang.cn/", "https://cangjie-lang.cn/docs", "https://cangjie-lang.cn/en/docs"]
    public var docsUrls: Array<String> = ["https://docs.cangjie-lang.cn/docs/1.0.0/"]
    public var stdSources: Array<String> = ["std", "stdx"]
    public var includesIssuePrHistory: Bool = true
    public var includesGovernedWebCandidates: Bool = true
    public var excludesPrivateRepos: Bool = true

    public init() {}
}

public class ScheduleEntry {
    public var name: String = ""
    public var intervalMinutes: Int64 = 0
    public var nextRunAt: Int64 = 0
    public var lastStartedAt: Int64 = -1
    public var lastSuccessAt: Int64 = -1
    public var lastFailureAt: Int64 = -1
    public var stale: Bool = false
    public var degraded: Bool = false
    public var failureCount: Int64 = 0
    public var lastCursor: String = ""
    public var lastSince: String = ""
    public var activeVersion: String = ""
    public var candidateVersion: String = ""
    public var lastStatus: String = "pending"
    public var lastDurationMillis: Int64 = 0
    public var lastRequestCount: Int64 = 0
    public var lastUpdatedDataKinds: ArrayList<String> = ArrayList<String>()
    public var lastTruncated: Bool = false
    public var timeBudgetMillis: Int64 = 0
    public var lastRunId: String = ""
    public var lastRunStartedAtMillis: Int64 = 0
    public var lastRunFinishedAtMillis: Int64 = 0
    public var lastBinaryEvidenceHash: String = ""
    public var lastTerminalState: String = ""

    public init() {}

    public init(name: String, intervalMinutes: Int64, nextRunAt: Int64) {
        this.name = name
        this.intervalMinutes = intervalMinutes
        this.nextRunAt = nextRunAt
    }
}

public class KnowledgeStatus {
    public var activeKnowledgeVersion: String = ""
    public var candidateKnowledgeVersion: String = ""
    public var failedCandidateVersion: String = ""
    public var activeStateSource: String = "offline_baseline"
    public var restoreDiagnostic: String = ""
    public var storage: StorageStatus = StorageStatus()
    public var sourceScope: SourceScope = SourceScope()
    public var schedules: ArrayList<ScheduleEntry> = ArrayList<ScheduleEntry>()
    public var schedulerLoop: CkbSchedulerLoopStatus = CkbSchedulerLoopStatus()
    public var indexManifest: IndexManifest = IndexManifest()
    public var localPathRedacted: Bool = true

    public init() {}
}

public class CkbSchedulerLoopStatus {
    public var loopStatus: String = "unknown"
    public var schedulerEnabled: Bool = false
    public var intervalMillis: Int64 = 0
    public var readinessGate: String = ""
    public var firstTickDeferred: Bool = false
    public var tickKind: String = ""
    public var limit: Int64 = 0
    public var ran: Int64 = 0
    public var taskNames: ArrayList<String> = ArrayList<String>()
    public var diagnostic: String = ""
    public var heartbeatFresh: Bool = false
    public var loopFailureCount: Int64 = 0

    public init() {}
}

public class FakeClock {
    public var nowMinutes: Int64 = 0

    public init() {}

    public init(nowMinutes: Int64) {
        this.nowMinutes = nowMinutes
    }

    public func advance(minutes: Int64): Unit {
        this.nowMinutes += minutes
    }
}

public class Scheduler {
    public var clock: FakeClock
    public var entries: ArrayList<ScheduleEntry> = ArrayList<ScheduleEntry>()

    public init(clock: FakeClock) {
        this.clock = clock
        this.entries.add(ScheduleEntry("community_repo_discovery_30d", 43200, 0))
        this.entries.add(ScheduleEntry("docs_probe_30d", 43200, 40))
        this.entries.add(ScheduleEntry("website_probe_weekly", 10080, 0))
        this.entries.add(ScheduleEntry("website_full_weekly", 10080, 200))
        this.entries.add(ScheduleEntry("web_candidate_weekly", 10080, 240))
        this.entries.add(ScheduleEntry("web_candidate_recrawl_30d", 43200, 240))
        this.entries.add(ScheduleEntry("weekly_full_rebuild", 10080, 150))
        this.entries.add(ScheduleEntry("cangjie_freshness_daily", 1440, 300))
        this.entries.add(ScheduleEntry("cangjie_docs_full_weekly", 10080, 360))
        this.entries.add(ScheduleEntry("cangjie_release_full_sync", 10080, 420))
        this.entries.add(ScheduleEntry("cangjie_source_event_sync", 1440, 480))
        this.entries.add(ScheduleEntry("cangjie_version_branch_refresh", 1440, 540))
        this.entries.add(ScheduleEntry("cangjie_benchmark_gap_curation", 1440, 600))
    }

    public func dueTaskNames(): ArrayList<String> {
        let out = ArrayList<String>()
        for (entry in this.entries) {
            if (this.clock.nowMinutes >= entry.nextRunAt) {
                out.add(entry.name)
            }
        }
        out
    }

    public func markSuccess(name: String): Unit {
        for (entry in this.entries) {
            if (entry.name == name) {
                entry.lastStartedAt = this.clock.nowMinutes
                entry.lastSuccessAt = this.clock.nowMinutes
                entry.failureCount = 0
                entry.degraded = false
                entry.lastStatus = "succeeded"
                entry.nextRunAt = this.clock.nowMinutes + entry.intervalMinutes
            }
        }
    }

    public func markFailure(name: String): Unit {
        for (entry in this.entries) {
            if (entry.name == name) {
                entry.lastStartedAt = this.clock.nowMinutes
                entry.lastFailureAt = this.clock.nowMinutes
                entry.failureCount += 1
                entry.lastStatus = "failed"
                if (entry.failureCount >= 3) {
                    entry.degraded = true
                }
                var backoff: Int64 = 5
                if (entry.failureCount == 2) {
                    backoff = 15
                }
                if (entry.failureCount >= 3) {
                    backoff = 60
                }
                entry.nextRunAt = this.clock.nowMinutes + backoff
            }
        }
    }
}

public class SchedulerTaskResult {
    public var ok: Bool = false
    public var status: String = "not_started"
    public var terminality: String = ""
    public var cursor: String = ""
    public var since: String = ""
    public var activeVersion: String = ""
    public var candidateVersion: String = ""
    public var startedAtMillis: Int64 = 0
    public var endedAtMillis: Int64 = 0
    public var deadlineAtMillis: Int64 = 0
    public var durationMillis: Int64 = 0
    public var schedulerRunId: String = ""
    public var schedulerTaskName: String = ""
    public var bootstrapStartedAtMillis: Int64 = 0
    public var taskBodyStartedAtMillis: Int64 = 0
    public var taskBodyEndedAtMillis: Int64 = 0
    public var bootstrapDurationMillis: Int64 = 0
    public var resultWrittenAtMillis: Int64 = 0
    public var resultFlushDurationMillis: Int64 = 0
    // Business and terminal-artifact outcomes are deliberately independent:
    // a flush degradation must not erase the primary business failure.
    public var businessStatus: String = ""
    public var primaryFailure: String = ""
    public var finalizationStatus: String = "not_started"
    public var finalizationFailure: String = ""
    public var stageDurations: ArrayList<String> = ArrayList<String>()
    public var requestCount: Int64 = 0
    public var actualAttempts: Int64 = 0
    public var successfulAttempts: Int64 = 0
    public var retryAttempts: Int64 = 0
    public var plannedRequests: Int64 = 0
    public var completedRequests: Int64 = 0
    public var failedRequests: Int64 = 0
    public var updatedDataKinds: ArrayList<String> = ArrayList<String>()
    public var truncated: Bool = false
    public var timeBudgetMillis: Int64 = 0
    public var validationStatus: String = ""
    public var validationGates: ArrayList<String> = ArrayList<String>()
    public var transactionId: String = ""
    public var manifestEvidenceHash: String = ""
    public var freshnessEvidenceHash: String = ""
    public var sourceCoverageEvidenceHash: String = ""
    public var inventoryEvidenceHash: String = ""
    public var validationSummary: String = ""
    public var validationEvidenceHash: String = ""
    public var validationDiagnostics: ArrayList<String> = ArrayList<String>()
    public var lastStage: String = ""
    public var lastProgress: String = ""
    public var workerPid: Int64 = 0
    public var workerOutSnippet: String = ""
    public var workerErrSnippet: String = ""

    public init() {}
}

public class SchedulerExecutorResult {
    public var runId: String = ""
    public var startedAtMillis: Int64 = 0
    public var endedAtMillis: Int64 = 0
    public var timedOut: Bool = false
    public var partial: Bool = false
    public var progressPath: String = ""
    public var ran: Int64 = 0
    public var succeeded: Int64 = 0
    public var failed: Int64 = 0
    public var degraded: Int64 = 0
    public var details: String = ""
    public var forced: Bool = false
    public var taskNames: ArrayList<String> = ArrayList<String>()
    public var validationSummaries: ArrayList<String> = ArrayList<String>()
    public var validationDiagnostics: ArrayList<String> = ArrayList<String>()
    public var validationEvidenceHashes: ArrayList<String> = ArrayList<String>()
    public var businessOk: Bool = false
    public var finalizationOk: Bool = true
    public var schedulerSaved: Bool = false
    public var loopMetadataSaved: Bool = false
    public var lockReleased: Bool = false
    public var jsonPrinted: Bool = false
    public var schedulerSaveStatus: String = "not_run"
    public var loopMetadataStatus: String = "not_run"
    public var lockReleaseStatus: String = "not_run"
    public var jsonReadyAtMillis: Int64 = 0
    public var finalizationDiagnostics: ArrayList<String> = ArrayList<String>()
    public var finalPreflightOk: Bool = true
    public var finalPreflightDiagnostics: ArrayList<String> = ArrayList<String>()
    public var postRepairAttempted: Bool = false
    public var postRepairOk: Bool = false
    public var buildCommit: String = ""
    public var configHash: String = ""
    public var storeHash: String = ""
    public var taskRecords: ArrayList<SchedulerTaskRunRecord> = ArrayList<SchedulerTaskRunRecord>()

    public init() {}
}

public class SchedulerTaskRunRecord {
    public var taskName: String = ""
    public var ok: Bool = false
    public var status: String = ""
    public var startedAtMillis: Int64 = 0
    public var endedAtMillis: Int64 = 0
    public var deadlineAtMillis: Int64 = 0
    public var durationMillis: Int64 = 0
    public var schedulerRunId: String = ""
    public var schedulerTaskName: String = ""
    public var bootstrapStartedAtMillis: Int64 = 0
    public var taskBodyStartedAtMillis: Int64 = 0
    public var taskBodyEndedAtMillis: Int64 = 0
    public var bootstrapDurationMillis: Int64 = 0
    public var resultWrittenAtMillis: Int64 = 0
    public var resultFlushDurationMillis: Int64 = 0
    public var businessStatus: String = ""
    public var finalizationStatus: String = ""
    public var finalizationFailure: String = ""
    public var stageDurations: ArrayList<String> = ArrayList<String>()
    public var timeBudgetMillis: Int64 = 0
    public var requestCount: Int64 = 0
    public var actualAttempts: Int64 = 0
    public var successfulAttempts: Int64 = 0
    public var retryAttempts: Int64 = 0
    public var plannedRequests: Int64 = 0
    public var completedRequests: Int64 = 0
    public var failedRequests: Int64 = 0
    public var validationGates: ArrayList<String> = ArrayList<String>()
    public var transactionId: String = ""
    public var manifestEvidenceHash: String = ""
    public var freshnessEvidenceHash: String = ""
    public var sourceCoverageEvidenceHash: String = ""
    public var inventoryEvidenceHash: String = ""
    public var lastStage: String = ""
    public var lastProgress: String = ""
    public var workerPid: Int64 = 0
    public var workerOutSnippet: String = ""
    public var workerErrSnippet: String = ""
    public var primaryFailure: String = ""

    public init() {}
}

public interface SchedulerTaskRunner {
    func runTask(name: String, since: String, deadlineAtMillis: Int64): SchedulerTaskResult
}

public interface SchedulerProgressSink {
    func onRunStarted(result: SchedulerExecutorResult): Unit
    func onTaskStarted(runId: String, taskName: String,
        timeBudgetMillis: Int64, deadlineAtMillis: Int64): Unit
    func onTaskFinished(runId: String, taskName: String, task: SchedulerTaskResult): Unit
    func onRunFinished(result: SchedulerExecutorResult): Unit
}

public class NoopSchedulerProgressSink <: SchedulerProgressSink {
    public init() {}

    public func onRunStarted(result: SchedulerExecutorResult): Unit {}

    public func onTaskStarted(runId: String, taskName: String,
        timeBudgetMillis: Int64, deadlineAtMillis: Int64): Unit {}

    public func onTaskFinished(runId: String, taskName: String, task: SchedulerTaskResult): Unit {}

    public func onRunFinished(result: SchedulerExecutorResult): Unit {}
}

public class SchedulerExecutor {
    private let scheduler: Scheduler
    private let runner: SchedulerTaskRunner
    private let progressSink: SchedulerProgressSink
    private let taskTimeoutMillis: Int64

    public init(scheduler: Scheduler, runner: SchedulerTaskRunner) {
        this.scheduler = scheduler
        this.runner = runner
        this.progressSink = NoopSchedulerProgressSink()
        this.taskTimeoutMillis = 0
    }

    public init(scheduler: Scheduler, runner: SchedulerTaskRunner, progressSink: SchedulerProgressSink, taskTimeoutMillis: Int64) {
        this.scheduler = scheduler
        this.runner = runner
        this.progressSink = progressSink
        this.taskTimeoutMillis = taskTimeoutMillis
    }

    public func runDue(limit!: Int64 = 1): SchedulerExecutorResult {
        let result = SchedulerExecutorResult()
        this.startRun(result, false)
        let due = this.scheduler.dueTaskNames()
        for (name in due) {
            if (limit > 0 && result.ran >= limit) {
                break
            }
            this.runOneTask(result, name, true)
        }
        this.finishRun(result)
        result
    }

    public func runTaskNames(taskNames: ArrayList<String>, force!: Bool = false): SchedulerExecutorResult {
        let result = SchedulerExecutorResult()
        this.startRun(result, force)
        for (name in taskNames) {
            let entry = this.findEntry(name)
            if (entry.name == "" || entry.intervalMinutes == 0) {
                result.failed += 1
                result.details += "task ${name} ok=false status=unknown_task\n"
                continue
            }
            if (!force && this.scheduler.clock.nowMinutes < entry.nextRunAt) {
                result.details += "task ${name} ok=false status=not_due nextRunAt=${entry.nextRunAt}\n"
                continue
            }
            this.runOneTask(result, name, force)
        }
        this.finishRun(result)
        result
    }

    private func startRun(result: SchedulerExecutorResult, forced: Bool): Unit {
        result.runId = "scheduler-${ckbCoreNowMillis()}"
        result.startedAtMillis = ckbCoreNowMillis()
        result.forced = forced
        this.safeNotifyRunStarted(result)
    }

    private func finishRun(result: SchedulerExecutorResult): Unit {
        result.endedAtMillis = ckbCoreNowMillis()
        result.businessOk = result.failed == 0 && result.degraded == 0 && !result.partial
        this.safeNotifyRunFinished(result)
    }

    private func runOneTask(result: SchedulerExecutorResult, name: String, force: Bool): Unit {
        let entry = this.findEntry(name)
        let timeBudgetMillis = this.effectiveTaskTimeoutMillis(entry)
        let taskStartedAtMillis = ckbCoreNowMillis()
        let deadlineAtMillis = if (timeBudgetMillis > 0) {
            taskStartedAtMillis + timeBudgetMillis
        } else { 0 }
        this.safeNotifyTaskStarted(result, name, timeBudgetMillis,
            deadlineAtMillis)
        let task = this.runTaskWithTimeout(name, entry.lastSince,
            timeBudgetMillis, taskStartedAtMillis, deadlineAtMillis)
        result.ran += 1
        result.taskNames.add(name)
        if (schedulerTaskStatusIsTimeout(task.status)) {
            result.timedOut = true
            result.partial = true
        }
        if (task.terminality == "nonterminal_checkpointed" ||
            task.terminality == "nonterminal_retryable") {
            result.partial = true
            this.applyCheckpoint(name, task, result.runId)
        } else if (task.ok && (task.terminality == "" || task.terminality == "terminal_success")) {
            this.scheduler.markSuccess(name)
            this.applyCheckpoint(name, task, result.runId)
            result.succeeded += 1
        } else {
            this.scheduler.markFailure(name)
            this.applyCheckpoint(name, task, result.runId)
            result.failed += 1
        }
        let after = this.findEntry(name)
        if (after.degraded) {
            result.degraded += 1
        }
        result.details += "task ${name} ok=${task.ok} status=${task.status} nextRunAt=${after.nextRunAt} failureCount=${after.failureCount} degraded=${after.degraded}\n"
        this.appendTaskValidation(result, name, task)
        result.taskRecords.add(schedulerTaskRunRecord(name, task, result.runId))
        this.safeNotifyTaskFinished(result, name, task)
    }

    private func safeNotifyRunStarted(result: SchedulerExecutorResult): Unit {
        try {
            this.progressSink.onRunStarted(result)
        } catch (_: Exception) {
            this.recordProgressObserverFailure(result, "run_started")
        }
    }

    private func safeNotifyTaskStarted(result: SchedulerExecutorResult,
        taskName: String, timeBudgetMillis: Int64,
        deadlineAtMillis: Int64): Unit {
        try {
            this.progressSink.onTaskStarted(result.runId, taskName,
                timeBudgetMillis, deadlineAtMillis)
        } catch (_: Exception) {
            this.recordProgressObserverFailure(result, "task_started:${taskName}")
        }
    }

    private func safeNotifyTaskFinished(result: SchedulerExecutorResult, taskName: String, task: SchedulerTaskResult): Unit {
        try {
            this.progressSink.onTaskFinished(result.runId, taskName, task)
        } catch (_: Exception) {
            this.recordProgressObserverFailure(result, "task_finished:${taskName}")
        }
    }

    private func safeNotifyRunFinished(result: SchedulerExecutorResult): Unit {
        try {
            this.progressSink.onRunFinished(result)
        } catch (_: Exception) {
            this.recordProgressObserverFailure(result, "run_finished")
        }
    }

    private func recordProgressObserverFailure(result: SchedulerExecutorResult, event: String): Unit {
        result.finalizationOk = false
        result.finalizationDiagnostics.add("scheduler_progress_observer_degraded:event=${event}")
    }

    private func runTaskWithTimeout(name: String, since: String,
        timeoutMillis: Int64, started: Int64,
        deadlineAtMillis: Int64): SchedulerTaskResult {
        if (timeoutMillis <= 0) {
            try {
                let task = this.runner.runTask(name, since, deadlineAtMillis)
                return this.finalizeTaskTiming(task, started, deadlineAtMillis, timeoutMillis)
            } catch (e: Exception) {
                let task = schedulerExceptionTaskResult(name, "task_exception", ckbCoreNowMillis() - started, message: schedulerExceptionMessage(e))
                return this.finalizeTaskTiming(task, started, deadlineAtMillis, timeoutMillis)
            }
        }
        try {
            let task = this.runner.runTask(name, since, deadlineAtMillis)
            if (schedulerTaskStatusIsTimeout(task.status)) {
                return this.finalizeTaskTiming(task, started, deadlineAtMillis, timeoutMillis)
            }
            if (ckbDeadlineExceeded(deadlineAtMillis)) {
                task.ok = false
                task.status = "task_timeout:${name}"
                task.durationMillis = ckbCoreNowMillis() - started
                return this.finalizeTaskTiming(task, started, deadlineAtMillis, timeoutMillis)
            }
            return this.finalizeTaskTiming(task, started, deadlineAtMillis, timeoutMillis)
        } catch (e: Exception) {
            let status = if (ckbDeadlineExceeded(deadlineAtMillis)) { "task_timeout:${name}" } else { "task_exception" }
            let task = schedulerExceptionTaskResult(name, status, ckbCoreNowMillis() - started, message: schedulerExceptionMessage(e))
            return this.finalizeTaskTiming(task, started, deadlineAtMillis, timeoutMillis)
        }
    }

    private func finalizeTaskTiming(task: SchedulerTaskResult, startedAtMillis: Int64, deadlineAtMillis: Int64, timeoutMillis: Int64): SchedulerTaskResult {
        let ended = ckbCoreNowMillis()
        if (task.startedAtMillis <= 0) {
            task.startedAtMillis = startedAtMillis
        }
        if (task.endedAtMillis <= 0) {
            task.endedAtMillis = ended
        }
        task.deadlineAtMillis = deadlineAtMillis
        task.durationMillis = if (task.endedAtMillis >= task.startedAtMillis) { task.endedAtMillis - task.startedAtMillis } else { 0 }
        if (task.timeBudgetMillis <= 0) {
            task.timeBudgetMillis = timeoutMillis
        }
        task
    }

    private func effectiveTaskTimeoutMillis(entry: ScheduleEntry): Int64 {
        if (entry.timeBudgetMillis > 0) {
            return entry.timeBudgetMillis
        }
        if (this.taskTimeoutMillis > 0) {
            return this.taskTimeoutMillis
        }
        0
    }

    private func appendTaskValidation(result: SchedulerExecutorResult, name: String, task: SchedulerTaskResult): Unit {
        if (task.validationSummary != "") {
            result.details += "${task.validationSummary}\n"
            result.validationSummaries.add(task.validationSummary)
        }
        if (task.validationEvidenceHash != "") {
            result.validationEvidenceHashes.add("${name}:${task.validationEvidenceHash}")
        }
        for (diagnostic in task.validationDiagnostics) {
            result.validationDiagnostics.add("${name}:${diagnostic}")
        }
    }

    private func findEntry(name: String): ScheduleEntry {
        for (entry in this.scheduler.entries) {
            if (entry.name == name) {
                return entry
            }
        }
        ScheduleEntry(name, 0, 0)
    }

    private func applyCheckpoint(name: String, task: SchedulerTaskResult, runId: String): Unit {
        for (entry in this.scheduler.entries) {
            if (entry.name == name) {
                entry.lastCursor = task.cursor
                entry.lastSince = task.since
                entry.activeVersion = task.activeVersion
                entry.candidateVersion = task.candidateVersion
                entry.lastStatus = task.status
                entry.lastDurationMillis = task.durationMillis
                entry.lastRequestCount = task.requestCount
                entry.lastUpdatedDataKinds.clear()
                for (kind in task.updatedDataKinds) {
                    entry.lastUpdatedDataKinds.add(kind)
                }
                entry.lastTruncated = task.truncated
                entry.timeBudgetMillis = task.timeBudgetMillis
                entry.lastRunId = runId
                entry.lastRunStartedAtMillis = task.startedAtMillis
                entry.lastRunFinishedAtMillis = task.endedAtMillis
                entry.lastTerminalState = if (task.ok) { "succeeded" } else { task.status }
            }
        }
    }
}

private func schedulerTaskRunRecord(name: String, task: SchedulerTaskResult, runId: String): SchedulerTaskRunRecord {
    let record = SchedulerTaskRunRecord()
    record.taskName = name
    record.ok = task.ok
    record.status = task.status
    record.startedAtMillis = task.startedAtMillis
    record.endedAtMillis = task.endedAtMillis
    record.deadlineAtMillis = task.deadlineAtMillis
    record.durationMillis = task.durationMillis
    record.schedulerRunId = if (task.schedulerRunId != "") { task.schedulerRunId } else { runId }
    record.schedulerTaskName = if (task.schedulerTaskName != "") { task.schedulerTaskName } else { name }
    record.bootstrapStartedAtMillis = task.bootstrapStartedAtMillis
    record.taskBodyStartedAtMillis = task.taskBodyStartedAtMillis
    record.taskBodyEndedAtMillis = task.taskBodyEndedAtMillis
    record.bootstrapDurationMillis = task.bootstrapDurationMillis
    record.resultWrittenAtMillis = task.resultWrittenAtMillis
    record.resultFlushDurationMillis = task.resultFlushDurationMillis
    record.businessStatus = task.businessStatus
    record.finalizationStatus = task.finalizationStatus
    record.finalizationFailure = task.finalizationFailure
    for (duration in task.stageDurations) {
        record.stageDurations.add(duration)
    }
    record.timeBudgetMillis = task.timeBudgetMillis
    record.requestCount = task.requestCount
    record.actualAttempts = task.actualAttempts
    record.successfulAttempts = task.successfulAttempts
    record.retryAttempts = task.retryAttempts
    record.plannedRequests = task.plannedRequests
    record.completedRequests = task.completedRequests
    record.failedRequests = task.failedRequests
    for (gate in task.validationGates) {
        record.validationGates.add(gate)
    }
    record.transactionId = task.transactionId
    record.manifestEvidenceHash = task.manifestEvidenceHash
    record.freshnessEvidenceHash = task.freshnessEvidenceHash
    record.sourceCoverageEvidenceHash = task.sourceCoverageEvidenceHash
    record.inventoryEvidenceHash = task.inventoryEvidenceHash
    record.lastStage = task.lastStage
    record.lastProgress = task.lastProgress
    record.workerPid = task.workerPid
    record.workerOutSnippet = task.workerOutSnippet
    record.workerErrSnippet = task.workerErrSnippet
    record.primaryFailure = if (task.primaryFailure != "") {
        task.primaryFailure
    } else { schedulerPrimaryFailureFromTask(task) }
    record
}

public func schedulerTaskStatusIsTimeout(status: String): Bool {
    status.startsWith("task_timeout:") ||
        status == "bootstrap_deadline_exceeded" ||
        status == "fetch_deadline_exceeded" ||
        status == "ingest_deadline_exceeded" ||
        status == "candidate_vector_deadline_exceeded" ||
        status == "candidate_validation_deadline_exceeded" ||
        status == "candidate_active_commit_deadline_exceeded" ||
        status == "candidate_active_snapshot_deadline_exceeded" ||
        status.startsWith("deadline_exceeded:")
}

private func schedulerPrimaryFailureFromTask(task: SchedulerTaskResult): String {
    if (task.ok) {
        return ""
    }
    for (diagnostic in task.validationDiagnostics) {
        if (schedulerDiagnosticIsPrimaryFailure(diagnostic)) {
            return schedulerDiagnosticSafePrefix(diagnostic, 240)
        }
    }
    for (diagnostic in task.validationDiagnostics) {
        if (diagnostic.startsWith("fetch:") && diagnostic.contains("ok=false")) {
            return schedulerDiagnosticSafePrefix(diagnostic, 240)
        }
    }
    for (diagnostic in task.validationDiagnostics) {
        if (!schedulerDiagnosticIsContextOnly(diagnostic)) {
            return schedulerDiagnosticSafePrefix(diagnostic, 240)
        }
    }
    task.status
}

private func schedulerDiagnosticIsPrimaryFailure(diagnostic: String): Bool {
    if (schedulerDiagnosticIsContextOnly(diagnostic)) {
        return false
    }
    if (schedulerFreshnessDiagnosticIsBlocking(diagnostic)) {
        return true
    }
    diagnostic.startsWith("readiness:") ||
        diagnostic.contains("version_manifest_write_verify_failed") ||
        diagnostic.contains("version_manifest_empty_after_refresh") ||
        diagnostic.startsWith("internal_timeout:") ||
        diagnostic.contains("worker_artifact:")
}

private func schedulerDiagnosticIsContextOnly(diagnostic: String): Bool {
    diagnostic.contains("routine_contract_passed") ||
        diagnostic.contains("profile_stage_budget") ||
        diagnostic.contains("profile_stage_checkpoint") ||
        schedulerFreshnessDiagnosticIsSignal(diagnostic)
}

private func schedulerFreshnessDiagnosticIsBlocking(diagnostic: String): Bool {
    diagnostic.contains("probe_failed") ||
        diagnostic.contains("manifest_not_ready_for_freshness") ||
        diagnostic.contains("manifest_blocking_for_freshness") ||
        diagnostic.contains("manifest_missing_for_freshness") ||
        diagnostic.contains("manifest_offline_baseline_for_freshness") ||
        diagnostic.contains("version_manifest_contains_offline_baseline") ||
        diagnostic.contains("version_manifest_invalid_encoding") ||
        diagnostic.contains("version_manifest_malformed")
}

private func schedulerFreshnessDiagnosticIsSignal(diagnostic: String): Bool {
    diagnostic.contains("freshness_source_hash_changed") ||
        diagnostic.contains("staleness_stale") ||
        diagnostic.contains("freshness_stale_signal") ||
        diagnostic.contains("freshness_source:") ||
        diagnostic.contains("manifest_source_tree_resolved") ||
        diagnostic.contains("manifest_source_content_sample_ok") ||
        diagnostic.contains("manifest_ready_for_freshness")
}

private func schedulerExceptionTaskResult(name: String, status: String, durationMillis: Int64, message!: String = ""): SchedulerTaskResult {
    let task = SchedulerTaskResult()
    task.ok = false
    task.status = status
    task.durationMillis = durationMillis
    let detail = schedulerDiagnosticSafePrefix(message, 160)
    task.validationDiagnostics.add(if (detail == "") { "${name}:${status}" } else { "${name}:${status}:${detail}" })
    task
}

private func schedulerExceptionMessage(e: Exception): String {
    let message = e.message.replace("\n", " ").replace("\r", " ").trimAscii()
    if (message != "") {
        return message
    }
    e.toString().replace("\n", " ").replace("\r", " ").trimAscii()
}

private func schedulerDiagnosticSafePrefix(raw: String, limit: Int64): String {
    if (limit <= 0) {
        return ""
    }
    var out = ""
    var count: Int64 = 0
    for (r in raw.runes()) {
        if (count >= limit) {
            return out
        }
        out += r.toString()
        count += 1
    }
    out
}

public class FreshnessResult {
    public var policy: String = FreshnessPolicies.USE_ACTIVE
    public var status: String = "active"
    public var oldKnowledgeVersion: String = ""
    public var newKnowledgeVersion: String = ""
    public var requiresReview: Bool = false
    public var blocked: Bool = false

    public init() {}
}

public class ScopedRefreshService {
    private var lastRepoRefreshAt: Int64 = -100000
    private let cooldownMinutes: Int64 = 5

    public init() {}

    public func apply(policy: String, repo: String, ref: String, nowMinutes: Int64, activeVersion: String): FreshnessResult {
        let result = FreshnessResult()
        result.policy = policy
        result.oldKnowledgeVersion = activeVersion
        result.newKnowledgeVersion = activeVersion
        if (policy == FreshnessPolicies.USE_ACTIVE) {
            return result
        }
        if (nowMinutes - this.lastRepoRefreshAt < this.cooldownMinutes) {
            result.status = "refresh_limited"
            result.blocked = true
            return result
        }
        this.lastRepoRefreshAt = nowMinutes
        if (policy == FreshnessPolicies.FORCE_CANDIDATE || policy == FreshnessPolicies.ENSURE_REF) {
            result.status = "candidate"
            result.newKnowledgeVersion = "${activeVersion}-candidate"
            result.requiresReview = true
            return result
        }
        if (policy == FreshnessPolicies.ENSURE_RECENT) {
            result.status = "fresh"
            result.newKnowledgeVersion = "${activeVersion}-scoped"
            return result
        }
        result.status = "unknown_policy"
        result.blocked = true
        result
    }
}

public class CurationTask {
    public var taskId: String = ""
    public var kind: String = ""
    public var repo: String = ""
    public var status: String = "pending"
    public var sourceReferences: ArrayList<SourceReference> = ArrayList<SourceReference>()
    public var derivedKnowledge: String = ""

    public init() {}
}

public class CurationQueue {
    public var tasks: ArrayList<CurationTask> = ArrayList<CurationTask>()

    public init() {}

    public func enqueueRepoSummary(repo: String, references: ArrayList<SourceReference>): CurationTask {
        let task = CurationTask()
        task.taskId = "curation-${this.tasks.size + 1}"
        task.kind = "repo_summary"
        task.repo = repo
        for (reference in references) {
            task.sourceReferences.add(reference)
        }
        this.tasks.add(task)
        task
    }

    public func start(taskId: String): Bool {
        for (task in this.tasks) {
            if (task.taskId == taskId && task.status == "pending") {
                task.status = "running"
                return true
            }
        }
        false
    }

    public func cancel(taskId: String): Bool {
        for (task in this.tasks) {
            if (task.taskId == taskId && task.status != "succeeded") {
                task.status = "cancelled"
                return true
            }
        }
        false
    }

    public func complete(taskId: String, derivedKnowledge: String): Bool {
        for (task in this.tasks) {
            if (task.taskId == taskId && task.status == "running" && task.sourceReferences.size > 0) {
                task.status = "succeeded"
                task.derivedKnowledge = derivedKnowledge
                return true
            }
        }
        false
    }
}

public class KnowledgeBase {
    public let sourceScope: SourceScope = SourceScope()
    public let storage: StorageStatus = StorageStatus()
    public let scheduler: Scheduler
    public let curationQueue: CurationQueue = CurationQueue()
    public let refreshService: ScopedRefreshService = ScopedRefreshService()
    private var rawRecords: ArrayList<RawRecord> = ArrayList<RawRecord>()
    private var normalizedRecords: ArrayList<NormalizedRecord> = ArrayList<NormalizedRecord>()
    private var activeIndex: ArrayList<NormalizedRecord> = ArrayList<NormalizedRecord>()
    private var candidateIndex: ArrayList<NormalizedRecord> = ArrayList<NormalizedRecord>()
    private var activeKnowledgeVersion: String = "ckb-20260519-000000-baseline"
    private var candidateKnowledgeVersion: String = ""
    private var failedCandidateVersion: String = ""
    private var activeStateSource: String = "offline_baseline"
    private var restoreDiagnostic: String = ""
    private var indexManifest: IndexManifest = IndexManifest()
    private let embeddingProvider: EmbeddingProvider
    private let vectorStore: VectorStore
    private let graphStore: GraphStore
    private var vectorCollection: String = "active"
    private var candidateVectorCollection: String = "candidate"
    private let embeddingModel: String = "deterministic-token-v1"
    private let embeddingDimensions: Int64 = 16
    private var servingQueryCache: CangjieQueryCache = CangjieQueryCache(256)
    private var studentServingProjection: CangjieStudentServingProjection = CangjieStudentServingProjection()
    private var lastVectorBuildProgress: VectorBuildProgress = VectorBuildProgress()
    private var lastVectorIndexBuildResult: VectorIndexBuildResult = VectorIndexBuildResult()
    private var lastOverlayBuildStats: CkbOverlayBuildStats = CkbOverlayBuildStats()
    private var lastCandidateMaterialization: CkbCandidateMaterializationResult = CkbCandidateMaterializationResult()
    private var lastGraphBuildCache: CkbGraphBuildCache = CkbGraphBuildCache()
    private var activeSnapshotReadable: Bool = true

    public init(clock: FakeClock) {
        this.scheduler = Scheduler(clock)
        this.embeddingProvider = DeterministicEmbeddingProvider()
        this.vectorStore = LocalVectorStore()
        this.graphStore = LocalGraphStore()
    }

    public init(clock: FakeClock, embeddingProvider: EmbeddingProvider, vectorStore: VectorStore, graphStore: GraphStore) {
        this.scheduler = Scheduler(clock)
        this.embeddingProvider = embeddingProvider
        this.vectorStore = vectorStore
        this.graphStore = graphStore
    }

    public func configureVectorCollections(active: String, candidate: String): Unit {
        if (active != "") {
            this.vectorCollection = active
            this.storage.vectorCollection = active
            this.storage.vectorActiveCollection = active
        }
        if (candidate != "") {
            this.candidateVectorCollection = candidate
            this.storage.vectorCandidateCollection = candidate
        }
    }

    public func promoteVectorActiveCollection(collection: String): Unit {
        let trimmed = collection.trimAscii()
        if (trimmed == "") {
            return
        }
        this.vectorCollection = trimmed
        this.storage.vectorCollection = trimmed
        this.storage.vectorActiveCollection = trimmed
    }

    public func bootstrapOffline(restoreDiagnostic!: String = ""): Unit {
        this.activeSnapshotReadable = true
        this.rawRecords.clear()
        this.normalizedRecords.clear()
        this.activeStateSource = "offline_baseline"
        this.restoreDiagnostic = restoreDiagnostic
        this.addRecord("doc-syntax", SourceTypes.DOC, "Cangjie function syntax", "https://docs.cangjie-lang.cn/docs/1.0.0/language/functions", "", "", "", "1.0.0", TrustLevels.OFFICIAL, ReviewStates.TRUSTED, "Function definitions use func. Named parameters use an exclamation marker in the declaration and parameter names in calls. Cangjie syntax covers classes, arrays, options, and tests.")
        this.addRecord("doc-stdx-json", SourceTypes.DOC, "stdx JSON API", "https://docs.cangjie-lang.cn/docs/1.0.0/libs/stdx/json", "", "", "", "1.0.0", TrustLevels.OFFICIAL, ReviewStates.TRUSTED, "stdx contains JSON support for structured encoding and decoding.")
        this.addRecord("cangjie-syntax-option", SourceTypes.DOC, "Cangjie Option syntax", "https://docs.cangjie-lang.cn/docs/1.0.0/language/option", "", "", "Option", "1.0.0", TrustLevels.OFFICIAL, ReviewStates.TRUSTED, "Option<T> values are None<T> or Some<T>(value). Use Option when a value may be absent and avoid null-style checks.")
        this.addRecord("cangjie-syntax-main", SourceTypes.DOC, "Cangjie main entry point syntax", "https://docs.cangjie-lang.cn/docs/1.0.0/language/main", "", "", "main", "1.0.0", TrustLevels.OFFICIAL, ReviewStates.TRUSTED, "The program entry point is declared as main() without the func keyword. Example: main() { println(\"Hello\") }.")
        this.addRecord("cangjie-stdlib-arraylist", SourceTypes.DOC, "std.collection ArrayList", "https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection", "cangjie/std", "std/collection/arraylist.cj", "ArrayList", "1.0.0", TrustLevels.OFFICIAL, ReviewStates.TRUSTED, "ArrayList<T> is the dynamic array collection. Import std.collection.* before using ArrayList, HashMap, or HashSet.")
        this.addRecord("cangjie-stdlib-regex", SourceTypes.DOC, "std.regex usage", "https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/regex", "cangjie/std", "std/regex/regex.cj", "Regex", "1.0.0", TrustLevels.OFFICIAL, ReviewStates.TRUSTED, "Regular expression matching, splitting, replacement, and capture groups are available after import std.regex.*.")
        this.addRecord("cangjie-stdx-json", SourceTypes.DOC, "stdx JSON examples", "https://docs.cangjie-lang.cn/docs/1.0.0/libs/stdx/json", "cangjie/stdx", "stdx/json/json.cj", "Json", "1.0.0", TrustLevels.OFFICIAL, ReviewStates.TRUSTED, "stdx JSON APIs provide structured JSON parsing and encoding examples for Cangjie programs.")
        this.addRecord("cangjie-toolchain-cjpm-test", SourceTypes.DOC, "cjpm test workflow", "https://docs.cangjie-lang.cn/docs/1.0.0/tools/cjpm", "", "", "cjpm test", "1.0.0", TrustLevels.OFFICIAL, ReviewStates.TRUSTED, "Use cjpm build and cjpm test to compile and run Cangjie package tests. Test fixtures should stay under test directories.")
        this.addRecord("cangjie-antipattern-python-main", SourceTypes.DOC, "Cangjie anti-pattern: Python-style main", "https://docs.cangjie-lang.cn/docs/1.0.0/language/main", "", "", "main", "1.0.0", TrustLevels.OFFICIAL, ReviewStates.REVIEWED, "Do not write def main() or if __name__ == '__main__' in Cangjie. Cangjie uses main() { ... } without the func keyword.")
        this.addRecord("website-download", SourceTypes.WEBSITE, "Cangjie official download", "https://cangjie-lang.cn/download", "", "", "", "", TrustLevels.OFFICIAL, ReviewStates.TRUSTED, "The official website links Cangjie downloads, documentation, tools, and community entry points.")
        this.addRecord("source-http-client", SourceTypes.REPO, "HttpClient source", "https://gitcode.com/cangjie/stdx/blob/main/src/http/client.cj", "cangjie/stdx", "src/http/client.cj", "HttpClient", "", TrustLevels.OFFICIAL, ReviewStates.TRUSTED, "public class HttpClient provides HTTP request transport behavior for stdx examples.")
        this.addRecord("community-issue-1", SourceTypes.COMMUNITY, "Issue history for named parameter syntax", "https://gitcode.com/cangjie/cangjie/issues/1", "cangjie/cangjie", "", "", "", TrustLevels.COMMUNITY, ReviewStates.REVIEWED, "Maintainers clarified that named parameters are passed after positional parameters.")
        this.normalize()
        this.publishIndex(false)
    }

    public func markPersistedSnapshotInvalid(diagnostic: String): Unit {
        this.activeSnapshotReadable = false
        this.rawRecords.clear()
        this.normalizedRecords.clear()
        this.activeIndex.clear()
        this.candidateIndex.clear()
        this.activeKnowledgeVersion = ""
        this.candidateKnowledgeVersion = ""
        this.failedCandidateVersion = ""
        this.activeStateSource = "persisted_invalid"
        this.restoreDiagnostic = if (diagnostic == "") { "active_snapshot_invalid" } else { diagnostic }
        this.storage.rawCount = 0
        this.storage.normalizedCount = 0
        this.storage.indexCount = 0
        this.storage.textIndexCount = 0
        this.storage.vectorIndexCount = 0
        this.storage.symbolIndexCount = 0
        this.storage.graphIndexCount = 0
        this.storage.vectorState = EmbeddingProviderState.DEGRADED
        this.storage.vectorDegradedReason = this.restoreDiagnostic
        this.storage.graphState = EmbeddingProviderState.DEGRADED
        this.storage.graphNodeCount = 0
        this.storage.graphEdgeCount = 0
        this.indexManifest = IndexManifest()
        this.servingQueryCache = CangjieQueryCache(256)
        this.invalidateStudentServingProjection()
        this.graphStore.clear()
        this.lastGraphBuildCache = CkbGraphBuildCache()
    }

    public func restoreActiveSnapshot(snapshot: ActiveSnapshot): Bool {
        if (!snapshot.valid) {
            this.restoreDiagnostic = snapshot.diagnostic
            return false
        }
        this.activeSnapshotReadable = true
        this.rawRecords.clear()
        this.normalizedRecords.clear()
        this.activeIndex.clear()
        this.invalidateStudentServingProjection()
        this.candidateIndex.clear()
        for (record in snapshot.rawRecords) {
            this.rawRecords.add(this.copyRawRecord(record))
        }
        for (record in snapshot.normalizedRecords) {
            this.normalizedRecords.add(this.copyNormalizedRecord(record))
        }
        if (this.normalizedRecords.size == 0) {
            for (record in snapshot.activeIndex) {
                this.normalizedRecords.add(this.copyNormalizedRecord(record))
            }
        }
        for (record in snapshot.activeIndex) {
            let active = this.copyNormalizedRecord(record)
            active.metadata.knowledgeVersion = snapshot.activeVersion
            this.activeIndex.add(active)
        }
        this.activeKnowledgeVersion = snapshot.activeVersion
        this.candidateKnowledgeVersion = snapshot.candidateVersion
        this.failedCandidateVersion = snapshot.failedVersion
        this.configureVectorCollections(snapshot.vectorActiveCollection, snapshot.vectorCandidateCollection)
        this.activeStateSource = if (snapshot.activeStateSource == "first_initialization") {
            "first_initialization"
        } else if (snapshot.degraded || snapshot.activeStateSource == "persisted_degraded") {
            "persisted_degraded"
        } else {
            "persisted"
        }
        this.restoreDiagnostic = snapshot.diagnostic
        this.storage.rawCount = this.rawRecords.size
        this.storage.normalizedCount = this.normalizedRecords.size
        this.storage.indexCount = this.activeIndex.size
        let vectorResult = this.restoreOrRebuildActiveVectorIndex(snapshot)
        if (!vectorResult.ok && vectorResult.diagnostic != "") {
            this.restoreDiagnostic = "${this.restoreDiagnostic};${vectorResult.diagnostic}"
        }
        if (snapshot.degraded) {
            let vectorStatus = this.vectorStore.status(this.vectorCollection)
            vectorStatus.state = EmbeddingProviderState.DEGRADED
            vectorStatus.degradedReason = snapshot.diagnostic
            this.applyVectorStatus(vectorStatus)
        }
        this.rebuildIndexManifest()
        return true
    }

    private func restoreOrRebuildActiveVectorIndex(snapshot: ActiveSnapshot): VectorIndexBuildResult {
        if (snapshot.vectorRecords.size == 0) {
            let existing = this.vectorStore.status(this.vectorCollection)
            if (existing.state == EmbeddingProviderState.READY && existing.count == this.activeIndex.size) {
                this.applyVectorStatus(existing)
                this.rebuildGraphIndex()
                this.rebuildServingIndexStatus()
                let ready = VectorIndexBuildResult()
                ready.ok = true
                ready.status = existing.state
                ready.vectorCount = existing.count
                ready.graphNodes = this.storage.graphNodeCount
                ready.servingCount = this.storage.servingIndexCount
                ready.diagnostic = "vector_snapshot_missing_but_active_collection_consistent"
                return ready
            }
            return this.markVectorRebuildRequired("vector_snapshot_missing")
        }
        let backupDimension = vectorBackupDimension(snapshot.vectorRecords)
        let expectedDimension = this.activeEmbeddingDimensions()
        if (backupDimension <= 0 || (expectedDimension > 0 && backupDimension != expectedDimension)) {
            return this.markVectorRebuildRequired("vector_rebuild_required:dimension_mismatch:${backupDimension}:${expectedDimension}")
        }
        let result = VectorIndexBuildResult()
        let backup = VectorBackup()
        backup.collection = this.vectorCollection
        backup.valid = true
        backup.diagnostic = "ok"
        for (record in snapshot.vectorRecords) {
            backup.records.add(record)
        }
        let vectorStatus = this.vectorStore.restore(backup)
        this.applyVectorStatus(vectorStatus)
        this.rebuildGraphIndex()
        this.rebuildServingIndexStatus()
        result.ok = vectorStatus.state == EmbeddingProviderState.READY
        result.status = vectorStatus.state
        result.vectorCount = vectorStatus.count
        result.graphNodes = this.storage.graphNodeCount
        result.servingCount = this.storage.servingIndexCount
        result.diagnostic = vectorStatus.degradedReason
        result
    }

    private func markVectorRebuildRequired(reason: String): VectorIndexBuildResult {
        let result = VectorIndexBuildResult()
        result.ok = false
        result.status = EmbeddingProviderState.DEGRADED
        result.vectorCount = 0
        result.diagnostic = reason
        this.rebuildServingIndexStatus()
        this.rebuildGraphIndex()
        let status = this.vectorStore.status(this.vectorCollection)
        status.state = EmbeddingProviderState.DEGRADED
        status.count = 0
        status.dimension = this.activeEmbeddingDimensions()
        status.degradedReason = reason
        this.applyVectorStatus(status)
        result.graphNodes = this.storage.graphNodeCount
        result.servingCount = this.storage.servingIndexCount
        result
    }

    public func restoreScheduler(entries: ArrayList<ScheduleEntry>): Unit {
        for (checkpoint in entries) {
            for (entry in this.scheduler.entries) {
                if (entry.name == checkpoint.name) {
                    entry.nextRunAt = checkpoint.nextRunAt
                    entry.lastStartedAt = checkpoint.lastStartedAt
                    entry.lastSuccessAt = checkpoint.lastSuccessAt
                    entry.lastFailureAt = checkpoint.lastFailureAt
                    entry.failureCount = checkpoint.failureCount
                    entry.degraded = checkpoint.degraded
                    entry.lastCursor = checkpoint.lastCursor
                    entry.lastSince = checkpoint.lastSince
                    entry.activeVersion = checkpoint.activeVersion
                    entry.candidateVersion = checkpoint.candidateVersion
                    entry.lastStatus = checkpoint.lastStatus
                    entry.lastDurationMillis = checkpoint.lastDurationMillis
                    entry.lastRequestCount = checkpoint.lastRequestCount
                    entry.lastUpdatedDataKinds.clear()
                    for (kind in checkpoint.lastUpdatedDataKinds) {
                        entry.lastUpdatedDataKinds.add(kind)
                    }
                    entry.lastTruncated = checkpoint.lastTruncated
                    entry.timeBudgetMillis = checkpoint.timeBudgetMillis
                    entry.lastRunId = checkpoint.lastRunId
                    entry.lastRunStartedAtMillis = checkpoint.lastRunStartedAtMillis
                    entry.lastRunFinishedAtMillis = checkpoint.lastRunFinishedAtMillis
                    entry.lastBinaryEvidenceHash = checkpoint.lastBinaryEvidenceHash
                    entry.lastTerminalState = checkpoint.lastTerminalState
                }
            }
        }
    }

    private func addRecord(sourceId: String, sourceType: String, title: String, sourceUrl: String, repo: String, path: String, symbol: String, docVersion: String, trustLevel: String, reviewState: String, content: String): Int64 {
        let existing = this.rawRecordIndex(sourceId)
        if (existing >= 0) {
            return existing
        }
        let metadata = KnowledgeMetadata()
        metadata.sourceId = sourceId
        metadata.sourceType = sourceType
        metadata.sourceUrl = sourceUrl
        metadata.repo = repo
        metadata.path = path
        metadata.symbol = symbol
        metadata.commit = "offline-baseline"
        metadata.docVersion = docVersion
        metadata.crawlAt = "2026-05-19T00:00:00Z"
        metadata.indexedAt = "2026-05-19T00:00:00Z"
        metadata.knowledgeVersion = this.activeKnowledgeVersion
        metadata.candidateVersion = ""
        metadata.contentSize = content.size
        metadata.trustLevel = trustLevel
        metadata.reviewState = reviewState
        metadata.license = "declared-or-unknown"
        let record = RawRecord()
        record.sourceId = sourceId
        record.title = title
        record.content = content
        record.metadata = metadata
        record.contentHash = contentHash(sourceId, content)
        record.requiresReview = reviewState == ReviewStates.CANDIDATE
        this.rawRecords.add(record)
        this.rawRecords.size - 1
    }

    public func ingestFetchResult(sourceId: String, sourceType: String, fetch: SourceFetchResult, title: String, trustLevel: String, reviewState: String): Bool {
        if (!fetch.ok) {
            return false
        }
        var repo = fetch.repo
        var path = fetch.path
        var symbol = ""
        if (sourceType == SourceTypes.REPO) {
            symbol = if (path != "") { "HttpClient" } else { "" }
        }
        let index = this.addRecord(sourceId, sourceType, title, fetch.sourceUrl, repo, path, symbol, "1.0.0", trustLevel, reviewState, fetch.body)
        let inserted = this.rawRecords[index]
        inserted.sourceId = sourceId
        inserted.title = title
        inserted.content = fetch.body
        inserted.contentHash = contentHash(sourceId, fetch.body)
        inserted.requiresReview = reviewState == ReviewStates.CANDIDATE
        inserted.metadata.sourceId = sourceId
        inserted.metadata.sourceType = sourceType
        inserted.metadata.sourceUrl = fetch.sourceUrl
        inserted.metadata.repo = repo
        inserted.metadata.path = path
        inserted.metadata.symbol = symbol
        inserted.metadata.contentSize = fetch.body.size
        inserted.metadata.trustLevel = trustLevel
        inserted.metadata.reviewState = reviewState
        inserted.metadata.repoVisibility = fetch.repoVisibility
        inserted.metadata.commit = if (fetch.commit != "") { fetch.commit } else { inserted.metadata.commit }
        inserted.metadata.docVersion = if (fetch.ref != "") { fetch.ref } else { inserted.metadata.docVersion }
        inserted.metadata.targetVersion = cangjieDefaultTargetVersion()
        inserted.metadata.sourceSet = cangjieSourceSetForIngest(sourceType, repo, path, fetch.sourceUrl)
        inserted.metadata.versionResolutionId = cangjieIngestVersionResolutionId(inserted.metadata)
        this.storage.rawCount = this.rawRecords.size
        true
    }

    public func activeSnapshotForRollback(): ActiveSnapshot {
        let snapshot = ActiveSnapshot()
        snapshot.valid = true
        snapshot.activeVersion = this.activeKnowledgeVersion
        snapshot.candidateVersion = this.candidateKnowledgeVersion
        snapshot.failedVersion = this.failedCandidateVersion
        snapshot.activeStateSource = this.activeStateSource
        snapshot.vectorActiveCollection = this.vectorCollection
        snapshot.vectorCandidateCollection = this.candidateVectorCollection
        for (record in this.rawRecords) {
            snapshot.rawRecords.add(this.copyRawRecord(record))
        }
        for (record in this.normalizedRecords) {
            snapshot.normalizedRecords.add(this.copyNormalizedRecord(record))
        }
        for (record in this.activeIndex) {
            snapshot.activeIndex.add(this.copyNormalizedRecord(record))
        }
        snapshot
    }

    // Candidate promotion shares embedding/vector backends for its dedicated
    // staging collection, but copies state directly: restoreActiveSnapshot()
    // would rebuild the shared active vector/graph before transaction commit.
    public func forkIsolatedCandidate(): KnowledgeBase {
        let child = KnowledgeBase(FakeClock(this.scheduler.clock.nowMinutes),
            this.embeddingProvider, this.vectorStore, LocalGraphStore())
        for (record in this.rawRecords) { child.rawRecords.add(child.copyRawRecord(record)) }
        for (record in this.normalizedRecords) { child.normalizedRecords.add(child.copyNormalizedRecord(record)) }
        for (record in this.activeIndex) { child.activeIndex.add(child.copyNormalizedRecord(record)) }
        child.activeKnowledgeVersion = this.activeKnowledgeVersion
        child.candidateKnowledgeVersion = this.candidateKnowledgeVersion
        child.failedCandidateVersion = this.failedCandidateVersion
        child.vectorCollection = this.vectorCollection
        child.candidateVectorCollection = this.candidateVectorCollection
        child.storage.vectorActiveCollection = this.storage.vectorActiveCollection
        child.storage.vectorCandidateCollection = this.storage.vectorCandidateCollection
        child.storage.rawCount = child.rawRecords.size
        child.storage.normalizedCount = child.normalizedRecords.size
        child.storage.indexCount = child.activeIndex.size
        child.activeStateSource = "candidate_isolated"
        child
    }

    private func hasRawRecord(sourceId: String): Bool {
        this.rawRecordIndex(sourceId) >= 0
    }

    private func rawRecordIndex(sourceId: String): Int64 {
        for (i in 0..this.rawRecords.size) {
            if (this.rawRecords[i].sourceId == sourceId) {
                return i
            }
        }
        -1
    }

    public func normalize(): Unit {
        this.normalizedRecords.clear()
        for (record in this.rawRecords) {
            let normalized = NormalizedRecord()
            normalized.sourceId = record.sourceId
            normalized.recordKind = this.normalizedKind(record)
            normalized.title = record.title
            normalized.chunk = record.content
            normalized.citation = this.publicCitation(record)
            normalized.metadata = record.metadata
            normalized.requiresReview = record.requiresReview
            this.normalizedRecords.add(normalized)
            let typed = cangjieTypedNormalizeRawRecord(record)
            for (typedRecord in typed.records) {
                this.normalizedRecords.add(cangjieTypedRecordToNormalized(typedRecord, record.metadata))
            }
        }
        this.storage.rawCount = this.rawRecords.size
        this.storage.normalizedCount = this.normalizedRecords.size
    }

    public func loadFirstInitializationTypedRecords(records: ArrayList<CangjieTypedRecord>, candidateVersion: String): String {
        this.rawRecords.clear()
        this.normalizedRecords.clear()
        this.candidateIndex.clear()
        this.candidateKnowledgeVersion = ""
        this.failedCandidateVersion = ""
        for (record in records) {
            let normalized = cangjieTypedRecordToNormalized(record, KnowledgeMetadata())
            let raw = RawRecord()
            raw.sourceId = normalized.sourceId
            raw.title = normalized.title
            raw.content = normalized.chunk
            raw.metadata = normalized.metadata
            raw.contentHash = if (record.contentHash != "") { record.contentHash } else { cangjieTypedRecordContentHash(record.sourceId, record.content) }
            raw.requiresReview = normalized.requiresReview
            this.rawRecords.add(raw)
            this.normalizedRecords.add(normalized)
        }
        this.storage.rawCount = this.rawRecords.size
        this.storage.normalizedCount = this.normalizedRecords.size
        this.stageCandidateIndex(candidateVersion)
    }

    public func promoteFirstInitializationCandidate(activeVersion: String): Bool {
        let ok = this.promoteCandidateToActive(activeVersion)
        if (ok) {
            this.activeStateSource = "first_initialization"
            this.restoreDiagnostic = "ok"
        }
        ok
    }

    private func cangjieSourceSetForIngest(sourceType: String, repo: String, path: String, sourceUrl: String): String {
        if (sourceType == SourceTypes.DOC || sourceType == SourceTypes.WEBSITE) {
            return cangjieSourceSetForDocPath(path, sourceUrl)
        }
        let value = "${repo}\n${path}\n${sourceUrl}".toAsciiLower()
        if (value.contains("cangjie_stdx") || value.contains("/stdx/") || value.contains("stdx")) {
            return CangjieSourceSets.STDX
        }
        if (value.contains("cangjie_runtime") || value.contains("/std/") || value.contains("stdlib")) {
            return CangjieSourceSets.STD
        }
        ""
    }

    private func cangjieIngestVersionResolutionId(metadata: KnowledgeMetadata): String {
        if (metadata.versionResolutionId != "") {
            return metadata.versionResolutionId
        }
        if (metadata.sourceSet == "") {
            return ""
        }
        let ref = if (metadata.docVersion != "") { metadata.docVersion } else { "release-1.0.0" }
        "cangjie-${metadata.targetVersion}-${metadata.sourceSet}-${ref}"
    }

    private func normalizedKind(record: RawRecord): String {
        if (record.metadata.sourceType == SourceTypes.REPO && record.metadata.symbol != "") {
            return "code_entity"
        }
        if (record.metadata.sourceType == SourceTypes.COMMUNITY) {
            return "comment_record"
        }
        if (record.metadata.sourceType == SourceTypes.WEB_CANDIDATE) {
            return "web_candidate"
        }
        if (record.metadata.sourceType == SourceTypes.DOC || record.metadata.sourceType == SourceTypes.WEBSITE) {
            return "document_chunk"
        }
        "chunk"
    }

    private func publicCitation(record: RawRecord): String {
        if (record.metadata.sourceType == SourceTypes.REPO) {
            return "${record.metadata.repo}:${record.metadata.path}#${record.metadata.symbol}"
        }
        if (record.metadata.sourceType == SourceTypes.COMMUNITY) {
            return "${record.metadata.repo}:${record.metadata.sourceUrl}"
        }
        record.metadata.sourceUrl
    }

    public func stageCandidateIndex(candidateVersion: String): String {
        this.candidateKnowledgeVersion = if (candidateVersion.trimAscii() == "") { "ckb-20260519-000100-candidate" } else { candidateVersion.trimAscii() }
        this.candidateIndex.clear()
        for (record in this.normalizedRecords) {
            record.metadata.candidateVersion = this.candidateKnowledgeVersion
            this.candidateIndex.add(record)
        }
        this.candidateKnowledgeVersion
    }

    public func stageCandidateRecords(candidateVersion: String, records: ArrayList<NormalizedRecord>): String {
        this.candidateKnowledgeVersion = if (candidateVersion.trimAscii() == "") { "ckb-20260519-000100-candidate" } else { candidateVersion.trimAscii() }
        this.candidateIndex.clear()
        for (record in records) {
            let candidate = this.copyNormalizedRecord(record)
            candidate.metadata.candidateVersion = this.candidateKnowledgeVersion
            this.candidateIndex.add(candidate)
        }
        this.candidateKnowledgeVersion
    }

    public func markCandidateValidationFailed(candidateVersion: String): Unit {
        let failedVersion = if (candidateVersion.trimAscii() == "") { this.candidateKnowledgeVersion } else { candidateVersion.trimAscii() }
        this.candidateKnowledgeVersion = failedVersion
        this.failedCandidateVersion = failedVersion
    }

    public func promoteCandidateToActive(activeVersion: String): Bool {
        if (this.candidateIndex.size == 0 || this.candidateKnowledgeVersion == "") {
            this.failedCandidateVersion = if (this.candidateKnowledgeVersion == "") { "candidate_missing" } else { this.candidateKnowledgeVersion }
            return false
        }
        this.activeIndex.clear()
        this.invalidateStudentServingProjection()
        for (record in this.candidateIndex) {
            this.activeIndex.add(record)
        }
        this.activeKnowledgeVersion = if (activeVersion.trimAscii() == "") { this.candidateKnowledgeVersion.replace("-candidate", "-active") } else { activeVersion.trimAscii() }
        for (record in this.activeIndex) {
            record.metadata.knowledgeVersion = this.activeKnowledgeVersion
            record.metadata.candidateVersion = this.candidateKnowledgeVersion
        }
        this.adoptActiveCandidateAsNormalized()
        this.failedCandidateVersion = ""
        this.storage.indexCount = this.activeIndex.size
        this.invalidateServingCacheOnActiveVersionChange()
        this.rebuildProductionIndexes()
        this.rebuildIndexManifest()
        true
    }

    public func commitCandidateToActiveAfterVectorReady(activeVersion: String, vectorCollection: String,
        vectorStatus: VectorStoreStatus, deadlineAtMillis!: Int64 = 0,
        validatedServingSummary!: CkbValidatedServingIndexSummary = CkbValidatedServingIndexSummary(),
        releaseExistingGraph!: Bool = false): Bool {
        this.ensureActiveCommitDeadline("candidate_active_commit_before", deadlineAtMillis)
        if (this.candidateIndex.size == 0 || this.candidateKnowledgeVersion == "") {
            this.failedCandidateVersion = if (this.candidateKnowledgeVersion == "") { "candidate_missing" } else { this.candidateKnowledgeVersion }
            return false
        }
        if (vectorStatus.state != EmbeddingProviderState.READY) {
            this.failedCandidateVersion = this.candidateKnowledgeVersion
            return false
        }
        let effectiveActiveVersion = if (activeVersion.trimAscii() == "") {
            this.candidateKnowledgeVersion.replace("-candidate", "-active")
        } else { activeVersion.trimAscii() }
        let candidateRecordsEvidenceHash = ckbCandidateRecordsEvidenceHash(this.candidateIndex)
        let validatedServingSummaryMatches = ckbValidatedServingIndexSummaryMatches(
            validatedServingSummary, candidateRecordsEvidenceHash, effectiveActiveVersion)
        this.activeIndex.clear()
        this.invalidateStudentServingProjection()
        var copied: Int64 = 0
        for (record in this.candidateIndex) {
            if (copied % 256 == 0) {
                this.ensureActiveCommitDeadline("candidate_active_commit_copy", deadlineAtMillis)
            }
            this.activeIndex.add(record)
            copied += 1
        }
        this.activeKnowledgeVersion = effectiveActiveVersion
        var updated: Int64 = 0
        for (record in this.activeIndex) {
            if (updated % 256 == 0) {
                this.ensureActiveCommitDeadline("candidate_active_commit_metadata", deadlineAtMillis)
            }
            record.metadata.knowledgeVersion = this.activeKnowledgeVersion
            record.metadata.candidateVersion = this.candidateKnowledgeVersion
            updated += 1
        }
        this.adoptActiveCandidateAsNormalized()
        this.failedCandidateVersion = ""
        this.storage.indexCount = this.activeIndex.size
        this.promoteVectorActiveCollection(vectorCollection)
        this.applyVectorStatus(vectorStatus)
        this.invalidateServingCacheOnActiveVersionChange()
        let servingDiagnostic = if (validatedServingSummaryMatches) {
            this.storage.servingIndexCount = validatedServingSummary.documentCount
            this.storage.servingIndexVersion = validatedServingSummary.activeVersion
            this.storage.servingIndexDiagnostic = validatedServingSummary.servingDiagnostic
            ""
        } else {
            this.rebuildServingIndexStatus(deadlineAtMillis: deadlineAtMillis)
        }
        if (servingDiagnostic != "") {
            throw Exception(servingDiagnostic)
        }
        let graphDiagnostic = this.rebuildGraphIndex(deadlineAtMillis: deadlineAtMillis,
            releaseExisting: releaseExistingGraph)
        if (graphDiagnostic != "") {
            throw Exception(graphDiagnostic)
        }
        this.ensureActiveCommitDeadline("candidate_active_manifest_before", deadlineAtMillis)
        this.rebuildIndexManifest()
        this.ensureActiveCommitDeadline("candidate_active_commit_after", deadlineAtMillis)
        true
    }

    private func adoptActiveCandidateAsNormalized(): Unit {
        this.normalizedRecords.clear()
        for (record in this.candidateIndex) {
            this.normalizedRecords.add(this.copyNormalizedRecord(record))
        }
        this.storage.normalizedCount = this.normalizedRecords.size
    }

    public func publishIndex(simulateFailure: Bool): Bool {
        let candidateVersion = this.stageCandidateIndex("ckb-20260519-000100-candidate")
        if (simulateFailure) {
            this.markCandidateValidationFailed(candidateVersion)
            return false
        }
        this.promoteCandidateToActive("ckb-20260519-000100-active")
    }

    public func candidateRecordSnapshot(): ArrayList<NormalizedRecord> {
        let out = ArrayList<NormalizedRecord>()
        for (record in this.candidateIndex) {
            out.add(record)
        }
        out
    }

    public func activeRecordSnapshot(): ArrayList<NormalizedRecord> {
        let out = ArrayList<NormalizedRecord>()
        for (record in this.activeIndex) {
            out.add(record)
        }
        out
    }

    public func prepareStudentServingProjection(
        buildObserver!: CangjieServingIndexBuildObserver = NoopCangjieServingIndexBuildObserver()): CangjieStudentServingProjection {
        if (this.studentServingProjection.diagnostic == "student_serving_projection_unprepared") {
            this.studentServingProjection = buildCangjieStudentServingProjection(
                this.activeRecordSnapshot(), this.activeKnowledgeVersion,
                buildObserver: buildObserver)
        }
        let diagnostic = cangjieStudentServingProjectionDiagnostic(
            this.studentServingProjection, this.activeKnowledgeVersion)
        if (diagnostic != "ok") {
            this.studentServingProjection.valid = false
            if (diagnostic == "student_serving_projection_version_drift") {
                this.studentServingProjection.diagnostic = diagnostic
            }
        }
        this.studentServingProjection
    }

    private func invalidateStudentServingProjection(): Unit {
        this.studentServingProjection = CangjieStudentServingProjection()
    }

    func rawRecordSnapshot(): ArrayList<RawRecord> {
        let out = ArrayList<RawRecord>()
        for (record in this.rawRecords) {
            out.add(this.copyRawRecord(record))
        }
        out
    }

    func rawRecordSnapshotOverlayForOwner(owner: String, targetVersion: String, removedSourceIds: ArrayList<String>, current: ArrayList<RawRecord>): ArrayList<RawRecord> {
        let out = ArrayList<RawRecord>()
        let stats = CkbOverlayBuildStats()
        stats.activeRecords = this.rawRecords.size
        stats.deltaRecords = current.size
        let removedIds = HashSet<String>(removedSourceIds)
        let currentIds = HashSet<String>()
        for (record in current) {
            if (record.sourceId != "") {
                currentIds.add(record.sourceId)
            }
        }
        for (record in this.rawRecords) {
            if (this.recordOwnedBy(record.metadata, owner, targetVersion)) { continue }
            if (record.sourceId != "" && (removedIds.contains(record.sourceId) || currentIds.contains(record.sourceId))) { continue }
            out.add(record)
        }
        for (record in current) {
            out.add(record)
        }
        stats.removedRecords = removedSourceIds.size
        stats.outputRecords = out.size
        stats.processedRecords = this.rawRecords.size + current.size
        stats.peakAuxiliaryRecords = removedIds.size + currentIds.size
        stats.evidenceHash = contentHash(owner, "${targetVersion}:${stats.activeRecords}:${stats.deltaRecords}:${stats.removedRecords}:${stats.outputRecords}")
        this.lastOverlayBuildStats = stats
        out
    }

    func replaceRawRecords(records: ArrayList<RawRecord>): Unit {
        this.rawRecords.clear()
        for (record in records) {
            this.rawRecords.add(this.copyRawRecord(record))
        }
        this.storage.rawCount = this.rawRecords.size
    }

    public func activeEmbeddingTextSnapshot(limit!: Int64 = -1): ArrayList<String> {
        let out = ArrayList<String>()
        for (record in this.activeIndex) {
            if (limit >= 0 && out.size >= limit) {
                break
            }
            out.add(this.vectorText(record))
        }
        out
    }

    public func activeRecordSnapshotOverlay(delta: ArrayList<NormalizedRecord>): ArrayList<NormalizedRecord> {
        let out = ArrayList<NormalizedRecord>()
        let replacementKeys = HashSet<String>()
        for (record in delta) { replacementKeys.add(this.normalizedLogicalKey(record)) }
        for (record in this.activeIndex) {
            if (!replacementKeys.contains(this.normalizedLogicalKey(record))) {
                out.add(record)
            }
        }
        for (record in delta) {
            out.add(record)
        }
        let stats = CkbOverlayBuildStats()
        stats.activeRecords = this.activeIndex.size
        stats.deltaRecords = delta.size
        stats.outputRecords = out.size
        stats.processedRecords = this.activeIndex.size + delta.size
        stats.peakAuxiliaryRecords = replacementKeys.size
        stats.evidenceHash = contentHash("overlay", "${stats.activeRecords}:${stats.deltaRecords}:${stats.outputRecords}")
        this.lastOverlayBuildStats = stats
        out
    }

    func activeRecordSnapshotOverlayForOwner(delta: ArrayList<NormalizedRecord>, owner: String, targetVersion: String, removedSourceIds: ArrayList<String>): ArrayList<NormalizedRecord> {
        let out = ArrayList<NormalizedRecord>()
        let deltaIds = HashSet<String>()
        let removedIds = HashSet<String>(removedSourceIds)
        for (record in delta) {
            if (record.sourceId != "") {
                deltaIds.add(record.sourceId)
            }
        }
        for (record in this.activeIndex) {
            if (this.recordOwnedBy(record.metadata, owner, targetVersion)) {
                continue
            }
            if (record.sourceId != "" && removedIds.contains(record.sourceId)) {
                continue
            }
            if (record.sourceId != "" && deltaIds.contains(record.sourceId)) {
                continue
            }
            out.add(record)
        }
        for (record in delta) {
            out.add(record)
        }
        let stats = CkbOverlayBuildStats()
        stats.activeRecords = this.activeIndex.size
        stats.deltaRecords = delta.size
        stats.removedRecords = removedSourceIds.size
        stats.outputRecords = out.size
        stats.processedRecords = this.activeIndex.size + delta.size
        stats.peakAuxiliaryRecords = deltaIds.size + removedIds.size
        stats.evidenceHash = contentHash(owner, "${targetVersion}:${stats.activeRecords}:${stats.deltaRecords}:${stats.removedRecords}:${stats.outputRecords}")
        this.lastOverlayBuildStats = stats
        out
    }

    public func overlayBuildStats(): CkbOverlayBuildStats {
        this.lastOverlayBuildStats
    }

    public func candidateMaterializationStats(): CkbCandidateMaterializationResult {
        this.lastCandidateMaterialization
    }

    private func normalizedLogicalKey(record: NormalizedRecord): String {
        if (record.sourceId != "") { return "id:${record.sourceId}" }
        "fallback:${record.recordKind}:${contentHash(record.title, record.citation)}"
    }

    private func recordOwnedBy(metadata: KnowledgeMetadata, owner: String, targetVersion: String): Bool {
        metadata.crawlAt == owner && (targetVersion == "" || metadata.targetVersion == targetVersion)
    }

    private func copyNormalizedRecord(record: NormalizedRecord): NormalizedRecord {
        let out = NormalizedRecord()
        out.sourceId = record.sourceId
        out.recordKind = record.recordKind
        out.title = record.title
        out.chunk = record.chunk
        out.citation = record.citation
        out.score = record.score
        out.metadata = cangjieCopyKnowledgeMetadata(record.metadata)
        out.requiresReview = record.requiresReview
        out
    }

    private func copyRawRecord(record: RawRecord): RawRecord {
        let out = RawRecord()
        out.sourceId = record.sourceId
        out.title = record.title
        out.content = record.content
        out.metadata = cangjieCopyKnowledgeMetadata(record.metadata)
        out.contentHash = record.contentHash
        out.requiresReview = record.requiresReview
        out
    }

    public func rebuildIndex(simulateFailure: Bool, progressSink!: VectorBuildProgressSink = NoopVectorBuildProgressSink(), targetVectorCollection!: String = "", deadlineAtMillis!: Int64 = 0): IndexBuildResult {
        let builder = IndexBuilder()
        let result = builder.rebuild(this.normalizedRecords, this.activeKnowledgeVersion, "ckb-20260519-000200-candidate", fail: simulateFailure)
        this.candidateKnowledgeVersion = result.candidateVersion
        this.candidateIndex.clear()
        for (record in this.normalizedRecords) {
            record.metadata.candidateVersion = result.candidateVersion
            this.candidateIndex.add(record)
        }
        if (!result.ok) {
            this.failedCandidateVersion = result.failedVersion
            return result
        }
        this.activeIndex.clear()
        this.invalidateStudentServingProjection()
        for (record in this.candidateIndex) {
            record.metadata.knowledgeVersion = result.activeVersion
            record.metadata.candidateVersion = result.candidateVersion
            this.activeIndex.add(record)
        }
        this.activeKnowledgeVersion = result.activeVersion
        this.failedCandidateVersion = ""
        this.storage.indexCount = this.activeIndex.size
        this.invalidateServingCacheOnActiveVersionChange()
        this.lastVectorIndexBuildResult = this.rebuildProductionIndexesWithResult("", progressSink: progressSink, targetVectorCollection: targetVectorCollection, deadlineAtMillis: deadlineAtMillis)
        this.rebuildIndexManifest()
        result
    }

    public func reconcileProductionVectorIndex(progressSink!: VectorBuildProgressSink =
        NoopVectorBuildProgressSink(), targetVectorCollection!: String = "",
        deadlineAtMillis!: Int64 = 0): IndexBuildResult {
        let result = IndexBuildResult()
        result.activeVersion = this.activeKnowledgeVersion
        result.candidateVersion = this.candidateKnowledgeVersion
        result.count = this.activeIndex.size
        if (this.activeKnowledgeVersion == "" || this.activeIndex.size == 0) {
            result.failedVersion = "active_snapshot_empty"
            return result
        }
        this.lastVectorIndexBuildResult = this.rebuildProductionVectorIndexWithResult(
            progressSink: progressSink, targetVectorCollection: targetVectorCollection,
            deadlineAtMillis: deadlineAtMillis)
        result.ok = this.lastVectorIndexBuildResult.ok
        if (!result.ok) {
            result.failedVersion = if (this.lastVectorIndexBuildResult.diagnostic != "") {
                this.lastVectorIndexBuildResult.diagnostic
            } else { "vector_rebuild_failed" }
        }
        this.rebuildIndexManifest()
        result
    }

    private func rebuildProductionIndexes(): Unit {
        this.lastVectorIndexBuildResult = this.rebuildProductionIndexesWithResult("", progressSink: NoopVectorBuildProgressSink())
    }

    private func rebuildProductionIndexesWithResult(reason: String, progressSink!: VectorBuildProgressSink = NoopVectorBuildProgressSink(), targetVectorCollection!: String = "", deadlineAtMillis!: Int64 = 0): VectorIndexBuildResult {
        let started = ckbCoreNowMillis()
        let result = VectorIndexBuildResult()
        result.diagnostic = reason
        if (this.applyDeadlineToVectorResult(result, "rebuild_serving_before", deadlineAtMillis, started)) {
            return result
        }
        this.rebuildServingIndexStatus()
        if (this.applyDeadlineToVectorResult(result, "rebuild_serving_after", deadlineAtMillis, started)) {
            return result
        }
        if (this.applyDeadlineToVectorResult(result, "rebuild_vector_before", deadlineAtMillis, started)) {
            return result
        }
        let vector = this.rebuildProductionVectorIndexWithResult(progressSink: progressSink, targetVectorCollection: targetVectorCollection, deadlineAtMillis: deadlineAtMillis)
        if (this.applyDeadlineToVectorResult(result, "rebuild_vector_after", deadlineAtMillis, started)) {
            result.vectorCount = vector.vectorCount
            result.truncatedCount = vector.truncatedCount
            this.copyVectorBuildPayload(result, vector)
            return result
        }
        if (this.applyDeadlineToVectorResult(result, "rebuild_graph_before", deadlineAtMillis, started)) {
            result.vectorCount = vector.vectorCount
            result.truncatedCount = vector.truncatedCount
            this.copyVectorBuildPayload(result, vector)
            return result
        }
        let graphDiagnostic = this.rebuildGraphIndex(deadlineAtMillis: deadlineAtMillis)
        if (graphDiagnostic != "") {
            result.ok = false
            result.status = "deadline_exceeded"
            result.vectorCount = vector.vectorCount
            result.truncatedCount = vector.truncatedCount
            result.elapsedMillis = ckbCoreNowMillis() - started
            this.copyVectorBuildPayload(result, vector)
            result.diagnostic = if (result.diagnostic == "") { graphDiagnostic } else { "${result.diagnostic};${graphDiagnostic}" }
            return result
        }
        result.ok = vector.ok
        result.status = vector.status
        this.copyVectorBuildPayload(result, vector)
        result.vectorCount = vector.vectorCount
        result.graphNodes = this.storage.graphNodeCount
        result.servingCount = this.storage.servingIndexCount
        result.truncatedCount = vector.truncatedCount
        result.elapsedMillis = ckbCoreNowMillis() - started
        if (result.diagnostic == "") {
            result.diagnostic = vector.diagnostic
        } else if (vector.diagnostic != "") {
            result.diagnostic += ";${vector.diagnostic}"
        }
        result
    }

    private func copyVectorBuildPayload(target: VectorIndexBuildResult, source: VectorIndexBuildResult): Unit {
        target.vectorRecordsMaterialized = source.vectorRecordsMaterialized
        target.persistedVectorCollection = source.persistedVectorCollection
        if (source.vectorRecordsMaterialized) {
            for (record in source.vectorRecords) {
                target.vectorRecords.add(record)
            }
        }
    }

    private func applyDeadlineToVectorResult(result: VectorIndexBuildResult, stage: String, deadlineAtMillis: Int64, started: Int64): Bool {
        let deadline = ckbDeadlineGuard(stage, deadlineAtMillis)
        if (!deadline.exceeded) {
            return false
        }
        result.ok = false
        result.status = deadline.status
        result.elapsedMillis = ckbCoreNowMillis() - started
        result.diagnostic = if (result.diagnostic == "") { deadline.diagnostic } else { "${result.diagnostic};${deadline.diagnostic}" }
        true
    }

    private func rebuildProductionVectorIndexWithResult(progressSink!: VectorBuildProgressSink = NoopVectorBuildProgressSink(), targetVectorCollection!: String = "", deadlineAtMillis!: Int64 = 0): VectorIndexBuildResult {
        let effectiveVectorCollection = if (targetVectorCollection.trimAscii() == "") { this.vectorCollection } else { targetVectorCollection.trimAscii() }
        this.buildVectorIndexForRecordsInternal(this.activeIndex, effectiveVectorCollection, progressSink: progressSink, deadlineAtMillis: deadlineAtMillis, applyToStorage: true)
    }

    public func buildVectorIndexForRecords(records: ArrayList<NormalizedRecord>, collection: String, progressSink!: VectorBuildProgressSink = NoopVectorBuildProgressSink(), deadlineAtMillis!: Int64 = 0): VectorIndexBuildResult {
        this.buildVectorIndexForRecordsInternal(records, collection, progressSink: progressSink, deadlineAtMillis: deadlineAtMillis, applyToStorage: false)
    }

    public func buildVectorIndexForRecordsDurable(records: ArrayList<NormalizedRecord>, collection: String, store: FileKnowledgeStore, context: CkbCandidateAcquisitionContext, progressSink!: VectorBuildProgressSink = NoopVectorBuildProgressSink(), deadlineAtMillis!: Int64 = 0): VectorIndexBuildResult {
        let result = VectorIndexBuildResult()
        result.vectorRecordsMaterialized = false
        result.persistedVectorCollection = collection
        if (!context.valid()) {
            result.status = "candidate_acquisition_context_invalid"
            result.diagnostic = result.status
            return result
        }
        let actualRecordsEvidenceHash = ckbCandidateRecordsEvidenceHash(records)
        if (context.recordsEvidenceHash != actualRecordsEvidenceHash) {
            result.status = "candidate_records_evidence_mismatch"
            result.diagnostic = result.status
            return result
        }
        _ = store.cleanupVectorBuildStaleTemps(context.acquisitionId)
        let progress = VectorBuildProgress()
        progress.runId = if (context.schedulerRunId != "") { context.schedulerRunId } else { context.acquisitionId }
        progress.collection = collection
        progress.targetCollection = collection
        progress.total = records.size
        progress.dimension = this.activeEmbeddingDimensions()
        progress.batchSize = CkbCandidateDurableSchema.VECTOR_BATCH_SIZE
        progress.startedAtMillis = ckbCoreNowMillis()
        progress.updatedAtMillis = progress.startedAtMillis
        progress.state = "running"
        this.lastVectorBuildProgress = progress
        try { progressSink.onVectorBuildStarted(progress) } catch (_: Exception) { () }

        var descriptor = store.loadVectorSpoolCheckpoint(context, collection)
        var resumeValid = descriptor.valid && descriptor.total == records.size
        if (resumeValid) {
            let ready = this.vectorStore.ensureReadyCollection(collection)
            resumeValid = ready.state == EmbeddingProviderState.READY && ready.count <= descriptor.total
            let restoreCommitted = resumeValid && ready.count < descriptor.completed
            if (restoreCommitted) {
                let empty = ArrayList<VectorRecord>()
                let recreated = this.vectorStore.recreateWithDeadline(collection, empty, deadlineAtMillis)
                resumeValid = recreated.state == EmbeddingProviderState.READY
            }
            var committedStart: Int64 = 0
            for (index in 0..descriptor.batchRelativePaths.size) {
                if (!resumeValid) { break }
                let batch = store.loadVectorSpoolBatch(descriptor.batchRelativePaths[index], descriptor.batchEvidenceHashes[index])
                let committedCount = try { Int64.parse(descriptor.batchRecordCounts[index]) } catch (_: Exception) { -1 }
                if (!batch.valid || batch.records.size != committedCount || committedStart + committedCount > descriptor.completed) {
                    resumeValid = false
                    result.diagnostic = if (!batch.valid) { batch.diagnostic } else { "vector_spool_batch_count_mismatch" }
                    break
                }
                for (offset in 0..committedCount) {
                    if (!ckbVectorRecordMatchesSource(batch.records[offset], records[committedStart + offset])) {
                        resumeValid = false
                        result.diagnostic = "vector_spool_record_evidence_mismatch"
                        break
                    }
                }
                if (resumeValid && restoreCommitted) {
                    let restored = this.vectorStore.upsertBatchWithDeadline(collection, batch.records, deadlineAtMillis)
                    if (restored.state != EmbeddingProviderState.READY) {
                        resumeValid = false
                        result.diagnostic = restored.degradedReason
                    }
                }
                committedStart += committedCount
            }
            if (committedStart != descriptor.completed) { resumeValid = false; result.diagnostic = "vector_spool_committed_cursor_mismatch" }
        }
        if (!resumeValid) {
            _ = store.deleteS4ArtifactTree("metadata/vector-builds/${context.acquisitionId}")
            descriptor = CkbVectorSpoolDescriptor()
            descriptor.acquisitionId = context.acquisitionId
            descriptor.candidateVersion = context.candidateVersion
            descriptor.planHash = context.planHash
            descriptor.recordsEvidenceHash = context.recordsEvidenceHash
            descriptor.collection = collection
            descriptor.total = records.size
            descriptor.batchSize = CkbCandidateDurableSchema.VECTOR_BATCH_SIZE
            descriptor.status = "running"
            let empty = ArrayList<VectorRecord>()
            let recreated = this.vectorStore.recreateWithDeadline(collection, empty, deadlineAtMillis)
            if (recreated.state != EmbeddingProviderState.READY) {
                result.status = recreated.state
                result.diagnostic = recreated.degradedReason
                return result
            }
            store.saveVectorSpoolCheckpoint(descriptor)
        } else {
            descriptor.failed = 0
            descriptor.status = "running"
            store.saveVectorSpoolCheckpoint(descriptor)
            progress.completed = descriptor.completed
            progress.reused = descriptor.reused
            progress.embedded = descriptor.embedded
        }

        let embeddingStatus = this.embeddingProvider.status()
        let budget = ckbEmbeddingTextBudgetFromStatus(embeddingStatus)
        let budgeter = CkbEmbeddingTextBudgeter(budget)
        var start = descriptor.completed
        var batchIndex = descriptor.batchRelativePaths.size
        while (start < records.size) {
            if (ckbDeadlineExceeded(deadlineAtMillis)) {
                result.status = EmbeddingProviderState.DEGRADED
                result.diagnostic = "vector_build_deadline_exceeded:${collection}:${start}:${records.size}"
                result.spool = descriptor
                return result
            }
            var end = start
            var plannedBufferedBytes: Int64 = 0
            while (end < records.size && end - start < descriptor.batchSize) {
                let estimated = ckbVectorSourceBufferedBytes(records[end], this.activeEmbeddingDimensions(), ordinal: end)
                if (estimated > CkbCandidateDurableSchema.VECTOR_MAX_BUFFER_BYTES) {
                    descriptor.status = "vector_record_oversized"
                    store.saveVectorSpoolCheckpoint(descriptor)
                    result.status = EmbeddingProviderState.DEGRADED
                    result.diagnostic = "vector_record_oversized:${ckbReleaseEvidenceHash(records[end].sourceId)}:${estimated}:${CkbCandidateDurableSchema.VECTOR_MAX_BUFFER_BYTES}"
                    result.spool = descriptor
                    return result
                }
                if (end > start && plannedBufferedBytes + estimated > CkbCandidateDurableSchema.VECTOR_MAX_BUFFER_BYTES) { break }
                plannedBufferedBytes += estimated
                end += 1
            }
            let pointIds = ArrayList<String>()
            for (index in start..end) {
                // Migrate both current stable IDs and the pre-S4
                // ordinal/weak-hash IDs in one bounded request (128 * 2).
                pointIds.add(ckbVectorPointId(records[index]))
                pointIds.add(ckbLegacyVectorPointId(records[index], index))
            }
            var batchBufferedBytes = plannedBufferedBytes
            progress.currentBatch = batchIndex
            progress.currentBatchStart = start
            progress.currentBatchEnd = end
            progress.lookupRequested = pointIds.size
            progress.lookupFound = 0
            progress.lookupStatus = "running"
            progress.lookupDurationMillis = 0
            progress.lookupTimedOut = false
            progress.updatedAtMillis = ckbCoreNowMillis()
            try { progressSink.onVectorBatchStarted(progress) } catch (_: Exception) { () }
            let lookupStartedAtMillis = ckbCoreNowMillis()
            let lookup = this.vectorStore.lookupBatchWithDeadline(this.vectorCollection, pointIds, deadlineAtMillis)
            if (lookup.peakBufferedRecords > descriptor.peakBufferedRecords) { descriptor.peakBufferedRecords = lookup.peakBufferedRecords }
            progress.lookupFound = lookup.found
            progress.lookupStatus = lookup.status
            progress.lookupDurationMillis = ckbCoreNowMillis() - lookupStartedAtMillis
            progress.lookupTimedOut = lookup.status.contains("deadline") || lookup.status.contains("timeout")
            if (!lookup.ok) {
                progress.state = lookup.status
                progress.diagnostic = lookup.diagnostic
                progress.updatedAtMillis = ckbCoreNowMillis()
                try { progressSink.onVectorBatchFinished(progress) } catch (_: Exception) { () }
                result.status = lookup.status
                result.diagnostic = lookup.diagnostic
                result.spool = descriptor
                return result
            }
            let reusable = HashMap<String, ArrayList<Float64>>()
            for (record in lookup.records) {
                reusable[ckbVectorRecordStablePointId(record)] = record.vector
            }
            lookup.records.clear()
            pointIds.clear()
            let outputBatch = ArrayList<VectorRecord>()
            var batchReused: Int64 = 0
            var batchEmbedded: Int64 = 0
            var cursor = start
            while (cursor < end) {
                let source = records[cursor]
                let pointId = ckbVectorPointId(source)
                if (reusable.contains(pointId)) {
                    let output = this.vectorRecordFrom(source, reusable[pointId], pointId)
                    outputBatch.add(output)
                    batchReused += 1
                    if (reusable.size + outputBatch.size > descriptor.peakBufferedRecords) { descriptor.peakBufferedRecords = reusable.size + outputBatch.size }
                    cursor += 1
                    continue
                }
                let texts = ArrayList<String>()
                let sources = ArrayList<NormalizedRecord>()
                var preparedBytes: Int64 = 0
                var originalBytes: Int64 = 0
                var truncated: Int64 = 0
                while (cursor < end && texts.size < budget.maxBatchItems) {
                    let candidate = records[cursor]
                    let candidatePoint = ckbVectorPointId(candidate)
                    if (reusable.contains(candidatePoint)) {
                        if (texts.size == 0) {
                            let output = this.vectorRecordFrom(candidate, reusable[candidatePoint], candidatePoint)
                            outputBatch.add(output)
                            batchReused += 1
                            if (reusable.size + outputBatch.size > descriptor.peakBufferedRecords) { descriptor.peakBufferedRecords = reusable.size + outputBatch.size }
                            cursor += 1
                            continue
                        }
                        break
                    }
                    let prepared = budgeter.prepare(this.vectorText(candidate))
                    if (texts.size > 0 && budget.maxBatchBytes > 0 && preparedBytes + prepared.preparedBytes > budget.maxBatchBytes) {
                        break
                    }
                    texts.add(prepared.text)
                    sources.add(candidate)
                    preparedBytes += prepared.preparedBytes
                    originalBytes += prepared.originalBytes
                    if (prepared.truncated) { truncated += 1 }
                    cursor += 1
                }
                if (texts.size == 0) { continue }
                progress.currentBatch = batchIndex
                progress.currentBatchStart = start
                progress.currentBatchEnd = end
                progress.inputBytes = originalBytes
                progress.preparedBytes = preparedBytes
                progress.updatedAtMillis = ckbCoreNowMillis()
                try { progressSink.onVectorBatchStarted(progress) } catch (_: Exception) { () }
                let embedded = this.embeddingProvider.embedWithDeadline(texts, this.activeEmbeddingModel(), this.activeEmbeddingDimensions(), deadlineAtMillis)
                result.truncatedCount += truncated + embedded.truncatedCount
                if (embedded.status.state != EmbeddingProviderState.READY || embedded.vectors.size != texts.size) {
                    descriptor.failed += texts.size
                    descriptor.status = "embedding_batch_failed"
                    store.saveVectorSpoolCheckpoint(descriptor)
                    result.status = EmbeddingProviderState.DEGRADED
                    result.diagnostic = if (embedded.status.degradedReason != "") { embedded.status.degradedReason } else { "embedding_vector_count_mismatch" }
                    result.spool = descriptor
                    return result
                }
                for (index in 0..texts.size) {
                    let item = sources[index]
                    let output = this.vectorRecordFrom(item, embedded.vectors[index], ckbVectorPointId(item))
                    outputBatch.add(output)
                }
                if (reusable.size + outputBatch.size > descriptor.peakBufferedRecords) { descriptor.peakBufferedRecords = reusable.size + outputBatch.size }
                batchEmbedded += texts.size
            }
            if (outputBatch.size != end - start) {
                descriptor.failed += end - start - outputBatch.size
                descriptor.status = "vector_batch_cardinality_mismatch"
                store.saveVectorSpoolCheckpoint(descriptor)
                result.status = EmbeddingProviderState.DEGRADED
                result.diagnostic = "vector_batch_cardinality_mismatch:${outputBatch.size}:${end - start}"
                result.spool = descriptor
                return result
            }
            if (outputBatch.size > descriptor.peakBufferedRecords) { descriptor.peakBufferedRecords = outputBatch.size }
            let preparedPath = store.writeVectorSpoolBatch(descriptor, batchIndex, outputBatch, deadlineAtMillis: deadlineAtMillis)
            let preparedHash = store.vectorSpoolBatchEvidenceHash(outputBatch)
            let upserted = this.vectorStore.upsertBatchWithDeadline(collection, outputBatch, deadlineAtMillis)
            if (upserted.state != EmbeddingProviderState.READY) {
                _ = store.deleteS4ArtifactFile(preparedPath)
                descriptor.status = "vector_batch_upsert_failed"
                store.saveVectorSpoolCheckpoint(descriptor)
                result.status = upserted.state
                result.diagnostic = upserted.degradedReason
                result.spool = descriptor
                return result
            }
            descriptor.batchRelativePaths.add(preparedPath)
            descriptor.batchEvidenceHashes.add(preparedHash)
            descriptor.batchRecordCounts.add("${outputBatch.size}")
            descriptor.reused += batchReused
            descriptor.embedded += batchEmbedded
            if (batchBufferedBytes > descriptor.peakBufferedBytes) { descriptor.peakBufferedBytes = batchBufferedBytes }
            descriptor.completed = end
            descriptor.status = "running"
            store.saveVectorSpoolCheckpoint(descriptor)
            progress.completed = descriptor.completed
            progress.reused = descriptor.reused
            progress.embedded = descriptor.embedded
            progress.currentBatch = batchIndex
            progress.currentBatchStart = start
            progress.currentBatchEnd = end
            progress.updatedAtMillis = ckbCoreNowMillis()
            progress.elapsedMillis = progress.updatedAtMillis - progress.startedAtMillis
            try { progressSink.onVectorBatchFinished(progress) } catch (_: Exception) { () }
            batchIndex += 1
            start = end
        }
        let verified = this.vectorStore.status(collection)
        if (verified.state != EmbeddingProviderState.READY || verified.count != records.size) {
            descriptor.status = "vector_count_mismatch"
            store.saveVectorSpoolCheckpoint(descriptor)
            result.status = verified.state
            result.diagnostic = "vector_count_mismatch:${verified.count}:${records.size}"
            result.spool = descriptor
            return result
        }
        descriptor.valid = true
        descriptor.status = "completed"
        descriptor.completed = records.size
        descriptor.failed = 0
        if (descriptor.reused + descriptor.embedded != descriptor.total) {
            result.status = EmbeddingProviderState.DEGRADED
            result.diagnostic = "vector_committed_counter_mismatch:${descriptor.reused}:${descriptor.embedded}:${descriptor.total}"
            result.spool = descriptor
            return result
        }
        store.saveVectorSpoolCheckpoint(descriptor, completed: true)
        progress.state = EmbeddingProviderState.READY
        progress.completed = descriptor.completed
        progress.reused = descriptor.reused
        progress.embedded = descriptor.embedded
        progress.updatedAtMillis = ckbCoreNowMillis()
        progress.elapsedMillis = progress.updatedAtMillis - progress.startedAtMillis
        try { progressSink.onVectorBuildFinished(progress) } catch (_: Exception) { () }
        result.ok = true
        result.status = EmbeddingProviderState.READY
        result.vectorCount = descriptor.completed
        result.reused = descriptor.reused
        result.embedded = descriptor.embedded
        result.peakBufferedRecords = descriptor.peakBufferedRecords
        result.peakBufferedBytes = descriptor.peakBufferedBytes
        result.elapsedMillis = progress.elapsedMillis
        result.spool = descriptor
        result
    }

    private func buildVectorIndexForRecordsInternal(records: ArrayList<NormalizedRecord>, collection: String, progressSink!: VectorBuildProgressSink = NoopVectorBuildProgressSink(), deadlineAtMillis!: Int64 = 0, applyToStorage!: Bool = false): VectorIndexBuildResult {
        let result = VectorIndexBuildResult()
        let progress = VectorBuildProgress()
        let effectiveVectorCollection = if (collection.trimAscii() == "") { this.vectorCollection } else { collection.trimAscii() }
        let stagedCollection = applyToStorage && effectiveVectorCollection != this.vectorCollection
        let materializeVectorRecords = !stagedCollection
        result.vectorRecordsMaterialized = materializeVectorRecords
        result.persistedVectorCollection = effectiveVectorCollection
        progress.runId = ckbVectorBuildRunId()
        progress.collection = effectiveVectorCollection
        progress.targetCollection = effectiveVectorCollection
        progress.total = records.size
        progress.dimension = this.activeEmbeddingDimensions()
        let embeddingStatus = this.embeddingProvider.status()
        progress.batchSize = if (embeddingStatus.batchSize > 0) { embeddingStatus.batchSize } else { 16 }
        progress.startedAtMillis = ckbCoreNowMillis()
        progress.updatedAtMillis = progress.startedAtMillis
        progress.state = "running"
        this.lastVectorBuildProgress = progress
        progressSink.onVectorBuildStarted(progress)
        let empty = ArrayList<VectorRecord>()
        var vectorStatus = this.vectorStore.recreateWithDeadline(effectiveVectorCollection, empty, deadlineAtMillis)
        if (vectorStatus.state != EmbeddingProviderState.READY) {
            progress.state = vectorStatus.state
            progress.diagnostic = vectorStatus.degradedReason
            progress.updatedAtMillis = ckbCoreNowMillis()
            progress.elapsedMillis = progress.updatedAtMillis - progress.startedAtMillis
            if (applyToStorage) {
                this.applyVectorStatus(vectorStatus)
            }
            result.ok = false
            result.status = vectorStatus.state
            result.diagnostic = vectorStatus.degradedReason
            result.elapsedMillis = progress.elapsedMillis
            progress.lastDiagnostic = progress.diagnostic
            progressSink.onVectorBuildFinished(progress)
            return result
        }
        if (records.size == 0) {
            progress.state = EmbeddingProviderState.READY
            progress.updatedAtMillis = ckbCoreNowMillis()
            progress.elapsedMillis = progress.updatedAtMillis - progress.startedAtMillis
            vectorStatus.count = 0
            if (applyToStorage) {
                this.applyVectorStatus(vectorStatus)
            }
            result.ok = true
            result.status = EmbeddingProviderState.READY
            result.vectorCount = 0
            result.elapsedMillis = progress.elapsedMillis
            progressSink.onVectorBuildFinished(progress)
            return result
        }
        let reusable = if (stagedCollection) { ArrayList<VectorRecord>() } else { this.reusableVectorRecordsForBuild(records, this.vectorCollection, deadlineAtMillis) }
        let reusablePoints = this.vectorRecordPointIndex(reusable)
        var batchIndex: Int64 = 0
        if (reusable.size > 0) {
            let reuseBatchSize = ckbReusableVectorUpsertBatchSize()
            let reuseStatus = this.upsertVectorRecordsInBatches(effectiveVectorCollection, reusable, progress, progressSink, deadlineAtMillis, batchIndex, reuseBatchSize)
            if (reuseStatus.state != EmbeddingProviderState.READY) {
                progress.state = reuseStatus.state
                progress.diagnostic = reuseStatus.degradedReason
                progress.lastDiagnostic = reuseStatus.degradedReason
                progress.updatedAtMillis = ckbCoreNowMillis()
                progress.elapsedMillis = progress.updatedAtMillis - progress.startedAtMillis
                if (applyToStorage) {
                    this.applyVectorStatus(reuseStatus)
                }
                result.ok = false
                result.status = reuseStatus.state
                result.vectorCount = progress.completed
                result.diagnostic = reuseStatus.degradedReason
                result.elapsedMillis = progress.elapsedMillis
                progressSink.onVectorBuildFinished(progress)
                return result
            }
            if (materializeVectorRecords) {
                for (record in reusable) {
                    result.vectorRecords.add(record)
                }
            }
            batchIndex += ckbVectorBatchCount(reusable.size, reuseBatchSize)
            progress.batchSize = if (embeddingStatus.batchSize > 0) { embeddingStatus.batchSize } else { 16 }
        }
        let rawTexts = ArrayList<String>()
        let pendingRecords = ArrayList<NormalizedRecord>()
        let pendingOrdinals = ArrayList<Int64>()
        for (i in 0..records.size) {
            let record = records[i]
            if (reusablePoints.contains(ckbVectorPointId(record))) {
                continue
            }
            rawTexts.add(this.vectorText(record))
            pendingRecords.add(record)
            pendingOrdinals.add(i)
        }
        let textBatches = CkbEmbeddingTextBudgeter(ckbEmbeddingTextBudgetFromStatus(embeddingStatus)).batches(rawTexts)
        for (textBatch in textBatches) {
            if (ckbDeadlineExceeded(deadlineAtMillis)) {
                vectorStatus = this.vectorStore.status(effectiveVectorCollection)
                vectorStatus.state = EmbeddingProviderState.DEGRADED
                vectorStatus.count = progress.completed
                vectorStatus.degradedReason = "vector_build_deadline_exceeded:${effectiveVectorCollection}:${progress.completed}:${progress.total}"
                progress.state = vectorStatus.state
                progress.diagnostic = vectorStatus.degradedReason
                progress.lastDiagnostic = vectorStatus.degradedReason
                progress.updatedAtMillis = ckbCoreNowMillis()
                progress.elapsedMillis = progress.updatedAtMillis - progress.startedAtMillis
                if (applyToStorage) {
                    this.applyVectorStatus(vectorStatus)
                }
                result.ok = false
                result.status = vectorStatus.state
                result.vectorCount = progress.completed
                result.diagnostic = vectorStatus.degradedReason
                result.elapsedMillis = progress.elapsedMillis
                progressSink.onVectorBuildFinished(progress)
                return result
            }
            let texts = textBatch.texts
            progress.currentBatch = batchIndex
            progress.currentBatchStart = textBatch.startIndex
            progress.currentBatchEnd = textBatch.endIndex
            progress.inputBytes = textBatch.originalBytes
            progress.preparedBytes = textBatch.preparedBytes
            progress.updatedAtMillis = ckbCoreNowMillis()
            progress.elapsedMillis = progress.updatedAtMillis - progress.startedAtMillis
            progressSink.onVectorBatchStarted(progress)
            let batch = this.embeddingProvider.embedWithDeadline(texts, this.activeEmbeddingModel(), this.activeEmbeddingDimensions(), deadlineAtMillis)
            progress.failed += batch.failed
            result.truncatedCount += textBatch.truncatedCount + batch.truncatedCount
            if (batch.status.state != EmbeddingProviderState.READY || batch.vectors.size != texts.size) {
                vectorStatus = this.vectorStore.status(effectiveVectorCollection)
                vectorStatus.state = EmbeddingProviderState.DEGRADED
                vectorStatus.count = progress.completed
                vectorStatus.degradedReason = if (batch.status.degradedReason != "") {
                    "embedding_batch_failed:batch=${batchIndex}:${batch.status.degradedReason}"
                } else {
                    "embedding_batch_failed:batch=${batchIndex}:vector_count_mismatch:${batch.vectors.size}:${texts.size}"
                }
                progress.failed = texts.size
                progress.state = vectorStatus.state
                progress.diagnostic = vectorStatus.degradedReason
                progress.lastDiagnostic = vectorStatus.degradedReason
                progress.updatedAtMillis = ckbCoreNowMillis()
                progress.elapsedMillis = progress.updatedAtMillis - progress.startedAtMillis
                if (applyToStorage) {
                    this.applyVectorStatus(vectorStatus)
                }
                result.ok = false
                result.status = vectorStatus.state
                result.vectorCount = progress.completed
                result.diagnostic = vectorStatus.degradedReason
                result.elapsedMillis = progress.elapsedMillis
                progressSink.onVectorBatchFinished(progress)
                progressSink.onVectorBuildFinished(progress)
                return result
            }
            let vectorRecords = ArrayList<VectorRecord>()
            for (i in 0..texts.size) {
                let source = pendingRecords[textBatch.startIndex + i]
                let ordinal = pendingOrdinals[textBatch.startIndex + i]
                vectorRecords.add(this.vectorRecordFrom(source, batch.vectors[i], ckbVectorPointId(source)))
            }
            vectorStatus = this.vectorStore.upsertBatchWithDeadline(effectiveVectorCollection, vectorRecords, deadlineAtMillis)
            if (vectorStatus.state != EmbeddingProviderState.READY) {
                progress.failed = texts.size
                progress.state = vectorStatus.state
                progress.diagnostic = vectorStatus.degradedReason
                progress.lastDiagnostic = vectorStatus.degradedReason
                progress.updatedAtMillis = ckbCoreNowMillis()
                progress.elapsedMillis = progress.updatedAtMillis - progress.startedAtMillis
                vectorStatus.count = progress.completed
                if (applyToStorage) {
                    this.applyVectorStatus(vectorStatus)
                }
                result.ok = false
                result.status = vectorStatus.state
                result.vectorCount = progress.completed
                result.diagnostic = vectorStatus.degradedReason
                result.elapsedMillis = progress.elapsedMillis
                progressSink.onVectorBatchFinished(progress)
                progressSink.onVectorBuildFinished(progress)
                return result
            }
            if (materializeVectorRecords) {
                for (record in vectorRecords) {
                    result.vectorRecords.add(record)
                }
            }
            progress.embedded += texts.size
            progress.completed += texts.size
            progress.updatedAtMillis = ckbCoreNowMillis()
            progress.elapsedMillis = progress.updatedAtMillis - progress.startedAtMillis
            progressSink.onVectorBatchFinished(progress)
            batchIndex += 1
        }
        progress.state = EmbeddingProviderState.READY
        progress.updatedAtMillis = ckbCoreNowMillis()
        progress.elapsedMillis = progress.updatedAtMillis - progress.startedAtMillis
        vectorStatus.count = progress.completed
        if (applyToStorage) {
            this.applyVectorStatus(vectorStatus)
        }
        result.ok = true
        result.status = EmbeddingProviderState.READY
        result.vectorCount = progress.completed
        result.elapsedMillis = progress.elapsedMillis
        progressSink.onVectorBuildFinished(progress)
        result
    }

    private func vectorText(record: NormalizedRecord): String {
        "${record.title} ${record.chunk} ${record.metadata.repo} ${record.metadata.path} ${record.metadata.symbol}"
    }

    private func vectorRecordFrom(source: NormalizedRecord, vector: ArrayList<Float64>, pointId: String): VectorRecord {
        let vectorRecord = VectorRecord()
        vectorRecord.id = source.sourceId
        vectorRecord.pointId = pointId
        vectorRecord.vector = vector
        vectorRecord.metadata = source.metadata
        vectorRecord.title = source.title
        vectorRecord.chunk = source.chunk
        vectorRecord.citation = source.citation
        vectorRecord
    }

    private func reusableVectorRecordsForBuild(records: ArrayList<NormalizedRecord>, sourceCollection: String, deadlineAtMillis: Int64): ArrayList<VectorRecord> {
        let out = ArrayList<VectorRecord>()
        if (records.size == 0 || sourceCollection.trimAscii() == "" || ckbDeadlineExceeded(deadlineAtMillis)) {
            return out
        }
        let backup = this.vectorStore.backupWithDeadline(sourceCollection, deadlineAtMillis)
        if (!backup.valid || backup.records.size == 0) {
            return out
        }
        let dimension = this.activeEmbeddingDimensions()
        if (dimension <= 0 || this.vectorBackupDimension(backup.records) != dimension) {
            return out
        }
        let index = this.vectorBackupReuseIndex(backup.records, dimension)
        for (i in 0..records.size) {
            if (ckbDeadlineExceeded(deadlineAtMillis)) {
                return out
            }
            let source = records[i]
            let pointId = ckbVectorPointId(source)
            let reusable = this.reusableVectorRecordForPoint(index, source, pointId)
            if (reusable.pointId != "") {
                out.add(reusable)
            }
        }
        out
    }

    private func vectorBackupReuseIndex(records: ArrayList<VectorRecord>, dimension: Int64): VectorBackupReuseIndex {
        let index = VectorBackupReuseIndex()
        for (record in records) {
            if (record.vector.size != dimension) {
                continue
            }
            let pointId = vectorPointIdentity(record)
            if (pointId != "" && !index.byPoint.contains(pointId)) {
                index.byPoint[pointId] = record
            }
            let reuseIdentity = ckbVectorReuseIdentity(record.id, record.title, record.chunk, record.citation)
            if (!index.byContent.contains(reuseIdentity)) {
                index.byContent[reuseIdentity] = record
            }
        }
        index
    }

    private func reusableVectorRecordForPoint(index: VectorBackupReuseIndex, source: NormalizedRecord, pointId: String): VectorRecord {
        if (index.byPoint.contains(pointId)) {
            let record = index.byPoint[pointId]
            return this.vectorRecordFrom(source, record.vector, pointId)
        }
        let reuseIdentity = ckbVectorReuseIdentity(source.sourceId, source.title, source.chunk, source.citation)
        if (index.byContent.contains(reuseIdentity)) {
            let record = index.byContent[reuseIdentity]
            return this.vectorRecordFrom(source, record.vector, pointId)
        }
        VectorRecord()
    }

    private func vectorRecordPointIndex(records: ArrayList<VectorRecord>): HashMap<String, Bool> {
        let index = HashMap<String, Bool>()
        for (record in records) {
            let pointId = vectorPointIdentity(record)
            if (pointId != "") {
                index[pointId] = true
            }
        }
        index
    }

    private func upsertVectorRecordsInBatches(collection: String, records: ArrayList<VectorRecord>, progress: VectorBuildProgress, progressSink: VectorBuildProgressSink, deadlineAtMillis: Int64, startBatchIndex: Int64, batchSize: Int64): VectorStoreStatus {
        var last = VectorStoreStatus()
        last.collection = collection
        last.state = EmbeddingProviderState.READY
        last.count = progress.completed
        var start: Int64 = 0
        var batchIndex = startBatchIndex
        let effectiveBatchSize = if (batchSize > 0) { batchSize } else { 64 }
        while (start < records.size) {
            if (ckbDeadlineExceeded(deadlineAtMillis)) {
                last.state = EmbeddingProviderState.DEGRADED
                last.count = progress.completed
                last.degradedReason = "vector_build_deadline_exceeded:${collection}:${progress.completed}:${progress.total}"
                return last
            }
            let end = if (start + effectiveBatchSize < records.size) { start + effectiveBatchSize } else { records.size }
            let batch = ArrayList<VectorRecord>()
            for (i in start..end) {
                batch.add(records[i])
            }
            progress.currentBatch = batchIndex
            progress.currentBatchStart = start
            progress.currentBatchEnd = end
            progress.batchSize = effectiveBatchSize
            progress.updatedAtMillis = ckbCoreNowMillis()
            progress.elapsedMillis = progress.updatedAtMillis - progress.startedAtMillis
            progressSink.onVectorBatchStarted(progress)
            last = this.vectorStore.upsertBatchWithDeadline(collection, batch, deadlineAtMillis)
            if (last.state != EmbeddingProviderState.READY) {
                return last
            }
            progress.completed += batch.size
            progress.reused += batch.size
            progress.updatedAtMillis = ckbCoreNowMillis()
            progress.elapsedMillis = progress.updatedAtMillis - progress.startedAtMillis
            progressSink.onVectorBatchFinished(progress)
            batchIndex += 1
            start = end
        }
        last.count = progress.completed
        last
    }

    private func vectorBackupDimension(records: ArrayList<VectorRecord>): Int64 {
        var dimension: Int64 = 0
        for (record in records) {
            let size = record.vector.size
            if (size <= 0) {
                return 0
            }
            if (dimension == 0) {
                dimension = size
            } else if (dimension != size) {
                return -1
            }
        }
        dimension
    }

    private func rebuildServingIndexStatus(deadlineAtMillis!: Int64 = 0): String {
        let servingIndex = buildCangjieServingIndex(this.activeIndex, activeKnowledgeVersion: this.activeKnowledgeVersion, deadlineAtMillis: deadlineAtMillis)
        let deadlineDiagnostic = cangjieServingIndexDeadlineDiagnostic(servingIndex)
        if (deadlineDiagnostic != "") {
            servingIndex.records.clear()
            servingIndex.documents.clear()
            servingIndex.exactEntries.clear()
            return deadlineDiagnostic
        }
        let servingIndexCount = servingIndex.documents.size
        let servingIndexVersion = servingIndex.activeKnowledgeVersion
        let servingIndexDiagnostic = cangjieServingIndexDiagnostics(servingIndex)
        servingIndex.records.clear()
        servingIndex.documents.clear()
        servingIndex.exactEntries.clear()
        this.storage.servingIndexCount = servingIndexCount
        this.storage.servingIndexVersion = servingIndexVersion
        this.storage.servingIndexDiagnostic = servingIndexDiagnostic
        ""
    }

    private func ensureActiveCommitDeadline(stage: String, deadlineAtMillis: Int64): Unit {
        let deadline = ckbDeadlineGuard(stage, deadlineAtMillis)
        if (deadline.exceeded) {
            throw Exception(deadline.diagnostic)
        }
    }

    private func rebuildGraphIndex(deadlineAtMillis!: Int64 = 0, releaseExisting!: Bool = false): String {
        let beforeBuild = ckbDeadlineGuard("graph_build_before", deadlineAtMillis)
        if (beforeBuild.exceeded) {
            return beforeBuild.diagnostic
        }
        if (releaseExisting) {
            this.graphStore.clear()
            this.lastGraphBuildCache = CkbGraphBuildCache()
        }
        let graph = buildGraphFromRecords(this.activeIndex, this.activeKnowledgeVersion, deadlineAtMillis: deadlineAtMillis)
        if (!graph.ok) {
            return graph.diagnostic
        }
        let beforeUpsert = ckbDeadlineGuard("graph_upsert_before", deadlineAtMillis)
        if (beforeUpsert.exceeded) {
            return beforeUpsert.diagnostic
        }
        this.graphStore.replace(graph.nodes, graph.edges)
        let afterUpsert = ckbDeadlineGuard("graph_upsert_after", deadlineAtMillis)
        if (afterUpsert.exceeded) {
            return afterUpsert.diagnostic
        }
        let graphStatus = this.graphStore.status()
        this.storage.graphBackend = graphStatus.backend
        this.storage.graphState = graphStatus.state
        this.storage.graphNodeCount = graphStatus.dimension
        this.storage.graphEdgeCount = graphStatus.count
        this.cacheGraphBuild(graph, graphStatus)
        if (!this.lastGraphBuildCache.valid) {
            return "graph_store_commit_mismatch:expected_nodes=${graph.nodes.size}:actual_nodes=${graphStatus.dimension}:expected_edges=${graph.edges.size}:actual_edges=${graphStatus.count}:state=${graphStatus.state}"
        }
        ""
    }

    private func cacheGraphBuild(graph: GraphBuildResult, graphStatus: VectorStoreStatus): Unit {
        let cache = CkbGraphBuildCache()
        cache.recordsEvidenceHash = ckbCandidateRecordsEvidenceHash(this.activeIndex)
        cache.activeVersion = this.activeKnowledgeVersion
        cache.nodeCount = graph.nodes.size
        cache.edgeCount = graph.edges.size
        cache.graphEvidenceHash = ckbGraphBuildEvidenceHash(graph)
        cache.graph = graph
        cache.valid = graph.ok && graph.processed == graph.total && graph.total == this.activeIndex.size &&
            graphStatus.state == EmbeddingProviderState.READY && graphStatus.dimension == cache.nodeCount &&
            graphStatus.count == cache.edgeCount && cache.graphEvidenceHash != ""
        this.lastGraphBuildCache = cache
    }

    private func applyVectorStatus(status: VectorStoreStatus): Unit {
        this.storage.vectorBackend = status.backend
        this.storage.vectorState = status.state
        this.storage.vectorCollection = if (status.collection == "") { this.vectorCollection } else { status.collection }
        this.storage.vectorActiveCollection = this.vectorCollection
        this.storage.vectorCandidateCollection = this.candidateVectorCollection
        this.storage.vectorDimension = status.dimension
        this.storage.vectorDegradedReason = status.degradedReason
        this.storage.vectorIndexCount = status.count
    }

    private func rebuildIndexManifest(): Unit {
        let manifest = IndexManifest()
        manifest.activeVersion = this.activeKnowledgeVersion
        manifest.candidateVersion = this.candidateKnowledgeVersion
        manifest.entries.add(this.indexMetadata(IndexKinds.TEXT, this.activeIndex.size, "token overlap text index"))
        manifest.entries.add(this.indexMetadata(IndexKinds.VECTOR, this.storage.vectorIndexCount, "${this.storage.vectorBackend} vector backend state=${this.storage.vectorState} dimension=${this.storage.vectorDimension}"))
        manifest.entries.add(this.indexMetadata(IndexKinds.SYMBOL, this.countSymbolRecords(), "symbol metadata index"))
        manifest.entries.add(this.indexMetadata(IndexKinds.GRAPH, this.storage.graphEdgeCount, "${this.storage.graphBackend} neighbor graph nodes=${this.storage.graphNodeCount}"))
        manifest.entries.add(this.indexMetadata(IndexKinds.SERVING, this.storage.servingIndexCount, "serving activeVersion=${this.storage.servingIndexVersion} cacheSize=${this.storage.queryCacheSize} diagnostic=${this.storage.servingIndexDiagnostic}"))
        this.indexManifest = manifest
        this.storage.textIndexCount = this.activeIndex.size
        this.storage.symbolIndexCount = this.countSymbolRecords()
        this.storage.graphIndexCount = this.storage.graphEdgeCount
    }

    private func indexMetadata(kind: String, count: Int64, notes: String): IndexMetadata {
        let metadata = IndexMetadata()
        metadata.kind = kind
        metadata.version = this.activeKnowledgeVersion
        metadata.itemCount = count
        metadata.deterministic = true
        metadata.candidateIsolated = true
        metadata.notes = notes
        metadata
    }

    private func countSymbolRecords(): Int64 {
        var count: Int64 = 0
        for (record in this.activeIndex) {
            if (record.metadata.symbol != "") {
                count += 1
            }
        }
        count
    }

    private func countGraphEdges(): Int64 {
        var count: Int64 = 0
        for (record in this.activeIndex) {
            if (record.metadata.repo != "" && record.citation != "") {
                count += 1
            }
            if (record.metadata.sourceType == SourceTypes.COMMUNITY) {
                count += 1
            }
        }
        count
    }

    public func persist(store: FileKnowledgeStore): Unit {
        store.ensureLayout()
        store.saveRaw(this.rawRecords)
        store.saveNormalized(this.normalizedRecords)
        store.saveMetadata(this.status())
    }

    public func persistIndex(store: FileKnowledgeStore): Unit {
        store.ensureLayout()
        store.saveActiveIndex(this.activeIndex, this.activeKnowledgeVersion)
        if (this.candidateKnowledgeVersion != "") {
            store.saveCandidateIndex(this.candidateIndex, this.candidateKnowledgeVersion)
        }
        store.saveMetadata(this.status())
    }

    public func persistActiveSnapshot(store: FileKnowledgeStore, deadlineAtMillis!: Int64 = 0,
        expectedBaseActivePointerHash!: String = ""): CkbActiveSnapshotTransactionResult {
        store.ensureLayout()
        let graph = this.activeGraphBuildForSnapshot(deadlineAtMillis)
        if (!graph.ok) {
            throw Exception(graph.diagnostic)
        }
        this.requireCommittedActiveSnapshot(store.writeActiveSnapshotTransaction(this.status(), this.rawRecords, this.activeIndex,
            this.activeIndex, this.activeVectorRecords(), this.vectorCollection, graph,
            deadlineAtMillis: deadlineAtMillis,
            expectedBaseActivePointerHash: expectedBaseActivePointerHash))
    }

    public func persistActiveSnapshotUsingVectorRecords(store: FileKnowledgeStore, vectorRecords: ArrayList<VectorRecord>, persistVectorFile!: Bool = true, deadlineAtMillis!: Int64 = 0, stageSink!: CkbStagedRebuildStageSink = NoopCkbStagedRebuildStageSink(), expectedBaseActivePointerHash!: String = ""): CkbActiveSnapshotTransactionResult {
        store.ensureLayout()
        let graph = this.activeGraphBuildForSnapshot(deadlineAtMillis)
        if (!graph.ok) {
            throw Exception(graph.diagnostic)
        }
        this.requireCommittedActiveSnapshot(store.writeActiveSnapshotTransaction(this.status(), this.rawRecords, this.activeIndex,
            this.activeIndex, vectorRecords, this.vectorCollection, graph,
            persistVectorFile: persistVectorFile, deadlineAtMillis: deadlineAtMillis,
            stageSink: stageSink, expectedBaseActivePointerHash: expectedBaseActivePointerHash))
    }

    public func persistActiveSnapshotUsingVectorBuild(store: FileKnowledgeStore, vectorBuild: VectorIndexBuildResult, persistVectorFile!: Bool = true, deadlineAtMillis!: Int64 = 0, stageSink!: CkbStagedRebuildStageSink = NoopCkbStagedRebuildStageSink(), releaseBundle!: CkbReleaseCommitBundle = CkbReleaseCommitBundle(), repositoryEventIdentity!: String = "", faultInjector!: CkbActiveSnapshotFaultInjector = NoopCkbActiveSnapshotFaultInjector(), expectedBaseActivePointerHash!: String = ""): CkbActiveSnapshotTransactionResult {
        store.ensureLayout()
        let graph = this.activeGraphBuildForSnapshot(deadlineAtMillis)
        if (!graph.ok) { throw Exception(graph.diagnostic) }
        this.requireCommittedActiveSnapshot(store.writeActiveSnapshotTransaction(this.status(), this.rawRecords, this.activeIndex,
            this.activeIndex, vectorBuild.vectorRecords, this.vectorCollection, graph,
            persistVectorFile: persistVectorFile, deadlineAtMillis: deadlineAtMillis,
            stageSink: stageSink, vectorSpool: vectorBuild.spool, releaseBundle: releaseBundle,
            repositoryEventIdentity: repositoryEventIdentity,
            faultInjector: faultInjector,
            expectedBaseActivePointerHash: expectedBaseActivePointerHash))
    }

    private func requireCommittedActiveSnapshot(
        result: CkbActiveSnapshotTransactionResult): CkbActiveSnapshotTransactionResult {
        if (!result.businessCommitted) {
            let diagnostic = if (result.failureDiagnostic != "") {
                result.failureDiagnostic
            } else if (result.diagnostics.size > 0) {
                result.diagnostics[0]
            } else { "active_snapshot_transaction_not_committed" }
            throw Exception(diagnostic)
        }
        result
    }

    public func persistCandidateSnapshot(store: FileKnowledgeStore,
        deadlineAtMillis!: Int64 = 0): Unit {
        store.ensureLayout()
        let materialization = store.saveCandidateSnapshotImmutable(this.rawRecords, this.candidateIndex, this.candidateKnowledgeVersion, deadlineAtMillis: deadlineAtMillis)
        this.lastCandidateMaterialization = materialization
        if (!materialization.ok) {
            throw Exception(materialization.diagnostic)
        }
        store.saveCandidateLifecycleMetadata(this.status())
    }

    public func activeVectorRecords(): ArrayList<VectorRecord> {
        this.activeVectorRecordsWithResult().records
    }

    public func activeVectorRecordsWithResult(): VectorRecordsBuildResult {
        let result = VectorRecordsBuildResult()
        let started = ckbCoreNowMillis()
        let embeddingStatus = this.embeddingProvider.status()
        let rawTexts = ArrayList<String>()
        for (record in this.activeIndex) {
            rawTexts.add(this.vectorText(record))
        }
        let textBatches = CkbEmbeddingTextBudgeter(ckbEmbeddingTextBudgetFromStatus(embeddingStatus)).batches(rawTexts)
        for (textBatch in textBatches) {
            let texts = textBatch.texts
            let batch = this.embeddingProvider.embed(texts, this.activeEmbeddingModel(), this.activeEmbeddingDimensions())
            result.truncatedCount += textBatch.truncatedCount + batch.truncatedCount
            if (batch.status.state != EmbeddingProviderState.READY || batch.vectors.size != texts.size) {
                result.ok = false
                result.status = "embedding_rebuild_failed"
                result.failed = texts.size
                result.diagnostic = if (batch.status.degradedReason != "") { batch.status.degradedReason } else { "vector_count_mismatch:${batch.vectors.size}:${texts.size}" }
                result.elapsedMillis = ckbCoreNowMillis() - started
                return result
            }
            for (i in 0..texts.size) {
                let source = this.activeIndex[textBatch.startIndex + i]
                result.records.add(this.vectorRecordFrom(source, batch.vectors[i], ckbVectorPointId(source)))
            }
            result.processed += texts.size
        }
        result.ok = true
        result.status = EmbeddingProviderState.READY
        result.elapsedMillis = ckbCoreNowMillis() - started
        result
    }

    public func activeGraphBuild(deadlineAtMillis!: Int64 = 0): GraphBuildResult {
        buildGraphFromRecords(this.activeIndex, this.activeKnowledgeVersion, deadlineAtMillis: deadlineAtMillis)
    }

    private func activeGraphBuildForSnapshot(deadlineAtMillis: Int64): GraphBuildResult {
        let cache = this.lastGraphBuildCache
        let graphStatus = this.graphStore.status()
        if (ckbGraphSnapshotBindingMatches(cache.valid, cache.activeVersion, this.activeKnowledgeVersion,
            cache.recordsEvidenceHash, ckbCandidateRecordsEvidenceHash(this.activeIndex),
            cache.nodeCount, cache.graph.nodes.size, cache.edgeCount, cache.graph.edges.size,
            cache.graphEvidenceHash, ckbGraphBuildEvidenceHash(cache.graph), graphStatus)) {
            return cache.graph
        }
        let rebuiltDiagnostic = this.rebuildGraphIndex(deadlineAtMillis: deadlineAtMillis)
        if (rebuiltDiagnostic != "") {
            let failed = GraphBuildResult()
            failed.ok = false
            failed.diagnostic = rebuiltDiagnostic
            failed.total = this.activeIndex.size
            return failed
        }
        let rebuiltCache = this.lastGraphBuildCache
        if (!rebuiltCache.valid) {
            let failed = GraphBuildResult()
            failed.ok = false
            failed.diagnostic = "graph_cache_invalid_after_rebuild"
            failed.total = this.activeIndex.size
            return failed
        }
        rebuiltCache.graph
    }

    public func rawRecordCount(): Int64 {
        this.rawRecords.size
    }

    public func normalizedRecordCount(): Int64 {
        this.normalizedRecords.size
    }

    public func servingCacheLookup(key: CangjieQueryCacheKey): CangjieQueryCacheLookup {
        let lookup = this.servingQueryCache.get(key)
        this.storage.queryCacheSize = this.servingQueryCache.size()
        this.storage.queryCacheDiagnostic = if (lookup.hit) { "cache_hit" } else { lookup.diagnostic }
        lookup
    }

    public func servingCachePut(key: CangjieQueryCacheKey, valueHash: String): String {
        let status = this.servingQueryCache.put(key, valueHash)
        this.storage.queryCacheSize = this.servingQueryCache.size()
        this.storage.queryCacheDiagnostic = status
        status
    }

    public func servingCachePutResult(key: CangjieQueryCacheKey, valueHash: String, resultSummary: String, hitIds: ArrayList<String>): String {
        let status = this.servingQueryCache.putResult(key, valueHash, resultSummary: resultSummary, hitIds: hitIds, createdAt: this.scheduler.clock.nowMinutes)
        this.storage.queryCacheSize = this.servingQueryCache.size()
        this.storage.queryCacheDiagnostic = status
        status
    }

    public func recordServingCacheDiagnostic(diagnostic: String): Unit {
        this.storage.queryCacheDiagnostic = diagnostic
        this.storage.queryCacheSize = this.servingQueryCache.size()
    }

    public func invalidateServingCacheOnActiveVersionChange(): Int64 {
        let removed = this.servingQueryCache.invalidateOnActiveVersionChange(this.activeKnowledgeVersion)
        this.storage.queryCacheSize = this.servingQueryCache.size()
        this.storage.queryCacheDiagnostic = "invalidate_removed:${removed}"
        removed
    }

    public func search(query: String, options: SearchOptions): SearchResult {
        let result = SearchResult()
        result.queryId = "query-${query.size}-${options.sourceType}"
        result.knowledgeVersion = this.activeKnowledgeVersion
        if (!this.activeSnapshotReadable) {
            result.degraded = true
            result.fallbackReason = this.restoreDiagnostic
            return result
        }
        let needle = query.toAsciiLower()
        for (record in this.activeIndex) {
            if (!this.recordAllowed(record, options)) {
                continue
            }
            if (this.matches(record, needle)) {
                if (result.records.size < options.budget) {
                    record.score = this.scoreRecord(record, needle)
                    result.records.add(record)
                } else {
                    result.truncated = true
                }
            }
        }
        if (options.includeVector && result.records.size < options.budget) {
            this.appendVectorResults(result, query, options)
        }
        result
    }

    private func appendVectorResults(result: SearchResult, query: String, options: SearchOptions): Unit {
        if (!hasEmbeddingAnchor(query)) {
            return
        }
        let embeddingStatus = this.embeddingProvider.status()
        let vectorStatus = this.vectorStore.status(this.vectorCollection)
        if (embeddingStatus.state != EmbeddingProviderState.READY || vectorStatus.state != EmbeddingProviderState.READY) {
            result.degraded = true
            result.fallbackReason = if (embeddingStatus.state != EmbeddingProviderState.READY) { embeddingStatus.degradedReason } else { vectorStatus.degradedReason }
            return
        }
        let texts = ArrayList<String>()
        texts.add(query)
        let batch = this.embeddingProvider.embed(texts, this.activeEmbeddingModel(), this.activeEmbeddingDimensions())
        if (batch.vectors.size == 0) {
            result.degraded = true
            result.fallbackReason = "query_embedding_unavailable"
            return
        }
        let filters = VectorSearchFilters()
        filters.sourceType = options.sourceType
        filters.trustLevel = options.trustLevel
        filters.reviewState = options.reviewState
        filters.knowledgeVersion = this.activeKnowledgeVersion
        filters.includeCandidates = options.includeCandidates
        let vectorResults = this.vectorStore.search(this.vectorCollection, batch.vectors[0], filters, options.budget)
        for (item in vectorResults) {
            if (result.records.size >= options.budget) {
                result.truncated = true
                break
            }
            if (this.hasResultRecord(result, item.id)) {
                continue
            }
            let record = NormalizedRecord()
            record.sourceId = item.record.id
            record.title = item.record.title
            record.chunk = item.record.chunk
            record.citation = item.record.citation
            record.metadata = item.record.metadata
            record.requiresReview = item.record.metadata.reviewState == ReviewStates.CANDIDATE
            record.score = 0.55 + item.score * 0.35
            result.records.add(record)
            result.vectorUsed = true
        }
    }

    private func hasResultRecord(result: SearchResult, sourceId: String): Bool {
        for (record in result.records) {
            if (record.sourceId == sourceId) {
                return true
            }
        }
        false
    }

    private func recordAllowed(record: NormalizedRecord, options: SearchOptions): Bool {
        if (options.sourceType != "" && record.metadata.sourceType != options.sourceType) {
            return false
        }
        if (options.trustLevel != "" && record.metadata.trustLevel != options.trustLevel) {
            return false
        }
        if (options.reviewState != "" && record.metadata.reviewState != options.reviewState) {
            return false
        }
        if (!options.includeCandidates && record.metadata.reviewState == ReviewStates.CANDIDATE) {
            return false
        }
        true
    }

    private func matches(record: NormalizedRecord, needle: String): Bool {
        let haystack = "${record.title} ${record.chunk} ${record.metadata.repo} ${record.metadata.path} ${record.metadata.symbol} ${record.metadata.sourceUrl}".toAsciiLower()
        haystack.contains(needle) || this.wordOverlap(haystack, needle)
    }

    private func wordOverlap(haystack: String, needle: String): Bool {
        for (word in needle.split(" ")) {
            let trimmed = word.trimAscii()
            if (trimmed.size >= 3 && haystack.contains(trimmed)) {
                return true
            }
        }
        false
    }

    private func scoreRecord(record: NormalizedRecord, needle: String): Float64 {
        let haystack = "${record.title} ${record.chunk} ${record.metadata.symbol}".toAsciiLower()
        if (haystack.contains(needle)) {
            return 1.0
        }
        0.72
    }

    public func status(): KnowledgeStatus {
        let status = KnowledgeStatus()
        status.activeKnowledgeVersion = this.activeKnowledgeVersion
        status.candidateKnowledgeVersion = this.candidateKnowledgeVersion
        status.failedCandidateVersion = this.failedCandidateVersion
        status.activeStateSource = this.activeStateSource
        status.restoreDiagnostic = this.restoreDiagnostic
        status.storage = this.storage
        status.sourceScope = this.sourceScope
        status.indexManifest = this.indexManifest
        for (entry in this.scheduler.entries) {
            if (entry.lastSuccessAt < 0 && this.scheduler.clock.nowMinutes > entry.intervalMinutes) {
                entry.stale = true
            }
            status.schedules.add(entry)
        }
        status
    }

    public func evidencePack(query: String, budget: Int64): EvidencePack {
        let pack = EvidencePack()
        pack.queryId = "evidence-${query.size}"
        pack.knowledgeVersion = this.activeKnowledgeVersion
        let sourceResult = cangjie_source_search(this, query, budget)
        let docResult = cangjie_doc_search(this, query, budget)
        let websiteResult = cangjie_website_search(this, query, budget)
        let communityResult = this.searchByType(query, SourceTypes.COMMUNITY, budget, false)
        let candidateResult = cangjie_web_candidate_search(this, query, budget)
        this.fillSourceEvidence(pack, sourceResult)
        this.fillDocEvidence(pack, docResult)
        this.fillWebsiteEvidence(pack, websiteResult)
        this.fillCommunityEvidence(pack, communityResult)
        this.fillWebCandidateEvidence(pack, candidateResult)
        pack.degraded = sourceResult.degraded || docResult.degraded || websiteResult.degraded || communityResult.degraded || candidateResult.degraded
        this.attachGraphContext(pack, budget)
        if (pack.sourceEvidence.size + pack.docEvidence.size + pack.websiteEvidence.size + pack.communityEvidence.size + pack.webCandidateEvidence.size > budget) {
            pack.truncated = true
        }
        pack
    }

    private func attachGraphContext(pack: EvidencePack, budget: Int64): Unit {
        let graphBudget = if (budget <= 0) { 0 } else { budget * 2 }
        if (graphBudget <= 0) {
            return
        }
        for (citation in pack.citations) {
            if (pack.graphContext.edges.size >= graphBudget) {
                pack.graphContext.truncated = true
                break
            }
            let query = GraphQuery()
            query.sourceId = citation.sourceId
            query.knowledgeVersion = this.activeKnowledgeVersion
            query.budget = graphBudget - pack.graphContext.edges.size
            let context = this.graphStore.neighbors(query)
            this.mergeGraphContext(pack.graphContext, context, graphBudget)
            pack.hasGraphContext = pack.graphContext.nodes.size > 0 || pack.graphContext.edges.size > 0
        }
        pack.graphContext.knowledgeVersion = this.activeKnowledgeVersion
        pack.graphContext.budget = graphBudget
        pack.truncated = pack.truncated || pack.graphContext.truncated
    }

    private func mergeGraphContext(target: GraphContext, source: GraphContext, budget: Int64): Unit {
        for (node in source.nodes) {
            if (target.nodes.size >= budget) {
                target.truncated = true
                break
            }
            if (!graphContextHasNode(target, node.nodeId)) {
                target.nodes.add(node)
            }
        }
        for (edge in source.edges) {
            if (target.edges.size >= budget) {
                target.truncated = true
                break
            }
            if (!graphContextHasEdge(target, edge.edgeId)) {
                target.edges.add(edge)
            }
        }
        target.truncated = target.truncated || source.truncated
    }

    public func graphNeighbors(query: GraphQuery): GraphContext {
        this.graphStore.neighbors(query)
    }

    public func vectorStatus(): VectorStoreStatus {
        this.vectorStore.status(this.vectorCollection)
    }

    public func vectorCollectionStatus(collection: String): VectorStoreStatus {
        this.vectorStore.status(collection)
    }

    public func deleteVectorCollection(collection: String): VectorStoreStatus {
        this.vectorStore.deleteCollection(collection)
    }

    public func verifyAndApplyVectorStoreStatus(collection: String, expectedCount: Int64): VectorStoreStatus {
        let effectiveCollection = if (collection.trimAscii() == "") { this.vectorCollection } else { collection.trimAscii() }
        let status = this.vectorStore.status(effectiveCollection)
        let expectedDimension = this.activeEmbeddingDimensions()
        if (status.collection == "") {
            status.collection = effectiveCollection
        }
        if (status.state == EmbeddingProviderState.READY && expectedCount >= 0 && status.count != expectedCount) {
            status.state = EmbeddingProviderState.DEGRADED
            status.degradedReason = "vector_store_count_mismatch:${status.count}:${expectedCount}:${effectiveCollection}"
        }
        if (status.state == EmbeddingProviderState.READY && expectedDimension > 0 && status.dimension > 0 && status.dimension != expectedDimension) {
            status.state = EmbeddingProviderState.DEGRADED
            status.degradedReason = "vector_store_dimension_mismatch:${status.dimension}:${expectedDimension}:${effectiveCollection}"
        }
        this.applyVectorStatus(status)
        this.rebuildIndexManifest()
        status
    }

    public func vectorBuildProgress(): VectorBuildProgress {
        this.lastVectorBuildProgress
    }

    public func lastVectorIndexBuild(): VectorIndexBuildResult {
        this.lastVectorIndexBuildResult
    }

    private func activeEmbeddingModel(): String {
        let status = this.embeddingProvider.status()
        if (status.model != "") {
            return status.model
        }
        this.embeddingModel
    }

    private func activeEmbeddingDimensions(): Int64 {
        let status = this.embeddingProvider.status()
        if (status.dimensions > 0) {
            return status.dimensions
        }
        this.embeddingDimensions
    }

    public func graphStatus(): VectorStoreStatus {
        this.graphStore.status()
    }

    private func fillSourceEvidence(pack: EvidencePack, result: SearchResult): Unit {
        pack.truncated = pack.truncated || result.truncated
        for (record in result.records) {
            let evidence = SourceEvidence()
            evidence.citation = record.citation
            evidence.repo = record.metadata.repo
            evidence.path = record.metadata.path
            evidence.symbol = record.metadata.symbol
            evidence.score = record.score
            evidence.knowledgeVersion = record.metadata.knowledgeVersion
            evidence.trustLevel = record.metadata.trustLevel
            evidence.reviewState = record.metadata.reviewState
            pack.sourceEvidence.add(evidence)
            pack.citations.add(SourceReference(record.sourceId, record.citation, record.metadata.knowledgeVersion))
        }
    }

    private func fillDocEvidence(pack: EvidencePack, result: SearchResult): Unit {
        pack.truncated = pack.truncated || result.truncated
        for (record in result.records) {
            let evidence = DocEvidence()
            evidence.citation = record.citation
            evidence.title = record.title
            evidence.docVersion = record.metadata.docVersion
            evidence.score = record.score
            evidence.knowledgeVersion = record.metadata.knowledgeVersion
            evidence.trustLevel = record.metadata.trustLevel
            evidence.reviewState = record.metadata.reviewState
            pack.docEvidence.add(evidence)
            pack.citations.add(SourceReference(record.sourceId, record.citation, record.metadata.knowledgeVersion))
        }
    }

    private func fillWebsiteEvidence(pack: EvidencePack, result: SearchResult): Unit {
        pack.truncated = pack.truncated || result.truncated
        for (record in result.records) {
            let evidence = WebsiteEvidence()
            evidence.citation = record.citation
            evidence.url = record.metadata.sourceUrl
            evidence.title = record.title
            evidence.score = record.score
            evidence.knowledgeVersion = record.metadata.knowledgeVersion
            evidence.trustLevel = record.metadata.trustLevel
            evidence.reviewState = record.metadata.reviewState
            pack.websiteEvidence.add(evidence)
            pack.citations.add(SourceReference(record.sourceId, record.citation, record.metadata.knowledgeVersion))
        }
    }

    private func fillCommunityEvidence(pack: EvidencePack, result: SearchResult): Unit {
        pack.truncated = pack.truncated || result.truncated
        for (record in result.records) {
            let evidence = CommunityEvidence()
            evidence.citation = record.citation
            evidence.repo = record.metadata.repo
            evidence.issueOrPr = record.metadata.sourceUrl
            evidence.score = record.score
            evidence.knowledgeVersion = record.metadata.knowledgeVersion
            evidence.trustLevel = record.metadata.trustLevel
            evidence.reviewState = record.metadata.reviewState
            pack.communityEvidence.add(evidence)
            pack.citations.add(SourceReference(record.sourceId, record.citation, record.metadata.knowledgeVersion))
        }
    }

    private func fillWebCandidateEvidence(pack: EvidencePack, result: SearchResult): Unit {
        pack.truncated = pack.truncated || result.truncated
        for (record in result.records) {
            let evidence = WebCandidateEvidence()
            evidence.citation = record.citation
            evidence.url = record.metadata.sourceUrl
            evidence.score = record.score
            evidence.knowledgeVersion = record.metadata.knowledgeVersion
            evidence.trustLevel = record.metadata.trustLevel
            evidence.reviewState = record.metadata.reviewState
            evidence.requiresReview = true
            pack.webCandidateEvidence.add(evidence)
            pack.citations.add(SourceReference(record.sourceId, record.citation, record.metadata.knowledgeVersion))
        }
    }

    public func searchByType(query: String, sourceType: String, budget: Int64, includeCandidates: Bool): SearchResult {
        let options = SearchOptions()
        options.sourceType = sourceType
        options.budget = budget
        options.includeCandidates = includeCandidates
        this.search(query, options)
    }
}

public func newOfflineKnowledgeBase(): KnowledgeBase {
    let kb = KnowledgeBase(FakeClock(0))
    kb.bootstrapOffline()
    kb
}

public class KnowledgeBaseLoadResult {
    public let kb: KnowledgeBase
    public var source: String = "offline_baseline"
    public var diagnostic: String = ""

    public init(kb: KnowledgeBase) {
        this.kb = kb
    }
}

public func newKnowledgeBaseFromStore(store: FileKnowledgeStore): KnowledgeBaseLoadResult {
    let kb = KnowledgeBase(FakeClock(0))
    let result = KnowledgeBaseLoadResult(kb)
    let snapshot = store.loadActiveSnapshot()
    if (kb.restoreActiveSnapshot(snapshot)) {
        kb.restoreScheduler(store.loadScheduler())
        result.source = kb.status().activeStateSource
        result.diagnostic = snapshot.diagnostic
        return result
    }
    if (store.hasAuthoritativeActiveSnapshotPointer()) {
        kb.markPersistedSnapshotInvalid(snapshot.diagnostic)
        kb.restoreScheduler(store.loadScheduler())
        result.source = "persisted_invalid"
        result.diagnostic = snapshot.diagnostic
        return result
    }
    kb.bootstrapOffline(restoreDiagnostic: snapshot.diagnostic)
    kb.restoreScheduler(store.loadScheduler())
    result.source = "offline_baseline"
    result.diagnostic = snapshot.diagnostic
    return result
}

public func cangjie_source_search(kb: KnowledgeBase, query: String, budget: Int64): SearchResult {
    kb.searchByType(query, SourceTypes.REPO, budget, false)
}

public func cangjie_doc_search(kb: KnowledgeBase, query: String, budget: Int64): SearchResult {
    kb.searchByType(query, SourceTypes.DOC, budget, false)
}

public func cangjie_website_search(kb: KnowledgeBase, query: String, budget: Int64): SearchResult {
    kb.searchByType(query, SourceTypes.WEBSITE, budget, false)
}

public func cangjie_web_candidate_search(kb: KnowledgeBase, query: String, budget: Int64): SearchResult {
    kb.searchByType(query, SourceTypes.WEB_CANDIDATE, budget, true)
}

public func cangjie_hybrid_search(kb: KnowledgeBase, query: String, budget: Int64): SearchResult {
    let options = SearchOptions()
    options.budget = budget
    options.includeCandidates = false
    kb.search(query, options)
}

public func cangjie_evidence_pack(kb: KnowledgeBase, query: String, budget: Int64): EvidencePack {
    kb.evidencePack(query, budget)
}

public func cangjie_knowledge_status(kb: KnowledgeBase): KnowledgeStatus {
    kb.status()
}

public func cangjie_knowledge_pack(kb: KnowledgeBase, task: String, budget: Int64): CangjieKnowledgePack {
    CangjieCapabilityService(kb).knowledgePack(task, budget: budget)
}

public func cangjie_api_search(kb: KnowledgeBase, query: String, module!: String = "", symbol!: String = "", sourceSet!: String = "", budget!: Int64 = 5): CangjieKnowledgePack {
    CangjieCapabilityService(kb).apiSearch(query, module: module, symbol: symbol, sourceSet: sourceSet, budget: budget)
}

public func cangjie_syntax_query(kb: KnowledgeBase, query: String, budget!: Int64 = 5): CangjieKnowledgePack {
    CangjieCapabilityService(kb).syntaxQuery(query, budget: budget)
}

public func cangjie_cookbook(kb: KnowledgeBase, task: String, constraints!: String = "", style!: String = "", budget!: Int64 = 5): CangjieKnowledgePack {
    CangjieCapabilityService(kb).cookbook(task, constraints: constraints, style: style, budget: budget)
}

public func cangjie_diagnose(kb: KnowledgeBase, code: String, compilerOutput: String, context!: String = "", budget!: Int64 = 5): CangjieKnowledgePack {
    CangjieCapabilityService(kb).diagnose(code, compilerOutput, context: context, budget: budget)
}

public func cangjie_examples(kb: KnowledgeBase, query: String, module!: String = "", symbol!: String = "", maxExamples!: Int64 = 3): CangjieKnowledgePack {
    CangjieCapabilityService(kb).examples(query, module: module, symbol: symbol, maxExamples: maxExamples)
}

public func cangjie_corpus_status(kb: KnowledgeBase): CangjieCorpusStatus {
    CangjieCapabilityService(kb).corpusStatus()
}

private func deterministicEmbedding(text: String, dimensions: Int64): ArrayList<Float64> {
    let vector = ArrayList<Float64>()
    let dim = if (dimensions <= 0) { 1 } else { dimensions }
    for (_ in 0..dim) {
        vector.add(0.0)
    }
    let lowered = text.toAsciiLower()
    for (word in lowered.split(" ")) {
        let token = word.trimAscii().replace(".", "").replace(",", "").replace(":", "").replace(";", "").replace("(", "").replace(")", "")
        if (token.size < 3) {
            continue
        }
        let bucket = tokenBucket(token, dim)
        vector[bucket] = vector[bucket] + 1.0
        if (token.contains("func") || token.contains("function")) {
            vector[1 % dim] = vector[1 % dim] + 2.0
        }
        if (token.contains("http") || token.contains("client")) {
            vector[2 % dim] = vector[2 % dim] + 2.0
        }
        if (token.contains("download") || token.contains("tool")) {
            vector[3 % dim] = vector[3 % dim] + 2.0
        }
        if (token.contains("json")) {
            vector[4 % dim] = vector[4 % dim] + 2.0
        }
        if (token.contains("repo") || token.contains("source") || token.contains("symbol")) {
            vector[5 % dim] = vector[5 % dim] + 1.5
        }
    }
    normalizeVector(vector)
    vector
}

private func hasEmbeddingAnchor(text: String): Bool {
    let lowered = text.toAsciiLower()
    lowered.contains("func") || lowered.contains("function") || lowered.contains("http") || lowered.contains("client") || lowered.contains("download") || lowered.contains("tool") || lowered.contains("json") || lowered.contains("repo") || lowered.contains("source") || lowered.contains("symbol")
}

private func tokenBucket(token: String, dimensions: Int64): Int64 {
    var score = token.size * 3
    if (token.contains("a")) {
        score += 1
    }
    if (token.contains("e")) {
        score += 2
    }
    if (token.contains("i")) {
        score += 3
    }
    if (token.contains("o")) {
        score += 4
    }
    if (token.contains("u")) {
        score += 5
    }
    score % dimensions
}

private func normalizeVector(vector: ArrayList<Float64>): Unit {
    var sum = 0.0
    for (value in vector) {
        sum += value * value
    }
    if (sum <= 0.0) {
        return
    }
    let norm = sqrtApprox(sum)
    for (i in 0..vector.size) {
        vector[i] = vector[i] / norm
    }
}

private func sqrtApprox(value: Float64): Float64 {
    var guess = if (value > 1.0) { value / 2.0 } else { 1.0 }
    for (_ in 0..8) {
        guess = (guess + value / guess) / 2.0
    }
    guess
}

private func cosineSimilarity(left: ArrayList<Float64>, right: ArrayList<Float64>): Float64 {
    let size = if (left.size < right.size) { left.size } else { right.size }
    var dot = 0.0
    for (i in 0..size) {
        dot += left[i] * right[i]
    }
    dot
}

private func vectorRecordAllowed(record: VectorRecord, filters: VectorSearchFilters): Bool {
    if (filters.repo != "" && record.metadata.repo != filters.repo) {
        return false
    }
    if (filters.sourceType != "" && record.metadata.sourceType != filters.sourceType) {
        return false
    }
    if (filters.trustLevel != "" && record.metadata.trustLevel != filters.trustLevel) {
        return false
    }
    if (filters.reviewState != "" && record.metadata.reviewState != filters.reviewState) {
        return false
    }
    if (filters.knowledgeVersion != "" && record.metadata.knowledgeVersion != filters.knowledgeVersion) {
        return false
    }
    if (!filters.includeCandidates && record.metadata.reviewState == ReviewStates.CANDIDATE) {
        return false
    }
    true
}

private func insertVectorResult(out: ArrayList<VectorSearchResult>, record: VectorRecord, score: Float64, topK: Int64): Unit {
    if (topK <= 0) {
        return
    }
    let item = VectorSearchResult()
    item.id = record.id
    item.score = score
    item.record = record
    if (out.size < topK) {
        out.add(item)
        return
    }
    var minIndex: Int64 = 0
    var minScore = out[0].score
    for (i in 1..out.size) {
        if (out[i].score < minScore) {
            minScore = out[i].score
            minIndex = i
        }
    }
    if (score > minScore) {
        out[minIndex] = item
    }
}

private func buildGraphFromRecords(records: ArrayList<NormalizedRecord>, knowledgeVersion: String, deadlineAtMillis!: Int64 = 0): GraphBuildResult {
    let result = GraphBuildResult()
    let nodeIds = HashSet<String>()
    let edgeIds = HashSet<String>()
    result.total = records.size
    for (record in records) {
        if (result.processed % 64 == 0) {
            let deadline = ckbDeadlineGuard("graph_build_records", deadlineAtMillis)
            if (deadline.exceeded) {
                result.ok = false
                result.diagnostic = "${deadline.diagnostic}:processed=${result.processed}:total=${result.total}"
                return result
            }
        }
        let citationNodeId = addGraphNode(result.nodes, nodeIds, "citation:${record.sourceId}",
            GraphNodeTypes.CITATION, record.citation, record.sourceId, knowledgeVersion)
        if (record.metadata.repo != "") {
            let repoNodeId = addGraphNode(result.nodes, nodeIds, "repo:${record.metadata.repo}",
                GraphNodeTypes.REPO, record.metadata.repo, record.sourceId, knowledgeVersion)
            addGraphEdge(result.edges, edgeIds, GraphEdgeTypes.CITES, repoNodeId, citationNodeId, record.sourceId, knowledgeVersion)
        }
        if (record.metadata.path != "") {
            let pathNodeId = addGraphNode(result.nodes, nodeIds, "path:${record.metadata.repo}:${record.metadata.path}",
                GraphNodeTypes.PATH, record.metadata.path, record.sourceId, knowledgeVersion)
            addGraphEdge(result.edges, edgeIds, GraphEdgeTypes.CONTAINS, "repo:${record.metadata.repo}", pathNodeId, record.sourceId, knowledgeVersion)
            addGraphEdge(result.edges, edgeIds, GraphEdgeTypes.CITES, pathNodeId, citationNodeId, record.sourceId, knowledgeVersion)
        }
        if (record.metadata.symbol != "") {
            let symbolNodeId = addGraphNode(result.nodes, nodeIds, "symbol:${record.metadata.repo}:${record.metadata.symbol}",
                GraphNodeTypes.SYMBOL, record.metadata.symbol, record.sourceId, knowledgeVersion)
            let fromNode = if (record.metadata.path != "") { "path:${record.metadata.repo}:${record.metadata.path}" } else { "repo:${record.metadata.repo}" }
            addGraphEdge(result.edges, edgeIds, GraphEdgeTypes.DEFINES, fromNode, symbolNodeId, record.sourceId, knowledgeVersion)
            addGraphEdge(result.edges, edgeIds, GraphEdgeTypes.CITES, symbolNodeId, citationNodeId, record.sourceId, knowledgeVersion)
        }
        if (record.metadata.sourceType == SourceTypes.DOC || record.metadata.sourceType == SourceTypes.WEBSITE) {
            let docNodeId = addGraphNode(result.nodes, nodeIds, "doc:${record.sourceId}",
                if (record.metadata.sourceType == SourceTypes.DOC) { GraphNodeTypes.DOC } else { GraphNodeTypes.SECTION },
                record.title, record.sourceId, knowledgeVersion)
            addGraphEdge(result.edges, edgeIds, GraphEdgeTypes.CITES, docNodeId, citationNodeId, record.sourceId, knowledgeVersion)
        }
        if (record.metadata.sourceType == SourceTypes.COMMUNITY) {
            let issueNodeId = addGraphNode(result.nodes, nodeIds, "issue:${record.sourceId}",
                GraphNodeTypes.ISSUE, record.title, record.sourceId, knowledgeVersion)
            if (record.metadata.repo != "") {
                addGraphEdge(result.edges, edgeIds, GraphEdgeTypes.DISCUSSES, issueNodeId, "repo:${record.metadata.repo}", record.sourceId, knowledgeVersion)
            }
            addGraphEdge(result.edges, edgeIds, GraphEdgeTypes.CITES, issueNodeId, citationNodeId, record.sourceId, knowledgeVersion)
        }
        result.processed += 1
    }
    result
}

private func ckbGraphBuildEvidenceHash(graph: GraphBuildResult): String {
    let digest = SHA256()
    ckbGraphDigestField(digest, "${graph.processed}"); ckbGraphDigestField(digest, "${graph.total}")
    for (node in graph.nodes) {
        ckbGraphDigestField(digest, node.nodeId); ckbGraphDigestField(digest, node.nodeType)
        ckbGraphDigestField(digest, node.label); ckbGraphDigestField(digest, node.sourceId)
        ckbGraphDigestField(digest, node.knowledgeVersion)
    }
    for (edge in graph.edges) {
        ckbGraphDigestField(digest, edge.edgeId); ckbGraphDigestField(digest, edge.edgeType)
        ckbGraphDigestField(digest, edge.fromNodeId); ckbGraphDigestField(digest, edge.toNodeId)
        ckbGraphDigestField(digest, edge.sourceId); ckbGraphDigestField(digest, edge.knowledgeVersion)
    }
    let out = StringBuilder()
    for (byte in digest.finish()) {
        out.append(ckbGraphHexNibble(byte / UInt8(16))); out.append(ckbGraphHexNibble(byte % UInt8(16)))
    }
    "sha256:${out.toString()}"
}

private func ckbGraphDigestField(digest: SHA256, value: String): Unit { digest.write("${value.size}:".toArray()); digest.write(value.toArray()) }
private func ckbGraphHexNibble(value: UInt8): String {
    if (value < UInt8(10)) { return "${value}" }
    if (value == UInt8(10)) { return "a" }; if (value == UInt8(11)) { return "b" }
    if (value == UInt8(12)) { return "c" }; if (value == UInt8(13)) { return "d" }
    if (value == UInt8(14)) { return "e" }
    "f"
}

private func addGraphNode(nodes: ArrayList<GraphNode>, nodeIds: HashSet<String>, rawNodeId: String,
    nodeType: String, label: String, sourceId: String, knowledgeVersion: String): String {
    let nodeId = safeGraphId(rawNodeId)
    if (nodeIds.contains(nodeId)) { return nodeId }
    nodeIds.add(nodeId)
    let node = GraphNode()
    node.nodeId = nodeId
    node.nodeType = nodeType
    node.label = label
    node.sourceId = sourceId
    node.knowledgeVersion = knowledgeVersion
    nodes.add(node)
    nodeId
}

private func addGraphEdge(edges: ArrayList<GraphEdge>, edgeIds: HashSet<String>, edgeType: String,
    fromNodeId: String, toNodeId: String, sourceId: String, knowledgeVersion: String): Unit {
    let canonicalFrom = safeGraphId(fromNodeId)
    let canonicalTo = safeGraphId(toNodeId)
    let edgeId = "${edgeType}:${canonicalFrom}->${canonicalTo}:${sourceId}"
    if (edgeIds.contains(edgeId)) { return }
    edgeIds.add(edgeId)
    let edge = GraphEdge()
    edge.edgeType = edgeType
    edge.fromNodeId = canonicalFrom
    edge.toNodeId = canonicalTo
    edge.sourceId = sourceId
    edge.knowledgeVersion = knowledgeVersion
    edge.edgeId = edgeId
    edges.add(edge)
}

private func graphContextHasNode(context: GraphContext, nodeId: String): Bool {
    for (node in context.nodes) {
        if (node.nodeId == nodeId) {
            return true
        }
    }
    false
}

private func graphContextHasEdge(context: GraphContext, edgeId: String): Bool {
    for (edge in context.edges) {
        if (edge.edgeId == edgeId) {
            return true
        }
    }
    false
}

private func safeGraphId(raw: String): String {
    raw.replace("/", "_").replace("\\", "_").replace(":", "_").replace(" ", "_").replace("#", "_").replace("?", "_")
}

public func renderDoctor(status: KnowledgeStatus): String {
    var out = "CangjieCommunityKnowledgeBase doctor\n"
    out += "activeKnowledgeVersion=${status.activeKnowledgeVersion}\n"
    out += "activeStateSource=${status.activeStateSource} restoreDiagnostic=${status.restoreDiagnostic}\n"
    out += "storage raw=${status.storage.rawCount} normalized=${status.storage.normalizedCount} indexes=${status.storage.indexCount} derived=${status.storage.derivedCount}\n"
    out += "indexKinds text=${status.storage.textIndexCount} vector=${status.storage.vectorIndexCount} symbol=${status.storage.symbolIndexCount} graph=${status.storage.graphIndexCount} serving=${status.storage.servingIndexCount}\n"
    out += "servingIndex version=${status.storage.servingIndexVersion} diagnostic=${status.storage.servingIndexDiagnostic} cacheSize=${status.storage.queryCacheSize} cacheDiagnostic=${status.storage.queryCacheDiagnostic}\n"
    out += "vector backend=${status.storage.vectorBackend} state=${status.storage.vectorState} collection=${status.storage.vectorCollection} activeCollection=${status.storage.vectorActiveCollection} candidateCollection=${status.storage.vectorCandidateCollection} dimension=${status.storage.vectorDimension} count=${status.storage.vectorIndexCount} degradedReason=${status.storage.vectorDegradedReason}\n"
    out += "graph backend=${status.storage.graphBackend} state=${status.storage.graphState} nodes=${status.storage.graphNodeCount} edges=${status.storage.graphEdgeCount}\n"
    out += "paths raw=${status.storage.rawPath} normalized=${status.storage.normalizedPath} metadata=${status.storage.metadataPath} indexes=${status.storage.indexesPath} derived=${status.storage.derivedPath} cache=${status.storage.cachePath}\n"
    out += "scope organizations=${status.sourceScope.organizations} repoScope=${status.sourceScope.repoScope} websiteUrls=${status.sourceScope.websiteUrls} docsUrls=${status.sourceScope.docsUrls} stdSources=${status.sourceScope.stdSources} issuePrHistory=${status.sourceScope.includesIssuePrHistory} governedWebCandidates=${status.sourceScope.includesGovernedWebCandidates}\n"
    out += "localPathRedacted=${status.localPathRedacted}\n"
    for (entry in status.schedules) {
        let staleFailure = entry.failureCount > 0 && (entry.lastRunId == "" || entry.lastTerminalState == "" || entry.lastTerminalState == "succeeded")
        out += "schedule ${entry.name} nextRunAt=${entry.nextRunAt} lastStartedAt=${entry.lastStartedAt} lastSuccessAt=${entry.lastSuccessAt} lastFailureAt=${entry.lastFailureAt} failureCount=${entry.failureCount} stale=${entry.stale} degraded=${entry.degraded} staleFailure=${staleFailure} runId=${entry.lastRunId} runStartedAtMillis=${entry.lastRunStartedAtMillis} runFinishedAtMillis=${entry.lastRunFinishedAtMillis} terminalState=${entry.lastTerminalState} cursor=${entry.lastCursor} since=${entry.lastSince} active=${entry.activeVersion} candidate=${entry.candidateVersion} status=${entry.lastStatus}\n"
    }
    out
}

public func renderMetrics(status: KnowledgeStatus): String {
    var degradedSchedules: Int64 = 0
    var staleSchedules: Int64 = 0
    for (entry in status.schedules) {
        if (entry.degraded) {
            degradedSchedules += 1
        }
        if (entry.stale) {
            staleSchedules += 1
        }
    }
    var out = "metrics activeKnowledgeVersion=${status.activeKnowledgeVersion} activeStateSource=${status.activeStateSource} restoreDiagnostic=${status.restoreDiagnostic}\n"
    out += "metrics storage raw=${status.storage.rawCount} normalized=${status.storage.normalizedCount} activeIndex=${status.storage.indexCount} vector=${status.storage.vectorIndexCount} graphEdges=${status.storage.graphEdgeCount} serving=${status.storage.servingIndexCount}\n"
    out += "metrics backend vectorState=${status.storage.vectorState} graphState=${status.storage.graphState}\n"
    out += "metrics scheduler total=${status.schedules.size} degraded=${degradedSchedules} stale=${staleSchedules}\n"
    out
}

public func renderBackupRestore(result: BackupRestoreResult): String {
    "backupRestore action=${result.action} ok=${result.ok} source=${result.source} destination=${result.destination} activeKnowledgeVersion=${result.activeVersion} files=${result.files} diagnostic=${result.diagnostic}\n"
}

public func renderQuery(pack: EvidencePack): String {
    var out = "queryId=${pack.queryId} knowledgeVersion=${pack.knowledgeVersion} truncated=${pack.truncated} degraded=${pack.degraded}\n"
    out += "sourceEvidence=${pack.sourceEvidence.size} docEvidence=${pack.docEvidence.size} websiteEvidence=${pack.websiteEvidence.size} communityEvidence=${pack.communityEvidence.size} webCandidateEvidence=${pack.webCandidateEvidence.size}\n"
    out += "graphContext nodes=${pack.graphContext.nodes.size} edges=${pack.graphContext.edges.size} knowledgeVersion=${pack.graphContext.knowledgeVersion} truncated=${pack.graphContext.truncated}\n"
    for (citation in pack.citations) {
        out += "citation ${citation.sourceId} ${citation.citation} ${citation.knowledgeVersion}\n"
    }
    out
}

private func contentHash(sourceId: String, content: String): String {
    var hash: Int64 = 5381
    let modulus: Int64 = 1000000007
    for (b in "${sourceId}:${content}".toArray()) {
        hash = ((hash * 33) % modulus + (Int64(b) % modulus)) % modulus
    }
    "hash-${hash}-${content.size}"
}

func ckbVectorPointId(source: NormalizedRecord): String {
    ckbStableVectorPointId(source.sourceId, source.title, source.chunk, source.citation,
        source.metadata.repo, source.metadata.path, source.metadata.symbol)
}

private func ckbVectorRecordStablePointId(record: VectorRecord): String {
    ckbStableVectorPointId(record.metadata.sourceId, record.title, record.chunk, record.citation,
        record.metadata.repo, record.metadata.path, record.metadata.symbol)
}

private func ckbStableVectorPointId(sourceId: String, title: String, chunk: String, citation: String, repo: String, path: String, symbol: String): String {
    let digest = SHA256()
    ckbVectorIdentityDigestField(digest, sourceId)
    ckbVectorIdentityDigestField(digest, title)
    ckbVectorIdentityDigestField(digest, chunk)
    ckbVectorIdentityDigestField(digest, citation)
    ckbVectorIdentityDigestField(digest, repo)
    ckbVectorIdentityDigestField(digest, path)
    ckbVectorIdentityDigestField(digest, symbol)
    let out = StringBuilder()
    for (byte in digest.finish()) {
        out.append(ckbVectorIdentityHexNibble(byte / UInt8(16)))
        out.append(ckbVectorIdentityHexNibble(byte % UInt8(16)))
    }
    "${sourceId}#sha256:${out.toString()}"
}

private func ckbVectorIdentityDigestField(digest: SHA256, value: String): Unit {
    digest.write("${value.size}:".toArray())
    digest.write(value.toArray())
}

private func ckbVectorIdentityHexNibble(value: UInt8): String {
    if (value < UInt8(10)) { return "${value}" }
    if (value == UInt8(10)) { return "a" }; if (value == UInt8(11)) { return "b" }
    if (value == UInt8(12)) { return "c" }; if (value == UInt8(13)) { return "d" }
    if (value == UInt8(14)) { return "e" }
    "f"
}

func ckbLegacyVectorPointId(source: NormalizedRecord, activeIndexOrdinal: Int64): String {
    let summary = contentHash(source.sourceId, "${source.title}\n${source.chunk}\n${source.citation}")
    "${source.sourceId}#${activeIndexOrdinal}#${summary}"
}

private func ckbVectorRecordMatchesSource(record: VectorRecord, source: NormalizedRecord): Bool {
    let actual = record.metadata
    let expected = source.metadata
    if (vectorPointIdentity(record) != ckbVectorPointId(source) || record.id != source.sourceId ||
        record.title != source.title || record.chunk != source.chunk || record.citation != source.citation ||
        actual.sourceId != expected.sourceId || actual.sourceType != expected.sourceType ||
        actual.sourceUrl != expected.sourceUrl || actual.repo != expected.repo || actual.path != expected.path ||
        actual.symbol != expected.symbol || actual.commit != expected.commit || actual.docVersion != expected.docVersion ||
        actual.targetVersion != expected.targetVersion || actual.sourceSet != expected.sourceSet ||
        actual.versionResolutionId != expected.versionResolutionId || actual.crawlAt != expected.crawlAt ||
        actual.indexedAt != expected.indexedAt || actual.knowledgeVersion != expected.knowledgeVersion ||
        actual.candidateVersion != expected.candidateVersion || actual.contentSize != expected.contentSize ||
        actual.trustLevel != expected.trustLevel || actual.reviewState != expected.reviewState ||
        actual.license != expected.license || actual.repoVisibility != expected.repoVisibility ||
        actual.derivedFrom.size != expected.derivedFrom.size) { return false }
    for (index in 0..actual.derivedFrom.size) {
        if (actual.derivedFrom[index] != expected.derivedFrom[index]) { return false }
    }
    record.vector.size > 0
}

func ckbVectorSourceBufferedBytes(record: NormalizedRecord, dimensions: Int64, ordinal!: Int64 = 0): Int64 {
    let vectorTextBytes = if (dimensions > 0) { dimensions * 32 } else { 0 }
    let embeddingTextBytes = record.title.size + record.chunk.size + record.metadata.repo.size + record.metadata.path.size + record.metadata.symbol.size + 4
    let metadata = record.metadata
    var spoolBytes = ckbVectorEscapedFieldBytes(ckbVectorPointId(record)) + ckbVectorEscapedFieldBytes(record.sourceId) +
        ckbVectorEscapedFieldBytes(record.title) + ckbVectorEscapedFieldBytes(record.chunk) +
        ckbVectorEscapedFieldBytes(metadata.knowledgeVersion) + ckbVectorEscapedFieldBytes(metadata.sourceId) +
        ckbVectorEscapedFieldBytes(metadata.sourceType) + ckbVectorEscapedFieldBytes(metadata.trustLevel) +
        ckbVectorEscapedFieldBytes(metadata.reviewState) + ckbVectorEscapedFieldBytes(record.citation) + vectorTextBytes +
        "p5-vector-v2".size + ckbVectorEscapedFieldBytes(metadata.sourceUrl) + ckbVectorEscapedFieldBytes(metadata.repo) +
        ckbVectorEscapedFieldBytes(metadata.path) + ckbVectorEscapedFieldBytes(metadata.symbol) +
        ckbVectorEscapedFieldBytes(metadata.commit) + ckbVectorEscapedFieldBytes(metadata.docVersion) +
        ckbVectorEscapedFieldBytes(metadata.targetVersion) + ckbVectorEscapedFieldBytes(metadata.sourceSet) +
        ckbVectorEscapedFieldBytes(metadata.versionResolutionId) + ckbVectorEscapedFieldBytes(metadata.crawlAt) +
        ckbVectorEscapedFieldBytes(metadata.indexedAt) + ckbVectorEscapedFieldBytes(metadata.candidateVersion) +
        "${metadata.contentSize}".size + ckbVectorEscapedFieldBytes(metadata.license) +
        ckbVectorEscapedFieldBytes(metadata.repoVisibility) + ckbVectorDerivedCodecBytes(metadata.derivedFrom) + 28
    // The legacy alias is held alongside the serialized current point ID during lookup.
    spoolBytes + ckbVectorEscapedFieldBytes(ckbLegacyVectorPointId(record, ordinal)) + embeddingTextBytes +
        record.recordKind.size + "${record.score}".size + "${record.requiresReview}".size + 64
}

private func ckbVectorEscapedFieldBytes(value: String): Int64 {
    var size: Int64 = 0
    for (byte in value.toArray()) {
        size += if (byte == UInt8(92) || byte == UInt8(124) || byte == UInt8(10) || byte == UInt8(13)) { 2 } else { 1 }
    }
    size
}

private func ckbVectorDerivedCodecBytes(values: Array<String>): Int64 {
    var size: Int64 = "${values.size}".size + 1
    var index: Int64 = 0
    for (value in values) {
        if (index > 0) { size += 1 }
        size += if (value.size == 0) { 1 } else { value.size * 2 }
        index += 1
    }
    size
}

private func ckbVectorReuseIdentity(sourceId: String, title: String, chunk: String, citation: String): String {
    contentHash(sourceId, "${title}\n${chunk}\n${citation}")
}

private func ckbReusableVectorUpsertBatchSize(): Int64 {
    1024
}

private func ckbVectorBatchCount(size: Int64, batchSize: Int64): Int64 {
    if (size <= 0) {
        return 0
    }
    let effective = if (batchSize > 0) { batchSize } else { 1 }
    (size + effective - 1) / effective
}
