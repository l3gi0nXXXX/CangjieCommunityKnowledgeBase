package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieEvalFailureTriageTest {
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
        @Expect(confirmKnowledgeGap(first, p5Classifier("classifier-b", "transcript-b", "reasoning_failure", 1, "development")).diagnostic, "classifier_evidence_hash_mismatch")
        @Expect(confirmKnowledgeGap(first, p5Classifier("classifier-a", "transcript-b", "knowledge_gap", 1, "development")).diagnostic, "independent_classifier_required")
        @Expect(confirmKnowledgeGap(first, p5Classifier("classifier-b", "transcript-b", "knowledge_gap", 2, "development")).diagnostic, "classifier_evidence_hash_mismatch")
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
}

private func p5Classifier(classifier: String, source: String, category: String, attempt: Int64, mode: String): String {
    p5ClassifierWithKnowledgeText(classifier, source, category, attempt, mode, "General reusable Rune guidance.")
}

private func p5ClassifierWithKnowledgeText(classifier: String, source: String, category: String, attempt: Int64, mode: String, knowledgeText: String): String {
    let resultHash = cangjieEvalTriageResultEvidenceHash(p5Triage("\"suspectedKnowledgeGap\":true", 1))
    let raw = "{\"classifierId\":\"${classifier}\",\"sourceEvidenceId\":\"${source}\",\"category\":\"${category}\",\"caseId\":\"CJ-HUMANEVAL-007\",\"runId\":\"run-001\",\"datasetVersion\":\"dataset-v1\",\"resultEvidenceHash\":\"${resultHash}\",\"failureObservation\":\"CKB returned no reusable Rune guidance 中文😀\",\"attempt\":${attempt},\"runMode\":\"${mode}\",\"knowledgeFamily\":\"standard_library\",\"reusable\":true,\"sourceClass\":\"official\",\"citation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/\",\"purificationPassed\":true,\"canonicalKnowledgeId\":\"GENERAL-RUNE\",\"targetVersion\":\"1.0.0\",\"evidenceId\":\"official-rune-doc\",\"positiveTestPassed\":true,\"negativeTestPassed\":true,\"boundaryTestPassed\":true,\"knowledgeText\":\"${knowledgeText}\",\"exampleText\":\"\",\"testText\":\"\",\"publishableMetadata\":\"family=standard_library\",\"evidenceHash\":\"HASH\"}"
    raw.replace("HASH", cangjieEvalTriageClassifierEvidenceHash(raw))
}

private func p5Triage(signal: String, attempt: Int64): String {
    let raw = "{\"caseId\":\"CJ-HUMANEVAL-007\",\"runId\":\"run-001\",\"datasetVersion\":\"dataset-v1\",\"attempt\":${attempt},\"runMode\":\"development\",\"failureObservation\":\"observed 中文😀\",${signal},\"resultEvidenceHash\":\"HASH\"}"
    raw.replace("HASH", cangjieEvalTriageResultEvidenceHash(raw))
}

private func p5Closure(caseId: String, passed: Bool, category: String, confirmed: Bool): CangjieEvalDevelopmentCaseClosure {
    let item = CangjieEvalDevelopmentCaseClosure(); item.caseId = caseId; item.developmentPass = passed; item.category = category; item.route = routeNonKnowledgeFailure(category); item.knowledgeGapConfirmed = confirmed
    if (confirmed) { item.confirmationEvidenceHash = "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" }
    item
}
