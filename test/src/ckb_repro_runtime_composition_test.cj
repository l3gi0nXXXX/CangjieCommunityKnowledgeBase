package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, OpenMode, Path, canonicalize, exists, remove, rename}
import std.process.launch
import std.time.DateTime
import std.unittest.*
import std.unittest.testmacro.*
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*
import stdx.net.http.*

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
    public var code: Int64 = 200
    public var declaredLength: Int64 = -1
    public var readCalls: Int64 = 0
    public init(size: Int64) { this.remaining = size }
    public func statusCode(): Int64 { this.code }
    public func contentLength(): Int64 { this.declaredLength }
    public func read(buffer: Array<UInt8>): Int64 {
        this.readCalls += 1
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

private func p3RuntimeRoot(suffix: String): Path {
    canonicalize(Path("/tmp")).join(
        "ckb-p3-${suffix}-${DateTime.now().toUnixTimeStamp()}-${suffix.hashCode()}")
}

private func p3RuntimeFileHash(path: Path): String {
    let digest = SHA256()
    try (file = File(path, OpenMode.Read)) {
        let buffer = Array<UInt8>(173, repeat: UInt8(0))
        while (true) {
            let count = file.read(buffer)
            if (count == 0) { break }
            digest.write(if (count == buffer.size) { buffer }
                else { buffer[0..count].clone() })
        }
    }
    let out = StringBuilder()
    let digits = "0123456789abcdef".toRuneArray()
    for (byte in digest.finish()) {
        for (nibble in [byte / UInt8(16), byte % UInt8(16)]) {
            out.append(digits[Int64(nibble)])
        }
    }
    "sha256:${out.toString()}"
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

private class P3RuntimeParityBackend <: CkbRetrievalParityBackend {
    public var calls: Int64 = 0
    public func query(transport: String, query: String):
        CkbRetrievalParityResponse {
        this.calls += 1; CkbRetrievalParityResponse()
    }
}

private class P3RuntimeSnapshotControl <: CkbQdrantSnapshotExecutor {
    public var calls: Int64 = 0
    public func execute(request: CkbQdrantSnapshotRequest):
        CkbQdrantSnapshotResponse {
        this.calls += 1
        let out = CkbQdrantSnapshotResponse(); out.statusCode = 404; out
    }
}

private class P3RuntimeSnapshotFiles <: CkbQdrantSnapshotFileExecutor {
    public var uploadCalls: Int64 = 0
    public func download(request: CkbQdrantSnapshotRequest,
        targetPath: String, maxBytes: Int64): CkbQdrantSnapshotFileTransferResult {
        CkbQdrantSnapshotFileTransferResult()
    }
    public func upload(request: CkbQdrantSnapshotRequest, sourcePath: String,
        expectedSize: Int64, expectedSha256: String): CkbQdrantSnapshotResponse {
        this.uploadCalls += 1
        let out = CkbQdrantSnapshotResponse()
        out.statusCode = 200; out.diagnostic = "ok"; out
    }
}

private class P8RuntimeRestoreOperation <: CkbReproRestoreStageOperation {
    public var calls: Int64 = 0
    public var evidence: CkbReproStageEvidence = CkbReproStageEvidence()
    public func execute(options: CkbReproVerifyOptions): CkbReproStageEvidence {
        this.calls += 1; this.evidence
    }
}

private class P8RuntimeRebuildOperation <: CkbReproRebuildStageOperation {
    public var calls: Int64 = 0
    public var evidence: CkbReproStageEvidence = CkbReproStageEvidence()
    public func execute(options: CkbReproVerifyOptions): CkbReproStageEvidence {
        this.calls += 1; this.evidence
    }
}

private class P8RuntimeReferenceOperation <: CkbReproReferenceRunOperation {
    public var calls: Int64 = 0
    public func execute(options: CkbReproVerifyOptions):
        CkbReproReferenceRunEvidence {
        this.calls += 1; CkbReproReferenceRunEvidence()
    }
}

private class P8RuntimePublicOperation <: CkbReproPublicEvidenceOperation {
    public var calls: Int64 = 0
    public func execute(options: CkbReproVerifyOptions): CkbReproContractResult {
        this.calls += 1
        let out = CkbReproContractResult(); out.ok = true
        out.diagnostic = "ok"; out
    }
}

private class P8RuntimeDocumentationOperation <:
    CkbReproDocumentationOperation {
    public var calls: Int64 = 0
    public func execute(options: CkbReproVerifyOptions): CkbReproContractResult {
        this.calls += 1
        let out = CkbReproContractResult(); out.ok = true
        out.diagnostic = "ok"; out
    }
}

private class P8RuntimeCleanupProbe {
    var calls: Int64 = 0
    public init() {}
    func execute(options: CkbReproVerifyOptions): Bool {
        this.calls += 1
        true
    }
}

private class P3RuntimeUploadServerState {
    public var calls: Int64 = 0
    public init() {}
}

private func p3RuntimeUploadResponse(ctx: HttpContext,
    state: P3RuntimeUploadServerState, status: UInt16,
    response: Array<UInt8>): Unit {
    state.calls += 1
    let buffer = Array<UInt8>(128, repeat: UInt8(0))
    while (ctx.request.body.read(buffer) > 0) {}
    ctx.responseBuilder.status(status)
    ctx.responseBuilder.header("content-type", "application/json")
    ctx.responseBuilder.body(response)
}

private func p3RuntimeSnapshotManifest(hash: String): CkbQdrantSnapshotManifest {
    let out = CkbQdrantSnapshotManifest()
    out.schemaVersion = "ckb-qdrant-snapshot-v1"
    out.imageDigest = benchmarkGapSha256("image")
    out.qdrantMinorVersion = "1.14"; out.collection = "portable-v1"
    out.distance = "Cosine"; out.dimension = 1024; out.points = 7978
    out.snapshotSha256 = hash
    out.logicalManifestHash = benchmarkGapSha256("logical")
    out.vectorProofHash = benchmarkGapSha256("vector")
    out.payloadCanonicalHash = benchmarkGapSha256("payload")
    _ = buildCkbQdrantSnapshotManifest(out)
    out
}

@Test
public class CkbReproRuntimeCompositionTest {
    @TestCase
    public func p3RuntimeRedSnapshotStreamsToOwnedTempAndCleansFailure(): Unit {
        let root = p3RuntimeRoot("stream")
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
            @Expect(result.sha256, p3RuntimeFileHash(target))

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
    public func p3RuntimeStreamRejectsOversizeAndResponseMismatch(): Unit {
        let root = p3RuntimeRoot("bounds")
        Directory.create(root)
        try {
            let declaredTooLarge = P3RuntimeDownloadStream(10)
            declaredTooLarge.declaredLength = 101
            let large = streamCkbQdrantSnapshotToOwnedTemp(
                declaredTooLarge, root.join("large.part").toString(), 100)
            @Expect(large.diagnostic, "qdrant_snapshot_stream_too_large")
            @Expect(declaredTooLarge.readCalls, 0)
            @Expect(exists(root.join("large.part")), false)

            let unknownTooLarge = P3RuntimeDownloadStream(101)
            let unknown = streamCkbQdrantSnapshotToOwnedTemp(
                unknownTooLarge, root.join("unknown.part").toString(), 100)
            @Expect(unknown.diagnostic, "qdrant_snapshot_stream_too_large")
            @Expect(exists(root.join("unknown.part")), false)

            let mismatch = P3RuntimeDownloadStream(9)
            mismatch.declaredLength = 10
            let mismatched = streamCkbQdrantSnapshotToOwnedTemp(
                mismatch, root.join("mismatch.part").toString(), 100)
            @Expect(mismatched.diagnostic,
                "qdrant_snapshot_stream_length_mismatch")
            @Expect(exists(root.join("mismatch.part")), false)

            let notFound = P3RuntimeDownloadStream(10)
            notFound.code = 404
            let response = streamCkbQdrantSnapshotToOwnedTemp(
                notFound, root.join("response.part").toString(), 100)
            @Expect(response.diagnostic,
                "qdrant_snapshot_stream_response_invalid")
            @Expect(notFound.readCalls, 0)
            @Expect(exists(root.join("response.part")), false)
        } finally { if (exists(root)) { remove(root, recursive: true) } }
    }

    @TestCase
    public func p3RuntimeStreamNeverOverwritesExistingOrSymlink(): Unit {
        let root = p3RuntimeRoot("exclusive")
        Directory.create(root)
        try {
            let existing = root.join("existing.part")
            File.writeTo(existing, "preserve".toArray())
            let first = P3RuntimeDownloadStream(10)
            @Expect(streamCkbQdrantSnapshotToOwnedTemp(first,
                existing.toString(), 100).diagnostic,
                "qdrant_snapshot_temp_path_invalid")
            @Expect(File.readFrom(existing), "preserve".toArray())
            @Expect(first.readCalls, 0)

            let directory = root.join("directory.part")
            Directory.create(directory)
            let second = P3RuntimeDownloadStream(10)
            @Expect(streamCkbQdrantSnapshotToOwnedTemp(second,
                directory.toString(), 100).diagnostic,
                "qdrant_snapshot_temp_path_invalid")
            @Expect(second.readCalls, 0)

            let link = root.join("link.part")
            @Expect(launch("/bin/ln", ["-s", existing.toString(),
                link.toString()]).wait(), 0)
            let third = P3RuntimeDownloadStream(10)
            @Expect(streamCkbQdrantSnapshotToOwnedTemp(third,
                link.toString(), 100).diagnostic,
                "qdrant_snapshot_temp_path_invalid")
            @Expect(File.readFrom(existing), "preserve".toArray())
            @Expect(third.readCalls, 0)
        } finally { if (exists(root)) { remove(root, recursive: true) } }
    }

    @TestCase
    public func p3RuntimeRestoreHashMismatchMakesZeroTransportCalls(): Unit {
        let root = p3RuntimeRoot("restore")
        Directory.create(root)
        try {
            let snapshot = root.join("snapshot.bin")
            File.writeTo(snapshot, "actual-snapshot".toArray())
            let control = P3RuntimeSnapshotControl()
            let files = P3RuntimeSnapshotFiles()
            let result = restoreCkbQdrantSnapshotFromFile("target",
                snapshot.toString(),
                p3RuntimeSnapshotManifest(benchmarkGapSha256("different")),
                control, files)
            @Expect(result.diagnostic, "qdrant_snapshot_hash_mismatch")
            @Expect(control.calls, 0)
            @Expect(files.uploadCalls, 0)
            @Expect(File.readFrom(snapshot), "actual-snapshot".toArray())
        } finally { if (exists(root)) { remove(root, recursive: true) } }
    }

    @TestCase
    public func p3RuntimeNativeUploadPinsOpenedFileAcrossPathSwap(): Unit {
        let root = p3RuntimeRoot("upload-race")
        Directory.create(root)
        let source = root.join("snapshot.bin")
        let held = root.join("opened-snapshot.bin")
        File.writeTo(source, "original-snapshot-content".toArray())
        let received = ArrayList<UInt8>()
        let server = ServerBuilder().addr("127.0.0.1").port(0).build()
        server.distributor.register("/upload", { ctx =>
            rename(source.toString(), to: held.toString(), overwrite: false)
            File.writeTo(source, "replacement-must-not-upload".toArray())
            let buffer = Array<UInt8>(128, repeat: UInt8(0))
            while (true) {
                let count = ctx.request.body.read(buffer)
                if (count <= 0) { break }
                received.add(all: buffer[0..count])
            }
            ctx.responseBuilder.status(UInt16(200))
            ctx.responseBuilder.header("content-type", "application/json")
            ctx.responseBuilder.body("{\"status\":\"ok\"}")
        })
        spawn { server.serve() }
        try {
            for (_ in 0..200) {
                if (server.port > UInt16(0)) { break }
                sleep(Duration.millisecond * 5)
            }
            @Expect(server.port > UInt16(0), true)
            let config = CkbNativeHttpTransportConfig("", false,
                "127.0.0.1", false, true, "", 5000)
            let executor = CkbNativeQdrantSnapshotFileExecutor(
                "http://127.0.0.1:${server.port}", config)
            let identity = ckbQdrantSnapshotFileIdentity(source.toString())
            @Expect(identity.ok, true)
            let request = CkbQdrantSnapshotRequest()
            request.method = "PUT"; request.path = "/upload"
            request.contentType = "application/octet-stream"
            let response = executor.upload(request, source.toString(),
                identity.size, identity.sha256)
            @Expect(received.toArray(), "original-snapshot-content".toArray())
            @Expect(response.diagnostic == "ok" ||
                response.diagnostic == "qdrant_snapshot_upload_identity_changed",
                true)
            @Expect(File.readFrom(source),
                "replacement-must-not-upload".toArray())
        } finally {
            server.close()
            if (exists(root)) { remove(root, recursive: true) }
        }
    }

    @TestCase
    public func p3RuntimeNativeUploadDiagnosticsAreBoundedAndDistinct(): Unit {
        let root = p3RuntimeRoot("upload-diagnostics")
        Directory.create(root)
        let source = root.join("snapshot.bin")
        File.writeTo(source, "snapshot".toArray())
        let state = P3RuntimeUploadServerState()
        let server = ServerBuilder().addr("127.0.0.1").port(0).build()
        server.distributor.register("/non2xx", { ctx =>
            p3RuntimeUploadResponse(ctx, state, UInt16(500), "{}".toArray())
        })
        server.distributor.register("/oversize", { ctx =>
            p3RuntimeUploadResponse(ctx, state, UInt16(200),
                Array<UInt8>(65537, repeat: UInt8(65)))
        })
        server.distributor.register("/invalid", { ctx =>
            p3RuntimeUploadResponse(ctx, state, UInt16(200), [0xff, 0xfe])
        })
        server.distributor.register("/malformed", { ctx =>
            p3RuntimeUploadResponse(ctx, state, UInt16(200), "{".toArray())
        })
        server.distributor.register("/generic-large", { ctx =>
            p3RuntimeUploadResponse(ctx, state, UInt16(200),
                Array<UInt8>(65537, repeat: UInt8(65)))
        })
        server.distributor.register("/generic-invalid", { ctx =>
            p3RuntimeUploadResponse(ctx, state, UInt16(200), [0xff, 0xfe])
        })
        spawn { server.serve() }
        try {
            for (_ in 0..200) {
                if (server.port > UInt16(0)) { break }
                sleep(Duration.millisecond * 5)
            }
            let config = CkbNativeHttpTransportConfig("", false,
                "127.0.0.1", false, true, "", 5000)
            let executor = CkbNativeQdrantSnapshotFileExecutor(
                "http://127.0.0.1:${server.port}", config)
            let identity = ckbQdrantSnapshotFileIdentity(source.toString())
            let request = CkbQdrantSnapshotRequest()
            request.method = "PUT"
            request.contentType = "application/octet-stream"
            request.path = "/non2xx"
            @Expect(executor.upload(request, source.toString(), identity.size,
                identity.sha256).diagnostic, "qdrant_snapshot_restore_failed")
            request.path = "/oversize"
            @Expect(executor.upload(request, source.toString(), identity.size,
                identity.sha256).diagnostic,
                "qdrant_snapshot_response_too_large")
            request.path = "/invalid"
            @Expect(executor.upload(request, source.toString(), identity.size,
                identity.sha256).diagnostic, "invalid_response_encoding")
            request.path = "/malformed"
            @Expect(executor.upload(request, source.toString(), identity.size,
                identity.sha256).diagnostic,
                "qdrant_snapshot_response_malformed_json")
            let before = state.calls
            @Expect(executor.upload(request, source.toString(), identity.size,
                benchmarkGapSha256("wrong")).diagnostic,
                "qdrant_snapshot_upload_identity_mismatch")
            @Expect(state.calls, before)

            let directory = root.join("directory")
            Directory.create(directory)
            @Expect(executor.upload(request, directory.toString(), 0,
                benchmarkGapSha256("")).diagnostic,
                "qdrant_snapshot_upload_identity_mismatch")
            let link = root.join("snapshot-link")
            @Expect(launch("/bin/ln", ["-s", source.toString(),
                link.toString()]).wait(), 0)
            @Expect(executor.upload(request, link.toString(), identity.size,
                identity.sha256).diagnostic,
                "qdrant_snapshot_upload_identity_mismatch")
            let fifo = root.join("snapshot.fifo")
            @Expect(launch("/usr/bin/mkfifo", [fifo.toString()]).wait(), 0)
            @Expect(executor.upload(request, fifo.toString(), 0,
                benchmarkGapSha256("")).diagnostic,
                "qdrant_snapshot_upload_identity_mismatch")
            @Expect(state.calls, before)

            let http = NativeHttpRequestExecutor(config)
            let bounded = HttpExecutionRequest()
            bounded.url = "http://127.0.0.1:${server.port}/generic-large"
            bounded.maxResponseBytes = 65536
            @Expect(http.get(bounded).transportErrorClass,
                "response_too_large")
            let invalid = HttpExecutionRequest()
            invalid.url = "http://127.0.0.1:${server.port}/generic-invalid"
            invalid.maxResponseBytes = 65536
            @Expect(http.get(invalid).transportErrorClass,
                "invalid_response_encoding")
            let compatible = HttpExecutionRequest()
            compatible.url =
                "http://127.0.0.1:${server.port}/generic-large"
            @Expect(compatible.maxResponseBytes, 0)
            @Expect(http.get(compatible).body.size, 65537)
        } finally {
            server.close()
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
    public func p3RuntimeParityParsesRestAndMcpToSameCanonicalHits(): Unit {
        let data = "{\"knowledgeVersion\":\"v1\",\"citations\":[{" +
            "\"sourceId\":\"std/string\",\"citation\":\"仓颉🙂 Rune\"," +
            "\"knowledgeVersion\":\"v1\"}]}"
        let rest = ckbParseRetrievalParityResponse(
            "{\"ok\":true,\"data\":${data}}".toArray(), "rest")
        let escaped = data.replace("\\", "\\\\").replace("\"", "\\\"")
        let mcp = ckbParseRetrievalParityResponse(
            ("{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{" +
            "\"content\":[{\"type\":\"text\",\"text\":\"${escaped}\"}]}}")
                .toArray(), "mcp")
        @Expect(rest.ok, true); @Expect(mcp.ok, true)
        @Expect(rest.knowledgeVersion, mcp.knowledgeVersion)
        @Expect(rest.hits[0].logicalId, mcp.hits[0].logicalId)
        @Expect(rest.hits[0].contentHash, mcp.hits[0].contentHash)
        @Expect(ckbParseRetrievalParityResponse(
            [0xff, 0xfe], "rest").diagnostic, "invalid_response_encoding")
        @Expect(ckbParseRetrievalParityResponse(
            "{".toArray(), "rest").diagnostic,
            "retrieval_parity_malformed_json")
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

    @TestCase
    public func p3RuntimeParityManifestRequiresExactReferenceQuery(): Unit {
        let backend = P3RuntimeParityBackend()
        let manifest = CkbRetrievalParityManifest()
        manifest.knowledgeVersion = "v1"
        manifest.logicalManifestHash = benchmarkGapSha256("logical")
        manifest.query = "如何遍历仓颉字符串中的字符？"
        manifest.canonicalResultHash = benchmarkGapSha256("result")
        for (transport in ["rest", "mcp_stdio", "mcp_http"]) {
            manifest.transports.add(transport)
        }
        @Expect(verifyCkbRetrievalParityManifest(
            manifest, backend).diagnostic,
            "retrieval_parity_manifest_invalid")
        @Expect(backend.calls, 0)
    }

    @TestCase
    public func p3RuntimeParityManifestParserIsCanonicalAndUtf8Safe(): Unit {
        let manifest = CkbRetrievalParityManifest()
        manifest.knowledgeVersion = "portable-知识🙂"
        manifest.logicalManifestHash = benchmarkGapSha256("logical")
        manifest.query = ckbRetrievalParityReferenceQuery()
        manifest.canonicalResultHash = benchmarkGapSha256("result")
        for (transport in ["rest", "mcp_stdio", "mcp_http"]) {
            manifest.transports.add(transport)
        }
        let canonical = renderCkbRetrievalParityManifest(manifest)
        let parsed = parseCkbRetrievalParityManifest(canonical.toArray())
        @Expect(parsed[0].ok, true)
        @Expect(parsed[1].knowledgeVersion, manifest.knowledgeVersion)
        @Expect(parseCkbRetrievalParityManifest(
            [0xff, 0xfe])[0].diagnostic, "invalid_response_encoding")
        @Expect(parseCkbRetrievalParityManifest(
            canonical.replace("\"rest\"", "\"other\"").toArray())[0]
            .diagnostic, "retrieval_parity_manifest_invalid")
    }

    @TestCase
    public func p3RuntimeNativeStdioUsesOneLineFrameAndCleansProcess(): Unit {
        let root = p3RuntimeRoot("stdio")
        Directory.create(root)
        let truncatedFile = root.join("truncated.json")
        let oversizedFile = root.join("oversized.json")
        File.writeTo(truncatedFile, "{}".toArray())
        File.writeTo(oversizedFile,
            Array<UInt8>(300000, repeat: UInt8(120)))
        try {
        let spec = CkbMcpStdioCommandSpec()
        spec.schemaVersion = "ckb-mcp-stdio-command-v1"
        spec.executable = "/bin/cat"; spec.timeoutMillis = 2000
        let request = "{\"jsonrpc\":\"2.0\",\"id\":1}".toArray()
        let response = CkbNativeRetrievalParityProcessExecutor()
            .execute(spec, request)
        @Expect(response.diagnostic, "ok")
        @Expect(response.exitCode, 0)
        @Expect(response.stdout,
            "{\"jsonrpc\":\"2.0\",\"id\":1}".toArray())
        @Expect(CkbNativeRetrievalParityProcessExecutor().execute(spec,
            "{}\n".toArray()).diagnostic,
            "mcp_stdio_request_frame_invalid")
        @Expect(CkbNativeRetrievalParityProcessExecutor().execute(spec,
            "{".toArray()).diagnostic,
            "mcp_stdio_request_malformed_json")

        let truncated = CkbMcpStdioCommandSpec()
        truncated.schemaVersion = "ckb-mcp-stdio-command-v1"
        truncated.executable = "/bin/cat"
        truncated.args.add(truncatedFile.toString())
        truncated.timeoutMillis = 2000
        @Expect(CkbNativeRetrievalParityProcessExecutor()
            .execute(truncated, request).diagnostic,
            "mcp_stdio_response_truncated")

        let timeout = CkbMcpStdioCommandSpec()
        timeout.schemaVersion = "ckb-mcp-stdio-command-v1"
        timeout.executable = "/bin/sleep"; timeout.args.add("2")
        timeout.timeoutMillis = 100
        @Expect(CkbNativeRetrievalParityProcessExecutor()
            .execute(timeout, request).diagnostic,
            "mcp_stdio_process_timeout")

        let oversized = CkbMcpStdioCommandSpec()
        oversized.schemaVersion = "ckb-mcp-stdio-command-v1"
        oversized.executable = "/bin/cat"
        oversized.args.add(oversizedFile.toString())
        oversized.timeoutMillis = 2000
        @Expect(CkbNativeRetrievalParityProcessExecutor()
            .execute(oversized, request).diagnostic,
            "mcp_stdio_response_too_large")
        } finally { if (exists(root)) { remove(root, recursive: true) } }
    }

    @TestCase
    public func p8RuntimeProductionExecutorsKeepRunnerOutOfRelease(): Unit {
        let restore = P8RuntimeRestoreOperation()
        let rebuild = P8RuntimeRebuildOperation()
        let reference = P8RuntimeReferenceOperation()
        let certification = CkbProductionRunCertificationExecutor(
            restore, rebuild, reference)
        let options = CkbReproVerifyOptions()
        _ = certification.restore(options)
        _ = certification.rebuild(options)
        _ = certification.runReference(options)
        @Expect(restore.calls, 1); @Expect(rebuild.calls, 1)
        @Expect(reference.calls, 1)

        let publicEvidence = P8RuntimePublicOperation()
        let documentation = P8RuntimeDocumentationOperation()
        let release = CkbProductionReleaseVerificationExecutor(
            restore, rebuild, publicEvidence, documentation)
        _ = release.restore(options); _ = release.rebuild(options)
        _ = release.verifyPublicEvidence(options)
        _ = release.verifyDocumentation(options)
        @Expect(restore.calls, 2); @Expect(rebuild.calls, 2)
        @Expect(publicEvidence.calls, 1); @Expect(documentation.calls, 1)
        @Expect(reference.calls, 1)
    }

    @TestCase
    public func p8OwnedCleanupRunsEvenWhenRebuildWasNeverReached(): Unit {
        let certificationCleanup = P8RuntimeCleanupProbe()
        let certification = CkbProductionRunCertificationExecutor(
            P8RuntimeRestoreOperation(), P8RuntimeRebuildOperation(),
            P8RuntimeReferenceOperation(), cleanupAction: {
                _: CkbReproVerifyOptions =>
                certificationCleanup.execute(CkbReproVerifyOptions())
            })
        @Expect(certification.cleanup(CkbReproVerifyOptions()), true)
        @Expect(certificationCleanup.calls, 1)

        let releaseCleanup = P8RuntimeCleanupProbe()
        let release = CkbProductionReleaseVerificationExecutor(
            P8RuntimeRestoreOperation(), P8RuntimeRebuildOperation(),
            P8RuntimePublicOperation(), P8RuntimeDocumentationOperation(),
            cleanupAction: { _: CkbReproVerifyOptions =>
                releaseCleanup.execute(CkbReproVerifyOptions())
            })
        @Expect(release.cleanup(CkbReproVerifyOptions()), true)
        @Expect(releaseCleanup.calls, 1)
    }

    @TestCase
    public func p8RuntimeSharedCompositionFailsBeforeSideEffects(): Unit {
        let invalid = CkbReproProductionCliComposition()
        let invalidResult = loadCkbReproP8SharedComposition(invalid, "/tmp")
        @Expect(invalidResult[0].diagnostic, "p8_composition_mode_invalid")

        let missing = CkbReproProductionCliComposition()
        missing.ok = true; missing.mode = "run-certify"
        let missingResult = loadCkbReproP8SharedComposition(missing, "/tmp")
        @Expect(missingResult[0].diagnostic, "p8_composition_asset_missing")

        let prepared = CkbReproProductionCliComposition()
        let shared = CkbReproP8SharedComposition()
        shared.environment.qdrantImageDigest = benchmarkGapSha256("expected")
        let transport = CkbP8OwnedLocalRuntimeAuthority()
        transport.qdrantImageId = benchmarkGapSha256("different")
        let stages = buildCkbReproP8ProductionStages(prepared, shared,
            CkbReproVerifyOptions(), transport, CkbReproBuildInputManifest(),
            CangjieEvalSupportSnapshot(), CangjieBenchmarkLeakageAuthority())
        @Expect(stages.ok, false)
        @Expect(stages.diagnostic, "p8_transport_environment_invalid")
    }

    @TestCase
    public func p8CompositionDiagnosticIsRuneSafeAndBounded(): Unit {
        let value = StringBuilder("\"\n\u{0001}\b\fAuthorization: secret ")
        for (_ in 0..200) { value.append("中🙂") }
        let safe = ckbReproP8SafeDiagnostic(value.toString())
        @Expect(safe.toRuneArray().size <= 160, true)
        @Expect(safe.contains("secret"), false)
        let failure = ckbReproP8CompositionFailure(value.toString(), true)
        let object = JsonValue.fromStr(failure.output).asObject()
        @Expect(object.get("ok").getOrThrow().asBool().getValue(), false)
        let diagnostic = object.get("diagnostic").getOrThrow()
            .asString().getValue()
        @Expect(diagnostic.toRuneArray().size <= 160, true)
        @Expect(diagnostic.contains("secret"), false)
    }

    @TestCase
    public func p8RuntimeFilesystemProbePinsRegularInputAndRejectsSymlink(): Unit {
        let root = p3RuntimeRoot("p8-probe")
        Directory.create(root)
        try {
            let input = root.join("输入🙂.json")
            File.writeTo(input, "{\"ok\":true}".toArray())
            let storeRoot = root.join("store")
            Directory.create(storeRoot)
            let probe = CkbFilesystemReproVerifyEnvironmentProbe(
                FileKnowledgeStore(storeRoot.toString()),
                CkbPortablePathContext(), "https://example.invalid/repo",
                benchmarkGapSha256("provider"), "GLM-5.2", { => 0 })
            let evidence = probe.inspectInput(input.toString())
            @Expect(evidence.ok, true); @Expect(evidence.regular, true)
            @Expect(evidence.noFollow, true); @Expect(evidence.stable, true)
            @Expect(evidence.size, 11)
            @Expect(evidence.sha256, p3RuntimeFileHash(input))

            let link = root.join("input-link")
            @Expect(launch("/bin/ln", ["-s", input.toString(),
                link.toString()]).wait(), 0)
            @Expect(probe.inspectInput(link.toString()).ok, false)
        } finally { if (exists(root)) { remove(root, recursive: true) } }
    }
}
