package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.env.getVariable
import std.fs.{Path, exists, remove}

class CkbReproProductionCliComposition {
    var ok: Bool = false
    var diagnostic: String = "production_composition_not_loaded"
    var json: Bool = false
    var mode: String = ""
    var manifestPath: String = ""
    var args: Array<String> = Array<String>()
    var loaded: CkbReproCliCompositionLoadResult =
        CkbReproCliCompositionLoadResult()
    public init() {}
}

interface CkbReproP4BuildCompositionExecutor {
    func execute(args: Array<String>, assembly: CkbReproP4BuildProductionAssembly):
        CkbReproMainCliResult
}

interface CkbReproP4OwnedRootCleaner {
    func cleanup(path: String): Bool
}

private class CkbReproP4ProductionBuildCompositionExecutor <:
    CkbReproP4BuildCompositionExecutor {
    public init() {}
    public func execute(args: Array<String>,
        assembly: CkbReproP4BuildProductionAssembly): CkbReproMainCliResult {
        executeCkbReproP4BuildProductionAssembly(args, assembly)
    }
}

private class CkbReproP4FilesystemOwnedRootCleaner <:
    CkbReproP4OwnedRootCleaner {
    public init() {}
    public func cleanup(path: String): Bool {
        ckbReproP4RemoveOwnedRoot(path)
    }
}

func loadCkbReproProductionCliComposition(args: Array<String>, mode: String):
    CkbReproProductionCliComposition {
    let out = CkbReproProductionCliComposition()
    out.mode = mode
    if (mode == "") {
        out.diagnostic = "production_composition_mode_invalid"; return out
    }
    let forwarded = ArrayList<String>()
    var seenManifest = false
    var i: Int64 = 0
    while (i < args.size) {
        if (args[i] == "--composition-manifest") {
            if (seenManifest || i + 1 >= args.size ||
                args[i + 1].startsWith("--")) {
                out.diagnostic = "composition_manifest_argument_invalid"
                return out
            }
            seenManifest = true; out.manifestPath = args[i + 1]; i += 2
            continue
        }
        if (args[i] == "--json") { out.json = true }
        forwarded.add(args[i]); i += 1
    }
    if (!seenManifest || !Path(out.manifestPath).isAbsolute()) {
        out.diagnostic = "production_composition_manifest_required"
        return out
    }
    out.loaded = loadCkbReproCliComposition(out.manifestPath, mode)
    if (!out.loaded.ok) {
        out.diagnostic = out.loaded.diagnostic; return out
    }
    out.args = forwarded.toArray(); out.ok = true; out.diagnostic = "ok"; out
}

func ckbReproCompositionAssetBytes(
    loaded: CkbReproCliCompositionLoadResult, role: String):
    (Bool, Array<UInt8>) {
    var matched = false
    var bytes = Array<UInt8>()
    for (asset in loaded.assets) {
        if (asset.role == role) {
            if (matched) { return (false, Array<UInt8>()) }
            matched = true; bytes = asset.bytes
        }
    }
    (matched, bytes)
}

func ckbReproCompositionAssetPath(
    loaded: CkbReproCliCompositionLoadResult, role: String):
    (Bool, String) {
    var matched = false
    var path = ""
    for (asset in loaded.assets) {
        if (asset.role == role) {
            if (matched) { return (false, "") }
            matched = true
            path = Path(loaded.root).join(asset.relativePath).toString()
        }
    }
    (matched, path)
}

func ckbReproP3CompositionMode(args: Array<String>): String {
    let options = parseCkbP3CliOptions(
        ckbReproArgsWithoutCompositionManifest(args))
    if (options.diagnostic != "ok") { return "" }
    match (options.mode) {
        case "build" => "p3-vector-build"
        case "create" => "p3-snapshot-create"
        case "restore" => "p3-snapshot-restore"
        case "verify" => "p3-snapshot-verify"
        case "parity" => if (options.parityAction == "build") {
            "p3-parity-build"
        } else { "p3-parity" }
        case _ => ""
    }
}

func ckbReproP3FrozenEndpointsValid(options: CkbP3CliOptions,
    runtime: CkbRuntimeConfig): Bool {
    let serviceOrigin = "http://${runtime.serviceBind}:${runtime.servicePort}"
    options.restEndpoint == serviceOrigin + "/v1/cangjie/syntax-query" &&
        options.mcpHttpEndpoint == serviceOrigin + "/mcp"
}

func runCkbReproP3ProductionComposition(args: Array<String>):
    CkbReproMainCliResult {
    let forwarded = ckbReproArgsWithoutCompositionManifest(args)
    let options = parseCkbP3CliOptions(forwarded)
    if (options.diagnostic != "ok") {
        return ckbReproP3CompositionFailure(options.diagnostic,
            args.contains("--json"))
    }
    let prepared = loadCkbReproProductionCliComposition(args,
        ckbReproP3CompositionMode(args))
    if (!prepared.ok) {
        return ckbReproP3CompositionFailure(prepared.diagnostic,
            prepared.json)
    }
    let runtimeBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "runtime_config")
    let policyBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "path_policy")
    let rootsBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "local_root_map")
    let routesBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "api_routes")
    let releasePolicyBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "path_context")
    if (!runtimeBytes[0] || !policyBytes[0] || !rootsBytes[0] ||
        !routesBytes[0] || !releasePolicyBytes[0]) {
        return ckbReproP3CompositionFailure(
            "p3_composition_asset_missing", prepared.json)
    }
    let runtime = parseCkbReproCliRuntimeConfigBytes(runtimeBytes[1])
    if (!runtime[0].ok) {
        return ckbReproP3CompositionFailure(
            runtime[0].diagnostic, prepared.json)
    }
    let pathContext = parseCkbReproCliPathContextBytes(policyBytes[1],
        rootsBytes[1], routesBytes[1], releasePolicyBytes[1])
    if (!pathContext[0].ok) {
        return ckbReproP3CompositionFailure(
            pathContext[0].diagnostic, prepared.json)
    }
    let assembly = CkbReproP3ProductionAssembly()
    assembly.mode = options.mode
    assembly.runtime = runtime[1]
    assembly.candidateStoreRoot = options.candidateRoot
    assembly.pathContext = pathContext[1].pathContext
    assembly.pathPolicy = pathContext[1].releasePathPolicy
    if (options.mode == "parity") {
        if (!ckbReproP3FrozenEndpointsValid(options, runtime[1])) {
            return ckbReproP3CompositionFailure(
                "p3_composition_endpoint_mismatch", prepared.json)
        }
        let stdio = ckbReproCompositionAssetBytes(
            prepared.loaded, "mcp_stdio_command")
        if (!stdio[0]) {
            return ckbReproP3CompositionFailure(
                "p3_composition_asset_missing", prepared.json)
        }
        let parsed = parseCkbMcpStdioCommandSpec(stdio[1])
        if (!parsed[0].ok) {
            return ckbReproP3CompositionFailure(
                parsed[0].diagnostic, prepared.json)
        }
        assembly.stdioSpec = parsed[1]
        if (options.parityAction == "build") {
            let logicalBytes = ckbReproCompositionAssetBytes(
                prepared.loaded, "logical_manifest")
            let logicalPath = ckbReproCompositionAssetPath(
                prepared.loaded, "logical_manifest")
            let logical = parseCkbLogicalSnapshotManifest(logicalBytes[1])
            if (!logicalBytes[0] || !logicalPath[0] ||
                options.logicalManifest != logicalPath[1] || !logical[0].ok) {
                return ckbReproP3CompositionFailure(
                    "p3_logical_manifest_authority_invalid", prepared.json)
            }
            assembly.logicalManifest = Some(logical[1])
        }
    }
    if (options.mode == "restore" || options.mode == "verify") {
        let manifest = ckbReproCompositionAssetBytes(
            prepared.loaded, "qdrant_manifest")
        let manifestPath = ckbReproCompositionAssetPath(
            prepared.loaded, "qdrant_manifest")
        if (!manifest[0] || !manifestPath[0] ||
            options.manifest != manifestPath[1] ||
            !parseCkbQdrantSnapshotManifest(manifest[1])[0].ok) {
            return ckbReproP3CompositionFailure(
                "p3_qdrant_manifest_authority_invalid", prepared.json)
        }
    }
    executeCkbReproP3ProductionAssembly(forwarded, assembly)
}

func ckbReproP4CompositionMode(args: Array<String>): String {
    let options = parseCkbP4CliOptions(
        ckbReproArgsWithoutCompositionManifest(args))
    if (options.diagnostic != "ok") { return "" }
    if (options.command == "ckb-repro-build") { "p4-build" }
    else if (options.command == "ckb-repro-promote") { "p4-promote" }
    else { "" }
}

func runCkbReproP4ProductionComposition(args: Array<String>):
    CkbReproMainCliResult {
    let forwarded = ckbReproArgsWithoutCompositionManifest(args)
    let options = parseCkbP4CliOptions(forwarded)
    if (options.diagnostic != "ok") {
        return ckbReproP4CompositionFailure(options.diagnostic,
            args.contains("--json"))
    }
    let prepared = loadCkbReproProductionCliComposition(args,
        ckbReproP4CompositionMode(args))
    if (!prepared.ok) {
        return ckbReproP4CompositionFailure(prepared.diagnostic,
            prepared.json)
    }
    let runtimeBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "runtime_config")
    let policyBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "path_policy")
    let rootsBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "local_root_map")
    let routesBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "api_routes")
    let releasePolicyBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "path_context")
    if (!runtimeBytes[0] || !policyBytes[0] || !rootsBytes[0] ||
        !routesBytes[0] || !releasePolicyBytes[0]) {
        return ckbReproP4CompositionFailure(
            "p4_composition_asset_missing", prepared.json)
    }
    let runtime = parseCkbReproCliRuntimeConfigBytes(runtimeBytes[1])
    let path = parseCkbReproCliPathContextBytes(policyBytes[1],
        rootsBytes[1], routesBytes[1], releasePolicyBytes[1])
    if (!runtime[0].ok || !path[0].ok) {
        return ckbReproP4CompositionFailure(if (!runtime[0].ok) {
            runtime[0].diagnostic
        } else { path[0].diagnostic }, prepared.json)
    }
    if (options.command == "ckb-repro-promote") {
        let assembly = CkbReproP4PromoteProductionAssembly()
        assembly.runtime = runtime[1]
        assembly.pathContext = path[1].pathContext
        return executeCkbReproP4PromoteProductionAssembly(forwarded,
            assembly)
    }
    let manifestBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "public_build_input_manifest")
    let evalBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "eval_support")
    let leakageBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "leakage_authority")
    if (!manifestBytes[0] || !evalBytes[0] || !leakageBytes[0]) {
        return ckbReproP4CompositionFailure(
            "p4_composition_asset_missing", prepared.json)
    }
    let manifest = parseCkbReproBuildInputManifest(manifestBytes[1])
    let eval = parseCkbReproCliEvalSupportBytes(evalBytes[1])
    let leakage = parseCkbReproCliLeakageAuthorityBytes(leakageBytes[1])
    if (!manifest[0].ok || !eval[0].ok || !leakage[0].ok) {
        return ckbReproP4CompositionFailure(if (!manifest[0].ok) {
            manifest[0].diagnostic
        } else if (!eval[0].ok) { eval[0].diagnostic }
        else { leakage[0].diagnostic }, prepared.json)
    }
    let authority = composeCkbReproCliPrivateBuildAuthority(eval[1],
        leakage[1], path[1], options.temporaryRoot, options.outputRoot)
    if (!authority[0].ok) {
        return ckbReproP4CompositionFailure(
            authority[0].diagnostic, prepared.json)
    }
    let publicRoot = Path(prepared.loaded.root).join(
        "public-build-inputs").toString()
    let reader = CkbReproFilesystemBundleReadBackend()
    let loaded = loadCkbReproPublicBuildInputs(
        publicRoot, manifest[1], reader)
    if (!loaded.ok) {
        return ckbReproP4CompositionFailure(loaded.diagnostic, prepared.json)
    }
    let sourceCacheRoot = options.temporaryRoot + ".source-cache"
    let ownedSourceRoot = options.temporaryRoot + ".owned-sources"
    if (exists(Path(sourceCacheRoot)) || exists(Path(ownedSourceRoot))) {
        return ckbReproP4CompositionFailure(
            "p4_source_root_exists", prepared.json)
    }
    let assembly = CkbReproP4BuildProductionAssembly()
    assembly.publicRoot = publicRoot; assembly.manifest = manifest[1]
    assembly.authority = authority[1]; assembly.reader = Some(reader)
    assembly.materialBackend = Some(CkbPinnedSourceMaterialBackend(
        loaded.sourceLock, sourceCacheRoot))
    assembly.materializer = Some(CkbFilesystemOwnedSourceMaterializer(
        ownedSourceRoot))
    ckbReproExecuteP4BuildWithCleanup(forwarded, prepared.json, assembly,
        sourceCacheRoot, ownedSourceRoot,
        CkbReproP4ProductionBuildCompositionExecutor(),
        CkbReproP4FilesystemOwnedRootCleaner())
}

func ckbReproExecuteP4BuildWithCleanup(args: Array<String>, json: Bool,
    assembly: CkbReproP4BuildProductionAssembly, sourceCacheRoot: String,
    ownedSourceRoot: String, executor: CkbReproP4BuildCompositionExecutor,
    cleaner: CkbReproP4OwnedRootCleaner): CkbReproMainCliResult {
    var result = ckbReproP4CompositionFailure(
        "p4_build_execution_failed", json)
    var cacheCleaned = false
    var sourcesCleaned = false
    try {
        result = executor.execute(args, assembly)
    } catch (_: Exception) {
        result = ckbReproP4CompositionFailure(
            "p4_build_execution_failed", json)
    } finally {
        try { cacheCleaned = cleaner.cleanup(sourceCacheRoot) }
        catch (_: Exception) { cacheCleaned = false }
        try { sourcesCleaned = cleaner.cleanup(ownedSourceRoot) }
        catch (_: Exception) { sourcesCleaned = false }
    }
    if (!cacheCleaned || !sourcesCleaned) {
        return ckbReproP4CompositionFailure(
            "p4_source_cleanup_failed", json)
    }
    result
}

func ckbReproP8CompositionMode(args: Array<String>): String {
    let forwarded = ckbReproVerifyArgsWithoutPresentation(args)
    let parsed = parseCkbReproVerifyOptions(forwarded)
    if (!parsed.ok) { return "" }
    if (parsed.options.mode == "run-certify") { "run-certify" }
    else if (parsed.options.mode == "release-verify") { "release-verify" }
    else { "" }
}

func runCkbReproP8ProductionComposition(args: Array<String>):
    CkbReproMainCliResult {
    let forwarded = ckbReproVerifyArgsWithoutPresentation(args)
    let parsed = parseCkbReproVerifyOptions(forwarded)
    let json = args.contains("--json")
    if (!parsed.ok) { return ckbReproP8CompositionFailure(
        parsed.diagnostic, json) }
    let prepared = loadCkbReproProductionCliComposition(args,
        ckbReproP8CompositionMode(args))
    if (!prepared.ok) { return ckbReproP8CompositionFailure(
        prepared.diagnostic, prepared.json) }
    let shared = loadCkbReproP8SharedComposition(
        prepared, parsed.options.repositoryRoot)
    if (!shared[0].ok) { return ckbReproP8CompositionFailure(
        shared[0].diagnostic, prepared.json) }
    let transportBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "runtime_transport")
    let buildBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "public_build_input_manifest")
    let evalBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "eval_support")
    let leakageBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "leakage_authority")
    if (!transportBytes[0] || !buildBytes[0] || !evalBytes[0] ||
        !leakageBytes[0]) {
        return ckbReproP8CompositionFailure(
            "p8_composition_asset_missing", prepared.json)
    }
    let transport = parseCkbP8OwnedLocalRuntimeAuthorityBytes(
        transportBytes[1])
    let build = parseCkbReproBuildInputManifest(buildBytes[1])
    let eval = parseCkbReproCliEvalSupportBytes(evalBytes[1])
    let leakage = parseCkbReproCliLeakageAuthorityBytes(leakageBytes[1])
    if (!transport[0].ok || !build[0].ok || !eval[0].ok ||
        !leakage[0].ok) {
        return ckbReproP8CompositionFailure(
            "p8_composition_asset_invalid", prepared.json)
    }
    let stages = buildCkbReproP8ProductionStages(prepared, shared[1],
        parsed.options, transport[1], build[1], eval[1], leakage[1])
    if (!stages.ok) { return ckbReproP8CompositionFailure(
        stages.diagnostic, prepared.json) }
    if (parsed.options.mode == "run-certify") {
        return ckbReproRunP8A(prepared, shared[1], stages,
            transport[1], parsed.options, forwarded)
    }
    ckbReproRunP8B(prepared, shared[1], stages,
        parsed.options, forwarded)
}

private func ckbReproRunP8A(prepared: CkbReproProductionCliComposition,
    shared: CkbReproP8SharedComposition,
    stages: CkbReproP8ProductionStages,
    transport: CkbP8OwnedLocalRuntimeAuthority,
    options: CkbReproVerifyOptions, forwarded: Array<String>):
    CkbReproMainCliResult {
    let runnerBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "runner_inputs")
    let authorityBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "authority_manifest")
    if (!runnerBytes[0] || !authorityBytes[0]) {
        return ckbReproP8CompositionFailure(
            "p8a_composition_asset_missing", prepared.json)
    }
    let runner = parseCkbReproCliRunnerInputsBytes(
        runnerBytes[1], "run-certify")
    let authorityText = try { String.fromUtf8(authorityBytes[1]) }
        catch (_: Exception) { return ckbReproP8CompositionFailure(
            "invalid_response_encoding", prepared.json) }
    let authority = parseCangjieHumanEvalAuthorityManifest(authorityText)
    if (!runner[0].ok || !authority.ok || authority.rows.size != 164 ||
        authority.datasetVersion != shared.environment.datasetVersion ||
        runner[1].knowledgeVersion != shared.logical.portableKnowledgeVersion ||
        runner[1].candidateVersion != shared.buildProof.candidateVersion) {
        return ckbReproP8CompositionFailure(
            "p8a_runner_authority_invalid", prepared.json)
    }
    shared.environment.runCandidateCommit = options.runCandidateCommit
    let p6 = runCkbReproSingleCommitPreflight(
        options.p6EnvironmentLockPath,
        runner[1].certificationPreflightPath,
        runner[1].certificationRunManifestPath,
        options.repositoryRoot, options.runCandidateCommit, ckbReproP8Heap())
    if (!p6.ok || !p6.startAllowed) {
        return ckbReproP8CompositionFailure(p6.diagnostic, prepared.json)
    }
    let lifecycle = match (stages.lifecycle) {
        case Some(value) => value
        case None => return ckbReproP8CompositionFailure(
            "p8_lifecycle_required", prepared.json)
    }
    let probe = CkbFilesystemReproVerifyEnvironmentProbe(
        FileKnowledgeStore(options.candidateRoot), shared.path.pathContext,
        shared.reference.releaseRepository, runner[1].providerIdentityHash,
        shared.environment.glmModel,
        { => lifecycle.conflictingProcessCount() })
    let heap = ckbReproP8Heap()
    let verification = validateCkbReproVerifyEnvironment(options, heap, probe)
    if (!verification.ok) { return ckbReproP8CompositionFailure(
        verification.diagnostic, prepared.json) }
    let environmentValidation = validateCkbReproEnvironmentLock(
        shared.environment, mode: "execution")
    let hashes = CkbReproCertifiedRunHashInputs()
    hashes.logicalProofHash = shared.logical.manifestHash
    hashes.vectorProofHash = shared.qdrant.vectorProofHash
    hashes.datasetHash = benchmarkGapSha256(
        "ckb-repro-dataset-v1|${shared.environment.datasetVersion}")
    hashes.authorityHash = ckbReproBundleHash(authorityBytes[1])
    hashes.environmentHash = environmentValidation.manifestHash
    hashes.experimentHash = ckbReproP8ExperimentHash(shared.environment)
    hashes.inputEvidenceHash = verification.inputEvidenceHash
    hashes.repositoryRoot = options.repositoryRoot
    hashes.runCriticalManifest = shared.critical
    let assembly = CkbReproP8AProductionAssembly()
    assembly.expected = shared.expected; assembly.hashInputs = hashes
    assembly.probe = Some(probe); assembly.reference = shared.reference
    assembly.environment = shared.environment; assembly.runnerInputs = runner[1]
    assembly.preflight = p6; assembly.authorityManifestText = authorityText
    assembly.restore = stages.restore; assembly.rebuild = stages.rebuild
    assembly.lifecycle = Some(lifecycle)
    executeCkbReproP8AProductionAssembly(
        forwarded, heap, prepared.json, assembly)
}

private func ckbReproRunP8B(prepared: CkbReproProductionCliComposition,
    shared: CkbReproP8SharedComposition,
    stages: CkbReproP8ProductionStages, options: CkbReproVerifyOptions,
    forwarded: Array<String>): CkbReproMainCliResult {
    let backend = CkbReproFilesystemBundleReadBackend()
    let loaded = validateCkbReproBundleManifest(options.candidateRoot, backend)
    if (!loaded.contract.ok) { return ckbReproP8CompositionFailure(
        loaded.contract.diagnostic, prepared.json) }
    let releaseInputBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "release_inputs_manifest")
    if (!releaseInputBytes[0]) { return ckbReproP8CompositionFailure(
        "p8b_release_inputs_missing", prepared.json) }
    let frozen = parseCkbReproReleaseInputsManifest(releaseInputBytes[1])
    if (!frozen.contract.ok) { return ckbReproP8CompositionFailure(
        frozen.contract.diagnostic, prepared.json) }
    let referenceValidation = validateCkbReproReferenceManifest(
        shared.reference, mode: "execution")
    let criticalTreeHash = computeCkbRunCriticalTreeHash(
        shared.critical, options.repositoryRoot)
    if (!referenceValidation.ok || frozen.releaseCommit != options.releaseCommit ||
        frozen.runCriticalTreeHash != criticalTreeHash ||
        frozen.runCriticalTreeHash != shared.reference.runCriticalTreeHash ||
        frozen.certifiedRunInputHash !=
            shared.reference.certifiedRunInputHash ||
        frozen.referenceManifestHash != referenceValidation.manifestHash ||
        frozen.manifest.inputSetHash != loaded.manifest.inputSetHash) {
        return ckbReproP8CompositionFailure(
            "p8b_release_inputs_authority_mismatch", prepared.json)
    }
    let authority = ckbReproP8ReleaseInputsAuthority(frozen)
    if (!authority[0].ok) { return ckbReproP8CompositionFailure(
        authority[0].diagnostic, prepared.json) }
    let lifecycle = match (stages.lifecycle) {
        case Some(value) => value
        case None => return ckbReproP8CompositionFailure(
            "p8_lifecycle_required", prepared.json)
    }
    let assembly = CkbReproP8BProductionAssembly()
    assembly.expected = shared.expected; assembly.reference = shared.reference
    assembly.expectedInputSetHash = frozen.manifest.inputSetHash
    assembly.expectedCertifiedInputHash = frozen.certifiedRunInputHash
    assembly.releaseRepository = shared.reference.releaseRepository
    assembly.critical = shared.critical; assembly.authority = authority[1]
    assembly.probe = Some(CkbReleaseFilesystemReproVerifyEnvironmentProbe(
        options.candidateRoot, shared.reference.releaseRepository,
        { => lifecycle.conflictingProcessCount() }))
    assembly.backend = Some(backend); assembly.restore = stages.restore
    assembly.rebuild = stages.rebuild; assembly.lifecycle = Some(lifecycle)
    assembly.registeredCommands = ckbReproP8RegisteredCommands()
    executeCkbReproP8BProductionAssembly(
        forwarded, ckbReproP8Heap(), prepared.json, assembly)
}

func ckbReproArgsWithoutCompositionManifest(args: Array<String>):
    Array<String> {
    let out = ArrayList<String>(); var i: Int64 = 0
    while (i < args.size) {
        if (args[i] == "--composition-manifest" && i + 1 < args.size) {
            i += 2
        } else { out.add(args[i]); i += 1 }
    }
    out.toArray()
}

func ckbReproVerifyArgsWithoutPresentation(args: Array<String>):
    Array<String> {
    let stripped = ckbReproArgsWithoutCompositionManifest(args)
    let out = ArrayList<String>()
    for (value in stripped) {
        if (value != "ckb-repro-verify" && value != "--json") {
            out.add(value)
        }
    }
    out.toArray()
}

private func ckbReproP3CompositionFailure(code: String, json: Bool):
    CkbReproMainCliResult {
    let result = CkbP3CliOperationResult(); result.diagnostic = code
    CkbReproMainCliResult(true, 2, if (json) {
        renderCkbP3CliJson(result)
    } else { renderCkbP3CliHuman(result) })
}

private func ckbReproP4RemoveOwnedRoot(path: String): Bool {
    if (!exists(Path(path))) { return true }
    try { remove(Path(path), recursive: true); true }
    catch (_: Exception) { false }
}

private func ckbReproP4CompositionFailure(code: String, json: Bool):
    CkbReproMainCliResult {
    let result = CkbP4CliOperationResult(); result.diagnostic = code
    CkbReproMainCliResult(true, 2, if (json) {
        renderCkbP4CliJson(result)
    } else { renderCkbP4CliHuman(result) })
}

private func ckbReproP8Heap(): String {
    match (getVariable("cjHeapSize")) {
        case Some(value) => value
        case None => ""
    }
}

private func ckbReproP8ExperimentHash(
    value: CkbReproEnvironmentLock): String {
    benchmarkGapSha256("ckb-repro-experiment-v1|" +
        "${value.experimentGroup}|${value.ckbRequired}|" +
        "${value.localDocsPolicy}|${value.modelEffort}|${value.modelBudget}|" +
        "${value.timeoutSeconds}|${value.transportRetryBudget}|" +
        "${value.promptHash}|${value.mcpCommand}|${value.mcpTransport}|" +
        value.sandboxCapability)
}

private func ckbReproP8ReleaseInputsAuthority(
    frozen: CkbReproReleaseInputsLoadResult):
    (CkbReproContractResult, CkbReproReleaseAuthorityContract) {
    let rows = ArrayList<CkbReproReleaseAuthorityEvidence>()
    for (input in frozen.inputs) {
        let asset = input.asset
        let row = CkbReproReleaseAuthorityEvidence()
        row.role = asset.role; row.logicalAsset = asset.logicalAsset
        row.size = asset.logicalSize; row.sha256 = asset.logicalSha256
        rows.add(row)
    }
    buildCkbReproReleaseAuthorityContract(rows, frozen.authorityDeliveryMode)
}

private func ckbReproP8RegisteredCommands(): Array<String> {
    ["ckb-release-export", "ckb-release-import",
        "ckb-public-evidence-export", "ckb-repro-preflight",
        "ckb-authority-bundle",
        "ckb-repro-bundle", "ckb-repro-publish-gate",
        "ckb-portable-vector-build", "ckb-qdrant-snapshot",
        "ckb-retrieval-parity", "ckb-repro-build", "ckb-repro-promote",
        "ckb-repro-composition-stage", "ckb-repro-composition-seal",
        "ckb-repro-verify",
        "cangjie-humaneval-pass1-gate",
        "cangjie-humaneval-strict-score"]
}

func ckbReproP8CompositionFailure(code: String, json: Bool):
    CkbReproMainCliResult {
    let safe = ckbReproP8SafeDiagnostic(code)
    CkbReproMainCliResult(true, 2, if (json) {
        "{\"ok\":false,\"diagnostic\":\"${ckbReproP8JsonEscape(safe)}\"}"
    } else { "CKB reproducibility verification failed: ${safe}\n" })
}

func ckbReproP8SafeDiagnostic(value: String): String {
    utf8SafePrefix(redactSensitive(value), 160)
}

private func ckbReproP8JsonEscape(value: String): String {
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
