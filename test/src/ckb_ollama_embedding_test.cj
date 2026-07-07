package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

private class FakeOllamaEmbeddingExecutor <: OllamaEmbeddingHttpExecutor {
    private var responses: ArrayList<OllamaEmbeddingHttpResponse> = ArrayList<OllamaEmbeddingHttpResponse>()
    public var requests: ArrayList<OllamaEmbeddingHttpRequest> = ArrayList<OllamaEmbeddingHttpRequest>()
    public var calls: Int64 = 0

    public init() {}

    public func add(response: OllamaEmbeddingHttpResponse): Unit {
        this.responses.add(response)
    }

    public func execute(request: OllamaEmbeddingHttpRequest): OllamaEmbeddingHttpResponse {
        this.calls += 1
        this.requests.add(request)
        if (this.responses.size == 0) {
            return responseWith(500, "{\"error\":\"missing fake response\"}", "http_500")
        }
        var index = this.calls - 1
        if (index >= this.responses.size) {
            index = this.responses.size - 1
        }
        this.responses[index]
    }
}

private class SlowOllamaEmbeddingExecutor <: OllamaEmbeddingHttpExecutor {
    public var calls: Int64 = 0

    public init() {}

    public func execute(request: OllamaEmbeddingHttpRequest): OllamaEmbeddingHttpResponse {
        this.calls += 1
        sleep(Duration.millisecond * 200)
        responseWith(200, embeddingResponseJson(1, 1024), "http_200")
    }
}

@Test
public class CkbOllamaEmbeddingTest {
    @TestCase
    public func ollamaEmbeddingFactoryReportsReadyStatusWhenConfigured(): Unit {
        let config = CkbRuntimeConfig()
        config.embeddingProvider = "ollama"
        config.embeddingModel = "bge-m3:latest"
        config.embeddingEndpoint = "http://127.0.0.1:11434/api/embed"
        config.embeddingDimensions = 1024
        config.embeddingAllowPrivateEndpoint = true
        let provider = embeddingProviderFromRuntime(config)
        let ready = provider.status()

        @Expect(ready.provider, "ollama")
        @Expect(ready.model, "bge-m3:latest")
        @Expect(ready.dimensions, 1024)
        @Expect(ready.endpointConfigured, true)
        @Expect(ready.production, true)
        @Expect(ready.state, EmbeddingProviderState.READY)

        config.embeddingEndpoint = ""
        let degraded = embeddingProviderFromRuntime(config).status()
        @Expect(degraded.provider, "ollama")
        @Expect(degraded.state, EmbeddingProviderState.DEGRADED)
        @Expect(degraded.degradedReason, "ollama_embedding_missing_config")

        config.embeddingEndpoint = "http://127.0.0.1:11434/api/embed"
        config.embeddingModel = ""
        let missingModel = embeddingProviderFromRuntime(config).status()
        @Expect(missingModel.state, EmbeddingProviderState.DEGRADED)
        @Expect(missingModel.degradedReason, "ollama_embedding_missing_config")

        config.embeddingModel = "bge-m3:latest"
        config.embeddingDimensions = 0
        let missingDimensions = embeddingProviderFromRuntime(config).status()
        @Expect(missingDimensions.state, EmbeddingProviderState.DEGRADED)
        @Expect(missingDimensions.degradedReason, "ollama_embedding_missing_config")
    }

    @TestCase
    public func ollamaEmbeddingParsesChineseBgeM3BatchResponse(): Unit {
        let fake = FakeOllamaEmbeddingExecutor()
        fake.add(responseWith(200, embeddingResponseJson(2, 1024), "http_200"))
        let provider = OllamaEmbeddingProvider(ollamaConfig(), executor: fake)
        let input = textBatch(["仓颉 HttpClient 如何设置超时", "generics and package docs"])

        let batch = provider.embed(input, "bge-m3:latest", 1024)

        @Expect(batch.status.state, EmbeddingProviderState.READY)
        @Expect(batch.requested, 2)
        @Expect(batch.succeeded, 2)
        @Expect(batch.failed, 0)
        @Expect(batch.vectors.size, 2)
        @Expect(batch.vectors[0].size, 1024)
        @Expect(fake.calls, 1)
        @Expect(fake.requests[0].method, "POST")
        @Expect(fake.requests[0].url, "http://127.0.0.1:11434/api/embed")
        @Expect(fake.requests[0].contentType, "application/json")
        @Expect(fake.requests[0].headers.size, 0)
        @Expect(fake.requests[0].body.contains("\"model\":\"bge-m3:latest\""), true)
        @Expect(fake.requests[0].body.contains("\"dimensions\":1024"), true)
        @Expect(fake.requests[0].body.contains("仓颉 HttpClient 如何设置超时"), true)
    }

    @TestCase
    public func ollamaEmbeddingMalformedJsonDegradesWithoutThrowing(): Unit {
        let fake = FakeOllamaEmbeddingExecutor()
        fake.add(responseWith(200, "{", "http_200"))
        let provider = OllamaEmbeddingProvider(ollamaConfig(), executor: fake)

        let batch = provider.embed(textBatch(["仓颉 malformed JSON 防崩溃"]), "bge-m3:latest", 1024)

        @Expect(batch.status.state, EmbeddingProviderState.DEGRADED)
        @Expect(batch.status.degradedReason, "malformed_json")
        @Expect(batch.vectors.size, 0)
        @Expect(batch.failed, 1)
    }

    @TestCase
    public func ollamaEmbeddingDefensiveFailuresReturnDegradedOrDown(): Unit {
        let empty = providerFor(responseWith(200, "{\"embeddings\":[]}", "http_200"))
            .embed(textBatch(["empty embeddings"]), "bge-m3:latest", 1024)
        @Expect(empty.status.state, EmbeddingProviderState.DEGRADED)
        @Expect(empty.status.degradedReason, "ollama_empty_embeddings")

        let mismatchedCount = providerFor(responseWith(200, embeddingResponseJson(1, 1024), "http_200"))
            .embed(textBatch(["one", "two"]), "bge-m3:latest", 1024)
        @Expect(mismatchedCount.status.state, EmbeddingProviderState.DEGRADED)
        @Expect(mismatchedCount.status.degradedReason, "ollama_embedding_count_mismatch")

        let mismatchedDimension = providerFor(responseWith(200, embeddingResponseJson(1, 16), "http_200"))
            .embed(textBatch(["dimension mismatch"]), "bge-m3:latest", 1024)
        @Expect(mismatchedDimension.status.state, EmbeddingProviderState.DEGRADED)
        @Expect(mismatchedDimension.status.degradedReason, "ollama_embedding_dimension_mismatch")

        let badRequest = providerFor(responseWith(400, "{\"error\":\"bad input\"}", "http_400"))
            .embed(textBatch(["bad request"]), "bge-m3:latest", 1024)
        @Expect(badRequest.status.state, EmbeddingProviderState.DEGRADED)
        @Expect(badRequest.status.degradedReason, "ollama_http_400")

        let serverError = providerFor(responseWith(500, "{\"error\":\"server\"}", "http_500"))
            .embed(textBatch(["server error"]), "bge-m3:latest", 1024)
        @Expect(serverError.status.state, EmbeddingProviderState.DOWN)
        @Expect(serverError.status.degradedReason, "ollama_http_500")

        let timeout = providerFor(timeoutResponse())
            .embed(textBatch(["timeout"]), "bge-m3:latest", 1024)
        @Expect(timeout.status.state, EmbeddingProviderState.DOWN)
        @Expect(timeout.status.degradedReason, "ollama_timeout")
    }

    @TestCase
    public func ruP1RuntimeEmbeddingAndVectorConfigNormalizeInvalidTimeoutBatchAndRetry(): Unit {
        let config = CkbRuntimeConfig()
        config.embeddingProvider = "ollama"
        config.embeddingModel = "bge-m3:latest"
        config.embeddingEndpoint = "http://127.0.0.1:11434/api/embed"
        config.embeddingDimensions = 1024
        config.embeddingBatchSize = 0
        config.embeddingTimeoutMillis = 0
        config.embeddingRetryCount = -1
        config.vectorBackend = "qdrant"
        config.vectorEndpoint = "http://127.0.0.1:6333"
        config.vectorDimensions = 1024
        config.vectorTimeoutMillis = 0
        config.vectorRetryCount = -1

        let embedding = embeddingConfigFromRuntime(config)
        let vector = vectorStoreConfigFromRuntime(config)
        let readiness = ckbRuntimeVectorReadinessWithStore(config, LocalVectorStore())

        @Expect(embedding.batchSize, 16)
        @Expect(embedding.timeoutMillis, 10000)
        @Expect(embedding.retryCount, 0)
        @Expect(vector.timeoutMillis, 10000)
        @Expect(vector.retryCount, 0)
        @Expect(readiness.ready, true)
    }

    @TestCase
    public func ollamaRuntimeEmbeddingReadinessRunsOneSmokeRequest(): Unit {
        let fake = FakeOllamaEmbeddingExecutor()
        fake.add(responseWith(200, embeddingResponseJson(1, 1024), "http_200"))
        let provider = OllamaEmbeddingProvider(ollamaConfig(), executor: fake)

        let readiness = ckbRuntimeEmbeddingReadinessWithProvider(ollamaRuntimeConfig(), provider)

        @Expect(readiness.ready, true)
        @Expect(readiness.state, EmbeddingProviderState.READY)
        @Expect(fake.calls, 1)
    }

    @TestCase
    public func ollamaRuntimeEmbeddingReadinessReportsTimeoutBeforeFullRebuild(): Unit {
        let readiness = ckbRuntimeEmbeddingReadinessWithProvider(ollamaRuntimeConfig(), providerFor(timeoutResponse()))

        @Expect(readiness.ready, false)
        @Expect(readiness.state, EmbeddingProviderState.DOWN)
        @Expect(readiness.reason, "ollama_timeout")
    }

    @TestCase
    public func ollamaProviderOuterTimeoutReturnsWithoutBlockingScheduler(): Unit {
        let config = ollamaConfig()
        config.timeoutMillis = 20
        config.totalTimeoutMillis = 20
        let slow = SlowOllamaEmbeddingExecutor()
        let provider = OllamaEmbeddingProvider(config, executor: slow)
        let started = DateTime.now().toUnixTimeStamp().toMilliseconds()

        let batch = provider.embed(textBatch(["slow request"]), "bge-m3:latest", 1024)
        let elapsed = DateTime.now().toUnixTimeStamp().toMilliseconds() - started

        @Expect(batch.status.state, EmbeddingProviderState.DOWN)
        @Expect(batch.status.degradedReason, "ollama_timeout")
        @Expect(batch.failed, 1)
        @Expect(elapsed < 1000, true)
        @Expect(slow.calls, 1)
    }

    @TestCase
    public func ollamaProviderAppliesUtf8SafeTextBudgetBeforeRequest(): Unit {
        let config = ollamaConfig()
        config.batchSize = 2
        config.maxBatchBytes = 16
        config.maxTextBytes = 8
        let fake = FakeOllamaEmbeddingExecutor()
        fake.add(responseWith(200, embeddingResponseJson(2, 1024), "http_200"))
        fake.add(responseWith(200, embeddingResponseJson(1, 1024), "http_200"))
        let provider = OllamaEmbeddingProvider(config, executor: fake)

        let batch = provider.embed(textBatch(["仓颉🙂abcdef", "plain", "third"]), "bge-m3:latest", 1024)

        @Expect(batch.status.state, EmbeddingProviderState.READY)
        @Expect(batch.succeeded, 3)
        @Expect(batch.truncatedCount, 1)
        @Expect(fake.calls, 2)
        @Expect(fake.requests[0].body.contains("仓颉"), true)
        @Expect(fake.requests[0].body.contains("🙂"), false)
    }
}

private func ollamaRuntimeConfig(): CkbRuntimeConfig {
    let config = CkbRuntimeConfig()
    config.embeddingProvider = "ollama"
    config.embeddingModel = "bge-m3:latest"
    config.embeddingEndpoint = "http://127.0.0.1:11434/api/embed"
    config.embeddingDimensions = 1024
    config.embeddingAllowPrivateEndpoint = true
    config
}

private func ollamaConfig(): EmbeddingConfig {
    let config = EmbeddingConfig()
    config.provider = "ollama"
    config.model = "bge-m3:latest"
    config.endpoint = "http://127.0.0.1:11434/api/embed"
    config.dimensions = 1024
    config.batchSize = 16
    config.timeoutMillis = 30000
    config.retryCount = 0
    config.production = true
    config.configured = true
    config
}

private func providerFor(response: OllamaEmbeddingHttpResponse): OllamaEmbeddingProvider {
    let fake = FakeOllamaEmbeddingExecutor()
    fake.add(response)
    OllamaEmbeddingProvider(ollamaConfig(), executor: fake)
}

private func responseWith(code: Int64, body: String, status: String): OllamaEmbeddingHttpResponse {
    let response = OllamaEmbeddingHttpResponse()
    response.statusCode = code
    response.body = body
    response.contentType = "application/json"
    response.status = status
    response
}

private func timeoutResponse(): OllamaEmbeddingHttpResponse {
    let response = OllamaEmbeddingHttpResponse()
    response.status = "timeout"
    response.transportErrorClass = "timeout"
    response.transportDiagnostic = "request timed out"
    response
}

private func textBatch(values: Array<String>): ArrayList<String> {
    let out = ArrayList<String>()
    for (value in values) {
        out.add(value)
    }
    out
}

private func embeddingResponseJson(count: Int64, dimensions: Int64): String {
    let out = StringBuilder()
    out.append("{\"embeddings\":[")
    for (row in 0..count) {
        if (row > 0) {
            out.append(",")
        }
        out.append("[")
        for (idx in 0..dimensions) {
            if (idx > 0) {
                out.append(",")
            }
            out.append("${(idx % 11) + 1}.0")
        }
        out.append("]")
    }
    out.append("]}")
    out.toString()
}
