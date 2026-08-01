package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

private class P3RuntimeHttpExecutor <: HttpRequestExecutor {
    public let requests = ArrayList<HttpExecutionRequest>()
    public var response: HttpExecutionResponse = HttpExecutionResponse()
    public func execute(request: HttpExecutionRequest): HttpExecutionResponse {
        this.requests.add(request); this.response
    }
    public func get(request: HttpExecutionRequest): HttpExecutionResponse {
        this.execute(request)
    }
}

private class P3RuntimeProcessExecutor <: CkbRetrievalParityProcessExecutor {
    public var calls: Int64 = 0
    public var response: CkbRetrievalParityProcessResponse =
        CkbRetrievalParityProcessResponse()
    public func execute(spec: CkbMcpStdioCommandSpec,
        request: Array<UInt8>): CkbRetrievalParityProcessResponse {
        this.calls += 1; this.response
    }
}

@Test
public class CkbReproRuntimeCompositionTest {
    @TestCase
    public func p3RuntimeRedQdrantExecutorPreservesBinaryAndBoundsBody(): Unit {
        let http = P3RuntimeHttpExecutor()
        http.response.statusCode = 200
        http.response.status = "http_200"
        http.response.contentType = "application/octet-stream"
        http.response.bodyBytes = [0x00, 0xff, 0x43, 0x4b, 0x42]
        let executor = CkbProductionQdrantSnapshotExecutor(
            "http://127.0.0.1:6333", http, maxResponseBytes: 8)
        let request = CkbQdrantSnapshotRequest()
        request.method = "GET"
        request.path = "/collections/portable/snapshots/x.snapshot"
        let response = executor.execute(request)
        @Expect(response.statusCode, 200)
        @Expect(response.bodyBytes, [0x00, 0xff, 0x43, 0x4b, 0x42])
        @Expect(http.requests.size, 1)
        @Expect(http.requests[0].url,
            "http://127.0.0.1:6333/collections/portable/snapshots/x.snapshot")

        http.response.bodyBytes = Array<UInt8>(9, repeat: 0x41)
        let bounded = executor.execute(request)
        @Expect(bounded.statusCode, 0)
        @Expect(bounded.diagnostic, "qdrant_snapshot_response_too_large")
    }

    @TestCase
    public func p3RuntimeRedCommandFileIsVersionedArgvAndRejectsShell(): Unit {
        let parsed = parseCkbMcpStdioCommandSpec(
            ("{\"schemaVersion\":\"ckb-mcp-stdio-command-v1\"," +
            "\"executable\":\"/opt/ckb/bin/ckb\",\"args\":[\"mcp-stdio\"]," +
            "\"environment\":[\"LANG=C.UTF-8\"],\"timeoutMillis\":10000}").toArray())
        @Expect(parsed[0].ok, true)
        @Expect(parsed[1].executable, "/opt/ckb/bin/ckb")
        @Expect(parsed[1].args.size, 1)
        @Expect(parsed[1].args[0], "mcp-stdio")
        @Expect(parseCkbMcpStdioCommandSpec([0xff, 0xfe])[0].diagnostic,
            "invalid_response_encoding")
        @Expect(parseCkbMcpStdioCommandSpec(
            "{\"schemaVersion\":\"ckb-mcp-stdio-command-v1\",\"executable\":\"/bin/sh\",\"args\":[\"-c\",\"echo pwned\"],\"environment\":[],\"timeoutMillis\":10000}".toArray())[0].diagnostic,
            "mcp_stdio_command_forbidden")
    }

    @TestCase
    public func p3RuntimeRedParityRejectsHumanEvalBeforeTransport(): Unit {
        let http = P3RuntimeHttpExecutor()
        let process = P3RuntimeProcessExecutor()
        let spec = CkbMcpStdioCommandSpec()
        spec.schemaVersion = "ckb-mcp-stdio-command-v1"
        spec.executable = "/opt/ckb/bin/ckb"
        spec.args.add("mcp-stdio")
        spec.timeoutMillis = 10000
        let backend = CkbProductionRetrievalParityBackend(
            "http://127.0.0.1:8080", spec,
            "http://127.0.0.1:8081/mcp", http, process)
        let result = backend.query("rest", "HumanEval case 145 solution")
        @Expect(result.ok, false)
        @Expect(result.diagnostic, "retrieval_parity_query_forbidden")
        @Expect(http.requests.size, 0)
        @Expect(process.calls, 0)
    }
}
