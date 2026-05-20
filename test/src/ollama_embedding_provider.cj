package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.convert.Parsable

public class OllamaEmbeddingHttpRequest {
    public var method: String = "POST"
    public var url: String = ""
    public var accept: String = "application/json"
    public var contentType: String = "application/json"
    public var headers: ArrayList<String> = ArrayList<String>()
    public var body: String = ""
    public var timeoutMillis: Int64 = 10000
    public var retryCount: Int64 = 2

    public init() {}
}

public class OllamaEmbeddingHttpResponse {
    public var statusCode: Int64 = 0
    public var body: String = ""
    public var contentType: String = ""
    public var status: String = "not_started"
    public var retryAfterSeconds: Int64 = 0
    public var transportErrorClass: String = ""
    public var transportDiagnostic: String = ""

    public init() {}
}

public interface OllamaEmbeddingHttpExecutor {
    func execute(request: OllamaEmbeddingHttpRequest): OllamaEmbeddingHttpResponse
}

private class UnavailableOllamaEmbeddingHttpExecutor <: OllamaEmbeddingHttpExecutor {
    public init() {}

    public func execute(request: OllamaEmbeddingHttpRequest): OllamaEmbeddingHttpResponse {
        let response = OllamaEmbeddingHttpResponse()
        response.status = "unsupported_method"
        response.transportErrorClass = "unsupported_method"
        response.transportDiagnostic = "http_execute_not_configured"
        response
    }
}

private class OllamaEmbeddingParseResult {
    public var ok: Bool = false
    public var diagnostic: String = "malformed_json"
    public var vectors: ArrayList<ArrayList<Float64>> = ArrayList<ArrayList<Float64>>()

    public init() {}
}

public class OllamaEmbeddingProvider <: EmbeddingProvider {
    private let config: EmbeddingConfig
    private let executor: OllamaEmbeddingHttpExecutor

    public init(config: EmbeddingConfig) {
        this.config = config
        this.executor = UnavailableOllamaEmbeddingHttpExecutor()
    }

    public init(config: EmbeddingConfig, executor!: OllamaEmbeddingHttpExecutor) {
        this.config = config
        this.executor = executor
    }

    public func embed(texts: ArrayList<String>, model: String, dimensions: Int64): EmbeddingBatch {
        let batch = EmbeddingBatch()
        batch.requested = texts.size
        batch.batchSize = effectiveBatchSize(this.config.batchSize)
        batch.status = this.status()
        let effectiveModel = if (model == "") { this.config.model } else { model }
        let effectiveDimensions = if (dimensions > 0) { dimensions } else { this.config.dimensions }
        if (batch.status.state != EmbeddingProviderState.READY || effectiveModel == "" || effectiveDimensions <= 0) {
            batch.failed = texts.size
            return batch
        }
        if (texts.size == 0) {
            batch.status.state = EmbeddingProviderState.READY
            return batch
        }

        var offset: Int64 = 0
        var degradedReason = ""
        var down = false
        while (offset < texts.size) {
            let chunk = ArrayList<String>()
            let limit = minInt64(texts.size, offset + batch.batchSize)
            for (idx in offset..limit) {
                chunk.add(texts[idx])
            }
            let chunkResult = this.embedChunk(chunk, effectiveModel, effectiveDimensions)
            if (chunkResult.status.state == EmbeddingProviderState.READY) {
                for (vector in chunkResult.vectors) {
                    batch.vectors.add(vector)
                }
            } else {
                batch.failed += chunk.size
                if (degradedReason == "") {
                    degradedReason = chunkResult.status.degradedReason
                }
                if (chunkResult.status.state == EmbeddingProviderState.DOWN) {
                    down = true
                }
            }
            offset = limit
        }
        batch.succeeded = batch.vectors.size
        batch.failed = batch.requested - batch.succeeded
        if (batch.failed > 0) {
            batch.status.state = if (down && batch.succeeded == 0) { EmbeddingProviderState.DOWN } else { EmbeddingProviderState.DEGRADED }
            batch.status.degradedReason = if (degradedReason == "") { "ollama_embedding_failed" } else { degradedReason }
        } else {
            batch.status.state = EmbeddingProviderState.READY
            batch.status.degradedReason = ""
        }
        batch
    }

    public func status(): EmbeddingStatus {
        let status = EmbeddingStatus()
        status.provider = "ollama"
        status.model = this.config.model
        status.dimensions = this.config.dimensions
        status.endpointConfigured = this.config.endpoint != ""
        status.tokenConfigured = this.config.credentialPresent()
        status.batchSize = effectiveBatchSize(this.config.batchSize)
        status.timeoutMillis = this.config.timeoutMillis
        status.retryCount = this.config.retryCount
        status.production = true
        if (!this.config.configured || this.config.endpoint == "" || this.config.model == "" || this.config.dimensions <= 0) {
            status.state = EmbeddingProviderState.DEGRADED
            status.degradedReason = "ollama_embedding_missing_config"
            return status
        }
        status.state = EmbeddingProviderState.READY
        status
    }

    private func embedChunk(texts: ArrayList<String>, model: String, dimensions: Int64): EmbeddingBatch {
        let batch = EmbeddingBatch()
        batch.requested = texts.size
        batch.batchSize = effectiveBatchSize(this.config.batchSize)
        batch.status = this.status()
        let request = OllamaEmbeddingHttpRequest()
        request.method = "POST"
        request.url = this.config.endpoint
        request.accept = "application/json"
        request.contentType = "application/json"
        request.body = ollamaEmbeddingRequestBody(model, texts, dimensions)
        request.timeoutMillis = this.config.timeoutMillis
        request.retryCount = this.config.retryCount

        let response = this.executeWithRetry(request)
        let httpState = ollamaStatusFromHttpResponse(response)
        if (httpState.state != EmbeddingProviderState.READY) {
            batch.status.state = httpState.state
            batch.status.degradedReason = httpState.degradedReason
            batch.failed = texts.size
            return batch
        }

        let parsed = parseOllamaEmbeddingResponse(response.body)
        if (!parsed.ok) {
            batch.status.state = EmbeddingProviderState.DEGRADED
            batch.status.degradedReason = parsed.diagnostic
            batch.failed = texts.size
            return batch
        }
        if (parsed.vectors.size == 0) {
            batch.status.state = EmbeddingProviderState.DEGRADED
            batch.status.degradedReason = "ollama_empty_embeddings"
            batch.failed = texts.size
            return batch
        }
        if (parsed.vectors.size != texts.size) {
            batch.status.state = EmbeddingProviderState.DEGRADED
            batch.status.degradedReason = "ollama_embedding_count_mismatch"
            batch.failed = texts.size
            return batch
        }
        for (vector in parsed.vectors) {
            if (vector.size != dimensions) {
                batch.status.state = EmbeddingProviderState.DEGRADED
                batch.status.degradedReason = "ollama_embedding_dimension_mismatch"
                batch.failed = texts.size
                return batch
            }
        }
        for (vector in parsed.vectors) {
            batch.vectors.add(vector)
        }
        batch.succeeded = batch.vectors.size
        batch.status.state = EmbeddingProviderState.READY
        batch
    }

    private func executeWithRetry(request: OllamaEmbeddingHttpRequest): OllamaEmbeddingHttpResponse {
        var attempt: Int64 = 0
        var last = OllamaEmbeddingHttpResponse()
        while (attempt <= request.retryCount) {
            attempt += 1
            try {
                last = this.executor.execute(request)
            } catch (_: Exception) {
                last = OllamaEmbeddingHttpResponse()
                last.status = "transport_error"
                last.transportErrorClass = "exception"
                last.transportDiagnostic = "executor_exception"
            }
            if (last.statusCode != 429 && last.statusCode < 500 && last.status != "timeout") {
                break
            }
        }
        last
    }
}

private func ollamaStatusFromHttpResponse(response: OllamaEmbeddingHttpResponse): EmbeddingStatus {
    let status = EmbeddingStatus()
    status.provider = "ollama"
    status.production = true
    if (response.status == "timeout" || response.transportErrorClass == "timeout") {
        status.state = EmbeddingProviderState.DOWN
        status.degradedReason = "ollama_timeout"
        return status
    }
    if (response.status == "blocked_url") {
        status.state = EmbeddingProviderState.DEGRADED
        status.degradedReason = "ollama_blocked_url"
        return status
    }
    if (response.status == "unsupported_method") {
        status.state = EmbeddingProviderState.DOWN
        status.degradedReason = "ollama_http_execute_unavailable"
        return status
    }
    if (response.status == "transport_error" || (response.statusCode == 0 && response.status != "http_0")) {
        status.state = EmbeddingProviderState.DOWN
        status.degradedReason = if (response.transportErrorClass == "") { "ollama_transport_error" } else { "ollama_${response.transportErrorClass}" }
        return status
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
        status.state = EmbeddingProviderState.READY
        return status
    }
    if (response.statusCode >= 500) {
        status.state = EmbeddingProviderState.DOWN
        status.degradedReason = "ollama_http_${response.statusCode}"
        return status
    }
    status.state = EmbeddingProviderState.DEGRADED
    status.degradedReason = "ollama_http_${response.statusCode}"
    status
}

private func ollamaEmbeddingRequestBody(model: String, texts: ArrayList<String>, dimensions: Int64): String {
    let out = StringBuilder()
    out.append("{\"model\":\"")
    out.append(ollamaJsonEscape(model))
    out.append("\",\"input\":[")
    for (idx in 0..texts.size) {
        if (idx > 0) {
            out.append(",")
        }
        out.append("\"")
        out.append(ollamaJsonEscape(texts[idx]))
        out.append("\"")
    }
    out.append("],\"dimensions\":")
    out.append("${dimensions}")
    out.append("}")
    out.toString()
}

private func ollamaJsonEscape(raw: String): String {
    let out = StringBuilder()
    for (ch in raw.toRuneArray()) {
        if (ch == r'"') {
            out.append("\\\"")
        } else if (ch == r'\\') {
            out.append("\\\\")
        } else if (ch == r'\n') {
            out.append("\\n")
        } else if (ch == r'\r') {
            out.append("\\r")
        } else if (ch == r'\t') {
            out.append("\\t")
        } else if (UInt32(ch) < 0x20u32) {
            out.append(" ")
        } else {
            out.append(ch)
        }
    }
    out.toString()
}

private func parseOllamaEmbeddingResponse(body: String): OllamaEmbeddingParseResult {
    try {
        return parseOllamaEmbeddingResponseUnsafe(body)
    } catch (_: Exception) {
        let result = OllamaEmbeddingParseResult()
        result.ok = false
        result.diagnostic = "malformed_json"
        return result
    }
}

private func parseOllamaEmbeddingResponseUnsafe(body: String): OllamaEmbeddingParseResult {
    let result = OllamaEmbeddingParseResult()
    let start = ollamaJsonValueStart(body, "embeddings")
    if (start < 0 || start >= body.size || body[start..start + 1] != "[") {
        result.diagnostic = "malformed_json"
        return result
    }
    var i = ollamaSkipJsonWhitespace(body, start + 1)
    if (i < body.size && body[i..i + 1] == "]") {
        result.ok = true
        return result
    }
    while (i < body.size) {
        if (body[i..i + 1] != "[") {
            result.diagnostic = "malformed_json"
            return result
        }
        let vector = ArrayList<Float64>()
        i = ollamaSkipJsonWhitespace(body, i + 1)
        if (i < body.size && body[i..i + 1] == "]") {
            i += 1
        } else {
            while (i < body.size) {
                let numberStart = i
                while (i < body.size && ollamaIsNumberChar(body[i..i + 1])) {
                    i += 1
                }
                if (numberStart == i) {
                    result.diagnostic = "malformed_json"
                    return result
                }
                let token = body[numberStart..i]
                let value = try { Float64.parse(token) } catch (_: Exception) {
                    result.diagnostic = "malformed_json"
                    return result
                }
                vector.add(value)
                i = ollamaSkipJsonWhitespace(body, i)
                if (i < body.size && body[i..i + 1] == ",") {
                    i = ollamaSkipJsonWhitespace(body, i + 1)
                    continue
                }
                if (i < body.size && body[i..i + 1] == "]") {
                    i += 1
                    break
                }
                result.diagnostic = "malformed_json"
                return result
            }
        }
        result.vectors.add(vector)
        i = ollamaSkipJsonWhitespace(body, i)
        if (i < body.size && body[i..i + 1] == ",") {
            i = ollamaSkipJsonWhitespace(body, i + 1)
            continue
        }
        if (i < body.size && body[i..i + 1] == "]") {
            result.ok = true
            return result
        }
        result.diagnostic = "malformed_json"
        return result
    }
    result.diagnostic = "malformed_json"
    result
}

private func ollamaJsonValueStart(raw: String, key: String): Int64 {
    let marker = "\"${key}\""
    let start = match (raw.indexOf(marker)) {
        case Some(idx) => idx + marker.size
        case None => return -1
    }
    var i = ollamaSkipJsonWhitespace(raw, start)
    if (i >= raw.size || raw[i..i + 1] != ":") {
        return -1
    }
    ollamaSkipJsonWhitespace(raw, i + 1)
}

private func ollamaSkipJsonWhitespace(raw: String, start: Int64): Int64 {
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

private func ollamaIsNumberChar(ch: String): Bool {
    ch == "-" || ch == "+" || ch == "." || ch == "e" || ch == "E" ||
        (ch >= "0" && ch <= "9")
}

private func effectiveBatchSize(value: Int64): Int64 {
    if (value > 0) {
        return value
    }
    16
}

private func minInt64(left: Int64, right: Int64): Int64 {
    if (left < right) {
        return left
    }
    right
}
