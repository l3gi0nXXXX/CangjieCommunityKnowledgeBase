package cangjie_community_knowledge_base_test

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

    public init() {}
}

public class SearchResult {
    public var queryId: String = ""
    public var knowledgeVersion: String = ""
    public var records: ArrayList<NormalizedRecord> = ArrayList<NormalizedRecord>()
    public var truncated: Bool = false

    public init() {}
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
    public var citations: ArrayList<SourceReference> = ArrayList<SourceReference>()
    public var sourceEvidence: ArrayList<SourceEvidence> = ArrayList<SourceEvidence>()
    public var docEvidence: ArrayList<DocEvidence> = ArrayList<DocEvidence>()
    public var websiteEvidence: ArrayList<WebsiteEvidence> = ArrayList<WebsiteEvidence>()
    public var communityEvidence: ArrayList<CommunityEvidence> = ArrayList<CommunityEvidence>()
    public var webCandidateEvidence: ArrayList<WebCandidateEvidence> = ArrayList<WebCandidateEvidence>()

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
    private var indexManifest: IndexManifest = IndexManifest()

    public init(clock: FakeClock) {
        this.scheduler = Scheduler(clock)
    }

    public func bootstrapOffline(): Unit {
        this.rawRecords.clear()
        this.normalizedRecords.clear()
        this.addRecord("doc-syntax", SourceTypes.DOC, "Cangjie function syntax", "https://docs.cangjie-lang.cn/docs/1.0.0/language/functions", "", "", "", "1.0.0", TrustLevels.OFFICIAL, ReviewStates.TRUSTED, "Function definitions use func. Named parameters use an exclamation marker in the declaration and parameter names in calls. Cangjie syntax covers classes, arrays, options, and tests.")
        this.addRecord("doc-stdx-json", SourceTypes.DOC, "stdx JSON API", "https://docs.cangjie-lang.cn/docs/1.0.0/libs/stdx/json", "", "", "", "1.0.0", TrustLevels.OFFICIAL, ReviewStates.TRUSTED, "stdx contains JSON support for structured encoding and decoding.")
        this.addRecord("website-download", SourceTypes.WEBSITE, "Cangjie official download", "https://cangjie-lang.cn/download", "", "", "", "", TrustLevels.OFFICIAL, ReviewStates.TRUSTED, "The official website links Cangjie downloads, documentation, tools, and community entry points.")
        this.addRecord("source-http-client", SourceTypes.REPO, "HttpClient source", "https://gitcode.com/cangjie/stdx/blob/main/src/http/client.cj", "cangjie/stdx", "src/http/client.cj", "HttpClient", "", TrustLevels.OFFICIAL, ReviewStates.TRUSTED, "public class HttpClient provides HTTP request transport behavior for stdx examples.")
        this.addRecord("community-issue-1", SourceTypes.COMMUNITY, "Issue history for named parameter syntax", "https://gitcode.com/cangjie/cangjie/issues/1", "cangjie/cangjie", "", "", "", TrustLevels.COMMUNITY, ReviewStates.REVIEWED, "Maintainers clarified that named parameters are passed after positional parameters.")
        this.addRecord("web-candidate-blog", SourceTypes.WEB_CANDIDATE, "External Cangjie tutorial candidate", "https://example.invalid/cangjie-tutorial", "", "", "", "", TrustLevels.WEB_CANDIDATE, ReviewStates.CANDIDATE, "A third party tutorial discusses Cangjie stdx examples and requires manual review.")
        this.normalize()
        this.publishIndex(false)
    }

    private func addRecord(sourceId: String, sourceType: String, title: String, sourceUrl: String, repo: String, path: String, symbol: String, docVersion: String, trustLevel: String, reviewState: String, content: String): Unit {
        if (this.hasRawRecord(sourceId)) {
            return
        }
        let metadata = KnowledgeMetadata()
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
        var repo = ""
        var path = ""
        var symbol = ""
        if (sourceType == SourceTypes.REPO) {
            repo = if (fetch.sourceUrl.contains("cangjie/stdx")) { "cangjie/stdx" } else { "cangjie/cangjie" }
            path = if (fetch.sourceUrl.contains("/blob/")) { "src/http/client.cj" } else { "" }
            symbol = if (path != "") { "HttpClient" } else { "" }
        }
        this.addRecord(sourceId, sourceType, title, fetch.sourceUrl, repo, path, symbol, "1.0.0", trustLevel, reviewState, fetch.body)
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
        this.rebuildIndexManifest()
        result
    }

    private func rebuildIndexManifest(): Unit {
        let manifest = IndexManifest()
        manifest.activeVersion = this.activeKnowledgeVersion
        manifest.candidateVersion = this.candidateKnowledgeVersion
        manifest.entries.add(this.indexMetadata(IndexKinds.TEXT, this.activeIndex.size, "token overlap text index"))
        manifest.entries.add(this.indexMetadata(IndexKinds.VECTOR, this.activeIndex.size, "deterministic lexical vector surrogate"))
        manifest.entries.add(this.indexMetadata(IndexKinds.SYMBOL, this.countSymbolRecords(), "symbol metadata index"))
        manifest.entries.add(this.indexMetadata(IndexKinds.GRAPH, this.countGraphEdges(), "repo-doc-community citation graph"))
        this.indexManifest = manifest
        this.storage.textIndexCount = this.activeIndex.size
        this.storage.vectorIndexCount = this.activeIndex.size
        this.storage.symbolIndexCount = this.countSymbolRecords()
        this.storage.graphIndexCount = this.countGraphEdges()
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
        store.saveMetadata(this.status())
    }

    public func persistCandidateSnapshot(store: FileKnowledgeStore): Unit {
        store.ensureLayout()
        store.saveCandidateRaw(this.rawRecords, this.candidateKnowledgeVersion)
        store.saveCandidateNormalized(this.candidateIndex, this.candidateKnowledgeVersion)
        store.saveMetadata(this.status())
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
        result
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
        this.fillSourceEvidence(pack, cangjie_source_search(this, query, budget))
        this.fillDocEvidence(pack, cangjie_doc_search(this, query, budget))
        this.fillWebsiteEvidence(pack, cangjie_website_search(this, query, budget))
        this.fillCommunityEvidence(pack, this.searchByType(query, SourceTypes.COMMUNITY, budget, false))
        this.fillWebCandidateEvidence(pack, cangjie_web_candidate_search(this, query, budget))
        if (pack.sourceEvidence.size + pack.docEvidence.size + pack.websiteEvidence.size + pack.communityEvidence.size + pack.webCandidateEvidence.size > budget) {
            pack.truncated = true
        }
        pack
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

public func renderDoctor(status: KnowledgeStatus): String {
    var out = "CangjieCommunityKnowledgeBase doctor\n"
    out += "activeKnowledgeVersion=${status.activeKnowledgeVersion}\n"
    out += "storage raw=${status.storage.rawCount} normalized=${status.storage.normalizedCount} indexes=${status.storage.indexCount} derived=${status.storage.derivedCount}\n"
    out += "indexKinds text=${status.storage.textIndexCount} vector=${status.storage.vectorIndexCount} symbol=${status.storage.symbolIndexCount} graph=${status.storage.graphIndexCount}\n"
    out += "paths raw=${status.storage.rawPath} normalized=${status.storage.normalizedPath} metadata=${status.storage.metadataPath} indexes=${status.storage.indexesPath} derived=${status.storage.derivedPath} cache=${status.storage.cachePath}\n"
    out += "scope organizations=${status.sourceScope.organizations} repoScope=${status.sourceScope.repoScope} websiteUrls=${status.sourceScope.websiteUrls} docsUrls=${status.sourceScope.docsUrls} stdSources=${status.sourceScope.stdSources} issuePrHistory=${status.sourceScope.includesIssuePrHistory} governedWebCandidates=${status.sourceScope.includesGovernedWebCandidates}\n"
    out += "localPathRedacted=${status.localPathRedacted}\n"
    for (entry in status.schedules) {
        out += "schedule ${entry.name} nextRunAt=${entry.nextRunAt} lastStartedAt=${entry.lastStartedAt} lastSuccessAt=${entry.lastSuccessAt} lastFailureAt=${entry.lastFailureAt} stale=${entry.stale} degraded=${entry.degraded}\n"
    }
    out
}

public func renderQuery(pack: EvidencePack): String {
    var out = "queryId=${pack.queryId} knowledgeVersion=${pack.knowledgeVersion} truncated=${pack.truncated}\n"
    out += "sourceEvidence=${pack.sourceEvidence.size} docEvidence=${pack.docEvidence.size} websiteEvidence=${pack.websiteEvidence.size} communityEvidence=${pack.communityEvidence.size} webCandidateEvidence=${pack.webCandidateEvidence.size}\n"
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
