public package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashSet}
import std.fs.{Directory, File, Path, canonicalize, exists}
import stdx.encoding.json.*

public class CkbFrozenFingerprintInput {
    public var knowledgeVersion: String = ""
    public var knowledgeContentHash: String = ""
    public var datasetVersion: String = ""
    public var manifestHash: String = ""
    public var modelVersion: String = ""
    public var claudeCodeVersion: String = ""
    public var promptHash: String = ""
    public var toolConfigHash: String = ""
    public var providerIdentityHash: String = ""
    public var certificationTransport: String = ""
    public var runtimeConfigHash: String = ""
    public var candidateChecksum: String = ""
    public var studentLeakageProofHash: String = ""
    public var frozenCandidateManifestHash: String = ""
    public var skillBundleVersion: String = ""
    public var skillBundleHash: String = ""
    public var samplingCapabilityHash: String = ""
    public var generationProtocol: String = ""
    public var outputSchemaHash: String = ""
    public var skillCount: Int64 = 0
    public var skillContentBytes: Int64 = 0
    public var assetLineage: String = ""
    public var lineageProofHash: String = ""
    public var studentContextCompositeHash: String = ""
    public var combinationAuditHash: String = ""
    public init() {}
}

public func ckbFrozenFingerprint(input: CkbFrozenFingerprintInput): String {
    let contextSeed=if(input.studentContextCompositeHash==""&&input.combinationAuditHash==""){""}else{ckbP6Part(input.studentContextCompositeHash)+ckbP6Part(input.combinationAuditHash)}
    benchmarkGapSha256(ckbP6Part(input.knowledgeVersion) + ckbP6Part(input.knowledgeContentHash) +
        ckbP6Part(input.datasetVersion) + ckbP6Part(input.manifestHash) + ckbP6Part(input.modelVersion) +
        ckbP6Part(input.claudeCodeVersion) + ckbP6Part(input.promptHash) + ckbP6Part(input.toolConfigHash) +
        ckbP6Part(input.providerIdentityHash) + ckbP6Part(input.certificationTransport) + ckbP6Part(input.runtimeConfigHash) +
        ckbP6Part(input.candidateChecksum) + ckbP6Part(input.studentLeakageProofHash) + ckbP6Part(input.frozenCandidateManifestHash) +
        ckbP6Part(input.skillBundleVersion)+ckbP6Part(input.skillBundleHash)+ckbP6Part(input.samplingCapabilityHash)+
        ckbP6Part(input.generationProtocol)+ckbP6Part(input.outputSchemaHash)+ckbP6Part("${input.skillCount}")+ckbP6Part("${input.skillContentBytes}")+ckbP6Part(input.assetLineage)+ckbP6Part(input.lineageProofHash)+contextSeed)
}

public func ckbFrozenFingerprintDiagnostic(input: CkbFrozenFingerprintInput): String {
    if (input.knowledgeVersion == "" || input.datasetVersion == "" || input.modelVersion == "" || input.claudeCodeVersion == "" || input.certificationTransport == "" || input.skillBundleVersion=="" || input.generationProtocol!="completion-only-v1"||input.skillCount<1||input.skillCount>16||input.skillContentBytes<1||input.skillContentBytes>24576||(input.assetLineage!="independent"&&input.assetLineage!="humaneval_164_derived")) { return "fingerprint_identity_field_required" }
    for (hash in [input.knowledgeContentHash, input.manifestHash, input.promptHash, input.toolConfigHash, input.providerIdentityHash, input.runtimeConfigHash,
        input.candidateChecksum, input.studentLeakageProofHash, input.frozenCandidateManifestHash,input.skillBundleHash,input.samplingCapabilityHash,input.outputSchemaHash,input.lineageProofHash]) {
        if (!ckbP6HashFormat(hash)) { return "fingerprint_canonical_hash_required" }
    }
    if (input.certificationTransport != CkbAbcdeGroups.D) { return "fingerprint_transport_invalid" }
    if((input.studentContextCompositeHash=="")!=(input.combinationAuditHash=="")||(input.studentContextCompositeHash!=""&&(!ckbP6HashFormat(input.studentContextCompositeHash)||!ckbP6HashFormat(input.combinationAuditHash)))){return "student_context_fingerprint_binding_invalid"}
    "ok"
}

public class CkbContributionArm {
    public var name: String = ""
    public var ckbEnabled: Bool = false
    public var workspaceId: String = ""
    public var sessionId: String = ""
    public var runtimeHomeId: String = ""
    public var datasetVersion: String = ""
    public var manifestHash: String = ""
    public var modelVersion: String = ""
    public var claudeCodeVersion: String = ""
    public var promptHash: String = ""
    public var toolConfigHash: String = ""
    public var temperature: String = "0"
    public var toolBudget: Int64 = 3
    public var passed: Int64 = 0
    public var total: Int64 = 0
    public var knowledgeHits: Int64 = 0
    public var failureClassificationHash: String = ""
    public var resultArtifactHash: String = ""
    public var isolationSetHash: String = ""
    public var frozenKnowledgeVersion: String = ""
    public var frozenKnowledgeContentHash: String = ""
    public var resultArtifactJson: String = ""
    public var isolationSetJson: String = ""
    public init() {}
}

public class CkbContributionExperimentReport {
    public var ok: Bool = false
    public var diagnostic: String = ""
    public var comparisonFingerprint: String = ""
    public var baselinePassRate: String = "0/0"
    public var treatmentPassRate: String = "0/0"
    public var passDelta: Int64 = 0
    public var knowledgeHitDelta: Int64 = 0
    public var certificationPassAt1: ?Bool = None<Bool>
    public var evidenceHash: String = ""
    public var frozenFingerprint: String = ""
    public init() {}
}

public func runCkbContributionExperiment(baseline: CkbContributionArm, treatment: CkbContributionArm, frozenFingerprint!: String = ""): CkbContributionExperimentReport {
    let report = CkbContributionExperimentReport()
    let diagnostic = if (!ckbP6HashFormat(frozenFingerprint)) { "frozen_fingerprint_required" } else { ckbContributionExperimentDiagnostic(baseline, treatment) }
    report.diagnostic = diagnostic
    report.ok = diagnostic == "ok"
    report.baselinePassRate = "${baseline.passed}/${baseline.total}"
    report.treatmentPassRate = "${treatment.passed}/${treatment.total}"
    report.passDelta = treatment.passed - baseline.passed
    report.knowledgeHitDelta = treatment.knowledgeHits - baseline.knowledgeHits
    report.comparisonFingerprint = benchmarkGapSha256(ckbP6ComparableSeed(baseline))
    report.frozenFingerprint = frozenFingerprint
    report.evidenceHash = benchmarkGapSha256(ckbP6Part(report.comparisonFingerprint) + ckbP6Part(frozenFingerprint) + ckbP6Part(baseline.resultArtifactHash) + ckbP6Part(treatment.resultArtifactHash) + ckbP6Part(baseline.isolationSetHash) + ckbP6Part(treatment.isolationSetHash) + ckbP6Part(treatment.frozenKnowledgeVersion) + ckbP6Part(treatment.frozenKnowledgeContentHash))
    report
}

public func ckbContributionExperimentDiagnostic(baseline: CkbContributionArm, treatment: CkbContributionArm): String {
    if (baseline.name != "no-ckb" || baseline.ckbEnabled) { return "baseline_must_disable_ckb" }
    if (treatment.name != "frozen-ckb" || !treatment.ckbEnabled) { return "treatment_must_enable_frozen_ckb" }
    if (baseline.total <= 0 || baseline.total != treatment.total || baseline.passed < 0 || treatment.passed < 0 || baseline.passed > baseline.total || treatment.passed > treatment.total) { return "experiment_counts_invalid" }
    if (baseline.workspaceId == "" || baseline.sessionId == "" || baseline.runtimeHomeId == "" || treatment.workspaceId == "" || treatment.sessionId == "" || treatment.runtimeHomeId == "") { return "experiment_isolation_identity_required" }
    if (baseline.workspaceId == treatment.workspaceId || baseline.sessionId == treatment.sessionId || baseline.runtimeHomeId == treatment.runtimeHomeId) { return "experiment_fresh_isolation_required" }
    if (ckbP6ComparableSeed(baseline) != ckbP6ComparableSeed(treatment)) { return "experiment_configuration_mismatch" }
    if (baseline.failureClassificationHash == "" || treatment.failureClassificationHash == "") { return "failure_classification_evidence_required" }
    for (hash in [baseline.failureClassificationHash, treatment.failureClassificationHash, baseline.resultArtifactHash, treatment.resultArtifactHash, baseline.isolationSetHash, treatment.isolationSetHash]) { if (!ckbP6HashFormat(hash)) { return "experiment_artifact_hash_required" } }
    if (baseline.resultArtifactHash != benchmarkGapSha256(baseline.resultArtifactJson) || treatment.resultArtifactHash != benchmarkGapSha256(treatment.resultArtifactJson) || baseline.isolationSetHash != benchmarkGapSha256(baseline.isolationSetJson) || treatment.isolationSetHash != benchmarkGapSha256(treatment.isolationSetJson)) { return "experiment_artifact_hash_mismatch" }
    if (treatment.frozenKnowledgeVersion == "" || !ckbP6HashFormat(treatment.frozenKnowledgeContentHash)) { return "treatment_frozen_knowledge_binding_required" }
    if (baseline.frozenKnowledgeVersion != "" || baseline.frozenKnowledgeContentHash != "") { return "baseline_must_not_bind_knowledge" }
    "ok"
}

public class CkbCertificationBudget {
    public var agentAttempts: Int64 = 1
    public var providerRetries: Int64 = 0
    public var sdkRetries: Int64 = 0
    public var maxTurns: Int64 = 1
    public var knowledgeRestRetries: Int64 = 0
    public var transportRetries: Int64 = 2
    public init() {}
}

public class CkbCertificationPreflightOptions {
    public var runId: String = ""
    public var outputRoot: String = ""
    public var workspaceRoot: String = ""
    public var frozenVersion: String = ""
    public var datasetVersion: String = ""
    public var activeVersionAtStart: String = ""
    public var activeVersionAtEnd: String = ""
    public var expectedManifestHash: String = ""
    public var actualManifestHash: String = ""
    public var developmentClosed: Int64 = 0
    public var expectedCases: Int64 = 164
    public var unresolvedNonKnowledgeFailures: Int64 = 0
    public var knowledgeTestsPassed: Bool = false
    public var releaseGatePassed: Bool = false
    public var contributionExperimentPassed: Bool = false
    public var contributionExperimentSynthetic: Bool = false
    public var parityPassed: Bool = false
    public var parityEvidenceHash: String = ""
    public var modelVersion: String = ""
    public var claudeCodeVersion: String = ""
    public var providerIdentityHash: String = ""
    public var certificationTransport: String = ""
    public var runtimeHomeRoot: String = ""
    public var filesystemIsolationEnforced: Bool = false
    public var developmentClosureJson: String = ""
    public var knowledgeGateJson: String = ""
    public var releaseGateJson: String = ""
    public var filesystemProbeJson: String = ""
    public var experimentReport: CkbContributionExperimentReport = CkbContributionExperimentReport()
    public var parityRestPayload: String = ""
    public var parityStdioPayload: String = ""
    public var parityHttpPayload: String = ""
    public var providerIdentityJson: String = ""
    public var providerIdentityPath: String = ""
    public var candidateChecksum: String = ""
    public var studentLeakageProofJson: String = ""
    public var studentLeakageProofHash: String = ""
    public var frozenCandidateManifestJson: String = ""
    public var frozenCandidateManifestHash: String = ""
    public var budget: CkbCertificationBudget = CkbCertificationBudget()
    public var modelTimeoutSeconds: Int64 = 180
    public var certificationBinaryPath: String = ""
    public var certificationConfigPath: String = ""
    public var certificationStorePath: String = ""
    public var certificationRunRoot: String = ""
    public var certificationHttpBase: String = ""
    public var skillBundlePath: String = ""
    public var skillBundleVersion: String = ""
    public var skillBundleHash: String = ""
    public var samplingCapabilityPath: String = ""
    public var samplingCapabilityHash: String = ""
    public var generationProtocol: String = ""
    public var samplesPerCase: Int64 = 0
    public var outputSchemaHash: String = ""
    public var skillCount: Int64 = 0
    public var skillContentBytes: Int64 = 0
    public var assetLineage: String = ""
    public var lineageProofPath: String = ""
    public var lineageProofJson: String = ""
    public var lineageProofHash: String = ""
    public var studentContextRoot: String = ""
    public var studentContextManifestHash: String = ""
    public var studentContextCompositeHash: String = ""
    public var combinationAuditHash: String = ""
    public var aggregateAssetLineage: String = ""
    public var generationMode: String = ""
    public var providerCount: Int64 = 0
    public var providerPromptCapabilityPath: String = ""
    public var providerPromptCapabilityHash: String = ""
    public var effectivePromptByteBudget: Int64 = 0
    public var studentContextCandidateRoot: String = ""
    public var studentContextCandidateSetHash: String = ""
    public var completionControlPath: String = ""
    public var completionControlHash: String = ""
    public var providerRuntimeExecutablePath: String = ""
    public init() {}
}

public class CkbCertificationPreflightReport {
    public var ok: Bool = false
    public var startAllowed: Bool = false
    public var diagnostic: String = ""
    public var fingerprint: String = ""
    public var checks: ArrayList<String> = ArrayList<String>()
    public var certificationBinaryHash: String = ""
    public var certificationHttpLaunchSpecHash: String = ""
    public var certificationHttpCommandHash: String = ""
    public var certificationPassAt1: ?Bool = None<Bool>
    public var preflightHash: String = ""
    public var runManifestHash: String = ""
    public var runManifestPath: String = ""
    public var providerIdentityHash: String = ""
    public var modelVersion: String = ""
    public var claudeCodeVersion: String = ""
    public var certificationTransport: String = ""
    public var candidateChecksum: String = ""
    public var studentLeakageProofHash: String = ""
    public var frozenCandidateManifestHash: String = ""
    public var transportRetryBudget: Int64 = 0
    public var modelTimeoutSeconds: Int64 = 0
    public var skillBundleHash: String = ""
    public var samplingCapabilityHash: String = ""
    public var generationProtocol: String = ""
    public var samplesPerCase: Int64 = 0
    public var outputSchemaHash: String = ""
    public var skillCount: Int64 = 0
    public var skillContentBytes: Int64 = 0
    public var assetLineage: String = ""
    public var lineageProofHash: String = ""
    public var studentContextManifestHash: String = ""
    public var studentContextCompositeHash: String = ""
    public var combinationAuditHash: String = ""
    public var aggregateAssetLineage: String = ""
    public init() {}
}

public func runCertificationPreflight(options: CkbCertificationPreflightOptions, fingerprintInput: CkbFrozenFingerprintInput): CkbCertificationPreflightReport {
    let report = CkbCertificationPreflightReport()
    report.transportRetryBudget = options.budget.transportRetries
    report.modelTimeoutSeconds = options.modelTimeoutSeconds
    report.fingerprint = ckbFrozenFingerprint(fingerprintInput)
    report.providerIdentityHash=options.providerIdentityHash;report.modelVersion=options.modelVersion;report.claudeCodeVersion=options.claudeCodeVersion;report.certificationTransport=options.certificationTransport
    report.candidateChecksum = options.candidateChecksum
    report.studentLeakageProofHash = options.studentLeakageProofHash
    report.frozenCandidateManifestHash = options.frozenCandidateManifestHash
    report.skillBundleHash=options.skillBundleHash;report.samplingCapabilityHash=options.samplingCapabilityHash
    report.generationProtocol=options.generationProtocol;report.samplesPerCase=options.samplesPerCase;report.outputSchemaHash=options.outputSchemaHash
    report.skillCount=options.skillCount;report.skillContentBytes=options.skillContentBytes;report.assetLineage=options.assetLineage;report.lineageProofHash=options.lineageProofHash;report.studentContextManifestHash=options.studentContextManifestHash;report.studentContextCompositeHash=options.studentContextCompositeHash;report.combinationAuditHash=options.combinationAuditHash;report.aggregateAssetLineage=options.aggregateAssetLineage
    report.certificationBinaryHash = ckbAbcdeBinaryHash(options.certificationBinaryPath)
    report.certificationHttpLaunchSpecHash = ckbAbcdeCertificationHttpLaunchSpecHash(
        report.certificationBinaryHash, options.certificationConfigPath,
        options.certificationStorePath, options.certificationRunRoot, options.certificationHttpBase)
    report.certificationHttpCommandHash = benchmarkGapSha256(ckbAbcdeCertificationHttpLaunchScript(
        options.certificationBinaryPath, options.certificationConfigPath,
        options.certificationStorePath, options.certificationRunRoot))
    ckbP6Check(report, ckbP6HashFormat(report.certificationBinaryHash), "certification_binary_hash_required")
    ckbP6Check(report, ckbP6HashFormat(report.certificationHttpLaunchSpecHash), "certification_http_launch_spec_invalid")
    ckbP6Check(report, ckbP6HashFormat(report.certificationHttpCommandHash), "certification_http_command_hash_invalid")
    ckbP6Check(report, ckbFrozenFingerprintDiagnostic(fingerprintInput) == "ok", ckbFrozenFingerprintDiagnostic(fingerprintInput))
    if(options.generationMode!=""){ckbP6Check(report,ckbControlFrozenPathDiagnostic(options.studentContextRoot,true)=="ok"&&ckbControlFrozenPathDiagnostic(options.studentContextCandidateRoot,true)=="ok"&&ckbControlFrozenPathDiagnostic(options.providerPromptCapabilityPath,false)=="ok"&&ckbControlFrozenPathDiagnostic(options.completionControlPath,false)=="ok"&&ckbControlFrozenPathDiagnostic(options.providerRuntimeExecutablePath,false)=="ok","student_validation_identity_invalid")}
    if(options.generationMode!=""){let context=readStudentContextBundleV2(options.studentContextRoot);let contextManifest=try{String.fromUtf8(File.readFrom(Path(options.studentContextRoot).join("student-context-manifest.json")))}catch(_:Exception){""};let aggregate=if(context.rulesLineage=="independent"&&context.skillsLineage=="independent"&&context.knowledgeLineage=="independent"){"independent"}else{"humaneval_164_derived"};ckbP6Check(report,context.ok&&benchmarkGapSha256(contextManifest)==options.studentContextManifestHash&&context.compositeHash==options.studentContextCompositeHash&&context.combinationAuditHash==options.combinationAuditHash&&aggregate==options.aggregateAssetLineage,"student_context_manifest_binding_invalid");ckbP6Check(report,context.validationLevel=="student_validated","student_context_not_student_validated");let identityBinding=ckbStudentContextValidationIdentityDiagnostic(options.studentContextRoot,options.studentContextCandidateRoot,options.studentContextCandidateSetHash,options.providerIdentityHash,options.modelVersion);ckbP6Check(report,identityBinding=="ok",identityBinding);let completion=try{String.fromUtf8(File.readFrom(Path(options.completionControlPath)))}catch(_:Exception){""};let sampling=try{String.fromUtf8(File.readFrom(Path(options.samplingCapabilityPath)))}catch(_:Exception){""};let runtimeConfig=try{String.fromUtf8(File.readFrom(Path(options.certificationConfigPath)))}catch(_:Exception){""};let completionDiagnostic=ckbStudentCompletionControlDiagnostic(completion.toArray(),options.certificationTransport,options.generationProtocol,options.samplesPerCase,options.outputSchemaHash,benchmarkGapSha256(sampling),options.effectivePromptByteBudget,options.budget.transportRetries,options.modelTimeoutSeconds,benchmarkGapSha256(runtimeConfig),options.modelVersion);ckbP6Check(report,benchmarkGapSha256(completion)==options.completionControlHash&&completionDiagnostic=="ok","student_completion_control_invalid");let binding=ckbS4PreflightBindingDiagnostic(options.generationMode,options.studentContextCompositeHash,options.combinationAuditHash,options.providerCount);ckbP6Check(report,binding=="ok",binding);let capability=try{File.readFrom(Path(options.providerPromptCapabilityPath))}catch(_:Exception){Array<UInt8>()};let parsedCapability=parseCkbS4ProviderPromptCapability(capability,options.modelVersion,"");let capabilityText=try{String.fromUtf8(capability)}catch(_:Exception){""};let identityDiagnostic=ckbStudentValidationProviderIdentityDiagnostic(options.providerIdentityJson.toArray(),options.modelVersion,options.claudeCodeVersion,ckbAbcdeBinaryHash(options.providerRuntimeExecutablePath),options.completionControlHash,benchmarkGapSha256(capabilityText));ckbP6Check(report,identityDiagnostic=="ok",identityDiagnostic);ckbP6Check(report,parsedCapability.ok&&benchmarkGapSha256(capabilityText)==options.providerPromptCapabilityHash&&options.effectivePromptByteBudget>0&&options.effectivePromptByteBudget<=parsedCapability.maxPromptBytes,"provider_prompt_capability_binding_invalid")}
    let skillBundle=try{parseStudentSkillBundle(File.readFrom(Path(options.skillBundlePath)))}catch(_:Exception){CkbStudentSkillBundleBuild()}
    ckbP6Check(report,validateStudentSkillBundle(skillBundle)=="ok"&&skillBundle.bundleVersion==options.skillBundleVersion&&skillBundle.canonicalHash==options.skillBundleHash&&skillBundle.skillCount==options.skillCount&&skillBundle.contentBytes==options.skillContentBytes,"student_skill_bundle_binding_invalid")
    ckbP6Check(report,(options.assetLineage=="independent"||options.assetLineage=="humaneval_164_derived")&&options.lineageProofHash==benchmarkGapSha256(options.lineageProofJson),"asset_lineage_binding_invalid")
    let samplingText=try{String.fromUtf8(File.readFrom(Path(options.samplingCapabilityPath)))}catch(_:Exception){""}
    ckbP6Check(report,samplingText!=""&&benchmarkGapSha256(samplingText)==options.samplingCapabilityHash,"sampling_capability_binding_invalid")
    ckbP6Check(report,options.generationProtocol=="completion-only-v1"&&options.samplesPerCase==1,"completion_generation_contract_invalid")
    ckbP6Check(report,options.outputSchemaHash==benchmarkGapSha256(ckbAbcdeCompletionOutputSchema()),"completion_output_schema_binding_invalid")
    ckbP6Check(report, options.runId != "", "run_identity_required")
    ckbP6Check(report, options.frozenVersion != "" && options.activeVersionAtStart == options.frozenVersion, "frozen_active_version_mismatch")
    ckbP6Check(report, options.activeVersionAtEnd == options.activeVersionAtStart, "knowledge_version_drift")
    ckbP6Check(report, options.expectedManifestHash != "" && options.expectedManifestHash == options.actualManifestHash, "manifest_hash_mismatch")
    ckbP6Check(report, ckbP6DevelopmentClosureDiagnostic(options.developmentClosureJson) == "ok", ckbP6DevelopmentClosureDiagnostic(options.developmentClosureJson))
    ckbP6Check(report, ckbP6GateArtifactDiagnostic(options.knowledgeGateJson, "knowledge") == "ok", ckbP6GateArtifactDiagnostic(options.knowledgeGateJson, "knowledge"))
    ckbP6Check(report, ckbP6GateArtifactDiagnostic(options.releaseGateJson, "release") == "ok", ckbP6GateArtifactDiagnostic(options.releaseGateJson, "release"))
    let parityHash = ckbP6ParityHash(options.parityRestPayload, options.parityStdioPayload, options.parityHttpPayload, options.frozenVersion)
    ckbP6Check(report, parityHash != "" && parityHash == options.parityEvidenceHash, "transport_parity_required")
    ckbP6Check(report, options.modelVersion != "" && options.claudeCodeVersion != "", "exact_model_versions_required")
    ckbP6Check(report, ckbP6HashFormat(options.providerIdentityHash), "redacted_provider_identity_required")
    ckbP6Check(report, ckbP6HashFormat(options.candidateChecksum) && options.candidateChecksum == fingerprintInput.knowledgeContentHash &&
        options.candidateChecksum == fingerprintInput.candidateChecksum, "candidate_checksum_binding_mismatch")
    ckbP6Check(report, ckbP6HashFormat(options.studentLeakageProofHash) &&
        options.studentLeakageProofHash == benchmarkGapSha256(options.studentLeakageProofJson) &&
        options.studentLeakageProofHash == fingerprintInput.studentLeakageProofHash,
        "student_leakage_proof_binding_mismatch")
    ckbP6Check(report, ckbP6HashFormat(options.frozenCandidateManifestHash) &&
        options.frozenCandidateManifestHash == benchmarkGapSha256(options.frozenCandidateManifestJson) &&
        options.frozenCandidateManifestHash == fingerprintInput.frozenCandidateManifestHash &&
        ckbFrozenCandidateManifestIntegrityDiagnostic(options.frozenCandidateManifestJson,
            expectedCandidateChecksum: options.candidateChecksum,
            expectedLeakageProofHash: options.studentLeakageProofHash,
            expectedKnowledgeVersion: options.frozenVersion) == "ok",
        "frozen_candidate_manifest_invalid")
    ckbP6Check(report, ckbP6ProviderIdentityDiagnostic(options.providerIdentityJson, options.providerIdentityHash, options.modelVersion, options.claudeCodeVersion) == "ok", ckbP6ProviderIdentityDiagnostic(options.providerIdentityJson, options.providerIdentityHash, options.modelVersion, options.claudeCodeVersion))
    ckbP6Check(report, options.certificationTransport == CkbAbcdeGroups.D, "isolated_http_certification_transport_required")
    ckbP6Check(report, options.runtimeHomeRoot != "" && options.runtimeHomeRoot != options.workspaceRoot && ckbCertificationWorkspaceDiagnostic(options.runtimeHomeRoot) == "ok", "isolated_runtime_home_required")
    ckbP6Check(report, ckbP6FilesystemProbeDiagnostic(options.filesystemProbeJson, options.workspaceRoot, options.runtimeHomeRoot) == "ok", ckbP6FilesystemProbeDiagnostic(options.filesystemProbeJson, options.workspaceRoot, options.runtimeHomeRoot))
    ckbP6Check(report, ckbCertificationBudgetDiagnostic(options.budget) == "ok", ckbCertificationBudgetDiagnostic(options.budget))
    ckbP6Check(report, options.modelTimeoutSeconds > 0 && options.modelTimeoutSeconds <= 3600, "model_timeout_budget_invalid")
    ckbP6Check(report, ckbCertificationWorkspaceDiagnostic(options.workspaceRoot) == "ok", ckbCertificationWorkspaceDiagnostic(options.workspaceRoot))
    ckbP6Check(report, ckbCertificationOutputDiagnostic(options.outputRoot) == "ok", ckbCertificationOutputDiagnostic(options.outputRoot))
    ckbP6Check(report, ckbP6CanonicalPath(options.outputRoot).endsWith("/${options.runId}"), "output_root_run_identity_mismatch")
    ckbP6Check(report, fingerprintInput.knowledgeVersion == options.frozenVersion && fingerprintInput.manifestHash == options.actualManifestHash && fingerprintInput.modelVersion == options.modelVersion && fingerprintInput.claudeCodeVersion == options.claudeCodeVersion && fingerprintInput.providerIdentityHash == options.providerIdentityHash && fingerprintInput.certificationTransport == options.certificationTransport && fingerprintInput.runtimeConfigHash != "" && fingerprintInput.skillBundleVersion==options.skillBundleVersion&&fingerprintInput.skillBundleHash==options.skillBundleHash&&fingerprintInput.samplingCapabilityHash==options.samplingCapabilityHash&&fingerprintInput.generationProtocol==options.generationProtocol&&fingerprintInput.outputSchemaHash==options.outputSchemaHash&&fingerprintInput.skillCount==options.skillCount&&fingerprintInput.skillContentBytes==options.skillContentBytes&&fingerprintInput.assetLineage==options.assetLineage&&fingerprintInput.lineageProofHash==options.lineageProofHash&&(options.generationMode==""||(fingerprintInput.studentContextCompositeHash==options.studentContextCompositeHash&&fingerprintInput.combinationAuditHash==options.combinationAuditHash)), "fingerprint_binding_mismatch")
    report.ok = report.checks.size == 0
    report.startAllowed = report.ok
    report.diagnostic = if (report.ok) { "ok" } else { report.checks[0] }
    report.preflightHash = benchmarkGapSha256(renderCertificationPreflightJson(report))
    if (report.ok) { ckbP6PersistManifest(options, report) }
    report
}

public func ckbCertificationBudgetDiagnostic(budget: CkbCertificationBudget): String {
    if (budget.agentAttempts != 1) { return "agent_attempt_budget_must_equal_one" }
    if (budget.providerRetries != 0) { return "provider_retry_must_be_zero" }
    if (budget.sdkRetries != 0) { return "sdk_retry_must_be_zero" }
    if (budget.maxTurns <= 0) { return "internal_turn_budget_must_be_positive" }
    if (budget.transportRetries < 0 || budget.transportRetries > 10) { return "transport_retry_budget_must_be_0_to_10" }
    if (budget.knowledgeRestRetries != 0) { return "knowledge_rest_retry_must_be_zero" }
    "ok"
}

public func ckbCertificationWorkspaceDiagnostic(path: String): String {
    if (path.trimAscii() == "" || !exists(Path(path))) { return "workspace_required" }
    let normalized = try { canonicalize(Path(path)).toString().replace("\\", "/").toAsciiLower() } catch (_: Exception) { return "workspace_canonicalization_failed" }
    for (segment in normalized.split("/")) {
        if (segment == "test" || segment == "tests" || segment == "reference" || segment == "references" || segment == "teacher" || segment == "teacher-solutions" || segment == "solution" || segment == "solutions") { return "forbidden_workspace_segment:${segment}" }
    }
    "ok"
}

public func ckbCertificationOutputDiagnostic(path: String): String {
    if (path.trimAscii() == "") { return "output_root_required" }
    let root = Path(path)
    if (!exists(root)) { return "output_root_must_preexist" }
    try {
        let canonical = canonicalize(root).toString().replace("\\", "/")
        if (!canonical.endsWith("/${Path(path).fileName}")) { return "output_root_symlink_forbidden" }
        for (_ in Directory.readFrom(root)) { return "output_root_not_empty" }
    } catch (_: Exception) { return "output_root_unreadable" }
    "ok"
}

public func renderCertificationPreflightJson(report: CkbCertificationPreflightReport): String {
    var checks = ""
    for (i in 0..report.checks.size) { if (i > 0) { checks += "," }; checks += "\"${ckbP6JsonEscape(report.checks[i])}\"" }
    "{\"ok\":${report.ok},\"startAllowed\":${report.startAllowed},\"diagnostic\":\"${ckbP6JsonEscape(report.diagnostic)}\",\"fingerprint\":\"${ckbP6JsonEscape(report.fingerprint)}\",\"providerIdentityHash\":\"${report.providerIdentityHash}\",\"candidateChecksum\":\"${report.candidateChecksum}\",\"studentLeakageProofHash\":\"${report.studentLeakageProofHash}\",\"frozenCandidateManifestHash\":\"${report.frozenCandidateManifestHash}\",\"skillBundleHash\":\"${report.skillBundleHash}\",\"skillCount\":${report.skillCount},\"contentBytes\":${report.skillContentBytes},\"assetLineage\":\"${report.assetLineage}\",\"lineageProofHash\":\"${report.lineageProofHash}\",\"samplingCapabilityHash\":\"${report.samplingCapabilityHash}\",\"generationProtocol\":\"${report.generationProtocol}\",\"samplesPerCase\":${report.samplesPerCase},\"outputSchemaHash\":\"${report.outputSchemaHash}\",\"certificationBinaryHash\":\"${report.certificationBinaryHash}\",\"certificationHttpLaunchSpecHash\":\"${report.certificationHttpLaunchSpecHash}\",\"certificationHttpCommandHash\":\"${report.certificationHttpCommandHash}\",\"transportRetryBudget\":${report.transportRetryBudget},\"modelTimeoutSeconds\":${report.modelTimeoutSeconds},\"certificationPassAt1\":null,\"violations\":[${checks}]}"
}

public func ckbCertificationPreflightSealDiagnostic(preflight: String, manifest: String): String {
    try {
        let p = JsonValue.fromStr(preflight).asObject(); let m = JsonValue.fromStr(manifest).asObject()
        let declared = ckbP6String(m, "preflightHash")
        let contextSeed=match(m.get("studentContextCompositeHash")){case Some(_)=>ckbP6Part(ckbP6String(m,"studentContextManifestHash"))+ckbP6Part(ckbP6String(m,"studentContextCompositeHash"))+ckbP6Part(ckbP6String(m,"combinationAuditHash"))+ckbP6Part(ckbP6String(m,"aggregateAssetLineage"))+ckbP6Part(ckbP6String(m,"providerPromptCapabilityPath"))+ckbP6Part(ckbP6String(m,"providerPromptCapabilityHash"))+ckbP6Part("${ckbP6Int(m,"effectivePromptByteBudget")}")+ckbP6Part(ckbP6String(m,"studentContextCandidateRoot"))+ckbP6Part(ckbP6String(m,"studentContextCandidateSetHash"))+ckbP6Part(ckbP6String(m,"completionControlPath"))+ckbP6Part(ckbP6String(m,"completionControlHash"))+ckbP6Part(ckbP6String(m,"providerIdentityPath"))+ckbP6Part(ckbP6String(m,"providerRuntimeExecutablePath")) case None=>""}
        let expectedManifest = benchmarkGapSha256(ckbP6Part(ckbP6String(m, "runId")) +
            ckbP6Part(declared) + ckbP6Part(ckbP6String(m, "fingerprint")) +
            ckbP6Part(ckbP6String(m, "providerIdentityHash")) + ckbP6Part(ckbP6String(m, "modelVersion")) +
            ckbP6Part(ckbP6String(m, "claudeCodeVersion")) + ckbP6Part(ckbP6String(m, "certificationTransport")) +
            ckbP6Part("${ckbP6Int(m, "transportRetryBudget")}") +
            ckbP6Part("${ckbP6Int(m, "modelTimeoutSeconds")}") +
            ckbP6Part(ckbP6String(m, "candidateChecksum")) + ckbP6Part(ckbP6String(m, "studentLeakageProofHash")) +
            ckbP6Part(ckbP6String(m, "frozenCandidateManifestHash")) + ckbP6Part(ckbP6String(m,"skillBundleHash"))+
            ckbP6Part(ckbP6String(m,"samplingCapabilityHash"))+ckbP6Part(ckbP6String(m,"generationProtocol"))+ckbP6Part("${ckbP6Int(m,"samplesPerCase")}")+ckbP6Part(ckbP6String(m,"outputSchemaHash"))+ckbP6Part("${ckbP6Int(m,"skillCount")}")+ckbP6Part("${ckbP6Int(m,"contentBytes")}")+ckbP6Part(ckbP6String(m,"assetLineage"))+ckbP6Part(ckbP6String(m,"lineageProofHash"))+ckbP6Part(ckbP6String(m, "certificationBinaryHash")) +
            ckbP6Part(ckbP6String(m, "certificationHttpLaunchSpecHash")) + ckbP6Part(ckbP6String(m, "certificationHttpCommandHash"))+contextSeed)
        if (declared != benchmarkGapSha256(preflight) || ckbP6String(m, "runManifestHash") != expectedManifest ||
            !ckbP6Bool(m, "startAllowed") || !ckbP6Null(m, "certificationPassAt1") ||
            !ckbP6Bool(p, "ok") || !ckbP6Bool(p, "startAllowed") ||
            ckbP6String(p, "fingerprint") != ckbP6String(m, "fingerprint") ||
            ckbP6String(p, "providerIdentityHash") != ckbP6String(m, "providerIdentityHash") || !ckbP6HashFormat(ckbP6String(m,"providerIdentityHash")) ||
            ckbP6String(p, "candidateChecksum") != ckbP6String(m, "candidateChecksum") ||
            ckbP6String(p, "studentLeakageProofHash") != ckbP6String(m, "studentLeakageProofHash") ||
            ckbP6String(p, "frozenCandidateManifestHash") != ckbP6String(m, "frozenCandidateManifestHash") ||
            ckbP6String(p,"skillBundleHash")!=ckbP6String(m,"skillBundleHash")||ckbP6String(p,"samplingCapabilityHash")!=ckbP6String(m,"samplingCapabilityHash")||
            ckbP6String(p,"generationProtocol")!=ckbP6String(m,"generationProtocol")||ckbP6String(m,"generationProtocol")!="completion-only-v1"||ckbP6Int(p,"samplesPerCase")!=1||ckbP6Int(m,"samplesPerCase")!=1||
            ckbP6String(p,"outputSchemaHash")!=ckbP6String(m,"outputSchemaHash")||
            ckbP6Int(p,"skillCount")!=ckbP6Int(m,"skillCount")||ckbP6Int(p,"contentBytes")!=ckbP6Int(m,"contentBytes")||ckbP6String(p,"assetLineage")!=ckbP6String(m,"assetLineage")||ckbP6String(p,"lineageProofHash")!=ckbP6String(m,"lineageProofHash")||
            ckbP6String(p, "certificationBinaryHash") != ckbP6String(m, "certificationBinaryHash") ||
            ckbP6String(p, "certificationHttpLaunchSpecHash") != ckbP6String(m, "certificationHttpLaunchSpecHash") ||
            ckbP6String(p, "certificationHttpCommandHash") != ckbP6String(m, "certificationHttpCommandHash") ||
            ckbP6Int(p, "transportRetryBudget") != ckbP6Int(m, "transportRetryBudget") || ckbP6Int(m, "transportRetryBudget") < 0 || ckbP6Int(m, "transportRetryBudget") > 10 ||
            ckbP6Int(p, "modelTimeoutSeconds") != ckbP6Int(m, "modelTimeoutSeconds") || ckbP6Int(m, "modelTimeoutSeconds") <= 0 || ckbP6Int(m, "modelTimeoutSeconds") > 3600 ||
            !ckbP6HashFormat(ckbP6String(m, "candidateChecksum")) ||
            !ckbP6HashFormat(ckbP6String(m, "studentLeakageProofHash")) ||
            !ckbP6HashFormat(ckbP6String(m, "frozenCandidateManifestHash")) ||
            !ckbP6HashFormat(ckbP6String(m,"skillBundleHash"))||!ckbP6HashFormat(ckbP6String(m,"samplingCapabilityHash"))||!ckbP6HashFormat(ckbP6String(m,"outputSchemaHash"))||!ckbP6HashFormat(ckbP6String(m,"lineageProofHash"))||(ckbP6String(m,"assetLineage")!="independent"&&ckbP6String(m,"assetLineage")!="humaneval_164_derived")||ckbP6Int(m,"skillCount")<1||ckbP6Int(m,"skillCount")>16||ckbP6Int(m,"contentBytes")<1||ckbP6Int(m,"contentBytes")>24576||
            !ckbP6HashFormat(ckbP6String(m, "certificationBinaryHash")) ||
            !ckbP6HashFormat(ckbP6String(m, "certificationHttpLaunchSpecHash")) ||
            !ckbP6HashFormat(ckbP6String(m, "certificationHttpCommandHash"))) { return "preflight_manifest_seal_mismatch" }
        "ok"
    } catch (_: Exception) { "preflight_manifest_seal_mismatch" }
}

public func cangjieCertificationReleaseGateIntegrated(preflightPath: String, manifestPath: String): CangjieKnowledgeReleaseGateStep {
    let step = CangjieKnowledgeReleaseGateStep(); step.id = "P6-frozen-certification-preflight"
    try {
        let preflight = String.fromUtf8(File.readFrom(Path(preflightPath))); let manifest = String.fromUtf8(File.readFrom(Path(manifestPath)))
        step.ok = ckbCertificationPreflightSealDiagnostic(preflight, manifest) == "ok"
        step.evidenceHash = if (step.ok) { benchmarkGapSha256(preflight + manifest) } else { "" }
    } catch (_: Exception) { step.ok = false }
    step.status = if (step.ok) { "pass" } else { "fail" }; step.diagnostic = if (step.ok) { "trusted_preflight_manifest_verified" } else { "trusted_preflight_manifest_invalid" }; step
}

private func ckbP6PersistManifest(options: CkbCertificationPreflightOptions, report: CkbCertificationPreflightReport): Unit {
    let preflightPath = Path(options.outputRoot).join("preflight.json"); let manifestPath = Path(options.outputRoot).join("run-manifest.json")
    File.writeTo(Path(options.outputRoot).join("completion-runtime-config.json"),File.readFrom(Path(options.certificationConfigPath)));File.writeTo(Path(options.outputRoot).join("completion-sampling-capability.json"),File.readFrom(Path(options.samplingCapabilityPath)))
    let preflight = renderCertificationPreflightJson(report); File.writeTo(preflightPath, preflight.toArray()); report.preflightHash = benchmarkGapSha256(preflight)
    let contextSeed=if(options.generationMode==""){""}else{ckbP6Part(options.studentContextManifestHash)+ckbP6Part(options.studentContextCompositeHash)+ckbP6Part(options.combinationAuditHash)+ckbP6Part(options.aggregateAssetLineage)+ckbP6Part(options.providerPromptCapabilityPath)+ckbP6Part(options.providerPromptCapabilityHash)+ckbP6Part("${options.effectivePromptByteBudget}")+ckbP6Part(options.studentContextCandidateRoot)+ckbP6Part(options.studentContextCandidateSetHash)+ckbP6Part(options.completionControlPath)+ckbP6Part(options.completionControlHash)+ckbP6Part(options.providerIdentityPath)+ckbP6Part(options.providerRuntimeExecutablePath)}
    report.runManifestHash = benchmarkGapSha256(ckbP6Part(options.runId) + ckbP6Part(report.preflightHash) + ckbP6Part(report.fingerprint) + ckbP6Part(options.providerIdentityHash) + ckbP6Part(options.modelVersion) + ckbP6Part(options.claudeCodeVersion) + ckbP6Part(options.certificationTransport) + ckbP6Part("${report.transportRetryBudget}") + ckbP6Part("${report.modelTimeoutSeconds}") + ckbP6Part(options.candidateChecksum) + ckbP6Part(options.studentLeakageProofHash) + ckbP6Part(options.frozenCandidateManifestHash)+ckbP6Part(options.skillBundleHash)+ckbP6Part(options.samplingCapabilityHash)+ckbP6Part(options.generationProtocol)+ckbP6Part("${options.samplesPerCase}")+ckbP6Part(options.outputSchemaHash)+ckbP6Part("${options.skillCount}")+ckbP6Part("${options.skillContentBytes}")+ckbP6Part(options.assetLineage)+ckbP6Part(options.lineageProofHash) + ckbP6Part(report.certificationBinaryHash) + ckbP6Part(report.certificationHttpLaunchSpecHash) + ckbP6Part(report.certificationHttpCommandHash)+contextSeed)
    let persistedContext=if(options.generationMode==""){CkbContextBaseVersion()}else{readStudentContextBundleV2(options.studentContextRoot)}
    var contextFields=""
    if(options.generationMode!=""){
        contextFields=",\"skillBundleVersion\":\"${ckbP6JsonEscape(options.skillBundleVersion)}\""+
            ",\"samplingCapability\":\"provider_default_not_client_exposed\""+
            ",\"studentContextRoot\":\"${ckbP6JsonEscape(options.studentContextRoot)}\""+
            ",\"studentContextManifestHash\":\"${options.studentContextManifestHash}\""+
            ",\"studentContextCompositeHash\":\"${options.studentContextCompositeHash}\""+
            ",\"combinationAuditHash\":\"${options.combinationAuditHash}\""+
            ",\"aggregateAssetLineage\":\"${options.aggregateAssetLineage}\""+
            ",\"providerPromptCapabilityPath\":\"${ckbP6JsonEscape(options.providerPromptCapabilityPath)}\""+
            ",\"providerPromptCapabilityHash\":\"${options.providerPromptCapabilityHash}\""+
            ",\"effectivePromptByteBudget\":${options.effectivePromptByteBudget}"+
            ",\"rulesHash\":\"${persistedContext.rulesHash}\""+
            ",\"rulesTreeHash\":\"${persistedContext.rulesBundleHash}\""+
            ",\"rulesCount\":${persistedContext.rulesCount}"+
            ",\"studentContextCandidateRoot\":\"${ckbP6JsonEscape(options.studentContextCandidateRoot)}\""+
            ",\"studentContextCandidateSetHash\":\"${options.studentContextCandidateSetHash}\""+
            ",\"completionControlPath\":\"${ckbP6JsonEscape(options.completionControlPath)}\""+
            ",\"completionControlHash\":\"${options.completionControlHash}\""+
            ",\"providerIdentityPath\":\"${ckbP6JsonEscape(options.providerIdentityPath)}\""+
            ",\"providerRuntimeExecutablePath\":\"${ckbP6JsonEscape(options.providerRuntimeExecutablePath)}\""
    }
    let manifest = "{\"runId\":\"${ckbP6JsonEscape(options.runId)}\",\"startAllowed\":true,\"fingerprint\":\"${report.fingerprint}\",\"providerIdentityHash\":\"${options.providerIdentityHash}\",\"modelVersion\":\"${ckbP6JsonEscape(options.modelVersion)}\",\"claudeCodeVersion\":\"${ckbP6JsonEscape(options.claudeCodeVersion)}\",\"certificationTransport\":\"${ckbP6JsonEscape(options.certificationTransport)}\",\"transportRetryBudget\":${report.transportRetryBudget},\"modelTimeoutSeconds\":${report.modelTimeoutSeconds},\"candidateChecksum\":\"${options.candidateChecksum}\",\"studentLeakageProofHash\":\"${options.studentLeakageProofHash}\",\"frozenCandidateManifestHash\":\"${options.frozenCandidateManifestHash}\",\"skillBundlePath\":\"${ckbP6JsonEscape(options.skillBundlePath)}\",\"skillBundleHash\":\"${options.skillBundleHash}\",\"skillCount\":${options.skillCount},\"contentBytes\":${options.skillContentBytes},\"assetLineage\":\"${options.assetLineage}\",\"lineageProofHash\":\"${options.lineageProofHash}\",\"samplingCapabilityHash\":\"${options.samplingCapabilityHash}\",\"generationProtocol\":\"${options.generationProtocol}\",\"samplesPerCase\":${options.samplesPerCase},\"outputSchemaHash\":\"${options.outputSchemaHash}\",\"datasetVersion\":\"${ckbP6JsonEscape(options.datasetVersion)}\",\"knowledgeVersion\":\"${ckbP6JsonEscape(options.frozenVersion)}\",\"certificationBinaryHash\":\"${report.certificationBinaryHash}\",\"certificationHttpLaunchSpecHash\":\"${report.certificationHttpLaunchSpecHash}\",\"certificationHttpCommandHash\":\"${report.certificationHttpCommandHash}\",\"preflightHash\":\"${report.preflightHash}\",\"runManifestHash\":\"${report.runManifestHash}\",\"certificationPassAt1\":null${contextFields}}"
    File.writeTo(manifestPath, manifest.toArray()); report.runManifestPath = manifestPath.toString()
}

private func ckbP6DevelopmentClosureDiagnostic(raw: String): String { try { let o=JsonValue.fromStr(raw).asObject(); let cases=o.get("cases").getOrThrow().asArray().getItems(); if(!ckbP6Bool(o,"developmentClosed")||ckbP6Int(o,"developmentTotal")!=164||ckbP6Int(o,"developmentPassed")!=164||ckbP6Int(o,"invalidCaseCount")!=0||ckbP6Int(o,"knowledgeCandidateCount")!=0||cases.size!=164){return "development_closure_incomplete"};let ids=HashSet<String>();for(v in cases){let row=v.asObject();let id=ckbP6String(row,"caseId");if(id==""||ids.contains(id)||!ckbP6Bool(row,"developmentPass")||!ckbP6Bool(row,"valid")){return "development_closure_case_invalid"};ids.add(id)};"ok" } catch(_:Exception){"development_closure_artifact_invalid"} }
private func ckbP6GateArtifactDiagnostic(raw:String,kind:String):String{try{let o=JsonValue.fromStr(raw).asObject();let evidence=ckbP6String(o,"evidence");if(!ckbP6Bool(o,"ok")||ckbP6String(o,"status")!="pass"||evidence==""||ckbP6String(o,"evidenceHash")!=benchmarkGapSha256(evidence)){"${kind}_gate_artifact_invalid"}else{"ok"}}catch(_:Exception){"${kind}_gate_artifact_invalid"}}
private func ckbP6FilesystemProbeDiagnostic(raw:String,workspace:String,runtimeHome:String):String{try{let o=JsonValue.fromStr(raw).asObject();if(!ckbP6Bool(o,"deniedOutsideWorkspace")||!ckbP6Bool(o,"deniedTests")||!ckbP6Bool(o,"deniedReference")||!ckbP6Bool(o,"deniedTeacher")||!ckbP6Bool(o,"deniedStore")||ckbP6String(o,"workspaceCanonical")!=canonicalize(Path(workspace)).toString()||ckbP6String(o,"runtimeHomeCanonical")!=canonicalize(Path(runtimeHome)).toString()){"filesystem_isolation_probe_invalid"}else{"ok"}}catch(_:Exception){"filesystem_isolation_probe_invalid"}}
private func ckbP6ParityHash(rest:String,stdio:String,http:String,frozen:String):String{if(rest==""||rest!=stdio||rest!=http){return ""};try{let o=JsonValue.fromStr(rest).asObject();if(!ckbP6HashFormat(ckbP6String(o,"contentHash"))||ckbP6String(o,"citation")==""||ckbP6String(o,"knowledgeVersion")!=frozen){return ""};benchmarkGapSha256(rest)}catch(_:Exception){""}}
private func ckbP6ProviderIdentityDiagnostic(raw:String,hash:String,model:String,claude:String):String{let lowered=raw.toAsciiLower();for(key in ["\"token\"","\"apikey\"","\"authorization\"","\"password\"","\"secret\""]){if(lowered.contains(key)){return "provider_identity_contains_secret"}};try{let o=JsonValue.fromStr(raw).asObject();if(ckbP6String(o,"provider")==""||ckbP6String(o,"model")!=model||ckbP6String(o,"claudeCodeVersion")!=claude||benchmarkGapSha256(raw)!=hash){"provider_identity_artifact_invalid"}else{"ok"}}catch(_:Exception){"provider_identity_artifact_invalid"}}
private func ckbP6CanonicalPath(path:String):String{try{canonicalize(Path(path)).toString().replace("\\","/")}catch(_:Exception){""}}
private func ckbP6HashFormat(value:String):Bool{if(value.toRuneArray().size!=71||!value.startsWith("sha256:")){return false};for(i in 7..71){let c=value.toRuneArray()[i];if(!((c>=r'0'&&c<=r'9')||(c>=r'a'&&c<=r'f'))){return false}};true}
private func ckbP6String(o:JsonObject,k:String):String{match(o.get(k)){case Some(v)=>v.asString().getValue();case None=>""}}
private func ckbP6Bool(o:JsonObject,k:String):Bool{match(o.get(k)){case Some(v)=>v.asBool().getValue();case None=>false}}
private func ckbP6Int(o:JsonObject,k:String):Int64{match(o.get(k)){case Some(v)=>v.asInt().getValue();case None=>-1}}
private func ckbP6Null(o:JsonObject,k:String):Bool{match(o.get(k)){case Some(v)=>v.toString()=="null";case None=>false}}

private func ckbP6Check(report: CkbCertificationPreflightReport, passed: Bool, diagnostic: String): Unit { if (!passed) { report.checks.add(diagnostic) } }
private func ckbP6Part(value: String): String { "${value.toArray().size}:${value}" }
private func ckbP6ComparableSeed(arm: CkbContributionArm): String {
    ckbP6Part(arm.datasetVersion) + ckbP6Part(arm.manifestHash) + ckbP6Part(arm.modelVersion) + ckbP6Part(arm.claudeCodeVersion) + ckbP6Part(arm.promptHash) + ckbP6Part(arm.toolConfigHash) + ckbP6Part(arm.temperature) + ckbP6Part("${arm.toolBudget}")
}
private func ckbP6JsonEscape(value: String): String { value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t") }
