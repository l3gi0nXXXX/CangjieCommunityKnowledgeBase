package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashMap, HashSet}
import std.env.getVariable
import std.fs.{Directory, File, OpenMode, Path, canonicalize, exists, remove, rename}
import std.sort.*
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

public class CkbLogicalSnapshotSourceStates {
    public static let PORTABLE_VECTOR_CANDIDATE: String = "portableVectorCandidate"
    public static let PROMOTED_PORTABLE_PRODUCTION: String = "promotedPortableProduction"
    public static let PORTABLE_VECTOR_ARTIFACT: String = "portableVectorArtifact"
}

public class CkbReleaseArchiveEntryKinds {
    public static let REGULAR: String = "regular"
    public static let DIRECTORY: String = "directory"
    public static let SYMLINK: String = "symlink"
    public static let HARDLINK: String = "hardlink"
    public static let DEVICE: String = "device"
    public static let FIFO: String = "fifo"
    public static let SOCKET: String = "socket"
}

public class CkbLogicalSnapshotAsset {
    public var relativePath: String = ""
    public var size: Int64 = 0
    public var sha256: String = ""
    public var entryType: String = CkbReleaseArchiveEntryKinds.REGULAR
    public init() {}
}

public class CkbLogicalSnapshotManifest {
    public var schemaVersion: String = ""
    public var sourceState: String = CkbLogicalSnapshotSourceStates.PORTABLE_VECTOR_ARTIFACT
    public var portableKnowledgeVersion: String = ""
    public var p4PortableProofHash: String = ""
    public var p3VectorProofHash: String = ""
    public var vectorState: String = ""
    public var vectorCollection: String = ""
    public var vectorCount: Int64 = 0
    public var vectorDimension: Int64 = 0
    public var rawCount: Int64 = 0
    public var normalizedCount: Int64 = 0
    public var normalizedChecksum: String = ""
    public var indexCount: Int64 = 0
    public var graphNodeCount: Int64 = 0
    public var graphEdgeCount: Int64 = 0
    public var activePointerHash: String = ""
    public var contaminationProofHash: String = ""
    public var assets: ArrayList<CkbLogicalSnapshotAsset> =
        ArrayList<CkbLogicalSnapshotAsset>()
    public var manifestHash: String = ""
    public init() {}
}

public class CkbLogicalSnapshotContract {
    public var ok: Bool = false
    public var diagnostic: String = "not_validated"
    public var canonicalJson: String = ""
    public var manifestHash: String = ""
    public init() {}
}

public class CkbLogicalSnapshotExportProofs {
    public var sourceState: String = ""
    public var portableKnowledgeVersion: String = ""
    public var p4PortableProofHash: String = ""
    public var p3VectorProofHash: String = ""
    // False is permitted only for the explicitly labelled synthetic acceptance lane.
    public var p3ProofReal: Bool = false
    public var vectorState: String = ""
    public var vectorCollection: String = ""
    public var vectorCount: Int64 = 0
    public var vectorDimension: Int64 = 0
    public var pathMachineFindingCount: Int64 = -1
    public var pathUnmappedFindingCount: Int64 = -1
    public var contaminationProofHash: String = ""
    public var expectedStartPointerHash: String = ""
    public var expectedEndPointerHash: String = ""
    public init() {}
}

public class CkbReleasePathPolicy {
    public var worktreeRoot: String = ""
    public var productionStoreRoot: String = ""
    public var userConfigRoot: String = ""
    public init() {}
}

public class CkbReleaseArchiveEntry {
    public var path: String = ""
    public var kind: String = ""
    public var size: Int64 = 0
    public var linkTarget: String = ""
    public init() {}
}

public class CkbReleaseArchivePayload {
    public var path: String = ""
    public var bytes: Array<UInt8> = Array<UInt8>()
    public var sourcePath: String = ""
    public var size: Int64 = 0
    public var sha256: String = ""
    public init() {}
}

public class CkbReleaseArchiveOperation {
    public var ok: Bool = false
    public var diagnostic: String = "archive_operation_failed"
    public init() {}
}

private class CkbReleaseSourceScan {
    public var ok: Bool = false
    public var diagnostic: String = "logical_snapshot_asset_read_failed"
    public var size: Int64 = 0
    public var sha256: String = ""
    public init() {}
}

public class CkbReleaseArchiveListing {
    public var ok: Bool = false
    public var diagnostic: String = "archive_listing_failed"
    public var entries: ArrayList<CkbReleaseArchiveEntry> =
        ArrayList<CkbReleaseArchiveEntry>()
    public init() {}
}

public class CkbReleaseArchiveRead {
    public var ok: Bool = false
    public var diagnostic: String = "archive_entry_read_failed"
    public var bytes: Array<UInt8> = Array<UInt8>()
    public init() {}
}

public interface CkbReleaseArchiveBackend {
    func create(archivePath: String,
        values: ArrayList<CkbReleaseArchivePayload>): CkbReleaseArchiveOperation
    func enumerate(archivePath: String): CkbReleaseArchiveListing
    func readRegular(archivePath: String,
        relativePath: String): CkbReleaseArchiveRead
    func supportsStreaming(): Bool
    func createFromFiles(archivePath: String,
        values: ArrayList<CkbReleaseArchivePayload>): CkbReleaseArchiveOperation
    func extractRegularToFile(archivePath: String, relativePath: String,
        outputPath: String, expectedSize: Int64,
        expectedSha256: String): CkbReleaseArchiveOperation
    func extractAllRegularToDirectory(archivePath: String, outputRoot: String,
        manifest: CkbLogicalSnapshotManifest): CkbReleaseArchiveOperation
    func archiveHash(archivePath: String): String
}

public class CkbReleaseArchiveLimits {
    public var maxEntries: Int64 = 128
    public var maxEntryBytes: Int64 = 67108864
    public var maxTotalBytes: Int64 = 536870912
    public init() {}
}

public class CkbReleaseArchiveInspection {
    public var ok: Bool = false
    public var diagnostic: String = "archive_not_inspected"
    public var manifest: CkbLogicalSnapshotManifest =
        CkbLogicalSnapshotManifest()
    public var entries: ArrayList<CkbReleaseArchiveEntry> =
        ArrayList<CkbReleaseArchiveEntry>()
    public init() {}
}

public class CkbLogicalSnapshotResult {
    public var ok: Bool = false
    public var diagnostic: String = "not_started"
    public var evidenceLevel: String = ""
    public var realP3Bound: Bool = false
    public var activeVersion: String = ""
    public var rawCount: Int64 = 0
    public var normalizedCount: Int64 = 0
    public var indexCount: Int64 = 0
    public var graphNodeCount: Int64 = 0
    public var graphEdgeCount: Int64 = 0
    public var vectorCollection: String = ""
    public var vectorCount: Int64 = 0
    public var vectorDimension: Int64 = 0
    public var normalizedChecksum: String = ""
    public var activePointerHash: String = ""
    public var manifestHash: String = ""
    public var archiveHash: String = ""
    public init() {}
}

// Thin CLI contract used by main; archive/proof loading remains behind the
// production context so tests never need a real store or archive tool.
public class CkbReleaseCliOptions {
    public var mode: String = ""
    public var storeRoot: String = ""
    public var logicalProof: String = ""
    public var vectorProof: String = ""
    public var output: String = ""
    public var archive: String = ""
    public var targetRoot: String = ""
    public var json: Bool = false
    public var diagnostic: String = "not_parsed"
    public init() {}
}

public class CkbReleaseCliOperationResult {
    public var ok: Bool = false
    public var diagnostic: String = "not_run"
    public var summary: String = ""
    public init() {}
}

public class CkbReleaseCliExecution {
    public var ok: Bool = false
    public var exitCode: Int64 = 2
    public var diagnostic: String = "not_run"
    public var output: String = ""
    public init() {}
}

public interface CkbReleaseCliAdapter {
    func execute(options: CkbReleaseCliOptions): CkbReleaseCliOperationResult
}

public func parseCkbReleaseCliOptions(args: Array<String>): CkbReleaseCliOptions {
    let out = CkbReleaseCliOptions()
    if (args.size == 0 || (args[0] != "ckb-release-export" &&
        args[0] != "ckb-release-import")) {
        out.diagnostic = "release_command_required"; return out
    }
    out.mode = if (args[0] == "ckb-release-export") { "export" } else { "import" }
    let seen = HashSet<String>()
    var i: Int64 = 1
    while (i < args.size) {
        let arg = args[i]
        if (arg == "--json") {
            if (seen.contains(arg)) { out.diagnostic = "duplicate_argument:${arg}"; return out }
            seen.add(arg); out.json = true; i += 1; continue
        }
        if (!ckbReleaseCliAllowed(out.mode, arg)) {
            out.diagnostic = "unknown_argument:${arg}"; return out
        }
        if (seen.contains(arg)) { out.diagnostic = "duplicate_argument:${arg}"; return out }
        if (i + 1 >= args.size || args[i + 1].startsWith("--")) {
            out.diagnostic = "missing_argument_value:${arg}"; return out
        }
        seen.add(arg)
        let value = args[i + 1]
        if (arg == "--store-root") { out.storeRoot = value }
        else if (arg == "--logical-proof") { out.logicalProof = value }
        else if (arg == "--vector-proof") { out.vectorProof = value }
        else if (arg == "--output") { out.output = value }
        else if (arg == "--archive") { out.archive = value }
        else if (arg == "--target-root") { out.targetRoot = value }
        i += 2
    }
    out.diagnostic = validateCkbReleaseCliOptions(out); out
}

public func validateCkbReleaseCliOptions(out: CkbReleaseCliOptions): String {
    for (pair in if (out.mode == "export") {
        [("--store-root", out.storeRoot), ("--logical-proof", out.logicalProof),
         ("--vector-proof", out.vectorProof), ("--output", out.output)]
    } else { [("--archive", out.archive), ("--target-root", out.targetRoot)] }) {
        if (pair[1] == "") { return "required_argument_missing:${pair[0]}" }
    }
    "ok"
}

public func executeCkbReleaseCliAdapter(args: Array<String>,
    adapter: CkbReleaseCliAdapter): CkbReleaseCliExecution {
    let options = parseCkbReleaseCliOptions(args)
    if (options.diagnostic != "ok") {
        return ckbReleaseCliFailure(options.diagnostic, false, args.contains("--json"))
    }
    let result = try { adapter.execute(options) } catch (_: Exception) {
        return ckbReleaseCliFailure("release_adapter_execution_failed", true, options.json)
    }
    let out = CkbReleaseCliExecution()
    out.ok = result.ok; out.exitCode = if (result.ok) { 0 } else { 1 }
    out.diagnostic = result.diagnostic
    out.output = if (options.json) { renderCkbReleaseCliJson(result) }
        else { renderCkbReleaseCliHuman(result) }
    out
}

public func runCkbReleaseCli(args: Array<String>): CkbReleaseCliExecution {
    let options = parseCkbReleaseCliOptions(args)
    if (options.diagnostic != "ok") {
        return executeCkbReleaseCliAdapter(args,
            CkbReleaseProductionAdapter(CkbReleasePathPolicy()))
    }
    let policy = ckbDefaultReleasePathPolicy(options)
    executeCkbReleaseCliAdapter(args, CkbReleaseProductionAdapter(policy))
}

public func ckbDefaultReleasePathPolicy(
    options: CkbReleaseCliOptions): CkbReleasePathPolicy {
    let policy = CkbReleasePathPolicy()
    policy.worktreeRoot = ckbReleaseGitWorktreeRoot()
    let production = if (options.mode == "export") { options.storeRoot }
        else if (policy.worktreeRoot == "") { "" }
        else { Path(policy.worktreeRoot).join("target/ckb-data").toString() }
    policy.productionStoreRoot = ckbReleaseCanonicalPolicyPath(production)
    let home = match (getVariable("HOME")) {
        case Some(value) => value.trimAscii()
        case None => ""
    }
    if (home != "") {
        let canonicalHome = ckbReleaseCanonicalPolicyPath(home)
        if (canonicalHome != "") {
            policy.userConfigRoot =
                Path(canonicalHome).join(".metis/ckb").toString()
        }
    }
    policy
}

private func ckbReleaseGitWorktreeRoot(): String {
    var current = try { canonicalize(Path(".")) }
        catch (_: Exception) { return "" }
    while (true) {
        if (exists(current.join(".git"))) { return current.toString() }
        let parent = current.parent
        if (parent.toString() == current.toString()) { return "" }
        current = parent
    }
    ""
}

private func ckbReleaseCanonicalPolicyPath(value: String): String {
    if (value == "" || !value.startsWith("/")) { return "" }
    let path = Path(value)
    if (exists(path)) {
        return try { canonicalize(path).toString() } catch (_: Exception) { "" }
    }
    let parent = try { canonicalize(path.parent) } catch (_: Exception) { return "" }
    parent.join(path.fileName).toString()
}

// Production archive codec. It is deliberately binary and length-prefixed:
// snapshot payloads are never decoded as UTF-8, while entry paths are.
public class CkbPortableReleaseArchiveBackend <: CkbReleaseArchiveBackend {
    public var maxBufferBytes: Int64 = 0
    public var maxResidentBufferBytes: Int64 = 0
    public var maxReadBytes: Int64 = 0
    public func create(archivePath: String,
        values: ArrayList<CkbReleaseArchivePayload>): CkbReleaseArchiveOperation {
        let result = CkbReleaseArchiveOperation()
        try {
            if (values.size > 128) { throw Exception("archive_count") }
            var total: Int64 = 16; let seen = HashSet<String>()
            for (value in values) {
                let pathSize = value.path.toArray().size
                if (!ckbLogicalSnapshotRelativePathValid(value.path) ||
                    pathSize <= 0 || pathSize > 4096 || value.bytes.size > 67108864 ||
                    total > 536870912 - 16 - pathSize - value.bytes.size) {
                    throw Exception("archive_bounds")
                }
                if (seen.contains(value.path)) { throw Exception("archive_duplicate") }
                seen.add(value.path)
                total += 16 + pathSize + value.bytes.size
            }
            try (file = File(Path(archivePath), OpenMode.Write)) {
                file.write("CKBREL01".toArray())
                file.write(ckbReleaseArchiveIntBytes(values.size))
                for (value in values) {
                    let pathBytes = value.path.toArray()
                    file.write(ckbReleaseArchiveIntBytes(pathBytes.size))
                    file.write(ckbReleaseArchiveIntBytes(value.bytes.size))
                    file.write(pathBytes)
                    ckbReleaseArchiveWriteChunks(file, value.bytes, this)
                }
            }
            result.ok = true; result.diagnostic = "ok"
        } catch (_: Exception) { result.diagnostic = "archive_operation_failed" }
        result
    }

    public func enumerate(archivePath: String): CkbReleaseArchiveListing {
        let result = CkbReleaseArchiveListing()
        try {
            try (file = File(Path(archivePath), OpenMode.Read)) {
                let header = ckbReleaseArchiveReadHeader(file, this)
                var total: Int64 = 16
                for (_ in 0..header) {
                    let pathSize = ckbReleaseArchiveReadInt(file, this)
                    let bodySize = ckbReleaseArchiveReadInt(file, this)
                    ckbReleaseArchiveValidateLengths(pathSize, bodySize)
                    if (total > 536870912 - 16 - pathSize - bodySize) {
                        throw Exception("archive_total_size")
                    }
                    total += 16 + pathSize + bodySize
                    let path = ckbReleaseArchiveReadPath(file, pathSize, this)
                    ckbReleaseArchiveSkip(file, bodySize, this)
                    let entry = CkbReleaseArchiveEntry(); entry.path = path
                    entry.kind = CkbReleaseArchiveEntryKinds.REGULAR
                    entry.size = bodySize; result.entries.add(entry)
                }
                ckbReleaseArchiveRequireEof(file, this)
            }
            result.ok = true; result.diagnostic = "ok"
        } catch (e: Exception) {
            result.diagnostic = if (e.message == "invalid_response_encoding") {
                "invalid_response_encoding"
            } else { "archive_listing_failed" }
            result.entries.clear()
        }
        result
    }

    public func readRegular(archivePath: String,
        relativePath: String): CkbReleaseArchiveRead {
        let result = CkbReleaseArchiveRead()
        try {
            try (file = File(Path(archivePath), OpenMode.Read)) {
                let count = ckbReleaseArchiveReadHeader(file, this)
                var found: Bool = false; var total: Int64 = 16
                for (_ in 0..count) {
                    let pathSize = ckbReleaseArchiveReadInt(file, this)
                    let bodySize = ckbReleaseArchiveReadInt(file, this)
                    ckbReleaseArchiveValidateLengths(pathSize, bodySize)
                    if (total > 536870912 - 16 - pathSize - bodySize) {
                        throw Exception("archive_total_size")
                    }
                    total += 16 + pathSize + bodySize
                    let path = ckbReleaseArchiveReadPath(file, pathSize, this)
                    if (path == relativePath) {
                        if (found) { throw Exception("archive_duplicate") }
                        result.bytes = ckbReleaseArchiveReadBody(file, bodySize, this)
                        found = true
                    } else { ckbReleaseArchiveSkip(file, bodySize, this) }
                }
                ckbReleaseArchiveRequireEof(file, this)
                if (found) { result.ok = true; result.diagnostic = "ok"; return result }
            }
        } catch (e: Exception) {
            result.diagnostic = if (e.message == "invalid_response_encoding") {
                "invalid_response_encoding"
            } else { "archive_entry_read_failed" }
            return result
        }
        result.diagnostic = "archive_entry_missing"; result
    }

    public func supportsStreaming(): Bool { true }

    public func createFromFiles(archivePath: String,
        values: ArrayList<CkbReleaseArchivePayload>): CkbReleaseArchiveOperation {
        let result = CkbReleaseArchiveOperation()
        try {
            if (values.size > 128) { throw Exception("archive_count") }
            var total: Int64 = 16; let seen = HashSet<String>()
            for (value in values) {
                let pathSize = value.path.toArray().size
                let bodySize = if (value.sourcePath == "") { value.bytes.size } else { value.size }
                if (!ckbLogicalSnapshotRelativePathValid(value.path) ||
                    pathSize <= 0 || pathSize > 4096 || bodySize < 0 ||
                    bodySize > 67108864 || total > 536870912 - 16 - pathSize - bodySize) {
                    throw Exception("archive_bounds")
                }
                if (seen.contains(value.path)) { throw Exception("archive_duplicate") }
                seen.add(value.path)
                if (value.sourcePath != "" && !exists(Path(value.sourcePath))) {
                    throw Exception("archive_source_missing")
                }
                if (value.sourcePath != "" &&
                    !ckbLogicalSnapshotHashValid(value.sha256)) {
                    throw Exception("archive_source_hash")
                }
                total += 16 + pathSize + bodySize
            }
            try (file = File(Path(archivePath), OpenMode.Write)) {
                file.write("CKBREL01".toArray()); file.write(ckbReleaseArchiveIntBytes(values.size))
                for (value in values) {
                    let pathBytes = value.path.toArray()
                    let bodySize = if (value.sourcePath == "") { value.bytes.size } else { value.size }
                    file.write(ckbReleaseArchiveIntBytes(pathBytes.size))
                    file.write(ckbReleaseArchiveIntBytes(bodySize)); file.write(pathBytes)
                    if (value.sourcePath == "") {
                        ckbReleaseArchiveWriteChunks(file, value.bytes, this)
                    } else {
                        ckbReleaseArchiveCopyFileToArchive(value.sourcePath, file,
                            bodySize, value.sha256, this)
                    }
                }
            }
            result.ok = true; result.diagnostic = "ok"
        } catch (_: Exception) { result.diagnostic = "archive_operation_failed" }
        result
    }

    public func extractRegularToFile(archivePath: String, relativePath: String,
        outputPath: String, expectedSize: Int64,
        expectedSha256: String): CkbReleaseArchiveOperation {
        let result = CkbReleaseArchiveOperation()
        try {
            try (file = File(Path(archivePath), OpenMode.Read)) {
                let count = ckbReleaseArchiveReadHeader(file, this)
                var total: Int64 = 16; var found: Bool = false
                for (_ in 0..count) {
                    let pathSize = ckbReleaseArchiveReadInt(file, this)
                    let bodySize = ckbReleaseArchiveReadInt(file, this)
                    ckbReleaseArchiveValidateLengths(pathSize, bodySize)
                    if (total > 536870912 - 16 - pathSize - bodySize) {
                        throw Exception("archive_total_size")
                    }
                    total += 16 + pathSize + bodySize
                    let path = ckbReleaseArchiveReadPath(file, pathSize, this)
                    if (path == relativePath) {
                        if (found || bodySize != expectedSize) { throw Exception("archive_identity") }
                        ckbReleaseArchiveExtractBody(file, outputPath, bodySize,
                            expectedSha256, this); found = true
                    } else { ckbReleaseArchiveSkip(file, bodySize, this) }
                }
                ckbReleaseArchiveRequireEof(file, this)
                if (!found) { throw Exception("archive_entry_missing") }
            }
            result.ok = true; result.diagnostic = "ok"
        } catch (_: Exception) {
            if (exists(Path(outputPath))) { try { remove(Path(outputPath), recursive: true) } catch (_: Exception) { () } }
            result.diagnostic = "archive_entry_read_failed"
        }
        result
    }

    public func archiveHash(archivePath: String): String {
        try { ckbReleaseFileHash(archivePath, this) } catch (_: Exception) { "" }
    }

    public func extractAllRegularToDirectory(archivePath: String,
        outputRoot: String, manifest: CkbLogicalSnapshotManifest):
        CkbReleaseArchiveOperation {
        let result = CkbReleaseArchiveOperation()
        let expected = HashMap<String, CkbLogicalSnapshotAsset>()
        for (asset in manifest.assets) { expected[asset.relativePath] = asset }
        try {
            try (file = File(Path(archivePath), OpenMode.Read)) {
                let count = ckbReleaseArchiveReadHeader(file, this)
                if (count != manifest.assets.size + 1) {
                    throw Exception("archive_count")
                }
                let seen = HashSet<String>(); var total: Int64 = 16
                var extracted: Int64 = 0; var hasManifest: Bool = false
                for (_ in 0..count) {
                    let pathSize = ckbReleaseArchiveReadInt(file, this)
                    let bodySize = ckbReleaseArchiveReadInt(file, this)
                    ckbReleaseArchiveValidateLengths(pathSize, bodySize)
                    if (total > 536870912 - 16 - pathSize - bodySize) {
                        throw Exception("archive_total_size")
                    }
                    total += 16 + pathSize + bodySize
                    let relative = ckbReleaseArchiveReadPath(file, pathSize, this)
                    if (!ckbLogicalSnapshotRelativePathValid(relative) ||
                        seen.contains(relative)) {
                        throw Exception("archive_path")
                    }
                    seen.add(relative)
                    if (relative == "RELEASE-MANIFEST.json") {
                        hasManifest = true
                        ckbReleaseArchiveSkip(file, bodySize, this)
                        continue
                    }
                    if (!expected.contains(relative)) {
                        throw Exception("archive_unmanifested")
                    }
                    let asset = expected.get(relative).getOrThrow()
                    if (bodySize != asset.size) { throw Exception("archive_identity") }
                    let target = Path(outputRoot).join(relative)
                    if (!exists(target.parent)) {
                        Directory.create(target.parent, recursive: true)
                    }
                    ckbReleaseArchiveExtractBody(file, target.toString(), bodySize,
                        asset.sha256, this)
                    extracted += 1
                }
                ckbReleaseArchiveRequireEof(file, this)
                if (!hasManifest || extracted != manifest.assets.size) {
                    throw Exception("archive_missing")
                }
            }
            result.ok = true; result.diagnostic = "ok"
        } catch (_: Exception) {
            result.diagnostic = "archive_extract_failed"
        }
        result
    }
}

public class CkbReleaseProductionAdapter <: CkbReleaseCliAdapter {
    private let policy: CkbReleasePathPolicy
    private let backend: CkbReleaseArchiveBackend
    public init(policy: CkbReleasePathPolicy,
        backend!: CkbReleaseArchiveBackend = CkbPortableReleaseArchiveBackend()) {
        this.policy = policy; this.backend = backend
    }
    public func execute(options: CkbReleaseCliOptions): CkbReleaseCliOperationResult {
        let out = CkbReleaseCliOperationResult()
        let result = if (options.mode == "export") {
            let loaded = loadCkbLogicalSnapshotCliProofs(
                options.logicalProof, options.vectorProof)
            if (!loaded[0].ok) { out.diagnostic = loaded[0].diagnostic; return out }
            exportCkbLogicalSnapshot(FileKnowledgeStore(options.storeRoot), loaded[1],
                options.output, this.backend, pathPolicy: this.policy)
        } else {
            importCkbLogicalSnapshot(options.archive, options.targetRoot,
                this.backend, pathPolicy: this.policy)
        }
        out.ok = result.ok; out.diagnostic = result.diagnostic
        out.summary = "version=${result.activeVersion} raw=${result.rawCount} " +
            "normalized=${result.normalizedCount} vector=${result.vectorCount}"
        out
    }
}

public func newCkbReleaseProductionAdapter(policy: CkbReleasePathPolicy,
    backend!: CkbReleaseArchiveBackend = CkbPortableReleaseArchiveBackend()):
    CkbReleaseCliAdapter { CkbReleaseProductionAdapter(policy, backend: backend) }

public func loadCkbLogicalSnapshotCliProofs(logicalPath: String,
    vectorPath: String): (CkbReproContractResult, CkbLogicalSnapshotExportProofs) {
    let logicalRead = ckbReleaseReadBoundedUtf8(logicalPath)
    if (logicalRead[0] != "ok") {
        return (ckbReleaseCliContractFailure(logicalRead[0]),
            CkbLogicalSnapshotExportProofs())
    }
    let vectorRead = ckbReleaseReadBoundedUtf8(vectorPath)
    if (vectorRead[0] != "ok") {
        return (ckbReleaseCliContractFailure(vectorRead[0]),
            CkbLogicalSnapshotExportProofs())
    }
    parseCkbLogicalSnapshotCliProofBytes(
        logicalRead[1].toArray(), vectorRead[1].toArray())
}

public func parseCkbLogicalSnapshotCliProofBytes(logicalBytes: Array<UInt8>,
    vectorBytes: Array<UInt8>):
    (CkbReproContractResult, CkbLogicalSnapshotExportProofs) {
    let proofs = CkbLogicalSnapshotExportProofs()
    let logicalText = try { String.fromUtf8(logicalBytes) }
        catch (_: Exception) {
            return (ckbReleaseCliContractFailure("invalid_response_encoding"), proofs)
        }
    let vectorText = try { String.fromUtf8(vectorBytes) }
        catch (_: Exception) {
            return (ckbReleaseCliContractFailure("invalid_response_encoding"), proofs)
        }
    try {
        let logical = JsonValue.fromStr(logicalText).asObject()
        let vector = JsonValue.fromStr(vectorText).asObject()
        if (logical.size() != 7 || vector.size() != 13) {
            return (ckbReleaseCliContractFailure(
                "release_proof_field_contract_invalid"), proofs)
        }
        proofs.sourceState = ckbReleaseRequiredString(logical, "sourceState")
        proofs.portableKnowledgeVersion =
            ckbReleaseRequiredString(logical, "portableKnowledgeVersion")
        proofs.p4PortableProofHash =
            ckbReleaseRequiredString(logical, "p4PortableProofHash")
        proofs.pathMachineFindingCount =
            ckbReleaseRequiredInt(logical, "pathMachineFindingCount")
        proofs.pathUnmappedFindingCount =
            ckbReleaseRequiredInt(logical, "pathUnmappedFindingCount")
        proofs.contaminationProofHash =
            ckbReleaseRequiredString(logical, "contaminationProofHash")
        proofs.expectedStartPointerHash =
            ckbReleaseRequiredString(logical, "activePointerHash")
        proofs.expectedEndPointerHash = proofs.expectedStartPointerHash
        proofs.p3VectorProofHash =
            ckbReleaseRequiredString(vector, "vectorProofHash")
        proofs.p3ProofReal = ckbReleaseRequiredBool(vector, "proofReal")
        let vectorState = ckbReleaseRequiredString(vector, "vectorState")
        if (vectorState != "READY") {
            return (ckbReleaseCliContractFailure(
                "release_proof_cross_binding_mismatch"), proofs)
        }
        proofs.vectorState = EmbeddingProviderState.READY
        proofs.vectorCollection = ckbReleaseRequiredString(vector, "collection")
        proofs.vectorCount = ckbReleaseRequiredInt(vector, "count")
        proofs.vectorDimension = ckbReleaseRequiredInt(vector, "dimension")
        let typedVector = CkbPortableVectorProof()
        typedVector.collection = proofs.vectorCollection
        typedVector.candidateVersion =
            ckbReleaseRequiredString(vector, "candidateVersion")
        typedVector.p4PortableProofHash =
            ckbReleaseRequiredString(vector, "p4PortableProofHash")
        typedVector.qdrantImageDigest =
            ckbReleaseRequiredString(vector, "qdrantImageDigest")
        typedVector.embeddingProvider =
            ckbReleaseRequiredString(vector, "embeddingProvider")
        typedVector.embeddingModel =
            ckbReleaseRequiredString(vector, "embeddingModel")
        typedVector.count = proofs.vectorCount
        typedVector.dimension = proofs.vectorDimension
        typedVector.distance = ckbReleaseRequiredString(vector, "distance")
        typedVector.payloadCanonicalHash =
            ckbReleaseRequiredString(vector, "payloadCanonicalHash")
        typedVector.vectorProofHash = proofs.p3VectorProofHash
        if (typedVector.candidateVersion != proofs.portableKnowledgeVersion ||
            typedVector.p4PortableProofHash != proofs.p4PortableProofHash ||
            typedVector.vectorProofHash != ckbPortableVectorProofHash(typedVector) ||
            typedVector.distance.toAsciiLower() != "cosine" ||
            !ckbLogicalSnapshotHashValid(typedVector.qdrantImageDigest) ||
            !ckbLogicalSnapshotHashValid(typedVector.payloadCanonicalHash)) {
            return (ckbReleaseCliContractFailure(
                "release_proof_cross_binding_mismatch"), proofs)
        }
    } catch (_: Exception) {
        return (ckbReleaseCliContractFailure("release_proof_malformed_json"), proofs)
    }
    let diagnostic = ckbLogicalSnapshotProofDiagnosticForCli(proofs)
    if (diagnostic != "ok") { return (ckbReleaseCliContractFailure(diagnostic), proofs) }
    let contract = CkbReproContractResult(); contract.ok = true; contract.diagnostic = "ok"
    (contract, proofs)
}

private func ckbReleaseReadBoundedUtf8(path: String): (String, String) {
    let bytes = ArrayList<UInt8>()
    try {
        try (file = File(Path(path), OpenMode.Read)) {
            while (true) {
                let buffer = Array<UInt8>(16000, repeat: UInt8(0))
                let count = file.read(buffer)
                if (count < 0 || count > buffer.size) {
                    return ("release_proof_read_failed", "")
                }
                if (count == 0) { break }
                if (bytes.size > 48000 - count) {
                    return ("release_proof_size_invalid", "")
                }
                for (i in 0..count) { bytes.add(buffer[i]) }
            }
        }
    } catch (_: Exception) { return ("release_proof_read_failed", "") }
    try { ("ok", String.fromUtf8(bytes.toArray())) }
    catch (_: Exception) { ("invalid_response_encoding", "") }
}

public func runCkbReleaseCli(args: Array<String>,
    context: CkbReleaseCliAdapter): CkbReleaseCliExecution {
    executeCkbReleaseCliAdapter(args, context)
}

public func renderCkbReleaseCliHuman(result: CkbReleaseCliOperationResult): String {
    if (result.ok) { "CKB release operation completed. ${ckbReleaseCliSafe(result.summary)}\n" }
    else { "CKB release operation failed: ${ckbReleaseCliSafe(result.diagnostic)}\n" }
}

public func renderCkbReleaseCliJson(result: CkbReleaseCliOperationResult): String {
    "{\"ok\":${result.ok},\"diagnostic\":\"${ckbReleaseCliJson(result.diagnostic)}\"," +
        "\"summary\":\"${ckbReleaseCliJson(result.summary)}\"}"
}

private func ckbReleaseCliAllowed(mode: String, arg: String): Bool {
    if (mode == "export") { return ["--store-root", "--logical-proof",
        "--vector-proof", "--output"].contains(arg) }
    ["--archive", "--target-root"].contains(arg)
}

private func ckbReleaseCliFailure(diagnostic: String, runtime: Bool, json: Bool): CkbReleaseCliExecution {
    let result = CkbReleaseCliOperationResult(); result.diagnostic = diagnostic
    let out = CkbReleaseCliExecution(); out.exitCode = if (runtime) { 1 } else { 2 }
    out.diagnostic = diagnostic; out.output = if (json) { renderCkbReleaseCliJson(result) }
        else { renderCkbReleaseCliHuman(result) }; out
}

private func ckbReleaseCliSafe(value: String): String {
    let runes = redactSensitive(value).toRuneArray()
    let limit: Int64 = if (runes.size < 160) { runes.size } else { 160 }
    let out = StringBuilder(); for (i in 0..limit) { out.append(runes[i]) }; out.toString()
}

private func ckbReleaseCliJson(value: String): String {
    ckbReleaseCliJsonEscape(ckbReleaseCliSafe(value))
}

private func ckbReleaseCliJsonEscape(value: String): String {
    let out = StringBuilder(); let hex = "0123456789abcdef".toRuneArray()
    for (rune in value.runes()) {
        if (rune == r'"') { out.append("\\\"") }
        else if (rune == r'\\') { out.append("\\\\") }
        else if (rune == r'\n') { out.append("\\n") }
        else if (rune == r'\r') { out.append("\\r") }
        else if (rune == r'\t') { out.append("\\t") }
        else if (UInt32(rune) < 0x20u32) {
            let code = UInt32(rune); out.append("\\u00")
            out.append(hex[Int64(code / 16u32)]); out.append(hex[Int64(code % 16u32)])
        } else { out.append(rune) }
    }
    out.toString()
}

private func ckbReleaseArchiveIntBytes(value: Int64): Array<UInt8> {
    let out = ArrayList<UInt8>()
    for (shift in [56, 48, 40, 32, 24, 16, 8, 0]) {
        var divisor: Int64 = 1
        for (_ in 0..(shift / 8)) { divisor *= 256 }
        out.add(UInt8((value / divisor) % 256))
    }
    out.toArray()
}

private func ckbReleaseArchiveTrackBuffer(backend: CkbPortableReleaseArchiveBackend,
    size: Int64): Unit {
    if (size > backend.maxBufferBytes) { backend.maxBufferBytes = size }
    if (size > backend.maxResidentBufferBytes) {
        backend.maxResidentBufferBytes = size
    }
}

private func ckbReleaseArchiveTrackRead(backend: CkbPortableReleaseArchiveBackend,
    size: Int64): Unit {
    if (size > backend.maxReadBytes) { backend.maxReadBytes = size }
}

private func ckbReleaseArchiveReadExact(file: File, size: Int64,
    backend: CkbPortableReleaseArchiveBackend): Array<UInt8> {
    if (size < 0 || size > 65536) { throw Exception("archive_bounds") }
    let out = Array<UInt8>(size, repeat: UInt8(0)); var offset: Int64 = 0
    ckbReleaseArchiveTrackBuffer(backend, size)
    while (offset < size) {
        let chunk = Array<UInt8>(size - offset, repeat: UInt8(0))
        ckbReleaseArchiveTrackBuffer(backend, out.size + chunk.size)
        let count = file.read(chunk)
        ckbReleaseArchiveTrackRead(backend, count)
        if (count <= 0 || count > chunk.size) { throw Exception("archive_truncated") }
        for (i in 0..count) { out[offset + i] = chunk[i] }
        offset += count
    }
    out
}

private func ckbReleaseArchiveReadInt(file: File,
    backend: CkbPortableReleaseArchiveBackend): Int64 {
    let bytes = ckbReleaseArchiveReadExact(file, 8, backend); var value: Int64 = 0
    for (byte in bytes) {
        if (value > 36028797018963967) { throw Exception("archive_overflow") }
        value = value * 256 + Int64(byte)
    }
    value
}

private func ckbReleaseArchiveReadHeader(file: File,
    backend: CkbPortableReleaseArchiveBackend): Int64 {
    if (ckbReleaseArchiveReadExact(file, 8, backend) != "CKBREL01".toArray()) {
        throw Exception("archive_magic")
    }
    let count = ckbReleaseArchiveReadInt(file, backend)
    if (count < 0 || count > 128) { throw Exception("archive_count") }
    count
}

private func ckbReleaseArchiveValidateLengths(pathSize: Int64, bodySize: Int64): Unit {
    if (pathSize <= 0 || pathSize > 4096 || bodySize < 0 || bodySize > 67108864) {
        throw Exception("archive_bounds")
    }
}

private func ckbReleaseArchiveReadPath(file: File, size: Int64,
    backend: CkbPortableReleaseArchiveBackend): String {
    try { String.fromUtf8(ckbReleaseArchiveReadExact(file, size, backend)) }
    catch (_: Exception) { throw Exception("invalid_response_encoding") }
}

private func ckbReleaseArchiveSkip(file: File, size: Int64,
    backend: CkbPortableReleaseArchiveBackend): Unit {
    var remaining = size
    while (remaining > 0) {
        let wanted = if (remaining < 65536) { remaining } else { 65536 }
        let chunk = Array<UInt8>(wanted, repeat: UInt8(0))
        ckbReleaseArchiveTrackBuffer(backend, chunk.size)
        let count = file.read(chunk)
        ckbReleaseArchiveTrackRead(backend, count)
        if (count <= 0 || count > wanted) { throw Exception("archive_truncated") }
        remaining -= count
    }
}

private func ckbReleaseArchiveReadBody(file: File, size: Int64,
    backend: CkbPortableReleaseArchiveBackend): Array<UInt8> {
    let out = ArrayList<UInt8>(); let buffer = Array<UInt8>(16000, repeat: UInt8(0))
    ckbReleaseArchiveTrackBuffer(backend, buffer.size); var remaining = size
    while (remaining > 0) {
        let wanted = if (remaining < buffer.size) { remaining } else { buffer.size }
        let chunk = if (wanted == buffer.size) { buffer }
            else { Array<UInt8>(wanted, repeat: UInt8(0)) }
        ckbReleaseArchiveTrackBuffer(backend, chunk.size)
        let count = file.read(chunk)
        ckbReleaseArchiveTrackRead(backend, count)
        if (count <= 0 || count > wanted) { throw Exception("archive_truncated") }
        for (i in 0..count) { out.add(chunk[i]) }; remaining -= count
    }
    out.toArray()
}

private func ckbReleaseArchiveRequireEof(file: File,
    backend: CkbPortableReleaseArchiveBackend): Unit {
    let one = Array<UInt8>(1, repeat: UInt8(0)); ckbReleaseArchiveTrackBuffer(backend, 1)
    let count = file.read(one); ckbReleaseArchiveTrackRead(backend, count)
    if (count != 0) { throw Exception("archive_trailing_bytes") }
}

private func ckbReleaseArchiveWriteChunks(file: File, bytes: Array<UInt8>,
    backend: CkbPortableReleaseArchiveBackend): Unit {
    var offset: Int64 = 0
    while (offset < bytes.size) {
        let count = if (bytes.size - offset < 65536) { bytes.size - offset } else { 65536 }
        let chunk = Array<UInt8>(count, repeat: UInt8(0))
        for (i in 0..count) { chunk[i] = bytes[offset + i] }
        ckbReleaseArchiveTrackBuffer(backend, chunk.size); file.write(chunk); offset += count
    }
}

private func ckbReleaseArchiveCopyFileToArchive(sourcePath: String,
    output: File, expectedSize: Int64, expectedHash: String,
    backend: CkbPortableReleaseArchiveBackend): Unit {
    let digest = SHA256(); var total: Int64 = 0
    try (source = File(Path(sourcePath), OpenMode.Read)) {
        let buffer = Array<UInt8>(32000, repeat: UInt8(0))
        ckbReleaseArchiveTrackBuffer(backend, buffer.size)
        while (true) {
            let count = source.read(buffer)
            ckbReleaseArchiveTrackRead(backend, count)
            if (count < 0 || count > buffer.size) { throw Exception("archive_source_read") }
            if (count == 0) { break }
            let chunk = if (count == buffer.size) { buffer }
                else { buffer[0..count].clone() }
            ckbReleaseArchiveTrackBuffer(backend,
                if (count == buffer.size) { buffer.size } else { buffer.size + count })
            output.write(chunk); digest.write(chunk); total += count
            if (total > expectedSize) { throw Exception("archive_source_size") }
        }
    }
    if (total != expectedSize || ckbReleaseDigestHash(digest) != expectedHash) {
        throw Exception("archive_source_hash")
    }
}

private func ckbReleaseArchiveExtractBody(input: File, outputPath: String,
    size: Int64, expectedHash: String,
    backend: CkbPortableReleaseArchiveBackend): Unit {
    let digest = SHA256(); var remaining = size
    try (output = File(Path(outputPath), OpenMode.Write)) {
        while (remaining > 0) {
            let wanted = if (remaining < 32768) { remaining } else { 32768 }
            let chunk = Array<UInt8>(wanted, repeat: UInt8(0))
            ckbReleaseArchiveTrackBuffer(backend, chunk.size)
            let count = input.read(chunk)
            ckbReleaseArchiveTrackRead(backend, count)
            if (count <= 0 || count > wanted) { throw Exception("archive_truncated") }
            let written = if (count == chunk.size) { chunk } else { chunk[0..count].clone() }
            ckbReleaseArchiveTrackBuffer(backend, chunk.size +
                if (count == chunk.size) { 0 } else { count })
            output.write(written); digest.write(written); remaining -= count
        }
    }
    if (ckbReleaseDigestHash(digest) != expectedHash) {
        throw Exception("archive_asset_hash")
    }
}

private func ckbReleaseFileHash(path: String,
    backend: CkbPortableReleaseArchiveBackend): String {
    let digest = SHA256()
    try (file = File(Path(path), OpenMode.Read)) {
        let buffer = Array<UInt8>(32000, repeat: UInt8(0))
        ckbReleaseArchiveTrackBuffer(backend, buffer.size)
        while (true) {
            let count = file.read(buffer)
            ckbReleaseArchiveTrackRead(backend, count)
            if (count < 0 || count > buffer.size) { throw Exception("archive_hash_read") }
            if (count == 0) { break }
            let chunk = if (count == buffer.size) { buffer } else { buffer[0..count].clone() }
            ckbReleaseArchiveTrackBuffer(backend,
                if (count == buffer.size) { buffer.size } else { buffer.size + count })
            digest.write(chunk)
        }
    }
    ckbReleaseDigestHash(digest)
}

private func ckbReleaseDigestHash(digest: SHA256): String {
    let out = StringBuilder()
    for (byte in digest.finish()) {
        out.append(ckbLogicalSnapshotNibble(byte / UInt8(16)))
        out.append(ckbLogicalSnapshotNibble(byte % UInt8(16)))
    }
    "sha256:${out.toString()}"
}

private func ckbReleaseRequiredString(object: JsonObject, key: String): String {
    object.get(key).getOrThrow().asString().getValue()
}
private func ckbReleaseRequiredInt(object: JsonObject, key: String): Int64 {
    object.get(key).getOrThrow().asInt().getValue()
}
private func ckbReleaseRequiredBool(object: JsonObject, key: String): Bool {
    object.get(key).getOrThrow().asBool().getValue()
}
private func ckbLogicalSnapshotProofDiagnosticForCli(
    proofs: CkbLogicalSnapshotExportProofs): String {
    if (proofs.sourceState != CkbLogicalSnapshotSourceStates.PORTABLE_VECTOR_CANDIDATE &&
        proofs.sourceState != CkbLogicalSnapshotSourceStates.PROMOTED_PORTABLE_PRODUCTION) {
        return "logical_snapshot_source_state_invalid"
    }
    if (proofs.portableKnowledgeVersion == "" || !proofs.p3ProofReal ||
        proofs.vectorState != EmbeddingProviderState.READY || proofs.vectorCount <= 0 ||
        proofs.vectorDimension != 1024 || proofs.pathMachineFindingCount != 0 ||
        proofs.pathUnmappedFindingCount != 0) {
        return "logical_snapshot_proof_invalid"
    }
    for (hash in [proofs.p4PortableProofHash, proofs.p3VectorProofHash,
        proofs.contaminationProofHash, proofs.expectedStartPointerHash]) {
        if (!hash.startsWith("sha256:") || hash.toRuneArray().size != 71) {
            return "logical_snapshot_proof_invalid"
        }
    }
    "ok"
}

private func ckbReleaseCliContractFailure(diagnostic: String): CkbReproContractResult {
    let result = CkbReproContractResult(); result.diagnostic = diagnostic; result
}

// Release-level binding is created only after both the logical manifest and
// Qdrant snapshot manifest are final. It prevents either artifact from being
// substituted independently.
public class CkbReleaseManifest {
    public var schemaVersion: String = "ckb-release-manifest-v1"
    public var portableKnowledgeVersion: String = ""
    public var logicalManifestHash: String = ""
    public var qdrantSnapshotManifestHash: String = ""
    public var qdrantSnapshotHash: String = ""
    public var vectorProofHash: String = ""
    public var collection: String = ""
    public var points: Int64 = 0
    public var dimension: Int64 = 0
    public var distance: String = ""
    public var bindingHash: String = ""
    public init() {}
}

public class CkbReleaseManifestContract {
    public var ok: Bool = false
    public var ready: Bool = false
    public var diagnostic: String = "release_manifest_not_validated"
    public var canonicalJson: String = ""
    public var manifest: CkbReleaseManifest = CkbReleaseManifest()
    public init() {}
}

public func buildCkbReleaseManifest(logical: CkbLogicalSnapshotManifest,
    vector: CkbQdrantSnapshotManifest): CkbReleaseManifestContract {
    let result = CkbReleaseManifestContract()
    let logicalValidation = validateCkbLogicalSnapshotManifest(logical)
    if (!logicalValidation.ok) {
        result.diagnostic = logicalValidation.diagnostic
        return result
    }
    let vectorValidation = validateCkbQdrantSnapshotManifest(vector)
    if (!vectorValidation.ok) {
        result.diagnostic = vectorValidation.diagnostic
        return result
    }
    let binding = CkbReleaseManifest()
    binding.portableKnowledgeVersion = logical.portableKnowledgeVersion
    binding.logicalManifestHash = logical.manifestHash
    binding.qdrantSnapshotManifestHash = vector.manifestHash
    binding.qdrantSnapshotHash = vector.snapshotSha256
    binding.vectorProofHash = vector.vectorProofHash
    binding.collection = vector.collection
    binding.points = vector.points
    binding.dimension = vector.dimension
    binding.distance = vector.distance
    let identity = ckbReleaseManifestIdentityDiagnostic(
        binding, logical, vector)
    if (identity != "ok") { result.diagnostic = identity; return result }
    binding.bindingHash = ckbLogicalSnapshotBytesHash(
        ckbReleaseManifestBody(binding).toArray())
    result.ok = true
    result.ready = true
    result.diagnostic = "ok"
    result.manifest = binding
    result.canonicalJson = renderCkbReleaseManifest(binding)
    result
}

public func validateCkbReleaseManifest(binding: CkbReleaseManifest,
    logical: CkbLogicalSnapshotManifest,
    vector: CkbQdrantSnapshotManifest): CkbReleaseManifestContract {
    let result = CkbReleaseManifestContract()
    let logicalValidation = validateCkbLogicalSnapshotManifest(logical)
    if (!logicalValidation.ok) {
        result.diagnostic = logicalValidation.diagnostic
        return result
    }
    let vectorValidation = validateCkbQdrantSnapshotManifest(vector)
    if (!vectorValidation.ok) {
        result.diagnostic = vectorValidation.diagnostic
        return result
    }
    let identity = ckbReleaseManifestIdentityDiagnostic(
        binding, logical, vector)
    if (identity != "ok") { result.diagnostic = identity; return result }
    let expected = ckbLogicalSnapshotBytesHash(
        ckbReleaseManifestBody(binding).toArray())
    if (binding.bindingHash != expected) {
        result.diagnostic = "release_manifest_binding_hash_mismatch"
        return result
    }
    result.ok = true
    result.ready = true
    result.diagnostic = "ok"
    result.manifest = binding
    result.canonicalJson = renderCkbReleaseManifest(binding)
    result
}

public func renderCkbReleaseManifest(binding: CkbReleaseManifest): String {
    ckbReleaseManifestBody(binding) +
        ",\"bindingHash\":\"${binding.bindingHash}\"}"
}

public func parseCkbLogicalSnapshotManifest(bytes: Array<UInt8>):
    (CkbLogicalSnapshotContract, CkbLogicalSnapshotManifest) {
    let manifest = CkbLogicalSnapshotManifest()
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (ckbLogicalSnapshotFailure("invalid_response_encoding"), manifest)
    }
    try {
        let object = JsonValue.fromStr(text).asObject()
        if (object.size() != 19) {
            return (ckbLogicalSnapshotFailure(
                "logical_snapshot_field_contract_invalid"), manifest)
        }
        manifest.schemaVersion = ckbLogicalSnapshotString(object, "schemaVersion")
        manifest.sourceState = ckbLogicalSnapshotString(object, "sourceState")
        manifest.portableKnowledgeVersion = ckbLogicalSnapshotString(
            object, "portableKnowledgeVersion")
        manifest.p4PortableProofHash = ckbLogicalSnapshotString(
            object, "p4PortableProofHash")
        manifest.p3VectorProofHash = ckbLogicalSnapshotString(
            object, "p3VectorProofHash")
        manifest.vectorState = ckbLogicalSnapshotString(object, "vectorState")
        manifest.vectorCollection = ckbLogicalSnapshotString(
            object, "vectorCollection")
        manifest.vectorCount = ckbLogicalSnapshotInt(object, "vectorCount")
        manifest.vectorDimension = ckbLogicalSnapshotInt(
            object, "vectorDimension")
        manifest.rawCount = ckbLogicalSnapshotInt(object, "rawCount")
        manifest.normalizedCount = ckbLogicalSnapshotInt(
            object, "normalizedCount")
        manifest.normalizedChecksum = ckbLogicalSnapshotString(
            object, "normalizedChecksum")
        manifest.indexCount = ckbLogicalSnapshotInt(object, "indexCount")
        manifest.graphNodeCount = ckbLogicalSnapshotInt(
            object, "graphNodeCount")
        manifest.graphEdgeCount = ckbLogicalSnapshotInt(
            object, "graphEdgeCount")
        manifest.activePointerHash = ckbLogicalSnapshotString(
            object, "activePointerHash")
        manifest.contaminationProofHash = ckbLogicalSnapshotString(
            object, "contaminationProofHash")
        for (value in object.get("assets").getOrThrow().asArray().getItems()) {
            let row = value.asObject()
            if (row.size() != 4) {
                return (ckbLogicalSnapshotFailure(
                    "logical_snapshot_asset_contract_invalid"),
                    CkbLogicalSnapshotManifest())
            }
            let asset = CkbLogicalSnapshotAsset()
            asset.relativePath = ckbLogicalSnapshotString(row, "relativePath")
            asset.size = ckbLogicalSnapshotInt(row, "size")
            asset.sha256 = ckbLogicalSnapshotString(row, "sha256")
            asset.entryType = ckbLogicalSnapshotString(row, "entryType")
            manifest.assets.add(asset)
        }
        manifest.manifestHash = ckbLogicalSnapshotString(object, "manifestHash")
    } catch (_: Exception) {
        return (ckbLogicalSnapshotFailure(
            "logical_snapshot_field_contract_invalid"),
            CkbLogicalSnapshotManifest())
    }
    let result = CkbLogicalSnapshotContract()
    result.ok = true
    result.diagnostic = "ok"
    (result, manifest)
}

public func buildCkbLogicalSnapshotManifest(
    manifest: CkbLogicalSnapshotManifest): CkbLogicalSnapshotContract {
    let structural = ckbLogicalSnapshotValidateStructure(manifest)
    if (!structural.ok) { return structural }
    let hash = ckbLogicalSnapshotBytesHash(
        ckbLogicalSnapshotManifestBody(manifest).toArray())
    manifest.manifestHash = hash
    let result = CkbLogicalSnapshotContract()
    result.ok = true
    result.diagnostic = "ok"
    result.manifestHash = hash
    result.canonicalJson = renderCkbLogicalSnapshotManifest(manifest)
    result
}

public func validateCkbLogicalSnapshotManifest(
    manifest: CkbLogicalSnapshotManifest): CkbLogicalSnapshotContract {
    let structural = ckbLogicalSnapshotValidateStructure(manifest)
    if (!structural.ok) { return structural }
    let expected = ckbLogicalSnapshotBytesHash(
        ckbLogicalSnapshotManifestBody(manifest).toArray())
    if (manifest.manifestHash != expected) {
        return ckbLogicalSnapshotFailure("logical_snapshot_manifest_hash_mismatch")
    }
    let result = CkbLogicalSnapshotContract()
    result.ok = true
    result.diagnostic = "ok"
    result.manifestHash = expected
    result.canonicalJson = renderCkbLogicalSnapshotManifest(manifest)
    result
}

public func renderCkbLogicalSnapshotManifest(
    manifest: CkbLogicalSnapshotManifest): String {
    ckbLogicalSnapshotManifestBody(manifest) +
        ",\"manifestHash\":\"${ckbLogicalSnapshotJson(manifest.manifestHash)}\"}"
}

public func inspectCkbReleaseArchive(backend: CkbReleaseArchiveBackend,
    archivePath: String,
    limits!: CkbReleaseArchiveLimits = CkbReleaseArchiveLimits()):
    CkbReleaseArchiveInspection {
    let result = CkbReleaseArchiveInspection()
    let listing = backend.enumerate(archivePath)
    if (!listing.ok) {
        result.diagnostic = if (listing.diagnostic == "") {
            "logical_snapshot_archive_listing_failed"
        } else { listing.diagnostic }
        return result
    }
    if (listing.entries.size == 0 || listing.entries.size > limits.maxEntries) {
        result.diagnostic = "logical_snapshot_archive_entry_limit"
        return result
    }
    let seen = HashSet<String>()
    var total: Int64 = 0
    var hasManifest = false
    for (entry in listing.entries) {
        if (!ckbLogicalSnapshotRelativePathValid(entry.path)) {
            result.diagnostic = "logical_snapshot_archive_path_invalid"
            return result
        }
        if (entry.kind != CkbReleaseArchiveEntryKinds.REGULAR ||
            entry.linkTarget != "") {
            result.diagnostic = "logical_snapshot_archive_entry_type_forbidden"
            return result
        }
        if (seen.contains(entry.path)) {
            result.diagnostic = "logical_snapshot_archive_entry_duplicate"
            return result
        }
        if (entry.size < 0 || entry.size > limits.maxEntryBytes) {
            result.diagnostic = "logical_snapshot_archive_entry_size_invalid"
            return result
        }
        seen.add(entry.path)
        if (total > limits.maxTotalBytes - entry.size) {
            result.diagnostic = "logical_snapshot_archive_total_size_invalid"
            return result
        }
        total += entry.size
        if (entry.path == "RELEASE-MANIFEST.json") { hasManifest = true }
    }
    if (!hasManifest) {
        result.diagnostic = "logical_snapshot_manifest_missing"
        return result
    }
    let manifestRead = backend.readRegular(archivePath, "RELEASE-MANIFEST.json")
    if (!manifestRead.ok) {
        result.diagnostic = "logical_snapshot_manifest_read_failed"
        return result
    }
    let parsed = parseCkbLogicalSnapshotManifest(manifestRead.bytes)
    if (!parsed[0].ok) {
        result.diagnostic = parsed[0].diagnostic
        return result
    }
    let validated = validateCkbLogicalSnapshotManifest(parsed[1])
    if (!validated.ok) {
        result.diagnostic = validated.diagnostic
        return result
    }
    let declared = HashSet<String>()
    for (asset in parsed[1].assets) {
        declared.add(asset.relativePath)
        var matched = false
        for (entry in listing.entries) {
            if (entry.path == asset.relativePath) {
                matched = entry.size == asset.size
                break
            }
        }
        if (!matched) {
            result.diagnostic = "logical_snapshot_archive_asset_declaration_mismatch"
            return result
        }
    }
    for (entry in listing.entries) {
        if (entry.path != "RELEASE-MANIFEST.json" &&
            !declared.contains(entry.path)) {
            result.diagnostic = "logical_snapshot_archive_entry_unmanifested"
            return result
        }
    }
    if (listing.entries.size != parsed[1].assets.size + 1) {
        result.diagnostic = "logical_snapshot_archive_asset_count_mismatch"
        return result
    }
    result.ok = true
    result.diagnostic = "ok"
    result.manifest = parsed[1]
    for (entry in listing.entries) { result.entries.add(entry) }
    result
}

public func exportCkbLogicalSnapshot(store: FileKnowledgeStore,
    proofs: CkbLogicalSnapshotExportProofs, outputPath: String,
    backend: CkbReleaseArchiveBackend,
    pathPolicy!: CkbReleasePathPolicy = CkbReleasePathPolicy(),
    allowSyntheticProof!: Bool = false):
    CkbLogicalSnapshotResult {
    let result = CkbLogicalSnapshotResult()
    let pathDiagnostic = ckbLogicalSnapshotNewPathDiagnostic(
        outputPath, pathPolicy, store.rootPath(), "output")
    if (pathDiagnostic != "ok") {
        result.diagnostic = pathDiagnostic
        return result
    }
    let start = store.loadActiveSnapshotPointer()
    if (!start.valid || start.legacy) {
        result.diagnostic = if (start.diagnostic == "") {
            "logical_snapshot_active_pointer_invalid"
        } else { start.diagnostic }
        return result
    }
    let startHash = ckbActiveSnapshotPointerIdentityHash(start)
    if (proofs.expectedStartPointerHash != "" &&
        proofs.expectedStartPointerHash != startHash) {
        result.diagnostic = "logical_snapshot_pointer_drift"
        return result
    }
    let proofDiagnostic = ckbLogicalSnapshotProofDiagnostic(proofs, start)
    if (proofDiagnostic != "ok") {
        result.diagnostic = proofDiagnostic
        return result
    }
    if (!proofs.p3ProofReal && !allowSyntheticProof) {
        result.diagnostic = "logical_snapshot_real_p3_proof_required"
        return result
    }
    let snapshot = store.loadActiveSnapshot()
    let metadata = store.loadMetadataStatus()
    if (!snapshot.valid || !metadata.valid) {
        result.diagnostic = if (!snapshot.valid) {
            snapshot.diagnostic
        } else { metadata.diagnostic }
        return result
    }
    if (snapshot.activeIndex.size == 0) {
        result.diagnostic = "logical_snapshot_empty_store"
        return result
    }
    if (snapshot.activeVersion != proofs.portableKnowledgeVersion ||
        metadata.activeVersion != proofs.portableKnowledgeVersion ||
        snapshot.vectorActiveCollection != proofs.vectorCollection ||
        metadata.vectorActiveCollection != proofs.vectorCollection ||
        metadata.vectorState != EmbeddingProviderState.READY ||
        metadata.vectorIndexCount != proofs.vectorCount ||
        metadata.vectorDimension != proofs.vectorDimension) {
        result.diagnostic = "logical_snapshot_vector_binding_mismatch"
        return result
    }
    let materialized = KnowledgeBase(FakeClock(0))
    if (!materialized.restoreActiveSnapshot(snapshot)) {
        result.diagnostic = materialized.status().restoreDiagnostic
        return result
    }
    let graph = materialized.activeGraphBuild()
    if (!graph.ok) {
        result.diagnostic = graph.diagnostic
        return result
    }
    let payloads = ckbLogicalSnapshotStorePayloads(store, start)
    if (!payloads[0].ok) {
        result.diagnostic = payloads[0].diagnostic
        return result
    }
    let manifest = CkbLogicalSnapshotManifest()
    manifest.schemaVersion = "ckb-logical-snapshot-v1"
    manifest.sourceState = CkbLogicalSnapshotSourceStates.PORTABLE_VECTOR_ARTIFACT
    manifest.portableKnowledgeVersion = snapshot.activeVersion
    manifest.p4PortableProofHash = proofs.p4PortableProofHash
    manifest.p3VectorProofHash = proofs.p3VectorProofHash
    manifest.vectorState = proofs.vectorState
    manifest.vectorCollection = proofs.vectorCollection
    manifest.vectorCount = proofs.vectorCount
    manifest.vectorDimension = proofs.vectorDimension
    manifest.rawCount = snapshot.rawRecords.size
    manifest.normalizedCount = snapshot.normalizedRecords.size
    manifest.normalizedChecksum = ckbCertifiedNormalizedRecordsChecksum(
        snapshot.normalizedRecords)
    manifest.indexCount = snapshot.activeIndex.size
    manifest.graphNodeCount = graph.nodes.size
    manifest.graphEdgeCount = graph.edges.size
    manifest.activePointerHash = startHash
    manifest.contaminationProofHash = proofs.contaminationProofHash
    for (payload in payloads[1]) {
        let asset = CkbLogicalSnapshotAsset()
        asset.relativePath = payload.path
        asset.size = payload.size
        asset.sha256 = payload.sha256
        manifest.assets.add(asset)
    }
    let contract = buildCkbLogicalSnapshotManifest(manifest)
    if (!contract.ok) {
        result.diagnostic = contract.diagnostic
        return result
    }
    let end = store.loadActiveSnapshotPointer()
    let endHash = ckbActiveSnapshotPointerIdentityHash(end)
    if (!end.valid || endHash != startHash ||
        (proofs.expectedEndPointerHash != "" &&
        proofs.expectedEndPointerHash != endHash)) {
        result.diagnostic = "logical_snapshot_pointer_drift"
        return result
    }
    let archivePayloads = ArrayList<CkbReleaseArchivePayload>()
    for (payload in payloads[1]) { archivePayloads.add(payload) }
    let manifestPayload = CkbReleaseArchivePayload()
    manifestPayload.path = "RELEASE-MANIFEST.json"
    manifestPayload.bytes = contract.canonicalJson.toArray()
    archivePayloads.add(manifestPayload)
    ckbLogicalSnapshotSortPayloads(archivePayloads)
    let temporary = ckbLogicalSnapshotTemporaryPath(
        outputPath, contract.manifestHash, "export")
    var ownsTemporary: Bool = false
    try {
        if (exists(Path(temporary))) {
            result.diagnostic = "logical_snapshot_temporary_path_exists"
            return result
        }
        ownsTemporary = true
        let created = backend.createFromFiles(temporary, archivePayloads)
        if (!created.ok) {
            result.diagnostic = if (created.diagnostic == "") {
                "logical_snapshot_archive_create_failed"
            } else { created.diagnostic }
            return result
        }
        let inspected = inspectCkbReleaseArchive(backend, temporary)
        if (!inspected.ok ||
            inspected.manifest.manifestHash != contract.manifestHash) {
            result.diagnostic = if (!inspected.ok) {
                inspected.diagnostic
            } else { "logical_snapshot_archive_manifest_mismatch" }
            return result
        }
        result.archiveHash = backend.archiveHash(temporary)
        if (result.archiveHash == "") {
            result.diagnostic = "logical_snapshot_archive_hash_failed"
            return result
        }
        rename(temporary, to: outputPath, overwrite: false)
        ownsTemporary = false
    } catch (_: Exception) {
        result.diagnostic = "logical_snapshot_archive_commit_failed"
        return result
    } finally {
        if (ownsTemporary && exists(Path(temporary))) {
            try { remove(Path(temporary), recursive: true) } catch (_: Exception) { () }
        }
    }
    ckbLogicalSnapshotFillResult(result, manifest)
    result.ok = true
    result.diagnostic = "ok"
    result.evidenceLevel = if (proofs.p3ProofReal) {
        "real_p3_bound"
    } else { "fake_proof_dependency" }
    result.realP3Bound = proofs.p3ProofReal
    result.normalizedChecksum = ckbCertifiedNormalizedRecordsChecksum(
        snapshot.normalizedRecords)
    result
}

public func importCkbLogicalSnapshot(archivePath: String, targetRoot: String,
    backend: CkbReleaseArchiveBackend,
    pathPolicy!: CkbReleasePathPolicy = CkbReleasePathPolicy()):
    CkbLogicalSnapshotResult {
    let result = CkbLogicalSnapshotResult()
    let pathDiagnostic = ckbLogicalSnapshotNewPathDiagnostic(
        targetRoot, pathPolicy, "", "target")
    if (pathDiagnostic != "ok") {
        result.diagnostic = pathDiagnostic
        return result
    }
    let inspected = inspectCkbReleaseArchive(backend, archivePath)
    if (!inspected.ok) {
        result.diagnostic = inspected.diagnostic
        return result
    }
    let staging = ckbLogicalSnapshotTemporaryPath(
        targetRoot, inspected.manifest.manifestHash, "source")
    let targetTemporary = ckbLogicalSnapshotTemporaryPath(
        targetRoot, inspected.manifest.manifestHash, "target")
    var ownsStaging: Bool = false
    var ownsTargetTemporary: Bool = false
    try {
        if (exists(Path(staging)) || exists(Path(targetTemporary))) {
            result.diagnostic = "logical_snapshot_temporary_path_exists"
            return result
        }
        Directory.create(Path(staging), recursive: false)
        ownsStaging = true
        let extracted = backend.extractAllRegularToDirectory(
            archivePath, staging, inspected.manifest)
        if (!extracted.ok) {
            result.diagnostic = "logical_snapshot_asset_hash_mismatch"
            return result
        }
        let sourceStore = FileKnowledgeStore(staging)
        let sourcePointer = sourceStore.loadActiveSnapshotPointer()
        let sourceSnapshot = sourceStore.loadActiveSnapshot()
        if (!sourcePointer.valid) {
            result.diagnostic = "logical_snapshot_staged_pointer_invalid:${sourcePointer.diagnostic}"
            return result
        }
        if (!sourceSnapshot.valid) {
            result.diagnostic = "logical_snapshot_staged_payload_invalid"
            return result
        }
        if (ckbActiveSnapshotPointerIdentityHash(sourcePointer) !=
            inspected.manifest.activePointerHash) {
            result.diagnostic = "logical_snapshot_staged_pointer_hash_mismatch"
            return result
        }
        if (sourceSnapshot.activeVersion !=
            inspected.manifest.portableKnowledgeVersion) {
            result.diagnostic = "logical_snapshot_staged_version_mismatch"
            return result
        }
        let targetStore = FileKnowledgeStore(targetTemporary)
        ownsTargetTemporary = true
        let restored = targetStore.restoreActiveSnapshotBackup(staging)
        if (!restored.ok) {
            result.diagnostic = restored.diagnostic
            return result
        }
        let reloaded = targetStore.loadActiveSnapshot()
        let metadata = targetStore.loadMetadataStatus()
        if (!reloaded.valid || !metadata.valid ||
            reloaded.activeVersion != inspected.manifest.portableKnowledgeVersion ||
            reloaded.rawRecords.size != inspected.manifest.rawCount ||
            reloaded.normalizedRecords.size != inspected.manifest.normalizedCount ||
            ckbCertifiedNormalizedRecordsChecksum(reloaded.normalizedRecords) !=
                inspected.manifest.normalizedChecksum ||
            reloaded.activeIndex.size != inspected.manifest.indexCount ||
            metadata.vectorActiveCollection !=
                inspected.manifest.vectorCollection ||
            metadata.vectorIndexCount != inspected.manifest.vectorCount ||
            metadata.vectorDimension != inspected.manifest.vectorDimension) {
            result.diagnostic = "logical_snapshot_restore_readback_mismatch"
            return result
        }
        let kb = KnowledgeBase(FakeClock(0))
        if (!kb.restoreActiveSnapshot(reloaded)) {
            result.diagnostic = kb.status().restoreDiagnostic
            return result
        }
        let graph = kb.activeGraphBuild()
        if (!graph.ok ||
            graph.nodes.size != inspected.manifest.graphNodeCount ||
            graph.edges.size != inspected.manifest.graphEdgeCount) {
            result.diagnostic = "logical_snapshot_graph_readback_mismatch"
            return result
        }
        rename(targetTemporary, to: targetRoot, overwrite: false)
        ownsTargetTemporary = false
        ckbLogicalSnapshotFillResult(result, inspected.manifest)
        result.ok = true
        result.diagnostic = "ok"
        result.evidenceLevel = "imported_manifest"
        result.normalizedChecksum = ckbCertifiedNormalizedRecordsChecksum(
            reloaded.normalizedRecords)
    } catch (_: Exception) {
        if (result.diagnostic == "not_started") {
            result.diagnostic = "logical_snapshot_import_failed"
        }
    } finally {
        if (ownsStaging && exists(Path(staging))) {
            try { remove(Path(staging), recursive: true) } catch (_: Exception) { () }
        }
        if (ownsTargetTemporary && exists(Path(targetTemporary))) {
            try { remove(Path(targetTemporary), recursive: true) } catch (_: Exception) { () }
        }
    }
    result
}

public func ckbLogicalSnapshotBytesHash(bytes: Array<UInt8>): String {
    let digest = SHA256()
    digest.write(bytes)
    let out = StringBuilder()
    for (byte in digest.finish()) {
        out.append(ckbLogicalSnapshotNibble(byte / UInt8(16)))
        out.append(ckbLogicalSnapshotNibble(byte % UInt8(16)))
    }
    "sha256:${out.toString()}"
}

private func ckbLogicalSnapshotScanSourceFile(path: String): CkbReleaseSourceScan {
    let result = CkbReleaseSourceScan(); let digest = SHA256()
    let window = ArrayList<UInt8>(); var utf8Remaining: Int64 = 0
    var nextMin: UInt8 = UInt8(0x80); var nextMax: UInt8 = UInt8(0xbf)
    try {
        try (file = File(Path(path), OpenMode.Read)) {
            let buffer = Array<UInt8>(32000, repeat: UInt8(0))
            while (true) {
                let count = file.read(buffer)
                if (count < 0 || count > buffer.size) {
                    throw Exception("source_read")
                }
                if (count == 0) { break }
                if (result.size > 67108864 - count) {
                    result.diagnostic = "logical_snapshot_archive_entry_size_invalid"
                    return result
                }
                let chunk = if (count == buffer.size) { buffer }
                    else { buffer[0..count].clone() }
                digest.write(chunk); result.size += count
                for (byte in chunk) {
                    if (utf8Remaining == 0) {
                        if (byte <= UInt8(0x7f)) { () }
                        else if (byte >= UInt8(0xc2) && byte <= UInt8(0xdf)) {
                            utf8Remaining = 1; nextMin = UInt8(0x80); nextMax = UInt8(0xbf)
                        } else if (byte == UInt8(0xe0)) {
                            utf8Remaining = 2; nextMin = UInt8(0xa0); nextMax = UInt8(0xbf)
                        } else if ((byte >= UInt8(0xe1) && byte <= UInt8(0xec)) ||
                            (byte >= UInt8(0xee) && byte <= UInt8(0xef))) {
                            utf8Remaining = 2; nextMin = UInt8(0x80); nextMax = UInt8(0xbf)
                        } else if (byte == UInt8(0xed)) {
                            utf8Remaining = 2; nextMin = UInt8(0x80); nextMax = UInt8(0x9f)
                        } else if (byte == UInt8(0xf0)) {
                            utf8Remaining = 3; nextMin = UInt8(0x90); nextMax = UInt8(0xbf)
                        } else if (byte >= UInt8(0xf1) && byte <= UInt8(0xf3)) {
                            utf8Remaining = 3; nextMin = UInt8(0x80); nextMax = UInt8(0xbf)
                        } else if (byte == UInt8(0xf4)) {
                            utf8Remaining = 3; nextMin = UInt8(0x80); nextMax = UInt8(0x8f)
                        } else {
                            result.diagnostic = "invalid_response_encoding"; return result
                        }
                    } else {
                        if (byte < nextMin || byte > nextMax) {
                            result.diagnostic = "invalid_response_encoding"; return result
                        }
                        utf8Remaining -= 1
                        nextMin = UInt8(0x80); nextMax = UInt8(0xbf)
                    }
                    let lowered = if (byte >= UInt8(0x41) && byte <= UInt8(0x5a)) {
                        byte + UInt8(0x20)
                    } else { byte }
                    window.add(lowered)
                    if (window.size > 32) { window.remove(at: 0) }
                    if (ckbLogicalSnapshotSensitiveWindow(window)) {
                        result.diagnostic = "logical_snapshot_sensitive_content"; return result
                    }
                }
            }
        }
    } catch (_: Exception) { return result }
    if (utf8Remaining != 0) {
        result.diagnostic = "invalid_response_encoding"; return result
    }
    result.ok = true; result.diagnostic = "ok"
    result.sha256 = ckbReleaseDigestHash(digest); result
}

private func ckbLogicalSnapshotSensitiveWindow(window: ArrayList<UInt8>): Bool {
    for (pattern in ["authorization:", "private-token:", "bearer ",
        "/users/", "proxy_password="]) {
        let bytes = pattern.toArray()
        if (window.size < bytes.size) { continue }
        let offset = window.size - bytes.size; var matched = true
        for (i in 0..bytes.size) {
            if (window[offset + i] != bytes[i]) { matched = false; break }
        }
        if (matched) { return true }
    }
    false
}

private func ckbReleaseManifestIdentityDiagnostic(
    binding: CkbReleaseManifest,
    logical: CkbLogicalSnapshotManifest,
    vector: CkbQdrantSnapshotManifest): String {
    if (binding.schemaVersion != "ckb-release-manifest-v1" ||
        binding.portableKnowledgeVersion == "") {
        return "release_manifest_identity_invalid"
    }
    if (logical.manifestHash != binding.logicalManifestHash ||
        vector.logicalManifestHash != logical.manifestHash ||
        vector.manifestHash != binding.qdrantSnapshotManifestHash ||
        vector.snapshotSha256 != binding.qdrantSnapshotHash ||
        logical.p3VectorProofHash != vector.vectorProofHash ||
        binding.vectorProofHash != vector.vectorProofHash ||
        logical.vectorCollection != vector.collection ||
        binding.collection != vector.collection ||
        logical.vectorCount != vector.points ||
        binding.points != vector.points ||
        logical.vectorDimension != vector.dimension ||
        binding.dimension != vector.dimension ||
        binding.distance.toAsciiLower() != vector.distance.toAsciiLower()) {
        return "release_manifest_vector_binding_mismatch"
    }
    "ok"
}

private func ckbReleaseManifestBody(binding: CkbReleaseManifest): String {
    "{\"schemaVersion\":\"${ckbLogicalSnapshotJson(binding.schemaVersion)}\"," +
        "\"portableKnowledgeVersion\":\"${ckbLogicalSnapshotJson(binding.portableKnowledgeVersion)}\"," +
        "\"logicalManifestHash\":\"${binding.logicalManifestHash}\"," +
        "\"qdrantSnapshotManifestHash\":\"${binding.qdrantSnapshotManifestHash}\"," +
        "\"qdrantSnapshotHash\":\"${binding.qdrantSnapshotHash}\"," +
        "\"vectorProofHash\":\"${binding.vectorProofHash}\"," +
        "\"collection\":\"${ckbLogicalSnapshotJson(binding.collection)}\"," +
        "\"points\":${binding.points},\"dimension\":${binding.dimension}," +
        "\"distance\":\"${ckbLogicalSnapshotJson(binding.distance)}\""
}

private func ckbLogicalSnapshotValidateStructure(
    manifest: CkbLogicalSnapshotManifest): CkbLogicalSnapshotContract {
    if (manifest.schemaVersion != "ckb-logical-snapshot-v1") {
        return ckbLogicalSnapshotFailure("logical_snapshot_schema_mismatch")
    }
    if (manifest.sourceState !=
        CkbLogicalSnapshotSourceStates.PORTABLE_VECTOR_ARTIFACT ||
        manifest.portableKnowledgeVersion == "" ||
        manifest.vectorState != EmbeddingProviderState.READY ||
        manifest.vectorCollection == "" || manifest.vectorCount <= 0 ||
        manifest.vectorDimension <= 0 || manifest.rawCount <= 0 ||
        manifest.normalizedCount <= 0 || manifest.indexCount <= 0 ||
        manifest.graphNodeCount < 0 || manifest.graphEdgeCount < 0) {
        return ckbLogicalSnapshotFailure("logical_snapshot_identity_invalid")
    }
    for (hash in [manifest.p4PortableProofHash, manifest.p3VectorProofHash,
        manifest.activePointerHash, manifest.contaminationProofHash,
        manifest.normalizedChecksum]) {
        if (!ckbLogicalSnapshotHashValid(hash)) {
            return ckbLogicalSnapshotFailure("logical_snapshot_hash_invalid")
        }
    }
    if (manifest.assets.size == 0) {
        return ckbLogicalSnapshotFailure("logical_snapshot_assets_empty")
    }
    let seen = HashSet<String>()
    for (asset in manifest.assets) {
        if (!ckbLogicalSnapshotRelativePathValid(asset.relativePath)) {
            return ckbLogicalSnapshotFailure(
                "logical_snapshot_asset_path_invalid")
        }
        if (seen.contains(asset.relativePath)) {
            return ckbLogicalSnapshotFailure(
                "logical_snapshot_asset_duplicate")
        }
        if (asset.entryType != CkbReleaseArchiveEntryKinds.REGULAR ||
            asset.size < 0 || !ckbLogicalSnapshotHashValid(asset.sha256)) {
            return ckbLogicalSnapshotFailure(
                "logical_snapshot_asset_invalid")
        }
        seen.add(asset.relativePath)
    }
    let result = CkbLogicalSnapshotContract()
    result.ok = true
    result.diagnostic = "ok"
    result
}

private func ckbLogicalSnapshotManifestBody(
    manifest: CkbLogicalSnapshotManifest): String {
    let rows = ArrayList<String>()
    for (asset in manifest.assets) {
        rows.add("{\"relativePath\":\"${ckbLogicalSnapshotJson(asset.relativePath)}\"," +
            "\"size\":${asset.size},\"sha256\":\"${asset.sha256}\"," +
            "\"entryType\":\"${asset.entryType}\"}")
    }
    let ordered = rows.toArray()
    sort(ordered)
    var assets = "["
    for (i in 0..ordered.size) {
        if (i > 0) { assets += "," }
        assets += ordered[i]
    }
    assets += "]"
    "{\"schemaVersion\":\"${ckbLogicalSnapshotJson(manifest.schemaVersion)}\"," +
        "\"sourceState\":\"${ckbLogicalSnapshotJson(manifest.sourceState)}\"," +
        "\"portableKnowledgeVersion\":\"${ckbLogicalSnapshotJson(manifest.portableKnowledgeVersion)}\"," +
        "\"p4PortableProofHash\":\"${manifest.p4PortableProofHash}\"," +
        "\"p3VectorProofHash\":\"${manifest.p3VectorProofHash}\"," +
        "\"vectorState\":\"${ckbLogicalSnapshotJson(manifest.vectorState)}\"," +
        "\"vectorCollection\":\"${ckbLogicalSnapshotJson(manifest.vectorCollection)}\"," +
        "\"vectorCount\":${manifest.vectorCount}," +
        "\"vectorDimension\":${manifest.vectorDimension}," +
        "\"rawCount\":${manifest.rawCount}," +
        "\"normalizedCount\":${manifest.normalizedCount}," +
        "\"normalizedChecksum\":\"${manifest.normalizedChecksum}\"," +
        "\"indexCount\":${manifest.indexCount}," +
        "\"graphNodeCount\":${manifest.graphNodeCount}," +
        "\"graphEdgeCount\":${manifest.graphEdgeCount}," +
        "\"activePointerHash\":\"${manifest.activePointerHash}\"," +
        "\"contaminationProofHash\":\"${manifest.contaminationProofHash}\"," +
        "\"assets\":${assets}"
}

private func ckbLogicalSnapshotProofDiagnostic(
    proofs: CkbLogicalSnapshotExportProofs,
    pointer: CkbActiveSnapshotPointer): String {
    if (proofs.sourceState !=
        CkbLogicalSnapshotSourceStates.PORTABLE_VECTOR_CANDIDATE &&
        proofs.sourceState !=
        CkbLogicalSnapshotSourceStates.PROMOTED_PORTABLE_PRODUCTION) {
        return "logical_snapshot_source_state_forbidden"
    }
    if (proofs.portableKnowledgeVersion == "" ||
        proofs.portableKnowledgeVersion != pointer.activeVersion ||
        proofs.vectorState != EmbeddingProviderState.READY ||
        proofs.vectorCollection == "" ||
        proofs.vectorCollection != pointer.vectorActiveCollection ||
        proofs.vectorCount <= 0 || proofs.vectorDimension <= 0) {
        return "logical_snapshot_vector_proof_invalid"
    }
    if (!ckbLogicalSnapshotHashValid(proofs.p4PortableProofHash) ||
        !ckbLogicalSnapshotHashValid(proofs.p3VectorProofHash) ||
        !ckbLogicalSnapshotHashValid(proofs.contaminationProofHash)) {
        return "logical_snapshot_proof_hash_invalid"
    }
    if (proofs.pathMachineFindingCount != 0 ||
        proofs.pathUnmappedFindingCount != 0) {
        return "logical_snapshot_portable_path_finding"
    }
    "ok"
}

private func ckbLogicalSnapshotStorePayloads(store: FileKnowledgeStore,
    pointer: CkbActiveSnapshotPointer):
    (CkbLogicalSnapshotContract, ArrayList<CkbReleaseArchivePayload>) {
    let payloads = ArrayList<CkbReleaseArchivePayload>()
    let tx = "transactions/${pointer.txId}"
    let paths = ArrayList<String>()
    for (relative in [
        "metadata/active-snapshot.manifest",
        "${tx}/COMMIT",
        "${tx}/normalized/records.ckb",
        "${tx}/index/active.version",
        "${tx}/index/active.ckb",
        "${tx}/index/graph-nodes.ckb",
        "${tx}/index/graph-edges.ckb",
        "${tx}/metadata/status.ckb"
    ]) { paths.add(relative) }
    let rawRoot = Path(store.rootPath()).join("${tx}/raw")
    if (!exists(rawRoot)) {
        return (ckbLogicalSnapshotFailure(
            "logical_snapshot_raw_directory_missing"), payloads)
    }
    let canonicalRawRoot = try { canonicalize(rawRoot) } catch (_: Exception) {
        return (ckbLogicalSnapshotFailure(
            "logical_snapshot_raw_directory_invalid"), payloads)
    }
    for (entry in Directory.readFrom(rawRoot)) {
        if (!entry.isRegular() || !entry.name.endsWith(".ckb") ||
            !ckbLogicalSnapshotRelativePathValid(entry.name) ||
            (try { canonicalize(entry.path).toString() } catch (_: Exception) {
                ""
            }) != canonicalRawRoot.join(entry.name).toString()) {
            return (ckbLogicalSnapshotFailure(
                "logical_snapshot_raw_entry_invalid"), payloads)
        }
        paths.add("${tx}/raw/${entry.name}")
    }
    let commitBytes = try {
        File.readFrom(Path(store.rootPath()).join("${tx}/COMMIT"))
    } catch (_: Exception) {
        return (ckbLogicalSnapshotFailure(
            "logical_snapshot_commit_missing"), payloads)
    }
    let commitText = try { String.fromUtf8(commitBytes) } catch (_: Exception) {
        return (ckbLogicalSnapshotFailure(
            "invalid_response_encoding"), payloads)
    }
    if (!commitText.contains("committed=true")) {
        return (ckbLogicalSnapshotFailure(
            "logical_snapshot_commit_invalid"), payloads)
    }
    if (commitText.contains("persistVectorFile=true")) {
        paths.add("${tx}/index/vector-${pointer.vectorActiveCollection}.ckb")
    }
    if (pointer.companionMode != CkbActiveSnapshotCompanionMode.NONE) {
        for (relative in [
            "${tx}/metadata/cangjie-version-manifest.ckb",
            "${tx}/metadata/cangjie-freshness.ckb",
            "${tx}/metadata/cangjie-release-coverage.ckb"
        ]) { paths.add(relative) }
    }
    let ordered = paths.toArray()
    sort(ordered)
    let canonicalStoreRoot = try {
        canonicalize(Path(store.rootPath()))
    } catch (_: Exception) {
        return (ckbLogicalSnapshotFailure(
            "logical_snapshot_store_root_invalid"), payloads)
    }
    for (relative in ordered) {
        if (!ckbLogicalSnapshotRelativePathValid(relative)) {
            return (ckbLogicalSnapshotFailure(
                "logical_snapshot_asset_path_invalid"), payloads)
        }
        let sourcePath = Path(store.rootPath()).join(relative)
        let canonicalSource = try {
            canonicalize(sourcePath).toString()
        } catch (_: Exception) {
            return (ckbLogicalSnapshotFailure(
                "logical_snapshot_asset_read_failed"), payloads)
        }
        if (canonicalSource != canonicalStoreRoot.join(relative).toString()) {
            return (ckbLogicalSnapshotFailure(
                "logical_snapshot_source_symlink_forbidden"), payloads)
        }
        let scan = ckbLogicalSnapshotScanSourceFile(sourcePath.toString())
        if (!scan.ok) {
            return (ckbLogicalSnapshotFailure(
                scan.diagnostic), payloads)
        }
        let payload = CkbReleaseArchivePayload()
        payload.path = relative
        payload.sourcePath = sourcePath.toString()
        payload.size = scan.size
        payload.sha256 = scan.sha256
        payloads.add(payload)
    }
    let success = CkbLogicalSnapshotContract()
    success.ok = true
    success.diagnostic = "ok"
    (success, payloads)
}

private func ckbLogicalSnapshotNewPathDiagnostic(pathText: String,
    policy: CkbReleasePathPolicy, sourceStoreRoot: String,
    role: String): String {
    let rolePrefix = if (role == "target") {
        "logical_snapshot_target"
    } else { "logical_snapshot" }
    if (pathText == "" || pathText != pathText.trimAscii() ||
        !pathText.startsWith("/") || pathText.contains("\\") ||
        pathText.contains("/../") || pathText.endsWith("/..") ||
        pathText.contains("/./") || pathText.endsWith("/.") ||
        pathText.contains("//")) {
        return "${rolePrefix}_path_invalid"
    }
    let path = Path(pathText)
    if (exists(path)) {
        return if (role == "target") {
            "logical_snapshot_target_exists"
        } else { "logical_snapshot_output_exists" }
    }
    if (!exists(path.parent)) { return "logical_snapshot_parent_missing" }
    let parent = try { canonicalize(path.parent).toString() } catch (_: Exception) {
        return "${rolePrefix}_path_invalid"
    }
    let expected = Path(parent).join(path.fileName).toString()
    if (expected != pathText) { return "${rolePrefix}_path_invalid" }
    for (root in [policy.worktreeRoot, policy.productionStoreRoot,
        policy.userConfigRoot, sourceStoreRoot]) {
        if (root == "") { continue }
        let canonicalRoot = try {
            if (exists(Path(root))) {
                canonicalize(Path(root)).toString()
            } else { root }
        } catch (_: Exception) { root }
        if (pathText == canonicalRoot ||
            pathText.startsWith("${canonicalRoot}/") ||
            canonicalRoot.startsWith("${pathText}/")) {
            return "logical_snapshot_path_forbidden"
        }
    }
    "ok"
}

private func ckbLogicalSnapshotTemporaryPath(target: String, hash: String,
    kind: String): String {
    "${target}.tmp-${kind}-${hash.replace("sha256:", "")}"
}

private func ckbLogicalSnapshotSortPayloads(
    payloads: ArrayList<CkbReleaseArchivePayload>): Unit {
    let ordered = payloads.toArray()
    sort(ordered, by: { left: CkbReleaseArchivePayload,
        right: CkbReleaseArchivePayload =>
        left.path.compare(right.path)
    })
    payloads.clear()
    for (payload in ordered) { payloads.add(payload) }
}

private func ckbLogicalSnapshotFillResult(result: CkbLogicalSnapshotResult,
    manifest: CkbLogicalSnapshotManifest): Unit {
    result.activeVersion = manifest.portableKnowledgeVersion
    result.rawCount = manifest.rawCount
    result.normalizedCount = manifest.normalizedCount
    result.normalizedChecksum = manifest.normalizedChecksum
    result.indexCount = manifest.indexCount
    result.graphNodeCount = manifest.graphNodeCount
    result.graphEdgeCount = manifest.graphEdgeCount
    result.vectorCollection = manifest.vectorCollection
    result.vectorCount = manifest.vectorCount
    result.vectorDimension = manifest.vectorDimension
    result.activePointerHash = manifest.activePointerHash
    result.manifestHash = manifest.manifestHash
}

private func ckbLogicalSnapshotRelativePathValid(value: String): Bool {
    if (value == "" || value.startsWith("/") || value.startsWith("~") ||
        value.contains("\\") || value.contains(":") ||
        value.endsWith("/") || value.contains("//")) {
        return false
    }
    for (part in value.split("/")) {
        if (part == "" || part == "." || part == "..") { return false }
    }
    for (rune in value.runes()) {
        if (rune < r' ' || rune == r'\u{7f}') { return false }
    }
    true
}

private func ckbLogicalSnapshotSensitiveText(value: String): Bool {
    let lower = value.toAsciiLower()
    lower.contains("authorization:") ||
        lower.contains("private-token:") ||
        lower.contains("bearer ") ||
        lower.contains("/users/") ||
        lower.contains("proxy_password=")
}

private func ckbLogicalSnapshotHashValid(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 71 || !value.startsWith("sha256:")) { return false }
    for (rune in runes[7..71]) {
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) {
            return false
        }
    }
    true
}

private func ckbLogicalSnapshotString(object: JsonObject,
    key: String): String {
    object.get(key).getOrThrow().asString().getValue()
}

private func ckbLogicalSnapshotInt(object: JsonObject, key: String): Int64 {
    object.get(key).getOrThrow().asInt().getValue()
}

private func ckbLogicalSnapshotJson(value: String): String {
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

private func ckbLogicalSnapshotFailure(
    diagnostic: String): CkbLogicalSnapshotContract {
    let result = CkbLogicalSnapshotContract()
    result.diagnostic = diagnostic
    result
}

private func ckbLogicalSnapshotNibble(value: UInt8): String {
    if (value == UInt8(0)) { return "0" }
    if (value == UInt8(1)) { return "1" }
    if (value == UInt8(2)) { return "2" }
    if (value == UInt8(3)) { return "3" }
    if (value == UInt8(4)) { return "4" }
    if (value == UInt8(5)) { return "5" }
    if (value == UInt8(6)) { return "6" }
    if (value == UInt8(7)) { return "7" }
    if (value == UInt8(8)) { return "8" }
    if (value == UInt8(9)) { return "9" }
    if (value == UInt8(10)) { return "a" }
    if (value == UInt8(11)) { return "b" }
    if (value == UInt8(12)) { return "c" }
    if (value == UInt8(13)) { return "d" }
    if (value == UInt8(14)) { return "e" }
    "f"
}
