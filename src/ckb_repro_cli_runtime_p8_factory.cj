package cangjie_community_knowledge_base

import std.fs.Path

class CkbP8OwnedLazyParityBackend <: CkbRetrievalParityBackend {
    private let lifecycle: CkbP8OwnedLocalLifecycle
    private let authority: CkbP8OwnedLocalRuntimeAuthority
    private let runtimeRoot: String
    private let knowledgeVersion: String
    private var backend: ?CkbRetrievalParityBackend = None
    private var nextTransport: Int64 = 0
    public init(lifecycle: CkbP8OwnedLocalLifecycle,
        authority: CkbP8OwnedLocalRuntimeAuthority, runtimeRoot: String,
        knowledgeVersion: String) {
        this.lifecycle = lifecycle; this.authority = authority
        this.runtimeRoot = runtimeRoot; this.knowledgeVersion = knowledgeVersion
    }
    public func query(transport: String, query: String):
        CkbRetrievalParityResponse {
        let expected = ["rest", "mcp_stdio", "mcp_http"]
        if (this.nextTransport >= expected.size ||
            transport != expected[this.nextTransport]) {
            _ = this.lifecycle.stopParityService()
            this.backend = None<CkbRetrievalParityBackend>
            return ckbP8OwnedParityFailure("p8_parity_transport_order_invalid")
        }
        if (this.backend.isNone()) {
            let started = this.lifecycle.startParityService(
                this.runtimeRoot, this.knowledgeVersion)
            if (!started.ok) {
                _ = this.lifecycle.stopParityService()
                return ckbP8OwnedParityFailure(started.diagnostic)
            }
            let spec = buildCkbP8OwnedMcpStdioSpec(this.authority,
                this.lifecycle.ownedConfigPath(), this.runtimeRoot)
            if (!spec[0].ok) {
                _ = this.lifecycle.stopParityService()
                return ckbP8OwnedParityFailure(spec[0].diagnostic)
            }
            let config = CkbNativeHttpTransportConfig("", false, "", false,
                true, "", this.authority.timeoutMillis)
            this.backend = Some<CkbRetrievalParityBackend>(
                CkbProductionRetrievalParityBackend(
                    this.authority.restEndpoint, spec[1],
                    this.authority.mcpHttpEndpoint,
                    NativeHttpRequestExecutor(config),
                    CkbP8BIdentityCheckedProcessExecutor(this.authority,
                        this.lifecycle.ownedConfigPath(), this.runtimeRoot),
                    timeoutMillis: this.authority.timeoutMillis))
        }
        let response = try {
            match (this.backend) {
                case Some(value) => value.query(transport, query)
                case None => ckbP8OwnedParityFailure(
                    "p8_parity_backend_unavailable")
            }
        } catch (_: Exception) {
            ckbP8OwnedParityFailure("p8_parity_backend_failed")
        }
        this.nextTransport += 1
        if (!response.ok || transport == "mcp_http") {
            let stopped = this.lifecycle.stopParityService()
            this.backend = None<CkbRetrievalParityBackend>
            if (!stopped) {
                return ckbP8OwnedParityFailure(
                    "p8_parity_service_stop_failed")
            }
        }
        response
    }
}

private func ckbP8OwnedParityFailure(code: String):
    CkbRetrievalParityResponse {
    let out = CkbRetrievalParityResponse(); out.diagnostic = code; out
}

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

class CkbReproP8ProductionStages {
    var ok: Bool = false
    var diagnostic: String = "p8_production_stages_not_built"
    var restore: CkbP8ProductionRestoreInputs = CkbP8ProductionRestoreInputs()
    var rebuild: CkbP8ProductionRebuildInputs = CkbP8ProductionRebuildInputs()
    var lifecycle: ?CkbP8OwnedLocalLifecycle = None
    public init() {}
}

func buildCkbReproP8ProductionStages(
    prepared: CkbReproProductionCliComposition,
    shared: CkbReproP8SharedComposition, options: CkbReproVerifyOptions,
    transport: CkbP8OwnedLocalRuntimeAuthority,
    buildManifest: CkbReproBuildInputManifest,
    evalSupport: CangjieEvalSupportSnapshot,
    leakage: CangjieBenchmarkLeakageAuthority):
    CkbReproP8ProductionStages {
    let out = CkbReproP8ProductionStages()
    if (!validateCkbP8BTransportEnvironment(
            transport, shared.environment).ok) {
        out.diagnostic = "p8_transport_environment_invalid"; return out
    }
    let authority = composeCkbReproCliPrivateBuildAuthority(evalSupport,
        leakage, shared.path,
        Path(options.workRoot).join("rebuild-temporary").toString(),
        options.runtimeRoot)
    if (!authority[0].ok) {
        out.diagnostic = authority[0].diagnostic; return out
    }
    let reader = CkbReproFilesystemBundleReadBackend()
    let publicRoot = Path(prepared.loaded.root).join(
        "public-build-inputs").toString()
    let loaded = loadCkbReproPublicBuildInputs(
        publicRoot, buildManifest, reader)
    if (!loaded.ok) { out.diagnostic = loaded.diagnostic; return out }
    if (loaded.sourceLock.entries.size == 0 ||
        canonicalCkbReproSourceLockHash(loaded.sourceLock) !=
            shared.buildProof.sourceLockHash) {
        out.diagnostic = "p8_build_source_identity_mismatch"; return out
    }
    let lifecycle: CkbP8OwnedLocalLifecycle =
        CkbNativeP8OwnedLocalLifecycle(transport, shared.qdrant)
    let httpConfig = CkbNativeHttpTransportConfig("", false, "", false,
        true, "", transport.timeoutMillis)
    let control: CkbQdrantSnapshotExecutor = CkbQdrantSnapshotHttpExecutor(
        transport.qdrantEndpoint, NativeHttpRequestExecutor(httpConfig))
    let files: CkbQdrantSnapshotFileExecutor =
        CkbNativeQdrantSnapshotFileExecutor(
            transport.qdrantEndpoint, httpConfig)
    out.restore.archiveBackend = Some<CkbReleaseArchiveBackend>(
        CkbPortableReleaseArchiveBackend())
    out.restore.pathPolicy = shared.path.releasePathPolicy
    out.restore.targetCollection = shared.qdrant.collection
    out.restore.qdrantManifest = shared.qdrant
    out.restore.qdrantControl = Some(control); out.restore.qdrantFile = Some(files)
    out.restore.pathContext = shared.path.pathContext
    out.restore.parityManifest = shared.parity
    out.restore.parityBackend = Some<CkbRetrievalParityBackend>(
        CkbP8OwnedLazyParityBackend(lifecycle, transport,
            options.runtimeRoot, shared.logical.portableKnowledgeVersion))
    out.restore.sourceLockHash = shared.buildProof.sourceLockHash
    out.restore.pathProofHash = shared.logical.p4PortableProofHash

    out.rebuild.buildManifest = buildManifest
    out.rebuild.authority = authority[1]; out.rebuild.reader = Some(reader)
    out.rebuild.materialBackend = Some<CkbReproMaterializingSourceBackend>(
        CkbPinnedSourceMaterialBackend(loaded.sourceLock, options.sourceRoot))
    out.rebuild.materializer = Some<CkbReproOwnedSourceMaterializer>(
        CkbFilesystemOwnedSourceMaterializer(
            Path(options.workRoot).join("owned-sources").toString()))
    out.rebuild.assembler = Some<CkbReproActualSourceAssembler>(
        CkbFirstInitReproSourceAssembler())
    out.rebuild.pipeline = Some<CkbReproBuildBackend>(
        CkbReproProductionBuildBackend())
    out.rebuild.archiveBackend = Some<CkbReleaseArchiveBackend>(
        CkbPortableReleaseArchiveBackend())
    out.rebuild.qdrantManifest = shared.qdrant
    out.rebuild.targetCollection = shared.qdrant.collection
    out.rebuild.qdrantControl = Some(control); out.rebuild.qdrantFile = Some(files)
    out.rebuild.parityManifest = shared.parity
    out.rebuild.parityBackend = Some<CkbRetrievalParityBackend>(
        CkbP8OwnedLazyParityBackend(lifecycle, transport,
            options.runtimeRoot, shared.logical.portableKnowledgeVersion))
    out.rebuild.pathProofHash = shared.logical.p4PortableProofHash
    out.lifecycle = Some(lifecycle); out.ok = true; out.diagnostic = "ok"; out
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
        (prepared.mode == "release-verify" &&
        out.buildProof.selectedCount != out.logical.rawCount) ||
        (prepared.mode == "run-certify" &&
        out.buildProof.rawCount != out.logical.rawCount) ||
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
