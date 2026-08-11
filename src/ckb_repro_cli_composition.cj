package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashSet}
import std.fs.{Path, canonicalize, exists}
import stdx.encoding.json.*

public class CkbReproCliCompositionAsset {
    public var role: String = ""
    public var relativePath: String = ""
    public var size: Int64 = -1
    public var sha256: String = ""
    public init() {}
}

public class CkbReproCliCompositionManifest {
    public var schemaVersion: String = ""
    public var mode: String = ""
    public let assets = ArrayList<CkbReproCliCompositionAsset>()
    public init() {}
}

public class CkbReproCliCompositionLoadResult {
    public var ok: Bool = false
    public var diagnostic: String = "cli_composition_not_loaded"
    public var root: String = ""
    public var manifest: CkbReproCliCompositionManifest =
        CkbReproCliCompositionManifest()
    public var authorityEnvironmentLock: CkbReproEnvironmentLock =
        CkbReproEnvironmentLock()
    public var authorityEnvironmentLockBytes: Array<UInt8> = Array<UInt8>()
    public var runnerAuthority: CkbReproCliRunnerAuthority =
        CkbReproCliRunnerAuthority()
    public let assets = ArrayList<CkbReproCliCompositionLoadedAsset>()
    public init() {}
}

public class CkbReproCliCompositionLoadedAsset {
    public var role: String = ""
    public var relativePath: String = ""
    public var privateAuthority: Bool = false
    public var bytes: Array<UInt8> = Array<UInt8>()
    public init() {}
}

public class CkbReproCliPrivateAuthority {
    public var schemaVersion: String = ""
    public var localRootMap: String = ""
    public var pathContext: String = ""
    public var evalSupport: String = ""
    public var leakageAuthority: String = ""
    public init() {}
}

public class CkbReproCliRunnerAuthority {
    public var schemaVersion: String = ""
    public let credentialEnvironmentVariables = ArrayList<String>()
    public init() {}
}

public class CkbReproCliCompositionAuthority {
    public var manifestPath: String = ""
    public var manifestSha256: String = ""
    public init() {}
}

public class CkbReproCompositionSealAssetSpec {
    public var role: String = ""
    public var relativePath: String = ""
    public init() {}
}

public class CkbReproCompositionSealOptions {
    public var root: String = ""
    public var mode: String = ""
    public var json: Bool = false
    public var diagnostic: String = "not_parsed"
    public let assets = ArrayList<CkbReproCompositionSealAssetSpec>()
    public init() {}
}

public class CkbReproCompositionSealExecution {
    public var ok: Bool = false
    public var exitCode: Int64 = 2
    public var diagnostic: String = "not_run"
    public var output: String = ""
    public init() {}
}

public interface CkbReproCompositionSealCommitHook {
    func beforeCompositionCommit(): Unit
    func afterTempAcquired(path: String, kind: String): Unit
    func afterTargetPublished(path: String, kind: String): Unit
    func forceParentFsyncFailure(kind: String): Bool
    func forceInitialTempIdentityFailure(kind: String): Bool
    // Returning true simulates a process crash after the composition manifest
    // is durable but before the environment lock publication point.
    func afterCompositionCommitted(compositionPath: String,
        expectedMode: String): Bool
}

private class CkbReproCompositionSealNoopCommitHook <:
    CkbReproCompositionSealCommitHook {
    public func beforeCompositionCommit(): Unit {}
    public func afterTempAcquired(path: String, kind: String): Unit {}
    public func afterTargetPublished(path: String, kind: String): Unit {}
    public func forceParentFsyncFailure(kind: String): Bool { false }
    public func forceInitialTempIdentityFailure(kind: String): Bool { false }
    public func afterCompositionCommitted(compositionPath: String,
        expectedMode: String): Bool { false }
}

private class CkbReproCompositionTempFile {
    public var ok: Bool = false
    public var path: String = ""
    public var diagnostic: String = "composition_temporary_open_failed"
    public var descriptor: CkbReproOwnedTempDescriptor =
        CkbReproOwnedTempDescriptor()
    public init() {}
}

private func ckbCompositionAcquireTempFile(target: String, kind: String,
    manifestHash: String,
    hook: CkbReproCompositionSealCommitHook):
    CkbReproCompositionTempFile {
    let out = CkbReproCompositionTempFile()
    let token = manifestHash.replace("sha256:", "")
    let targetPath = Path(target)
    let parent = targetPath.parent.toString()
    let targetName = targetPath.fileName
    for (index in 0..4096) {
        let tempName = "${targetName}.tmp-${kind}-${token}-${index}"
        let descriptor = CkbReproOwnedTempDescriptor()
        descriptor.acquire(parent, tempName, targetName,
            forceInitialIdentityFailure:
                hook.forceInitialTempIdentityFailure(kind))
        if (descriptor.ok) {
            out.ok = true; out.path = Path(parent).join(tempName).toString()
            out.descriptor = descriptor
            hook.afterTempAcquired(out.path, kind)
            return out
        }
        if (descriptor.diagnostic != "composition_temporary_exists") {
            out.diagnostic = descriptor.diagnostic
            _ = descriptor.cleanup()
            return out
        }
        descriptor.close()
    }
    out
}

private func ckbCompositionReleaseTempFile(
    claim: CkbReproCompositionTempFile): Unit {
    if (claim.ok) { _ = claim.descriptor.cleanup() }
}

public func parseCkbReproCliCompositionManifest(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbReproCliCompositionManifest) {
    let out = CkbReproCliCompositionManifest()
    if (bytes.size <= 0 || bytes.size > 64 * 1024) {
        return (ckbCliCompositionFailure("cli_composition_size_invalid"), out)
    }
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (ckbCliCompositionFailure("invalid_response_encoding"), out)
    }
    let value = try { JsonValue.fromStr(text) } catch (_: Exception) {
        return (ckbCliCompositionFailure("malformed_json"), out)
    }
    try {
        let root = value.asObject()
        if (root.size() != 3) {
            return (ckbCliCompositionFailure(
                "cli_composition_field_contract_invalid"), out)
        }
        out.schemaVersion = root.get("schemaVersion").getOrThrow()
            .asString().getValue()
        out.mode = root.get("mode").getOrThrow().asString().getValue()
        for (value in root.get("assets").getOrThrow().asArray().getItems()) {
            let object = value.asObject()
            if (object.size() != 4) {
                return (ckbCliCompositionFailure(
                    "cli_composition_asset_field_contract_invalid"),
                    CkbReproCliCompositionManifest())
            }
            let asset = CkbReproCliCompositionAsset()
            asset.role = object.get("role").getOrThrow().asString().getValue()
            asset.relativePath = object.get("relativePath").getOrThrow()
                .asString().getValue()
            asset.size = object.get("size").getOrThrow().asInt().getValue()
            asset.sha256 = object.get("sha256").getOrThrow()
                .asString().getValue()
            out.assets.add(asset)
        }
    } catch (_: Exception) {
        return (ckbCliCompositionFailure(
            "cli_composition_field_contract_invalid"),
            CkbReproCliCompositionManifest())
    }
    let validation = validateCkbReproCliCompositionManifest(out)
    if (!validation.ok) { return (validation, CkbReproCliCompositionManifest()) }
    if (renderCkbReproCliCompositionManifest(out) != text) {
        return (ckbCliCompositionFailure("cli_composition_noncanonical"),
            CkbReproCliCompositionManifest())
    }
    (ckbCliCompositionSuccess(), out)
}

public func validateCkbReproCliCompositionManifest(
    manifest: CkbReproCliCompositionManifest): CkbReproContractResult {
    if (manifest.schemaVersion != "ckb-repro-cli-composition-v1") {
        return ckbCliCompositionFailure("cli_composition_schema_invalid")
    }
    let expected = ckbReproCliCompositionRoles(manifest.mode)
    if (expected.size == 0 || manifest.assets.size != expected.size) {
        return ckbCliCompositionFailure("cli_composition_mode_contract_invalid")
    }
    let roles = HashSet<String>(); let paths = HashSet<String>()
    for (asset in manifest.assets) {
        if (!expected.contains(asset.role) || roles.contains(asset.role) ||
            paths.contains(asset.relativePath) || asset.size <= 0 ||
            asset.size > 536870912 || !ckbCliCompositionHash(asset.sha256) ||
            !validateCkbReproBundleRelativePath(asset.relativePath).ok ||
            asset.relativePath.contains("\"") || asset.relativePath.contains("|") ||
            !ckbCliCompositionRolePath(asset.role, asset.relativePath)) {
            return ckbCliCompositionFailure("cli_composition_asset_invalid")
        }
        if (manifest.mode == "release-verify" &&
            ckbCliCompositionForbiddenB(asset.role + "|" + asset.relativePath)) {
            return ckbCliCompositionFailure("release_verify_online_asset_forbidden")
        }
        roles.add(asset.role); paths.add(asset.relativePath)
    }
    ckbCliCompositionSuccess()
}

public func renderCkbReproCliCompositionManifest(
    manifest: CkbReproCliCompositionManifest): String {
    let rows = ArrayList<String>()
    for (role in ckbReproCliCompositionRoles(manifest.mode)) {
        for (asset in manifest.assets) {
            if (asset.role == role) {
                rows.add("{\"role\":\"${asset.role}\",\"relativePath\":\"" +
                    "${asset.relativePath}\",\"size\":${asset.size}," +
                    "\"sha256\":\"${asset.sha256}\"}")
            }
        }
    }
    "{\"schemaVersion\":\"ckb-repro-cli-composition-v1\"," +
        "\"mode\":\"${manifest.mode}\",\"assets\":[" +
        ckbCliCompositionJoin(rows) + "]}"
}

public func loadCkbReproCliComposition(path: String, expectedMode: String):
    CkbReproCliCompositionLoadResult {
    let out = CkbReproCliCompositionLoadResult()
    let manifestRelative =
        "reproducibility/manifests/runtime-composition.json"
    let manifestPath = Path(path)
    if (!manifestPath.isAbsolute()) {
        out.diagnostic = "cli_composition_path_invalid"; return out
    }
    let rootPath = manifestPath.parent.parent.parent
    if (rootPath.join(manifestRelative).toString() != path) {
        out.diagnostic = "cli_composition_path_invalid"; return out
    }
    out.root = rootPath.toString()
    let authorityPath = "reproducibility/manifests/environment-lock.json"
    let authorityBytes = ckbCliCompositionRead(
        out.root, authorityPath, 128 * 1024)
    if (!authorityBytes[0].ok) {
        out.diagnostic = authorityBytes[0].diagnostic; return out
    }
    let authority = parseCkbReproCliCompositionAuthority(authorityBytes[1])
    if (!authority[0].ok || authority[1].manifestPath != manifestRelative) {
        out.diagnostic = if (!authority[0].ok) { authority[0].diagnostic }
            else { "cli_composition_authority_path_mismatch" }
        return out
    }
    let environment = parseCkbReproEnvironmentLock(authorityBytes[1])
    if (!environment[0].ok) {
        out.diagnostic = environment[0].diagnostic; return out
    }
    try {
        let manifestBytes = ckbCliCompositionRead(
            out.root, manifestRelative, 64 * 1024)
        if (!manifestBytes[0].ok ||
            ckbReproBundleHash(manifestBytes[1]) !=
                authority[1].manifestSha256) {
            out.diagnostic = "cli_composition_authority_mismatch"; return out
        }
        let parsed = parseCkbReproCliCompositionManifest(manifestBytes[1])
        if (!parsed[0].ok || parsed[1].mode != expectedMode) {
            out.diagnostic = if (!parsed[0].ok) { parsed[0].diagnostic }
                else { "cli_composition_mode_mismatch" }
            return out
        }
        var privateAuthority = CkbReproCliPrivateAuthority()
        var privateAuthorityLoaded = false
        for (asset in parsed[1].assets) {
            let captured = ckbCliCompositionRead(
                out.root, asset.relativePath, asset.size)
            if (!captured[0].ok || captured[1].size != asset.size ||
                ckbReproBundleHash(captured[1]) != asset.sha256) {
                out.diagnostic = "cli_composition_asset_authority_invalid"
                return out
            }
            if (asset.role == "public_build_input_manifest") {
                let build = parseCkbReproBuildInputManifest(captured[1])
                if (!build[0].ok) {
                    out.diagnostic = build[0].diagnostic; return out
                }
            }
            if (asset.role == "private_build_authority") {
                let authority = parseCkbReproCliPrivateAuthority(
                    captured[1], parsed[1].mode)
                if (!authority[0].ok) {
                    out.diagnostic = authority[0].diagnostic; return out
                }
                privateAuthority = authority[1]
                privateAuthorityLoaded = true
            }
            if (asset.role == "runner_authority") {
                let authority = parseCkbReproCliRunnerAuthority(
                    captured[1], parsed[1].mode)
                if (!authority[0].ok) {
                    out.diagnostic = authority[0].diagnostic; return out
                }
                out.runnerAuthority = authority[1]
            }
            let loaded = CkbReproCliCompositionLoadedAsset()
            loaded.role = asset.role; loaded.relativePath = asset.relativePath
            loaded.privateAuthority = asset.relativePath
                .startsWith("private-authority/")
            loaded.bytes = captured[1]; out.assets.add(loaded)
        }
        if (privateAuthorityLoaded &&
            (privateAuthority.localRootMap != ckbCliCompositionPathForRole(
                parsed[1], "local_root_map") ||
            privateAuthority.pathContext != ckbCliCompositionPathForRole(
                parsed[1], "path_context") ||
            privateAuthority.evalSupport != ckbCliCompositionPathForRole(
                parsed[1], "eval_support") ||
            privateAuthority.leakageAuthority != ckbCliCompositionPathForRole(
                parsed[1], "leakage_authority"))) {
            out.diagnostic = "private_authority_asset_mismatch"; return out
        }
        let authorityAfter = ckbCliCompositionRead(
            out.root, authorityPath, 128 * 1024)
        let manifestAfter = ckbCliCompositionRead(
            out.root, manifestRelative, 64 * 1024)
        if (!authorityAfter[0].ok || authorityAfter[1] != authorityBytes[1] ||
            !manifestAfter[0].ok || manifestAfter[1] != manifestBytes[1]) {
            out.diagnostic = "cli_composition_authority_changed"; return out
        }
        out.manifest = parsed[1]
        out.authorityEnvironmentLock = environment[1]
        out.authorityEnvironmentLockBytes = authorityBytes[1]
        out.ok = true; out.diagnostic = "ok"; out
    } catch (_: Exception) {
        out.diagnostic = "cli_composition_load_failed"; out
    }
}

public func parseCkbReproCliCompositionAuthority(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbReproCliCompositionAuthority) {
    let out = CkbReproCliCompositionAuthority()
    if (bytes.size <= 0 || bytes.size > 128 * 1024) {
        return (ckbCliCompositionFailure("cli_composition_authority_size_invalid"), out)
    }
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (ckbCliCompositionFailure("invalid_response_encoding"), out)
    }
    try {
        let root = JsonValue.fromStr(text).asObject()
        if (root.size() != 41 ||
            root.get("schemaVersion").getOrThrow().asString().getValue() !=
                "ckb-repro-environment-v1") {
            return (ckbCliCompositionFailure(
                "cli_composition_authority_field_contract_invalid"), out)
        }
        for (field in ckbCliCompositionEnvironmentLockFields()) {
            _ = root.get(field).getOrThrow()
        }
        out.manifestPath = root.get("compositionManifestPath").getOrThrow()
            .asString().getValue()
        out.manifestSha256 = root.get("compositionManifestHash")
            .getOrThrow().asString().getValue()
    } catch (_: Exception) {
        return (ckbCliCompositionFailure(
            "cli_composition_authority_field_contract_invalid"),
            CkbReproCliCompositionAuthority())
    }
    if (out.manifestPath !=
            "reproducibility/manifests/runtime-composition.json" ||
        !ckbCliCompositionHash(out.manifestSha256)) {
        return (ckbCliCompositionFailure(
            "cli_composition_authority_invalid"),
            CkbReproCliCompositionAuthority())
    }
    (ckbCliCompositionSuccess(), out)
}

public func parseCkbReproBuildInputManifest(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbReproBuildInputManifest) {
    let out = CkbReproBuildInputManifest()
    if (bytes.size <= 0 || bytes.size > 64 * 1024) {
        return (ckbCliCompositionFailure("build_inputs_manifest_size_invalid"), out)
    }
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (ckbCliCompositionFailure("invalid_response_encoding"), out)
    }
    try {
        let root = JsonValue.fromStr(text).asObject()
        if (root.size() != 5) {
            return (ckbCliCompositionFailure(
                "build_inputs_manifest_field_contract_invalid"), out)
        }
        out.schemaVersion = root.get("schemaVersion").getOrThrow()
            .asString().getValue()
        out.candidateVersion = root.get("candidateVersion").getOrThrow()
            .asString().getValue()
        out.targetVersion = root.get("targetVersion").getOrThrow()
            .asString().getValue()
        out.expectedRawCount = root.get("expectedRawCount").getOrThrow()
            .asInt().getValue()
        for (value in root.get("assets").getOrThrow().asArray().getItems()) {
            let object = value.asObject()
            if (object.size() != 4) {
                return (ckbCliCompositionFailure(
                    "build_inputs_manifest_asset_contract_invalid"),
                    CkbReproBuildInputManifest())
            }
            let asset = CkbReproBuildInputAsset()
            asset.role = object.get("role").getOrThrow().asString().getValue()
            asset.relativePath = object.get("relativePath").getOrThrow()
                .asString().getValue()
            asset.size = object.get("size").getOrThrow().asInt().getValue()
            asset.sha256 = object.get("sha256").getOrThrow()
                .asString().getValue()
            out.assets.add(asset)
        }
    } catch (_: Exception) {
        return (ckbCliCompositionFailure("malformed_json"),
            CkbReproBuildInputManifest())
    }
    let validated = validateCkbReproBuildInputManifest(out)
    if (!validated.ok) { return (validated, CkbReproBuildInputManifest()) }
    if (renderCkbReproBuildInputManifest(out) != text) {
        return (ckbCliCompositionFailure("build_inputs_manifest_noncanonical"),
            CkbReproBuildInputManifest())
    }
    (ckbCliCompositionSuccess(), out)
}

public func renderCkbReproBuildInputManifest(
    manifest: CkbReproBuildInputManifest): String {
    let rows = ArrayList<String>()
    for (role in ckbReproPublicBuildInputRoles()) {
        for (asset in manifest.assets) {
            if (asset.role == role) {
                rows.add("{\"role\":\"${asset.role}\",\"relativePath\":\"" +
                    "${asset.relativePath}\",\"size\":${asset.size}," +
                    "\"sha256\":\"${asset.sha256}\"}")
            }
        }
    }
    "{\"schemaVersion\":\"ckb-repro-build-inputs-v1\"," +
        "\"candidateVersion\":\"${manifest.candidateVersion}\"," +
        "\"targetVersion\":\"${manifest.targetVersion}\"," +
        "\"expectedRawCount\":${manifest.expectedRawCount},\"assets\":[" +
        ckbCliCompositionJoin(rows) + "]}"
}

public func parseCkbReproCliPrivateAuthority(bytes: Array<UInt8>, mode: String):
    (CkbReproContractResult, CkbReproCliPrivateAuthority) {
    let out = CkbReproCliPrivateAuthority()
    if (bytes.size <= 0 || bytes.size > 64 * 1024) {
        return (ckbCliCompositionFailure("private_authority_size_invalid"), out)
    }
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (ckbCliCompositionFailure("invalid_response_encoding"), out)
    }
    try {
        let root = JsonValue.fromStr(text).asObject()
        if (root.size() != 5) {
            return (ckbCliCompositionFailure(
                "private_authority_field_contract_invalid"), out)
        }
        out.schemaVersion = root.get("schemaVersion").getOrThrow()
            .asString().getValue()
        out.localRootMap = root.get("localRootMap").getOrThrow()
            .asString().getValue()
        out.pathContext = root.get("pathContext").getOrThrow()
            .asString().getValue()
        out.evalSupport = root.get("evalSupport").getOrThrow()
            .asString().getValue()
        out.leakageAuthority = root.get("leakageAuthority").getOrThrow()
            .asString().getValue()
    } catch (_: Exception) {
        return (ckbCliCompositionFailure("malformed_json"),
            CkbReproCliPrivateAuthority())
    }
    let validated = validateCkbReproCliPrivateAuthority(out, mode)
    if (!validated.ok) {
        return (validated, CkbReproCliPrivateAuthority())
    }
    if (renderCkbReproCliPrivateAuthority(out, mode) != text) {
        return (ckbCliCompositionFailure("private_authority_noncanonical"),
            CkbReproCliPrivateAuthority())
    }
    (ckbCliCompositionSuccess(), out)
}

public func validateCkbReproCliPrivateAuthority(
    authority: CkbReproCliPrivateAuthority, mode: String):
    CkbReproContractResult {
    if (authority.schemaVersion != "ckb-repro-private-cli-authority-v1") {
        return ckbCliCompositionFailure("private_authority_schema_invalid")
    }
    let paths = [authority.localRootMap, authority.pathContext,
        authority.evalSupport, authority.leakageAuthority]
    let seen = HashSet<String>()
    for (path in paths) {
        if (!validateCkbReproBundleRelativePath(path).ok ||
            !path.startsWith("private-authority/") || seen.contains(path)) {
            return ckbCliCompositionFailure("private_authority_path_invalid")
        }
        seen.add(path)
    }
    ckbCliCompositionSuccess()
}

public func renderCkbReproCliPrivateAuthority(
    authority: CkbReproCliPrivateAuthority, mode: String): String {
    let prefix = "{\"schemaVersion\":\"ckb-repro-private-cli-authority-v1\"," +
        "\"localRootMap\":\"${authority.localRootMap}\"," +
        "\"pathContext\":\"${authority.pathContext}\"," +
        "\"evalSupport\":\"${authority.evalSupport}\"," +
        "\"leakageAuthority\":\"${authority.leakageAuthority}\""
    prefix + "}"
}

public func parseCkbReproCliRunnerAuthority(bytes: Array<UInt8>, mode: String):
    (CkbReproContractResult, CkbReproCliRunnerAuthority) {
    let out = CkbReproCliRunnerAuthority()
    if (mode != "run-certify" || bytes.size <= 0 || bytes.size > 64 * 1024) {
        return (ckbCliCompositionFailure("runner_authority_mode_invalid"), out)
    }
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (ckbCliCompositionFailure("invalid_response_encoding"), out)
    }
    try {
        let root = JsonValue.fromStr(text).asObject()
        if (root.size() != 2) {
            return (ckbCliCompositionFailure(
                "runner_authority_field_contract_invalid"), out)
        }
        out.schemaVersion = root.get("schemaVersion").getOrThrow()
            .asString().getValue()
        for (value in root.get("credentialEnvironmentVariables")
            .getOrThrow().asArray().getItems()) {
            out.credentialEnvironmentVariables.add(value.asString().getValue())
        }
    } catch (_: Exception) {
        return (ckbCliCompositionFailure("malformed_json"),
            CkbReproCliRunnerAuthority())
    }
    if (out.schemaVersion != "ckb-repro-runner-authority-v1") {
        return (ckbCliCompositionFailure("runner_authority_schema_invalid"),
            CkbReproCliRunnerAuthority())
    }
    let values = ArrayList<String>()
    let seen = HashSet<String>()
    for (value in out.credentialEnvironmentVariables) {
        if (!ckbCliCompositionEnvironmentVariable(value) ||
            seen.contains(value)) {
            return (ckbCliCompositionFailure(
                "credential_environment_variable_invalid"),
                CkbReproCliRunnerAuthority())
        }
        seen.add(value)
        values.add("\"${value}\"")
    }
    let canonical = "{\"schemaVersion\":\"ckb-repro-runner-authority-v1\"," +
        "\"credentialEnvironmentVariables\":[" +
        ckbCliCompositionJoin(values) + "]}"
    if (canonical != text) {
        return (ckbCliCompositionFailure("runner_authority_noncanonical"),
            CkbReproCliRunnerAuthority())
    }
    (ckbCliCompositionSuccess(), out)
}

public func renderCkbReproCliRunnerAuthority(
    authority: CkbReproCliRunnerAuthority): String {
    let values = ArrayList<String>()
    for (value in authority.credentialEnvironmentVariables) {
        values.add("\"${ckbCliCompositionJson(value)}\"")
    }
    "{\"schemaVersion\":\"ckb-repro-runner-authority-v1\"," +
        "\"credentialEnvironmentVariables\":[" +
        ckbCliCompositionJoin(values) + "]}"
}

public func parseCkbReproCompositionSealOptions(args: Array<String>):
    CkbReproCompositionSealOptions {
    let out = CkbReproCompositionSealOptions()
    if (args.size == 0 || args[0] != "ckb-repro-composition-seal") {
        out.diagnostic = "composition_seal_command_required"; return out
    }
    let seen = HashSet<String>()
    var i: Int64 = 1
    while (i < args.size) {
        let arg = args[i]
        if (arg == "--json") {
            if (seen.contains(arg)) {
                out.diagnostic = "duplicate_argument:${arg}"; return out
            }
            seen.add(arg); out.json = true; i += 1; continue
        }
        if (arg != "--root" && arg != "--mode" && arg != "--asset") {
            out.diagnostic = "unknown_argument:${arg}"; return out
        }
        if (arg != "--asset" && seen.contains(arg)) {
            out.diagnostic = "duplicate_argument:${arg}"; return out
        }
        if (i + 1 >= args.size || args[i + 1].startsWith("--")) {
            out.diagnostic = "missing_argument_value:${arg}"; return out
        }
        if (arg != "--asset") { seen.add(arg) }
        let value = args[i + 1]
        if (arg == "--root") { out.root = value }
        else if (arg == "--mode") { out.mode = value }
        else {
            let separator = match (value.indexOf("=")) {
                case Some(index) => index
                case None => -1
            }
            if (separator <= 0 || separator >= value.toRuneArray().size - 1) {
                out.diagnostic = "composition_asset_argument_invalid"; return out
            }
            let runes = value.toRuneArray()
            let spec = CkbReproCompositionSealAssetSpec()
            spec.role = String(runes[0..separator])
            spec.relativePath = String(runes[separator + 1..runes.size])
            out.assets.add(spec)
        }
        i += 2
    }
    out.diagnostic = validateCkbReproCompositionSealOptions(out)
    out
}

public func validateCkbReproCompositionSealOptions(
    options: CkbReproCompositionSealOptions): String {
    let expected = ckbReproCliCompositionRoles(options.mode)
    if (options.root == "" || !Path(options.root).isAbsolute() ||
        expected.size == 0 || options.assets.size != expected.size) {
        return "composition_seal_options_invalid"
    }
    let roles = HashSet<String>(); let paths = HashSet<String>()
    for (spec in options.assets) {
        if (!expected.contains(spec.role) || roles.contains(spec.role) ||
            paths.contains(spec.relativePath) ||
            !validateCkbReproBundleRelativePath(spec.relativePath).ok ||
            !ckbCliCompositionRolePath(spec.role, spec.relativePath)) {
            return "composition_asset_argument_invalid"
        }
        roles.add(spec.role); paths.add(spec.relativePath)
    }
    "ok"
}

public func runCkbReproCompositionSealCli(args: Array<String>):
    CkbReproCompositionSealExecution {
    runCkbReproCompositionSealCliWithProbe(args,
        CkbReproFilesystemEnvironmentProbe())
}

public func runCkbReproCompositionSealCliWithProbe(args: Array<String>,
    probe: CkbReproEnvironmentProbe): CkbReproCompositionSealExecution {
    runCkbReproCompositionSealCliWithProbeAndHook(args, probe,
        CkbReproCompositionSealNoopCommitHook())
}

public func runCkbReproCompositionSealCliWithProbeAndHook(
    args: Array<String>, probe: CkbReproEnvironmentProbe,
    hook: CkbReproCompositionSealCommitHook):
    CkbReproCompositionSealExecution {
    let options = parseCkbReproCompositionSealOptions(args)
    if (options.diagnostic != "ok") {
        return ckbCompositionSealFailure(options.diagnostic,
            options.json || args.contains("--json"), 2)
    }
    let canonicalRoot = try { canonicalize(Path(options.root)).toString() }
        catch (_: Exception) { "" }
    if (canonicalRoot == "" || canonicalRoot != options.root) {
        return ckbCompositionSealFailure("composition_root_invalid",
            options.json, 1)
    }
    let manifest = CkbReproCliCompositionManifest()
    manifest.schemaVersion = "ckb-repro-cli-composition-v1"
    manifest.mode = options.mode
    for (role in ckbReproCliCompositionRoles(options.mode)) {
        for (spec in options.assets) {
            if (spec.role != role) { continue }
            let read = ckbCliCompositionRead(canonicalRoot,
                spec.relativePath, 536870912)
            if (!read[0].ok) {
                return ckbCompositionSealFailure(read[0].diagnostic,
                    options.json, 1)
            }
            let asset = CkbReproCliCompositionAsset()
            asset.role = role; asset.relativePath = spec.relativePath
            asset.size = read[1].size
            asset.sha256 = ckbReproBundleHash(read[1])
            manifest.assets.add(asset)
        }
    }
    let checked = validateCkbReproCliCompositionManifest(manifest)
    if (!checked.ok) {
        return ckbCompositionSealFailure(checked.diagnostic, options.json, 1)
    }
    let manifestText = renderCkbReproCliCompositionManifest(manifest)
    let manifestHash = ckbReproBundleHash(manifestText.toArray())
    let manifestPath = Path(canonicalRoot).join(
        "reproducibility/manifests/runtime-composition.json").toString()
    let environmentPath = Path(canonicalRoot).join(
        "reproducibility/manifests/environment-lock.json").toString()
    let environmentAlreadyExists = exists(Path(environmentPath))
    var manifestClaim = CkbReproCompositionTempFile()
    var environmentClaim = CkbReproCompositionTempFile()
    try {
        if (exists(Path(manifestPath))) {
            manifestClaim = ckbCompositionAcquireTempFile(
                manifestPath, "manifest", manifestHash, hook)
            if (!manifestClaim.ok ||
                !manifestClaim.descriptor.syncParentAndValidate(forceFailure:
                    hook.forceParentFsyncFailure("manifest"))) {
                return ckbCompositionSealFailure(if (!manifestClaim.ok) {
                    manifestClaim.diagnostic
                } else { manifestClaim.descriptor.diagnostic }, options.json, 1)
            }
            let recovery = manifestClaim.descriptor.readPublicTarget(
                64 * 1024)
            if (!recovery[0]) {
                return ckbCompositionSealFailure(
                    "composition_recovery_read_failed", options.json, 1)
            }
            if (recovery[1] != manifestText.toArray()) {
                return ckbCompositionSealFailure(
                    "composition_recovery_bytes_mismatch", options.json, 1)
            }
            if (ckbReproBundleHash(recovery[1]) != manifestHash) {
                return ckbCompositionSealFailure(
                    "composition_recovery_hash_mismatch", options.json, 1)
            }
        } else {
            manifestClaim = ckbCompositionAcquireTempFile(
                manifestPath, "manifest", manifestHash, hook)
            if (!manifestClaim.ok) {
                return ckbCompositionSealFailure(
                    manifestClaim.diagnostic, options.json, 1)
            }
            if (!manifestClaim.descriptor.createPayload(
                    manifestText.toArray()) ||
                !parseCkbReproCliCompositionManifest(
                    manifestText.toArray())[0].ok) {
                return ckbCompositionSealFailure(
                    "composition_readback_failed", options.json, 1)
            }
            hook.beforeCompositionCommit()
            if (!manifestClaim.descriptor.publish()) {
                return ckbCompositionSealFailure(
                    manifestClaim.descriptor.diagnostic, options.json, 1)
            }
            hook.afterTargetPublished(manifestPath, "manifest")
            if (!manifestClaim.descriptor.syncAndValidate(forceFailure:
                    hook.forceParentFsyncFailure("manifest"))) {
                return ckbCompositionSealFailure(
                    manifestClaim.descriptor.diagnostic, options.json, 1)
            }
            let publicManifest = manifestClaim.descriptor.readPublicTarget(
                64 * 1024)
            if (!publicManifest[0] || publicManifest[1] != manifestText.toArray()) {
                return ckbCompositionSealFailure(
                    "composition_public_reload_failed", options.json, 1)
            }
        }
        if (hook.afterCompositionCommitted(manifestPath, options.mode)) {
            return ckbCompositionSealFailure(
                "composition_simulated_crash", options.json, 1)
        }
        let plannedRead = ckbCliCompositionRead(canonicalRoot,
            "reproducibility/manifests/environment-plan.json", 128 * 1024)
        if (!plannedRead[0].ok) {
            return ckbCompositionSealFailure(plannedRead[0].diagnostic,
                options.json, 1)
        }
        let planned = parseCkbReproEnvironmentLock(plannedRead[1])
        if (!planned[0].ok) {
            return ckbCompositionSealFailure(planned[0].diagnostic,
                options.json, 1)
        }
        let authorityRead = ckbCliCompositionRead(canonicalRoot,
            planned[1].attestationAuthorityManifestPath, 64 * 1024)
        if (!authorityRead[0].ok) {
            return ckbCompositionSealFailure(authorityRead[0].diagnostic,
                options.json, 1)
        }
        let authority = loadCkbReproVerifiedAttestationAuthority(
            authorityRead[1], planned[1].attestationAuthorityHash)
        if (!authority[0].ok) {
            return ckbCompositionSealFailure(authority[0].diagnostic,
                options.json, 1)
        }
        let frozen = freezeCkbReproEnvironmentLock(planned[1], manifestHash,
            authority[1], probe, canonicalRoot)
        if (!frozen[0].ok) {
            return ckbCompositionSealFailure(frozen[0].diagnostic,
                options.json, 1)
        }
        let environmentText = renderCkbReproEnvironmentLock(frozen[1])
        environmentClaim = ckbCompositionAcquireTempFile(
            environmentPath, "environment", manifestHash, hook)
        if (!environmentClaim.ok) {
            return ckbCompositionSealFailure(
                environmentClaim.diagnostic, options.json, 1)
        }
        if (!environmentAlreadyExists &&
            !environmentClaim.descriptor.createPayload(environmentText.toArray())) {
            return ckbCompositionSealFailure(
                "composition_readback_failed", options.json, 1)
        }
        let environmentCanonicalBytes = environmentText.toArray()
        let parsedEnvironment = parseCkbReproEnvironmentLock(
            environmentCanonicalBytes)
        if (!parsedEnvironment[0].ok ||
            !validateCkbReproEnvironmentLock(parsedEnvironment[1],
                mode: "execution").ok) {
            return ckbCompositionSealFailure("composition_readback_failed",
                options.json, 1)
        }
        if (environmentAlreadyExists) {
            if (!environmentClaim.descriptor.syncParentAndValidate(forceFailure:
                    hook.forceParentFsyncFailure("environment"))) {
                return ckbCompositionSealFailure(
                    environmentClaim.descriptor.diagnostic, options.json, 1)
            }
        } else {
            // The environment lock is the sole publication point. The loader
            // reads it first, so a composition-only crash is not executable.
            if (!environmentClaim.descriptor.publish()) {
                return ckbCompositionSealFailure(
                    environmentClaim.descriptor.diagnostic, options.json, 1)
            }
            hook.afterTargetPublished(environmentPath, "environment")
            if (!environmentClaim.descriptor.syncAndValidate(forceFailure:
                    hook.forceParentFsyncFailure("environment"))) {
                return ckbCompositionSealFailure(
                    environmentClaim.descriptor.diagnostic, options.json, 1)
            }
        }
        if (!manifestClaim.descriptor.syncParentAndValidate()) {
            return ckbCompositionSealFailure(
                manifestClaim.descriptor.diagnostic, options.json, 1)
        }
        // Environment is the publication point. Reload it first, then the
        // composition anchor, through the bound public parent.
        let publicEnvironment = environmentClaim.descriptor.readPublicTarget(
            128 * 1024)
        let publicComposition = manifestClaim.descriptor.readPublicTarget(
            64 * 1024)
        if (!publicEnvironment[0] ||
            publicEnvironment[1] != environmentCanonicalBytes ||
            !publicComposition[0] ||
            publicComposition[1] != manifestText.toArray() ||
            ckbReproBundleHash(publicComposition[1]) != manifestHash) {
            return ckbCompositionSealFailure(
                "composition_public_pair_reload_failed", options.json, 1)
        }
    } catch (_: Exception) {
        return ckbCompositionSealFailure("composition_commit_failed",
            options.json, 1)
    } finally {
        ckbCompositionReleaseTempFile(environmentClaim)
        ckbCompositionReleaseTempFile(manifestClaim)
        // A committed composition is an immutable pre-publication anchor.
        // Never roll it back: another invocation may already have adopted it.
        // Without the environment-lock publication point it is not executable,
        // and an exact-input rerun can safely recover it.
    }
    let out = CkbReproCompositionSealExecution()
    out.ok = true; out.exitCode = 0; out.diagnostic = "ok"
    out.output = ckbCompositionSealRender(true, "ok", options.mode,
        manifestHash, options.json)
    out
}

private func ckbCompositionSealFailure(diagnostic: String, json: Bool,
    exitCode: Int64): CkbReproCompositionSealExecution {
    let out = CkbReproCompositionSealExecution()
    out.exitCode = exitCode; out.diagnostic = diagnostic
    out.output = ckbCompositionSealRender(false, diagnostic, "", "", json)
    out
}

private func ckbCompositionSealRender(ok: Bool, diagnostic: String,
    mode: String, manifestHash: String, json: Bool): String {
    if (json) {
        return "{\"ok\":${ok},\"diagnostic\":\"${ckbCliCompositionJson(diagnostic)}\"," +
            "\"mode\":\"${ckbCliCompositionJson(mode)}\"," +
            "\"compositionManifestHash\":\"${manifestHash}\"}"
    }
    if (ok) {
        "CKB reproduction composition sealed. mode=${ckbCliCompositionSafe(mode)} " +
            "hash=${manifestHash}\n"
    } else {
        "CKB reproduction composition seal failed: " +
            "${ckbCliCompositionSafe(diagnostic)}\n"
    }
}

private func ckbCliCompositionSafe(value: String): String {
    let runes = redactSensitive(value).toRuneArray()
    let count = if (runes.size < 160) { runes.size } else { 160 }
    String(runes[0..count])
}

private func ckbCliCompositionJson(value: String): String {
    ckbCliCompositionSafe(value).replace("\\", "\\\\")
        .replace("\"", "\\\"").replace("\n", "\\n")
        .replace("\r", "\\r").replace("\t", "\\t")
}

public func ckbReproCliCompositionRoles(mode: String): Array<String> {
    if (mode == "p3-vector-build") {
        return ["runtime_config", "path_policy", "local_root_map",
            "api_routes", "path_context"]
    }
    if (mode == "p3-snapshot-create") {
        return ["runtime_config", "path_policy", "local_root_map",
            "api_routes", "path_context"]
    }
    if (mode == "p3-snapshot-restore" || mode == "p3-snapshot-verify") {
        return ["runtime_config", "path_policy", "local_root_map",
            "api_routes", "path_context", "qdrant_manifest"]
    }
    if (mode == "p3-parity") {
        return ["runtime_config", "path_policy", "local_root_map",
            "api_routes", "path_context", "mcp_stdio_command"]
    }
    if (mode == "p3-parity-build") {
        return ["runtime_config", "path_policy", "local_root_map",
            "api_routes", "path_context", "mcp_stdio_command",
            "logical_manifest"]
    }
    if (mode == "p4-build") {
        return ["public_build_input_manifest", "private_build_authority",
            "path_policy", "local_root_map", "api_routes", "path_context",
            "eval_support",
            "leakage_authority", "runtime_config"]
    }
    if (mode == "p4-promote") {
        return ["runtime_config", "path_policy", "local_root_map",
            "api_routes", "path_context"]
    }
    if (mode == "run-certify") {
        return ["logical_manifest", "qdrant_manifest", "parity_manifest",
            "build_proof",
            "path_policy", "local_root_map", "api_routes",
            "public_build_input_manifest", "private_build_authority",
            "path_context", "eval_support", "leakage_authority",
            "runtime_transport", "mcp_stdio_command", "runner_inputs",
            "runner_authority",
            "reference_template", "authority_manifest",
            "run_critical_manifest"]
    }
    if (mode == "release-verify") {
        return ["logical_manifest", "qdrant_manifest", "parity_manifest",
            "build_proof",
            "path_policy", "local_root_map", "api_routes",
            "public_build_input_manifest", "private_build_authority",
            "path_context", "eval_support", "leakage_authority",
            "runtime_transport", "mcp_stdio_command",
            "reference_template", "run_critical_manifest",
            "release_inputs_manifest"]
    }
    Array<String>()
}

public func ckbReproCliCompositionRoleRelativePath(role: String): String {
    if (role == "public_build_input_manifest") {
        return "assets/public-build-input-manifest.json"
    }
    if (role == "private_build_authority") {
        return "private-authority/build-authority.json"
    }
    if (role == "runner_authority") {
        return "private-authority/runner-authority.json"
    }
    if (role == "local_root_map") {
        return "private-authority/local-roots.json"
    }
    if (role == "path_context") {
        return "private-authority/path-context.json"
    }
    if (role == "eval_support") {
        return "private-authority/eval-support.json"
    }
    if (role == "leakage_authority") {
        return "private-authority/leakage.json"
    }
    if (ckbReproCliCompositionKnownRole(role)) { return "assets/${role}.json" }
    ""
}

private func ckbReproCliCompositionKnownRole(role: String): Bool {
    for (mode in ["p3-vector-build", "p3-snapshot-create",
        "p3-snapshot-restore", "p3-snapshot-verify", "p3-parity",
        "p3-parity-build", "p4-build", "p4-promote", "run-certify",
        "release-verify"]) {
        if (ckbReproCliCompositionRoles(mode).contains(role)) { return true }
    }
    false
}

private func ckbCliCompositionForbiddenB(value: String): Bool {
    let lower = value.toAsciiLower()
    for (word in ["runner", "model", "provider", "credential", "claude",
        "glm", "secret", "token", "authorization"]) {
        if (lower.contains(word)) { return true }
    }
    false
}

private func ckbCliCompositionHash(value: String): Bool {
    let expected = "sha256:".toRuneArray(); var index: Int64 = 0
    for (rune in value.runes()) {
        if (index < expected.size) {
            if (rune != expected[index]) { return false }
        } else if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) { return false }
        index += 1
    }
    index == 71
}

private func ckbCliCompositionEnvironmentVariable(value: String): Bool {
    if (value == "" || value.toRuneArray().size > 128) { return false }
    var index: Int64 = 0
    for (rune in value.runes()) {
        let upper = rune >= r'A' && rune <= r'Z'
        let digit = rune >= r'0' && rune <= r'9'
        if (!(upper || rune == r'_' || (index > 0 && digit))) { return false }
        index += 1
    }
    true
}

private func ckbCliCompositionRolePath(role: String, path: String): Bool {
    if (role == "public_build_input_manifest") {
        return path == "assets/public-build-input-manifest.json"
    }
    if (role == "private_build_authority" || role == "local_root_map" ||
        role == "path_context" || role == "eval_support" ||
        role == "leakage_authority") {
        return path.startsWith("private-authority/")
    }
    if (role == "runner_authority") {
        return path.startsWith("private-authority/")
    }
    !path.startsWith("private-authority/")
}

private func ckbCliCompositionEnvironmentLockFields(): Array<String> {
    ["schemaVersion", "identityStatus", "certifiedPlatform",
        "cpuArchitecture", "cangjieSdkVersion", "cangjieSdkHash",
        "opensslVersion", "serviceHeap", "qdrantImageDigest",
        "runCandidateCommit", "runCriticalFilesManifestHash",
        "runCriticalTreeHash", "compositionManifestPath",
        "compositionManifestHash", "claudeCodeVersion", "glmProvider",
        "glmBaseUrl", "glmModel", "modelFingerprint", "glmCredentialEnv",
        "embeddingProvider", "embeddingModel", "embeddingDimension",
        "embeddingCredentialEnv", "archiveTool", "archiveToolVersion",
        "experimentGroup", "ckbRequired", "localDocsPolicy", "modelEffort",
        "modelBudget", "timeoutSeconds", "transportRetryBudget",
        "promptHash", "mcpCommand", "mcpTransport", "sandboxCapability",
        "datasetVersion", "authorityDeliveryHash",
        "attestationAuthorityManifestPath", "attestationAuthorityHash"]
}

private func ckbCliCompositionPathForRole(
    manifest: CkbReproCliCompositionManifest, role: String): String {
    for (asset in manifest.assets) {
        if (asset.role == role) { return asset.relativePath }
    }
    ""
}

private func ckbCliCompositionRead(root: String, relativePath: String,
    maxBytes: Int64): (CkbReproContractResult, Array<UInt8>) {
    if (!validateCkbReproBundleRelativePath(relativePath).ok ||
        maxBytes < 1 || maxBytes > 536870912) {
        return (ckbCliCompositionFailure("cli_composition_file_invalid"),
            Array<UInt8>())
    }
    let backend = CkbReproFilesystemBundleReadBackend()
    if (!backend.rootExists(root) || backend.rootIdentity(root) == "") {
        return (ckbCliCompositionFailure("cli_composition_root_invalid"),
            Array<UInt8>())
    }
    let expected = CkbReproBundleReadEntry()
    expected.relativePath = relativePath
    try {
        let handle = backend.open(root, expected)
        let bytes = ArrayList<UInt8>()
        try {
            let initial = handle.observedEntry()
            if (!handle.noFollow() || !initial.withinRoot ||
                initial.relativePath != relativePath ||
                initial.kind != "regular" || initial.identity == "" ||
                initial.size < 0 || initial.size > maxBytes) {
                return (ckbCliCompositionFailure(
                    "cli_composition_file_invalid"), Array<UInt8>())
            }
            while (true) {
                let buffer = Array<UInt8>(65536, repeat: UInt8(0))
                let count = handle.read(buffer)
                if (count < 0 || count > buffer.size ||
                    bytes.size + count > maxBytes) {
                    return (ckbCliCompositionFailure(
                        "cli_composition_file_read_failed"), Array<UInt8>())
                }
                if (count == 0) { break }
                bytes.add(all: if (count == buffer.size) { buffer }
                    else { buffer[0..count].clone() })
            }
            let observed = handle.observedEntry()
            if (!handle.noFollow() || !observed.withinRoot ||
                observed.relativePath != initial.relativePath ||
                observed.kind != initial.kind ||
                observed.identity != initial.identity ||
                observed.size != initial.size || bytes.size != initial.size) {
                return (ckbCliCompositionFailure(
                    "cli_composition_file_changed"), Array<UInt8>())
            }
        } finally { handle.close() }
        (ckbCliCompositionSuccess(), bytes.toArray())
    } catch (_: Exception) {
        (ckbCliCompositionFailure("cli_composition_file_invalid"),
            Array<UInt8>())
    }
}

private func ckbCliCompositionJoin(values: ArrayList<String>): String {
    let out = StringBuilder()
    for (i in 0..values.size) {
        if (i > 0) { out.append(",") }; out.append(values[i])
    }
    out.toString()
}

private func ckbCliCompositionFailure(code: String): CkbReproContractResult {
    let out = CkbReproContractResult(); out.diagnostic = code; out
}

private func ckbCliCompositionSuccess(): CkbReproContractResult {
    let out = CkbReproContractResult(); out.ok = true; out.diagnostic = "ok"; out
}
