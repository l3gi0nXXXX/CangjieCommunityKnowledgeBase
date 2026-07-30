package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashSet}
import std.fs.{Directory, File, Path, canonicalize, exists, remove, rename}
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
    public init() {}
}

public class CkbReleaseArchiveOperation {
    public var ok: Bool = false
    public var diagnostic: String = "archive_operation_failed"
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
        total += entry.size
        if (total > limits.maxTotalBytes) {
            result.diagnostic = "logical_snapshot_archive_total_size_invalid"
            return result
        }
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
        asset.size = payload.bytes.size
        asset.sha256 = ckbLogicalSnapshotBytesHash(payload.bytes)
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
    try {
        if (exists(Path(temporary))) { remove(Path(temporary), recursive: true) }
        let created = backend.create(temporary, archivePayloads)
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
        rename(temporary, to: outputPath, overwrite: false)
        result.archiveHash = ckbLogicalSnapshotBytesHash(
            File.readFrom(Path(outputPath)))
    } catch (_: Exception) {
        result.diagnostic = "logical_snapshot_archive_commit_failed"
        return result
    } finally {
        if (exists(Path(temporary))) {
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
    let payloads = ArrayList<CkbReleaseArchivePayload>()
    for (asset in inspected.manifest.assets) {
        let read = backend.readRegular(archivePath, asset.relativePath)
        if (!read.ok || read.bytes.size != asset.size ||
            ckbLogicalSnapshotBytesHash(read.bytes) != asset.sha256) {
            result.diagnostic = "logical_snapshot_asset_hash_mismatch"
            return result
        }
        let payload = CkbReleaseArchivePayload()
        payload.path = asset.relativePath
        payload.bytes = read.bytes
        payloads.add(payload)
    }
    let staging = ckbLogicalSnapshotTemporaryPath(
        targetRoot, inspected.manifest.manifestHash, "source")
    let targetTemporary = ckbLogicalSnapshotTemporaryPath(
        targetRoot, inspected.manifest.manifestHash, "target")
    try {
        if (exists(Path(staging)) || exists(Path(targetTemporary))) {
            result.diagnostic = "logical_snapshot_temporary_path_exists"
            return result
        }
        Directory.create(Path(staging), recursive: false)
        for (payload in payloads) {
            let target = Path(staging).join(payload.path)
            if (!exists(target.parent)) {
                Directory.create(target.parent, recursive: true)
            }
            File.writeTo(target, payload.bytes)
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
        for (path in [staging, targetTemporary]) {
            if (exists(Path(path))) {
                try { remove(Path(path), recursive: true) } catch (_: Exception) { () }
            }
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
        let bytes = try {
            File.readFrom(sourcePath)
        } catch (_: Exception) {
            return (ckbLogicalSnapshotFailure(
                "logical_snapshot_asset_read_failed"), payloads)
        }
        let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
            return (ckbLogicalSnapshotFailure(
                "invalid_response_encoding"), payloads)
        }
        if (ckbLogicalSnapshotSensitiveText(text)) {
            return (ckbLogicalSnapshotFailure(
                "logical_snapshot_sensitive_content"), payloads)
        }
        let payload = CkbReleaseArchivePayload()
        payload.path = relative
        payload.bytes = bytes
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
        if (rune < r' ') { return false }
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
    value.replace("\\", "\\\\").replace("\"", "\\\"")
        .replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
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
