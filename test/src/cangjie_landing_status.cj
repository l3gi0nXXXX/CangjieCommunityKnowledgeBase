package cangjie_community_knowledge_base_test

import std.collection.ArrayList

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
    let report = CkbLandingStatusReport()
    let status = service.statusSnapshot()
    report.activeKnowledgeVersion = status.activeKnowledgeVersion
    report.capabilities.add(ckbLandingFirstInitStatus(status))
    report.capabilities.add(ckbLandingTaskPackStatus(service))
    report.capabilities.add(ckbLandingSchedulerStatus(status))
    report.capabilities.add(ckbLandingRouteContractStatus())
    report.capabilities.add(ckbLandingPass1GateStatus())
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
    for (entry in status.schedules) {
        if (entry.lastSuccessAt > 0) {
            successCount += 1
        }
        requestCount += entry.lastRequestCount
    }
    item.evidence = "successCount=${successCount},requestCount=${requestCount},entries=${status.schedules.size}"
    if (successCount > 0 && requestCount > 0) {
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

private func ckbLandingRouteContractStatus(): CkbLandingCapabilityStatus {
    let item = ckbLandingCapability("F2-route-contract")
    item.status = "partial"
    item.diagnostic = "route_probe_required"
    item.evidence = "schema_routes_declared_but_runtime_probe_required"
    item
}

private func ckbLandingPass1GateStatus(): CkbLandingCapabilityStatus {
    let item = ckbLandingCapability("F8-humaneval-pass1-gate")
    item.status = "missing"
    item.diagnostic = "pass1_gate_result_missing"
    item.evidence = "C/D full 164/164 pass@1 not recorded by landing status"
    item
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
