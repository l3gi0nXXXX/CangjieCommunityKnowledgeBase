package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashSet}
import std.fs.{Directory, File, Path, exists}
import stdx.encoding.json.*

public class CkbCertificationCaseEvidence {
    public var schemaVersion: String = "ckb-humaneval-certification-result-v2"
    public var runId: String = ""
    public var caseId: String = ""
    public var group: String = ""
    public var datasetVersion: String = ""
    public var knowledgeVersion: String = ""
    public var modelFingerprint: String = ""
    public var expectedModelVersion: String = ""
    public var observedModelVersion: String = ""
    public var claudeCodeVersion: String = ""
    public var providerIdentityHash: String = ""
    public var preflightHash: String = ""
    public var runManifestHash: String = ""
    public var authorityCaseHash: String = ""
    public var authorityTestsHash: String = ""
    public var workspaceId: String = ""
    public var sessionId: String = ""
    public var runtimeHomeId: String = ""
    public var isolationEvidenceHash: String = ""
    public var answerHash: String = ""
    public var transcriptHash: String = ""
    public var testHash: String = ""
    public var configHash: String = ""
    public var artifactHash: String = ""
    public var attempt: Int64 = 1
    public var sampleAttemptCount: Int64 = 0
    public var retryUsed: Bool = false
    public var fallbackUsed: Bool = false
    public var agentRetryCount: Int64 = 0
    public var providerRetryCount: Int64 = 0
    public var sdkRetryCount: Int64 = 0
    public var llmTurnCount: Int64 = 0
    public var referenceExposure: Int64 = 0
    public var hiddenTestExposure: Int64 = 0
    public var teacherExposure: Int64 = 0
    public var crossCaseExposure: Int64 = 0
    public var sandboxDeniedOutsideWorkspace: Bool = false
    public var verifierMountedAfterAnswerFreeze: Bool = false
    public var certificationPassAt1: Bool = false
    public var resultEvidenceHash: String = ""
    public var valid: Bool = false
    public var diagnostic: String = ""
    public init() {}
}

public class CkbStrictCertificationGateResult {
    public var ok: Bool = false
    public var total: Int64 = 0
    public var unitPass: Int64 = 0
    public var unitPassAt1: Int64 = 0
    public var failed: Int64 = 0
    public var invalid: Int64 = 0
    public var retryUsed: Int64 = 0
    public var fallbackUsed: Int64 = 0
    public var referenceExposure: Int64 = 0
    public var hiddenTestExposure: Int64 = 0
    public var teacherExposure: Int64 = 0
    public var crossCaseExposure: Int64 = 0
    public var group: String = ""
    public var datasetVersion: String = ""
    public var knowledgeVersion: String = ""
    public var modelFingerprint: String = ""
    public var diagnostics: ArrayList<String> = ArrayList<String>()
    public init() {}
    public func fail(message: String): Unit { this.diagnostics.add(message) }
}

public func ckbCertificationEvidenceSeed(row: CkbCertificationCaseEvidence): String {
    ckbCertPart(row.schemaVersion) + ckbCertPart(row.runId) + ckbCertPart(row.caseId) + ckbCertPart(row.group) +
        ckbCertPart(row.datasetVersion) + ckbCertPart(row.knowledgeVersion) + ckbCertPart(row.modelFingerprint) +
        ckbCertPart(row.expectedModelVersion) + ckbCertPart(row.observedModelVersion) + ckbCertPart(row.claudeCodeVersion) +
        ckbCertPart(row.providerIdentityHash) + ckbCertPart(row.preflightHash) + ckbCertPart(row.runManifestHash) + ckbCertPart(row.authorityCaseHash) + ckbCertPart(row.authorityTestsHash) +
        ckbCertPart(row.workspaceId) + ckbCertPart(row.sessionId) + ckbCertPart(row.runtimeHomeId) +
        ckbCertPart(row.isolationEvidenceHash) + ckbCertPart(row.answerHash) + ckbCertPart(row.transcriptHash) +
        ckbCertPart(row.testHash) + ckbCertPart(row.configHash) + ckbCertPart(row.artifactHash) +
        ckbCertPart("${row.attempt}") + ckbCertPart("${row.sampleAttemptCount}") + ckbCertPart("${row.retryUsed}") + ckbCertPart("${row.fallbackUsed}") +
        ckbCertPart("${row.agentRetryCount}") + ckbCertPart("${row.providerRetryCount}") + ckbCertPart("${row.sdkRetryCount}") + ckbCertPart("${row.llmTurnCount}") +
        ckbCertPart("${row.referenceExposure}") + ckbCertPart("${row.hiddenTestExposure}") + ckbCertPart("${row.teacherExposure}") +
        ckbCertPart("${row.crossCaseExposure}") + ckbCertPart("${row.sandboxDeniedOutsideWorkspace}") +
        ckbCertPart("${row.verifierMountedAfterAnswerFreeze}") + ckbCertPart("${row.certificationPassAt1}")
}

public func sealCkbCertificationEvidence(row: CkbCertificationCaseEvidence): Unit {
    row.resultEvidenceHash = benchmarkGapSha256(ckbCertificationEvidenceSeed(row))
}

public func renderCkbCertificationEvidenceJson(row: CkbCertificationCaseEvidence): String {
    "{\"schemaVersion\":\"${ckbCertEscape(row.schemaVersion)}\",\"runId\":\"${ckbCertEscape(row.runId)}\",\"caseId\":\"${ckbCertEscape(row.caseId)}\",\"group\":\"${ckbCertEscape(row.group)}\",\"datasetVersion\":\"${ckbCertEscape(row.datasetVersion)}\",\"knowledgeVersion\":\"${ckbCertEscape(row.knowledgeVersion)}\",\"modelFingerprint\":\"${ckbCertEscape(row.modelFingerprint)}\",\"expectedModelVersion\":\"${ckbCertEscape(row.expectedModelVersion)}\",\"observedModelVersion\":\"${ckbCertEscape(row.observedModelVersion)}\",\"claudeCodeVersion\":\"${ckbCertEscape(row.claudeCodeVersion)}\",\"providerIdentityHash\":\"${ckbCertEscape(row.providerIdentityHash)}\",\"preflightHash\":\"${ckbCertEscape(row.preflightHash)}\",\"runManifestHash\":\"${ckbCertEscape(row.runManifestHash)}\",\"authorityCaseHash\":\"${ckbCertEscape(row.authorityCaseHash)}\",\"authorityTestsHash\":\"${ckbCertEscape(row.authorityTestsHash)}\",\"workspaceId\":\"${ckbCertEscape(row.workspaceId)}\",\"sessionId\":\"${ckbCertEscape(row.sessionId)}\",\"runtimeHomeId\":\"${ckbCertEscape(row.runtimeHomeId)}\",\"isolationEvidenceHash\":\"${ckbCertEscape(row.isolationEvidenceHash)}\",\"answerHash\":\"${ckbCertEscape(row.answerHash)}\",\"transcriptHash\":\"${ckbCertEscape(row.transcriptHash)}\",\"testHash\":\"${ckbCertEscape(row.testHash)}\",\"configHash\":\"${ckbCertEscape(row.configHash)}\",\"artifactHash\":\"${ckbCertEscape(row.artifactHash)}\",\"attempt\":${row.attempt},\"sampleAttemptCount\":${row.sampleAttemptCount},\"retryUsed\":${row.retryUsed},\"fallbackUsed\":${row.fallbackUsed},\"agentRetryCount\":${row.agentRetryCount},\"providerRetryCount\":${row.providerRetryCount},\"sdkRetryCount\":${row.sdkRetryCount},\"llmTurnCount\":${row.llmTurnCount},\"referenceExposure\":${row.referenceExposure},\"hiddenTestExposure\":${row.hiddenTestExposure},\"teacherExposure\":${row.teacherExposure},\"crossCaseExposure\":${row.crossCaseExposure},\"sandboxDeniedOutsideWorkspace\":${row.sandboxDeniedOutsideWorkspace},\"verifierMountedAfterAnswerFreeze\":${row.verifierMountedAfterAnswerFreeze},\"certificationPassAt1\":${row.certificationPassAt1},\"resultEvidenceHash\":\"${ckbCertEscape(row.resultEvidenceHash)}\"}"
}

public func parseCkbCertificationEvidence(line: String): CkbCertificationCaseEvidence {
    let row = CkbCertificationCaseEvidence()
    try {
        let o = JsonValue.fromStr(line).asObject()
        row.schemaVersion = ckbCertString(o, "schemaVersion"); row.runId = ckbCertString(o, "runId"); row.caseId = ckbCertString(o, "caseId"); row.group = ckbCertString(o, "group")
        row.datasetVersion = ckbCertString(o, "datasetVersion"); row.knowledgeVersion = ckbCertString(o, "knowledgeVersion"); row.modelFingerprint = ckbCertString(o, "modelFingerprint"); row.expectedModelVersion = ckbCertString(o, "expectedModelVersion"); row.observedModelVersion = ckbCertString(o, "observedModelVersion"); row.claudeCodeVersion = ckbCertString(o, "claudeCodeVersion"); row.providerIdentityHash = ckbCertString(o, "providerIdentityHash")
        row.preflightHash = ckbCertString(o, "preflightHash"); row.runManifestHash = ckbCertString(o, "runManifestHash"); row.authorityCaseHash=ckbCertString(o,"authorityCaseHash");row.authorityTestsHash=ckbCertString(o,"authorityTestsHash"); row.workspaceId = ckbCertString(o, "workspaceId"); row.sessionId = ckbCertString(o, "sessionId"); row.runtimeHomeId = ckbCertString(o, "runtimeHomeId")
        row.isolationEvidenceHash = ckbCertString(o, "isolationEvidenceHash"); row.answerHash = ckbCertString(o, "answerHash"); row.transcriptHash = ckbCertString(o, "transcriptHash"); row.testHash = ckbCertString(o, "testHash"); row.configHash = ckbCertString(o, "configHash"); row.artifactHash = ckbCertString(o, "artifactHash")
        row.attempt = ckbCertInt(o, "attempt"); row.sampleAttemptCount=ckbCertInt(o,"sampleAttemptCount"); row.retryUsed = ckbCertBool(o, "retryUsed"); row.fallbackUsed = ckbCertBool(o, "fallbackUsed"); row.agentRetryCount = ckbCertInt(o, "agentRetryCount"); row.providerRetryCount = ckbCertInt(o, "providerRetryCount"); row.sdkRetryCount = ckbCertInt(o, "sdkRetryCount");row.llmTurnCount=ckbCertInt(o,"llmTurnCount")
        row.referenceExposure = ckbCertInt(o, "referenceExposure"); row.hiddenTestExposure = ckbCertInt(o, "hiddenTestExposure"); row.teacherExposure = ckbCertInt(o, "teacherExposure"); row.crossCaseExposure = ckbCertInt(o, "crossCaseExposure")
        row.sandboxDeniedOutsideWorkspace = ckbCertBool(o, "sandboxDeniedOutsideWorkspace"); row.verifierMountedAfterAnswerFreeze = ckbCertBool(o, "verifierMountedAfterAnswerFreeze"); row.certificationPassAt1 = ckbCertBool(o, "certificationPassAt1"); row.resultEvidenceHash = ckbCertString(o, "resultEvidenceHash")
    } catch (_: Exception) { row.diagnostic = "malformed_json"; return row }
    row.diagnostic = ckbCertificationEvidenceDiagnostic(row)
    row.valid = row.diagnostic == "ok"
    row
}

public func ckbCertificationEvidenceDiagnostic(row: CkbCertificationCaseEvidence): String {
    if (row.schemaVersion != "ckb-humaneval-certification-result-v2") { return "unknown_schema" }
    if (row.runId == "" || row.caseId == "" || row.group == "" || row.datasetVersion == "" || row.knowledgeVersion == "" || row.modelFingerprint == "") { return "identity_field_required" }
    if (row.expectedModelVersion == "" || row.observedModelVersion != row.expectedModelVersion || row.claudeCodeVersion == "") { return "observed_model_identity_mismatch" }
    if (row.group != CkbAbcdeGroups.C && row.group != CkbAbcdeGroups.D) { return "single_treatment_transport_required" }
    for (hash in [row.providerIdentityHash,row.preflightHash,row.runManifestHash,row.authorityCaseHash,row.authorityTestsHash,row.isolationEvidenceHash,row.answerHash,row.transcriptHash,row.testHash,row.configHash,row.artifactHash]) { if (!ckbCertHash(hash)) { return "artifact_hash_invalid" } }
    if (row.attempt != 1 || row.retryUsed || row.fallbackUsed || row.agentRetryCount != 0 || row.providerRetryCount != 0 || row.sdkRetryCount != 0) { return "retry_or_fallback_forbidden" }
    if(row.sampleAttemptCount!=1){return "sample_attempt_count_must_equal_one"}
    if(row.llmTurnCount<=0){return "llm_turn_count_required"}
    if (row.referenceExposure != 0 || row.hiddenTestExposure != 0 || row.teacherExposure != 0 || row.crossCaseExposure != 0) { return "model_exposure_forbidden" }
    if (!row.sandboxDeniedOutsideWorkspace) { return "auditable_sandbox_deny_required" }
    if (!row.verifierMountedAfterAnswerFreeze) { return "verifier_mount_order_invalid" }
    if (row.resultEvidenceHash != benchmarkGapSha256(ckbCertificationEvidenceSeed(row))) { return "result_evidence_hash_mismatch" }
    "ok"
}

public func ckbStrictCertificationGate(resultsText: String, authorityManifestText: String): CkbStrictCertificationGateResult {
    let gate = CkbStrictCertificationGateResult()
    let authority = parseCangjieHumanEvalAuthorityManifest(authorityManifestText)
    if (!authority.ok || authority.rows.size != 164) { gate.fail("authority_manifest_invalid"); return gate }
    let expected = HashSet<String>(); for (i in 0..164) { expected.add(ckbCertCaseId(i)) }
    for (row in authority.rows) { if (!expected.contains(row.caseId)) { gate.fail("authority_case_set_invalid:${row.caseId}") } }
    let seenCases = HashSet<String>(); let workspaces = HashSet<String>(); let sessions = HashSet<String>(); let homes = HashSet<String>()
    var runId = ""; var preflightHash = ""; var runManifestHash = ""; var providerHash = ""
    for (line in resultsText.split("\n")) {
        if (line.trimAscii() == "") { continue }
        gate.total += 1
        let row = parseCkbCertificationEvidence(line)
        if (!row.valid) { gate.invalid += 1; gate.fail("invalid_row:${row.caseId}:${row.diagnostic}"); continue }
        if (!expected.contains(row.caseId)) { gate.fail("unexpected_case:${row.caseId}") }
        if (cangjieHumanEvalAuthorityDatasetDiagnostic(authority, row.datasetVersion) != "ok") { gate.fail("authority_dataset_version_mismatch:${row.caseId}") }
        var authorityBound=false;for(ar in authority.rows){if(ar.caseId==row.caseId){authorityBound=row.authorityCaseHash==ar.caseHash&&row.authorityTestsHash==ar.testsHash}}
        if(!authorityBound){gate.fail("authority_hash_binding_mismatch:${row.caseId}")}
        if (seenCases.contains(row.caseId)) { gate.fail("duplicate_case:${row.caseId}") } else { seenCases.add(row.caseId) }
        if (workspaces.contains(row.workspaceId) || sessions.contains(row.sessionId) || homes.contains(row.runtimeHomeId)) { gate.fail("isolation_identity_reuse:${row.caseId}") }
        workspaces.add(row.workspaceId); sessions.add(row.sessionId); homes.add(row.runtimeHomeId)
        if (runId == "") { runId=row.runId; gate.group=row.group; gate.datasetVersion=row.datasetVersion; gate.knowledgeVersion=row.knowledgeVersion; gate.modelFingerprint=row.modelFingerprint; preflightHash=row.preflightHash; runManifestHash=row.runManifestHash; providerHash=row.providerIdentityHash }
        if (row.runId!=runId || row.group!=gate.group || row.datasetVersion!=gate.datasetVersion || row.knowledgeVersion!=gate.knowledgeVersion || row.modelFingerprint!=gate.modelFingerprint || row.preflightHash!=preflightHash || row.runManifestHash!=runManifestHash || row.providerIdentityHash!=providerHash) { gate.fail("certification_lineage_drift:${row.caseId}") }
        gate.retryUsed += if (row.retryUsed || row.agentRetryCount>0 || row.providerRetryCount>0 || row.sdkRetryCount>0) {1}else{0}; gate.fallbackUsed += if(row.fallbackUsed){1}else{0}
        gate.referenceExposure += row.referenceExposure; gate.hiddenTestExposure += row.hiddenTestExposure; gate.teacherExposure += row.teacherExposure; gate.crossCaseExposure += row.crossCaseExposure
        if (row.certificationPassAt1) { gate.unitPass+=1; gate.unitPassAt1+=1 } else { gate.failed+=1 }
    }
    if (gate.total != 164) { gate.fail("result_count_mismatch:${gate.total}:164") }
    for (id in expected) { if (!seenCases.contains(id)) { gate.fail("missing_case:${id}") } }
    if (gate.unitPassAt1 != 164 || gate.failed != 0 || gate.invalid != 0 || gate.retryUsed != 0 || gate.fallbackUsed != 0 || gate.referenceExposure != 0 || gate.hiddenTestExposure != 0 || gate.teacherExposure != 0 || gate.crossCaseExposure != 0) { gate.fail("strict_pass_at_1_requirements_not_met") }
    gate.ok = gate.diagnostics.size == 0
    gate
}

public func renderCkbStrictCertificationGateJson(g: CkbStrictCertificationGateResult): String {
    var ds=""; for(i in 0..g.diagnostics.size){if(i>0){ds+=","};ds+="\"${ckbCertEscape(g.diagnostics[i])}\""}
    "{\"schemaVersion\":\"ckb-humaneval-certification-gate-v1\",\"ok\":${g.ok},\"total\":${g.total},\"unitPass\":${g.unitPass},\"unitPassAt1\":${g.unitPassAt1},\"failed\":${g.failed},\"invalid\":${g.invalid},\"retryUsed\":${g.retryUsed},\"fallbackUsed\":${g.fallbackUsed},\"referenceExposure\":${g.referenceExposure},\"hiddenTestExposure\":${g.hiddenTestExposure},\"teacherExposure\":${g.teacherExposure},\"crossCaseExposure\":${g.crossCaseExposure},\"group\":\"${ckbCertEscape(g.group)}\",\"datasetVersion\":\"${ckbCertEscape(g.datasetVersion)}\",\"knowledgeVersion\":\"${ckbCertEscape(g.knowledgeVersion)}\",\"modelFingerprint\":\"${ckbCertEscape(g.modelFingerprint)}\",\"diagnostics\":[${ds}]}"
}

public func renderCkbStrictCertificationGateMarkdown(g: CkbStrictCertificationGateResult): String {
    "# Cangjie HumanEval strict certification\n\n- status: ${if(g.ok){"pass"}else{"fail"}}\n- transport: ${g.group}\n- total: ${g.total}\n- unitPassAt1: ${g.unitPassAt1}\n- invalid: ${g.invalid}\n- retry/fallback: ${g.retryUsed}/${g.fallbackUsed}\n- exposure(reference/hidden/teacher/cross-case): ${g.referenceExposure}/${g.hiddenTestExposure}/${g.teacherExposure}/${g.crossCaseExposure}\n"
}

public open class CkbCertificationExecutor {
    public open func execute(caseId: String, workspace: String, sessionId: String, runtimeHome: String): CkbCertificationCaseEvidence { let r=CkbCertificationCaseEvidence();r.caseId=caseId;r.diagnostic="executor_not_configured";r }
}

public func orchestrateCkbStrictCertification(runRoot:String, authorityManifestText:String, template:CkbCertificationCaseEvidence, executor:CkbCertificationExecutor):CkbStrictCertificationGateResult {
    if (!exists(Path(runRoot))) { Directory.create(Path(runRoot), recursive:true) }
    for (_ in Directory.readFrom(Path(runRoot))) { let g=CkbStrictCertificationGateResult();g.fail("run_root_not_empty");return g }
    let authority=parseCangjieHumanEvalAuthorityManifest(authorityManifestText);if(!authority.ok||authority.rows.size!=164){let g=CkbStrictCertificationGateResult();g.fail("authority_manifest_invalid");return g}
    var lines=""
    for(i in 0..authority.rows.size){let authorityRow=authority.rows[i];let id=authorityRow.caseId;let caseRoot=Path(runRoot).join("cases").join(id);let workspace=caseRoot.join("workspace");let home=caseRoot.join("runtime-home");Directory.create(workspace,recursive:true);Directory.create(home,recursive:true);let session="${template.runId}-${id}-session";let row=executor.execute(id,workspace.toString(),session,home.toString());row.runId=template.runId;row.caseId=id;row.group=template.group;row.datasetVersion=template.datasetVersion;row.knowledgeVersion=template.knowledgeVersion;row.modelFingerprint=template.modelFingerprint;row.expectedModelVersion=template.expectedModelVersion;row.providerIdentityHash=template.providerIdentityHash;row.preflightHash=template.preflightHash;row.runManifestHash=template.runManifestHash;row.authorityCaseHash=authorityRow.caseHash;row.authorityTestsHash=authorityRow.testsHash;row.workspaceId=benchmarkGapSha256(workspace.toString());row.sessionId=benchmarkGapSha256(session);row.runtimeHomeId=benchmarkGapSha256(home.toString());sealCkbCertificationEvidence(row);let json=renderCkbCertificationEvidenceJson(row);File.writeTo(caseRoot.join("result-evidence.json"),json.toArray());lines+=json+"\n"}
    File.writeTo(Path(runRoot).join("results.jsonl"),lines.toArray());let gate=ckbStrictCertificationGate(lines,authorityManifestText);File.writeTo(Path(runRoot).join("certification-gate.json"),renderCkbStrictCertificationGateJson(gate).toArray());gate
}

private func ckbCertPart(v:String):String{"${v.toArray().size}:${v}"}
private func ckbCertEscape(v:String):String{v.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r").replace("\t","\\t")}
private func ckbCertString(o:JsonObject,k:String):String{match(o.get(k)){case Some(v)=>v.asString().getValue();case None=>throw Exception("missing")}}
private func ckbCertInt(o:JsonObject,k:String):Int64{match(o.get(k)){case Some(v)=>v.asInt().getValue();case None=>throw Exception("missing")}}
private func ckbCertBool(o:JsonObject,k:String):Bool{match(o.get(k)){case Some(v)=>v.asBool().getValue();case None=>throw Exception("missing")}}
private func ckbCertHash(v:String):Bool{if(v.toRuneArray().size!=71||!v.startsWith("sha256:")){return false};for(c in v.toRuneArray()[7..71]){if(!((c>=r'0'&&c<=r'9')||(c>=r'a'&&c<=r'f'))){return false}};true}
private func ckbCertCaseId(i:Int64):String{if(i<10){"CJ-HUMANEVAL-00${i}"}else if(i<100){"CJ-HUMANEVAL-0${i}"}else{"CJ-HUMANEVAL-${i}"}}
