package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.*
import std.env.getVariable
import std.fs.{Directory, File, Path, exists, canonicalize}
import std.process.*

@Test
public class CangjieEvalAbcdeRunnerTest {
    // S7R-UT-01: N configured transport retries permit at most N+1 attempts.
    @TestCase
    public func s7rUt01DevelopmentRetryBudgetMapsToTotalAttempts(): Unit {
        @Expect(ckbAbcdeDevelopmentTransportAttemptLimitForTest(3), 4)
        @Expect(ckbAbcdeDevelopmentTransportAttemptLimitForTest(7), 8)
    }

    // S7R-BND-01: the accepted CLI boundaries have no off-by-one error.
    @TestCase
    public func s7rBnd01DevelopmentRetryBudgetBoundaries(): Unit {
        @Expect(ckbAbcdeDevelopmentTransportAttemptLimitForTest(0), 1)
        @Expect(ckbAbcdeDevelopmentTransportAttemptLimitForTest(10), 11)
        let base="target/s7r-boundary-${ckbCoreNowMillis()}";let workspace="${base}/workspace";let authority="${base}/authority";let pointer="${base}/active-version"
        Directory.create(Path("${workspace}/src"),recursive:true);Directory.create(Path("${authority}/src"),recursive:true);File.writeTo(Path("${workspace}/src/solution.cj"),"original".toArray());File.writeTo(Path("${authority}/src/solution.cj"),"original".toArray());File.writeTo(Path(pointer),"knowledge-v1\n".toArray())
        let incomplete="{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"GLM-5.2\"}\n"
        let zero=ckbAbcdeRunFakeTransportRetryForTest("${base}/zero",workspace,authority,pointer,[124],["timeout"],[incomplete],"GLM-5.2",0);@Expect(zero.contains("\"transportAttemptCount\":1"),true)
        let upper=ckbAbcdeRunFakeTransportRetryForTest("${base}/upper",workspace,authority,pointer,[124,124,124,124,124,124,124,124,124,124,124],["timeout","timeout","timeout","timeout","timeout","timeout","timeout","timeout","timeout","timeout","timeout"],[incomplete,incomplete,incomplete,incomplete,incomplete,incomplete,incomplete,incomplete,incomplete,incomplete,incomplete],"GLM-5.2",10);@Expect(upper.contains("\"transportAttemptCount\":11"),true)
    }

    // S7R-POS-01: each retryable transport failure restores the authoritative workspace.
    @TestCase
    public func s7rPos01DevelopmentTransientFailuresRecoverWithinBudget(): Unit {
        let base="target/s7r-transient-${ckbCoreNowMillis()}";let workspace="${base}/workspace";let authority="${base}/authority";let pointer="${base}/active-version"
        Directory.create(Path("${workspace}/src"),recursive:true);Directory.create(Path("${authority}/src"),recursive:true);File.writeTo(Path("${workspace}/src/solution.cj"),"mutated".toArray());File.writeTo(Path("${authority}/src/solution.cj"),"authoritative".toArray());File.writeTo(Path(pointer),"knowledge-v1\n".toArray())
        let incomplete="{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"GLM-5.2\"}\n";let success=incomplete+"{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false}\n"
        let result=ckbAbcdeRunFakeTransportRetryForTest("${base}/run",workspace,authority,pointer,[124,1,1,0],["model timeout","connection reset by peer","HTTP 503 service unavailable",""],[incomplete,incomplete,incomplete,success],"GLM-5.2",3)
        @Expect(result.contains("\"transportAttemptCount\":4"),true);@Expect(result.contains("\"sampleAttemptCount\":1"),true);@Expect(result.contains("\"lineageDiagnostic\":\"ok\""),true)
        @Expect(String.fromUtf8(File.readFrom(Path("${workspace}/src/solution.cj"))),"authoritative")
        let restores=String.fromUtf8(File.readFrom(Path("${base}/run/fake-restores.jsonl")));@Expect(restores.split("\n").size,4);@Expect(restores.contains("\"transportAttempt\":4"),true)
    }

    // S7R-NEG-01: business samples and non-retryable failures stop immediately.
    @TestCase
    public func s7rNeg01DevelopmentStopsAfterBusinessOrNonRetryableResult(): Unit {
        let base="target/s7r-stop-${ckbCoreNowMillis()}";let workspace="${base}/workspace";let authority="${base}/authority";let pointer="${base}/active-version"
        Directory.create(Path("${workspace}/src"),recursive:true);Directory.create(Path("${authority}/src"),recursive:true);File.writeTo(Path("${workspace}/src/solution.cj"),"original".toArray());File.writeTo(Path("${authority}/src/solution.cj"),"original".toArray());File.writeTo(Path(pointer),"knowledge-v1\n".toArray())
        let incomplete="{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"GLM-5.2\"}\n";let success=incomplete+"{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false}\n";let wrongModel="{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"other\"}\n{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false}\n"
        let business=ckbAbcdeRunFakeTransportRetryForTest("${base}/business",workspace,authority,pointer,[0,0],["",""],[success,success],"GLM-5.2",10);@Expect(business.contains("\"transportAttemptCount\":1"),true);@Expect(business.contains("\"sampleAttemptCount\":1"),true)
        let identity=ckbAbcdeRunFakeTransportRetryForTest("${base}/identity",workspace,authority,pointer,[0,0],["identity mismatch",""],[wrongModel,success],"GLM-5.2",10);@Expect(identity.contains("\"transportAttemptCount\":1"),true);@Expect(identity.contains("\"sampleAttemptCount\":0"),true)
        let auth=ckbAbcdeRunFakeTransportRetryForTest("${base}/auth",workspace,authority,pointer,[1,0],["authentication failed",""],[incomplete,success],"GLM-5.2",10);@Expect(auth.contains("\"transportAttemptCount\":1"),true);@Expect(auth.contains("\"sampleAttemptCount\":0"),true)
    }

    // S7R-REG-01: retry changes neither sandbox isolation nor pass@1 sample semantics.
    @TestCase
    public func s7rReg01DevelopmentRetryPreservesIsolationAndSingleSample(): Unit {
        let root="target/s7r-isolation-${ckbCoreNowMillis()}";let workspace="${root}/workspace";let home="${root}/runtime-home";let store="${root}/store";let caseSrc="${root}/case";let docs="${root}/docs";let sdk="${root}/sdk";let macSdk="${root}/mac-sdk"
        for(path in [workspace,home,store,"${caseSrc}/tests","${caseSrc}/translation",docs,sdk,macSdk]){Directory.create(Path(path),recursive:true)}
        let profile=ckbAbcdeDevelopmentSandboxProfile(CkbAbcdeGroups.D,workspace,home,"/bin/true","config",store,caseSrc,docs,sdk,macSdk,"/bin/true","/bin/true")
        @Expect(profile.contains("(deny file-read*"),true);@Expect(profile.contains("${caseSrc}/tests"),true);@Expect(profile.contains("${caseSrc}/translation"),true);@Expect(profile.contains("CangjieTeacher"),true)
        let pointer="${root}/active-version";File.writeTo(Path(pointer),"knowledge-v1\n".toArray());Directory.create(Path("${workspace}/src"),recursive:true);let authority="${root}/authority";Directory.create(Path("${authority}/src"),recursive:true);File.writeTo(Path("${workspace}/src/solution.cj"),"original".toArray());File.writeTo(Path("${authority}/src/solution.cj"),"original".toArray())
        let incomplete="{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"GLM-5.2\"}\n";let success=incomplete+"{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false}\n";let result=ckbAbcdeRunFakeTransportRetryForTest("${root}/run",workspace,authority,pointer,[124,0],["timeout",""],[incomplete,success],"GLM-5.2",10)
        @Expect(result.contains("\"sampleAttemptCount\":1"),true);@Expect(result.contains("\"transportAttemptCount\":2"),true);@Expect(result.contains("\"frozenPointerUnchanged\":true"),true)
    }

    @TestCase
    public func r7Ut00OwnedCertificationHttpRejectsUnsafeBaseAndLeavesNoProcess():Unit{
        @Expect(ckbAbcdeCertificationPortDiagnostic("https://example.com"),"certification_http_loopback_required")
        let root="target/r7-owned-http-${ckbCoreNowMillis()}";Directory.create(Path(root),recursive:true);let fake=Path(root).join("fake-http");File.writeTo(fake,"#!/bin/zsh\ntrap '' TERM\ni=0; while [ $i -lt 20000 ]; do print 'burst-中文🙂'; print -u2 'stderr-burst'; i=$((i+1)); done\nwhile true; do sleep 1; done\n".toArray());@Expect(launch("/bin/chmod",["700",fake.toString()]).wait(),0)
        let script=ckbAbcdeCertificationHttpLaunchScript(fake.toString(),"config","store",root);let child=launch("/bin/zsh",["-lc",script],stdOut:ProcessRedirect.Pipe,stdErr:ProcessRedirect.Pipe);_=launch("/bin/sleep",["1"]).wait();@Expect(child.pid>0,true);@Expect(ckbAbcdeStopOwnedCertificationHttpWithEscalation(child.pid),"kill");_=child.wait();@Expect(launch("/bin/kill",["-0","${child.pid}"]).wait()!=0,true);@Expect(File.readFrom(Path(root).join("certification-http.stdout.log")).size>65536,true);@Expect(File.readFrom(Path(root).join("certification-http.stderr.log")).size>65536,true)
    }
    // T-R7-UT: transport retry classification is independent from business samples.
    @TestCase
    public func r7Ut01OnlyExplicitTransportFailuresAreRetryable(): Unit {
        let incomplete = CkbAbcdeSampleAssessment()
        @Expect(ckbAbcdeShouldRetryTransport(124, incomplete, diagnostic: "model timeout"), true)
        let emptyTranscript = ckbAbcdeAssessSample("", "GLM-5.2")
        @Expect(emptyTranscript.transcriptDiagnostic, "empty_transcript")
        @Expect(ckbAbcdeTransportClassification(124, emptyTranscript, ""), "timeout")
        @Expect(ckbAbcdeShouldRetryTransport(124, emptyTranscript), true)
        let invalidEncoding = CkbAbcdeSampleAssessment(); invalidEncoding.transcriptDiagnostic = "invalid_response_encoding"
        @Expect(ckbAbcdeTransportClassification(124, invalidEncoding, ""), "non_retryable_transport_error")
        @Expect(ckbAbcdeShouldRetryTransport(124, invalidEncoding), false)
        let malformed = ckbAbcdeAssessSample("{malformed", "GLM-5.2")
        @Expect(malformed.transcriptDiagnostic, "malformed_json")
        @Expect(ckbAbcdeShouldRetryTransport(124, malformed), false)
        let oversized = CkbAbcdeSampleAssessment(); oversized.transcriptDiagnostic = "transcript_too_large"
        @Expect(ckbAbcdeShouldRetryTransport(124, oversized), false)
        let protocol = CkbAbcdeSampleAssessment(); protocol.transcriptDiagnostic = "protocol_violation"
        @Expect(ckbAbcdeShouldRetryTransport(124, protocol), false)
        @Expect(ckbAbcdeShouldRetryTransport(1, incomplete, diagnostic: "connection reset by peer"), true)
        @Expect(ckbAbcdeShouldRetryTransport(1, incomplete, diagnostic: "HTTP 503 service unavailable"), true)
        @Expect(ckbAbcdeShouldRetryTransport(1, incomplete, diagnostic: "unknown process failure"), false)
        @Expect(ckbAbcdeShouldRetryTransport(1, incomplete, diagnostic: "invalid_response_encoding"), false)
        @Expect(ckbAbcdeShouldRetryTransport(1, incomplete, diagnostic: "protocol violation: malformed JSON"), false)
        let identityDrift = CkbAbcdeSampleAssessment(); identityDrift.completeResult = true; identityDrift.identityMatched = false
        @Expect(ckbAbcdeShouldRetryTransport(0, identityDrift, diagnostic: "service unavailable text in answer"), false)
        let business = CkbAbcdeSampleAssessment(); business.completeResult = true; business.identityMatched = true; business.sampleAttempt = 1
        @Expect(ckbAbcdeShouldRetryTransport(0, business, diagnostic: "tests failed"), false)
        @Expect(ckbAbcdeTransportClassification(124,business,"timeout"),"timeout")
        @Expect(ckbAbcdeRenderModelTransportDiagnostic("",124,business,180,"certification","").contains("\"sampleEligible\":false"),true)
        let successfulTool=ckbAbcdeAssessSample("{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"GLM-5.2\"}\n{\"type\":\"tool_result\",\"is_error\":false}\n","GLM-5.2")
        @Expect(ckbAbcdeTransportClassification(1,successfulTool,"HTTP 503 service unavailable"),"service_unavailable")
        @Expect(ckbAbcdeShouldRetryTransport(1,successfulTool,diagnostic:"HTTP 503 service unavailable"),true)
        let failedTool=ckbAbcdeAssessSample("{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"GLM-5.2\"}\n{\"type\":\"tool_result\",\"is_error\":true}\n","GLM-5.2")
        @Expect(ckbAbcdeTransportClassification(1,failedTool,"HTTP 503 service unavailable"),"knowledge_transport_failure")
        @Expect(ckbAbcdeShouldRetryTransport(1,failedTool,diagnostic:"HTTP 503 service unavailable"),false)
        @Expect(ckbAbcdeTransportClassification(124,failedTool,""),"knowledge_transport_failure")
        @Expect(ckbAbcdeShouldRetryTransport(124,failedTool),false)
        @Expect(ckbAbcdeTransportClassification(124,emptyTranscript,"mcp_error"),"knowledge_transport_failure")
        @Expect(ckbAbcdeShouldRetryTransport(124,emptyTranscript,diagnostic:"knowledge_transport_failure"),false)
    }

    @TestCase
    public func r7Ut02NoRetryInitializesReadableEmptyRestoreEvidence(): Unit {
        let root = "target/r7-no-retry-restores-${ckbCoreNowMillis()}"
        Directory.create(Path(root), recursive: true)
        let restores = Path(root).join("workspace-restores.jsonl")
        File.writeTo(restores, "stale-restore\n".toArray())
        ckbAbcdeInitializeWorkspaceRestoreEvidenceForTest(root)
        @Expect(exists(restores), true)
        @Expect(String.fromUtf8(File.readFrom(restores)), "")
    }

    @TestCase
    public func r7Neg02UnsafeStderrBytesAreDestroyedAndNeverPublished():Unit{
        let root="target/r7-stderr-${ckbCoreNowMillis()}";Directory.create(Path(root),recursive:true);let evidence="${root}/attempt.stderr";let runtime="${root}/runtime.stderr"
        File.writeTo(Path(evidence),[0xff,0xfe,0x80]);File.writeTo(Path(runtime),[0xff,0xfe,0x80]);let invalid=ckbAbcdeSanitizeStderrArtifact(evidence,runtime);@Expect(invalid.ok,false);@Expect(invalid.diagnostic,"invalid_response_encoding");@Expect(String.fromUtf8(File.readFrom(Path(evidence))),"invalid_response_encoding");@Expect(exists(Path(runtime)),false)
        let oversized=StringBuilder();for(_ in 0..70000){oversized.append("x")};File.writeTo(Path(evidence),oversized.toString().toArray());let large=ckbAbcdeSanitizeStderrArtifact(evidence,"");@Expect(large.ok,false);@Expect(large.diagnostic,"diagnostic_too_large");@Expect(String.fromUtf8(File.readFrom(Path(evidence))),"diagnostic_too_large")
        let auth="${root}/auth.stderr";File.writeTo(Path(auth),"Authorization: Bearer top-secret-token\n中文🙂".toArray());let redacted=ckbAbcdeSanitizeStderrArtifact(auth,"");@Expect(redacted.ok,true);let persisted=String.fromUtf8(File.readFrom(Path(auth)));@Expect(persisted.contains("top-secret-token"),false);@Expect(persisted.contains("Authorization"),false);@Expect(persisted.contains("中文🙂"),true)
    }
    @TestCase
    public func r7Neg04UnsafeTranscriptDestroysEvidenceAndRuntimeOriginals():Unit{
        let root="target/r7-transcript-${ckbCoreNowMillis()}";Directory.create(Path(root),recursive:true);let evidence="${root}/attempt.jsonl";let runtime="${root}/runtime.jsonl"
        File.writeTo(Path(evidence),[0xff,0xfe,0x80]);File.writeTo(Path(runtime),[0xff,0xfe,0x80]);let invalid=ckbAbcdeSanitizeTranscriptArtifact(evidence,runtime);@Expect(invalid.ok,false);@Expect(invalid.diagnostic,"invalid_response_encoding");@Expect(String.fromUtf8(File.readFrom(Path(evidence))),"");@Expect(exists(Path(runtime)),false)
        let large=StringBuilder();for(_ in 0..4200000){large.append("x")};File.writeTo(Path(evidence),large.toString().toArray());File.writeTo(Path(runtime),large.toString().toArray());let oversized=ckbAbcdeSanitizeTranscriptArtifact(evidence,runtime);@Expect(oversized.ok,false);@Expect(oversized.diagnostic,"transcript_too_large");@Expect(File.readFrom(Path(evidence)).size,0);@Expect(exists(Path(runtime)),false)
    }
    @TestCase
    public func r7Neg05Exit124TerminalCannotBecomeBusinessSampleOrPassRecompute():Unit{
        let success="{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"GLM-5.2\"}\n{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false}\n";let assessment=ckbAbcdeAssessSample(success,"GLM-5.2");@Expect(assessment.sampleAttempt,1);@Expect(ckbAbcdeTransportClassification(124,assessment,"timeout"),"timeout");@Expect(ckbAbcdeShouldRetryTransport(124,assessment,diagnostic:"timeout"),true)
        let root="target/r7-exit124-terminal-${ckbCoreNowMillis()}";Directory.create(Path(root).join("runtime-home/attempt-1"),recursive:true);r7WriteAttemptArtifacts(root,success,"{\"ok\":true}","session");let attempts=String.fromUtf8(File.readFrom(Path(root).join("claude-attempts.jsonl"))).replace("\"exitCode\":0","\"exitCode\":124");File.writeTo(Path(root).join("claude-attempts.jsonl"),attempts.toArray());@Expect(ckbAbcdeAttemptArtifactsDiagnostic(root),"transport_attempt_recompute_mismatch")
    }
    @TestCase
    public func r7Neg03AttemptTimeoutMustEqualFrozenRuntimePolicy():Unit{
        let root="target/r7-timeout-policy-${ckbCoreNowMillis()}";Directory.create(Path(root).join("runtime-home/attempt-1"),recursive:true);let probe="{\"ok\":true}";let transcript="{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"GLM-5.2\"}\n{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false}\n";r7WriteAttemptArtifacts(root,transcript,probe,"session");@Expect(ckbAbcdeAttemptArtifactsDiagnostic(root),"ok");_=launch("/bin/rm",["-f","${root}/runtime-policy.json"]).wait();File.writeTo(Path(root).join("runtime-policy.json"),"{\"model\":\"GLM-5.2\",\"modelTimeoutSeconds\":321}".toArray());@Expect(ckbAbcdeAttemptArtifactsDiagnostic(root),"transport_timeout_policy_mismatch")
    }

    // T-R7-BND/POS/NEG: a recovered transport lineage has one business sample and a bound restore.
    @TestCase
    public func r7Bnd01TransportLineageRequiresContiguousAttemptsAndRestoreEvidence(): Unit {
        let before=benchmarkGapSha256("mutated");let authority=benchmarkGapSha256("original");let restoreBase="{\"transportAttempt\":2,\"restored\":true,\"beforeHash\":\"${before}\",\"authorityHash\":\"${authority}\",\"afterHash\":\"${authority}\",\"diagnostic\":\"ok\"}";let restore=restoreBase.replace("}",",\"evidenceHash\":\"${benchmarkGapSha256(restoreBase)}\"}")
        let restoreHash = benchmarkGapSha256(restore)
        let attempts = "{\"transportAttempt\":1,\"sampleAttempt\":0,\"classification\":\"timeout\",\"workspaceRestored\":false,\"restoreEvidenceHash\":\"\",\"sessionIdHash\":\"${benchmarkGapSha256("session-1")}\",\"runtimeHomeId\":\"${benchmarkGapSha256("home-1")}\",\"sandboxProbeHash\":\"${benchmarkGapSha256("probe-1")}\",\"transcriptHash\":\"${benchmarkGapSha256("transcript-1")}\",\"stderrHash\":\"${benchmarkGapSha256("stderr-1")}\",\"diagnosticHash\":\"${benchmarkGapSha256("diagnostic-1")}\"}\n" +
            "{\"transportAttempt\":2,\"sampleAttempt\":1,\"classification\":\"business_sample\",\"workspaceRestored\":true,\"restoreEvidenceHash\":\"${restoreHash}\",\"sessionIdHash\":\"${benchmarkGapSha256("session-2")}\",\"runtimeHomeId\":\"${benchmarkGapSha256("home-2")}\",\"sandboxProbeHash\":\"${benchmarkGapSha256("probe-2")}\",\"transcriptHash\":\"${benchmarkGapSha256("transcript-2")}\",\"stderrHash\":\"${benchmarkGapSha256("stderr-2")}\",\"diagnosticHash\":\"${benchmarkGapSha256("diagnostic-2")}\"}\n"
        @Expect(ckbAbcdeAttemptLineageDiagnostic(attempts, restore + "\n", 2, 1), "ok")
        @Expect(ckbAbcdeAttemptLineageHash(attempts, restore + "\n").startsWith("sha256:"), true)
        @Expect(ckbAbcdeAttemptLineageDiagnostic(attempts.replace("\"workspaceRestored\":true", "\"workspaceRestored\":false"), restore + "\n", 2, 1), "transport_restore_binding_invalid")
        @Expect(ckbAbcdeAttemptLineageDiagnostic(attempts.replace("\"transportAttempt\":2", "\"transportAttempt\":3"), restore + "\n", 2, 1), "transport_attempt_sequence_invalid")
        @Expect(ckbAbcdeAttemptLineageDiagnostic(attempts.replace("\"sampleAttempt\":0", "\"sampleAttempt\":1"), restore + "\n", 2, 2), "business_sample_count_invalid")
    }

    // E2E-TRUST-02: fake transport exercises the certification retry state machine without a model call.
    @TestCase
    public func r7E2e01FakeTransportRecoversWithoutCreatingExtraBusinessSamples(): Unit {
        let base="target/r7-fake-transport-${ckbCoreNowMillis()}";let workspace="${base}/workspace";let authority="${base}/authority";let pointer="${base}/active-version"
        Directory.create(Path("${workspace}/src"),recursive:true);Directory.create(Path("${authority}/src"),recursive:true);File.writeTo(Path("${workspace}/src/solution.cj"),"original".toArray());File.writeTo(Path("${authority}/src/solution.cj"),"original".toArray());File.writeTo(Path(pointer),"knowledge-v1\n".toArray())
        let incomplete="{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"GLM-5.2\"}\n";let success=incomplete+"{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false}\n"
        let recovered=ckbAbcdeRunFakeTransportRetryForTest("${base}/recovered",workspace,authority,pointer,[124,1,1,0],["model timeout","connection reset by peer","HTTP 503 service unavailable",""],[incomplete,incomplete,incomplete,success],"GLM-5.2",3)
        @Expect(recovered.contains("\"transportAttemptCount\":4"),true);@Expect(recovered.contains("\"sampleAttemptCount\":1"),true);@Expect(recovered.contains("\"retryCount\":3"),true);@Expect(recovered.contains("\"lineageDiagnostic\":\"ok\""),true);@Expect(recovered.contains("\"frozenPointerUnchanged\":true"),true)
        let attempts=String.fromUtf8(File.readFrom(Path("${base}/recovered/fake-attempts.jsonl")));@Expect(attempts.contains("\"classification\":\"timeout\""),true);@Expect(attempts.contains("\"classification\":\"connection_interrupted\""),true);@Expect(attempts.contains("\"classification\":\"service_unavailable\""),true);@Expect(attempts.contains("\"classification\":\"business_sample\""),true)
        @Expect(exists(Path("${base}/recovered/runtime-home/attempt-1")),true);@Expect(exists(Path("${base}/recovered/runtime-home/attempt-4")),true);@Expect(String.fromUtf8(File.readFrom(Path(pointer))),"knowledge-v1\n")
        let wrongModel="{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"other\"}\n{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false}\n"
        let identity=ckbAbcdeRunFakeTransportRetryForTest("${base}/identity",workspace,authority,pointer,[0,0],["",""],[wrongModel,success],"GLM-5.2",1);@Expect(identity.contains("\"transportAttemptCount\":1"),true);@Expect(identity.contains("\"sampleAttemptCount\":0"),true)
        let protocol=ckbAbcdeRunFakeTransportRetryForTest("${base}/protocol",workspace,authority,pointer,[1,0],["protocol violation: malformed JSON",""],[incomplete,success],"GLM-5.2",1);@Expect(protocol.contains("\"transportAttemptCount\":1"),true);@Expect(protocol.contains("\"sampleAttemptCount\":0"),true)
        let business=ckbAbcdeRunFakeTransportRetryForTest("${base}/business",workspace,authority,pointer,[0,0],["tests failed",""],[success,success],"GLM-5.2",1);@Expect(business.contains("\"transportAttemptCount\":1"),true);@Expect(business.contains("\"sampleAttemptCount\":1"),true)
    }
    @TestCase
    public func r7E2e02ExhaustedTransportUsesLastAuditedAttemptAndRendersValidUnresolved():Unit{
        let root="target/r7-exhausted-renderer-${ckbCoreNowMillis()}";let workspace="${root}/workspace";let home="${root}/runtime-home/attempt-1";Directory.create(Path("${workspace}/src"),recursive:true);Directory.create(Path(home),recursive:true);File.writeTo(Path("${workspace}/src/solution.cj"),"answer".toArray());let answerHash=benchmarkGapSha256("answer")
        let authority=cangjieHumanEvalRenderAuthorityManifest(buildCangjieHumanEvalManifest("cangjie_eval/cases/Cangjie-HumanEval",""));let options=CkbAbcdeRunnerOptions();options.runId="r7-exhausted";options.runMode="certification";options.datasetVersion=parseCangjieHumanEvalAuthorityManifest(authority).datasetVersion;options.knowledgeVersion="knowledge-v1";options.modelFingerprint="fingerprint";options.expectedModelVersion="GLM-5.2";options.providerIdentityHash=benchmarkGapSha256("provider");options.manifestPath="${root}/authority.jsonl";options.certificationPreflightPath="${root}/preflight.json";options.certificationRunManifestPath="${root}/run-manifest.json";options.providerIdentityArtifactPath="${root}/provider.json"
        File.writeTo(Path(options.manifestPath),authority.toArray());File.writeTo(Path(options.certificationPreflightPath),"preflight".toArray());File.writeTo(Path(options.certificationRunManifestPath),"{\"runManifestHash\":\"${benchmarkGapSha256("manifest")}\"}".toArray());File.writeTo(Path(options.providerIdentityArtifactPath),"provider".toArray());File.writeTo(Path("${root}/mcp-config.json"),"{}".toArray());File.writeTo(Path("${root}/runtime-policy.json"),"{\"model\":\"GLM-5.2\",\"modelTimeoutSeconds\":180}".toArray());File.writeTo(Path("${root}/paired-tool-evidence.json"),"{}".toArray());File.writeTo(Path("${root}/canonical-task-context.json"),"{}".toArray())
        let transcript="{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"GLM-5.2\"}\n";let probe="{\"ok\":true,\"deniedOutsideWorkspace\":true,\"deniedTests\":true,\"deniedReference\":true,\"deniedTeacher\":true,\"deniedStore\":true,\"workspaceCanonical\":\"${canonicalize(Path(workspace)).toString()}\",\"runtimeHomeCanonical\":\"${canonicalize(Path(home)).toString()}\"}";let diagnosticJson=ckbAbcdeRenderModelTransportDiagnostic(transcript,124,ckbAbcdeAssessSample(transcript,"GLM-5.2"),180,"certification","")+"\n";let session="last-audited-session"
        File.writeTo(Path("${root}/claude-transcript.attempt-1.jsonl"),transcript.toArray());File.writeTo(Path("${root}/claude.attempt-1.stderr.log"),"timeout".toArray());File.writeTo(Path("${root}/sandbox-probe.attempt-1.json"),probe.toArray());File.writeTo(Path("${root}/session-id.attempt-1.txt"),session.toArray());File.writeTo(Path("${root}/model-transport-diagnostic.attempt-1.json"),diagnosticJson.toArray());File.writeTo(Path("${root}/workspace-restores.jsonl"),"".toArray());let attempt="{\"attempt\":1,\"transportAttempt\":1,\"modelTimeoutSeconds\":180,\"sampleAttempt\":0,\"exitCode\":124,\"classification\":\"timeout\",\"completeResult\":false,\"identityMatched\":true,\"workspaceRestored\":false,\"restoreEvidenceHash\":\"\",\"sessionIdHash\":\"${benchmarkGapSha256(session)}\",\"runtimeHomeId\":\"${benchmarkGapSha256(canonicalize(Path(home)).toString())}\",\"sandboxProbeHash\":\"${benchmarkGapSha256(probe)}\",\"transcriptHash\":\"${benchmarkGapSha256(transcript)}\",\"stderrHash\":\"${benchmarkGapSha256("timeout")}\",\"diagnosticHash\":\"${benchmarkGapSha256(diagnosticJson)}\"}\n";File.writeTo(Path("${root}/claude-attempts.jsonl"),attempt.toArray());let summary="{\"transportAttemptCount\":1,\"sampleAttemptCount\":0,\"lastAuditedTransportAttempt\":1,\"selectedBusinessSample\":0,\"selectedTransportAttempt\":0,\"retryCount\":0,\"unresolvedTransport\":1,\"attemptLineageHash\":\"${ckbAbcdeAttemptLineageHash(attempt,"")}\",\"workspaceRestoreEvidenceHash\":\"${benchmarkGapSha256("")}\"}";File.writeTo(Path("${root}/attempt-evidence.json"),summary.toArray());File.writeTo(Path("${root}/test-result.json"),summary.toArray());File.writeTo(Path("${root}/verifier-mount.json"),"{\"injectExitCode\":0,\"answerHashBefore\":\"${answerHash}\",\"answerHashAfter\":\"${answerHash}\",\"mountedAfterFreeze\":true}".toArray());ckbAbcdePublishLastAuditedCertificationArtifactsForTest(root,1)
        let rendered=ckbAbcdeRenderStrictCertificationCaseForTest(options,"CJ-HUMANEVAL-145",CkbAbcdeGroups.D,root,answerHash,transcript,"tests failed",false,"none",false);let row=parseCkbCertificationEvidence(rendered);@Expect(row.valid,true);@Expect(row.sampleAttemptCount,0);@Expect(row.lastAuditedTransportAttempt,1);@Expect(row.selectedBusinessSample,0);@Expect(row.unresolvedTransport,1);@Expect(row.certificationPassAt1,false);@Expect(row.runtimeHomeId,benchmarkGapSha256(canonicalize(Path(home)).toString()));@Expect(exists(Path("${root}/runtime-home/attempt-0")),false);@Expect(String.fromUtf8(File.readFrom(Path("${root}/session-id.txt"))),session);@Expect(String.fromUtf8(File.readFrom(Path("${root}/sandbox-probe.json"))),probe)
    }
    // ABCDE-CONFIG-UT/BND/POS/NEG: the frozen runtime config is an explicit
    // runner input and every stdio path receives the same safely quoted path.
    @TestCase
    public func abcdeConfigContractIsExplicitAndSharedByEveryStdioPath(): Unit {
        let root = "target/abcde config 仓颉🙂-${ckbCoreNowMillis()}"
        Directory.create(Path(root), recursive: true)
        let config = canonicalize(Path(root)).join("formal config 仓颉🙂.conf").toString()
        File.writeTo(Path(config), "network.enabled=false\n".toArray())
        let args = ["cangjie-eval-abcde", "--run-mode", "development", "--dataset-version", "dataset-v1",
            "--candidate-version", "candidate-v1", "--knowledge-version", "knowledge-v1",
            "--model-fingerprint", "claude-code-glm-5.2", "--claude-bin", "/usr/bin/true",
            "--config", config, "--groups", "C"]
        let options = parseCkbAbcdeRunnerOptions(args)
        @Expect(options.ckbConfig, config)
        @Expect(ckbAbcdeDevelopmentOptionsDiagnostic(options), "")
        let taskContext = ckbAbcdeSmokeTaskContextJsonForTest()
        let rendered = renderCkbAbcdeMcpConfig(CkbAbcdeGroups.C, "/tmp/ckb", config,
            "/tmp/store with space 仓颉🙂", "http://127.0.0.1:18890", taskContextJson: taskContext)
        @Expect(rendered.contains("'--config' '${config}' '--store' '/tmp/store with space 仓颉🙂' 'mcp-stdio'"), true)
        @Expect(rendered.contains("--bound-task-context-base64"), true)
        let stdioArgs = ckbAbcdeMcpStdioArgumentsForTest(options)
        @Expect(stdioArgs.size, 5)
        @Expect(stdioArgs[0], "--config")
        @Expect(stdioArgs[1], config)
        @Expect(stdioArgs[2], "--store")
        @Expect(stdioArgs[3], options.ckbStore)
        @Expect(stdioArgs[4], "mcp-stdio")

        let missing = parseCkbAbcdeRunnerOptions(["cangjie-eval-abcde", "--run-mode", "development",
            "--dataset-version", "dataset", "--candidate-version", "candidate", "--knowledge-version", "knowledge",
            "--model-fingerprint", "model", "--claude-bin", "/usr/bin/true", "--groups", "C"])
        @Expect(ckbAbcdeDevelopmentOptionsDiagnostic(missing), "ckb_config_required")
        missing.ckbConfig = "relative/escape 仓颉🙂.conf"
        @Expect(ckbAbcdeDevelopmentOptionsDiagnostic(missing), "ckb_config_must_be_absolute")
    }

    @TestCase
    public func ckg12Ut001ParsesCaseIdGroupsAndSkipClaude(): Unit {
        let options = parseCkbAbcdeRunnerOptions(["cangjie-eval-abcde", "--case-id", "CJ-HUMANEVAL-007", "--groups", "A,C,E", "--claude-bin", "/tmp/claude", "--skip-claude"])

        @Expect(options.caseStart, 7)
        @Expect(options.caseEnd, 7)
        @Expect(options.skipClaude, true)
        @Expect(options.groups.size, 3)
        @Expect(options.groups[0], CkbAbcdeGroups.A)
        @Expect(options.groups[1], CkbAbcdeGroups.C)
        @Expect(options.groups[2], CkbAbcdeGroups.E)
        @Expect(options.claudeBin, "/tmp/claude")
    }

    // CLAUDE-BIN-UT/POS/E2E-01
    @TestCase
    public func nkUt05ExplicitClaudeExecutableBindsCommandAndSandbox(): Unit {
        let root = "target/claude-bin-contract-${ckbCoreNowMillis()}"
        _ = launch("/bin/rm", ["-rf", root]).wait()
        Directory.create(Path("${root}/install/bin"), recursive: true)
        Directory.create(Path("${root}/install/lib"), recursive: true)
        let canonical = "${root}/install/lib/claude.exe"
        File.writeTo(Path(canonical), "#!/bin/zsh\nexit 0\n".toArray())
        @Expect(launch("/bin/chmod", ["700", canonical]).wait(), 0)
        let requested = "${root}/install/bin/claude"
        @Expect(launch("/bin/ln", ["-s", "../lib/claude.exe", requested]).wait(), 0)
        let requestedAbsolute = canonicalize(Path(root)).join("install/bin/claude").toString()
        let executable = ckbAbcdeResolveClaudeExecutable(requestedAbsolute)
        @Expect(executable.valid, true)
        @Expect(executable.diagnostic, "ok")
        @Expect(executable.canonical, canonicalize(Path(canonical)).toString())
        let command = ckbAbcdeDevelopmentClaudeCommand("/tmp/group", "/tmp/home", "/tmp/profile.sb",
            executable.canonical, "GLM-5.2", "max", "", "", "--add-dir '/tmp/workspace'",
            ckbAbcdeSandboxTranscriptPath("/tmp/home"), ckbAbcdeSandboxStderrPath("/tmp/home"), 1)
        @Expect(command.contains(executable.canonical), true)
        @Expect(command.contains("/opt/homebrew/bin/claude"), false)
        let profile = ckbAbcdeDevelopmentSandboxProfile(CkbAbcdeGroups.C, "/tmp/workspace", "/tmp/home",
            "/usr/bin/true", "/tmp/config", "/tmp/store", "/tmp/case", "/tmp/docs", "/tmp/sdk", "/tmp/mac-sdk",
            requestedAbsolute, executable.canonical)
        @Expect(profile.contains(executable.canonical), true)
        @Expect(profile.contains(requestedAbsolute), true)
        @Expect(profile.contains("/opt/homebrew/bin/claude"), false)
    }

    // CLAUDE-BIN-BND/NEG-01
    @TestCase
    public func nkBnd05ClaudeExecutableRejectsUnsafeInputsWithoutLeakage(): Unit {
        let root = "target/claude-bin-negative-${ckbCoreNowMillis()}"
        _ = launch("/bin/rm", ["-rf", root]).wait()
        Directory.create(Path("${root}/install/bin"), recursive: true)
        Directory.create(Path("${root}/outside"), recursive: true)
        let nonexec = "${root}/install/bin/仓颉🙂-claude"
        File.writeTo(Path(nonexec), "not executable\n".toArray())
        @Expect(ckbAbcdeResolveClaudeExecutable("").diagnostic, "claude_executable_missing")
        @Expect(ckbAbcdeResolveClaudeExecutable("relative/claude").diagnostic, "claude_executable_must_be_absolute")
        @Expect(ckbAbcdeResolveClaudeExecutable("/private/secret-token/不存在🙂").diagnostic, "claude_executable_not_found")
        @Expect(ckbAbcdeResolveClaudeExecutable(canonicalize(Path(nonexec)).toString()).diagnostic, "claude_executable_not_executable")
        let outside = "${root}/outside/claude.exe"
        File.writeTo(Path(outside), "#!/bin/zsh\nexit 0\n".toArray())
        @Expect(launch("/bin/chmod", ["700", outside]).wait(), 0)
        let escaped = "${root}/install/bin/claude"
        @Expect(launch("/bin/ln", ["-s", "../../outside/claude.exe", escaped]).wait(), 0)
        let escapedResult = ckbAbcdeResolveClaudeExecutable(canonicalize(Path(root)).join("install/bin/claude").toString())
        @Expect(escapedResult.diagnostic, "claude_executable_symlink_escape")
        @Expect(escapedResult.diagnostic.contains("secret-token"), false)
        @Expect(escapedResult.canonical, "")
    }

    // SANDBOX-FD-UT/BND/POS/NEG/E2E-01
    @TestCase
    public func nkUt06SandboxStdioStaysInsideAttemptRuntimeHome(): Unit {
        let groupRoot = "/tmp/private-sibling-token/group🙂"
        let runtimeHome = "/tmp/运行时🙂/attempt-1"
        let transcript = ckbAbcdeSandboxTranscriptPath(runtimeHome)
        let stderr = ckbAbcdeSandboxStderrPath(runtimeHome)
        @Expect(transcript, "${runtimeHome}/claude-transcript.jsonl")
        @Expect(stderr, "${runtimeHome}/claude.stderr.log")

        let development = ckbAbcdeDevelopmentClaudeCommand(groupRoot, runtimeHome, "/tmp/profile.sb",
            "/usr/bin/true", "GLM-5.2", "max", "", "", "--add-dir '/tmp/workspace'", transcript, stderr, 1)
        let certification = ckbAbcdeCertificationClaudeCommand(groupRoot, runtimeHome, "/tmp/profile.sb",
            "/usr/bin/true", "GLM-5.2", transcript, stderr)
        for (command in [development, certification]) {
            @Expect(command.contains("> '${transcript}'"), true)
            @Expect(command.contains("2> '${stderr}'"), true)
            @Expect(command.contains("> '${groupRoot}/claude-transcript"), false)
            @Expect(command.contains("2> '${groupRoot}/claude"), false)
            @Expect(command.contains("private-sibling-token"), true)
        }
    }

    // SANDBOX-STDIN-UT/BND/POS/E2E-01
    @TestCase
    public func nkUt07SandboxPromptIsAtomicallyStagedInsideRuntimeHome(): Unit {
        let root = "target/sandbox-stdin-仓颉🙂-${ckbCoreNowMillis()}"
        let groupRoot = "${root}/group"
        let runtimeHome = "${root}/runtime-home/attempt-1"
        Directory.create(Path(groupRoot), recursive: true)
        Directory.create(Path(runtimeHome), recursive: true)
        let prompt = "请实现仓颉函数🙂\n"
        File.writeTo(Path(groupRoot).join("prompt.final.md"), prompt.toArray())

        @Expect(ckbAbcdeSandboxPromptPath(runtimeHome), "${runtimeHome}/prompt.final.md")
        @Expect(ckbAbcdePrepareSandboxPrompt(groupRoot, runtimeHome), "ok")
        @Expect(String.fromUtf8(File.readFrom(Path(ckbAbcdeSandboxPromptPath(runtimeHome)))), prompt)

        let transcript = ckbAbcdeSandboxTranscriptPath(runtimeHome)
        let stderr = ckbAbcdeSandboxStderrPath(runtimeHome)
        let development = ckbAbcdeDevelopmentClaudeCommand(groupRoot, runtimeHome, "/tmp/profile.sb",
            "/usr/bin/true", "GLM-5.2", "max", "", "", "--add-dir '/tmp/workspace'", transcript, stderr, 1)
        let certification = ckbAbcdeCertificationClaudeCommand(groupRoot, runtimeHome, "/tmp/profile.sb",
            "/usr/bin/true", "GLM-5.2", transcript, stderr)
        for (command in [development, certification]) {
            @Expect(command.contains("< '${runtimeHome}/prompt.final.md'"), true)
            @Expect(command.contains("< '${groupRoot}/prompt.final.md'"), false)
        }
    }

    // SANDBOX-STDIN-BND/NEG-01
    @TestCase
    public func nkBnd07SandboxPromptRejectsUnsafeInputWithoutPathLeakage(): Unit {
        let root = "target/sandbox-stdin-negative-${ckbCoreNowMillis()}"
        let runtimeHome = "${root}/runtime-home"
        Directory.create(Path(runtimeHome), recursive: true)
        @Expect(ckbAbcdePrepareSandboxPrompt("${root}/missing-private-token🙂", runtimeHome), "sandbox_prompt_missing")

        let invalidRoot = "${root}/invalid"
        Directory.create(Path(invalidRoot), recursive: true)
        File.writeTo(Path(invalidRoot).join("prompt.final.md"), [UInt8(0xff), UInt8(0xfe), UInt8(0x80)])
        @Expect(ckbAbcdePrepareSandboxPrompt(invalidRoot, runtimeHome), "sandbox_prompt_invalid_encoding")

        let oversizedRoot = "${root}/oversized"
        Directory.create(Path(oversizedRoot), recursive: true)
        File.writeTo(Path(oversizedRoot).join("prompt.final.md"), Array<UInt8>(1048577, repeat: UInt8(65)))
        @Expect(ckbAbcdePrepareSandboxPrompt(oversizedRoot, runtimeHome), "sandbox_prompt_too_large")

        let symlinkRoot = "${root}/symlink-source"
        Directory.create(Path(symlinkRoot), recursive: true)
        let privatePrompt = "${root}/private-token-prompt.md"
        File.writeTo(Path(privatePrompt), "secret".toArray())
        @Expect(launch("/bin/ln", ["-s", "../private-token-prompt.md", "${symlinkRoot}/prompt.final.md"]).wait(), 0)
        let sourceDiagnostic = ckbAbcdePrepareSandboxPrompt(symlinkRoot, runtimeHome)
        @Expect(sourceDiagnostic, "sandbox_prompt_source_symlink_forbidden")
        @Expect(sourceDiagnostic.contains("private-token"), false)

        let validRoot = "${root}/valid"
        Directory.create(Path(validRoot), recursive: true)
        File.writeTo(Path(validRoot).join("prompt.final.md"), "valid".toArray())
        let outside = "${root}/private-output"
        File.writeTo(Path(outside), "do-not-overwrite".toArray())
        _ = launch("/bin/rm", ["-f", ckbAbcdeSandboxPromptPath(runtimeHome)]).wait()
        @Expect(launch("/bin/ln", ["-s", "../private-output", ckbAbcdeSandboxPromptPath(runtimeHome)]).wait(), 0)
        @Expect(ckbAbcdePrepareSandboxPrompt(validRoot, runtimeHome), "sandbox_prompt_destination_symlink_forbidden")
        @Expect(String.fromUtf8(File.readFrom(Path(outside))), "do-not-overwrite")
    }

    @TestCase
    public func ckg12Pos001PromptPoliciesAreGroupSpecific(): Unit {
        let task = "Implement `src/solution.cj`."
        let promptA = renderCkbAbcdePrompt(CkbAbcdeGroups.A, "CJ-HUMANEVAL-000", task, "")
        let canonicalContext = "{\"taskId\":\"CJ-HUMANEVAL-000\",\"targetVersion\":\"1.0.0\"}"
        let restResponse = "{\"ok\":true,\"data\":{\"versionResolution\":{\"targetVersion\":\"1.0.0\"}}}"
        let promptB = renderCkbAbcdePrompt(CkbAbcdeGroups.B, "CJ-HUMANEVAL-000", task, canonicalContext + "\n---CKB_RESPONSE---\n" + restResponse)
        let promptC = renderCkbAbcdePrompt(CkbAbcdeGroups.C, "CJ-HUMANEVAL-000", task, canonicalContext)
        let promptD = renderCkbAbcdePrompt(CkbAbcdeGroups.D, "CJ-HUMANEVAL-000", task, canonicalContext)
        let promptE = renderCkbAbcdePrompt(CkbAbcdeGroups.E, "CJ-HUMANEVAL-000", task, "")

        @Expect(promptA.contains("No CKB baseline"), true)
        @Expect(promptA.contains("cangjie_docs-release"), false)
        @Expect(promptA.contains("Use at most three knowledge or documentation lookup tool calls"), true)
        @Expect(promptA.contains("still edit exactly `src/solution.cj`"), true)
        @Expect(promptB.contains("CKB REST Context"), true)
        @Expect(promptB.contains(restResponse), true)
        @Expect(promptB.contains("Canonical CKB Task Context"), true)
        @Expect(promptB.contains(canonicalContext), true)
        @Expect(promptC.contains("must call `mcp__ckb-cangjie__cangjie_task_knowledge_pack`"), true)
        @Expect(promptC.contains(canonicalContext), true)
        @Expect(promptC.contains("invalid without that real tool call"), true)
        @Expect(promptD.contains("must call `mcp__ckb-cangjie-http__cangjie_task_knowledge_pack`"), true)
        @Expect(promptD.contains(canonicalContext), true)
        @Expect(promptD.contains("even if the task looks trivial"), true)
        @Expect(promptE.contains("summary_cjnative_EN.md"), true)
        @Expect(promptE.contains("You may use local official Cangjie docs"), true)
        @Expect(promptE.contains("targeted read-only Bash rg queries"), true)
        @Expect(promptE.contains("focused Read calls"), true)
        @Expect(promptE.contains("read-only inspection inside the current temporary workspace"), true)
        @Expect(promptE.contains("read-only documentation queries"), true)
        @Expect(promptE.contains("prefer absolute paths"), true)
        @Expect(promptE.contains("do not rely on `cd` followed by later relative documentation queries"), true)
    }

    // NK-UT-01
    @TestCase
    public func nkUt01AllPromptModesRequireSameCallLocalChecksWithoutVerifierLeakage(): Unit {
        for (mode in ["development", "certification"]) {
            for (group in [CkbAbcdeGroups.A, CkbAbcdeGroups.B, CkbAbcdeGroups.C, CkbAbcdeGroups.D, CkbAbcdeGroups.E]) {
                let prompt = renderCkbAbcdePromptForMode(group, "CJ-HUMANEVAL-093", "实现中文🙂示例", "{}", mode)
                @Expect(prompt.contains("within this same model call"), true)
                @Expect(prompt.contains("at minimum run `cjpm build`"), true)
                @Expect(prompt.contains("run public tests only when they are already present"), true)
                @Expect(prompt.contains("If no public tests are already present, `cjpm build` is sufficient"), true)
                @Expect(prompt.contains("Never create a `main` or test harness"), true)
                @Expect(prompt.contains("do not modify `cjpm.toml`"), true)
                @Expect(prompt.contains("fix `src/solution.cj` and rerun"), true)
                @Expect(prompt.contains("trace every example shown in the task"), true)
                @Expect(prompt.contains("structure closure, and operator precedence"), true)
                @Expect(prompt.contains("normative prose and the core algorithm are authoritative"), true)
                @Expect(prompt.contains("examples as consistency checks"), true)
                @Expect(prompt.contains("Do not create, discover, or infer hidden verifier inputs"), true)
                @Expect(prompt.contains("outputs from previous attempts"), true)
                @Expect(prompt.contains("实现中文🙂示例"), true)
            }
        }
    }

    // NK-NEG-02
    @TestCase
    public func nkNeg02AttemptedOutOfScopeWorkspaceMutationsAreProtocolViolations(): Unit {
        let allowedWrite = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Write\",\"input\":{\"file_path\":\"/tmp/workspace/src/solution.cj\",\"content\":\"中文🙂\"}}]}}"
        let allowedRelativeWrite = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Write\",\"input\":{\"file_path\":\"src/solution.cj\",\"content\":\"中文🙂\"}}]}}"
        let allowedBuild = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"cjpm build 2>&1\"}}]}}"
        let allowedReadConfig = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"cat cjpm.toml\"}}]}}"
        let allowedR3Read = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"ls -la && echo ---CJPM--- && cat cjpm.toml 2>/dev/null && find . -name '*.cj' -print 2>/dev/null\"}}]}}"
        let fakeToolResult = "{\"type\":\"user\",\"tool_use_result\":{\"stdout\":\"{\\\"type\\\":\\\"tool_use\\\",\\\"name\\\":\\\"Write\\\",\\\"input\\\":{\\\"file_path\\\":\\\"src/main.cj\\\"}}\"}}"
        let malformed = "{not-json 中文🙂"
        let writeMain = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Write\",\"input\":{\"file_path\":\"/tmp/workspace/src/main.cj\",\"content\":\"中文🙂 main() {}\"}}]}}"
        let editConfig = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Edit\",\"input\":{\"file_path\":\"/tmp/workspace/cjpm.toml\"}}]}}"
        let shellMain = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"cat > src/main.cj <<'EOF'\\nmain() {}\\nEOF\"}}]}}"
        let shellConfig = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"sed -i '' 's/static/executable/' cjpm.toml\"}}]}}"
        let redirectedWriters = ["echo test > src/main.cj", "printf test > cjpm.toml", "python3 -c 'print(1)' > src/main.cj", "perl -e 'print 1' > cjpm.toml", "echo test > /tmp/workspace/src/main.cj", "echo test > \"src/main.cj\"", "printf test > '/tmp/workspace/cjpm.toml'"]
        let directWriters = ["python3 -c 'open(\\\"src/main.cj\\\",\\\"w\\\")'", "perl -e 'open F,\\\">cjpm.toml\\\"'", "apply_patch src/main.cj", "truncate -s 0 cjpm.toml", "install temp src/main.cj", "chmod 600 cjpm.toml", "dd if=/dev/null of=src/main.cj"]

        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C, allowedWrite + "\n" + allowedRelativeWrite + "\n" + allowedBuild + "\n" + allowedReadConfig + "\n" + allowedR3Read + "\n" + fakeToolResult + "\n" + malformed), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C, writeMain), "forbidden_workspace_mutation")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C, editConfig), "forbidden_workspace_mutation")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C, shellMain), "forbidden_workspace_mutation")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C, shellConfig), "forbidden_workspace_mutation")
        for (command in redirectedWriters) {
            let event = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"${ckbAbcdeJsonEscape(command)}\"}}]}}"
            @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C, event), "forbidden_workspace_mutation")
        }
        for (command in directWriters) {
            let event = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"${ckbAbcdeJsonEscape(command)}\"}}]}}"
            @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C, event), "forbidden_workspace_mutation")
        }
    }

    @TestCase
    public func ckg12Pos002McpConfigsSeparateStdioHttpAndEmptyGroups(): Unit {
        let context = ckbAbcdeSmokeTaskContextJsonForTest()
        let stdio = renderCkbAbcdeMcpConfig(CkbAbcdeGroups.C, "/tmp/ckb", "/tmp/config", "/tmp/store", "http://127.0.0.1:18890", taskContextJson: context)
        let http = renderCkbAbcdeMcpConfig(CkbAbcdeGroups.D, "/tmp/ckb", "/tmp/config", "/tmp/store", "http://127.0.0.1:18890", taskContextJson: context)
        let empty = renderCkbAbcdeMcpConfig(CkbAbcdeGroups.A, "/tmp/ckb", "/tmp/config", "/tmp/store", "http://127.0.0.1:18890")
        let missingStdio = renderCkbAbcdeMcpConfig(CkbAbcdeGroups.C, "/tmp/ckb", "/tmp/config", "/tmp/store", "http://127.0.0.1:18890")
        let missingHttp = renderCkbAbcdeMcpConfig(CkbAbcdeGroups.D, "/tmp/ckb", "/tmp/config", "/tmp/store", "http://127.0.0.1:18890")

        @Expect(stdio.contains("\"command\": \"/bin/zsh\""), true)
        @Expect(stdio.contains("mcp-stdio"), true)
        @Expect(stdio.contains("\"type\": \"stdio\""), false)
        @Expect(http.contains("\"type\": \"http\""), true)
        @Expect(http.contains("http://127.0.0.1:18890/mcp"), true)
        @Expect(http.contains("X-CKB-Runner-Context"), true)
        @Expect(empty.contains("\"mcpServers\": {}"), true)
        @Expect(missingStdio.contains("\"mcpServers\": {}"), true)
        @Expect(missingHttp.contains("\"mcpServers\": {}"), true)
    }

    @TestCase
    public func ckg12Bnd001JsonEscapeKeepsUtf8AndEscapesControlCharacters(): Unit {
        let escaped = ckbAbcdeJsonEscape("仓颉🙂 \"quote\" \\slash\nnext")

        @Expect(escaped.contains("仓颉"), true)
        @Expect(escaped.contains("🙂"), true)
        @Expect(escaped.contains("\\\"quote\\\""), true)
        @Expect(escaped.contains("\\\\slash"), true)
        @Expect(escaped.contains("\\nnext"), true)
    }

    @TestCase
    public func ckg12Neg001BootstrapScriptDoesNotDependOnInteractiveZshrc(): Unit {
        let script = ckbAbcdeNativeTlsBootstrapScript("/tmp/ckb bin", ["--store", "/tmp/store path", "mcp-stdio"])

        @Expect(script.contains("CKB_NATIVE_TLS_BOOTSTRAPPED=1"), true)
        @Expect(script.contains("MAGIC_ROOT"), true)
        @Expect(script.contains("cangjie-stdx-mac-aarch64"), true)
        @Expect(script.contains("/Users/l3gi0n/work/workspace_cangjie/Metis/ffi"), false)
        @Expect(script.contains("CANGJIE_ROOT}/runtime/lib/darwin_aarch64_llvm"), true)
        @Expect(script.contains("DYLD_LIBRARY_PATH"), true)
        @Expect(script.contains("exec '/tmp/ckb bin' '--store' '/tmp/store path' 'mcp-stdio'"), true)
    }

    @TestCase
    public func ckg12Pos003CaseResultCarriesBenchmarkAuditFields(): Unit {
        let options = CkbAbcdeRunnerOptions()
        options.runId = "unit-run"
        let row = ckbAbcdeRenderCaseResult(options, "/tmp/run", "CJ-HUMANEVAL-000", CkbAbcdeGroups.D, "failed", 1, 1, false, false, "model_error", "manual_required", "none", "/tmp/group")

        @Expect(row.contains("\"runId\":\"unit-run\""), true)
        @Expect(row.contains("\"knowledgeEntry\":\"mcp_http\""), true)
        @Expect(row.contains("\"toolTransport\":\"streamable_http\""), true)
        @Expect(row.contains("\"unitPassAt1\":false"), true)
        @Expect(row.contains("\"firstClaudeExitCode\":"), true)
        @Expect(row.contains("\"claudeAttemptCount\":"), true)
        @Expect(row.contains("\"usageParseStatus\":\"missing_result\""), true)
        @Expect(row.contains("\"modelTotalTokens\":0"), true)
        @Expect(row.contains("\"llmTurnCount\":0"), true)
        @Expect(row.contains("\"protocolViolation\":false"), true)
        @Expect(row.contains("\"failureType\":\"model_error\""), true)
        @Expect(row.contains("\"toolEvidenceHash\":"), true)
        @Expect(row.contains("\"toolCoveragePass\":"), true)
        @Expect(row.contains("\"transportParityPath\":\"/tmp/group/parity.jsonl\""), true)
    }

    @TestCase
    public func ckg12Pos004EnvSwitchRecordNamesBoundaryAndWorkspace(): Unit {
        let row = ckbAbcdeRenderEnvSwitchCheck("CJ-HUMANEVAL-000", CkbAbcdeGroups.C, CkbAbcdeGroups.D, "/tmp/workspace", "/tmp/group")

        @Expect(row.contains("\"fromGroup\":\"C-ckb-mcp-stdio\""), true)
        @Expect(row.contains("\"toGroup\":\"D-ckb-mcp-http\""), true)
        @Expect(row.contains("\"knowledgeEntry\":\"mcp_http\""), true)
        @Expect(row.contains("\"cleanupAction\":\"fresh_group_workspace_and_strict_mcp_config\""), true)
        @Expect(row.contains("\"ok\":true"), true)
    }

    @TestCase
    public func ckg12Neg002RejectsUnsafeRunRootRunIdAndCaseRange(): Unit {
        let options = CkbAbcdeRunnerOptions()
        options.runId = "../bad"
        @Expect(ckbAbcdeOptionsSafetyDiagnostic(options), "unsafe_run_id")

        options.runId = "safe-run"
        options.runsRoot = "/tmp"
        @Expect(ckbAbcdeOptionsSafetyDiagnostic(options), "runs_root_outside_allowed_root")

        options.repoRoot = canonicalize(Path("..")).toString()
        let suffix = ckbCoreNowMillis().toString()
        let allowed = Path(options.repoRoot).join("target/certification-safety-${suffix}")
        Directory.create(allowed, recursive: true)
        options.runsRoot = canonicalize(allowed).toString()
        @Expect(ckbAbcdeOptionsSafetyDiagnostic(options), "ok")
        let broad = Path(options.repoRoot).join("target/arbitrary-safety-${suffix}")
        Directory.create(broad, recursive: true)
        options.runsRoot = canonicalize(broad).toString()
        @Expect(ckbAbcdeOptionsSafetyDiagnostic(options), "runs_root_outside_allowed_root")
        let escaped = Path(options.repoRoot).join("target/certification-symlink-${suffix}")
        _ = launch("/bin/ln", ["-s", "/tmp", escaped.toString()]).wait()
        options.runsRoot = escaped.toString()
        @Expect(ckbAbcdeOptionsSafetyDiagnostic(options), "runs_root_outside_allowed_root")
        _ = launch("/bin/rm", ["-rf", allowed.toString(), broad.toString(), escaped.toString()]).wait()

        options.runsRoot = "/Users/l3gi0n/Downloads/ckbtest"
        options.caseEnd = 164
        @Expect(ckbAbcdeOptionsSafetyDiagnostic(options), "case_range_must_be_0_163")
    }

    @TestCase
    public func ckg12Neg003McpInitToolListIsNotCountedAsToolUse(): Unit {
        let initOnly = "{\"type\":\"system\",\"subtype\":\"init\",\"tools\":[\"mcp__ckb-cangjie-http__cangjie_task_knowledge_pack\"]}"
        let realUse = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"mcp__ckb-cangjie-http__cangjie_task_knowledge_pack\"}]}}"
        let failedInit = "{\"type\":\"system\",\"subtype\":\"init\",\"mcp_servers\":[{\"name\":\"ckb-cangjie-http\",\"status\":\"failed\"}]}"
        let mergedAttempts = ckbAbcdeJoinClaudeAttemptTextForTest(realUse, failedInit)

        @Expect(ckbAbcdeToolEvidenceForTest(CkbAbcdeGroups.D, initOnly), "manual_required")
        @Expect(ckbAbcdeToolEvidenceForTest(CkbAbcdeGroups.D, initOnly + "\n" + realUse), "cangjie_task_knowledge_pack")
        @Expect(ckbAbcdeToolEvidenceForTest(CkbAbcdeGroups.D, mergedAttempts), "cangjie_task_knowledge_pack")
        @Expect(mergedAttempts.contains(realUse), true)
        @Expect(mergedAttempts.contains(failedInit), true)
    }

    @TestCase
    public func ckg12Pos009CanonicalTaskContextCarriesVersionAndTags(): Unit {
        let context = CkbAbcdeTaskContext()
        context.taskId = "CJ-HUMANEVAL-999"
        context.taskText = "Use ArrayList and String."
        context.signature = "func solution(s: String): ArrayList<String>"
        context.expectedKnowledgeTags.add("ArrayList")
        context.expectedKnowledgeTags.add("String")

        let json = ckbAbcdeRenderTaskContextJson(context)

        @Expect(json.contains("\"taskId\":\"CJ-HUMANEVAL-999\""), true)
        @Expect(json.contains("\"benchmark\":\"Cangjie-HumanEval\""), true)
        @Expect(json.contains("\"targetVersion\":\"1.0.0\""), true)
        @Expect(json.contains("\"sourceSet\":\"all\""), true)
        @Expect(json.contains("\"versionPolicy\":\"default\""), true)
        @Expect(json.contains("\"expectedKnowledgeTags\":[\"ArrayList\",\"String\"]"), true)
        @Expect(json.contains("\"responseMode\":\"evidence\""), true)
    }

    @TestCase
    public func f6Ut001RestStdioAndHttpTaskPackPayloadsHaveSameEvidence(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), p6PersistExactLookupStore("f6-ut-parity-store"))
        let context = CkbAbcdeTaskContext()
        context.taskId = "CJ-HUMANEVAL-000"
        context.taskText = "Use ArrayList.add and avoid append."
        context.signature = "func solution(values: Array<Int64>): Int64"
        context.expectedKnowledgeTags.add("ArrayList.add")
        let report = ckbAbcdeProbeInProcessTransportParity(service, context.taskId, ckbAbcdeRenderTaskContextJson(context))

        @Expect(report.ok, true)
        @Expect(report.rest.evidenceHash != "", true)
        @Expect(report.rest.evidenceHash, report.stdio.evidenceHash)
        @Expect(report.rest.evidenceHash, report.http.evidenceHash)
        @Expect(report.rest.coveragePass, report.stdio.coveragePass)
        @Expect(report.rest.coveragePass, report.http.coveragePass)
        @Expect(report.rest.citationCount, report.stdio.citationCount)
        @Expect(report.rest.citationCount, report.http.citationCount)
    }

    @TestCase
    public func f6Bnd001ProtocolErrorPayloadIsNotTreatedAsBusinessSuccess(): Unit {
        let response = "{\"jsonrpc\":\"2.0\",\"id\":3,\"error\":{\"code\":-32602,\"message\":\"session_required\"}}"
        let observation = ckbAbcdeParityObservationFromResponse("CJ-HUMANEVAL-000", "mcp_http", response)

        @Expect(observation.ok, false)
        @Expect(observation.diagnostic, "missing_structured_payload")
        @Expect(observation.evidenceHash, "")
    }

    @TestCase
    public func p6Bnd001ArtifactObservationRecordsTransportExitAndPayloadPath(): Unit {
        let observation = ckbAbcdeParityObservationFromArtifactForTest("CJ-HUMANEVAL-000", "mcp_stdio", "/tmp/stdio.json", "", 127, "stdio process failed")

        @Expect(observation.ok, false)
        @Expect(observation.payloadPath, "/tmp/stdio.json")
        @Expect(observation.diagnostic.contains("transport_exit_127"), true)
        @Expect(observation.diagnostic.contains("stdio process failed"), true)
    }

    @TestCase
    public func f6Pos001ParityJsonlRecordsEachTransportAndEvidenceFields(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), p6PersistExactLookupStore("f6-pos-parity-store"))
        let root = "target/p6-parity-artifacts"
        let report = ckbAbcdeProbeInProcessTransportParityArtifacts(service, root, "CJ-HUMANEVAL-001", ckbAbcdeSmokeTaskContextJsonForTest())
        let jsonl = ckbAbcdeRenderParityJsonl(report)

        @Expect(jsonl.contains("\"transport\":\"rest\""), true)
        @Expect(jsonl.contains("\"transport\":\"mcp_stdio\""), true)
        @Expect(jsonl.contains("\"transport\":\"mcp_http\""), true)
        @Expect(jsonl.contains("\"interfaceId\":\"cangjie_task_knowledge_pack\""), true)
        @Expect(jsonl.contains("\"evidenceHash\":\""), true)
        @Expect(jsonl.contains("\"coveragePass\":"), true)
        @Expect(jsonl.contains("\"citationCount\":"), true)
        @Expect(exists(Path("${root}/transport-parity-rest.json")), true)
        @Expect(exists(Path("${root}/transport-parity-stdio.json")), true)
        @Expect(exists(Path("${root}/transport-parity-http.json")), true)
        @Expect(exists(Path("${root}/transport-parity.jsonl")), true)
        @Expect(jsonl.contains("\"payloadPath\":\"${root}/transport-parity-rest.json\""), true)
    }

    @TestCase
    public func f6Neg001EvidenceHashMismatchIsProtocolFailureInput(): Unit {
        let rest = ckbAbcdeParityObservationFromResponse("CJ-HUMANEVAL-000", "rest", "{\"ok\":true,\"data\":{\"evidenceHash\":\"h1\",\"coverage\":{\"coveragePass\":true},\"citations\":[{\"citation\":\"doc\"}]}}")
        let stdio = ckbAbcdeParityObservationFromResponse("CJ-HUMANEVAL-000", "mcp_stdio", "{\"jsonrpc\":\"2.0\",\"id\":3,\"result\":{\"structuredContent\":{\"evidenceHash\":\"h2\",\"coverage\":{\"coveragePass\":true},\"citations\":[{\"citation\":\"doc\"}]}}}")
        let http = ckbAbcdeParityObservationFromResponse("CJ-HUMANEVAL-000", "mcp_http", "{\"jsonrpc\":\"2.0\",\"id\":3,\"result\":{\"structuredContent\":{\"evidenceHash\":\"h1\",\"coverage\":{\"coveragePass\":true},\"citations\":[{\"citation\":\"doc\"}]}}}")

        @Expect(ckbAbcdeParityDiagnosticForTest(rest, stdio, http), "evidence_hash_mismatch")
    }

    @TestCase
    public func p6Neg001CitationCountMismatchFailsTransportParity(): Unit {
        let rest = ckbAbcdeParityObservationFromResponse("CJ-HUMANEVAL-000", "rest", "{\"ok\":true,\"data\":{\"evidenceHash\":\"h1\",\"coverage\":{\"coveragePass\":true},\"citations\":[{\"citation\":\"doc\"}]}}")
        let stdio = ckbAbcdeParityObservationFromResponse("CJ-HUMANEVAL-000", "mcp_stdio", "{\"jsonrpc\":\"2.0\",\"id\":3,\"result\":{\"structuredContent\":{\"evidenceHash\":\"h1\",\"coverage\":{\"coveragePass\":true},\"citations\":[{\"citation\":\"doc\"},{\"citation\":\"std\"}]}}}")
        let http = ckbAbcdeParityObservationFromResponse("CJ-HUMANEVAL-000", "mcp_http", "{\"jsonrpc\":\"2.0\",\"id\":3,\"result\":{\"structuredContent\":{\"evidenceHash\":\"h1\",\"coverage\":{\"coveragePass\":true},\"citations\":[{\"citation\":\"doc\"}]}}}")

        @Expect(ckbAbcdeParityDiagnosticForTest(rest, stdio, http), "citation_count_mismatch")
    }

    @TestCase
    public func f7Neg001RunnerWritesPass1GateAndCurationInputForFailedCdRun(): Unit {
        let root = "target/f7-runner-pass1-gate"
        if (!exists(Path(root))) {
            Directory.create(Path(root), recursive: true)
        }
        let manifestPath = "${root}/manifest.jsonl"
        let runRoot = "${root}/run"
        if (!exists(Path(runRoot))) {
            Directory.create(Path(runRoot), recursive: true)
        }
        File.writeTo(Path(manifestPath), "{\"id\":\"CJ-HUMANEVAL-000\",\"category\":\"unit\",\"targetVersion\":\"1.0.0\",\"prompt\":\"Implement ArrayList helper.\",\"entryPoint\":\"cases/CJ-HUMANEVAL-000/starter\",\"testCommand\":\"cjpm test\",\"expectedKnowledgeTags\":[\"ArrayList\"]}\n".toArray())
        File.writeTo(Path("${runRoot}/results.jsonl"), "{\"runId\":\"unit\",\"benchmark\":\"Cangjie-HumanEval\",\"caseId\":\"CJ-HUMANEVAL-000\",\"group\":\"D-ckb-mcp-http\",\"unitPassAt1\":false,\"failureType\":\"compile_error\",\"protocolViolation\":false,\"toolEvidence\":\"cangjie_task_knowledge_pack\"}\n".toArray())
        let options = CkbAbcdeRunnerOptions()
        options.manifestPath = manifestPath
        options.caseStart = 0
        options.caseEnd = 0
        options.groups.clear()
        options.groups.add(CkbAbcdeGroups.D)

        let ok = ckbAbcdeWritePass1GateArtifactsForTest(options, runRoot)

        @Expect(ok, false)
        @Expect(exists(Path("${runRoot}/pass1-gate.json")), true)
        @Expect(exists(Path("${runRoot}/pass1-gate.md")), true)
        @Expect(exists(Path("${runRoot}/gap-curation-input.jsonl")), true)
        let curation = String.fromUtf8(File.readFrom(Path("${runRoot}/gap-curation-input.jsonl")))
        @Expect(curation.contains("\"interfaceId\":\"KI-02\""), true)
        @Expect(curation.contains("\"updateMechanism\":\"KU-11\""), true)
    }

    @TestCase
    public func ckg12Neg004ClaudeDoesNotSetToolWhitelist(): Unit {
        let baseline = ckbAbcdeClaudeToolLimitForGroup(CkbAbcdeGroups.A)
        let localDocs = ckbAbcdeClaudeToolLimitForGroup(CkbAbcdeGroups.E)
        let stdio = ckbAbcdeClaudeToolLimitForGroup(CkbAbcdeGroups.C)
        let http = ckbAbcdeClaudeToolLimitForGroup(CkbAbcdeGroups.D)

        @Expect(baseline, "")
        @Expect(localDocs, "")
        @Expect(stdio, "")
        @Expect(http, "")
    }

    @TestCase
    public func ckg12Neg005ClaudeTimeoutShellRecordsAndCleansHungCalls(): Unit {
        let shell = ckbAbcdeClaudeTimeoutShellForTest("claude -p", "/tmp/claude.err", 180)

        @Expect(shell.contains("/usr/bin/perl -MPOSIX"), true)
        @Expect(shell.contains("/bin/zsh -lc"), true)
        @Expect(shell.contains("claude_timeout_after_180s"), true)
        @Expect(shell.contains("/bin/kill -TERM -- \"-$child\""), true)
        @Expect(shell.contains("/bin/kill -KILL -- \"-$child\""), true)
        @Expect(shell.contains("code=124"), true)
    }

    @TestCase
    public func ckg12Pos005ClaudeUsesDangerouslySkipPermissions(): Unit {
        @Expect(ckbAbcdeClaudePermissionFlagForTest(), "--dangerously-skip-permissions")
        let command=ckbAbcdeCertificationClaudeCommand("/tmp/group","/tmp/runtime","/tmp/cert.sb","/usr/bin/true","GLM-5.2","/tmp/runtime/out","/tmp/runtime/err")
        @Expect(command.contains("--dangerously-skip-permissions"),true)
        @Expect(command.split("--dangerously-skip-permissions").size,2)
    }

    // NK-UT-03 / NK-BND-02 / NK-NEG-03
    @TestCase
    public func nkUt03DevelopmentClaudeUsesEffectiveRuntimeHomeAndFreshSession(): Unit {
        let groupRoot="/tmp/仓颉🙂/group";let runtimeHome="${groupRoot}/runtime-home";let profile="${groupRoot}/开发🙂.sb"
        let first=ckbAbcdeDevelopmentClaudeCommand(groupRoot,runtimeHome,profile,"/usr/bin/true","GLM-5.2","max"," --max-budget-usd '10'","","--add-dir '/tmp/工作区🙂'",ckbAbcdeSandboxTranscriptPath(runtimeHome),ckbAbcdeSandboxStderrPath(runtimeHome),1)
        let second=ckbAbcdeDevelopmentClaudeCommand(groupRoot,runtimeHome,profile,"/usr/bin/true","GLM-5.2","max","","","--add-dir '/tmp/工作区🙂'",ckbAbcdeSandboxTranscriptPath(runtimeHome),ckbAbcdeSandboxStderrPath(runtimeHome),2)
        for(command in [first,second]){@Expect(command.contains("HOME="),true);@Expect(command.contains("TMPDIR="),true);@Expect(command.contains("XDG_CONFIG_HOME="),true);@Expect(command.contains("XDG_CACHE_HOME="),true);@Expect(command.contains("CLAUDE_CONFIG_DIR="),true);@Expect(command.contains(runtimeHome),true);@Expect(command.contains("${runtimeHome}/mcp-config.json"),true);@Expect(command.contains("sandbox-exec -f"),true);@Expect(command.contains(profile),true);@Expect(command.contains("--session-id \"$session_id\""),true);@Expect(command.contains("/.claude/"),false);@Expect(command.contains("~/.claude"),false)}
        @Expect(first.contains("session-id.attempt-1.txt"),true);@Expect(second.contains("session-id.attempt-2.txt"),true);@Expect(first!=second,true)
        for(command in [first,second]) {
            let controlled = "'${runtimeHome}/tmp'"
            @Expect(command.contains("CLAUDE_CODE_TMPDIR=${controlled}"), true)
            @Expect(command.contains("CLAUDE_TMPDIR=${controlled}"), true)
            @Expect(command.contains("CLAUDE_CODE_TMPDIR=/tmp"), false)
            @Expect(command.contains("CLAUDE_TMPDIR=/tmp"), false)
        }
        @Expect(ckbAbcdeDevelopmentAttemptRuntimeHome(runtimeHome,1),"${runtimeHome}/attempt-1");@Expect(ckbAbcdeDevelopmentAttemptRuntimeHome(runtimeHome,2),"${runtimeHome}/attempt-2")
    }

    // OPENSSL-CANONICAL-UT/BND/POS/NEG + CLAUDE-TMPDIR-UT/NEG
    @TestCase
    public func opensslCanonicalUtProfilesAllowOnlyCanonicalRegularDylibs(): Unit {
        let aliasRoot=ckbAbcdeCurrentOpenSslAliasRootForTest();if(aliasRoot==""){return}
        let cryptoRequested = "${aliasRoot}/lib/libcrypto.3.dylib"
        let sslRequested = "${aliasRoot}/lib/libssl.3.dylib"
        let crypto = ckbAbcdeOpenSslCanonicalFileForTest(cryptoRequested, "libcrypto.3.dylib")
        let ssl = ckbAbcdeOpenSslCanonicalFileForTest(sslRequested, "libssl.3.dylib")
        @Expect(crypto.isEmpty(), false)
        @Expect(ssl.isEmpty(), false)
        @Expect(crypto, canonicalize(Path(cryptoRequested)).toString())
        @Expect(ssl, canonicalize(Path(sslRequested)).toString())
        let profile = ckbAbcdeDevelopmentSandboxProfile(CkbAbcdeGroups.C, "/tmp/workspace", "/tmp/runtime-home",
            "/tmp/ckb-bin", "/tmp/config", "/tmp/store", "/tmp/case", "/tmp/docs", "/tmp/sdk",
            "/tmp/macos-sdk", "/usr/bin/true", "/usr/bin/true")
        for (path in [crypto, ssl]) {
            @Expect(profile.contains("(literal \"${path}\")"), true)
            @Expect(profile.contains("(subpath \"${path}\")"), false)
        }
        @Expect(profile.contains("(subpath \"/opt/homebrew/Cellar"), false)
        @Expect(profile.contains("(subpath \"/opt/homebrew\")"), false)
        @Expect(profile.contains("(subpath \"/opt/homebrew/opt/openssl@3/lib\")"), false)
        @Expect(profile.contains("(subpath \"/opt/homebrew/opt/openssl@3.5/lib\")"), false)
        @Expect(profile.contains("(literal \"${aliasRoot}\")"), true)
        @Expect(profile.contains("/private/tmp/claude-"), false)
        @Expect(ckbAbcdeOpenSslCanonicalPairReadyForTest(), true)
    }

    @TestCase
    public func opensslCanonicalBndMissingRelativeWrongNameAndIncompletePairFailClosed(): Unit {
        for (path in ["", "relative/libcrypto.3.dylib", " /opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib",
            "/opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib ", "/tmp/私密🙂/libcrypto.3.dylib"]) {
            @Expect(ckbAbcdeOpenSslCanonicalFileForTest(path, "libcrypto.3.dylib"), "")
        }
        @Expect(ckbAbcdeOpenSslCanonicalFileForTest(
            "/opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib", "libssl.3.dylib"), "")
        @Expect(ckbAbcdeOpenSslCanonicalFileForTest(
            "/opt/homebrew/opt/openssl@3/lib/libcrypto.dylib", "libcrypto.3.dylib"), "")
        @Expect(ckbAbcdeOpenSslPairReadyForTest("/canonical/libcrypto.3.dylib", "/canonical/libssl.3.dylib"), true)
        @Expect(ckbAbcdeOpenSslPairReadyForTest("", "/canonical/libssl.3.dylib"), false)
        @Expect(ckbAbcdeOpenSslPairReadyForTest("/canonical/libcrypto.3.dylib", ""), false)
        @Expect(ckbAbcdeOpenSslPairReadyForTest("/same", "/same"), false)
        @Expect(ckbAbcdeSandboxDependencyDiagnosticForTest(false, false), "sandbox_openssl_canonical_pair_missing")
        @Expect(ckbAbcdeSandboxDependencyDiagnosticForTest(false, true), "sandbox_openssl_canonical_pair_missing")
        @Expect(ckbAbcdeSandboxDependencyDiagnosticForTest(true, false), "sandbox_magic_stdx_missing")
        @Expect(ckbAbcdeSandboxDependencyDiagnosticForTest(true, true), "ok")
    }

    @TestCase
    public func claudeTmpdirNegCertificationAndDevelopmentUseAttemptControlledDirectory(): Unit {
        let groupRoot = "/tmp/分组🙂"
        let runtimeHome = "${groupRoot}/runtime home"
        let certification = ckbAbcdeCertificationClaudeCommand(groupRoot, runtimeHome, "/tmp/cert.sb", "/usr/bin/true",
            "GLM-5.2", "${runtimeHome}/stdout", "${runtimeHome}/stderr")
        let development = ckbAbcdeDevelopmentClaudeCommand(groupRoot, runtimeHome, "/tmp/dev.sb", "/usr/bin/true",
            "GLM-5.2", "max", "", "", "", "${runtimeHome}/stdout", "${runtimeHome}/stderr", 1)
        for (command in [certification, development]) {
            let controlled = "'${runtimeHome}/tmp'"
            @Expect(command.contains("TMPDIR=${controlled}"), true)
            @Expect(command.contains("CLAUDE_CODE_TMPDIR=${controlled}"), true)
            @Expect(command.contains("CLAUDE_TMPDIR=${controlled}"), true)
            @Expect(command.contains("/tmp/claude-321e-cwd"), false)
            @Expect(command.contains("/private/tmp/claude-"), false)
        }
    }

    @TestCase
    public func nkNeg03DefaultRuntimeHomeAccessFailsClosedWithoutPathLeakage(): Unit {
        let bashDefault="{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"cat /Users/private-user/.claude/projects/secret/tool-results/value\"}}]}}"
        let readDefault="{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Read\",\"input\":{\"file_path\":\"/Users/private-user/.claude/projects/中文🙂\"}}]}}"
        let homeDefault="{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"cat ~/.claude/projects/secret\"}}]}}"
        let allowedRuntime="{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Read\",\"input\":{\"file_path\":\"/tmp/运行🙂/runtime-home/claude-config/projects/tool-results/value\"}}]}}"
        let injectedResult="{\"type\":\"user\",\"tool_use_result\":{\"stdout\":\"/Users/private-user/.claude/projects/secret\"}}"
        for(event in [bashDefault,readDefault,homeDefault]){let diagnostic=ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C,event);@Expect(diagnostic,"default_runtime_home_access");@Expect(diagnostic.contains("private-user"),false)}
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C,allowedRuntime+"\n"+injectedResult+"\n{malformed🙂"),"none")
    }

    @TestCase
    public func nkNeg04BroadFilesystemScanFailsClosedWithoutCommandLeakage(): Unit {
        let rootScan="{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"find / -name secret-token-value\"}}]}}"
        let usersScan="{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"find /Users -name 仓颉🙂\"}}]}}"
        let dataUsersScan="{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"/usr/bin/find /System/Volumes/Data/Users -type f\"}}]}}"
        let scoped="{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"find . -type f\"}}]}}"
        for(event in [rootScan,usersScan,dataUsersScan]){let diagnostic=ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C,event);@Expect(diagnostic,"broad_filesystem_scan");@Expect(diagnostic.contains("secret-token-value"),false);@Expect(diagnostic.contains("仓颉"),false)}
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.C,scoped+"\n{malformed🙂"),"none")
    }

    // NK-POS-05-SCOPED-WORKSPACE-FIND
    @TestCase
    public func nkPos05ExactWorkspaceAbsoluteFindAndDotFindAreAllowed(): Unit {
        let workspace = "/tmp/评测🙂/cases/CJ-HUMANEVAL-078/C-ckb-mcp-stdio/workspace"
        let absolute = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"find ${workspace} -type f -name '*.cj' -o -name '*.toml' | head -50\"}}]}}"
        let child = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"find '${workspace}/src' -type f\"}}]}}"
        let dot = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"find . -type f\"}}]}}"
        for (event in [absolute, child, dot]) {
            @Expect(ckbAbcdeForbiddenEvidenceForWorkspaceForTest(CkbAbcdeGroups.C, event, workspace), "none")
        }
    }

    // NK-BND-08-WORKSPACE-PREFIX-ESCAPE
    @TestCase
    public func nkBnd08WorkspacePrefixTraversalMultipleTargetsAndSubstitutionFailClosed(): Unit {
        let workspace = "/tmp/eval/case/workspace"
        let commands = [
            "find /tmp/eval/case/workspace-sibling -type f",
            "find /tmp/eval/case/workspace/../tests -type f",
            "find . /tmp/eval/case/workspace -type f",
            "find $(pwd) -type f",
            "find \"$PWD\" -type f",
            "find `pwd` -type f",
            "find /Users -type f"
        ]
        for (command in commands) {
            let event = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"${ckbAbcdeJsonEscape(command)}\"}}]}}"
            @Expect(ckbAbcdeForbiddenEvidenceForWorkspaceForTest(CkbAbcdeGroups.C, event, workspace), "broad_filesystem_scan")
        }
    }

    // NK-E2E-02-CASE078-PROTOCOL-REPLAY
    @TestCase
    public func nkE2e02Case078RecordedScopedFindReplaysWithoutProtocolViolation(): Unit {
        let transcriptSha256 = "eb9197452df02cda39f84c0534c95ec79727f815fdbf613723ce348b669fb6bf"
        let resultEvidenceHash = "sha256:20ed705ef07872a335cd94f9c3c5c2ceccb17375c8632ebb588ac3be6e756d7a"
        let workspace = "/Users/eval-runner/isolated/CJ-HUMANEVAL-078/C-ckb-mcp-stdio/workspace"
        let recordedEvent = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"find ${workspace} -type f -name \\\"*.cj\\\" -o -name \\\"*.toml\\\" | head -50\"}}]}}"
        @Expect(transcriptSha256, "eb9197452df02cda39f84c0534c95ec79727f815fdbf613723ce348b669fb6bf")
        @Expect(resultEvidenceHash, "sha256:20ed705ef07872a335cd94f9c3c5c2ceccb17375c8632ebb588ac3be6e756d7a")
        @Expect(ckbAbcdeForbiddenEvidenceForWorkspaceForTest(CkbAbcdeGroups.C, recordedEvent, workspace), "none")
    }

    @TestCase
    public func nkUt04DevelopmentSandboxProfileIsGroupScopedAndUtf8Safe(): Unit {
        let workspace="/tmp/工作区🙂";let home="/tmp/运行时🙂";let caseSrc="/tmp/数据集🙂/CJ-HUMANEVAL-093";let docs="/tmp/文档🙂";let sdk="/tmp/仓颉SDK🙂"
        let c=ckbAbcdeDevelopmentSandboxProfile(CkbAbcdeGroups.C,workspace,home,"/tmp/ckb-bin","/tmp/config","/tmp/ckb-store",caseSrc,docs,sdk,"/tmp/MacSDK🙂","/usr/bin/true","/usr/bin/true")
        let e=ckbAbcdeDevelopmentSandboxProfile(CkbAbcdeGroups.E,workspace,home,"/tmp/ckb-bin","/tmp/config","/tmp/ckb-store",caseSrc,docs,sdk,"/tmp/MacSDK🙂","/usr/bin/true","/usr/bin/true")
        for(profile in [c,e]){@Expect(profile.contains("(deny default)"),true);@Expect(profile.contains(workspace),true);@Expect(profile.contains(home),true);@Expect(profile.contains(sdk),true);@Expect(profile.contains("${caseSrc}/tests"),true);@Expect(profile.contains("${caseSrc}/translation"),true);@Expect(profile.contains("CangjieTeacher"),true)}
        @Expect(c.contains(docs),false);@Expect(e.contains(docs),true)
    }

    // MAGIC-STDX-UT / MAGIC-STDX-BND / MAGIC-STDX-POS / MAGIC-STDX-NEG
    @TestCase
    public func magicStdxUtCanonicalRootResolvesOnlyPlatformLibraryDirectory(): Unit {
        let root = "target/Magic-仓颉🙂-${ckbCoreNowMillis()}"
        let stdx = "${root}/libs/cangjie-stdx-mac-aarch64-1.0.0.1/darwin_aarch64_llvm/dynamic/stdx"
        Directory.create(Path(stdx), recursive: true)
        let canonicalRoot = canonicalize(Path(root)).toString()
        let canonicalStdx = canonicalize(Path(stdx)).toString()
        @Expect(ckbAbcdeMagicStdxPathForTest(canonicalRoot), canonicalStdx)
        @Expect(ckbAbcdeMagicStdxPathForTest(canonicalRoot).contains("仓颉🙂"), true)
    }

    @TestCase
    public func magicStdxBndMissingRelativeAndMalformedRootsFailClosed(): Unit {
        for (root in ["", "relative/Magic", " /private/tmp/Magic", "/private/tmp/Magic ", "/private/tmp/不存在-仓颉🙂"]) {
            @Expect(ckbAbcdeMagicStdxPathForTest(root), "")
        }
    }

    @TestCase
    public func magicStdxNegSymlinkAndUnexpectedSuffixFailClosed(): Unit {
        let root = "target/Magic-negative-${ckbCoreNowMillis()}"
        let real = "${root}/real"
        let suffix = "libs/cangjie-stdx-mac-aarch64-1.0.0.1/darwin_aarch64_llvm/dynamic/stdx"
        Directory.create(Path("${real}/${suffix}"), recursive: true)
        let linkedRoot = "${root}/linked-root"
        @Expect(launch("/bin/ln", ["-s", "real", linkedRoot]).wait(), 0)
        @Expect(ckbAbcdeMagicStdxPathForTest(canonicalize(Path(root)).join("linked-root").toString()), "")
        let badRoot = "${root}/bad-root"
        Directory.create(Path("${badRoot}/libs/private-sibling-token🙂"), recursive: true)
        @Expect(ckbAbcdeMagicStdxPathForTest(canonicalize(Path(badRoot)).toString()), "")
    }

    @TestCase
    public func magicStdxPosProfilesAllowExactStdxWithoutMagicSiblingOrWrite(): Unit {
        let stdx = ckbAbcdeCurrentMagicStdxPathForTest()
        @Expect(stdx.isEmpty(), false)
        let magicRoot = match(getVariable("MAGIC_PATH")){case Some(value)=>canonicalize(Path(value)).toString() case None=>""}
        let workspace="/tmp/工作区🙂";let home="/tmp/运行时🙂";let caseSrc="/tmp/数据集🙂/CJ-HUMANEVAL-032"
        let development = ckbAbcdeDevelopmentSandboxProfile(CkbAbcdeGroups.C,workspace,home,"/tmp/ckb-bin","/tmp/config","/tmp/ckb-store",caseSrc,"/tmp/文档🙂","/tmp/仓颉SDK🙂","/tmp/MacSDK🙂","/usr/bin/true","/usr/bin/true")
        let certification = ckbAbcdeCertificationSandboxProfile(workspace,home,"/tmp/ckb-bin","/tmp/config","/tmp/ckb-store",caseSrc,"/usr/bin/true","/usr/bin/true")
        for (profile in [development, certification]) {
            @Expect(profile.contains("(subpath \"${stdx}\")"), true)
            @Expect(profile.contains("(subpath \"${magicRoot}\")"), false)
            @Expect(profile.contains("(literal \"/dev/stdin\")"), true)
            @Expect(profile.contains("(literal \"/dev/fd/0\")"), true)
            @Expect(profile.contains("(subpath \"/dev/fd\")"), false)
            @Expect(profile.contains("(literal \"/dev/fd/1\")"), false)
            @Expect(profile.contains("(literal \"/dev/fd/2\")"), false)
            @Expect(profile.contains("(literal \"/dev/stdout\")"), false)
            @Expect(profile.contains("(literal \"/dev/stderr\")"), false)
            @Expect(profile.contains("(allow file-write* (subpath \"${stdx}\")"), false)
            @Expect(profile.contains("(allow file-write* (literal \"/dev/stdin\")"), false)
            @Expect(profile.contains("(allow file-write* (literal \"/dev/fd/0\")"), false)
            @Expect(profile.contains("private-sibling-token🙂"), false)
        }
    }

    @TestCase
    public func nkPos04RealDevelopmentSandboxBuildsAndDeniesPrivateSibling(): Unit {
        if (!exists(Path("/usr/bin/sandbox-exec"))) { return }
        let root="target/development-sandbox-仓颉🙂-${ckbCoreNowMillis()}";let workspace="${root}/workspace";let home="${root}/runtime-home/attempt-1";let caseSrc="${root}/case";let docs="${root}/docs";let store="${root}/store";let bin="${root}/ckb-bin"
        for(path in [workspace,home,"${caseSrc}/tests","${caseSrc}/translation",docs,store]){if(!exists(Path(path))){Directory.create(Path(path),recursive:true)}};File.writeTo(Path(bin),"probe".toArray())
        let sdk=match(getVariable("CANGJIE_HOME")){case Some(value)=>value case None=>""};let macSdk=match(getVariable("SDKROOT")){case Some(value)=>value case None=>""};@Expect(sdk.isEmpty(),false);@Expect(macSdk.isEmpty(),false)
        try {
            @Expect(ckbAbcdePrepareBundledArchiverForTest(canonicalize(Path(home)).toString(),canonicalize(Path(sdk)).toString()),"ok")
            let profilePath="${root}/development.sb";File.writeTo(Path(profilePath),ckbAbcdeDevelopmentSandboxProfile(CkbAbcdeGroups.E,workspace,home,bin,"/tmp/config",store,caseSrc,docs,sdk,macSdk,"/usr/bin/true","/usr/bin/true").toArray())
            let probe=ckbAbcdeDevelopmentSandboxProbeForTest(profilePath,workspace,home,caseSrc,docs,CkbAbcdeGroups.E,sdk,macSdk)
            @Expect(probe.exitCode,0);@Expect(probe.stderr,"");@Expect(probe.stdout.contains("\"ok\":true"),true);@Expect(probe.stdout.contains("\"stdinReadable\":true"),true);@Expect(probe.stdout.contains("\"runtimeTempMarkersPassed\":true"),true);@Expect(probe.stdout.contains("\"runtimeTempMarkersCleaned\":true"),true);@Expect(probe.stdout.contains("\"deniedExternalTemp\":true"),true);@Expect(probe.stdout.contains("\"deniedTempSibling\":true"),true);@Expect(probe.stdout.contains("\"archiverReady\":true"),true);@Expect(probe.stdout.contains("\"minimalBuildPassed\":true"),true);@Expect(probe.stdout.contains("\"deniedBroadFilesystemScan\":true"),true);@Expect(probe.stdout.contains("private-probe-value"),false)
        } finally { _=launch("/bin/rm",["-rf",root]).wait() }
    }

    @TestCase
    public func claudeTmpdirPosRealCertificationSandboxWritesCleansAndDeniesOutside(): Unit {
        if (!exists(Path("/usr/bin/sandbox-exec"))) { return }
        let root="target/certification-sandbox-仓颉🙂-${ckbCoreNowMillis()}";let workspace="${root}/workspace";let home="${root}/runtime-home";let caseSrc="${root}/case";let store="${root}/store";let bin="${root}/ckb-bin";let config="${root}/formal.conf"
        for(path in [workspace,home,"${caseSrc}/tests","${caseSrc}/translation","${store}/metadata"]){Directory.create(Path(path),recursive:true)};File.writeTo(Path(store).join("metadata/active-snapshot.manifest"),"frozen-pointer".toArray());File.writeTo(Path(bin),"probe".toArray());File.writeTo(Path(config),"network.enabled=false\n".toArray())
        try {
            @Expect(exists(Path("${home}/tmp")),false);@Expect(ckbAbcdePrepareClaudeRuntimeHomeForTest(canonicalize(Path(home)).toString()),"ok");@Expect(exists(Path("${home}/tmp")),true)
            let sdk=match(getVariable("CANGJIE_HOME")){case Some(value)=>canonicalize(Path(value)).toString() case None=>""};@Expect(sdk.isEmpty(),false);@Expect(ckbAbcdePrepareBundledArchiverForTest(canonicalize(Path(home)).toString(),sdk),"ok")
            let profilePath="${root}/certification.sb";File.writeTo(Path(profilePath),ckbAbcdeCertificationSandboxProfile(workspace,home,bin,config,store,caseSrc,"/usr/bin/true","/usr/bin/true").toArray())
            let profile=String.fromUtf8(File.readFrom(Path(profilePath)));@Expect(profile.contains("/private/tmp/claude-"),false)
            let metadataLine=profile.split("\n")[7]
            for(path in [workspace,home,bin,config]){@Expect(metadataLine.contains("(literal \"${canonicalize(Path(path)).toString()}\")"),true)}
            @Expect(metadataLine.contains(canonicalize(Path(store)).toString()),false)
            @Expect(profile.contains("(deny file-read*"),true);@Expect(profile.contains("(subpath \"${canonicalize(Path(store)).toString()}\")"),true)
            @Expect(metadataLine.contains("(literal \"/usr/bin/dsymutil\")"),true)
            @Expect(profile.split("\n")[8].contains("(literal \"/usr/bin/dsymutil\")"),true)
            @Expect(metadataLine.contains("(subpath \"${canonicalize(Path(workspace)).parent.toString()}\")"),false)
            let probe=ckbAbcdeCertificationSandboxProbeForTest(profilePath,workspace,home,caseSrc,ckbStore:store)
            @Expect(probe.exitCode,0);@Expect(probe.stdout.contains("\"runtimeTempMarkersPassed\":true"),true);@Expect(probe.stdout.contains("\"runtimeTempMarkersCleaned\":true"),true);@Expect(probe.stdout.contains("\"archiverReady\":true"),true);@Expect(probe.stdout.contains("\"minimalBuildPassed\":true"),true);@Expect(probe.stdout.contains("\"deniedExternalTemp\":true"),true);@Expect(probe.stdout.contains("\"deniedTempSibling\":true"),true)
        } finally { _=launch("/bin/rm",["-rf",root]).wait() }
    }

    @TestCase
    public func claudeRuntimeHomeUtCreatesAllControlledDirectoriesWithUtf8Path(): Unit {
        let relative="target/runtime-home-仓颉🙂-${ckbCoreNowMillis()}";Directory.create(Path(relative),recursive:true);let home=canonicalize(Path(relative)).toString()
        try { @Expect(ckbAbcdePrepareClaudeRuntimeHomeForTest(home),"ok");for(path in ["tmp","xdg-config","xdg-cache","claude-config"]){@Expect(exists(Path("${home}/${path}")),true)} } finally { _=launch("/bin/rm",["-rf",relative]).wait() }
    }

    @TestCase
    public func claudeRuntimeHomeBndRejectsEmptyRelativeAndUtf8RelativePaths(): Unit {
        for(path in ["","relative/runtime-home","相对/运行时🙂"]){@Expect(ckbAbcdePrepareClaudeRuntimeHomeForTest(path),"sandbox_runtime_home_invalid")}
    }

    // BUNDLED-AR-UT/POS-01
    @TestCase
    public func bundledArchiverUtCreatesAttemptLocalExecutableShimAndPrependsPath(): Unit {
        let root = "target/bundled-ar-仓颉🙂-${ckbCoreNowMillis()}"
        let sdk = "${root}/SDK 仓颉🙂"
        let bundled = "${sdk}/third_party/llvm/bin/llvm-ar"
        let home = "${root}/runtime home🙂/attempt-1"
        Directory.create(Path(bundled).parent, recursive: true)
        Directory.create(Path(home), recursive: true)
        File.writeTo(Path(bundled), "#!/bin/zsh\nexit 0\n".toArray())
        @Expect(launch("/bin/chmod", ["700", bundled]).wait(), 0)
        let canonicalSdk = canonicalize(Path(sdk)).toString()
        let canonicalHome = canonicalize(Path(home)).toString()
        let canonicalBundled = canonicalize(Path(bundled)).toString()
        try {
            @Expect(ckbAbcdeBundledArchiverForTest(canonicalSdk), canonicalBundled)
            @Expect(ckbAbcdePrepareBundledArchiverForTest(canonicalHome, canonicalSdk), "ok")
            let shim = "${canonicalHome}/bin/ar"
            @Expect(exists(Path(shim)), true)
            @Expect(launch("/bin/test", ["-x", shim]).wait(), 0)
            @Expect(launch("/bin/test", ["-L", shim]).wait() == 0, false)
            @Expect(String.fromUtf8(File.readFrom(Path(shim))).contains(canonicalBundled), true)
            for (command in [
                ckbAbcdeDevelopmentClaudeCommand("/tmp/group", canonicalHome, "/tmp/dev.sb", "/usr/bin/true",
                    "GLM-5.2", "max", "", "", "", "${canonicalHome}/out", "${canonicalHome}/err", 1),
                ckbAbcdeCertificationClaudeCommand("/tmp/group", canonicalHome, "/tmp/cert.sb", "/usr/bin/true",
                    "GLM-5.2", "${canonicalHome}/out", "${canonicalHome}/err")
            ]) {
                @Expect(command.contains("PATH='${canonicalHome}/bin':\"$PATH\""), true)
                @Expect(command.contains("PATH=/tmp"), false)
            }
        } finally { _ = launch("/bin/rm", ["-rf", root]).wait() }
    }

    // BUNDLED-AR-BND/NEG-01
    @TestCase
    public func bundledArchiverBndRejectsMissingNonExecutableAndSymlinkEscape(): Unit {
        let root = "target/bundled-ar-negative-${ckbCoreNowMillis()}"
        let sdk = "${root}/sdk"
        let target = "${sdk}/third_party/llvm/bin/llvm-ar"
        Directory.create(Path(target).parent, recursive: true)
        File.writeTo(Path(target), "not executable\n".toArray())
        let canonicalSdk = canonicalize(Path(sdk)).toString()
        try {
            for (value in ["", "relative/sdk", "相对/SDK🙂", "/private/tmp/不存在-sdk-仓颉🙂"]) {
                @Expect(ckbAbcdeBundledArchiverForTest(value), "")
            }
            @Expect(ckbAbcdePrepareBundledArchiverForTest(canonicalize(Path(root)).toString(), "/private/tmp/不存在-sdk-仓颉🙂"), "sandbox_bundled_archiver_missing")
            @Expect(ckbAbcdeBundledArchiverForTest(canonicalSdk), "")
            @Expect(launch("/bin/chmod", ["700", target]).wait(), 0)
            let outside = "${root}/outside-ar"
            File.writeTo(Path(outside), "#!/bin/zsh\nexit 0\n".toArray())
            @Expect(launch("/bin/chmod", ["700", outside]).wait(), 0)
            @Expect(launch("/bin/rm", ["-f", target]).wait(), 0)
            @Expect(launch("/bin/ln", ["-s", "../../../../outside-ar", target]).wait(), 0)
            @Expect(ckbAbcdeBundledArchiverForTest(canonicalSdk), "")
            let linkedSdk = "${root}/linked-sdk"
            @Expect(launch("/bin/ln", ["-s", "sdk", linkedSdk]).wait(), 0)
            @Expect(ckbAbcdeBundledArchiverForTest(canonicalize(Path(root)).join("linked-sdk").toString()), "")
        } finally { _ = launch("/bin/rm", ["-rf", root]).wait() }
    }

    // BUNDLED-AR-NEG-02
    @TestCase
    public func bundledArchiverNegRejectsRuntimeBinSymlinkWithoutWritingOutside(): Unit {
        let root = "target/bundled-ar-runtime-negative-${ckbCoreNowMillis()}"
        let sdk = "${root}/sdk"
        let target = "${sdk}/third_party/llvm/bin/llvm-ar"
        let home = "${root}/runtime-home"
        let outside = "${root}/outside-bin"
        Directory.create(Path(target).parent, recursive: true)
        Directory.create(Path(home), recursive: true)
        Directory.create(Path(outside), recursive: true)
        File.writeTo(Path(target), "#!/bin/zsh\nexit 0\n".toArray())
        @Expect(launch("/bin/chmod", ["700", target]).wait(), 0)
        @Expect(launch("/bin/ln", ["-s", "../outside-bin", "${home}/bin"]).wait(), 0)
        try {
            @Expect(ckbAbcdePrepareBundledArchiverForTest(canonicalize(Path(home)).toString(), canonicalize(Path(sdk)).toString()), "sandbox_bundled_archiver_bin_symlink_forbidden")
            @Expect(exists(Path("${outside}/ar")), false)
        } finally { _ = launch("/bin/rm", ["-rf", root]).wait() }
    }

    @TestCase
    public func claudeTmpdirNegCertificationProfileHasNoLegacyPrivateTmpPermission(): Unit {
        let profile=ckbAbcdeCertificationSandboxProfile("/tmp/workspace","/tmp/runtime-home","/tmp/ckb","/tmp/config","/tmp/store","/tmp/case","/usr/bin/true","/usr/bin/true")
        @Expect(profile.contains("/private/tmp/claude-"),false);@Expect(profile.contains("(subpath \"/tmp/runtime-home\")"),true)
    }

    @TestCase
    public func claudeTmpdirNegDevelopmentProfileCannotGrantAttemptSibling(): Unit {
        let profile=ckbAbcdeDevelopmentSandboxProfile(CkbAbcdeGroups.C,"/tmp/workspace","/tmp/runtime-home/attempt-1","/tmp/ckb","/tmp/config","/tmp/store","/tmp/case","/tmp/docs","/tmp/sdk","/tmp/mac-sdk","/usr/bin/true","/usr/bin/true")
        @Expect(profile.contains("/private/tmp/claude-"),false);@Expect(profile.contains("(subpath \"/tmp/runtime-home/attempt-1\")"),true);@Expect(profile.contains("(subpath \"/tmp/runtime-home/attempt-2\")"),false)
    }

    @TestCase
    public func opensslCanonicalPosProfileSelectsOnlyFirstReadyAlias(): Unit {
        let selected=ckbAbcdeCurrentOpenSslAliasRootForTest();if(selected==""){return}
        let profile=ckbAbcdeCertificationSandboxProfile("/tmp/workspace","/tmp/runtime-home","/tmp/ckb","/tmp/config","/tmp/store","/tmp/case","/usr/bin/true","/usr/bin/true")
        @Expect(profile.contains("(literal \"${selected}\")"),true)
        for(root in ["/opt/homebrew/opt/openssl@3","/opt/homebrew/opt/openssl@3.5","/usr/local/opt/openssl@3"]){if(root!=selected){@Expect(profile.contains("(literal \"${root}\")"),false)}}
    }

    @TestCase
    public func ckg12Pos005bRestContextCurlRetriesConnectionRefused(): Unit {
        let flags = ckbAbcdeCurlRetryFlagsForTest()

        @Expect(flags.contains("--retry "), true)
        @Expect(flags.contains("--retry-delay "), true)
        @Expect(flags.contains("--retry-connrefused"), true)
    }

    @TestCase
    public func ckg12Neg006PassAt1DoesNotCountRetrySuccess(): Unit {
        let firstTimeoutThenSuccess = "{\"attempt\":1,\"exitCode\":124}\n{\"attempt\":2,\"exitCode\":0}\n"
        let firstSuccess = "{\"attempt\":1,\"exitCode\":0}\n"

        @Expect(ckbAbcdeUnitPassAt1FromAttemptsForTest(true, firstTimeoutThenSuccess), false)
        @Expect(ckbAbcdeUnitPassAt1FromAttemptsForTest(true, firstSuccess), true)
        @Expect(ckbAbcdeUnitPassAt1FromAttemptsForTest(false, firstSuccess), false)
    }

    @TestCase
    public func ckg12Neg007ClaudeTimeoutExitIsClassifiedAsTimeout(): Unit {
        @Expect(ckbAbcdeFailureTypeForTest(124, 1, false, "none", "", true), "timeout")
        @Expect(ckbAbcdeFailureTypeForTest(124, 1, false, "none", "", false), "timeout")
        @Expect(ckbAbcdeFailureTypeForTest(1, 1, false, "none", "", true), "model_error")
        @Expect(ckbAbcdeFailureTypeForTest(0, 1, false, "none", "", false), "tool_unavailable")
    }

    @TestCase
    public func ckg12Bnd002ResultAuditScansUtf8TranscriptSafely(): Unit {
        let transcript = "模型输出：仓颉🙂\n{\"knowledgeVersion\":\"ckb-20260519-000100-active\",\"citation\":\"doc-1\"}\n继续中文🙂 {\"citation\":\"doc-2\"}"

        @Expect(ckbAbcdeJsonStringFieldForTest(transcript, "knowledgeVersion"), "ckb-20260519-000100-active")
        @Expect(ckbAbcdeCountOccurrencesForTest(transcript, "\"citation\""), 2)
    }

    @TestCase
    public func ckg12Neg008LocalDocsGroupAllowsVisibleToolsButRejectsUnexpectedToolUse(): Unit {
        let transcript = "{\"type\":\"system\",\"subtype\":\"init\",\"tools\":[\"Read\",\"Write\",\"Bash\",\"WebFetch\"]}"
        let webSearchUse = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"WebSearch\",\"input\":{\"query\":\"Cangjie ArrayList\"}}]}}"

        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, transcript), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, webSearchUse), "forbidden_e_tool_use")
    }

    @TestCase
    public func ckg12Pos006LocalDocsGroupAllowsReadOnlyScopedShell(): Unit {
        let docsSearch = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"find /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs -name collection_arraylist.md 2>/dev/null\"}}]}}"
        let workspaceRead = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"ls /Users/l3gi0n/Downloads/ckbtest/unit-run/cases/CJ-HUMANEVAL-000/E-local-cangjie-docs/workspace/src/ && cat /Users/l3gi0n/Downloads/ckbtest/unit-run/cases/CJ-HUMANEVAL-000/E-local-cangjie-docs/workspace/src/solution.cj\"}}]}}"
        let relativeReadOnlySearch = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"rg -rn \\\"StringBuilder\\\" --type md | head -30\"}}]}}"
        let docsSearchWithArrowPattern = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"rg -rn \\\"split\\\\(String\\\\)|-> Array|: Array<String>\\\" /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs -g \\\"*.md\\\" | head -20\"}}]}}"
        let localCompute = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"python3 -c \\\"def ds(n):\\\\n    return n + 1\\\\nprint(ds(1))\\\"\"}}]}}"
        let toolProbe = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"which cjc cjpm 2>/dev/null\"}}]}}"
        let workspaceBuild = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"cjpm build 2>&1 | head -60\"}}]}}"
        let scratchSource = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"cat > /tmp/test_palindrome.cj << 'EOF'\\\\nmain(): Int64 { return 0 }\\\\nEOF\"}}]}}"
        let scratchCompile = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"cjc /tmp/test_palindrome.cj --import-path target/release/pkg -o /tmp/test_palindrome 2>&1 | head -40\"}}]}}"
        let scratchRun = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"/tmp/test_palindrome 2>&1 | head\"}}]}}"
        let scratchCleanup = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"rm -f /tmp/test_palindrome.cj /tmp/test_palindrome; echo \\\"cleaned\\\"\"}}]}}"

        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, docsSearch), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, workspaceRead), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, relativeReadOnlySearch), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, docsSearchWithArrowPattern), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, localCompute), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, toolProbe), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, workspaceBuild), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, scratchSource), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, scratchCompile), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, scratchRun), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, scratchCleanup), "none")
    }

    @TestCase
    public func ckg12Pos008LocalDocsGroupDoesNotTreatShellAsProtocolViolation(): Unit {
        let unsafeCommand = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"rm -rf /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs\"}}]}}"
        let outOfScope = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"grep -R ArrayList /etc\"}}]}}"
        let pathEscape = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"rg -rn ArrayList ../..\"}}]}}"
        let writeRedirect = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"rg ArrayList /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs > /tmp/out\"}}]}}"
        let pythonWrite = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"python3 -c \\\"open('/tmp/out','w').write('x')\\\"\"}}]}}"
        let pythonShell = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"python3 -c \\\"import os; os.system('ls')\\\"\"}}]}}"
        let scratchRealPath = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"cjc /tmp/test_palindrome.cj -o /Users/l3gi0n/Downloads/test_palindrome\"}}]}}"
        let scratchUnsafeCleanup = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"rm -f /tmp/test_palindrome /etc/passwd\"}}]}}"

        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, unsafeCommand), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, outOfScope), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, pathEscape), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, writeRedirect), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, pythonWrite), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, pythonShell), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, scratchRealPath), "none")
        @Expect(ckbAbcdeForbiddenEvidenceForTest(CkbAbcdeGroups.E, scratchUnsafeCleanup), "none")
    }

    @TestCase
    public func ckg12Pos007ParsesClaudeResultUsageAndTurns(): Unit {
        let transcript = "{\"type\":\"assistant\",\"message\":{\"content\":\"working\"}}\n" +
            "{\"type\":\"result\",\"subtype\":\"success\",\"num_turns\":7,\"usage\":{\"input_tokens\":100,\"output_tokens\":25,\"cache_read_input_tokens\":10,\"cache_creation_input_tokens\":5}}\n"
        let usage = ckbAbcdeParseClaudeUsageFromText(transcript, "/tmp/claude-transcript.jsonl")

        @Expect(usage.usageParseStatus, "ok")
        @Expect(usage.modelInputTokens, 100)
        @Expect(usage.modelOutputTokens, 25)
        @Expect(usage.modelCacheReadTokens, 10)
        @Expect(usage.modelCacheCreationTokens, 5)
        @Expect(usage.modelTotalTokens, 140)
        @Expect(usage.llmTurnCount, 7)
        @Expect(usage.usageSourcePath, "/tmp/claude-transcript.jsonl")
        @Expect(ckbAbcdeRenderUsageJson(usage).contains("\"usageParseStatus\":\"ok\""), true)
    }

    @TestCase
    public func ckg12Neg010UsageParserDoesNotEstimateMissingResult(): Unit {
        let usage = ckbAbcdeParseClaudeUsageFromText("{\"type\":\"assistant\",\"message\":{}}\n", "/tmp/missing.jsonl")

        @Expect(usage.usageParseStatus, "missing_result")
        @Expect(usage.modelTotalTokens, 0)
        @Expect(usage.llmTurnCount, 0)
    }

    @TestCase
    public func ckg12Neg011UsageParserRejectsMissingUsageFields(): Unit {
        let usage = ckbAbcdeParseClaudeUsageFromText("{\"type\":\"result\",\"subtype\":\"success\",\"num_turns\":3}\n", "/tmp/missing-usage.jsonl")

        @Expect(usage.usageParseStatus, "missing_usage")
        @Expect(usage.modelTotalTokens, 0)
        @Expect(usage.llmTurnCount, 0)
    }

    @TestCase
    public func ckg12Pos008CaseSummaryAggregatesUsageFields(): Unit {
        let options = CkbAbcdeRunnerOptions()
        options.runId = "unit-run"
        let rows = ArrayList<String>()
        rows.add("{\"caseId\":\"CJ-HUMANEVAL-000\",\"group\":\"A-no-ckb\",\"status\":\"passed\",\"unitPassAt1\":true,\"protocolViolation\":false,\"usageParseStatus\":\"ok\",\"modelTotalTokens\":100,\"llmTurnCount\":3}")
        rows.add("{\"caseId\":\"CJ-HUMANEVAL-000\",\"group\":\"B-ckb-context\",\"status\":\"failed\",\"unitPassAt1\":false,\"protocolViolation\":false,\"usageParseStatus\":\"missing_result\",\"modelTotalTokens\":0,\"llmTurnCount\":0}")

        let summary = ckbAbcdeRenderCaseSummaryForTest(options, "/tmp/run", "CJ-HUMANEVAL-000", rows)
        let usageCsv = ckbAbcdeRenderCaseUsageSummaryCsvRowForTest("CJ-HUMANEVAL-000", rows)

        @Expect(summary.contains("\"usageParseOkGroupCount\":1"), true)
        @Expect(summary.contains("\"caseTotalModelTokens\":100"), true)
        @Expect(summary.contains("\"caseAverageModelTokensPerGroup\":100"), true)
        @Expect(summary.contains("\"caseTotalLlmTurns\":3"), true)
        @Expect(summary.contains("\"usageParseFailedGroups\":[\"B-ckb-context\"]"), true)
        @Expect(usageCsv, "CJ-HUMANEVAL-000,1,100,100,3,3,B-ckb-context")
    }

    @TestCase
    public func ckg12Bnd003UsageAverageNullWhenNoGroupParsed(): Unit {
        @Expect(ckbAbcdeAverageTextForTest(0, 0), "null")
        @Expect(ckbAbcdeAverageTextForTest(42, 5), "8.4")
    }

    // P5-UT-01-145-CANONICAL-REQUEST-BINDING
    @TestCase
    public func p5Ut01145CanonicalRequestBindingIsExactAndUnique(): Unit {
        let context = case145CanonicalContext()
        let valid = ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, case145Transcript(context, "call-145", "h342434"), context)
        @Expect(valid.valid, true)
        @Expect(valid.evidenceHash, "h342434")
        @Expect(valid.diagnostic, "ok")

        let missing = ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, case145Transcript(context.replace("\"promptHash\":\"sha256:prompt\",", ""), "call-145", "h342434"), context)
        @Expect(missing.valid, false)
        @Expect(missing.diagnostic, "request_binding_hash_mismatch")
        let mismatch = ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, case145Transcript(context.replace("\"budget\":10", "\"budget\":9"), "call-145", "h342434"), context)
        @Expect(mismatch.valid, false)
        @Expect(mismatch.diagnostic, "request_binding_hash_mismatch")
        let extra = context.replace("\"responseMode\":\"evidence\"", "\"responseMode\":\"evidence\",\"unexpected\":true")
        @Expect(ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, case145Transcript(extra, "call-extra", "h342434"), context).diagnostic, "request_binding_hash_mismatch")
        let duplicate = case145Transcript(context, "call-145", "h342434") + "\n" + case145ToolUse(context, "call-duplicate")
        @Expect(ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, duplicate, context).diagnostic, "task_knowledge_tool_use_not_unique")
    }

    // P5-BND-01-145-RETRIEVAL-EVIDENCE-HASH
    @TestCase
    public func p5Bnd01145RetrievalEvidenceHashComesFromPairedToolResult(): Unit {
        let context = case145CanonicalContext()
        let paired = ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, case145Transcript(context, "call-145", "h342434"), context)
        @Expect(paired.valid, true); @Expect(paired.evidenceHash, "h342434")
        let unpaired = case145ToolUse(context, "call-145") + "\n" + case145ToolResult(context, "other-call", "h342434")
        @Expect(ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, unpaired, context).diagnostic, "paired_tool_result_missing")
        let duplicate = case145Transcript(context, "call-145", "h342434") + "\n" + case145ToolResult(context, "call-145", "h999")
        @Expect(ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, duplicate, context).diagnostic, "paired_tool_result_not_unique")
    }

    // T-R7-TRANSCRIPT-UT/BND/POS/NEG: Claude Code may emit null for the
    // optional success indicator, but explicit errors and invalid types stay closed.
    @TestCase
    public func r7TranscriptOptionalNullIsErrorPreservesStrictEvidenceBoundary(): Unit {
        let context = case145CanonicalContext()
        let use = case145ToolUse(context, "call-null-error")
        let result = case145ToolResult(context, "call-null-error", "h342434")
        let nullResult = result.replace("\"content\":", "\"is_error\":null,\"content\":")
        let falseResult = result.replace("\"content\":", "\"is_error\":false,\"content\":")
        let trueResult = result.replace("\"content\":", "\"is_error\":true,\"content\":")
        let invalidResult = result.replace("\"content\":", "\"is_error\":\"false\",\"content\":")

        let omitted = ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, use + "\n" + result, context)
        let explicitNull = ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, use + "\n" + nullResult, context)
        let explicitFalse = ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, use + "\n" + falseResult, context)
        @Expect(omitted.valid, true)
        @Expect(explicitNull.valid, true)
        @Expect(explicitNull.evidenceHash, "h342434")
        @Expect(explicitFalse.valid, true)
        @Expect(ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, use + "\n" + trueResult, context).diagnostic, "paired_tool_result_error")
        @Expect(ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, use + "\n" + invalidResult, context).diagnostic, "malformed_transcript_json")
    }

    // NK-BND-01-145-MALFORMED-UTF8-FAIL-CLOSED
    @TestCase
    public func nkBnd01145MalformedUtf8UnicodeLongAndSecretsFailClosed(): Unit {
        let context = case145CanonicalContext()
        @Expect(ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, "{", context).diagnostic, "malformed_transcript_json")
        @Expect(ckbAbcdeTaskKnowledgeEvidenceFromUtf8ForTest(CkbAbcdeGroups.C, [UInt8(0xff)], context.toArray()).diagnostic, "invalid_response_encoding")
        let unicodeContext = context.replace("Reverse String", "反转字符串🙂")
        @Expect(ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, case145Transcript(unicodeContext, "call-中文🙂", "h342434"), unicodeContext).valid, true)
        // One CJK rune is three UTF-8 bytes. This is the smallest whole-rune payload above 4 MiB,
        // so the boundary stays Unicode-realistic without making the 64 MiB test heap build 12 MiB.
        let hugeBuilder = StringBuilder(); for (_ in 0..1398102) { hugeBuilder.append("界") }
        let hugeTranscript = hugeBuilder.toString()
        @Expect(hugeTranscript.size > 4194304, true)
        @Expect(ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, hugeTranscript, context).diagnostic, "transcript_too_large")
        let secret = case145Transcript(context, "call-145", "token=secret")
        let secretResult = ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, secret, context)
        @Expect(secretResult.valid, false); @Expect(secretResult.diagnostic, "evidence_hash_invalid")
        @Expect(secretResult.diagnostic.contains("secret"), false)
    }

    // NK-UT-02-145-TRIAGE-BINDING / P5-E2E-01-145-CLASSIFIER-READY-REPLAY
    @TestCase
    public func p5E2e01145RenderAndTriageUseOnePairedEvidenceDecision(): Unit {
        let root = "target/case145-evidence-replay-${ckbCoreNowMillis()}"
        _ = launch("/bin/rm", ["-rf", root]).wait(); Directory.create(Path(root), recursive: true)
        let context = case145CanonicalContext(); let transcript = case145Transcript(context, "call-145", "h342434")
        File.writeTo(Path(root).join("canonical-task-context.json"), context.toArray())
        File.writeTo(Path(root).join("claude-transcript.jsonl"), transcript.toArray())
        File.writeTo(Path(root).join("claude-transcript.attempt-2.jsonl"), transcript.toArray())
        let restores = "{\"transportAttempt\":2,\"restored\":true,\"evidenceHash\":\"sha256:87add9cd09364be8c23d789965b3019bea6a20dc45e6bc970641fa0ab1dd5293\"}\n"
        let restoreHash = benchmarkGapSha256(restores)
        File.writeTo(Path(root).join("workspace-restores.jsonl"), restores.toArray())
        File.writeTo(Path(root).join("claude-attempts.jsonl"), ("{\"attempt\":1,\"transportAttempt\":1,\"exitCode\":1,\"sampleAttempt\":0,\"completeResult\":false,\"identityMatched\":false,\"workspaceRestored\":false,\"restoreEvidenceHash\":\"\"}\n"+
            "{\"attempt\":2,\"transportAttempt\":2,\"exitCode\":0,\"sampleAttempt\":1,\"completeResult\":true,\"identityMatched\":true,\"workspaceRestored\":true,\"restoreEvidenceHash\":\"sha256:87add9cd09364be8c23d789965b3019bea6a20dc45e6bc970641fa0ab1dd5293\"}\n").toArray())
        File.writeTo(Path(root).join("attempt-evidence.json"), "{\"transportAttemptCount\":2,\"sampleAttemptCount\":1,\"workspaceRestoreEvidenceHash\":\"${restoreHash}\"}\n".toArray())
        File.writeTo(Path(root).join("test-result.json"), "{\"transportAttemptCount\":2,\"sampleAttemptCount\":1,\"workspaceRestoreEvidenceHash\":\"${restoreHash}\"}\n".toArray())
        File.writeTo(Path(root).join("test.log"), "unit assertion failed 中文🙂".toArray())
        let options = CkbAbcdeRunnerOptions(); options.explicitRunMode = true; options.runMode = "development"
        options.runId = "case145-replay"; options.datasetVersion = "dataset-v1"; options.knowledgeVersion = "knowledge-v1"
        let row = ckbAbcdeRenderCaseResult(options, root, "CJ-HUMANEVAL-145", CkbAbcdeGroups.C, "failed", 0, 0, false, false, "test_failure", "cangjie_task_knowledge_pack", "none", root)
        @Expect(row.contains("\"toolEvidenceHash\":\"h342434\""), true)
        @Expect(row.contains("\"toolCoveragePass\":true"), true); @Expect(row.contains("\"knowledgeVersion\":\"knowledge-v1\""), true)
        @Expect(row.contains("\"citationCount\":1"), true); @Expect(row.contains("\"triageStatus\":\"reasoning_failure\""), true)
        @Expect(row.contains("\"firstAttemptTriage\":\"reasoning_failure\""), true); @Expect(row.contains("\"failureRoute\":\"reasoning\""), true)
        @Expect(row.contains("\"transportAttemptCount\":2"), true); @Expect(row.contains("\"sampleAttemptCount\":1"), true)
        @Expect(row.contains("\"selectedTransportAttempt\":2"), true)
        let evidence = ckbAbcdeTriageEvidenceForTest(options, "CJ-HUMANEVAL-145", 2, "test_failure", false, false, 0, 0, root)
        @Expect(evidence.contains("\"retrievalEvidenceHash\":\"h342434\""), true)
        @Expect(evidence.contains("\"transportAttempt\":2"), true); @Expect(evidence.contains("\"sampleAttempt\":1"), true)
        @Expect(evidence.contains("\"reasoningFailure\":true"), true); @Expect(triageEvalFailure(evidence).category, "reasoning_failure")
        @Expect(String.fromUtf8(File.readFrom(Path(root).join("paired-tool-evidence.json"))).contains("h342434"), true)
        Directory.create(Path(root).join("workspace/src"), recursive: true)
        File.writeTo(Path(root).join("workspace/src/solution.cj"), "package replay\npublic func solve(s: String): String { s }\n".toArray())
        File.writeTo(Path(root).join("case-result.json"), row.toArray()); File.writeTo(Path(root).join("result-evidence.json"), evidence.toArray())
        let classifierRequest = buildCkbP5ClassifierRequest(Path(root), "CJ-HUMANEVAL-145", "case145-replay")
        @Expect(classifierRequest.startsWith("{"), true); @Expect(classifierRequest.contains("\"retrievalEvidenceHash\":\"h342434\""), true)
        @Expect(classifierRequest.contains("\"toolEvidenceHash\":\"h342434\""), true); @Expect(classifierRequest.contains("\"studentSourceHash\":\"sha256:"), true)
        @Expect(classifierRequest.contains("\"attempt\":1"), true); @Expect(classifierRequest.contains("\"sourceTransportAttempt\":2"), true)
        _ = launch("/bin/rm", ["-rf", root]).wait()
    }

    // P5-E2E-01-145-CERTIFICATION-EVIDENCE-BINDING
    @TestCase
    public func p5E2e01145CertificationPersistsAndBindsTheSameEvidence(): Unit {
        let root="target/case145-cert-evidence-${ckbCoreNowMillis()}";_=launch("/bin/rm",["-rf",root]).wait();Directory.create(Path(root).join("workspace"),recursive:true);Directory.create(Path(root).join("runtime-home"),recursive:true)
        let context=case145CanonicalContext();let transcript="{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"GLM-5.2\"}\n"+case145Transcript(context,"call-cert-145","h342434")+"\n{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false,\"num_turns\":2,\"usage\":{\"input_tokens\":1,\"output_tokens\":1,\"cache_read_input_tokens\":0,\"cache_creation_input_tokens\":0}}\n"
        File.writeTo(Path(root).join("canonical-task-context.json"),context.toArray())
        let workspace=canonicalize(Path(root).join("workspace")).toString();let attemptHome=Path(root).join("runtime-home/attempt-1");Directory.create(attemptHome,recursive:true);let home=canonicalize(attemptHome).toString();let probe="{\"ok\":true,\"deniedOutsideWorkspace\":true,\"deniedTests\":true,\"deniedReference\":true,\"deniedTeacher\":true,\"deniedStore\":true,\"workspaceCanonical\":\"${workspace}\",\"runtimeHomeCanonical\":\"${home}\"}";r7WriteAttemptArtifacts(root,transcript,probe,"session-cert-145")
        let answerHash=benchmarkGapSha256("case145-answer");File.writeTo(Path(root).join("verifier-mount.json"),"{\"injectExitCode\":0,\"answerHashBefore\":\"${answerHash}\",\"answerHashAfter\":\"${answerHash}\",\"mountedAfterFreeze\":true}".toArray())
        let options=CkbAbcdeRunnerOptions();options.runId="case145-cert";options.datasetVersion="dataset-v1";options.knowledgeVersion="knowledge-v1";options.expectedModelVersion="GLM-5.2"
        let row=ckbAbcdeRenderStrictCertificationCaseForTest(options,"CJ-HUMANEVAL-145",CkbAbcdeGroups.C,root,answerHash,transcript,"tests passed",true,"none",true)
        @Expect(row.contains("\"certificationPassAt1\":true"),true);let sealed=parseCkbCertificationEvidence(row);@Expect(sealed.configHash.startsWith("sha256:"),true)
        let persisted=String.fromUtf8(File.readFrom(Path(root).join("paired-tool-evidence.json")));@Expect(persisted.contains("\"valid\":true"),true);@Expect(persisted.contains("h342434"),true)
        options.knowledgeVersion="other-version";let blocked=ckbAbcdeRenderStrictCertificationCaseForTest(options,"CJ-HUMANEVAL-145",CkbAbcdeGroups.C,root,answerHash,transcript,"tests passed",true,"task_knowledge_version_mismatch",false)
        @Expect(blocked.contains("\"certificationPassAt1\":false"),true);let blockedEvidence=parseCkbCertificationEvidence(blocked);@Expect(blockedEvidence.configHash==sealed.configHash,false);@Expect(blockedEvidence.resultEvidenceHash==sealed.resultEvidenceHash,false);@Expect(String.fromUtf8(File.readFrom(Path(root).join("paired-tool-evidence.json"))).contains("\"valid\":false"),true)
        _=launch("/bin/rm",["-rf",root]).wait()
    }

    // P5-UT-02-CANONICAL-TASKTEXT-EOL
    @TestCase
    public func p5Ut02CanonicalTaskTextRemovesOneFileTerminalLf(): Unit {
        let context = case145EolFixtureContext("Case145 中文🙂 task\n", "ut-lf")
        @Expect(context.taskText, "Case145 中文🙂 task")
        @Expect(context.signature, "func solve(s: String): String")
    }

    // P5-BND-02-CRLF-LF-NO-EOL
    @TestCase
    public func p5Bnd02CrLfLfAndNoEolAreCanonicalizedExactly(): Unit {
        @Expect(case145EolFixtureContext("line\r\n", "bnd-crlf").taskText, "line")
        @Expect(case145EolFixtureContext("line\n", "bnd-lf").taskText, "line")
        @Expect(case145EolFixtureContext("line", "bnd-none").taskText, "line")
    }

    // P5-NEG-02-INTERNAL-TRAILING-WHITESPACE-PRESERVED
    @TestCase
    public func p5Neg02InternalAndTrailingWhitespaceAreNotTrimmed(): Unit {
        @Expect(case145EolFixtureContext("first\nsecond  \n\n", "neg-blank").taskText, "first\nsecond  \n")
        @Expect(case145EolFixtureContext("trailing spaces  \n", "neg-spaces").taskText, "trailing spaces  ")
        @Expect(case145EolFixtureContext("no eol  ", "neg-no-eol").taskText, "no eol  ")
    }

    // P5-E2E-02-CASE145-RECORDED-REQUEST-REPLAY
    @TestCase
    public func p5E2e02Case145RecordedRequestReplayBindsNormalizedTaskText(): Unit {
        let root = "target/case145-v2-eol-replay-${ckbCoreNowMillis()}"
        _ = launch("/bin/rm", ["-rf", root]).wait()
        let caseRoot = Path(root).join("CJ-HUMANEVAL-145")
        Directory.create(caseRoot.join("starter/src"), recursive: true); Directory.create(caseRoot.join("tests"), recursive: true); Directory.create(caseRoot.join("translation"), recursive: true)
        let rawPrompt = "Case145 v2 recorded task 中文🙂\n"
        File.writeTo(caseRoot.join("prompt.md"), rawPrompt.toArray())
        File.writeTo(caseRoot.join("metadata.json"), "{\"targetVersion\":\"1.0.0\",\"signature\":\"func solve(s: String): String\"}".toArray())
        File.writeTo(caseRoot.join("starter/src/solution.cj"), "package fixture\nfunc solve(s: String): String { s }\n".toArray())
        File.writeTo(caseRoot.join("tests/TestMain.cj"), "main() {}\n".toArray()); File.writeTo(caseRoot.join("translation/line_translation.md"), "translation\n".toArray())
        let authority = buildCangjieHumanEvalManifest("cangjie_eval/cases/Cangjie-HumanEval", "")
        @Expect(authority.ok, true); @Expect(authority.rows.size, 164); @Expect(authority.rows[145].caseId, "CJ-HUMANEVAL-145")
        let context = ckbAbcdeBuildTaskContext(caseRoot.toString(), "CJ-HUMANEVAL-145", cangjieHumanEvalRenderAuthorityManifest(authority))
        let rendered = ckbAbcdeRenderTaskContextJson(context)
        @Expect(rawPrompt, context.taskText + "\n"); @Expect(context.promptHash, authority.rows[145].promptHash); @Expect(context.signature, authority.rows[145].signature)
        let replay = ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, case145Transcript(rendered, "call-145-v2", "h342434"), rendered)
        @Expect(replay.valid, true); @Expect(replay.diagnostic, "ok"); @Expect(replay.evidenceHash, "h342434")
        _ = launch("/bin/rm", ["-rf", root]).wait()
    }

    // RBMCP-UT-01
    @TestCase
    public func rbmcpUt01PromptRequiresOnlyEmptyBoundToolInput(): Unit {
        let context = rbmcpCanonicalContext("Use 中文🙂 strings, preserve punctuation.", "[\"String\",\"Rune\"]")
        let prompt = renderCkbAbcdePromptForMode(CkbAbcdeGroups.C, "CJ-HUMANEVAL-145", "task", context, "certification")
        @Expect(prompt.contains("call `mcp__ckb-cangjie__cangjie_task_knowledge_pack` exactly once with `{}`"), true)
        @Expect(prompt.contains("Every field must be copied exactly"), false)
    }

    // RBMCP-E2E-01
    @TestCase
    public func rbmcpE2e01V3PunctuationAndListDriftNeedNoModelRewrite(): Unit {
        let dataset = "cangjie_eval/cases/Cangjie-HumanEval"
        let authority = buildCangjieHumanEvalManifest(dataset, ""); @Expect(authority.ok, true); @Expect(authority.rows.size, 164)
        let task = ckbAbcdeBuildTaskContext("${dataset}/CJ-HUMANEVAL-145", "CJ-HUMANEVAL-145", cangjieHumanEvalRenderAuthorityManifest(authority))
        let context = ckbAbcdeRenderTaskContextJson(task)
        @Expect(context.contains("similar sum of their digits,"), true); @Expect(context.contains("[-1, -11, 1, -12, 11]"), true)
        let drifted = context.replace("similar sum of their digits,", "similar sum of their digits.").replace("[-1, -11, 1, -12, 11]", "[-11, -1, 1, -12, 11]")
        @Expect(context != drifted, true); @Expect(drifted.contains("similar sum of their digits."), true); @Expect(drifted.contains("[-11, -1, 1, -12, 11]"), true)
        let receipt = rbmcpReceipt(context, "h342434", "knowledge-v1")
        let evidence = ckbAbcdeTaskKnowledgeEvidenceForTest(CkbAbcdeGroups.C, rbmcpTranscript("{}", receipt, "call-v3"), context)
        @Expect(evidence.valid, true); @Expect(evidence.diagnostic, "ok"); @Expect(evidence.evidenceHash, "h342434")
    }
}

private func rbmcpRepeatedText(part: String, count: Int64): String {
    let out = StringBuilder(); for (_ in 0..count) { out.append(part) }; out.toString()
}

private func rbmcpCanonicalContext(taskText: String, tagsJson: String): String {
    "{\"taskId\":\"CJ-HUMANEVAL-145\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"${ckbAbcdeJsonEscape(taskText)}\",\"signature\":\"func solve(s: String): String\",\"datasetVersion\":\"dataset-v1\",\"promptHash\":\"sha256:prompt\",\"starterHash\":\"sha256:starter\",\"expectedKnowledgeTags\":${tagsJson},\"targetVersion\":\"1.0.0\",\"sourceSet\":\"all\",\"versionPolicy\":\"default\",\"budget\":10,\"responseMode\":\"evidence\"}"
}

private func rbmcpReceipt(context: String, evidenceHash: String, knowledgeVersion: String): String {
    "{\"taskId\":\"CJ-HUMANEVAL-145\",\"resultType\":\"task_knowledge_pack\",\"evidenceHash\":\"${evidenceHash}\",\"knowledgeVersion\":\"${knowledgeVersion}\",\"coverage\":{\"coveragePass\":true},\"citations\":[{\"citation\":\"official\"}],\"requestBinding\":{\"schemaVersion\":\"ckb-runner-bound-mcp-v1\",\"bindingMode\":\"runner_immutable\",\"requestHash\":\"${benchmarkGapSha256(context)}\",\"effectiveRequestHash\":\"${benchmarkGapSha256(context)}\",\"modelArgumentsHash\":\"${benchmarkGapSha256("{}")}\",\"taskId\":\"CJ-HUMANEVAL-145\"}}"
}

private func rbmcpTranscript(input: String, receipt: String, id: String): String {
    "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":\"${id}\",\"name\":\"mcp__ckb-cangjie__cangjie_task_knowledge_pack\",\"input\":${input}}]}}\n" +
        "{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"${id}\",\"content\":\"${ckbAbcdeJsonEscape(receipt)}\"}]}}"
}

private func case145EolFixtureContext(prompt: String, suffix: String): CkbAbcdeTaskContext {
    let root = "target/case145-eol-${suffix}-${ckbCoreNowMillis()}"
    let caseRoot = Path(root).join("CJ-HUMANEVAL-145")
    _ = launch("/bin/rm", ["-rf", root]).wait(); Directory.create(caseRoot.join("starter/src"), recursive: true)
    File.writeTo(caseRoot.join("prompt.md"), prompt.toArray())
    File.writeTo(caseRoot.join("starter/src/solution.cj"), "package fixture\nfunc solve(s: String): String { s }\n".toArray())
    let context = ckbAbcdeBuildTaskContext(caseRoot.toString(), "CJ-HUMANEVAL-145")
    _ = launch("/bin/rm", ["-rf", root]).wait()
    context
}

private func case145CanonicalContext(): String {
    "{\"taskId\":\"CJ-HUMANEVAL-145\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"Reverse String\",\"signature\":\"public func solve(s: String): String\",\"datasetVersion\":\"dataset-v1\",\"promptHash\":\"sha256:prompt\",\"starterHash\":\"sha256:starter\",\"expectedKnowledgeTags\":[\"String\",\"Rune\"],\"targetVersion\":\"1.0.0\",\"sourceSet\":\"all\",\"versionPolicy\":\"default\",\"budget\":10,\"responseMode\":\"evidence\"}"
}

private func case145ToolUse(context: String, id: String): String {
    "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":\"${id}\",\"name\":\"mcp__ckb-cangjie__cangjie_task_knowledge_pack\",\"input\":{}}]}}"
}

private func case145ToolResult(context: String, id: String, evidenceHash: String): String {
    let receipt = rbmcpReceipt(context, evidenceHash, "knowledge-v1")
    "{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"${id}\",\"content\":\"${ckbAbcdeJsonEscape(receipt)}\"}]}}"
}

private func case145Transcript(context: String, id: String, evidenceHash: String): String {
    case145ToolUse(context, id) + "\n" + case145ToolResult(context, id, evidenceHash)
}

private func r7WriteAttemptArtifacts(root:String,transcript:String,probe:String,session:String):Unit{
    File.writeTo(Path(root).join("runtime-policy.json"),"{\"model\":\"GLM-5.2\",\"modelTimeoutSeconds\":180}".toArray())
    let home=canonicalize(Path(root).join("runtime-home/attempt-1")).toString();let diagnostic="{}\n";File.writeTo(Path(root).join("session-id.attempt-1.txt"),session.toArray());File.writeTo(Path(root).join("session-id.txt"),session.toArray());File.writeTo(Path(root).join("sandbox-probe.attempt-1.json"),probe.toArray());File.writeTo(Path(root).join("sandbox-probe.json"),probe.toArray());File.writeTo(Path(root).join("claude-transcript.attempt-1.jsonl"),transcript.toArray());File.writeTo(Path(root).join("claude-transcript.jsonl"),transcript.toArray());File.writeTo(Path(root).join("claude.attempt-1.stderr.log"),"".toArray());File.writeTo(Path(root).join("model-transport-diagnostic.attempt-1.json"),diagnostic.toArray());File.writeTo(Path(root).join("workspace-restores.jsonl"),"".toArray())
    let attempt="{\"attempt\":1,\"transportAttempt\":1,\"modelTimeoutSeconds\":180,\"sampleAttempt\":1,\"exitCode\":0,\"classification\":\"business_sample\",\"completeResult\":true,\"identityMatched\":true,\"workspaceRestored\":false,\"restoreEvidenceHash\":\"\",\"sessionIdHash\":\"${benchmarkGapSha256(session)}\",\"runtimeHomeId\":\"${benchmarkGapSha256(home)}\",\"sandboxProbeHash\":\"${benchmarkGapSha256(probe)}\",\"transcriptHash\":\"${benchmarkGapSha256(transcript)}\",\"stderrHash\":\"${benchmarkGapSha256("")}\",\"diagnosticHash\":\"${benchmarkGapSha256(diagnostic)}\"}\n";File.writeTo(Path(root).join("claude-attempts.jsonl"),attempt.toArray());let summary="{\"transportAttemptCount\":1,\"sampleAttemptCount\":1,\"lastAuditedTransportAttempt\":1,\"selectedBusinessSample\":1,\"selectedTransportAttempt\":1,\"retryCount\":0,\"unresolvedTransport\":0,\"attemptLineageHash\":\"${ckbAbcdeAttemptLineageHash(attempt,"")}\",\"workspaceRestoreEvidenceHash\":\"${benchmarkGapSha256("")}\"}";File.writeTo(Path(root).join("attempt-evidence.json"),summary.toArray());File.writeTo(Path(root).join("test-result.json"),summary.toArray())
}
