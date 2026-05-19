package cangjie_community_knowledge_base_test

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
    public var status: String = "ready"
    public var diagnostic: String = ""
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
    public var transportErrorClass: String = ""
    public var transportDiagnostic: String = ""
    public var curlExitCode: Int64 = 0

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
        result.contentType = if (request.accept == "text/html") { "text/html" } else { "application/json" }
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
    public var vectorBackend: String = "local-file"
    public var vectorActiveCollection: String = "active"
    public var vectorCandidateCollection: String = "candidate"
    public var timeoutMillis: Int64 = 10000
    public var retryCount: Int64 = 2

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
        out += " gitcode.token=${if (this.tokenPresent()) { "present" } else { "absent" }}"
        out += " gitcode.auth=${auth.state}"
        if (auth.diagnostic != "") {
            out += " gitcode.authDiagnostic=${auth.diagnostic}"
        }
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
        out += " vector.backend=${this.vectorBackend}"
        out += " vector.activeCollection=${this.vectorActiveCollection}"
        out += " vector.candidateCollection=${this.vectorCandidateCollection}"
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
    var i: Int64 = 0
    var inString = false
    var escaped = false
    var depth: Int64 = 0
    var start: Int64 = -1
    while (i < trimmed.size) {
        let ch = trimmed[i..i + 1]
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
            if (depth == 0) {
                start = i
            }
            depth += 1
        } else if (ch == "}") {
            depth -= 1
            if (depth == 0 && start >= 0) {
                let metadata = parseGitCodeRepoObject(trimmed[start..i + 1])
                if (metadata.fullName != "") {
                    repos.add(metadata)
                }
                start = -1
            }
        }
        i += 1
    }
    repos
}

private func parseGitCodeRepoObject(raw: String): GitCodeRepoMetadata {
    let metadata = GitCodeRepoMetadata()
    let namespaceObject = jsonObjectField(raw, "namespace")
    metadata.org = jsonStringField(namespaceObject, "path")
    metadata.owner = metadata.org
    metadata.repo = jsonStringField(raw, "path")
    if (metadata.repo == "") {
        metadata.repo = jsonStringField(raw, "name")
    }
    if (metadata.owner != "" && metadata.repo != "" && isSafeGitCodePathPart(metadata.owner) && isSafeGitCodePathPart(metadata.repo)) {
        metadata.fullName = "${metadata.owner}/${metadata.repo}"
    }
    metadata.defaultBranch = jsonStringField(raw, "default_branch")
    if (metadata.defaultBranch == "") {
        metadata.defaultBranch = jsonStringField(raw, "defaultBranch")
    }
    metadata.sourceUrl = firstNonEmptyJsonString(raw, ["web_url", "html_url", "sourceUrl", "url"])
    metadata.rawId = jsonScalarField(raw, "id")
    let visibilityText = normalizeRepoVisibility(jsonStringField(raw, "visibility"))
    metadata.private = jsonBoolField(raw, "private") || visibilityText == RepoVisibility.PRIVATE
    metadata.internal = jsonBoolField(raw, "internal") || visibilityText == RepoVisibility.INTERNAL
    metadata.public = jsonBoolField(raw, "public") || visibilityText == RepoVisibility.PUBLIC
    metadata.visibility = deriveRepoVisibility(metadata.private, metadata.internal, metadata.public)
    metadata
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
    text = redactAbsolutePath(text)
    text
}

private func sanitizedTransportDiagnostic(raw: String): String {
    var text = redactSensitive(raw).replace("\n", " ").replace("\r", " ").trimAscii()
    if (text.size > 160) {
        text = text[0..160]
    }
    text
}

public class HttpExecutionRequest {
    public var method: String = "GET"
    public var url: String = ""
    public var accept: String = "application/json"
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
    func get(request: HttpExecutionRequest): HttpExecutionResponse
}

private func curlRequestArgs(request: HttpExecutionRequest, timeoutSeconds: String): Array<String> {
    let args = ArrayList<String>()
    args.add("-sS")
    args.add("-L")
    args.add("--max-time")
    args.add(timeoutSeconds)
    args.add("-H")
    args.add("Accept: ${request.accept}")
    for (header in request.headers) {
        args.add("-H")
        args.add(header)
    }
    args.add("-w")
    args.add("\nCKB_HTTP_STATUS:%{http_code}\nCKB_CONTENT_TYPE:%{content_type}\n")
    args.add(request.url)
    args.toArray()
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

    public func gitCodeOrgRepos(org: String): SourceFetchRequest {
        let request = SourceFetchRequest(SourceKinds.GITCODE_ORG, "${this.gitCodeApiRoot}/orgs/${org}/repos?type=public&page=1&per_page=100", repo: org, purpose: "enumerate_public_repos")
        request.authHint = "gitcode-token-optional-redacted"
        request.paginationParam = "page"
        request.perPageParam = "per_page"
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
        let parts = parseGitCodeRepoPath(repo)
        if (!parts.valid) {
            return invalidSourceFetchRequest(SourceKinds.GITCODE_SOURCE, "source_snapshot", parts.diagnostic)
        }
        if (!isSafeGitCodeRef(ref)) {
            return invalidSourceFetchRequest(SourceKinds.GITCODE_SOURCE, "source_snapshot", "invalid_ref")
        }
        let safePath = normalizeGitCodeSourcePath(path)
        if (safePath == "") {
            return invalidSourceFetchRequest(SourceKinds.GITCODE_SOURCE, "source_snapshot", "invalid_source_path")
        }
        let normalizedRepo = "${parts.owner}/${parts.repo}"
        let request = SourceFetchRequest(SourceKinds.GITCODE_SOURCE, "${this.gitCodeApiRoot}/repos/${parts.owner}/${parts.repo}/contents/${safePath}?ref=${ref}", repo: normalizedRepo, ref: ref, path: safePath, accept: "text/plain", purpose: "source_snapshot")
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
    if (trimmed == "" || trimmed.contains("%") || trimmed.contains("?") || trimmed.contains("#") || trimmed.contains("&") || trimmed.contains("=") || trimmed.contains("\n") || trimmed.contains("\r") || trimmed.contains("\t")) {
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
    let applyOptions = liveApplyOptionsFromSync(options)
    let plan = limitedPlan(planner.productionPlan(kb.sourceScope), applyOptions)
    var out = "sync-live mode=${if (options.dryRun) { "dry-run" } else { "apply" }} requests=${plan.requests.size} websiteEnabled=${config.websiteEnabled} docsEnabled=${config.docsEnabled} ${config.redactedSummary()}\n"
    var okCount: Int64 = 0
    var degradedCount: Int64 = 0
    for (request in plan.requests) {
        request.timeoutMillis = config.timeoutMillis
        request.retryCount = config.retryCount
        if (!config.websiteEnabled && request.kind == SourceKinds.CANGJIE_WEBSITE) {
            out += "skip kind=${request.kind} reason=website_disabled auth=none sourceUrl=${redactSensitive(request.url)}\n"
            continue
        }
        if (!config.docsEnabled && request.kind == SourceKinds.CANGJIE_DOCS) {
            out += "skip kind=${request.kind} reason=docs_disabled auth=none sourceUrl=${redactSensitive(request.url)}\n"
            continue
        }
        let fetch = SourceResponseNormalizer().normalize(request, runner.fetch(request))
        if (fetch.ok) {
            okCount += 1
        } else {
            degradedCount += 1
        }
        out += renderLiveFetchSummary(request, fetch, authSummaryForRequest(config, request))
        if (options.apply && fetch.ok) {
            ingestLiveFetch(kb, request, fetch, okCount + degradedCount)
        }
    }
    var activePromoted = false
    var candidateWritten = false
    if (options.apply) {
        kb.normalize()
        kb.publishIndex(options.simulateValidationFailure)
        kb.persistCandidateSnapshot(store)
        candidateWritten = true
        if (kb.status().failedCandidateVersion == "") {
            kb.persistActiveSnapshot(store)
            activePromoted = true
        }
    }
    out += "summary requests=${plan.requests.size} ok=${okCount} degraded=${degradedCount} truncated=${plan.truncated} rawWritten=${if (options.apply && activePromoted) { "true" } else { "false" }} candidateWritten=${candidateWritten} activePromoted=${activePromoted} since=${options.since}\n"
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
            text += "${escapeField(entry.name)}|${entry.intervalMinutes}|${entry.nextRunAt}|${entry.lastStartedAt}|${entry.lastSuccessAt}|${entry.lastFailureAt}|${entry.failureCount}|${entry.degraded}|${escapeField(entry.lastCursor)}|${escapeField(entry.lastSince)}|${escapeField(entry.activeVersion)}|${escapeField(entry.candidateVersion)}|${escapeField(entry.lastStatus)}\n"
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
        "tools: cangjie.health,cangjie.status,cangjie.query,cangjie.evidence,cangjie.sync,cangjie.rebuild,cangjie.source_search,cangjie.doc_search,cangjie.website_search,cangjie.web_candidate_search,cangjie.hybrid_search,cangjie.evidence_pack; input: query{q,budget,sourceType,includeCandidates=false}, evidence{q,budget,includeCandidates=true}, sync{dryRun,apply,maxRepos,maxFilesPerRepo,maxItems,since}, rebuild{store}; liveGitCode: officialApi=https://api.gitcode.com/api/v5 authMode=token authHeader=private-token tokenFile=tokenFile tokenFileFormat=single PAT line without token/Bearer/PRIVATE-TOKEN prefix; acceptance: schema -> doctor/status -> anonymous dry-run -> credentialed dry-run if needed -> limited apply -> rebuild-index -> status/evidence; output: ok,status,errorCode,activeKnowledgeVersion,knowledgeVersion,citations,evidence,requiresReview,truncated,degraded,transportDiagnostic; redaction: never returns tokenRef,tokenFile contents,PRIVATE-TOKEN,Authorization,Cookie,private-token values,absolute local paths; errors: ckb.bad_request,ckb.network_disabled,ckb.auth_degraded,ckb.rate_limited,ckb.source_unavailable,ckb.rebuild_failed,ckb.validation_failed"
    }

    public static func httpLikeRoutes(): String {
        "routes: STDIO ckb-stdio-v1 health,status,metrics,query <text>,evidence <text>,sync,rebuild,scheduler-run,backup <name>,restore <name>,restart,stop; GET /health -> ok,status,activeKnowledgeVersion,degraded; GET /status -> storage,indexManifest,scheduler,activeKnowledgeVersion,restoreDiagnostic,authHeaderStrategy; POST /query -> query,evidence,citations,knowledgeVersion; POST /evidence -> evidencePack,graphContext,citations,activeKnowledgeVersion; POST /sync -> dryRun|apply,candidateVersion,activeKnowledgeVersion,redactedSourceStatus,transportDiagnostic; POST /rebuild-index -> candidateVersion,activeKnowledgeVersion,count; compatibility: CLI service/status/rebuild-index provide the canonical local protocol"
    }
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

    public func runTask(name: String, since: String): SchedulerTaskResult {
        let result = SchedulerTaskResult()
        result.since = if (since == "") { "0" } else { since }
        if (name == "weekly_full_rebuild") {
            let rebuild = ckbRebuildIndex(this.kb, this.store)
            result.ok = rebuild.ok
            result.status = if (rebuild.ok) { "rebuild_ok" } else { "rebuild_failed" }
            result.cursor = "rebuild-${rebuild.activeVersion}"
            result.activeVersion = rebuild.activeVersion
            result.candidateVersion = rebuild.candidateVersion
            return result
        }
        let options = LiveSyncOptions()
        options.apply = true
        options.maxItems = 3
        options.since = result.since
        let text = ckbSyncLive(this.kb, this.config, options, runner: this.sourceRunner, store: this.store)
        let status = this.kb.status()
        result.ok = text.contains("summary") && !text.contains("network=disabled") && !text.contains("usage error")
        result.status = if (result.ok) { "sync_ok" } else { "sync_failed" }
        result.cursor = "cursor-${status.activeKnowledgeVersion}"
        result.since = "${this.kb.scheduler.clock.nowMinutes}"
        result.activeVersion = status.activeKnowledgeVersion
        result.candidateVersion = status.candidateKnowledgeVersion
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
    private var started: Bool = false

    public init(config: CkbRuntimeConfig, store: FileKnowledgeStore, sourceRunner!: SourceFetchRunner = DisabledNetworkFetchRunner()) {
        this.config = config
        this.store = store
        this.sourceRunner = sourceRunner
        this.kb = newKnowledgeBaseFromStore(store).kb
    }

    public func start(): String {
        this.started = true
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
        } else if (command == "sync") {
            let options = LiveSyncOptions()
            options.apply = true
            options.maxItems = 3
            response.text = ckbSyncLive(this.kb, this.config, options, runner: this.sourceRunner, store: this.store)
        } else if (command == "rebuild") {
            let result = ckbRebuildIndex(this.kb, this.store)
            response.text = "rebuild ok=${result.ok} activeKnowledgeVersion=${result.activeVersion} candidateKnowledgeVersion=${result.candidateVersion} count=${result.count}\n"
        } else if (command == "scheduler-run") {
            let executor = SchedulerExecutor(this.kb.scheduler, CkbSchedulerTaskRunner(this.kb, this.config, this.store, sourceRunner: this.sourceRunner))
            let result = executor.runDue()
            this.store.saveScheduler(this.kb.scheduler.entries)
            response.text = "scheduler ran=${result.ran} succeeded=${result.succeeded} failed=${result.failed} degraded=${result.degraded}\n${result.details}"
        } else if (command == "backup") {
            response.text = renderBackupRestore(this.store.backupActiveSnapshot(tail))
        } else if (command == "restore") {
            let result = this.store.restoreActiveSnapshotBackup(tail)
            if (result.ok) {
                this.kb = newKnowledgeBaseFromStore(this.store).kb
            }
            response.text = renderBackupRestore(result)
        } else if (command == "restart") {
            this.kb = newKnowledgeBaseFromStore(this.store).kb
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

    private func health(): String {
        let status = this.kb.status()
        "health ok=true protocol=ckb-stdio-v1 activeKnowledgeVersion=${status.activeKnowledgeVersion} activeStateSource=${status.activeStateSource} restoreDiagnostic=${status.restoreDiagnostic} vectorState=${status.storage.vectorState} graphState=${status.storage.graphState}\n"
    }

    private func logLine(level: String, event: String): String {
        let status = this.kb.status()
        "log level=${level} event=${event} protocol=ckb-stdio-v1 activeKnowledgeVersion=${status.activeKnowledgeVersion} store=redacted\n"
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

public func embeddingConfigFromRuntime(config: CkbRuntimeConfig): EmbeddingConfig {
    let embedding = EmbeddingConfig()
    embedding.provider = config.embeddingProvider
    embedding.model = if (config.embeddingModel == "") { "deterministic-token-v1" } else { config.embeddingModel }
    embedding.dimensions = if (config.embeddingDimensions <= 0) { 16 } else { config.embeddingDimensions }
    embedding.endpoint = config.embeddingEndpoint
    embedding.tokenFile = config.embeddingTokenFile
    embedding.batchSize = config.embeddingBatchSize
    embedding.timeoutMillis = config.embeddingTimeoutMillis
    embedding.retryCount = config.embeddingRetryCount
    embedding.production = !(config.embeddingProvider == "deterministic" || config.embeddingProvider == "local" || config.embeddingProvider == "local-file")
    embedding.configured = config.embeddingProvider != "" && config.embeddingProvider != "none"
    embedding
}

public func embeddingProviderFromRuntime(config: CkbRuntimeConfig): EmbeddingProvider {
    let embedding = embeddingConfigFromRuntime(config)
    if (embedding.provider == "deterministic" || embedding.provider == "local" || embedding.provider == "local-file") {
        embedding.provider = "deterministic"
        embedding.production = false
        embedding.configured = true
        return DeterministicEmbeddingProvider(embedding)
    }
    ProductionEmbeddingProvider(embedding)
}

public func newKnowledgeBaseFromStoreWithRuntime(store: FileKnowledgeStore, config: CkbRuntimeConfig): KnowledgeBaseLoadResult {
    let kb = KnowledgeBase(FakeClock(0), embeddingProviderFromRuntime(config), LocalVectorStore(), LocalGraphStore())
    kb.configureVectorCollections(config.vectorActiveCollection, config.vectorCandidateCollection)
    kb.bootstrapOffline()
    let result = KnowledgeBaseLoadResult(kb)
    let snapshot = store.loadActiveSnapshot()
    if (kb.restoreActiveSnapshot(snapshot)) {
        result.source = "persisted"
        result.diagnostic = snapshot.diagnostic
        return result
    }
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
    request.kind == SourceKinds.GITCODE_ORG || request.kind == SourceKinds.GITCODE_REPO || request.kind == SourceKinds.GITCODE_SOURCE || request.kind == SourceKinds.GITCODE_ISSUE_HISTORY || request.kind == SourceKinds.GITCODE_PR_HISTORY
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
    } else if (key == "vector.backend") {
        config.vectorBackend = value
    } else if (key == "vector.activeCollection") {
        config.vectorActiveCollection = value
    } else if (key == "vector.candidateCollection") {
        config.vectorCandidateCollection = value
    } else if (key == "network.timeoutMillis") {
        config.timeoutMillis = try { Int64.parse(value) } catch (_: Exception) { config.timeoutMillis }
    } else if (key == "network.retryCount") {
        config.retryCount = try { Int64.parse(value) } catch (_: Exception) { config.retryCount }
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
    let idx = findText(raw, needle)
    if (idx < 0) {
        return raw
    }
    var start = idx
    var delimiter = ""
    if (idx > 0) {
        let previous = raw[idx - 1..idx]
        if (previous == "?" || previous == "&") {
            start = idx - 1
            delimiter = previous
        }
    }
    var end = idx + needle.size
    while (end < raw.size) {
        let ch = raw[end..end + 1]
        if (ch == "&" || ch == "#" || ch == " " || ch == "\n" || ch == "\r" || ch == "\"" || ch == "'") {
            break
        }
        end += 1
    }
    if (delimiter == "?" && end < raw.size && raw[end..end + 1] == "&") {
        return raw[0..start + 1] + raw[end + 1..raw.size]
    }
    raw[0..start] + raw[end..raw.size]
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

private func renderLiveFetchSummary(request: SourceFetchRequest, fetch: SourceFetchResult, auth: GitCodeAuthResolution): String {
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
    var out = "request kind=${request.kind} method=${request.method} sourceUrl=${redactSensitive(request.url)} pageParam=${request.paginationParam} perPageParam=${request.perPageParam} timeoutMillis=${request.timeoutMillis} retryCount=${request.retryCount} auth=${auth.state} authHeader=${auth.headerStrategy}"
    out += " -> status=${fetch.status} httpStatus=${fetch.statusCode} shape=${shape} bytes=${fetch.bytes} contentType=${fetch.contentType} bodyHash=${fetch.bodyHash} attempts=${fetch.attempts} errorClass=${classifyFetchError(fetch)}"
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
        if (fetch.curlExitCode != 0) {
            out += " curlExitCode=${fetch.curlExitCode}"
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
