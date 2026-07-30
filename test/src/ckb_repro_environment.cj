package cangjie_community_knowledge_base_test

import std.collection.ArrayList
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
