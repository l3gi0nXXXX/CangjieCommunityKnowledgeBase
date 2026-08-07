package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashSet}
import std.fs.{File, Path}
import stdx.encoding.json.*

public class CkbStrictScoreEvidenceRow {
    public var schemaVersion: String = "ckb-humaneval-public-evidence-v1"
    public var caseId: String = ""
    public var runId: String = ""
    public var datasetVersion: String = ""
    public var knowledgeVersion: String = ""
    public var modelFingerprint: String = ""
    public var providerIdentityHash: String = ""
    public var runManifestHash: String = ""
    public var certificationPassAt1: Bool = false
    public var unitFirstSamplePassed: Bool = false
    public var classification: String = ""
    public var sampleAttemptCount: Int64 = 0
    public var selectedBusinessSample: Int64 = 0
    public var transportAttemptCount: Int64 = 0
    public var transportRetryCount: Int64 = 0
    public var unresolvedTransport: Int64 = 0
    public var retryUsed: Bool = false
    public var fallbackUsed: Bool = false
    public var referenceExposure: Int64 = 0
    public var hiddenTestExposure: Int64 = 0
    public var teacherExposure: Int64 = 0
    public var crossCaseExposure: Int64 = 0
    public var generationProtocol: String = "historical-agentic-v1"
    public var assetLineage: String = "historical_agentic"
    public var skillBundleHash: String = ""
    public var rulesHash: String = ""
    public var rulesTreeHash: String = ""
    public var rulesCount: Int64 = 0
    public var basePassed: Bool = false
    public var plusPassed: Bool = false
    public init() {}
}

public class CkbHumanEvalStrictScore {
    public var valid: Bool = false
    public var total: Int64 = 0
    public var strictPassed: Int64 = 0
    public var strictFailed: Int64 = 0
    public var unitFirstSamplePassed: Int64 = 0
    public var businessFailed: Int64 = 0
    public var protocolInvalid: Int64 = 0
    public var transportUnresolved: Int64 = 0
    public var basePassed: Int64 = 0
    public var plusPassed: Int64 = 0
    public var baseMetricName: String = "historical_agentic_base_pass_at_1"
    public var plusMetricName: String = "historical_agentic_plus_pass_at_1"
    public var certificationStatus: String = "historical_agentic_not_strict"
    public var evidenceLevel: String = ""
    public var artifactManifestHash: String = ""
    // Score computation never signs or authorizes a release. P9 owns that decision.
    public var releaseEligible: Bool = false
    public var diagnostic: String = ""
    public init() {}
}

public func computeCkbHumanEvalStrictScore(
    rows: ArrayList<CkbStrictScoreEvidenceRow>
): CkbHumanEvalStrictScore {
    let score = CkbHumanEvalStrictScore()
    score.total = Int64(rows.size)
    score.evidenceLevel = "public_projection"
    if (rows.size != 164) {
        score.diagnostic = "evidence_count_mismatch:${rows.size}:164"
        return score
    }
    let expected = HashSet<String>()
    for (i in 0..164) { expected.add(ckbStrictScoreCaseId(i)) }
    let seen = HashSet<String>()
    let first = rows[0]
    if (!ckbStrictScoreIdentityValid(first)) {
        score.diagnostic = "evidence_identity_invalid:${first.caseId}"
        return score
    }
    for (row in rows) {
        if (!expected.contains(row.caseId)) {
            score.diagnostic = "unexpected_case:${row.caseId}"
            return score
        }
        if (seen.contains(row.caseId)) {
            score.diagnostic = "duplicate_case:${row.caseId}"
            return score
        }
        seen.add(row.caseId)
        if (!ckbStrictScoreIdentityValid(row)) {
            score.diagnostic = "evidence_identity_invalid:${row.caseId}"
            return score
        }
        if (row.runId != first.runId || row.datasetVersion != first.datasetVersion ||
            row.knowledgeVersion != first.knowledgeVersion ||
            row.modelFingerprint != first.modelFingerprint ||
            row.providerIdentityHash != first.providerIdentityHash ||
            row.runManifestHash != first.runManifestHash) {
            score.diagnostic = "evidence_lineage_drift:${row.caseId}"
            return score
        }
        if(row.generationProtocol!=first.generationProtocol){score.diagnostic="generation_protocol_mixed";return score}
        if(first.generationProtocol=="completion-only-v1"&&(row.assetLineage!=first.assetLineage||row.skillBundleHash!=first.skillBundleHash||(first.schemaVersion=="ckb-humaneval-public-evidence-v3"&&(row.rulesHash!=first.rulesHash||row.rulesTreeHash!=first.rulesTreeHash||row.rulesCount!=first.rulesCount)))){
            score.diagnostic="bundle_or_lineage_drift:${row.caseId}";return score
        }
        let unresolved = row.classification == "transport_unresolved"
        let sampleValid = if (unresolved) {
            row.sampleAttemptCount == 0 && row.selectedBusinessSample == 0
        } else {
            row.sampleAttemptCount == 1 &&
                row.selectedBusinessSample == row.transportAttemptCount
        }
        if (row.transportAttemptCount < 1 ||
            row.transportRetryCount != row.transportAttemptCount - 1 ||
            !sampleValid) {
            score.diagnostic = "first_business_sample_invalid:${row.caseId}"
            return score
        }
        if (row.retryUsed || row.fallbackUsed) {
            score.diagnostic = "retry_or_fallback_forbidden:${row.caseId}"
            return score
        }
        let exposure = row.referenceExposure != 0 ||
            row.hiddenTestExposure != 0 || row.teacherExposure != 0 ||
            row.crossCaseExposure != 0
        if (exposure && row.classification != "protocol_invalid") {
            score.diagnostic = "model_exposure_forbidden:${row.caseId}"
            return score
        }
        if (!ckbStrictScoreClassificationValid(row)) {
            score.diagnostic = "classification_closure_invalid:${row.caseId}"
            return score
        }
        if(first.generationProtocol=="completion-only-v1"&&row.certificationPassAt1!=(row.basePassed&&row.plusPassed)){
            score.diagnostic="base_plus_certification_mismatch:${row.caseId}";return score
        }
        if (row.certificationPassAt1) { score.strictPassed += 1 }
        if(row.basePassed){score.basePassed+=1};if(row.plusPassed){score.plusPassed+=1}
        if (row.unitFirstSamplePassed) { score.unitFirstSamplePassed += 1 }
        if (row.classification == "business_failure") { score.businessFailed += 1 }
        if (row.classification == "protocol_invalid") { score.protocolInvalid += 1 }
        if (row.classification == "transport_unresolved") {
            score.transportUnresolved += 1
        }
        if (row.unresolvedTransport !=
            if (row.classification == "transport_unresolved") { 1 } else { 0 }) {
            score.diagnostic = "classification_closure_invalid:${row.caseId}"
            return score
        }
    }
    for (caseId in expected) {
        if (!seen.contains(caseId)) {
            score.diagnostic = "missing_case:${caseId}"
            return score
        }
    }
    score.strictFailed = score.total - score.strictPassed
    if (score.businessFailed + score.protocolInvalid + score.transportUnresolved !=
        score.strictFailed) {
        score.diagnostic = "aggregate_classification_mismatch"
        return score
    }
    if(first.generationProtocol=="completion-only-v1"){
        if(!ckbStrictScoreHash(first.skillBundleHash)||(first.schemaVersion=="ckb-humaneval-public-evidence-v3"&&ckbS4RulesIdentityDiagnostic(first.rulesHash,first.rulesTreeHash,first.rulesCount)!="ok")||(first.assetLineage!="independent"&&first.assetLineage!="humaneval_164_derived")){
            score.diagnostic="completion_lineage_invalid";return score
        }
        let prefix=if(first.assetLineage=="independent"){"strict_ckb_skill"}else{"closed_loop_ckb_skill"}
        score.baseMetricName="${prefix}_base_pass_at_1";score.plusMetricName="${prefix}_plus_pass_at_1"
        score.certificationStatus=if(score.basePassed==164&&score.plusPassed==164&&score.strictPassed==164){"passed"}else{"failed"}
    }
    score.valid = true
    score.diagnostic = "ok"
    score
}

public func computeCkbHumanEvalStrictScoreFromRunRoot(
    runRoot: String,
    authorityManifestText: String,
    rows: ArrayList<CkbStrictScoreEvidenceRow>
): CkbHumanEvalStrictScore {
    let projection = computeCkbHumanEvalStrictScore(rows)
    if (!projection.valid) { return projection }
    let gate = ckbStrictCertificationGateFromRunRoot(runRoot, authorityManifestText)
    let thresholdOnly = !gate.ok && gate.diagnostics.size == 1 &&
        gate.diagnostics[0] == "strict_pass_at_1_requirements_not_met"
    if ((!gate.ok && !thresholdOnly) || !ckbStrictScoreHash(gate.artifactManifestHash)) {
        let failed = CkbHumanEvalStrictScore()
        failed.diagnostic = "private_artifact_certification_invalid"
        return failed
    }
    if (ckbStrictScorePrivateLineageDiagnostic(runRoot, rows[0]) != "ok") {
        let failed = CkbHumanEvalStrictScore()
        failed.diagnostic = "private_projection_lineage_mismatch"
        return failed
    }
    if (gate.total != projection.total ||
        gate.unitPassAt1 != projection.strictPassed ||
        gate.failed != projection.strictFailed ||
        gate.datasetVersion != rows[0].datasetVersion ||
        gate.knowledgeVersion != rows[0].knowledgeVersion ||
        gate.modelFingerprint != rows[0].modelFingerprint) {
        let failed = CkbHumanEvalStrictScore()
        failed.diagnostic = "private_projection_score_mismatch"
        return failed
    }
    projection.evidenceLevel = "private_artifact_certification"
    projection.artifactManifestHash = gate.artifactManifestHash
    projection
}

public func renderCkbHumanEvalStrictScoreJson(score: CkbHumanEvalStrictScore): String {
    "{\"valid\":${score.valid},\"total\":${score.total},\"strictPassed\":${score.strictPassed}," +
        "\"strictFailed\":${score.strictFailed},\"unitFirstSamplePassed\":${score.unitFirstSamplePassed}," +
        "\"businessFailed\":${score.businessFailed},\"protocolInvalid\":${score.protocolInvalid}," +
        "\"transportUnresolved\":${score.transportUnresolved}," +
        "\"basePassed\":${score.basePassed},\"plusPassed\":${score.plusPassed},"+
        "\"baseMetricName\":\"${ckbStrictScoreEscape(score.baseMetricName)}\",\"plusMetricName\":\"${ckbStrictScoreEscape(score.plusMetricName)}\","+
        "\"certificationStatus\":\"${ckbStrictScoreEscape(score.certificationStatus)}\","+
        "\"evidenceLevel\":\"${ckbStrictScoreEscape(score.evidenceLevel)}\"," +
        "\"artifactManifestHash\":\"${ckbStrictScoreEscape(score.artifactManifestHash)}\"," +
        "\"releaseEligible\":${score.releaseEligible}," +
        "\"diagnostic\":\"${ckbStrictScoreEscape(score.diagnostic)}\"}"
}

public func renderCkbStrictScoreEvidenceRowJson(row: CkbStrictScoreEvidenceRow): String {
    let completion=if(row.schemaVersion=="ckb-humaneval-public-evidence-v2"){",\"generationProtocol\":\"${row.generationProtocol}\",\"assetLineage\":\"${row.assetLineage}\",\"skillBundleHash\":\"${row.skillBundleHash}\",\"basePassed\":${row.basePassed},\"plusPassed\":${row.plusPassed}"}else if(row.schemaVersion=="ckb-humaneval-public-evidence-v3"){",\"generationProtocol\":\"${row.generationProtocol}\",\"assetLineage\":\"${row.assetLineage}\",\"skillBundleHash\":\"${row.skillBundleHash}\",\"rulesHash\":\"${row.rulesHash}\",\"rulesTreeHash\":\"${row.rulesTreeHash}\",\"rulesCount\":${row.rulesCount},\"basePassed\":${row.basePassed},\"plusPassed\":${row.plusPassed}"}else{""}
    "{\"schemaVersion\":\"${ckbStrictScoreEscape(row.schemaVersion)}\"," +
        "\"caseId\":\"${ckbStrictScoreEscape(row.caseId)}\"," +
        "\"runId\":\"${ckbStrictScoreEscape(row.runId)}\"," +
        "\"datasetVersion\":\"${ckbStrictScoreEscape(row.datasetVersion)}\"," +
        "\"knowledgeVersion\":\"${ckbStrictScoreEscape(row.knowledgeVersion)}\"," +
        "\"modelFingerprint\":\"${ckbStrictScoreEscape(row.modelFingerprint)}\"," +
        "\"providerIdentityHash\":\"${ckbStrictScoreEscape(row.providerIdentityHash)}\"," +
        "\"runManifestHash\":\"${ckbStrictScoreEscape(row.runManifestHash)}\"," +
        "\"certificationPassAt1\":${row.certificationPassAt1}," +
        "\"unitFirstSamplePassed\":${row.unitFirstSamplePassed}," +
        "\"classification\":\"${ckbStrictScoreEscape(row.classification)}\"," +
        "\"sampleAttemptCount\":${row.sampleAttemptCount}," +
        "\"selectedBusinessSample\":${row.selectedBusinessSample}," +
        "\"transportAttemptCount\":${row.transportAttemptCount}," +
        "\"transportRetryCount\":${row.transportRetryCount}," +
        "\"unresolvedTransport\":${row.unresolvedTransport}," +
        "\"retryUsed\":${row.retryUsed},\"fallbackUsed\":${row.fallbackUsed}," +
        "\"referenceExposure\":${row.referenceExposure}," +
        "\"hiddenTestExposure\":${row.hiddenTestExposure}," +
        "\"teacherExposure\":${row.teacherExposure}," +
        "\"crossCaseExposure\":${row.crossCaseExposure}${completion}}"
}

public func renderCkbStrictScoreEvidenceJsonl(
    rows: ArrayList<CkbStrictScoreEvidenceRow>
): String {
    let out = StringBuilder()
    for (row in rows) {
        out.append(renderCkbStrictScoreEvidenceRowJson(row))
        out.append("\n")
    }
    out.toString()
}

public func parseCkbStrictScoreEvidenceJsonl(bytes: Array<UInt8>): CkbHumanEvalStrictScore {
    let text = try {
        String.fromUtf8(bytes)
    } catch (_: Exception) {
        let failed = CkbHumanEvalStrictScore()
        failed.diagnostic = "invalid_response_encoding"
        return failed
    }
    let rows = ArrayList<CkbStrictScoreEvidenceRow>()
    let lines = text.split("\n")
    for (i in 0..lines.size) {
        let line = lines[i]
        if (line.trimAscii() == "") {
            if (i != lines.size - 1) {
                let failed = CkbHumanEvalStrictScore()
                failed.diagnostic = "empty_evidence_line"
                return failed
            }
            continue
        }
        let parsed = ckbStrictScoreParseRow(line)
        if (parsed[0] != "ok") {
            let failed = CkbHumanEvalStrictScore()
            failed.diagnostic = parsed[0]
            return failed
        }
        rows.add(parsed[1])
    }
    computeCkbHumanEvalStrictScore(rows)
}

public func runCangjieHumanEvalStrictScore(args: Array<String>): Int64 {
    var publicEvidencePath = ""
    var runRoot = ""
    var authorityPath = ""
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "cangjie-humaneval-strict-score") { i += 1; continue }
        if ((arg == "--public-evidence" || arg == "--run-root" || arg == "--manifest") &&
            i + 1 >= args.size) {
            return 2
        }
        if (arg == "--public-evidence") {
            publicEvidencePath = args[i + 1].trimAscii(); i += 2; continue
        }
        if (arg == "--run-root") { runRoot = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--manifest") {
            authorityPath = args[i + 1].trimAscii(); i += 2; continue
        }
        return 2
    }
    if (publicEvidencePath == "" || (runRoot == "") != (authorityPath == "")) { return 2 }
    let bytes = try { File.readFrom(Path(publicEvidencePath)) } catch (_: Exception) { return 1 }
    let projection = parseCkbStrictScoreEvidenceJsonl(bytes)
    if (!projection.valid) { println(renderCkbHumanEvalStrictScoreJson(projection)); return 1 }
    let score = if (runRoot == "") {
        projection
    } else {
        let authority = try {
            String.fromUtf8(File.readFrom(Path(authorityPath)))
        } catch (_: Exception) {
            return 1
        }
        let rows = ckbStrictScoreRowsFromUtf8(bytes)
        if (rows[0] != "ok") { return 1 }
        computeCkbHumanEvalStrictScoreFromRunRoot(runRoot, authority, rows[1])
    }
    println(renderCkbHumanEvalStrictScoreJson(score))
    if (score.valid) { 0 } else { 1 }
}

private func ckbStrictScoreRowsFromUtf8(
    bytes: Array<UInt8>
): (String, ArrayList<CkbStrictScoreEvidenceRow>) {
    let rows = ArrayList<CkbStrictScoreEvidenceRow>()
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return ("invalid_response_encoding", rows)
    }
    let lines = text.split("\n")
    for (i in 0..lines.size) {
        let line = lines[i]
        if (line.trimAscii() == "") {
            if (i != lines.size - 1) { return ("empty_evidence_line", rows) }
            continue
        }
        let parsed = ckbStrictScoreParseRow(line)
        if (parsed[0] != "ok") { return (parsed[0], rows) }
        rows.add(parsed[1])
    }
    ("ok", rows)
}

private func ckbStrictScoreParseRow(raw: String): (String, CkbStrictScoreEvidenceRow) {
    let row = CkbStrictScoreEvidenceRow()
    try {
        let object = JsonValue.fromStr(raw).asObject()
        row.schemaVersion = ckbStrictScoreString(object, "schemaVersion")
        let fields = ArrayList<String>()
        for(field in [
            "schemaVersion", "caseId", "runId", "datasetVersion", "knowledgeVersion",
            "modelFingerprint", "providerIdentityHash", "runManifestHash",
            "certificationPassAt1", "unitFirstSamplePassed", "classification",
            "sampleAttemptCount", "selectedBusinessSample", "transportAttemptCount",
            "transportRetryCount", "unresolvedTransport", "retryUsed", "fallbackUsed",
            "referenceExposure", "hiddenTestExposure", "teacherExposure", "crossCaseExposure"
        ]){fields.add(field)}
        if(row.schemaVersion=="ckb-humaneval-public-evidence-v2"){
            for(field in ["generationProtocol","assetLineage","skillBundleHash","basePassed","plusPassed"]){fields.add(field)}
        }else if(row.schemaVersion=="ckb-humaneval-public-evidence-v3"){
            for(field in ["generationProtocol","assetLineage","skillBundleHash","rulesHash","rulesTreeHash","rulesCount","basePassed","plusPassed"]){fields.add(field)}
        }
        if (object.getFields().size != fields.size ||
            !ckbStrictScoreUniqueFields(raw, fields.toArray())) {
            return ("public_evidence_unknown_or_duplicate_field", row)
        }
        row.caseId = ckbStrictScoreString(object, "caseId")
        row.runId = ckbStrictScoreString(object, "runId")
        row.datasetVersion = ckbStrictScoreString(object, "datasetVersion")
        row.knowledgeVersion = ckbStrictScoreString(object, "knowledgeVersion")
        row.modelFingerprint = ckbStrictScoreString(object, "modelFingerprint")
        row.providerIdentityHash = ckbStrictScoreString(object, "providerIdentityHash")
        row.runManifestHash = ckbStrictScoreString(object, "runManifestHash")
        row.certificationPassAt1 = ckbStrictScoreBool(object, "certificationPassAt1")
        row.unitFirstSamplePassed = ckbStrictScoreBool(object, "unitFirstSamplePassed")
        row.classification = ckbStrictScoreString(object, "classification")
        row.sampleAttemptCount = ckbStrictScoreInt(object, "sampleAttemptCount")
        row.selectedBusinessSample = ckbStrictScoreInt(object, "selectedBusinessSample")
        row.transportAttemptCount = ckbStrictScoreInt(object, "transportAttemptCount")
        row.transportRetryCount = ckbStrictScoreInt(object, "transportRetryCount")
        row.unresolvedTransport = ckbStrictScoreInt(object, "unresolvedTransport")
        row.retryUsed = ckbStrictScoreBool(object, "retryUsed")
        row.fallbackUsed = ckbStrictScoreBool(object, "fallbackUsed")
        row.referenceExposure = ckbStrictScoreInt(object, "referenceExposure")
        row.hiddenTestExposure = ckbStrictScoreInt(object, "hiddenTestExposure")
        row.teacherExposure = ckbStrictScoreInt(object, "teacherExposure")
        row.crossCaseExposure = ckbStrictScoreInt(object, "crossCaseExposure")
        if(row.schemaVersion=="ckb-humaneval-public-evidence-v2"){
            row.generationProtocol=ckbStrictScoreString(object,"generationProtocol");row.assetLineage=ckbStrictScoreString(object,"assetLineage");row.skillBundleHash=ckbStrictScoreString(object,"skillBundleHash");row.basePassed=ckbStrictScoreBool(object,"basePassed");row.plusPassed=ckbStrictScoreBool(object,"plusPassed")
        }else if(row.schemaVersion=="ckb-humaneval-public-evidence-v3"){
            row.generationProtocol=ckbStrictScoreString(object,"generationProtocol");row.assetLineage=ckbStrictScoreString(object,"assetLineage");row.skillBundleHash=ckbStrictScoreString(object,"skillBundleHash");row.rulesHash=ckbStrictScoreString(object,"rulesHash");row.rulesTreeHash=ckbStrictScoreString(object,"rulesTreeHash");row.rulesCount=ckbStrictScoreInt(object,"rulesCount");row.basePassed=ckbStrictScoreBool(object,"basePassed");row.plusPassed=ckbStrictScoreBool(object,"plusPassed")
        }
    } catch (_: Exception) {
        return ("malformed_json", row)
    }
    if((row.schemaVersion=="ckb-humaneval-public-evidence-v2"||row.schemaVersion=="ckb-humaneval-public-evidence-v3")&&raw!=renderCkbStrictScoreEvidenceRowJson(row)){return ("public_evidence_non_canonical",row)}
    ("ok", row)
}

private func ckbStrictScoreIdentityValid(row: CkbStrictScoreEvidenceRow): Bool {
    (row.schemaVersion == "ckb-humaneval-public-evidence-v1"||row.schemaVersion=="ckb-humaneval-public-evidence-v2"||row.schemaVersion=="ckb-humaneval-public-evidence-v3") &&
        row.caseId != "" && row.runId != "" && row.datasetVersion != "" &&
        row.knowledgeVersion != "" && row.modelFingerprint != "" &&
        ckbStrictScoreHash(row.providerIdentityHash) &&
        ckbStrictScoreHash(row.runManifestHash)
}

private func ckbStrictScorePrivateLineageDiagnostic(
    runRoot: String,
    projection: CkbStrictScoreEvidenceRow
): String {
    let text = try {
        String.fromUtf8(File.readFrom(Path(runRoot).join("results.jsonl")))
    } catch (_: Exception) {
        return "private_results_unreadable"
    }
    for (line in text.split("\n")) {
        if (line.trimAscii() == "") { continue }
        let row = parseCkbCertificationEvidence(line)
        if (!row.valid) { return "private_result_invalid" }
        if (row.runId != projection.runId ||
            row.datasetVersion != projection.datasetVersion ||
            row.knowledgeVersion != projection.knowledgeVersion ||
            row.modelFingerprint != projection.modelFingerprint ||
            row.providerIdentityHash != projection.providerIdentityHash ||
            row.runManifestHash != projection.runManifestHash) {
            return "private_projection_lineage_mismatch"
        }
        return "ok"
    }
    "private_results_empty"
}

private func ckbStrictScoreClassificationValid(row: CkbStrictScoreEvidenceRow): Bool {
    if (row.certificationPassAt1) {
        return row.unitFirstSamplePassed && row.classification == "none" &&
            row.unresolvedTransport == 0
    }
    if (row.classification == "business_failure") {
        return !row.unitFirstSamplePassed && row.unresolvedTransport == 0
    }
    if (row.classification == "protocol_invalid") {
        return row.unresolvedTransport == 0
    }
    if (row.classification == "transport_unresolved") {
        return !row.unitFirstSamplePassed && row.unresolvedTransport == 1
    }
    false
}

private func ckbStrictScoreUniqueFields(raw: String, fields: Array<String>): Bool {
    for (field in fields) {
        if (raw.split("\"${field}\"").size != 2) { return false }
    }
    true
}

private func ckbStrictScoreString(object: JsonObject, key: String): String {
    object.get(key).getOrThrow().asString().getValue()
}

private func ckbStrictScoreInt(object: JsonObject, key: String): Int64 {
    object.get(key).getOrThrow().asInt().getValue()
}

private func ckbStrictScoreBool(object: JsonObject, key: String): Bool {
    object.get(key).getOrThrow().asBool().getValue()
}

private func ckbStrictScoreHash(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 71 || !value.startsWith("sha256:")) { return false }
    for (i in 7..71) {
        let rune = runes[i]
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) {
            return false
        }
    }
    true
}

private func ckbStrictScoreCaseId(i: Int64): String {
    if (i < 10) { "CJ-HUMANEVAL-00${i}" }
    else if (i < 100) { "CJ-HUMANEVAL-0${i}" }
    else { "CJ-HUMANEVAL-${i}" }
}

private func ckbStrictScoreEscape(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")
        .replace("\r", "\\r").replace("\t", "\\t")
}
