package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashSet}
import std.convert.Parsable
import std.fs.{Directory, FileInfo, Path, canonicalize, exists, remove}
import std.sort.*

public class CkbReproCompositionStageInput {
    public var role: String = ""
    public var path: String = ""
    public init() {}
}

public class CkbReproCompositionStageOptions {
    public var root: String = ""
    public var mode: String = ""
    public var authorityStore: String = ""
    public var publicInputRoot: String = ""
    public var environmentPlan: String = ""
    public var attestationAuthority: String = ""
    public var worktreeRoot: String = ""
    public var productionStoreRoot: String = ""
    public var userConfigRoot: String = ""
    public var temporaryRoot: String = ""
    public var outputRoot: String = ""
    public var ckbExecutable: String = ""
    public var dockerExecutable: String = ""
    public var qdrantEndpoint: String = ""
    public var restEndpoint: String = ""
    public var mcpHttpEndpoint: String = ""
    public var qdrantImageReference: String = ""
    public var runtimeTimeoutMillis: Int64 = 0
    public var runId: String = ""
    public var runsRoot: String = ""
    public var datasetRoot: String = ""
    public var authorityManifestPath: String = ""
    public var ckbConfig: String = ""
    public var ckbStore: String = ""
    public var ckbHttpBase: String = ""
    public var claudeExecutable: String = ""
    public var docsRoot: String = ""
    public var candidateVersion: String = ""
    public var knowledgeVersion: String = ""
    public var providerIdentityHash: String = ""
    public var providerIdentityArtifactPath: String = ""
    public var frozenCandidateManifestPath: String = ""
    public var observedEnvironmentPath: String = ""
    public var certificationPreflightPath: String = ""
    public var certificationRunManifestPath: String = ""
    public var referenceSource: String = ""
    public var json: Bool = false
    public var prepareOnly: Bool = false
    public var diagnostic: String = "not_parsed"
    public let inputs = ArrayList<CkbReproCompositionStageInput>()
    public let credentialEnvironmentVariables = ArrayList<String>()
    public let localRoots = ArrayList<CkbPortableLocalRoot>()
    public init() {}
}

public interface CkbReproCompositionRuntimeProbe {
    func inspectQdrantImage(dockerExecutable: String,
        imageReference: String): (String, String)
}

public class CkbReproProductionCompositionRuntimeProbe <:
    CkbReproCompositionRuntimeProbe {
    public init() {}
    public func inspectQdrantImage(dockerExecutable: String,
        imageReference: String): (String, String) {
        let result = ckbReproBoundedProbeCommand(dockerExecutable,
            ["image", "inspect", "--format={{.Id}}", imageReference], 4096)
        if (result[0] != 0 || result[1] != "ok") {
            return ("composition_stage_qdrant_probe_failed", "")
        }
        let normalized = ckbReproNormalizeProbeOutput(result[2].toArray(), 4096)
        if (normalized[0] != "ok" || !normalized[1].startsWith("sha256:")) {
            return ("composition_stage_qdrant_probe_invalid", "")
        }
        ("ok", normalized[1])
    }
}

public class CkbReproCompositionStageExecution {
    public var ok: Bool = false
    public var exitCode: Int64 = 2
    public var diagnostic: String = "not_run"
    public var output: String = ""
    public var providerCalls: Int64 = 0
    public var modelCalls: Int64 = 0
    public var runnerCalls: Int64 = 0
    public init() {}
}

public class CkbReproCompositionRuntimeAssets {
    public var contract: CkbReproContractResult = CkbReproContractResult()
    public var runtime: CkbP8OwnedLocalRuntimeAuthority =
        CkbP8OwnedLocalRuntimeAuthority()
    public var mcp: CkbMcpStdioCommandSpec = CkbMcpStdioCommandSpec()
    public init() {}
}

private class CkbReproCompositionPublication {
    var root: String = ""
    var rootIdentity: String = ""
    var assetsIdentity: String = ""
    var privateIdentity: String = ""
    var publicIdentity: String = ""
    var reproducibilityIdentity: String = ""
    var manifestsIdentity: String = ""
    init() {}
}

public func probeAndRenderCkbReproRuntimeAssets(ckbExecutable: String,
    dockerExecutable: String, qdrantEndpoint: String, restEndpoint: String,
    mcpHttpEndpoint: String, qdrantImageReference: String,
    timeoutMillis: Int64, environment: CkbReproEnvironmentLock,
    probe: CkbReproCompositionRuntimeProbe): CkbReproCompositionRuntimeAssets {
    let out = CkbReproCompositionRuntimeAssets()
    let image = probe.inspectQdrantImage(dockerExecutable,
        qdrantImageReference)
    if (image[0] != "ok") {
        out.contract = ckbCompositionStageContractFailure(image[0]); return out
    }
    if (image[1] != environment.qdrantImageDigest) {
        out.contract = ckbCompositionStageContractFailure(
            "p8b_qdrant_image_authority_mismatch"); return out
    }
    let runtime = buildCkbP8OwnedLocalRuntimeAuthority(ckbExecutable,
        dockerExecutable, qdrantEndpoint, restEndpoint, mcpHttpEndpoint,
        qdrantImageReference, image[1], timeoutMillis)
    if (!runtime[0].ok) { out.contract = runtime[0]; return out }
    let transport = validateCkbP8BTransportEnvironment(runtime[1], environment)
    if (!transport.ok) { out.contract = transport; return out }
    let mcp = buildCkbP8EmptyMcpStdioCommand(runtime[1])
    if (!mcp[0].ok) { out.contract = mcp[0]; return out }
    out.contract = ckbCompositionStageContractSuccess()
    out.runtime = runtime[1]; out.mcp = mcp[1]
    out
}

public func parseCkbReproCompositionStageOptions(args: Array<String>):
    CkbReproCompositionStageOptions {
    let out = CkbReproCompositionStageOptions()
    if (args.size == 0 || args[0] != "ckb-repro-composition-stage") {
        out.diagnostic = "composition_stage_command_required"; return out
    }
    let seen = HashSet<String>(); var index: Int64 = 1
    while (index < args.size) {
        let name = args[index]
        if (name == "--json" || name == "--prepare-only") {
            if (seen.contains(name)) {
                out.diagnostic = "duplicate_argument:${name}"; return out
            }
            seen.add(name)
            if (name == "--json") { out.json = true }
            else { out.prepareOnly = true }
            index += 1; continue
        }
        if (!ckbCompositionStageOptionName(name)) {
            out.diagnostic = "unknown_argument:${name}"; return out
        }
        if (name != "--input" && name != "--credential-env" &&
            name != "--local-root" &&
            seen.contains(name)) {
            out.diagnostic = "duplicate_argument:${name}"; return out
        }
        if (index + 1 >= args.size || args[index + 1].startsWith("--")) {
            out.diagnostic = "missing_argument_value:${name}"; return out
        }
        let value = args[index + 1]
        if (name == "--local-root") {
            let parsed = ckbCompositionStageParseLocalRoot(value)
            if (parsed[0] != "ok") { out.diagnostic = parsed[0]; return out }
            out.localRoots.add(parsed[1])
        } else if (name == "--credential-env") {
            out.credentialEnvironmentVariables.add(value)
        } else if (name == "--input") {
            let separator = match (value.indexOf("=")) {
                case Some(found) => found
                case None => -1
            }
            let runes = value.toRuneArray()
            if (separator <= 0 || separator >= runes.size - 1) {
                out.diagnostic = "composition_stage_input_invalid"; return out
            }
            let input = CkbReproCompositionStageInput()
            input.role = String(runes[0..separator])
            input.path = String(runes[separator + 1..runes.size])
            out.inputs.add(input)
        } else {
            seen.add(name); ckbCompositionStageSet(out, name, value)
        }
        index += 2
    }
    out.diagnostic = validateCkbReproCompositionStageOptions(out)
    out
}

public func validateCkbReproCompositionStageOptions(
    options: CkbReproCompositionStageOptions): String {
    if (!ckbCompositionStageModeAllowed(options.mode) ||
        !ckbCompositionStageCanonicalNewPath(options.root) ||
        options.environmentPlan == "" ||
        (!options.prepareOnly && options.attestationAuthority == "")) {
        return "composition_stage_options_invalid"
    }
    let roles = ckbReproCliCompositionRoles(options.mode)
    if (roles.size == 0) { return "composition_stage_mode_invalid" }
    let seen = HashSet<String>()
    for (input in options.inputs) {
        if (!roles.contains(input.role) || seen.contains(input.role) ||
            !ckbCompositionStageTrustedInputRole(input.role, options.mode) ||
            !ckbCompositionStageCanonicalExistingFile(input.path)) {
            return "composition_stage_input_invalid"
        }
        seen.add(input.role)
    }
    for (path in [options.environmentPlan, options.attestationAuthority]) {
        if (path == "" && options.prepareOnly) { continue }
        if (!ckbCompositionStageCanonicalExistingFile(path)) {
            return "composition_stage_input_invalid"
        }
    }
    if (options.mode == "p4-build" || options.mode == "run-certify") {
        if (!ckbCompositionStageCanonicalExistingDirectory(
                options.authorityStore) ||
            !ckbCompositionStageCanonicalExistingDirectory(
            options.publicInputRoot) ||
            !ckbCompositionStageCanonicalExistingDirectory(options.worktreeRoot) ||
            !ckbCompositionStageCanonicalExistingDirectory(
                options.productionStoreRoot) ||
            !ckbCompositionStageCanonicalExistingDirectory(options.userConfigRoot) ||
            !ckbCompositionStageCanonicalNewPath(options.temporaryRoot) ||
            !ckbCompositionStageCanonicalNewPath(options.outputRoot)) {
            return "composition_stage_authority_inputs_required"
        }
        if (!ckbCompositionStageLocalRootMap(options)[0].ok) {
            return "composition_stage_local_root_invalid"
        }
    }
    if (options.mode == "run-certify" &&
        !ckbCompositionStageRunCertifyOptionsValid(options)) {
        return "composition_stage_run_certify_inputs_required"
    }
    let protected = ArrayList<String>()
    for (path in [options.authorityStore, options.publicInputRoot,
        options.environmentPlan, options.attestationAuthority,
        options.worktreeRoot, options.productionStoreRoot,
        options.userConfigRoot, options.temporaryRoot, options.outputRoot,
        options.ckbExecutable, options.dockerExecutable, options.runsRoot,
        options.datasetRoot, options.authorityManifestPath,
        options.ckbConfig, options.ckbStore, options.claudeExecutable,
        options.docsRoot, options.providerIdentityArtifactPath,
        options.frozenCandidateManifestPath, options.observedEnvironmentPath,
        options.certificationPreflightPath,
        options.certificationRunManifestPath, options.referenceSource]) {
        if (path != "") { protected.add(path) }
    }
    for (input in options.inputs) { protected.add(input.path) }
    for (path in protected) {
        if (ckbCompositionStagePathsOverlap(options.root, path)) {
            return "composition_stage_roots_overlap"
        }
    }
    for (left in [options.temporaryRoot, options.outputRoot]) {
        if (left == "") { continue }
        for (right in [options.authorityStore, options.publicInputRoot,
            options.worktreeRoot, options.productionStoreRoot,
            options.userConfigRoot]) {
            if (right != "" && ckbCompositionStagePathsOverlap(left, right)) {
                return "composition_stage_roots_overlap"
            }
        }
    }
    if (options.temporaryRoot != "" && options.outputRoot != "" &&
        ckbCompositionStagePathsOverlap(options.temporaryRoot,
            options.outputRoot)) {
        return "composition_stage_roots_overlap"
    }
    "ok"
}

private func ckbCompositionStageParseLocalRoot(value: String):
    (String, CkbPortableLocalRoot) {
    let out = CkbPortableLocalRoot()
    let parts = value.split("|")
    if (parts.size != 3 || parts[0] == "" || parts[1] == "" ||
        !ckbCompositionStageCanonicalExistingDirectory(parts[2])) {
        return ("composition_stage_local_root_invalid", out)
    }
    out.sourceId = parts[0]; out.kind = parts[1]; out.localRoot = parts[2]
    ("ok", out)
}

private func ckbCompositionStageLocalRootMap(
    options: CkbReproCompositionStageOptions):
    (CkbReproContractResult, CkbPortableLocalRootMap) {
    let out = CkbPortableLocalRootMap()
    out.schemaVersion = "ckb-portable-local-root-map-v1"
    let rows = ArrayList<String>()
    for (root in options.localRoots) {
        rows.add("${root.sourceId}|${root.kind}|${root.localRoot}")
    }
    let ordered = rows.toArray(); sort(ordered)
    let allowed = ArrayList<String>()
    for (row in ordered) {
        let parsed = ckbCompositionStageParseLocalRoot(row)
        if (parsed[0] != "ok") {
            return (ckbCompositionStageContractFailure(parsed[0]),
                CkbPortableLocalRootMap())
        }
        out.roots.add(parsed[1]); allowed.add(parsed[1].sourceId)
    }
    let validation = validateCkbPortableLocalRootMap(out, allowed.toArray())
    if (!validation.ok) {
        return (validation, CkbPortableLocalRootMap())
    }
    let parsed = parseCkbPortableLocalRootMap(
        renderCkbReproCliLocalRootMap(out).toArray())
    if (!parsed[0].ok) { return parsed }
    parsed
}

public func runCkbReproCompositionStageCli(args: Array<String>):
    CkbReproCompositionStageExecution {
    runCkbReproCompositionStageCliWithProbe(args,
        CkbReproProductionCompositionRuntimeProbe())
}

public func runCkbReproCompositionStageCliWithProbe(args: Array<String>,
    probe: CkbReproCompositionRuntimeProbe):
    CkbReproCompositionStageExecution {
    let options = parseCkbReproCompositionStageOptions(args)
    if (options.diagnostic != "ok") {
        return ckbCompositionStageFailure(options.diagnostic, options.json, 2)
    }
    var rootIdentity = ""
    try {
        Directory.create(Path(options.root), recursive: false)
        let canonicalRoot = canonicalize(Path(options.root)).toString()
        if (canonicalRoot != options.root) {
            ckbCompositionStageCleanupFreshRoot(options.root)
            return ckbCompositionStageFailure("composition_stage_root_invalid",
                options.json, 1)
        }
        rootIdentity = ckbReproDirectoryOwnershipIdentity(canonicalRoot)
        if (rootIdentity == "") {
            ckbCompositionStageCleanupFreshRoot(options.root)
            return ckbCompositionStageFailure("composition_stage_root_invalid",
                options.json, 1)
        }
        let publication = ckbCompositionStagePreparePublication(canonicalRoot,
            rootIdentity)
        if (publication[0] != "ok") {
            return ckbCompositionStageOwnedFailure(options, rootIdentity,
                publication[0], 1)
        }
        if (!options.prepareOnly) {
            let auxiliary = ckbCompositionStageEnvironment(options,
                publication[1])
            if (auxiliary != "ok") {
                return ckbCompositionStageOwnedFailure(options, rootIdentity,
                    auxiliary, 1)
            }
        }
        let generated = ckbCompositionStageGenerated(options, publication[1],
            probe)
        if (generated != "ok") {
            return ckbCompositionStageOwnedFailure(options, rootIdentity,
                generated, 1)
        }
        for (role in ckbReproCliCompositionRoles(options.mode)) {
            if (ckbCompositionStageGeneratedRole(role, options.mode)) { continue }
            let input = ckbCompositionStageFindInput(options, role)
            if (input == "") {
                return ckbCompositionStageOwnedFailure(options, rootIdentity,
                    "composition_stage_input_missing:${role}", 1)
            }
            let read = ckbReproReadSingleFileNoFollow(input, 536870912)
            if (!read[0] || !ckbCompositionStageValidateRole(role,
                    read[1], options)) {
                return ckbCompositionStageOwnedFailure(options, rootIdentity,
                    "composition_stage_input_contract_invalid:${role}", 1)
            }
            let published = ckbCompositionStagePublish(publication[1],
                ckbReproCliCompositionRoleRelativePath(role), read[1])
            if (published != "ok") {
                return ckbCompositionStageOwnedFailure(options, rootIdentity,
                    published, 1)
            }
        }
        let sealArgs = ArrayList<String>()
        sealArgs.add("ckb-repro-composition-seal")
        sealArgs.add("--root"); sealArgs.add(canonicalRoot)
        sealArgs.add("--mode"); sealArgs.add(options.mode)
        if (options.prepareOnly) { sealArgs.add("--prepare-only") }
        if (options.json) { sealArgs.add("--json") }
        for (role in ckbReproCliCompositionRoles(options.mode)) {
            sealArgs.add("--asset")
            sealArgs.add("${role}=${ckbReproCliCompositionRoleRelativePath(role)}")
        }
        let sealed = runCkbReproCompositionSealCli(sealArgs.toArray())
        if (!sealed.ok) {
            return ckbCompositionStageOwnedFailure(options, rootIdentity,
                sealed.diagnostic, 1)
        }
        let out = CkbReproCompositionStageExecution()
        out.ok = true; out.exitCode = 0; out.diagnostic = "ok"
        out.output = if (options.json) {
            "{\"ok\":true,\"diagnostic\":\"ok\",\"mode\":\"${options.mode}\"," +
                "\"providerCalls\":0,\"modelCalls\":0,\"runnerCalls\":0}"
        } else {
            "CKB reproduction composition staged. mode=${options.mode} " +
                "providerCalls=0 modelCalls=0 runnerCalls=0\n"
        }
        out
    } catch (_: Exception) {
        if (rootIdentity != "" &&
            ckbReproDirectoryOwnershipIdentity(options.root) == rootIdentity) {
            try { remove(Path(options.root), recursive: true) }
            catch (_: Exception) {}
        }
        ckbCompositionStageFailure("composition_stage_failed", options.json, 1)
    }
}

private func ckbCompositionStageCleanupFreshRoot(path: String): Unit {
    if (!exists(Path(path))) { return }
    let parent = Path(path).parent
    try {
        if (canonicalize(parent).toString() == parent.toString() &&
            parent.join(Path(path).fileName).toString() == path) {
            remove(Path(path), recursive: true)
        }
    } catch (_: Exception) {}
}

private func ckbCompositionStagePreparePublication(root: String,
    rootIdentity: String): (String, CkbReproCompositionPublication) {
    let out = CkbReproCompositionPublication()
    out.root = root; out.rootIdentity = rootIdentity
    try {
        let assets = Path(root).join("assets")
        let privateRoot = Path(root).join("private-authority")
        let publicRoot = Path(root).join("public-build-inputs")
        let reproducibility = Path(root).join("reproducibility")
        let manifests = reproducibility.join("manifests")
        for (path in [assets, privateRoot, publicRoot, reproducibility]) {
            Directory.create(path, recursive: false)
        }
        Directory.create(manifests, recursive: false)
        out.assetsIdentity = ckbReproDirectoryOwnershipIdentity(
            assets.toString())
        out.privateIdentity = ckbReproDirectoryOwnershipIdentity(
            privateRoot.toString())
        out.publicIdentity = ckbReproDirectoryOwnershipIdentity(
            publicRoot.toString())
        out.reproducibilityIdentity = ckbReproDirectoryOwnershipIdentity(
            reproducibility.toString())
        out.manifestsIdentity = ckbReproDirectoryOwnershipIdentity(
            manifests.toString())
        if (!ckbCompositionStagePublicationValid(out,
                "assets/runtime_config.json") ||
            !ckbCompositionStagePublicationValid(out,
                "private-authority/eval-support.json") ||
            !ckbCompositionStagePublicationValid(out,
                "public-build-inputs/source-lock.json") ||
            !ckbCompositionStagePublicationValid(out,
                "reproducibility/manifests/environment-plan.json")) {
            return ("composition_stage_directory_identity_invalid", out)
        }
        ("ok", out)
    } catch (_: Exception) {
        ("composition_stage_directory_prepare_failed", out)
    }
}

private func ckbCompositionStagePublicationValid(
    publication: CkbReproCompositionPublication,
    relativePath: String): Bool {
    if (ckbReproDirectoryOwnershipIdentity(publication.root) !=
            publication.rootIdentity ||
        !validateCkbReproBundleRelativePath(relativePath).ok) {
        return false
    }
    let target = Path(publication.root).join(relativePath)
    let parent = target.parent
    let expected = if (relativePath.startsWith("assets/")) {
        publication.assetsIdentity
    } else if (relativePath.startsWith("private-authority/")) {
        publication.privateIdentity
    } else if (relativePath.startsWith("public-build-inputs/")) {
        publication.publicIdentity
    } else if (relativePath.startsWith("reproducibility/manifests/")) {
        publication.manifestsIdentity
    } else { "" }
    if (expected == "" ||
        ckbReproDirectoryOwnershipIdentity(parent.toString()) != expected) {
        return false
    }
    try {
        canonicalize(Path(publication.root)).toString() == publication.root &&
            canonicalize(parent).toString() == parent.toString() &&
            parent.toString().startsWith("${publication.root}/")
    } catch (_: Exception) { false }
}

private func ckbCompositionStageExpectedParentIdentity(
    publication: CkbReproCompositionPublication,
    relativePath: String): String {
    if (relativePath.startsWith("assets/")) {
        return publication.assetsIdentity
    }
    if (relativePath.startsWith("private-authority/")) {
        return publication.privateIdentity
    }
    if (relativePath.startsWith("public-build-inputs/")) {
        return publication.publicIdentity
    }
    if (relativePath.startsWith("reproducibility/manifests/")) {
        return publication.manifestsIdentity
    }
    ""
}

private func ckbCompositionStageExpectedGrandparentIdentity(
    publication: CkbReproCompositionPublication,
    relativePath: String): String {
    if (relativePath.startsWith("reproducibility/manifests/")) {
        return publication.reproducibilityIdentity
    }
    publication.rootIdentity
}

private func ckbCompositionStageGenerated(options: CkbReproCompositionStageOptions,
    publication: CkbReproCompositionPublication,
    probe: CkbReproCompositionRuntimeProbe): String {
    if (options.mode != "p4-build" && options.mode != "run-certify") {
        return "ok"
    }
    let loaded = loadVersionedEvalSupportAuthority(
        FileKnowledgeStore(options.authorityStore))
    let leakage = ckbLoadBenchmarkLeakageAuthority(
        FileKnowledgeStore(options.authorityStore))
    if (!loaded.ok || !leakage.ok ||
        loaded.snapshot.recordCount != leakage.authorityRecordCount ||
        loaded.snapshot.authorityHash != leakage.authorityHash) {
        return "composition_stage_authority_drift"
    }
    let evalText = renderCkbReproCliEvalSupport(loaded.snapshot)
    let leakageText = renderCkbReproCliLeakageAuthority(leakage.authority)
    if (!parseCkbReproCliEvalSupportBytes(evalText.toArray())[0].ok ||
        !parseCkbReproCliLeakageAuthorityBytes(leakageText.toArray())[0].ok) {
        return "composition_stage_authority_export_invalid"
    }
    let policy = ckbCompositionStageReadInput(options, "path_policy")
    let rootsBuilt = ckbCompositionStageLocalRootMap(options)
    let roots = if (rootsBuilt[0].ok) {
        (true, renderCkbReproCliLocalRootMap(rootsBuilt[1]).toArray())
    } else { (false, Array<UInt8>()) }
    let routes = ckbCompositionStageReadInput(options, "api_routes")
    if (!policy[0] || !roots[0] || !routes[0]) {
        return "composition_stage_path_input_missing"
    }
    let path = buildAndRenderCkbReproCliPathContext(policy[1], roots[1],
        routes[1], options.worktreeRoot, options.productionStoreRoot,
        options.userConfigRoot)
    if (!path[0].ok) { return path[0].diagnostic }
    let pathAsset = parseCkbReproCliPathContextBytes(policy[1], roots[1],
        routes[1], path[1].toArray())
    if (!pathAsset[0].ok) { return pathAsset[0].diagnostic }
    let privateBuild = composeCkbReproCliPrivateBuildAuthority(
        loaded.snapshot, leakage.authority, pathAsset[1],
        options.temporaryRoot, options.outputRoot)
    if (!privateBuild[0].ok) { return privateBuild[0].diagnostic }
    let buildContractRead = ckbReproReadSingleFileNoFollow(
        Path(options.publicInputRoot).join("build-contract.json").toString(),
        64 * 1024)
    if (!buildContractRead[0]) { return "composition_stage_build_contract_invalid" }
    let buildContract = parseCkbReproBuildContract(buildContractRead[1])
    if (!buildContract[0].ok ||
        buildContract[1].privateAuthorityIdentityHash !=
            ckbReproPrivateBuildAuthorityIdentity(privateBuild[1])) {
        return "build_private_authority_identity_mismatch"
    }
    let authority = CkbReproCliPrivateAuthority()
    authority.schemaVersion = "ckb-repro-private-cli-authority-v1"
    authority.localRootMap = "private-authority/local-roots.json"
    authority.pathContext = "private-authority/path-context.json"
    authority.evalSupport = "private-authority/eval-support.json"
    authority.leakageAuthority = "private-authority/leakage.json"
    let authorityText = renderCkbReproCliPrivateAuthority(authority,
        options.mode)
    if (!parseCkbReproCliPrivateAuthority(authorityText.toArray(),
            options.mode)[0].ok) {
        return "composition_stage_private_authority_invalid"
    }
    for (entry in [
        ("local_root_map", roots[1]), ("path_context", path[1].toArray()),
        ("eval_support", evalText.toArray()),
        ("leakage_authority", leakageText.toArray()),
        ("private_build_authority", authorityText.toArray())]) {
        let diagnostic = ckbCompositionStagePublish(publication,
            ckbReproCliCompositionRoleRelativePath(entry[0]), entry[1])
        if (diagnostic != "ok") { return diagnostic }
    }
    if (options.mode == "p4-build" || options.mode == "run-certify") {
        let publicResult = ckbCompositionStagePublicInputs(options, publication)
        if (publicResult != "ok") { return publicResult }
    }
    if (options.mode == "run-certify") {
        let runAssets = ckbCompositionStageRunCertifyAssets(options, publication,
            probe)
        if (runAssets != "ok") { return runAssets }
    }
    "ok"
}

private func ckbCompositionStagePublicInputs(
    options: CkbReproCompositionStageOptions,
    publication: CkbReproCompositionPublication): String {
    let manifestInput = ckbCompositionStageFindInput(options,
        "public_build_input_manifest")
    if (manifestInput == "") { return "composition_stage_public_manifest_missing" }
    let manifestRead = ckbReproReadSingleFileNoFollow(manifestInput, 64 * 1024)
    if (!manifestRead[0]) { return "composition_stage_public_manifest_invalid" }
    let parsed = parseCkbReproBuildInputManifest(manifestRead[1])
    if (!parsed[0].ok || parsed[1].assets.size != 7) {
        return "composition_stage_public_manifest_invalid"
    }
    let backend = CkbReproFilesystemBundleReadBackend()
    if (!backend.rootExists(options.publicInputRoot) ||
        backend.list(options.publicInputRoot).size != 7) {
        return "composition_stage_public_inputs_invalid"
    }
    for (asset in parsed[1].assets) {
        let captured = ckbCaptureBuildInputAsset(options.publicInputRoot,
            asset, backend)
        if (!captured.contract.ok) { return captured.contract.diagnostic }
        let published = ckbCompositionStagePublish(publication,
            "public-build-inputs/${asset.relativePath}", captured.bytes)
        if (published != "ok") { return published }
    }
    ckbCompositionStagePublish(publication,
        ckbReproCliCompositionRoleRelativePath("public_build_input_manifest"),
        manifestRead[1])
}

private func ckbCompositionStageRunCertifyOptionsValid(
    options: CkbReproCompositionStageOptions): Bool {
    for (directory in [options.runsRoot, options.datasetRoot, options.docsRoot]) {
        if (!ckbCompositionStageCanonicalExistingDirectory(directory)) {
            return false
        }
    }
    for (file in [options.ckbExecutable, options.dockerExecutable,
        options.authorityManifestPath, options.ckbConfig,
        options.claudeExecutable, options.providerIdentityArtifactPath,
        options.frozenCandidateManifestPath, options.referenceSource]) {
        if (!ckbCompositionStageCanonicalExistingFile(file)) { return false }
    }
    if (!ckbCompositionStageCanonicalExistingDirectory(options.ckbStore) ||
        options.runId == "" || options.candidateVersion == "" ||
        options.knowledgeVersion == "" ||
        !options.providerIdentityHash.startsWith("sha256:") ||
        options.ckbHttpBase == "" || options.qdrantEndpoint == "" ||
        options.restEndpoint == "" || options.mcpHttpEndpoint == "" ||
        options.qdrantImageReference == "" ||
        options.runtimeTimeoutMillis < 100 ||
        options.runtimeTimeoutMillis > 300000) {
        return false
    }
    for (output in [options.observedEnvironmentPath,
        options.certificationPreflightPath,
        options.certificationRunManifestPath]) {
        if (!ckbCompositionStageCanonicalExistingFile(output)) { return false }
    }
    let runnerAuthority = buildCkbReproCliRunnerAuthority(
        options.credentialEnvironmentVariables.toArray())
    runnerAuthority[0].ok
}

private func ckbCompositionStageRunCertifyAssets(
    options: CkbReproCompositionStageOptions,
    publication: CkbReproCompositionPublication,
    probe: CkbReproCompositionRuntimeProbe): String {
    let planRead = ckbReproReadSingleFileNoFollow(options.environmentPlan,
        128 * 1024)
    if (!planRead[0]) { return "composition_stage_environment_invalid" }
    let environment = parseCkbReproEnvironmentLock(planRead[1])
    if (!environment[0].ok) { return environment[0].diagnostic }
    let identity = ckbCompositionStageCrossAssetIdentity(options)
    if (!identity.ok) { return identity.diagnostic }
    let runtime = probeAndRenderCkbReproRuntimeAssets(
        options.ckbExecutable, options.dockerExecutable,
        options.qdrantEndpoint, options.restEndpoint,
        options.mcpHttpEndpoint, options.qdrantImageReference,
        options.runtimeTimeoutMillis, environment[1], probe)
    if (!runtime.contract.ok) { return runtime.contract.diagnostic }
    let runner = ckbCompositionStageBuildRunnerInputs(options)
    let runnerText = renderCkbReproCliRunnerInputs(runner)
    let runnerParsed = parseCkbReproCliRunnerInputsBytes(
        runnerText.toArray(), "run-certify")
    if (!runnerParsed[0].ok ||
        !ckbCompositionStageRunnerEntitiesValid(runnerParsed[1])) {
        return if (!runnerParsed[0].ok) { runnerParsed[0].diagnostic }
            else { "runner_inputs_entity_invalid" }
    }
    let sealed = ckbCompositionStageValidateRunnerEvidence(options)
    if (sealed != "ok") { return sealed }
    let authority = buildCkbReproCliRunnerAuthority(
        options.credentialEnvironmentVariables.toArray())
    if (!authority[0].ok) { return authority[0].diagnostic }
    let reference = ckbCompositionStageReference(options, environment[1])
    if (!reference[0].ok) { return reference[0].diagnostic }
    for (entry in [
        ("runtime_transport",
            renderCkbP8OwnedLocalRuntimeAuthority(runtime.runtime).toArray()),
        ("mcp_stdio_command", renderCkbMcpStdioCommandSpec(runtime.mcp).toArray()),
        ("runner_inputs", runnerText.toArray()),
        ("runner_authority",
            renderCkbReproCliRunnerAuthority(authority[1]).toArray()),
        ("reference_template", reference[0].canonicalJson.toArray())]) {
        let diagnostic = ckbCompositionStagePublish(publication,
            ckbReproCliCompositionRoleRelativePath(entry[0]), entry[1])
        if (diagnostic != "ok") { return diagnostic }
    }
    "ok"
}

private func ckbCompositionStageBuildRunnerInputs(
    options: CkbReproCompositionStageOptions): CkbReproRunnerInputs {
    let out = CkbReproRunnerInputs()
    out.runId = options.runId; out.repoRoot = options.worktreeRoot
    out.runsRoot = options.runsRoot; out.datasetRoot = options.datasetRoot
    out.authorityManifestPath = options.authorityManifestPath
    out.ckbBin = options.ckbExecutable; out.ckbConfig = options.ckbConfig
    out.ckbStore = options.ckbStore; out.ckbHttpBase = options.ckbHttpBase
    out.claudeBin = options.claudeExecutable; out.docsRoot = options.docsRoot
    out.candidateVersion = options.candidateVersion
    out.knowledgeVersion = options.knowledgeVersion
    out.providerIdentityHash = options.providerIdentityHash
    out.providerIdentityArtifactPath = options.providerIdentityArtifactPath
    out.frozenCandidateManifestPath = options.frozenCandidateManifestPath
    out.observedEnvironmentPath = options.observedEnvironmentPath
    out.certificationPreflightPath = options.certificationPreflightPath
    out.certificationRunManifestPath = options.certificationRunManifestPath
    out
}

private func ckbCompositionStageValidateRunnerEvidence(
    options: CkbReproCompositionStageOptions): String {
    let observed = ckbReproReadSingleFileNoFollow(
        options.observedEnvironmentPath, 128 * 1024)
    let preflight = ckbReproReadSingleFileNoFollow(
        options.certificationPreflightPath, 512 * 1024)
    let manifest = ckbReproReadSingleFileNoFollow(
        options.certificationRunManifestPath, 512 * 1024)
    if (!observed[0] || !preflight[0] || !manifest[0]) {
        return "runner_evidence_invalid"
    }
    let observedParsed = parseCkbReproEnvironmentLock(observed[1])
    if (!observedParsed[0].ok ||
        !validateCkbReproEnvironmentLock(observedParsed[1],
            mode: "execution").ok) {
        return "observed_environment_invalid"
    }
    let preflightText = try { String.fromUtf8(preflight[1]) }
        catch (_: Exception) { return "invalid_response_encoding" }
    let manifestText = try { String.fromUtf8(manifest[1]) }
        catch (_: Exception) { return "invalid_response_encoding" }
    ckbCertificationPreflightSealDiagnostic(preflightText, manifestText)
}

private func ckbCompositionStageReference(
    options: CkbReproCompositionStageOptions,
    environment: CkbReproEnvironmentLock):
    (CkbReproContractResult, CkbReproReferenceManifest) {
    let sourceRead = ckbReproReadSingleFileNoFollow(options.referenceSource,
        128 * 1024)
    let qdrantRead = ckbCompositionStageReadInput(options, "qdrant_manifest")
    let logicalRead = ckbCompositionStageReadInput(options, "logical_manifest")
    let buildRead = ckbCompositionStageReadInput(options, "build_proof")
    let criticalRead = ckbCompositionStageReadInput(options,
        "run_critical_manifest")
    let providerRead = ckbReproReadSingleFileNoFollow(
        options.providerIdentityArtifactPath, 128 * 1024)
    if (!sourceRead[0] || !qdrantRead[0] || !logicalRead[0] || !buildRead[0] ||
        !criticalRead[0] || !providerRead[0]) {
        return (ckbCompositionStageContractFailure(
            "reference_template_input_invalid"), CkbReproReferenceManifest())
    }
    let source = parseCkbReproReferenceManifest(sourceRead[1])
    let qdrant = parseCkbQdrantSnapshotManifest(qdrantRead[1])
    let logical = parseCkbLogicalSnapshotManifest(logicalRead[1])
    let build = parseCkbReproBuildProof(buildRead[1])
    let critical = parseCkbRunCriticalFilesManifest(criticalRead[1])
    if (!source[0].ok ||
        !validateCkbReproReferenceManifest(source[1], mode: "execution").ok ||
        !qdrant[0].ok || !logical[0].ok || !build[0].ok || !critical[0].ok ||
        ckbReproBundleHash(providerRead[1]) != options.providerIdentityHash ||
        logical[1].portableKnowledgeVersion != options.knowledgeVersion ||
        build[1].candidateVersion != options.candidateVersion) {
        return (ckbCompositionStageContractFailure(
            "reference_template_identity_mismatch"),
            CkbReproReferenceManifest())
    }
    let out = source[1]
    out.knowledgeVersion = options.knowledgeVersion
    out.vectorProofHash = qdrant[1].vectorProofHash
    out.datasetVersion = environment.datasetVersion
    out.runnerCommit = environment.runCandidateCommit
    out.claudeCodeVersion = environment.claudeCodeVersion
    out.model = environment.glmModel
    out.modelFingerprint = environment.modelFingerprint
    out.providerFingerprint = options.providerIdentityHash
    out.experimentGroup = environment.experimentGroup
    out.mcpTransport = environment.mcpTransport
    out.ckbRequired = environment.ckbRequired
    out.localDocsPolicy = environment.localDocsPolicy
    out.modelEffort = environment.modelEffort
    out.modelBudget = environment.modelBudget
    out.timeoutSeconds = environment.timeoutSeconds
    out.transportRetryBudget = environment.transportRetryBudget
    out.promptHash = environment.promptHash
    out.runCriticalTreeHash = computeCkbRunCriticalTreeHash(critical[1],
        options.worktreeRoot)
    let validation = validateCkbReproReferenceManifest(out,
        mode: "execution")
    if (!validation.ok) {
        return (validation, CkbReproReferenceManifest())
    }
    (validation, out)
}

public func validateCkbReproCompositionStageIdentity(
    logical: CkbLogicalSnapshotManifest, qdrant: CkbQdrantSnapshotManifest,
    parity: CkbRetrievalParityManifest,
    build: CkbReproBuildProof): CkbReproContractResult {
    if (qdrant.logicalManifestHash != logical.manifestHash ||
        qdrant.vectorProofHash != logical.p3VectorProofHash ||
        qdrant.collection != logical.vectorCollection ||
        qdrant.points != logical.vectorCount ||
        qdrant.dimension != logical.vectorDimension ||
        build.candidateVersion != logical.portableKnowledgeVersion ||
        parity.logicalManifestHash != logical.manifestHash ||
        parity.knowledgeVersion != logical.portableKnowledgeVersion) {
        return ckbCompositionStageContractFailure(
            "composition_stage_cross_asset_identity_mismatch")
    }
    ckbCompositionStageContractSuccess()
}

private func ckbCompositionStageCrossAssetIdentity(
    options: CkbReproCompositionStageOptions): CkbReproContractResult {
    let logicalRead = ckbCompositionStageReadInput(options, "logical_manifest")
    let qdrantRead = ckbCompositionStageReadInput(options, "qdrant_manifest")
    let parityRead = ckbCompositionStageReadInput(options, "parity_manifest")
    let buildRead = ckbCompositionStageReadInput(options, "build_proof")
    if (!logicalRead[0] || !qdrantRead[0] || !parityRead[0] ||
        !buildRead[0]) {
        return ckbCompositionStageContractFailure(
            "composition_stage_cross_asset_input_invalid")
    }
    let logical = parseCkbLogicalSnapshotManifest(logicalRead[1])
    let qdrant = parseCkbQdrantSnapshotManifest(qdrantRead[1])
    let parity = parseCkbRetrievalParityManifest(parityRead[1])
    let build = parseCkbReproBuildProof(buildRead[1])
    if (!logical[0].ok || !qdrant[0].ok || !parity[0].ok || !build[0].ok) {
        return ckbCompositionStageContractFailure(
            "composition_stage_cross_asset_input_invalid")
    }
    validateCkbReproCompositionStageIdentity(logical[1], qdrant[1],
        parity[1], build[1])
}

private func ckbCompositionStageContractFailure(
    diagnostic: String): CkbReproContractResult {
    let out = CkbReproContractResult()
    out.diagnostic = diagnostic
    out
}

private func ckbCompositionStageContractSuccess(): CkbReproContractResult {
    let out = CkbReproContractResult()
    out.ok = true; out.diagnostic = "ok"
    out
}

private func ckbCompositionStageEnvironment(
    options: CkbReproCompositionStageOptions,
    publication: CkbReproCompositionPublication): String {
    let plan = ckbReproReadSingleFileNoFollow(options.environmentPlan,
        128 * 1024)
    let authority = ckbReproReadSingleFileNoFollow(
        options.attestationAuthority, 64 * 1024)
    if (!plan[0] || !authority[0]) { return "composition_stage_environment_invalid" }
    let parsed = parseCkbReproEnvironmentLock(plan[1])
    if (!parsed[0].ok || parsed[1].identityStatus != "planned" ||
        parsed[1].attestationAuthorityManifestPath !=
            "reproducibility/manifests/environment-attestation-authority.json" ||
        !loadCkbReproVerifiedAttestationAuthority(authority[1],
            parsed[1].attestationAuthorityHash)[0].ok) {
        return "composition_stage_environment_invalid"
    }
    var diagnostic = ckbCompositionStagePublish(publication,
        "reproducibility/manifests/environment-plan.json", plan[1])
    if (diagnostic != "ok") { return diagnostic }
    diagnostic = ckbCompositionStagePublish(publication,
        parsed[1].attestationAuthorityManifestPath, authority[1])
    diagnostic
}

private func ckbCompositionStagePublish(
    publication: CkbReproCompositionPublication, relativePath: String,
    bytes: Array<UInt8>): String {
    if (!validateCkbReproBundleRelativePath(relativePath).ok || bytes.size < 1) {
        return "composition_stage_publish_invalid"
    }
    if (!ckbCompositionStagePublicationValid(publication, relativePath)) {
        return "composition_stage_root_identity_changed"
    }
    let target = Path(publication.root).join(relativePath)
    try {
        if (exists(target)) { return "composition_stage_target_exists" }
        let descriptor = CkbReproOwnedTempDescriptor()
        let token = ckbReproBundleHash(bytes).replace("sha256:", "")
        descriptor.acquireBound(target.parent.toString(),
            ".${target.fileName}.stage-${token}", target.fileName,
            expectedParentIdentity:
                ckbCompositionStageExpectedParentIdentity(publication,
                    relativePath),
            expectedGrandparentIdentity:
                ckbCompositionStageExpectedGrandparentIdentity(publication,
                    relativePath))
        try {
            if (!descriptor.ok || !descriptor.createPayload(bytes) ||
                !descriptor.publish() || !descriptor.syncAndValidate()) {
                return if (descriptor.diagnostic == "ok") {
                    "composition_stage_publish_failed"
                } else { descriptor.diagnostic }
            }
            let readback = descriptor.readPublicTarget(536870912)
            if (!readback[0] || readback[1] != bytes) {
                return "composition_stage_readback_failed"
            }
            if (!ckbCompositionStagePublicationValid(publication,
                    relativePath)) {
                return "composition_stage_root_identity_changed"
            }
            "ok"
        } finally { _ = descriptor.cleanup() }
    } catch (_: Exception) { "composition_stage_publish_failed" }
}

private func ckbCompositionStageValidateRole(role: String,
    bytes: Array<UInt8>, options: CkbReproCompositionStageOptions): Bool {
    if (role == "runtime_config") {
        return parseCkbReproCliRuntimeConfigBytes(bytes)[0].ok
    }
    if (role == "path_policy") { return parseCkbPortablePathPolicy(bytes)[0].ok }
    if (role == "api_routes") { return parseCkbReproApiRoutes(bytes)[0].ok }
    if (role == "logical_manifest") {
        return parseCkbLogicalSnapshotManifest(bytes)[0].ok
    }
    if (role == "qdrant_manifest") {
        return parseCkbQdrantSnapshotManifest(bytes)[0].ok
    }
    if (role == "parity_manifest") {
        return parseCkbRetrievalParityManifest(bytes)[0].ok
    }
    if (role == "build_proof") { return parseCkbReproBuildProof(bytes)[0].ok }
    if (role == "mcp_stdio_command") {
        return parseCkbMcpStdioCommandSpec(bytes)[0].ok
    }
    if (role == "runner_inputs") {
        let parsed = parseCkbReproCliRunnerInputsBytes(bytes, options.mode)
        return parsed[0].ok && ckbCompositionStageRunnerEntitiesValid(parsed[1])
    }
    if (role == "runner_authority") {
        return parseCkbReproCliRunnerAuthority(bytes, options.mode)[0].ok
    }
    if (role == "reference_template") {
        let parsed = parseCkbReproReferenceManifest(bytes)
        return parsed[0].ok &&
            validateCkbReproReferenceManifest(parsed[1], mode: "execution").ok
    }
    if (role == "authority_manifest") {
        let text = try { String.fromUtf8(bytes) } catch (_: Exception) { return false }
        let authority = parseCangjieHumanEvalAuthorityManifest(text)
        let plan = ckbReproReadSingleFileNoFollow(options.environmentPlan,
            128 * 1024)
        if (!authority.ok || authority.rows.size != 164 || !plan[0]) {
            return false
        }
        let environment = parseCkbReproEnvironmentLock(plan[1])
        environment[0].ok && cangjieHumanEvalAuthorityDatasetDiagnostic(
            authority, environment[1].datasetVersion) == "ok"
    }
    if (role == "run_critical_manifest") {
        let parsed = parseCkbRunCriticalFilesManifest(bytes)
        return parsed[0].ok && validateCkbRunCriticalFilesManifest(parsed[1],
            options.worktreeRoot, mode: "execution").ok
    }
    if (role == "runtime_transport") {
        return parseCkbP8OwnedLocalRuntimeAuthorityBytes(bytes)[0].ok
    }
    if (role == "public_build_input_manifest") {
        return parseCkbReproBuildInputManifest(bytes)[0].ok
    }
    true
}

private func ckbCompositionStageRunnerEntitiesValid(
    runner: CkbReproRunnerInputs): Bool {
    for (directory in [runner.repoRoot, runner.runsRoot, runner.datasetRoot,
        runner.ckbStore, runner.docsRoot]) {
        if (!ckbCompositionStageCanonicalExistingDirectory(directory)) {
            return false
        }
    }
    for (file in [runner.authorityManifestPath, runner.ckbBin,
        runner.ckbConfig, runner.claudeBin, runner.providerIdentityArtifactPath,
        runner.frozenCandidateManifestPath]) {
        if (!ckbCompositionStageCanonicalExistingFile(file)) { return false }
    }
    for (file in [runner.observedEnvironmentPath,
        runner.certificationPreflightPath, runner.certificationRunManifestPath]) {
        if (!ckbCompositionStageCanonicalExistingFile(file)) { return false }
    }
    true
}

private func ckbCompositionStagePathsOverlap(left: String,
    right: String): Bool {
    let a = ckbCompositionStageTrimPath(left)
    let b = ckbCompositionStageTrimPath(right)
    if (a == "" || b == "") { return false }
    a == b || a.startsWith("${b}/") || b.startsWith("${a}/")
}

private func ckbCompositionStageTrimPath(path: String): String {
    var out = path
    while (out.endsWith("/") && out != "/") {
        let runes = out.toRuneArray(); out = String(runes[0..runes.size - 1])
    }
    out
}

private func ckbCompositionStageReadInput(
    options: CkbReproCompositionStageOptions, role: String):
    (Bool, Array<UInt8>) {
    let path = ckbCompositionStageFindInput(options, role)
    if (path == "") { return (false, Array<UInt8>()) }
    ckbReproReadSingleFileNoFollow(path, 536870912)
}

private func ckbCompositionStageFindInput(
    options: CkbReproCompositionStageOptions, role: String): String {
    for (input in options.inputs) {
        if (input.role == role) { return input.path }
    }
    ""
}

private func ckbCompositionStageGeneratedRole(role: String,
    mode: String): Bool {
    if (mode != "p4-build" && mode != "run-certify") { return false }
    role == "public_build_input_manifest" ||
        role == "private_build_authority" || role == "local_root_map" ||
        role == "path_context" || role == "eval_support" ||
        role == "leakage_authority" || (mode == "run-certify" &&
        (role == "runtime_transport" || role == "mcp_stdio_command" ||
        role == "runner_inputs" || role == "runner_authority" ||
        role == "reference_template"))
}

private func ckbCompositionStageTrustedInputRole(role: String,
    mode: String): Bool {
    if (mode == "p4-build" || mode == "run-certify") {
        return role != "private_build_authority" && role != "path_context" &&
            role != "eval_support" && role != "leakage_authority" &&
            role != "local_root_map" &&
            role != "runtime_transport" && role != "mcp_stdio_command" &&
            role != "runner_inputs" && role != "runner_authority" &&
            role != "reference_template"
    }
    true
}

private func ckbCompositionStageModeAllowed(mode: String): Bool {
    mode == "p4-build" || mode == "p3-vector-build" ||
        mode == "p3-snapshot-create" || mode == "p3-snapshot-restore" ||
        mode == "p3-snapshot-verify" || mode == "p3-parity-build" ||
        mode == "run-certify"
}

private func ckbCompositionStageCanonicalExistingFile(path: String): Bool {
    path != "" && Path(path).isAbsolute() &&
        ckbReproReadSingleFileNoFollow(path, 536870912)[0]
}

private func ckbCompositionStageCanonicalExistingDirectory(path: String): Bool {
    if (path == "" || !Path(path).isAbsolute()) { return false }
    try {
        let info = FileInfo(Path(path))
        !info.isSymbolicLink() && info.isDirectory() &&
            canonicalize(Path(path)).toString() == path
    }
    catch (_: Exception) { false }
}

private func ckbCompositionStageCanonicalNewPath(path: String): Bool {
    if (path == "" || !Path(path).isAbsolute() || exists(Path(path))) {
        return false
    }
    let parent = Path(path).parent
    if (parent.toString() == "" || !exists(parent)) { return false }
    try {
        let parentInfo = FileInfo(parent)
        if (parentInfo.isSymbolicLink() || !parentInfo.isDirectory()) {
            return false
        }
        let canonicalParent = canonicalize(parent).toString()
        canonicalParent == parent.toString() &&
            Path(canonicalParent).join(Path(path).fileName).toString() == path
    } catch (_: Exception) { false }
}

private func ckbCompositionStageOptionName(name: String): Bool {
    name == "--root" || name == "--mode" || name == "--authority-store" ||
        name == "--public-input-root" || name == "--environment-plan" ||
        name == "--attestation-authority" || name == "--worktree-root" ||
        name == "--production-store-root" || name == "--user-config-root" ||
        name == "--temporary-root" || name == "--output-root" ||
        name == "--ckb-executable" || name == "--docker-executable" ||
        name == "--qdrant-endpoint" || name == "--rest-endpoint" ||
        name == "--mcp-http-endpoint" || name == "--qdrant-image" ||
        name == "--runtime-timeout-millis" || name == "--run-id" ||
        name == "--runs-root" || name == "--dataset-root" ||
        name == "--authority-manifest" || name == "--ckb-config" ||
        name == "--ckb-store" || name == "--ckb-http-base" ||
        name == "--claude-executable" || name == "--docs-root" ||
        name == "--candidate-version" || name == "--knowledge-version" ||
        name == "--provider-identity-hash" ||
        name == "--provider-identity-artifact" ||
        name == "--frozen-candidate-manifest" ||
        name == "--observed-environment" ||
        name == "--certification-preflight" ||
        name == "--certification-run-manifest" ||
        name == "--reference-source" || name == "--credential-env" ||
        name == "--local-root" ||
        name == "--input"
}

private func ckbCompositionStageSet(options: CkbReproCompositionStageOptions,
    name: String, value: String): Unit {
    if (name == "--root") { options.root = value }
    else if (name == "--mode") { options.mode = value }
    else if (name == "--authority-store") { options.authorityStore = value }
    else if (name == "--public-input-root") { options.publicInputRoot = value }
    else if (name == "--environment-plan") { options.environmentPlan = value }
    else if (name == "--attestation-authority") {
        options.attestationAuthority = value
    } else if (name == "--worktree-root") { options.worktreeRoot = value }
    else if (name == "--production-store-root") {
        options.productionStoreRoot = value
    } else if (name == "--user-config-root") { options.userConfigRoot = value }
    else if (name == "--temporary-root") { options.temporaryRoot = value }
    else if (name == "--output-root") { options.outputRoot = value }
    else if (name == "--ckb-executable") { options.ckbExecutable = value }
    else if (name == "--docker-executable") { options.dockerExecutable = value }
    else if (name == "--qdrant-endpoint") { options.qdrantEndpoint = value }
    else if (name == "--rest-endpoint") { options.restEndpoint = value }
    else if (name == "--mcp-http-endpoint") { options.mcpHttpEndpoint = value }
    else if (name == "--qdrant-image") { options.qdrantImageReference = value }
    else if (name == "--runtime-timeout-millis") {
        options.runtimeTimeoutMillis = try { Int64.parse(value) }
            catch (_: Exception) { -1 }
    } else if (name == "--run-id") { options.runId = value }
    else if (name == "--runs-root") { options.runsRoot = value }
    else if (name == "--dataset-root") { options.datasetRoot = value }
    else if (name == "--authority-manifest") {
        options.authorityManifestPath = value
    } else if (name == "--ckb-config") { options.ckbConfig = value }
    else if (name == "--ckb-store") { options.ckbStore = value }
    else if (name == "--ckb-http-base") { options.ckbHttpBase = value }
    else if (name == "--claude-executable") { options.claudeExecutable = value }
    else if (name == "--docs-root") { options.docsRoot = value }
    else if (name == "--candidate-version") { options.candidateVersion = value }
    else if (name == "--knowledge-version") { options.knowledgeVersion = value }
    else if (name == "--provider-identity-hash") {
        options.providerIdentityHash = value
    } else if (name == "--provider-identity-artifact") {
        options.providerIdentityArtifactPath = value
    } else if (name == "--frozen-candidate-manifest") {
        options.frozenCandidateManifestPath = value
    } else if (name == "--observed-environment") {
        options.observedEnvironmentPath = value
    } else if (name == "--certification-preflight") {
        options.certificationPreflightPath = value
    } else if (name == "--certification-run-manifest") {
        options.certificationRunManifestPath = value
    } else if (name == "--reference-source") { options.referenceSource = value }
}

private func ckbCompositionStageOwnedFailure(
    options: CkbReproCompositionStageOptions, identity: String,
    diagnostic: String, exitCode: Int64): CkbReproCompositionStageExecution {
    if (ckbReproDirectoryOwnershipIdentity(options.root) == identity) {
        try { remove(Path(options.root), recursive: true) }
        catch (_: Exception) {}
    }
    ckbCompositionStageFailure(diagnostic, options.json, exitCode)
}

private func ckbCompositionStageFailure(diagnostic: String, json: Bool,
    exitCode: Int64): CkbReproCompositionStageExecution {
    let out = CkbReproCompositionStageExecution()
    out.diagnostic = utf8SafePrefix(redactSensitive(diagnostic), 160)
    out.exitCode = exitCode
    out.output = if (json) {
        "{\"ok\":false,\"diagnostic\":\"${out.diagnostic}\"," +
            "\"providerCalls\":0,\"modelCalls\":0,\"runnerCalls\":0}"
    } else {
        "CKB reproduction composition stage failed: ${out.diagnostic}\n"
    }
    out
}
