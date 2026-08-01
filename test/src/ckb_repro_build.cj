package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashSet}
import std.fs.{File, Path, canonicalize, exists}
import std.sort.*
import stdx.encoding.json.*

public class CkbReproSourceLockEntry {
    public var sourceId: String = ""
    public var sourceType: String = ""
    public var repository: String = ""
    public var commit: String = ""
    public var tree: String = ""
    public var path: String = ""
    public var fileHash: String = ""
    public var license: String = ""
    public var authMode: String = ""
    public var generatorId: String = ""
    public var generatorVersion: String = ""
    public var generatorSourceHash: String = ""
    public var inputHashes: ArrayList<String> = ArrayList<String>()
    public var outputHash: String = ""
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
        let loaded = loadCkbPortablePromotionCliInputs(options.candidateManifest,
            options.p8BReport)
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

public func loadCkbPortablePromotionCliInputs(candidatePath: String,
    p8BPath: String): (CkbReproContractResult, CkbPortablePromotionOptions) {
    let options = CkbPortablePromotionOptions()
    try {
        let candidate = JsonValue.fromStr(String.fromUtf8(
            File.readFrom(Path(candidatePath)))).asObject()
        let p8b = JsonValue.fromStr(String.fromUtf8(
            File.readFrom(Path(p8BPath)))).asObject()
        options.candidateVersion = p4BuildRequiredString(candidate, "candidateVersion")
        options.candidateManifestHash =
            p4BuildRequiredString(candidate, "candidateManifestHash")
        options.p2ProofHash = p4BuildRequiredString(candidate, "p2ProofHash")
        options.p3ProofHash = p4BuildRequiredString(candidate, "p3ProofHash")
        options.p5ProofHash = p4BuildRequiredString(candidate, "p5ProofHash")
        options.p8AProofHash = p4BuildRequiredString(candidate, "p8AProofHash")
        options.identity = p4BuildRequiredString(candidate, "identity")
        options.p8StrictPassed = p4BuildRequiredInt(candidate, "p8StrictPassed")
        options.p8BProofHash = p4BuildRequiredString(p8b, "p8BProofHash")
        if (!p4BuildRequiredBool(p8b, "ready") ||
            p4BuildRequiredString(p8b, "candidateVersion") != options.candidateVersion ||
            p4BuildRequiredString(p8b, "identity") != options.identity) {
            return (p4BuildFailure("promotion_p8_b_report_invalid"), options)
        }
    } catch (_: Exception) {
        return (p4BuildFailure("promotion_artifact_malformed_json"), options)
    }
    for (hash in [options.candidateManifestHash, options.p2ProofHash,
        options.p3ProofHash, options.p5ProofHash, options.p8AProofHash,
        options.p8BProofHash]) {
        if (!p4BuildHash(hash)) { return (p4BuildFailure("promotion_proof_missing"), options) }
    }
    if (options.candidateVersion == "" || options.identity == "" ||
        options.p8StrictPassed != 151) {
        return (p4BuildFailure("promotion_identity_invalid"), options)
    }
    (p4BuildSuccess(), options)
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
     "--candidate-manifest", "--p8-b-report"].contains(arg)
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
            entry.fileHash = p4BuildOptionalString(object, "fileHash")
            entry.license = p4BuildOptionalString(object, "license")
            entry.authMode = p4BuildOptionalString(object, "authMode")
            entry.generatorId = p4BuildOptionalString(object, "generatorId")
            entry.generatorVersion = p4BuildOptionalString(object, "generatorVersion")
            entry.generatorSourceHash = p4BuildOptionalString(object, "generatorSourceHash")
            entry.outputHash = p4BuildOptionalString(object, "outputHash")
            match (object.get("inputHashes")) {
                case Some(items) =>
                    for (item in items.asArray().getItems()) {
                        entry.inputHashes.add(item.asString().getValue())
                    }
                case None => ()
            }
            lock.entries.add(entry)
        }
        (p4BuildSuccess(), lock)
    } catch (_: Exception) {
        (p4BuildFailure("source_lock_malformed_json"), CkbReproSourceLock())
    }
}

public func validateCkbReproBuildLocks(lock: CkbReproSourceLock): CkbReproContractResult {
    if (lock.schemaVersion != "ckb-source-lock-v1" || lock.entries.size == 0) {
        return p4BuildFailure("source_lock_contract_invalid")
    }
    let ids = HashSet<String>()
    for (entry in lock.entries) {
        if (entry.sourceId == "" || ids.contains(entry.sourceId) || entry.license == "") {
            return p4BuildFailure("source_lock_identity_invalid")
        }
        ids.add(entry.sourceId)
        if (entry.sourceType == "external_git") {
            if (entry.generatorId != "" || entry.generatorVersion != "" ||
                entry.generatorSourceHash != "" || entry.inputHashes.size > 0 ||
                entry.outputHash != "") {
                return p4BuildFailure("external_source_fields_mixed")
            }
            if (!p4BuildAnonymousHttps(entry.repository) || !p4BuildCommit(entry.commit) ||
                !p4BuildHash(entry.tree) || !p4BuildSafeRelative(entry.path) ||
                !p4BuildHash(entry.fileHash) || entry.authMode != "anonymous") {
                return p4BuildFailure("external_source_contract_invalid")
            }
        } else if (entry.sourceType == "generated") {
            if (entry.repository != "" || entry.commit != "" || entry.tree != "" ||
                entry.path != "" || entry.fileHash != "" || entry.authMode != "") {
                return p4BuildFailure("generated_source_fields_mixed")
            }
            if (entry.generatorId == "" || entry.generatorVersion == "" ||
                !p4BuildHash(entry.generatorSourceHash) || entry.inputHashes.size == 0 ||
                !p4BuildHash(entry.outputHash)) {
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

public func canonicalCkbReproSourceLockHash(lock: CkbReproSourceLock): String {
    let rows = ArrayList<String>()
    for (entry in lock.entries) {
        let inputs = entry.inputHashes.toArray(); sort(inputs)
        rows.add(p4BuildFields([
            entry.sourceId, entry.sourceType, entry.repository, entry.commit, entry.tree,
            entry.path, entry.fileHash, entry.license, entry.authMode, entry.generatorId,
            entry.generatorVersion, entry.generatorSourceHash,
            p4BuildJoin(inputs, ","), entry.outputHash
        ]))
    }
    let ordered = rows.toArray(); sort(ordered)
    benchmarkGapSha256("ckb-source-lock-v1|" + p4BuildJoin(ordered, "\n"))
}

public class CkbReproKnowledgeInventoryRow {
    public var identity: String = ""
    public var sourceId: String = ""
    public var recordKind: String = ""
    public var portableLocator: String = ""
    public var sourceType: String = ""
    public var license: String = ""
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
    provider: CkbPortablePathHmacProvider): ArrayList<CkbReproKnowledgeInventoryRow> {
    let rows = ArrayList<CkbReproKnowledgeInventoryRow>()
    for (record in typed) {
        let row = CkbReproKnowledgeInventoryRow()
        row.identity = provider.recordId(canonicalCkbPortableTypedRecord(record))
        row.sourceId = record.sourceId; row.recordKind = record.recordKind
        row.portableLocator = record.path; row.sourceType = "generated"
        row.license = "declared"; rows.add(row)
    }
    for (record in raw) {
        let row = CkbReproKnowledgeInventoryRow()
        row.identity = provider.recordId(canonicalCkbPortableRawRecord(record))
        row.sourceId = record.sourceId; row.recordKind = "raw"
        row.portableLocator = record.metadata.path; row.sourceType = record.metadata.sourceType
        row.license = record.metadata.license; rows.add(row)
    }
    rows
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
    for (source in lock.entries) {
        let entry = CkbReproSourceMaterialEntry()
        entry.sourceId = source.sourceId
        entry.action = if (source.sourceType == "external_git") {
            "fetch_required"
        } else { "build_required" }
        entry.expectedHash = if (source.sourceType == "external_git") {
            source.fileHash
        } else { source.outputHash }
        entry.canonicalIdentity = benchmarkGapSha256(
            p4BuildFields([source.sourceId, source.sourceType,
                canonicalCkbReproSourceLockHash(lock), entry.expectedHash]))
        manifest.entries.add(entry)
    }
    manifest.ready = true; manifest.diagnostic = "ok"; manifest
}

public func renderCkbSourceMaterialsManifest(
    manifest: CkbReproSourceMaterialsManifest): String {
    let rows = ArrayList<String>()
    for (entry in manifest.entries) {
        rows.add("${entry.sourceId}|${entry.action}|${entry.expectedHash}|" +
            entry.canonicalIdentity)
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
            normalized.add(normalizer.normalize(record, "",
                input.request.candidateVersion))
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
    public var preservationHash: String = ""
    public init() {}
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
    result.proof.preservationHash = benchmarkGapSha256(
        preservation.typedPairAggregateHash + "|" + preservation.rawPairAggregateHash)
    result.ready = true; result.diagnostic = "ok"; result
}

public func renderCkbReproBuildProof(proof: CkbReproBuildProof): String {
    "{\"logicalReady\":${proof.logicalReady},\"diagnostic\":\"${p4BuildEscape(proof.diagnostic)}\"," +
    "\"sourceLockHash\":\"${proof.sourceLockHash}\",\"typedCount\":${proof.typedCount}," +
    "\"rawCount\":${proof.rawCount},\"selectedCount\":${proof.selectedCount}," +
    "\"excludedCount\":${proof.excludedCount},\"evalSupportPersisted\":" +
    "${proof.evalSupportPersisted},\"vectorCount\":${proof.vectorCount}," +
    "\"vectorState\":\"${proof.vectorState}\",\"preservationHash\":" +
    "\"${proof.preservationHash}\"}"
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
    public var p8BProofHash: String = ""
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
        options.p3ProofHash, options.p5ProofHash, options.p8AProofHash,
        options.p8BProofHash]) {
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
        restoreCkbQdrantSnapshot(this.targetCollection, this.snapshotBytes,
            this.snapshotManifest, this.executor).ok
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
    value.replace("\\", "\\\\").replace("\"", "\\\"")
        .replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
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
