package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}
import std.process.launch
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieEvalFailureTriageTest {
    // S1-POS-01
    @TestCase
    public func completionFailureIndexIsAtomicSortedAndIdempotent():Unit{
        let root=Path("target/s1-failure-index-positive");if(exists(root)){_=launch("/bin/rm",["-rf",root.toString()]).wait()}
        let groups=ArrayList<String>();groups.add("C-ckb-mcp-stdio")
        s1WriteOutcome(root,"CJ-HUMANEVAL-001",true)
        s1WriteOutcome(root,"CJ-HUMANEVAL-000",false)
        let built=buildCkbCompletionFailureIndex(root.toString(),"s1-run",groups,0,1)
        @Expect(built[1],"ok");@Expect(built[0].startsWith("{\"caseId\":\"CJ-HUMANEVAL-000\""),true)
        @Expect(built[0].contains("base-test"),false);@Expect(built[0].contains("solution"),false)
        @Expect(finalizeCkbCompletionFailureIndex(root.toString(),"s1-run",groups,0,1),"ok")
        let first=String.fromUtf8(File.readFrom(root.join("completion-failures.jsonl")))
        @Expect(finalizeCkbCompletionFailureIndex(root.toString(),"s1-run",groups,0,1),"ok")
        @Expect(String.fromUtf8(File.readFrom(root.join("completion-failures.jsonl"))),first)
    }

    // S1-NEG-01
    @TestCase
    public func completionFailureRejectsDriftSecretsAndFrozenRewrite():Unit{
        let root=Path("target/s1-failure-index-negative");if(exists(root)){_=launch("/bin/rm",["-rf",root.toString()]).wait()}
        let groups=ArrayList<String>();groups.add("C-ckb-mcp-stdio")
        s1WriteOutcome(root,"CJ-HUMANEVAL-000",false)
        @Expect(finalizeCkbCompletionFailureIndex(root.toString(),"s1-run",groups,0,0),"ok")
        File.writeTo(root.join("completion-failures.jsonl"),"drift\n".toArray())
        @Expect(finalizeCkbCompletionFailureIndex(root.toString(),"s1-run",groups,0,0),"failure_evidence_frozen")
        let caseRoot=root.join("cases/CJ-HUMANEVAL-000/C-ckb-mcp-stdio")
        let answer="sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        File.writeTo(caseRoot.join("base-test-result.json"),("{\"answerHash\":\"${answer}\",\"passed\":false}\n").toArray())
        File.writeTo(caseRoot.join("plus-test-result.json"),("{\"answerHash\":\"${answer}\",\"passed\":true}\n").toArray())
        File.writeTo(caseRoot.join("canonical-task-context.json"),"{\"taskId\":\"CJ-HUMANEVAL-000\",\"datasetVersion\":\"dataset-v1\",\"taskText\":\"公开任务 中文😀\"}\n".toArray())
        File.writeTo(caseRoot.join("base-test.log"),"assert public failure 中文😀".toArray());File.writeTo(caseRoot.join("plus-test.log"),"PASS".toArray())
        let options=CkbAbcdeRunnerOptions();options.runId="s1-run";options.datasetVersion="dataset-v1"
        let result=String.fromUtf8(File.readFrom(caseRoot.join("result-evidence.json"))).trimAscii()
        _=launch("/bin/rm",["-f",caseRoot.join("completion-failure.json").toString()]).wait()
        @Expect(persistCkbCompletionFailureEvidence(caseRoot.toString(),options,"CJ-HUMANEVAL-000","C-ckb-mcp-stdio",answer,result),"ok")
        @Expect(persistCkbCompletionFailureEvidence(caseRoot.toString(),options,"CJ-HUMANEVAL-000","C-ckb-mcp-stdio",answer,result.replace("test_failure","compile_error")),"failure_evidence_frozen")
        let duplicate=ArrayList<String>();duplicate.add("C-ckb-mcp-stdio");duplicate.add("C-ckb-mcp-stdio")
        @Expect(buildCkbCompletionFailureIndex(root.toString(),"s1-run",duplicate,0,0)[1],"failure_index_duplicate")
        let failure=String.fromUtf8(File.readFrom(caseRoot.join("completion-failure.json")))
        File.writeTo(caseRoot.join("completion-failure.json"),failure.replace("base=failed","Authorization: Bearer secret").toArray())
        @Expect(buildCkbCompletionFailureIndex(root.toString(),"s1-run",groups,0,0)[1],"failure_index_failure_mismatch")
    }

    @TestCase
    public func p5Ut01TaxonomyConfirmationAndRetryPass1AreStrict(): Unit {
        let cases = [
            (p5Triage("\"protocolViolation\":true", 1), "protocol_violation", "protocol"),
            (p5Triage("\"timedOut\":true", 1), "timeout", "timeout"),
            (p5Triage("\"toolFailure\":true", 1), "tool_error", "tool"),
            (p5Triage("\"datasetFailure\":true", 1), "dataset_failure", "dataset"),
            (p5Triage("\"runnerFailure\":true", 1), "runner_failure", "runner"),
            (p5Triage("\"environmentFailure\":true", 1), "environment_failure", "environment"),
            (p5Triage("\"reasoningFailure\":true", 1), "reasoning_failure", "reasoning")
        ]
        for (entry in cases) {
            let result = triageEvalFailure(entry[0])
            @Expect(result.ok, true); @Expect(result.category, entry[1]); @Expect(result.route, entry[2])
        }
        let first = p5Classifier("classifier-a", "transcript-a", "knowledge_gap", 1, "development")
        let second = p5Classifier("classifier-b", "transcript-b", "knowledge_gap", 1, "development")
        let confirmed = confirmKnowledgeGap(first, second)
        @Expect(confirmed.confirmed, true); @Expect(confirmed.diagnostic, "ok")
        @Expect(confirmKnowledgeGap(first, p5Classifier("classifier-b", "transcript-b", "reasoning_failure", 1, "development")).diagnostic, "classifier_disagreement")
        @Expect(confirmKnowledgeGap(first, p5Classifier("classifier-a", "transcript-b", "knowledge_gap", 1, "development")).diagnostic, "independent_classifier_required")
        @Expect(confirmKnowledgeGap(first, p5Classifier("classifier-b", "transcript-b", "knowledge_gap", 2, "development")).diagnostic, "classifier_field_contract_invalid")
        let contaminatedA = p5ClassifierWithKnowledgeText("classifier-a", "transcript-a", "knowledge_gap", 1, "development", "Answer for CJ-HUMANEVAL-007")
        let contaminatedB = p5ClassifierWithKnowledgeText("classifier-b", "transcript-b", "knowledge_gap", 1, "development", "Answer for CJ-HUMANEVAL-007")
        @Expect(confirmKnowledgeGap(contaminatedA, contaminatedB).diagnostic, "knowledge_policy_not_satisfied")
        let retry = triageEvalFailure(p5Triage("\"unitPass\":true", 2))
        @Expect(retry.category, "reasoning_failure")
        @Expect(triageEvalFailure("{\"attempt\":1,\"runMode\":\"development\"}").diagnostic, "field_contract_invalid")
        @Expect(triageEvalFailure(p5Triage("\"timedOut\":true", 1).replace("CJ-HUMANEVAL-007", "CJ-HUMANEVAL-008")).diagnostic, "result_evidence_hash_mismatch")
    }

    @TestCase
    public func p5Bnd01MalformedUnicodeLongAndOperationalFailuresFailClosed(): Unit {
        @Expect(triageEvalFailure("").diagnostic, "empty_input")
        @Expect(triageEvalFailure("{\"attempt\":1").diagnostic, "malformed_json")
        @Expect(triageEvalFailureFromUtf8([UInt8(0xff), UInt8(0xfe)]).diagnostic, "invalid_response_encoding")
        @Expect(triageEvalFailure(p5Triage("\"emptyModelResponse\":true,\"note\":\"中文😀\"", 1)).category, "model_empty")
        @Expect(triageEvalFailure(p5Triage("\"zeroKnowledgeHits\":true", 1)).category, "evidence_missing")
        @Expect(triageEvalFailure(p5Triage("\"malformedToolPayload\":true", 1)).category, "malformed_tool_payload")
        @Expect(triageEvalFailure(p5Triage("\"timedOut\":true", 1)).category, "timeout")
        @Expect(triageEvalFailure(p5Triage("\"toolFailure\":true", 1)).category, "tool_error")
        var huge = ""; for (_ in 0..262145) { huge += "界" }
        @Expect(triageEvalFailure(huge).diagnostic, "input_too_large")
        @Expect(confirmKnowledgeGap("{", "{}").diagnostic, "malformed_classifier_evidence")
    }

    // NK-UT-02
    @TestCase
    public func nkUt02NonKnowledgeLabelsReachAuditableRouteConsensus(): Unit {
        let reasoning = nkClassifier("CJ-HUMANEVAL-116", "a", "reasoning_failure")
        let unit = nkClassifier("CJ-HUMANEVAL-116", "b", "unit_failure")
        let result = confirmIndependentClassifierPair(reasoning, unit)
        @Expect(result.confirmed, true); @Expect(result.diagnostic, "nonknowledge_route_consensus")
        @Expect(result.route, "reasoning"); @Expect(result.firstCategory, "reasoning_failure"); @Expect(result.secondCategory, "unit_failure")
        @Expect(result.nonKnowledgeRouteConsensus, true); @Expect(result.evidenceHash.startsWith("sha256:"), true)
        @Expect(confirmKnowledgeGap(reasoning, unit).diagnostic, "knowledge_gap_not_confirmed")
        let compile = confirmIndependentClassifierPair(nkClassifier("CJ-HUMANEVAL-132", "a", "compile_error"), nkClassifier("CJ-HUMANEVAL-132", "b", "unit_failure"))
        @Expect(compile.confirmed, true); @Expect(compile.route, "reasoning")
    }

    // NK-BND-01
    @TestCase
    public func nkBnd01IdentityRouteUtf8AndSecretBoundariesFailClosed(): Unit {
        let first = nkClassifier("CJ-HUMANEVAL-116", "a", "reasoning_failure")
        let sourceMismatch = nkClassifier("CJ-HUMANEVAL-116", "b", "unit_failure", studentHash: "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        @Expect(confirmIndependentClassifierPair(first, sourceMismatch).diagnostic, "classifier_semantic_disagreement")
        let timeout = nkClassifier("CJ-HUMANEVAL-116", "b", "timeout")
        @Expect(confirmIndependentClassifierPair(first, timeout).diagnostic, "classifier_disagreement")
        @Expect(triageEvalFailureFromUtf8([UInt8(0xff), UInt8(0xfe)]).diagnostic, "invalid_response_encoding")
        let closure = nkClosure("CJ-HUMANEVAL-116-中文🙂", confirmIndependentClassifierPair(first, nkClassifier("CJ-HUMANEVAL-116", "b", "unit_failure")))
        let rendered = renderDevelopmentClosure(nkClosureList(closure))
        @Expect(rendered.contains("中文🙂"), true); @Expect(rendered.toAsciiLower().contains("authorization"), false); @Expect(rendered.toAsciiLower().contains("token="), false)
    }

    // NK-POS-093
    @TestCase
    public func nkPos093ExactUnitFailureRoutesWithoutKnowledgeCandidate(): Unit {
        nkExpectAuditableCase("CJ-HUMANEVAL-093", "unit_failure", "unit_failure")
    }

    // NK-POS-116
    @TestCase
    public func nkPos116ReasoningUnitDisagreementRoutesWithoutKnowledgeCandidate(): Unit {
        nkExpectAuditableCase("CJ-HUMANEVAL-116", "reasoning_failure", "unit_failure")
    }

    // NK-POS-132
    @TestCase
    public func nkPos132ReasoningUnitDisagreementRoutesWithoutKnowledgeCandidate(): Unit {
        nkExpectAuditableCase("CJ-HUMANEVAL-132", "reasoning_failure", "unit_failure")
    }

    // NK-POS-160
    @TestCase
    public func nkPos160ExactUnitFailureRoutesWithoutKnowledgeCandidate(): Unit {
        nkExpectAuditableCase("CJ-HUMANEVAL-160", "unit_failure", "unit_failure")
    }

    // NK-NEG-01
    @TestCase
    public func nkNeg01KnowledgeDisagreementCannotBecomeRouteOrAuthority(): Unit {
        let result = confirmIndependentClassifierPair(nkClassifier("CJ-HUMANEVAL-093", "a", "knowledge_gap"), nkClassifier("CJ-HUMANEVAL-093", "b", "unit_failure"))
        @Expect(result.confirmed, false); @Expect(result.diagnostic, "classifier_disagreement")
        let invalid = CangjieEvalDevelopmentCaseClosure(); invalid.caseId = "CJ-HUMANEVAL-093"; invalid.category = "unit_failure"; invalid.route = "reasoning"; invalid.routeEvidenceHash = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        let rendered = renderDevelopmentClosure(nkClosureList(invalid))
        @Expect(rendered.contains("\"invalidCaseCount\":1"), true); @Expect(rendered.contains("\"knowledgeCandidateCount\":0"), true)
    }

    @TestCase
    public func p5E2e01FiveCaseDevelopmentClosureNeverClaimsCertification(): Unit {
        let cases = ArrayList<CangjieEvalDevelopmentCaseClosure>()
        cases.add(p5Closure("CJ-HUMANEVAL-007知识😀", false, "knowledge_gap", true))
        cases.add(p5Closure("reasoning", false, "reasoning_failure", false))
        cases.add(p5Closure("dataset", false, "dataset_failure", false))
        cases.add(p5Closure("infrastructure", false, "environment_failure", false))
        cases.add(p5Closure("success", true, "none", false))
        let closure = renderDevelopmentClosure(cases)
        @Expect(closure.contains("\"developmentClosed\":false"), true)
        @Expect(closure.contains("\"developmentPassed\":1"), true)
        @Expect(closure.contains("\"knowledgeCandidateCount\":1"), true)
        @Expect(closure.contains("\"certifiedPassAt1\":null"), true)
        @Expect(closure.contains("\"certificationStatus\":\"unset\""), true)
        @Expect(closure.contains("知识😀"), true)
        let conflict = ArrayList<CangjieEvalDevelopmentCaseClosure>()
        conflict.add(p5Closure("conflict", true, "knowledge_gap", true))
        let conflictJson = renderDevelopmentClosure(conflict)
        @Expect(conflictJson.contains("\"invalidCaseCount\":1"), true)
        @Expect(conflictJson.contains("case_state_conflict:conflict"), true)
        @Expect(conflictJson.contains("\"knowledgeCandidateCount\":0"), true)
    }

    @TestCase
    public func p5ProviderIdentityAndRunLevel164ClosureAreAuthorityBound(): Unit {
        let identity = ckbAbcdeProviderIdentityJson("GLM-5.2", "claude-code-2.1.179")
        @Expect(identity.contains("GLM-5.2"), true)
        @Expect(identity.contains("token"), false)
        @Expect(identity.contains("Authorization"), false)
        @Expect(ckbAbcdeProviderIdentityJson("other-model", "claude-code-2.1.179"), "")

        let root = "target/p5-run-level"
        if (exists(Path(root))) { _ = launch("/bin/rm", ["-rf", root]).wait() }
        let options = CkbAbcdeRunnerOptions(); options.runId = "run-001"; options.datasetVersion = "dataset-v1"
        options.groups.clear(); options.groups.add(CkbAbcdeGroups.C)
        for (i in 0..164) {
            let id = p5CaseId(i); let groupRoot = Path(root).join("cases").join(id).join(CkbAbcdeGroups.C)
            Directory.create(groupRoot, recursive: true)
            let caseResult = "{\"caseId\":\"${id}\",\"runId\":\"run-001\",\"datasetVersion\":\"dataset-v1\",\"runMode\":\"development\",\"workspaceId\":\"w-${i}\",\"sessionId\":\"s-${i}\",\"runtimeHomeId\":\"h-${i}\",\"developmentPass\":${i != 7},\"certificationPassAt1\":null}"
            let rawEvidence = if (i == 7) { p5Triage("\"suspectedKnowledgeGap\":true", 1) } else { "{\"caseId\":\"${id}\",\"runId\":\"run-001\",\"datasetVersion\":\"dataset-v1\",\"attempt\":1,\"runMode\":\"development\",\"failureObservation\":\"case_passed 中文😀\",\"unitPass\":true,\"resultEvidenceHash\":\"HASH\"}" }
            let evidence = rawEvidence.replace("HASH", cangjieEvalTriageResultEvidenceHash(rawEvidence))
            File.writeTo(groupRoot.join("case-result.json"), caseResult.toArray()); File.writeTo(groupRoot.join("result-evidence.json"), evidence.toArray())
        }
        let firstRoot = "${root}/classifier-a"; let secondRoot = "${root}/classifier-b"; Directory.create(Path(firstRoot), recursive: true); Directory.create(Path(secondRoot), recursive: true)
        File.writeTo(Path(firstRoot).join("CJ-HUMANEVAL-007.json"), p5Classifier("classifier-a", "source-a", "knowledge_gap", 1, "development").toArray())
        File.writeTo(Path(secondRoot).join("CJ-HUMANEVAL-007.json"), p5Classifier("classifier-b", "source-b", "knowledge_gap", 1, "development").toArray())
        @Expect(runCangjieEvalDevelopmentClose(["cangjie-eval-development-close", "--run-root", root, "--run-id", "run-001", "--transport", "C", "--classifier-a-root", firstRoot, "--classifier-b-root", secondRoot]), 0)
        let aggregate = aggregateDevelopmentRun(options, root)
        @Expect(aggregate.ok, true)
        @Expect(aggregate.developmentClosureJson.contains("\"developmentTotal\":164"), true)
        @Expect(aggregate.developmentClosureJson.contains("\"developmentClosed\":false"), true)
        @Expect(aggregate.developmentClosureJson.contains("\"certifiedPassAt1\":null"), true)
        @Expect(aggregate.authoritativeGapJsonl.contains("\"caseId\":\"CJ-HUMANEVAL-007\""), true)

        options.groups.add(CkbAbcdeGroups.D)
        @Expect(aggregateDevelopmentRun(options, root).diagnostics[0], "single_treatment_transport_required")
        options.groups.remove(at: 1)
        _ = launch("/bin/rm", ["-f", "${root}/cases/CJ-HUMANEVAL-163/${CkbAbcdeGroups.C}/result-evidence.json"]).wait()
        @Expect(aggregateDevelopmentRun(options, root).ok, false)
    }

    @TestCase
    public func p5SingleCaseClosePublishesOnlyConfirmedAuthorityAtomically(): Unit {
        let root="/tmp/ckb-single-case-close-test";if(exists(Path(root))){_=launch("/bin/rm",["-rf",root]).wait()}
        let caseRoot=Path(root).join("case");Directory.create(caseRoot,recursive:true)
        let evidence=p5Triage("\"suspectedKnowledgeGap\":true",1,failureType:"compile_error")
        let caseResult="{\"caseId\":\"CJ-HUMANEVAL-007\",\"runId\":\"run-001\",\"datasetVersion\":\"dataset-v1\",\"runMode\":\"development\",\"workspaceId\":\"w-one\",\"sessionId\":\"s-one\",\"runtimeHomeId\":\"h-one\",\"developmentPass\":false,\"certificationPassAt1\":null}"
        File.writeTo(caseRoot.join("case-result.json"),caseResult.toArray());File.writeTo(caseRoot.join("result-evidence.json"),evidence.toArray())
        File.writeTo(caseRoot.join("canonical-task-context.json"),"{\"taskText\":\"仓颉范围语法 中文😀\"}".toArray())
        File.writeTo(caseRoot.join("test.log"),"error: expected 范围🙂, actual 空\n==> /private/user/path/solution.cj:28:28:\n1 error generated, 1 error printed.\nError: failed to compile package `fixture`, return code is 1\n at /private/user/path token=secret".toArray())
        let first=Path(root).join("a.json");let second=Path(root).join("b.json");File.writeTo(first,p5Classifier("classifier-a","source-a","knowledge_gap",1,"development",failureType:"compile_error").toArray());File.writeTo(second,p5Classifier("classifier-b","source-b","knowledge_gap",1,"development",failureType:"compile_error").toArray())
        let output="${root}/authority";let args=["cangjie-eval-case-close","--case-root",caseRoot.toString(),"--classifier-a",first.toString(),"--classifier-b",second.toString(),"--teacher-run-id","teacher-run-中文","--output-root",output,"--gap-code","G-RANGE","--interface-id","KI-04","--content-family","KC-01","--target-version","1.0.0"]
        @Expect(runCangjieEvalSingleCaseClose(args),0);@Expect(exists(Path(output).join("development-closure.json")),true);@Expect(exists(Path(output).join("authority-gap.jsonl")),true)
        let gap=String.fromUtf8(File.readFrom(Path(output).join("authority-gap.jsonl")));@Expect(gap.contains("\"caseId\":\"CJ-HUMANEVAL-007\""),true);@Expect(gap.contains("\"missingKnowledge\":\"G-RANGE\""),true);@Expect(gap.contains("仓颉范围语法 中文😀"),true)
        @Expect(gap.contains("expected 范围🙂, actual 空"),true);@Expect(gap.contains("/private/user/path"),false);@Expect(gap.contains("token=secret"),false);@Expect(gap.contains("failureSummaryHash=sha256:"),true)
        @Expect(runCangjieEvalSingleCaseClose(args),1)
        let bad=args.clone();bad[2]="/tmp/ckb-data/forbidden";bad[10]="${root}/bad-output";@Expect(runCangjieEvalSingleCaseClose(bad),1);@Expect(exists(Path("${root}/bad-output")),false)
        _=launch("/bin/rm",["-rf",root]).wait()
    }

    // S5-UT-02
    @TestCase
    public func s5Ut02ProtocolClosureIsDeterministicWithoutClassifiers(): Unit {
        let input=s5ClosureInput("CJ-HUMANEVAL-016","\"protocolViolation\":true")
        let inputs=ArrayList<CangjieEvalDevelopmentClosureInput>();inputs.add(input)
        let result=orchestrateDevelopmentClosure(inputs,"teacher-s5")
        @Expect(result.ok,true);@Expect(result.pendingClassifierCount,0)
        @Expect(result.knowledgeGapCount,0);@Expect(result.authoritativeGapJsonl,"")
        @Expect(result.developmentClosureJson.contains("\"category\":\"protocol_violation\""),true)
        @Expect(result.developmentClosureJson.contains("\"route\":\"protocol\""),true)
        @Expect(result.developmentClosureJson.contains("\"nonKnowledgeRouteConfirmed\":true"),true)
        @Expect(result.developmentClosureJson.contains("\"routeEvidenceHash\":\"sha256:"),true)
    }

    // S5-BND-02
    @TestCase
    public func s5Bnd02OperationalClosuresAreFinalNonKnowledgeRoutes(): Unit {
        for((signal,category,route) in [
            ("\"environmentFailure\":true","environment_failure","environment"),
            ("\"runnerFailure\":true","runner_failure","runner"),
            ("\"datasetFailure\":true","dataset_failure","dataset"),
            ("\"timedOut\":true","timeout","timeout"),
            ("\"malformedToolPayload\":true","malformed_tool_payload","protocol"),
            ("\"toolFailure\":true","tool_error","tool"),
            ("\"emptyModelResponse\":true","model_empty","reasoning"),
            ("\"zeroKnowledgeHits\":true","evidence_missing","retrieval")
        ]){
            let inputs=ArrayList<CangjieEvalDevelopmentClosureInput>();inputs.add(s5ClosureInput("CJ-HUMANEVAL-016",signal))
            let result=orchestrateDevelopmentClosure(inputs,"teacher-s5")
            @Expect(result.ok,true);@Expect(result.pendingClassifierCount,0);@Expect(result.knowledgeGapCount,0)
            @Expect(result.developmentClosureJson.contains("\"category\":\"${category}\""),true)
            @Expect(result.developmentClosureJson.contains("\"route\":\"${route}\""),true)
        }
    }

    // S5-POS-04
    @TestCase
    public func s5Pos04BusinessKnowledgeGapStillNeedsAndAcceptsTwoClassifiers(): Unit {
        let input=s5ClosureInput("CJ-HUMANEVAL-007","\"suspectedKnowledgeGap\":true",failureType:"compile_error")
        input.firstClassifierJson=p5Classifier("classifier-a","source-a","knowledge_gap",1,"development",failureType:"compile_error")
        input.secondClassifierJson=p5Classifier("classifier-b","source-b","knowledge_gap",1,"development",failureType:"compile_error")
        let inputs=ArrayList<CangjieEvalDevelopmentClosureInput>();inputs.add(input)
        let result=orchestrateDevelopmentClosure(inputs,"teacher-s5")
        @Expect(result.ok,true);@Expect(result.pendingClassifierCount,0);@Expect(result.knowledgeGapCount,1)
        @Expect(result.authoritativeGapJsonl.contains("\"failureTaxonomy\":\"knowledge_gap\""),true)
    }

    // S5-NEG-03
    @TestCase
    public func s5Neg03ForgedCaseCategoryAndTamperedSealCannotBypass(): Unit {
        let business=s5ClosureInput("CJ-HUMANEVAL-016","\"reasoningFailure\":true")
        business.caseResultJson=business.caseResultJson.replace("}",",\"category\":\"protocol_violation\"}")
        let businessInputs=ArrayList<CangjieEvalDevelopmentClosureInput>();businessInputs.add(business)
        let pending=orchestrateDevelopmentClosure(businessInputs,"teacher-s5")
        @Expect(pending.ok,true);@Expect(pending.pendingClassifierCount,1)
        @Expect(pending.developmentClosureJson.contains("\"category\":\"reasoning_failure\""),true)

        let tampered=s5ClosureInput("CJ-HUMANEVAL-016","\"protocolViolation\":true")
        tampered.resultEvidenceJson=tampered.resultEvidenceJson.replace("\"protocolViolation\":true","\"protocolViolation\":false,\"environmentFailure\":true")
        let tamperedInputs=ArrayList<CangjieEvalDevelopmentClosureInput>();tamperedInputs.add(tampered)
        let blocked=orchestrateDevelopmentClosure(tamperedInputs,"teacher-s5")
        @Expect(blocked.ok,false);@Expect(blocked.knowledgeGapCount,0)
        @Expect(blocked.authoritativeGapJsonl,"")
    }
}

private func s1WriteOutcome(root:Path,caseId:String,passed:Bool):Unit{
    let group="C-ckb-mcp-stdio";let caseRoot=root.join("cases").join(caseId).join(group);Directory.create(caseRoot,recursive:true)
    let result="{\"runId\":\"s1-run\",\"caseId\":\"${caseId}\",\"datasetVersion\":\"dataset-v1\",\"failureType\":\"test_failure\"}"
    File.writeTo(caseRoot.join("result-evidence.json"),(result+"\n").toArray())
    let base=if(passed){"passed"}else{"failed"};let outcome=renderCkbCompletionEvaluationOutcome("s1-run",caseId,group,"dataset-v1","sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",base,"passed",benchmarkGapSha256(result))
    File.writeTo(caseRoot.join("evaluation-outcome.json"),(outcome+"\n").toArray())
    if(!passed){
        let failure=CkbCompletionFailure();failure.runId="s1-run";failure.caseId=caseId;failure.datasetVersion="dataset-v1";failure.completionHash="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";failure.baseStatus="failed";failure.plusStatus="passed";failure.failureKind="test_failure";failure.failureObservation="base=failed:中文😀";failure.assetLineage="humaneval_164_derived"
        @Expect(sealCkbCompletionFailure(failure),"ok");File.writeTo(caseRoot.join("completion-failure.json"),(renderCkbCompletionFailure(failure)+"\n").toArray())
    }
}

private func p5CaseId(index: Int64): String {
    if (index < 10) { return "CJ-HUMANEVAL-00${index}" }
    if (index < 100) { return "CJ-HUMANEVAL-0${index}" }
    "CJ-HUMANEVAL-${index}"
}

private func p5Classifier(classifier: String, source: String, category: String, attempt: Int64, mode: String, failureType!:String=""): String {
    p5ClassifierWithKnowledgeText(classifier, source, category, attempt, mode, "General reusable Rune guidance.",failureType:failureType)
}

private func p5ClassifierWithKnowledgeText(classifier: String, source: String, category: String, attempt: Int64, mode: String, knowledgeText: String, failureType!:String=""): String {
    let resultHash = cangjieEvalTriageResultEvidenceHash(p5Triage("\"suspectedKnowledgeGap\":true", 1,failureType:failureType))
    let request = "{\"schemaVersion\":\"ckb-p5-classifier-request-v1\",\"caseId\":\"CJ-HUMANEVAL-007\",\"runId\":\"run-001\",\"datasetVersion\":\"dataset-v1\",\"attempt\":1,\"runMode\":\"development\",\"resultEvidenceHash\":\"${resultHash}\",\"failureObservation\":\"CKB returned no reusable Rune guidance 中文😀\"}"
    let config = CkbP5ClassifierConfig(); config.label=source; config.classifierId=classifier; config.provider=source; config.model="model-${classifier}"; config.executable="/fake/${source}"
    let response = "{\"schemaVersion\":\"ckb-p5-classifier-response-v1\",\"observedProvider\":\"${source}\",\"observedModel\":\"model-${classifier}\",\"category\":\"${category}\",\"knowledgeFamily\":\"standard_library\",\"reusable\":true,\"sourceClass\":\"official\",\"citation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/\",\"purificationPassed\":true,\"canonicalKnowledgeId\":\"GENERAL-RUNE\",\"targetVersion\":\"1.0.0\",\"evidenceId\":\"official-rune-doc\",\"knowledgeText\":\"${knowledgeText}\"}"
    let artifact=sealCkbP5ClassifierResponse(request,response,config,"/tmp/${source}/workspace","/tmp/${source}/home","${source}-session")
    if(attempt==1&&mode=="development"){artifact}else{artifact.replace("\"attempt\":1","\"attempt\":${attempt}").replace("\"runMode\":\"development\"","\"runMode\":\"${mode}\"")}
}

private func p5Triage(signal: String, attempt: Int64,failureType!:String=""): String {
    let failureField=if(failureType==""){""}else{"\"failureType\":\"${failureType}\","}
    let raw = "{\"caseId\":\"CJ-HUMANEVAL-007\",\"runId\":\"run-001\",\"datasetVersion\":\"dataset-v1\",\"attempt\":${attempt},\"runMode\":\"development\",\"failureObservation\":\"observed 中文😀\",${failureField}${signal},\"resultEvidenceHash\":\"HASH\"}"
    raw.replace("HASH", cangjieEvalTriageResultEvidenceHash(raw))
}

private func s5ClosureInput(caseId:String,signal:String,failureType!:String=""):CangjieEvalDevelopmentClosureInput{
    let input=CangjieEvalDevelopmentClosureInput()
    input.caseResultJson="{\"caseId\":\"${caseId}\",\"runId\":\"run-s5\",\"datasetVersion\":\"dataset-v1\",\"runMode\":\"development\",\"workspaceId\":\"w-${caseId}\",\"sessionId\":\"s-${caseId}\",\"runtimeHomeId\":\"h-${caseId}\",\"developmentPass\":false,\"certificationPassAt1\":null}"
    let failureField=if(failureType==""){""}else{"\"failureType\":\"${failureType}\","}
    let raw="{\"caseId\":\"${caseId}\",\"runId\":\"run-s5\",\"datasetVersion\":\"dataset-v1\",\"attempt\":1,\"runMode\":\"development\",\"failureObservation\":\"sealed failure 中文🙂\",${failureField}${signal},\"resultEvidenceHash\":\"HASH\"}"
    input.resultEvidenceJson=raw.replace("HASH",cangjieEvalTriageResultEvidenceHash(raw))
    input.taskText="通用仓颉知识🙂";input.failureSummary="public failure";input
}

private func p5Closure(caseId: String, passed: Bool, category: String, confirmed: Bool): CangjieEvalDevelopmentCaseClosure {
    let item = CangjieEvalDevelopmentCaseClosure(); item.caseId = caseId; item.developmentPass = passed; item.category = category; item.route = routeNonKnowledgeFailure(category); item.knowledgeGapConfirmed = confirmed
    if (confirmed) { item.confirmationEvidenceHash = "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" }
    item
}

private func nkClassifier(caseId: String, label: String, category: String, studentHash!: String = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"): String {
    let provider = if (label == "a") { "codex" } else { "claude-code" }
    let model = if (label == "a") { "GPT-5.6-Sol" } else { "GLM-5.2" }
    let request = "{\"schemaVersion\":\"ckb-p5-classifier-request-v1\",\"caseId\":\"${caseId}\",\"runId\":\"run-nk\",\"datasetVersion\":\"dataset-v1\",\"attempt\":1,\"runMode\":\"development\",\"studentSourceHash\":\"${studentHash}\",\"resultEvidenceHash\":\"sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\",\"failureObservation\":\"public verifier mismatch 中文🙂\"}"
    let response = "{\"schemaVersion\":\"ckb-p5-classifier-response-v1\",\"observedProvider\":\"${provider}\",\"observedModel\":\"${model}\",\"category\":\"${category}\"}"
    let config = CkbP5ClassifierConfig(); config.label = label; config.classifierId = "nk-${caseId}-${label}"; config.provider = provider; config.model = model; config.executable = "/fake/nk-${label}"
    sealCkbP5ClassifierResponse(request, response, config, "/tmp/nk/${caseId}/${label}/workspace", "/tmp/nk/${caseId}/${label}/home", "nk-${caseId}-${label}")
}

private func nkClosure(caseId: String, confirmation: CangjieEvalKnowledgeGapConfirmation): CangjieEvalDevelopmentCaseClosure {
    let item = CangjieEvalDevelopmentCaseClosure(); item.caseId = caseId; item.category = confirmation.category; item.route = confirmation.route
    item.classifierFirstCategory = confirmation.firstCategory; item.classifierSecondCategory = confirmation.secondCategory
    item.nonKnowledgeRouteConfirmed = confirmation.confirmed && confirmation.category != "knowledge_gap"; item.routeEvidenceHash = if (item.nonKnowledgeRouteConfirmed) { confirmation.evidenceHash } else { "" }
    item
}

private func nkExpectAuditableCase(caseId: String, firstCategory: String, secondCategory: String): Unit {
    let confirmation = confirmIndependentClassifierPair(nkClassifier(caseId, "a", firstCategory), nkClassifier(caseId, "b", secondCategory))
    @Expect(confirmation.confirmed, true); @Expect(confirmation.route, "reasoning")
    let rendered = renderDevelopmentClosure(nkClosureList(nkClosure(caseId, confirmation)))
    @Expect(rendered.contains("\"caseId\":\"${caseId}\""), true); @Expect(rendered.contains("\"nonKnowledgeRouteConfirmed\":true"), true)
    @Expect(rendered.contains("\"classifierFirstCategory\":\"${firstCategory}\""), true); @Expect(rendered.contains("\"classifierSecondCategory\":\"${secondCategory}\""), true)
    @Expect(rendered.contains("\"valid\":true"), true); @Expect(rendered.contains("\"knowledgeCandidateCount\":0"), true)
}

private func nkClosureList(item: CangjieEvalDevelopmentCaseClosure): ArrayList<CangjieEvalDevelopmentCaseClosure> {
    let items = ArrayList<CangjieEvalDevelopmentCaseClosure>(); items.add(item); items
}
