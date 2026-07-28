package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.sort.*
import stdx.crypto.digest.SHA256

public class CkbCandidateRuntimeMaterializeOptions {
    public var sourceStore: String = ""
    public var outputStore: String = ""
    public var candidateVersion: String = ""
    public init() {}
}

public class CkbCandidateRuntimeMaterializeResult {
    public var ok: Bool = false
    public var diagnostic: String = "candidate_runtime_not_run"
    public var activeVersion: String = ""
    public var rawCount: Int64 = 0
    public var normalizedCount: Int64 = 0
    public var activeCount: Int64 = 0
    public var candidateChecksum: String = ""
    public var immutableManifestHash: String = ""
    public var cleanManifestHash: String = ""
    public var manifestEvidenceHash: String = ""
    public var authorityHash: String = ""
    public var sourceEvidenceHash: String = ""
    public var pointerIdentityHash: String = ""
    public var txIdHash: String = ""
    public var transactionPayloadHash: String = ""
    public init() {}
}

public interface CkbCandidateRuntimeMaterializeFaultInjector {
    func checkpoint(point: String, output: FileKnowledgeStore): Unit
}

public class NoopCkbCandidateRuntimeMaterializeFaultInjector <:
    CkbCandidateRuntimeMaterializeFaultInjector {
    public func checkpoint(_point: String, _output: FileKnowledgeStore): Unit {}
}

public func ckbMaterializeCandidateRuntime(
    options: CkbCandidateRuntimeMaterializeOptions,
    faultInjector!: CkbCandidateRuntimeMaterializeFaultInjector =
        NoopCkbCandidateRuntimeMaterializeFaultInjector()
): CkbCandidateRuntimeMaterializeResult {
    let result = CkbCandidateRuntimeMaterializeResult()
    let paths = ckbCandidateRuntimePaths(options)
    if (paths[0] != "ok") { result.diagnostic = paths[0]; return result }
    let source = FileKnowledgeStore(paths[1])
    let output = FileKnowledgeStore(paths[2])
    let before = source.loadCandidateSnapshotImmutable(options.candidateVersion)
    if (!before.valid) { result.diagnostic = before.diagnostic; return result }
    let sourceEvidenceBefore = ckbCandidateRuntimeSourceEvidence(
        source, options.candidateVersion, before.batchCount)
    if (sourceEvidenceBefore[0] != "ok" ||
        !ckbCandidateRuntimeSha256(sourceEvidenceBefore[1])) {
        result.diagnostic = sourceEvidenceBefore[0]; return result
    }
    result.activeVersion = before.version
    result.rawCount = before.rawCount
    result.normalizedCount = before.normalizedCount
    result.activeCount = before.activeIndex.size
    result.candidateChecksum = before.candidateChecksum
    result.immutableManifestHash = before.immutableManifestHash
    result.cleanManifestHash = before.cleanManifestHash
    result.manifestEvidenceHash = before.manifestEvidenceHash
    result.authorityHash = before.authorityHash
    result.sourceEvidenceHash = sourceEvidenceBefore[1]
    try {
        let snapshot = ActiveSnapshot()
        snapshot.valid = true
        snapshot.diagnostic = "ok"
        snapshot.activeVersion = before.version
        snapshot.candidateVersion = before.version
        snapshot.activeStateSource = "persisted"
        snapshot.rawRecords = before.rawRecords
        snapshot.normalizedRecords = before.normalizedRecords
        snapshot.activeIndex = before.activeIndex
        let kb = KnowledgeBase(FakeClock(0))
        if (!kb.restoreActiveSnapshot(snapshot)) {
            result.diagnostic = "candidate_runtime_restore_failed"
            return result
        }
        kb.storage.vectorBackend = ""
        kb.storage.vectorState = EmbeddingProviderState.DEGRADED
        kb.storage.vectorIndexCount = 0
        kb.storage.vectorDimension = 0
        kb.storage.vectorDegradedReason = "vector_snapshot_missing"
        let committed = kb.persistActiveSnapshotUsingVectorRecords(output,
            ArrayList<VectorRecord>(), persistVectorFile: false)
        faultInjector.checkpoint("after_active_commit", output)
        if (!committed.ok || !committed.businessCommitted ||
            !committed.pointerCommitted || committed.txId == "") {
            throw Exception("candidate_runtime_commit_failed")
        }
        let outputRoot = ckbCandidateRuntimeCanonicalExisting(options.outputStore)
        if (outputRoot[0] != "ok" || outputRoot[1] != paths[2]) {
            throw Exception("candidate_runtime_output_path_drift")
        }
        let pointer = output.loadActiveSnapshotPointer()
        if (!pointer.valid || pointer.legacy || pointer.txId != committed.txId ||
            pointer.activeVersion != before.version) {
            throw Exception("candidate_runtime_pointer_mismatch")
        }
        let txRoot = output.root.join("transactions").join(pointer.txId)
        let canonicalTx = try { canonicalize(txRoot).toString() }
            catch (_: Exception) { "" }
        if (canonicalTx != paths[2] + "/transactions/" + pointer.txId ||
            !ckbCandidateRuntimeRegularFile(txRoot.join("COMMIT"))) {
            throw Exception("candidate_runtime_commit_marker_invalid")
        }
        let loaded = output.loadActiveSnapshot()
        let metadata = output.loadMetadataStatus()
        if (!loaded.valid || loaded.activeVersion != before.version ||
            loaded.candidateVersion != before.version ||
            loaded.hasVectorArtifact ||
            !metadata.valid || metadata.activeVersion != before.version ||
            metadata.vectorState != EmbeddingProviderState.DEGRADED ||
            metadata.vectorIndexCount != 0 || metadata.vectorDimension != 0 ||
            metadata.vectorDegradedReason != "vector_snapshot_missing" ||
            loaded.rawRecords.size != before.rawCount ||
            loaded.normalizedRecords.size != before.normalizedCount ||
            loaded.activeIndex.size != before.activeIndex.size ||
            ckbCertifiedNormalizedRecordsChecksum(loaded.normalizedRecords) !=
                before.candidateChecksum ||
            ckbCertifiedNormalizedRecordsChecksum(loaded.activeIndex) !=
                before.candidateChecksum) {
            throw Exception("candidate_runtime_readback_mismatch")
        }
        if (ckbCandidateRuntimeFileHash(source.root.join(
                "raw/candidate/${before.version}/records.ckb")) !=
                ckbCandidateRuntimeFileHash(txRoot.join("raw/records.ckb")) ||
            ckbCandidateRuntimeFileHash(source.root.join(
                "normalized/candidate/${before.version}.ckb")) !=
                ckbCandidateRuntimeFileHash(txRoot.join("normalized/records.ckb")) ||
            ckbCandidateRuntimeFileHash(source.root.join(
                "normalized/candidate/${before.version}.ckb")) !=
                ckbCandidateRuntimeFileHash(txRoot.join("index/active.ckb"))) {
            throw Exception("candidate_runtime_payload_bytes_mismatch")
        }
        faultInjector.checkpoint("before_source_recheck", output)
        let after = source.loadCandidateSnapshotImmutable(options.candidateVersion)
        let sourceEvidenceAfter = ckbCandidateRuntimeSourceEvidence(
            source, options.candidateVersion, before.batchCount)
        if (!after.valid || sourceEvidenceAfter[0] != "ok" ||
            after.immutableManifestHash != before.immutableManifestHash ||
            after.cleanManifestHash != before.cleanManifestHash ||
            after.manifestEvidenceHash != before.manifestEvidenceHash ||
            after.candidateChecksum != before.candidateChecksum ||
            after.authorityHash != before.authorityHash ||
            sourceEvidenceAfter[1] != sourceEvidenceBefore[1]) {
            throw Exception("candidate_runtime_source_drift")
        }
        let finalPointer = output.loadActiveSnapshotPointer()
        if (!finalPointer.valid ||
            ckbActiveSnapshotPointerIdentityHash(finalPointer) !=
                ckbActiveSnapshotPointerIdentityHash(pointer)) {
            throw Exception("candidate_runtime_pointer_drift")
        }
        result.pointerIdentityHash =
            ckbActiveSnapshotPointerIdentityHash(finalPointer)
        result.txIdHash = benchmarkGapSha256(pointer.txId)
        result.transactionPayloadHash = committed.payloadHash
        if (!ckbCandidateRuntimeHsha256(result.transactionPayloadHash)) {
            throw Exception("candidate_runtime_transaction_hash_invalid")
        }
        result.ok = true
        result.diagnostic = "ok"
        result
    } catch (e: Exception) {
        result.ok = false
        result.diagnostic = if (e.message.startsWith("candidate_runtime_")) {
            e.message
        } else { "candidate_runtime_materialize_failed" }
        try {
            if (exists(output.root) &&
                ckbCandidateRuntimeSafeOwnedDirectory(output.root, paths[2])) {
                remove(output.root, recursive: true)
            }
        } catch (_: Exception) {
            result.diagnostic = "candidate_runtime_cleanup_failed"
        }
        result
    }
}

public func runCkbCandidateRuntimeMaterializeCli(args: Array<String>): Int64 {
    let options = CkbCandidateRuntimeMaterializeOptions()
    var commandSeen = false
    var sourceSeen = false
    var outputSeen = false
    var versionSeen = false
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "cangjie-candidate-runtime-materialize" && !commandSeen) {
            commandSeen = true; i += 1; continue
        }
        if (arg != "--source-store" && arg != "--output-store" &&
            arg != "--candidate-version") {
            println("candidate runtime materialize blocked: unknown_argument")
            return 2
        }
        if (i + 1 >= args.size) {
            println("candidate runtime materialize blocked: missing_argument_value")
            return 2
        }
        if (arg == "--source-store") {
            if (sourceSeen) {
                println("candidate runtime materialize blocked: duplicate_argument")
                return 2
            }
            sourceSeen = true; options.sourceStore = args[i + 1]
        } else if (arg == "--output-store") {
            if (outputSeen) {
                println("candidate runtime materialize blocked: duplicate_argument")
                return 2
            }
            outputSeen = true; options.outputStore = args[i + 1]
        } else {
            if (versionSeen) {
                println("candidate runtime materialize blocked: duplicate_argument")
                return 2
            }
            versionSeen = true; options.candidateVersion = args[i + 1]
        }
        i += 2
    }
    if (!commandSeen) {
        println("candidate runtime materialize blocked: command_required")
        return 2
    }
    if (!sourceSeen || !outputSeen || !versionSeen) {
        println("candidate runtime materialize blocked: required_argument_missing")
        return 2
    }
    let result = ckbMaterializeCandidateRuntime(options)
    println("candidate runtime materialize ok=${result.ok} activeVersion=${result.activeVersion} raw=${result.rawCount} normalized=${result.normalizedCount} active=${result.activeCount} candidateChecksum=${result.candidateChecksum} immutableManifestHash=${result.immutableManifestHash} cleanManifestHash=${result.cleanManifestHash} manifestEvidenceHash=${result.manifestEvidenceHash} authorityHash=${result.authorityHash} sourceEvidenceHash=${result.sourceEvidenceHash} pointerIdentityHash=${result.pointerIdentityHash} txIdHash=${result.txIdHash} transactionPayloadHash=${result.transactionPayloadHash} diagnostic=${result.diagnostic}")
    if (result.ok) { 0 } else { 1 }
}

private func ckbCandidateRuntimePaths(
    options: CkbCandidateRuntimeMaterializeOptions): (String, String, String) {
    if (options.sourceStore == "" || options.outputStore == "" ||
        options.candidateVersion == "") {
        return ("candidate_runtime_options_invalid", "", "")
    }
    for (value in [options.sourceStore, options.outputStore]) {
        if (value.contains("\u{0}") || value.contains("\\") ||
            ckbCandidateRuntimeHasParentSegment(value)) {
            return ("candidate_runtime_path_invalid", "", "")
        }
    }
    let source = ckbCandidateRuntimeCanonicalExisting(options.sourceStore)
    if (source[0] != "ok" || source[1] != options.sourceStore) {
        return ("candidate_runtime_source_path_invalid", "", "")
    }
    if (exists(Path(options.outputStore))) {
        return ("candidate_runtime_output_exists", "", "")
    }
    let outputPath = Path(options.outputStore)
    let parent = try { canonicalize(outputPath.parent).toString() }
        catch (_: Exception) {
            return ("candidate_runtime_output_parent_invalid", "", "")
        }
    let output = Path(parent).join(outputPath.fileName).toString()
    if (output != options.outputStore) {
        return ("candidate_runtime_output_path_invalid", "", "")
    }
    if (source[1] == output || source[1].startsWith(output + "/") ||
        output.startsWith(source[1] + "/")) {
        return ("candidate_runtime_store_overlap", "", "")
    }
    ("ok", source[1], output)
}

private func ckbCandidateRuntimeCanonicalExisting(path: String): (String, String) {
    try { ("ok", canonicalize(Path(path)).toString()) }
    catch (_: Exception) { ("candidate_runtime_path_unreadable", "") }
}

private func ckbCandidateRuntimeHasParentSegment(path: String): Bool {
    for (part in path.split("/")) {
        if (part == "..") { return true }
    }
    false
}

private func ckbCandidateRuntimeRegularFile(path: Path): Bool {
    if (!exists(path)) { return false }
    let canonical = try { canonicalize(path).toString() } catch (_: Exception) { return false }
    if (canonical != path.toString()) { return false }
    try {
        for (entry in Directory.readFrom(path.parent)) {
            if (entry.name == path.fileName) { return entry.isRegular() }
        }
        false
    } catch (_: Exception) { false }
}

private func ckbCandidateRuntimeSafeOwnedDirectory(path: Path,
    expected: String): Bool {
    let canonical = try { canonicalize(path).toString() }
        catch (_: Exception) { return false }
    if (canonical != expected || path.toString() != expected) { return false }
    try {
        for (entry in Directory.readFrom(path.parent)) {
            if (entry.name == path.fileName) { return entry.isDirectory() }
        }
        false
    } catch (_: Exception) { false }
}

private func ckbCandidateRuntimeSourceEvidence(store: FileKnowledgeStore,
    version: String, batchCount: Int64): (String, String) {
    let paths = ArrayList<String>()
    paths.add("raw/candidate/${version}/records.ckb")
    paths.add("normalized/candidate/${version}.ckb")
    paths.add("candidate-artifacts/${version}/manifest.ckb")
    paths.add("candidate-artifacts/${version}/clean-candidate-manifest.json")
    paths.add("candidate-artifacts/${version}/clean-candidate-audit.json")
    for (index in 0..batchCount) {
        paths.add("candidate-artifacts/${version}/batches/batch-${index}.ckb")
    }
    let entries = ArrayList<String>()
    for (relative in paths) {
        let path = store.root.join(relative)
        if (!ckbCandidateRuntimeRegularFile(path)) {
            return ("candidate_runtime_source_artifact_invalid", "")
        }
        let fileHash = ckbCandidateRuntimeFileHash(path)
        if (!ckbCandidateRuntimeSha256(fileHash)) {
            return ("candidate_runtime_source_artifact_invalid", "")
        }
        entries.add("${relative.toArray().size}:${relative}=${fileHash}")
    }
    let ordered = entries.toArray()
    sort(ordered)
    let seed = StringBuilder()
    for (entry in ordered) { seed.append(entry) }
    ("ok", benchmarkGapSha256(seed.toString()))
}

private func ckbCandidateRuntimeFileHash(path: Path): String {
    try {
        let digest = SHA256()
        digest.write(File.readFrom(path))
        let out = StringBuilder()
        for (byte in digest.finish()) {
            out.append(ckbCandidateRuntimeHex(byte / UInt8(16)))
            out.append(ckbCandidateRuntimeHex(byte % UInt8(16)))
        }
        "sha256:${out.toString()}"
    } catch (_: Exception) { "" }
}

private func ckbCandidateRuntimeSha256(value: String): Bool {
    if (!value.startsWith("sha256:") || value.toRuneArray().size != 71) {
        return false
    }
    for (rune in value.toRuneArray()[7..71]) {
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) {
            return false
        }
    }
    true
}

private func ckbCandidateRuntimeHsha256(value: String): Bool {
    if (!value.startsWith("hsha256:") || value.toRuneArray().size != 72) {
        return false
    }
    for (rune in value.toRuneArray()[8..72]) {
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) {
            return false
        }
    }
    true
}

private func ckbCandidateRuntimeHex(value: UInt8): String {
    if (value < UInt8(10)) {
        String.fromUtf8([UInt8(48) + value])
    } else {
        String.fromUtf8([UInt8(87) + value])
    }
}
