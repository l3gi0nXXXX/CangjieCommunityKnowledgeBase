package cangjie_community_knowledge_base_test

class CkbReproP8SharedComposition {
    var expected: CkbReproExpectedIdentity = CkbReproExpectedIdentity()
    var logical: CkbLogicalSnapshotManifest = CkbLogicalSnapshotManifest()
    var qdrant: CkbQdrantSnapshotManifest = CkbQdrantSnapshotManifest()
    var parity: CkbRetrievalParityManifest = CkbRetrievalParityManifest()
    var buildProof: CkbReproBuildProof = CkbReproBuildProof()
    var reference: CkbReproReferenceManifest = CkbReproReferenceManifest()
    var environment: CkbReproEnvironmentLock = CkbReproEnvironmentLock()
    var critical: CkbRunCriticalFilesManifest = CkbRunCriticalFilesManifest()
    var path: CkbReproCliPathContextAsset = CkbReproCliPathContextAsset()
    public init() {}
}

func loadCkbReproP8SharedComposition(
    prepared: CkbReproProductionCliComposition, repositoryRoot: String):
    (CkbReproContractResult, CkbReproP8SharedComposition) {
    let out = CkbReproP8SharedComposition()
    if (!prepared.ok || (prepared.mode != "run-certify" &&
        prepared.mode != "release-verify")) {
        return (ckbP8CompositionFailure(
            "p8_composition_mode_invalid"), out)
    }
    let logicalBytes = ckbP8CompositionRequired(prepared, "logical_manifest")
    let qdrantBytes = ckbP8CompositionRequired(prepared, "qdrant_manifest")
    let parityBytes = ckbP8CompositionRequired(prepared, "parity_manifest")
    let buildBytes = ckbP8CompositionRequired(prepared, "build_proof")
    let referenceBytes = ckbP8CompositionRequired(
        prepared, "reference_template")
    let criticalBytes = ckbP8CompositionRequired(
        prepared, "run_critical_manifest")
    let policyBytes = ckbP8CompositionRequired(prepared, "path_policy")
    let rootsBytes = ckbP8CompositionRequired(prepared, "local_root_map")
    let routesBytes = ckbP8CompositionRequired(prepared, "api_routes")
    let contextBytes = ckbP8CompositionRequired(prepared, "path_context")
    for (asset in [logicalBytes, qdrantBytes, parityBytes, buildBytes,
        referenceBytes, criticalBytes, policyBytes,
        rootsBytes, routesBytes, contextBytes]) {
        if (!asset[0]) {
            return (ckbP8CompositionFailure(
                "p8_composition_asset_missing"), out)
        }
    }
    let logical = parseCkbLogicalSnapshotManifest(logicalBytes[1])
    let qdrant = parseCkbQdrantSnapshotManifest(qdrantBytes[1])
    let parity = parseCkbRetrievalParityManifest(parityBytes[1])
    let build = parseCkbReproBuildProof(buildBytes[1])
    let reference = parseCkbReproReferenceManifest(referenceBytes[1])
    let critical = parseCkbRunCriticalFilesManifest(criticalBytes[1])
    let path = parseCkbReproCliPathContextBytes(policyBytes[1], rootsBytes[1],
        routesBytes[1], contextBytes[1])
    if (!logical[0].ok ||
        !validateCkbLogicalSnapshotManifest(logical[1]).ok ||
        !qdrant[0].ok || !validateCkbQdrantSnapshotManifest(qdrant[1]).ok ||
        !parity[0].ok || !build[0].ok || !reference[0].ok ||
        !validateCkbReproEnvironmentLock(
            prepared.loaded.authorityEnvironmentLock,
            mode: "execution").ok ||
        !critical[0].ok || !validateCkbRunCriticalFilesManifest(
            critical[1], repositoryRoot, mode: "execution").ok ||
        !path[0].ok) {
        return (ckbP8CompositionFailure(
            "p8_composition_asset_invalid"), out)
    }
    out.logical = logical[1]; out.qdrant = qdrant[1]
    out.parity = parity[1]; out.buildProof = build[1]
    out.reference = reference[1]
    out.environment = prepared.loaded.authorityEnvironmentLock
    out.critical = critical[1]; out.path = path[1]
    out.expected.knowledgeVersion = out.logical.portableKnowledgeVersion
    out.expected.logicalManifestHash = out.logical.manifestHash
    out.expected.vectorProofHash = out.qdrant.vectorProofHash
    out.expected.sourceLockHash = out.buildProof.sourceLockHash
    out.expected.pathProofHash = out.logical.p4PortableProofHash
    out.expected.rawRecords = out.logical.rawCount
    out.expected.normalizedRecords = out.logical.normalizedCount
    out.expected.activeRecords = out.logical.indexCount
    out.expected.vectorPoints = out.qdrant.points
    out.expected.vectorDimension = out.qdrant.dimension
    if (out.qdrant.logicalManifestHash != out.logical.manifestHash ||
        out.qdrant.collection != out.logical.vectorCollection ||
        out.qdrant.vectorProofHash != out.logical.p3VectorProofHash ||
        out.qdrant.points != out.logical.vectorCount ||
        out.qdrant.dimension != out.logical.vectorDimension ||
        out.parity.knowledgeVersion != out.logical.portableKnowledgeVersion ||
        out.parity.logicalManifestHash != out.logical.manifestHash ||
        out.buildProof.candidateVersion != out.logical.portableKnowledgeVersion ||
        out.buildProof.rawCount != out.logical.rawCount ||
        out.reference.knowledgeVersion != out.logical.portableKnowledgeVersion ||
        out.reference.vectorProofHash != out.qdrant.vectorProofHash ||
        out.environment.runCriticalTreeHash !=
            computeCkbRunCriticalTreeHash(out.critical, repositoryRoot) ||
        (out.reference.runCriticalTreeHash != "" &&
        out.reference.runCriticalTreeHash != out.environment.runCriticalTreeHash)) {
        return (ckbP8CompositionFailure(
            "p8_composition_identity_mismatch"),
            CkbReproP8SharedComposition())
    }
    (ckbP8CompositionSuccess(), out)
}

private func ckbP8CompositionRequired(
    prepared: CkbReproProductionCliComposition, role: String):
    (Bool, Array<UInt8>) {
    ckbReproCompositionAssetBytes(prepared.loaded, role)
}

private func ckbP8CompositionFailure(code: String):
    CkbReproContractResult {
    let out = CkbReproContractResult(); out.diagnostic = code; out
}

private func ckbP8CompositionSuccess(): CkbReproContractResult {
    let out = CkbReproContractResult(); out.ok = true
    out.diagnostic = "ok"; out
}
