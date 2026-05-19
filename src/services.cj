package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.convert.Parsable
import std.fs.{Directory, File, Path, exists}
import std.io.*
import std.process.*

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
    public var paginationParam: String = "page"
    public var perPageParam: String = "per_page"
    public var timeoutMillis: Int64 = 10000
    public var retryCount: Int64 = 2

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
    public var contentType: String = ""
    public var bytes: Int64 = 0
    public var bodyHash: String = ""
    public var retryAfterSeconds: Int64 = 0
    public var attempts: Int64 = 0

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
    public var statusCode: Int64 = 200
    public var status: String = "ok"
    public var body: String = ""
    public var retryAfterSeconds: Int64 = 0

    public init() {}

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        this.calls.add(request)
        let result = SourceFetchResult()
        result.ok = this.statusCode >= 200 && this.statusCode < 300
        result.status = this.status
        result.statusCode = this.statusCode
        result.commit = "fake-commit"
        result.sourceUrl = request.url
        result.normalizedType = request.kind
        result.etag = "fake-etag"
        result.lastModified = "2026-05-19T00:00:00Z"
        result.body = if (this.body == "") { "fake ${request.kind} ${request.repo} ${request.path} func HttpClient Cangjie docs tutorial" } else { this.body }
        result.contentType = if (request.accept == "text/html") { "text/html" } else { "application/json" }
        result.bytes = result.body.size
        result.bodyHash = stableSummaryHash(result.body)
        result.retryAfterSeconds = this.retryAfterSeconds
        result.attempts = 1
        result
    }
}

public class CkbRuntimeConfig {
    public var networkEnabled: Bool = false
    public var gitCodeBaseUrl: String = "https://gitcode.com/api/v5"
    public var gitCodeAuthMode: String = "none"
    public var gitCodeTokenRef: String = ""
    public var gitCodeTokenFile: String = ""
    public var websiteEnabled: Bool = false
    public var docsEnabled: Bool = false
    public var indexBackend: String = "offline"
    public var embeddingProvider: String = "none"
    public var timeoutMillis: Int64 = 10000
    public var retryCount: Int64 = 2

    public init() {}

    public func tokenPresent(): Bool {
        this.gitCodeTokenRef != "" || this.gitCodeTokenFile != ""
    }

    public func redactedSummary(): String {
        var out = "network=${if (this.networkEnabled) { "enabled" } else { "disabled" }}"
        out += " gitcode.baseUrl=${redactSensitive(this.gitCodeBaseUrl)}"
        out += " gitcode.authMode=${this.gitCodeAuthMode}"
        out += " gitcode.token=${if (this.tokenPresent()) { "present" } else { "absent" }}"
        out += " website=${if (this.websiteEnabled) { "enabled" } else { "disabled" }}"
        out += " docs=${if (this.docsEnabled) { "enabled" } else { "disabled" }}"
        out += " index.backend=${this.indexBackend}"
        out += " embedding.provider=${this.embeddingProvider}"
        out
    }
}

public func loadCkbRuntimeConfig(path: String): CkbRuntimeConfig {
    let config = CkbRuntimeConfig()
    if (path == "" || !exists(Path(path))) {
        return config
    }
    let text = String.fromUtf8(File.readFrom(Path(path)))
    for (line in text.split("\n")) {
        let trimmed = line.trimAscii()
        if (trimmed == "" || trimmed.startsWith("#")) {
            continue
        }
        let parts = trimmed.split("=")
        if (parts.size < 2) {
            continue
        }
        let key = parts[0].trimAscii()
        var value = parts[1].trimAscii()
        if (parts.size > 2) {
            for (i in 2..parts.size) {
                value += "=${parts[i]}"
            }
        }
        configApply(config, key, unquoteConfigValue(value))
    }
    config
}

public func redactSensitive(raw: String): String {
    var text = raw
    text = redactQueryParam(text, "access_token")
    text = redactQueryParam(text, "token")
    text = redactAssignment(text, "Authorization")
    text = redactAssignment(text, "authorization")
    text = redactAssignment(text, "Cookie")
    text = redactAssignment(text, "cookie")
    text = redactAssignment(text, "token")
    text = redactAssignment(text, "access_token")
    text = redactAbsolutePath(text)
    text
}

public class HttpExecutionRequest {
    public var method: String = "GET"
    public var url: String = ""
    public var accept: String = "application/json"
    public var authHeader: String = ""
    public var timeoutMillis: Int64 = 10000
    public var retryCount: Int64 = 2

    public init() {}
}

public class HttpExecutionResponse {
    public var statusCode: Int64 = 0
    public var body: String = ""
    public var contentType: String = ""
    public var retryAfterSeconds: Int64 = 0
    public var status: String = "not_started"

    public init() {}
}

public interface HttpRequestExecutor {
    func get(request: HttpExecutionRequest): HttpExecutionResponse
}

public class CurlHttpRequestExecutor <: HttpRequestExecutor {
    public init() {}

    public func get(request: HttpExecutionRequest): HttpExecutionResponse {
        let response = HttpExecutionResponse()
        if (request.method != "GET") {
            response.status = "unsupported_method"
            return response
        }
        let timeoutSeconds = if (request.timeoutMillis <= 0) { "10" } else { "${(request.timeoutMillis + 999) / 1000}" }
        let args = ["-sS", "-L", "--max-time", timeoutSeconds, "-H", "Accept: ${request.accept}", "-w", "\nCKB_HTTP_STATUS:%{http_code}\nCKB_CONTENT_TYPE:%{content_type}\n", request.url]
        try {
            let process = launch("curl", args, stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
            let out = StringReader<InputStream>(process.stdOutPipe).readToEnd()
            let err = StringReader<InputStream>(process.stdErrPipe).readToEnd()
            let code = process.wait()
            response.body = stripCurlTrailer(out)
            response.statusCode = parseCurlStatus(out)
            response.contentType = parseCurlContentType(out)
            response.status = if (code == 0) { "http_${response.statusCode}" } else { "transport_error" }
            if (code != 0 && err.contains("timed out")) {
                response.status = "timeout"
            }
        } catch (_: Exception) {
            response.status = "transport_error"
        }
        response
    }
}

public class HttpSourceFetchRunner <: SourceFetchRunner {
    private let config: CkbRuntimeConfig
    private let executor: HttpRequestExecutor

    public init(config: CkbRuntimeConfig, executor!: HttpRequestExecutor = CurlHttpRequestExecutor()) {
        this.config = config
        this.executor = executor
    }

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        let result = SourceFetchResult()
        result.sourceUrl = request.url
        result.normalizedType = request.kind
        if (!this.config.networkEnabled) {
            result.status = "network_disabled"
            return result
        }
        if (request.method != "GET") {
            result.status = "unsupported_method"
            return result
        }
        let http = HttpExecutionRequest()
        http.method = request.method
        http.url = request.url
        http.accept = request.accept
        http.timeoutMillis = request.timeoutMillis
        http.retryCount = request.retryCount
        http.authHeader = if (this.config.tokenPresent()) { "present-redacted" } else { "" }
        var attempt: Int64 = 0
        var last = HttpExecutionResponse()
        while (attempt <= request.retryCount) {
            attempt += 1
            last = this.executor.get(http)
            if (last.statusCode != 429 && last.statusCode < 500 && last.status != "timeout") {
                break
            }
        }
        result.attempts = attempt
        result.statusCode = last.statusCode
        result.body = last.body
        result.contentType = last.contentType
        result.bytes = last.body.size
        result.bodyHash = stableSummaryHash(last.body)
        result.retryAfterSeconds = last.retryAfterSeconds
        result.ok = last.statusCode >= 200 && last.statusCode < 300
        if (last.status == "timeout") {
            result.status = "timeout"
        } else if (result.ok) {
            result.status = "ok"
        } else if (last.statusCode == 401 || last.statusCode == 403) {
            result.status = "auth_degraded"
        } else if (last.statusCode == 429) {
            result.status = "rate_limited"
        } else if (last.statusCode == 404) {
            result.status = "not_found"
        } else if (last.statusCode >= 500) {
            result.status = "server_error"
        } else {
            result.status = last.status
        }
        result
    }
}

public class SourceRequestBuilder {
    private let gitCodeApiRoot: String

    public init(gitCodeApiRoot!: String = "https://gitcode.com/api/v5") {
        this.gitCodeApiRoot = gitCodeApiRoot
    }

    public func gitCodeOrgRepos(org: String): SourceFetchRequest {
        let request = SourceFetchRequest(SourceKinds.GITCODE_ORG, "${this.gitCodeApiRoot}/orgs/${org}/projects?visibility=public&page=1&per_page=100", repo: org, purpose: "enumerate_public_repos")
        request.authHint = "gitcode-token-optional-redacted"
        request.paginationParam = "page"
        request.perPageParam = "per_page"
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
        result.bytes = result.body.size
        if (result.bodyHash == "") {
            result.bodyHash = stableSummaryHash(result.body)
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
    private let builder: SourceRequestBuilder

    public init(builder!: SourceRequestBuilder = SourceRequestBuilder()) {
        this.builder = builder
    }

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

public class LiveSyncOptions {
    public var dryRun: Bool = false
    public var apply: Bool = false
    public var maxRepos: Int64 = -1
    public var maxFilesPerRepo: Int64 = -1
    public var maxItems: Int64 = -1
    public var since: String = ""
    public var simulateValidationFailure: Bool = false

    public init() {}
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

public func ckbSyncLive(kb: KnowledgeBase, config: CkbRuntimeConfig, options: LiveSyncOptions, runner!: SourceFetchRunner = DisabledNetworkFetchRunner(), store!: FileKnowledgeStore = FileKnowledgeStore("target/ckb-data")): String {
    if (options.dryRun == options.apply) {
        return "usage error: sync-live requires exactly one of --dry-run or --apply"
    }
    if (!config.networkEnabled) {
        return "sync-live mode=${if (options.dryRun) { "dry-run" } else { "apply" }} network=disabled requests=0 status=network_disabled"
    }
    let planner = SourceSyncPlanner(builder: SourceRequestBuilder(gitCodeApiRoot: config.gitCodeBaseUrl))
    let applyOptions = liveApplyOptionsFromSync(options)
    let plan = limitedPlan(planner.productionPlan(kb.sourceScope), applyOptions)
    var out = "sync-live mode=${if (options.dryRun) { "dry-run" } else { "apply" }} ${config.redactedSummary()}\n"
    var okCount: Int64 = 0
    var degradedCount: Int64 = 0
    for (request in plan.requests) {
        request.timeoutMillis = config.timeoutMillis
        request.retryCount = config.retryCount
        if (!config.websiteEnabled && request.kind == SourceKinds.CANGJIE_WEBSITE) {
            out += "skip kind=${request.kind} reason=website_disabled url=${redactSensitive(request.url)}\n"
            continue
        }
        if (!config.docsEnabled && request.kind == SourceKinds.CANGJIE_DOCS) {
            out += "skip kind=${request.kind} reason=docs_disabled url=${redactSensitive(request.url)}\n"
            continue
        }
        let fetch = SourceResponseNormalizer().normalize(request, runner.fetch(request))
        if (fetch.ok) {
            okCount += 1
        } else {
            degradedCount += 1
        }
        out += renderLiveFetchSummary(request, fetch)
        if (options.apply && fetch.ok) {
            ingestLiveFetch(kb, request, fetch, okCount + degradedCount)
        }
    }
    if (options.apply) {
        kb.normalize()
        kb.publishIndex(options.simulateValidationFailure)
        kb.persistCandidateSnapshot(store)
        if (kb.status().failedCandidateVersion == "") {
            kb.persistActiveSnapshot(store)
        }
    }
    out += "summary requests=${plan.requests.size} ok=${okCount} degraded=${degradedCount} truncated=${plan.truncated} rawWritten=${if (options.apply) { "true" } else { "false" }} since=${options.since}\n"
    redactSensitive(out)
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
        text += "vectorBackend=${status.storage.vectorBackend}\n"
        text += "vectorState=${status.storage.vectorState}\n"
        text += "vectorCollection=${status.storage.vectorCollection}\n"
        text += "vectorDimension=${status.storage.vectorDimension}\n"
        text += "vectorDegradedReason=${escapeField(status.storage.vectorDegradedReason)}\n"
        text += "graphBackend=${status.storage.graphBackend}\n"
        text += "graphState=${status.storage.graphState}\n"
        text += "graphNodeCount=${status.storage.graphNodeCount}\n"
        text += "graphEdgeCount=${status.storage.graphEdgeCount}\n"
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

    public func saveVectorCollection(records: ArrayList<VectorRecord>, collection: String): Unit {
        this.writeLines("index/vector-${safeName(collection)}.ckb", this.vectorLines(records))
    }

    public func saveGraph(graph: GraphBuildResult): Unit {
        this.writeLines("index/graph-nodes.ckb", this.graphNodeLines(graph.nodes))
        this.writeLines("index/graph-edges.ckb", this.graphEdgeLines(graph.edges))
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
        this.parseNormalized(this.readLines("normalized/records.ckb"))
    }

    public func loadActiveVersion(): String {
        this.readLines("index/active.version").trimAscii()
    }

    public func loadActiveIndex(): ArrayList<NormalizedRecord> {
        this.parseNormalized(this.readLines("index/active.ckb"))
    }

    public func loadMetadataStatus(): StoreMetadataStatus {
        let status = StoreMetadataStatus()
        let text = this.readLines("metadata/status.ckb")
        for (line in text.split("\n")) {
            let trimmed = line.trimAscii()
            if (trimmed == "") {
                continue
            }
            let parts = trimmed.split("=")
            if (parts.size < 2) {
                continue
            }
            let key = parts[0]
            let value = trimmed[(key.size + 1)..trimmed.size]
            if (key == "active") {
                status.activeVersion = value
            } else if (key == "candidate") {
                status.candidateVersion = value
            } else if (key == "failed") {
                status.failedVersion = value
            }
        }
        status
    }

    public func loadActiveSnapshot(): ActiveSnapshot {
        let snapshot = ActiveSnapshot()
        snapshot.activeVersion = this.loadActiveVersion()
        if (snapshot.activeVersion == "") {
            snapshot.valid = false
            snapshot.diagnostic = "missing_active_version"
            return snapshot
        }
        let metadata = this.loadMetadataStatus()
        snapshot.candidateVersion = metadata.candidateVersion
        snapshot.failedVersion = metadata.failedVersion
        if (metadata.activeVersion != "" && metadata.activeVersion != snapshot.activeVersion) {
            snapshot.valid = false
            snapshot.diagnostic = "metadata_active_mismatch"
            return snapshot
        }
        let diagnostics = ArrayList<String>()
        snapshot.activeIndex = this.parseNormalizedStrict(this.readLines("index/active.ckb"), diagnostics)
        if (diagnostics.size > 0) {
            snapshot.valid = false
            snapshot.diagnostic = "malformed_active_index"
            return snapshot
        }
        if (snapshot.activeIndex.size == 0) {
            snapshot.valid = false
            snapshot.diagnostic = "missing_or_empty_active_index"
            return snapshot
        }
        for (record in snapshot.activeIndex) {
            if (record.metadata.knowledgeVersion != snapshot.activeVersion) {
                snapshot.valid = false
                snapshot.diagnostic = "active_index_version_mismatch"
                return snapshot
            }
        }
        snapshot.rawRecords = this.loadRaw()
        snapshot.normalizedRecords = this.loadNormalized()
        snapshot.valid = true
        snapshot.diagnostic = "ok"
        snapshot.hasVectorArtifact = this.has("index/vector-active.ckb")
        snapshot.hasGraphArtifacts = this.has("index/graph-nodes.ckb") && this.has("index/graph-edges.ckb")
        snapshot
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

    private func parseNormalized(text: String): ArrayList<NormalizedRecord> {
        let diagnostics = ArrayList<String>()
        this.parseNormalizedInternal(text, false, diagnostics)
    }

    private func parseNormalizedStrict(text: String, diagnostics: ArrayList<String>): ArrayList<NormalizedRecord> {
        this.parseNormalizedInternal(text, true, diagnostics)
    }

    private func parseNormalizedInternal(text: String, strict: Bool, diagnostics: ArrayList<String>): ArrayList<NormalizedRecord> {
        let out = ArrayList<NormalizedRecord>()
        if (text == "") {
            return out
        }
        var lineNumber: Int64 = 0
        for (line in text.split("\n")) {
            lineNumber += 1
            if (line == "") {
                continue
            }
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
            } else if (strict) {
                diagnostics.add("malformed active index line ${lineNumber}")
            }
        }
        out
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

    private func vectorLines(records: ArrayList<VectorRecord>): String {
        var out = ""
        for (record in records) {
            out += "${escapeField(record.id)}|${escapeField(record.metadata.knowledgeVersion)}|${escapeField(record.metadata.sourceId)}|${escapeField(record.metadata.sourceType)}|${escapeField(record.metadata.trustLevel)}|${escapeField(record.metadata.reviewState)}|${escapeField(record.citation)}|${vectorToLine(record.vector)}\n"
        }
        out
    }

    private func graphNodeLines(nodes: ArrayList<GraphNode>): String {
        var out = ""
        for (node in nodes) {
            out += "${escapeField(node.nodeId)}|${escapeField(node.nodeType)}|${escapeField(node.label)}|${escapeField(node.sourceId)}|${escapeField(node.knowledgeVersion)}\n"
        }
        out
    }

    private func graphEdgeLines(edges: ArrayList<GraphEdge>): String {
        var out = ""
        for (edge in edges) {
            out += "${escapeField(edge.edgeId)}|${escapeField(edge.edgeType)}|${escapeField(edge.fromNodeId)}|${escapeField(edge.toNodeId)}|${escapeField(edge.sourceId)}|${escapeField(edge.knowledgeVersion)}\n"
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

public class StoreMetadataStatus {
    public var activeVersion: String = ""
    public var candidateVersion: String = ""
    public var failedVersion: String = ""

    public init() {}
}

public class ActiveSnapshot {
    public var valid: Bool = false
    public var diagnostic: String = ""
    public var activeVersion: String = ""
    public var candidateVersion: String = ""
    public var failedVersion: String = ""
    public var rawRecords: ArrayList<RawRecord> = ArrayList<RawRecord>()
    public var normalizedRecords: ArrayList<NormalizedRecord> = ArrayList<NormalizedRecord>()
    public var activeIndex: ArrayList<NormalizedRecord> = ArrayList<NormalizedRecord>()
    public var hasVectorArtifact: Bool = false
    public var hasGraphArtifacts: Bool = false

    public init() {}
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
        kb.persistActiveSnapshot(store)
    }
    result
}

public func renderRuntimeDoctor(config: CkbRuntimeConfig): String {
    "runtime ${config.redactedSummary()}\n"
}

private func liveApplyOptionsFromSync(options: LiveSyncOptions): LiveApplyOptions {
    let out = LiveApplyOptions()
    out.apply = options.apply
    out.maxRepos = options.maxRepos
    out.maxFilesPerRepo = options.maxFilesPerRepo
    out.maxItems = options.maxItems
    out.since = options.since
    out.simulateValidationFailure = options.simulateValidationFailure
    out
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

private func vectorToLine(vector: ArrayList<Float64>): String {
    var out = ""
    for (i in 0..vector.size) {
        if (i > 0) {
            out += ","
        }
        out += "${vector[i]}"
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
    "${escapeField(metadata.sourceType)}|${escapeField(metadata.sourceUrl)}|${escapeField(metadata.repo)}|${escapeField(metadata.commit)}|${escapeField(metadata.path)}|${escapeField(metadata.symbol)}|${escapeField(metadata.docVersion)}|${escapeField(metadata.crawlAt)}|${escapeField(metadata.indexedAt)}|${escapeField(metadata.knowledgeVersion)}|${escapeField(metadata.candidateVersion)}|${metadata.contentSize}|${escapeField(metadata.trustLevel)}|${escapeField(metadata.reviewState)}|${escapeField(metadata.license)}|${escapeField(metadata.sourceId)}"
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
    if (parts.size > start + 15) {
        metadata.sourceId = unescapeField(parts[start + 15])
    }
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

private func findText(raw: String, needle: String): Int64 {
    if (needle == "") {
        return 0
    }
    if (raw.size < needle.size) {
        return -1
    }
    for (i in 0..=raw.size - needle.size) {
        if (raw[i..i + needle.size] == needle) {
            return i
        }
    }
    -1
}

private func configApply(config: CkbRuntimeConfig, key: String, value: String): Unit {
    if (key == "network.enabled") {
        config.networkEnabled = parseBool(value)
    } else if (key == "gitcode.baseUrl") {
        config.gitCodeBaseUrl = value
    } else if (key == "gitcode.authMode") {
        config.gitCodeAuthMode = value
    } else if (key == "gitcode.tokenRef") {
        config.gitCodeTokenRef = value
    } else if (key == "gitcode.tokenFile") {
        config.gitCodeTokenFile = value
    } else if (key == "website.enabled") {
        config.websiteEnabled = parseBool(value)
    } else if (key == "docs.enabled") {
        config.docsEnabled = parseBool(value)
    } else if (key == "index.backend") {
        config.indexBackend = value
    } else if (key == "embedding.provider") {
        config.embeddingProvider = value
    } else if (key == "network.timeoutMillis") {
        config.timeoutMillis = try { Int64.parse(value) } catch (_: Exception) { config.timeoutMillis }
    } else if (key == "network.retryCount") {
        config.retryCount = try { Int64.parse(value) } catch (_: Exception) { config.retryCount }
    }
}

private func parseBool(value: String): Bool {
    let lowered = value.toAsciiLower()
    lowered == "true" || lowered == "1" || lowered == "yes" || lowered == "enabled"
}

private func unquoteConfigValue(value: String): String {
    var out = value.trimAscii()
    if (out.size >= 2 && ((out.startsWith("\"") && out.endsWith("\"")) || (out.startsWith("'") && out.endsWith("'")))) {
        out = out[1..out.size - 1]
    }
    out
}

private func redactQueryParam(raw: String, key: String): String {
    var text = raw
    let needle1 = "${key}="
    let needle2 = "${key}%3D"
    text = redactAfterNeedle(text, needle1)
    text = redactAfterNeedle(text, needle2)
    text
}

private func redactAssignment(raw: String, key: String): String {
    var text = raw
    if (key == "Authorization" || key == "authorization" || key == "Cookie" || key == "cookie") {
        text = redactLineAfterNeedle(text, "${key}: ")
        text = redactLineAfterNeedle(text, "${key}:")
    } else {
        text = redactAfterNeedle(text, "${key}: ")
        text = redactAfterNeedle(text, "${key}:")
    }
    text = redactAfterNeedle(text, "${key}=")
    text
}

private func redactAfterNeedle(raw: String, needle: String): String {
    let idx = findText(raw, needle)
    if (idx < 0) {
        return raw
    }
    var end = idx + needle.size
    while (end < raw.size) {
        let ch = raw[end..end + 1]
        if (ch == "&" || ch == " " || ch == "\n" || ch == "\r" || ch == "\"" || ch == "'") {
            break
        }
        end += 1
    }
    raw[0..idx + needle.size] + "[redacted]" + raw[end..raw.size]
}

private func redactLineAfterNeedle(raw: String, needle: String): String {
    let idx = findText(raw, needle)
    if (idx < 0) {
        return raw
    }
    var end = idx + needle.size
    while (end < raw.size) {
        let ch = raw[end..end + 1]
        if (ch == "\n" || ch == "\r") {
            break
        }
        end += 1
    }
    raw[0..idx + needle.size] + "[redacted]" + raw[end..raw.size]
}

private func redactAbsolutePath(raw: String): String {
    var text = raw
    text = redactPathPrefix(text, "/Users/")
    text = redactPathPrefix(text, "/home/")
    text = redactPathPrefix(text, "/var/")
    text = redactPathPrefix(text, "/tmp/")
    text
}

private func redactPathPrefix(raw: String, prefix: String): String {
    let idx = findText(raw, prefix)
    if (idx < 0) {
        return raw
    }
    var end = idx
    while (end < raw.size) {
        let ch = raw[end..end + 1]
        if (ch == " " || ch == "\n" || ch == "\r" || ch == "\"" || ch == "'") {
            break
        }
        end += 1
    }
    raw[0..idx] + "[local-path-redacted]" + raw[end..raw.size]
}

public func stableSummaryHash(raw: String): String {
    var hash: Int64 = raw.size * 131
    if (raw.contains("repo")) {
        hash += 17
    }
    if (raw.contains("issue")) {
        hash += 31
    }
    if (raw.contains("func")) {
        hash += 47
    }
    "h${hash}"
}

private func stripCurlTrailer(raw: String): String {
    let marker = "\nCKB_HTTP_STATUS:"
    let idx = findText(raw, marker)
    if (idx < 0) {
        return raw
    }
    raw[0..idx]
}

private func parseCurlStatus(raw: String): Int64 {
    let marker = "CKB_HTTP_STATUS:"
    let idx = findText(raw, marker)
    if (idx < 0) {
        return 0
    }
    let rest = raw[idx + marker.size..raw.size]
    let line = rest.split("\n")[0].trimAscii()
    try { Int64.parse(line) } catch (_: Exception) { 0 }
}

private func parseCurlContentType(raw: String): String {
    let marker = "CKB_CONTENT_TYPE:"
    let idx = findText(raw, marker)
    if (idx < 0) {
        return ""
    }
    raw[idx + marker.size..raw.size].split("\n")[0].trimAscii()
}

private func renderLiveFetchSummary(request: SourceFetchRequest, fetch: SourceFetchResult): String {
    var shape = "unknown"
    if (request.kind == SourceKinds.GITCODE_ORG) {
        shape = "repo-list"
    } else if (request.kind == SourceKinds.CANGJIE_WEBSITE || request.kind == SourceKinds.CANGJIE_DOCS) {
        shape = "html-entry"
    } else if (request.kind == SourceKinds.GITCODE_ISSUE_HISTORY || request.kind == SourceKinds.GITCODE_PR_HISTORY) {
        shape = "history-list"
    } else if (request.kind == SourceKinds.GITCODE_REPO) {
        shape = "repo-metadata"
    } else if (request.kind == SourceKinds.GITCODE_SOURCE) {
        shape = "source-snapshot"
    }
    var out = "request kind=${request.kind} method=${request.method} url=${redactSensitive(request.url)} pageParam=${request.paginationParam} perPageParam=${request.perPageParam} timeoutMillis=${request.timeoutMillis} retryCount=${request.retryCount}"
    out += " -> status=${fetch.status} code=${fetch.statusCode} shape=${shape} bytes=${fetch.bytes} contentType=${fetch.contentType} hash=${fetch.bodyHash} attempts=${fetch.attempts}"
    if (fetch.retryAfterSeconds > 0) {
        out += " retryAfter=${fetch.retryAfterSeconds}"
    }
    out + "\n"
}

private func ingestLiveFetch(kb: KnowledgeBase, request: SourceFetchRequest, fetch: SourceFetchResult): Unit {
    if (request.kind == SourceKinds.GITCODE_ORG) {
        kb.ingestFetchResult("live-org-${safeName(request.repo)}", SourceTypes.COMMUNITY, fetch, "GitCode ${request.repo} repo list", TrustLevels.COMMUNITY, ReviewStates.REVIEWED)
    } else if (request.kind == SourceKinds.GITCODE_REPO) {
        kb.ingestFetchResult("live-repo-${safeName(request.repo)}", SourceTypes.REPO, fetch, "GitCode ${request.repo} repo", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    } else if (request.kind == SourceKinds.GITCODE_SOURCE) {
        kb.ingestFetchResult("live-source-${safeName(request.repo)}-${safeName(request.path)}", SourceTypes.REPO, fetch, "GitCode ${request.repo} source", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    } else if (request.kind == SourceKinds.GITCODE_ISSUE_HISTORY) {
        kb.ingestFetchResult("live-issue-${safeName(request.repo)}", SourceTypes.COMMUNITY, fetch, "GitCode issue history", TrustLevels.COMMUNITY, ReviewStates.REVIEWED)
    } else if (request.kind == SourceKinds.GITCODE_PR_HISTORY) {
        kb.ingestFetchResult("live-pr-${safeName(request.repo)}", SourceTypes.COMMUNITY, fetch, "GitCode PR history", TrustLevels.COMMUNITY, ReviewStates.REVIEWED)
    } else if (request.kind == SourceKinds.CANGJIE_DOCS) {
        kb.ingestFetchResult("live-docs-${safeName(request.url)}", SourceTypes.DOC, fetch, "Cangjie docs", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    } else if (request.kind == SourceKinds.CANGJIE_WEBSITE) {
        kb.ingestFetchResult("live-website-${safeName(request.url)}", SourceTypes.WEBSITE, fetch, "Cangjie website", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    } else if (request.kind == SourceKinds.WEB_CANDIDATE) {
        kb.ingestFetchResult("live-web-candidate-${safeName(request.url)}", SourceTypes.WEB_CANDIDATE, fetch, "Web candidate", TrustLevels.WEB_CANDIDATE, ReviewStates.CANDIDATE)
    }
}
