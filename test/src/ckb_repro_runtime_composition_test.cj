package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists, remove}
import std.time.DateTime
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

private class P3RuntimeDownloadStream <: CkbQdrantSnapshotDownloadStream {
    public var remaining: Int64
    public var failAfter: Int64 = -1
    public var readTotal: Int64 = 0
    public var maxRequested: Int64 = 0
    public var closed: Int64 = 0
    public init(size: Int64) { this.remaining = size }
    public func statusCode(): Int64 { 200 }
    public func contentLength(): Int64 { -1 }
    public func read(buffer: Array<UInt8>): Int64 {
        if (buffer.size > this.maxRequested) { this.maxRequested = buffer.size }
        if (this.failAfter >= 0 && this.readTotal >= this.failAfter) {
            throw Exception("token=secret /private/path")
        }
        if (this.remaining == 0) { return 0 }
        let count = if (this.remaining < buffer.size) {
            this.remaining
        } else { buffer.size }
        for (i in 0..count) { buffer[i] = UInt8((this.readTotal + i) % 251) }
        this.remaining -= count; this.readTotal += count; count
    }
    public func close(): Unit { this.closed += 1 }
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
    public func p3RuntimeRedSnapshotStreamsToOwnedTempAndCleansFailure(): Unit {
        let root = Path("/tmp/ckb-p3-stream-${DateTime.now().toUnixTimeStamp()}")
        Directory.create(root)
        try {
            let source = P3RuntimeDownloadStream(512 * 1024 + 17)
            let target = root.join("snapshot.part")
            let result = streamCkbQdrantSnapshotToOwnedTemp(
                source, target.toString(), 1024 * 1024)
            @Expect(result.ok, true)
            @Expect(result.size, 512 * 1024 + 17)
            @Expect(result.sha256.startsWith("sha256:"), true)
            @Expect(source.maxRequested <= 65536, true)
            @Expect(source.closed, 1)
            @Expect(exists(target), true)

            let failing = P3RuntimeDownloadStream(200000)
            failing.failAfter = 65536
            let failedTarget = root.join("failed.part")
            let failed = streamCkbQdrantSnapshotToOwnedTemp(
                failing, failedTarget.toString(), 1024 * 1024)
            @Expect(failed.ok, false)
            @Expect(failed.diagnostic, "qdrant_snapshot_stream_read_failed")
            @Expect(failing.closed, 1)
            @Expect(exists(failedTarget), false)
            @Expect(failed.diagnostic.contains("secret"), false)
            @Expect(failed.diagnostic.contains("/private"), false)
        } finally {
            if (exists(root)) { remove(root, recursive: true) }
        }
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
