package cangjie_community_knowledge_base_test

import std.collection.HashSet
import std.fs.{Directory, FileInfo, Path, canonicalize, exists}

public class CkbReproAttestationAuthorityFreezeOptions {
    public var environmentLockPath: String = ""
    public var compositionManifestPath: String = ""
    public var signingFingerprint: String = ""
    public var outputRoot: String = ""
    public var json: Bool = false
    public var diagnostic: String = "not_parsed"
    public init() {}
}

public class CkbReproAttestationAuthorityFreezeExecution {
    public var ok: Bool = false
    public var exitCode: Int64 = 2
    public var diagnostic: String = "not_run"
    public var output: String = ""
    public var environmentPlanHash: String = ""
    public var attestationAuthorityHash: String = ""
    public var providerCalls: Int64 = 0
    public var modelCalls: Int64 = 0
    public var runnerCalls: Int64 = 0
    public init() {}
}

public func parseCkbReproAttestationAuthorityFreezeOptions(
    args: Array<String>): CkbReproAttestationAuthorityFreezeOptions {
    let out = CkbReproAttestationAuthorityFreezeOptions()
    if (args.size == 0 ||
        args[0] != "ckb-repro-attestation-authority-freeze") {
        out.diagnostic = "attestation_authority_command_required"
        return out
    }
    let seen = HashSet<String>()
    var index: Int64 = 1
    while (index < args.size) {
        let name = args[index]
        if (name == "--json") {
            if (seen.contains(name)) {
                out.diagnostic = "duplicate_argument:${name}"
                return out
            }
            seen.add(name); out.json = true; index += 1; continue
        }
        if (name != "--environment-lock" &&
            name != "--composition-manifest" &&
            name != "--signing-fingerprint" && name != "--output-root") {
            out.diagnostic = "unknown_argument:${name}"
            return out
        }
        if (seen.contains(name)) {
            out.diagnostic = "duplicate_argument:${name}"
            return out
        }
        if (index + 1 >= args.size || args[index + 1].startsWith("--")) {
            out.diagnostic = "missing_argument_value:${name}"
            return out
        }
        let value = args[index + 1]
        seen.add(name)
        if (name == "--environment-lock") {
            out.environmentLockPath = value
        } else if (name == "--composition-manifest") {
            out.compositionManifestPath = value
        } else if (name == "--signing-fingerprint") {
            out.signingFingerprint = value
        } else { out.outputRoot = value }
        index += 2
    }
    out.diagnostic = validateCkbReproAttestationAuthorityFreezeOptions(out)
    out
}

public func validateCkbReproAttestationAuthorityFreezeOptions(
    options: CkbReproAttestationAuthorityFreezeOptions): String {
    if (!ckbAttestationAuthorityCanonicalExistingFile(
            options.environmentLockPath)) {
        return "attestation_authority_environment_lock_invalid"
    }
    if (!ckbAttestationAuthorityCanonicalExistingFile(
            options.compositionManifestPath)) {
        return "attestation_authority_composition_manifest_invalid"
    }
    if (!ckbAttestationAuthorityFingerprintValid(
            options.signingFingerprint)) {
        return "attestation_authority_fingerprint_invalid"
    }
    if (!ckbAttestationAuthorityCanonicalNewRoot(options.outputRoot)) {
        return "attestation_authority_output_root_invalid"
    }
    "ok"
}

public func runCkbReproAttestationAuthorityFreezeCli(args: Array<String>):
    CkbReproAttestationAuthorityFreezeExecution {
    let options = parseCkbReproAttestationAuthorityFreezeOptions(args)
    if (options.diagnostic != "ok") {
        return ckbAttestationAuthorityFailure(options.diagnostic,
            options.json || args.contains("--json"), 2)
    }
    var rootIdentity = ""
    try {
        let plannedRead = ckbReproReadSingleFileNoFollow(
            options.environmentLockPath, 128 * 1024)
        if (!plannedRead[0]) {
            return ckbAttestationAuthorityFailure(
                "attestation_authority_environment_lock_invalid",
                options.json, 1)
        }
        let parsed = parseCkbReproEnvironmentLock(plannedRead[1])
        if (!parsed[0].ok ||
            !validateCkbReproEnvironmentLock(parsed[1]).ok ||
            parsed[1].identityStatus != "planned" ||
            parsed[1].attestationAuthorityHash != "" ||
            parsed[1].compositionManifestHash != "") {
            return ckbAttestationAuthorityFailure(
                "attestation_authority_environment_plan_invalid",
                options.json, 1)
        }
        let composition = ckbAttestationAuthorityComposition(
            options.compositionManifestPath)
        if (!composition[0]) {
            return ckbAttestationAuthorityFailure(
                "attestation_authority_composition_manifest_invalid",
                options.json, 1)
        }
        Directory.create(Path(options.outputRoot), recursive: false)
        if (canonicalize(Path(options.outputRoot)).toString() !=
                options.outputRoot) {
            return ckbAttestationAuthorityOwnedFailure(options, "",
                "attestation_authority_output_root_invalid")
        }
        rootIdentity = ckbReproDirectoryOwnershipIdentity(options.outputRoot)
        if (rootIdentity == "") {
            return ckbAttestationAuthorityOwnedFailure(options, rootIdentity,
                "attestation_authority_output_root_invalid")
        }
        let frozen = parseCkbReproEnvironmentLock(
            renderCkbReproEnvironmentLock(parsed[1]).toArray())
        if (!frozen[0].ok) {
            return ckbAttestationAuthorityOwnedFailure(options, rootIdentity,
                "attestation_authority_environment_plan_invalid")
        }
        frozen[1].identityStatus = "frozen"
        frozen[1].compositionManifestHash = composition[1]
        let projection = ckbReproObservedEnvironmentProjectionHash(frozen[1])
        let source = "release://ckb/environment-attestation-authority-v1"
        let authorityText =
            "{\"schemaVersion\":\"ckb-repro-environment-attestation-authority-v1\"," +
            "\"status\":\"frozen\",\"signingFingerprint\":\"${options.signingFingerprint}\"," +
            "\"observedEnvironmentProjectionHash\":\"${projection}\"," +
            "\"authoritySource\":\"${source}\"," +
            "\"authoritySourceHash\":\"${ckbReproBundleHash(source.toArray())}\"}"
        let authorityBytes = authorityText.toArray()
        let authorityHash = ckbReproBundleHash(authorityBytes)
        let verified = loadCkbReproVerifiedAttestationAuthority(
            authorityBytes, authorityHash)
        if (!verified[0].ok ||
            verified[1].observedEnvironmentProjectionHash() != projection) {
            return ckbAttestationAuthorityOwnedFailure(options, rootIdentity,
                "attestation_authority_generation_invalid")
        }
        parsed[1].attestationAuthorityHash = authorityHash
        let planCheck = validateCkbReproEnvironmentLock(parsed[1])
        if (!planCheck.ok || parsed[1].identityStatus != "planned" ||
            parsed[1].compositionManifestHash != "") {
            return ckbAttestationAuthorityOwnedFailure(options, rootIdentity,
                "attestation_authority_environment_plan_invalid")
        }
        let planBytes = renderCkbReproEnvironmentLock(parsed[1]).toArray()
        let planWrite = ckbAttestationAuthorityPublish(options.outputRoot,
            rootIdentity, "environment-plan.json", planBytes)
        if (planWrite != "ok") {
            return ckbAttestationAuthorityOwnedFailure(options, rootIdentity,
                planWrite)
        }
        let authorityWrite = ckbAttestationAuthorityPublish(
            options.outputRoot, rootIdentity,
            "environment-attestation-authority.json", authorityBytes)
        if (authorityWrite != "ok") {
            return ckbAttestationAuthorityOwnedFailure(options, rootIdentity,
                authorityWrite)
        }
        let readback = ckbAttestationAuthorityReadback(options.outputRoot,
            rootIdentity, planBytes, authorityBytes, authorityHash, projection)
        if (readback != "ok") {
            return ckbAttestationAuthorityOwnedFailure(options, rootIdentity,
                readback)
        }
        let out = CkbReproAttestationAuthorityFreezeExecution()
        out.ok = true; out.exitCode = 0; out.diagnostic = "ok"
        out.environmentPlanHash = ckbReproBundleHash(planBytes)
        out.attestationAuthorityHash = authorityHash
        out.output = if (options.json) {
            "{\"ok\":true,\"diagnostic\":\"ok\"," +
            "\"environmentPlanHash\":\"${out.environmentPlanHash}\"," +
            "\"attestationAuthorityHash\":\"${authorityHash}\"," +
            "\"providerCalls\":0,\"modelCalls\":0,\"runnerCalls\":0}"
        } else {
            "CKB attestation authority frozen. " +
            "environmentPlanHash=${out.environmentPlanHash} " +
            "attestationAuthorityHash=${authorityHash} " +
            "providerCalls=0 modelCalls=0 runnerCalls=0\n"
        }
        out
    } catch (_: Exception) {
        ckbAttestationAuthorityOwnedFailure(options, rootIdentity,
            "attestation_authority_freeze_failed")
    }
}

private func ckbAttestationAuthorityComposition(path: String):
    (Bool, String) {
    let read = ckbReproReadSingleFileNoFollow(path, 64 * 1024)
    if (!read[0]) { return (false, "") }
    let parsed = parseCkbReproCliCompositionManifest(read[1])
    if (!parsed[0].ok) { return (false, "") }
    let root = Path(path).parent.parent.parent
    let canonicalRoot = try { canonicalize(root).toString() }
        catch (_: Exception) { return (false, "") }
    if (root.join("reproducibility/manifests/runtime-composition.json")
            .toString() != path || canonicalRoot != root.toString()) {
        return (false, "")
    }
    for (asset in parsed[1].assets) {
        let bytes = ckbReproReadSingleFileNoFollow(
            root.join(asset.relativePath).toString(), 536870912)
        if (!bytes[0] || bytes[1].size != asset.size ||
            ckbReproBundleHash(bytes[1]) != asset.sha256) {
            return (false, "")
        }
    }
    (true, ckbReproBundleHash(read[1]))
}

private func ckbAttestationAuthorityReadback(root: String,
    rootIdentity: String, expectedPlan: Array<UInt8>,
    expectedAuthority: Array<UInt8>, authorityHash: String,
    projection: String): String {
    if (ckbReproDirectoryOwnershipIdentity(root) != rootIdentity) {
        return "attestation_authority_root_identity_changed"
    }
    let plan = ckbReproReadSingleFileNoFollow(
        Path(root).join("environment-plan.json").toString(), 128 * 1024)
    let authority = ckbReproReadSingleFileNoFollow(
        Path(root).join("environment-attestation-authority.json").toString(),
        64 * 1024)
    if (!plan[0] || !authority[0] || plan[1] != expectedPlan ||
        authority[1] != expectedAuthority) {
        return "attestation_authority_readback_failed"
    }
    let parsedPlan = parseCkbReproEnvironmentLock(plan[1])
    let verified = loadCkbReproVerifiedAttestationAuthority(
        authority[1], authorityHash)
    if (!parsedPlan[0].ok || parsedPlan[1].identityStatus != "planned" ||
        parsedPlan[1].attestationAuthorityHash != authorityHash ||
        renderCkbReproEnvironmentLock(parsedPlan[1]).toArray() != plan[1] ||
        !verified[0].ok ||
        verified[1].observedEnvironmentProjectionHash() != projection) {
        return "attestation_authority_readback_failed"
    }
    "ok"
}

private func ckbAttestationAuthorityPublish(root: String,
    rootIdentity: String, fileName: String, bytes: Array<UInt8>): String {
    if (ckbReproDirectoryOwnershipIdentity(root) != rootIdentity ||
        bytes.size < 1) {
        return "attestation_authority_root_identity_changed"
    }
    let target = Path(root).join(fileName)
    if (exists(target)) { return "attestation_authority_target_exists" }
    let parentIdentity = ckbReproDirectoryOwnershipIdentity(Path(root).parent.toString())
    if (parentIdentity == "") {
        return "attestation_authority_parent_identity_invalid"
    }
    let descriptor = CkbReproOwnedTempDescriptor()
    let token = ckbReproBundleHash(bytes).replace("sha256:", "")
    descriptor.acquireBound(root, ".${fileName}.freeze-${token}", fileName,
        expectedParentIdentity: rootIdentity,
        expectedGrandparentIdentity: parentIdentity)
    try {
        if (!descriptor.ok || !descriptor.createPayload(bytes) ||
            !descriptor.publish() || !descriptor.syncAndValidate()) {
            return if (descriptor.diagnostic == "ok") {
                "attestation_authority_publish_failed"
            } else { descriptor.diagnostic }
        }
        let readback = descriptor.readPublicTarget(128 * 1024)
        if (!readback[0] || readback[1] != bytes ||
            ckbReproDirectoryOwnershipIdentity(root) != rootIdentity) {
            return "attestation_authority_readback_failed"
        }
        "ok"
    } finally { _ = descriptor.cleanup() }
}

private func ckbAttestationAuthorityOwnedFailure(
    options: CkbReproAttestationAuthorityFreezeOptions,
    rootIdentity: String, diagnostic: String):
    CkbReproAttestationAuthorityFreezeExecution {
    if (rootIdentity != "") {
        _ = ckbReproCleanupOwnedDirectory(options.outputRoot, rootIdentity,
            ["environment-plan.json", "environment-attestation-authority.json"])
    }
    ckbAttestationAuthorityFailure(diagnostic, options.json, 1)
}

private func ckbAttestationAuthorityFailure(diagnostic: String, json: Bool,
    exitCode: Int64): CkbReproAttestationAuthorityFreezeExecution {
    let out = CkbReproAttestationAuthorityFreezeExecution()
    out.exitCode = exitCode; out.diagnostic = diagnostic
    out.output = if (json) {
        "{\"ok\":false,\"diagnostic\":\"${diagnostic}\"," +
        "\"providerCalls\":0,\"modelCalls\":0,\"runnerCalls\":0}"
    } else {
        "CKB attestation authority freeze failed: ${diagnostic}. " +
        "providerCalls=0 modelCalls=0 runnerCalls=0\n"
    }
    out
}

private func ckbAttestationAuthorityFingerprintValid(value: String): Bool {
    if (value.toRuneArray().size != 40) { return false }
    for (rune in value.runes()) {
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'A' && rune <= r'F'))) { return false }
    }
    true
}

private func ckbAttestationAuthorityCanonicalExistingFile(path: String): Bool {
    path != "" && Path(path).isAbsolute() &&
        ckbReproReadSingleFileNoFollow(path, 128 * 1024)[0]
}

private func ckbAttestationAuthorityCanonicalNewRoot(path: String): Bool {
    if (path == "" || !Path(path).isAbsolute() || exists(Path(path))) {
        return false
    }
    let parent = Path(path).parent
    try {
        let info = FileInfo(parent)
        !info.isSymbolicLink() && info.isDirectory() &&
            canonicalize(parent).toString() == parent.toString() &&
            parent.join(Path(path).fileName).toString() == path &&
            ckbReproDirectoryOwnershipIdentity(parent.toString()) != ""
    } catch (_: Exception) { false }
}
