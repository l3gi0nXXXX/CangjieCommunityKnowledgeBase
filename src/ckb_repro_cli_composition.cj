package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashSet}
import std.fs.Path
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
    public let bytes = ArrayList<Array<UInt8>>()
    public init() {}
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
    try {
        let root = JsonValue.fromStr(text).asObject()
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
    let expected = ckbCliCompositionRoles(manifest.mode)
    if (expected.size == 0 || manifest.assets.size != expected.size) {
        return ckbCliCompositionFailure("cli_composition_mode_contract_invalid")
    }
    let roles = HashSet<String>(); let paths = HashSet<String>()
    for (asset in manifest.assets) {
        if (!expected.contains(asset.role) || roles.contains(asset.role) ||
            paths.contains(asset.relativePath) || asset.size < 0 ||
            asset.size > 536870912 || !ckbCliCompositionHash(asset.sha256) ||
            !validateCkbReproBundleRelativePath(asset.relativePath).ok) {
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
    for (role in ckbCliCompositionRoles(manifest.mode)) {
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
    let suffix = "/reproducibility/manifests/runtime-composition.json"
    if (!Path(path).isAbsolute() || !path.endsWith(suffix)) {
        out.diagnostic = "cli_composition_path_invalid"; return out
    }
    out.root = path[0..path.size - suffix.size]
    let reader = CkbP8ManifestAuthorizedReader()
    let started = reader.start(out.root)
    if (!started.ok) { out.diagnostic = started.diagnostic; return out }
    try {
        let manifestBytes = reader.read("repro_cli_composition",
            "reproducibility/manifests/runtime-composition.json", 64 * 1024)
        if (!manifestBytes[0].ok) {
            out.diagnostic = manifestBytes[0].diagnostic; return out
        }
        let parsed = parseCkbReproCliCompositionManifest(manifestBytes[1])
        if (!parsed[0].ok || parsed[1].mode != expectedMode) {
            out.diagnostic = if (!parsed[0].ok) { parsed[0].diagnostic }
                else { "cli_composition_mode_mismatch" }
            return out
        }
        for (asset in parsed[1].assets) {
            let captured = reader.read(asset.role, asset.relativePath,
                asset.size)
            if (!captured[0].ok || captured[1].size != asset.size ||
                ckbReproBundleHash(captured[1]) != asset.sha256) {
                out.diagnostic = "cli_composition_asset_authority_invalid"
                return out
            }
            out.bytes.add(captured[1])
        }
        let finished = reader.finish()
        if (!finished.ok) { out.diagnostic = finished.diagnostic; return out }
        out.manifest = parsed[1]; out.ok = true; out.diagnostic = "ok"; out
    } catch (_: Exception) {
        out.diagnostic = "cli_composition_load_failed"; out
    }
}

private func ckbCliCompositionRoles(mode: String): Array<String> {
    if (mode == "p3-vector-build") {
        return ["runtime_config", "path_context"]
    }
    if (mode == "p3-snapshot-create" || mode == "p3-snapshot-restore" ||
        mode == "p3-snapshot-verify") {
        return ["runtime_config", "path_context", "qdrant_manifest"]
    }
    if (mode == "p3-parity") {
        return ["runtime_config", "mcp_stdio_command"]
    }
    if (mode == "p4-build") {
        return ["public_build_input_manifest", "private_build_authority",
            "runtime_config"]
    }
    if (mode == "p4-promote") {
        return ["runtime_config", "path_context"]
    }
    if (mode == "run-certify") {
        return ["logical_manifest", "qdrant_manifest", "parity_manifest",
            "path_policy", "local_root_map", "api_routes",
            "public_build_input_manifest", "private_build_authority",
            "runtime_transport", "mcp_stdio_command", "runner_inputs",
            "reference_template", "authority_manifest",
            "environment_preflight"]
    }
    if (mode == "release-verify") {
        return ["logical_manifest", "qdrant_manifest", "parity_manifest",
            "path_policy", "local_root_map", "api_routes",
            "public_build_input_manifest", "private_build_authority",
            "runtime_transport", "mcp_stdio_command",
            "release_asset_authority"]
    }
    Array<String>()
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
    if (!value.startsWith("sha256:") || value.toRuneArray().size != 71) {
        return false
    }
    for (rune in value[7..value.size].runes()) {
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) { return false }
    }
    true
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
