package cangjie_community_knowledge_base_test

import std.collection.ArrayList

public class CkbFirstInitOptions {
    public var storeRoot: String = ""
    public var docsRoot: String = ""
    public var toolDocsRoot: String = ""
    public var stdRoot: String = ""
    public var stdxRoot: String = ""
    public var evalRoot: String = ""
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var apply: Bool = false
    public var dryRun: Bool = false
    public var autoMode: Bool = false
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class CkbFirstInitSourceSummary {
    public var name: String = ""
    public var root: String = ""
    public var ok: Bool = false
    public var fileCount: Int64 = 0
    public var recordCount: Int64 = 0
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class CkbFirstInitValidationResult {
    public var ok: Bool = false
    public var failedGates: ArrayList<String> = ArrayList<String>()
    public var queryChecks: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class CkbFirstInitResult {
    public var ok: Bool = false
    public var candidateVersion: String = ""
    public var activeVersion: String = ""
    public var persisted: Bool = false
    public var evalSupportAuthorityPersisted: Bool = false
    public var dryRun: Bool = false
    public var evalSupportAuthority: CangjieEvalSupportSnapshot = CangjieEvalSupportSnapshot()
    public var validation: CkbFirstInitValidationResult = CkbFirstInitValidationResult()
    public var sources: ArrayList<CkbFirstInitSourceSummary> = ArrayList<CkbFirstInitSourceSummary>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class CkbFirstInitAssembly {
    public var ok: Bool = true
    public var manifest: CangjieVersionManifest = CangjieVersionManifest()
    public var records: ArrayList<CangjieTypedRecord> = ArrayList<CangjieTypedRecord>()
    public var evalSupportAuthority: CangjieEvalSupportSnapshot = CangjieEvalSupportSnapshot()
    public var sources: ArrayList<CkbFirstInitSourceSummary> = ArrayList<CkbFirstInitSourceSummary>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public func parseCkbFirstInitOptions(args: Array<String>): CkbFirstInitOptions {
    let options = CkbFirstInitOptions()
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "--apply") {
            options.apply = true
        } else if (arg == "--dry-run") {
            options.dryRun = true
        } else if (arg == "--auto") {
            options.autoMode = true
        } else if (arg == "--store" && i + 1 < args.size) {
            options.storeRoot = args[i + 1].trimAscii()
            i += 1
        } else if (arg == "--docs-root" && i + 1 < args.size) {
            options.docsRoot = args[i + 1].trimAscii()
            i += 1
        } else if (arg == "--tool-docs-root" && i + 1 < args.size) {
            options.toolDocsRoot = args[i + 1].trimAscii()
            i += 1
        } else if (arg == "--std-root" && i + 1 < args.size) {
            options.stdRoot = args[i + 1].trimAscii()
            i += 1
        } else if (arg == "--stdx-root" && i + 1 < args.size) {
            options.stdxRoot = args[i + 1].trimAscii()
            i += 1
        } else if (arg == "--eval-root" && i + 1 < args.size) {
            options.evalRoot = args[i + 1].trimAscii()
            i += 1
        } else if (arg == "--target-version" && i + 1 < args.size) {
            options.targetVersion = args[i + 1].trimAscii()
            i += 1
        }
        i += 1
    }
    validateCkbFirstInitOptions(options)
    options
}

public func validateCkbFirstInitOptions(options: CkbFirstInitOptions): Bool {
    options.diagnostics.clear()
    if (options.apply && options.dryRun) {
        options.diagnostics.add("apply_and_dry_run_conflict")
    }
    if (options.targetVersion.trimAscii() == "") {
        options.diagnostics.add("target_version_empty")
    }
    ckbFirstInitValidatePath(options.docsRoot, "docs_root", options.diagnostics)
    ckbFirstInitValidatePath(options.toolDocsRoot, "tool_docs_root", options.diagnostics)
    ckbFirstInitValidatePath(options.stdRoot, "std_root", options.diagnostics)
    ckbFirstInitValidatePath(options.stdxRoot, "stdx_root", options.diagnostics)
    ckbFirstInitValidatePath(options.evalRoot, "eval_root", options.diagnostics)
    options.diagnostics.size == 0
}

public func renderCkbFirstInitResult(result: CkbFirstInitResult): String {
    let out = StringBuilder()
    if (result.dryRun) {
        out.append("first-init preflight ok=${result.ok}\n")
    } else {
        out.append("first-init ok=${result.ok}\n")
    }
    out.append("validation ok=${result.validation.ok}\n")
    out.append("activeKnowledgeVersion=${if (result.activeVersion == "") { "<empty>" } else { result.activeVersion }}\n")
    out.append("persisted=${result.persisted}\n")
    out.append("evalSupportAuthority version=${if (result.evalSupportAuthority.datasetVersion == "") { "<empty>" } else { result.evalSupportAuthority.datasetVersion }} records=${result.evalSupportAuthority.recordCount} hash=${if (result.evalSupportAuthority.authorityHash == "") { "<empty>" } else { result.evalSupportAuthority.authorityHash }} persisted=${result.evalSupportAuthorityPersisted}\n")
    for (source in result.sources) {
        out.append("source ${source.name} ok=${source.ok} files=${source.fileCount} records=${source.recordCount}\n")
    }
    for (gate in result.validation.failedGates) {
        out.append("failedGate=${gate}\n")
    }
    for (check in result.validation.queryChecks) {
        out.append("queryCheck=${check}\n")
    }
    for (diagnostic in result.diagnostics) {
        out.append("diagnostic=${diagnostic}\n")
    }
    out.toString()
}

public func assembleCkbFirstInitializationRecords(options: CkbFirstInitOptions): CkbFirstInitAssembly {
    let assembly = CkbFirstInitAssembly()
    let targetVersion = if (options.targetVersion.trimAscii() == "") { cangjieDefaultTargetVersion() } else { options.targetVersion.trimAscii() }
    let manifest = buildCangjieVersionManifestFromRoots(targetVersion: targetVersion,
        docsRoot: options.docsRoot,
        toolDocsRoot: options.toolDocsRoot,
        stdRoot: options.stdRoot,
        stdxRoot: options.stdxRoot,
        evalRoot: options.evalRoot)
    assembly.manifest = manifest
    if (manifest.degraded) {
        for (diagnostic in manifest.diagnostics) {
            assembly.diagnostics.add(diagnostic)
        }
    }
    let allResolution = resolveCangjieVersion(cangjieVersionSelector(targetVersion: targetVersion, sourceSet: CangjieSourceSets.ALL), manifest)
    ckbFirstInitCollectDocs(assembly, "docs", options.docsRoot, allResolution)
    if (options.toolDocsRoot.trimAscii() != "" && options.toolDocsRoot.trimAscii() != options.docsRoot.trimAscii()) {
        ckbFirstInitCollectDocs(assembly, "tools", options.toolDocsRoot, allResolution)
    }
    ckbFirstInitCollectEval(assembly, options.evalRoot, resolveCangjieVersion(cangjieVersionSelector(targetVersion: targetVersion, sourceSet: CangjieSourceSets.EVAL_SUPPORT), manifest))
    ckbFirstInitCollectSource(assembly, "std", options.stdRoot, CangjieSourceSets.STD, resolveCangjieVersion(cangjieVersionSelector(targetVersion: targetVersion, sourceSet: CangjieSourceSets.STD), manifest))
    ckbFirstInitCollectSource(assembly, "stdx", options.stdxRoot, CangjieSourceSets.STDX, resolveCangjieVersion(cangjieVersionSelector(targetVersion: targetVersion, sourceSet: CangjieSourceSets.STDX), manifest))
    assembly.records = dedupeCkbFirstInitializationRecords(assembly.records)
    assembly.ok = assembly.diagnostics.size == 0 && assembly.records.size > 0
    assembly
}

public func dedupeCkbFirstInitializationRecords(records: ArrayList<CangjieTypedRecord>): ArrayList<CangjieTypedRecord> {
    let out = ArrayList<CangjieTypedRecord>()
    for (record in records) {
        var seen = false
        for (existing in out) {
            if (existing.sourceId == record.sourceId && existing.recordKind == record.recordKind && existing.contentHash == record.contentHash) {
                seen = true
                break
            }
        }
        if (!seen) {
            out.add(record)
        }
    }
    out
}

public func validateCkbFirstInitializationRecords(records: ArrayList<CangjieTypedRecord>,
    evalSupportAuthority: CangjieEvalSupportSnapshot): CkbFirstInitValidationResult {
    let validation = CkbFirstInitValidationResult()
    ckbFirstInitRequireKind(validation, records, CangjieTypedRecordKinds.DOC_SECTION, "missing_doc_section")
    ckbFirstInitRequireKind(validation, records, CangjieTypedRecordKinds.TOOL_MANUAL, "missing_tool_manual")
    ckbFirstInitRequireTool(validation, records, "cjpm", "test")
    ckbFirstInitRequireSymbol(validation, records, "ArrayList.add")
    ckbFirstInitRequireSymbol(validation, records, "String.contains")
    ckbFirstInitRequireSymbol(validation, records, "HashMap")
    ckbFirstInitRequireSymbol(validation, records, "Option")
    let evalValidation = validateVersionedEvalSupportSnapshot(evalSupportAuthority)
    validation.queryChecks.add("evalAuthority:version=${evalSupportAuthority.datasetVersion}:records=${evalSupportAuthority.recordCount}:hash=${evalSupportAuthority.authorityHash}")
    if (!evalSupportAuthority.ok || !evalValidation.ok || evalSupportAuthority.recordCount == 0) {
        validation.failedGates.add("eval_support_authority_snapshot_invalid")
    }
    validation.ok = validation.failedGates.size == 0
    validation
}

public func ckbFirstInitCandidateVersion(targetVersion: String): String {
    "ckb-first-init-${ckbFirstInitSafeVersion(targetVersion)}-candidate"
}

public func ckbFirstInitActiveVersion(targetVersion: String): String {
    "ckb-first-init-${ckbFirstInitSafeVersion(targetVersion)}-active"
}

public func runCkbFirstInitialization(options: CkbFirstInitOptions, store: FileKnowledgeStore): CkbFirstInitResult {
    let result = CkbFirstInitResult()
    result.dryRun = options.dryRun || !options.apply
    result.candidateVersion = ckbFirstInitCandidateVersion(options.targetVersion)
    result.activeVersion = ""
    if (!validateCkbFirstInitOptions(options)) {
        for (diagnostic in options.diagnostics) {
            result.diagnostics.add(diagnostic)
        }
        return result
    }
    let assembly = assembleCkbFirstInitializationRecords(options)
    for (source in assembly.sources) {
        result.sources.add(source)
    }
    for (diagnostic in assembly.diagnostics) {
        result.diagnostics.add(diagnostic)
    }
    result.evalSupportAuthority = assembly.evalSupportAuthority
    result.validation = validateCkbFirstInitializationRecords(assembly.records, assembly.evalSupportAuthority)
    if (!assembly.ok) {
        if (options.apply && assembly.records.size > 0) {
            let loaded = newKnowledgeBaseFromStore(store)
            let kb = loaded.kb
            kb.loadFirstInitializationTypedRecords(assembly.records, result.candidateVersion)
            kb.markCandidateValidationFailed(result.candidateVersion)
            kb.persistCandidateSnapshot(store)
            result.activeVersion = kb.status().activeKnowledgeVersion
        }
        return result
    }
    if (!result.validation.ok) {
        if (options.apply && assembly.records.size > 0) {
            let loaded = newKnowledgeBaseFromStore(store)
            let kb = loaded.kb
            kb.loadFirstInitializationTypedRecords(assembly.records, result.candidateVersion)
            kb.markCandidateValidationFailed(result.candidateVersion)
            kb.persistCandidateSnapshot(store)
            result.activeVersion = kb.status().activeKnowledgeVersion
        }
        return result
    }
    if (!options.apply || options.dryRun) {
        result.ok = true
        return result
    }
    result.evalSupportAuthorityPersisted = persistVersionedEvalSupportSnapshot(store, assembly.evalSupportAuthority)
    if (!result.evalSupportAuthorityPersisted) {
        result.diagnostics.add("eval_support_authority_persist_failed")
        return result
    }
    let loaded = newKnowledgeBaseFromStore(store)
    let kb = loaded.kb
    kb.loadFirstInitializationTypedRecords(assembly.records, result.candidateVersion)
    let candidateValidation = validateCandidateServingIndex(kb.candidateRecordSnapshot(), result.candidateVersion)
    if (!candidateValidation.ok) {
        for (diagnostic in candidateValidation.diagnostics) {
            result.diagnostics.add(diagnostic)
        }
        kb.markCandidateValidationFailed(result.candidateVersion)
        kb.persistCandidateSnapshot(store)
        result.activeVersion = kb.status().activeKnowledgeVersion
        return result
    }
    result.activeVersion = ckbFirstInitActiveVersion(options.targetVersion)
    let promoted = kb.promoteFirstInitializationCandidate(result.activeVersion)
    kb.persistCandidateSnapshot(store)
    if (promoted) {
        kb.persistActiveSnapshot(store)
        store.saveCangjieVersionManifest(assembly.manifest)
    }
    result.persisted = promoted
    result.ok = promoted
    result.activeVersion = kb.status().activeKnowledgeVersion
    result
}

public func ckbFirstInitOptionsFromRuntime(config: CkbRuntimeConfig, apply!: Bool = true, dryRun!: Bool = false): CkbFirstInitOptions {
    let options = CkbFirstInitOptions()
    options.docsRoot = config.firstInitDocsRoot
    options.toolDocsRoot = config.firstInitToolDocsRoot
    options.stdRoot = config.firstInitStdRoot
    options.stdxRoot = config.firstInitStdxRoot
    options.evalRoot = config.firstInitEvalRoot
    options.targetVersion = if (config.firstInitTargetVersion.trimAscii() == "") { cangjieDefaultTargetVersion() } else { config.firstInitTargetVersion.trimAscii() }
    options.apply = apply
    options.dryRun = dryRun
    options.autoMode = true
    validateCkbFirstInitOptions(options)
    options
}

public func runCkbFirstInitializationWithActiveGuard(options: CkbFirstInitOptions, store: FileKnowledgeStore): CkbFirstInitResult {
    if (options.apply && !options.dryRun) {
        let snapshot = store.loadActiveSnapshot()
        if (snapshot.valid) {
            let result = CkbFirstInitResult()
            result.ok = true
            result.validation.ok = true
            result.activeVersion = snapshot.activeVersion
            result.candidateVersion = snapshot.candidateVersion
            result.persisted = false
            result.diagnostics.add("already_initialized")
            return result
        }
        if (store.hasAuthoritativeActiveSnapshotPointer()) {
            let result = CkbFirstInitResult()
            result.ok = false
            result.persisted = false
            result.diagnostics.add("active_snapshot_invalid:${snapshot.diagnostic}")
            return result
        }
    }
    runCkbFirstInitialization(options, store)
}

public func ckbEnsureFirstInitialized(config: CkbRuntimeConfig, store: FileKnowledgeStore): CkbFirstInitResult {
    if (!config.firstInitEnabled) {
        let result = CkbFirstInitResult()
        result.diagnostics.add("first_init_disabled")
        return result
    }
    runCkbFirstInitializationWithActiveGuard(ckbFirstInitOptionsFromRuntime(config, apply: true, dryRun: false), store)
}

private func ckbFirstInitCollectDocs(assembly: CkbFirstInitAssembly, name: String, root: String, resolution: CangjieVersionResolution): Unit {
    let clean = root.trimAscii()
    let summary = CkbFirstInitSourceSummary()
    summary.name = name
    summary.root = clean
    if (clean == "") {
        summary.diagnostics.add("missing_${name}_root")
        assembly.diagnostics.add("missing_${name}_root")
        assembly.sources.add(summary)
        return
    }
    let paths = discoverCangjieDocsRelativePaths(clean)
    let records = scanCangjieDocsRootFull(clean, resolution)
    summary.fileCount = paths.size
    summary.recordCount = records.records.size
    summary.ok = records.ok && records.records.size > 0
    for (diagnostic in records.diagnostics) {
        summary.diagnostics.add(diagnostic)
    }
    if (!resolution.ok) {
        for (diagnostic in resolution.diagnostics) {
            summary.diagnostics.add(diagnostic)
        }
    }
    for (record in records.records) {
        assembly.records.add(record)
    }
    if (!summary.ok) {
        assembly.diagnostics.add("${name}_scan_failed")
    }
    assembly.sources.add(summary)
}

private func ckbFirstInitCollectEval(assembly: CkbFirstInitAssembly, root: String, version: CangjieVersionResolution): Unit {
    let clean = root.trimAscii()
    let summary = CkbFirstInitSourceSummary()
    summary.name = "eval-support"
    summary.root = clean
    if (clean == "") {
        summary.diagnostics.add("missing_eval_root")
        assembly.diagnostics.add("missing_eval_root")
        assembly.sources.add(summary)
        return
    }
    let roots = discoverCangjieHumanEvalCaseRoots(clean)
    let snapshot = buildVersionedEvalSupportSnapshot(clean,
        "cangjie-${version.targetVersion}-eval-support", version: version)
    assembly.evalSupportAuthority = snapshot
    summary.fileCount = roots.size
    summary.recordCount = snapshot.recordCount
    summary.ok = snapshot.ok && snapshot.recordCount > 0
    for (diagnostic in snapshot.diagnostics) {
        summary.diagnostics.add(diagnostic)
    }
    if (!version.ok) {
        for (diagnostic in version.diagnostics) {
            summary.diagnostics.add(diagnostic)
        }
    }
    if (!summary.ok) {
        assembly.diagnostics.add("eval_support_scan_failed")
    }
    assembly.sources.add(summary)
}

private func ckbFirstInitCollectSource(assembly: CkbFirstInitAssembly, name: String, root: String, sourceSet: String, resolution: CangjieVersionResolution): Unit {
    let clean = root.trimAscii()
    let summary = CkbFirstInitSourceSummary()
    summary.name = name
    summary.root = clean
    if (clean == "") {
        summary.diagnostics.add("missing_${name}_root")
        assembly.diagnostics.add("missing_${name}_root")
        assembly.sources.add(summary)
        return
    }
    if (!resolution.ok) {
        for (diagnostic in resolution.diagnostics) {
            summary.diagnostics.add(diagnostic)
        }
    }
    let paths = discoverCangjieSourceRelativePaths(clean)
    let records = scanCangjieSourceSymbolsRoot(clean, sourceSet, resolution)
    summary.fileCount = paths.size
    summary.recordCount = records.records.size
    summary.ok = records.ok && records.records.size > 0
    for (diagnostic in records.diagnostics) {
        summary.diagnostics.add(diagnostic)
    }
    for (record in records.records) {
        assembly.records.add(record)
    }
    if (!summary.ok) {
        assembly.diagnostics.add("${name}_source_scan_failed")
    }
    assembly.sources.add(summary)
}

private func ckbFirstInitRequireKind(validation: CkbFirstInitValidationResult, records: ArrayList<CangjieTypedRecord>, kind: String, gate: String): Unit {
    let hit = ckbFirstInitHasKind(records, kind)
    validation.queryChecks.add("${kind}=${if (hit) { "hit" } else { "miss" }}")
    if (!hit) {
        validation.failedGates.add(gate)
    }
}

private func ckbFirstInitRequireTool(validation: CkbFirstInitValidationResult, records: ArrayList<CangjieTypedRecord>, tool: String, command: String): Unit {
    let hit = ckbFirstInitHasTool(records, tool, command)
    validation.queryChecks.add("tool:${tool}:${command}=${if (hit) { "hit" } else { "miss" }}")
    if (!hit) {
        validation.failedGates.add("missing_tool_${tool}_${command}")
    }
}

private func ckbFirstInitRequireSymbol(validation: CkbFirstInitValidationResult, records: ArrayList<CangjieTypedRecord>, symbol: String): Unit {
    let hit = ckbFirstInitHasSymbol(records, symbol)
    validation.queryChecks.add("symbol:${symbol}=${if (hit) { "hit" } else { "miss" }}")
    if (!hit) {
        validation.failedGates.add("missing_symbol_${symbol}")
    }
}

private func ckbFirstInitRequireContent(validation: CkbFirstInitValidationResult, records: ArrayList<CangjieTypedRecord>, kind: String, needle: String, gate: String): Unit {
    let hit = ckbFirstInitHasContent(records, kind, needle)
    validation.queryChecks.add("${kind}:${needle}=${if (hit) { "hit" } else { "miss" }}")
    if (!hit) {
        validation.failedGates.add(gate)
    }
}

private func ckbFirstInitHasKind(records: ArrayList<CangjieTypedRecord>, kind: String): Bool {
    for (record in records) {
        if (record.recordKind == kind) {
            return true
        }
    }
    false
}

private func ckbFirstInitHasTool(records: ArrayList<CangjieTypedRecord>, tool: String, command: String): Bool {
    for (record in records) {
        if (record.recordKind == CangjieTypedRecordKinds.TOOL_MANUAL && record.toolName == tool && record.command == command) {
            return true
        }
    }
    false
}

private func ckbFirstInitHasSymbol(records: ArrayList<CangjieTypedRecord>, symbol: String): Bool {
    for (record in records) {
        if (record.recordKind == CangjieTypedRecordKinds.SYMBOL_CARD && record.symbol == symbol) {
            return true
        }
    }
    false
}

private func ckbFirstInitHasContent(records: ArrayList<CangjieTypedRecord>, kind: String, needle: String): Bool {
    for (record in records) {
        if (record.recordKind == kind && record.content.contains(needle)) {
            return true
        }
    }
    false
}

private func ckbFirstInitSafeVersion(targetVersion: String): String {
    let raw = if (targetVersion.trimAscii() == "") { cangjieDefaultTargetVersion() } else { targetVersion.trimAscii() }
    let out = StringBuilder()
    for (ch in raw.toRuneArray()) {
        if ((ch >= r'a' && ch <= r'z') || (ch >= r'A' && ch <= r'Z') || (ch >= r'0' && ch <= r'9')) {
            out.append(ch)
        } else {
            out.append("-")
        }
    }
    out.toString().toAsciiLower()
}

private func ckbFirstInitValidatePath(path: String, name: String, diagnostics: ArrayList<String>): Unit {
    let clean = path.trimAscii().replace("\\", "/")
    if (clean == "") {
        return
    }
    if (clean.contains("\u{0}") || clean.contains("..")) {
        diagnostics.add("invalid_${name}")
        return
    }
    let lower = clean.toAsciiLower()
    if (lower.contains("/.ssh") || lower.contains("/.config") || lower.contains("/reference/") || lower.endsWith("/reference") || lower.contains("/hidden/") || lower.endsWith("/hidden")) {
        diagnostics.add("invalid_${name}")
    }
}
