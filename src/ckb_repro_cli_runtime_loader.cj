package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.fs.Path
import stdx.encoding.json.*

class CkbReproProductionCliComposition {
    var ok: Bool = false
    var diagnostic: String = "production_composition_not_loaded"
    var json: Bool = false
    var mode: String = ""
    var manifestPath: String = ""
    var args: Array<String> = Array<String>()
    var loaded: CkbReproCliCompositionLoadResult =
        CkbReproCliCompositionLoadResult()
    public init() {}
}

class CkbReproCliPathContext {
    var context: CkbPortablePathContext = CkbPortablePathContext()
    var releasePolicy: CkbReleasePathPolicy = CkbReleasePathPolicy()
    public init() {}
}

func loadCkbReproProductionCliComposition(args: Array<String>, mode: String):
    CkbReproProductionCliComposition {
    let out = CkbReproProductionCliComposition()
    out.mode = mode
    if (mode == "") {
        out.diagnostic = "production_composition_mode_invalid"; return out
    }
    let forwarded = ArrayList<String>()
    var seenManifest = false
    var i: Int64 = 0
    while (i < args.size) {
        if (args[i] == "--composition-manifest") {
            if (seenManifest || i + 1 >= args.size ||
                args[i + 1].startsWith("--")) {
                out.diagnostic = "composition_manifest_argument_invalid"
                return out
            }
            seenManifest = true; out.manifestPath = args[i + 1]; i += 2
            continue
        }
        if (args[i] == "--json") { out.json = true }
        forwarded.add(args[i]); i += 1
    }
    if (!seenManifest || !Path(out.manifestPath).isAbsolute()) {
        out.diagnostic = "production_composition_manifest_required"
        return out
    }
    out.loaded = loadCkbReproCliComposition(out.manifestPath, mode)
    if (!out.loaded.ok) {
        out.diagnostic = out.loaded.diagnostic; return out
    }
    out.args = forwarded.toArray(); out.ok = true; out.diagnostic = "ok"; out
}

func ckbReproCompositionAssetBytes(
    loaded: CkbReproCliCompositionLoadResult, role: String):
    (Bool, Array<UInt8>) {
    var matched = false
    var bytes = Array<UInt8>()
    for (asset in loaded.assets) {
        if (asset.role == role) {
            if (matched) { return (false, Array<UInt8>()) }
            matched = true; bytes = asset.bytes
        }
    }
    (matched, bytes)
}

func ckbReproCompositionAssetPath(
    loaded: CkbReproCliCompositionLoadResult, role: String):
    (Bool, String) {
    var matched = false
    var path = ""
    for (asset in loaded.assets) {
        if (asset.role == role) {
            if (matched) { return (false, "") }
            matched = true
            path = Path(loaded.root).join(asset.relativePath).toString()
        }
    }
    (matched, path)
}

func parseCkbReproCliPathContext(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbReproCliPathContext) {
    let out = CkbReproCliPathContext()
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (ckbReproRuntimeCompositionFailure(
            "invalid_response_encoding"), out)
    }
    try {
        let object = JsonValue.fromStr(text).asObject()
        if (object.size() != 7 || object.get("schemaVersion").getOrThrow()
            .asString().getValue() != "ckb-repro-cli-path-context-v1") {
            return (ckbReproRuntimeCompositionFailure(
                "path_context_field_contract_invalid"), out)
        }
        let policy = parseCkbPortablePathPolicy(object.get("portablePolicy")
            .getOrThrow().asString().getValue().toArray())
        let roots = parseCkbPortableLocalRootMap(object.get("localRootMap")
            .getOrThrow().asString().getValue().toArray())
        let routes = parseCkbReproApiRoutes(object.get("apiRoutes")
            .getOrThrow().asString().getValue().toArray())
        if (!policy[0].ok || !roots[0].ok || !routes[0].ok) {
            return (ckbReproRuntimeCompositionFailure(
                "path_context_component_invalid"), out)
        }
        out.context.policy = policy[1]; out.context.localRoots = roots[1]
        for (route in routes[1]) { out.context.apiRoutes.add(route) }
        out.releasePolicy.worktreeRoot = object.get("worktreeRoot")
            .getOrThrow().asString().getValue()
        out.releasePolicy.productionStoreRoot = object
            .get("productionStoreRoot").getOrThrow().asString().getValue()
        out.releasePolicy.userConfigRoot = object.get("userConfigRoot")
            .getOrThrow().asString().getValue()
        if (!validateCkbPortablePathContext(out.context).ok ||
            !Path(out.releasePolicy.worktreeRoot).isAbsolute() ||
            !Path(out.releasePolicy.productionStoreRoot).isAbsolute() ||
            !Path(out.releasePolicy.userConfigRoot).isAbsolute()) {
            return (ckbReproRuntimeCompositionFailure(
                "path_context_invalid"), CkbReproCliPathContext())
        }
    } catch (_: Exception) {
        return (ckbReproRuntimeCompositionFailure(
            "path_context_malformed_json"), CkbReproCliPathContext())
    }
    let result = CkbReproContractResult(); result.ok = true
    result.diagnostic = "ok"; (result, out)
}

func ckbReproP3CompositionMode(args: Array<String>): String {
    let options = parseCkbP3CliOptions(
        ckbReproArgsWithoutCompositionManifest(args))
    if (options.diagnostic != "ok") { return "" }
    match (options.mode) {
        case "build" => "p3-vector-build"
        case "create" => "p3-snapshot-create"
        case "restore" => "p3-snapshot-restore"
        case "verify" => "p3-snapshot-verify"
        case "parity" => "p3-parity"
        case _ => ""
    }
}

func runCkbReproP3ProductionComposition(args: Array<String>):
    CkbReproMainCliResult {
    let forwarded = ckbReproArgsWithoutCompositionManifest(args)
    let options = parseCkbP3CliOptions(forwarded)
    if (options.diagnostic != "ok") {
        return ckbReproP3CompositionFailure(options.diagnostic,
            args.contains("--json"))
    }
    let prepared = loadCkbReproProductionCliComposition(args,
        ckbReproP3CompositionMode(args))
    if (!prepared.ok) {
        return ckbReproP3CompositionFailure(prepared.diagnostic,
            prepared.json)
    }
    let runtimeAsset = ckbReproCompositionAssetPath(
        prepared.loaded, "runtime_config")
    let runtimeBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "runtime_config")
    let pathBytes = ckbReproCompositionAssetBytes(
        prepared.loaded, "path_context")
    if (!runtimeAsset[0] || !runtimeBytes[0] || !pathBytes[0]) {
        return ckbReproP3CompositionFailure(
            "p3_composition_asset_missing", prepared.json)
    }
    try { _ = String.fromUtf8(runtimeBytes[1]) } catch (_: Exception) {
        return ckbReproP3CompositionFailure(
            "invalid_response_encoding", prepared.json)
    }
    let pathContext = parseCkbReproCliPathContext(pathBytes[1])
    if (!pathContext[0].ok) {
        return ckbReproP3CompositionFailure(
            pathContext[0].diagnostic, prepared.json)
    }
    let assembly = CkbReproP3ProductionAssembly()
    assembly.mode = options.mode
    assembly.runtime = loadCkbRuntimeConfig(runtimeAsset[1])
    assembly.candidateStoreRoot = options.candidateRoot
    assembly.pathContext = pathContext[1].context
    assembly.pathPolicy = pathContext[1].releasePolicy
    if (options.mode == "parity") {
        let stdio = ckbReproCompositionAssetBytes(
            prepared.loaded, "mcp_stdio_command")
        if (!stdio[0]) {
            return ckbReproP3CompositionFailure(
                "p3_composition_asset_missing", prepared.json)
        }
        let parsed = parseCkbMcpStdioCommandSpec(stdio[1])
        if (!parsed[0].ok) {
            return ckbReproP3CompositionFailure(
                parsed[0].diagnostic, prepared.json)
        }
        assembly.stdioSpec = parsed[1]
    }
    if (options.mode == "restore" || options.mode == "verify") {
        let manifest = ckbReproCompositionAssetBytes(
            prepared.loaded, "qdrant_manifest")
        let manifestPath = ckbReproCompositionAssetPath(
            prepared.loaded, "qdrant_manifest")
        if (!manifest[0] || !manifestPath[0] ||
            options.manifest != manifestPath[1] ||
            !parseCkbQdrantSnapshotManifest(manifest[1])[0].ok) {
            return ckbReproP3CompositionFailure(
                "p3_qdrant_manifest_authority_invalid", prepared.json)
        }
    }
    executeCkbReproP3ProductionAssembly(forwarded, assembly)
}

func ckbReproP4CompositionMode(args: Array<String>): String {
    let options = parseCkbP4CliOptions(
        ckbReproArgsWithoutCompositionManifest(args))
    if (options.diagnostic != "ok") { return "" }
    if (options.command == "ckb-repro-build") { "p4-build" }
    else if (options.command == "ckb-repro-promote") { "p4-promote" }
    else { "" }
}

func ckbReproP8CompositionMode(args: Array<String>): String {
    let forwarded = ckbReproVerifyArgsWithoutPresentation(args)
    let parsed = parseCkbReproVerifyOptions(forwarded)
    if (!parsed.ok) { return "" }
    if (parsed.options.mode == "run-certify") { "run-certify" }
    else if (parsed.options.mode == "release-verify") { "release-verify" }
    else { "" }
}

func ckbReproArgsWithoutCompositionManifest(args: Array<String>):
    Array<String> {
    let out = ArrayList<String>(); var i: Int64 = 0
    while (i < args.size) {
        if (args[i] == "--composition-manifest" && i + 1 < args.size) {
            i += 2
        } else { out.add(args[i]); i += 1 }
    }
    out.toArray()
}

func ckbReproVerifyArgsWithoutPresentation(args: Array<String>):
    Array<String> {
    let stripped = ckbReproArgsWithoutCompositionManifest(args)
    let out = ArrayList<String>()
    for (value in stripped) {
        if (value != "ckb-repro-verify" && value != "--json") {
            out.add(value)
        }
    }
    out.toArray()
}

private func ckbReproRuntimeCompositionFailure(code: String):
    CkbReproContractResult {
    let out = CkbReproContractResult(); out.diagnostic = code; out
}

private func ckbReproP3CompositionFailure(code: String, json: Bool):
    CkbReproMainCliResult {
    let result = CkbP3CliOperationResult(); result.diagnostic = code
    CkbReproMainCliResult(true, 2, if (json) {
        renderCkbP3CliJson(result)
    } else { renderCkbP3CliHuman(result) })
}
