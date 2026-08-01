package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

private class P3FakeVectorBuildBackend <: CkbPortableVectorBuildBackend {
    public var existing: Bool = false
    public var failRebuild: Bool = false
    public var count: Int64 = 7978
    public var dimension: Int64 = 1024
    public var distance: String = "Cosine"
    public var machinePathCount: Int64 = 0
    public var created: Int64 = 0
    public var deleted: Int64 = 0
    public init() {}
    public func collectionExists(collection: String): Bool { this.existing }
    public func createEmpty(collection: String, dimension: Int64,
        distance: String): CkbReproContractResult {
        this.created += 1
        let out = CkbReproContractResult()
        out.ok = true; out.diagnostic = "ok"; out
    }
    public func stagedRebuild(collection: String):
        CkbPortableVectorBuildEvidence {
        let out = CkbPortableVectorBuildEvidence()
        out.ready = !this.failRebuild
        out.diagnostic = if (this.failRebuild) {
            "staged_rebuild_failed"
        } else { "ok" }
        out.collection = collection
        out.count = this.count
        out.dimension = this.dimension
        out.distance = this.distance
        out.payloadCanonicalHash = p3VectorHash("payload")
        out.machinePathCount = this.machinePathCount
        out
    }
    public func deleteCollection(collection: String): Unit {
        this.deleted += 1
    }
}

private class P3VectorSnapshotExecutor <: CkbQdrantSnapshotExecutor {
    public var snapshotBytes: Array<UInt8> = [0x50, 0x33, 0xff, 0x00]
    public var restored: Bool = false
    public init() {}
    public func execute(request: CkbQdrantSnapshotRequest):
        CkbQdrantSnapshotResponse {
        let out = CkbQdrantSnapshotResponse()
        if (request.method == "POST" && request.path.endsWith("/snapshots")) {
            out.statusCode = 200
            out.bodyBytes =
                "{\"result\":{\"name\":\"portable.snapshot\"}}".toArray()
        } else if (request.method == "GET" &&
            request.path.contains("/snapshots/portable.snapshot")) {
            out.statusCode = 200
            out.bodyBytes = this.snapshotBytes.clone()
        } else if (request.method == "GET") {
            out.statusCode = 404
        } else if (request.method == "PUT") {
            this.restored = request.bodyBytes == this.snapshotBytes
            out.statusCode = 200
            out.bodyBytes = "{\"status\":\"ok\"}".toArray()
        }
        out
    }
}

@Test
public class CkbPortableVectorBuildTest {
    @TestCase
    public func p3Pos02LockedLogicalCandidateBuildsReferenceVectors(): Unit {
        let backend = P3FakeVectorBuildBackend()
        let result = buildCkbPortableReferenceVectors(
            p3VectorOptions(), p3BuildProof(), p3Environment(), backend)
        @Expect(result.ready, true)
        @Expect(result.proof.count, 7978)
        @Expect(result.proof.dimension, 1024)
        @Expect(result.proof.distance, "Cosine")
        @Expect(result.proof.vectorProofHash.startsWith("sha256:"), true)
        @Expect(backend.created, 1)
        @Expect(backend.deleted, 0)

        let executor = P3VectorSnapshotExecutor()
        let identity = CkbQdrantSnapshotIdentity()
        identity.collection = result.proof.collection
        identity.logicalManifestHash = p3VectorHash("logical")
        identity.vectorProofHash = result.proof.vectorProofHash
        let created = createCkbQdrantSnapshot(identity, executor)
        @Expect(created.ok, true)
        let downloaded = downloadCkbQdrantSnapshot(
            identity, created.snapshotName, executor)
        @Expect(downloaded.ok, true)
        let manifest = CkbQdrantSnapshotManifest()
        manifest.schemaVersion = "ckb-qdrant-snapshot-v1"
        manifest.imageDigest = result.proof.qdrantImageDigest
        manifest.qdrantMinorVersion = "1.14"
        manifest.collection = result.proof.collection
        manifest.distance = result.proof.distance
        manifest.dimension = result.proof.dimension
        manifest.points = result.proof.count
        manifest.snapshotSha256 = downloaded.sha256
        manifest.logicalManifestHash = identity.logicalManifestHash
        manifest.vectorProofHash = identity.vectorProofHash
        manifest.payloadCanonicalHash = result.proof.payloadCanonicalHash
        @Expect(buildCkbQdrantSnapshotManifest(manifest).ok, true)
        @Expect(restoreCkbQdrantSnapshot(
            "portable-second", downloaded.bytes, manifest,
            executor).ok, true)
        @Expect(executor.restored, true)
    }

    @TestCase
    public func p3Neg02OldNonemptyWrongIdentityAndFailureAreCleaned(): Unit {
        let backend = P3FakeVectorBuildBackend()
        backend.existing = true
        @Expect(buildCkbPortableReferenceVectors(
            p3VectorOptions(), p3BuildProof(), p3Environment(),
            backend).diagnostic, "portable_vector_collection_exists")
        @Expect(backend.created, 0)

        backend.existing = false
        let wrongEmbedding = p3Environment()
        wrongEmbedding.embeddingDimension = 1023
        @Expect(buildCkbPortableReferenceVectors(
            p3VectorOptions(), p3BuildProof(), wrongEmbedding,
            backend).diagnostic, "portable_vector_environment_invalid")

        let wrongProof = p3BuildProof()
        wrongProof.preservationHash = p3VectorHash("other")
        @Expect(buildCkbPortableReferenceVectors(
            p3VectorOptions(), wrongProof, p3Environment(),
            backend).diagnostic, "portable_vector_p4_proof_mismatch")
        let wrongCandidate = p3BuildProof()
        wrongCandidate.candidateVersion = "portable-candidate-a"
        @Expect(buildCkbPortableReferenceVectors(
            p3VectorOptions(), wrongCandidate, p3Environment(),
            backend).diagnostic, "portable_vector_p4_proof_mismatch")

        backend.count = 7977
        @Expect(buildCkbPortableReferenceVectors(
            p3VectorOptions(), p3BuildProof(), p3Environment(),
            backend).diagnostic, "portable_vector_count_mismatch")
        @Expect(backend.deleted, 1)
        backend.count = 7978
        backend.machinePathCount = 1
        @Expect(buildCkbPortableReferenceVectors(
            p3VectorOptions(), p3BuildProof(), p3Environment(),
            backend).diagnostic, "portable_vector_payload_path_finding")
        @Expect(backend.deleted, 2)
        backend.machinePathCount = 0
        backend.failRebuild = true
        @Expect(buildCkbPortableReferenceVectors(
            p3VectorOptions(), p3BuildProof(), p3Environment(),
            backend).diagnostic, "staged_rebuild_failed")
        @Expect(backend.deleted, 3)
    }

    @TestCase
    public func p3Bnd01RuntimeMustBeExactlyMissingVectorState(): Unit {
        for (state in ["READY", "DOWN", "degraded"]) {
            let options = p3VectorOptions()
            options.runtimeVectorState = state
            @Expect(validateCkbPortableVectorBuildInputs(
                options, p3BuildProof(), p3Environment()).ok, false)
        }
        let reason = p3VectorOptions()
        reason.runtimeVectorDegradedReason = "other"
        @Expect(validateCkbPortableVectorBuildInputs(
            reason, p3BuildProof(), p3Environment()).diagnostic,
            "portable_vector_runtime_state_invalid")
        let count = p3VectorOptions()
        count.runtimeVectorCount = 1
        @Expect(validateCkbPortableVectorBuildInputs(
            count, p3BuildProof(), p3Environment()).diagnostic,
            "portable_vector_runtime_state_invalid")
    }

    @TestCase
    public func p3Reg01CollectionIdentityIsDeterministicAndBoundToProof(): Unit {
        let first = p3VectorOptions()
        let second = p3VectorOptions()
        @Expect(ckbPortableVectorCollectionName(first),
            ckbPortableVectorCollectionName(second))
        second.p4PortableProofHash = p3VectorHash("different")
        @Expect(ckbPortableVectorCollectionName(first) ==
            ckbPortableVectorCollectionName(second), false)
    }
}

private func p3VectorOptions(): CkbPortableVectorBuildOptions {
    let value = CkbPortableVectorBuildOptions()
    value.candidateVersion = "portable-v1"
    value.p4PortableProofHash = p3VectorHash("p4")
    value.runtimeVectorState = "DEGRADED"
    value.runtimeVectorDegradedReason = "vector_snapshot_missing"
    value.runtimeVectorCount = 0
    value.distance = "Cosine"
    value
}

private func p3BuildProof(): CkbReproBuildProof {
    let value = CkbReproBuildProof()
    value.logicalReady = true
    value.diagnostic = "ok"
    value.vectorState = "DEGRADED"
    value.vectorCount = 0
    value.candidateVersion = "portable-v1"
    value.preservationHash = p3VectorHash("p4")
    value
}

private func p3Environment(): CkbReproEnvironmentLock {
    let value = CkbReproEnvironmentLock()
    value.schemaVersion = "ckb-repro-environment-v1"
    value.identityStatus = "frozen"
    value.qdrantImageDigest = p3VectorHash("image")
    value.embeddingProvider = "ollama"
    value.embeddingModel = "qwen3-embedding"
    value.embeddingDimension = 1024
    value
}

private func p3VectorHash(value: String): String {
    benchmarkGapSha256(value)
}
