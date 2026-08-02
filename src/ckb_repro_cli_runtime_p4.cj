package cangjie_community_knowledge_base

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
    var candidateStore: ?FileKnowledgeStore = None
    var productionStore: ?FileKnowledgeStore = None
    var snapshotPath: String = ""
    var snapshotManifest: CkbQdrantSnapshotManifest =
        CkbQdrantSnapshotManifest()
    var logicalManifest: CkbLogicalSnapshotManifest =
        CkbLogicalSnapshotManifest()
    var targetCollection: String = ""
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
    operation.summary = "logicalReady=${result.proof.logicalReady} " +
        "raw=${result.proof.rawCount} selected=${result.proof.selectedCount} " +
        "vectorState=${result.proof.vectorState}"
    ckbP4MainResult(operation, options.json)
}

func executeCkbReproP4PromoteProductionAssembly(args: Array<String>,
    assembly: CkbReproP4PromoteProductionAssembly): CkbReproMainCliResult {
    let options = parseCkbP4CliOptions(args)
    if (options.diagnostic != "ok" || options.command != "ckb-repro-promote") {
        return ckbP4MainFailure(options.diagnostic, args.contains("--json"))
    }
    let candidate = match (assembly.candidateStore) {
        case Some(value) => value
        case None => return ckbP4MainFailure("p4_candidate_store_required",
            options.json)
    }
    let production = match (assembly.productionStore) {
        case Some(value) => value
        case None => return ckbP4MainFailure("p4_production_store_required",
            options.json)
    }
    let request = CkbReproBuildRequest()
    let adapter = newCkbP4RuntimeProductionAdapter(request, candidate,
        production, assembly.snapshotPath, assembly.snapshotManifest,
        assembly.logicalManifest, assembly.targetCollection,
        options.qdrantEndpoint, assembly.runtime, assembly.pathContext)
    let execution = runCkbP4Cli(args, adapter)
    CkbReproMainCliResult(true, execution.exitCode, execution.output)
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
