package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.convert.Parsable
import std.fs.{Directory, File, Path, exists}
import stdx.encoding.json.*

public class CangjieHumanEvalPass1GateGroups {
    public static let C: String = "C-ckb-mcp-stdio"
    public static let D: String = "D-ckb-mcp-http"
}

public class CangjieHumanEvalPass1GateOptions {
    public var runRoot: String = ""
    public var manifestPath: String = "test/cangjie_eval/cangjie_humaneval_manifest.jsonl"
    public var groups: ArrayList<String> = ArrayList<String>()
    public var expectedTotal: Int64 = 164
    public var expectedPass: Int64 = 164
    public var format: String = "markdown"
    public var protocol: String = ""
    public var groupsExplicit: Bool = false
    public var emitCurationInputPath: String = ""
    public var help: Bool = false

    public init() {
        this.groups.add(CangjieHumanEvalPass1GateGroups.C)
        this.groups.add(CangjieHumanEvalPass1GateGroups.D)
    }
}

public class CangjieHumanEvalPass1ResultRow {
    public var ok: Bool = false
    public var diagnostic: String = ""
    public var raw: String = ""
    public var schemaVersion: String = ""
    public var caseId: String = ""
    public var group: String = ""
    public var unitPassAt1: Bool = false
    public var protocolViolation: Bool = false
    public var failureType: String = ""
    public var toolEvidence: String = ""
    public var runId: String = ""
    public var generationProtocol: String = "historical-agentic-v1"
    public var baseAnswerHash: String = ""
    public var plusAnswerHash: String = ""
    public var skillBundleHash: String = ""
    public var assetLineage: String = ""
    public var basePassed: Bool = false
    public var plusPassed: Bool = false

    public init() {}
}

public class CangjieHumanEvalPass1GroupResult {
    public var group: String = ""
    public var total: Int64 = 0
    public var passAt1: Int64 = 0
    public var duplicates: Int64 = 0
    public var missing: Int64 = 0
    public var protocolViolations: Int64 = 0
    public var transportParityFailures: Int64 = 0

    public init(group: String) {
        this.group = group
    }
}

public class CangjieHumanEvalRemainingGap {
    public var caseId: String = ""
    public var group: String = ""
    public var status: String = ""
    public var targetVersion: String = ""
    public var tags: ArrayList<String> = ArrayList<String>()
    public var gapCodes: ArrayList<String> = ArrayList<String>()
    public var kiInterfaces: ArrayList<String> = ArrayList<String>()
    public var taskText: String = ""

    public init() {}
}

public class CangjieHumanEvalPass1GateResult {
    public var ok: Bool = true
    public var runRoot: String = ""
    public var manifestPath: String = ""
    public var expectedTotal: Int64 = 164
    public var expectedPass: Int64 = 164
    public var manifestCaseCount: Int64 = 0
    public var parsedResultRows: Int64 = 0
    public var groups: ArrayList<CangjieHumanEvalPass1GroupResult> = ArrayList<CangjieHumanEvalPass1GroupResult>()
    public var remainingGaps: ArrayList<CangjieHumanEvalRemainingGap> = ArrayList<CangjieHumanEvalRemainingGap>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()
    public var baseMetricName: String = ""
    public var plusMetricName: String = ""
    public var basePassed: Int64 = 0
    public var plusPassed: Int64 = 0
    public var certificationStatus: String = ""
    public var assetLineage: String = ""

    public init() {}

    public func addDiagnostic(message: String): Unit {
        this.ok = false
        this.diagnostics.add(message)
    }
}

public func parseCangjieHumanEvalPass1GateOptions(args: Array<String>): CangjieHumanEvalPass1GateOptions {
    let options = CangjieHumanEvalPass1GateOptions()
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "cangjie-humaneval-pass1-gate") {
            i += 1
            continue
        }
        if (arg == "--help" || arg == "-h") {
            options.help = true
            i += 1
            continue
        }
        if ((arg == "--run-root" || arg == "--run") && i + 1 < args.size) {
            options.runRoot = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--manifest" && i + 1 < args.size) {
            options.manifestPath = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--groups" && i + 1 < args.size) {
            options.groups = cangjieHumanEvalGateParseGroups(args[i + 1])
            options.groupsExplicit = true
            i += 2
            continue
        }
        if (arg == "--expected-total" && i + 1 < args.size) {
            options.expectedTotal = cangjieHumanEvalGateParseInt(args[i + 1], options.expectedTotal)
            i += 2
            continue
        }
        if (arg == "--expected-pass" && i + 1 < args.size) {
            options.expectedPass = cangjieHumanEvalGateParseInt(args[i + 1], options.expectedPass)
            i += 2
            continue
        }
        if (arg == "--format" && i + 1 < args.size) {
            options.format = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--protocol" && i + 1 < args.size) {
            options.protocol = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--emit-curation-input" && i + 1 < args.size) {
            options.emitCurationInputPath = args[i + 1].trimAscii()
            i += 2
            continue
        }
        i += 1
    }
    if(options.protocol=="completion-only-v1"){
        if(!options.groupsExplicit){options.groups=ArrayList<String>();options.groups.add(CangjieHumanEvalPass1GateGroups.D)}
        else if(options.groups.size!=1||options.groups[0]!=CangjieHumanEvalPass1GateGroups.D){options.groups=ArrayList<String>()}
    }
    options
}

public func runCangjieHumanEvalPass1Gate(args: Array<String>): Int64 {
    let options = parseCangjieHumanEvalPass1GateOptions(args)
    if (options.help) {
        print(cangjieHumanEvalPass1GateUsage())
        return 0
    }
    if (options.runRoot == "") {
        println("usage error: cangjie-humaneval-pass1-gate requires --run-root <path>")
        return 2
    }
    if(options.protocol=="completion-only-v1"&&(options.groups.size!=1||options.groups[0]!=CangjieHumanEvalPass1GateGroups.D)){println("usage error: completion-only-v1 requires group D");return 2}
    let result = cangjieHumanEvalPass1GateFromFiles(options)
    if (options.emitCurationInputPath != "") {
        let writeDiagnostic = cangjieHumanEvalGateWriteCurationInput(options.runRoot, options.emitCurationInputPath, result)
        if (writeDiagnostic != "ok") {
            result.addDiagnostic(writeDiagnostic)
        }
    }
    if (options.format == "json") {
        print(renderCangjieHumanEvalPass1GateJson(result))
    } else {
        print(renderCangjieHumanEvalPass1GateMarkdown(result))
    }
    if (result.ok) { 0 } else { 1 }
}

public func runCangjieHumanEvalPass1GateSmoke(args: Array<String>): Int64 {
    let manifest = cangjieHumanEvalGateManifestLine("CJ-HUMANEVAL-000", "Implement ArrayList.", "[\"ArrayList\"]") + "\n" +
        cangjieHumanEvalGateManifestLine("CJ-HUMANEVAL-001", "Implement String.", "[\"String\"]") + "\n"
    let passRows = cangjieHumanEvalGateResultLine("CJ-HUMANEVAL-000", CangjieHumanEvalPass1GateGroups.C, true, "none", false, "cangjie_task_knowledge_pack") + "\n" +
        cangjieHumanEvalGateResultLine("CJ-HUMANEVAL-000", CangjieHumanEvalPass1GateGroups.D, true, "none", false, "cangjie_task_knowledge_pack") + "\n" +
        cangjieHumanEvalGateResultLine("CJ-HUMANEVAL-001", CangjieHumanEvalPass1GateGroups.C, true, "none", false, "cangjie_task_knowledge_pack") + "\n" +
        cangjieHumanEvalGateResultLine("CJ-HUMANEVAL-001", CangjieHumanEvalPass1GateGroups.D, true, "none", false, "cangjie_task_knowledge_pack") + "\n"
    let failRows = cangjieHumanEvalGateResultLine("CJ-HUMANEVAL-000", CangjieHumanEvalPass1GateGroups.C, true, "none", false, "cangjie_task_knowledge_pack") + "\n" +
        cangjieHumanEvalGateResultLine("CJ-HUMANEVAL-000", CangjieHumanEvalPass1GateGroups.D, true, "none", false, "cangjie_task_knowledge_pack") + "\n" +
        cangjieHumanEvalGateResultLine("CJ-HUMANEVAL-001", CangjieHumanEvalPass1GateGroups.C, false, "compile_error", false, "cangjie_task_knowledge_pack") + "\n" +
        cangjieHumanEvalGateResultLine("CJ-HUMANEVAL-001", CangjieHumanEvalPass1GateGroups.D, true, "none", false, "cangjie_task_knowledge_pack") + "\n"
    let options = CangjieHumanEvalPass1GateOptions()
    options.expectedTotal = 2
    options.expectedPass = 2
    let pass = cangjieHumanEvalPass1GateFromText(passRows, manifest, options, "smoke-pass", "smoke-manifest")
    let fail = cangjieHumanEvalPass1GateFromText(failRows, manifest, options, "smoke-fail", "smoke-manifest")
    let curation = emitCangjieHumanEvalGapCurationInput(fail)
    let ok = pass.ok && !fail.ok && fail.remainingGaps.size > 0 && curation.contains("officialCitation")
    println("pass1-gate-smoke ok=${ok}")
    println("passGate=${pass.ok}")
    println("failGate=${fail.ok}")
    println("remainingGaps=${fail.remainingGaps.size}")
    println("curationInputReady=${curation.contains("officialCitation")}")
    if (ok) { 0 } else { 1 }
}

public func cangjieHumanEvalPass1GateFromFiles(options: CangjieHumanEvalPass1GateOptions): CangjieHumanEvalPass1GateResult {
    let result = CangjieHumanEvalPass1GateResult()
    result.runRoot = options.runRoot
    result.manifestPath = options.manifestPath
    result.expectedTotal = options.expectedTotal
    result.expectedPass = options.expectedPass
    if (!exists(Path(options.runRoot))) {
        result.addDiagnostic("run_root_not_found:${options.runRoot}")
        return result
    }
    let resultsPath = "${options.runRoot}/results.jsonl"
    if (!exists(Path(resultsPath))) {
        result.addDiagnostic("results_not_found:${resultsPath}")
        return result
    }
    if (!exists(Path(options.manifestPath))) {
        result.addDiagnostic("manifest_not_found:${options.manifestPath}")
        return result
    }
    let manifestText=cangjieHumanEvalGateReadText(options.manifestPath)
    if(options.protocol=="completion-only-v1"){
        let gate=ckbStrictCertificationGateFromRunRoot(options.runRoot,manifestText)
        let thresholdOnly=!gate.ok&&gate.diagnostics.size==1&&gate.diagnostics[0]=="strict_pass_at_1_requirements_not_met"
        if(!gate.ok&&!thresholdOnly){result.addDiagnostic("completion_private_artifact_certification_invalid:${if(gate.diagnostics.size>0){gate.diagnostics[0]}else{"unknown"}}");return result}
    }
    cangjieHumanEvalPass1GateFromText(cangjieHumanEvalGateReadText(resultsPath), manifestText, options, options.runRoot, options.manifestPath)
}

public func cangjieHumanEvalPass1GateFromText(
    resultsText: String,
    manifestText: String,
    options: CangjieHumanEvalPass1GateOptions,
    runRoot: String,
    manifestPath: String
): CangjieHumanEvalPass1GateResult {
    let result = CangjieHumanEvalPass1GateResult()
    result.runRoot = runRoot
    result.manifestPath = manifestPath
    result.expectedTotal = options.expectedTotal
    result.expectedPass = options.expectedPass
    let authorityMode = manifestText.contains("cangjie-humaneval-authority-v1")
    let authority = if (authorityMode) { parseCangjieHumanEvalAuthorityManifest(manifestText) } else { CangjieHumanEvalManifestResult() }
    let manifest = if (authorityMode) { cangjieHumanEvalGateManifestFromAuthority(authority) } else { parseCangjieEvalManifest(manifestText) }
    let rows = parseCangjieHumanEvalPass1Rows(resultsText)
    result.manifestCaseCount = manifest.cases.size
    if (manifest.invalidLines > 0) {
        result.addDiagnostic("manifest_invalid_lines:${manifest.invalidLines}")
    }
    if (authorityMode && !authority.ok) {
        for (diagnostic in authority.diagnostics) { result.addDiagnostic("authority_${diagnostic}") }
    }
    if (manifest.cases.size != options.expectedTotal) {
        result.addDiagnostic("manifest_case_count_mismatch:${manifest.cases.size}:${options.expectedTotal}")
    }
    cangjieHumanEvalGateValidateManifestIdentity(manifest, options.expectedTotal, result)
    for (row in rows) {
        if (row.ok) {
            result.parsedResultRows += 1
        } else {
            result.addDiagnostic("${row.diagnostic}:${cangjieHumanEvalGateCompactRaw(row.raw)}")
        }
    }
    if(options.protocol=="completion-only-v1"){
        var runId="";var bundle="";var lineage=""
        let scoreRows=ArrayList<CkbStrictScoreEvidenceRow>()
        for(row in rows){
            if(!row.ok||row.generationProtocol!="completion-only-v1"){result.addDiagnostic("completion_protocol_row_invalid:${row.caseId}");continue}
            if(runId==""){runId=row.runId;bundle=row.skillBundleHash;lineage=row.assetLineage}
            if(row.runId!=runId){result.addDiagnostic("cross_run_sample_join:${row.caseId}")}
            if(row.baseAnswerHash!=row.plusAnswerHash){result.addDiagnostic("base_plus_answer_mismatch:${row.caseId}")}
            if(row.skillBundleHash!=bundle||row.assetLineage!=lineage){result.addDiagnostic("completion_bundle_or_lineage_drift:${row.caseId}")}
            let certification=parseCkbCertificationEvidence(row.raw)
            let artifactDiagnostic=ckbStrictCompletionCaseFromRunRootDiagnostic(runRoot,certification)
            if(artifactDiagnostic!="ok"){result.addDiagnostic("completion_artifact_invalid:${row.caseId}:${artifactDiagnostic}")}
            if(certification.valid){scoreRows.add(cangjieHumanEvalCompletionScoreRow(certification))}
        }
        let score=computeCkbHumanEvalStrictScore(scoreRows)
        if(!score.valid){result.addDiagnostic("completion_score_invalid:${score.diagnostic}")}else{result.baseMetricName=score.baseMetricName;result.plusMetricName=score.plusMetricName;result.basePassed=score.basePassed;result.plusPassed=score.plusPassed;result.certificationStatus=score.certificationStatus;result.assetLineage=if(scoreRows.size>0){scoreRows[0].assetLineage}else{""}}
    }
    for (group in options.groups) {
        result.groups.add(cangjieHumanEvalPass1GroupGate(group, rows, manifest, options, result.remainingGaps))
    }
    for (groupResult in result.groups) {
        if (groupResult.total != options.expectedTotal) {
            result.addDiagnostic("group_total_mismatch:${groupResult.group}:${groupResult.total}:${options.expectedTotal}")
        }
        if (options.protocol!="completion-only-v1"&&groupResult.passAt1 != options.expectedPass) {
            result.addDiagnostic("group_pass_at1_mismatch:${groupResult.group}:${groupResult.passAt1}:${options.expectedPass}")
        }
        if (groupResult.duplicates > 0) {
            result.addDiagnostic("duplicate_result_rows:${groupResult.group}:${groupResult.duplicates}")
        }
        if (groupResult.missing > 0) {
            result.addDiagnostic("missing_result_rows:${groupResult.group}:${groupResult.missing}")
        }
        if (groupResult.protocolViolations > 0) {
            result.addDiagnostic("protocol_violation_rows:${groupResult.group}:${groupResult.protocolViolations}")
        }
        if (groupResult.transportParityFailures > 0) {
            result.addDiagnostic("transport_parity_failure_rows:${groupResult.group}:${groupResult.transportParityFailures}")
        }
    }
    result
}

private func cangjieHumanEvalGateValidateManifestIdentity(
    manifest: CangjieEvalManifestSummary,
    expectedTotal: Int64,
    result: CangjieHumanEvalPass1GateResult
): Unit {
    let seen = ArrayList<String>()
    for (i in 0..manifest.cases.size) {
        let caseId = manifest.cases[i].id
        if (seen.contains(caseId)) { result.addDiagnostic("manifest_duplicate_case_id:${caseId}") } else { seen.add(caseId) }
        if (caseId != cangjieHumanEvalGateExpectedCaseId(i)) {
            result.addDiagnostic("manifest_case_id_not_contiguous:${i}:${caseId}")
        }
    }
}

private func cangjieHumanEvalGateManifestFromAuthority(authority: CangjieHumanEvalManifestResult): CangjieEvalManifestSummary {
    let manifest = CangjieEvalManifestSummary()
    for (row in authority.rows) {
        let evalCase = CangjieEvalCase()
        evalCase.id = row.caseId
        evalCase.category = CangjieEvalCategories.UNIT
        evalCase.targetVersion = row.targetVersion
        evalCase.prompt = row.prompt
        evalCase.entryPoint = "${row.caseId}/starter"
        evalCase.testCommand = "verifier-owned"
        for (tag in row.expectedKnowledgeTags) { evalCase.expectedKnowledgeTags.add(tag) }
        manifest.cases.add(evalCase)
    }
    manifest
}

private func cangjieHumanEvalGateExpectedCaseId(index: Int64): String {
    if (index < 10) { return "CJ-HUMANEVAL-00${index}" }
    if (index < 100) { return "CJ-HUMANEVAL-0${index}" }
    "CJ-HUMANEVAL-${index}"
}

public func parseCangjieHumanEvalPass1Rows(text: String): ArrayList<CangjieHumanEvalPass1ResultRow> {
    let rows = ArrayList<CangjieHumanEvalPass1ResultRow>()
    for (line in text.split("\n")) {
        if (line.trimAscii() == "") {
            continue
        }
        rows.add(parseCangjieHumanEvalPass1Row(line))
    }
    rows
}

public func parseCangjieHumanEvalPass1Row(line: String): CangjieHumanEvalPass1ResultRow {
    let row = CangjieHumanEvalPass1ResultRow()
    let raw = line.trimAscii()
    row.raw = raw
    if (raw == "" || !raw.startsWith("{") || !raw.endsWith("}")) {
        row.diagnostic = "malformed_result_row"
        return row
    }
    try {
        let object = JsonValue.fromStr(raw).asObject()
        row.schemaVersion = match (object.get("schemaVersion")) {
            case Some(value) => value.asString().getValue().trimAscii()
            case None => ""
        }
        row.caseId = cangjieHumanEvalGateObjectString(object, "caseId").trimAscii()
        row.group = cangjieHumanEvalGateObjectString(object, "group").trimAscii()
        if(row.schemaVersion=="ckb-humaneval-certification-result-v4"){
            let certification=parseCkbCertificationEvidence(raw);if(!certification.valid){row.diagnostic="completion_${certification.diagnostic}";return row}
            row.runId=certification.runId;row.generationProtocol=certification.generationProtocol;row.baseAnswerHash=certification.baseAnswerHash;row.plusAnswerHash=certification.plusAnswerHash
            row.skillBundleHash=certification.skillBundleHash;row.assetLineage=certification.assetLineage;row.basePassed=certification.basePassed;row.plusPassed=certification.plusPassed
            row.unitPassAt1=certification.certificationPassAt1;row.protocolViolation=false;row.failureType=if(row.unitPassAt1){"none"}else{"test_failure"}
        }else{
            row.unitPassAt1 = cangjieHumanEvalGateObjectBool(object, "unitPassAt1")
            row.protocolViolation = cangjieHumanEvalGateObjectBool(object, "protocolViolation")
            row.failureType = cangjieHumanEvalGateObjectString(object, "failureType").trimAscii()
            row.toolEvidence = cangjieHumanEvalGateObjectString(object, "toolEvidence").trimAscii()
        }
    } catch (_: Exception) {
        row.diagnostic = "malformed_result_row"
        return row
    }
    if (row.caseId == "" || row.group == "") {
        row.diagnostic = "missing_result_field"
        return row
    }
    row.ok = true
    row
}

private func cangjieHumanEvalPass1GroupGate(
    group: String,
    rows: ArrayList<CangjieHumanEvalPass1ResultRow>,
    manifest: CangjieEvalManifestSummary,
    options: CangjieHumanEvalPass1GateOptions,
    gaps: ArrayList<CangjieHumanEvalRemainingGap>
): CangjieHumanEvalPass1GroupResult {
    let groupResult = CangjieHumanEvalPass1GroupResult(group)
    for (evalCase in manifest.cases) {
        let indexes = cangjieHumanEvalGateFindRows(rows, evalCase.id, group)
        if (indexes.size == 0) {
            groupResult.missing += 1
            gaps.add(cangjieHumanEvalRemainingGapForCase(evalCase, group, "missing_result"))
            continue
        }
        if (indexes.size > 1) {
            groupResult.duplicates += indexes.size - 1
        }
        let row = rows[indexes[0]]
        groupResult.total += 1
        if (row.unitPassAt1) {
            groupResult.passAt1 += 1
        }
        if (row.protocolViolation) {
            groupResult.protocolViolations += 1
        }
        if (cangjieHumanEvalGateTransportParityFailure(group, row)) {
            groupResult.transportParityFailures += 1
        }
        if (!row.unitPassAt1 || row.protocolViolation || cangjieHumanEvalGateTransportParityFailure(group, row)) {
            gaps.add(cangjieHumanEvalRemainingGapForCase(evalCase, group, cangjieHumanEvalGateRowStatus(row)))
        }
    }
    groupResult
}

private func cangjieHumanEvalGateFindRows(rows: ArrayList<CangjieHumanEvalPass1ResultRow>, caseId: String, group: String): ArrayList<Int64> {
    let indexes = ArrayList<Int64>()
    for (i in 0..rows.size) {
        if (rows[i].ok && rows[i].caseId == caseId && rows[i].group == group) {
            indexes.add(i)
        }
    }
    indexes
}

private func cangjieHumanEvalGateTransportParityFailure(group: String, row: CangjieHumanEvalPass1ResultRow): Bool {
    if(row.generationProtocol=="completion-only-v1"){return false}
    (group == CangjieHumanEvalPass1GateGroups.C || group == CangjieHumanEvalPass1GateGroups.D) &&
        row.toolEvidence != "cangjie_task_knowledge_pack"
}

private func cangjieHumanEvalCompletionScoreRow(certification:CkbCertificationCaseEvidence):CkbStrictScoreEvidenceRow{
    let row=CkbStrictScoreEvidenceRow();row.schemaVersion="ckb-humaneval-public-evidence-v2";row.caseId=certification.caseId;row.runId=certification.runId;row.datasetVersion=certification.datasetVersion;row.knowledgeVersion=certification.knowledgeVersion;row.modelFingerprint=certification.modelFingerprint;row.providerIdentityHash=certification.providerIdentityHash;row.runManifestHash=certification.runManifestHash;row.certificationPassAt1=certification.certificationPassAt1;row.unitFirstSamplePassed=certification.certificationPassAt1&&certification.unresolvedTransport==0;row.classification=if(certification.unresolvedTransport==1){"transport_unresolved"}else if(certification.certificationPassAt1){"none"}else{"business_failure"};row.sampleAttemptCount=certification.sampleAttemptCount;row.selectedBusinessSample=certification.selectedBusinessSample;row.transportAttemptCount=certification.transportAttemptCount;row.transportRetryCount=certification.retryCount;row.unresolvedTransport=certification.unresolvedTransport;row.retryUsed=certification.retryUsed;row.fallbackUsed=certification.fallbackUsed;row.referenceExposure=certification.referenceExposure;row.hiddenTestExposure=certification.hiddenTestExposure;row.teacherExposure=certification.teacherExposure;row.crossCaseExposure=certification.crossCaseExposure;row.generationProtocol=certification.generationProtocol;row.assetLineage=certification.assetLineage;row.skillBundleHash=certification.skillBundleHash;row.basePassed=certification.basePassed;row.plusPassed=certification.plusPassed;row
}

private func cangjieHumanEvalGateRowStatus(row: CangjieHumanEvalPass1ResultRow): String {
    if (row.protocolViolation) {
        return "protocol_violation"
    }
    if (cangjieHumanEvalGateTransportParityFailure(row.group, row)) {
        return "transport_parity_failure"
    }
    if (row.failureType != "" && row.failureType != "none") {
        return row.failureType
    }
    if (!row.unitPassAt1) {
        return "not_pass_at1"
    }
    "ok"
}

private func cangjieHumanEvalRemainingGapForCase(evalCase: CangjieEvalCase, group: String, status: String): CangjieHumanEvalRemainingGap {
    let gap = CangjieHumanEvalRemainingGap()
    gap.caseId = evalCase.id
    gap.group = group
    gap.status = status
    gap.targetVersion = evalCase.targetVersion
    gap.taskText = evalCase.prompt
    for (tag in evalCase.expectedKnowledgeTags) {
        gap.tags.add(tag)
        let code = cangjieHumanEvalGateGapCode(tag)
        if (!gap.gapCodes.contains(code)) {
            gap.gapCodes.add(code)
        }
        for (ki in cangjieHumanEvalGateKiInterfaces(code)) {
            if (!gap.kiInterfaces.contains(ki)) {
                gap.kiInterfaces.add(ki)
            }
        }
    }
    if (gap.gapCodes.size == 0) {
        gap.gapCodes.add("G-RECIPE")
        for (ki in cangjieHumanEvalGateKiInterfaces("G-RECIPE")) {
            gap.kiInterfaces.add(ki)
        }
    }
    gap
}

public func renderCangjieHumanEvalPass1GateMarkdown(result: CangjieHumanEvalPass1GateResult): String {
    var out = "# Cangjie HumanEval Pass@1 Gate\n\n"
    out += "- releaseGate: ${if (result.ok) { "pass" } else { "fail" }}\n"
    out += "- runRoot: `${result.runRoot}`\n"
    out += "- manifestPath: `${result.manifestPath}`\n"
    out += "- expected: ${result.expectedPass}/${result.expectedTotal}\n"
    out += "- manifestCaseCount: ${result.manifestCaseCount}\n"
    out += "- parsedResultRows: ${result.parsedResultRows}\n\n"
    if(result.baseMetricName!=""){out+="${result.baseMetricName}=${result.basePassed}/${result.expectedTotal}\n${result.plusMetricName}=${result.plusPassed}/${result.expectedTotal}\ncertification_status=${result.certificationStatus}\nasset_lineage=${result.assetLineage}\n\n"}
    out += "## Group Gate\n\n"
    out += "| group | total | pass@1 | duplicates | missing | protocolViolation | transportParityFailure |\n"
    out += "| --- | ---: | ---: | ---: | ---: | ---: | ---: |\n"
    for (group in result.groups) {
        out += "| ${group.group} | ${group.total} | ${group.passAt1} | ${group.duplicates} | ${group.missing} | ${group.protocolViolations} | ${group.transportParityFailures} |\n"
    }
    out += "\n## Diagnostics\n\n"
    if (result.diagnostics.size == 0) {
        out += "- none\n"
    } else {
        for (diagnostic in result.diagnostics) {
            out += "- `${cangjieHumanEvalGateEscapeMarkdown(diagnostic)}`\n"
        }
    }
    out += "\n## Remaining Gaps\n\n"
    out += "| caseId | group | status | gaps | KI interfaces | tags |\n"
    out += "| --- | --- | --- | --- | --- | --- |\n"
    for (gap in result.remainingGaps) {
        out += "| ${gap.caseId} | ${gap.group} | ${gap.status} | ${cangjieHumanEvalGateJoin(gap.gapCodes, ", ")} | ${cangjieHumanEvalGateJoin(gap.kiInterfaces, ", ")} | ${cangjieHumanEvalGateJoin(gap.tags, ", ")} |\n"
    }
    out
}

public func renderCangjieHumanEvalPass1GateJson(result: CangjieHumanEvalPass1GateResult): String {
    var groups = ""
    for (i in 0..result.groups.size) {
        if (i > 0) { groups += "," }
        let group = result.groups[i]
        groups += "{\"group\":\"${cangjieHumanEvalGateJsonEscape(group.group)}\",\"total\":${group.total},\"passAt1\":${group.passAt1},\"duplicates\":${group.duplicates},\"missing\":${group.missing},\"protocolViolations\":${group.protocolViolations},\"transportParityFailures\":${group.transportParityFailures}}"
    }
    var gaps = ""
    for (i in 0..result.remainingGaps.size) {
        if (i > 0) { gaps += "," }
        let gap = result.remainingGaps[i]
        gaps += "{\"caseId\":\"${cangjieHumanEvalGateJsonEscape(gap.caseId)}\",\"group\":\"${cangjieHumanEvalGateJsonEscape(gap.group)}\",\"status\":\"${cangjieHumanEvalGateJsonEscape(gap.status)}\",\"targetVersion\":\"${cangjieHumanEvalGateJsonEscape(gap.targetVersion)}\",\"gapCodes\":[${cangjieHumanEvalGateJsonStringArray(gap.gapCodes)}],\"kiInterfaces\":[${cangjieHumanEvalGateJsonStringArray(gap.kiInterfaces)}],\"tags\":[${cangjieHumanEvalGateJsonStringArray(gap.tags)}]}"
    }
    "{\"ok\":${result.ok},\"baseMetricName\":\"${cangjieHumanEvalGateJsonEscape(result.baseMetricName)}\",\"plusMetricName\":\"${cangjieHumanEvalGateJsonEscape(result.plusMetricName)}\",\"basePassed\":${result.basePassed},\"plusPassed\":${result.plusPassed},\"certificationStatus\":\"${cangjieHumanEvalGateJsonEscape(result.certificationStatus)}\",\"assetLineage\":\"${cangjieHumanEvalGateJsonEscape(result.assetLineage)}\",\"releaseGate\":\"${if (result.ok) { "pass" } else { "fail" }}\",\"runRoot\":\"${cangjieHumanEvalGateJsonEscape(result.runRoot)}\",\"manifestPath\":\"${cangjieHumanEvalGateJsonEscape(result.manifestPath)}\",\"expectedTotal\":${result.expectedTotal},\"expectedPass\":${result.expectedPass},\"manifestCaseCount\":${result.manifestCaseCount},\"parsedResultRows\":${result.parsedResultRows},\"diagnostics\":[${cangjieHumanEvalGateJsonStringArray(result.diagnostics)}],\"groups\":[${groups}],\"remainingGaps\":[${gaps}]}\n"
}

public func emitCangjieHumanEvalGapCurationInput(result: CangjieHumanEvalPass1GateResult): String {
    var out = ""
    for (gap in result.remainingGaps) {
        for (gapCode in gap.gapCodes) {
            out += "{\"caseId\":\"${cangjieHumanEvalGateJsonEscape(gap.caseId)}\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"${cangjieHumanEvalGateJsonEscape(gap.taskText)}\",\"visibleTestExcerpt\":\"\",\"compilerOutput\":\"${cangjieHumanEvalGateJsonEscape(gap.status)}\",\"missingKnowledge\":\"${cangjieHumanEvalGateJsonEscape(gapCode)}\",\"interfaceId\":\"${cangjieHumanEvalGateJsonEscape(cangjieHumanEvalGatePrimaryInterface(gapCode))}\",\"contentFamily\":\"${cangjieHumanEvalGateContentFamily(gapCode)}\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"${cangjieHumanEvalGateJsonEscape(if (gap.targetVersion == "") { cangjieDefaultTargetVersion() } else { gap.targetVersion })}\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/\"}\n"
        }
    }
    out
}

// Cross-project authority output is deliberately separate from the legacy internal
// curation feed. Only two independently observed first-attempt knowledge gaps emit.
public func emitCangjieHumanEvalAuthoritativeGapCurationInput(result: CangjieHumanEvalPass1GateResult, datasetVersion: String, teacherRunId: String): String {
    if (!cangjieHumanEvalAuthorityIdentityAllowed(datasetVersion) || !cangjieHumanEvalAuthorityIdentityAllowed(teacherRunId)) { return "" }
    let emitted = ArrayList<String>()
    let out = StringBuilder()
    for (gap in result.remainingGaps) {
        if (gap.status != "knowledge_gap") { continue }
        for (gapCode in gap.gapCodes) {
            let key = "${gap.caseId}:${gapCode}:${gap.targetVersion}"
            if (emitted.contains(key)) { continue }
            let cEvidence = cangjieHumanEvalAuthorityConfirmationEvidence(result, gap.caseId, gapCode, CangjieHumanEvalPass1GateGroups.C)
            let dEvidence = cangjieHumanEvalAuthorityConfirmationEvidence(result, gap.caseId, gapCode, CangjieHumanEvalPass1GateGroups.D)
            if (cEvidence == "" || dEvidence == "") { continue }
            let confirmations: Int64 = 2
            let input = CangjieBenchmarkGapInput()
            input.schemaVersion = "ckb-benchmark-gap-v1"; input.datasetVersion = datasetVersion; input.teacherRunId = teacherRunId
            input.candidatePath = "authority/benchmark-gap.jsonl"; input.revision = 1; input.attempt = 1
            input.failureTaxonomy = "knowledge_gap"; input.knowledgeGapConfirmations = confirmations
            input.caseId = gap.caseId; input.taskText = gap.taskText; input.compilerOutput = gap.status; input.missingKnowledge = gapCode
            input.interfaceId = cangjieHumanEvalGatePrimaryInterface(gapCode); input.contentFamily = cangjieHumanEvalGateContentFamily(gapCode)
            input.updateMechanism = "KU-11"; input.targetVersion = if (gap.targetVersion == "") { cangjieDefaultTargetVersion() } else { gap.targetVersion }
            input.officialCitation = "https://docs.cangjie-lang.cn/docs/1.0.0/"
            input.evidence = "case=${gap.caseId}|gap=${gapCode}|taxonomy=knowledge_gap|confirmations=2|C=${cEvidence}|D=${dEvidence}"
            input.evidenceHash = benchmarkGapSha256(input.evidence); input.candidateHash = canonicalBenchmarkGapCandidateHash(input)
            out.append(cangjieHumanEvalAuthorityGapJson(input)); emitted.add(key)
        }
    }
    out.toString()
}

private func cangjieHumanEvalAuthorityConfirmationEvidence(result: CangjieHumanEvalPass1GateResult, caseId: String, gapCode: String, requiredGroup: String): String {
    for (gap in result.remainingGaps) {
        if (gap.caseId == caseId && gap.group == requiredGroup && gap.status == "knowledge_gap" && gap.gapCodes.contains(gapCode)) {
            let canonical = "group=${gap.group}|status=${gap.status}|case=${gap.caseId}|task=${gap.taskText}|target=${gap.targetVersion}|gap=${gapCode}|allGaps=${cangjieHumanEvalGateJoin(gap.gapCodes, ",")}|tags=${cangjieHumanEvalGateJoin(gap.tags, ",")}"
            return benchmarkGapSha256(canonical)
        }
    }
    ""
}

private func cangjieHumanEvalAuthorityGapJson(input: CangjieBenchmarkGapInput): String {
    "{\"schemaVersion\":\"${cangjieHumanEvalGateJsonEscape(input.schemaVersion)}\",\"datasetVersion\":\"${cangjieHumanEvalGateJsonEscape(input.datasetVersion)}\",\"teacherRunId\":\"${cangjieHumanEvalGateJsonEscape(input.teacherRunId)}\",\"evidence\":\"${cangjieHumanEvalGateJsonEscape(input.evidence)}\",\"evidenceHash\":\"${cangjieHumanEvalGateJsonEscape(input.evidenceHash)}\",\"candidateHash\":\"${cangjieHumanEvalGateJsonEscape(input.candidateHash)}\",\"candidatePath\":\"${cangjieHumanEvalGateJsonEscape(input.candidatePath)}\",\"revision\":${input.revision},\"attempt\":1,\"failureTaxonomy\":\"knowledge_gap\",\"knowledgeGapConfirmations\":${input.knowledgeGapConfirmations},\"caseId\":\"${cangjieHumanEvalGateJsonEscape(input.caseId)}\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"${cangjieHumanEvalGateJsonEscape(input.taskText)}\",\"compilerOutput\":\"knowledge_gap\",\"missingKnowledge\":\"${cangjieHumanEvalGateJsonEscape(input.missingKnowledge)}\",\"interfaceId\":\"${cangjieHumanEvalGateJsonEscape(input.interfaceId)}\",\"contentFamily\":\"${cangjieHumanEvalGateJsonEscape(input.contentFamily)}\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"${cangjieHumanEvalGateJsonEscape(input.targetVersion)}\",\"officialCitation\":\"${cangjieHumanEvalGateJsonEscape(input.officialCitation)}\"}\n"
}

private func cangjieHumanEvalAuthorityIdentityAllowed(value: String): Bool {
    let chars = value.toRuneArray(); if (chars.size == 0 || chars.size > 256) { return false }
    for (ch in chars) { let ok = (ch >= r'a' && ch <= r'z') || (ch >= r'A' && ch <= r'Z') || (ch >= r'0' && ch <= r'9') || ch == r'-' || ch == r'_' || ch == r'.'; if (!ok) { return false } }
    true
}

private func cangjieHumanEvalGateWriteCurationInput(runRoot: String, path: String, result: CangjieHumanEvalPass1GateResult): String {
    if (!path.startsWith(runRoot + "/")) {
        return "unsafe_curation_input_path:${path}"
    }
    try {
        let target = Path(path)
        if (!exists(target.parent)) {
            Directory.create(target.parent, recursive: true)
        }
        File.writeTo(target, emitCangjieHumanEvalGapCurationInput(result).toArray())
    } catch (_: Exception) {
        return "write_curation_input_failed:${path}"
    }
    "ok"
}

public func cangjieHumanEvalPass1GateUsage(): String {
    "Usage: cangjie_community_knowledge_base cangjie-humaneval-pass1-gate --run-root <path> [--manifest <manifest.jsonl>] [--groups C,D] [--expected-total 164] [--expected-pass 164] [--format markdown|json] [--emit-curation-input <runRoot/path.jsonl>]\n"
}

private func cangjieHumanEvalGateParseGroups(raw: String): ArrayList<String> {
    let groups = ArrayList<String>()
    for (item in raw.split(",")) {
        let trimmed = item.trimAscii()
        if (trimmed == "C") {
            groups.add(CangjieHumanEvalPass1GateGroups.C)
        } else if (trimmed == "D") {
            groups.add(CangjieHumanEvalPass1GateGroups.D)
        } else if (trimmed != "") {
            groups.add(trimmed)
        }
    }
    groups
}

private func cangjieHumanEvalGateParseInt(raw: String, fallback: Int64): Int64 {
    try {
        Int64.parse(raw.trimAscii())
    } catch (_: Exception) {
        fallback
    }
}

private func cangjieHumanEvalGateGapCode(tag: String): String {
    let lower = tag.toAsciiLower()
    if (lower.contains("arraylist")) { return "G-ARRAYLIST" }
    if (lower.contains("string") || lower.contains("rune")) { return "G-STRING" }
    if (lower.contains("float64")) { return "G-FLOAT64" }
    if (lower.contains("int64") || lower.contains("numeric")) { return "G-INT64" }
    if (lower.contains("bool")) { return "G-BOOL" }
    if (lower.contains("tuple")) { return "G-TUPLE" }
    if (lower.contains("evalvalue")) { return "G-EVALVALUE" }
    if (lower.contains("evalentry")) { return "G-EVALENTRY" }
    if (lower.contains("option")) { return "G-OPTION" }
    if (lower.contains("hashmap")) { return "G-HASHMAP" }
    "G-RECIPE"
}

private func cangjieHumanEvalGateKiInterfaces(gapCode: String): ArrayList<String> {
    let interfaces = ArrayList<String>()
    if (gapCode == "G-RECIPE") {
        interfaces.add("KI-07")
        interfaces.add("KI-01")
        interfaces.add("KI-12")
        interfaces.add("KI-13")
    } else if (gapCode == "G-EVALVALUE" || gapCode == "G-EVALENTRY") {
        interfaces.add("KI-05")
        interfaces.add("KI-06")
        interfaces.add("KI-13")
    } else if (gapCode == "G-ARRAYLIST" || gapCode == "G-STRING" || gapCode == "G-HASHMAP" || gapCode == "G-FLOAT64") {
        interfaces.add("KI-02")
        interfaces.add("KI-03")
        interfaces.add("KI-06")
        interfaces.add("KI-07")
    } else {
        interfaces.add("KI-04")
        interfaces.add("KI-06")
        interfaces.add("KI-07")
    }
    interfaces
}

private func cangjieHumanEvalGatePrimaryInterface(gapCode: String): String {
    let interfaces = cangjieHumanEvalGateKiInterfaces(gapCode)
    if (interfaces.size > 0) {
        return interfaces[0]
    }
    "KI-07"
}

private func cangjieHumanEvalGateContentFamily(gapCode: String): String {
    if (gapCode == "G-RECIPE" || gapCode == "G-TIMEOUT" || gapCode == "G-EDGE" || gapCode == "G-EVALVALUE" || gapCode == "G-EVALENTRY") {
        return "KC-05"
    }
    if (gapCode == "G-ARRAYLIST" || gapCode == "G-STRING" || gapCode == "G-HASHMAP" || gapCode == "G-FLOAT64") {
        return "KC-02"
    }
    "KC-01"
}

private func cangjieHumanEvalGateManifestLine(caseId: String, prompt: String, tagsJson: String): String {
    "{\"id\":\"${caseId}\",\"category\":\"unit\",\"targetVersion\":\"1.0.0\",\"prompt\":\"${cangjieHumanEvalGateJsonEscape(prompt)}\",\"entryPoint\":\"cases/${caseId}/starter\",\"testCommand\":\"cjpm run\",\"expectedKnowledgeTags\":${tagsJson}}"
}

private func cangjieHumanEvalGateResultLine(caseId: String, group: String, passAt1: Bool, failureType: String, protocolViolation: Bool, toolEvidence: String): String {
    "{\"runId\":\"unit\",\"benchmark\":\"Cangjie-HumanEval\",\"caseId\":\"${caseId}\",\"group\":\"${group}\",\"unitPassAt1\":${passAt1},\"failureType\":\"${failureType}\",\"protocolViolation\":${protocolViolation},\"toolEvidence\":\"${toolEvidence}\"}"
}

private func cangjieHumanEvalGateReadText(path: String): String {
    try {
        String.fromUtf8(File.readFrom(Path(path)))
    } catch (_: Exception) {
        ""
    }
}

private func cangjieHumanEvalGateObjectString(object: JsonObject, field: String): String {
    match (object.get(field)) {
        case Some(value) => value.asString().getValue()
        case None => throw Exception("missing result string")
    }
}

private func cangjieHumanEvalGateObjectBool(object: JsonObject, field: String): Bool {
    match (object.get(field)) {
        case Some(value) => value.asBool().getValue()
        case None => throw Exception("missing result bool")
    }
}

private func cangjieHumanEvalGateJsonStringArray(values: ArrayList<String>): String {
    var out = ""
    for (i in 0..values.size) {
        if (i > 0) { out += "," }
        out += "\"${cangjieHumanEvalGateJsonEscape(values[i])}\""
    }
    out
}

private func cangjieHumanEvalGateJsonEscape(raw: String): String {
    raw.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
}

private func cangjieHumanEvalGateJoin(values: ArrayList<String>, separator: String): String {
    var out = ""
    for (i in 0..values.size) {
        if (i > 0) { out += separator }
        out += values[i]
    }
    out
}

private func cangjieHumanEvalGateCompactRaw(raw: String): String {
    let trimmed = raw.trimAscii().replace("\n", " ").replace("\r", " ")
    let runes = trimmed.toRuneArray()
    if (runes.size <= 80) {
        return trimmed
    }
    let out = StringBuilder()
    for (i in 0..80) {
        out.append(runes[i])
    }
    out.toString() + "..."
}

private func cangjieHumanEvalGateEscapeMarkdown(raw: String): String {
    raw.replace("|", "\\|")
}
