package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashSet}
import std.sort.*
import stdx.crypto.digest.SHA256

public class CkbReproBundleAsset {
    public var relativePath: String = ""
    public var bytes: Array<UInt8> = Array<UInt8>()
    public var size: Int64 = 0
    public var sha256: String = ""
    public var inputKind: String = ""
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

public interface CkbReproBundleBackend {
    func rootExists(root: String): Bool
    func rootIsEmpty(root: String): Bool
    func createRoot(root: String): Bool
    func read(root: String, relativePath: String): Array<UInt8>
    func write(root: String, relativePath: String, bytes: Array<UInt8>): Bool
    func removeRoot(root: String): Bool
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
        path.contains("\u{0000}") || path.contains("//") ||
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
    if (assets.size > 1000) {
        return p9BundleFailure("bundle_asset_count_exceeded")
    }
    let seen = HashSet<String>()
    for (asset in assets) {
        if (asset.relativePath == "RELEASE-MANIFEST.json" ||
            asset.relativePath == "SHA256SUMS" ||
            asset.relativePath == "SHA256SUMS.sig" ||
            asset.relativePath.endsWith(".sig")) {
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
    p9BundleSuccess()
}

public func computeCkbReproBundleInputSetHash(
    assets: ArrayList<CkbReproBundleAsset>): String {
    let lines = ArrayList<String>()
    for (asset in assets) {
        lines.add(p9BundlePart(asset.relativePath) +
            p9BundlePart(asset.inputKind) + p9BundlePart(asset.size.toString()) +
            p9BundlePart(asset.sha256))
    }
    let ordered = lines.toArray()
    sort(ordered)
    let builder = StringBuilder("ckb-repro-input-set-v1")
    for (line in ordered) { builder.append(p9BundlePart(line)) }
    ckbReproBundleHash(builder.toString().toArray())
}

public func writeCkbReproReleaseManifest(
    assets: ArrayList<CkbReproBundleAsset>): String {
    let rows = ArrayList<String>()
    for (asset in assets) {
        rows.add("{\"path\":\"${p9BundleJson(asset.relativePath)}\"," +
            "\"size\":${asset.size},\"sha256\":\"${asset.sha256}\"," +
            "\"inputKind\":\"${p9BundleJson(asset.inputKind)}\"}")
    }
    let ordered = rows.toArray()
    sort(ordered)
    "{\"schemaVersion\":\"ckb-repro-release-component-v1\"," +
        "\"inputSetHash\":\"${computeCkbReproBundleInputSetHash(assets)}\"," +
        "\"assets\":[${p9BundleJoin(ordered, ",")}]}"
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
        part.relativePath = "${relativePath}.part-${p9BundlePartIndex(index)}"
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
        !value.contains("\n") && !value.contains("\r")
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
        .replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
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
