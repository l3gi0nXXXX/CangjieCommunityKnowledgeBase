package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashSet}
import std.fs.{Directory, File, Path, exists}
import std.process.launch
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
    public var route: String = ""
    public var firstCategory: String = ""
    public var secondCategory: String = ""
    public var nonKnowledgeRouteConsensus: Bool = false
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
    public var classifierFirstCategory: String = ""
    public var classifierSecondCategory: String = ""
    public var nonKnowledgeRouteConfirmed: Bool = false
    public var routeEvidenceHash: String = ""
    public init() {}
}

public class CangjieEvalDevelopmentClosureInput {
    public var caseResultJson: String = ""
    public var resultEvidenceJson: String = ""
    public var firstClassifierJson: String = ""
    public var secondClassifierJson: String = ""
    public var taskText: String = ""
    public var failureSummary: String = ""
    public var gapCode: String = "G-STRING"
    public var interfaceId: String = "KI-02"
    public var contentFamily: String = "KC-02"
    public var targetVersion: String = "1.0.0"
    public init() {}
}

public class CangjieEvalDevelopmentClosureResult {
    public var ok: Bool = true
    public var developmentClosureJson: String = ""
    public var authoritativeGapJsonl: String = ""
    public var knowledgeGapCount: Int64 = 0
    public var pendingClassifierCount: Int64 = 0
    public var diagnostics: ArrayList<String> = ArrayList<String>()
    public init() {}
}

public func ckbAbcdeProviderIdentityJson(observedModel: String, claudeCodeVersion: String): String {
    if (observedModel != "GLM-5.2" || claudeCodeVersion.trimAscii() == "") { return "" }
    "{\"schemaVersion\":\"ckb-provider-identity-v1\",\"provider\":\"claude-code-runtime\",\"model\":\"${triageJsonEscape(observedModel)}\",\"claudeCodeVersion\":\"${triageJsonEscape(claudeCodeVersion)}\"}\n"
}

public func aggregateDevelopmentRun(options: CkbAbcdeRunnerOptions, runRoot: String): CangjieEvalDevelopmentClosureResult {
    let blocked = CangjieEvalDevelopmentClosureResult()
    if (options.groups.size != 1 || (options.groups[0] != CkbAbcdeGroups.C && options.groups[0] != CkbAbcdeGroups.D)) {
        blocked.ok = false; blocked.diagnostics.add("single_treatment_transport_required"); return blocked
    }
    let inputs = ArrayList<CangjieEvalDevelopmentClosureInput>()
    let group = options.groups[0]
    for (i in 0..164) {
        let id = triageCaseId(i)
        let root = Path(runRoot).join("cases").join(id).join(group)
        let input = CangjieEvalDevelopmentClosureInput()
        input.caseResultJson = triageReadText(root.join("case-result.json"))
        input.resultEvidenceJson = triageReadText(root.join("result-evidence.json"))
        input.firstClassifierJson = triageReadText(root.join("classifier-1.json"))
        input.secondClassifierJson = triageReadText(root.join("classifier-2.json"))
        input.taskText = "authority-bound:${id}"
        let evidenceObject=try{JsonValue.fromStr(input.resultEvidenceJson.trimAscii()).asObject()}catch(_:Exception){JsonObject()}
        input.failureSummary=ckbP5CompilerSummary(triageReadText(root.join("test.log")),triageJsonString(evidenceObject,"failureType"))
        inputs.add(input)
    }
    let out = orchestrateDevelopmentClosure(inputs, options.runId)
    if (inputs.size != 164) { out.ok = false; out.diagnostics.add("development_case_count_mismatch") }
    let closurePath = Path(runRoot).join("development-closure.json")
    let gapPath = Path(runRoot).join("authority-gap.jsonl")
    File.writeTo(closurePath, out.developmentClosureJson.toArray())
    File.writeTo(gapPath, out.authoritativeGapJsonl.toArray())
    out
}

public func runCangjieEvalDevelopmentClose(args: Array<String>): Int64 {
    var runRoot = ""; var runId = ""; var transport = ""; var firstRoot = ""; var secondRoot = ""; var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "cangjie-eval-development-close") { i += 1; continue }
        if ((arg == "--run-root" || arg == "--run-id" || arg == "--transport" || arg == "--classifier-a-root" || arg == "--classifier-b-root") && i + 1 < args.size) {
            let value = args[i + 1].trimAscii()
            if (arg == "--run-root") { runRoot = value } else if (arg == "--run-id") { runId = value } else if (arg == "--transport") { transport = value } else if (arg == "--classifier-a-root") { firstRoot = value } else { secondRoot = value }
            i += 2; continue
        }
        println("usage error: invalid cangjie-eval-development-close argument"); return 2
    }
    if (runRoot == "" || runId == "" || firstRoot == "" || secondRoot == "" || (transport != "C" && transport != "D")) {
        println("usage error: development close requires --run-root --run-id --transport C|D --classifier-a-root --classifier-b-root"); return 2
    }
    let group = if (transport == "C") { CkbAbcdeGroups.C } else { CkbAbcdeGroups.D }
    for (caseIndex in 0..164) {
        let id = triageCaseId(caseIndex); let first = Path(firstRoot).join("${id}.json"); let second = Path(secondRoot).join("${id}.json")
        if (!exists(first) && !exists(second)) { continue }
        if (!exists(first) || !exists(second)) { println("development close blocked: classifier pair incomplete"); return 1 }
        let firstText = triageReadText(first); let secondText = triageReadText(second); let confirmation = confirmIndependentClassifierPair(firstText, secondText)
        if (!confirmation.confirmed) { println("development close blocked: classifier evidence invalid"); return 1 }
        let target = Path(runRoot).join("cases").join(id).join(group)
        if (!exists(target)) { println("development close blocked: case result missing"); return 1 }
        if (!triageAtomicWrite(target.join("classifier-1.json"), firstText) || !triageAtomicWrite(target.join("classifier-2.json"), secondText)) { println("development close blocked: classifier injection failed"); return 1 }
    }
    let options = CkbAbcdeRunnerOptions(); options.runId = runId; options.groups.clear(); options.groups.add(group)
    let aggregate = aggregateDevelopmentRun(options, runRoot)
    if (!aggregate.ok || aggregate.pendingClassifierCount > 0) { println("development close blocked diagnostics=${aggregate.diagnostics.size} pending=${aggregate.pendingClassifierCount}"); return 1 }
    println("development close written total=164 knowledgeGaps=${aggregate.knowledgeGapCount}"); 0
}

public func runCangjieEvalSingleCaseClose(args: Array<String>): Int64 {
    var caseRoot="";var firstPath="";var secondPath="";var teacherRunId="";var outputRoot=""
    var gapCode="";var interfaceId="";var contentFamily="";var targetVersion="";var i:Int64=0
    while(i<args.size){
        let arg=args[i];if(arg=="cangjie-eval-case-close"){i+=1;continue}
        let known=arg=="--case-root"||arg=="--classifier-a"||arg=="--classifier-b"||arg=="--teacher-run-id"||arg=="--output-root"||arg=="--gap-code"||arg=="--interface-id"||arg=="--content-family"||arg=="--target-version"
        if(!known||i+1>=args.size){println("usage error: invalid cangjie-eval-case-close argument");return 2}
        let value=args[i+1].trimAscii();if(value==""){println("usage error: empty cangjie-eval-case-close value");return 2}
        if(arg=="--case-root"){caseRoot=value}else if(arg=="--classifier-a"){firstPath=value}else if(arg=="--classifier-b"){secondPath=value}else if(arg=="--teacher-run-id"){teacherRunId=value}else if(arg=="--output-root"){outputRoot=value}else if(arg=="--gap-code"){gapCode=value}else if(arg=="--interface-id"){interfaceId=value}else if(arg=="--content-family"){contentFamily=value}else{targetVersion=value};i+=2
    }
    var missing=false;for(v in [caseRoot,firstPath,secondPath,teacherRunId,outputRoot,gapCode,interfaceId,contentFamily,targetVersion]){if(v==""){missing=true}}
    if(missing){
        println("usage error: cangjie-eval-case-close requires all authority arguments");return 2
    }
    if(!triageSingleCasePathAllowed(caseRoot)||!triageSingleCasePathAllowed(firstPath)||!triageSingleCasePathAllowed(secondPath)||!triageSingleCasePathAllowed(outputRoot)||exists(Path(outputRoot))){
        println("case close blocked diagnostic=path_boundary_invalid");return 1
    }
    let caseResult=triageReadText(Path(caseRoot).join("case-result.json"));let evidence=triageReadText(Path(caseRoot).join("result-evidence.json"))
    let first=triageReadText(Path(firstPath));let second=triageReadText(Path(secondPath));let context=triageReadText(Path(caseRoot).join("canonical-task-context.json"))
    if(caseResult==""||evidence==""||first==""||second==""||context==""){println("case close blocked diagnostic=authority_input_missing_or_invalid_encoding");return 1}
    let taskText=try{triageJsonString(JsonValue.fromStr(context).asObject(),"taskText")}catch(_:Exception){""}
    if(taskText==""){println("case close blocked diagnostic=task_context_invalid");return 1}
    let input=CangjieEvalDevelopmentClosureInput();input.caseResultJson=caseResult;input.resultEvidenceJson=evidence;input.firstClassifierJson=first;input.secondClassifierJson=second;input.taskText=taskText
    let failureType=try{triageJsonString(JsonValue.fromStr(evidence).asObject(),"failureType")}catch(_:Exception){""};input.failureSummary=ckbP5CompilerSummary(triageReadText(Path(caseRoot).join("test.log")),failureType)
    input.gapCode=gapCode;input.interfaceId=interfaceId;input.contentFamily=contentFamily;input.targetVersion=targetVersion
    let inputs=ArrayList<CangjieEvalDevelopmentClosureInput>();inputs.add(input);let closure=orchestrateDevelopmentClosure(inputs,teacherRunId)
    if(!closure.ok||closure.knowledgeGapCount!=1||closure.pendingClassifierCount!=0||closure.diagnostics.size!=0||closure.authoritativeGapJsonl.trimAscii()==""){
        println("case close blocked diagnostic=authority_confirmation_failed");return 1
    }
    let stage=outputRoot+".tmp-"+benchmarkGapSha256(closure.authoritativeGapJsonl).replace("sha256:","")
    try{
        if(exists(Path(stage))){_=launch("/bin/rm",["-rf",stage]).wait()};Directory.create(Path(stage),recursive:true)
        if(!triageAtomicWrite(Path(stage).join("development-closure.json"),closure.developmentClosureJson+"\n")||!triageAtomicWrite(Path(stage).join("authority-gap.jsonl"),closure.authoritativeGapJsonl)){throw IllegalStateException("write_failed")}
        if(launch("/bin/mv",[stage,outputRoot]).wait()!=0){throw IllegalStateException("publish_failed")}
    }catch(_:Exception){try{_=launch("/bin/rm",["-rf",stage]).wait()}catch(_:Exception){};println("case close blocked diagnostic=atomic_publish_failed");return 1}
    println("case close written knowledgeGaps=1");0
}

private func triageSingleCasePathAllowed(value:String):Bool{
    let lower=value.toAsciiLower();value.startsWith("/")&&!value.contains("..")&&!lower.contains("/ckb-data")&&!lower.contains("/teacher-solutions")&&!lower.contains("/reference/")&&!lower.contains("/hidden/")
}

private func triageAtomicWrite(path: Path, text: String): Bool {
    let tmpId = benchmarkGapSha256(path.toString() + text).replace("sha256:", "")
    let tmp = path.parent.join(".tmp-${tmpId}")
    try { File.writeTo(tmp, text.toArray()); if (triageReadText(tmp) != text) { _ = launch("/bin/rm", ["-f", tmp.toString()]).wait(); return false }; launch("/bin/mv", ["-f", tmp.toString(), path.toString()]).wait() == 0 } catch (_: Exception) { try { _ = launch("/bin/rm", ["-f", tmp.toString()]).wait() } catch (_: Exception) {}; false }
}

private func triageReadText(path: Path): String {
    if (!exists(path)) { return "" }
    try { String.fromUtf8(File.readFrom(path)) } catch (_: Exception) { "" }
}
private func triageCaseId(index: Int64): String {
    if (index < 10) { return "CJ-HUMANEVAL-00${index}" }
    if (index < 100) { return "CJ-HUMANEVAL-0${index}" }
    "CJ-HUMANEVAL-${index}"
}

public func orchestrateDevelopmentClosure(inputs: ArrayList<CangjieEvalDevelopmentClosureInput>, teacherRunId: String): CangjieEvalDevelopmentClosureResult {
    let output = CangjieEvalDevelopmentClosureResult()
    let closures = ArrayList<CangjieEvalDevelopmentCaseClosure>()
    let workspaces = HashSet<String>(); let sessions = HashSet<String>(); let runtimeHomes = HashSet<String>()
    for (input in inputs) {
        let closure = CangjieEvalDevelopmentCaseClosure()
        try {
            let row = JsonValue.fromStr(input.caseResultJson.trimAscii()).asObject()
            closure.caseId = triageJsonString(row, "caseId")
            let runId = triageJsonString(row, "runId")
            let datasetVersion = triageJsonString(row, "datasetVersion")
            let mode = triageJsonString(row, "runMode").toAsciiLower()
            let workspace = triageJsonString(row, "workspaceId"); let session = triageJsonString(row, "sessionId"); let runtimeHome = triageJsonString(row, "runtimeHomeId")
            let certUnset = match (row.get("certificationPassAt1")) { case Some(value) => value.toString() == "null"; case None => false }
            if (closure.caseId == "" || runId == "" || datasetVersion == "" || mode != "development" || workspace == "" || session == "" || runtimeHome == "" || !certUnset) {
                throw IllegalArgumentException("case_result_contract_invalid")
            }
            if (workspaces.contains(workspace) || sessions.contains(session) || runtimeHomes.contains(runtimeHome)) {
                output.ok = false; output.diagnostics.add("duplicate_isolation_identity:${closure.caseId}"); closure.category = "runner_failure"; closure.route = "runner"; closures.add(closure); continue
            }
            workspaces.add(workspace); sessions.add(session); runtimeHomes.add(runtimeHome)
            let triage = triageEvalFailure(input.resultEvidenceJson)
            if (!triage.ok) { throw IllegalArgumentException("triage:${triage.diagnostic}") }
            let evidence = JsonValue.fromStr(input.resultEvidenceJson.trimAscii()).asObject()
            if (triageJsonString(evidence, "caseId") != closure.caseId || triageJsonString(evidence, "runId") != runId || triageJsonString(evidence, "datasetVersion") != datasetVersion) {
                throw IllegalArgumentException("result_evidence_identity_mismatch")
            }
            closure.category = triage.category; closure.route = triage.route
            closure.developmentPass = triage.category == "none" && triageJsonBool(row, "developmentPass")
            if (triage.category != "none") {
                if (input.firstClassifierJson.trimAscii() == "" || input.secondClassifierJson.trimAscii() == "") {
                    output.pendingClassifierCount += 1
                } else {
                    let confirmation = confirmIndependentClassifierPair(input.firstClassifierJson, input.secondClassifierJson)
                    if (confirmation.confirmed) {
                        closure.category = confirmation.category; closure.route = confirmation.route
                        closure.classifierFirstCategory = confirmation.firstCategory; closure.classifierSecondCategory = confirmation.secondCategory
                        if (confirmation.category == "knowledge_gap") {
                            closure.knowledgeGapConfirmed = true; closure.confirmationEvidenceHash = confirmation.evidenceHash
                            let gap = cangjieEvalConfirmedGapInput(input, closure.caseId, datasetVersion, teacherRunId, confirmation)
                            output.authoritativeGapJsonl += renderAuthoritativeBenchmarkGapInput(gap) + "\n"; output.knowledgeGapCount += 1
                        } else {
                            closure.nonKnowledgeRouteConfirmed = true; closure.routeEvidenceHash = confirmation.evidenceHash
                        }
                    } else { output.diagnostics.add("classifier:${closure.caseId}:${confirmation.diagnostic}") }
                }
            }
        } catch (error: Exception) {
            output.ok = false; output.diagnostics.add("case:${closure.caseId}:${utf8SafePrefix(error.message, 120)}")
        }
        closures.add(closure)
    }
    output.developmentClosureJson = renderDevelopmentClosure(closures)
    output
}

private func cangjieEvalConfirmedGapInput(source: CangjieEvalDevelopmentClosureInput, caseId: String, datasetVersion: String, teacherRunId: String, confirmation: CangjieEvalKnowledgeGapConfirmation): CangjieBenchmarkGapInput {
    let input = CangjieBenchmarkGapInput()
    input.schemaVersion = "ckb-benchmark-gap-v1"; input.datasetVersion = datasetVersion; input.teacherRunId = teacherRunId
    input.candidatePath = "authority/benchmark-gap.jsonl"; input.revision = 1; input.attempt = 1; input.failureTaxonomy = "knowledge_gap"; input.knowledgeGapConfirmations = 2
    input.caseId = caseId; input.taskText = source.taskText; input.compilerOutput = if(source.failureSummary==""){"knowledge_gap"}else{source.failureSummary}; input.missingKnowledge = source.gapCode
    input.interfaceId = source.interfaceId; input.contentFamily = source.contentFamily; input.updateMechanism = "KU-11"; input.targetVersion = source.targetVersion
    input.officialCitation = "https://docs.cangjie-lang.cn/docs/1.0.0/"
    input.evidence = "case=${caseId}|taxonomy=knowledge_gap|independentClassifierEvidence=${confirmation.evidenceHash}|failureSummaryHash=${benchmarkGapSha256(input.compilerOutput)}"
    input.evidenceHash = benchmarkGapSha256(input.evidence); input.candidateHash = canonicalBenchmarkGapCandidateHash(input)
    input
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

public func confirmIndependentClassifierPair(firstJson: String, secondJson: String): CangjieEvalKnowledgeGapConfirmation {
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
        if (firstId == "" || secondId == "" || firstId == secondId || firstSource == "" || secondSource == "" || firstSource == secondSource ||
            triageJsonString(first,"provider")==triageJsonString(second,"provider") || triageJsonString(first,"provenanceHash")==triageJsonString(second,"provenanceHash")) {
            result.diagnostic = "independent_classifier_required"; return result
        }
        if (!triageClassifierContractValid(first) || !triageClassifierContractValid(second) ||
            !ckbP5ClassifierArtifactIdentityValid(firstJson) || !ckbP5ClassifierArtifactIdentityValid(secondJson)) {
            result.diagnostic = "classifier_field_contract_invalid"; return result
        }
        let firstHash = triageJsonString(first, "evidenceHash")
        let secondHash = triageJsonString(second, "evidenceHash")
        let firstConsensus = triageJsonString(first,"consensusHash");let secondConsensus=triageJsonString(second,"consensusHash")
        if (firstHash == "" || secondHash == "" || firstHash == secondHash) {
            result.diagnostic = "classifier_evidence_hash_mismatch"; return result
        }
        if (firstConsensus == "" || secondConsensus == "" ||
            firstConsensus != ckbP5ClassifierArtifactConsensusHash(firstJson) || secondConsensus != ckbP5ClassifierArtifactConsensusHash(secondJson)) {
            result.diagnostic = "classifier_consensus_hash_invalid"; return result
        }
        let firstCategory = triageJsonString(first, "category").toAsciiLower()
        let secondCategory = triageJsonString(second, "category").toAsciiLower()
        if (triageJsonInt(first, "attempt", -1) != 1 || triageJsonInt(second, "attempt", -1) != 1 ||
            triageJsonString(first, "runMode").toAsciiLower() != "development" || triageJsonString(second, "runMode").toAsciiLower() != "development") {
            result.diagnostic = "development_first_attempt_required"; return result
        }
        result.firstCategory = firstCategory; result.secondCategory = secondCategory
        if (secondCategory != firstCategory) {
            let firstRoute = routeNonKnowledgeFailure(firstCategory); let secondRoute = routeNonKnowledgeFailure(secondCategory)
            if (firstCategory == "knowledge_gap" || secondCategory == "knowledge_gap" || firstRoute != secondRoute) {
                result.diagnostic = "classifier_disagreement"; return result
            }
            let firstAgreement = triageClassifierRouteAgreementHash(first, firstRoute)
            let secondAgreement = triageClassifierRouteAgreementHash(second, secondRoute)
            if (firstAgreement != secondAgreement) {
                result.diagnostic = "classifier_semantic_disagreement"; return result
            }
            result.confirmed = true; result.diagnostic = "nonknowledge_route_consensus"; result.category = firstCategory
            result.route = firstRoute; result.nonKnowledgeRouteConsensus = true; result.evidenceHash = firstAgreement
            return result
        }
        let firstAgreement = triageClassifierAgreementHash(first)
        let secondAgreement = triageClassifierAgreementHash(second)
        if (firstAgreement != secondAgreement) {
            result.diagnostic = "classifier_semantic_disagreement"; return result
        }
        if (firstCategory == "knowledge_gap" && (!triageK4Eligible(first) || !triageK4Eligible(second))) {
            result.diagnostic = "knowledge_policy_not_satisfied"; return result
        }
        result.confirmed = true
        result.diagnostic = "ok"
        result.category = firstCategory
        result.route = routeNonKnowledgeFailure(firstCategory)
        result.nonKnowledgeRouteConsensus = firstCategory != "knowledge_gap"
        result.evidenceHash = firstAgreement
    } catch (_: Exception) {
        result.diagnostic = "malformed_classifier_evidence"
    }
    result
}

// Independent classifiers can choose different eligible K4 families and official citation pages
// for the same root cause. Agreement binds the failure identity and publication policy facts;
// Teacher extraction later owns the canonical family, citation and reusable knowledge text.
private func triageClassifierAgreementHash(object: JsonObject): String {
    let canonical = triageCanonicalPart(triageJsonString(object, "category").toAsciiLower()) +
        triageCanonicalPart(triageJsonString(object, "caseId")) +
        triageCanonicalPart(triageJsonString(object, "runId")) +
        triageCanonicalPart(triageJsonString(object, "datasetVersion")) +
        triageCanonicalPart("${triageJsonInt(object, "attempt", -1)}") +
        triageCanonicalPart(triageJsonString(object, "runMode").toAsciiLower()) +
        triageCanonicalPart(triageJsonString(object, "studentSourceHash").toAsciiLower()) +
        triageCanonicalPart(triageJsonString(object, "resultEvidenceHash").toAsciiLower()) +
        triageCanonicalPart(triageJsonString(object, "failureObservation")) +
        triageCanonicalPart("${triageJsonBool(object, "reusable")}") +
        triageCanonicalPart(triageJsonString(object, "sourceClass").toAsciiLower()) +
        triageCanonicalPart("${triageJsonBool(object, "purificationPassed")}") +
        triageCanonicalPart(triageJsonString(object, "targetVersion")) +
        triageCanonicalPart(triageJsonString(object, "evidenceId"))
    triageSha256(canonical)
}

private func triageClassifierRouteAgreementHash(object: JsonObject, route: String): String {
    let canonical = triageCanonicalPart(route) +
        triageCanonicalPart(triageJsonString(object, "caseId")) +
        triageCanonicalPart(triageJsonString(object, "runId")) +
        triageCanonicalPart(triageJsonString(object, "datasetVersion")) +
        triageCanonicalPart("${triageJsonInt(object, "attempt", -1)}") +
        triageCanonicalPart(triageJsonString(object, "runMode").toAsciiLower()) +
        triageCanonicalPart(triageJsonString(object, "studentSourceHash").toAsciiLower()) +
        triageCanonicalPart(triageJsonString(object, "resultEvidenceHash").toAsciiLower()) +
        triageCanonicalPart(triageJsonString(object, "failureObservation"))
    triageSha256(canonical)
}

public func confirmKnowledgeGap(firstJson: String, secondJson: String): CangjieEvalKnowledgeGapConfirmation {
    let result = confirmIndependentClassifierPair(firstJson, secondJson)
    if (result.confirmed && result.category != "knowledge_gap") {
        result.confirmed = false; result.diagnostic = "knowledge_gap_not_confirmed"
    }
    result
}

public func routeNonKnowledgeFailure(category: String): String {
    let value = category.trimAscii().toAsciiLower()
    if (value == "knowledge_gap" || value == "none") { return value }
    if (value == "retrieval_failure") { return "retrieval" }
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
        let routeHashValid = triageSha256Format(item.routeEvidenceHash)
        let invalid = item.caseId.trimAscii() == "" ||
            (item.developmentPass && item.category != "none") ||
            (item.knowledgeGapConfirmed && (item.developmentPass || item.category != "knowledge_gap" || !confirmationHashValid)) ||
            (!item.knowledgeGapConfirmed && item.confirmationEvidenceHash != "") ||
            (item.nonKnowledgeRouteConfirmed && (item.developmentPass || item.knowledgeGapConfirmed || item.route == "knowledge_gap" || item.route == "none" ||
                item.classifierFirstCategory == "" || item.classifierSecondCategory == "" || !routeHashValid)) ||
            (!item.nonKnowledgeRouteConfirmed && item.routeEvidenceHash != "")
        if (invalid) {
            invalidCount += 1
            if (diagnostics != "") { diagnostics += "," }
            diagnostics += "\"case_state_conflict:${triageJsonEscape(item.caseId)}\""
        } else {
            if (item.developmentPass) { passed += 1 }
            if (item.knowledgeGapConfirmed) { knowledgeCandidates += 1 }
        }
        if (i > 0) { rows += "," }
        rows += "{\"caseId\":\"${triageJsonEscape(item.caseId)}\",\"developmentPass\":${item.developmentPass},\"category\":\"${triageJsonEscape(item.category)}\",\"route\":\"${triageJsonEscape(item.route)}\",\"knowledgeGapConfirmed\":${item.knowledgeGapConfirmed},\"confirmationEvidenceHash\":\"${triageJsonEscape(item.confirmationEvidenceHash)}\",\"classifierFirstCategory\":\"${triageJsonEscape(item.classifierFirstCategory)}\",\"classifierSecondCategory\":\"${triageJsonEscape(item.classifierSecondCategory)}\",\"nonKnowledgeRouteConfirmed\":${item.nonKnowledgeRouteConfirmed},\"routeEvidenceHash\":\"${triageJsonEscape(item.routeEvidenceHash)}\",\"valid\":${!invalid}}"
    }
    let closed = cases.size > 0 && invalidCount == 0 && passed == cases.size
    "{\"developmentClosed\":${closed},\"developmentPassed\":${passed},\"developmentTotal\":${cases.size},\"knowledgeCandidateCount\":${knowledgeCandidates},\"invalidCaseCount\":${invalidCount},\"diagnostics\":[${diagnostics}],\"certifiedPassAt1\":null,\"certificationStatus\":\"unset\",\"cases\":[${rows}]}"
}

public func cangjieEvalTriageClassifierEvidenceHash(classifierJson: String): String {
    ckbP5ClassifierArtifactEvidenceHash(classifierJson)
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
        !triageJsonBool(object, "purificationPassed") || triageForbiddenKnowledgeEvidence(object)) { return false }
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
    triageJsonString(object,"schemaVersion")=="ckb-p5-classifier-v1" && triageKnownCategory(triageJsonString(object, "category")) && triageJsonString(object, "caseId") != "" &&
        triageJsonString(object, "runId") != "" && triageJsonString(object, "datasetVersion") != "" &&
        triageJsonInt(object, "attempt", -1) >= 1 && (mode == "development" || mode == "certification") &&
        (triageJsonString(object,"studentSourceHash")==""||triageSha256Format(triageJsonString(object,"studentSourceHash").toAsciiLower())) &&
        triageJsonString(object, "failureObservation") != "" && triageSha256Format(triageJsonString(object, "resultEvidenceHash").toAsciiLower()) &&
        triageSha256Format(triageJsonString(object, "evidenceHash").toAsciiLower())
}
private func triageKnownCategory(category: String): Bool {
    let value = category.toAsciiLower()
    value == "knowledge_gap" || value == "retrieval_failure" || value == "reasoning_failure" || value == "dataset_failure" || value == "runner_failure" ||
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
