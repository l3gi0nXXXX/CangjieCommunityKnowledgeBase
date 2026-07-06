package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{File, Path, exists}

public class CkbLandingCapabilityStatus {
    public var id: String = ""
    public var status: String = "missing"
    public var diagnostic: String = ""
    public var evidence: String = ""

    public init() {}
}

public class CkbLandingStatusReport {
    public var ok: Bool = false
    public var overallStatus: String = "missing"
    public var activeKnowledgeVersion: String = ""
    public var capabilities: ArrayList<CkbLandingCapabilityStatus> = ArrayList<CkbLandingCapabilityStatus>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public func collectCkbLandingStatus(service: CkbCommandLoopService): CkbLandingStatusReport {
    collectCkbLandingStatusWithArtifacts(service, "")
}

public func collectCkbLandingStatusWithArtifacts(service: CkbCommandLoopService, runRoot: String): CkbLandingStatusReport {
    let report = CkbLandingStatusReport()
    let status = service.statusSnapshot()
    report.activeKnowledgeVersion = status.activeKnowledgeVersion
    report.capabilities.add(ckbLandingFirstInitStatus(status))
    report.capabilities.add(ckbLandingTaskPackStatus(service))
    report.capabilities.add(ckbLandingSchedulerStatus(status))
    report.capabilities.add(ckbLandingRouteContractStatus(service))
    report.capabilities.add(ckbLandingPass1GateStatus(runRoot))
    ckbLandingFinalize(report)
    report
}

public func renderCkbLandingStatusJson(report: CkbLandingStatusReport): String {
    var capabilities = ""
    for (i in 0..report.capabilities.size) {
        if (i > 0) {
            capabilities += ","
        }
        let item = report.capabilities[i]
        capabilities += "{\"id\":\"${ckbLandingJsonEscape(item.id)}\",\"status\":\"${ckbLandingJsonEscape(item.status)}\",\"diagnostic\":\"${ckbLandingJsonEscape(item.diagnostic)}\",\"evidence\":\"${ckbLandingJsonEscape(item.evidence)}\"}"
    }
    "{\"ok\":${report.ok},\"overallStatus\":\"${ckbLandingJsonEscape(report.overallStatus)}\",\"activeKnowledgeVersion\":\"${ckbLandingJsonEscape(report.activeKnowledgeVersion)}\",\"capabilities\":[${capabilities}],\"diagnostics\":${ckbLandingStringArrayJson(report.diagnostics)}}"
}

public func renderCkbLandingStatusMarkdown(report: CkbLandingStatusReport): String {
    let out = StringBuilder()
    out.append("ckb landing status=${report.overallStatus} ok=${report.ok} activeKnowledgeVersion=${report.activeKnowledgeVersion}\n")
    for (item in report.capabilities) {
        out.append("capability ${item.id} status=${item.status} diagnostic=${item.diagnostic} evidence=${item.evidence}\n")
    }
    for (diagnostic in report.diagnostics) {
        out.append("diagnostic=${diagnostic}\n")
    }
    out.toString()
}

private func ckbLandingFirstInitStatus(status: KnowledgeStatus): CkbLandingCapabilityStatus {
    let item = ckbLandingCapability("F1-first-initialization")
    item.evidence = "raw=${status.storage.rawCount},normalized=${status.storage.normalizedCount},activeStateSource=${status.activeStateSource}"
    if (status.activeStateSource == "first_initialization" && status.storage.rawCount > 0 && status.storage.normalizedCount > 0) {
        item.status = "landed"
        item.diagnostic = "first_initialization_active"
    } else if (status.storage.rawCount > 0 || status.storage.normalizedCount > 0) {
        item.status = "partial"
        item.diagnostic = "active_store_present_but_not_first_initialization"
    } else {
        item.status = "missing"
        item.diagnostic = "active_store_missing"
    }
    item
}

private func ckbLandingTaskPackStatus(service: CkbCommandLoopService): CkbLandingCapabilityStatus {
    let item = ckbLandingCapability("F3-task-pack-evidence")
    let request = CangjieTaskKnowledgeRequest()
    request.taskId = "landing-status-probe"
    request.benchmark = "landing-status"
    request.taskText = "Use ArrayList.add and String.contains in Cangjie."
    request.expectedKnowledgeTags.add("collection-api")
    request.expectedKnowledgeTags.add("string-api")
    let pack = service.cangjieTaskKnowledgePack(request)
    item.evidence = "coveragePass=${pack.coverage.coveragePass},notes=${pack.notes.size},diagnostics=${pack.diagnostics.size}"
    if (pack.notes.contains("task_knowledge_contract_skeleton") || pack.notes.contains("evidence_retrieval_deferred_to_p2_p4")) {
        item.status = "partial"
        item.diagnostic = "skeleton_contract_detected"
    } else if (pack.coverage.coveragePass && !pack.degraded) {
        item.status = "landed"
        item.diagnostic = "evidence_backed_task_pack"
    } else {
        item.status = "missing"
        item.diagnostic = "task_pack_not_evidence_backed"
    }
    item
}

private func ckbLandingSchedulerStatus(status: KnowledgeStatus): CkbLandingCapabilityStatus {
    let item = ckbLandingCapability("F5-routine-update-scheduler")
    var successCount: Int64 = 0
    var requestCount: Int64 = 0
    var validationFailure = ""
    for (entry in status.schedules) {
        if (entry.lastSuccessAt > 0) {
            successCount += 1
        }
        requestCount += entry.lastRequestCount
        if (entry.lastStatus == "candidate_validation_failed") {
            validationFailure = entry.name
        }
    }
    item.evidence = "successCount=${successCount},requestCount=${requestCount},entries=${status.schedules.size}"
    if (validationFailure != "") {
        item.status = "missing"
        item.diagnostic = "candidate_validation_failed:${validationFailure}"
    } else if (successCount > 0 && requestCount > 0) {
        item.status = "landed"
        item.diagnostic = "scheduler_has_successful_update"
    } else if (status.schedules.size > 0) {
        item.status = "missing"
        item.diagnostic = "scheduler_status_missing"
    } else {
        item.status = "missing"
        item.diagnostic = "scheduler_entries_missing"
    }
    item
}

private func ckbLandingRouteContractStatus(service: CkbCommandLoopService): CkbLandingCapabilityStatus {
    let item = ckbLandingCapability("F2-route-contract")
    var passed: Int64 = 0
    let total: Int64 = 15
    if (ckbLandingRouteProbeOk(service, "GET", "/v1/health", "{}", [], "activeKnowledgeVersion")) { passed += 1 }
    if (ckbLandingRouteProbeOk(service, "GET", "/v1/status", "{}", [], "storage")) { passed += 1 }
    if (ckbLandingRouteProbeOk(service, "GET", "/v1/schedules", "{}", [], "entries")) { passed += 1 }
    if (ckbLandingRouteProbeOk(service, "GET", "/v1/schema", "{}", [], "routes")) { passed += 1 }
    if (ckbLandingRouteProbeOk(service, "GET", "/v1/cangjie/corpus/status", "{}", [], "activeKnowledgeVersion")) { passed += 1 }
    if (ckbLandingRouteProbeOk(service, "POST", "/v1/cangjie/task-knowledge-pack", ckbLandingTaskContextJson(), [], "versionResolution")) { passed += 1 }
    if (ckbLandingRouteProbeOk(service, "POST", "/v1/cangjie/knowledge-coverage", ckbLandingTaskContextJson(), [], "coveragePass")) { passed += 1 }
    if (ckbLandingRouteProbeOk(service, "POST", "/v1/cangjie/compile-diagnose-v2", "{\"compilerOutput\":\"unknown symbol ArrayList.add\",\"targetVersion\":\"1.0.0\",\"budget\":3}", [], "versionResolution")) { passed += 1 }
    if (ckbLandingRouteProbeOk(service, "POST", "/v1/cangjie/symbol-lookup", "{\"symbol\":\"ArrayList.add\",\"sourceSet\":\"std\",\"targetVersion\":\"1.0.0\"}", [], "resultType")) { passed += 1 }
    if (ckbLandingRouteProbeOk(service, "POST", "/v1/cangjie/doc-section", "{\"path\":\"dev-guide/source_en/api/collections.md\",\"targetVersion\":\"1.0.0\"}", [], "resultType")) { passed += 1 }
    if (ckbLandingRouteProbeOk(service, "GET", "/v1/cangjie/corpus/freshness", "{}", [], "resultType")) { passed += 1 }
    if (ckbLandingRouteProbeOk(service, "POST", "/v1/cangjie/tool-manual", "{\"tool\":\"cjpm\",\"command\":\"test\",\"targetVersion\":\"1.0.0\"}", [], "resultType")) { passed += 1 }
    if (ckbLandingRouteProbeOk(service, "POST", "/v1/cangjie/negative-rules", "{\"q\":\"ArrayList.add\",\"targetVersion\":\"1.0.0\"}", [], "resultType")) { passed += 1 }
    if (ckbLandingRouteProbeOk(service, "POST", "/v1/evidence-pack", "{\"q\":\"ArrayList.add\",\"budget\":3}", [], "knowledgeVersion")) { passed += 1 }
    if (ckbLandingRouteProbeOk(service, "POST", "/v1/admin/initialize", "{\"dryRun\":true}", ["X-CKB-Admin-Token: landing-status"], "activeKnowledgeVersion")) { passed += 1 }
    item.evidence = "passed=${passed},total=${total}"
    if (passed == total) {
        item.status = "landed"
        item.diagnostic = "route_contract_probe_passed"
    } else {
        item.status = "partial"
        item.diagnostic = "route_contract_probe_failed:${passed}/${total}"
    }
    item
}

private func ckbLandingPass1GateStatus(runRoot: String): CkbLandingCapabilityStatus {
    let item = ckbLandingCapability("F8-humaneval-pass1-gate")
    if (runRoot.trimAscii() == "") {
        item.status = "missing"
        item.diagnostic = "pass1_gate_result_missing"
        item.evidence = "runRoot=absent"
        return item
    }
    let jsonPath = Path(runRoot).join("pass1-gate.json")
    let markdownPath = Path(runRoot).join("pass1-gate.md")
    if (exists(jsonPath)) {
        let text = ckbLandingReadText(jsonPath)
        item.evidence = "artifact=pass1-gate.json"
        if (text.contains("\"releaseGate\":\"pass\"") || text.contains("\"ok\":true")) {
            item.status = "landed"
            item.diagnostic = "pass1_gate_passed"
        } else {
            item.status = "missing"
            item.diagnostic = "pass1_gate_failed"
        }
        return item
    }
    if (exists(markdownPath)) {
        let text = ckbLandingReadText(markdownPath)
        item.evidence = "artifact=pass1-gate.md"
        if (text.contains("- releaseGate: pass")) {
            item.status = "landed"
            item.diagnostic = "pass1_gate_passed"
        } else {
            item.status = "missing"
            item.diagnostic = "pass1_gate_failed"
        }
        return item
    }
    item.status = "missing"
    item.diagnostic = "pass1_gate_result_missing"
    item.evidence = "artifact=absent"
    item
}

private func ckbLandingRouteProbeOk(service: CkbCommandLoopService, method: String, path: String, body: String, headers: Array<String>, expected: String): Bool {
    let response = ckbApiHandle(service, method, path, body, headers)
    if (response.contains("\"code\":\"ckb.not_found\"") || response.contains("\"code\":\"ckb.method_not_allowed\"") || response.contains("\"status\":404")) {
        return false
    }
    expected == "" || response.contains(expected)
}

private func ckbLandingTaskContextJson(): String {
    "{\"taskId\":\"landing-status\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"Implement a Cangjie ArrayList helper.\",\"signature\":\"func solution(values: Array<Int64>): Int64\",\"imports\":[],\"argTypes\":[\"Array<Int64>\"],\"returnType\":\"Int64\",\"expectedKnowledgeTags\":[\"ArrayList\",\"Cangjie syntax\"],\"starterCodeExcerpt\":\"\",\"compilerOutput\":\"\",\"targetVersion\":\"1.0.0\",\"sourceSet\":\"all\",\"sourceRef\":\"\",\"versionPolicy\":\"default\",\"budget\":5}"
}

private func ckbLandingReadText(path: Path): String {
    try {
        String.fromUtf8(File.readFrom(path))
    } catch (_: Exception) {
        ""
    }
}

private func ckbLandingFinalize(report: CkbLandingStatusReport): Unit {
    var landed: Int64 = 0
    var partial: Int64 = 0
    var missing: Int64 = 0
    for (item in report.capabilities) {
        if (item.status == "landed") {
            landed += 1
        } else if (item.status == "partial") {
            partial += 1
        } else {
            missing += 1
        }
    }
    report.ok = missing == 0 && partial == 0 && report.capabilities.size > 0
    report.overallStatus = if (report.ok) { "complete" } else if (landed > 0 || partial > 0) { "partial" } else { "missing" }
    report.diagnostics.add("landed=${landed}")
    report.diagnostics.add("partial=${partial}")
    report.diagnostics.add("missing=${missing}")
}

private func ckbLandingCapability(id: String): CkbLandingCapabilityStatus {
    let item = CkbLandingCapabilityStatus()
    item.id = id
    item
}

private func ckbLandingStringArrayJson(values: ArrayList<String>): String {
    var out = "["
    for (i in 0..values.size) {
        if (i > 0) {
            out += ","
        }
        out += "\"${ckbLandingJsonEscape(values[i])}\""
    }
    out + "]"
}

private func ckbLandingJsonEscape(raw: String): String {
    let text = redactSensitive(raw)
    let out = StringBuilder()
    for (ch in text.toRuneArray()) {
        if (ch == r'"') {
            out.append("\\\"")
        } else if (ch == r'\\') {
            out.append("\\\\")
        } else if (ch == r'\n') {
            out.append("\\n")
        } else if (ch == r'\r') {
            out.append("\\r")
        } else if (ch == r'\t') {
            out.append("\\t")
        } else {
            out.append(ch)
        }
    }
    out.toString()
}
