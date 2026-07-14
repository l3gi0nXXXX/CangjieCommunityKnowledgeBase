package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}

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
    public init() {}
}

public func runCkbContributionExperiment(baseline: CkbContributionArm, treatment: CkbContributionArm): CkbContributionExperimentReport {
    let report = CkbContributionExperimentReport()
    let diagnostic = ckbContributionExperimentDiagnostic(baseline, treatment)
    report.diagnostic = diagnostic
    report.ok = diagnostic == "ok"
    report.baselinePassRate = "${baseline.passed}/${baseline.total}"
    report.treatmentPassRate = "${treatment.passed}/${treatment.total}"
    report.passDelta = treatment.passed - baseline.passed
    report.knowledgeHitDelta = treatment.knowledgeHits - baseline.knowledgeHits
    report.comparisonFingerprint = benchmarkGapSha256(ckbP6ComparableSeed(baseline))
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
    public init() {}
}

public func runCertificationPreflight(options: CkbCertificationPreflightOptions, fingerprintInput: CkbFrozenFingerprintInput): CkbCertificationPreflightReport {
    let report = CkbCertificationPreflightReport()
    report.fingerprint = ckbFrozenFingerprint(fingerprintInput)
    ckbP6Check(report, options.runId != "", "run_identity_required")
    ckbP6Check(report, options.frozenVersion != "" && options.activeVersionAtStart == options.frozenVersion, "frozen_active_version_mismatch")
    ckbP6Check(report, options.activeVersionAtEnd == options.activeVersionAtStart, "knowledge_version_drift")
    ckbP6Check(report, options.expectedManifestHash != "" && options.expectedManifestHash == options.actualManifestHash, "manifest_hash_mismatch")
    ckbP6Check(report, options.developmentClosed == options.expectedCases && options.expectedCases == 164, "development_closure_incomplete")
    ckbP6Check(report, options.unresolvedNonKnowledgeFailures == 0, "nonknowledge_failure_unresolved")
    ckbP6Check(report, options.knowledgeTestsPassed, "knowledge_tests_required")
    ckbP6Check(report, options.releaseGatePassed, "release_gate_required")
    ckbP6Check(report, options.contributionExperimentPassed && !options.contributionExperimentSynthetic, "trusted_contribution_experiment_required")
    ckbP6Check(report, options.parityPassed && options.parityEvidenceHash != "", "transport_parity_required")
    ckbP6Check(report, options.modelVersion != "" && options.claudeCodeVersion != "", "exact_model_versions_required")
    ckbP6Check(report, options.providerIdentityHash.startsWith("sha256:") && !options.providerIdentityHash.contains("GLM") && !options.providerIdentityHash.contains("http"), "redacted_provider_identity_required")
    ckbP6Check(report, options.certificationTransport == CkbAbcdeGroups.C || options.certificationTransport == CkbAbcdeGroups.D, "single_certification_transport_required")
    ckbP6Check(report, options.runtimeHomeRoot != "" && options.runtimeHomeRoot != options.workspaceRoot && ckbCertificationWorkspaceDiagnostic(options.runtimeHomeRoot) == "ok", "isolated_runtime_home_required")
    ckbP6Check(report, options.filesystemIsolationEnforced, "filesystem_isolation_not_enforced")
    ckbP6Check(report, ckbCertificationBudgetDiagnostic(options.budget) == "ok", ckbCertificationBudgetDiagnostic(options.budget))
    ckbP6Check(report, ckbCertificationWorkspaceDiagnostic(options.workspaceRoot) == "ok", ckbCertificationWorkspaceDiagnostic(options.workspaceRoot))
    ckbP6Check(report, ckbCertificationOutputDiagnostic(options.outputRoot) == "ok", ckbCertificationOutputDiagnostic(options.outputRoot))
    ckbP6Check(report, fingerprintInput.knowledgeVersion == options.frozenVersion && fingerprintInput.manifestHash == options.actualManifestHash && fingerprintInput.modelVersion == options.modelVersion && fingerprintInput.claudeCodeVersion == options.claudeCodeVersion && fingerprintInput.providerIdentityHash == options.providerIdentityHash && fingerprintInput.certificationTransport == options.certificationTransport && fingerprintInput.runtimeConfigHash != "", "fingerprint_binding_mismatch")
    report.ok = report.checks.size == 0
    report.startAllowed = report.ok
    report.diagnostic = if (report.ok) { "ok" } else { report.checks[0] }
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
    let normalized = path.replace("\\", "/").toAsciiLower()
    if (normalized == "") { return "workspace_required" }
    for (segment in ["/test", "/tests", "/reference", "/references", "/teacher", "/teacher-solutions", "/solution"]) {
        if (normalized.contains(segment)) { return "forbidden_workspace_path:${segment}" }
    }
    "ok"
}

public func ckbCertificationOutputDiagnostic(path: String): String {
    if (path.trimAscii() == "") { return "output_root_required" }
    let root = Path(path)
    if (!exists(root)) { return "output_root_must_preexist" }
    try {
        for (_ in Directory.readFrom(root)) { return "output_root_not_empty" }
    } catch (_: Exception) { return "output_root_unreadable" }
    "ok"
}

public func renderCertificationPreflightJson(report: CkbCertificationPreflightReport): String {
    var checks = ""
    for (i in 0..report.checks.size) { if (i > 0) { checks += "," }; checks += "\"${ckbP6JsonEscape(report.checks[i])}\"" }
    "{\"ok\":${report.ok},\"startAllowed\":${report.startAllowed},\"diagnostic\":\"${ckbP6JsonEscape(report.diagnostic)}\",\"fingerprint\":\"${ckbP6JsonEscape(report.fingerprint)}\",\"certificationPassAt1\":null,\"violations\":[${checks}]}"
}

private func ckbP6Check(report: CkbCertificationPreflightReport, passed: Bool, diagnostic: String): Unit { if (!passed) { report.checks.add(diagnostic) } }
private func ckbP6Part(value: String): String { "${value.toArray().size}:${value}" }
private func ckbP6ComparableSeed(arm: CkbContributionArm): String {
    ckbP6Part(arm.datasetVersion) + ckbP6Part(arm.manifestHash) + ckbP6Part(arm.modelVersion) + ckbP6Part(arm.claudeCodeVersion) + ckbP6Part(arm.promptHash) + ckbP6Part(arm.toolConfigHash) + ckbP6Part(arm.temperature) + ckbP6Part("${arm.toolBudget}")
}
private func ckbP6JsonEscape(value: String): String { value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t") }
