package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

private class QdrantHttpStep {
    public var code: Int64 = 0
    public var body: String = ""
    public var contentType: String = "application/json"
    public var status: String = ""
    public var transportClass: String = ""
    public var transportDiagnostic: String = ""

    public init() {}
}

private class QdrantFakeExecutor <: HttpRequestExecutor {
    private var steps: ArrayList<QdrantHttpStep> = ArrayList<QdrantHttpStep>()
    public var calls: Int64 = 0
    public var methods: ArrayList<String> = ArrayList<String>()
    public var urls: ArrayList<String> = ArrayList<String>()
    public var bodies: ArrayList<String> = ArrayList<String>()
    public var contentTypes: ArrayList<String> = ArrayList<String>()
    public var headers: ArrayList<String> = ArrayList<String>()

    public init() {}

    public func add(code: Int64, body: String, status: String): Unit {
        let step = QdrantHttpStep()
        step.code = code
        step.body = body
        step.status = status
        this.steps.add(step)
    }

    public func addTransportFailure(kind: String): Unit {
        let step = QdrantHttpStep()
        step.status = if (kind == "timeout") { "timeout" } else { "transport_error" }
        step.transportClass = kind
        step.transportDiagnostic = kind
        this.steps.add(step)
    }

    public func execute(request: HttpExecutionRequest): HttpExecutionResponse {
        this.calls += 1
        this.methods.add(request.method)
        this.urls.add(request.url)
        this.bodies.add(request.body)
        this.contentTypes.add(request.contentType)
        for (header in request.headers) {
            this.headers.add(header)
        }
        var index = this.calls - 1
        if (index >= this.steps.size) {
            index = this.steps.size - 1
        }
        let response = HttpExecutionResponse()
        if (index < 0 || this.steps.size == 0) {
            response.statusCode = 500
            response.status = "http_500"
            return response
        }
        let step = this.steps[index]
        response.statusCode = step.code
        response.body = step.body
        response.contentType = step.contentType
        response.status = step.status
        response.transportErrorClass = step.transportClass
        response.transportDiagnostic = step.transportDiagnostic
        response
    }

    public func get(request: HttpExecutionRequest): HttpExecutionResponse {
        this.execute(request)
    }
}

@Test
public class CkbQdrantVectorStoreTest {
    @TestCase
    public func qdrantRecreateCreatesCollectionAndUpsertsChinesePayload(): Unit {
        let executor = QdrantFakeExecutor()
        executor.add(404, "{\"status\":\"error\"}", "http_404")
        executor.add(200, "{\"status\":\"ok\",\"result\":true}", "http_200")
        executor.add(200, "{\"status\":\"ok\",\"result\":{\"status\":\"acknowledged\"}}", "http_200")
        let store = QdrantVectorStore("http://qdrant.test/", 3, "Cosine", executor: executor)
        let records = ArrayList<VectorRecord>()
        records.add(qdrantRecord("repo/doc#1", "仓颉 HTTP 客户端", "中文 payload chunk", "https://example.test/citation", "cangjie", ReviewStates.TRUSTED))

        let status = store.recreate("ckb active", records)

        @Expect(status.state, EmbeddingProviderState.READY)
        @Expect(executor.calls, 3)
        @Expect(executor.methods[0], "DELETE")
        @Expect(executor.methods[1], "PUT")
        @Expect(executor.methods[2], "PUT")
        @Expect(executor.urls[1], "http://qdrant.test/collections/ckb_active")
        @Expect(executor.urls[2], "http://qdrant.test/collections/ckb_active/points?wait=true")
        @Expect(executor.bodies[1].contains("\"size\":3"), true)
        @Expect(executor.bodies[1].contains("\"distance\":\"Cosine\""), true)
        @Expect(executor.bodies[2].contains("\"points\""), true)
        @Expect(executor.bodies[2].contains("\"ckb_id\":\"repo/doc#1\""), true)
        @Expect(executor.bodies[2].contains("仓颉 HTTP 客户端"), true)
        @Expect(executor.bodies[2].contains("\"repo\":\"cangjie\""), true)
        @Expect(executor.contentTypes[2], "application/json")
        @Expect(qdrantStablePointId("repo/doc#1"), qdrantStablePointId("repo/doc#1"))
        @Expect(qdrantStablePointId("repo/doc#1") != qdrantStablePointId("repo/doc#2"), true)
    }

    @TestCase
    public func qdrantSearchUsesFilterAndLocalSecondCheck(): Unit {
        let executor = QdrantFakeExecutor()
        executor.add(200, "{\"status\":\"ok\",\"result\":{\"points\":[{\"id\":1,\"score\":0.92,\"payload\":{\"ckb_id\":\"ok-id\",\"title\":\"匹配标题\",\"chunk\":\"匹配 chunk\",\"citation\":\"cite://ok\",\"sourceId\":\"src-ok\",\"sourceType\":\"repo\",\"repo\":\"cangjie\",\"path\":\"src/http.cj\",\"symbol\":\"HttpClient\",\"trustLevel\":\"official\",\"reviewState\":\"trusted\",\"knowledgeVersion\":\"active\"}},{\"id\":2,\"score\":0.99,\"payload\":{\"ckb_id\":\"bad-id\",\"title\":\"bad\",\"chunk\":\"bad chunk\",\"citation\":\"cite://bad\",\"sourceId\":\"src-bad\",\"sourceType\":\"repo\",\"repo\":\"other\",\"trustLevel\":\"official\",\"reviewState\":\"trusted\",\"knowledgeVersion\":\"active\"}}]}}", "http_200")
        let store = QdrantVectorStore("http://qdrant.test", 3, "Cosine", executor: executor)
        let filters = VectorSearchFilters()
        filters.repo = "cangjie"
        filters.sourceType = "repo"
        filters.trustLevel = "official"
        filters.reviewState = "trusted"
        let query = ArrayList<Float64>()
        query.add(1.0)
        query.add(0.0)
        query.add(0.0)

        let results = store.search("ckb_active", query, filters, 5)

        @Expect(results.size, 1)
        @Expect(results[0].id, "ok-id")
        @Expect(results[0].record.title, "匹配标题")
        @Expect(results[0].record.metadata.repo, "cangjie")
        @Expect(results[0].record.citation, "cite://ok")
        @Expect(executor.methods[0], "POST")
        @Expect(executor.urls[0], "http://qdrant.test/collections/ckb_active/points/query")
        @Expect(executor.bodies[0].contains("\"query\":[1.000000,0.000000,0.000000]") || executor.bodies[0].contains("\"query\":[1.0,0.0,0.0]"), true)
        @Expect(executor.bodies[0].contains("\"key\":\"repo\""), true)
        @Expect(executor.bodies[0].contains("\"key\":\"sourceType\""), true)
        @Expect(executor.bodies[0].contains("\"key\":\"trustLevel\""), true)
        @Expect(executor.bodies[0].contains("\"key\":\"reviewState\""), true)
    }

    @TestCase
    public func qdrantStatusAndClearMapMissingAndServerFailure(): Unit {
        let nestedStatusExecutor = QdrantFakeExecutor()
        nestedStatusExecutor.add(200, "{\"status\":\"ok\",\"result\":{\"status\":\"green\",\"points_count\":13,\"config\":{\"params\":{\"vectors\":{\"size\":1024,\"distance\":\"Cosine\"}}}}}", "http_200")
        let nestedStatusStore = QdrantVectorStore("http://qdrant.test", 1024, "Cosine", executor: nestedStatusExecutor)
        let nested = nestedStatusStore.status("ckb_active")

        @Expect(nested.state, EmbeddingProviderState.READY)
        @Expect(nested.count, 13)
        @Expect(nested.dimension, 1024)

        let statusExecutor = QdrantFakeExecutor()
        statusExecutor.add(404, "{\"status\":\"error\"}", "http_404")
        let missingStore = QdrantVectorStore("http://qdrant.test", 3, "Cosine", executor: statusExecutor)

        let missing = missingStore.status("ckb_missing")

        @Expect(missing.state, EmbeddingProviderState.DEGRADED)
        @Expect(missing.degradedReason, "collection_missing")

        let clearMissingExecutor = QdrantFakeExecutor()
        clearMissingExecutor.add(404, "{\"status\":\"error\"}", "http_404")
        let clearMissingStore = QdrantVectorStore("http://qdrant.test", 3, "Cosine", executor: clearMissingExecutor)
        let clearMissing = clearMissingStore.clear("ckb_missing")

        @Expect(clearMissing.state, EmbeddingProviderState.READY)
        @Expect(clearMissing.count, 0)

        let clearFailedExecutor = QdrantFakeExecutor()
        clearFailedExecutor.add(500, "{\"status\":\"error\"}", "http_500")
        let clearFailedStore = QdrantVectorStore("http://qdrant.test", 3, "Cosine", executor: clearFailedExecutor)
        let clearFailed = clearFailedStore.clear("ckb_active")

        @Expect(clearFailed.state, EmbeddingProviderState.DOWN)
        @Expect(clearFailed.degradedReason, "qdrant_clear_failed")
    }

    @TestCase
    public func qdrantMalformedJsonDimensionMismatchAndEmptyVectorDoNotThrow(): Unit {
        let statusExecutor = QdrantFakeExecutor()
        statusExecutor.add(200, "{", "http_200")
        let statusStore = QdrantVectorStore("http://qdrant.test", 3, "Cosine", executor: statusExecutor)
        let malformedStatus = statusStore.status("ckb_active")

        @Expect(malformedStatus.state, EmbeddingProviderState.DEGRADED)
        @Expect(malformedStatus.degradedReason, "malformed_json")

        let searchExecutor = QdrantFakeExecutor()
        searchExecutor.add(200, "{", "http_200")
        let searchStore = QdrantVectorStore("http://qdrant.test", 3, "Cosine", executor: searchExecutor)
        let query = ArrayList<Float64>()
        query.add(1.0)
        query.add(0.0)
        query.add(0.0)
        let search = searchStore.search("ckb_active", query, VectorSearchFilters(), 5)

        @Expect(search.size, 0)
        @Expect(searchStore.lastOperationStatus().state, EmbeddingProviderState.DEGRADED)
        @Expect(searchStore.lastOperationStatus().degradedReason, "malformed_json")

        let invalidExecutor = QdrantFakeExecutor()
        let invalidStore = QdrantVectorStore("http://qdrant.test", 3, "Cosine", executor: invalidExecutor)
        let dimensionMismatch = ArrayList<VectorRecord>()
        let wrong = qdrantRecord("wrong", "wrong", "wrong", "cite://wrong", "cangjie", ReviewStates.TRUSTED)
        wrong.vector.add(9.0)
        dimensionMismatch.add(wrong)
        let mismatchStatus = invalidStore.upsert("ckb_active", dimensionMismatch)

        let emptyVectors = ArrayList<VectorRecord>()
        let empty = qdrantRecord("empty", "empty", "empty", "cite://empty", "cangjie", ReviewStates.TRUSTED)
        empty.vector.clear()
        emptyVectors.add(empty)
        let emptyStatus = invalidStore.upsert("ckb_active", emptyVectors)

        @Expect(mismatchStatus.state, EmbeddingProviderState.DEGRADED)
        @Expect(mismatchStatus.degradedReason, "dimension_mismatch")
        @Expect(emptyStatus.state, EmbeddingProviderState.DEGRADED)
        @Expect(emptyStatus.degradedReason, "empty_vector")
        @Expect(invalidExecutor.calls, 0)
    }

    @TestCase
    public func qdrantEnsureReadyCollectionCreatesOnlyWhenMissing(): Unit {
        let executor = QdrantFakeExecutor()
        executor.add(404, "{\"status\":\"error\"}", "http_404")
        executor.add(200, "{\"status\":\"ok\",\"result\":true}", "http_200")
        let store = QdrantVectorStore("http://qdrant.test", 3, "Cosine", executor: executor)

        let status = store.ensureReadyCollection("ckb active")

        @Expect(status.state, EmbeddingProviderState.READY)
        @Expect(executor.calls, 2)
        @Expect(executor.methods[0], "GET")
        @Expect(executor.methods[1], "PUT")
        @Expect(executor.urls[1], "http://qdrant.test/collections/ckb_active")
        @Expect(executor.bodies[1].contains("\"size\":3"), true)
    }

    @TestCase
    public func qdrantUpsertBatchAppendsCacheWithoutDroppingPreviousBatch(): Unit {
        let executor = QdrantFakeExecutor()
        executor.add(200, "{\"status\":\"ok\",\"result\":{\"status\":\"acknowledged\"}}", "http_200")
        executor.add(200, "{\"status\":\"ok\",\"result\":{\"status\":\"acknowledged\"}}", "http_200")
        let store = QdrantVectorStore("http://qdrant.test", 3, "Cosine", executor: executor)
        let first = ArrayList<VectorRecord>()
        first.add(qdrantRecord("id-1", "标题 1", "chunk 1", "cite://1", "cangjie", ReviewStates.TRUSTED))
        let second = ArrayList<VectorRecord>()
        second.add(qdrantRecord("id-2", "标题 2", "chunk 2", "cite://2", "cangjie", ReviewStates.TRUSTED))

        let firstStatus = store.upsertBatch("ckb_active", first)
        let secondStatus = store.upsertBatch("ckb_active", second)
        let backup = store.backup("ckb_active")

        @Expect(firstStatus.count, 1)
        @Expect(secondStatus.count, 2)
        @Expect(backup.valid, true)
        @Expect(backup.records.size, 2)
        @Expect(executor.calls, 2)
    }

    @TestCase
    public func qdrantPointIdHashDoesNotOverflowForBaselineAndLongUnicodeIds(): Unit {
        let baseline = qdrantStablePointId("source-http-client")
        let longUnicode = qdrantStablePointId("Cangjie/community:docs/语言规范/很长很长很长很长的路径/README.md#source_analysis")

        @Expect(baseline != "", true)
        @Expect(longUnicode != "", true)
        @Expect(baseline != "0", true)
        @Expect(longUnicode != "0", true)
        @Expect(baseline, qdrantStablePointId("source-http-client"))
        @Expect(longUnicode, qdrantStablePointId("Cangjie/community:docs/语言规范/很长很长很长很长的路径/README.md#source_analysis"))
        @Expect(baseline != longUnicode, true)
    }
}

private func qdrantRecord(id: String, title: String, chunk: String, citation: String, repo: String, reviewState: String): VectorRecord {
    let record = VectorRecord()
    record.id = id
    record.title = title
    record.chunk = chunk
    record.citation = citation
    record.vector.add(0.1)
    record.vector.add(0.2)
    record.vector.add(0.3)
    record.metadata.sourceId = "src-${id}"
    record.metadata.sourceType = SourceTypes.REPO
    record.metadata.sourceUrl = "https://gitcode.com/${repo}/repo"
    record.metadata.repo = repo
    record.metadata.path = "src/main.cj"
    record.metadata.symbol = "HttpClient"
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = reviewState
    record.metadata.knowledgeVersion = "active"
    record
}
