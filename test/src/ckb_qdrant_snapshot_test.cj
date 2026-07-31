package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{File, Path}
import std.unittest.*
import std.unittest.testmacro.*

private class P3FakeSnapshotExecutor <: CkbQdrantSnapshotExecutor {
    public var requests: ArrayList<CkbQdrantSnapshotRequest> =
        ArrayList<CkbQdrantSnapshotRequest>()
    public var existingTarget: Bool = false
    public var failRestore: Bool = false
    public var snapshotBytes: Array<UInt8> = [0xff, 0x00, 0xfe, 0x41]
    public init() {}

    public func execute(request: CkbQdrantSnapshotRequest):
        CkbQdrantSnapshotResponse {
        this.requests.add(request)
        let out = CkbQdrantSnapshotResponse()
        if (request.method == "GET" &&
            request.path == "/collections/target") {
            out.statusCode = if (this.existingTarget) { 200 } else { 404 }
            out.bodyBytes = "{\"result\":{\"status\":\"green\"}}".toArray()
        } else if (request.path.endsWith("/snapshots") &&
            request.method == "POST") {
            out.statusCode = 200
            out.bodyBytes =
                "{\"result\":{\"name\":\"portable.snapshot\"}}".toArray()
        } else if (request.method == "GET" &&
            request.path.contains("/snapshots/portable.snapshot")) {
            out.statusCode = 200
            out.bodyBytes = this.snapshotBytes.clone()
        } else if (request.method == "PUT" &&
            request.path.contains("/snapshots/upload")) {
            out.statusCode = if (this.failRestore) { 500 } else { 200 }
            out.bodyBytes = "{\"status\":\"ok\"}".toArray()
        } else {
            out.statusCode = 200
            out.bodyBytes = "{\"status\":\"ok\"}".toArray()
        }
        out
    }
}

@Test
public class CkbQdrantSnapshotTest {
    @TestCase
    public func p3Ut01FakeCreateDownloadAndManifestRoundTrip(): Unit {
        let executor = P3FakeSnapshotExecutor()
        let identity = p3Identity()
        let created = createCkbQdrantSnapshot(identity, executor)
        @Expect(created.ok, true)
        @Expect(created.snapshotName, "portable.snapshot")
        @Expect(executor.requests[0].method, "POST")
        @Expect(executor.requests[0].path,
            "/collections/portable-v1/snapshots")
        let downloaded = downloadCkbQdrantSnapshot(
            identity, created.snapshotName, executor)
        @Expect(downloaded.ok, true)
        @Expect(downloaded.bytes, executor.snapshotBytes)
        @Expect(executor.requests[1].method, "GET")
        let parsedStatus = parseCkbQdrantRestoredStatus(
            ("{\"result\":{\"status\":\"green\",\"points_count\":7978," +
            "\"config\":{\"params\":{\"vectors\":{\"size\":1024," +
            "\"distance\":\"Cosine\"}}}}}").toArray(),
            "portable-v1", p3Hash("payload"))
        @Expect(parsedStatus[0].ok, true)
        @Expect(parsedStatus[1].state, "green")
        @Expect(parsedStatus[1].count, 7978)
        @Expect(parsedStatus[1].dimension, 1024)
        let manifest = p3Manifest(downloaded.sha256)
        let built = buildCkbQdrantSnapshotManifest(manifest)
        @Expect(built.ok, true)
        let parsed = parseCkbQdrantSnapshotManifest(
            built.canonicalJson.toArray())
        @Expect(parsed[0].ok, true)
        @Expect(validateCkbQdrantSnapshotManifest(parsed[1]).ok, true)
        @Expect(renderCkbQdrantSnapshotManifest(parsed[1]),
            built.canonicalJson)
    }

    @TestCase
    public func p3Bnd01CountsDimensionsUnicodeAndBinaryAreFailClosed(): Unit {
        let valid = p3Manifest(p3Hash("snapshot"))
        for (count in [Int64(7977), Int64(7979)]) {
            valid.points = count
            @Expect(buildCkbQdrantSnapshotManifest(valid).diagnostic,
                "qdrant_snapshot_points_mismatch")
        }
        valid.points = 7978
        for (dimension in [Int64(0), Int64(1023), Int64(1025)]) {
            valid.dimension = dimension
            @Expect(buildCkbQdrantSnapshotManifest(valid).diagnostic,
                "qdrant_snapshot_dimension_mismatch")
        }
        valid.dimension = 1024
        valid.payloadCanonicalHash = p3Hash("仓颉🙂")
        @Expect(buildCkbQdrantSnapshotManifest(valid).ok, true)
        @Expect(parseCkbQdrantSnapshotManifest([0xff, 0xfe])[0].diagnostic,
            "invalid_response_encoding")
        @Expect(parseCkbQdrantRestoredStatus(
            [0xff, 0xfe], "portable-v1",
            p3Hash("payload"))[0].diagnostic,
            "invalid_response_encoding")
        let executor = P3FakeSnapshotExecutor()
        let binary = downloadCkbQdrantSnapshot(
            p3Identity(), "portable.snapshot", executor)
        @Expect(binary.ok, true)
        let expected: Array<UInt8> = [0xff, 0x00, 0xfe, 0x41]
        @Expect(binary.bytes, expected)
        @Expect(downloadCkbQdrantSnapshot(
            p3Identity(), "portable.snapshot?delete=true",
            executor).diagnostic, "qdrant_snapshot_identity_invalid")
    }

    @TestCase
    public func p3Pos01RestoreAndVerifyBindingWithFakeQdrant(): Unit {
        let executor = P3FakeSnapshotExecutor()
        let bytes: Array<UInt8> = [0xff, 0x00, 0xfe, 0x41]
        let manifest = p3Manifest(ckbQdrantSnapshotBytesHash(bytes))
        @Expect(buildCkbQdrantSnapshotManifest(manifest).ok, true)
        let restored = restoreCkbQdrantSnapshot(
            "target", bytes, manifest, executor)
        @Expect(restored.ok, true)
        @Expect(executor.requests[0].method, "GET")
        @Expect(executor.requests[1].method, "PUT")
        @Expect(executor.requests[1].bodyBytes, bytes)
        let status = p3Status("target")
        let verified = verifyRestoredCkbQdrantSnapshot(
            status, manifest, p3LogicalManifest(), p3PathInput(),
            p3PathContext())
        @Expect(verified.ok, true)
        @Expect(verified.ready, true)
    }

    @TestCase
    public func p3Neg01TamperExistingTargetVersionAndEncodingFailClosed(): Unit {
        let executor = P3FakeSnapshotExecutor()
        let manifest = p3Manifest(p3Hash("snapshot"))
        @Expect(buildCkbQdrantSnapshotManifest(manifest).ok, true)
        @Expect(restoreCkbQdrantSnapshot(
            "target", [1, 2, 3], manifest, executor).diagnostic,
            "qdrant_snapshot_hash_mismatch")
        executor.existingTarget = true
        @Expect(restoreCkbQdrantSnapshot(
            "target", "snapshot".toArray(), manifest, executor).diagnostic,
            "qdrant_snapshot_target_exists")
        let minor = p3Manifest(p3Hash("snapshot"))
        minor.qdrantMinorVersion = "1.15"
        @Expect(buildCkbQdrantSnapshotManifest(minor).diagnostic,
            "qdrant_snapshot_minor_version_mismatch")
        @Expect(parseCkbQdrantSnapshotManifest(
            "{\"schemaVersion\":".toArray())[0].diagnostic,
            "qdrant_snapshot_field_contract_invalid")
    }

    @TestCase
    public func p3Reg01PayloadHashLogicalBindingAndHistoricalStatusStayExact(): Unit {
        let manifest = p3Manifest(p3Hash("snapshot"))
        @Expect(buildCkbQdrantSnapshotManifest(manifest).ok, true)
        let wrongPayload = p3Status("target")
        wrongPayload.payloadCanonicalHash = p3Hash("wrong")
        @Expect(verifyRestoredCkbQdrantSnapshot(
            wrongPayload, manifest, p3LogicalManifest(), p3PathInput(),
            p3PathContext()).diagnostic, "qdrant_payload_hash_mismatch")
        let wrongLogical = p3LogicalManifest()
        wrongLogical.manifestHash = p3Hash("wrong")
        @Expect(verifyRestoredCkbQdrantSnapshot(
            p3Status("target"), manifest, wrongLogical, p3PathInput(),
            p3PathContext()).diagnostic, "qdrant_logical_manifest_mismatch")
        let releaseLogical = p3ReleaseLogicalManifest()
        let releaseVector = p3Manifest(p3Hash("release-snapshot"))
        releaseVector.logicalManifestHash = releaseLogical.manifestHash
        @Expect(buildCkbQdrantSnapshotManifest(releaseVector).ok, true)
        let release = buildCkbReleaseManifest(releaseLogical, releaseVector)
        @Expect(release.ok, true)
        @Expect(release.ready, true)
        @Expect(validateCkbReleaseManifest(
            release.manifest, releaseLogical, releaseVector).ok, true)
        release.manifest.qdrantSnapshotHash = p3Hash("substituted")
        @Expect(validateCkbReleaseManifest(
            release.manifest, releaseLogical, releaseVector).diagnostic,
            "release_manifest_vector_binding_mismatch")
        @Expect(p3MirrorEquivalent("../src/ckb_qdrant_snapshot.cj",
            "src/ckb_qdrant_snapshot.cj"), true)
        @Expect(p3MirrorEquivalent("../src/ckb_retrieval_parity.cj",
            "src/ckb_retrieval_parity.cj"), true)
        @Expect(p3MirrorEquivalent("../src/ckb_portable_vector_build.cj",
            "src/ckb_portable_vector_build.cj"), true)
    }
}

private func p3Identity(): CkbQdrantSnapshotIdentity {
    let value = CkbQdrantSnapshotIdentity()
    value.collection = "portable-v1"
    value.logicalManifestHash = p3Hash("logical")
    value.vectorProofHash = p3Hash("vector")
    value
}

private func p3Manifest(snapshotHash: String): CkbQdrantSnapshotManifest {
    let value = CkbQdrantSnapshotManifest()
    value.schemaVersion = "ckb-qdrant-snapshot-v1"
    value.imageDigest = p3Hash("image")
    value.qdrantMinorVersion = "1.14"
    value.collection = "portable-v1"
    value.distance = "Cosine"
    value.dimension = 1024
    value.points = 7978
    value.snapshotSha256 = snapshotHash
    value.logicalManifestHash = p3Hash("logical")
    value.vectorProofHash = p3Hash("vector")
    value.payloadCanonicalHash = p3Hash("payload")
    value
}

private func p3LogicalManifest(): CkbLogicalSnapshotManifest {
    let value = CkbLogicalSnapshotManifest()
    value.manifestHash = p3Hash("logical")
    value.p3VectorProofHash = p3Hash("vector")
    value.vectorCollection = "portable-v1"
    value.vectorCount = 7978
    value.vectorDimension = 1024
    value
}

private func p3ReleaseLogicalManifest(): CkbLogicalSnapshotManifest {
    let value = CkbLogicalSnapshotManifest()
    value.schemaVersion = "ckb-logical-snapshot-v1"
    value.sourceState =
        CkbLogicalSnapshotSourceStates.PORTABLE_VECTOR_ARTIFACT
    value.portableKnowledgeVersion = "portable-v1"
    value.p4PortableProofHash = p3Hash("p4")
    value.p3VectorProofHash = p3Hash("vector")
    value.vectorState = EmbeddingProviderState.READY
    value.vectorCollection = "portable-v1"
    value.vectorCount = 7978
    value.vectorDimension = 1024
    value.rawCount = 1
    value.normalizedCount = 1
    value.normalizedChecksum = p3Hash("normalized")
    value.indexCount = 1
    value.graphNodeCount = 0
    value.graphEdgeCount = 0
    value.activePointerHash = p3Hash("pointer")
    value.contaminationProofHash = p3Hash("contamination")
    let asset = CkbLogicalSnapshotAsset()
    asset.relativePath = "transactions/portable/COMMIT"
    asset.size = 1
    asset.sha256 = p3Hash("asset")
    value.assets.add(asset)
    let built = buildCkbLogicalSnapshotManifest(value)
    if (!built.ok) { return CkbLogicalSnapshotManifest() }
    value
}

private func p3Status(collection: String): CkbQdrantRestoredStatus {
    let value = CkbQdrantRestoredStatus()
    value.state = "green"
    value.collection = collection
    value.count = 7978
    value.dimension = 1024
    value.distance = "Cosine"
    value.payloadCanonicalHash = p3Hash("payload")
    value
}

private func p3PathInput(): CkbStudentVisiblePathInput {
    CkbStudentVisiblePathInput()
}

private func p3PathContext(): CkbPortablePathContext {
    CkbPortablePathContext()
}

private func p3Hash(value: String): String {
    benchmarkGapSha256(value)
}

private func p3MirrorEquivalent(sourcePath: String,
    mirrorPath: String): Bool {
    let source = String.fromUtf8(File.readFrom(Path(sourcePath))).
        replace("package cangjie_community_knowledge_base\n",
            "package cangjie_community_knowledge_base_test\n")
    source == String.fromUtf8(File.readFrom(Path(mirrorPath)))
}
