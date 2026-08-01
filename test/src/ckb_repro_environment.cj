package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.env.getVariable
import std.fs.{File, Path, canonicalize, exists}
import std.io.{InputStream, StringReader}
import std.process.{ProcessRedirect, launch}
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

public class CkbReproEnvironmentLock {
    public var schemaVersion: String = ""
    public var identityStatus: String = ""
    public var certifiedPlatform: String = ""
    public var cpuArchitecture: String = ""
    public var cangjieSdkVersion: String = ""
    public var cangjieSdkHash: String = ""
    public var opensslVersion: String = ""
    public var serviceHeap: String = ""
    public var qdrantImageDigest: String = ""
    public var runCandidateCommit: String = ""
    public var runCriticalFilesManifestHash: String = ""
    public var runCriticalTreeHash: String = ""
    public var claudeCodeVersion: String = ""
    public var glmProvider: String = ""
    public var glmBaseUrl: String = ""
    public var glmModel: String = ""
    public var glmCredentialEnv: String = ""
    public var embeddingProvider: String = ""
    public var embeddingModel: String = ""
    public var embeddingDimension: Int64 = 0
    public var embeddingCredentialEnv: String = ""
    public var archiveTool: String = ""
    public var archiveToolVersion: String = ""
    public var experimentGroup: String = ""
    public var ckbRequired: Bool = false
    public var localDocsPolicy: String = ""
    public var modelEffort: String = ""
    public var modelBudget: String = ""
    public var timeoutSeconds: Int64 = 0
    public var transportRetryBudget: Int64 = 0
    public var promptHash: String = ""
    public var mcpCommand: String = ""
    public var mcpTransport: String = ""
    public var sandboxCapability: String = ""
    public var datasetVersion: String = ""
    public var authorityDeliveryHash: String = ""
    public init() {}
}

public class CkbReproEnvironmentPreflightResult {
    public var ok: Bool = false
    public var startAllowed: Bool = false
    public var diagnostic: String = "not_validated"
    public var environmentManifestHash: String = ""
    public var certifiedRunInputHash: String = ""
    public var heapResult: CkbServiceHeapPreflightResult = CkbServiceHeapPreflightResult()
    public init() {}
}

// P3/P4 inject these portable identities after their contracts are complete.
// This type deliberately has no defaults that point at a developer machine.
public class CkbReproRunnerInputs {
    public var runId: String = ""
    public var repoRoot: String = ""
    public var runsRoot: String = ""
    public var datasetRoot: String = ""
    public var authorityManifestPath: String = ""
    public var ckbBin: String = ""
    public var ckbConfig: String = ""
    public var ckbStore: String = ""
    public var ckbHttpBase: String = ""
    public var claudeBin: String = ""
    public var docsRoot: String = ""
    public var candidateVersion: String = ""
    public var knowledgeVersion: String = ""
    public var providerIdentityHash: String = ""
    public var providerIdentityArtifactPath: String = ""
    public var frozenCandidateManifestPath: String = ""
    public var certificationPreflightPath: String = ""
    public var certificationRunManifestPath: String = ""
    public init() {}
}

public interface CkbReproRunnerInvoker {
    func run(args: Array<String>): Int64
}

public class CkbReproPreflightCliOptions {
    public var environmentLockPath: String = ""
    public var observedEnvironmentPath: String = ""
    public var certificationPreflightPath: String = ""
    public var certificationRunManifestPath: String = ""
    public var json: Bool = false
    public var valid: Bool = false
    public var diagnostic: String = "usage_error"
    public init() {}
}

public class CkbReproPreflightCliInputs {
    public var expected: CkbReproEnvironmentLock = CkbReproEnvironmentLock()
    public var observed: CkbReproEnvironmentLock = CkbReproEnvironmentLock()
    public var heap: CkbServiceHeapPreflightResult = CkbServiceHeapPreflightResult()
    public var certificationPreflightJson: String = ""
    public var certificationRunManifestJson: String = ""
    public init() {}
}

public class CkbReproEnvironmentProbeResult {
    public var ok: Bool = false
    public var diagnostic: String = "environment_probe_unavailable"
    public var observed: CkbReproEnvironmentLock = CkbReproEnvironmentLock()
    public init() {}
}

public interface CkbReproEnvironmentProbe {
    func inspect(attested: CkbReproEnvironmentLock):
        CkbReproEnvironmentProbeResult
}

public class CkbReproAttestationAuthority {
    public var signingFingerprint: String = ""
    public var frozen: Bool = false
    public init() {}
}

public class CkbReproFilesystemEnvironmentProbe <: CkbReproEnvironmentProbe {
    public init() {}
    public func inspect(attested: CkbReproEnvironmentLock):
        CkbReproEnvironmentProbeResult {
        let out = CkbReproEnvironmentProbeResult()
        let copied = parseCkbReproEnvironmentLock(
            renderCkbReproEnvironmentLock(attested).toArray())
        if (!copied[0].ok) { return out }
        let platform = p6ProbeCommand("uname", ["-s"])
        let architecture = p6ProbeCommand("uname", ["-m"])
        let sdk = p6ProbeCommand("cjc", ["--version"])
        let sdkPath = p6ProbeCommand("which", ["cjc"])
        let openssl = p6ProbeCommand("openssl", ["version"])
        let commit = p6ProbeCommand("git", ["rev-parse", "HEAD"])
        let claude = p6ProbeCommand("claude", ["--version"])
        let tar = p6ProbeCommand("tar", ["--version"])
        let zstd = p6ProbeCommand("zstd", ["--version"])
        let qdrant = p6ProbeCommand("docker", ["image", "inspect",
            "--format={{.Id}}", attested.qdrantImageDigest])
        for (probe in [platform, architecture, sdk, sdkPath, openssl, commit,
            claude, tar, zstd, qdrant]) {
            if (probe[0] != 0 || probe[1] == "") { return out }
        }
        let sdkBytes = try { File.readFrom(Path(sdkPath[1])) }
            catch (_: Exception) { return out }
        let observed = copied[1]
        observed.certifiedPlatform = if (platform[1] == "Darwin") {
            "macOS"
        } else { platform[1] }
        observed.cpuArchitecture = architecture[1]
        observed.cangjieSdkVersion = sdk[1]
        observed.cangjieSdkHash = p6Hash(sdkBytes)
        observed.opensslVersion = openssl[1]
        observed.runCandidateCommit = commit[1]
        observed.claudeCodeVersion = claude[1]
        observed.archiveToolVersion = "${tar[1]}|${zstd[1]}"
        observed.qdrantImageDigest = qdrant[1]
        out.ok = true
        out.diagnostic = "ok"
        out.observed = observed
        out
    }
}

public func parseCkbReproPreflightCliArgs(args: Array<String>):
    CkbReproPreflightCliOptions {
    let out = CkbReproPreflightCliOptions()
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "ckb-repro-preflight") { i += 1; continue }
        if (arg == "--json") {
            if (out.json) { out.diagnostic = "duplicate_argument:--json"; return out }
            out.json = true; i += 1; continue
        }
        if (arg == "--environment-lock" || arg == "--observed-environment" ||
            arg == "--certification-preflight" ||
            arg == "--certification-run-manifest") {
            if (i + 1 >= args.size) { out.diagnostic = "missing_value:${arg}"; return out }
            let value = args[i + 1]
            if (!p6CliAbsolutePath(value)) { out.diagnostic = "preflight_path_invalid"; return out }
            if (arg == "--environment-lock") {
                if (out.environmentLockPath != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.environmentLockPath = value
            } else if (arg == "--observed-environment") {
                if (out.observedEnvironmentPath != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.observedEnvironmentPath = value
            } else if (arg == "--certification-preflight") {
                if (out.certificationPreflightPath != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.certificationPreflightPath = value
            } else {
                if (out.certificationRunManifestPath != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.certificationRunManifestPath = value
            }
            i += 2; continue
        }
        out.diagnostic = "unknown_argument:${arg}"; return out
    }
    if (out.environmentLockPath == "" || out.observedEnvironmentPath == "" ||
        out.certificationPreflightPath == "" ||
        out.certificationRunManifestPath == "") {
        out.diagnostic = "required_argument_missing"; return out
    }
    out.valid = true; out.diagnostic = "ok"; out
}

public func validateCkbReproPreflightCliOptions(
    options: CkbReproPreflightCliOptions): CkbReproContractResult {
    if (!options.valid) { return p6Failure(options.diagnostic) }
    for (path in [options.environmentLockPath, options.observedEnvironmentPath,
        options.certificationPreflightPath,
        options.certificationRunManifestPath]) {
        if (!p6CliAbsolutePath(path)) { return p6Failure("preflight_path_invalid") }
    }
    p6Success()
}

public func executeCkbReproPreflightCliAdapter(
    options: CkbReproPreflightCliOptions,
    inputs: CkbReproPreflightCliInputs): CkbReproEnvironmentPreflightResult {
    let checked = validateCkbReproPreflightCliOptions(options)
    if (!checked.ok) { return p6CliPreflightFailure(checked.diagnostic) }
    runCkbReproEnvironmentPreflight(inputs.expected, inputs.observed, inputs.heap,
        inputs.certificationPreflightJson, inputs.certificationRunManifestJson)
}

public func executeCkbReproPreflightCliAdapterWithProbe(
    options: CkbReproPreflightCliOptions,
    inputs: CkbReproPreflightCliInputs,
    probe: CkbReproEnvironmentProbe): CkbReproEnvironmentPreflightResult {
    let checked = validateCkbReproPreflightCliOptions(options)
    if (!checked.ok) { return p6CliPreflightFailure(checked.diagnostic) }
    let actual = try { probe.inspect(inputs.observed) }
        catch (_: Exception) { return p6CliPreflightFailure(
            "environment_probe_unavailable") }
    if (!actual.ok) { return p6CliPreflightFailure(actual.diagnostic) }
    runCkbReproEnvironmentPreflight(inputs.expected, actual.observed,
        inputs.heap, inputs.certificationPreflightJson,
        inputs.certificationRunManifestJson)
}

public func runCkbReproPreflightCliAdapter(
    options: CkbReproPreflightCliOptions): CkbReproEnvironmentPreflightResult {
    let checked = validateCkbReproPreflightCliOptions(options)
    if (!checked.ok) { return p6CliPreflightFailure(checked.diagnostic) }
    p6CliPreflightFailure("environment_attestation_authority_unavailable")
}

public func runCkbReproPreflightCliAdapter(
    options: CkbReproPreflightCliOptions,
    authority: CkbReproAttestationAuthority):
    CkbReproEnvironmentPreflightResult {
    let checked = validateCkbReproPreflightCliOptions(options)
    if (!checked.ok) { return p6CliPreflightFailure(checked.diagnostic) }
    if (!authority.frozen ||
        !p6ProbeFingerprint(authority.signingFingerprint)) {
        return p6CliPreflightFailure(
            "environment_attestation_authority_unavailable")
    }
    for (item in [
        (options.environmentLockPath, "environment_lock_missing"),
        (options.observedEnvironmentPath, "observed_environment_missing"),
        (options.certificationPreflightPath, "certification_preflight_missing"),
        (options.certificationRunManifestPath, "certification_run_manifest_missing")
    ]) {
        if (!exists(Path(item[0]))) { return p6CliPreflightFailure(item[1]) }
        if (try { canonicalize(Path(item[0])).toString() != item[0] }
            catch (_: Exception) { true }) {
            return p6CliPreflightFailure("preflight_path_not_canonical")
        }
    }
    let expected = p6CliReadEnvironment(options.environmentLockPath)
    if (!expected[0].ok) { return p6CliPreflightFailure(expected[0].diagnostic) }
    let observed = p6CliReadEnvironment(options.observedEnvironmentPath)
    if (!observed[0].ok) { return p6CliPreflightFailure(observed[0].diagnostic) }
    let attestation = p6VerifyObservedEnvironmentAttestation(
        options.observedEnvironmentPath, authority.signingFingerprint)
    if (attestation != "ok") { return p6CliPreflightFailure(attestation) }
    let preflight = p6CliReadUtf8(options.certificationPreflightPath)
    if (preflight[0] != "ok") { return p6CliPreflightFailure(preflight[0]) }
    let manifest = p6CliReadUtf8(options.certificationRunManifestPath)
    if (manifest[0] != "ok") { return p6CliPreflightFailure(manifest[0]) }
    let heapRaw = match (getVariable("cjHeapSize")) {
        case Some(value) => value
        case None => ""
    }
    let inputs = CkbReproPreflightCliInputs()
    inputs.expected = expected[1]
    inputs.observed = observed[1]
    inputs.heap = ckbServiceHeapPreflight(heapRaw)
    inputs.certificationPreflightJson = preflight[1]
    inputs.certificationRunManifestJson = manifest[1]
    executeCkbReproPreflightCliAdapterWithProbe(options, inputs,
        CkbReproFilesystemEnvironmentProbe())
}

public func renderCkbReproPreflightCliHuman(
    result: CkbReproEnvironmentPreflightResult,
    lock: CkbReproEnvironmentLock): String {
    "preflight: ${if (result.ok) { "passed" } else { "blocked" }}\n" +
        "diagnostic: ${p6CliSafeDiagnostic(result.diagnostic)}\n" +
        "platform: ${p6CliPublic(lock.certifiedPlatform)} ${p6CliPublic(lock.cpuArchitecture)}\n" +
        "model: ${p6CliPublic(lock.glmProvider)}/${p6CliPublic(lock.glmModel)}\n" +
        "embedding: ${p6CliPublic(lock.embeddingProvider)}/${p6CliPublic(lock.embeddingModel)}\n" +
        "mcp transport: ${p6CliPublic(lock.mcpTransport)}\n" +
        "environment hash: ${result.environmentManifestHash}\n" +
        "certified input hash: ${result.certifiedRunInputHash}\n"
}

public func renderCkbReproPreflightCliJson(
    result: CkbReproEnvironmentPreflightResult,
    lock: CkbReproEnvironmentLock): String {
    "{\"ok\":${result.ok},\"startAllowed\":${result.startAllowed}," +
        "\"diagnostic\":\"${p6Escape(p6CliSafeDiagnostic(result.diagnostic))}\"," +
        "\"platform\":\"${p6Escape(p6CliPublic(lock.certifiedPlatform))}\"," +
        "\"architecture\":\"${p6Escape(p6CliPublic(lock.cpuArchitecture))}\"," +
        "\"provider\":\"${p6Escape(p6CliPublic(lock.glmProvider))}\"," +
        "\"model\":\"${p6Escape(p6CliPublic(lock.glmModel))}\"," +
        "\"embeddingProvider\":\"${p6Escape(p6CliPublic(lock.embeddingProvider))}\"," +
        "\"embeddingModel\":\"${p6Escape(p6CliPublic(lock.embeddingModel))}\"," +
        "\"mcpTransport\":\"${p6Escape(p6CliPublic(lock.mcpTransport))}\"," +
        "\"environmentManifestHash\":\"${p6Escape(result.environmentManifestHash)}\"," +
        "\"certifiedRunInputHash\":\"${p6Escape(result.certifiedRunInputHash)}\"}"
}

public func parseCkbReproEnvironmentLock(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbReproEnvironmentLock) {
    let lock = CkbReproEnvironmentLock()
    let decoded = p6Decode(bytes)
    if (decoded[0] != "ok") { return (p6Failure(decoded[0]), lock) }
    try {
        let object = JsonValue.fromStr(decoded[1]).asObject()
        if (object.size() != 36) {
            return (p6Failure("environment_field_contract_invalid"), lock)
        }
        lock.schemaVersion = p6String(object, "schemaVersion")
        lock.identityStatus = p6String(object, "identityStatus")
        lock.certifiedPlatform = p6String(object, "certifiedPlatform")
        lock.cpuArchitecture = p6String(object, "cpuArchitecture")
        lock.cangjieSdkVersion = p6String(object, "cangjieSdkVersion")
        lock.cangjieSdkHash = p6String(object, "cangjieSdkHash")
        lock.opensslVersion = p6String(object, "opensslVersion")
        lock.serviceHeap = p6String(object, "serviceHeap")
        lock.qdrantImageDigest = p6String(object, "qdrantImageDigest")
        lock.runCandidateCommit = p6String(object, "runCandidateCommit")
        lock.runCriticalFilesManifestHash = p6String(object, "runCriticalFilesManifestHash")
        lock.runCriticalTreeHash = p6String(object, "runCriticalTreeHash")
        lock.claudeCodeVersion = p6String(object, "claudeCodeVersion")
        lock.glmProvider = p6String(object, "glmProvider")
        lock.glmBaseUrl = p6String(object, "glmBaseUrl")
        lock.glmModel = p6String(object, "glmModel")
        lock.glmCredentialEnv = p6String(object, "glmCredentialEnv")
        lock.embeddingProvider = p6String(object, "embeddingProvider")
        lock.embeddingModel = p6String(object, "embeddingModel")
        lock.embeddingDimension = p6Int(object, "embeddingDimension")
        lock.embeddingCredentialEnv = p6String(object, "embeddingCredentialEnv")
        lock.archiveTool = p6String(object, "archiveTool")
        lock.archiveToolVersion = p6String(object, "archiveToolVersion")
        lock.experimentGroup = p6String(object, "experimentGroup")
        lock.ckbRequired = p6Bool(object, "ckbRequired")
        lock.localDocsPolicy = p6String(object, "localDocsPolicy")
        lock.modelEffort = p6String(object, "modelEffort")
        lock.modelBudget = p6String(object, "modelBudget")
        lock.timeoutSeconds = p6Int(object, "timeoutSeconds")
        lock.transportRetryBudget = p6Int(object, "transportRetryBudget")
        lock.promptHash = p6String(object, "promptHash")
        lock.mcpCommand = p6String(object, "mcpCommand")
        lock.mcpTransport = p6String(object, "mcpTransport")
        lock.sandboxCapability = p6String(object, "sandboxCapability")
        lock.datasetVersion = p6String(object, "datasetVersion")
        lock.authorityDeliveryHash = p6String(object, "authorityDeliveryHash")
    } catch (_: Exception) {
        return (p6Failure("environment_field_contract_invalid"), CkbReproEnvironmentLock())
    }
    (p6Success(), lock)
}

public func validateCkbReproEnvironmentLock(lock: CkbReproEnvironmentLock,
    mode!: String = "contract"):
    CkbReproContractResult {
    if (lock.schemaVersion != "ckb-repro-environment-v1" ||
        (lock.identityStatus != "planned" && lock.identityStatus != "frozen") ||
        (mode != "contract" && mode != "execution")) {
        return p6Failure("environment_schema_invalid")
    }
    if (lock.certifiedPlatform != "macOS" || lock.cpuArchitecture != "arm64") {
        return p6Failure("environment_platform_unsupported")
    }
    if (lock.identityStatus == "frozen") {
        if (lock.cangjieSdkVersion == "" || lock.opensslVersion == "" ||
            lock.claudeCodeVersion == "" || lock.archiveTool == "" ||
            lock.archiveToolVersion == "") {
            return p6Failure("environment_tool_identity_required")
        }
        for (hash in [lock.cangjieSdkHash, lock.runCriticalFilesManifestHash,
            lock.runCriticalTreeHash, lock.promptHash, lock.authorityDeliveryHash]) {
            if (!p6HashValid(hash)) { return p6Failure("environment_hash_invalid") }
        }
        if (!lock.qdrantImageDigest.startsWith("sha256:") ||
            !p6CommitValid(lock.runCandidateCommit)) {
            return p6Failure("environment_runtime_identity_invalid")
        }
    } else if (mode == "execution") {
        return p6Failure("environment_identity_not_frozen")
    }
    if (lock.serviceHeap != "4GB") {
        return p6Failure("environment_heap_contract_invalid")
    }
    if (lock.glmProvider == "" || lock.glmModel != "GLM-5.2" ||
        !p6PublicHttpsUrl(lock.glmBaseUrl) ||
        !p6CredentialEnvName(lock.glmCredentialEnv)) {
        return p6Failure("environment_provider_identity_invalid")
    }
    if (lock.embeddingProvider == "" || lock.embeddingModel == "" ||
        lock.embeddingDimension <= 0 ||
        !p6CredentialEnvName(lock.embeddingCredentialEnv)) {
        return p6Failure("environment_embedding_identity_invalid")
    }
    if (lock.experimentGroup != CkbAbcdeGroups.D || !lock.ckbRequired ||
        lock.localDocsPolicy == "" || lock.modelEffort == "" ||
        lock.modelBudget == "" || lock.timeoutSeconds < 1 ||
        lock.timeoutSeconds > 3600 || lock.transportRetryBudget < 0 ||
        lock.mcpCommand == "" ||
        (lock.mcpTransport != "mcp_stdio" && lock.mcpTransport != "rest" &&
            lock.mcpTransport != "mcp_http") ||
        lock.sandboxCapability != "macos-sandbox-exec" ||
        lock.datasetVersion == "") {
        return p6Failure("environment_experiment_contract_invalid")
    }
    let canonical = renderCkbReproEnvironmentLock(lock)
    if (p6ContainsSecretOrLocalPath(canonical)) {
        return p6Failure("environment_secret_or_local_path_forbidden")
    }
    let result = p6Success()
    result.canonicalJson = canonical
    result.manifestHash = p6Hash(canonical.toArray())
    result.treeHash = p6Hash(renderCkbCertifiedRunInput(lock).toArray())
    result
}

public func runCkbReproEnvironmentPreflight(expected: CkbReproEnvironmentLock,
    observed: CkbReproEnvironmentLock, heap: CkbServiceHeapPreflightResult,
    certificationPreflightJson: String, certificationRunManifestJson: String):
    CkbReproEnvironmentPreflightResult {
    let out = CkbReproEnvironmentPreflightResult()
    out.heapResult = heap
    if (!heap.ok) {
        out.diagnostic = heap.errorCode
        return out
    }
    let expectedValidation = validateCkbReproEnvironmentLock(expected,
        mode: "execution")
    if (!expectedValidation.ok) {
        out.diagnostic = expectedValidation.diagnostic
        return out
    }
    let observedValidation = validateCkbReproEnvironmentLock(observed,
        mode: "execution")
    if (!observedValidation.ok) {
        out.diagnostic = observedValidation.diagnostic
        return out
    }
    if (renderCkbReproEnvironmentLock(expected) !=
        renderCkbReproEnvironmentLock(observed)) {
        out.diagnostic = "environment_identity_drift"
        return out
    }
    let sealDiagnostic = ckbCertificationPreflightSealDiagnostic(
        certificationPreflightJson, certificationRunManifestJson)
    if (sealDiagnostic != "ok") {
        out.diagnostic = sealDiagnostic
        return out
    }
    out.ok = true
    out.startAllowed = true
    out.diagnostic = "ok"
    out.environmentManifestHash = expectedValidation.manifestHash
    out.certifiedRunInputHash = expectedValidation.treeHash
    out
}

public func renderCkbReproEnvironmentLock(lock: CkbReproEnvironmentLock): String {
    "{\"schemaVersion\":\"${p6Escape(lock.schemaVersion)}\"," +
    "\"identityStatus\":\"${p6Escape(lock.identityStatus)}\"," +
    "\"certifiedPlatform\":\"${p6Escape(lock.certifiedPlatform)}\"," +
    "\"cpuArchitecture\":\"${p6Escape(lock.cpuArchitecture)}\"," +
    "\"cangjieSdkVersion\":\"${p6Escape(lock.cangjieSdkVersion)}\"," +
    "\"cangjieSdkHash\":\"${p6Escape(lock.cangjieSdkHash)}\"," +
    "\"opensslVersion\":\"${p6Escape(lock.opensslVersion)}\"," +
    "\"serviceHeap\":\"${p6Escape(lock.serviceHeap)}\"," +
    "\"qdrantImageDigest\":\"${p6Escape(lock.qdrantImageDigest)}\"," +
    "\"runCandidateCommit\":\"${p6Escape(lock.runCandidateCommit)}\"," +
    "\"runCriticalFilesManifestHash\":\"${p6Escape(lock.runCriticalFilesManifestHash)}\"," +
    "\"runCriticalTreeHash\":\"${p6Escape(lock.runCriticalTreeHash)}\"," +
    "\"claudeCodeVersion\":\"${p6Escape(lock.claudeCodeVersion)}\"," +
    "\"glmProvider\":\"${p6Escape(lock.glmProvider)}\"," +
    "\"glmBaseUrl\":\"${p6Escape(lock.glmBaseUrl)}\"," +
    "\"glmModel\":\"${p6Escape(lock.glmModel)}\"," +
    "\"glmCredentialEnv\":\"${p6Escape(lock.glmCredentialEnv)}\"," +
    "\"embeddingProvider\":\"${p6Escape(lock.embeddingProvider)}\"," +
    "\"embeddingModel\":\"${p6Escape(lock.embeddingModel)}\"," +
    "\"embeddingDimension\":${lock.embeddingDimension}," +
    "\"embeddingCredentialEnv\":\"${p6Escape(lock.embeddingCredentialEnv)}\"," +
    "\"archiveTool\":\"${p6Escape(lock.archiveTool)}\"," +
    "\"archiveToolVersion\":\"${p6Escape(lock.archiveToolVersion)}\"," +
    "\"experimentGroup\":\"${p6Escape(lock.experimentGroup)}\"," +
    "\"ckbRequired\":${lock.ckbRequired}," +
    "\"localDocsPolicy\":\"${p6Escape(lock.localDocsPolicy)}\"," +
    "\"modelEffort\":\"${p6Escape(lock.modelEffort)}\"," +
    "\"modelBudget\":\"${p6Escape(lock.modelBudget)}\"," +
    "\"timeoutSeconds\":${lock.timeoutSeconds}," +
    "\"transportRetryBudget\":${lock.transportRetryBudget}," +
    "\"promptHash\":\"${p6Escape(lock.promptHash)}\"," +
    "\"mcpCommand\":\"${p6Escape(lock.mcpCommand)}\"," +
    "\"mcpTransport\":\"${p6Escape(lock.mcpTransport)}\"," +
    "\"sandboxCapability\":\"${p6Escape(lock.sandboxCapability)}\"," +
    "\"datasetVersion\":\"${p6Escape(lock.datasetVersion)}\"," +
    "\"authorityDeliveryHash\":\"${p6Escape(lock.authorityDeliveryHash)}\"}"
}

public func renderCkbProviderTemplate(lock: CkbReproEnvironmentLock): String {
    "GLM_PROVIDER=${lock.glmProvider}\n" +
    "GLM_BASE_URL=${lock.glmBaseUrl}\n" +
    "GLM_MODEL=${lock.glmModel}\n" +
    "GLM_CREDENTIAL_ENV=${lock.glmCredentialEnv}\n" +
    "EMBEDDING_PROVIDER=${lock.embeddingProvider}\n" +
    "EMBEDDING_MODEL=${lock.embeddingModel}\n" +
    "EMBEDDING_DIMENSION=${lock.embeddingDimension}\n" +
    "EMBEDDING_CREDENTIAL_ENV=${lock.embeddingCredentialEnv}\n" +
    "cjHeapSize=${lock.serviceHeap}\n"
}

public func buildCkbReproRunnerArgs(reference: CkbReproReferenceManifest,
    lock: CkbReproEnvironmentLock, inputs: CkbReproRunnerInputs):
    (CkbReproContractResult, Array<String>) {
    let empty = Array<String>()
    if (!validateCkbReproEnvironmentLock(lock).ok ||
        reference.experimentGroup != lock.experimentGroup ||
        reference.datasetVersion != lock.datasetVersion ||
        inputs.runId == "" || inputs.repoRoot == "" || inputs.runsRoot == "" ||
        inputs.datasetRoot == "" || inputs.authorityManifestPath == "" ||
        inputs.ckbBin == "" || inputs.ckbConfig == "" || inputs.ckbStore == "" ||
        inputs.ckbHttpBase == "" || inputs.claudeBin == "" ||
        inputs.docsRoot == "" || inputs.candidateVersion == "" ||
        inputs.knowledgeVersion == "" ||
        !p6HashValid(inputs.providerIdentityHash) ||
        inputs.providerIdentityArtifactPath == "" ||
        inputs.frozenCandidateManifestPath == "" ||
        inputs.certificationPreflightPath == "" ||
        inputs.certificationRunManifestPath == "") {
        return (p6Failure("runner_identity_injection_required"), empty)
    }
    let args = [
        "cangjie-eval-abcde", "--run-mode", "certification",
        "--dataset-version", lock.datasetVersion,
        "--candidate-version", inputs.candidateVersion,
        "--knowledge-version", inputs.knowledgeVersion,
        "--model-fingerprint", "claude-code-${lock.glmModel}",
        "--run-id", inputs.runId, "--repo-root", inputs.repoRoot,
        "--runs-root", inputs.runsRoot, "--dataset-root", inputs.datasetRoot,
        "--manifest", inputs.authorityManifestPath, "--ckb-bin", inputs.ckbBin,
        "--config", inputs.ckbConfig, "--ckb-store", inputs.ckbStore,
        "--ckb-http-base", inputs.ckbHttpBase, "--claude-bin", inputs.claudeBin,
        "--docs-root", inputs.docsRoot, "--case-start", "0", "--case-end", "163",
        "--groups", lock.experimentGroup, "--transport-retries",
        "${lock.transportRetryBudget}", "--model-timeout-seconds",
        "${lock.timeoutSeconds}", "--model-effort", lock.modelEffort,
        "--model-max-budget-usd", lock.modelBudget,
        "--expected-model-version", lock.glmModel,
        "--provider-identity-hash", inputs.providerIdentityHash,
        "--provider-identity-artifact", inputs.providerIdentityArtifactPath,
        "--frozen-candidate-manifest", inputs.frozenCandidateManifestPath,
        "--certification-preflight", inputs.certificationPreflightPath,
        "--certification-run-manifest", inputs.certificationRunManifestPath
    ]
    let result = p6Success()
    result.canonicalJson = p6ArgsIdentity(args)
    result.manifestHash = p6Hash(result.canonicalJson.toArray())
    (result, args)
}

public func runCkbReproCertifiedStudent(reference: CkbReproReferenceManifest,
    lock: CkbReproEnvironmentLock, inputs: CkbReproRunnerInputs,
    preflight: CkbReproEnvironmentPreflightResult,
    runner: CkbReproRunnerInvoker): Int64 {
    if (!preflight.ok || !preflight.startAllowed) { return 1 }
    let built = buildCkbReproRunnerArgs(reference, lock, inputs)
    if (!built[0].ok) { return 1 }
    runner.run(built[1])
}

private func renderCkbCertifiedRunInput(lock: CkbReproEnvironmentLock): String {
    renderCkbReproEnvironmentLock(lock).replace(
        "\"runCandidateCommit\":\"${p6Escape(lock.runCandidateCommit)}\",", "")
}

private func p6ArgsIdentity(args: Array<String>): String {
    var out = ""
    for (arg in args) { out += "${arg.toArray().size}:${arg}" }
    out
}

private func p6Decode(bytes: Array<UInt8>): (String, String) {
    try { ("ok", String.fromUtf8(bytes)) }
    catch (_: Exception) { ("invalid_response_encoding", "") }
}

private func p6Success(): CkbReproContractResult {
    let out = CkbReproContractResult()
    out.ok = true
    out.diagnostic = "ok"
    out
}

private func p6Failure(diagnostic: String): CkbReproContractResult {
    let out = CkbReproContractResult()
    out.diagnostic = diagnostic
    out
}

private func p6String(object: JsonObject, key: String): String {
    object.get(key).getOrThrow().asString().getValue()
}

private func p6Int(object: JsonObject, key: String): Int64 {
    object.get(key).getOrThrow().asInt().getValue()
}

private func p6Bool(object: JsonObject, key: String): Bool {
    object.get(key).getOrThrow().asBool().getValue()
}

private func p6HashValid(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 71 || !value.startsWith("sha256:")) { return false }
    for (i in 7..runes.size) {
        let rune = runes[i]
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) { return false }
    }
    true
}

private func p6CommitValid(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 40) { return false }
    for (rune in runes) {
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) { return false }
    }
    true
}

private func p6CredentialEnvName(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size == 0) { return false }
    for (i in 0..runes.size) {
        let rune = runes[i]
        if (i == 0 && !((rune >= r'A' && rune <= r'Z') || rune == r'_')) {
            return false
        }
        if (i > 0 && !((rune >= r'A' && rune <= r'Z') ||
            (rune >= r'0' && rune <= r'9') || rune == r'_')) {
            return false
        }
    }
    true
}

private func p6PublicHttpsUrl(value: String): Bool {
    value.startsWith("https://") && !value.contains("@") &&
        !value.contains("localhost") && !value.contains("127.0.0.1")
}

private func p6ContainsSecretOrLocalPath(value: String): Bool {
    let lower = value.toAsciiLower()
    lower.contains("authorization") || lower.contains("bearer ") ||
        lower.contains("/users/") || lower.contains("/home/") ||
        lower.contains("api_key=") || lower.contains("password=")
}

private func p6Escape(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"")
        .replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
}

private func p6VerifyObservedEnvironmentAttestation(path: String,
    fingerprint: String): String {
    let signature = path + ".sig"
    if (!exists(Path(signature)) ||
        (try { canonicalize(Path(signature)).toString() != signature }
            catch (_: Exception) { true })) {
        return "environment_attestation_missing"
    }
    if (!p6ProbeFingerprint(fingerprint)) {
        return "environment_attestation_authority_unavailable"
    }
    let verified = p6ProbeCommand("gpg", ["--batch", "--status-fd", "1",
        "--verify", signature, path])
    if (verified[0] != 0 ||
        !verified[1].contains("VALIDSIG ${fingerprint} ")) {
        return "environment_attestation_signature_invalid"
    }
    "ok"
}

private func p6ProbeFingerprint(value: String): Bool {
    if (value.toRuneArray().size != 40) { return false }
    for (rune in value.runes()) {
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'A' && rune <= r'F'))) { return false }
    }
    true
}

private func p6ProbeCommand(command: String, args: Array<String>):
    (Int64, String) {
    try {
        let process = launch(command, args, stdOut: ProcessRedirect.Pipe,
            stdErr: ProcessRedirect.Pipe)
        let stdout = p6ProbeReadPipe(process.stdOutPipe)
        let stderr = p6ProbeReadPipe(process.stdErrPipe)
        let code = process.wait()
        (code, (stdout + if (stdout == "") { stderr } else { "" })
            .trimAscii().replace("\n", " ").replace("\r", " "))
    } catch (_: Exception) { (127, "") }
}

private func p6ProbeReadPipe(pipe: InputStream): String {
    try { StringReader<InputStream>(pipe).readToEnd() }
    catch (_: Exception) { "" }
}

private func p6Hash(bytes: Array<UInt8>): String {
    let digest = SHA256()
    digest.write(bytes)
    let out = StringBuilder()
    for (byte in digest.finish()) {
        out.append(p6Hex(byte / UInt8(16)))
        out.append(p6Hex(byte % UInt8(16)))
    }
    "sha256:${out.toString()}"
}

private func p6Hex(value: UInt8): String {
    if (value < UInt8(10)) { return "${value}" }
    if (value == UInt8(10)) { return "a" }
    if (value == UInt8(11)) { return "b" }
    if (value == UInt8(12)) { return "c" }
    if (value == UInt8(13)) { return "d" }
    if (value == UInt8(14)) { return "e" }
    "f"
}

private func p6CliAbsolutePath(value: String): Bool {
    value.startsWith("/") && value != "/" && !value.endsWith("/") &&
        !value.contains("//") && !value.contains("/./") &&
        !value.contains("/../") && !value.endsWith("/.") &&
        !value.endsWith("/..") && !value.contains("\\") &&
        !value.contains("\n") && !value.contains("\r") && !value.contains("\t") &&
        value.toRuneArray().size <= 4096
}

private func p6CliPreflightFailure(code: String): CkbReproEnvironmentPreflightResult {
    let out = CkbReproEnvironmentPreflightResult(); out.diagnostic = code; out
}

private func p6CliReadEnvironment(path: String):
    (CkbReproContractResult, CkbReproEnvironmentLock) {
    let bytes = try { File.readFrom(Path(path)) } catch (_: Exception) {
        return (p6Failure("environment_lock_read_failed"), CkbReproEnvironmentLock())
    }
    parseCkbReproEnvironmentLock(bytes)
}

private func p6CliReadUtf8(path: String): (String, String) {
    let bytes = try { File.readFrom(Path(path)) } catch (_: Exception) {
        return ("preflight_artifact_read_failed", "")
    }
    try { ("ok", String.fromUtf8(bytes)) }
    catch (_: Exception) { ("invalid_response_encoding", "") }
}

private func p6CliSafeDiagnostic(value: String): String {
    if (value == "" || value.toRuneArray().size > 128 || value.contains(":") ||
        value.contains("/") || value.contains("\\") || value.contains(" ")) {
        return "redacted_diagnostic"
    }
    value
}

private func p6CliPublic(value: String): String {
    if (value.toRuneArray().size > 128 || p6ContainsSecretOrLocalPath(value) ||
        value.contains("/") || value.contains("\\") || value.contains("\n")) {
        return "redacted"
    }
    value
}
