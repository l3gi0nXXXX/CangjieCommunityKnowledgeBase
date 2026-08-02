package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashMap, HashSet}
import std.fs.{Directory, File, OpenMode, Path, canonicalize, exists, remove}
import std.sort.*
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

public class CkbReproBuildInputAsset {
    public var role: String = ""
    public var relativePath: String = ""
    public var size: Int64 = -1
    public var sha256: String = ""
    public init() {}
}

public class CkbReproBuildInputManifest {
    public var schemaVersion: String = ""
    public var candidateVersion: String = ""
    public var targetVersion: String = ""
    public var expectedRawCount: Int64 = -1
    public let assets = ArrayList<CkbReproBuildInputAsset>()
    public init() {}
}

public class CkbReproBuildContract {
    public var schemaVersion: String = ""
    public var candidateVersion: String = ""
    public var targetVersion: String = ""
    public var expectedRawCount: Int64 = -1
    public var sourceLockHash: String = ""
    public var sourceMaterialsHash: String = ""
    public var knowledgeInventoryHash: String = ""
    public var knowledgeSelectionHash: String = ""
    public var portablePolicyHash: String = ""
    public var apiRoutesHash: String = ""
    public var assemblerIdentityHash: String = ""
    public var privateAuthorityIdentityHash: String = ""
    public init() {}
}

public class CkbReproPrivateBuildContext {
    private var authorized: Bool = false
    private var authority: CkbReproPrivateBuildAuthority =
        CkbReproPrivateBuildAuthority()
    public init() {}
    init(authority: CkbReproPrivateBuildAuthority) {
        this.authorized = true; this.authority = authority
    }
    func permitsBuild(): Bool { this.authorized }
    func buildAuthority(): CkbReproPrivateBuildAuthority { this.authority }
}

public class CkbReproPrivateBuildAuthority {
    public var evalSupport: CangjieEvalSupportSnapshot =
        CangjieEvalSupportSnapshot()
    public var leakage: CangjieBenchmarkLeakageAuthority =
        CangjieBenchmarkLeakageAuthority()
    public var leakageHash: String = ""
    public var pathContext: CkbPortablePathContext = CkbPortablePathContext()
    public var temporaryRoot: String = ""
    public var outputRoot: String = ""
    public init() {}
}

private func issueCkbReproPrivateBuildContext(
    authority: CkbReproPrivateBuildAuthority): CkbReproPrivateBuildContext {
    CkbReproPrivateBuildContext(authority)
}

public class CkbReproOwnedSourceMaterials {
    public var ok: Bool = false
    public var diagnostic: String = "source_materials_not_materialized"
    public var root: String = ""
    public var proofHash: String = ""
    public init() {}
}

public interface CkbReproSourceMaterialReadHandle {
    func read(maxBytes: Int64): Array<UInt8>
    func noFollow(): Bool
    func identity(): String
    func observedIdentity(): String
    func close(): Unit
}

public interface CkbReproMaterializingSourceBackend <:
    CkbReproSourceMaterialBackend {
    func open(entry: CkbReproSourceMaterialEntry):
        CkbReproSourceMaterialReadHandle
}

public class CkbReproActualSourceRecords {
    public var ok: Bool = false
    public var diagnostic: String = "source_records_not_assembled"
    public let typed = ArrayList<CangjieTypedRecord>()
    public let raw = ArrayList<RawRecord>()
    public init() {}
}

public class CkbReproKnowledgeInventoryLoadResult {
    public var contract: CkbReproContractResult = CkbReproContractResult()
    public let rows = ArrayList<CkbReproKnowledgeInventoryRow>()
    public var size: Int64 = 0
    public var sha256: String = ""
    public init() {}
}

public class CkbReproActualCoverageResult {
    public var ok: Bool = false
    public var diagnostic: String = "actual_record_coverage_not_validated"
    public var actualCount: Int64 = 0
    public var selectedCount: Int64 = 0
    public var excludedCount: Int64 = 0
    public init() {}
}

public class CkbReproCapturedBuildInput {
    public var contract: CkbReproContractResult = CkbReproContractResult()
    public var bytes: Array<UInt8> = Array<UInt8>()
    public var size: Int64 = 0
    public var sha256: String = ""
    public init() {}
}

public class CkbReproLoadedBuildInputs {
    public var ok: Bool = false
    public var diagnostic: String = "build_inputs_not_loaded"
    public var buildContract: CkbReproBuildContract = CkbReproBuildContract()
    public var sourceLock: CkbReproSourceLock = CkbReproSourceLock()
    public var sourceMaterials: CkbReproSourceMaterialsManifest =
        CkbReproSourceMaterialsManifest()
    public let inventory = ArrayList<CkbReproKnowledgeInventoryRow>()
    public let selection = ArrayList<CkbReproKnowledgeSelectionRow>()
    public var portablePolicy: CkbPortablePathPolicy = CkbPortablePathPolicy()
    public let apiRoutes = ArrayList<String>()
    public init() {}
}

public interface CkbReproActualSourceAssembler {
    func assemble(materials: CkbReproOwnedSourceMaterials,
        lock: CkbReproSourceLock): CkbReproActualSourceRecords
}

public interface CkbReproOwnedSourceMaterializer {
    func materialize(lock: CkbReproSourceLock,
        manifest: CkbReproSourceMaterialsManifest,
        backend: CkbReproMaterializingSourceBackend):
        CkbReproOwnedSourceMaterials
    func cleanup(materials: CkbReproOwnedSourceMaterials): Bool
}

public class CkbFilesystemOwnedSourceMaterializer <:
    CkbReproOwnedSourceMaterializer {
    private let ownedRoot: String
    public init(ownedRoot: String) { this.ownedRoot = ownedRoot }
    public func materialize(lock: CkbReproSourceLock,
        manifest: CkbReproSourceMaterialsManifest,
        backend: CkbReproMaterializingSourceBackend):
        CkbReproOwnedSourceMaterials {
        let out = CkbReproOwnedSourceMaterials(); out.root = this.ownedRoot
        if (this.ownedRoot == "" || exists(Path(this.ownedRoot)) ||
            !manifest.ready || !validateCkbReproBuildLocks(lock).ok) {
            out.diagnostic = "owned_source_root_invalid"; return out
        }
        let lockById = HashMap<String, CkbReproSourceLockEntry>()
        for (entry in lock.entries) { lockById[entry.sourceId] = entry }
        let proofRows = ArrayList<String>()
        let targetPaths = HashSet<String>()
        for (material in manifest.entries) {
            let source = match (lockById.get(material.sourceId)) {
                case Some(value) => value
                case None =>
                    out.diagnostic = "owned_source_lock_entry_missing"
                    return out
            }
            let roleRoot = ckbReproFirstInitRoleRoot(source.assemblyRole)
            let target = "${roleRoot}/${material.relativePath}"
            if (roleRoot == "" ||
                !validateCkbReproBundleRelativePath(
                    material.relativePath).ok || targetPaths.contains(target)) {
                out.diagnostic = "owned_source_target_contract_invalid"
                return out
            }
            targetPaths.add(target)
        }
        try {
            Directory.create(Path(this.ownedRoot), recursive: false)
            for (material in manifest.entries) {
                let source = match (lockById.get(material.sourceId)) {
                    case Some(value) => value
                    case None =>
                        out.diagnostic = "owned_source_lock_entry_missing"
                        return out
                }
                let roleRoot = ckbReproFirstInitRoleRoot(source.assemblyRole)
                if (roleRoot == "" ||
                    !validateCkbReproBundleRelativePath(
                        material.relativePath).ok) {
                    out.diagnostic = "owned_source_target_contract_invalid"
                    return out
                }
                let target = Path(this.ownedRoot).join(roleRoot)
                    .join(material.relativePath)
                if (!exists(target.parent)) {
                    Directory.create(target.parent, recursive: true)
                }
                let digest = SHA256(); var size: Int64 = 0
                let handle = backend.open(material)
                try {
                    if (!handle.noFollow()) {
                        out.diagnostic = "source_material_no_follow_required"
                        return out
                    }
                    if (handle.identity() != material.canonicalIdentity) {
                        out.diagnostic = "source_material_entry_changed"
                        return out
                    }
                    try (file = File(target, OpenMode.Write)) {
                        while (true) {
                            let chunk = handle.read(64 * 1024)
                            if (chunk.size > 64 * 1024) {
                                out.diagnostic = "source_material_chunk_invalid"
                                return out
                            }
                            if (chunk.size == 0) { break }
                            size += chunk.size
                            if (size > 64 * 1024 * 1024) {
                                out.diagnostic = "source_material_size_exceeded"
                                return out
                            }
                            file.write(chunk); digest.write(chunk)
                        }
                    }
                    if (handle.observedIdentity() !=
                        material.canonicalIdentity) {
                        out.diagnostic = "source_material_entry_changed"
                        return out
                    }
                } finally { handle.close() }
                let actualHash = ckbBuildInputsDigestHash(digest)
                if (size == 0 || actualHash != material.expectedHash) {
                    out.diagnostic = "source_material_content_hash_mismatch"
                    return out
                }
                if (!ckbVerifyOwnedSourceFile(target, size, actualHash)) {
                    out.diagnostic = "owned_source_written_file_mismatch"
                    return out
                }
                proofRows.add("${material.sourceId}|${roleRoot}|" +
                    "${material.relativePath}|${size}|${actualHash}")
            }
            if (proofRows.size != lock.entries.size ||
                proofRows.size != manifest.entries.size) {
                out.diagnostic = "owned_source_material_count_mismatch"
                return out
            }
            let ordered = proofRows.toArray(); sort(ordered)
            out.proofHash = benchmarkGapSha256(
                "ckb-owned-source-materials-v1|" +
                ckbBuildInputsJoin(ordered, "\n"))
            out.ok = true; out.diagnostic = "ok"; out
        } catch (_: Exception) {
            out.diagnostic = "owned_source_materialization_failed"; out
        }
    }
    public func cleanup(materials: CkbReproOwnedSourceMaterials): Bool {
        if (materials.root != this.ownedRoot || this.ownedRoot == "") {
            return false
        }
        try {
            if (exists(Path(this.ownedRoot))) {
                remove(Path(this.ownedRoot), recursive: true)
            }
            true
        } catch (_: Exception) { false }
    }
}

private func ckbVerifyOwnedSourceFile(path: Path, expectedSize: Int64,
    expectedHash: String): Bool {
    let actual = ckbHashOwnedSourceFile(path, expectedSize)
    actual[0] && actual[1] == expectedSize && actual[2] == expectedHash
}

private func ckbHashOwnedSourceFile(path: Path, limit: Int64):
    (Bool, Int64, String) {
    try {
        let digest = SHA256(); var size: Int64 = 0
        try (file = File(path, OpenMode.Read)) {
            let buffer = Array<UInt8>(32 * 1024, repeat: UInt8(0))
            while (true) {
                let count = file.read(buffer)
                if (count < 0 || count > buffer.size) {
                    return (false, size, "")
                }
                if (count == 0) { break }
                let chunk = if (count == buffer.size) { buffer }
                    else { buffer[0..count].clone() }
                digest.write(chunk); size += count
                if (size > limit) { return (false, size, "") }
            }
        }
        (true, size, ckbBuildInputsDigestHash(digest))
    } catch (_: Exception) { (false, 0, "") }
}

private func validateCkbOwnedSourceMaterials(
    materials: CkbReproOwnedSourceMaterials,
    lock: CkbReproSourceLock): Bool {
    let manifest = buildCkbSourceMaterialsManifest(lock)
    if (!materials.ok || !manifest.ready) { return false }
    let lockById = HashMap<String, CkbReproSourceLockEntry>()
    for (entry in lock.entries) { lockById[entry.sourceId] = entry }
    let rows = ArrayList<String>()
    let expectedPaths = HashSet<String>()
    let expectedDirectories = HashSet<String>()
    for (material in manifest.entries) {
        let source = match (lockById.get(material.sourceId)) {
            case Some(value) => value
            case None => return false
        }
        let roleRoot = ckbReproFirstInitRoleRoot(source.assemblyRole)
        if (roleRoot == "") { return false }
        let relativeTarget = "${roleRoot}/${material.relativePath}"
        if (expectedPaths.contains(relativeTarget)) { return false }
        expectedPaths.add(relativeTarget)
        ckbAddOwnedExpectedDirectories(relativeTarget, expectedDirectories)
        let actual = ckbHashOwnedSourceFile(Path(materials.root)
            .join(roleRoot).join(material.relativePath), 64 * 1024 * 1024)
        if (!actual[0] || actual[1] == 0 ||
            actual[2] != material.expectedHash) { return false }
        rows.add("${material.sourceId}|${roleRoot}|${material.relativePath}|" +
            "${actual[1]}|${actual[2]}")
    }
    let listing = CkbOwnedSourceListing()
    try {
        let canonicalRoot = canonicalize(Path(materials.root)).toString()
        ckbCollectOwnedSourceFiles(canonicalRoot, Path(materials.root), "",
            listing)
    } catch (_: Exception) { return false }
    if (!listing.ok || listing.files.size != expectedPaths.size ||
        listing.directories.size != expectedDirectories.size) { return false }
    for (path in expectedPaths) {
        if (!listing.files.contains(path)) { return false }
    }
    for (path in expectedDirectories) {
        if (!listing.directories.contains(path)) { return false }
    }
    let ordered = rows.toArray(); sort(ordered)
    rows.size == lock.entries.size && materials.proofHash ==
        benchmarkGapSha256("ckb-owned-source-materials-v1|" +
            ckbBuildInputsJoin(ordered, "\n"))
}

private class CkbOwnedSourceListing {
    public var ok: Bool = true
    public let files = HashSet<String>()
    public let directories = HashSet<String>()
    public init() {}
}

private func ckbCollectOwnedSourceFiles(canonicalRoot: String, root: Path,
    relativeRoot: String, out: CkbOwnedSourceListing): Unit {
    if (!out.ok) { return }
    try {
        for (entry in Directory.readFrom(root)) {
            let relative = if (relativeRoot == "") { entry.name }
                else { "${relativeRoot}/${entry.name}" }
            let expected = Path(canonicalRoot).join(relative).toString()
            if (canonicalize(entry.path).toString() != expected) {
                out.ok = false; return
            }
            if (entry.isDirectory()) {
                if (out.directories.contains(relative)) {
                    out.ok = false; return
                }
                out.directories.add(relative)
                ckbCollectOwnedSourceFiles(
                    canonicalRoot, entry.path, relative, out)
            } else if (entry.isRegular() && !out.files.contains(relative)) {
                out.files.add(relative)
            } else {
                out.ok = false; return
            }
        }
    } catch (_: Exception) { out.ok = false }
}

private func ckbAddOwnedExpectedDirectories(path: String,
    out: HashSet<String>): Unit {
    let parts = path.split("/")
    var current = ""
    for (i in 0..parts.size - 1) {
        current = if (current == "") { parts[i] }
            else { "${current}/${parts[i]}" }
        out.add(current)
    }
}

private func ckbReproFirstInitRoleRoot(role: String): String {
    if (role == "community_docs" || role == "generated_guidance" ||
        role == "docs") { "docs" }
    else if (role == "tool_docs" || role == "tools") { "tools" }
    else if (role == "std" || role == "std_source") { "std" }
    else if (role == "stdx" || role == "stdx_source") { "stdx" }
    else { "" }
}

public class CkbFirstInitReproSourceAssembler <:
    CkbReproActualSourceAssembler {
    public init() {}
    public func assemble(materials: CkbReproOwnedSourceMaterials,
        lock: CkbReproSourceLock): CkbReproActualSourceRecords {
        let out = CkbReproActualSourceRecords()
        if (!materials.ok || materials.root == "" ||
            !ckbBuildInputsHash(materials.proofHash) ||
            !validateCkbOwnedSourceMaterials(materials, lock)) {
            out.diagnostic = "owned_source_materials_invalid"; return out
        }
        let roots = HashSet<String>()
        for (entry in lock.entries) {
            let roleRoot = ckbReproFirstInitRoleRoot(entry.assemblyRole)
            if (roleRoot == "") {
                out.diagnostic = "owned_source_assembly_role_invalid"
                return out
            }
            roots.add(roleRoot)
        }
        let resolution = CangjieVersionResolution()
        resolution.ok = true; resolution.diagnostic = "ok"
        resolution.targetVersion = cangjieDefaultTargetVersion()
        resolution.versionResolutionId = benchmarkGapSha256(
            "ckb-owned-source-resolution-v1|" +
            canonicalCkbReproSourceLockHash(lock))
        for (roleRoot in ["docs", "tools", "std", "stdx"]) {
            if (!roots.contains(roleRoot)) { continue }
            let scanned = if (roleRoot == "docs" || roleRoot == "tools") {
                scanCangjieDocsRootFull("${materials.root}/${roleRoot}",
                    resolution)
            } else {
                scanCangjieSourceSymbolsRoot("${materials.root}/${roleRoot}",
                    if (roleRoot == "std") { CangjieSourceSets.STD }
                    else { CangjieSourceSets.STDX }, resolution)
            }
            if (!scanned.ok) {
                out.diagnostic = "first_init_source_assembly_failed"
                return out
            }
            for (record in scanned.records) { out.typed.add(record) }
        }
        let deduped = dedupeCkbFirstInitializationRecords(out.typed)
        out.typed.clear(); for (record in deduped) { out.typed.add(record) }
        out.ok = out.typed.size > 0
        out.diagnostic = if (out.ok) { "ok" } else { "source_records_empty" }
        out
    }
}

public func ckbReproPublicBuildInputRoles(): Array<String> {
    ["build_contract", "source_lock", "source_materials",
     "knowledge_inventory", "knowledge_selection", "portable_policy",
     "api_routes"]
}

public func validateCkbReproBuildInputManifest(
    manifest: CkbReproBuildInputManifest): CkbReproContractResult {
    if (manifest.schemaVersion != "ckb-repro-build-inputs-v1" ||
        manifest.candidateVersion.trimAscii() == "" ||
        manifest.targetVersion.trimAscii() == "" ||
        manifest.expectedRawCount < 0) {
        return ckbBuildInputsFailure("build_inputs_manifest_invalid")
    }
    let expected = HashSet<String>(ckbReproPublicBuildInputRoles())
    let seen = HashSet<String>()
    let seenPaths = HashSet<String>()
    for (asset in manifest.assets) {
        if (!expected.contains(asset.role) || seen.contains(asset.role) ||
            seenPaths.contains(asset.relativePath) ||
            !validateCkbReproBundleRelativePath(asset.relativePath).ok ||
            asset.size < 0 || !ckbBuildInputsHash(asset.sha256)) {
            return ckbBuildInputsFailure("build_inputs_role_contract_invalid")
        }
        seen.add(asset.role); seenPaths.add(asset.relativePath)
    }
    if (seen.size != expected.size) {
        return ckbBuildInputsFailure("build_inputs_role_contract_invalid")
    }
    ckbBuildInputsSuccess()
}

func composeCkbReproProductionBuild(root: String,
    manifest: CkbReproBuildInputManifest,
    privateContext: CkbReproPrivateBuildContext,
    reader: CkbReproBundleReadBackend,
    materialBackend: CkbReproMaterializingSourceBackend,
    materializer: CkbReproOwnedSourceMaterializer,
    assembler: CkbReproActualSourceAssembler,
    pipeline: CkbReproBuildBackend): CkbReproBuildResult {
    let out = CkbReproBuildResult()
    if (!privateContext.permitsBuild()) {
        out.diagnostic = "build_private_capability_required"
        return out
    }
    let loaded = loadCkbReproPublicBuildInputs(root, manifest, reader)
    if (!loaded.ok) { out.diagnostic = loaded.diagnostic; return out }
    let authority = privateContext.buildAuthority()
    if (loaded.buildContract.privateAuthorityIdentityHash !=
        ckbReproPrivateBuildAuthorityIdentity(authority)) {
        out.diagnostic = "build_private_authority_identity_mismatch"; return out
    }
    let expectedMaterials = buildCkbSourceMaterialsManifest(loaded.sourceLock)
    if (!expectedMaterials.ready ||
        renderCkbSourceMaterialsManifest(expectedMaterials) !=
            renderCkbSourceMaterialsManifest(loaded.sourceMaterials)) {
        out.diagnostic = "source_materials_lock_mismatch"; return out
    }
    let fetched = fetchAndValidateCkbSourceMaterials(
        loaded.sourceMaterials, materialBackend)
    if (!fetched.ok) { out.diagnostic = fetched.diagnostic; return out }
    let generated = generateAndValidateCkbSourceMaterials(
        loaded.sourceMaterials, materialBackend)
    if (!generated.ok) { out.diagnostic = generated.diagnostic; return out }
    let materials = materializer.materialize(
        loaded.sourceLock, loaded.sourceMaterials, materialBackend)
    var composed = CkbReproBuildResult()
    try {
        composed = ckbComposeOwnedSourceRecords(materials, loaded, manifest,
            authority, assembler, pipeline)
    } catch (_: Exception) {
        composed.diagnostic = "owned_source_composition_failed"
    }
    finalizeCkbReproOwnedMaterials(composed, materials, materializer)
}

func finalizeCkbReproOwnedMaterials(result: CkbReproBuildResult,
    materials: CkbReproOwnedSourceMaterials,
    materializer: CkbReproOwnedSourceMaterializer): CkbReproBuildResult {
    let cleaned = try { materializer.cleanup(materials) }
        catch (_: Exception) { false }
    if (!cleaned) {
        let failed = CkbReproBuildResult()
        failed.diagnostic = "owned_source_materials_cleanup_failed"
        return failed
    }
    result
}

private func ckbComposeOwnedSourceRecords(
    materials: CkbReproOwnedSourceMaterials,
    loaded: CkbReproLoadedBuildInputs,
    manifest: CkbReproBuildInputManifest,
    authority: CkbReproPrivateBuildAuthority,
    assembler: CkbReproActualSourceAssembler,
    pipeline: CkbReproBuildBackend): CkbReproBuildResult {
    let out = CkbReproBuildResult()
    if (!materials.ok || materials.root == "" ||
        !ckbBuildInputsHash(materials.proofHash)) {
        out.diagnostic = if (materials.diagnostic == "") {
            "owned_source_materials_invalid"
        } else { materials.diagnostic }
        return out
    }
    let assembled = assembler.assemble(materials, loaded.sourceLock)
    if (!assembled.ok) { out.diagnostic = assembled.diagnostic; return out }
    let portable = CkbReproActualSourceRecords()
    for (record in assembled.typed) {
        let normalized = normalizeCkbTypedRecordPortablePaths(
            record, authority.pathContext)
        if (!normalized.ok) { out.diagnostic = normalized.diagnostic; return out }
        portable.typed.add(normalized.record)
    }
    for (record in assembled.raw) {
        let normalized = normalizeCkbRawRecordPortablePaths(
            record, authority.pathContext)
        if (!normalized.ok) { out.diagnostic = normalized.diagnostic; return out }
        portable.raw.add(normalized.record)
    }
    portable.ok = true; portable.diagnostic = "ok"
    let coverage = validateCkbReproActualRecordCoverage(
        portable, loaded.sourceLock, loaded.inventory, loaded.selection,
        authority.pathContext)
    if (!coverage.ok || coverage.selectedCount != manifest.expectedRawCount) {
        out.diagnostic = if (!coverage.ok) { coverage.diagnostic }
            else { "actual_selected_count_mismatch" }
        return out
    }
    let request = CkbReproBuildRequest()
    request.sourceLock = loaded.sourceLock
    for (row in loaded.inventory) { request.inventory.add(row) }
    for (row in loaded.selection) { request.selection.add(row) }
    request.pathContext = authority.pathContext
    for (record in portable.typed) { request.typedInput.add(record) }
    for (record in portable.raw) { request.rawInput.add(record) }
    request.candidateVersion = manifest.candidateVersion
    request.options.expectedRawCount = manifest.expectedRawCount
    request.options.temporaryRoot = authority.temporaryRoot
    request.options.outputRoot = authority.outputRoot
    request.evalSupportAuthority = authority.evalSupport
    request.leakageAuthority = authority.leakage
    request.leakageAuthorityHash = authority.leakageHash
    runCkbReproBuild(request, pipeline)
}

public func runCkbReproProductionBuild(root: String,
    manifest: CkbReproBuildInputManifest,
    authority: CkbReproPrivateBuildAuthority,
    reader: CkbReproBundleReadBackend,
    materialBackend: CkbReproMaterializingSourceBackend,
    materializer: CkbReproOwnedSourceMaterializer,
    assembler: CkbReproActualSourceAssembler,
    pipeline: CkbReproBuildBackend): CkbReproBuildResult {
    let out = CkbReproBuildResult()
    let validated = validateVersionedEvalSupportSnapshot(authority.evalSupport)
    if (!validated.ok || authority.evalSupport.recordCount <= 0 ||
        validateCkbPortablePathContext(authority.pathContext).ok == false ||
        authority.temporaryRoot == "" || authority.outputRoot == "" ||
        authority.temporaryRoot == authority.outputRoot ||
        authority.leakageHash != ckbReproLeakageAuthorityHash(authority.leakage)) {
        out.diagnostic = "build_private_authority_invalid"; return out
    }
    composeCkbReproProductionBuild(root, manifest,
        issueCkbReproPrivateBuildContext(authority), reader, materialBackend,
        materializer, assembler, pipeline)
}

public func ckbReproLeakageAuthorityHash(
    authority: CangjieBenchmarkLeakageAuthority): String {
    let values = authority.fingerprints.toArray(); sort(values)
    benchmarkGapSha256("ckb-leakage-authority-v1|" +
        ckbBuildInputsJoin(values, "\n"))
}

public func ckbReproPrivateBuildAuthorityIdentity(
    authority: CkbReproPrivateBuildAuthority): String {
    benchmarkGapSha256("ckb-private-build-authority-v1|" +
        authority.evalSupport.authorityHash + "|" + authority.leakageHash)
}

public func parseCkbReproBuildContract(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbReproBuildContract) {
    let out = CkbReproBuildContract()
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (ckbBuildInputsFailure("invalid_response_encoding"), out)
    }
    if (bytes.size > 64 * 1024) {
        return (ckbBuildInputsFailure("build_contract_size_exceeded"), out)
    }
    try {
        let root = JsonValue.fromStr(text).asObject()
        if (root.size() != 12) {
            return (ckbBuildInputsFailure(
                "build_contract_field_contract_invalid"), out)
        }
        out.schemaVersion = root.get("schemaVersion").getOrThrow().asString().getValue()
        out.candidateVersion = root.get("candidateVersion").getOrThrow().asString().getValue()
        out.targetVersion = root.get("targetVersion").getOrThrow().asString().getValue()
        out.expectedRawCount = root.get("expectedRawCount").getOrThrow()
            .asInt().getValue()
        out.sourceLockHash = ckbBuildInputsString(root, "sourceLockHash")
        out.sourceMaterialsHash = ckbBuildInputsString(root, "sourceMaterialsHash")
        out.knowledgeInventoryHash = ckbBuildInputsString(root, "knowledgeInventoryHash")
        out.knowledgeSelectionHash = ckbBuildInputsString(root, "knowledgeSelectionHash")
        out.portablePolicyHash = ckbBuildInputsString(root, "portablePolicyHash")
        out.apiRoutesHash = ckbBuildInputsString(root, "apiRoutesHash")
        out.assemblerIdentityHash = ckbBuildInputsString(root, "assemblerIdentityHash")
        out.privateAuthorityIdentityHash =
            ckbBuildInputsString(root, "privateAuthorityIdentityHash")
        if (renderCkbReproBuildContract(out) != text) {
            return (ckbBuildInputsFailure("build_contract_noncanonical"),
                CkbReproBuildContract())
        }
        if (out.schemaVersion != "ckb-repro-build-contract-v1" ||
            out.candidateVersion == "" || out.targetVersion == "" ||
            out.expectedRawCount < 0 ||
            !ckbBuildInputsHash(out.sourceLockHash) ||
            !ckbBuildInputsHash(out.sourceMaterialsHash) ||
            !ckbBuildInputsHash(out.knowledgeInventoryHash) ||
            !ckbBuildInputsHash(out.knowledgeSelectionHash) ||
            !ckbBuildInputsHash(out.portablePolicyHash) ||
            !ckbBuildInputsHash(out.apiRoutesHash) ||
            !ckbBuildInputsHash(out.assemblerIdentityHash) ||
            !ckbBuildInputsHash(out.privateAuthorityIdentityHash)) {
            return (ckbBuildInputsFailure("build_contract_invalid"),
                CkbReproBuildContract())
        }
        (ckbBuildInputsSuccess(), out)
    } catch (_: Exception) {
        (ckbBuildInputsFailure("build_contract_malformed_json"),
            CkbReproBuildContract())
    }
}

public func renderCkbReproBuildContract(value: CkbReproBuildContract): String {
    "{\"schemaVersion\":\"${ckbBuildInputsEscape(value.schemaVersion)}\"," +
        "\"candidateVersion\":\"${ckbBuildInputsEscape(value.candidateVersion)}\"," +
        "\"targetVersion\":\"${ckbBuildInputsEscape(value.targetVersion)}\"," +
        "\"expectedRawCount\":${value.expectedRawCount}," +
        "\"sourceLockHash\":\"${value.sourceLockHash}\"," +
        "\"sourceMaterialsHash\":\"${value.sourceMaterialsHash}\"," +
        "\"knowledgeInventoryHash\":\"${value.knowledgeInventoryHash}\"," +
        "\"knowledgeSelectionHash\":\"${value.knowledgeSelectionHash}\"," +
        "\"portablePolicyHash\":\"${value.portablePolicyHash}\"," +
        "\"apiRoutesHash\":\"${value.apiRoutesHash}\"," +
        "\"assemblerIdentityHash\":\"${value.assemblerIdentityHash}\"," +
        "\"privateAuthorityIdentityHash\":\"${value.privateAuthorityIdentityHash}\"}"
}

public func parseCkbReproKnowledgeInventory(bytes: Array<UInt8>):
    (CkbReproContractResult, ArrayList<CkbReproKnowledgeInventoryRow>) {
    let rows = ArrayList<CkbReproKnowledgeInventoryRow>()
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (ckbBuildInputsFailure("invalid_response_encoding"), rows)
    }
    if (bytes.size > 64 * 1024 * 1024) {
        return (ckbBuildInputsFailure("knowledge_inventory_size_exceeded"), rows)
    }
    try {
        if (!text.endsWith("\n")) {
            return (ckbBuildInputsFailure("knowledge_inventory_noncanonical"), rows)
        }
        let lines = text.split("\n")
        for (i in 0..lines.size - 1) {
            if (lines[i].toArray().size > 64 * 1024) {
                return (ckbBuildInputsFailure(
                    "knowledge_inventory_line_size_exceeded"), rows)
            }
            let parsed = ckbParseBuildInventoryRow(lines[i])
            if (!parsed[0].ok) {
                return (ckbBuildInputsFailure("knowledge_inventory_noncanonical"),
                    ArrayList<CkbReproKnowledgeInventoryRow>())
            }
            if (rows.size > 0 && rows[rows.size - 1].identity >=
                parsed[1].identity) {
                return (ckbBuildInputsFailure(
                    "knowledge_inventory_order_invalid"),
                    ArrayList<CkbReproKnowledgeInventoryRow>())
            }
            rows.add(parsed[1])
        }
        (ckbBuildInputsSuccess(), rows)
    } catch (_: Exception) {
        (ckbBuildInputsFailure("knowledge_inventory_malformed_json"),
            ArrayList<CkbReproKnowledgeInventoryRow>())
    }
}

public func loadCkbReproKnowledgeInventoryAsset(root: String,
    asset: CkbReproBuildInputAsset, backend: CkbReproBundleReadBackend):
    CkbReproKnowledgeInventoryLoadResult {
    let out = CkbReproKnowledgeInventoryLoadResult()
    if (asset.role != "knowledge_inventory" || asset.size < 0 ||
        asset.size > 64 * 1024 * 1024 || !ckbBuildInputsHash(asset.sha256)) {
        out.contract = ckbBuildInputsFailure("knowledge_inventory_asset_invalid")
        return out
    }
    var expected = CkbReproBundleReadEntry(); var matches: Int64 = 0
    try {
        if (!backend.rootExists(root) || backend.rootIdentity(root) == "") {
            out.contract = ckbBuildInputsFailure("build_inputs_root_invalid")
            return out
        }
        for (entry in backend.list(root)) {
            if (entry.relativePath == asset.relativePath) {
                expected = entry; matches += 1
            }
        }
        if (matches != 1 || expected.kind != "regular" ||
            !expected.withinRoot || expected.canonicalPath !=
                "${root}/${asset.relativePath}" || expected.size != asset.size ||
            expected.identity == "") {
            out.contract = ckbBuildInputsFailure(
                "knowledge_inventory_entry_invalid")
            return out
        }
        let handle = backend.open(root, expected)
        try {
            if (!handle.noFollow()) {
                out.contract = ckbBuildInputsFailure(
                    "build_input_no_follow_required")
                return out
            }
            let digest = SHA256()
            let pending = ArrayList<UInt8>()
            let buffer = Array<UInt8>(64 * 1024, repeat: UInt8(0))
            while (true) {
                let count = handle.read(buffer)
                if (count < 0 || count > buffer.size) {
                    out.contract = ckbBuildInputsFailure(
                        "build_input_read_failed"); return out
                }
                if (count == 0) { break }
                let chunk = Array<UInt8>(count, repeat: UInt8(0))
                for (i in 0..count) {
                    let byte = buffer[i]; chunk[i] = byte
                    if (byte == UInt8(0x0a)) {
                        if (pending.size == 0) {
                            out.contract = ckbBuildInputsFailure(
                                "knowledge_inventory_noncanonical"); return out
                        }
                        let line = try { String.fromUtf8(pending.toArray()) }
                            catch (_: Exception) {
                                out.contract = ckbBuildInputsFailure(
                                    "invalid_response_encoding"); return out
                            }
                        let parsed = ckbParseBuildInventoryRow(line)
                        if (!parsed[0].ok || (out.rows.size > 0 &&
                            out.rows[out.rows.size - 1].identity >=
                                parsed[1].identity)) {
                            out.contract = ckbBuildInputsFailure(
                                "knowledge_inventory_noncanonical"); return out
                        }
                        out.rows.add(parsed[1]); pending.clear()
                        if (out.rows.size > 100000) {
                            out.contract = ckbBuildInputsFailure(
                                "knowledge_inventory_row_count_exceeded")
                            return out
                        }
                    } else {
                        pending.add(byte)
                        if (pending.size > 64 * 1024) {
                            out.contract = ckbBuildInputsFailure(
                                "knowledge_inventory_line_size_exceeded")
                            return out
                        }
                    }
                }
                out.size += count
                if (out.size > asset.size) {
                    out.contract = ckbBuildInputsFailure(
                        "build_input_size_mismatch"); return out
                }
                digest.write(chunk)
            }
            let observed = handle.observedEntry()
            if (pending.size != 0 || out.size != asset.size ||
                !ckbBuildInputsEntriesEqual(expected, observed)) {
                out.contract = ckbBuildInputsFailure(
                    "build_input_entry_changed"); return out
            }
            out.sha256 = ckbBuildInputsDigestHash(digest)
            if (out.sha256 != asset.sha256) {
                out.contract = ckbBuildInputsFailure(
                    "build_input_hash_mismatch"); return out
            }
            out.contract = ckbBuildInputsSuccess(); out
        } finally {
            try { handle.close() } catch (_: Exception) {
                if (out.contract.ok) {
                    out.contract = ckbBuildInputsFailure(
                        "build_input_close_failed")
                }
            }
        }
    } catch (_: Exception) {
        out.contract = ckbBuildInputsFailure("build_input_read_failed"); out
    }
}

public func loadCkbReproPublicBuildInputs(root: String,
    manifest: CkbReproBuildInputManifest,
    backend: CkbReproBundleReadBackend): CkbReproLoadedBuildInputs {
    let out = CkbReproLoadedBuildInputs()
    let manifestValidation = validateCkbReproBuildInputManifest(manifest)
    if (!manifestValidation.ok) {
        out.diagnostic = manifestValidation.diagnostic; return out
    }
    try {
        let rootIdentity = backend.rootIdentity(root)
        if (!backend.rootExists(root) || rootIdentity == "") {
            out.diagnostic = "build_inputs_root_contract_invalid"; return out
        }
        let declaredPaths = HashSet<String>()
        let declaredDirectories = HashSet<String>()
        for (asset in manifest.assets) {
            declaredPaths.add(asset.relativePath)
            ckbAddBuildInputParentDirectories(
                asset.relativePath, declaredDirectories)
        }
        let listedPaths = HashSet<String>()
        let listedDirectories = HashSet<String>()
        for (entry in backend.list(root)) {
            if (!entry.withinRoot ||
                entry.canonicalPath != "${root}/${entry.relativePath}" ||
                entry.identity == "") {
                out.diagnostic = "build_inputs_root_contract_invalid"
                return out
            }
            if (entry.kind == "regular") {
                if (!declaredPaths.contains(entry.relativePath) ||
                    listedPaths.contains(entry.relativePath)) {
                    out.diagnostic = "build_inputs_root_contract_invalid"; return out
                }
                listedPaths.add(entry.relativePath)
            } else if (entry.kind == "directory") {
                if (!declaredDirectories.contains(entry.relativePath) ||
                    listedDirectories.contains(entry.relativePath)) {
                    out.diagnostic = "build_inputs_root_contract_invalid"; return out
                }
                listedDirectories.add(entry.relativePath)
            } else {
                out.diagnostic = "build_inputs_root_contract_invalid"; return out
            }
        }
        if (listedPaths.size != declaredPaths.size ||
            listedDirectories.size != declaredDirectories.size) {
            out.diagnostic = "build_inputs_root_contract_invalid"; return out
        }
        var captured = ckbCaptureBuildInputAsset(root,
            ckbBuildInputsAsset(manifest, "build_contract"), backend)
        if (!captured.contract.ok) {
            out.diagnostic = captured.contract.diagnostic; return out
        }
        let contract = parseCkbReproBuildContract(captured.bytes)
        if (!contract[0].ok) { out.diagnostic = contract[0].diagnostic; return out }
        out.buildContract = contract[1]
        if (out.buildContract.candidateVersion != manifest.candidateVersion ||
            out.buildContract.targetVersion != manifest.targetVersion ||
            out.buildContract.expectedRawCount != manifest.expectedRawCount) {
            out.diagnostic = "build_contract_manifest_mismatch"; return out
        }
        captured = ckbCaptureBuildInputAsset(root,
            ckbBuildInputsAsset(manifest, "source_lock"), backend)
        if (!captured.contract.ok) {
            out.diagnostic = captured.contract.diagnostic; return out
        }
        let lock = parseCkbReproSourceLock(captured.bytes)
        if (!lock[0].ok) { out.diagnostic = lock[0].diagnostic; return out }
        let lockValidation = validateCkbReproBuildLocks(lock[1])
        if (!lockValidation.ok) {
            out.diagnostic = lockValidation.diagnostic; return out
        }
        out.sourceLock = lock[1]
        captured = ckbCaptureBuildInputAsset(root,
            ckbBuildInputsAsset(manifest, "source_materials"), backend)
        if (!captured.contract.ok) {
            out.diagnostic = captured.contract.diagnostic; return out
        }
        let materials = parseCkbReproSourceMaterialsManifest(captured.bytes)
        if (!materials[0].ok) {
            out.diagnostic = materials[0].diagnostic; return out
        }
        out.sourceMaterials = materials[1]
        let inventoryAsset = ckbBuildInputsAsset(
            manifest, "knowledge_inventory")
        let inventory = loadCkbReproKnowledgeInventoryAsset(
            root, inventoryAsset, backend)
        if (!inventory.contract.ok) {
            out.diagnostic = inventory.contract.diagnostic; return out
        }
        for (row in inventory.rows) { out.inventory.add(row) }
        captured = ckbCaptureBuildInputAsset(root,
            ckbBuildInputsAsset(manifest, "knowledge_selection"), backend)
        if (!captured.contract.ok) {
            out.diagnostic = captured.contract.diagnostic; return out
        }
        let selection = parseCkbReproKnowledgeSelection(captured.bytes)
        if (!selection[0].ok) {
            out.diagnostic = selection[0].diagnostic; return out
        }
        for (row in selection[1]) { out.selection.add(row) }
        captured = ckbCaptureBuildInputAsset(root,
            ckbBuildInputsAsset(manifest, "portable_policy"), backend)
        if (!captured.contract.ok) {
            out.diagnostic = captured.contract.diagnostic; return out
        }
        let policy = parseCkbPortablePathPolicy(captured.bytes)
        if (!policy[0].ok || !validateCkbPortablePathPolicyForBuild(policy[1]).ok) {
            out.diagnostic = "portable_policy_invalid"; return out
        }
        out.portablePolicy = policy[1]
        captured = ckbCaptureBuildInputAsset(root,
            ckbBuildInputsAsset(manifest, "api_routes"), backend)
        if (!captured.contract.ok) {
            out.diagnostic = captured.contract.diagnostic; return out
        }
        let routes = parseCkbReproApiRoutes(captured.bytes)
        if (!routes[0].ok) { out.diagnostic = routes[0].diagnostic; return out }
        for (route in routes[1]) { out.apiRoutes.add(route) }
        if (out.buildContract.sourceLockHash !=
                ckbBuildInputsAssetHash(manifest, "source_lock") ||
            out.buildContract.sourceMaterialsHash !=
                ckbBuildInputsAssetHash(manifest, "source_materials") ||
            out.buildContract.knowledgeInventoryHash !=
                ckbBuildInputsAssetHash(manifest, "knowledge_inventory") ||
            out.buildContract.knowledgeSelectionHash !=
                ckbBuildInputsAssetHash(manifest, "knowledge_selection") ||
            out.buildContract.portablePolicyHash !=
                ckbBuildInputsAssetHash(manifest, "portable_policy") ||
            out.buildContract.apiRoutesHash !=
                ckbBuildInputsAssetHash(manifest, "api_routes")) {
            out.diagnostic = "build_contract_asset_hash_mismatch"; return out
        }
        if (backend.rootIdentity(root) != rootIdentity) {
            out.diagnostic = "build_inputs_root_changed"; return out
        }
        out.ok = true; out.diagnostic = "ok"; out
    } catch (_: Exception) {
        out.diagnostic = "build_inputs_role_missing"; out
    }
}

private func ckbAddBuildInputParentDirectories(path: String,
    out: HashSet<String>): Unit {
    let parts = path.split("/")
    var current = ""
    for (i in 0..parts.size - 1) {
        current = if (current == "") { parts[i] }
            else { "${current}/${parts[i]}" }
        out.add(current)
    }
}

public func parseCkbReproSourceMaterialsManifest(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbReproSourceMaterialsManifest) {
    let out = CkbReproSourceMaterialsManifest()
    if (bytes.size == 0 || bytes.size > 64 * 1024 * 1024) {
        return (ckbBuildInputsFailure("source_materials_size_invalid"), out)
    }
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (ckbBuildInputsFailure("invalid_response_encoding"), out)
    }
    var previous = ""
    try {
        for (line in text.split("\n")) {
            if (line == "" || line.toArray().size > 64 * 1024) {
                return (ckbBuildInputsFailure(
                    "source_materials_noncanonical"), out)
            }
            let fields = line.split("|")
            if (fields.size != 5 || (fields[1] != "fetch_required" &&
                fields[1] != "build_required") ||
                !validateCkbReproBundleRelativePath(fields[2]).ok ||
                !ckbBuildInputsHash(fields[3]) ||
                !ckbBuildInputsHash(fields[4]) ||
                (previous != "" && previous >= line)) {
                return (ckbBuildInputsFailure(
                    "source_materials_noncanonical"), out)
            }
            let entry = CkbReproSourceMaterialEntry()
            entry.sourceId = fields[0]; entry.action = fields[1]
            entry.relativePath = fields[2]; entry.expectedHash = fields[3]
            entry.canonicalIdentity = fields[4]
            out.entries.add(entry); previous = line
        }
        out.ready = true; out.diagnostic = "ok"
        if (renderCkbSourceMaterialsManifest(out) != text) {
            return (ckbBuildInputsFailure(
                "source_materials_noncanonical"),
                CkbReproSourceMaterialsManifest())
        }
        (ckbBuildInputsSuccess(), out)
    } catch (_: Exception) {
        (ckbBuildInputsFailure("source_materials_malformed"),
            CkbReproSourceMaterialsManifest())
    }
}

public func renderCkbReproKnowledgeSelectionRow(
    row: CkbReproKnowledgeSelectionRow): String {
    "{\"identity\":\"${ckbBuildInputsEscape(row.identity)}\"," +
        "\"recordKind\":\"${ckbBuildInputsEscape(row.recordKind)}\"," +
        "\"decision\":\"${ckbBuildInputsEscape(row.decision)}\"," +
        "\"reason\":\"${ckbBuildInputsEscape(row.reason)}\"}"
}

public func parseCkbReproKnowledgeSelection(bytes: Array<UInt8>):
    (CkbReproContractResult, ArrayList<CkbReproKnowledgeSelectionRow>) {
    let out = ArrayList<CkbReproKnowledgeSelectionRow>()
    if (bytes.size == 0 || bytes.size > 64 * 1024 * 1024) {
        return (ckbBuildInputsFailure("knowledge_selection_size_invalid"), out)
    }
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (ckbBuildInputsFailure("invalid_response_encoding"), out)
    }
    if (!text.endsWith("\n")) {
        return (ckbBuildInputsFailure("knowledge_selection_noncanonical"), out)
    }
    var previous = ""
    try {
        let lines = text.split("\n")
        for (i in 0..lines.size - 1) {
            let line = lines[i]
            if (line.toArray().size > 64 * 1024) {
                return (ckbBuildInputsFailure(
                    "knowledge_selection_line_size_exceeded"), out)
            }
            let object = JsonValue.fromStr(line).asObject()
            if (object.size() != 4) {
                return (ckbBuildInputsFailure(
                    "knowledge_selection_field_contract_invalid"), out)
            }
            let row = CkbReproKnowledgeSelectionRow()
            row.identity = ckbBuildInputsString(object, "identity")
            row.recordKind = ckbBuildInputsString(object, "recordKind")
            row.decision = ckbBuildInputsString(object, "decision")
            row.reason = ckbBuildInputsString(object, "reason")
            if (!ckbBuildInputsHash(row.identity) || row.recordKind == "" ||
                (row.decision != "selected" && row.decision != "excluded") ||
                row.reason == "" || renderCkbReproKnowledgeSelectionRow(row) !=
                    line || (previous != "" && previous >= row.identity)) {
                return (ckbBuildInputsFailure(
                    "knowledge_selection_noncanonical"),
                    ArrayList<CkbReproKnowledgeSelectionRow>())
            }
            previous = row.identity; out.add(row)
        }
        (ckbBuildInputsSuccess(), out)
    } catch (_: Exception) {
        (ckbBuildInputsFailure("knowledge_selection_malformed_json"),
            ArrayList<CkbReproKnowledgeSelectionRow>())
    }
}

public func parseCkbReproApiRoutes(bytes: Array<UInt8>):
    (CkbReproContractResult, ArrayList<String>) {
    let routes = ArrayList<String>()
    if (bytes.size > 64 * 1024) {
        return (ckbBuildInputsFailure("api_routes_size_exceeded"), routes)
    }
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (ckbBuildInputsFailure("invalid_response_encoding"), routes)
    }
    try {
        let object = JsonValue.fromStr(text).asObject()
        if (object.size() != 2 || ckbBuildInputsString(
            object, "schemaVersion") != "ckb-api-routes-v1") {
            return (ckbBuildInputsFailure("api_routes_field_contract_invalid"), routes)
        }
        var previous = ""
        for (value in object.get("routes").getOrThrow().asArray().getItems()) {
            let route = value.asString().getValue()
            if (!route.startsWith("/") || route.contains("..") ||
                route.contains("\\") || route.trimAscii() != route ||
                (previous != "" && previous >= route)) {
                return (ckbBuildInputsFailure("api_routes_invalid"),
                    ArrayList<String>())
            }
            routes.add(route); previous = route
        }
        if (renderCkbReproApiRoutes(routes) != text) {
            return (ckbBuildInputsFailure("api_routes_noncanonical"),
                ArrayList<String>())
        }
        (ckbBuildInputsSuccess(), routes)
    } catch (_: Exception) {
        (ckbBuildInputsFailure("api_routes_malformed_json"), ArrayList<String>())
    }
}

public func renderCkbReproApiRoutes(routes: ArrayList<String>): String {
    var values = "["
    for (i in 0..routes.size) {
        if (i > 0) { values += "," }
        values += "\"${ckbBuildInputsEscape(routes[i])}\""
    }
    "{\"schemaVersion\":\"ckb-api-routes-v1\",\"routes\":${values}]}"
}

func ckbCaptureBuildInputAsset(root: String,
    asset: CkbReproBuildInputAsset, backend: CkbReproBundleReadBackend):
    CkbReproCapturedBuildInput {
    let out = CkbReproCapturedBuildInput()
    let limit: Int64 = if (asset.role == "build_contract" ||
        asset.role == "portable_policy" || asset.role == "api_routes") {
        64 * 1024
    } else { 16 * 1024 * 1024 }
    if (asset.size < 0 || asset.size > limit) {
        out.contract = ckbBuildInputsFailure("build_input_size_exceeded"); return out
    }
    var expected = CkbReproBundleReadEntry(); var matches: Int64 = 0
    try {
        if (!backend.rootExists(root) || backend.rootIdentity(root) == "") {
            out.contract = ckbBuildInputsFailure("build_inputs_root_invalid"); return out
        }
        for (entry in backend.list(root)) {
            if (entry.relativePath == asset.relativePath) {
                expected = entry; matches += 1
            }
        }
        if (matches != 1 || expected.kind != "regular" ||
            !expected.withinRoot || expected.canonicalPath !=
                "${root}/${asset.relativePath}" || expected.size != asset.size ||
            expected.identity == "") {
            out.contract = ckbBuildInputsFailure("build_input_entry_invalid"); return out
        }
        let handle = backend.open(root, expected)
        try {
            if (!handle.noFollow()) {
                out.contract = ckbBuildInputsFailure(
                    "build_input_no_follow_required"); return out
            }
            let digest = SHA256(); let bytes = ArrayList<UInt8>()
            let buffer = Array<UInt8>(64 * 1024, repeat: UInt8(0))
            while (true) {
                let count = handle.read(buffer)
                if (count < 0 || count > buffer.size) {
                    out.contract = ckbBuildInputsFailure(
                        "build_input_read_failed"); return out
                }
                if (count == 0) { break }
                let chunk = Array<UInt8>(count, repeat: UInt8(0))
                for (i in 0..count) { chunk[i] = buffer[i]; bytes.add(buffer[i]) }
                out.size += count
                if (out.size > asset.size || out.size > limit) {
                    out.contract = ckbBuildInputsFailure(
                        "build_input_size_mismatch"); return out
                }
                digest.write(chunk)
            }
            if (out.size != asset.size || !ckbBuildInputsEntriesEqual(
                expected, handle.observedEntry())) {
                out.contract = ckbBuildInputsFailure(
                    "build_input_entry_changed"); return out
            }
            out.sha256 = ckbBuildInputsDigestHash(digest)
            if (out.sha256 != asset.sha256) {
                out.contract = ckbBuildInputsFailure(
                    "build_input_hash_mismatch"); return out
            }
            out.bytes = bytes.toArray(); out.contract = ckbBuildInputsSuccess(); out
        } finally {
            try { handle.close() } catch (_: Exception) {
                if (out.contract.ok) {
                    out.contract = ckbBuildInputsFailure("build_input_close_failed")
                }
            }
        }
    } catch (_: Exception) {
        out.contract = ckbBuildInputsFailure("build_input_read_failed"); out
    }
}

private func ckbBuildInputsAssetHash(manifest: CkbReproBuildInputManifest,
    role: String): String {
    for (asset in manifest.assets) { if (asset.role == role) { return asset.sha256 } }
    ""
}

private func ckbBuildInputsAsset(manifest: CkbReproBuildInputManifest,
    role: String): CkbReproBuildInputAsset {
    for (asset in manifest.assets) { if (asset.role == role) { return asset } }
    throw Exception("build input role missing")
}

private func ckbParseBuildInventoryRow(line: String):
    (CkbReproContractResult, CkbReproKnowledgeInventoryRow) {
    let row = CkbReproKnowledgeInventoryRow()
    try {
        let object = JsonValue.fromStr(line).asObject()
        if (object.size() != 7) {
            return (ckbBuildInputsFailure(
                "knowledge_inventory_field_contract_invalid"), row)
        }
        row.identity = ckbBuildInputsString(object, "identity")
        row.sourceId = ckbBuildInputsString(object, "sourceId")
        row.recordKind = ckbBuildInputsString(object, "recordKind")
        row.portableLocator = ckbBuildInputsString(object, "portableLocator")
        row.sourceType = ckbBuildInputsString(object, "sourceType")
        row.license = ckbBuildInputsString(object, "license")
        row.sourceLockEntryHash = ckbBuildInputsString(
            object, "sourceLockEntryHash")
        if (renderCkbReproKnowledgeInventoryRow(row) != line ||
            !ckbBuildInputsHash(row.identity) || row.sourceId == "" ||
            row.recordKind == "" || row.portableLocator == "" ||
            row.portableLocator.startsWith("/") ||
            row.portableLocator.contains("{{CKB_PATH:") ||
            (row.sourceType != "external_git" &&
                row.sourceType != "generated") || row.license == "" ||
            !ckbBuildInputsHash(row.sourceLockEntryHash)) {
            return (ckbBuildInputsFailure(
                "knowledge_inventory_noncanonical"), row)
        }
        (ckbBuildInputsSuccess(), row)
    } catch (_: Exception) {
        (ckbBuildInputsFailure("knowledge_inventory_malformed_json"), row)
    }
}

private func ckbBuildInputsEntriesEqual(left: CkbReproBundleReadEntry,
    right: CkbReproBundleReadEntry): Bool {
    left.relativePath == right.relativePath && left.kind == right.kind &&
        left.canonicalPath == right.canonicalPath &&
        left.withinRoot == right.withinRoot &&
        left.identity == right.identity && left.size == right.size
}

private func ckbBuildInputsDigestHash(digest: SHA256): String {
    let digits = "0123456789abcdef".toRuneArray()
    let out = StringBuilder()
    for (byte in digest.finish()) {
        out.append(digits[Int64(byte / UInt8(16))])
        out.append(digits[Int64(byte % UInt8(16))])
    }
    "sha256:${out.toString()}"
}

public func renderCkbReproKnowledgeInventoryRow(
    row: CkbReproKnowledgeInventoryRow): String {
    "{\"identity\":\"${ckbBuildInputsEscape(row.identity)}\"," +
        "\"sourceId\":\"${ckbBuildInputsEscape(row.sourceId)}\"," +
        "\"recordKind\":\"${ckbBuildInputsEscape(row.recordKind)}\"," +
        "\"portableLocator\":\"${ckbBuildInputsEscape(row.portableLocator)}\"," +
        "\"sourceType\":\"${ckbBuildInputsEscape(row.sourceType)}\"," +
        "\"license\":\"${ckbBuildInputsEscape(row.license)}\"," +
        "\"sourceLockEntryHash\":\"${row.sourceLockEntryHash}\"}"
}

public class CkbReproPublicRecordIdentityResult {
    public var ok: Bool = false
    public var diagnostic: String = "public_record_not_validated"
    public var identity: String = ""
    public init() {}
}

public func ckbReproValidatedPublicTypedRecordIdentity(
    record: CangjieTypedRecord, context: CkbPortablePathContext):
    CkbReproPublicRecordIdentityResult {
    let out = CkbReproPublicRecordIdentityResult()
    if (canonicalCkbPortableTypedRecord(record).contains("{{CKB_PATH:")) {
        out.diagnostic = "portable_placeholder_unresolved"; return out
    }
    let validation = validateCkbPortableTypedRecord(record, context)
    if (!validation.ok) { out.diagnostic = validation.diagnostic; return out }
    out.identity = ckbReproPublicTypedRecordIdentity(record)
    out.ok = true; out.diagnostic = "ok"; out
}

public func ckbReproValidatedPublicRawRecordIdentity(record: RawRecord,
    context: CkbPortablePathContext): CkbReproPublicRecordIdentityResult {
    let out = CkbReproPublicRecordIdentityResult()
    if (canonicalCkbPortableRawRecord(record).contains("{{CKB_PATH:")) {
        out.diagnostic = "portable_placeholder_unresolved"; return out
    }
    let scan = scanCkbRawPathOccurrences(record, context)
    if (!scan.ready) { out.diagnostic = scan.diagnostic; return out }
    let metadata = validateCkbPortableMetadata(record.metadata, context)
    if (!metadata.ok) { out.diagnostic = metadata.diagnostic; return out }
    if (record.contentHash !=
        cangjieTypedRecordContentHash(record.sourceId, record.content)) {
        out.diagnostic = "portable_raw_content_hash_mismatch"; return out
    }
    out.identity = ckbReproPublicRawRecordIdentity(record)
    out.ok = true; out.diagnostic = "ok"; out
}

public func validateCkbReproActualRecordCoverage(
    records: CkbReproActualSourceRecords, lock: CkbReproSourceLock,
    inventory: ArrayList<CkbReproKnowledgeInventoryRow>,
    selection: ArrayList<CkbReproKnowledgeSelectionRow>,
    context: CkbPortablePathContext): CkbReproActualCoverageResult {
    let out = CkbReproActualCoverageResult()
    let lockValidation = validateCkbReproBuildLocks(lock)
    if (!lockValidation.ok) { out.diagnostic = lockValidation.diagnostic; return out }
    if (!records.ok) { out.diagnostic = records.diagnostic; return out }
    let locks = HashMap<String, CkbReproSourceLockEntry>()
    for (entry in lock.entries) { locks[entry.sourceId] = entry }
    let inventoryById = HashMap<String, CkbReproKnowledgeInventoryRow>()
    for (row in inventory) {
        if (ckbBuildInputsEvaluationKind(row.recordKind)) {
            out.diagnostic = "eval_support_inventory_forbidden"; return out
        }
        if (inventoryById.contains(row.identity) || !locks.contains(row.sourceId)) {
            out.diagnostic = "actual_inventory_mapping_invalid"; return out
        }
        let source = locks.get(row.sourceId).getOrThrow()
        if (row.sourceType != source.sourceType || row.license != source.license ||
            row.sourceLockEntryHash !=
                canonicalCkbReproSourceLockEntryHash(source)) {
            out.diagnostic = "actual_inventory_source_lock_mismatch"; return out
        }
        inventoryById[row.identity] = row
    }
    let decisions = HashMap<String, CkbReproKnowledgeSelectionRow>()
    for (row in selection) {
        if (decisions.contains(row.identity) ||
            !inventoryById.contains(row.identity) ||
            inventoryById.get(row.identity).getOrThrow().recordKind !=
                row.recordKind) {
            out.diagnostic = "actual_selection_mapping_invalid"; return out
        }
        if (row.decision == "selected") {
            if (ckbBuildInputsEvaluationKind(row.recordKind)) {
                out.diagnostic = "eval_support_selection_forbidden"; return out
            }
            out.selectedCount += 1
        } else if (row.decision == "excluded") {
            out.excludedCount += 1
        } else {
            out.diagnostic = "source_selection_decision_invalid"; return out
        }
        decisions[row.identity] = row
    }
    if (decisions.size != inventoryById.size) {
        out.diagnostic = "actual_selection_mapping_invalid"; return out
    }
    let actualIds = HashSet<String>()
    for (record in records.typed) {
        if (ckbBuildInputsEvaluationKind(record.recordKind)) {
            out.diagnostic = "eval_support_actual_record_forbidden"; return out
        }
        let identity = ckbReproValidatedPublicTypedRecordIdentity(record, context)
        if (!identity.ok || actualIds.contains(identity.identity) ||
            !inventoryById.contains(identity.identity)) {
            out.diagnostic = "actual_record_inventory_mismatch"; return out
        }
        let row = inventoryById.get(identity.identity).getOrThrow()
        if (row.recordKind != record.recordKind) {
            out.diagnostic = "actual_record_inventory_mismatch"; return out
        }
        actualIds.add(identity.identity)
    }
    for (record in records.raw) {
        let identity = ckbReproValidatedPublicRawRecordIdentity(record, context)
        if (!identity.ok || actualIds.contains(identity.identity) ||
            !inventoryById.contains(identity.identity)) {
            out.diagnostic = "actual_record_inventory_mismatch"; return out
        }
        let row = inventoryById.get(identity.identity).getOrThrow()
        if (row.recordKind != "raw") {
            out.diagnostic = "actual_record_inventory_mismatch"; return out
        }
        actualIds.add(identity.identity)
    }
    out.actualCount = actualIds.size
    if (actualIds.size != inventoryById.size) {
        out.diagnostic = "actual_record_inventory_mismatch"; return out
    }
    out.ok = true; out.diagnostic = "ok"; out
}

public func ckbReproPublicTypedRecordIdentity(
    record: CangjieTypedRecord): String {
    benchmarkGapSha256("ckb-public-record-identity-v1|typed|" +
        canonicalCkbPortableTypedRecord(record))
}

public func ckbReproPublicRawRecordIdentity(record: RawRecord): String {
    benchmarkGapSha256("ckb-public-record-identity-v1|raw|" +
        canonicalCkbPortableRawRecord(record))
}

private func inventoryCkbPublicKnowledgeSources(
    typed: ArrayList<CangjieTypedRecord>, raw: ArrayList<RawRecord>):
    ArrayList<CkbReproKnowledgeInventoryRow> {
    let rows = ArrayList<CkbReproKnowledgeInventoryRow>()
    for (record in typed) {
        if (record.recordKind == CangjieTypedRecordKinds.EVAL_SUPPORT) { continue }
        let row = CkbReproKnowledgeInventoryRow()
        row.identity = ckbReproPublicTypedRecordIdentity(record)
        row.sourceId = record.sourceId; row.recordKind = record.recordKind
        row.portableLocator = record.path; row.sourceType = "generated"
        row.license = "declared"; rows.add(row)
    }
    for (record in raw) {
        let row = CkbReproKnowledgeInventoryRow()
        row.identity = ckbReproPublicRawRecordIdentity(record)
        row.sourceId = record.sourceId; row.recordKind = "raw"
        row.portableLocator = record.metadata.path
        row.sourceType = record.metadata.sourceType
        row.license = record.metadata.license; rows.add(row)
    }
    rows
}

private func ckbBuildInputsString(object: JsonObject,
    key: String): String {
    object.get(key).getOrThrow().asString().getValue()
}

private func ckbBuildInputsEvaluationKind(kind: String): Bool {
    let lower = kind.toAsciiLower()
    lower == CangjieTypedRecordKinds.EVAL_SUPPORT.toAsciiLower() ||
        lower.contains("humaneval") || lower.contains("benchmark") ||
        lower.contains("teacher") || lower.contains("student_solution")
}

private func ckbBuildInputsJoin(values: Array<String>, separator: String): String {
    let out = StringBuilder()
    for (i in 0..values.size) {
        if (i > 0) { out.append(separator) }; out.append(values[i])
    }
    out.toString()
}

private func ckbBuildInputsEscape(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")
        .replace("\r", "\\r").replace("\t", "\\t")
}

private func ckbBuildInputsHash(value: String): Bool {
    if (!value.startsWith("sha256:") || value.toRuneArray().size != 71) {
        return false
    }
    var index: Int64 = 0
    for (rune in value.runes()) {
        if (index >= 7 && !((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) { return false }
        index += 1
    }
    true
}

private func ckbBuildInputsSuccess(): CkbReproContractResult {
    let out = CkbReproContractResult(); out.ok = true
    out.diagnostic = "ok"; out
}

private func ckbBuildInputsFailure(value: String): CkbReproContractResult {
    let out = CkbReproContractResult(); out.diagnostic = value; out
}
