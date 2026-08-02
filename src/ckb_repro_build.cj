package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashSet}
import std.fs.{File, OpenMode, Path, canonicalize, exists}
import std.sort.*
import stdx.encoding.json.*

public class CkbReproSourceLockEntry {
    public var sourceId: String = ""
    public var sourceType: String = ""
    public var repository: String = ""
    public var commit: String = ""
    public var tree: String = ""
    public var path: String = ""
    public var assemblyPath: String = ""
    public var fileHash: String = ""
    public var license: String = ""
    public var authMode: String = ""
    public var generatorId: String = ""
    public var generatorVersion: String = ""
    public var generatorSourceHash: String = ""
    public var inputHashes: ArrayList<String> = ArrayList<String>()
    public var outputHash: String = ""
    public var outputPath: String = ""
    public var assemblyRole: String = ""
    public var outputKind: String = ""
    public init() {}
}

public class CkbReproSourceLock {
    public var schemaVersion: String = "ckb-source-lock-v1"
    public var entries: ArrayList<CkbReproSourceLockEntry> =
        ArrayList<CkbReproSourceLockEntry>()
    public init() {}
}

public class CkbReproBuildOptions {
    public var outputRoot: String = ""
    public var temporaryRoot: String = ""
    public var expectedRawCount: Int64 = 7818
    public init() {}
}

public class CkbP4CliOptions {
    public var command: String = ""
    public var outputRoot: String = ""
    public var temporaryRoot: String = ""
    public var productionStore: String = ""
    public var qdrantEndpoint: String = ""
    public var expectedActiveVersion: String = ""
    public var unsignedRoot: String = ""
    public var candidateManifest: String = ""
    public var p8BReport: String = ""
    public var apply: Bool = false
    public var json: Bool = false
    public var diagnostic: String = "not_parsed"
    public init() {}
}

public class CkbP4CliOperationResult {
    public var ok: Bool = false
    public var diagnostic: String = "not_run"
    public var summary: String = ""
    public init() {}
}

public class CkbP4CliExecution {
    public var ok: Bool = false
    public var exitCode: Int64 = 2
    public var diagnostic: String = "not_run"
    public var output: String = ""
    public init() {}
}

public interface CkbP4CliAdapter {
    func execute(options: CkbP4CliOptions): CkbP4CliOperationResult
}

public func parseCkbP4CliOptions(args: Array<String>): CkbP4CliOptions {
    let out = CkbP4CliOptions()
    if (args.size == 0 || (args[0] != "ckb-repro-build" && args[0] != "ckb-repro-promote")) {
        out.diagnostic = "p4_command_required"; return out
    }
    out.command = args[0]; let seen = HashSet<String>(); var i: Int64 = 1
    while (i < args.size) {
        let arg = args[i]
        if (arg == "--apply" || arg == "--json") {
            if (seen.contains(arg)) { out.diagnostic = "duplicate_argument:${arg}"; return out }
            if (arg == "--apply" && out.command != "ckb-repro-promote") {
                out.diagnostic = "argument_not_allowed:build:--apply"; return out
            }
            seen.add(arg); if (arg == "--apply") { out.apply = true } else { out.json = true }
            i += 1; continue
        }
        if (!ckbP4CliAllowed(out.command, arg)) { out.diagnostic = "unknown_argument:${arg}"; return out }
        if (seen.contains(arg)) { out.diagnostic = "duplicate_argument:${arg}"; return out }
        if (i + 1 >= args.size || args[i + 1].startsWith("--")) {
            out.diagnostic = "missing_argument_value:${arg}"; return out
        }
        seen.add(arg); let value = args[i + 1]
        if (arg == "--output-root") { out.outputRoot = value }
        else if (arg == "--temporary-root") { out.temporaryRoot = value }
        else if (arg == "--production-store") { out.productionStore = value }
        else if (arg == "--qdrant-endpoint") { out.qdrantEndpoint = value }
        else if (arg == "--expected-active-version") { out.expectedActiveVersion = value }
        else if (arg == "--unsigned-root") { out.unsignedRoot = value }
        else if (arg == "--candidate-manifest") { out.candidateManifest = value }
        else if (arg == "--p8-b-report") { out.p8BReport = value }
        i += 2
    }
    out.diagnostic = validateCkbP4CliOptions(out); out
}

public func validateCkbP4CliOptions(out: CkbP4CliOptions): String {
    for (pair in if (out.command == "ckb-repro-build") {
        [("--output-root", out.outputRoot), ("--temporary-root", out.temporaryRoot)]
    } else { [("--production-store", out.productionStore),
        ("--qdrant-endpoint", out.qdrantEndpoint),
        ("--expected-active-version", out.expectedActiveVersion),
        ("--unsigned-root", out.unsignedRoot),
        ("--candidate-manifest", out.candidateManifest),
        ("--p8-b-report", out.p8BReport)] }) {
        if (pair[1] == "") { return "required_argument_missing:${pair[0]}" }
    }
    if (out.command == "ckb-repro-promote" && !out.apply) {
        return "promotion_apply_required"
    }
    if (out.command == "ckb-repro-promote" && !(out.qdrantEndpoint.startsWith("http://") ||
        out.qdrantEndpoint.startsWith("https://"))) {
        return "invalid_endpoint"
    }
    "ok"
}

public func executeCkbP4CliAdapter(args: Array<String>, adapter: CkbP4CliAdapter): CkbP4CliExecution {
    let options = parseCkbP4CliOptions(args)
    if (options.diagnostic != "ok") { return ckbP4CliFailure(options.diagnostic, args.contains("--json")) }
    let result = try { adapter.execute(options) } catch (_: Exception) {
        return ckbP4CliFailure("p4_adapter_execution_failed", options.json)
    }
    let out = CkbP4CliExecution()
    out.ok = result.ok; out.exitCode = if (result.ok) { 0 } else { 1 }
    out.diagnostic = result.diagnostic
    out.output = if (options.json) { renderCkbP4CliJson(result) } else { renderCkbP4CliHuman(result) }
    out
}
public class CkbP4ProductionAdapter <: CkbP4CliAdapter {
    private let buildRequest: CkbReproBuildRequest
    private let buildBackend: CkbReproBuildBackend
    private let promotionBackend: CkbPortablePromotionBackend
    public init(buildRequest: CkbReproBuildRequest,
        buildBackend: CkbReproBuildBackend,
        promotionBackend: CkbPortablePromotionBackend) {
        this.buildRequest = buildRequest; this.buildBackend = buildBackend
        this.promotionBackend = promotionBackend
    }
    public func execute(options: CkbP4CliOptions): CkbP4CliOperationResult {
        if (options.command == "ckb-repro-build") { return this.build(options) }
        this.promote(options)
    }
    private func build(options: CkbP4CliOptions): CkbP4CliOperationResult {
        let out = CkbP4CliOperationResult()
        let roots = ckbP4ValidateBuildRoots(options.outputRoot, options.temporaryRoot)
        if (roots != "ok") { out.diagnostic = roots; return out }
        this.buildRequest.options.outputRoot = options.outputRoot
        this.buildRequest.options.temporaryRoot = options.temporaryRoot
        let result = runCkbReproBuild(this.buildRequest, this.buildBackend)
        out.ok = result.ready; out.diagnostic = result.diagnostic
        out.summary = "logicalReady=${result.proof.logicalReady} raw=${result.proof.rawCount} " +
            "selected=${result.proof.selectedCount} vectorState=${result.proof.vectorState}"
        out
    }
    private func promote(options: CkbP4CliOptions): CkbP4CliOperationResult {
        let out = CkbP4CliOperationResult()
        let loaded = loadCkbPortablePromotionCliInputs(options.unsignedRoot,
            options.candidateManifest, options.p8BReport,
            CkbReproFilesystemBundleReadBackend())
        if (!loaded[0].ok) { out.diagnostic = loaded[0].diagnostic; return out }
        let promotion = loaded[1]; promotion.productionStore = options.productionStore
        promotion.qdrantEndpoint = options.qdrantEndpoint
        promotion.expectedActiveVersion = options.expectedActiveVersion
        promotion.apply = options.apply
        let current = this.promotionBackend.readCurrent()
        promotion.expectedPointerHash = current.pointerHash
        let result = promoteCkbPortableCandidate(promotion, this.promotionBackend)
        out.ok = result.ready; out.diagnostic = result.diagnostic
        out.summary = "activeVersion=${result.activeVersion} pointerCommitted=" +
            "${result.pointerCommitted}"; out
    }
}

public func newCkbP4ProductionAdapter(buildRequest: CkbReproBuildRequest,
    buildBackend: CkbReproBuildBackend,
    promotionBackend: CkbPortablePromotionBackend): CkbP4CliAdapter {
    CkbP4ProductionAdapter(buildRequest, buildBackend, promotionBackend)
}

public func newCkbP4BusinessProductionAdapter(
    buildRequest: CkbReproBuildRequest,
    candidateStore: FileKnowledgeStore,
    productionStore: FileKnowledgeStore,
    snapshotBytes: Array<UInt8>,
    snapshotManifest: CkbQdrantSnapshotManifest,
    logicalManifest: CkbLogicalSnapshotManifest,
    targetCollection: String,
    snapshotExecutor: CkbQdrantSnapshotExecutor,
    pathContext: CkbPortablePathContext): CkbP4CliAdapter {
    CkbP4ProductionAdapter(buildRequest, CkbReproProductionBuildBackend(),
        CkbPortableProductionPromotionBackend(candidateStore, productionStore,
            snapshotBytes, snapshotManifest, logicalManifest, targetCollection,
            snapshotExecutor, pathContext))
}

public func newCkbP4RuntimeProductionAdapter(
    buildRequest: CkbReproBuildRequest,
    candidateStore: FileKnowledgeStore,
    productionStore: FileKnowledgeStore,
    snapshotPath: String,
    snapshotManifest: CkbQdrantSnapshotManifest,
    logicalManifest: CkbLogicalSnapshotManifest,
    targetCollection: String,
    snapshotEndpoint: String,
    runtime: CkbRuntimeConfig,
    pathContext: CkbPortablePathContext): CkbP4CliAdapter {
    let transportConfig = ckbNativeHttpAdapterConfigFromRuntime(runtime, true)
    let http = NativeHttpRequestExecutor(transportConfig)
    let control = CkbQdrantSnapshotHttpExecutor(snapshotEndpoint, http)
    let files = CkbNativeQdrantSnapshotFileExecutor(
        snapshotEndpoint, transportConfig)
    CkbP4ProductionAdapter(buildRequest, CkbReproProductionBuildBackend(),
        CkbPortableProductionPromotionBackend(candidateStore, productionStore,
            snapshotPath, snapshotManifest, logicalManifest, targetCollection,
            control, files, pathContext))
}

public class CkbPortablePromotionBundleInputs {
    public var contract: CkbReproContractResult = CkbReproContractResult()
    public var runtimeAssets: CkbReproPromotionRuntimeAssets =
        CkbReproPromotionRuntimeAssets()
    public var options: CkbPortablePromotionOptions =
        CkbPortablePromotionOptions()
    public var logicalManifest: CkbLogicalSnapshotManifest =
        CkbLogicalSnapshotManifest()
    public var snapshotManifest: CkbQdrantSnapshotManifest =
        CkbQdrantSnapshotManifest()
    public var candidateStoreRoot: String = ""
    public var targetCollection: String = ""
    public init() {}
}

public func validateCkbPortablePromotionRuntimeBindings(
    options: CkbPortablePromotionOptions,
    snapshot: CkbQdrantSnapshotManifest,
    logical: CkbLogicalSnapshotManifest,
    vector: CkbPortableVectorProof,
    qdrantSnapshotSha256: String): CkbReproContractResult {
    if (snapshot.snapshotSha256 != qdrantSnapshotSha256 ||
        snapshot.logicalManifestHash != logical.manifestHash ||
        snapshot.vectorProofHash != vector.vectorProofHash ||
        logical.p3VectorProofHash != vector.vectorProofHash ||
        snapshot.collection != logical.vectorCollection ||
        snapshot.points != logical.vectorCount ||
        snapshot.dimension != logical.vectorDimension ||
        logical.portableKnowledgeVersion != options.candidateVersion) {
        return p4BuildFailure("promotion_runtime_asset_binding_invalid")
    }
    p4BuildSuccess()
}

// Loads every runtime promotion input from one validated release bundle.
// productionStore is intentionally absent: only the CLI may select it.
public func loadCkbPortablePromotionBundleInputs(unsignedRoot: String,
    candidatePath: String, p8BPath: String, ownedRoot: String,
    bundleBackend: CkbReproBundleReadBackend,
    archiveBackend: CkbReleaseArchiveBackend):
    CkbPortablePromotionBundleInputs {
    let out = CkbPortablePromotionBundleInputs()
    let baseline = validateCkbReproBundleManifest(unsignedRoot, bundleBackend)
    if (!baseline.contract.ok) {
        out.contract = p4BuildFailure("promotion_bundle_invalid"); return out
    }
    let controls = loadCkbPortablePromotionCliInputs(unsignedRoot,
        candidatePath, p8BPath, bundleBackend)
    if (!controls[0].ok) { out.contract = controls[0]; return out }
    let runtime = captureCkbReproPromotionRuntimeAssets(unsignedRoot,
        ownedRoot, bundleBackend)
    out.runtimeAssets = runtime
    if (!runtime.contract.ok || runtime.control.bytes.size != 7 ||
        runtime.control.loaded.rootIdentity != baseline.rootIdentity ||
        runtime.control.loaded.manifest.inputSetHash !=
            baseline.manifest.inputSetHash ||
        runtime.control.loaded.proofSetHash != baseline.proofSetHash) {
        cleanupCkbReproPromotionRuntimeAssets(runtime)
        out.contract = p4BuildFailure(if (runtime.contract.ok) {
            "promotion_bundle_changed"
        } else { runtime.contract.diagnostic })
        return out
    }
    let parsedSnapshot = parseCkbQdrantSnapshotManifest(
        runtime.control.bytes[6])
    if (!parsedSnapshot[0].ok ||
        !validateCkbQdrantSnapshotManifest(parsedSnapshot[1]).ok) {
        return p4BuildBundleInputsFailure(out,
            if (parsedSnapshot[0].diagnostic == "invalid_response_encoding") {
                "invalid_response_encoding"
            } else { "promotion_qdrant_manifest_invalid" })
    }
    let inspected = inspectCkbReleaseArchive(archiveBackend,
        runtime.logicalSnapshotPath)
    if (!inspected.ok) {
        return p4BuildBundleInputsFailure(out,
            "promotion_logical_archive_invalid")
    }
    let vector = parseCkbPortableVectorProofBytes(
        runtime.control.bytes[2])
    if (!vector[0].ok) {
        return p4BuildBundleInputsFailure(out,
            "promotion_vector_proof_invalid")
    }
    let snapshot = parsedSnapshot[1]
    let logical = inspected.manifest
    let binding = validateCkbPortablePromotionRuntimeBindings(controls[1],
        snapshot, logical, vector[1], runtime.qdrantSnapshotSha256)
    if (!binding.ok) {
        return p4BuildBundleInputsFailure(out,
            binding.diagnostic)
    }
    let candidateStoreRoot = Path(ownedRoot).join("candidate-store").toString()
    let imported = importCkbLogicalSnapshot(runtime.logicalSnapshotPath,
        candidateStoreRoot, archiveBackend)
    if (!imported.ok) {
        return p4BuildBundleInputsFailure(out,
            "promotion_candidate_store_import_failed")
    }
    out.options = controls[1]
    out.logicalManifest = logical
    out.snapshotManifest = snapshot
    out.candidateStoreRoot = candidateStoreRoot
    out.targetCollection = "ckb_promotion_" +
        controls[1].candidateManifestHash.replace("sha256:", "")
    out.contract = p4BuildSuccess()
    out
}

public func newCkbPortableBundlePromotionBackend(
    inputs: CkbPortablePromotionBundleInputs, productionStore: String,
    executor: CkbQdrantSnapshotExecutor,
    fileExecutor: CkbQdrantSnapshotFileExecutor,
    pathContext: CkbPortablePathContext): CkbPortablePromotionBackend {
    CkbPortableProductionPromotionBackend(
        FileKnowledgeStore(inputs.candidateStoreRoot),
        FileKnowledgeStore(productionStore),
        inputs.runtimeAssets.qdrantSnapshotPath, inputs.snapshotManifest,
        inputs.logicalManifest, inputs.targetCollection, executor,
        fileExecutor, pathContext)
}

public func cleanupCkbPortablePromotionBundleInputs(
    inputs: CkbPortablePromotionBundleInputs): Bool {
    cleanupCkbReproPromotionRuntimeAssets(inputs.runtimeAssets)
}

public class CkbP4SameBundleProductionAdapter <: CkbP4CliAdapter {
    private let buildAdapter: CkbP4CliAdapter
    private let ownedRoot: String
    private let bundleBackend: CkbReproBundleReadBackend
    private let archiveBackend: CkbReleaseArchiveBackend
    private let executor: CkbQdrantSnapshotExecutor
    private let fileExecutor: CkbQdrantSnapshotFileExecutor
    private let pathContext: CkbPortablePathContext
    public init(buildAdapter: CkbP4CliAdapter, ownedRoot: String,
        bundleBackend: CkbReproBundleReadBackend,
        archiveBackend: CkbReleaseArchiveBackend,
        executor: CkbQdrantSnapshotExecutor,
        fileExecutor: CkbQdrantSnapshotFileExecutor,
        pathContext: CkbPortablePathContext) {
        this.buildAdapter = buildAdapter; this.ownedRoot = ownedRoot
        this.bundleBackend = bundleBackend; this.archiveBackend = archiveBackend
        this.executor = executor; this.fileExecutor = fileExecutor
        this.pathContext = pathContext
    }
    public func execute(options: CkbP4CliOptions): CkbP4CliOperationResult {
        if (options.command == "ckb-repro-build") {
            return this.buildAdapter.execute(options)
        }
        let out = CkbP4CliOperationResult()
        let loaded = loadCkbPortablePromotionBundleInputs(
            options.unsignedRoot, options.candidateManifest,
            options.p8BReport, this.ownedRoot, this.bundleBackend,
            this.archiveBackend)
        if (!loaded.contract.ok) {
            out.diagnostic = loaded.contract.diagnostic; return out
        }
        try {
            let promotion = loaded.options
            promotion.productionStore = options.productionStore
            promotion.qdrantEndpoint = options.qdrantEndpoint
            promotion.expectedActiveVersion = options.expectedActiveVersion
            promotion.apply = options.apply
            let backend = newCkbPortableBundlePromotionBackend(loaded,
                options.productionStore, this.executor, this.fileExecutor,
                this.pathContext)
            let current = backend.readCurrent()
            promotion.expectedPointerHash = current.pointerHash
            let result = promoteCkbPortableCandidate(promotion, backend)
            out.ok = result.ready; out.diagnostic = result.diagnostic
            out.summary = "activeVersion=${result.activeVersion} " +
                "pointerCommitted=${result.pointerCommitted}"
            out
        } finally {
            cleanupCkbPortablePromotionBundleInputs(loaded)
        }
    }
}

private func p4BuildBundleInputsFailure(
    out: CkbPortablePromotionBundleInputs, diagnostic: String):
    CkbPortablePromotionBundleInputs {
    cleanupCkbReproPromotionRuntimeAssets(out.runtimeAssets)
    out.contract = p4BuildFailure(diagnostic)
    out
}

public func loadCkbPortablePromotionCliInputs(unsignedRoot: String,
    candidatePath: String, p8BPath: String,
    backend: CkbReproBundleReadBackend):
    (CkbReproContractResult, CkbPortablePromotionOptions) {
    let options = CkbPortablePromotionOptions()
    let snapshot = captureCkbReproPromotionAssets(unsignedRoot, backend)
    if (!snapshot.contract.ok) {
        return (p4BuildFailure("promotion_bundle_invalid"), options)
    }
    let loaded = snapshot.loaded
    let root = try { canonicalize(Path(unsignedRoot)).toString() }
        catch (_: Exception) { return (p4BuildFailure("promotion_bundle_invalid"), options) }
    let candidate = try { canonicalize(Path(candidatePath)).toString() }
        catch (_: Exception) { return (p4BuildFailure("promotion_candidate_path_invalid"), options) }
    if (!candidate.startsWith(root + "/") ||
        candidate != Path(root).join("promotion-candidate.json").toString() ||
        !p4BuildManifestAsset(loaded.manifest, "promotion-candidate.json",
            "p4_build_proof")) {
        return (p4BuildFailure("promotion_candidate_path_invalid"), options)
    }
    let candidateBytes = p4BuildBundleAssetBytes(snapshot,
        "promotion-candidate.json", "p4_build_proof")
    if (!candidateBytes[0]) {
        return (p4BuildFailure("promotion_candidate_path_invalid"), options)
    }
    let p8BRead = p4BuildReadBoundedUtf8(p8BPath, "promotion_p8_b")
    if (p8BRead[0] != "ok") { return (p4BuildFailure(p8BRead[0]), options) }
    let report = parseCkbReproVerificationReport(p8BRead[1].toArray())
    if (!report[0].ok || !validateCkbReproVerificationReport(report[1]).ok) {
        return (p4BuildFailure("promotion_p8_b_report_invalid"), options)
    }
    try {
        let candidateText = String.fromUtf8(candidateBytes[1])
        let candidate = JsonValue.fromStr(candidateText).asObject()
        if (candidate.size() != 12) {
            return (p4BuildFailure("promotion_candidate_field_contract_invalid"), options)
        }
        options.candidateVersion = p4BuildRequiredString(candidate, "candidateVersion")
        options.candidateManifestHash =
            p4BuildRequiredString(candidate, "candidateManifestHash")
        options.p2ProofHash = p4BuildRequiredString(candidate, "p2ProofHash")
        options.p3ProofHash = p4BuildRequiredString(candidate, "p3ProofHash")
        options.p5ProofHash = p4BuildRequiredString(candidate, "p5ProofHash")
        options.p8AProofHash = p4BuildRequiredString(candidate, "p8AProofHash")
        options.identity = p4BuildRequiredString(candidate, "identity")
        options.p8StrictPassed = p4BuildRequiredInt(candidate, "p8StrictPassed")
        let artifactPaths = [
            p4BuildRequiredString(candidate, "p2ProofPath"),
            p4BuildRequiredString(candidate, "p3ProofPath"),
            p4BuildRequiredString(candidate, "p5ProofPath"),
            p4BuildRequiredString(candidate, "p8AProofPath")
        ]
        let expectedPaths = ["portable-logical-proof.json",
            "portable-vector-proof.json", "public-evidence-export.json",
            "reproducibility/manifests/reference-run.json"]
        let expectedRoles = ["p4_build_proof", "p4_build_proof",
            "p5_public_evidence", "p8_reference"]
        let declaredHashes = [options.p2ProofHash, options.p3ProofHash,
            options.p5ProofHash, options.p8AProofHash]
        let artifactBytes = ArrayList<Array<UInt8>>()
        let artifactTexts = ArrayList<String>()
        for (i in 0..artifactPaths.size) {
            if (artifactPaths[i] != expectedPaths[i] ||
                !p4BuildManifestAsset(loaded.manifest, expectedPaths[i],
                    expectedRoles[i])) {
                return (p4BuildFailure("promotion_artifact_path_invalid"), options)
            }
            let artifact = p4BuildBundleAssetBytes(snapshot,
                expectedPaths[i], expectedRoles[i])
            if (!artifact[0]) {
                return (p4BuildFailure("promotion_artifact_path_invalid"), options)
            }
            let artifactText = String.fromUtf8(artifact[1])
            if (benchmarkGapSha256(artifactText) != declaredHashes[i]) {
                return (p4BuildFailure("promotion_artifact_hash_mismatch"), options)
            }
            artifactBytes.add(artifact[1])
            artifactTexts.add(artifactText)
        }
        let logical = parseCkbLogicalSnapshotCliProofBytes(
            artifactBytes[0], artifactBytes[1])
        let vector = parseCkbPortableVectorProofBytes(artifactBytes[1])
        let publicEvidence = parseCkbPublicEvidenceExportManifest(
            artifactTexts[2].toArray())
        let reference = parseCkbReproReferenceManifest(
            artifactTexts[3].toArray())
        let referenceValidation = validateCkbReproReferenceManifest(reference[1])
        if (!logical[0].ok || !vector[0].ok || !publicEvidence[0].ok ||
            !validateCkbPublicEvidenceExportManifest(publicEvidence[1]).ok ||
            !reference[0].ok || !referenceValidation.ok ||
            reference[1].baselineKind != "portable_release" ||
            reference[1].evidenceStatus != "complete" ||
            logical[1].portableKnowledgeVersion != options.candidateVersion ||
            vector[1].candidateVersion != options.candidateVersion ||
            reference[1].knowledgeVersion != options.candidateVersion ||
            publicEvidence[1].knowledgeVersion != options.candidateVersion ||
            logical[1].contaminationProofHash != publicEvidence[1].publicEvidenceHash ||
            publicEvidence[1].publicEvidenceHash != options.identity ||
            reference[1].strictPassed != options.p8StrictPassed ||
            reference[1].strictPassed != 151 ||
            publicEvidence[1].referenceManifestHash != referenceValidation.manifestHash ||
            publicEvidence[1].privateResultsHash != reference[1].resultsHash ||
            publicEvidence[1].runId != reference[1].runId ||
            publicEvidence[1].providerFingerprint != reference[1].providerFingerprint ||
            publicEvidence[1].modelFingerprint != reference[1].modelFingerprint ||
            publicEvidence[1].vectorProofHash != reference[1].vectorProofHash ||
            vector[1].vectorProofHash != reference[1].vectorProofHash ||
            publicEvidence[1].certifiedRunInputHash != reference[1].certifiedRunInputHash) {
            return (p4BuildFailure("promotion_typed_artifact_invalid"), options)
        }
        if (options.candidateManifestHash !=
            ckbPortableCandidateManifestHash(options)) {
            return (p4BuildFailure("promotion_candidate_hash_mismatch"), options)
        }
        if (report[1].referenceManifestHash != referenceValidation.manifestHash ||
            report[1].certifiedRunInputHash != reference[1].certifiedRunInputHash ||
            report[1].runCriticalTreeHash != reference[1].runCriticalTreeHash ||
            report[1].verifiedReleaseInputSetHash != loaded.manifest.inputSetHash ||
            report[1].bundleProofSetHash != loaded.proofSetHash) {
            return (p4BuildFailure("promotion_p8_b_report_invalid"), options)
        }
        let commitAsset = p4BuildUniqueRoleBytes(snapshot, "release_commit")
        if (!commitAsset[0]) {
            return (p4BuildFailure("promotion_p8_b_report_invalid"), options)
        }
        let commitText = String.fromUtf8(commitAsset[1])
        if (commitText != report[1].releaseCommit ||
            computeCkbReproReleaseAuthorityHash(loaded,
                referenceValidation.manifestHash,
                referenceValidation.canonicalJson.toArray().size,
                report[1].releaseCommit) !=
                report[1].authorityHash) {
            return (p4BuildFailure("promotion_p8_b_report_invalid"), options)
        }
        let after = validateCkbReproBundleManifest(unsignedRoot, backend)
        if (!after.contract.ok || after.manifest.inputSetHash != loaded.manifest.inputSetHash ||
            after.proofSetHash != loaded.proofSetHash ||
            after.rootIdentity != loaded.rootIdentity) {
            return (p4BuildFailure("promotion_bundle_changed"), options)
        }
    } catch (_: Exception) {
        return (p4BuildFailure("promotion_artifact_malformed_json"), options)
    }
    for (hash in [options.candidateManifestHash, options.p2ProofHash,
        options.p3ProofHash, options.p5ProofHash, options.p8AProofHash]) {
        if (!p4BuildHash(hash)) { return (p4BuildFailure("promotion_proof_missing"), options) }
    }
    if (options.candidateVersion == "" || options.identity == "" ||
        options.p8StrictPassed != 151) {
        return (p4BuildFailure("promotion_identity_invalid"), options)
    }
    (p4BuildSuccess(), options)
}

private func p4BuildManifestAsset(manifest: CkbReproBundleManifest,
    relativePath: String, role: String): Bool {
    var count: Int64 = 0
    for (asset in manifest.assets) {
        if (asset.relativePath == relativePath && asset.role == role) { count += 1 }
    }
    count == 1
}

private func p4BuildBundleAssetBytes(snapshot: CkbReproPromotionAssetSnapshot,
    relativePath: String, role: String): (Bool, Array<UInt8>) {
    let loaded = snapshot.loaded
    var index: Int64 = -1; var count: Int64 = 0
    for (i in 0..loaded.manifest.assets.size) {
        let asset = loaded.manifest.assets[i]
        if (asset.relativePath == relativePath) {
            count += 1; index = i
            if (asset.role != role || asset.logicalAsset != relativePath ||
                asset.partIndex != 0 || asset.partCount != 1 ||
                asset.logicalSize != asset.size ||
                asset.logicalSha256 != asset.sha256) {
                return (false, Array<UInt8>())
            }
        }
    }
    let paths = ["promotion-candidate.json", "portable-logical-proof.json",
        "portable-vector-proof.json", "public-evidence-export.json",
        "reproducibility/manifests/reference-run.json",
        "release/release-commit.txt"]
    var captured: Int64 = -1
    for (i in 0..paths.size) { if (paths[i] == relativePath) { captured = i } }
    if (count != 1 || index < 0 || captured < 0 ||
        captured >= snapshot.bytes.size) {
        return (false, Array<UInt8>())
    }
    (true, snapshot.bytes[captured])
}

private func p4BuildUniqueRoleBytes(snapshot: CkbReproPromotionAssetSnapshot,
    role: String): (Bool, Array<UInt8>) {
    let loaded = snapshot.loaded
    var index: Int64 = -1; var count: Int64 = 0
    for (i in 0..loaded.manifest.assets.size) {
        if (loaded.manifest.assets[i].role == role) { count += 1; index = i }
    }
    if (count != 1 || index < 0 || snapshot.bytes.size != 6) {
        return (false, Array<UInt8>())
    }
    (true, snapshot.bytes[5])
}

private func p4BuildUniqueManifestRole(manifest: CkbReproBundleManifest,
    role: String): String {
    var value = ""; var count: Int64 = 0
    for (asset in manifest.assets) {
        if (asset.role == role) { value = asset.relativePath; count += 1 }
    }
    if (count == 1) { value } else { "" }
}

public func ckbPortableCandidateManifestHash(
    options: CkbPortablePromotionOptions): String {
    benchmarkGapSha256("ckb-portable-candidate-manifest-v1|" + p4BuildFields([
        options.candidateVersion, options.p2ProofHash, options.p3ProofHash,
        options.p5ProofHash, options.p8AProofHash, options.identity,
        options.p8StrictPassed.toString()
    ]))
}

private func p4BuildPromotionArtifactPath(candidatePath: String,
    relative: String): (String, String) {
    if (!p4BuildSafeRelative(relative)) {
        return ("promotion_artifact_path_invalid", "")
    }
    let parent = try { canonicalize(Path(candidatePath).parent) }
        catch (_: Exception) { return ("promotion_artifact_path_invalid", "") }
    let artifact = parent.join(relative)
    let canonical = try { canonicalize(artifact) }
        catch (_: Exception) { return ("promotion_artifact_unreadable", "") }
    if (!canonical.toString().startsWith("${parent.toString()}/")) {
        return ("promotion_artifact_path_invalid", "")
    }
    ("ok", canonical.toString())
}

private func p4BuildReadBoundedUtf8(path: String, kind: String): (String, String) {
    let bytes = ArrayList<UInt8>()
    try {
        try (file = File(Path(path), OpenMode.Read)) {
            while (true) {
                let buffer = Array<UInt8>(16000, repeat: UInt8(0))
                let count = file.read(buffer)
                if (count < 0 || count > buffer.size) {
                    return ("${kind}_read_failed", "")
                }
                if (count == 0) { break }
                if (bytes.size > 65536 - count) {
                    return ("${kind}_size_invalid", "")
                }
                for (i in 0..count) { bytes.add(buffer[i]) }
            }
        }
    } catch (_: Exception) { return ("${kind}_unreadable", "") }
    try { ("ok", String.fromUtf8(bytes.toArray())) }
    catch (_: Exception) { ("invalid_response_encoding", "") }
}
public func runCkbP4Cli(args: Array<String>, context: CkbP4CliAdapter): CkbP4CliExecution {
    executeCkbP4CliAdapter(args, context)
}
public func renderCkbP4CliHuman(result: CkbP4CliOperationResult): String {
    if (result.ok) { "CKB reproducible build operation completed. ${ckbP4CliSafe(result.summary)}\n" }
    else { "CKB reproducible build operation failed: ${ckbP4CliSafe(result.diagnostic)}\n" }
}
public func renderCkbP4CliJson(result: CkbP4CliOperationResult): String {
    "{\"ok\":${result.ok},\"diagnostic\":\"${ckbP4CliJson(result.diagnostic)}\"," +
        "\"summary\":\"${ckbP4CliJson(result.summary)}\"}"
}
private func ckbP4CliAllowed(command: String, arg: String): Bool {
    if (command == "ckb-repro-build") { return ["--output-root", "--temporary-root"].contains(arg) }
    ["--production-store", "--qdrant-endpoint", "--expected-active-version",
     "--unsigned-root", "--candidate-manifest", "--p8-b-report"].contains(arg)
}
private func ckbP4CliFailure(diagnostic: String, json: Bool): CkbP4CliExecution {
    let result = CkbP4CliOperationResult(); result.diagnostic = diagnostic
    let out = CkbP4CliExecution(); out.diagnostic = diagnostic
    out.output = if (json) { renderCkbP4CliJson(result) } else { renderCkbP4CliHuman(result) }; out
}
private func ckbP4CliSafe(value: String): String { let runes = redactSensitive(value).toRuneArray(); let n = if (runes.size < 160) { runes.size } else { 160 }; let out = StringBuilder(); for (i in 0..n) { out.append(runes[i]) }; out.toString() }
private func ckbP4CliJson(value: String): String { let out = StringBuilder(); let hex = "0123456789abcdef".toRuneArray(); for (rune in ckbP4CliSafe(value).runes()) { if (rune == r'"') { out.append("\\\"") } else if (rune == r'\\') { out.append("\\\\") } else if (rune == r'\n') { out.append("\\n") } else if (rune == r'\r') { out.append("\\r") } else if (rune == r'\t') { out.append("\\t") } else if (UInt32(rune) < 0x20u32) { let code = UInt32(rune); out.append("\\u00"); out.append(hex[Int64(code / 16u32)]); out.append(hex[Int64(code % 16u32)]) } else { out.append(rune) } }; out.toString() }

public func parseCkbReproBuildOptions(args: Array<String>): CkbReproBuildOptions {
    let options = CkbReproBuildOptions()
    var i: Int64 = 0
    while (i < args.size) {
        if (args[i] == "--output-root" && i + 1 < args.size) {
            options.outputRoot = args[i + 1].trimAscii(); i += 2; continue
        }
        if (args[i] == "--temporary-root" && i + 1 < args.size) {
            options.temporaryRoot = args[i + 1].trimAscii(); i += 2; continue
        }
        i += 1
    }
    options
}

public func parseCkbReproSourceLock(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbReproSourceLock) {
    let lock = CkbReproSourceLock()
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (p4BuildFailure("invalid_response_encoding"), lock)
    }
    try {
        let root = JsonValue.fromStr(text).asObject()
        if (root.size() != 2) {
            return (p4BuildFailure("source_lock_field_contract_invalid"), lock)
        }
        lock.schemaVersion = root.get("schemaVersion").getOrThrow().asString().getValue()
        for (value in root.get("sources").getOrThrow().asArray().getItems()) {
            let object = value.asObject()
            let entry = CkbReproSourceLockEntry()
            entry.sourceId = p4BuildOptionalString(object, "sourceId")
            entry.sourceType = p4BuildOptionalString(object, "sourceType")
            entry.repository = p4BuildOptionalString(object, "repository")
            entry.commit = p4BuildOptionalString(object, "commit")
            entry.tree = p4BuildOptionalString(object, "tree")
            entry.path = p4BuildOptionalString(object, "path")
            entry.assemblyPath = p4BuildOptionalString(object, "assemblyPath")
            entry.fileHash = p4BuildOptionalString(object, "fileHash")
            entry.license = p4BuildOptionalString(object, "license")
            entry.authMode = p4BuildOptionalString(object, "authMode")
            entry.generatorId = p4BuildOptionalString(object, "generatorId")
            entry.generatorVersion = p4BuildOptionalString(object, "generatorVersion")
            entry.generatorSourceHash = p4BuildOptionalString(object, "generatorSourceHash")
            entry.outputHash = p4BuildOptionalString(object, "outputHash")
            entry.outputPath = p4BuildOptionalString(object, "outputPath")
            entry.assemblyRole = p4BuildOptionalString(object, "assemblyRole")
            entry.outputKind = p4BuildOptionalString(object, "outputKind")
            match (object.get("inputHashes")) {
                case Some(items) =>
                    for (item in items.asArray().getItems()) {
                        entry.inputHashes.add(item.asString().getValue())
                    }
                case None => ()
            }
            let validFieldCount = if (entry.sourceType == "external_git") {
                object.size() == 11 || object.size() == 12
            } else if (entry.sourceType == "generated") {
                object.size() == 11
            } else { false }
            if (!validFieldCount) {
                return (p4BuildFailure("source_lock_field_contract_invalid"),
                    CkbReproSourceLock())
            }
            lock.entries.add(entry)
        }
        let validated = validateCkbReproBuildLocks(lock)
        if (!validated.ok) { return (validated, CkbReproSourceLock()) }
        if (renderCkbReproSourceLock(lock) != text) {
            return (p4BuildFailure("source_lock_noncanonical"),
                CkbReproSourceLock())
        }
        (p4BuildSuccess(), lock)
    } catch (_: Exception) {
        (p4BuildFailure("source_lock_malformed_json"), CkbReproSourceLock())
    }
}

public func renderCkbReproSourceLock(lock: CkbReproSourceLock): String {
    let rows = ArrayList<String>()
    for (entry in lock.entries) {
        if (entry.sourceType == "external_git") {
            rows.add("{\"sourceId\":\"${p4BuildJson(entry.sourceId)}\"," +
                "\"sourceType\":\"external_git\"," +
                "\"repository\":\"${p4BuildJson(entry.repository)}\"," +
                "\"commit\":\"${p4BuildJson(entry.commit)}\"," +
                "\"tree\":\"${entry.tree}\"," +
                "\"path\":\"${p4BuildJson(entry.path)}\"," +
                if (entry.assemblyPath != "" &&
                    entry.assemblyPath != entry.path) {
                    "\"assemblyPath\":\"${p4BuildJson(entry.assemblyPath)}\","
                } else { "" } +
                "\"fileHash\":\"${entry.fileHash}\"," +
                "\"license\":\"${p4BuildJson(entry.license)}\"," +
                "\"authMode\":\"${p4BuildJson(entry.authMode)}\"," +
                "\"assemblyRole\":\"${p4BuildJson(entry.assemblyRole)}\"," +
                "\"outputKind\":\"${p4BuildJson(entry.outputKind)}\"}")
        } else {
            let inputs = entry.inputHashes.toArray(); sort(inputs)
            var renderedInputs = "["
            for (i in 0..inputs.size) {
                if (i > 0) { renderedInputs += "," }
                renderedInputs += "\"${inputs[i]}\""
            }
            renderedInputs += "]"
            rows.add("{\"sourceId\":\"${p4BuildJson(entry.sourceId)}\"," +
                "\"sourceType\":\"generated\"," +
                "\"generatorId\":\"${p4BuildJson(entry.generatorId)}\"," +
                "\"generatorVersion\":\"${p4BuildJson(entry.generatorVersion)}\"," +
                "\"generatorSourceHash\":\"${entry.generatorSourceHash}\"," +
                "\"inputHashes\":${renderedInputs}," +
                "\"outputHash\":\"${entry.outputHash}\"," +
                "\"outputPath\":\"${p4BuildJson(entry.outputPath)}\"," +
                "\"license\":\"${p4BuildJson(entry.license)}\"," +
                "\"assemblyRole\":\"${p4BuildJson(entry.assemblyRole)}\"," +
                "\"outputKind\":\"${p4BuildJson(entry.outputKind)}\"}")
        }
    }
    let ordered = rows.toArray(); sort(ordered)
    "{\"schemaVersion\":\"ckb-source-lock-v1\",\"sources\":[" +
        p4BuildJoin(ordered, ",") + "]}"
}

private func p4BuildJson(value: String): String {
    let out = StringBuilder()
    let hex = "0123456789abcdef".toRuneArray()
    for (rune in value.runes()) {
        if (rune == r'"') { out.append("\\\"") }
        else if (rune == r'\\') { out.append("\\\\") }
        else if (rune == r'\n') { out.append("\\n") }
        else if (rune == r'\r') { out.append("\\r") }
        else if (rune == r'\t') { out.append("\\t") }
        else if (UInt32(rune) < 0x20u32) {
            let code = UInt32(rune); out.append("\\u00")
            out.append(hex[Int64(code / 16u32)])
            out.append(hex[Int64(code % 16u32)])
        } else { out.append(rune) }
    }
    out.toString()
}

public func validateCkbReproBuildLocks(lock: CkbReproSourceLock): CkbReproContractResult {
    if (lock.schemaVersion != "ckb-source-lock-v1" || lock.entries.size == 0) {
        return p4BuildFailure("source_lock_contract_invalid")
    }
    let ids = HashSet<String>()
    for (entry in lock.entries) {
        if (entry.sourceId == "" || ids.contains(entry.sourceId) ||
            entry.license == "" || entry.assemblyRole == "" ||
            entry.outputKind == "" || p4BuildEvaluationKind(entry.outputKind)) {
            return p4BuildFailure("source_lock_identity_invalid")
        }
        ids.add(entry.sourceId)
        if (entry.sourceType == "external_git") {
            if (entry.generatorId != "" || entry.generatorVersion != "" ||
                entry.generatorSourceHash != "" || entry.inputHashes.size > 0 ||
                entry.outputHash != "" || entry.outputPath != "") {
                return p4BuildFailure("external_source_fields_mixed")
            }
            if (!p4BuildAnonymousHttps(entry.repository) || !p4BuildCommit(entry.commit) ||
                !p4BuildHash(entry.tree) || !p4BuildSafeRelative(entry.path) ||
                !p4BuildSafeRelative(ckbReproSourceAssemblyPath(entry)) ||
                !p4BuildHash(entry.fileHash) || entry.authMode != "anonymous") {
                return p4BuildFailure("external_source_contract_invalid")
            }
        } else if (entry.sourceType == "generated") {
            if (entry.repository != "" || entry.commit != "" || entry.tree != "" ||
                entry.path != "" || entry.assemblyPath != "" ||
                entry.fileHash != "" || entry.authMode != "") {
                return p4BuildFailure("generated_source_fields_mixed")
            }
            if (entry.generatorId == "" || entry.generatorVersion == "" ||
                !p4BuildHash(entry.generatorSourceHash) || entry.inputHashes.size == 0 ||
                !p4BuildHash(entry.outputHash) ||
                !p4BuildSafeRelative(entry.outputPath)) {
                return p4BuildFailure("generated_source_contract_invalid")
            }
            for (hash in entry.inputHashes) {
                if (!p4BuildHash(hash)) {
                    return p4BuildFailure("generated_input_hash_invalid")
                }
            }
        } else {
            return p4BuildFailure("source_type_unknown")
        }
    }
    p4BuildSuccess()
}

public func ckbReproSourceAssemblyPath(
    entry: CkbReproSourceLockEntry): String {
    if (entry.sourceType == "external_git") {
        if (entry.assemblyPath == "") { entry.path } else { entry.assemblyPath }
    } else { entry.outputPath }
}

public func canonicalCkbReproSourceLockHash(lock: CkbReproSourceLock): String {
    let rows = ArrayList<String>()
    for (entry in lock.entries) {
        let inputs = entry.inputHashes.toArray(); sort(inputs)
        rows.add(p4BuildFields([
            entry.sourceId, entry.sourceType, entry.repository, entry.commit, entry.tree,
            entry.path, ckbReproSourceAssemblyPath(entry), entry.fileHash,
            entry.license, entry.authMode, entry.generatorId,
            entry.generatorVersion, entry.generatorSourceHash,
            p4BuildJoin(inputs, ","), entry.outputHash, entry.outputPath,
            entry.assemblyRole,
            entry.outputKind
        ]))
    }
    let ordered = rows.toArray(); sort(ordered)
    benchmarkGapSha256("ckb-source-lock-v1|" + p4BuildJoin(ordered, "\n"))
}

public func canonicalCkbReproSourceLockEntryHash(
    entry: CkbReproSourceLockEntry): String {
    let inputs = entry.inputHashes.toArray(); sort(inputs)
    benchmarkGapSha256("ckb-source-lock-entry-v1|" + p4BuildFields([
        entry.sourceId, entry.sourceType, entry.repository, entry.commit,
        entry.tree, entry.path, ckbReproSourceAssemblyPath(entry),
        entry.fileHash, entry.license, entry.authMode,
        entry.generatorId, entry.generatorVersion, entry.generatorSourceHash,
        p4BuildJoin(inputs, ","), entry.outputHash, entry.outputPath,
        entry.assemblyRole,
        entry.outputKind
    ]))
}

public class CkbReproKnowledgeInventoryRow {
    public var identity: String = ""
    public var sourceId: String = ""
    public var recordKind: String = ""
    public var portableLocator: String = ""
    public var sourceType: String = ""
    public var license: String = ""
    public var sourceLockEntryHash: String = ""
    public init() {}
}

public class CkbReproKnowledgeSelectionRow {
    public var identity: String = ""
    public var recordKind: String = ""
    public var decision: String = ""
    public var reason: String = ""
    public init() {}
}

public class CkbReproSourceCoverageResult {
    public var ready: Bool = false
    public var diagnostic: String = "source_coverage_not_validated"
    public var inventoryCount: Int64 = 0
    public var selectedCount: Int64 = 0
    public var excludedCount: Int64 = 0
    public var expectedSelectedCount: Int64 = 0
    public init() {}
}

public func inventoryCkbCurrentKnowledgeSources(
    typed: ArrayList<CangjieTypedRecord>, raw: ArrayList<RawRecord>,
    lock: CkbReproSourceLock): ArrayList<CkbReproKnowledgeInventoryRow> {
    let rows = ArrayList<CkbReproKnowledgeInventoryRow>()
    for (record in typed) {
        let row = CkbReproKnowledgeInventoryRow()
        row.identity = ckbReproPublicTypedRecordIdentity(record)
        let source = ckbP4InventorySource(record.path, record.sourceSet, lock)
        match (source) {
            case Some(value) =>
                row.sourceId = value.sourceId
                row.sourceType = value.sourceType
                row.license = value.license
                row.sourceLockEntryHash =
                    canonicalCkbReproSourceLockEntryHash(value)
            case None => ()
        }
        row.recordKind = record.recordKind
        row.portableLocator = record.path; rows.add(row)
    }
    for (record in raw) {
        let row = CkbReproKnowledgeInventoryRow()
        row.identity = ckbReproPublicRawRecordIdentity(record)
        let source = ckbP4InventorySource(record.metadata.path,
            record.metadata.sourceSet, lock)
        match (source) {
            case Some(value) =>
                row.sourceId = value.sourceId
                row.sourceType = value.sourceType
                row.license = value.license
                row.sourceLockEntryHash =
                    canonicalCkbReproSourceLockEntryHash(value)
            case None => ()
        }
        row.recordKind = "raw"
        row.portableLocator = record.metadata.path; rows.add(row)
    }
    rows
}

private func ckbP4InventorySource(path: String, sourceSet: String,
    lock: CkbReproSourceLock): ?CkbReproSourceLockEntry {
    let pathMatches = ArrayList<CkbReproSourceLockEntry>()
    var bestLength: Int64 = -1
    for (source in lock.entries) {
        let relative = ckbReproSourceAssemblyPath(source)
        if (path == relative || path.endsWith("/${relative}")) {
            if (relative.size > bestLength) {
                pathMatches.clear(); bestLength = relative.size
                pathMatches.add(source)
            } else if (relative.size == bestLength) {
                pathMatches.add(source)
            }
        }
    }
    if (pathMatches.size == 1) { return Some(pathMatches[0]) }
    var matched: ?CkbReproSourceLockEntry = None
    for (source in pathMatches) {
        if (!ckbP4InventoryRoleMatches(sourceSet, source.assemblyRole)) { continue }
        match (matched) {
            case Some(_) => return None<CkbReproSourceLockEntry>
            case None => matched = Some(source)
        }
    }
    matched
}

private func ckbP4InventoryRoleMatches(sourceSet: String, role: String): Bool {
    (sourceSet == CangjieSourceSets.DOCS &&
        (role == "docs" || role == "community_docs")) ||
    (sourceSet == CangjieSourceSets.TOOLS &&
        (role == "tools" || role == "tool_docs")) ||
    (sourceSet == CangjieSourceSets.STD &&
        (role == "std" || role == "std_source")) ||
    (sourceSet == CangjieSourceSets.STDX &&
        (role == "stdx" || role == "stdx_source")) ||
    (sourceSet == "knowledge-atoms" && role == "generated_guidance")
}

public func buildCkbKnowledgeSelectionManifest(
    inventory: ArrayList<CkbReproKnowledgeInventoryRow>):
    ArrayList<CkbReproKnowledgeSelectionRow> {
    let rows = ArrayList<CkbReproKnowledgeSelectionRow>()
    for (item in inventory) {
        let row = CkbReproKnowledgeSelectionRow()
        row.identity = item.identity; row.recordKind = item.recordKind
        if (p4BuildEvaluationKind(item.recordKind)) {
            row.decision = "excluded"; row.reason = "evaluation_plane"
        } else {
            row.decision = "selected"; row.reason = "knowledge_plane"
        }
        rows.add(row)
    }
    rows
}

public func validateCkbSourceCoverage(inventory: ArrayList<CkbReproKnowledgeInventoryRow>,
    selection: ArrayList<CkbReproKnowledgeSelectionRow>,
    expectedSelectedCount: Int64): CkbReproSourceCoverageResult {
    let result = CkbReproSourceCoverageResult()
    result.inventoryCount = inventory.size
    result.expectedSelectedCount = expectedSelectedCount
    let inventoryIds = HashSet<String>()
    for (row in inventory) {
        if (row.identity == "" || inventoryIds.contains(row.identity)) {
            result.diagnostic = "source_inventory_duplicate"; return result
        }
        if (row.portableLocator.startsWith("/") || row.license == "") {
            result.diagnostic = "source_inventory_not_portable"; return result
        }
        inventoryIds.add(row.identity)
    }
    let selectedIds = HashSet<String>()
    for (row in selection) {
        if (!inventoryIds.contains(row.identity) || selectedIds.contains(row.identity)) {
            result.diagnostic = "source_selection_mapping_invalid"; return result
        }
        selectedIds.add(row.identity)
        if (row.decision == "selected") {
            if (p4BuildEvaluationKind(row.recordKind)) {
                result.diagnostic = "eval_support_selection_forbidden"; return result
            }
            result.selectedCount += 1
        } else if (row.decision == "excluded") {
            result.excludedCount += 1
        } else {
            result.diagnostic = "source_selection_decision_invalid"; return result
        }
    }
    if (selectedIds.size != inventoryIds.size ||
        result.selectedCount != expectedSelectedCount) {
        result.diagnostic = "source_coverage_count_mismatch"; return result
    }
    result.ready = true; result.diagnostic = "ok"; result
}

public class CkbReproSourceMaterialEntry {
    public var sourceId: String = ""
    public var action: String = ""
    public var expectedHash: String = ""
    public var relativePath: String = ""
    public var canonicalIdentity: String = ""
    public init() {}
}

public class CkbReproSourceMaterialsManifest {
    public var ready: Bool = false
    public var diagnostic: String = "source_materials_not_built"
    public var entries: ArrayList<CkbReproSourceMaterialEntry> =
        ArrayList<CkbReproSourceMaterialEntry>()
    public init() {}
}

public class CkbReproBackendResult {
    public var ok: Bool = false
    public var value: String = ""
    public init(ok: Bool, value: String) { this.ok = ok; this.value = value }
}

public interface CkbReproSourceMaterialBackend {
    func fetch(entry: CkbReproSourceMaterialEntry): CkbReproBackendResult
    func generate(entry: CkbReproSourceMaterialEntry): CkbReproBackendResult
}

public func buildCkbSourceMaterialsManifest(
    lock: CkbReproSourceLock): CkbReproSourceMaterialsManifest {
    let manifest = CkbReproSourceMaterialsManifest()
    let contract = validateCkbReproBuildLocks(lock)
    if (!contract.ok) { manifest.diagnostic = contract.diagnostic; return manifest }
    let sourceLockHash = canonicalCkbReproSourceLockHash(lock)
    for (source in lock.entries) {
        let entry = CkbReproSourceMaterialEntry()
        entry.sourceId = source.sourceId
        entry.action = if (source.sourceType == "external_git") {
            "fetch_required"
        } else { "build_required" }
        entry.expectedHash = if (source.sourceType == "external_git") {
            source.fileHash
        } else { source.outputHash }
        entry.relativePath = ckbReproSourceAssemblyPath(source)
        entry.canonicalIdentity = benchmarkGapSha256(
            p4BuildFields([source.sourceId, source.sourceType,
                sourceLockHash, entry.relativePath,
                entry.expectedHash]))
        manifest.entries.add(entry)
    }
    manifest.ready = true; manifest.diagnostic = "ok"; manifest
}

public func renderCkbSourceMaterialsManifest(
    manifest: CkbReproSourceMaterialsManifest): String {
    let rows = ArrayList<String>()
    for (entry in manifest.entries) {
        rows.add("${entry.sourceId}|${entry.action}|${entry.relativePath}|" +
            "${entry.expectedHash}|${entry.canonicalIdentity}")
    }
    let ordered = rows.toArray(); sort(ordered)
    p4BuildJoin(ordered, "\n")
}

public func fetchAndValidateCkbSourceMaterials(manifest: CkbReproSourceMaterialsManifest,
    backend: CkbReproSourceMaterialBackend): CkbReproContractResult {
    if (!manifest.ready) { return p4BuildFailure(manifest.diagnostic) }
    for (entry in manifest.entries) {
        if (entry.action != "fetch_required") { continue }
        let fetched = backend.fetch(entry)
        if (!fetched.ok || fetched.value != entry.expectedHash) {
            return p4BuildFailure("source_material_fetch_mismatch")
        }
    }
    p4BuildSuccess()
}

public func generateAndValidateCkbSourceMaterials(
    manifest: CkbReproSourceMaterialsManifest,
    backend: CkbReproSourceMaterialBackend): CkbReproContractResult {
    if (!manifest.ready) { return p4BuildFailure(manifest.diagnostic) }
    for (entry in manifest.entries) {
        if (entry.action != "build_required") { continue }
        let generated = backend.generate(entry)
        if (!generated.ok || generated.value != entry.expectedHash) {
            return p4BuildFailure("source_material_generate_mismatch")
        }
    }
    p4BuildSuccess()
}

public class CkbReproPipelineInput {
    public var request: CkbReproBuildRequest = CkbReproBuildRequest()
    public var selectedTyped: ArrayList<CangjieTypedRecord> =
        ArrayList<CangjieTypedRecord>()
    public var portableTyped: ArrayList<CangjieTypedRecord> =
        ArrayList<CangjieTypedRecord>()
    public var portableRaw: ArrayList<RawRecord> = ArrayList<RawRecord>()
    public init() {}
}

public interface CkbReproBuildBackend {
    func run(stage: String, input: CkbReproPipelineInput): CkbReproBackendResult
}

public class CkbReproBuildRequest {
    public var options: CkbReproBuildOptions = CkbReproBuildOptions()
    public var sourceLock: CkbReproSourceLock = CkbReproSourceLock()
    public var inventory: ArrayList<CkbReproKnowledgeInventoryRow> =
        ArrayList<CkbReproKnowledgeInventoryRow>()
    public var selection: ArrayList<CkbReproKnowledgeSelectionRow> =
        ArrayList<CkbReproKnowledgeSelectionRow>()
    public var pathContext: CkbPortablePathContext = CkbPortablePathContext()
    public var typedInput: ArrayList<CangjieTypedRecord> = ArrayList<CangjieTypedRecord>()
    public var rawInput: ArrayList<RawRecord> = ArrayList<RawRecord>()
    public var candidateVersion: String = ""
    public var evalSupportAuthority: CangjieEvalSupportSnapshot =
        CangjieEvalSupportSnapshot()
    public var leakageAuthority: CangjieBenchmarkLeakageAuthority =
        CangjieBenchmarkLeakageAuthority()
    public var leakageAuthorityHash: String = ""
    public init() {}
}

public class CkbReproProductionBuildBackend <: CkbReproBuildBackend {
    private var kb: KnowledgeBase = KnowledgeBase(FakeClock(0))
    private var candidate: CkbCompleteCleanStudentCandidate =
        CkbCompleteCleanStudentCandidate()
    private var persisted: CkbCleanCandidateBuildResult =
        CkbCleanCandidateBuildResult()
    private var materialized: CkbCandidateRuntimeMaterializeResult =
        CkbCandidateRuntimeMaterializeResult()

    public init() {}

    public func run(stage: String,
        input: CkbReproPipelineInput): CkbReproBackendResult {
        if (stage == "assemble") { return this.assemble(input) }
        if (stage == "validate_authority") { return this.validateAuthority(input) }
        if (stage == "load_first_init") { return this.loadFirstInit(input) }
        if (stage == "validate_serving") { return this.validateServing(input) }
        if (stage == "clean") { return this.clean(input) }
        if (stage == "leakage") { return this.leakage(input) }
        if (stage == "materialize") { return this.materialize(input) }
        if (stage == "logical_scan") { return this.logicalScan(input) }
        CkbReproBackendResult(false, "build_stage_unknown")
    }

    private func assemble(input: CkbReproPipelineInput): CkbReproBackendResult {
        this.kb = KnowledgeBase(FakeClock(0))
        this.candidate = CkbCompleteCleanStudentCandidate()
        this.persisted = CkbCleanCandidateBuildResult()
        this.materialized = CkbCandidateRuntimeMaterializeResult()
        if (input.request.candidateVersion == "" ||
            input.selectedTyped.size == 0 || input.portableTyped.size == 0) {
            return CkbReproBackendResult(false, "portable_build_input_empty")
        }
        let deduped = dedupeCkbFirstInitializationRecords(input.selectedTyped)
        CkbReproBackendResult(deduped.size == input.selectedTyped.size,
            if (deduped.size == input.selectedTyped.size) { "ok" }
            else { "portable_build_dedupe_count_mismatch" })
    }

    private func validateAuthority(input: CkbReproPipelineInput): CkbReproBackendResult {
        let validated = validateCkbFirstInitializationRecords(
            input.portableTyped, input.request.evalSupportAuthority)
        CkbReproBackendResult(validated.ok,
            if (validated.ok) { "ok" } else { "first_init_authority_invalid" })
    }

    private func loadFirstInit(input: CkbReproPipelineInput): CkbReproBackendResult {
        let version = input.request.candidateVersion
        let loaded = this.kb.loadFirstInitializationTypedRecords(
            input.selectedTyped, version)
        CkbReproBackendResult(loaded == version &&
            this.kb.candidateRecordSnapshot().size == input.selectedTyped.size,
            if (loaded == version) { "ok" } else { "first_init_load_failed" })
    }

    private func validateServing(input: CkbReproPipelineInput): CkbReproBackendResult {
        let result = validateCandidateServingIndex(
            this.kb.candidateRecordSnapshot(), input.request.candidateVersion)
        CkbReproBackendResult(result.ok,
            if (result.ok) { "ok" } else { result.status })
    }

    private func clean(input: CkbReproPipelineInput): CkbReproBackendResult {
        let raw = ArrayList<RawRecord>()
        let normalized = ArrayList<NormalizedRecord>()
        for (record in input.selectedTyped) {
            let metadata = KnowledgeMetadata()
            let value = cangjieTypedRecordToNormalized(record, metadata)
            let source = RawRecord(); source.sourceId = value.sourceId
            source.title = value.title; source.content = value.chunk
            source.metadata = value.metadata; source.contentHash = record.contentHash
            source.requiresReview = value.requiresReview
            raw.add(source); normalized.add(value)
        }
        let normalizer = Normalizer()
        for (record in input.portableRaw) {
            raw.add(record)
            let value = normalizer.normalize(record, "",
                input.request.candidateVersion)
            value.recordKind = if (record.metadata.sourceSet ==
                CangjieSourceSets.KNOWLEDGE_ATOMS) {
                CangjieTypedRecordKinds.KNOWLEDGE_ATOM
            } else { CangjieTypedRecordKinds.DOC_SECTION }
            normalized.add(value)
        }
        this.candidate = ckbBuildCompleteCleanStudentCandidate(
            ArrayList<RawRecord>(), ArrayList<NormalizedRecord>(),
            ArrayList<NormalizedRecord>(), raw, normalized, normalized,
            input.request.candidateVersion,
            authorityHash: input.request.leakageAuthorityHash,
            authority: input.request.leakageAuthority)
        CkbReproBackendResult(this.candidate.ok, this.candidate.diagnostic)
    }

    private func leakage(input: CkbReproPipelineInput): CkbReproBackendResult {
        let leakage = validateCangjieStudentKnowledgeRecords(
            this.candidate.normalizedRecords,
            authority: input.request.leakageAuthority)
        if (!leakage.ok) {
            return CkbReproBackendResult(false, leakage.code)
        }
        let visible = CkbStudentVisiblePathInput()
        visible.rawRecords = this.candidate.rawRecords
        visible.normalizedRecords = this.candidate.normalizedRecords
        visible.activeRecords = this.candidate.activeRecords
        let paths = scanCkbStudentVisiblePaths(visible, input.request.pathContext)
        CkbReproBackendResult(paths.ready, paths.diagnostic)
    }

    private func materialize(input: CkbReproPipelineInput): CkbReproBackendResult {
        let staging = FileKnowledgeStore(input.request.options.temporaryRoot)
        this.persisted = ckbPersistCompleteCleanStudentCandidate(staging,
            this.candidate)
        if (!this.persisted.ok) {
            return CkbReproBackendResult(false, this.persisted.diagnostic)
        }
        let options = CkbCandidateRuntimeMaterializeOptions()
        options.sourceStore = input.request.options.temporaryRoot
        options.outputStore = input.request.options.outputRoot
        options.candidateVersion = input.request.candidateVersion
        this.materialized = ckbMaterializeCandidateRuntime(options)
        CkbReproBackendResult(this.materialized.ok, this.materialized.diagnostic)
    }

    private func logicalScan(input: CkbReproPipelineInput): CkbReproBackendResult {
        let store = FileKnowledgeStore(input.request.options.outputRoot)
        let snapshot = store.loadActiveSnapshot()
        let metadata = store.loadMetadataStatus()
        if (!snapshot.valid || !metadata.valid ||
            snapshot.rawRecords.size != this.candidate.rawRecords.size ||
            snapshot.normalizedRecords.size != this.candidate.normalizedRecords.size ||
            snapshot.activeIndex.size != this.candidate.activeRecords.size ||
            metadata.vectorState != EmbeddingProviderState.DEGRADED ||
            metadata.vectorDegradedReason != "vector_snapshot_missing" ||
            metadata.vectorIndexCount != 0) {
            return CkbReproBackendResult(false, "portable_logical_scan_failed")
        }
        let visible = CkbStudentVisiblePathInput()
        visible.rawRecords = snapshot.rawRecords
        visible.normalizedRecords = snapshot.normalizedRecords
        visible.activeRecords = snapshot.activeIndex
        let paths = scanCkbStudentVisiblePaths(visible, input.request.pathContext)
        CkbReproBackendResult(paths.ready, paths.diagnostic)
    }
}

public class CkbReproBuildProof {
    public var logicalReady: Bool = false
    public var diagnostic: String = "not_built"
    public var sourceLockHash: String = ""
    public var typedCount: Int64 = 0
    public var rawCount: Int64 = 0
    public var selectedCount: Int64 = 0
    public var excludedCount: Int64 = 0
    public var evalSupportPersisted: Int64 = 0
    public var vectorCount: Int64 = 0
    public var vectorState: String = "DEGRADED"
    public var candidateVersion: String = ""
    public var typedPairAggregateHash: String = ""
    public var rawPairAggregateHash: String = ""
    public var preservationHash: String = ""
    public init() {}
}

public func ckbReproBuildPreservationHash(proof: CkbReproBuildProof): String {
    benchmarkGapSha256("ckb-repro-build-proof-v1|" + p4BuildFields([
        proof.candidateVersion, proof.sourceLockHash,
        proof.typedCount.toString(), proof.rawCount.toString(),
        proof.selectedCount.toString(), proof.excludedCount.toString(),
        proof.typedPairAggregateHash, proof.rawPairAggregateHash
    ]))
}

public class CkbReproBuildResult {
    public var ready: Bool = false
    public var diagnostic: String = "build_not_run"
    public var proof: CkbReproBuildProof = CkbReproBuildProof()
    public init() {}
}

public func selectCkbPortableFirstInitKnowledgeRecords(
    records: ArrayList<CangjieTypedRecord>,
    selection: ArrayList<CkbReproKnowledgeSelectionRow>):
    (CkbReproContractResult, ArrayList<CangjieTypedRecord>) {
    for (row in selection) {
        if (row.decision == "selected" && p4BuildEvaluationKind(row.recordKind)) {
            return (p4BuildFailure("eval_support_selection_forbidden"),
                ArrayList<CangjieTypedRecord>())
        }
    }
    let out = ArrayList<CangjieTypedRecord>()
    for (record in records) {
        if (!p4BuildEvaluationKind(record.recordKind)) { out.add(record) }
    }
    (p4BuildSuccess(), out)
}

public func runCkbReproOfficialPipeline(input: CkbReproPipelineInput,
    backend: CkbReproBuildBackend):
    CkbReproContractResult {
    for (stage in ["assemble", "validate_authority", "load_first_init",
        "validate_serving", "clean", "leakage", "materialize", "logical_scan"]) {
        if (!backend.run(stage, input).ok) {
            return p4BuildFailure("build_stage_failed:${stage}")
        }
    }
    p4BuildSuccess()
}

public func runCkbReproBuild(request: CkbReproBuildRequest,
    backend: CkbReproBuildBackend): CkbReproBuildResult {
    let result = CkbReproBuildResult()
    let lock = validateCkbReproBuildLocks(request.sourceLock)
    if (!lock.ok) { result.diagnostic = lock.diagnostic; return result }
    if (request.options.outputRoot == "" || request.options.temporaryRoot == "" ||
        request.options.outputRoot == request.options.temporaryRoot) {
        result.diagnostic = "build_roots_invalid"; return result
    }
    for (row in request.selection) {
        if (row.decision == "selected" && p4BuildEvaluationKind(row.recordKind)) {
            result.diagnostic = "eval_support_selection_forbidden"; return result
        }
    }
    let coverage = validateCkbSourceCoverage(
        request.inventory, request.selection, request.options.expectedRawCount)
    if (!coverage.ready) { result.diagnostic = coverage.diagnostic; return result }
    let selected = selectCkbPortableFirstInitKnowledgeRecords(
        request.typedInput, request.selection)
    if (!selected[0].ok) { result.diagnostic = selected[0].diagnostic; return result }
    let typedOutput = ArrayList<CangjieTypedRecord>()
    for (record in request.typedInput) {
        let normalized = normalizeCkbTypedRecordPortablePaths(record, request.pathContext)
        if (!normalized.ok) { result.diagnostic = normalized.diagnostic; return result }
        typedOutput.add(normalized.record)
    }
    let rawOutput = ArrayList<RawRecord>()
    for (record in request.rawInput) {
        let normalized = normalizeCkbRawRecordPortablePaths(record, request.pathContext)
        if (!normalized.ok) { result.diagnostic = normalized.diagnostic; return result }
        rawOutput.add(normalized.record)
    }
    let selectedOutput = ArrayList<CangjieTypedRecord>()
    for (record in selected[1]) {
        let normalized = normalizeCkbTypedRecordPortablePaths(record, request.pathContext)
        if (!normalized.ok) { result.diagnostic = normalized.diagnostic; return result }
        selectedOutput.add(normalized.record)
    }
    let preservation = buildCkbPortableRecordPreservationProof(
        request.typedInput.toArray(), typedOutput.toArray(),
        request.rawInput.toArray(), rawOutput.toArray(), request.pathContext)
    if (!preservation.ready) {
        result.diagnostic = preservation.diagnostic; return result
    }
    let pipelineInput = CkbReproPipelineInput()
    pipelineInput.request = request
    pipelineInput.selectedTyped = selectedOutput
    pipelineInput.portableTyped = typedOutput
    pipelineInput.portableRaw = rawOutput
    let pipeline = runCkbReproOfficialPipeline(pipelineInput, backend)
    if (!pipeline.ok) { result.diagnostic = pipeline.diagnostic; return result }
    result.proof.logicalReady = true; result.proof.diagnostic = "ok"
    result.proof.sourceLockHash = canonicalCkbReproSourceLockHash(request.sourceLock)
    result.proof.typedCount = typedOutput.size; result.proof.rawCount = rawOutput.size
    result.proof.selectedCount = coverage.selectedCount
    result.proof.excludedCount = coverage.excludedCount
    result.proof.evalSupportPersisted = 0
    result.proof.vectorCount = 0; result.proof.vectorState = "DEGRADED"
    result.proof.candidateVersion = request.candidateVersion
    result.proof.typedPairAggregateHash = preservation.typedPairAggregateHash
    result.proof.rawPairAggregateHash = preservation.rawPairAggregateHash
    result.proof.preservationHash = ckbReproBuildPreservationHash(result.proof)
    result.ready = true; result.diagnostic = "ok"; result
}

public func renderCkbReproBuildProof(proof: CkbReproBuildProof): String {
    "{\"logicalReady\":${proof.logicalReady},\"diagnostic\":\"${p4BuildEscape(proof.diagnostic)}\"," +
    "\"sourceLockHash\":\"${proof.sourceLockHash}\",\"typedCount\":${proof.typedCount}," +
    "\"rawCount\":${proof.rawCount},\"selectedCount\":${proof.selectedCount}," +
    "\"excludedCount\":${proof.excludedCount},\"evalSupportPersisted\":" +
    "${proof.evalSupportPersisted},\"vectorCount\":${proof.vectorCount}," +
    "\"vectorState\":\"${proof.vectorState}\",\"candidateVersion\":" +
    "\"${p4BuildEscape(proof.candidateVersion)}\",\"typedPairAggregateHash\":" +
    "\"${proof.typedPairAggregateHash}\",\"rawPairAggregateHash\":" +
    "\"${proof.rawPairAggregateHash}\",\"preservationHash\":" +
    "\"${proof.preservationHash}\"}"
}

public func parseCkbReproBuildProof(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbReproBuildProof) {
    let proof = CkbReproBuildProof()
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (p4BuildFailure("invalid_response_encoding"), proof)
    }
    try {
        let object = JsonValue.fromStr(text).asObject()
        if (object.size() != 14) {
            return (p4BuildFailure("build_proof_field_contract_invalid"),
                proof)
        }
        proof.logicalReady = p4BuildRequiredBool(object, "logicalReady")
        proof.diagnostic = p4BuildRequiredString(object, "diagnostic")
        proof.sourceLockHash = p4BuildRequiredString(object, "sourceLockHash")
        proof.typedCount = p4BuildRequiredInt(object, "typedCount")
        proof.rawCount = p4BuildRequiredInt(object, "rawCount")
        proof.selectedCount = p4BuildRequiredInt(object, "selectedCount")
        proof.excludedCount = p4BuildRequiredInt(object, "excludedCount")
        proof.evalSupportPersisted = p4BuildRequiredInt(
            object, "evalSupportPersisted")
        proof.vectorCount = p4BuildRequiredInt(object, "vectorCount")
        proof.vectorState = p4BuildRequiredString(object, "vectorState")
        proof.candidateVersion = p4BuildRequiredString(
            object, "candidateVersion")
        proof.typedPairAggregateHash = p4BuildRequiredString(
            object, "typedPairAggregateHash")
        proof.rawPairAggregateHash = p4BuildRequiredString(
            object, "rawPairAggregateHash")
        proof.preservationHash = p4BuildRequiredString(
            object, "preservationHash")
    } catch (_: Exception) {
        return (p4BuildFailure("build_proof_malformed_json"),
            CkbReproBuildProof())
    }
    if (!proof.logicalReady || proof.diagnostic != "ok" ||
        !p4BuildHash(proof.sourceLockHash) || proof.typedCount < 1 ||
        proof.rawCount < 1 || proof.selectedCount < 1 ||
        proof.selectedCount + proof.excludedCount != proof.rawCount ||
        proof.evalSupportPersisted != 0 || proof.vectorCount != 0 ||
        proof.vectorState != "DEGRADED" || proof.candidateVersion == "" ||
        !p4BuildHash(proof.typedPairAggregateHash) ||
        !p4BuildHash(proof.rawPairAggregateHash) ||
        proof.preservationHash != ckbReproBuildPreservationHash(proof) ||
        renderCkbReproBuildProof(proof) != text) {
        return (p4BuildFailure("build_proof_invalid"),
            CkbReproBuildProof())
    }
    (p4BuildSuccess(), proof)
}

public class CkbPortablePromotionOptions {
    public var productionStore: String = ""
    public var qdrantEndpoint: String = ""
    public var expectedActiveVersion: String = ""
    public var expectedPointerHash: String = ""
    public var candidateVersion: String = ""
    public var candidateManifestHash: String = ""
    public var p2ProofHash: String = ""
    public var p3ProofHash: String = ""
    public var p5ProofHash: String = ""
    public var p8AProofHash: String = ""
    public var identity: String = ""
    public var p8StrictPassed: Int64 = 0
    public var apply: Bool = false
    public init() {}
}

public func parseCkbPortablePromotionOptions(args: Array<String>):
    CkbPortablePromotionOptions {
    let options = CkbPortablePromotionOptions()
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "--apply") { options.apply = true; i += 1; continue }
        if (i + 1 >= args.size) { break }
        let value = args[i + 1].trimAscii()
        if (arg == "--production-store") { options.productionStore = value }
        else if (arg == "--qdrant-endpoint") { options.qdrantEndpoint = value }
        else if (arg == "--expected-active-version") {
            options.expectedActiveVersion = value
        } else if (arg == "--expected-pointer-hash") {
            options.expectedPointerHash = value
        } else if (arg == "--candidate-version") { options.candidateVersion = value }
        else if (arg == "--candidate-manifest-hash") {
            options.candidateManifestHash = value
        }
        i += 2
    }
    options
}

public func validateCkbPortablePromotionInputs(
    options: CkbPortablePromotionOptions): CkbReproContractResult {
    if (!options.apply) { return p4BuildFailure("promotion_apply_required") }
    if (options.productionStore == "" || !exists(Path(options.productionStore))) {
        return p4BuildFailure("promotion_store_invalid")
    }
    let canonical = try { canonicalize(Path(options.productionStore)).toString() }
        catch (_: Exception) { return p4BuildFailure("promotion_store_invalid") }
    if (canonical != options.productionStore ||
        !(options.qdrantEndpoint.startsWith("http://") ||
          options.qdrantEndpoint.startsWith("https://"))) {
        return p4BuildFailure("promotion_target_invalid")
    }
    if (options.expectedActiveVersion == "" || !p4BuildHash(options.expectedPointerHash) ||
        options.candidateVersion == "" || options.identity == "" ||
        options.p8StrictPassed != 151) {
        return p4BuildFailure("promotion_identity_invalid")
    }
    for (hash in [options.candidateManifestHash, options.p2ProofHash,
        options.p3ProofHash, options.p5ProofHash, options.p8AProofHash]) {
        if (!p4BuildHash(hash)) { return p4BuildFailure("promotion_proof_missing") }
    }
    p4BuildSuccess()
}

public class CkbPortablePromotionState {
    public var activeVersion: String = ""
    public var pointerHash: String = ""
    public var vectorCollection: String = ""
    public init(activeVersion: String, pointerHash: String, vectorCollection: String) {
        this.activeVersion = activeVersion; this.pointerHash = pointerHash
        this.vectorCollection = vectorCollection
    }
}

public interface CkbPortablePromotionBackend {
    func readCurrent(): CkbPortablePromotionState
    func restoreVector(options: CkbPortablePromotionOptions): Bool
    func validateVector(options: CkbPortablePromotionOptions): Bool
    func commitPointer(options: CkbPortablePromotionOptions): Bool
    func readBack(options: CkbPortablePromotionOptions): Bool
    func cleanupOld(): Bool
    func rollback(state: CkbPortablePromotionState): Bool
    func cleanupStaging(): Unit
}

public class CkbPortableProductionPromotionBackend <:
    CkbPortablePromotionBackend {
    private let candidateStore: FileKnowledgeStore
    private let productionStore: FileKnowledgeStore
    private let snapshotBytes: Array<UInt8>
    private let snapshotPath: String
    private let fileExecutor: ?CkbQdrantSnapshotFileExecutor
    private let snapshotManifest: CkbQdrantSnapshotManifest
    private let logicalManifest: CkbLogicalSnapshotManifest
    private let targetCollection: String
    private let executor: CkbQdrantSnapshotExecutor
    private let pathContext: CkbPortablePathContext
    private var before: CkbPortablePromotionState =
        CkbPortablePromotionState("", "", "")
    private var beforeSnapshot: ActiveSnapshot = ActiveSnapshot()
    private var pointerCommitted: Bool = false

    public init(candidateStore: FileKnowledgeStore,
        productionStore: FileKnowledgeStore, snapshotBytes: Array<UInt8>,
        snapshotManifest: CkbQdrantSnapshotManifest,
        logicalManifest: CkbLogicalSnapshotManifest, targetCollection: String,
        executor: CkbQdrantSnapshotExecutor,
        pathContext: CkbPortablePathContext) {
        this.candidateStore = candidateStore
        this.productionStore = productionStore
        this.snapshotBytes = snapshotBytes
        this.snapshotPath = ""; this.fileExecutor = None
        this.snapshotManifest = snapshotManifest
        this.logicalManifest = logicalManifest
        this.targetCollection = targetCollection
        this.executor = executor; this.pathContext = pathContext
    }

    public init(candidateStore: FileKnowledgeStore,
        productionStore: FileKnowledgeStore, snapshotPath: String,
        snapshotManifest: CkbQdrantSnapshotManifest,
        logicalManifest: CkbLogicalSnapshotManifest, targetCollection: String,
        executor: CkbQdrantSnapshotExecutor,
        fileExecutor: CkbQdrantSnapshotFileExecutor,
        pathContext: CkbPortablePathContext) {
        this.candidateStore = candidateStore
        this.productionStore = productionStore
        this.snapshotBytes = Array<UInt8>()
        this.snapshotPath = snapshotPath; this.fileExecutor = Some(fileExecutor)
        this.snapshotManifest = snapshotManifest
        this.logicalManifest = logicalManifest
        this.targetCollection = targetCollection
        this.executor = executor; this.pathContext = pathContext
    }

    public func readCurrent(): CkbPortablePromotionState {
        let pointer = this.productionStore.loadActiveSnapshotPointer()
        let state = if (pointer.valid) {
            CkbPortablePromotionState(pointer.activeVersion,
                ckbActiveSnapshotPointerIdentityHash(pointer),
                pointer.vectorActiveCollection)
        } else { CkbPortablePromotionState("", "", "") }
        this.before = state
        this.beforeSnapshot = this.productionStore.loadActiveSnapshot()
        state
    }

    public func restoreVector(options: CkbPortablePromotionOptions): Bool {
        if (this.snapshotManifest.collection == "" ||
            this.snapshotManifest.logicalManifestHash !=
                this.logicalManifest.manifestHash) { return false }
        if (let Some(files) <- this.fileExecutor) {
            return restoreCkbQdrantSnapshotFromFile(this.targetCollection,
                this.snapshotPath, this.snapshotManifest, this.executor,
                files).ok
        }
        restoreCkbQdrantSnapshot(this.targetCollection,
            this.snapshotBytes, this.snapshotManifest, this.executor).ok
    }

    public func validateVector(options: CkbPortablePromotionOptions): Bool {
        let request = CkbQdrantSnapshotRequest(); request.method = "GET"
        request.path = "/collections/${this.targetCollection}"
        let response = this.executor.execute(request)
        let status = parseCkbQdrantRestoredStatus(response.bodyBytes,
            this.targetCollection, this.snapshotManifest.payloadCanonicalHash)
        if (!status[0].ok) { return false }
        let visible = CkbStoreVerificationInputProvider(
            this.candidateStore, this.pathContext)
        verifyRestoredCkbQdrantSnapshot(status[1], this.snapshotManifest,
            this.logicalManifest, visible.visibleInput(this.targetCollection),
            this.pathContext).ok
    }

    public func commitPointer(options: CkbPortablePromotionOptions): Bool {
        let snapshot = this.candidateStore.loadActiveSnapshot()
        if (!snapshot.valid || snapshot.activeVersion != options.candidateVersion) {
            return false
        }
        let kb = KnowledgeBase(FakeClock(0))
        if (!kb.restoreActiveSnapshot(snapshot)) { return false }
        kb.promoteVectorActiveCollection(this.targetCollection)
        let committed = kb.persistActiveSnapshotUsingVectorRecords(
            this.productionStore, ArrayList<VectorRecord>(),
            persistVectorFile: false,
            expectedBaseActivePointerHash: options.expectedPointerHash)
        this.pointerCommitted = committed.ok && committed.businessCommitted &&
            committed.pointerCommitted
        this.pointerCommitted
    }

    public func readBack(options: CkbPortablePromotionOptions): Bool {
        let pointer = this.productionStore.loadActiveSnapshotPointer()
        pointer.valid && pointer.activeVersion == options.candidateVersion &&
            pointer.vectorActiveCollection == this.targetCollection
    }

    public func cleanupOld(): Bool {
        if (this.before.vectorCollection == "" ||
            this.before.vectorCollection == this.targetCollection) { return true }
        let request = CkbQdrantSnapshotRequest(); request.method = "DELETE"
        request.path = "/collections/${this.before.vectorCollection}"
        let response = this.executor.execute(request)
        response.statusCode == 200 || response.statusCode == 202 ||
            response.statusCode == 404
    }

    public func rollback(state: CkbPortablePromotionState): Bool {
        if (!this.pointerCommitted || !this.beforeSnapshot.valid ||
            state.activeVersion != this.before.activeVersion ||
            state.pointerHash != this.before.pointerHash ||
            state.vectorCollection != this.before.vectorCollection) { return false }
        let current = this.productionStore.loadActiveSnapshotPointer()
        if (!current.valid) { return false }
        let kb = KnowledgeBase(FakeClock(0))
        if (!kb.restoreActiveSnapshot(this.beforeSnapshot)) { return false }
        kb.promoteVectorActiveCollection(state.vectorCollection)
        let committed = kb.persistActiveSnapshotUsingVectorRecords(
            this.productionStore, ArrayList<VectorRecord>(),
            persistVectorFile: false,
            expectedBaseActivePointerHash:
                ckbActiveSnapshotPointerIdentityHash(current))
        let rolledBack = committed.ok && committed.businessCommitted &&
            committed.pointerCommitted
        if (rolledBack) { this.pointerCommitted = false }
        rolledBack
    }

    public func cleanupStaging(): Unit {
        if (this.pointerCommitted) { return }
        let request = CkbQdrantSnapshotRequest(); request.method = "DELETE"
        request.path = "/collections/${this.targetCollection}"
        _ = this.executor.execute(request)
    }
}

public class CkbPortablePromotionResult {
    public var ready: Bool = false
    public var diagnostic: String = "promotion_not_run"
    public var pointerCommitted: Bool = false
    public var activeVersion: String = ""
    public init() {}
}

public func promoteCkbPortableCandidate(options: CkbPortablePromotionOptions,
    backend: CkbPortablePromotionBackend): CkbPortablePromotionResult {
    let result = CkbPortablePromotionResult()
    let contract = validateCkbPortablePromotionInputs(options)
    if (!contract.ok) { result.diagnostic = contract.diagnostic; return result }
    let before = backend.readCurrent()
    if (before.activeVersion != options.expectedActiveVersion ||
        before.pointerHash != options.expectedPointerHash) {
        result.diagnostic = "promotion_expected_state_drift"; return result
    }
    if (!backend.restoreVector(options)) {
        backend.cleanupStaging(); result.diagnostic = "promotion_vector_restore_failed"
        return result
    }
    if (!backend.validateVector(options)) {
        backend.cleanupStaging(); result.diagnostic = "promotion_vector_validation_failed"
        return result
    }
    if (!backend.commitPointer(options)) {
        backend.cleanupStaging(); result.diagnostic = "promotion_pointer_commit_failed"
        return result
    }
    result.pointerCommitted = true
    if (!backend.readBack(options)) {
        if (!backend.rollback(before)) {
            result.diagnostic = "promotion_rollback_failed"; return result
        }
        result.pointerCommitted = false; backend.cleanupStaging()
        result.diagnostic = "promotion_read_back_failed"; return result
    }
    if (!backend.cleanupOld()) {
        if (!backend.rollback(before)) {
            result.diagnostic = "promotion_rollback_failed"; return result
        }
        result.pointerCommitted = false; backend.cleanupStaging()
        result.diagnostic = "promotion_cleanup_old_failed"; return result
    }
    result.ready = true; result.diagnostic = "ok"
    result.activeVersion = options.candidateVersion; result
}

private func p4BuildEvaluationKind(kind: String): Bool {
    let lower = kind.toAsciiLower()
    lower == CangjieTypedRecordKinds.EVAL_SUPPORT.toAsciiLower() ||
    lower.contains("humaneval") || lower.contains("benchmark") ||
    lower.contains("teacher") || lower.contains("student_solution")
}

private func p4BuildAnonymousHttps(repository: String): Bool {
    if (!repository.startsWith("https://") || repository.contains("@") ||
        repository.contains("latest") || repository.contains("private")) { return false }
    let tail = repository["https://".size..repository.size]
    tail.contains("/") && !tail.contains(":")
}

private func p4BuildCommit(value: String): Bool {
    if (value.size != 40) { return false }
    for (rune in value.runes()) {
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) { return false }
    }
    true
}

private func p4BuildHash(value: String): Bool {
    if (!value.startsWith("sha256:") || value.size != 71) { return false }
    for (rune in value["sha256:".size..value.size].runes()) {
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) { return false }
    }
    true
}

private func p4BuildSafeRelative(value: String): Bool {
    value != "" && !value.startsWith("/") && !value.startsWith("\\") &&
    !value.contains("..") && !value.contains("\\")
}

private func p4BuildFields(values: Array<String>): String {
    var out = ""
    for (value in values) { out += "${value.toArray().size}:${value}" }
    out
}

private func p4BuildJoin(values: Array<String>, separator: String): String {
    var out = ""
    for (i in 0..values.size) {
        if (i > 0) { out += separator }
        out += values[i]
    }
    out
}

private func p4BuildEscape(value: String): String {
    let out = StringBuilder(); let hex = "0123456789abcdef".toRuneArray()
    for (rune in value.runes()) {
        if (rune == r'"') { out.append("\\\"") }
        else if (rune == r'\\') { out.append("\\\\") }
        else if (rune == r'\n') { out.append("\\n") }
        else if (rune == r'\r') { out.append("\\r") }
        else if (rune == r'\t') { out.append("\\t") }
        else if (UInt32(rune) < 0x20u32) {
            let code = UInt32(rune); out.append("\\u00")
            out.append(hex[Int64(code / 16u32)])
            out.append(hex[Int64(code % 16u32)])
        } else { out.append(rune) }
    }
    out.toString()
}

private func p4BuildSuccess(): CkbReproContractResult {
    let result = CkbReproContractResult(); result.ok = true; result.diagnostic = "ok"; result
}

private func p4BuildFailure(diagnostic: String): CkbReproContractResult {
    let result = CkbReproContractResult(); result.diagnostic = diagnostic; result
}

private func p4BuildOptionalString(object: JsonObject, key: String): String {
    match (object.get(key)) {
        case Some(value) => value.asString().getValue()
        case None => ""
    }
}

private func ckbP4ValidateBuildRoots(outputRoot: String,
    temporaryRoot: String): String {
    if (outputRoot == temporaryRoot) { return "build_roots_invalid" }
    for (value in [outputRoot, temporaryRoot]) {
        if (value == "" || value != value.trimAscii() || !value.startsWith("/") ||
            value.contains("//") || value.contains("/../") || value.contains("/./") ||
            exists(Path(value)) || !exists(Path(value).parent)) {
            return "build_root_path_invalid"
        }
        let parent = try { canonicalize(Path(value).parent).toString() }
            catch (_: Exception) { return "build_root_path_invalid" }
        if (Path(parent).join(Path(value).fileName).toString() != value) {
            return "build_root_path_invalid"
        }
    }
    "ok"
}

private func p4BuildRequiredString(object: JsonObject, key: String): String {
    object.get(key).getOrThrow().asString().getValue()
}
private func p4BuildRequiredInt(object: JsonObject, key: String): Int64 {
    object.get(key).getOrThrow().asInt().getValue()
}
private func p4BuildRequiredBool(object: JsonObject, key: String): Bool {
    object.get(key).getOrThrow().asBool().getValue()
}
