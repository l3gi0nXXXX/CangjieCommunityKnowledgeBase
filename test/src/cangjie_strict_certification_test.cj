package cangjie_community_knowledge_base_test

import std.collection.ArrayList
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
        let options=CkbAbcdeRunnerOptions();options.explicitRunMode=true;options.runMode="certification";options.datasetVersion="dataset-v1";options.knowledgeVersion="knowledge-v1";options.modelFingerprint="frozen";options.claudeBin="/usr/bin/true";options.ckbConfig=config;options.groups.clear();options.groups.add(CkbAbcdeGroups.D);options.manifestPath=Path(configRoot).join("missing-authority.jsonl").toString();@Expect(ckbAbcdeDevelopmentOptionsDiagnostic(options),"certification_requires_authority_manifest")
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

    @TestCase
    public func p1Ut00ThresholdOnlyTextGateRemainsFailedScore(): Unit {
        let gate = ckbStrictCertificationGate(p1M00Rows(151), p1M00Authority())
        @Expect(gate.ok, false)
        @Expect(gate.total, 164)
        @Expect(gate.unitPass, 151)
        @Expect(gate.unitPassAt1, 151)
        @Expect(gate.failed, 13)
        @Expect(gate.invalid, 0)
        @Expect(gate.retryUsed, 0)
        @Expect(gate.fallbackUsed, 0)
        @Expect(gate.unresolvedTransport, 0)
        @Expect(gate.diagnostics.size, 1)
        @Expect(gate.diagnostics[0], "strict_pass_at_1_requirements_not_met")
        @Expect(gate.artifactManifestHash, "")
    }

    @TestCase
    public func p1Pos00ThresholdOnlyPrivateRunCompletesArtifactAudit(): Unit {
        let fixture = p1M00PrivateRun(151, "pos")
        let first = ckbStrictCertificationGateFromRunRoot(fixture.root, fixture.authority)
        let second = ckbStrictCertificationGateFromRunRoot(fixture.root, fixture.authority)
        @Expect(first.ok, false)
        @Expect(first.total, 164)
        @Expect(first.unitPassAt1, 151)
        @Expect(first.failed, 13)
        @Expect(first.invalid, 0)
        @Expect(first.diagnostics.size, 1)
        @Expect(first.diagnostics[0], "strict_pass_at_1_requirements_not_met")
        @Expect(p1M00Hash(first.artifactManifestHash), true)
        @Expect(second.artifactManifestHash, first.artifactManifestHash)
    }

    @TestCase
    public func p1Neg00ThresholdExceptionNeverBypassesArtifactMismatch(): Unit {
        let fixture = p1M00PrivateRun(151, "neg-tamper")
        let firstCase = Path(fixture.root).join("cases").join("CJ-HUMANEVAL-000").join(CkbAbcdeGroups.D)
        File.writeTo(firstCase.join("test.log"), "tampered".toArray())
        let tampered = ckbStrictCertificationGateFromRunRoot(fixture.root, fixture.authority)
        @Expect(tampered.ok, false)
        @Expect(tampered.artifactManifestHash, "")
        @Expect(tampered.diagnostics.size, 1)
        @Expect(tampered.diagnostics[0], "case_semantic_artifact_mismatch:CJ-HUMANEVAL-000")

        let structural = p1M00PrivateRun(151, "neg-structural")
        let resultsPath = Path(structural.root).join("results.jsonl")
        let lines = String.fromUtf8(File.readFrom(resultsPath)).split("\n")
        let shortened = StringBuilder()
        for (i in 0..163) { shortened.append(lines[i]); shortened.append("\n") }
        File.writeTo(resultsPath, shortened.toString().toArray())
        let invalid = ckbStrictCertificationGateFromRunRoot(structural.root, structural.authority)
        @Expect(invalid.ok, false)
        @Expect(invalid.artifactManifestHash, "")
        @Expect(p7Diagnostics(invalid).contains("result_count_mismatch:163:164"), true)
        @Expect(p7Diagnostics(invalid).contains("missing_case:CJ-HUMANEVAL-163"), true)
        @Expect(p7Diagnostics(invalid).contains("strict_pass_at_1_requirements_not_met"), true)
    }

    @TestCase
    public func p1Reg00Full164PrivateCertificationAndReleaseGateRemainStrict(): Unit {
        let complete = p1M00PrivateRun(164, "reg-full")
        let first = ckbStrictCertificationGateFromRunRoot(complete.root, complete.authority)
        let second = ckbStrictCertificationGateFromRunRoot(complete.root, complete.authority)
        @Expect(first.ok, true)
        @Expect(first.total, 164)
        @Expect(first.unitPassAt1, 164)
        @Expect(first.failed, 0)
        @Expect(first.invalid, 0)
        @Expect(first.diagnostics.size, 0)
        @Expect(p1M00Hash(first.artifactManifestHash), true)
        @Expect(second.artifactManifestHash, first.artifactManifestHash)

        let belowThreshold = p1M00PrivateRun(151, "reg-below")
        let score = ckbStrictCertificationGateFromRunRoot(belowThreshold.root, belowThreshold.authority)
        @Expect(score.ok, false)
        @Expect(score.unitPassAt1, 151)
    }

}

@Test
public class CkbP4IntegratedCertificationTest {
    @TestCase
    public func p4Ut01ExistingScorePipelineNamesBasePlusByLineage(): Unit {
        let fixture=p4CompletionRun("ut-score","none");let projected=projectCkbPublicEvidenceFromRunFiles(canonicalize(Path(fixture.root)).toString(),p4Reference(fixture),bindReferenceOutcome:false)
        @Expect(projected.ok,true);@Expect(projected.score.basePassed,164);@Expect(projected.score.plusPassed,164)
        @Expect(projected.score.baseMetricName,"strict_ckb_skill_base_pass_at_1");@Expect(projected.score.plusMetricName,"strict_ckb_skill_plus_pass_at_1")
        @Expect(projected.score.certificationStatus,"passed")
    }
    
    @TestCase
    public func p4Bnd01ExistingPass1GateRejectsCountsAndTreatsPostTokenAsFailure(): Unit {
        let fixture=p4CompletionRun("bnd-post-token","post_token_failure");let options=p4Pass1Options(fixture)
        let gate=cangjieHumanEvalPass1GateFromFiles(options)
        @Expect(gate.ok,true);@Expect(gate.groups[0].total,164);@Expect(gate.groups[0].passAt1,163);@Expect(gate.basePassed,163);@Expect(gate.plusPassed,163);@Expect(gate.remainingGaps.size>0,true)
        let lines=String.fromUtf8(File.readFrom(Path(fixture.root).join("results.jsonl"))).split("\n");let short=StringBuilder();for(i in 0..163){short.append(lines[i]);short.append("\n")}
        let countGate=cangjieHumanEvalPass1GateFromText(short.toString(),fixture.authority,options,fixture.root,"authority.jsonl")
        @Expect(p7DiagnosticsText(countGate.diagnostics).contains("group_total_mismatch"),true)
        let recovered=p4CompletionRun("bnd-zero-recovered","zero_token_recovered");@Expect(cangjieHumanEvalPass1GateFromFiles(p4Pass1Options(recovered)).ok,true)
        let unrecovered=p4CompletionRun("bnd-zero-unrecovered","zero_token_unrecovered");let unrecoveredGate=cangjieHumanEvalPass1GateFromFiles(p4Pass1Options(unrecovered));@Expect(unrecoveredGate.ok,false);@Expect(p7DiagnosticsText(unrecoveredGate.diagnostics).contains("zero_token_recovery_evidence_required"),true)
        let public163=projectCkbPublicEvidenceFromRunFiles(canonicalize(Path(fixture.root)).toString(),p4Reference(fixture),bindReferenceOutcome:false);@Expect(public163.ok,true);@Expect(public163.score.strictPassed,163);@Expect(public163.score.businessFailed,1);@Expect(public163.text.contains("\"classification\":\"business_failure\""),true)
    }
    
    @TestCase
    public func p4Pos01Real164RunPassesCertificationPass1ScoreAndPublicExport(): Unit {
        let fixture=p4CompletionRun("pos","none")
        let strict=ckbStrictCertificationGateFromRunRoot(fixture.root,fixture.authority)
        @Expect(strict.ok,true)
        @Expect(cangjieHumanEvalPass1GateFromFiles(p4Pass1Options(fixture)).ok,true)
        let runbook=parseCangjieHumanEvalPass1GateOptions(["--run-root",fixture.root,"--protocol","completion-only-v1"]);runbook.manifestPath=Path(fixture.root).join("authority.jsonl").toString();let runbookResult=cangjieHumanEvalPass1GateFromFiles(runbook);let human=renderCangjieHumanEvalPass1GateMarkdown(runbookResult)
        let machine=renderCangjieHumanEvalPass1GateJson(runbookResult);@Expect(runbookResult.ok,true);@Expect(runbook.groups.size,1);@Expect(runbook.groups[0],CkbAbcdeGroups.D);@Expect(human.contains("strict_ckb_skill_base_pass_at_1=164/164"),true);@Expect(human.contains("certification_status=passed"),true);@Expect(machine.contains("\"baseMetricName\":\"strict_ckb_skill_base_pass_at_1\""),true);@Expect(machine.contains("\"assetLineage\":\"independent\""),true)
        let derived=p4CompletionRun("pos-derived","derived");let derivedOptions=parseCangjieHumanEvalPass1GateOptions(["--run-root",derived.root,"--protocol","completion-only-v1"]);derivedOptions.manifestPath=Path(derived.root).join("authority.jsonl").toString();let derivedHuman=renderCangjieHumanEvalPass1GateMarkdown(cangjieHumanEvalPass1GateFromFiles(derivedOptions));@Expect(derivedHuman.contains("closed_loop_ckb_skill_base_pass_at_1=164/164"),true)
        let reference=p4Reference(fixture);let projected=projectCkbPublicEvidenceFromRunFiles(canonicalize(Path(fixture.root)).toString(),reference,bindReferenceOutcome:false)
        @Expect(projected.ok,true);@Expect(projected.score.strictPassed,164);@Expect(projected.text.contains("\"generationProtocol\":\"completion-only-v1\""),true)
    }
    
    @TestCase
    public func p4Neg01RealRunArtifactsRejectToolsSecondAnswerEarlyExecutionAndBundleDrift(): Unit {
        for(mutation in ["tool_use","second_answer","early_execution","bundle_drift"]){
            let fixture=p4CompletionRun("neg-${mutation}",mutation);let gate=ckbStrictCertificationGateFromRunRoot(fixture.root,fixture.authority)
            let expected=if(mutation=="tool_use"){"completion_tool_use_forbidden"}else if(mutation=="second_answer"){"completion_not_unique"}else if(mutation=="early_execution"){"execution_before_answer_freeze"}else{"completion_bundle_or_lineage_drift"}
            @Expect(gate.ok,false);@Expect(p7Diagnostics(gate).contains(expected),true)
        }
        let provenance=p4CompletionRun("neg-provenance","none");let provenancePath=Path(provenance.root).join("runner-provenance.json");let provenanceText=String.fromUtf8(File.readFrom(provenancePath));File.writeTo(provenancePath,provenanceText.replace("\"caseCount\":164","\"caseCount\":163").toArray())
        let pass1=cangjieHumanEvalPass1GateFromFiles(p4Pass1Options(provenance));@Expect(pass1.ok,false);@Expect(p7DiagnosticsText(pass1.diagnostics).contains("run_manifest_artifact_binding_mismatch"),true)
        let artifacts=p4CompletionRun("neg-completion-seed","none");let caseRoot=Path(artifacts.root).join("cases/CJ-HUMANEVAL-000").join(CkbAbcdeGroups.D);let initial=ckbStrictCertificationGateFromRunRoot(artifacts.root,artifacts.authority);@Expect(initial.ok,true);@Expect(initial.artifactManifestHash!="",true)
        for(name in ["frozen-completion/solution.cj","generation-evidence.json","answer-freeze.json","base-test-result.json","plus-test-result.json"]){let path=caseRoot.join(name);let original=File.readFrom(path);File.writeTo(path,(String.fromUtf8(original)+" ").toArray());let tampered=ckbStrictCertificationGateFromRunRoot(artifacts.root,artifacts.authority);@Expect(!tampered.ok||tampered.artifactManifestHash!=initial.artifactManifestHash,true);File.writeTo(path,original)}
        let v4Legacy=p4CompletionRun("neg-v4-legacy-manifest","none");let v4Manifest=Path(v4Legacy.root).join("run-manifest.json");File.writeTo(v4Manifest,String.fromUtf8(File.readFrom(v4Manifest)).replace("\"generationProtocol\":\"completion-only-v1\"","\"legacyProtocol\":\"completion-only-v1\"").toArray());@Expect(p7Diagnostics(ckbStrictCertificationGateFromRunRoot(v4Legacy.root,v4Legacy.authority)).contains("case_run_protocol_mismatch"),true)
        let v3Completion=p1M00PrivateRun(164,"p4-neg-v3-completion-manifest");let v3Manifest=Path(v3Completion.root).join("run-manifest.json");let bundle=benchmarkGapSha256("student-bundle");File.writeTo(v3Manifest,String.fromUtf8(File.readFrom(v3Manifest)).replace("}",",\"generationProtocol\":\"completion-only-v1\",\"samplingCapability\":\"temperature_zero\",\"skillBundleVersion\":\"student-v1\",\"skillBundleHash\":\"${bundle}\",\"assetLineage\":\"independent\"}").toArray());@Expect(p7Diagnostics(ckbStrictCertificationGateFromRunRoot(v3Completion.root,v3Completion.authority)).contains("student_validation_identity_invalid"),true)
    }

    @TestCase
    public func s4Reg01CertificationResultV5BindsRulesAtRunRoot(): Unit {
        let valid=p4CompletionRunV5("s4-v5-valid",false);let validRow=parseCkbCertificationEvidence(String.fromUtf8(File.readFrom(Path(valid.root).join("results.jsonl"))).split("\n")[0])
        @Expect(validRow.valid,true);@Expect(ckbStrictCompletionCaseFromRunRootDiagnostic(valid.root,validRow),"ok");@Expect(ckbStrictCertificationGateFromRunRoot(valid.root,valid.authority).ok,true);@Expect(cangjieHumanEvalPass1GateFromFiles(p4Pass1Options(valid)).ok,true)
        let audit="{\"runMode\":\"certification\",\"caseId\":\"${validRow.caseId}\",\"group\":\"${validRow.group}\",\"unitPassAt1\":true,\"protocolViolation\":false,\"firstClaudeExitCode\":0,\"claudeExitCode\":0,\"testExitCode\":0,\"failureType\":\"none\",\"datasetVersion\":\"${validRow.datasetVersion}\",\"lineageKnowledgeVersion\":\"${validRow.knowledgeVersion}\",\"developmentPass\":false,\"closureStatus\":\"closed\",\"triageStatus\":\"complete\",\"failureRoute\":\"none\",\"certificationPassAt1\":null}"
        let projected=projectCkbPublicEvidenceRow(renderCkbCertificationEvidenceJson(validRow).toArray(),audit.toArray());@Expect(projected.ok,true);@Expect(projected.row.schemaVersion,"ckb-humaneval-public-evidence-v3");@Expect(projected.row.rulesHash,validRow.rulesHash);@Expect(projected.row.rulesTreeHash,validRow.rulesTreeHash);@Expect(projected.row.rulesCount,validRow.rulesCount)
        let drift=p4CompletionRunV5("s4-v5-rules-drift",true);let driftRow=parseCkbCertificationEvidence(String.fromUtf8(File.readFrom(Path(drift.root).join("results.jsonl"))).split("\n")[0])
        @Expect(driftRow.valid,true);@Expect(ckbStrictCompletionCaseFromRunRootDiagnostic(drift.root,driftRow),"run_manifest_rules_binding_mismatch")
        let blocked=ckbStrictCertificationGateFromRunRoot(drift.root,drift.authority);@Expect(blocked.ok,false);@Expect(p7Diagnostics(blocked).contains("run_manifest_rules_binding_mismatch"),true);let releaseBlocked=cangjieHumanEvalPass1GateFromFiles(p4Pass1Options(drift));@Expect(releaseBlocked.ok,false);@Expect(p7DiagnosticsText(releaseBlocked.diagnostics).contains("run_manifest_rules_binding_mismatch"),true)
    }
    
    @TestCase
    public func p4Pub01ExistingExportRejectsPrivateHiddenSecretWrongLineageAndInvalidUtf8(): Unit {
        let fixture=p4CompletionRun("pub","none");let reference=p4Reference(fixture)
        @Expect(projectCkbPublicEvidenceFromRunFiles(canonicalize(Path(fixture.root)).toString(),reference,bindReferenceOutcome:false).ok,true)
        let caseRoot=Path(fixture.root).join("cases/CJ-HUMANEVAL-000").join(CkbAbcdeGroups.D)
        File.writeTo(caseRoot.join("audit.json"),"{\"token\":\"secret\",\"hiddenTest\":\"/Users/private/x\"}".toArray())
        @Expect(projectCkbPublicEvidenceFromRunFiles(canonicalize(Path(fixture.root)).toString(),reference,bindReferenceOutcome:false).ok,false)
        File.writeTo(caseRoot.join("audit.json"),[UInt8(0xff),UInt8(0xfe)])
        @Expect(projectCkbPublicEvidenceFromRunFiles(canonicalize(Path(fixture.root)).toString(),reference,bindReferenceOutcome:false).ok,false)
        let drift=p4CompletionRun("pub-lineage","wrong_lineage")
        @Expect(projectCkbPublicEvidenceFromRunFiles(canonicalize(Path(drift.root)).toString(),p4Reference(drift),bindReferenceOutcome:false).ok,false)
        let provenance=p4CompletionRun("pub-provenance","none");let provenancePath=Path(provenance.root).join("runner-provenance.json");let provenanceText=String.fromUtf8(File.readFrom(provenancePath));File.writeTo(provenancePath,provenanceText.replace("\"caseCount\":164","\"caseCount\":163").toArray())
        @Expect(projectCkbPublicEvidenceFromRunFiles(canonicalize(Path(provenance.root)).toString(),p4Reference(provenance),bindReferenceOutcome:false).ok,false)
        let authority=p4CompletionRun("pub-authority","none");let authorityPath=Path(authority.root).join("authority.jsonl");File.writeTo(authorityPath,(String.fromUtf8(File.readFrom(authorityPath))+" ").toArray())
        @Expect(projectCkbPublicEvidenceFromRunFiles(canonicalize(Path(authority.root)).toString(),p4Reference(authority),bindReferenceOutcome:false).ok,false)
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

private class P1M00PrivateRunFixture {
    public let root: String
    public let authority: String
    public init(root: String, authority: String) {
        this.root = root
        this.authority = authority
    }
}

private class P4StudentValidationAssets {
    public let providerText: String
    public let providerHash: String
    public let manifestFields: String
    public init(providerText: String, providerHash: String, manifestFields: String) {
        this.providerText = providerText
        this.providerHash = providerHash
        this.manifestFields = manifestFields
    }
}

private func p4FreezeStudentValidationAssets(rootValue: String, model: String,
    claudeVersion: String): P4StudentValidationAssets {
    let root = canonicalize(Path(rootValue)); let source = root.join("p4-student-validation-source")
    Directory.create(source, recursive: true)
    let runtime = canonicalize(Path("/bin/echo")).toString()
    let runtimeEvidence = "{\"runtime\":\"p4 frozen completion fixture\"}\n"
    let sampling = "{\"schemaVersion\":\"ckb-completion-sampling-capability-v1\"," +
        "\"samplingControl\":\"provider_default_not_client_exposed\"}\n"
    let capability = "{\"schemaVersion\":\"ckb-provider-prompt-capability-v1\"," +
        "\"capability\":\"p4 strict completion fixture\"}\n"
    let outputSchemaHash = benchmarkGapSha256(ckbAbcdeCompletionOutputSchema())
    let samplingHash = benchmarkGapSha256(sampling)
    let completion = "{\"schemaVersion\":\"ckb-student-completion-control-v1\"," +
        "\"certificationTransport\":\"${CkbAbcdeGroups.D}\"," +
        "\"generationProtocol\":\"completion-only-v1\",\"samplesPerCase\":1," +
        "\"outputSchemaHash\":\"${outputSchemaHash}\"," +
        "\"samplingCapabilityHash\":\"${samplingHash}\"," +
        "\"effectivePromptByteBudget\":188416,\"transportRetryBudget\":0," +
        "\"modelTimeoutSeconds\":180," +
        "\"runtimeConfigHash\":\"${benchmarkGapSha256(runtimeEvidence)}\"," +
        "\"completionCommandHash\":\"${ckbStudentCompletionCommandHash(model)}\"}\n"
    let completionHash = benchmarkGapSha256(completion)
    let capabilityHash = benchmarkGapSha256(capability)
    let provider = "{\"schemaVersion\":\"ckb-student-validation-provider-identity-v1\"," +
        "\"provider\":\"p4-strict-fixture\",\"model\":\"${model}\"," +
        "\"claudeCodeVersion\":\"${claudeVersion}\"," +
        "\"runtimeExecutableHash\":\"${ckbAbcdeBinaryHash(runtime)}\"," +
        "\"completionControlHash\":\"${completionHash}\"," +
        "\"providerPromptCapabilityHash\":\"${capabilityHash}\"}\n"
    let providerHash = benchmarkGapSha256(provider)
    let context = s4PublishedStudentValidatedContext("p4-${benchmarkGapSha256(root.toString())}",
        providerHash, model)
    let bundle = readStudentContextBundleV2(context.contextRoot)
    if (!bundle.ok) { throw IllegalStateException("p4_student_context_fixture_invalid") }
    let capabilitySource = source.join("provider-prompt-capability.json")
    let completionSource = source.join("completion-control.json")
    File.writeTo(capabilitySource, capability.toArray()); File.writeTo(completionSource, completion.toArray())
    let options = CkbAbcdeRunnerOptions()
    options.studentContextRoot = context.contextRoot
    options.studentContextCompositeHash = bundle.compositeHash
    options.combinationAuditHash = bundle.combinationAuditHash
    options.providerPromptCapabilityPath = capabilitySource.toString()
    options.providerPromptCapabilityHash = capabilityHash
    options.studentContextCandidateRoot = context.candidateRoot
    options.studentContextCandidateSetHash = context.candidateSetHash
    options.completionControlPath = completionSource.toString()
    options.completionControlHash = completionHash
    if (ckbAbcdeFreezeS4RunAssets(options, root.toString(), false) != "ok") {
        throw IllegalStateException("p4_student_context_freeze_failed")
    }
    File.writeTo(root.join("completion-runtime-config.json"), runtimeEvidence.toArray())
    File.writeTo(root.join("completion-sampling-capability.json"), sampling.toArray())
    File.writeTo(root.join("provider-identity.json"), provider.toArray())
    let fields = "\"studentContextRoot\":\"${root.join("student-context")}\"," +
        "\"studentContextManifestHash\":\"${benchmarkGapSha256(bundle.manifestJson)}\"," +
        "\"studentContextCompositeHash\":\"${bundle.compositeHash}\"," +
        "\"combinationAuditHash\":\"${bundle.combinationAuditHash}\"," +
        "\"aggregateAssetLineage\":\"independent\"," +
        "\"studentContextCandidateRoot\":\"${root.join("student-context-candidate")}\"," +
        "\"studentContextCandidateSetHash\":\"${context.candidateSetHash}\"," +
        "\"completionControlPath\":\"${root.join("completion-control.json")}\"," +
        "\"completionControlHash\":\"${completionHash}\"," +
        "\"providerPromptCapabilityPath\":\"${root.join("provider-prompt-capability.json")}\"," +
        "\"providerPromptCapabilityHash\":\"${capabilityHash}\"," +
        "\"providerIdentityPath\":\"${root.join("provider-identity.json")}\"," +
        "\"providerRuntimeExecutablePath\":\"${runtime}\"," +
        "\"samplingCapabilityHash\":\"${samplingHash}\"," +
        "\"certificationTransport\":\"${CkbAbcdeGroups.D}\",\"samplesPerCase\":1," +
        "\"outputSchemaHash\":\"${outputSchemaHash}\",\"effectivePromptByteBudget\":188416," +
        "\"transportRetryBudget\":0"
    P4StudentValidationAssets(provider, providerHash, fields)
}

private func p1M00Rows(strictPassed: Int64): String {
    let authority = parseCangjieHumanEvalAuthorityManifest(p1M00Authority())
    let out = StringBuilder()
    for (i in 0..164) {
        let row = p7Row(i, CkbAbcdeGroups.D)
        row.authorityCaseHash = authority.rows[i].caseHash
        row.authorityTestsHash = authority.rows[i].testsHash
        row.certificationPassAt1 = i < strictPassed
        sealCkbCertificationEvidence(row)
        out.append(renderCkbCertificationEvidenceJson(row))
        out.append("\n")
    }
    out.toString()
}

private func p1M00PrivateRun(strictPassed: Int64, label: String): P1M00PrivateRunFixture {
    let root = p7EmptyRoot("p1-m00-${label}-${strictPassed}")
    let authorityText = p1M00Authority()
    let authority = parseCangjieHumanEvalAuthorityManifest(authorityText)
    let runId = "p1-m00-private-run"
    let knowledgeVersion = "knowledge-v1"
    let fingerprint = benchmarkGapSha256("frozen-input-fingerprint")
    let model = "GLM-5.2"
    let claudeBin = "/bin/echo"
    let claudeVersion = ckbAbcdeClaudeVersionForTest(executable: claudeBin)
    let preflight = "p1-m00-preflight"
    let pointerHash = benchmarkGapSha256("p1-m00-pointer")
    let candidateChecksum = benchmarkGapSha256("p1-m00-candidate")
    let frozen = "{\"knowledgeVersion\":\"${knowledgeVersion}\",\"activePointerHash\":\"${pointerHash}\",\"candidateChecksum\":\"${candidateChecksum}\"}"
    let provider = "{\"provider\":\"fake-transport\",\"model\":\"${model}\",\"claudeCodeVersion\":\"${claudeVersion}\"}"
    let providerHash = benchmarkGapSha256(provider)
    let runManifestHash = benchmarkGapSha256("p1-m00-run-manifest")
    let binaryHash = benchmarkGapSha256("p1-m00-binary")
    let launchHash = benchmarkGapSha256("p1-m00-launch")
    let commandHash = benchmarkGapSha256("p1-m00-command")
    let runManifest = "{\"frozenCandidateManifestHash\":\"${benchmarkGapSha256(frozen)}\",\"providerIdentityHash\":\"${providerHash}\",\"modelVersion\":\"${model}\",\"fingerprint\":\"${fingerprint}\",\"preflightHash\":\"${benchmarkGapSha256(preflight)}\",\"runManifestHash\":\"${runManifestHash}\",\"modelTimeoutSeconds\":180,\"claudeCodeVersion\":\"${claudeVersion}\",\"runId\":\"${runId}\",\"certificationBinaryHash\":\"${binaryHash}\",\"certificationHttpLaunchSpecHash\":\"${launchHash}\",\"certificationHttpCommandHash\":\"${commandHash}\"}"
    let owner = "{\"schemaVersion\":\"ckb-certification-http-owner-v1\",\"pid\":4242,\"binaryHash\":\"${binaryHash}\",\"launchSpecHash\":\"${launchHash}\",\"commandHash\":\"${commandHash}\"}"
    let stopped = "{\"schemaVersion\":\"ckb-certification-http-stop-v1\",\"pid\":4242,\"stopMethod\":\"term\",\"aliveAfterStop\":false}"
    let identity = "{\"ok\":true,\"apiVersion\":\"v1\",\"data\":{\"schemaVersion\":\"ckb-certification-identity-v1\",\"activeVersion\":\"${knowledgeVersion}\",\"pointerIdentityHash\":\"${pointerHash}\",\"candidateChecksum\":\"${candidateChecksum}\"},\"diagnostics\":{}}"
    let rootPath = Path(root)
    File.writeTo(rootPath.join("authority.jsonl"), authorityText.toArray())
    File.writeTo(rootPath.join("preflight.json"), preflight.toArray())
    File.writeTo(rootPath.join("run-manifest.json"), runManifest.toArray())
    File.writeTo(rootPath.join("frozen-candidate-manifest.json"), frozen.toArray())
    File.writeTo(rootPath.join("provider-identity.json"), provider.toArray())
    File.writeTo(rootPath.join("certification-http-owner.json"), owner.toArray())
    File.writeTo(rootPath.join("certification-http-stopped.json"), stopped.toArray())
    File.writeTo(rootPath.join("certification-http-identity.json"), identity.toArray())

    let options = CkbAbcdeRunnerOptions()
    options.runId = runId
    options.explicitRunMode = true
    options.runMode = "certification"
    options.datasetVersion = authority.datasetVersion
    options.knowledgeVersion = knowledgeVersion
    // The environment model identity is distinct from the P6 frozen-input fingerprint.
    options.modelFingerprint = "claude-code-glm-5.2"
    options.expectedModelVersion = model
    options.claudeBin = claudeBin
    options.providerIdentityHash = providerHash
    options.modelTimeoutSeconds = 180
    options.manifestPath = rootPath.join("authority.jsonl").toString()
    options.certificationPreflightPath = rootPath.join("preflight.json").toString()
    options.certificationRunManifestPath = rootPath.join("run-manifest.json").toString()
    options.providerIdentityArtifactPath = rootPath.join("provider-identity.json").toString()
    options.frozenCandidateManifestPath = rootPath.join("frozen-candidate-manifest.json").toString()

    let results = StringBuilder()
    for (i in 0..164) {
        let authorityRow = authority.rows[i]
        let groupRoot = rootPath.join("cases").join(authorityRow.caseId).join(CkbAbcdeGroups.D)
        var rendered = ckbAbcdeWriteSuccessfulFakeTransportCaseForTest(
            options, authorityRow.caseId, groupRoot.toString())
        if (i >= strictPassed) {
            let row = parseCkbCertificationEvidence(rendered)
            row.certificationPassAt1 = false
            sealCkbCertificationEvidence(row)
            rendered = renderCkbCertificationEvidenceJson(row)
            let testResultPath = groupRoot.join("test-result.json")
            let testResult = String.fromUtf8(File.readFrom(testResultPath))
                .replace("\"testExitCode\":0", "\"testExitCode\":1")
                .replace("\"unitPassAt1\":true", "\"unitPassAt1\":false")
                .replace("\"failureType\":\"none\"", "\"failureType\":\"unit_failure\"")
            File.writeTo(testResultPath, testResult.toArray())
            File.writeTo(groupRoot.join("result-evidence.json"), rendered.toArray())
        }
        results.append(rendered)
        results.append("\n")
    }
    let resultsText = results.toString()
    File.writeTo(rootPath.join("results.jsonl"), resultsText.toArray())
    let provenance = "{\"schemaVersion\":\"ckb-certification-runner-provenance-v1\",\"runId\":\"${runId}\",\"canonicalRunRootHash\":\"${benchmarkGapSha256(canonicalize(rootPath).toString())}\",\"runManifestHash\":\"${runManifestHash}\",\"runnerBinaryHash\":\"${binaryHash}\",\"launchSpecHash\":\"${launchHash}\",\"commandHash\":\"${commandHash}\",\"authorityHash\":\"${benchmarkGapSha256(authorityText)}\",\"caseCount\":164,\"resultManifestHash\":\"${benchmarkGapSha256(resultsText)}\"}"
    File.writeTo(rootPath.join("runner-provenance.json"), provenance.toArray())
    P1M00PrivateRunFixture(root, authorityText)
}

private func p1M00Authority(): String {
    cangjieHumanEvalRenderAuthorityManifest(
        buildCangjieHumanEvalManifest("cangjie_eval/cases/Cangjie-HumanEval", ""))
}

private func p1M00Hash(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 71 || !value.startsWith("sha256:")) { return false }
    for (i in 7..71) {
        let rune = runes[i]
        if (!((rune >= r'0' && rune <= r'9') || (rune >= r'a' && rune <= r'f'))) {
            return false
        }
    }
    true
}

private func p4CompletionRun(label:String,mutation:String):P1M00PrivateRunFixture{
    let fixture=p1M00PrivateRun(164,"p4-${label}");let root=Path(fixture.root);let bundleHash=benchmarkGapSha256("student-bundle");let oldResults=String.fromUtf8(File.readFrom(root.join("results.jsonl")));let lineageValue=if(mutation=="derived"){"humaneval_164_derived"}else if(mutation=="wrong_lineage"){"wrong"}else{"independent"}
    let oldProvider=String.fromUtf8(File.readFrom(root.join("provider-identity.json")));let oldProviderHash=benchmarkGapSha256(oldProvider);let model="GLM-5.2";let claude=ckbAbcdeClaudeVersionForTest(executable:"/bin/echo");let student=p4FreezeStudentValidationAssets(fixture.root,model,claude)
    let manifest=String.fromUtf8(File.readFrom(root.join("run-manifest.json"))).replace(oldProviderHash,student.providerHash).replace("}",",\"generationProtocol\":\"completion-only-v1\",\"samplingCapability\":\"temperature_zero\",\"skillBundleVersion\":\"student-v1\",\"skillBundleHash\":\"${bundleHash}\",\"assetLineage\":\"${lineageValue}\",${student.manifestFields}}")
    File.writeTo(root.join("run-manifest.json"),manifest.toArray());let out=StringBuilder()
    for(line in oldResults.split("\n")){if(line==""){continue};let row=parseCkbCertificationEvidence(line);let groupRoot=root.join("cases").join(row.caseId).join(row.group);let solution=String.fromUtf8(File.readFrom(groupRoot.join("workspace/src/solution.cj")));let answerHash=benchmarkGapSha256(solution)
        var transcript="{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false,\"modelUsage\":{\"GLM-5.2\":{}},\"structured_output\":{\"solution_cj\":\"${ckbAbcdeJsonEscape(solution)}\"}}"
        if(row.caseId=="CJ-HUMANEVAL-000"&&mutation=="tool_use"){transcript="{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Skill\"}]}}\n${transcript}"}
        if(row.caseId=="CJ-HUMANEVAL-000"&&mutation=="second_answer"){transcript+="\n${transcript}"}
        Directory.create(groupRoot.join("frozen-completion"),recursive:true);File.writeTo(groupRoot.join("frozen-completion/solution.cj"),solution.toArray());File.writeTo(groupRoot.join("claude-transcript.jsonl"),transcript.toArray());File.writeTo(groupRoot.join("claude-transcript.attempt-1.jsonl"),transcript.toArray())
        let attemptsPath=groupRoot.join("claude-attempts.jsonl");let oldAttempts=String.fromUtf8(File.readFrom(attemptsPath));let attempts=oldAttempts.replace(row.transcriptHash,benchmarkGapSha256(transcript));File.writeTo(attemptsPath,attempts.toArray());let restores=String.fromUtf8(File.readFrom(groupRoot.join("workspace-restores.jsonl")));let lineageHash=ckbAbcdeAttemptLineageHash(attempts,restores);let summaryPath=groupRoot.join("attempt-evidence.json");let summary=String.fromUtf8(File.readFrom(summaryPath)).replace(row.attemptLineageHash,lineageHash);File.writeTo(summaryPath,summary.toArray());let legacyTestPath=groupRoot.join("test-result.json");let legacyTest=String.fromUtf8(File.readFrom(legacyTestPath)).replace(row.attemptLineageHash,lineageHash);File.writeTo(legacyTestPath,legacyTest.toArray())
        let early=row.caseId=="CJ-HUMANEVAL-000"&&mutation=="early_execution";let failed=row.caseId=="CJ-HUMANEVAL-000"&&mutation=="post_token_failure";let outcomeFailed=failed;let zeroRecovered=row.caseId=="CJ-HUMANEVAL-000"&&mutation=="zero_token_recovered";let zeroUnrecovered=row.caseId=="CJ-HUMANEVAL-000"&&mutation=="zero_token_unrecovered"
        if(outcomeFailed){let failedTest=String.fromUtf8(File.readFrom(legacyTestPath)).replace("\"testExitCode\":0","\"testExitCode\":1").replace("\"unitPassAt1\":true","\"unitPassAt1\":false").replace("\"failureType\":\"none\"","\"failureType\":\"test_failure\"");File.writeTo(legacyTestPath,failedTest.toArray())}
        File.writeTo(groupRoot.join("generation-evidence.json"),"{\"answerHash\":\"${answerHash}\",\"completionCount\":1,\"toolCallCount\":0,\"executionFeedbackCount\":0,\"interrupted\":${failed||zeroRecovered||zeroUnrecovered},\"generatedTokenCount\":${if(failed){1}else{0}},\"checkpointRecovered\":${zeroRecovered}}".toArray())
        File.writeTo(groupRoot.join("answer-freeze.json"),"{\"answerHash\":\"${answerHash}\",\"sequence\":${if(early){4}else{2}}}".toArray())
        File.writeTo(groupRoot.join("base-test-result.json"),"{\"answerHash\":\"${answerHash}\",\"sequence\":3,\"passed\":${!outcomeFailed}}".toArray());File.writeTo(groupRoot.join("plus-test-result.json"),"{\"answerHash\":\"${answerHash}\",\"sequence\":4,\"passed\":${!outcomeFailed}}".toArray())
        row.schemaVersion="ckb-humaneval-certification-result-v4";row.generationProtocol="completion-only-v1";row.samplingCapability="temperature_zero";row.completionCount=1;row.toolCallCount=0;row.executionFeedbackCount=0;row.answerFreezeSequence=if(early){4}else{2};row.firstExecutionSequence=3;row.baseAnswerHash=answerHash;row.plusAnswerHash=answerHash;row.basePassed=!outcomeFailed;row.plusPassed=!outcomeFailed;row.skillBundleVersion="student-v1";row.skillBundleHash=if(row.caseId=="CJ-HUMANEVAL-000"&&mutation=="bundle_drift"){benchmarkGapSha256("drift")}else{bundleHash};row.assetLineage=lineageValue;row.providerIdentityHash=student.providerHash;row.llmTurnCount=1;row.attemptLineageHash=lineageHash;row.transcriptHash=benchmarkGapSha256(transcript);row.certificationPassAt1=!outcomeFailed;row.configHash=benchmarkGapSha256(String.fromUtf8(File.readFrom(groupRoot.join("mcp-config.json")))+String.fromUtf8(File.readFrom(groupRoot.join("runtime-policy.json")))+student.providerText+String.fromUtf8(File.readFrom(groupRoot.join("paired-tool-evidence.json"))));row.artifactHash=benchmarkGapSha256(row.answerHash+row.transcriptHash+row.testHash+row.configHash);sealCkbCertificationEvidence(row)
        let rendered=renderCkbCertificationEvidenceJson(row);File.writeTo(groupRoot.join("result-evidence.json"),rendered.toArray());File.writeTo(groupRoot.join("audit.json"),"{\"violation\":\"none\",\"developmentPass\":false,\"closureStatus\":\"closed\",\"triageStatus\":\"complete\",\"failureRoute\":\"${if(failed){"business_failure"}else{"none"}}\",\"certificationPassAt1\":null}".toArray());out.append(rendered);out.append("\n")
    }
    let results=out.toString();File.writeTo(root.join("results.jsonl"),results.toArray());let provenancePath=root.join("runner-provenance.json");let provenance=String.fromUtf8(File.readFrom(provenancePath)).replace(benchmarkGapSha256(oldResults),benchmarkGapSha256(results));File.writeTo(provenancePath,provenance.toArray());fixture
}

private func p4CompletionRunV5(label:String,rulesDrift:Bool):P1M00PrivateRunFixture{
    let fixture=p4CompletionRun(label,"none");let root=Path(fixture.root);let rulesHash=benchmarkGapSha256("student-rules");let rulesTreeHash=benchmarkGapSha256("student-rules-tree");let rulesCount:Int64=1;let manifestPath=root.join("run-manifest.json");let manifest=String.fromUtf8(File.readFrom(manifestPath)).replace("}",",\"rulesHash\":\"${rulesHash}\",\"rulesTreeHash\":\"${rulesTreeHash}\",\"rulesCount\":${rulesCount}}");File.writeTo(manifestPath,manifest.toArray())
    let oldResults=String.fromUtf8(File.readFrom(root.join("results.jsonl")));let out=StringBuilder()
    for(line in oldResults.split("\n")){if(line==""){continue};let row=parseCkbCertificationEvidence(line);row.schemaVersion="ckb-humaneval-certification-result-v5";row.rulesHash=if(rulesDrift&&row.caseId=="CJ-HUMANEVAL-000"){benchmarkGapSha256("student-rules-drift")}else{rulesHash};row.rulesTreeHash=rulesTreeHash;row.rulesCount=rulesCount;sealCkbCertificationEvidence(row);let rendered=renderCkbCertificationEvidenceJson(row);let evidencePath=root.join("cases").join(row.caseId).join(row.group).join("result-evidence.json");File.writeTo(evidencePath,rendered.toArray());out.append(rendered);out.append("\n")}
    let results=out.toString();File.writeTo(root.join("results.jsonl"),results.toArray());let provenancePath=root.join("runner-provenance.json");let provenance=String.fromUtf8(File.readFrom(provenancePath)).replace(benchmarkGapSha256(oldResults),benchmarkGapSha256(results));File.writeTo(provenancePath,provenance.toArray());fixture
}

private func p4Pass1Options(fixture:P1M00PrivateRunFixture):CangjieHumanEvalPass1GateOptions{let o=CangjieHumanEvalPass1GateOptions();o.runRoot=fixture.root;o.manifestPath=Path(fixture.root).join("authority.jsonl").toString();o.groups=ArrayList<String>();o.groups.add(CkbAbcdeGroups.D);o.protocol="completion-only-v1";o}
private func p7DiagnosticsText(values:ArrayList<String>):String{let out=StringBuilder();for(value in values){out.append(value);out.append("\n")};out.toString()}
private func p4Reference(fixture:P1M00PrivateRunFixture):CkbReproReferenceManifest{let first=parseCkbCertificationEvidence(String.fromUtf8(File.readFrom(Path(fixture.root).join("results.jsonl"))).split("\n")[0]);let r=CkbReproReferenceManifest();r.schemaVersion="ckb-repro-reference-v1";r.baselineKind="portable_release";r.evidenceStatus="complete";r.releaseRepository="l3gi0nXXXX/CangjieCommunityKnowledgeBase";r.releaseRepositoryUrl="https://github.com/l3gi0nXXXX/CangjieCommunityKnowledgeBase";r.releaseBranch="main";r.observedRemote="https://github.com/l3gi0nXXXX/CangjieCommunityKnowledgeBase.git";r.runId=first.runId;r.knowledgeVersion=first.knowledgeVersion;r.vectorProofHash=benchmarkGapSha256("vector");r.datasetVersion=first.datasetVersion;r.runnerCommit="0123456789012345678901234567890123456789";r.claudeCodeVersion=first.claudeCodeVersion;r.model=first.expectedModelVersion;r.modelFingerprint="claude-code-glm-5.2";r.providerFingerprint=first.providerIdentityHash;r.experimentGroup=CkbAbcdeGroups.D;r.toolTransport="mcp";r.mcpTransport="stdio";r.ckbRequired=true;r.localDocsPolicy="disabled";r.modelEffort="high";r.modelBudget="fixed";r.timeoutSeconds=3600;r.transportRetryBudget=0;r.promptHash=benchmarkGapSha256("prompt");r.resultsHash=benchmarkGapSha256(String.fromUtf8(File.readFrom(Path(fixture.root).join("results.jsonl"))));r.runCriticalTreeHash=benchmarkGapSha256("tree");r.certifiedRunInputHash=benchmarkGapSha256("input");r.totalCases=164;r.rawPassed=164;r.strictPassed=164;r.strictFailed=0;r.businessFailed=0;r.protocolInvalid=0;r.transportUnresolved=0;r}
