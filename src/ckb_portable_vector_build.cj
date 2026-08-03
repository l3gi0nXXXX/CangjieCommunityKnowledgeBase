package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.sort.*

public func ckbReproReleaseRecordCount(): Int64 { 7817 }

public class CkbPortableVectorBuildOptions {
    public var candidateVersion: String = ""
    public var p4PortableProofHash: String = ""
    public var runtimeVectorState: String = ""
    public var runtimeVectorDegradedReason: String = ""
    public var runtimeVectorCount: Int64 = -1
    public var distance: String = "Cosine"
    public init() {}
}

public class CkbPortableVectorBuildEvidence {
    public var ready: Bool = false
    public var diagnostic: String = "not_built"
    public var collection: String = ""
    public var count: Int64 = 0
    public var dimension: Int64 = 0
    public var distance: String = ""
    public var payloadCanonicalHash: String = ""
    public var machinePathCount: Int64 = -1
    public init() {}
}

public interface CkbPortableVectorBuildBackend {
    func collectionExists(collection: String): Bool
    func createEmpty(collection: String, dimension: Int64,
        distance: String): CkbReproContractResult
    func stagedRebuild(collection: String): CkbPortableVectorBuildEvidence
    func deleteCollection(collection: String): Unit
}

public class CkbPortableVectorProductionBackend <: CkbPortableVectorBuildBackend {
    private let kb: KnowledgeBase
    private let store: FileKnowledgeStore
    private let vectorStore: VectorStore
    private let pathContext: CkbPortablePathContext
    private let deadlineAtMillis: Int64

    public init(embeddingProvider: EmbeddingProvider, store: FileKnowledgeStore,
        vectorStore: VectorStore, pathContext: CkbPortablePathContext,
        deadlineAtMillis!: Int64 = 0) {
        this.kb = KnowledgeBase(FakeClock(0), embeddingProvider, vectorStore,
            LocalGraphStore())
        this.store = store; this.vectorStore = vectorStore
        this.pathContext = pathContext; this.deadlineAtMillis = deadlineAtMillis
    }

    public func collectionExists(collection: String): Bool {
        // Only Qdrant's explicit missing status authorizes a create attempt.
        this.vectorStore.status(collection).degradedReason != "collection_missing"
    }

    public func createEmpty(collection: String, dimension: Int64,
        distance: String): CkbReproContractResult {
        let status = this.vectorStore.ensureReadyCollection(collection)
        if (status.state != EmbeddingProviderState.READY || status.count != 0 ||
            (status.dimension != 0 && status.dimension != dimension) ||
            (status.distance != "" &&
             status.distance.toAsciiLower() != distance.toAsciiLower())) {
            return ckbPortableVectorFailure("portable_vector_collection_create_failed")
        }
        ckbPortableVectorSuccess()
    }

    public func stagedRebuild(collection: String): CkbPortableVectorBuildEvidence {
        let evidence = CkbPortableVectorBuildEvidence()
        let basePointer = this.store.loadActiveSnapshotPointer()
        if (!basePointer.valid) {
            evidence.diagnostic = "portable_vector_candidate_pointer_invalid"
            return evidence
        }
        let basePointerHash = ckbActiveSnapshotPointerIdentityHash(basePointer)
        let sourceSnapshot = this.store.loadActiveSnapshot()
        if (!sourceSnapshot.valid || !this.kb.restoreActiveSnapshot(sourceSnapshot)) {
            evidence.diagnostic = "portable_vector_candidate_restore_failed"
            return evidence
        }
        // P3 builds vectors for the already frozen P4 active snapshot. The
        // generic rebuild entry may promote an unrelated lifecycle candidate.
        let built = this.kb.reconcileProductionVectorIndex(
            progressSink: NoopVectorBuildProgressSink(),
            targetVectorCollection: collection,
            deadlineAtMillis: this.deadlineAtMillis)
        if (!built.ok) {
            evidence.diagnostic = if (built.failedVersion == "") {
                "portable_vector_staged_rebuild_failed"
            } else { built.failedVersion }
            return evidence
        }
        let status = this.vectorStore.status(collection)
        if (status.state != EmbeddingProviderState.READY) {
            evidence.diagnostic = "portable_vector_collection_not_ready"
            return evidence
        }
        // Staged production builds intentionally do not retain 1024-dimensional
        // vectors in process memory. Reconstruct the canonical payload fields
        // from the exact active records that fed the successful staged build.
        let snapshot = this.store.loadActiveSnapshot()
        if (!snapshot.valid || snapshot.activeIndex.size != status.count) {
            evidence.diagnostic = "portable_vector_payload_evidence_unavailable"
            return evidence
        }
        let visible = CkbStudentVisiblePathInput()
        for (record in snapshot.activeIndex) { visible.activeRecords.add(record) }
        let scan = scanCkbStudentVisiblePaths(visible, this.pathContext)
        if (!scan.ready) {
            evidence.diagnostic = scan.diagnostic
            evidence.machinePathCount = scan.machinePathCount + scan.unmappedCount
            return evidence
        }
        evidence.collection = collection; evidence.count = status.count
        evidence.dimension = status.dimension; evidence.distance = status.distance
        evidence.machinePathCount = 0
        evidence.payloadCanonicalHash =
            ckbPortableVectorPayloadCanonicalHashFromNormalized(snapshot.activeIndex)
        try {
            this.kb.promoteVectorActiveCollection(collection)
            this.kb.persistActiveSnapshotUsingVectorRecords(this.store,
                ArrayList<VectorRecord>(), persistVectorFile: false,
                deadlineAtMillis: this.deadlineAtMillis,
                expectedBaseActivePointerHash: basePointerHash)
        } catch (_: Exception) {
            evidence.diagnostic = "portable_vector_candidate_binding_failed"
            return evidence
        }
        let binding = validateCkbPortableVectorCandidateBinding(
            this.store.loadActiveSnapshot(), this.store.loadMetadataStatus(),
            sourceSnapshot.activeVersion, collection, status.count,
            status.dimension)
        if (!binding.ok) {
            evidence.diagnostic = binding.diagnostic
            return evidence
        }
        evidence.ready = true; evidence.diagnostic = "ok"
        evidence
    }

    public func deleteCollection(collection: String): Unit {
        _ = this.vectorStore.deleteCollection(collection)
    }
}

public func validateCkbPortableVectorCandidateBinding(snapshot: ActiveSnapshot,
    metadata: StoreMetadataStatus, expectedVersion: String,
    collection: String, count: Int64, dimension: Int64): CkbReproContractResult {
    if (!snapshot.valid || !metadata.valid || collection == "" || count <= 0 ||
        dimension <= 0 || expectedVersion == "" ||
        snapshot.activeVersion != expectedVersion ||
        snapshot.activeVersion != metadata.activeVersion ||
        snapshot.vectorActiveCollection != collection ||
        metadata.vectorActiveCollection != collection ||
        metadata.vectorCollection != collection ||
        metadata.vectorState != EmbeddingProviderState.READY ||
        metadata.vectorIndexCount != count ||
        metadata.vectorDimension != dimension) {
        return ckbPortableVectorFailure(
            "portable_vector_candidate_binding_invalid")
    }
    ckbPortableVectorSuccess()
}

public func ckbPortableVectorPayloadCanonicalHash(
    records: ArrayList<VectorRecord>): String {
    let rows = ArrayList<String>()
    for (record in records) {
        let derived = record.metadata.derivedFrom.toArray(); sort(derived)
        var derivedText = ""
        for (value in derived) { derivedText += "${value.toArray().size}:${value}" }
        rows.add(ckbPortableVectorCanonicalFields([
            record.id, record.pointId, record.title, record.chunk,
            record.citation, record.metadata.path, record.metadata.sourceType,
            record.metadata.license, derivedText
        ]))
    }
    let ordered = rows.toArray(); sort(ordered)
    var body = "ckb-portable-vector-payload-v1|"
    for (row in ordered) { body += "${row.toArray().size}:${row}" }
    benchmarkGapSha256(body)
}

public func ckbPortableVectorPayloadCanonicalHashFromNormalized(
    records: ArrayList<NormalizedRecord>): String {
    let rows = ArrayList<String>()
    for (record in records) {
        let derived = record.metadata.derivedFrom.toArray(); sort(derived)
        var derivedText = ""
        for (value in derived) { derivedText += "${value.toArray().size}:${value}" }
        rows.add(ckbPortableVectorCanonicalFields([
            record.sourceId, ckbVectorPointId(record), record.title,
            record.chunk, record.citation, record.metadata.path,
            record.metadata.sourceType, record.metadata.license, derivedText
        ]))
    }
    let ordered = rows.toArray(); sort(ordered)
    var body = "ckb-portable-vector-payload-v1|"
    for (row in ordered) { body += "${row.toArray().size}:${row}" }
    benchmarkGapSha256(body)
}

private func ckbPortableVectorCanonicalFields(values: Array<String>): String {
    var out = ""
    for (value in values) { out += "${value.toArray().size}:${value}" }
    out
}

public class CkbPortableVectorProof {
    public var collection: String = ""
    public var candidateVersion: String = ""
    public var p4PortableProofHash: String = ""
    public var qdrantImageDigest: String = ""
    public var embeddingProvider: String = ""
    public var embeddingModel: String = ""
    public var count: Int64 = 0
    public var dimension: Int64 = 0
    public var distance: String = ""
    public var payloadCanonicalHash: String = ""
    public var vectorProofHash: String = ""
    public init() {}
}

public func ckbPortableVectorProofHash(proof: CkbPortableVectorProof): String {
    benchmarkGapSha256("ckb-portable-vector-proof-v1|" +
        ckbPortableVectorCanonicalFields([
            proof.collection, proof.candidateVersion,
            proof.p4PortableProofHash, proof.qdrantImageDigest,
            proof.embeddingProvider, proof.embeddingModel,
            proof.count.toString(), proof.dimension.toString(),
            proof.distance, proof.payloadCanonicalHash
        ]))
}

public class CkbPortableVectorBuildResult {
    public var ready: Bool = false
    public var diagnostic: String = "portable_vector_build_not_run"
    public var proof: CkbPortableVectorProof = CkbPortableVectorProof()
    public init() {}
}

public func validateCkbPortableVectorBuildInputs(
    options: CkbPortableVectorBuildOptions,
    p4Proof: CkbReproBuildProof,
    environment: CkbReproEnvironmentLock): CkbReproContractResult {
    if (options.runtimeVectorState != "DEGRADED" ||
        options.runtimeVectorDegradedReason != "vector_snapshot_missing" ||
        options.runtimeVectorCount != 0 ||
        !p4Proof.logicalReady || p4Proof.diagnostic != "ok" ||
        p4Proof.vectorState != "DEGRADED" || p4Proof.vectorCount != 0) {
        return ckbPortableVectorFailure(
            "portable_vector_runtime_state_invalid")
    }
    if (!ckbPortableVectorHashValid(options.p4PortableProofHash) ||
        p4Proof.preservationHash != options.p4PortableProofHash ||
        p4Proof.candidateVersion != options.candidateVersion) {
        return ckbPortableVectorFailure(
            "portable_vector_p4_proof_mismatch")
    }
    if (options.candidateVersion == "" ||
        options.candidateVersion.size > 80 ||
        options.distance.toAsciiLower() != "cosine") {
        return ckbPortableVectorFailure(
            "portable_vector_options_invalid")
    }
    if (environment.identityStatus != "frozen" ||
        !ckbPortableVectorHashValid(environment.qdrantImageDigest) ||
        environment.embeddingProvider == "" ||
        environment.embeddingModel == "" ||
        environment.embeddingDimension != 1024) {
        return ckbPortableVectorFailure(
            "portable_vector_environment_invalid")
    }
    ckbPortableVectorSuccess()
}

public func ckbPortableVectorCollectionName(
    options: CkbPortableVectorBuildOptions): String {
    let version = ckbPortableVectorSafeName(options.candidateVersion)
    let digest = options.p4PortableProofHash.replace("sha256:", "")
    if (version == "" || digest.size < 12) { return "" }
    "ckb-portable-${version}-${digest[0..12]}"
}

public func buildCkbPortableReferenceVectors(
    options: CkbPortableVectorBuildOptions,
    p4Proof: CkbReproBuildProof,
    environment: CkbReproEnvironmentLock,
    backend: CkbPortableVectorBuildBackend): CkbPortableVectorBuildResult {
    let result = CkbPortableVectorBuildResult()
    let inputs = validateCkbPortableVectorBuildInputs(
        options, p4Proof, environment)
    if (!inputs.ok) { result.diagnostic = inputs.diagnostic; return result }
    let collection = ckbPortableVectorCollectionName(options)
    if (collection == "") {
        result.diagnostic = "portable_vector_collection_invalid"
        return result
    }
    if (backend.collectionExists(collection)) {
        result.diagnostic = "portable_vector_collection_exists"
        return result
    }
    let created = backend.createEmpty(
        collection, 1024, options.distance)
    if (!created.ok) {
        result.diagnostic = if (created.diagnostic == "") {
            "portable_vector_collection_create_failed"
        } else { created.diagnostic }
        return result
    }
    let evidence = backend.stagedRebuild(collection)
    if (!evidence.ready) {
        backend.deleteCollection(collection)
        result.diagnostic = if (evidence.diagnostic == "") {
            "portable_vector_staged_rebuild_failed"
        } else { evidence.diagnostic }
        return result
    }
    if (evidence.collection != collection) {
        backend.deleteCollection(collection)
        result.diagnostic = "portable_vector_collection_mismatch"
        return result
    }
    if (evidence.count != ckbReproReleaseRecordCount()) {
        backend.deleteCollection(collection)
        result.diagnostic = "portable_vector_count_mismatch"
        return result
    }
    if (evidence.dimension != 1024) {
        backend.deleteCollection(collection)
        result.diagnostic = "portable_vector_dimension_mismatch"
        return result
    }
    if (evidence.distance.toAsciiLower() !=
        options.distance.toAsciiLower()) {
        backend.deleteCollection(collection)
        result.diagnostic = "portable_vector_distance_mismatch"
        return result
    }
    if (evidence.machinePathCount != 0) {
        backend.deleteCollection(collection)
        result.diagnostic = "portable_vector_payload_path_finding"
        return result
    }
    if (!ckbPortableVectorHashValid(evidence.payloadCanonicalHash)) {
        backend.deleteCollection(collection)
        result.diagnostic = "portable_vector_payload_hash_invalid"
        return result
    }
    result.proof.collection = collection
    result.proof.candidateVersion = options.candidateVersion
    result.proof.p4PortableProofHash = options.p4PortableProofHash
    result.proof.qdrantImageDigest = environment.qdrantImageDigest
    result.proof.embeddingProvider = environment.embeddingProvider
    result.proof.embeddingModel = environment.embeddingModel
    result.proof.count = evidence.count
    result.proof.dimension = evidence.dimension
    result.proof.distance = evidence.distance
    result.proof.payloadCanonicalHash = evidence.payloadCanonicalHash
    result.proof.vectorProofHash = ckbPortableVectorProofHash(result.proof)
    result.ready = true
    result.diagnostic = "ok"
    result
}

private func ckbPortableVectorSafeName(value: String): String {
    let out = StringBuilder()
    for (rune in value.toAsciiLower().runes()) {
        if ((rune >= r'a' && rune <= r'z') ||
            (rune >= r'0' && rune <= r'9') ||
            rune == r'-' || rune == r'_') {
            out.append(rune)
        }
    }
    out.toString()
}

private func ckbPortableVectorHashValid(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 71 || !value.startsWith("sha256:")) { return false }
    for (i in 7..runes.size) {
        if (!((runes[i] >= r'0' && runes[i] <= r'9') ||
            (runes[i] >= r'a' && runes[i] <= r'f'))) { return false }
    }
    true
}

private func ckbPortableVectorFailure(
    diagnostic: String): CkbReproContractResult {
    let result = CkbReproContractResult()
    result.diagnostic = diagnostic
    result
}

private func ckbPortableVectorSuccess(): CkbReproContractResult {
    let result = CkbReproContractResult()
    result.ok = true
    result.diagnostic = "ok"
    result
}
