package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.fs.{Path, canonicalize, exists}
import std.sort.*
import stdx.encoding.json.*

public class CkbReproCliPathContextAsset {
    public var pathContext: CkbPortablePathContext = CkbPortablePathContext()
    public var releasePathPolicy: CkbReleasePathPolicy = CkbReleasePathPolicy()
    public init() {}
}

public func parseCkbReproCliRuntimeConfigBytes(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbRuntimeConfig) {
    let out = CkbRuntimeConfig()
    let decoded = ckbTypedAssetDecode(bytes, 64 * 1024, "runtime_config")
    if (!decoded[0].ok) { return (decoded[0], out) }
    try {
        let root = JsonValue.fromStr(decoded[1]).asObject()
        if (root.size() != 31 || ckbTypedString(root, "schemaVersion") !=
                "ckb-repro-runtime-config-v1") {
            return (ckbTypedFailure("runtime_config_field_contract_invalid"), out)
        }
        out.networkEnabled = ckbTypedBool(root, "networkEnabled")
        out.embeddingProvider = ckbTypedString(root, "embeddingProvider")
        out.embeddingModel = ckbTypedString(root, "embeddingModel")
        out.embeddingDimensions = ckbTypedInt(root, "embeddingDimensions")
        out.embeddingEndpoint = ckbTypedString(root, "embeddingEndpoint")
        out.embeddingBatchSize = ckbTypedInt(root, "embeddingBatchSize")
        out.embeddingMaxBatchBytes = ckbTypedInt(root, "embeddingMaxBatchBytes")
        out.embeddingMaxTextBytes = ckbTypedInt(root, "embeddingMaxTextBytes")
        out.embeddingTotalTimeoutMillis = ckbTypedInt(root,
            "embeddingTotalTimeoutMillis")
        out.embeddingTimeoutMillis = ckbTypedInt(root, "embeddingTimeoutMillis")
        out.embeddingRetryCount = ckbTypedInt(root, "embeddingRetryCount")
        out.embeddingAllowPrivateEndpoint = ckbTypedBool(root,
            "embeddingAllowPrivateEndpoint")
        out.vectorBackend = ckbTypedString(root, "vectorBackend")
        out.vectorActiveCollection = ckbTypedString(root, "vectorActiveCollection")
        out.vectorCandidateCollection = ckbTypedString(root,
            "vectorCandidateCollection")
        out.vectorEndpoint = ckbTypedString(root, "vectorEndpoint")
        out.vectorDimensions = ckbTypedInt(root, "vectorDimensions")
        out.vectorDistance = ckbTypedString(root, "vectorDistance")
        out.vectorTimeoutMillis = ckbTypedInt(root, "vectorTimeoutMillis")
        out.vectorRetryCount = ckbTypedInt(root, "vectorRetryCount")
        out.vectorAllowPrivateEndpoint = ckbTypedBool(root,
            "vectorAllowPrivateEndpoint")
        out.timeoutMillis = ckbTypedInt(root, "timeoutMillis")
        out.retryCount = ckbTypedInt(root, "retryCount")
        out.networkProxy = ckbTypedString(root, "networkProxy")
        out.networkEnvProxyEnabled = ckbTypedBool(root, "networkEnvProxyEnabled")
        out.networkNoProxy = ckbTypedString(root, "networkNoProxy")
        out.networkInsecureSkipTlsVerify = ckbTypedBool(root,
            "networkInsecureSkipTlsVerify")
        out.networkCaFile = ckbTypedString(root, "networkCaFile")
        out.networkAllowPrivateNetwork = ckbTypedBool(root,
            "networkAllowPrivateNetwork")
        out.networkAllowedHosts = ckbTypedString(root, "networkAllowedHosts")
        if (!ckbTypedRuntimeValid(out) ||
            renderCkbReproCliRuntimeConfig(out) != decoded[1]) {
            return (ckbTypedFailure("runtime_config_invalid"), CkbRuntimeConfig())
        }
        (ckbTypedSuccess(), out)
    } catch (_: Exception) {
        (ckbTypedFailure("runtime_config_field_contract_invalid"),
            CkbRuntimeConfig())
    }
}

public func renderCkbReproCliRuntimeConfig(value: CkbRuntimeConfig): String {
    "{\"schemaVersion\":\"ckb-repro-runtime-config-v1\"," +
        "\"networkEnabled\":${value.networkEnabled}," +
        "\"embeddingProvider\":\"${ckbTypedEscape(value.embeddingProvider)}\"," +
        "\"embeddingModel\":\"${ckbTypedEscape(value.embeddingModel)}\"," +
        "\"embeddingDimensions\":${value.embeddingDimensions}," +
        "\"embeddingEndpoint\":\"${ckbTypedEscape(value.embeddingEndpoint)}\"," +
        "\"embeddingBatchSize\":${value.embeddingBatchSize}," +
        "\"embeddingMaxBatchBytes\":${value.embeddingMaxBatchBytes}," +
        "\"embeddingMaxTextBytes\":${value.embeddingMaxTextBytes}," +
        "\"embeddingTotalTimeoutMillis\":${value.embeddingTotalTimeoutMillis}," +
        "\"embeddingTimeoutMillis\":${value.embeddingTimeoutMillis}," +
        "\"embeddingRetryCount\":${value.embeddingRetryCount}," +
        "\"embeddingAllowPrivateEndpoint\":${value.embeddingAllowPrivateEndpoint}," +
        "\"vectorBackend\":\"${ckbTypedEscape(value.vectorBackend)}\"," +
        "\"vectorActiveCollection\":\"${ckbTypedEscape(value.vectorActiveCollection)}\"," +
        "\"vectorCandidateCollection\":\"${ckbTypedEscape(value.vectorCandidateCollection)}\"," +
        "\"vectorEndpoint\":\"${ckbTypedEscape(value.vectorEndpoint)}\"," +
        "\"vectorDimensions\":${value.vectorDimensions}," +
        "\"vectorDistance\":\"${ckbTypedEscape(value.vectorDistance)}\"," +
        "\"vectorTimeoutMillis\":${value.vectorTimeoutMillis}," +
        "\"vectorRetryCount\":${value.vectorRetryCount}," +
        "\"vectorAllowPrivateEndpoint\":${value.vectorAllowPrivateEndpoint}," +
        "\"timeoutMillis\":${value.timeoutMillis},\"retryCount\":${value.retryCount}," +
        "\"networkProxy\":\"${ckbTypedEscape(value.networkProxy)}\"," +
        "\"networkEnvProxyEnabled\":${value.networkEnvProxyEnabled}," +
        "\"networkNoProxy\":\"${ckbTypedEscape(value.networkNoProxy)}\"," +
        "\"networkInsecureSkipTlsVerify\":${value.networkInsecureSkipTlsVerify}," +
        "\"networkCaFile\":\"${ckbTypedEscape(value.networkCaFile)}\"," +
        "\"networkAllowPrivateNetwork\":${value.networkAllowPrivateNetwork}," +
        "\"networkAllowedHosts\":\"${ckbTypedEscape(value.networkAllowedHosts)}\"}"
}

public func parseCkbReproCliPathContextBytes(pathPolicyBytes: Array<UInt8>,
    localRootMapBytes: Array<UInt8>, apiRoutesBytes: Array<UInt8>,
    releasePolicyBytes: Array<UInt8>):
    (CkbReproContractResult, CkbReproCliPathContextAsset) {
    let out = CkbReproCliPathContextAsset()
    let policyDecoded = ckbTypedAssetDecode(pathPolicyBytes, 64 * 1024,
        "path_policy")
    if (!policyDecoded[0].ok) { return (policyDecoded[0], out) }
    let policy = parseCkbPortablePathPolicy(pathPolicyBytes)
    if (!policy[0].ok || !validateCkbPortablePathPolicyForBuild(policy[1]).ok ||
        renderCkbPortablePathPolicy(policy[1]) != policyDecoded[1]) {
        return (ckbTypedFailure("path_policy_invalid"), out)
    }
    let rootsDecoded = ckbTypedAssetDecode(localRootMapBytes, 256 * 1024,
        "local_root_map")
    if (!rootsDecoded[0].ok) { return (rootsDecoded[0], out) }
    let roots = parseCkbPortableLocalRootMap(localRootMapBytes)
    if (!roots[0].ok || renderCkbReproCliLocalRootMap(roots[1]) != rootsDecoded[1]) {
        return (ckbTypedFailure("portable_local_root_map_invalid"), out)
    }
    let allowed = ArrayList<String>()
    for (root in roots[1].roots) { allowed.add(root.sourceId) }
    if (!validateCkbPortableLocalRootMap(roots[1], allowed.toArray()).ok) {
        return (ckbTypedFailure("portable_local_root_map_invalid"), out)
    }
    let routes = parseCkbReproApiRoutes(apiRoutesBytes)
    if (!routes[0].ok) { return (routes[0], out) }
    let release = ckbTypedParseReleasePolicy(releasePolicyBytes,
        ckbReproBundleHash(pathPolicyBytes),
        ckbReproBundleHash(localRootMapBytes), ckbReproBundleHash(apiRoutesBytes))
    if (!release[0].ok) { return (release[0], out) }
    out.pathContext.policy = policy[1]
    out.pathContext.localRoots = roots[1]
    for (route in routes[1]) { out.pathContext.apiRoutes.add(route) }
    out.releasePathPolicy = release[1]
    let validation = validateCkbPortablePathContext(out.pathContext)
    if (!validation.ok) { return (validation, CkbReproCliPathContextAsset()) }
    (ckbTypedSuccess(), out)
}

public func renderCkbReproCliLocalRootMap(value: CkbPortableLocalRootMap): String {
    let rows = ArrayList<String>()
    for (root in value.roots) {
        rows.add("{\"sourceId\":\"${ckbTypedEscape(root.sourceId)}\"," +
            "\"kind\":\"${ckbTypedEscape(root.kind)}\"," +
            "\"localRoot\":\"${ckbTypedEscape(root.localRoot)}\"}")
    }
    "{\"schemaVersion\":\"${ckbTypedEscape(value.schemaVersion)}\"," +
        "\"roots\":[${ckbTypedJoin(rows)}]}"
}

public func parseCkbReproCliEvalSupportBytes(bytes: Array<UInt8>):
    (CkbReproContractResult, CangjieEvalSupportSnapshot) {
    let out = CangjieEvalSupportSnapshot()
    let decoded = ckbTypedAssetDecode(bytes, 32 * 1024 * 1024, "eval_support")
    if (!decoded[0].ok) { return (decoded[0], out) }
    try {
        let root = JsonValue.fromStr(decoded[1]).asObject()
        if (root.size() != 7) {
            return (ckbTypedFailure("eval_support_field_contract_invalid"), out)
        }
        out.schemaVersion = ckbTypedString(root, "schemaVersion")
        out.datasetVersion = ckbTypedString(root, "datasetVersion")
        out.revision = ckbTypedInt(root, "revision")
        out.recordCount = ckbTypedInt(root, "recordCount")
        out.authorityHash = ckbTypedString(root, "authorityHash")
        out.checksum = ckbTypedString(root, "checksum")
        out.jsonl = ckbTypedString(root, "jsonl")
        let validated = validateVersionedEvalSupportSnapshot(out)
        if (!validated.ok || renderCkbReproCliEvalSupport(out) != decoded[1]) {
            return (ckbTypedFailure(if (validated.diagnostics.size > 0) {
                validated.diagnostics[0]
            } else { "eval_support_noncanonical" }), CangjieEvalSupportSnapshot())
        }
        (ckbTypedSuccess(), out)
    } catch (_: Exception) {
        (ckbTypedFailure("eval_support_field_contract_invalid"),
            CangjieEvalSupportSnapshot())
    }
}

public func renderCkbReproCliEvalSupport(value: CangjieEvalSupportSnapshot): String {
    "{\"schemaVersion\":\"${ckbTypedEscape(value.schemaVersion)}\"," +
        "\"datasetVersion\":\"${ckbTypedEscape(value.datasetVersion)}\"," +
        "\"revision\":${value.revision},\"recordCount\":${value.recordCount}," +
        "\"authorityHash\":\"${ckbTypedEscape(value.authorityHash)}\"," +
        "\"checksum\":\"${ckbTypedEscape(value.checksum)}\"," +
        "\"jsonl\":\"${ckbTypedEscape(value.jsonl)}\"}"
}

public func parseCkbReproCliLeakageAuthorityBytes(bytes: Array<UInt8>):
    (CkbReproContractResult, CangjieBenchmarkLeakageAuthority) {
    let out = CangjieBenchmarkLeakageAuthority()
    let decoded = ckbTypedAssetDecode(bytes, 32 * 1024 * 1024,
        "leakage_authority")
    if (!decoded[0].ok) { return (decoded[0], out) }
    try {
        let root = JsonValue.fromStr(decoded[1]).asObject()
        if (root.size() != 3 || ckbTypedString(root, "schemaVersion") !=
                "ckb-repro-leakage-authority-v1") {
            return (ckbTypedFailure("leakage_authority_field_contract_invalid"), out)
        }
        var previous = ""
        for (value in root.get("fingerprints").getOrThrow().asArray().getItems()) {
            let fingerprint = value.asString().getValue()
            if (!ckbTypedSafeValue(fingerprint, 4096) ||
                ckbTypedSensitive(fingerprint) || ckbTypedPrivatePath(fingerprint) ||
                (previous != "" && previous >= fingerprint)) {
                return (ckbTypedFailure("leakage_authority_invalid"),
                    CangjieBenchmarkLeakageAuthority())
            }
            out.fingerprints.add(fingerprint); out.fingerprintSet.add(fingerprint)
            previous = fingerprint
        }
        let expected = ckbTypedString(root, "authorityHash")
        if (out.fingerprints.size == 0 || expected !=
                ckbReproLeakageAuthorityHash(out) ||
            renderCkbReproCliLeakageAuthority(out) != decoded[1]) {
            return (ckbTypedFailure("leakage_authority_invalid"),
                CangjieBenchmarkLeakageAuthority())
        }
        (ckbTypedSuccess(), out)
    } catch (_: Exception) {
        (ckbTypedFailure("leakage_authority_field_contract_invalid"),
            CangjieBenchmarkLeakageAuthority())
    }
}

public func renderCkbReproCliLeakageAuthority(
    value: CangjieBenchmarkLeakageAuthority): String {
    let rows = ArrayList<String>()
    for (fingerprint in value.fingerprints) {
        rows.add("\"${ckbTypedEscape(fingerprint)}\"")
    }
    "{\"schemaVersion\":\"ckb-repro-leakage-authority-v1\"," +
        "\"fingerprints\":[${ckbTypedJoin(rows)}],\"authorityHash\":\"" +
        "${ckbReproLeakageAuthorityHash(value)}\"}"
}

public func parseCkbReproCliRunnerInputsBytes(bytes: Array<UInt8>, mode: String):
    (CkbReproContractResult, CkbReproRunnerInputs) {
    let out = CkbReproRunnerInputs()
    if (mode != "run-certify") {
        return (ckbTypedFailure("runner_inputs_mode_invalid"), out)
    }
    let decoded = ckbTypedAssetDecode(bytes, 128 * 1024, "runner_inputs")
    if (!decoded[0].ok) { return (decoded[0], out) }
    try {
        let root = JsonValue.fromStr(decoded[1]).asObject()
        if (root.size() != 19 || ckbTypedString(root, "schemaVersion") !=
                "ckb-repro-runner-inputs-v1") {
            return (ckbTypedFailure("runner_inputs_field_contract_invalid"), out)
        }
        out.runId = ckbTypedString(root, "runId")
        out.repoRoot = ckbTypedString(root, "repoRoot")
        out.runsRoot = ckbTypedString(root, "runsRoot")
        out.datasetRoot = ckbTypedString(root, "datasetRoot")
        out.authorityManifestPath = ckbTypedString(root, "authorityManifestPath")
        out.ckbBin = ckbTypedString(root, "ckbBin")
        out.ckbConfig = ckbTypedString(root, "ckbConfig")
        out.ckbStore = ckbTypedString(root, "ckbStore")
        out.ckbHttpBase = ckbTypedString(root, "ckbHttpBase")
        out.claudeBin = ckbTypedString(root, "claudeBin")
        out.docsRoot = ckbTypedString(root, "docsRoot")
        out.candidateVersion = ckbTypedString(root, "candidateVersion")
        out.knowledgeVersion = ckbTypedString(root, "knowledgeVersion")
        out.providerIdentityHash = ckbTypedString(root, "providerIdentityHash")
        out.providerIdentityArtifactPath = ckbTypedString(root,
            "providerIdentityArtifactPath")
        out.frozenCandidateManifestPath = ckbTypedString(root,
            "frozenCandidateManifestPath")
        out.certificationPreflightPath = ckbTypedString(root,
            "certificationPreflightPath")
        out.certificationRunManifestPath = ckbTypedString(root,
            "certificationRunManifestPath")
        if (!ckbTypedRunnerValid(out) ||
            renderCkbReproCliRunnerInputs(out) != decoded[1]) {
            return (ckbTypedFailure("runner_inputs_invalid"),
                CkbReproRunnerInputs())
        }
        (ckbTypedSuccess(), out)
    } catch (_: Exception) {
        (ckbTypedFailure("runner_inputs_field_contract_invalid"),
            CkbReproRunnerInputs())
    }
}

public func renderCkbReproCliRunnerInputs(value: CkbReproRunnerInputs): String {
    "{\"schemaVersion\":\"ckb-repro-runner-inputs-v1\"," +
        "\"runId\":\"${ckbTypedEscape(value.runId)}\"," +
        "\"repoRoot\":\"${ckbTypedEscape(value.repoRoot)}\"," +
        "\"runsRoot\":\"${ckbTypedEscape(value.runsRoot)}\"," +
        "\"datasetRoot\":\"${ckbTypedEscape(value.datasetRoot)}\"," +
        "\"authorityManifestPath\":\"${ckbTypedEscape(value.authorityManifestPath)}\"," +
        "\"ckbBin\":\"${ckbTypedEscape(value.ckbBin)}\"," +
        "\"ckbConfig\":\"${ckbTypedEscape(value.ckbConfig)}\"," +
        "\"ckbStore\":\"${ckbTypedEscape(value.ckbStore)}\"," +
        "\"ckbHttpBase\":\"${ckbTypedEscape(value.ckbHttpBase)}\"," +
        "\"claudeBin\":\"${ckbTypedEscape(value.claudeBin)}\"," +
        "\"docsRoot\":\"${ckbTypedEscape(value.docsRoot)}\"," +
        "\"candidateVersion\":\"${ckbTypedEscape(value.candidateVersion)}\"," +
        "\"knowledgeVersion\":\"${ckbTypedEscape(value.knowledgeVersion)}\"," +
        "\"providerIdentityHash\":\"${ckbTypedEscape(value.providerIdentityHash)}\"," +
        "\"providerIdentityArtifactPath\":\"${ckbTypedEscape(value.providerIdentityArtifactPath)}\"," +
        "\"frozenCandidateManifestPath\":\"${ckbTypedEscape(value.frozenCandidateManifestPath)}\"," +
        "\"certificationPreflightPath\":\"${ckbTypedEscape(value.certificationPreflightPath)}\"," +
        "\"certificationRunManifestPath\":\"${ckbTypedEscape(value.certificationRunManifestPath)}\"}"
}

public func composeCkbReproCliPrivateBuildAuthority(
    evalSupport: CangjieEvalSupportSnapshot,
    leakage: CangjieBenchmarkLeakageAuthority,
    path: CkbReproCliPathContextAsset, temporaryRoot: String,
    outputRoot: String): (CkbReproContractResult, CkbReproPrivateBuildAuthority) {
    let out = CkbReproPrivateBuildAuthority()
    let evalValidated = validateVersionedEvalSupportSnapshot(evalSupport)
    if (!evalValidated.ok || !validateCkbPortablePathContext(path.pathContext).ok ||
        leakage.fingerprints.size == 0 ||
        !ckbTypedCanonicalNewPath(temporaryRoot) ||
        !ckbTypedCanonicalNewPath(outputRoot) || temporaryRoot == outputRoot ||
        ckbTypedSensitive(temporaryRoot) || ckbTypedSensitive(outputRoot) ||
        ckbTypedProtectedPath(temporaryRoot, path.releasePathPolicy) ||
        ckbTypedProtectedPath(outputRoot, path.releasePathPolicy)) {
        return (ckbTypedFailure("private_build_authority_invalid"), out)
    }
    out.evalSupport = evalSupport; out.leakage = leakage
    out.leakageHash = ckbReproLeakageAuthorityHash(leakage)
    out.pathContext = path.pathContext; out.temporaryRoot = temporaryRoot
    out.outputRoot = outputRoot
    (ckbTypedSuccess(), out)
}

private func ckbTypedParseReleasePolicy(bytes: Array<UInt8>, policyHash: String,
    rootsHash: String, routesHash: String):
    (CkbReproContractResult, CkbReleasePathPolicy) {
    let out = CkbReleasePathPolicy()
    let decoded = ckbTypedAssetDecode(bytes, 64 * 1024, "path_context")
    if (!decoded[0].ok) { return (decoded[0], out) }
    try {
        let root = JsonValue.fromStr(decoded[1]).asObject()
        if (root.size() != 7 || ckbTypedString(root, "schemaVersion") !=
                "ckb-repro-path-context-v1" ||
            ckbTypedString(root, "portablePolicyHash") != policyHash ||
            ckbTypedString(root, "localRootMapHash") != rootsHash ||
            ckbTypedString(root, "apiRoutesHash") != routesHash) {
            return (ckbTypedFailure("path_context_authority_mismatch"), out)
        }
        out.worktreeRoot = ckbTypedString(root, "worktreeRoot")
        out.productionStoreRoot = ckbTypedString(root, "productionStoreRoot")
        out.userConfigRoot = ckbTypedString(root, "userConfigRoot")
        if (!ckbTypedAbsolutePath(out.worktreeRoot) ||
            !ckbTypedAbsolutePath(out.productionStoreRoot) ||
            !ckbTypedAbsolutePath(out.userConfigRoot) ||
            out.worktreeRoot == out.productionStoreRoot ||
            out.worktreeRoot == out.userConfigRoot ||
            out.productionStoreRoot == out.userConfigRoot ||
            ckbTypedSensitive(decoded[1])) {
            return (ckbTypedFailure("release_path_policy_invalid"),
                CkbReleasePathPolicy())
        }
        let canonical = "{\"schemaVersion\":\"ckb-repro-path-context-v1\"," +
            "\"portablePolicyHash\":\"${policyHash}\"," +
            "\"localRootMapHash\":\"${rootsHash}\"," +
            "\"apiRoutesHash\":\"${routesHash}\"," +
            "\"worktreeRoot\":\"${ckbTypedEscape(out.worktreeRoot)}\"," +
            "\"productionStoreRoot\":\"${ckbTypedEscape(out.productionStoreRoot)}\"," +
            "\"userConfigRoot\":\"${ckbTypedEscape(out.userConfigRoot)}\"}"
        if (canonical != decoded[1]) {
            return (ckbTypedFailure("path_context_noncanonical"),
                CkbReleasePathPolicy())
        }
        (ckbTypedSuccess(), out)
    } catch (_: Exception) {
        (ckbTypedFailure("path_context_field_contract_invalid"),
            CkbReleasePathPolicy())
    }
}

private func ckbTypedRuntimeValid(value: CkbRuntimeConfig): Bool {
    for (text in [value.embeddingProvider, value.embeddingModel,
        value.vectorBackend, value.vectorActiveCollection,
        value.vectorCandidateCollection, value.vectorDistance,
        value.embeddingEndpoint, value.vectorEndpoint, value.networkProxy,
        value.networkNoProxy, value.networkCaFile, value.networkAllowedHosts]) {
        if (!ckbTypedSafeValue(text, 4096) || ckbTypedSensitive(text)) { return false }
    }
    if (value.embeddingProvider == "" || value.embeddingModel == "" ||
        value.vectorBackend == "" || value.vectorActiveCollection == "" ||
        value.vectorCandidateCollection == "" || value.vectorDistance == "" ||
        value.embeddingDimensions <= 0 || value.embeddingDimensions > 65536 ||
        value.vectorDimensions <= 0 || value.vectorDimensions > 65536 ||
        value.embeddingBatchSize <= 0 || value.embeddingBatchSize > 10000 ||
        value.embeddingMaxBatchBytes <= 0 || value.embeddingMaxTextBytes <= 0 ||
        value.embeddingTotalTimeoutMillis < 0 ||
        value.embeddingTimeoutMillis <= 0 || value.vectorTimeoutMillis <= 0 ||
        value.timeoutMillis <= 0 || value.embeddingRetryCount < 0 ||
        value.vectorRetryCount < 0 || value.retryCount < 0) { return false }
    for (endpoint in [value.embeddingEndpoint, value.vectorEndpoint,
        value.networkProxy]) {
        if (endpoint != "" && (!ckbTypedHttpUrl(endpoint) ||
            endpoint.contains("@") || endpoint.contains("?") ||
            endpoint.contains("#"))) { return false }
    }
    value.networkCaFile == "" || ckbTypedAbsolutePath(value.networkCaFile)
}

private func ckbTypedRunnerValid(value: CkbReproRunnerInputs): Bool {
    for (text in [value.runId, value.candidateVersion, value.knowledgeVersion]) {
        if (!ckbTypedSafeValue(text, 512) || text == "" ||
            ckbTypedSensitive(text)) { return false }
    }
    for (path in [value.repoRoot, value.runsRoot, value.datasetRoot,
        value.authorityManifestPath, value.ckbBin, value.ckbConfig,
        value.ckbStore, value.claudeBin, value.docsRoot,
        value.providerIdentityArtifactPath, value.frozenCandidateManifestPath,
        value.certificationPreflightPath, value.certificationRunManifestPath]) {
        if (!ckbTypedAbsolutePath(path) || ckbTypedSensitive(path)) { return false }
    }
    ckbTypedHttpUrl(value.ckbHttpBase) && !value.ckbHttpBase.contains("@") &&
        ckbTypedHash(value.providerIdentityHash)
}

private func ckbTypedAssetDecode(bytes: Array<UInt8>, maxBytes: Int64,
    role: String): (CkbReproContractResult, String) {
    if (bytes.size <= 0 || bytes.size > maxBytes) {
        return (ckbTypedFailure("${role}_size_invalid"), "")
    }
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (ckbTypedFailure("invalid_response_encoding"), "")
    }
    if (!ckbTypedSafeValue(text, maxBytes)) {
        return (ckbTypedFailure("${role}_text_invalid"), "")
    }
    (ckbTypedSuccess(), text)
}

private func ckbTypedSafeValue(value: String, maxRunes: Int64): Bool {
    let runes = value.toRuneArray()
    if (runes.size > maxRunes) { return false }
    for (rune in runes) {
        if ((rune >= r'\u{0000}' && rune <= r'\u{0008}') ||
            (rune >= r'\u{000b}' && rune <= r'\u{000c}') ||
            (rune >= r'\u{000e}' && rune <= r'\u{001f}') || rune == r'\u{007f}') {
            return false
        }
    }
    true
}

private func ckbTypedSensitive(value: String): Bool {
    let lower = value.toAsciiLower()
    lower.contains("authorization:") || lower.contains("bearer ") ||
        lower.contains("api_key=") || lower.contains("apikey=") ||
        lower.contains("password=") || lower.contains("secret=")
}

private func ckbTypedPrivatePath(value: String): Bool {
    let lower = value.toAsciiLower().replace("\\", "/")
    lower.contains("/users/") || lower.contains("/home/") ||
        lower.contains("ckb-data/") || lower.contains(".metis/")
}

private func ckbTypedAbsolutePath(value: String): Bool {
    value.startsWith("/") && value.trimAscii() == value &&
        !value.contains("\\") && !value.contains("//") &&
        !value.contains("/../") && !value.endsWith("/..") &&
        !value.contains("/./") && !value.endsWith("/.") &&
        ckbTypedSafeValue(value, 4096)
}

private func ckbTypedCanonicalNewPath(value: String): Bool {
    if (!ckbTypedAbsolutePath(value)) { return false }
    let path = Path(value)
    if (exists(path)) {
        return try { canonicalize(path).toString() == value }
            catch (_: Exception) { false }
    }
    if (!exists(path.parent)) { return false }
    let parent = try { canonicalize(path.parent).toString() }
        catch (_: Exception) { return false }
    Path(parent).join(path.fileName).toString() == value
}

private func ckbTypedProtectedPath(value: String,
    policy: CkbReleasePathPolicy): Bool {
    for (root in [policy.worktreeRoot, policy.productionStoreRoot,
        policy.userConfigRoot]) {
        if (root != "" && (value == root || value.startsWith("${root}/") ||
            root.startsWith("${value}/"))) { return true }
    }
    false
}

private func ckbTypedHttpUrl(value: String): Bool {
    (value.startsWith("http://") || value.startsWith("https://")) &&
        value.trimAscii() == value && ckbTypedSafeValue(value, 4096)
}

private func ckbTypedHash(value: String): Bool {
    let prefix = "sha256:".toRuneArray(); var index: Int64 = 0
    for (rune in value.runes()) {
        if (index < prefix.size) {
            if (rune != prefix[index]) { return false }
        } else if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) { return false }
        index += 1
    }
    index == 71
}

private func ckbTypedString(root: JsonObject, key: String): String {
    root.get(key).getOrThrow().asString().getValue()
}

private func ckbTypedInt(root: JsonObject, key: String): Int64 {
    root.get(key).getOrThrow().asInt().getValue()
}

private func ckbTypedBool(root: JsonObject, key: String): Bool {
    root.get(key).getOrThrow().asBool().getValue()
}

private func ckbTypedEscape(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"")
        .replace("\n", "\\n").replace("\r", "\\r")
        .replace("\t", "\\t")
}

private func ckbTypedJoin(values: ArrayList<String>): String {
    let out = StringBuilder()
    for (i in 0..values.size) {
        if (i > 0) { out.append(",") }
        out.append(values[i])
    }
    out.toString()
}

private func ckbTypedSuccess(): CkbReproContractResult {
    let out = CkbReproContractResult(); out.ok = true; out.diagnostic = "ok"; out
}

private func ckbTypedFailure(code: String): CkbReproContractResult {
    let out = CkbReproContractResult(); out.diagnostic = code; out
}
