package cangjie_community_knowledge_base

import std.collection.ArrayList

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
        this.entries.add(ScheduleEntry("website_probe_6h", 360, 0))
        this.entries.add(ScheduleEntry("website_full_daily", 1440, 200))
        this.entries.add(ScheduleEntry("docs_probe_6h", 360, 40))
        this.entries.add(ScheduleEntry("repo_list_6h", 360, 0))
        this.entries.add(ScheduleEntry("active_repo_fetch_30m", 30, 0))
        this.entries.add(ScheduleEntry("active_item_sync_10m", 10, 0))
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

    public init() {}
}

public class SchedulerExecutorResult {
    public var ran: Int64 = 0
    public var succeeded: Int64 = 0
    public var failed: Int64 = 0
    public var degraded: Int64 = 0
    public var details: String = ""

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
        this.rawRecords[this.rawRecords.size - 1].metadata.repoVisibility = fetch.repoVisibility
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
        }
        this.storage.rawCount = this.rawRecords.size
        this.storage.normalizedCount = this.normalizedRecords.size
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
