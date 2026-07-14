package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*
import std.fs.{Directory, Path, exists}
import std.collection.*

@Test
public class CangjieCertificationPreflightTest {
    @TestCase
    public func p6Ut01FrozenFingerprintIsDeterministicAndFieldBound(): Unit {
        let input = p6Fingerprint()
        let first = ckbFrozenFingerprint(input)
        let second = ckbFrozenFingerprint(input)
        @Expect(first, second)
        @Expect(first.startsWith("sha256:"), true)
        input.promptHash = "sha256:changed-中文😀"
        @Expect(ckbFrozenFingerprint(input) == first, false)

        let baseline = p6Arm("no-ckb", false, "ws-a", "session-a", "home-a")
        let treatment = p6Arm("frozen-ckb", true, "ws-b", "session-b", "home-b")
        let report = runCkbContributionExperiment(baseline, treatment)
        @Expect(report.ok, true)
        @Expect(report.certificationPassAt1.isNone(), true)
    }

    @TestCase
    public func p6Bnd01ActiveVersionDriftFailsClosedBeforeCaseStart(): Unit {
        let output = p6EmptyOutput("target/p6-bnd-empty")
        let options = p6Preflight(output)
        options.activeVersionAtEnd = "knowledge-v2"
        let report = runCertificationPreflight(options, p6Fingerprint())
        @Expect(report.ok, false)
        @Expect(report.startAllowed, false)
        @Expect(report.checks.contains("knowledge_version_drift"), true)
        @Expect(report.certificationPassAt1.isNone(), true)
    }

    @TestCase
    public func p6Pos01RestStdioHttpPayloadEvidenceParityIsRequired(): Unit {
        let rest = p6Observation("rest")
        let stdio = p6Observation("mcp_stdio")
        let http = p6Observation("mcp_http")
        @Expect(ckbAbcdeCertificationTransportParity(rest, stdio, http), true)
        http.evidenceHash = "sha256:different"
        @Expect(ckbAbcdeCertificationTransportParity(rest, stdio, http), false)
    }

    @TestCase
    public func p6Neg01ForbiddenPathsRetryLayersAndSyntheticEvidenceAreRejected(): Unit {
        @Expect(ckbCertificationWorkspaceDiagnostic("/tmp/case/tests/hidden"), "forbidden_workspace_path:/test")
        @Expect(ckbCertificationWorkspaceDiagnostic("/tmp/reference/solution"), "forbidden_workspace_path:/reference")
        @Expect(ckbCertificationWorkspaceDiagnostic("/tmp/teacher-solutions/CJ-HUMANEVAL-000"), "forbidden_workspace_path:/teacher")
        let budget = CkbCertificationBudget()
        budget.agentAttempts = 2
        @Expect(ckbCertificationBudgetDiagnostic(budget), "agent_attempt_budget_must_equal_one")
        budget.agentAttempts = 1; budget.providerRetries = 1
        @Expect(ckbCertificationBudgetDiagnostic(budget), "provider_retry_must_be_zero")
        budget.providerRetries = 0; budget.sdkRetries = 1
        @Expect(ckbCertificationBudgetDiagnostic(budget), "sdk_retry_must_be_zero")
        budget.sdkRetries = 0; budget.maxTurns = 2
        @Expect(ckbCertificationBudgetDiagnostic(budget), "max_turns_must_equal_one")
        budget.maxTurns = 1; budget.knowledgeRestRetries = 3
        @Expect(ckbCertificationBudgetDiagnostic(budget), "knowledge_rest_retry_must_be_zero")

        let options = p6Preflight(p6EmptyOutput("target/p6-neg-empty"))
        options.contributionExperimentSynthetic = true
        let report = runCertificationPreflight(options, p6Fingerprint())
        @Expect(report.startAllowed, false)
        @Expect(report.checks.contains("trusted_contribution_experiment_required"), true)
        options.contributionExperimentSynthetic = false; options.filesystemIsolationEnforced = false
        let unsafeReport = runCertificationPreflight(options, p6Fingerprint())
        @Expect(unsafeReport.checks.contains("filesystem_isolation_not_enforced"), true)
    }

    @TestCase
    public func p6E2e01ContributionFreezePreflightAndReleaseGateDoNotCertify(): Unit {
        let baseline = p6Arm("no-ckb", false, "baseline-ws", "baseline-session", "baseline-home")
        baseline.passed = 100; baseline.knowledgeHits = 0
        let treatment = p6Arm("frozen-ckb", true, "treatment-ws", "treatment-session", "treatment-home")
        treatment.passed = 164; treatment.knowledgeHits = 164
        let experiment = runCkbContributionExperiment(baseline, treatment)
        @Expect(experiment.ok, true)
        @Expect(experiment.passDelta, 64)
        @Expect(experiment.knowledgeHitDelta, 164)

        let output = p6EmptyOutput("target/p6-e2e-empty")
        let options = p6Preflight(output)
        options.contributionExperimentPassed = experiment.ok
        let report = runCertificationPreflight(options, p6Fingerprint())
        @Expect(report.ok, true)
        @Expect(report.startAllowed, true)
        @Expect(report.certificationPassAt1.isNone(), true)
        let json = renderCertificationPreflightJson(report)
        @Expect(json.contains("\"certificationPassAt1\":null"), true)
        @Expect(json.contains("中文"), false)
        let gate = cangjieCertificationReleaseGate(report)
        @Expect(gate.ok, true)
        @Expect(gate.evidenceHash.startsWith("sha256:"), true)
    }
}

private func p6Fingerprint(): CkbFrozenFingerprintInput {
    let input = CkbFrozenFingerprintInput()
    input.knowledgeVersion = "knowledge-v1"; input.knowledgeContentHash = "sha256:knowledge"; input.datasetVersion = "dataset-v1"
    input.manifestHash = "sha256:manifest"; input.modelVersion = "GLM-5.2"; input.claudeCodeVersion = "claude-code-1.0"
    input.promptHash = "sha256:prompt"; input.toolConfigHash = "sha256:tools"
    input.providerIdentityHash = "sha256:0123456789abcdef"; input.certificationTransport = CkbAbcdeGroups.C; input.runtimeConfigHash = "sha256:runtime-config"
    input
}

private func p6Arm(name: String, enabled: Bool, workspace: String, session: String, home: String): CkbContributionArm {
    let arm = CkbContributionArm()
    arm.name = name; arm.ckbEnabled = enabled; arm.workspaceId = workspace; arm.sessionId = session; arm.runtimeHomeId = home
    arm.datasetVersion = "dataset-v1"; arm.manifestHash = "sha256:manifest"; arm.modelVersion = "GLM-5.2"; arm.claudeCodeVersion = "claude-code-1.0"
    arm.promptHash = "sha256:prompt"; arm.toolConfigHash = "sha256:tools"; arm.temperature = "0"; arm.toolBudget = 3
    arm.total = 164; arm.passed = 120; arm.knowledgeHits = if (enabled) { 120 } else { 0 }; arm.failureClassificationHash = "sha256:classified-${name}"
    arm
}

private func p6Preflight(output: String): CkbCertificationPreflightOptions {
    let options = CkbCertificationPreflightOptions()
    options.runId = "p6-run"; options.outputRoot = output; options.workspaceRoot = "/tmp/ckb-certification/case-workspace"
    options.frozenVersion = "knowledge-v1"; options.activeVersionAtStart = "knowledge-v1"; options.activeVersionAtEnd = "knowledge-v1"
    options.expectedManifestHash = "sha256:manifest"; options.actualManifestHash = "sha256:manifest"
    options.developmentClosed = 164; options.expectedCases = 164; options.unresolvedNonKnowledgeFailures = 0
    options.knowledgeTestsPassed = true; options.releaseGatePassed = true; options.contributionExperimentPassed = true
    options.parityPassed = true; options.parityEvidenceHash = "sha256:parity"; options.modelVersion = "GLM-5.2"; options.claudeCodeVersion = "claude-code-1.0"
    options.providerIdentityHash = "sha256:0123456789abcdef"; options.certificationTransport = CkbAbcdeGroups.C
    options.runtimeHomeRoot = "/tmp/ckb-certification/runtime-home"; options.filesystemIsolationEnforced = true
    options
}

private func p6Observation(transport: String): CkbAbcdeParityObservation {
    let observation = CkbAbcdeParityObservation()
    observation.transport = transport; observation.ok = true; observation.evidenceHash = "sha256:same-payload"; observation.coveragePass = true; observation.citationCount = 2; observation.diagnostic = "ok"
    observation
}

private func p6EmptyOutput(path: String): String {
    let root = Path(path)
    if (!exists(root)) { Directory.create(root, recursive: true) }
    path
}
