package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.time.DateTime

public class CkbMcpHttpServiceConfig {
    public var path: String = "/mcp"
    public var protocolVersion: String = "2025-06-18"
    public var requireSession: Bool = true
    public var sessionTtlMillis: Int64 = 3600000
    public var strictAccept: Bool = true

    public init() {}
}

public class CkbMcpHttpResponse {
    public var statusCode: Int64 = 200
    public var contentType: String = "application/json; charset=utf-8"
    public var headers: ArrayList<String> = ArrayList<String>()
    public var body: String = ""
    public var authKind: String = "public"
    public var streamMode: Bool = false

    public init() {}
}

public class CkbMcpHttpSession {
    public var sessionId: String = ""
    public var protocolVersion: String = ""
    public var initialized: Bool = false
    public var createdAtMillis: Int64 = 0
    public var lastSeenMillis: Int64 = 0
    public var clientName: String = ""
    public var lastEventId: String = ""
    public var sseConnected: Bool = false

    public init() {}
}

public class CkbMcpHttpSessionStore {
    private let sessions: ArrayList<CkbMcpHttpSession> = ArrayList<CkbMcpHttpSession>()
    private var nextSequence: Int64 = 1

    public init() {}

    public func create(protocolVersion: String, clientName: String): CkbMcpHttpSession {
        let now = ckbMcpHttpNowMillis()
        let session = CkbMcpHttpSession()
        session.sessionId = "ckb-mcp-${now}-${this.nextSequence}"
        this.nextSequence += 1
        session.protocolVersion = protocolVersion
        session.clientName = clientName
        session.createdAtMillis = now
        session.lastSeenMillis = now
        this.sessions.add(session)
        session
    }

    public func get(sessionId: String): ?CkbMcpHttpSession {
        let clean = sessionId.trimAscii()
        for (session in this.sessions) {
            if (session.sessionId == clean) {
                session.lastSeenMillis = ckbMcpHttpNowMillis()
                return Some<CkbMcpHttpSession>(session)
            }
        }
        None<CkbMcpHttpSession>
    }

    public func markInitialized(sessionId: String): Bool {
        if (let Some(session) <- this.get(sessionId)) {
            session.initialized = true
            return true
        }
        false
    }

    public func markSseConnected(sessionId: String): Bool {
        if (let Some(session) <- this.get(sessionId)) {
            session.sseConnected = true
            return true
        }
        false
    }

    public func recordLastEventId(sessionId: String, value: String): Bool {
        if (let Some(session) <- this.get(sessionId)) {
            session.lastEventId = redactSensitive(value.trimAscii())
            return true
        }
        false
    }

    public func delete(sessionId: String): Bool {
        let clean = sessionId.trimAscii()
        for (idx in 0..this.sessions.size) {
            if (this.sessions[idx].sessionId == clean) {
                this.sessions.remove(at: idx)
                return true
            }
        }
        false
    }

    public func expire(nowMillis: Int64, ttlMillis: Int64): Unit {
        var idx: Int64 = this.sessions.size - 1
        while (idx >= 0) {
            if (ttlMillis > 0 && nowMillis - this.sessions[idx].lastSeenMillis > ttlMillis) {
                this.sessions.remove(at: idx)
            }
            idx -= 1
        }
    }
}

public func handleCkbMcpHttpRequest(
    service: CkbCommandLoopService,
    method: String,
    path: String,
    body: String,
    headers: Array<String>,
    httpConfig: CkbHttpServiceConfig,
    mcpConfig: CkbMcpHttpServiceConfig,
    sessionStore: CkbMcpHttpSessionStore
): CkbMcpHttpResponse {
    let cleanMethod = method.trimAscii().toAsciiUpper()
    let cleanPath = path.trimAscii()
    if (cleanPath != mcpConfig.path) {
        return ckbMcpHttpError(404, "null", -32601, "method_not_found", "{\"path\":\"${ckbMcpJsonEscape(cleanPath)}\"}", "public")
    }

    let auth = ckbHttpAuthorize(httpConfig, headers, "read")
    if (!auth.authorized) {
        return ckbMcpHttpError(auth.statusCode, "null", -32000, auth.code, "{\"reason\":\"${ckbMcpJsonEscape(auth.diagnostic)}\"}", auth.authKind)
    }

    if (cleanMethod == "POST") {
        return ckbMcpHttpHandlePost(service, body, headers, httpConfig, mcpConfig, sessionStore, auth.authKind)
    }
    if (cleanMethod == "GET") {
        return ckbMcpHttpHandleSseGet(headers, mcpConfig, sessionStore, auth.authKind)
    }
    if (cleanMethod == "DELETE") {
        return ckbMcpHttpHandleDelete(headers, mcpConfig, sessionStore, auth.authKind)
    }
    ckbMcpHttpError(405, "null", -32601, "method_not_found", "{\"method\":\"${ckbMcpJsonEscape(cleanMethod)}\"}", auth.authKind)
}

private func ckbMcpHttpHandlePost(
    service: CkbCommandLoopService,
    body: String,
    headers: Array<String>,
    httpConfig: CkbHttpServiceConfig,
    mcpConfig: CkbMcpHttpServiceConfig,
    sessionStore: CkbMcpHttpSessionStore,
    authKind: String
): CkbMcpHttpResponse {
    let maxBytes = if (httpConfig.maxRequestBytes <= 0) { 1048576 } else { httpConfig.maxRequestBytes }
    if (Int64(body.size) > maxBytes) {
        return ckbMcpHttpError(413, "null", -32600, "request_too_large", "{\"limit\":${maxBytes}}", authKind)
    }
    if (!ckbMcpHttpValidatePostAccept(headers)) {
        return ckbMcpHttpError(406, ckbMcpHttpRequestIdOrNull(body), -32600, "not_acceptable", "{\"accept\":\"application/json, text/event-stream\"}", authKind)
    }
    if (!ckbMcpHttpHeaderContains(headers, "Content-Type", "application/json")) {
        return ckbMcpHttpError(400, ckbMcpHttpRequestIdOrNull(body), -32600, "content_type_required", "{\"contentType\":\"application/json\"}", authKind)
    }
    let trimmed = body.trimAscii()
    if (!trimmed.startsWith("{") || !trimmed.endsWith("}") || trimmed.startsWith("[")) {
        return ckbMcpHttpError(400, "null", -32700, "parse_error", "{}", authKind)
    }

    let id = ckbMcpJsonId(trimmed)
    let hasId = ckbMcpJsonHasId(trimmed)
    let method = ckbMcpJsonStringField(trimmed, "method")
    if (method == "") {
        return ckbMcpHttpAccepted(authKind)
    }

    if (method == "initialize" && hasId) {
        if (ckbMcpHttpHeaderValue(headers, "Mcp-Session-Id") != "") {
            return ckbMcpHttpError(400, id, -32602, "session_not_allowed_on_initialize", "{}", authKind)
        }
        let params = ckbMcpJsonObjectField(trimmed, "params")
        let protocolVersion = ckbMcpJsonStringField(params, "protocolVersion")
        if (protocolVersion == "") {
            return ckbMcpHttpError(400, id, -32602, "protocol_version_required", "{}", authKind)
        }
        let clientInfo = ckbMcpJsonObjectField(params, "clientInfo")
        let session = sessionStore.create(protocolVersion, ckbMcpJsonStringField(clientInfo, "name"))
        let protocol = CkbMcpProtocolServer(service)
        let dispatch = protocol.handleMessage(trimmed, protocolVersion, "ckb-cangjie-mcp-http")
        let response = ckbMcpHttpJsonResponse(200, if (dispatch.shouldWrite) { dispatch.payload } else { "{}" }, authKind)
        response.headers.add("Mcp-Session-Id: ${session.sessionId}")
        return response
    }

    let sessionResult = ckbMcpHttpRequireSession(headers, mcpConfig, sessionStore, authKind, id)
    if (!sessionResult.ok) {
        return sessionResult.response
    }

    if (!hasId) {
        if (method == "notifications/initialized") {
            sessionStore.markInitialized(sessionResult.session.sessionId)
        }
        return ckbMcpHttpAccepted(authKind)
    }

    let protocol = CkbMcpProtocolServer(service)
    let dispatch = protocol.handleMessage(trimmed, sessionResult.session.protocolVersion, "ckb-cangjie-mcp-http")
    if (!dispatch.shouldWrite) {
        return ckbMcpHttpAccepted(authKind)
    }
    ckbMcpHttpJsonResponse(200, dispatch.payload, authKind)
}

public func ckbMcpHttpHandleSseGet(
    headers: Array<String>,
    mcpConfig: CkbMcpHttpServiceConfig,
    sessionStore: CkbMcpHttpSessionStore,
    authKind: String
): CkbMcpHttpResponse {
    if (!ckbMcpHttpValidateSseAccept(headers)) {
        return ckbMcpHttpError(406, "null", -32600, "not_acceptable", "{\"accept\":\"text/event-stream\"}", authKind)
    }
    let sessionResult = ckbMcpHttpRequireSession(headers, mcpConfig, sessionStore, authKind, "null")
    if (!sessionResult.ok) {
        return sessionResult.response
    }
    let lastEventId = ckbMcpHttpHeaderValue(headers, "Last-Event-ID")
    if (lastEventId != "") {
        sessionStore.recordLastEventId(sessionResult.session.sessionId, lastEventId)
    }
    sessionStore.markSseConnected(sessionResult.session.sessionId)
    ckbMcpHttpSseStreamReady(sessionResult.session, authKind)
}

private func ckbMcpHttpHandleDelete(
    headers: Array<String>,
    mcpConfig: CkbMcpHttpServiceConfig,
    sessionStore: CkbMcpHttpSessionStore,
    authKind: String
): CkbMcpHttpResponse {
    let sessionResult = ckbMcpHttpRequireSession(headers, mcpConfig, sessionStore, authKind, "null")
    if (!sessionResult.ok) {
        return sessionResult.response
    }
    sessionStore.delete(sessionResult.session.sessionId)
    ckbMcpHttpAccepted(authKind)
}

public func ckbMcpHttpValidatePostAccept(headers: Array<String>): Bool {
    ckbMcpHttpHeaderContains(headers, "Accept", "application/json") && ckbMcpHttpHeaderContains(headers, "Accept", "text/event-stream")
}

public func ckbMcpHttpValidateSseAccept(headers: Array<String>): Bool {
    ckbMcpHttpHeaderContains(headers, "Accept", "text/event-stream")
}

public func ckbMcpHttpSseFrame(eventName: String, data: String, eventId: String): String {
    var out = ""
    if (eventId.trimAscii() != "") {
        out += "id: ${eventId.trimAscii()}\n"
    }
    if (eventName.trimAscii() != "") {
        out += "event: ${eventName.trimAscii()}\n"
    }
    for (line in data.split("\n")) {
        out += "data: ${line}\n"
    }
    out += "\n"
    out
}

public func ckbMcpHttpSseStreamReady(session: CkbMcpHttpSession, authKind: String): CkbMcpHttpResponse {
    let response = CkbMcpHttpResponse()
    response.statusCode = 200
    response.contentType = "text/event-stream"
    response.authKind = authKind
    response.streamMode = true
    response.body = ": ckb-mcp-ready\n\n"
    response
}

private class CkbMcpHttpSessionCheck {
    public var ok: Bool = false
    public var session: CkbMcpHttpSession = CkbMcpHttpSession()
    public var response: CkbMcpHttpResponse = CkbMcpHttpResponse()

    init() {}
}

private func ckbMcpHttpRequireSession(
    headers: Array<String>,
    mcpConfig: CkbMcpHttpServiceConfig,
    sessionStore: CkbMcpHttpSessionStore,
    authKind: String,
    id: String
): CkbMcpHttpSessionCheck {
    let result = CkbMcpHttpSessionCheck()
    let sessionId = ckbMcpHttpHeaderValue(headers, "Mcp-Session-Id")
    if (sessionId == "") {
        result.response = ckbMcpHttpError(400, id, -32602, "session_required", "{}", authKind)
        return result
    }
    let session = if (let Some(session) <- sessionStore.get(sessionId)) {
        session
    } else {
        result.response = ckbMcpHttpError(404, id, -32602, "session_not_found", "{}", authKind)
        return result
    }
    let protocolVersion = ckbMcpHttpHeaderValue(headers, "MCP-Protocol-Version")
    if (protocolVersion == "") {
        result.response = ckbMcpHttpError(400, id, -32602, "protocol_version_required", "{}", authKind)
        return result
    }
    if (protocolVersion != session.protocolVersion) {
        result.response = ckbMcpHttpError(400, id, -32602, "unsupported_protocol_version", "{\"supported\":\"${ckbMcpJsonEscape(session.protocolVersion)}\"}", authKind)
        return result
    }
    result.ok = true
    result.session = session
    result
}

private func ckbMcpHttpJsonResponse(statusCode: Int64, body: String, authKind: String): CkbMcpHttpResponse {
    let response = CkbMcpHttpResponse()
    response.statusCode = statusCode
    response.contentType = "application/json; charset=utf-8"
    response.authKind = authKind
    response.body = body
    response
}

private func ckbMcpHttpAccepted(authKind: String): CkbMcpHttpResponse {
    let response = CkbMcpHttpResponse()
    response.statusCode = 202
    response.contentType = "application/json; charset=utf-8"
    response.authKind = authKind
    response.body = ""
    response
}

private func ckbMcpHttpError(statusCode: Int64, id: String, code: Int64, message: String, data: String, authKind: String): CkbMcpHttpResponse {
    ckbMcpHttpJsonResponse(statusCode, "{\"jsonrpc\":\"2.0\",\"id\":${id},\"error\":{\"code\":${code},\"message\":\"${ckbMcpJsonEscape(message)}\",\"data\":${redactSensitive(data)}}}", authKind)
}

private func ckbMcpHttpRequestIdOrNull(body: String): String {
    if (body.trimAscii().startsWith("{")) {
        return ckbMcpJsonId(body)
    }
    "null"
}

private func ckbMcpHttpHeaderContains(headers: Array<String>, name: String, expected: String): Bool {
    let value = ckbMcpHttpHeaderValue(headers, name).toAsciiLower()
    let lowered = expected.toAsciiLower()
    for (part in value.split(",")) {
        if (part.trimAscii().startsWith(lowered)) {
            return true
        }
    }
    false
}

private func ckbMcpHttpHeaderValue(headers: Array<String>, name: String): String {
    let prefix = name.toAsciiLower() + ":"
    for (header in headers) {
        let cleaned = header.trimAscii()
        if (cleaned.toAsciiLower().startsWith(prefix)) {
            return cleaned[prefix.size..cleaned.size].trimAscii()
        }
    }
    ""
}

private func ckbMcpHttpNowMillis(): Int64 {
    DateTime.now().toUnixTimeStamp().toMilliseconds()
}
