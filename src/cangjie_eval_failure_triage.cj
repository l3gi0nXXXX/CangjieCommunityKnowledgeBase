package cangjie_community_knowledge_base

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
        if (attempt < 1 || (runMode != "development" && runMode != "certification")) {
            result.diagnostic = "field_contract_invalid"; return result
        }
        result.category = triageCategory(object)
        result.route = routeNonKnowledgeFailure(result.category)
        result.evidenceHash = cangjieEvalTriageEvidenceHash(raw)
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
    for (i in 0..cases.size) {
        let item = cases[i]
        if (item.developmentPass) { passed += 1 }
        if (item.category == "knowledge_gap") { knowledgeCandidates += 1 }
        if (i > 0) { rows += "," }
        rows += "{\"caseId\":\"${triageJsonEscape(item.caseId)}\",\"developmentPass\":${item.developmentPass},\"category\":\"${triageJsonEscape(item.category)}\",\"route\":\"${triageJsonEscape(item.route)}\"}"
    }
    let closed = cases.size > 0 && passed == cases.size
    "{\"developmentClosed\":${closed},\"developmentPassed\":${passed},\"developmentTotal\":${cases.size},\"knowledgeCandidateCount\":${knowledgeCandidates},\"certifiedPassAt1\":null,\"certificationStatus\":\"unset\",\"cases\":[${rows}]}"
}

public func cangjieEvalTriageClassifierEvidenceHash(classifierJson: String): String {
    try { triageClassifierEvidenceHash(JsonValue.fromStr(classifierJson.trimAscii()).asObject()) } catch (_: Exception) { "" }
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
        !triageJsonBool(object, "negativeTestPassed") || !triageJsonBool(object, "boundaryTestPassed") || triageForbiddenKnowledgeEvidence(object.toString())) { return false }
    if (sourceClass == "official") { return citation.startsWith("https://docs.cangjie-lang.cn/") }
    if (sourceClass == "approved_trusted") { return citation.startsWith("https://github.com/dyingchinese/cangjie-stdx") }
    false
}

private func triageForbiddenKnowledgeEvidence(raw: String): Bool {
    let lowered = raw.toAsciiLower()
    lowered.contains("cj-humaneval-") || lowered.contains("canonical_solution") || lowered.contains("hidden_test") ||
        lowered.contains("hidden assertion") || lowered.contains("teacher-solutions") || lowered.contains("/reference/")
}

private func triageClassifierEvidenceHash(object: JsonObject): String {
    let canonical = triageCanonicalPart("${triageJsonInt(object, "attempt", -1)}") +
        triageCanonicalPart(triageJsonString(object, "runMode").toAsciiLower()) +
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
        triageCanonicalPart("${triageJsonBool(object, "boundaryTestPassed")}")
    triageSha256(canonical)
}

private func cangjieEvalTriageEvidenceHash(raw: String): String { triageSha256(raw.trimAscii()) }
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
