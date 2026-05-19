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
    public var method: String = "GET"
    public var url: String = ""
    public var repo: String = ""
    public var ref: String = ""
    public var path: String = ""
    public var accept: String = "application/json"
    public var authHint: String = "none"
    public var page: Int64 = 1
    public var perPage: Int64 = 100
    public var purpose: String = ""

    public init() {}

    public init(kind: String, url: String, repo!: String = "", ref!: String = "", path!: String = "", accept!: String = "application/json", purpose!: String = "") {
        this.kind = kind
        this.url = url
        this.repo = repo
        this.ref = ref
        this.path = path
        this.accept = accept
        this.purpose = purpose
    }
}

public class SourceFetchResult {
    public var ok: Bool = false
    public var status: String = "not_started"
    public var statusCode: Int64 = 0
    public var body: String = ""
    public var commit: String = ""
    public var sourceUrl: String = ""
    public var normalizedType: String = ""
    public var etag: String = ""
    public var lastModified: String = ""
    public var truncated: Bool = false

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
        result.statusCode = 200
        result.commit = "fake-commit"
        result.sourceUrl = request.url
        result.normalizedType = request.kind
        result.etag = "fake-etag"
        result.lastModified = "2026-05-19T00:00:00Z"
        result.body = "fake ${request.kind} ${request.repo} ${request.path} func HttpClient Cangjie docs tutorial"
        result
    }
}

public class SourceRequestBuilder {
    private let gitCodeApiRoot: String = "https://gitcode.com/api/v5"

    public init() {}

    public func gitCodeOrgRepos(org: String): SourceFetchRequest {
        let request = SourceFetchRequest(SourceKinds.GITCODE_ORG, "${this.gitCodeApiRoot}/orgs/${org}/projects?visibility=public&page=1&per_page=100", repo: org, purpose: "enumerate_public_repos")
        request.authHint = "gitcode-token-optional-redacted"
        request
    }

    public func gitCodeRepo(repo: String, ref!: String = "main"): SourceFetchRequest {
        let request = SourceFetchRequest(SourceKinds.GITCODE_REPO, "${this.gitCodeApiRoot}/projects/${repo}?ref=${ref}", repo: repo, ref: ref, purpose: "repo_metadata")
        request.authHint = "gitcode-token-optional-redacted"
        request
    }

    public func gitCodeSource(repo: String, ref: String, path: String): SourceFetchRequest {
        let request = SourceFetchRequest(SourceKinds.GITCODE_SOURCE, "${this.gitCodeApiRoot}/projects/${repo}/repository/files/${path}/raw?ref=${ref}", repo: repo, ref: ref, path: path, accept: "text/plain", purpose: "source_snapshot")
        request.authHint = "gitcode-token-optional-redacted"
        request
    }

    public func gitCodeIssueHistory(repo: String): SourceFetchRequest {
        let request = SourceFetchRequest(SourceKinds.GITCODE_ISSUE_HISTORY, "${this.gitCodeApiRoot}/projects/${repo}/issues?state=all&page=1&per_page=100", repo: repo, purpose: "issue_history")
        request.authHint = "gitcode-token-optional-redacted"
        request
    }

    public func gitCodePrHistory(repo: String): SourceFetchRequest {
        let request = SourceFetchRequest(SourceKinds.GITCODE_PR_HISTORY, "${this.gitCodeApiRoot}/projects/${repo}/merge_requests?state=all&page=1&per_page=100", repo: repo, purpose: "pr_history")
        request.authHint = "gitcode-token-optional-redacted"
        request
    }

    public func website(url: String): SourceFetchRequest {
        SourceFetchRequest(SourceKinds.CANGJIE_WEBSITE, url, accept: "text/html", purpose: "website_probe")
    }

    public func docs(url: String): SourceFetchRequest {
        SourceFetchRequest(SourceKinds.CANGJIE_DOCS, url, accept: "text/html", purpose: "docs_probe")
    }

    public func webCandidate(url: String): SourceFetchRequest {
        SourceFetchRequest(SourceKinds.WEB_CANDIDATE, url, accept: "text/html", purpose: "candidate_recrawl")
    }
}

public class SourceResponseNormalizer {
    public init() {}

    public func normalize(request: SourceFetchRequest, result: SourceFetchResult): SourceFetchResult {
        result.sourceUrl = if (result.sourceUrl == "") { request.url } else { result.sourceUrl }
        result.normalizedType = request.kind
        if (result.statusCode == 0 && result.ok) {
            result.statusCode = 200
        }
        if (result.statusCode >= 200 && result.statusCode < 300) {
            result.ok = true
            result.status = "ok"
        } else if (result.status == "not_started") {
            result.status = "http_${result.statusCode}"
        }
        if (result.body.size > 200000) {
            result.truncated = true
            result.body = result.body[0..200000]
        }
        result
    }
}

public class SourceSyncPlan {
    public var requests: ArrayList<SourceFetchRequest> = ArrayList<SourceFetchRequest>()
    public var truncated: Bool = false

    public init() {}
}

public class SourceSyncPlanner {
    private let builder: SourceRequestBuilder = SourceRequestBuilder()

    public init() {}

    public func productionPlan(scope: SourceScope): SourceSyncPlan {
        let plan = SourceSyncPlan()
        for (org in scope.organizations) {
            plan.requests.add(this.builder.gitCodeOrgRepos(org))
        }
        plan.requests.add(this.builder.gitCodeRepo("cangjie/stdx"))
        plan.requests.add(this.builder.gitCodeSource("cangjie/stdx", "main", "src/http/client.cj"))
        plan.requests.add(this.builder.gitCodeIssueHistory("cangjie/cangjie"))
        plan.requests.add(this.builder.gitCodePrHistory("cangjie/cangjie"))
        for (url in scope.websiteUrls) {
            plan.requests.add(this.builder.website(url))
        }
        for (url in scope.docsUrls) {
            plan.requests.add(this.builder.docs(url))
        }
        if (scope.includesGovernedWebCandidates) {
            plan.requests.add(this.builder.webCandidate("https://example.invalid/cangjie-tutorial"))
        }
        plan
    }
}

public class LiveApplyOptions {
    public var apply: Bool = false
    public var maxRepos: Int64 = -1
    public var maxFilesPerRepo: Int64 = -1
    public var maxItems: Int64 = -1
    public var since: String = ""
    public var simulateValidationFailure: Bool = false

    public init() {}
}

public class LiveApplyResult {
    public var ok: Bool = false
    public var applied: Bool = false
    public var requests: Int64 = 0
    public var fetched: Int64 = 0
    public var failed: Int64 = 0
    public var rawCount: Int64 = 0
    public var normalizedCount: Int64 = 0
    public var truncated: Bool = false
    public var activeVersion: String = ""
    public var candidateVersion: String = ""
    public var failedVersion: String = ""
    public var since: String = ""
    public var errorReport: String = ""

    public init() {}
}

public class SourceAdapter {
    private let runner: SourceFetchRunner
    private let builder: SourceRequestBuilder
    private let normalizer: SourceResponseNormalizer

    public init(runner!: SourceFetchRunner = DisabledNetworkFetchRunner()) {
        this.runner = runner
        this.builder = SourceRequestBuilder()
        this.normalizer = SourceResponseNormalizer()
    }

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        this.normalizer.normalize(request, this.runner.fetch(request))
    }

    public func fetchGitCodeOrg(org: String): SourceFetchResult {
        this.fetch(this.builder.gitCodeOrgRepos(org))
    }

    public func fetchGitCodeRepo(repo: String, ref!: String = "main"): SourceFetchResult {
        this.fetch(this.builder.gitCodeRepo(repo, ref: ref))
    }

    public func fetchGitCodeSource(repo: String, ref: String, path: String): SourceFetchResult {
        this.fetch(this.builder.gitCodeSource(repo, ref, path))
    }

    public func fetchGitCodeIssueHistory(repo: String): SourceFetchResult {
        this.fetch(this.builder.gitCodeIssueHistory(repo))
    }

    public func fetchGitCodePrHistory(repo: String): SourceFetchResult {
        this.fetch(this.builder.gitCodePrHistory(repo))
    }

    public func fetchCangjieWebsite(url: String): SourceFetchResult {
        this.fetch(this.builder.website(url))
    }

    public func fetchCangjieDocs(url: String): SourceFetchResult {
        this.fetch(this.builder.docs(url))
    }

    public func fetchWebCandidate(url: String): SourceFetchResult {
        this.fetch(this.builder.webCandidate(url))
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
        for (record in records) {
            this.writeLines("raw/${safeName(record.metadata.sourceType)}/${safeName(record.sourceId)}.ckb", this.rawLines(singleRawRecord(record)))
        }
    }

    public func saveNormalized(records: ArrayList<NormalizedRecord>): Unit {
        this.writeLines("normalized/records.ckb", this.normalizedLines(records))
    }

    public func saveCandidateRaw(records: ArrayList<RawRecord>, version: String): Unit {
        if (version == "") {
            return
        }
        this.writeLines("raw/candidate/${safeName(version)}/records.ckb", this.rawLines(records))
    }

    public func saveCandidateNormalized(records: ArrayList<NormalizedRecord>, version: String): Unit {
        if (version == "") {
            return
        }
        this.writeLines("normalized/candidate/${safeName(version)}.ckb", this.normalizedLines(records))
    }

    public func saveMetadata(status: KnowledgeStatus): Unit {
        var text = "active=${status.activeKnowledgeVersion}\n"
        text += "candidate=${status.candidateKnowledgeVersion}\n"
        text += "failed=${status.failedCandidateVersion}\n"
        text += "rawCount=${status.storage.rawCount}\n"
        text += "normalizedCount=${status.storage.normalizedCount}\n"
        text += "indexCount=${status.storage.indexCount}\n"
        text += "textIndexCount=${status.storage.textIndexCount}\n"
        text += "vectorIndexCount=${status.storage.vectorIndexCount}\n"
        text += "symbolIndexCount=${status.storage.symbolIndexCount}\n"
        text += "graphIndexCount=${status.storage.graphIndexCount}\n"
        text += this.indexManifestLines(status.indexManifest)
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
            if (parts.size >= 19) {
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
            if (parts.size >= 20) {
                let metadata = metadataFromParts(parts, 6)
                let record = NormalizedRecord()
                record.sourceId = unescapeField(parts[0])
                record.recordKind = unescapeField(parts[1])
                record.title = unescapeField(parts[2])
                record.chunk = unescapeField(parts[3])
                record.citation = unescapeField(parts[4])
                record.score = try { Float64.parse(parts[5]) } catch (_: Exception) { 0.0 }
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
        let path = this.root.join(relative)
        if (!exists(path.parent)) {
            Directory.create(path.parent, recursive: true)
        }
        File.writeTo(path, text.toArray())
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
            out += "${escapeField(record.sourceId)}|${escapeField(record.recordKind)}|${escapeField(record.title)}|${escapeField(record.chunk)}|${escapeField(record.citation)}|${record.score}|${metadataLine(record.metadata)}\n"
        }
        out
    }

    private func indexManifestLines(manifest: IndexManifest): String {
        var out = "indexManifestActive=${manifest.activeVersion}\n"
        out += "indexManifestCandidate=${manifest.candidateVersion}\n"
        for (entry in manifest.entries) {
            out += "index ${entry.kind}|${entry.version}|${entry.itemCount}|${entry.deterministic}|${entry.candidateIsolated}|${escapeField(entry.notes)}\n"
        }
        out
    }
}

private func singleRawRecord(record: RawRecord): ArrayList<RawRecord> {
    let records = ArrayList<RawRecord>()
    records.add(record)
    records
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
    let planner = SourceSyncPlanner()
    let plan = planner.productionPlan(kb.sourceScope)
    var okCount: Int64 = 0
    var orgStatus = "missing"
    var repoStatus = "missing"
    var docsStatus = "missing"
    var webCandidateStatus = "missing"
    for (i in 0..plan.requests.size) {
        let request = plan.requests[i]
        let fetch = adapter.fetch(request)
        if (fetch.ok) {
            okCount += 1
        }
        if (request.kind == SourceKinds.GITCODE_ORG) {
            orgStatus = fetch.status
            kb.ingestFetchResult("sync-org-${request.repo}", SourceTypes.COMMUNITY, fetch, "GitCode ${request.repo} org", TrustLevels.COMMUNITY, ReviewStates.REVIEWED)
        } else if (request.kind == SourceKinds.GITCODE_REPO) {
            repoStatus = fetch.status
            kb.ingestFetchResult("sync-repo-${safeName(request.repo)}", SourceTypes.REPO, fetch, "GitCode ${request.repo} repo", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
        } else if (request.kind == SourceKinds.GITCODE_SOURCE) {
            kb.ingestFetchResult("sync-source-${safeName(request.repo)}-${safeName(request.path)}", SourceTypes.REPO, fetch, "GitCode ${request.repo} source", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
        } else if (request.kind == SourceKinds.GITCODE_ISSUE_HISTORY) {
            kb.ingestFetchResult("sync-issue-${safeName(request.repo)}", SourceTypes.COMMUNITY, fetch, "GitCode issue history", TrustLevels.COMMUNITY, ReviewStates.REVIEWED)
        } else if (request.kind == SourceKinds.GITCODE_PR_HISTORY) {
            kb.ingestFetchResult("sync-pr-${safeName(request.repo)}", SourceTypes.COMMUNITY, fetch, "GitCode PR history", TrustLevels.COMMUNITY, ReviewStates.REVIEWED)
        } else if (request.kind == SourceKinds.CANGJIE_DOCS) {
            docsStatus = fetch.status
            kb.ingestFetchResult("sync-docs-${i}", SourceTypes.DOC, fetch, "Cangjie docs", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
        } else if (request.kind == SourceKinds.CANGJIE_WEBSITE) {
            kb.ingestFetchResult("sync-website-${i}", SourceTypes.WEBSITE, fetch, "Cangjie website", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
        } else if (request.kind == SourceKinds.WEB_CANDIDATE) {
            webCandidateStatus = fetch.status
            kb.ingestFetchResult("sync-web-candidate-${i}", SourceTypes.WEB_CANDIDATE, fetch, "Web candidate", TrustLevels.WEB_CANDIDATE, ReviewStates.CANDIDATE)
        }
    }
    kb.normalize()
    kb.persist(store)
    "sync status requests=${plan.requests.size} ok=${okCount} org=${orgStatus} repo=${repoStatus} docs=${docsStatus} webCandidate=${webCandidateStatus}"
}

public func ckbSyncLiveApply(kb: KnowledgeBase, adapter: SourceAdapter, store: FileKnowledgeStore, options: LiveApplyOptions): LiveApplyResult {
    let result = LiveApplyResult()
    result.applied = options.apply
    result.since = options.since
    let planner = SourceSyncPlanner()
    let plan = limitedPlan(planner.productionPlan(kb.sourceScope), options)
    result.truncated = plan.truncated
    result.requests = plan.requests.size
    if (!options.apply) {
        result.ok = true
        return result
    }
    for (i in 0..plan.requests.size) {
        let request = plan.requests[i]
        let fetch = adapter.fetch(request)
        if (fetch.ok) {
            result.fetched += 1
            ingestLiveFetch(kb, request, fetch, i)
        } else {
            result.failed += 1
            result.errorReport += "${request.kind}:${request.repo}:${fetch.status}\n"
        }
    }
    kb.normalize()
    kb.publishIndex(options.simulateValidationFailure)
    let status = kb.status()
    result.rawCount = status.storage.rawCount
    result.normalizedCount = status.storage.normalizedCount
    result.activeVersion = status.activeKnowledgeVersion
    result.candidateVersion = status.candidateKnowledgeVersion
    result.failedVersion = status.failedCandidateVersion
    kb.persistCandidateSnapshot(store)
    if (status.failedCandidateVersion != "") {
        result.ok = false
        return result
    }
    kb.persistActiveSnapshot(store)
    result.ok = true
    result
}

public func ckbRebuildIndex(kb: KnowledgeBase, store: FileKnowledgeStore, fail!: Bool = false): IndexBuildResult {
    let result = kb.rebuildIndex(fail)
    if (result.ok) {
        kb.persistIndex(store)
    }
    result
}

private func limitedPlan(plan: SourceSyncPlan, options: LiveApplyOptions): SourceSyncPlan {
    let out = SourceSyncPlan()
    var repos: Int64 = 0
    var filesByRepo: ArrayList<String> = ArrayList<String>()
    for (request in plan.requests) {
        if (options.maxItems >= 0 && out.requests.size >= options.maxItems) {
            out.truncated = true
            continue
        }
        if (request.kind == SourceKinds.GITCODE_ORG || request.kind == SourceKinds.GITCODE_REPO || request.kind == SourceKinds.GITCODE_SOURCE || request.kind == SourceKinds.GITCODE_ISSUE_HISTORY || request.kind == SourceKinds.GITCODE_PR_HISTORY) {
            if (request.repo != "" && !repoSeen(out, request.repo)) {
                if (options.maxRepos >= 0 && repos >= options.maxRepos) {
                    out.truncated = true
                    continue
                }
                repos += 1
            }
        }
        if (request.kind == SourceKinds.GITCODE_SOURCE) {
            let key = request.repo
            let current = countMatches(filesByRepo, key)
            if (options.maxFilesPerRepo >= 0 && current >= options.maxFilesPerRepo) {
                out.truncated = true
                continue
            }
            filesByRepo.add(key)
        }
        out.requests.add(request)
    }
    out
}

private func repoSeen(plan: SourceSyncPlan, repo: String): Bool {
    for (request in plan.requests) {
        if (request.repo == repo && (request.kind == SourceKinds.GITCODE_ORG || request.kind == SourceKinds.GITCODE_REPO || request.kind == SourceKinds.GITCODE_SOURCE || request.kind == SourceKinds.GITCODE_ISSUE_HISTORY || request.kind == SourceKinds.GITCODE_PR_HISTORY)) {
            return true
        }
    }
    false
}

private func countMatches(values: ArrayList<String>, value: String): Int64 {
    var count: Int64 = 0
    for (entry in values) {
        if (entry == value) {
            count += 1
        }
    }
    count
}

private func ingestLiveFetch(kb: KnowledgeBase, request: SourceFetchRequest, fetch: SourceFetchResult, index: Int64): Unit {
    if (request.kind == SourceKinds.GITCODE_ORG) {
        kb.ingestFetchResult("live-org-${safeName(request.repo)}", SourceTypes.COMMUNITY, fetch, "GitCode ${request.repo} org", TrustLevels.COMMUNITY, ReviewStates.REVIEWED)
    } else if (request.kind == SourceKinds.GITCODE_REPO) {
        kb.ingestFetchResult("live-repo-${safeName(request.repo)}", SourceTypes.REPO, fetch, "GitCode ${request.repo} repo", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    } else if (request.kind == SourceKinds.GITCODE_SOURCE) {
        kb.ingestFetchResult("live-source-${safeName(request.repo)}-${safeName(request.path)}", SourceTypes.REPO, fetch, "GitCode ${request.repo} source", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    } else if (request.kind == SourceKinds.GITCODE_ISSUE_HISTORY) {
        kb.ingestFetchResult("live-issue-${safeName(request.repo)}", SourceTypes.COMMUNITY, fetch, "GitCode issue history", TrustLevels.COMMUNITY, ReviewStates.REVIEWED)
    } else if (request.kind == SourceKinds.GITCODE_PR_HISTORY) {
        kb.ingestFetchResult("live-pr-${safeName(request.repo)}", SourceTypes.COMMUNITY, fetch, "GitCode PR history", TrustLevels.COMMUNITY, ReviewStates.REVIEWED)
    } else if (request.kind == SourceKinds.CANGJIE_DOCS) {
        kb.ingestFetchResult("live-docs-${index}", SourceTypes.DOC, fetch, "Cangjie docs", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    } else if (request.kind == SourceKinds.CANGJIE_WEBSITE) {
        kb.ingestFetchResult("live-website-${index}", SourceTypes.WEBSITE, fetch, "Cangjie website", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    } else if (request.kind == SourceKinds.WEB_CANDIDATE) {
        kb.ingestFetchResult("live-web-candidate-${index}", SourceTypes.WEB_CANDIDATE, fetch, "Web candidate", TrustLevels.WEB_CANDIDATE, ReviewStates.CANDIDATE)
    }
}

private func metadataLine(metadata: KnowledgeMetadata): String {
    "${escapeField(metadata.sourceType)}|${escapeField(metadata.sourceUrl)}|${escapeField(metadata.repo)}|${escapeField(metadata.commit)}|${escapeField(metadata.path)}|${escapeField(metadata.symbol)}|${escapeField(metadata.docVersion)}|${escapeField(metadata.crawlAt)}|${escapeField(metadata.indexedAt)}|${escapeField(metadata.knowledgeVersion)}|${escapeField(metadata.candidateVersion)}|${metadata.contentSize}|${escapeField(metadata.trustLevel)}|${escapeField(metadata.reviewState)}|${escapeField(metadata.license)}"
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
    metadata.candidateVersion = unescapeField(parts[start + 10])
    metadata.contentSize = try { Int64.parse(parts[start + 11]) } catch (_: Exception) { 0 }
    metadata.trustLevel = unescapeField(parts[start + 12])
    metadata.reviewState = unescapeField(parts[start + 13])
    metadata.license = unescapeField(parts[start + 14])
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
