package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.sort.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.json.*

private class P2RealP3VectorBackend <: CkbPortableVectorBuildBackend {
    public func collectionExists(collection: String): Bool { false }
    public func createEmpty(collection: String, dimension: Int64,
        distance: String): CkbReproContractResult {
        let result = CkbReproContractResult()
        result.ok = true; result.diagnostic = "ok"; result
    }
    public func stagedRebuild(collection: String): CkbPortableVectorBuildEvidence {
        let evidence = CkbPortableVectorBuildEvidence()
        evidence.ready = true; evidence.diagnostic = "ok"
        evidence.collection = collection; evidence.count = 7978
        evidence.dimension = 1024; evidence.distance = "Cosine"
        evidence.payloadCanonicalHash = benchmarkGapSha256("real-payload")
        evidence.machinePathCount = 0; evidence
    }
    public func deleteCollection(collection: String): Unit {}
}

private class P2FakeArchiveBackend <: CkbReleaseArchiveBackend {
    public var listCalls: Int64 = 0
    public var readCalls: Int64 = 0
    public var createCalls: Int64 = 0
    public var createFromFilesCalls: Int64 = 0
    public var tamperPath: String = ""
    public var forcedEntries: ArrayList<CkbReleaseArchiveEntry> =
        ArrayList<CkbReleaseArchiveEntry>()
    private var payloads: ArrayList<CkbReleaseArchivePayload> =
        ArrayList<CkbReleaseArchivePayload>()
    private var capturedPayloads: ArrayList<CkbReleaseArchivePayload> =
        ArrayList<CkbReleaseArchivePayload>()

    public init() {}

    public func create(archivePath: String,
        values: ArrayList<CkbReleaseArchivePayload>): CkbReleaseArchiveOperation {
        this.createCalls += 1
        this.payloads.clear()
        let seed = ArrayList<UInt8>()
        for (value in values) {
            let copy = CkbReleaseArchivePayload()
            copy.path = value.path
            copy.bytes = value.bytes.clone()
            this.payloads.add(copy)
            seed.add(all: value.path.toArray())
            seed.add(UInt8(0))
            seed.add(all: value.bytes)
        }
        File.writeTo(Path(archivePath), seed.toArray())
        let result = CkbReleaseArchiveOperation()
        result.ok = true
        result.diagnostic = "ok"
        result
    }

    public func enumerate(archivePath: String): CkbReleaseArchiveListing {
        this.listCalls += 1
        let result = CkbReleaseArchiveListing()
        result.ok = true
        result.diagnostic = "ok"
        if (this.forcedEntries.size > 0) {
            for (entry in this.forcedEntries) { result.entries.add(entry) }
            return result
        }
        for (value in this.payloads) {
            let entry = CkbReleaseArchiveEntry()
            entry.path = value.path
            entry.kind = CkbReleaseArchiveEntryKinds.REGULAR
            entry.size = value.bytes.size
            result.entries.add(entry)
        }
        result
    }

    public func readRegular(archivePath: String,
        relativePath: String): CkbReleaseArchiveRead {
        this.readCalls += 1
        let result = CkbReleaseArchiveRead()
        for (value in this.payloads) {
            if (value.path == relativePath) {
                result.ok = true
                result.diagnostic = "ok"
                result.bytes = value.bytes.clone()
                if (relativePath == this.tamperPath && result.bytes.size > 0) {
                    result.bytes[0] = result.bytes[0] ^ UInt8(1)
                }
                return result
            }
        }
        result.diagnostic = "archive_entry_missing"
        result
    }

    public func supportsStreaming(): Bool { true }
    public func createFromFiles(archivePath: String,
        values: ArrayList<CkbReleaseArchivePayload>): CkbReleaseArchiveOperation {
        this.createFromFilesCalls += 1
        let materialized = ArrayList<CkbReleaseArchivePayload>()
        this.capturedPayloads.clear()
        for (value in values) {
            let captured = CkbReleaseArchivePayload()
            captured.path = value.path; captured.bytes = value.bytes.clone()
            captured.sourcePath = value.sourcePath; captured.size = value.size
            captured.sha256 = value.sha256; this.capturedPayloads.add(captured)
            let payload = CkbReleaseArchivePayload(); payload.path = value.path
            payload.bytes = if (value.sourcePath == "") { value.bytes.clone() }
                else { File.readFrom(Path(value.sourcePath)) }
            materialized.add(payload)
        }
        this.create(archivePath, materialized)
    }
    public func extractRegularToFile(archivePath: String, relativePath: String,
        outputPath: String, expectedSize: Int64,
        expectedSha256: String): CkbReleaseArchiveOperation {
        CkbReleaseArchiveOperation()
    }
    public func extractAllRegularToDirectory(archivePath: String,
        outputRoot: String, manifest: CkbLogicalSnapshotManifest):
        CkbReleaseArchiveOperation {
        let result = CkbReleaseArchiveOperation()
        for (asset in manifest.assets) {
            var matched: Bool = false
            for (value in this.payloads) {
                if (value.path != asset.relativePath) { continue }
                let bytes = value.bytes.clone()
                if (value.path == this.tamperPath && bytes.size > 0) {
                    bytes[0] = bytes[0] ^ UInt8(1)
                }
                if (bytes.size != asset.size ||
                    ckbLogicalSnapshotBytesHash(bytes) != asset.sha256) {
                    return result
                }
                let target = Path(outputRoot).join(asset.relativePath)
                if (!exists(target.parent)) {
                    Directory.create(target.parent, recursive: true)
                }
                File.writeTo(target, bytes); matched = true; break
            }
            if (!matched) { return result }
        }
        result.ok = true; result.diagnostic = "ok"; result
    }
    public func archiveHash(archivePath: String): String {
        if (exists(Path(archivePath))) {
            ckbLogicalSnapshotBytesHash(File.readFrom(Path(archivePath)))
        } else { "" }
    }

    public func forceCapturedEntries(): Unit {
        this.forcedEntries.clear()
        for (value in this.payloads) {
            let entry = CkbReleaseArchiveEntry()
            entry.path = value.path
            entry.kind = CkbReleaseArchiveEntryKinds.REGULAR
            entry.size = value.bytes.size
            this.forcedEntries.add(entry)
        }
    }

    public func payloadBytes(relativePath: String): Array<UInt8> {
        for (value in this.payloads) {
            if (value.path == relativePath) { return value.bytes.clone() }
        }
        Array<UInt8>()
    }

    public func payloadsForTest(): ArrayList<CkbReleaseArchivePayload> {
        let out = ArrayList<CkbReleaseArchivePayload>()
        for (value in this.capturedPayloads) { out.add(value) }
        out
    }

    public func replacePayload(relativePath: String, bytes: Array<UInt8>): Unit {
        for (value in this.payloads) {
            if (value.path == relativePath) {
                value.bytes = bytes.clone()
                return
            }
        }
    }
}

@Test
public class CkbReproReleaseTest {
    @TestCase
    public func p2ProofJsonEscapesEveryControlRune(): Unit {
        let manifest = CkbLogicalSnapshotManifest()
        var controls = ""
        for (value in 0..32) { controls += Rune(UInt32(value)).toString() }
        manifest.portableKnowledgeVersion = controls
        let json = renderCkbLogicalSnapshotManifest(manifest)
        for (value in 0..32) {
            @Expect(json.contains(Rune(UInt32(value)).toString()), false)
        }
    }

    @TestCase
    public func p2Ut01ManifestCanonicalRoundTripAndSchemaFailClosed(): Unit {
        let manifest = p2Manifest()
        let second = CkbLogicalSnapshotAsset()
        second.relativePath = manifest.assets[0].relativePath
        second.size = manifest.assets[0].size
        second.sha256 = manifest.assets[0].sha256
        manifest.assets.add(second)
        let duplicate = validateCkbLogicalSnapshotManifest(manifest)
        @Expect(duplicate.ok, false)
        @Expect(duplicate.diagnostic, "logical_snapshot_asset_duplicate")
        manifest.assets.remove(at: 1)

        let built = buildCkbLogicalSnapshotManifest(manifest)
        @Expect(built.ok, true)
        let parsed = parseCkbLogicalSnapshotManifest(built.canonicalJson.toArray())
        @Expect(parsed[0].ok, true)
        let validated = validateCkbLogicalSnapshotManifest(parsed[1])
        @Expect(validated.ok, true)
        @Expect(validated.canonicalJson, built.canonicalJson)
        @Expect(validated.manifestHash, built.manifestHash)
        @Expect(parseCkbLogicalSnapshotManifest([0xff, 0xfe])[0].diagnostic,
            "invalid_response_encoding")
        @Expect(parseCkbLogicalSnapshotManifest(
            built.canonicalJson.replace(
                "\"schemaVersion\":\"ckb-logical-snapshot-v1\"",
                "\"schemaVersion\":\"ckb-logical-snapshot-v2\"").toArray())[0].ok,
            true)
        let drift = parseCkbLogicalSnapshotManifest(
            built.canonicalJson.replace(
                "\"schemaVersion\":\"ckb-logical-snapshot-v1\"",
                "\"schemaVersion\":\"ckb-logical-snapshot-v2\"").toArray())[1]
        @Expect(validateCkbLogicalSnapshotManifest(drift).diagnostic,
            "logical_snapshot_schema_mismatch")
        let releaseSchema = String.fromUtf8(File.readFrom(
            Path("../reproducibility/RELEASE-MANIFEST.schema.json")))
        let schemaObject = JsonValue.fromStr(releaseSchema).asObject()
        @Expect(schemaObject.get("title").isSome(), true)
        @Expect(releaseSchema.contains("\"logicalSnapshot\""), true)
        @Expect(releaseSchema.contains("\"vectorSnapshot\""), true)
        let definitions = schemaObject.get("$defs").getOrThrow().asObject()
        let vectorSchema = definitions.get("vectorSnapshot").getOrThrow()
            .asObject()
        let vectorProperties = vectorSchema.get("properties").getOrThrow()
            .asObject()
        @Expect(vectorProperties.get("manifest").isSome(), true)
        @Expect(releaseSchema.contains(
            "\"snapshot\",\n              \"manifest\",\n              \"manifestHash\""),
            true)
        @Expect(releaseSchema.contains("\"environment\""), true)
        @Expect(releaseSchema.contains("\"licenses\""), true)
    }

    @TestCase
    public func p2Bnd01Utf8PathsEncodingPointerDriftAndTargetsAreBounded(): Unit {
        let manifest = p2Manifest()
        for (path in [
            "transactions/tx/raw/仓颉🙂 knowledge.ckb",
            "transactions/tx/raw/${p2LongName()}.ckb"
        ]) {
            manifest.assets[0].relativePath = path
            @Expect(buildCkbLogicalSnapshotManifest(manifest).ok, true)
        }
        for (path in [
            "", "/tmp/a", "C:/a", "../a", "transactions/../a", "transactions\\a",
            "transactions/a\nb", "transactions//a", "./transactions/a"
        ]) {
            manifest.assets[0].relativePath = path
            @Expect(buildCkbLogicalSnapshotManifest(manifest).diagnostic,
                "logical_snapshot_asset_path_invalid")
        }

        let root = p2Root("boundary")
        let store = p2CommittedStore("${root}/store")
        let backend = P2FakeArchiveBackend()
        let policy = p2Policy("${root}/forbidden", store.rootPath())
        let drift = p2Proofs(store)
        drift.expectedEndPointerHash = p2Hash("different")
        let output = "${root}/out/archive.ckb-release"
        let failed = exportCkbLogicalSnapshot(store, drift, output, backend,
            pathPolicy: policy, allowSyntheticProof: true)
        @Expect(failed.ok, false)
        @Expect(failed.diagnostic, "logical_snapshot_pointer_drift")
        @Expect(exists(Path(output)), false)
        @Expect(backend.createCalls, 0)

        Directory.create(Path("${root}/existing"), recursive: true)
        @Expect(importCkbLogicalSnapshot(output, "${root}/existing", backend,
            pathPolicy: policy).diagnostic, "logical_snapshot_target_exists")
        @Expect(exportCkbLogicalSnapshot(store, p2Proofs(store),
            "${root}/missing/out.ckb-release", backend,
            pathPolicy: policy, allowSyntheticProof: true).diagnostic,
            "logical_snapshot_parent_missing")
        let forbiddenPolicy = p2Policy(root, store.rootPath())
        @Expect(exportCkbLogicalSnapshot(store, p2Proofs(store),
            "${root}/inside-worktree.ckb-release", backend,
            pathPolicy: forbiddenPolicy, allowSyntheticProof: true).diagnostic,
            "logical_snapshot_path_forbidden")
        @Expect(exportCkbLogicalSnapshot(store, p2Proofs(store),
            "${store.rootPath()}/inside-production.ckb-release", backend,
            pathPolicy: policy, allowSyntheticProof: true).diagnostic,
            "logical_snapshot_path_forbidden")
        Directory.create(Path(policy.userConfigRoot), recursive: true)
        @Expect(exportCkbLogicalSnapshot(store, p2Proofs(store),
            "${policy.userConfigRoot}/inside-config.ckb-release", backend,
            pathPolicy: policy, allowSyntheticProof: true).diagnostic,
            "logical_snapshot_path_forbidden")
    }

    @TestCase
    public func p2Pos01FakeProofCommittedRoundTripIsDeterministic(): Unit {
        let root = p2Root("positive")
        let store = p2CommittedStore("${root}/source")
        let backend = P2FakeArchiveBackend()
        let policy = p2Policy("${root}/forbidden", store.rootPath())
        let blocked = exportCkbLogicalSnapshot(store, p2Proofs(store),
            "${root}/synthetic-default-blocked.ckb-release", backend,
            pathPolicy: policy)
        @Expect(blocked.diagnostic,
            "logical_snapshot_real_p3_proof_required")
        @Expect(backend.createCalls, 0)
        let firstPath = "${root}/candidate one.ckb-release"
        let first = exportCkbLogicalSnapshot(store, p2Proofs(store), firstPath,
            backend, pathPolicy: policy, allowSyntheticProof: true)
        @Expect(first.ok, true)
        @Expect(backend.createFromFilesCalls, 1)
        for (payload in backend.payloadsForTest()) {
            if (payload.path != "RELEASE-MANIFEST.json") {
                @Expect(payload.bytes.size, 0)
                @Expect(payload.sourcePath == "", false)
                @Expect(payload.size >= 0, true)
                @Expect(payload.sha256.startsWith("sha256:"), true)
            }
        }
        @Expect(first.diagnostic, "ok")
        @Expect(first.evidenceLevel, "fake_proof_dependency")
        @Expect(first.realP3Bound, false)
        let firstBytes = File.readFrom(Path(firstPath))
        let target = "${root}/restored"
        let readsBeforeImport = backend.readCalls
        let restored = importCkbLogicalSnapshot(firstPath, target, backend,
            pathPolicy: policy)
        @Expect(restored.diagnostic, "ok")
        @Expect(restored.ok, true)
        @Expect(restored.activeVersion, p2Version())
        @Expect(restored.rawCount, 1)
        @Expect(restored.normalizedCount, 1)
        @Expect(restored.indexCount, 1)
        @Expect(restored.vectorCollection, "portable_vectors")
        @Expect(backend.readCalls - readsBeforeImport, 1)
        let loaded = FileKnowledgeStore(target).loadActiveSnapshot()
        @Expect(loaded.valid, true)
        @Expect(loaded.activeVersion, p2Version())
        @Expect(ckbCertifiedNormalizedRecordsChecksum(loaded.normalizedRecords),
            first.normalizedChecksum)

        let secondPath = "${root}/production two.ckb-release"
        let production = p2Proofs(store)
        production.sourceState = CkbLogicalSnapshotSourceStates.PROMOTED_PORTABLE_PRODUCTION
        let second = exportCkbLogicalSnapshot(store, production, secondPath,
            backend, pathPolicy: policy, allowSyntheticProof: true)
        @Expect(second.ok, true)
        @Expect(File.readFrom(Path(secondPath)), firstBytes)
        @Expect(second.archiveHash, first.archiveHash)
    }

    @TestCase
    public func p2Neg01UnsafeArchiveAndTamperStopBeforeTargetWrite(): Unit {
        let root = p2Root("negative")
        let store = p2CommittedStore("${root}/source")
        let backend = P2FakeArchiveBackend()
        let policy = p2Policy("${root}/forbidden", store.rootPath())
        let archive = "${root}/source.ckb-release"
        @Expect(exportCkbLogicalSnapshot(store, p2Proofs(store), archive,
            backend, pathPolicy: policy, allowSyntheticProof: true).ok, true)

        for (unsafePath in ["/tmp/escaped", "../escaped",
            "transactions/../escaped", "line\nbreak"]) {
            backend.forcedEntries.clear()
            let attack = CkbReleaseArchiveEntry()
            attack.path = unsafePath
            attack.kind = CkbReleaseArchiveEntryKinds.REGULAR
            attack.size = 0
            backend.forcedEntries.add(attack)
            let readsBefore = backend.readCalls
            let target = "${root}/path-target-${backend.listCalls}"
            @Expect(importCkbLogicalSnapshot(archive, target, backend,
                pathPolicy: policy).diagnostic,
                "logical_snapshot_archive_path_invalid")
            @Expect(exists(Path(target)), false)
            @Expect(backend.readCalls, readsBefore)
        }

        let attackKinds = [
            CkbReleaseArchiveEntryKinds.SYMLINK,
            CkbReleaseArchiveEntryKinds.HARDLINK,
            CkbReleaseArchiveEntryKinds.DEVICE,
            CkbReleaseArchiveEntryKinds.FIFO,
            CkbReleaseArchiveEntryKinds.SOCKET
        ]
        for (kind in attackKinds) {
            backend.forcedEntries.clear()
            let attack = CkbReleaseArchiveEntry()
            attack.path = "safe-attack-entry"
            attack.kind = kind
            attack.size = 0
            backend.forcedEntries.add(attack)
            let readsBefore = backend.readCalls
            let target = "${root}/target-${kind}"
            let result = importCkbLogicalSnapshot(archive, target, backend,
                pathPolicy: policy)
            @Expect(result.ok, false)
            @Expect(exists(Path(target)), false)
            @Expect(backend.readCalls, readsBefore)
        }

        backend.forcedEntries.clear()
        let linkedRegular = CkbReleaseArchiveEntry()
        linkedRegular.path = "safe-linked-entry"
        linkedRegular.kind = CkbReleaseArchiveEntryKinds.REGULAR
        linkedRegular.linkTarget = "other"
        backend.forcedEntries.add(linkedRegular)
        let linkedReads = backend.readCalls
        @Expect(importCkbLogicalSnapshot(archive,
            "${root}/linked-regular-target", backend,
            pathPolicy: policy).diagnostic,
            "logical_snapshot_archive_entry_type_forbidden")
        @Expect(backend.readCalls, linkedReads)

        backend.forceCapturedEntries()
        let duplicate = CkbReleaseArchiveEntry()
        duplicate.path = backend.forcedEntries[0].path
        duplicate.kind = CkbReleaseArchiveEntryKinds.REGULAR
        duplicate.size = backend.forcedEntries[0].size
        backend.forcedEntries.add(duplicate)
        @Expect(importCkbLogicalSnapshot(archive,
            "${root}/duplicate-target", backend,
            pathPolicy: policy).diagnostic,
            "logical_snapshot_archive_entry_duplicate")

        backend.forceCapturedEntries()
        let unmanifested = CkbReleaseArchiveEntry()
        unmanifested.path = "extra/unmanifested.ckb"
        unmanifested.kind = CkbReleaseArchiveEntryKinds.REGULAR
        unmanifested.size = 0
        backend.forcedEntries.add(unmanifested)
        @Expect(importCkbLogicalSnapshot(archive,
            "${root}/unmanifested-target", backend,
            pathPolicy: policy).diagnostic,
            "logical_snapshot_archive_entry_unmanifested")

        backend.forcedEntries.clear()
        let bomb = CkbReleaseArchiveEntry()
        bomb.path = "safe-bomb-entry"
        bomb.kind = CkbReleaseArchiveEntryKinds.REGULAR
        bomb.size = 67108865
        backend.forcedEntries.add(bomb)
        let bombReads = backend.readCalls
        @Expect(importCkbLogicalSnapshot(archive,
            "${root}/bomb-target", backend,
            pathPolicy: policy).diagnostic,
            "logical_snapshot_archive_entry_size_invalid")
        @Expect(backend.readCalls, bombReads)

        backend.forcedEntries.clear()
        let noManifest = CkbReleaseArchiveEntry()
        noManifest.path = "safe-entry"
        noManifest.kind = CkbReleaseArchiveEntryKinds.REGULAR
        noManifest.size = 0
        backend.forcedEntries.add(noManifest)
        @Expect(importCkbLogicalSnapshot(archive,
            "${root}/missing-manifest-target", backend,
            pathPolicy: policy).diagnostic,
            "logical_snapshot_manifest_missing")

        backend.forcedEntries.clear()
        backend.tamperPath = "metadata/active-snapshot.manifest"
        let tamperedTarget = "${root}/tampered-target"
        let tampered = importCkbLogicalSnapshot(archive, tamperedTarget, backend,
            pathPolicy: policy)
        @Expect(tampered.ok, false)
        @Expect(tampered.diagnostic, "logical_snapshot_asset_hash_mismatch")
        @Expect(exists(Path(tamperedTarget)), false)

        backend.tamperPath = ""
        let originalManifest = String.fromUtf8(
            backend.payloadBytes("RELEASE-MANIFEST.json"))
        backend.replacePayload("RELEASE-MANIFEST.json",
            originalManifest.replace("ckb-logical-snapshot-v1",
                "ckb-logical-snapshot-v2").toArray())
        let schemaTarget = "${root}/schema-target"
        let schemaMismatch = importCkbLogicalSnapshot(archive, schemaTarget,
            backend, pathPolicy: policy)
        @Expect(schemaMismatch.diagnostic, "logical_snapshot_schema_mismatch")
        @Expect(exists(Path(schemaTarget)), false)
    }

    @TestCase
    public func p2Reg01ExportIsReadOnlyAndBackupRestoreStillWorks(): Unit {
        let root = p2Root("regression")
        let store = p2CommittedStore("${root}/source")
        let pointerBefore = ckbActiveSnapshotPointerIdentityHash(
            store.loadActiveSnapshotPointer())
        let treeBefore = p2TreeHash(Path(store.rootPath()))
        let servicesBefore = p2BytesHash(File.readFrom(Path("../src/services.cj")))
        let backend = P2FakeArchiveBackend()
        let policy = p2Policy("${root}/forbidden", store.rootPath())
        @Expect(exportCkbLogicalSnapshot(store, p2Proofs(store),
            "${root}/readonly.ckb-release", backend,
            pathPolicy: policy, allowSyntheticProof: true).ok, true)
        @Expect(ckbActiveSnapshotPointerIdentityHash(
            store.loadActiveSnapshotPointer()), pointerBefore)
        @Expect(p2TreeHash(Path(store.rootPath())), treeBefore)
        @Expect(p2BytesHash(File.readFrom(Path("../src/services.cj"))),
            servicesBefore)

        let backup = "${root}/backup"
        let restored = "${root}/legacy-restored"
        @Expect(store.backupActiveSnapshot(backup).ok, true)
        @Expect(FileKnowledgeStore(restored).restoreActiveSnapshotBackup(
            backup).ok, true)
    }

    @TestCase
    public func p2Stream01PortableCodecIsBoundedAndRejectsMalformedArchives(): Unit {
        let root = p2Root("stream-codec")
        let source = "${root}/source.bin"
        let sourceBytes = Array<UInt8>(196608, repeat: UInt8(0x5a))
        File.writeTo(Path(source), sourceBytes)
        let payload = CkbReleaseArchivePayload()
        payload.path = "transactions/tx/raw/large.ckb"
        payload.sourcePath = source
        payload.size = sourceBytes.size
        payload.sha256 = ckbLogicalSnapshotBytesHash(sourceBytes)
        let payloads = ArrayList<CkbReleaseArchivePayload>(); payloads.add(payload)
        let archive = "${root}/large.ckb-release"
        let backend = CkbPortableReleaseArchiveBackend()
        @Expect(backend.createFromFiles(archive, payloads).ok, true)
        @Expect(backend.maxBufferBytes <= 65536, true)
        @Expect(backend.archiveHash(archive).startsWith("sha256:"), true)
        @Expect(backend.maxBufferBytes <= 65536, true)

        let trailing = "${root}/trailing.ckb-release"
        let trailingBytes = ArrayList<UInt8>()
        trailingBytes.add(all: File.readFrom(Path(archive)))
        trailingBytes.add(UInt8(1)); File.writeTo(Path(trailing), trailingBytes.toArray())
        @Expect(backend.enumerate(trailing).ok, false)
        let truncated = "${root}/truncated.ckb-release"
        File.writeTo(Path(truncated), File.readFrom(Path(archive))[0..31])
        @Expect(backend.enumerate(truncated).ok, false)

        let invalidPath = CkbReleaseArchivePayload()
        invalidPath.path = "bad\u{7f}path"; invalidPath.bytes = [UInt8(1)]
        let invalidPayloads = ArrayList<CkbReleaseArchivePayload>()
        invalidPayloads.add(invalidPath)
        let invalidArchive = "${root}/invalid-path.ckb-release"
        @Expect(backend.create(invalidArchive, invalidPayloads).ok, false)

        let duplicatePayloads = ArrayList<CkbReleaseArchivePayload>()
        let duplicate = CkbReleaseArchivePayload(); duplicate.path = payload.path
        duplicate.bytes = [UInt8(2)]
        duplicatePayloads.add(duplicate); duplicatePayloads.add(duplicate)
        @Expect(backend.create("${root}/duplicate.ckb-release",
            duplicatePayloads).ok, false)
        let invalidUtf8 = ArrayList<UInt8>(); invalidUtf8.add(all: "CKBREL01".toArray())
        invalidUtf8.add(all: p2ArchiveIntBytes(1)); invalidUtf8.add(all: p2ArchiveIntBytes(1))
        invalidUtf8.add(all: p2ArchiveIntBytes(0)); invalidUtf8.add(UInt8(0xff))
        let invalidUtf8Path = "${root}/invalid-utf8.ckb-release"
        File.writeTo(Path(invalidUtf8Path), invalidUtf8.toArray())
        @Expect(backend.enumerate(invalidUtf8Path).diagnostic,
            "invalid_response_encoding")
        let excessiveCount = ArrayList<UInt8>()
        excessiveCount.add(all: "CKBREL01".toArray())
        excessiveCount.add(all: p2ArchiveIntBytes(129))
        let excessiveCountPath = "${root}/count.ckb-release"
        File.writeTo(Path(excessiveCountPath), excessiveCount.toArray())
        @Expect(backend.enumerate(excessiveCountPath).ok, false)
        let excessiveEntry = ArrayList<UInt8>()
        excessiveEntry.add(all: "CKBREL01".toArray())
        excessiveEntry.add(all: p2ArchiveIntBytes(1))
        excessiveEntry.add(all: p2ArchiveIntBytes(1))
        excessiveEntry.add(all: p2ArchiveIntBytes(67108865))
        excessiveEntry.add(UInt8(0x61))
        let excessiveEntryPath = "${root}/entry-cap.ckb-release"
        File.writeTo(Path(excessiveEntryPath), excessiveEntry.toArray())
        @Expect(backend.enumerate(excessiveEntryPath).ok, false)
    }

    @TestCase
    public func p2Stream02PreexistingTemporaryPathsAreNeverDeleted(): Unit {
        let root = p2Root("owned-temp")
        let store = p2CommittedStore("${root}/source")
        let backend = P2FakeArchiveBackend()
        let policy = p2Policy("${root}/forbidden", store.rootPath())
        let output = "${root}/owned.ckb-release"
        let preview = exportCkbLogicalSnapshot(store, p2Proofs(store), output,
            backend, pathPolicy: policy, allowSyntheticProof: true)
        @Expect(preview.ok, true)
        remove(Path(output), recursive: true)
        let temporary = "${output}.tmp-export-${preview.manifestHash.replace("sha256:", "")}"
        File.writeTo(Path(temporary), "preexisting".toArray())
        let blocked = exportCkbLogicalSnapshot(store, p2Proofs(store), output,
            backend, pathPolicy: policy, allowSyntheticProof: true)
        @Expect(blocked.ok, false)
        @Expect(blocked.diagnostic, "logical_snapshot_temporary_path_exists")
        @Expect(String.fromUtf8(File.readFrom(Path(temporary))), "preexisting")
        remove(Path(temporary), recursive: true)
        @Expect(exportCkbLogicalSnapshot(store, p2Proofs(store), output,
            backend, pathPolicy: policy, allowSyntheticProof: true).ok, true)
        let target = "${root}/restored"
        let staging = "${target}.tmp-source-${preview.manifestHash.replace("sha256:", "")}"
        Directory.create(Path(staging), recursive: false)
        File.writeTo(Path(staging).join("marker"), "preexisting".toArray())
        let importBlocked = importCkbLogicalSnapshot(output, target, backend,
            pathPolicy: policy)
        @Expect(importBlocked.diagnostic, "logical_snapshot_temporary_path_exists")
        @Expect(String.fromUtf8(File.readFrom(Path(staging).join("marker"))),
            "preexisting")
    }

    @TestCase
    public func p2Stream03TypedProofsAreBoundedAndCrossBound(): Unit {
        let root = p2Root("typed-proofs")
        let logicalPath = "${root}/logical.json"
        let vectorPath = "${root}/vector.json"
        let version = p2Version(); let p4Hash = p2Hash("p4-real")
        let buildOptions = CkbPortableVectorBuildOptions()
        buildOptions.candidateVersion = version
        buildOptions.p4PortableProofHash = p4Hash
        buildOptions.runtimeVectorState = "DEGRADED"
        buildOptions.runtimeVectorDegradedReason = "vector_snapshot_missing"
        buildOptions.runtimeVectorCount = 0
        let p4Proof = CkbReproBuildProof()
        p4Proof.logicalReady = true; p4Proof.diagnostic = "ok"
        p4Proof.vectorState = "DEGRADED"; p4Proof.vectorCount = 0
        p4Proof.candidateVersion = version
        p4Proof.preservationHash = p4Hash
        let environment = CkbReproEnvironmentLock()
        environment.identityStatus = "frozen"
        environment.qdrantImageDigest = p2Hash("real-image")
        environment.embeddingProvider = "real-provider"
        environment.embeddingModel = "real-model"
        environment.embeddingDimension = 1024
        let generated = buildCkbPortableReferenceVectors(buildOptions,
            p4Proof, environment, P2RealP3VectorBackend())
        @Expect(generated.ready, true)
        let vector = renderCkbPortableVectorProof(generated.proof)
        let logical = "{\"sourceState\":\"portableVectorCandidate\"," +
            "\"portableKnowledgeVersion\":\"${version}\"," +
            "\"p4PortableProofHash\":\"${p4Hash}\"," +
            "\"pathMachineFindingCount\":0,\"pathUnmappedFindingCount\":0," +
            "\"contaminationProofHash\":\"${p2Hash("clean")}\"," +
            "\"activePointerHash\":\"${p2Hash("pointer")}\"}"
        File.writeTo(Path(logicalPath), logical.toArray())
        File.writeTo(Path(vectorPath), vector.toArray())
        @Expect(loadCkbLogicalSnapshotCliProofs(logicalPath, vectorPath)[0].diagnostic,
            "ok")
        File.writeTo(Path(vectorPath), vector.replace("\"real-model\"",
            "\"tampered-model\"").toArray())
        @Expect(loadCkbLogicalSnapshotCliProofs(logicalPath, vectorPath)[0].diagnostic,
            "release_proof_cross_binding_mismatch")
        File.writeTo(Path(vectorPath), [UInt8(0xff), UInt8(0xfe)])
        @Expect(loadCkbLogicalSnapshotCliProofs(logicalPath, vectorPath)[0].diagnostic,
            "invalid_response_encoding")
        File.writeTo(Path(vectorPath), Array<UInt8>(65537, repeat: UInt8(0x20)))
        @Expect(loadCkbLogicalSnapshotCliProofs(logicalPath, vectorPath)[0].diagnostic,
            "release_proof_size_invalid")
    }

    @TestCase
    public func p2Stream04ProductionRoundTripUsesBoundedBuffers(): Unit {
        let root = p2Root("production-streaming")
        let store = p2CommittedStore("${root}/source")
        let backend = CkbPortableReleaseArchiveBackend()
        let policy = p2Policy("${root}/forbidden", store.rootPath())
        let archive = "${root}/snapshot.ckb-release"
        let exported = exportCkbLogicalSnapshot(store, p2Proofs(store), archive,
            backend, pathPolicy: policy, allowSyntheticProof: true)
        @Expect(exported.ok, true)
        let target = "${root}/restored"
        let imported = importCkbLogicalSnapshot(archive, target, backend,
            pathPolicy: policy)
        @Expect(imported.ok, true)
        @Expect(imported.activeVersion, p2Version())
        @Expect(backend.maxResidentBufferBytes <= 65536, true)
        @Expect(backend.maxReadBytes <= 65536, true)
        @Expect(backend.maxBufferBytes, backend.maxResidentBufferBytes)
    }
}

private func p2Manifest(): CkbLogicalSnapshotManifest {
    let manifest = CkbLogicalSnapshotManifest()
    manifest.schemaVersion = "ckb-logical-snapshot-v1"
    manifest.sourceState = CkbLogicalSnapshotSourceStates.PORTABLE_VECTOR_ARTIFACT
    manifest.portableKnowledgeVersion = p2Version()
    manifest.p4PortableProofHash = p2Hash("p4")
    manifest.p3VectorProofHash = p2Hash("p3")
    manifest.vectorState = EmbeddingProviderState.READY
    manifest.vectorCollection = "portable_vectors"
    manifest.vectorCount = 1
    manifest.vectorDimension = 1024
    manifest.rawCount = 1
    manifest.normalizedCount = 1
    manifest.normalizedChecksum = p2Hash("normalized")
    manifest.indexCount = 1
    manifest.graphNodeCount = 0
    manifest.graphEdgeCount = 0
    manifest.activePointerHash = p2Hash("pointer")
    manifest.contaminationProofHash = p2Hash("clean")
    let asset = CkbLogicalSnapshotAsset()
    asset.relativePath = "transactions/tx/raw/records.ckb"
    asset.size = 3
    asset.sha256 = p2Hash("raw")
    manifest.assets.add(asset)
    manifest
}

private func p2Proofs(store: FileKnowledgeStore): CkbLogicalSnapshotExportProofs {
    let snapshot = store.loadActiveSnapshot()
    let status = store.loadMetadataStatus()
    let proofs = CkbLogicalSnapshotExportProofs()
    proofs.sourceState = CkbLogicalSnapshotSourceStates.PORTABLE_VECTOR_CANDIDATE
    proofs.portableKnowledgeVersion = snapshot.activeVersion
    proofs.p4PortableProofHash = p2Hash("p4-portable-clean")
    proofs.p3VectorProofHash = p2Hash("p3-vector-ready")
    proofs.p3ProofReal = false
    proofs.vectorState = EmbeddingProviderState.READY
    proofs.vectorCollection = snapshot.vectorActiveCollection
    proofs.vectorCount = status.vectorIndexCount
    proofs.vectorDimension = status.vectorDimension
    proofs.pathMachineFindingCount = 0
    proofs.pathUnmappedFindingCount = 0
    proofs.contaminationProofHash = p2Hash("contamination-clean")
    proofs.expectedStartPointerHash = ckbActiveSnapshotPointerIdentityHash(
        store.loadActiveSnapshotPointer())
    proofs.expectedEndPointerHash = proofs.expectedStartPointerHash
    proofs
}

private func p2CommittedStore(root: String): FileKnowledgeStore {
    if (exists(Path(root))) { remove(Path(root), recursive: true) }
    let store = FileKnowledgeStore(root)
    let raw = RawRecord()
    raw.sourceId = "atom-仓颉🙂"
    raw.title = "ArrayList add"
    raw.content = "使用 add 追加元素"
    raw.contentHash = p2Hash(raw.content)
    raw.metadata.knowledgeVersion = p2Version()
    raw.metadata.targetVersion = "1.0.0"
    let normalized = NormalizedRecord()
    normalized.sourceId = raw.sourceId
    normalized.recordKind = "knowledge_atom"
    normalized.title = raw.title
    normalized.chunk = raw.content
    normalized.citation = "https://docs.cangjie-lang.cn/docs/1.0.0/"
    normalized.metadata = raw.metadata
    let raws = ArrayList<RawRecord>(); raws.add(raw)
    let records = ArrayList<NormalizedRecord>(); records.add(normalized)
    let status = KnowledgeStatus()
    status.activeKnowledgeVersion = p2Version()
    status.activeStateSource = "portable_candidate"
    status.storage.rawCount = 1
    status.storage.normalizedCount = 1
    status.storage.indexCount = 1
    status.storage.textIndexCount = 1
    status.storage.vectorIndexCount = 1
    status.storage.vectorBackend = "qdrant"
    status.storage.vectorState = EmbeddingProviderState.READY
    status.storage.vectorCollection = "portable_vectors"
    status.storage.vectorActiveCollection = "portable_vectors"
    status.storage.vectorCandidateCollection = "portable_vectors_candidate"
    status.storage.vectorDimension = 1024
    status.storage.graphBackend = "local"
    status.storage.graphState = EmbeddingProviderState.READY
    let graph = GraphBuildResult()
    let committed = store.writeActiveSnapshotTransaction(status, raws, records,
        records, ArrayList<VectorRecord>(), "portable_vectors", graph,
        persistVectorFile: false)
    if (!committed.ok) { throw Exception("p2_fixture_commit_failed") }
    store
}

private func p2Policy(forbiddenRoot: String,
    productionStoreRoot: String): CkbReleasePathPolicy {
    let policy = CkbReleasePathPolicy()
    policy.worktreeRoot = forbiddenRoot
    policy.productionStoreRoot = productionStoreRoot
    policy.userConfigRoot = "${forbiddenRoot}/user-config"
    policy
}

private func p2Root(name: String): String {
    let root = "/tmp/ckb-p2-${name}"
    if (exists(Path(root))) { remove(Path(root), recursive: true) }
    Directory.create(Path(root), recursive: true)
    Directory.create(Path("${root}/out"), recursive: true)
    canonicalize(Path(root)).toString()
}

private func p2Version(): String { "portable-knowledge-2026-07-31" }

private func p2Hash(value: String): String { benchmarkGapSha256(value) }

private func p2ArchiveIntBytes(value: Int64): Array<UInt8> {
    let out = ArrayList<UInt8>()
    for (shift in [56, 48, 40, 32, 24, 16, 8, 0]) {
        var divisor: Int64 = 1
        for (_ in 0..(shift / 8)) { divisor *= 256 }
        out.add(UInt8((value / divisor) % 256))
    }
    out.toArray()
}

private func p2BytesHash(bytes: Array<UInt8>): String {
    ckbLogicalSnapshotBytesHash(bytes)
}

private func p2TreeHash(root: Path): String {
    let rows = ArrayList<String>()
    p2CollectTree(root, "", rows)
    let ordered = rows.toArray()
    sort(ordered)
    var seed = ""
    for (row in ordered) { seed += "${row}|" }
    benchmarkGapSha256(seed)
}

private func p2CollectTree(root: Path, prefix: String,
    out: ArrayList<String>): Unit {
    for (entry in Directory.readFrom(root)) {
        let relative = if (prefix == "") { entry.name } else {
            "${prefix}/${entry.name}"
        }
        if (entry.isDirectory()) {
            p2CollectTree(entry.path, relative, out)
        } else if (entry.isRegular()) {
            out.add("${relative}=${p2BytesHash(File.readFrom(entry.path))}")
        }
    }
}

private func p2LongName(): String {
    var value = ""
    for (_ in 0..80) { value += "长" }
    value
}
