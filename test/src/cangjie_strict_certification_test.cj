package cangjie_community_knowledge_base_test

import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.env.getVariable
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
        let authority=p7Authority();let rows=p7Rows(164,CkbAbcdeGroups.D)
        let gate=ckbStrictCertificationGate(rows,authority)
        @Expect(gate.ok,true);@Expect(gate.total,164);@Expect(gate.unitPassAt1,164);@Expect(gate.invalid,0)
        let json=renderCkbStrictCertificationGateJson(gate);let md=renderCkbStrictCertificationGateMarkdown(gate)
        @Expect(json.contains("\"unitPassAt1\":164"),true);@Expect(md.contains("unitPassAt1: 164"),true)
        let parsed=parseCkbCertificationEvidence(rows.split("\n")[0]);@Expect(parsed.valid,true)
        @Expect(parsed.schemaVersion,"ckb-humaneval-certification-result-v3");@Expect(parsed.transportAttemptCount,1);@Expect(parsed.retryCount,0);@Expect(parsed.unresolvedTransport,0);@Expect(parsed.attemptLineageHash.startsWith("sha256:"),true)
        let multiTurn=p7Row(0,CkbAbcdeGroups.D);multiTurn.llmTurnCount=21;sealCkbCertificationEvidence(multiTurn);@Expect(ckbCertificationEvidenceDiagnostic(multiTurn),"ok");let multiJson=renderCkbCertificationEvidenceJson(multiTurn);@Expect(multiJson.contains("\"sampleAttemptCount\":1"),true);@Expect(parseCkbCertificationEvidence(multiJson).llmTurnCount,21)
        parsed.answerHash=benchmarkGapSha256("tampered");@Expect(ckbCertificationEvidenceDiagnostic(parsed),"result_evidence_hash_mismatch")
    }

    @TestCase
    public func p7Bnd01Rejects163165DuplicateAndMissing(): Unit {
        let authority=p7Authority()
        @Expect(ckbStrictCertificationGate(p7Rows(163,CkbAbcdeGroups.D),authority).ok,false)
        @Expect(ckbStrictCertificationGate(p7Rows(165,CkbAbcdeGroups.D),authority).ok,false)
        let duplicate=p7DuplicateRowsD()
        let gate=ckbStrictCertificationGate(duplicate,authority);@Expect(gate.ok,false);@Expect(p7Diagnostics(gate).contains("duplicate_case"),true);@Expect(p7Diagnostics(gate).contains("missing_case"),true)
    }

    @TestCase
    public func r7Bnd01ExhaustedTransportIsValidEvidenceButNeverCertified(): Unit {
        let authority=parseCangjieHumanEvalAuthorityManifest(p7Authority());var rows=""
        for(i in 0..164){
            let row=p7Row(i,CkbAbcdeGroups.D);row.authorityCaseHash=authority.rows[i].caseHash;row.authorityTestsHash=authority.rows[i].testsHash
            if(i==145){row.sampleAttemptCount=0;row.selectedBusinessSample=0;row.unresolvedTransport=1;row.certificationPassAt1=false;row.observedModelVersion="";row.llmTurnCount=0}
            sealCkbCertificationEvidence(row);rows+=renderCkbCertificationEvidenceJson(row)+"\n"
        }
        let gate=ckbStrictCertificationGate(rows,p7Authority())
        @Expect(gate.ok,false);@Expect(gate.total,164);@Expect(gate.invalid,0);@Expect(gate.unresolvedTransport,1);@Expect(gate.failed,1);@Expect(gate.unitPassAt1,163)
    }

    @TestCase
    public func p7Pos01FakeExecutorUsesReal164OrchestrationAndUniqueIsolation(): Unit {
        let root=p7EmptyRoot("p7-pos");let template=p7Template();template.group=CkbAbcdeGroups.D;let gate=orchestrateCkbStrictCertification(root,p7Authority(),template,P7FakeExecutor())
        @Expect(gate.ok,true);@Expect(gate.total,164);@Expect(exists(Path(root).join("cases").join("CJ-HUMANEVAL-163").join("result-evidence.json")),true)
        @Expect(exists(Path(root).join("certification-gate.json")),true)
    }

    @TestCase
    public func p7Neg01RejectsRetryDriftExposureIsolationAndMalformedUnicode(): Unit {
        let authority=p7Authority();let valid=p7Rows(164,CkbAbcdeGroups.D)
        @Expect(ckbStrictCertificationGate(valid.replace("\"retryUsed\":false","\"retryUsed\":true"),authority).ok,false)
        let noSample=p7Row(0,CkbAbcdeGroups.D);noSample.sampleAttemptCount=0;noSample.selectedBusinessSample=0;noSample.unresolvedTransport=1;noSample.certificationPassAt1=false;noSample.observedModelVersion="";noSample.llmTurnCount=0;sealCkbCertificationEvidence(noSample);@Expect(ckbCertificationEvidenceDiagnostic(noSample),"ok")
        let twoSamples=p7Row(0,CkbAbcdeGroups.D);twoSamples.sampleAttemptCount=2;sealCkbCertificationEvidence(twoSamples);@Expect(ckbCertificationEvidenceDiagnostic(twoSamples),"sample_attempt_count_invalid")
        let noTurns=p7Row(0,CkbAbcdeGroups.D);noTurns.llmTurnCount=0;sealCkbCertificationEvidence(noTurns);@Expect(ckbCertificationEvidenceDiagnostic(noTurns),"llm_turn_count_required")
        let legacyV1=p7Row(0,CkbAbcdeGroups.D);legacyV1.schemaVersion="ckb-humaneval-certification-result-v1";sealCkbCertificationEvidence(legacyV1);@Expect(ckbCertificationEvidenceDiagnostic(legacyV1),"unknown_schema")
        let legacyV2=p7Row(0,CkbAbcdeGroups.D);legacyV2.schemaVersion="ckb-humaneval-certification-result-v2";sealCkbCertificationEvidence(legacyV2);@Expect(ckbCertificationEvidenceDiagnostic(legacyV2),"unknown_schema")
        let completeV3=p7Row(0,CkbAbcdeGroups.D);let missingLineage=renderCkbCertificationEvidenceJson(completeV3).replace(",\"attemptLineageHash\":\"${completeV3.attemptLineageHash}\"","");@Expect(parseCkbCertificationEvidence(missingLineage).valid,false)
        @Expect(ckbStrictCertificationGate(valid.replace("\"knowledgeVersion\":\"knowledge-v1\"","\"knowledgeVersion\":\"knowledge-v2\""),authority).ok,false)
        let staleDataset=p7RowsWithDatasetD("stale-dataset")
        let staleGate=ckbStrictCertificationGate(staleDataset,authority);@Expect(staleGate.ok,false);@Expect(p7Diagnostics(staleGate).contains("authority_dataset_version_mismatch"),true)
        @Expect(ckbStrictCertificationGate(valid.replace("\"hiddenTestExposure\":0","\"hiddenTestExposure\":1"),authority).ok,false)
        let firstWorkspace=parseCkbCertificationEvidence(valid.split("\n")[0]).workspaceId
        let isolationReuse=valid.replace("\"workspaceId\":\"${benchmarkGapSha256("workspace-1")}\"","\"workspaceId\":\"${firstWorkspace}\"")
        @Expect(ckbStrictCertificationGate(isolationReuse,authority).ok,false)
        let wrongModel=p7Row(0,CkbAbcdeGroups.D);wrongModel.observedModelVersion="OpenRouter Claude Opus 4.6";sealCkbCertificationEvidence(wrongModel);@Expect(ckbCertificationEvidenceDiagnostic(wrongModel),"observed_model_identity_mismatch")
        let recovered=p7Row(0,CkbAbcdeGroups.D);recovered.transportAttemptCount=2;recovered.retryCount=1;recovered.lastAuditedTransportAttempt=2;recovered.selectedBusinessSample=2;recovered.attemptLineageHash=benchmarkGapSha256("timeout->sample");sealCkbCertificationEvidence(recovered);@Expect(ckbCertificationEvidenceDiagnostic(recovered),"ok")
        let staleSelection=p7Row(0,CkbAbcdeGroups.D);staleSelection.transportAttemptCount=2;staleSelection.retryCount=1;staleSelection.attemptLineageHash=benchmarkGapSha256("timeout->stale-sample");sealCkbCertificationEvidence(staleSelection);@Expect(ckbCertificationEvidenceDiagnostic(staleSelection),"transport_selection_invalid")
        let unresolved=p7Row(0,CkbAbcdeGroups.D);unresolved.sampleAttemptCount=0;unresolved.selectedBusinessSample=0;unresolved.unresolvedTransport=1;unresolved.certificationPassAt1=false;unresolved.observedModelVersion="";unresolved.llmTurnCount=0;sealCkbCertificationEvidence(unresolved);@Expect(ckbCertificationEvidenceDiagnostic(unresolved),"ok")
        let businessRetry=p7Row(0,CkbAbcdeGroups.D);businessRetry.retryUsed=true;businessRetry.agentRetryCount=1;sealCkbCertificationEvidence(businessRetry);@Expect(ckbCertificationEvidenceDiagnostic(businessRetry),"business_retry_forbidden")
        let configRoot=p7EmptyRoot("p7-config");let config=canonicalize(Path(configRoot)).join("ckb.conf").toString();File.writeTo(Path(config),"network.enabled=false\n".toArray())
        let options=CkbAbcdeRunnerOptions();options.explicitRunMode=true;options.runMode="certification";options.datasetVersion="dataset-v1";options.knowledgeVersion="knowledge-v1";options.modelFingerprint="frozen";options.claudeBin="/usr/bin/true";options.ckbConfig=config;options.groups.clear();options.groups.add(CkbAbcdeGroups.D);@Expect(ckbAbcdeDevelopmentOptionsDiagnostic(options),"certification_requires_authority_manifest")
        let authorityPath=Path(configRoot).join("authority.jsonl").toString();File.writeTo(Path(authorityPath),authority.toArray());options.manifestPath=authorityPath;options.providerIdentityHash=benchmarkGapSha256("provider")
        @Expect(ckbAbcdeDevelopmentOptionsDiagnostic(options),"authority_dataset_version_mismatch")
        @Expect(ckbAbcdeCertificationEntryDiagnostic(options,Path(configRoot).join("run").toString()),"authority_dataset_version_mismatch")
        options.datasetVersion=parseCangjieHumanEvalAuthorityManifest(authority).datasetVersion
        @Expect(ckbAbcdeDevelopmentOptionsDiagnostic(options),"certification_requires_p6_artifacts")
        @Expect(ckbAbcdeCertificationEntryDiagnostic(options,Path(configRoot).join("run").toString()),"p6_artifact_missing")
        let profile=ckbAbcdeCertificationSandboxProfile("/tmp/p7/workspace","/tmp/p7/home","/tmp/ckb",config,"/tmp/store","/tmp/dataset/CJ-HUMANEVAL-000","/usr/bin/true","/usr/bin/true");@Expect(profile.contains("/tests"),true);@Expect(profile.contains("/translation"),true);@Expect(profile.contains("CangjieTeacher"),true);@Expect(profile.contains("(deny file-read*"),true)
        let command=ckbAbcdeCertificationClaudeCommand("/tmp/group","/tmp/home","/tmp/profile.sb","/usr/bin/true","GLM-5.2","/tmp/transcript","/tmp/stderr");@Expect(command.contains("XDG_CACHE_HOME"),true);@Expect(command.contains("CLAUDE_CONFIG_DIR"),true);@Expect(command.contains("--session-id"),true);@Expect(command.contains("--model 'GLM-5.2'"),true);@Expect(command.contains("ANTHROPIC_MAX_RETRIES=0"),true);@Expect(command.split("--dangerously-skip-permissions").size,2);@Expect(command.contains("env -u ANTHROPIC"),false);@Expect(command.contains("fallback-model"),false)
        @Expect(parseCkbCertificationEvidence("{\"caseId\":\"中文🙂\"").diagnostic,"malformed_json")
        let badBytes:Array<UInt8>=[0xff,0xfe,0x80];var decoded="not_caught";try{decoded=String.fromUtf8(badBytes)}catch(_:Exception){decoded="invalid_response_encoding"};@Expect(decoded,"invalid_response_encoding")
        let productionRow=parseCkbCertificationEvidence(p7ProductionRendererRow(false));@Expect(productionRow.valid,true);@Expect(productionRow.certificationPassAt1,true)
        let tamperedProbe=parseCkbCertificationEvidence(p7ProductionRendererRow(true));@Expect(tamperedProbe.valid,false);@Expect(tamperedProbe.diagnostic,"auditable_sandbox_deny_required")
        remove(Path(configRoot),recursive:true)
    }

    @TestCase
    public func p7E2e01FakeIsExplicitlyNotRealModelProof(): Unit {
        let root=p7EmptyRoot("p7-e2e");let template=p7Template();template.group=CkbAbcdeGroups.D;let gate=orchestrateCkbStrictCertification(root,p7Authority(),template,P7FakeExecutor())
        @Expect(gate.ok,true);@Expect(gate.group,CkbAbcdeGroups.D);@Expect(gate.retryUsed,0);@Expect(gate.hiddenTestExposure,0)
        let evidence=String.fromUtf8(File.readFrom(Path(root).join("results.jsonl")))
        @Expect(evidence.split("\n").size>=164,true)
        @Expect(evidence.contains("realModelProof"),false) // offline fake validates orchestration, never model capability.
        let audit=auditCkbStrictCertificationFromText(evidence,p7Authority());@Expect(audit.contains("\"ok\":true"),true);@Expect(audit.contains("answerHash"),false);@Expect(audit.contains("testHash"),false)
    }

    @TestCase
    public func p7Pos02RealMacOsSandboxAllowsRuntimeAndEnforcesDenyRules(): Unit {
        if (!exists(Path("/usr/bin/sandbox-exec"))) { return }
        let root=p7EmptyRoot("p7-real-sandbox-中文🙂");let workspace="${root}/workspace";let home="${root}/runtime-home";let caseSrc="${root}/authority/CJ-HUMANEVAL-000";let config="${root}/ckb.conf";let store="${root}-store"
        Directory.create(Path(workspace),recursive:true);Directory.create(Path(home),recursive:true);Directory.create(Path(caseSrc).join("tests"),recursive:true);Directory.create(Path(caseSrc).join("translation"),recursive:true)
        let cangjieHome=match(getVariable("CANGJIE_HOME")){case Some(value)=>canonicalize(Path(value)).toString() case None=>""};@Expect(cangjieHome.isEmpty(),false);@Expect(ckbAbcdePrepareBundledArchiverForTest(canonicalize(Path(home)).toString(),cangjieHome),"ok")
        Directory.create(Path(store).join("metadata"),recursive:true);File.writeTo(Path(store).join("metadata/active-snapshot.manifest"),"frozen-pointer".toArray());File.writeTo(Path(config),"network.enabled=false\n".toArray());File.writeTo(Path(caseSrc).join("tests/hidden.txt"),"hidden".toArray());File.writeTo(Path(caseSrc).join("translation/reference.txt"),"reference".toArray())
        let profilePath="${root}/certification.sb";let profile=ckbAbcdeCertificationSandboxProfile(workspace,home,"/usr/bin/true",config,store,caseSrc,"/usr/bin/true","/usr/bin/true");File.writeTo(Path(profilePath),profile.toArray())
        @Expect(profile.contains("(import \"system.sb\")"),true);@Expect(profile.contains("(subpath \"/System\")"),false);@Expect(profile.contains("(subpath \"/usr\")"),false)
        let probe=ckbAbcdeCertificationSandboxProbeForTest(profilePath,workspace,home,caseSrc,ckbStore:store)
        @Expect(probe.exitCode,0);@Expect(probe.stdout.contains("\"ok\":true"),true);@Expect(probe.stdout.contains("\"stdinReadable\":true"),true);@Expect(probe.stdout.contains("\"deniedStore\":true"),true);@Expect(exists(Path(workspace).join(".sandbox-write-probe")),false);@Expect(exists(Path(root).join(".sandbox-outside-probe")),false)
    }
}

private class P7FakeExecutor <: CkbCertificationExecutor {
    public override func execute(caseId:String,workspace:String,sessionId:String,runtimeHome:String):CkbCertificationCaseEvidence{
        let r=CkbCertificationCaseEvidence();r.observedModelVersion="GLM-5.2";r.claudeCodeVersion="claude-code-1.0";r.isolationEvidenceHash=benchmarkGapSha256("deny:${workspace}:${runtimeHome}");r.answerHash=benchmarkGapSha256("answer:${caseId}:中文🙂");r.transcriptHash=benchmarkGapSha256("transcript:${caseId}");r.testHash=benchmarkGapSha256("verifier:${caseId}");r.configHash=benchmarkGapSha256("config");r.artifactHash=benchmarkGapSha256("artifact:${caseId}");r.attemptLineageHash=benchmarkGapSha256("attempt-lineage:${caseId}");r.sampleAttemptCount=1;r.lastAuditedTransportAttempt=1;r.selectedBusinessSample=1;r.llmTurnCount=21;r.sandboxDeniedOutsideWorkspace=true;r.verifierMountedAfterAnswerFreeze=true;r.certificationPassAt1=true;r
    }
}

private func p7Template():CkbCertificationCaseEvidence{let r=CkbCertificationCaseEvidence();r.runId="certification-run";r.group=CkbAbcdeGroups.C;r.datasetVersion=parseCangjieHumanEvalAuthorityManifest(p7Authority()).datasetVersion;r.knowledgeVersion="knowledge-v1";r.modelFingerprint="frozen-fingerprint";r.expectedModelVersion="GLM-5.2";r.observedModelVersion="GLM-5.2";r.claudeCodeVersion="claude-code-1.0";r.providerIdentityHash=benchmarkGapSha256("provider-identity");r.preflightHash=benchmarkGapSha256("preflight");r.runManifestHash=benchmarkGapSha256("manifest");r.authorityCaseHash=benchmarkGapSha256("case");r.authorityTestsHash=benchmarkGapSha256("tests");r}
private func p7Row(i:Int64,group:String):CkbCertificationCaseEvidence{let r=p7Template();r.caseId=if(i<10){"CJ-HUMANEVAL-00${i}"}else if(i<100){"CJ-HUMANEVAL-0${i}"}else{"CJ-HUMANEVAL-${i}"};r.group=group;r.workspaceId=benchmarkGapSha256("workspace-${i}");r.sessionId=benchmarkGapSha256("session-${i}");r.runtimeHomeId=benchmarkGapSha256("home-${i}");r.isolationEvidenceHash=benchmarkGapSha256("deny-${i}");r.answerHash=benchmarkGapSha256("answer-${i}");r.transcriptHash=benchmarkGapSha256("transcript-${i}");r.testHash=benchmarkGapSha256("test-${i}");r.configHash=benchmarkGapSha256("config-${i}");r.artifactHash=benchmarkGapSha256("artifact-${i}");r.attemptLineageHash=benchmarkGapSha256("attempt-lineage-${i}");r.sampleAttemptCount=1;r.lastAuditedTransportAttempt=1;r.selectedBusinessSample=1;r.llmTurnCount=21;r.sandboxDeniedOutsideWorkspace=true;r.verifierMountedAfterAnswerFreeze=true;r.certificationPassAt1=true;sealCkbCertificationEvidence(r);r}
private func p7Rows(n:Int64,group:String):String{let authority=parseCangjieHumanEvalAuthorityManifest(p7Authority());var out="";for(i in 0..n){let row=p7Row(i,group);if(i<authority.rows.size){row.authorityCaseHash=authority.rows[i].caseHash;row.authorityTestsHash=authority.rows[i].testsHash};sealCkbCertificationEvidence(row);out+=renderCkbCertificationEvidenceJson(row)+"\n"};out}
private func p7RowsWithDataset(datasetVersion:String):String{let authority=parseCangjieHumanEvalAuthorityManifest(p7Authority());var out="";for(i in 0..164){let row=p7Row(i,CkbAbcdeGroups.C);row.datasetVersion=datasetVersion;row.authorityCaseHash=authority.rows[i].caseHash;row.authorityTestsHash=authority.rows[i].testsHash;sealCkbCertificationEvidence(row);out+=renderCkbCertificationEvidenceJson(row)+"\n"};out}
private func p7DuplicateRows():String{let authority=parseCangjieHumanEvalAuthorityManifest(p7Authority());var out="";for(i in 0..163){let row=p7Row(i,CkbAbcdeGroups.C);row.authorityCaseHash=authority.rows[i].caseHash;row.authorityTestsHash=authority.rows[i].testsHash;sealCkbCertificationEvidence(row);out+=renderCkbCertificationEvidenceJson(row)+"\n"};let duplicate=p7Row(162,CkbAbcdeGroups.C);duplicate.authorityCaseHash=authority.rows[162].caseHash;duplicate.authorityTestsHash=authority.rows[162].testsHash;sealCkbCertificationEvidence(duplicate);out+=renderCkbCertificationEvidenceJson(duplicate)+"\n";out}
private func p7Authority():String{let cache=Path("../target/p7-authority-cache.jsonl");if(exists(cache)){try{return String.fromUtf8(File.readFrom(cache))}catch(_:Exception){}};let value=cangjieHumanEvalRenderAuthorityManifest(buildCangjieHumanEvalManifest("cangjie_eval/cases/Cangjie-HumanEval",""));File.writeTo(cache,value.toArray());value}
private func p7EmptyRoot(prefix:String):String{let p="../target/${prefix}-${DateTime.now().toUnixTimeStamp().toMilliseconds()}-${benchmarkGapSha256(prefix+DateTime.now().toString()).replace("sha256:","")}";Directory.create(Path(p),recursive:true);p}
private func p7Diagnostics(g:CkbStrictCertificationGateResult):String{var out="";for(v in g.diagnostics){out+=v+"\n"};out}
private func p7ProductionRendererRow(tamper:Bool):String{
    let root=p7EmptyRoot(if(tamper){"p7-render-tamper"}else{"p7-render"});let groupRoot="${root}/group";let workspace="${groupRoot}/workspace";let home="${groupRoot}/runtime-home";let attemptHome="${home}/attempt-1";Directory.create(Path(workspace),recursive:true);Directory.create(Path(attemptHome),recursive:true)
    let options=CkbAbcdeRunnerOptions();options.runId="certification-run";options.runMode="certification";options.datasetVersion=parseCangjieHumanEvalAuthorityManifest(p7Authority()).datasetVersion;options.knowledgeVersion="knowledge-v1";options.modelFingerprint="frozen-fingerprint";options.expectedModelVersion="GLM-5.2";options.providerIdentityHash=benchmarkGapSha256("provider");options.manifestPath="${root}/authority.jsonl";options.certificationPreflightPath="${root}/preflight.json";options.certificationRunManifestPath="${root}/run-manifest.json"
    File.writeTo(Path(options.manifestPath),p7Authority().toArray());File.writeTo(Path(options.certificationPreflightPath),"preflight".toArray());File.writeTo(Path(options.certificationRunManifestPath),"{\"runManifestHash\":\"${benchmarkGapSha256("manifest")}\"}".toArray());File.writeTo(Path("${groupRoot}/session-id.txt"),"session-uuid".toArray());File.writeTo(Path("${groupRoot}/mcp-config.json"),"{}".toArray());File.writeTo(Path("${groupRoot}/runtime-policy.json"),"{\"sampleAttempts\":1,\"internalTurns\":\"audited_not_gated\"}".toArray());File.writeTo(Path("${groupRoot}/claude-attempts.jsonl"),"{\"attempt\":1,\"transportAttempt\":1,\"sampleAttempt\":1,\"exitCode\":0,\"completeResult\":true,\"identityMatched\":true}\n".toArray())
    let answerHash=benchmarkGapSha256("answer中文🙂");let probe="{\"ok\":${!tamper},\"deniedOutsideWorkspace\":true,\"deniedTests\":true,\"deniedReference\":true,\"deniedTeacher\":true,\"deniedStore\":true,\"workspaceCanonical\":\"${canonicalize(Path(workspace)).toString()}\",\"runtimeHomeCanonical\":\"${canonicalize(Path(attemptHome)).toString()}\"}";File.writeTo(Path("${groupRoot}/sandbox-probe.json"),probe.toArray());File.writeTo(Path("${groupRoot}/sandbox-probe.attempt-1.json"),probe.toArray());File.writeTo(Path("${groupRoot}/verifier-mount.json"),"{\"injectExitCode\":0,\"answerHashBefore\":\"${answerHash}\",\"answerHashAfter\":\"${answerHash}\",\"mountedAfterFreeze\":true}".toArray())
    let context="{\"taskId\":\"CJ-HUMANEVAL-000\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"Certification fixture task 中文🙂\",\"signature\":\"public func solve(): Unit\",\"datasetVersion\":\"${options.datasetVersion}\",\"promptHash\":\"sha256:prompt\",\"starterHash\":\"sha256:starter\",\"expectedKnowledgeTags\":[\"Unit\"],\"targetVersion\":\"1.0.0\",\"sourceSet\":\"all\",\"versionPolicy\":\"default\",\"budget\":10,\"responseMode\":\"evidence\"}"
    File.writeTo(Path("${groupRoot}/canonical-task-context.json"),context.toArray())
    File.writeTo(Path("${groupRoot}/runtime-policy.json"),"{\"model\":\"GLM-5.2\",\"modelTimeoutSeconds\":180,\"sampleAttempts\":1}".toArray())
    File.writeTo(Path("${groupRoot}/paired-tool-evidence.json"),"{}".toArray())
    let toolUse="{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":\"call-cert\",\"name\":\"mcp__ckb-cangjie-http__cangjie_task_knowledge_pack\",\"input\":{}}]}}"
    let contextHash=benchmarkGapSha256(context)
    let emptyInputHash=benchmarkGapSha256("{}")
    let toolResult="{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"call-cert\",\"content\":\"{\\\"taskId\\\":\\\"CJ-HUMANEVAL-000\\\",\\\"resultType\\\":\\\"task_knowledge_pack\\\",\\\"evidenceHash\\\":\\\"h-p7-production\\\",\\\"knowledgeVersion\\\":\\\"knowledge-v1\\\",\\\"coverage\\\":{\\\"coveragePass\\\":true},\\\"citations\\\":[{\\\"citation\\\":\\\"official\\\"}],\\\"requestBinding\\\":{\\\"schemaVersion\\\":\\\"ckb-runner-bound-mcp-v1\\\",\\\"bindingMode\\\":\\\"runner_immutable\\\",\\\"requestHash\\\":\\\"${contextHash}\\\",\\\"effectiveRequestHash\\\":\\\"${contextHash}\\\",\\\"modelArgumentsHash\\\":\\\"${emptyInputHash}\\\",\\\"taskId\\\":\\\"CJ-HUMANEVAL-000\\\"}}\"}]}}"
    let transcript="{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"GLM-5.2\"}\n${toolUse}\n${toolResult}\n{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false,\"num_turns\":21,\"usage\":{\"input_tokens\":1,\"output_tokens\":1,\"cache_read_input_tokens\":0,\"cache_creation_input_tokens\":0}}\n"
    let session="session-uuid";let diagnostic="{}\n";File.writeTo(Path("${groupRoot}/session-id.attempt-1.txt"),session.toArray());File.writeTo(Path("${groupRoot}/session-id.txt"),session.toArray());File.writeTo(Path("${groupRoot}/claude-transcript.attempt-1.jsonl"),transcript.toArray());File.writeTo(Path("${groupRoot}/claude-transcript.jsonl"),transcript.toArray());File.writeTo(Path("${groupRoot}/claude.attempt-1.stderr.log"),"".toArray());File.writeTo(Path("${groupRoot}/model-transport-diagnostic.attempt-1.json"),diagnostic.toArray());File.writeTo(Path("${groupRoot}/workspace-restores.jsonl"),"".toArray())
    let attempt="{\"attempt\":1,\"transportAttempt\":1,\"modelTimeoutSeconds\":180,\"sampleAttempt\":1,\"exitCode\":0,\"classification\":\"business_sample\",\"completeResult\":true,\"identityMatched\":true,\"workspaceRestored\":false,\"restoreEvidenceHash\":\"\",\"sessionIdHash\":\"${benchmarkGapSha256(session)}\",\"runtimeHomeId\":\"${benchmarkGapSha256(canonicalize(Path(attemptHome)).toString())}\",\"sandboxProbeHash\":\"${benchmarkGapSha256(probe)}\",\"transcriptHash\":\"${benchmarkGapSha256(transcript)}\",\"stderrHash\":\"${benchmarkGapSha256("")}\",\"diagnosticHash\":\"${benchmarkGapSha256(diagnostic)}\"}\n";File.writeTo(Path("${groupRoot}/claude-attempts.jsonl"),attempt.toArray());let summary="{\"transportAttemptCount\":1,\"sampleAttemptCount\":1,\"lastAuditedTransportAttempt\":1,\"selectedBusinessSample\":1,\"selectedTransportAttempt\":1,\"retryCount\":0,\"unresolvedTransport\":0,\"attemptLineageHash\":\"${ckbAbcdeAttemptLineageHash(attempt,"")}\",\"workspaceRestoreEvidenceHash\":\"${benchmarkGapSha256("")}\"}";File.writeTo(Path("${groupRoot}/attempt-evidence.json"),summary.toArray());File.writeTo(Path("${groupRoot}/test-result.json"),summary.toArray())
    ckbAbcdeRenderStrictCertificationCaseForTest(options,"CJ-HUMANEVAL-000",CkbAbcdeGroups.D,groupRoot,answerHash,transcript,"tests passed",true,"none",true)
}

private func p7RowsWithDatasetD(datasetVersion:String):String {
    let authority=parseCangjieHumanEvalAuthorityManifest(p7Authority());var out=""
    for(i in 0..164){let row=p7Row(i,CkbAbcdeGroups.D);row.datasetVersion=datasetVersion;row.authorityCaseHash=authority.rows[i].caseHash;row.authorityTestsHash=authority.rows[i].testsHash;sealCkbCertificationEvidence(row);out+=renderCkbCertificationEvidenceJson(row)+"\n"}
    out
}

private func p7DuplicateRowsD():String {
    let authority=parseCangjieHumanEvalAuthorityManifest(p7Authority());var out=""
    for(i in 0..163){let row=p7Row(i,CkbAbcdeGroups.D);row.authorityCaseHash=authority.rows[i].caseHash;row.authorityTestsHash=authority.rows[i].testsHash;sealCkbCertificationEvidence(row);out+=renderCkbCertificationEvidenceJson(row)+"\n"}
    let duplicate=p7Row(162,CkbAbcdeGroups.D);duplicate.authorityCaseHash=authority.rows[162].caseHash;duplicate.authorityTestsHash=authority.rows[162].testsHash;sealCkbCertificationEvidence(duplicate);out+=renderCkbCertificationEvidenceJson(duplicate)+"\n";out
}
