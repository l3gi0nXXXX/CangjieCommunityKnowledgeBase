package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.sort.*
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

public class CkbAuthorityDeliveryManifest {
    public var schemaVersion: String = ""
    public var mode: String = ""
    public var licenseId: String = ""
    public var licenseEvidenceHash: String = ""
    public var redistributionAllowed: Bool = false
    public var anonymousPublicAccess: Bool = false
    public var repository: String = ""
    public var commit: String = ""
    public var tree: String = ""
    public var path: String = ""
    public var fileHashes: ArrayList<String> = ArrayList<String>()
    public var builderHash: String = ""
    public var sourceMaterialsHash: String = ""
    public var bundleHash: String = ""
    public var authorityHash: String = ""
    public var datasetVersion: String = ""
    public var diagnostic: String = ""
    public init() {}
}

public func parseCkbAuthorityDeliveryManifest(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbAuthorityDeliveryManifest) {
    let manifest = CkbAuthorityDeliveryManifest()
    let decoded = p6AuthorityDecode(bytes)
    if (decoded[0] != "ok") {
        return (p6AuthorityFailure(decoded[0]), manifest)
    }
    try {
        let object = JsonValue.fromStr(decoded[1]).asObject()
        if (object.size() != 17) {
            return (p6AuthorityFailure("authority_delivery_field_contract_invalid"),
                manifest)
        }
        manifest.schemaVersion = p6AuthorityString(object, "schemaVersion")
        manifest.mode = p6AuthorityString(object, "mode")
        manifest.licenseId = p6AuthorityString(object, "licenseId")
        manifest.licenseEvidenceHash = p6AuthorityString(object, "licenseEvidenceHash")
        manifest.redistributionAllowed = p6AuthorityBool(object, "redistributionAllowed")
        manifest.anonymousPublicAccess = p6AuthorityBool(object, "anonymousPublicAccess")
        manifest.repository = p6AuthorityString(object, "repository")
        manifest.commit = p6AuthorityString(object, "commit")
        manifest.tree = p6AuthorityString(object, "tree")
        manifest.path = p6AuthorityString(object, "path")
        for (value in object.get("fileHashes").getOrThrow().asArray().getItems()) {
            manifest.fileHashes.add(value.asString().getValue())
        }
        manifest.builderHash = p6AuthorityString(object, "builderHash")
        manifest.sourceMaterialsHash = p6AuthorityString(object, "sourceMaterialsHash")
        manifest.bundleHash = p6AuthorityString(object, "bundleHash")
        manifest.authorityHash = p6AuthorityString(object, "authorityHash")
        manifest.datasetVersion = p6AuthorityString(object, "datasetVersion")
        manifest.diagnostic = p6AuthorityString(object, "diagnostic")
    } catch (_: Exception) {
        return (p6AuthorityFailure("authority_delivery_field_contract_invalid"),
            CkbAuthorityDeliveryManifest())
    }
    (p6AuthoritySuccess(), manifest)
}

public func selectCkbAuthorityDeliveryMode(manifest: CkbAuthorityDeliveryManifest):
    CkbReproContractResult {
    if (manifest.schemaVersion != "ckb-authority-delivery-v1" ||
        manifest.licenseId == "") {
        return p6AuthorityFailure("authority_license_evidence_invalid")
    }
    if (manifest.redistributionAllowed) {
        if (!p6AuthorityHashValid(manifest.licenseEvidenceHash) ||
            manifest.mode != "bundled" ||
            !p6AuthorityHashValid(manifest.bundleHash) ||
            !p6AuthorityCommonIdentityValid(manifest) ||
            manifest.repository != "" || manifest.commit != "" ||
            manifest.tree != "" || manifest.path != "" ||
            manifest.fileHashes.size != 0 || manifest.builderHash != "" ||
            manifest.sourceMaterialsHash != "" || manifest.diagnostic != "") {
            return p6AuthorityFailure("authority_bundled_contract_invalid")
        }
        let result = p6AuthoritySuccess()
        result.diagnostic = "bundled"
        return result
    }
    if (manifest.anonymousPublicAccess) {
        if (!p6AuthorityHashValid(manifest.licenseEvidenceHash) ||
            manifest.mode != "public_rebuild" ||
            !p6AuthorityPublicSourceValid(manifest) ||
            !p6AuthorityCommonIdentityValid(manifest) ||
            manifest.bundleHash != "" || manifest.diagnostic != "") {
            return p6AuthorityFailure("authority_public_rebuild_contract_invalid")
        }
        let result = p6AuthoritySuccess()
        result.diagnostic = "public_rebuild"
        return result
    }
    if (manifest.mode != "blocked" || manifest.diagnostic == "" ||
        manifest.licenseEvidenceHash != "" ||
        manifest.bundleHash != "" || manifest.authorityHash != "" ||
        manifest.datasetVersion != "" || manifest.repository != "" ||
        manifest.commit != "" || manifest.tree != "" || manifest.path != "" ||
        manifest.fileHashes.size != 0 || manifest.builderHash != "" ||
        manifest.sourceMaterialsHash != "") {
        return p6AuthorityFailure("authority_blocked_contract_invalid")
    }
    let result = p6AuthoritySuccess()
    result.diagnostic = "blocked"
    result
}

public func renderCkbAuthorityDeliveryManifest(manifest: CkbAuthorityDeliveryManifest):
    String {
    let hashes = manifest.fileHashes.toArray()
    sort(hashes)
    var renderedHashes = "["
    for (i in 0..hashes.size) {
        if (i > 0) { renderedHashes += "," }
        renderedHashes += "\"${p6AuthorityEscape(hashes[i])}\""
    }
    renderedHashes += "]"
    "{\"schemaVersion\":\"${p6AuthorityEscape(manifest.schemaVersion)}\"," +
    "\"mode\":\"${p6AuthorityEscape(manifest.mode)}\"," +
    "\"licenseId\":\"${p6AuthorityEscape(manifest.licenseId)}\"," +
    "\"licenseEvidenceHash\":\"${p6AuthorityEscape(manifest.licenseEvidenceHash)}\"," +
    "\"redistributionAllowed\":${manifest.redistributionAllowed}," +
    "\"anonymousPublicAccess\":${manifest.anonymousPublicAccess}," +
    "\"repository\":\"${p6AuthorityEscape(manifest.repository)}\"," +
    "\"commit\":\"${p6AuthorityEscape(manifest.commit)}\"," +
    "\"tree\":\"${p6AuthorityEscape(manifest.tree)}\"," +
    "\"path\":\"${p6AuthorityEscape(manifest.path)}\"," +
    "\"fileHashes\":${renderedHashes}," +
    "\"builderHash\":\"${p6AuthorityEscape(manifest.builderHash)}\"," +
    "\"sourceMaterialsHash\":\"${p6AuthorityEscape(manifest.sourceMaterialsHash)}\"," +
    "\"bundleHash\":\"${p6AuthorityEscape(manifest.bundleHash)}\"," +
    "\"authorityHash\":\"${p6AuthorityEscape(manifest.authorityHash)}\"," +
    "\"datasetVersion\":\"${p6AuthorityEscape(manifest.datasetVersion)}\"," +
    "\"diagnostic\":\"${p6AuthorityEscape(manifest.diagnostic)}\"}"
}

public func buildCkbReproAuthorityBundle(manifest: CkbAuthorityDeliveryManifest,
    authorityBytes: Array<UInt8>, outputRoot: String, storeRoot: String,
    studentWorkspace: String): CkbReproContractResult {
    let selected = selectCkbAuthorityDeliveryMode(manifest)
    if (!selected.ok || selected.diagnostic != "bundled") {
        return p6AuthorityFailure("authority_bundled_mode_required")
    }
    validateCkbReproAuthorityDelivery(manifest, authorityBytes,
        manifest.datasetVersion, outputRoot, storeRoot, studentWorkspace)
}

public func buildCkbReproAuthorityFromPublicSource(
    manifest: CkbAuthorityDeliveryManifest, authorityBytes: Array<UInt8>,
    outputRoot: String, storeRoot: String,
    studentWorkspace: String): CkbReproContractResult {
    let selected = selectCkbAuthorityDeliveryMode(manifest)
    if (!selected.ok || selected.diagnostic != "public_rebuild") {
        return p6AuthorityFailure("authority_public_rebuild_mode_required")
    }
    validateCkbReproAuthorityDelivery(manifest, authorityBytes,
        manifest.datasetVersion, outputRoot, storeRoot, studentWorkspace)
}

public func validateCkbReproAuthorityDelivery(
    manifest: CkbAuthorityDeliveryManifest, authorityBytes: Array<UInt8>,
    expectedDatasetVersion: String, outputRoot: String, storeRoot: String,
    studentWorkspace: String): CkbReproContractResult {
    let selected = selectCkbAuthorityDeliveryMode(manifest)
    if (!selected.ok) { return selected }
    if (selected.diagnostic == "blocked") {
        return p6AuthorityFailure("authority_delivery_blocked")
    }
    if (!p6AuthorityRootValid(outputRoot) ||
        !p6AuthorityRootValid(storeRoot) ||
        !p6AuthorityRootValid(studentWorkspace)) {
        return p6AuthorityFailure("authority_output_root_invalid")
    }
    if (p6AuthorityPathOverlap(outputRoot, storeRoot) ||
        p6AuthorityPathOverlap(outputRoot, studentWorkspace)) {
        return p6AuthorityFailure("authority_output_root_forbidden")
    }
    let decoded = p6AuthorityDecode(authorityBytes)
    if (decoded[0] != "ok") { return p6AuthorityFailure(decoded[0]) }
    let authority = parseCangjieHumanEvalAuthorityManifest(decoded[1])
    if (!authority.ok || authority.rows.size != 164) {
        return p6AuthorityFailure("authority_manifest_invalid")
    }
    if (expectedDatasetVersion == "" ||
        authority.datasetVersion != expectedDatasetVersion ||
        manifest.datasetVersion != expectedDatasetVersion) {
        return p6AuthorityFailure("authority_dataset_version_mismatch")
    }
    let authorityHash = p6AuthorityHash(authorityBytes)
    if (manifest.authorityHash != authorityHash) {
        return p6AuthorityFailure("authority_hash_mismatch")
    }
    let result = p6AuthoritySuccess()
    result.canonicalJson = renderCkbAuthorityDeliveryManifest(manifest)
    result.manifestHash = p6AuthorityHash(result.canonicalJson.toArray())
    result.treeHash = authorityHash
    result.presentCount = 164
    result
}

private func p6AuthorityCommonIdentityValid(
    manifest: CkbAuthorityDeliveryManifest): Bool {
    p6AuthorityHashValid(manifest.authorityHash) &&
        manifest.datasetVersion.startsWith("cangjie-humaneval-164-sha256:")
}

private func p6AuthorityPublicSourceValid(
    manifest: CkbAuthorityDeliveryManifest): Bool {
    if (!manifest.repository.startsWith("https://") ||
        manifest.repository.contains("@") ||
        !p6AuthorityGitHashValid(manifest.commit) ||
        !p6AuthorityGitHashValid(manifest.tree) ||
        !p6AuthorityRelativePathValid(manifest.path) ||
        manifest.fileHashes.size == 0 ||
        !p6AuthorityHashValid(manifest.builderHash) ||
        !p6AuthorityHashValid(manifest.sourceMaterialsHash)) {
        return false
    }
    for (entry in manifest.fileHashes) {
        let parts = entry.split("|")
        if (parts.size != 2 || !p6AuthorityRelativePathValid(parts[0]) ||
            !p6AuthorityHashValid(parts[1])) { return false }
    }
    true
}

private func p6AuthorityPathOverlap(left: String, right: String): Bool {
    left == right || left.startsWith("${right}/") ||
        right.startsWith("${left}/")
}

private func p6AuthorityRootValid(value: String): Bool {
    if (value == "" || value != value.trimAscii() ||
        !value.startsWith("/") || value.contains("\\") ||
        value.contains("//") || (value.endsWith("/") && value != "/")) {
        return false
    }
    for (segment in value.split("/")) {
        if (segment == "." || segment == "..") { return false }
    }
    true
}

private func p6AuthorityRelativePathValid(value: String): Bool {
    value != "" && !value.startsWith("/") && !value.contains("..") &&
        !value.contains("\\") && !value.contains("*") &&
        !value.contains("?")
}

private func p6AuthorityGitHashValid(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 40) { return false }
    for (rune in runes) {
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) { return false }
    }
    true
}

private func p6AuthorityHashValid(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 71 || !value.startsWith("sha256:")) { return false }
    for (i in 7..runes.size) {
        let rune = runes[i]
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) { return false }
    }
    true
}

private func p6AuthorityDecode(bytes: Array<UInt8>): (String, String) {
    try { ("ok", String.fromUtf8(bytes)) }
    catch (_: Exception) { ("invalid_response_encoding", "") }
}

private func p6AuthorityString(object: JsonObject, key: String): String {
    object.get(key).getOrThrow().asString().getValue()
}

private func p6AuthorityBool(object: JsonObject, key: String): Bool {
    object.get(key).getOrThrow().asBool().getValue()
}

private func p6AuthoritySuccess(): CkbReproContractResult {
    let result = CkbReproContractResult()
    result.ok = true
    result.diagnostic = "ok"
    result
}

private func p6AuthorityFailure(diagnostic: String): CkbReproContractResult {
    let result = CkbReproContractResult()
    result.diagnostic = diagnostic
    result
}

private func p6AuthorityEscape(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"")
        .replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
}

private func p6AuthorityHash(bytes: Array<UInt8>): String {
    let digest = SHA256()
    digest.write(bytes)
    let out = StringBuilder()
    for (byte in digest.finish()) {
        out.append(p6AuthorityHex(byte / UInt8(16)))
        out.append(p6AuthorityHex(byte % UInt8(16)))
    }
    "sha256:${out.toString()}"
}

private func p6AuthorityHex(value: UInt8): String {
    if (value < UInt8(10)) { return "${value}" }
    if (value == UInt8(10)) { return "a" }
    if (value == UInt8(11)) { return "b" }
    if (value == UInt8(12)) { return "c" }
    if (value == UInt8(13)) { return "d" }
    if (value == UInt8(14)) { return "e" }
    "f"
}
