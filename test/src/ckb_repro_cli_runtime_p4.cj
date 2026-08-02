package cangjie_community_knowledge_base_test

import std.fs.{File, Path}

class CkbReproP4BuildProductionAssembly {
    var publicRoot: String = ""
    var manifest: CkbReproBuildInputManifest = CkbReproBuildInputManifest()
    var authority: CkbReproPrivateBuildAuthority =
        CkbReproPrivateBuildAuthority()
    var reader: ?CkbReproFilesystemBundleReadBackend = None
    var materialBackend: ?CkbPinnedSourceMaterialBackend = None
    var materializer: ?CkbFilesystemOwnedSourceMaterializer = None
    public init() {}
}

class CkbReproP4PromoteProductionAssembly {
    var runtime: CkbRuntimeConfig = CkbRuntimeConfig()
    var pathContext: CkbPortablePathContext = CkbPortablePathContext()
    public init() {}
}

func executeCkbReproP4BuildProductionAssembly(args: Array<String>,
    assembly: CkbReproP4BuildProductionAssembly): CkbReproMainCliResult {
    let options = parseCkbP4CliOptions(args)
    if (options.diagnostic != "ok" || options.command != "ckb-repro-build") {
        return ckbP4MainFailure(options.diagnostic, args.contains("--json"))
    }
    let reader = match (assembly.reader) {
        case Some(value) => value
        case None => return ckbP4MainFailure("p4_build_reader_required",
            options.json)
    }
    let materials = match (assembly.materialBackend) {
        case Some(value) => value
        case None => return ckbP4MainFailure("p4_material_backend_required",
            options.json)
    }
    let materializer = match (assembly.materializer) {
        case Some(value) => value
        case None => return ckbP4MainFailure("p4_materializer_required",
            options.json)
    }
    assembly.authority.outputRoot = options.outputRoot
    assembly.authority.temporaryRoot = options.temporaryRoot
    let result = runCkbReproProductionBuild(assembly.publicRoot,
        assembly.manifest, assembly.authority, reader, materials,
        materializer, CkbFirstInitReproSourceAssembler(),
        CkbReproProductionBuildBackend())
    let operation = CkbP4CliOperationResult()
    operation.ok = result.ready; operation.diagnostic = result.diagnostic
    if (result.ready) {
        let persisted = persistCkbReproBuildProof(
            options.outputRoot, result.proof)
        if (persisted != "ok") {
            operation.ok = false; operation.diagnostic = persisted
        }
    }
    operation.summary = "logicalReady=${result.proof.logicalReady} " +
        "raw=${result.proof.rawCount} selected=${result.proof.selectedCount} " +
        "vectorState=${result.proof.vectorState}"
    ckbP4MainResult(operation, options.json)
}

func persistCkbReproBuildProof(outputRoot: String,
    proof: CkbReproBuildProof): String {
    try {
        File.writeTo(Path(outputRoot).join("repro-build-proof.json"),
            renderCkbReproBuildProof(proof).toArray())
        "ok"
    } catch (_: Exception) {
        "p4_build_proof_write_failed"
    }
}

func executeCkbReproP4PromoteProductionAssembly(args: Array<String>,
    assembly: CkbReproP4PromoteProductionAssembly): CkbReproMainCliResult {
    let options = parseCkbP4CliOptions(args)
    if (options.diagnostic != "ok" || options.command != "ckb-repro-promote") {
        return ckbP4MainFailure(options.diagnostic, args.contains("--json"))
    }
    let transport = ckbNativeHttpAdapterConfigFromRuntime(
        assembly.runtime, assembly.runtime.vectorAllowPrivateEndpoint)
    let http = NativeHttpRequestExecutor(transport)
    let ownedRoot = Path(options.unsignedRoot).parent.join(
        ".ckb-promotion-owned-" + benchmarkGapSha256(
            options.unsignedRoot).replace("sha256:", "")).toString()
    let adapter = CkbP4SameBundleProductionAdapter(
        CkbP4ProductionBuildRejectedAdapter(), ownedRoot,
        CkbReproFilesystemBundleReadBackend(),
        CkbPortableReleaseArchiveBackend(),
        CkbQdrantSnapshotHttpExecutor(options.qdrantEndpoint, http),
        CkbNativeQdrantSnapshotFileExecutor(options.qdrantEndpoint,
            transport), assembly.pathContext)
    let execution = runCkbP4Cli(args, adapter)
    CkbReproMainCliResult(true, execution.exitCode, execution.output)
}

private class CkbP4ProductionBuildRejectedAdapter <: CkbP4CliAdapter {
    public init() {}
    public func execute(options: CkbP4CliOptions): CkbP4CliOperationResult {
        let out = CkbP4CliOperationResult()
        out.diagnostic = "p4_build_adapter_not_available"; out
    }
}

private func ckbP4MainResult(result: CkbP4CliOperationResult, json: Bool):
    CkbReproMainCliResult {
    CkbReproMainCliResult(true, if (result.ok) { 0 } else { 1 },
        if (json) { renderCkbP4CliJson(result) }
        else { renderCkbP4CliHuman(result) })
}

private func ckbP4MainFailure(code: String, json: Bool):
    CkbReproMainCliResult {
    let result = CkbP4CliOperationResult()
    result.diagnostic = if (code == "ok") { "p4_composition_mode_mismatch" }
        else { code }
    let out = ckbP4MainResult(result, json); out.exitCode = 2; out
}
