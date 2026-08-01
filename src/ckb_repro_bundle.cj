package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashSet}
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

public class CkbReproBundleManifest {
    public var schemaVersion: String = ""
    public var inputSetHash: String = ""
    public let assets = ArrayList<CkbReproBundleAsset>()
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

private class P9BundleStreamResult {
    public var contract: CkbReproContractResult = CkbReproContractResult()
    public var bytes: Array<UInt8> = Array<UInt8>()
    public var size: Int64 = 0
    public var sha256: String = ""
    public var observed: CkbReproBundleReadEntry = CkbReproBundleReadEntry()
    public init() {}
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
            let assetRead = p9ConsumeBundleEntry(root, entry[1], backend, 0)
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
        "portable_report", "license", "release_commit"]) {
        if (role == allowed) { return true }
    }
    false
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
    backend: CkbReproBundleReadBackend, captureLimit: Int64):
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
        p9BundlePart(proof.sha256) +
        p9BundlePart(proof.identity)).toArray())
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

private func p9BundleString(object: JsonObject, key: String): String {
    object.get(key).getOrThrow().asString().getValue()
}

private func p9BundleInt(object: JsonObject, key: String): Int64 {
    object.get(key).getOrThrow().asInt().getValue()
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
