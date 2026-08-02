package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashSet}
import std.fs.{Directory, File, Path, exists, remove}
import std.process.launch
import std.unittest.*
import std.unittest.testmacro.*
import stdx.crypto.digest.SHA256

private func p4RuntimeBuildInputAsset(role: String):
    CkbReproBuildInputAsset {
    let out = CkbReproBuildInputAsset()
    out.role = role
    out.relativePath = "inputs/${role}.json"
    out.size = 2
    out.sha256 = benchmarkGapSha256("{}")
    out
}

private func p4RuntimeBuildInputManifest(): CkbReproBuildInputManifest {
    let out = CkbReproBuildInputManifest()
    out.schemaVersion = "ckb-repro-build-inputs-v1"
    out.candidateVersion = "portable-v1"
    out.targetVersion = "1.0.0"
    out.expectedRawCount = 1
    for (role in ckbReproPublicBuildInputRoles()) {
        out.assets.add(p4RuntimeBuildInputAsset(role))
    }
    out
}

private class P4RuntimeMaterialHandle <: CkbReproSourceMaterialReadHandle {
    private let content: Array<UInt8>
    private let entryIdentity: String
    public var observedEntryIdentity: String
    private var offset: Int64 = 0
    public var maxRequest: Int64 = 0
    public var followSafe: Bool = true
    public init(content: Array<UInt8>, identity: String) {
        this.content = content; this.entryIdentity = identity
        this.observedEntryIdentity = identity
    }
    public func read(maxBytes: Int64): Array<UInt8> {
        if (maxBytes > this.maxRequest) { this.maxRequest = maxBytes }
        if (this.offset >= this.content.size) { return Array<UInt8>() }
        let count = min(maxBytes, this.content.size - this.offset)
        let chunk = this.content[this.offset..this.offset + count].clone()
        this.offset += count; chunk
    }
    public func noFollow(): Bool { this.followSafe }
    public func identity(): String { this.entryIdentity }
    public func observedIdentity(): String { this.observedEntryIdentity }
    public func close(): Unit {}
}

private class P4RuntimeMaterialBackend <: CkbReproMaterializingSourceBackend {
    public var networkCalls: Int64 = 0
    public var materialCalls: Int64 = 0
    public var content: Array<UInt8> = "# 仓颉🙂\n内容\n".toArray()
    public var handle: ?P4RuntimeMaterialHandle = None
    public var followSafe: Bool = true
    public var identityDrift: Bool = false
    public func fetch(entry: CkbReproSourceMaterialEntry):
        CkbReproBackendResult {
        this.networkCalls += 1
        CkbReproBackendResult(true, entry.expectedHash)
    }
    public func generate(entry: CkbReproSourceMaterialEntry):
        CkbReproBackendResult {
        this.materialCalls += 1
        CkbReproBackendResult(true, entry.expectedHash)
    }
    public func open(entry: CkbReproSourceMaterialEntry):
        CkbReproSourceMaterialReadHandle {
        let value = P4RuntimeMaterialHandle(
            this.content, entry.canonicalIdentity)
        if (this.identityDrift) { value.observedEntryIdentity = "drift" }
        value.followSafe = this.followSafe
        this.handle = Some(value); value
    }
}

private class P4RuntimeAssembler <: CkbReproActualSourceAssembler {
    public var calls: Int64 = 0
    public func assemble(materials: CkbReproOwnedSourceMaterials,
        lock: CkbReproSourceLock): CkbReproActualSourceRecords {
        this.calls += 1
        CkbReproActualSourceRecords()
    }
}

private class P4RuntimeMaterializer <: CkbReproOwnedSourceMaterializer {
    public var calls: Int64 = 0
    public var cleanupCalls: Int64 = 0
    public var cleanupOk: Bool = true
    public func materialize(lock: CkbReproSourceLock,
        manifest: CkbReproSourceMaterialsManifest,
        backend: CkbReproMaterializingSourceBackend):
        CkbReproOwnedSourceMaterials {
        this.calls += 1; CkbReproOwnedSourceMaterials()
    }
    public func cleanup(materials: CkbReproOwnedSourceMaterials): Bool {
        this.cleanupCalls += 1; this.cleanupOk
    }
}

private class P4RuntimePipeline <: CkbReproBuildBackend {
    public var calls: Int64 = 0
    public func run(stage: String,
        input: CkbReproPipelineInput): CkbReproBackendResult {
        this.calls += 1
        CkbReproBackendResult(true, "ok")
    }
}

private class P4RuntimeReadHandle <: CkbReproBundleReadHandle {
    private let bytes: Array<UInt8>
    private let entry: CkbReproBundleReadEntry
    private var offset: Int64 = 0
    public var maxRequest: Int64 = 0
    public init(bytes: Array<UInt8>, entry: CkbReproBundleReadEntry) {
        this.bytes = bytes; this.entry = entry
    }
    public func read(buffer: Array<UInt8>): Int64 {
        if (buffer.size > this.maxRequest) { this.maxRequest = buffer.size }
        if (this.offset >= this.bytes.size) { return 0 }
        let count = min(buffer.size, this.bytes.size - this.offset)
        for (i in 0..count) { buffer[i] = this.bytes[this.offset + i] }
        this.offset += count; count
    }
    public func observedEntry(): CkbReproBundleReadEntry { this.entry }
    public func noFollow(): Bool { true }
    public func close(): Unit {}
}

private class P4RuntimeReadBackend <: CkbReproBundleReadBackend {
    private let root: String
    private let bytes: Array<UInt8>
    private let entry: CkbReproBundleReadEntry
    public var handle: ?P4RuntimeReadHandle = None
    public init(root: String, relativePath: String, bytes: Array<UInt8>) {
        this.root = root; this.bytes = bytes
        let item = CkbReproBundleReadEntry()
        item.relativePath = relativePath; item.kind = "regular"
        item.canonicalPath = "${root}/${relativePath}"; item.withinRoot = true
        item.identity = "fixture-id"; item.size = bytes.size
        this.entry = item
    }
    public func rootExists(root: String): Bool { root == this.root }
    public func rootIdentity(root: String): String {
        if (root == this.root) { "fixture-root" } else { "" }
    }
    public func list(root: String): ArrayList<CkbReproBundleReadEntry> {
        let out = ArrayList<CkbReproBundleReadEntry>()
        if (root == this.root) { out.add(this.entry) }; out
    }
    public func open(root: String, expected: CkbReproBundleReadEntry):
        CkbReproBundleReadHandle {
        let value = P4RuntimeReadHandle(this.bytes, this.entry)
        this.handle = Some(value); value
    }
}

private class P4RuntimeMultiReadBackend <: CkbReproBundleReadBackend {
    private let root: String
    private let entries = ArrayList<CkbReproBundleReadEntry>()
    private let values = ArrayList<Array<UInt8>>()
    private let directories = HashSet<String>()
    public var maxRequest: Int64 = 0
    public init(root: String) { this.root = root }
    public func addDirectory(relativePath: String): Unit {
        if (this.directories.contains(relativePath)) { return }
        this.directories.add(relativePath)
        let directory = CkbReproBundleReadEntry()
        directory.relativePath = relativePath; directory.kind = "directory"
        directory.canonicalPath = "${this.root}/${relativePath}"
        directory.withinRoot = true
        directory.identity = "dir-${this.directories.size}"
        this.entries.add(directory); this.values.add(Array<UInt8>())
    }
    public func add(relativePath: String, bytes: Array<UInt8>): Unit {
        let parts = relativePath.split("/"); var current = ""
        for (i in 0..parts.size - 1) {
            current = if (current == "") { parts[i] }
                else { "${current}/${parts[i]}" }
            this.addDirectory(current)
        }
        let entry = CkbReproBundleReadEntry()
        entry.relativePath = relativePath; entry.kind = "regular"
        entry.canonicalPath = "${this.root}/${relativePath}"
        entry.withinRoot = true; entry.identity = "id-${this.entries.size}"
        entry.size = bytes.size; this.entries.add(entry); this.values.add(bytes)
    }
    public func rootExists(root: String): Bool { root == this.root }
    public func rootIdentity(root: String): String {
        if (root == this.root) { "multi-root" } else { "" }
    }
    public func list(root: String): ArrayList<CkbReproBundleReadEntry> {
        let out = ArrayList<CkbReproBundleReadEntry>()
        if (root == this.root) { for (entry in this.entries) { out.add(entry) } }
        out
    }
    public func open(root: String, expected: CkbReproBundleReadEntry):
        CkbReproBundleReadHandle {
        for (i in 0..this.entries.size) {
            if (this.entries[i].relativePath == expected.relativePath) {
                return P4RuntimeReadHandle(this.values[i], this.entries[i])
            }
        }
        throw Exception("missing")
    }
}

private func p4RuntimeHexIdentity(index: Int64): String {
    var value = index.toString()
    while (value.toRuneArray().size < 64) { value = "0" + value }
    "sha256:${value}"
}

private func p4RuntimeRawSha256(bytes: Array<UInt8>): String {
    let digest = SHA256(); digest.write(bytes); let out = StringBuilder()
    for (byte in digest.finish()) {
        out.append(p4RuntimeHexNibble(byte / UInt8(16)))
        out.append(p4RuntimeHexNibble(byte % UInt8(16)))
    }
    out.toString()
}

private func p4RuntimeHexNibble(value: UInt8): String {
    if (value < UInt8(10)) {
        Rune(UInt32(UInt8(0x30) + value)).toString()
    }
    else { Rune(UInt32(UInt8(0x61) + value - UInt8(10))).toString() }
}

private func p4RuntimeSourceLock(sourceId: String): CkbReproSourceLock {
    let lock = CkbReproSourceLock()
    let entry = CkbReproSourceLockEntry()
    entry.sourceId = sourceId; entry.sourceType = "external_git"
    entry.repository = "https://example.invalid/docs.git"
    entry.commit = "0123456789012345678901234567890123456789"
    entry.tree =
        "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    entry.path = "docs/a.md"
    entry.fileHash =
        "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    entry.license = "Apache-2.0"; entry.authMode = "anonymous"
    entry.assemblyRole = "community_docs"
    entry.outputKind = CangjieTypedRecordKinds.DOC_SECTION
    lock.entries.add(entry); lock
}

@Test
public class CkbReproBuildInputsRuntimeTest {
    @TestCase
    public func publicInventoryIdentityIsThirdPartyRecomputableSha256(): Unit {
        let typed = CangjieTypedRecord()
        typed.recordKind = CangjieTypedRecordKinds.DOC_SECTION
        typed.sourceId = "docs/a"; typed.content = "仓颉🙂"
        typed.contentHash = cangjieTypedRecordContentHash(
            typed.sourceId, typed.content)
        let expected = benchmarkGapSha256(
            "ckb-public-record-identity-v1|typed|" +
            canonicalCkbPortableTypedRecord(typed))
        let validated = ckbReproValidatedPublicTypedRecordIdentity(
            typed, CkbPortablePathContext())
        @Expect(validated.ok, true)
        @Expect(validated.identity, expected)
    }

    @TestCase
    public func publicIdentityRejectsPreNormalizedAndDriftedRecords(): Unit {
        let record = CangjieTypedRecord()
        record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
        record.sourceId = "docs/a"; record.content = "portable"
        record.contentHash = cangjieTypedRecordContentHash(
            record.sourceId, record.content)
        let context = CkbPortablePathContext()
        record.path = "/private/tmp/a.md"
        @Expect(ckbReproValidatedPublicTypedRecordIdentity(
            record, context).diagnostic, "unmapped_absolute_path")
        record.path = "{{CKB_PATH:docs}}/a.md"
        @Expect(ckbReproValidatedPublicTypedRecordIdentity(
            record, context).ok, false)
        record.path = "docs/a.md"; record.contentHash = "sha256:drift"
        @Expect(ckbReproValidatedPublicTypedRecordIdentity(
            record, context).diagnostic,
            "portable_typed_content_hash_mismatch")
    }

    @TestCase
    public func publicManifestExcludesPrivateAndDerivedInputs(): Unit {
        @Expect(ckbReproPublicBuildInputRoles(),
            ["build_contract", "source_lock", "source_materials",
             "knowledge_inventory", "knowledge_selection",
             "portable_policy", "api_routes"])
        let manifest = p4RuntimeBuildInputManifest()
        @Expect(validateCkbReproBuildInputManifest(manifest).ok, true)
        for (forbidden in ["local_root_map", "eval_support_authority",
            "leakage_authority", "typed_input", "raw_input"]) {
            let invalid = p4RuntimeBuildInputManifest()
            invalid.assets.add(p4RuntimeBuildInputAsset(forbidden))
            @Expect(validateCkbReproBuildInputManifest(invalid).diagnostic,
                "build_inputs_role_contract_invalid")
        }
    }

    @TestCase
    public func strictControlParsersRejectUnknownDuplicateAndNonCanonicalRows(): Unit {
        let contract =
            "{\"schemaVersion\":\"ckb-repro-build-contract-v1\",\"candidateVersion\":" +
            "\"portable-v1\",\"targetVersion\":\"1.0.0\",\"expectedRawCount\":1," +
            "\"sourceLockHash\":\"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"}"
        @Expect(parseCkbReproBuildContract(
            contract.replace("}", ",\"unknown\":true}").toArray())[0].diagnostic,
            "build_contract_field_contract_invalid")
        @Expect(parseCkbReproBuildContract(
            contract.replace("\"candidateVersion\":\"portable-v1\"",
                "\"candidateVersion\":\"portable-v1\",\"candidateVersion\":\"other\"").toArray())[0].ok,
            false)

        let inventory =
            "{\"identity\":\"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"," +
            "\"sourceId\":\"docs\",\"recordKind\":\"DOC_SECTION\"," +
            "\"portableLocator\":\"ckb-source://docs/a.md\",\"sourceType\":\"external_git\"," +
            "\"license\":\"Apache-2.0\",\"sourceLockEntryHash\":" +
            "\"sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\"}\n"
        @Expect(parseCkbReproKnowledgeInventory(inventory.toArray())[0].ok,
            true)
        @Expect(parseCkbReproKnowledgeInventory(
            (" " + inventory).toArray())[0].diagnostic,
            "knowledge_inventory_noncanonical")
        @Expect(parseCkbReproKnowledgeInventory([0xff, 0xfe])[0].diagnostic,
            "invalid_response_encoding")
    }

    @TestCase
    public func missingPrivateCapabilityFailsBeforeAnyBuildWork(): Unit {
        let material = P4RuntimeMaterialBackend()
        let materializer = P4RuntimeMaterializer()
        let assembler = P4RuntimeAssembler()
        let pipeline = P4RuntimePipeline()
        let result = composeCkbReproProductionBuild(
            "/not-observed", p4RuntimeBuildInputManifest(),
            CkbReproPrivateBuildContext(), CkbReproFilesystemBundleReadBackend(),
            material, materializer, assembler, pipeline)
        @Expect(result.ready, false)
        @Expect(result.diagnostic, "build_private_capability_required")
        @Expect(material.networkCalls, 0)
        @Expect(material.materialCalls, 0)
        @Expect(materializer.calls, 0)
        @Expect(assembler.calls, 0)
        @Expect(pipeline.calls, 0)
    }

    @TestCase
    public func inventoryLoaderStreams7978CanonicalRows(): Unit {
        let text = StringBuilder()
        let lockHash =
            "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
        for (i in 0..7978) {
            let row = CkbReproKnowledgeInventoryRow()
            row.identity = p4RuntimeHexIdentity(i)
            row.sourceId = "docs/${i}"; row.recordKind = "DOC_SECTION"
            row.portableLocator = "ckb-source://docs/${i}.md"
            row.sourceType = "external_git"; row.license = "Apache-2.0"
            row.sourceLockEntryHash = lockHash
            text.append(renderCkbReproKnowledgeInventoryRow(row)); text.append("\n")
        }
        let bytes = text.toString().toArray()
        let asset = p4RuntimeBuildInputAsset("knowledge_inventory")
        asset.relativePath = "inputs/knowledge-inventory.jsonl"
        asset.size = bytes.size
        asset.sha256 = benchmarkGapSha256(text.toString())
        let backend = P4RuntimeReadBackend(
            "/fixture", asset.relativePath, bytes)
        let loaded = loadCkbReproKnowledgeInventoryAsset(
            "/fixture", asset, backend)
        @Expect(loaded.contract.ok, true)
        @Expect(loaded.rows.size, 7978)
        @Expect(loaded.size, bytes.size)
        @Expect(loaded.sha256, asset.sha256)
        match (backend.handle) {
            case Some(handle) => @Expect(handle.maxRequest, 64 * 1024)
            case None => @Expect(false, true)
        }
    }

    @TestCase
    public func actualRecordsCloseInventorySelectionAndExcludeEval(): Unit {
        let record = CangjieTypedRecord()
        record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
        record.sourceId = "docs/a"; record.content = "portable knowledge"
        record.contentHash = cangjieTypedRecordContentHash(
            record.sourceId, record.content)
        let identity = ckbReproValidatedPublicTypedRecordIdentity(
            record, CkbPortablePathContext()).identity
        let lock = p4RuntimeSourceLock(record.sourceId)
        let row = CkbReproKnowledgeInventoryRow()
        row.identity = identity; row.sourceId = record.sourceId
        row.recordKind = record.recordKind; row.portableLocator = "docs/a.md"
        row.sourceType = "external_git"; row.license = "Apache-2.0"
        row.sourceLockEntryHash =
            canonicalCkbReproSourceLockEntryHash(lock.entries[0])
        let inventory = ArrayList<CkbReproKnowledgeInventoryRow>()
        inventory.add(row)
        let selection = buildCkbKnowledgeSelectionManifest(inventory)
        let actual = CkbReproActualSourceRecords()
        actual.ok = true; actual.diagnostic = "ok"; actual.typed.add(record)
        let valid = validateCkbReproActualRecordCoverage(actual, lock,
            inventory, selection, CkbPortablePathContext())
        @Expect(valid.ok, true)
        @Expect(valid.actualCount, 1)
        @Expect(valid.selectedCount, 1)
        let evalRow = CkbReproKnowledgeInventoryRow()
        evalRow.identity = p4RuntimeHexIdentity(9999)
        evalRow.sourceId = row.sourceId
        evalRow.recordKind = CangjieTypedRecordKinds.EVAL_SUPPORT
        evalRow.portableLocator = "eval/support"
        evalRow.sourceType = row.sourceType; evalRow.license = row.license
        evalRow.sourceLockEntryHash = row.sourceLockEntryHash
        inventory.add(evalRow)
        let rejected = validateCkbReproActualRecordCoverage(actual, lock,
            inventory, buildCkbKnowledgeSelectionManifest(inventory),
            CkbPortablePathContext())
        @Expect(rejected.ok, false)
        @Expect(rejected.diagnostic, "eval_support_inventory_forbidden")
    }

    @TestCase
    public func ownedMaterialsCleanupIsExactlyOnceAndFailClosed(): Unit {
        for (ready in [true, false]) {
            let materializer = P4RuntimeMaterializer()
            let result = CkbReproBuildResult(); result.ready = ready
            result.diagnostic = if (ready) { "ok" } else { "pipeline_failed" }
            let finalized = finalizeCkbReproOwnedMaterials(result,
                CkbReproOwnedSourceMaterials(), materializer)
            @Expect(finalized.ready, ready)
            @Expect(materializer.cleanupCalls, 1)
        }
        let failing = P4RuntimeMaterializer(); failing.cleanupOk = false
        let successful = CkbReproBuildResult(); successful.ready = true
        successful.diagnostic = "ok"
        let rejected = finalizeCkbReproOwnedMaterials(successful,
            CkbReproOwnedSourceMaterials(), failing)
        @Expect(rejected.ready, false)
        @Expect(rejected.diagnostic, "owned_source_materials_cleanup_failed")
        @Expect(failing.cleanupCalls, 1)
    }

    @TestCase
    public func largeControlAssetUsesBounded64KiBReads(): Unit {
        let bytes = Array<UInt8>(2 * 1024 * 1024, repeat: UInt8(0x61))
        let asset = p4RuntimeBuildInputAsset("knowledge_selection")
        asset.relativePath = "inputs/knowledge-selection.jsonl"
        asset.size = bytes.size
        asset.sha256 = benchmarkGapSha256(String.fromUtf8(bytes))
        let backend = P4RuntimeReadBackend(
            "/fixture-large", asset.relativePath, bytes)
        let loaded = ckbCaptureBuildInputAsset(
            "/fixture-large", asset, backend)
        @Expect(loaded.contract.ok, true)
        @Expect(loaded.size, bytes.size)
        @Expect(loaded.bytes.size, bytes.size)
        match (backend.handle) {
            case Some(handle) => @Expect(handle.maxRequest, 64 * 1024)
            case None => @Expect(false, true)
        }
    }

    @TestCase
    public func sevenRoleLoaderBindsEveryAssetAndParsesInSequence(): Unit {
        let root = "/fixture-seven"
        let sourceLock =
            "{\"schemaVersion\":\"ckb-source-lock-v1\",\"sources\":[{" +
            "\"sourceId\":\"docs/a\",\"sourceType\":\"external_git\"," +
            "\"repository\":\"https://example.invalid/docs.git\"," +
            "\"commit\":\"0123456789012345678901234567890123456789\"," +
            "\"tree\":\"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," +
            "\"path\":\"docs/a.md\",\"fileHash\":" +
            "\"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"," +
            "\"license\":\"Apache-2.0\",\"authMode\":\"anonymous\"," +
            "\"assemblyRole\":\"community_docs\"," +
            "\"outputKind\":\"DOC_SECTION\"}]}"
        let parsedLock = parseCkbReproSourceLock(sourceLock.toArray())[1]
        let materials = renderCkbSourceMaterialsManifest(
            buildCkbSourceMaterialsManifest(parsedLock))
        let inventoryRow = CkbReproKnowledgeInventoryRow()
        inventoryRow.identity = p4RuntimeHexIdentity(1)
        inventoryRow.sourceId = "docs/a"; inventoryRow.recordKind = "DOC_SECTION"
        inventoryRow.portableLocator = "docs/a.md"
        inventoryRow.sourceType = "external_git"
        inventoryRow.license = "Apache-2.0"
        inventoryRow.sourceLockEntryHash =
            canonicalCkbReproSourceLockEntryHash(parsedLock.entries[0])
        let inventory = renderCkbReproKnowledgeInventoryRow(inventoryRow) + "\n"
        let selectionRow = CkbReproKnowledgeSelectionRow()
        selectionRow.identity = inventoryRow.identity
        selectionRow.recordKind = inventoryRow.recordKind
        selectionRow.decision = "selected"; selectionRow.reason = "knowledge_plane"
        let selection = renderCkbReproKnowledgeSelectionRow(selectionRow) + "\n"
        let policy = String.fromUtf8(File.readFrom(Path(
            "../reproducibility/manifests/portable-path-policy.json")))
        let routes = renderCkbReproApiRoutes(ArrayList<String>())
        let payloads = ArrayList<String>()
        payloads.add(""); payloads.add(sourceLock); payloads.add(materials)
        payloads.add(inventory); payloads.add(selection); payloads.add(policy)
        payloads.add(routes)
        let manifest = CkbReproBuildInputManifest()
        manifest.schemaVersion = "ckb-repro-build-inputs-v1"
        manifest.candidateVersion = "portable-v1"
        manifest.targetVersion = "1.0.0"; manifest.expectedRawCount = 1
        let roles = ckbReproPublicBuildInputRoles()
        for (i in 0..roles.size) {
            let asset = p4RuntimeBuildInputAsset(roles[i])
            asset.relativePath = "inputs/${roles[i]}.json"
            asset.size = payloads[i].toArray().size
            asset.sha256 = benchmarkGapSha256(payloads[i])
            manifest.assets.add(asset)
        }
        let contract = CkbReproBuildContract()
        contract.schemaVersion = "ckb-repro-build-contract-v1"
        contract.candidateVersion = manifest.candidateVersion
        contract.targetVersion = manifest.targetVersion
        contract.expectedRawCount = 1
        contract.sourceLockHash = manifest.assets[1].sha256
        contract.sourceMaterialsHash = manifest.assets[2].sha256
        contract.knowledgeInventoryHash = manifest.assets[3].sha256
        contract.knowledgeSelectionHash = manifest.assets[4].sha256
        contract.portablePolicyHash = manifest.assets[5].sha256
        contract.apiRoutesHash = manifest.assets[6].sha256
        contract.assemblerIdentityHash = ckbFirstInitReproAssemblerIdentityHash()
        contract.privateAuthorityIdentityHash = p4RuntimeHexIdentity(9)
        payloads[0] = renderCkbReproBuildContract(contract)
        manifest.assets[0].size = payloads[0].toArray().size
        manifest.assets[0].sha256 = benchmarkGapSha256(payloads[0])
        let backend = P4RuntimeMultiReadBackend(root)
        for (i in 0..roles.size) {
            backend.add(manifest.assets[i].relativePath, payloads[i].toArray())
        }
        let loaded = loadCkbReproPublicBuildInputs(root, manifest, backend)
        @Expect(loaded.diagnostic, "ok")
        @Expect(loaded.ok, true)
        @Expect(loaded.inventory.size, 1)
        @Expect(loaded.selection.size, 1)
        @Expect(loaded.sourceMaterials.entries.size, 1)
        @Expect(loaded.sourceLock.entries.size, 1)

        contract.assemblerIdentityHash = p4RuntimeHexIdentity(8)
        payloads[0] = renderCkbReproBuildContract(contract)
        manifest.assets[0].size = payloads[0].toArray().size
        manifest.assets[0].sha256 = benchmarkGapSha256(payloads[0])
        let wrongAssembler = P4RuntimeMultiReadBackend(root)
        for (i in 0..roles.size) {
            wrongAssembler.add(manifest.assets[i].relativePath,
                payloads[i].toArray())
        }
        @Expect(loadCkbReproPublicBuildInputs(
            root, manifest, wrongAssembler).diagnostic,
            "build_contract_assembler_identity_mismatch")
        contract.assemblerIdentityHash = ckbFirstInitReproAssemblerIdentityHash()
        payloads[0] = renderCkbReproBuildContract(contract)
        manifest.assets[0].size = payloads[0].toArray().size
        manifest.assets[0].sha256 = benchmarkGapSha256(payloads[0])

        let tampered = P4RuntimeMultiReadBackend(root)
        for (i in 0..roles.size) {
            let bytes = payloads[i].toArray()
            if (roles[i] == "portable_policy") { bytes[0] = UInt8(0x5b) }
            tampered.add(manifest.assets[i].relativePath, bytes)
        }
        let rejected = loadCkbReproPublicBuildInputs(root, manifest, tampered)
        @Expect(rejected.ok, false)
        @Expect(rejected.diagnostic, "build_input_hash_mismatch")
    }

    @TestCase
    public func sevenRoleManifestRejectsSharedPathsAndUndeclaredAssets(): Unit {
        let manifest = p4RuntimeBuildInputManifest()
        manifest.assets[1].relativePath = manifest.assets[0].relativePath
        @Expect(validateCkbReproBuildInputManifest(manifest).diagnostic,
            "build_inputs_role_contract_invalid")

        let clean = p4RuntimeBuildInputManifest()
        let backend = P4RuntimeMultiReadBackend("/fixture-extra")
        for (asset in clean.assets) {
            backend.add(asset.relativePath, "{}".toArray())
        }
        backend.add("inputs/undeclared.json", "{}".toArray())
        let loaded = loadCkbReproPublicBuildInputs(
            "/fixture-extra", clean, backend)
        @Expect(loaded.ok, false)
        @Expect(loaded.diagnostic, "build_inputs_root_contract_invalid")

        let extraDirectory = P4RuntimeMultiReadBackend("/fixture-extra-dir")
        for (asset in clean.assets) {
            extraDirectory.add(asset.relativePath, "{}".toArray())
        }
        extraDirectory.addDirectory("unlisted-empty")
        @Expect(loadCkbReproPublicBuildInputs(
            "/fixture-extra-dir", clean, extraDirectory).diagnostic,
            "build_inputs_root_contract_invalid")
    }

    @TestCase
    public func productionMaterializerWritesActualBytesAndOwnsCleanup(): Unit {
        let root = "target/ckb-repro-owned-materials"
        if (exists(Path(root))) { remove(Path(root), recursive: true) }
        let lock = p4RuntimeSourceLock("docs/a.md")
        lock.entries[0].fileHash = benchmarkGapSha256("# 仓颉🙂\n内容\n")
        let manifest = buildCkbSourceMaterialsManifest(lock)
        let backend = P4RuntimeMaterialBackend()
        let materializer = CkbFilesystemOwnedSourceMaterializer(root)
        let materials = materializer.materialize(lock, manifest, backend)
        @Expect(materials.ok, true)
        @Expect(materials.proofHash.startsWith("sha256:"), true)
        @Expect(materials.proofHash.toRuneArray().size, 71)
        match (backend.handle) {
            case Some(handle) => @Expect(handle.maxRequest, 64 * 1024)
            case None => @Expect(false, true)
        }
        @Expect(String.fromUtf8(File.readFrom(
            Path(root).join("docs").join("docs/a.md"))), "# 仓颉🙂\n内容\n")
        let assembled = CkbFirstInitReproSourceAssembler().assemble(
            materials, lock)
        @Expect(assembled.ok, true)
        @Expect(assembled.typed.size > 0, true)
        for (record in assembled.typed) {
            @Expect(record.recordKind == CangjieTypedRecordKinds.EVAL_SUPPORT,
                false)
        }
        @Expect(materializer.cleanup(materials), true)
        @Expect(exists(Path(root)), false)
    }

    @TestCase
    public func streamingMaterializerRejectsDriftAndCleansPartials(): Unit {
        let existingRoot = "target/ckb-repro-owned-existing"
        if (exists(Path(existingRoot))) {
            remove(Path(existingRoot), recursive: true)
        }
        Directory.create(Path(existingRoot), recursive: true)
        File.writeTo(Path(existingRoot).join("sentinel"), "keep".toArray())
        let lock = p4RuntimeSourceLock("docs/a.md")
        let backend = P4RuntimeMaterialBackend()
        lock.entries[0].fileHash = benchmarkGapSha256("# 仓颉🙂\n内容\n")
        let existing = CkbFilesystemOwnedSourceMaterializer(existingRoot)
        @Expect(existing.materialize(lock,
            buildCkbSourceMaterialsManifest(lock), backend).diagnostic,
            "owned_source_root_invalid")
        @Expect(exists(Path(existingRoot).join("sentinel")), true)
        remove(Path(existingRoot), recursive: true)

        let mismatchRoot = "target/ckb-repro-owned-mismatch"
        if (exists(Path(mismatchRoot))) {
            remove(Path(mismatchRoot), recursive: true)
        }
        lock.entries[0].fileHash = benchmarkGapSha256("different")
        let mismatch = CkbFilesystemOwnedSourceMaterializer(mismatchRoot)
        let partial = mismatch.materialize(lock,
            buildCkbSourceMaterialsManifest(lock), backend)
        @Expect(partial.diagnostic, "source_material_content_hash_mismatch")
        @Expect(mismatch.cleanup(partial), true)
        @Expect(exists(Path(mismatchRoot)), false)

        let driftRoot = "target/ckb-repro-owned-drift"
        if (exists(Path(driftRoot))) { remove(Path(driftRoot), recursive: true) }
        lock.entries[0].fileHash = benchmarkGapSha256("# 仓颉🙂\n内容\n")
        let drift = CkbFilesystemOwnedSourceMaterializer(driftRoot)
        let written = drift.materialize(lock,
            buildCkbSourceMaterialsManifest(lock), backend)
        @Expect(written.ok, true)
        let extra = Path(driftRoot).join("docs").join("extra.md")
        File.writeTo(extra, "extra".toArray())
        @Expect(CkbFirstInitReproSourceAssembler().assemble(
            written, lock).diagnostic, "owned_source_materials_invalid")
        remove(extra)
        let extraDirectory = Path(driftRoot).join("docs").join("extra-dir")
        Directory.create(extraDirectory, recursive: false)
        @Expect(CkbFirstInitReproSourceAssembler().assemble(
            written, lock).diagnostic, "owned_source_materials_invalid")
        remove(extraDirectory, recursive: true)
        let link = Path(driftRoot).join("docs").join("linked.md")
        @Expect(launch("/bin/ln", ["-s", "docs/a.md", link.toString()])
            .wait(), 0)
        @Expect(CkbFirstInitReproSourceAssembler().assemble(
            written, lock).diagnostic, "owned_source_materials_invalid")
        remove(link)
        File.writeTo(Path(driftRoot).join("docs").join("docs/a.md"),
            "tampered".toArray())
        @Expect(CkbFirstInitReproSourceAssembler().assemble(
            written, lock).diagnostic, "owned_source_materials_invalid")
        @Expect(drift.cleanup(written), true)

        let binaryRoot = "target/ckb-repro-owned-binary"
        if (exists(Path(binaryRoot))) { remove(Path(binaryRoot), recursive: true) }
        backend.content = [UInt8(0xff), UInt8(0xfe), UInt8(0x00)]
        lock.entries[0].fileHash = "sha256:" +
            p4RuntimeRawSha256(backend.content)
        let binary = CkbFilesystemOwnedSourceMaterializer(binaryRoot)
        let binaryMaterials = binary.materialize(lock,
            buildCkbSourceMaterialsManifest(lock), backend)
        @Expect(binaryMaterials.ok, true)
        @Expect(CkbFirstInitReproSourceAssembler().assemble(
            binaryMaterials, lock).diagnostic,
            "first_init_source_assembly_failed")
        @Expect(binary.cleanup(binaryMaterials), true)
    }

    @TestCase
    public func streamingMaterializerBoundsMultiMiBAndRejectsUnsafeHandles(): Unit {
        let root = "target/ckb-repro-owned-large"
        if (exists(Path(root))) { remove(Path(root), recursive: true) }
        let bytes = Array<UInt8>(2 * 1024 * 1024, repeat: UInt8(0x61))
        let lock = p4RuntimeSourceLock("docs/large.md")
        lock.entries[0].fileHash = "sha256:" + p4RuntimeRawSha256(bytes)
        let backend = P4RuntimeMaterialBackend(); backend.content = bytes
        let materializer = CkbFilesystemOwnedSourceMaterializer(root)
        let materials = materializer.materialize(lock,
            buildCkbSourceMaterialsManifest(lock), backend)
        @Expect(materials.ok, true)
        match (backend.handle) {
            case Some(handle) => @Expect(handle.maxRequest <= 64 * 1024, true)
            case None => @Expect(false, true)
        }
        @Expect(materializer.cleanup(materials), true)

        let unsafeRoot = "target/ckb-repro-owned-unsafe"
        if (exists(Path(unsafeRoot))) { remove(Path(unsafeRoot), recursive: true) }
        backend.content = "safe".toArray(); backend.followSafe = false
        lock.entries[0].fileHash = benchmarkGapSha256("safe")
        let unsafeMaterializer = CkbFilesystemOwnedSourceMaterializer(unsafeRoot)
        let rejected = unsafeMaterializer.materialize(lock,
            buildCkbSourceMaterialsManifest(lock), backend)
        @Expect(rejected.diagnostic, "source_material_no_follow_required")
        @Expect(unsafeMaterializer.cleanup(rejected), true)

        let identityRoot = "target/ckb-repro-owned-identity"
        if (exists(Path(identityRoot))) {
            remove(Path(identityRoot), recursive: true)
        }
        backend.followSafe = true; backend.identityDrift = true
        let identity = CkbFilesystemOwnedSourceMaterializer(identityRoot)
        let changed = identity.materialize(lock,
            buildCkbSourceMaterialsManifest(lock), backend)
        @Expect(changed.diagnostic, "source_material_entry_changed")
        @Expect(identity.cleanup(changed), true)

        let roleRoot = "target/ckb-repro-owned-role"
        if (exists(Path(roleRoot))) { remove(Path(roleRoot), recursive: true) }
        backend.identityDrift = false; lock.entries[0].assemblyRole = "unknown"
        let invalidRole = CkbFilesystemOwnedSourceMaterializer(roleRoot)
        let roleRejected = invalidRole.materialize(lock,
            buildCkbSourceMaterialsManifest(lock), backend)
        @Expect(roleRejected.diagnostic, "owned_source_target_contract_invalid")
        @Expect(invalidRole.cleanup(roleRejected), true)

        let duplicateRoot = "target/ckb-repro-owned-duplicate"
        if (exists(Path(duplicateRoot))) {
            remove(Path(duplicateRoot), recursive: true)
        }
        let duplicateLock = p4RuntimeSourceLock("a")
        duplicateLock.entries[0].path = "docs/shared.md"
        duplicateLock.entries[0].fileHash = benchmarkGapSha256("safe")
        let another = p4RuntimeSourceLock("b").entries[0]
        another.path = "docs/shared.md"
        another.fileHash = benchmarkGapSha256("safe")
        duplicateLock.entries.add(another)
        let duplicate = CkbFilesystemOwnedSourceMaterializer(duplicateRoot)
        let duplicateResult = duplicate.materialize(duplicateLock,
            buildCkbSourceMaterialsManifest(duplicateLock), backend)
        @Expect(duplicateResult.diagnostic,
            "owned_source_target_contract_invalid")
        @Expect(exists(Path(duplicateRoot)), false)
    }

}
