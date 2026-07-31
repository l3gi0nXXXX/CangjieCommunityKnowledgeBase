package cangjie_community_knowledge_base_test

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
        p4Proof.preservationHash != options.p4PortableProofHash) {
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
    if (evidence.count != 7978) {
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
    result.proof.vectorProofHash = benchmarkGapSha256(
        "${collection}|${options.candidateVersion}|" +
        "${options.p4PortableProofHash}|${environment.qdrantImageDigest}|" +
        "${environment.embeddingProvider}|${environment.embeddingModel}|" +
        "${evidence.count}|${evidence.dimension}|${evidence.distance}|" +
        evidence.payloadCanonicalHash)
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
