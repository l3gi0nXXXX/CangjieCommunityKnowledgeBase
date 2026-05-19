package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.convert.Parsable
import std.fs.{Directory, File, Path, exists}

public class SourceKinds {
    public static let GITCODE_ORG: String = "gitcode_org"
    public static let GITCODE_REPO: String = "gitcode_repo"
    public static let GITCODE_SOURCE: String = "gitcode_source"
    public static let GITCODE_ISSUE_HISTORY: String = "gitcode_issue_history"
    public static let GITCODE_PR_HISTORY: String = "gitcode_pr_history"
    public static let CANGJIE_WEBSITE: String = "cangjie_website"
    public static let CANGJIE_DOCS: String = "cangjie_docs"
    public static let WEB_CANDIDATE: String = "web_candidate"
}

public class SourceFetchRequest {
    public var kind: String = ""
    public var url: String = ""
    public var repo: String = ""
    public var ref: String = ""
    public var path: String = ""

    public init() {}

    public init(kind: String, url: String, repo!: String = "", ref!: String = "", path!: String = "") {
        this.kind = kind
        this.url = url
        this.repo = repo
        this.ref = ref
        this.path = path
    }
}

public class SourceFetchResult {
    public var ok: Bool = false
    public var status: String = "not_started"
    public var body: String = ""
    public var commit: String = ""
    public var sourceUrl: String = ""

    public init() {}
}

public interface SourceFetchRunner {
    func fetch(request: SourceFetchRequest): SourceFetchResult
}

public class DisabledNetworkFetchRunner <: SourceFetchRunner {
    public init() {}

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        let result = SourceFetchResult()
        result.ok = false
        result.status = "network_disabled"
        result.sourceUrl = request.url
        result
    }
}

public class FakeSourceFetchRunner <: SourceFetchRunner {
    public var calls: ArrayList<SourceFetchRequest> = ArrayList<SourceFetchRequest>()

    public init() {}

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        this.calls.add(request)
        let result = SourceFetchResult()
        result.ok = true
        result.status = "ok"
        result.commit = "fake-commit"
        result.sourceUrl = request.url
        result.body = "fake ${request.kind} ${request.repo} ${request.path} func HttpClient Cangjie docs tutorial"
        result
    }
}

public class SourceAdapter {
    private let runner: SourceFetchRunner

    public init(runner!: SourceFetchRunner = DisabledNetworkFetchRunner()) {
        this.runner = runner
    }

    public func fetchGitCodeOrg(org: String): SourceFetchResult {
        this.runner.fetch(SourceFetchRequest(SourceKinds.GITCODE_ORG, "https://gitcode.com/${org}", repo: org))
    }

    public func fetchGitCodeRepo(repo: String, ref!: String = "main"): SourceFetchResult {
        this.runner.fetch(SourceFetchRequest(SourceKinds.GITCODE_REPO, "https://gitcode.com/${repo}", repo: repo, ref: ref))
    }

    public func fetchGitCodeSource(repo: String, ref: String, path: String): SourceFetchResult {
        this.runner.fetch(SourceFetchRequest(SourceKinds.GITCODE_SOURCE, "https://gitcode.com/${repo}/blob/${ref}/${path}", repo: repo, ref: ref, path: path))
    }

    public func fetchGitCodeIssueHistory(repo: String): SourceFetchResult {
        this.runner.fetch(SourceFetchRequest(SourceKinds.GITCODE_ISSUE_HISTORY, "https://gitcode.com/${repo}/issues", repo: repo))
    }

    public func fetchGitCodePrHistory(repo: String): SourceFetchResult {
        this.runner.fetch(SourceFetchRequest(SourceKinds.GITCODE_PR_HISTORY, "https://gitcode.com/${repo}/pulls", repo: repo))
    }

    public func fetchCangjieWebsite(url: String): SourceFetchResult {
        this.runner.fetch(SourceFetchRequest(SourceKinds.CANGJIE_WEBSITE, url))
    }

    public func fetchCangjieDocs(url: String): SourceFetchResult {
        this.runner.fetch(SourceFetchRequest(SourceKinds.CANGJIE_DOCS, url))
    }

    public func fetchWebCandidate(url: String): SourceFetchResult {
        this.runner.fetch(SourceFetchRequest(SourceKinds.WEB_CANDIDATE, url))
    }
}

public class FileKnowledgeStore {
    public let root: Path

    public init(root: String) {
        this.root = Path(root)
    }

    public func ensureLayout(): Unit {
        this.ensure("raw")
        this.ensure("normalized")
        this.ensure("metadata")
        this.ensure("index")
        this.ensure("derived")
        this.ensure("cache")
    }

    public func saveRaw(records: ArrayList<RawRecord>): Unit {
        this.writeLines("raw/records.ckb", this.rawLines(records))
    }

    public func saveNormalized(records: ArrayList<NormalizedRecord>): Unit {
        this.writeLines("normalized/records.ckb", this.normalizedLines(records))
    }

    public func saveMetadata(status: KnowledgeStatus): Unit {
        var text = "active=${status.activeKnowledgeVersion}\n"
        text += "candidate=${status.candidateKnowledgeVersion}\n"
        text += "failed=${status.failedCandidateVersion}\n"
        text += "rawCount=${status.storage.rawCount}\n"
        text += "normalizedCount=${status.storage.normalizedCount}\n"
        text += "indexCount=${status.storage.indexCount}\n"
        this.writeLines("metadata/status.ckb", text)
    }

    public func saveActiveIndex(records: ArrayList<NormalizedRecord>, version: String): Unit {
        this.writeLines("index/active.version", version + "\n")
        this.writeLines("index/active.ckb", this.normalizedLines(records))
    }

    public func saveCandidateIndex(records: ArrayList<NormalizedRecord>, version: String): Unit {
        this.writeLines("index/candidate.version", version + "\n")
        this.writeLines("index/candidate.ckb", this.normalizedLines(records))
    }

    public func saveDerived(task: CurationTask): Unit {
        this.writeLines("derived/${safeName(task.taskId)}.ckb", "${task.taskId}|${task.kind}|${task.repo}|${task.status}|${escapeField(task.derivedKnowledge)}\n")
    }

    public func saveCache(key: String, value: String): Unit {
        this.writeLines("cache/${safeName(key)}.txt", value)
    }

    public func loadRaw(): ArrayList<RawRecord> {
        let out = ArrayList<RawRecord>()
        let text = this.readLines("raw/records.ckb")
        if (text == "") {
            return out
        }
        for (line in text.split("\n")) {
            let parts = line.split("|")
            if (parts.size >= 17) {
                let metadata = metadataFromParts(parts, 4)
                let record = RawRecord()
                record.sourceId = unescapeField(parts[0])
                record.title = unescapeField(parts[1])
                record.content = unescapeField(parts[2])
                record.contentHash = unescapeField(parts[3])
                record.metadata = metadata
                record.requiresReview = metadata.reviewState == ReviewStates.CANDIDATE
                out.add(record)
            }
        }
        out
    }

    public func loadNormalized(): ArrayList<NormalizedRecord> {
        let out = ArrayList<NormalizedRecord>()
        let text = this.readLines("normalized/records.ckb")
        if (text == "") {
            return out
        }
        for (line in text.split("\n")) {
            let parts = line.split("|")
            if (parts.size >= 17) {
                let metadata = metadataFromParts(parts, 5)
                let record = NormalizedRecord()
                record.sourceId = unescapeField(parts[0])
                record.title = unescapeField(parts[1])
                record.chunk = unescapeField(parts[2])
                record.citation = unescapeField(parts[3])
                record.score = try { Float64.parse(parts[4]) } catch (_: Exception) { 0.0 }
                record.metadata = metadata
                record.requiresReview = metadata.reviewState == ReviewStates.CANDIDATE
                out.add(record)
            }
        }
        out
    }

    public func publicStatus(): StorageStatus {
        let status = StorageStatus()
        status.rawPath = "data/raw"
        status.normalizedPath = "data/normalized"
        status.metadataPath = "data/metadata"
        status.indexesPath = "data/indexes"
        status.derivedPath = "data/derived"
        status.cachePath = "data/cache"
        status
    }

    public func has(relative: String): Bool {
        exists(this.root.join(relative))
    }

    private func ensure(relative: String): Unit {
        let path = this.root.join(relative)
        if (!exists(path)) {
            Directory.create(path, recursive: true)
        }
    }

    private func writeLines(relative: String, text: String): Unit {
        this.ensureLayout()
        File.writeTo(this.root.join(relative), text.toArray())
    }

    private func readLines(relative: String): String {
        let path = this.root.join(relative)
        if (!exists(path)) {
            return ""
        }
        String.fromUtf8(File.readFrom(path))
    }

    private func rawLines(records: ArrayList<RawRecord>): String {
        var out = ""
        for (record in records) {
            out += "${escapeField(record.sourceId)}|${escapeField(record.title)}|${escapeField(record.content)}|${escapeField(record.contentHash)}|${metadataLine(record.metadata)}\n"
        }
        out
    }

    private func normalizedLines(records: ArrayList<NormalizedRecord>): String {
        var out = ""
        for (record in records) {
            out += "${escapeField(record.sourceId)}|${escapeField(record.title)}|${escapeField(record.chunk)}|${escapeField(record.citation)}|${record.score}|${metadataLine(record.metadata)}\n"
        }
        out
    }
}

public class Normalizer {
    public init() {}

    public func normalize(record: RawRecord, indexedAt: String, knowledgeVersion: String): NormalizedRecord {
        let normalized = NormalizedRecord()
        normalized.sourceId = record.sourceId
        normalized.title = record.title
        normalized.chunk = record.content.trimAscii()
        record.metadata.indexedAt = indexedAt
        record.metadata.knowledgeVersion = knowledgeVersion
        normalized.metadata = record.metadata
        normalized.requiresReview = record.requiresReview || record.metadata.reviewState == ReviewStates.CANDIDATE
        normalized.citation = publicRecordCitation(record)
        normalized
    }
}

public class IndexBuildResult {
    public var ok: Bool = false
    public var activeVersion: String = ""
    public var candidateVersion: String = ""
    public var failedVersion: String = ""
    public var count: Int64 = 0

    public init() {}
}

public class IndexBuilder {
    public init() {}

    public func rebuild(records: ArrayList<NormalizedRecord>, activeVersion: String, candidateVersion: String, fail!: Bool = false): IndexBuildResult {
        let result = IndexBuildResult()
        result.activeVersion = activeVersion
        result.candidateVersion = candidateVersion
        if (records.size == 0 || fail) {
            result.ok = false
            result.failedVersion = candidateVersion
            return result
        }
        result.ok = true
        result.activeVersion = candidateVersion.replace("-candidate", "-active")
        result.count = records.size
        result
    }
}

public class QueryService {
    private let kb: KnowledgeBase

    public init(kb: KnowledgeBase) {
        this.kb = kb
    }

    public func query(mode: String, text: String, budget: Int64, trustLevel!: String = "", reviewState!: String = "", includeCandidates!: Bool = false): SearchResult {
        let options = SearchOptions()
        options.budget = budget
        options.trustLevel = trustLevel
        options.reviewState = reviewState
        options.includeCandidates = includeCandidates
        match (mode) {
            case "source" => options.sourceType = SourceTypes.REPO
            case "doc" => options.sourceType = SourceTypes.DOC
            case "website" => options.sourceType = SourceTypes.WEBSITE
            case "web_candidate" =>
                options.sourceType = SourceTypes.WEB_CANDIDATE
                options.includeCandidates = true
            case _ => ()
        }
        this.kb.search(text, options)
    }

    public func evidence(text: String, budget: Int64, includeCandidates!: Bool = true): EvidencePack {
        if (includeCandidates) {
            return this.kb.evidencePack(text, budget)
        }
        let pack = this.kb.evidencePack(text, budget)
        pack.webCandidateEvidence.clear()
        pack
    }

    public func status(): KnowledgeStatus {
        this.kb.status()
    }
}

public class CkbSchema {
    public static func mcpTools(): String {
        "tools: cangjie.source_search,cangjie.doc_search,cangjie.website_search,cangjie.web_candidate_search,cangjie.hybrid_search,cangjie.evidence_pack,cangjie.status"
    }

    public static func httpLikeRoutes(): String {
        "routes: GET /status, POST /query, POST /evidence, POST /sync-once, POST /rebuild-index"
    }
}

public func ckbSyncOnce(kb: KnowledgeBase, adapter: SourceAdapter, store: FileKnowledgeStore): String {
    let org = adapter.fetchGitCodeOrg("cangjie")
    let repo = adapter.fetchGitCodeRepo("cangjie/stdx")
    let source = adapter.fetchGitCodeSource("cangjie/stdx", "main", "src/http/client.cj")
    let issue = adapter.fetchGitCodeIssueHistory("cangjie/cangjie")
    let pr = adapter.fetchGitCodePrHistory("cangjie/cangjie")
    let docs = adapter.fetchCangjieDocs("https://docs.cangjie-lang.cn/docs/1.0.0/")
    let web = adapter.fetchCangjieWebsite("https://cangjie-lang.cn/docs")
    let candidate = adapter.fetchWebCandidate("https://example.invalid/cangjie-tutorial")
    kb.ingestFetchResult("sync-org", SourceTypes.COMMUNITY, org, "GitCode cangjie org", TrustLevels.COMMUNITY, ReviewStates.REVIEWED)
    kb.ingestFetchResult("sync-repo", SourceTypes.REPO, repo, "GitCode stdx repo", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    kb.ingestFetchResult("sync-source", SourceTypes.REPO, source, "GitCode stdx source", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    kb.ingestFetchResult("sync-issue", SourceTypes.COMMUNITY, issue, "GitCode issue history", TrustLevels.COMMUNITY, ReviewStates.REVIEWED)
    kb.ingestFetchResult("sync-pr", SourceTypes.COMMUNITY, pr, "GitCode PR history", TrustLevels.COMMUNITY, ReviewStates.REVIEWED)
    kb.ingestFetchResult("sync-docs", SourceTypes.DOC, docs, "Cangjie docs", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    kb.ingestFetchResult("sync-website", SourceTypes.WEBSITE, web, "Cangjie website", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    kb.ingestFetchResult("sync-web-candidate", SourceTypes.WEB_CANDIDATE, candidate, "Web candidate", TrustLevels.WEB_CANDIDATE, ReviewStates.CANDIDATE)
    kb.normalize()
    kb.persist(store)
    "sync status org=${org.status} repo=${repo.status} docs=${docs.status} webCandidate=${candidate.status}"
}

public func ckbRebuildIndex(kb: KnowledgeBase, store: FileKnowledgeStore, fail!: Bool = false): IndexBuildResult {
    let result = kb.rebuildIndex(fail)
    if (result.ok) {
        kb.persistIndex(store)
    }
    result
}

private func metadataLine(metadata: KnowledgeMetadata): String {
    "${escapeField(metadata.sourceType)}|${escapeField(metadata.sourceUrl)}|${escapeField(metadata.repo)}|${escapeField(metadata.commit)}|${escapeField(metadata.path)}|${escapeField(metadata.symbol)}|${escapeField(metadata.docVersion)}|${escapeField(metadata.crawlAt)}|${escapeField(metadata.indexedAt)}|${escapeField(metadata.knowledgeVersion)}|${escapeField(metadata.trustLevel)}|${escapeField(metadata.reviewState)}|${escapeField(metadata.license)}"
}

private func metadataFromParts(parts: Array<String>, start: Int64): KnowledgeMetadata {
    let metadata = KnowledgeMetadata()
    metadata.sourceType = unescapeField(parts[start])
    metadata.sourceUrl = unescapeField(parts[start + 1])
    metadata.repo = unescapeField(parts[start + 2])
    metadata.commit = unescapeField(parts[start + 3])
    metadata.path = unescapeField(parts[start + 4])
    metadata.symbol = unescapeField(parts[start + 5])
    metadata.docVersion = unescapeField(parts[start + 6])
    metadata.crawlAt = unescapeField(parts[start + 7])
    metadata.indexedAt = unescapeField(parts[start + 8])
    metadata.knowledgeVersion = unescapeField(parts[start + 9])
    metadata.trustLevel = unescapeField(parts[start + 10])
    metadata.reviewState = unescapeField(parts[start + 11])
    metadata.license = unescapeField(parts[start + 12])
    metadata
}

private func publicRecordCitation(record: RawRecord): String {
    if (record.metadata.sourceType == SourceTypes.REPO) {
        return "${record.metadata.repo}:${record.metadata.path}#${record.metadata.symbol}"
    }
    if (record.metadata.sourceType == SourceTypes.COMMUNITY) {
        return "${record.metadata.repo}:${record.metadata.sourceUrl}"
    }
    record.metadata.sourceUrl
}

private func safeName(raw: String): String {
    raw.replace("/", "_").replace("\\", "_").replace(":", "_").replace("..", "_")
}

private func escapeField(raw: String): String {
    raw.replace("\\", "\\\\").replace("|", "\\p").replace("\n", "\\n").replace("\r", "\\r")
}

private func unescapeField(raw: String): String {
    raw.replace("\\r", "\r").replace("\\n", "\n").replace("\\p", "|").replace("\\\\", "\\")
}
