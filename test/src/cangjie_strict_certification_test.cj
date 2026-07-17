package cangjie_community_knowledge_base_test

import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieStrictCertificationTest {
    @TestCase
    public func p7CliBnd01UnknownDuplicateAndMissingValuesFailClosed(): Unit {
        @Expect(ckbAbcdeStrictUsageDiagnostic(["cangjie-eval-abcde", "--unknown"]), "unknown_argument:--unknown")
        @Expect(ckbAbcdeStrictUsageDiagnostic(["cangjie-eval-abcde", "--run-id", "one", "--run-id", "two"]), "duplicate_argument:--run-id")
        @Expect(ckbAbcdeStrictUsageDiagnostic(["cangjie-eval-abcde", "--manifest"]), "missing_argument_value:--manifest")
        @Expect(ckbAbcdeStrictUsageDiagnostic(["--run-id", "one"]), "command_required")
    }

    @TestCase
    public func p7CliPos01CompleteCertificationArgumentsAreAccepted(): Unit {
        @Expect(ckbAbcdeStrictUsageDiagnostic(["cangjie-eval-abcde", "--run-mode", "certification", "--run-id", "cert-中文🙂", "--dataset-version", "dataset-v1", "--knowledge-version", "knowledge-v1", "--model-fingerprint", "sha256:value", "--groups", "C-ckb-mcp-stdio", "--manifest", "authority.jsonl", "--certification-preflight", "preflight.json", "--certification-run-manifest", "run-manifest.json", "--expected-model-version", "GLM-5.2", "--provider-identity-hash", "sha256:value", "--provider-identity-artifact", "provider.json"]), "ok")
    }

    @TestCase
    public func p7Ut01StrictRowAndGateValidateAllBoundFields(): Unit {
        let authority=p7Authority();let rows=p7Rows(164,CkbAbcdeGroups.C)
        let gate=ckbStrictCertificationGate(rows,authority)
        @Expect(gate.ok,true);@Expect(gate.total,164);@Expect(gate.unitPassAt1,164);@Expect(gate.invalid,0)
        let json=renderCkbStrictCertificationGateJson(gate);let md=renderCkbStrictCertificationGateMarkdown(gate)
        @Expect(json.contains("\"unitPassAt1\":164"),true);@Expect(md.contains("unitPassAt1: 164"),true)
        let parsed=parseCkbCertificationEvidence(rows.split("\n")[0]);@Expect(parsed.valid,true)
        let multiTurn=p7Row(0,CkbAbcdeGroups.C);multiTurn.llmTurnCount=21;sealCkbCertificationEvidence(multiTurn);@Expect(ckbCertificationEvidenceDiagnostic(multiTurn),"ok");let multiJson=renderCkbCertificationEvidenceJson(multiTurn);@Expect(multiJson.contains("\"sampleAttemptCount\":1"),true);@Expect(parseCkbCertificationEvidence(multiJson).llmTurnCount,21)
        parsed.answerHash=benchmarkGapSha256("tampered");@Expect(ckbCertificationEvidenceDiagnostic(parsed),"result_evidence_hash_mismatch")
    }

    @TestCase
    public func p7Bnd01Rejects163165DuplicateAndMissing(): Unit {
        let authority=p7Authority()
        @Expect(ckbStrictCertificationGate(p7Rows(163,CkbAbcdeGroups.C),authority).ok,false)
        @Expect(ckbStrictCertificationGate(p7Rows(165,CkbAbcdeGroups.C),authority).ok,false)
        let duplicate=p7DuplicateRows()
        let gate=ckbStrictCertificationGate(duplicate,authority);@Expect(gate.ok,false);@Expect(p7Diagnostics(gate).contains("duplicate_case"),true);@Expect(p7Diagnostics(gate).contains("missing_case"),true)
    }

    @TestCase
    public func p7Pos01FakeExecutorUsesReal164OrchestrationAndUniqueIsolation(): Unit {
        let root=p7EmptyRoot("p7-pos");let gate=orchestrateCkbStrictCertification(root,p7Authority(),p7Template(),P7FakeExecutor())
        @Expect(gate.ok,true);@Expect(gate.total,164);@Expect(exists(Path(root).join("cases").join("CJ-HUMANEVAL-163").join("result-evidence.json")),true)
        @Expect(exists(Path(root).join("certification-gate.json")),true)
    }

    @TestCase
    public func p7Neg01RejectsRetryDriftExposureIsolationAndMalformedUnicode(): Unit {
        let authority=p7Authority();let valid=p7Rows(164,CkbAbcdeGroups.C)
        @Expect(ckbStrictCertificationGate(valid.replace("\"retryUsed\":false","\"retryUsed\":true"),authority).ok,false)
        let noSample=p7Row(0,CkbAbcdeGroups.C);noSample.sampleAttemptCount=0;sealCkbCertificationEvidence(noSample);@Expect(ckbCertificationEvidenceDiagnostic(noSample),"sample_attempt_count_must_equal_one")
        let twoSamples=p7Row(0,CkbAbcdeGroups.C);twoSamples.sampleAttemptCount=2;sealCkbCertificationEvidence(twoSamples);@Expect(ckbCertificationEvidenceDiagnostic(twoSamples),"sample_attempt_count_must_equal_one")
        let noTurns=p7Row(0,CkbAbcdeGroups.C);noTurns.llmTurnCount=0;sealCkbCertificationEvidence(noTurns);@Expect(ckbCertificationEvidenceDiagnostic(noTurns),"llm_turn_count_required")
        let legacyV1=p7Row(0,CkbAbcdeGroups.C);legacyV1.schemaVersion="ckb-humaneval-certification-result-v1";sealCkbCertificationEvidence(legacyV1);@Expect(ckbCertificationEvidenceDiagnostic(legacyV1),"unknown_schema")
        @Expect(ckbStrictCertificationGate(valid.replace("\"knowledgeVersion\":\"knowledge-v1\"","\"knowledgeVersion\":\"knowledge-v2\""),authority).ok,false)
        @Expect(ckbStrictCertificationGate(valid.replace("\"hiddenTestExposure\":0","\"hiddenTestExposure\":1"),authority).ok,false)
        let firstWorkspace=parseCkbCertificationEvidence(valid.split("\n")[0]).workspaceId
        let isolationReuse=valid.replace("\"workspaceId\":\"${benchmarkGapSha256("workspace-1")}\"","\"workspaceId\":\"${firstWorkspace}\"")
        @Expect(ckbStrictCertificationGate(isolationReuse,authority).ok,false)
        let wrongModel=p7Row(0,CkbAbcdeGroups.C);wrongModel.observedModelVersion="OpenRouter Claude Opus 4.6";sealCkbCertificationEvidence(wrongModel);@Expect(ckbCertificationEvidenceDiagnostic(wrongModel),"observed_model_identity_mismatch")
        let configRoot=p7EmptyRoot("p7-config");let config=canonicalize(Path(configRoot)).join("ckb.conf").toString();File.writeTo(Path(config),"network.enabled=false\n".toArray())
        let options=CkbAbcdeRunnerOptions();options.explicitRunMode=true;options.runMode="certification";options.datasetVersion="dataset-v1";options.knowledgeVersion="knowledge-v1";options.modelFingerprint="frozen";options.claudeBin="/usr/bin/true";options.ckbConfig=config;options.groups.clear();options.groups.add(CkbAbcdeGroups.C);@Expect(ckbAbcdeDevelopmentOptionsDiagnostic(options),"certification_requires_authority_manifest")
        let profile=ckbAbcdeCertificationSandboxProfile("/tmp/p7/workspace","/tmp/p7/home","/tmp/ckb",config,"/tmp/store","/tmp/dataset/CJ-HUMANEVAL-000","/usr/bin/true","/usr/bin/true");@Expect(profile.contains("/tests"),true);@Expect(profile.contains("/translation"),true);@Expect(profile.contains("CangjieTeacher"),true);@Expect(profile.contains("(deny file-read*"),true)
        let command=ckbAbcdeCertificationClaudeCommand("/tmp/group","/tmp/home","/tmp/profile.sb","/usr/bin/true","GLM-5.2","/tmp/transcript","/tmp/stderr");@Expect(command.contains("XDG_CACHE_HOME"),true);@Expect(command.contains("CLAUDE_CONFIG_DIR"),true);@Expect(command.contains("--session-id"),true);@Expect(command.contains("--model 'GLM-5.2'"),true);@Expect(command.contains("ANTHROPIC_MAX_RETRIES=0"),true);@Expect(command.contains("dangerously-skip-permissions"),false);@Expect(command.contains("env -u ANTHROPIC"),false);@Expect(command.contains("fallback-model"),false)
        @Expect(parseCkbCertificationEvidence("{\"caseId\":\"中文🙂\"").diagnostic,"malformed_json")
        let badBytes:Array<UInt8>=[0xff,0xfe,0x80];var decoded="not_caught";try{decoded=String.fromUtf8(badBytes)}catch(_:Exception){decoded="invalid_response_encoding"};@Expect(decoded,"invalid_response_encoding")
        let productionRow=parseCkbCertificationEvidence(p7ProductionRendererRow(false));@Expect(productionRow.valid,true);@Expect(productionRow.certificationPassAt1,true)
        let tamperedProbe=parseCkbCertificationEvidence(p7ProductionRendererRow(true));@Expect(tamperedProbe.valid,false);@Expect(tamperedProbe.diagnostic,"auditable_sandbox_deny_required")
        remove(Path(configRoot),recursive:true)
    }

    @TestCase
    public func p7E2e01FakeIsExplicitlyNotRealModelProof(): Unit {
        let root=p7EmptyRoot("p7-e2e");let gate=orchestrateCkbStrictCertification(root,p7Authority(),p7Template(),P7FakeExecutor())
        @Expect(gate.ok,true);@Expect(gate.group,CkbAbcdeGroups.C);@Expect(gate.retryUsed,0);@Expect(gate.hiddenTestExposure,0)
        let evidence=String.fromUtf8(File.readFrom(Path(root).join("results.jsonl")))
        @Expect(evidence.split("\n").size>=164,true)
        @Expect(evidence.contains("realModelProof"),false) // offline fake validates orchestration, never model capability.
        let audit=auditCkbStrictCertificationFromText(evidence,p7Authority());@Expect(audit.contains("\"ok\":true"),true);@Expect(audit.contains("answerHash"),false);@Expect(audit.contains("testHash"),false)
    }

    @TestCase
    public func p7Pos02RealMacOsSandboxAllowsRuntimeAndEnforcesDenyRules(): Unit {
        if (!exists(Path("/usr/bin/sandbox-exec"))) { return }
        let root=p7EmptyRoot("p7-real-sandbox-中文🙂");let workspace="${root}/workspace";let home="${root}/runtime-home";let caseSrc="${root}/authority/CJ-HUMANEVAL-000";let config="${root}/ckb.conf"
        Directory.create(Path(workspace),recursive:true);Directory.create(Path(home),recursive:true);Directory.create(Path(caseSrc).join("tests"),recursive:true);Directory.create(Path(caseSrc).join("translation"),recursive:true)
        File.writeTo(Path(config),"network.enabled=false\n".toArray());File.writeTo(Path(caseSrc).join("tests/hidden.txt"),"hidden".toArray());File.writeTo(Path(caseSrc).join("translation/reference.txt"),"reference".toArray())
        let profilePath="${root}/certification.sb";let profile=ckbAbcdeCertificationSandboxProfile(workspace,home,"/usr/bin/true",config,root,caseSrc,"/usr/bin/true","/usr/bin/true");File.writeTo(Path(profilePath),profile.toArray())
        @Expect(profile.contains("(import \"system.sb\")"),true);@Expect(profile.contains("(subpath \"/System\")"),false);@Expect(profile.contains("(subpath \"/usr\")"),false)
        let probe=ckbAbcdeCertificationSandboxProbeForTest(profilePath,workspace,home,caseSrc)
        @Expect(probe.exitCode,0);@Expect(probe.stdout.contains("\"ok\":true"),true);@Expect(probe.stdout.contains("\"stdinReadable\":true"),true);@Expect(exists(Path(workspace).join(".sandbox-write-probe")),false);@Expect(exists(Path(root).join(".sandbox-outside-probe")),false)
    }
}

private class P7FakeExecutor <: CkbCertificationExecutor {
    public override func execute(caseId:String,workspace:String,sessionId:String,runtimeHome:String):CkbCertificationCaseEvidence{
        let r=CkbCertificationCaseEvidence();r.observedModelVersion="GLM-5.2";r.claudeCodeVersion="claude-code-1.0";r.isolationEvidenceHash=benchmarkGapSha256("deny:${workspace}:${runtimeHome}");r.answerHash=benchmarkGapSha256("answer:${caseId}:中文🙂");r.transcriptHash=benchmarkGapSha256("transcript:${caseId}");r.testHash=benchmarkGapSha256("verifier:${caseId}");r.configHash=benchmarkGapSha256("config");r.artifactHash=benchmarkGapSha256("artifact:${caseId}");r.sampleAttemptCount=1;r.llmTurnCount=21;r.sandboxDeniedOutsideWorkspace=true;r.verifierMountedAfterAnswerFreeze=true;r.certificationPassAt1=true;r
    }
}

private func p7Template():CkbCertificationCaseEvidence{let r=CkbCertificationCaseEvidence();r.runId="certification-run";r.group=CkbAbcdeGroups.C;r.datasetVersion="dataset-v1";r.knowledgeVersion="knowledge-v1";r.modelFingerprint="frozen-fingerprint";r.expectedModelVersion="GLM-5.2";r.observedModelVersion="GLM-5.2";r.claudeCodeVersion="claude-code-1.0";r.providerIdentityHash=benchmarkGapSha256("provider-identity");r.preflightHash=benchmarkGapSha256("preflight");r.runManifestHash=benchmarkGapSha256("manifest");r.authorityCaseHash=benchmarkGapSha256("case");r.authorityTestsHash=benchmarkGapSha256("tests");r}
private func p7Row(i:Int64,group:String):CkbCertificationCaseEvidence{let r=p7Template();r.caseId=if(i<10){"CJ-HUMANEVAL-00${i}"}else if(i<100){"CJ-HUMANEVAL-0${i}"}else{"CJ-HUMANEVAL-${i}"};r.group=group;r.workspaceId=benchmarkGapSha256("workspace-${i}");r.sessionId=benchmarkGapSha256("session-${i}");r.runtimeHomeId=benchmarkGapSha256("home-${i}");r.isolationEvidenceHash=benchmarkGapSha256("deny-${i}");r.answerHash=benchmarkGapSha256("answer-${i}");r.transcriptHash=benchmarkGapSha256("transcript-${i}");r.testHash=benchmarkGapSha256("test-${i}");r.configHash=benchmarkGapSha256("config-${i}");r.artifactHash=benchmarkGapSha256("artifact-${i}");r.sampleAttemptCount=1;r.llmTurnCount=21;r.sandboxDeniedOutsideWorkspace=true;r.verifierMountedAfterAnswerFreeze=true;r.certificationPassAt1=true;sealCkbCertificationEvidence(r);r}
private func p7Rows(n:Int64,group:String):String{let authority=parseCangjieHumanEvalAuthorityManifest(p7Authority());var out="";for(i in 0..n){let row=p7Row(i,group);if(i<authority.rows.size){row.authorityCaseHash=authority.rows[i].caseHash;row.authorityTestsHash=authority.rows[i].testsHash};sealCkbCertificationEvidence(row);out+=renderCkbCertificationEvidenceJson(row)+"\n"};out}
private func p7DuplicateRows():String{let authority=parseCangjieHumanEvalAuthorityManifest(p7Authority());var out="";for(i in 0..163){let row=p7Row(i,CkbAbcdeGroups.C);row.authorityCaseHash=authority.rows[i].caseHash;row.authorityTestsHash=authority.rows[i].testsHash;sealCkbCertificationEvidence(row);out+=renderCkbCertificationEvidenceJson(row)+"\n"};let duplicate=p7Row(162,CkbAbcdeGroups.C);duplicate.authorityCaseHash=authority.rows[162].caseHash;duplicate.authorityTestsHash=authority.rows[162].testsHash;sealCkbCertificationEvidence(duplicate);out+=renderCkbCertificationEvidenceJson(duplicate)+"\n";out}
private func p7Authority():String{let cache=Path("../target/p7-authority-cache.jsonl");if(exists(cache)){try{return String.fromUtf8(File.readFrom(cache))}catch(_:Exception){}};let value=cangjieHumanEvalRenderAuthorityManifest(buildCangjieHumanEvalManifest("cangjie_eval/cases/Cangjie-HumanEval",""));File.writeTo(cache,value.toArray());value}
private func p7EmptyRoot(prefix:String):String{let p="../target/${prefix}-${DateTime.now().toUnixTimeStamp().toMilliseconds()}-${benchmarkGapSha256(prefix+DateTime.now().toString()).replace("sha256:","")}";Directory.create(Path(p),recursive:true);p}
private func p7Diagnostics(g:CkbStrictCertificationGateResult):String{var out="";for(v in g.diagnostics){out+=v+"\n"};out}
private func p7ProductionRendererRow(tamper:Bool):String{
    let root=p7EmptyRoot(if(tamper){"p7-render-tamper"}else{"p7-render"});let groupRoot="${root}/group";let workspace="${groupRoot}/workspace";let home="${groupRoot}/runtime-home";Directory.create(Path(workspace),recursive:true);Directory.create(Path(home),recursive:true)
    let options=CkbAbcdeRunnerOptions();options.runId="certification-run";options.runMode="certification";options.datasetVersion=parseCangjieHumanEvalAuthorityManifest(p7Authority()).datasetVersion;options.knowledgeVersion="knowledge-v1";options.modelFingerprint="frozen-fingerprint";options.expectedModelVersion="GLM-5.2";options.providerIdentityHash=benchmarkGapSha256("provider");options.manifestPath="${root}/authority.jsonl";options.certificationPreflightPath="${root}/preflight.json";options.certificationRunManifestPath="${root}/run-manifest.json"
    File.writeTo(Path(options.manifestPath),p7Authority().toArray());File.writeTo(Path(options.certificationPreflightPath),"preflight".toArray());File.writeTo(Path(options.certificationRunManifestPath),"{\"runManifestHash\":\"${benchmarkGapSha256("manifest")}\"}".toArray());File.writeTo(Path("${groupRoot}/session-id.txt"),"session-uuid".toArray());File.writeTo(Path("${groupRoot}/mcp-config.json"),"{}".toArray());File.writeTo(Path("${groupRoot}/runtime-policy.json"),"{\"sampleAttempts\":1,\"internalTurns\":\"audited_not_gated\"}".toArray());File.writeTo(Path("${groupRoot}/claude-attempts.jsonl"),"{\"attempt\":1,\"transportAttempt\":1,\"sampleAttempt\":1,\"exitCode\":0,\"completeResult\":true,\"identityMatched\":true}\n".toArray())
    let answerHash=benchmarkGapSha256("answer中文🙂");let probe="{\"ok\":${!tamper},\"deniedOutsideWorkspace\":true,\"deniedTests\":true,\"deniedReference\":true,\"deniedTeacher\":true,\"workspaceCanonical\":\"${canonicalize(Path(workspace)).toString()}\",\"runtimeHomeCanonical\":\"${canonicalize(Path(home)).toString()}\"}";File.writeTo(Path("${groupRoot}/sandbox-probe.json"),probe.toArray());File.writeTo(Path("${groupRoot}/verifier-mount.json"),"{\"injectExitCode\":0,\"answerHashBefore\":\"${answerHash}\",\"answerHashAfter\":\"${answerHash}\",\"mountedAfterFreeze\":true}".toArray())
    let transcript="{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"GLM-5.2\"}\n{\"type\":\"result\",\"input_tokens\":1,\"output_tokens\":1,\"num_turns\":21}\n"
    ckbAbcdeRenderStrictCertificationCaseForTest(options,"CJ-HUMANEVAL-000",CkbAbcdeGroups.C,groupRoot,answerHash,transcript,"tests passed",true,"none",true)
}
