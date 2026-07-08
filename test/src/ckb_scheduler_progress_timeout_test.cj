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
        let withDyld = ckbSchedulerWorkerShellPrelude("/tmp/runtime:/tmp/stdx")
        let withoutDyld = ckbSchedulerWorkerShellPrelude("")

        @Expect(withDyld.contains("export CKB_SCHEDULER_TASK_WORKER=1;"), true)
        @Expect(withDyld.contains("export DYLD_LIBRARY_PATH='/tmp/runtime:/tmp/stdx';"), true)
        @Expect(withoutDyld.contains("export CKB_SCHEDULER_TASK_WORKER=1;"), true)
        @Expect(withoutDyld.contains("DYLD_LIBRARY_PATH"), false)
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

private func ensureEmptyDir(path: String): Unit {
    if (exists(Path(path))) {
        _ = launch("/bin/rm", ["-rf", path]).wait()
    }
    Directory.create(Path(path), recursive: true)
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
