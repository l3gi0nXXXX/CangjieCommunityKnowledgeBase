package cangjie_community_knowledge_base_test

class CkbReproP3ProductionAssembly {
    var mode: String = ""
    var runtime: CkbRuntimeConfig = CkbRuntimeConfig()
    var candidateStoreRoot: String = ""
    var pathContext: CkbPortablePathContext = CkbPortablePathContext()
    var pathPolicy: CkbReleasePathPolicy = CkbReleasePathPolicy()
    var stdioSpec: CkbMcpStdioCommandSpec = CkbMcpStdioCommandSpec()
    public init() {}
}

func executeCkbReproP3ProductionAssembly(args: Array<String>,
    assembly: CkbReproP3ProductionAssembly): CkbReproMainCliResult {
    let options = parseCkbP3CliOptions(args)
    if (options.diagnostic != "ok" || options.mode != assembly.mode) {
        return ckbP3MainExecution(executeCkbP3CliAdapter(args,
            CkbP3RejectedProductionAdapter("p3_composition_mode_mismatch")))
    }
    let adapter: CkbP3CliAdapter
    if (options.mode == "build") {
        let store = FileKnowledgeStore(options.candidateRoot)
        adapter = newCkbP3RuntimeVectorBuildAdapter(
            embeddingProviderFromRuntime(assembly.runtime), store,
            vectorStoreFromRuntime(assembly.runtime), assembly.pathContext,
            assembly.pathPolicy)
    } else if (options.mode == "create" || options.mode == "restore") {
        adapter = newCkbP3RuntimeSnapshotAdapter(options.mode, None,
            assembly.pathContext, options.endpoint, assembly.runtime,
            assembly.pathPolicy)
    } else if (options.mode == "verify") {
        adapter = newCkbP3RuntimeSnapshotAdapter(options.mode,
            Some(FileKnowledgeStore(assembly.candidateStoreRoot)),
            assembly.pathContext, options.endpoint, assembly.runtime,
            assembly.pathPolicy)
    } else {
        adapter = newCkbP3RuntimeParityAdapter(options.restEndpoint,
            assembly.stdioSpec, options.mcpHttpEndpoint, assembly.runtime,
            assembly.pathPolicy)
    }
    ckbP3MainExecution(runCkbP3Cli(args, adapter))
}

private class CkbP3RejectedProductionAdapter <: CkbP3CliAdapter {
    private let diagnostic: String
    public init(diagnostic: String) { this.diagnostic = diagnostic }
    public func execute(options: CkbP3CliOptions): CkbP3CliOperationResult {
        let out = CkbP3CliOperationResult(); out.diagnostic = this.diagnostic; out
    }
}

private func ckbP3MainExecution(value: CkbP3CliExecution):
    CkbReproMainCliResult {
    CkbReproMainCliResult(true, value.exitCode, value.output)
}
