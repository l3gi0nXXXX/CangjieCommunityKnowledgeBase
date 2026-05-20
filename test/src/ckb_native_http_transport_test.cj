package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{File, Path, exists}
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbNativeHttpTransportTest {
    @TestCase
    public func httpRunnerKeepsStatusMappingAndRetryWithoutCurlExitDependency(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let request = SourceRequestBuilder().gitCodeOrgRepos("cangjie")
        request.retryCount = 2
        let executor = NativeContractSequenceHttpExecutor()
        executor.add(500, "{\"message\":\"server down\"}", "application/json", "http_500", 0)
        executor.add(200, "[{\"path\":\"stdx\",\"public\":true,\"namespace\":{\"path\":\"cangjie\"}}]", "application/json", "http_200", 0)

        let fetch = HttpSourceFetchRunner(config, executor: executor).fetch(request)

        @Expect(fetch.ok, true)
        @Expect(fetch.status, "ok")
        @Expect(fetch.statusCode, 200)
        @Expect(fetch.attempts, 2)
        @Expect(executor.calls, 2)
        @Expect(fetch.curlExitCode, 0)
        @Expect(fetch.transportDiagnostic.contains("curl"), false)
    }

    @TestCase
    public func httpRunnerMapsNativeTimeoutDiagnosticWithoutCurlExitCode(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let request = SourceRequestBuilder().gitCodeOrgRepos("cangjie")
        request.retryCount = 1
        let executor = NativeContractSequenceHttpExecutor()
        executor.addNativeTransportFailure("timeout", "native request timed out while connecting to api.gitcode.com")
        executor.addNativeTransportFailure("timeout", "native request timed out while connecting to api.gitcode.com")

        let fetch = HttpSourceFetchRunner(config, executor: executor).fetch(request)

        @Expect(fetch.ok, false)
        @Expect(fetch.status, "timeout")
        @Expect(fetch.statusCode, 0)
        @Expect(fetch.attempts, 2)
        @Expect(fetch.transportErrorClass, "timeout")
        @Expect(fetch.transportDiagnostic.contains("api.gitcode.com"), true)
        @Expect(fetch.transportDiagnostic.contains("curl"), false)
        @Expect(fetch.curlExitCode, 0)
    }

    @TestCase
    public func httpRunnerMapsAuthRateLimitNotFoundAndServerStatuses(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let request = SourceRequestBuilder().gitCodeOrgRepos("cangjie")
        request.retryCount = 0

        let unauthorized = HttpSourceFetchRunner(config, executor: singleStatusExecutor(401, "http_401", 0)).fetch(request)
        let forbidden = HttpSourceFetchRunner(config, executor: singleStatusExecutor(403, "http_403", 0)).fetch(request)
        let missing = HttpSourceFetchRunner(config, executor: singleStatusExecutor(404, "http_404", 0)).fetch(request)
        let limited = HttpSourceFetchRunner(config, executor: singleStatusExecutor(429, "http_429", 60)).fetch(request)
        let server = HttpSourceFetchRunner(config, executor: singleStatusExecutor(503, "http_503", 0)).fetch(request)

        @Expect(unauthorized.status, "auth_degraded")
        @Expect(forbidden.status, "auth_degraded")
        @Expect(missing.status, "not_found")
        @Expect(limited.status, "rate_limited")
        @Expect(limited.retryAfterSeconds, 60)
        @Expect(server.status, "server_error")
        @Expect(unauthorized.curlExitCode, 0)
        @Expect(limited.curlExitCode, 0)
        @Expect(server.curlExitCode, 0)
    }

    @TestCase
    public func networkDisabledStopsBeforeExecutorAndBeforeCredentialRead(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = false
        config.gitCodeAuthMode = "token"
        config.gitCodeTokenFile = "target/ckb-native-http-test-missing-token"
        let executor = NativeContractSequenceHttpExecutor()
        executor.add(200, "{}", "application/json", "http_200", 0)

        let fetch = HttpSourceFetchRunner(config, executor: executor).fetch(SourceRequestBuilder().gitCodeOrgRepos("cangjie"))

        @Expect(fetch.ok, false)
        @Expect(fetch.status, "network_disabled")
        @Expect(fetch.body, "")
        @Expect(executor.calls, 0)
    }

    @TestCase
    public func gitCodeAuthHeadersAreInjectedOnlyForGitCodeAndNeverRenderedInSummary(): Unit {
        let tokenPath = "target/ckb-native-http-test-token.fixture"
        File.writeTo(Path(tokenPath), "native-token-secret\n".toArray())
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.gitCodeAuthMode = "token"
        config.gitCodeAuthHeader = "both"
        config.gitCodeTokenFile = tokenPath
        let gitCodeExecutor = NativeContractSequenceHttpExecutor()
        gitCodeExecutor.add(200, "{}", "application/json", "http_200", 0)
        let docsExecutor = NativeContractSequenceHttpExecutor()
        docsExecutor.add(200, "<html></html>", "text/html", "http_200", 0)
        let builder = SourceRequestBuilder()

        let gitCodeFetch = HttpSourceFetchRunner(config, executor: gitCodeExecutor).fetch(builder.gitCodeRepo("cangjie/stdx"))
        let docsFetch = HttpSourceFetchRunner(config, executor: docsExecutor).fetch(builder.docs("https://docs.cangjie-lang.cn/docs/1.0.0/"))
        let summary = config.redactedSummary()

        @Expect(gitCodeFetch.ok, true)
        @Expect(gitCodeExecutor.seenHeaders.size, 2)
        @Expect(gitCodeExecutor.seenHeaders[0], "PRIVATE-TOKEN: native-token-secret")
        @Expect(gitCodeExecutor.seenHeaders[1], "Authorization: Bearer native-token-secret")
        @Expect(docsFetch.ok, true)
        @Expect(docsExecutor.seenHeaders.size, 0)
        @Expect(summary.contains("gitcode.token=present"), true)
        @Expect(summary.contains("native-token-secret"), false)
        @Expect(summary.contains(tokenPath), false)
    }

    @TestCase
    public func redactionRemovesNativeSecretsCookiesProxyCredentialsAndLocalPaths(): Unit {
        let text = "Authorization: Bearer native-token-secret\nPRIVATE-TOKEN: second-secret\nCookie: SESSION=cookie-secret\nproxy=http://user:proxy-secret@127.0.0.1:7897\nurl=https://api.gitcode.com/api/v5?access_token=query-secret&token=query-token\npath=/Users/l3gi0n/work/private/ckb-live.conf"

        let redacted = redactSensitive(text)

        @Expect(redacted.contains("native-token-secret"), false)
        @Expect(redacted.contains("second-secret"), false)
        @Expect(redacted.contains("cookie-secret"), false)
        @Expect(redacted.contains("proxy-secret"), false)
        @Expect(redacted.contains("query-secret"), false)
        @Expect(redacted.contains("query-token"), false)
        @Expect(redacted.contains("/Users/l3gi0n"), false)
        @Expect(redacted.contains("[local-path-redacted]"), true)
        @Expect(redacted.contains("Authorization"), true)
        @Expect(redacted.contains("Cookie"), true)
    }

    @TestCase
    public func syncLiveWithFakeRunnerKeepsPrivateInternalUnknownReposExcluded(): Unit {
        let kb = newOfflineKnowledgeBase()
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.gitCodeAuthMode = "token"
        config.gitCodeTokenRef = "dry-run-secret"
        let options = LiveSyncOptions()
        options.dryRun = true
        options.maxRepos = 5
        options.maxFilesPerRepo = 2
        options.maxItems = 30

        let text = ckbSyncLive(kb, config, options, runner: NativeContractPublicOnlyRunner(), store: FileKnowledgeStore("target/ckb-native-http-public-only"))

        @Expect(text.contains("repoIncluded cangjie/public-one visibility=public"), true)
        @Expect(text.contains("repoExcluded cangjie/private-one visibility=private"), true)
        @Expect(text.contains("repoExcluded cangjie/internal-one visibility=internal"), true)
        @Expect(text.contains("repoExcluded cangjie/unknown-one visibility=unknown"), true)
        @Expect(text.contains("repo=cangjie/private-one visibility=public"), false)
        @Expect(text.contains("repo=cangjie/internal-one visibility=public"), false)
        @Expect(text.contains("repo=cangjie/unknown-one visibility=public"), false)
        @Expect(text.contains("dry-run-secret"), false)
        @Expect(text.contains("rawWritten=false"), true)
    }

    @TestCase
    public func nativeHttpSmokeUsesAllowlistUrlWithoutCredentialsOrWrites(): Unit {
        let executor = NativeContractSequenceHttpExecutor()
        executor.add(204, "", "text/plain", "http_204", 0)
        let config = CkbNativeHttpTransportConfig("", false, "", false, false, "", 10000)
        let noWritePath = Path("target/ckb-native-smoke-no-write/raw/records.ckb")

        let result = ckbNativeHttpSmokeWithExecutor("https://api.gitcode.com/api/v5/orgs/cangjie/repos?type=public", config, executor)
        let text = ckbNativeHttpRenderSmokeResult(result)

        @Expect(executor.calls, 1)
        @Expect(executor.seenHeaders.size, 0)
        @Expect(result.routeMode, "direct")
        @Expect(result.targetHost, "api.gitcode.com")
        @Expect(result.tlsVerifyMode, "strict")
        @Expect(result.httpStatus, 204)
        @Expect(text.contains("native-http-smoke"), true)
        @Expect(text.contains("route=direct"), true)
        @Expect(text.contains("targetHost=api.gitcode.com"), true)
        @Expect(text.contains("tlsVerifyMode=strict"), true)
        @Expect(text.contains("httpStatus=204"), true)
        @Expect(text.contains("rawWritten=false"), true)
        @Expect(text.contains("candidateWritten=false"), true)
        @Expect(text.contains("activePromoted=false"), true)
        @Expect(exists(noWritePath), false)
    }

    @TestCase
    public func nativeHttpSmokeBlocksIllegalAndPrivateUrlsBeforeExecutor(): Unit {
        let executor = NativeContractSequenceHttpExecutor()
        executor.add(200, "should-not-run", "text/plain", "http_200", 0)
        let config = CkbNativeHttpTransportConfig("", false, "", false, false, "", 10000)

        let fileResult = ckbNativeHttpSmokeWithExecutor("file:///tmp/secret", config, executor)
        let privateResult = ckbNativeHttpSmokeWithExecutor("https://127.0.0.1/secret", config, executor)
        let privateText = ckbNativeHttpRenderSmokeResult(privateResult)

        @Expect(executor.calls, 0)
        @Expect(fileResult.status, "blocked_url")
        @Expect(fileResult.transportClass, "blocked_url")
        @Expect(fileResult.transportDiagnostic.contains("non-http"), true)
        @Expect(privateResult.status, "blocked_url")
        @Expect(privateResult.transportDiagnostic.contains("private-network"), true)
        @Expect(privateText.contains("transportClass=blocked_url"), true)
        @Expect(privateText.contains("httpStatus=0"), true)
    }

    @TestCase
    public func nativeHttpSmokeRedactsProxyAndFailureDiagnostics(): Unit {
        let executor = NativeContractSequenceHttpExecutor()
        executor.addNativeTransportFailure("tls", "TLS failed Authorization: Bearer smoke-token Cookie=session=smoke-cookie proxy=http://user:proxy-secret@127.0.0.1:7897")
        let config = CkbNativeHttpTransportConfig("http://user:proxy-secret@127.0.0.1:7897", false, "", false, false, "", 10000)

        let result = ckbNativeHttpSmokeWithExecutor("https://api.gitcode.com/api/v5/orgs/cangjie/repos?type=public", config, executor)
        let text = ckbNativeHttpRenderSmokeResult(result)

        @Expect(result.routeMode, "httpConnectTunnel")
        @Expect(text.contains("route=httpConnectTunnel"), true)
        @Expect(text.contains("[redacted]@127.0.0.1:7897"), true)
        @Expect(text.contains("smoke-token"), false)
        @Expect(text.contains("smoke-cookie"), false)
        @Expect(text.contains("proxy-secret"), false)
        @Expect(text.contains("transportClass=tls"), true)
    }
}

private func singleStatusExecutor(code: Int64, status: String, retryAfter: Int64): NativeContractSequenceHttpExecutor {
    let executor = NativeContractSequenceHttpExecutor()
    executor.add(code, "{}", "application/json", status, retryAfter)
    executor
}

private class NativeContractHttpStep {
    public var code: Int64 = 0
    public var body: String = ""
    public var contentType: String = ""
    public var status: String = ""
    public var retryAfter: Int64 = 0
    public var transportClass: String = ""
    public var transportDiagnostic: String = ""

    public init() {}
}

private class NativeContractSequenceHttpExecutor <: HttpRequestExecutor {
    private var steps: ArrayList<NativeContractHttpStep> = ArrayList<NativeContractHttpStep>()
    public var calls: Int64 = 0
    public var seenHeaders: ArrayList<String> = ArrayList<String>()

    public init() {}

    public func add(code: Int64, body: String, contentType: String, status: String, retryAfter: Int64): Unit {
        let step = NativeContractHttpStep()
        step.code = code
        step.body = body
        step.contentType = contentType
        step.status = status
        step.retryAfter = retryAfter
        this.steps.add(step)
    }

    public func addNativeTransportFailure(transportClass: String, diagnostic: String): Unit {
        let step = NativeContractHttpStep()
        step.code = 0
        step.status = if (transportClass == "timeout") { "timeout" } else { "transport_error" }
        step.transportClass = transportClass
        step.transportDiagnostic = diagnostic
        this.steps.add(step)
    }

    public func get(request: HttpExecutionRequest): HttpExecutionResponse {
        this.calls += 1
        for (header in request.headers) {
            this.seenHeaders.add(header)
        }
        var index = this.calls - 1
        if (index >= this.steps.size) {
            index = this.steps.size - 1
        }
        let step = this.steps[index]
        let response = HttpExecutionResponse()
        response.statusCode = step.code
        response.body = step.body
        response.contentType = step.contentType
        response.status = step.status
        response.retryAfterSeconds = step.retryAfter
        response.transportErrorClass = step.transportClass
        response.transportDiagnostic = step.transportDiagnostic
        response.curlExitCode = 0
        response
    }
}

private class NativeContractPublicOnlyRunner <: SourceFetchRunner {
    public var calls: ArrayList<SourceFetchRequest> = ArrayList<SourceFetchRequest>()

    public init() {}

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        this.calls.add(request)
        let result = SourceFetchResult()
        result.ok = true
        result.status = "ok"
        result.statusCode = 200
        result.sourceUrl = request.url
        result.normalizedType = request.kind
        result.repo = request.repo
        result.ref = request.ref
        result.path = request.path
        result.repoVisibility = request.repoVisibility
        result.contentType = if (request.accept == "text/html") { "text/html" } else { "application/json" }
        result.body = this.bodyFor(request)
        result.bytes = result.body.size
        result.bodyHash = stableSummaryHash(result.body)
        result.attempts = 1
        result
    }

    private func bodyFor(request: SourceFetchRequest): String {
        if (request.kind == SourceKinds.GITCODE_ORG) {
            if (request.repo == "cangjie") {
                return "[{\"id\":1,\"path\":\"public-one\",\"default_branch\":\"main\",\"public\":true,\"namespace\":{\"path\":\"cangjie\"}},{\"id\":2,\"path\":\"private-one\",\"default_branch\":\"main\",\"private\":true,\"namespace\":{\"path\":\"cangjie\"}},{\"id\":3,\"path\":\"internal-one\",\"default_branch\":\"main\",\"internal\":true,\"namespace\":{\"path\":\"cangjie\"}},{\"id\":4,\"path\":\"unknown-one\",\"default_branch\":\"main\",\"namespace\":{\"path\":\"cangjie\"}}]"
            }
            return "[]"
        }
        if (request.kind == SourceKinds.GITCODE_TREE) {
            return "{\"tree\":[{\"type\":\"blob\",\"path\":\"src/main.cj\"},{\"type\":\"blob\",\"path\":\"README.md\"}]}"
        }
        if (request.kind == SourceKinds.GITCODE_SOURCE) {
            return "public func publicOne(): Unit { println(\"public\") }"
        }
        if (request.kind == SourceKinds.GITCODE_ISSUE_HISTORY) {
            return "[{\"number\":\"1\",\"title\":\"issue\"}]"
        }
        if (request.kind == SourceKinds.GITCODE_PR_HISTORY) {
            return "[{\"number\":\"2\",\"title\":\"pr\"}]"
        }
        if (request.kind == SourceKinds.GITCODE_COMMENT_HISTORY) {
            return "[{\"id\":3,\"body\":\"comment\"}]"
        }
        if (request.kind == SourceKinds.CANGJIE_WEBSITE || request.kind == SourceKinds.CANGJIE_DOCS) {
            return "<html>Cangjie</html>"
        }
        "fixture body"
    }
}
