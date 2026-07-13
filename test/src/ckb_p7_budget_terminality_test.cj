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
    public func runTask(name: String, since: String, deadlineAtMillis: Int64): SchedulerTaskResult {
        let result = SchedulerTaskResult()
        result.ok = false
        result.status = if (this.call == 0) { "benchmark_gap_scan_batch_checkpointed" } else { "benchmark_gap_proof_checkpointed" }
        result.terminality = if (this.call == 0) { "nonterminal_checkpointed" } else { "nonterminal_retryable" }
        result.cursor = "${this.call * 200}"
        this.call += 1
        result
    }
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
        @Expect(ckbSchedulerWorkerSoftDeadlineAtMillis(9999, 5000, nowMillis: 1, safetyMillis: 5000), 0)
        @Expect(ckbSchedulerWorkerSoftDeadlineAtMillis(10000, 5000, nowMillis: 1, safetyMillis: 5000), 0)
        @Expect(ckbSchedulerWorkerSoftDeadlineAtMillis(10001, 5000, nowMillis: 1, safetyMillis: 5000), 1)
    }

    @TestCase
    public func p7S5P01CheckpointAndRetryableDoNotIncrementFailureOrSuccess(): Unit {
        let scheduler = Scheduler(FakeClock(1000)); let tasks = ArrayList<String>(); tasks.add("cangjie_benchmark_gap_curation")
        let runner = P7S5TerminalityRunner(); let first = SchedulerExecutor(scheduler, runner).runTaskNames(tasks, force: true)
        let second = SchedulerExecutor(scheduler, runner).runTaskNames(tasks, force: true)
        @Expect(first.ran, 1); @Expect(first.failed, 0); @Expect(first.succeeded, 0)
        @Expect(second.ran, 1); @Expect(second.failed, 0); @Expect(second.succeeded, 0)
        var failureCount: Int64 = -1
        for (entry in scheduler.entries) { if (entry.name == "cangjie_benchmark_gap_curation") { failureCount = entry.failureCount } }
        @Expect(failureCount, 0)
    }

    @TestCase
    public func p7S5N01TerminalityClassificationKeepsQualityFailuresTerminal(): Unit {
        let terminal = SchedulerTaskResult(); terminal.ok = false; terminal.status = "benchmark_gap_query_proof_failed"; terminal.terminality = "terminal_failure"
        let parsed = ckbSchedulerTaskResultFromText(ckbSchedulerTaskResultText(terminal))
        @Expect(parsed.ok, false); @Expect(parsed.status, "benchmark_gap_query_proof_failed")
        @Expect(parsed.terminality, "terminal_failure")
    }
}
