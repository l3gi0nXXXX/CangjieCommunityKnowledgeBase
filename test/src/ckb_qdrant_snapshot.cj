package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

public class CkbQdrantSnapshotManifest {
    public var schemaVersion: String = ""
    public var imageDigest: String = ""
    public var qdrantMinorVersion: String = ""
    public var collection: String = ""
    public var distance: String = ""
    public var dimension: Int64 = 0
    public var points: Int64 = 0
    public var snapshotSha256: String = ""
    public var logicalManifestHash: String = ""
    public var vectorProofHash: String = ""
    public var payloadCanonicalHash: String = ""
    public var manifestHash: String = ""
    public init() {}
}

public class CkbQdrantSnapshotContract {
    public var ok: Bool = false
    public var diagnostic: String = "not_validated"
    public var canonicalJson: String = ""
    public var manifestHash: String = ""
    public init() {}
}

public class CkbQdrantSnapshotIdentity {
    public var collection: String = ""
    public var logicalManifestHash: String = ""
    public var vectorProofHash: String = ""
    public init() {}
}

public class CkbQdrantSnapshotRequest {
    public var method: String = "GET"
    public var path: String = ""
    public var contentType: String = ""
    public var bodyBytes: Array<UInt8> = Array<UInt8>()
    public init() {}
}

public class CkbQdrantSnapshotResponse {
    public var statusCode: Int64 = 0
    public var bodyBytes: Array<UInt8> = Array<UInt8>()
    public var diagnostic: String = ""
    public init() {}
}

public interface CkbQdrantSnapshotExecutor {
    func execute(request: CkbQdrantSnapshotRequest):
        CkbQdrantSnapshotResponse
}

public class CkbQdrantSnapshotCreateResult {
    public var ok: Bool = false
    public var diagnostic: String = "snapshot_create_not_run"
    public var snapshotName: String = ""
    public init() {}
}

public class CkbQdrantSnapshotDownloadResult {
    public var ok: Bool = false
    public var diagnostic: String = "snapshot_download_not_run"
    public var bytes: Array<UInt8> = Array<UInt8>()
    public var sha256: String = ""
    public init() {}
}

public class CkbQdrantSnapshotRestoreResult {
    public var ok: Bool = false
    public var diagnostic: String = "snapshot_restore_not_run"
    public init() {}
}

public class CkbQdrantRestoredStatus {
    public var state: String = ""
    public var collection: String = ""
    public var count: Int64 = 0
    public var dimension: Int64 = 0
    public var distance: String = ""
    public var payloadCanonicalHash: String = ""
    public init() {}
}

public class CkbQdrantSnapshotVerification {
    public var ok: Bool = false
    public var ready: Bool = false
    public var diagnostic: String = "snapshot_not_verified"
    public init() {}
}

public func parseCkbQdrantRestoredStatus(bytes: Array<UInt8>,
    collection: String, payloadCanonicalHash: String):
    (CkbQdrantSnapshotContract, CkbQdrantRestoredStatus) {
    let status = CkbQdrantRestoredStatus()
    status.collection = collection
    status.payloadCanonicalHash = payloadCanonicalHash
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (ckbQdrantSnapshotFailure("invalid_response_encoding"), status)
    }
    try {
        let object = JsonValue.fromStr(text).asObject()
        let result = object.get("result").getOrThrow().asObject()
        status.state = ckbQdrantSnapshotString(result, "status")
        status.count = ckbQdrantSnapshotInt(result, "points_count")
        let config = result.get("config").getOrThrow().asObject()
        let params = config.get("params").getOrThrow().asObject()
        let vectors = params.get("vectors").getOrThrow().asObject()
        status.dimension = ckbQdrantSnapshotInt(vectors, "size")
        status.distance = ckbQdrantSnapshotString(vectors, "distance")
    } catch (_: Exception) {
        return (ckbQdrantSnapshotFailure(
            "qdrant_snapshot_status_response_invalid"),
            CkbQdrantRestoredStatus())
    }
    (ckbQdrantSnapshotSuccess(), status)
}

public func parseCkbQdrantSnapshotManifest(bytes: Array<UInt8>):
    (CkbQdrantSnapshotContract, CkbQdrantSnapshotManifest) {
    let manifest = CkbQdrantSnapshotManifest()
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (ckbQdrantSnapshotFailure("invalid_response_encoding"), manifest)
    }
    try {
        let object = JsonValue.fromStr(text).asObject()
        if (object.size() != 12) {
            return (ckbQdrantSnapshotFailure(
                "qdrant_snapshot_field_contract_invalid"), manifest)
        }
        manifest.schemaVersion = ckbQdrantSnapshotString(object, "schemaVersion")
        manifest.imageDigest = ckbQdrantSnapshotString(object, "imageDigest")
        manifest.qdrantMinorVersion =
            ckbQdrantSnapshotString(object, "qdrantMinorVersion")
        manifest.collection = ckbQdrantSnapshotString(object, "collection")
        manifest.distance = ckbQdrantSnapshotString(object, "distance")
        manifest.dimension = ckbQdrantSnapshotInt(object, "dimension")
        manifest.points = ckbQdrantSnapshotInt(object, "points")
        manifest.snapshotSha256 =
            ckbQdrantSnapshotString(object, "snapshotSha256")
        manifest.logicalManifestHash =
            ckbQdrantSnapshotString(object, "logicalManifestHash")
        manifest.vectorProofHash =
            ckbQdrantSnapshotString(object, "vectorProofHash")
        manifest.payloadCanonicalHash =
            ckbQdrantSnapshotString(object, "payloadCanonicalHash")
        manifest.manifestHash =
            ckbQdrantSnapshotString(object, "manifestHash")
    } catch (_: Exception) {
        return (ckbQdrantSnapshotFailure(
            "qdrant_snapshot_field_contract_invalid"),
            CkbQdrantSnapshotManifest())
    }
    (ckbQdrantSnapshotSuccess(), manifest)
}

public func buildCkbQdrantSnapshotManifest(
    manifest: CkbQdrantSnapshotManifest): CkbQdrantSnapshotContract {
    let structural = ckbQdrantSnapshotValidateStructure(manifest)
    if (!structural.ok) { return structural }
    manifest.manifestHash = ckbQdrantSnapshotBytesHash(
        ckbQdrantSnapshotManifestBody(manifest).toArray())
    let result = ckbQdrantSnapshotSuccess()
    result.manifestHash = manifest.manifestHash
    result.canonicalJson = renderCkbQdrantSnapshotManifest(manifest)
    result
}

public func validateCkbQdrantSnapshotManifest(
    manifest: CkbQdrantSnapshotManifest): CkbQdrantSnapshotContract {
    let structural = ckbQdrantSnapshotValidateStructure(manifest)
    if (!structural.ok) { return structural }
    let expected = ckbQdrantSnapshotBytesHash(
        ckbQdrantSnapshotManifestBody(manifest).toArray())
    if (manifest.manifestHash != expected) {
        return ckbQdrantSnapshotFailure(
            "qdrant_snapshot_manifest_hash_mismatch")
    }
    let result = ckbQdrantSnapshotSuccess()
    result.manifestHash = expected
    result.canonicalJson = renderCkbQdrantSnapshotManifest(manifest)
    result
}

public func renderCkbQdrantSnapshotManifest(
    manifest: CkbQdrantSnapshotManifest): String {
    ckbQdrantSnapshotManifestBody(manifest) +
        ",\"manifestHash\":\"${manifest.manifestHash}\"}"
}

public func createCkbQdrantSnapshot(identity: CkbQdrantSnapshotIdentity,
    executor: CkbQdrantSnapshotExecutor): CkbQdrantSnapshotCreateResult {
    let result = CkbQdrantSnapshotCreateResult()
    if (!ckbQdrantSnapshotIdentityValid(identity)) {
        result.diagnostic = "qdrant_snapshot_identity_invalid"
        return result
    }
    let request = CkbQdrantSnapshotRequest()
    request.method = "POST"
    request.path =
        "/collections/${identity.collection}/snapshots"
    let response = executor.execute(request)
    if (response.statusCode < 200 || response.statusCode >= 300) {
        result.diagnostic = "qdrant_snapshot_create_failed"
        return result
    }
    let text = try { String.fromUtf8(response.bodyBytes) } catch (_: Exception) {
        result.diagnostic = "invalid_response_encoding"
        return result
    }
    try {
        let object = JsonValue.fromStr(text).asObject()
        let payload = object.get("result").getOrThrow().asObject()
        result.snapshotName = payload.get("name").getOrThrow().
            asString().getValue()
    } catch (_: Exception) {
        result.diagnostic = "qdrant_snapshot_response_invalid"
        return result
    }
    if (!ckbQdrantSnapshotNameValid(result.snapshotName)) {
        result.diagnostic = "qdrant_snapshot_name_invalid"
        return result
    }
    result.ok = true
    result.diagnostic = "ok"
    result
}

public func downloadCkbQdrantSnapshot(identity: CkbQdrantSnapshotIdentity,
    snapshotName: String, executor: CkbQdrantSnapshotExecutor):
    CkbQdrantSnapshotDownloadResult {
    let result = CkbQdrantSnapshotDownloadResult()
    if (!ckbQdrantSnapshotIdentityValid(identity) ||
        !ckbQdrantSnapshotNameValid(snapshotName)) {
        result.diagnostic = "qdrant_snapshot_identity_invalid"
        return result
    }
    let request = CkbQdrantSnapshotRequest()
    request.method = "GET"
    request.path =
        "/collections/${identity.collection}/snapshots/${snapshotName}"
    let response = executor.execute(request)
    if (response.statusCode < 200 || response.statusCode >= 300 ||
        response.bodyBytes.size == 0) {
        result.diagnostic = "qdrant_snapshot_download_failed"
        return result
    }
    // Snapshot bytes are intentionally never decoded as UTF-8.
    result.bytes = response.bodyBytes.clone()
    result.sha256 = ckbQdrantSnapshotBytesHash(result.bytes)
    result.ok = true
    result.diagnostic = "ok"
    result
}

public func restoreCkbQdrantSnapshot(targetCollection: String,
    snapshotBytes: Array<UInt8>, manifest: CkbQdrantSnapshotManifest,
    executor: CkbQdrantSnapshotExecutor): CkbQdrantSnapshotRestoreResult {
    let result = CkbQdrantSnapshotRestoreResult()
    let validation = validateCkbQdrantSnapshotManifest(manifest)
    if (!validation.ok) { result.diagnostic = validation.diagnostic; return result }
    if (!ckbQdrantSnapshotCollectionValid(targetCollection)) {
        result.diagnostic = "qdrant_snapshot_target_invalid"
        return result
    }
    if (ckbQdrantSnapshotBytesHash(snapshotBytes) !=
        manifest.snapshotSha256) {
        result.diagnostic = "qdrant_snapshot_hash_mismatch"
        return result
    }
    let statusRequest = CkbQdrantSnapshotRequest()
    statusRequest.method = "GET"
    statusRequest.path = "/collections/${targetCollection}"
    let status = executor.execute(statusRequest)
    if (status.statusCode != 404) {
        result.diagnostic = "qdrant_snapshot_target_exists"
        return result
    }
    let restoreRequest = CkbQdrantSnapshotRequest()
    restoreRequest.method = "PUT"
    restoreRequest.path =
        "/collections/${targetCollection}/snapshots/upload"
    restoreRequest.contentType = "application/octet-stream"
    restoreRequest.bodyBytes = snapshotBytes.clone()
    let response = executor.execute(restoreRequest)
    if (response.statusCode < 200 || response.statusCode >= 300) {
        result.diagnostic = "qdrant_snapshot_restore_failed"
        return result
    }
    result.ok = true
    result.diagnostic = "ok"
    result
}

public func verifyRestoredCkbQdrantSnapshot(
    status: CkbQdrantRestoredStatus,
    manifest: CkbQdrantSnapshotManifest,
    logical: CkbLogicalSnapshotManifest,
    visible: CkbStudentVisiblePathInput,
    context: CkbPortablePathContext): CkbQdrantSnapshotVerification {
    let result = CkbQdrantSnapshotVerification()
    let validation = validateCkbQdrantSnapshotManifest(manifest)
    if (!validation.ok) { result.diagnostic = validation.diagnostic; return result }
    if (logical.manifestHash != manifest.logicalManifestHash ||
        logical.p3VectorProofHash != manifest.vectorProofHash ||
        logical.vectorCollection != manifest.collection ||
        logical.vectorCount != manifest.points ||
        logical.vectorDimension != manifest.dimension) {
        result.diagnostic = "qdrant_logical_manifest_mismatch"
        return result
    }
    if (status.state != "green" || status.count != manifest.points ||
        status.dimension != manifest.dimension ||
        status.distance.toAsciiLower() != manifest.distance.toAsciiLower()) {
        result.diagnostic = "qdrant_restored_status_mismatch"
        return result
    }
    if (status.payloadCanonicalHash != manifest.payloadCanonicalHash) {
        result.diagnostic = "qdrant_payload_hash_mismatch"
        return result
    }
    let pathReport = scanCkbStudentVisiblePaths(visible, context)
    if (!pathReport.ready) {
        result.diagnostic = "qdrant_payload_path_finding"
        return result
    }
    result.ok = true
    result.ready = true
    result.diagnostic = "ok"
    result
}

public func ckbQdrantSnapshotBytesHash(bytes: Array<UInt8>): String {
    let digest = SHA256()
    digest.write(bytes)
    let out = StringBuilder()
    for (byte in digest.finish()) {
        out.append(ckbQdrantSnapshotNibble(byte / UInt8(16)))
        out.append(ckbQdrantSnapshotNibble(byte % UInt8(16)))
    }
    "sha256:${out.toString()}"
}

private func ckbQdrantSnapshotValidateStructure(
    manifest: CkbQdrantSnapshotManifest): CkbQdrantSnapshotContract {
    if (manifest.schemaVersion != "ckb-qdrant-snapshot-v1" ||
        !ckbQdrantSnapshotHashValid(manifest.imageDigest) ||
        !ckbQdrantSnapshotCollectionValid(manifest.collection) ||
        manifest.distance.toAsciiLower() != "cosine") {
        return ckbQdrantSnapshotFailure("qdrant_snapshot_identity_invalid")
    }
    if (manifest.qdrantMinorVersion != "1.14") {
        return ckbQdrantSnapshotFailure(
            "qdrant_snapshot_minor_version_mismatch")
    }
    if (manifest.points != 7978) {
        return ckbQdrantSnapshotFailure("qdrant_snapshot_points_mismatch")
    }
    if (manifest.dimension != 1024) {
        return ckbQdrantSnapshotFailure(
            "qdrant_snapshot_dimension_mismatch")
    }
    for (hash in [manifest.snapshotSha256, manifest.logicalManifestHash,
        manifest.vectorProofHash, manifest.payloadCanonicalHash]) {
        if (!ckbQdrantSnapshotHashValid(hash)) {
            return ckbQdrantSnapshotFailure("qdrant_snapshot_hash_invalid")
        }
    }
    ckbQdrantSnapshotSuccess()
}

private func ckbQdrantSnapshotManifestBody(
    manifest: CkbQdrantSnapshotManifest): String {
    "{\"schemaVersion\":\"${ckbQdrantSnapshotJson(manifest.schemaVersion)}\"," +
    "\"imageDigest\":\"${manifest.imageDigest}\"," +
    "\"qdrantMinorVersion\":\"${manifest.qdrantMinorVersion}\"," +
    "\"collection\":\"${ckbQdrantSnapshotJson(manifest.collection)}\"," +
    "\"distance\":\"${ckbQdrantSnapshotJson(manifest.distance)}\"," +
    "\"dimension\":${manifest.dimension},\"points\":${manifest.points}," +
    "\"snapshotSha256\":\"${manifest.snapshotSha256}\"," +
    "\"logicalManifestHash\":\"${manifest.logicalManifestHash}\"," +
    "\"vectorProofHash\":\"${manifest.vectorProofHash}\"," +
    "\"payloadCanonicalHash\":\"${manifest.payloadCanonicalHash}\""
}

private func ckbQdrantSnapshotIdentityValid(
    identity: CkbQdrantSnapshotIdentity): Bool {
    ckbQdrantSnapshotCollectionValid(identity.collection) &&
        ckbQdrantSnapshotHashValid(identity.logicalManifestHash) &&
        ckbQdrantSnapshotHashValid(identity.vectorProofHash)
}

private func ckbQdrantSnapshotCollectionValid(value: String): Bool {
    if (value == "" || value.size > 120) { return false }
    for (rune in value.runes()) {
        if (!((rune >= r'a' && rune <= r'z') ||
            (rune >= r'A' && rune <= r'Z') ||
            (rune >= r'0' && rune <= r'9') ||
            rune == r'-' || rune == r'_')) { return false }
    }
    true
}

private func ckbQdrantSnapshotNameValid(value: String): Bool {
    if (value == "" || value.size > 200 || value.contains("..")) {
        return false
    }
    for (rune in value.runes()) {
        if (!((rune >= r'a' && rune <= r'z') ||
            (rune >= r'A' && rune <= r'Z') ||
            (rune >= r'0' && rune <= r'9') ||
            rune == r'-' || rune == r'_' || rune == r'.')) {
            return false
        }
    }
    true
}

private func ckbQdrantSnapshotHashValid(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 71 || !value.startsWith("sha256:")) { return false }
    for (i in 7..runes.size) {
        if (!((runes[i] >= r'0' && runes[i] <= r'9') ||
            (runes[i] >= r'a' && runes[i] <= r'f'))) { return false }
    }
    true
}

private func ckbQdrantSnapshotString(
    object: JsonObject, key: String): String {
    object.get(key).getOrThrow().asString().getValue()
}

private func ckbQdrantSnapshotInt(
    object: JsonObject, key: String): Int64 {
    object.get(key).getOrThrow().asInt().getValue()
}

private func ckbQdrantSnapshotJson(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"").
        replace("\n", "\\n").replace("\r", "\\r")
}

private func ckbQdrantSnapshotNibble(value: UInt8): Rune {
    if (value < UInt8(10)) {
        return Rune(UInt32(value) + UInt32(r'0'))
    }
    Rune(UInt32(value - UInt8(10)) + UInt32(r'a'))
}

private func ckbQdrantSnapshotFailure(
    diagnostic: String): CkbQdrantSnapshotContract {
    let result = CkbQdrantSnapshotContract()
    result.diagnostic = diagnostic
    result
}

private func ckbQdrantSnapshotSuccess(): CkbQdrantSnapshotContract {
    let result = CkbQdrantSnapshotContract()
    result.ok = true
    result.diagnostic = "ok"
    result
}
