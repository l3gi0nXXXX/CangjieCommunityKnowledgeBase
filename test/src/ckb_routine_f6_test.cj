package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}
import std.process.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbRoutineF6Test {
    @TestCase
    public func f6U1ProfileStageBudgetSplitIsVisible(): Unit {
        let release = ckbSyncProfileForScheduleTask("cangjie_release_full_sync")
        let benchmark = ckbSyncProfileForScheduleTask("cangjie_benchmark_gap_curation")
        let diagnostic = ckbSchedulerProfileStageBudgetDiagnostic(benchmark)

        @Expect(release.fetchBudgetMillis > 0, true)
        @Expect(release.ingestBudgetMillis > 0, true)
        @Expect(release.vectorBudgetMillis > 0, true)
        @Expect(release.validationBudgetMillis > 0, true)
        @Expect(release.snapshotBudgetMillis > 0, true)
        @Expect(benchmark.proofBudgetMillis > 0, true)
        @Expect(diagnostic.contains("fetchBudgetMs="), true)
        @Expect(diagnostic.contains("proofBudgetMs="), true)
    }

    @TestCase
    public func f6B1BenchmarkProofCheckpointResumesAfterBatchBoundary(): Unit {
        let root = "target/f6-b1-benchmark-proof-resume"
        f6EnsureEmptyDir(root)
        f6WriteBenchmarkGapInput(root, 200)
        let config = CkbRuntimeConfig()
        config.benchmarkGapCurationInputPath = "${root}/gap-curation-input.jsonl"
        config.benchmarkGapProofBatchSize = 50
        let store = FileKnowledgeStore("${root}/store")
        let service = CkbCommandLoopService(config, store)
        _ = service.start()
        let tasks = f6BenchmarkTaskNames()

        let first = service.runSchedulerTasks(tasks, true)
        let firstCheckpoint = store.readText("metadata/benchmark-gap-curation-proof.ckb")

        @Expect(first.failed, 1)
        @Expect(first.details.contains("benchmark_gap_query_proof_recoverable"), true)
        @Expect(firstCheckpoint.contains("completed=50"), true)
        @Expect(firstCheckpoint.contains("status=recoverable"), true)

        let resumeConfig = CkbRuntimeConfig()
        resumeConfig.benchmarkGapCurationInputPath = "${root}/gap-curation-input.jsonl"
        resumeConfig.benchmarkGapProofBatchSize = 0
        let resumeService = CkbCommandLoopService(resumeConfig, store)
        _ = resumeService.start()
        let second = resumeService.runSchedulerTasks(tasks, true)
        let secondCheckpoint = store.readText("metadata/benchmark-gap-curation-proof.ckb")

        @Expect(second.succeeded, 1)
        @Expect(second.failed, 0)
        @Expect(secondCheckpoint.contains("completed=200"), true)
        @Expect(secondCheckpoint.contains("status=success"), true)
        @Expect(f6SchedulerDiagnosticsContain(second, "benchmark_gap_proof_resume_skip:CJ-HUMANEVAL-F6-000"), true)
        @Expect(f6SchedulerDiagnosticsContain(second, "benchmark_gap_query_proof:CJ-HUMANEVAL-F6-000:"), false)
    }

    @TestCase
    public func f6P1BenchmarkCurationProofsAllVisibleCases(): Unit {
        let root = "target/f6-p1-benchmark-proof-all"
        f6EnsureEmptyDir(root)
        f6WriteBenchmarkGapInput(root, 164)
        let config = CkbRuntimeConfig()
        config.benchmarkGapCurationInputPath = "${root}/gap-curation-input.jsonl"
        let store = FileKnowledgeStore("${root}/store")
        let service = CkbCommandLoopService(config, store)
        _ = service.start()

        let result = service.runSchedulerTasks(f6BenchmarkTaskNames(), true)
        let checkpoint = store.readText("metadata/benchmark-gap-curation-proof.ckb")

        @Expect(result.succeeded, 1)
        @Expect(result.failed, 0)
        @Expect(f6SchedulerDiagnosticsContain(result, "benchmark_gap_query_proof:CJ-HUMANEVAL-F6-163:coveragePass=true"), true)
        @Expect(checkpoint.contains("completed=164"), true)
        @Expect(checkpoint.contains("coveragePass=true"), true)
    }

    @TestCase
    public func f6N1BenchmarkInvalidUtf8StopsBeforePromotion(): Unit {
        let root = "target/f6-n1-benchmark-invalid-utf8"
        f6EnsureEmptyDir(root)
        let inputPath = "${root}/gap-curation-input.jsonl"
        File.writeTo(Path(inputPath), [UInt8(255), UInt8(254), UInt8(253)])
        let config = CkbRuntimeConfig()
        config.benchmarkGapCurationInputPath = inputPath
        let store = FileKnowledgeStore("${root}/store")
        let service = CkbCommandLoopService(config, store)
        _ = service.start()

        let result = service.runSchedulerTasks(f6BenchmarkTaskNames(), true)

        @Expect(result.failed, 1)
        @Expect(result.details.contains("benchmark_gap_curation_input_invalid_encoding"), true)
        @Expect(store.has("metadata/benchmark-gap-curation-proof.ckb"), false)
        @Expect(store.has("index/active.ckb"), false)
    }

    @TestCase
    public func f6E2EFakeFullRunResumesBenchmarkProofInSecondRound(): Unit {
        let root = "target/f6-e2e-fake-full-run"
        f6EnsureEmptyDir(root)
        f6WriteBenchmarkGapInput(root, 200)
        let config = CkbRuntimeConfig()
        config.benchmarkGapCurationInputPath = "${root}/gap-curation-input.jsonl"
        config.benchmarkGapProofBatchSize = 50
        let store = FileKnowledgeStore("${root}/store")
        let kb = newOfflineKnowledgeBase()
        ckbApplySchedulerProfileBudgets(kb.scheduler)
        let runner = F6FakeFullRunSchedulerTaskRunner(kb, config, store)
        let executor = SchedulerExecutor(kb.scheduler, runner, NoopSchedulerProgressSink(), 300000)
        let names = ckbSchedulerAllowlistTaskNames()

        let first = executor.runTaskNames(names, force: true)
        config.benchmarkGapProofBatchSize = 0
        let second = executor.runTaskNames(names, force: true)

        @Expect(first.ran, 13)
        @Expect(first.succeeded, 12)
        @Expect(first.failed, 1)
        @Expect(first.details.contains("benchmark_gap_query_proof_recoverable"), true)
        @Expect(second.ran, 13)
        @Expect(second.succeeded, 13)
        @Expect(second.failed, 0)
        @Expect(f6SchedulerDiagnosticsContain(second, "benchmark_gap_proof_resume_skip:CJ-HUMANEVAL-F6-000"), true)
    }
}

private class F6FakeFullRunSchedulerTaskRunner <: SchedulerTaskRunner {
    private let kb: KnowledgeBase
    private let config: CkbRuntimeConfig
    private let store: FileKnowledgeStore

    init(kb: KnowledgeBase, config: CkbRuntimeConfig, store: FileKnowledgeStore) {
        this.kb = kb
        this.config = config
        this.store = store
    }

    public func runTask(name: String, since: String, deadlineAtMillis: Int64): SchedulerTaskResult {
        if (name == "cangjie_benchmark_gap_curation") {
            return CkbSchedulerTaskRunner(this.kb, this.config, this.store).runTask(name, since, deadlineAtMillis)
        }
        let profile = ckbSyncProfileForScheduleTask(name)
        let result = SchedulerTaskResult()
        result.ok = true
        result.status = "f6_fake_task_ok"
        result.since = if (since == "") { "0" } else { since }
        result.durationMillis = 1
        result.timeBudgetMillis = profile.timeBudgetMillis
        result.lastStage = "f6_fake_finished"
        result.lastProgress = "taskName=${name}"
        for (kind in profile.updatedDataKinds) {
            result.updatedDataKinds.add(kind)
        }
        result.validationDiagnostics.add(ckbSchedulerProfileStageBudgetDiagnostic(profile))
        result
    }
}

private func f6BenchmarkTaskNames(): ArrayList<String> {
    let tasks = ArrayList<String>()
    tasks.add("cangjie_benchmark_gap_curation")
    tasks
}

private func f6WriteBenchmarkGapInput(root: String, count: Int64): Unit {
    var text = ""
    for (i in 0..count) {
        text += "{\"caseId\":\"CJ-HUMANEVAL-F6-${f6Pad3(i)}\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"Use ArrayList.add for visible input ${i}.\",\"visibleTestExcerpt\":\"assert solve([1,2]) == 3\",\"compilerOutput\":\"compile_error\",\"missingKnowledge\":\"G-ARRAYLIST\",\"interfaceId\":\"KI-02\",\"contentFamily\":\"KC-02\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"1.0.0\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection\"}\n"
    }
    File.writeTo(Path(root).join("gap-curation-input.jsonl"), text.toArray())
}

private func f6Pad3(value: Int64): String {
    if (value < 10) {
        return "00${value}"
    }
    if (value < 100) {
        return "0${value}"
    }
    "${value}"
}

private func f6EnsureEmptyDir(path: String): Unit {
    if (exists(Path(path))) {
        _ = launch("/bin/rm", ["-rf", path]).wait()
    }
    Directory.create(Path(path), recursive: true)
}

private func f6SchedulerDiagnosticsContain(result: SchedulerExecutorResult, needle: String): Bool {
    for (diagnostic in result.validationDiagnostics) {
        if (diagnostic.contains(needle)) {
            return true
        }
    }
    false
}
