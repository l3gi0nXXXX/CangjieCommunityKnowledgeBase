package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashSet}
import std.fs.{Directory, File, OpenMode, Path, canonicalize, exists, remove, rename}
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

public class CkbAuthorityTrustPolicy {
    public var releaseRepository: String = ""
    public var releaseCommit: String = ""
    public var releaseTree: String = ""
    public var releaseLicenseSize: Int64 = 0
    public var releaseLicenseHash: String = ""
    public var evaluatorRepository: String = ""
    public var evaluatorCommit: String = ""
    public var evaluatorTree: String = ""
    public var evaluatorLicenseSize: Int64 = 0
    public var evaluatorLicenseHash: String = ""
    public var releaseLicenseId: String = ""
    public var evaluatorLicenseId: String = ""
    public var deliveryLicenseId: String = ""
    public var releaseAssetHash: String = ""
    public var sourceLockHash: String = ""
    public var authorityHash: String = ""
    public var datasetVersion: String = ""
    public init() {}
}

public func ckbHumanEvalAuthorityTrustPolicy(): CkbAuthorityTrustPolicy {
    let policy = CkbAuthorityTrustPolicy()
    policy.releaseRepository =
        "https://github.com/evalplus/humanevalplus_release"
    policy.releaseCommit = "68cd26d53a0dec69f85eafe1f82a2a74155a2bd6"
    policy.releaseTree = "8134abd00a3f022a7df0d1d410d90b59ccd3e69a"
    policy.releaseLicenseSize = 11549
    policy.releaseLicenseHash =
        "sha256:b0b08821a8c2b49e0f296b0b498c17d6e19b0439d1e4dd9cdb5f37712993c8a7"
    policy.evaluatorRepository = "https://github.com/evalplus/evalplus"
    policy.evaluatorCommit = "437e6936d3fad9487e891c24e4509b9561b95e3a"
    policy.evaluatorTree = "f185f11ba5ccecdd1e40d9a836f9d9e7ce40eac2"
    policy.evaluatorLicenseSize = 11558
    policy.evaluatorLicenseHash =
        "sha256:fcc1f77fe5443b21bfc4dfcc3d66f7654f599b91582df771850e5e876986a103"
    policy.releaseLicenseId = "Apache-2.0 AND MIT"
    policy.evaluatorLicenseId = "Apache-2.0 AND MIT"
    policy.deliveryLicenseId = "Apache-2.0 AND MIT"
    policy.releaseAssetHash =
        "sha256:272720b90ac375502c8ed23cd791c2a93dfb22a911641a494da74a426c09f101"
    policy.sourceLockHash =
        "sha256:42af8d986e94d8629407a04c5350da24db574abedd736205cbee914bf68f0454"
    policy.authorityHash =
        "sha256:58c32632cb7635e49e33b31e49a8401543a8e2110db975d2577a90465873c3b1"
    policy.datasetVersion =
        "cangjie-humaneval-164-sha256:72aa7564b350583eff660722aa54487334079b2c92207d3906898953f72f90f6"
    policy
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
    if (manifest.redistributionAllowed && manifest.anonymousPublicAccess) {
        return p6AuthorityFailure("authority_delivery_mode_ambiguous")
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
    archivePath: String, authorityBytes: Array<UInt8>, outputRoot: String,
    storeRoot: String, studentWorkspace: String,
    policy!: CkbAuthorityTrustPolicy = ckbHumanEvalAuthorityTrustPolicy(),
    backend!: CkbReleaseArchiveBackend = CkbPortableReleaseArchiveBackend()):
    CkbReproContractResult {
    validateCkbReproAuthorityDelivery(manifest, archivePath, authorityBytes,
        manifest.datasetVersion, outputRoot, storeRoot, studentWorkspace,
        policy: policy, backend: backend)
}

public func buildCkbReproAuthorityFromPublicSource(
    manifest: CkbAuthorityDeliveryManifest, authorityBytes: Array<UInt8>,
    outputRoot: String, storeRoot: String,
    studentWorkspace: String): CkbReproContractResult {
    let selected = selectCkbAuthorityDeliveryMode(manifest)
    if (!selected.ok || selected.diagnostic != "public_rebuild") {
        return p6AuthorityFailure("authority_public_rebuild_mode_required")
    }
    p6AuthorityFailure("authority_public_rebuild_not_executable")
}

public func validateCkbReproAuthorityDelivery(
    manifest: CkbAuthorityDeliveryManifest, archivePath: String,
    authorityBytes: Array<UInt8>,
    expectedDatasetVersion: String, outputRoot: String, storeRoot: String,
    studentWorkspace: String,
    policy!: CkbAuthorityTrustPolicy = ckbHumanEvalAuthorityTrustPolicy(),
    backend!: CkbReleaseArchiveBackend = CkbPortableReleaseArchiveBackend()):
    CkbReproContractResult {
    let selected = selectCkbAuthorityDeliveryMode(manifest)
    if (!selected.ok) { return selected }
    if (selected.diagnostic == "blocked") {
        return p6AuthorityFailure("authority_delivery_blocked")
    }
    if (selected.diagnostic != "bundled") {
        return p6AuthorityFailure("authority_public_rebuild_not_executable")
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
    let execution = validateCkbExecutionAuthorityDelivery(
        renderCkbAuthorityDeliveryManifest(manifest).toArray(),
        authorityBytes, archivePath, policy: policy, backend: backend)
    if (!execution.ok) { return execution }
    if (execution.canonicalJson == "" || expectedDatasetVersion == "" ||
        manifest.datasetVersion != expectedDatasetVersion) {
        return p6AuthorityFailure("authority_dataset_version_mismatch")
    }
    execution
}

public func validateCkbExecutionAuthorityDelivery(
    manifestBytes: Array<UInt8>, authorityBytes: Array<UInt8>,
    archivePath: String,
    policy!: CkbAuthorityTrustPolicy = ckbHumanEvalAuthorityTrustPolicy(),
    backend!: CkbReleaseArchiveBackend = CkbPortableReleaseArchiveBackend()):
    CkbReproContractResult {
    let parsed = parseCkbAuthorityDeliveryManifest(manifestBytes)
    if (!parsed[0].ok) { return parsed[0] }
    let manifest = parsed[1]
    let selected = selectCkbAuthorityDeliveryMode(manifest)
    if (!selected.ok) { return selected }
    if (selected.diagnostic == "blocked") {
        return p6AuthorityFailure("authority_delivery_blocked")
    }
    if (selected.diagnostic != "bundled") {
        return p6AuthorityFailure("authority_public_rebuild_not_executable")
    }
    if (!p6AuthorityPolicyValid(policy) ||
        manifest.licenseId != policy.deliveryLicenseId ||
        manifest.authorityHash != policy.authorityHash ||
        manifest.datasetVersion != policy.datasetVersion) {
        return p6AuthorityFailure("authority_trust_policy_mismatch")
    }
    if (archivePath == "" ||
        backend.archiveHash(archivePath) != manifest.bundleHash) {
        return p6AuthorityFailure("authority_bundle_hash_mismatch")
    }
    let archiveDiagnostic = p6AuthorityArchiveDiagnostic(
        manifest, authorityBytes, archivePath, policy, backend)
    if (archiveDiagnostic != "ok") {
        return p6AuthorityFailure(archiveDiagnostic)
    }
    if (backend.archiveHash(archivePath) != manifest.bundleHash) {
        return p6AuthorityFailure("authority_bundle_replaced_during_validation")
    }
    let decoded = p6AuthorityDecode(authorityBytes)
    if (decoded[0] != "ok") { return p6AuthorityFailure(decoded[0]) }
    let authority = parseCangjieHumanEvalAuthorityManifest(decoded[1])
    if (!authority.ok || authority.rows.size != 164) {
        return p6AuthorityFailure("authority_manifest_invalid")
    }
    if (authority.datasetVersion == "" ||
        manifest.datasetVersion != authority.datasetVersion) {
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

public func ckbAuthorityDeliveryReadyForExecution(
    manifest: CkbAuthorityDeliveryManifest): Bool {
    let selected = selectCkbAuthorityDeliveryMode(manifest)
    selected.ok && selected.diagnostic == "bundled"
}

public class CkbAuthorityBundleCliOptions {
    public var action: String = ""
    public var authorityPath: String = ""
    public var sourceLockPath: String = ""
    public var releaseAssetPath: String = ""
    public var releaseLicensePath: String = ""
    public var evaluatorLicensePath: String = ""
    public var outputRoot: String = ""
    public var deliveryRoot: String = ""
    public var json: Bool = false
    public var valid: Bool = false
    public var diagnostic: String = "not_parsed"
    public init() {}
}

public class CkbAuthorityBundleCliResult {
    public var ok: Bool = false
    public var action: String = ""
    public var diagnostic: String = "not_run"
    public var bundleHash: String = ""
    public var authorityHash: String = ""
    public var licenseEvidenceHash: String = ""
    public var datasetVersion: String = ""
    public var presentCount: Int64 = 0
    public init() {}
}

public class CkbAuthorityBundleCliExecution {
    public var exitCode: Int64 = 2
    public var diagnostic: String = "not_run"
    public var output: String = ""
    public init() {}
}

public func parseCkbAuthorityBundleCliArgs(args: Array<String>):
    CkbAuthorityBundleCliOptions {
    let out = CkbAuthorityBundleCliOptions()
    out.json = args.contains("--json")
    if (args.size < 2 || args[0] != "ckb-authority-bundle") {
        out.diagnostic = "authority_bundle_command_required"; return out
    }
    out.action = args[1]
    if (out.action != "seal" && out.action != "verify") {
        out.diagnostic = "authority_bundle_action_invalid"; return out
    }
    let seen = HashSet<String>(); var i: Int64 = 2
    while (i < args.size) {
        let arg = args[i]
        if (arg == "--json") {
            if (seen.contains(arg)) {
                out.diagnostic = "duplicate_argument:${arg}"; return out
            }
            seen.add(arg); out.json = true; i += 1; continue
        }
        if (!p6AuthorityCliArgumentAllowed(out.action, arg)) {
            out.diagnostic = "unknown_argument:${arg}"; return out
        }
        if (seen.contains(arg)) {
            out.diagnostic = "duplicate_argument:${arg}"; return out
        }
        if (i + 1 >= args.size || args[i + 1].startsWith("--")) {
            out.diagnostic = "missing_argument_value:${arg}"; return out
        }
        let value = args[i + 1]
        if (value.toRuneArray().size > 4096) {
            out.diagnostic = "cli_argument_too_long"; return out
        }
        seen.add(arg)
        if (arg == "--authority") { out.authorityPath = value }
        else if (arg == "--source-lock") { out.sourceLockPath = value }
        else if (arg == "--release-asset") { out.releaseAssetPath = value }
        else if (arg == "--release-license") { out.releaseLicensePath = value }
        else if (arg == "--evaluator-license") {
            out.evaluatorLicensePath = value
        } else if (arg == "--output-root") { out.outputRoot = value }
        else if (arg == "--delivery-root") { out.deliveryRoot = value }
        i += 2
    }
    let required = if (out.action == "seal") {
        [out.authorityPath, out.sourceLockPath, out.releaseAssetPath,
            out.releaseLicensePath, out.evaluatorLicensePath, out.outputRoot]
    } else { [out.authorityPath, out.deliveryRoot] }
    for (value in required) {
        if (value == "") {
            out.diagnostic = "required_argument_missing"; return out
        }
        if (!p6AuthorityRootValid(value)) {
            out.diagnostic = "authority_bundle_path_invalid"; return out
        }
    }
    out.valid = true; out.diagnostic = "ok"; out
}

public func runCkbAuthorityBundleCli(args: Array<String>,
    policy!: CkbAuthorityTrustPolicy = ckbHumanEvalAuthorityTrustPolicy(),
    backend!: CkbReleaseArchiveBackend = CkbPortableReleaseArchiveBackend()):
    CkbAuthorityBundleCliExecution {
    let options = parseCkbAuthorityBundleCliArgs(args)
    if (!options.valid) {
        return p6AuthorityCliExecution(options, p6AuthorityCliFailure(
            options.action, options.diagnostic), 2)
    }
    let result = if (options.action == "seal") {
        p6SealAuthorityBundleCli(options, policy, backend)
    } else { p6VerifyAuthorityBundleCli(options, policy, backend) }
    p6AuthorityCliExecution(options, result, if (result.ok) { 0 } else { 1 })
}

public func sealCkbExecutionAuthorityDelivery(authorityBytes: Array<UInt8>,
    sourceLockBytes: Array<UInt8>, releaseAssetBytes: Array<UInt8>,
    releaseLicenseBytes: Array<UInt8>, evaluatorLicenseBytes: Array<UInt8>,
    archivePath: String,
    policy!: CkbAuthorityTrustPolicy = ckbHumanEvalAuthorityTrustPolicy(),
    backend!: CkbReleaseArchiveBackend = CkbPortableReleaseArchiveBackend()):
    CkbReproContractResult {
    if (archivePath == "" || !p6AuthorityCanonicalNewPath(archivePath)) {
        return p6AuthorityFailure("authority_bundle_output_invalid")
    }
    if (!p6AuthorityPolicyValid(policy)) {
        return p6AuthorityFailure("authority_trust_policy_invalid")
    }
    if (p6AuthorityHash(sourceLockBytes) != policy.sourceLockHash) {
        return p6AuthorityFailure("authority_bundle_source_lock_mismatch")
    }
    if (p6AuthorityHash(releaseAssetBytes) != policy.releaseAssetHash) {
        return p6AuthorityFailure("authority_release_asset_mismatch")
    }
    if (releaseLicenseBytes.size != policy.releaseLicenseSize ||
        p6AuthorityHash(releaseLicenseBytes) != policy.releaseLicenseHash ||
        evaluatorLicenseBytes.size != policy.evaluatorLicenseSize ||
        p6AuthorityHash(evaluatorLicenseBytes) != policy.evaluatorLicenseHash) {
        return p6AuthorityFailure("authority_license_bytes_mismatch")
    }
    let decoded = p6AuthorityDecode(authorityBytes)
    if (decoded[0] != "ok") { return p6AuthorityFailure(decoded[0]) }
    let authority = parseCangjieHumanEvalAuthorityManifest(decoded[1])
    if (!authority.ok || authority.rows.size != 164 ||
        authority.datasetVersion != policy.datasetVersion ||
        p6AuthorityHash(authorityBytes) != policy.authorityHash) {
        return p6AuthorityFailure("authority_manifest_invalid")
    }
    let evidence = p6RenderAuthorityLicenseEvidence(policy)
    let evidenceHash = p6AuthorityHash(evidence.toArray())
    let index = p6RenderAuthorityBundleIndex(policy, evidenceHash)
    let payloads = ArrayList<CkbReleaseArchivePayload>()
    p6AddAuthorityPayload(payloads, "AUTHORITY-BUNDLE-MANIFEST.json",
        index.toArray())
    p6AddAuthorityPayload(payloads,
        "authority/HumanEvalPlus-v0.1.10/source-lock.json", sourceLockBytes)
    p6AddAuthorityPayload(payloads,
        "authority/cangjie_humaneval_manifest.jsonl", authorityBytes)
    p6AddAuthorityPayload(payloads, "licenses/LICENSE-EVIDENCE.json",
        evidence.toArray())
    p6AddAuthorityPayload(payloads, "licenses/evalplus-evaluator-LICENSE",
        evaluatorLicenseBytes)
    p6AddAuthorityPayload(payloads,
        "licenses/humanevalplus-release-LICENSE", releaseLicenseBytes)
    let stagingId = p6AuthorityHash(
        (archivePath + policy.authorityHash).toArray()).replace("sha256:", "")
    let temporaryRoot = "${archivePath}.seal-${stagingId}.tmp"
    var owned = false; var ownership = ""
    try {
        if (exists(Path(temporaryRoot))) {
            return p6AuthorityFailure("authority_bundle_temporary_conflict")
        }
        Directory.create(Path(temporaryRoot), recursive: false); owned = true
        ownership = ckbReproDirectoryOwnershipIdentity(temporaryRoot)
        if (ownership == "") {
            return p6AuthorityFailure("authority_bundle_create_failed")
        }
        let temporaryArchive = Path(temporaryRoot).join("bundle.tmp").toString()
        let created = backend.create(temporaryArchive, payloads)
        if (!created.ok) {
            return p6AuthorityFailure("authority_bundle_create_failed")
        }
        let manifest = CkbAuthorityDeliveryManifest()
        manifest.schemaVersion = "ckb-authority-delivery-v1"
        manifest.mode = "bundled"
        manifest.licenseId = policy.deliveryLicenseId
        manifest.licenseEvidenceHash = evidenceHash
        manifest.redistributionAllowed = true
        manifest.bundleHash = backend.archiveHash(temporaryArchive)
        manifest.authorityHash = policy.authorityHash
        manifest.datasetVersion = policy.datasetVersion
        let rendered = renderCkbAuthorityDeliveryManifest(manifest)
        let verified = validateCkbExecutionAuthorityDelivery(
            rendered.toArray(), authorityBytes, temporaryArchive,
            policy: policy, backend: backend)
        if (!verified.ok) { return verified }
        rename(temporaryArchive, to: archivePath, overwrite: false)
        verified.canonicalJson = rendered
        verified
    } catch (_: Exception) {
        p6AuthorityFailure("authority_bundle_create_failed")
    } finally {
        if (owned && exists(Path(temporaryRoot))) {
            _ = ckbReproCleanupOwnedDirectory(
                temporaryRoot, ownership, ["bundle.tmp"])
        }
    }
}

public func renderCkbAuthorityBundleCliHuman(
    result: CkbAuthorityBundleCliResult): String {
    let status = if (result.ok) {
        if (result.action == "seal") { "sealed" } else { "verified" }
    } else { "blocked" }
    "authority bundle: ${status}\n" +
        "diagnostic: ${p6AuthorityCliSafe(result.diagnostic)}\n" +
        "cases: ${result.presentCount}\n" +
        "dataset version: ${p6AuthorityCliSafe(result.datasetVersion)}\n" +
        "bundle hash: ${p6AuthorityCliSafe(result.bundleHash)}\n" +
        "authority hash: ${p6AuthorityCliSafe(result.authorityHash)}\n" +
        "license evidence hash: ${p6AuthorityCliSafe(result.licenseEvidenceHash)}\n"
}

public func renderCkbAuthorityBundleCliJson(
    result: CkbAuthorityBundleCliResult): String {
    "{\"ok\":${result.ok},\"action\":\"${p6AuthorityCliJson(result.action)}\"," +
        "\"diagnostic\":\"${p6AuthorityCliJson(p6AuthorityCliSafe(result.diagnostic))}\"," +
        "\"presentCount\":${result.presentCount}," +
        "\"datasetVersion\":\"${p6AuthorityCliJson(result.datasetVersion)}\"," +
        "\"bundleHash\":\"${p6AuthorityCliJson(result.bundleHash)}\"," +
        "\"authorityHash\":\"${p6AuthorityCliJson(result.authorityHash)}\"," +
        "\"licenseEvidenceHash\":\"${p6AuthorityCliJson(result.licenseEvidenceHash)}\"}"
}

private func p6AuthorityCliArgumentAllowed(action: String, arg: String): Bool {
    if (arg == "--authority") { return true }
    if (action == "seal") {
        return arg == "--source-lock" || arg == "--release-asset" ||
            arg == "--release-license" || arg == "--evaluator-license" ||
            arg == "--output-root"
    }
    arg == "--delivery-root"
}

private func p6SealAuthorityBundleCli(options: CkbAuthorityBundleCliOptions,
    policy: CkbAuthorityTrustPolicy, backend: CkbReleaseArchiveBackend):
    CkbAuthorityBundleCliResult {
    let paths = [options.authorityPath, options.sourceLockPath,
        options.releaseAssetPath, options.releaseLicensePath,
        options.evaluatorLicensePath]
    if (exists(Path(options.outputRoot)) ||
        !p6AuthorityCanonicalNewPath(options.outputRoot)) {
        return p6AuthorityCliFailure("seal", "authority_bundle_output_invalid")
    }
    for (path in paths) {
        if (p6AuthorityPathOverlap(options.outputRoot, path)) {
            return p6AuthorityCliFailure("seal", "authority_bundle_output_forbidden")
        }
    }
    let authority = p6AuthorityReadBounded(options.authorityPath,
        16 * 1024 * 1024)
    let sourceLock = p6AuthorityReadBounded(options.sourceLockPath, 1024 * 1024)
    let releaseAsset = p6AuthorityReadBounded(options.releaseAssetPath,
        16 * 1024 * 1024)
    let releaseLicense = p6AuthorityReadBounded(options.releaseLicensePath,
        1024 * 1024)
    let evaluatorLicense = p6AuthorityReadBounded(options.evaluatorLicensePath,
        1024 * 1024)
    for (read in [authority, sourceLock, releaseAsset, releaseLicense,
        evaluatorLicense]) {
        if (!read[0]) {
            return p6AuthorityCliFailure("seal", "authority_bundle_input_read_failed")
        }
    }
    let temporary = "${options.outputRoot}.tmp-${p6AuthorityHash(authority[1]).replace("sha256:", "")}"
    var owned = false; var ownership = ""
    try {
        if (exists(Path(temporary))) {
            return p6AuthorityCliFailure("seal", "authority_bundle_temporary_conflict")
        }
        Directory.create(Path(temporary), recursive: false); owned = true
        ownership = ckbReproDirectoryOwnershipIdentity(temporary)
        if (ownership == "") {
            return p6AuthorityCliFailure("seal",
                "authority_bundle_seal_failed")
        }
        let archivePath = Path(temporary).join(
            "cangjie-humaneval-authority.tar.zst").toString()
        let sealed = sealCkbExecutionAuthorityDelivery(authority[1],
            sourceLock[1], releaseAsset[1], releaseLicense[1],
            evaluatorLicense[1], archivePath, policy: policy, backend: backend)
        if (!sealed.ok) {
            return p6AuthorityCliFailure("seal", sealed.diagnostic)
        }
        File.writeTo(Path(temporary).join("authority-delivery.json"),
            sealed.canonicalJson.toArray())
        let verified = validateCkbExecutionAuthorityDelivery(
            sealed.canonicalJson.toArray(), authority[1], archivePath,
            policy: policy, backend: backend)
        if (!verified.ok) {
            return p6AuthorityCliFailure("seal", verified.diagnostic)
        }
        if (!p6AuthorityDeliveryRootExact(temporary)) {
            return p6AuthorityCliFailure("seal",
                "authority_bundle_layout_invalid")
        }
        rename(temporary, to: options.outputRoot, overwrite: false)
        owned = false
        p6AuthorityCliSuccess("seal", sealed.canonicalJson, verified)
    } catch (_: Exception) {
        p6AuthorityCliFailure("seal", "authority_bundle_seal_failed")
    } finally {
        if (owned && exists(Path(temporary))) {
            _ = ckbReproCleanupOwnedDirectory(temporary, ownership,
                ["cangjie-humaneval-authority.tar.zst",
                    "authority-delivery.json"])
        }
    }
}

private func p6VerifyAuthorityBundleCli(options: CkbAuthorityBundleCliOptions,
    policy: CkbAuthorityTrustPolicy, backend: CkbReleaseArchiveBackend):
    CkbAuthorityBundleCliResult {
    if (!p6AuthorityCanonicalExistingDirectory(options.deliveryRoot)) {
        return p6AuthorityCliFailure("verify", "authority_bundle_input_invalid")
    }
    if (!p6AuthorityDeliveryRootExact(options.deliveryRoot)) {
        return p6AuthorityCliFailure("verify", "authority_bundle_layout_invalid")
    }
    let authority = p6AuthorityReadBounded(options.authorityPath,
        16 * 1024 * 1024)
    let manifestPath = Path(options.deliveryRoot).join(
        "authority-delivery.json").toString()
    let archivePath = Path(options.deliveryRoot).join(
        "cangjie-humaneval-authority.tar.zst").toString()
    let manifest = p6AuthorityReadBounded(manifestPath, 1024 * 1024)
    let archive = p6AuthorityReadBounded(archivePath, 20 * 1024 * 1024)
    if (!authority[0] || !manifest[0] || !archive[0]) {
        return p6AuthorityCliFailure("verify", "authority_bundle_input_read_failed")
    }
    let temporary = "${options.deliveryRoot}.verify-${p6AuthorityHash(archive[1]).replace("sha256:", "")}.tmp"
    var owned = false; var ownership = ""
    try {
        if (exists(Path(temporary))) {
            return p6AuthorityCliFailure("verify",
                "authority_bundle_temporary_conflict")
        }
        Directory.create(Path(temporary), recursive: false); owned = true
        ownership = ckbReproDirectoryOwnershipIdentity(temporary)
        if (ownership == "") {
            return p6AuthorityCliFailure("verify",
                "authority_bundle_verify_failed")
        }
        let snapshot = Path(temporary).join("bundle.snapshot").toString()
        File.writeTo(Path(snapshot), archive[1])
        let verified = validateCkbExecutionAuthorityDelivery(manifest[1],
            authority[1], snapshot, policy: policy, backend: backend)
        if (!verified.ok) {
            return p6AuthorityCliFailure("verify", verified.diagnostic)
        }
        if (!p6AuthorityDeliveryRootExact(options.deliveryRoot)) {
            return p6AuthorityCliFailure("verify",
                "authority_bundle_layout_invalid")
        }
        p6AuthorityCliSuccess("verify", verified.canonicalJson, verified)
    } catch (_: Exception) {
        p6AuthorityCliFailure("verify", "authority_bundle_verify_failed")
    } finally {
        if (owned && exists(Path(temporary))) {
            _ = ckbReproCleanupOwnedDirectory(
                temporary, ownership, ["bundle.snapshot"])
        }
    }
}

private func p6RenderAuthorityLicenseEvidence(
    policy: CkbAuthorityTrustPolicy): String {
    "{\"schemaVersion\":\"ckb-authority-license-evidence-v1\",\"licenses\":[" +
        "{\"role\":\"humanevalplus-release\",\"bundlePath\":\"licenses/humanevalplus-release-LICENSE\",\"repository\":\"${p6AuthorityEscape(policy.releaseRepository)}\",\"commit\":\"${policy.releaseCommit}\",\"tree\":\"${policy.releaseTree}\",\"sourcePath\":\"LICENSE\",\"size\":${policy.releaseLicenseSize},\"sha256\":\"${policy.releaseLicenseHash}\",\"licenseId\":\"${p6AuthorityEscape(policy.releaseLicenseId)}\"}," +
        "{\"role\":\"evalplus-evaluator\",\"bundlePath\":\"licenses/evalplus-evaluator-LICENSE\",\"repository\":\"${p6AuthorityEscape(policy.evaluatorRepository)}\",\"commit\":\"${policy.evaluatorCommit}\",\"tree\":\"${policy.evaluatorTree}\",\"sourcePath\":\"LICENSE\",\"size\":${policy.evaluatorLicenseSize},\"sha256\":\"${policy.evaluatorLicenseHash}\",\"licenseId\":\"${p6AuthorityEscape(policy.evaluatorLicenseId)}\"}]}"
}

private func p6RenderAuthorityBundleIndex(policy: CkbAuthorityTrustPolicy,
    evidenceHash: String): String {
    "{\"schemaVersion\":\"ckb-authority-bundle-manifest-v1\"," +
        "\"datasetVersion\":\"${policy.datasetVersion}\"," +
        "\"authorityPath\":\"authority/cangjie_humaneval_manifest.jsonl\"," +
        "\"authorityHash\":\"${policy.authorityHash}\"," +
        "\"licenseEvidencePath\":\"licenses/LICENSE-EVIDENCE.json\"," +
        "\"licenseEvidenceHash\":\"${evidenceHash}\"," +
        "\"sourceLockPath\":\"authority/HumanEvalPlus-v0.1.10/source-lock.json\"," +
        "\"sourceLockHash\":\"${policy.sourceLockHash}\"," +
        "\"releaseAssetHash\":\"${policy.releaseAssetHash}\"," +
        "\"evaluatorCommit\":\"${policy.evaluatorCommit}\"}"
}

private func p6AddAuthorityPayload(values: ArrayList<CkbReleaseArchivePayload>,
    path: String, bytes: Array<UInt8>): Unit {
    let payload = CkbReleaseArchivePayload()
    payload.path = path; payload.bytes = bytes; values.add(payload)
}

private func p6AuthorityCliSuccess(action: String, manifestText: String,
    contract: CkbReproContractResult): CkbAuthorityBundleCliResult {
    let parsed = parseCkbAuthorityDeliveryManifest(manifestText.toArray())
    if (!contract.ok || !parsed[0].ok) {
        return p6AuthorityCliFailure(action,
            "authority_bundle_result_invalid")
    }
    let result = CkbAuthorityBundleCliResult()
    result.ok = true; result.action = action; result.diagnostic = "ok"
    result.presentCount = contract.presentCount
    result.bundleHash = parsed[1].bundleHash
    result.authorityHash = parsed[1].authorityHash
    result.licenseEvidenceHash = parsed[1].licenseEvidenceHash
    result.datasetVersion = parsed[1].datasetVersion
    result
}

private func p6AuthorityCliFailure(action: String, diagnostic: String):
    CkbAuthorityBundleCliResult {
    let result = CkbAuthorityBundleCliResult()
    result.action = action; result.diagnostic = diagnostic; result
}

private func p6AuthorityCliExecution(options: CkbAuthorityBundleCliOptions,
    result: CkbAuthorityBundleCliResult, exitCode: Int64):
    CkbAuthorityBundleCliExecution {
    let out = CkbAuthorityBundleCliExecution()
    out.exitCode = exitCode; out.diagnostic = result.diagnostic
    out.output = if (options.json) { renderCkbAuthorityBundleCliJson(result) }
        else { renderCkbAuthorityBundleCliHuman(result) }
    out
}

private func p6AuthorityCanonicalExistingDirectory(value: String): Bool {
    if (!exists(Path(value))) { return false }
    try {
        if (canonicalize(Path(value)).toString() != value) { return false }
        _ = Directory.readFrom(Path(value)); true
    }
    catch (_: Exception) { false }
}

private func p6AuthorityDeliveryRootExact(value: String): Bool {
    let expected = HashSet<String>()
    expected.add("authority-delivery.json")
    expected.add("cangjie-humaneval-authority.tar.zst")
    try {
        var count: Int64 = 0
        for (entry in Directory.readFrom(Path(value))) {
            if (entry.isSymbolicLink() || !entry.isRegular() ||
                !expected.contains(entry.name)) { return false }
            count += 1
        }
        count == 2
    } catch (_: Exception) { false }
}

private func p6AuthorityCanonicalNewPath(value: String): Bool {
    if (exists(Path(value))) { return false }
    try { canonicalize(Path(value).parent).join(Path(value).fileName).toString() == value }
    catch (_: Exception) { false }
}

private func p6AuthorityReadBounded(path: String, limit: Int64):
    (Bool, Array<UInt8>) {
    if (!p6AuthorityRootValid(path) || limit < 1) {
        return (false, Array<UInt8>())
    }
    ckbReproReadSingleFileNoFollow(path, limit)
}

private func p6AuthorityCliSafe(value: String): String {
    utf8SafePrefix(redactSensitive(value), 160)
}

private func p6AuthorityCliJson(value: String): String {
    let out = StringBuilder(); let hex = "0123456789abcdef".toRuneArray()
    for (rune in value.runes()) {
        if (rune == r'\"') { out.append("\\\"") }
        else if (rune == r'\\') { out.append("\\\\") }
        else if (rune == r'\n') { out.append("\\n") }
        else if (rune == r'\r') { out.append("\\r") }
        else if (rune == r'\t') { out.append("\\t") }
        else if (UInt32(rune) < 0x20u32) {
            let code = UInt32(rune); out.append("\\u00")
            out.append(hex[Int64(code / 16u32)])
            out.append(hex[Int64(code % 16u32)])
        } else { out.append(rune) }
    }
    out.toString()
}

private func p6AuthorityArchiveDiagnostic(
    manifest: CkbAuthorityDeliveryManifest, authorityBytes: Array<UInt8>,
    archivePath: String, policy: CkbAuthorityTrustPolicy,
    backend: CkbReleaseArchiveBackend): String {
    let expected = [
        "AUTHORITY-BUNDLE-MANIFEST.json",
        "authority/HumanEvalPlus-v0.1.10/source-lock.json",
        "authority/cangjie_humaneval_manifest.jsonl",
        "licenses/LICENSE-EVIDENCE.json",
        "licenses/evalplus-evaluator-LICENSE",
        "licenses/humanevalplus-release-LICENSE"
    ]
    let listing = backend.enumerate(archivePath)
    if (!listing.ok || listing.entries.size != expected.size) {
        return "authority_bundle_layout_invalid"
    }
    let observed = ArrayList<String>()
    var totalBytes: Int64 = 0
    for (entry in listing.entries) {
        let entryLimit = p6AuthorityArchiveEntryLimit(entry.path)
        if (entry.kind != CkbReleaseArchiveEntryKinds.REGULAR ||
            entry.linkTarget != "" || entry.size <= 0 || entryLimit == 0 ||
            entry.size > entryLimit || totalBytes > 20 * 1024 * 1024 - entry.size) {
            return "authority_bundle_layout_invalid"
        }
        totalBytes += entry.size
        observed.add(entry.path)
    }
    let sortedObserved = observed.toArray()
    sort(sortedObserved)
    for (i in 0..expected.size) {
        if (sortedObserved[i] != expected[i]) {
            return "authority_bundle_layout_invalid"
        }
    }
    let index = backend.readRegular(
        archivePath, "AUTHORITY-BUNDLE-MANIFEST.json")
    let bundledAuthority = backend.readRegular(
        archivePath, "authority/cangjie_humaneval_manifest.jsonl")
    let sourceLock = backend.readRegular(
        archivePath, "authority/HumanEvalPlus-v0.1.10/source-lock.json")
    let licenseEvidence = backend.readRegular(
        archivePath, "licenses/LICENSE-EVIDENCE.json")
    let releaseLicense = backend.readRegular(
        archivePath, "licenses/humanevalplus-release-LICENSE")
    let evaluatorLicense = backend.readRegular(
        archivePath, "licenses/evalplus-evaluator-LICENSE")
    if (!index.ok || !bundledAuthority.ok || !sourceLock.ok ||
        !licenseEvidence.ok || !releaseLicense.ok || !evaluatorLicense.ok) {
        return "authority_bundle_entry_read_failed"
    }
    if (!p6AuthorityArchiveReadSizeMatches(listing,
            "AUTHORITY-BUNDLE-MANIFEST.json", index.bytes.size) ||
        !p6AuthorityArchiveReadSizeMatches(listing,
            "authority/cangjie_humaneval_manifest.jsonl",
            bundledAuthority.bytes.size) ||
        !p6AuthorityArchiveReadSizeMatches(listing,
            "authority/HumanEvalPlus-v0.1.10/source-lock.json",
            sourceLock.bytes.size) ||
        !p6AuthorityArchiveReadSizeMatches(listing,
            "licenses/LICENSE-EVIDENCE.json", licenseEvidence.bytes.size) ||
        !p6AuthorityArchiveReadSizeMatches(listing,
            "licenses/humanevalplus-release-LICENSE",
            releaseLicense.bytes.size) ||
        !p6AuthorityArchiveReadSizeMatches(listing,
            "licenses/evalplus-evaluator-LICENSE",
            evaluatorLicense.bytes.size)) {
        return "authority_bundle_entry_size_mismatch"
    }
    if (bundledAuthority.bytes != authorityBytes ||
        p6AuthorityHash(bundledAuthority.bytes) != manifest.authorityHash) {
        return "authority_bundle_authority_mismatch"
    }
    if (p6AuthorityHash(sourceLock.bytes) != policy.sourceLockHash) {
        return "authority_bundle_source_lock_mismatch"
    }
    if (p6AuthorityHash(licenseEvidence.bytes) !=
        manifest.licenseEvidenceHash) {
        return "authority_license_evidence_hash_mismatch"
    }
    if (releaseLicense.bytes.size != policy.releaseLicenseSize ||
        p6AuthorityHash(releaseLicense.bytes) != policy.releaseLicenseHash ||
        evaluatorLicense.bytes.size != policy.evaluatorLicenseSize ||
        p6AuthorityHash(evaluatorLicense.bytes) !=
            policy.evaluatorLicenseHash) {
        return "authority_license_bytes_mismatch"
    }
    let licenseDiagnostic = p6AuthorityLicenseEvidenceDiagnostic(
        licenseEvidence.bytes, policy)
    if (licenseDiagnostic != "ok") { return licenseDiagnostic }
    p6AuthorityBundleIndexDiagnostic(index.bytes, manifest, policy)
}

private func p6AuthorityArchiveEntryLimit(path: String): Int64 {
    if (path == "authority/cangjie_humaneval_manifest.jsonl") {
        return 16 * 1024 * 1024
    }
    if (path == "AUTHORITY-BUNDLE-MANIFEST.json" ||
        path == "authority/HumanEvalPlus-v0.1.10/source-lock.json" ||
        path == "licenses/LICENSE-EVIDENCE.json" ||
        path == "licenses/evalplus-evaluator-LICENSE" ||
        path == "licenses/humanevalplus-release-LICENSE") {
        return 1024 * 1024
    }
    0
}

private func p6AuthorityArchiveReadSizeMatches(
    listing: CkbReleaseArchiveListing, path: String, size: Int64): Bool {
    for (entry in listing.entries) {
        if (entry.path == path) { return entry.size == size }
    }
    false
}

private func p6AuthorityBundleIndexDiagnostic(
    bytes: Array<UInt8>, manifest: CkbAuthorityDeliveryManifest,
    policy: CkbAuthorityTrustPolicy): String {
    let decoded = p6AuthorityDecode(bytes)
    if (decoded[0] != "ok") { return decoded[0] }
    try {
        let object = JsonValue.fromStr(decoded[1]).asObject()
        if (object.size() != 10 ||
            p6AuthorityString(object, "schemaVersion") !=
                "ckb-authority-bundle-manifest-v1" ||
            p6AuthorityString(object, "datasetVersion") !=
                manifest.datasetVersion ||
            p6AuthorityString(object, "authorityPath") !=
                "authority/cangjie_humaneval_manifest.jsonl" ||
            p6AuthorityString(object, "authorityHash") !=
                manifest.authorityHash ||
            p6AuthorityString(object, "licenseEvidencePath") !=
                "licenses/LICENSE-EVIDENCE.json" ||
            p6AuthorityString(object, "licenseEvidenceHash") !=
                manifest.licenseEvidenceHash ||
            p6AuthorityString(object, "sourceLockPath") !=
                "authority/HumanEvalPlus-v0.1.10/source-lock.json" ||
            p6AuthorityString(object, "sourceLockHash") !=
                policy.sourceLockHash ||
            p6AuthorityString(object, "releaseAssetHash") !=
                policy.releaseAssetHash ||
            p6AuthorityString(object, "evaluatorCommit") !=
                policy.evaluatorCommit) {
            return "authority_bundle_manifest_invalid"
        }
    } catch (_: Exception) {
        return "authority_bundle_manifest_invalid"
    }
    "ok"
}

private func p6AuthorityLicenseEvidenceDiagnostic(
    bytes: Array<UInt8>, policy: CkbAuthorityTrustPolicy): String {
    let decoded = p6AuthorityDecode(bytes)
    if (decoded[0] != "ok") { return decoded[0] }
    var releaseMatched = false
    var evaluatorMatched = false
    try {
        let root = JsonValue.fromStr(decoded[1]).asObject()
        if (root.size() != 2 ||
            p6AuthorityString(root, "schemaVersion") !=
                "ckb-authority-license-evidence-v1") {
            return "authority_license_evidence_invalid"
        }
        let licenses = root.get("licenses").getOrThrow().asArray().getItems()
        if (licenses.size != 2) {
            return "authority_license_evidence_invalid"
        }
        for (value in licenses) {
            let item = value.asObject()
            if (item.size() != 9) {
                return "authority_license_evidence_invalid"
            }
            let role = p6AuthorityString(item, "role")
            let bundlePath = p6AuthorityString(item, "bundlePath")
            let repository = p6AuthorityString(item, "repository")
            let commit = p6AuthorityString(item, "commit")
            let tree = p6AuthorityString(item, "tree")
            let sourcePath = p6AuthorityString(item, "sourcePath")
            let size = item.get("size").getOrThrow().asInt().getValue()
            let hash = p6AuthorityString(item, "sha256")
            let licenseId = p6AuthorityString(item, "licenseId")
            if (role == "humanevalplus-release" && !releaseMatched &&
                bundlePath == "licenses/humanevalplus-release-LICENSE" &&
                repository == policy.releaseRepository &&
                commit == policy.releaseCommit && tree == policy.releaseTree &&
                sourcePath == "LICENSE" && size == policy.releaseLicenseSize &&
                hash == policy.releaseLicenseHash &&
                licenseId == policy.releaseLicenseId) {
                releaseMatched = true
            } else if (role == "evalplus-evaluator" && !evaluatorMatched &&
                bundlePath == "licenses/evalplus-evaluator-LICENSE" &&
                repository == policy.evaluatorRepository &&
                commit == policy.evaluatorCommit &&
                tree == policy.evaluatorTree && sourcePath == "LICENSE" &&
                size == policy.evaluatorLicenseSize &&
                hash == policy.evaluatorLicenseHash &&
                licenseId == policy.evaluatorLicenseId) {
                evaluatorMatched = true
            } else {
                return "authority_license_evidence_invalid"
            }
        }
    } catch (_: Exception) {
        return "authority_license_evidence_invalid"
    }
    if (!releaseMatched || !evaluatorMatched) {
        return "authority_license_evidence_invalid"
    }
    "ok"
}

private func p6AuthorityPolicyValid(policy: CkbAuthorityTrustPolicy): Bool {
    policy.releaseRepository.startsWith("https://") &&
        policy.evaluatorRepository.startsWith("https://") &&
        p6AuthorityGitHashValid(policy.releaseCommit) &&
        p6AuthorityGitHashValid(policy.releaseTree) &&
        p6AuthorityGitHashValid(policy.evaluatorCommit) &&
        p6AuthorityGitHashValid(policy.evaluatorTree) &&
        policy.releaseLicenseSize > 0 && policy.evaluatorLicenseSize > 0 &&
        p6AuthorityHashValid(policy.releaseLicenseHash) &&
        p6AuthorityHashValid(policy.evaluatorLicenseHash) &&
        p6AuthorityHashValid(policy.releaseAssetHash) &&
        p6AuthorityHashValid(policy.sourceLockHash) &&
        p6AuthorityHashValid(policy.authorityHash) &&
        policy.datasetVersion.startsWith("cangjie-humaneval-164-sha256:") &&
        policy.releaseLicenseId != "" && policy.evaluatorLicenseId != "" &&
        policy.deliveryLicenseId != ""
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
    let hashes = manifest.fileHashes.toArray()
    sort(hashes)
    for (i in 1..hashes.size) {
        if (hashes[i] == hashes[i - 1] ||
            hashes[i].split("|")[0] == hashes[i - 1].split("|")[0]) {
            return false
        }
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
