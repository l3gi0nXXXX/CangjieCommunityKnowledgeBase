package cangjie_community_knowledge_base

import std.collection.ArrayList

public func ckbSchedulerRunOutputJson(result: SchedulerExecutorResult): String {
    let businessOk = result.failed == 0 && result.degraded == 0
    let ok = businessOk && result.finalizationOk
    let failedTasks = ArrayList<CkbSchedulerFailedTaskSummary>()
    if (!businessOk) {
        for (summary in ckbSchedulerFailureSummaries(result)) {
            failedTasks.add(summary)
        }
    }
    "{\"ok\":${ok},\"businessOk\":${businessOk},\"finalizationOk\":${result.finalizationOk},\"errorCode\":\"${ckbSchedulerRunOutputErrorCode(businessOk, result.finalizationOk)}\",\"runId\":\"${ckbSchedulerRunOutputJsonEscape(result.runId)}\",\"progressPath\":\"${ckbSchedulerRunOutputJsonEscape(result.progressPath)}\",\"startedAtMillis\":${result.startedAtMillis},\"endedAtMillis\":${result.endedAtMillis},\"timedOut\":${result.timedOut},\"partial\":${result.partial},\"ran\":${result.ran},\"succeeded\":${result.succeeded},\"failed\":${result.failed},\"degraded\":${result.degraded},\"forced\":${result.forced},\"buildCommit\":\"${ckbSchedulerRunOutputJsonEscape(result.buildCommit)}\",\"configHash\":\"${ckbSchedulerRunOutputJsonEscape(result.configHash)}\",\"storeHash\":\"${ckbSchedulerRunOutputJsonEscape(result.storeHash)}\",\"taskNames\":${ckbSchedulerRunOutputStringArrayJson(result.taskNames)},\"tasks\":${ckbSchedulerRunTaskRecordsJson(result.taskRecords)},\"details\":\"${ckbSchedulerRunOutputJsonEscape(result.details)}\",\"validationSummaries\":${ckbSchedulerRunOutputStringArrayJson(result.validationSummaries)},\"validationDiagnostics\":${ckbSchedulerRunOutputStringArrayJson(result.validationDiagnostics)},\"validationEvidenceHashes\":${ckbSchedulerRunOutputStringArrayJson(result.validationEvidenceHashes)},\"schedulerSaved\":${result.schedulerSaved},\"loopMetadataSaved\":${result.loopMetadataSaved},\"lockReleased\":${result.lockReleased},\"jsonPrinted\":${result.jsonPrinted},\"schedulerSaveStatus\":\"${ckbSchedulerRunOutputJsonEscape(result.schedulerSaveStatus)}\",\"loopMetadataStatus\":\"${ckbSchedulerRunOutputJsonEscape(result.loopMetadataStatus)}\",\"lockReleaseStatus\":\"${ckbSchedulerRunOutputJsonEscape(result.lockReleaseStatus)}\",\"jsonReadyAtMillis\":${result.jsonReadyAtMillis},\"finalizationDiagnostics\":${ckbSchedulerRunOutputStringArrayJson(result.finalizationDiagnostics)},\"finalPreflightOk\":${result.finalPreflightOk},\"finalPreflightDiagnostics\":${ckbSchedulerRunOutputStringArrayJson(result.finalPreflightDiagnostics)},\"postRepairAttempted\":${result.postRepairAttempted},\"postRepairOk\":${result.postRepairOk},\"failedTasks\":${ckbSchedulerRunOutputFailedTasksJson(failedTasks)}}"
}

public func ckbSchedulerRunOutputErrorCode(businessOk: Bool, finalizationOk: Bool): String {
    if (businessOk && finalizationOk) {
        return ""
    }
    if (!businessOk) {
        return "ckb.scheduler_run_degraded"
    }
    "ckb.scheduler_finalization_failed"
}

private func ckbSchedulerRunOutputFailedTasksJson(values: ArrayList<CkbSchedulerFailedTaskSummary>): String {
    var out = "["
    for (i in 0..values.size) {
        if (i > 0) {
            out += ","
        }
        let summary = values[i]
        out += "{\"taskName\":\"${ckbSchedulerRunOutputJsonEscape(summary.taskName)}\",\"status\":\"${ckbSchedulerRunOutputJsonEscape(summary.status)}\",\"primaryFailure\":\"${ckbSchedulerRunOutputJsonEscape(summary.primaryFailure)}\",\"failedSources\":${ckbSchedulerRunOutputStringArrayJson(summary.failedSources)},\"missingArtifacts\":${ckbSchedulerRunOutputStringArrayJson(summary.missingArtifacts)}}"
    }
    out + "]"
}

private func ckbSchedulerRunOutputStringArrayJson(values: ArrayList<String>): String {
    var out = "["
    for (i in 0..values.size) {
        if (i > 0) {
            out += ","
        }
        out += "\"${ckbSchedulerRunOutputJsonEscape(values[i])}\""
    }
    out + "]"
}

private func ckbSchedulerRunOutputJsonEscape(raw: String): String {
    redactSensitive(raw).replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
}
