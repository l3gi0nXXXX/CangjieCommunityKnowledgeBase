package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashSet}
import std.fs.{Directory, File, Path, exists, canonicalize}
import stdx.encoding.json.*

public class CkbCertificationCaseEvidence {
    public var schemaVersion: String = "ckb-humaneval-certification-result-v3"
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
    public var lastAuditedTransportAttempt: Int64 = 1
    public var selectedBusinessSample: Int64 = 0
    public var transportAttemptCount: Int64 = 1
    public var retryCount: Int64 = 0
    public var unresolvedTransport: Int64 = 0
    public var attemptLineageHash: String = ""
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
    public var generationProtocol: String = "historical-agentic-v1"
    public var samplingCapability: String = "historical"
    public var completionCount: Int64 = 0
    public var toolCallCount: Int64 = 0
    public var executionFeedbackCount: Int64 = 0
    public var answerFreezeSequence: Int64 = 0
    public var firstExecutionSequence: Int64 = 0
    public var baseAnswerHash: String = ""
    public var plusAnswerHash: String = ""
    public var basePassed: Bool = false
    public var plusPassed: Bool = false
    public var skillBundleVersion: String = ""
    public var skillBundleHash: String = ""
    public var assetLineage: String = ""
    public var rulesHash: String = ""
    public var rulesTreeHash: String = ""
    public var rulesCount: Int64 = 0
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
    public var transportRetryCount: Int64 = 0
    public var unresolvedTransport: Int64 = 0
    public var fallbackUsed: Int64 = 0
    public var referenceExposure: Int64 = 0
    public var hiddenTestExposure: Int64 = 0
    public var teacherExposure: Int64 = 0
    public var crossCaseExposure: Int64 = 0
    public var group: String = ""
    public var datasetVersion: String = ""
    public var knowledgeVersion: String = ""
    public var modelFingerprint: String = ""
    public var artifactManifestHash: String = ""
    public var diagnostics: ArrayList<String> = ArrayList<String>()
    public init() {}
    public func fail(message: String): Unit { this.diagnostics.add(message) }
}

public func ckbCertificationEvidenceSeed(row: CkbCertificationCaseEvidence): String {
    let completionSeed=if(row.schemaVersion=="ckb-humaneval-certification-result-v4"||row.schemaVersion=="ckb-humaneval-certification-result-v5"){
        ckbCertPart(row.generationProtocol)+ckbCertPart(row.samplingCapability)+ckbCertPart("${row.completionCount}")+
        ckbCertPart("${row.toolCallCount}")+ckbCertPart("${row.executionFeedbackCount}")+ckbCertPart("${row.answerFreezeSequence}")+
        ckbCertPart("${row.firstExecutionSequence}")+ckbCertPart(row.baseAnswerHash)+ckbCertPart(row.plusAnswerHash)+
        ckbCertPart("${row.basePassed}")+ckbCertPart("${row.plusPassed}")+ckbCertPart(row.skillBundleVersion)+
        ckbCertPart(row.skillBundleHash)+ckbCertPart(row.assetLineage)+if(row.schemaVersion=="ckb-humaneval-certification-result-v5"){ckbCertPart(row.rulesHash)+ckbCertPart(row.rulesTreeHash)+ckbCertPart("${row.rulesCount}")}else{""}
    }else{""}
    ckbCertPart(row.schemaVersion) + ckbCertPart(row.runId) + ckbCertPart(row.caseId) + ckbCertPart(row.group) +
        ckbCertPart(row.datasetVersion) + ckbCertPart(row.knowledgeVersion) + ckbCertPart(row.modelFingerprint) +
        ckbCertPart(row.expectedModelVersion) + ckbCertPart(row.observedModelVersion) + ckbCertPart(row.claudeCodeVersion) +
        ckbCertPart(row.providerIdentityHash) + ckbCertPart(row.preflightHash) + ckbCertPart(row.runManifestHash) + ckbCertPart(row.authorityCaseHash) + ckbCertPart(row.authorityTestsHash) +
        ckbCertPart(row.workspaceId) + ckbCertPart(row.sessionId) + ckbCertPart(row.runtimeHomeId) +
        ckbCertPart(row.isolationEvidenceHash) + ckbCertPart(row.answerHash) + ckbCertPart(row.transcriptHash) +
        ckbCertPart(row.testHash) + ckbCertPart(row.configHash) + ckbCertPart(row.artifactHash) +
        ckbCertPart("${row.attempt}") + ckbCertPart("${row.sampleAttemptCount}") + ckbCertPart("${row.lastAuditedTransportAttempt}") + ckbCertPart("${row.selectedBusinessSample}") + ckbCertPart("${row.transportAttemptCount}") + ckbCertPart("${row.retryCount}") + ckbCertPart("${row.unresolvedTransport}") + ckbCertPart(row.attemptLineageHash) + ckbCertPart("${row.retryUsed}") + ckbCertPart("${row.fallbackUsed}") +
        ckbCertPart("${row.agentRetryCount}") + ckbCertPart("${row.providerRetryCount}") + ckbCertPart("${row.sdkRetryCount}") + ckbCertPart("${row.llmTurnCount}") +
        ckbCertPart("${row.referenceExposure}") + ckbCertPart("${row.hiddenTestExposure}") + ckbCertPart("${row.teacherExposure}") +
        ckbCertPart("${row.crossCaseExposure}") + ckbCertPart("${row.sandboxDeniedOutsideWorkspace}") +
        ckbCertPart("${row.verifierMountedAfterAnswerFreeze}") + ckbCertPart("${row.certificationPassAt1}")+completionSeed
}

public func sealCkbCertificationEvidence(row: CkbCertificationCaseEvidence): Unit {
    row.resultEvidenceHash = benchmarkGapSha256(ckbCertificationEvidenceSeed(row))
}

public func renderCkbCertificationEvidenceJson(row: CkbCertificationCaseEvidence): String {
    let completion=if(row.schemaVersion=="ckb-humaneval-certification-result-v4"||row.schemaVersion=="ckb-humaneval-certification-result-v5"){",\"generationProtocol\":\"${ckbCertEscape(row.generationProtocol)}\",\"samplingCapability\":\"${ckbCertEscape(row.samplingCapability)}\",\"completionCount\":${row.completionCount},\"toolCallCount\":${row.toolCallCount},\"executionFeedbackCount\":${row.executionFeedbackCount},\"answerFreezeSequence\":${row.answerFreezeSequence},\"firstExecutionSequence\":${row.firstExecutionSequence},\"baseAnswerHash\":\"${row.baseAnswerHash}\",\"plusAnswerHash\":\"${row.plusAnswerHash}\",\"basePassed\":${row.basePassed},\"plusPassed\":${row.plusPassed},\"skillBundleVersion\":\"${ckbCertEscape(row.skillBundleVersion)}\",\"skillBundleHash\":\"${row.skillBundleHash}\",\"assetLineage\":\"${row.assetLineage}\"${if(row.schemaVersion=="ckb-humaneval-certification-result-v5"){",\"rulesHash\":\"${row.rulesHash}\",\"rulesTreeHash\":\"${row.rulesTreeHash}\",\"rulesCount\":${row.rulesCount}"}else{""}}"}else{""}
    "{\"schemaVersion\":\"${ckbCertEscape(row.schemaVersion)}\",\"runId\":\"${ckbCertEscape(row.runId)}\",\"caseId\":\"${ckbCertEscape(row.caseId)}\",\"group\":\"${ckbCertEscape(row.group)}\",\"datasetVersion\":\"${ckbCertEscape(row.datasetVersion)}\",\"knowledgeVersion\":\"${ckbCertEscape(row.knowledgeVersion)}\",\"modelFingerprint\":\"${ckbCertEscape(row.modelFingerprint)}\",\"expectedModelVersion\":\"${ckbCertEscape(row.expectedModelVersion)}\",\"observedModelVersion\":\"${ckbCertEscape(row.observedModelVersion)}\",\"claudeCodeVersion\":\"${ckbCertEscape(row.claudeCodeVersion)}\",\"providerIdentityHash\":\"${ckbCertEscape(row.providerIdentityHash)}\",\"preflightHash\":\"${ckbCertEscape(row.preflightHash)}\",\"runManifestHash\":\"${ckbCertEscape(row.runManifestHash)}\",\"authorityCaseHash\":\"${ckbCertEscape(row.authorityCaseHash)}\",\"authorityTestsHash\":\"${ckbCertEscape(row.authorityTestsHash)}\",\"workspaceId\":\"${ckbCertEscape(row.workspaceId)}\",\"sessionId\":\"${ckbCertEscape(row.sessionId)}\",\"runtimeHomeId\":\"${ckbCertEscape(row.runtimeHomeId)}\",\"isolationEvidenceHash\":\"${ckbCertEscape(row.isolationEvidenceHash)}\",\"answerHash\":\"${ckbCertEscape(row.answerHash)}\",\"transcriptHash\":\"${ckbCertEscape(row.transcriptHash)}\",\"testHash\":\"${ckbCertEscape(row.testHash)}\",\"configHash\":\"${ckbCertEscape(row.configHash)}\",\"artifactHash\":\"${ckbCertEscape(row.artifactHash)}\",\"attempt\":${row.attempt},\"sampleAttemptCount\":${row.sampleAttemptCount},\"lastAuditedTransportAttempt\":${row.lastAuditedTransportAttempt},\"selectedBusinessSample\":${row.selectedBusinessSample},\"transportAttemptCount\":${row.transportAttemptCount},\"retryCount\":${row.retryCount},\"unresolvedTransport\":${row.unresolvedTransport},\"attemptLineageHash\":\"${ckbCertEscape(row.attemptLineageHash)}\",\"retryUsed\":${row.retryUsed},\"fallbackUsed\":${row.fallbackUsed},\"agentRetryCount\":${row.agentRetryCount},\"providerRetryCount\":${row.providerRetryCount},\"sdkRetryCount\":${row.sdkRetryCount},\"llmTurnCount\":${row.llmTurnCount},\"referenceExposure\":${row.referenceExposure},\"hiddenTestExposure\":${row.hiddenTestExposure},\"teacherExposure\":${row.teacherExposure},\"crossCaseExposure\":${row.crossCaseExposure},\"sandboxDeniedOutsideWorkspace\":${row.sandboxDeniedOutsideWorkspace},\"verifierMountedAfterAnswerFreeze\":${row.verifierMountedAfterAnswerFreeze},\"certificationPassAt1\":${row.certificationPassAt1}${completion},\"resultEvidenceHash\":\"${ckbCertEscape(row.resultEvidenceHash)}\"}"
}

public func parseCkbCertificationEvidence(line: String): CkbCertificationCaseEvidence {
    let row = CkbCertificationCaseEvidence()
    try {
        let o = JsonValue.fromStr(line).asObject()
        row.schemaVersion = ckbCertString(o, "schemaVersion"); row.runId = ckbCertString(o, "runId"); row.caseId = ckbCertString(o, "caseId"); row.group = ckbCertString(o, "group")
        row.datasetVersion = ckbCertString(o, "datasetVersion"); row.knowledgeVersion = ckbCertString(o, "knowledgeVersion"); row.modelFingerprint = ckbCertString(o, "modelFingerprint"); row.expectedModelVersion = ckbCertString(o, "expectedModelVersion"); row.observedModelVersion = ckbCertString(o, "observedModelVersion"); row.claudeCodeVersion = ckbCertString(o, "claudeCodeVersion"); row.providerIdentityHash = ckbCertString(o, "providerIdentityHash")
        row.preflightHash = ckbCertString(o, "preflightHash"); row.runManifestHash = ckbCertString(o, "runManifestHash"); row.authorityCaseHash=ckbCertString(o,"authorityCaseHash");row.authorityTestsHash=ckbCertString(o,"authorityTestsHash"); row.workspaceId = ckbCertString(o, "workspaceId"); row.sessionId = ckbCertString(o, "sessionId"); row.runtimeHomeId = ckbCertString(o, "runtimeHomeId")
        row.isolationEvidenceHash = ckbCertString(o, "isolationEvidenceHash"); row.answerHash = ckbCertString(o, "answerHash"); row.transcriptHash = ckbCertString(o, "transcriptHash"); row.testHash = ckbCertString(o, "testHash"); row.configHash = ckbCertString(o, "configHash"); row.artifactHash = ckbCertString(o, "artifactHash")
        row.attempt = ckbCertInt(o, "attempt"); row.sampleAttemptCount=ckbCertInt(o,"sampleAttemptCount");row.lastAuditedTransportAttempt=ckbCertInt(o,"lastAuditedTransportAttempt");row.selectedBusinessSample=ckbCertInt(o,"selectedBusinessSample"); row.transportAttemptCount=ckbCertInt(o,"transportAttemptCount");row.retryCount=ckbCertInt(o,"retryCount");row.unresolvedTransport=ckbCertInt(o,"unresolvedTransport");row.attemptLineageHash=ckbCertString(o,"attemptLineageHash"); row.retryUsed = ckbCertBool(o, "retryUsed"); row.fallbackUsed = ckbCertBool(o, "fallbackUsed"); row.agentRetryCount = ckbCertInt(o, "agentRetryCount"); row.providerRetryCount = ckbCertInt(o, "providerRetryCount"); row.sdkRetryCount = ckbCertInt(o, "sdkRetryCount");row.llmTurnCount=ckbCertInt(o,"llmTurnCount")
        row.referenceExposure = ckbCertInt(o, "referenceExposure"); row.hiddenTestExposure = ckbCertInt(o, "hiddenTestExposure"); row.teacherExposure = ckbCertInt(o, "teacherExposure"); row.crossCaseExposure = ckbCertInt(o, "crossCaseExposure")
        row.sandboxDeniedOutsideWorkspace = ckbCertBool(o, "sandboxDeniedOutsideWorkspace"); row.verifierMountedAfterAnswerFreeze = ckbCertBool(o, "verifierMountedAfterAnswerFreeze"); row.certificationPassAt1 = ckbCertBool(o, "certificationPassAt1"); row.resultEvidenceHash = ckbCertString(o, "resultEvidenceHash")
        if(row.schemaVersion=="ckb-humaneval-certification-result-v4"||row.schemaVersion=="ckb-humaneval-certification-result-v5"){
            row.generationProtocol=ckbCertString(o,"generationProtocol");row.samplingCapability=ckbCertString(o,"samplingCapability")
            row.completionCount=ckbCertInt(o,"completionCount");row.toolCallCount=ckbCertInt(o,"toolCallCount");row.executionFeedbackCount=ckbCertInt(o,"executionFeedbackCount")
            row.answerFreezeSequence=ckbCertInt(o,"answerFreezeSequence");row.firstExecutionSequence=ckbCertInt(o,"firstExecutionSequence")
            row.baseAnswerHash=ckbCertString(o,"baseAnswerHash");row.plusAnswerHash=ckbCertString(o,"plusAnswerHash")
            row.basePassed=ckbCertBool(o,"basePassed");row.plusPassed=ckbCertBool(o,"plusPassed")
            row.skillBundleVersion=ckbCertString(o,"skillBundleVersion");row.skillBundleHash=ckbCertString(o,"skillBundleHash");row.assetLineage=ckbCertString(o,"assetLineage")
            if(row.schemaVersion=="ckb-humaneval-certification-result-v5"){row.rulesHash=ckbCertString(o,"rulesHash");row.rulesTreeHash=ckbCertString(o,"rulesTreeHash");row.rulesCount=ckbCertInt(o,"rulesCount")}
        }
    } catch (_: Exception) { row.diagnostic = "malformed_json"; return row }
    row.diagnostic = ckbCertificationEvidenceDiagnostic(row)
    if(row.diagnostic=="ok"&&(row.schemaVersion=="ckb-humaneval-certification-result-v4"||row.schemaVersion=="ckb-humaneval-certification-result-v5")&&line!=renderCkbCertificationEvidenceJson(row)){
        row.diagnostic="non_canonical_completion_evidence"
    }
    row.valid = row.diagnostic == "ok"
    row
}

public func ckbCertificationEvidenceDiagnostic(row: CkbCertificationCaseEvidence): String {
    if (row.schemaVersion != "ckb-humaneval-certification-result-v3" && row.schemaVersion != "ckb-humaneval-certification-result-v4" && row.schemaVersion != "ckb-humaneval-certification-result-v5") { return "unknown_schema" }
    if (row.runId == "" || row.caseId == "" || row.group == "" || row.datasetVersion == "" || row.knowledgeVersion == "" || row.modelFingerprint == "") { return "identity_field_required" }
    if (row.expectedModelVersion == "" || row.claudeCodeVersion == "") { return "observed_model_identity_mismatch" }
    if (row.group != CkbAbcdeGroups.D) { return "certification_requires_isolated_http_transport" }
    for (hash in [row.providerIdentityHash,row.preflightHash,row.runManifestHash,row.authorityCaseHash,row.authorityTestsHash,row.isolationEvidenceHash,row.answerHash,row.transcriptHash,row.testHash,row.configHash,row.artifactHash]) { if (!ckbCertHash(hash)) { return "artifact_hash_invalid" } }
    if (row.attempt != 1 || row.retryUsed || row.agentRetryCount != 0) { return "business_retry_forbidden" }
    if (row.fallbackUsed || row.providerRetryCount != 0 || row.sdkRetryCount != 0) { return "provider_sdk_retry_or_fallback_forbidden" }
    if(row.transportAttemptCount<1||row.retryCount!=row.transportAttemptCount-1||!ckbCertHash(row.attemptLineageHash)){return "transport_lineage_invalid"}
    if(row.sampleAttemptCount<0||row.sampleAttemptCount>1){return "sample_attempt_count_invalid"}
    if(row.lastAuditedTransportAttempt!=row.transportAttemptCount||row.selectedBusinessSample!=if(row.sampleAttemptCount==1){row.transportAttemptCount}else{0}){return "transport_selection_invalid"}
    let expectedUnresolved=if(row.sampleAttemptCount==0){1}else{0};if(row.unresolvedTransport!=expectedUnresolved){return "unresolved_transport_sample_mismatch"}
    if(row.unresolvedTransport==1&&row.certificationPassAt1){return "unresolved_transport_cannot_pass"}
    if(row.sampleAttemptCount==1&&row.observedModelVersion!=row.expectedModelVersion){return "observed_model_identity_mismatch"}
    if(row.sampleAttemptCount==1&&row.llmTurnCount<=0){return "llm_turn_count_required"}
    if (row.referenceExposure != 0 || row.hiddenTestExposure != 0 || row.teacherExposure != 0 || row.crossCaseExposure != 0) { return "model_exposure_forbidden" }
    if (!row.sandboxDeniedOutsideWorkspace) { return "auditable_sandbox_deny_required" }
    if (!row.verifierMountedAfterAnswerFreeze) { return "verifier_mount_order_invalid" }
    if(row.schemaVersion=="ckb-humaneval-certification-result-v4"||row.schemaVersion=="ckb-humaneval-certification-result-v5"){
        if(row.generationProtocol!="completion-only-v1"){return "completion_protocol_required"}
        if(row.samplingCapability!="temperature_zero"&&row.samplingCapability!="provider_default_not_client_exposed"){return "sampling_capability_invalid"}
        if(row.completionCount!=1){return "completion_not_unique"}
        if(row.toolCallCount!=0){return "completion_tool_use_forbidden"}
        if(row.executionFeedbackCount!=0){return "execution_feedback_forbidden"}
        if(row.answerFreezeSequence<=0||row.firstExecutionSequence<=row.answerFreezeSequence){return "execution_before_answer_freeze"}
        if(!ckbCertHash(row.baseAnswerHash)||row.baseAnswerHash!=row.answerHash||row.plusAnswerHash!=row.answerHash){return "base_plus_answer_mismatch"}
        if(row.skillBundleVersion==""||!ckbCertHash(row.skillBundleHash)){return "skill_bundle_identity_invalid"}
        if(row.assetLineage!="independent"&&row.assetLineage!="humaneval_164_derived"){return "asset_lineage_invalid"}
        if(row.schemaVersion=="ckb-humaneval-certification-result-v5"&&ckbS4RulesIdentityDiagnostic(row.rulesHash,row.rulesTreeHash,row.rulesCount)!="ok"){return "rules_identity_invalid"}
        if(row.certificationPassAt1!=(row.basePassed&&row.plusPassed)){return "base_plus_certification_mismatch"}
    }
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
    var runId = ""; var preflightHash = ""; var runManifestHash = ""; var providerHash = "";var protocol="";var bundleHash="";var lineage=""
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
        if (runId == "") { runId=row.runId; gate.group=row.group; gate.datasetVersion=row.datasetVersion; gate.knowledgeVersion=row.knowledgeVersion; gate.modelFingerprint=row.modelFingerprint; preflightHash=row.preflightHash; runManifestHash=row.runManifestHash; providerHash=row.providerIdentityHash;protocol=row.generationProtocol;bundleHash=row.skillBundleHash;lineage=row.assetLineage }
        if (row.runId!=runId || row.group!=gate.group || row.datasetVersion!=gate.datasetVersion || row.knowledgeVersion!=gate.knowledgeVersion || row.modelFingerprint!=gate.modelFingerprint || row.preflightHash!=preflightHash || row.runManifestHash!=runManifestHash || row.providerIdentityHash!=providerHash) { gate.fail("certification_lineage_drift:${row.caseId}") }
        if(row.generationProtocol!=protocol||(protocol=="completion-only-v1"&&(row.skillBundleHash!=bundleHash||row.assetLineage!=lineage))){gate.fail("completion_bundle_or_lineage_drift:${row.caseId}")}
        gate.retryUsed += if (row.retryUsed || row.agentRetryCount>0 || row.providerRetryCount>0 || row.sdkRetryCount>0) {1}else{0}; gate.fallbackUsed += if(row.fallbackUsed){1}else{0}
        gate.transportRetryCount += row.retryCount; gate.unresolvedTransport += row.unresolvedTransport
        gate.referenceExposure += row.referenceExposure; gate.hiddenTestExposure += row.hiddenTestExposure; gate.teacherExposure += row.teacherExposure; gate.crossCaseExposure += row.crossCaseExposure
        if (row.certificationPassAt1) { gate.unitPass+=1; gate.unitPassAt1+=1 } else { gate.failed+=1 }
    }
    if (gate.total != 164) { gate.fail("result_count_mismatch:${gate.total}:164") }
    for (id in expected) { if (!seenCases.contains(id)) { gate.fail("missing_case:${id}") } }
    if (gate.unitPassAt1 != 164 || gate.failed != 0 || gate.invalid != 0 || gate.retryUsed != 0 || gate.fallbackUsed != 0 || gate.unresolvedTransport != 0 || gate.referenceExposure != 0 || gate.hiddenTestExposure != 0 || gate.teacherExposure != 0 || gate.crossCaseExposure != 0) { gate.fail("strict_pass_at_1_requirements_not_met") }
    gate.ok = gate.diagnostics.size == 0
    gate
}

// Trusted certification is reconstructed from the immutable run directory.
// The text-only gate remains a parser/unit-test primitive and is not a P8 trust input.
public func ckbStrictCertificationGateFromRunRoot(runRoot: String, authorityManifestText: String): CkbStrictCertificationGateResult {
    let gate=CkbStrictCertificationGateResult();if(runRoot.trimAscii()==""){gate.fail("run_root_required");return gate};let root=Path(runRoot);let resultsPath=root.join("results.jsonl")
    let results=try{String.fromUtf8(File.readFrom(resultsPath))}catch(_:Exception){gate.fail("run_results_unreadable");return gate}
    let frozenAuthority=try{String.fromUtf8(File.readFrom(root.join("authority.jsonl")))}catch(_:Exception){gate.fail("authority_snapshot_unreadable");return gate}
    if(frozenAuthority!=authorityManifestText){gate.fail("authority_snapshot_hash_mismatch");return gate}
    let parsed=ckbStrictCertificationGate(results,authorityManifestText)
    let scoreThresholdOnly=!parsed.ok&&parsed.diagnostics.size==1&&
        parsed.diagnostics[0]=="strict_pass_at_1_requirements_not_met"
    if(!parsed.ok&&!scoreThresholdOnly){return parsed}
    let authority=parseCangjieHumanEvalAuthorityManifest(authorityManifestText)
    let frozen=try{String.fromUtf8(File.readFrom(root.join("frozen-candidate-manifest.json")))}catch(_:Exception){gate.fail("frozen_candidate_manifest_unreadable");return gate}
    let provider=try{String.fromUtf8(File.readFrom(root.join("provider-identity.json")))}catch(_:Exception){gate.fail("provider_identity_unreadable");return gate}
    let preflight=try{String.fromUtf8(File.readFrom(root.join("preflight.json")))}catch(_:Exception){gate.fail("preflight_unreadable");return gate}
    let owner=try{String.fromUtf8(File.readFrom(root.join("certification-http-owner.json")))}catch(_:Exception){gate.fail("http_owner_unreadable");return gate}
    let identity=try{String.fromUtf8(File.readFrom(root.join("certification-http-identity.json")))}catch(_:Exception){gate.fail("http_identity_unreadable");return gate}
    let stopped=try{String.fromUtf8(File.readFrom(root.join("certification-http-stopped.json")))}catch(_:Exception){gate.fail("http_stop_unreadable");return gate}
    let runManifest=try{String.fromUtf8(File.readFrom(root.join("run-manifest.json")))}catch(_:Exception){gate.fail("run_manifest_unreadable");return gate}
    let provenance=try{String.fromUtf8(File.readFrom(root.join("runner-provenance.json")))}catch(_:Exception){gate.fail("runner_provenance_unreadable");return gate}
    var frozenHash="";var providerHash="";var declaredModel="";var declaredFingerprint="";var declaredPreflight="";var declaredRunHash="";var declaredTimeout:Int64=-1;var declaredClaude="";var declaredRunId="";var declaredBinary="";var declaredLaunch="";var declaredCommand="";var declaredProtocol="historical-agentic-v1";var declaredBundle="";var declaredBundleVersion="";var declaredLineage="";var declaredSampling="historical"
    try{let manifest=JsonValue.fromStr(runManifest).asObject();frozenHash=ckbCertString(manifest,"frozenCandidateManifestHash");providerHash=ckbCertString(manifest,"providerIdentityHash");declaredModel=ckbCertString(manifest,"modelVersion");declaredFingerprint=ckbCertString(manifest,"fingerprint");declaredPreflight=ckbCertString(manifest,"preflightHash");declaredRunHash=ckbCertString(manifest,"runManifestHash");declaredTimeout=ckbCertInt(manifest,"modelTimeoutSeconds");declaredClaude=ckbCertString(manifest,"claudeCodeVersion");declaredRunId=ckbCertString(manifest,"runId");declaredBinary=ckbCertString(manifest,"certificationBinaryHash");declaredLaunch=ckbCertString(manifest,"certificationHttpLaunchSpecHash");declaredCommand=ckbCertString(manifest,"certificationHttpCommandHash");match(manifest.get("generationProtocol")){case Some(value)=>declaredProtocol=value.asString().getValue();if(declaredProtocol!="completion-only-v1"){gate.fail("run_manifest_generation_protocol_invalid");return gate};declaredBundle=ckbCertString(manifest,"skillBundleHash");declaredBundleVersion=ckbCertString(manifest,"skillBundleVersion");declaredLineage=ckbCertString(manifest,"assetLineage");declaredSampling=ckbCertString(manifest,"samplingCapability") case None=>()}}catch(_:Exception){gate.fail("run_manifest_malformed");return gate}
    var providerModel="";var providerClaude="";try{let object=JsonValue.fromStr(provider).asObject();providerModel=ckbCertString(object,"model");providerClaude=ckbCertString(object,"claudeCodeVersion")}catch(_:Exception){gate.fail("provider_identity_malformed");return gate}
    var ownerPid:Int64=-1;var stopPid:Int64=-2;var alive=true;var ownerBinary="";var ownerLaunch="";var ownerCommand="";try{let own=JsonValue.fromStr(owner).asObject();if(own.getFields().size!=5||!ckbCertUniqueFields(owner,["schemaVersion","pid","binaryHash","launchSpecHash","commandHash"])||ckbCertString(own,"schemaVersion")!="ckb-certification-http-owner-v1"||!ckbCertHash(ckbCertString(own,"binaryHash"))||!ckbCertHash(ckbCertString(own,"launchSpecHash"))||!ckbCertHash(ckbCertString(own,"commandHash"))){gate.fail("http_owner_invalid")};ownerPid=ckbCertInt(own,"pid");ownerBinary=ckbCertString(own,"binaryHash");ownerLaunch=ckbCertString(own,"launchSpecHash");ownerCommand=ckbCertString(own,"commandHash");let stop=JsonValue.fromStr(stopped).asObject();if(stop.getFields().size!=4||!ckbCertUniqueFields(stopped,["schemaVersion","pid","stopMethod","aliveAfterStop"])||ckbCertString(stop,"schemaVersion")!="ckb-certification-http-stop-v1"){gate.fail("http_stop_invalid")};stopPid=ckbCertInt(stop,"pid");alive=ckbCertBool(stop,"aliveAfterStop");let method=ckbCertString(stop,"stopMethod");if(method!="term"&&method!="kill"){gate.fail("http_stop_method_invalid")}}catch(_:Exception){gate.fail("http_lifecycle_malformed")}
    var provenanceOk=false;try{let p=JsonValue.fromStr(provenance).asObject();provenanceOk=p.getFields().size==10&&ckbCertUniqueFields(provenance,["schemaVersion","runId","canonicalRunRootHash","runManifestHash","runnerBinaryHash","launchSpecHash","commandHash","authorityHash","caseCount","resultManifestHash"])&&ckbCertString(p,"schemaVersion")=="ckb-certification-runner-provenance-v1"&&ckbCertString(p,"runId")==declaredRunId&&ckbCertString(p,"canonicalRunRootHash")==benchmarkGapSha256(canonicalize(root).toString())&&ckbCertString(p,"runManifestHash")==declaredRunHash&&ckbCertString(p,"runnerBinaryHash")==declaredBinary&&ckbCertString(p,"launchSpecHash")==declaredLaunch&&ckbCertString(p,"commandHash")==declaredCommand&&ckbCertString(p,"authorityHash")==benchmarkGapSha256(authorityManifestText)&&ckbCertInt(p,"caseCount")==164&&ckbCertString(p,"resultManifestHash")==benchmarkGapSha256(results)}catch(_:Exception){}
    if(frozenHash!=benchmarkGapSha256(frozen)||providerHash!=benchmarkGapSha256(provider)||declaredPreflight!=benchmarkGapSha256(preflight)||declaredModel!=providerModel||declaredClaude!=providerClaude||declaredTimeout<=0||declaredFingerprint!=parsed.modelFingerprint||!ckbCertHash(declaredBinary)||!ckbCertHash(declaredLaunch)||!ckbCertHash(declaredCommand)||ownerBinary!=declaredBinary||ownerLaunch!=declaredLaunch||ownerCommand!=declaredCommand||!provenanceOk||ownerPid<=0||ownerPid!=stopPid||alive){gate.fail("run_manifest_artifact_binding_mismatch");return gate}
    try{let frozenObject=JsonValue.fromStr(frozen).asObject();let envelope=JsonValue.fromStr(identity).asObject();if(envelope.getFields().size!=4||!ckbCertUniqueFields(identity,["ok","apiVersion","data","diagnostics","schemaVersion","activeVersion","pointerIdentityHash","candidateChecksum"])||!ckbCertBool(envelope,"ok")){gate.fail("http_identity_binding_mismatch");return gate};let data=envelope.get("data").getOrThrow().asObject();if(data.getFields().size!=4||ckbCertString(data,"schemaVersion")!="ckb-certification-identity-v1"||ckbCertString(data,"activeVersion")!=ckbCertString(frozenObject,"knowledgeVersion")||ckbCertString(data,"pointerIdentityHash")!=ckbCertString(frozenObject,"activePointerHash")||ckbCertString(data,"candidateChecksum")!=ckbCertString(frozenObject,"candidateChecksum")){gate.fail("http_identity_binding_mismatch");return gate}}catch(_:Exception){gate.fail("http_identity_binding_mismatch");return gate}
    var seed="${benchmarkGapSha256(preflight)}|${benchmarkGapSha256(runManifest)}|${frozenHash}|${providerHash}|${benchmarkGapSha256(owner)}|${benchmarkGapSha256(identity)}|${benchmarkGapSha256(stopped)}|${benchmarkGapSha256(provenance)}|${declaredModel}|${declaredFingerprint}|${benchmarkGapSha256(authorityManifestText)}|"
    for(line in results.split("\n")){if(line.trimAscii()==""){continue};let row=parseCkbCertificationEvidence(line);let groupRoot=root.join("cases").join(row.caseId).join(row.group);let evidencePath=groupRoot.join("result-evidence.json")
        if((declaredProtocol=="completion-only-v1"&&(row.schemaVersion!="ckb-humaneval-certification-result-v4"||row.generationProtocol!="completion-only-v1"))||(declaredProtocol=="historical-agentic-v1"&&(row.schemaVersion!="ckb-humaneval-certification-result-v3"||row.generationProtocol!="historical-agentic-v1"))){gate.fail("case_run_protocol_mismatch:${row.caseId}");continue}
        let persisted=try{String.fromUtf8(File.readFrom(evidencePath))}catch(_:Exception){gate.fail("case_evidence_unreadable:${row.caseId}");continue}
        if(persisted.trimAscii()!=line.trimAscii()){gate.fail("case_evidence_mismatch:${row.caseId}");continue}
        if(row.preflightHash!=benchmarkGapSha256(preflight)||row.runManifestHash!=declaredRunHash||row.providerIdentityHash!=providerHash||row.expectedModelVersion!=providerModel||row.claudeCodeVersion!=providerClaude){gate.fail("case_p6_provider_binding_mismatch:${row.caseId}");continue}
        let transcript=try{String.fromUtf8(File.readFrom(groupRoot.join("claude-transcript.jsonl")))}catch(_:Exception){gate.fail("case_transcript_unreadable:${row.caseId}");continue};let testLog=try{String.fromUtf8(File.readFrom(groupRoot.join("test.log")))}catch(_:Exception){gate.fail("case_test_log_unreadable:${row.caseId}");continue};let probe=try{String.fromUtf8(File.readFrom(groupRoot.join("sandbox-probe.json")))}catch(_:Exception){gate.fail("case_probe_unreadable:${row.caseId}");continue};let mcp=try{String.fromUtf8(File.readFrom(groupRoot.join("mcp-config.json")))}catch(_:Exception){gate.fail("case_config_unreadable:${row.caseId}");continue};let policy=try{String.fromUtf8(File.readFrom(groupRoot.join("runtime-policy.json")))}catch(_:Exception){gate.fail("case_policy_unreadable:${row.caseId}");continue};let paired=try{String.fromUtf8(File.readFrom(groupRoot.join("paired-tool-evidence.json")))}catch(_:Exception){gate.fail("case_tool_evidence_unreadable:${row.caseId}");continue};let verifier=try{String.fromUtf8(File.readFrom(groupRoot.join("verifier-mount.json")))}catch(_:Exception){gate.fail("case_verifier_evidence_unreadable:${row.caseId}");continue}
        var completionSeed=""
        if(declaredProtocol=="completion-only-v1"){
            let d=ckbCertCompletionRunArtifactsDiagnostic(groupRoot,row,transcript,declaredBundleVersion,declaredBundle,declaredLineage,declaredSampling);if(d!="ok"){gate.fail("case_completion_artifact_invalid:${row.caseId}:${d}");continue}
            try{
                let frozenCompletion=String.fromUtf8(File.readFrom(groupRoot.join("frozen-completion/solution.cj")))
                let generation=String.fromUtf8(File.readFrom(groupRoot.join("generation-evidence.json")))
                let answerFreeze=String.fromUtf8(File.readFrom(groupRoot.join("answer-freeze.json")))
                let baseResult=String.fromUtf8(File.readFrom(groupRoot.join("base-test-result.json")))
                let plusResult=String.fromUtf8(File.readFrom(groupRoot.join("plus-test-result.json")))
                completionSeed="${benchmarkGapSha256(frozenCompletion)}|${benchmarkGapSha256(generation)}|${benchmarkGapSha256(answerFreeze)}|${benchmarkGapSha256(baseResult)}|${benchmarkGapSha256(plusResult)}|"
            }catch(_:Exception){gate.fail("case_completion_artifact_unreadable:${row.caseId}");continue}
        }
        let attemptDiagnostic=ckbAbcdeAttemptArtifactsDiagnostic(groupRoot.toString());if(attemptDiagnostic!="ok"){gate.fail("case_attempt_artifact_invalid:${row.caseId}:${attemptDiagnostic}");continue}
        let solution=try{String.fromUtf8(File.readFrom(groupRoot.join("workspace/src/solution.cj")))}catch(_:Exception){gate.fail("case_solution_unreadable:${row.caseId}");continue};let testResult=try{String.fromUtf8(File.readFrom(groupRoot.join("test-result.json")))}catch(_:Exception){gate.fail("case_test_result_unreadable:${row.caseId}");continue};let context=try{String.fromUtf8(File.readFrom(groupRoot.join("canonical-task-context.json")))}catch(_:Exception){gate.fail("case_context_unreadable:${row.caseId}");continue};let attemptSummary=try{String.fromUtf8(File.readFrom(groupRoot.join("attempt-evidence.json")))}catch(_:Exception){gate.fail("case_attempt_summary_unreadable:${row.caseId}");continue};let attempts=try{String.fromUtf8(File.readFrom(groupRoot.join("claude-attempts.jsonl")))}catch(_:Exception){gate.fail("case_attempts_unreadable:${row.caseId}");continue};let restores=try{String.fromUtf8(File.readFrom(groupRoot.join("workspace-restores.jsonl")))}catch(_:Exception){gate.fail("case_restores_unreadable:${row.caseId}");continue}
        var verifierOk=false;var unitPass=false;var policyTimeout:Int64=-1;try{let v=JsonValue.fromStr(verifier).asObject();verifierOk=v.getFields().size==4&&ckbCertInt(v,"injectExitCode")==0&&ckbCertString(v,"answerHashBefore")==row.answerHash&&ckbCertString(v,"answerHashAfter")==row.answerHash&&ckbCertBool(v,"mountedAfterFreeze");let tr=JsonValue.fromStr(testResult).asObject();unitPass=tr.getFields().size==15&&ckbCertInt(tr,"testExitCode")==0&&ckbCertBool(tr,"unitPassAt1")&&ckbCertString(tr,"failureType")=="none"&&ckbCertString(tr,"testLogPath")==groupRoot.join("test.log").toString();policyTimeout=ckbCertInt(JsonValue.fromStr(policy).asObject(),"modelTimeoutSeconds")}catch(_:Exception){}
        let evidenceAttempt=if(row.selectedBusinessSample>0){row.selectedBusinessSample}else{row.lastAuditedTransportAttempt};let workspace=groupRoot.join("workspace").toString();let home=groupRoot.join("runtime-home").join("attempt-${evidenceAttempt}").toString();var probeOk=false;try{let p=JsonValue.fromStr(probe).asObject();probeOk=ckbCertBool(p,"ok")&&ckbCertBool(p,"deniedOutsideWorkspace")&&ckbCertBool(p,"deniedTests")&&ckbCertBool(p,"deniedReference")&&ckbCertBool(p,"deniedTeacher")&&ckbCertBool(p,"deniedStore")&&ckbCertString(p,"workspaceCanonical")==canonicalize(Path(workspace)).toString()&&ckbCertString(p,"runtimeHomeCanonical")==canonicalize(Path(home)).toString()}catch(_:Exception){}
        let knowledge=ckbAbcdeTaskKnowledgeEvidenceForAudit(row.group,transcript,context);var pairedOk=false;try{let p=JsonValue.fromStr(paired).asObject();pairedOk=knowledge.valid&&knowledge.coveragePass&&knowledge.citationCount>0&&knowledge.knowledgeVersion==row.knowledgeVersion&&ckbCertBool(p,"valid")&&ckbCertString(p,"evidenceHash")==knowledge.evidenceHash&&ckbCertString(p,"knowledgeVersion")==knowledge.knowledgeVersion&&ckbCertString(p,"requestBindingHash")==knowledge.requestBindingHash&&ckbCertBool(p,"coveragePass")&&ckbCertInt(p,"citationCount")==knowledge.citationCount}catch(_:Exception){}
        let lower=transcript.toAsciiLower();let reference=if(lower.contains("/reference")){1}else{0};let hidden=if(lower.contains("/tests/")||lower.contains("testmain.cj")){1}else{0};let teacher=if(lower.contains("cangjieteacher")||lower.contains("teacher-solutions")){1}else{0};var cross:Int64=0;for(i in 0..164){let id=ckbCertCaseId(i);if(id!=row.caseId&&transcript.contains(id)){cross=1}};let parsedTurns=ckbAbcdeParseClaudeUsageFromText(transcript,"audit").llmTurnCount;let completionMode=declaredProtocol=="completion-only-v1";let turns=if(completionMode){1}else{parsedTurns}
        let semanticPass=benchmarkGapSha256(solution)==row.answerHash&&verifierOk&&(if(completionMode){row.basePassed&&row.plusPassed}else{unitPass})&&probeOk&&(completionMode||pairedOk)&&policyTimeout==declaredTimeout&&row.observedModelVersion==row.expectedModelVersion&&row.sampleAttemptCount==1&&row.unresolvedTransport==0&&reference==0&&hidden==0&&teacher==0&&cross==0&&turns>0
        if(row.transcriptHash!=benchmarkGapSha256(transcript)||row.testHash!=benchmarkGapSha256(testLog)||row.isolationEvidenceHash!=benchmarkGapSha256(probe)||row.configHash!=benchmarkGapSha256(mcp+policy+provider+paired)||row.answerHash!=benchmarkGapSha256(solution)||row.verifierMountedAfterAnswerFreeze!=verifierOk||row.sandboxDeniedOutsideWorkspace!=probeOk||row.referenceExposure!=reference||row.hiddenTestExposure!=hidden||row.teacherExposure!=teacher||row.crossCaseExposure!=cross||row.llmTurnCount!=turns||row.certificationPassAt1!=semanticPass){gate.fail("case_semantic_artifact_mismatch:${row.caseId}");continue}
        try{let summary=JsonValue.fromStr(attemptSummary).asObject();if(summary.getFields().size!=11||row.attemptLineageHash!=ckbCertString(summary,"attemptLineageHash")||row.transportAttemptCount!=ckbCertInt(summary,"transportAttemptCount")||row.sampleAttemptCount!=ckbCertInt(summary,"sampleAttemptCount")||row.lastAuditedTransportAttempt!=ckbCertInt(summary,"lastAuditedTransportAttempt")||row.selectedBusinessSample!=ckbCertInt(summary,"selectedBusinessSample")||row.unresolvedTransport!=ckbCertInt(summary,"unresolvedTransport")||ckbCertString(summary,"attemptsPath")!="claude-attempts.jsonl"||ckbCertString(summary,"restoresPath")!="workspace-restores.jsonl"){gate.fail("case_attempt_summary_mismatch:${row.caseId}");continue}}catch(_:Exception){gate.fail("case_attempt_summary_malformed:${row.caseId}");continue}
        if(row.artifactHash!=benchmarkGapSha256(row.answerHash+row.transcriptHash+row.testHash+row.configHash)){gate.fail("case_artifact_hash_mismatch:${row.caseId}");continue}
        seed+="${row.caseId}|${row.resultEvidenceHash}|${row.attemptLineageHash}|${row.configHash}|${benchmarkGapSha256(solution)}|${benchmarkGapSha256(context)}|${benchmarkGapSha256(transcript)}|${benchmarkGapSha256(testLog)}|${benchmarkGapSha256(probe)}|${benchmarkGapSha256(mcp)}|${benchmarkGapSha256(policy)}|${benchmarkGapSha256(paired)}|${benchmarkGapSha256(verifier)}|${benchmarkGapSha256(testResult)}|${benchmarkGapSha256(attemptSummary)}|${benchmarkGapSha256(attempts)}|${benchmarkGapSha256(restores)}|${completionSeed}"
    }
    if(gate.diagnostics.size>0){gate.total=parsed.total;gate.unitPass=parsed.unitPass;gate.unitPassAt1=parsed.unitPassAt1;gate.failed=parsed.failed;gate.invalid=parsed.invalid;return gate}
    parsed.artifactManifestHash=benchmarkGapSha256(seed);parsed
}

public func renderCkbStrictCertificationGateJson(g: CkbStrictCertificationGateResult): String {
    var ds=""; for(i in 0..g.diagnostics.size){if(i>0){ds+=","};ds+="\"${ckbCertEscape(g.diagnostics[i])}\""}
    "{\"schemaVersion\":\"ckb-humaneval-certification-gate-v2\",\"ok\":${g.ok},\"total\":${g.total},\"unitPass\":${g.unitPass},\"unitPassAt1\":${g.unitPassAt1},\"failed\":${g.failed},\"invalid\":${g.invalid},\"businessRetryUsed\":${g.retryUsed},\"transportRetryCount\":${g.transportRetryCount},\"unresolvedTransport\":${g.unresolvedTransport},\"fallbackUsed\":${g.fallbackUsed},\"referenceExposure\":${g.referenceExposure},\"hiddenTestExposure\":${g.hiddenTestExposure},\"teacherExposure\":${g.teacherExposure},\"crossCaseExposure\":${g.crossCaseExposure},\"group\":\"${ckbCertEscape(g.group)}\",\"datasetVersion\":\"${ckbCertEscape(g.datasetVersion)}\",\"knowledgeVersion\":\"${ckbCertEscape(g.knowledgeVersion)}\",\"modelFingerprint\":\"${ckbCertEscape(g.modelFingerprint)}\",\"artifactManifestHash\":\"${ckbCertEscape(g.artifactManifestHash)}\",\"diagnostics\":[${ds}]}"
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
private func ckbCertCompletionRunArtifactsDiagnostic(groupRoot:Path,row:CkbCertificationCaseEvidence,transcript:String,bundleVersion:String,bundleHash:String,lineage:String,sampling:String):String{
    if(row.schemaVersion!="ckb-humaneval-certification-result-v4"||row.generationProtocol!="completion-only-v1"){return "strict_completion_schema_required"}
    if(row.skillBundleVersion!=bundleVersion||row.skillBundleHash!=bundleHash||row.assetLineage!=lineage||row.samplingCapability!=sampling){return "run_manifest_completion_binding_mismatch"}
    if(transcript.contains("\"type\":\"tool_use\"")){return "completion_tool_use_forbidden"}
    if(transcript.split("\"structured_output\"").size!=2){return "completion_not_unique"}
    if(transcript.contains("\"type\":\"tool_result\"")||transcript.contains("\"execution_feedback\"")){return "execution_feedback_forbidden"}
    let parsed=ckbAbcdeExtractSingleCompletion(transcript.toArray());if(!parsed.ok){return parsed.diagnostic}
    if(parsed.completionCount!=1||parsed.toolCallCount!=0||parsed.answerHash!=row.answerHash){return "completion_transcript_mismatch"}
    let frozen=try{String.fromUtf8(File.readFrom(groupRoot.join("frozen-completion/solution.cj")))}catch(_:Exception){return "frozen_completion_unreadable"}
    if(benchmarkGapSha256(frozen)!=row.answerHash){return "frozen_completion_hash_mismatch"}
    let generation=try{String.fromUtf8(File.readFrom(groupRoot.join("generation-evidence.json")))}catch(_:Exception){return "generation_evidence_unreadable"}
    let freeze=try{String.fromUtf8(File.readFrom(groupRoot.join("answer-freeze.json")))}catch(_:Exception){return "answer_freeze_unreadable"}
    let base=try{String.fromUtf8(File.readFrom(groupRoot.join("base-test-result.json")))}catch(_:Exception){return "base_result_unreadable"}
    let plus=try{String.fromUtf8(File.readFrom(groupRoot.join("plus-test-result.json")))}catch(_:Exception){return "plus_result_unreadable"}
    try{
        let g=JsonValue.fromStr(generation).asObject();let f=JsonValue.fromStr(freeze).asObject();let b=JsonValue.fromStr(base).asObject();let p=JsonValue.fromStr(plus).asObject()
        if(ckbCertInt(g,"completionCount")!=1||ckbCertInt(g,"toolCallCount")!=0||ckbCertInt(g,"executionFeedbackCount")!=0){return "completion_count_or_feedback_invalid"}
        let interrupted=ckbCertBool(g,"interrupted");let generatedTokens=ckbCertInt(g,"generatedTokenCount");let recovered=ckbCertBool(g,"checkpointRecovered");if(interrupted&&generatedTokens==0&&!recovered){return "zero_token_recovery_evidence_required"};if(recovered&&(!interrupted||generatedTokens!=0)){return "checkpoint_recovery_evidence_invalid"}
        if(ckbCertString(g,"answerHash")!=row.answerHash||ckbCertString(f,"answerHash")!=row.answerHash){return "completion_answer_binding_mismatch"}
        let freezeSequence=ckbCertInt(f,"sequence");let baseSequence=ckbCertInt(b,"sequence");let plusSequence=ckbCertInt(p,"sequence")
        if(freezeSequence<=0||baseSequence<=freezeSequence||plusSequence<=freezeSequence){return "execution_before_answer_freeze"}
        if(ckbCertString(b,"answerHash")!=row.answerHash||ckbCertString(p,"answerHash")!=row.answerHash){return "base_plus_answer_mismatch"}
        if(ckbCertBool(b,"passed")!=row.basePassed||ckbCertBool(p,"passed")!=row.plusPassed){return "base_plus_status_mismatch"}
        if(row.completionCount!=1||row.toolCallCount!=0||row.executionFeedbackCount!=0||row.answerFreezeSequence!=freezeSequence||row.firstExecutionSequence!=if(baseSequence<plusSequence){baseSequence}else{plusSequence}){return "completion_evidence_recompute_mismatch"}
    }catch(_:Exception){return "completion_artifact_malformed"}
    "ok"
}
public func ckbStrictCompletionCaseFromRunRootDiagnostic(runRoot:String,row:CkbCertificationCaseEvidence):String{
    if(row.schemaVersion!="ckb-humaneval-certification-result-v4"){return "historical_agentic_not_strict"}
    let root=Path(runRoot);let groupRoot=root.join("cases").join(row.caseId).join(row.group)
    let transcript=try{String.fromUtf8(File.readFrom(groupRoot.join("claude-transcript.jsonl")))}catch(_:Exception){return "case_transcript_unreadable"}
    let manifest=try{String.fromUtf8(File.readFrom(root.join("run-manifest.json")))}catch(_:Exception){return "run_manifest_unreadable"}
    try{let o=JsonValue.fromStr(manifest).asObject();if(ckbCertString(o,"generationProtocol")!="completion-only-v1"){return "completion_protocol_required"};ckbCertCompletionRunArtifactsDiagnostic(groupRoot,row,transcript,ckbCertString(o,"skillBundleVersion"),ckbCertString(o,"skillBundleHash"),ckbCertString(o,"assetLineage"),ckbCertString(o,"samplingCapability"))}catch(_:Exception){"run_manifest_malformed"}
}
private func ckbCertString(o:JsonObject,k:String):String{match(o.get(k)){case Some(v)=>v.asString().getValue();case None=>throw Exception("missing")}}
private func ckbCertInt(o:JsonObject,k:String):Int64{match(o.get(k)){case Some(v)=>v.asInt().getValue();case None=>throw Exception("missing")}}
private func ckbCertBool(o:JsonObject,k:String):Bool{match(o.get(k)){case Some(v)=>v.asBool().getValue();case None=>throw Exception("missing")}}
private func ckbCertUniqueFields(raw:String,keys:Array<String>):Bool{for(key in keys){if(raw.split("\"${key}\"").size!=2){return false}};true}
private func ckbCertHash(v:String):Bool{if(v.toRuneArray().size!=71||!v.startsWith("sha256:")){return false};for(c in v.toRuneArray()[7..71]){if(!((c>=r'0'&&c<=r'9')||(c>=r'a'&&c<=r'f'))){return false}};true}
private func ckbCertCaseId(i:Int64):String{if(i<10){"CJ-HUMANEVAL-00${i}"}else if(i<100){"CJ-HUMANEVAL-0${i}"}else{"CJ-HUMANEVAL-${i}"}}
