package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashSet}
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

public class CangjieEvalFailureTriageResult {
    public var ok: Bool = false
    public var category: String = "invalid_input"
    public var route: String = "protocol"
    public var diagnostic: String = "malformed_json"
    public var evidenceHash: String = ""
    public init() {}
}

public class CangjieEvalKnowledgeGapConfirmation {
    public var confirmed: Bool = false
    public var diagnostic: String = "knowledge_gap_not_confirmed"
    public var category: String = ""
    public var evidenceHash: String = ""
    public init() {}
}

public class CangjieEvalDevelopmentCaseClosure {
    public var caseId: String = ""
    public var developmentPass: Bool = false
    public var category: String = "invalid_input"
    public var route: String = "protocol"
    public var knowledgeGapConfirmed: Bool = false
    public var confirmationEvidenceHash: String = ""
    public init() {}
}

public func triageEvalFailure(inputJson: String): CangjieEvalFailureTriageResult {
    let result = CangjieEvalFailureTriageResult()
    let raw = inputJson.trimAscii()
    if (raw == "") { result.diagnostic = "empty_input"; return result }
    if (raw.toRuneArray().size > 262144) { result.diagnostic = "input_too_large"; return result }
    try {
        let object = JsonValue.fromStr(raw).asObject()
        let attempt = triageJsonInt(object, "attempt", -1)
        let runMode = triageJsonString(object, "runMode").toAsciiLower()
        if (attempt < 1 || (runMode != "development" && runMode != "certification") ||
            triageJsonString(object, "caseId") == "" || triageJsonString(object, "runId") == "" ||
            triageJsonString(object, "datasetVersion") == "" || triageJsonString(object, "failureObservation") == "" || !triageHasOutcomeSignal(object)) {
            result.diagnostic = "field_contract_invalid"; return result
        }
        let declaredHash = triageJsonString(object, "resultEvidenceHash").toAsciiLower()
        if (!triageSha256Format(declaredHash) || declaredHash != triageResultEvidenceHash(object)) {
            result.diagnostic = "result_evidence_hash_mismatch"; return result
        }
        result.category = triageCategory(object)
        result.route = routeNonKnowledgeFailure(result.category)
        result.evidenceHash = declaredHash
        result.ok = true
        result.diagnostic = "ok"
    } catch (_: Exception) {
        result.diagnostic = "malformed_json"
    }
    result
}

public func triageEvalFailureFromUtf8(input: Array<UInt8>): CangjieEvalFailureTriageResult {
    try {
        triageEvalFailure(String.fromUtf8(input))
    } catch (_: Exception) {
        let result = CangjieEvalFailureTriageResult()
        result.diagnostic = "invalid_response_encoding"
        result
    }
}

public func confirmKnowledgeGap(firstJson: String, secondJson: String): CangjieEvalKnowledgeGapConfirmation {
    let result = CangjieEvalKnowledgeGapConfirmation()
    if (firstJson.toRuneArray().size > 262144 || secondJson.toRuneArray().size > 262144) {
        result.diagnostic = "classifier_evidence_too_large"; return result
    }
    try {
        let first = JsonValue.fromStr(firstJson.trimAscii()).asObject()
        let second = JsonValue.fromStr(secondJson.trimAscii()).asObject()
        let firstId = triageJsonString(first, "classifierId")
        let secondId = triageJsonString(second, "classifierId")
        let firstSource = triageJsonString(first, "sourceEvidenceId")
        let secondSource = triageJsonString(second, "sourceEvidenceId")
        if (firstId == "" || secondId == "" || firstId == secondId || firstSource == "" || secondSource == "" || firstSource == secondSource) {
            result.diagnostic = "independent_classifier_required"; return result
        }
        if (!triageClassifierContractValid(first) || !triageClassifierContractValid(second)) {
            result.diagnostic = "classifier_field_contract_invalid"; return result
        }
        let firstHash = triageJsonString(first, "evidenceHash")
        let secondHash = triageJsonString(second, "evidenceHash")
        if (firstHash == "" || firstHash != secondHash || firstHash != triageClassifierEvidenceHash(first) || secondHash != triageClassifierEvidenceHash(second)) {
            result.diagnostic = "classifier_evidence_hash_mismatch"; return result
        }
        let firstCategory = triageJsonString(first, "category").toAsciiLower()
        let secondCategory = triageJsonString(second, "category").toAsciiLower()
        if (firstCategory != "knowledge_gap" || secondCategory != firstCategory) {
            result.diagnostic = "classifier_disagreement"; return result
        }
        if (triageJsonInt(first, "attempt", -1) != 1 || triageJsonInt(second, "attempt", -1) != 1 ||
            triageJsonString(first, "runMode").toAsciiLower() != "development" || triageJsonString(second, "runMode").toAsciiLower() != "development") {
            result.diagnostic = "development_first_attempt_required"; return result
        }
        if (!triageK4Eligible(first) || !triageK4Eligible(second)) {
            result.diagnostic = "knowledge_policy_not_satisfied"; return result
        }
        result.confirmed = true
        result.diagnostic = "ok"
        result.category = firstCategory
        result.evidenceHash = firstHash
    } catch (_: Exception) {
        result.diagnostic = "malformed_classifier_evidence"
    }
    result
}

public func routeNonKnowledgeFailure(category: String): String {
    let value = category.trimAscii().toAsciiLower()
    if (value == "knowledge_gap" || value == "none") { return value }
    if (value == "reasoning_failure" || value == "compile_error" || value == "unit_failure" || value == "model_empty") { return "reasoning" }
    if (value == "dataset_failure") { return "dataset" }
    if (value == "runner_failure") { return "runner" }
    if (value == "environment_failure") { return "environment" }
    if (value == "protocol_violation" || value == "malformed_tool_payload") { return "protocol" }
    if (value == "tool_error" || value == "evidence_missing") { return "tool" }
    if (value == "timeout") { return "timeout" }
    "protocol"
}

public func renderDevelopmentClosure(cases: ArrayList<CangjieEvalDevelopmentCaseClosure>): String {
    var passed: Int64 = 0
    var knowledgeCandidates: Int64 = 0
    var rows = ""
    var diagnostics = ""
    var invalidCount: Int64 = 0
    for (i in 0..cases.size) {
        let item = cases[i]
        let confirmationHashValid = triageSha256Format(item.confirmationEvidenceHash)
        let invalid = item.caseId.trimAscii() == "" ||
            (item.developmentPass && item.category != "none") ||
            (item.knowledgeGapConfirmed && (item.developmentPass || item.category != "knowledge_gap" || !confirmationHashValid)) ||
            (!item.knowledgeGapConfirmed && item.confirmationEvidenceHash != "")
        if (invalid) {
            invalidCount += 1
            if (diagnostics != "") { diagnostics += "," }
            diagnostics += "\"case_state_conflict:${triageJsonEscape(item.caseId)}\""
        } else {
            if (item.developmentPass) { passed += 1 }
            if (item.knowledgeGapConfirmed) { knowledgeCandidates += 1 }
        }
        if (i > 0) { rows += "," }
        rows += "{\"caseId\":\"${triageJsonEscape(item.caseId)}\",\"developmentPass\":${item.developmentPass},\"category\":\"${triageJsonEscape(item.category)}\",\"route\":\"${triageJsonEscape(item.route)}\",\"knowledgeGapConfirmed\":${item.knowledgeGapConfirmed},\"confirmationEvidenceHash\":\"${triageJsonEscape(item.confirmationEvidenceHash)}\",\"valid\":${!invalid}}"
    }
    let closed = cases.size > 0 && invalidCount == 0 && passed == cases.size
    "{\"developmentClosed\":${closed},\"developmentPassed\":${passed},\"developmentTotal\":${cases.size},\"knowledgeCandidateCount\":${knowledgeCandidates},\"invalidCaseCount\":${invalidCount},\"diagnostics\":[${diagnostics}],\"certifiedPassAt1\":null,\"certificationStatus\":\"unset\",\"cases\":[${rows}]}"
}

public func cangjieEvalTriageClassifierEvidenceHash(classifierJson: String): String {
    try { triageClassifierEvidenceHash(JsonValue.fromStr(classifierJson.trimAscii()).asObject()) } catch (_: Exception) { "" }
}

public func cangjieEvalTriageResultEvidenceHash(inputJson: String): String {
    try { triageResultEvidenceHash(JsonValue.fromStr(inputJson.trimAscii()).asObject()) } catch (_: Exception) { "" }
}

private func triageCategory(object: JsonObject): String {
    if (triageJsonBool(object, "protocolViolation")) { return "protocol_violation" }
    if (triageJsonBool(object, "timedOut")) { return "timeout" }
    if (triageJsonBool(object, "malformedToolPayload")) { return "malformed_tool_payload" }
    if (triageJsonBool(object, "toolFailure")) { return "tool_error" }
    if (triageJsonBool(object, "emptyModelResponse")) { return "model_empty" }
    if (triageJsonBool(object, "zeroKnowledgeHits")) { return "evidence_missing" }
    if (triageJsonBool(object, "datasetFailure")) { return "dataset_failure" }
    if (triageJsonBool(object, "runnerFailure")) { return "runner_failure" }
    if (triageJsonBool(object, "environmentFailure")) { return "environment_failure" }
    if (triageJsonBool(object, "suspectedKnowledgeGap")) { return "knowledge_gap" }
    if (triageJsonBool(object, "reasoningFailure")) { return "reasoning_failure" }
    let failureType = triageJsonString(object, "failureType").toAsciiLower()
    if (failureType == "compile_error" || failureType == "unit_failure") { return failureType }
    if (triageJsonBool(object, "unitPass") && triageJsonInt(object, "attempt", -1) == 1) { return "none" }
    "reasoning_failure"
}

private func triageK4Eligible(object: JsonObject): Bool {
    let families = HashSet<String>(["syntax", "standard_library", "stdx", "toolchain", "compiler_diagnostic", "version_migration", "engineering_practice"])
    let family = triageJsonString(object, "knowledgeFamily").toAsciiLower()
    let sourceClass = triageJsonString(object, "sourceClass").toAsciiLower()
    let citation = triageJsonString(object, "citation").toAsciiLower()
    if (triageJsonString(object, "canonicalKnowledgeId") == "" || triageJsonString(object, "targetVersion") == "" ||
        triageJsonString(object, "evidenceId") == "" || !families.contains(family) || !triageJsonBool(object, "reusable") ||
        !triageJsonBool(object, "purificationPassed") || !triageJsonBool(object, "positiveTestPassed") ||
        !triageJsonBool(object, "negativeTestPassed") || !triageJsonBool(object, "boundaryTestPassed") || triageForbiddenKnowledgeEvidence(object)) { return false }
    if (sourceClass == "official") { return citation.startsWith("https://docs.cangjie-lang.cn/") }
    if (sourceClass == "approved_trusted") { return citation.startsWith("https://github.com/dyingchinese/cangjie-stdx") }
    false
}

private func triageForbiddenKnowledgeEvidence(object: JsonObject): Bool {
    let raw = triageJsonString(object, "knowledgeText") + "\n" + triageJsonString(object, "exampleText") + "\n" +
        triageJsonString(object, "testText") + "\n" + triageJsonString(object, "publishableMetadata")
    let lowered = raw.toAsciiLower()
    lowered.contains("cj-humaneval-") || lowered.contains("canonical_solution") || lowered.contains("hidden_test") ||
        lowered.contains("hidden assertion") || lowered.contains("teacher-solutions") || lowered.contains("/reference/")
}

private func triageClassifierEvidenceHash(object: JsonObject): String {
    let canonical = triageCanonicalPart(triageJsonString(object, "category").toAsciiLower()) +
        triageCanonicalPart(triageJsonString(object, "caseId")) +
        triageCanonicalPart(triageJsonString(object, "runId")) +
        triageCanonicalPart(triageJsonString(object, "datasetVersion")) +
        triageCanonicalPart("${triageJsonInt(object, "attempt", -1)}") +
        triageCanonicalPart(triageJsonString(object, "runMode").toAsciiLower()) +
        triageCanonicalPart(triageJsonString(object, "resultEvidenceHash").toAsciiLower()) +
        triageCanonicalPart(triageJsonString(object, "failureObservation")) +
        triageCanonicalPart(triageJsonString(object, "knowledgeFamily").toAsciiLower()) +
        triageCanonicalPart("${triageJsonBool(object, "reusable")}") +
        triageCanonicalPart(triageJsonString(object, "sourceClass").toAsciiLower()) +
        triageCanonicalPart(triageJsonString(object, "citation").toAsciiLower()) +
        triageCanonicalPart("${triageJsonBool(object, "purificationPassed")}") +
        triageCanonicalPart(triageJsonString(object, "canonicalKnowledgeId")) +
        triageCanonicalPart(triageJsonString(object, "targetVersion")) +
        triageCanonicalPart(triageJsonString(object, "evidenceId")) +
        triageCanonicalPart("${triageJsonBool(object, "positiveTestPassed")}") +
        triageCanonicalPart("${triageJsonBool(object, "negativeTestPassed")}") +
        triageCanonicalPart("${triageJsonBool(object, "boundaryTestPassed")}") +
        triageCanonicalPart(triageJsonString(object, "knowledgeText")) +
        triageCanonicalPart(triageJsonString(object, "exampleText")) +
        triageCanonicalPart(triageJsonString(object, "testText")) +
        triageCanonicalPart(triageJsonString(object, "publishableMetadata"))
    triageSha256(canonical)
}

private func triageClassifierContractValid(object: JsonObject): Bool {
    let mode = triageJsonString(object, "runMode").toAsciiLower()
    triageKnownCategory(triageJsonString(object, "category")) && triageJsonString(object, "caseId") != "" &&
        triageJsonString(object, "runId") != "" && triageJsonString(object, "datasetVersion") != "" &&
        triageJsonInt(object, "attempt", -1) >= 1 && (mode == "development" || mode == "certification") &&
        triageJsonString(object, "failureObservation") != "" && triageSha256Format(triageJsonString(object, "resultEvidenceHash").toAsciiLower()) &&
        triageSha256Format(triageJsonString(object, "evidenceHash").toAsciiLower())
}
private func triageKnownCategory(category: String): Bool {
    let value = category.toAsciiLower()
    value == "knowledge_gap" || value == "reasoning_failure" || value == "dataset_failure" || value == "runner_failure" ||
        value == "environment_failure" || value == "protocol_violation" || value == "malformed_tool_payload" || value == "tool_error" ||
        value == "evidence_missing" || value == "timeout" || value == "model_empty" || value == "compile_error" || value == "unit_failure" || value == "none"
}

private func triageResultEvidenceHash(object: JsonObject): String {
    let canonical = triageCanonicalPart(triageJsonString(object, "caseId")) + triageCanonicalPart(triageJsonString(object, "runId")) +
        triageCanonicalPart(triageJsonString(object, "datasetVersion")) + triageCanonicalPart("${triageJsonInt(object, "attempt", -1)}") +
        triageCanonicalPart(triageJsonString(object, "runMode").toAsciiLower()) + triageCanonicalPart(triageJsonString(object, "failureObservation")) +
        triageCanonicalPart("${triageJsonBool(object, "protocolViolation")}") + triageCanonicalPart("${triageJsonBool(object, "timedOut")}") +
        triageCanonicalPart("${triageJsonBool(object, "malformedToolPayload")}") + triageCanonicalPart("${triageJsonBool(object, "toolFailure")}") +
        triageCanonicalPart("${triageJsonBool(object, "emptyModelResponse")}") + triageCanonicalPart("${triageJsonBool(object, "zeroKnowledgeHits")}") +
        triageCanonicalPart("${triageJsonBool(object, "datasetFailure")}") + triageCanonicalPart("${triageJsonBool(object, "runnerFailure")}") +
        triageCanonicalPart("${triageJsonBool(object, "environmentFailure")}") + triageCanonicalPart("${triageJsonBool(object, "suspectedKnowledgeGap")}") +
        triageCanonicalPart("${triageJsonBool(object, "reasoningFailure")}") + triageCanonicalPart(triageJsonString(object, "failureType").toAsciiLower()) +
        triageCanonicalPart("${triageJsonBool(object, "unitPass")}")
    triageSha256(canonical)
}
private func triageHasOutcomeSignal(object: JsonObject): Bool {
    triageJsonBool(object, "protocolViolation") || triageJsonBool(object, "timedOut") || triageJsonBool(object, "malformedToolPayload") ||
        triageJsonBool(object, "toolFailure") || triageJsonBool(object, "emptyModelResponse") || triageJsonBool(object, "zeroKnowledgeHits") ||
        triageJsonBool(object, "datasetFailure") || triageJsonBool(object, "runnerFailure") || triageJsonBool(object, "environmentFailure") ||
        triageJsonBool(object, "suspectedKnowledgeGap") || triageJsonBool(object, "reasoningFailure") ||
        triageJsonString(object, "failureType") != "" || triageJsonBool(object, "unitPass") || triageJsonFieldPresent(object, "unitPass")
}
private func triageJsonFieldPresent(object: JsonObject, field: String): Bool { match (object.get(field)) { case Some(_) => true; case None => false } }
private func triageSha256Format(value: String): Bool {
    let runes = value.toRuneArray(); if (runes.size != 71 || !value.startsWith("sha256:")) { return false }
    for (i in 7..71) { let ch = runes[i]; if (!((ch >= r'0' && ch <= r'9') || (ch >= r'a' && ch <= r'f'))) { return false } }
    true
}
private func triageCanonicalPart(value: String): String { "${value.toArray().size}:${value}" }
private func triageSha256(value: String): String {
    let digest = SHA256(); digest.write(value.toArray()); let out = StringBuilder()
    for (byte in digest.finish()) { out.append(triageHex(byte / UInt8(16))); out.append(triageHex(byte % UInt8(16))) }
    "sha256:${out.toString()}"
}
private func triageHex(value: UInt8): String { "0123456789abcdef".toRuneArray()[Int64(value)].toString() }
private func triageJsonString(object: JsonObject, field: String): String { match (object.get(field)) { case Some(value) => value.asString().getValue().trimAscii(); case None => "" } }
private func triageJsonBool(object: JsonObject, field: String): Bool { match (object.get(field)) { case Some(value) => value.asBool().getValue(); case None => false } }
private func triageJsonInt(object: JsonObject, field: String, fallback: Int64): Int64 { match (object.get(field)) { case Some(value) => value.asInt().getValue(); case None => fallback } }
private func triageJsonEscape(value: String): String { value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t") }
