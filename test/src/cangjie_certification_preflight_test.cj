package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.collection.*
import std.time.*

@Test
public class CangjieCertificationPreflightTest {
    @TestCase
    public func p6CliNeg01SecretArtifactsAreRejectedWithoutEchoingValues(): Unit {
        @Expect(ckbControlContainsSecret("{\"authorization\":\"Bearer private-value\"}"), true)
        @Expect(ckbControlContainsSecret("{\"api_key\":\"私密🙂\"}"), true)
        @Expect(ckbControlContainsSecret("{\"provider\":\"glm\",\"model\":\"GLM-5.2\"}"), false)
    }

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
        let report = runCkbContributionExperiment(baseline, treatment, frozenFingerprint: ckbFrozenFingerprint(p6Fingerprint()))
        @Expect(report.ok, true)
        @Expect(report.certificationPassAt1.isNone(), true)
    }

    @TestCase
    public func p6Bnd01ActiveVersionDriftFailsClosedBeforeCaseStart(): Unit {
        let output = p6EmptyOutput("../target/p6-bnd-empty")
        let options = p6Preflight(output)
        options.activeVersionAtEnd = "knowledge-v2"
        let report = runCertificationPreflight(options, p6Fingerprint())
        @Expect(report.ok, false)
        @Expect(report.startAllowed, false)
        @Expect(report.checks.contains("knowledge_version_drift"), true)
        @Expect(report.certificationPassAt1.isNone(), true)
        options.frozenCandidateManifestJson = "{}"
        options.frozenCandidateManifestHash = benchmarkGapSha256(options.frozenCandidateManifestJson)
        let invalidFrozen = runCertificationPreflight(options, p6Fingerprint())
        @Expect(invalidFrozen.checks.contains("frozen_candidate_manifest_invalid"), true)
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
    public func p6Neg01ForbiddenPathsAndRetryLayersAreRejected(): Unit {
        let testsPath=p6EmptyOutput("../target/p6-path/tests/hidden"); let referencePath=p6EmptyOutput("../target/p6-path/reference/work"); let teacherPath=p6EmptyOutput("../target/p6-path/teacher-solutions/work")
        @Expect(ckbCertificationWorkspaceDiagnostic(testsPath), "forbidden_workspace_segment:tests")
        @Expect(ckbCertificationWorkspaceDiagnostic(referencePath), "forbidden_workspace_segment:reference")
        @Expect(ckbCertificationWorkspaceDiagnostic(teacherPath), "forbidden_workspace_segment:teacher-solutions")
        let budget = CkbCertificationBudget()
        budget.agentAttempts = 2
        @Expect(ckbCertificationBudgetDiagnostic(budget), "agent_attempt_budget_must_equal_one")
        budget.agentAttempts = 1; budget.providerRetries = 1
        @Expect(ckbCertificationBudgetDiagnostic(budget), "provider_retry_must_be_zero")
        budget.providerRetries = 0; budget.sdkRetries = 1
        @Expect(ckbCertificationBudgetDiagnostic(budget), "sdk_retry_must_be_zero")
        budget.sdkRetries = 0; budget.maxTurns = 0
        @Expect(ckbCertificationBudgetDiagnostic(budget), "internal_turn_budget_must_be_positive")
        budget.maxTurns = 21
        @Expect(ckbCertificationBudgetDiagnostic(budget), "ok")
        budget.transportRetries = -1
        @Expect(ckbCertificationBudgetDiagnostic(budget), "transport_retry_budget_must_be_0_to_10")
        budget.transportRetries = 2
        @Expect(ckbCertificationBudgetDiagnostic(budget), "ok")
        budget.knowledgeRestRetries = 3
        @Expect(ckbCertificationBudgetDiagnostic(budget), "knowledge_rest_retry_must_be_zero")

        let options = p6Preflight(p6EmptyOutput("../target/p6-neg-empty"))
        options.experimentReport = CkbContributionExperimentReport()
        let report = runCertificationPreflight(options, p6Fingerprint())
        @Expect(report.startAllowed, true)
        @Expect(report.checks.contains("trusted_contribution_experiment_required"), false)
        options.filesystemProbeJson = "{\"deniedOutsideWorkspace\":false}"
        let unsafeReport = runCertificationPreflight(options, p6Fingerprint())
        @Expect(unsafeReport.checks.contains("filesystem_isolation_probe_invalid"), true)
        options.filesystemProbeJson = "{}"; options.developmentClosureJson = "{malformed中文😀"
        let malformed = runCertificationPreflight(options, p6Fingerprint())
        @Expect(malformed.checks.contains("development_closure_artifact_invalid"), true)
        options.developmentClosureJson=p6ClosureJson(); options.providerIdentityHash="sha256:fake"; options.parityHttpPayload="tampered"
        let tampered = runCertificationPreflight(options, p6Fingerprint())
        @Expect(tampered.checks.contains("redacted_provider_identity_required"), true)
        @Expect(tampered.checks.contains("transport_parity_required"), true)
        let secretOptions=p6Preflight(p6EmptyOutput("../target/p6-secret-${DateTime.now().toUnixTimeStamp().toMilliseconds()}"));secretOptions.providerIdentityJson="{\"provider\":\"redacted\",\"model\":\"GLM-5.2\",\"claudeCodeVersion\":\"claude-code-1.0\",\"token\":\"must-not-land\"}";secretOptions.providerIdentityHash=benchmarkGapSha256(secretOptions.providerIdentityJson)
        @Expect(runCertificationPreflight(secretOptions,p6Fingerprint()).checks.contains("provider_identity_contains_secret"),true)
    }

    @TestCase
    public func p6E2e01ContributionFreezePreflightAndReleaseGateDoNotCertify(): Unit {
        let baseline = p6Arm("no-ckb", false, "baseline-ws", "baseline-session", "baseline-home")
        baseline.passed = 100; baseline.knowledgeHits = 0
        let treatment = p6Arm("frozen-ckb", true, "treatment-ws", "treatment-session", "treatment-home")
        treatment.passed = 164; treatment.knowledgeHits = 164
        let experiment = runCkbContributionExperiment(baseline, treatment, frozenFingerprint: ckbFrozenFingerprint(p6Fingerprint()))
        @Expect(experiment.ok, true)
        @Expect(experiment.passDelta, 64)
        @Expect(experiment.knowledgeHitDelta, 164)

        let output = p6EmptyOutput("../target/p6-e2e-${DateTime.now().toUnixTimeStamp().toMilliseconds()}")
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
        @Expect(exists(Path(report.runManifestPath)), true)
        let integrated = cangjieCertificationReleaseGateIntegrated("${output}/preflight.json", "${output}/run-manifest.json")
        @Expect(integrated.ok, true)
        let manifestText=String.fromUtf8(File.readFrom(Path("${output}/run-manifest.json")))
        @Expect(manifestText.contains("\"providerIdentityHash\":"),true)
        @Expect(manifestText.contains("\"modelVersion\":\"GLM-5.2\""),true)
        File.writeTo(Path("${output}/run-manifest.json"),manifestText.replace("\"modelVersion\":\"GLM-5.2\"","\"modelVersion\":\"tampered\"").toArray())
        @Expect(cangjieCertificationReleaseGateIntegrated("${output}/preflight.json", "${output}/run-manifest.json").ok,false)
    }

    @TestCase
    public func r7Ut10PreflightSealsComputedCertificationHttpProvenance(): Unit {
        let output=p6EmptyOutput("../target/p6-r7-provenance-${DateTime.now().toUnixTimeStamp().toMilliseconds()}")
        let options=p6Preflight(output);let fingerprint=p6Fingerprint()
        let report=runCertificationPreflight(options,fingerprint)
        @Expect(report.ok,true);@Expect(report.certificationBinaryHash,ckbAbcdeBinaryHash(options.certificationBinaryPath))
        @Expect(report.certificationHttpLaunchSpecHash,ckbAbcdeCertificationHttpLaunchSpecHash(report.certificationBinaryHash,options.certificationConfigPath,options.certificationStorePath,options.certificationRunRoot,options.certificationHttpBase))
        @Expect(report.certificationHttpCommandHash,benchmarkGapSha256(ckbAbcdeCertificationHttpLaunchScript(options.certificationBinaryPath,options.certificationConfigPath,options.certificationStorePath,options.certificationRunRoot)))
        let preflight=String.fromUtf8(File.readFrom(Path(output).join("preflight.json")));let manifestPath=Path(output).join("run-manifest.json");let manifest=String.fromUtf8(File.readFrom(manifestPath))
        @Expect(ckbCertificationPreflightSealDiagnostic(preflight,manifest),"ok")
        File.writeTo(Path(options.certificationConfigPath),(String.fromUtf8(File.readFrom(Path(options.certificationConfigPath)))+"# drift\n").toArray())
        @Expect(ckbAbcdeCertificationHttpLaunchSpecHash(report.certificationBinaryHash,options.certificationConfigPath,options.certificationStorePath,options.certificationRunRoot,options.certificationHttpBase)==report.certificationHttpLaunchSpecHash,false)
        @Expect(ckbCertificationPreflightSealDiagnostic(preflight,manifest.replace("certificationBinaryHash","tamperedCertificationBinaryHash")),"preflight_manifest_seal_mismatch")
        @Expect(ckbCertificationPreflightSealDiagnostic(preflight,manifest.replace(report.certificationHttpCommandHash,benchmarkGapSha256("wrong-command"))),"preflight_manifest_seal_mismatch")
        @Expect(ckbCertificationPreflightSealDiagnostic(preflight.replace(report.providerIdentityHash,benchmarkGapSha256("wrong-provider")),manifest),"preflight_manifest_seal_mismatch")
    }
}

private func p6Fingerprint(): CkbFrozenFingerprintInput {
    let input = CkbFrozenFingerprintInput()
    input.knowledgeVersion = "knowledge-v1"; input.knowledgeContentHash = benchmarkGapSha256("knowledge"); input.datasetVersion = "dataset-v1"
    input.manifestHash = benchmarkGapSha256("manifest"); input.modelVersion = "GLM-5.2"; input.claudeCodeVersion = "claude-code-1.0"
    input.promptHash = benchmarkGapSha256("prompt"); input.toolConfigHash = benchmarkGapSha256("tools")
    input.providerIdentityHash = benchmarkGapSha256("{\"provider\":\"redacted-provider\",\"model\":\"GLM-5.2\",\"claudeCodeVersion\":\"claude-code-1.0\"}"); input.certificationTransport = CkbAbcdeGroups.D; input.runtimeConfigHash = benchmarkGapSha256("runtime-config")
    input.candidateChecksum=input.knowledgeContentHash;input.studentLeakageProofHash=benchmarkGapSha256("{\"ok\":true,\"status\":\"pass\"}");input.frozenCandidateManifestHash=benchmarkGapSha256(p6FrozenManifest(input.candidateChecksum,input.studentLeakageProofHash))
    let bundle=p6SkillBundle();input.skillBundleVersion=bundle.bundleVersion;input.skillBundleHash=bundle.canonicalHash;input.skillCount=bundle.skillCount;input.skillContentBytes=bundle.contentBytes;input.samplingCapabilityHash=benchmarkGapSha256(p6SamplingCapability());input.generationProtocol="completion-only-v1";input.outputSchemaHash=benchmarkGapSha256(ckbAbcdeCompletionOutputSchema());input.assetLineage="independent";input.lineageProofHash=benchmarkGapSha256(p6LineageProof())
    input
}

private func p6Arm(name: String, enabled: Bool, workspace: String, session: String, home: String): CkbContributionArm {
    let arm = CkbContributionArm()
    arm.name = name; arm.ckbEnabled = enabled; arm.workspaceId = workspace; arm.sessionId = session; arm.runtimeHomeId = home
    arm.datasetVersion = "dataset-v1"; arm.manifestHash = benchmarkGapSha256("manifest"); arm.modelVersion = "GLM-5.2"; arm.claudeCodeVersion = "claude-code-1.0"
    arm.promptHash = benchmarkGapSha256("prompt"); arm.toolConfigHash = benchmarkGapSha256("tools"); arm.temperature = "0"; arm.toolBudget = 3
    arm.total = 164; arm.passed = 120; arm.knowledgeHits = if (enabled) { 120 } else { 0 }; arm.failureClassificationHash = benchmarkGapSha256("classified-${name}")
    arm.resultArtifactJson="{\"arm\":\"${name}\",\"passed\":120,\"total\":164}";arm.isolationSetJson="{\"workspace\":\"${workspace}\",\"session\":\"${session}\",\"runtimeHome\":\"${home}\"}";arm.resultArtifactHash=benchmarkGapSha256(arm.resultArtifactJson); arm.isolationSetHash=benchmarkGapSha256(arm.isolationSetJson)
    if(enabled){arm.frozenKnowledgeVersion="knowledge-v1";arm.frozenKnowledgeContentHash=benchmarkGapSha256("knowledge")}
    arm
}

private func p6Preflight(output: String): CkbCertificationPreflightOptions {
    let options = CkbCertificationPreflightOptions()
    options.runId = Path(output).fileName; options.outputRoot = output; options.workspaceRoot = p6EmptyOutput("../target/p6-workspace/case-workspace")
    let certificationRoot=p6EmptyOutput("../target/p6-http-provenance/${options.runId}");let config=Path(certificationRoot).join("runtime.conf");File.writeTo(config,"service.bind=127.0.0.1\nservice.port=19873\n".toArray());options.certificationBinaryPath=canonicalize(Path("../target/release/bin/main")).toString();options.certificationConfigPath=canonicalize(config).toString();options.certificationStorePath=canonicalize(Path(p6EmptyOutput("${certificationRoot}/store"))).toString();options.certificationRunRoot=canonicalize(Path(p6EmptyOutput("${certificationRoot}/run"))).toString();options.certificationHttpBase="http://127.0.0.1:19873"
    options.frozenVersion = "knowledge-v1"; options.activeVersionAtStart = "knowledge-v1"; options.activeVersionAtEnd = "knowledge-v1"
    options.expectedManifestHash = benchmarkGapSha256("manifest"); options.actualManifestHash = benchmarkGapSha256("manifest")
    options.developmentClosed = 164; options.expectedCases = 164; options.unresolvedNonKnowledgeFailures = 0
    options.knowledgeTestsPassed = true; options.releaseGatePassed = true; options.contributionExperimentPassed = true
    options.modelVersion = "GLM-5.2"; options.claudeCodeVersion = "claude-code-1.0"
    options.providerIdentityJson="{\"provider\":\"redacted-provider\",\"model\":\"GLM-5.2\",\"claudeCodeVersion\":\"claude-code-1.0\"}";options.providerIdentityHash = benchmarkGapSha256(options.providerIdentityJson); options.certificationTransport = CkbAbcdeGroups.D
    options.runtimeHomeRoot = p6EmptyOutput("../target/p6-runtime/runtime-home"); options.filesystemIsolationEnforced = true
    options.developmentClosureJson=p6ClosureJson(); options.knowledgeGateJson=p6Gate("knowledge-gate"); options.releaseGateJson=p6Gate("release-gate")
    let wc=canonicalize(Path(options.workspaceRoot)).toString();let rc=canonicalize(Path(options.runtimeHomeRoot)).toString();options.filesystemProbeJson="{\"deniedOutsideWorkspace\":true,\"deniedTests\":true,\"deniedReference\":true,\"deniedTeacher\":true,\"deniedStore\":true,\"workspaceCanonical\":\"${wc}\",\"runtimeHomeCanonical\":\"${rc}\"}"
    options.parityRestPayload="{\"atomIds\":[\"A\"],\"contentHash\":\"${benchmarkGapSha256("atom")}\",\"citation\":\"官方中文😀\",\"knowledgeVersion\":\"knowledge-v1\"}";options.parityStdioPayload=options.parityRestPayload;options.parityHttpPayload=options.parityRestPayload;options.parityEvidenceHash=benchmarkGapSha256(options.parityRestPayload)
    options.candidateChecksum=benchmarkGapSha256("knowledge");options.studentLeakageProofJson="{\"ok\":true,\"status\":\"pass\"}";options.studentLeakageProofHash=benchmarkGapSha256(options.studentLeakageProofJson);options.frozenCandidateManifestJson=p6FrozenManifest(options.candidateChecksum,options.studentLeakageProofHash);options.frozenCandidateManifestHash=benchmarkGapSha256(options.frozenCandidateManifestJson)
    let bundle=p6SkillBundle();options.skillBundlePath=Path(certificationRoot).join("student-skills.json").toString();File.writeTo(Path(options.skillBundlePath),(bundle.json+"\n").toArray());options.skillBundleVersion=bundle.bundleVersion;options.skillBundleHash=bundle.canonicalHash;options.skillCount=bundle.skillCount;options.skillContentBytes=bundle.contentBytes
    options.samplingCapabilityPath=Path(certificationRoot).join("sampling.json").toString();File.writeTo(Path(options.samplingCapabilityPath),p6SamplingCapability().toArray());options.samplingCapabilityHash=benchmarkGapSha256(p6SamplingCapability());options.generationProtocol="completion-only-v1";options.samplesPerCase=1;options.outputSchemaHash=benchmarkGapSha256(ckbAbcdeCompletionOutputSchema());options.assetLineage="independent";options.lineageProofPath=Path(certificationRoot).join("lineage.json").toString();options.lineageProofJson=p6LineageProof();File.writeTo(Path(options.lineageProofPath),options.lineageProofJson.toArray());options.lineageProofHash=benchmarkGapSha256(options.lineageProofJson)
    let baseline=p6Arm("no-ckb",false,"pre-w1","pre-s1","pre-h1");let treatment=p6Arm("frozen-ckb",true,"pre-w2","pre-s2","pre-h2");options.experimentReport=runCkbContributionExperiment(baseline,treatment,frozenFingerprint: ckbFrozenFingerprint(p6Fingerprint()))
    options
}

private func p6SkillBundle():CkbStudentSkillBundleBuild{let candidate=parseStudentSkillCandidateDirectory("fixtures/teacher_skill_candidate/static-boundary-review",true);compileStudentSkillBundle("student-skills-v1",ArrayList<CkbStudentSkillCandidate>([candidate]))}
private func p6SamplingCapability():String{"{\"schemaVersion\":\"ckb-completion-sampling-capability-v1\",\"samplingControl\":\"provider_default_not_client_exposed\"}\n"}
private func p6LineageProof():String{"{\"assetLineage\":\"independent\",\"source\":\"non_humaneval_seed\"}\n"}

private func p6ClosureJson():String{var rows="";for(i in 0..164){if(i>0){rows+=","};rows+="{\"caseId\":\"CJ-HUMANEVAL-${i}\",\"developmentPass\":true,\"valid\":true}"};"{\"developmentClosed\":true,\"developmentPassed\":164,\"developmentTotal\":164,\"knowledgeCandidateCount\":0,\"invalidCaseCount\":0,\"certifiedPassAt1\":null,\"cases\":[${rows}]}"}
private func p6FrozenManifest(candidate:String,leakage:String):String{let h={v:String=>benchmarkGapSha256(v)};let body="{\"schemaVersion\":\"ckb-frozen-candidate-v1\",\"knowledgeVersion\":\"knowledge-v1\",\"txIdHash\":\"${h("tx")}\",\"activePointerHash\":\"${h("pointer")}\",\"transactionHash\":\"${h("transaction")}\",\"candidateChecksum\":\"${candidate}\",\"inputHash\":\"${h("input")}\",\"configHash\":\"${h("config")}\",\"modelHash\":\"${h("model")}\",\"studentLeakageProofHash\":\"${leakage}\",\"authorityIsolationArtifactHash\":\"${h("authority")}\",\"anonymousQueryArtifactHash\":\"${h("query")}\",\"atomTestArtifactHash\":\"${h("atom")}\"";body+",\"evidenceHash\":\"${h(body+"}")}\"}"}
private func p6Gate(evidence:String):String{"{\"ok\":true,\"status\":\"pass\",\"evidence\":\"${evidence}\",\"evidenceHash\":\"${benchmarkGapSha256(evidence)}\"}"}

private func p6Observation(transport: String): CkbAbcdeParityObservation {
    let observation = CkbAbcdeParityObservation()
    observation.transport = transport; observation.ok = true; observation.evidenceHash = "sha256:same-payload"; observation.coveragePass = true; observation.citationCount = 2; observation.diagnostic = "ok"
    observation
}

private func p6EmptyOutput(path: String): String {
    let root = Path(path)
    if (exists(root)) { remove(root, recursive: true) }
    Directory.create(root, recursive: true)
    path
}
