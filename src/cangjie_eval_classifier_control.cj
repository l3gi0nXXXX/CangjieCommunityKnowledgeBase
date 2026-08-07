package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.convert.Parsable
import std.env.getVariable
import std.fs.{Directory, File, Path, exists, canonicalize}
import std.process.launch
import stdx.encoding.json.*

private let CKB_P5_CLASSIFIER_SCHEMA = "ckb-p5-classifier-v1"
private let CKB_P5_RESPONSE_SCHEMA = "ckb-p5-classifier-response-v1"
private let CKB_P5_REQUEST_SCHEMA = "ckb-p5-classifier-request-v1"

public let CKB_COMPLETION_FAILURE_FIXTURE_HASH = "f08453591302a46c4acc04c43d9bdf456679fae27b354bbca7ebecb194c1e773"
public let CKB_COMPLETION_FAILURE_CLASSIFICATION_FIXTURE_HASH = "1ff85ffec78c69504a2f98146daebb75557d340b6366e92875c4c1acd4b44a16"
public let CKB_COMPLETION_FAILURE_ASSET_CLASSIFICATION_FIXTURE_HASH = "5fa4aa906f5a147d220372cbb67533565ac7222419bf6f7c462cc476c0a31768"

public class CkbCompletionFailure {
    public var schemaVersion = "ckb-completion-failure-v1"
    public var runId = ""
    public var caseId = ""
    public var datasetVersion = ""
    public var generationProtocol = "completion-only-v1"
    public var completionHash = ""
    public var baseStatus = ""
    public var plusStatus = ""
    public var failureKind = ""
    public var failureObservation = ""
    public var assetLineage = ""
    public var evidenceHash = ""
    public init() {}
}

public class CkbCompletionFailureClassification {
    public var schemaVersion = "ckb-completion-failure-classification-v1"
    public var failureEvidenceHash = ""
    public var gapKind = ""
    public var knowledgeEligible = false
    public var skillEligible = false
    public var classificationEvidenceHash = ""
    public init() {}
}

public class CkbCompletionFailureAssetClassification {
    public var schemaVersion = "ckb-completion-failure-classification-v2"
    public var failureEvidenceHash = ""
    public var gapKind = ""
    public var knowledgeEligible = false
    public var skillEligible = false
    public var rulesEligible = false
    public var classificationReasonCode = ""
    public var classificationEvidenceHash = ""
    public init() {}
}

public func sealCkbCompletionFailure(row: CkbCompletionFailure): String {
    let diagnostic = ckbCompletionFailureDiagnostic(row, false)
    if (diagnostic != "ok") { return diagnostic }
    row.failureObservation = utf8SafePrefix(redactSensitive(row.failureObservation), 1024)
    if (ckbCompletionFailureObservationForbidden(row.failureObservation)) {
        return "protected_failure_observation"
    }
    row.evidenceHash = ckbCompletionHexHash(ckbCompletionFailureCanonical(row, false))
    "ok"
}

public func renderCkbCompletionFailure(row: CkbCompletionFailure): String {
    ckbCompletionFailureCanonical(row, true)
}

public func parseCkbCompletionFailure(bytes: Array<UInt8>): (CkbCompletionFailure, String) {
    let row = CkbCompletionFailure()
    let raw = try { String.fromUtf8(bytes) } catch (_: Exception) { return (row, "invalid_response_encoding") }
    try {
        let object = JsonValue.fromStr(raw.trimAscii()).asObject()
        let keys = ["schemaVersion", "runId", "caseId", "datasetVersion", "generationProtocol",
            "completionHash", "baseStatus", "plusStatus", "failureKind", "failureObservation",
            "assetLineage", "evidenceHash"]
        if (object.getFields().size != keys.size || !ckbCompletionUniqueFields(raw, keys)) {
            return (row, "failure_schema_fields_invalid")
        }
        row.schemaVersion=ckbP5String(object,"schemaVersion");row.runId=ckbP5String(object,"runId")
        row.caseId=ckbP5String(object,"caseId");row.datasetVersion=ckbP5String(object,"datasetVersion")
        row.generationProtocol=ckbP5String(object,"generationProtocol");row.completionHash=ckbP5String(object,"completionHash")
        row.baseStatus=ckbP5String(object,"baseStatus");row.plusStatus=ckbP5String(object,"plusStatus")
        row.failureKind=ckbP5String(object,"failureKind");row.failureObservation=ckbP5String(object,"failureObservation")
        row.assetLineage=ckbP5String(object,"assetLineage");row.evidenceHash=ckbP5String(object,"evidenceHash")
        (row, ckbCompletionFailureDiagnostic(row, true))
    } catch (_: Exception) { (row, "malformed_json") }
}

public func parseCkbCompletionFailureClassification(bytes: Array<UInt8>):
    (CkbCompletionFailureClassification, String) {
    let row = CkbCompletionFailureClassification()
    let raw = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (row, "invalid_response_encoding")
    }
    if(raw!=raw.trimAscii()){return(row,"classification_schema_fields_invalid")}
    try {
        let object = JsonValue.fromStr(raw.trimAscii()).asObject()
        let keys = ["schemaVersion", "failureEvidenceHash", "gapKind", "knowledgeEligible",
            "skillEligible", "classificationEvidenceHash"]
        if (object.getFields().size != keys.size || !ckbCompletionUniqueFields(raw, keys)) {
            return (row, "classification_schema_fields_invalid")
        }
        row.schemaVersion=ckbP5String(object,"schemaVersion")
        row.failureEvidenceHash=ckbP5String(object,"failureEvidenceHash")
        row.gapKind=ckbP5String(object,"gapKind")
        row.knowledgeEligible=ckbP5Bool(object,"knowledgeEligible")
        row.skillEligible=ckbP5Bool(object,"skillEligible")
        row.classificationEvidenceHash=ckbP5String(object,"classificationEvidenceHash")
        let diagnostic=ckbCompletionFailureClassificationDiagnostic(row, true)
        if(diagnostic!="ok"){return(row,diagnostic)}
        if(ckbCompletionFailureClassificationCanonical(row,true)!=raw){
            return(row,"classification_schema_fields_invalid")
        }
        (row, "ok")
    } catch (_: Exception) { (row, "malformed_json") }
}

public func parseCkbCompletionFailureAssetClassification(bytes: Array<UInt8>):
    (CkbCompletionFailureAssetClassification, String) {
    let row = CkbCompletionFailureAssetClassification()
    let raw = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (row, "invalid_response_encoding")
    }
    if(raw!=raw.trimAscii()){return(row,"classification_schema_fields_invalid")}
    try {
        let object = JsonValue.fromStr(raw).asObject()
        let keys = ["schemaVersion", "failureEvidenceHash", "gapKind", "knowledgeEligible",
            "skillEligible", "rulesEligible", "classificationReasonCode",
            "classificationEvidenceHash"]
        if (object.getFields().size != keys.size || !ckbCompletionUniqueFields(raw, keys)) {
            return (row, "classification_schema_fields_invalid")
        }
        row.schemaVersion=ckbP5String(object,"schemaVersion")
        row.failureEvidenceHash=ckbP5String(object,"failureEvidenceHash")
        row.gapKind=ckbP5String(object,"gapKind")
        row.knowledgeEligible=ckbP5Bool(object,"knowledgeEligible")
        row.skillEligible=ckbP5Bool(object,"skillEligible")
        row.rulesEligible=ckbP5Bool(object,"rulesEligible")
        row.classificationReasonCode=ckbP5String(object,"classificationReasonCode")
        row.classificationEvidenceHash=ckbP5String(object,"classificationEvidenceHash")
        let diagnostic=ckbCompletionFailureAssetClassificationDiagnostic(row, true)
        if(diagnostic!="ok"){return(row,diagnostic)}
        if(ckbCompletionFailureAssetClassificationCanonical(row,true)!=raw){
            return(row,"classification_schema_fields_invalid")
        }
        (row, "ok")
    } catch (_: Exception) { (row, "malformed_json") }
}

public func sealCkbCompletionFailureClassification(row: CkbCompletionFailureClassification): String {
    let diagnostic = ckbCompletionFailureClassificationDiagnostic(row, false)
    if (diagnostic != "ok") { return diagnostic }
    row.classificationEvidenceHash = ckbCompletionHexHash(
        ckbCompletionFailureClassificationCanonical(row, false))
    "ok"
}

public func renderCkbCompletionFailureClassification(row: CkbCompletionFailureClassification): String {
    ckbCompletionFailureClassificationCanonical(row, true)
}

public func sealCkbCompletionFailureAssetClassification(
    row: CkbCompletionFailureAssetClassification): String {
    let diagnostic = ckbCompletionFailureAssetClassificationDiagnostic(row, false)
    if (diagnostic != "ok") { return diagnostic }
    row.classificationEvidenceHash = ckbCompletionHexHash(
        ckbCompletionFailureAssetClassificationCanonical(row, false))
    "ok"
}

public func renderCkbCompletionFailureAssetClassification(
    row: CkbCompletionFailureAssetClassification): String {
    ckbCompletionFailureAssetClassificationCanonical(row, true)
}

public func ckbFailureAssetOutputKind(row: CkbCompletionFailureAssetClassification): String {
    if (row.knowledgeEligible) {
        if (row.skillEligible) {
            return if (row.rulesEligible) { "all" } else { "knowledge_skill" }
        }
        return if (row.rulesEligible) { "knowledge_rules" } else { "knowledge" }
    }
    if (row.skillEligible) {
        return if (row.rulesEligible) { "skill_rules" } else { "skill" }
    }
    if (row.rulesEligible) { "rules" } else { "none" }
}

public func ckbFailureAssetOutputKind(row: CkbCompletionFailureClassification): String {
    if (row.knowledgeEligible) {
        return if (row.skillEligible) { "knowledge_skill" } else { "knowledge" }
    }
    if (row.skillEligible) { "skill" } else { "none" }
}

public func ckbCompletionFailureFixtureJsonl(): String {
    "{\"schemaVersion\":\"ckb-completion-failure-v1\",\"runId\":\"recert-fixture-run\",\"caseId\":\"CJ-HUMANEVAL-007\",\"datasetVersion\":\"cangjie-humaneval-164-v1\",\"generationProtocol\":\"completion-only-v1\",\"completionHash\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"baseStatus\":\"failed\",\"plusStatus\":\"failed\",\"failureKind\":\"test_failure\",\"failureObservation\":\"student_completion_test_failed 中文😀\",\"assetLineage\":\"independent\",\"evidenceHash\":\"${CKB_COMPLETION_FAILURE_FIXTURE_HASH}\"}\n" +
    "{\"schemaVersion\":\"ckb-completion-failure-classification-v1\",\"failureEvidenceHash\":\"${CKB_COMPLETION_FAILURE_FIXTURE_HASH}\",\"gapKind\":\"mixed_gap\",\"knowledgeEligible\":true,\"skillEligible\":true,\"classificationEvidenceHash\":\"${CKB_COMPLETION_FAILURE_CLASSIFICATION_FIXTURE_HASH}\"}\n"
}

private func ckbCompletionFailureDiagnostic(row:CkbCompletionFailure,verifyHash:Bool):String{
    if(row.schemaVersion!="ckb-completion-failure-v1"||row.runId==""||row.datasetVersion==""||
        row.generationProtocol!="completion-only-v1"||!ckbCompletionCaseId(row.caseId)||
        !ckbCompletionHash(row.completionHash)){return "failure_identity_invalid"}
    if(!ckbCompletionOneOf(row.baseStatus,["passed","failed","timeout","infra_error"])||
        !ckbCompletionOneOf(row.plusStatus,["passed","failed","timeout","infra_error"])||
        !ckbCompletionOneOf(row.failureKind,["compile_error","test_failure","timeout","infra_error","protocol_violation"])||
        !ckbCompletionOneOf(row.assetLineage,["independent","humaneval_164_derived"])){return "failure_enum_invalid"}
    if(row.failureObservation.toArray().size>1024||ckbCompletionFailureObservationForbidden(row.failureObservation)){return "protected_failure_observation"}
    if(verifyHash&&row.evidenceHash!=ckbCompletionHexHash(ckbCompletionFailureCanonical(row,false))){return "failure_evidence_hash_mismatch"}
    "ok"
}

private func ckbCompletionFailureClassificationDiagnostic(row:CkbCompletionFailureClassification,verifyHash:Bool):String{
    if(row.schemaVersion!="ckb-completion-failure-classification-v1"||!ckbCompletionHash(row.failureEvidenceHash)||
        !ckbCompletionOneOf(row.gapKind,["knowledge_gap","procedure_gap","mixed_gap","reasoning_error","translation_defect","infrastructure_failure"])){
        return "classification_identity_invalid"
    }
    let knowledge=row.gapKind=="knowledge_gap"||row.gapKind=="mixed_gap"
    let skill=row.gapKind=="procedure_gap"||row.gapKind=="mixed_gap"
    if(row.knowledgeEligible!=knowledge||row.skillEligible!=skill){return "classification_eligibility_invalid"}
    if(verifyHash&&row.classificationEvidenceHash!=ckbCompletionHexHash(ckbCompletionFailureClassificationCanonical(row,false))){return "classification_evidence_hash_mismatch"}
    "ok"
}

private func ckbCompletionFailureAssetClassificationDiagnostic(
    row:CkbCompletionFailureAssetClassification,verifyHash:Bool):String{
    if(row.schemaVersion!="ckb-completion-failure-classification-v2"||
        !ckbCompletionHash(row.failureEvidenceHash)||
        !ckbCompletionOneOf(row.gapKind,["none","knowledge_gap","procedure_gap","rules_gap",
            "knowledge_procedure_gap","knowledge_rules_gap","procedure_rules_gap","all_assets_gap",
            "reasoning_error","translation_defect","infrastructure_failure"])||
        !ckbCompletionOneOf(row.classificationReasonCode,["missing_versioned_fact",
            "missing_reusable_procedure","missing_global_invariant","multiple_reusable_gaps",
            "reasoning_only","translation_defect_only","infrastructure_only","no_reusable_gap"])){
        return "classification_identity_invalid"
    }
    let knowledge=row.gapKind=="knowledge_gap"||row.gapKind=="knowledge_procedure_gap"||
        row.gapKind=="knowledge_rules_gap"||row.gapKind=="all_assets_gap"
    let skill=row.gapKind=="procedure_gap"||row.gapKind=="knowledge_procedure_gap"||
        row.gapKind=="procedure_rules_gap"||row.gapKind=="all_assets_gap"
    let rules=row.gapKind=="rules_gap"||row.gapKind=="knowledge_rules_gap"||
        row.gapKind=="procedure_rules_gap"||row.gapKind=="all_assets_gap"
    var reason="no_reusable_gap"
    if(row.gapKind=="knowledge_gap"){reason="missing_versioned_fact"}
    else if(row.gapKind=="procedure_gap"){reason="missing_reusable_procedure"}
    else if(row.gapKind=="rules_gap"){reason="missing_global_invariant"}
    else if(knowledge||skill||rules){reason="multiple_reusable_gaps"}
    else if(row.gapKind=="reasoning_error"){reason="reasoning_only"}
    else if(row.gapKind=="translation_defect"){reason="translation_defect_only"}
    else if(row.gapKind=="infrastructure_failure"){reason="infrastructure_only"}
    if(row.knowledgeEligible!=knowledge||row.skillEligible!=skill||row.rulesEligible!=rules||
        row.classificationReasonCode!=reason){return "classification_eligibility_invalid"}
    if(verifyHash&&row.classificationEvidenceHash!=ckbCompletionHexHash(
        ckbCompletionFailureAssetClassificationCanonical(row,false))){
        return "classification_evidence_hash_mismatch"
    }
    "ok"
}

private func ckbCompletionFailureCanonical(row:CkbCompletionFailure,includeHash:Bool):String{
    let suffix=if(includeHash){",\"evidenceHash\":\"${ckbP5Escape(row.evidenceHash)}\""}else{""}
    "{\"schemaVersion\":\"${ckbP5Escape(row.schemaVersion)}\",\"runId\":\"${ckbP5Escape(row.runId)}\",\"caseId\":\"${ckbP5Escape(row.caseId)}\",\"datasetVersion\":\"${ckbP5Escape(row.datasetVersion)}\",\"generationProtocol\":\"${ckbP5Escape(row.generationProtocol)}\",\"completionHash\":\"${ckbP5Escape(row.completionHash)}\",\"baseStatus\":\"${ckbP5Escape(row.baseStatus)}\",\"plusStatus\":\"${ckbP5Escape(row.plusStatus)}\",\"failureKind\":\"${ckbP5Escape(row.failureKind)}\",\"failureObservation\":\"${ckbP5Escape(row.failureObservation)}\",\"assetLineage\":\"${ckbP5Escape(row.assetLineage)}\"${suffix}}"
}
private func ckbCompletionFailureClassificationCanonical(row:CkbCompletionFailureClassification,includeHash:Bool):String{
    let suffix=if(includeHash){",\"classificationEvidenceHash\":\"${row.classificationEvidenceHash}\""}else{""}
    "{\"schemaVersion\":\"${row.schemaVersion}\",\"failureEvidenceHash\":\"${row.failureEvidenceHash}\",\"gapKind\":\"${row.gapKind}\",\"knowledgeEligible\":${row.knowledgeEligible},\"skillEligible\":${row.skillEligible}${suffix}}"
}
private func ckbCompletionFailureAssetClassificationCanonical(
    row:CkbCompletionFailureAssetClassification,includeHash:Bool):String{
    let suffix=if(includeHash){",\"classificationEvidenceHash\":\"${row.classificationEvidenceHash}\""}else{""}
    "{\"schemaVersion\":\"${ckbP5Escape(row.schemaVersion)}\",\"failureEvidenceHash\":\"${row.failureEvidenceHash}\",\"gapKind\":\"${ckbP5Escape(row.gapKind)}\",\"knowledgeEligible\":${row.knowledgeEligible},\"skillEligible\":${row.skillEligible},\"rulesEligible\":${row.rulesEligible},\"classificationReasonCode\":\"${ckbP5Escape(row.classificationReasonCode)}\"${suffix}}"
}
private func ckbCompletionHexHash(raw:String):String{let value=benchmarkGapSha256(raw);value[7..value.size]}
private func ckbCompletionHash(value:String):Bool{if(value.toRuneArray().size!=64){return false};for(c in value.toRuneArray()){if(!((c>=r'0'&&c<=r'9')||(c>=r'a'&&c<=r'f'))){return false}};true}
private func ckbCompletionCaseId(value:String):Bool{if(value.size!=16||!value.startsWith("CJ-HUMANEVAL-")){return false};for(c in value.toRuneArray()[13..16]){if(c<r'0'||c>r'9'){return false}};true}
private func ckbCompletionOneOf(value:String,allowed:Array<String>):Bool{for(item in allowed){if(value==item){return true}};false}
private func ckbCompletionUniqueFields(raw:String,keys:Array<String>):Bool{for(key in keys){if(raw.split("\"${key}\"").size!=2){return false}};true}
private func ckbCompletionFailureObservationForbidden(raw:String):Bool{let lower=raw.toAsciiLower();for(term in ["authorization","bearer ","api_key","token=","reference solution","testmain.cj","expected:","assert(","/users/","/home/"]){if(lower.contains(term)){return true}};false}

public class CkbP5ClassifierConfig {
    public var label: String = ""
    public var classifierId: String = ""
    public var provider: String = ""
    public var model: String = ""
    public var executable: String = ""
    public init() {}
}

public class CkbP5ClassifierRunResult {
    public var ok: Bool = false
    public var diagnostic: String = "not_started"
    public var processed: Int64 = 0
    public var paired: Int64 = 0
    public var rejected: Int64 = 0
    public let diagnostics: ArrayList<String> = ArrayList<String>()
    public let diagnosticRows: ArrayList<String> = ArrayList<String>()
    public init() {}
}

private class CkbP5ClassifierInvocationResult {
    var artifact: String = ""
    var diagnostic: String = "not_started"
    init() {}
}

private class CkbP5ClassifierCliOptions {
    var runRoot: String = ""
    var runId: String = ""
    var transport: String = ""
    var outputRoot: String = ""
    var timeoutSeconds: Int64 = 300
    let first = CkbP5ClassifierConfig()
    let second = CkbP5ClassifierConfig()
    init() { first.label = "a"; second.label = "b" }
}

public func runCangjieEvalClassifierControl(args: Array<String>): Int64 {
    let parsed = ckbP5ParseClassifierCli(args)
    if (parsed[0] != "ok") { println("usage error: ${parsed[0]}"); return 2 }
    let options = ckbP5DecodeClassifierOptions(parsed[1])
    let result = runCkbP5IndependentClassifiers(options.runRoot, options.runId, options.transport,
        options.outputRoot, options.first, options.second, options.timeoutSeconds)
    if (!result.ok) {
        let detail=if(result.diagnostics.size>0){" first=${result.diagnostics[0]}"}else{""}
        println("classifier control blocked diagnostic=${result.diagnostic} processed=${result.processed} rejected=${result.rejected}${detail}")
        return 1
    }
    println("classifier control complete processed=${result.processed} paired=${result.paired} rejected=${result.rejected}")
    0
}

// The opaque encoded value keeps the strict parser small without ever rendering
// executable arguments or environment values into diagnostics.
private func ckbP5ParseClassifierCli(args: Array<String>): (String, String) {
    let known = ["--run-root", "--run-id", "--transport", "--output-root", "--classifier-a-executable",
        "--classifier-a-provider", "--classifier-a-model", "--classifier-a-id", "--classifier-b-executable",
        "--classifier-b-provider", "--classifier-b-model", "--classifier-b-id", "--timeout-seconds"]
    let values = ArrayList<String>(); for (_ in known) { values.add("") }
    var i: Int64 = 0
    while (i < args.size) {
        if (args[i] == "cangjie-eval-classifier-run") { if (i != 0) { return ("command_must_be_first", "") }; i += 1; continue }
        var index: Int64 = -1; for (j in 0..known.size) { if (known[j] == args[i]) { index = j; break } }
        if (index < 0 || i + 1 >= args.size || args[i + 1].trimAscii() == "") { return ("unknown_or_missing_classifier_argument", "") }
        if (values[index] != "") { return ("duplicate_classifier_argument", "") }
        values[index] = args[i + 1].trimAscii(); i += 2
    }
    for (j in 0..12) { if (values[j] == "") { return ("classifier_arguments_incomplete", "") } }
    if (values[2] != "C" && values[2] != "D") { return ("classifier_transport_invalid", "") }
    let timeout = try { Int64.parse(values[12]) } catch (_: Exception) { return ("classifier_timeout_invalid", "") }
    if (timeout < 1 || timeout > 3600) { return ("classifier_timeout_invalid", "") }
    if (values[5] == values[10] || values[7] == values[11] || values[4] == values[9]) { return ("independent_classifier_configuration_required", "") }
    var encoded = ""; for (value in values) { encoded += ckbP5Part(value) }
    ("ok", encoded)
}

private func ckbP5DecodeClassifierOptions(encoded: String): CkbP5ClassifierCliOptions {
    let values = ckbP5DecodeParts(encoded); let o = CkbP5ClassifierCliOptions()
    o.runRoot=values[0];o.runId=values[1];o.transport=values[2];o.outputRoot=values[3]
    o.first.executable=values[4];o.first.provider=values[5];o.first.model=values[6];o.first.classifierId=values[7]
    o.second.executable=values[8];o.second.provider=values[9];o.second.model=values[10];o.second.classifierId=values[11]
    o.timeoutSeconds=Int64.parse(values[12]);o
}

private func ckbP5DecodeParts(encoded: String): ArrayList<String> {
    let out=ArrayList<String>();var index:Int64=0;let bytes=encoded.toArray()
    while(index<bytes.size){var colon=index;while(colon<bytes.size&&bytes[colon]!=UInt8(58)){colon+=1};let size=Int64.parse(String.fromUtf8(bytes[index..colon]));let start=colon+1;out.add(String.fromUtf8(bytes[start..start+size]));index=start+size};out
}

public func runCkbP5IndependentClassifiers(runRoot: String, runId: String, transport: String, outputRoot: String,
    first: CkbP5ClassifierConfig, second: CkbP5ClassifierConfig, timeoutSeconds: Int64): CkbP5ClassifierRunResult {
    let result = CkbP5ClassifierRunResult()
    if (!ckbP5SafeControlRoots(runRoot, outputRoot) || runId == "" || (transport != "C" && transport != "D") ||
        !ckbP5IndependentConfigs(first, second) || timeoutSeconds < 1 || timeoutSeconds > 3600) {
        result.diagnostic = "classifier_control_contract_invalid"; return result
    }
    let group = if (transport == "C") { CkbAbcdeGroups.C } else { CkbAbcdeGroups.D }
    if (!exists(Path(runRoot)) || exists(Path(outputRoot))) { result.diagnostic = "classifier_roots_invalid"; return result }
    try { Directory.create(Path(outputRoot), recursive: true) } catch (_: Exception) { result.diagnostic="classifier_output_create_failed";return result }
    for (index in 0..164) {
        let caseId=ckbP5CaseId(index);let caseRoot=Path(runRoot).join("cases").join(caseId).join(group)
        if (!exists(caseRoot.join("case-result.json")) && !exists(caseRoot.join("result-evidence.json"))) { continue }
        let caseResult=ckbP5ReadUtf8(caseRoot.join("case-result.json"))
        try { if (ckbP5Bool(JsonValue.fromStr(caseResult).asObject(),"firstAttemptPass")) { continue } } catch (_: Exception) { result.rejected+=1;ckbP5AddControllerDiagnostic(result,caseId,"case_result_malformed","not_run","not_run");continue }
        let request = buildCkbP5ClassifierRequest(caseRoot, caseId, runId)
        if (request.startsWith("sealed_nonbusiness_route:")) {
            ckbP5AddControllerDiagnostic(result,caseId,"not_run","not_run",request)
            continue
        }
        if (!request.startsWith("{")) { result.rejected+=1;ckbP5AddControllerDiagnostic(result,caseId,request,"not_run","not_run");continue }
        result.processed+=1
        let firstRun=ckbP5InvokeClassifier(outputRoot,caseId,request,first,timeoutSeconds)
        let secondRun=ckbP5InvokeClassifier(outputRoot,caseId,request,second,timeoutSeconds)
        if (firstRun.artifact==""||secondRun.artifact=="") { result.rejected+=1;ckbP5AddControllerDiagnostic(result,caseId,firstRun.diagnostic,secondRun.diagnostic,"not_run");continue }
        let confirmation=confirmIndependentClassifierPair(firstRun.artifact,secondRun.artifact)
        if(!confirmation.confirmed){result.rejected+=1;ckbP5AddControllerDiagnostic(result,caseId,"ok","ok",confirmation.diagnostic);continue}
        let pairA=Path(outputRoot).join("pairs/a");let pairB=Path(outputRoot).join("pairs/b")
        try{if(!exists(pairA)){Directory.create(pairA,recursive:true)};if(!exists(pairB)){Directory.create(pairB,recursive:true)}}catch(_:Exception){result.diagnostic="classifier_pair_root_failed";return ckbP5FinalizeControllerResult(outputRoot,result)}
        if(!ckbP5AtomicWrite(pairA.join("${caseId}.json"),firstRun.artifact+"\n")||!ckbP5AtomicWrite(pairB.join("${caseId}.json"),secondRun.artifact+"\n")){result.diagnostic="classifier_pair_write_failed";return ckbP5FinalizeControllerResult(outputRoot,result)}
        result.paired+=1
    }
    result.ok=result.rejected==0;result.diagnostic=if(result.ok){"ok"}else{"classifier_cases_rejected"};ckbP5FinalizeControllerResult(outputRoot,result)
}

private func ckbP5AddControllerDiagnostic(result:CkbP5ClassifierRunResult,caseId:String,a:String,b:String,pair:String):Unit{
    result.diagnostics.add("${caseId}:a=${a}:b=${b}:pair=${pair}")
    result.diagnosticRows.add("{\"caseId\":\"${ckbP5Escape(caseId)}\",\"classifierA\":\"${ckbP5Escape(a)}\",\"classifierB\":\"${ckbP5Escape(b)}\",\"pair\":\"${ckbP5Escape(pair)}\"}")
}

private func ckbP5FinalizeControllerResult(outputRoot:String,result:CkbP5ClassifierRunResult):CkbP5ClassifierRunResult{
    var rows="";for(i in 0..result.diagnosticRows.size){if(i>0){rows+=","};rows+=result.diagnosticRows[i]}
    let fields="\"schemaVersion\":\"ckb-p5-classifier-diagnostics-v1\",\"ok\":${result.ok},\"diagnostic\":\"${ckbP5Escape(result.diagnostic)}\",\"processed\":${result.processed},\"paired\":${result.paired},\"rejected\":${result.rejected},\"cases\":[${rows}]";let payload="{${fields}}"
    let artifact="{${fields},\"artifactHash\":\"${benchmarkGapSha256(payload)}\"}"
    if(!ckbP5AtomicWrite(Path(outputRoot).join("classifier-control-diagnostics.json"),artifact+"\n")){result.ok=false;result.diagnostic="classifier_diagnostic_artifact_write_failed"}
    result
}

public func ckbP5ClassifierDiagnosticArtifactValid(raw:String):Bool{try{let o=JsonValue.fromStr(raw).asObject();if(ckbP5String(o,"schemaVersion")!="ckb-p5-classifier-diagnostics-v1"){return false};let items=o.get("cases").getOrThrow().asArray().getItems();var rows="";for(i in 0..items.size){let row=items[i].asObject();if(i>0){rows+=","};rows+="{\"caseId\":\"${ckbP5Escape(ckbP5String(row,"caseId"))}\",\"classifierA\":\"${ckbP5Escape(ckbP5String(row,"classifierA"))}\",\"classifierB\":\"${ckbP5Escape(ckbP5String(row,"classifierB"))}\",\"pair\":\"${ckbP5Escape(ckbP5String(row,"pair"))}\"}"};let payload="{\"schemaVersion\":\"ckb-p5-classifier-diagnostics-v1\",\"ok\":${ckbP5Bool(o,"ok")},\"diagnostic\":\"${ckbP5Escape(ckbP5String(o,"diagnostic"))}\",\"processed\":${ckbP5Int(o,"processed")},\"paired\":${ckbP5Int(o,"paired")},\"rejected\":${ckbP5Int(o,"rejected")},\"cases\":[${rows}]}";ckbP5String(o,"artifactHash")==benchmarkGapSha256(payload)}catch(_:Exception){false}}

public func buildCkbP5ClassifierRequest(caseRoot: Path, caseId: String, runId: String): String {
    if (exists(caseRoot.join("evaluation-outcome.json"))) {
        let failure = buildCkbCompletionFailureFromArtifacts(caseRoot, caseId, runId)
        if (failure[1] != "ok") { return failure[1] }
        return renderCkbCompletionFailure(failure[0])
    }
    let caseText=ckbP5ReadUtf8(caseRoot.join("case-result.json"));let evidenceText=ckbP5ReadUtf8(caseRoot.join("result-evidence.json"))
    if(caseText==""||evidenceText==""){return "missing_case_evidence"}
    try{
        let row=JsonValue.fromStr(caseText).asObject();let evidence=JsonValue.fromStr(evidenceText).asObject()
        let triage=triageEvalFailure(evidenceText)
        if(!triage.ok||ckbP5String(row,"caseId")!=caseId||ckbP5String(row,"runId")!=runId||ckbP5String(row,"runMode")!="development"||
            ckbP5String(evidence,"caseId")!=caseId||ckbP5String(evidence,"runId")!=runId||
            ckbP5String(evidence,"datasetVersion")!=ckbP5String(row,"datasetVersion")||
            ckbP5Bool(row,"firstAttemptPass")){return "first_complete_development_sample_required"}
        if(!cangjieEvalBusinessClassificationRequired(triage.category)){
            let route=cangjieEvalSealedNonBusinessRoute(evidenceText)
            if(!route.confirmed){return "sealed_nonbusiness_route_invalid"}
            return "sealed_nonbusiness_route:${route.category}:${route.route}"
        }
        let sample=ckbP5FirstCompleteDevelopmentSample(caseRoot,row,evidence)
        if(sample[0]!="ok"){return "first_complete_development_sample_required"}
        let contextText=ckbP5ReadUtf8(caseRoot.join("canonical-task-context.json"));if(contextText==""){return "task_context_missing"}
        let context=JsonValue.fromStr(contextText).asObject();let taskText=ckbP5String(context,"taskText");let signature=ckbP5String(context,"signature")
        if(taskText==""||signature==""||ckbP5String(context,"taskId")!=caseId||ckbP5String(context,"datasetVersion")!=ckbP5String(row,"datasetVersion")||ckbP5Forbidden(taskText+"\n"+signature)){return "task_context_forbidden"}
        let retrievalEvidenceHash=ckbP5String(evidence,"retrievalEvidenceHash");let toolEvidenceHash=ckbP5String(row,"toolEvidenceHash")
        if(retrievalEvidenceHash!=toolEvidenceHash||!ckbP5OpaqueEvidenceHashValid(retrievalEvidenceHash)){return "retrieval_evidence_binding_invalid"}
        let studentSource=ckbP5ReadUtf8(caseRoot.join("workspace/src/solution.cj"));if(studentSource==""){return "student_source_missing_or_invalid_encoding"};let studentExcerpt=utf8SafePrefix(studentSource,8192);if(ckbP5Forbidden(studentExcerpt)){return "student_source_forbidden"};let studentSourceHash=benchmarkGapSha256(studentSource)
        let failureType=ckbP5String(row,"failureType");let summary=ckbP5CompilerSummary(ckbP5ReadUtf8(caseRoot.join("test.log")),failureType)
        let request="{\"schemaVersion\":\"${CKB_P5_REQUEST_SCHEMA}\",\"caseId\":\"${ckbP5Escape(caseId)}\",\"runId\":\"${ckbP5Escape(runId)}\",\"datasetVersion\":\"${ckbP5Escape(ckbP5String(row,"datasetVersion"))}\",\"attempt\":1,\"sourceTransportAttempt\":${sample[1]},\"runMode\":\"development\",\"taskText\":\"${ckbP5Escape(taskText)}\",\"signature\":\"${ckbP5Escape(signature)}\",\"studentSourceExcerpt\":\"${ckbP5Escape(studentExcerpt)}\",\"studentSourceHash\":\"${studentSourceHash}\",\"failureObservation\":\"${ckbP5Escape(ckbP5String(evidence,"failureObservation"))}\",\"failureType\":\"${ckbP5Escape(failureType)}\",\"compilerTestSummary\":\"${ckbP5Escape(summary)}\",\"resultEvidenceHash\":\"${ckbP5Escape(ckbP5String(evidence,"resultEvidenceHash"))}\",\"retrievalDiagnostic\":\"${ckbP5Escape(ckbP5String(evidence,"retrievalDiagnostic"))}\",\"retrievalEvidenceHash\":\"${ckbP5Escape(retrievalEvidenceHash)}\",\"toolEvidenceHash\":\"${ckbP5Escape(toolEvidenceHash)}\",\"toolCoveragePass\":${ckbP5Bool(row,"toolCoveragePass")},\"citationCount\":${ckbP5Int(row,"citationCount")} }"
        if(ckbP5Forbidden(request)){"request_contains_forbidden_evidence"}else{request}
    }catch(_:Exception){"malformed_case_evidence"}
}

public func buildCkbCompletionFailureFromArtifacts(caseRoot:Path,caseId:String,runId:String):
    (CkbCompletionFailure,String) {
    let failure=CkbCompletionFailure()
    let outcomeText=ckbP5ReadUtf8(caseRoot.join("evaluation-outcome.json"))
    let resultText=ckbP5ReadUtf8(caseRoot.join("result-evidence.json"))
    let contextText=ckbP5ReadUtf8(caseRoot.join("canonical-task-context.json"))
    if(outcomeText==""||resultText==""||contextText==""){return(failure,"missing_case_evidence")}
    try{
        let outcome=JsonValue.fromStr(outcomeText.trimAscii()).asObject()
        let result=JsonValue.fromStr(resultText.trimAscii()).asObject()
        let context=JsonValue.fromStr(contextText.trimAscii()).asObject()
        let dataset=ckbP5String(outcome,"datasetVersion")
        if(ckbP5String(outcome,"schemaVersion")!="ckb-completion-evaluation-outcome-v1"||
            ckbP5String(outcome,"runId")!=runId||ckbP5String(outcome,"caseId")!=caseId||
            ckbP5String(outcome,"generationProtocol")!="completion-only-v1"||
            ckbP5String(result,"runId")!=runId||ckbP5String(result,"caseId")!=caseId||
            ckbP5String(result,"datasetVersion")!=dataset||
            ckbP5String(context,"taskId")!=caseId||ckbP5String(context,"datasetVersion")!=dataset||
            ckbP5String(context,"taskText")==""||ckbP5Forbidden(ckbP5String(context,"taskText"))){
            return(failure,"failure_artifact_identity_mismatch")
        }
        let resultHash=benchmarkGapSha256(resultText.trimAscii())
        if(ckbP5String(outcome,"resultHash")!=resultHash){return(failure,"failure_result_hash_mismatch")}
        let base=ckbP5String(outcome,"baseStatus");let plus=ckbP5String(outcome,"plusStatus")
        if(base=="passed"&&plus=="passed"){return(failure,"completion_failure_not_required")}
        failure.runId=runId;failure.caseId=caseId;failure.datasetVersion=dataset
        failure.completionHash=ckbP5String(outcome,"completionHash").replace("sha256:","")
        failure.baseStatus=base;failure.plusStatus=plus
        let resultFailure=ckbP5String(result,"failureType")
        failure.failureKind=if(resultFailure=="compile_error"){"compile_error"}else if(resultFailure=="timeout"){"timeout"}else if(resultFailure=="protocol_violation"){"protocol_violation"}else if(resultFailure=="runner_failure"||resultFailure=="environment_failure"){"infra_error"}else{"test_failure"}
        let baseSummary=ckbP5CompilerSummaryFromBytes(try{File.readFrom(caseRoot.join("base-test.log"))}catch(_:Exception){Array<UInt8>()},failure.failureKind)
        let plusSummary=ckbP5CompilerSummaryFromBytes(try{File.readFrom(caseRoot.join("plus-test.log"))}catch(_:Exception){Array<UInt8>()},failure.failureKind)
        failure.failureObservation=utf8SafePrefix("base=${base}:${baseSummary}; plus=${plus}:${plusSummary}",1024)
        failure.assetLineage="humaneval_164_derived"
        let diagnostic=sealCkbCompletionFailure(failure)
        (failure,diagnostic)
    }catch(_:Exception){(failure,"malformed_case_evidence")}
}

private func ckbP5FirstCompleteDevelopmentSample(caseRoot:Path,row:JsonObject,evidence:JsonObject):(String,Int64){
    let transportCount=ckbP5Int(row,"claudeAttemptCount")
    if(transportCount<=1){
        if(ckbP5Int(evidence,"attempt")!=1||ckbP5Int(row,"firstClaudeExitCode")!=0){return ("legacy_first_sample_invalid",0)}
        return ("ok",1)
    }
    if(ckbP5Int(row,"claudeExitCode")!=0){return ("selected_transport_failed",0)}
    let attemptEvidenceText=ckbP5ReadUtf8(caseRoot.join("attempt-evidence.json"));let testResultText=ckbP5ReadUtf8(caseRoot.join("test-result.json"));let attemptsText=ckbP5ReadUtf8(caseRoot.join("claude-attempts.jsonl"))
    if(attemptEvidenceText==""||testResultText==""||attemptsText==""){return ("sample_evidence_missing",0)}
    try{
        let attemptEvidence=JsonValue.fromStr(attemptEvidenceText).asObject();let testResult=JsonValue.fromStr(testResultText).asObject()
        if(ckbP5Int(attemptEvidence,"transportAttemptCount")!=transportCount||ckbP5Int(testResult,"transportAttemptCount")!=transportCount||
            ckbP5Int(attemptEvidence,"sampleAttemptCount")!=1||ckbP5Int(testResult,"sampleAttemptCount")!=1){return ("sample_count_mismatch",0)}
        match(row.get("transportAttemptCount")){case Some(v)=>if(v.asInt().getValue()!=transportCount){return ("row_transport_count_mismatch",0)};case None=>()}
        match(row.get("sampleAttemptCount")){case Some(v)=>if(v.asInt().getValue()!=1){return ("row_sample_count_mismatch",0)};case None=>()}
        let restoreText=ckbP5ReadUtf8(caseRoot.join("workspace-restores.jsonl"));let restoreHash=ckbP5String(attemptEvidence,"workspaceRestoreEvidenceHash")
        if(restoreText==""||!ckbP5Hash(restoreHash)||restoreHash!=benchmarkGapSha256(restoreText)||ckbP5String(testResult,"workspaceRestoreEvidenceHash")!=restoreHash){return ("restore_evidence_invalid",0)}
        var rowCount:Int64=0;var selected:Int64=0;var sampleCount:Int64=0
        for(raw in attemptsText.split("\n")){
            let line=raw.trimAscii();if(line==""){continue};let item=JsonValue.fromStr(line).asObject();rowCount+=1
            if(ckbP5Int(item,"attempt")!=rowCount||ckbP5Int(item,"transportAttempt")!=rowCount){return ("transport_sequence_invalid",0)}
            let sampleAttempt=ckbP5Int(item,"sampleAttempt");let exitCode=ckbP5Int(item,"exitCode");let complete=ckbP5Bool(item,"completeResult");let identity=ckbP5Bool(item,"identityMatched")
            if(sampleAttempt==1){sampleCount+=1;selected=rowCount;if(exitCode!=0||!complete||!identity){return ("selected_sample_invalid",0)}}
            else if(sampleAttempt!=0||exitCode==0&&complete&&identity){return ("unrecorded_complete_sample",0)}
            if(rowCount>1&&(!ckbP5Bool(item,"workspaceRestored")||!ckbP5Hash(ckbP5String(item,"restoreEvidenceHash")))){return ("transport_restore_invalid",0)}
        }
        if(rowCount!=transportCount||sampleCount!=1||selected!=transportCount){return ("first_complete_sample_not_unique",0)}
        let evidenceTransport=ckbP5Int(evidence,"transportAttempt")
        if((evidenceTransport>0&&(ckbP5Int(evidence,"attempt")!=selected||evidenceTransport!=selected))||(evidenceTransport==0&&ckbP5Int(evidence,"attempt")!=selected)){return ("result_evidence_transport_mismatch",0)}
        let selectedTranscript=ckbP5ReadUtf8(caseRoot.join("claude-transcript.attempt-${selected}.jsonl"));let publishedTranscript=ckbP5ReadUtf8(caseRoot.join("claude-transcript.jsonl"))
        if(selectedTranscript==""||publishedTranscript==""||selectedTranscript!=publishedTranscript){return ("published_transcript_mismatch",0)}
        ("ok",selected)
    }catch(_:Exception){("sample_evidence_malformed",0)}
}

private func ckbP5OpaqueEvidenceHashValid(value:String):Bool{if(value==""||value.size>256||ckbP5Forbidden(value)){return false};for(ch in value.toRuneArray()){if(ch<=r' '){return false}};true}

private func ckbP5InvokeClassifier(outputRoot:String,caseId:String,request:String,config:CkbP5ClassifierConfig,timeoutSeconds:Int64):CkbP5ClassifierInvocationResult{
    let invocation=CkbP5ClassifierInvocationResult()
    let root=Path(outputRoot).join("runs").join(caseId).join(config.label);let workspace=root.join("workspace");let home=root.join("runtime-home")
    try{Directory.create(workspace,recursive:true);Directory.create(home,recursive:true)}catch(_:Exception){invocation.diagnostic="classifier_isolation_create_failed";return invocation}
    let requestPath=workspace.join("request.json");let responsePath=workspace.join("response.json");let stdoutPath=root.join("stdout.tmp");let stderrPath=root.join("stderr.tmp")
    if(!ckbP5AtomicWrite(requestPath,request+"\n")){invocation.diagnostic="classifier_request_write_failed";return invocation}
    let session="${caseId}-${config.label}-${benchmarkGapSha256(request+config.provider+config.model)}";let args=ArrayList<String>()
    for(value in ["--request",requestPath.toString(),"--output",responsePath.toString(),"--workspace",workspace.toString(),"--runtime-home",home.toString(),"--session-id",session,"--expected-provider",config.provider,"--expected-model",config.model]){args.add(value)}
    let dyld=match(getVariable("DYLD_LIBRARY_PATH")){case Some(value)=>value;case None=>""};let requiresDyld=ckbP5ClassifierRequiresDyld();let environment=ckbP5ClassifierProcessEnvironment(dyld,requiresDyld)
    if(ckbP5ClassifierDyldDiagnostic(dyld,requiresDyld)!="ok"){invocation.diagnostic="classifier_dyld_library_path_missing";return invocation}
    let marker=root.join("timeout.marker");let process=CkbTimedWorkerProcessLauncher(config.executable,args,environment:environment,workdir:workspace.toString(),cutoffAtMillis:ckbCoreNowMillis()+timeoutSeconds*1000,timeoutMarkerPath:marker.toString(),stdoutPath:stdoutPath.toString(),stderrPath:stderrPath.toString()).run()
    try{_=launch("/bin/rm",["-f",stdoutPath.toString(),stderrPath.toString()]).wait()}catch(_:Exception){}
    let diagnosticPath=workspace.join("classifier-diagnostic.json")
    if(process.timedOut){ckbP5RemoveClassifierResponse(responsePath);ckbP5RemoveClassifierResponse(diagnosticPath);invocation.diagnostic="classifier_process_timeout";return invocation}
    if(process.exitCode!=0){ckbP5RemoveClassifierResponse(responsePath);invocation.diagnostic=ckbP5ReadClassifierFailureDiagnostic(diagnosticPath);ckbP5RemoveClassifierResponse(diagnosticPath);return invocation}
    if(exists(diagnosticPath)){ckbP5RemoveClassifierResponse(responsePath);ckbP5RemoveClassifierResponse(diagnosticPath);invocation.diagnostic="classifier_diagnostic_unexpected_on_success";return invocation}
    if(!exists(responsePath)){invocation.diagnostic="classifier_response_missing";return invocation}
    let responseBytes=try{File.readFrom(responsePath)}catch(_:Exception){ckbP5RemoveClassifierResponse(responsePath);invocation.diagnostic="classifier_response_read_failed";return invocation};ckbP5RemoveClassifierResponse(responsePath);let response=try{String.fromUtf8(responseBytes)}catch(_:Exception){invocation.diagnostic="classifier_response_invalid_encoding";return invocation}
    let sealed=sealCkbP5ClassifierResponseWithDiagnostic(request,response,config,workspace.toString(),home.toString(),session)
    if(sealed[0]!=""){_=ckbP5AtomicWrite(root.join("classifier.json"),sealed[0]+"\n");invocation.artifact=sealed[0]};invocation.diagnostic=sealed[1];invocation
}
public func ckbP5ClassifierProcessEnvironment(dyldLibraryPath:String,requiresDyld:Bool):ArrayList<CkbTimedWorkerProcessEnvironment>{let out=ArrayList<CkbTimedWorkerProcessEnvironment>();let value=dyldLibraryPath.trimAscii();if(requiresDyld&&value==""){return out};if(value!=""){out.add(CkbTimedWorkerProcessEnvironment("DYLD_LIBRARY_PATH",value))};out}
public func ckbP5ClassifierDyldDiagnostic(dyldLibraryPath:String,requiresDyld:Bool):String{if(requiresDyld&&dyldLibraryPath.trimAscii()==""){"classifier_dyld_library_path_missing"}else{"ok"}}
private func ckbP5ClassifierRequiresDyld():Bool{exists(Path("/usr/bin/sw_vers"))}
private func ckbP5RemoveClassifierResponse(path:Path):Unit{try{_=launch("/bin/rm",["-f",path.toString()]).wait()}catch(_:Exception){}}
public func ckbP5ReadClassifierFailureDiagnostic(path:Path):String{
    if(!exists(path)){return "classifier_diagnostic_missing"}
    let bytes=try{File.readFrom(path)}catch(_:Exception){return "classifier_diagnostic_invalid"}
    if(bytes.size>512){return "classifier_diagnostic_too_large"}
    let raw=try{String.fromUtf8(bytes)}catch(_:Exception){return "classifier_diagnostic_invalid_encoding"}
    try{
        let o=JsonValue.fromStr(raw).asObject();let diagnostic=ckbP5String(o,"diagnostic")
        if(ckbP5String(o,"schemaVersion")!="cangjie-teacher-classifier-diagnostic-v1"){return "classifier_diagnostic_invalid"}
        let canonical="{\"schemaVersion\":\"cangjie-teacher-classifier-diagnostic-v1\",\"diagnostic\":\"${diagnostic}\"}"
        if(raw.trimAscii()!=canonical){return "classifier_diagnostic_invalid"}
        if(!ckbP5ClassifierFailureDiagnosticAllowed(diagnostic)){return "classifier_diagnostic_unknown"};diagnostic
    }catch(_:Exception){"classifier_diagnostic_invalid"}
}
private func ckbP5ClassifierFailureDiagnosticAllowed(value:String):Bool{
    ["invalid_response_encoding","request_too_large","request_contract_invalid","classifier_timeout","classifier_process_failed",
        "classifier_output_too_large","malformed_stream_json","duplicate_init","classifier_unsuccessful_result","missing_init",
        "observed_model_mismatch","missing_or_duplicate_terminal_result","response_contract_invalid","response_contains_forbidden_data",
        "malformed_structured_output","classifier_response_source_fact_unsupported","response_write_failed","diagnostic_reset_failed",
        "classifier_reserved_match_plain_missing","classifier_reserved_match_raw_missing",
        "classifier_reserved_match_rename_missing","classifier_reserved_match_contradictory",
        "classifier_reserved_match_comment_disguised",
        "classifier_string_case_iteration_uint8_missing","classifier_string_case_string_ascii_api_missing",
        "classifier_string_case_rune_ascii_api_missing","classifier_string_case_unicode_import_missing",
        "classifier_string_case_unicode_rune_api_missing","classifier_string_case_unicode_return_type_missing",
        "classifier_string_case_invalid_api_negative_missing","classifier_string_case_contradictory",
        "classifier_string_case_comment_disguised","classifier_string_case_solution_leakage",
        "classifier_failure_unknown"].contains(value)
}

public func sealCkbP5ClassifierResponse(requestText:String,responseText:String,config:CkbP5ClassifierConfig,workspace:String,runtimeHome:String,session:String):String{
    sealCkbP5ClassifierResponseWithDiagnostic(requestText,responseText,config,workspace,runtimeHome,session)[0]
}

public func sealCkbP5ClassifierResponseWithDiagnostic(requestText:String,responseText:String,config:CkbP5ClassifierConfig,workspace:String,runtimeHome:String,session:String):(String,String){
    try{
        let request=JsonValue.fromStr(requestText).asObject();let response=JsonValue.fromStr(responseText).asObject()
        if(ckbP5String(request,"schemaVersion")!=CKB_P5_REQUEST_SCHEMA||ckbP5String(request,"caseId")==""||ckbP5String(request,"runId")==""||
            ckbP5String(request,"datasetVersion")==""||ckbP5Int(request,"attempt")!=1||ckbP5String(request,"runMode")!="development"){return ("","classifier_request_contract_invalid")}
        if(ckbP5String(request,"studentSourceExcerpt")!=""&&!ckbP5Hash(ckbP5String(request,"studentSourceHash"))){return ("","classifier_request_contract_invalid")}
        if(ckbP5String(response,"schemaVersion")!=CKB_P5_RESPONSE_SCHEMA){return ("","classifier_response_schema_invalid")}
        if(ckbP5String(response,"observedProvider")==""||ckbP5String(response,"observedModel")==""||ckbP5String(response,"category")==""){return ("","classifier_response_incomplete")}
        if(ckbP5String(response,"observedProvider")!=config.provider||ckbP5String(response,"observedModel")!=config.model){return ("","classifier_response_identity_mismatch")}
        if(ckbP5Forbidden(responseText)){return ("","classifier_response_forbidden_content")}
        let category=ckbP5String(response,"category").toAsciiLower();if(!ckbP5ClassifierCategory(category)){return ("","classifier_response_category_invalid")}
        let sourceFactDiagnostic=ckbP5ClassifierSourceFactsDiagnostic(request,response,category)
        if(sourceFactDiagnostic!="ok"){return ("",sourceFactDiagnostic)}
        let providerHash=benchmarkGapSha256(ckbP5Part(config.provider)+ckbP5Part(config.model)+ckbP5Part(ckbP5String(response,"observedProvider"))+ckbP5Part(ckbP5String(response,"observedModel")))
        let workspaceId=benchmarkGapSha256(try{canonicalize(Path(workspace)).toString()}catch(_:Exception){workspace});let runtimeHomeId=benchmarkGapSha256(try{canonicalize(Path(runtimeHome)).toString()}catch(_:Exception){runtimeHome});let sessionId=benchmarkGapSha256(session)
        let sourceId=benchmarkGapSha256(config.provider+"|"+config.model+"|"+config.executable+"|"+config.classifierId)
        let shared=ckbP5SharedClassifierFields(request,response,category);let consensusHash=ckbP5ClassifierConsensusHash(JsonValue.fromStr("{${shared}}").asObject())
        let provenanceHash=benchmarkGapSha256(ckbP5Part(benchmarkGapSha256(requestText))+ckbP5Part(providerHash)+ckbP5Part(workspaceId)+ckbP5Part(runtimeHomeId)+ckbP5Part(sessionId)+ckbP5Part(sourceId))
        let base="{\"schemaVersion\":\"${CKB_P5_CLASSIFIER_SCHEMA}\",\"classifierId\":\"${ckbP5Escape(config.classifierId)}\",\"sourceEvidenceId\":\"${sourceId}\",\"provider\":\"${ckbP5Escape(config.provider)}\",\"observedProvider\":\"${ckbP5Escape(ckbP5String(response,"observedProvider"))}\",\"expectedModel\":\"${ckbP5Escape(config.model)}\",\"observedModel\":\"${ckbP5Escape(ckbP5String(response,"observedModel"))}\",\"providerIdentityHash\":\"${providerHash}\",\"provenanceHash\":\"${provenanceHash}\",\"workspaceId\":\"${workspaceId}\",\"runtimeHomeId\":\"${runtimeHomeId}\",\"sessionId\":\"${sessionId}\",${shared},\"consensusHash\":\"${consensusHash}\",\"evidenceHash\":\"\"}"
        let hash=ckbP5ClassifierArtifactEvidenceHash(base);(base.replace("\"evidenceHash\":\"\"","\"evidenceHash\":\"${hash}\""),"ok")
    }catch(_:Exception){("","classifier_response_malformed")}
}

private func ckbP5ClassifierSourceFactsDiagnostic(request:JsonObject,response:JsonObject,category:String):String{
    if(category!="knowledge_gap"){return "ok"}
    let source=ckbP5String(request,"studentSourceExcerpt").toAsciiLower()
    let compiler=ckbP5String(request,"compilerTestSummary").toAsciiLower()
    let task=ckbP5String(request,"taskText").toAsciiLower()
    let knowledge=ckbP5String(response,"knowledgeText").toAsciiLower()
    let stringCasingDiagnostic=ckbP5ClassifierStringCasingFactsDiagnostic(source,compiler,task,knowledge)
    if(stringCasingDiagnostic!="ok"){return stringCasingDiagnostic}
    let reservedKeywordDiagnostic=ckbP5ClassifierReservedKeywordFactsDiagnostic(source,compiler,knowledge)
    if(reservedKeywordDiagnostic!="ok"){return reservedKeywordDiagnostic}
    if(!source.contains(".abs(")||!compiler.contains("undeclared identifier 'abs'")){return "ok"}
    if(!knowledge.contains("std.math")){return "ok"}
    let deniesRequirement=knowledge.contains("std.math import is unnecessary")||knowledge.contains("std.math import is not required")||
        knowledge.contains("does not require importing std.math")||knowledge.contains("without importing std.math")||
        knowledge.contains("do not import std.math")||knowledge.contains("must not import std.math")
    if(deniesRequirement){return "ok"}
    let assertsRequirement=knowledge.contains("must import std.math")||knowledge.contains("requires import std.math")||
        knowledge.contains("required to import std.math")||knowledge.contains("import std.math")||
        knowledge.contains("importing std.math")||knowledge.contains("from std.math")||knowledge.contains("std.math.* before")
    if(assertsRequirement){"classifier_response_source_fact_unsupported"}else{"ok"}
}

private func ckbP5ClassifierStringCasingFactsDiagnostic(source:String,compiler:String,task:String,knowledge:String):String{
    if(!source.contains(".tolower(")||!compiler.contains("'tolower' is not a member")||!compiler.contains("string")){return "ok"}
    let value=knowledge.replace("`", "")
    if(knowledge.contains("//")||knowledge.contains("/*")||knowledge.contains("*/")){return "classifier_string_case_comment_disguised"}
    if(ckbP5ClassifierDistinctCaseCountGoal(task)&&ckbP5ClassifierDistinctCaseCountSolution(knowledge)){
        return "classifier_string_case_solution_leakage"
    }
    let directRune=(value.contains("for (c in string)")&&(value.contains("yielding rune")||value.contains("yields rune")||
        value.contains("produces rune")||value.contains("returns rune")))||
        (value.contains("direct string iteration")&&value.contains("rune")&&!value.contains("uint8"))||
        value.contains("string iteration yields rune")||value.contains("string iteration returns rune")||value.contains("string iteration produces rune")
    let assertsStringToLower=value.contains("use string.tolower")||value.contains("call string.tolower")||
        value.contains("string.tolower() is available")||value.contains("string supports string.tolower")||
        value.contains("string provides string.tolower")
    let assertsToLowerAscii=value.contains("use tolowerascii")||value.contains("call tolowerascii")||
        value.contains("tolowerascii returns")||value.contains("tolowerascii is available")||
        value.contains("rune.tolowerascii")||value.contains("string.tolowerascii")
    if(directRune||value.contains("string.toasciilowercase")||value.contains("rune.toasciilower(")||assertsStringToLower||
        assertsToLowerAscii){return "classifier_string_case_contradictory"}
    let iterationUInt8=value.contains("direct string iteration yields uint8")||value.contains("string iteration yields uint8")||
        value.contains("iterating a string yields uint8")||value.contains("string iteration produces uint8")
    if(!iterationUInt8){return "classifier_string_case_iteration_uint8_missing"}
    let stringAscii=ckbP5ClassifierAsciiApiFactValid(value,"string.toasciilower()","string")
    if(!stringAscii){return "classifier_string_case_string_ascii_api_missing"}
    let runeAscii=ckbP5ClassifierAsciiApiFactValid(value,"rune.toasciilowercase()","rune")
    if(!runeAscii){return "classifier_string_case_rune_ascii_api_missing"}
    if(!ckbP5ClassifierUnicodeImportRequired(value)){return "classifier_string_case_unicode_import_missing"}
    if(!value.contains("rune.tolowercase()")){return "classifier_string_case_unicode_rune_api_missing"}
    if(!ckbP5ClassifierRuneLowerResultValid(value)){return "classifier_string_case_unicode_return_type_missing"}
    let stringToLowerUnavailable=value.contains("string.tolower()")&&
        (value.contains("unavailable")||value.contains("does not provide")||value.contains("not a member")||value.contains("does not exist"))
    if(!stringToLowerUnavailable||!ckbP5ClassifierToLowerAsciiClaimValid(value)){return "classifier_string_case_invalid_api_negative_missing"}
    "ok"
}

private func ckbP5ClassifierDistinctCaseCountGoal(value:String):Bool{
    let count=value.contains("count")||value.contains("how many")||value.contains("number of")||
        value.contains("统计")||value.contains("计数")
    let distinct=value.contains("distinct")||value.contains("unique")||value.contains("不同")||
        value.contains("唯一")||value.contains("不重复")
    let character=value.contains("character")||value.contains("字符")
    let insensitive=value.contains("case-insensitive")||value.contains("case insensitive")||
        value.contains("case insensitively")||value.contains("regardless of case")||value.contains("ignore case")||
        value.contains("ignoring case")||value.contains("不区分大小写")||value.contains("忽略大小写")
    count&&distinct&&character&&insensitive
}

private func ckbP5ClassifierDistinctCaseCountSolution(knowledge:String):Bool{
    if(!ckbP5ClassifierDistinctCaseCountGoal(knowledge)){return false}
    knowledge.contains("hashset")||knowledge.contains("hash set")||knowledge.contains("collect ")||
        knowledge.contains("collect into")||knowledge.contains("collecting")||knowledge.contains("collected")||
        knowledge.contains("iterate over")||knowledge.contains("iterating over")||knowledge.contains("loop")||
        knowledge.contains("for (")||knowledge.contains("torunearray")||knowledge.contains("normalize case")||
        knowledge.contains("遍历")||knowledge.contains("循环")||knowledge.contains("收集")||
        (knowledge.contains("先")&&knowledge.contains("再"))||
        (knowledge.contains("first ")&&knowledge.contains(" then "))
}

private func ckbP5ClassifierAsciiApiFactValid(knowledge:String,api:String,resultType:String):Bool{
    for(clause in knowledge.replace(";", ". ").split(". ")){
        let value=clause.trimAscii()
        if(value.contains(api)&&value.contains("ascii-only")&&
            (value.contains("returns a ${resultType}")||value.contains(": ${resultType}"))){return true}
    }
    false
}

private func ckbP5ClassifierToLowerAsciiClaimValid(knowledge:String):Bool{
    if(!knowledge.contains("tolowerascii")){return true}
    if(knowledge.contains("//")||knowledge.contains("/*")||knowledge.contains("*/")){return false}
    let denied=knowledge.contains("tolowerascii is not a cangjie api")||
        knowledge.contains("tolowerascii is unavailable")||knowledge.contains("tolowerascii does not exist")
    if(!denied){return false}
    !(knowledge.contains("use tolowerascii")||knowledge.contains("call tolowerascii")||
        knowledge.contains("tolowerascii returns")||knowledge.contains("tolowerascii is available")||
        knowledge.contains("rune.tolowerascii")||knowledge.contains("string.tolowerascii"))
}

private func ckbP5ClassifierUnicodeImportRequired(knowledge:String):Bool{
    for(clause in knowledge.replace(";", ". ").split(". ")){
        let value=clause.trimAscii()
        if(!value.contains("std.unicode")){continue}
        if(value.contains("//")||value.contains("/*")||value.contains("*/")){return false}
        if(value.contains("requires import std.unicode")||value.contains("requires importing std.unicode")){return true}
    }
    false
}

private func ckbP5ClassifierRuneLowerResultValid(knowledge:String):Bool{
    for(clause in knowledge.replace(";", ". ").split(". ")){
        let value=clause.trimAscii()
        if(!value.contains("rune.tolowercase()")){continue}
        if(value.contains("//")||value.contains("/*")||value.contains("*/")){return false}
        if(value.contains("rune.tolowercase() returns a rune")||
            value.contains("rune.tolowercase() produces a rune")||
            value.contains("rune.tolowercase() result is a rune")||
            value.contains("result of rune.tolowercase() is a rune")||
            value.contains("rune.tolowercase(): rune")){return true}
    }
    false
}

private func ckbP5ClassifierReservedKeywordFactsDiagnostic(source:String,compiler:String,knowledge:String):String{
    let target=source.contains("var match")&&compiler.contains("expected identifier or pattern after 'var'")&&
        compiler.contains("found keyword 'match'")
    if(!target){return "ok"}
    if(knowledge.contains("//")||knowledge.contains("/*")||knowledge.contains("*/")){return "classifier_reserved_match_comment_disguised"}
    let absolute=knowledge.contains("can never be used as an identifier")||
        knowledge.contains("cannot ever be used as an identifier")||
        knowledge.contains("cannot be used as an identifier under any circumstances")||
        knowledge.contains("cannot be used as a local variable identifier")||
        knowledge.contains("cannot be used as a variable name or identifier")||
        knowledge.contains("cannot be used as an identifier")||
        knowledge.contains("always forbidden as an identifier")
    if(absolute){return "classifier_reserved_match_contradictory"}
    let plainContext=knowledge.contains("using the reserved keyword match directly")||
        knowledge.contains("using match directly")||knowledge.contains("unescaped match")||
        knowledge.contains("match without escaping")||
        ((knowledge.contains("`match`")||knowledge.contains("keyword match"))&&
        (knowledge.contains("plain identifier")||knowledge.contains("ordinary identifier")||knowledge.contains("regular identifier")))
    let plainInvalid=plainContext&&knowledge.contains("keyword")&&
        (knowledge.contains(" is invalid")||knowledge.contains("cannot be used directly")||
        knowledge.contains(" is not a valid")||knowledge.contains(" is illegal"))
    if(!plainInvalid){return "classifier_reserved_match_plain_missing"}
    let rawSyntax=knowledge.contains("`match`")&&
        (knowledge.contains("raw identifier")||knowledge.contains("escaped identifier"))
    let rawLegal=rawSyntax&&(knowledge.contains(" is legal")||knowledge.contains(" is allowed")||
        knowledge.contains(" is valid")||knowledge.contains(" can be used")||
        knowledge.contains("legal raw identifier")||knowledge.contains("valid raw identifier"))
    if(!rawLegal){return "classifier_reserved_match_raw_missing"}
    let rename=(knowledge.contains("rename")||knowledge.contains("renaming")||
        knowledge.contains("use a non-keyword")||knowledge.contains("choose a non-keyword"))&&
        (knowledge.contains("non-keyword identifier")||knowledge.contains("non-keyword variable")||
        knowledge.contains("non-keyword name")||knowledge.contains("different non-keyword"))
    if(!rename){return "classifier_reserved_match_rename_missing"}
    "ok"
}

public func ckbP5ClassifierArtifactEvidenceHash(raw:String):String{try{ckbP5ClassifierArtifactHash(JsonValue.fromStr(raw).asObject())}catch(_:Exception){""}}
public func ckbP5ClassifierArtifactConsensusHash(raw:String):String{try{ckbP5ClassifierConsensusHash(JsonValue.fromStr(raw).asObject())}catch(_:Exception){""}}
public func ckbP5ClassifierArtifactIdentityValid(raw:String):Bool{try{let o=JsonValue.fromStr(raw).asObject();let provider=ckbP5String(o,"provider");let model=ckbP5String(o,"expectedModel");let expectedIdentity=benchmarkGapSha256(ckbP5Part(provider)+ckbP5Part(model)+ckbP5Part(provider)+ckbP5Part(model));ckbP5String(o,"schemaVersion")==CKB_P5_CLASSIFIER_SCHEMA&&ckbP5String(o,"classifierId")!=""&&ckbP5String(o,"sourceEvidenceId")!=""&&provider!=""&&ckbP5String(o,"observedProvider")==provider&&model!=""&&ckbP5String(o,"observedModel")==model&&ckbP5String(o,"providerIdentityHash")==expectedIdentity&&ckbP5Hash(ckbP5String(o,"provenanceHash"))&&ckbP5Hash(ckbP5String(o,"workspaceId"))&&ckbP5Hash(ckbP5String(o,"runtimeHomeId"))&&ckbP5Hash(ckbP5String(o,"sessionId"))&&ckbP5Hash(ckbP5String(o,"consensusHash"))&&ckbP5Hash(ckbP5String(o,"evidenceHash"))&&ckbP5String(o,"consensusHash")==ckbP5ClassifierConsensusHash(o)&&ckbP5String(o,"evidenceHash")==ckbP5ClassifierArtifactHash(o)}catch(_:Exception){false}}
private func ckbP5ClassifierConsensusHash(o:JsonObject):String{let sourceTransport=ckbP5Int(o,"sourceTransportAttempt");benchmarkGapSha256(ckbP5Part(ckbP5String(o,"category").toAsciiLower())+ckbP5Part(ckbP5String(o,"caseId"))+ckbP5Part(ckbP5String(o,"runId"))+ckbP5Part(ckbP5String(o,"datasetVersion"))+ckbP5Part("${ckbP5Int(o,"attempt")}")+(if(sourceTransport>0){ckbP5Part("${sourceTransport}")}else{""})+ckbP5Part(ckbP5String(o,"runMode").toAsciiLower())+ckbP5Part(ckbP5String(o,"studentSourceHash").toAsciiLower())+ckbP5Part(ckbP5String(o,"resultEvidenceHash").toAsciiLower())+ckbP5Part(ckbP5String(o,"failureObservation"))+ckbP5Part(ckbP5String(o,"knowledgeFamily").toAsciiLower())+ckbP5Part("${ckbP5Bool(o,"reusable")}")+ckbP5Part(ckbP5String(o,"sourceClass").toAsciiLower())+ckbP5Part(ckbP5String(o,"citation").toAsciiLower())+ckbP5Part("${ckbP5Bool(o,"purificationPassed")}")+ckbP5Part(ckbP5String(o,"canonicalKnowledgeId"))+ckbP5Part(ckbP5String(o,"targetVersion"))+ckbP5Part(ckbP5String(o,"evidenceId"))+ckbP5Part(ckbP5String(o,"knowledgeText"))+ckbP5Part(ckbP5String(o,"exampleText"))+ckbP5Part(ckbP5String(o,"testText"))+ckbP5Part(ckbP5String(o,"publishableMetadata")))}
private func ckbP5ClassifierArtifactHash(o:JsonObject):String{benchmarkGapSha256(ckbP5Part(ckbP5String(o,"schemaVersion"))+ckbP5Part(ckbP5String(o,"classifierId"))+ckbP5Part(ckbP5String(o,"sourceEvidenceId"))+ckbP5Part(ckbP5String(o,"provider"))+ckbP5Part(ckbP5String(o,"observedProvider"))+ckbP5Part(ckbP5String(o,"expectedModel"))+ckbP5Part(ckbP5String(o,"observedModel"))+ckbP5Part(ckbP5String(o,"providerIdentityHash"))+ckbP5Part(ckbP5String(o,"provenanceHash"))+ckbP5Part(ckbP5String(o,"workspaceId"))+ckbP5Part(ckbP5String(o,"runtimeHomeId"))+ckbP5Part(ckbP5String(o,"sessionId"))+ckbP5Part(ckbP5ClassifierConsensusHash(o))+ckbP5Part(ckbP5String(o,"consensusHash")))}
private func ckbP5Hash(v:String):Bool{let r=v.toRuneArray();if(r.size!=71||!v.startsWith("sha256:")){return false};for(i in 7..71){let c=r[i];if(!((c>=r'0'&&c<=r'9')||(c>=r'a'&&c<=r'f'))){return false}};true}

private func ckbP5SharedClassifierFields(request:JsonObject,response:JsonObject,category:String):String{
    let knowledge=category=="knowledge_gap"
    let family=if(knowledge){ckbP5String(response,"knowledgeFamily").toAsciiLower()}else{""}
    let source=if(knowledge){ckbP5String(response,"sourceClass").toAsciiLower()}else{""}
    let sourceTransport=ckbP5Int(request,"sourceTransportAttempt");let transportField=if(sourceTransport>0){",\"sourceTransportAttempt\":${sourceTransport}"}else{""}
    "\"category\":\"${ckbP5Escape(category)}\",\"caseId\":\"${ckbP5Escape(ckbP5String(request,"caseId"))}\",\"runId\":\"${ckbP5Escape(ckbP5String(request,"runId"))}\",\"datasetVersion\":\"${ckbP5Escape(ckbP5String(request,"datasetVersion"))}\",\"attempt\":1${transportField},\"runMode\":\"development\",\"studentSourceHash\":\"${ckbP5Escape(ckbP5String(request,"studentSourceHash"))}\",\"resultEvidenceHash\":\"${ckbP5Escape(ckbP5String(request,"resultEvidenceHash"))}\",\"failureObservation\":\"${ckbP5Escape(ckbP5String(request,"failureObservation"))}\",\"knowledgeFamily\":\"${ckbP5Escape(family)}\",\"reusable\":${knowledge&&ckbP5Bool(response,"reusable")},\"sourceClass\":\"${ckbP5Escape(source)}\",\"citation\":\"${if(knowledge){ckbP5Escape(ckbP5String(response,"citation"))}else{""}}\",\"purificationPassed\":${knowledge&&ckbP5Bool(response,"purificationPassed")},\"canonicalKnowledgeId\":\"${if(knowledge){ckbP5Escape(ckbP5String(response,"canonicalKnowledgeId"))}else{""}}\",\"targetVersion\":\"${if(knowledge){ckbP5Escape(ckbP5String(response,"targetVersion"))}else{""}}\",\"evidenceId\":\"${if(knowledge){ckbP5Escape(ckbP5String(response,"evidenceId"))}else{""}}\",\"knowledgeText\":\"${if(knowledge){ckbP5Escape(ckbP5String(response,"knowledgeText"))}else{""}}\",\"exampleText\":\"\",\"testText\":\"\",\"publishableMetadata\":\"classifier-stage-only\""
}

func ckbP5CompilerSummary(text:String,failureType:String):String{
    if(failureType=="unit_failure"||failureType=="test_failure"){
        var out="";for(line in text.split("\n")){let clean=ckbP5StripAnsi(line).trimAscii();let lower=clean.toAsciiLower();if(clean.contains("/")||ckbP5Forbidden(clean)){continue};if(lower.contains("exception")||lower.contains("expected")||lower.contains("assert")){if(out!=""){out+=" | "};out+=utf8SafePrefix(clean,240);if(out.toRuneArray().size>=960){break}}};return if(out==""){"unit_test_failed_without_assertion_detail"}else{utf8SafePrefix(out,1024)}
    }
    if(failureType!="compile_error"){return utf8SafePrefix(failureType,120)}
    var out="";for(line in text.split("\n")){
        let clean=ckbP5StripAnsi(line).trimAscii();let lower=clean.toAsciiLower()
        if(lower.contains("==>")){let location=ckbP5CompilerLocation(clean);if(location!=""){if(out!=""){out+=" | "};out+=location};continue}
        if(ckbP5Forbidden(clean)||clean.contains("/")){continue}
        if(lower.contains("error")||lower.contains("expected")||lower.contains("found")){if(out!=""){out+=" | "};out+=utf8SafePrefix(clean,240);if(out.toRuneArray().size>=960){break}}
    };utf8SafePrefix(out,1024)
}
public func ckbP5CompilerSummaryFromBytes(bytes:Array<UInt8>,failureType:String):String{
    let text=try{String.fromUtf8(bytes)}catch(_:Exception){return "invalid_response_encoding"}
    let summary=ckbP5CompilerSummary(text,failureType);let lower=summary.toAsciiLower()
    if(lower.contains("assert")||lower.contains("expected")){"test_failure_detail_redacted"}else{summary}
}
private func ckbP5CompilerLocation(value:String):String{
    let runes=value.toRuneArray();var separator:Int64=-1
    for(i in 0..runes.size){if(runes[i]==r'/'||runes[i]==r'\\'){separator=i}}
    if(separator<0||separator+1>=runes.size){return ""}
    let suffix=StringBuilder();for(i in (separator+1)..runes.size){suffix.append(runes[i])}
    let safe=suffix.toString().trimAscii();if(safe==""||ckbP5Forbidden(safe)){""}else{"location ${utf8SafePrefix(safe,160)}"}
}
private func ckbP5StripAnsi(value:String):String{var out=value;for(code in ["\u{001b}[31m","\u{001b}[0m","\u{001b}[36m","\u{001b}[32m"]){out=out.replace(code,"")};out}
private func ckbP5Forbidden(value:String):Bool{let v=value.toAsciiLower();v.contains("teacher-solutions")||v.contains("canonical_solution")||v.contains("hidden_test")||v.contains("hidden-test")||v.contains("/reference/")||v.contains("authorization:")||v.contains("password")||v.contains("api_key")||v.contains("token=")}
private func ckbP5IndependentConfigs(a:CkbP5ClassifierConfig,b:CkbP5ClassifierConfig):Bool{a.classifierId!=""&&b.classifierId!=""&&a.classifierId!=b.classifierId&&a.provider=="codex"&&a.model=="GPT-5.6-Sol"&&b.provider=="claude-code"&&b.model=="GLM-5.2"&&a.executable.startsWith("/")&&b.executable.startsWith("/")&&a.executable!=b.executable}
private func ckbP5SafeControlRoots(runRoot:String,outputRoot:String):Bool{runRoot.startsWith("/")&&outputRoot.startsWith("/")&&runRoot!=outputRoot&&!outputRoot.startsWith(runRoot+"/cases/")&&!runRoot.contains("/ckb-data")&&!outputRoot.contains("/ckb-data")}
private func ckbP5ClassifierCategory(v:String):Bool{v=="knowledge_gap"||v=="retrieval_failure"||v=="reasoning_failure"||v=="compile_error"||v=="unit_failure"||v=="dataset_failure"||v=="runner_failure"||v=="environment_failure"||v=="tool_error"||v=="timeout"||v=="protocol_violation"}
private func ckbP5AtomicWrite(path:Path,text:String):Bool{try{if(!exists(path.parent)){Directory.create(path.parent,recursive:true)};let tmp=path.parent.join(".tmp-${benchmarkGapSha256(path.toString()+text).replace("sha256:","")}");File.writeTo(tmp,text.toArray());if(ckbP5ReadUtf8(tmp)!=text){_=launch("/bin/rm",["-f",tmp.toString()]).wait();return false};launch("/bin/mv",["-f",tmp.toString(),path.toString()]).wait()==0}catch(_:Exception){false}}
private func ckbP5ReadUtf8(path:Path):String{if(!exists(path)){return ""};try{String.fromUtf8(File.readFrom(path))}catch(_:Exception){""}}
private func ckbP5CaseId(i:Int64):String{if(i<10){"CJ-HUMANEVAL-00${i}"}else if(i<100){"CJ-HUMANEVAL-0${i}"}else{"CJ-HUMANEVAL-${i}"}}
private func ckbP5Part(value:String):String{"${value.toArray().size}:${value}"}
private func ckbP5String(o:JsonObject,k:String):String{match(o.get(k)){case Some(v)=>v.asString().getValue().trimAscii();case None=>""}}
private func ckbP5Bool(o:JsonObject,k:String):Bool{match(o.get(k)){case Some(v)=>v.asBool().getValue();case None=>false}}
private func ckbP5Int(o:JsonObject,k:String):Int64{match(o.get(k)){case Some(v)=>v.asInt().getValue();case None=>0}}
private func ckbP5Escape(v:String):String{v.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r").replace("\t","\\t")}
