package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.sort.*

public class CkbPublicEvidenceProjectionResult {
    public var ok: Bool = false
    public var diagnostic: String = ""
    public var row: CkbStrictScoreEvidenceRow = CkbStrictScoreEvidenceRow()
    public init() {}
}

public class CkbPublicEvidenceLeakageReport {
    public var ok: Bool = false
    public var diagnostic: String = ""
    public var findingCodes: ArrayList<String> = ArrayList<String>()
    public init() {}
}

public class CkbPublicEvidenceRenderResult {
    public var ok: Bool = false
    public var diagnostic: String = ""
    public var text: String = ""
    public var evidenceHash: String = ""
    public var score: CkbHumanEvalStrictScore = CkbHumanEvalStrictScore()
    public init() {}
}

public class CkbPublicEvidenceScoreComparison {
    public var ok: Bool = false
    public var diagnostic: String = ""
    public init() {}
}

public func projectCkbPublicEvidenceRow(
    certificationBytes: Array<UInt8>,
    auditBytes: Array<UInt8>
): CkbPublicEvidenceProjectionResult {
    let result = CkbPublicEvidenceProjectionResult()
    let certificationText = try {
        String.fromUtf8(certificationBytes)
    } catch (_: Exception) {
        result.diagnostic = "invalid_certification_encoding"
        return result
    }
    let auditText = try {
        String.fromUtf8(auditBytes)
    } catch (_: Exception) {
        result.diagnostic = "invalid_audit_encoding"
        return result
    }
    let certification = parseCkbCertificationEvidence(certificationText.trimAscii())
    if (!certification.valid) {
        result.diagnostic = "certification_${certification.diagnostic}"
        return result
    }
    let audits = parseCkbCdGapAuditResults(auditText)
    if (audits.size != 1) {
        result.diagnostic = "audit_row_count_mismatch:${audits.size}:1"
        return result
    }
    let audit = audits[0]
    if (!audit.ok) {
        result.diagnostic = "audit_${audit.diagnostic}"
        return result
    }
    if (audit.runMode != "certification") {
        result.diagnostic = "audit_requires_certification_mode"
        return result
    }
    if (certification.caseId != audit.caseId || certification.group != audit.group) {
        result.diagnostic = "case_identity_mismatch"
        return result
    }
    if (certification.datasetVersion != audit.datasetVersion ||
        certification.knowledgeVersion != audit.knowledgeVersion) {
        result.diagnostic = "knowledge_identity_mismatch"
        return result
    }
    if ((certification.certificationPassAt1 &&
            (!audit.unitPassAt1 || audit.protocolViolation)) ||
        (!certification.certificationPassAt1 &&
            audit.unitPassAt1 && !audit.protocolViolation)) {
        result.diagnostic = "certification_audit_outcome_mismatch"
        return result
    }

    let row = CkbStrictScoreEvidenceRow()
    row.caseId = certification.caseId
    row.runId = certification.runId
    row.datasetVersion = certification.datasetVersion
    row.knowledgeVersion = certification.knowledgeVersion
    row.modelFingerprint = certification.modelFingerprint
    row.providerIdentityHash = certification.providerIdentityHash
    row.runManifestHash = certification.runManifestHash
    row.certificationPassAt1 = certification.certificationPassAt1
    row.unitFirstSamplePassed = audit.unitPassAt1
    row.sampleAttemptCount = certification.sampleAttemptCount
    row.selectedBusinessSample = certification.selectedBusinessSample
    row.transportAttemptCount = certification.transportAttemptCount
    row.transportRetryCount = certification.retryCount
    row.unresolvedTransport = certification.unresolvedTransport
    row.retryUsed = certification.retryUsed
    row.fallbackUsed = certification.fallbackUsed
    row.referenceExposure = certification.referenceExposure
    row.hiddenTestExposure = certification.hiddenTestExposure
    row.teacherExposure = certification.teacherExposure
    row.crossCaseExposure = certification.crossCaseExposure
    row.classification = ckbPublicEvidenceClassification(certification, audit)
    if (!ckbPublicEvidenceSingleRowValid(row)) {
        result.diagnostic = "projected_row_invalid"
        return result
    }
    result.row = row
    result.ok = true
    result.diagnostic = "ok"
    result
}

public func scanCkbPublicEvidenceLeakage(
    bytes: Array<UInt8>
): CkbPublicEvidenceLeakageReport {
    let report = CkbPublicEvidenceLeakageReport()
    let text = try {
        String.fromUtf8(bytes)
    } catch (_: Exception) {
        report.diagnostic = "invalid_response_encoding"
        return report
    }
    let lower = text.toAsciiLower()
    ckbPublicEvidenceFinding(report, lower.contains("authorization:"),
        "authorization_header")
    ckbPublicEvidenceFinding(report,
        lower.contains("api_key") || lower.contains("apikey") ||
            lower.contains("x-api-key") || lower.contains("bearer "),
        "credential")
    ckbPublicEvidenceFinding(report,
        text.contains("/Users/") || text.contains("/home/") ||
            text.contains("\\\\Users\\\\"),
        "absolute_path")
    ckbPublicEvidenceFinding(report,
        lower.contains("\"prompt\"") || lower.contains("\"prompttext\""),
        "prompt_body")
    ckbPublicEvidenceFinding(report,
        lower.contains("\"solution\"") || lower.contains("\"answerbody\"") ||
            lower.contains("\"studentanswer\"") || lower.contains("\"teacheranswer\""),
        "solution_body")
    ckbPublicEvidenceFinding(report, lower.contains("\"transcript\""),
        "transcript_body")
    ckbPublicEvidenceFinding(report,
        lower.contains("\"hiddentest\"") || lower.contains("\"hiddentests\"") ||
            lower.contains("\"testbody\"") || lower.contains("\"visibletest\""),
        "test_body")
    ckbPublicEvidenceFinding(report,
        lower.contains("\"sessionid\"") || lower.contains("\"workspaceid\"") ||
            lower.contains("\"runtimehomeid\""),
        "private_runtime_identity")
    report.ok = report.findingCodes.size == 0
    report.diagnostic = if (report.ok) { "ok" } else { "sensitive_content_detected" }
    report
}

public func renderCkbPublicEvidence(
    rows: ArrayList<CkbStrictScoreEvidenceRow>
): CkbPublicEvidenceRenderResult {
    let result = CkbPublicEvidenceRenderResult()
    let ordered = ckbPublicEvidenceCanonicalRows(rows)
    let score = computeCkbHumanEvalStrictScore(ordered)
    result.score = score
    if (!score.valid) {
        result.diagnostic = score.diagnostic
        return result
    }
    let text = renderCkbStrictScoreEvidenceJsonl(ordered)
    let leakage = scanCkbPublicEvidenceLeakage(text.toArray())
    if (!leakage.ok) {
        result.diagnostic = leakage.diagnostic
        return result
    }
    let reparsed = parseCkbStrictScoreEvidenceJsonl(text.toArray())
    if (!reparsed.valid ||
        compareCkbPrivateAndPublicScores(score, reparsed, ordered[0], ordered[0])
            .diagnostic != "ok") {
        result.diagnostic = "render_roundtrip_mismatch"
        return result
    }
    result.text = text
    result.evidenceHash = benchmarkGapSha256(text)
    result.score = reparsed
    result.ok = true
    result.diagnostic = "ok"
    result
}

public func compareCkbPrivateAndPublicScores(
    privateScore: CkbHumanEvalStrictScore,
    publicScore: CkbHumanEvalStrictScore,
    privateIdentity: CkbStrictScoreEvidenceRow,
    publicIdentity: CkbStrictScoreEvidenceRow
): CkbPublicEvidenceScoreComparison {
    let result = CkbPublicEvidenceScoreComparison()
    if (!privateScore.valid || !publicScore.valid) {
        result.diagnostic = "score_invalid"
        return result
    }
    if (!ckbPublicEvidenceIdentityEqual(privateIdentity, publicIdentity)) {
        result.diagnostic = "identity_mismatch"
        return result
    }
    if (privateScore.total != publicScore.total ||
        privateScore.strictPassed != publicScore.strictPassed ||
        privateScore.strictFailed != publicScore.strictFailed ||
        privateScore.unitFirstSamplePassed != publicScore.unitFirstSamplePassed ||
        privateScore.businessFailed != publicScore.businessFailed ||
        privateScore.protocolInvalid != publicScore.protocolInvalid ||
        privateScore.transportUnresolved != publicScore.transportUnresolved) {
        result.diagnostic = "score_mismatch"
        return result
    }
    result.ok = true
    result.diagnostic = "ok"
    result
}

private func ckbPublicEvidenceClassification(
    certification: CkbCertificationCaseEvidence,
    audit: CkbCdGapAuditResultRow
): String {
    if (certification.certificationPassAt1) { return "none" }
    if (certification.unresolvedTransport == 1) { return "transport_unresolved" }
    if (audit.protocolViolation ||
        audit.failureRoute.toAsciiLower().contains("protocol") ||
        audit.failureType.toAsciiLower().contains("protocol")) {
        return "protocol_invalid"
    }
    "business_failure"
}

private func ckbPublicEvidenceSingleRowValid(row: CkbStrictScoreEvidenceRow): Bool {
    if (row.caseId == "" || row.runId == "" || row.datasetVersion == "" ||
        row.knowledgeVersion == "" || row.modelFingerprint == "" ||
        !row.providerIdentityHash.startsWith("sha256:") ||
        !row.runManifestHash.startsWith("sha256:")) {
        return false
    }
    if (row.transportAttemptCount < 1 ||
        row.transportRetryCount != row.transportAttemptCount - 1 ||
        row.retryUsed || row.fallbackUsed ||
        row.referenceExposure != 0 || row.hiddenTestExposure != 0 ||
        row.teacherExposure != 0 || row.crossCaseExposure != 0) {
        return false
    }
    if (row.classification == "transport_unresolved") {
        return row.sampleAttemptCount == 0 && row.selectedBusinessSample == 0 &&
            row.unresolvedTransport == 1 && !row.certificationPassAt1 &&
            !row.unitFirstSamplePassed
    }
    if (row.sampleAttemptCount != 1 ||
        row.selectedBusinessSample != row.transportAttemptCount ||
        row.unresolvedTransport != 0) {
        return false
    }
    if (row.classification == "none") {
        return row.certificationPassAt1 && row.unitFirstSamplePassed
    }
    if (row.classification == "business_failure") {
        return !row.certificationPassAt1 && !row.unitFirstSamplePassed
    }
    if (row.classification == "protocol_invalid") {
        return !row.certificationPassAt1
    }
    false
}

private func ckbPublicEvidenceCanonicalRows(
    rows: ArrayList<CkbStrictScoreEvidenceRow>
): ArrayList<CkbStrictScoreEvidenceRow> {
    let caseIds = ArrayList<String>()
    for (row in rows) { caseIds.add(row.caseId) }
    let orderedIds = caseIds.toArray()
    sort(orderedIds)
    let ordered = ArrayList<CkbStrictScoreEvidenceRow>()
    for (caseId in orderedIds) {
        for (row in rows) {
            if (row.caseId == caseId) {
                ordered.add(row)
                break
            }
        }
    }
    ordered
}

private func ckbPublicEvidenceFinding(
    report: CkbPublicEvidenceLeakageReport,
    matched: Bool,
    code: String
): Unit {
    if (matched) { report.findingCodes.add(code) }
}

private func ckbPublicEvidenceIdentityEqual(
    left: CkbStrictScoreEvidenceRow,
    right: CkbStrictScoreEvidenceRow
): Bool {
    left.runId == right.runId &&
        left.datasetVersion == right.datasetVersion &&
        left.knowledgeVersion == right.knowledgeVersion &&
        left.modelFingerprint == right.modelFingerprint &&
        left.providerIdentityHash == right.providerIdentityHash &&
        left.runManifestHash == right.runManifestHash
}
