package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.convert.Parsable
import std.fs.{Path, canonicalize, exists}
import std.sort.*
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

public class CkbReproCliPathContextAsset {
    public var pathContext: CkbPortablePathContext = CkbPortablePathContext()
    public var releasePathPolicy: CkbReleasePathPolicy = CkbReleasePathPolicy()
    public init() {}
}

public class CkbP8OwnedLocalRuntimeAuthority {
    public var schemaVersion: String = ""
    public var qdrantEndpoint: String = ""
    public var restEndpoint: String = ""
    public var mcpHttpEndpoint: String = ""
    public var ckbExecutable: String = ""
    public var ckbExecutableSha256: String = ""
    public var dockerExecutable: String = ""
    public var dockerExecutableSha256: String = ""
    public var qdrantImageReference: String = ""
    public var qdrantImageId: String = ""
    public var timeoutMillis: Int64 = 0
    public init() {}
}

public func parseCkbP8OwnedLocalRuntimeAuthorityBytes(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbP8OwnedLocalRuntimeAuthority) {
    let out = CkbP8OwnedLocalRuntimeAuthority()
    let decoded = ckbTypedAssetDecode(bytes, 64 * 1024, "runtime_transport")
    if (!decoded[0].ok) { return (decoded[0], out) }
    try {
        let root = JsonValue.fromStr(decoded[1]).asObject()
        if (root.size() != 11 || ckbTypedString(root, "schemaVersion") !=
                "ckb-repro-p8-owned-local-runtime-v1") {
            return (ckbTypedFailure(
                "p8b_runtime_transport_field_contract_invalid"), out)
        }
        out.schemaVersion = ckbTypedString(root, "schemaVersion")
        out.qdrantEndpoint = ckbTypedString(root, "qdrantEndpoint")
        out.restEndpoint = ckbTypedString(root, "restEndpoint")
        out.mcpHttpEndpoint = ckbTypedString(root, "mcpHttpEndpoint")
        out.ckbExecutable = ckbTypedString(root, "ckbExecutable")
        out.ckbExecutableSha256 = ckbTypedString(root, "ckbExecutableSha256")
        out.dockerExecutable = ckbTypedString(root, "dockerExecutable")
        out.dockerExecutableSha256 = ckbTypedString(root,
            "dockerExecutableSha256")
        out.qdrantImageReference = ckbTypedString(root,
            "qdrantImageReference")
        out.qdrantImageId = ckbTypedString(root, "qdrantImageId")
        out.timeoutMillis = ckbTypedInt(root, "timeoutMillis")
        if (!ckbTypedP8BLoopbackEndpoint(out.qdrantEndpoint, "") ||
            !ckbTypedP8BLoopbackEndpoint(out.restEndpoint,
                "/v1/cangjie/syntax-query") ||
            !ckbTypedP8BLoopbackEndpoint(out.mcpHttpEndpoint, "/mcp") ||
            ckbTypedP8BOrigin(out.restEndpoint) !=
                ckbTypedP8BOrigin(out.mcpHttpEndpoint) ||
            !validateCkbP8BExecutableIdentity(out).ok ||
            !validateCkbP8DockerExecutableIdentity(out).ok ||
            !ckbTypedP8QdrantImageReference(out.qdrantImageReference) ||
            !ckbTypedHash(out.qdrantImageId) ||
            out.timeoutMillis < 100 || out.timeoutMillis > 300000 ||
            renderCkbP8OwnedLocalRuntimeAuthority(out) != decoded[1]) {
            return (ckbTypedFailure("p8b_runtime_transport_invalid"),
                CkbP8OwnedLocalRuntimeAuthority())
        }
        (ckbTypedSuccess(), out)
    } catch (_: Exception) {
        (ckbTypedFailure("p8b_runtime_transport_field_contract_invalid"),
            CkbP8OwnedLocalRuntimeAuthority())
    }
}

public func renderCkbP8OwnedLocalRuntimeAuthority(
    value: CkbP8OwnedLocalRuntimeAuthority): String {
    "{\"schemaVersion\":\"ckb-repro-p8-owned-local-runtime-v1\"," +
        "\"qdrantEndpoint\":\"${ckbTypedEscape(value.qdrantEndpoint)}\"," +
        "\"restEndpoint\":\"${ckbTypedEscape(value.restEndpoint)}\"," +
        "\"mcpHttpEndpoint\":\"${ckbTypedEscape(value.mcpHttpEndpoint)}\"," +
        "\"ckbExecutable\":\"${ckbTypedEscape(value.ckbExecutable)}\"," +
        "\"ckbExecutableSha256\":\"${value.ckbExecutableSha256}\"," +
        "\"dockerExecutable\":\"${ckbTypedEscape(value.dockerExecutable)}\"," +
        "\"dockerExecutableSha256\":\"${value.dockerExecutableSha256}\"," +
        "\"qdrantImageReference\":\"${ckbTypedEscape(value.qdrantImageReference)}\"," +
        "\"qdrantImageId\":\"${value.qdrantImageId}\"," +
        "\"timeoutMillis\":${value.timeoutMillis}}"
}

public func buildCkbP8OwnedLocalRuntimeAuthority(ckbExecutable: String,
    dockerExecutable: String, qdrantEndpoint: String, restEndpoint: String,
    mcpHttpEndpoint: String, qdrantImageReference: String,
    qdrantImageId: String, timeoutMillis: Int64):
    (CkbReproContractResult, CkbP8OwnedLocalRuntimeAuthority) {
    let out = CkbP8OwnedLocalRuntimeAuthority()
    let ckb = ckbReproReadSingleFileNoFollow(ckbExecutable, 536870912)
    let docker = ckbReproReadSingleFileNoFollow(dockerExecutable, 536870912)
    if (!ckb[0] || !docker[0]) {
        return (ckbTypedFailure("p8_executable_identity_invalid"), out)
    }
    out.schemaVersion = "ckb-repro-p8-owned-local-runtime-v1"
    out.qdrantEndpoint = qdrantEndpoint; out.restEndpoint = restEndpoint
    out.mcpHttpEndpoint = mcpHttpEndpoint; out.ckbExecutable = ckbExecutable
    out.ckbExecutableSha256 = ckbReproBundleHash(ckb[1])
    out.dockerExecutable = dockerExecutable
    out.dockerExecutableSha256 = ckbReproBundleHash(docker[1])
    out.qdrantImageReference = qdrantImageReference
    out.qdrantImageId = qdrantImageId; out.timeoutMillis = timeoutMillis
    let parsed = parseCkbP8OwnedLocalRuntimeAuthorityBytes(
        renderCkbP8OwnedLocalRuntimeAuthority(out).toArray())
    if (!parsed[0].ok) { return (parsed[0], CkbP8OwnedLocalRuntimeAuthority()) }
    parsed
}

public func buildCkbP8EmptyMcpStdioCommand(
    authority: CkbP8OwnedLocalRuntimeAuthority):
    (CkbReproContractResult, CkbMcpStdioCommandSpec) {
    let out = CkbMcpStdioCommandSpec()
    if (!validateCkbP8BExecutableIdentity(authority).ok) {
        return (ckbTypedFailure("p8b_mcp_stdio_command_forbidden"), out)
    }
    out.schemaVersion = "ckb-mcp-stdio-command-v1"
    out.executable = authority.ckbExecutable
    out.timeoutMillis = authority.timeoutMillis
    let bytes = renderCkbMcpStdioCommandSpec(out).toArray()
    parseCkbP8BMcpStdioCommand(bytes, authority)
}

public func buildCkbReproCliRunnerAuthority(environmentNames: Array<String>):
    (CkbReproContractResult, CkbReproCliRunnerAuthority) {
    let out = CkbReproCliRunnerAuthority()
    out.schemaVersion = "ckb-repro-runner-authority-v1"
    let sorted = environmentNames.clone()
    sort(sorted)
    var previous = ""
    for (name in sorted) {
        if (name != previous) {
            out.credentialEnvironmentVariables.add(name)
            previous = name
        }
    }
    let text = renderCkbReproCliRunnerAuthority(out)
    parseCkbReproCliRunnerAuthority(text.toArray(), "run-certify")
}

public func validateCkbP8BExecutableIdentity(
    transport: CkbP8OwnedLocalRuntimeAuthority): CkbReproContractResult {
    let evidence = ckbTypedP8BFileEvidence(transport.ckbExecutable,
        transport.ckbExecutableSha256)
    if (!evidence.ok) {
        return ckbTypedFailure("p8b_ckb_executable_identity_invalid")
    }
    ckbTypedSuccess()
}

public func validateCkbP8DockerExecutableIdentity(
    transport: CkbP8OwnedLocalRuntimeAuthority): CkbReproContractResult {
    let evidence = ckbTypedP8BFileEvidence(transport.dockerExecutable,
        transport.dockerExecutableSha256)
    if (!evidence.ok) {
        return ckbTypedFailure("p8_docker_executable_identity_invalid")
    }
    ckbTypedSuccess()
}

public func validateCkbP8BTransportEnvironment(
    transport: CkbP8OwnedLocalRuntimeAuthority,
    environment: CkbReproEnvironmentLock): CkbReproContractResult {
    if (transport.qdrantImageId != environment.qdrantImageDigest) {
        return ckbTypedFailure("p8b_qdrant_image_authority_mismatch")
    }
    ckbTypedSuccess()
}

public func parseCkbP8BMcpStdioCommand(bytes: Array<UInt8>,
    transport: CkbP8OwnedLocalRuntimeAuthority):
    (CkbReproContractResult, CkbMcpStdioCommandSpec) {
    let parsed = parseCkbMcpStdioCommandSpec(bytes)
    if (!parsed[0].ok) { return parsed }
    if (parsed[1].executable != transport.ckbExecutable ||
        parsed[1].args.size != 0 || parsed[1].environment.size != 0 ||
        parsed[1].timeoutMillis != transport.timeoutMillis ||
        !validateCkbP8BExecutableIdentity(transport).ok) {
        return (ckbTypedFailure("p8b_mcp_stdio_command_forbidden"),
            CkbMcpStdioCommandSpec())
    }
    parsed
}

public func parseCkbReproCliRuntimeConfigBytes(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbRuntimeConfig) {
    let out = CkbRuntimeConfig()
    let decoded = ckbTypedAssetDecode(bytes, 64 * 1024, "runtime_config")
    if (!decoded[0].ok) { return (decoded[0], out) }
    try {
        let root = JsonValue.fromStr(decoded[1]).asObject()
        if (root.size() != 33 || ckbTypedString(root, "schemaVersion") !=
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
        out.serviceBind = ckbTypedString(root, "serviceBind")
        out.servicePort = ckbTypedInt(root, "servicePort")
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
        "\"networkAllowedHosts\":\"${ckbTypedEscape(value.networkAllowedHosts)}\"," +
        "\"serviceBind\":\"${ckbTypedEscape(value.serviceBind)}\"," +
        "\"servicePort\":${value.servicePort}}"
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

public func buildAndRenderCkbReproCliPathContext(
    pathPolicyBytes: Array<UInt8>, localRootMapBytes: Array<UInt8>,
    apiRoutesBytes: Array<UInt8>, worktreeRoot: String,
    productionStoreRoot: String, userConfigRoot: String):
    (CkbReproContractResult, String) {
    let policy = parseCkbPortablePathPolicy(pathPolicyBytes)
    let roots = parseCkbPortableLocalRootMap(localRootMapBytes)
    let routes = parseCkbReproApiRoutes(apiRoutesBytes)
    if (!policy[0].ok || !validateCkbPortablePathPolicyForBuild(policy[1]).ok ||
        !roots[0].ok || !routes[0].ok ||
        !ckbTypedAbsolutePath(worktreeRoot) ||
        !ckbTypedAbsolutePath(productionStoreRoot) ||
        !ckbTypedAbsolutePath(userConfigRoot) ||
        worktreeRoot == productionStoreRoot || worktreeRoot == userConfigRoot ||
        productionStoreRoot == userConfigRoot) {
        return (ckbTypedFailure("path_context_input_invalid"), "")
    }
    let text = "{\"schemaVersion\":\"ckb-repro-path-context-v1\"," +
        "\"portablePolicyHash\":\"${ckbReproBundleHash(pathPolicyBytes)}\"," +
        "\"localRootMapHash\":\"${ckbReproBundleHash(localRootMapBytes)}\"," +
        "\"apiRoutesHash\":\"${ckbReproBundleHash(apiRoutesBytes)}\"," +
        "\"worktreeRoot\":\"${ckbTypedEscape(worktreeRoot)}\"," +
        "\"productionStoreRoot\":\"${ckbTypedEscape(productionStoreRoot)}\"," +
        "\"userConfigRoot\":\"${ckbTypedEscape(userConfigRoot)}\"}"
    let parsed = parseCkbReproCliPathContextBytes(pathPolicyBytes,
        localRootMapBytes, apiRoutesBytes, text.toArray())
    if (!parsed[0].ok) { return (parsed[0], "") }
    (ckbTypedSuccess(), text)
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
    let fingerprints = value.fingerprints.toArray()
    sort(fingerprints)
    for (fingerprint in fingerprints) {
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
        if (root.size() != 20 || ckbTypedString(root, "schemaVersion") !=
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
        out.observedEnvironmentPath = ckbTypedString(root,
            "observedEnvironmentPath")
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
        "\"observedEnvironmentPath\":\"${ckbTypedEscape(value.observedEnvironmentPath)}\"," +
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
        value.networkNoProxy, value.networkCaFile, value.networkAllowedHosts,
        value.serviceBind]) {
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
        value.vectorRetryCount < 0 || value.retryCount < 0 ||
        value.serviceBind != "127.0.0.1" || value.servicePort <= 0 ||
        value.servicePort > 65535) { return false }
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
        value.observedEnvironmentPath,
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
    var existingParent = path.parent
    while (!exists(existingParent)) {
        let next = existingParent.parent
        if (next.toString() == existingParent.toString()) { return false }
        existingParent = next
    }
    let parent = try { canonicalize(existingParent).toString() }
        catch (_: Exception) { return false }
    parent == existingParent.toString() && value.startsWith("${parent}/")
}

private class CkbTypedP8BFileEvidence {
    var ok: Bool = false
    var identity: String = ""
    var size: Int64 = 0
    var sha256: String = ""
    init() {}
}

private func ckbTypedP8BFileEvidence(path: String,
    expectedHash: String): CkbTypedP8BFileEvidence {
    let out = CkbTypedP8BFileEvidence()
    if (!ckbTypedAbsolutePath(path) || !ckbTypedHash(expectedHash) ||
        !exists(Path(path))) { return out }
    let root = try { canonicalize(Path(path).parent).toString() }
        catch (_: Exception) { return out }
    if (Path(root).join(Path(path).fileName).toString() != path) { return out }
    let backend = CkbReproFilesystemBundleReadBackend()
    var matched: ?CkbReproBundleReadEntry = None
    for (entry in backend.list(root)) {
        if (entry.relativePath == Path(path).fileName) {
            match (matched) {
                case Some(_) => return out
                case None => ()
            }
            matched = Some(entry)
        }
    }
    let expected = match (matched) {
        case Some(value) => value
        case None => return out
    }
    if (expected.kind != "regular" || !expected.withinRoot ||
        expected.canonicalPath != path || expected.identity == "" ||
        expected.size < 1 || expected.size > 512 * 1024 * 1024) { return out }
    let digest = SHA256(); var size: Int64 = 0
    var handle: ?CkbReproBundleReadHandle = None
    try {
        let opened = backend.open(root, expected); handle = Some(opened)
        try {
            if (!opened.noFollow() ||
                !ckbTypedP8BEntryEqual(expected, opened.observedEntry())) {
                return out
            }
            let buffer = Array<UInt8>(65536, repeat: UInt8(0))
            while (true) {
                let count = opened.read(buffer)
                if (count < 0 || count > buffer.size) { return out }
                if (count == 0) { break }
                size += count
                if (size > 512 * 1024 * 1024) { return out }
                digest.write(if (count == buffer.size) { buffer }
                    else { buffer[0..count].clone() })
            }
            if (size != expected.size ||
                !ckbTypedP8BEntryEqual(expected, opened.observedEntry())) {
                return out
            }
        } finally { opened.close(); handle = None }
    } catch (_: Exception) {
        match (handle) {
            case Some(value) => try { value.close() } catch (_: Exception) {}
            case None => ()
        }
        return out
    }
    let builder = StringBuilder()
    let digits = "0123456789abcdef".toRuneArray()
    for (byte in digest.finish()) {
        builder.append(digits[Int64(byte / UInt8(16))])
        builder.append(digits[Int64(byte % UInt8(16))])
    }
    let actualHash = "sha256:${builder.toString()}"
    if (actualHash != expectedHash) { return CkbTypedP8BFileEvidence() }
    let evidence = CkbTypedP8BFileEvidence(); evidence.ok = true
    evidence.identity = expected.identity; evidence.size = expected.size
    evidence.sha256 = actualHash; evidence
}

private func ckbTypedP8BEntryEqual(left: CkbReproBundleReadEntry,
    right: CkbReproBundleReadEntry): Bool {
    left.relativePath == right.relativePath && left.kind == right.kind &&
        left.canonicalPath == right.canonicalPath &&
        left.withinRoot == right.withinRoot &&
        left.identity == right.identity && left.size == right.size
}

private func ckbTypedP8QdrantImageReference(value: String): Bool {
    if (!ckbTypedAscii(value) || value.size < 10 || value.size > 512 ||
        value.contains("@") == false || value.contains("//") ||
        value.contains("..") || value.contains(" ") ||
        value.startsWith("/") || value.endsWith("/")) { return false }
    let parts = value.split("@")
    if (parts.size != 2 || parts[0] == "" || !ckbTypedHash(parts[1]) ||
        parts[0].contains(":latest")) { return false }
    for (rune in parts[0].runes()) {
        if (!((rune >= r'a' && rune <= r'z') ||
            (rune >= r'0' && rune <= r'9') || rune == r'.' ||
            rune == r'/' || rune == r':' || rune == r'_' || rune == r'-')) {
            return false
        }
    }
    true
}

private func ckbTypedP8BLoopbackEndpoint(value: String,
    requiredPath: String): Bool {
    if (!ckbTypedAscii(value) || !value.startsWith("http://") ||
        value.contains("@") ||
        value.contains("?") || value.contains("#") ||
        value.trimAscii() != value || !ckbTypedSafeValue(value, 4096)) {
        return false
    }
    let rest = value[7..]
    let slash = match (rest.indexOf("/")) {
        case Some(index) => index
        case None => rest.size
    }
    let authority = rest[..slash]
    let path = rest[slash..]
    if (path != requiredPath) { return false }
    let colon = match (authority.lastIndexOf(":")) {
        case Some(index) => index
        case None => return false
    }
    let host = authority[..colon]
    let portText = authority[colon + 1..]
    if (host != "127.0.0.1" && host != "[::1]") { return false }
    if (portText == "" || (portText.size > 1 && portText.startsWith("0"))) {
        return false
    }
    for (rune in portText.runes()) {
        if (rune < r'0' || rune > r'9') { return false }
    }
    let port = try { Int64.parse(portText) } catch (_: Exception) { return false }
    port > 0 && port <= 65535
}

private func ckbTypedAscii(value: String): Bool {
    for (rune in value.runes()) {
        if (rune > r'\u{007f}') { return false }
    }
    true
}

private func ckbTypedP8BOrigin(value: String): String {
    let rest = value[7..]
    match (rest.indexOf("/")) {
        case Some(index) => value[..7 + index]
        case None => value
    }
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
