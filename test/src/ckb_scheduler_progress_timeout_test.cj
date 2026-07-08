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
            return result
        }
        result.ok = name != this.failTask
        result.status = if (result.ok) { "ok" } else { "fake_failed" }
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
}

private func ensureEmptyDir(path: String): Unit {
    if (exists(Path(path))) {
        _ = launch("/bin/rm", ["-rf", path]).wait()
    }
    Directory.create(Path(path), recursive: true)
}
