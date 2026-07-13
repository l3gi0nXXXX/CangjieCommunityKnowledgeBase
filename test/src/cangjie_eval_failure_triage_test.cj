package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieEvalFailureTriageTest {
    @TestCase
    public func p5Ut01TaxonomyConfirmationAndRetryPass1AreStrict(): Unit {
        let cases = [
            ("{\"attempt\":1,\"runMode\":\"development\",\"protocolViolation\":true}", "protocol_violation", "protocol"),
            ("{\"attempt\":1,\"runMode\":\"development\",\"timedOut\":true}", "timeout", "timeout"),
            ("{\"attempt\":1,\"runMode\":\"development\",\"toolFailure\":true}", "tool_error", "tool"),
            ("{\"attempt\":1,\"runMode\":\"development\",\"datasetFailure\":true}", "dataset_failure", "dataset"),
            ("{\"attempt\":1,\"runMode\":\"development\",\"runnerFailure\":true}", "runner_failure", "runner"),
            ("{\"attempt\":1,\"runMode\":\"development\",\"environmentFailure\":true}", "environment_failure", "environment"),
            ("{\"attempt\":1,\"runMode\":\"development\",\"reasoningFailure\":true}", "reasoning_failure", "reasoning")
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
        @Expect(confirmKnowledgeGap(first, p5Classifier("classifier-b", "transcript-b", "knowledge_gap", 2, "development")).diagnostic, "classifier_evidence_hash_mismatch")
        let contaminatedA = p5ClassifierWithKnowledgeId("classifier-a", "transcript-a", "knowledge_gap", 1, "development", "CJ-HUMANEVAL-007")
        let contaminatedB = p5ClassifierWithKnowledgeId("classifier-b", "transcript-b", "knowledge_gap", 1, "development", "CJ-HUMANEVAL-007")
        @Expect(confirmKnowledgeGap(contaminatedA, contaminatedB).diagnostic, "knowledge_policy_not_satisfied")
        let retry = triageEvalFailure("{\"attempt\":2,\"runMode\":\"development\",\"unitPass\":true}")
        @Expect(retry.category, "reasoning_failure")
    }

    @TestCase
    public func p5Bnd01MalformedUnicodeLongAndOperationalFailuresFailClosed(): Unit {
        @Expect(triageEvalFailure("").diagnostic, "empty_input")
        @Expect(triageEvalFailure("{\"attempt\":1").diagnostic, "malformed_json")
        @Expect(triageEvalFailureFromUtf8([UInt8(0xff), UInt8(0xfe)]).diagnostic, "invalid_response_encoding")
        @Expect(triageEvalFailure("{\"attempt\":1,\"runMode\":\"development\",\"emptyModelResponse\":true,\"note\":\"中文😀\"}").category, "model_empty")
        @Expect(triageEvalFailure("{\"attempt\":1,\"runMode\":\"development\",\"zeroKnowledgeHits\":true}").category, "evidence_missing")
        @Expect(triageEvalFailure("{\"attempt\":1,\"runMode\":\"development\",\"malformedToolPayload\":true}").category, "malformed_tool_payload")
        @Expect(triageEvalFailure("{\"attempt\":1,\"runMode\":\"development\",\"timedOut\":true}").category, "timeout")
        @Expect(triageEvalFailure("{\"attempt\":1,\"runMode\":\"development\",\"toolFailure\":true}").category, "tool_error")
        var huge = ""; for (_ in 0..262145) { huge += "界" }
        @Expect(triageEvalFailure(huge).diagnostic, "input_too_large")
        @Expect(confirmKnowledgeGap("{", "{}").diagnostic, "malformed_classifier_evidence")
    }

    @TestCase
    public func p5E2e01FiveCaseDevelopmentClosureNeverClaimsCertification(): Unit {
        let cases = ArrayList<CangjieEvalDevelopmentCaseClosure>()
        cases.add(p5Closure("知识😀", true, "knowledge_gap"))
        cases.add(p5Closure("reasoning", true, "reasoning_failure"))
        cases.add(p5Closure("dataset", true, "dataset_failure"))
        cases.add(p5Closure("infrastructure", true, "environment_failure"))
        cases.add(p5Closure("success", true, "none"))
        let closure = renderDevelopmentClosure(cases)
        @Expect(closure.contains("\"developmentClosed\":true"), true)
        @Expect(closure.contains("\"developmentPassed\":5"), true)
        @Expect(closure.contains("\"knowledgeCandidateCount\":1"), true)
        @Expect(closure.contains("\"certifiedPassAt1\":null"), true)
        @Expect(closure.contains("\"certificationStatus\":\"unset\""), true)
        @Expect(closure.contains("知识😀"), true)
    }
}

private func p5Classifier(classifier: String, source: String, category: String, attempt: Int64, mode: String): String {
    p5ClassifierWithKnowledgeId(classifier, source, category, attempt, mode, "GENERAL-RUNE")
}

private func p5ClassifierWithKnowledgeId(classifier: String, source: String, category: String, attempt: Int64, mode: String, knowledgeId: String): String {
    let raw = "{\"classifierId\":\"${classifier}\",\"sourceEvidenceId\":\"${source}\",\"category\":\"${category}\",\"attempt\":${attempt},\"runMode\":\"${mode}\",\"knowledgeFamily\":\"standard_library\",\"reusable\":true,\"sourceClass\":\"official\",\"citation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/\",\"purificationPassed\":true,\"canonicalKnowledgeId\":\"${knowledgeId}\",\"targetVersion\":\"1.0.0\",\"evidenceId\":\"official-rune-doc\",\"positiveTestPassed\":true,\"negativeTestPassed\":true,\"boundaryTestPassed\":true,\"evidenceHash\":\"HASH\"}"
    raw.replace("HASH", cangjieEvalTriageClassifierEvidenceHash(raw))
}

private func p5Closure(caseId: String, passed: Bool, category: String): CangjieEvalDevelopmentCaseClosure {
    let item = CangjieEvalDevelopmentCaseClosure(); item.caseId = caseId; item.developmentPass = passed; item.category = category; item.route = routeNonKnowledgeFailure(category); item
}
