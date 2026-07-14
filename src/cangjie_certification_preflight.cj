package cangjie_community_knowledge_base

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
    public init() {}
}

public func ckbFrozenFingerprint(input: CkbFrozenFingerprintInput): String {
    benchmarkGapSha256(ckbP6Part(input.knowledgeVersion) + ckbP6Part(input.knowledgeContentHash) +
        ckbP6Part(input.datasetVersion) + ckbP6Part(input.manifestHash) + ckbP6Part(input.modelVersion) +
        ckbP6Part(input.claudeCodeVersion) + ckbP6Part(input.promptHash) + ckbP6Part(input.toolConfigHash) +
        ckbP6Part(input.providerIdentityHash) + ckbP6Part(input.certificationTransport) + ckbP6Part(input.runtimeConfigHash))
}

public func ckbFrozenFingerprintDiagnostic(input: CkbFrozenFingerprintInput): String {
    if (input.knowledgeVersion == "" || input.datasetVersion == "" || input.modelVersion == "" || input.claudeCodeVersion == "" || input.certificationTransport == "") { return "fingerprint_identity_field_required" }
    for (hash in [input.knowledgeContentHash, input.manifestHash, input.promptHash, input.toolConfigHash, input.providerIdentityHash, input.runtimeConfigHash]) {
        if (!ckbP6HashFormat(hash)) { return "fingerprint_canonical_hash_required" }
    }
    if (input.certificationTransport != CkbAbcdeGroups.C && input.certificationTransport != CkbAbcdeGroups.D) { return "fingerprint_transport_invalid" }
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
    public init() {}
}

public class CkbCertificationPreflightOptions {
    public var runId: String = ""
    public var outputRoot: String = ""
    public var workspaceRoot: String = ""
    public var frozenVersion: String = ""
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
    public var budget: CkbCertificationBudget = CkbCertificationBudget()
    public init() {}
}

public class CkbCertificationPreflightReport {
    public var ok: Bool = false
    public var startAllowed: Bool = false
    public var diagnostic: String = ""
    public var fingerprint: String = ""
    public var checks: ArrayList<String> = ArrayList<String>()
    public var certificationPassAt1: ?Bool = None<Bool>
    public var preflightHash: String = ""
    public var runManifestHash: String = ""
    public var runManifestPath: String = ""
    public var providerIdentityHash: String = ""
    public var modelVersion: String = ""
    public var claudeCodeVersion: String = ""
    public var certificationTransport: String = ""
    public init() {}
}

public func runCertificationPreflight(options: CkbCertificationPreflightOptions, fingerprintInput: CkbFrozenFingerprintInput): CkbCertificationPreflightReport {
    let report = CkbCertificationPreflightReport()
    report.fingerprint = ckbFrozenFingerprint(fingerprintInput)
    report.providerIdentityHash=options.providerIdentityHash;report.modelVersion=options.modelVersion;report.claudeCodeVersion=options.claudeCodeVersion;report.certificationTransport=options.certificationTransport
    ckbP6Check(report, ckbFrozenFingerprintDiagnostic(fingerprintInput) == "ok", ckbFrozenFingerprintDiagnostic(fingerprintInput))
    ckbP6Check(report, options.runId != "", "run_identity_required")
    ckbP6Check(report, options.frozenVersion != "" && options.activeVersionAtStart == options.frozenVersion, "frozen_active_version_mismatch")
    ckbP6Check(report, options.activeVersionAtEnd == options.activeVersionAtStart, "knowledge_version_drift")
    ckbP6Check(report, options.expectedManifestHash != "" && options.expectedManifestHash == options.actualManifestHash, "manifest_hash_mismatch")
    ckbP6Check(report, ckbP6DevelopmentClosureDiagnostic(options.developmentClosureJson) == "ok", ckbP6DevelopmentClosureDiagnostic(options.developmentClosureJson))
    ckbP6Check(report, ckbP6GateArtifactDiagnostic(options.knowledgeGateJson, "knowledge") == "ok", ckbP6GateArtifactDiagnostic(options.knowledgeGateJson, "knowledge"))
    ckbP6Check(report, ckbP6GateArtifactDiagnostic(options.releaseGateJson, "release") == "ok", ckbP6GateArtifactDiagnostic(options.releaseGateJson, "release"))
    ckbP6Check(report, options.experimentReport.ok && !options.contributionExperimentSynthetic && ckbP6HashFormat(options.experimentReport.evidenceHash) && options.experimentReport.frozenFingerprint == report.fingerprint, "trusted_contribution_experiment_required")
    let parityHash = ckbP6ParityHash(options.parityRestPayload, options.parityStdioPayload, options.parityHttpPayload, options.frozenVersion)
    ckbP6Check(report, parityHash != "" && parityHash == options.parityEvidenceHash, "transport_parity_required")
    ckbP6Check(report, options.modelVersion != "" && options.claudeCodeVersion != "", "exact_model_versions_required")
    ckbP6Check(report, ckbP6HashFormat(options.providerIdentityHash), "redacted_provider_identity_required")
    ckbP6Check(report, ckbP6ProviderIdentityDiagnostic(options.providerIdentityJson, options.providerIdentityHash, options.modelVersion, options.claudeCodeVersion) == "ok", ckbP6ProviderIdentityDiagnostic(options.providerIdentityJson, options.providerIdentityHash, options.modelVersion, options.claudeCodeVersion))
    ckbP6Check(report, options.certificationTransport == CkbAbcdeGroups.C || options.certificationTransport == CkbAbcdeGroups.D, "single_certification_transport_required")
    ckbP6Check(report, options.runtimeHomeRoot != "" && options.runtimeHomeRoot != options.workspaceRoot && ckbCertificationWorkspaceDiagnostic(options.runtimeHomeRoot) == "ok", "isolated_runtime_home_required")
    ckbP6Check(report, ckbP6FilesystemProbeDiagnostic(options.filesystemProbeJson, options.workspaceRoot, options.runtimeHomeRoot) == "ok", ckbP6FilesystemProbeDiagnostic(options.filesystemProbeJson, options.workspaceRoot, options.runtimeHomeRoot))
    ckbP6Check(report, ckbCertificationBudgetDiagnostic(options.budget) == "ok", ckbCertificationBudgetDiagnostic(options.budget))
    ckbP6Check(report, ckbCertificationWorkspaceDiagnostic(options.workspaceRoot) == "ok", ckbCertificationWorkspaceDiagnostic(options.workspaceRoot))
    ckbP6Check(report, ckbCertificationOutputDiagnostic(options.outputRoot) == "ok", ckbCertificationOutputDiagnostic(options.outputRoot))
    ckbP6Check(report, ckbP6CanonicalPath(options.outputRoot).endsWith("/${options.runId}"), "output_root_run_identity_mismatch")
    ckbP6Check(report, fingerprintInput.knowledgeVersion == options.frozenVersion && fingerprintInput.manifestHash == options.actualManifestHash && fingerprintInput.modelVersion == options.modelVersion && fingerprintInput.claudeCodeVersion == options.claudeCodeVersion && fingerprintInput.providerIdentityHash == options.providerIdentityHash && fingerprintInput.certificationTransport == options.certificationTransport && fingerprintInput.runtimeConfigHash != "", "fingerprint_binding_mismatch")
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
    if (budget.maxTurns != 1) { return "max_turns_must_equal_one" }
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
    "{\"ok\":${report.ok},\"startAllowed\":${report.startAllowed},\"diagnostic\":\"${ckbP6JsonEscape(report.diagnostic)}\",\"fingerprint\":\"${ckbP6JsonEscape(report.fingerprint)}\",\"certificationPassAt1\":null,\"violations\":[${checks}]}"
}

public func cangjieCertificationReleaseGateIntegrated(preflightPath: String, manifestPath: String): CangjieKnowledgeReleaseGateStep {
    let step = CangjieKnowledgeReleaseGateStep(); step.id = "P6-frozen-certification-preflight"
    try {
        let preflight = String.fromUtf8(File.readFrom(Path(preflightPath))); let manifest = String.fromUtf8(File.readFrom(Path(manifestPath)))
        let object = JsonValue.fromStr(manifest).asObject(); let declared = ckbP6String(object, "preflightHash"); let manifestHash = ckbP6String(object, "runManifestHash")
        let actual = benchmarkGapSha256(preflight); let expectedManifest = benchmarkGapSha256(ckbP6Part(ckbP6String(object, "runId")) + ckbP6Part(declared) + ckbP6Part(ckbP6String(object, "fingerprint")) + ckbP6Part(ckbP6String(object,"providerIdentityHash")) + ckbP6Part(ckbP6String(object,"modelVersion")) + ckbP6Part(ckbP6String(object,"claudeCodeVersion")) + ckbP6Part(ckbP6String(object,"certificationTransport")))
        step.ok = declared == actual && manifestHash == expectedManifest && ckbP6Bool(object, "startAllowed") && ckbP6Null(object, "certificationPassAt1")
        step.evidenceHash = if (step.ok) { benchmarkGapSha256(preflight + manifest) } else { "" }
    } catch (_: Exception) { step.ok = false }
    step.status = if (step.ok) { "pass" } else { "fail" }; step.diagnostic = if (step.ok) { "trusted_preflight_manifest_verified" } else { "trusted_preflight_manifest_invalid" }; step
}

private func ckbP6PersistManifest(options: CkbCertificationPreflightOptions, report: CkbCertificationPreflightReport): Unit {
    let preflightPath = Path(options.outputRoot).join("preflight.json"); let manifestPath = Path(options.outputRoot).join("run-manifest.json")
    let preflight = renderCertificationPreflightJson(report); File.writeTo(preflightPath, preflight.toArray()); report.preflightHash = benchmarkGapSha256(preflight)
    report.runManifestHash = benchmarkGapSha256(ckbP6Part(options.runId) + ckbP6Part(report.preflightHash) + ckbP6Part(report.fingerprint) + ckbP6Part(options.providerIdentityHash) + ckbP6Part(options.modelVersion) + ckbP6Part(options.claudeCodeVersion) + ckbP6Part(options.certificationTransport))
    let manifest = "{\"runId\":\"${ckbP6JsonEscape(options.runId)}\",\"startAllowed\":true,\"fingerprint\":\"${report.fingerprint}\",\"providerIdentityHash\":\"${options.providerIdentityHash}\",\"modelVersion\":\"${ckbP6JsonEscape(options.modelVersion)}\",\"claudeCodeVersion\":\"${ckbP6JsonEscape(options.claudeCodeVersion)}\",\"certificationTransport\":\"${ckbP6JsonEscape(options.certificationTransport)}\",\"preflightHash\":\"${report.preflightHash}\",\"runManifestHash\":\"${report.runManifestHash}\",\"certificationPassAt1\":null}"
    File.writeTo(manifestPath, manifest.toArray()); report.runManifestPath = manifestPath.toString()
}

private func ckbP6DevelopmentClosureDiagnostic(raw: String): String { try { let o=JsonValue.fromStr(raw).asObject(); let cases=o.get("cases").getOrThrow().asArray().getItems(); if(!ckbP6Bool(o,"developmentClosed")||ckbP6Int(o,"developmentTotal")!=164||ckbP6Int(o,"developmentPassed")!=164||ckbP6Int(o,"invalidCaseCount")!=0||ckbP6Int(o,"knowledgeCandidateCount")!=0||cases.size!=164){return "development_closure_incomplete"};let ids=HashSet<String>();for(v in cases){let row=v.asObject();let id=ckbP6String(row,"caseId");if(id==""||ids.contains(id)||!ckbP6Bool(row,"developmentPass")||!ckbP6Bool(row,"valid")){return "development_closure_case_invalid"};ids.add(id)};"ok" } catch(_:Exception){"development_closure_artifact_invalid"} }
private func ckbP6GateArtifactDiagnostic(raw:String,kind:String):String{try{let o=JsonValue.fromStr(raw).asObject();let evidence=ckbP6String(o,"evidence");if(!ckbP6Bool(o,"ok")||ckbP6String(o,"status")!="pass"||evidence==""||ckbP6String(o,"evidenceHash")!=benchmarkGapSha256(evidence)){"${kind}_gate_artifact_invalid"}else{"ok"}}catch(_:Exception){"${kind}_gate_artifact_invalid"}}
private func ckbP6FilesystemProbeDiagnostic(raw:String,workspace:String,runtimeHome:String):String{try{let o=JsonValue.fromStr(raw).asObject();if(!ckbP6Bool(o,"deniedOutsideWorkspace")||!ckbP6Bool(o,"deniedTests")||!ckbP6Bool(o,"deniedReference")||!ckbP6Bool(o,"deniedTeacher")||ckbP6String(o,"workspaceCanonical")!=canonicalize(Path(workspace)).toString()||ckbP6String(o,"runtimeHomeCanonical")!=canonicalize(Path(runtimeHome)).toString()){"filesystem_isolation_probe_invalid"}else{"ok"}}catch(_:Exception){"filesystem_isolation_probe_invalid"}}
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
