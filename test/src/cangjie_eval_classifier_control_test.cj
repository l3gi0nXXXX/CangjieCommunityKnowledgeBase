package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.env.getVariable
import std.fs.{Directory, File, Path, exists, remove}
import std.process.launch
import std.time.DateTime
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.json.*

@Test
public class CangjieEvalClassifierControlTest {
    // S1-UT-01
    @TestCase
    public func completionFailureBuildsFromFrozenArtifacts():Unit{
        let root=Path("target/s1-failure-builder-${DateTime.now().toUnixTimeStamp().toMilliseconds()}")
        Directory.create(root,recursive:true)
        let caseId="CJ-HUMANEVAL-007";let runId="s1-run";let dataset="dataset-v1"
        let result="{\"runId\":\"${runId}\",\"caseId\":\"${caseId}\",\"datasetVersion\":\"${dataset}\",\"failureType\":\"test_failure\"}"
        File.writeTo(root.join("result-evidence.json"),(result+"\n").toArray())
        File.writeTo(root.join("canonical-task-context.json"),("{\"taskId\":\"${caseId}\",\"datasetVersion\":\"${dataset}\",\"taskText\":\"公开任务 中文😀\"}\n").toArray())
        File.writeTo(root.join("evaluation-outcome.json"),(renderCkbCompletionEvaluationOutcome(runId,caseId,"C-ckb-mcp-stdio",dataset,"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","failed","passed",benchmarkGapSha256(result))+"\n").toArray())
        File.writeTo(root.join("base-test.log"),"exception 中文😀\n/Users/private/hidden/TestMain.cj expected: secret".toArray())
        File.writeTo(root.join("plus-test.log"),"PASS".toArray())
        let built=buildCkbCompletionFailureFromArtifacts(root,caseId,runId)
        @Expect(built[1],"ok");@Expect(parseCkbCompletionFailure(renderCkbCompletionFailure(built[0]).toArray())[1],"ok")
        let rendered=renderCkbCompletionFailure(built[0]);@Expect(rendered.contains("中文😀"),true)
        @Expect(rendered.contains("/Users/"),false);@Expect(rendered.contains("TestMain.cj"),false)
        @Expect(rendered.toAsciiLower().contains("expected:"),false);@Expect(rendered.contains("solution.cj"),false)
    }

    // S1-BND-01
    @TestCase
    public func completionFailureSummaryBoundariesAreSafe():Unit{
        @Expect(ckbP5CompilerSummaryFromBytes([UInt8(0xff),UInt8(0xfe)],"test_failure"),"invalid_response_encoding")
        var long="";for(_ in 0..2000){long+="界😀"}
        let summary=ckbP5CompilerSummaryFromBytes(("exception 中文😀 "+long).toArray(),"test_failure")
        @Expect(summary.toRuneArray().size<=1024,true);@Expect(summary.contains("中文😀"),true)
        let redacted=ckbP5CompilerSummaryFromBytes("Authorization: Bearer secret\nassert public failure".toArray(),"test_failure")
        @Expect(redacted,"test_failure_detail_redacted");@Expect(redacted.toAsciiLower().contains("authorization"),false)
    }

    // S0-UT-01: the owner-specific v2 carrier seals and parses canonical bytes deterministically.
    @TestCase
    public func failureAssetV2CanonicalBytesMatchAcrossRepositories(): Unit {
        let fixture=s0FailureAssetFixture("classification-v2-valid.jsonl")
        @Expect(benchmarkGapSha256(fixture).replace("sha256:",""),
            CKB_COMPLETION_FAILURE_ASSET_CLASSIFICATION_FIXTURE_HASH)
        let lines=fixture.split("\n");@Expect(lines.size,12)
        for(i in 0..11){
            let parsed=parseCkbCompletionFailureAssetClassification(lines[i].toArray())
            @Expect(parsed[1],"ok")
            let originalHash=parsed[0].classificationEvidenceHash
            parsed[0].classificationEvidenceHash=""
            @Expect(sealCkbCompletionFailureAssetClassification(parsed[0]),"ok")
            @Expect(parsed[0].classificationEvidenceHash,originalHash)
            @Expect(renderCkbCompletionFailureAssetClassification(parsed[0]),lines[i])
        }
        let checks=s0FailureAssetFixture("SHA256SUMS").split("\n");@Expect(checks.size,20)
        for(i in 0..19){
            let columns=checks[i].split("  ");@Expect(columns.size,2)
            @Expect(columns[1].contains("/")||columns[1].contains(".."),false)
            @Expect(benchmarkGapSha256(s0FailureAssetFixture(columns[1])).replace("sha256:",""),columns[0])
        }
        @Expect(s0FailureAssetClosureDiagnostic(),"ok")
    }

    // S0-BND-01: v1 remains read-only compatible and bytes are decoded fail-close.
    @TestCase
    public func failureAssetV2BoundariesAreUtf8Safe(): Unit {
        let v1=s0FailureAssetFixture("classification-v1-compatibility.jsonl").split("\n")[0]
        let parsedV1=parseCkbCompletionFailureClassification(v1.toArray())
        @Expect(parsedV1[1],"ok")
        @Expect(ckbFailureAssetOutputKind(parsedV1[0]),"knowledge_skill")
        let invalidBytes=s0FailureAssetInvalidUtf8Bytes()
        @Expect(invalidBytes.size,2)
        @Expect(parseCkbCompletionFailureAssetClassification(invalidBytes)[1],
            "invalid_response_encoding")
        let row=CkbCompletionFailureAssetClassification()
        row.failureEvidenceHash=CKB_COMPLETION_FAILURE_FIXTURE_HASH
        row.gapKind="rules_gap";row.rulesEligible=true
        row.classificationReasonCode="missing_global_invariant"
        @Expect(sealCkbCompletionFailureAssetClassification(row),"ok")
        @Expect(parseCkbCompletionFailureAssetClassification(
            renderCkbCompletionFailureAssetClassification(row).toArray())[1],"ok")
        let failure=s0FailureAssetFixture("completion-failure-v1-utf8.json").split("\n")[0]
        @Expect(parseCkbCompletionFailure(failure.toArray())[1],"ok")
        @Expect(parseCkbCompletionFailure(failure.toArray())[0].failureObservation.contains("中文😀"),true)
    }

    // S0-POS-01: all eight visibility routes are exact.
    @TestCase
    public func failureAssetOutputKindsAreExact(): Unit {
        for ((knowledge,skill,rules,expected) in [
            (false,false,false,"none"),(true,false,false,"knowledge"),
            (false,true,false,"skill"),(false,false,true,"rules"),
            (true,true,false,"knowledge_skill"),(true,false,true,"knowledge_rules"),
            (false,true,true,"skill_rules"),(true,true,true,"all")]) {
            let row=CkbCompletionFailureAssetClassification()
            row.knowledgeEligible=knowledge;row.skillEligible=skill;row.rulesEligible=rules
            @Expect(ckbFailureAssetOutputKind(row),expected)
        }
    }

    // S0-NEG-01: schema, enum, eligibility, reason, hash, and JSON drift fail closed.
    @TestCase
    public func failureAssetV2RejectsContractDrift(): Unit {
        let row=CkbCompletionFailureAssetClassification()
        row.failureEvidenceHash=CKB_COMPLETION_FAILURE_FIXTURE_HASH
        row.gapKind="knowledge_gap";row.knowledgeEligible=true
        row.classificationReasonCode="missing_versioned_fact"
        @Expect(sealCkbCompletionFailureAssetClassification(row),"ok")
        let valid=renderCkbCompletionFailureAssetClassification(row)
        @Expect(parseCkbCompletionFailureAssetClassification(valid.replace(
            "\"schemaVersion\":", "\"unknown\":1,\"schemaVersion\":").toArray())[1],
            "classification_schema_fields_invalid")
        @Expect(parseCkbCompletionFailureAssetClassification(valid.replace(
            "\"gapKind\":\"knowledge_gap\"",
            "\"gapKind\":\"knowledge_gap\",\"gapKind\":\"knowledge_gap\"").toArray())[1],
            "classification_schema_fields_invalid")
        @Expect(parseCkbCompletionFailureAssetClassification(valid.replace(
            ",\"rulesEligible\":false", "").toArray())[1],"classification_schema_fields_invalid")
        @Expect(parseCkbCompletionFailureAssetClassification(valid.replace(
            "knowledge_gap","unknown_gap").toArray())[1],"classification_identity_invalid")
        @Expect(parseCkbCompletionFailureAssetClassification(valid.replace(
            "\"knowledgeEligible\":true","\"knowledgeEligible\":false").toArray())[1],
            "classification_eligibility_invalid")
        @Expect(parseCkbCompletionFailureAssetClassification(valid.replace(
            "missing_versioned_fact","multiple_reusable_gaps").toArray())[1],
            "classification_eligibility_invalid")
        @Expect(parseCkbCompletionFailureAssetClassification(valid.replace(
            row.classificationEvidenceHash,
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb").toArray())[1],
            "classification_evidence_hash_mismatch")
        @Expect(parseCkbCompletionFailureAssetClassification("{中文🙂".toArray())[1],"malformed_json")
        @Expect(parseCkbCompletionFailureAssetClassification((" "+valid).toArray())[1],
            "classification_schema_fields_invalid")
        let reordered=valid.replace(
            "\"schemaVersion\":\"ckb-completion-failure-classification-v2\",\"failureEvidenceHash\":",
            "\"failureEvidenceHash\":").replace(
            "{\"failureEvidenceHash\":",
            "{\"failureEvidenceHash\":").replace(
            "\"gapKind\":", "\"schemaVersion\":\"ckb-completion-failure-classification-v2\",\"gapKind\":")
        @Expect(parseCkbCompletionFailureAssetClassification(reordered.toArray())[1],
            "classification_schema_fields_invalid")
        let drifts=s0FailureAssetFixture("classification-v2-contract-drift.jsonl").split("\n")
        @Expect(drifts.size,8)
        for(i in 0..7){@Expect(parseCkbCompletionFailureAssetClassification(drifts[i].toArray())[1]=="ok",false)}
    }

    // P6-UT-01 / P6-POS-01: frozen cross-repository carrier and eligibility rules.
    @TestCase
    public func p6FrozenCompletionFailureFixtureIsByteExact(): Unit {
        let lines=ckbCompletionFailureFixtureJsonl().split("\n")
        @Expect(lines.size,3)
        let parsed=parseCkbCompletionFailure(lines[0].toArray())
        @Expect(parsed[1],"ok")
        @Expect(parsed[0].evidenceHash,CKB_COMPLETION_FAILURE_FIXTURE_HASH)
        @Expect(renderCkbCompletionFailure(parsed[0]),lines[0])
        let classification=CkbCompletionFailureClassification()
        classification.failureEvidenceHash=CKB_COMPLETION_FAILURE_FIXTURE_HASH
        classification.gapKind="mixed_gap";classification.knowledgeEligible=true;classification.skillEligible=true
        @Expect(sealCkbCompletionFailureClassification(classification),"ok")
        @Expect(classification.classificationEvidenceHash,CKB_COMPLETION_FAILURE_CLASSIFICATION_FIXTURE_HASH)
        @Expect(renderCkbCompletionFailureClassification(classification),lines[1])
    }

    // P6-BND-01 / P6-NEG-01: encoding, protected detail, tamper, and invalid eligibility fail closed.
    @TestCase
    public func p6CompletionFailureBoundaryAndNegativeCasesFailClosed(): Unit {
        @Expect(parseCkbCompletionFailure([UInt8(0xff),UInt8(0xfe)])[1],"invalid_response_encoding")
        let fixture=ckbCompletionFailureFixtureJsonl().split("\n")[0]
        @Expect(parseCkbCompletionFailure(fixture.replace("student_completion_test_failed 中文😀","Authorization: Bearer secret").toArray())[1],"protected_failure_observation")
        @Expect(parseCkbCompletionFailure(fixture.replace(CKB_COMPLETION_FAILURE_FIXTURE_HASH,"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb").toArray())[1],"failure_evidence_hash_mismatch")
        @Expect(parseCkbCompletionFailure(fixture.replace("\"runId\":", "\"unknown\":1,\"runId\":").toArray())[1],"failure_schema_fields_invalid")
        let invalid=CkbCompletionFailureClassification();invalid.failureEvidenceHash=CKB_COMPLETION_FAILURE_FIXTURE_HASH
        invalid.gapKind="reasoning_error";invalid.knowledgeEligible=true
        @Expect(sealCkbCompletionFailureClassification(invalid),"classification_eligibility_invalid")
    }

    // P5-C-UT-01
    @TestCase
    public func p5IcUt01SealedIndependentEvidenceBindsSchemaModelAndProvenance(): Unit {
        let env=ckbP5ClassifierProcessEnvironment("/private/运行库🙂:/secret-value",true);@Expect(env.size,1);@Expect(env[0].name,"DYLD_LIBRARY_PATH");@Expect(env[0].value,"/private/运行库🙂:/secret-value")
        @Expect(ckbP5ClassifierDyldDiagnostic("",true),"classifier_dyld_library_path_missing");@Expect(ckbP5ClassifierDyldDiagnostic("",false),"ok");@Expect(ckbP5ClassifierProcessEnvironment("",false).size,0)
        let request=p5IcRequest("CJ-HUMANEVAL-016");let a=p5IcConfig("a","codex","GPT-5.6-Sol");let b=p5IcConfig("b","claude-code","GLM-5.2")
        let first=sealCkbP5ClassifierResponse(request,p5IcResponse("codex","GPT-5.6-Sol"),a,"/tmp/p5-a/workspace","/tmp/p5-a/home","session-a")
        let second=sealCkbP5ClassifierResponse(request,p5IcResponse("claude-code","GLM-5.2"),b,"/tmp/p5-b/workspace","/tmp/p5-b/home","session-b")
        @Expect(first.contains("\"schemaVersion\":\"ckb-p5-classifier-v1\""),true)
        @Expect(first.contains("\"observedModel\":\"GPT-5.6-Sol\""),true)
        @Expect(first.contains("\"provenanceHash\":\"sha256:"),true)
        @Expect(first.contains("positiveTestPassed"),false)
        @Expect(first.contains("negativeTestPassed"),false)
        @Expect(first.contains("boundaryTestPassed"),false)
        @Expect(ckbP5ClassifierArtifactIdentityValid(first),true)
        @Expect(ckbP5ClassifierArtifactIdentityValid(second),true)
        @Expect(first==second,false)
        @Expect(confirmKnowledgeGap(first,second).confirmed,true)
        let alternateResponse=p5IcResponse("claude-code","GLM-5.2").replace("GENERAL-STRING-API","GENERAL-STRING-API-ALTERNATE").replace("General reusable String API guidance 中文🙂","Equivalent reusable String guidance with different wording 中文🙂")
        let alternate=sealCkbP5ClassifierResponse(request,alternateResponse,b,"/tmp/p5-b-alt/workspace","/tmp/p5-b-alt/home","session-b-alt")
        @Expect(alternate.isEmpty(),false);@Expect(ckbP5ClassifierArtifactIdentityValid(alternate),true)
        @Expect(alternate.contains(ckbP5ClassifierArtifactConsensusHash(alternate)),true)
        @Expect(ckbP5ClassifierArtifactEvidenceHash(first)==ckbP5ClassifierArtifactEvidenceHash(alternate),false)
        @Expect(ckbP5ClassifierArtifactConsensusHash(first)==ckbP5ClassifierArtifactConsensusHash(alternate),false)
        @Expect(confirmKnowledgeGap(first,alternate).confirmed,true)
        let familyMismatch=sealCkbP5ClassifierResponse(request,alternateResponse.replace("standard_library","syntax"),b,"/tmp/p5-b-family/workspace","/tmp/p5-b-family/home","session-b-family")
        @Expect(confirmKnowledgeGap(first,familyMismatch).confirmed,true)
        let citationMismatch=sealCkbP5ClassifierResponse(request,alternateResponse.replace("https://docs.cangjie-lang.cn/docs/1.0.0/","https://docs.cangjie-lang.cn/docs/other/"),b,"/tmp/p5-b-citation/workspace","/tmp/p5-b-citation/home","session-b-citation")
        @Expect(confirmKnowledgeGap(first,citationMismatch).confirmed,true)
        let targetMismatch=sealCkbP5ClassifierResponse(request,alternateResponse.replace("\"targetVersion\":\"1.0.0\"","\"targetVersion\":\"1.0.1\""),b,"/tmp/p5-b-target/workspace","/tmp/p5-b-target/home","session-b-target")
        @Expect(confirmKnowledgeGap(first,targetMismatch).diagnostic,"classifier_semantic_disagreement")
        let sourceMismatchRequest=request.replace("sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        let sourceMismatch=sealCkbP5ClassifierResponse(sourceMismatchRequest,p5IcResponse("claude-code","GLM-5.2"),b,"/tmp/p5-b-source/workspace","/tmp/p5-b-source/home","session-b-source")
        @Expect(confirmKnowledgeGap(first,sourceMismatch).diagnostic,"classifier_semantic_disagreement")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(request,"{\"schemaVersion\":\"ckb-p5-classifier-response-v1\"}",a,"/tmp/p5-a/workspace","/tmp/p5-a/home","session-a")[1],"classifier_response_incomplete")
        let retrievalA=sealCkbP5ClassifierResponse(request,p5IcResponse("codex","GPT-5.6-Sol").replace("knowledge_gap","retrieval_failure"),a,"/tmp/p5-a2/workspace","/tmp/p5-a2/home","session-a2")
        let retrievalB=sealCkbP5ClassifierResponse(request,p5IcResponse("claude-code","GLM-5.2").replace("knowledge_gap","retrieval_failure"),b,"/tmp/p5-b2/workspace","/tmp/p5-b2/home","session-b2")
        let nonKnowledge=confirmIndependentClassifierPair(retrievalA,retrievalB)
        @Expect(nonKnowledge.confirmed,true);@Expect(nonKnowledge.category,"retrieval_failure");@Expect(routeNonKnowledgeFailure(nonKnowledge.category),"retrieval")
        @Expect(confirmKnowledgeGap(retrievalA,retrievalB).confirmed,false)
    }

    @TestCase
    public func p5IcBnd01UnicodeRestrictedRequestAndInvalidUtf8FailClosed(): Unit {
        let root=p5IcRoot("unicode");let caseRoot=p5IcSample(root,"CJ-HUMANEVAL-016","error: 编译错误🙂")
        let request=buildCkbP5ClassifierRequest(caseRoot,"CJ-HUMANEVAL-016","run-中文🙂")
        @Expect(request.contains("编译错误🙂"),true)
        @Expect(request.contains("studentSourceExcerpt"),true);@Expect(request.contains("学生源码🙂"),true);@Expect(request.contains("\"studentSourceHash\":\"sha256:"),true)
        @Expect(request.contains("canonical_solution"),false)
        @Expect(request.contains("teacher-solutions"),false)
        @Expect(request.contains("hidden_test"),false)
        let validCaseResult=String.fromUtf8(File.readFrom(caseRoot.join("case-result.json")))
        File.writeTo(caseRoot.join("case-result.json"),validCaseResult.replace("h342434","h999999").toArray())
        @Expect(buildCkbP5ClassifierRequest(caseRoot,"CJ-HUMANEVAL-016","run-中文🙂"),"retrieval_evidence_binding_invalid")
        File.writeTo(caseRoot.join("case-result.json"),validCaseResult.toArray())
        File.writeTo(caseRoot.join("result-evidence.json"),[UInt8(0xff),UInt8(0xfe)])
        @Expect(buildCkbP5ClassifierRequest(caseRoot,"CJ-HUMANEVAL-016","run-中文🙂"),"missing_case_evidence")
        let unitRoot=p5IcRoot("unit-summary");let unitCase=p5IcSample(unitRoot,"CJ-HUMANEVAL-065","Exception: failure: expected 001, actual 484849 中文🙂\n at /private/user/path token=secret",failureType:"test_failure")
        let unitRequest=buildCkbP5ClassifierRequest(unitCase,"CJ-HUMANEVAL-065","run-中文🙂")
        @Expect(unitRequest.contains("expected 001, actual 484849 中文🙂"),true)
        @Expect(unitRequest.contains("/private/user/path"),false);@Expect(unitRequest.contains("token=secret"),false)
        let compilerRoot=p5IcRoot("compiler-summary");let longDetailBuilder=StringBuilder();for(_ in 0..300){longDetailBuilder.append("边界🙂")};let longDetail=longDetailBuilder.toString()
        let compilerLog="\u{001b}[31merror\u{001b}[0m: mismatched types\n  \u{001b}[36m==>\u{001b}[0m /Users/private/项目🙂/solution.cj:35:5:\n   | _____^ expected 'Float64', found 'Unit' 中文🙂 ${longDetail}\nAuthorization: secret\n/private/token=secret"
        let compilerCase=p5IcSample(compilerRoot,"CJ-HUMANEVAL-032",compilerLog)
        let compilerRequest=buildCkbP5ClassifierRequest(compilerCase,"CJ-HUMANEVAL-032","run-中文🙂")
        @Expect(compilerRequest.contains("location solution.cj:35:5:"),true)
        @Expect(compilerRequest.contains("expected 'Float64', found 'Unit' 中文🙂"),true)
        @Expect(compilerRequest.contains("/Users/private"),false);@Expect(compilerRequest.toAsciiLower().contains("authorization:"),false);@Expect(compilerRequest.contains("token=secret"),false)
        @Expect(compilerRequest.contains(longDetail),false)
        File.writeTo(compilerCase.join("test.log"),[UInt8(0xff),UInt8(0xfe)])
        let invalidLogRequest=buildCkbP5ClassifierRequest(compilerCase,"CJ-HUMANEVAL-032","run-中文🙂")
        @Expect(invalidLogRequest.startsWith("{"),true);@Expect(invalidLogRequest.contains("compilerTestSummary\":\"\""),true)
    }

    // FCS-UT-01 / FCS-BND-01 / FCS-POS-01 / FCS-NEG-01 / FCS-E2E-01
    @TestCase
    public func classifierUsesFirstCompleteSampleAfterTransportFailures(): Unit {
        let root=p5IcRoot("first-complete-sample")
        let attempts="{\"attempt\":1,\"transportAttempt\":1,\"sampleAttempt\":0,\"exitCode\":1,\"completeResult\":false,\"identityMatched\":false,\"workspaceRestored\":false,\"restoreEvidenceHash\":\"\"}\n"+
            "{\"attempt\":2,\"transportAttempt\":2,\"sampleAttempt\":1,\"exitCode\":0,\"completeResult\":true,\"identityMatched\":true,\"workspaceRestored\":true,\"restoreEvidenceHash\":\"sha256:87add9cd09364be8c23d789965b3019bea6a20dc45e6bc970641fa0ab1dd5293\"}\n"
        let caseRoot=p5IcTransportRetrySample(root,"CJ-HUMANEVAL-145",2,1,attempts)
        let request=buildCkbP5ClassifierRequest(caseRoot,"CJ-HUMANEVAL-145","run-中文🙂")
        @Expect(request.startsWith("{"),true)
        @Expect(request.contains("\"attempt\":1"),true)
        @Expect(request.contains("\"sourceTransportAttempt\":2"),true)
        @Expect(request.contains("expected -1, actual 1 中文🙂"),true)

        let output="${root}/classifier-output"
        let run=runCkbP5IndependentClassifiers(root,"run-中文🙂","C",output,
            p5IcExecutableConfig("a","codex","GPT-5.6-Sol",p5IcFake(root,"fake-fcs-a.sh","reasoning")),
            p5IcExecutableConfig("b","claude-code","GLM-5.2",p5IcFake(root,"fake-fcs-b.sh","unit")),10)
        @Expect(run.ok,true);@Expect(run.processed,1);@Expect(run.paired,1);@Expect(run.rejected,0)

        let boundaryRoot=p5IcRoot("first-complete-boundary")
        let boundaryAttempts="{\"attempt\":1,\"transportAttempt\":1,\"sampleAttempt\":0,\"exitCode\":124,\"completeResult\":false,\"identityMatched\":false,\"workspaceRestored\":false,\"restoreEvidenceHash\":\"\"}\n"+
            "{\"attempt\":2,\"transportAttempt\":2,\"sampleAttempt\":0,\"exitCode\":1,\"completeResult\":false,\"identityMatched\":false,\"workspaceRestored\":true,\"restoreEvidenceHash\":\"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"}\n"+
            "{\"attempt\":3,\"transportAttempt\":3,\"sampleAttempt\":1,\"exitCode\":0,\"completeResult\":true,\"identityMatched\":true,\"workspaceRestored\":true,\"restoreEvidenceHash\":\"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}\n"
        let boundaryCase=p5IcTransportRetrySample(boundaryRoot,"CJ-HUMANEVAL-145",3,1,boundaryAttempts)
        @Expect(buildCkbP5ClassifierRequest(boundaryCase,"CJ-HUMANEVAL-145","run-中文🙂").startsWith("{"),true)

        let twoSamplesRoot=p5IcRoot("two-complete-samples")
        let twoSamples=attempts+"{\"attempt\":3,\"transportAttempt\":3,\"sampleAttempt\":2,\"exitCode\":0,\"completeResult\":true,\"identityMatched\":true,\"workspaceRestored\":true,\"restoreEvidenceHash\":\"sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\"}\n"
        let twoSamplesCase=p5IcTransportRetrySample(twoSamplesRoot,"CJ-HUMANEVAL-145",3,2,twoSamples)
        @Expect(buildCkbP5ClassifierRequest(twoSamplesCase,"CJ-HUMANEVAL-145","run-中文🙂"),"first_complete_development_sample_required")

        let mismatchRoot=p5IcRoot("transport-count-mismatch")
        let mismatchCase=p5IcTransportRetrySample(mismatchRoot,"CJ-HUMANEVAL-145",3,1,attempts)
        @Expect(buildCkbP5ClassifierRequest(mismatchCase,"CJ-HUMANEVAL-145","run-中文🙂"),"first_complete_development_sample_required")

        let missingRoot=p5IcRoot("transport-attempts-missing")
        let missingCase=p5IcTransportRetrySample(missingRoot,"CJ-HUMANEVAL-145",2,1,attempts)
        _=remove(missingCase.join("claude-attempts.jsonl"))
        @Expect(buildCkbP5ClassifierRequest(missingCase,"CJ-HUMANEVAL-145","run-中文🙂"),"first_complete_development_sample_required")
    }

    // P5-C-UT-02 / P5-C-BND-02 / P5-C-POS-02 / P5-C-NEG-02
    @TestCase
    public func p5IcSourceFactsRejectUnsupportedAbsImportPrerequisite(): Unit {
        let config=p5IcConfig("a","codex","GPT-5.6-Sol")
        let request=p5IcAbsRequest("CASE-GENERIC-UTF8-🙂","main(): Unit { let value: Float64 = -3.5; println(value.abs()) }",
            "error: undeclared identifier 'abs' 中文🙂")
        let globalAbs=p5IcResponse("codex","GPT-5.6-Sol").replace("General reusable String API guidance 中文🙂",
            "Float64 absolute value uses the global abs(value) function, not a receiver .abs() member.")
        let allowed=sealCkbP5ClassifierResponseWithDiagnostic(request,globalAbs,config,"/tmp/p5-fact-ok/workspace","/tmp/p5-fact-ok/home","session-fact-ok")
        @Expect(allowed[0].isEmpty(),false);@Expect(allowed[1],"ok")

        let unsupported=globalAbs.replace("Float64 absolute value uses the global abs(value) function, not a receiver .abs() member.",
            "Float64 requires import std.math.* before calling the global abs(value) function instead of .abs().")
        let rejected=sealCkbP5ClassifierResponseWithDiagnostic(request,unsupported,config,"/tmp/p5-fact-bad/workspace","/tmp/p5-fact-bad/home","session-fact-bad")
        @Expect(rejected[0],"");@Expect(rejected[1],"classifier_response_source_fact_unsupported")
        let unsupportedFromPackage=globalAbs.replace("Float64 absolute value uses the global abs(value) function, not a receiver .abs() member.",
            "The correct approach requires using a function from std.math, for example importing std.math.* before global abs(value).")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(request,unsupportedFromPackage,config,"/tmp/p5-fact-package/workspace","/tmp/p5-fact-package/home","session-fact-package")[1],"classifier_response_source_fact_unsupported")

        let evidencedRequest=p5IcAbsRequest("CASE-GENERIC-EVIDENCED","import std.math.*\nmain(): Unit { let value: Float64 = -3.5; println(value.abs()) }",
            "error: undeclared identifier 'abs' after import std.math.*")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(evidencedRequest,unsupported,config,"/tmp/p5-fact-evidenced/workspace","/tmp/p5-fact-evidenced/home","session-fact-evidenced")[1],"classifier_response_source_fact_unsupported")

        let explicitNoImport=globalAbs.replace("Float64 absolute value uses the global abs(value) function, not a receiver .abs() member.",
            "The global abs(value) function replaces receiver .abs(); std.math import is unnecessary and not required.")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(request,explicitNoImport,config,"/tmp/p5-fact-no-import/workspace","/tmp/p5-fact-no-import/home","session-fact-no-import")[1],"ok")

        let unrelated=p5IcAbsRequest("CASE-GENERIC-OTHER","main(): Unit { let value: Float64 = -3.5; println(value.abs()) }",
            "error: undeclared identifier 'otherApi'")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(unrelated,unsupported,config,"/tmp/p5-fact-other/workspace","/tmp/p5-fact-other/home","session-fact-other")[1],"ok")
        let nonKnowledge=unsupported.replace("\"category\":\"knowledge_gap\"","\"category\":\"compile_error\"")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(request,nonKnowledge,config,"/tmp/p5-fact-non/workspace","/tmp/p5-fact-non/home","session-fact-non")[1],"ok")
    }

    // CLASSIFIER-016-FACT-UT/BND/POS/NEG: request-aware String casing facts fail closed.
    @TestCase
    public func p5IcStringCasingSourceFactsMatchDocumentedReceiversAndImports(): Unit {
        let config=p5IcConfig("a","codex","GPT-5.6-Sol")
        let request=p5IcAbsRequest("CJ-HUMANEVAL-016",
            "public func solve(string: String): String { for (c in string.toLower()) { println(c) }; string }",
            "error: 'toLower' is not a member of struct 'String' 中文🙂").replace(
                "\"runMode\":\"development\",","\"runMode\":\"development\",\"taskText\":\"Count distinct characters regardless of case. 统计不区分大小写的不同字符。\",")
        let base=p5IcResponse("codex","GPT-5.6-Sol")
        let ascii=base.replace("General reusable String API guidance 中文🙂",
            "String.toAsciiLower() returns an ASCII-only lowercase String; non-ASCII 中文🙂 is unchanged.")
        let runeAscii=base.replace("General reusable String API guidance 中文🙂",
            "Direct String iteration yields UInt8. Convert with string.runes(), then use the core Rune.toAsciiLowerCase() for ASCII-only casing.")
        let unicode=base.replace("General reusable String API guidance 中文🙂",
            "Unicode casing requires import std.unicode.* and conversion through runes(), then Rune.toLowerCase() returns a Rune.")
        let v3Importing=base.replace("General reusable String API guidance 中文🙂",
            "In Cangjie 1.0.0, direct String iteration yields UInt8 bytes. String.toAsciiLower() returns a String and performs ASCII-only casing. Rune.toAsciiLowerCase() returns a Rune and is also ASCII-only. Unicode casing requires importing std.unicode.*, after which Rune.toLowerCase() returns a Rune. String.toLower() is unavailable, and toLowerAscii is not a Cangjie API.")
        let v4InlineImport=base.replace("General reusable String API guidance 中文🙂",
            "In Cangjie 1.0.0, direct String iteration yields UInt8 bytes. String.toAsciiLower() returns a String and performs ASCII-only lowercasing. Rune.toAsciiLowerCase() returns a Rune and is also ASCII-only. Unicode casing requires `import std.unicode.*`; Rune.toLowerCase() returns a Rune. String.toLower() is unavailable, and toLowerAscii is not a Cangjie API.")
        for((label,response) in [("v3-importing",v3Importing),("v4-inline-import",v4InlineImport)]){
            let result=sealCkbP5ClassifierResponseWithDiagnostic(request,response,config,"/tmp/p5-case-${label}/workspace","/tmp/p5-case-${label}/home","session-${label}")
            @Expect(result[0].isEmpty(),false);@Expect(result[1],"ok")
        }

        let oldV1=base.replace("General reusable String API guidance 中文🙂",
            "Iterate over the String's Runes, for (c in string) yielding Rune values, and convert each Rune using Rune.toLowerAscii().")
        let directRune=base.replace("General reusable String API guidance 中文🙂",
            "Direct String iteration yields Rune values; use each Rune for comparison.")
        let nonexistentString=base.replace("General reusable String API guidance 中文🙂",
            "String.toLower() is available and should be used for lowercase conversion.")
        let unicodeWithoutImport=base.replace("General reusable String API guidance 中文🙂",
            "For Unicode lowercase conversion call Rune.toLowerCase() on every Rune.")
        let wrongReceivers=base.replace("General reusable String API guidance 中文🙂",
            "Use String.toAsciiLowerCase() or Rune.toAsciiLower() for ASCII casing.")
        let importMention=base.replace("General reusable String API guidance 中文🙂",
            "Unicode casing mentions std.unicode.* and Rune.toLowerCase() returns a Rune; String.toLower() is unavailable.")
        let afterImport=base.replace("General reusable String API guidance 中文🙂",
            "After import std.unicode.*, Rune.toLowerCase() returns a Rune; String.toLower() is unavailable.")
        let inlineMention=base.replace("General reusable String API guidance 中文🙂",
            "Unicode casing mentions `std.unicode.*`; Rune.toLowerCase() returns a Rune; String.toLower() is unavailable.")
        let inlineAfterImport=base.replace("General reusable String API guidance 中文🙂",
            "After `import std.unicode.*`, Rune.toLowerCase() returns a Rune; String.toLower() is unavailable.")
        let falseNegativeApi=base.replace("General reusable String API guidance 中文🙂",
            "Unicode casing requires import std.unicode.* and Rune.toLowerCase() returns a Rune. toLowerAscii is not a Cangjie API, but use toLowerAscii for compatibility.")
        let commentDisguise=base.replace("General reusable String API guidance 中文🙂",
            "Unicode casing requires import std.unicode.*; // Rune.toLowerCase() returns a Rune. toLowerAscii is not a Cangjie API.")
        let completeText="In Cangjie 1.0.0, direct String iteration yields UInt8 bytes. String.toAsciiLower() returns a String and performs ASCII-only casing. Rune.toAsciiLowerCase() returns a Rune and is also ASCII-only. Unicode casing requires importing std.unicode.*, after which Rune.toLowerCase() returns a Rune. String.toLower() is unavailable, and toLowerAscii is not a Cangjie API."
        let genericHashSet=base.replace("General reusable String API guidance 中文🙂",completeText+" HashSet is a general collection type.")
        let goalWithoutStrategy=base.replace("General reusable String API guidance 中文🙂",completeText+" Character casing is relevant when counting distinct characters regardless of case.")
        for((label,response) in [("generic-hashset",genericHashSet),("goal-without-strategy",goalWithoutStrategy)]){
            let result=sealCkbP5ClassifierResponseWithDiagnostic(request,response,config,"/tmp/p5-case-safe-${label}/workspace","/tmp/p5-case-safe-${label}/home","session-safe-${label}")
            @Expect(result[0].isEmpty(),false);@Expect(result[1],"ok")
        }
        let solutionLeak=base.replace("General reusable String API guidance 中文🙂",completeText+" When counting distinct characters case-insensitively, iterate over the String as Runes, normalize case, and collect into a HashSet<Rune>.")
        let solutionLeakChinese=base.replace("General reusable String API guidance 中文🙂",completeText+" 统计不区分大小写的不同字符时，遍历字符并收集到 HashSet<Rune>。中文🙂")
        let solutionLeakWordPile=base.replace("General reusable String API guidance 中文🙂",completeText+" count distinct character case-insensitive HashSet collect loop")
        let solutionLeakComment=base.replace("General reusable String API guidance 中文🙂",completeText+" // Count distinct characters regardless of case with a HashSet.")
        let noIteration=base.replace("General reusable String API guidance 中文🙂",completeText.replace("direct String iteration yields UInt8 bytes. ",""))
        let noStringAscii=base.replace("General reusable String API guidance 中文🙂",completeText.replace("String.toAsciiLower() returns a String and performs ASCII-only casing. ",""))
        let noRuneAscii=base.replace("General reusable String API guidance 中文🙂",completeText.replace("Rune.toAsciiLowerCase() returns a Rune and is also ASCII-only. ",""))
        let crossClauseString=base.replace("General reusable String API guidance 中文🙂",completeText.replace(
            "String.toAsciiLower() returns a String and performs ASCII-only casing.","String.toAsciiLower() performs ASCII-only casing. Another conversion returns a String."))
        let crossClauseRune=base.replace("General reusable String API guidance 中文🙂",completeText.replace(
            "Rune.toAsciiLowerCase() returns a Rune and is also ASCII-only.","Rune.toAsciiLowerCase() performs ASCII-only casing. Another conversion returns a Rune."))
        let noUnicodeImport=base.replace("General reusable String API guidance 中文🙂",completeText.replace("Unicode casing requires importing std.unicode.*, after which ","For Unicode casing, "))
        let noUnicodeRune=base.replace("General reusable String API guidance 中文🙂",completeText.replace("Rune.toLowerCase() returns a Rune. ",""))
        let noUnicodeReturn=base.replace("General reusable String API guidance 中文🙂",completeText.replace("Rune.toLowerCase() returns a Rune.","Rune.toLowerCase() performs Unicode lowercasing."))
        let noInvalidNegative=base.replace("General reusable String API guidance 中文🙂",completeText.replace("String.toLower() is unavailable, and toLowerAscii is not a Cangjie API.",""))
        let completeComment=base.replace("General reusable String API guidance 中文🙂",completeText.replace("Rune.toLowerCase() returns a Rune.","// Rune.toLowerCase() returns a Rune."))
        let wordPile=base.replace("General reusable String API guidance 中文🙂","string uint8 string.toasciilower rune.toasciilowercase unicode std.unicode rune.tolowercase string.tolower unavailable tolowerascii not api")
        for((label,response,diagnostic) in [("ascii-partial",ascii,"classifier_string_case_iteration_uint8_missing"),
            ("rune-ascii-partial",runeAscii,"classifier_string_case_string_ascii_api_missing"),
            ("unicode-partial",unicode,"classifier_string_case_iteration_uint8_missing"),
            ("no-iteration",noIteration,"classifier_string_case_iteration_uint8_missing"),
            ("no-string-ascii",noStringAscii,"classifier_string_case_string_ascii_api_missing"),
            ("cross-clause-string",crossClauseString,"classifier_string_case_string_ascii_api_missing"),
            ("no-rune-ascii",noRuneAscii,"classifier_string_case_rune_ascii_api_missing"),
            ("cross-clause-rune",crossClauseRune,"classifier_string_case_rune_ascii_api_missing"),
            ("no-unicode-import",noUnicodeImport,"classifier_string_case_unicode_import_missing"),
            ("no-unicode-rune",noUnicodeRune,"classifier_string_case_unicode_rune_api_missing"),
            ("no-unicode-return",noUnicodeReturn,"classifier_string_case_unicode_return_type_missing"),
            ("no-invalid-negative",noInvalidNegative,"classifier_string_case_invalid_api_negative_missing"),
            ("old-v1",oldV1,"classifier_string_case_contradictory"),("direct-rune",directRune,"classifier_string_case_contradictory"),
            ("string-tolower",nonexistentString,"classifier_string_case_contradictory"),
            ("wrong-receivers",wrongReceivers,"classifier_string_case_contradictory"),
            ("false-negative-api",falseNegativeApi,"classifier_string_case_contradictory"),
            ("solution-leak",solutionLeak,"classifier_string_case_solution_leakage"),
            ("solution-leak-chinese",solutionLeakChinese,"classifier_string_case_solution_leakage"),
            ("solution-leak-word-pile",solutionLeakWordPile,"classifier_string_case_solution_leakage"),
            ("solution-leak-comment",solutionLeakComment,"classifier_string_case_comment_disguised"),
            ("word-pile",wordPile,"classifier_string_case_iteration_uint8_missing"),
            ("comment-disguise",commentDisguise,"classifier_string_case_comment_disguised"),
            ("complete-comment",completeComment,"classifier_string_case_comment_disguised")]){
            let result=sealCkbP5ClassifierResponseWithDiagnostic(request,response,config,"/tmp/p5-case-bad-${label}/workspace","/tmp/p5-case-bad-${label}/home","session-bad-${label}")
            @Expect(result[0],"");@Expect(result[1],diagnostic)
        }

        for((label,response) in [("legacy-unicode-no-import",unicodeWithoutImport),("legacy-import-mention",importMention),
            ("legacy-after-import",afterImport),("legacy-inline-mention",inlineMention),("legacy-inline-after-import",inlineAfterImport)]){
            let result=sealCkbP5ClassifierResponseWithDiagnostic(request,response,config,"/tmp/p5-case-legacy-${label}/workspace","/tmp/p5-case-legacy-${label}/home","session-legacy-${label}")
            @Expect(result[0],"");@Expect(result[1],"classifier_string_case_iteration_uint8_missing")
        }

        let unrelated=p5IcAbsRequest("CJ-HUMANEVAL-018",
            "public func solve(string: String): String { string }","error: unrelated member 中文🙂")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(unrelated,oldV1,config,"/tmp/p5-case-other/workspace","/tmp/p5-case-other/home","session-other")[1],"ok")
        let nonGoal=p5IcAbsRequest("CASE-STRING-DISPLAY",
            "public func solve(string: String): String { for (c in string.toLower()) { println(c) }; string }",
            "error: 'toLower' is not a member of struct 'String' 中文🙂").replace(
                "\"runMode\":\"development\",","\"runMode\":\"development\",\"taskText\":\"Convert a String to lowercase for display.\",")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(nonGoal,solutionLeak,config,"/tmp/p5-case-non-goal/workspace","/tmp/p5-case-non-goal/home","session-non-goal")[1],"ok")
        let nonKnowledge=oldV1.replace("\"category\":\"knowledge_gap\"","\"category\":\"reasoning_failure\"")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(request,nonKnowledge,config,"/tmp/p5-case-non/workspace","/tmp/p5-case-non/home","session-non")[1],"ok")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(request,"{",config,"/tmp/p5-case-malformed/workspace","/tmp/p5-case-malformed/home","session-malformed")[1],"classifier_response_malformed")
        let leaking=ascii.replace("ASCII-only lowercase String","ASCII-only lowercase String token=secret /Users/private/秘密🙂")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(request,leaking,config,"/tmp/p5-case-leak/workspace","/tmp/p5-case-leak/home","session-leak")[1],"classifier_response_forbidden_content")
    }

    // CLASSIFIER-018-FACT-UT/BND/POS/NEG: plain keywords and raw identifiers have distinct legality.
    @TestCase
    public func p5IcReservedKeywordFactsRequireRawIdentifierBoundary(): Unit {
        let config=p5IcConfig("a","codex","GPT-5.6-Sol")
        let request=p5IcAbsRequest("CJ-HUMANEVAL-018",
            "public func solve(values: Array<Int64>): Int64 { var match = 0; match }",
            "error: expected identifier or pattern after 'var', found keyword 'match'\nhelp: escape the keyword `match` to use it as an identifier 中文🙂")
        let base=p5IcResponse("codex","GPT-5.6-Sol")
        let complete=base.replace("General reusable String API guidance 中文🙂",
            "Using the reserved keyword match directly as a plain variable identifier is invalid. The raw identifier `match` is legal in Cangjie; alternatively, rename it to a non-keyword identifier such as matchedCount 中文🙂.")
        let equivalent=base.replace("General reusable String API guidance 中文🙂",
            "An unescaped match cannot be used directly as an ordinary identifier because it is a keyword. The escaped identifier `match` is allowed, and renaming it to a different non-keyword variable is also valid.")
        let v3Exact=base.replace("General reusable String API guidance 中文🙂",
            "In Cangjie 1.0, `match` is invalid as a plain identifier because it is a keyword. The backtick form `match` is a legal raw identifier; alternatively, rename it to a non-keyword name.")
        let regularEquivalent=base.replace("General reusable String API guidance 中文🙂",
            "The reserved keyword `match` is illegal as a regular identifier. Raw identifier `match` is valid; renaming it to a non-keyword variable is valid.")
        for((label,response) in [("complete",complete),("equivalent",equivalent),("v3-exact",v3Exact),("regular-equivalent",regularEquivalent)]){
            let result=sealCkbP5ClassifierResponseWithDiagnostic(request,response,config,"/tmp/p5-keyword-${label}/workspace","/tmp/p5-keyword-${label}/home","session-keyword-${label}")
            @Expect(result[0].isEmpty(),false);@Expect(result[1],"ok")
        }

        let absolute=base.replace("General reusable String API guidance 中文🙂",
            "The reserved keyword match can never be used as an identifier under any circumstances; rename it to a non-keyword identifier.")
        let v1A=base.replace("General reusable String API guidance 中文🙂",
            "Cangjie reserves `match` for match expressions, so it cannot be used as a local variable identifier.")
        let v1B=base.replace("General reusable String API guidance 中文🙂",
            "In Cangjie, `match` is a reserved keyword and cannot be used as a variable name or identifier; choose another name.")
        let missingRaw=base.replace("General reusable String API guidance 中文🙂",
            "Using the reserved keyword match directly as a plain variable identifier is invalid; rename it to a non-keyword identifier.")
        let rawWithoutLegality=base.replace("General reusable String API guidance 中文🙂",
            "Using match directly as a plain identifier is invalid. Raw identifier syntax is `match`; rename to a non-keyword variable.")
        let missingPlainBoundary=base.replace("General reusable String API guidance 中文🙂",
            "The raw identifier `match` is legal, and renaming it to a non-keyword variable is valid.")
        let missingRename=base.replace("General reusable String API guidance 中文🙂",
            "Using the reserved keyword match directly as a plain variable identifier is invalid. The raw identifier `match` is legal in Cangjie.")
        let wordSalad=base.replace("General reusable String API guidance 中文🙂",
            "plain match keyword invalid raw identifier `match` legal rename non-keyword valid 中文🙂")
        let commentDisguise=base.replace("General reusable String API guidance 中文🙂",
            "Using the reserved keyword match directly as a plain variable identifier is invalid; rename it to a non-keyword identifier. // The raw identifier `match` is legal.")
        let contradictory=complete.replace("Using the reserved keyword match directly as a plain variable identifier is invalid.",
            "The reserved keyword match can never be used as an identifier under any circumstances.")
        for((label,response,diagnostic) in [("absolute",absolute,"classifier_reserved_match_contradictory"),
            ("v1-a",v1A,"classifier_reserved_match_contradictory"),("v1-b",v1B,"classifier_reserved_match_contradictory"),
            ("missing-raw",missingRaw,"classifier_reserved_match_raw_missing"),("raw-no-legality",rawWithoutLegality,"classifier_reserved_match_raw_missing"),
            ("missing-plain",missingPlainBoundary,"classifier_reserved_match_plain_missing"),("missing-rename",missingRename,"classifier_reserved_match_rename_missing"),
            ("word-salad",wordSalad,"classifier_reserved_match_plain_missing"),("comment-disguise",commentDisguise,"classifier_reserved_match_comment_disguised"),
            ("contradictory",contradictory,"classifier_reserved_match_contradictory")]){
            let result=sealCkbP5ClassifierResponseWithDiagnostic(request,response,config,"/tmp/p5-keyword-bad-${label}/workspace","/tmp/p5-keyword-bad-${label}/home","session-keyword-bad-${label}")
            @Expect(result[0],"");@Expect(result[1],diagnostic)
        }

        let unrelated=p5IcAbsRequest("CJ-HUMANEVAL-018","public func solve(): Int64 { var found = 0; found }",
            "error: expected expression after '=' 中文🙂")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(unrelated,missingRaw,config,"/tmp/p5-keyword-other/workspace","/tmp/p5-keyword-other/home","session-keyword-other")[1],"ok")
        let nonKnowledge=missingRaw.replace("\"category\":\"knowledge_gap\"","\"category\":\"reasoning_failure\"")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(request,nonKnowledge,config,"/tmp/p5-keyword-non/workspace","/tmp/p5-keyword-non/home","session-keyword-non")[1],"ok")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(request,"{",config,"/tmp/p5-keyword-malformed/workspace","/tmp/p5-keyword-malformed/home","session-keyword-malformed")[1],"classifier_response_malformed")
        let leaking=complete.replace("non-keyword identifier","non-keyword identifier token=secret /Users/private/秘密🙂")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(request,leaking,config,"/tmp/p5-keyword-leak/workspace","/tmp/p5-keyword-leak/home","session-keyword-leak")[1],"classifier_response_forbidden_content")
    }

    // P5-C-E2E-01
    @TestCase
    public func p5IcPos01TwoFakeProcessesProduceAnInjectableIndependentPair(): Unit {
        let root=p5IcRoot("positive");_=p5IcSample(root,"CJ-HUMANEVAL-016","error: String member missing 中文🙂")
        let fakeA=p5IcFake(root,"fake-a.sh","ok");let fakeB=p5IcFake(root,"fake-b.sh","ok")
        let output="${root}/classifier-output";let result=runCkbP5IndependentClassifiers(root,"run-中文🙂","C",output,p5IcExecutableConfig("a","codex","GPT-5.6-Sol",fakeA),p5IcExecutableConfig("b","claude-code","GLM-5.2",fakeB),10)
        @Expect(result.ok,true);@Expect(result.processed,1);@Expect(result.paired,1);@Expect(result.rejected,0)
        let diagnostic=String.fromUtf8(File.readFrom(Path(output).join("classifier-control-diagnostics.json")));@Expect(ckbP5ClassifierDiagnosticArtifactValid(diagnostic),true);@Expect(diagnostic.contains("\"ok\":true"),true);@Expect(diagnostic.contains("\"cases\":[]"),true);if(let Some(dyld)<-getVariable("DYLD_LIBRARY_PATH")){@Expect(diagnostic.contains(dyld),false)}
        let first=String.fromUtf8(File.readFrom(Path(output).join("pairs/a/CJ-HUMANEVAL-016.json")));let second=String.fromUtf8(File.readFrom(Path(output).join("pairs/b/CJ-HUMANEVAL-016.json")))
        @Expect(confirmKnowledgeGap(first,second).confirmed,true);@Expect(first==second,false)
    }

    @TestCase
    public func p5IcNeg01MalformedNonzeroTimeoutAndIdentityMismatchNeverProducePair(): Unit {
        for(mode in ["malformed","invalid_utf8","nonterminal","nonzero","identity"]){
            let root=p5IcRoot("negative-${mode}");_=p5IcSample(root,"CJ-HUMANEVAL-016","error: missing member")
            let output="${root}/classifier-output";let result=runCkbP5IndependentClassifiers(root,"run-中文🙂","C",output,p5IcExecutableConfig("a","codex","GPT-5.6-Sol",p5IcFake(root,"fake-a.sh",mode)),p5IcExecutableConfig("b","claude-code","GLM-5.2",p5IcFake(root,"fake-b.sh","ok")),10)
            @Expect(result.ok,false);@Expect(result.paired,0);@Expect(result.rejected,1);@Expect(result.diagnostics.size,1);@Expect(result.diagnostics[0].contains(p5IcExpectedDiagnostic(mode)),true);@Expect(exists(Path(output).join("pairs/a/CJ-HUMANEVAL-016.json")),false)
            let diagnostic=String.fromUtf8(File.readFrom(Path(output).join("classifier-control-diagnostics.json")));@Expect(ckbP5ClassifierDiagnosticArtifactValid(diagnostic),true);@Expect(diagnostic.contains(p5IcExpectedDiagnostic(mode)),true);@Expect(diagnostic.contains("/tmp/"),false);@Expect(diagnostic.toAsciiLower().contains("token"),false);@Expect(exists(Path(output).join("runs/CJ-HUMANEVAL-016/a/stdout.tmp")),false);@Expect(exists(Path(output).join("runs/CJ-HUMANEVAL-016/a/stderr.tmp")),false);@Expect(exists(Path(output).join("runs/CJ-HUMANEVAL-016/a/workspace/response.json")),false)
        }
        let timeoutRoot=p5IcRoot("negative-timeout");_=p5IcSample(timeoutRoot,"CJ-HUMANEVAL-016","error: timeout")
        let timed=runCkbP5IndependentClassifiers(timeoutRoot,"run-中文🙂","C","${timeoutRoot}/classifier-output",p5IcExecutableConfig("a","codex","GPT-5.6-Sol",p5IcFake(timeoutRoot,"fake-a.sh","timeout")),p5IcExecutableConfig("b","claude-code","GLM-5.2",p5IcFake(timeoutRoot,"fake-b.sh","ok")),1)
        @Expect(timed.ok,false);@Expect(timed.paired,0);@Expect(timed.rejected,1);let timedDiagnostic=String.fromUtf8(File.readFrom(Path(timeoutRoot).join("classifier-output/classifier-control-diagnostics.json")));@Expect(ckbP5ClassifierDiagnosticArtifactValid(timedDiagnostic),true);@Expect(timedDiagnostic.contains("classifier_process_timeout"),true)
    }

    // P5-C-UT-03/POS-03/NEG-03/BND-03: cross-process diagnostics are enum-only and fail closed.
    @TestCase
    public func p5IcSafeDiagnosticSidecarMapsExactEnumAndRejectsUnsafePayloads(): Unit {
        let root=p5IcRoot("safe-diagnostic");let path=Path(root).join("classifier-diagnostic.json")
        File.writeTo(path,"{\"schemaVersion\":\"cangjie-teacher-classifier-diagnostic-v1\",\"diagnostic\":\"classifier_response_source_fact_unsupported\"}\n".toArray())
        @Expect(ckbP5ReadClassifierFailureDiagnostic(path),"classifier_response_source_fact_unsupported")
        for(diagnostic in ["classifier_reserved_match_plain_missing","classifier_reserved_match_raw_missing",
            "classifier_reserved_match_rename_missing","classifier_reserved_match_contradictory",
            "classifier_reserved_match_comment_disguised","classifier_string_case_iteration_uint8_missing",
            "classifier_string_case_string_ascii_api_missing","classifier_string_case_rune_ascii_api_missing",
            "classifier_string_case_unicode_import_missing","classifier_string_case_unicode_rune_api_missing",
            "classifier_string_case_unicode_return_type_missing","classifier_string_case_invalid_api_negative_missing",
            "classifier_string_case_contradictory","classifier_string_case_comment_disguised",
            "classifier_string_case_solution_leakage"]){
            File.writeTo(path,"{\"schemaVersion\":\"cangjie-teacher-classifier-diagnostic-v1\",\"diagnostic\":\"${diagnostic}\"}\n".toArray())
            @Expect(ckbP5ReadClassifierFailureDiagnostic(path),diagnostic)
        }
        File.writeTo(path,"{\"schemaVersion\":\"wrong\",\"diagnostic\":\"classifier_timeout\"}".toArray())
        @Expect(ckbP5ReadClassifierFailureDiagnostic(path),"classifier_diagnostic_invalid")
        File.writeTo(path,"{\"schemaVersion\":\"cangjie-teacher-classifier-diagnostic-v1\",\"diagnostic\":\"unknown\"}".toArray())
        @Expect(ckbP5ReadClassifierFailureDiagnostic(path),"classifier_diagnostic_unknown")
        File.writeTo(path,"{\"schemaVersion\":\"cangjie-teacher-classifier-diagnostic-v1\",\"diagnostic\":\"classifier_timeout\",\"path\":\"/Users/private/秘密😀 token=secret\"}".toArray())
        @Expect(ckbP5ReadClassifierFailureDiagnostic(path),"classifier_diagnostic_invalid")
        File.writeTo(path,[UInt8(0xff),UInt8(0xfe)])
        @Expect(ckbP5ReadClassifierFailureDiagnostic(path),"classifier_diagnostic_invalid_encoding")
        File.writeTo(path,Array<UInt8>(513,repeat:UInt8(65)))
        @Expect(ckbP5ReadClassifierFailureDiagnostic(path),"classifier_diagnostic_too_large")
        remove(path)
        @Expect(ckbP5ReadClassifierFailureDiagnostic(path),"classifier_diagnostic_missing")

        let runRoot=p5IcRoot("safe-diagnostic-process");_=p5IcSample(runRoot,"CJ-HUMANEVAL-016","error: missing member")
        let output="${runRoot}/classifier-output";let result=runCkbP5IndependentClassifiers(runRoot,"run-中文🙂","C",output,
            p5IcExecutableConfig("a","codex","GPT-5.6-Sol",p5IcDiagnosticFake(runRoot,"fake-a.sh","classifier_response_source_fact_unsupported")),
            p5IcExecutableConfig("b","claude-code","GLM-5.2",p5IcFake(runRoot,"fake-b.sh","ok")),10)
        @Expect(result.ok,false);@Expect(result.paired,0);@Expect(result.rejected,1)
        @Expect(result.diagnostics[0].contains("a=classifier_response_source_fact_unsupported"),true)
        @Expect(exists(Path(output).join("pairs/a/CJ-HUMANEVAL-016.json")),false)
        @Expect(exists(Path(output).join("runs/CJ-HUMANEVAL-016/a/workspace/classifier-diagnostic.json")),false)

        let preciseRoot=p5IcRoot("safe-diagnostic-precise");_=p5IcSample(preciseRoot,"CJ-HUMANEVAL-018","error: found keyword 'match'")
        let preciseOutput="${preciseRoot}/classifier-output";let precise=runCkbP5IndependentClassifiers(preciseRoot,"run-中文🙂","C",preciseOutput,
            p5IcExecutableConfig("a","codex","GPT-5.6-Sol",p5IcDiagnosticFake(preciseRoot,"fake-a.sh","classifier_reserved_match_raw_missing")),
            p5IcExecutableConfig("b","claude-code","GLM-5.2",p5IcFake(preciseRoot,"fake-b.sh","ok")),10)
        @Expect(precise.ok,false);@Expect(precise.paired,0);@Expect(precise.rejected,1)
        @Expect(precise.diagnostics[0].contains("a=classifier_reserved_match_raw_missing"),true)
        @Expect(precise.diagnostics[0].contains("/Users"),false);@Expect(precise.diagnostics[0].toAsciiLower().contains("token"),false)

        let stringRoot=p5IcRoot("safe-diagnostic-string");_=p5IcSample(stringRoot,"CJ-HUMANEVAL-016","error: 'toLower' is not a member of struct 'String'")
        let stringOutput="${stringRoot}/classifier-output";let stringPrecise=runCkbP5IndependentClassifiers(stringRoot,"run-中文🙂","C",stringOutput,
            p5IcExecutableConfig("a","codex","GPT-5.6-Sol",p5IcDiagnosticFake(stringRoot,"fake-a.sh","classifier_string_case_unicode_import_missing")),
            p5IcExecutableConfig("b","claude-code","GLM-5.2",p5IcFake(stringRoot,"fake-b.sh","ok")),10)
        @Expect(stringPrecise.ok,false);@Expect(stringPrecise.paired,0);@Expect(stringPrecise.rejected,1)
        @Expect(stringPrecise.diagnostics[0].contains("a=classifier_string_case_unicode_import_missing"),true)

        let staleRoot=p5IcRoot("safe-diagnostic-stale");_=p5IcSample(staleRoot,"CJ-HUMANEVAL-016","error: missing member")
        let staleOutput="${staleRoot}/classifier-output";let stale=runCkbP5IndependentClassifiers(staleRoot,"run-中文🙂","C",staleOutput,
            p5IcExecutableConfig("a","codex","GPT-5.6-Sol",p5IcStaleSuccessFake(staleRoot,"fake-a.sh")),
            p5IcExecutableConfig("b","claude-code","GLM-5.2",p5IcFake(staleRoot,"fake-b.sh","ok")),10)
        @Expect(stale.ok,false);@Expect(stale.paired,0);@Expect(stale.rejected,1)
        @Expect(stale.diagnostics[0].contains("a=classifier_diagnostic_unexpected_on_success"),true)
        @Expect(exists(Path(staleOutput).join("runs/CJ-HUMANEVAL-016/a/workspace/classifier-diagnostic.json")),false)
    }

    @TestCase
    public func p5IcE2e01CliIsStrictAndFeedsExistingDevelopmentCloseRoots(): Unit {
        let root=p5IcRoot("e2e");_=p5IcSample(root,"CJ-HUMANEVAL-016","error: API missing")
        let output="${root}/classifier-output";let args=["cangjie-eval-classifier-run","--run-root",root,"--run-id","run-中文🙂","--transport","C","--output-root",output,"--classifier-a-executable",p5IcFake(root,"fake-a.sh","ok"),"--classifier-a-provider","codex","--classifier-a-model","GPT-5.6-Sol","--classifier-a-id","classifier-a","--classifier-b-executable",p5IcFake(root,"fake-b.sh","ok"),"--classifier-b-provider","claude-code","--classifier-b-model","GLM-5.2","--classifier-b-id","classifier-b","--timeout-seconds","10"]
        @Expect(runCangjieEvalClassifierControl(args),0)
        @Expect(exists(Path(output).join("pairs/a/CJ-HUMANEVAL-016.json")),true)
        let duplicate=ArrayList<String>();for(value in args){duplicate.add(value)};duplicate.add("--run-id");duplicate.add("duplicate")
        @Expect(runCangjieEvalClassifierControl(duplicate.toArray()),2)
        @Expect(runCangjieEvalClassifierControl(["cangjie-eval-classifier-run","--unknown","x"]),2)
        @Expect(runCangjieEvalClassifierControl(["cangjie-eval-classifier-run"]),2)
    }

    // NK-E2E-01
    @TestCase
    public func nkE2e01ControllerPersistsReasoningUnitRouteConsensusWithoutKnowledge(): Unit {
        let root=p5IcRoot("nk-route-e2e");_=p5IcSample(root,"CJ-HUMANEVAL-116","Exception: expected -4, actual -6 中文🙂",failureType:"test_failure")
        let output="${root}/classifier-output"
        let result=runCkbP5IndependentClassifiers(root,"run-中文🙂","C",output,p5IcExecutableConfig("a","codex","GPT-5.6-Sol",p5IcFake(root,"fake-a.sh","reasoning")),p5IcExecutableConfig("b","claude-code","GLM-5.2",p5IcFake(root,"fake-b.sh","unit")),10)
        @Expect(result.ok,true);@Expect(result.paired,1);@Expect(result.rejected,0)
        let first=String.fromUtf8(File.readFrom(Path(output).join("pairs/a/CJ-HUMANEVAL-116.json")));let second=String.fromUtf8(File.readFrom(Path(output).join("pairs/b/CJ-HUMANEVAL-116.json")))
        let confirmation=confirmIndependentClassifierPair(first,second)
        @Expect(confirmation.confirmed,true);@Expect(confirmation.diagnostic,"nonknowledge_route_consensus");@Expect(confirmation.route,"reasoning")
        @Expect(confirmKnowledgeGap(first,second).confirmed,false)
        let diagnostic=String.fromUtf8(File.readFrom(Path(output).join("classifier-control-diagnostics.json")))
        @Expect(ckbP5ClassifierDiagnosticArtifactValid(diagnostic),true);@Expect(diagnostic.contains("/tmp/"),false);@Expect(diagnostic.toAsciiLower().contains("token"),false)
    }

    // S5-UT-02
    @TestCase
    public func s5Ut02ProtocolEvidenceSkipsBothClassifiers(): Unit {
        let root=p5IcRoot("s5-protocol");_=p5IcNonBusinessSample(root,"CJ-HUMANEVAL-016","\"protocolViolation\":true")
        let output="${root}/classifier-output"
        let result=runCkbP5IndependentClassifiers(root,"run-中文🙂","C",output,
            p5IcExecutableConfig("a","codex","GPT-5.6-Sol",p5IcFake(root,"fake-a.sh","ok")),
            p5IcExecutableConfig("b","claude-code","GLM-5.2",p5IcFake(root,"fake-b.sh","ok")),10)
        @Expect(result.ok,true);@Expect(result.processed,0);@Expect(result.paired,0);@Expect(result.rejected,0)
        @Expect(exists(Path(output).join("runs/CJ-HUMANEVAL-016")),false)
        @Expect(exists(Path(output).join("pairs/a/CJ-HUMANEVAL-016.json")),false)
        let diagnostic=String.fromUtf8(File.readFrom(Path(output).join("classifier-control-diagnostics.json")))
        @Expect(ckbP5ClassifierDiagnosticArtifactValid(diagnostic),true)
        @Expect(diagnostic.contains("sealed_nonbusiness_route:protocol_violation:protocol"),true)
    }

    // S5-BND-02
    @TestCase
    public func s5Bnd02OperationalCategoriesNeverBuildClassifierRequests(): Unit {
        for((label,signal,category,route) in [
            ("environment","\"environmentFailure\":true","environment_failure","environment"),
            ("runner","\"runnerFailure\":true","runner_failure","runner"),
            ("dataset","\"datasetFailure\":true","dataset_failure","dataset"),
            ("timeout","\"timedOut\":true","timeout","timeout"),
            ("malformed-tool","\"malformedToolPayload\":true","malformed_tool_payload","protocol"),
            ("tool","\"toolFailure\":true","tool_error","tool"),
            ("model-empty","\"emptyModelResponse\":true","model_empty","reasoning"),
            ("retrieval","\"zeroKnowledgeHits\":true","evidence_missing","retrieval")
        ]){
            let root=p5IcRoot("s5-${label}");let caseRoot=p5IcNonBusinessSample(root,"CJ-HUMANEVAL-016",signal)
            @Expect(buildCkbP5ClassifierRequest(caseRoot,"CJ-HUMANEVAL-016","run-中文🙂"),
                "sealed_nonbusiness_route:${category}:${route}")
        }
    }

    // S5-POS-04
    @TestCase
    public func s5Pos04BusinessFailureStillRequiresIndependentPair(): Unit {
        let root=p5IcRoot("s5-business");_=p5IcSample(root,"CJ-HUMANEVAL-016","error: String API missing 中文🙂")
        let output="${root}/classifier-output"
        let result=runCkbP5IndependentClassifiers(root,"run-中文🙂","C",output,
            p5IcExecutableConfig("a","codex","GPT-5.6-Sol",p5IcFake(root,"fake-a.sh","ok")),
            p5IcExecutableConfig("b","claude-code","GLM-5.2",p5IcFake(root,"fake-b.sh","ok")),10)
        @Expect(result.ok,true);@Expect(result.processed,1);@Expect(result.paired,1);@Expect(result.rejected,0)
        let first=String.fromUtf8(File.readFrom(Path(output).join("pairs/a/CJ-HUMANEVAL-016.json")))
        let second=String.fromUtf8(File.readFrom(Path(output).join("pairs/b/CJ-HUMANEVAL-016.json")))
        @Expect(confirmKnowledgeGap(first,second).confirmed,true)
    }

    // S5-NEG-03
    @TestCase
    public func s5Neg03ForgedCategoryOrUnsealedEvidenceCannotSkipClassifiers(): Unit {
        let root=p5IcRoot("s5-forged-category");let caseRoot=p5IcSample(root,"CJ-HUMANEVAL-016","error: missing API")
        let row=String.fromUtf8(File.readFrom(caseRoot.join("case-result.json")))
        File.writeTo(caseRoot.join("case-result.json"),row.replace("}",",\"category\":\"protocol_violation\"}").toArray())
        let output="${root}/classifier-output"
        let result=runCkbP5IndependentClassifiers(root,"run-中文🙂","C",output,
            p5IcExecutableConfig("a","codex","GPT-5.6-Sol",p5IcFake(root,"fake-a.sh","ok")),
            p5IcExecutableConfig("b","claude-code","GLM-5.2",p5IcFake(root,"fake-b.sh","ok")),10)
        @Expect(result.ok,true);@Expect(result.processed,1);@Expect(result.paired,1)

        let tamperedRoot=p5IcRoot("s5-forged-evidence");let tamperedCase=p5IcNonBusinessSample(tamperedRoot,"CJ-HUMANEVAL-016","\"protocolViolation\":true")
        let evidence=String.fromUtf8(File.readFrom(tamperedCase.join("result-evidence.json")))
        File.writeTo(tamperedCase.join("result-evidence.json"),evidence.replace("\"protocolViolation\":true","\"protocolViolation\":false,\"environmentFailure\":true").toArray())
        let tamperedOutput="${tamperedRoot}/classifier-output"
        let blocked=runCkbP5IndependentClassifiers(tamperedRoot,"run-中文🙂","C",tamperedOutput,
            p5IcExecutableConfig("a","codex","GPT-5.6-Sol",p5IcFake(tamperedRoot,"fake-a.sh","ok")),
            p5IcExecutableConfig("b","claude-code","GLM-5.2",p5IcFake(tamperedRoot,"fake-b.sh","ok")),10)
        @Expect(blocked.ok,false);@Expect(blocked.rejected,1);@Expect(blocked.processed,0)
        @Expect(exists(Path(tamperedOutput).join("runs/CJ-HUMANEVAL-016")),false)
    }
}

private func s0FailureAssetFixture(name:String):String{
    try{String.fromUtf8(File.readFrom(Path("fixtures/completion_failure_assets").join(name)))}
    catch(_:Exception){"fixture_invalid_encoding"}
}
private func s0FailureAssetFileHash(name:String):String{
    benchmarkGapSha256(s0FailureAssetFixture(name))
}
private func s0FailureAssetString(object:JsonObject,key:String):String{
    object.get(key).getOrThrow().asString().getValue()
}
private func s0FailureAssetInt(object:JsonObject,key:String):Int64{
    object.get(key).getOrThrow().asInt().getValue()
}
private func s0FailureAssetHashInput(raw:String,key:String):String{
    let parts=raw.trimAscii().split(",\"${key}\"")
    if(parts.size!=2){return "fixture_hash_input_invalid"}
    parts[0]+"}"
}
private func s0FailureAssetClosureDiagnostic():String{
    try{
        let sourceRaw=s0FailureAssetFixture("source-evidence-manifest-v1.json")
        let source=JsonValue.fromStr(sourceRaw.trimAscii()).asObject()
        if(benchmarkGapSha256(s0FailureAssetHashInput(sourceRaw,"sourceManifestHash"))!=
            s0FailureAssetString(source,"sourceManifestHash")){return "source_manifest_hash_mismatch"}
        let ruleRaw=s0FailureAssetFixture("rule-candidate-v1.json")
        let rule=JsonValue.fromStr(ruleRaw.trimAscii()).asObject()
        if(benchmarkGapSha256(s0FailureAssetHashInput(ruleRaw,"canonicalHash"))!=
            s0FailureAssetString(rule,"canonicalHash")||
            s0FailureAssetString(rule,"sourceEvidenceHash")!=s0FailureAssetString(source,"sourceManifestHash")||
            s0FailureAssetString(rule,"positiveEvidenceHash")!=s0FailureAssetFileHash("classification-v2-valid.jsonl")||
            s0FailureAssetString(rule,"negativeEvidenceHash")!=s0FailureAssetFileHash("classification-v2-contract-drift.jsonl")||
            s0FailureAssetString(rule,"boundaryEvidenceHash")!=s0FailureAssetFileHash("completion-failure-v1-utf8.json")||
            s0FailureAssetString(rule,"generalizationEvidenceHash")!=s0FailureAssetFileHash("classification-v1-compatibility.jsonl")){
            return "rule_candidate_hash_mismatch"
        }
        let rulesOperation=JsonValue.fromStr(s0FailureAssetFixture("rules-operation-v1.json").trimAscii()).asObject()
        let skillsOperation=JsonValue.fromStr(s0FailureAssetFixture("skills-operation-v1.json").trimAscii()).asObject()
        if(s0FailureAssetString(rulesOperation,"newHash")!=s0FailureAssetString(rule,"canonicalHash")||
            s0FailureAssetString(skillsOperation,"newHash")!=s0FailureAssetFileHash("student-skill-content.md")){
            return "operation_hash_mismatch"
        }
        let execution=JsonValue.fromStr(s0FailureAssetFixture("candidate-fixture-execution-v1.json").trimAscii()).asObject()
        if(s0FailureAssetString(execution,"fixtureHash")!=s0FailureAssetFileHash("knowledge-content.md")||
            s0FailureAssetString(execution,"providerIdentityHash")!=s0FailureAssetFileHash("classification-v2-valid.jsonl")||
            s0FailureAssetString(execution,"expectedEvidenceHash")!=s0FailureAssetFileHash("source-evidence-manifest-v1.json")||
            s0FailureAssetString(execution,"actualEvidenceHash")!=s0FailureAssetFileHash("source-evidence-manifest-v1.json")||
            s0FailureAssetString(execution,"transcriptHash")!=s0FailureAssetFileHash("rules-operation-v1.json")){
            return "candidate_execution_hash_mismatch"
        }
        let candidateRaw=s0FailureAssetFixture("candidate-set-manifest-v1.json")
        let candidate=JsonValue.fromStr(candidateRaw.trimAscii()).asObject()
        if(benchmarkGapSha256(s0FailureAssetHashInput(candidateRaw,"candidateSetHash"))!=
            s0FailureAssetString(candidate,"candidateSetHash")||
            s0FailureAssetString(candidate,"sourceEvidenceManifestHash")!=s0FailureAssetString(source,"sourceManifestHash")||
            s0FailureAssetString(candidate,"rulesHash")!=s0FailureAssetFileHash("rule-candidate-v1.json")||
            s0FailureAssetString(candidate,"skillsHash")!=s0FailureAssetFileHash("skills-operation-v1.json")||
            s0FailureAssetString(candidate,"knowledgeCandidateHash")!=s0FailureAssetFileHash("knowledge-content.md")||
            s0FailureAssetString(candidate,"combinationAuditHash")!=s0FailureAssetFileHash("candidate-fixture-execution-v1.json")){
            return "candidate_set_hash_mismatch"
        }
        let approvalRaw=s0FailureAssetFixture("approval-v1.json")
        let approval=JsonValue.fromStr(approvalRaw.trimAscii()).asObject()
        if(s0FailureAssetString(approval,"candidateSetHash")!=s0FailureAssetString(candidate,"candidateSetHash")||
            s0FailureAssetString(approval,"rulesHash")!=s0FailureAssetString(candidate,"rulesHash")||
            s0FailureAssetString(approval,"skillsHash")!=s0FailureAssetString(candidate,"skillsHash")||
            s0FailureAssetString(approval,"knowledgeCandidateHash")!=s0FailureAssetString(candidate,"knowledgeCandidateHash")){
            return "approval_hash_mismatch"
        }
        let frozen=JsonValue.fromStr(s0FailureAssetFixture("frozen-knowledge-reference-v1.json").trimAscii()).asObject()
        if(s0FailureAssetString(frozen,"knowledgeCandidateHash")!=s0FailureAssetString(candidate,"knowledgeCandidateHash")||
            s0FailureAssetString(frozen,"frozenCandidateManifestHash")!=s0FailureAssetFileHash("candidate-set-manifest-v1.json")||
            s0FailureAssetString(frozen,"knowledgeContentHash")!=s0FailureAssetFileHash("knowledge-content.md")){
            return "frozen_knowledge_reference_hash_mismatch"
        }
        let bundleRaw=s0FailureAssetFixture("student-context-bundle-v1.json")
        let bundle=JsonValue.fromStr(bundleRaw.trimAscii()).asObject()
        if(benchmarkGapSha256(s0FailureAssetHashInput(bundleRaw,"compositeHash"))!=
            s0FailureAssetString(bundle,"compositeHash")||
            s0FailureAssetString(bundle,"candidateSetHash")!=s0FailureAssetString(candidate,"candidateSetHash")||
            s0FailureAssetString(bundle,"approvalHash")!=s0FailureAssetFileHash("approval-v1.json")||
            s0FailureAssetString(bundle,"rulesHash")!=s0FailureAssetString(candidate,"rulesHash")||
            s0FailureAssetString(bundle,"skillBundleHash")!=s0FailureAssetString(candidate,"skillsHash")||
            s0FailureAssetString(bundle,"knowledgeContentHash")!=s0FailureAssetString(frozen,"knowledgeContentHash")||
            s0FailureAssetInt(bundle,"rulesContentBytes")!=s0FailureAssetString(rule,"body").toArray().size||
            s0FailureAssetInt(bundle,"skillContentBytes")!=s0FailureAssetFixture("student-skill-content.md").toArray().size){
            return "student_context_bundle_hash_mismatch"
        }
        let context=JsonValue.fromStr(s0FailureAssetFixture("completion-context-evidence-v2.json").trimAscii()).asObject()
        if(s0FailureAssetString(context,"knowledgeResponseHash")!=s0FailureAssetFileHash("frozen-knowledge-reference-v1.json")||
            s0FailureAssetString(context,"knowledgePackHash")!=s0FailureAssetFileHash("knowledge-content.md")||
            s0FailureAssetInt(context,"knowledgeContentBytes")!=s0FailureAssetFixture("knowledge-content.md").toArray().size||
            s0FailureAssetString(context,"compositeHash")!=s0FailureAssetString(bundle,"compositeHash")){
            return "completion_context_evidence_hash_mismatch"
        }
        let capabilityRaw=s0FailureAssetFixture("provider-prompt-capability-v1.json")
        let capability=JsonValue.fromStr(capabilityRaw.trimAscii()).asObject()
        if(benchmarkGapSha256(s0FailureAssetHashInput(capabilityRaw,"capabilityHash"))!=
            s0FailureAssetString(capability,"capabilityHash")){return "provider_capability_hash_mismatch"}
        let delta=JsonValue.fromStr(s0FailureAssetFixture("certification-v5-delta.json").trimAscii()).asObject()
        if(s0FailureAssetString(delta,"studentContextManifestHash")!=s0FailureAssetFileHash("student-context-bundle-v1.json")||
            s0FailureAssetString(delta,"compositeHash")!=s0FailureAssetString(bundle,"compositeHash")||
            s0FailureAssetString(delta,"providerPromptCapabilityHash")!=s0FailureAssetFileHash("provider-prompt-capability-v1.json")||
            s0FailureAssetInt(delta,"effectivePromptByteBudget")!=188416){return "certification_delta_hash_mismatch"}
        for(name in ["student-skill-content.md","knowledge-content.md","source-evidence-manifest-v1.json",
            "rule-candidate-v1.json","candidate-set-manifest-v1.json","approval-v1.json",
            "student-context-bundle-v1.json","completion-context-evidence-v2.json"]){
            let lower=s0FailureAssetFixture(name).toAsciiLower()
            if(lower.contains("/users/")||lower.contains("/home/")||lower.contains("authorization")||
                lower.contains("bearer ")||lower.contains("token=")||lower.contains("password")||
                lower.contains("canonical_solution")||lower.contains("hidden_test")){return "fixture_protected_material"}
        }
        "ok"
    }catch(_:Exception){"fixture_closure_malformed"}
}
private func s0FailureAssetHexNibble(value:Rune):UInt8{
    if(value==r'0'){return UInt8(0)};if(value==r'1'){return UInt8(1)}
    if(value==r'2'){return UInt8(2)};if(value==r'3'){return UInt8(3)}
    if(value==r'4'){return UInt8(4)};if(value==r'5'){return UInt8(5)}
    if(value==r'6'){return UInt8(6)};if(value==r'7'){return UInt8(7)}
    if(value==r'8'){return UInt8(8)};if(value==r'9'){return UInt8(9)}
    if(value==r'a'){return UInt8(10)};if(value==r'b'){return UInt8(11)}
    if(value==r'c'){return UInt8(12)};if(value==r'd'){return UInt8(13)}
    if(value==r'e'){return UInt8(14)};if(value==r'f'){return UInt8(15)}
    UInt8(255)
}
private func s0FailureAssetInvalidUtf8Bytes():Array<UInt8>{
    let text=s0FailureAssetFixture("classification-invalid-utf8.hex")
    if(text!="fffe\n"){return []}
    let runes=text.toRuneArray();let out=ArrayList<UInt8>()
    for(i in 0..4:2){
        let high=s0FailureAssetHexNibble(runes[i]);let low=s0FailureAssetHexNibble(runes[i+1])
        if(high>15||low>15){return []};out.add(high*16+low)
    }
    out.toArray()
}

private func p5IcRoot(label:String):String{let root="/tmp/ckb-p5-ic-${label}-${DateTime.now().toUnixTimeStamp().toMilliseconds()}";if(exists(Path(root))){_=launch("/bin/rm",["-rf",root]).wait()};Directory.create(Path(root),recursive:true);root}
private func p5IcSample(root:String,caseId:String,log:String,failureType!:String="compile_error"):Path{
    let caseRoot=Path(root).join("cases").join(caseId).join(CkbAbcdeGroups.C);Directory.create(caseRoot,recursive:true)
    let sourceRoot=caseRoot.join("workspace/src");Directory.create(sourceRoot,recursive:true);File.writeTo(sourceRoot.join("solution.cj"),"package sample\n// 学生源码🙂\npublic func sample(s: String): Int64 { s.size }\n".toArray())
    let raw="{\"caseId\":\"${caseId}\",\"runId\":\"run-中文🙂\",\"datasetVersion\":\"dataset-v1\",\"attempt\":1,\"runMode\":\"development\",\"failureObservation\":\"missing reusable guidance 中文🙂\",\"suspectedKnowledgeGap\":true,\"retrievalDiagnostic\":\"bound_tool_result\",\"retrievalEvidenceHash\":\"h342434\",\"failureType\":\"${failureType}\",\"unitPass\":false,\"resultEvidenceHash\":\"HASH\"}";let evidence=raw.replace("HASH",cangjieEvalTriageResultEvidenceHash(raw))
    let result="{\"caseId\":\"${caseId}\",\"runId\":\"run-中文🙂\",\"datasetVersion\":\"dataset-v1\",\"runMode\":\"development\",\"firstAttemptPass\":false,\"firstClaudeExitCode\":0,\"failureType\":\"${failureType}\",\"toolEvidenceHash\":\"h342434\",\"toolCoveragePass\":true,\"citationCount\":2}"
    File.writeTo(caseRoot.join("case-result.json"),result.toArray());File.writeTo(caseRoot.join("result-evidence.json"),evidence.toArray());File.writeTo(caseRoot.join("canonical-task-context.json"),"{\"taskId\":\"${caseId}\",\"datasetVersion\":\"dataset-v1\",\"taskText\":\"通用字符串 API 任务🙂\",\"signature\":\"public func sample(s: String): Int64\"}".toArray());File.writeTo(caseRoot.join("test.log"),log.toArray());caseRoot
}
private func p5IcNonBusinessSample(root:String,caseId:String,signal:String):Path{
    let caseRoot=p5IcSample(root,caseId,"operational failure 中文🙂")
    let raw="{\"caseId\":\"${caseId}\",\"runId\":\"run-中文🙂\",\"datasetVersion\":\"dataset-v1\",\"attempt\":1,\"runMode\":\"development\",\"failureObservation\":\"operational failure 中文🙂\",${signal},\"resultEvidenceHash\":\"HASH\"}"
    File.writeTo(caseRoot.join("result-evidence.json"),raw.replace("HASH",cangjieEvalTriageResultEvidenceHash(raw)).toArray())
    caseRoot
}
private func p5IcTransportRetrySample(root:String,caseId:String,transportAttempts:Int64,sampleAttempts:Int64,attempts:String):Path{
    let caseRoot=p5IcSample(root,caseId,"Exception: expected -1, actual 1 中文🙂",failureType:"test_failure")
    let row="{\"caseId\":\"${caseId}\",\"runId\":\"run-中文🙂\",\"datasetVersion\":\"dataset-v1\",\"runMode\":\"development\",\"firstAttemptPass\":false,\"firstClaudeExitCode\":1,\"claudeExitCode\":0,\"claudeAttemptCount\":${transportAttempts},\"failureType\":\"test_failure\",\"toolEvidenceHash\":\"h342434\",\"toolCoveragePass\":true,\"citationCount\":2}"
    let raw="{\"caseId\":\"${caseId}\",\"runId\":\"run-中文🙂\",\"datasetVersion\":\"dataset-v1\",\"attempt\":${transportAttempts},\"runMode\":\"development\",\"failureObservation\":\"test_failure\",\"protocolViolation\":false,\"timedOut\":false,\"environmentFailure\":false,\"suspectedKnowledgeGap\":false,\"retrievalDiagnostic\":\"bound_tool_result\",\"retrievalEvidenceHash\":\"h342434\",\"reasoningFailure\":true,\"failureType\":\"test_failure\",\"unitPass\":false,\"resultEvidenceHash\":\"HASH\"}"
    let evidence=raw.replace("HASH",cangjieEvalTriageResultEvidenceHash(raw))
    let restores="{\"transportAttempt\":2,\"restored\":true,\"sourceAttempt\":1,\"sourceHash\":\"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"restoredHash\":\"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}\n";let restoreHash=benchmarkGapSha256(restores)
    File.writeTo(caseRoot.join("case-result.json"),row.toArray());File.writeTo(caseRoot.join("result-evidence.json"),evidence.toArray())
    File.writeTo(caseRoot.join("attempt-evidence.json"),"{\"transportAttemptCount\":${transportAttempts},\"sampleAttemptCount\":${sampleAttempts},\"workspaceRestoreEvidenceHash\":\"${restoreHash}\",\"attemptsPath\":\"claude-attempts.jsonl\",\"restoresPath\":\"workspace-restores.jsonl\"}\n".toArray())
    File.writeTo(caseRoot.join("test-result.json"),"{\"testExitCode\":0,\"unitPassAt1\":false,\"transportAttemptCount\":${transportAttempts},\"sampleAttemptCount\":${sampleAttempts},\"workspaceRestoreEvidenceHash\":\"${restoreHash}\",\"failureType\":\"test_failure\",\"testLogPath\":\"redacted\"}\n".toArray())
    let transcript="{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false,\"model\":\"GLM-5.2\",\"中文\":\"🙂\"}\n"
    File.writeTo(caseRoot.join("workspace-restores.jsonl"),restores.toArray());File.writeTo(caseRoot.join("claude-attempts.jsonl"),attempts.toArray())
    File.writeTo(caseRoot.join("claude-transcript.attempt-${transportAttempts}.jsonl"),transcript.toArray());File.writeTo(caseRoot.join("claude-transcript.jsonl"),transcript.toArray());caseRoot
}
private func p5IcRequest(caseId:String):String{let evidence="{\"caseId\":\"${caseId}\",\"runId\":\"run-001\",\"datasetVersion\":\"dataset-v1\",\"attempt\":1,\"runMode\":\"development\",\"failureObservation\":\"missing reusable guidance 中文🙂\",\"suspectedKnowledgeGap\":true,\"failureType\":\"compile_error\",\"unitPass\":false,\"resultEvidenceHash\":\"HASH\"}";let hash=cangjieEvalTriageResultEvidenceHash(evidence);"{\"schemaVersion\":\"ckb-p5-classifier-request-v1\",\"caseId\":\"${caseId}\",\"runId\":\"run-001\",\"datasetVersion\":\"dataset-v1\",\"attempt\":1,\"runMode\":\"development\",\"studentSourceExcerpt\":\"学生源码🙂\",\"studentSourceHash\":\"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"failureObservation\":\"missing reusable guidance 中文🙂\",\"resultEvidenceHash\":\"${hash}\"}"}
private func p5IcAbsRequest(caseId:String,source:String,compiler:String):String{
    p5IcRequest(caseId).replace("\"studentSourceExcerpt\":\"学生源码🙂\"","\"studentSourceExcerpt\":\"${source.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n")}\"").replace("\"resultEvidenceHash\":","\"compilerTestSummary\":\"${compiler.replace("\\","\\\\").replace("\"","\\\"")}\",\"resultEvidenceHash\":")
}
private func p5IcConfig(label:String,provider:String,model:String):CkbP5ClassifierConfig{p5IcExecutableConfig(label,provider,model,"/fake/${label}")}
private func p5IcExecutableConfig(label:String,provider:String,model:String,executable:String):CkbP5ClassifierConfig{let c=CkbP5ClassifierConfig();c.label=label;c.classifierId="classifier-${label}";c.provider=provider;c.model=model;c.executable=executable;c}
private func p5IcResponse(provider:String,model:String):String{"{\"schemaVersion\":\"ckb-p5-classifier-response-v1\",\"observedProvider\":\"${provider}\",\"observedModel\":\"${model}\",\"category\":\"knowledge_gap\",\"knowledgeFamily\":\"standard_library\",\"reusable\":true,\"sourceClass\":\"official\",\"citation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/\",\"purificationPassed\":true,\"canonicalKnowledgeId\":\"GENERAL-STRING-API\",\"targetVersion\":\"1.0.0\",\"evidenceId\":\"official-string-api\",\"knowledgeText\":\"General reusable String API guidance 中文🙂\"}"}
private func p5IcExpectedDiagnostic(mode:String):String{if(mode=="malformed"){"classifier_response_malformed"}else if(mode=="invalid_utf8"){"classifier_response_invalid_encoding"}else if(mode=="nonterminal"){"classifier_response_incomplete"}else if(mode=="nonzero"){"classifier_diagnostic_missing"}else{"classifier_response_identity_mismatch"}}
private func p5IcDiagnosticFake(root:String,name:String,diagnostic:String):String{
    let path=Path(root).join(name);let body="#!/bin/zsh\nworkspace=''; while (( $# > 0 )); do case \"$1\" in --workspace) workspace=\"$2\"; shift 2;; *) shift 2;; esac; done\nprint -r -- '{\"schemaVersion\":\"cangjie-teacher-classifier-diagnostic-v1\",\"diagnostic\":\"${diagnostic}\"}' > \"$workspace/classifier-diagnostic.json\"\nexit 7\n"
    File.writeTo(path,body.toArray());_=launch("/bin/chmod",["700",path.toString()]).wait();path.toString()
}
private func p5IcStaleSuccessFake(root:String,name:String):String{
    let path=Path(root).join(name);let body="#!/bin/zsh\nworkspace=''; out=''; provider=''; model=''; while (( $# > 0 )); do case \"$1\" in --workspace) workspace=\"$2\"; shift 2;; --output) out=\"$2\"; shift 2;; --expected-provider) provider=\"$2\"; shift 2;; --expected-model) model=\"$2\"; shift 2;; *) shift 2;; esac; done\nprint -r -- '{\"schemaVersion\":\"cangjie-teacher-classifier-diagnostic-v1\",\"diagnostic\":\"classifier_timeout\"}' > \"$workspace/classifier-diagnostic.json\"\nprint -r -- \"{\\\"schemaVersion\\\":\\\"ckb-p5-classifier-response-v1\\\",\\\"observedProvider\\\":\\\"$provider\\\",\\\"observedModel\\\":\\\"$model\\\",\\\"category\\\":\\\"knowledge_gap\\\",\\\"knowledgeFamily\\\":\\\"standard_library\\\",\\\"reusable\\\":true,\\\"sourceClass\\\":\\\"official\\\",\\\"citation\\\":\\\"https://docs.cangjie-lang.cn/docs/1.0.0/\\\",\\\"purificationPassed\\\":true,\\\"canonicalKnowledgeId\\\":\\\"GENERAL-STRING-API\\\",\\\"targetVersion\\\":\\\"1.0.0\\\",\\\"evidenceId\\\":\\\"official-string-api\\\",\\\"knowledgeText\\\":\\\"General reusable String API guidance 中文🙂\\\"}\" > \"$out\"\n"
    File.writeTo(path,body.toArray());_=launch("/bin/chmod",["700",path.toString()]).wait();path.toString()
}
private func p5IcFake(root:String,name:String,mode:String):String{
    let path=Path(root).join(name);let body=if(mode=="timeout"){"#!/bin/zsh\nsleep 5\n"}else if(mode=="nonzero"){"#!/bin/zsh\nexit 7\n"}else{"#!/bin/zsh\nout=''; provider=''; model=''; while (( $# > 0 )); do case \"$1\" in --output) out=\"$2\"; shift 2;; --expected-provider) provider=\"$2\"; shift 2;; --expected-model) model=\"$2\"; shift 2;; *) shift 2;; esac; done\n"+if(mode=="malformed"){"print -r -- '{' > \"$out\"\n"}else if(mode=="invalid_utf8"){"printf '\\xff\\xfe' > \"$out\"\n"}else if(mode=="nonterminal"){"print -r -- '{\"schemaVersion\":\"ckb-p5-classifier-response-v1\"}' > \"$out\"\n"}else if(mode=="identity"){"print -r -- '{\"schemaVersion\":\"ckb-p5-classifier-response-v1\",\"observedProvider\":\"wrong\",\"observedModel\":\"wrong\",\"category\":\"knowledge_gap\"}' > \"$out\"\n"}else if(mode=="reasoning"||mode=="unit"){let category=if(mode=="reasoning"){"reasoning_failure"}else{"unit_failure"};"print -r -- \"{\\\"schemaVersion\\\":\\\"ckb-p5-classifier-response-v1\\\",\\\"observedProvider\\\":\\\"$provider\\\",\\\"observedModel\\\":\\\"$model\\\",\\\"category\\\":\\\"${category}\\\"}\" > \"$out\"\n"}else{"print -r -- \"{\\\"schemaVersion\\\":\\\"ckb-p5-classifier-response-v1\\\",\\\"observedProvider\\\":\\\"$provider\\\",\\\"observedModel\\\":\\\"$model\\\",\\\"category\\\":\\\"knowledge_gap\\\",\\\"knowledgeFamily\\\":\\\"standard_library\\\",\\\"reusable\\\":true,\\\"sourceClass\\\":\\\"official\\\",\\\"citation\\\":\\\"https://docs.cangjie-lang.cn/docs/1.0.0/\\\",\\\"purificationPassed\\\":true,\\\"canonicalKnowledgeId\\\":\\\"GENERAL-STRING-API\\\",\\\"targetVersion\\\":\\\"1.0.0\\\",\\\"evidenceId\\\":\\\"official-string-api\\\",\\\"knowledgeText\\\":\\\"General reusable String API guidance 中文🙂\\\"}\" > \"$out\"\n"}}
    File.writeTo(path,body.toArray());_=launch("/bin/chmod",["700",path.toString()]).wait();path.toString()
}
