package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbSchedulerCliOutputTest {
    @TestCase
    public func cliJsonSuccessIncludesFinalizationAndJsonPrintedFields(): Unit {
        let result = SchedulerExecutorResult()
        result.runId = "run-success"
        result.ran = 1
        result.succeeded = 1
        result.schedulerSaved = true
        result.loopMetadataSaved = true
        result.lockReleased = true
        result.jsonPrinted = true
        result.schedulerSaveStatus = "succeeded"
        result.loopMetadataStatus = "succeeded"
        result.lockReleaseStatus = "succeeded"
        result.jsonReadyAtMillis = 123

        let json = ckbSchedulerRunOutputJson(result)

        @Expect(json.contains("\"ok\":true"), true)
        @Expect(json.contains("\"businessOk\":true"), true)
        @Expect(json.contains("\"finalizationOk\":true"), true)
        @Expect(json.contains("\"errorCode\":\"\""), true)
        @Expect(json.contains("\"schedulerSaved\":true"), true)
        @Expect(json.contains("\"loopMetadataSaved\":true"), true)
        @Expect(json.contains("\"lockReleased\":true"), true)
        @Expect(json.contains("\"jsonPrinted\":true"), true)
        @Expect(json.contains("\"jsonReadyAtMillis\":123"), true)
    }

    @TestCase
    public func cliJsonBusinessFailureKeepsFailedTaskSummary(): Unit {
        let result = SchedulerExecutorResult()
        result.runId = "run-business-failed"
        result.ran = 1
        result.failed = 1
        result.details = "task cangjie_freshness_daily ok=false status=freshness_probe_degraded\n"
        result.validationDiagnostics.add("cangjie_freshness_daily:version_manifest_invalid_encoding")

        let json = ckbSchedulerRunOutputJson(result)

        @Expect(json.contains("\"ok\":false"), true)
        @Expect(json.contains("\"businessOk\":false"), true)
        @Expect(json.contains("\"finalizationOk\":true"), true)
        @Expect(json.contains("\"errorCode\":\"ckb.scheduler_run_degraded\""), true)
        @Expect(json.contains("\"failedTasks\":[{\"taskName\":\"cangjie_freshness_daily\""), true)
        @Expect(json.contains("version_manifest_invalid_encoding"), true)
    }

    @TestCase
    public func cliJsonFinalizationFailureDoesNotNeedBusinessDegraded(): Unit {
        let result = SchedulerExecutorResult()
        result.runId = "run-finalization-failed"
        result.ran = 1
        result.succeeded = 1
        result.finalizationOk = false
        result.schedulerSaveStatus = "failed"
        result.finalizationDiagnostics.add("scheduler_save_failed:permission_denied /Users/l3gi0n/private/token")

        let json = ckbSchedulerRunOutputJson(result)

        @Expect(json.contains("\"ok\":false"), true)
        @Expect(json.contains("\"businessOk\":true"), true)
        @Expect(json.contains("\"finalizationOk\":false"), true)
        @Expect(json.contains("\"failed\":0"), true)
        @Expect(json.contains("\"degraded\":0"), true)
        @Expect(json.contains("\"errorCode\":\"ckb.scheduler_finalization_failed\""), true)
        @Expect(json.contains("\"schedulerSaveStatus\":\"failed\""), true)
        @Expect(json.contains("scheduler_save_failed"), true)
        @Expect(json.contains("/Users/l3gi0n"), false)
    }
}
