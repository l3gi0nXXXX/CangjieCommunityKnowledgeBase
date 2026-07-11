package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}
import std.process.*
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieServingAdminTest {
    @TestCase
    public func p6Pos001CandidateValidationPassesForOfflineServingFeed(): Unit {
        let kb = newOfflineKnowledgeBase()
        kb.normalize()
        let candidateVersion = kb.stageCandidateIndex(cangjieLiveSyncCandidateVersion())

        let validation = validateCandidateServingIndex(kb.candidateRecordSnapshot(), candidateVersion)

        @Expect(validation.ok, true)
        @Expect(validation.status, "candidate_validation_passed")
        @Expect(validation.exactSymbolHits > 0, true)
        @Expect(validation.docSectionHits > 0, true)
        @Expect(validation.coveragePass, true)
        @Expect(validation.evidenceHash.startsWith("h"), true)
    }

    @TestCase
    public func p6Neg001ValidationFailureKeepsOldActiveVersion(): Unit {
        let kb = newOfflineKnowledgeBase()
        let before = kb.status().activeKnowledgeVersion
        kb.normalize()

        let promotion = cangjiePromoteCandidateAfterValidation(kb, FileKnowledgeStore("target/ckb-p6-neg-store"), forceFailure: true)
        let after = kb.status()

        @Expect(promotion.ok, false)
        @Expect(promotion.activePromoted, false)
        @Expect(promotion.validation.status, "candidate_validation_forced_failure")
        @Expect(after.activeKnowledgeVersion, before)
        @Expect(after.failedCandidateVersion.contains("candidate"), true)
    }

    @TestCase
    public func f4ValidationChecksExactDocToolNegativeTransportAndPerformanceSignals(): Unit {
        let records = ArrayList<NormalizedRecord>()
        records.add(cangjieF4AdminRecord("sym-arraylist-add", CangjieTypedRecordKinds.SYMBOL_CARD, "ArrayList.add", "symbolKey=ArrayList.add\nmodule=std.collection\nsignature=func add(value: T): Unit", CangjieSourceSets.STD, "vr-std-1"))
        records.add(cangjieF4AdminRecord("doc-arraylist-add", CangjieTypedRecordKinds.DOC_SECTION, "ArrayList.add docs", "ArrayList.add appends values. Do not use append.", CangjieSourceSets.DOCS, "vr-docs-1"))
        records.add(cangjieF4AdminRecord("tool-cjpm-test", CangjieTypedRecordKinds.TOOL_MANUAL, "cjpm test", "Run cjpm test to execute package tests.", CangjieSourceSets.TOOLS, "vr-tools-1"))

        let validation = validateCandidateServingIndex(records, "ckb-f4-candidate")

        @Expect(validation.ok, true)
        @Expect(validation.exactSymbolHits > 0, true)
        @Expect(validation.docSectionHits > 0, true)
        @Expect(validation.toolManualHits > 0, true)
        @Expect(validation.negativeRuleHits > 0, true)
        @Expect(validation.taskPackCoveragePass, true)
        @Expect(validation.transportParityPass, true)
        @Expect(validation.vectorHealthPass, true)
        @Expect(validation.performancePass, true)
        @Expect(cangjieF4AdminDiagnosticsContain(validation, "rest_mcp_parity_passed"), true)
        @Expect(cangjieF4AdminDiagnosticsContain(validation, "vector_health_passed"), true)
        @Expect(cangjieF4AdminDiagnosticsContain(validation, "performance_threshold_passed"), true)
    }

    @TestCase
    public func f4ValidationReportsMissingToolManualCoverageInsteadOfCountingOnlyDocs(): Unit {
        let records = ArrayList<NormalizedRecord>()
        records.add(cangjieF4AdminRecord("sym-arraylist-add", CangjieTypedRecordKinds.SYMBOL_CARD, "ArrayList.add", "symbolKey=ArrayList.add\nmodule=std.collection\nsignature=func add(value: T): Unit", CangjieSourceSets.STD, "vr-std-1"))
        records.add(cangjieF4AdminRecord("doc-arraylist-add", CangjieTypedRecordKinds.DOC_SECTION, "ArrayList.add docs", "ArrayList.add appends values. Do not use append.", CangjieSourceSets.DOCS, "vr-docs-1"))

        let validation = validateCandidateServingIndex(records, "ckb-f4-candidate")

        @Expect(validation.servingDocumentCount > 0, true)
        @Expect(validation.toolManualHits, 0)
        @Expect(cangjieF4AdminDiagnosticsContain(validation, "tool_manual_coverage_missing"), true)
        @Expect(cangjieF4AdminDiagnosticsContain(validation, "task_pack_coverage_missing"), true)
    }

    @TestCase
    public func p4Neg001VectorDimensionMismatchFailsCandidateGate(): Unit {
        let records = ArrayList<NormalizedRecord>()
        records.add(cangjieF4AdminRecord("sym-arraylist-add", CangjieTypedRecordKinds.SYMBOL_CARD, "ArrayList.add", "symbolKey=ArrayList.add\nmodule=std.collection\nsignature=func add(value: T): Unit", CangjieSourceSets.STD, "vr-std-1"))
        records.add(cangjieF4AdminRecord("doc-arraylist-add", CangjieTypedRecordKinds.DOC_SECTION, "ArrayList.add docs", "ArrayList.add appends values. Do not use append.", CangjieSourceSets.DOCS, "vr-docs-1"))
        records.add(cangjieF4AdminRecord("tool-cjpm-test", CangjieTypedRecordKinds.TOOL_MANUAL, "cjpm test", "Run cjpm test to execute package tests.", CangjieSourceSets.TOOLS, "vr-tools-1"))
        let vector = VectorStoreStatus()
        vector.backend = "qdrant"
        vector.collection = "ckb_active"
        vector.dimension = 1024
        vector.count = 3
        vector.state = EmbeddingProviderState.DEGRADED
        vector.degradedReason = "dimension_mismatch"

        let validation = validateCandidateServingIndexWithVectorStatus(records, "ckb-f4-candidate", vector)

        @Expect(validation.ok, false)
        @Expect(validation.vectorHealthPass, false)
        @Expect(validation.vectorState, EmbeddingProviderState.DEGRADED)
        @Expect(validation.vectorDegradedReason, "dimension_mismatch")
        @Expect(cangjieF4AdminDiagnosticsContainPrefix(validation, "vector_health_failed:dimension_mismatch"), true)
    }

    @TestCase
    public func p4E2E001HundredQueryPerformanceProbeHasStableHashAndP95(): Unit {
        let records = ArrayList<NormalizedRecord>()
        records.add(cangjieF4AdminRecord("sym-arraylist-add", CangjieTypedRecordKinds.SYMBOL_CARD, "ArrayList.add", "symbolKey=ArrayList.add\nmodule=std.collection\nsignature=func add(value: T): Unit\naliases=ArrayList.add;add", CangjieSourceSets.STD, "vr-std-1"))
        records.add(cangjieF4AdminRecord("doc-arraylist-add", CangjieTypedRecordKinds.DOC_SECTION, "ArrayList.add docs", "ArrayList.add appends values. Do not use append.", CangjieSourceSets.DOCS, "vr-docs-1"))
        records.add(cangjieF4AdminRecord("tool-cjpm-test", CangjieTypedRecordKinds.TOOL_MANUAL, "cjpm test", "Run cjpm test to execute package tests.", CangjieSourceSets.TOOLS, "vr-tools-1"))
        let index = buildCangjieServingIndex(records, activeKnowledgeVersion: "ckb-f4-active")
        let queries = ArrayList<String>()
        for (i in 0..100) {
            queries.add("ArrayList.add query ${i}")
        }

        let first = cangjieServingPerformanceProbe(index, queries, budget: 3, p95Threshold: 1000)
        let second = cangjieServingPerformanceProbe(index, queries, budget: 3, p95Threshold: 1000)

        @Expect(first.pass, true)
        @Expect(first.queryCount, 100)
        @Expect(first.p95Cost > 0, true)
        @Expect(first.p95Cost <= 1000, true)
        @Expect(first.evidenceHash.startsWith("h"), true)
        @Expect(second.evidenceHash, first.evidenceHash)
        @Expect(second.p95Cost, first.p95Cost)
    }

    @TestCase
    public func s4Ut001ValidationDeadlineTimeoutDoesNotCommitActive(): Unit {
        let records = cangjieF4AdminPromotionRecords()
        let expired = ckbCoreNowMillis() - 1
        let validation = validateCandidateServingIndexWithVectorStatus(records, "ckb-s4-timeout-candidate", cangjieCandidateTestVectorStatus(records), deadlineAtMillis: expired, validationScope: "UT-S4-001")
        let kb = KnowledgeBase(FakeClock(0))
        let before = kb.status().activeKnowledgeVersion
        let store = FileKnowledgeStore("target/s4-ut001-validation-timeout")

        let promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb, store, "ckb-s4-timeout-candidate", records, deadlineAtMillis: expired)
        let after = kb.status()

        @Expect(validation.ok, false)
        @Expect(validation.status, "candidate_validation_timeout")
        @Expect(cangjieF4AdminDiagnosticsContainPrefix(validation, "deadline_exceeded:candidate_validation_doc_loop_before"), true)
        @Expect(promotion.ok, false)
        @Expect(promotion.activePromoted, false)
        @Expect(promotion.validation.status, "candidate_validation_timeout")
        @Expect(after.activeKnowledgeVersion, before)
        @Expect(store.has("metadata/active-snapshot.manifest"), false)
    }

    @TestCase
    public func s4Bnd001EmptyCandidateRecordsReturnValidationFailed(): Unit {
        let records = ArrayList<NormalizedRecord>()

        let validation = validateCandidateServingIndex(records, "ckb-s4-empty-candidate")

        @Expect(validation.ok, false)
        @Expect(validation.status, "candidate_validation_failed")
        @Expect(cangjieF4AdminDiagnosticsContain(validation, "serving_index_not_ready"), true)
    }

    @TestCase
    public func s4Pos001SmallCandidateValidationPromotesActive(): Unit {
        let provider = CangjieAdminEmbeddingProvider(2)
        let vectorStore = CangjieAdminTrackingVectorStore(initialCount: 3)
        let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
        kb.configureVectorCollections("ckb_active", "ckb_candidate")
        let store = FileKnowledgeStore("target/s4-pos001-candidate-promotion")
        let records = cangjieF4AdminPromotionRecords()

        let promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb, store, "ckb-s4-pos-candidate", records)

        @Expect(promotion.ok, true)
        @Expect(promotion.validation.status, "candidate_validation_passed")
        @Expect(promotion.activePromoted, true)
        @Expect(store.has("metadata/active-snapshot.manifest"), true)
    }

    @TestCase
    public func p4U6CandidatePromotionEmitsScheduledStageSinkEvents(): Unit {
        let provider = CangjieAdminEmbeddingProvider(2)
        let vectorStore = CangjieAdminTrackingVectorStore(initialCount: 3)
        let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
        kb.configureVectorCollections("ckb_active", "ckb_candidate")
        let store = FileKnowledgeStore("target/p4-u6-candidate-stage-sink")
        let records = cangjieF4AdminPromotionRecords()
        let sink = AdminCaptureStageSink()

        let promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb, store, "ckb-p4-stage-candidate", records, stageSink: sink)

        @Expect(promotion.ok, true)
        @Expect(adminCaptureContains(sink.stages, "candidate_vector_started|running"), true)
        @Expect(adminCaptureContains(sink.stages, "candidate_validation_finished|candidate_validation_passed"), true)
        @Expect(adminCaptureContains(sink.stages, "candidate_active_commit_started|running"), true)
        @Expect(adminCaptureContains(sink.stages, "candidate_active_snapshot_finished|ok"), true)
        @Expect(store.has("metadata/active-snapshot.manifest"), true)
    }

    @TestCase
    public func p5S1P01CandidateAndLiveShadowStagesExposeDurationAndCounts(): Unit {
        let root = "target/p5-s1-p01-stage-duration"
        adminEnsureEmptyDir(root)
        let provider = CangjieAdminEmbeddingProvider(2)
        let vectorStore = CangjieAdminTrackingVectorStore(initialCount: 3)
        let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
        kb.configureVectorCollections("ckb_active", "ckb_candidate")
        let store = FileKnowledgeStore(root)
        store.writeLinesAtomically("metadata/scheduler-current.ckb", "runId=p5-s1-p01\ntaskName=cangjie_release_full_sync\nstatus=running\nprogressPath=metadata/scheduler-runs/p5-s1-p01.jsonl\n")
        let records = cangjieF4AdminPromotionRecords()
        let fileSink = FileCkbStagedRebuildStageSink(store, schedulerRunId: "p5-s1-p01", schedulerTaskName: "cangjie_release_full_sync")
        let sink = RecordingCkbStagedRebuildStageSink(fileSink)

        let promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb, store, "ckb-p5-s1-p01-candidate", records, stageSink: sink)
        let progress = store.readText("metadata/scheduler-runs/p5-s1-p01.jsonl")
        let validationLine = adminStageProgressLine(progress, "candidate_validation_finished")
        let snapshotLine = adminStageProgressLine(progress, "candidate_active_snapshot_finished")

        @Expect(promotion.ok, true)
        @Expect(promotion.validation.servingDocumentCount >= records.size, true)
        @Expect(validationLine.contains("\"durationMillis\":"), true)
        @Expect(validationLine.contains("\"itemCount\":${promotion.validation.servingDocumentCount}"), true)
        @Expect(snapshotLine.contains("\"durationMillis\":"), true)
        @Expect(snapshotLine.contains("\"itemCount\":${records.size}"), true)
        @Expect(progress.contains("\"stage\":\"active_snapshot_live_shadow_after\""), true)
        @Expect(sink.stageDurations.size, 4)
        @Expect(adminCaptureContains(sink.stageDurations, "stage=candidate_vector_finished|durationMillis="), true)
        @Expect(adminCaptureContains(sink.stageDurations, "stage=candidate_validation_finished|durationMillis="), true)
        @Expect(adminCaptureContains(sink.stageDurations, "stage=candidate_active_commit_finished|durationMillis="), true)
        @Expect(adminCaptureContains(sink.stageDurations, "stage=candidate_active_snapshot_finished|durationMillis="), true)
        @Expect(store.has("metadata/active-snapshot.manifest"), true)
    }

    @TestCase
    public func p5S1N02VectorProgressObserverFailureDoesNotFailPromotion(): Unit {
        let root = "target/p5-s1-n02-vector-observer"
        adminEnsureEmptyDir(root)
        let provider = CangjieAdminEmbeddingProvider(2)
        let vectorStore = CangjieAdminTrackingVectorStore(initialCount: 3)
        let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
        kb.configureVectorCollections("ckb_active", "ckb_candidate")
        let store = FileKnowledgeStore(root)
        store.ensureLayout()
        File.writeTo(Path(root).join("metadata/vector-reconcile-runs"), "observer-path-blocked 中文🙂".toArray())
        let sink = FileVectorBuildProgressSink(store, schedulerRunId: "p5-s1-vector-observer", schedulerTaskName: "cangjie_release_full_sync")

        let promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb, store, "ckb-p5-s1-vector-observer-candidate", cangjieF4AdminPromotionRecords(), progressSink: sink)
        let diagnostics = store.readText("metadata/scheduler-runs/p5-s1-vector-observer-diagnostics.jsonl")

        @Expect(promotion.ok, true)
        @Expect(promotion.activePromoted, true)
        @Expect(store.has("metadata/active-snapshot.manifest"), true)
        @Expect(diagnostics.contains("vector_progress_observer_degraded"), true)
        @Expect(diagnostics.contains("Authorization"), false)
    }

    @TestCase
    public func p5S1N01ThrowingStageSinkKeepsPreciseVectorFailureAndOldActive(): Unit {
        let provider = CangjieAdminEmbeddingProvider(2, failAtCall: 1, failReason: "ollama_timeout")
        let vectorStore = CangjieAdminTrackingVectorStore(initialCount: 3)
        let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
        kb.configureVectorCollections("ckb_active", "ckb_candidate")
        let before = kb.status()
        let store = FileKnowledgeStore("target/p5-s1-n01-throwing-stage")

        let sink = RecordingCkbStagedRebuildStageSink(ThrowingAdminStageSink())
        let promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb, store, "ckb-p5-s1-n01-candidate", cangjieF4AdminPromotionRecords(), stageSink: sink)
        let after = kb.status()

        @Expect(promotion.ok, false)
        @Expect(promotion.validation.status, "candidate_vector_failed")
        @Expect(after.activeKnowledgeVersion, before.activeKnowledgeVersion)
        @Expect(after.storage.vectorActiveCollection, before.storage.vectorActiveCollection)
        @Expect(after.storage.vectorIndexCount, before.storage.vectorIndexCount)
        @Expect(adminCaptureContains(sink.stageDurations, "stage=candidate_vector_finished|durationMillis="), true)
    }

    @TestCase
    public func p5S1P02ThrowingStageDelegateDoesNotFailSuccessfulPromotion(): Unit {
        let root = "target/p5-s1-p02-success-throwing-stage"
        adminEnsureEmptyDir(root)
        let provider = CangjieAdminEmbeddingProvider(2)
        let vectorStore = CangjieAdminTrackingVectorStore(initialCount: 3)
        let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
        kb.configureVectorCollections("ckb_active", "ckb_candidate")
        let before = kb.status().activeKnowledgeVersion
        let store = FileKnowledgeStore(root)
        let sink = RecordingCkbStagedRebuildStageSink(ThrowingAdminStageSink())

        let promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb, store, "ckb-p5-s1-p02-candidate", cangjieF4AdminPromotionRecords(), stageSink: sink)
        let after = kb.status()

        @Expect(promotion.ok, true)
        @Expect(promotion.activePromoted, true)
        @Expect(after.activeKnowledgeVersion, promotion.activeVersion)
        @Expect(after.activeKnowledgeVersion == before, false)
        @Expect(store.has("metadata/active-snapshot.manifest"), true)
        @Expect(sink.stageDurations.size, 4)
        @Expect(adminCaptureContains(sink.stageDurations, "stage=candidate_vector_finished|durationMillis="), true)
        @Expect(adminCaptureContains(sink.stageDurations, "stage=candidate_validation_finished|durationMillis="), true)
        @Expect(adminCaptureContains(sink.stageDurations, "stage=candidate_active_commit_finished|durationMillis="), true)
        @Expect(adminCaptureContains(sink.stageDurations, "stage=candidate_active_snapshot_finished|durationMillis="), true)
    }

    @TestCase
    public func p5S2N01BCandidateStageDeadlinesKeepOldActiveAndCleanStaging(): Unit {
        let records = cangjieF4AdminPromotionRecords()
        let largeRecords = cangjieF4AdminPromotionRecords()
        for (record in cangjieAdminGeneratedRecords(1024)) {
            largeRecords.add(record)
        }

        let vectorRoot = "target/p5-s2-n01-vector"
        adminEnsureEmptyDir(vectorRoot)
        let vectorStore = CangjieAdminTrackingVectorStore(initialCount: 3)
        let vectorKb = KnowledgeBase(FakeClock(0), CangjieAdminEmbeddingProvider(2, delayMillis: 30), vectorStore, LocalGraphStore())
        vectorKb.configureVectorCollections("ckb_active", "ckb_candidate")
        let vectorFileStore = FileKnowledgeStore(vectorRoot)
        vectorKb.bootstrapOffline()
        vectorKb.persistActiveSnapshot(vectorFileStore)
        vectorStore.deletedActiveCollection = false
        let vectorBefore = vectorKb.status().activeKnowledgeVersion
        let vectorSink = AdminCaptureStageSink()
        let vector = cangjiePromoteCandidateRecordsAfterValidationWithVersion(vectorKb, vectorFileStore, "ckb-p5-s2-vector-candidate", records, stageSink: vectorSink, budgetPlan: adminP5S2BudgetPlan(SystemCkbMillisClock(), ckbCoreNowMillis() + 435000, vectorBudgetMillis: 20))
        @Expect(vector.ok, false)
        @Expect(vector.validation.status, "candidate_vector_deadline_exceeded")
        @Expect(vectorKb.status().activeKnowledgeVersion, vectorBefore)
        @Expect(vectorStore.deleteCollectionCalls, 1)
        @Expect(vectorStore.deletedActiveCollection, false)
        @Expect(adminCaptureContains(vectorSink.stages, "candidate_vector_started|running"), true)
        @Expect(adminCaptureContains(vectorSink.stages, "candidate_validation_started|running"), false)

        let validationRoot = "target/p5-s2-n01-validation"
        adminEnsureEmptyDir(validationRoot)
        let validationStore = CangjieAdminTrackingVectorStore(initialCount: 3)
        let validationKb = KnowledgeBase(FakeClock(0), CangjieAdminEmbeddingProvider(2), validationStore, LocalGraphStore())
        validationKb.configureVectorCollections("ckb_active", "ckb_candidate")
        let validationFileStore = FileKnowledgeStore(validationRoot)
        validationKb.bootstrapOffline()
        validationKb.persistActiveSnapshot(validationFileStore)
        validationStore.deletedActiveCollection = false
        let validationBefore = validationKb.status().activeKnowledgeVersion
        let validationSink = AdminCaptureStageSink()
        let validation = cangjiePromoteCandidateRecordsAfterValidationWithVersion(validationKb, validationFileStore, "ckb-p5-s2-validation-candidate", largeRecords, stageSink: validationSink, budgetPlan: adminP5S2BudgetPlan(SystemCkbMillisClock(), ckbCoreNowMillis() + 435000, validationBudgetMillis: 1))
        @Expect(validation.ok, false)
        @Expect(validation.validation.status, "candidate_validation_deadline_exceeded")
        @Expect(validationKb.status().activeKnowledgeVersion, validationBefore)
        @Expect(validationStore.deleteCollectionCalls, 1)
        @Expect(validationStore.deletedActiveCollection, false)
        @Expect(adminCaptureContains(validationSink.stages, "candidate_validation_started|running"), true)
        @Expect(adminCaptureContains(validationSink.stages, "candidate_active_commit_started|running"), false)

        let commitRoot = "target/p5-s2-n01-commit"
        adminEnsureEmptyDir(commitRoot)
        let commitStore = CangjieAdminTrackingVectorStore(initialCount: 3)
        let commitKb = KnowledgeBase(FakeClock(0), CangjieAdminEmbeddingProvider(2), commitStore, LocalGraphStore())
        commitKb.configureVectorCollections("ckb_active", "ckb_candidate")
        let commitFileStore = FileKnowledgeStore(commitRoot)
        commitKb.bootstrapOffline()
        commitKb.persistActiveSnapshot(commitFileStore)
        commitStore.deletedActiveCollection = false
        let commitBefore = commitKb.status().activeKnowledgeVersion
        let commitSink = AdminCaptureStageSink()
        let commit = cangjiePromoteCandidateRecordsAfterValidationWithVersion(commitKb, commitFileStore, "ckb-p5-s2-commit-candidate", largeRecords, stageSink: commitSink, budgetPlan: adminP5S2BudgetPlan(SystemCkbMillisClock(), ckbCoreNowMillis() + 435000, activeCommitBudgetMillis: 20))
        @Expect(commit.ok, false)
        @Expect(commit.validation.status, "candidate_active_commit_deadline_exceeded")
        @Expect(commitKb.status().activeKnowledgeVersion, commitBefore)
        @Expect(commitStore.deleteCollectionCalls, 1)
        @Expect(commitStore.deletedActiveCollection, false)
        @Expect(adminCaptureContains(commitSink.stages, "candidate_active_commit_started|running"), true)
        @Expect(adminCaptureContains(commitSink.stages, "candidate_active_snapshot_started|running"), false)

        let snapshotRoot = "target/p5-s2-n01-snapshot"
        adminEnsureEmptyDir(snapshotRoot)
        let snapshotStore = CangjieAdminTrackingVectorStore(initialCount: 3)
        let snapshotKb = KnowledgeBase(FakeClock(0), CangjieAdminEmbeddingProvider(2), snapshotStore, LocalGraphStore())
        snapshotKb.configureVectorCollections("ckb_active", "ckb_candidate")
        let snapshotFileStore = FileKnowledgeStore(snapshotRoot)
        snapshotKb.bootstrapOffline()
        snapshotKb.persistActiveSnapshot(snapshotFileStore)
        snapshotStore.deletedActiveCollection = false
        let snapshotBefore = snapshotKb.status().activeKnowledgeVersion
        let snapshotSink = AdminCaptureStageSink()
        let snapshot = cangjiePromoteCandidateRecordsAfterValidationWithVersion(snapshotKb, snapshotFileStore, "ckb-p5-s2-snapshot-candidate", largeRecords, stageSink: snapshotSink, budgetPlan: adminP5S2BudgetPlan(SystemCkbMillisClock(), ckbCoreNowMillis() + 435000, snapshotBudgetMillis: 20))
        @Expect(snapshot.ok, false)
        @Expect(snapshot.validation.status, "candidate_active_snapshot_deadline_exceeded")
        @Expect(snapshotKb.status().activeKnowledgeVersion, snapshotBefore)
        @Expect(snapshotStore.deleteCollectionCalls, 1)
        @Expect(snapshotStore.deletedActiveCollection, false)
        @Expect(adminCaptureContains(snapshotSink.stages, "candidate_active_snapshot_started|running"), true)
        @Expect(adminCaptureContains(snapshotSink.stages, "candidate_active_snapshot_finished|candidate_active_snapshot_deadline_exceeded"), true)
    }

    @TestCase
    public func p4N2ActiveCommitDeadlineThrowsBeforeHalfCommittedManifest(): Unit {
        let kb = KnowledgeBase(FakeClock(0))
        kb.configureVectorCollections("ckb_active", "ckb_candidate")
        let records = cangjieF4AdminPromotionRecords()
        let candidateVersion = kb.stageCandidateRecords("ckb-p4-deadline-candidate", records)
        let vector = cangjieCandidateTestVectorStatus(records)
        var diagnostic = ""

        try {
            _ = kb.commitCandidateToActiveAfterVectorReady(cangjieActiveVersionForCandidate(candidateVersion), "ckb_candidate", vector, deadlineAtMillis: ckbCoreNowMillis() - 1)
        } catch (e: Exception) {
            diagnostic = e.message
        }

        @Expect(diagnostic.startsWith("deadline_exceeded:candidate_active_commit_before"), true)
        @Expect(kb.status().activeKnowledgeVersion.contains("ckb-p4-deadline"), false)
    }

    @TestCase
    public func s4Neg001ParityFailureIsNotReportedAsTimeout(): Unit {
        let records = ArrayList<NormalizedRecord>()

        let validation = validateCandidateServingIndexWithVectorStatus(records, "ckb-s4-parity-candidate", cangjieCandidateTestVectorStatus(records), deadlineAtMillis: ckbCoreNowMillis() + 60000, validationScope: "NEG-S4-001")

        @Expect(validation.ok, false)
        @Expect(validation.status, "candidate_validation_failed")
        @Expect(cangjieF4AdminDiagnosticsContain(validation, "rest_mcp_parity_failed"), true)
        @Expect(cangjieF4AdminDiagnosticsContainPrefix(validation, "deadline_exceeded:"), false)
    }

    @TestCase
    public func f9Pos001CandidatePromotionUsesStagingVectorAndSingleEmbeddingPass(): Unit {
        let provider = CangjieAdminEmbeddingProvider(2)
        let vectorStore = CangjieAdminTrackingVectorStore(initialCount: 3)
        let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
        kb.configureVectorCollections("ckb_active", "ckb_candidate")
        let store = FileKnowledgeStore("target/ckb-admin-safe-candidate-promotion")
        let records = cangjieF4AdminPromotionRecords()

        let promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb, store, "ckb-admin-safe-candidate", records)
        let status = kb.status()

        @Expect(promotion.ok, true)
        @Expect(promotion.activePromoted, true)
        @Expect(provider.calls, 2)
        @Expect(vectorStore.deletedActiveCollection, false)
        @Expect(vectorStore.recreateCalls, 1)
        @Expect(status.storage.vectorActiveCollection.startsWith("ckb_candidate_stage_"), true)
        @Expect(status.storage.vectorIndexCount, records.size)
        @Expect(store.has("normalized/candidate/ckb-admin-safe-candidate.ckb"), true)
        @Expect(store.has("metadata/active-snapshot.manifest"), true)
    }

    @TestCase
    public func f9Bnd001CandidatePromotionKeepsStagingCollectionBoundedWhenActiveNameIsLong(): Unit {
        let kb = KnowledgeBase(FakeClock(0))
        var longActive = "active"
        for (i in 0..12) {
            longActive += "_candidate_1234567890123_h${i}"
        }
        kb.configureVectorCollections(longActive, "ckb_candidate")
        let store = FileKnowledgeStore("target/ckb-admin-bounded-candidate-collection")
        let records = cangjieF4AdminPromotionRecords()

        let promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb, store, "ckb-admin-long-active-candidate", records)
        let activeCollection = kb.status().storage.vectorActiveCollection

        @Expect(promotion.ok, true)
        @Expect(promotion.activePromoted, true)
        @Expect(activeCollection.startsWith("ckb_candidate_stage_"), true)
        @Expect(activeCollection.size < 80, true)
        @Expect(store.has("metadata/active-snapshot.manifest"), true)
    }

    @TestCase
    public func f9Neg001CandidatePromotionVectorFailureKeepsOldActiveAndDeletesStaging(): Unit {
        let provider = CangjieAdminEmbeddingProvider(2, failAtCall: 2, failReason: "ollama_timeout")
        let vectorStore = CangjieAdminTrackingVectorStore(initialCount: 3)
        let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
        kb.configureVectorCollections("ckb_active", "ckb_candidate")
        let before = kb.status().activeKnowledgeVersion
        let store = FileKnowledgeStore("target/ckb-admin-safe-candidate-failure")
        let records = cangjieF4AdminPromotionRecords()

        let promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb, store, "ckb-admin-fail-candidate", records)
        let after = kb.status()

        @Expect(promotion.ok, false)
        @Expect(promotion.activePromoted, false)
        @Expect(provider.calls, 2)
        @Expect(vectorStore.deletedActiveCollection, false)
        @Expect(vectorStore.deleteCollectionCalls, 1)
        @Expect(after.activeKnowledgeVersion, before)
        @Expect(promotion.validation.vectorDegradedReason.contains("ollama_timeout"), true)
    }

    @TestCase
    public func p4N4CandidateVectorFailureDoesNotPolluteActiveVectorStatus(): Unit {
        let provider = CangjieAdminEmbeddingProvider(2, failAtCall: 1, failReason: "ollama_timeout")
        let vectorStore = CangjieAdminTrackingVectorStore(initialCount: 3)
        let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
        kb.configureVectorCollections("ckb_active", "ckb_candidate")
        let before = kb.status()
        let store = FileKnowledgeStore("target/ckb-admin-p4-vector-failure-status")

        let promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb, store, "ckb-admin-p4-vector-fail-candidate", cangjieF4AdminPromotionRecords())
        let after = kb.status()

        @Expect(promotion.ok, false)
        @Expect(promotion.validation.status, "candidate_vector_failed")
        @Expect(promotion.validation.vectorDegradedReason.contains("ollama_timeout"), true)
        @Expect(vectorStore.deleteCollectionCalls, 1)
        @Expect(after.activeKnowledgeVersion, before.activeKnowledgeVersion)
        @Expect(after.storage.vectorActiveCollection, before.storage.vectorActiveCollection)
        @Expect(after.storage.vectorCollection, before.storage.vectorCollection)
        @Expect(after.storage.vectorState, before.storage.vectorState)
        @Expect(after.storage.vectorDegradedReason, before.storage.vectorDegradedReason)
        @Expect(after.storage.vectorIndexCount, before.storage.vectorIndexCount)
        @Expect(after.storage.vectorDegradedReason.contains("ollama_timeout"), false)
    }

    @TestCase
    public func p4P3CandidateVectorBuildReusesActiveVectorsWhenOrdinalChanges(): Unit {
        let provider = CangjieAdminEmbeddingProvider(2)
        let vectorStore = CangjieAdminTrackingVectorStore()
        let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
        kb.configureVectorCollections("ckb_active", "ckb_candidate")
        let active = ArrayList<NormalizedRecord>()
        let first = cangjieF4AdminRecord("reuse-a", CangjieTypedRecordKinds.DOC_SECTION, "Reuse A", "first active record", CangjieSourceSets.DOCS, "vr-docs-1")
        let second = cangjieF4AdminRecord("reuse-b", CangjieTypedRecordKinds.DOC_SECTION, "Reuse B", "second active record", CangjieSourceSets.DOCS, "vr-docs-1")
        active.add(first)
        active.add(second)

        let activeBuild = kb.buildVectorIndexForRecords(active, "ckb_active")
        let candidate = ArrayList<NormalizedRecord>()
        candidate.add(second)
        candidate.add(first)
        candidate.add(cangjieF4AdminRecord("reuse-c", CangjieTypedRecordKinds.DOC_SECTION, "Reuse C", "new candidate record", CangjieSourceSets.DOCS, "vr-docs-1"))
        let candidateBuild = kb.buildVectorIndexForRecords(candidate, "ckb_candidate_stage_reuse")
        let progress = kb.vectorBuildProgress()

        @Expect(activeBuild.ok, true)
        @Expect(candidateBuild.ok, true)
        @Expect(provider.calls, 2)
        @Expect(progress.reused, 2)
        @Expect(progress.embedded, 1)
        @Expect(candidateBuild.vectorRecords.size, 3)
    }

    @TestCase
    public func p4P4CandidateVectorReuseUsesLargeStagingBatches(): Unit {
        let provider = CangjieAdminEmbeddingProvider(2)
        let vectorStore = CangjieAdminTrackingVectorStore()
        let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
        kb.configureVectorCollections("ckb_active", "ckb_candidate")
        let records = cangjieAdminGeneratedRecords(2050)

        let activeBuild = kb.buildVectorIndexForRecords(records, "ckb_active")
        let callsAfterActive = provider.calls
        let stagingCallsBefore = vectorStore.stagingUpsertBatchCalls
        let candidateBuild = kb.buildVectorIndexForRecords(records, "ckb_candidate_stage_large_reuse")
        let progress = kb.vectorBuildProgress()

        @Expect(activeBuild.ok, true)
        @Expect(candidateBuild.ok, true)
        @Expect(provider.calls, callsAfterActive)
        @Expect(progress.reused, 2050)
        @Expect(progress.embedded, 0)
        @Expect(vectorStore.stagingUpsertBatchCalls - stagingCallsBefore, 3)
        @Expect(vectorStore.stagingMaxBatchSize, 1024)
    }

    @TestCase
    public func p4P5LargeCandidateValidationUsesLinearCoverageScan(): Unit {
        let records = cangjieF4AdminPromotionRecords()
        for (record in cangjieAdminGeneratedRecords(1024)) {
            records.add(record)
        }

        let validation = validateCandidateServingIndexWithVectorStatus(records, "ckb-admin-p4-large-validation-candidate", cangjieCandidateTestVectorStatus(records), deadlineAtMillis: ckbCoreNowMillis() + 10000, validationScope: "P4-P5")

        @Expect(validation.ok, true)
        @Expect(validation.status, "candidate_validation_passed")
        @Expect(validation.servingDocumentCount >= 1024, true)
        @Expect(validation.exactSymbolHits > 0, true)
        @Expect(validation.docSectionHits >= 1024, true)
        @Expect(validation.toolManualHits > 0, true)
        @Expect(validation.negativeRuleHits > 0, true)
        @Expect(cangjieF4AdminDiagnosticsContainPrefix(validation, "deadline_exceeded:"), false)
    }
}

private class AdminP5S2SequenceClock <: CkbMillisClock {
    private var values: ArrayList<Int64> = ArrayList<Int64>()
    private var index: Int64 = 0

    public init() {}

    public func add(value: Int64): Unit {
        this.values.add(value)
    }

    public func nowMillis(): Int64 {
        var selected = this.index
        if (selected >= this.values.size) {
            selected = this.values.size - 1
        }
        let value = this.values[selected]
        this.index += 1
        value
    }
}

private func adminP5S2BudgetPlan(clock: CkbMillisClock, softDeadlineAtMillis: Int64, vectorBudgetMillis!: Int64 = 180000, validationBudgetMillis!: Int64 = 40000, activeCommitBudgetMillis!: Int64 = 20000, snapshotBudgetMillis!: Int64 = 50000): CangjieCandidatePromotionBudgetPlan {
    let plan = CangjieCandidatePromotionBudgetPlan()
    plan.segmented = true
    plan.vectorBudgetMillis = vectorBudgetMillis
    plan.validationBudgetMillis = validationBudgetMillis
    plan.activeCommitBudgetMillis = activeCommitBudgetMillis
    plan.snapshotBudgetMillis = snapshotBudgetMillis
    plan.workerSoftDeadlineAtMillis = softDeadlineAtMillis
    plan.deadlineClock = clock
    plan
}

private class AdminCaptureStageSink <: CkbStagedRebuildStageSink {
    public var stages: ArrayList<String> = ArrayList<String>()

    public init() {}

    public func onStagedRebuildStage(progress: CkbStagedRebuildStageProgress): Unit {
        this.stages.add("${progress.stage}|${progress.status}")
    }
}

private class ThrowingAdminStageSink <: CkbStagedRebuildStageSink {
    public init() {}

    public func onStagedRebuildStage(progress: CkbStagedRebuildStageProgress): Unit {
        throw Exception("stage sink fixture failure 中文🙂")
    }
}

private func adminEnsureEmptyDir(path: String): Unit {
    if (exists(Path(path))) {
        _ = launch("/bin/rm", ["-rf", path]).wait()
    }
    Directory.create(Path(path), recursive: true)
}

private func adminStageProgressLine(text: String, stage: String): String {
    let needle = "\"stage\":\"${stage}\""
    for (line in text.split("\n")) {
        if (line.contains(needle)) {
            return line
        }
    }
    ""
}

private func adminCaptureContains(values: ArrayList<String>, needle: String): Bool {
    for (value in values) {
        if (value.contains(needle)) {
            return true
        }
    }
    false
}

private func cangjieF4AdminRecord(sourceId: String, kind: String, title: String, chunk: String, sourceSet: String, versionResolutionId: String): NormalizedRecord {
    let record = NormalizedRecord()
    record.sourceId = sourceId
    record.recordKind = kind
    record.title = title
    record.chunk = chunk
    record.citation = "test:${sourceId}"
    record.metadata.sourceId = sourceId
    record.metadata.sourceType = if (sourceSet == CangjieSourceSets.STD || sourceSet == CangjieSourceSets.STDX) { SourceTypes.REPO } else { SourceTypes.DOC }
    record.metadata.sourceSet = sourceSet
    record.metadata.targetVersion = "1.0.0"
    record.metadata.versionResolutionId = versionResolutionId
    record.metadata.knowledgeVersion = "ckb-f4-active"
    record.metadata.path = if (kind == CangjieTypedRecordKinds.TOOL_MANUAL) { "tools/cjpm.md" } else { "docs/${sourceId}.md" }
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.TRUSTED
    record
}

private func cangjieAdminGeneratedRecords(count: Int64): ArrayList<NormalizedRecord> {
    let records = ArrayList<NormalizedRecord>()
    for (i in 0..count) {
        records.add(cangjieF4AdminRecord("generated-${i}", CangjieTypedRecordKinds.DOC_SECTION, "Generated ${i}", "generated reusable chunk ${i}", CangjieSourceSets.DOCS, "vr-docs-1"))
    }
    records
}

private func cangjieF4AdminPromotionRecords(): ArrayList<NormalizedRecord> {
    let records = ArrayList<NormalizedRecord>()
    records.add(cangjieF4AdminRecord("sym-arraylist-add", CangjieTypedRecordKinds.SYMBOL_CARD, "ArrayList.add", "symbolKey=ArrayList.add\nmodule=std.collection\nsignature=func add(value: T): Unit\naliases=ArrayList.add;add", CangjieSourceSets.STD, "vr-std-1"))
    records.add(cangjieF4AdminRecord("doc-arraylist-add", CangjieTypedRecordKinds.DOC_SECTION, "ArrayList.add docs", "ArrayList.add appends values. Do not use append.", CangjieSourceSets.DOCS, "vr-docs-1"))
    records.add(cangjieF4AdminRecord("tool-cjpm-test", CangjieTypedRecordKinds.TOOL_MANUAL, "cjpm test", "Run cjpm test to execute package tests.", CangjieSourceSets.TOOLS, "vr-tools-1"))
    records
}

private func cangjieCandidateTestVectorStatus(records: ArrayList<NormalizedRecord>): VectorStoreStatus {
    let status = VectorStoreStatus()
    status.backend = "qdrant"
    status.collection = "ckb_candidate"
    status.activeCollection = "ckb_active"
    status.candidateCollection = "ckb_candidate"
    status.dimension = 3
    status.count = records.size
    status.state = if (records.size > 0) { EmbeddingProviderState.READY } else { EmbeddingProviderState.DEGRADED }
    status.degradedReason = if (records.size > 0) { "" } else { "empty_candidate_vectors" }
    status
}

private class CangjieAdminEmbeddingProvider <: EmbeddingProvider {
    private let configuredBatchSize: Int64
    private let failReason: String
    private let delayMillis: Int64
    public var calls: Int64 = 0
    public var failAtCall: Int64 = -1

    init(batchSize: Int64, failAtCall!: Int64 = -1, failReason!: String = "", delayMillis!: Int64 = 0) {
        this.configuredBatchSize = batchSize
        this.failAtCall = failAtCall
        this.failReason = failReason
        this.delayMillis = delayMillis
    }

    public func embed(texts: ArrayList<String>, model: String, dimensions: Int64): EmbeddingBatch {
        this.calls += 1
        if (this.delayMillis > 0) {
            sleep(Duration.millisecond * this.delayMillis)
        }
        let batch = EmbeddingBatch()
        batch.requested = texts.size
        batch.batchSize = this.configuredBatchSize
        batch.status = this.status()
        if (this.calls == this.failAtCall) {
            batch.status.state = EmbeddingProviderState.DOWN
            batch.status.degradedReason = if (this.failReason != "") { this.failReason } else { "embedding_failed" }
            batch.failed = texts.size
            return batch
        }
        for (_ in texts) {
            let vector = ArrayList<Float64>()
            vector.add(1.0)
            vector.add(2.0)
            vector.add(0.5)
            batch.vectors.add(vector)
        }
        batch.succeeded = texts.size
        batch
    }

    public func embedWithDeadline(texts: ArrayList<String>, model: String, dimensions: Int64, deadlineAtMillis: Int64): EmbeddingBatch {
        this.embed(texts, model, dimensions)
    }

    public func status(): EmbeddingStatus {
        let status = EmbeddingStatus()
        status.provider = "ollama"
        status.model = "bge-m3:latest"
        status.dimensions = 3
        status.endpointConfigured = true
        status.batchSize = this.configuredBatchSize
        status.timeoutMillis = 100
        status.retryCount = 0
        status.production = true
        status.state = EmbeddingProviderState.READY
        status
    }
}

private class CangjieAdminTrackingVectorStore <: VectorStore {
    public var recreateCalls: Int64 = 0
    public var upsertBatchCalls: Int64 = 0
    public var activeUpsertBatchCalls: Int64 = 0
    public var stagingUpsertBatchCalls: Int64 = 0
    public var stagingMaxBatchSize: Int64 = 0
    public var deleteCollectionCalls: Int64 = 0
    public var deletedActiveCollection: Bool = false
    private var activeCount: Int64 = 0
    private var stagingCollection: String = ""
    private var stagingCount: Int64 = 0
    private var activeRecords: ArrayList<VectorRecord> = ArrayList<VectorRecord>()
    private var stagingRecords: ArrayList<VectorRecord> = ArrayList<VectorRecord>()

    init(initialCount!: Int64 = 0) {
        this.activeCount = initialCount
    }

    public func upsert(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.upsertBatch(collection, vectors)
    }

    public func upsertBatch(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.upsertBatchCalls += 1
        if (collection == "ckb_active") {
            this.activeUpsertBatchCalls += 1
            this.activeCount += vectors.size
            for (record in vectors) {
                this.activeRecords.add(record)
            }
        } else {
            this.stagingUpsertBatchCalls += 1
            if (vectors.size > this.stagingMaxBatchSize) {
                this.stagingMaxBatchSize = vectors.size
            }
            this.stagingCollection = collection
            this.stagingCount += vectors.size
            for (record in vectors) {
                this.stagingRecords.add(record)
            }
        }
        this.status(collection)
    }

    public func upsertBatchWithDeadline(collection: String, vectors: ArrayList<VectorRecord>, deadlineAtMillis: Int64): VectorStoreStatus {
        this.upsertBatch(collection, vectors)
    }

    public func search(collection: String, queryVector: ArrayList<Float64>, filters: VectorSearchFilters, topK: Int64): ArrayList<VectorSearchResult> {
        ArrayList<VectorSearchResult>()
    }

    public func status(collection: String): VectorStoreStatus {
        let status = VectorStoreStatus()
        status.backend = "qdrant"
        status.collection = collection
        status.activeCollection = "ckb_active"
        status.candidateCollection = "ckb_candidate"
        status.dimension = 3
        status.distance = "Cosine"
        status.state = EmbeddingProviderState.READY
        status.count = if (collection == "ckb_active") {
            this.activeCount
        } else if (collection == this.stagingCollection) {
            this.stagingCount
        } else {
            0
        }
        status
    }

    public func ensureReadyCollection(collection: String): VectorStoreStatus {
        this.status(collection)
    }

    public func clear(collection: String): VectorStoreStatus {
        if (collection == "ckb_active") {
            this.deletedActiveCollection = true
            this.activeCount = 0
            this.activeRecords.clear()
        } else {
            this.stagingCollection = collection
            this.stagingCount = 0
            this.stagingRecords.clear()
        }
        this.status(collection)
    }

    public func recreate(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.recreateCalls += 1
        this.clear(collection)
        if (vectors.size > 0) {
            return this.upsertBatch(collection, vectors)
        }
        this.status(collection)
    }

    public func recreateWithDeadline(collection: String, vectors: ArrayList<VectorRecord>, deadlineAtMillis: Int64): VectorStoreStatus {
        this.recreate(collection, vectors)
    }

    public func deleteCollection(collection: String): VectorStoreStatus {
        this.deleteCollectionCalls += 1
        if (collection == "ckb_active") {
            this.deletedActiveCollection = true
            this.activeCount = 0
            this.activeRecords.clear()
        } else if (collection == this.stagingCollection) {
            this.stagingCount = 0
            this.stagingRecords.clear()
        }
        this.status(collection)
    }

    public func backup(collection: String): VectorBackup {
        let backup = VectorBackup()
        backup.collection = collection
        backup.valid = true
        backup.diagnostic = "ok"
        if (collection == "ckb_active") {
            for (record in this.activeRecords) {
                backup.records.add(record)
            }
        } else if (collection == this.stagingCollection) {
            for (record in this.stagingRecords) {
                backup.records.add(record)
            }
        }
        backup
    }

    public func backupWithDeadline(collection: String, deadlineAtMillis: Int64): VectorBackup {
        this.backup(collection)
    }

    public func restore(backup: VectorBackup): VectorStoreStatus {
        this.status(backup.collection)
    }
}

private func cangjieF4AdminDiagnosticsContain(validation: CangjieCandidateValidationResult, diagnostic: String): Bool {
    for (item in validation.diagnostics) {
        if (item == diagnostic) {
            return true
        }
    }
    false
}

private func cangjieF4AdminDiagnosticsContainPrefix(validation: CangjieCandidateValidationResult, prefix: String): Bool {
    for (item in validation.diagnostics) {
        if (item.startsWith(prefix)) {
            return true
        }
    }
    false
}
