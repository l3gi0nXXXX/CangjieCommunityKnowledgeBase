package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.convert.Parsable
import std.env.getVariable
import std.fs.{Directory, File, Path, exists}
import std.io.*
import std.process.*
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

private class ProgressFakeRunner <: SchedulerTaskRunner {
    public var calls: ArrayList<String> = ArrayList<String>()
    public var timeoutTask: String = ""
    public var failTask: String = ""

    public init() {}

    public func runTask(name: String, since: String, deadlineAtMillis: Int64): SchedulerTaskResult {
        this.calls.add(name)
        let result = SchedulerTaskResult()
        if (name == this.timeoutTask && deadlineAtMillis > 0) {
            result.ok = false
            result.status = "task_timeout:${name}"
            result.durationMillis = 20
            result.validationDiagnostics.add("timeout diagnostic 中文🙂 Authorization: Bearer secret-value")
            return result
        }
        result.ok = name != this.failTask
        result.status = if (result.ok) { "ok" } else { "fake_failed" }
        if (!result.ok) {
            result.validationDiagnostics.add("failure diagnostic 中文🙂 with detailed scheduler worker failure")
        }
        result.durationMillis = 1
        result
    }
}

private class P5S1TruthTimingRunner <: SchedulerTaskRunner {
    public init() {}

    public func runTask(name: String, since: String, deadlineAtMillis: Int64): SchedulerTaskResult {
        let result = SchedulerTaskResult()
        result.ok = true
        result.status = "truth_ok"
        result.startedAtMillis = 100
        result.endedAtMillis = 255
        result.bootstrapStartedAtMillis = 100
        result.taskBodyStartedAtMillis = 137
        result.taskBodyEndedAtMillis = 250
        result.bootstrapDurationMillis = 37
        result.resultWrittenAtMillis = 255
        result.resultFlushDurationMillis = 5
        result.durationMillis = 24000
        result.stageDurations.add("candidate_validation=113")
        result
    }
}

private class P5S2AccountingRunner <: SchedulerTaskRunner {
    public init() {}

    public func runTask(name: String, since: String, deadlineAtMillis: Int64): SchedulerTaskResult {
        let result = SchedulerTaskResult()
        result.ok = true
        result.status = "candidate_validated_promoted"
        result.requestCount = 7
        result.actualAttempts = 7
        result.successfulAttempts = 6
        result.retryAttempts = 1
        result.plannedRequests = 6
        result.completedRequests = 6
        result.failedRequests = 0
        result.validationDiagnostics.add("计量完成🙂 malformed_json invalid_response_encoding Authorization: Bearer fixture-secret")
        result
    }
}

private class CaptureStageSink <: CkbStagedRebuildStageSink {
    public var stages: ArrayList<String> = ArrayList<String>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}

    public func onStagedRebuildStage(progress: CkbStagedRebuildStageProgress): Unit {
        this.stages.add("${progress.stage}|${progress.status}")
        this.diagnostics.add(progress.diagnostic)
    }
}

private class P5S1ThrowingSchedulerProgressSink <: SchedulerProgressSink {
    public var calls: Int64 = 0

    public init() {}

    public func onRunStarted(result: SchedulerExecutorResult): Unit {
        this.fail("run_started")
    }

    public func onTaskStarted(runId: String, taskName: String): Unit {
        this.fail("task_started")
    }

    public func onTaskFinished(runId: String, taskName: String, task: SchedulerTaskResult): Unit {
        this.fail("task_finished")
    }

    public func onRunFinished(result: SchedulerExecutorResult): Unit {
        this.fail("run_finished")
    }

    private func fail(event: String): Unit {
        this.calls += 1
        throw Exception("progress observer fixture ${event} 中文🙂")
    }
}

@Test
public class CkbSchedulerProgressTimeoutTest {
    @TestCase
    public func p5S2U01BudgetPlanAndAttemptFactsRoundTrip(): Unit {
        let release = ckbSyncProfileForScheduleTask("cangjie_release_full_sync")
        let valid = ckbValidateSchedulerProfileBudgetPlan(release)
        let negative = ckbSyncProfileForScheduleTask("cangjie_release_full_sync")
        negative.vectorBudgetMillis = -1
        let overflow = ckbSyncProfileForScheduleTask("cangjie_release_full_sync")
        overflow.unallocatedSafetyMillis = 5001
        let noFlush = ckbSyncProfileForScheduleTask("cangjie_release_full_sync")
        noFlush.resultFlushBudgetMillis = 0
        let historical = ckbSyncProfileForScheduleTask("cangjie_docs_full_weekly")
        let historicalValidation = ckbValidateSchedulerProfileBudgetPlan(historical)

        let scheduler = Scheduler(FakeClock(1000))
        let tasks = ArrayList<String>()
        tasks.add("cangjie_release_full_sync")
        let run = SchedulerExecutor(scheduler, P5S2AccountingRunner()).runTaskNames(tasks, force: true)
        let record = run.taskRecords[0]
        let task = SchedulerTaskResult()
        task.ok = true
        task.status = "candidate_validated_promoted"
        task.requestCount = 7
        task.actualAttempts = 7
        task.successfulAttempts = 6
        task.retryAttempts = 1
        task.plannedRequests = 6
        task.completedRequests = 6
        task.failedRequests = 0
        task.validationDiagnostics.add("计量完成🙂 malformed_json invalid_response_encoding Authorization: Bearer fixture-secret")
        let terminal = ckbSchedulerTaskResultText(task)
        let parsed = ckbSchedulerTaskResultFromText(terminal)
        let legacy = ckbSchedulerTaskResultFromText("ok=true\nstatus=legacy_ok\nrequestCount=2\n")
        let json = ckbSchedulerRunOutputJson(run)
        let progressRoot = "target/p5-s2-u01-task-finished-progress"
        ensureEmptyDir(progressRoot)
        let progressStore = FileKnowledgeStore(progressRoot)
        let progressScheduler = Scheduler(FakeClock(2000))
        let progressRun = SchedulerExecutor(progressScheduler, P5S2AccountingRunner(), FileSchedulerProgressSink(progressStore), 0).runTaskNames(tasks, force: true)
        let progressJson = progressStore.readText(progressRun.progressPath)

        @Expect(release.timeBudgetMillis, 440000)
        @Expect(release.bootstrapBudgetMillis, 40000)
        @Expect(release.fetchBudgetMillis, 80000)
        @Expect(release.ingestBudgetMillis, 20000)
        @Expect(release.vectorBudgetMillis, 180000)
        @Expect(release.validationBudgetMillis, 40000)
        @Expect(release.activeCommitBudgetMillis, 20000)
        @Expect(release.snapshotBudgetMillis, 50000)
        @Expect(release.resultFlushBudgetMillis, 5000)
        @Expect(release.unallocatedSafetyMillis, 5000)
        @Expect(valid.ok, true)
        @Expect(valid.businessBudgetMillis, 430000)
        @Expect(valid.executionBudgetMillis, 435000)
        @Expect(valid.plannedBudgetMillis, 440000)
        @Expect(valid.workerSoftBudgetMillis, 435000)
        @Expect(ckbValidateSchedulerProfileBudgetPlan(negative).status, "invalid_profile_budget_plan")
        @Expect(ckbValidateSchedulerProfileBudgetPlan(overflow).status, "invalid_profile_budget_plan")
        @Expect(ckbValidateSchedulerProfileBudgetPlan(noFlush).status, "invalid_profile_budget_plan")
        @Expect(historicalValidation.ok, true)
        @Expect(historical.timeBudgetMillis, 360000)
        @Expect(parsed.requestCount, parsed.actualAttempts)
        @Expect(parsed.actualAttempts, 7)
        @Expect(parsed.successfulAttempts, 6)
        @Expect(parsed.retryAttempts, 1)
        @Expect(parsed.plannedRequests, 6)
        @Expect(parsed.completedRequests, 6)
        @Expect(parsed.failedRequests, 0)
        @Expect(legacy.actualAttempts, 0)
        @Expect(record.requestCount, record.actualAttempts)
        @Expect(record.retryAttempts, 1)
        @Expect(json.contains("\"actualAttempts\":7"), true)
        @Expect(json.contains("\"successfulAttempts\":6"), true)
        @Expect(json.contains("\"plannedRequests\":6"), true)
        @Expect(json.contains("\"completedRequests\":6"), true)
        @Expect(json.contains("\"failedRequests\":0"), true)
        @Expect(json.contains("\"retryAttempts\":1"), true)
        @Expect(progressJson.contains("\"event\":\"task_finished\""), true)
        @Expect(progressJson.contains("\"requestCount\":7"), true)
        @Expect(progressJson.contains("\"actualAttempts\":7"), true)
        @Expect(progressJson.contains("\"successfulAttempts\":6"), true)
        @Expect(progressJson.contains("\"retryAttempts\":1"), true)
        @Expect(progressJson.contains("\"plannedRequests\":6"), true)
        @Expect(progressJson.contains("\"completedRequests\":6"), true)
        @Expect(progressJson.contains("\"failedRequests\":0"), true)
        @Expect(terminal.contains("fixture-secret"), false)
        @Expect(terminal.contains("计量完成🙂"), true)
        @Expect(terminal.contains("malformed_json"), true)
        @Expect(terminal.contains("invalid_response_encoding"), true)
        @Expect(run.details.contains("\"actualAttempts\""), false)
    }

    @TestCase
    public func p5S1U01TrueTimingRoundTripsToRunRecordAndJson(): Unit {
        let scheduler = Scheduler(FakeClock(1000))
        let executor = SchedulerExecutor(scheduler, P5S1TruthTimingRunner())
        let tasks = ArrayList<String>()
        tasks.add("docs_probe_30d")

        let result = executor.runTaskNames(tasks, force: true)
        let record = result.taskRecords[0]
        let task = SchedulerTaskResult()
        task.ok = true
        task.status = "truth_ok"
        task.schedulerRunId = result.runId
        task.schedulerTaskName = "docs_probe_30d"
        task.startedAtMillis = 100
        task.endedAtMillis = 255
        task.bootstrapStartedAtMillis = 100
        task.taskBodyStartedAtMillis = 137
        task.taskBodyEndedAtMillis = 250
        task.bootstrapDurationMillis = 37
        task.resultWrittenAtMillis = 255
        task.resultFlushDurationMillis = 5
        task.durationMillis = 155
        task.stageDurations.add("candidate_validation=113")
        let parsed = ckbSchedulerTaskResultFromText(ckbSchedulerTaskResultText(task))
        let legacy = ckbSchedulerTaskResultFromText("ok=true\nstatus=legacy_ok\ndurationMillis=7\nfutureField=future-value\n")
        var longUnicodeIdentity = "运行🙂"
        for (i in 0..80) {
            longUnicodeIdentity += "阶段${i}中文🙂"
        }
        let unicodeTask = SchedulerTaskResult()
        unicodeTask.status = "稳定状态-${longUnicodeIdentity}"
        unicodeTask.cursor = "游标-${longUnicodeIdentity}"
        unicodeTask.since = "起点-${longUnicodeIdentity}"
        unicodeTask.activeVersion = "活动-${longUnicodeIdentity}"
        unicodeTask.candidateVersion = "候选-${longUnicodeIdentity}"
        unicodeTask.schedulerRunId = "运行-${longUnicodeIdentity}"
        unicodeTask.schedulerTaskName = "任务-${longUnicodeIdentity}"
        unicodeTask.validationStatus = "验证-${longUnicodeIdentity}"
        unicodeTask.validationEvidenceHash = "证据-${longUnicodeIdentity}"
        unicodeTask.updatedDataKinds.add("数据-${longUnicodeIdentity}")
        let parsedUnicode = ckbSchedulerTaskResultFromText(ckbSchedulerTaskResultText(unicodeTask))
        let json = ckbSchedulerRunOutputJson(result)
        let wall = ckbApplySchedulerProcessWallTiming(task, 90, 260)

        @Expect(result.succeeded, 1)
        @Expect(record.schedulerRunId, result.runId)
        @Expect(record.schedulerTaskName, "docs_probe_30d")
        @Expect(record.durationMillis, 155)
        @Expect(record.bootstrapDurationMillis, 37)
        @Expect(record.taskBodyEndedAtMillis - record.taskBodyStartedAtMillis, 113)
        @Expect(record.resultFlushDurationMillis, 5)
        @Expect(scheduler.entries[1].lastRunStartedAtMillis, 100)
        @Expect(scheduler.entries[1].lastRunFinishedAtMillis, 255)
        @Expect(parsed.schedulerRunId, result.runId)
        @Expect(parsed.schedulerTaskName, "docs_probe_30d")
        @Expect(parsed.stageDurations.size, 1)
        @Expect(parsed.stageDurations[0], "candidate_validation=113")
        @Expect(legacy.status, "legacy_ok")
        @Expect(legacy.bootstrapStartedAtMillis, 0)
        @Expect(legacy.taskBodyEndedAtMillis, 0)
        @Expect(legacy.resultFlushDurationMillis, 0)
        @Expect(parsedUnicode.status, unicodeTask.status)
        @Expect(parsedUnicode.cursor, unicodeTask.cursor)
        @Expect(parsedUnicode.since, unicodeTask.since)
        @Expect(parsedUnicode.activeVersion, unicodeTask.activeVersion)
        @Expect(parsedUnicode.candidateVersion, unicodeTask.candidateVersion)
        @Expect(parsedUnicode.schedulerRunId, unicodeTask.schedulerRunId)
        @Expect(parsedUnicode.schedulerTaskName, unicodeTask.schedulerTaskName)
        @Expect(parsedUnicode.validationStatus, unicodeTask.validationStatus)
        @Expect(parsedUnicode.validationEvidenceHash, unicodeTask.validationEvidenceHash)
        @Expect(parsedUnicode.updatedDataKinds[0], unicodeTask.updatedDataKinds[0])
        @Expect(json.contains("\"bootstrapStartedAtMillis\":100"), true)
        @Expect(json.contains("\"taskBodyEndedAtMillis\":250"), true)
        @Expect(json.contains("\"resultFlushDurationMillis\":5"), true)
        @Expect(json.contains("\"schedulerTaskName\":\"docs_probe_30d\""), true)
        @Expect(result.details.contains("\"ok\""), false)
        @Expect(result.details.contains("\"schedulerRunId\""), false)
        @Expect(wall.durationMillis, 170)
        @Expect(wall.bootstrapDurationMillis, 37)
    }

    @TestCase
    public func p5S1N02ThrowingSchedulerObserverKeepsBusinessOutcome(): Unit {
        let scheduler = Scheduler(FakeClock(1000))
        let sink = P5S1ThrowingSchedulerProgressSink()
        let executor = SchedulerExecutor(scheduler, ProgressFakeRunner(), sink, 0)
        let tasks = ArrayList<String>()
        tasks.add("community_repo_discovery_30d")
        tasks.add("docs_probe_30d")

        let result = executor.runTaskNames(tasks, force: true)

        @Expect(result.ran, 2)
        @Expect(result.succeeded, 2)
        @Expect(result.failed, 0)
        @Expect(result.businessOk, true)
        @Expect(result.finalizationOk, false)
        @Expect(result.taskRecords.size, 2)
        @Expect(result.taskRecords[0].status, "ok")
        @Expect(result.taskRecords[1].status, "ok")
        @Expect(sink.calls, 6)
        @Expect(p5S1StringListContains(result.finalizationDiagnostics, "scheduler_progress_observer_degraded:event=run_started"), true)
        @Expect(p5S1StringListContains(result.finalizationDiagnostics, "scheduler_progress_observer_degraded:event=run_finished"), true)
        @Expect(p5S1StringListContains(result.finalizationDiagnostics, "task_exception"), false)
        @Expect(p5S1StringListContains(result.finalizationDiagnostics, "Authorization"), false)
    }

    @TestCase
    public func p5S1B01LatestStageUsesCurrentIdentityTimestampAndPriority(): Unit {
        let root = "target/p5-s1-b01-stage-selection"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        store.writeLinesAtomically("metadata/scheduler-current.ckb", "runId=current-run\ntaskName=cangjie_release_full_sync\nstatus=running\nprogressPath=metadata/scheduler-runs/current-run.jsonl\ndiagnostic=\n")
        store.writeLinesAtomically("metadata/routine-stage-checkpoints/cangjie_release_full_sync-ingest_finished.ckb", "profile=cangjie_release_full_sync\nrunId=old-run\ntaskName=cangjie_release_full_sync\nstage=ingest_finished\nstatus=running\ndiagnostic=old-routine\natMillis=1\n")
        store.writeLinesAtomically("metadata/scheduler-runs/current-run-cangjie_release_full_sync-vector-current.ckb", "schedulerRunId=old-run\nschedulerTaskName=cangjie_release_full_sync\nstate=ready\ncompleted=99\ncurrentBatch=2\nprogressPath=metadata/vector-reconcile-runs/old.jsonl\natMillis=2\n")
        store.writeLinesAtomically("metadata/scheduler-runs/current-run-cangjie_release_full_sync-staged-rebuild-current.ckb", "runId=current-run\ntaskName=cangjie_release_full_sync\nstage=candidate_active_commit_started\nstatus=running\nprogressPath=metadata/scheduler-runs/current-run.jsonl\ndiagnostic=current-candidate\natMillis=3\n")
        store.writeLinesAtomically("metadata/routine-stage-checkpoints/cangjie_release_full_sync-ingest_started.ckb", "profile=cangjie_release_full_sync\nrunId=\ntaskName=\nstage=ingest_started\nstatus=running\ndiagnostic=empty-identity\natMillis=4\n")
        store.writeLinesAtomically("metadata/scheduler-runs/current-run-cangjie_release_full_sync-routine-active_snapshot_manifest_after-current.ckb", "profile=cangjie_release_full_sync\nrunId=wrong-run\ntaskName=cangjie_release_full_sync\nstage=active_snapshot_manifest_after\nstatus=ok\nprogressPath=metadata/scheduler-runs/wrong-run.jsonl\ndiagnostic=wrong-run-newer\natMillis=99\n")

        @Expect(ckbSchedulerWorkerLastStageFromStoreForTask(store, "cangjie_release_full_sync"), "candidate_active_commit_started")
        @Expect(ckbSchedulerWorkerLastProgressFromStoreForTask(store, "cangjie_release_full_sync").contains("current-candidate"), true)
        @Expect(ckbSchedulerCurrentRunIdForTask(store, "cangjie_docs_full_weekly"), "")
        @Expect(ckbSchedulerWorkerLastStageFromStoreForTask(store, "cangjie_docs_full_weekly"), "")
        @Expect(ckbSchedulerWorkerLastProgressFromStoreForTask(store, "cangjie_docs_full_weekly"), "")

        store.writeLinesAtomically("metadata/scheduler-runs/current-run-cangjie_release_full_sync-routine-ingest_started-current.ckb", "profile=cangjie_release_full_sync\nrunId=current-run\ntaskName=cangjie_release_full_sync\nstage=ingest_started\nstatus=running\nprogressPath=metadata/scheduler-runs/current-run.jsonl\ndiagnostic=current-routine-tie\natMillis=3\n")
        for (_ in 0..100) {
            @Expect(ckbSchedulerWorkerLastStageFromStoreForTask(store, "cangjie_release_full_sync"), "candidate_active_commit_started")
        }
    }

    @TestCase
    public func p5S1N01CheckpointFailureIsDegradedAndMalformedUtf8Isolated(): Unit {
        let root = "target/p5-s1-n01-checkpoint-degraded"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore("${root}/store")
        store.ensureLayout()
        File.writeTo(Path(root).join("store/metadata/routine-stage-checkpoints"), "blocked".toArray())
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let service = CkbCommandLoopService(config, store, sourceRunner: FakeSourceFetchRunner())
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("docs_probe_30d")

        let result = service.runSchedulerTasks(tasks, true)
        let diagnosticPath = "metadata/scheduler-runs/${result.runId}-diagnostics.jsonl"

        @Expect(result.succeeded, 1)
        @Expect(store.readText(diagnosticPath).contains("profile_stage_checkpoint_write_degraded"), true)
        @Expect(ckbScheduledPromotionTerminalStatus(false, "candidate_vector_failed", "ok"), "candidate_vector_failed")
        @Expect(ckbScheduledPromotionTerminalStatus(false, "candidate_active_commit_failed", "ok"), "candidate_active_commit_failed")
        @Expect(ckbScheduledPromotionTerminalStatus(false, "candidate_active_snapshot_failed", "ok"), "candidate_active_snapshot_failed")

        let malformedRoot = "target/p5-s1-n01-invalid-utf8-stage"
        ensureEmptyDir(malformedRoot)
        let malformedStore = FileKnowledgeStore(malformedRoot)
        malformedStore.writeLinesAtomically("metadata/scheduler-current.ckb", "runId=utf8-run\ntaskName=cangjie_release_full_sync\nstatus=running\nprogressPath=metadata/scheduler-runs/utf8-run.jsonl\n")
        malformedStore.writeLinesAtomically("metadata/scheduler-runs/utf8-run-cangjie_release_full_sync-staged-rebuild-current.ckb", "runId=utf8-run\ntaskName=cangjie_release_full_sync\nstage=candidate_validation_finished\nstatus=failed\nprogressPath=metadata/scheduler-runs/utf8-run.jsonl\ndiagnostic=中文🙂\natMillis=5\n")
        File.writeTo(Path(malformedRoot).join("metadata/scheduler-runs/utf8-run-cangjie_release_full_sync-routine-active_snapshot_manifest_after-current.ckb"), [UInt8(255), UInt8(254), UInt8(253)])

        @Expect(ckbSchedulerWorkerLastStageFromStoreForTask(malformedStore, "cangjie_release_full_sync"), "candidate_validation_finished")
        @Expect(ckbSchedulerWorkerLastProgressFromStoreForTask(malformedStore, "cangjie_release_full_sync").contains("中文🙂"), true)

        let invalidCurrentRoot = "target/p5-s1-n01-invalid-utf8-current"
        ensureEmptyDir(invalidCurrentRoot)
        let invalidCurrentStore = FileKnowledgeStore(invalidCurrentRoot)
        invalidCurrentStore.ensureLayout()
        File.writeTo(Path(invalidCurrentRoot).join("metadata/scheduler-current.ckb"), [UInt8(255), UInt8(254), UInt8(253)])
        File.writeTo(Path(invalidCurrentRoot).join("metadata/staged-rebuild-current.ckb"), [UInt8(255), UInt8(254), UInt8(253)])
        File.writeTo(Path(invalidCurrentRoot).join("metadata/vector-reconcile-current.ckb"), [UInt8(255), UInt8(254), UInt8(253)])

        @Expect(ckbSchedulerCurrentRunIdForTask(invalidCurrentStore, "cangjie_release_full_sync"), "")
        @Expect(ckbSchedulerWorkerLastStageFromStoreForTask(invalidCurrentStore, "cangjie_release_full_sync"), "")
        @Expect(ckbSchedulerWorkerLastProgressFromStoreForTask(invalidCurrentStore, "cangjie_release_full_sync"), "")
    }

    @TestCase
    public func p5S1B02WrongScopedCheckpointStillAllowsValidProfileCurrent(): Unit {
        let root = "target/p5-s1-b02-profile-current-fallback"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        store.writeLinesAtomically("metadata/scheduler-current.ckb", "runId=current-run\ntaskName=cangjie_release_full_sync\nstatus=running\nprogressPath=metadata/scheduler-runs/current-run.jsonl\n")
        store.writeLinesAtomically("metadata/scheduler-runs/current-run-cangjie_release_full_sync-routine-fetch-current.ckb", "profile=cangjie_release_full_sync\nrunId=wrong-run\ntaskName=cangjie_release_full_sync\nstage=fetch\nstatus=failed\ndiagnostic=wrong-scoped\natMillis=99\n")
        store.writeLinesAtomically("metadata/routine-stage-checkpoints/cangjie_release_full_sync-fetch.ckb", "profile=cangjie_release_full_sync\nrunId=current-run\ntaskName=cangjie_release_full_sync\nstage=fetch\nstatus=running\nprogressPath=metadata/scheduler-runs/current-run.jsonl\ndiagnostic=valid-profile-current 中文🙂\natMillis=5\n")

        @Expect(ckbSchedulerWorkerLastStageFromStoreForTask(store, "cangjie_release_full_sync"), "fetch")
        @Expect(ckbSchedulerWorkerLastProgressFromStoreForTask(store, "cangjie_release_full_sync").contains("valid-profile-current 中文🙂"), true)
        @Expect(ckbSchedulerWorkerLastProgressFromStoreForTask(store, "cangjie_release_full_sync").contains("wrong-scoped"), false)
    }

    @TestCase
    public func p5S1N03StrictWorkerReaderRequiresAuthoritativeSidecar(): Unit {
        let root = "target/p5-s1-n03-sidecar-authority"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let resultPath = "metadata/scheduler-workers/docs-authority.ckb"
        let primary = SchedulerTaskResult()
        primary.ok = true
        primary.status = "primary_ok"
        primary.schedulerRunId = "run-authority"
        primary.schedulerTaskName = "docs_probe_30d"
        primary.lastStage = "fetch"
        primary.lastProgress = "完成 中文🙂 Authorization: Bearer secret-value"
        store.writeLinesAtomically(resultPath, ckbSchedulerTaskResultText(primary))
        let primaryArtifact = store.readText(resultPath)

        let strictMissing = ckbReadSchedulerWorkerResultFile(root, resultPath, "docs_probe_30d", "0", 5, 100, schedulerRunId: "run-authority", strictIdentity: true)
        let legacy = ckbReadSchedulerWorkerResultFile(root, resultPath, "docs_probe_30d", "0", 5, 100, schedulerRunId: "run-authority", strictIdentity: false)

        @Expect(strictMissing.ok, false)
        @Expect(strictMissing.status, "task_worker_sidecar_missing")
        @Expect(strictMissing.lastStage, "fetch")
        @Expect(strictMissing.lastProgress.contains("中文🙂"), true)
        @Expect(strictMissing.lastProgress.contains("secret-value"), false)
        @Expect(primaryArtifact.contains("中文🙂"), true)
        @Expect(primaryArtifact.contains("secret-value"), false)
        @Expect(legacy.ok, true)
        @Expect(legacy.status, "primary_ok")

        let confirmed = SchedulerTaskResult()
        confirmed.ok = true
        confirmed.status = "confirmed_ok"
        confirmed.schedulerRunId = "run-authority"
        confirmed.schedulerTaskName = "docs_probe_30d"
        confirmed.resultWrittenAtMillis = 123
        confirmed.resultFlushDurationMillis = 3
        confirmed.lastProgress = "确认完成 中文🙂 Authorization: Bearer secret-value"
        confirmed.workerErrSnippet = "Authorization: Bearer secret-value"
        confirmed.validationDiagnostics.add("诊断🙂 Authorization: Bearer secret-value")
        confirmed.stageDurations.add("stage=fetch|durationMillis=2|itemCount=1|status=profile_ok")
        store.writeLinesAtomically("${resultPath}.sidecar", ckbSchedulerTaskResultText(confirmed))
        let sidecarArtifact = store.readText("${resultPath}.sidecar")
        let strictConfirmed = ckbReadSchedulerWorkerResultFile(root, resultPath, "docs_probe_30d", "0", 5, 100, schedulerRunId: "run-authority", strictIdentity: true)

        @Expect(strictConfirmed.ok, true)
        @Expect(strictConfirmed.status, "confirmed_ok")
        @Expect(strictConfirmed.stageDurations.size, 1)
        @Expect(strictConfirmed.lastProgress.contains("中文🙂"), true)
        @Expect(strictConfirmed.lastProgress.contains("secret-value"), false)
        @Expect(strictConfirmed.workerErrSnippet.contains("secret-value"), false)
        @Expect(p5S1StringListContains(strictConfirmed.validationDiagnostics, "secret-value"), false)
        @Expect(sidecarArtifact.contains("中文🙂"), true)
        @Expect(sidecarArtifact.contains("secret-value"), false)

        confirmed.schedulerRunId = "wrong-run"
        store.writeLinesAtomically("${resultPath}.sidecar", ckbSchedulerTaskResultText(confirmed))
        let wrongRun = ckbReadSchedulerWorkerResultFile(root, resultPath, "docs_probe_30d", "0", 5, 100, schedulerRunId: "run-authority", strictIdentity: true)
        @Expect(wrongRun.ok, false)
        @Expect(wrongRun.status, "task_worker_sidecar_run_mismatch")

        confirmed.schedulerRunId = "run-authority"
        confirmed.schedulerTaskName = "wrong-task"
        store.writeLinesAtomically("${resultPath}.sidecar", ckbSchedulerTaskResultText(confirmed))
        let wrongTask = ckbReadSchedulerWorkerResultFile(root, resultPath, "docs_probe_30d", "0", 5, 100, schedulerRunId: "run-authority", strictIdentity: true)
        @Expect(wrongTask.status, "task_worker_sidecar_task_mismatch")

        confirmed.schedulerTaskName = "docs_probe_30d"
        confirmed.resultWrittenAtMillis = 0
        store.writeLinesAtomically("${resultPath}.sidecar", ckbSchedulerTaskResultText(confirmed))
        let unconfirmed = ckbReadSchedulerWorkerResultFile(root, resultPath, "docs_probe_30d", "0", 5, 100, schedulerRunId: "run-authority", strictIdentity: true)
        @Expect(unconfirmed.status, "task_worker_sidecar_unconfirmed")

        File.writeTo(Path(root).join("${resultPath}.sidecar"), [UInt8(255), UInt8(254), UInt8(253)])
        let malformed = ckbReadSchedulerWorkerResultFile(root, resultPath, "docs_probe_30d", "0", 5, 100, schedulerRunId: "run-authority", strictIdentity: true)
        @Expect(malformed.status, "task_worker_sidecar_malformed")
    }

    @TestCase
    public func p5S1E2EATrueChildKeepsRunIdentityAndTerminalArtifacts(): Unit {
        let root = "target/p5-s1-e2e-a-child"
        ensureEmptyDir(root)
        let storePath = "${root}/store"
        let configPath = "${root}/ckb-test.conf"
        File.writeTo(Path(configPath), "networkEnabled=false\n".toArray())
        let store = FileKnowledgeStore(storePath)
        store.writeLinesAtomically("metadata/scheduler-current.ckb", "runId=s1-child-run\ntaskName=docs_probe_30d\nstatus=running\nprogressPath=metadata/scheduler-runs/s1-child-run.jsonl\ndiagnostic=\n")
        let config = CkbRuntimeConfig()
        let runner = ProcessIsolatedSchedulerTaskRunner(newOfflineKnowledgeBase(), config, store, configPath, storePath, DisabledNetworkFetchRunner(), "../target/release/bin/main")
        let scheduler = Scheduler(FakeClock(1000))
        let executor = SchedulerExecutor(scheduler, runner, NoopSchedulerProgressSink(), 120000)
        let tasks = ArrayList<String>()
        tasks.add("docs_probe_30d")

        let result = executor.runTaskNames(tasks, force: true)
        let record = result.taskRecords[0]
        var terminalName = ""
        let workerDir = Path(storePath).join("metadata/scheduler-workers")
        if (exists(workerDir)) {
            for (entry in Directory.readFrom(workerDir)) {
                if (entry.isRegular() && entry.name.endsWith(".ckb")) {
                    let text = String.fromUtf8(File.readFrom(entry.path))
                    if (text.contains("schedulerRunId=s1-child-run") && !text.contains("status=worker_started")) {
                        terminalName = entry.name
                    }
                }
            }
        }

        let resultPath = "metadata/scheduler-workers/${terminalName}"
        let primaryText = if (terminalName != "") { store.readText(resultPath) } else { "" }
        let sidecarText = if (terminalName != "") { store.readText("${resultPath}.sidecar") } else { "" }
        let confirmed = ckbReadSchedulerWorkerResultFile(storePath, resultPath, "docs_probe_30d", "0", record.durationMillis, 120000, schedulerRunId: "s1-child-run", strictIdentity: true)
        let taskRecordsJson = ckbSchedulerRunTaskRecordsJson(result.taskRecords)
        let outText = if (terminalName != "") { String.fromUtf8(File.readFrom(Path(storePath).join("${resultPath}.out"))) } else { "missing" }
        let errText = if (terminalName != "") { String.fromUtf8(File.readFrom(Path(storePath).join("${resultPath}.err"))) } else { "missing" }
        let childExitProbe = if (record.workerPid > 0) { launch("/bin/sh", ["-c", "kill -0 ${record.workerPid} 2>/dev/null"]).wait() } else { 0 }

        @Expect(result.ran, 1)
        @Expect(result.failed, 1)
        @Expect(record.ok, false)
        @Expect(record.status, "fetch_degraded:request_failed")
        @Expect(record.schedulerRunId, "s1-child-run")
        @Expect(record.schedulerTaskName, "docs_probe_30d")
        @Expect(record.startedAtMillis <= record.bootstrapStartedAtMillis, true)
        @Expect(record.bootstrapStartedAtMillis <= record.taskBodyStartedAtMillis, true)
        @Expect(record.taskBodyStartedAtMillis <= record.taskBodyEndedAtMillis, true)
        @Expect(record.taskBodyEndedAtMillis <= record.resultWrittenAtMillis, true)
        @Expect(record.resultWrittenAtMillis <= record.endedAtMillis, true)
        @Expect(record.resultFlushDurationMillis, record.resultWrittenAtMillis - record.taskBodyEndedAtMillis)
        @Expect(record.durationMillis, record.endedAtMillis - record.startedAtMillis)
        @Expect(record.workerOutSnippet, "")
        @Expect(record.workerErrSnippet, "")
        @Expect(record.stageDurations.size >= 2, true)
        @Expect(p5S1StringListContains(record.stageDurations, "stage=fetch|durationMillis="), true)
        @Expect(p5S1StringListContains(record.stageDurations, "stage=ingest|durationMillis="), true)
        @Expect(terminalName != "", true)
        @Expect(store.has("metadata/scheduler-workers/${terminalName}.sidecar"), true)
        @Expect(primaryText.contains("resultWrittenAtMillis=0"), true)
        @Expect(sidecarText.contains("resultWrittenAtMillis=0"), false)
        @Expect(confirmed.status, record.status)
        @Expect(confirmed.schedulerTaskName, record.schedulerTaskName)
        @Expect(confirmed.taskBodyEndedAtMillis, record.taskBodyEndedAtMillis)
        @Expect(confirmed.resultWrittenAtMillis, record.resultWrittenAtMillis)
        @Expect(confirmed.resultFlushDurationMillis, record.resultFlushDurationMillis)
        @Expect(confirmed.stageDurations.size, record.stageDurations.size)
        @Expect(taskRecordsJson.contains("\"schedulerTaskName\":\"docs_probe_30d\""), true)
        @Expect(taskRecordsJson.contains("stage=fetch|durationMillis="), true)
        @Expect(outText, "")
        @Expect(errText, "")
        @Expect(record.workerPid > 0, true)
        @Expect(childExitProbe != 0, true)
        @Expect(ckbSchedulerWorkerLastStageFromStoreForTask(store, "docs_probe_30d") != "", true)
        @Expect(ckbSchedulerCurrentRunIdForTask(store, "cangjie_release_full_sync"), "")
    }

    @TestCase
    public func p5S2E2EAChildKeepsSoftMarginStagesAndAttemptFacts(): Unit {
        let root = "target/p5-s2-e2e-a-child-budget"
        ensureEmptyDir(root)
        let storePath = "${root}/store"
        let hardDeadlineAtMillis = ckbCoreNowMillis() + 440000
        let softDeadlineAtMillis = hardDeadlineAtMillis - 5000
        let resultRel = "metadata/scheduler-workers/p5-s2-real-child.ckb"
        var dyldLibraryPath = ""
        if (let Some(value) <- getVariable("DYLD_LIBRARY_PATH")) {
            dyldLibraryPath = value
        }
        let childPrelude = ckbSchedulerWorkerShellPreludeWithHeap(dyldLibraryPath, "")
        let childCommand = childPrelude +
            "export CKB_P5_S2_E2E_CHILD='1'; " +
            "export CKB_P5_S2_E2E_STORE='${storePath}'; " +
            "export CKB_P5_S2_E2E_RESULT_REL='${resultRel}'; " +
            "export CKB_P5_S2_E2E_HARD_DEADLINE='${hardDeadlineAtMillis}'; " +
            "export CKB_P5_S2_E2E_SOFT_DEADLINE='${softDeadlineAtMillis}'; " +
            "target/release/unittest_bin/cangjie_community_knowledge_base_test --filter='*CkbSchedulerProgressTimeoutTest.p5S2E2EARealChildWorkerFixture' --no-color --no-progress"
        let child = launch("/bin/zsh", ["-c", childCommand], stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
        let childCode = child.wait()
        let childStdout = p5S1SafeReadPipe(child.stdOutPipe)
        let childStderr = p5S1SafeReadPipe(child.stdErrPipe)
        let store = FileKnowledgeStore(storePath)
        let task = ckbSchedulerTaskResultFromText(store.readText("${resultRel}.sidecar"))

        @Expect(childCode, 0)
        @Expect(task.ok, true)
        @Expect(task.status, "candidate_validated_promoted")
        @Expect(task.deadlineAtMillis, softDeadlineAtMillis)
        @Expect(task.timeBudgetMillis, 440000)
        @Expect(task.requestCount, task.actualAttempts)
        @Expect(task.actualAttempts > 0, true)
        @Expect(task.successfulAttempts, task.actualAttempts)
        @Expect(task.retryAttempts, 0)
        @Expect(task.plannedRequests, task.actualAttempts)
        @Expect(task.completedRequests, task.plannedRequests)
        @Expect(task.failedRequests, 0)
        @Expect(task.stageDurations.size, 7)
        @Expect(p5S1StringListContains(task.stageDurations, "stage=bootstrap|durationMillis=0"), true)
        @Expect(p5S1StringListContains(task.stageDurations, "stage=fetch|durationMillis="), true)
        @Expect(p5S1StringListContains(task.stageDurations, "stage=ingest|durationMillis="), true)
        @Expect(p5S1StringListContains(task.stageDurations, "stage=candidate_vector_finished|durationMillis="), true)
        @Expect(p5S1StringListContains(task.stageDurations, "stage=candidate_validation_finished|durationMillis="), true)
        @Expect(p5S1StringListContains(task.stageDurations, "stage=candidate_active_commit_finished|durationMillis="), true)
        @Expect(p5S1StringListContains(task.stageDurations, "stage=candidate_active_snapshot_finished|durationMillis="), true)
        @Expect(childStdout.contains("FAILED"), false)
        @Expect(childStderr.contains("Authorization"), false)

        let bootstrapRoot = "${root}/bootstrap-real-child"
        let bootstrapStorePath = "${bootstrapRoot}/store"
        let bootstrapConfigPath = "${bootstrapRoot}/ckb-test.conf"
        let bootstrapResultRel = "metadata/scheduler-workers/bootstrap-expired.ckb"
        Directory.create(Path(bootstrapRoot), recursive: true)
        File.writeTo(Path(bootstrapConfigPath), "networkEnabled=false\n".toArray())
        let bootstrapProcess = launch("../target/release/bin/main", ["--config", bootstrapConfigPath, "--store", bootstrapStorePath, "scheduler-task-worker", "--task", "cangjie_release_full_sync", "--scheduler-run-id", "p5-s2-bootstrap-real", "--since", "0", "--deadline", "1", "--result-rel", bootstrapResultRel], stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
        let bootstrapCode = bootstrapProcess.wait()
        let bootstrapStdout = p5S1SafeReadPipe(bootstrapProcess.stdOutPipe)
        let bootstrapStderr = p5S1SafeReadPipe(bootstrapProcess.stdErrPipe)
        let bootstrapStore = FileKnowledgeStore(bootstrapStorePath)
        let bootstrapResult = ckbSchedulerTaskResultFromText(bootstrapStore.readText("${bootstrapResultRel}.sidecar"))

        @Expect(bootstrapCode, 1)
        @Expect(bootstrapResult.status, "bootstrap_deadline_exceeded")
        @Expect(bootstrapResult.schedulerRunId, "p5-s2-bootstrap-real")
        @Expect(bootstrapResult.schedulerTaskName, "cangjie_release_full_sync")
        @Expect(bootstrapResult.resultWrittenAtMillis > 0, true)
        @Expect(bootstrapStdout, "")
        @Expect(bootstrapStderr, "")
    }

    @TestCase
    public func p5S2E2EARealChildWorkerFixture(): Unit {
        if (getVariable("CKB_P5_S2_E2E_CHILD") != Some("1")) {
            return
        }
        let storePath = p5S2RequiredChildVariable("CKB_P5_S2_E2E_STORE")
        let resultRel = p5S2RequiredChildVariable("CKB_P5_S2_E2E_RESULT_REL")
        let hardDeadlineAtMillis = Int64.parse(p5S2RequiredChildVariable("CKB_P5_S2_E2E_HARD_DEADLINE"))
        let softDeadlineAtMillis = Int64.parse(p5S2RequiredChildVariable("CKB_P5_S2_E2E_SOFT_DEADLINE"))
        let store = FileKnowledgeStore(storePath)
        store.saveCangjieVersionManifest(p5S2E2EManifest())
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.firstInitEvalRoot = p5S2WriteEvalFixture("${storePath}/eval-fixture")
        config.firstInitTargetVersion = "1.0.0"
        let bootstrapStartedAtMillis = ckbCoreNowMillis()
        let taskBodyStartedAtMillis = ckbCoreNowMillis()
        let task = CkbSchedulerTaskRunner(newOfflineKnowledgeBase(), config, store, sourceRunner: P5S2E2EReleaseRunner()).runTask("cangjie_release_full_sync", "0", softDeadlineAtMillis)
        let taskBodyEndedAtMillis = ckbCoreNowMillis()
        task.schedulerRunId = "p5-s2-e2e-a"
        task.schedulerTaskName = "cangjie_release_full_sync"
        task.startedAtMillis = bootstrapStartedAtMillis
        task.bootstrapStartedAtMillis = bootstrapStartedAtMillis
        task.taskBodyStartedAtMillis = taskBodyStartedAtMillis
        task.taskBodyEndedAtMillis = taskBodyEndedAtMillis
        task.bootstrapDurationMillis = taskBodyStartedAtMillis - bootstrapStartedAtMillis
        task.deadlineAtMillis = softDeadlineAtMillis
        task.timeBudgetMillis = 440000
        task.stageDurations.add("stage=bootstrap|durationMillis=${task.bootstrapDurationMillis}|itemCount=1|status=ok")
        task.resultWrittenAtMillis = 0
        task.resultFlushDurationMillis = 0
        store.writeLinesAtomically(resultRel, ckbSchedulerTaskResultText(task))
        let resultWrittenAtMillis = ckbCoreNowMillis()
        task.resultWrittenAtMillis = resultWrittenAtMillis
        task.resultFlushDurationMillis = resultWrittenAtMillis - taskBodyEndedAtMillis
        task.endedAtMillis = resultWrittenAtMillis
        task.durationMillis = resultWrittenAtMillis - bootstrapStartedAtMillis
        store.writeLinesAtomically("${resultRel}.sidecar", ckbSchedulerTaskResultText(task))

        @Expect(softDeadlineAtMillis, hardDeadlineAtMillis - 5000)
        @Expect(task.ok, true)
        @Expect(task.stageDurations.size, 7)
        @Expect(task.requestCount, task.actualAttempts)
        @Expect(task.plannedRequests, task.completedRequests + task.failedRequests)
    }

    @TestCase
    public func p5S1E2ECHardTimeoutProcessWritesConfirmedCompensation(): Unit {
        let root = "target/p5-s1-e2e-c-hard-timeout"
        ensureEmptyDir(root)
        let storePath = "${root}/store"
        let workerPath = "${root}/sleep-worker.zsh"
        let childPidPath = "${root}/sleep-child.pid"
        File.writeTo(Path(workerPath), "#!/bin/zsh\nsleep 30 &\nchild=$!\necho $child > ${childPidPath}\nwait $child\n".toArray())
        let chmodCode = launch("/bin/chmod", ["700", workerPath]).wait()
        let store = FileKnowledgeStore(storePath)
        store.writeLinesAtomically("metadata/scheduler-current.ckb", "runId=hard-timeout-run\ntaskName=docs_probe_30d\nstatus=running\nprogressPath=metadata/scheduler-runs/hard-timeout-run.jsonl\ndiagnostic=\n")
        let runner = ProcessIsolatedSchedulerTaskRunner(newOfflineKnowledgeBase(), CkbRuntimeConfig(), store, "", storePath, DisabledNetworkFetchRunner(), workerPath)

        let task = runner.runTask("docs_probe_30d", "0", ckbCoreNowMillis() + 500)
        let terminalName = p5S1TerminalWorkerFileName(storePath, "hard-timeout-run")
        let resultPath = "metadata/scheduler-workers/${terminalName}"
        let primaryText = if (terminalName != "") { store.readText(resultPath) } else { "" }
        let sidecarText = if (terminalName != "") { store.readText("${resultPath}.sidecar") } else { "" }
        let primary = ckbSchedulerTaskResultFromText(primaryText)
        let confirmed = ckbSchedulerTaskResultFromText(sidecarText)
        var childPid: Int64 = 0
        if (exists(Path(childPidPath))) {
            try {
                childPid = Int64.parse(String.fromUtf8(File.readFrom(Path(childPidPath))).trimAscii())
            } catch (_: Exception) {
                childPid = 0
            }
        }
        let outText = if (terminalName != "") { p5S1SafeReadFile(Path(storePath).join("${resultPath}.out")) } else { "missing" }
        let errText = if (terminalName != "") { p5S1SafeReadFile(Path(storePath).join("${resultPath}.err")) } else { "missing" }

        @Expect(chmodCode, 0)
        @Expect(task.ok, false)
        @Expect(task.status, "task_timeout:docs_probe_30d")
        @Expect(task.schedulerRunId, "hard-timeout-run")
        @Expect(task.schedulerTaskName, "docs_probe_30d")
        @Expect(task.lastStage, "worker_timeout")
        @Expect(task.workerPid > 0, true)
        @Expect(terminalName != "", true)
        @Expect(primary.status, "task_timeout:docs_probe_30d")
        @Expect(primary.resultWrittenAtMillis, 0)
        @Expect(confirmed.status, "task_timeout:docs_probe_30d")
        @Expect(confirmed.schedulerRunId, "hard-timeout-run")
        @Expect(confirmed.schedulerTaskName, "docs_probe_30d")
        @Expect(confirmed.resultWrittenAtMillis >= confirmed.taskBodyEndedAtMillis, true)
        @Expect(confirmed.resultFlushDurationMillis, confirmed.resultWrittenAtMillis - confirmed.taskBodyEndedAtMillis)
        @Expect(outText, "")
        @Expect(errText, "")
        @Expect(p5S1ProcessExited(task.workerPid), true)
        @Expect(childPid > 0, true)
        @Expect(p5S1ProcessExited(childPid), true)
        @Expect(primaryText.contains("secret-value"), false)
        @Expect(sidecarText.contains("secret-value"), false)
    }

    @TestCase
    public func p5S1N04FastWorkerWithoutSidecarRemainsProtocolFailure(): Unit {
        let root = "target/p5-s1-n04-fast-worker-protocol"
        ensureEmptyDir(root)
        let storePath = "${root}/store"
        let workerPath = "${root}/fast-worker.zsh"
        File.writeTo(Path(workerPath), "#!/bin/zsh\nexit 0\n".toArray())
        @Expect(launch("/bin/chmod", ["700", workerPath]).wait(), 0)
        let store = FileKnowledgeStore(storePath)
        store.writeLinesAtomically("metadata/scheduler-current.ckb", "runId=fast-protocol-run\ntaskName=docs_probe_30d\nstatus=running\nprogressPath=metadata/scheduler-runs/fast-protocol-run.jsonl\ndiagnostic=\n")
        let runner = ProcessIsolatedSchedulerTaskRunner(newOfflineKnowledgeBase(), CkbRuntimeConfig(), store, "", storePath, DisabledNetworkFetchRunner(), workerPath)

        let task = runner.runTask("docs_probe_30d", "0", ckbCoreNowMillis() + 10000)

        @Expect(task.ok, false)
        @Expect(task.status, "task_worker_sidecar_missing")
        @Expect(task.status.startsWith("task_timeout:"), false)
        @Expect(task.schedulerRunId, "fast-protocol-run")
        @Expect(task.schedulerTaskName, "docs_probe_30d")
        @Expect(task.workerPid > 0, true)
        @Expect(p5S1ProcessExited(task.workerPid), true)
    }

    @TestCase
    public func p5S1N05HardTimeoutDoesNotOverwriteWrongIdentitySidecar(): Unit {
        let root = "target/p5-s1-n05-timeout-wrong-sidecar"
        ensureEmptyDir(root)
        let storePath = "${root}/store"
        let workerPath = "${root}/wrong-sidecar-worker.zsh"
        let childPidPath = "${root}/sleep-child.pid"
        let script = "#!/bin/zsh\nstorePath=''\nresultRel=''\nwhile [[ $# -gt 0 ]]; do\n  case \"$1\" in\n    --store) storePath=\"$2\"; shift 2 ;;\n    --result-rel) resultRel=\"$2\"; shift 2 ;;\n    *) shift ;;\n  esac\ndone\nsidecar=\"$storePath/$resultRel.sidecar\"\nprint -r -- 'ok=true\nstatus=conflicting_terminal\nschedulerRunId=wrong-run\nschedulerTaskName=docs_probe_30d\nresultWrittenAtMillis=123\n' > \"$sidecar\"\necho 'Out of memory 中文🙂' >&2\nsleep 30 &\nchild=$!\necho $child > ${childPidPath}\nwait $child\n"
        File.writeTo(Path(workerPath), script.toArray())
        @Expect(launch("/bin/chmod", ["700", workerPath]).wait(), 0)
        let store = FileKnowledgeStore(storePath)
        store.writeLinesAtomically("metadata/scheduler-current.ckb", "runId=protected-run\ntaskName=docs_probe_30d\nstatus=running\nprogressPath=metadata/scheduler-runs/protected-run.jsonl\ndiagnostic=\n")
        let runner = ProcessIsolatedSchedulerTaskRunner(newOfflineKnowledgeBase(), CkbRuntimeConfig(), store, "", storePath, DisabledNetworkFetchRunner(), workerPath)

        let task = runner.runTask("docs_probe_30d", "0", ckbCoreNowMillis() + 500)
        let workerName = p5S1WorkerFileNameForRun(storePath, "protected-run")
        let sidecarText = if (workerName != "") { store.readText("metadata/scheduler-workers/${workerName}.sidecar") } else { "" }
        var childPid: Int64 = 0
        if (exists(Path(childPidPath))) {
            try {
                childPid = Int64.parse(String.fromUtf8(File.readFrom(Path(childPidPath))).trimAscii())
            } catch (_: Exception) {
                childPid = 0
            }
        }

        @Expect(task.ok, false)
        @Expect(task.status, "task_worker_sidecar_run_mismatch")
        @Expect(task.status.startsWith("task_timeout:"), false)
        @Expect(task.lastStage, "worker_out_of_memory")
        @Expect(task.workerPid > 0, true)
        @Expect(task.workerErrSnippet.contains("Out of memory 中文🙂"), true)
        @Expect(p5S1StringListContains(task.validationDiagnostics, "worker_artifact:worker_out_of_memory"), true)
        @Expect(p5S1StringListContains(task.validationDiagnostics, "task_worker_out_of_memory"), false)
        @Expect(workerName != "", true)
        @Expect(sidecarText.contains("status=conflicting_terminal"), true)
        @Expect(sidecarText.contains("schedulerRunId=wrong-run"), true)
        @Expect(sidecarText.contains("task_timeout:docs_probe_30d"), false)
        @Expect(p5S1ProcessExited(task.workerPid), true)
        @Expect(childPid > 0, true)
        @Expect(p5S1ProcessExited(childPid), true)
    }

    @TestCase
    public func p5S1N06HardTimeoutDoesNotOverwriteUnconfirmedSidecar(): Unit {
        let root = "target/p5-s1-n06-timeout-unconfirmed-sidecar"
        ensureEmptyDir(root)
        let storePath = "${root}/store"
        let workerPath = "${root}/unconfirmed-sidecar-worker.zsh"
        let childPidPath = "${root}/sleep-child.pid"
        let script = "#!/bin/zsh\nstorePath=''\nresultRel=''\nwhile [[ $# -gt 0 ]]; do\n  case \"$1\" in\n    --store) storePath=\"$2\"; shift 2 ;;\n    --result-rel) resultRel=\"$2\"; shift 2 ;;\n    *) shift ;;\n  esac\ndone\nsidecar=\"$storePath/$resultRel.sidecar\"\nprint -r -- 'ok=true\nstatus=unconfirmed_candidate\nschedulerRunId=unconfirmed-run\nschedulerTaskName=docs_probe_30d\nresultWrittenAtMillis=0\n' > \"$sidecar\"\necho 'Out of memory 中文🙂' >&2\nsleep 30 &\nchild=$!\necho $child > ${childPidPath}\nwait $child\n"
        File.writeTo(Path(workerPath), script.toArray())
        @Expect(launch("/bin/chmod", ["700", workerPath]).wait(), 0)
        let store = FileKnowledgeStore(storePath)
        store.writeLinesAtomically("metadata/scheduler-current.ckb", "runId=unconfirmed-run\ntaskName=docs_probe_30d\nstatus=running\nprogressPath=metadata/scheduler-runs/unconfirmed-run.jsonl\ndiagnostic=\n")
        let runner = ProcessIsolatedSchedulerTaskRunner(newOfflineKnowledgeBase(), CkbRuntimeConfig(), store, "", storePath, DisabledNetworkFetchRunner(), workerPath)

        let task = runner.runTask("docs_probe_30d", "0", ckbCoreNowMillis() + 500)
        let workerName = p5S1WorkerFileNameForRun(storePath, "unconfirmed-run")
        let sidecarText = if (workerName != "") { store.readText("metadata/scheduler-workers/${workerName}.sidecar") } else { "" }
        var childPid: Int64 = 0
        if (exists(Path(childPidPath))) {
            try {
                childPid = Int64.parse(String.fromUtf8(File.readFrom(Path(childPidPath))).trimAscii())
            } catch (_: Exception) {
                childPid = 0
            }
        }

        @Expect(task.ok, false)
        @Expect(task.status, "task_worker_sidecar_unconfirmed")
        @Expect(task.status.startsWith("task_timeout:"), false)
        @Expect(task.lastStage, "worker_out_of_memory")
        @Expect(task.workerPid > 0, true)
        @Expect(task.workerErrSnippet.contains("Out of memory 中文🙂"), true)
        @Expect(p5S1StringListContains(task.validationDiagnostics, "worker_artifact:worker_out_of_memory"), true)
        @Expect(p5S1StringListContains(task.validationDiagnostics, "task_worker_out_of_memory"), false)
        @Expect(workerName != "", true)
        @Expect(sidecarText.contains("status=unconfirmed_candidate"), true)
        @Expect(sidecarText.contains("schedulerRunId=unconfirmed-run"), true)
        @Expect(sidecarText.contains("resultWrittenAtMillis=0"), true)
        @Expect(sidecarText.contains("task_timeout:docs_probe_30d"), false)
        @Expect(p5S1ProcessExited(task.workerPid), true)
        @Expect(childPid > 0, true)
        @Expect(p5S1ProcessExited(childPid), true)
    }

    @TestCase
    public func p5S1E2EDCliFinalizerPreservesSchedulerObserverFailure(): Unit {
        let root = "target/p5-s1-e2e-d-cli-observer"
        ensureEmptyDir(root)
        let storePath = "${root}/store"
        let configPath = "${root}/ckb-test.conf"
        let stdoutPath = "${root}/scheduler-run.stdout"
        let stderrPath = "${root}/scheduler-run.stderr"
        File.writeTo(Path(configPath), "networkEnabled=false\nschedulerEnabled=false\n".toArray())
        let store = FileKnowledgeStore(storePath)
        store.ensureLayout()
        File.writeTo(Path(storePath).join("metadata/scheduler-runs"), "blocked observer projection 中文🙂".toArray())

        var dyldLibraryPath = ""
        if (let Some(value) <- getVariable("DYLD_LIBRARY_PATH")) {
            dyldLibraryPath = value
        }
        let prelude = ckbSchedulerWorkerShellPreludeWithHeap(dyldLibraryPath, "") + "unset CKB_SCHEDULER_TASK_WORKER; "
        let command = prelude + "../target/release/bin/main --config ${configPath} --store ${storePath} scheduler-run --task weekly_full_rebuild --force --json > ${stdoutPath} 2> ${stderrPath}"
        let process = launch("/bin/zsh", ["-c", command], stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
        let code = process.wait()
        let wrapperStdout = p5S1SafeReadPipe(process.stdOutPipe)
        let wrapperStderr = p5S1SafeReadPipe(process.stdErrPipe)
        let stdout = p5S1SafeReadFile(Path(stdoutPath))
        let stderr = p5S1SafeReadFile(Path(stderrPath))

        @Expect(dyldLibraryPath != "", true)
        @Expect(code, 1)
        @Expect(stdout.contains("\"ran\":1"), true)
        @Expect(stdout.contains("\"succeeded\":1"), true)
        @Expect(stdout.contains("\"failed\":0"), true)
        @Expect(stdout.contains("\"businessOk\":true"), true)
        @Expect(stdout.contains("\"finalizationOk\":false"), true)
        @Expect(stdout.contains("scheduler_progress_observer_degraded:event=run_started"), true)
        @Expect(stdout.contains("scheduler_progress_observer_degraded:event=run_finished"), true)
        @Expect(stdout.contains("\"status\":\"rebuild_ok\""), true)
        @Expect(stdout.contains("task_exception"), false)
        @Expect(stdout.contains("blocked observer projection"), false)
        @Expect(wrapperStdout, "")
        @Expect(wrapperStderr, "")
        @Expect(stderr, "")
    }

    @TestCase
    public func schedulerRunWritesProgressArtifacts(): Unit {
        let root = "target/ckb-scheduler-progress-artifacts"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let scheduler = Scheduler(FakeClock(1000))
        let runner = ProgressFakeRunner()
        let executor = SchedulerExecutor(scheduler, runner, FileSchedulerProgressSink(store), 0)
        let tasks = ArrayList<String>()
        tasks.add("community_repo_discovery_30d")
        tasks.add("docs_probe_30d")

        let result = executor.runTaskNames(tasks, force: true)

        @Expect(result.ran, 2)
        @Expect(result.succeeded, 2)
        @Expect(result.runId != "", true)
        @Expect(result.progressPath != "", true)
        @Expect(store.has(result.progressPath), true)
        @Expect(store.has("metadata/scheduler-current.ckb"), true)
        @Expect(scheduler.entries[0].lastRunId, result.runId)
        @Expect(scheduler.entries[0].lastTerminalState, "succeeded")
        let progress = store.readText(result.progressPath)
        @Expect(progress.contains("\"subsystem\":\"scheduler\""), true)
        @Expect(progress.contains("\"stage\":\"task_finish\""), true)
        @Expect(progress.contains("\"durationMs\""), true)
        @Expect(progress.contains("\"deadlineAtMillis\""), true)
    }

    @TestCase
    public func schedulerDiagnosticsSidecarKeepsFullRedactedDiagnostics(): Unit {
        let root = "target/ckb-scheduler-diagnostics-sidecar"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let scheduler = Scheduler(FakeClock(1000))
        let runner = ProgressFakeRunner()
        runner.failTask = "docs_probe_30d"
        let executor = SchedulerExecutor(scheduler, runner, FileSchedulerProgressSink(store), 0)
        let tasks = ArrayList<String>()
        tasks.add("docs_probe_30d")

        let result = executor.runTaskNames(tasks, force: true)
        let diagnosticsPath = "metadata/scheduler-runs/${result.runId}-diagnostics.jsonl"
        let diagnostics = store.readText(diagnosticsPath)

        @Expect(result.failed, 1)
        @Expect(store.has(diagnosticsPath), true)
        @Expect(diagnostics.contains("task_diagnostic"), true)
        @Expect(diagnostics.contains("failure diagnostic 中文🙂"), true)
    }

    @TestCase
    public func schedulerWorkerPreludeRestoresDyldForZshWorker(): Unit {
        let withDyld = ckbSchedulerWorkerShellPreludeWithHeap("/tmp/runtime:/tmp/stdx", "4GB")
        let withoutDyld = ckbSchedulerWorkerShellPreludeWithHeap("", "")

        @Expect(withDyld.contains("export CKB_SCHEDULER_TASK_WORKER=1;"), true)
        @Expect(withDyld.contains("export cjHeapSize='4GB';"), true)
        @Expect(withDyld.contains("export DYLD_LIBRARY_PATH='/tmp/runtime:/tmp/stdx';"), true)
        @Expect(withoutDyld.contains("export CKB_SCHEDULER_TASK_WORKER=1;"), true)
        @Expect(withoutDyld.contains("DYLD_LIBRARY_PATH"), false)
        @Expect(withoutDyld.contains("cjHeapSize"), false)
        @Expect(ckbSchedulerDefaultCjHeapSizeForTask("cangjie_docs_full_weekly", ""), "4GB")
        @Expect(ckbSchedulerDefaultCjHeapSizeForTask("cangjie_docs_full_weekly", "6GB"), "6GB")
        @Expect(ckbSchedulerDefaultCjHeapSizeForTask("docs_probe_30d", ""), "")
    }

    @TestCase
    public func schedulerTimeoutMarksPartialAndContinuesFollowingTask(): Unit {
        let scheduler = Scheduler(FakeClock(1000))
        let runner = ProgressFakeRunner()
        runner.timeoutTask = "community_repo_discovery_30d"
        let executor = SchedulerExecutor(scheduler, runner, NoopSchedulerProgressSink(), 20)
        let tasks = ArrayList<String>()
        tasks.add("community_repo_discovery_30d")
        tasks.add("docs_probe_30d")

        let result = executor.runTaskNames(tasks, force: true)

        @Expect(result.ran, 2)
        @Expect(result.failed, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.timedOut, true)
        @Expect(result.partial, true)
        @Expect(result.details.contains("task community_repo_discovery_30d ok=false status=task_timeout:community_repo_discovery_30d"), true)
        @Expect(result.details.contains("task docs_probe_30d ok=true status=ok"), true)
        @Expect(scheduler.entries[0].timeBudgetMillis, 20)
    }

    @TestCase
    public func staleSchedulerAndVectorCurrentFilesRecoverBeforeNextRun(): Unit {
        // NEG-S5-001: stale recovery marks old scheduler/vector runs and clears current blockers.
        let root = "target/ckb-scheduler-stale-recovery"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        store.writeLinesAtomically("metadata/scheduler-runs/stale-scheduler.jsonl", "")
        store.writeLinesAtomically("metadata/vector-reconcile-runs/stale-vector.jsonl", "")
        store.writeLinesAtomically("metadata/scheduler-current.ckb", "runId=stale-scheduler\ntaskName=weekly_full_rebuild\nstatus=running\nprogressPath=metadata/scheduler-runs/stale-scheduler.jsonl\ndiagnostic=\n")
        store.writeLinesAtomically("metadata/vector-reconcile-current.ckb", "runId=stale-vector\ncollection=ckb_staging\ntargetCollection=ckb_staging\nstate=running\ncurrentBatch=7\ncompleted=112\nfailed=0\nreused=64\nembedded=48\nprogressPath=metadata/vector-reconcile-runs/stale-vector.jsonl\ndiagnostic=\n")

        let recovery = ckbRecoverStaleSchedulerRuns(store)

        @Expect(recovery.recoveredScheduler, true)
        @Expect(recovery.recoveredVector, true)
        @Expect(store.readText("metadata/scheduler-current.ckb").contains("status=aborted_stale_run"), true)
        @Expect(store.readText("metadata/vector-reconcile-current.ckb").contains("state=aborted_stale_run"), true)
        @Expect(store.readText("metadata/vector-reconcile-current.ckb").contains("completed=112"), true)
        @Expect(store.readText("metadata/vector-reconcile-current.ckb").contains("reused=64"), true)
        @Expect(store.readText("metadata/scheduler-runs/stale-scheduler.jsonl").contains("stale_recovered"), true)
        @Expect(store.readText("metadata/vector-reconcile-runs/stale-vector.jsonl").contains("stale_recovered"), true)
    }

    @TestCase
    public func schedulerRunLockBlocksConcurrentUnexpiredRunAndRecoversExpiredRun(): Unit {
        let root = "target/ckb-scheduler-run-lock"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let first = ckbAcquireSchedulerRunLock(store, "run-a", ckbCoreNowMillis() + 60000, "cmd-a")
        let busy = ckbAcquireSchedulerRunLock(store, "run-b", ckbCoreNowMillis() + 60000, "cmd-b")

        @Expect(first.ok, true)
        @Expect(busy.ok, false)
        @Expect(busy.status, "scheduler_busy")
        @Expect(busy.diagnostic.contains("run-a"), true)

        store.writeLinesAtomically("metadata/scheduler-lock.ckb", "runId=old-run\nstatus=running\ndeadlineAtMillis=1\nownerCommandHash=old\ndiagnostic=stale\n")
        let recovered = ckbAcquireSchedulerRunLock(store, "run-c", ckbCoreNowMillis() + 60000, "cmd-c")

        @Expect(recovered.ok, true)
        @Expect(recovered.diagnostic.contains("scheduler_lock_recovered_expired"), true)
        @Expect(store.readText("metadata/scheduler-lock.ckb").contains("runId=run-c"), true)

        ckbReleaseSchedulerRunLock(store, recovered, "run-c-final", "succeeded")
        @Expect(store.readText("metadata/scheduler-lock.ckb").contains("status=succeeded"), true)
    }

    @TestCase
    public func scopedVectorCurrentIsWrittenForSchedulerTask(): Unit {
        let root = "target/ckb-scoped-vector-current"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        store.writeLinesAtomically("metadata/scheduler-current.ckb", "runId=scheduler-a\ntaskName=weekly_full_rebuild\nstatus=running\nprogressPath=metadata/scheduler-runs/scheduler-a.jsonl\ndiagnostic=\n")
        let progress = VectorBuildProgress()
        progress.runId = "vector-a"
        progress.collection = "ckb_candidate"
        progress.targetCollection = "ckb_staging"
        progress.state = "running"
        progress.currentBatch = 3
        progress.completed = 42
        let sink = FileVectorBuildProgressSink(store, schedulerRunId: "scheduler-a", schedulerTaskName: "weekly_full_rebuild")

        sink.onVectorBatchStarted(progress)

        let scoped = "metadata/scheduler-runs/scheduler-a-weekly_full_rebuild-vector-current.ckb"
        @Expect(store.has("metadata/vector-reconcile-current.ckb"), true)
        @Expect(store.has(scoped), true)
        @Expect(store.readText(scoped).contains("schedulerRunId=scheduler-a"), true)
        @Expect(store.readText(scoped).contains("schedulerTaskName=weekly_full_rebuild"), true)
        @Expect(store.readText(scoped).contains("completed=42"), true)
    }

    @TestCase
    public func p2Ut001TaskScopedProgressPrefersVersionRefreshCheckpoint(): Unit {
        let root = "target/p2-ut001-task-scoped-progress"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        store.writeLinesAtomically("metadata/routine-stage-checkpoints/cangjie_version_branch_refresh-fetch_tree_page.ckb", "profile=cangjie_version_branch_refresh\nstage=fetch_tree_page\nstatus=running\nbudgetMillis=70000\ndeadlineAtMillis=999999999999\nremainingMillis=70000\ndiagnostic=sourceSet=tools|repo=Cangjie/cangjie_tools|page=11\n")
        store.writeLinesAtomically("metadata/vector-reconcile-current.ckb", "runId=old-vector\ncollection=ckb_active\nstate=running\ncurrentBatch=9\ncompleted=800\nprogressPath=metadata/vector-reconcile-runs/old-vector.jsonl\ndiagnostic=weekly_full_rebuild\n")

        let progress = ckbSchedulerWorkerLastProgressFromStoreForTask(store, "cangjie_version_branch_refresh")

        @Expect(progress.contains("routine:profile=cangjie_version_branch_refresh"), true)
        @Expect(progress.contains("stage=fetch_tree_page"), true)
        @Expect(progress.contains("sourceSet=tools"), true)
        @Expect(progress.contains("vector:"), false)
    }

    @TestCase
    public func p3Ut001TaskScopedProgressPrefersDocsRoutineCheckpoint(): Unit {
        let root = "target/p3-ut001-docs-task-scoped-progress"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        store.writeLinesAtomically("metadata/routine-stage-checkpoints/cangjie_docs_full_sync-fetch_tree_page.ckb", "profile=cangjie_docs_full_sync\nstage=fetch_tree_page\nstatus=running\nbudgetMillis=60000\ndeadlineAtMillis=999999999999\nremainingMillis=60000\ndiagnostic=sourceSet=docs|repo=Cangjie/cangjie_docs|page=14\n")
        store.writeLinesAtomically("metadata/staged-rebuild-current.ckb", "stage=staged_rebuild_status_before\nstatus=running\ndiagnostic=old-global-progress\n")

        let progress = ckbSchedulerWorkerLastProgressFromStoreForTask(store, "cangjie_docs_full_weekly")

        @Expect(progress.contains("routine:profile=cangjie_docs_full_sync"), true)
        @Expect(progress.contains("stage=fetch_tree_page"), true)
        @Expect(progress.contains("sourceSet=docs"), true)
        @Expect(progress.contains("old-global-progress"), false)
    }

    @TestCase
    public func p3Neg001ExplicitTaskProgressDoesNotReadStaleGlobalVectorCurrent(): Unit {
        let root = "target/p3-neg001-explicit-task-no-global-vector"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        store.writeLinesAtomically("metadata/vector-reconcile-current.ckb", "runId=old-vector\ncollection=ckb_active\nstate=running\ncurrentBatch=9\ncompleted=800\nprogressPath=metadata/vector-reconcile-runs/old-vector.jsonl\ndiagnostic=old-global-vector\n")

        let progress = ckbSchedulerWorkerLastProgressFromStoreForTask(store, "cangjie_release_full_sync")

        @Expect(progress.contains("vector:"), false)
        @Expect(progress.contains("old-global-vector"), false)
        @Expect(progress, "")
    }

    @TestCase
    public func p4U7ExplicitDocsTaskLastStageDoesNotReadStaleGlobalStagedCurrent(): Unit {
        let root = "target/p4-u7-docs-task-no-global-stage"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        store.writeLinesAtomically("metadata/staged-rebuild-current.ckb", "stage=staged_rebuild_vector_before\nstatus=running\nremainingMillis=1\ndiagnostic=old-global-stage\n")

        let stage = ckbSchedulerWorkerLastStageFromStoreForTask(store, "cangjie_docs_full_weekly")

        @Expect(stage.contains("staged_rebuild_vector_before"), false)
        @Expect(stage.contains("old-global-stage"), false)
        @Expect(stage, "")
    }

    @TestCase
    public func p4N3ExplicitDocsTaskLastStagePrefersScopedCandidateStage(): Unit {
        let root = "target/p4-n3-docs-task-scoped-stage"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        store.writeLinesAtomically("metadata/scheduler-current.ckb", "runId=scheduler-p4\ntaskName=cangjie_docs_full_weekly\nstatus=running\nprogressPath=metadata/scheduler-runs/scheduler-p4.jsonl\ndiagnostic=\n")
        store.writeLinesAtomically("metadata/staged-rebuild-current.ckb", "stage=staged_rebuild_vector_before\nstatus=running\ndiagnostic=old-global-stage\n")
        store.writeLinesAtomically("metadata/scheduler-runs/scheduler-p4-cangjie_docs_full_weekly-staged-rebuild-current.ckb", "runId=scheduler-p4\ntaskName=cangjie_docs_full_weekly\nstage=candidate_active_commit_started\nstatus=running\nprogressPath=metadata/scheduler-runs/scheduler-p4.jsonl\ndiagnostic=p4-active-commit\natMillis=3\n")

        let stage = ckbSchedulerWorkerLastStageFromStoreForTask(store, "cangjie_docs_full_weekly")

        @Expect(stage, "candidate_active_commit_started")
    }

    @TestCase
    public func p1Ut001StagedRebuildFileSinkWritesSchedulerProgressAndCurrent(): Unit {
        let root = "target/p1-ut001-staged-rebuild-file-sink"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let sink = FileCkbStagedRebuildStageSink(store, schedulerRunId: "run-p1", schedulerTaskName: "weekly_full_rebuild")
        let progress = CkbStagedRebuildStageProgress()
        progress.stage = "staged_rebuild_status_before"
        progress.status = "running"
        progress.diagnostic = "diagnostic 中文🙂 Authorization: Bearer secret-value"
        progress.deadlineAtMillis = ckbCoreNowMillis() + 60000
        progress.remainingMillis = 60000
        progress.atMillis = ckbCoreNowMillis()

        sink.onStagedRebuildStage(progress)

        let progressPath = "metadata/scheduler-runs/run-p1.jsonl"
        let scopedPath = "metadata/scheduler-runs/run-p1-weekly_full_rebuild-staged-rebuild-current.ckb"
        let progressText = store.readText(progressPath)
        @Expect(progressText.contains("\"subsystem\":\"routine_update\""), true)
        @Expect(progressText.contains("\"event\":\"staged_rebuild_stage\""), true)
        @Expect(progressText.contains("\"stage\":\"staged_rebuild_status_before\""), true)
        @Expect(progressText.contains("secret-value"), false)
        @Expect(store.readText("metadata/staged-rebuild-current.ckb").contains("stage=staged_rebuild_status_before"), true)
        @Expect(store.has(scopedPath), true)
        @Expect(store.readText("metadata/scheduler-current.ckb").contains("taskName=weekly_full_rebuild"), true)
    }

    @TestCase
    public func p1Ut002WeeklyFullRebuildUsesDedicatedBudget(): Unit {
        let profile = ckbSyncProfileForScheduleTask("weekly_full_rebuild")

        @Expect(profile.timeBudgetMillis, 300000)
        @Expect(profile.fetchBudgetMillis, 0)
        @Expect(profile.ingestBudgetMillis, 30000)
        @Expect(profile.vectorBudgetMillis, 150000)
        @Expect(profile.validationBudgetMillis, 60000)
        @Expect(profile.snapshotBudgetMillis, 45000)
        @Expect(profile.proofBudgetMillis, 15000)
        @Expect(ckbSchedulerProfileStageBudgetDiagnostic(profile).contains("profile=full_rebuild"), true)
    }

    @TestCase
    public func p4P6DocsFullWeeklyUsesObservedEndToEndBudget(): Unit {
        let profile = ckbSyncProfileForScheduleTask("cangjie_docs_full_weekly")
        let diagnostic = ckbSchedulerProfileStageBudgetDiagnostic(profile)

        @Expect(profile.timeBudgetMillis, 360000)
        @Expect(profile.fetchBudgetMillis, 60000)
        @Expect(profile.ingestBudgetMillis, 20000)
        @Expect(profile.vectorBudgetMillis, 180000)
        @Expect(profile.validationBudgetMillis, 40000)
        @Expect(profile.snapshotBudgetMillis, 50000)
        @Expect(profile.proofBudgetMillis, 0)
        @Expect(diagnostic.contains("profile=cangjie_docs_full_sync"), true)
        @Expect(diagnostic.contains("timeBudgetMs=360000"), true)
    }

    @TestCase
    public func p1Ut003SnapshotTransactionEmitsStageCheckpoints(): Unit {
        let root = "target/p1-ut003-snapshot-stage-checkpoints"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let kb = newOfflineKnowledgeBase()
        let rebuild = ckbRebuildIndex(kb, store, deadlineAtMillis: ckbCoreNowMillis() + 60000)
        let sink = CaptureStageSink()

        kb.persistActiveSnapshotUsingVectorRecords(store, kb.lastVectorIndexBuild().vectorRecords, persistVectorFile: false, deadlineAtMillis: ckbCoreNowMillis() + 60000, stageSink: sink)

        @Expect(rebuild.ok, true)
        @Expect(sink.stages.contains("active_snapshot_tx_raw_before|running"), true)
        @Expect(sink.stages.contains("active_snapshot_tx_raw_after|ok"), true)
        @Expect(sink.stages.contains("active_snapshot_tx_vector_skipped|skipped"), true)
        @Expect(sink.stages.contains("active_snapshot_tx_graph_before|running"), true)
        @Expect(sink.stages.contains("active_snapshot_live_vector_skipped|skipped"), true)
        @Expect(sink.stages.contains("active_snapshot_manifest_after|ok"), true)
        @Expect(captureContains(sink.diagnostics, "graphEdgeCount="), true)
        @Expect(captureContains(sink.diagnostics, "persistVectorFile=false"), true)
    }

    @TestCase
    public func p4P7ActiveSnapshotLiveShadowCopiesCommittedSnapshotFiles(): Unit {
        let root = "target/p4-p7-active-snapshot-live-shadow-copy"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let kb = newOfflineKnowledgeBase()
        let sink = CaptureStageSink()

        kb.persistActiveSnapshotUsingVectorRecords(store, ArrayList<VectorRecord>(), persistVectorFile: false, deadlineAtMillis: ckbCoreNowMillis() + 60000, stageSink: sink)
        let txId = testField(store.readText("metadata/active-snapshot.manifest"), "txId")

        @Expect(txId != "", true)
        @Expect(store.readText("raw/records.ckb"), store.readText("transactions/${txId}/raw/records.ckb"))
        @Expect(store.readText("normalized/records.ckb"), store.readText("transactions/${txId}/normalized/records.ckb"))
        @Expect(store.readText("index/active.ckb"), store.readText("transactions/${txId}/index/active.ckb"))
        @Expect(store.readText("metadata/status.ckb"), store.readText("transactions/${txId}/metadata/status.ckb"))
        @Expect(store.has("transactions/${txId}/raw/doc/doc-syntax.ckb"), true)
        @Expect(store.has("raw/doc/doc-syntax.ckb"), true)
        @Expect(store.readText("raw/doc/doc-syntax.ckb"), store.readText("transactions/${txId}/raw/doc/doc-syntax.ckb"))
        @Expect(sink.stages.contains("active_snapshot_live_raw_after|ok"), true)
        @Expect(sink.stages.contains("active_snapshot_live_status_after|ok"), true)
        @Expect(sink.stages.contains("active_snapshot_manifest_after|ok"), true)
    }

    @TestCase
    public func s3Ut001ExpiredStagedFullRebuildReturnsDeadlineWithoutActiveManifest(): Unit {
        let root = "target/s3-ut001-expired-staged-rebuild"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let kb = newOfflineKnowledgeBase()
        kb.configureVectorCollections("ckb_active", "ckb_candidate")
        let config = s3QdrantRuntimeConfig()

        let result = ckbStagedFullRebuild(kb, store, config, NoopVectorBuildProgressSink(), ckbCoreNowMillis() - 1)

        @Expect(result.ok, false)
        @Expect(result.failedVersion.contains("deadline_exceeded:"), true)
        @Expect(store.has("metadata/active-snapshot.manifest"), false)
    }

    @TestCase
    public func s3Ut002SnapshotDeadlineDoesNotWriteCommitOrActiveManifest(): Unit {
        let root = "target/s3-ut002-snapshot-deadline"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let kb = newOfflineKnowledgeBase()
        var diagnostic = ""

        try {
            kb.persistActiveSnapshot(store, deadlineAtMillis: ckbCoreNowMillis() - 1)
        } catch (e: Exception) {
            diagnostic = e.message
        }

        @Expect(diagnostic.contains("deadline_exceeded:"), true)
        @Expect(store.has("metadata/active-snapshot.manifest"), false)
        @Expect(store.has("transactions"), false)
        @Expect(store.readText("metadata/active-snapshot.manifest"), "")
    }

    @TestCase
    public func s3Bnd001LargeTimeoutHasStructuredNonEmptyWorkerResult(): Unit {
        let root = "target/s3-bnd001-worker-timeout-result"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let resultPath = "metadata/scheduler-workers/weekly_full_rebuild-bnd.ckb"

        let task = ckbWriteSchedulerWorkerTimeoutCompensation(store, resultPath, "weekly_full_rebuild", "0", 120001, 120000, "deadline_exceeded:rebuild_graph_after:records=9001")

        @Expect(task.ok, false)
        @Expect(task.status, "task_timeout:weekly_full_rebuild")
        @Expect(store.readText(resultPath).size > 0, true)
        @Expect(store.readText(resultPath).contains("task_worker_hard_timeout"), false)
        @Expect(store.readText(resultPath).contains("deadline_exceeded:rebuild_graph_after"), true)
    }

    @TestCase
    public func s3Pos001FullRebuildWithDeadlinePersistsActiveSnapshot(): Unit {
        let root = "target/s3-pos001-full-rebuild"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let kb = newOfflineKnowledgeBase()

        let result = ckbRebuildIndex(kb, store, deadlineAtMillis: ckbCoreNowMillis() + 60000)
        let snapshot = store.loadActiveSnapshot()

        @Expect(result.ok, true)
        @Expect(store.has("metadata/active-snapshot.manifest"), true)
        @Expect(snapshot.valid, true)
        @Expect(snapshot.activeIndex.size, result.count)
    }

    @TestCase
    public func s3Neg001SnapshotWriteExceptionReturnsFailureWithoutManifest(): Unit {
        let parent = "target/s3-neg001-snapshot-write-exception"
        ensureEmptyDir(parent)
        let root = "${parent}/store-file"
        File.writeTo(Path(root), "not-a-directory\n".toArray())
        let store = FileKnowledgeStore(root)
        let kb = newOfflineKnowledgeBase()

        let result = ckbRebuildIndex(kb, store, deadlineAtMillis: ckbCoreNowMillis() + 60000)

        @Expect(result.ok, false)
        @Expect(result.failedVersion.contains("active_snapshot_write_failed"), true)
    }

    @TestCase
    public func s5Ut001HardTimeoutEmptyResultWritesCompensationSidecar(): Unit {
        let root = "target/s5-ut001-worker-compensation"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let resultPath = "metadata/scheduler-workers/weekly-empty.ckb"
        store.writeLinesAtomically(resultPath, "")

        let task = ckbWriteSchedulerWorkerTimeoutCompensation(store, resultPath, "weekly_full_rebuild", "0", 120001, 120000, "task_worker_hard_timeout", lastStage: "native_http_timeout", lastProgress: "vector:completed=64,currentBatch=1", workerPid: 12345, outSnippet: "WARN timeout", errSnippet: "Authorization: Bearer secret-value timeout", schedulerRunId: "timeout-run")
        let text = store.readText(resultPath)
        let primary = ckbSchedulerTaskResultFromText(text)
        let confirmed = ckbSchedulerTaskResultFromText(store.readText("${resultPath}.sidecar"))

        @Expect(task.status, "task_timeout:weekly_full_rebuild")
        @Expect(task.lastStage, "native_http_timeout")
        @Expect(task.lastProgress.contains("completed=64"), true)
        @Expect(task.workerPid, 12345)
        @Expect(task.schedulerRunId, "timeout-run")
        @Expect(task.schedulerTaskName, "weekly_full_rebuild")
        @Expect(primary.resultWrittenAtMillis, 0)
        @Expect(confirmed.schedulerRunId, "timeout-run")
        @Expect(confirmed.schedulerTaskName, "weekly_full_rebuild")
        @Expect(confirmed.status, "task_timeout:weekly_full_rebuild")
        @Expect(confirmed.resultWrittenAtMillis >= confirmed.taskBodyEndedAtMillis, true)
        @Expect(confirmed.resultFlushDurationMillis, confirmed.resultWrittenAtMillis - confirmed.taskBodyEndedAtMillis)
        @Expect(task.resultWrittenAtMillis, confirmed.resultWrittenAtMillis)
        @Expect(task.resultFlushDurationMillis, confirmed.resultFlushDurationMillis)
        @Expect(store.readText(resultPath).size > 0, true)
        @Expect(store.readText("${resultPath}.sidecar").contains("task_worker_hard_timeout"), true)
        @Expect(text.contains("lastStage=native_http_timeout"), true)
        @Expect(text.contains("workerPid=12345"), true)
        @Expect(text.contains("secret-value"), false)
        @Expect(store.readText("${resultPath}.sidecar").contains("secret-value"), false)
    }

    @TestCase
    public func p5S1U02BootstrapFailureUsesRecoveryPrimaryAndConfirmedSidecar(): Unit {
        let root = "target/p5-s1-u02-bootstrap-terminal"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let resultPath = "metadata/scheduler-workers/docs-bootstrap.ckb"
        let bootstrapStartedAtMillis = ckbCoreNowMillis() - 10

        let task = ckbWriteSchedulerTaskBootstrapFailure(store, "docs_probe_30d", "0", ckbCoreNowMillis() + 1000, resultPath, "bootstrap-run", bootstrapStartedAtMillis, "启动失败 中文🙂 Authorization: Bearer secret-value")
        let primaryText = store.readText(resultPath)
        let sidecarText = store.readText("${resultPath}.sidecar")
        let primary = ckbSchedulerTaskResultFromText(primaryText)
        let confirmed = ckbSchedulerTaskResultFromText(sidecarText)

        @Expect(task.ok, false)
        @Expect(task.status, "task_bootstrap_failed")
        @Expect(primary.resultWrittenAtMillis, 0)
        @Expect(primary.schedulerRunId, "bootstrap-run")
        @Expect(primary.schedulerTaskName, "docs_probe_30d")
        @Expect(confirmed.status, "task_bootstrap_failed")
        @Expect(confirmed.schedulerRunId, "bootstrap-run")
        @Expect(confirmed.schedulerTaskName, "docs_probe_30d")
        @Expect(confirmed.resultWrittenAtMillis >= confirmed.taskBodyEndedAtMillis, true)
        @Expect(confirmed.resultFlushDurationMillis, confirmed.resultWrittenAtMillis - confirmed.taskBodyEndedAtMillis)
        @Expect(task.resultWrittenAtMillis, confirmed.resultWrittenAtMillis)
        @Expect(task.resultFlushDurationMillis, confirmed.resultFlushDurationMillis)
        @Expect(primaryText.contains("中文🙂"), true)
        @Expect(sidecarText.contains("中文🙂"), true)
        @Expect(primaryText.contains("secret-value"), false)
        @Expect(sidecarText.contains("secret-value"), false)
    }

    @TestCase
    public func s5Ut002WorkerInternalDeadlineWritesTaskTimeoutResult(): Unit {
        let root = "target/s5-ut002-worker-internal-deadline"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let kb = newOfflineKnowledgeBase()
        let resultPath = "metadata/scheduler-workers/weekly-internal-timeout.ckb"

        let task = ckbRunSchedulerTaskWorker(kb, CkbRuntimeConfig(), store, "weekly_full_rebuild", "0", ckbCoreNowMillis() - 1, resultPath)

        @Expect(task.ok, false)
        @Expect(task.status, "task_timeout:weekly_full_rebuild")
        @Expect(store.readText(resultPath).contains("task_timeout:weekly_full_rebuild"), true)
        @Expect(store.readText(resultPath).size > 0, true)
    }

    @TestCase
    public func s5Bnd001MalformedWorkerResultIsReportedAndPreserved(): Unit {
        let root = "target/s5-bnd001-malformed-worker"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let resultPath = "metadata/scheduler-workers/malformed.ckb"
        store.writeLinesAtomically(resultPath, "this is not a scheduler result\n")

        let parsed = ckbReadSchedulerWorkerResultFile(root, resultPath, "weekly_full_rebuild", "0", 10, 100)

        @Expect(parsed.ok, false)
        @Expect(parsed.status, "task_worker_result_malformed")
        @Expect(store.readText(resultPath), "this is not a scheduler result\n")
    }

    @TestCase
    public func s5Bnd002WorkerStartedResultIsReportedAsIncomplete(): Unit {
        let root = "target/s5-bnd002-worker-started-incomplete"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let resultPath = "metadata/scheduler-workers/started.ckb"
        store.writeLinesAtomically(resultPath, "status=worker_started\ntaskName=weekly_full_rebuild\nsince=0\nstartedAtMillis=10\ndeadlineAtMillis=110\n")

        let parsed = ckbReadSchedulerWorkerResultFile(root, resultPath, "weekly_full_rebuild", "0", 20, 100)

        @Expect(parsed.ok, false)
        @Expect(parsed.status, "task_worker_result_incomplete")
        @Expect(parsed.validationDiagnostics.contains("weekly_full_rebuild:task_worker_result_incomplete"), true)
    }

    @TestCase
    public func s5Pos001NormalWorkerResultRoundTripsWithProgressFields(): Unit {
        let root = "target/s5-pos001-worker-success"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let resultPath = "metadata/scheduler-workers/docs-ok.ckb"
        let task = SchedulerTaskResult()
        task.ok = true
        task.status = "ok"
        task.since = "0"
        task.durationMillis = 5
        task.timeBudgetMillis = 100
        task.lastStage = "fetch"
        task.lastProgress = "requests=1"
        task.workerPid = 88
        task.workerOutSnippet = "ok 中文🙂"
        task.workerErrSnippet = "stderr empty"
        task.validationDiagnostics.add("progress=complete")
        store.writeLinesAtomically(resultPath, ckbSchedulerTaskResultText(task))

        let parsed = ckbReadSchedulerWorkerResultFile(root, resultPath, "docs_probe_30d", "0", 5, 100)

        @Expect(parsed.ok, true)
        @Expect(parsed.status, "ok")
        @Expect(parsed.timeBudgetMillis, 100)
        @Expect(parsed.lastStage, "fetch")
        @Expect(parsed.lastProgress, "requests=1")
        @Expect(parsed.workerPid, 88)
        @Expect(parsed.workerOutSnippet.contains("中文🙂"), true)
        @Expect(parsed.workerErrSnippet, "stderr empty")
        @Expect(parsed.validationDiagnostics.contains("progress=complete"), true)
    }

    @TestCase
    public func s5Pos002TaskFinishedProgressIncludesWorkerTimeoutFields(): Unit {
        let root = "target/s5-pos002-progress-timeout-fields"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let scheduler = Scheduler(FakeClock(1000))
        let runner = ProgressFakeRunner()
        runner.timeoutTask = "docs_probe_30d"
        let executor = SchedulerExecutor(scheduler, runner, FileSchedulerProgressSink(store), 20)
        let tasks = ArrayList<String>()
        tasks.add("docs_probe_30d")

        let result = executor.runTaskNames(tasks, force: true)
        let progress = store.readText(result.progressPath)

        @Expect(result.failed, 1)
        @Expect(progress.contains("\"event\":\"task_finished\""), true)
        @Expect(progress.contains("\"lastStage\""), true)
        @Expect(progress.contains("\"workerErrSnippet\""), true)
    }

    @TestCase
    public func activeSnapshotRepairRestoresLiveShadowFromCommittedManifest(): Unit {
        let root = "target/ckb-active-snapshot-live-shadow-repair"
        ensureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let kb = newOfflineKnowledgeBase()
        let rebuild = ckbRebuildIndex(kb, store)
        let activeVersion = store.readText("index/active.version")
        let statusText = store.readText("metadata/status.ckb")
        let manifest = store.readText("metadata/active-snapshot.manifest")
        let txId = testField(manifest, "txId")

        store.writeLinesAtomically("index/active.version", "stale-live\n")
        store.writeLinesAtomically("metadata/status.ckb", "active=stale-live\nvectorActiveCollection=stale-live\n")

        let repair = store.repairActiveLiveShadowFromManifest()

        @Expect(rebuild.ok, true)
        @Expect(txId != "", true)
        @Expect(repair.ok, true)
        @Expect(repair.repairPerformed, true)
        @Expect(store.readText("index/active.version"), activeVersion)
        @Expect(store.readText("metadata/status.ckb"), statusText)
        @Expect(store.has("metadata/active-snapshot-commits/${txId}.ckb"), true)
    }
}

private func s3QdrantRuntimeConfig(): CkbRuntimeConfig {
    let config = CkbRuntimeConfig()
    config.vectorBackend = "qdrant"
    config.vectorActiveCollection = "ckb_active"
    config.vectorCandidateCollection = "ckb_candidate"
    config.vectorDimensions = 16
    config.vectorDistance = "Cosine"
    config
}

private func p5S2RequiredChildVariable(name: String): String {
    if (let Some(value) <- getVariable(name)) {
        return value
    }
    throw Exception("missing p5 s2 child variable ${name}")
}

private func p5S2E2EManifest(): CangjieVersionManifest {
    let manifest = CangjieVersionManifest()
    manifest.defaultTargetVersion = cangjieDefaultTargetVersion()
    p5S2AddE2ESource(manifest, CangjieSourceSets.DOCS, "docs", "Cangjie/cangjie_docs")
    p5S2AddE2ESource(manifest, CangjieSourceSets.STD, "stdlib", "Cangjie/cangjie_runtime")
    p5S2AddE2ESource(manifest, CangjieSourceSets.STDX, "stdx", "Cangjie/cangjie_stdx")
    p5S2AddE2ESource(manifest, CangjieSourceSets.TOOLS, "tools", "Cangjie/cangjie_tools")
    p5S2AddE2ESource(manifest, CangjieSourceSets.EVAL_SUPPORT, "eval-support", "CangjieCommunityKnowledgeBase/Cangjie-HumanEval")
    manifest
}

private func p5S2AddE2ESource(manifest: CangjieVersionManifest, sourceSet: String, sourceFamily: String, repo: String): Unit {
    let source = CangjieVersionSource()
    source.targetVersion = cangjieDefaultTargetVersion()
    source.sourceSet = sourceSet
    source.sourceFamily = sourceFamily
    source.sourceRepo = repo
    source.sourceRef = "release-1.0.0"
    source.refKind = "branch"
    source.resolvedCommit = "abcdef0123456789abcdef0123456789abcdef01"
    source.contentHash = "sha256:p5-s2-e2e-${sourceSet}"
    source.rootKind = "scheduled:test-child"
    manifest.sources.add(source)
}

private class P5S2E2EReleaseRunner <: SourceFetchRunner {
    private let delegate: FakeSourceFetchRunner = FakeSourceFetchRunner()

    init() {}

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        if (request.kind == SourceKinds.GITCODE_TREE && request.page > 1) {
            let result = SourceFetchResult()
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.sourceUrl = request.url
            result.repo = request.repo
            result.ref = request.ref
            result.path = request.path
            result.normalizedType = request.kind
            result.contentType = "application/json"
            result.commit = "abcdef0123456789abcdef0123456789abcdef01"
            result.body = "{\"tree\":[],\"sha\":\"${result.commit}\"}"
            result.bytes = result.body.size
            result.bodyHash = stableSummaryHash(result.body)
            result.attempts = 1
            return result
        }
        this.delegate.fetch(request)
    }
}

private func p5S2WriteEvalFixture(root: String): String {
    p5S2WriteFixtureFile(Path(root).join("CJ-HUMANEVAL-000/prompt.md"), "# Task\nUse EvalValue and EvalEntry.\n")
    p5S2WriteFixtureFile(Path(root).join("CJ-HUMANEVAL-000/metadata.json"), "{\"id\":\"CJ-HUMANEVAL-000\"}\n")
    p5S2WriteFixtureFile(Path(root).join("CJ-HUMANEVAL-000/starter/src/eval_support.cj"), "public class EvalValue {}\npublic class EvalEntry {}\n")
    p5S2WriteFixtureFile(Path(root).join("CJ-HUMANEVAL-000/tests/TestMain.cj"), "public func helper(): Unit {}\nmain() {}\n")
    root
}

private func p5S2WriteFixtureFile(path: Path, content: String): Unit {
    if (!exists(path.parent)) {
        Directory.create(path.parent, recursive: true)
    }
    File.writeTo(path, content.toArray())
}

private func ensureEmptyDir(path: String): Unit {
    if (exists(Path(path))) {
        _ = launch("/bin/rm", ["-rf", path]).wait()
    }
    Directory.create(Path(path), recursive: true)
}

private func captureContains(items: ArrayList<String>, expected: String): Bool {
    for (item in items) {
        if (item.contains(expected)) {
            return true
        }
    }
    false
}

private func p5S1StringListContains(items: ArrayList<String>, expected: String): Bool {
    for (item in items) {
        if (item.contains(expected)) {
            return true
        }
    }
    false
}

private func p5S1TerminalWorkerFileName(storePath: String, schedulerRunId: String): String {
    let workerDir = Path(storePath).join("metadata/scheduler-workers")
    if (!exists(workerDir)) {
        return ""
    }
    for (entry in Directory.readFrom(workerDir)) {
        if (!entry.isRegular() || !entry.name.endsWith(".ckb")) {
            continue
        }
        let text = p5S1SafeReadFile(entry.path)
        if (text.contains("schedulerRunId=${schedulerRunId}") && !text.contains("status=worker_started")) {
            return entry.name
        }
    }
    ""
}

private func p5S1WorkerFileNameForRun(storePath: String, schedulerRunId: String): String {
    let workerDir = Path(storePath).join("metadata/scheduler-workers")
    if (!exists(workerDir)) {
        return ""
    }
    for (entry in Directory.readFrom(workerDir)) {
        if (entry.isRegular() && entry.name.endsWith(".ckb") && p5S1SafeReadFile(entry.path).contains("schedulerRunId=${schedulerRunId}")) {
            return entry.name
        }
    }
    ""
}

private func p5S1ProcessExited(pid: Int64): Bool {
    pid > 0 && launch("/bin/sh", ["-c", "kill -0 ${pid} 2>/dev/null"]).wait() != 0
}

private func p5S1SafeReadFile(path: Path): String {
    if (!exists(path)) {
        return ""
    }
    try {
        String.fromUtf8(File.readFrom(path))
    } catch (_: Exception) {
        "invalid_response_encoding"
    }
}

private func p5S1SafeReadPipe(pipe: InputStream): String {
    try {
        StringReader<InputStream>(pipe).readToEnd()
    } catch (_: Exception) {
        "invalid_response_encoding"
    }
}

private func testField(text: String, key: String): String {
    let prefix = key + "="
    for (line in text.split("\n")) {
        let trimmed = line.trimAscii()
        if (trimmed.startsWith(prefix)) {
            return trimmed[prefix.size..trimmed.size]
        }
    }
    ""
}
