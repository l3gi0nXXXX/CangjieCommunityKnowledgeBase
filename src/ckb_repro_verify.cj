package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashSet}
import std.fs.{Directory, Path, canonicalize, exists}
import std.sort.*

foreign {
    func open(path: CString, flags: Int32): Int32
    func read(fd: Int32, buffer: CPointer<UInt8>, size: UIntNative): IntNative
    func fstat(fd: Int32, stat: CPointer<UInt8>): Int32
    func fcntl(fd: Int32, command: Int32, ...): Int32
    func close(fd: Int32): Int32
    func __error(): CPointer<Int32>
}

public class CkbReproVerifyOptions {
    public var mode: String = ""
    public var workRoot: String = ""
    public var runtimeRoot: String = ""
    public var qdrantRoot: String = ""
    public var sourceRoot: String = ""
    public var candidateRoot: String = ""
    public var repositoryRoot: String = ""
    public var p0ManifestPath: String = ""
    public var p1ScoreContractPath: String = ""
    public var p2LogicalSnapshotPath: String = ""
    public var p3QdrantSnapshotPath: String = ""
    public var p4BuildProofPath: String = ""
    public var p6EnvironmentLockPath: String = ""
    public var p8ReferencePath: String = ""
    public var runCandidateCommit: String = ""
    public var releaseCommit: String = ""
    // There is intentionally no CLI option for a tag in either pre-tag mode.
    public var tag: String = ""
    public init() {}
}

public class CkbReproVerifyOptionsResult {
    public var ok: Bool = false
    public var diagnostic: String = "verify_options_not_parsed"
    public var options: CkbReproVerifyOptions = CkbReproVerifyOptions()
    public init() {}
}

public interface CkbReproVerifyEnvironmentProbe {
    func pathExists(path: String): Bool
    func pathIsEmptyDirectory(path: String): Bool
    func candidateEntryCount(path: String): Int64
    func inspectInput(path: String): CkbReproVerifyInputEvidence
    func canonicalReleaseRepository(): String
    func providerFingerprint(): String
    func modelIdentity(): String
    func staleProcessCount(): Int64
    func privatePathDependencyCount(): Int64
}

public class CkbReproVerifyInputEvidence {
    public var ok: Bool = false
    public var regular: Bool = false
    public var noFollow: Bool = false
    public var stable: Bool = false
    public var size: Int64 = -1
    public var sha256: String = ""
    public var identity: String = ""
    public init() {}
}

public class CkbReproVerifyEnvironmentResult {
    public var ok: Bool = false
    public var startAllowed: Bool = false
    public var diagnostic: String = "verify_environment_not_checked"
    public var heap: CkbServiceHeapPreflightResult =
        CkbServiceHeapPreflightResult()
    public var optionsFingerprint: String = ""
    public var inputEvidenceHash: String = ""
    public var localToctouToken: String = ""
    public var canonicalReleaseRepository: String = ""
    public var providerFingerprint: String = ""
    public var modelIdentity: String = ""
    public let inputRoles = ArrayList<String>()
    public let inputHashes = ArrayList<String>()
    public let inputSizes = ArrayList<Int64>()
    public init() {}
}

public class CkbReproStageEvidence {
    public var ok: Bool = false
    public var diagnostic: String = "stage_not_run"
    public var knowledgeVersion: String = ""
    public var logicalManifestHash: String = ""
    public var vectorProofHash: String = ""
    public var sourceLockHash: String = ""
    public var pathProofHash: String = ""
    public var rawRecords: Int64 = 0
    public var normalizedRecords: Int64 = 0
    public var activeRecords: Int64 = 0
    public var vectorPoints: Int64 = 0
    public var vectorDimension: Int64 = 0
    public var leakageFindings: Int64 = 0
    public var pathFindings: Int64 = 0
    public var retrievalDiff: Int64 = 0
    public var mcpParityDiff: Int64 = 0
    public init() {}
}

public class CkbReproExpectedIdentity {
    public var knowledgeVersion: String = ""
    public var logicalManifestHash: String = ""
    public var vectorProofHash: String = ""
    public var sourceLockHash: String = ""
    public var pathProofHash: String = ""
    public var rawRecords: Int64 = 7818
    public var normalizedRecords: Int64 = 7978
    public var activeRecords: Int64 = 7978
    public var vectorPoints: Int64 = 7978
    public var vectorDimension: Int64 = 1024
    public init() {}
}

public interface CkbReproRunCertificationExecutor {
    func restore(options: CkbReproVerifyOptions): CkbReproStageEvidence
    func rebuild(options: CkbReproVerifyOptions): CkbReproStageEvidence
    func runReference(options: CkbReproVerifyOptions):
        CkbReproReferenceRunEvidence
}

// P8-B deliberately has no provider or Runner method.
public interface CkbReproReleaseVerificationExecutor {
    func restore(options: CkbReproVerifyOptions): CkbReproStageEvidence
    func rebuild(options: CkbReproVerifyOptions): CkbReproStageEvidence
    func verifyPublicEvidence(options: CkbReproVerifyOptions):
        CkbReproContractResult
    func verifyDocumentation(options: CkbReproVerifyOptions):
        CkbReproContractResult
}

public class CkbReproCertifiedRunHashInputs {
    public var logicalProofHash: String = ""
    public var vectorProofHash: String = ""
    public var datasetHash: String = ""
    public var authorityHash: String = ""
    public var environmentHash: String = ""
    public var experimentHash: String = ""
    public var inputEvidenceHash: String = ""
    public var repositoryRoot: String = ""
    public var runCriticalManifest: CkbRunCriticalFilesManifest =
        CkbRunCriticalFilesManifest()
    public init() {}
}

public class CkbReproReferenceRunEvidence {
    public var ok: Bool = false
    public var diagnostic: String = "reference_run_not_run"
    public var totalCases: Int64 = 0
    public var rawPassed: Int64 = 0
    public var strictPassed: Int64 = 0
    public var businessFailed: Int64 = 0
    public var protocolInvalid: Int64 = 0
    public var transportUnresolved: Int64 = 0
    public var resultsHash: String = ""
    public init() {}
}

public class CkbReproTargetScore {
    public var runValid: Bool = false
    public var targetScoreMatched: Bool = false
    public var status: String = "invalid_run"
    public init() {}
}

public class CkbReproRunCertificationResult {
    public var ok: Bool = false
    public var diagnostic: String = "run_certification_not_run"
    public var restored: CkbReproStageEvidence = CkbReproStageEvidence()
    public var rebuilt: CkbReproStageEvidence = CkbReproStageEvidence()
    public var run: CkbReproReferenceRunEvidence =
        CkbReproReferenceRunEvidence()
    public var target: CkbReproTargetScore = CkbReproTargetScore()
    public var certifiedRunInputHash: String = ""
    public var runCriticalTreeHash: String = ""
    public var runnerCalls: Int64 = 0
    public var downstreamCalls: Int64 = 0
    public var referenceManifest: CkbReproReferenceManifest =
        CkbReproReferenceManifest()
    public var referenceValidation: CkbReproContractResult =
        CkbReproContractResult()
    public init() {}
}

public class CkbReproReleaseVerificationResult {
    public var ok: Bool = false
    public var diagnostic: String = "release_verification_not_run"
    public var verifiedReleaseInputSetHash: String = ""
    public var bundleProofSetHash: String = ""
    public var restored: CkbReproStageEvidence = CkbReproStageEvidence()
    public var rebuilt: CkbReproStageEvidence = CkbReproStageEvidence()
    public var publicEvidence: CkbReproContractResult =
        CkbReproContractResult()
    public var documentation: CkbReproContractResult =
        CkbReproContractResult()
    public var runnerCalls: Int64 = 0
    public var releaseCommit: String = ""
    public var certifiedRunInputHash: String = ""
    public var runCriticalTreeHash: String = ""
    public var referenceManifestHash: String = ""
    public var authorityHash: String = ""
    public init() {}
}

public class CkbReproVerifiedReleaseAuthority {
    public var ok: Bool = false
    public var diagnostic: String = "release_authority_not_verified"
    public var authorityHash: String = ""
    public var verifiedInputSetHash: String = ""
    public var proofSetHash: String = ""
    public var referenceManifestHash: String = ""
    public var releaseCommitHash: String = ""
    public var rolesComplete: Bool = false
    public var derivedAssetCount: Int64 = -1
    public init() {}
}

public interface CkbReproReleaseAssetAuthority {
    func validate(loaded: CkbReproBundleLoadResult,
        reference: CkbReproReferenceManifest, releaseCommit: String,
        preflight: CkbReproVerifyEnvironmentResult):
        CkbReproVerifiedReleaseAuthority
}

public class CkbReproReleaseAuthorityEvidence {
    public var role: String = ""
    public var logicalAsset: String = ""
    public var size: Int64 = 0
    public var sha256: String = ""
    public init() {}
}

public class CkbReproReleaseAuthorityContract {
    public let expected = ArrayList<CkbReproReleaseAuthorityEvidence>()
    public var authorityDeliveryMode: String = ""
    public var layoutHash: String = ""
    public init() {}
}

public func buildCkbReproReleaseAuthorityContract(
    inputs: ArrayList<CkbReproReleaseAuthorityEvidence>,
    authorityDeliveryMode: String):
    (CkbReproContractResult, CkbReproReleaseAuthorityContract) {
    let contract = CkbReproReleaseAuthorityContract()
    contract.authorityDeliveryMode = authorityDeliveryMode
    for (source in inputs) {
        let evidence = CkbReproReleaseAuthorityEvidence()
        evidence.role = source.role
        evidence.logicalAsset = source.logicalAsset
        evidence.size = source.size
        evidence.sha256 = source.sha256
        contract.expected.add(evidence)
    }
    contract.layoutHash = p8AuthorityLayoutHash(contract)
    let validation = p8ValidateAuthorityLayout(contract)
    (validation, contract)
}

public class CkbReproCanonicalReleaseAssetAuthority <:
    CkbReproReleaseAssetAuthority {
    private let contract: CkbReproReleaseAuthorityContract
    public init(contract: CkbReproReleaseAuthorityContract) {
        this.contract = contract
    }
    public func validate(loaded: CkbReproBundleLoadResult,
        reference: CkbReproReferenceManifest, releaseCommit: String,
        preflight: CkbReproVerifyEnvironmentResult):
        CkbReproVerifiedReleaseAuthority {
        p8ValidateReleaseAuthority(this.contract, loaded, reference,
            releaseCommit, preflight)
    }
}

public interface CkbReproNativeReadOperation {
    func read(fd: Int32, buffer: Array<UInt8>): Int64
    func errorNumber(): Int32
}

public func ckbReproReadRetryingInterrupt(fd: Int32,
    buffer: Array<UInt8>, operation: CkbReproNativeReadOperation): Int64 {
    while (true) {
        let count = operation.read(fd, buffer)
        if (count >= 0 || operation.errorNumber() != 4) { return count }
    }
    -1
}

private class P8NativeReadOperation <: CkbReproNativeReadOperation {
    public init() {}
    public func read(fd: Int32, buffer: Array<UInt8>): Int64 {
        unsafe {
            let pointer = acquireArrayRawData(buffer)
            let count = read(fd, pointer.pointer, UIntNative(buffer.size))
            releaseArrayRawData(pointer)
            Int64(count)
        }
    }
    public func errorNumber(): Int32 {
        unsafe { __error().read() }
    }
}

public class CkbReproFilesystemBundleReadBackend <:
    CkbReproBundleReadBackend {
    public init() {}
    public func rootExists(root: String): Bool {
        try { canonicalize(Path(root)).toString() == root }
        catch (_: Exception) { false }
    }
    public func rootIdentity(root: String): String {
        if (!this.rootExists(root)) { return "" }
        let fd = p8OpenBundlePath(root)
        if (fd < 0) { return "" }
        let entry = p8DescriptorEntry(fd, root, "")
        _ = unsafe { close(fd) }
        if (entry.kind == "directory") { entry.identity } else { "" }
    }
    public func list(root: String): ArrayList<CkbReproBundleReadEntry> {
        let out = ArrayList<CkbReproBundleReadEntry>()
        if (!this.rootExists(root)) { return out }
        p8ListBundleDirectory(root, Path(root), "", out)
        out
    }
    public func open(root: String, expected: CkbReproBundleReadEntry):
        CkbReproBundleReadHandle {
        if (!this.rootExists(root) ||
            !validateCkbReproBundleRelativePath(expected.relativePath).ok) {
            throw Exception("bundle path invalid")
        }
        P8FilesystemBundleReadHandle(root, expected.relativePath)
    }
}

private class P8FilesystemBundleReadHandle <:
    CkbReproBundleReadHandle {
    private let root: String
    private let relativePath: String
    private let fd: Int32
    private var closed: Bool = false
    public init(root: String, relativePath: String) {
        this.root = root
        this.relativePath = relativePath
        this.fd = p8OpenBundlePath("${root}/${relativePath}")
        if (this.fd < 0) { throw Exception("bundle open failed") }
        let initial = p8DescriptorEntry(this.fd, root, relativePath)
        if (initial.kind != "regular" || !initial.withinRoot) {
            _ = unsafe { close(this.fd) }
            this.closed = true
            throw Exception("bundle entry not regular")
        }
    }
    public func read(buffer: Array<UInt8>): Int64 {
        if (this.closed || buffer.size == 0) { return -1 }
        ckbReproReadRetryingInterrupt(this.fd, buffer,
            P8NativeReadOperation())
    }
    public func observedEntry(): CkbReproBundleReadEntry {
        if (this.closed) { return CkbReproBundleReadEntry() }
        p8DescriptorEntry(this.fd, this.root, this.relativePath)
    }
    public func noFollow(): Bool { !this.closed }
    public func close(): Unit {
        if (!this.closed) {
            this.closed = true
            if (unsafe { close(this.fd) } != 0) {
                throw Exception("bundle close failed")
            }
        }
    }
}

public func parseCkbReproVerifyOptions(args: Array<String>):
    CkbReproVerifyOptionsResult {
    let out = CkbReproVerifyOptionsResult()
    if (args.size == 0 || args.size % 2 != 0) {
        out.diagnostic = "verify_arguments_invalid"
        return out
    }
    let seen = HashSet<String>()
    var index: Int64 = 0
    while (index < args.size) {
        let key = args[index]
        let value = args[index + 1]
        if (seen.contains(key) || value == "") {
            out.diagnostic = "verify_argument_duplicate_or_empty"
            return out
        }
        seen.add(key)
        match (key) {
            case "--mode" => out.options.mode = value
            case "--work-root" => out.options.workRoot = value
            case "--runtime-root" => out.options.runtimeRoot = value
            case "--qdrant-root" => out.options.qdrantRoot = value
            case "--source-root" => out.options.sourceRoot = value
            case "--candidate-root" => out.options.candidateRoot = value
            case "--repository-root" => out.options.repositoryRoot = value
            case "--p0-manifest" => out.options.p0ManifestPath = value
            case "--p1-score-contract" =>
                out.options.p1ScoreContractPath = value
            case "--p2-logical-snapshot" =>
                out.options.p2LogicalSnapshotPath = value
            case "--p3-qdrant-snapshot" =>
                out.options.p3QdrantSnapshotPath = value
            case "--p4-build-proof" => out.options.p4BuildProofPath = value
            case "--p6-environment-lock" =>
                out.options.p6EnvironmentLockPath = value
            case "--p8-reference" => out.options.p8ReferencePath = value
            case "--run-candidate-commit" =>
                out.options.runCandidateCommit = value
            case "--release-commit" => out.options.releaseCommit = value
            case _ =>
                out.diagnostic = "verify_argument_unknown"
                return out
        }
        index += 2
    }
    let structural = p8ValidateOptions(out.options)
    out.ok = structural.ok
    out.diagnostic = structural.diagnostic
    out
}

public func validateCkbReproVerifyEnvironment(
    options: CkbReproVerifyOptions, heapRaw: String,
    probe: CkbReproVerifyEnvironmentProbe):
    CkbReproVerifyEnvironmentResult {
    try {
        p8ValidateEnvironmentUnchecked(options, heapRaw, probe)
    } catch (_: Exception) {
        let out = CkbReproVerifyEnvironmentResult()
        out.diagnostic = "verify_environment_probe_failed"
        out
    }
}

private func p8ValidateEnvironmentUnchecked(
    options: CkbReproVerifyOptions, heapRaw: String,
    probe: CkbReproVerifyEnvironmentProbe):
    CkbReproVerifyEnvironmentResult {
    let out = CkbReproVerifyEnvironmentResult()
    out.heap = ckbServiceHeapPreflight(heapRaw)
    let optionsValidation = p8ValidateOptions(options)
    if (!optionsValidation.ok) {
        out.diagnostic = optionsValidation.diagnostic
        return out
    }
    if (!out.heap.ok) {
        out.diagnostic = out.heap.errorCode
        return out
    }
    for (root in [options.workRoot, options.runtimeRoot,
        options.qdrantRoot, options.sourceRoot]) {
        if (probe.pathExists(root)) {
            out.diagnostic = if (probe.pathIsEmptyDirectory(root)) {
                "verify_root_must_not_exist"
            } else {
                "verify_root_contains_old_state"
            }
            return out
        }
    }
    if (!probe.pathExists(options.candidateRoot)) {
        out.diagnostic = "verify_candidate_missing"
        return out
    }
    if (probe.candidateEntryCount(options.candidateRoot) <= 0) {
        out.diagnostic = "verify_candidate_empty"
        return out
    }
    if (probe.staleProcessCount() != 0) {
        out.diagnostic = "verify_stale_process_detected"
        return out
    }
    if (probe.privatePathDependencyCount() != 0) {
        out.diagnostic = "verify_private_path_dependency"
        return out
    }
    let portableRows = ArrayList<String>()
    let localRows = ArrayList<String>()
    let paths = p8InputPaths(options)
    for (i in 0..paths.size) {
        let path = paths[i]
        let evidence = probe.inspectInput(path)
        if (!evidence.ok || !evidence.regular || !evidence.noFollow ||
            !evidence.stable || evidence.size < 0 ||
            !p8HashValid(evidence.sha256) || evidence.identity == "" ||
            p8HasControl(evidence.identity)) {
            out.diagnostic = "verify_input_evidence_invalid"
            return out
        }
        portableRows.add("${p8InputRole(options, i)}\t" +
            "${evidence.sha256}\t${evidence.size}")
        out.inputRoles.add(p8InputRole(options, i))
        out.inputHashes.add(evidence.sha256)
        out.inputSizes.add(evidence.size)
        localRows.add("${path}\t${evidence.identity}\t" +
            "${evidence.size}\t${evidence.sha256}")
    }
    out.optionsFingerprint = p8OptionsFingerprint(options)
    out.inputEvidenceHash = p8HashParts(
        "ckb-repro-portable-input-content-v1", portableRows.toArray())
    out.localToctouToken = p8HashParts(
        "ckb-repro-local-toctou-v1", localRows.toArray())
    out.canonicalReleaseRepository = probe.canonicalReleaseRepository()
    out.providerFingerprint = probe.providerFingerprint()
    out.modelIdentity = probe.modelIdentity()
    if (out.canonicalReleaseRepository == "" ||
        !p8HashValid(out.providerFingerprint) ||
        out.modelIdentity == "") {
        out.diagnostic = "verify_authority_identity_invalid"
        return out
    }
    out.ok = true
    out.startAllowed = true
    out.diagnostic = "ok"
    out
}

public func verifyRestoredCkbRelease(options: CkbReproVerifyOptions,
    expected: CkbReproExpectedIdentity,
    executor: CkbReproRunCertificationExecutor):
    CkbReproStageEvidence {
    try {
        p8ValidateStage(executor.restore(options), expected, false)
    } catch (_: Exception) {
        p8StageFailure("restore_executor_failed")
    }
}

public func verifyRebuiltCkbRelease(options: CkbReproVerifyOptions,
    expected: CkbReproExpectedIdentity,
    executor: CkbReproRunCertificationExecutor):
    CkbReproStageEvidence {
    try {
        p8ValidateStage(executor.rebuild(options), expected, true)
    } catch (_: Exception) {
        p8StageFailure("rebuild_executor_failed")
    }
}

public func computeCkbCertifiedRunInputHash(
    inputs: CkbReproCertifiedRunHashInputs): String {
    let critical = computeCkbRunCriticalTreeHash(
        inputs.runCriticalManifest, inputs.repositoryRoot)
    if (!p8HashValid(critical)) { return "" }
    for (hash in [inputs.logicalProofHash, inputs.vectorProofHash,
        inputs.datasetHash, inputs.authorityHash, inputs.environmentHash,
        inputs.experimentHash, inputs.inputEvidenceHash]) {
        if (!p8HashValid(hash)) { return "" }
    }
    let parts = [
        "logical=${inputs.logicalProofHash}",
        "vector=${inputs.vectorProofHash}",
        "dataset=${inputs.datasetHash}",
        "authority=${inputs.authorityHash}",
        "environment=${inputs.environmentHash}",
        "experiment=${inputs.experimentHash}",
        "inputEvidence=${inputs.inputEvidenceHash}",
        "runCritical=${critical}"
    ]
    p8HashParts("ckb-certified-run-input-v1", parts)
}

public func classifyCkbReferenceTargetScore(
    evidence: CkbReproReferenceRunEvidence): CkbReproTargetScore {
    let out = CkbReproTargetScore()
    if (!evidence.ok || evidence.totalCases != 164 ||
        evidence.strictPassed < 0 || evidence.strictPassed > 164 ||
        evidence.rawPassed < 0 || evidence.businessFailed < 0 ||
        evidence.protocolInvalid < 0 || evidence.transportUnresolved < 0 ||
        evidence.rawPassed < evidence.strictPassed ||
        evidence.rawPassed > 164 ||
        evidence.businessFailed + evidence.protocolInvalid !=
            164 - evidence.strictPassed ||
        evidence.transportUnresolved != 0 ||
        !p8HashValid(evidence.resultsHash)) {
        return out
    }
    out.runValid = true
    out.targetScoreMatched = evidence.strictPassed == 151
    out.status = if (out.targetScoreMatched) {
        "target_matched"
    } else {
        "score_mismatch_hold"
    }
    out
}

public func runCkbPortableReferenceHumanEval(
    options: CkbReproVerifyOptions, expected: CkbReproExpectedIdentity,
    hashInputs: CkbReproCertifiedRunHashInputs,
    preflight: CkbReproVerifyEnvironmentResult,
    probe: CkbReproVerifyEnvironmentProbe,
    referenceTemplate: CkbReproReferenceManifest,
    executor: CkbReproRunCertificationExecutor):
    CkbReproRunCertificationResult {
    let out = CkbReproRunCertificationResult()
    let start = p8ValidateExecutionStart(options, preflight, "run-certify")
    if (!start.ok) {
        out.diagnostic = start.diagnostic
        return out
    }
    if (hashInputs.repositoryRoot != options.repositoryRoot ||
        hashInputs.logicalProofHash != expected.logicalManifestHash ||
        hashInputs.vectorProofHash != expected.vectorProofHash ||
        hashInputs.inputEvidenceHash != preflight.inputEvidenceHash ||
        !p8ExpectedIdentityValid(expected)) {
        out.diagnostic = "certified_run_input_binding_mismatch"
        return out
    }
    if (referenceTemplate.providerFingerprint !=
        preflight.providerFingerprint ||
        referenceTemplate.model != preflight.modelIdentity ||
        referenceTemplate.knowledgeVersion != expected.knowledgeVersion ||
        referenceTemplate.vectorProofHash != expected.vectorProofHash) {
        out.diagnostic = "reference_template_identity_mismatch"
        return out
    }
    out.runCriticalTreeHash = computeCkbRunCriticalTreeHash(
        hashInputs.runCriticalManifest, hashInputs.repositoryRoot)
    out.certifiedRunInputHash =
        computeCkbCertifiedRunInputHash(hashInputs)
    if (!p8HashValid(out.certifiedRunInputHash)) {
        out.diagnostic = "certified_run_input_invalid"
        return out
    }
    out.restored = verifyRestoredCkbRelease(options, expected, executor)
    if (!out.restored.ok) {
        out.diagnostic = out.restored.diagnostic
        return out
    }
    out.rebuilt = verifyRebuiltCkbRelease(options, expected, executor)
    if (!out.rebuilt.ok) {
        out.diagnostic = out.rebuilt.diagnostic
        return out
    }
    let stable = p8RevalidateInputs(options, preflight, probe)
    if (!stable.ok) {
        out.diagnostic = stable.diagnostic
        return out
    }
    let criticalAfterPreflight = computeCkbRunCriticalTreeHash(
        hashInputs.runCriticalManifest, hashInputs.repositoryRoot)
    if (!p8HashValid(criticalAfterPreflight) ||
        criticalAfterPreflight != out.runCriticalTreeHash) {
        out.diagnostic = "run_critical_identity_drift"
        return out
    }
    out.runnerCalls = 1
    out.run = try { executor.runReference(options) }
        catch (_: Exception) {
            out.diagnostic = "reference_runner_failed"
            return out
        }
    out.target = classifyCkbReferenceTargetScore(out.run)
    if (!out.target.runValid) {
        out.diagnostic = "reference_run_invalid"
        return out
    }
    out.ok = out.target.targetScoreMatched
    out.diagnostic = out.target.status
    if (out.ok) {
        let written = writeCkbPortableReferenceManifest(
            referenceTemplate, out.run, options.runCandidateCommit,
            out.certifiedRunInputHash, out.runCriticalTreeHash)
        out.referenceValidation = written[0]
        out.referenceManifest = written[1]
        if (!out.referenceValidation.ok) {
            out.ok = false
            out.diagnostic = "portable_reference_write_invalid"
        }
    }
    out
}

public func writeCkbPortableReferenceManifest(
    template: CkbReproReferenceManifest,
    run: CkbReproReferenceRunEvidence, runCandidateCommit: String,
    certifiedRunInputHash: String, runCriticalTreeHash: String):
    (CkbReproContractResult, CkbReproReferenceManifest) {
    let manifest = p8CopyReferenceManifest(template)
    manifest.baselineKind = "portable_release"
    manifest.evidenceStatus = "complete"
    manifest.runnerCommit = runCandidateCommit
    manifest.certifiedRunInputHash = certifiedRunInputHash
    manifest.runCriticalTreeHash = runCriticalTreeHash
    manifest.resultsHash = run.resultsHash
    manifest.totalCases = run.totalCases
    manifest.rawPassed = run.rawPassed
    manifest.strictPassed = run.strictPassed
    manifest.strictFailed = run.totalCases - run.strictPassed
    manifest.businessFailed = run.businessFailed
    manifest.protocolInvalid = run.protocolInvalid
    manifest.transportUnresolved = run.transportUnresolved
    manifest.missingEvidence.clear()
    let validation = validateCkbReproReferenceManifest(
        manifest, mode: "execution")
    (validation, manifest)
}

public func computeCkbVerifiedReleaseInputSetHash(
    bundle: CkbReproBundleManifest): String {
    computeCkbReproBundleInputSetHash(bundle.assets)
}

public func verifyCkbUnsignedReleaseCandidate(
    options: CkbReproVerifyOptions, expected: CkbReproExpectedIdentity,
    reference: CkbReproReferenceManifest,
    expectedInputSetHash: String, expectedCertifiedRunInputHash: String,
    canonicalReleaseRepository: String,
    runCriticalManifest: CkbRunCriticalFilesManifest,
    authorityValidator: CkbReproReleaseAssetAuthority,
    preflight: CkbReproVerifyEnvironmentResult,
    probe: CkbReproVerifyEnvironmentProbe,
    backend: CkbReproBundleReadBackend,
    executor: CkbReproReleaseVerificationExecutor):
    CkbReproReleaseVerificationResult {
    let out = CkbReproReleaseVerificationResult()
    let start = p8ValidateExecutionStart(
        options, preflight, "release-verify")
    if (!start.ok) {
        out.diagnostic = start.diagnostic
        return out
    }
    if (!p8HashValid(expectedInputSetHash) ||
        !p8HashValid(expectedCertifiedRunInputHash)) {
        out.diagnostic = "release_expected_hash_invalid"
        return out
    }
    let referenceValidation = validateCkbReproReferenceManifest(
        reference, mode: "execution")
    if (!referenceValidation.ok || reference.baselineKind !=
        "portable_release" || reference.strictPassed != 151 ||
        reference.knowledgeVersion != expected.knowledgeVersion ||
        reference.vectorProofHash != expected.vectorProofHash ||
        !p8CommitValid(reference.runnerCommit) ||
        !p8HashValid(reference.certifiedRunInputHash) ||
        reference.certifiedRunInputHash != expectedCertifiedRunInputHash ||
        !p8HashValid(reference.runCriticalTreeHash)) {
        out.diagnostic = "portable_reference_invalid"
        return out
    }
    out.releaseCommit = options.releaseCommit
    out.certifiedRunInputHash = reference.certifiedRunInputHash
    out.runCriticalTreeHash = reference.runCriticalTreeHash
    out.referenceManifestHash = referenceValidation.manifestHash
    if (
        canonicalReleaseRepository !=
            preflight.canonicalReleaseRepository ||
        normalizeCkbReproRepositoryRemote(reference.observedRemote) !=
            canonicalReleaseRepository ||
        reference.releaseRepository != canonicalReleaseRepository) {
        out.diagnostic = "release_repository_mismatch"
        return out
    }
    let loaded = validateCkbReproBundleManifest(
        options.candidateRoot, backend)
    if (!loaded.contract.ok) {
        out.diagnostic = loaded.contract.diagnostic
        return out
    }
    out.verifiedReleaseInputSetHash =
        computeCkbVerifiedReleaseInputSetHash(loaded.manifest)
    out.bundleProofSetHash = loaded.proofSetHash
    if (out.verifiedReleaseInputSetHash != expectedInputSetHash) {
        out.diagnostic = "verified_release_input_changed"
        return out
    }
    let authority = try {
        authorityValidator.validate(
            loaded, reference, options.releaseCommit, preflight)
    } catch (_: Exception) {
        out.diagnostic = "release_asset_authority_failed"
        return out
    }
    if (!authority.ok || !p8HashValid(authority.authorityHash) ||
        !authority.rolesComplete || authority.derivedAssetCount != 0 ||
        authority.verifiedInputSetHash != expectedInputSetHash ||
        authority.proofSetHash != loaded.proofSetHash ||
        authority.referenceManifestHash != referenceValidation.manifestHash ||
        authority.releaseCommitHash !=
            ckbReproBundleHash(options.releaseCommit.toArray())) {
        out.diagnostic = "release_asset_authority_invalid"
        return out
    }
    out.authorityHash = authority.authorityHash
    let stable = p8RevalidateInputs(options, preflight, probe)
    if (!stable.ok) {
        out.diagnostic = stable.diagnostic
        return out
    }
    let actualCritical = computeCkbRunCriticalTreeHash(
        runCriticalManifest, options.repositoryRoot)
    if (!p8HashValid(actualCritical) ||
        actualCritical != reference.runCriticalTreeHash) {
        out.diagnostic = "run_critical_changed_rerun_a"
        return out
    }
    let bundleStableBeforeRestore = p8RevalidateBundle(
        options.candidateRoot, expectedInputSetHash, loaded.proofSetHash,
        loaded.rootIdentity, backend)
    if (!bundleStableBeforeRestore.ok) {
        out.diagnostic = bundleStableBeforeRestore.diagnostic
        return out
    }
    out.restored = try {
        p8ValidateStage(executor.restore(options), expected, false)
    } catch (_: Exception) { p8StageFailure("restore_executor_failed") }
    if (!out.restored.ok) {
        out.diagnostic = out.restored.diagnostic
        return out
    }
    let bundleStableAfterRestore = p8RevalidateBundle(
        options.candidateRoot, expectedInputSetHash, loaded.proofSetHash,
        loaded.rootIdentity, backend)
    if (!bundleStableAfterRestore.ok) {
        out.diagnostic = bundleStableAfterRestore.diagnostic
        return out
    }
    out.rebuilt = try {
        p8ValidateStage(executor.rebuild(options), expected, true)
    } catch (_: Exception) { p8StageFailure("rebuild_executor_failed") }
    if (!out.rebuilt.ok) {
        out.diagnostic = out.rebuilt.diagnostic
        return out
    }
    let bundleStableAfterRebuild = p8RevalidateBundle(
        options.candidateRoot, expectedInputSetHash, loaded.proofSetHash,
        loaded.rootIdentity, backend)
    if (!bundleStableAfterRebuild.ok) {
        out.diagnostic = bundleStableAfterRebuild.diagnostic
        return out
    }
    out.publicEvidence = try { executor.verifyPublicEvidence(options) }
        catch (_: Exception) {
            p8Failure("public_evidence_executor_failed")
        }
    if (!out.publicEvidence.ok) {
        out.diagnostic = out.publicEvidence.diagnostic
        return out
    }
    let bundleStableAfterEvidence = p8RevalidateBundle(
        options.candidateRoot, expectedInputSetHash, loaded.proofSetHash,
        loaded.rootIdentity, backend)
    if (!bundleStableAfterEvidence.ok) {
        out.diagnostic = bundleStableAfterEvidence.diagnostic
        return out
    }
    out.documentation = try { executor.verifyDocumentation(options) }
        catch (_: Exception) {
            p8Failure("documentation_executor_failed")
        }
    if (!out.documentation.ok) {
        out.diagnostic = out.documentation.diagnostic
        return out
    }
    let bundleStableAfterDocs = p8RevalidateBundle(
        options.candidateRoot, expectedInputSetHash, loaded.proofSetHash,
        loaded.rootIdentity, backend)
    if (!bundleStableAfterDocs.ok) {
        out.diagnostic = bundleStableAfterDocs.diagnostic
        return out
    }
    out.ok = true
    out.diagnostic = "verified"
    out
}

public func renderCkbReproVerificationReport(
    result: CkbReproReleaseVerificationResult): String {
    "{\"schemaVersion\":\"ckb-repro-verification-report-v1\"," +
        "\"ok\":${result.ok}," +
        "\"diagnostic\":\"${p8Json(result.diagnostic)}\"," +
        "\"verifiedReleaseInputSetHash\":\"" +
        "${p8Json(result.verifiedReleaseInputSetHash)}\"," +
        "\"bundleProofSetHash\":\"${p8Json(result.bundleProofSetHash)}\"," +
        "\"releaseCommit\":\"${p8Json(result.releaseCommit)}\"," +
        "\"certifiedRunInputHash\":\"" +
        "${p8Json(result.certifiedRunInputHash)}\"," +
        "\"runCriticalTreeHash\":\"" +
        "${p8Json(result.runCriticalTreeHash)}\"," +
        "\"referenceManifestHash\":\"" +
        "${p8Json(result.referenceManifestHash)}\"," +
        "\"authorityHash\":\"${p8Json(result.authorityHash)}\"," +
        "\"restoreOk\":${result.restored.ok}," +
        "\"restoreDiagnostic\":\"" +
        "${p8Json(result.restored.diagnostic)}\"," +
        "\"rebuildOk\":${result.rebuilt.ok}," +
        "\"rebuildDiagnostic\":\"" +
        "${p8Json(result.rebuilt.diagnostic)}\"," +
        "\"publicEvidenceOk\":${result.publicEvidence.ok}," +
        "\"publicEvidenceDiagnostic\":\"" +
        "${p8Json(result.publicEvidence.diagnostic)}\"," +
        "\"documentationOk\":${result.documentation.ok}," +
        "\"documentationDiagnostic\":\"" +
        "${p8Json(result.documentation.diagnostic)}\"," +
        "\"runnerCalls\":${result.runnerCalls}}"
}

private func p8ValidateOptions(options: CkbReproVerifyOptions):
    CkbReproContractResult {
    if (options.mode != "run-certify" &&
        options.mode != "release-verify") {
        return p8Failure("verify_mode_invalid")
    }
    let roots = [options.workRoot, options.runtimeRoot,
        options.qdrantRoot, options.sourceRoot, options.candidateRoot,
        options.repositoryRoot]
    for (root in roots) {
        if (!p8AbsoluteRoot(root)) {
            return p8Failure("verify_root_invalid")
        }
    }
    for (i in 0..roots.size) {
        for (j in i + 1..roots.size) {
            if (p8RootsOverlap(roots[i], roots[j])) {
                return p8Failure("verify_roots_overlap")
            }
        }
    }
    for (path in [options.p0ManifestPath, options.p1ScoreContractPath,
        options.p2LogicalSnapshotPath, options.p3QdrantSnapshotPath,
        options.p4BuildProofPath, options.p6EnvironmentLockPath]) {
        if (!p8AbsoluteFile(path)) {
            return p8Failure("verify_input_path_invalid")
        }
    }
    if (options.mode == "release-verify" &&
        !p8AbsoluteFile(options.p8ReferencePath)) {
        return p8Failure("verify_reference_path_invalid")
    }
    if (options.mode == "run-certify") {
        if (!p8CommitValid(options.runCandidateCommit) ||
            options.releaseCommit != "" || options.p8ReferencePath != "") {
            return p8Failure("run_candidate_commit_invalid")
        }
    } else if (!p8CommitValid(options.releaseCommit) ||
        options.runCandidateCommit != "") {
        return p8Failure("release_commit_invalid")
    }
    if (options.tag != "") { return p8Failure("verify_tag_forbidden") }
    p8Success()
}

private func p8InputPaths(options: CkbReproVerifyOptions): Array<String> {
    let paths = ArrayList<String>()
    for (path in [options.p0ManifestPath, options.p1ScoreContractPath,
        options.p2LogicalSnapshotPath, options.p3QdrantSnapshotPath,
        options.p4BuildProofPath, options.p6EnvironmentLockPath]) {
        paths.add(path)
    }
    if (options.mode == "release-verify") {
        paths.add(options.p8ReferencePath)
    }
    paths.toArray()
}

private func p8InputRole(options: CkbReproVerifyOptions, index: Int64):
    String {
    let roles = ["p0_manifest", "p1_score_contract",
        "p2_logical_snapshot", "p3_qdrant_snapshot", "p4_build_proof",
        "p6_environment_lock", "p8_reference"]
    if (index < 0 || index >= roles.size) { return "" }
    roles[index]
}

private func p8RevalidateInputs(options: CkbReproVerifyOptions,
    preflight: CkbReproVerifyEnvironmentResult,
    probe: CkbReproVerifyEnvironmentProbe): CkbReproContractResult {
    let portableRows = ArrayList<String>()
    let localRows = ArrayList<String>()
    try {
        let optionsValidation = p8ValidateOptions(options)
        if (!optionsValidation.ok ||
            p8OptionsFingerprint(options) != preflight.optionsFingerprint) {
            return p8Failure("verify_options_identity_drift")
        }
        if (probe.staleProcessCount() != 0) {
            return p8Failure("verify_stale_process_detected")
        }
        if (probe.privatePathDependencyCount() != 0) {
            return p8Failure("verify_private_path_dependency")
        }
        if (probe.canonicalReleaseRepository() !=
            preflight.canonicalReleaseRepository ||
            probe.providerFingerprint() != preflight.providerFingerprint ||
            probe.modelIdentity() != preflight.modelIdentity) {
            return p8Failure("verify_authority_identity_drift")
        }
        let paths = p8InputPaths(options)
        for (i in 0..paths.size) {
            let evidence = probe.inspectInput(paths[i])
            if (!evidence.ok || !evidence.regular || !evidence.noFollow ||
                !evidence.stable || evidence.size < 0 ||
                !p8HashValid(evidence.sha256) ||
                evidence.identity == "") {
                return p8Failure("verify_input_evidence_invalid")
            }
            portableRows.add("${p8InputRole(options, i)}\t" +
                "${evidence.sha256}\t${evidence.size}")
            localRows.add("${paths[i]}\t${evidence.identity}\t" +
                "${evidence.size}\t${evidence.sha256}")
        }
    } catch (_: Exception) {
        return p8Failure("verify_environment_probe_failed")
    }
    if (p8HashParts("ckb-repro-portable-input-content-v1",
        portableRows.toArray()) != preflight.inputEvidenceHash ||
        p8HashParts("ckb-repro-local-toctou-v1",
        localRows.toArray()) != preflight.localToctouToken) {
        return p8Failure("verify_input_identity_drift")
    }
    p8Success()
}

private func p8RevalidateBundle(root: String, expectedInputSetHash: String,
    expectedProofSetHash: String, expectedRootIdentity: String,
    backend: CkbReproBundleReadBackend): CkbReproContractResult {
    let loaded = validateCkbReproBundleManifest(root, backend)
    if (!loaded.contract.ok || loaded.rootIdentity != expectedRootIdentity ||
        loaded.proofSetHash != expectedProofSetHash ||
        computeCkbVerifiedReleaseInputSetHash(loaded.manifest) !=
            expectedInputSetHash) {
        return p8Failure("bundle_revalidation_failed")
    }
    p8Success()
}

private func p8OptionsFingerprint(options: CkbReproVerifyOptions): String {
    p8HashParts("ckb-repro-verify-options-v1", [
        options.mode, options.workRoot, options.runtimeRoot,
        options.qdrantRoot, options.sourceRoot, options.candidateRoot,
        options.repositoryRoot, options.p0ManifestPath,
        options.p1ScoreContractPath, options.p2LogicalSnapshotPath,
        options.p3QdrantSnapshotPath, options.p4BuildProofPath,
        options.p6EnvironmentLockPath, options.p8ReferencePath,
        options.runCandidateCommit, options.releaseCommit
    ])
}

private func p8ValidateExecutionStart(options: CkbReproVerifyOptions,
    preflight: CkbReproVerifyEnvironmentResult,
    requiredMode: String): CkbReproContractResult {
    let optionsResult = p8ValidateOptions(options)
    if (!optionsResult.ok) { return optionsResult }
    if (options.mode != requiredMode) {
        return p8Failure("verify_state_mode_invalid")
    }
    if (!preflight.ok || !preflight.startAllowed ||
        preflight.optionsFingerprint != p8OptionsFingerprint(options) ||
        !p8HashValid(preflight.inputEvidenceHash)) {
        return p8Failure("verify_preflight_required")
    }
    p8Success()
}

private func p8StageFailure(diagnostic: String): CkbReproStageEvidence {
    let out = CkbReproStageEvidence()
    out.diagnostic = diagnostic
    out
}

private func p8ExpectedIdentityValid(
    expected: CkbReproExpectedIdentity): Bool {
    expected.knowledgeVersion != "" &&
        p8HashValid(expected.logicalManifestHash) &&
        p8HashValid(expected.vectorProofHash) &&
        p8HashValid(expected.sourceLockHash) &&
        p8HashValid(expected.pathProofHash) &&
        expected.rawRecords >= 0 && expected.normalizedRecords >= 0 &&
        expected.activeRecords >= 0 && expected.vectorPoints >= 0 &&
        expected.vectorDimension > 0
}

private func p8ValidateStage(stage: CkbReproStageEvidence,
    expected: CkbReproExpectedIdentity,
    requireSourceProof: Bool): CkbReproStageEvidence {
    if (!stage.ok) { return stage }
    if (stage.knowledgeVersion != expected.knowledgeVersion ||
        stage.logicalManifestHash != expected.logicalManifestHash ||
        stage.vectorProofHash != expected.vectorProofHash ||
        stage.rawRecords != expected.rawRecords ||
        stage.normalizedRecords != expected.normalizedRecords ||
        stage.activeRecords != expected.activeRecords ||
        stage.vectorPoints != expected.vectorPoints ||
        stage.vectorDimension != expected.vectorDimension) {
        stage.ok = false
        stage.diagnostic = "portable_identity_mismatch"
        return stage
    }
    if (stage.leakageFindings != 0 || stage.pathFindings != 0) {
        stage.ok = false
        stage.diagnostic = "portable_knowledge_findings"
        return stage
    }
    if (stage.retrievalDiff != 0 || stage.mcpParityDiff != 0) {
        stage.ok = false
        stage.diagnostic = "portable_retrieval_parity_mismatch"
        return stage
    }
    if (requireSourceProof &&
        (stage.sourceLockHash != expected.sourceLockHash ||
        stage.pathProofHash != expected.pathProofHash)) {
        stage.ok = false
        stage.diagnostic = "portable_rebuild_proof_mismatch"
        return stage
    }
    stage.diagnostic = "ok"
    stage
}

private func p8CopyReferenceManifest(source: CkbReproReferenceManifest):
    CkbReproReferenceManifest {
    let parsed = parseCkbReproReferenceManifest(
        renderCkbReproReferenceManifest(source).toArray())
    if (parsed[0].ok) { parsed[1] } else { CkbReproReferenceManifest() }
}

private func p8AuthorityFailure(diagnostic: String):
    CkbReproVerifiedReleaseAuthority {
    let out = CkbReproVerifiedReleaseAuthority()
    out.diagnostic = diagnostic
    out
}

private func p8OpenBundlePath(path: String): Int32 {
    let cpath = unsafe { LibC.mallocCString(path) }
    let fd = unsafe { open(cpath, 0x104) }
    unsafe { LibC.free(cpath) }
    fd
}

private func p8DescriptorEntry(fd: Int32, root: String,
    relativePath: String): CkbReproBundleReadEntry {
    let out = CkbReproBundleReadEntry()
    out.relativePath = relativePath
    let stat = Array<UInt8>(144, repeat: UInt8(0))
    let pathBytes = Array<UInt8>(1024, repeat: UInt8(0))
    var statOk = false
    var pathOk = false
    unsafe {
        let statPointer = acquireArrayRawData(stat)
        statOk = fstat(fd, statPointer.pointer) == 0
        releaseArrayRawData(statPointer)
        let pathPointer = acquireArrayRawData(pathBytes)
        pathOk = fcntl(fd, 50, pathPointer.pointer) == 0
        releaseArrayRawData(pathPointer)
    }
    if (!statOk || !pathOk) { return out }
    let mode = p8LittleEndian(stat, 4, 2)
    if ((mode & UInt64(0xf000)) == UInt64(0x8000)) {
        out.kind = "regular"
    } else if ((mode & UInt64(0xf000)) == UInt64(0x4000)) {
        out.kind = "directory"
    } else { out.kind = "special" }
    if (out.kind == "regular" && p8LittleEndian(stat, 6, 2) != UInt64(1)) {
        out.kind = "special"
    }
    let sizeBits = p8LittleEndian(stat, 96, 8)
    if ((sizeBits & (UInt64(1) << 63)) != 0) { return out }
    out.size = Int64(sizeBits)
    let chars = ArrayList<UInt8>()
    for (byte in pathBytes) {
        if (byte == UInt8(0)) { break }
        chars.add(byte)
    }
    out.canonicalPath = try { String.fromUtf8(chars.toArray()) }
        catch (_: Exception) { "" }
    out.withinRoot = out.canonicalPath == "${root}/${relativePath}"
    out.identity = "dev=${p8LittleEndian(stat, 0, 4)};" +
        "ino=${p8LittleEndian(stat, 8, 8)};size=${out.size};" +
        "mtime=${p8LittleEndian(stat, 48, 8)}:" +
        "${p8LittleEndian(stat, 56, 8)};" +
        "ctime=${p8LittleEndian(stat, 64, 8)}:" +
        "${p8LittleEndian(stat, 72, 8)}"
    out
}

private func p8LittleEndian(bytes: Array<UInt8>, offset: Int64,
    count: Int64): UInt64 {
    var value: UInt64 = 0
    for (i in 0..count) {
        value |= UInt64(bytes[offset + i]) << UInt64(i * 8)
    }
    value
}

private func p8ListBundleDirectory(root: String, directory: Path,
    prefix: String, out: ArrayList<CkbReproBundleReadEntry>): Unit {
    for (entry in Directory.readFrom(directory)) {
        let relative = if (prefix == "") { entry.name }
            else { "${prefix}/${entry.name}" }
        let path = validateCkbReproBundleRelativePath(relative)
        if (!path.ok) {
            let unsafeEntry = CkbReproBundleReadEntry()
            unsafeEntry.relativePath = relative
            unsafeEntry.kind = "special"
            out.add(unsafeEntry)
            continue
        }
        let fd = p8OpenBundlePath(entry.path.toString())
        if (fd < 0) {
            let unsafeEntry = CkbReproBundleReadEntry()
            unsafeEntry.relativePath = relative
            unsafeEntry.kind = "special"
            unsafeEntry.canonicalPath = "${root}/${relative}"
            out.add(unsafeEntry)
            continue
        }
        let observed = p8DescriptorEntry(fd, root, relative)
        _ = unsafe { close(fd) }
        out.add(observed)
        if (observed.kind == "directory" && observed.withinRoot) {
            p8ListBundleDirectory(root, entry.path, relative, out)
        }
    }
}

private func p8ValidateReleaseAuthority(
    contract: CkbReproReleaseAuthorityContract,
    loaded: CkbReproBundleLoadResult,
    reference: CkbReproReferenceManifest, releaseCommit: String,
    preflight: CkbReproVerifyEnvironmentResult):
    CkbReproVerifiedReleaseAuthority {
    let layout = p8ValidateAuthorityLayout(contract)
    if (!layout.ok) {
        return p8AuthorityFailure(layout.diagnostic)
    }
    if (!loaded.contract.ok || !p8HashValid(loaded.proofSetHash) ||
        !p8HashValid(loaded.manifest.inputSetHash)) {
        return p8AuthorityFailure("release_authority_bundle_invalid")
    }
    let mandatory = ["p0_manifest", "p1_score_contract",
        "p2_logical_snapshot", "p3_qdrant_snapshot", "p4_build_proof",
        "p5_public_evidence", "p6_environment_lock", "p7_documentation",
        "p8_reference", "source_lock", "authority_delivery",
        "portable_report", "license", "release_commit"]
    for (role in mandatory) {
        var count: Int64 = 0
        for (expected in contract.expected) {
            if (expected.role == role) { count += 1 }
        }
        let exactlyOne = role == "p8_reference" ||
            role == "release_commit"
        if (count == 0 || (exactlyOne && count != 1)) {
            return p8AuthorityFailure("release_authority_role_missing")
        }
    }
    let loadedGroups = HashSet<String>()
    for (asset in loaded.manifest.assets) {
        loadedGroups.add(asset.role + "\t" + asset.logicalAsset + "\t" +
            "${asset.logicalSize}\t${asset.logicalSha256}")
    }
    if (contract.expected.size != loadedGroups.size) {
        return p8AuthorityFailure("release_authority_contract_mismatch")
    }
    let contractKeys = HashSet<String>()
    let authorityRows = ArrayList<String>()
    for (expected in contract.expected) {
        let key = expected.role + "\t" + expected.logicalAsset
        if (contractKeys.contains(key) || expected.size < 0 ||
            !p8HashValid(expected.sha256)) {
            return p8AuthorityFailure("release_authority_contract_mismatch")
        }
        contractKeys.add(key)
        var matched = false
        for (asset in loaded.manifest.assets) {
            if (asset.role == expected.role &&
                asset.logicalAsset == expected.logicalAsset &&
                asset.logicalSize == expected.size &&
                asset.logicalSha256 == expected.sha256) { matched = true }
        }
        if (!matched) {
            return p8AuthorityFailure("release_authority_contract_mismatch")
        }
        authorityRows.add(key + "\t${expected.size}\t${expected.sha256}")
    }
    let requiredPreflight = HashSet<String>()
    for (role in ["p0_manifest", "p1_score_contract",
        "p2_logical_snapshot", "p3_qdrant_snapshot", "p4_build_proof",
        "p6_environment_lock", "p8_reference"]) {
        requiredPreflight.add(role)
    }
    let seenPreflight = HashSet<String>()
    for (i in 0..preflight.inputRoles.size) {
        if (i >= preflight.inputHashes.size || i >= preflight.inputSizes.size) {
            return p8AuthorityFailure("release_authority_preflight_mismatch")
        }
        if (!requiredPreflight.contains(preflight.inputRoles[i]) ||
            seenPreflight.contains(preflight.inputRoles[i])) {
            return p8AuthorityFailure("release_authority_preflight_mismatch")
        }
        seenPreflight.add(preflight.inputRoles[i])
        var matched = false
        for (expected in contract.expected) {
            if (p8AuthorityPreflightRole(expected.logicalAsset) ==
                    preflight.inputRoles[i] &&
                expected.sha256 == preflight.inputHashes[i] &&
                expected.size == preflight.inputSizes[i]) { matched = true }
        }
        if (!matched) {
            return p8AuthorityFailure("release_authority_preflight_mismatch")
        }
    }
    if (preflight.inputRoles.size != 7 ||
        preflight.inputHashes.size != 7 || preflight.inputSizes.size != 7 ||
        seenPreflight.size != requiredPreflight.size) {
        return p8AuthorityFailure("release_authority_preflight_mismatch")
    }
    let referenceValidation = validateCkbReproReferenceManifest(reference)
    if (!referenceValidation.ok) {
        return p8AuthorityFailure("release_authority_reference_mismatch")
    }
    var referenceMatched = false
    var commitMatched = false
    for (expected in contract.expected) {
        if (expected.role == "p8_reference" &&
            expected.sha256 == referenceValidation.manifestHash &&
            expected.size == referenceValidation.canonicalJson.toArray().size) {
            referenceMatched = true
        }
        if (expected.role == "release_commit" &&
            expected.sha256 == ckbReproBundleHash(releaseCommit.toArray()) &&
            expected.size == releaseCommit.toArray().size) {
            commitMatched = true
        }
    }
    if (!referenceMatched) {
        return p8AuthorityFailure("release_authority_reference_mismatch")
    }
    if (!p8CommitValid(releaseCommit) || !commitMatched) {
        return p8AuthorityFailure("release_authority_commit_mismatch")
    }
    let ordered = authorityRows.toArray()
    sort(ordered)
    let out = CkbReproVerifiedReleaseAuthority()
    out.ok = true
    out.diagnostic = "ok"
    out.verifiedInputSetHash = loaded.manifest.inputSetHash
    out.proofSetHash = loaded.proofSetHash
    out.referenceManifestHash = referenceValidation.manifestHash
    out.releaseCommitHash = ckbReproBundleHash(releaseCommit.toArray())
    out.authorityHash = p8HashParts("ckb-repro-release-authority-v1",
        [out.verifiedInputSetHash, out.proofSetHash,
        out.referenceManifestHash, out.releaseCommitHash,
        p8HashParts("ckb-repro-release-authority-contract-v1", ordered)])
    out.rolesComplete = true
    out.derivedAssetCount = 0
    out
}

private func p8AuthorityPreflightRole(logicalAsset: String): String {
    match (logicalAsset) {
        case "reproducibility/manifests/historical-reference-run.json" =>
            "p0_manifest"
        case "reproducibility/PUBLIC-EVIDENCE.schema.json" =>
            "p1_score_contract"
        case "ckb-logical-snapshot.tar.zst" => "p2_logical_snapshot"
        case "qdrant-collection.snapshot" => "p3_qdrant_snapshot"
        case "portable-logical-proof.json" => "p4_build_proof"
        case "reproducibility/manifests/environment-lock.json" =>
            "p6_environment_lock"
        case "reproducibility/manifests/reference-run.json" =>
            "p8_reference"
        case _ => ""
    }
}

private func p8AuthorityRequiredLayout(mode: String):
    ArrayList<(String, String)> {
    let out = ArrayList<(String, String)>()
    for (row in [
        ("README.md", "p7_documentation"),
        ("docs/reproducibility/README.md", "p7_documentation"),
        ("docs/reproducibility/quick-start.md", "p7_documentation"),
        ("docs/reproducibility/restore-knowledge-base.md", "p7_documentation"),
        ("docs/reproducibility/rebuild-from-source.md", "p7_documentation"),
        ("docs/reproducibility/configure-claude-glm.md", "p7_documentation"),
        ("docs/reproducibility/run-humaneval-164.md", "p7_documentation"),
        ("docs/reproducibility/verify-strict-pass-at-1.md", "p7_documentation"),
        ("docs/reproducibility/result-interpretation.md", "p7_documentation"),
        ("docs/reproducibility/troubleshooting.md", "p7_documentation"),
        ("docs/reproducibility/release-maintainer-runbook.md", "p7_documentation"),
        ("docs/service-http-operations.md", "p7_documentation"),
        ("reproducibility/PUBLIC-EVIDENCE.schema.json", "p1_score_contract"),
        ("reproducibility/RELEASE-MANIFEST.schema.json", "p0_manifest"),
        ("reproducibility/authority-source-materials.schema.json", "authority_delivery"),
        ("reproducibility/source-lock.schema.json", "source_lock"),
        ("reproducibility/source-inventory.schema.json", "source_lock"),
        ("reproducibility/knowledge-selection.schema.json", "p0_manifest"),
        ("reproducibility/authority-delivery.schema.json", "authority_delivery"),
        ("reproducibility/environment-lock.schema.json", "p6_environment_lock"),
        ("reproducibility/historical-reference-evidence.schema.json", "p0_manifest"),
        ("reproducibility/reference-run.schema.json", "p0_manifest"),
        ("reproducibility/portable-path-policy.schema.json", "portable_report"),
        ("reproducibility/run-critical-files.schema.json", "p4_build_proof"),
        ("reproducibility/RELEASE-SIGNING-KEY.asc", "p0_manifest"),
        ("reproducibility/configs/provider.example.env", "p6_environment_lock"),
        ("reproducibility/configs/ckb.example.conf", "p6_environment_lock"),
        ("reproducibility/configs/claude-mcp.example.json", "p6_environment_lock"),
        ("reproducibility/configs/experiment-profile.json", "p1_score_contract"),
        ("reproducibility/manifests/source-lock.json", "source_lock"),
        ("reproducibility/manifests/source-inventory.jsonl", "source_lock"),
        ("reproducibility/manifests/portable-path-policy.json", "portable_report"),
        ("reproducibility/manifests/run-critical-files.json", "p4_build_proof"),
        ("reproducibility/manifests/knowledge-selection.jsonl", "p0_manifest"),
        ("reproducibility/manifests/environment-lock.json", "p6_environment_lock"),
        ("reproducibility/manifests/authority-delivery.json", "authority_delivery"),
        ("reproducibility/manifests/authority-source-materials.json", "authority_delivery"),
        ("reproducibility/manifests/historical-reference-evidence.json", "p0_manifest"),
        ("reproducibility/manifests/historical-reference-run.json", "p0_manifest"),
        ("reproducibility/manifests/reference-run.json", "p8_reference"),
        ("reproducibility/licenses/THIRD_PARTY_NOTICES.md", "license"),
        ("ckb-logical-snapshot.tar.zst", "p2_logical_snapshot"),
        ("qdrant-collection.snapshot", "p3_qdrant_snapshot"),
        ("portable-logical-proof.json", "p4_build_proof"),
        ("source-materials-manifest.json", "source_lock"),
        ("ckb-public-reference-evidence.tar.zst", "p5_public_evidence"),
        ("leakage-report.json", "portable_report"),
        ("portable-path-report.json", "portable_report"),
        ("retrieval-parity.json", "portable_report"),
        ("release/release-commit.txt", "release_commit")]) { out.add(row) }
    if (mode == "bundled") {
        out.add(("cangjie-humaneval-authority.tar.zst",
            "authority_delivery"))
    } else if (mode == "public_rebuild") {
        out.add(("authority-source-materials.json", "authority_delivery"))
    }
    out
}

private func p8AuthorityLayoutHash(
    contract: CkbReproReleaseAuthorityContract): String {
    let rows = ArrayList<String>()
    for (evidence in contract.expected) {
        rows.add("${evidence.role}\t${evidence.logicalAsset}\t" +
            "${evidence.size}\t${evidence.sha256}")
    }
    let ordered = rows.toArray()
    sort(ordered)
    p8HashParts("ckb-repro-release-authority-layout-v1",
        [contract.authorityDeliveryMode,
        p8HashParts("ckb-repro-release-authority-layout-rows-v1", ordered)])
}

private func p8ValidateAuthorityLayout(
    contract: CkbReproReleaseAuthorityContract): CkbReproContractResult {
    if (contract.authorityDeliveryMode != "bundled" &&
        contract.authorityDeliveryMode != "public_rebuild") {
        return p8Failure("release_authority_delivery_mode_invalid")
    }
    if (contract.layoutHash == "" ||
        contract.layoutHash != p8AuthorityLayoutHash(contract)) {
        return p8Failure("release_authority_contract_mismatch")
    }
    let required = p8AuthorityRequiredLayout(contract.authorityDeliveryMode)
    if (contract.expected.size != required.size) {
        return p8Failure("release_authority_layout_incomplete")
    }
    let seen = HashSet<String>()
    for (expected in contract.expected) {
        if (seen.contains(expected.logicalAsset)) {
            return p8Failure("release_authority_contract_mismatch")
        }
        seen.add(expected.logicalAsset)
        var matched = false
        for (row in required) {
            if (row[0] == expected.logicalAsset &&
                row[1] == expected.role) { matched = true }
        }
        if (!matched) { return p8Failure("release_authority_layout_invalid") }
    }
    p8Success()
}

private func p8HashParts(prefix: String, values: Array<String>): String {
    let builder = StringBuilder(prefix)
    for (value in values) {
        builder.append("${value.toArray().size}:${value}")
    }
    ckbReproBundleHash(builder.toString().toArray())
}

private func p8AbsoluteRoot(value: String): Bool {
    value.startsWith("/") && value != "/" && !value.endsWith("/") &&
        !value.contains("//") && !value.contains("/./") &&
        !value.contains("/../") && !value.endsWith("/.") &&
        !value.endsWith("/..") && !value.contains("\\") &&
        !value.contains("\n") && !value.contains("\r") &&
        !value.contains("\t") && !p8HasControl(value)
}

private func p8AbsoluteFile(value: String): Bool {
    p8AbsoluteRoot(value) && !value.endsWith("/")
}

private func p8RootsOverlap(left: String, right: String): Bool {
    left == right || left.startsWith(right + "/") ||
        right.startsWith(left + "/")
}

private func p8CommitValid(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 40) { return false }
    for (rune in runes) {
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) { return false }
    }
    true
}

private func p8HashValid(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 71 || !value.startsWith("sha256:")) {
        return false
    }
    for (i in 7..runes.size) {
        if (!((runes[i] >= r'0' && runes[i] <= r'9') ||
            (runes[i] >= r'a' && runes[i] <= r'f'))) { return false }
    }
    true
}

private func p8HasControl(value: String): Bool {
    for (rune in value.toRuneArray()) {
        if (rune < r' ' || rune == r'\u{7f}') { return true }
    }
    false
}

private func p8Success(): CkbReproContractResult {
    let out = CkbReproContractResult()
    out.ok = true
    out.diagnostic = "ok"
    out
}

private func p8Failure(diagnostic: String): CkbReproContractResult {
    let out = CkbReproContractResult()
    out.diagnostic = diagnostic
    out
}

private func p8Json(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"")
        .replace("\u{0000}", "\\u0000").replace("\u{0001}", "\\u0001")
        .replace("\u{0002}", "\\u0002").replace("\u{0003}", "\\u0003")
        .replace("\u{0004}", "\\u0004").replace("\u{0005}", "\\u0005")
        .replace("\u{0006}", "\\u0006").replace("\u{0007}", "\\u0007")
        .replace("\u{0008}", "\\b").replace("\t", "\\t")
        .replace("\n", "\\n").replace("\u{000b}", "\\u000b")
        .replace("\u{000c}", "\\f").replace("\r", "\\r")
        .replace("\u{000e}", "\\u000e").replace("\u{000f}", "\\u000f")
        .replace("\u{0010}", "\\u0010").replace("\u{0011}", "\\u0011")
        .replace("\u{0012}", "\\u0012").replace("\u{0013}", "\\u0013")
        .replace("\u{0014}", "\\u0014").replace("\u{0015}", "\\u0015")
        .replace("\u{0016}", "\\u0016").replace("\u{0017}", "\\u0017")
        .replace("\u{0018}", "\\u0018").replace("\u{0019}", "\\u0019")
        .replace("\u{001a}", "\\u001a").replace("\u{001b}", "\\u001b")
        .replace("\u{001c}", "\\u001c").replace("\u{001d}", "\\u001d")
        .replace("\u{001e}", "\\u001e").replace("\u{001f}", "\\u001f")
        .replace("\u{007f}", "\\u007f")
}
