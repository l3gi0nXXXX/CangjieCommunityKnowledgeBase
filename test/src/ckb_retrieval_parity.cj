package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashMap}
import std.io.InputStream
import std.process.*
import std.sort.*
import stdx.encoding.json.*

public class CkbMcpStdioCommandSpec {
    public var schemaVersion: String = ""
    public var executable: String = ""
    public var args: ArrayList<String> = ArrayList<String>()
    public var environment: ArrayList<String> = ArrayList<String>()
    public var timeoutMillis: Int64 = 0
    public init() {}
}

public class CkbRetrievalParityProcessResponse {
    public var exitCode: Int64 = 127
    public var stdout: Array<UInt8> = Array<UInt8>()
    public var diagnostic: String = "process_not_run"
    public init() {}
}

public interface CkbRetrievalParityProcessExecutor {
    func execute(spec: CkbMcpStdioCommandSpec, request: Array<UInt8>):
        CkbRetrievalParityProcessResponse
}

public class CkbNativeRetrievalParityProcessExecutor <:
    CkbRetrievalParityProcessExecutor {
    public func execute(spec: CkbMcpStdioCommandSpec,
        request: Array<UInt8>): CkbRetrievalParityProcessResponse {
        let out = CkbRetrievalParityProcessResponse()
        if (!ckbValidateMcpStdioCommandSpec(spec).ok ||
            request.size == 0 || request.size > 65536) {
            out.diagnostic = "mcp_stdio_request_invalid"; return out
        }
        let requestText = try { String.fromUtf8(request) }
            catch (_: Exception) {
                out.diagnostic = "invalid_response_encoding"; return out
            }
        if (requestText.contains("\n") || requestText.contains("\r")) {
            out.diagnostic = "mcp_stdio_request_frame_invalid"; return out
        }
        try { _ = JsonValue.fromStr(requestText).asObject() }
        catch (_: Exception) {
            out.diagnostic = "mcp_stdio_request_malformed_json"; return out
        }
        let environment = HashMap<String, String>()
        for (entry in spec.environment) {
            for (key in ["LANG", "LC_ALL", "PATH"]) {
                let prefix = "${key}="
                if (entry.startsWith(prefix)) {
                    let runes = entry.toRuneArray()
                    let valueRunes = runes[prefix.toRuneArray().size..]
                    let value = StringBuilder()
                    for (rune in valueRunes) { value.append(rune) }
                    environment[key] = value.toString()
                }
            }
        }
        try {
            let process = launch(spec.executable, spec.args.toArray(),
                environment: environment, stdIn: ProcessRedirect.Pipe,
                stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
            let stdoutFuture = spawn { =>
                ckbRetrievalParityReadLine(process.stdOutPipe, 262144) }
            let stderrFuture = spawn { =>
                ckbRetrievalParityReadPipe(process.stdErrPipe, 65536) }
            try {
                process.stdInPipe.write("${requestText}\n".toArray())
                process.stdInPipe.flush()
                let stdout = stdoutFuture.get(
                    Duration.millisecond * spec.timeoutMillis)
                if (stdout[0] != "ok") {
                    out.diagnostic = if (stdout[0] == "too_large") {
                        "mcp_stdio_response_too_large"
                    } else { "mcp_stdio_response_truncated" }
                    return out
                }
                out.stdout = stdout[1]; out.exitCode = 0
                out.diagnostic = "ok"
            } catch (_: Exception) {
                out.diagnostic = "mcp_stdio_process_timeout"
            } finally {
                try { process.terminate(force: true) } catch (_: Exception) {}
                try { _ = process.wait(timeout: Duration.second * 1) }
                catch (_: Exception) {}
                try { _ = stdoutFuture.get(Duration.second * 1) }
                catch (_: Exception) {}
                try { _ = stderrFuture.get(Duration.second * 1) }
                catch (_: Exception) {}
            }
        } catch (_: Exception) {
            out.diagnostic = "mcp_stdio_process_launch_failed"
        }
        out
    }
}

private func ckbRetrievalParityReadLine(pipe: InputStream,
    maxBytes: Int64): (String, Array<UInt8>) {
    let bytes = ArrayList<UInt8>()
    let buffer = Array<UInt8>(8192, repeat: UInt8(0))
    while (true) {
        let count = pipe.read(buffer)
        if (count == 0) { return ("truncated", Array<UInt8>()) }
        if (count < 0 || count > buffer.size) {
            return ("read_failed", Array<UInt8>())
        }
        for (i in 0..count) {
            if (buffer[i] == UInt8(10)) { return ("ok", bytes.toArray()) }
            if (bytes.size >= maxBytes) {
                return ("too_large", Array<UInt8>())
            }
            bytes.add(buffer[i])
        }
    }
    ("read_failed", Array<UInt8>())
}

private func ckbRetrievalParityReadPipe(pipe: InputStream,
    maxBytes: Int64): (Bool, Array<UInt8>) {
    let bytes = ArrayList<UInt8>()
    let buffer = Array<UInt8>(8192, repeat: UInt8(0))
    while (true) {
        let count = pipe.read(buffer)
        if (count < 0 || count > buffer.size) {
            return (false, Array<UInt8>())
        }
        if (count == 0) { return (true, bytes.toArray()) }
        if (bytes.size > maxBytes - count) {
            return (false, Array<UInt8>())
        }
        bytes.add(all: buffer[0..count])
    }
    (false, Array<UInt8>())
}

public func parseCkbMcpStdioCommandSpec(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbMcpStdioCommandSpec) {
    let out = CkbMcpStdioCommandSpec()
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (ckbRetrievalParityFailure("invalid_response_encoding"), out)
    }
    try {
        let object = JsonValue.fromStr(text).asObject()
        if (object.size() != 5) {
            return (ckbRetrievalParityFailure(
                "mcp_stdio_command_contract_invalid"), out)
        }
        out.schemaVersion = object.get("schemaVersion").getOrThrow()
            .asString().getValue()
        out.executable = object.get("executable").getOrThrow()
            .asString().getValue()
        for (value in object.get("args").getOrThrow().asArray().getItems()) {
            out.args.add(value.asString().getValue())
        }
        for (value in object.get("environment").getOrThrow().asArray().getItems()) {
            out.environment.add(value.asString().getValue())
        }
        out.timeoutMillis = object.get("timeoutMillis").getOrThrow()
            .asInt().getValue()
    } catch (_: Exception) {
        return (ckbRetrievalParityFailure("mcp_stdio_command_malformed_json"), out)
    }
    let validation = ckbValidateMcpStdioCommandSpec(out)
    (validation, out)
}

private func ckbValidateMcpStdioCommandSpec(
    spec: CkbMcpStdioCommandSpec): CkbReproContractResult {
    if (spec.schemaVersion != "ckb-mcp-stdio-command-v1" ||
        !spec.executable.startsWith("/") || spec.executable.size > 4096 ||
        spec.args.size > 64 || spec.environment.size > 8 ||
        spec.timeoutMillis < 100 || spec.timeoutMillis > 300000) {
        return ckbRetrievalParityFailure("mcp_stdio_command_contract_invalid")
    }
    let executable = spec.executable.toAsciiLower()
    for (shell in ["/bin/sh", "/bin/bash", "/bin/zsh", "/usr/bin/env"]) {
        if (executable == shell || executable.endsWith("/${shell[5..]}")) {
            return ckbRetrievalParityFailure("mcp_stdio_command_forbidden")
        }
    }
    for (arg in spec.args) {
        if (arg == "" || arg.toRuneArray().size > 1024 ||
            arg.contains("\u{0000}") || arg.contains("\n") ||
            arg.contains("\r")) {
            return ckbRetrievalParityFailure(
                "mcp_stdio_command_contract_invalid")
        }
    }
    for (entry in spec.environment) {
        if (!(entry.startsWith("LANG=") || entry.startsWith("LC_ALL=") ||
            entry.startsWith("PATH=")) || entry.contains("\n") ||
            entry.contains("\r") || entry.toRuneArray().size > 4096) {
            return ckbRetrievalParityFailure(
                "mcp_stdio_environment_forbidden")
        }
    }
    ckbRetrievalParitySuccess()
}

public class CkbProductionRetrievalParityBackend <:
    CkbRetrievalParityBackend {
    private let restEndpoint: String
    private let stdioSpec: CkbMcpStdioCommandSpec
    private let mcpHttpEndpoint: String
    private let http: HttpRequestExecutor
    private let process: CkbRetrievalParityProcessExecutor
    public init(restEndpoint: String, stdioSpec: CkbMcpStdioCommandSpec,
        mcpHttpEndpoint: String, http: HttpRequestExecutor,
        process: CkbRetrievalParityProcessExecutor) {
        this.restEndpoint = restEndpoint
        this.stdioSpec = stdioSpec
        this.mcpHttpEndpoint = mcpHttpEndpoint
        this.http = http
        this.process = process
    }
    public func query(transport: String, query: String):
        CkbRetrievalParityResponse {
        let out = CkbRetrievalParityResponse()
        let validation = validateCkbRetrievalParityQuery(query)
        if (!validation.ok) {
            out.diagnostic = "retrieval_parity_query_forbidden"
            return out
        }
        let escaped = ckbRetrievalParityJson(query)
        if (transport == "rest") {
            let request = HttpExecutionRequest()
            request.method = "POST"; request.url = this.restEndpoint
            request.accept = "application/json"
            request.contentType = "application/json"
            request.body = "{\"q\":\"${escaped}\",\"budget\":5}"
            request.retryCount = 0; request.maxResponseBytes = 262144
            let response = this.http.execute(request)
            if (response.statusCode < 200 || response.statusCode >= 300) {
                out.diagnostic = "retrieval_parity_rest_failed"; return out
            }
            return ckbParseRetrievalParityResponse(
                response.body.toArray(), "rest")
        }
        let rpc = "{\"jsonrpc\":\"2.0\",\"id\":1," +
            "\"method\":\"tools/call\",\"params\":{" +
            "\"name\":\"cangjie_syntax_query\",\"arguments\":{" +
            "\"q\":\"${escaped}\",\"budget\":5}}}"
        if (transport == "mcp_stdio") {
            let response = this.process.execute(this.stdioSpec, rpc.toArray())
            if (response.exitCode != 0 || response.diagnostic != "ok") {
                out.diagnostic = if (response.diagnostic == "") {
                    "retrieval_parity_stdio_failed"
                } else { response.diagnostic }
                return out
            }
            return ckbParseRetrievalParityResponse(
                response.stdout, "mcp")
        }
        if (transport == "mcp_http") {
            let request = HttpExecutionRequest()
            request.method = "POST"; request.url = this.mcpHttpEndpoint
            request.accept = "application/json"
            request.contentType = "application/json"
            request.body = rpc; request.retryCount = 0
            request.maxResponseBytes = 262144
            let response = this.http.execute(request)
            if (response.statusCode < 200 || response.statusCode >= 300) {
                out.diagnostic = "retrieval_parity_mcp_http_failed"; return out
            }
            return ckbParseRetrievalParityResponse(
                response.body.toArray(), "mcp")
        }
        out.diagnostic = "retrieval_parity_transport_invalid"; out
    }
}

public func ckbParseRetrievalParityResponse(bytes: Array<UInt8>,
    shape: String): CkbRetrievalParityResponse {
    let out = CkbRetrievalParityResponse(); out.rawBytes = bytes.clone()
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        out.diagnostic = "invalid_response_encoding"; return out
    }
    try {
        let root = JsonValue.fromStr(text.trimAscii()).asObject()
        let payload = if (shape == "rest") {
            if (!root.get("ok").getOrThrow().asBool().getValue()) {
                out.diagnostic = "retrieval_parity_rest_error"; return out
            }
            root.get("data").getOrThrow().asObject()
        } else if (shape == "mcp") {
            let result = root.get("result").getOrThrow().asObject()
            let content = result.get("content").getOrThrow().asArray().getItems()
            if (content.size != 1) {
                out.diagnostic = "retrieval_parity_mcp_response_invalid"; return out
            }
            let item = content[0].asObject()
            if (item.get("type").getOrThrow().asString().getValue() != "text") {
                out.diagnostic = "retrieval_parity_mcp_response_invalid"; return out
            }
            JsonValue.fromStr(item.get("text").getOrThrow()
                .asString().getValue()).asObject()
        } else {
            out.diagnostic = "retrieval_parity_response_shape_invalid"; return out
        }
        out.knowledgeVersion = payload.get("knowledgeVersion")
            .getOrThrow().asString().getValue()
        let citations = payload.get("citations").getOrThrow()
            .asArray().getItems()
        var rank: Int64 = 1
        for (value in citations) {
            let item = value.asObject()
            let sourceId = item.get("sourceId").getOrThrow()
                .asString().getValue()
            let citation = item.get("citation").getOrThrow()
                .asString().getValue()
            let version = item.get("knowledgeVersion").getOrThrow()
                .asString().getValue()
            if (sourceId == "" || citation == "" ||
                version != out.knowledgeVersion) {
                out.diagnostic = "retrieval_parity_hit_invalid"; return out
            }
            let hit = CkbRetrievalParityHit()
            hit.logicalId = sourceId
            hit.contentHash = benchmarkGapSha256("${sourceId}|${citation}")
            hit.citation = citation; hit.rank = rank; rank += 1
            out.hits.add(hit)
        }
    } catch (_: Exception) {
        out.diagnostic = "retrieval_parity_malformed_json"; return out
    }
    if (out.knowledgeVersion == "" || out.hits.size == 0) {
        out.diagnostic = "retrieval_parity_empty_response"; return out
    }
    out.ok = true; out.diagnostic = "ok"; out
}

private func ckbRetrievalParityJson(value: String): String {
    let out = StringBuilder()
    for (rune in value.runes()) {
        if (rune == r'"') { out.append("\\\"") }
        else if (rune == r'\\') { out.append("\\\\") }
        else if (rune == r'\n') { out.append("\\n") }
        else if (rune == r'\r') { out.append("\\r") }
        else if (rune == r'\t') { out.append("\\t") }
        else if (UInt32(rune) < 0x20u32) { out.append(" ") }
        else { out.append(rune) }
    }
    out.toString()
}

public class CkbRetrievalParityHit {
    public var logicalId: String = ""
    public var contentHash: String = ""
    public var citation: String = ""
    public var rank: Int64 = 0
    public init() {}
}

public class CkbRetrievalParityResponse {
    public var ok: Bool = false
    public var diagnostic: String = ""
    public var knowledgeVersion: String = ""
    public var hits: ArrayList<CkbRetrievalParityHit> =
        ArrayList<CkbRetrievalParityHit>()
    public var rawBytes: Array<UInt8> = Array<UInt8>()
    public init() {}
}

public interface CkbRetrievalParityBackend {
    func query(transport: String, query: String):
        CkbRetrievalParityResponse
}

public class CkbRetrievalParityManifest {
    public var schemaVersion: String = "ckb-retrieval-parity-v1"
    public var knowledgeVersion: String = ""
    public var logicalManifestHash: String = ""
    public var query: String = ""
    public var transports: ArrayList<String> = ArrayList<String>()
    public var canonicalResultHash: String = ""
    public init() {}
}

public class CkbRetrievalParityResult {
    public var ok: Bool = false
    public var diagnostic: String = "retrieval_parity_not_run"
    public var manifest: CkbRetrievalParityManifest =
        CkbRetrievalParityManifest()
    public init() {}
}

public func ckbRetrievalParityReferenceQuery(): String {
    "仓颉语言中如何按 Rune 安全遍历 UTF-8 字符串？"
}

public func validateCkbRetrievalParityQuery(
    query: String): CkbReproContractResult {
    let lowered = query.toAsciiLower()
    for (forbidden in [
        "humaneval", "pass@1", "hidden test", "reference solution",
        "teacher solution", "case 0", "case 1", "case id"
    ]) {
        if (lowered.contains(forbidden)) {
            return ckbRetrievalParityFailure(
                "retrieval_parity_benchmark_query_forbidden")
        }
    }
    if (query.trimAscii() == "" || query.size > 500) {
        return ckbRetrievalParityFailure(
            "retrieval_parity_query_invalid")
    }
    ckbRetrievalParitySuccess()
}

public func buildCkbRetrievalParityManifest(knowledgeVersion: String,
    logicalManifestHash: String, backend: CkbRetrievalParityBackend):
    CkbRetrievalParityResult {
    let result = CkbRetrievalParityResult()
    let query = ckbRetrievalParityReferenceQuery()
    if (!validateCkbRetrievalParityQuery(query).ok ||
        knowledgeVersion == "" ||
        !ckbRetrievalParityHashValid(logicalManifestHash)) {
        result.diagnostic = "retrieval_parity_identity_invalid"
        return result
    }
    let transports = ["rest", "mcp_stdio", "mcp_http"]
    var expected: String = ""
    for (transport in transports) {
        let response = backend.query(transport, query)
        let canonical = ckbRetrievalParityCanonicalResponse(response)
        if (canonical[0] != "ok") {
            result.diagnostic = canonical[0]
            return result
        }
        if (response.knowledgeVersion != knowledgeVersion) {
            result.diagnostic = "retrieval_parity_knowledge_version_mismatch"
            return result
        }
        if (expected == "") { expected = canonical[1] }
        if (canonical[1] != expected) {
            result.diagnostic = "retrieval_parity_result_mismatch"
            return result
        }
        result.manifest.transports.add(transport)
    }
    result.manifest.knowledgeVersion = knowledgeVersion
    result.manifest.logicalManifestHash = logicalManifestHash
    result.manifest.query = query
    result.manifest.canonicalResultHash =
        benchmarkGapSha256(expected)
    result.ok = true
    result.diagnostic = "ok"
    result
}

public func verifyCkbRetrievalParityManifest(
    manifest: CkbRetrievalParityManifest,
    backend: CkbRetrievalParityBackend): CkbRetrievalParityResult {
    let result = CkbRetrievalParityResult()
    result.manifest = manifest
    if (manifest.schemaVersion != "ckb-retrieval-parity-v1" ||
        manifest.knowledgeVersion == "" ||
        !ckbRetrievalParityHashValid(manifest.logicalManifestHash) ||
        !ckbRetrievalParityHashValid(manifest.canonicalResultHash) ||
        manifest.query != ckbRetrievalParityReferenceQuery() ||
        manifest.transports.size != 3 ||
        manifest.transports[0] != "rest" ||
        manifest.transports[1] != "mcp_stdio" ||
        manifest.transports[2] != "mcp_http") {
        result.diagnostic = "retrieval_parity_manifest_invalid"
        return result
    }
    var expected: String = ""
    for (transport in manifest.transports) {
        let response = backend.query(transport, manifest.query)
        let canonical = ckbRetrievalParityCanonicalResponse(response)
        if (canonical[0] != "ok") {
            result.diagnostic = canonical[0]
            return result
        }
        if (response.knowledgeVersion != manifest.knowledgeVersion) {
            result.diagnostic = "retrieval_parity_knowledge_version_mismatch"
            return result
        }
        if (expected == "") { expected = canonical[1] }
        if (canonical[1] != expected ||
            benchmarkGapSha256(canonical[1]) !=
                manifest.canonicalResultHash) {
            result.diagnostic = "retrieval_parity_result_mismatch"
            return result
        }
    }
    result.ok = true
    result.diagnostic = "ok"
    result
}

private func ckbRetrievalParityCanonicalResponse(
    response: CkbRetrievalParityResponse): (String, String) {
    if (!response.ok) {
        return (if (response.diagnostic == "") {
            "retrieval_parity_transport_failed"
        } else { response.diagnostic }, "")
    }
    if (response.rawBytes.size > 0) {
        let decoded = try { String.fromUtf8(response.rawBytes) } catch (_: Exception) {
            return ("invalid_response_encoding", "")
        }
        if (decoded == "") { return ("retrieval_parity_empty_response", "") }
    }
    let rows = ArrayList<String>()
    for (hit in response.hits) {
        if (hit.logicalId == "" || hit.rank <= 0 ||
            !ckbRetrievalParityHashValid(hit.contentHash)) {
            return ("retrieval_parity_hit_invalid", "")
        }
        rows.add("${hit.rank}|${hit.logicalId}|${hit.contentHash}|${hit.citation}")
    }
    if (rows.size == 0) { return ("retrieval_parity_empty_response", "") }
    let ordered = rows.toArray()
    sort(ordered)
    var out = ""
    for (row in ordered) { out += "${row}\n" }
    ("ok", out)
}

private func ckbRetrievalParityHashValid(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 71 || !value.startsWith("sha256:")) { return false }
    for (i in 7..runes.size) {
        if (!((runes[i] >= r'0' && runes[i] <= r'9') ||
            (runes[i] >= r'a' && runes[i] <= r'f'))) { return false }
    }
    true
}

private func ckbRetrievalParityFailure(
    diagnostic: String): CkbReproContractResult {
    let result = CkbReproContractResult()
    result.diagnostic = diagnostic
    result
}

private func ckbRetrievalParitySuccess(): CkbReproContractResult {
    let result = CkbReproContractResult()
    result.ok = true
    result.diagnostic = "ok"
    result
}
