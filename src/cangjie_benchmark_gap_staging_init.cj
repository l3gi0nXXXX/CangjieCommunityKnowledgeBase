package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}

public class CkbBenchmarkGapStagingInitResult {
    public var ok: Bool = false
    public var status: String = "failed"
    public var diagnostic: String = "not_started"
    public var activeVersion: String = ""
    public var activeCollection: String = ""
    public var candidateCollection: String = ""
    public var rawCount: Int64 = 0
    public var indexCount: Int64 = 0
    public var vectorCount: Int64 = 0
    public var transactionId: String = ""
    public var activeCollectionCreated: Bool = false
    public var candidateCollectionCreated: Bool = false
    public init() {}
}

public class CkbBenchmarkGapStagingInitCliOptions {
    public var diagnostic: String = "ok"
    public var configPath: String = ""
    public var storePath: String = ""
    public var json: Bool = false
    public init() {}
}

public func ckbBenchmarkGapStagingInitCliArgs(args: Array<String>): CkbBenchmarkGapStagingInitCliOptions {
    let options = CkbBenchmarkGapStagingInitCliOptions()
    var commandSeen = false
    var index: Int64 = 0
    while (index < args.size) {
        let arg = args[index]
        if (arg == "cangjie-benchmark-gap-staging-init" && !commandSeen) {
            commandSeen = true; index += 1; continue
        }
        if (arg == "--json") {
            if (options.json) { options.diagnostic = "duplicate_argument:--json"; return options }
            options.json = true; index += 1; continue
        }
        if (arg == "--config" || arg == "--store") {
            if (index + 1 >= args.size || args[index + 1].startsWith("--")) {
                options.diagnostic = "required_argument_value_missing:${arg}"; return options
            }
            if (arg == "--config") {
                if (options.configPath != "") { options.diagnostic = "duplicate_argument:--config"; return options }
                options.configPath = args[index + 1]
            } else {
                if (options.storePath != "") { options.diagnostic = "duplicate_argument:--store"; return options }
                options.storePath = args[index + 1]
            }
            index += 2; continue
        }
        options.diagnostic = if (arg.startsWith("--")) {
            "unknown_argument:${utf8SafePrefix(redactSensitive(arg), 80)}"
        } else { "unexpected_argument" }
        return options
    }
    if (!commandSeen) { options.diagnostic = "command_missing"; return options }
    if (options.configPath == "") { options.diagnostic = "required_argument_missing:--config"; return options }
    if (options.storePath == "") { options.diagnostic = "required_argument_missing:--store"; return options }
    options
}

public func ckbBenchmarkGapStagingConfigDiagnostic(config: CkbRuntimeConfig): String {
    if (config.networkEnabled) { return "network_must_be_disabled" }
    if (config.vectorBackend.trimAscii().toAsciiLower() != "qdrant") { return "qdrant_backend_required" }
    if (config.gitCodeAuthMode.trimAscii() != "" && config.gitCodeAuthMode.trimAscii().toAsciiLower() != "none") {
        return "auth_configuration_forbidden"
    }
    if (config.gitCodeTokenRef.trimAscii() != "" || config.gitCodeTokenFile.trimAscii() != "" ||
        config.embeddingTokenFile.trimAscii() != "" || config.vectorApiKeyFile.trimAscii() != "" ||
        config.serviceAdminTokenFile.trimAscii() != "" || config.serviceEventIngestTokenFile.trimAscii() != "") {
        return "credential_configuration_forbidden"
    }
    let active = config.vectorActiveCollection.trimAscii()
    let candidate = config.vectorCandidateCollection.trimAscii()
    if (!ckbBenchmarkGapStagingCollectionNameValid(active) ||
        !ckbBenchmarkGapStagingCollectionNameValid(candidate)) { return "collection_name_invalid" }
    if (active == candidate) { return "vector_collections_must_be_unique" }
    if (ckbBenchmarkGapStagingCollectionLegacy(active) ||
        ckbBenchmarkGapStagingCollectionLegacy(candidate)) { return "legacy_collection_forbidden" }
    "ok"
}

public func ckbBenchmarkGapStagingInit(config: CkbRuntimeConfig, store: FileKnowledgeStore,
    vectorStore: VectorStore): CkbBenchmarkGapStagingInitResult {
    let result = CkbBenchmarkGapStagingInitResult()
    result.activeCollection = config.vectorActiveCollection.trimAscii()
    result.candidateCollection = config.vectorCandidateCollection.trimAscii()
    let configDiagnostic = ckbBenchmarkGapStagingConfigDiagnostic(config)
    if (configDiagnostic != "ok") { result.diagnostic = configDiagnostic; return result }
    if (store.has("metadata/active-snapshot.manifest") ||
        store.hasAuthoritativeActiveSnapshotPointer()) {
        result.diagnostic = "authoritative_active_pointer_present"; return result
    }
    if (!ckbBenchmarkGapStagingStoreEmpty(store.root)) {
        result.diagnostic = "store_not_empty"; return result
    }
    let activeBefore = vectorStore.status(result.activeCollection)
    if (!ckbBenchmarkGapStagingCollectionAbsentOrEmpty(activeBefore)) {
        result.diagnostic = ckbBenchmarkGapStagingCollectionDiagnostic("active", activeBefore); return result
    }
    if (activeBefore.degradedReason == "collection_missing") {
        let created = vectorStore.ensureReadyCollection(result.activeCollection)
        if (!ckbBenchmarkGapStagingCollectionReadyEmpty(created)) {
            result.diagnostic = ckbBenchmarkGapStagingCollectionDiagnostic("active_create", created); return result
        }
        result.activeCollectionCreated = true
    }
    let candidateBefore = vectorStore.status(result.candidateCollection)
    if (!ckbBenchmarkGapStagingCollectionAbsentOrEmpty(candidateBefore)) {
        result.diagnostic = ckbBenchmarkGapStagingCollectionDiagnostic("candidate", candidateBefore)
        ckbBenchmarkGapStagingCleanupCreatedCollections(vectorStore, result); return result
    }
    if (candidateBefore.degradedReason == "collection_missing") {
        let created = vectorStore.ensureReadyCollection(result.candidateCollection)
        if (!ckbBenchmarkGapStagingCollectionReadyEmpty(created)) {
            result.diagnostic = ckbBenchmarkGapStagingCollectionDiagnostic("candidate_create", created)
            ckbBenchmarkGapStagingCleanupCreatedCollections(vectorStore, result); return result
        }
        result.candidateCollectionCreated = true
    }
    let snapshot = ActiveSnapshot()
    snapshot.valid = true
    snapshot.activeVersion = "ckb-benchmark-gap-staging-empty-v1"
    snapshot.activeStateSource = "persisted"
    snapshot.vectorActiveCollection = result.activeCollection
    snapshot.vectorCandidateCollection = result.candidateCollection
    let kb = KnowledgeBase(FakeClock(0), embeddingProviderFromRuntime(config), vectorStore, LocalGraphStore())
    kb.configureVectorCollections(result.activeCollection, result.candidateCollection)
    if (!kb.restoreActiveSnapshot(snapshot)) {
        result.diagnostic = "zero_record_knowledge_base_restore_failed"
        ckbBenchmarkGapStagingCleanupCreatedCollections(vectorStore, result); return result
    }
    let status = kb.status()
    if (status.storage.rawCount != 0 || status.storage.indexCount != 0 ||
        status.storage.vectorIndexCount != 0 ||
        status.storage.vectorActiveCollection != result.activeCollection ||
        status.storage.vectorCandidateCollection != result.candidateCollection) {
        result.diagnostic = "zero_record_knowledge_base_invariant_failed"
        ckbBenchmarkGapStagingCleanupCreatedCollections(vectorStore, result); return result
    }
    let emptyRaw = ArrayList<RawRecord>()
    let emptyNormalized = ArrayList<NormalizedRecord>()
    let emptyVectors = ArrayList<VectorRecord>()
    let transaction = store.writeActiveSnapshotTransaction(status, emptyRaw, emptyNormalized,
        emptyNormalized, emptyVectors, result.activeCollection, kb.activeGraphBuild())
    result.transactionId = transaction.txId
    if (!transaction.ok || !transaction.businessCommitted || !transaction.pointerCommitted) {
        result.diagnostic = "active_snapshot_transaction_failed"
        ckbBenchmarkGapStagingCleanupCreatedCollections(vectorStore, result); return result
    }
    let pointer = store.loadActiveSnapshotPointer()
    let reloaded = store.loadActiveSnapshot()
    if (!pointer.valid || pointer.activeVersion != snapshot.activeVersion ||
        pointer.vectorActiveCollection != result.activeCollection || !reloaded.valid ||
        reloaded.activeVersion != snapshot.activeVersion ||
        reloaded.vectorActiveCollection != result.activeCollection ||
        reloaded.vectorCandidateCollection != result.candidateCollection ||
        reloaded.rawRecords.size != 0 || reloaded.normalizedRecords.size != 0 ||
        reloaded.activeIndex.size != 0 || reloaded.vectorRecords.size != 0) {
        result.diagnostic = "committed_snapshot_reload_mismatch"; return result
    }
    let reloadedKb = KnowledgeBase(FakeClock(0), embeddingProviderFromRuntime(config), vectorStore,
        LocalGraphStore())
    reloadedKb.configureVectorCollections(result.activeCollection, result.candidateCollection)
    if (!reloadedKb.restoreActiveSnapshot(reloaded)) {
        result.diagnostic = "committed_knowledge_base_reload_failed"; return result
    }
    let reloadedStatus = reloadedKb.status()
    result.rawCount = reloadedStatus.storage.rawCount
    result.indexCount = reloadedStatus.storage.indexCount
    result.vectorCount = reloadedStatus.storage.vectorIndexCount
    if (result.rawCount != 0 || result.indexCount != 0 || result.vectorCount != 0 ||
        reloadedStatus.storage.vectorActiveCollection != result.activeCollection ||
        reloadedStatus.storage.vectorCandidateCollection != result.candidateCollection) {
        result.diagnostic = "committed_zero_record_invariant_failed"; return result
    }
    result.ok = true; result.status = "initialized"; result.diagnostic = "ok"; result
}

public func renderCkbBenchmarkGapStagingInitText(result: CkbBenchmarkGapStagingInitResult): String {
    if (result.ok) {
        return "benchmark-gap staging initialized; active=${utf8SafePrefix(redactSensitive(result.activeCollection), 120)}; candidate=${utf8SafePrefix(redactSensitive(result.candidateCollection), 120)}; raw=0; index=0; vector=0; snapshot=committed\n"
    }
    "benchmark-gap staging initialization failed; reason=${utf8SafePrefix(redactSensitive(result.diagnostic), 160)}\n"
}

public func renderCkbBenchmarkGapStagingInitJson(result: CkbBenchmarkGapStagingInitResult): String {
    "{\"ok\":${result.ok},\"status\":\"${ckbMcpJsonEscape(result.status)}\",\"diagnostic\":\"${ckbMcpJsonEscape(utf8SafePrefix(redactSensitive(result.diagnostic), 160))}\",\"activeCollection\":\"${ckbMcpJsonEscape(utf8SafePrefix(redactSensitive(result.activeCollection), 120))}\",\"candidateCollection\":\"${ckbMcpJsonEscape(utf8SafePrefix(redactSensitive(result.candidateCollection), 120))}\",\"rawCount\":${result.rawCount},\"indexCount\":${result.indexCount},\"vectorCount\":${result.vectorCount}}"
}

public func runCkbBenchmarkGapStagingInitCli(args: Array<String>): Int64 {
    let options = ckbBenchmarkGapStagingInitCliArgs(args)
    if (options.diagnostic != "ok") {
        let failed = CkbBenchmarkGapStagingInitResult(); failed.diagnostic = options.diagnostic
        if (options.json) { println(renderCkbBenchmarkGapStagingInitJson(failed)) }
        else { print(renderCkbBenchmarkGapStagingInitText(failed)) }
        return 2
    }
    let rawConfigDiagnostic = ckbBenchmarkGapStagingRawConfigDiagnostic(options.configPath)
    if (rawConfigDiagnostic != "ok") {
        let failed = CkbBenchmarkGapStagingInitResult(); failed.diagnostic = rawConfigDiagnostic
        if (options.json) { println(renderCkbBenchmarkGapStagingInitJson(failed)) }
        else { print(renderCkbBenchmarkGapStagingInitText(failed)) }
        return 1
    }
    let config = try { loadCkbRuntimeConfig(options.configPath) } catch (_: Exception) {
        let failed = CkbBenchmarkGapStagingInitResult(); failed.diagnostic = "invalid_config_encoding"
        if (options.json) { println(renderCkbBenchmarkGapStagingInitJson(failed)) }
        else { print(renderCkbBenchmarkGapStagingInitText(failed)) }
        return 1
    }
    let result = ckbBenchmarkGapStagingInit(config, FileKnowledgeStore(options.storePath),
        vectorStoreFromRuntime(config))
    if (options.json) { println(renderCkbBenchmarkGapStagingInitJson(result)) }
    else { print(renderCkbBenchmarkGapStagingInitText(result)) }
    if (result.ok) { 0 } else { 1 }
}

public func ckbBenchmarkGapStagingRawConfigDiagnostic(path: String): String {
    if (path.trimAscii() == "" || !exists(Path(path))) { return "config_file_missing" }
    let text = try { String.fromUtf8(File.readFrom(Path(path))) } catch (_: Exception) {
        return "invalid_config_encoding"
    }
    for (line in text.split("\n")) {
        let trimmed = line.trimAscii()
        if (trimmed == "" || trimmed.startsWith("#")) { continue }
        let parts = trimmed.split("=")
        if (parts.size < 2 || parts[0].trimAscii() == "") { return "malformed_config" }
        let key = parts[0].trimAscii().toAsciiLower()
        var value = parts[1].trimAscii()
        if (parts.size > 2) { for (index in 2..parts.size) { value += "=${parts[index]}" } }
        value = value.trimAscii()
        if (value == "") { continue }
        let credentialKey = key.contains("secret") || key.contains("password") ||
            key.endsWith(".token") || key.endsWith(".tokenfile") ||
            key.endsWith(".tokenref") || key.endsWith(".apikeyfile")
        if (credentialKey) { return "credential_configuration_forbidden" }
    }
    "ok"
}

private func ckbBenchmarkGapStagingStoreEmpty(root: Path): Bool {
    if (!exists(root)) { return true }
    try { ckbBenchmarkGapStagingDirectoryEmpty(root) } catch (_: Exception) { false }
}

private func ckbBenchmarkGapStagingDirectoryEmpty(root: Path): Bool {
    for (entry in Directory.readFrom(root)) {
        if (entry.isDirectory()) {
            if (!ckbBenchmarkGapStagingDirectoryEmpty(entry.path)) { return false }
        } else { return false }
    }
    true
}

private func ckbBenchmarkGapStagingCollectionNameValid(raw: String): Bool {
    if (raw == "" || raw.size > 120) { return false }
    for (value in raw.toArray()) {
        let alpha = (value >= UInt8(65) && value <= UInt8(90)) ||
            (value >= UInt8(97) && value <= UInt8(122))
        let digit = value >= UInt8(48) && value <= UInt8(57)
        if (!alpha && !digit && value != UInt8(45) && value != UInt8(95)) { return false }
    }
    true
}

private func ckbBenchmarkGapStagingCollectionLegacy(raw: String): Bool {
    let value = raw.trimAscii().toAsciiLower()
    value == "active" || value == "candidate" || value == "ckb_active" ||
        value == "ckb_candidate" || value.startsWith("legacy")
}

private func ckbBenchmarkGapStagingCollectionAbsentOrEmpty(status: VectorStoreStatus): Bool {
    status.degradedReason == "collection_missing" || ckbBenchmarkGapStagingCollectionReadyEmpty(status)
}

private func ckbBenchmarkGapStagingCollectionReadyEmpty(status: VectorStoreStatus): Bool {
    status.state == EmbeddingProviderState.READY && status.count == 0
}

private func ckbBenchmarkGapStagingCollectionDiagnostic(kind: String, status: VectorStoreStatus): String {
    if (status.state == EmbeddingProviderState.READY && status.count > 0) {
        return "${kind}_collection_not_empty"
    }
    "${kind}_collection_unavailable"
}

private func ckbBenchmarkGapStagingCleanupCreatedCollections(vectorStore: VectorStore,
    result: CkbBenchmarkGapStagingInitResult): Unit {
    if (result.candidateCollectionCreated) {
        _ = vectorStore.deleteCollection(result.candidateCollection)
        result.candidateCollectionCreated = false
    }
    if (result.activeCollectionCreated) {
        _ = vectorStore.deleteCollection(result.activeCollection)
        result.activeCollectionCreated = false
    }
}
