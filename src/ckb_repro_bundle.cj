package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashSet}
import std.fs.{Directory, File, Path, OpenMode, canonicalize, exists, remove}
import std.sort.*
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

public class CkbReproBundleAsset {
    public var relativePath: String = ""
    public var bytes: Array<UInt8> = Array<UInt8>()
    public var size: Int64 = 0
    public var sha256: String = ""
    public var inputKind: String = ""
    public var role: String = ""
    public var logicalAsset: String = ""
    public var partIndex: Int64 = 0
    public var partCount: Int64 = 0
    public var logicalSize: Int64 = 0
    public var logicalSha256: String = ""
    public init() {}
}

public class CkbReproAssetPart {
    public var relativePath: String = ""
    public var offset: Int64 = 0
    public var size: Int64 = 0
    public init() {}
}

public class CkbReproBundleOptions {
    public var outputRoot: String = ""
    public var worktreeRoot: String = ""
    public var productionRoot: String = ""
    public var privateRunRoot: String = ""
    public var userConfigRoot: String = ""
    public init() {}
}

public class CkbReproBundleResult {
    public var ok: Bool = false
    public var diagnostic: String = "not_validated"
    public var inputSetHash: String = ""
    public var treeHash: String = ""
    public var assetCount: Int64 = 0
    public init() {}
}

public class CkbReproBundleCliOptions {
    public var mode: String = ""
    public var inputRoot: String = ""
    public var outputRoot: String = ""
    public var unsignedRoot: String = ""
    public var verificationReport: String = ""
    public var worktreeRoot: String = ""
    public var productionRoot: String = ""
    public var privateRunRoot: String = ""
    public var userConfigRoot: String = ""
    public var json: Bool = false
    public var valid: Bool = false
    public var diagnostic: String = "usage_error"
    public init() {}
}

public interface CkbReproFrozenAssetProvider {
    func collect(root: String): CkbReproBundleLoadResult
}

public class CkbReproFilesystemFrozenAssetProvider <:
    CkbReproFrozenAssetProvider {
    private let reader: CkbReproFilesystemBundleReadBackend
    public init() { this.reader = CkbReproFilesystemBundleReadBackend() }
    public func collect(root: String): CkbReproBundleLoadResult {
        validateCkbReproBundleManifest(root, this.reader)
    }
}

public class CkbReproBundleCliPathContext {
    public var worktreeRoot: String = ""
    public var productionRoot: String = ""
    public var privateRunRoot: String = ""
    public var userConfigRoot: String = ""
    public init() {}
}

public interface CkbReproBundleCliExecutor {
    func exists(path: String): Bool
    func outputParentExists(path: String): Bool
    func assembleUnsigned(options: CkbReproBundleCliOptions): CkbReproBundleResult
    func finalizeBundle(options: CkbReproBundleCliOptions): CkbReproBundleResult
    func cleanupOutput(path: String): Bool
}

public class CkbReproFilesystemBundleBackend <: CkbReproBundleBackend {
    public init() {}
    public func rootExists(root: String): Bool { exists(Path(root)) }
    public func rootIsEmpty(root: String): Bool {
        try { Directory.readFrom(Path(root)).size == 0 } catch (_: Exception) { false }
    }
    public func createRoot(root: String): Bool {
        try { Directory.create(Path(root), recursive: false); true }
        catch (_: Exception) { false }
    }
    public func read(root: String, relativePath: String): Array<UInt8> {
        try { File.readFrom(Path(root).join(relativePath)) }
        catch (_: Exception) { Array<UInt8>() }
    }
    public func write(root: String, relativePath: String,
        bytes: Array<UInt8>): Bool {
        try {
            let target = Path(root).join(relativePath)
            if (!exists(target.parent)) { Directory.create(target.parent, recursive: true) }
            File.writeTo(target, bytes); true
        } catch (_: Exception) { false }
    }
    public func removeRoot(root: String): Bool {
        try { if (exists(Path(root))) { remove(Path(root), recursive: true) }; true }
        catch (_: Exception) { false }
    }
}

public class CkbReproFilesystemBundleCliExecutor <: CkbReproBundleCliExecutor {
    private let assets: ArrayList<CkbReproBundleAsset>
    private let expectedInputSetHash: String
    private let backend: CkbReproFilesystemBundleBackend
    public init(values: ArrayList<CkbReproBundleAsset>, expected: String) {
        this.assets = values
        this.expectedInputSetHash = expected
        this.backend = CkbReproFilesystemBundleBackend()
    }
    public func exists(path: String): Bool { exists(Path(path)) }
    public func outputParentExists(path: String): Bool { exists(Path(path).parent) }
    public func assembleUnsigned(options: CkbReproBundleCliOptions):
        CkbReproBundleResult {
        if (!p9BundleCliNewOutputCanonical(options.outputRoot)) {
            return p9BundleCliFailure("bundle_output_not_canonical")
        }
        if (this.assets.size == 0) { return p9BundleCliFailure("bundle_inputs_not_ready") }
        assembleCkbUnsignedReleaseCandidate(
            p9BundleCliCoreOptions(options), this.assets, this.backend)
    }
    public func finalizeBundle(options: CkbReproBundleCliOptions):
        CkbReproBundleResult {
        if (!p9BundleCliNewOutputCanonical(options.outputRoot) ||
            !p9BundleCliExistingCanonical(options.unsignedRoot) ||
            !p9BundleCliExistingCanonical(options.verificationReport)) {
            return p9BundleCliFailure("bundle_path_not_canonical")
        }
        if (this.assets.size == 0 || this.expectedInputSetHash == "") {
            return p9BundleCliFailure("bundle_verified_inputs_not_ready")
        }
        finalizeCkbReproReleaseBundle(p9BundleCliCoreOptions(options),
            this.assets, this.expectedInputSetHash, this.backend)
    }
    public func cleanupOutput(path: String): Bool {
        // The core writer removes only roots that it created. A later generic
        // cleanup must not delete a path won by another process.
        true
    }
}

public class CkbReproProductionBundleCliExecutor <:
    CkbReproBundleCliExecutor {
    private let reader: CkbReproBundleReadBackend
    private var ownedRoot: String = ""
    public init() {
        this.reader = CkbReproFilesystemBundleReadBackend()
    }
    public func exists(path: String): Bool { exists(Path(path)) }
    public func outputParentExists(path: String): Bool { exists(Path(path).parent) }
    public func assembleUnsigned(options: CkbReproBundleCliOptions):
        CkbReproBundleResult {
        if (options.inputRoot == "" ||
            !p9BundleCliExistingCanonical(options.inputRoot) ||
            !p9BundleCliNewOutputCanonical(options.outputRoot)) {
            return p9BundleCliFailure("bundle_input_root_invalid")
        }
        let loaded = p9LoadFrozenReleaseInputs(options.inputRoot, this.reader)
        if (!loaded.contract.ok) { return p9BundleCliFailure(loaded.contract.diagnostic) }
        try { Directory.create(Path(options.outputRoot), recursive: false) }
        catch (_: Exception) {
            return p9BundleCliFailure("bundle_output_create_failed")
        }
        this.ownedRoot = options.outputRoot
        if (!p9BundleStreamFrozenInputs(options.inputRoot,
            options.outputRoot, loaded, this.reader)) {
            return p9BundleCliFailure("bundle_stream_copy_failed")
        }
        let copied = validateCkbReproBundleManifest(options.outputRoot,
            CkbReproFilesystemBundleReadBackend())
        if (!copied.contract.ok || copied.manifest.inputSetHash !=
            loaded.manifest.inputSetHash) {
            return p9BundleCliFailure("bundle_stream_copy_validation_failed")
        }
        let out = CkbReproBundleResult()
        out.ok = true; out.diagnostic = "ready"
        out.inputSetHash = copied.manifest.inputSetHash
        out.treeHash = copied.contract.manifestHash
        out.assetCount = copied.manifest.assets.size
        out
    }
    public func finalizeBundle(options: CkbReproBundleCliOptions):
        CkbReproBundleResult {
        if (!p9BundleCliNewOutputCanonical(options.outputRoot) ||
            !p9BundleCliExistingCanonical(options.unsignedRoot) ||
            !p9BundleCliExistingCanonical(options.verificationReport)) {
            return p9BundleCliFailure("bundle_path_not_canonical")
        }
        let report = p9BundleReadSmallFile(options.verificationReport,
            16 * 1024 * 1024)
        if (report[0] != "ok") { return p9BundleCliFailure(report[0]) }
        let reportBytes = report[1]
        let loaded = loadCkbReproFinalizeInputs(options.unsignedRoot,
            reportBytes, this.reader)
        if (!loaded.ok) { return p9BundleCliFailure(loaded.diagnostic) }
        try { Directory.create(Path(options.outputRoot), recursive: false) }
        catch (_: Exception) {
            return p9BundleCliFailure("bundle_output_create_failed")
        }
        this.ownedRoot = options.outputRoot
        if (!p9BundleStreamCopyValidated(options.unsignedRoot,
            options.outputRoot, loaded.manifest, this.reader)) {
            return p9BundleCliFailure("bundle_stream_copy_failed")
        }
        let outputLoaded = validateCkbReproBundleManifest(options.outputRoot,
            CkbReproFilesystemBundleReadBackend())
        if (!outputLoaded.contract.ok ||
            outputLoaded.manifest.inputSetHash != loaded.manifest.inputSetHash) {
            return p9BundleCliFailure("bundle_stream_copy_validation_failed")
        }
        let verificationTarget = Path(options.outputRoot)
            .join("verification-report.json")
        try { File.writeTo(verificationTarget, reportBytes) }
        catch (_: Exception) { return p9BundleCliFailure(
            "bundle_verification_report_copy_failed") }
        let manifestBytes = renderCkbReproBundleManifest(
            loaded.manifest).toArray()
        let attestation = buildCkbReproBuildAttestation(
            reportBytes, manifestBytes)
        if (!attestation[0].ok) {
            return p9BundleCliFailure(attestation[0].diagnostic)
        }
        let attestationBytes = attestation[1].toArray()
        try {
            File.writeTo(Path(options.outputRoot).join(
                "build-attestation.json"), attestationBytes)
            File.writeTo(Path(options.outputRoot).join("SHA256SUMS"),
                p9BundleFinalShaSums(loaded.manifest, manifestBytes,
                    reportBytes, attestationBytes).toArray())
        } catch (_: Exception) {
            return p9BundleCliFailure("bundle_final_artifact_write_failed")
        }
        let out = CkbReproBundleResult()
        out.ok = true; out.diagnostic = "ready"
        out.inputSetHash = loaded.manifest.inputSetHash
        out.treeHash = outputLoaded.contract.manifestHash
        out.assetCount = loaded.manifest.assets.size
        out
    }
    public func cleanupOutput(path: String): Bool {
        if (this.ownedRoot != path) { return true }
        try { remove(Path(path), recursive: true); this.ownedRoot = ""; true }
        catch (_: Exception) { false }
    }
}

public class CkbReproBundleManifest {
    public var schemaVersion: String = ""
    public var inputSetHash: String = ""
    public let assets = ArrayList<CkbReproBundleAsset>()
    public init() {}
}

public class CkbReproReleaseInput {
    public var sourceRelativePath: String = ""
    public var asset: CkbReproBundleAsset = CkbReproBundleAsset()
    public init() {}
}

public class CkbReproReleaseInputsLoadResult {
    public var contract: CkbReproContractResult = CkbReproContractResult()
    public var manifest: CkbReproBundleManifest = CkbReproBundleManifest()
    public let inputs = ArrayList<CkbReproReleaseInput>()
    public var rootIdentity: String = ""
    public var listingHash: String = ""
    public var manifestBytes: Array<UInt8> = Array<UInt8>()
    public var releaseCommit: String = ""
    public var runCriticalTreeHash: String = ""
    public var certifiedRunInputHash: String = ""
    public var referenceManifestHash: String = ""
    public var authorityDeliveryMode: String = ""
    public var authorityLayoutHash: String = ""
    public init() {}
}

public class CkbReproBundleReadEntry {
    public var relativePath: String = ""
    public var kind: String = ""
    public var canonicalPath: String = ""
    public var withinRoot: Bool = false
    public var identity: String = ""
    public var size: Int64 = 0
    public init() {}
}

public class CkbReproBundleAssetProof {
    public var relativePath: String = ""
    public var size: Int64 = 0
    public var sha256: String = ""
    public var identity: String = ""
    public var proofHash: String = ""
    public init() {}
}

public class CkbReproBundleLoadResult {
    public var contract: CkbReproContractResult = CkbReproContractResult()
    public var manifest: CkbReproBundleManifest = CkbReproBundleManifest()
    public let assetProofs = ArrayList<CkbReproBundleAssetProof>()
    public var proofSetHash: String = ""
    public var rootIdentity: String = ""
    public init() {}
}

public class CkbReproPromotionAssetSnapshot {
    public var contract: CkbReproContractResult = CkbReproContractResult()
    public var loaded: CkbReproBundleLoadResult = CkbReproBundleLoadResult()
    public let bytes = ArrayList<Array<UInt8>>()
    public init() {}
}

public class CkbReproPromotionRuntimeAssets {
    public var contract: CkbReproContractResult = CkbReproContractResult()
    public var control: CkbReproPromotionAssetSnapshot =
        CkbReproPromotionAssetSnapshot()
    public var ownedRoot: String = ""
    public var logicalSnapshotPath: String = ""
    public var logicalSnapshotSha256: String = ""
    public var qdrantSnapshotPath: String = ""
    public var qdrantSnapshotSha256: String = ""
    public init() {}
}

// Promotion consumes a fixed, single-part authority layout. This prevents a
// caller from mixing control proofs with runtime assets from another bundle.
public func validateCkbReproPromotionBundleLayout(
    assets: ArrayList<CkbReproBundleAsset>): CkbReproContractResult {
    let required = [
        ("promotion-candidate.json", "p4_build_proof"),
        ("portable-logical-proof.json", "p4_build_proof"),
        ("portable-vector-proof.json", "p4_build_proof"),
        ("public-evidence-export.json", "p5_public_evidence"),
        ("reproducibility/manifests/reference-run.json", "p8_reference"),
        ("release/release-commit.txt", "release_commit"),
        ("qdrant-snapshot-manifest.json", "p3_qdrant_snapshot"),
        ("ckb-logical-snapshot.tar.zst", "p2_logical_snapshot"),
        ("qdrant-collection.snapshot", "p3_qdrant_snapshot")
    ]
    for (row in required) {
        var matched: Int64 = 0
        for (asset in assets) {
            if (asset.relativePath == row[0] && asset.role == row[1] &&
                asset.logicalAsset == row[0] && asset.partIndex == 0 &&
                asset.partCount == 1 && asset.logicalSize == asset.size &&
                asset.logicalSha256 == asset.sha256) { matched += 1 }
        }
        if (matched != 1) {
            return p9BundleFailure("promotion_bundle_layout_invalid")
        }
    }
    for (expected in [("p2_logical_snapshot", Int64(1)),
        ("p3_qdrant_snapshot", Int64(2)),
        ("p4_build_proof", Int64(3)),
        ("p5_public_evidence", Int64(1)),
        ("p8_reference", Int64(1)),
        ("release_commit", Int64(1))]) {
        var count: Int64 = 0
        for (asset in assets) {
            if (asset.role == expected[0]) { count += 1 }
        }
        if (count != expected[1]) {
            return p9BundleFailure("promotion_bundle_layout_invalid")
        }
    }
    p9BundleSuccess()
}

// Captures bounded JSON/text controls in memory and streams both potentially
// large runtime snapshots into a newly owned directory. Each stream is hashed
// from the no-follow handle that supplied the bytes.
public func captureCkbReproPromotionRuntimeAssets(root: String,
    ownedRoot: String, backend: CkbReproBundleReadBackend):
    CkbReproPromotionRuntimeAssets {
    let out = CkbReproPromotionRuntimeAssets()
    let before = validateCkbReproBundleManifest(root, backend)
    if (!before.contract.ok) { out.contract = before.contract; return out }
    let layout = validateCkbReproPromotionBundleLayout(before.manifest.assets)
    if (!layout.ok) { out.contract = layout; return out }
    if (!p9PromotionOwnedRootValid(root, ownedRoot)) {
        out.contract = p9BundleFailure("promotion_owned_root_invalid")
        return out
    }
    try {
        Directory.create(Path(ownedRoot), recursive: false)
        out.ownedRoot = ownedRoot
        let listing = backend.list(root)
        let controls = ["promotion-candidate.json",
            "portable-logical-proof.json", "portable-vector-proof.json",
            "public-evidence-export.json",
            "reproducibility/manifests/reference-run.json",
            "release/release-commit.txt", "qdrant-snapshot-manifest.json"]
        for (path in controls) {
            let read = p9PromotionReadSmallAsset(root, path, before, listing,
                backend)
            if (!read[0].ok) {
                out.contract = read[0]
                p9PromotionCleanupOwnedRoot(out)
                return out
            }
            out.control.bytes.add(read[1])
        }
        out.control.loaded = before
        out.control.contract = p9BundleSuccess()

        let logical = p9PromotionStreamAsset(root,
            "ckb-logical-snapshot.tar.zst", ownedRoot, before, listing,
            backend)
        if (!logical[0].ok) {
            out.contract = logical[0]; p9PromotionCleanupOwnedRoot(out)
            return out
        }
        out.logicalSnapshotPath = logical[1]
        out.logicalSnapshotSha256 = logical[2]
        let vector = p9PromotionStreamAsset(root,
            "qdrant-collection.snapshot", ownedRoot, before, listing, backend)
        if (!vector[0].ok) {
            out.contract = vector[0]; p9PromotionCleanupOwnedRoot(out)
            return out
        }
        out.qdrantSnapshotPath = vector[1]
        out.qdrantSnapshotSha256 = vector[2]

        let after = validateCkbReproBundleManifest(root, backend)
        if (!after.contract.ok || after.rootIdentity != before.rootIdentity ||
            after.manifest.inputSetHash != before.manifest.inputSetHash ||
            after.proofSetHash != before.proofSetHash) {
            out.contract = p9BundleFailure("promotion_bundle_changed")
            p9PromotionCleanupOwnedRoot(out)
            return out
        }
        out.contract = p9BundleSuccess(); out
    } catch (_: Exception) {
        out.contract = p9BundleFailure("promotion_asset_read_failed")
        p9PromotionCleanupOwnedRoot(out)
        out
    }
}

public func cleanupCkbReproPromotionRuntimeAssets(
    assets: CkbReproPromotionRuntimeAssets): Bool {
    p9PromotionCleanupOwnedRoot(assets)
}

// Captures only the bounded promotion control assets. Large bundle payloads
// remain streaming-only and are never retained by bundle validation.
public func captureCkbReproPromotionAssets(root: String,
    backend: CkbReproBundleReadBackend): CkbReproPromotionAssetSnapshot {
    let out = CkbReproPromotionAssetSnapshot()
    let before = validateCkbReproBundleManifest(root, backend)
    if (!before.contract.ok) { out.contract = before.contract; return out }
    let paths = ["promotion-candidate.json", "portable-logical-proof.json",
        "portable-vector-proof.json", "public-evidence-export.json",
        "reproducibility/manifests/reference-run.json",
        "release/release-commit.txt"]
    try {
        let listing = backend.list(root)
        for (path in paths) {
            let entry = p9FindBundleReadEntry(listing, path)
            if (!entry[0] || entry[1].size > 64 * 1024) {
                out.contract = p9BundleFailure("promotion_asset_invalid")
                return out
            }
            let read = p9ConsumeBundleEntry(root, entry[1], backend,
                64 * 1024, scanText: true)
            if (!read.contract.ok) { out.contract = read.contract; return out }
            var matched: Int64 = 0
            for (asset in before.manifest.assets) {
                if (asset.relativePath == path && asset.size == read.size &&
                    asset.sha256 == read.sha256) { matched += 1 }
            }
            if (matched != 1) {
                out.contract = p9BundleFailure("promotion_asset_invalid")
                return out
            }
            out.bytes.add(read.bytes)
        }
        let after = validateCkbReproBundleManifest(root, backend)
        if (!after.contract.ok || after.rootIdentity != before.rootIdentity ||
            after.manifest.inputSetHash != before.manifest.inputSetHash ||
            after.proofSetHash != before.proofSetHash) {
            out.contract = p9BundleFailure("promotion_bundle_changed")
            return out
        }
        out.loaded = before; out.contract = p9BundleSuccess(); out
    } catch (_: Exception) {
        out.contract = p9BundleFailure("promotion_asset_read_failed"); out
    }
}

private func p9PromotionOwnedRootValid(root: String,
    ownedRoot: String): Bool {
    if (!p9AbsoluteRoot(root) || !p9AbsoluteRoot(ownedRoot) ||
        p9RootsOverlap(root, ownedRoot) || exists(Path(ownedRoot))) {
        return false
    }
    let path = Path(ownedRoot)
    try {
        let parent = canonicalize(path.parent).toString()
        Path(parent).join(path.fileName).toString() == ownedRoot
    } catch (_: Exception) { false }
}

private func p9PromotionManifestAsset(manifest: CkbReproBundleManifest,
    path: String): (Bool, CkbReproBundleAsset) {
    var matched: Int64 = 0
    var value = CkbReproBundleAsset()
    for (asset in manifest.assets) {
        if (asset.relativePath == path) { matched += 1; value = asset }
    }
    (matched == 1, value)
}

private func p9PromotionReadSmallAsset(root: String, path: String,
    loaded: CkbReproBundleLoadResult,
    listing: ArrayList<CkbReproBundleReadEntry>,
    backend: CkbReproBundleReadBackend):
    (CkbReproContractResult, Array<UInt8>) {
    let entry = p9FindBundleReadEntry(listing, path)
    let asset = p9PromotionManifestAsset(loaded.manifest, path)
    if (!entry[0] || !asset[0] || entry[1].size > 64 * 1024) {
        return (p9BundleFailure("promotion_asset_invalid"), Array<UInt8>())
    }
    let read = p9ConsumeBundleEntry(root, entry[1], backend,
        64 * 1024, scanText: true)
    if (!read.contract.ok) { return (read.contract, Array<UInt8>()) }
    if (read.size != asset[1].size || read.sha256 != asset[1].sha256) {
        return (p9BundleFailure("promotion_asset_invalid"), Array<UInt8>())
    }
    (p9BundleSuccess(), read.bytes)
}

private func p9PromotionStreamAsset(root: String, path: String,
    ownedRoot: String, loaded: CkbReproBundleLoadResult,
    listing: ArrayList<CkbReproBundleReadEntry>,
    backend: CkbReproBundleReadBackend):
    (CkbReproContractResult, String, String) {
    let entry = p9FindBundleReadEntry(listing, path)
    let asset = p9PromotionManifestAsset(loaded.manifest, path)
    if (!entry[0] || !asset[0] || entry[1].kind != "regular") {
        return (p9BundleFailure("promotion_asset_invalid"), "", "")
    }
    let target = Path(ownedRoot).join(Path(path).fileName)
    try {
        let handle = backend.open(root, entry[1])
        try {
            if (!handle.noFollow()) {
                return (p9BundleFailure("bundle_read_no_follow_required"),
                    "", "")
            }
            let digest = SHA256()
            var size: Int64 = 0
            try (file = File(target, OpenMode.Write)) {
                let buffer = Array<UInt8>(65536, repeat: UInt8(0))
                while (true) {
                    let count = handle.read(buffer)
                    if (count < 0 || count > buffer.size) {
                        return (p9BundleFailure("bundle_read_failed"), "", "")
                    }
                    if (count == 0) { break }
                    let chunk = p9BundleBufferPrefix(buffer, count)
                    file.write(chunk); digest.write(chunk); size += count
                    if (size > asset[1].size) {
                        return (p9BundleFailure("bundle_asset_size_mismatch"),
                            "", "")
                    }
                }
            }
            let hash = p9BundleDigestHash(digest)
            if (size != asset[1].size || hash != asset[1].sha256 ||
                !p9BundleReadEntriesEqual(entry[1], handle.observedEntry())) {
                return (p9BundleFailure("bundle_read_entry_changed"), "", "")
            }
            (p9BundleSuccess(), target.toString(), hash)
        } finally { handle.close() }
    } catch (_: Exception) {
        (p9BundleFailure("promotion_asset_read_failed"), "", "")
    }
}

private func p9PromotionCleanupOwnedRoot(
    assets: CkbReproPromotionRuntimeAssets): Bool {
    if (assets.ownedRoot == "") { return true }
    try {
        if (exists(Path(assets.ownedRoot))) {
            remove(Path(assets.ownedRoot), recursive: true)
        }
        assets.ownedRoot = ""
        true
    } catch (_: Exception) { false }
}

public class CkbReproFinalizeInputs {
    public var ok: Bool = false
    public var diagnostic: String = "bundle_finalize_inputs_not_loaded"
    public var manifest: CkbReproBundleManifest = CkbReproBundleManifest()
    public var proofSetHash: String = ""
    public var releaseCommit: String = ""
    public init() {}
}

private class P9BundleStreamResult {
    public var contract: CkbReproContractResult = CkbReproContractResult()
    public var bytes: Array<UInt8> = Array<UInt8>()
    public var size: Int64 = 0
    public var sha256: String = ""
    public var observed: CkbReproBundleReadEntry = CkbReproBundleReadEntry()
    public init() {}
}

private class P9BundleContentScanner {
    private let textRequired: Bool
    private var utf8Remaining: Int64 = 0
    private var nextMinimum: UInt8 = 0x80
    private var nextMaximum: UInt8 = 0xbf
    private var firstContinuation: Bool = false
    private var invalidEncoding: Bool = false
    private var sensitive: Bool = false
    private var recent = ArrayList<UInt8>()
    public init(scanText: Bool) { this.textRequired = scanText }
    public func feed(bytes: Array<UInt8>): Unit {
        for (byte in bytes) {
            if (this.textRequired && !this.invalidEncoding) {
                this.validateUtf8Byte(byte)
            }
            if (this.recent.size >= 1024) {
                this.scanRecent()
                let tail = ArrayList<UInt8>()
                for (i in this.recent.size - 256..this.recent.size) {
                    tail.add(this.recent[i])
                }
                this.recent = tail
            }
            this.recent.add(if (byte < 0x80) { byte } else { UInt8(0x20) })
        }
        this.scanRecent()
    }
    private func scanRecent(): Unit {
        if (!this.sensitive &&
            !scanCkbPublicEvidenceLeakage(this.recent.toArray()).ok) {
            this.sensitive = true
        }
    }
    public func finish(): String {
        if (this.textRequired &&
            (this.invalidEncoding || this.utf8Remaining != 0)) {
            return "bundle_text_encoding_invalid"
        }
        if (this.sensitive) { return "bundle_sensitive_content_detected" }
        "ok"
    }
    private func validateUtf8Byte(byte: UInt8): Unit {
        if (this.utf8Remaining == 0) {
            if (byte < 0x80) { return }
            this.firstContinuation = true
            if (byte >= 0xc2 && byte <= 0xdf) {
                this.utf8Remaining = 1
                this.nextMinimum = 0x80; this.nextMaximum = 0xbf
            } else if (byte == 0xe0) {
                this.utf8Remaining = 2
                this.nextMinimum = 0xa0; this.nextMaximum = 0xbf
            } else if ((byte >= 0xe1 && byte <= 0xec) ||
                (byte >= 0xee && byte <= 0xef)) {
                this.utf8Remaining = 2
                this.nextMinimum = 0x80; this.nextMaximum = 0xbf
            } else if (byte == 0xed) {
                this.utf8Remaining = 2
                this.nextMinimum = 0x80; this.nextMaximum = 0x9f
            } else if (byte == 0xf0) {
                this.utf8Remaining = 3
                this.nextMinimum = 0x90; this.nextMaximum = 0xbf
            } else if (byte >= 0xf1 && byte <= 0xf3) {
                this.utf8Remaining = 3
                this.nextMinimum = 0x80; this.nextMaximum = 0xbf
            } else if (byte == 0xf4) {
                this.utf8Remaining = 3
                this.nextMinimum = 0x80; this.nextMaximum = 0x8f
            } else { this.invalidEncoding = true }
            return
        }
        if (byte < this.nextMinimum || byte > this.nextMaximum) {
            this.invalidEncoding = true
            return
        }
        this.utf8Remaining -= 1
        if (this.firstContinuation) {
            this.firstContinuation = false
            this.nextMinimum = 0x80; this.nextMaximum = 0xbf
        }
    }
}

public interface CkbReproBundleBackend {
    func rootExists(root: String): Bool
    func rootIsEmpty(root: String): Bool
    func createRoot(root: String): Bool
    func read(root: String, relativePath: String): Array<UInt8>
    func write(root: String, relativePath: String, bytes: Array<UInt8>): Bool
    func removeRoot(root: String): Bool
}

public interface CkbReproBundleReadBackend {
    func rootExists(root: String): Bool
    func rootIdentity(root: String): String
    func list(root: String): ArrayList<CkbReproBundleReadEntry>
    func open(root: String, expected: CkbReproBundleReadEntry):
        CkbReproBundleReadHandle
}

public interface CkbReproBundleReadHandle {
    func read(buffer: Array<UInt8>): Int64
    func observedEntry(): CkbReproBundleReadEntry
    func noFollow(): Bool
    func close(): Unit
}

public func parseCkbReproBundleCliArgs(args: Array<String>):
    CkbReproBundleCliOptions {
    let out = CkbReproBundleCliOptions()
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "ckb-repro-bundle") { i += 1; continue }
        if (arg == "--json") {
            if (out.json) { out.diagnostic = "duplicate_argument:--json"; return out }
            out.json = true; i += 1; continue
        }
        if (arg == "--mode" || arg == "--output" || arg == "--input-root" ||
            arg == "--unsigned-root" || arg == "--verification-report" ||
            arg == "--worktree-root" || arg == "--production-root" ||
            arg == "--private-run-root" || arg == "--user-config-root") {
            if (i + 1 >= args.size) { out.diagnostic = "missing_value:${arg}"; return out }
            let value = args[i + 1]
            if (value.toRuneArray().size > 4096) {
                out.diagnostic = "cli_argument_too_long"; return out
            }
            if (arg == "--mode") {
                if (out.mode != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.mode = value
            } else if (arg == "--output") {
                if (out.outputRoot != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.outputRoot = value
            } else if (arg == "--input-root") {
                if (out.inputRoot != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.inputRoot = value
            } else if (arg == "--unsigned-root") {
                if (out.unsignedRoot != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.unsignedRoot = value
            } else if (arg == "--verification-report") {
                if (out.verificationReport != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.verificationReport = value
            } else if (arg == "--worktree-root") {
                if (out.worktreeRoot != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.worktreeRoot = value
            } else if (arg == "--production-root") {
                if (out.productionRoot != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.productionRoot = value
            } else if (arg == "--private-run-root") {
                if (out.privateRunRoot != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.privateRunRoot = value
            } else {
                if (out.userConfigRoot != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.userConfigRoot = value
            }
            i += 2; continue
        }
        out.diagnostic = "unknown_argument:${arg}"; return out
    }
    if (out.mode != "unsigned" && out.mode != "finalize") {
        out.diagnostic = "bundle_mode_invalid"; return out
    }
    if (out.outputRoot == "" || out.worktreeRoot == "" ||
        out.productionRoot == "" || out.privateRunRoot == "" ||
        out.userConfigRoot == "") {
        out.diagnostic = "required_argument_missing"; return out
    }
    if (out.mode == "unsigned") {
        if (out.unsignedRoot != "" || out.verificationReport != "") {
            out.diagnostic = "bundle_unsigned_arguments_conflict"; return out
        }
        if (out.inputRoot == "") {
            out.diagnostic = "bundle_unsigned_input_root_missing"; return out
        }
    }
    if (out.mode == "finalize" &&
        (out.unsignedRoot == "" || out.verificationReport == "")) {
        out.diagnostic = "bundle_finalize_arguments_missing"; return out
    }
    out.valid = true; out.diagnostic = "ok"; out
}

public func validateCkbReproBundleCliOptions(options: CkbReproBundleCliOptions,
    context: CkbReproBundleCliPathContext,
    executor: CkbReproBundleCliExecutor): CkbReproContractResult {
    if (!options.valid) { return p9BundleFailure(options.diagnostic) }
    if (options.worktreeRoot != context.worktreeRoot ||
        options.productionRoot != context.productionRoot ||
        options.privateRunRoot != context.privateRunRoot ||
        options.userConfigRoot != context.userConfigRoot) {
        return p9BundleFailure("bundle_context_mismatch")
    }
    for (path in [options.outputRoot, context.worktreeRoot,
        context.productionRoot, context.privateRunRoot, context.userConfigRoot]) {
        if (!p9AbsoluteRoot(path)) { return p9BundleFailure("bundle_output_invalid") }
    }
    for (protected in [context.worktreeRoot, context.productionRoot,
        context.privateRunRoot, context.userConfigRoot]) {
        if (!executor.exists(protected)) {
            return p9BundleFailure("bundle_protected_root_missing")
        }
        if (p9RootsOverlap(options.outputRoot, protected)) {
            return p9BundleFailure("bundle_output_forbidden")
        }
    }
    let protected = [context.worktreeRoot, context.productionRoot,
        context.privateRunRoot, context.userConfigRoot]
    for (i in 0..protected.size) {
        for (j in (i + 1)..protected.size) {
            if (p9RootsOverlap(protected[i], protected[j])) {
                return p9BundleFailure("bundle_protected_roots_overlap")
            }
        }
    }
    if (executor.exists(options.outputRoot)) {
        return p9BundleFailure("bundle_output_exists")
    }
    if (!executor.outputParentExists(options.outputRoot)) {
        return p9BundleFailure("bundle_output_parent_missing")
    }
    if (options.mode == "finalize") {
        if (!p9AbsoluteRoot(options.unsignedRoot) ||
            !p9AbsoluteRoot(options.verificationReport)) {
            return p9BundleFailure("bundle_finalize_input_invalid")
        }
        if (p9RootsOverlap(options.outputRoot, options.unsignedRoot)) {
            return p9BundleFailure("bundle_unsigned_final_overlap")
        }
        if (!executor.exists(options.unsignedRoot)) {
            return p9BundleFailure("bundle_unsigned_root_missing")
        }
        if (!executor.exists(options.verificationReport)) {
            return p9BundleFailure("bundle_verification_report_missing")
        }
    } else if (options.inputRoot != "") {
        if (!p9AbsoluteRoot(options.inputRoot) ||
            p9RootsOverlap(options.outputRoot, options.inputRoot)) {
            return p9BundleFailure("bundle_input_root_invalid")
        }
        if (!executor.exists(options.inputRoot)) {
            return p9BundleFailure("bundle_input_root_missing")
        }
    }
    p9BundleSuccess()
}

public func executeCkbReproBundleCliAdapter(options: CkbReproBundleCliOptions,
    context: CkbReproBundleCliPathContext,
    executor: CkbReproBundleCliExecutor): CkbReproBundleResult {
    let checked = validateCkbReproBundleCliOptions(options, context, executor)
    if (!checked.ok) { return p9BundleCliFailure(checked.diagnostic) }
    let out = try {
        if (options.mode == "unsigned") {
            executor.assembleUnsigned(options)
        } else { executor.finalizeBundle(options) }
    } catch (_: Exception) { p9BundleCliFailure("bundle_execution_failed") }
    if (!out.ok) { _ = executor.cleanupOutput(options.outputRoot) }
    out
}

public func runCkbReproBundleCliAdapter(options: CkbReproBundleCliOptions,
    context: CkbReproBundleCliPathContext,
    assets: ArrayList<CkbReproBundleAsset>, expectedInputSetHash: String):
    CkbReproBundleResult {
    executeCkbReproBundleCliAdapter(options, context,
        CkbReproFilesystemBundleCliExecutor(assets, expectedInputSetHash))
}

public func runCkbReproBundleCliAdapter(options: CkbReproBundleCliOptions,
    context: CkbReproBundleCliPathContext): CkbReproBundleResult {
    executeCkbReproBundleCliAdapter(options, context,
        CkbReproProductionBundleCliExecutor())
}

public func runCkbReproBundleCliAdapter(options: CkbReproBundleCliOptions):
    CkbReproBundleResult {
    let context = CkbReproBundleCliPathContext()
    context.worktreeRoot = options.worktreeRoot
    context.productionRoot = options.productionRoot
    context.privateRunRoot = options.privateRunRoot
    context.userConfigRoot = options.userConfigRoot
    for (root in [context.worktreeRoot, context.productionRoot,
        context.privateRunRoot, context.userConfigRoot]) {
        let canonical = try { canonicalize(Path(root)).toString() }
            catch (_: Exception) {
                return p9BundleCliFailure("bundle_path_not_canonical")
            }
        if (canonical != root) {
            return p9BundleCliFailure("bundle_path_not_canonical")
        }
    }
    runCkbReproBundleCliAdapter(options, context)
}

public func renderCkbReproBundleCliHuman(result: CkbReproBundleResult): String {
    "bundle: ${if (result.ok) { "ready" } else { "blocked" }}\n" +
        "diagnostic: ${p9BundleCliSafe(result.diagnostic)}\n" +
        "assets: ${result.assetCount}\n" +
        "input set hash: ${result.inputSetHash}\n" +
        "tree hash: ${result.treeHash}\n"
}

public func renderCkbReproBundleCliJson(result: CkbReproBundleResult): String {
    "{\"ok\":${result.ok},\"diagnostic\":\"${p9BundleJson(p9BundleCliSafe(result.diagnostic))}\"," +
        "\"assetCount\":${result.assetCount},\"inputSetHash\":\"${p9BundleJson(result.inputSetHash)}\"," +
        "\"treeHash\":\"${p9BundleJson(result.treeHash)}\"}"
}

public func ckbReproBundleHash(bytes: Array<UInt8>): String {
    let digest = SHA256()
    digest.write(bytes)
    let builder = StringBuilder()
    for (byte in digest.finish()) {
        builder.append(p9BundleNibble(byte / UInt8(16)))
        builder.append(p9BundleNibble(byte % UInt8(16)))
    }
    "sha256:${builder.toString()}"
}

public func validateCkbReproBundleRelativePath(path: String):
    CkbReproContractResult {
    if (path == "" || path.startsWith("/") || path.endsWith("/") ||
        path.contains("\\") || path.contains("\n") || path.contains("\r") ||
        p9BundlePathHasControl(path) || path.contains("//") ||
        path == "." || path == ".." || path.startsWith("./") ||
        path.startsWith("../") || path.contains("/./") ||
        path.contains("/../") || path.endsWith("/.") || path.endsWith("/..")) {
        return p9BundleFailure("bundle_path_invalid")
    }
    if (path.startsWith("private-runs/") ||
        path.contains("/private-runs/")) {
        return p9BundleFailure("bundle_private_artifact_forbidden")
    }
    p9BundleSuccess()
}

public func validateCkbReproBundleRelativePathBytes(bytes: Array<UInt8>):
    CkbReproContractResult {
    let value = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return p9BundleFailure("invalid_response_encoding")
    }
    validateCkbReproBundleRelativePath(value)
}

public func validateCkbReproBundleAssets(assets: ArrayList<CkbReproBundleAsset>):
    CkbReproContractResult {
    if (assets.size > 995) {
        return p9BundleFailure("bundle_asset_count_exceeded")
    }
    let seen = HashSet<String>()
    for (asset in assets) {
        if (p9BundleDerivedPathForbidden(asset.relativePath) ||
            p9BundleDerivedPathForbidden(asset.logicalAsset)) {
            return p9BundleFailure("bundle_derived_asset_forbidden")
        }
        let path = validateCkbReproBundleRelativePath(asset.relativePath)
        if (!path.ok) { return path }
        if (seen.contains(asset.relativePath)) {
            return p9BundleFailure("bundle_asset_duplicate")
        }
        seen.add(asset.relativePath)
        if (asset.size < 0 || asset.size != asset.bytes.size ||
            asset.sha256 != ckbReproBundleHash(asset.bytes)) {
            return p9BundleFailure("bundle_asset_hash_mismatch")
        }
        let scanner = P9BundleContentScanner(!p9BundleBinaryAllowed(asset))
        scanner.feed(asset.bytes)
        let content = scanner.finish()
        if (content != "ok") { return p9BundleFailure(content) }
        if (asset.inputKind != "verified_input") {
            return p9BundleFailure("bundle_input_kind_invalid")
        }
    }
    p9ValidateBundleAssetMetadata(assets, true)
}

public func computeCkbReproBundleInputSetHash(
    assets: ArrayList<CkbReproBundleAsset>): String {
    let lines = ArrayList<String>()
    for (asset in assets) {
        lines.add(p9BundlePart(asset.relativePath) +
            p9BundlePart(asset.inputKind) + p9BundlePart(asset.size.toString()) +
            p9BundlePart(asset.sha256) + p9BundlePart(asset.role) +
            p9BundlePart(asset.logicalAsset) +
            p9BundlePart(asset.partIndex.toString()) +
            p9BundlePart(asset.partCount.toString()) +
            p9BundlePart(asset.logicalSize.toString()) +
            p9BundlePart(asset.logicalSha256))
    }
    let ordered = lines.toArray()
    sort(ordered)
    let builder = StringBuilder("ckb-repro-input-set-v1")
    for (line in ordered) { builder.append(p9BundlePart(line)) }
    ckbReproBundleHash(builder.toString().toArray())
}

public func writeCkbReproReleaseManifest(
    assets: ArrayList<CkbReproBundleAsset>): String {
    let manifest = CkbReproBundleManifest()
    manifest.schemaVersion = "ckb-repro-release-component-v1"
    manifest.inputSetHash = computeCkbReproBundleInputSetHash(assets)
    for (asset in assets) { manifest.assets.add(asset) }
    renderCkbReproBundleManifest(manifest)
}

public func renderCkbReproBundleManifest(
    manifest: CkbReproBundleManifest): String {
    let rows = ArrayList<String>()
    for (asset in manifest.assets) {
        rows.add(p9BundleCanonicalAssetRow(asset))
    }
    let ordered = rows.toArray()
    sort(ordered)
    "{\"schemaVersion\":\"${p9BundleJson(manifest.schemaVersion)}\"," +
        "\"inputSetHash\":\"${p9BundleJson(manifest.inputSetHash)}\"," +
        "\"assets\":[${p9BundleJoin(ordered, ",")}]}"
}

public func renderCkbReproReleaseInputsManifest(
    inputs: ArrayList<CkbReproReleaseInput>, releaseCommit: String,
    runCriticalTreeHash: String, certifiedRunInputHash: String,
    referenceManifestHash: String, authorityDeliveryMode: String,
    authorityLayoutHash: String): String {
    let rows = ArrayList<String>()
    for (input in inputs) {
        let asset = input.asset
        rows.add("{\"sourcePath\":\"${p9BundleJson(input.sourceRelativePath)}\"," +
            "\"path\":\"${p9BundleJson(asset.relativePath)}\"," +
            "\"size\":${asset.size},\"sha256\":\"${asset.sha256}\"," +
            "\"inputKind\":\"${p9BundleJson(asset.inputKind)}\"," +
            "\"role\":\"${p9BundleJson(asset.role)}\"," +
            "\"logicalAsset\":\"${p9BundleJson(asset.logicalAsset)}\"," +
            "\"partIndex\":${asset.partIndex},\"partCount\":${asset.partCount}," +
            "\"logicalSize\":${asset.logicalSize}," +
            "\"logicalSha256\":\"${asset.logicalSha256}\"}")
    }
    let ordered = rows.toArray(); sort(ordered)
    "{\"schemaVersion\":\"ckb-repro-release-inputs-v1\"," +
        "\"releaseCommit\":\"${p9BundleJson(releaseCommit)}\"," +
        "\"runCriticalTreeHash\":\"${p9BundleJson(runCriticalTreeHash)}\"," +
        "\"certifiedRunInputHash\":\"${p9BundleJson(certifiedRunInputHash)}\"," +
        "\"referenceManifestHash\":\"${p9BundleJson(referenceManifestHash)}\"," +
        "\"authorityDeliveryMode\":\"${p9BundleJson(authorityDeliveryMode)}\"," +
        "\"authorityLayoutHash\":\"${p9BundleJson(authorityLayoutHash)}\"," +
        "\"inputs\":[${p9BundleJoin(ordered, ",")}]}"
}

private func p9ParseReleaseInputs(bytes: Array<UInt8>):
    CkbReproReleaseInputsLoadResult {
    let out = CkbReproReleaseInputsLoadResult()
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        out.contract = p9BundleFailure("invalid_response_encoding"); return out
    }
    try {
        let object = JsonValue.fromStr(text).asObject()
        if (object.size() != 8 ||
            p9BundleString(object, "schemaVersion") !=
                "ckb-repro-release-inputs-v1") {
            out.contract = p9BundleFailure("bundle_release_inputs_invalid")
            return out
        }
        out.releaseCommit = p9BundleString(object, "releaseCommit")
        out.runCriticalTreeHash = p9BundleString(object, "runCriticalTreeHash")
        out.certifiedRunInputHash = p9BundleString(object,
            "certifiedRunInputHash")
        out.referenceManifestHash = p9BundleString(object,
            "referenceManifestHash")
        out.authorityDeliveryMode = p9BundleString(object,
            "authorityDeliveryMode")
        out.authorityLayoutHash = p9BundleString(object,
            "authorityLayoutHash")
        for (value in object.get("inputs").getOrThrow().asArray().getItems()) {
            let row = value.asObject()
            if (row.size() != 11) {
                out.contract = p9BundleFailure("bundle_release_inputs_invalid")
                return out
            }
            let input = CkbReproReleaseInput()
            input.sourceRelativePath = p9BundleString(row, "sourcePath")
            let asset = input.asset
            asset.relativePath = p9BundleString(row, "path")
            asset.size = p9BundleInt(row, "size")
            asset.sha256 = p9BundleString(row, "sha256")
            asset.inputKind = p9BundleString(row, "inputKind")
            asset.role = p9BundleString(row, "role")
            asset.logicalAsset = p9BundleString(row, "logicalAsset")
            asset.partIndex = p9BundleInt(row, "partIndex")
            asset.partCount = p9BundleInt(row, "partCount")
            asset.logicalSize = p9BundleInt(row, "logicalSize")
            asset.logicalSha256 = p9BundleString(row, "logicalSha256")
            out.inputs.add(input); out.manifest.assets.add(asset)
        }
    } catch (_: Exception) {
        out.contract = p9BundleFailure("bundle_release_inputs_invalid")
        return out
    }
    if (renderCkbReproReleaseInputsManifest(out.inputs, out.releaseCommit,
        out.runCriticalTreeHash, out.certifiedRunInputHash,
        out.referenceManifestHash, out.authorityDeliveryMode,
        out.authorityLayoutHash) != text ||
        !p9BundleCommit(out.releaseCommit) ||
        !p9BundleHashValid(out.runCriticalTreeHash) ||
        !p9BundleHashValid(out.certifiedRunInputHash) ||
        !p9BundleHashValid(out.referenceManifestHash)) {
        out.contract = p9BundleFailure("bundle_release_inputs_invalid")
        return out
    }
    let sources = HashSet<String>(); let targets = HashSet<String>()
    let evidence = ArrayList<CkbReproReleaseAuthorityEvidence>()
    for (input in out.inputs) {
        if (!validateCkbReproBundleRelativePath(input.sourceRelativePath).ok ||
            input.sourceRelativePath == "RELEASE-INPUTS.json" ||
            !validateCkbReproBundleRelativePath(input.asset.relativePath).ok ||
            sources.contains(input.sourceRelativePath) ||
            targets.contains(input.asset.relativePath) ||
            input.asset.size < 0 || !p9BundleHashValid(input.asset.sha256) ||
            input.asset.inputKind != "verified_input") {
            out.contract = p9BundleFailure("bundle_release_inputs_invalid")
            return out
        }
        sources.add(input.sourceRelativePath)
        targets.add(input.asset.relativePath)
        let row = CkbReproReleaseAuthorityEvidence()
        row.role = input.asset.role
        row.logicalAsset = input.asset.logicalAsset
        row.size = input.asset.size; row.sha256 = input.asset.sha256
        evidence.add(row)
    }
    let metadata = p9ValidateBundleAssetMetadata(out.manifest.assets, false)
    if (!metadata.ok) { out.contract = metadata; return out }
    let authority = buildCkbReproReleaseAuthorityContract(evidence,
        out.authorityDeliveryMode)
    if (!authority[0].ok ||
        authority[1].layoutHash != out.authorityLayoutHash) {
        out.contract = p9BundleFailure("bundle_release_authority_mismatch")
        return out
    }
    out.manifest.schemaVersion = "ckb-repro-release-component-v1"
    out.manifest.inputSetHash =
        computeCkbReproBundleInputSetHash(out.manifest.assets)
    out.manifestBytes = bytes
    out.contract = p9BundleSuccess(); out
}

public func parseCkbReproReleaseInputsManifest(bytes: Array<UInt8>):
    CkbReproReleaseInputsLoadResult {
    if (bytes.size <= 0 || bytes.size > 16 * 1024 * 1024) {
        let out = CkbReproReleaseInputsLoadResult()
        out.contract = p9BundleFailure("bundle_release_inputs_invalid")
        return out
    }
    p9ParseReleaseInputs(bytes)
}

public func parseCkbReproBundleManifest(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbReproBundleManifest) {
    let manifest = CkbReproBundleManifest()
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (p9BundleFailure("invalid_response_encoding"), manifest)
    }
    let value = try { JsonValue.fromStr(text) } catch (_: Exception) {
        return (p9BundleFailure("malformed_json"), manifest)
    }
    try {
        let object = value.asObject()
        if (object.size() != 3) {
            return (p9BundleFailure(
                "bundle_manifest_field_contract_invalid"), manifest)
        }
        manifest.schemaVersion = p9BundleString(object, "schemaVersion")
        manifest.inputSetHash = p9BundleString(object, "inputSetHash")
        for (value in object.get("assets").getOrThrow().asArray().getItems()) {
            let row = value.asObject()
            if (row.size() != 10) {
                return (p9BundleFailure(
                    "bundle_manifest_asset_contract_invalid"),
                    CkbReproBundleManifest())
            }
            let asset = CkbReproBundleAsset()
            asset.relativePath = p9BundleString(row, "path")
            let path = validateCkbReproBundleRelativePath(asset.relativePath)
            if (!path.ok) {
                return (path, CkbReproBundleManifest())
            }
            asset.size = p9BundleInt(row, "size")
            asset.sha256 = p9BundleString(row, "sha256")
            asset.inputKind = p9BundleString(row, "inputKind")
            asset.role = p9BundleString(row, "role")
            asset.logicalAsset = p9BundleString(row, "logicalAsset")
            asset.partIndex = p9BundleInt(row, "partIndex")
            asset.partCount = p9BundleInt(row, "partCount")
            asset.logicalSize = p9BundleInt(row, "logicalSize")
            asset.logicalSha256 = p9BundleString(row, "logicalSha256")
            manifest.assets.add(asset)
        }
    } catch (_: Exception) {
        return (p9BundleFailure(
            "bundle_manifest_field_contract_invalid"),
            CkbReproBundleManifest())
    }
    if (renderCkbReproBundleManifest(manifest) != text) {
        return (p9BundleFailure("bundle_manifest_non_canonical"),
            CkbReproBundleManifest())
    }
    (p9BundleSuccess(), manifest)
}

public func validateCkbReproBundleManifest(root: String,
    backend: CkbReproBundleReadBackend): CkbReproBundleLoadResult {
    let out = CkbReproBundleLoadResult()
    if (!p9AbsoluteRoot(root)) {
        out.contract = p9BundleFailure("bundle_root_invalid")
        return out
    }
    try {
        if (!backend.rootExists(root)) {
            out.contract = p9BundleFailure("bundle_root_missing")
            return out
        }
        let rootIdentity = backend.rootIdentity(root)
        if (rootIdentity == "") {
            out.contract = p9BundleFailure("bundle_root_identity_invalid")
            return out
        }
        let firstListing = backend.list(root)
        let firstSafe = p9ValidateBundleReadListing(root, firstListing)
        if (!firstSafe.ok) { out.contract = firstSafe; return out }
        let manifestEntry = p9FindBundleReadEntry(
            firstListing, "RELEASE-MANIFEST.json")
        if (!manifestEntry[0]) {
            for (entry in firstListing) {
                if (entry.kind == "directory") {
                    out.contract = p9BundleFailure(
                        "bundle_root_entry_type_invalid")
                    return out
                }
            }
            out.contract = p9BundleFailure("bundle_manifest_missing")
            return out
        }
        if (manifestEntry[1].size > 16 * 1024 * 1024) {
            out.contract = p9BundleFailure("bundle_manifest_size_exceeded")
            return out
        }
        let manifestRead = p9ConsumeBundleEntry(
            root, manifestEntry[1], backend, 16 * 1024 * 1024)
        if (!manifestRead.contract.ok) {
            out.contract = manifestRead.contract
            return out
        }
        let manifestBytes = manifestRead.bytes
        let parsed = parseCkbReproBundleManifest(manifestBytes)
        if (!parsed[0].ok) { out.contract = parsed[0]; return out }
        let structure = p9ValidateBundleManifestStructure(parsed[1])
        if (!structure.ok) { out.contract = structure; return out }
        let coverage = p9ValidateBundleReadCoverage(parsed[1], firstListing)
        if (!coverage.ok) { out.contract = coverage; return out }
        for (asset in parsed[1].assets) {
            let entry = p9FindBundleReadEntry(
                firstListing, asset.relativePath)
            if (!entry[0] || entry[1].size != asset.size) {
                out.contract = p9BundleFailure("bundle_asset_size_mismatch")
                return out
            }
            let assetRead = p9ConsumeBundleEntry(root, entry[1], backend, 0,
                scanText: !p9BundleBinaryAllowed(asset))
            if (!assetRead.contract.ok) {
                out.contract = assetRead.contract
                return out
            }
            let actualHash = assetRead.sha256
            if (actualHash != asset.sha256) {
                out.contract = p9BundleFailure("bundle_asset_hash_mismatch")
                return out
            }
            let proof = CkbReproBundleAssetProof()
            proof.relativePath = asset.relativePath
            proof.size = asset.size
            proof.sha256 = actualHash
            proof.identity = assetRead.observed.identity
            proof.proofHash = p9BundleAssetProofHash(proof)
            out.assetProofs.add(proof)
        }
        let logical = p9ValidateMultipartContent(root, parsed[1],
            firstListing, backend)
        if (!logical.ok) { out.contract = logical; return out }
        let manifestReadAfterAssets = p9ConsumeBundleEntry(
            root, manifestEntry[1], backend, 16 * 1024 * 1024)
        if (!manifestReadAfterAssets.contract.ok) {
            out.contract = manifestReadAfterAssets.contract
            return out
        }
        let manifestBytesAfterAssets = manifestReadAfterAssets.bytes
        if (manifestBytesAfterAssets != manifestBytes) {
            out.contract = p9BundleFailure("bundle_manifest_bytes_changed")
            return out
        }
        let secondListing = backend.list(root)
        let secondSafe = p9ValidateBundleReadListing(root, secondListing)
        if (!secondSafe.ok) { out.contract = secondSafe; return out }
        if (p9BundleReadSnapshotHash(firstListing) !=
            p9BundleReadSnapshotHash(secondListing)) {
            out.contract = p9BundleFailure("bundle_root_listing_changed")
            return out
        }
        if (backend.rootIdentity(root) != rootIdentity) {
            out.contract = p9BundleFailure("bundle_root_identity_changed")
            return out
        }
        out.manifest = parsed[1]
        // Proofs bind this two-list snapshot only. A later consumer must
        // re-list and re-read each asset before using its bytes.
        out.proofSetHash = p9BundleProofSetHash(out.assetProofs)
        out.rootIdentity = rootIdentity
        out.contract = p9BundleSuccess()
        out.contract.canonicalJson =
            renderCkbReproBundleManifest(parsed[1])
        out.contract.manifestHash = ckbReproBundleHash(manifestBytes)
        out
    } catch (_: Exception) {
        out.contract = p9BundleFailure("bundle_read_failed")
        out
    }
}

public func validateCkbReproBundleAssetsStreaming(root: String,
    manifest: CkbReproBundleManifest,
    backend: CkbReproBundleReadBackend): CkbReproContractResult {
    let structure = p9ValidateBundleManifestStructure(manifest)
    if (!structure.ok) { return structure }
    let listing = try { backend.list(root) } catch (_: Exception) {
        return p9BundleFailure("bundle_read_failed")
    }
    let safe = p9ValidateBundleReadListing(root, listing)
    if (!safe.ok) { return safe }
    for (asset in manifest.assets) {
        let entry = p9FindBundleReadEntry(listing, asset.relativePath)
        if (!entry[0] || entry[1].kind != "regular" ||
            entry[1].size != asset.size) {
            return p9BundleFailure("bundle_asset_size_mismatch")
        }
        let streamed = p9ConsumeBundleEntry(root, entry[1], backend, 0,
            scanText: !p9BundleBinaryAllowed(asset))
        if (!streamed.contract.ok) { return streamed.contract }
        if (streamed.sha256 != asset.sha256) {
            return p9BundleFailure("bundle_asset_hash_mismatch")
        }
    }
    p9ValidateMultipartContent(root, manifest, listing, backend)
}

public func loadCkbReproFinalizeInputs(unsignedRoot: String,
    reportBytes: Array<UInt8>, backend: CkbReproBundleReadBackend):
    CkbReproFinalizeInputs {
    let out = CkbReproFinalizeInputs()
    let loaded = validateCkbReproBundleManifest(unsignedRoot, backend)
    if (!loaded.contract.ok) {
        out.diagnostic = loaded.contract.diagnostic
        return out
    }
    let text = try { String.fromUtf8(reportBytes) } catch (_: Exception) {
        out.diagnostic = "invalid_response_encoding"; return out
    }
    try {
        let object = JsonValue.fromStr(text).asObject()
        if (object.size() != 19 ||
            !p9BundleBool(object, "ok") ||
            p9BundleString(object, "diagnostic") != "verified" ||
            p9BundleString(object, "verifiedReleaseInputSetHash") !=
                loaded.manifest.inputSetHash ||
            p9BundleString(object, "bundleProofSetHash") !=
                loaded.proofSetHash ||
            !p9BundleBool(object, "restoreOk") ||
            !p9BundleBool(object, "rebuildOk") ||
            !p9BundleBool(object, "publicEvidenceOk") ||
            !p9BundleBool(object, "documentationOk") ||
            p9BundleInt(object, "runnerCalls") != 0) {
            out.diagnostic = "bundle_verification_report_mismatch"
            return out
        }
        let commit = p9BundleString(object, "releaseCommit")
        if (!p9BundleCommit(commit)) {
            out.diagnostic = "bundle_verification_report_mismatch"
            return out
        }
        out.ok = true
        out.diagnostic = "ok"
        out.manifest = loaded.manifest
        out.proofSetHash = loaded.proofSetHash
        out.releaseCommit = commit
        out
    } catch (_: Exception) {
        out.diagnostic = "bundle_verification_report_malformed"
        out
    }
}

public func writeCkbReproSha256Sums(
    assets: ArrayList<CkbReproBundleAsset>): String {
    let rows = ArrayList<String>()
    for (asset in assets) {
        rows.add("${asset.sha256.replace("sha256:", "")}  ${asset.relativePath}")
    }
    let ordered = rows.toArray()
    sort(ordered)
    if (ordered.size == 0) { return "" }
    p9BundleJoin(ordered, "\n") + "\n"
}

public func buildCkbReproBuildAttestation(reportBytes: Array<UInt8>,
    manifestBytes: Array<UInt8>): (CkbReproContractResult, String) {
    let failed = p9BundleFailure("bundle_build_attestation_invalid")
    let parsedReport = parseCkbReproVerificationReport(reportBytes)
    if (!parsedReport[0].ok ||
        !validateCkbReproVerificationReport(parsedReport[1]).ok) {
        return (failed, "")
    }
    let report = parsedReport[1]
    let parsedManifest = parseCkbReproBundleManifest(manifestBytes)
    if (!parsedManifest[0].ok) { return (failed, "") }
    if (report.verifiedReleaseInputSetHash != parsedManifest[1].inputSetHash) {
        return (failed, "")
    }
    let text = "{\"schemaVersion\":\"ckb-repro-build-attestation-v2\"," +
        "\"verificationReportHash\":\"${ckbReproBundleHash(reportBytes)}\"," +
        "\"releaseManifestHash\":\"${ckbReproBundleHash(manifestBytes)}\"," +
        "\"verifiedReleaseInputSetHash\":\"${p9BundleJson(report.verifiedReleaseInputSetHash)}\"," +
        "\"bundleProofSetHash\":\"${p9BundleJson(report.bundleProofSetHash)}\"," +
        "\"releaseCommit\":\"${p9BundleJson(report.releaseCommit)}\"," +
        "\"runCriticalTreeHash\":\"${p9BundleJson(report.runCriticalTreeHash)}\"," +
        "\"referenceManifestHash\":\"${p9BundleJson(report.referenceManifestHash)}\"}"
    let ok = p9BundleSuccess(); ok.canonicalJson = text
    (ok, text)
}

public func validateCkbReproBuildAttestation(
    attestationBytes: Array<UInt8>, reportBytes: Array<UInt8>,
    manifestBytes: Array<UInt8>): CkbReproContractResult {
    let expected = buildCkbReproBuildAttestation(reportBytes, manifestBytes)
    if (!expected[0].ok) { return expected[0] }
    let actual = try { String.fromUtf8(attestationBytes) }
        catch (_: Exception) {
            return p9BundleFailure("bundle_build_attestation_invalid_encoding")
        }
    if (actual != expected[1]) {
        return p9BundleFailure("bundle_build_attestation_mismatch")
    }
    expected[0]
}

private func p9BundleFinalShaSums(manifest: CkbReproBundleManifest,
    manifestBytes: Array<UInt8>, reportBytes: Array<UInt8>,
    attestationBytes: Array<UInt8>): String {
    let rows = ArrayList<String>()
    for (asset in manifest.assets) {
        rows.add("${asset.sha256.replace("sha256:", "")}  ${asset.relativePath}")
    }
    for (item in [
        ("RELEASE-MANIFEST.json", manifestBytes),
        ("verification-report.json", reportBytes),
        ("build-attestation.json", attestationBytes)]) {
        rows.add("${ckbReproBundleHash(item[1]).replace("sha256:", "")}  ${item[0]}")
    }
    let ordered = rows.toArray(); sort(ordered)
    p9BundleJoin(ordered, "\n") + "\n"
}

public func planCkbReproAssetParts(relativePath: String,
    size: Int64): ArrayList<CkbReproAssetPart> {
    let out = ArrayList<CkbReproAssetPart>()
    let limit: Int64 = 1024 * 1024 * 1024
    if (size < 2 * limit) {
        let part = CkbReproAssetPart()
        part.relativePath = relativePath
        part.size = if (size < 0) { 0 } else { size }
        out.add(part)
        return out
    }
    var offset: Int64 = 0
    var index: Int64 = 0
    while (offset < size) {
        let part = CkbReproAssetPart()
        part.offset = offset
        part.size = if (size - offset > limit) { limit } else { size - offset }
        part.relativePath =
            "${relativePath}.part-${p9BundlePartIndex(index + 1)}"
        out.add(part)
        offset += part.size
        index += 1
    }
    out
}

public func assembleCkbUnsignedReleaseCandidate(options: CkbReproBundleOptions,
    assets: ArrayList<CkbReproBundleAsset>, backend: CkbReproBundleBackend):
    CkbReproBundleResult {
    let out = CkbReproBundleResult()
    let assetValidation = validateCkbReproBundleAssets(assets)
    if (!assetValidation.ok) {
        out.diagnostic = assetValidation.diagnostic
        return out
    }
    let rootValidation = p9ValidateOutputRoot(options)
    if (!rootValidation.ok) {
        out.diagnostic = rootValidation.diagnostic
        return out
    }
    if (backend.rootExists(options.outputRoot)) {
        out.diagnostic = "bundle_output_exists"
        return out
    }
    if (!backend.createRoot(options.outputRoot)) {
        out.diagnostic = "bundle_output_create_failed"
        return out
    }
    for (asset in assets) {
        if (!backend.write(options.outputRoot, asset.relativePath, asset.bytes) ||
            backend.read(options.outputRoot, asset.relativePath) != asset.bytes) {
            _ = backend.removeRoot(options.outputRoot)
            out.diagnostic = "bundle_asset_copy_failed"
            return out
        }
    }
    out.inputSetHash = computeCkbReproBundleInputSetHash(assets)
    out.treeHash = ckbReproBundleHash(
        (writeCkbReproReleaseManifest(assets) +
            writeCkbReproSha256Sums(assets)).toArray())
    out.assetCount = assets.size
    out.ok = true
    out.diagnostic = "component_ready"
    out
}

public func finalizeCkbReproReleaseBundle(options: CkbReproBundleOptions,
    assets: ArrayList<CkbReproBundleAsset>, expectedInputSetHash: String,
    backend: CkbReproBundleBackend): CkbReproBundleResult {
    if (computeCkbReproBundleInputSetHash(assets) != expectedInputSetHash) {
        let out = CkbReproBundleResult()
        out.diagnostic = "bundle_verified_input_changed"
        return out
    }
    assembleCkbUnsignedReleaseCandidate(options, assets, backend)
}

private func p9ValidateOutputRoot(options: CkbReproBundleOptions):
    CkbReproContractResult {
    if (!p9AbsoluteRoot(options.outputRoot)) {
        return p9BundleFailure("bundle_output_invalid")
    }
    for (protected in [options.worktreeRoot, options.productionRoot,
        options.privateRunRoot, options.userConfigRoot]) {
        if (!p9AbsoluteRoot(protected) ||
            p9RootsOverlap(options.outputRoot, protected)) {
            return p9BundleFailure("bundle_output_forbidden")
        }
    }
    p9BundleSuccess()
}

private func p9AbsoluteRoot(value: String): Bool {
    value.startsWith("/") && value != "/" && !value.endsWith("/") &&
        !value.contains("//") && !value.contains("/./") &&
        !value.contains("/../") && !value.endsWith("/.") &&
        !value.endsWith("/..") && !value.contains("\\") &&
        !value.contains("\n") && !value.contains("\r") &&
        !value.contains("\t")
}

private func p9RootsOverlap(left: String, right: String): Bool {
    left == right || left.startsWith(right + "/") || right.startsWith(left + "/")
}

private func p9BundlePart(value: String): String {
    "${value.toArray().size}:${value}"
}

private func p9BundleJoin(values: Array<String>, separator: String): String {
    let builder = StringBuilder()
    for (i in 0..values.size) {
        if (i > 0) { builder.append(separator) }
        builder.append(values[i])
    }
    builder.toString()
}

private func p9BundlePartIndex(index: Int64): String {
    if (index < 10) { return "000${index}" }
    if (index < 100) { return "00${index}" }
    if (index < 1000) { return "0${index}" }
    index.toString()
}

private func p9BundleCanonicalAssetRow(
    asset: CkbReproBundleAsset): String {
    "{\"path\":\"${p9BundleJson(asset.relativePath)}\"," +
        "\"size\":${asset.size},\"sha256\":\"${asset.sha256}\"," +
        "\"inputKind\":\"${p9BundleJson(asset.inputKind)}\"," +
        "\"role\":\"${p9BundleJson(asset.role)}\"," +
        "\"logicalAsset\":\"${p9BundleJson(asset.logicalAsset)}\"," +
        "\"partIndex\":${asset.partIndex},\"partCount\":${asset.partCount}," +
        "\"logicalSize\":${asset.logicalSize}," +
        "\"logicalSha256\":\"${asset.logicalSha256}\"}"
}

private func p9BundleRoleAllowed(role: String): Bool {
    for (allowed in ["p0_manifest", "p1_score_contract",
        "p2_logical_snapshot", "p3_qdrant_snapshot", "p4_build_proof",
        "p5_public_evidence", "p6_environment_lock", "p7_documentation",
        "p8_reference", "source_lock", "authority_delivery",
        "full_test_clean_log", "full_test_build_log",
        "full_test_test_log", "full_test_topology", "full_test_runner",
        "full_test_source",
        "portable_report", "license", "release_commit"]) {
        if (role == allowed) { return true }
    }
    false
}

private func p9BundleBinaryAllowed(asset: CkbReproBundleAsset): Bool {
    if (asset.role != "p2_logical_snapshot" &&
        asset.role != "p3_qdrant_snapshot" &&
        asset.role != "authority_delivery") { return false }
    let path = asset.logicalAsset.toAsciiLower()
    path.endsWith(".bin") || path.endsWith(".snapshot") ||
        path.endsWith(".tar") || path.endsWith(".tar.gz") ||
        path.endsWith(".gz") || path.endsWith(".zst") ||
        path.endsWith(".zip") || path.endsWith(".ckb-release")
}

private func p9BundleDerivedPathForbidden(path: String): Bool {
    path == "RELEASE-MANIFEST.json" ||
        path.endsWith("/RELEASE-MANIFEST.json") ||
        path == "SHA256SUMS" || path.endsWith("/SHA256SUMS") ||
        path == "SHA256SUMS.sig" || path.endsWith("/SHA256SUMS.sig") ||
        path == "build-attestation.json" ||
        path.endsWith("/build-attestation.json") ||
        path == "verification-report.json" ||
        path.endsWith("/verification-report.json") ||
        path.endsWith(".sig")
}

private func p9ValidateBundleAssetMetadata(
    assets: ArrayList<CkbReproBundleAsset>, verifyBytes: Bool):
    CkbReproContractResult {
    let checked = HashSet<String>()
    for (asset in assets) {
        if (!p9BundleRoleAllowed(asset.role)) {
            if (asset.role == "p8_verification_report") {
                return p9BundleFailure("bundle_derived_asset_forbidden")
            }
            return p9BundleFailure("bundle_asset_role_invalid")
        }
        let logicalPath = validateCkbReproBundleRelativePath(asset.logicalAsset)
        if (!logicalPath.ok) { return logicalPath }
        if (asset.partCount <= 0 || asset.partIndex < 0 ||
            asset.partIndex >= asset.partCount || asset.logicalSize < 0 ||
            !p9BundleHashValid(asset.logicalSha256)) {
            return p9BundleFailure("bundle_asset_parts_incomplete")
        }
        let group = asset.role + "\t" + asset.logicalAsset
        if (checked.contains(group)) { continue }
        checked.add(group)
        var total: Int64 = 0
        for (index in 0..asset.partCount) {
            var found = false
            for (part in assets) {
                if (part.role == asset.role &&
                    part.logicalAsset == asset.logicalAsset &&
                    part.partIndex == index && part.partCount == asset.partCount &&
                    part.logicalSize == asset.logicalSize &&
                    part.logicalSha256 == asset.logicalSha256) {
                    if (found) {
                        return p9BundleFailure("bundle_asset_parts_incomplete")
                    }
                    found = true
                    total += part.size
                }
            }
            if (!found) {
                return p9BundleFailure("bundle_asset_parts_incomplete")
            }
        }
        var groupCount: Int64 = 0
        for (part in assets) {
            if (part.role == asset.role &&
                part.logicalAsset == asset.logicalAsset) { groupCount += 1 }
        }
        if (groupCount != asset.partCount || total != asset.logicalSize) {
            return p9BundleFailure("bundle_asset_parts_incomplete")
        }
        if (asset.partCount == 1) {
            if (asset.logicalAsset != asset.relativePath ||
                asset.logicalSize != asset.size ||
                asset.logicalSha256 != asset.sha256 ||
                asset.logicalSize >= 2 * 1024 * 1024 * 1024) {
                return p9BundleFailure("bundle_asset_parts_incomplete")
            }
        } else {
            if (asset.logicalSize < 2 * 1024 * 1024 * 1024) {
                return p9BundleFailure("bundle_asset_parts_incomplete")
            }
            for (part in assets) {
                if (part.role != asset.role ||
                    part.logicalAsset != asset.logicalAsset) { continue }
                let expectedPath = "${part.logicalAsset}.part-" +
                    p9BundlePartIndex(part.partIndex + 1)
                let limit: Int64 = 1024 * 1024 * 1024
                if (part.relativePath != expectedPath || part.size <= 0 ||
                    part.size > limit ||
                    (asset.logicalSize >= 2 * limit &&
                    part.partIndex < part.partCount - 1 &&
                    part.size != limit)) {
                    return p9BundleFailure("bundle_asset_parts_incomplete")
                }
            }
        }
        if (asset.partCount > 1 && verifyBytes) {
            let digest = SHA256()
            for (index in 0..asset.partCount) {
                for (part in assets) {
                    if (part.role == asset.role &&
                        part.logicalAsset == asset.logicalAsset &&
                        part.partIndex == index) { digest.write(part.bytes) }
                }
            }
            if (p9BundleDigestHash(digest) != asset.logicalSha256) {
                return p9BundleFailure("bundle_asset_hash_mismatch")
            }
        }
    }
    p9BundleSuccess()
}

private func p9ValidateBundleManifestStructure(
    manifest: CkbReproBundleManifest): CkbReproContractResult {
    if (manifest.schemaVersion != "ckb-repro-release-component-v1") {
        return p9BundleFailure("bundle_manifest_schema_invalid")
    }
    if (manifest.assets.size > 995) {
        return p9BundleFailure("bundle_asset_count_exceeded")
    }
    let declared = HashSet<String>()
    var previousKey = ""
    for (asset in manifest.assets) {
        let path = validateCkbReproBundleRelativePath(asset.relativePath)
        if (!path.ok) { return path }
        if (p9BundleDerivedPathForbidden(asset.relativePath) ||
            p9BundleDerivedPathForbidden(asset.logicalAsset)) {
            return p9BundleFailure("bundle_derived_asset_forbidden")
        }
        if (declared.contains(asset.relativePath)) {
            return p9BundleFailure("bundle_asset_duplicate")
        }
        let key = p9BundleCanonicalAssetRow(asset)
        if (previousKey != "" && previousKey > key) {
            return p9BundleFailure("bundle_manifest_asset_order_invalid")
        }
        if (asset.size < 0 || !p9BundleHashValid(asset.sha256)) {
            return p9BundleFailure("bundle_manifest_asset_contract_invalid")
        }
        if (asset.inputKind != "verified_input") {
            return p9BundleFailure("bundle_input_kind_invalid")
        }
        declared.add(asset.relativePath)
        previousKey = key
    }
    if (computeCkbReproBundleInputSetHash(manifest.assets) !=
        manifest.inputSetHash) {
        return p9BundleFailure("bundle_input_set_hash_mismatch")
    }
    p9ValidateBundleAssetMetadata(manifest.assets, false)
}

private func p9ValidateBundleReadListing(root: String,
    listing: ArrayList<CkbReproBundleReadEntry>): CkbReproContractResult {
    let seen = HashSet<String>()
    for (entry in listing) {
        if (entry.kind != "regular" && entry.kind != "directory") {
            return p9BundleFailure("bundle_root_entry_type_invalid")
        }
        let path = validateCkbReproBundleRelativePath(entry.relativePath)
        if (!path.ok) { return path }
        if (!entry.withinRoot ||
            entry.canonicalPath != "${root}/${entry.relativePath}") {
            return p9BundleFailure("bundle_root_entry_outside")
        }
        if (entry.identity == "" || entry.size < 0) {
            return p9BundleFailure("bundle_root_entry_identity_invalid")
        }
        if (seen.contains(entry.relativePath)) {
            return p9BundleFailure("bundle_root_asset_duplicate")
        }
        seen.add(entry.relativePath)
    }
    p9BundleSuccess()
}

private func p9ValidateBundleReadCoverage(
    manifest: CkbReproBundleManifest,
    listing: ArrayList<CkbReproBundleReadEntry>): CkbReproContractResult {
    let declared = HashSet<String>()
    let requiredDirectories = HashSet<String>()
    for (asset in manifest.assets) {
        declared.add(asset.relativePath)
        let parts = asset.relativePath.split("/")
        let parent = StringBuilder()
        for (i in 0..parts.size - 1) {
            if (i > 0) { parent.append("/") }
            parent.append(parts[i])
            requiredDirectories.add(parent.toString())
        }
    }
    let listed = HashSet<String>()
    let listedDirectories = HashSet<String>()
    var hasManifest = false
    for (entry in listing) {
        listed.add(entry.relativePath)
        if (entry.kind == "directory") {
            if (declared.contains(entry.relativePath)) {
                return p9BundleFailure("bundle_root_entry_type_invalid")
            }
            listedDirectories.add(entry.relativePath)
            if (!requiredDirectories.contains(entry.relativePath)) {
                return p9BundleFailure("bundle_root_extra_asset")
            }
        } else if (entry.relativePath == "RELEASE-MANIFEST.json") {
            hasManifest = true
        } else if (!declared.contains(entry.relativePath)) {
            return p9BundleFailure("bundle_root_extra_asset")
        }
    }
    if (!hasManifest) {
        return p9BundleFailure("bundle_manifest_missing")
    }
    for (asset in manifest.assets) {
        let entry = p9FindBundleReadEntry(listing, asset.relativePath)
        if (!entry[0]) {
            return p9BundleFailure("bundle_root_missing_asset")
        }
        if (entry[1].kind != "regular") {
            return p9BundleFailure("bundle_root_entry_type_invalid")
        }
    }
    for (directory in requiredDirectories) {
        if (!listedDirectories.contains(directory)) {
            return p9BundleFailure("bundle_root_missing_asset")
        }
    }
    if (listing.size != manifest.assets.size + 1 +
        requiredDirectories.size) {
        return p9BundleFailure("bundle_root_extra_asset")
    }
    p9BundleSuccess()
}

private func p9FindBundleReadEntry(
    listing: ArrayList<CkbReproBundleReadEntry>, relativePath: String):
    (Bool, CkbReproBundleReadEntry) {
    for (entry in listing) {
        if (entry.relativePath == relativePath) { return (true, entry) }
    }
    (false, CkbReproBundleReadEntry())
}

private func p9ConsumeBundleEntry(root: String,
    expected: CkbReproBundleReadEntry,
    backend: CkbReproBundleReadBackend, captureLimit: Int64,
    scanText!: Bool = false):
    P9BundleStreamResult {
    let out = P9BundleStreamResult()
    if (captureLimit > 0 && expected.size > captureLimit) {
        out.contract = p9BundleFailure("bundle_manifest_size_exceeded")
        return out
    }
    try {
        let handle = backend.open(root, expected)
        try {
            if (!handle.noFollow()) {
                out.contract = p9BundleFailure("bundle_read_no_follow_required")
                return out
            }
            let digest = SHA256()
            let captured = ArrayList<UInt8>()
            let scanner = P9BundleContentScanner(scanText)
            let buffer = Array<UInt8>(65536, repeat: UInt8(0))
            while (true) {
                let count = handle.read(buffer)
                if (count < 0 || count > buffer.size) {
                    out.contract = p9BundleFailure("bundle_read_failed")
                    return out
                }
                if (count == 0) { break }
                let chunk = Array<UInt8>(count, repeat: UInt8(0))
                for (i in 0..count) {
                    chunk[i] = buffer[i]
                    if (captureLimit > 0) { captured.add(buffer[i]) }
                }
                out.size += count
                if (out.size > expected.size ||
                    (captureLimit > 0 && out.size > captureLimit)) {
                    out.contract = p9BundleFailure("bundle_asset_size_mismatch")
                    return out
                }
                digest.write(chunk)
                scanner.feed(chunk)
            }
            let content = scanner.finish()
            if (content != "ok") {
                out.contract = p9BundleFailure(content)
                return out
            }
            out.observed = handle.observedEntry()
            if (out.observed.kind != "regular" ||
                !out.observed.withinRoot ||
                out.observed.canonicalPath !=
                    "${root}/${out.observed.relativePath}") {
                out.contract = p9BundleFailure(
                    "bundle_read_observed_entry_unsafe")
                return out
            }
            if (!p9BundleReadEntriesEqual(expected, out.observed)) {
                out.contract = p9BundleFailure("bundle_read_entry_changed")
                return out
            }
            if (out.size != out.observed.size) {
                out.contract = p9BundleFailure("bundle_asset_size_mismatch")
                return out
            }
            out.sha256 = p9BundleDigestHash(digest)
            if (captureLimit > 0) { out.bytes = captured.toArray() }
            out.contract = p9BundleSuccess()
            out
        } catch (_: Exception) {
            out.contract = p9BundleFailure("bundle_read_failed")
            out
        } finally {
            try { handle.close() } catch (_: Exception) {
                if (out.contract.ok) {
                    out.contract = p9BundleFailure(
                        "bundle_read_close_failed")
                }
            }
        }
    } catch (_: Exception) {
        out.contract = p9BundleFailure("bundle_read_failed")
        out
    }
}

private func p9ValidateMultipartContent(root: String,
    manifest: CkbReproBundleManifest,
    listing: ArrayList<CkbReproBundleReadEntry>,
    backend: CkbReproBundleReadBackend): CkbReproContractResult {
    let checked = HashSet<String>()
    for (asset in manifest.assets) {
        if (asset.partCount <= 1) { continue }
        let group = asset.role + "\t" + asset.logicalAsset
        if (checked.contains(group)) { continue }
        checked.add(group)
        let digest = SHA256()
        var total: Int64 = 0
        for (index in 0..asset.partCount) {
            var part = CkbReproBundleAsset()
            var found = false
            for (candidate in manifest.assets) {
                if (candidate.role == asset.role &&
                    candidate.logicalAsset == asset.logicalAsset &&
                    candidate.partIndex == index) {
                    part = candidate
                    found = true
                }
            }
            if (!found) {
                return p9BundleFailure("bundle_asset_parts_incomplete")
            }
            let entry = p9FindBundleReadEntry(listing, part.relativePath)
            if (!entry[0]) {
                return p9BundleFailure("bundle_root_missing_asset")
            }
            // A second bounded streaming pass feeds the logical digest without
            // retaining a potentially GiB-sized part in memory.
            let logical = p9DigestBundleEntry(root, entry[1], backend, digest)
            if (!logical.ok) { return logical }
            total += part.size
        }
        if (total != asset.logicalSize ||
            p9BundleDigestHash(digest) != asset.logicalSha256) {
            return p9BundleFailure("bundle_asset_hash_mismatch")
        }
    }
    p9BundleSuccess()
}

private func p9DigestBundleEntry(root: String,
    expected: CkbReproBundleReadEntry,
    backend: CkbReproBundleReadBackend, digest: SHA256):
    CkbReproContractResult {
    let out = CkbReproContractResult()
    out.diagnostic = "bundle_read_failed"
    try {
        let handle = backend.open(root, expected)
        try {
            if (!handle.noFollow()) {
                out.diagnostic = "bundle_read_no_follow_required"
                return out
            }
            let buffer = Array<UInt8>(65536, repeat: UInt8(0))
            var total: Int64 = 0
            while (true) {
                let count = handle.read(buffer)
                if (count < 0 || count > buffer.size) {
                    return out
                }
                if (count == 0) { break }
                digest.write(p9BundleBufferPrefix(buffer, count))
                total += count
                if (total > expected.size) {
                    out.diagnostic = "bundle_asset_size_mismatch"
                    return out
                }
            }
            if (total != expected.size ||
                !p9BundleReadEntriesEqual(expected,
                    handle.observedEntry())) {
                out.diagnostic = "bundle_read_entry_changed"
                return out
            }
            out.ok = true
            out.diagnostic = "ok"
            out
        } catch (_: Exception) {
            out.ok = false
            out.diagnostic = "bundle_read_failed"
            out
        } finally {
            try { handle.close() } catch (_: Exception) {
                if (out.ok) {
                    out.ok = false
                    out.diagnostic = "bundle_read_close_failed"
                }
            }
        }
    } catch (_: Exception) {
        out.ok = false
        out.diagnostic = "bundle_read_failed"
        out
    }
}

private func p9BundleBufferPrefix(buffer: Array<UInt8>, count: Int64):
    Array<UInt8> {
    let prefix = Array<UInt8>(count, repeat: UInt8(0))
    for (i in 0..count) { prefix[i] = buffer[i] }
    prefix
}

private func p9BundleReadEntriesEqual(left: CkbReproBundleReadEntry,
    right: CkbReproBundleReadEntry): Bool {
    left.relativePath == right.relativePath &&
        left.kind == right.kind &&
        left.canonicalPath == right.canonicalPath &&
        left.withinRoot == right.withinRoot &&
        left.identity == right.identity &&
        left.size == right.size
}

private func p9BundleReadSnapshotHash(
    listing: ArrayList<CkbReproBundleReadEntry>): String {
    let rows = ArrayList<String>()
    for (entry in listing) {
        rows.add(p9BundlePart(entry.relativePath) +
            p9BundlePart(entry.kind) + p9BundlePart(entry.identity) +
            p9BundlePart(entry.size.toString()))
    }
    let ordered = rows.toArray()
    sort(ordered)
    ckbReproBundleHash(
        ("ckb-repro-bundle-read-snapshot-v1" +
            p9BundleJoin(ordered, "")).toArray())
}

private func p9BundleAssetProofHash(
    proof: CkbReproBundleAssetProof): String {
    ckbReproBundleHash(("ckb-repro-bundle-asset-proof-v1" +
        p9BundlePart(proof.relativePath) +
        p9BundlePart(proof.size.toString()) +
        p9BundlePart(proof.sha256)).toArray())
}

private func p9BundleProofSetHash(
    proofs: ArrayList<CkbReproBundleAssetProof>): String {
    let rows = ArrayList<String>()
    for (proof in proofs) { rows.add(proof.proofHash) }
    let ordered = rows.toArray()
    sort(ordered)
    ckbReproBundleHash(
        ("ckb-repro-bundle-proof-set-v1" +
            p9BundleJoin(ordered, "")).toArray())
}

public func computeCkbReproBundleProofSetHash(
    manifest: CkbReproBundleManifest): String {
    let proofs = ArrayList<CkbReproBundleAssetProof>()
    for (asset in manifest.assets) {
        let proof = CkbReproBundleAssetProof()
        proof.relativePath = asset.relativePath
        proof.size = asset.size; proof.sha256 = asset.sha256
        proof.proofHash = p9BundleAssetProofHash(proof)
        proofs.add(proof)
    }
    p9BundleProofSetHash(proofs)
}

private func p9BundleString(object: JsonObject, key: String): String {
    object.get(key).getOrThrow().asString().getValue()
}

private func p9BundleBool(object: JsonObject, key: String): Bool {
    object.get(key).getOrThrow().asBool().getValue()
}

private func p9BundleInt(object: JsonObject, key: String): Int64 {
    object.get(key).getOrThrow().asInt().getValue()
}

private func p9BundleCommit(value: String): Bool {
    if (value.toRuneArray().size != 40) { return false }
    for (rune in value.runes()) {
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) { return false }
    }
    true
}

private func p9BundleReadSmallFile(path: String, limit: Int64):
    (String, Array<UInt8>) {
    let bytes = ArrayList<UInt8>()
    try {
        try (file = File(Path(path), OpenMode.Read)) {
            let buffer = Array<UInt8>(65536, repeat: UInt8(0))
            while (true) {
                let count = file.read(buffer)
                if (count < 0 || count > buffer.size) {
                    return ("bundle_verification_report_read_failed",
                        Array<UInt8>())
                }
                if (count == 0) { break }
                if (bytes.size + count > limit) {
                    return ("bundle_verification_report_size_invalid",
                        Array<UInt8>())
                }
                for (i in 0..count) { bytes.add(buffer[i]) }
            }
        }
        ("ok", bytes.toArray())
    } catch (_: Exception) {
        ("bundle_verification_report_read_failed", Array<UInt8>())
    }
}

private func p9LoadFrozenReleaseInputs(root: String,
    backend: CkbReproBundleReadBackend): CkbReproReleaseInputsLoadResult {
    let failed = CkbReproReleaseInputsLoadResult()
    try {
        if (!backend.rootExists(root)) {
            failed.contract = p9BundleFailure("bundle_input_root_missing")
            return failed
        }
        let identity = backend.rootIdentity(root)
        if (identity == "") {
            failed.contract = p9BundleFailure("bundle_input_root_invalid")
            return failed
        }
        let listing = backend.list(root)
        let safe = p9ValidateBundleReadListing(root, listing)
        if (!safe.ok) { failed.contract = safe; return failed }
        let found = p9FindBundleReadEntry(listing, "RELEASE-INPUTS.json")
        if (!found[0]) {
            failed.contract = p9BundleFailure("bundle_release_inputs_missing")
            return failed
        }
        let manifestRead = p9ConsumeBundleEntry(root, found[1], backend,
            16 * 1024 * 1024)
        if (!manifestRead.contract.ok) {
            failed.contract = manifestRead.contract; return failed
        }
        let out = p9ParseReleaseInputs(manifestRead.bytes)
        if (!out.contract.ok) { return out }
        let declared = HashSet<String>(); declared.add("RELEASE-INPUTS.json")
        let directories = HashSet<String>()
        for (input in out.inputs) {
            declared.add(input.sourceRelativePath)
            let parts = input.sourceRelativePath.split("/")
            let parent = StringBuilder()
            for (i in 0..parts.size - 1) {
                if (i > 0) { parent.append("/") }
                parent.append(parts[i]); directories.add(parent.toString())
            }
        }
        for (entry in listing) {
            if (entry.kind == "directory") {
                if (!directories.contains(entry.relativePath)) {
                    out.contract = p9BundleFailure(
                        "bundle_input_root_extra_asset"); return out
                }
            } else if (!declared.contains(entry.relativePath)) {
                out.contract = p9BundleFailure(
                    "bundle_input_root_extra_asset"); return out
            }
        }
        if (listing.size != declared.size + directories.size) {
            out.contract = p9BundleFailure("bundle_input_root_missing_asset")
            return out
        }
        var releaseBound = false; var referenceBound = false
        for (input in out.inputs) {
            let entry = p9FindBundleReadEntry(listing,
                input.sourceRelativePath)
            if (!entry[0] || entry[1].kind != "regular" ||
                entry[1].size != input.asset.size) {
                out.contract = p9BundleFailure(
                    "bundle_input_root_missing_asset"); return out
            }
            if (input.asset.logicalAsset == "release/release-commit.txt") {
                let read = p9ConsumeBundleEntry(root, entry[1], backend, 1024)
                let text = try { String.fromUtf8(read.bytes).trimAscii() }
                    catch (_: Exception) { "" }
                if (!read.contract.ok || read.sha256 != input.asset.sha256 ||
                    text != out.releaseCommit) {
                    out.contract = p9BundleFailure(
                        "bundle_release_identity_mismatch"); return out
                }
                releaseBound = true
            }
            if (input.asset.logicalAsset ==
                "reproducibility/manifests/reference-run.json") {
                let read = p9ConsumeBundleEntry(root, entry[1], backend,
                    16 * 1024 * 1024)
                let reference = parseCkbReproReferenceManifest(read.bytes)
                if (!read.contract.ok || read.sha256 != input.asset.sha256 ||
                    read.sha256 != out.referenceManifestHash ||
                    !reference[0].ok ||
                    reference[1].runCriticalTreeHash != out.runCriticalTreeHash ||
                    reference[1].certifiedRunInputHash !=
                        out.certifiedRunInputHash) {
                    out.contract = p9BundleFailure(
                        "bundle_release_identity_mismatch"); return out
                }
                referenceBound = true
            }
        }
        if (!releaseBound || !referenceBound) {
            out.contract = p9BundleFailure("bundle_release_identity_missing")
            return out
        }
        out.rootIdentity = identity
        out.listingHash = p9BundleReadSnapshotHash(listing)
        out.manifestBytes = manifestRead.bytes
        out.contract = p9BundleSuccess(); out
    } catch (_: Exception) {
        failed.contract = p9BundleFailure("bundle_release_inputs_read_failed")
        failed
    }
}

private func p9BundleStreamFrozenInputs(sourceRoot: String,
    outputRoot: String, loaded: CkbReproReleaseInputsLoadResult,
    backend: CkbReproBundleReadBackend): Bool {
    try {
        let listing = backend.list(sourceRoot)
        if (p9BundleReadSnapshotHash(listing) != loaded.listingHash ||
            backend.rootIdentity(sourceRoot) != loaded.rootIdentity) {
            return false
        }
        for (input in loaded.inputs) {
            let asset = input.asset
            let found = p9FindBundleReadEntry(listing,
                input.sourceRelativePath)
            if (!found[0] || found[1].kind != "regular") { return false }
            let target = Path(outputRoot).join(asset.relativePath)
            if (!exists(target.parent)) {
                Directory.create(target.parent, recursive: true)
            }
            let handle = backend.open(sourceRoot, found[1])
            let digest = SHA256(); var size: Int64 = 0
            let scanner = P9BundleContentScanner(!p9BundleBinaryAllowed(asset))
            try {
                if (!handle.noFollow()) { return false }
                try (file = File(target, OpenMode.Write)) {
                    let buffer = Array<UInt8>(65536, repeat: UInt8(0))
                    while (true) {
                        let count = handle.read(buffer)
                        if (count < 0 || count > buffer.size) { return false }
                        if (count == 0) { break }
                        let chunk = if (count == buffer.size) { buffer }
                            else { buffer[0..count].clone() }
                        file.write(chunk); digest.write(chunk)
                        scanner.feed(chunk); size += count
                        if (size > asset.size) { return false }
                    }
                }
                if (size != asset.size ||
                    p9BundleDigestHash(digest) != asset.sha256 ||
                    scanner.finish() != "ok" ||
                    !p9BundleReadEntriesEqual(found[1],
                        handle.observedEntry())) { return false }
            } finally { handle.close() }
        }
        let foundManifest = p9FindBundleReadEntry(listing,
            "RELEASE-INPUTS.json")
        if (!foundManifest[0]) { return false }
        let manifestAfter = p9ConsumeBundleEntry(sourceRoot,
            foundManifest[1], backend, 16 * 1024 * 1024)
        if (!manifestAfter.contract.ok ||
            manifestAfter.bytes != loaded.manifestBytes ||
            p9BundleReadSnapshotHash(backend.list(sourceRoot)) !=
                loaded.listingHash ||
            backend.rootIdentity(sourceRoot) != loaded.rootIdentity) {
            return false
        }
        File.writeTo(Path(outputRoot).join("RELEASE-MANIFEST.json"),
            renderCkbReproBundleManifest(loaded.manifest).toArray())
        true
    } catch (_: Exception) { false }
}

private func p9BundleStreamCopyValidated(sourceRoot: String,
    outputRoot: String, manifest: CkbReproBundleManifest,
    backend: CkbReproBundleReadBackend): Bool {
    try {
        let listing = backend.list(sourceRoot)
        for (asset in manifest.assets) {
            let found = p9FindBundleReadEntry(listing, asset.relativePath)
            if (!found[0] || found[1].kind != "regular") { return false }
            let target = Path(outputRoot).join(asset.relativePath)
            if (!exists(target.parent)) {
                Directory.create(target.parent, recursive: true)
            }
            let digest = SHA256()
            var size: Int64 = 0
            let handle = backend.open(sourceRoot, found[1])
            try {
                if (!handle.noFollow()) { return false }
                try (file = File(target, OpenMode.Write)) {
                    let buffer = Array<UInt8>(65536, repeat: UInt8(0))
                    while (true) {
                        let count = handle.read(buffer)
                        if (count < 0 || count > buffer.size) { return false }
                        if (count == 0) { break }
                        let chunk = if (count == buffer.size) {
                            buffer
                        } else { buffer[0..count].clone() }
                        file.write(chunk); digest.write(chunk); size += count
                        if (size > asset.size) { return false }
                    }
                }
                if (size != asset.size ||
                    p9BundleDigestHash(digest) != asset.sha256 ||
                    !p9BundleReadEntriesEqual(found[1],
                        handle.observedEntry())) { return false }
            } finally { handle.close() }
        }
        File.writeTo(Path(outputRoot).join("RELEASE-MANIFEST.json"),
            renderCkbReproBundleManifest(manifest).toArray())
        true
    } catch (_: Exception) { false }
}

private func p9BundleHashValid(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 71 || !value.startsWith("sha256:")) { return false }
    for (i in 7..71) {
        let rune = runes[i]
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) {
            return false
        }
    }
    true
}

private func p9BundlePathHasControl(value: String): Bool {
    for (rune in value.toRuneArray()) {
        if (rune <= r'\u{001f}' || rune == r'\u{007f}') { return true }
    }
    false
}

private func p9BundleDigestHash(digest: SHA256): String {
    let builder = StringBuilder()
    for (byte in digest.finish()) {
        builder.append(p9BundleNibble(byte / UInt8(16)))
        builder.append(p9BundleNibble(byte % UInt8(16)))
    }
    "sha256:${builder.toString()}"
}

private func p9BundleNibble(value: UInt8): String {
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

private func p9BundleCliCoreOptions(
    cli: CkbReproBundleCliOptions): CkbReproBundleOptions {
    let out = CkbReproBundleOptions()
    out.outputRoot = cli.outputRoot
    // CLI validation owns protected roots before the core writer is called.
    out.worktreeRoot = "/__validated_worktree__"
    out.productionRoot = "/__validated_production__"
    out.privateRunRoot = "/__validated_private_run__"
    out.userConfigRoot = "/__validated_user_config__"
    out
}

private func p9BundleCliFailure(code: String): CkbReproBundleResult {
    let out = CkbReproBundleResult(); out.diagnostic = code; out
}

private func p9BundleCliSafe(value: String): String {
    if (value == "" || value.toRuneArray().size > 128 || value.contains(":") ||
        value.contains("/") || value.contains("\\") || value.contains(" ")) {
        return "redacted_diagnostic"
    }
    value
}

private func p9BundleCliExistingCanonical(value: String): Bool {
    try { canonicalize(Path(value)).toString() == value }
    catch (_: Exception) { false }
}

private func p9BundleCliNewOutputCanonical(value: String): Bool {
    let path = Path(value)
    try {
        Path(canonicalize(path.parent).toString()).join(path.fileName).toString() == value
    } catch (_: Exception) { false }
}

private func p9BundleJson(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"")
        .replace("\u{0000}", "\\u0000").replace("\u{0001}", "\\u0001")
        .replace("\u{0002}", "\\u0002").replace("\u{0003}", "\\u0003")
        .replace("\u{0004}", "\\u0004").replace("\u{0005}", "\\u0005")
        .replace("\u{0006}", "\\u0006").replace("\u{0007}", "\\u0007")
        .replace("\u{0008}", "\\b").replace("\t", "\\t")
        .replace("\n", "\\n").replace("\u{000b}", "\\u000b")
        .replace("\u{000c}", "\\f").replace("\r", "\\r")
        .replace("\u{000e}", "\\u000e").replace("\u{000f}", "\\u000f")
        .replace("\u{0010}", "\\u0010").replace("\u{0011}", "\\u0011")
        .replace("\u{0012}", "\\u0012").replace("\u{0013}", "\\u0013")
        .replace("\u{0014}", "\\u0014").replace("\u{0015}", "\\u0015")
        .replace("\u{0016}", "\\u0016").replace("\u{0017}", "\\u0017")
        .replace("\u{0018}", "\\u0018").replace("\u{0019}", "\\u0019")
        .replace("\u{001a}", "\\u001a").replace("\u{001b}", "\\u001b")
        .replace("\u{001c}", "\\u001c").replace("\u{001d}", "\\u001d")
        .replace("\u{001e}", "\\u001e").replace("\u{001f}", "\\u001f")
        .replace("\u{007f}", "\\u007f")
}

private func p9BundleSuccess(): CkbReproContractResult {
    let out = CkbReproContractResult()
    out.ok = true
    out.diagnostic = "ok"
    out
}

private func p9BundleFailure(diagnostic: String): CkbReproContractResult {
    let out = CkbReproContractResult()
    out.diagnostic = diagnostic
    out
}
