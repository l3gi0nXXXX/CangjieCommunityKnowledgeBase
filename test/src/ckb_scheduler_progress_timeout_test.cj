package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}
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

private class CaptureStageSink <: CkbStagedRebuildStageSink {
    public var stages: ArrayList<String> = ArrayList<String>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}

    public func onStagedRebuildStage(progress: CkbStagedRebuildStageProgress): Unit {
        this.stages.add("${progress.stage}|${progress.status}")
        this.diagnostics.add(progress.diagnostic)
    }
}

@Test
public class CkbSchedulerProgressTimeoutTest {
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
        store.writeLinesAtomically("metadata/scheduler-runs/scheduler-p4-cangjie_docs_full_weekly-staged-rebuild-current.ckb", "stage=candidate_active_commit_started\nstatus=running\ndiagnostic=p4-active-commit\n")

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

        let task = ckbWriteSchedulerWorkerTimeoutCompensation(store, resultPath, "weekly_full_rebuild", "0", 120001, 120000, "task_worker_hard_timeout", lastStage: "native_http_timeout", lastProgress: "vector:completed=64,currentBatch=1", workerPid: 12345, outSnippet: "WARN timeout", errSnippet: "Authorization: Bearer secret-value timeout")
        let text = store.readText(resultPath)

        @Expect(task.status, "task_timeout:weekly_full_rebuild")
        @Expect(task.lastStage, "native_http_timeout")
        @Expect(task.lastProgress.contains("completed=64"), true)
        @Expect(task.workerPid, 12345)
        @Expect(store.readText(resultPath).size > 0, true)
        @Expect(store.readText("${resultPath}.sidecar").contains("task_worker_hard_timeout"), true)
        @Expect(text.contains("lastStage=native_http_timeout"), true)
        @Expect(text.contains("workerPid=12345"), true)
        @Expect(text.contains("secret-value"), false)
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
