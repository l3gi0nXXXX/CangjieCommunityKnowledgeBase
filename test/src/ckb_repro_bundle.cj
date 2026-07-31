package cangjie_community_knowledge_base_test

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
    func list(root: String): ArrayList<String>
    func read(root: String, relativePath: String): Array<UInt8>
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
        rows.add("{\"path\":\"${p9BundleJson(asset.relativePath)}\"," +
            "\"size\":${asset.size},\"sha256\":\"${asset.sha256}\"," +
            "\"inputKind\":\"${p9BundleJson(asset.inputKind)}\"}")
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
            if (row.size() != 4) {
                return (p9BundleFailure(
                    "bundle_manifest_asset_contract_invalid"),
                    CkbReproBundleManifest())
            }
            let asset = CkbReproBundleAsset()
            asset.relativePath = p9BundleString(row, "path")
            asset.size = p9BundleInt(row, "size")
            asset.sha256 = p9BundleString(row, "sha256")
            asset.inputKind = p9BundleString(row, "inputKind")
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
    manifest: CkbReproBundleManifest,
    backend: CkbReproBundleReadBackend): CkbReproContractResult {
    if (manifest.schemaVersion != "ckb-repro-release-component-v1") {
        return p9BundleFailure("bundle_manifest_schema_invalid")
    }
    if (manifest.assets.size > 1000) {
        return p9BundleFailure("bundle_asset_count_exceeded")
    }
    let declared = HashSet<String>()
    var previousPath = ""
    for (asset in manifest.assets) {
        let path = validateCkbReproBundleRelativePath(asset.relativePath)
        if (!path.ok) { return path }
        if (asset.relativePath == "RELEASE-MANIFEST.json" ||
            asset.relativePath == "SHA256SUMS" ||
            asset.relativePath == "SHA256SUMS.sig" ||
            asset.relativePath.endsWith(".sig")) {
            return p9BundleFailure("bundle_derived_asset_forbidden")
        }
        if (declared.contains(asset.relativePath)) {
            return p9BundleFailure("bundle_asset_duplicate")
        }
        if (previousPath != "" && previousPath > asset.relativePath) {
            return p9BundleFailure("bundle_manifest_asset_order_invalid")
        }
        if (asset.size < 0 || !p9BundleHashValid(asset.sha256)) {
            return p9BundleFailure("bundle_manifest_asset_contract_invalid")
        }
        if (asset.inputKind != "verified_input") {
            return p9BundleFailure("bundle_input_kind_invalid")
        }
        declared.add(asset.relativePath)
        previousPath = asset.relativePath
    }
    if (computeCkbReproBundleInputSetHash(manifest.assets) !=
        manifest.inputSetHash) {
        return p9BundleFailure("bundle_input_set_hash_mismatch")
    }
    try {
        if (!backend.rootExists(root)) {
            return p9BundleFailure("bundle_root_missing")
        }
        let listed = backend.list(root)
        let seen = HashSet<String>()
        var hasManifest = false
        for (path in listed) {
            if (seen.contains(path)) {
                return p9BundleFailure("bundle_root_asset_duplicate")
            }
            seen.add(path)
            if (path == "RELEASE-MANIFEST.json") {
                hasManifest = true
            } else {
                let validPath = validateCkbReproBundleRelativePath(path)
                if (!validPath.ok) { return validPath }
                if (!declared.contains(path)) {
                    return p9BundleFailure("bundle_root_extra_asset")
                }
            }
        }
        if (!hasManifest) {
            return p9BundleFailure("bundle_manifest_missing")
        }
        for (asset in manifest.assets) {
            if (!seen.contains(asset.relativePath)) {
                return p9BundleFailure("bundle_root_missing_asset")
            }
        }
        if (listed.size != manifest.assets.size + 1) {
            return p9BundleFailure("bundle_root_extra_asset")
        }
        let canonical = renderCkbReproBundleManifest(manifest)
        let manifestBytes = backend.read(root, "RELEASE-MANIFEST.json")
        if (manifestBytes != canonical.toArray()) {
            return p9BundleFailure("bundle_manifest_bytes_changed")
        }
        for (asset in manifest.assets) {
            let bytes = backend.read(root, asset.relativePath)
            if (bytes.size != asset.size) {
                return p9BundleFailure("bundle_asset_size_mismatch")
            }
            if (ckbReproBundleHash(bytes) != asset.sha256) {
                return p9BundleFailure("bundle_asset_hash_mismatch")
            }
        }
        let result = p9BundleSuccess()
        result.canonicalJson = canonical
        result.manifestHash = ckbReproBundleHash(manifestBytes)
        result
    } catch (_: Exception) {
        p9BundleFailure("bundle_read_failed")
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
