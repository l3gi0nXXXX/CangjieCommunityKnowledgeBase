package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.convert.Parsable
import std.env.getVariable
import std.fs.{Directory, File, Path, exists}
import std.io.*
import std.process.*

public class SourceKinds {
    public static let GITCODE_ORG: String = "gitcode_org"
    public static let GITCODE_REPO: String = "gitcode_repo"
    public static let GITCODE_TREE: String = "gitcode_tree"
    public static let GITCODE_SOURCE: String = "gitcode_source"
    public static let GITCODE_ISSUE_HISTORY: String = "gitcode_issue_history"
    public static let GITCODE_PR_HISTORY: String = "gitcode_pr_history"
    public static let GITCODE_COMMENT_HISTORY: String = "gitcode_comment_history"
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
    public var status: String = "ready"
    public var diagnostic: String = ""
    public var page: Int64 = 1
    public var perPage: Int64 = 100
    public var purpose: String = ""
    public var sourceVariant: String = ""
    public var paginationParam: String = "page"
    public var perPageParam: String = "per_page"
    public var timeoutMillis: Int64 = 10000
    public var retryCount: Int64 = 2
    public var repoVisibility: String = ""

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

public class SourceLimits {
    public static let MAX_FILE_BYTES: Int64 = 262144
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
    public var transportErrorClass: String = ""
    public var transportDiagnostic: String = ""
    public var curlExitCode: Int64 = 0
    public var repo: String = ""
    public var ref: String = ""
    public var path: String = ""
    public var repoVisibility: String = ""

    public init() {}
}

private class GitCodeContentsFile {
    var ok: Bool = false
    var status: String = "malformed_contents_response"
    var body: String = ""
    var path: String = ""
    var sha: String = ""
    var htmlUrl: String = ""
    var downloadUrl: String = ""

    init() {}
}

public class SourceAnalysisTriggerReasons {
    public static let COMPILE_ERROR: String = "compile_error"
    public static let RUNTIME_BUG: String = "runtime_bug"
    public static let STACK_TRACE: String = "stack_trace"
    public static let FILE_PATH_MENTIONED: String = "file_path_mentioned"
    public static let SYMBOL_MENTIONED: String = "symbol_mentioned"
    public static let PR_DIFF_REVIEW: String = "pr_diff_review"
    public static let INSUFFICIENT_SOURCE_EVIDENCE: String = "insufficient_source_evidence"
    public static let FRESH_SOURCE_REQUIRED: String = "fresh_source_required"
    public static let MANUAL_REQUEST: String = "manual_request"
}

public class SourceAnalysisAcquisition {
    public static let NONE: String = "none"
    public static let API_RAW: String = "api_raw"
    public static let API_CONTENTS: String = "api_contents"
    public static let CLONE: String = "clone"
}

public class SourceAnalysisRequest {
    public var repo: String = ""
    public var ref: String = "main"
    public var commit: String = ""
    public var query: String = ""
    public var issueUrl: String = ""
    public var prUrl: String = ""
    public var changedFiles: ArrayList<String> = ArrayList<String>()
    public var candidatePaths: ArrayList<String> = ArrayList<String>()
    public var allowCloneFallback: Bool = false
    public var maxFiles: Int64 = 5
    public var maxBytes: Int64 = 200000
    public var timeoutMillis: Int64 = 10000
    public var repoVisibility: String = RepoVisibility.PUBLIC
    public var visibility: String = RepoVisibility.PUBLIC
    public var cloneUrl: String = ""
    public var selector: String = ""
    public var retainFailedWorkspace: Bool = false

    public init() {}
}

public class TriggerDecision {
    public var shouldAnalyze: Bool = false
    public var triggerReasons: ArrayList<String> = ArrayList<String>()
    public var acquisitionPlan: String = "none"
    public var degraded: Bool = false
    public var diagnostic: String = ""

    public init() {}
}

public class SourceAnalysisFile {
    public var repo: String = ""
    public var ref: String = ""
    public var path: String = ""
    public var sourceUrl: String = ""
    public var bodyHash: String = ""
    public var excerpt: String = ""
    public var bytes: Int64 = 0
    public var acquisition: String = ""
    public var citation: String = ""
    public var truncated: Bool = false

    public init() {}
}

public class SourceAnalysisResult {
    public var analysisId: String = ""
    public var repo: String = ""
    public var ref: String = ""
    public var commit: String = ""
    public var triggerReasons: ArrayList<String> = ArrayList<String>()
    public var sourceAcquisition: String = SourceAnalysisAcquisition.NONE
    public var filesRead: ArrayList<SourceAnalysisFile> = ArrayList<SourceAnalysisFile>()
    public var citations: ArrayList<String> = ArrayList<String>()
    public var degraded: Bool = false
    public var cleanupStatus: String = "not_needed"
    public var diagnostic: String = ""

    public init() {}
}

public interface SourceFetchRunner {
    func fetch(request: SourceFetchRequest): SourceFetchResult
}

public class DisabledNetworkFetchRunner <: SourceFetchRunner {
    public init() {}

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        if (isInvalidSourceRequest(request)) {
            return invalidSourceFetchResult(request)
        }
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
    public var transportErrorClass: String = ""
    public var transportDiagnostic: String = ""
    public var curlExitCode: Int64 = 0

    public init() {}

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        if (isInvalidSourceRequest(request)) {
            return invalidSourceFetchResult(request)
        }
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
        result.contentType = if (request.accept == "text/html") {
            "text/html"
        } else if (request.kind == SourceKinds.GITCODE_SOURCE && request.sourceVariant == "raw") {
            "text/plain"
        } else {
            "application/json"
        }
        result.bytes = result.body.size
        result.bodyHash = stableSummaryHash(result.body)
        result.retryAfterSeconds = this.retryAfterSeconds
        result.attempts = 1
        result.transportErrorClass = this.transportErrorClass
        result.transportDiagnostic = this.transportDiagnostic
        result.curlExitCode = this.curlExitCode
        result
    }
}

public class CkbRuntimeConfig {
    public var networkEnabled: Bool = false
    public var gitCodeBaseUrl: String = "https://api.gitcode.com/api/v5"
    public var gitCodeAuthMode: String = "none"
    public var gitCodeAuthHeader: String = "private-token"
    public var gitCodeAccessTokenQuery: Bool = false
    public var gitCodeTokenRef: String = ""
    public var gitCodeTokenFile: String = ""
    public var websiteEnabled: Bool = false
    public var docsEnabled: Bool = false
    public var indexBackend: String = "offline"
    public var embeddingProvider: String = "deterministic"
    public var embeddingModel: String = "deterministic-token-v1"
    public var embeddingDimensions: Int64 = 16
    public var embeddingEndpoint: String = ""
    public var embeddingTokenFile: String = ""
    public var embeddingBatchSize: Int64 = 16
    public var embeddingTimeoutMillis: Int64 = 10000
    public var embeddingRetryCount: Int64 = 2
    public var embeddingAllowPrivateEndpoint: Bool = false
    public var vectorBackend: String = "local-file"
    public var vectorActiveCollection: String = "active"
    public var vectorCandidateCollection: String = "candidate"
    public var vectorEndpoint: String = ""
    public var vectorDimensions: Int64 = 16
    public var vectorDistance: String = "Cosine"
    public var vectorTimeoutMillis: Int64 = 10000
    public var vectorRetryCount: Int64 = 2
    public var vectorApiKeyFile: String = ""
    public var vectorAllowPrivateEndpoint: Bool = false
    public var timeoutMillis: Int64 = 10000
    public var retryCount: Int64 = 2
    public var networkProxy: String = ""
    public var networkEnvProxyEnabled: Bool = false
    public var networkNoProxy: String = ""
    public var networkInsecureSkipTlsVerify: Bool = false
    public var networkCaFile: String = ""
    public var networkAllowPrivateNetwork: Bool = false
    public var networkAllowedHosts: String = ""
    public var sourceAnalysisEnabled: Bool = false
    public var sourceAnalysisWorkspaceRoot: String = ""
    public var sourceAnalysisRetainFailedWorkspace: Bool = false
    public var sourceAnalysisCloneDepth: Int64 = 1
    public var sourceAnalysisTimeoutMillis: Int64 = 30000
    public var sourceAnalysisMaxFiles: Int64 = 8
    public var sourceAnalysisMaxFileBytes: Int64 = 65536
    public var sourceAnalysisCloneHostAllowlist: String = "gitcode.com"
    public var serviceBind: String = "127.0.0.1"
    public var servicePort: Int64 = 18890
    public var serviceAdminTokenFile: String = ""
    public var serviceEventIngestTokenFile: String = ""
    public var serviceMaxRequestBytes: Int64 = 1048576
    public var serviceReadOnlyPublic: Bool = true
    public var serviceDefaultBudget: Int64 = 5
    public var serviceMaxBudget: Int64 = 20
    public var schedulerEnabled: Bool = true
    public var schedulerLoopIntervalMillis: Int64 = 60000
    public var firstInitEnabled: Bool = false
    public var firstInitDocsRoot: String = ""
    public var firstInitToolDocsRoot: String = ""
    public var firstInitStdRoot: String = ""
    public var firstInitStdxRoot: String = ""
    public var firstInitEvalRoot: String = ""
    public var firstInitTargetVersion: String = cangjieDefaultTargetVersion()
    public var benchmarkGapCurationInputPath: String = ""
    public var benchmarkGapTargetVersion: String = cangjieDefaultTargetVersion()

    public init() {}

    public func tokenPresent(): Bool {
        this.gitCodeTokenRef != "" || this.gitCodeTokenFile != ""
    }

    public func gitCodeAuthSummary(): GitCodeAuthResolution {
        let auth = GitCodeAuthResolution()
        let mode = this.gitCodeAuthMode.toAsciiLower()
        if (mode == "" || mode == "none") {
            return auth
        }
        if (mode != "token" && mode != "cookie") {
            auth.state = "invalid"
            auth.status = "auth_degraded"
            auth.diagnostic = "unsupported_auth_mode"
            return auth
        }
        auth.headerStrategy = normalizedGitCodeAuthHeader(this.gitCodeAuthHeader)
        auth.accessTokenQuery = this.gitCodeAccessTokenQuery
        if (mode == "token" && auth.headerStrategy == "invalid") {
            auth.state = "invalid"
            auth.status = "auth_degraded"
            auth.diagnostic = "unsupported_auth_header_strategy"
            return auth
        }
        if (this.gitCodeTokenRef.trimAscii() != "") {
            auth.state = if (mode == "cookie") { "cookie-present" } else { "token" }
            return auth
        }
        if (this.gitCodeTokenFile != "") {
            if (exists(Path(this.gitCodeTokenFile))) {
                auth.state = if (mode == "cookie") { "cookie-present" } else { "token" }
                return auth
            }
            auth.state = if (mode == "cookie") { "cookie-missing" } else { "token-missing" }
            auth.status = "auth_degraded"
            auth.diagnostic = if (mode == "cookie") { "missing_cookie_file" } else { "missing_token_file" }
            return auth
        }
        auth.state = if (mode == "cookie") { "cookie-missing" } else { "token-missing" }
        auth.status = "auth_degraded"
        auth.diagnostic = if (mode == "cookie") { "missing_cookie" } else { "missing_token" }
        auth
    }

    public func gitCodeAuth(): GitCodeAuthResolution {
        let auth = GitCodeAuthResolution()
        let mode = this.gitCodeAuthMode.toAsciiLower()
        if (mode == "" || mode == "none") {
            return auth
        }
        if (mode != "token" && mode != "cookie") {
            auth.state = "invalid"
            auth.status = "auth_degraded"
            auth.diagnostic = "unsupported_auth_mode"
            return auth
        }
        auth.headerStrategy = normalizedGitCodeAuthHeader(this.gitCodeAuthHeader)
        auth.accessTokenQuery = this.gitCodeAccessTokenQuery
        if (mode == "token" && auth.headerStrategy == "invalid") {
            auth.state = "invalid"
            auth.status = "auth_degraded"
            auth.diagnostic = "unsupported_auth_header_strategy"
            return auth
        }
        var secret = this.gitCodeTokenRef.trimAscii()
        var fileStatus = "not_configured"
        if (secret == "" && this.gitCodeTokenFile != "") {
            let loaded = readCredentialFile(this.gitCodeTokenFile)
            secret = loaded.value
            fileStatus = loaded.status
        }
        if (secret == "") {
            auth.state = if (mode == "cookie") { "cookie-missing" } else { "token-missing" }
            auth.status = "auth_degraded"
            auth.diagnostic = if (fileStatus == "missing") {
                if (mode == "cookie") { "missing_cookie_file" } else { "missing_token_file" }
            } else if (fileStatus == "empty") {
                if (mode == "cookie") { "empty_cookie_file" } else { "empty_token_file" }
            } else if (mode == "cookie") {
                "missing_cookie"
            } else {
                "missing_token"
            }
            return auth
        }
        auth.state = if (mode == "cookie") { "cookie-present" } else { "token" }
        auth.status = "ok"
        if (mode == "cookie") {
            auth.headers.add("Cookie: ${secret}")
        } else {
            addGitCodeTokenHeaders(auth.headers, auth.headerStrategy, secret)
        }
        auth
    }

    public func redactedSummary(): String {
        let auth = this.gitCodeAuthSummary()
        var out = "network=${if (this.networkEnabled) { "enabled" } else { "disabled" }}"
        out += " gitcode.baseUrl=${redactSensitive(this.gitCodeBaseUrl)}"
        out += " gitcode.authMode=${this.gitCodeAuthMode}"
        out += " gitcode.authHeader=${normalizedGitCodeAuthHeader(this.gitCodeAuthHeader)}"
        out += " gitcode.accessTokenQuery=${if (this.gitCodeAccessTokenQuery) { "enabled" } else { "disabled" }}"
        out += " source.maxFileBytes=${SourceLimits.MAX_FILE_BYTES}"
        out += " gitcode.token=${if (this.tokenPresent()) { "present" } else { "absent" }}"
        out += " gitcode.auth=${auth.state}"
        if (auth.diagnostic != "") {
            out += " gitcode.authDiagnostic=${auth.diagnostic}"
        }
        out += " transport=native"
        out += " network.proxy=${if (this.networkProxy == "") { "absent" } else { redactProxyEndpoint(this.networkProxy) }}"
        out += " network.envProxy=${if (this.networkEnvProxyEnabled) { "enabled" } else { "disabled" }}"
        out += " network.noProxy=${if (this.networkNoProxy == "") { "absent" } else { redactSensitive(this.networkNoProxy) }}"
        out += " network.insecureSkipTlsVerify=${if (this.networkInsecureSkipTlsVerify) { "enabled" } else { "disabled" }}"
        out += " network.caFile=${if (this.networkCaFile == "") { "absent" } else { "present" }}"
        out += " network.timeoutMillis=${this.timeoutMillis}"
        out += " network.retryCount=${this.retryCount}"
        out += " sourceAnalysis.enabled=${if (this.sourceAnalysisEnabled) { "true" } else { "false" }}"
        out += " sourceAnalysis.workspaceRoot=${if (this.sourceAnalysisWorkspaceRoot == "") { sourceAnalysisDefaultWorkspaceRoot() } else { redactSensitive(this.sourceAnalysisWorkspaceRoot) }}"
        out += " sourceAnalysis.cloneDepth=${this.sourceAnalysisCloneDepth}"
        out += " sourceAnalysis.maxFiles=${this.sourceAnalysisMaxFiles}"
        out += " service.bind=${redactSensitive(this.serviceBind)}"
        out += " service.port=${this.servicePort}"
        out += " service.adminToken=${if (this.serviceAdminTokenFile == "") { "absent" } else { "present" }}"
        out += " service.eventIngestToken=${if (this.serviceEventIngestTokenFile == "") { "absent" } else { "present" }}"
        out += " service.maxRequestBytes=${this.serviceMaxRequestBytes}"
        out += " service.readOnlyPublic=${if (this.serviceReadOnlyPublic) { "true" } else { "false" }}"
        out += " service.defaultBudget=${this.serviceDefaultBudget}"
        out += " service.maxBudget=${this.serviceMaxBudget}"
        out += " scheduler.enabled=${if (this.schedulerEnabled) { "true" } else { "false" }}"
        out += " scheduler.loopIntervalMillis=${this.schedulerLoopIntervalMillis}"
        out += " firstInit.enabled=${if (this.firstInitEnabled) { "true" } else { "false" }}"
        out += " firstInit.docsRoot=${if (this.firstInitDocsRoot == "") { "absent" } else { "present" }}"
        out += " firstInit.toolDocsRoot=${if (this.firstInitToolDocsRoot == "") { "absent" } else { "present" }}"
        out += " firstInit.stdRoot=${if (this.firstInitStdRoot == "") { "absent" } else { "present" }}"
        out += " firstInit.stdxRoot=${if (this.firstInitStdxRoot == "") { "absent" } else { "present" }}"
        out += " firstInit.evalRoot=${if (this.firstInitEvalRoot == "") { "absent" } else { "present" }}"
        out += " firstInit.targetVersion=${if (this.firstInitTargetVersion == "") { "unset" } else { this.firstInitTargetVersion }}"
        out += " benchmarkGap.curationInput=${if (this.benchmarkGapCurationInputPath == "") { "absent" } else { "present" }}"
        out += " benchmarkGap.targetVersion=${if (this.benchmarkGapTargetVersion == "") { "unset" } else { this.benchmarkGapTargetVersion }}"
        out += " website=${if (this.websiteEnabled) { "enabled" } else { "disabled" }}"
        out += " docs=${if (this.docsEnabled) { "enabled" } else { "disabled" }}"
        out += " index.backend=${this.indexBackend}"
        out += " embedding.provider=${this.embeddingProvider}"
        out += " embedding.model=${if (this.embeddingModel == "") { "unset" } else { this.embeddingModel }}"
        out += " embedding.dimensions=${this.embeddingDimensions}"
        out += " embedding.endpoint=${if (this.embeddingEndpoint == "") { "absent" } else { "present" }}"
        out += " embedding.token=${if (this.embeddingTokenFile == "") { "absent" } else { "present" }}"
        out += " embedding.batchSize=${this.embeddingBatchSize}"
        out += " embedding.timeoutMillis=${this.embeddingTimeoutMillis}"
        out += " embedding.retryCount=${this.embeddingRetryCount}"
        out += " embedding.allowPrivateEndpoint=${if (this.embeddingAllowPrivateEndpoint) { "true" } else { "false" }}"
        out += " vector.backend=${this.vectorBackend}"
        out += " vector.activeCollection=${this.vectorActiveCollection}"
        out += " vector.candidateCollection=${this.vectorCandidateCollection}"
        out += " vector.endpoint=${if (this.vectorEndpoint == "") { "absent" } else { "present" }}"
        out += " vector.dimensions=${this.vectorDimensions}"
        out += " vector.distance=${this.vectorDistance}"
        out += " vector.timeoutMillis=${this.vectorTimeoutMillis}"
        out += " vector.retryCount=${this.vectorRetryCount}"
        out += " vector.apiKey=${if (this.vectorApiKeyFile == "") { "absent" } else { "present" }}"
        out += " vector.allowPrivateEndpoint=${if (this.vectorAllowPrivateEndpoint) { "true" } else { "false" }}"
        out
    }
}

public class GitCodeAuthResolution {
    public var state: String = "none"
    public var status: String = "ok"
    public var diagnostic: String = ""
    public var headers: ArrayList<String> = ArrayList<String>()
    public var headerStrategy: String = "none"
    public var accessTokenQuery: Bool = false

    public init() {}
}

public class RepoVisibility {
    public static let PUBLIC: String = "public"
    public static let PRIVATE: String = "private"
    public static let INTERNAL: String = "internal"
    public static let UNKNOWN: String = "unknown"
}

public class GitCodeRepoMetadata {
    public var org: String = ""
    public var owner: String = ""
    public var repo: String = ""
    public var fullName: String = ""
    public var defaultBranch: String = ""
    public var public: Bool = false
    public var private: Bool = false
    public var internal: Bool = false
    public var visibility: String = RepoVisibility.UNKNOWN
    public var sourceUrl: String = ""
    public var rawId: String = ""

    public init() {}
}

private class JsonStringScan {
    var ok: Bool = false
    var value: String = ""
    var end: Int64 = 0

    init() {}
}

public func deriveRepoVisibility(private: Bool, internal: Bool, public: Bool): String {
    if (private) {
        return RepoVisibility.PRIVATE
    }
    if (internal) {
        return RepoVisibility.INTERNAL
    }
    if (public) {
        return RepoVisibility.PUBLIC
    }
    RepoVisibility.UNKNOWN
}

public func isRepoAllowedForKnowledge(metadata: GitCodeRepoMetadata): Bool {
    metadata.visibility == RepoVisibility.PUBLIC
}

public func parseGitCodeRepoMetadataJson(body: String): GitCodeRepoMetadata {
    parseGitCodeRepoObject(body)
}

public func parseGitCodeOrgReposJson(body: String): ArrayList<GitCodeRepoMetadata> {
    let repos = ArrayList<GitCodeRepoMetadata>()
    let trimmed = body.trimAscii()
    if (!trimmed.startsWith("[") || !trimmed.endsWith("]")) {
        return repos
    }
    for (object in jsonObjectChunks(trimmed)) {
        let metadata = parseGitCodeRepoObject(object)
        if (metadata.fullName != "") {
            repos.add(metadata)
        }
    }
    repos
}

private func parseGitCodeRepoObject(raw: String): GitCodeRepoMetadata {
    let safeRaw = asciiJsonProjection(raw)
    let metadata = GitCodeRepoMetadata()
    let namespaceObject = jsonObjectField(safeRaw, "namespace")
    metadata.org = jsonStringField(namespaceObject, "path")
    metadata.owner = metadata.org
    metadata.repo = jsonStringField(safeRaw, "path")
    if (metadata.repo == "") {
        metadata.repo = jsonStringField(safeRaw, "name")
    }
    if (metadata.owner != "" && metadata.repo != "" && isSafeGitCodePathPart(metadata.owner) && isSafeGitCodePathPart(metadata.repo)) {
        metadata.fullName = "${metadata.owner}/${metadata.repo}"
    }
    metadata.defaultBranch = jsonStringField(safeRaw, "default_branch")
    if (metadata.defaultBranch == "") {
        metadata.defaultBranch = jsonStringField(safeRaw, "defaultBranch")
    }
    metadata.sourceUrl = firstNonEmptyJsonString(safeRaw, ["web_url", "html_url", "sourceUrl", "url"])
    metadata.rawId = jsonScalarField(safeRaw, "id")
    let visibilityText = normalizeRepoVisibility(jsonStringField(safeRaw, "visibility"))
    metadata.private = jsonBoolField(safeRaw, "private") || visibilityText == RepoVisibility.PRIVATE
    metadata.internal = jsonBoolField(safeRaw, "internal") || visibilityText == RepoVisibility.INTERNAL
    metadata.public = jsonBoolField(safeRaw, "public") || visibilityText == RepoVisibility.PUBLIC
    metadata.visibility = deriveRepoVisibility(metadata.private, metadata.internal, metadata.public)
    metadata
}

private func asciiJsonProjection(raw: String): String {
    let out = StringBuilder()
    for (ch in raw.toRuneArray()) {
        if (UInt32(ch) <= 0x7Fu32) {
            out.append(ch)
        } else {
            out.append(r' ')
        }
    }
    out.toString()
}

public func utf8SafePrefix(raw: String, maxBytes: Int64): String {
    if (maxBytes <= 0) {
        return ""
    }
    if (raw.size <= maxBytes) {
        return raw
    }
    let out = StringBuilder()
    var used: Int64 = 0
    for (ch in raw.toRuneArray()) {
        let piece = "${ch}"
        let next = used + piece.size
        if (next > maxBytes) {
            break
        }
        out.append(ch)
        used = next
    }
    out.toString()
}

private func normalizeRepoVisibility(raw: String): String {
    let value = raw.trimAscii().toAsciiLower()
    if (value == RepoVisibility.PUBLIC || value == RepoVisibility.PRIVATE || value == RepoVisibility.INTERNAL) {
        return value
    }
    RepoVisibility.UNKNOWN
}

private func firstNonEmptyJsonString(raw: String, keys: Array<String>): String {
    for (key in keys) {
        let value = jsonStringField(raw, key)
        if (value != "") {
            return value
        }
    }
    ""
}

private func jsonStringField(raw: String, key: String): String {
    let start = jsonTopLevelValueStart(raw, key)
    if (start < 0 || start >= raw.size || raw[start..start + 1] != "\"") {
        return ""
    }
    let scan = readJsonStringAt(raw, start)
    if (scan.ok) {
        return scan.value
    }
    ""
}

private func jsonObjectField(raw: String, key: String): String {
    let start = jsonTopLevelValueStart(raw, key)
    if (start < 0 || start >= raw.size || raw[start..start + 1] != "{") {
        return ""
    }
    var i = start
    var inString = false
    var escaped = false
    var depth: Int64 = 0
    while (i < raw.size) {
        let ch = raw[i..i + 1]
        if (inString) {
            if (escaped) {
                escaped = false
            } else if (ch == "\\") {
                escaped = true
            } else if (ch == "\"") {
                inString = false
            }
        } else if (ch == "\"") {
            inString = true
        } else if (ch == "{") {
            depth += 1
        } else if (ch == "}") {
            depth -= 1
            if (depth == 0) {
                return raw[start..i + 1]
            }
        }
        i += 1
    }
    ""
}

private func jsonBoolField(raw: String, key: String): Bool {
    let start = jsonTopLevelValueStart(raw, key)
    if (start < 0) {
        return false
    }
    raw[start..raw.size].startsWith("true")
}

private func jsonScalarField(raw: String, key: String): String {
    let start = jsonTopLevelValueStart(raw, key)
    if (start < 0 || start >= raw.size) {
        return ""
    }
    if (raw[start..start + 1] == "\"") {
        return jsonStringField(raw, key)
    }
    var end = start
    while (end < raw.size) {
        let ch = raw[end..end + 1]
        if (ch == "," || ch == "}" || ch == "]" || ch == "\n" || ch == "\r" || ch == " " || ch == "\t") {
            break
        }
        end += 1
    }
    raw[start..end].trimAscii()
}

private func jsonTopLevelValueStart(raw: String, key: String): Int64 {
    var i: Int64 = 0
    var depth: Int64 = 0
    var inString = false
    var escaped = false
    while (i < raw.size) {
        let ch = raw[i..i + 1]
        if (inString) {
            if (escaped) {
                escaped = false
            } else if (ch == "\\") {
                escaped = true
            } else if (ch == "\"") {
                inString = false
            }
            i += 1
            continue
        }
        if (ch == "\"") {
            if (depth == 1) {
                let scan = readJsonStringAt(raw, i)
                if (scan.ok && scan.value == key) {
                    var colon = skipJsonWhitespace(raw, scan.end)
                    if (colon < raw.size && raw[colon..colon + 1] == ":") {
                        return skipJsonWhitespace(raw, colon + 1)
                    }
                }
                i = if (scan.ok) { scan.end } else { i + 1 }
                continue
            }
            inString = true
        } else if (ch == "{" || ch == "[") {
            depth += 1
        } else if (ch == "}" || ch == "]") {
            depth -= 1
        }
        i += 1
    }
    -1
}

private func readJsonStringAt(raw: String, start: Int64): JsonStringScan {
    let scan = JsonStringScan()
    if (start < 0 || start >= raw.size || raw[start..start + 1] != "\"") {
        return scan
    }
    var i = start + 1
    var escaped = false
    var value = ""
    while (i < raw.size) {
        let ch = raw[i..i + 1]
        if (escaped) {
            value += jsonUnescapeChar(ch)
            escaped = false
        } else if (ch == "\\") {
            escaped = true
        } else if (ch == "\"") {
            scan.ok = true
            scan.value = value
            scan.end = i + 1
            return scan
        } else {
            value += ch
        }
        i += 1
    }
    scan
}

private func jsonUnescapeChar(ch: String): String {
    if (ch == "\"") {
        return "\""
    }
    if (ch == "\\") {
        return "\\"
    }
    if (ch == "/") {
        return "/"
    }
    if (ch == "n") {
        return "\n"
    }
    if (ch == "r") {
        return "\r"
    }
    if (ch == "t") {
        return "\t"
    }
    ch
}

private func skipJsonWhitespace(raw: String, start: Int64): Int64 {
    var i = start
    while (i < raw.size) {
        let ch = raw[i..i + 1]
        if (ch != " " && ch != "\n" && ch != "\r" && ch != "\t") {
            break
        }
        i += 1
    }
    i
}

private class CredentialFileRead {
    var status: String = "not_configured"
    var value: String = ""

    init() {}
}

private func normalizedGitCodeAuthHeader(raw: String): String {
    let value = raw.trimAscii().toAsciiLower()
    if (value == "" || value == "private-token") {
        return "private-token"
    }
    if (value == "authorization" || value == "both") {
        return value
    }
    "invalid"
}

private func addGitCodeTokenHeaders(headers: ArrayList<String>, strategy: String, secret: String): Unit {
    if (strategy == "authorization") {
        headers.add("Authorization: Bearer ${secret}")
    } else if (strategy == "both") {
        headers.add("PRIVATE-TOKEN: ${secret}")
        headers.add("Authorization: Bearer ${secret}")
    } else {
        headers.add("PRIVATE-TOKEN: ${secret}")
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

private func readCredentialFile(path: String): CredentialFileRead {
    let result = CredentialFileRead()
    if (path == "" || !exists(Path(path))) {
        result.status = "missing"
        return result
    }
    try {
        let text = String.fromUtf8(File.readFrom(Path(path))).trimAscii()
        result.value = firstCredentialLine(text)
        result.status = if (result.value == "") { "empty" } else { "ok" }
    } catch (_: Exception) {
        result.status = "missing"
    }
    result
}

private func firstCredentialLine(text: String): String {
    for (line in text.split("\n")) {
        let trimmed = line.trimAscii()
        if (trimmed != "") {
            return trimmed
        }
    }
    ""
}

public func redactSensitive(raw: String): String {
    var text = raw
    text = redactQueryParam(text, "access_token")
    text = redactQueryParam(text, "token")
    text = redactAssignment(text, "PRIVATE-TOKEN")
    text = redactAssignment(text, "private-token")
    text = redactAssignment(text, "Authorization")
    text = redactAssignment(text, "authorization")
    text = redactAssignment(text, "Cookie")
    text = redactAssignment(text, "cookie")
    text = redactAssignment(text, "token")
    text = redactAssignment(text, "access_token")
    text = redactAfterNeedle(text, "Bearer ")
    text = redactAfterNeedle(text, "bearer ")
    text = redactProxyCredentials(text)
    text = redactAbsolutePath(text)
    text
}

public func redactProxyEndpoint(raw: String): String {
    var text = redactSensitive(raw.trimAscii())
    let schemeIdx = findText(text, "://")
    if (schemeIdx < 0) {
        return text
    }
    let authorityStart = schemeIdx + 3
    let rest = text[authorityStart..text.size]
    let slashIdx = findText(rest, "/")
    let authorityEnd = if (slashIdx < 0) { text.size } else { authorityStart + slashIdx }
    let authority = text[authorityStart..authorityEnd]
    let atIdx = findText(authority, "@")
    if (atIdx < 0) {
        return text
    }
    text[0..authorityStart] + "[redacted]@" + text[authorityStart + atIdx + 1..text.size]
}

private func sanitizedTransportDiagnostic(raw: String): String {
    var text = redactSensitive(raw).replace("\n", " ").replace("\r", " ").trimAscii()
    if (text.size > 160) {
        text = utf8SafePrefix(text, 160)
    }
    text
}

public class HttpExecutionRequest {
    public var method: String = "GET"
    public var url: String = ""
    public var accept: String = "application/json"
    public var body: String = ""
    public var contentType: String = ""
    public var headers: ArrayList<String> = ArrayList<String>()
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
    public var transportErrorClass: String = ""
    public var transportDiagnostic: String = ""
    public var curlExitCode: Int64 = 0

    public init() {}
}

public class CurlTransportDiagnostic {
    public var transportErrorClass: String = "unknown_transport"
    public var transportDiagnostic: String = ""
    public var curlExitCode: Int64 = 0

    public init() {}
}

public func diagnoseCurlTransportError(curlExitCode: Int64, stderr: String): CurlTransportDiagnostic {
    let diagnostic = CurlTransportDiagnostic()
    diagnostic.curlExitCode = curlExitCode
    diagnostic.transportDiagnostic = sanitizedTransportDiagnostic(stderr)
    let lowered = stderr.toAsciiLower()
    if (curlExitCode == 28 || lowered.contains("timed out") || lowered.contains("timeout")) {
        diagnostic.transportErrorClass = "timeout"
    } else if (curlExitCode == 6 || lowered.contains("could not resolve host") || lowered.contains("name lookup") || lowered.contains("resolve host")) {
        diagnostic.transportErrorClass = "dns"
    } else if (curlExitCode == 35 || curlExitCode == 51 || curlExitCode == 58 || curlExitCode == 60 || lowered.contains("ssl") || lowered.contains("tls") || lowered.contains("certificate")) {
        diagnostic.transportErrorClass = "tls"
    } else if (curlExitCode == 5 || lowered.contains("proxy")) {
        diagnostic.transportErrorClass = "proxy"
    } else if (curlExitCode == 7 || lowered.contains("connection refused") || lowered.contains("failed to connect")) {
        diagnostic.transportErrorClass = "connection_refused"
    } else if (curlExitCode != 0) {
        diagnostic.transportErrorClass = "curl_exit"
    } else {
        diagnostic.transportErrorClass = "unknown_transport"
    }
    if (diagnostic.transportDiagnostic == "") {
        diagnostic.transportDiagnostic = diagnostic.transportErrorClass
    }
    diagnostic
}

public interface HttpRequestExecutor {
    func execute(request: HttpExecutionRequest): HttpExecutionResponse
    func get(request: HttpExecutionRequest): HttpExecutionResponse
}

public func normalizeHttpExecutionMethod(method: String): String {
    let normalized = method.trimAscii().toAsciiUpper()
    if (normalized == "") {
        return "GET"
    }
    normalized
}

public func httpExecutionMethodSupported(method: String): Bool {
    let normalized = normalizeHttpExecutionMethod(method)
    normalized == "GET" || normalized == "POST" || normalized == "PUT" || normalized == "DELETE"
}

public func unsupportedHttpExecutionResponse(method: String): HttpExecutionResponse {
    let response = HttpExecutionResponse()
    response.status = "unsupported_method"
    response.transportErrorClass = "unsupported_method"
    response.transportDiagnostic = "unsupported HTTP method: ${redactSensitive(normalizeHttpExecutionMethod(method))}"
    response
}

private func copyHttpExecutionRequest(request: HttpExecutionRequest): HttpExecutionRequest {
    let copied = HttpExecutionRequest()
    copied.method = request.method
    copied.url = request.url
    copied.accept = request.accept
    copied.body = request.body
    copied.contentType = request.contentType
    copied.timeoutMillis = request.timeoutMillis
    copied.retryCount = request.retryCount
    for (header in request.headers) {
        copied.headers.add(header)
    }
    copied
}

private func curlRequestArgs(request: HttpExecutionRequest, timeoutSeconds: String): Array<String> {
    let args = ArrayList<String>()
    let method = normalizeHttpExecutionMethod(request.method)
    args.add("-sS")
    args.add("-L")
    args.add("--max-time")
    args.add(timeoutSeconds)
    if (method != "GET") {
        args.add("-X")
        args.add(method)
    }
    args.add("-H")
    args.add("Accept: ${request.accept}")
    if (request.contentType.trimAscii() != "") {
        args.add("-H")
        args.add("Content-Type: ${request.contentType.trimAscii()}")
    }
    for (header in request.headers) {
        args.add("-H")
        args.add(header)
    }
    if (request.body != "") {
        args.add("--data-binary")
        args.add(request.body)
    }
    args.add("-w")
    args.add("\nCKB_HTTP_STATUS:%{http_code}\nCKB_CONTENT_TYPE:%{content_type}\n")
    args.add(request.url)
    args.toArray()
}

public class CurlHttpRequestExecutor <: HttpRequestExecutor {
    public init() {}

    public func execute(request: HttpExecutionRequest): HttpExecutionResponse {
        if (!httpExecutionMethodSupported(request.method)) {
            return unsupportedHttpExecutionResponse(request.method)
        }
        let response = HttpExecutionResponse()
        let timeoutSeconds = if (request.timeoutMillis <= 0) { "10" } else { "${(request.timeoutMillis + 999) / 1000}" }
        let args = curlRequestArgs(request, timeoutSeconds)
        try {
            let process = launch("curl", args, stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
            let out = StringReader<InputStream>(process.stdOutPipe).readToEnd()
            let err = StringReader<InputStream>(process.stdErrPipe).readToEnd()
            let code = process.wait()
            response.body = stripCurlTrailer(out)
            response.statusCode = parseCurlStatus(out)
            response.contentType = parseCurlContentType(out)
            response.status = if (code == 0) { "http_${response.statusCode}" } else { "transport_error" }
            if (code != 0) {
                let diagnostic = diagnoseCurlTransportError(code, err)
                response.transportErrorClass = diagnostic.transportErrorClass
                response.transportDiagnostic = diagnostic.transportDiagnostic
                response.curlExitCode = diagnostic.curlExitCode
                if (diagnostic.transportErrorClass == "timeout") {
                    response.status = "timeout"
                }
            }
        } catch (_: Exception) {
            let diagnostic = diagnoseCurlTransportError(-1, "curl launch failed")
            response.status = "transport_error"
            response.transportErrorClass = diagnostic.transportErrorClass
            response.transportDiagnostic = diagnostic.transportDiagnostic
            response.curlExitCode = diagnostic.curlExitCode
        }
        response
    }

    public func get(request: HttpExecutionRequest): HttpExecutionResponse {
        let getRequest = copyHttpExecutionRequest(request)
        getRequest.method = "GET"
        this.execute(getRequest)
    }
}

public class HttpSourceFetchRunner <: SourceFetchRunner {
    private let config: CkbRuntimeConfig
    private let executor: HttpRequestExecutor

    public init(config: CkbRuntimeConfig) {
        this.config = config
        this.executor = NativeHttpRequestExecutor(config)
    }

    public init(config: CkbRuntimeConfig, executor!: HttpRequestExecutor) {
        this.config = config
        this.executor = executor
    }

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        let result = SourceFetchResult()
        result.sourceUrl = request.url
        result.normalizedType = request.kind
        if (isInvalidSourceRequest(request)) {
            return invalidSourceFetchResult(request)
        }
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
        let auth = authHeaderForRequest(this.config, request)
        if (auth.status != "ok") {
            result.status = auth.status
            result.body = auth.diagnostic
            result.bodyHash = stableSummaryHash(auth.diagnostic)
            return result
        }
        for (header in auth.headers) {
            http.headers.add(header)
        }
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
        result.transportErrorClass = last.transportErrorClass
        result.transportDiagnostic = last.transportDiagnostic
        result.curlExitCode = last.curlExitCode
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

    public init(gitCodeApiRoot!: String = "https://api.gitcode.com/api/v5") {
        this.gitCodeApiRoot = gitCodeApiRoot
    }

    public func gitCodeOrgRepos(org: String, page!: Int64 = 1): SourceFetchRequest {
        let request = SourceFetchRequest(SourceKinds.GITCODE_ORG, "${this.gitCodeApiRoot}/orgs/${org}/repos?type=public&page=${page}&per_page=100", repo: org, purpose: "enumerate_public_repos")
        request.authHint = "gitcode-token-optional-redacted"
        request.paginationParam = "page"
        request.perPageParam = "per_page"
        request.page = page
        request
    }

    public func gitCodeRepo(repo: String, ref!: String = "main"): SourceFetchRequest {
        let parts = parseGitCodeRepoPath(repo)
        if (!parts.valid) {
            return invalidSourceFetchRequest(SourceKinds.GITCODE_REPO, "repo_metadata", parts.diagnostic)
        }
        if (!isSafeGitCodeRef(ref)) {
            return invalidSourceFetchRequest(SourceKinds.GITCODE_REPO, "repo_metadata", "invalid_ref")
        }
        let normalizedRepo = "${parts.owner}/${parts.repo}"
        let request = SourceFetchRequest(SourceKinds.GITCODE_REPO, "${this.gitCodeApiRoot}/repos/${parts.owner}/${parts.repo}?ref=${ref}", repo: normalizedRepo, ref: ref, purpose: "repo_metadata")
        request.authHint = "gitcode-token-optional-redacted"
        request
    }

    public func gitCodeSource(repo: String, ref: String, path: String): SourceFetchRequest {
        this.gitCodeSourceRaw(repo, ref, path)
    }

    public func gitCodeSourceRaw(repo: String, ref: String, path: String): SourceFetchRequest {
        this.gitCodeSourceVariant(repo, ref, path, "raw")
    }

    public func gitCodeSourceContents(repo: String, ref: String, path: String): SourceFetchRequest {
        this.gitCodeSourceVariant(repo, ref, path, "contents")
    }

    private func gitCodeSourceVariant(repo: String, ref: String, path: String, variant: String): SourceFetchRequest {
        let parts = parseGitCodeRepoPath(repo)
        let purpose = if (variant == "contents") { "source_contents_snapshot" } else { "source_raw_snapshot" }
        if (!parts.valid) {
            return invalidSourceFetchRequest(SourceKinds.GITCODE_SOURCE, purpose, parts.diagnostic)
        }
        if (!isSafeGitCodeRef(ref)) {
            return invalidSourceFetchRequest(SourceKinds.GITCODE_SOURCE, purpose, "invalid_ref")
        }
        let safePath = normalizeGitCodeSourcePath(path)
        if (safePath == "") {
            return invalidSourceFetchRequest(SourceKinds.GITCODE_SOURCE, purpose, "invalid_source_path")
        }
        let normalizedRepo = "${parts.owner}/${parts.repo}"
        let endpoint = if (variant == "contents") { "contents" } else { "raw" }
        let accept = if (variant == "contents") { "application/json" } else { "text/plain, text/markdown, application/octet-stream" }
        let request = SourceFetchRequest(SourceKinds.GITCODE_SOURCE, "${this.gitCodeApiRoot}/repos/${parts.owner}/${parts.repo}/${endpoint}/${safePath}?ref=${ref}", repo: normalizedRepo, ref: ref, path: safePath, accept: accept, purpose: purpose)
        request.authHint = "gitcode-token-optional-redacted"
        request.sourceVariant = variant
        request
    }

    public func gitCodeTree(repo: String, ref: String): SourceFetchRequest {
        let parts = parseGitCodeRepoPath(repo)
        if (!parts.valid) {
            return invalidSourceFetchRequest(SourceKinds.GITCODE_TREE, "source_tree", parts.diagnostic)
        }
        if (!isSafeGitCodeRef(ref)) {
            return invalidSourceFetchRequest(SourceKinds.GITCODE_TREE, "source_tree", "invalid_ref")
        }
        let normalizedRepo = "${parts.owner}/${parts.repo}"
        let request = SourceFetchRequest(SourceKinds.GITCODE_TREE, "${this.gitCodeApiRoot}/repos/${parts.owner}/${parts.repo}/git/trees/${ref}?recursive=1&page=1&per_page=100", repo: normalizedRepo, ref: ref, purpose: "source_tree")
        request.authHint = "gitcode-token-optional-redacted"
        request
    }

    public func gitCodeIssueHistory(repo: String): SourceFetchRequest {
        let parts = parseGitCodeRepoPath(repo)
        if (!parts.valid) {
            return invalidSourceFetchRequest(SourceKinds.GITCODE_ISSUE_HISTORY, "issue_history", parts.diagnostic)
        }
        let normalizedRepo = "${parts.owner}/${parts.repo}"
        let request = SourceFetchRequest(SourceKinds.GITCODE_ISSUE_HISTORY, "${this.gitCodeApiRoot}/repos/${parts.owner}/${parts.repo}/issues?state=all&page=1&per_page=100", repo: normalizedRepo, purpose: "issue_history")
        request.authHint = "gitcode-token-optional-redacted"
        request
    }

    public func gitCodePrHistory(repo: String): SourceFetchRequest {
        let parts = parseGitCodeRepoPath(repo)
        if (!parts.valid) {
            return invalidSourceFetchRequest(SourceKinds.GITCODE_PR_HISTORY, "pr_history", parts.diagnostic)
        }
        let normalizedRepo = "${parts.owner}/${parts.repo}"
        let request = SourceFetchRequest(SourceKinds.GITCODE_PR_HISTORY, "${this.gitCodeApiRoot}/repos/${parts.owner}/${parts.repo}/pulls?state=all&page=1&per_page=100", repo: normalizedRepo, purpose: "pr_history")
        request.authHint = "gitcode-token-optional-redacted"
        request
    }

    public func gitCodeCommentHistory(repo: String): SourceFetchRequest {
        let parts = parseGitCodeRepoPath(repo)
        if (!parts.valid) {
            return invalidSourceFetchRequest(SourceKinds.GITCODE_COMMENT_HISTORY, "comment_history", parts.diagnostic)
        }
        let normalizedRepo = "${parts.owner}/${parts.repo}"
        let request = SourceFetchRequest(SourceKinds.GITCODE_COMMENT_HISTORY, "${this.gitCodeApiRoot}/repos/${parts.owner}/${parts.repo}/issues/comments?page=1&per_page=100", repo: normalizedRepo, purpose: "comment_history")
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

private class GitCodeRepoParts {
    var valid: Bool = false
    var owner: String = ""
    var repo: String = ""
    var diagnostic: String = "invalid_repo_path"

    init() {}
}

private func parseGitCodeRepoPath(raw: String): GitCodeRepoParts {
    let parts = GitCodeRepoParts()
    let values = raw.trimAscii().split("/")
    if (values.size != 2) {
        return parts
    }
    let owner = values[0].trimAscii()
    let repo = values[1].trimAscii()
    if (!isSafeGitCodePathPart(owner) || !isSafeGitCodePathPart(repo)) {
        return parts
    }
    parts.valid = true
    parts.owner = owner
    parts.repo = repo
    parts.diagnostic = ""
    parts
}

private func isSafeGitCodePathPart(part: String): Bool {
    if (part == "" || part == "." || part == "..") {
        return false
    }
    if (part.contains("\\") || part.contains("..") || part.contains("%") || part.contains("?") || part.contains("#") || part.contains("&") || part.contains("=") || part.contains(":") || part.contains(" ") || part.contains("\n") || part.contains("\r") || part.contains("\t")) {
        return false
    }
    true
}

private func isSafeGitCodeRef(ref: String): Bool {
    let trimmed = ref.trimAscii()
    if (trimmed == "" || trimmed.contains("..") || trimmed.contains("%") || trimmed.contains("?") || trimmed.contains("#") || trimmed.contains("&") || trimmed.contains("=") || trimmed.contains("\n") || trimmed.contains("\r") || trimmed.contains("\t")) {
        return false
    }
    true
}

private func normalizeGitCodeSourcePath(raw: String): String {
    let trimmed = raw.trimAscii()
    if (trimmed == "" || trimmed.startsWith("/") || trimmed.contains("\\") || trimmed.contains("%") || trimmed.contains("?") || trimmed.contains("#") || trimmed.contains("&") || trimmed.contains("=") || trimmed.contains(":") || trimmed.contains("\n") || trimmed.contains("\r") || trimmed.contains("\t")) {
        return ""
    }
    let parts = trimmed.split("/")
    for (part in parts) {
        if (part == "" || part == "." || part == "..") {
            return ""
        }
    }
    trimmed
}

private func jsonObjectChunks(body: String): ArrayList<String> {
    let objects = ArrayList<String>()
    var depth: Int64 = 0
    var current = StringBuilder()
    var inString = false
    var escaped = false
    for (ch in body.toRuneArray()) {
        if (inString) {
            if (escaped) {
                escaped = false
            } else if (ch == r'\\') {
                escaped = true
            } else if (ch == r'"') {
                inString = false
            }
        } else if (ch == r'"') {
            inString = true
        } else if (ch == r'{') {
            if (depth == 0) {
                current = StringBuilder()
            }
            depth += 1
        }
        if (depth > 0) {
            current.append(ch)
        }
        if (!inString && ch == r'}') {
            depth -= 1
            if (depth == 0) {
                objects.add(current.toString())
            }
        }
    }
    objects
}

private func nestedJsonObjectChunks(body: String): ArrayList<String> {
    let objects = ArrayList<String>()
    let chunks = ArrayList<StringBuilder>()
    var inString = false
    var escaped = false
    for (ch in body.toRuneArray()) {
        if (inString) {
            if (escaped) {
                escaped = false
            } else if (ch == r'\\') {
                escaped = true
            } else if (ch == r'"') {
                inString = false
            }
        } else if (ch == r'"') {
            inString = true
        }
        for (idx in 0..chunks.size) {
            chunks[idx].append(ch)
        }
        if (!inString && ch == r'{') {
            let chunk = StringBuilder()
            chunk.append(ch)
            chunks.add(chunk)
        } else if (!inString && ch == r'}' && chunks.size > 0) {
            let complete = chunks[chunks.size - 1]
            chunks.remove(at: chunks.size - 1)
            objects.add(complete.toString())
        }
    }
    objects
}

private func addUniqueString(out: ArrayList<String>, value: String): Unit {
    for (item in out) {
        if (item == value) {
            return
        }
    }
    out.add(value)
}

private func excludedSourceCandidate(path: String): Bool {
    let lower = path.toAsciiLower()
    lower.startsWith("target/") || lower.contains("/target/") || lower.startsWith("build/") || lower.contains("/build/") || lower.startsWith("vendor/") || lower.contains("/vendor/") || lower.startsWith("binary/") || lower.contains("/binary/") || lower.endsWith(".png") || lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.endsWith(".gif") || lower.endsWith(".zip") || lower.endsWith(".tar") || lower.endsWith(".gz") || lower.endsWith(".so") || lower.endsWith(".dylib") || lower.endsWith(".a") || lower.endsWith(".o") || lower.endsWith(".jar") || lower.endsWith(".class")
}

private func isReadmeOrDocsMarkdown(lower: String): Bool {
    if (!(lower.endsWith(".md") || lower.endsWith(".markdown"))) {
        return false
    }
    lower == "readme.md" || lower.endsWith("/readme.md") || lower.startsWith("docs/") || lower.contains("/docs/") || lower.startsWith("doc/") || lower.contains("/doc/")
}

private func invalidSourceFetchRequest(kind: String, purpose: String, diagnostic: String): SourceFetchRequest {
    let request = SourceFetchRequest(kind, "", purpose: purpose)
    request.status = diagnostic
    request.diagnostic = diagnostic
    request
}

private func isInvalidSourceRequest(request: SourceFetchRequest): Bool {
    request.diagnostic != ""
}

private func invalidSourceFetchResult(request: SourceFetchRequest): SourceFetchResult {
    let result = SourceFetchResult()
    result.ok = false
    result.status = request.diagnostic
    result.sourceUrl = ""
    result.normalizedType = request.kind
    result.body = request.diagnostic
    result.bodyHash = stableSummaryHash(result.body)
    result
}

public class SourceResponseNormalizer {
    public init() {}

    public func normalize(request: SourceFetchRequest, result: SourceFetchResult): SourceFetchResult {
        if (isInvalidSourceRequest(request)) {
            return invalidSourceFetchResult(request)
        }
        result.sourceUrl = if (result.sourceUrl == "") { request.url } else { result.sourceUrl }
        result.normalizedType = request.kind
        result.repo = if (result.repo == "") { request.repo } else { result.repo }
        result.ref = if (result.ref == "") { request.ref } else { result.ref }
        result.path = if (result.path == "") { request.path } else { result.path }
        result.repoVisibility = if (result.repoVisibility == "") { request.repoVisibility } else { result.repoVisibility }
        if (result.statusCode == 0 && result.ok) {
            result.statusCode = 200
        }
        if (result.statusCode >= 200 && result.statusCode < 300) {
            result.ok = true
            result.status = "ok"
        } else if (result.status == "not_started") {
            result.status = "http_${result.statusCode}"
        }
        if (request.kind == SourceKinds.GITCODE_SOURCE && request.sourceVariant == "raw" && result.ok) {
            if (result.body.size > SourceLimits.MAX_FILE_BYTES) {
                result.ok = false
                result.status = "source_too_large"
                result.truncated = true
                result.body = ""
            } else if (!isSupportedRawSourceBody(result.contentType, result.body)) {
                result.ok = false
                result.status = "unsupported_binary"
                result.body = ""
            }
        } else if (result.body.size > 200000) {
            result.truncated = true
            result.body = utf8SafePrefix(result.body, 200000)
        }
        if (result.ok && request.kind == SourceKinds.GITCODE_SOURCE && request.purpose == "source_contents_snapshot") {
            let parsed = parseGitCodeContentsFile(result.body, request.path)
            if (!parsed.ok) {
                result.ok = false
                result.status = parsed.status
                result.body = parsed.status
            } else {
                result.body = parsed.body
                result.path = request.path
                result.commit = parsed.sha
                result.bodyHash = stableSummaryHash(result.body)
                if (parsed.htmlUrl != "") {
                    result.sourceUrl = parsed.htmlUrl
                } else if (parsed.downloadUrl != "") {
                    result.sourceUrl = parsed.downloadUrl
                }
            }
        }
        result.bytes = result.body.size
        result.bodyHash = stableSummaryHash(result.body)
        result
    }
}

private func isSupportedRawSourceBody(contentType: String, body: String): Bool {
    for (ch in body.runes()) {
        if (UInt32(ch) == 0) {
            return false
        }
    }
    let normalized = contentType.toAsciiLower().replace(" ", "")
    if (normalized == "" || normalized.startsWith("text/plain") || normalized.startsWith("text/markdown")) {
        return true
    }
    normalized.startsWith("application/octet-stream") && normalized.contains("charset=utf-8")
}

public class SourceAnalysisPack {
    public var ok: Bool = false
    public var status: String = "not_started"
    public var diagnostic: String = ""
    public var repo: String = ""
    public var ref: String = ""
    public var commit: String = ""
    public var runId: String = ""
    public var cleanupStatus: String = "not_started"
    public var workspaceStatus: String = "redacted"
    public var selectedFiles: ArrayList<SourceAnalysisFile> = ArrayList<SourceAnalysisFile>()
    public var citations: ArrayList<String> = ArrayList<String>()
    public var degraded: ArrayList<String> = ArrayList<String>()
    public var truncated: Bool = false

    public init() {}
}

public class SourceCloneWorkspace {
    public var ok: Bool = false
    public var status: String = "not_started"
    public var diagnostic: String = ""
    public var root: String = ""
    public var runId: String = ""
    public var runDir: Path = Path("")
    public var checkoutPath: Path = Path("")
    public var checkoutDisplay: String = "redacted"
    public var cleanupStatus: String = "not_started"

    public init() {}
}

public class CloneExecutionRequest {
    public var repo: String = ""
    public var ref: String = "main"
    public var cloneUrl: String = ""
    public var checkoutPath: String = ""
    public var depth: Int64 = 1
    public var timeoutMillis: Int64 = 30000

    public init() {}
}

public class CloneExecutionResult {
    public var ok: Bool = false
    public var status: String = "not_started"
    public var diagnostic: String = ""
    public var commandSummary: String = ""

    public init() {}
}

public interface SourceCloneExecutor {
    func clone(request: CloneExecutionRequest): CloneExecutionResult
}

private var sourceAnalysisRunCounter: Int64 = 0

public class GitSourceCloneExecutor <: SourceCloneExecutor {
    public init() {}

    public func clone(request: CloneExecutionRequest): CloneExecutionResult {
        let result = CloneExecutionResult()
        result.commandSummary = "git clone --depth ${request.depth} --branch ${request.ref} [clone-url-redacted] [checkout-path-redacted]"
        try {
            let seconds = if (request.timeoutMillis <= 0) { 30 } else { (request.timeoutMillis + 999) / 1000 }
            let script = "git clone --depth " + ckbLocalShellQuote("${request.depth}") +
                " --branch " + ckbLocalShellQuote(request.ref) +
                " " + ckbLocalShellQuote(request.cloneUrl) +
                " " + ckbLocalShellQuote(request.checkoutPath) +
                " & pid=$!; " +
                "( sleep " + ckbLocalShellQuote("${seconds}") + "; if kill -0 $pid 2>/dev/null; then echo CKB_CLONE_TIMEOUT >&2; kill -TERM $pid 2>/dev/null; fi ) & timer=$!; " +
                "wait $pid; code=$?; kill $timer 2>/dev/null; exit $code"
            let process = launch("/bin/zsh", ["-lc", script], stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
            let err = StringReader<InputStream>(process.stdErrPipe).readToEnd()
            let code = process.wait()
            if (code == 0) {
                result.ok = true
                result.status = "ok"
                return result
            }
            let lowered = err.toAsciiLower()
            result.status = if (lowered.contains("authentication") || lowered.contains("permission denied")) {
                "clone_auth_failed"
            } else if (lowered.contains("ckb_clone_timeout") || lowered.contains("timeout") || lowered.contains("timed out")) {
                "clone_timeout"
            } else if (lowered.contains("command not found") || lowered.contains("no such file or directory")) {
                "git_unavailable"
            } else if (lowered.contains("not found") || lowered.contains("repository not found")) {
                "clone_not_found"
            } else {
                "clone_failed"
            }
            result.diagnostic = sanitizedTransportDiagnostic(err)
        } catch (_: Exception) {
            result.status = "git_unavailable"
            result.diagnostic = "git launch failed"
        }
        result
    }
}

private func ckbLocalShellQuote(value: String): String {
    "'" + value.replace("'", "'\\''") + "'"
}

public class SourceCloneWorkspaceManager {
    private let config: CkbRuntimeConfig

    public init(config: CkbRuntimeConfig) {
        this.config = config
    }

    public func prepare(repo: String): SourceCloneWorkspace {
        let ws = SourceCloneWorkspace()
        let root = effectiveSourceAnalysisWorkspaceRoot(this.config)
        ws.root = root
        let invalid = validateSourceAnalysisWorkspaceRoot(root)
        if (invalid != "") {
            ws.status = invalid
            ws.diagnostic = invalid
            return ws
        }
        let parts = parseGitCodeRepoPath(repo)
        if (!parts.valid) {
            ws.status = parts.diagnostic
            ws.diagnostic = parts.diagnostic
            return ws
        }
        sourceAnalysisRunCounter += 1
        ws.runId = "run-${sourceAnalysisRunCounter}-${stableSummaryHash(repo)}"
        ws.runDir = Path(root).join(ws.runId)
        ws.checkoutPath = ws.runDir.join(safeSourceAnalysisRepoDir(parts.owner, parts.repo))
        ws.checkoutDisplay = "[workspace-redacted]/${ws.runId}/${safeSourceAnalysisRepoDir(parts.owner, parts.repo)}"
        try {
            Directory.create(ws.checkoutPath.parent, recursive: true)
            let _ = launch("chmod", ["700", ws.runDir.toString()]).wait()
            ws.ok = true
            ws.status = "ready"
        } catch (_: Exception) {
            ws.status = "workspace_create_failed"
            ws.diagnostic = "workspace_create_failed"
        }
        ws
    }

    public func cleanup(workspace: SourceCloneWorkspace, retain: Bool): String {
        if (workspace.runId == "" || workspace.runDir.toString() == "") {
            workspace.cleanupStatus = "not_created"
            return workspace.cleanupStatus
        }
        if (retain) {
            workspace.cleanupStatus = "retained_by_config"
            return workspace.cleanupStatus
        }
        try {
            let code = launch("rm", ["-rf", workspace.runDir.toString()]).wait()
            workspace.cleanupStatus = if (code == 0 || !exists(workspace.runDir)) { "cleaned" } else { "cleanup_failed" }
        } catch (_: Exception) {
            workspace.cleanupStatus = "cleanup_failed"
        }
        workspace.cleanupStatus
    }
}

public func sourceAnalysisDefaultWorkspaceRoot(): String {
    let tmp = if (let Some(value) <- getVariable("TMPDIR")) {
        if (value.trimAscii() == "") { "/tmp" } else { value.trimAscii() }
    } else {
        "/tmp"
    }
    trimTrailingSlash(tmp) + "/ckb-source-analysis"
}

public func effectiveSourceAnalysisWorkspaceRoot(config: CkbRuntimeConfig): String {
    if (config.sourceAnalysisWorkspaceRoot.trimAscii() == "") {
        return sourceAnalysisDefaultWorkspaceRoot()
    }
    config.sourceAnalysisWorkspaceRoot.trimAscii()
}

public func validateSourceAnalysisWorkspaceRoot(root: String): String {
    let cleaned = trimTrailingSlash(root.trimAscii())
    if (cleaned == "" || !cleaned.startsWith("/") || cleaned.contains("/../") || cleaned.endsWith("/..") || cleaned.contains("/./") || cleaned.endsWith("/.")) {
        return "invalid_workspace_root"
    }
    let projectRoot = trimTrailingSlash(if (let Some(value) <- getVariable("PWD")) { value } else { "" })
    if (projectRoot != "" && cleaned == projectRoot) {
        return "invalid_workspace_root"
    }
    ""
}

public func safeSourceAnalysisRepoDir(owner: String, repo: String): String {
    safeSourceAnalysisPathPart(owner) + "__" + safeSourceAnalysisPathPart(repo)
}

private func safeSourceAnalysisPathPart(raw: String): String {
    let out = StringBuilder()
    for (ch in raw.toRuneArray()) {
        let code = UInt32(ch)
        if ((code >= UInt32(r'a') && code <= UInt32(r'z')) || (code >= UInt32(r'A') && code <= UInt32(r'Z')) || (code >= UInt32(r'0') && code <= UInt32(r'9')) || ch == r'-' || ch == r'_') {
            out.append(ch)
        } else {
            out.append(r'_')
        }
    }
    let text = out.toString()
    if (text == "" || text == "." || text == "..") {
        return "repo"
    }
    text
}

public func cangjie_source_analysis(config: CkbRuntimeConfig, request: SourceAnalysisRequest, executor!: SourceCloneExecutor = GitSourceCloneExecutor()): SourceAnalysisPack {
    let pack = SourceAnalysisPack()
    pack.repo = request.repo
    pack.ref = if (request.ref == "") { "main" } else { request.ref }
    pack.commit = request.commit
    if (!config.sourceAnalysisEnabled) {
        pack.status = "source_analysis_disabled"
        pack.diagnostic = "source_analysis_disabled"
        return pack
    }
    if (request.visibility != RepoVisibility.PUBLIC) {
        pack.status = "non_public_repo_blocked"
        pack.diagnostic = "${request.visibility}_repo_excluded"
        return pack
    }
    let parts = parseGitCodeRepoPath(request.repo)
    if (!parts.valid) {
        pack.status = parts.diagnostic
        pack.diagnostic = parts.diagnostic
        return pack
    }
    let cloneUrl = sourceAnalysisCloneUrl(request)
    if (!sourceAnalysisCloneHostAllowed(cloneUrl, config.sourceAnalysisCloneHostAllowlist)) {
        pack.status = "invalid_clone_host"
        pack.diagnostic = "invalid_clone_host"
        return pack
    }
    let manager = SourceCloneWorkspaceManager(config)
    let workspace = manager.prepare(request.repo)
    pack.runId = workspace.runId
    pack.workspaceStatus = workspace.checkoutDisplay
    if (!workspace.ok) {
        pack.status = workspace.status
        pack.diagnostic = workspace.diagnostic
        pack.cleanupStatus = workspace.cleanupStatus
        return pack
    }
    let cloneRequest = CloneExecutionRequest()
    cloneRequest.repo = request.repo
    cloneRequest.ref = pack.ref
    cloneRequest.cloneUrl = cloneUrl
    cloneRequest.checkoutPath = workspace.checkoutPath.toString()
    cloneRequest.depth = if (config.sourceAnalysisCloneDepth <= 0) { 1 } else { config.sourceAnalysisCloneDepth }
    cloneRequest.timeoutMillis = config.sourceAnalysisTimeoutMillis
    let cloneResult = executor.clone(cloneRequest)
    if (!cloneResult.ok) {
        pack.status = cloneResult.status
        pack.diagnostic = cloneResult.diagnostic
        pack.cleanupStatus = manager.cleanup(workspace, request.retainFailedWorkspace || config.sourceAnalysisRetainFailedWorkspace)
        return pack
    }
    buildSourceAnalysisPackFromCheckout(pack, request, workspace.checkoutPath, config)
    pack.cleanupStatus = manager.cleanup(workspace, false)
    pack.ok = pack.status == "ok"
    pack
}

private func sourceAnalysisCloneUrl(request: SourceAnalysisRequest): String {
    if (request.cloneUrl.trimAscii() != "") {
        return request.cloneUrl.trimAscii()
    }
    let parts = parseGitCodeRepoPath(request.repo)
    if (!parts.valid) {
        return ""
    }
    "https://gitcode.com/${parts.owner}/${parts.repo}.git"
}

public func sourceAnalysisCloneHostAllowed(url: String, allowlist: String): Bool {
    let host = sourceAnalysisUrlHost(url)
    if (host == "") {
        return false
    }
    for (allowed in allowlist.split(",")) {
        if (host == allowed.trimAscii().toAsciiLower()) {
            return true
        }
    }
    false
}

private func sourceAnalysisUrlHost(url: String): String {
    let lowered = url.trimAscii().toAsciiLower()
    if (!lowered.startsWith("https://")) {
        return ""
    }
    let start: Int64 = 8
    var end = start
    while (end < lowered.size) {
        let ch = lowered[end..end + 1]
        if (ch == "/" || ch == ":" || ch == "?" || ch == "#") {
            break
        }
        end += 1
    }
    lowered[start..end]
}

private func buildSourceAnalysisPackFromCheckout(pack: SourceAnalysisPack, request: SourceAnalysisRequest, checkoutPath: Path, config: CkbRuntimeConfig): Unit {
    let selected = sourceAnalysisSelectedPaths(request)
    var count: Int64 = 0
    for (path in selected) {
        if (config.sourceAnalysisMaxFiles >= 0 && count >= config.sourceAnalysisMaxFiles) {
            pack.truncated = true
            addUniqueString(pack.degraded, "max_files")
            break
        }
        let normalized = normalizeGitCodeSourcePath(path)
        if (normalized == "" || sourceAnalysisPathExcluded(normalized)) {
            continue
        }
        let filePath = checkoutPath.join(normalized)
        if (!exists(filePath)) {
            continue
        }
        let raw = try {
            File.readFrom(filePath)
        } catch (_: Exception) {
            continue
        }
        if (sourceAnalysisLooksBinary(raw)) {
            continue
        }
        let file = SourceAnalysisFile()
        file.path = normalized
        file.bytes = raw.size
        var body = String.fromUtf8(raw)
        if (config.sourceAnalysisMaxFileBytes >= 0 && raw.size > config.sourceAnalysisMaxFileBytes) {
            pack.truncated = true
            file.truncated = true
            addUniqueString(pack.degraded, "max_file_bytes")
            body = utf8SafePrefix(body, config.sourceAnalysisMaxFileBytes)
        }
        file.bodyHash = stableSummaryHash(body)
        file.excerpt = sourceAnalysisExcerpt(body)
        file.citation = "${request.repo}@${if (request.commit == "") { if (request.ref == "") { "main" } else { request.ref } } else { request.commit }}:${normalized}"
        pack.selectedFiles.add(file)
        pack.citations.add(file.citation)
        count += 1
    }
    pack.status = "ok"
}

private func sourceAnalysisSelectedPaths(request: SourceAnalysisRequest): ArrayList<String> {
    let out = ArrayList<String>()
    for (path in request.changedFiles) {
        addUniqueString(out, path)
    }
    for (path in request.candidatePaths) {
        addUniqueString(out, path)
    }
    for (path in sourceAnalysisPathsFromSelector(request.selector)) {
        addUniqueString(out, path)
    }
    out
}

private func sourceAnalysisPathsFromSelector(selector: String): ArrayList<String> {
    let out = ArrayList<String>()
    for (token in selector.replace(",", " ").replace("\n", " ").split(" ")) {
        let value = token.trimAscii()
        if (value.contains("/") && sourceAnalysisAllowedExtension(value.toAsciiLower())) {
            addUniqueString(out, value)
        }
    }
    out
}

private func sourceAnalysisPathExcluded(path: String): Bool {
    let lower = path.toAsciiLower()
    lower.startsWith(".git/") || lower.contains("/.git/") || lower.startsWith("target/") || lower.contains("/target/") || lower.startsWith("build/") || lower.contains("/build/") || lower.startsWith("vendor/") || lower.contains("/vendor/") || !sourceAnalysisAllowedExtension(lower)
}

private func sourceAnalysisAllowedExtension(lower: String): Bool {
    lower.endsWith(".cj") || lower.endsWith(".md") || lower.endsWith(".txt") || lower.endsWith(".toml") || lower.endsWith(".json") || lower.endsWith(".yaml") || lower.endsWith(".yml")
}

private func sourceAnalysisLooksBinary(bytes: Array<UInt8>): Bool {
    for (byte in bytes) {
        if (byte == 0u8) {
            return true
        }
    }
    false
}

private func sourceAnalysisExcerpt(body: String): String {
    let cleaned = body.replace("\r", "").trimAscii()
    if (cleaned.size <= 800) {
        return cleaned
    }
    utf8SafePrefix(cleaned, 800)
}

private func trimTrailingSlash(raw: String): String {
    var out = raw
    while (out.size > 1 && out.endsWith("/")) {
        out = out[0..out.size - 1]
    }
    out
}

public class SourceSyncPlan {
    public var requests: ArrayList<SourceFetchRequest> = ArrayList<SourceFetchRequest>()
    public var truncated: Bool = false

    public init() {}
}

public class GitCodeDiscoveryStats {
    public var orgs: Int64 = 0
    public var pages: Int64 = 0
    public var discovered: Int64 = 0
    public var publicCount: Int64 = 0
    public var privateCount: Int64 = 0
    public var internalCount: Int64 = 0
    public var unknownCount: Int64 = 0
    public var included: Int64 = 0
    public var excluded: Int64 = 0

    public init() {}
}

private class LiveSyncRunState {
    var requests: Int64 = 0
    var okCount: Int64 = 0
    var degradedCount: Int64 = 0
    var truncated: Bool = false
    var out: String = ""
    let discovery: GitCodeDiscoveryStats = GitCodeDiscoveryStats()

    init() {}
}

public class SourceCandidateSelector {
    public init() {}

    public func selectFromTree(body: String, maxFiles!: Int64 = -1): ArrayList<String> {
        let code = ArrayList<String>()
        let docs = ArrayList<String>()
        for (object in nestedJsonObjectChunks(body)) {
            let safeObject = asciiJsonProjection(object)
            let rawPath = jsonStringField(safeObject, "path")
            let path = normalizeGitCodeSourcePath(rawPath)
            if (path == "" || excludedSourceCandidate(path)) {
                continue
            }
            let itemType = jsonStringField(safeObject, "type").toAsciiLower()
            if (itemType == "tree" || itemType == "commit") {
                continue
            }
            let lower = path.toAsciiLower()
            if (lower.endsWith(".cj")) {
                addUniqueString(code, path)
            } else if (isReadmeOrDocsMarkdown(lower)) {
                addUniqueString(docs, path)
            }
        }
        let selected = ArrayList<String>()
        for (path in code) {
            if (maxFiles >= 0 && selected.size >= maxFiles) {
                return selected
            }
            selected.add(path)
        }
        for (path in docs) {
            if (maxFiles >= 0 && selected.size >= maxFiles) {
                return selected
            }
            selected.add(path)
        }
        selected
    }
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

    public func repoScopedPlan(repos: ArrayList<GitCodeRepoMetadata>, maxFilesPerRepo!: Int64 = -1): SourceSyncPlan {
        let plan = SourceSyncPlan()
        for (repo in repos) {
            if (!isRepoAllowedForKnowledge(repo)) {
                continue
            }
            if (repo.defaultBranch != "") {
                plan.requests.add(markPublicRepoRequest(this.builder.gitCodeTree(repo.fullName, repo.defaultBranch)))
            }
            plan.requests.add(markPublicRepoRequest(this.builder.gitCodeIssueHistory(repo.fullName)))
            plan.requests.add(markPublicRepoRequest(this.builder.gitCodePrHistory(repo.fullName)))
            plan.requests.add(markPublicRepoRequest(this.builder.gitCodeCommentHistory(repo.fullName)))
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

public class BackupRestoreResult {
    public var ok: Bool = false
    public var action: String = ""
    public var source: String = ""
    public var destination: String = ""
    public var activeVersion: String = ""
    public var diagnostic: String = ""
    public var files: Int64 = 0

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
    let builder = SourceRequestBuilder(gitCodeApiRoot: config.gitCodeBaseUrl)
    let state = LiveSyncRunState()
    state.out = "sync-live mode=${if (options.dryRun) { "dry-run" } else { "apply" }} requests=dynamic websiteEnabled=${config.websiteEnabled} docsEnabled=${config.docsEnabled} ${config.redactedSummary()}\n"
    discoverAndFetchGitCodePublicRepos(kb, config, options, runner, builder, state)
    let staticPlan = planner.productionPlan(kb.sourceScope)
    for (request in staticPlan.requests) {
        if (request.kind == SourceKinds.GITCODE_ORG) {
            continue
        }
        if (!config.websiteEnabled && request.kind == SourceKinds.CANGJIE_WEBSITE) {
            state.out += "skip kind=${request.kind} reason=website_disabled auth=none sourceUrl=${redactSensitive(request.url)}\n"
            continue
        }
        if (!config.docsEnabled && request.kind == SourceKinds.CANGJIE_DOCS) {
            state.out += "skip kind=${request.kind} reason=docs_disabled auth=none sourceUrl=${redactSensitive(request.url)}\n"
            continue
        }
        fetchLiveRequest(kb, config, options, runner, request, state)
    }
    var activePromoted = false
    var candidateWritten = false
    var validationSummary = "candidateValidation status=not_run"
    if (options.apply) {
        kb.normalize()
        let promotion = cangjiePromoteCandidateAfterValidation(kb, store, forceFailure: options.simulateValidationFailure)
        candidateWritten = promotion.candidateWritten
        activePromoted = promotion.activePromoted
        validationSummary = renderCangjieCandidateValidationSummary(promotion.validation)
    }
    state.out += "summary requests=${state.requests} ok=${state.okCount} degraded=${state.degradedCount} truncated=${state.truncated} rawWritten=${if (options.apply && activePromoted) { "true" } else { "false" }} candidateWritten=${candidateWritten} activePromoted=${activePromoted} since=${options.since}\n"
    state.out += "${validationSummary}\n"
    state.out += "freshness ${renderCangjieCorpusFreshnessJson(cangjieCorpusFreshnessReport(kb.status()))}\n"
    redactSensitive(state.out)
}

private func discoverAndFetchGitCodePublicRepos(kb: KnowledgeBase, config: CkbRuntimeConfig, options: LiveSyncOptions, runner: SourceFetchRunner, builder: SourceRequestBuilder, state: LiveSyncRunState): Unit {
    for (org in kb.sourceScope.organizations) {
        state.discovery.orgs += 1
        var page: Int64 = 1
        while (true) {
            if (!liveBudgetAllows(state, options)) {
                state.truncated = true
                break
            }
            let request = builder.gitCodeOrgRepos(org, page: page)
            let fetch = fetchLiveRequest(kb, config, options, runner, request, state)
            state.discovery.pages += 1
            let repos = parseGitCodeOrgReposJson(fetch.body)
            updateDiscoveryStats(state.discovery, repos)
            state.out += renderRepoDiscoveryLine(state.discovery)
            state.out += "repoDiscoveryPage org=${org} page=${page} status=${fetch.status} repos=${repos.size} stop=${if (!fetch.ok || repos.size < request.perPage) { "true" } else { "false" }}\n"
            if (!fetch.ok) {
                break
            }
            for (repo in repos) {
                if (!isRepoAllowedForKnowledge(repo)) {
                    state.discovery.excluded += 1
                    state.out += "repoExcluded ${repoDisplayName(repo)} visibility=${repo.visibility} reason=${repo.visibility}_repo_excluded\n"
                    continue
                }
                if (options.maxRepos >= 0 && state.discovery.included >= options.maxRepos) {
                    state.truncated = true
                    state.out += "repoExcluded ${repo.fullName} visibility=public reason=max_repos\n"
                    continue
                }
                state.discovery.included += 1
                state.out += "repoIncluded ${repo.fullName} visibility=public defaultBranch=${if (repo.defaultBranch == "") { "missing" } else { repo.defaultBranch }}\n"
                fetchGitCodePublicRepo(kb, config, options, runner, builder, repo, state)
            }
            if (repos.size < request.perPage) {
                break
            }
            page += 1
        }
    }
}

private func fetchGitCodePublicRepo(kb: KnowledgeBase, config: CkbRuntimeConfig, options: LiveSyncOptions, runner: SourceFetchRunner, builder: SourceRequestBuilder, repo: GitCodeRepoMetadata, state: LiveSyncRunState): Unit {
    if (!isRepoAllowedForKnowledge(repo)) {
        state.out += "repoExcluded ${repoDisplayName(repo)} visibility=${repo.visibility} reason=non_public_request_blocked\n"
        return
    }
    if (repo.defaultBranch != "") {
        let treeRequest = markPublicRepoRequest(builder.gitCodeTree(repo.fullName, repo.defaultBranch))
        let treeFetch = fetchLiveRequest(kb, config, options, runner, treeRequest, state)
        if (treeFetch.ok) {
            let candidates = SourceCandidateSelector().selectFromTree(treeFetch.body, maxFiles: options.maxFilesPerRepo)
            for (path in candidates) {
                if (!liveBudgetAllows(state, options)) {
                    state.truncated = true
                    break
                }
                let rawFetch = fetchLiveRequest(kb, config, options, runner, markPublicRepoRequest(builder.gitCodeSource(repo.fullName, repo.defaultBranch, path)), state)
                if (!rawFetch.ok && shouldFallbackToGitCodeContents(rawFetch)) {
                    if (!liveBudgetAllows(state, options)) {
                        state.truncated = true
                        state.out += "sourceFallback repo=${repo.fullName} path=${path} rawStatus=${rawFetch.status} contentsFallback=skipped reason=max_items\n"
                        break
                    }
                    state.out += "sourceFallback repo=${repo.fullName} path=${path} rawStatus=${rawFetch.status} contentsFallback=attempted\n"
                    fetchLiveRequest(kb, config, options, runner, markPublicRepoRequest(builder.gitCodeSourceContents(repo.fullName, repo.defaultBranch, path)), state)
                }
            }
        }
    } else {
        state.out += "repoSkippedSource ${repo.fullName} visibility=public reason=missing_default_branch\n"
    }
    if (!liveBudgetAllows(state, options)) {
        state.truncated = true
        return
    }
    fetchLiveRequest(kb, config, options, runner, markPublicRepoRequest(builder.gitCodeIssueHistory(repo.fullName)), state)
    if (!liveBudgetAllows(state, options)) {
        state.truncated = true
        return
    }
    fetchLiveRequest(kb, config, options, runner, markPublicRepoRequest(builder.gitCodePrHistory(repo.fullName)), state)
    if (!liveBudgetAllows(state, options)) {
        state.truncated = true
        return
    }
    fetchLiveRequest(kb, config, options, runner, markPublicRepoRequest(builder.gitCodeCommentHistory(repo.fullName)), state)
}

private func fetchLiveRequest(kb: KnowledgeBase, config: CkbRuntimeConfig, options: LiveSyncOptions, runner: SourceFetchRunner, request: SourceFetchRequest, state: LiveSyncRunState): SourceFetchResult {
    request.timeoutMillis = config.timeoutMillis
    request.retryCount = config.retryCount
    state.requests += 1
    state.out += "repoFetch kind=${request.kind} repo=${request.repo} visibility=${if (request.repoVisibility == "") { "n/a" } else { request.repoVisibility }} sourceUrl=${redactSensitive(request.url)}\n"
    let fetch = SourceResponseNormalizer().normalize(request, runner.fetch(request))
    if (fetch.ok) {
        state.okCount += 1
    } else {
        state.degradedCount += 1
    }
    state.out += renderLiveFetchSummary(request, fetch, authSummaryForRequest(config, request))
    if (options.apply && fetch.ok) {
        ingestLiveFetch(kb, request, fetch, state.requests)
    }
    fetch
}

private func liveBudgetAllows(state: LiveSyncRunState, options: LiveSyncOptions): Bool {
    options.maxItems < 0 || state.requests < options.maxItems
}

private func shouldFallbackToGitCodeContents(fetch: SourceFetchResult): Bool {
    if (fetch.ok) {
        return false
    }
    fetch.status == "http_400" || fetch.status == "http_404" || fetch.status == "not_found" || fetch.status == "source_unavailable" || fetch.status == "server_error" || fetch.statusCode == 400 || fetch.statusCode == 404 || fetch.statusCode >= 500
}

private func markPublicRepoRequest(request: SourceFetchRequest): SourceFetchRequest {
    request.repoVisibility = RepoVisibility.PUBLIC
    request
}

private func updateDiscoveryStats(stats: GitCodeDiscoveryStats, repos: ArrayList<GitCodeRepoMetadata>): Unit {
    stats.discovered += repos.size
    for (repo in repos) {
        if (repo.visibility == RepoVisibility.PUBLIC) {
            stats.publicCount += 1
        } else if (repo.visibility == RepoVisibility.PRIVATE) {
            stats.privateCount += 1
        } else if (repo.visibility == RepoVisibility.INTERNAL) {
            stats.internalCount += 1
        } else {
            stats.unknownCount += 1
        }
    }
}

private func renderRepoDiscoveryLine(stats: GitCodeDiscoveryStats): String {
    "repoDiscovery orgs=${stats.orgs} pages=${stats.pages} discovered=${stats.discovered} public=${stats.publicCount} private=${stats.privateCount} internal=${stats.internalCount} unknown=${stats.unknownCount} included=${stats.included} excluded=${stats.excluded}\n"
}

private func repoDisplayName(repo: GitCodeRepoMetadata): String {
    if (repo.fullName != "") {
        return repo.fullName
    }
    if (repo.owner != "" || repo.repo != "") {
        return "${repo.owner}/${repo.repo}"
    }
    "unknown"
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

    public func fetchGitCodeSourceRaw(repo: String, ref: String, path: String): SourceFetchResult {
        this.fetch(this.builder.gitCodeSourceRaw(repo, ref, path))
    }

    public func fetchGitCodeSourceContents(repo: String, ref: String, path: String): SourceFetchResult {
        this.fetch(this.builder.gitCodeSourceContents(repo, ref, path))
    }

    public func fetchGitCodeTree(repo: String, ref: String): SourceFetchResult {
        this.fetch(this.builder.gitCodeTree(repo, ref))
    }

    public func fetchGitCodeIssueHistory(repo: String): SourceFetchResult {
        this.fetch(this.builder.gitCodeIssueHistory(repo))
    }

    public func fetchGitCodePrHistory(repo: String): SourceFetchResult {
        this.fetch(this.builder.gitCodePrHistory(repo))
    }

    public func fetchGitCodeCommentHistory(repo: String): SourceFetchResult {
        this.fetch(this.builder.gitCodeCommentHistory(repo))
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

public class SourceAnalysisTriggerClassifier {
    public init() {}

    public func classify(request: SourceAnalysisRequest, hasSourceEvidence!: Bool = true): TriggerDecision {
        let decision = TriggerDecision()
        let text = ("${request.query} ${request.issueUrl} ${request.prUrl}").toAsciiLower()
        if (containsAnyText(text, ["source_analysis", "source analysis", "analyze source", "read source", "fresh source", "latest source"])) {
            addUniqueString(decision.triggerReasons, SourceAnalysisTriggerReasons.MANUAL_REQUEST)
        }
        if (containsAnyText(text, ["compile error", "build failed", "compiler error", "error:"]) || hasLineNumberSignal(text)) {
            addUniqueString(decision.triggerReasons, SourceAnalysisTriggerReasons.COMPILE_ERROR)
        }
        if (containsAnyText(text, ["runtime bug", "panic", "exception", "crash", "segmentation fault"])) {
            addUniqueString(decision.triggerReasons, SourceAnalysisTriggerReasons.RUNTIME_BUG)
        }
        if (containsAnyText(text, ["stack trace", "traceback", "\tat ", " at "]) || hasStackFrameSignal(text)) {
            addUniqueString(decision.triggerReasons, SourceAnalysisTriggerReasons.STACK_TRACE)
        }
        if (request.changedFiles.size > 0 || request.prUrl != "" || containsAnyText(text, ["changed files", "pr diff", "pull request", "review diff", "regression"])) {
            addUniqueString(decision.triggerReasons, SourceAnalysisTriggerReasons.PR_DIFF_REVIEW)
        }
        if (!hasSourceEvidence || containsAnyText(text, ["source evidence insufficient", "insufficient source evidence", "no source evidence"])) {
            addUniqueString(decision.triggerReasons, SourceAnalysisTriggerReasons.INSUFFICIENT_SOURCE_EVIDENCE)
        }
        if (containsAnyText(text, ["fresh source", "latest source", "current source", "head source"])) {
            addUniqueString(decision.triggerReasons, SourceAnalysisTriggerReasons.FRESH_SOURCE_REQUIRED)
        }
        let paths = sourceAnalysisCandidatePaths(request)
        if (paths.size > 0) {
            addUniqueString(decision.triggerReasons, SourceAnalysisTriggerReasons.FILE_PATH_MENTIONED)
        }
        if (hasSourceSymbolSignal(request.query)) {
            addUniqueString(decision.triggerReasons, SourceAnalysisTriggerReasons.SYMBOL_MENTIONED)
        }
        decision.shouldAnalyze = decision.triggerReasons.size > 0
        if (decision.shouldAnalyze) {
            decision.acquisitionPlan = if (!hasSourceEvidence && request.allowCloneFallback) { "clone_fallback" } else { "api_or_existing" }
            if (!hasSourceEvidence && !request.allowCloneFallback) {
                decision.degraded = true
                decision.diagnostic = "clone_fallback_disabled"
                decision.acquisitionPlan = "api_only_degraded"
            }
        }
        decision
    }
}

public func ckbSourceAnalysis(request: SourceAnalysisRequest, runner!: SourceFetchRunner = DisabledNetworkFetchRunner(), hasSourceEvidence!: Bool = true): SourceAnalysisResult {
    let result = SourceAnalysisResult()
    result.repo = request.repo
    result.ref = request.ref
    result.analysisId = sourceAnalysisId(request)
    let classifier = SourceAnalysisTriggerClassifier()
    let decision = classifier.classify(request, hasSourceEvidence: hasSourceEvidence)
    for (reason in decision.triggerReasons) {
        result.triggerReasons.add(reason)
    }
    if (request.repoVisibility != "" && request.repoVisibility != RepoVisibility.PUBLIC) {
        result.degraded = true
        result.diagnostic = "blocked_non_public_repo"
        return result
    }
    if (!decision.shouldAnalyze) {
        result.diagnostic = "not_triggered"
        return result
    }
    if (decision.degraded) {
        result.degraded = true
        result.diagnostic = decision.diagnostic
    }
    let adapter = SourceAdapter(runner: runner)
    let paths = sourceAnalysisCandidatePaths(request)
    var totalBytes: Int64 = 0
    var attempted: Int64 = 0
    for (path in paths) {
        if (attempted >= normalizedMaxFiles(request.maxFiles)) {
            break
        }
        let cleanPath = normalizeGitCodeSourcePath(path)
        if (cleanPath == "") {
            result.degraded = true
            result.diagnostic = appendDiagnostic(result.diagnostic, "invalid_source_path")
            continue
        }
        attempted += 1
        let raw = adapter.fetchGitCodeSourceRaw(request.repo, request.ref, cleanPath)
        var acquired = raw
        var acquisition = SourceAnalysisAcquisition.API_RAW
        if (!raw.ok) {
            let contents = adapter.fetchGitCodeSourceContents(request.repo, request.ref, cleanPath)
            acquired = contents
            acquisition = SourceAnalysisAcquisition.API_CONTENTS
        }
        if (!acquired.ok) {
            result.degraded = true
            result.diagnostic = appendDiagnostic(result.diagnostic, "source_unavailable:${cleanPath}")
            continue
        }
        if (totalBytes + acquired.bytes > normalizedMaxBytes(request.maxBytes)) {
            result.degraded = true
            result.diagnostic = appendDiagnostic(result.diagnostic, "max_bytes_exceeded")
            break
        }
        totalBytes += acquired.bytes
        let file = SourceAnalysisFile()
        file.repo = request.repo
        file.ref = request.ref
        file.path = cleanPath
        file.sourceUrl = redactSensitive(acquired.sourceUrl)
        file.bodyHash = acquired.bodyHash
        file.excerpt = sourceExcerpt(acquired.body)
        file.bytes = acquired.bytes
        file.acquisition = acquisition
        result.filesRead.add(file)
        result.citations.add(sourceAnalysisCitation(request.repo, request.ref, cleanPath))
        result.commit = if (result.commit == "" && acquired.commit != "") { acquired.commit } else { result.commit }
        result.sourceAcquisition = if (result.sourceAcquisition == SourceAnalysisAcquisition.NONE) { acquisition } else { result.sourceAcquisition }
    }
    if (paths.size == 0) {
        result.degraded = true
        result.diagnostic = appendDiagnostic(result.diagnostic, "no_candidate_paths")
    }
    if (result.filesRead.size == 0 && request.allowCloneFallback) {
        result.degraded = true
        result.diagnostic = appendDiagnostic(result.diagnostic, "clone_fallback_not_implemented")
    } else if (result.filesRead.size == 0 && !request.allowCloneFallback) {
        result.degraded = true
        result.diagnostic = appendDiagnostic(result.diagnostic, "clone_fallback_disabled")
    }
    result.cleanupStatus = "not_needed"
    result
}

public func renderSourceAnalysis(result: SourceAnalysisResult): String {
    var out = "source_analysis analysisId=${result.analysisId} repo=${result.repo} ref=${result.ref} commit=${if (result.commit == "") { "unknown" } else { result.commit }} sourceAcquisition=${result.sourceAcquisition} degraded=${result.degraded} cleanupStatus=${result.cleanupStatus} diagnostic=${redactSensitive(result.diagnostic)}\n"
    out += "triggerReasons=${joinStrings(result.triggerReasons, ",")}\n"
    out += "filesRead=${result.filesRead.size}\n"
    for (file in result.filesRead) {
        out += "file path=${file.path} acquisition=${file.acquisition} bytes=${file.bytes} bodyHash=${file.bodyHash} sourceUrl=${file.sourceUrl}\n"
    }
    out += "citations=${joinStrings(result.citations, ",")}\n"
    out
}

public func sourceAnalysisRequestFromText(raw: String): SourceAnalysisRequest {
    let request = SourceAnalysisRequest()
    var queryParts = ArrayList<String>()
    for (part in raw.split(" ")) {
        let item = part.trimAscii()
        if (item == "") {
            continue
        }
        if (item.startsWith("repo=")) {
            request.repo = item[5..item.size]
        } else if (item.startsWith("ref=")) {
            request.ref = item[4..item.size]
        } else if (item.startsWith("query=")) {
            queryParts.add(item[6..item.size])
        } else if (item.startsWith("issueUrl=")) {
            request.issueUrl = item[9..item.size]
        } else if (item.startsWith("prUrl=")) {
            request.prUrl = item[6..item.size]
        } else if (item.startsWith("changedFiles=")) {
            addCsvPaths(request.changedFiles, item[13..item.size])
        } else if (item.startsWith("candidatePaths=")) {
            addCsvPaths(request.candidatePaths, item[15..item.size])
        } else if (item.startsWith("path=")) {
            addCsvPaths(request.candidatePaths, item[5..item.size])
        } else if (item.startsWith("allowCloneFallback=")) {
            request.allowCloneFallback = parseBool(item[19..item.size])
        } else if (item.startsWith("maxFiles=")) {
            request.maxFiles = parseIntField(item[9..item.size], request.maxFiles)
        } else if (item.startsWith("maxBytes=")) {
            request.maxBytes = parseIntField(item[9..item.size], request.maxBytes)
        } else if (item.startsWith("timeoutMillis=")) {
            request.timeoutMillis = parseIntField(item[14..item.size], request.timeoutMillis)
        } else if (item.startsWith("repoVisibility=")) {
            request.repoVisibility = item[15..item.size]
        } else {
            queryParts.add(item)
        }
    }
    request.query = joinStrings(queryParts, " ")
    request
}

private func sourceAnalysisCandidatePaths(request: SourceAnalysisRequest): ArrayList<String> {
    let paths = ArrayList<String>()
    for (path in request.changedFiles) {
        addNormalizedSourcePath(paths, path)
    }
    for (path in request.candidatePaths) {
        addNormalizedSourcePath(paths, path)
    }
    for (path in extractMentionedSourcePaths(request.query)) {
        addNormalizedSourcePath(paths, path)
    }
    paths
}

private func extractMentionedSourcePaths(text: String): ArrayList<String> {
    let paths = ArrayList<String>()
    let normalized = text.replace("\n", " ").replace("\r", " ").replace("\t", " ")
    for (part in normalized.split(" ")) {
        let candidate = stripSourcePathToken(part)
        if (candidate != "") {
            addNormalizedSourcePath(paths, candidate)
        }
    }
    paths
}

private func stripSourcePathToken(raw: String): String {
    var token = raw.trimAscii()
    while (token.size > 0 && (token.endsWith(".") || token.endsWith(",") || token.endsWith(";") || token.endsWith(")") || token.endsWith("]") || token.endsWith("\"") || token.endsWith("'"))) {
        token = token[0..token.size - 1]
    }
    while (token.size > 0 && (token.startsWith("(") || token.startsWith("[") || token.startsWith("\"") || token.startsWith("'"))) {
        token = token[1..token.size]
    }
    let colon = lastColonIndex(token)
    if (colon > 0 && colon + 1 < token.size && allDigits(token[colon + 1..token.size])) {
        token = token[0..colon]
    }
    let lower = token.toAsciiLower()
    if ((lower.startsWith("src/") || lower.startsWith("docs/") || lower.startsWith("test/") || lower == "readme.md" || lower.contains("/")) && (lower.endsWith(".cj") || lower.endsWith(".md") || lower.endsWith(".cjo") || lower.endsWith(".toml"))) {
        return token
    }
    ""
}

private func addNormalizedSourcePath(paths: ArrayList<String>, raw: String): Unit {
    let path = normalizeGitCodeSourcePath(stripSourcePathToken(raw))
    if (path != "") {
        addUniqueString(paths, path)
    }
}

private func addCsvPaths(paths: ArrayList<String>, raw: String): Unit {
    for (path in raw.split(",")) {
        addNormalizedSourcePath(paths, path)
    }
}

private func sourceAnalysisId(request: SourceAnalysisRequest): String {
    stableSummaryHash("${request.repo}|${request.ref}|${request.query}|${request.changedFiles.size}|${request.candidatePaths.size}")
}

private func sourceAnalysisCitation(repo: String, ref: String, path: String): String {
    "https://gitcode.com/${repo}/-/blob/${ref}/${path}"
}

private func sourceExcerpt(body: String): String {
    let clean = redactSensitive(body).replace("\r", " ")
    let out = StringBuilder()
    var count: Int64 = 0
    for (ch in clean.toRuneArray()) {
        if (count >= 160) {
            break
        }
        out.append(ch)
        count += 1
    }
    out.toString()
}

private func containsAnyText(text: String, needles: Array<String>): Bool {
    for (needle in needles) {
        if (text.contains(needle)) {
            return true
        }
    }
    false
}

private func hasLineNumberSignal(text: String): Bool {
    for (part in text.split(" ")) {
        let token = stripSourcePathToken(part)
        if (token != "" && part.contains(":")) {
            return true
        }
    }
    false
}

private func hasStackFrameSignal(text: String): Bool {
    text.contains(".cj:") || text.contains(" at ") && text.contains(".")
}

private func hasSourceSymbolSignal(text: String): Bool {
    let lower = text.toAsciiLower()
    lower.contains("symbol ") || lower.contains("func ") || lower.contains("class ") || text.contains("()") || text.contains("::")
}

private func normalizedMaxFiles(raw: Int64): Int64 {
    if (raw <= 0) {
        return 1
    }
    raw
}

private func normalizedMaxBytes(raw: Int64): Int64 {
    if (raw <= 0) {
        return 1
    }
    raw
}

private func appendDiagnostic(current: String, next: String): String {
    if (current == "") {
        return next
    }
    if (current.contains(next)) {
        return current
    }
    "${current},${next}"
}

private func joinStrings(values: ArrayList<String>, separator: String): String {
    var out = ""
    for (value in values) {
        if (out == "") {
            out = value
        } else {
            out += "${separator}${value}"
        }
    }
    out
}

private func allDigits(value: String): Bool {
    if (value == "") {
        return false
    }
    for (ch in value.toRuneArray()) {
        if (ch < r'0' || ch > r'9') {
            return false
        }
    }
    true
}

private func lastColonIndex(value: String): Int64 {
    var i = value.size - 1
    while (i >= 0) {
        if (value[i..i + 1] == ":") {
            return i
        }
        i -= 1
    }
    -1
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
        text += "activeStateSource=${status.activeStateSource}\n"
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
        text += "vectorActiveCollection=${status.storage.vectorActiveCollection}\n"
        text += "vectorCandidateCollection=${status.storage.vectorCandidateCollection}\n"
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

    public func loadVectorCollection(collection: String): ArrayList<VectorRecord> {
        this.parseVector(this.readLines("index/vector-${safeName(collection)}.ckb"))
    }

    public func backupVectorCollection(collection: String, backupName: String): Bool {
        let source = this.readLines("index/vector-${safeName(collection)}.ckb")
        if (source == "") {
            return false
        }
        this.writeLines("backup/vector-${safeName(backupName)}-${safeName(collection)}.ckb", source)
        true
    }

    public func restoreVectorBackup(collection: String, backupName: String): Bool {
        let source = this.readLines("backup/vector-${safeName(backupName)}-${safeName(collection)}.ckb")
        if (source == "") {
            return false
        }
        this.writeLines("index/vector-${safeName(collection)}.ckb", source)
        true
    }

    public func saveGraph(graph: GraphBuildResult): Unit {
        this.writeLines("index/graph-nodes.ckb", this.graphNodeLines(graph.nodes))
        this.writeLines("index/graph-edges.ckb", this.graphEdgeLines(graph.edges))
    }

    public func saveDerived(task: CurationTask): Unit {
        this.writeLines("derived/${safeName(task.taskId)}.ckb", "${task.taskId}|${task.kind}|${task.repo}|${task.status}|${escapeField(task.derivedKnowledge)}\n")
    }

    public func saveRepositoryListRefresh(result: CkbAdminOperationResult): Unit {
        var text = "repo=${escapeField(result.repo)}\n"
        text += "ref=${escapeField(result.ref)}\n"
        text += "activeRepoListVersion=${escapeField(result.activeRepoListVersion)}\n"
        text += "candidateRepoListVersion=${escapeField(result.candidateRepoListVersion)}\n"
        text += "repoCount=${result.repoCount}\n"
        text += "paths=${escapeField(joinStrings(result.matchedPaths, ","))}\n"
        this.writeLines("metadata/repo-list.ckb", text)
    }

    public func saveCangjieVersionManifest(manifest: CangjieVersionManifest): Unit {
        var text = "manifestVersion=${escapeField(manifest.manifestVersion)}\n"
        text += "defaultTargetVersion=${escapeField(manifest.defaultTargetVersion)}\n"
        text += "degraded=${manifest.degraded}\n"
        for (diagnostic in manifest.diagnostics) {
            text += "diagnostic|${escapeField(diagnostic)}\n"
        }
        for (source in manifest.sources) {
            text += "source|${escapeField(source.targetVersion)}|${escapeField(source.sourceSet)}|${escapeField(source.sourceFamily)}|${escapeField(source.sourceRepo)}|${escapeField(source.sourceRef)}|${escapeField(source.refKind)}|${escapeField(source.resolvedCommit)}|${escapeField(source.contentHash)}|${escapeField(source.rootKind)}\n"
        }
        this.writeLines("metadata/cangjie-version-manifest.ckb", text)
    }

    public func loadCangjieVersionManifest(): CangjieVersionManifest {
        let manifest = CangjieVersionManifest()
        manifest.sources.clear()
        let text = this.readLines("metadata/cangjie-version-manifest.ckb")
        if (text == "") {
            return manifest
        }
        for (line in text.split("\n")) {
            let trimmed = line.trimAscii()
            if (trimmed == "") {
                continue
            }
            if (trimmed.startsWith("manifestVersion=")) {
                manifest.manifestVersion = unescapeField(trimmed[16..trimmed.size])
            } else if (trimmed.startsWith("defaultTargetVersion=")) {
                manifest.defaultTargetVersion = unescapeField(trimmed[21..trimmed.size])
            } else if (trimmed.startsWith("degraded=")) {
                manifest.degraded = unescapeField(trimmed[9..trimmed.size]) == "true"
            } else if (trimmed.startsWith("diagnostic|")) {
                let parts = trimmed.split("|")
                if (parts.size >= 2) {
                    manifest.diagnostics.add(unescapeField(parts[1]))
                }
            } else if (trimmed.startsWith("source|")) {
                let parts = trimmed.split("|")
                if (parts.size >= 9) {
                    let source = CangjieVersionSource()
                    source.targetVersion = unescapeField(parts[1])
                    source.sourceSet = unescapeField(parts[2])
                    source.sourceFamily = unescapeField(parts[3])
                    source.sourceRepo = unescapeField(parts[4])
                    source.sourceRef = unescapeField(parts[5])
                    source.refKind = unescapeField(parts[6])
                    source.resolvedCommit = unescapeField(parts[7])
                    source.contentHash = unescapeField(parts[8])
                    if (parts.size >= 10) {
                        source.rootKind = unescapeField(parts[9])
                    }
                    manifest.sources.add(source)
                }
            }
        }
        manifest
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
            } else if (key == "activeStateSource") {
                status.activeStateSource = value
            } else if (key == "vectorActiveCollection") {
                status.vectorActiveCollection = value
            } else if (key == "vectorCandidateCollection") {
                status.vectorCandidateCollection = value
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
        snapshot.activeStateSource = metadata.activeStateSource
        snapshot.vectorActiveCollection = metadata.vectorActiveCollection
        snapshot.vectorCandidateCollection = metadata.vectorCandidateCollection
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
        let vectorCollection = if (metadata.vectorActiveCollection == "") { "active" } else { metadata.vectorActiveCollection }
        snapshot.hasVectorArtifact = this.has("index/vector-${safeName(vectorCollection)}.ckb")
        if (snapshot.hasVectorArtifact) {
            snapshot.vectorRecords = this.loadVectorCollection(vectorCollection)
        }
        snapshot.hasGraphArtifacts = this.has("index/graph-nodes.ckb") && this.has("index/graph-edges.ckb")
        snapshot
    }

    public func backupActiveSnapshot(backupRoot: String): BackupRestoreResult {
        let result = BackupRestoreResult()
        result.action = "backup"
        result.source = "store"
        result.destination = redactSensitive(backupRoot)
        if (backupRoot.trimAscii() == "") {
            result.ok = false
            result.diagnostic = "missing_backup_path"
            return result
        }
        let snapshot = this.loadActiveSnapshot()
        result.activeVersion = snapshot.activeVersion
        if (!snapshot.valid) {
            result.ok = false
            result.diagnostic = snapshot.diagnostic
            return result
        }
        let backup = FileKnowledgeStore(backupRoot)
        backup.ensureLayout()
        result.files += this.copyIfPresentTo(backup, "raw/records.ckb")
        result.files += this.copyIfPresentTo(backup, "normalized/records.ckb")
        result.files += this.copyIfPresentTo(backup, "metadata/status.ckb")
        result.files += this.copyIfPresentTo(backup, "metadata/cangjie-version-manifest.ckb")
        result.files += this.copyIfPresentTo(backup, "index/active.version")
        result.files += this.copyIfPresentTo(backup, "index/active.ckb")
        result.files += this.copyIfPresentTo(backup, "index/vector-active.ckb")
        result.files += this.copyIfPresentTo(backup, "index/graph-nodes.ckb")
        result.files += this.copyIfPresentTo(backup, "index/graph-edges.ckb")
        backup.writeLines("metadata/backup.ckb", "active=${snapshot.activeVersion}\nsource=active-snapshot\n")
        result.files += 1
        result.ok = true
        result.diagnostic = "ok"
        result
    }

    public func restoreActiveSnapshotBackup(backupRoot: String): BackupRestoreResult {
        let result = BackupRestoreResult()
        result.action = "restore"
        result.source = redactSensitive(backupRoot)
        result.destination = "store"
        if (backupRoot.trimAscii() == "") {
            result.ok = false
            result.diagnostic = "missing_backup_path"
            return result
        }
        let backup = FileKnowledgeStore(backupRoot)
        let snapshot = backup.loadActiveSnapshot()
        result.activeVersion = snapshot.activeVersion
        if (!snapshot.valid) {
            result.ok = false
            result.diagnostic = snapshot.diagnostic
            return result
        }
        this.ensureLayout()
        result.files += backup.copyIfPresentTo(this, "raw/records.ckb")
        result.files += backup.copyIfPresentTo(this, "normalized/records.ckb")
        result.files += backup.copyIfPresentTo(this, "metadata/status.ckb")
        result.files += backup.copyIfPresentTo(this, "metadata/cangjie-version-manifest.ckb")
        result.files += backup.copyIfPresentTo(this, "index/active.version")
        result.files += backup.copyIfPresentTo(this, "index/active.ckb")
        result.files += backup.copyIfPresentTo(this, "index/vector-active.ckb")
        result.files += backup.copyIfPresentTo(this, "index/graph-nodes.ckb")
        result.files += backup.copyIfPresentTo(this, "index/graph-edges.ckb")
        result.ok = true
        result.diagnostic = "ok"
        result
    }

    public func saveScheduler(entries: ArrayList<ScheduleEntry>): Unit {
        var text = ""
        for (entry in entries) {
            text += "${escapeField(entry.name)}|${entry.intervalMinutes}|${entry.nextRunAt}|${entry.lastStartedAt}|${entry.lastSuccessAt}|${entry.lastFailureAt}|${entry.failureCount}|${entry.degraded}|${escapeField(entry.lastCursor)}|${escapeField(entry.lastSince)}|${escapeField(entry.activeVersion)}|${escapeField(entry.candidateVersion)}|${escapeField(entry.lastStatus)}|${entry.lastDurationMillis}|${entry.lastRequestCount}|${escapeField(joinStrings(entry.lastUpdatedDataKinds, ","))}|${entry.lastTruncated}|${entry.timeBudgetMillis}\n"
        }
        this.writeLines("metadata/scheduler.ckb", text)
    }

    public func loadScheduler(): ArrayList<ScheduleEntry> {
        let out = ArrayList<ScheduleEntry>()
        let text = this.readLines("metadata/scheduler.ckb")
        if (text == "") {
            return out
        }
        for (line in text.split("\n")) {
            if (line == "") {
                continue
            }
            let parts = line.split("|")
            if (parts.size < 13) {
                continue
            }
            let entry = ScheduleEntry(unescapeField(parts[0]), parseIntField(parts[1], 0), parseIntField(parts[2], 0))
            entry.lastStartedAt = parseIntField(parts[3], -1)
            entry.lastSuccessAt = parseIntField(parts[4], -1)
            entry.lastFailureAt = parseIntField(parts[5], -1)
            entry.failureCount = parseIntField(parts[6], 0)
            entry.degraded = parts[7] == "true"
            entry.lastCursor = unescapeField(parts[8])
            entry.lastSince = unescapeField(parts[9])
            entry.activeVersion = unescapeField(parts[10])
            entry.candidateVersion = unescapeField(parts[11])
            entry.lastStatus = unescapeField(parts[12])
            if (parts.size >= 18) {
                entry.lastDurationMillis = parseIntField(parts[13], 0)
                entry.lastRequestCount = parseIntField(parts[14], 0)
                let kinds = unescapeField(parts[15])
                if (kinds != "") {
                    for (kind in kinds.split(",")) {
                        let cleaned = kind.trimAscii()
                        if (cleaned != "") {
                            entry.lastUpdatedDataKinds.add(cleaned)
                        }
                    }
                }
                entry.lastTruncated = parts[16] == "true"
                entry.timeBudgetMillis = parseIntField(parts[17], 0)
            }
            out.add(entry)
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

    private func copyIfPresentTo(destination: FileKnowledgeStore, relative: String): Int64 {
        if (!this.has(relative)) {
            return 0
        }
        destination.writeLines(relative, this.readLines(relative))
        1
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
            out += "${escapeField(record.id)}|${escapeField(record.title)}|${escapeField(record.chunk)}|${escapeField(record.metadata.knowledgeVersion)}|${escapeField(record.metadata.sourceId)}|${escapeField(record.metadata.sourceType)}|${escapeField(record.metadata.trustLevel)}|${escapeField(record.metadata.reviewState)}|${escapeField(record.citation)}|${vectorToLine(record.vector)}\n"
        }
        out
    }

    private func parseVector(text: String): ArrayList<VectorRecord> {
        let out = ArrayList<VectorRecord>()
        if (text == "") {
            return out
        }
        for (line in text.split("\n")) {
            if (line == "") {
                continue
            }
            let parts = line.split("|")
            if (parts.size >= 10) {
                out.add(this.vectorRecordFromParts(parts, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9))
            } else if (parts.size >= 8) {
                out.add(this.vectorRecordFromParts(parts, 0, -1, -1, 1, 2, 3, 4, 5, 6, 7))
            }
        }
        out
    }

    private func vectorRecordFromParts(parts: Array<String>, idIndex: Int64, titleIndex: Int64, chunkIndex: Int64, versionIndex: Int64, sourceIdIndex: Int64, sourceTypeIndex: Int64, trustIndex: Int64, reviewIndex: Int64, citationIndex: Int64, vectorIndex: Int64): VectorRecord {
        let metadata = KnowledgeMetadata()
        metadata.knowledgeVersion = unescapeField(parts[versionIndex])
        metadata.sourceId = unescapeField(parts[sourceIdIndex])
        metadata.sourceType = unescapeField(parts[sourceTypeIndex])
        metadata.trustLevel = unescapeField(parts[trustIndex])
        metadata.reviewState = unescapeField(parts[reviewIndex])
        let record = VectorRecord()
        record.id = unescapeField(parts[idIndex])
        record.title = if (titleIndex >= 0) { unescapeField(parts[titleIndex]) } else { "" }
        record.chunk = if (chunkIndex >= 0) { unescapeField(parts[chunkIndex]) } else { "" }
        record.metadata = metadata
        record.citation = unescapeField(parts[citationIndex])
        record.vector = parseVectorValues(parts[vectorIndex])
        record
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
    public var activeStateSource: String = ""
    public var vectorActiveCollection: String = "active"
    public var vectorCandidateCollection: String = "candidate"

    public init() {}
}

public class ActiveSnapshot {
    public var valid: Bool = false
    public var diagnostic: String = ""
    public var activeVersion: String = ""
    public var candidateVersion: String = ""
    public var failedVersion: String = ""
    public var activeStateSource: String = ""
    public var rawRecords: ArrayList<RawRecord> = ArrayList<RawRecord>()
    public var normalizedRecords: ArrayList<NormalizedRecord> = ArrayList<NormalizedRecord>()
    public var activeIndex: ArrayList<NormalizedRecord> = ArrayList<NormalizedRecord>()
    public var vectorActiveCollection: String = "active"
    public var vectorCandidateCollection: String = "candidate"
    public var vectorRecords: ArrayList<VectorRecord> = ArrayList<VectorRecord>()
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
        "tools: cangjie.health,cangjie.status,cangjie.query,cangjie.evidence,cangjie.sync,cangjie.rebuild,cangjie.source_analysis,cangjie.source_search,cangjie.doc_search,cangjie.website_search,cangjie.web_candidate_search,cangjie.hybrid_search,cangjie.evidence_pack,cangjie.knowledge_pack,cangjie.syntax_query,cangjie.api_search,cangjie.cookbook,cangjie.diagnose,cangjie.examples,cangjie.corpus_status,cangjie.version_resolve,cangjie.task_knowledge_pack,cangjie.knowledge_coverage,cangjie.compile_diagnose_v2,cangjie.symbol_lookup,cangjie.doc_section,cangjie.corpus_freshness,cangjie.tool_manual,cangjie.negative_rules,cangjie.schedules,cangjie.gitcode_repository_changed,cangjie.admin_scheduler_run,cangjie.admin_repositories_sync,cangjie.admin_repo_list_refresh,cangjie.admin_initialize; mcpTransports=stdio,streamable-http mcpEndpoint=/mcp mcpProtocolVersions=2024-11-05,2025-06-18 mcpSse=true; apiVersion=ckb-http-v1 envelope={ok,apiVersion,data|error,diagnostics}; input: query{q,budget<=20,sourceType,includeCandidates=false}, evidence_pack{q,budget<=20,includeCandidates,parentUrl,repo,ref}, cangjie_knowledge_pack{task,targetVersion=1.0.0,budget<=20,includeExamples,includeAntiPatterns,legacy_endpoint_degraded=true}, cangjie_version_resolve{targetVersion,sourceSet,sourceFamily,sourceRepo,sourceRef,refKind,versionPolicy=default|exact,includePrerelease=false}, cangjie_task_knowledge_pack{taskId,benchmark,taskText,signature,imports,argTypes,returnType,expectedKnowledgeTags,starterCodeExcerpt,compilerOutput,targetVersion,sourceSet,sourceRef,versionPolicy,budget<=20}, cangjie_knowledge_coverage{same fields as cangjie_task_knowledge_pack}, cangjie_compile_diagnose_v2{code,compilerOutput,context,targetVersion,sourceSet,sourceRef,budget<=20,executed=false}, cangjie_symbol_lookup{symbol,module,sourceSet,targetVersion,budget<=20}, cangjie_doc_section{sectionId,path,heading,targetVersion,budget<=20}, cangjie_corpus_freshness{readOnly=true}, cangjie_tool_manual{tool,command,targetVersion,budget<=20}, cangjie_negative_rules{q,query,targetVersion,budget<=20}, cangjie_api_search{q,module,symbol,sourceSet,targetVersion,budget<=20}, cangjie_syntax_query{q,targetVersion,budget<=20}, cangjie_cookbook{task,constraints,targetVersion,style,budget<=20}, cangjie_diagnose{code,compilerOutput,context,targetVersion,budget<=20,executed=false}, cangjie_examples{q,module,symbol,maxExamples<=20}, cangjie_corpus_status{readOnly=true}, source_analysis{repo,ref,query,issueUrl,prUrl,changedFiles,candidatePaths,allowCloneFallback,maxFiles,maxBytes,timeoutMillis,visibility=public,retainFailedWorkspace=false}, gitcode_repository_changed{contractVersion=gcm-ckb-repository-change-v1,provider=gitcode,eventType=merge_request,reason=pr_merged,repo,ref,prNumber,changedFiles}, admin_scheduler_run{limit,taskNames,force,reason,requestedBy,source}, admin_repositories_sync{repo,ref,profile,changedFiles,prNumber,mode,reason}, admin_repo_list_refresh{repo,ref,paths,prNumber,mode,reason}, admin_initialize{dryRun,apply,docsRoot,toolDocsRoot,stdRoot,stdxRoot,evalRoot,targetVersion}, sync{dryRun,apply,maxRepos,maxFilesPerRepo,maxItems,since}, rebuild{store}; liveGitCode: officialApi=https://api.gitcode.com/api/v5 authMode=token authHeader=private-token tokenFile=tokenFile tokenFileFormat=single PAT line without token/Bearer/PRIVATE-TOKEN prefix; sourceAnalysis: defaultEnabled=false workspaceRoot=TMPDIR-or-tmp/ckb-source-analysis publicOnly=true cloneHostAllowlist=gitcode.com cleanup=default; acceptance: schema -> doctor/status -> anonymous dry-run -> credentialed dry-run if needed -> limited apply -> rebuild-index -> status/evidence -> source_analysis fake/public repo; output: ok,status,errorCode,interfaceId,contentFamily,updateMechanism,activeKnowledgeVersion,knowledgeVersion,targetVersion,versionResolution,versionResolutionId,queryPlan,coverage,matchedItems,requiredKnowledge,citations,evidenceHash,provenance,evidence,requiresReview,triggerReasons,sourceAcquisition,filesRead,cleanupStatus,truncated,degraded,transportDiagnostic,scheduledProfiles; boundary: MCP JSON-RPC server exposes only read-only Cangjie tools/resources/prompts through stdio and /mcp; cangjie diagnose is knowledge-only; cangjie compile_diagnose_v2 is query-plan only and does not execute code; verify-snippet/admin/update/repository sync/event tools are not exposed to ordinary MCP clients; redaction: never returns tokenRef,tokenFile contents,PRIVATE-TOKEN,Authorization,Cookie,private-token values,absolute local paths; errors: ckb.bad_request,ckb.unauthorized,ckb.not_found,ckb.network_disabled,ckb.auth_degraded,ckb.rate_limited,ckb.source_unavailable,ckb.rebuild_failed,ckb.validation_failed,ckb.invalid_workspace_root,ckb.invalid_clone_host,version_not_resolved,unsupported_source_set"
    }

    public static func httpLikeRoutes(): String {
        "routes: STDIO ckb-stdio-v1 health,status,metrics,query <text>,evidence <text>,source_analysis repo=<owner/repo> ref=<ref> path=<path> query=<text> allowCloneFallback=<bool>,sync,cangjie_initialize,rebuild,scheduler-run,backup <name>,restore <name>,restart,stop; MCP stdio command mcp-stdio; MCP Streamable HTTP GET /mcp -> text/event-stream SSE ready/keepalive, POST /mcp -> JSON-RPC request JSON response or notification 202 empty, DELETE /mcp -> session close 202; legacy HTTP-like aliases GET /health -> ok,status,activeKnowledgeVersion,degraded; GET /status -> storage,indexManifest,scheduler,activeKnowledgeVersion,restoreDiagnostic,authHeaderStrategy,sourceAnalysis; POST /query -> query,evidence,citations,knowledgeVersion; POST /evidence -> evidencePack,graphContext,citations,activeKnowledgeVersion; POST /sync -> dryRun|apply,candidateVersion,activeKnowledgeVersion,redactedSourceStatus,transportDiagnostic; POST /rebuild-index -> candidateVersion,activeKnowledgeVersion,count; JSON ckb-http-v1 envelope={ok,apiVersion,data|error,diagnostics}; GET /v1/health -> status,activeKnowledgeVersion,degraded,schedulerDegraded; GET /v1/status -> storage,indexManifest,scheduler,activeKnowledgeVersion,restoreDiagnostic,authHeaderStrategy,sourceAnalysis; GET /v1/schedules -> entries interval,nextRunAt,lastSuccessAt,failureCount,lastDurationMillis,lastRequestCount,lastUpdatedDataKinds; GET /v1/schema -> routes,tools,errorCodes,apiVersion,limits,mcpTransports,mcpEndpoint,mcpSse; GET /v1/cangjie/corpus/status -> docsUrls,stdSources,activeKnowledgeVersion; GET /v1/cangjie/llms.txt -> markdown,knowledgeVersion; GET /v1/cangjie/llms-full.txt -> markdown,knowledgeVersion; POST /v1/cangjie/knowledge-pack -> knowledgeVersion,targetVersion,items,apiItems,examples,citations,truncated,degraded,legacy_endpoint_degraded; POST /v1/cangjie/version/resolve -> targetVersion,versionResolutionId,sources,diagnostics; POST /v1/cangjie/task-knowledge-pack -> interfaceId,contentFamily,updateMechanism,versionResolution,queryPlan,coverage,diagnostics; POST /v1/cangjie/knowledge-coverage -> required,coveredCount,missingCount,coveragePass; POST /v1/cangjie/compile-diagnose-v2 -> interfaceId,contentFamily,updateMechanism,versionResolution,queryPlan,coverage,executed=false; POST /v1/cangjie/syntax-query -> interfaceId,contentFamily,updateMechanism,matchedItems,requiredKnowledge,queryPlan,coverage,citations,evidenceHash,provenance,syntaxItems; POST /v1/cangjie/api-search -> interfaceId,contentFamily,updateMechanism,matchedItems,requiredKnowledge,queryPlan,coverage,citations,evidenceHash,provenance,apiItems; POST /v1/cangjie/cookbook -> interfaceId,contentFamily,updateMechanism,matchedItems,requiredKnowledge,queryPlan,coverage,citations,evidenceHash,provenance,steps; POST /v1/cangjie/diagnose -> interfaceId,contentFamily,updateMechanism,matchedItems,requiredKnowledge,queryPlan,coverage,diagnostics,executed=false,citations,evidenceHash,provenance; POST /v1/cangjie/examples -> interfaceId,contentFamily,updateMechanism,matchedItems,requiredKnowledge,queryPlan,coverage,examples,citations,evidenceHash,provenance; POST /v1/cangjie/context-pack -> markdown,citations; POST /v1/query -> rows,citations,knowledgeVersion,truncated; POST /v1/evidence-pack -> evidencePack,graphContext,citations,knowledgeVersion; POST /v1/source-analysis -> analysisId,repo,ref,triggerReasons,sourceAcquisition,filesRead,citations,degraded,cleanupStatus; POST /v1/events/gitcode/repository-changed -> accepted|duplicate|rejected,dedupeKey,scheduledProfiles; POST /v1/admin/scheduler/run -> ran,succeeded,failed,degraded,details; POST /v1/admin/repositories/sync -> repo,profile,requestCount,updatedDataKinds,truncated,candidateVersion,activeKnowledgeVersion; POST /v1/admin/repo-list/refresh -> matchedPaths,repoCount,candidateRepoListVersion,activeRepoListVersion,diagnostics; POST /v1/admin/sync -> source status,candidateVersion,activeKnowledgeVersion,transportDiagnostic; POST /v1/admin/initialize -> dryRun,persisted,activeKnowledgeVersion,candidateKnowledgeVersion,validation,sources; POST /v1/admin/rebuild -> candidateVersion,activeKnowledgeVersion,count; planned_not_enabled: /v1/cangjie/verify-snippet; compatibility: CLI service/status/rebuild-index/source_analysis provide the canonical local protocol"
    }
}

public class CkbScheduleTaskProfile {
    public var enabled: Bool = false
    public var status: String = "unsupported"
    public var profile: String = ""
    public var networkGate: String = "network_required"
    public var candidateMode: String = "none"
    public var timeBudgetMillis: Int64 = 0
    public var requestCount: Int64 = 0
    public var updatedDataKinds: ArrayList<String> = ArrayList<String>()
    public var sourceFamilies: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public func ckbSchedulerAllowlistTaskNames(): ArrayList<String> {
    let names = ArrayList<String>()
    names.add("community_repo_discovery_30d")
    names.add("docs_probe_30d")
    names.add("website_probe_weekly")
    names.add("website_full_weekly")
    names.add("web_candidate_weekly")
    names.add("web_candidate_recrawl_30d")
    names.add("weekly_full_rebuild")
    names.add("cangjie_freshness_daily")
    names.add("cangjie_docs_full_weekly")
    names.add("cangjie_release_full_sync")
    names.add("cangjie_source_event_sync")
    names.add("cangjie_version_branch_refresh")
    names.add("cangjie_benchmark_gap_curation")
    names
}

public func ckbSyncProfileForScheduleTask(name: String): CkbScheduleTaskProfile {
    let profile = CkbScheduleTaskProfile()
    if (name == "community_repo_discovery_30d") {
        profile.enabled = true
        profile.status = "ready"
        profile.profile = "community_repo_discovery"
        profile.timeBudgetMillis = 60000
        profile.requestCount = 3
        profile.updatedDataKinds.add("repo_catalog")
    } else if (name == "docs_probe_30d") {
        profile.enabled = true
        profile.status = "ready"
        profile.profile = "docs_probe"
        profile.timeBudgetMillis = 60000
        profile.requestCount = 1
        profile.updatedDataKinds.add("docs")
    } else if (name == "website_probe_weekly") {
        profile.enabled = true
        profile.status = "ready"
        profile.profile = "website_probe"
        profile.timeBudgetMillis = 90000
        profile.requestCount = 3
        profile.updatedDataKinds.add("website")
    } else if (name == "website_full_weekly") {
        profile.enabled = true
        profile.status = "ready"
        profile.profile = "website_full"
        profile.timeBudgetMillis = 180000
        profile.requestCount = 3
        profile.updatedDataKinds.add("website")
    } else if (name == "web_candidate_weekly") {
        profile.enabled = true
        profile.status = "ready"
        profile.profile = "web_candidate_discovery"
        profile.timeBudgetMillis = 90000
        profile.requestCount = 2
        profile.updatedDataKinds.add("web_candidates")
    } else if (name == "web_candidate_recrawl_30d") {
        profile.enabled = true
        profile.status = "ready"
        profile.profile = "web_candidate_recrawl"
        profile.timeBudgetMillis = 90000
        profile.requestCount = 2
        profile.updatedDataKinds.add("web_candidates")
    } else if (name == "weekly_full_rebuild") {
        profile.enabled = true
        profile.status = "ready"
        profile.profile = "full_rebuild"
        profile.candidateMode = "rebuild_candidate_then_promote"
        profile.timeBudgetMillis = 120000
        profile.requestCount = 1
        profile.updatedDataKinds.add("index")
    } else if (name == "cangjie_freshness_daily") {
        profile.enabled = true
        profile.status = "ready"
        profile.profile = "cangjie_freshness_probe"
        profile.candidateMode = "probe_only"
        profile.timeBudgetMillis = 60000
        profile.requestCount = 5
        profile.updatedDataKinds.add("freshness")
        profile.updatedDataKinds.add("version_manifest")
        ckbAddCangjieSourceFamilies(profile)
    } else if (name == "cangjie_docs_full_weekly") {
        profile.enabled = true
        profile.status = "ready"
        profile.profile = "cangjie_docs_full_sync"
        profile.candidateMode = "candidate_validate_promote"
        profile.timeBudgetMillis = 180000
        profile.requestCount = 5
        profile.updatedDataKinds.add("docs")
        profile.updatedDataKinds.add("serving_feed")
        profile.sourceFamilies.add("docs")
    } else if (name == "cangjie_release_full_sync") {
        profile.enabled = true
        profile.status = "ready"
        profile.profile = "cangjie_release_full_sync"
        profile.candidateMode = "candidate_validate_promote"
        profile.timeBudgetMillis = 240000
        profile.requestCount = 5
        profile.updatedDataKinds.add("release")
        profile.updatedDataKinds.add("version_manifest")
        ckbAddCangjieSourceFamilies(profile)
    } else if (name == "cangjie_source_event_sync") {
        profile.enabled = true
        profile.status = "ready"
        profile.profile = "cangjie_source_event_sync"
        profile.candidateMode = "candidate_validate_promote"
        profile.timeBudgetMillis = 120000
        profile.requestCount = 4
        profile.updatedDataKinds.add("repo_source")
        profile.updatedDataKinds.add("serving_feed")
        profile.sourceFamilies.add("std")
        profile.sourceFamilies.add("stdx")
        profile.sourceFamilies.add("tools")
    } else if (name == "cangjie_version_branch_refresh") {
        profile.enabled = true
        profile.status = "ready"
        profile.profile = "cangjie_version_branch_refresh"
        profile.candidateMode = "manifest_candidate"
        profile.timeBudgetMillis = 60000
        profile.requestCount = 5
        profile.updatedDataKinds.add("version_manifest")
        ckbAddCangjieSourceFamilies(profile)
    } else if (name == "cangjie_benchmark_gap_curation") {
        profile.enabled = true
        profile.status = "ready"
        profile.profile = "cangjie_benchmark_gap_curation"
        profile.networkGate = "offline_visible_artifacts_only"
        profile.candidateMode = "curated_candidate_validate_promote"
        profile.timeBudgetMillis = 90000
        profile.requestCount = 0
        profile.updatedDataKinds.add("benchmark_gap_curation")
        profile.updatedDataKinds.add("negative_rules")
    }
    profile
}

private func ckbAddCangjieSourceFamilies(profile: CkbScheduleTaskProfile): Unit {
    profile.sourceFamilies.add("docs")
    profile.sourceFamilies.add("std")
    profile.sourceFamilies.add("stdx")
    profile.sourceFamilies.add("tools")
    profile.sourceFamilies.add("eval-support")
}

public func ckbProfilesForRepositoryChangedEvent(event: GitCodeRepositoryChangedEvent, config: CkbRuntimeConfig): ArrayList<String> {
    let profiles = ArrayList<String>()
    if (event.changedFilesUnavailable || event.changedFiles.size == 0) {
        profiles.add("items")
        return profiles
    }
    var repoSource = false
    var repoList = false
    for (path in event.changedFiles) {
        let lowered = path.toAsciiLower()
        if (ckbRepoListTriggerPath(lowered)) {
            repoList = true
        }
        if (ckbRepositorySourceTriggerPath(lowered)) {
            repoSource = true
        }
    }
    if (repoSource) {
        profiles.add("repo_source_and_items")
    } else {
        profiles.add("items")
    }
    if (repoList) {
        profiles.add("repo_list_refresh")
    }
    profiles
}

public class CkbSchedulerTaskRunner <: SchedulerTaskRunner {
    private let kb: KnowledgeBase
    private let config: CkbRuntimeConfig
    private let store: FileKnowledgeStore
    private let sourceRunner: SourceFetchRunner

    public init(kb: KnowledgeBase, config: CkbRuntimeConfig, store: FileKnowledgeStore, sourceRunner!: SourceFetchRunner = DisabledNetworkFetchRunner()) {
        this.kb = kb
        this.config = config
        this.store = store
        this.sourceRunner = sourceRunner
    }

    private func runtimeVersionManifest(): CangjieVersionManifest {
        let stored = this.store.loadCangjieVersionManifest()
        if (stored.sources.size > 0) {
            return stored
        }
        ckbRuntimeCangjieVersionManifest(this.config)
    }

    public func runTask(name: String, since: String): SchedulerTaskResult {
        let result = SchedulerTaskResult()
        result.since = if (since == "") { "0" } else { since }
        let profile = ckbSyncProfileForScheduleTask(name)
        result.timeBudgetMillis = profile.timeBudgetMillis
        for (kind in profile.updatedDataKinds) {
            result.updatedDataKinds.add(kind)
        }
        if (!profile.enabled) {
            result.ok = false
            result.status = profile.status
            return result
        }
        if (name == "weekly_full_rebuild") {
            let rebuild = ckbRebuildIndex(this.kb, this.store)
            result.ok = rebuild.ok
            result.status = if (rebuild.ok) { "rebuild_ok" } else { "rebuild_failed" }
            result.cursor = "rebuild-${rebuild.activeVersion}"
            result.activeVersion = rebuild.activeVersion
            result.candidateVersion = rebuild.candidateVersion
            result.requestCount = profile.requestCount
            result.durationMillis = profile.timeBudgetMillis / 10
            return result
        }
        if (profile.profile == "cangjie_freshness_probe") {
            let freshness = probeCangjieCorpusFreshness(this.runtimeVersionManifest(), this.sourceRunner)
            let status = this.kb.status()
            result.ok = freshness.ok && !freshness.degraded
            result.status = if (result.ok) { "freshness_probe_ok" } else { "freshness_probe_degraded" }
            result.cursor = stableSummaryHash("${freshness.targetVersion}:${freshness.sources.size}:${freshness.degraded}")
            result.since = "${this.kb.scheduler.clock.nowMinutes}"
            result.activeVersion = status.activeKnowledgeVersion
            result.candidateVersion = status.candidateKnowledgeVersion
            result.requestCount = freshness.sources.size
            result.durationMillis = profile.timeBudgetMillis / 10
            return result
        }
        let manifest = this.runtimeVersionManifest()
        let fetch = ckbRunScheduledProfileFetches(profile, this.sourceRunner, this.config, manifest)
        fetch.runId = "${this.kb.scheduler.clock.nowMinutes}"
        let ingest = ingestScheduledProfileSources(this.kb, this.store, profile, fetch, this.config, manifest)
        let status = this.kb.status()
        result.ok = fetch.ok && ingest.ok
        result.status = if (result.ok) { ingest.status } else { if (ingest.status != "") { ingest.status } else { "profile_degraded" } }
        result.cursor = "cursor-${status.activeKnowledgeVersion}"
        result.since = "${this.kb.scheduler.clock.nowMinutes}"
        result.activeVersion = status.activeKnowledgeVersion
        result.candidateVersion = status.candidateKnowledgeVersion
        result.requestCount = fetch.requestCount
        result.truncated = fetch.truncated
        result.durationMillis = profile.timeBudgetMillis / 10
        result.validationStatus = ingest.validationStatus
        result.validationSummary = ingest.validationSummary
        result.validationEvidenceHash = ingest.validationEvidenceHash
        for (diagnostic in ingest.validationDiagnostics) {
            result.validationDiagnostics.add(diagnostic)
        }
        result
    }
}

public class CkbServiceResponse {
    public var text: String = ""
    public var shouldStop: Bool = false

    public init() {}
}

public class CkbCommandLoopService {
    private let config: CkbRuntimeConfig
    private let store: FileKnowledgeStore
    private let sourceRunner: SourceFetchRunner
    private var kb: KnowledgeBase
    private let adminOperationGate: CkbAdminOperationGate = CkbAdminOperationGate()
    private var started: Bool = false
    private var acceptedEventDedupeKeys: ArrayList<String> = ArrayList<String>()
    private var acceptedEventCount: Int64 = 0
    private var rebuildCount: Int64 = 0

    public init(config: CkbRuntimeConfig, store: FileKnowledgeStore, sourceRunner!: SourceFetchRunner = DisabledNetworkFetchRunner()) {
        this.config = config
        this.store = store
        this.sourceRunner = sourceRunner
        this.kb = newKnowledgeBaseFromStoreWithRuntime(store, config).kb
    }

    public func start(): String {
        this.started = true
        if (this.config.firstInitEnabled) {
            let result = ckbEnsureFirstInitialized(this.config, this.store)
            if (result.ok && result.persisted) {
                this.reloadKnowledgeBase()
            }
        }
        this.logLine("info", "service_started")
    }

    public func handleLine(line: String): CkbServiceResponse {
        if (!this.started) {
            this.started = true
        }
        let response = CkbServiceResponse()
        let cleaned = line.trimAscii()
        if (cleaned == "") {
            response.text = "error code=empty_command\n"
            return response
        }
        let command = firstToken(cleaned)
        let tail = lineTail(cleaned, command)
        if (command == "health") {
            response.text = this.health()
        } else if (command == "status") {
            response.text = renderDoctor(this.kb.status())
        } else if (command == "metrics") {
            response.text = renderMetrics(this.kb.status())
        } else if (command == "query") {
            response.text = renderQuery(cangjie_evidence_pack(this.kb, if (tail == "") { "func syntax" } else { tail }, 5))
        } else if (command == "evidence") {
            response.text = renderQuery(cangjie_evidence_pack(this.kb, if (tail == "") { "HttpClient" } else { tail }, 3))
        } else if (command == "cangjie_knowledge_pack") {
            response.text = renderCangjieKnowledgePackMarkdown(this.cangjieKnowledgePack(if (tail == "") { "Cangjie language context" } else { tail }))
        } else if (command == "cangjie_api_search") {
            response.text = renderCangjieKnowledgePackMarkdown(this.cangjieApiSearch(if (tail == "") { "stdx JSON" } else { tail }))
        } else if (command == "cangjie_syntax_query") {
            response.text = renderCangjieKnowledgePackMarkdown(this.cangjieSyntaxQuery(if (tail == "") { "function syntax" } else { tail }))
        } else if (command == "cangjie_cookbook") {
            response.text = renderCangjieContextPack(this.cangjieCookbook(if (tail == "") { "Cangjie task" } else { tail }))
        } else if (command == "cangjie_diagnose") {
            response.text = renderCangjieKnowledgePackMarkdown(this.cangjieDiagnose("", if (tail == "") { "Cangjie compiler diagnostic" } else { tail }))
        } else if (command == "cangjie_corpus_status") {
            response.text = renderCangjieCorpusStatus(this.cangjieCorpusStatus())
        } else if (command == "source_analysis" || command == "source-analysis") {
            var request = sourceAnalysisRequestFromText(tail)
            if (request.repo == "") {
                request = parseSourceAnalysisCommand(tail)
            }
            if (request.allowCloneFallback && this.config.sourceAnalysisEnabled) {
                request.visibility = request.repoVisibility
                request.selector = request.query
                response.text = renderSourceAnalysis(cangjie_source_analysis(this.config, request))
            } else {
                response.text = renderSourceAnalysis(ckbSourceAnalysis(request, runner: this.sourceRunner))
            }
        } else if (command == "sync") {
            let result = this.runSync(body: "{\"mode\":\"apply\",\"maxItems\":3}")
            response.text = "sync status=${result.status} degraded=${result.degraded} activeKnowledgeVersion=${result.activeKnowledgeVersion} candidateKnowledgeVersion=${result.candidateKnowledgeVersion} diagnostic=${result.diagnostic}\n"
        } else if (command == "cangjie_initialize" || command == "cangjie-initialize" || command == "initialize") {
            response.text = renderCkbFirstInitResult(this.runFirstInitialization(body: tail))
        } else if (command == "rebuild") {
            let result = this.runRebuild()
            response.text = "rebuild ok=${result.ok} activeKnowledgeVersion=${result.activeVersion} candidateKnowledgeVersion=${result.candidateVersion} count=${result.count}\n"
        } else if (command == "scheduler-run") {
            let result = this.runScheduler(1)
            response.text = "scheduler ran=${result.ran} succeeded=${result.succeeded} failed=${result.failed} degraded=${result.degraded}\n${result.details}"
        } else if (command == "backup") {
            response.text = renderBackupRestore(this.store.backupActiveSnapshot(tail))
        } else if (command == "restore") {
            let result = this.store.restoreActiveSnapshotBackup(tail)
            if (result.ok) {
                this.reloadKnowledgeBase()
            }
            response.text = renderBackupRestore(result)
        } else if (command == "restart") {
            this.reloadKnowledgeBase()
            response.text = this.logLine("info", "service_restarted")
        } else if (command == "stop" || command == "shutdown" || command == "exit") {
            response.text = this.logLine("info", "service_stopped")
            response.shouldStop = true
        } else {
            response.text = "error code=unknown_command command=${redactSensitive(command)} protocol=ckb-stdio-v1\n"
        }
        response.text = redactSensitive(response.text)
        response
    }

    public func statusSnapshot(): KnowledgeStatus {
        this.kb.status()
    }

    public func queryEvidencePack(query: String, budget: Int64, includeCandidates!: Bool = true): EvidencePack {
        let pack = cangjie_evidence_pack(this.kb, query, budget)
        if (!includeCandidates) {
            pack.webCandidateEvidence.clear()
        }
        pack
    }

    public func activeVersionManifest(): CangjieVersionManifest {
        let stored = this.store.loadCangjieVersionManifest()
        if (stored.sources.size > 0) {
            return stored
        }
        ckbRuntimeCangjieVersionManifest(this.config)
    }

    private func cangjieCapabilityService(): CangjieCapabilityService {
        CangjieCapabilityService(this.kb, manifest: this.activeVersionManifest())
    }

    public func cangjieKnowledgePack(task: String, targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET, includeExamples!: Bool = true, includeAntiPatterns!: Bool = true): CangjieKnowledgePack {
        this.cangjieCapabilityService().knowledgePack(task, targetVersion: targetVersion, budget: budget, includeExamples: includeExamples, includeAntiPatterns: includeAntiPatterns)
    }

    public func cangjieResolveVersion(selector: CangjieVersionSelector): CangjieVersionResolution {
        this.cangjieCapabilityService().resolveVersion(selector)
    }

    public func cangjieTaskKnowledgePack(request: CangjieTaskKnowledgeRequest): CangjieTaskKnowledgePack {
        this.cangjieCapabilityService().taskKnowledgePack(request)
    }

    public func cangjieKnowledgeCoverage(request: CangjieTaskKnowledgeRequest): CangjieKnowledgeCoverage {
        this.cangjieCapabilityService().knowledgeCoverage(request)
    }

    public func cangjieCompileDiagnoseV2(code: String, compilerOutput: String, context!: String = "", targetVersion!: String = "", sourceSet!: String = "", sourceRef!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieTaskKnowledgePack {
        this.cangjieCapabilityService().compileDiagnoseV2(code, compilerOutput, context: context, targetVersion: targetVersion, sourceSet: sourceSet, sourceRef: sourceRef, budget: budget)
    }

    public func cangjieApiSearch(query: String, module!: String = "", symbol!: String = "", sourceSet!: String = "", targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieKnowledgePack {
        this.cangjieCapabilityService().apiSearch(query, module: module, symbol: symbol, sourceSet: sourceSet, targetVersion: targetVersion, budget: budget)
    }

    public func cangjieSyntaxQuery(query: String, targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieKnowledgePack {
        this.cangjieCapabilityService().syntaxQuery(query, targetVersion: targetVersion, budget: budget)
    }

    public func cangjieCookbook(task: String, constraints!: String = "", targetVersion!: String = "", style!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieKnowledgePack {
        this.cangjieCapabilityService().cookbook(task, constraints: constraints, targetVersion: targetVersion, style: style, budget: budget)
    }

    public func cangjieDiagnose(code: String, compilerOutput: String, context!: String = "", targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieKnowledgePack {
        this.cangjieCapabilityService().diagnose(code, compilerOutput, context: context, targetVersion: targetVersion, budget: budget)
    }

    public func cangjieExamples(query: String, module!: String = "", symbol!: String = "", maxExamples!: Int64 = CangjieCapabilityLimits.DEFAULT_EXAMPLE_LIMIT, targetVersion!: String = ""): CangjieKnowledgePack {
        this.cangjieCapabilityService().examples(query, module: module, symbol: symbol, maxExamples: maxExamples, targetVersion: targetVersion)
    }

    public func cangjieSymbolLookup(symbol: String, module!: String = "", sourceSet!: String = "", targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieKnowledgePack {
        this.cangjieCapabilityService().symbolLookup(symbol, module: module, sourceSet: sourceSet, targetVersion: targetVersion, budget: budget)
    }

    public func cangjieDocSection(sectionId: String, path!: String = "", heading!: String = "", targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieKnowledgePack {
        this.cangjieCapabilityService().docSection(sectionId, path: path, heading: heading, targetVersion: targetVersion, budget: budget)
    }

    public func cangjieToolManual(tool: String, command!: String = "", targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieKnowledgePack {
        this.cangjieCapabilityService().toolManual(tool, command: command, targetVersion: targetVersion, budget: budget)
    }

    public func cangjieNegativeRules(query: String, targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieKnowledgePack {
        this.cangjieCapabilityService().negativeRules(query, targetVersion: targetVersion, budget: budget)
    }

    public func cangjieCorpusStatus(): CangjieCorpusStatus {
        this.cangjieCapabilityService().corpusStatus()
    }

    public func cangjieCorpusFreshness(): CangjieCorpusFreshnessReport {
        cangjieCorpusFreshnessReport(this.kb.status(), manifest: this.activeVersionManifest())
    }

    public func runSourceAnalysis(request: SourceAnalysisRequest): SourceAnalysisResult {
        if (request.allowCloneFallback && this.config.sourceAnalysisEnabled) {
            let pack = cangjie_source_analysis(this.config, request)
            return sourceAnalysisResultFromPack(pack)
        }
        ckbSourceAnalysis(request, runner: this.sourceRunner)
    }

    public func runSync(body!: String = ""): CkbAdminOperationResult {
        let busy = this.tryEnterAdminOperation("sync")
        if (busy != "") {
            return this.adminBusyResult(busy)
        }
        let result = this.runSyncUnlocked(body: body)
        this.leaveAdminOperation("sync")
        result
    }

    private func runSyncUnlocked(body!: String = ""): CkbAdminOperationResult {
        let result = CkbAdminOperationResult()
        let mode = ckbServiceJsonStringField(body, "mode").trimAscii()
        let sourceSet = ckbServiceJsonStringField(body, "sourceSet").trimAscii()
        if (sourceSet != "" && !ckbServiceCangjieSourceSetAllowed(sourceSet)) {
            return ckbRejectedAdminResult(result, "unsupported_source_set")
        }
        if (mode == "rollback") {
            let status = this.kb.status()
            result.status = "ok"
            result.degraded = false
            result.diagnostic = "rollback_active_preserved"
            result.activeKnowledgeVersion = status.activeKnowledgeVersion
            result.candidateKnowledgeVersion = status.candidateKnowledgeVersion
            result.updatedDataKinds.add("rollback")
            return result
        }
        let options = LiveSyncOptions()
        options.apply = mode != "dry-run"
        options.dryRun = !options.apply
        options.maxItems = ckbServiceJsonIntField(body, "maxItems", 3)
        options.maxRepos = ckbServiceJsonIntField(body, "maxRepos", -1)
        options.maxFilesPerRepo = ckbServiceJsonIntField(body, "maxFilesPerRepo", -1)
        options.since = ckbServiceJsonStringField(body, "since")
        let text = ckbSyncLive(this.kb, this.config, options, runner: this.sourceRunner, store: this.store)
        result.status = if (text.contains("summary") && !text.contains("usage error")) { if (options.apply) { "candidate_sync_ok" } else { "delta_sync_dry_run_ok" } } else { "degraded" }
        result.degraded = result.status != "ok"
        if (result.status == "candidate_sync_ok" || result.status == "delta_sync_dry_run_ok") {
            result.degraded = false
        }
        result.diagnostic = text
        result.requestCount = options.maxItems
        result.updatedDataKinds.add(if (sourceSet == "") { "live_sync" } else { "live_sync_${sourceSet}" })
        let status = this.kb.status()
        result.activeKnowledgeVersion = status.activeKnowledgeVersion
        result.candidateKnowledgeVersion = status.candidateKnowledgeVersion
        result
    }

    public func runFirstInitialization(body!: String = ""): CkbFirstInitResult {
        let busy = this.tryEnterAdminOperation("first_initialization")
        if (busy != "") {
            let result = CkbFirstInitResult()
            result.diagnostics.add(busy)
            return result
        }
        let result = this.runFirstInitializationUnlocked(body: body)
        this.leaveAdminOperation("first_initialization")
        result
    }

    private func runFirstInitializationUnlocked(body!: String = ""): CkbFirstInitResult {
        let options = ckbFirstInitOptionsFromRuntime(this.config, apply: true, dryRun: false)
        this.applyFirstInitializationBodyOverrides(options, body)
        let result = runCkbFirstInitializationWithActiveGuard(options, this.store)
        if (result.ok && result.persisted) {
            this.reloadKnowledgeBase()
        }
        result
    }

    public func acceptGitCodeRepositoryChangedEvent(event: GitCodeRepositoryChangedEvent): GitCodeRepositoryChangedEventResult {
        let result = GitCodeRepositoryChangedEventResult()
        result.dedupeKey = ckbRepositoryChangedDedupeKey(event)
        result.eventId = if (event.eventId != "") { event.eventId } else { "gcm-ckb-${stableSummaryHash(result.dedupeKey)}" }
        result.acceptedAt = "${this.kb.scheduler.clock.nowMinutes}"
        if (this.acceptedEventDedupeKeys.contains(result.dedupeKey)) {
            result.status = "duplicate"
            result.diagnostic = "dedupe_key_seen"
            return result
        }
        for (profile in ckbProfilesForRepositoryChangedEvent(event, this.config)) {
            result.scheduledProfiles.add(profile)
        }
        this.acceptedEventDedupeKeys.add(result.dedupeKey)
        this.acceptedEventCount += 1
        result.status = "accepted"
        let syncBody = ckbRepositoryEventSyncBody(event, result.scheduledProfiles)
        let sync = this.runRepositorySync(body: syncBody)
        if (result.scheduledProfiles.contains("repo_list_refresh")) {
            _ = this.runRepoListRefresh(body: ckbRepositoryEventRepoListBody(event))
        }
        result.diagnostic = if (sync.status == "ok" || sync.status == "candidate_promoted") { "immediate_sync_executed" } else { "scheduler_job_created:${sync.diagnostic}" }
        result
    }

    public func runRepositorySync(body!: String = ""): CkbAdminOperationResult {
        let busy = this.tryEnterAdminOperation("repository_sync")
        if (busy != "") {
            return this.adminBusyResult(busy)
        }
        let result = this.runRepositorySyncUnlocked(body: body)
        this.leaveAdminOperation("repository_sync")
        result
    }

    private func runRepositorySyncUnlocked(body!: String = ""): CkbAdminOperationResult {
        let result = CkbAdminOperationResult()
        result.repo = ckbServiceJsonStringField(body, "repo")
        result.ref = ckbServiceJsonStringField(body, "ref")
        result.profile = ckbServiceJsonStringField(body, "profile")
        result.prNumber = ckbServiceJsonIntField(body, "prNumber", 0)
        if (result.ref == "") {
            result.ref = "main"
        }
        if (result.profile == "") {
            result.profile = "items"
        }
        if (!ckbCommunityRepoAllowed(result.repo)) {
            return ckbRejectedAdminResult(result, "invalid_repo")
        }
        if (result.profile != "items" && result.profile != "repo_source_and_items") {
            return ckbRejectedAdminResult(result, "unsupported_profile")
        }
        for (path in ckbServiceJsonStringArrayField(body, "changedFiles")) {
            if (!ckbSafeRepoRelativePath(path)) {
                return ckbRejectedAdminResult(result, "invalid_changed_file")
            }
            result.matchedPaths.add(path)
        }
        if (result.profile == "repo_source_and_items") {
            result.updatedDataKinds.add("repo_source")
            let sync = ckbRunRepositoryChangedSourceSync(this.kb, this.store, this.sourceRunner, this.config, result.repo, result.ref, result.matchedPaths)
            result.requestCount = sync.requestCount
            result.truncated = sync.truncated
            result.status = if (sync.ok) { "candidate_promoted" } else { sync.status }
            result.degraded = !sync.ok
            result.diagnostic = sync.status
        } else {
            result.requestCount = 3
            result.status = "ok"
            result.degraded = false
            result.diagnostic = "repository_items_delta_scheduled"
        }
        result.updatedDataKinds.add("issues")
        result.updatedDataKinds.add("pull_requests")
        result.updatedDataKinds.add("comments")
        let status = this.kb.status()
        result.activeKnowledgeVersion = status.activeKnowledgeVersion
        result.candidateKnowledgeVersion = status.candidateKnowledgeVersion
        result
    }

    public func runRepoListRefresh(body!: String = ""): CkbAdminOperationResult {
        let result = CkbAdminOperationResult()
        result.repo = ckbServiceJsonStringField(body, "repo")
        result.ref = ckbServiceJsonStringField(body, "ref")
        result.prNumber = ckbServiceJsonIntField(body, "prNumber", 0)
        if (result.ref == "") {
            result.ref = "main"
        }
        if (!ckbCommunityRepoAllowed(result.repo)) {
            return ckbRejectedAdminResult(result, "invalid_repo")
        }
        for (path in ckbServiceJsonStringArrayField(body, "paths")) {
            if (!ckbSafeRepoRelativePath(path) || !ckbRepoListTriggerPath(path.toAsciiLower())) {
                return ckbRejectedAdminResult(result, "invalid_repo_list_path")
            }
            result.matchedPaths.add(path)
        }
        if (result.matchedPaths.size == 0) {
            return ckbRejectedAdminResult(result, "missing_repo_list_path")
        }
        result.status = "ok"
        result.degraded = false
        result.diagnostic = "repo_list_refresh_scheduled"
        result.profile = "repo_list_refresh"
        result.requestCount = result.matchedPaths.size
        result.repoCount = result.matchedPaths.size
        result.updatedDataKinds.add("repo_list")
        let version = "repo-list-${stableSummaryHash(joinStrings(result.matchedPaths, ","))}"
        result.activeRepoListVersion = version
        result.candidateRepoListVersion = "${version}-candidate"
        this.store.saveRepositoryListRefresh(result)
        result
    }

    public func runRebuild(): IndexBuildResult {
        let busy = this.tryEnterAdminOperation("rebuild")
        if (busy != "") {
            let result = IndexBuildResult()
            result.ok = false
            result.candidateVersion = this.kb.status().candidateKnowledgeVersion
            result.activeVersion = this.kb.status().activeKnowledgeVersion
            result.failedVersion = busy
            return result
        }
        let result = this.runRebuildUnlocked()
        this.leaveAdminOperation("rebuild")
        result
    }

    private func runRebuildUnlocked(): IndexBuildResult {
        this.rebuildCount += 1
        ckbRebuildIndex(this.kb, this.store)
    }

    public func runScheduler(limit: Int64): SchedulerExecutorResult {
        let busy = this.tryEnterAdminOperation("scheduler")
        if (busy != "") {
            return this.schedulerBusyResult(busy, ArrayList<String>(), false)
        }
        let result = this.runSchedulerUnlocked(limit)
        this.leaveAdminOperation("scheduler")
        result
    }

    private func runSchedulerUnlocked(limit: Int64): SchedulerExecutorResult {
        this.advanceSchedulerClockForServiceTick()
        let executor = SchedulerExecutor(this.kb.scheduler, CkbSchedulerTaskRunner(this.kb, this.config, this.store, sourceRunner: this.sourceRunner))
        let result = executor.runDue(limit: limit)
        this.store.saveScheduler(this.kb.scheduler.entries)
        result
    }

    public func runSchedulerTasks(taskNames: ArrayList<String>, force: Bool): SchedulerExecutorResult {
        let busy = this.tryEnterAdminOperation("scheduler_tasks")
        if (busy != "") {
            return this.schedulerBusyResult(busy, taskNames, force)
        }
        let result = this.runSchedulerTasksUnlocked(taskNames, force)
        this.leaveAdminOperation("scheduler_tasks")
        result
    }

    private func runSchedulerTasksUnlocked(taskNames: ArrayList<String>, force: Bool): SchedulerExecutorResult {
        let result = SchedulerExecutorResult()
        result.forced = force
        let allowed = ckbSchedulerAllowlistTaskNames()
        for (name in taskNames) {
            result.taskNames.add(name)
            if (!allowed.contains(name)) {
                result.failed += 1
                result.details += "task ${name} ok=false status=unsupported_task\n"
            }
        }
        if (result.failed > 0) {
            return result
        }
        this.advanceSchedulerClockForServiceTick()
        let executor = SchedulerExecutor(this.kb.scheduler, CkbSchedulerTaskRunner(this.kb, this.config, this.store, sourceRunner: this.sourceRunner))
        let ran = executor.runTaskNames(taskNames, force: force)
        this.store.saveScheduler(this.kb.scheduler.entries)
        ran
    }

    public func markSchedulerDisabled(): Unit {
        for (entry in this.kb.scheduler.entries) {
            entry.lastStatus = "scheduler_disabled"
            entry.degraded = true
        }
        this.store.saveScheduler(this.kb.scheduler.entries)
    }

    public func markSchedulerLoopFailure(diagnostic: String): Unit {
        this.kb.scheduler.clock.advance(1)
        for (entry in this.kb.scheduler.entries) {
            entry.lastStatus = diagnostic
            entry.lastFailureAt = this.kb.scheduler.clock.nowMinutes
            entry.failureCount += 1
            entry.degraded = true
        }
        this.store.saveScheduler(this.kb.scheduler.entries)
    }

    public func rebuildCountForTest(): Int64 {
        this.rebuildCount
    }

    public func acceptedEventCountForTest(): Int64 {
        this.acceptedEventCount
    }

    private func tryEnterAdminOperation(operationId: String): String {
        if (this.adminOperationGate.enter(operationId)) {
            return ""
        }
        let current = this.adminOperationGate.currentOperation()
        if (current == "") {
            return "admin_operation_busy"
        }
        "admin_operation_busy:${current}"
    }

    private func leaveAdminOperation(operationId: String): Unit {
        this.adminOperationGate.leave(operationId)
    }

    private func schedulerBusyResult(diagnostic: String, taskNames: ArrayList<String>, force: Bool): SchedulerExecutorResult {
        let result = SchedulerExecutorResult()
        result.forced = force
        if (taskNames.size == 0) {
            result.taskNames.add("scheduler")
        } else {
            for (name in taskNames) {
                result.taskNames.add(name)
            }
        }
        result.failed = if (result.taskNames.size == 0) { 1 } else { result.taskNames.size }
        result.details = "task admin_mutation ok=false status=${diagnostic}\n"
        result
    }

    private func adminBusyResult(diagnostic: String): CkbAdminOperationResult {
        let result = CkbAdminOperationResult()
        let status = this.kb.status()
        result.status = "rejected"
        result.degraded = true
        result.diagnostic = diagnostic
        result.activeKnowledgeVersion = status.activeKnowledgeVersion
        result.candidateKnowledgeVersion = status.candidateKnowledgeVersion
        result
    }

    private func applyFirstInitializationBodyOverrides(options: CkbFirstInitOptions, body: String): Unit {
        let docsRoot = ckbServiceJsonStringField(body, "docsRoot").trimAscii()
        if (docsRoot != "") {
            options.docsRoot = docsRoot
        }
        let toolDocsRoot = ckbServiceJsonStringField(body, "toolDocsRoot").trimAscii()
        if (toolDocsRoot != "") {
            options.toolDocsRoot = toolDocsRoot
        }
        let stdRoot = ckbServiceJsonStringField(body, "stdRoot").trimAscii()
        if (stdRoot != "") {
            options.stdRoot = stdRoot
        }
        let stdxRoot = ckbServiceJsonStringField(body, "stdxRoot").trimAscii()
        if (stdxRoot != "") {
            options.stdxRoot = stdxRoot
        }
        let evalRoot = ckbServiceJsonStringField(body, "evalRoot").trimAscii()
        if (evalRoot != "") {
            options.evalRoot = evalRoot
        }
        let targetVersion = ckbServiceJsonStringField(body, "targetVersion").trimAscii()
        if (targetVersion != "") {
            options.targetVersion = targetVersion
        }
        options.dryRun = ckbServiceJsonBoolFieldDefault(body, "dryRun", options.dryRun)
        options.apply = ckbServiceJsonBoolFieldDefault(body, "apply", !options.dryRun)
        if (options.dryRun) {
            options.apply = false
        }
        validateCkbFirstInitOptions(options)
    }

    private func reloadKnowledgeBase(): Unit {
        this.kb = newKnowledgeBaseFromStoreWithRuntime(this.store, this.config).kb
    }

    private func advanceSchedulerClockForServiceTick(): Unit {
        var last: Int64 = this.kb.scheduler.clock.nowMinutes
        for (entry in this.kb.scheduler.entries) {
            if (entry.lastSuccessAt > last) {
                last = entry.lastSuccessAt
            }
            if (entry.lastFailureAt > last) {
                last = entry.lastFailureAt
            }
        }
        if (this.kb.scheduler.clock.nowMinutes < last) {
            this.kb.scheduler.clock.nowMinutes = last
        }
        this.kb.scheduler.clock.advance(1)
    }

    private func health(): String {
        let status = this.kb.status()
        "health ok=true protocol=ckb-stdio-v1 activeKnowledgeVersion=${status.activeKnowledgeVersion} activeStateSource=${status.activeStateSource} restoreDiagnostic=${status.restoreDiagnostic} vectorState=${status.storage.vectorState} graphState=${status.storage.graphState}\n"
    }

    private func logLine(level: String, event: String): String {
        let status = this.kb.status()
        "log level=${level} event=${event} protocol=ckb-stdio-v1 activeKnowledgeVersion=${status.activeKnowledgeVersion} store=redacted\n"
    }
}

private func renderCangjieCorpusStatus(status: CangjieCorpusStatus): String {
    var out = "cangjie_corpus_status activeKnowledgeVersion=${status.activeKnowledgeVersion} knowledgeVersion=${status.activeKnowledgeVersion} targetVersion=${status.targetVersion} rawCount=${status.rawCount} normalizedCount=${status.normalizedCount} indexCount=${status.indexCount} degraded=${status.degraded}\n"
    out += "docsUrls=${status.docsUrls}\n"
    out += "stdSources=${status.stdSources}\n"
    if (status.diagnostics.size > 0) {
        out += "diagnostics=${status.diagnostics}\n"
    }
    redactSensitive(out)
}

private func ckbRepositoryChangedDedupeKey(event: GitCodeRepositoryChangedEvent): String {
    let identity = if (event.deliveryId != "") { event.deliveryId } else if (event.eventId != "") { event.eventId } else if (event.mergeCommitSha != "") { event.mergeCommitSha } else { joinStrings(event.changedFiles, ",") }
    "${event.contractVersion}:${event.provider}:${event.eventType}:${event.reason}:${event.repo}:${event.ref}:${event.prNumber}:${identity}"
}

private func ckbRepositoryChangedProfile(event: GitCodeRepositoryChangedEvent): String {
    for (path in event.changedFiles) {
        let lowered = path.toAsciiLower()
        if (lowered.endsWith(".cj") || lowered.endsWith(".md") || lowered.endsWith(".toml") || lowered.endsWith(".json") || lowered.endsWith(".yaml") || lowered.endsWith(".yml")) {
            return "repo_source_and_items"
        }
    }
    "items"
}

private class CkbScheduledProfileFetchResult {
    var ok: Bool = true
    var status: String = "profile_ok"
    var requestCount: Int64 = 0
    var fetchedCount: Int64 = 0
    var failedCount: Int64 = 0
    var truncated: Bool = false
    var runId: String = ""
    var records: ArrayList<CkbScheduledSourceRecord> = ArrayList<CkbScheduledSourceRecord>()

    init() {}
}

private class CkbScheduledSourceRecord {
    var sourceId: String = ""
    var sourceType: String = SourceTypes.DOC
    var sourceFamily: String = ""
    var sourceSet: String = ""
    var title: String = ""
    var request: SourceFetchRequest = SourceFetchRequest()
    var fetch: SourceFetchResult = SourceFetchResult()

    init() {}
}

private class CkbScheduledProfileIngestResult {
    var ok: Bool = true
    var status: String = "profile_ok"
    var candidateVersion: String = ""
    var activeVersion: String = ""
    var validationStatus: String = "not_run"
    var validationSummary: String = ""
    var validationEvidenceHash: String = ""
    var validationDiagnostics: ArrayList<String> = ArrayList<String>()

    init() {}
}

private func ckbRunScheduledProfileFetches(profile: CkbScheduleTaskProfile, runner: SourceFetchRunner, config: CkbRuntimeConfig, manifest: CangjieVersionManifest): CkbScheduledProfileFetchResult {
    fetchScheduledProfileSources(profile, runner, config, manifest)
}

private func fetchScheduledProfileSources(profile: CkbScheduleTaskProfile, runner: SourceFetchRunner, config: CkbRuntimeConfig, manifest: CangjieVersionManifest): CkbScheduledProfileFetchResult {
    let result = CkbScheduledProfileFetchResult()
    let builder = SourceRequestBuilder(gitCodeApiRoot: config.gitCodeBaseUrl)
    if (profile.profile == "community_repo_discovery") {
        ckbFetchScheduledSource(runner, builder.gitCodeOrgRepos("cangjie"), profile, result)
        ckbFetchScheduledSource(runner, builder.gitCodeOrgRepos("cangjie-sig"), profile, result)
        ckbFetchScheduledSource(runner, builder.gitCodeOrgRepos("cangjie-tpc"), profile, result)
    } else if (profile.profile == "docs_probe") {
        ckbFetchScheduledSource(runner, builder.docs("https://docs.cangjie-lang.cn/docs/1.0.0/"), profile, result)
    } else if (profile.profile == "website_probe" || profile.profile == "website_full") {
        ckbFetchScheduledSource(runner, builder.website("https://cangjie-lang.cn/"), profile, result)
        ckbFetchScheduledSource(runner, builder.website("https://cangjie-lang.cn/docs"), profile, result)
        ckbFetchScheduledSource(runner, builder.website("https://cangjie-lang.cn/en/docs"), profile, result)
    } else if (profile.profile == "web_candidate_discovery" || profile.profile == "web_candidate_recrawl") {
        ckbFetchScheduledSource(runner, builder.webCandidate("https://cangjie-lang.cn/community"), profile, result)
        ckbFetchScheduledSource(runner, builder.webCandidate("https://cangjie-lang.cn/blog"), profile, result)
    } else if (profile.profile == "cangjie_freshness_probe" || profile.profile == "cangjie_docs_full_sync" || profile.profile == "cangjie_release_full_sync") {
        ckbFetchScheduledSource(runner, builder.docs("https://docs.cangjie-lang.cn/docs/1.0.0/"), profile, result)
        ckbFetchScheduledManifestRepoSources(runner, builder, manifest, profile, result, true, true, true, true)
    } else if (profile.profile == "cangjie_source_event_sync") {
        ckbFetchScheduledManifestRepoSources(runner, builder, manifest, profile, result, false, true, true, true)
    } else if (profile.profile == "cangjie_version_branch_refresh") {
        ckbFetchScheduledManifestRepoSources(runner, builder, manifest, profile, result, true, true, true, true)
    } else if (profile.profile == "cangjie_benchmark_gap_curation") {
        result.ok = true
    }
    if (!result.ok) {
        result.status = "fetch_degraded"
    }
    result
}

private func ckbFetchScheduledManifestRepoSources(runner: SourceFetchRunner, builder: SourceRequestBuilder, manifest: CangjieVersionManifest, profile: CkbScheduleTaskProfile, result: CkbScheduledProfileFetchResult, docs: Bool, std: Bool, stdx: Bool, tools: Bool): Unit {
    let before = result.requestCount
    for (source in manifest.sources) {
        if (!ckbScheduledManifestSourceIncluded(source, docs, std, stdx, tools)) {
            continue
        }
        if (source.sourceRepo.trimAscii() == "" || source.sourceRef.trimAscii() == "") {
            result.ok = false
            result.status = "manifest_source_missing"
            continue
        }
        ckbFetchScheduledSource(runner, builder.gitCodeRepo(source.sourceRepo, ref: source.sourceRef), profile, result)
    }
    if (result.requestCount == before) {
        result.ok = false
        result.status = "manifest_source_missing"
    }
}

private func ckbScheduledManifestSourceIncluded(source: CangjieVersionSource, docs: Bool, std: Bool, stdx: Bool, tools: Bool): Bool {
    (docs && source.sourceSet == CangjieSourceSets.DOCS) ||
        (std && source.sourceSet == CangjieSourceSets.STD) ||
        (stdx && source.sourceSet == CangjieSourceSets.STDX) ||
        (tools && source.sourceSet == CangjieSourceSets.TOOLS)
}

private func ckbFetchScheduledSource(runner: SourceFetchRunner, request: SourceFetchRequest, profile: CkbScheduleTaskProfile, result: CkbScheduledProfileFetchResult): Unit {
    let fetch = SourceResponseNormalizer().normalize(request, runner.fetch(request))
    result.requestCount += 1
    if (fetch.truncated) {
        result.truncated = true
    }
    if (fetch.ok) {
        result.fetchedCount += 1
    } else {
        result.ok = false
        result.failedCount += 1
    }
    let record = CkbScheduledSourceRecord()
    record.request = request
    record.fetch = fetch
    record.sourceType = ckbScheduledSourceType(request)
    record.sourceFamily = ckbScheduledSourceFamily(request, profile)
    record.sourceSet = ckbScheduledSourceSet(request, profile)
    record.title = ckbScheduledSourceTitle(request, profile)
    record.sourceId = "scheduled-${profile.profile}-${stableSummaryHash("${request.kind}:${request.url}:${request.repo}:${request.ref}:${fetch.bodyHash}")}"
    result.records.add(record)
}

private func ingestScheduledProfileSources(kb: KnowledgeBase, store: FileKnowledgeStore, profile: CkbScheduleTaskProfile, fetch: CkbScheduledProfileFetchResult, config: CkbRuntimeConfig, manifest: CangjieVersionManifest): CkbScheduledProfileIngestResult {
    let result = CkbScheduledProfileIngestResult()
    result.status = if (fetch.ok) { "profile_ok" } else { fetch.status }
    if (profile.profile == "cangjie_benchmark_gap_curation") {
        return ingestScheduledBenchmarkGapCuration(kb, store, profile, config)
    }
    if (profile.candidateMode == "" || profile.candidateMode == "none" || profile.candidateMode == "probe_only") {
        result.ok = fetch.ok
        return result
    }
    if (!fetch.ok) {
        result.ok = false
        result.status = "fetch_degraded_candidate_not_promoted"
        return result
    }
    let delta = ckbScheduledTypedDeltaRecords(profile, fetch.records, config, manifest)
    for (record in fetch.records) {
        if (record.fetch.ok) {
            _ = kb.ingestFetchResult(record.sourceId, record.sourceType, record.fetch, record.title, TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
        }
    }
    let candidateVersion = ckbScheduledCandidateVersion(profile, fetch)
    let candidateRecords = kb.activeRecordSnapshotOverlay(delta)
    let promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb, store, candidateVersion, candidateRecords)
    ckbApplyScheduledPromotionResult(result, promotion, "candidate_validated_promoted")
    result
}

private func ingestScheduledBenchmarkGapCuration(kb: KnowledgeBase, store: FileKnowledgeStore, profile: CkbScheduleTaskProfile, config: CkbRuntimeConfig): CkbScheduledProfileIngestResult {
    let result = CkbScheduledProfileIngestResult()
    if (config.benchmarkGapCurationInputPath.trimAscii() == "") {
        result.ok = false
        result.status = "benchmark_gap_curation_input_missing"
        return result
    }
    if (!exists(Path(config.benchmarkGapCurationInputPath))) {
        result.ok = false
        result.status = "benchmark_gap_curation_input_not_found"
        return result
    }
    let curationText = try { String.fromUtf8(File.readFrom(Path(config.benchmarkGapCurationInputPath))) } catch (_: Exception) { "" }
    if (curationText.trimAscii() == "") {
        result.ok = false
        result.status = "benchmark_gap_curation_input_empty"
        return result
    }
    let curated = curateBenchmarkGapRecordsFromJsonl(curationText, targetVersion: config.benchmarkGapTargetVersion)
    if (!curated.ok) {
        result.ok = false
        result.status = curated.diagnostic
        return result
    }
    for (record in curated.records) {
        let fetch = SourceFetchResult()
        fetch.ok = true
        fetch.status = "ok"
        fetch.statusCode = 200
        fetch.body = record.chunk
        fetch.bodyHash = stableSummaryHash(record.chunk)
        fetch.sourceUrl = record.citation
        fetch.path = record.metadata.path
        fetch.ref = "visible-benchmark"
        _ = kb.ingestFetchResult(record.sourceId, SourceTypes.DOC, fetch, record.title, TrustLevels.OFFICIAL, ReviewStates.REVIEWED)
    }
    let fetch = CkbScheduledProfileFetchResult()
    fetch.requestCount = curated.accepted
    fetch.fetchedCount = curated.accepted
    let candidateVersion = ckbScheduledCandidateVersion(profile, fetch)
    let candidateRecords = kb.activeRecordSnapshotOverlay(curated.records)
    let promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb, store, candidateVersion, candidateRecords)
    ckbApplyScheduledPromotionResult(result, promotion, "benchmark_gap_candidate_promoted")
    result
}

private func ckbApplyScheduledPromotionResult(result: CkbScheduledProfileIngestResult, promotion: CangjieCandidatePromotionResult, successStatus: String): Unit {
    result.candidateVersion = promotion.candidateVersion
    result.activeVersion = promotion.activeVersion
    result.validationStatus = promotion.validation.status
    result.validationSummary = renderCangjieCandidateValidationSummary(promotion.validation)
    result.validationEvidenceHash = promotion.validation.evidenceHash
    for (diagnostic in promotion.validation.diagnostics) {
        result.validationDiagnostics.add(diagnostic)
    }
    result.ok = promotion.ok
    result.status = if (promotion.ok) { successStatus } else { "candidate_validation_failed" }
}

private func ckbScheduledTypedDeltaRecords(profile: CkbScheduleTaskProfile, records: ArrayList<CkbScheduledSourceRecord>, config: CkbRuntimeConfig, manifest: CangjieVersionManifest): ArrayList<NormalizedRecord> {
    let out = ArrayList<NormalizedRecord>()
    for (record in records) {
        if (!record.fetch.ok) {
            continue
        }
        let raw = ckbScheduledRawRecord(profile, record, config, manifest)
        ckbAppendTypedDeltaRecords(out, cangjieTypedNormalizeRawRecord(raw), raw.metadata)
        if (ckbScheduledCangjieSourcePath(record)) {
            ckbAppendTypedDeltaRecords(out, extractCangjieSourceSymbolRecords(raw.metadata.path, raw.content, raw.metadata.sourceSet, ckbScheduledVersionResolution(record, config, manifest)), raw.metadata)
        }
    }
    out
}

private func ckbAppendTypedDeltaRecords(out: ArrayList<NormalizedRecord>, typed: CangjieTypedRecordResult, base: KnowledgeMetadata): Unit {
    for (record in typed.records) {
        out.add(cangjieTypedRecordToNormalized(record, base))
    }
}

private func ckbScheduledRawRecord(profile: CkbScheduleTaskProfile, record: CkbScheduledSourceRecord, config: CkbRuntimeConfig, manifest: CangjieVersionManifest): RawRecord {
    let raw = RawRecord()
    raw.sourceId = record.sourceId
    raw.title = record.title
    raw.content = record.fetch.body
    raw.contentHash = if (record.fetch.bodyHash != "") { record.fetch.bodyHash } else { stableSummaryHash("${record.sourceId}\n${record.fetch.body}") }
    raw.requiresReview = false
    let metadata = cangjieMetadataFromVersionResolution(ckbScheduledVersionResolution(record, config, manifest), record.sourceSet)
    metadata.sourceId = record.sourceId
    metadata.sourceType = record.sourceType
    metadata.sourceUrl = if (record.fetch.sourceUrl != "") { record.fetch.sourceUrl } else { record.request.url }
    metadata.repo = if (record.fetch.repo != "") { record.fetch.repo } else { record.request.repo }
    metadata.path = if (record.fetch.path != "") { record.fetch.path } else { record.request.path }
    metadata.commit = if (record.fetch.commit != "") { record.fetch.commit } else { metadata.commit }
    metadata.docVersion = if (record.fetch.ref != "") { record.fetch.ref } else { if (record.request.ref != "") { record.request.ref } else { metadata.docVersion } }
    metadata.targetVersion = ckbScheduledTargetVersion(config)
    metadata.sourceSet = record.sourceSet
    metadata.crawlAt = "scheduled:${profile.profile}"
    metadata.indexedAt = "scheduled:${profile.profile}"
    metadata.contentSize = record.fetch.body.size
    metadata.trustLevel = TrustLevels.OFFICIAL
    metadata.reviewState = ReviewStates.TRUSTED
    metadata.license = "declared-or-unknown"
    metadata.repoVisibility = record.fetch.repoVisibility
    raw.metadata = metadata
    raw
}

private func ckbScheduledVersionResolution(record: CkbScheduledSourceRecord, config: CkbRuntimeConfig, manifest: CangjieVersionManifest): CangjieVersionResolution {
    resolveCangjieVersion(cangjieVersionSelector(
        targetVersion: ckbScheduledTargetVersion(config),
        sourceSet: if (record.sourceSet == "") { CangjieSourceSets.ALL } else { record.sourceSet },
        sourceFamily: record.sourceFamily,
        sourceRepo: if (record.request.repo != "") { record.request.repo } else { record.fetch.repo },
        sourceRef: if (record.request.ref != "") { record.request.ref } else { record.fetch.ref }),
        manifest)
}

private func ckbRuntimeCangjieVersionManifest(config: CkbRuntimeConfig): CangjieVersionManifest {
    buildCangjieVersionManifestFromRoots(
        targetVersion: ckbScheduledTargetVersion(config),
        docsRoot: config.firstInitDocsRoot,
        toolDocsRoot: config.firstInitToolDocsRoot,
        stdRoot: config.firstInitStdRoot,
        stdxRoot: config.firstInitStdxRoot,
        evalRoot: config.firstInitEvalRoot)
}

private func ckbScheduledTargetVersion(config: CkbRuntimeConfig): String {
    if (config.benchmarkGapTargetVersion.trimAscii() != "") {
        return config.benchmarkGapTargetVersion.trimAscii()
    }
    if (config.firstInitTargetVersion.trimAscii() != "") {
        return config.firstInitTargetVersion.trimAscii()
    }
    cangjieDefaultTargetVersion()
}

private func ckbScheduledCangjieSourcePath(record: CkbScheduledSourceRecord): Bool {
    let path = if (record.fetch.path != "") { record.fetch.path } else { record.request.path }
    path.endsWith(".cj") && (record.sourceSet == CangjieSourceSets.STD || record.sourceSet == CangjieSourceSets.STDX)
}

private func ckbScheduledSourceType(request: SourceFetchRequest): String {
    if (request.kind == SourceKinds.CANGJIE_DOCS) {
        return SourceTypes.DOC
    }
    if (request.kind == SourceKinds.CANGJIE_WEBSITE) {
        return SourceTypes.WEBSITE
    }
    if (request.kind == SourceKinds.WEB_CANDIDATE) {
        return SourceTypes.WEB_CANDIDATE
    }
    if (request.kind == SourceKinds.GITCODE_ORG || request.kind == SourceKinds.GITCODE_REPO || request.kind == SourceKinds.GITCODE_TREE || request.kind == SourceKinds.GITCODE_SOURCE) {
        return SourceTypes.REPO
    }
    SourceTypes.COMMUNITY
}

private func ckbScheduledSourceFamily(request: SourceFetchRequest, profile: CkbScheduleTaskProfile): String {
    if (request.repo.contains("cangjie_docs") || request.kind == SourceKinds.CANGJIE_DOCS) { return "docs" }
    if (request.repo.contains("cangjie_runtime")) { return "stdlib" }
    if (request.repo.contains("cangjie_stdx")) { return "stdx" }
    if (request.repo.contains("cangjie_tools")) { return "tools" }
    if (profile.profile.contains("benchmark")) { return "eval-support" }
    profile.profile
}

private func ckbScheduledSourceSet(request: SourceFetchRequest, profile: CkbScheduleTaskProfile): String {
    if (request.repo.contains("cangjie_docs") || request.kind == SourceKinds.CANGJIE_DOCS) { return CangjieSourceSets.DOCS }
    if (request.repo.contains("cangjie_runtime")) { return CangjieSourceSets.STD }
    if (request.repo.contains("cangjie_stdx")) { return CangjieSourceSets.STDX }
    if (request.repo.contains("cangjie_tools")) { return CangjieSourceSets.TOOLS }
    if (profile.profile.contains("benchmark")) { return CangjieSourceSets.EVAL_SUPPORT }
    ""
}

private func ckbScheduledSourceTitle(request: SourceFetchRequest, profile: CkbScheduleTaskProfile): String {
    if (request.repo != "") {
        return "Scheduled ${profile.profile}: ${request.repo}"
    }
    "Scheduled ${profile.profile}: ${request.url}"
}

private func ckbScheduledCandidateVersion(profile: CkbScheduleTaskProfile, fetch: CkbScheduledProfileFetchResult): String {
    let seed = StringBuilder()
    seed.append(profile.profile)
    seed.append("|")
    seed.append("${fetch.requestCount}")
    seed.append("|")
    seed.append(fetch.runId)
    seed.append("|")
    for (record in fetch.records) {
        seed.append(record.sourceId)
        seed.append(":")
        seed.append(record.fetch.bodyHash)
        seed.append("|")
    }
    "ckb-scheduled-${stableSummaryHash(seed.toString())}-candidate"
}

private func ckbServiceCangjieSourceSetAllowed(sourceSet: String): Bool {
    sourceSet == CangjieSourceSets.ALL ||
        sourceSet == CangjieSourceSets.DOCS ||
        sourceSet == CangjieSourceSets.STD ||
        sourceSet == CangjieSourceSets.STDX ||
        sourceSet == CangjieSourceSets.TOOLS ||
        sourceSet == CangjieSourceSets.EVAL_SUPPORT
}

private func ckbRepositoryEventSyncBody(event: GitCodeRepositoryChangedEvent, profiles: ArrayList<String>): String {
    let profile = if (profiles.contains("repo_source_and_items")) { "repo_source_and_items" } else { "items" }
    "{\"repo\":\"${ckbServiceJsonQuote(event.repo)}\",\"ref\":\"${ckbServiceJsonQuote(if (event.ref == "") { "main" } else { event.ref })}\",\"profile\":\"${profile}\",\"prNumber\":${event.prNumber},\"changedFiles\":${ckbServiceStringArrayJson(event.changedFiles)}}"
}

private func ckbRepositoryEventRepoListBody(event: GitCodeRepositoryChangedEvent): String {
    let paths = ArrayList<String>()
    for (path in event.changedFiles) {
        if (ckbRepoListTriggerPath(path.toAsciiLower())) {
            paths.add(path)
        }
    }
    "{\"repo\":\"${ckbServiceJsonQuote(event.repo)}\",\"ref\":\"${ckbServiceJsonQuote(if (event.ref == "") { "main" } else { event.ref })}\",\"prNumber\":${event.prNumber},\"paths\":${ckbServiceStringArrayJson(paths)}}"
}

private func ckbRunRepositoryChangedSourceSync(kb: KnowledgeBase, store: FileKnowledgeStore, runner: SourceFetchRunner, config: CkbRuntimeConfig, repo: String, ref: String, changedFiles: ArrayList<String>): CkbScheduledProfileFetchResult {
    let profile = ckbSyncProfileForScheduleTask("cangjie_source_event_sync")
    let result = CkbScheduledProfileFetchResult()
    let builder = SourceRequestBuilder(gitCodeApiRoot: config.gitCodeBaseUrl)
    if (changedFiles.size == 0) {
        ckbFetchScheduledSource(runner, builder.gitCodeRepo(repo, ref: ref), profile, result)
    } else {
        for (path in changedFiles) {
            ckbFetchScheduledSource(runner, builder.gitCodeSource(repo, ref, path), profile, result)
        }
    }
    let storedManifest = store.loadCangjieVersionManifest()
    let manifest = if (storedManifest.sources.size > 0) { storedManifest } else { ckbRuntimeCangjieVersionManifest(config) }
    let ingest = ingestScheduledProfileSources(kb, store, profile, result, config, manifest)
    result.ok = result.ok && ingest.ok
    result.status = if (result.ok) { ingest.status } else { if (ingest.status != "") { ingest.status } else { result.status } }
    result
}

private func ckbServiceStringArrayJson(values: ArrayList<String>): String {
    var out = "["
    for (i in 0..values.size) {
        if (i > 0) {
            out += ","
        }
        out += "\"${ckbServiceJsonQuote(values[i])}\""
    }
    out + "]"
}

private func ckbServiceJsonQuote(raw: String): String {
    raw.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r")
}

private func ckbRejectedAdminResult(result: CkbAdminOperationResult, diagnostic: String): CkbAdminOperationResult {
    result.status = "rejected"
    result.degraded = true
    result.diagnostic = diagnostic
    result
}

private func ckbCommunityRepoAllowed(raw: String): Bool {
    let parts = raw.split("/")
    if (parts.size != 2 || !ckbServiceSafePathPart(parts[0]) || !ckbServiceSafePathPart(parts[1])) {
        return false
    }
    let owner = parts[0].toAsciiLower()
    owner == "cangjie" || owner == "cangjie-sig" || owner == "cangjie-tpc"
}

private func ckbRepoListTriggerPath(raw: String): Bool {
    let path = raw.toAsciiLower()
    path == "repo_list.md" || path == "repo_lists.md" || path.endsWith("/repo_list.md") || path.endsWith("/repo_lists.md")
}

private func ckbRepositorySourceTriggerPath(raw: String): Bool {
    let path = raw.toAsciiLower()
    path.endsWith(".cj") || path.endsWith(".md") || path.endsWith(".toml") || path.endsWith(".json") || path.endsWith(".yaml") || path.endsWith(".yml")
}

private func ckbSafeRepoRelativePath(raw: String): Bool {
    let path = raw.trimAscii()
    if (path == "" || path.startsWith("/") || path.startsWith("~") || path.contains("\\") || path.contains("..")) {
        return false
    }
    for (part in path.split("/")) {
        if (part == "" || part == "." || part == "..") {
            return false
        }
    }
    true
}

private func ckbServiceSafePathPart(raw: String): Bool {
    if (raw == "" || raw == "." || raw == "..") {
        return false
    }
    for (ch in raw.toRuneArray()) {
        let ok = (ch >= r'a' && ch <= r'z') || (ch >= r'A' && ch <= r'Z') || (ch >= r'0' && ch <= r'9') || ch == r'_' || ch == r'-' || ch == r'.'
        if (!ok) {
            return false
        }
    }
    true
}

private class CkbServiceJsonStringScan {
    var ok: Bool = false
    var value: String = ""
    var end: Int64 = 0

    init() {}
}

private func ckbServiceJsonStringField(raw: String, key: String): String {
    let start = ckbServiceJsonTopLevelValueStart(raw, key)
    if (start < 0 || start >= raw.size || raw[start..start + 1] != "\"") {
        return ""
    }
    let scan = ckbServiceReadJsonStringAt(raw, start)
    if (scan.ok) {
        return scan.value
    }
    ""
}

private func ckbServiceJsonIntField(raw: String, key: String, fallback: Int64): Int64 {
    let start = ckbServiceJsonTopLevelValueStart(raw, key)
    if (start < 0 || start >= raw.size) {
        return fallback
    }
    if (raw[start..start + 1] == "\"") {
        return try { Int64.parse(ckbServiceJsonStringField(raw, key).trimAscii()) } catch (_: Exception) { fallback }
    }
    var end = start
    while (end < raw.size) {
        let ch = raw[end..end + 1]
        if (ch == "," || ch == "}" || ch == "]" || ch == " " || ch == "\n" || ch == "\r" || ch == "\t") {
            break
        }
        end += 1
    }
    try { Int64.parse(raw[start..end].trimAscii()) } catch (_: Exception) { fallback }
}

private func ckbServiceJsonBoolFieldDefault(raw: String, key: String, fallback: Bool): Bool {
    let start = ckbServiceJsonTopLevelValueStart(raw, key)
    if (start < 0 || start >= raw.size) {
        return fallback
    }
    if (raw[start..start + 1] == "\"") {
        let value = ckbServiceJsonStringField(raw, key).trimAscii().toAsciiLower()
        if (value == "true" || value == "1" || value == "yes" || value == "enabled") {
            return true
        }
        if (value == "false" || value == "0" || value == "no" || value == "disabled") {
            return false
        }
        return fallback
    }
    var end = start
    while (end < raw.size) {
        let ch = raw[end..end + 1]
        if (ch == "," || ch == "}" || ch == "]" || ch == " " || ch == "\n" || ch == "\r" || ch == "\t") {
            break
        }
        end += 1
    }
    let value = raw[start..end].trimAscii().toAsciiLower()
    if (value == "true" || value == "1" || value == "yes" || value == "enabled") {
        return true
    }
    if (value == "false" || value == "0" || value == "no" || value == "disabled") {
        return false
    }
    fallback
}

private func ckbServiceJsonStringArrayField(raw: String, key: String): ArrayList<String> {
    let values = ArrayList<String>()
    let start = ckbServiceJsonTopLevelValueStart(raw, key)
    if (start < 0 || start >= raw.size || raw[start..start + 1] != "[") {
        return values
    }
    var i = start + 1
    while (i < raw.size) {
        i = ckbServiceSkipJsonWhitespace(raw, i)
        if (i >= raw.size || raw[i..i + 1] == "]") {
            break
        }
        if (raw[i..i + 1] == "\"") {
            let scan = ckbServiceReadJsonStringAt(raw, i)
            if (scan.ok) {
                values.add(scan.value)
                i = scan.end
            } else {
                break
            }
        } else {
            i += 1
        }
        i = ckbServiceSkipJsonWhitespace(raw, i)
        if (i < raw.size && raw[i..i + 1] == ",") {
            i += 1
        }
    }
    values
}

private func ckbServiceJsonTopLevelValueStart(raw: String, key: String): Int64 {
    var i: Int64 = 0
    var depth: Int64 = 0
    var inString = false
    var escaped = false
    while (i < raw.size) {
        let ch = raw[i..i + 1]
        if (inString) {
            if (escaped) {
                escaped = false
            } else if (ch == "\\") {
                escaped = true
            } else if (ch == "\"") {
                inString = false
            }
            i += 1
            continue
        }
        if (ch == "\"") {
            if (depth == 1) {
                let scan = ckbServiceReadJsonStringAt(raw, i)
                if (scan.ok && scan.value == key) {
                    var colon = ckbServiceSkipJsonWhitespace(raw, scan.end)
                    if (colon < raw.size && raw[colon..colon + 1] == ":") {
                        return ckbServiceSkipJsonWhitespace(raw, colon + 1)
                    }
                }
                i = if (scan.ok) { scan.end } else { i + 1 }
                continue
            }
            inString = true
        } else if (ch == "{" || ch == "[") {
            depth += 1
        } else if (ch == "}" || ch == "]") {
            depth -= 1
        }
        i += 1
    }
    -1
}

private func ckbServiceReadJsonStringAt(raw: String, start: Int64): CkbServiceJsonStringScan {
    let scan = CkbServiceJsonStringScan()
    if (start < 0 || start >= raw.size || raw[start..start + 1] != "\"") {
        return scan
    }
    var i = start + 1
    var escaped = false
    var value = ""
    while (i < raw.size) {
        let ch = raw[i..i + 1]
        if (escaped) {
            value += ckbServiceJsonUnescapeChar(ch)
            escaped = false
        } else if (ch == "\\") {
            escaped = true
        } else if (ch == "\"") {
            scan.ok = true
            scan.value = value
            scan.end = i + 1
            return scan
        } else {
            value += ch
        }
        i += 1
    }
    scan
}

private func ckbServiceJsonUnescapeChar(ch: String): String {
    if (ch == "\"") { return "\"" }
    if (ch == "\\") { return "\\" }
    if (ch == "/") { return "/" }
    if (ch == "n") { return "\n" }
    if (ch == "r") { return "\r" }
    if (ch == "t") { return "\t" }
    ch
}

private func ckbServiceSkipJsonWhitespace(raw: String, start: Int64): Int64 {
    var i = start
    while (i < raw.size) {
        let ch = raw[i..i + 1]
        if (ch != " " && ch != "\n" && ch != "\r" && ch != "\t") {
            break
        }
        i += 1
    }
    i
}

private func sourceAnalysisResultFromPack(pack: SourceAnalysisPack): SourceAnalysisResult {
    let result = SourceAnalysisResult()
    result.analysisId = stableSummaryHash("${pack.repo}:${pack.ref}:${pack.status}")
    result.repo = pack.repo
    result.ref = pack.ref
    result.sourceAcquisition = if (pack.ok) { SourceAnalysisAcquisition.CLONE } else { SourceAnalysisAcquisition.NONE }
    result.degraded = !pack.ok
    result.cleanupStatus = pack.cleanupStatus
    result.diagnostic = pack.diagnostic
    for (file in pack.selectedFiles) {
        result.filesRead.add(file)
        if (file.citation != "") {
            result.citations.add(file.citation)
        }
    }
    result
}

private func parseSourceAnalysisCommand(tail: String): SourceAnalysisRequest {
    let request = SourceAnalysisRequest()
    let parts = tail.split(" ")
    if (parts.size > 0 && parts[0].trimAscii() != "") {
        request.repo = parts[0].trimAscii()
    }
    if (parts.size > 1 && parts[1].trimAscii() != "") {
        request.ref = parts[1].trimAscii()
    }
    request.visibility = RepoVisibility.PUBLIC
    if (parts.size > 2) {
        for (i in 2..parts.size) {
            let path = parts[i].trimAscii()
            if (path != "") {
                request.changedFiles.add(path)
            }
        }
    }
    request
}

public func renderSourceAnalysis(pack: SourceAnalysisPack): String {
    var out = "source_analysis ok=${pack.ok} status=${pack.status} repo=${pack.repo} ref=${pack.ref} files=${pack.selectedFiles.size} truncated=${pack.truncated} cleanupStatus=${pack.cleanupStatus} workspace=${pack.workspaceStatus}\n"
    if (pack.diagnostic != "") {
        out += "diagnostic=${redactSensitive(pack.diagnostic)}\n"
    }
    for (file in pack.selectedFiles) {
        out += "file path=${file.path} bytes=${file.bytes} bodyHash=${file.bodyHash} truncated=${file.truncated} citation=${file.citation}\n"
    }
    redactSensitive(out)
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
    let promotion = cangjiePromoteCandidateAfterValidation(kb, store, forceFailure: options.simulateValidationFailure)
    let status = kb.status()
    result.rawCount = status.storage.rawCount
    result.normalizedCount = status.storage.normalizedCount
    result.activeVersion = status.activeKnowledgeVersion
    result.candidateVersion = status.candidateKnowledgeVersion
    result.failedVersion = status.failedCandidateVersion
    if (!promotion.ok) {
        result.ok = false
        result.errorReport += renderCangjieCandidateValidationSummary(promotion.validation)
        return result
    }
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

public func embeddingConfigFromRuntime(config: CkbRuntimeConfig): EmbeddingConfig {
    let embedding = EmbeddingConfig()
    let localProvider = config.embeddingProvider == "deterministic" || config.embeddingProvider == "local" || config.embeddingProvider == "local-file"
    embedding.provider = config.embeddingProvider
    embedding.model = if (config.embeddingModel == "" && localProvider) { "deterministic-token-v1" } else { config.embeddingModel }
    embedding.dimensions = if (config.embeddingDimensions <= 0 && localProvider) { 16 } else { config.embeddingDimensions }
    embedding.endpoint = config.embeddingEndpoint
    embedding.tokenFile = config.embeddingTokenFile
    embedding.batchSize = config.embeddingBatchSize
    embedding.timeoutMillis = config.embeddingTimeoutMillis
    embedding.retryCount = config.embeddingRetryCount
    embedding.production = !localProvider
    embedding.configured = config.embeddingProvider != "" && config.embeddingProvider != "none"
    embedding
}

public class RuntimeVectorStoreConfig {
    public var backend: String = "local-file"
    public var endpoint: String = ""
    public var activeCollection: String = "active"
    public var candidateCollection: String = "candidate"
    public var dimensions: Int64 = 16
    public var distance: String = "Cosine"
    public var timeoutMillis: Int64 = 10000
    public var retryCount: Int64 = 2
    public var apiKeyFile: String = ""
    public var allowPrivateEndpoint: Bool = false

    public init() {}

    public func apiKeyPresent(): Bool {
        this.apiKeyFile != ""
    }
}

public func vectorStoreConfigFromRuntime(config: CkbRuntimeConfig): RuntimeVectorStoreConfig {
    let vector = RuntimeVectorStoreConfig()
    vector.backend = if (config.vectorBackend == "") { "local-file" } else { config.vectorBackend }
    vector.endpoint = config.vectorEndpoint
    vector.activeCollection = if (config.vectorActiveCollection == "") { "active" } else { config.vectorActiveCollection }
    vector.candidateCollection = if (config.vectorCandidateCollection == "") { "candidate" } else { config.vectorCandidateCollection }
    vector.dimensions = if (config.vectorDimensions <= 0) { 16 } else { config.vectorDimensions }
    vector.distance = if (config.vectorDistance == "") { "Cosine" } else { config.vectorDistance }
    vector.timeoutMillis = config.vectorTimeoutMillis
    vector.retryCount = config.vectorRetryCount
    vector.apiKeyFile = config.vectorApiKeyFile
    vector.allowPrivateEndpoint = config.vectorAllowPrivateEndpoint
    vector
}

public class RuntimeUnavailableEmbeddingProvider <: EmbeddingProvider {
    private let config: EmbeddingConfig
    private let degradedReason: String

    public init(config: EmbeddingConfig, degradedReason: String) {
        this.config = config
        this.degradedReason = degradedReason
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
        status.degradedReason = this.degradedReason
        status
    }
}

public class RuntimeUnavailableVectorStore <: VectorStore {
    private let config: RuntimeVectorStoreConfig
    private let degradedReason: String

    public init(config: RuntimeVectorStoreConfig, degradedReason: String) {
        this.config = config
        this.degradedReason = degradedReason
    }

    public func upsert(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.status(collection)
    }

    public func search(collection: String, queryVector: ArrayList<Float64>, filters: VectorSearchFilters, topK: Int64): ArrayList<VectorSearchResult> {
        ArrayList<VectorSearchResult>()
    }

    public func status(collection: String): VectorStoreStatus {
        let status = VectorStoreStatus()
        status.backend = this.config.backend
        status.collection = collection
        status.activeCollection = this.config.activeCollection
        status.candidateCollection = this.config.candidateCollection
        status.dimension = this.config.dimensions
        status.count = 0
        status.state = EmbeddingProviderState.DEGRADED
        status.degradedReason = this.degradedReason
        status
    }

    public func clear(collection: String): VectorStoreStatus {
        this.status(collection)
    }

    public func recreate(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.status(collection)
    }

    public func backup(collection: String): VectorBackup {
        let backup = VectorBackup()
        backup.collection = collection
        backup.valid = false
        backup.diagnostic = this.degradedReason
        backup
    }

    public func restore(backup: VectorBackup): VectorStoreStatus {
        this.status(backup.collection)
    }
}

public class RuntimeOllamaEmbeddingHttpExecutor <: OllamaEmbeddingHttpExecutor {
    private let executor: HttpRequestExecutor

    public init(executor: HttpRequestExecutor) {
        this.executor = executor
    }

    public func execute(request: OllamaEmbeddingHttpRequest): OllamaEmbeddingHttpResponse {
        let http = HttpExecutionRequest()
        http.method = request.method
        http.url = request.url
        http.accept = request.accept
        http.contentType = request.contentType
        http.body = request.body
        http.timeoutMillis = request.timeoutMillis
        http.retryCount = request.retryCount
        for (header in request.headers) {
            http.headers.add(header)
        }
        let response = this.executor.execute(http)
        let out = OllamaEmbeddingHttpResponse()
        out.statusCode = response.statusCode
        out.body = response.body
        out.contentType = response.contentType
        out.status = response.status
        out.retryAfterSeconds = response.retryAfterSeconds
        out.transportErrorClass = response.transportErrorClass
        out.transportDiagnostic = response.transportDiagnostic
        out
    }
}

private func endpointLooksPrivate(endpoint: String): Bool {
    let lower = endpoint.trimAscii().toAsciiLower()
    lower.startsWith("http://127.") || lower.startsWith("https://127.") || lower.startsWith("http://localhost") || lower.startsWith("https://localhost") || lower.startsWith("http://[::1]") || lower.startsWith("https://[::1]") || lower.startsWith("http://10.") || lower.startsWith("https://10.") || lower.startsWith("http://192.168.") || lower.startsWith("https://192.168.")
}

public func embeddingProviderFromRuntime(config: CkbRuntimeConfig): EmbeddingProvider {
    let embedding = embeddingConfigFromRuntime(config)
    if (embedding.provider == "deterministic" || embedding.provider == "local" || embedding.provider == "local-file") {
        embedding.provider = "deterministic"
        embedding.production = false
        embedding.configured = true
        return DeterministicEmbeddingProvider(embedding)
    }
    if (embedding.provider == "ollama") {
        embedding.production = true
        embedding.configured = embedding.model != "" && embedding.endpoint != "" && embedding.dimensions > 0
        if (endpointLooksPrivate(embedding.endpoint) && !config.embeddingAllowPrivateEndpoint) {
            return RuntimeUnavailableEmbeddingProvider(embedding, "embedding_private_endpoint_not_allowed")
        }
        if (!embedding.configured) {
            return RuntimeUnavailableEmbeddingProvider(embedding, "ollama_embedding_missing_config")
        }
        let httpExecutor = NativeHttpRequestExecutor(ckbNativeHttpAdapterConfigFromRuntime(config, config.embeddingAllowPrivateEndpoint))
        return OllamaEmbeddingProvider(embedding, executor: RuntimeOllamaEmbeddingHttpExecutor(httpExecutor))
    }
    if (embedding.provider != "production-http") {
        embedding.production = true
        embedding.configured = false
        return RuntimeUnavailableEmbeddingProvider(embedding, "unsupported_provider")
    }
    ProductionEmbeddingProvider(embedding)
}

private func qdrantVectorStoreConfigFromRuntime(config: CkbRuntimeConfig, vector: RuntimeVectorStoreConfig): QdrantVectorStoreConfig {
    let qdrant = QdrantVectorStoreConfig()
    qdrant.endpoint = vector.endpoint
    qdrant.dimensions = vector.dimensions
    qdrant.distance = vector.distance
    qdrant.timeoutMillis = vector.timeoutMillis
    qdrant.retryCount = vector.retryCount
    if (vector.apiKeyFile != "") {
        let loaded = readCredentialFile(vector.apiKeyFile)
        if (loaded.status == "ok") {
            qdrant.apiKey = loaded.value
        }
    }
    qdrant
}

public func vectorStoreFromRuntime(config: CkbRuntimeConfig): VectorStore {
    let vector = vectorStoreConfigFromRuntime(config)
    let backend = vector.backend
    if (backend == "local-file" || backend == "local" || backend == "deterministic" || backend == "") {
        return LocalVectorStore()
    }
    if (backend == "qdrant") {
        if (endpointLooksPrivate(vector.endpoint) && !vector.allowPrivateEndpoint) {
            return RuntimeUnavailableVectorStore(vector, "vector_private_endpoint_not_allowed")
        }
        if (vector.endpoint == "" || vector.dimensions <= 0 || vector.distance == "") {
            return RuntimeUnavailableVectorStore(vector, "qdrant_vector_missing_config")
        }
        let httpExecutor = NativeHttpRequestExecutor(ckbNativeHttpAdapterConfigFromRuntime(config, vector.allowPrivateEndpoint))
        return QdrantVectorStore(qdrantVectorStoreConfigFromRuntime(config, vector), executor: httpExecutor)
    }
    RuntimeUnavailableVectorStore(vector, "unsupported_vector_backend")
}

public func newKnowledgeBaseFromStoreWithRuntime(store: FileKnowledgeStore, config: CkbRuntimeConfig): KnowledgeBaseLoadResult {
    let kb = KnowledgeBase(FakeClock(0), embeddingProviderFromRuntime(config), vectorStoreFromRuntime(config), LocalGraphStore())
    kb.configureVectorCollections(config.vectorActiveCollection, config.vectorCandidateCollection)
    kb.bootstrapOffline()
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

private func parseVectorValues(raw: String): ArrayList<Float64> {
    let out = ArrayList<Float64>()
    for (value in raw.split(",")) {
        let trimmed = value.trimAscii()
        if (trimmed == "") {
            continue
        }
        out.add(try { Float64.parse(trimmed) } catch (_: Exception) { 0.0 })
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

private func authHeaderForRequest(config: CkbRuntimeConfig, request: SourceFetchRequest): GitCodeAuthResolution {
    if (isInvalidSourceRequest(request)) {
        return GitCodeAuthResolution()
    }
    if (!isGitCodeRequest(request)) {
        return GitCodeAuthResolution()
    }
    config.gitCodeAuth()
}

private func authSummaryForRequest(config: CkbRuntimeConfig, request: SourceFetchRequest): GitCodeAuthResolution {
    if (isInvalidSourceRequest(request)) {
        return GitCodeAuthResolution()
    }
    if (!isGitCodeRequest(request)) {
        return GitCodeAuthResolution()
    }
    config.gitCodeAuthSummary()
}

private func isGitCodeRequest(request: SourceFetchRequest): Bool {
    request.kind == SourceKinds.GITCODE_ORG || request.kind == SourceKinds.GITCODE_REPO || request.kind == SourceKinds.GITCODE_TREE || request.kind == SourceKinds.GITCODE_SOURCE || request.kind == SourceKinds.GITCODE_ISSUE_HISTORY || request.kind == SourceKinds.GITCODE_PR_HISTORY || request.kind == SourceKinds.GITCODE_COMMENT_HISTORY
}

private func ingestLiveFetch(kb: KnowledgeBase, request: SourceFetchRequest, fetch: SourceFetchResult, index: Int64): Unit {
    if (request.kind == SourceKinds.GITCODE_ORG) {
        kb.ingestFetchResult("live-org-${safeName(request.repo)}", SourceTypes.COMMUNITY, fetch, "GitCode ${request.repo} org", TrustLevels.COMMUNITY, ReviewStates.REVIEWED)
    } else if (request.kind == SourceKinds.GITCODE_REPO) {
        kb.ingestFetchResult("live-repo-${safeName(request.repo)}", SourceTypes.REPO, fetch, "GitCode ${request.repo} repo", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    } else if (request.kind == SourceKinds.GITCODE_TREE) {
        kb.ingestFetchResult("live-tree-${safeName(request.repo)}", SourceTypes.REPO, fetch, "GitCode ${request.repo} tree", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    } else if (request.kind == SourceKinds.GITCODE_SOURCE) {
        kb.ingestFetchResult("live-source-${safeName(request.repo)}-${safeName(request.path)}", SourceTypes.REPO, fetch, "GitCode ${request.repo} source", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    } else if (request.kind == SourceKinds.GITCODE_ISSUE_HISTORY) {
        kb.ingestFetchResult("live-issue-${safeName(request.repo)}", SourceTypes.COMMUNITY, fetch, "GitCode issue history", TrustLevels.COMMUNITY, ReviewStates.REVIEWED)
    } else if (request.kind == SourceKinds.GITCODE_PR_HISTORY) {
        kb.ingestFetchResult("live-pr-${safeName(request.repo)}", SourceTypes.COMMUNITY, fetch, "GitCode PR history", TrustLevels.COMMUNITY, ReviewStates.REVIEWED)
    } else if (request.kind == SourceKinds.GITCODE_COMMENT_HISTORY) {
        kb.ingestFetchResult("live-comments-${safeName(request.repo)}", SourceTypes.COMMUNITY, fetch, "GitCode comment history", TrustLevels.COMMUNITY, ReviewStates.REVIEWED)
    } else if (request.kind == SourceKinds.CANGJIE_DOCS) {
        kb.ingestFetchResult("live-docs-${index}", SourceTypes.DOC, fetch, "Cangjie docs", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    } else if (request.kind == SourceKinds.CANGJIE_WEBSITE) {
        kb.ingestFetchResult("live-website-${index}", SourceTypes.WEBSITE, fetch, "Cangjie website", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    } else if (request.kind == SourceKinds.WEB_CANDIDATE) {
        kb.ingestFetchResult("live-web-candidate-${index}", SourceTypes.WEB_CANDIDATE, fetch, "Web candidate", TrustLevels.WEB_CANDIDATE, ReviewStates.CANDIDATE)
    }
}

private func metadataLine(metadata: KnowledgeMetadata): String {
    "${escapeField(metadata.sourceType)}|${escapeField(metadata.sourceUrl)}|${escapeField(metadata.repo)}|${escapeField(metadata.commit)}|${escapeField(metadata.path)}|${escapeField(metadata.symbol)}|${escapeField(metadata.docVersion)}|${escapeField(metadata.crawlAt)}|${escapeField(metadata.indexedAt)}|${escapeField(metadata.knowledgeVersion)}|${escapeField(metadata.candidateVersion)}|${metadata.contentSize}|${escapeField(metadata.trustLevel)}|${escapeField(metadata.reviewState)}|${escapeField(metadata.license)}|${escapeField(metadata.sourceId)}|${escapeField(metadata.repoVisibility)}|${escapeField(metadata.targetVersion)}|${escapeField(metadata.sourceSet)}|${escapeField(metadata.versionResolutionId)}"
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
    if (parts.size > start + 16) {
        metadata.repoVisibility = unescapeField(parts[start + 16])
    }
    if (parts.size > start + 17) {
        metadata.targetVersion = unescapeField(parts[start + 17])
    }
    if (parts.size > start + 18) {
        metadata.sourceSet = unescapeField(parts[start + 18])
    }
    if (parts.size > start + 19) {
        metadata.versionResolutionId = unescapeField(parts[start + 19])
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
    if (!raw.contains(needle)) {
        return -1
    }
    raw.split(needle)[0].size
}

private func configApply(config: CkbRuntimeConfig, key: String, value: String): Unit {
    if (key == "network.enabled") {
        config.networkEnabled = parseBool(value)
    } else if (key == "gitcode.baseUrl") {
        config.gitCodeBaseUrl = if (config.gitCodeAccessTokenQuery) { value } else { stripAccessTokenQuery(value) }
    } else if (key == "gitcode.authMode") {
        config.gitCodeAuthMode = value
    } else if (key == "gitcode.authHeader") {
        config.gitCodeAuthHeader = value
    } else if (key == "gitcode.accessTokenQuery") {
        config.gitCodeAccessTokenQuery = parseBool(value)
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
    } else if (key == "embedding.model") {
        config.embeddingModel = value
    } else if (key == "embedding.dimensions") {
        config.embeddingDimensions = try { Int64.parse(value) } catch (_: Exception) { config.embeddingDimensions }
    } else if (key == "embedding.endpoint") {
        config.embeddingEndpoint = value
    } else if (key == "embedding.tokenFile") {
        config.embeddingTokenFile = value
    } else if (key == "embedding.batchSize") {
        config.embeddingBatchSize = try { Int64.parse(value) } catch (_: Exception) { config.embeddingBatchSize }
    } else if (key == "embedding.timeoutMillis") {
        config.embeddingTimeoutMillis = try { Int64.parse(value) } catch (_: Exception) { config.embeddingTimeoutMillis }
    } else if (key == "embedding.retryCount") {
        config.embeddingRetryCount = try { Int64.parse(value) } catch (_: Exception) { config.embeddingRetryCount }
    } else if (key == "embedding.allowPrivateEndpoint") {
        config.embeddingAllowPrivateEndpoint = parseBool(value)
    } else if (key == "vector.backend") {
        config.vectorBackend = value
    } else if (key == "vector.activeCollection") {
        config.vectorActiveCollection = value
    } else if (key == "vector.candidateCollection") {
        config.vectorCandidateCollection = value
    } else if (key == "vector.endpoint") {
        config.vectorEndpoint = value
    } else if (key == "vector.dimensions") {
        config.vectorDimensions = try { Int64.parse(value) } catch (_: Exception) { config.vectorDimensions }
    } else if (key == "vector.distance") {
        config.vectorDistance = value
    } else if (key == "vector.timeoutMillis") {
        config.vectorTimeoutMillis = try { Int64.parse(value) } catch (_: Exception) { config.vectorTimeoutMillis }
    } else if (key == "vector.retryCount") {
        config.vectorRetryCount = try { Int64.parse(value) } catch (_: Exception) { config.vectorRetryCount }
    } else if (key == "vector.apiKeyFile") {
        config.vectorApiKeyFile = value
    } else if (key == "vector.allowPrivateEndpoint") {
        config.vectorAllowPrivateEndpoint = parseBool(value)
    } else if (key == "network.timeoutMillis") {
        config.timeoutMillis = try { Int64.parse(value) } catch (_: Exception) { config.timeoutMillis }
    } else if (key == "network.retryCount") {
        config.retryCount = try { Int64.parse(value) } catch (_: Exception) { config.retryCount }
    } else if (key == "network.proxy") {
        config.networkProxy = value
    } else if (key == "network.envProxyEnabled") {
        config.networkEnvProxyEnabled = parseBool(value)
    } else if (key == "network.noProxy") {
        config.networkNoProxy = value
    } else if (key == "network.insecureSkipTlsVerify") {
        config.networkInsecureSkipTlsVerify = parseBool(value)
    } else if (key == "network.caFile") {
        config.networkCaFile = value
    } else if (key == "network.allowPrivateNetwork") {
        config.networkAllowPrivateNetwork = parseBool(value)
    } else if (key == "network.allowedHosts") {
        config.networkAllowedHosts = value
    } else if (key == "sourceAnalysis.enabled") {
        config.sourceAnalysisEnabled = parseBool(value)
    } else if (key == "sourceAnalysis.workspaceRoot") {
        config.sourceAnalysisWorkspaceRoot = value
    } else if (key == "sourceAnalysis.retainFailedWorkspace") {
        config.sourceAnalysisRetainFailedWorkspace = parseBool(value)
    } else if (key == "sourceAnalysis.cloneDepth") {
        config.sourceAnalysisCloneDepth = try { Int64.parse(value) } catch (_: Exception) { config.sourceAnalysisCloneDepth }
    } else if (key == "sourceAnalysis.timeoutMillis") {
        config.sourceAnalysisTimeoutMillis = try { Int64.parse(value) } catch (_: Exception) { config.sourceAnalysisTimeoutMillis }
    } else if (key == "sourceAnalysis.maxFiles") {
        config.sourceAnalysisMaxFiles = try { Int64.parse(value) } catch (_: Exception) { config.sourceAnalysisMaxFiles }
    } else if (key == "sourceAnalysis.maxFileBytes") {
        config.sourceAnalysisMaxFileBytes = try { Int64.parse(value) } catch (_: Exception) { config.sourceAnalysisMaxFileBytes }
    } else if (key == "sourceAnalysis.cloneHostAllowlist") {
        config.sourceAnalysisCloneHostAllowlist = value
    } else if (key == "service.bind") {
        config.serviceBind = value
    } else if (key == "service.port") {
        config.servicePort = try { Int64.parse(value) } catch (_: Exception) { config.servicePort }
    } else if (key == "service.adminTokenFile") {
        config.serviceAdminTokenFile = value
    } else if (key == "service.eventIngestTokenFile") {
        config.serviceEventIngestTokenFile = value
    } else if (key == "service.maxRequestBytes") {
        config.serviceMaxRequestBytes = try { Int64.parse(value) } catch (_: Exception) { config.serviceMaxRequestBytes }
    } else if (key == "service.readOnlyPublic") {
        config.serviceReadOnlyPublic = parseBool(value)
    } else if (key == "service.defaultBudget") {
        config.serviceDefaultBudget = try { Int64.parse(value) } catch (_: Exception) { config.serviceDefaultBudget }
    } else if (key == "service.maxBudget") {
        config.serviceMaxBudget = try { Int64.parse(value) } catch (_: Exception) { config.serviceMaxBudget }
    } else if (key == "scheduler.enabled") {
        config.schedulerEnabled = parseBool(value)
    } else if (key == "scheduler.loopIntervalMillis") {
        config.schedulerLoopIntervalMillis = try { Int64.parse(value) } catch (_: Exception) { config.schedulerLoopIntervalMillis }
    } else if (key == "firstInit.enabled") {
        config.firstInitEnabled = parseBool(value)
    } else if (key == "firstInit.docsRoot") {
        config.firstInitDocsRoot = value
    } else if (key == "firstInit.toolDocsRoot") {
        config.firstInitToolDocsRoot = value
    } else if (key == "firstInit.stdRoot") {
        config.firstInitStdRoot = value
    } else if (key == "firstInit.stdxRoot") {
        config.firstInitStdxRoot = value
    } else if (key == "firstInit.evalRoot") {
        config.firstInitEvalRoot = value
    } else if (key == "firstInit.targetVersion") {
        config.firstInitTargetVersion = value
    } else if (key == "benchmarkGap.curationInputPath") {
        config.benchmarkGapCurationInputPath = value
    } else if (key == "benchmarkGap.targetVersion") {
        config.benchmarkGapTargetVersion = value
    }
}

private func parseIntField(value: String, fallback: Int64): Int64 {
    try { Int64.parse(value) } catch (_: Exception) { fallback }
}

private func firstToken(line: String): String {
    let parts = line.split(" ")
    if (parts.size == 0) {
        return ""
    }
    parts[0].trimAscii()
}

private func lineTail(line: String, command: String): String {
    if (line.size <= command.size) {
        return ""
    }
    line[command.size..line.size].trimAscii()
}

private func parseBool(value: String): Bool {
    let lowered = value.toAsciiLower()
    lowered == "true" || lowered == "1" || lowered == "yes" || lowered == "enabled"
}

private func stripAccessTokenQuery(raw: String): String {
    let needle = "access_token="
    if (!raw.contains(needle)) {
        return raw
    }
    var prefix = textBeforeFirst(raw, needle)
    let tail = textAfterFirst(raw, needle)
    var delimiter = ""
    if (prefix.endsWith("?")) {
        prefix = prefix[0..prefix.size - 1]
        delimiter = "?"
    } else if (prefix.endsWith("&")) {
        prefix = prefix[0..prefix.size - 1]
        delimiter = "&"
    }
    let rest = tailAfterRedactedValue(tail, RedactStopMode.QUERY)
    if (delimiter == "?" && rest.startsWith("&")) {
        return prefix + "?" + rest[1..rest.size]
    }
    prefix + rest
}

private func textBeforeFirst(raw: String, needle: String): String {
    raw.split(needle)[0]
}

private func textAfterFirst(raw: String, needle: String): String {
    let parts = raw.split(needle)
    if (parts.size <= 1) {
        return ""
    }
    var out = ""
    for (i in 1..parts.size) {
        if (i > 1) {
            out += needle
        }
        out += parts[i]
    }
    out
}

private class RedactStopMode {
    public static const QUERY = "query"
    public static const TOKEN = "token"
    public static const LINE = "line"
    public static const PATH = "path"
    public static const URL_AUTHORITY = "url-authority"
}

private func tailAfterRedactedValue(tail: String, mode: String): String {
    let out = StringBuilder()
    var redacting = true
    for (ch in tail.toRuneArray()) {
        if (redacting) {
            if (isRedactStopRune(ch, mode)) {
                redacting = false
                out.append(ch)
            }
        } else {
            out.append(ch)
        }
    }
    out.toString()
}

private func isRedactStopRune(ch: Rune, mode: String): Bool {
    if (mode == RedactStopMode.LINE) {
        return ch == r'\n' || ch == r'\r'
    }
    if (mode == RedactStopMode.QUERY) {
        return ch == r'&' || ch == r'#' || ch == r' ' || ch == r'\n' || ch == r'\r' || ch == r'"' || ch == r'\''
    }
    if (mode == RedactStopMode.URL_AUTHORITY) {
        return ch == r'/' || ch == r' ' || ch == r'\n' || ch == r'\r' || ch == r'"' || ch == r'\''
    }
    ch == r'&' || ch == r' ' || ch == r'\n' || ch == r'\r' || ch == r'"' || ch == r'\''
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
    text = redactAfterNeedle(text, "?${needle1}")
    text = redactAfterNeedle(text, "&${needle1}")
    text = redactAfterNeedle(text, needle1)
    text = redactAfterNeedle(text, "?${needle2}")
    text = redactAfterNeedle(text, "&${needle2}")
    text = redactAfterNeedle(text, needle2)
    text
}

private func redactAssignment(raw: String, key: String): String {
    var text = raw
    if (key == "Authorization" || key == "authorization") {
        text = redactLineAfterNeedle(text, "${key}: ")
        text = redactLineAfterNeedle(text, "${key}:")
        text = redactLineAfterNeedle(text, "${key}=")
    } else if (key == "Cookie" || key == "cookie") {
        text = redactLineAfterNeedle(text, "${key}: ")
        text = redactLineAfterNeedle(text, "${key}:")
        text = redactAfterNeedle(text, "${key}=")
    } else {
        text = redactAfterNeedle(text, "${key}: ")
        text = redactAfterNeedle(text, "${key}:")
        text = redactAfterNeedle(text, "${key}=")
    }
    text
}

private func redactAfterNeedle(raw: String, needle: String): String {
    redactAllAfterNeedle(raw, needle, RedactStopMode.TOKEN)
}

private func redactLineAfterNeedle(raw: String, needle: String): String {
    redactAllAfterNeedle(raw, needle, RedactStopMode.LINE)
}

private func redactAllAfterNeedle(raw: String, needle: String, mode: String): String {
    if (!raw.contains(needle)) {
        return raw
    }
    var remaining = raw
    var out = ""
    while (remaining.contains(needle)) {
        out += textBeforeFirst(remaining, needle) + needle + "[redacted]"
        remaining = tailAfterRedactedValue(textAfterFirst(remaining, needle), mode)
    }
    out + remaining
}

private func redactProxyCredentials(raw: String): String {
    var text = raw
    text = redactProxyCredentialsForScheme(text, "http://")
    text = redactProxyCredentialsForScheme(text, "https://")
    text
}

private func redactProxyCredentialsForScheme(raw: String, scheme: String): String {
    if (!raw.contains(scheme)) {
        return raw
    }
    let prefix = textBeforeFirst(raw, scheme) + scheme
    let tail = textAfterFirst(raw, scheme)
    let authority = textBeforeFirstAuthorityStop(tail)
    let rest = tailAfterRedactedValue(tail, RedactStopMode.URL_AUTHORITY)
    if (!authority.contains("@")) {
        return prefix + authority + redactProxyCredentialsForScheme(rest, scheme)
    }
    let authParts = authority.split("@")
    var host = ""
    for (i in 1..authParts.size) {
        if (i > 1) {
            host += "@"
        }
        host += authParts[i]
    }
    prefix + "[redacted]@" + host + redactProxyCredentialsForScheme(rest, scheme)
}

private func textBeforeFirstAuthorityStop(raw: String): String {
    let out = StringBuilder()
    for (ch in raw.toRuneArray()) {
        if (isRedactStopRune(ch, RedactStopMode.URL_AUTHORITY)) {
            break
        }
        out.append(ch)
    }
    out.toString()
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
    if (!raw.contains(prefix)) {
        return raw
    }
    textBeforeFirst(raw, prefix) + "[local-path-redacted]" + tailAfterRedactedValue(textAfterFirst(raw, prefix), RedactStopMode.PATH)
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

private func parseGitCodeContentsFile(body: String, expectedPath: String): GitCodeContentsFile {
    let parsed = GitCodeContentsFile()
    let safeBody = asciiJsonProjection(body)
    if (jsonStringField(safeBody, "type") != "file") {
        parsed.status = "malformed_contents_response"
        return parsed
    }
    let path = jsonStringField(safeBody, "path")
    if (path == "" || path != expectedPath) {
        parsed.status = "contents_path_mismatch"
        return parsed
    }
    if (jsonStringField(safeBody, "encoding").toAsciiLower() != "base64") {
        parsed.status = "unsupported_contents_encoding"
        return parsed
    }
    let content = jsonStringField(safeBody, "content")
    if (content == "") {
        parsed.status = "malformed_contents_response"
        return parsed
    }
    let decoded = decodeBase64Utf8(content)
    if (!decoded.ok) {
        parsed.status = decoded.status
        return parsed
    }
    parsed.ok = true
    parsed.status = "ok"
    parsed.body = decoded.body
    parsed.path = path
    parsed.sha = jsonStringField(safeBody, "sha")
    parsed.htmlUrl = jsonStringField(safeBody, "html_url")
    parsed.downloadUrl = jsonStringField(safeBody, "download_url")
    parsed
}

private class Base64DecodeResult {
    var ok: Bool = false
    var status: String = "invalid_base64"
    var body: String = ""

    init() {}
}

private func decodeBase64Utf8(raw: String): Base64DecodeResult {
    let result = Base64DecodeResult()
    let bytes = ArrayList<Byte>()
    var buffer: Int64 = 0
    var bits: Int64 = 0
    var padding = false
    for (ch in raw.toRuneArray()) {
        if (ch == r' ' || ch == r'\n' || ch == r'\r' || ch == r'\t') {
            continue
        }
        if (ch == r'=') {
            padding = true
            continue
        }
        if (padding) {
            return result
        }
        let value = base64Value(ch)
        if (value < 0) {
            return result
        }
        buffer = buffer * 64 + value
        bits += 6
        while (bits >= 8) {
            bits -= 8
            let byteValue = (buffer / pow2(bits)) % 256
            bytes.add(UInt8(byteValue))
        }
        if (bits > 0) {
            buffer = buffer % pow2(bits)
        } else {
            buffer = 0
        }
    }
    try {
        result.body = String.fromUtf8(bytes.toArray())
        result.ok = true
        result.status = "ok"
    } catch (_: Exception) {
        result.status = "invalid_utf8_contents"
    }
    result
}

private func base64Value(ch: Rune): Int64 {
    let code = Int64(UInt32(ch))
    if (code >= Int64(UInt32(r'A')) && code <= Int64(UInt32(r'Z'))) {
        return code - Int64(UInt32(r'A'))
    }
    if (code >= Int64(UInt32(r'a')) && code <= Int64(UInt32(r'z'))) {
        return 26 + code - Int64(UInt32(r'a'))
    }
    if (code >= Int64(UInt32(r'0')) && code <= Int64(UInt32(r'9'))) {
        return 52 + code - Int64(UInt32(r'0'))
    }
    if (ch == r'+') {
        return 62
    }
    if (ch == r'/') {
        return 63
    }
    -1
}

private func pow2(bits: Int64): Int64 {
    var out: Int64 = 1
    for (_ in 0..bits) {
        out *= 2
    }
    out
}

private func parseCurlContentType(raw: String): String {
    let marker = "CKB_CONTENT_TYPE:"
    let idx = findText(raw, marker)
    if (idx < 0) {
        return ""
    }
    raw[idx + marker.size..raw.size].split("\n")[0].trimAscii()
}

private func renderLiveFetchSummary(request: SourceFetchRequest, fetch: SourceFetchResult, auth: GitCodeAuthResolution): String {
    var shape = "unknown"
    if (request.kind == SourceKinds.GITCODE_ORG) {
        shape = "repo-list"
    } else if (request.kind == SourceKinds.CANGJIE_WEBSITE || request.kind == SourceKinds.CANGJIE_DOCS) {
        shape = "html-entry"
    } else if (request.kind == SourceKinds.GITCODE_ISSUE_HISTORY || request.kind == SourceKinds.GITCODE_PR_HISTORY || request.kind == SourceKinds.GITCODE_COMMENT_HISTORY) {
        shape = "history-list"
    } else if (request.kind == SourceKinds.GITCODE_REPO) {
        shape = "repo-metadata"
    } else if (request.kind == SourceKinds.GITCODE_TREE) {
        shape = "source-tree"
    } else if (request.kind == SourceKinds.GITCODE_SOURCE) {
        shape = "source-snapshot"
    }
    var out = "request kind=${request.kind} method=${request.method} sourceUrl=${redactSensitive(request.url)} pageParam=${request.paginationParam} perPageParam=${request.perPageParam} timeoutMillis=${request.timeoutMillis} retryCount=${request.retryCount} auth=${auth.state} authHeader=${auth.headerStrategy}"
    out += " -> status=${fetch.status} httpStatus=${fetch.statusCode} shape=${shape} bytes=${fetch.bytes} contentType=${fetch.contentType} bodyHash=${fetch.bodyHash} attempts=${fetch.attempts} errorClass=${classifyFetchError(fetch)}"
    if (request.kind == SourceKinds.GITCODE_SOURCE && request.sourceVariant != "") {
        out += " sourceVariant=${request.sourceVariant} sourceMaxFileBytes=${SourceLimits.MAX_FILE_BYTES}"
    }
    if (auth.diagnostic != "") {
        out += " authDiagnostic=${auth.diagnostic}"
    }
    if (request.diagnostic != "") {
        out += " requestDiagnostic=${request.diagnostic}"
    }
    if (fetch.status == "timeout" || fetch.status == "transport_error") {
        if (fetch.transportErrorClass != "") {
            out += " transportClass=${fetch.transportErrorClass}"
        }
        if (fetch.transportDiagnostic != "") {
            out += " transportDiagnostic=${fetch.transportDiagnostic}"
        }
    }
    if (fetch.retryAfterSeconds > 0) {
        out += " retryAfter=${fetch.retryAfterSeconds}"
    }
    out + "\n"
}

private func classifyFetchError(fetch: SourceFetchResult): String {
    if (fetch.ok) {
        return "none"
    }
    if (fetch.status == "network_disabled") {
        return "network_disabled"
    }
    if (fetch.status == "auth_degraded") {
        return "auth"
    }
    if (fetch.status == "rate_limited") {
        return "rate_limit"
    }
    if (fetch.status == "timeout") {
        return "timeout"
    }
    if (fetch.status == "transport_error") {
        return "transport"
    }
    if (fetch.status == "not_found") {
        return "not_found"
    }
    if (fetch.status == "server_error") {
        return "server"
    }
    if (fetch.status == "invalid_repo_path" || fetch.status == "invalid_source_path" || fetch.status == "invalid_ref") {
        return "validation"
    }
    "http"
}

private func ingestLiveFetch(kb: KnowledgeBase, request: SourceFetchRequest, fetch: SourceFetchResult): Unit {
    if (request.kind == SourceKinds.GITCODE_ORG) {
        kb.ingestFetchResult("live-org-${safeName(request.repo)}", SourceTypes.COMMUNITY, fetch, "GitCode ${request.repo} repo list", TrustLevels.COMMUNITY, ReviewStates.REVIEWED)
    } else if (request.kind == SourceKinds.GITCODE_REPO) {
        kb.ingestFetchResult("live-repo-${safeName(request.repo)}", SourceTypes.REPO, fetch, "GitCode ${request.repo} repo", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    } else if (request.kind == SourceKinds.GITCODE_TREE) {
        kb.ingestFetchResult("live-tree-${safeName(request.repo)}", SourceTypes.REPO, fetch, "GitCode ${request.repo} tree", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    } else if (request.kind == SourceKinds.GITCODE_SOURCE) {
        kb.ingestFetchResult("live-source-${safeName(request.repo)}-${safeName(request.path)}", SourceTypes.REPO, fetch, "GitCode ${request.repo} source", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    } else if (request.kind == SourceKinds.GITCODE_ISSUE_HISTORY) {
        kb.ingestFetchResult("live-issue-${safeName(request.repo)}", SourceTypes.COMMUNITY, fetch, "GitCode issue history", TrustLevels.COMMUNITY, ReviewStates.REVIEWED)
    } else if (request.kind == SourceKinds.GITCODE_PR_HISTORY) {
        kb.ingestFetchResult("live-pr-${safeName(request.repo)}", SourceTypes.COMMUNITY, fetch, "GitCode PR history", TrustLevels.COMMUNITY, ReviewStates.REVIEWED)
    } else if (request.kind == SourceKinds.GITCODE_COMMENT_HISTORY) {
        kb.ingestFetchResult("live-comments-${safeName(request.repo)}", SourceTypes.COMMUNITY, fetch, "GitCode comment history", TrustLevels.COMMUNITY, ReviewStates.REVIEWED)
    } else if (request.kind == SourceKinds.CANGJIE_DOCS) {
        kb.ingestFetchResult("live-docs-${safeName(request.url)}", SourceTypes.DOC, fetch, "Cangjie docs", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    } else if (request.kind == SourceKinds.CANGJIE_WEBSITE) {
        kb.ingestFetchResult("live-website-${safeName(request.url)}", SourceTypes.WEBSITE, fetch, "Cangjie website", TrustLevels.OFFICIAL, ReviewStates.TRUSTED)
    } else if (request.kind == SourceKinds.WEB_CANDIDATE) {
        kb.ingestFetchResult("live-web-candidate-${safeName(request.url)}", SourceTypes.WEB_CANDIDATE, fetch, "Web candidate", TrustLevels.WEB_CANDIDATE, ReviewStates.CANDIDATE)
    }
}
