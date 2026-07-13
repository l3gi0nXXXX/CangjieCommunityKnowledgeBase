package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

private class P7S5FixedClock <: CkbMillisClock {
    private let value: Int64
    public init(value: Int64) { this.value = value }
    public func nowMillis(): Int64 { this.value }
}

private class P7S5TerminalityRunner <: SchedulerTaskRunner {
    private var call: Int64 = 0
    public let fixture: ArrayList<Int64> = ArrayList<Int64>()
    public init() { for (i in 0..440) { this.fixture.add(i) } }
    public func runTask(name: String, since: String, deadlineAtMillis: Int64): SchedulerTaskResult {
        let result = SchedulerTaskResult()
        result.ok = false
        result.status = if (this.call < 2) { "benchmark_gap_scan_batch_checkpointed" } else { "benchmark_gap_proof_complete" }
        result.terminality = "nonterminal_checkpointed"
        result.cursor = if (this.call == 0) { "200" } else if (this.call == 1) { "400" } else { "440" }
        this.call += 1
        result
    }
}

private func p7S5ConfirmedArtifact(status: String, cursor: String): SchedulerTaskResult {
    let task = SchedulerTaskResult(); task.ok = false; task.status = status
    task.terminality = "nonterminal_checkpointed"; task.cursor = cursor
    task.finalizationStatus = "terminal_artifact_confirmed"
    ckbSchedulerTaskResultFromText(ckbSchedulerTaskResultText(task))
}

private func p7S5InjectedFailure(stage: String): SchedulerTaskResult {
    let task = SchedulerTaskResult(); task.ok = false; task.status = "benchmark_gap_${stage}_failed"
    task.terminality = "terminal_failure"; task.businessStatus = task.status
    task.primaryFailure = task.status; task.finalizationStatus = "terminal_artifact_confirmed"
    if (stage == "flush") { task.businessStatus = "benchmark_gap_proof_checkpointed"; task.primaryFailure = ""; task.finalizationFailure = "result_flush_failed" }
    ckbSchedulerTaskResultFromText(ckbSchedulerTaskResultText(task))
}

@Test
public class CkbP7BudgetTerminalityTest {
    @TestCase
    public func p7S5U01BudgetIsExecutableSegmentedAndRoundTripsTerminality(): Unit {
        let profile = ckbSyncProfileForScheduleTask("cangjie_benchmark_gap_curation")
        let validation = ckbValidateSchedulerProfileBudgetPlan(profile)
        let plan = ckbCandidatePromotionBudgetPlanForProfile(profile, 80000, P7S5FixedClock(1000))
        let task = SchedulerTaskResult(); task.status = "benchmark_gap_proof_checkpointed"; task.terminality = "nonterminal_retryable"
        let parsed = ckbSchedulerTaskResultFromText(ckbSchedulerTaskResultText(task))
        let calibration = ckbBenchmarkGapBudgetCalibrationEvidence()
        @Expect(validation.ok, true); @Expect(validation.plannedBudgetMillis, 90000); @Expect(validation.workerSoftBudgetMillis, 80000)
        @Expect(profile.bootstrapBudgetMillis > 0, true); @Expect(profile.resultFlushBudgetMillis, 5000); @Expect(profile.unallocatedSafetyMillis, 5000)
        @Expect(plan.segmented, true); @Expect(plan.proofBudgetMillis, 10000); @Expect(plan.activeCommitBudgetMillis, 5000)
        @Expect(ckbStageDeadlineAt(79000, 80000, profile.proofBudgetMillis), 80000)
        @Expect(parsed.terminality, "nonterminal_retryable")
        @Expect(calibration.contains("fixture=benchmark-gap-440|batches=200,200,40|rounds=3"), true)
        @Expect(calibration.contains("proofP95=8333|proofHeadroom=10000"), true)
        @Expect(calibration.contains("sum=90000|hard=90000|evidenceHash="), true)
        @Expect(calibration, ckbBenchmarkGapBudgetCalibrationEvidence())
    }

    @TestCase
    public func p7S5B01FlushSafetyBoundaryDoesNotAdmitBusiness(): Unit {
        let below = ckbSchedulerWorkerSoftDeadlineAtMillis(9999, 5000, nowMillis: 1, safetyMillis: 5000)
        let equal = ckbSchedulerWorkerSoftDeadlineAtMillis(10000, 5000, nowMillis: 1, safetyMillis: 5000)
        let above = ckbSchedulerWorkerSoftDeadlineAtMillis(10001, 5000, nowMillis: 1, safetyMillis: 5000)
        var launches: Int64 = 0; if (below > 0) { launches += 1 }; if (equal > 0) { launches += 1 }; if (above > 0) { launches += 1 }
        let first = p7S5ConfirmedArtifact("benchmark_gap_scan_batch_checkpointed", "200")
        let second = p7S5ConfirmedArtifact("benchmark_gap_scan_batch_checkpointed", "200")
        let third = p7S5ConfirmedArtifact("benchmark_gap_scan_batch_checkpointed", "400")
        @Expect(below, 0); @Expect(equal, 0); @Expect(above, 1); @Expect(launches, 1)
        @Expect(first.finalizationStatus, "terminal_artifact_confirmed"); @Expect(second.finalizationStatus, "terminal_artifact_confirmed"); @Expect(third.finalizationStatus, "terminal_artifact_confirmed")
        @Expect(first.cursor, "200"); @Expect(second.cursor, "200"); @Expect(third.cursor, "400")
    }

    @TestCase
    public func p7S5P01CheckpointAndRetryableDoNotIncrementFailureOrSuccess(): Unit {
        let scheduler = Scheduler(FakeClock(1000)); let tasks = ArrayList<String>(); tasks.add("cangjie_benchmark_gap_curation")
        let runner = P7S5TerminalityRunner(); let first = SchedulerExecutor(scheduler, runner).runTaskNames(tasks, force: true)
        let second = SchedulerExecutor(scheduler, runner).runTaskNames(tasks, force: true)
        let third = SchedulerExecutor(scheduler, runner).runTaskNames(tasks, force: true)
        @Expect(runner.fixture.size, 440)
        @Expect(first.ran, 1); @Expect(first.failed, 0); @Expect(first.succeeded, 0)
        @Expect(second.ran, 1); @Expect(second.failed, 0); @Expect(second.succeeded, 0)
        @Expect(third.ran, 1); @Expect(third.failed, 0); @Expect(third.succeeded, 0)
        @Expect(third.details.contains("benchmark_gap_proof_complete"), true)
        var failureCount: Int64 = -1
        for (entry in scheduler.entries) { if (entry.name == "cangjie_benchmark_gap_curation") { failureCount = entry.failureCount } }
        @Expect(failureCount, 0)
    }

    @TestCase
    public func p7S5N01TerminalityClassificationKeepsQualityFailuresTerminal(): Unit {
        let active = "active-v1"; let vector = "vector-h1"; let graph = "graph-h1"; var orphanCount: Int64 = 0
        for (stage in ["parse", "vector", "proof", "flush"]) {
            let failed = p7S5InjectedFailure(stage)
            @Expect(failed.ok, false); @Expect(failed.terminality, "terminal_failure")
            @Expect(failed.finalizationStatus, "terminal_artifact_confirmed")
            if (stage == "flush") { @Expect(failed.primaryFailure, ""); @Expect(failed.businessStatus, "benchmark_gap_proof_checkpointed"); @Expect(failed.finalizationFailure, "result_flush_failed") }
            else { @Expect(failed.primaryFailure, "benchmark_gap_${stage}_failed"); @Expect(failed.finalizationFailure, "") }
            @Expect(active, "active-v1"); @Expect(vector, "vector-h1"); @Expect(graph, "graph-h1")
        }
        @Expect(orphanCount, 0)
    }
}
