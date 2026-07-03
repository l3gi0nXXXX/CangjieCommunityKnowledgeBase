package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.convert.Parsable

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

    public init() {}
}

public interface EmbeddingProvider {
    func embed(texts: ArrayList<String>, model: String, dimensions: Int64): EmbeddingBatch
    func status(): EmbeddingStatus
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

    public func status(): EmbeddingStatus {
        let status = EmbeddingStatus()
        status.provider = this.config.provider
        status.model = this.config.model
        status.dimensions = this.config.dimensions
        status.endpointConfigured = this.config.endpoint != ""
        status.tokenConfigured = this.config.credentialPresent()
        status.batchSize = this.config.batchSize
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

    public func status(): EmbeddingStatus {
        let status = EmbeddingStatus()
        status.provider = this.config.provider
        status.model = this.config.model
        status.dimensions = this.config.dimensions
        status.endpointConfigured = this.config.endpoint != ""
        status.tokenConfigured = this.config.credentialPresent()
        status.batchSize = this.config.batchSize
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
    public var vector: ArrayList<Float64> = ArrayList<Float64>()
    public var metadata: KnowledgeMetadata = KnowledgeMetadata()
    public var title: String = ""
    public var chunk: String = ""
    public var citation: String = ""

    public init() {}
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
    public var count: Int64 = 0
    public var state: String = EmbeddingProviderState.DEGRADED
    public var degradedReason: String = ""

    public init() {}
}

public interface VectorStore {
    func upsert(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus
    func search(collection: String, queryVector: ArrayList<Float64>, filters: VectorSearchFilters, topK: Int64): ArrayList<VectorSearchResult>
    func status(collection: String): VectorStoreStatus
    func clear(collection: String): VectorStoreStatus
    func recreate(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus
    func backup(collection: String): VectorBackup
    func restore(backup: VectorBackup): VectorStoreStatus
}

public class VectorBackup {
    public var collection: String = ""
    public var records: ArrayList<VectorRecord> = ArrayList<VectorRecord>()
    public var valid: Bool = false
    public var diagnostic: String = ""

    public init() {}
}

class LocalVectorCollection {
    public var name: String = ""
    public var records: ArrayList<VectorRecord> = ArrayList<VectorRecord>()
    public var dimension: Int64 = 0

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
        stored.dimension = 0
        for (record in vectors) {
            if (stored.dimension == 0) {
                stored.dimension = record.vector.size
            }
            stored.records.add(record)
        }
        this.status(collection)
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

    public func clear(collection: String): VectorStoreStatus {
        if (!this.available) {
            return this.status(collection)
        }
        let stored = this.findCollection(collection)
        if (stored.name != "") {
            stored.records.clear()
            stored.dimension = 0
        }
        this.status(collection)
    }

    public func recreate(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.clear(collection)
        this.upsert(collection, vectors)
    }

    public func backup(collection: String): VectorBackup {
        let backup = VectorBackup()
        backup.collection = collection
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

    public init() {}
}

private class QdrantJsonStringScan {
    public var ok: Bool = false
    public var value: String = ""
    public var end: Int64 = 0

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
        if (parsed.size == 0 && !qdrantBodyLooksOk(response.body)) {
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

    public func clear(collection: String): VectorStoreStatus {
        let response = this.execute("DELETE", this.collectionUrl(collection), "")
        let status = this.statusFromClearResponse(collection, response)
        if (status.state == EmbeddingProviderState.READY) {
            this.remember(collection, ArrayList<VectorRecord>())
        }
        this.lastStatus = status
        status
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

    public func backup(collection: String): VectorBackup {
        let backup = VectorBackup()
        backup.collection = collection
        let cached = this.cached(collection)
        if (cached.collection == "") {
            backup.valid = false
            backup.diagnostic = "qdrant_backup_requires_scroll"
            return backup
        }
        for (record in cached.records) {
            backup.records.add(record)
        }
        backup.valid = true
        backup.diagnostic = "ok"
        backup
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
        for (record in vectors) {
            entry.records.add(record)
        }
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
        out += "{\"id\":${qdrantStablePointId(record.id)},\"vector\":${qdrantVectorJson(record.vector)},\"payload\":${qdrantPayloadJson(record)}}"
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
    status.count = qdrantJsonIntField(result, "points_count", qdrantJsonIntField(result, "pointsCount", 0))
    status.dimension = qdrantJsonIntField(result, "size", 0)
    if (qdrantState == "green" || qdrantState == "ok" || qdrantState == "") {
        status.state = EmbeddingProviderState.READY
    } else {
        status.state = EmbeddingProviderState.DEGRADED
        status.degradedReason = "qdrant_status_${qdrantState}"
    }
    status
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
            scan.ok = true
            scan.value = qdrantJsonUnescapeString(raw[start + 1..i])
            scan.end = i + 1
            return scan
        }
        i += 1
    }
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
    raw.replace("\\\"", "\"").replace("\\n", "\n").replace("\\r", "\r").replace("\\t", "\t").replace("\\\\", "\\")
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
    public var nodes: ArrayList<GraphNode> = ArrayList<GraphNode>()
    public var edges: ArrayList<GraphEdge> = ArrayList<GraphEdge>()

    public init() {}
}

public interface GraphStore {
    func upsert(nodes: ArrayList<GraphNode>, edges: ArrayList<GraphEdge>): Unit
    func neighbors(query: GraphQuery): GraphContext
    func status(): VectorStoreStatus
}

public class LocalGraphStore <: GraphStore {
    private var nodes: ArrayList<GraphNode> = ArrayList<GraphNode>()
    private var edges: ArrayList<GraphEdge> = ArrayList<GraphEdge>()
    private var activeVersion: String = ""

    public init() {}

    public func upsert(nodes: ArrayList<GraphNode>, edges: ArrayList<GraphEdge>): Unit {
        this.nodes.clear()
        this.edges.clear()
        this.activeVersion = ""
        for (node in nodes) {
            if (this.activeVersion == "" && node.knowledgeVersion != "") {
                this.activeVersion = node.knowledgeVersion
            }
            this.nodes.add(node)
        }
        for (edge in edges) {
            this.edges.add(edge)
        }
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
    public var indexManifest: IndexManifest = IndexManifest()
    public var localPathRedacted: Bool = true

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
    public var cursor: String = ""
    public var since: String = ""
    public var activeVersion: String = ""
    public var candidateVersion: String = ""
    public var durationMillis: Int64 = 0
    public var requestCount: Int64 = 0
    public var updatedDataKinds: ArrayList<String> = ArrayList<String>()
    public var truncated: Bool = false
    public var timeBudgetMillis: Int64 = 0

    public init() {}
}

public class SchedulerExecutorResult {
    public var ran: Int64 = 0
    public var succeeded: Int64 = 0
    public var failed: Int64 = 0
    public var degraded: Int64 = 0
    public var details: String = ""
    public var forced: Bool = false
    public var taskNames: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public interface SchedulerTaskRunner {
    func runTask(name: String, since: String): SchedulerTaskResult
}

public class SchedulerExecutor {
    private let scheduler: Scheduler
    private let runner: SchedulerTaskRunner

    public init(scheduler: Scheduler, runner: SchedulerTaskRunner) {
        this.scheduler = scheduler
        this.runner = runner
    }

    public func runDue(limit!: Int64 = 1): SchedulerExecutorResult {
        let result = SchedulerExecutorResult()
        let due = this.scheduler.dueTaskNames()
        for (name in due) {
            if (limit > 0 && result.ran >= limit) {
                break
            }
            let entry = this.findEntry(name)
            let task = this.runner.runTask(name, entry.lastSince)
            result.ran += 1
            result.taskNames.add(name)
            if (task.ok) {
                this.scheduler.markSuccess(name)
                this.applyCheckpoint(name, task)
                result.succeeded += 1
            } else {
                this.scheduler.markFailure(name)
                this.applyCheckpoint(name, task)
                result.failed += 1
            }
            let after = this.findEntry(name)
            if (after.degraded) {
                result.degraded += 1
            }
            result.details += "task ${name} ok=${task.ok} status=${task.status} nextRunAt=${after.nextRunAt} failureCount=${after.failureCount} degraded=${after.degraded}\n"
        }
        result
    }

    public func runTaskNames(taskNames: ArrayList<String>, force!: Bool = false): SchedulerExecutorResult {
        let result = SchedulerExecutorResult()
        result.forced = force
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
            let task = this.runner.runTask(name, entry.lastSince)
            result.ran += 1
            result.taskNames.add(name)
            if (task.ok) {
                this.scheduler.markSuccess(name)
                this.applyCheckpoint(name, task)
                result.succeeded += 1
            } else {
                this.scheduler.markFailure(name)
                this.applyCheckpoint(name, task)
                result.failed += 1
            }
            let after = this.findEntry(name)
            if (after.degraded) {
                result.degraded += 1
            }
            result.details += "task ${name} ok=${task.ok} status=${task.status} nextRunAt=${after.nextRunAt} failureCount=${after.failureCount} degraded=${after.degraded}\n"
        }
        result
    }

    private func findEntry(name: String): ScheduleEntry {
        for (entry in this.scheduler.entries) {
            if (entry.name == name) {
                return entry
            }
        }
        ScheduleEntry(name, 0, 0)
    }

    private func applyCheckpoint(name: String, task: SchedulerTaskResult): Unit {
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
            }
        }
    }
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

    public func bootstrapOffline(): Unit {
        this.rawRecords.clear()
        this.normalizedRecords.clear()
        this.activeStateSource = "offline_baseline"
        this.restoreDiagnostic = ""
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
        this.addRecord("web-candidate-blog", SourceTypes.WEB_CANDIDATE, "External Cangjie tutorial candidate", "https://example.invalid/cangjie-tutorial", "", "", "", "", TrustLevels.WEB_CANDIDATE, ReviewStates.CANDIDATE, "A third party tutorial discusses Cangjie stdx examples and requires manual review.")
        this.normalize()
        this.publishIndex(false)
    }

    public func restoreActiveSnapshot(snapshot: ActiveSnapshot): Bool {
        if (!snapshot.valid) {
            this.restoreDiagnostic = snapshot.diagnostic
            return false
        }
        this.rawRecords.clear()
        this.normalizedRecords.clear()
        this.activeIndex.clear()
        this.candidateIndex.clear()
        for (record in snapshot.rawRecords) {
            this.rawRecords.add(record)
        }
        for (record in snapshot.normalizedRecords) {
            this.normalizedRecords.add(record)
        }
        if (this.normalizedRecords.size == 0) {
            for (record in snapshot.activeIndex) {
                this.normalizedRecords.add(record)
            }
        }
        for (record in snapshot.activeIndex) {
            record.metadata.knowledgeVersion = snapshot.activeVersion
            this.activeIndex.add(record)
        }
        this.activeKnowledgeVersion = snapshot.activeVersion
        this.candidateKnowledgeVersion = snapshot.candidateVersion
        this.failedCandidateVersion = snapshot.failedVersion
        this.activeStateSource = "persisted"
        this.restoreDiagnostic = snapshot.diagnostic
        this.storage.rawCount = this.rawRecords.size
        this.storage.normalizedCount = this.normalizedRecords.size
        this.storage.indexCount = this.activeIndex.size
        if (snapshot.vectorRecords.size > 0) {
            let backup = VectorBackup()
            backup.collection = this.vectorCollection
            backup.valid = true
            backup.diagnostic = "ok"
            for (record in snapshot.vectorRecords) {
                backup.records.add(record)
            }
            this.applyVectorStatus(this.vectorStore.restore(backup))
            this.rebuildGraphIndex()
        } else {
            this.rebuildProductionIndexes()
        }
        this.rebuildIndexManifest()
        return true
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
                }
            }
        }
    }

    private func addRecord(sourceId: String, sourceType: String, title: String, sourceUrl: String, repo: String, path: String, symbol: String, docVersion: String, trustLevel: String, reviewState: String, content: String): Unit {
        if (this.hasRawRecord(sourceId)) {
            return
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
        this.addRecord(sourceId, sourceType, title, fetch.sourceUrl, repo, path, symbol, "1.0.0", trustLevel, reviewState, fetch.body)
        let inserted = this.rawRecords[this.rawRecords.size - 1]
        inserted.metadata.repoVisibility = fetch.repoVisibility
        inserted.metadata.commit = if (fetch.commit != "") { fetch.commit } else { inserted.metadata.commit }
        inserted.metadata.docVersion = if (fetch.ref != "") { fetch.ref } else { inserted.metadata.docVersion }
        inserted.metadata.targetVersion = cangjieDefaultTargetVersion()
        inserted.metadata.sourceSet = cangjieSourceSetForIngest(sourceType, repo, path, fetch.sourceUrl)
        inserted.metadata.versionResolutionId = cangjieIngestVersionResolutionId(inserted.metadata)
        true
    }

    private func hasRawRecord(sourceId: String): Bool {
        for (record in this.rawRecords) {
            if (record.sourceId == sourceId) {
                return true
            }
        }
        false
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

    public func publishIndex(simulateFailure: Bool): Bool {
        this.candidateKnowledgeVersion = "ckb-20260519-000100-candidate"
        this.candidateIndex.clear()
        for (record in this.normalizedRecords) {
            record.metadata.candidateVersion = this.candidateKnowledgeVersion
            this.candidateIndex.add(record)
        }
        if (simulateFailure) {
            this.failedCandidateVersion = this.candidateKnowledgeVersion
            return false
        }
        this.activeIndex.clear()
        for (record in this.candidateIndex) {
            this.activeIndex.add(record)
        }
        this.activeKnowledgeVersion = "ckb-20260519-000100-active"
        for (record in this.activeIndex) {
            record.metadata.knowledgeVersion = this.activeKnowledgeVersion
            record.metadata.candidateVersion = this.candidateKnowledgeVersion
        }
        this.failedCandidateVersion = ""
        this.storage.indexCount = this.activeIndex.size
        this.rebuildProductionIndexes()
        this.rebuildIndexManifest()
        true
    }

    public func rebuildIndex(simulateFailure: Bool): IndexBuildResult {
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
        for (record in this.candidateIndex) {
            record.metadata.knowledgeVersion = result.activeVersion
            record.metadata.candidateVersion = result.candidateVersion
            this.activeIndex.add(record)
        }
        this.activeKnowledgeVersion = result.activeVersion
        this.failedCandidateVersion = ""
        this.storage.indexCount = this.activeIndex.size
        this.rebuildProductionIndexes()
        this.rebuildIndexManifest()
        result
    }

    private func rebuildProductionIndexes(): Unit {
        let vectorRecords = ArrayList<VectorRecord>()
        let texts = ArrayList<String>()
        for (record in this.activeIndex) {
            texts.add("${record.title} ${record.chunk} ${record.metadata.repo} ${record.metadata.path} ${record.metadata.symbol}")
        }
        let batch = this.embeddingProvider.embed(texts, this.activeEmbeddingModel(), this.activeEmbeddingDimensions())
        if (batch.status.state == EmbeddingProviderState.READY && batch.vectors.size == this.activeIndex.size) {
            for (i in 0..this.activeIndex.size) {
                let source = this.activeIndex[i]
                let vectorRecord = VectorRecord()
                vectorRecord.id = source.sourceId
                vectorRecord.vector = batch.vectors[i]
                vectorRecord.metadata = source.metadata
                vectorRecord.title = source.title
                vectorRecord.chunk = source.chunk
                vectorRecord.citation = source.citation
                vectorRecords.add(vectorRecord)
            }
            let vectorStatus = this.vectorStore.upsert(this.vectorCollection, vectorRecords)
            this.applyVectorStatus(vectorStatus)
        } else {
            let vectorStatus = this.vectorStore.status(this.vectorCollection)
            vectorStatus.state = EmbeddingProviderState.DEGRADED
            vectorStatus.degradedReason = batch.status.degradedReason
            this.applyVectorStatus(vectorStatus)
        }
        this.rebuildGraphIndex()
    }

    private func rebuildGraphIndex(): Unit {
        let graph = buildGraphFromRecords(this.activeIndex, this.activeKnowledgeVersion)
        this.graphStore.upsert(graph.nodes, graph.edges)
        let graphStatus = this.graphStore.status()
        this.storage.graphBackend = graphStatus.backend
        this.storage.graphState = graphStatus.state
        this.storage.graphNodeCount = graphStatus.dimension
        this.storage.graphEdgeCount = graphStatus.count
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

    public func persistActiveSnapshot(store: FileKnowledgeStore): Unit {
        store.ensureLayout()
        store.saveRaw(this.rawRecords)
        store.saveNormalized(this.activeIndex)
        store.saveActiveIndex(this.activeIndex, this.activeKnowledgeVersion)
        store.saveVectorCollection(this.activeVectorRecords(), this.vectorCollection)
        store.saveGraph(this.activeGraphBuild())
        store.saveMetadata(this.status())
    }

    public func persistCandidateSnapshot(store: FileKnowledgeStore): Unit {
        store.ensureLayout()
        store.saveCandidateRaw(this.rawRecords, this.candidateKnowledgeVersion)
        store.saveCandidateNormalized(this.candidateIndex, this.candidateKnowledgeVersion)
        store.saveMetadata(this.status())
    }

    public func activeVectorRecords(): ArrayList<VectorRecord> {
        let out = ArrayList<VectorRecord>()
        let texts = ArrayList<String>()
        for (record in this.activeIndex) {
            texts.add("${record.title} ${record.chunk} ${record.metadata.repo} ${record.metadata.path} ${record.metadata.symbol}")
        }
        let batch = this.embeddingProvider.embed(texts, this.activeEmbeddingModel(), this.activeEmbeddingDimensions())
        if (batch.vectors.size != this.activeIndex.size) {
            return out
        }
        for (i in 0..this.activeIndex.size) {
            let source = this.activeIndex[i]
            let vectorRecord = VectorRecord()
            vectorRecord.id = source.sourceId
            vectorRecord.vector = batch.vectors[i]
            vectorRecord.metadata = source.metadata
            vectorRecord.title = source.title
            vectorRecord.chunk = source.chunk
            vectorRecord.citation = source.citation
            out.add(vectorRecord)
        }
        out
    }

    public func activeGraphBuild(): GraphBuildResult {
        buildGraphFromRecords(this.activeIndex, this.activeKnowledgeVersion)
    }

    public func rawRecordCount(): Int64 {
        this.rawRecords.size
    }

    public func normalizedRecordCount(): Int64 {
        this.normalizedRecords.size
    }

    public func search(query: String, options: SearchOptions): SearchResult {
        let result = SearchResult()
        result.queryId = "query-${query.size}-${options.sourceType}"
        result.knowledgeVersion = this.activeKnowledgeVersion
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
    let kb = newOfflineKnowledgeBase()
    let result = KnowledgeBaseLoadResult(kb)
    let snapshot = store.loadActiveSnapshot()
    if (kb.restoreActiveSnapshot(snapshot)) {
        kb.restoreScheduler(store.loadScheduler())
        result.source = "persisted"
        result.diagnostic = snapshot.diagnostic
        return result
    }
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

private func buildGraphFromRecords(records: ArrayList<NormalizedRecord>, knowledgeVersion: String): GraphBuildResult {
    let result = GraphBuildResult()
    for (record in records) {
        let citationNode = graphNode("citation:${record.sourceId}", GraphNodeTypes.CITATION, record.citation, record.sourceId, knowledgeVersion)
        addGraphNode(result.nodes, citationNode)
        if (record.metadata.repo != "") {
            let repoNode = graphNode("repo:${record.metadata.repo}", GraphNodeTypes.REPO, record.metadata.repo, record.sourceId, knowledgeVersion)
            addGraphNode(result.nodes, repoNode)
            addGraphEdge(result.edges, GraphEdgeTypes.CITES, repoNode.nodeId, citationNode.nodeId, record.sourceId, knowledgeVersion)
        }
        if (record.metadata.path != "") {
            let pathNode = graphNode("path:${record.metadata.repo}:${record.metadata.path}", GraphNodeTypes.PATH, record.metadata.path, record.sourceId, knowledgeVersion)
            addGraphNode(result.nodes, pathNode)
            addGraphEdge(result.edges, GraphEdgeTypes.CONTAINS, "repo:${record.metadata.repo}", pathNode.nodeId, record.sourceId, knowledgeVersion)
            addGraphEdge(result.edges, GraphEdgeTypes.CITES, pathNode.nodeId, citationNode.nodeId, record.sourceId, knowledgeVersion)
        }
        if (record.metadata.symbol != "") {
            let symbolNode = graphNode("symbol:${record.metadata.repo}:${record.metadata.symbol}", GraphNodeTypes.SYMBOL, record.metadata.symbol, record.sourceId, knowledgeVersion)
            addGraphNode(result.nodes, symbolNode)
            let fromNode = if (record.metadata.path != "") { "path:${record.metadata.repo}:${record.metadata.path}" } else { "repo:${record.metadata.repo}" }
            addGraphEdge(result.edges, GraphEdgeTypes.DEFINES, fromNode, symbolNode.nodeId, record.sourceId, knowledgeVersion)
            addGraphEdge(result.edges, GraphEdgeTypes.CITES, symbolNode.nodeId, citationNode.nodeId, record.sourceId, knowledgeVersion)
        }
        if (record.metadata.sourceType == SourceTypes.DOC || record.metadata.sourceType == SourceTypes.WEBSITE) {
            let docNode = graphNode("doc:${record.sourceId}", if (record.metadata.sourceType == SourceTypes.DOC) { GraphNodeTypes.DOC } else { GraphNodeTypes.SECTION }, record.title, record.sourceId, knowledgeVersion)
            addGraphNode(result.nodes, docNode)
            addGraphEdge(result.edges, GraphEdgeTypes.CITES, docNode.nodeId, citationNode.nodeId, record.sourceId, knowledgeVersion)
        }
        if (record.metadata.sourceType == SourceTypes.COMMUNITY) {
            let issueNode = graphNode("issue:${record.sourceId}", GraphNodeTypes.ISSUE, record.title, record.sourceId, knowledgeVersion)
            addGraphNode(result.nodes, issueNode)
            if (record.metadata.repo != "") {
                addGraphEdge(result.edges, GraphEdgeTypes.DISCUSSES, issueNode.nodeId, "repo:${record.metadata.repo}", record.sourceId, knowledgeVersion)
            }
            addGraphEdge(result.edges, GraphEdgeTypes.CITES, issueNode.nodeId, citationNode.nodeId, record.sourceId, knowledgeVersion)
        }
    }
    result
}

private func graphNode(nodeId: String, nodeType: String, label: String, sourceId: String, knowledgeVersion: String): GraphNode {
    let node = GraphNode()
    node.nodeId = safeGraphId(nodeId)
    node.nodeType = nodeType
    node.label = label
    node.sourceId = sourceId
    node.knowledgeVersion = knowledgeVersion
    node
}

private func addGraphNode(nodes: ArrayList<GraphNode>, node: GraphNode): Unit {
    for (existing in nodes) {
        if (existing.nodeId == node.nodeId) {
            return
        }
    }
    nodes.add(node)
}

private func addGraphEdge(edges: ArrayList<GraphEdge>, edgeType: String, fromNodeId: String, toNodeId: String, sourceId: String, knowledgeVersion: String): Unit {
    let edge = GraphEdge()
    edge.edgeType = edgeType
    edge.fromNodeId = safeGraphId(fromNodeId)
    edge.toNodeId = safeGraphId(toNodeId)
    edge.sourceId = sourceId
    edge.knowledgeVersion = knowledgeVersion
    edge.edgeId = "${edge.edgeType}:${edge.fromNodeId}->${edge.toNodeId}:${sourceId}"
    for (existing in edges) {
        if (existing.edgeId == edge.edgeId) {
            return
        }
    }
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
    out += "indexKinds text=${status.storage.textIndexCount} vector=${status.storage.vectorIndexCount} symbol=${status.storage.symbolIndexCount} graph=${status.storage.graphIndexCount}\n"
    out += "vector backend=${status.storage.vectorBackend} state=${status.storage.vectorState} collection=${status.storage.vectorCollection} activeCollection=${status.storage.vectorActiveCollection} candidateCollection=${status.storage.vectorCandidateCollection} dimension=${status.storage.vectorDimension} count=${status.storage.vectorIndexCount} degradedReason=${status.storage.vectorDegradedReason}\n"
    out += "graph backend=${status.storage.graphBackend} state=${status.storage.graphState} nodes=${status.storage.graphNodeCount} edges=${status.storage.graphEdgeCount}\n"
    out += "paths raw=${status.storage.rawPath} normalized=${status.storage.normalizedPath} metadata=${status.storage.metadataPath} indexes=${status.storage.indexesPath} derived=${status.storage.derivedPath} cache=${status.storage.cachePath}\n"
    out += "scope organizations=${status.sourceScope.organizations} repoScope=${status.sourceScope.repoScope} websiteUrls=${status.sourceScope.websiteUrls} docsUrls=${status.sourceScope.docsUrls} stdSources=${status.sourceScope.stdSources} issuePrHistory=${status.sourceScope.includesIssuePrHistory} governedWebCandidates=${status.sourceScope.includesGovernedWebCandidates}\n"
    out += "localPathRedacted=${status.localPathRedacted}\n"
    for (entry in status.schedules) {
        out += "schedule ${entry.name} nextRunAt=${entry.nextRunAt} lastStartedAt=${entry.lastStartedAt} lastSuccessAt=${entry.lastSuccessAt} lastFailureAt=${entry.lastFailureAt} failureCount=${entry.failureCount} stale=${entry.stale} degraded=${entry.degraded} cursor=${entry.lastCursor} since=${entry.lastSince} active=${entry.activeVersion} candidate=${entry.candidateVersion} status=${entry.lastStatus}\n"
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
    out += "metrics storage raw=${status.storage.rawCount} normalized=${status.storage.normalizedCount} activeIndex=${status.storage.indexCount} vector=${status.storage.vectorIndexCount} graphEdges=${status.storage.graphEdgeCount}\n"
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
