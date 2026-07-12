package cangjie_community_knowledge_base_test

import std.collection.*
import std.fs.*
import std.io.*
import std.process.*
import std.unittest.*

private class P6S4SourceEventDeadlineClock <: CkbMillisClock {
    private var calls: Int64 = 0
    private let expireAtCall: Int64
    private let baseMillis: Int64

    public init(expireAtCall: Int64) {
        this.expireAtCall = expireAtCall
        this.baseMillis = ckbCoreNowMillis()
    }

    public func nowMillis(): Int64 {
        this.calls += 1
        if (this.calls == this.expireAtCall) { return this.baseMillis + 60000 }
        this.baseMillis
    }
}

private class P6S4NeverExpiredClock <: CkbMillisClock {
    public init() {}
    public func nowMillis(): Int64 { 0 }
}

private class P6S4RepositoryEventClock <: CkbMillisClock {
    private var offsetMillis: Int64 = 0

    public init() {}

    public func advance(millis: Int64): Unit {
        this.offsetMillis += millis
    }

    public func nowMillis(): Int64 {
        ckbCoreNowMillis() + this.offsetMillis
    }
}

private class P6S4FailingGateEvaluator <: CangjieCandidateValidationGateEvaluator {
    private let failedGate: String

    public init(failedGate: String) {
        this.failedGate = failedGate
    }

    public func restMcpParityPass(index: CangjieServingIndex): Bool {
        this.failedGate != "parity"
    }

    public func performanceProbe(index: CangjieServingIndex,
        queries: ArrayList<String>): CangjieServingPerformanceProbe {
        let probe = CangjieServingPerformanceProbe()
        probe.queryCount = queries.size
        probe.p95Cost = 1
        probe.threshold = 10000000
        probe.pass = this.failedGate != "performance"
        probe.evidenceHash = ckbReleaseEvidenceHash(
            "p6-s4-gate=${this.failedGate}|documents=${index.documents.size}|queries=${queries.size}")
        probe
    }
}

@Test
public class CkbP6SourceEventAcquisitionTest {
    @TestCase
    public func p6S4E01SourceEventValidationRecoversWithoutRefetchingArtifacts(): Unit {
        let root = "target/p6-s4-e01-source-event-recovery"
        p6S3EnsureEmpty(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        let baseline = newOfflineKnowledgeBase()
        _ = baseline.persistActiveSnapshot(store)
        let beforePointer = store.loadActiveSnapshotPointer()
        store.saveCangjieVersionManifest(defaultCangjieVersionManifest())
        let runner = P6S3PathResponseRunner("content", "P6S4ResumeMarker")
        let firstPlan = CangjieCandidatePromotionBudgetPlan()
        firstPlan.segmented = true
        firstPlan.validationBudgetMillis = 1
        firstPlan.workerSoftDeadlineAtMillis = ckbCoreNowMillis() + 60000
        firstPlan.validationDeadlineClockOverrideEnabled = true
        firstPlan.validationDeadlineClock = P6S4SourceEventDeadlineClock(2)
        let eventClock = P6S4RepositoryEventClock()
        let firstService = CkbCommandLoopService(config, store, sourceRunner: runner,
            sourceEventPromotionBudgetPlan: firstPlan,
            repositoryEventNowClock: eventClock)
        _ = firstService.start()
        let accepted = firstService.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("s4-e01", ["src/resume.cj"])))
        let first = firstService.runSchedulerTasks(p6S3SourceEventTasks(), true)
        let recoverable = store.loadRepositoryEventReceipt(accepted.dedupeKey)
        let sourceCallsAfterFirst = runner.calls.size
        let ownersBeforeResume = store.listCandidateCollectionOwners()
        @Expect(ownersBeforeResume.size, 1)
        let ownerBeforeResume = p6S4FirstOwner(ownersBeforeResume)
        let vectorContext = CkbCandidateAcquisitionContext()
        vectorContext.acquisitionId = ownerBeforeResume.acquisitionId
        vectorContext.schedulerRunId = ownerBeforeResume.schedulerRunId
        vectorContext.taskId = ownerBeforeResume.taskId
        vectorContext.candidateVersion = ownerBeforeResume.candidateVersion
        vectorContext.planHash = ownerBeforeResume.planHash
        vectorContext.recordsEvidenceHash = ownerBeforeResume.recordsEvidenceHash
        let spoolBeforeResume = store.loadVectorSpoolCheckpoint(vectorContext,
            ownerBeforeResume.collection)

        @Expect(accepted.status, "accepted")
        @Expect(first.failed, 1)
        @Expect(recoverable.state, "retryable")
        @Expect(recoverable.lastErrorCode, "candidate_validation_recoverable")
        @Expect(ownerBeforeResume.valid, true)
        @Expect(spoolBeforeResume.valid, true)

        eventClock.advance(2000)
        let resumed = firstService.runSchedulerTasks(p6S3SourceEventTasks(), true)
        let committed = store.loadRepositoryEventReceipt(accepted.dedupeKey)
        let ownerAfterResume = store.loadCandidateCollectionOwner(ownerBeforeResume.collection)
        let spoolAfterResume = store.loadVectorSpoolCheckpoint(vectorContext,
            ownerBeforeResume.collection)
        let ownersAfterResume = store.listCandidateCollectionOwners()
        let completedValidation = store.loadRepositoryEventValidationCheckpoint(
            p6S4CheckpointForOwner(committed, ownerAfterResume,
                beforePointer.activeVersion))

        @Expect(resumed.succeeded, 1)
        @Expect(committed.state, "committed")
        @Expect(runner.calls.size, sourceCallsAfterFirst)
        @Expect(ownerAfterResume.state, "committed_active")
        @Expect(ownersAfterResume.size, 1)
        let onlyOwnerAfterResume = p6S4FirstOwner(ownersAfterResume)
        @Expect(onlyOwnerAfterResume.collection, ownerBeforeResume.collection)
        @Expect(onlyOwnerAfterResume.state, "committed_active")
        @Expect(spoolAfterResume.valid, false)
        @Expect(completedValidation.valid, true)
        @Expect(completedValidation.phase, "completed")
        @Expect(completedValidation.vectorEvidenceHash, spoolBeforeResume.evidenceHash)
        @Expect(store.cleanupCandidateOwnerStaleTemps(), 0)
        @Expect(store.cleanupVectorBuildStaleTemps(vectorContext.acquisitionId), 0)
        @Expect(firstService.queryEvidencePack("P6S4ResumeMarker", 5).citations.size > 0, true)
    }

    @TestCase
    public func p6S4N04SourceEventCoverageFailureIsTerminalAndKeepsActiveSnapshot(): Unit {
        let root = "target/p6-s4-n04-source-event-quality-terminal"
        p6S3EnsureEmpty(root)
        let store = FileKnowledgeStore("${root}/store")
        _ = p6S4WriteCoverageFailureBaseline(store)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let beforePointer = store.loadActiveSnapshotPointer()
        let before = store.loadActiveSnapshot()
        let beforeGraph = newKnowledgeBaseFromStoreWithRuntime(store, config).kb.activeGraphBuild()
        store.saveCangjieVersionManifest(defaultCangjieVersionManifest())
        let service = CkbCommandLoopService(config, store,
            sourceRunner: P6S3PathResponseRunner("content", "CoverageTerminalMarker"))
        _ = service.start()
        let accepted = service.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("s4-n04", ["src/coverage.cj"])))
        let scheduled = service.runSchedulerTasks(p6S3SourceEventTasks(), true)
        let receipt = store.loadRepositoryEventReceipt(accepted.dedupeKey)
        let afterPointer = store.loadActiveSnapshotPointer()
        let after = store.loadActiveSnapshot()
        let afterGraph = newKnowledgeBaseFromStoreWithRuntime(store, config).kb.activeGraphBuild()
        let owners = store.listCandidateCollectionOwners()
        @Expect(owners.size, 1)
        let owner = p6S4FirstOwner(owners)
        let checkpoint = CkbRepositoryEventValidationCheckpoint()
        checkpoint.eventId = receipt.canonicalSha256
        checkpoint.runKey = owner.planHash
        checkpoint.acquisitionId = owner.acquisitionId
        checkpoint.planHash = owner.planHash
        checkpoint.recordsEvidenceHash = owner.recordsEvidenceHash
        checkpoint.candidateVersion = owner.candidateVersion
        checkpoint.activeBaseVersion = beforePointer.activeVersion
        let terminal = store.loadRepositoryEventValidationCheckpoint(checkpoint)

        @Expect(accepted.status, "accepted")
        @Expect(scheduled.failed, 1)
        @Expect(receipt.state, "failed")
        @Expect(receipt.lastErrorCode, "candidate_validation_failed")
        @Expect(terminal.valid, true)
        @Expect(terminal.phase, "terminal_failed")
        @Expect(owner.state, "cleaned")
        @Expect(terminal.candidateVersion, owner.candidateVersion)
        @Expect(afterPointer.activeVersion, beforePointer.activeVersion)
        @Expect(after.rawRecords.size, before.rawRecords.size)
        @Expect(after.normalizedRecords.size, before.normalizedRecords.size)
        @Expect(after.vectorRecords.size, before.vectorRecords.size)
        @Expect(afterGraph.nodes.size, beforeGraph.nodes.size)
        @Expect(afterGraph.edges.size, beforeGraph.edges.size)
        @Expect(p6S4GraphEvidence(afterGraph), p6S4GraphEvidence(beforeGraph))
    }

    @TestCase
    public func p6S4N05SourceEventParityFailureIsTerminalWithoutDeadline(): Unit {
        let root = "target/p6-s4-n05-source-event-parity-terminal"
        p6S3EnsureEmpty(root)
        let store = FileKnowledgeStore("${root}/store")
        let baseline = newOfflineKnowledgeBase()
        _ = baseline.persistActiveSnapshot(store)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let beforePointer = store.loadActiveSnapshotPointer()
        let before = store.loadActiveSnapshot()
        let beforeGraph = newKnowledgeBaseFromStoreWithRuntime(store, config).kb.activeGraphBuild()
        store.saveCangjieVersionManifest(defaultCangjieVersionManifest())
        let plan = CangjieCandidatePromotionBudgetPlan()
        plan.validationGateEvaluator = P6S4FailingGateEvaluator("parity")
        let service = CkbCommandLoopService(config, store,
            sourceRunner: P6S3PathResponseRunner("content", "ParityTerminalMarker"),
            sourceEventPromotionBudgetPlan: plan)
        _ = service.start()
        let accepted = service.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("s4-n05", ["src/parity.cj"])))
        let scheduled = service.runSchedulerTasks(p6S3SourceEventTasks(), true)
        let receipt = store.loadRepositoryEventReceipt(accepted.dedupeKey)
        let owners = store.listCandidateCollectionOwners()
        @Expect(owners.size, 1)
        let owner = p6S4FirstOwner(owners)
        let expected = p6S4CheckpointForOwner(receipt, owner, beforePointer.activeVersion)
        let terminal = store.loadRepositoryEventValidationCheckpoint(expected)
        let afterPointer = store.loadActiveSnapshotPointer()
        let after = store.loadActiveSnapshot()
        let afterGraph = newKnowledgeBaseFromStoreWithRuntime(store, config).kb.activeGraphBuild()

        @Expect(scheduled.failed, 1)
        @Expect(receipt.state, "failed")
        @Expect(receipt.lastErrorCode, "candidate_validation_failed")
        @Expect(terminal.valid, true)
        @Expect(terminal.phase, "terminal_failed")
        @Expect(terminal.transportParityPass, false)
        @Expect(owner.state, "cleaned")
        @Expect(afterPointer.activeVersion, beforePointer.activeVersion)
        @Expect(after.rawRecords.size, before.rawRecords.size)
        @Expect(after.normalizedRecords.size, before.normalizedRecords.size)
        @Expect(after.vectorRecords.size, before.vectorRecords.size)
        @Expect(afterGraph.nodes.size, beforeGraph.nodes.size)
        @Expect(afterGraph.edges.size, beforeGraph.edges.size)
        @Expect(p6S4GraphEvidence(afterGraph), p6S4GraphEvidence(beforeGraph))
    }

    @TestCase
    public func p6S4N06SourceEventPerformanceFailureIsTerminalWithoutDeadline(): Unit {
        let root = "target/p6-s4-n06-source-event-performance-terminal"
        p6S3EnsureEmpty(root)
        let store = FileKnowledgeStore("${root}/store")
        let baseline = newOfflineKnowledgeBase()
        _ = baseline.persistActiveSnapshot(store)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let beforePointer = store.loadActiveSnapshotPointer()
        let before = store.loadActiveSnapshot()
        let beforeGraph = newKnowledgeBaseFromStoreWithRuntime(store, config).kb.activeGraphBuild()
        store.saveCangjieVersionManifest(defaultCangjieVersionManifest())
        let plan = CangjieCandidatePromotionBudgetPlan()
        plan.validationGateEvaluator = P6S4FailingGateEvaluator("performance")
        let service = CkbCommandLoopService(config, store,
            sourceRunner: P6S3PathResponseRunner("content", "PerformanceTerminalMarker"),
            sourceEventPromotionBudgetPlan: plan)
        _ = service.start()
        let accepted = service.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("s4-n06", ["src/performance.cj"])))
        let scheduled = service.runSchedulerTasks(p6S3SourceEventTasks(), true)
        let receipt = store.loadRepositoryEventReceipt(accepted.dedupeKey)
        let owners = store.listCandidateCollectionOwners()
        @Expect(owners.size, 1)
        let owner = p6S4FirstOwner(owners)
        let expected = p6S4CheckpointForOwner(receipt, owner, beforePointer.activeVersion)
        let terminal = store.loadRepositoryEventValidationCheckpoint(expected)
        let afterPointer = store.loadActiveSnapshotPointer()
        let after = store.loadActiveSnapshot()
        let afterGraph = newKnowledgeBaseFromStoreWithRuntime(store, config).kb.activeGraphBuild()

        @Expect(scheduled.failed, 1)
        @Expect(receipt.state, "failed")
        @Expect(receipt.lastErrorCode, "candidate_validation_failed")
        @Expect(terminal.valid, true)
        @Expect(terminal.phase, "terminal_failed")
        @Expect(terminal.performancePass, false)
        @Expect(owner.state, "cleaned")
        @Expect(afterPointer.activeVersion, beforePointer.activeVersion)
        @Expect(after.rawRecords.size, before.rawRecords.size)
        @Expect(after.normalizedRecords.size, before.normalizedRecords.size)
        @Expect(after.vectorRecords.size, before.vectorRecords.size)
        @Expect(afterGraph.nodes.size, beforeGraph.nodes.size)
        @Expect(afterGraph.edges.size, beforeGraph.edges.size)
        @Expect(p6S4GraphEvidence(afterGraph), p6S4GraphEvidence(beforeGraph))
    }

    @TestCase
    public func p6S4U01ValidationCheckpointCodecBindsEventCandidateBaseAndCoverage(): Unit {
        let root = "target/p6-s4-u01-validation-checkpoint"
        p6S3EnsureEmpty(root)
        let store = FileKnowledgeStore("${root}/store")
        let checkpoint = p6S4ValidationCheckpoint("p6-s4-u01")

        store.saveRepositoryEventValidationCheckpoint(checkpoint)
        let loaded = store.loadRepositoryEventValidationCheckpoint(p6S4ValidationCheckpoint("p6-s4-u01"))
        let relative = ckbRepositoryEventValidationCheckpointRelativePath(checkpoint.acquisitionId)

        @Expect(relative, "metadata/candidate-validations/p6-validation-p6-s4-u01/checkpoint.ckb")
        @Expect(store.has(relative), true)
        @Expect(loaded.valid, true)
        @Expect(loaded.status, "ok")
        @Expect(loaded.eventId, checkpoint.eventId)
        @Expect(loaded.runKey, checkpoint.runKey)
        @Expect(loaded.candidateVersion, checkpoint.candidateVersion)
        @Expect(loaded.activeBaseVersion, checkpoint.activeBaseVersion)
        @Expect(loaded.documentCursor, 7)
        @Expect(loaded.documentTotal, 11)
        @Expect(loaded.currentPartition, "docs/中文🙂")
        @Expect(loaded.exactSymbolHits, 2)
        @Expect(loaded.validationEvidenceHash, checkpoint.validationEvidenceHash)
        @Expect(loaded.checksum, ckbRepositoryEventValidationCheckpointChecksum(loaded))
    }

    @TestCase
    public func p6S4N01ValidationCheckpointRejectsCorruptUtf8AndIdentityMismatch(): Unit {
        let root = "target/p6-s4-n01-validation-checkpoint"
        p6S3EnsureEmpty(root)
        let store = FileKnowledgeStore("${root}/store")
        let checkpoint = p6S4ValidationCheckpoint("p6-s4-n01")
        let expected = p6S4ValidationCheckpoint("p6-s4-n01")
        let relative = ckbRepositoryEventValidationCheckpointRelativePath(checkpoint.acquisitionId)

        store.saveRepositoryEventValidationCheckpoint(checkpoint)
        let canonical = store.readText(relative)
        store.writeLinesAtomically(relative, "schemaVersion=bad\n")
        @Expect(store.loadRepositoryEventValidationCheckpoint(expected).status,
            "validation_checkpoint_schema_mismatch")
        store.writeLinesAtomically(relative, canonical.replace(checkpoint.checksum, "hsha256:deadbeef"))
        @Expect(store.loadRepositoryEventValidationCheckpoint(expected).status,
            "validation_checkpoint_checksum_mismatch")
        store.writeLinesAtomically(relative, canonical.replace("documentTotal=11", "documentTotal=6"))
        @Expect(store.loadRepositoryEventValidationCheckpoint(expected).status,
            "validation_checkpoint_malformed")
        store.writeLinesAtomically(relative, canonical.replace("documentCursor=7", "documentCursor=12"))
        @Expect(store.loadRepositoryEventValidationCheckpoint(expected).status,
            "validation_checkpoint_malformed")
        store.writeLinesAtomically(relative, canonical.replace("partitionCursor=1", "partitionCursor=3"))
        @Expect(store.loadRepositoryEventValidationCheckpoint(expected).status,
            "validation_checkpoint_malformed")
        store.writeLinesAtomically(relative, canonical.replace("partitionIdsJson=[\"global\",\"partition-p6\"]", "partitionIdsJson={malformed"))
        @Expect(store.loadRepositoryEventValidationCheckpoint(expected).status,
            "validation_checkpoint_malformed")
        store.writeLinesAtomically(relative, canonical.replace(checkpoint.worksetEvidenceHash, "not-a-sha256"))
        @Expect(store.loadRepositoryEventValidationCheckpoint(expected).status,
            "validation_checkpoint_malformed")
        File.writeTo(Path("${root}/store").join(relative), [UInt8(255), UInt8(254)])
        @Expect(store.loadRepositoryEventValidationCheckpoint(expected).status,
            "invalid_response_encoding")
        store.writeLinesAtomically(relative, canonical)
        let wrongBase = p6S4ValidationCheckpoint("p6-s4-n01")
        wrongBase.activeBaseVersion = "ckb-active-wrong"
        @Expect(store.loadRepositoryEventValidationCheckpoint(wrongBase).status,
            "validation_checkpoint_identity_mismatch")
    }

    @TestCase
    public func p6S4N02ValidationIndexArtifactRejectsChecksumIdentityAndUtf8Corruption(): Unit {
        let root = "target/p6-s4-n02-validation-index-artifact"
        p6S3EnsureEmpty(root)
        let store = FileKnowledgeStore("${root}/store")
        let checkpoint = p6S4ValidationCheckpoint("p6-s4-n02-artifact")
        let index = CangjieServingIndex()
        let document = CangjieServingDocument()
        document.documentId = "p6-s4-index-doc"
        document.recordKind = CangjieServingRecordKinds.DOC_SECTION
        document.title = "仓颉🙂 index artifact"
        document.text = "UTF-8 durable index body"
        document.sourceId = "source-p6-s4-index"
        document.contentHash = ckbReleaseEvidenceHash(document.text)
        document.citation = "test:中文🙂"
        document.targetVersion = "1.0.0"
        index.documents.add(document)
        let saved = store.saveRepositoryEventValidationIndexArtifact(checkpoint, index)
        let relative = ckbRepositoryEventValidationIndexArtifactPath(checkpoint.acquisitionId)
        let canonical = store.readText(relative)

        @Expect(saved.valid, true)
        @Expect(store.loadRepositoryEventValidationIndexArtifact(checkpoint).valid, true)
        @Expect(store.loadRepositoryEventValidationIndexArtifact(checkpoint).documents[0].title,
            "仓颉🙂 index artifact")
        store.writeLinesAtomically(relative, canonical.replace(saved.checksum, "deadbeef"))
        @Expect(store.loadRepositoryEventValidationIndexArtifact(checkpoint).status,
            "validation_index_artifact_checksum_mismatch")
        File.writeTo(Path("${root}/store").join(relative), [UInt8(255), UInt8(254)])
        @Expect(store.loadRepositoryEventValidationIndexArtifact(checkpoint).status,
            "invalid_response_encoding")
        store.writeLinesAtomically(relative, canonical)
        let wrong = p6S4ValidationCheckpoint("p6-s4-n02-artifact")
        wrong.activeBaseVersion = "ckb-active-other"
        @Expect(store.loadRepositoryEventValidationIndexArtifact(wrong).status,
            "validation_index_artifact_identity_mismatch")
    }

    @TestCase
    public func p6S4U02ValidationWorksetIsOrderIndependentAndEvidenceBound(): Unit {
        let first = p6S4ValidationIndex("source-p6-s4-a", "source-p6-s4-b", false)
        let reordered = p6S4ValidationIndex("source-p6-s4-a", "source-p6-s4-b", true)
        let firstWorkset = buildCangjieCandidateValidationWorkset(first)
        let reorderedWorkset = buildCangjieCandidateValidationWorkset(reordered)

        @Expect(firstWorkset.valid, true)
        @Expect(reorderedWorkset.valid, true)
        @Expect(firstWorkset.evidenceHash, reorderedWorkset.evidenceHash)
        @Expect(firstWorkset.orderedDocumentIndexes.size, 3)
        @Expect(firstWorkset.partitionIds.size >= 2, true)
        @Expect(firstWorkset.partitionStartCursors[0], 0)
        @Expect(firstWorkset.partitionEndCursors[firstWorkset.partitionEndCursors.size - 1], 3)
    }

    @TestCase
    public func p6S4B01ValidationWorksetPartitionCursorsCoverExactBoundaries(): Unit {
        let index = p6S4ValidationIndex("source-p6-s4-boundary-a", "source-p6-s4-boundary-b", false)
        let workset = buildCangjieCandidateValidationWorkset(index)
        var cursor: Int64 = 0

        for (partitionIndex in 0..workset.partitionIds.size) {
            @Expect(workset.partitionStartCursors[partitionIndex], cursor)
            @Expect(workset.partitionEndCursors[partitionIndex] > cursor, true)
            cursor = workset.partitionEndCursors[partitionIndex]
        }
        @Expect(cursor, index.documents.size)
    }

    @TestCase
    public func p6S4P01OnlyAffectedAndGlobalPartitionsAreSelected(): Unit {
        let source = "source-p6-s4-affected"
        var untouched = "source-p6-s4-untouched"
        var suffix: Int64 = 0
        while (cangjieCandidateValidationPartitionId(source) == cangjieCandidateValidationPartitionId(untouched)) {
            suffix += 1
            untouched = "source-p6-s4-untouched-${suffix}"
        }
        let workset = buildCangjieCandidateValidationWorkset(p6S4ValidationIndex(source, untouched, false))
        let changed = ArrayList<String>()
        changed.add(source)
        let affected = cangjieCandidateValidationAffectedPartitions(workset, changed)

        @Expect(p6S4StringListContains(affected, cangjieCandidateValidationPartitionId(source)), true)
        @Expect(p6S4StringListContains(affected, "global"), true)
        @Expect(p6S4StringListContains(affected, cangjieCandidateValidationPartitionId(untouched)), false)
    }

    @TestCase
    public func p6S3U01CanonicalUtf8ReceiptSortsAndDeduplicates(): Unit {
        let root = "target/p6-s3-acquisition-u01"
        p6S3EnsureEmpty(root)
        let store = FileKnowledgeStore("${root}/store")
        let service = CkbCommandLoopService(CkbRuntimeConfig(), store)
        let event = parseGitCodeRepositoryChangedEvent(p6S3EventJson("u01",
            ["src/中文🙂.cj", "src/z.cj", "src/a.cj", "src/z.cj"]))
        let accepted = service.acceptGitCodeRepositoryChangedEvent(event)
        let receipt = store.loadRepositoryEventReceipt(accepted.dedupeKey)

        @Expect(accepted.status, "accepted")
        @Expect(receipt.valid, true)
        @Expect(receipt.changedFiles.size, 3)
        @Expect(receipt.changedFiles[0], "src/a.cj")
        @Expect(receipt.changedFiles[1], "src/z.cj")
        @Expect(receipt.changedFiles[2], "src/中文🙂.cj")
        @Expect(receipt.canonicalSha256 != "", true)
    }

    @TestCase
    public func p6S3B01CacheRejectsMalformedAndInvalidUtf8(): Unit {
        let root = "target/p6-s3-acquisition-b01"
        p6S3EnsureEmpty(root)
        let store = FileKnowledgeStore("${root}/store")
        let service = CkbCommandLoopService(CkbRuntimeConfig(), store)
        let accepted = service.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("b01", ["src/a.cj"])))
        let receipt = store.loadRepositoryEventReceipt(accepted.dedupeKey)
        let request = SourceFetchRequest(SourceKinds.GITCODE_SOURCE,
            "https://fake.test/a", repo: receipt.repo, ref: receipt.ref, path: "src/a.cj")
        let content = SourceFetchResult()
        content.ok = true
        content.body = "package fake\n"
        content.bodyHash = stableSummaryHash(content.body)
        content.sourceUrl = request.url
        content.repo = request.repo
        content.ref = request.ref
        content.path = request.path
        @Expect(store.saveRepositoryEventFetchContent(receipt, "abcdef0123456789", request, content), true)
        let cached = store.loadRepositoryEventFetchContent(receipt, "abcdef0123456789", request)
        @Expect(cached.ok, true)
        @Expect(cached.status, "repository_event_content_cache_hit")
        @Expect(cached.body, content.body)
        let path = "metadata/repository-event-inbox/fetch/${ckbReleaseEvidenceHash("${receipt.eventId}|${receipt.repo.toAsciiLower()}|abcdef0123456789|src/a.cj")}.ckb"
        store.writeLinesAtomically(path, "schemaVersion=bad\n")
        @Expect(store.loadRepositoryEventFetchContent(receipt, "abcdef0123456789", request).status,
            "repository_event_content_cache_invalid")
        File.writeTo(Path("${root}/store").join(path), [UInt8(255), UInt8(254)])
        @Expect(store.loadRepositoryEventFetchContent(receipt, "abcdef0123456789", request).status,
            "invalid_response_encoding")
    }

    @TestCase
    public func p6S3N01InvalidPathDoesNotCreateDurableReceipt(): Unit {
        let root = "target/p6-s3-acquisition-n01"
        p6S3EnsureEmpty(root)
        let store = FileKnowledgeStore("${root}/store")
        let service = CkbCommandLoopService(CkbRuntimeConfig(), store)
        let event = parseGitCodeRepositoryChangedEvent(p6S3EventJson("n01", ["../secret.cj"]))

        @Expect(event.valid, false)
        @Expect(event.diagnostic, "invalid_changed_file")
        @Expect(store.has("metadata/repository-event-inbox/events"), false)
        @Expect(service.acceptedEventCountForTest(), 0)
    }

    @TestCase
    public func p6S3B02RecoverySidecarIsUtf8SafeAndHealthReportsPendingRecovery(): Unit {
        let root = "target/p6-s3-acquisition-b02"
        p6S3EnsureEmpty(root)
        let store = FileKnowledgeStore("${root}/store")
        let tx = p6S3WriteRecoveryTransaction(store, "hsha256:p6-s3-b02")
        let pointer = store.loadActiveSnapshotPointer()
        let sidecarPath = "transactions/${pointer.txId}/metadata/repository-event-recovery.ckb"
        let sidecar = store.readText(sidecarPath)
        var sidecarPayload = ""
        let sidecarLines = sidecar.split("\n")
        for (index in 0..sidecarLines.size) {
            let line = sidecarLines[index]
            if (index == sidecarLines.size - 1 && line == "") { continue }
            if (!line.startsWith("checksum=")) { sidecarPayload += line + "\n" }
        }

        @Expect(tx.ok, true)
        @Expect(sidecar.contains("pointerHash=${ckbReleaseEvidenceHash("${pointer.txId}|${pointer.activeVersion}|${pointer.manifestHash}|${pointer.freshnessHash}|${pointer.coverageHash}")}"), true)
        @Expect(sidecar.contains("checksum=${ckbReleaseEvidenceHash(sidecarPayload)}"), true)
        @Expect(store.loadActiveSnapshot().valid, true)
        @Expect(store.repositoryEventRecoverySidecarStatus().valid, true)
        let pending = CkbCommandLoopService(CkbRuntimeConfig(), store)
        let health = pending.handleLine("health").text
        @Expect(health.contains("activeStateSource=persisted_degraded"), true)
        @Expect(health.contains("restoreDiagnostic=committed_recovery_required"), true)

        // Startup restores the valid committed snapshot, then independently
        // validates and consumes its current-pointer recovery sidecar.
        _ = pending.start()
        @Expect(store.repositoryEventRecoverySidecarStatus().status,
            "repository_event_recovery_marker_missing")

        // Invalid UTF-8 must be classified exactly and must not be parsed.
        File.writeTo(Path("${root}/store").join(sidecarPath), [UInt8(255), UInt8(254)])
        @Expect(store.repositoryEventRecoverySidecarStatus().status,
            "invalid_response_encoding")
    }

    @TestCase
    public func p6S3N02CorruptSidecarCannotClearValidLiveRecoveryMarker(): Unit {
        let root = "target/p6-s3-acquisition-n02"
        p6S3EnsureEmpty(root)
        let store = FileKnowledgeStore("${root}/store")
        let tx = p6S3WriteRecoveryTransaction(store, "hsha256:p6-s3-n02")
        let pointer = store.loadActiveSnapshotPointer()
        let pointerHash = ckbReleaseEvidenceHash("${pointer.txId}|${pointer.activeVersion}|${pointer.manifestHash}|${pointer.freshnessHash}|${pointer.coverageHash}")
        store.saveRepositoryEventRecoveryMarker("hsha256:p6-s3-n02", pointer.txId,
            pointer.activeVersion, pointerHash)
        store.writeLinesAtomically(
            "transactions/${pointer.txId}/metadata/repository-event-recovery.ckb",
            "schemaVersion=corrupt\n")

        @Expect(tx.ok, true)
        @Expect(store.repositoryEventRecoveryMarkerStatus().valid, true)
        @Expect(store.repositoryEventRecoverySidecarStatus().status,
            "repository_event_recovery_sidecar_invalid")
        let blocked = CkbCommandLoopService(CkbRuntimeConfig(), store)
        _ = blocked.start()
        @Expect(store.repositoryEventRecoveryMarkerStatus().valid, true)
        @Expect(blocked.handleLine("health").text.contains(
            "activeStateSource=persisted_degraded"), true)
    }

    @TestCase
    public func p6S3E2E01HttpIngressWorkerFetchCommitAndQueryUseOnlyFakeTransport(): Unit {
        let root = "target/p6-s3-acquisition-e2e01"
        p6S3EnsureEmpty(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(defaultCangjieVersionManifest())
        let runner = FakeSourceFetchRunner()
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let accepted = service.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("e2e01", ["src/中文🙂.cj"])))
        let tasks = ArrayList<String>()
        tasks.add("cangjie_source_event_sync")
        let scheduled = service.runSchedulerTasks(tasks, true)
        let receipt = store.loadRepositoryEventReceipt(accepted.dedupeKey)

        @Expect(accepted.status, "accepted")
        @Expect(scheduled.ran, 1)
        @Expect(scheduled.succeeded, 1)
        @Expect(scheduled.failed, 0)
        @Expect(receipt.state, "committed")
        @Expect(receipt.resolvedCommit, "abcdef0123456789abcdef0123456789abcdef01")
        @Expect(store.loadActiveSnapshotPointer().valid, true)
        @Expect(store.repositoryEventRecoverySidecarStatus().status,
            "repository_event_recovery_marker_missing")
        @Expect(runner.calls.size > 0, true)
        @Expect(service.queryEvidencePack("HttpClient", 5).citations.size > 0, true)
    }

    @TestCase
    public func p6S3P02PinnedRedeliveryHydratesCacheWithoutRepositoryEventTransport(): Unit {
        let root = "target/p6-s3-acquisition-p02"
        p6S3EnsureEmpty(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(defaultCangjieVersionManifest())
        let runner = FakeSourceFetchRunner()
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let accepted = service.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("p02", ["src/cache.cj"])))
        let queued = store.loadRepositoryEventReceipt(accepted.dedupeKey)
        let pinnedCommit = "abcdef0123456789abcdef0123456789abcdef01"
        let pinned = store.pinRepositoryEventResolvedCommit(queued, pinnedCommit,
            ckbCoreNowMillis())
        let request = SourceRequestBuilder(gitCodeApiRoot: config.gitCodeBaseUrl)
            .gitCodeSourceRawWithFetchRef(pinned.repo, pinned.ref, pinnedCommit,
                "src/cache.cj")
        let cached = SourceFetchResult()
        cached.ok = true
        cached.status = "ok"
        cached.statusCode = 200
        cached.body = "package cache\npublic class HttpClient {}\n"
        cached.bodyHash = stableSummaryHash(cached.body)
        cached.sourceUrl = request.url
        cached.repo = request.repo
        cached.ref = request.ref
        cached.path = request.path
        cached.normalizedType = request.kind
        let tasks = ArrayList<String>()
        tasks.add("cangjie_source_event_sync")

        @Expect(pinned.valid, true)
        @Expect(store.saveRepositoryEventFetchContent(pinned, pinnedCommit, request, cached), true)
        @Expect(store.loadRepositoryEventFetchContent(pinned, pinnedCommit, request).ok, true)
        let scheduled = service.runSchedulerTasks(tasks, true)
        let committed = store.loadRepositoryEventReceipt(accepted.dedupeKey)
        @Expect(scheduled.succeeded, 1)
        @Expect(scheduled.failed, 0)
        @Expect(committed.state, "committed")
        @Expect(committed.resolvedCommit, pinnedCommit)
        @Expect(p6S3RepositoryEventPathTransportCalls(runner.calls, pinned.repo,
            "src/cache.cj"), 0)
        @Expect(service.queryEvidencePack("HttpClient", 5).citations.size > 0, true)
    }

    @TestCase
    public func p6S3N03TransientRawAndContentsFailuresRetryWithoutChangingPointer(): Unit {
        let root = "target/p6-s3-acquisition-n03"
        p6S3EnsureEmpty(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        _ = p6S3WriteRecoveryTransaction(store, "hsha256:p6-s3-n03-baseline")
        store.saveCangjieVersionManifest(defaultCangjieVersionManifest())
        let before = store.loadActiveSnapshotPointer()
        let runner = P6S3TransientContentRunner()
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let accepted = service.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("n03", ["src/retry.cj"])))
        let queued = store.loadRepositoryEventReceipt(accepted.dedupeKey)
        @Expect(store.pinRepositoryEventResolvedCommit(queued,
            "abcdef0123456789abcdef0123456789abcdef01", ckbCoreNowMillis()).valid, true)
        let tasks = ArrayList<String>()
        tasks.add("cangjie_source_event_sync")
        let scheduled = service.runSchedulerTasks(tasks, true)
        let retried = store.loadRepositoryEventReceipt(accepted.dedupeKey)
        let after = store.loadActiveSnapshotPointer()

        @Expect(scheduled.failed, 1)
        @Expect(retried.state, "retryable")
        @Expect(retried.lastErrorCode, "repository_event_content_fetch_failed")
        @Expect(after.txId, before.txId)
        @Expect(service.queryEvidencePack("HttpClient", 5).citations.size > 0, true)
    }

    @TestCase
    public func p6S3B03UnavailableAndTruncatedChangesUseTerminalPagedTreeInventory(): Unit {
        let unavailableRoot = "target/p6-s3-acquisition-b03-unavailable"
        p6S3EnsureEmpty(unavailableRoot)
        let unavailableConfig = CkbRuntimeConfig()
        unavailableConfig.networkEnabled = true
        let unavailableStore = FileKnowledgeStore("${unavailableRoot}/store")
        unavailableStore.saveCangjieVersionManifest(defaultCangjieVersionManifest())
        let unavailableRunner = P6S3TreeInventoryRunner("terminal")
        let unavailableService = CkbCommandLoopService(unavailableConfig, unavailableStore,
            sourceRunner: unavailableRunner)
        _ = unavailableService.start()
        let unavailableAccepted = unavailableService.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("b03-unavailable", ["src/partial.cj"],
                unavailable: true)))
        let tasks = ArrayList<String>()
        tasks.add("cangjie_source_event_sync")
        let unavailableScheduled = unavailableService.runSchedulerTasks(tasks, true)

        @Expect(unavailableAccepted.status, "accepted")
        @Expect(unavailableScheduled.succeeded, 1)
        @Expect(unavailableStore.loadRepositoryEventReceipt(unavailableAccepted.dedupeKey).state,
            "committed")
        @Expect(unavailableRunner.treePages.size, 2)
        @Expect(unavailableRunner.treePages[0], 1)
        @Expect(unavailableRunner.treePages[1], 2)
        @Expect(unavailableRunner.terminalPageReturned, true)

        let truncatedRoot = "target/p6-s3-acquisition-b03-truncated"
        p6S3EnsureEmpty(truncatedRoot)
        let truncatedConfig = CkbRuntimeConfig()
        truncatedConfig.networkEnabled = true
        let truncatedStore = FileKnowledgeStore("${truncatedRoot}/store")
        truncatedStore.saveCangjieVersionManifest(defaultCangjieVersionManifest())
        let truncatedRunner = P6S3TreeInventoryRunner("terminal")
        let truncatedService = CkbCommandLoopService(truncatedConfig, truncatedStore,
            sourceRunner: truncatedRunner)
        _ = truncatedService.start()
        let truncatedAccepted = truncatedService.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("b03-truncated", ["src/partial.cj"],
                truncated: true)))
        let truncatedScheduled = truncatedService.runSchedulerTasks(tasks, true)

        @Expect(truncatedAccepted.status, "accepted")
        @Expect(truncatedScheduled.succeeded, 1)
        @Expect(truncatedStore.loadRepositoryEventReceipt(truncatedAccepted.dedupeKey).state,
            "committed")
        @Expect(truncatedRunner.treePages.size, 2)
        @Expect(truncatedRunner.treePages[0], 1)
        @Expect(truncatedRunner.treePages[1], 2)
        @Expect(truncatedRunner.terminalPageReturned, true)
    }

    @TestCase
    public func p6S3N04MissingTerminalTreeFailsClosedWithoutChangingPointer(): Unit {
        let root = "target/p6-s3-acquisition-n04-missing-terminal"
        p6S3EnsureEmpty(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        _ = p6S3WriteRecoveryTransaction(store, "hsha256:p6-s3-n04-baseline")
        let before = store.loadActiveSnapshotPointer()
        let runner = P6S3TreeInventoryRunner("missing_terminal")
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let accepted = service.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("n04", ["src/partial.cj"],
                unavailable: true)))
        let tasks = ArrayList<String>()
        tasks.add("cangjie_source_event_sync")
        let scheduled = service.runSchedulerTasks(tasks, true)
        let failed = store.loadRepositoryEventReceipt(accepted.dedupeKey)
        let after = store.loadActiveSnapshotPointer()

        @Expect(scheduled.failed, 1)
        @Expect(failed.state, "failed")
        @Expect(failed.lastErrorCode, "repository_event_tree_fallback_bound_reached")
        @Expect(runner.treePages.size, 20)
        @Expect(runner.terminalPageReturned, false)
        @Expect(after.txId, before.txId)
        @Expect(after.activeVersion, before.activeVersion)
    }

    @TestCase
    public func p6S3N05TruncatedTreeFailsClosedWithoutChangingPointer(): Unit {
        let root = "target/p6-s3-acquisition-n05-truncated-tree"
        p6S3EnsureEmpty(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        _ = p6S3WriteRecoveryTransaction(store, "hsha256:p6-s3-n05-baseline")
        let before = store.loadActiveSnapshotPointer()
        let runner = P6S3TreeInventoryRunner("truncated")
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let accepted = service.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("n05", ["src/partial.cj"],
                truncated: true)))
        let tasks = ArrayList<String>()
        tasks.add("cangjie_source_event_sync")
        let scheduled = service.runSchedulerTasks(tasks, true)
        let failed = store.loadRepositoryEventReceipt(accepted.dedupeKey)
        let after = store.loadActiveSnapshotPointer()

        @Expect(scheduled.failed, 1)
        @Expect(failed.state, "failed")
        @Expect(failed.lastErrorCode, "repository_event_tree_fallback_bound_reached")
        @Expect(runner.treePages.size, 2)
        @Expect(runner.terminalPageReturned, true)
        @Expect(after.txId, before.txId)
        @Expect(after.activeVersion, before.activeVersion)
    }

    @TestCase
    public func p6S3N06TreeObjectAndCandidateBoundsFailClosedWithoutChangingPointer(): Unit {
        let objectRoot = "target/p6-s3-acquisition-n06-object-bound"
        p6S3EnsureEmpty(objectRoot)
        let objectConfig = CkbRuntimeConfig()
        objectConfig.networkEnabled = true
        let objectStore = FileKnowledgeStore("${objectRoot}/store")
        _ = p6S3WriteRecoveryTransaction(objectStore, "hsha256:p6-s3-n06-object-baseline")
        let objectBefore = objectStore.loadActiveSnapshotPointer()
        let objectRunner = P6S3TreeInventoryRunner("object_bound")
        let objectService = CkbCommandLoopService(objectConfig, objectStore,
            sourceRunner: objectRunner)
        _ = objectService.start()
        let objectAccepted = objectService.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("n06-object", ["src/partial.cj"],
                unavailable: true)))
        let tasks = ArrayList<String>()
        tasks.add("cangjie_source_event_sync")
        let objectScheduled = objectService.runSchedulerTasks(tasks, true)
        let objectFailed = objectStore.loadRepositoryEventReceipt(objectAccepted.dedupeKey)
        let objectAfter = objectStore.loadActiveSnapshotPointer()

        @Expect(objectScheduled.failed, 1)
        @Expect(objectFailed.state, "failed")
        @Expect(objectFailed.lastErrorCode, "repository_event_tree_fallback_bound_reached")
        @Expect(objectRunner.treePages.size, 1)
        @Expect(objectAfter.txId, objectBefore.txId)
        @Expect(objectAfter.activeVersion, objectBefore.activeVersion)

        let candidateRoot = "target/p6-s3-acquisition-n06-candidate-bound"
        p6S3EnsureEmpty(candidateRoot)
        let candidateConfig = CkbRuntimeConfig()
        candidateConfig.networkEnabled = true
        let candidateStore = FileKnowledgeStore("${candidateRoot}/store")
        _ = p6S3WriteRecoveryTransaction(candidateStore, "hsha256:p6-s3-n06-candidate-baseline")
        let candidateBefore = candidateStore.loadActiveSnapshotPointer()
        let candidateRunner = P6S3TreeInventoryRunner("candidate_bound")
        let candidateService = CkbCommandLoopService(candidateConfig, candidateStore,
            sourceRunner: candidateRunner)
        _ = candidateService.start()
        let candidateAccepted = candidateService.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("n06-candidate", ["src/partial.cj"],
                unavailable: true)))
        let candidateScheduled = candidateService.runSchedulerTasks(tasks, true)
        let candidateFailed = candidateStore.loadRepositoryEventReceipt(candidateAccepted.dedupeKey)
        let candidateAfter = candidateStore.loadActiveSnapshotPointer()

        @Expect(candidateScheduled.failed, 1)
        @Expect(candidateFailed.state, "failed")
        @Expect(candidateFailed.lastErrorCode, "repository_event_tree_fallback_bound_reached")
        @Expect(candidateRunner.treePages.size, 2)
        @Expect(candidateRunner.terminalPageReturned, true)
        @Expect(candidateAfter.txId, candidateBefore.txId)
        @Expect(candidateAfter.activeVersion, candidateBefore.activeVersion)
    }

    @TestCase
    public func p6S3P03Double404DeletesEventContentFromCommittedRawNormalizedAndCandidate(): Unit {
        let root = "target/p6-s3-acquisition-p03-double-404"
        p6S3EnsureEmpty(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(defaultCangjieVersionManifest())
        let path = "src/removed.cj"
        let firstService = CkbCommandLoopService(config, store,
            sourceRunner: P6S3PathResponseRunner("content", "RemovedMarker"))
        _ = firstService.start()
        let first = firstService.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("p03-first", [path])))
        let tasks = p6S3SourceEventTasks()
        @Expect(firstService.runSchedulerTasks(tasks, true).succeeded, 1)
        let before = store.loadActiveSnapshot()
        @Expect(p6S3RawPathCount(before.rawRecords, path), 1)
        let legacyId = "scheduled-cangjie_source_event_sync-${stableSummaryHash("tombstone-legacy:${path}")}"
        @Expect(p6S3RewriteSourceIdAsLegacy(store, path, legacyId), true)

        let deleteService = CkbCommandLoopService(config, store,
            sourceRunner: P6S3PathResponseRunner("double_404", ""))
        _ = deleteService.start()
        let deleted = deleteService.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("p03-delete", [path])))
        let scheduled = deleteService.runSchedulerTasks(tasks, true)
        let committed = store.loadActiveSnapshot()
        let receipt = store.loadRepositoryEventReceipt(deleted.dedupeKey)
        let candidate = store.readText("normalized/candidate/${committed.candidateVersion}.ckb")

        @Expect(scheduled.succeeded, 1)
        @Expect(receipt.state, "committed")
        @Expect(p6S3RawPathCount(committed.rawRecords, path), 0)
        @Expect(p6S3NormalizedPathCount(committed.normalizedRecords, path), 0)
        @Expect(p6S3NormalizedPathCount(committed.activeIndex, path), 0)
        @Expect(p6S3RawSourceIdPresent(committed.rawRecords, legacyId), false)
        @Expect(p6S3NormalizedSourceIdPresent(committed.normalizedRecords, legacyId), false)
        @Expect(candidate.contains(path), false)
    }

    @TestCase
    public func p6S3N07Single404Then5xxOrNetworkRetainsContentAndRetriesWithoutPointerChange(): Unit {
        let serverRoot = "target/p6-s3-acquisition-n07-single-404-5xx"
        p6S3EnsureEmpty(serverRoot)
        let serverConfig = CkbRuntimeConfig()
        serverConfig.networkEnabled = true
        let serverStore = FileKnowledgeStore("${serverRoot}/store")
        serverStore.saveCangjieVersionManifest(defaultCangjieVersionManifest())
        let path = "src/retain.cj"
        let firstServer = CkbCommandLoopService(serverConfig, serverStore,
            sourceRunner: P6S3PathResponseRunner("content", "RetainedMarker"))
        _ = firstServer.start()
        let firstAccepted = firstServer.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("n07-server-first", [path])))
        let tasks = p6S3SourceEventTasks()
        @Expect(firstServer.runSchedulerTasks(tasks, true).succeeded, 1)
        let serverBefore = serverStore.loadActiveSnapshotPointer()
        let serverFailure = CkbCommandLoopService(serverConfig, serverStore,
            sourceRunner: P6S3PathResponseRunner("raw_404_contents_5xx", ""))
        _ = serverFailure.start()
        let failedAccepted = serverFailure.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("n07-server-failure", [path])))
        let serverScheduled = serverFailure.runSchedulerTasks(tasks, true)
        let serverReceipt = serverStore.loadRepositoryEventReceipt(failedAccepted.dedupeKey)
        let serverAfter = serverStore.loadActiveSnapshotPointer()

        @Expect(firstAccepted.status, "accepted")
        @Expect(serverScheduled.failed, 1)
        @Expect(serverReceipt.state, "retryable")
        @Expect(serverReceipt.lastErrorCode, "repository_event_content_fetch_failed")
        @Expect(p6S3RawPathCount(serverStore.loadActiveSnapshot().rawRecords, path), 1)
        @Expect(serverAfter.txId, serverBefore.txId)
        @Expect(serverAfter.activeVersion, serverBefore.activeVersion)

        let networkRoot = "target/p6-s3-acquisition-n07-network"
        p6S3EnsureEmpty(networkRoot)
        let networkConfig = CkbRuntimeConfig()
        networkConfig.networkEnabled = true
        let networkStore = FileKnowledgeStore("${networkRoot}/store")
        networkStore.saveCangjieVersionManifest(defaultCangjieVersionManifest())
        let firstNetwork = CkbCommandLoopService(networkConfig, networkStore,
            sourceRunner: P6S3PathResponseRunner("content", "RetainedMarker"))
        _ = firstNetwork.start()
        let networkFirst = firstNetwork.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("n07-network-first", [path])))
        @Expect(firstNetwork.runSchedulerTasks(tasks, true).succeeded, 1)
        let networkBefore = networkStore.loadActiveSnapshotPointer()
        let networkFailure = CkbCommandLoopService(networkConfig, networkStore,
            sourceRunner: P6S3PathResponseRunner("network", ""))
        _ = networkFailure.start()
        let networkAccepted = networkFailure.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("n07-network-failure", [path])))
        let networkScheduled = networkFailure.runSchedulerTasks(tasks, true)
        let networkReceipt = networkStore.loadRepositoryEventReceipt(networkAccepted.dedupeKey)
        let networkAfter = networkStore.loadActiveSnapshotPointer()

        @Expect(networkFirst.status, "accepted")
        @Expect(networkScheduled.failed, 1)
        @Expect(networkReceipt.state, "retryable")
        @Expect(networkReceipt.lastErrorCode, "repository_event_content_fetch_failed")
        @Expect(p6S3RawPathCount(networkStore.loadActiveSnapshot().rawRecords, path), 1)
        @Expect(networkAfter.txId, networkBefore.txId)
        @Expect(networkAfter.activeVersion, networkBefore.activeVersion)
    }

    @TestCase
    public func p6S3P04SamePathReplacementAndLegacyBodyHashIdMigrationDoNotDuplicate(): Unit {
        let root = "target/p6-s3-acquisition-p04-replace-legacy"
        p6S3EnsureEmpty(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(defaultCangjieVersionManifest())
        let path = "src/replaced.cj"
        let tasks = p6S3SourceEventTasks()
        let firstService = CkbCommandLoopService(config, store,
            sourceRunner: P6S3PathResponseRunner("content", "ReplacementOne"))
        _ = firstService.start()
        let first = firstService.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("p04-first", [path])))
        @Expect(firstService.runSchedulerTasks(tasks, true).succeeded, 1)
        let firstSnapshot = store.loadActiveSnapshot()
        let firstNormalizedCount = p6S3NormalizedPathCount(firstSnapshot.normalizedRecords, path)

        let replacementService = CkbCommandLoopService(config, store,
            sourceRunner: P6S3PathResponseRunner("content", "ReplacementTwo"))
        _ = replacementService.start()
        let replacement = replacementService.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("p04-replacement", [path])))
        @Expect(replacementService.runSchedulerTasks(tasks, true).succeeded, 1)
        let replacementSnapshot = store.loadActiveSnapshot()

        @Expect(replacement.status, "accepted")
        @Expect(p6S3RawPathCount(replacementSnapshot.rawRecords, path), 1)
        @Expect(p6S3NormalizedPathCount(replacementSnapshot.normalizedRecords, path),
            firstNormalizedCount)
        @Expect(p6S3RecordsContainChunk(replacementSnapshot.normalizedRecords, "ReplacementOne"), false)
        @Expect(p6S3RecordsContainChunk(replacementSnapshot.normalizedRecords, "ReplacementTwo"), true)

        let legacyId = "scheduled-cangjie_source_event_sync-${stableSummaryHash("legacy:${path}")}"
        @Expect(p6S3RewriteSourceIdAsLegacy(store, path, legacyId), true)
        let migratedService = CkbCommandLoopService(config, store,
            sourceRunner: P6S3PathResponseRunner("content", "ReplacementThree"))
        _ = migratedService.start()
        let migrated = migratedService.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("p04-migrated", [path])))
        @Expect(migratedService.runSchedulerTasks(tasks, true).succeeded, 1)
        let migratedSnapshot = store.loadActiveSnapshot()

        @Expect(migrated.status, "accepted")
        @Expect(p6S3RawPathCount(migratedSnapshot.rawRecords, path), 1)
        @Expect(p6S3NormalizedPathCount(migratedSnapshot.normalizedRecords, path),
            firstNormalizedCount)
        @Expect(p6S3RawSourceIdPresent(migratedSnapshot.rawRecords, legacyId), false)
        @Expect(p6S3NormalizedSourceIdPresent(migratedSnapshot.normalizedRecords, legacyId), false)
        @Expect(p6S3RecordsContainChunk(migratedSnapshot.normalizedRecords, "ReplacementTwo"), false)
        @Expect(p6S3RecordsContainChunk(migratedSnapshot.normalizedRecords, "ReplacementThree"), true)
    }

    @TestCase
    public func p6S3P05RepositoryEventReplacementAndTombstoneAreRefScoped(): Unit {
        let root = "target/p6-s3-acquisition-p05-ref-scoped"
        p6S3EnsureEmpty(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(defaultCangjieVersionManifest())
        let path = "src/ref-scoped.cj"
        let tasks = p6S3SourceEventTasks()

        let mainFirst = CkbCommandLoopService(config, store,
            sourceRunner: P6S3PathResponseRunner("content", "MainOne"))
        _ = mainFirst.start()
        _ = mainFirst.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("p05-main-one", [path])))
        @Expect(mainFirst.runSchedulerTasks(tasks, true).succeeded, 1)
        let releaseFirst = CkbCommandLoopService(config, store,
            sourceRunner: P6S3PathResponseRunner("content", "ReleaseOne"))
        _ = releaseFirst.start()
        _ = releaseFirst.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("p05-release-one", [path],
                ref: "release/x")))
        @Expect(releaseFirst.runSchedulerTasks(tasks, true).succeeded, 1)
        let releaseLegacyId = "scheduled-cangjie_source_event_sync-${stableSummaryHash("p05-release:${path}")}"
        @Expect(p6S3RewriteSourceIdAsLegacy(store, path, releaseLegacyId,
            ref: "release/x"), true)

        let mainReplacement = CkbCommandLoopService(config, store,
            sourceRunner: P6S3PathResponseRunner("content", "MainTwo"))
        _ = mainReplacement.start()
        _ = mainReplacement.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("p05-main-two", [path])))
        @Expect(mainReplacement.runSchedulerTasks(tasks, true).succeeded, 1)
        let replaced = store.loadActiveSnapshot()

        @Expect(p6S3RawPathRefCount(replaced.rawRecords, path, "main"), 1)
        @Expect(p6S3RawPathRefCount(replaced.rawRecords, path, "release/x"), 1)
        @Expect(p6S3NormalizedPathRefCount(replaced.normalizedRecords, path, "main") > 0, true)
        @Expect(p6S3NormalizedPathRefCount(replaced.normalizedRecords, path, "release/x") > 0, true)
        @Expect(p6S3RawRefContent(replaced.rawRecords, path, "main"), "package event\npublic class MainTwo {}\n")
        @Expect(p6S3RawRefContent(replaced.rawRecords, path, "release/x"), "package event\npublic class ReleaseOne {}\n")
        @Expect(p6S3RawSourceIdPresent(replaced.rawRecords, releaseLegacyId), true)
        @Expect(p6S3NormalizedSourceIdPresent(replaced.normalizedRecords, releaseLegacyId), true)

        let mainDelete = CkbCommandLoopService(config, store,
            sourceRunner: P6S3PathResponseRunner("double_404", ""))
        _ = mainDelete.start()
        let deleted = mainDelete.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("p05-main-delete", [path])))
        @Expect(mainDelete.runSchedulerTasks(tasks, true).succeeded, 1)
        let after = store.loadActiveSnapshot()

        @Expect(store.loadRepositoryEventReceipt(deleted.dedupeKey).state, "committed")
        @Expect(p6S3RawPathRefCount(after.rawRecords, path, "main"), 0)
        @Expect(p6S3RawPathRefCount(after.rawRecords, path, "release/x"), 1)
        @Expect(p6S3NormalizedPathRefCount(after.normalizedRecords, path, "main"), 0)
        @Expect(p6S3NormalizedPathRefCount(after.normalizedRecords, path, "release/x") > 0, true)
        @Expect(p6S3NormalizedPathRefCount(after.activeIndex, path, "main"), 0)
        @Expect(p6S3NormalizedPathRefCount(after.activeIndex, path, "release/x") > 0, true)
        @Expect(p6S3RawRefContent(after.rawRecords, path, "release/x"), "package event\npublic class ReleaseOne {}\n")
        @Expect(p6S3RawSourceIdPresent(after.rawRecords, releaseLegacyId), true)
        @Expect(p6S3NormalizedSourceIdPresent(after.normalizedRecords, releaseLegacyId), true)
        @Expect(mainDelete.queryEvidencePack("ReleaseOne", 5).citations.size > 0, true)
    }

    @TestCase
    public func p6S3B04BranchAndRefControlRecordsNeverEnterCommittedContent(): Unit {
        let root = "target/p6-s3-acquisition-b04-control-records"
        p6S3EnsureEmpty(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(defaultCangjieVersionManifest())
        let runner = P6S3PathResponseRunner("content", "ControlIsolationMarker")
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let accepted = service.acceptGitCodeRepositoryChangedEvent(
            parseGitCodeRepositoryChangedEvent(p6S3EventJson("b04", ["src/control.cj"])))
        let scheduled = service.runSchedulerTasks(p6S3SourceEventTasks(), true)
        let snapshot = store.loadActiveSnapshot()

        @Expect(accepted.status, "accepted")
        @Expect(scheduled.succeeded, 1)
        @Expect(p6S3HasRequestKind(runner.calls, SourceKinds.GITCODE_BRANCH), true)
        @Expect(p6S3RawControlRecordCount(snapshot.rawRecords), 0)
        @Expect(p6S3NormalizedControlRecordCount(snapshot.normalizedRecords), 0)
        @Expect(p6S3NormalizedControlRecordCount(snapshot.activeIndex), 0)
        @Expect(p6S3VectorControlRecordCount(snapshot.vectorRecords), 0)
    }
}

private func p6S4WriteCoverageFailureBaseline(store: FileKnowledgeStore): CkbActiveSnapshotTransactionResult {
    let kb = KnowledgeBase(FakeClock(0))
    let records = ArrayList<NormalizedRecord>()
    let record = NormalizedRecord()
    record.sourceId = "p6-s4-coverage-baseline"
    record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    record.title = "coverage baseline"
    record.chunk = "A deliberately narrow baseline without tool or negative-rule coverage."
    record.citation = "test:p6-s4-coverage-baseline"
    record.metadata.sourceSet = CangjieSourceSets.DOCS
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.TRUSTED
    record.metadata.targetVersion = "1.0.0"
    records.add(record)
    let candidate = kb.stageCandidateRecords("p6-s4-coverage-base-candidate", records)
    let vector = VectorStoreStatus()
    vector.collection = "active"
    vector.dimension = 16
    vector.count = records.size
    vector.state = EmbeddingProviderState.READY
    _ = kb.commitCandidateToActiveAfterVectorReady("p6-s4-coverage-base-active",
        "active", vector)
    kb.persistActiveSnapshot(store)
}

private func p6S4ValidationCheckpoint(id: String): CkbRepositoryEventValidationCheckpoint {
    let checkpoint = CkbRepositoryEventValidationCheckpoint()
    checkpoint.eventId = "event-${id}"
    checkpoint.runKey = "run-${id}"
    checkpoint.acquisitionId = "p6-validation-${id}"
    checkpoint.planHash = ckbReleaseEvidenceHash("plan-${id}")
    checkpoint.recordsEvidenceHash = ckbReleaseEvidenceHash("records-${id}")
    checkpoint.candidateVersion = "ckb-candidate-${id}"
    checkpoint.activeBaseVersion = "ckb-active-base-${id}"
    checkpoint.phase = "validation_documents"
    checkpoint.documentCursor = 7
    checkpoint.documentTotal = 11
    checkpoint.partitionCursor = 1
    checkpoint.partitionCount = 2
    checkpoint.partitionIds.add("global")
    checkpoint.partitionIds.add("partition-p6")
    checkpoint.worksetEvidenceHash = ckbReleaseEvidenceHash("workset-${id}")
    checkpoint.currentPartition = "docs/中文🙂"
    checkpoint.completedPartitionsEvidenceHash = ckbReleaseEvidenceHash("partitions-${id}")
    checkpoint.exactSymbolHits = 2
    checkpoint.docSectionHits = 3
    checkpoint.toolManualHits = 1
    checkpoint.negativeRuleHits = 4
    checkpoint.moduleHits = 5
    checkpoint.availabilityHits = 6
    checkpoint.deltaEvidenceHash = ckbReleaseEvidenceHash("delta-${id}")
    checkpoint.overlayEvidenceHash = ckbReleaseEvidenceHash("overlay-${id}")
    checkpoint.vectorEvidenceHash = ckbReleaseEvidenceHash("vector-${id}")
    checkpoint.validationEvidenceHash = ckbReleaseEvidenceHash("validation-${id}")
    checkpoint
}

private func p6S4CheckpointForOwner(receipt: CkbRepositoryEventReceipt,
    owner: CkbCandidateCollectionOwner,
    activeBaseVersion: String): CkbRepositoryEventValidationCheckpoint {
    let checkpoint = CkbRepositoryEventValidationCheckpoint()
    checkpoint.eventId = receipt.canonicalSha256
    checkpoint.runKey = owner.planHash
    checkpoint.acquisitionId = owner.acquisitionId
    checkpoint.planHash = owner.planHash
    checkpoint.recordsEvidenceHash = owner.recordsEvidenceHash
    checkpoint.candidateVersion = owner.candidateVersion
    checkpoint.activeBaseVersion = activeBaseVersion
    checkpoint
}

private func p6S4FirstOwner(owners: ArrayList<CkbCandidateCollectionOwner>): CkbCandidateCollectionOwner {
    if (owners.size > 0) { return owners[0] }
    CkbCandidateCollectionOwner()
}

private func p6S4GraphEvidence(graph: GraphBuildResult): String {
    let out = StringBuilder()
    out.append("nodes=${graph.nodes.size}|edges=${graph.edges.size}")
    for (node in graph.nodes) {
        out.append("|n=${node.nodeId}:${node.nodeType}:${node.sourceId}:${node.knowledgeVersion}")
    }
    for (edge in graph.edges) {
        out.append("|e=${edge.edgeId}:${edge.edgeType}:${edge.fromNodeId}:${edge.toNodeId}:${edge.sourceId}:${edge.knowledgeVersion}")
    }
    ckbReleaseEvidenceHash(out.toString())
}

private func p6S4ValidationIndex(firstSource: String, secondSource: String,
    reversed: Bool): CangjieServingIndex {
    let index = CangjieServingIndex()
    let first = p6S4ServingDocument(firstSource, "first")
    let second = p6S4ServingDocument(secondSource, "second")
    let global = p6S4ServingDocument("", "global")
    if (reversed) {
        index.documents.add(global)
        index.documents.add(second)
        index.documents.add(first)
    } else {
        index.documents.add(first)
        index.documents.add(second)
        index.documents.add(global)
    }
    index
}

private func p6S4ServingDocument(sourceId: String, id: String): CangjieServingDocument {
    let document = CangjieServingDocument()
    document.sourceId = sourceId
    document.documentId = "p6-s4-doc-${id}"
    document.contentHash = ckbReleaseEvidenceHash("p6-s4-content-${id}")
    document.recordKind = CangjieServingRecordKinds.DOC_SECTION
    document
}

private func p6S4StringListContains(values: ArrayList<String>, expected: String): Bool {
    for (value in values) {
        if (value == expected) { return true }
    }
    false
}

private func p6S3EventJson(eventId: String, paths: Array<String>, unavailable!: Bool = false,
    truncated!: Bool = false, ref!: String = "main"): String {
    var items = ""
    for (index in 0..paths.size) {
        if (index > 0) { items += "," }
        items += "\"${paths[index]}\""
    }
    "{\"contractVersion\":\"gcm-ckb-repository-change-v1\",\"eventId\":\"p6-s3-${eventId}\",\"deliveryId\":\"p6-s3-delivery-${eventId}\",\"provider\":\"gitcode\",\"eventType\":\"merge_request\",\"action\":\"merged\",\"state\":\"merged\",\"reason\":\"pr_merged\",\"repo\":\"cangjie/stdx\",\"ref\":\"${ref}\",\"prNumber\":1,\"changedFilesUnavailable\":${unavailable},\"changedFilesTruncated\":${truncated},\"changedFiles\":[${items}]}"
}

private func p6S3EnsureEmpty(root: String): Unit {
    let path = Path(root)
    if (exists(path)) { _ = launch("/bin/rm", ["-rf", path.toString()]).wait() }
    Directory.create(path, recursive: true)
}

private func p6S3WriteRecoveryTransaction(store: FileKnowledgeStore,
    eventIdentity: String): CkbActiveSnapshotTransactionResult {
    let kb = newOfflineKnowledgeBase()
    let status = kb.status()
    store.writeActiveSnapshotTransaction(status, kb.rawRecordSnapshot(),
        kb.activeRecordSnapshot(), kb.activeRecordSnapshot(),
        ArrayList<VectorRecord>(), status.storage.vectorActiveCollection,
        kb.activeGraphBuild(), persistVectorFile: false,
        repositoryEventIdentity: eventIdentity)
}

private func p6S3RepositoryEventPathTransportCalls(calls: ArrayList<SourceFetchRequest>,
    repo: String, path: String): Int64 {
    var count: Int64 = 0
    for (call in calls) {
        if (call.repo == repo && (call.kind == SourceKinds.GITCODE_BRANCH ||
            call.kind == SourceKinds.GITCODE_TREE ||
            call.kind == SourceKinds.GITCODE_SOURCE) && call.path == path) {
            count += 1
        }
    }
    count
}

private func p6S3SourceEventTasks(): ArrayList<String> {
    let tasks = ArrayList<String>()
    tasks.add("cangjie_source_event_sync")
    tasks
}

private func p6S3RawPathCount(records: ArrayList<RawRecord>, path: String): Int64 {
    var count: Int64 = 0
    for (record in records) {
        if (record.metadata.path == path) { count += 1 }
    }
    count
}

private func p6S3RawPathRefCount(records: ArrayList<RawRecord>, path: String,
    ref: String): Int64 {
    var count: Int64 = 0
    for (record in records) {
        if (record.metadata.path == path && record.metadata.docVersion == ref) {
            count += 1
        }
    }
    count
}

private func p6S3RawRefContent(records: ArrayList<RawRecord>, path: String,
    ref: String): String {
    for (record in records) {
        if (record.metadata.path == path && record.metadata.docVersion == ref) {
            return record.content
        }
    }
    ""
}

private func p6S3NormalizedPathCount(records: ArrayList<NormalizedRecord>, path: String): Int64 {
    var count: Int64 = 0
    for (record in records) {
        if (record.metadata.path == path) { count += 1 }
    }
    count
}

private func p6S3NormalizedPathRefCount(records: ArrayList<NormalizedRecord>, path: String,
    ref: String): Int64 {
    var count: Int64 = 0
    for (record in records) {
        if (record.metadata.path == path && record.metadata.docVersion == ref) {
            count += 1
        }
    }
    count
}

private func p6S3RecordsContainChunk(records: ArrayList<NormalizedRecord>, text: String): Bool {
    for (record in records) {
        if (record.chunk.contains(text)) { return true }
    }
    false
}

private func p6S3RawSourceIdPresent(records: ArrayList<RawRecord>, sourceId: String): Bool {
    for (record in records) {
        if (record.sourceId == sourceId) { return true }
    }
    false
}

private func p6S3NormalizedSourceIdPresent(records: ArrayList<NormalizedRecord>,
    sourceId: String): Bool {
    for (record in records) {
        if (record.sourceId == sourceId) { return true }
    }
    false
}

private func p6S3RawControlRecordCount(records: ArrayList<RawRecord>): Int64 {
    var count: Int64 = 0
    for (record in records) {
        if (record.sourceId.startsWith("scheduled-cangjie_source_event_sync-")) {
            count += 1
        }
    }
    count
}

private func p6S3NormalizedControlRecordCount(records: ArrayList<NormalizedRecord>): Int64 {
    var count: Int64 = 0
    for (record in records) {
        if (record.sourceId.startsWith("scheduled-cangjie_source_event_sync-")) {
            count += 1
        }
    }
    count
}

private func p6S3VectorControlRecordCount(records: ArrayList<VectorRecord>): Int64 {
    var count: Int64 = 0
    for (record in records) {
        if (record.id.startsWith("scheduled-cangjie_source_event_sync-")) {
            count += 1
        }
    }
    count
}

private func p6S3HasRequestKind(calls: ArrayList<SourceFetchRequest>, kind: String): Bool {
    for (call in calls) {
        if (call.kind == kind) { return true }
    }
    false
}

private func p6S3RewriteSourceIdAsLegacy(store: FileKnowledgeStore, path: String,
    legacyId: String, ref!: String = ""): Bool {
    let snapshot = store.loadActiveSnapshot()
    if (!snapshot.valid) { return false }
    for (record in snapshot.rawRecords) {
        if (record.metadata.path == path && (ref == "" || record.metadata.docVersion == ref)) {
            record.sourceId = legacyId
            record.metadata.sourceId = legacyId
        }
    }
    for (record in snapshot.normalizedRecords) {
        if (record.metadata.path == path && (ref == "" || record.metadata.docVersion == ref)) {
            record.sourceId = legacyId
            record.metadata.sourceId = legacyId
        }
    }
    for (record in snapshot.activeIndex) {
        if (record.metadata.path == path && (ref == "" || record.metadata.docVersion == ref)) {
            record.sourceId = legacyId
            record.metadata.sourceId = legacyId
        }
    }
    let kb = KnowledgeBase(FakeClock(0))
    if (!kb.restoreActiveSnapshot(snapshot)) { return false }
    let status = kb.status()
    store.writeActiveSnapshotTransaction(status, snapshot.rawRecords,
        snapshot.normalizedRecords, snapshot.activeIndex, snapshot.vectorRecords,
        status.storage.vectorActiveCollection, kb.activeGraphBuild(), persistVectorFile: false).ok
}

private class P6S3PathResponseRunner <: SourceFetchRunner {
    private let mode: String
    private let content: String
    private let delegate = FakeSourceFetchRunner()
    public let calls: ArrayList<SourceFetchRequest> = ArrayList<SourceFetchRequest>()

    public init(mode: String, content: String) {
        this.mode = mode
        this.content = content
    }

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        let result = this.delegate.fetch(request)
        this.calls.add(request)
        if (request.kind != SourceKinds.GITCODE_SOURCE) {
            return result
        }
        if (this.mode == "double_404") {
            return this.failure(result, "not_found", 404)
        }
        if (this.mode == "raw_404_contents_5xx") {
            if (request.sourceVariant == "raw") {
                return this.failure(result, "not_found", 404)
            }
            return this.failure(result, "server_error", 500)
        }
        if (this.mode == "network") {
            return this.failure(result, "network_timeout", 0)
        }
        result.ok = true
        result.status = "ok"
        result.statusCode = 200
        result.body = "package event\npublic class ${this.content} {}\n"
        result.bodyHash = stableSummaryHash(result.body)
        result.bytes = result.body.size
        result.path = request.path
        result.repo = request.repo
        result.ref = request.ref
        result.contentType = "text/plain"
        result
    }

    private func failure(result: SourceFetchResult, status: String,
        statusCode: Int64): SourceFetchResult {
        result.ok = false
        result.status = status
        result.statusCode = statusCode
        result.body = status
        result.bodyHash = stableSummaryHash(status)
        result.bytes = result.body.size
        result
    }
}

private class P6S3TreeInventoryRunner <: SourceFetchRunner {
    private let mode: String
    private let delegate = FakeSourceFetchRunner()
    public let treePages: ArrayList<Int64> = ArrayList<Int64>()
    public var terminalPageReturned: Bool = false

    public init(mode: String) {
        this.mode = mode
    }

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        let result = this.delegate.fetch(request)
        if (request.kind != SourceKinds.GITCODE_TREE) {
            return result
        }
        this.treePages.add(request.page)
        if (this.mode == "missing_terminal") {
            result.body = p6S3TreeBody(request.page, 1, true)
        } else if (this.mode == "truncated") {
            result.body = if (request.page == 1) {
                p6S3TreeBody(request.page, 1, true)
            } else {
                this.terminalPageReturned = true
                "{\"tree\":[]}"
            }
            result.truncated = request.page == 1
        } else if (this.mode == "object_bound") {
            result.body = p6S3TreeBody(request.page, 2000, false)
        } else if (this.mode == "candidate_bound") {
            result.body = if (request.page == 1) {
                p6S3TreeBody(request.page, 257, true)
            } else {
                this.terminalPageReturned = true
                "{\"tree\":[]}"
            }
        } else {
            result.body = if (request.page == 1) {
                p6S3TreeBody(request.page, 1, true)
            } else {
                this.terminalPageReturned = true
                "{\"tree\":[]}"
            }
        }
        result.bytes = result.body.size
        result.bodyHash = stableSummaryHash(result.body)
        result
    }
}

private func p6S3TreeBody(page: Int64, count: Int64, candidate: Bool): String {
    var body = "{\"tree\":["
    for (index in 0..count) {
        if (index > 0) { body += "," }
        let suffix = if (candidate) { ".cj" } else { ".txt" }
        body += "{\"path\":\"src/p${page}-item-${index}${suffix}\",\"type\":\"blob\"}"
    }
    body + "]}"
}

private class P6S3TransientContentRunner <: SourceFetchRunner {
    private let delegate = FakeSourceFetchRunner()
    public init() {}
    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        let result = this.delegate.fetch(request)
        if (request.kind == SourceKinds.GITCODE_SOURCE) {
            result.ok = false
            result.status = "server_error"
            result.statusCode = 500
        }
        result
    }
}
