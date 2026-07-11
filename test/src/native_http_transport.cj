package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.convert.Parsable
import std.env.getVariable
import std.net.{SocketAddress, TcpSocket}
import std.time.*
import stdx.encoding.base64.toBase64String
import stdx.encoding.url.URL
import stdx.net.http.*
import stdx.net.tls.*

public class CkbNativeHttpTransportConfig {
    public let proxy: String
    public let envProxyEnabled: Bool
    public let noProxy: String
    public let insecureSkipTlsVerify: Bool
    public let allowPrivateNetwork: Bool
    public let allowedHosts: String
    public let timeoutMillis: Int64

    public init(
        proxy: String,
        envProxyEnabled: Bool,
        noProxy: String,
        insecureSkipTlsVerify: Bool,
        allowPrivateNetwork: Bool,
        allowedHosts: String,
        timeoutMillis: Int64
    ) {
        this.proxy = proxy.trimAscii()
        this.envProxyEnabled = envProxyEnabled
        this.noProxy = noProxy.trimAscii()
        this.insecureSkipTlsVerify = insecureSkipTlsVerify
        this.allowPrivateNetwork = allowPrivateNetwork
        this.allowedHosts = allowedHosts.trimAscii()
        this.timeoutMillis = if (timeoutMillis > 0) { timeoutMillis } else { 10000 }
    }
}

public class CkbNativeHttpRoute {
    public let mode: String
    public let proxySource: String
    public let redactedProxy: String
    public let targetHost: String
    public let error: String

    public init(mode: String, proxySource: String, redactedProxy: String, targetHost: String, error!: String = "") {
        this.mode = mode
        this.proxySource = proxySource
        this.redactedProxy = redactedProxy
        this.targetHost = targetHost
        this.error = error
    }
}

public class CkbNativeHttpProxyEndpoint {
    public let host: String
    public let port: UInt16
    public let auth: String
    public let scheme: String

    public init(host: String, port: UInt16, auth!: String = "", scheme!: String = "http") {
        this.host = host
        this.port = port
        this.auth = auth
        this.scheme = scheme
    }
}

public class CkbNativeHttpTransportDiagnostic {
    public var transportErrorClass: String = "unknown"
    public var transportDiagnostic: String = ""

    public init() {}
}

public class CkbNativeHttpBuildPlan {
    public let route: CkbNativeHttpRoute
    public let useConnector: Bool
    public let useHttpProxy: Bool
    public let useTls: Bool

    public init(route: CkbNativeHttpRoute, useConnector: Bool, useHttpProxy: Bool, useTls: Bool) {
        this.route = route
        this.useConnector = useConnector
        this.useHttpProxy = useHttpProxy
        this.useTls = useTls
    }
}

public class CkbNativeHttpSmokeResult {
    public var routeMode: String = ""
    public var targetHost: String = ""
    public var tlsVerifyMode: String = "strict"
    public var proxySource: String = "none"
    public var redactedProxy: String = ""
    public var httpStatus: Int64 = 0
    public var status: String = ""
    public var transportClass: String = ""
    public var transportDiagnostic: String = ""
    public var rawWritten: Bool = false
    public var candidateWritten: Bool = false
    public var activePromoted: Bool = false

    public init() {}
}

public class NativeHttpRequestExecutor <: HttpRequestExecutor {
    private let config: CkbNativeHttpTransportConfig

    public init(runtime: CkbRuntimeConfig) {
        this.config = CkbNativeHttpTransportConfig(
            runtime.networkProxy,
            runtime.networkEnvProxyEnabled,
            runtime.networkNoProxy,
            runtime.networkInsecureSkipTlsVerify,
            runtime.networkAllowPrivateNetwork,
            runtime.networkAllowedHosts,
            runtime.timeoutMillis
        )
    }

    public init(config: CkbNativeHttpTransportConfig) {
        this.config = config
    }

    public func execute(request: HttpExecutionRequest): HttpExecutionResponse {
        if (!httpExecutionMethodSupported(request.method)) {
            return unsupportedHttpExecutionResponse(request.method)
        }
        let response = HttpExecutionResponse()
        let urlPolicy = ckbNativeHttpValidateUrl(request.url, this.config)
        if (urlPolicy != "") {
            response.status = "blocked_url"
            response.transportErrorClass = "blocked_url"
            response.transportDiagnostic = urlPolicy
            return response
        }
        try {
            let timeoutMillis = if (request.timeoutMillis > 0) { request.timeoutMillis } else { this.config.timeoutMillis }
            let future = spawn { =>
                ckbNativeHttpExecuteOnce(request, this.config)
            }
            return future.get(Duration.millisecond * timeoutMillis)
        } catch (e: Exception) {
            let diagnostic = ckbNativeHttpClassifyException(e.message)
            let timeoutMillis = if (request.timeoutMillis > 0) { request.timeoutMillis } else { this.config.timeoutMillis }
            response.status = ckbNativeHttpFailureStatus(diagnostic.transportErrorClass)
            response.transportErrorClass = diagnostic.transportErrorClass
            response.transportDiagnostic = ckbNativeHttpExecutionDiagnostic(request, diagnostic, timeoutMillis)
        }
        response
    }

    public func get(request: HttpExecutionRequest): HttpExecutionResponse {
        let getRequest = ckbNativeHttpCopyExecutionRequest(request)
        getRequest.method = "GET"
        this.execute(getRequest)
    }
}

private func ckbNativeHttpExecuteOnce(request: HttpExecutionRequest, config: CkbNativeHttpTransportConfig): HttpExecutionResponse {
    let response = HttpExecutionResponse()
    let timeoutMillis = if (request.timeoutMillis > 0) { request.timeoutMillis } else { config.timeoutMillis }
    try {
        let clientParts = ckbNativeHttpBuildClientBuilder(request.url, config, request.timeoutMillis)
        let route = clientParts[1]
        if (route.error != "") {
            response.status = "transport_error"
            response.transportErrorClass = "proxy"
            response.transportDiagnostic = route.error
            return response
        }
        let client = clientParts[0].build()
        try {
            let nativeResponse = client.send(ckbNativeHttpBuildRequest(request))
            let decoded = ckbNativeHttpDecodeBody(nativeResponse)
            if (!decoded[0]) {
                return ckbNativeHttpInvalidEncodingResponse(request, timeoutMillis)
            }
            response.statusCode = Int64(nativeResponse.status)
            response.body = decoded[1]
            response.contentType = nativeResponse.headers.getFirst("content-type") ?? nativeResponse.headers.getFirst("Content-Type") ?? ""
            response.retryAfterSeconds = ckbNativeHttpParseRetryAfter(nativeResponse.headers.getFirst("retry-after") ?? nativeResponse.headers.getFirst("Retry-After") ?? "")
            response.status = "http_${response.statusCode}"
        } finally {
            client.close()
        }
        return response
    } catch (e: Exception) {
        return ckbNativeHttpExceptionResponse(request, e.message, timeoutMillis)
    }
}

private func ckbNativeHttpExceptionResponse(request: HttpExecutionRequest, message: String, timeoutMillis: Int64): HttpExecutionResponse {
    let diagnostic = ckbNativeHttpClassifyException(message)
    let response = HttpExecutionResponse()
    response.status = ckbNativeHttpFailureStatus(diagnostic.transportErrorClass)
    response.transportErrorClass = diagnostic.transportErrorClass
    response.transportDiagnostic = ckbNativeHttpExecutionDiagnostic(request, diagnostic, timeoutMillis)
    response
}

public func ckbNativeHttpConfigFromRuntime(config: CkbRuntimeConfig): CkbNativeHttpTransportConfig {
    CkbNativeHttpTransportConfig(
        config.networkProxy,
        config.networkEnvProxyEnabled,
        config.networkNoProxy,
        config.networkInsecureSkipTlsVerify,
        config.networkAllowPrivateNetwork,
        config.networkAllowedHosts,
        config.timeoutMillis
    )
}

public func ckbNativeHttpAdapterConfigFromRuntime(config: CkbRuntimeConfig, allowPrivateEndpoint: Bool): CkbNativeHttpTransportConfig {
    CkbNativeHttpTransportConfig(
        config.networkProxy,
        config.networkEnvProxyEnabled,
        config.networkNoProxy,
        config.networkInsecureSkipTlsVerify,
        config.networkAllowPrivateNetwork || allowPrivateEndpoint,
        config.networkAllowedHosts,
        config.timeoutMillis
    )
}

public func ckbNativeHttpSmoke(url: String, runtime: CkbRuntimeConfig): String {
    ckbNativeHttpRenderSmokeResult(ckbNativeHttpSmokeWithExecutor(url, ckbNativeHttpConfigFromRuntime(runtime), NativeHttpRequestExecutor(runtime)))
}

public func ckbNativeHttpSmokeWithExecutor(url: String, config: CkbNativeHttpTransportConfig, executor: HttpRequestExecutor): CkbNativeHttpSmokeResult {
    let trimmed = url.trimAscii()
    let route = ckbNativeHttpResolveRoute(trimmed, config)
    let result = CkbNativeHttpSmokeResult()
    result.routeMode = route.mode
    result.targetHost = route.targetHost
    result.tlsVerifyMode = if (config.insecureSkipTlsVerify) { "trust-all" } else { "strict" }
    result.proxySource = route.proxySource
    result.redactedProxy = route.redactedProxy

    let urlPolicy = ckbNativeHttpValidateUrl(trimmed, config)
    if (urlPolicy != "") {
        result.status = "blocked_url"
        result.transportClass = "blocked_url"
        result.transportDiagnostic = urlPolicy
        return result
    }
    if (route.error != "") {
        result.status = "transport_error"
        result.transportClass = "proxy"
        result.transportDiagnostic = route.error
        return result
    }

    let request = HttpExecutionRequest()
    request.method = "GET"
    request.url = trimmed
    request.accept = "*/*"
    request.timeoutMillis = config.timeoutMillis
    request.retryCount = 0

    let response = executor.get(request)
    result.httpStatus = response.statusCode
    result.status = response.status
    result.transportClass = if (response.transportErrorClass == "") { "none" } else { response.transportErrorClass }
    result.transportDiagnostic = response.transportDiagnostic
    result
}

public func ckbNativeHttpRenderSmokeResult(result: CkbNativeHttpSmokeResult): String {
    var out = "native-http-smoke"
    out += " route=${result.routeMode}"
    out += " targetHost=${if (result.targetHost == "") { "n/a" } else { result.targetHost }}"
    out += " tlsVerifyMode=${result.tlsVerifyMode}"
    out += " proxySource=${result.proxySource}"
    if (result.redactedProxy != "") {
        out += " proxy=${result.redactedProxy}"
    }
    out += " httpStatus=${result.httpStatus}"
    out += " status=${if (result.status == "") { "unknown" } else { result.status }}"
    out += " transportClass=${if (result.transportClass == "") { "none" } else { result.transportClass }}"
    out += " transportDiagnostic=${if (result.transportDiagnostic == "") { "none" } else { redactSensitive(result.transportDiagnostic) }}"
    out += " rawWritten=${result.rawWritten} candidateWritten=${result.candidateWritten} activePromoted=${result.activePromoted}\n"
    redactSensitive(out)
}

public func ckbNativeHttpValidateUrl(url: String, config: CkbNativeHttpTransportConfig): String {
    let trimmed = url.trimAscii()
    let scheme = ckbNativeHttpScheme(trimmed)
    if (scheme != "http" && scheme != "https") {
        return "blocked non-http url"
    }
    let host = ckbNativeHttpTargetHost(trimmed)
    if (host == "") {
        return "blocked url without host"
    }
    if (!config.allowPrivateNetwork && ckbNativeHttpHostLooksPrivate(host)) {
        return "blocked private-network host: ${host}"
    }
    if (config.allowPrivateNetwork && ckbNativeHttpHostLooksPrivate(host)) {
        return ""
    }
    if (!ckbNativeHttpHostAllowed(host, config.allowedHosts)) {
        return "blocked host: ${host}"
    }
    ""
}

public func ckbNativeHttpResolveRoute(url: String, config: CkbNativeHttpTransportConfig): CkbNativeHttpRoute {
    let targetHost = ckbNativeHttpTargetHost(url)
    let targetScheme = ckbNativeHttpScheme(url)
    let proxyInfo = ckbNativeHttpProxyForUrl(url, config)
    let proxy = proxyInfo[0]
    let source = proxyInfo[1]
    if (proxy == "") {
        return CkbNativeHttpRoute("direct", "none", "", targetHost)
    }
    let proxyScheme = ckbNativeHttpProxyScheme(proxy)
    if (targetScheme == "https" && proxyScheme == "https") {
        return CkbNativeHttpRoute("unsupportedHttpsProxy", source, ckbNativeHttpRedactProxy(proxy), targetHost, error: "true HTTPS proxy is not implemented; configure an HTTP proxy or bare host:port for HTTPS CONNECT")
    }
    if (targetScheme == "https") {
        return CkbNativeHttpRoute("httpConnectTunnel", source, ckbNativeHttpRedactProxy(proxy), targetHost)
    }
    CkbNativeHttpRoute("httpProxy", source, ckbNativeHttpRedactProxy(proxy), targetHost)
}

public func ckbNativeHttpRedactProxy(proxy: String): String {
    let trimmed = proxy.trimAscii()
    if (trimmed == "") {
        return ""
    }
    let schemeEnd = match (trimmed.indexOf("://")) {
        case Some(idx) => idx + 3
        case None => 0
    }
    let prefix = trimmed[..schemeEnd]
    let rest = trimmed[schemeEnd..]
    match (rest.lastIndexOf("@")) {
        case Some(idx) => "${prefix}[redacted]@${rest[idx + 1..]}"
        case None => trimmed
    }
}

public func ckbNativeHttpParseProxyEndpoint(proxy: String): CkbNativeHttpProxyEndpoint {
    let trimmed = proxy.trimAscii()
    let scheme = ckbNativeHttpProxyScheme(trimmed)
    let withoutScheme = if (trimmed.toAsciiLower().startsWith("http://")) {
        trimmed[7..]
    } else if (trimmed.toAsciiLower().startsWith("https://")) {
        trimmed[8..]
    } else {
        trimmed
    }
    let authority = match (withoutScheme.indexOf("/")) {
        case Some(idx) => withoutScheme[..idx]
        case None => withoutScheme
    }
    var hostPort = authority
    var auth = ""
    match (authority.lastIndexOf("@")) {
        case Some(idx) =>
            auth = authority[..idx]
            hostPort = authority[idx + 1..]
        case None => ()
    }
    var host = hostPort
    var port: UInt16 = if (scheme == "https") { 443u16 } else { 80u16 }
    match (hostPort.lastIndexOf(":")) {
        case Some(idx) =>
            host = hostPort[..idx]
            let parsed = Int64.parse(hostPort[idx + 1..])
            if (parsed > 0 && parsed <= 65535) {
                port = UInt16(parsed)
            }
        case None => ()
    }
    if (host.trimAscii() == "") {
        throw Exception("invalid native HTTP proxy host")
    }
    CkbNativeHttpProxyEndpoint(host.trimAscii(), port, auth: auth, scheme: scheme)
}

public func ckbNativeHttpBuildConnectRequest(targetHost: String, targetPort: UInt16, endpoint: CkbNativeHttpProxyEndpoint): String {
    var request = "CONNECT ${targetHost}:${targetPort} HTTP/1.1\r\n" +
        "Host: ${targetHost}:${targetPort}\r\n" +
        "Proxy-Connection: Keep-Alive\r\n"
    if (endpoint.auth != "") {
        request += "Proxy-Authorization: Basic ${toBase64String(endpoint.auth.toArray())}\r\n"
    }
    request + "\r\n"
}

public func ckbNativeHttpClassifyException(message: String): CkbNativeHttpTransportDiagnostic {
    let diagnostic = CkbNativeHttpTransportDiagnostic()
    if (message.toAsciiLower().contains("invalid_response_encoding") || message.toAsciiLower().contains("invalid utf-8")) {
        diagnostic.transportErrorClass = "invalid_response_encoding"
        diagnostic.transportDiagnostic = "invalid_response_encoding"
        return diagnostic
    }
    let safe = redactSensitive(message).replace("\n", " ").replace("\r", " ").trimAscii()
    diagnostic.transportDiagnostic = if (safe.size > 160) { utf8SafePrefix(safe, 160) } else { safe }
    let lowered = safe.toAsciiLower()
    if (lowered.contains("timed out") || lowered.contains("timeout")) {
        diagnostic.transportErrorClass = "timeout"
    } else if (lowered.contains("could not resolve") || lowered.contains("failed to resolve address") || lowered.contains("resolve address") || lowered.contains("name lookup") || lowered.contains("dns") || lowered.contains("unknown host") || lowered.contains("nodename nor servname") || lowered.contains("name or service not known")) {
        diagnostic.transportErrorClass = "dns"
    } else if (lowered.contains("unknown ca") || lowered.contains("certificate verify failed") || lowered.contains("self signed") || lowered.contains("unable to get local issuer")) {
        diagnostic.transportErrorClass = "tls_unknown_ca"
    } else if (lowered.contains("hostname mismatch") || lowered.contains("host name mismatch") || lowered.contains("does not match") || lowered.contains("not valid for")) {
        diagnostic.transportErrorClass = "tls_hostname_mismatch"
    } else if (lowered.contains("certificate has expired") || lowered.contains("certificate expired") || lowered.contains("expired certificate") || lowered.contains("not yet valid")) {
        diagnostic.transportErrorClass = "tls_expired_certificate"
    } else if (lowered.contains("can not load openssl") || lowered.contains("cannot load openssl") || lowered.contains("crypto_get_ex_new_index")) {
        diagnostic.transportErrorClass = "tls_runtime"
    } else if (lowered.contains("ssl") || lowered.contains("tls") || lowered.contains("certificate")) {
        diagnostic.transportErrorClass = "tls_handshake_failed"
    } else if (lowered.contains("proxy") || lowered.contains("connect failed")) {
        diagnostic.transportErrorClass = "proxy"
    } else if (lowered.contains("connection refused") || lowered.contains("failed to connect")) {
        diagnostic.transportErrorClass = "connection_refused"
    } else {
        diagnostic.transportErrorClass = "unknown"
    }
    if (diagnostic.transportDiagnostic == "") {
        diagnostic.transportDiagnostic = diagnostic.transportErrorClass
    }
    diagnostic
}

private func ckbNativeHttpFailureStatus(errorClass: String): String {
    if (errorClass == "timeout") { return "timeout" }
    if (errorClass == "invalid_response_encoding") { return "invalid_response_encoding" }
    "transport_error"
}

private func ckbNativeHttpInvalidEncodingResponse(request: HttpExecutionRequest, timeoutMillis: Int64): HttpExecutionResponse {
    let response = HttpExecutionResponse()
    let diagnostic = CkbNativeHttpTransportDiagnostic()
    diagnostic.transportErrorClass = "invalid_response_encoding"
    diagnostic.transportDiagnostic = "invalid_response_encoding"
    response.status = "invalid_response_encoding"
    response.statusCode = 0
    response.body = ""
    response.transportErrorClass = "invalid_response_encoding"
    response.transportDiagnostic = ckbNativeHttpExecutionDiagnostic(request, diagnostic, timeoutMillis)
    response
}

private func ckbNativeHttpExecutionDiagnostic(request: HttpExecutionRequest, diagnostic: CkbNativeHttpTransportDiagnostic, timeoutMillis: Int64): String {
    let host = ckbNativeHttpTargetHost(request.url)
    let base = if (diagnostic.transportErrorClass == "timeout") { "native_http_total_timeout" } else { diagnostic.transportDiagnostic }
    let clean = utf8SafePrefix(redactSensitive(base), 160)
    "method=${normalizeHttpExecutionMethod(request.method)} host=${if (host == "") { "unknown" } else { host }} timeoutMillis=${timeoutMillis} diagnostic=${clean}"
}

public func ckbNativeHttpDescribeBuildPlan(url: String, config: CkbNativeHttpTransportConfig): CkbNativeHttpBuildPlan {
    let route = ckbNativeHttpResolveRoute(url, config)
    CkbNativeHttpBuildPlan(
        route,
        route.mode == "httpConnectTunnel",
        route.mode == "httpProxy",
        ckbNativeHttpScheme(url) == "https"
    )
}

private func ckbNativeHttpBuildClientBuilder(url: String, config: CkbNativeHttpTransportConfig, requestTimeoutMillis: Int64): (ClientBuilder, CkbNativeHttpRoute) {
    let effectiveTimeout = if (requestTimeoutMillis > 0) { requestTimeoutMillis } else { config.timeoutMillis }
    let plan = ckbNativeHttpDescribeBuildPlan(url, config)
    let route = plan.route
    let builder = ClientBuilder()
    builder.readTimeout(Duration.millisecond * effectiveTimeout)
    let proxyInfo = ckbNativeHttpProxyForUrl(url, config)
    if (plan.useHttpProxy) {
        builder.httpProxy(proxyInfo[0])
    }
    if (plan.useTls) {
        var tlsConfig = TlsClientConfig()
        if (config.insecureSkipTlsVerify) {
            tlsConfig.verifyMode = TrustAll
        }
        tlsConfig.domain = route.targetHost
        tlsConfig.alpnProtocolsList = ["http/1.1"]
        builder.tlsConfig(tlsConfig)
    }
    if (plan.useConnector) {
        let endpoint = ckbNativeHttpParseProxyEndpoint(proxyInfo[0])
        let targetHost = route.targetHost
        let connectTimeoutMillis = if (effectiveTimeout > 0) { effectiveTimeout } else { 10000 }
        let socketConnector = { _sa: SocketAddress =>
            let socket = TcpSocket(endpoint.host, endpoint.port)
            socket.readTimeout = Duration.millisecond * connectTimeoutMillis
            socket.writeTimeout = Duration.millisecond * connectTimeoutMillis
            socket.connect(timeout: Duration.millisecond * connectTimeoutMillis)
            ckbNativeHttpOpenConnectTunnel(socket, targetHost, 443u16, endpoint)
            return socket
        }
        builder.connector(socketConnector)
    }
    (builder, route)
}

private func ckbNativeHttpBuildRequest(request: HttpExecutionRequest): HttpRequest {
    let method = normalizeHttpExecutionMethod(request.method)
    let builder = HttpRequestBuilder().url(request.url)
    match (method) {
        case "GET" => builder.get()
        case "POST" => builder.post()
        case "PUT" => builder.method("PUT")
        case "DELETE" => builder.method("DELETE")
        case _ => builder.get()
    }
    builder.header("Accept", request.accept)
    if (request.contentType.trimAscii() != "") {
        builder.header("Content-Type", request.contentType.trimAscii())
    }
    for (header in request.headers) {
        let parsed = ckbNativeHttpParseHeaderLine(header)
        if (parsed[0] != "") {
            builder.header(parsed[0], parsed[1])
        }
    }
    if (request.body != "") {
        builder.body(request.body)
    }
    builder.build()
}

private func ckbNativeHttpCopyExecutionRequest(request: HttpExecutionRequest): HttpExecutionRequest {
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

private func ckbNativeHttpParseHeaderLine(header: String): (String, String) {
    match (header.indexOf(":")) {
        case Some(idx) =>
            let key = header[..idx].trimAscii()
            let value = header[idx + 1..].trimAscii()
            if (key == "") {
                return ("", "")
            }
            (key, value)
        case None => ("", "")
    }
}

private func ckbNativeHttpDecodeBody(response: HttpResponse): (Bool, String) {
    let out = ArrayList<Byte>()
    let buffer = Array<Byte>(8192, repeat: 0)
    while (true) {
        let n = response.body.read(buffer)
        if (n <= 0) {
            break
        }
        out.add(all: buffer[..n])
    }
    ckbNativeHttpDecodeUtf8Bytes(out.toArray())
}

func ckbNativeHttpDecodeUtf8Bytes(bytes: Array<Byte>): (Bool, String) {
    try {
        (true, String.fromUtf8(bytes))
    } catch (_: Exception) {
        (false, "")
    }
}

private func ckbNativeHttpOpenConnectTunnel(socket: TcpSocket, targetHost: String, targetPort: UInt16, endpoint: CkbNativeHttpProxyEndpoint): Unit {
    socket.write(ckbNativeHttpBuildConnectRequest(targetHost, targetPort, endpoint).toArray())
    let response = ckbNativeHttpReadConnectResponse(socket)
    let firstLine = match (response.indexOf("\r\n")) {
        case Some(idx) => response[..idx]
        case None => response
    }
    if (!firstLine.contains(" 200 ")) {
        throw Exception("native HTTP proxy CONNECT failed: ${firstLine}")
    }
}

private func ckbNativeHttpReadConnectResponse(socket: TcpSocket): String {
    let output = ArrayList<Byte>()
    let buffer = Array<Byte>(1024, repeat: 0)
    var total: Int64 = 0
    while (total < 8192) {
        let n = socket.read(buffer)
        if (n <= 0) {
            break
        }
        output.add(all: buffer[..n])
        total += n
        if (ckbNativeHttpHeaderBytesComplete(output)) {
            let decoded = ckbNativeHttpDecodeUtf8Bytes(output.toArray())
            if (!decoded[0]) { throw Exception("invalid_response_encoding") }
            return decoded[1]
        }
    }
    let decoded = ckbNativeHttpDecodeUtf8Bytes(output.toArray())
    if (!decoded[0]) { throw Exception("invalid_response_encoding") }
    decoded[1]
}

private func ckbNativeHttpHeaderBytesComplete(bytes: ArrayList<Byte>): Bool {
    if (bytes.size < 4) { return false }
    var i: Int64 = 0
    while (i + 3 < bytes.size) {
        if (bytes[i] == UInt8(13) && bytes[i + 1] == UInt8(10) && bytes[i + 2] == UInt8(13) && bytes[i + 3] == UInt8(10)) {
            return true
        }
        i += 1
    }
    false
}

private func ckbNativeHttpParseRetryAfter(raw: String): Int64 {
    try { Int64.parse(raw.trimAscii()) } catch (_: Exception) { 0 }
}

private func ckbNativeHttpProxyForUrl(url: String, config: CkbNativeHttpTransportConfig): (String, String) {
    if (ckbNativeHttpNoProxyMatches(url, config)) {
        return ("", "none")
    }
    if (config.proxy != "") {
        return (config.proxy, "explicit")
    }
    if (!config.envProxyEnabled) {
        return ("", "none")
    }
    let envProxy = ckbNativeHttpEnvProxyForUrl(url)
    if (envProxy != "") {
        return (envProxy, "env")
    }
    ("", "none")
}

private func ckbNativeHttpNoProxyMatches(url: String, config: CkbNativeHttpTransportConfig): Bool {
    var raw = config.noProxy
    if (raw == "") {
        raw = ckbNativeHttpEnv("NO_PROXY")
        if (raw == "") {
            raw = ckbNativeHttpEnv("no_proxy")
        }
    }
    if (raw == "") {
        return false
    }
    let host = ckbNativeHttpTargetHost(url)
    if (host == "") {
        return false
    }
    for (part0 in raw.split(",")) {
        let part = part0.trimAscii().toAsciiLower()
        if (part == "") {
            continue
        }
        if (part == "*" || part == host) {
            return true
        }
        if (part.startsWith(".")) {
            if (host.endsWith(part)) {
                return true
            }
        } else if (host.endsWith("." + part)) {
            return true
        }
    }
    false
}

private func ckbNativeHttpEnvProxyForUrl(url: String): String {
    if (ckbNativeHttpScheme(url) == "https") {
        let httpsProxy = ckbNativeHttpEnv("HTTPS_PROXY")
        if (httpsProxy != "") {
            return httpsProxy
        }
        let lowerHttpsProxy = ckbNativeHttpEnv("https_proxy")
        if (lowerHttpsProxy != "") {
            return lowerHttpsProxy
        }
    }
    let httpProxy = ckbNativeHttpEnv("HTTP_PROXY")
    if (httpProxy != "") {
        return httpProxy
    }
    ckbNativeHttpEnv("http_proxy")
}

private func ckbNativeHttpEnv(key: String): String {
    match (getVariable(key)) {
        case Some(v) => v.trimAscii()
        case None => ""
    }
}

private func ckbNativeHttpProxyScheme(proxy: String): String {
    let lower = proxy.trimAscii().toAsciiLower()
    if (lower.startsWith("https://")) {
        return "https"
    }
    if (lower.startsWith("http://")) {
        return "http"
    }
    "http"
}

private func ckbNativeHttpTargetHost(url: String): String {
    try { URL.parse(url.trimAscii()).hostName.trimAscii().toAsciiLower() } catch (_: Exception) { "" }
}

private func ckbNativeHttpScheme(url: String): String {
    try { URL.parse(url.trimAscii()).scheme.trimAscii().toAsciiLower() } catch (_: Exception) { "" }
}

private func ckbNativeHttpHostAllowed(host: String, extraAllowedHosts: String): Bool {
    let normalized = host.trimAscii().toAsciiLower()
    if (normalized == "api.gitcode.com" || normalized == "gitcode.com" || normalized == "cangjie-lang.cn" || normalized == "docs.cangjie-lang.cn" || normalized == "example.invalid") {
        return true
    }
    for (part0 in extraAllowedHosts.split(",")) {
        let part = part0.trimAscii().toAsciiLower()
        if (part != "" && (part == normalized || normalized.endsWith("." + part))) {
            return true
        }
    }
    false
}

private func ckbNativeHttpHostLooksPrivate(host: String): Bool {
    let h = host.trimAscii().toAsciiLower()
    if (h == "localhost" || h == "0.0.0.0" || h == "127.0.0.1" || h == "::1" || h == "[::1]") {
        return true
    }
    if (h.startsWith("127.") || h.startsWith("10.") || h.startsWith("192.168.") || h.startsWith("169.254.")) {
        return true
    }
    if (h.startsWith("172.")) {
        let parts = h.split(".")
        if (parts.size >= 2) {
            try {
                let second = Int64.parse(parts[1])
                if (second >= 16 && second <= 31) {
                    return true
                }
            } catch (_: Exception) {
                ()
            }
        }
    }
    h.startsWith("fc") || h.startsWith("fd") || h.startsWith("fe80:")
}
