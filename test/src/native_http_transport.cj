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

    public func get(request: HttpExecutionRequest): HttpExecutionResponse {
        let response = HttpExecutionResponse()
        if (request.method != "GET") {
            response.status = "unsupported_method"
            return response
        }
        let urlPolicy = ckbNativeHttpValidateUrl(request.url, this.config)
        if (urlPolicy != "") {
            response.status = "blocked_url"
            response.transportErrorClass = "blocked_url"
            response.transportDiagnostic = urlPolicy
            return response
        }
        try {
            let clientParts = ckbNativeHttpBuildClientBuilder(request.url, this.config, request.timeoutMillis)
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
                response.statusCode = Int64(nativeResponse.status)
                response.body = ckbNativeHttpDecodeBody(nativeResponse)
                response.contentType = nativeResponse.headers.getFirst("content-type") ?? nativeResponse.headers.getFirst("Content-Type") ?? ""
                response.retryAfterSeconds = ckbNativeHttpParseRetryAfter(nativeResponse.headers.getFirst("retry-after") ?? nativeResponse.headers.getFirst("Retry-After") ?? "")
                response.status = "http_${response.statusCode}"
            } finally {
                client.close()
            }
        } catch (e: Exception) {
            let diagnostic = ckbNativeHttpClassifyException(e.message)
            response.status = if (diagnostic.transportErrorClass == "timeout") { "timeout" } else { "transport_error" }
            response.transportErrorClass = diagnostic.transportErrorClass
            response.transportDiagnostic = diagnostic.transportDiagnostic
        }
        response
    }
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
    let safe = redactSensitive(message).replace("\n", " ").replace("\r", " ").trimAscii()
    diagnostic.transportDiagnostic = if (safe.size > 160) { safe[0..160] } else { safe }
    let lowered = safe.toAsciiLower()
    if (lowered.contains("timed out") || lowered.contains("timeout")) {
        diagnostic.transportErrorClass = "timeout"
    } else if (lowered.contains("could not resolve") || lowered.contains("name lookup") || lowered.contains("dns") || lowered.contains("unknown host")) {
        diagnostic.transportErrorClass = "dns"
    } else if (lowered.contains("ssl") || lowered.contains("tls") || lowered.contains("certificate")) {
        diagnostic.transportErrorClass = "tls"
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

private func ckbNativeHttpBuildClientBuilder(url: String, config: CkbNativeHttpTransportConfig, requestTimeoutMillis: Int64): (ClientBuilder, CkbNativeHttpRoute) {
    let effectiveTimeout = if (requestTimeoutMillis > 0) { requestTimeoutMillis } else { config.timeoutMillis }
    let route = ckbNativeHttpResolveRoute(url, config)
    let builder = ClientBuilder()
    builder.readTimeout(Duration.millisecond * effectiveTimeout)
    let proxyInfo = ckbNativeHttpProxyForUrl(url, config)
    if (route.mode == "httpProxy") {
        builder.httpProxy(proxyInfo[0])
    }
    if (ckbNativeHttpScheme(url) == "https") {
        var tlsConfig = TlsClientConfig()
        if (config.insecureSkipTlsVerify) {
            tlsConfig.verifyMode = TrustAll
        }
        tlsConfig.domain = route.targetHost
        tlsConfig.alpnProtocolsList = ["http/1.1"]
        builder.tlsConfig(tlsConfig)
    }
    if (route.mode == "httpConnectTunnel") {
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
    } else if (route.mode == "direct") {
        let connectTimeoutMillis = if (effectiveTimeout > 0) { effectiveTimeout } else { 10000 }
        let socketConnector = { sa: SocketAddress =>
            let socket = TcpSocket(sa)
            socket.readTimeout = Duration.millisecond * connectTimeoutMillis
            socket.writeTimeout = Duration.millisecond * connectTimeoutMillis
            socket.connect(timeout: Duration.millisecond * connectTimeoutMillis)
            return socket
        }
        builder.connector(socketConnector)
    }
    (builder, route)
}

private func ckbNativeHttpBuildRequest(request: HttpExecutionRequest): HttpRequest {
    let builder = HttpRequestBuilder().url(request.url).get()
    builder.header("Accept", request.accept)
    for (header in request.headers) {
        let parsed = ckbNativeHttpParseHeaderLine(header)
        if (parsed[0] != "") {
            builder.header(parsed[0], parsed[1])
        }
    }
    builder.build()
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

private func ckbNativeHttpDecodeBody(response: HttpResponse): String {
    let out = ArrayList<Byte>()
    let buffer = Array<Byte>(8192, repeat: 0)
    while (true) {
        let n = response.body.read(buffer)
        if (n <= 0) {
            break
        }
        out.add(all: buffer[..n])
    }
    String.fromUtf8(out.toArray())
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
        let text = String.fromUtf8(output.toArray())
        if (text.contains("\r\n\r\n")) {
            return text
        }
    }
    String.fromUtf8(output.toArray())
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
