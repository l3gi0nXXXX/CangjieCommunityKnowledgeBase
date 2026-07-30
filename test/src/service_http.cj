package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.convert.Parsable
import std.fs.{File, Path, canonicalize, exists}
import std.time.*
import stdx.net.http.*

public class CkbHttpServiceConfig {
    public var bind: String = "127.0.0.1"
    public var port: Int64 = 18890
    public var adminTokenFile: String = ""
    public var eventIngestTokenFile: String = ""
    public var maxRequestBytes: Int64 = 1048576
    public var readOnlyPublic: Bool = true
    public var defaultBudget: Int64 = 5
    public var maxBudget: Int64 = 20

    public init() {}
}

public class CkbHttpAuthorizationResult {
    public var authorized: Bool = false
    public var authKind: String = ""
    public var code: String = "ckb.unauthorized"
    public var statusCode: Int64 = 401
    public var diagnostic: String = ""

    public init() {}
}

public class CkbHttpBodyReadResult {
    public var ok: Bool = true
    public var body: String = ""
    public var code: String = "ok"
    public var statusCode: Int64 = 200

    public init() {}
}

public class CkbHttpHandlerResponse {
    public var statusCode: Int64 = 200
    public var body: String = ""
    public var authKind: String = "public"

    public init() {}
}

public class CkbHttpConfigValidationResult {
    public var ok: Bool = true
    public var code: String = "ok"
    public var diagnostic: String = "ok"

    public init() {}
}

public func ckbHttpServiceConfigFromRuntime(runtime: CkbRuntimeConfig): CkbHttpServiceConfig {
    let config = CkbHttpServiceConfig()
    config.bind = runtime.serviceBind
    config.port = runtime.servicePort
    config.adminTokenFile = runtime.serviceAdminTokenFile
    config.eventIngestTokenFile = runtime.serviceEventIngestTokenFile
    config.maxRequestBytes = runtime.serviceMaxRequestBytes
    config.readOnlyPublic = runtime.serviceReadOnlyPublic
    config.defaultBudget = runtime.serviceDefaultBudget
    config.maxBudget = runtime.serviceMaxBudget
    config
}

public func runCkbHttpService(runtime: CkbRuntimeConfig, store: FileKnowledgeStore,
    loadedKnowledgeBase!: ?KnowledgeBase = None): Int64 {
    let config = ckbHttpServiceConfigFromRuntime(runtime)
    let validation = ckbHttpValidateConfig(config)
    if (!validation.ok) {
        println(ckbApiErrorEnvelope(validation.code, "invalid http service configuration", status: 400, diagnostics: "{\"reason\":\"${validation.diagnostic}\"}"))
        return 2
    }
    let service = CkbCommandLoopService(runtime, store,
        sourceRunner: if (runtime.networkEnabled) { HttpSourceFetchRunner(runtime) } else { DisabledNetworkFetchRunner() },
        loadedKnowledgeBase: loadedKnowledgeBase)
    print(service.start())
    try {
        let server = ServerBuilder()
            .addr(config.bind)
            .port(UInt16(config.port))
            .build()
        let mcpSessionStore = CkbMcpHttpSessionStore()
        registerCkbHttpRoutes(server, service, config, mcpSessionStore: mcpSessionStore)
        println("service-http protocol=ckb-http-v1 bind=${redactSensitive(config.bind)} port=${config.port}")
        _ = startCkbSchedulerLoop(service, runtime, afterHttpReady: true, deferFirstTick: true)
        server.serve()
        return 0
    } catch (e: Exception) {
        println(ckbApiErrorEnvelope("ckb.http_service_failed", "http service failed", status: 500, diagnostics: "{\"reason\":\"${ckbHttpJsonEscape(redactSensitive(e.message))}\"}"))
        return 2
    }
}

// Certification exposes only the immutable knowledge-serving surface.  It
// deliberately does not start the command service or scheduler because both
// can recover or create durable state.
public func runCkbCertificationHttpService(runtime: CkbRuntimeConfig, store: FileKnowledgeStore): Int64 {
    let config = ckbHttpServiceConfigFromRuntime(runtime)
    if(ckbCertificationHttpBindDiagnostic(config.bind)!="ok"){println(ckbApiErrorEnvelope("ckb.certification_loopback_required","certification http bind must be loopback",status:400));return 2}
    let validation = ckbHttpValidateConfig(config)
    if (!validation.ok) {
        println(ckbApiErrorEnvelope(validation.code, "invalid http service configuration", status: 400, diagnostics: "{\"reason\":\"${validation.diagnostic}\"}"))
        return 2
    }
    let service = CkbCommandLoopService(runtime, store, sourceRunner: DisabledNetworkFetchRunner())
    let identity = prepareCkbCertificationHttpIdentity(service, store)
    if (!identity.valid) {
        println(ckbApiErrorEnvelope("ckb.certification_identity_unavailable",
            "certification identity unavailable", status: 409))
        return 2
    }
    try {
        let server = ServerBuilder().addr(config.bind).port(UInt16(config.port)).build()
        registerCkbCertificationHttpRoutes(server, service, store, config, identity: identity)
        println("certification-http protocol=ckb-certification-http-v1 bind=${redactSensitive(config.bind)} port=${config.port}")
        server.serve()
        return 0
    } catch (_: Exception) {
        println(ckbApiErrorEnvelope("ckb.certification_http_service_failed", "certification http service failed", status: 500))
        return 2
    }
}
public func ckbCertificationHttpBindDiagnostic(bind:String):String{let value=bind.trimAscii().toAsciiLower();if(value=="127.0.0.1"||value=="localhost"||value=="::1"){"ok"}else{"certification_http_loopback_required"}}

public func registerCkbCertificationHttpRoutes(server: Server, service: CkbCommandLoopService,
    store: FileKnowledgeStore, config: CkbHttpServiceConfig,
    mcpSessionStore!: CkbMcpHttpSessionStore = CkbMcpHttpSessionStore(),
    identity!: CkbCertificationHttpIdentity = prepareCkbCertificationHttpIdentity(service, store)): Unit {
    server.distributor.register("/v1/certification/identity", { ctx =>
        ckbCertificationHttpServeIdentity(ctx, identity, store, config)
    })
    ckbMcpHttpRegisterRoute(server, service, config, mcpSessionStore, "/mcp")
}

public class CkbCertificationHttpIdentity {
    public var valid: Bool = false
    public var diagnostic: String = "certification_identity_unavailable"
    public var activeVersion: String = ""
    public var pointerIdentityHash: String = ""
    public var candidateChecksum: String = ""
    public var responseBody: String = ""
    public init() {}
}

public func prepareCkbCertificationHttpIdentity(service: CkbCommandLoopService,
    store: FileKnowledgeStore): CkbCertificationHttpIdentity {
    let identity = CkbCertificationHttpIdentity()
    let first = store.loadActiveSnapshotPointer()
    if (!first.valid) { return identity }
    let requestedStoreRootHash = try {
        benchmarkGapSha256(canonicalize(store.root).toString())
    } catch (_: Exception) { "" }
    if (requestedStoreRootHash == "" ||
        requestedStoreRootHash != service.certificationStoreRootIdentityHash()) {
        identity.diagnostic = "certification_identity_service_store_mismatch"
        return identity
    }
    let projection = service.prepareStudentServingProjection()
    if (!projection.valid) {
        identity.diagnostic = projection.diagnostic
        return identity
    }
    let version = service.certificationActiveKnowledgeVersion()
    let checksum = service.certificationActiveRecordsChecksum()
    let servicePointerHash = service.certificationStorePointerIdentityHash()
    let second = store.loadActiveSnapshotPointer()
    let pointerHash = ckbActiveSnapshotPointerIdentityHash(first)
    if (!second.valid || ckbActiveSnapshotPointerIdentityHash(second) != pointerHash ||
        servicePointerHash != pointerHash || version != first.activeVersion ||
        projection.activeKnowledgeVersion != version) {
        identity.diagnostic = "certification_identity_service_store_mismatch"
        return identity
    }
    identity.activeVersion = version
    identity.pointerIdentityHash = pointerHash
    identity.candidateChecksum = checksum
    identity.responseBody = ckbApiEnvelope(
        "{\"schemaVersion\":\"ckb-certification-identity-v1\",\"activeVersion\":\"${ckbHttpJsonEscape(version)}\",\"pointerIdentityHash\":\"${pointerHash}\",\"candidateChecksum\":\"${checksum}\"}")
    identity.valid = true
    identity.diagnostic = "ok"
    identity
}

public func handleCkbCertificationHttpRequest(service: CkbCommandLoopService,
    store: FileKnowledgeStore, method: String, path: String, body: String,
    headers: Array<String>, config: CkbHttpServiceConfig): CkbHttpHandlerResponse {
    handlePreparedCkbCertificationHttpRequest(
        prepareCkbCertificationHttpIdentity(service, store), store,
        method, path, body, headers, config)
}

public func handlePreparedCkbCertificationHttpRequest(identity: CkbCertificationHttpIdentity,
    store: FileKnowledgeStore, method: String, path: String, body: String,
    headers: Array<String>, config: CkbHttpServiceConfig): CkbHttpHandlerResponse {
    let response = CkbHttpHandlerResponse()
    let cleanMethod = method.trimAscii().toAsciiUpper()
    let cleanPath = path.trimAscii()
    if (cleanPath != "/v1/certification/identity") {
        response.statusCode = 404
        response.body = ckbApiErrorEnvelope("ckb.not_found", "route not found", status: 404)
        return response
    }
    if (cleanMethod != "GET") {
        response.statusCode = 405
        response.body = ckbApiErrorEnvelope("ckb.method_not_allowed", "method not allowed", status: 405)
        return response
    }
    if (body.trimAscii() != "") {
        response.statusCode = 400
        response.body = ckbApiErrorEnvelope("ckb.bad_request", "identity request body must be empty", status: 400)
        return response
    }
    let auth = ckbHttpAuthorize(config, headers, "read")
    if (!auth.authorized) {
        response.statusCode = auth.statusCode
        response.authKind = auth.authKind
        response.body = ckbApiErrorEnvelope(auth.code, ckbHttpAuthMessage(auth.code), status: auth.statusCode)
        return response
    }
    response.authKind = auth.authKind
    if (!identity.valid) {
        response.statusCode = 409
        response.body = ckbApiErrorEnvelope("ckb.certification_identity_unavailable", "certification identity unavailable", status: 409)
        return response
    }
    let pointer = store.loadActiveSnapshotPointer()
    if (!pointer.valid ||
        ckbActiveSnapshotPointerIdentityHash(pointer) != identity.pointerIdentityHash) {
        response.statusCode = 409
        response.body = ckbApiErrorEnvelope("ckb.certification_identity_drift", "certification identity drift", status: 409)
        return response
    }
    response.body = identity.responseBody
    response.statusCode = 200
    response
}

public func registerCkbHttpRoutes(server: Server, service: CkbCommandLoopService, config: CkbHttpServiceConfig, mcpSessionStore!: CkbMcpHttpSessionStore = CkbMcpHttpSessionStore()): Unit {
    ckbHttpRegisterRoute(server, service, config, "/v1/health")
    ckbHttpRegisterRoute(server, service, config, "/v1/status")
    ckbHttpRegisterRoute(server, service, config, "/v1/schedules")
    ckbHttpRegisterRoute(server, service, config, "/v1/schema")
    ckbHttpRegisterRoute(server, service, config, "/v1/cangjie/corpus/status")
    ckbHttpRegisterRoute(server, service, config, "/v1/cangjie/llms.txt")
    ckbHttpRegisterRoute(server, service, config, "/v1/cangjie/llms-full.txt")
    ckbHttpRegisterRoute(server, service, config, "/v1/cangjie/knowledge-pack")
    ckbHttpRegisterRoute(server, service, config, "/v1/cangjie/syntax-query")
    ckbHttpRegisterRoute(server, service, config, "/v1/cangjie/api-search")
    ckbHttpRegisterRoute(server, service, config, "/v1/cangjie/cookbook")
    ckbHttpRegisterRoute(server, service, config, "/v1/cangjie/diagnose")
    ckbHttpRegisterRoute(server, service, config, "/v1/cangjie/examples")
    ckbHttpRegisterRoute(server, service, config, "/v1/cangjie/context-pack")
    ckbHttpRegisterRoute(server, service, config, "/v1/cangjie/version/resolve")
    ckbHttpRegisterRoute(server, service, config, "/v1/cangjie/task-knowledge-pack")
    ckbHttpRegisterRoute(server, service, config, "/v1/cangjie/knowledge-coverage")
    ckbHttpRegisterRoute(server, service, config, "/v1/cangjie/compile-diagnose-v2")
    ckbHttpRegisterRoute(server, service, config, "/v1/cangjie/symbol-lookup")
    ckbHttpRegisterRoute(server, service, config, "/v1/cangjie/doc-section")
    ckbHttpRegisterRoute(server, service, config, "/v1/cangjie/tool-manual")
    ckbHttpRegisterRoute(server, service, config, "/v1/cangjie/negative-rules")
    ckbHttpRegisterRoute(server, service, config, "/v1/cangjie/corpus/freshness")
    ckbHttpRegisterRoute(server, service, config, "/v1/query")
    ckbHttpRegisterRoute(server, service, config, "/v1/evidence-pack")
    ckbHttpRegisterRoute(server, service, config, "/v1/source-analysis")
    ckbHttpRegisterRoute(server, service, config, "/v1/events/gitcode/repository-changed")
    ckbHttpRegisterRoute(server, service, config, "/v1/admin/sync")
    ckbHttpRegisterRoute(server, service, config, "/v1/admin/rebuild")
    ckbHttpRegisterRoute(server, service, config, "/v1/admin/vector/bootstrap")
    ckbHttpRegisterRoute(server, service, config, "/v1/admin/vector/clean-derived")
    ckbHttpRegisterRoute(server, service, config, "/v1/admin/vector/reconcile")
    ckbHttpRegisterRoute(server, service, config, "/v1/admin/restart")
    ckbHttpRegisterRoute(server, service, config, "/v1/admin/backup")
    ckbHttpRegisterRoute(server, service, config, "/v1/admin/restore")
    ckbHttpRegisterRoute(server, service, config, "/v1/admin/scheduler/run")
    ckbHttpRegisterRoute(server, service, config, "/v1/admin/repositories/sync")
    ckbHttpRegisterRoute(server, service, config, "/v1/admin/repo-list/refresh")
    ckbHttpRegisterRoute(server, service, config, "/v1/admin/initialize")
    ckbHttpRegisterRoute(server, service, config, "/v1/admin/cangjie/landing-status")
    ckbMcpHttpRegisterRoute(server, service, config, mcpSessionStore, "/mcp")
}

public func handleCkbHttpRequest(
    service: CkbCommandLoopService,
    method: String,
    path: String,
    body: String,
    headers: Array<String>,
    config: CkbHttpServiceConfig
): CkbHttpHandlerResponse {
    let response = CkbHttpHandlerResponse()
    let cleanMethod = method.trimAscii().toAsciiUpper()
    let cleanPath = path.trimAscii()
    let maxBytes = if (config.maxRequestBytes <= 0) { 1048576 } else { config.maxRequestBytes }
    if (Int64(body.size) > maxBytes) {
        response.statusCode = 413
        response.body = ckbApiErrorEnvelope("ckb.payload_too_large", "request body exceeds service.maxRequestBytes", status: 413)
        return response
    }

    let requiredAuth = ckbHttpRequiredAuthKind(cleanPath)
    let auth = ckbHttpAuthorize(config, headers, requiredAuth)
    if (!auth.authorized) {
        response.statusCode = auth.statusCode
        response.authKind = auth.authKind
        response.body = ckbApiErrorEnvelope(auth.code, ckbHttpAuthMessage(auth.code), status: auth.statusCode, diagnostics: "{\"reason\":\"${ckbHttpJsonEscape(auth.diagnostic)}\"}")
        return response
    }
    response.authKind = auth.authKind

    let apiHeaders = ArrayList<String>()
    if (auth.authKind == "admin") {
        apiHeaders.add("X-CKB-Admin-Token: authorized")
    }
    response.body = ckbApiHandle(service, cleanMethod, cleanPath, body, apiHeaders.toArray())
    response.statusCode = ckbHttpStatusFromApiBody(cleanPath, response.body)
    response
}

public func ckbHttpAuthorize(config: CkbHttpServiceConfig, headers: Array<String>, authKind: String): CkbHttpAuthorizationResult {
    let requested = authKind.trimAscii().toAsciiLower()
    if (requested == "" || requested == "none" || requested == "public") {
        return ckbHttpAuthorized("public")
    }
    if (requested == "read") {
        let eventToken = ckbHttpCredential(config.eventIngestTokenFile)
        let supplied = ckbHttpSuppliedToken(headers)
        if (eventToken != "" && supplied == eventToken) {
            return ckbHttpDenied("event", "ckb.forbidden", 403, "event_token_not_allowed_for_read_api")
        }
        if (config.readOnlyPublic) {
            return ckbHttpAuthorized("public")
        }
        return ckbHttpAuthorize(config, headers, "admin")
    }
    if (requested == "admin") {
        let adminToken = ckbHttpCredential(config.adminTokenFile)
        let eventToken = ckbHttpCredential(config.eventIngestTokenFile)
        let supplied = ckbHttpAdminSuppliedToken(headers)
        if (adminToken == "") {
            return ckbHttpDenied("admin", "ckb.unauthorized", 401, "admin_token_not_configured")
        }
        if (supplied == adminToken) {
            return ckbHttpAuthorized("admin")
        }
        if (eventToken != "" && supplied == eventToken) {
            return ckbHttpDenied("event", "ckb.forbidden", 403, "event_token_not_allowed_for_admin_api")
        }
        return ckbHttpDenied("admin", "ckb.unauthorized", 401, "admin_authorization_failed")
    }
    if (requested == "event") {
        let eventToken = ckbHttpCredential(config.eventIngestTokenFile)
        let adminToken = ckbHttpCredential(config.adminTokenFile)
        let supplied = ckbHttpEventSuppliedToken(headers)
        if (eventToken == "") {
            return ckbHttpDenied("event", "ckb.unauthorized", 401, "event_token_not_configured")
        }
        if (supplied == eventToken) {
            return ckbHttpAuthorized("event")
        }
        if (adminToken != "" && supplied == adminToken) {
            return ckbHttpDenied("admin", "ckb.forbidden", 403, "admin_token_not_allowed_for_event_api")
        }
        return ckbHttpDenied("event", "ckb.unauthorized", 401, "event_authorization_failed")
    }
    ckbHttpDenied(requested, "ckb.unauthorized", 401, "unsupported_auth_kind")
}

public func ckbHttpReadBody(ctx: HttpContext, maxBytes: Int64): CkbHttpBodyReadResult {
    let result = CkbHttpBodyReadResult()
    try {
        let declaredText = ctx.request.headers.getFirst("Content-Length") ?? ctx.request.headers.getFirst("content-length") ?? ""
        if (declaredText.trimAscii() != "") {
            let declared = try { Int64.parse(declaredText.trimAscii()) } catch (_: Exception) {
                result.ok = false
                result.code = "ckb.bad_request"
                result.statusCode = 400
                return result
            }
            if (maxBytes > 0 && declared > maxBytes) {
                result.ok = false
                result.code = "ckb.payload_too_large"
                result.statusCode = 413
                return result
            }
        }
        let bytes = ArrayList<Byte>()
        let buffer = Array<Byte>(8192, repeat: 0)
        while (true) {
            let n = ctx.request.body.read(buffer)
            if (n <= 0) {
                break
            }
            if (maxBytes > 0 && Int64(bytes.size) + Int64(n) > maxBytes) {
                result.ok = false
                result.code = "ckb.payload_too_large"
                result.statusCode = 413
                return result
            }
            bytes.add(all: buffer[..n])
        }
        result.body = String.fromUtf8(bytes.toArray())
        result
    } catch (_: Exception) {
        result.ok = false
        result.code = "ckb.bad_request"
        result.statusCode = 400
        result
    }
}

public func ckbHttpValidateConfig(config: CkbHttpServiceConfig): CkbHttpConfigValidationResult {
    let result = CkbHttpConfigValidationResult()
    if (config.port < 1 || config.port > 65535) {
        result.ok = false
        result.code = "ckb.invalid_config"
        result.diagnostic = "invalid_service_port port=${config.port}"
        return result
    }
    if (config.bind.trimAscii() == "") {
        result.ok = false
        result.code = "ckb.invalid_config"
        result.diagnostic = "invalid_service_bind"
        return result
    }
    if (config.maxRequestBytes <= 0) {
        result.ok = false
        result.code = "ckb.invalid_config"
        result.diagnostic = "invalid_service_max_request_bytes"
        return result
    }
    result
}

private func ckbHttpRegisterRoute(server: Server, service: CkbCommandLoopService, config: CkbHttpServiceConfig, path: String): Unit {
    server.distributor.register(path, { ctx =>
        ckbHttpServeContext(ctx, service, path, config)
    })
}

private func ckbMcpHttpRegisterRoute(server: Server, service: CkbCommandLoopService, config: CkbHttpServiceConfig, sessionStore: CkbMcpHttpSessionStore, path: String): Unit {
    server.distributor.register(path, { ctx =>
        ckbMcpHttpServeContext(ctx, service, path, config, sessionStore)
    })
}

private func ckbCertificationHttpServeIdentity(ctx: HttpContext, identity: CkbCertificationHttpIdentity,
    store: FileKnowledgeStore, config: CkbHttpServiceConfig): Unit {
    let startMs = ckbHttpNowMillis()
    let rb = ctx.responseBuilder
    rb.header("content-type", "application/json; charset=utf-8")
    let bodyRead = ckbHttpReadBody(ctx, config.maxRequestBytes)
    if (!bodyRead.ok) {
        rb.status(UInt16(bodyRead.statusCode))
        rb.body(ckbApiErrorEnvelope(bodyRead.code, "invalid request body", status: bodyRead.statusCode))
        return
    }
    let response = handlePreparedCkbCertificationHttpRequest(identity, store, ctx.request.method,
        "/v1/certification/identity", bodyRead.body, ckbHttpRequestHeaders(ctx), config)
    rb.status(UInt16(response.statusCode))
    rb.body(response.body)
    ckbHttpAccessLog(ctx.request.method, "/v1/certification/identity", response.statusCode,
        response.authKind, Int64(bodyRead.body.toArray().size), ckbHttpNowMillis() - startMs)
}

private func ckbHttpServeContext(ctx: HttpContext, service: CkbCommandLoopService, path: String, config: CkbHttpServiceConfig): Unit {
    let startMs = ckbHttpNowMillis()
    let rb = ctx.responseBuilder
    rb.header("content-type", "application/json; charset=utf-8")
    let bodyRead = ckbHttpReadBody(ctx, config.maxRequestBytes)
    if (!bodyRead.ok) {
        rb.status(UInt16(bodyRead.statusCode))
        rb.body(ckbApiErrorEnvelope(bodyRead.code, if (bodyRead.code == "ckb.payload_too_large") { "request body exceeds service.maxRequestBytes" } else { "request body is invalid" }, status: bodyRead.statusCode))
        ckbHttpAccessLog(ctx.request.method, path, bodyRead.statusCode, "unavailable", 0, ckbHttpNowMillis() - startMs)
        return
    }
    let response = handleCkbHttpRequest(service, ctx.request.method, path, bodyRead.body, ckbHttpRequestHeaders(ctx), config)
    rb.status(UInt16(response.statusCode))
    rb.body(response.body)
    ckbHttpAccessLog(ctx.request.method, path, response.statusCode, response.authKind, Int64(bodyRead.body.toArray().size), ckbHttpNowMillis() - startMs)
}

private func ckbMcpHttpServeContext(ctx: HttpContext, service: CkbCommandLoopService, path: String, config: CkbHttpServiceConfig, sessionStore: CkbMcpHttpSessionStore): Unit {
    let startMs = ckbHttpNowMillis()
    let rb = ctx.responseBuilder
    let bodyRead = ckbHttpReadBody(ctx, config.maxRequestBytes)
    if (!bodyRead.ok) {
        rb.header("content-type", "application/json; charset=utf-8")
        rb.status(UInt16(bodyRead.statusCode))
        rb.body("{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32600,\"message\":\"${if (bodyRead.code == "ckb.payload_too_large") { "request_too_large" } else { "bad_request" }}\",\"data\":{}}}")
        ckbHttpAccessLog(ctx.request.method, path, bodyRead.statusCode, "unavailable", 0, ckbHttpNowMillis() - startMs)
        return
    }
    let response = handleCkbMcpHttpRequest(service, ctx.request.method, path, bodyRead.body, ckbHttpRequestHeaders(ctx), config, CkbMcpHttpServiceConfig(), sessionStore)
    rb.status(UInt16(response.statusCode))
    for (header in response.headers) {
        ckbMcpHttpApplyHeader(rb, header)
    }
    if (response.streamMode) {
        rb.header("content-type", response.contentType)
        rb.header("cache-control", "no-cache")
        rb.header("connection", "keep-alive")
        rb.header("transfer-encoding", "chunked")
        let writer = HttpResponseWriter(ctx)
        try {
            writer.write(response.body.toArray())
            while (true) {
                sleep(Duration.second * 15)
                writer.write(": ckb-mcp-keepalive\n\n".toArray())
            }
        } catch (_: Exception) {
            ckbHttpAccessLog(ctx.request.method, path, response.statusCode, response.authKind, Int64(bodyRead.body.toArray().size), ckbHttpNowMillis() - startMs)
            return
        }
    } else {
        rb.header("content-type", response.contentType)
        rb.body(response.body)
    }
    ckbHttpAccessLog(ctx.request.method, path, response.statusCode, response.authKind, Int64(bodyRead.body.toArray().size), ckbHttpNowMillis() - startMs)
}

private func ckbMcpHttpApplyHeader(rb: HttpResponseBuilder, header: String): Unit {
    match (header.indexOf(":")) {
        case Some(idx) =>
            let name = header[0..idx].trimAscii()
            let value = header[idx + 1..header.size].trimAscii()
            if (name != "") {
                rb.header(name, value)
            }
        case None =>
            ()
    }
}

public func ckbHttpAccessLogLine(method: String, path: String, statusCode: Int64, authKind: String, requestBytes: Int64, durationMs: Int64): String {
    "ckb.http.request method=${method.trimAscii().toAsciiUpper()} path=${path.trimAscii()} status=${statusCode} durationMs=${durationMs} authKind=${authKind.trimAscii()} requestBytes=${requestBytes}"
}

private func ckbHttpAccessLog(method: String, path: String, statusCode: Int64, authKind: String, requestBytes: Int64, durationMs: Int64): Unit {
    println(ckbHttpAccessLogLine(method, path, statusCode, authKind, requestBytes, durationMs))
}

private func ckbHttpNowMillis(): Int64 {
    DateTime.now().toUnixTimeStamp().toMilliseconds()
}

private func ckbHttpRequiredAuthKind(path: String): String {
    if (path.startsWith("/v1/admin/")) {
        return "admin"
    }
    if (path == "/v1/events/gitcode/repository-changed") {
        return "event"
    }
    if (path.startsWith("/v1/cangjie/")) {
        return "read"
    }
    if (path == "/v1/query" || path == "/v1/evidence-pack" || path == "/v1/source-analysis") {
        return "read"
    }
    "public"
}

private func ckbHttpStatusFromApiBody(path: String, body: String): Int64 {
    if (body.trimAscii().startsWith("{\"ok\":false")) {
        if (body.contains("\"code\":\"ckb.unauthorized\"")) { return 401 }
        if (body.contains("\"code\":\"ckb.forbidden\"")) { return 403 }
        if (body.contains("\"code\":\"ckb.not_found\"")) { return 404 }
        if (body.contains("\"code\":\"ckb.method_not_allowed\"")) { return 405 }
        if (body.contains("\"status\":409")) { return 409 }
        if (body.contains("\"status\":413")) { return 413 }
        if (body.contains("\"status\":500")) { return 500 }
        return 400
    }
    if (path == "/v1/events/gitcode/repository-changed" && body.contains("\"status\":\"accepted\"")) {
        return 202
    }
    200
}

private func ckbHttpAuthorized(kind: String): CkbHttpAuthorizationResult {
    let result = CkbHttpAuthorizationResult()
    result.authorized = true
    result.authKind = kind
    result.code = "ok"
    result.statusCode = 200
    result.diagnostic = "ok"
    result
}

private func ckbHttpDenied(kind: String, code: String, statusCode: Int64, diagnostic: String): CkbHttpAuthorizationResult {
    let result = CkbHttpAuthorizationResult()
    result.authorized = false
    result.authKind = kind
    result.code = code
    result.statusCode = statusCode
    result.diagnostic = diagnostic
    result
}

private func ckbHttpAuthMessage(code: String): String {
    if (code == "ckb.forbidden") {
        return "token is not allowed for this API"
    }
    "authorization required"
}

private func ckbHttpRequestHeaders(ctx: HttpContext): Array<String> {
    let headers = ArrayList<String>()
    ckbHttpAppendHeader(headers, "Authorization", ctx.request.headers.getFirst("Authorization") ?? ctx.request.headers.getFirst("authorization") ?? "")
    ckbHttpAppendHeader(headers, "X-CKB-Admin-Token", ctx.request.headers.getFirst("X-CKB-Admin-Token") ?? ctx.request.headers.getFirst("x-ckb-admin-token") ?? "")
    ckbHttpAppendHeader(headers, "X-CKB-Event-Token", ctx.request.headers.getFirst("X-CKB-Event-Token") ?? ctx.request.headers.getFirst("x-ckb-event-token") ?? "")
    ckbHttpAppendHeader(headers, "Accept", ctx.request.headers.getFirst("Accept") ?? ctx.request.headers.getFirst("accept") ?? "")
    ckbHttpAppendHeader(headers, "Content-Type", ctx.request.headers.getFirst("Content-Type") ?? ctx.request.headers.getFirst("content-type") ?? "")
    ckbHttpAppendHeader(headers, "MCP-Protocol-Version", ctx.request.headers.getFirst("MCP-Protocol-Version") ?? ctx.request.headers.getFirst("mcp-protocol-version") ?? "")
    ckbHttpAppendHeader(headers, "Mcp-Session-Id", ctx.request.headers.getFirst("Mcp-Session-Id") ?? ctx.request.headers.getFirst("mcp-session-id") ?? "")
    ckbHttpAppendHeader(headers, "Last-Event-ID", ctx.request.headers.getFirst("Last-Event-ID") ?? ctx.request.headers.getFirst("last-event-id") ?? "")
    ckbHttpAppendAllHeaderValues(headers, ctx.request.headers, "X-CKB-Runner-Context")
    ckbHttpAppendAllHeaderValues(headers, ctx.request.headers, "X-CKB-Runner-Context-SHA256")
    headers.toArray()
}

private func ckbHttpAppendAllHeaderValues(headers: ArrayList<String>, requestHeaders: HttpHeaders, name: String): Unit {
    for (value in requestHeaders.get(name)) { ckbHttpAppendHeader(headers, name, value) }
}

public func ckbHttpRunnerBindingHeadersForTest(requestHeaders: HttpHeaders): Array<String> {
    let headers = ArrayList<String>()
    ckbHttpAppendAllHeaderValues(headers, requestHeaders, "X-CKB-Runner-Context")
    ckbHttpAppendAllHeaderValues(headers, requestHeaders, "X-CKB-Runner-Context-SHA256")
    headers.toArray()
}

private func ckbHttpAppendHeader(headers: ArrayList<String>, name: String, value: String): Unit {
    if (value.trimAscii() != "") {
        headers.add("${name}: ${value.trimAscii()}")
    }
}

private func ckbHttpCredential(path: String): String {
    if (path.trimAscii() == "" || !exists(Path(path))) {
        return ""
    }
    try {
        for (line in String.fromUtf8(File.readFrom(Path(path))).split("\n")) {
            let trimmed = line.trimAscii()
            if (trimmed != "") {
                return trimmed
            }
        }
    } catch (_: Exception) {
        return ""
    }
    ""
}

private func ckbHttpAdminSuppliedToken(headers: Array<String>): String {
    let direct = ckbHttpHeaderValue(headers, "X-CKB-Admin-Token")
    if (direct != "") { return direct }
    ckbHttpBearerToken(headers)
}

private func ckbHttpEventSuppliedToken(headers: Array<String>): String {
    let direct = ckbHttpHeaderValue(headers, "X-CKB-Event-Token")
    if (direct != "") { return direct }
    ckbHttpBearerToken(headers)
}

private func ckbHttpSuppliedToken(headers: Array<String>): String {
    let bearer = ckbHttpBearerToken(headers)
    if (bearer != "") { return bearer }
    let admin = ckbHttpHeaderValue(headers, "X-CKB-Admin-Token")
    if (admin != "") { return admin }
    ckbHttpHeaderValue(headers, "X-CKB-Event-Token")
}

private func ckbHttpBearerToken(headers: Array<String>): String {
    let value = ckbHttpHeaderValue(headers, "Authorization")
    let lower = value.toAsciiLower()
    if (lower.startsWith("bearer ")) {
        return value[7..value.size].trimAscii()
    }
    ""
}

private func ckbHttpHeaderValue(headers: Array<String>, name: String): String {
    let prefix = name.toAsciiLower() + ":"
    for (header in headers) {
        let cleaned = header.trimAscii()
        if (cleaned.toAsciiLower().startsWith(prefix)) {
            return cleaned[prefix.size..cleaned.size].trimAscii()
        }
    }
    ""
}

private func ckbHttpJsonEscape(raw: String): String {
    raw.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r")
}
