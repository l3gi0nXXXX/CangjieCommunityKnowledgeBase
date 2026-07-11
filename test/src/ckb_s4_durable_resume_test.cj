package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashSet}
import std.convert.Parsable
import std.env.getVariable
import std.fs.{Directory, File, Path, exists}
import std.io.*
import std.process.*
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

private let S4_COMMIT: String = "0123456789abcdef0123456789abcdef01234567"

@Test
public class CkbS4DurableResumeTest {
    @TestCase
    public func p5S4U01DurableArtifactsIdentityStateStableIdsAndBoundedQdrantLookup(): Unit {
        let root = "target/p5-s4-u01"
        s4EnsureEmptyDir(root)
        let store = FileKnowledgeStore("${root}/store")
        let profile = ckbSyncProfileForScheduleTask("cangjie_release_full_sync")
        let source = s4ReleaseSource()
        let planningKey = ckbReleaseScheduledFetchRunKey(profile, source, "p5-plan-s4-u01")
        let runKey = ckbReleaseRunKeyWithCommit(planningKey, S4_COMMIT)

        let ref = ckbWriteReleaseContentArtifact(store, runKey, CkbReleaseArtifactKinds.REF,
            "{\"commit\":\"${S4_COMMIT}\"}", method: "gitcode_ref", contentType: "application/json")
        let page = ckbWriteReleaseContentArtifact(store, runKey, CkbReleaseArtifactKinds.TREE_PAGE,
            "[{\"path\":\"docs/仓颉🙂.md\",\"type\":\"blob\"}]", ordinal: 1,
            method: "gitcode_tree", contentType: "application/json")
        let content = ckbWriteReleaseContentArtifact(store, runKey, CkbReleaseArtifactKinds.CONTENT,
            "# 仓颉🙂\n正文", logicalPath: "docs/仓颉🙂.md", method: "gitcode_source", contentType: "text/markdown")
        let complete = ckbWriteReleaseContentArtifact(store, runKey, CkbReleaseArtifactKinds.SOURCE_COMPLETE,
            "{\"complete\":true}", method: "source_complete", contentType: "application/json")
        let checkpoint = CkbReleaseResumeCheckpoint()
        checkpoint.phase = "completed"
        checkpoint.sourceOrdinal = 2
        checkpoint.nextPage = 2
        checkpoint.refArtifactPath = ref.relativePath
        checkpoint.sourceCompleteArtifactPath = complete.relativePath
        checkpoint.plannedPaths.add("docs/仓颉🙂.md")
        checkpoint.completedPaths.add("docs/仓颉🙂.md")
        checkpoint.pageArtifactPaths.add(page.relativePath)
        checkpoint.contentArtifactPaths.add(content.relativePath)
        checkpoint.artifactEvidenceHashes.add(ref.evidenceHash)
        checkpoint.artifactEvidenceHashes.add(page.evidenceHash)
        checkpoint.artifactEvidenceHashes.add(content.evidenceHash)
        checkpoint.artifactEvidenceHashes.add(complete.evidenceHash)
        ckbSaveReleaseResumeCheckpoint(store, runKey, checkpoint)
        ckbMarkReleaseAcquisitionState(store, runKey, "active", candidateVersion: "candidate-s4")

        let loadedCheckpoint = ckbLoadReleaseResumeCheckpoint(store, runKey)
        let loadedRef = ckbLoadReleaseContentArtifact(store, runKey, CkbReleaseArtifactKinds.REF)
        let loadedPage = ckbLoadReleaseContentArtifact(store, runKey, CkbReleaseArtifactKinds.TREE_PAGE, ordinal: 1)
        let loadedContent = ckbLoadReleaseContentArtifact(store, runKey, CkbReleaseArtifactKinds.CONTENT, logicalPath: "docs/仓颉🙂.md")
        let loadedState = ckbLoadReleaseAcquisitionState(store, runKey)
        @Expect(loadedCheckpoint.valid, true)
        @Expect(loadedCheckpoint.phase, "completed")
        @Expect(loadedCheckpoint.completedPaths.size, 1)
        @Expect(loadedRef.payload, ref.payload)
        @Expect(loadedPage.payload, page.payload)
        @Expect(loadedContent.payload, content.payload)
        @Expect(loadedContent.evidenceHash, content.evidenceHash)
        @Expect(loadedState.valid, true)
        @Expect(ckbReleaseAcquisitionCanResume(store, runKey), true)

        let wrongCommit = ckbReleaseRunKeyWithCommit(planningKey, "ffffffffffffffffffffffffffffffffffffffff")
        @Expect(ckbLoadReleaseContentArtifact(store, wrongCommit, CkbReleaseArtifactKinds.CONTENT,
            logicalPath: "docs/仓颉🙂.md").status, "artifact_identity_mismatch")
        let wrongSelector = ckbReleaseRunKeyWithCommit(planningKey, S4_COMMIT)
        wrongSelector.selectorVersion = "p5-release-selector-corrupt"
        @Expect(ckbLoadReleaseContentArtifact(store, wrongSelector, CkbReleaseArtifactKinds.CONTENT,
            logicalPath: "docs/仓颉🙂.md").status, "artifact_identity_mismatch")
        let wrongPlan = ckbReleaseRunKeyWithCommit(planningKey, S4_COMMIT)
        wrongPlan.planEvidenceHash = "p5-plan-s4-u01-corrupt"
        @Expect(ckbLoadReleaseContentArtifact(store, wrongPlan, CkbReleaseArtifactKinds.CONTENT,
            logicalPath: "docs/仓颉🙂.md").status, "artifact_identity_mismatch")

        let contentText = store.readText(content.relativePath)
        store.writeLinesAtomically(content.relativePath, contentText.replace("# 仓颉🙂\\n正文", "# 被篡改🙂"))
        let corruptContent = ckbLoadReleaseContentArtifact(store, runKey, CkbReleaseArtifactKinds.CONTENT,
            logicalPath: "docs/仓颉🙂.md")
        @Expect(corruptContent.valid, false)
        @Expect(corruptContent.status, "artifact_hash_mismatch")
        store.writeLinesAtomically(content.relativePath, "{malformed")
        @Expect(ckbLoadReleaseContentArtifact(store, runKey, CkbReleaseArtifactKinds.CONTENT,
            logicalPath: "docs/仓颉🙂.md").status, "malformed_json")
        File.writeTo(Path("${root}/store").join(content.relativePath), [UInt8(255), UInt8(254)])
        @Expect(ckbLoadReleaseContentArtifact(store, runKey, CkbReleaseArtifactKinds.CONTENT,
            logicalPath: "docs/仓颉🙂.md").status, "invalid_response_encoding")
        store.writeLinesAtomically(content.relativePath, contentText)

        let checkpointPath = "${ckbReleaseAcquisitionRoot(runKey)}/checkpoint.json"
        let checkpointText = store.readText(checkpointPath)
        store.writeLinesAtomically(checkpointPath, "{malformed")
        @Expect(ckbLoadReleaseResumeCheckpoint(store, runKey).status, "malformed_json")
        File.writeTo(Path("${root}/store").join(checkpointPath), [UInt8(255), UInt8(254)])
        @Expect(ckbLoadReleaseResumeCheckpoint(store, runKey).status, "invalid_response_encoding")
        store.writeLinesAtomically(checkpointPath, checkpointText.replace(loadedCheckpoint.evidenceHash, "corrupt-evidence"))
        @Expect(ckbLoadReleaseResumeCheckpoint(store, runKey).status, "checkpoint_hash_mismatch")
        store.writeLinesAtomically(checkpointPath, checkpointText)
        @Expect(ckbLoadReleaseResumeCheckpoint(store, runKey).valid, true)

        let statePath = "${ckbReleaseAcquisitionRoot(runKey)}/state.json"
        store.writeLinesAtomically(statePath, "{malformed")
        @Expect(ckbLoadReleaseAcquisitionState(store, runKey).status, "malformed_json")
        File.writeTo(Path("${root}/store").join(statePath), [UInt8(255), UInt8(254)])
        @Expect(ckbLoadReleaseAcquisitionState(store, runKey).status, "invalid_response_encoding")
        ckbMarkReleaseAcquisitionState(store, runKey, "consumed", activeVersion: "active-s4")
        @Expect(ckbLoadReleaseAcquisitionState(store, runKey).valid, true)
        @Expect(ckbReleaseAcquisitionCanResume(store, runKey), false)

        let stable = s4Normalized(7, changed: false)
        let same = s4Normalized(7, changed: false)
        let changed = s4Normalized(7, changed: true)
        @Expect(ckbVectorPointId(stable), ckbVectorPointId(same))
        @Expect(ckbVectorPointId(stable) == ckbVectorPointId(changed), false)
        @Expect(ckbVectorPointId(stable).contains("#sha256:"), true)

        // Length-prefixed identity fields must not inherit the old newline
        // delimiter collision between title and chunk.
        let collisionA = s4Normalized(70, changed: false)
        collisionA.title = "a\nb"
        collisionA.chunk = "c"
        let collisionB = s4Normalized(70, changed: false)
        collisionB.title = "a"
        collisionB.chunk = "b\nc"
        @Expect(ckbLegacyVectorPointId(collisionA, 0), ckbLegacyVectorPointId(collisionB, 0))
        @Expect(ckbVectorPointId(collisionA) == ckbVectorPointId(collisionB), false)

        // A separately launched unittest process must derive the same ID for
        // Chinese/emoji input; process-local hash seeding is not permitted.
        let pointIdRoot = "${root}/point-id-child"
        s4EnsureEmptyDir(pointIdRoot)
        let pointIdChild = launch("/bin/zsh", ["-c", s4ChildCommand(pointIdRoot, "point_id")],
            stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
        @Expect(pointIdChild.wait(), 0)
        @Expect(s4ReadText(Path(pointIdRoot).join("point-id.txt")), ckbVectorPointId(stable))

        let qdrantRecord = s4Vector(stable)
        let executor = S4QdrantExecutor(s4QdrantRetrieveBody(qdrantRecord))
        let qdrant = QdrantVectorStore("http://qdrant.fixture", 3, "Cosine", executor: executor)
        let pointIds = ArrayList<String>()
        pointIds.add(ckbVectorPointId(stable))
        let lookup = qdrant.lookupBatchWithDeadline("ckb_active", pointIds, ckbCoreNowMillis() + 60000)
        @Expect(lookup.ok, true)
        @Expect(lookup.found, 1)
        @Expect(executor.calls, 1)
        @Expect(executor.methods[0], "POST")
        @Expect(executor.urls[0].endsWith("/collections/ckb_active/points"), true)
        @Expect(executor.urls[0].contains("scroll"), false)
        @Expect(executor.bodies[0].contains("\"ids\""), true)

        let legacyRecord = s4Vector(stable)
        legacyRecord.pointId = ckbLegacyVectorPointId(stable, 7)
        let legacyExecutor = S4QdrantExecutor("{\"status\":\"ok\",\"result\":[${s4QdrantPointJson(legacyRecord)}]}")
        let legacyQdrant = QdrantVectorStore("http://qdrant.legacy.fixture", 3, "Cosine",
            executor: legacyExecutor)
        let dualIds = ArrayList<String>()
        dualIds.add(ckbVectorPointId(stable))
        dualIds.add(ckbLegacyVectorPointId(stable, 7))
        let legacyLookup = legacyQdrant.lookupBatchWithDeadline("ckb_active", dualIds,
            ckbCoreNowMillis() + 60000)
        @Expect(legacyLookup.ok, true)
        @Expect(legacyLookup.found, 1)
        @Expect(ckbVectorPointId(stable), ckbVectorPointId(s4Normalized(7, changed: false)))

        let logStore = FileKnowledgeStore("${root}/logs")
        let logSink = FileVectorBuildProgressSink(logStore, schedulerRunId: "s4-run", schedulerTaskName: "cangjie_release_full_sync")
        let progress = VectorBuildProgress()
        progress.runId = "s4-vector-run"
        progress.collection = "ckb_candidate_stage_仓颉🙂"
        progress.targetCollection = progress.collection
        progress.currentBatch = 3
        progress.lookupRequested = 128
        progress.lookupFound = 127
        progress.lookupStatus = "ok"
        progress.lookupDurationMillis = 9
        progress.lookupTimedOut = false
        progress.diagnostic = "完成🙂 Authorization: Bearer fixture-secret /Users/private/ckb.conf"
        logSink.onVectorBatchFinished(progress)
        let progressLog = logStore.readText(logSink.currentProgressPath())
        @Expect(progressLog.contains("\"runId\":\"s4-vector-run\""), true)
        @Expect(progressLog.contains("\"taskName\":\"cangjie_release_full_sync\""), true)
        @Expect(progressLog.contains("\"stage\":\"batch_finished\""), true)
        @Expect(progressLog.contains("\"currentBatch\":3"), true)
        @Expect(progressLog.contains("\"lookupRequested\":128"), true)
        @Expect(progressLog.contains("\"lookupFound\":127"), true)
        @Expect(progressLog.contains("fixture-secret"), false)
        @Expect(progressLog.contains("/Users/private"), false)

        let missingRunContext = s4Context("p5-candidate-missing-run", "candidate-missing-run")
        missingRunContext.schedulerRunId = ""
        let missingRunBackend = S4TrackingVectorStore()
        let missingRun = KnowledgeBase(FakeClock(0), S4EmbeddingProvider(1), missingRunBackend,
            LocalGraphStore()).buildVectorIndexForRecordsDurable(s4NormalizedRecords(1, 0),
            "ckb_candidate_missing_run", FileKnowledgeStore("${root}/missing-run"), missingRunContext)
        @Expect(missingRun.ok, false)
        @Expect(missingRun.status, "candidate_acquisition_context_invalid")
        @Expect(missingRunBackend.recreateCalls, 0)

        // Ordered spool arrays are sequences, not sets: adjacent full batches
        // legitimately repeat the same record count and must round-trip.
        let orderedStore = FileKnowledgeStore("${root}/ordered-spool")
        let orderedContext = s4Context("p5-candidate-ordered-spool", "candidate-ordered-spool")
        let orderedCollection = s4StableCollection(orderedContext)
        let ordered = CkbVectorSpoolDescriptor()
        ordered.acquisitionId = orderedContext.acquisitionId
        ordered.candidateVersion = orderedContext.candidateVersion
        ordered.planHash = orderedContext.planHash
        ordered.recordsEvidenceHash = orderedContext.recordsEvidenceHash
        ordered.collection = orderedCollection
        ordered.status = "completed"
        ordered.total = 256
        ordered.completed = 256
        ordered.reused = 256
        ordered.batchSize = 128
        ordered.batchRelativePaths.add("metadata/vector-builds/${orderedContext.acquisitionId}/batches/batch-0.ckb")
        ordered.batchRelativePaths.add("metadata/vector-builds/${orderedContext.acquisitionId}/batches/batch-1.ckb")
        ordered.batchEvidenceHashes.add("hash-0")
        ordered.batchEvidenceHashes.add("hash-1")
        ordered.batchRecordCounts.add("128")
        ordered.batchRecordCounts.add("128")
        orderedStore.saveVectorSpoolCheckpoint(ordered, completed: true)
        let orderedLoaded = orderedStore.loadVectorSpoolCheckpoint(orderedContext, orderedCollection)
        @Expect(orderedLoaded.valid, true)
        @Expect(orderedLoaded.batchRecordCounts.size, 2)
        @Expect(orderedLoaded.batchRecordCounts[0], "128")
        @Expect(orderedLoaded.batchRecordCounts[1], "128")

        s4AssertRemoteCompletedHydrateExact()
    }

    @TestCase
    public func p5S4B01CursorBoundariesRedoOnlyUncommittedCandidateAndVectorUnits(): Unit {
        let boundaryCounts: Array<Int64> = [0, 1, CkbCandidateDurableSchema.VECTOR_BATCH_SIZE,
            CkbCandidateDurableSchema.VECTOR_BATCH_SIZE + 1]
        for (count in boundaryCounts) {
            let root = "target/p5-s4-b01-vector-${count}"
            s4EnsureEmptyDir(root)
            let records = s4NormalizedRecords(count, 0)
            let provider = S4EmbeddingProvider(64)
            let vectorStore = LocalVectorStore()
            let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
            let store = FileKnowledgeStore(root)
            let context = s4Context("p5-candidate-b01-${count}", "candidate-b01-${count}", records: records)
            let result = kb.buildVectorIndexForRecordsDurable(records, "ckb_candidate_b01_${count}", store, context)
            @Expect(result.ok, true)
            @Expect(result.vectorCount, count)
            @Expect(result.spool.completed, count)
            @Expect(result.spool.failed, 0)
            @Expect(result.spool.batchRelativePaths.size,
                if (count == 0) { 0 } else if (count <= CkbCandidateDurableSchema.VECTOR_BATCH_SIZE) { 1 } else { 2 })
            @Expect(result.peakBufferedRecords <= CkbCandidateDurableSchema.VECTOR_LOOKUP_BATCH_SIZE, true)
        }

        let candidateBoundaryCounts: Array<Int64> = [0, 1, 256, 257]
        for (count in candidateBoundaryCounts) {
            let root = "target/p5-s4-b01-candidate-${count}"
            s4EnsureEmptyDir(root)
            let records = s4NormalizedRecords(count, 0)
            let materialized = FileKnowledgeStore(root).saveCandidateSnapshotImmutable(
                s4RawRecords(records), records, "candidate-boundary-${count}")
            @Expect(materialized.ok, true)
            @Expect(materialized.rawCount, count)
            @Expect(materialized.normalizedCount, count)
            @Expect(materialized.batchCount, if (count == 0) { 0 } else if (count <= 256) { 1 } else { 2 })
            @Expect(materialized.writtenBatchCount, materialized.batchCount)
            @Expect(materialized.reusedBatchCount, 0)
        }

        let resumeRoot = "target/p5-s4-b01-vector-resume"
        s4EnsureEmptyDir(resumeRoot)
        let resumeStore = FileKnowledgeStore(resumeRoot)
        let resumeRecords = s4NormalizedRecords(CkbCandidateDurableSchema.VECTOR_BATCH_SIZE + 1, 0)
        let firstProvider = S4EmbeddingProvider(64)
        let tracking = S4TrackingVectorStore()
        tracking.failUpsertAt = 2
        let firstKb = KnowledgeBase(FakeClock(0), firstProvider, tracking, LocalGraphStore())
        let resumeContext = s4Context("p5-candidate-b01-resume", "candidate-b01-resume", records: resumeRecords)
        let first = firstKb.buildVectorIndexForRecordsDurable(resumeRecords, "ckb_candidate_b01_resume", resumeStore, resumeContext)
        @Expect(first.ok, false)
        @Expect(first.diagnostic, "s4_injected_vector_batch_failure")
        @Expect(first.spool.completed, CkbCandidateDurableSchema.VECTOR_BATCH_SIZE)
        @Expect(first.spool.batchRelativePaths.size, 1)
        @Expect(resumeStore.has("metadata/vector-builds/${resumeContext.acquisitionId}/batches/batch-1.ckb"), false)

        // A data file without a committed cursor is never adopted.
        resumeStore.writeLinesAtomically("metadata/vector-builds/${resumeContext.acquisitionId}/batches/batch-1.ckb", "uncommitted-garbage")
        tracking.failUpsertAt = -1
        let upsertsBeforeResume = tracking.upsertBatchCalls
        let secondProvider = S4EmbeddingProvider(64)
        let secondKb = KnowledgeBase(FakeClock(0), secondProvider, tracking, LocalGraphStore())
        let resumed = secondKb.buildVectorIndexForRecordsDurable(resumeRecords, "ckb_candidate_b01_resume", resumeStore, resumeContext)
        @Expect(resumed.ok, true)
        @Expect(resumed.vectorCount, CkbCandidateDurableSchema.VECTOR_BATCH_SIZE + 1)
        @Expect(secondProvider.embeddedItems, 1)
        @Expect(tracking.upsertBatchCalls - upsertsBeforeResume, 1)
        @Expect(resumed.spool.reused + resumed.spool.embedded, resumed.spool.total)
        @Expect(resumed.spool.failed, 0)
        @Expect(resumeStore.loadVectorSpoolBatch(resumed.spool.batchRelativePaths[1],
            resumed.spool.batchEvidenceHashes[1]).valid, true)

        let candidateRoot = "target/p5-s4-b01-candidate-resume"
        s4EnsureEmptyDir(candidateRoot)
        let candidateStore = FileKnowledgeStore(candidateRoot)
        let candidateRecords = s4NormalizedRecords(300, 0)
        let candidateRaw = s4RawRecords(candidateRecords)
        let firstCandidate = candidateStore.saveCandidateSnapshotImmutable(candidateRaw, candidateRecords, "candidate-b01")
        @Expect(firstCandidate.ok, true)
        @Expect(firstCandidate.batchCount, 2)
        _ = launch("/bin/rm", ["-f", "${candidateRoot}/candidate-artifacts/candidate-b01/manifest.ckb"]).wait()
        candidateStore.writeLinesAtomically("candidate-artifacts/candidate-b01/batches/batch-1.ckb", "uncommitted-garbage")
        let cursorEvidence = ckbReleaseEvidenceHash("candidate-b01|batch_committed|1|2|${firstCandidate.manifestEvidenceHash}")
        candidateStore.writeLinesAtomically("candidate-artifacts/candidate-b01/checkpoint.ckb",
            "schemaVersion=${CkbCandidateDurableSchema.VERSION}\nversion=candidate-b01\nphase=batch_committed\ncompletedBatches=1\ntotalBatches=2\nmanifestEvidenceHash=${firstCandidate.manifestEvidenceHash}\nupdatedAtMillis=1\nevidenceHash=${cursorEvidence}\n")
        let resumedCandidate = candidateStore.saveCandidateSnapshotImmutable(candidateRaw, candidateRecords, "candidate-b01")
        @Expect(resumedCandidate.ok, true)
        @Expect(resumedCandidate.batchCount, 2)
        @Expect(resumedCandidate.reusedBatchCount, 1)
        @Expect(resumedCandidate.writtenBatchCount, 1)
        @Expect(candidateStore.readText("candidate-artifacts/candidate-b01/batches/batch-1.ckb").contains("uncommitted-garbage"), false)
        @Expect(candidateStore.readText("candidate-artifacts/candidate-b01/checkpoint.ckb").contains("phase=completed"), true)

        let bytesRoot = "target/p5-s4-b01-vector-bytes"
        s4EnsureEmptyDir(bytesRoot)
        let atLimit = s4VectorByteBoundaryRecord(CkbCandidateDurableSchema.VECTOR_MAX_BUFFER_BYTES, "candidate-bytes-max")
        @Expect(s4EstimatedVectorBufferedBytes(atLimit), CkbCandidateDurableSchema.VECTOR_MAX_BUFFER_BYTES)
        let limitRecords = ArrayList<NormalizedRecord>()
        limitRecords.add(atLimit)
        let limitStore = FileKnowledgeStore(bytesRoot)
        let limitResult = KnowledgeBase(FakeClock(0), S4EmbeddingProvider(1), LocalVectorStore(), LocalGraphStore()).buildVectorIndexForRecordsDurable(
            limitRecords, "ckb_candidate_bytes_max", limitStore, s4Context("p5-candidate-bytes-max", "candidate-bytes-max", records: limitRecords))
        @Expect(limitResult.ok, true)
        @Expect(limitResult.peakBufferedBytes, CkbCandidateDurableSchema.VECTOR_MAX_BUFFER_BYTES)
        let loadedLimit = limitStore.loadVectorSpoolBatch(limitResult.spool.batchRelativePaths[0], limitResult.spool.batchEvidenceHashes[0])
        @Expect(loadedLimit.valid, true)
        @Expect(loadedLimit.records.size, 1)
        @Expect(loadedLimit.records[0].metadata.sourceUrl, atLimit.metadata.sourceUrl)
        @Expect(loadedLimit.records[0].metadata.repo, atLimit.metadata.repo)
        @Expect(loadedLimit.records[0].metadata.path, atLimit.metadata.path)
        @Expect(loadedLimit.records[0].metadata.symbol, atLimit.metadata.symbol)
        @Expect(loadedLimit.records[0].metadata.commit, atLimit.metadata.commit)
        @Expect(loadedLimit.records[0].metadata.docVersion, atLimit.metadata.docVersion)
        @Expect(loadedLimit.records[0].metadata.targetVersion, atLimit.metadata.targetVersion)
        @Expect(loadedLimit.records[0].metadata.sourceSet, atLimit.metadata.sourceSet)
        @Expect(loadedLimit.records[0].metadata.versionResolutionId, atLimit.metadata.versionResolutionId)
        @Expect(loadedLimit.records[0].metadata.trustLevel, atLimit.metadata.trustLevel)
        @Expect(loadedLimit.records[0].metadata.reviewState, atLimit.metadata.reviewState)
        @Expect(loadedLimit.records[0].metadata.derivedFrom.size, atLimit.metadata.derivedFrom.size)
        for (index in 0..atLimit.metadata.derivedFrom.size) { @Expect(loadedLimit.records[0].metadata.derivedFrom[index], atLimit.metadata.derivedFrom[index]) }
        let validBatchText = limitStore.readText(limitResult.spool.batchRelativePaths[0])
        let nonHexPath = "metadata/vector-builds/${limitResult.spool.acquisitionId}/batches/batch-90.ckb"
        let nonHexText = validBatchText[0..validBatchText.size - 2] + "gg\n"
        limitStore.writeLinesAtomically(nonHexPath, nonHexText)
        @Expect(limitStore.loadVectorSpoolBatch(nonHexPath, ckbReleaseEvidenceHash(nonHexText)).status, "vector_spool_schema_mismatch")
        let oddPath = "metadata/vector-builds/${limitResult.spool.acquisitionId}/batches/batch-91.ckb"
        let oddText = validBatchText[0..validBatchText.size - 2] + "\n"
        limitStore.writeLinesAtomically(oddPath, oddText)
        @Expect(limitStore.loadVectorSpoolBatch(oddPath, ckbReleaseEvidenceHash(oddText)).status, "vector_spool_schema_mismatch")
        let invalidUtf8Path = Path(bytesRoot).join("metadata/vector-builds/${limitResult.spool.acquisitionId}/batches/batch-92.ckb")
        File.writeTo(invalidUtf8Path, [UInt8(255), UInt8(254)])
        @Expect(limitStore.loadVectorSpoolBatch("metadata/vector-builds/${limitResult.spool.acquisitionId}/batches/batch-92.ckb", "expected").status, "invalid_response_encoding")
        let overLimit = s4VectorByteBoundaryRecord(CkbCandidateDurableSchema.VECTOR_MAX_BUFFER_BYTES + 1, "candidate-bytes-over")
        @Expect(s4EstimatedVectorBufferedBytes(overLimit), CkbCandidateDurableSchema.VECTOR_MAX_BUFFER_BYTES + 1)
        let overRecords = ArrayList<NormalizedRecord>()
        overRecords.add(overLimit)
        let overResult = KnowledgeBase(FakeClock(0), S4EmbeddingProvider(1), LocalVectorStore(), LocalGraphStore()).buildVectorIndexForRecordsDurable(
            overRecords, "ckb_candidate_bytes_over", FileKnowledgeStore("${bytesRoot}-over"), s4Context("p5-candidate-bytes-over", "candidate-bytes-over", records: overRecords))
        @Expect(overResult.ok, false)
        @Expect(overResult.diagnostic.startsWith("vector_record_oversized:"), true)

        s4AssertEvalSourceCompleteCrashWindowResumesWithoutReads()
        s4AssertRemoteSourceCompleteCrashWindowResumesWithoutRequests()
        s4AssertReleaseCursorCrashMatrix()
        s4AssertCandidateCursorCrashMatrix()
        s4AssertVectorCursorCrashMatrix()
    }

    @TestCase
    public func p5S4P01Streams9299CandidateWith9025ReuseAnd274Embeddings(): Unit {
        let root = "target/p5-s4-p01"
        if (getVariable("CKB_P5_S4_SCALE_CHILD") != Some("1")) {
            s4EnsureEmptyDir(root)
            var dyldLibraryPath = ""
            if (let Some(value) <- getVariable("DYLD_LIBRARY_PATH")) { dyldLibraryPath = value }
            let heap = ckbSchedulerDefaultCjHeapSizeForTask("cangjie_release_full_sync", "")
            @Expect(heap, "4GB")
            let prelude = ckbSchedulerWorkerShellPreludeWithHeap(dyldLibraryPath, heap)
            let pidPath = "target/p5-s4-p01-child.pid"
            _ = launch("/bin/rm", ["-f", pidPath]).wait()
            let command = "${prelude}export CKB_P5_S4_SCALE_CHILD=1; " +
                "target/release/unittest_bin/cangjie_community_knowledge_base_test --filter='*CkbS4DurableResumeTest.p5S4P01Streams9299CandidateWith9025ReuseAnd274Embeddings' --no-color --no-progress & " +
                "worker_pid=$!; echo $worker_pid > ${pidPath}; " +
                "(sleep 180; kill -9 $worker_pid 2>/dev/null; kill -9 $$ 2>/dev/null) & watchdog_pid=$!; " +
                "wait $worker_pid; child_code=$?; kill $watchdog_pid 2>/dev/null; wait $watchdog_pid 2>/dev/null; exit $child_code"
            let child = launch("/bin/zsh", ["-c", command], stdOut: ProcessRedirect.Pipe,
                stdErr: ProcessRedirect.Pipe)
            var childCode: Int64 = -1
            var childPid: Int64 = 0
            var waited = false
            try {
                childCode = child.wait()
                waited = true
                childPid = s4ReadInt(Path(pidPath))
            } finally {
                if (childPid == 0) { childPid = s4ReadInt(Path(pidPath)) }
                if (childPid > 0 && s4PidAlive(childPid)) {
                    _ = launch("/bin/kill", ["-9", "${childPid}"]).wait()
                }
                if (!waited) {
                    try { childCode = child.wait() } catch (_: Exception) { childCode = -1 }
                }
            }
            let childStdout = s4SafeReadPipe(child.stdOutPipe)
            let childStderr = s4SafeReadPipe(child.stdErrPipe)
            let resultText = FileKnowledgeStore(root).readText("p5-scale-result.ckb")
            let resultEvidence = s4TextField(resultText, "evidenceHash")
            let resultPayload = resultText.replace("evidenceHash=${resultEvidence}\n", "")
            @Expect(childCode, 0)
            @Expect(childPid > 0, true)
            @Expect(s4PidAlive(childPid), false)
            @Expect(childStdout.contains("OutOfMemory"), false)
            @Expect(childStdout.contains("Out of memory"), false)
            @Expect(childStdout.contains("[ FAILED ]"), false)
            @Expect(childStdout.contains("FAILED"), false)
            @Expect(childStderr.contains("OutOfMemory"), false)
            @Expect(childStderr.contains("Out of memory"), false)
            @Expect(childStderr.contains("[ FAILED ]"), false)
            @Expect(childStderr.contains("FAILED"), false)
            @Expect(childStdout.contains("Authorization"), false)
            @Expect(childStdout.contains("/Users/"), false)
            @Expect(childStderr.contains("Authorization"), false)
            @Expect(childStderr.contains("/Users/"), false)
            @Expect(s4TextField(resultText, "schemaVersion"), "p5-s4-scale-v1")
            @Expect(s4TextField(resultText, "runId"), "p5-s4-p01-child")
            @Expect(s4TextField(resultText, "cjHeapSize"), "4GB")
            @Expect(resultEvidence, ckbReleaseEvidenceHash(resultPayload))
            @Expect(s4IntField(resultText, "records"), 9299)
            @Expect(s4IntField(resultText, "reused"), 9025)
            @Expect(s4IntField(resultText, "embedded"), 274)
            @Expect(s4IntField(resultText, "firstProviderEmbedded"), 274)
            @Expect(s4IntField(resultText, "promotionProviderEmbedded"), 0)
            @Expect(s4IntField(resultText, "retrieveCalls"), 73)
            @Expect(s4IntField(resultText, "candidateUpserts"), 73)
            @Expect(s4IntField(resultText, "retrieveIds"), 18598)
            @Expect(s4IntField(resultText, "retrieveFound"), 9025)
            @Expect(s4TextField(resultText, "vectorRecordsMaterialized"), "false")
            @Expect(s4IntField(resultText, "vectorRecordsSize"), 0)
            @Expect(s4IntField(resultText, "overlayProcessed"), 18598)
            @Expect(s4IntField(resultText, "overlayPeakAuxiliary"), 9299)
            @Expect(s4IntField(resultText, "materializationBatches"), 37)
            @Expect(s4IntField(resultText, "materializationPeak") <= 256, true)
            @Expect(s4IntField(resultText, "vectorPeakRecords") <= CkbCandidateDurableSchema.VECTOR_LOOKUP_BATCH_SIZE, true)
            @Expect(s4IntField(resultText, "vectorPeakBytes") <= CkbCandidateDurableSchema.VECTOR_MAX_BUFFER_BYTES, true)
            @Expect(s4IntField(resultText, "graphNodes"), 27897)
            @Expect(s4IntField(resultText, "graphEdges"), 37195)
            @Expect(s4IntField(resultText, "servingCount"), s4IntField(resultText, "validationDocuments"))
            @Expect(s4IntField(resultText, "indexCount"), 9299)
            @Expect(s4IntField(resultText, "vectorCount"), 9299)
            @Expect(s4TextField(resultText, "activeVersion"), "candidate-s4-p01-active")
            for (field in ["snapshotValid", "reloadValid", "exactQuery", "hybridQuery", "graphQuery",
                "ownerCommitted", "checkpointGone", "manifestGone", "graphFiles", "tmpClean"]) {
                @Expect(s4TextField(resultText, field), "true")
            }
            @Expect(s4TextField(resultText, "queryKnowledgeVersion"), "candidate-s4-p01-active")
            _ = launch("/bin/rm", ["-f", pidPath]).wait()
            return
        }
        s4EnsureEmptyDir(root)
        let provider = S4EmbeddingProvider(64)
        let active = s4ScaleRecords(9299, 0)
        s4ApplyValidationCoverage(active)
        let executor = S4ScaleQdrantExecutor(9299, 9025)
        let vectorStore = QdrantVectorStore("http://qdrant.s4-scale", 3, "Cosine", executor: executor)
        let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
        let snapshot = ActiveSnapshot()
        snapshot.valid = true
        snapshot.activeVersion = "active-s4-p01"
        snapshot.activeStateSource = "persisted"
        snapshot.vectorActiveCollection = "active"
        snapshot.vectorCandidateCollection = "candidate"
        // Remote Qdrant is the active authority: the snapshot deliberately
        // carries no VectorRecord list, proving restore and reuse stay batched.
        snapshot.hasVectorArtifact = false
        let activeRaw = s4RawRecords(active)
        for (raw in activeRaw) { snapshot.rawRecords.add(raw) }
        for (record in active) {
            snapshot.normalizedRecords.add(record)
            snapshot.activeIndex.add(record)
        }
        @Expect(snapshot.vectorRecords.size, 0)
        @Expect(kb.restoreActiveSnapshot(snapshot), true)
        @Expect(kb.status().activeKnowledgeVersion, "active-s4-p01")
        @Expect(kb.activeRecordSnapshot()[9025].chunk, "a9025")
        snapshot.rawRecords.clear(); snapshot.normalizedRecords.clear(); snapshot.activeIndex.clear()
        activeRaw.clear(); active.clear()

        let candidate = s4ScaleRecords(9299, 9025)
        s4ApplyValidationCoverage(candidate)
        let candidateRaw = s4RawRecords(candidate)
        let overlay = kb.activeRecordSnapshotOverlay(candidate)
        let overlayStats = kb.overlayBuildStats()
        @Expect(overlay.size, 9299)
        @Expect(overlayStats.activeRecords, 9299)
        @Expect(overlayStats.deltaRecords, 9299)
        @Expect(overlayStats.processedRecords, 18598)
        @Expect(overlayStats.peakAuxiliaryRecords, 9299)
        overlay.clear()

        let store = FileKnowledgeStore(root)
        kb.replaceRawRecords(candidateRaw)
        let materialized = store.saveCandidateSnapshotImmutable(candidateRaw, candidate, "candidate-s4-p01")
        @Expect(materialized.ok, true)
        @Expect(materialized.rawCount, 9299)
        @Expect(materialized.normalizedCount, 9299)
        @Expect(materialized.batchCount, 37)
        @Expect(materialized.peakBufferedRecords <= 256, true)
        candidateRaw.clear()

        provider.reset()
        let context = s4Context("p5-candidate-s4-p01", "candidate-s4-p01", records: candidate)
        let collection = s4StableCollection(context)
        executor.candidateCollection = collection
        let result = kb.buildVectorIndexForRecordsDurable(candidate, collection, store, context)
        @Expect(result.ok, true)
        @Expect(result.vectorRecordsMaterialized, false)
        @Expect(result.vectorRecords.size, 0)
        @Expect(result.vectorCount, 9299)
        @Expect(result.reused, 9025)
        @Expect(result.embedded, 274)
        @Expect(provider.embeddedItems, 274)
        @Expect(result.spool.failed, 0)
        @Expect(result.spool.reused + result.spool.embedded, 9299)
        @Expect(result.peakBufferedRecords <= CkbCandidateDurableSchema.VECTOR_LOOKUP_BATCH_SIZE, true)
        @Expect(result.peakBufferedRecords >= CkbCandidateDurableSchema.VECTOR_LOOKUP_BATCH_SIZE, true)
        @Expect(result.peakBufferedBytes <= CkbCandidateDurableSchema.VECTOR_MAX_BUFFER_BYTES, true)
        @Expect(vectorStore.status(collection).count, 9299)
        @Expect(executor.retrieveCalls, 73)
        @Expect(executor.totalRetrieveIds, 18598)
        @Expect(executor.totalRetrieveFound, 9025)
        @Expect(executor.maxRetrieveIds, CkbCandidateDurableSchema.VECTOR_LOOKUP_BATCH_SIZE)
        @Expect(executor.identityMismatch, false)
        @Expect(executor.scrollCalls, 0)
        let firstProviderEmbedded = provider.embeddedItems
        store.streamVectorSpoolToFile("index/vector-candidate-s4-p01.ckb", result.spool, 0)
        @Expect(store.has("index/vector-candidate-s4-p01.ckb"), true)
        @Expect(store.has(result.spool.manifestRelativePath), true)

        let directCheckpoint = store.loadVectorSpoolCheckpoint(context, collection)
        @Expect(directCheckpoint.valid, true)
        @Expect(directCheckpoint.reused, 9025)
        @Expect(directCheckpoint.embedded, 274)
        provider.reset()

        let retrieveCallsBeforePromotion = executor.retrieveCalls
        let upsertsBeforePromotion = executor.candidateUpsertCalls
        let promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb, store,
            "candidate-s4-p01", candidate, acquisitionContext: context)
        @Expect(promotion.ok, true)
        @Expect(promotion.activePromoted, true)
        @Expect(promotion.validation.status, "candidate_validation_passed")
        @Expect(promotion.validation.coveragePass, true)
        @Expect(promotion.validation.taskPackCoveragePass, true)
        @Expect(promotion.validation.transportParityPass, true)
        @Expect(promotion.validation.performancePass, true)
        @Expect(promotion.validation.vectorHealthPass, true)
        @Expect(ckbValidationEvidenceIsSha256(promotion.validation.evidenceHash), true)
        @Expect(executor.retrieveCalls, retrieveCallsBeforePromotion)
        @Expect(executor.candidateUpsertCalls, upsertsBeforePromotion)
        @Expect(provider.embeddedItems, 0)
        @Expect(store.has("metadata/active-snapshot.manifest"), true)
        @Expect(store.has("metadata/vector-builds/${context.acquisitionId}/checkpoint.ckb"), false)
        @Expect(store.has("metadata/vector-builds/${context.acquisitionId}/manifest.ckb"), false)
        @Expect(store.loadCandidateCollectionOwner(collection).state, "committed_active")
        let promotedStatus = kb.status()
        @Expect(promotedStatus.storage.indexCount, 9299)
        @Expect(promotedStatus.storage.vectorIndexCount, 9299)
        @Expect(promotedStatus.storage.vectorActiveCollection, collection)
        @Expect(promotedStatus.storage.graphNodeCount, 27897)
        @Expect(promotedStatus.storage.graphEdgeCount, 37195)
        @Expect(promotedStatus.storage.servingIndexCount, promotion.validation.servingDocumentCount)
        @Expect(promotedStatus.storage.servingIndexVersion, promotion.validation.activeVersion)
        @Expect(promotedStatus.storage.servingIndexDiagnostic, promotion.validation.servingIndexDiagnostic)
        @Expect(store.has("index/graph-nodes.ckb"), true)
        @Expect(store.has("index/graph-edges.ckb"), true)

        let reloaded = KnowledgeBase(FakeClock(0), S4EmbeddingProvider(64), vectorStore, LocalGraphStore())
        let persisted = store.loadActiveSnapshot()
        @Expect(persisted.valid, true)
        @Expect(reloaded.restoreActiveSnapshot(persisted), true)
        let reloadedStatus = reloaded.status()
        @Expect(reloadedStatus.storage.indexCount, 9299)
        @Expect(reloadedStatus.storage.vectorIndexCount, 9299)
        @Expect(reloadedStatus.storage.vectorActiveCollection, collection)
        @Expect(reloadedStatus.storage.graphNodeCount, 27897)
        @Expect(reloadedStatus.storage.graphEdgeCount, 37195)
        @Expect(reloaded.activeRecordSnapshot()[9025].chunk, "b9025")
        @Expect(reloaded.rawRecordSnapshot()[9025].content, "b9025")
        @Expect(reloaded.rawRecordSnapshot().size, reloaded.activeRecordSnapshot().size)

        let servingIndex = buildCangjieServingIndex(reloaded.activeRecordSnapshot(),
            activeKnowledgeVersion: reloadedStatus.activeKnowledgeVersion)
        let exact = lookupExactSymbol(servingIndex, "ArrayList.add", sourceSet: CangjieSourceSets.STD,
            targetVersion: "1.0.0", versionResolutionId: "vr-std-s4", budget: 3)
        let hybridRequest = CangjieServingSearchRequest()
        hybridRequest.query = "b9025"
        hybridRequest.targetVersion = "1.0.0"
        hybridRequest.budget = 3
        let hybrid = searchHybridServingIndex(servingIndex, hybridRequest)
        @Expect(exact.ok, true); @Expect(exact.hits.size > 0, true)
        @Expect(hybrid.ok, true); @Expect(hybrid.hits.size > 0, true)
        @Expect(servingIndex.activeKnowledgeVersion, reloadedStatus.activeKnowledgeVersion)
        servingIndex.records.clear(); servingIndex.documents.clear(); servingIndex.exactEntries.clear()

        let graphQuery = GraphQuery()
        graphQuery.sourceId = "r9025"
        graphQuery.knowledgeVersion = reloadedStatus.activeKnowledgeVersion
        graphQuery.budget = 8
        let graphContext = reloaded.graphNeighbors(graphQuery)
        @Expect(graphContext.nodes.size > 0, true)
        @Expect(graphContext.edges.size > 0, true)
        @Expect(graphContext.knowledgeVersion, reloadedStatus.activeKnowledgeVersion)

        let actualHeap = if (let Some(value) <- getVariable("cjHeapSize")) { value } else { "" }
        @Expect(actualHeap, "4GB")
        var scalePayload = "schemaVersion=p5-s4-scale-v1\nrunId=p5-s4-p01-child\ncjHeapSize=${actualHeap}\n"
        scalePayload += "records=9299\nreused=${result.reused}\nembedded=${result.embedded}\n"
        scalePayload += "firstProviderEmbedded=${firstProviderEmbedded}\npromotionProviderEmbedded=${provider.embeddedItems}\n"
        scalePayload += "retrieveCalls=${executor.retrieveCalls}\ncandidateUpserts=${executor.candidateUpsertCalls}\nretrieveIds=${executor.totalRetrieveIds}\nretrieveFound=${executor.totalRetrieveFound}\n"
        scalePayload += "vectorRecordsMaterialized=${result.vectorRecordsMaterialized}\nvectorRecordsSize=${result.vectorRecords.size}\n"
        scalePayload += "overlayProcessed=${overlayStats.processedRecords}\noverlayPeakAuxiliary=${overlayStats.peakAuxiliaryRecords}\n"
        scalePayload += "materializationBatches=${materialized.batchCount}\nmaterializationPeak=${materialized.peakBufferedRecords}\n"
        scalePayload += "vectorPeakRecords=${result.peakBufferedRecords}\nvectorPeakBytes=${result.peakBufferedBytes}\n"
        scalePayload += "graphNodes=${promotedStatus.storage.graphNodeCount}\ngraphEdges=${promotedStatus.storage.graphEdgeCount}\n"
        scalePayload += "servingCount=${promotedStatus.storage.servingIndexCount}\nvalidationDocuments=${promotion.validation.servingDocumentCount}\n"
        scalePayload += "indexCount=${promotedStatus.storage.indexCount}\nvectorCount=${promotedStatus.storage.vectorIndexCount}\n"
        scalePayload += "activeVersion=${promotedStatus.activeKnowledgeVersion}\n"
        scalePayload += "snapshotValid=${persisted.valid}\nreloadValid=${reloadedStatus.storage.indexCount == 9299}\n"
        scalePayload += "exactQuery=${exact.ok && exact.hits.size > 0}\nhybridQuery=${hybrid.ok && hybrid.hits.size > 0}\n"
        scalePayload += "graphQuery=${graphContext.nodes.size > 0 && graphContext.edges.size > 0}\n"
        scalePayload += "queryKnowledgeVersion=${graphContext.knowledgeVersion}\n"
        scalePayload += "ownerCommitted=${store.loadCandidateCollectionOwner(collection).state == "committed_active"}\n"
        scalePayload += "checkpointGone=${!store.has("metadata/vector-builds/${context.acquisitionId}/checkpoint.ckb")}\n"
        scalePayload += "manifestGone=${!store.has("metadata/vector-builds/${context.acquisitionId}/manifest.ckb")}\n"
        scalePayload += "graphFiles=${store.has("index/graph-nodes.ckb") && store.has("index/graph-edges.ckb")}\n"
        scalePayload += "tmpClean=${s4CountTmpFiles(Path(root)) == 0}\n"
        store.writeLinesAtomically("p5-scale-result.ckb",
            scalePayload + "evidenceHash=${ckbReleaseEvidenceHash(scalePayload)}\n")
    }

    @TestCase
    public func p5S4N01WriteFailureHardKillCorruptSpoolAndOwnerRecoveryFailClosed(): Unit {
        let root = "target/p5-s4-n01"
        s4EnsureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let activeVectorStore = S4TrackingVectorStore()
        let activeKb = s4ActiveKnowledgeBase(activeVectorStore, "active-before-candidate-failure")
        let beforeActive = activeKb.status().activeKnowledgeVersion
        let beforeSourceId = activeKb.activeRecordSnapshot()[0].sourceId
        Directory.create(Path(root).join("raw/candidate"), recursive: true)
        File.writeTo(Path(root).join("raw/candidate/candidate-write-failure"), "blocking-file".toArray())
        let candidateFailureRecords = s4NormalizedRecords(4, 0)
        s4ApplyValidationCoverage(candidateFailureRecords)
        let materializationStages = S4StageCapture()
        let candidateFailure = cangjiePromoteCandidateRecordsAfterValidationWithVersion(activeKb, store,
            "candidate-write-failure", candidateFailureRecords, stageSink: materializationStages,
            acquisitionContext: s4Context("p5-candidate-write-failure", "candidate-write-failure", records: candidateFailureRecords))
        @Expect(candidateFailure.ok, false)
        @Expect(candidateFailure.candidateWritten, false)
        @Expect(candidateFailure.validation.status, "candidate_materialization_failed")
        @Expect(activeKb.status().activeKnowledgeVersion, beforeActive)
        @Expect(activeKb.activeRecordSnapshot()[0].sourceId, beforeSourceId)
        @Expect(materializationStages.contains("candidate_materialization_finished|candidate_materialization_failed"), true)
        @Expect(s4CountTmpFiles(Path(root)), 0)

        let vectorFailureRoot = "target/p5-s4-n01-vector-failure"
        s4EnsureEmptyDir(vectorFailureRoot)
        let vectorFailureStore = FileKnowledgeStore(vectorFailureRoot)
        let vectorFailureBackend = S4TrackingVectorStore()
        let vectorFailureKb = s4ActiveKnowledgeBase(vectorFailureBackend, "active-before-vector-failure")
        vectorFailureKb.persistActiveSnapshot(vectorFailureStore)
        let vectorFailureBefore = vectorFailureKb.status().activeKnowledgeVersion
        vectorFailureBackend.failUpsertAt = 1
        let vectorFailureStages = S4StageCapture()
        let vectorFailureContext = s4Context("p5-candidate-vector-failure", "candidate-vector-failure", records: candidateFailureRecords)
        let vectorFailure = cangjiePromoteCandidateRecordsAfterValidationWithVersion(vectorFailureKb,
            vectorFailureStore, "candidate-vector-failure", candidateFailureRecords,
            stageSink: vectorFailureStages, acquisitionContext: vectorFailureContext)
        @Expect(vectorFailure.ok, false)
        @Expect(vectorFailure.validation.status, "candidate_vector_failed")
        @Expect(vectorFailure.validation.vectorDegradedReason, "s4_injected_vector_batch_failure")
        @Expect(vectorFailureKb.status().activeKnowledgeVersion, vectorFailureBefore)
        @Expect(vectorFailureStages.contains("candidate_vector_finished|failed"), true)
        @Expect(vectorFailureStages.contains("candidate_validation_finished|candidate_vector_failed"), true)
        @Expect(vectorFailureBackend.wasDeleted(s4StableCollection(vectorFailureContext)), true)
        @Expect(s4CountTmpFiles(Path(vectorFailureRoot)), 0)

        let hardKillRoot = "target/p5-s4-n01-real-vector-hard-kill"
        s4EnsureEmptyDir(hardKillRoot)
        let hardKill = s4LaunchAndKillCrashFixture(hardKillRoot, "vector")
        @Expect(hardKill.ready, true)
        @Expect(hardKill.killed, true)
        @Expect(hardKill.orphanFree, true)
        let hardKillStore = FileKnowledgeStore("${hardKillRoot}/store")
        let hardKillRecords = s4NormalizedRecords(129, 0)
        s4ApplyValidationCoverage(hardKillRecords)
        let hardKillContext = s4Context("p5-candidate-vector-crash", "candidate-vector-crash", records: hardKillRecords)
        let hardKillCollection = s4StableCollection(hardKillContext)
        let interrupted = hardKillStore.loadVectorSpoolCheckpoint(hardKillContext, hardKillCollection)
        @Expect(interrupted.valid, true)
        @Expect(interrupted.completed, 128)
        let hardKillProvider = S4EmbeddingProvider(64)
        let hardKillBackend = LocalVectorStore()
        let hardKillResumed = KnowledgeBase(FakeClock(0), hardKillProvider, hardKillBackend,
            LocalGraphStore()).buildVectorIndexForRecordsDurable(hardKillRecords,
            hardKillCollection, hardKillStore, hardKillContext)
        @Expect(hardKillResumed.ok, true)
        @Expect(hardKillProvider.embeddedItems, 1)
        let hardKillRaw = s4RawRecords(hardKillRecords)
        let hardKillPromotionKb = s4KnowledgeBaseWithRecords(hardKillRecords, hardKillRaw,
            hardKillBackend, "old-active-hard-kill")
        hardKillPromotionKb.persistActiveSnapshot(hardKillStore)
        let hardKillPromotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(
            hardKillPromotionKb, hardKillStore, hardKillContext.candidateVersion, hardKillRecords,
            acquisitionContext: hardKillContext)
        @Expect(hardKillPromotion.ok, true)
        @Expect(hardKillPromotion.activePromoted, true)
        @Expect(hardKillStore.loadCandidateCollectionOwner(hardKillCollection).state, "committed_active")
        @Expect(hardKillStore.has("metadata/vector-builds/${hardKillContext.acquisitionId}/checkpoint.ckb"), false)
        @Expect(hardKillStore.has("metadata/vector-builds/${hardKillContext.acquisitionId}/manifest.ckb"), false)
        @Expect(hardKillPromotionKb.status().storage.vectorActiveCollection, hardKillCollection)
        @Expect(s4CountTmpFiles(Path(hardKillRoot)), 0)

        let rebuiltRecords = s4NormalizedRecords(1, 0)
        let corruptContext = s4Context("p5-candidate-corrupt-spool", "candidate-corrupt-spool", records: rebuiltRecords)
        let corruptDescriptor = CkbVectorSpoolDescriptor()
        corruptDescriptor.acquisitionId = corruptContext.acquisitionId
        corruptDescriptor.candidateVersion = corruptContext.candidateVersion
        corruptDescriptor.planHash = corruptContext.planHash
        corruptDescriptor.recordsEvidenceHash = corruptContext.recordsEvidenceHash
        corruptDescriptor.collection = "ckb_candidate_corrupt"
        corruptDescriptor.status = "running"
        corruptDescriptor.total = 1
        corruptDescriptor.completed = 1
        corruptDescriptor.embedded = 1
        corruptDescriptor.batchRelativePaths.add("metadata/vector-builds/${corruptContext.acquisitionId}/batches/../../escape.ckb")
        corruptDescriptor.batchEvidenceHashes.add("bad-hash")
        corruptDescriptor.batchRecordCounts.add("1")
        store.saveVectorSpoolCheckpoint(corruptDescriptor)
        let corrupt = store.loadVectorSpoolCheckpoint(corruptContext, corruptDescriptor.collection)
        @Expect(corrupt.valid, false)
        @Expect(corrupt.status, "vector_checkpoint_hash_mismatch")
        @Expect(store.loadVectorSpoolBatch("../../private.ckb", "hash").status, "vector_spool_path_invalid")
        let rebuiltBackend = S4TrackingVectorStore()
        let rebuilt = KnowledgeBase(FakeClock(0), S4EmbeddingProvider(1), rebuiltBackend,
            LocalGraphStore()).buildVectorIndexForRecordsDurable(rebuiltRecords,
            corruptDescriptor.collection, store, corruptContext)
        @Expect(rebuilt.ok, true)
        @Expect(rebuilt.vectorCount, 1)
        @Expect(rebuilt.spool.batchRelativePaths.size, 1)
        @Expect(store.loadVectorSpoolCheckpoint(corruptContext, corruptDescriptor.collection).valid, true)
        @Expect(s4CountTmpFiles(Path(root).join("metadata/vector-builds/${corruptContext.acquisitionId}")), 0)

        let conflictRoot = "target/p5-s4-n01-owner-conflict"
        s4EnsureEmptyDir(conflictRoot)
        let conflictStore = FileKnowledgeStore(conflictRoot)
        let conflictBackend = S4TrackingVectorStore()
        let conflictKb = s4ActiveKnowledgeBase(conflictBackend, "active-before-owner-conflict")
        let conflictContext = s4Context("p5-candidate-owner-conflict", "candidate-owner-conflict", records: candidateFailureRecords)
        let conflictCollection = s4StableCollection(conflictContext)
        let conflicting = s4Owner(conflictContext, conflictCollection, "planned")
        conflicting.taskId = "different-task"
        _ = conflictStore.saveCandidateCollectionOwner(conflicting)
        let recreateBeforeConflict = conflictBackend.recreateCalls
        let deleteBeforeConflict = conflictBackend.deleteCollectionCalls
        let conflictResult = cangjiePromoteCandidateRecordsAfterValidationWithVersion(conflictKb,
            conflictStore, conflictContext.candidateVersion, candidateFailureRecords,
            acquisitionContext: conflictContext)
        @Expect(conflictResult.ok, false)
        @Expect(conflictResult.validation.status, "candidate_staging_owner_conflict")
        @Expect(conflictBackend.recreateCalls, recreateBeforeConflict)
        @Expect(conflictBackend.deleteCollectionCalls, deleteBeforeConflict)
        @Expect(conflictKb.status().activeKnowledgeVersion, "active-before-owner-conflict")

        let alternateRoot = "target/p5-s4-n01-owner-alternate"
        s4EnsureEmptyDir(alternateRoot)
        let alternateStore = FileKnowledgeStore(alternateRoot)
        let alternateBackend = S4TrackingVectorStore()
        let alternateContext = s4Context("p5-candidate-owner-alternate", "candidate-owner-alternate", records: candidateFailureRecords)
        let stableCollection = s4StableCollection(alternateContext)
        let alternateCollection = ckbCandidateAlternateCollection(alternateContext)
        let alternateRaw = s4RawRecords(candidateFailureRecords)
        let alternateKb = s4KnowledgeBaseWithRecords(candidateFailureRecords, alternateRaw,
            alternateBackend, "active-before-alternate")
        let stableVectors = ArrayList<VectorRecord>()
        for (record in candidateFailureRecords) { stableVectors.add(s4Vector(record)) }
        _ = alternateBackend.recreate(stableCollection, stableVectors)
        alternateKb.promoteVectorActiveCollection(stableCollection)
        alternateKb.persistActiveSnapshot(alternateStore)
        let firstAlternate = cangjiePromoteCandidateRecordsAfterValidationWithVersion(alternateKb,
            alternateStore, alternateContext.candidateVersion, candidateFailureRecords,
            acquisitionContext: alternateContext)
        @Expect(firstAlternate.ok, true)
        @Expect(alternateKb.status().storage.vectorActiveCollection, alternateCollection)
        @Expect(alternateStore.loadCandidateCollectionOwner(alternateCollection).state, "committed_active")
        let secondStable = cangjiePromoteCandidateRecordsAfterValidationWithVersion(alternateKb,
            alternateStore, alternateContext.candidateVersion, candidateFailureRecords,
            acquisitionContext: alternateContext)
        @Expect(secondStable.ok, true)
        @Expect(alternateKb.status().storage.vectorActiveCollection, stableCollection)
        let alternateRecovery = ckbRecoverStaleSchedulerRunsWithVectorStore(alternateStore, alternateBackend)
        @Expect(alternateBackend.wasDeleted(alternateCollection), true)
        @Expect(alternateStore.loadCandidateCollectionOwner(alternateCollection).state, "cleaned")
        @Expect(s4Contains(alternateRecovery.diagnostics, "candidate_owner_orphan_deleted"), true)

        let tracking = S4TrackingVectorStore()
        let orphan = s4Context("p5-candidate-owner-orphan", "candidate-owner-orphan")
        let orphanCollection = s4StableCollection(orphan)
        _ = tracking.ensureReadyCollection(orphanCollection)
        _ = store.saveCandidateCollectionOwner(s4Owner(orphan, orphanCollection, "planned"))

        let oldCommitted = s4Context("p5-candidate-owner-old-active", "candidate-owner-old-active")
        let oldCommittedCollection = s4StableCollection(oldCommitted)
        _ = tracking.ensureReadyCollection(oldCommittedCollection)
        _ = store.saveCandidateCollectionOwner(s4Owner(oldCommitted, oldCommittedCollection, "committed_active"))

        let active = s4Context("p5-candidate-owner-active", "candidate-owner-active")
        let activeCollection = s4StableCollection(active)
        _ = tracking.ensureReadyCollection(activeCollection)
        _ = store.saveCandidateCollectionOwner(s4Owner(active, activeCollection, "committed_active"))

        let mismatch = s4Context("p5-candidate-owner-mismatch", "candidate-owner-mismatch")
        let mismatchCollection = "ckb_candidate_stage_prefix_only_must_preserve"
        _ = tracking.ensureReadyCollection(mismatchCollection)
        _ = store.saveCandidateCollectionOwner(s4Owner(mismatch, mismatchCollection, "planned"))

        let resumable = s4Context("p5-candidate-owner-resumable", "candidate-owner-resumable")
        let resumableCollection = s4StableCollection(resumable)
        _ = tracking.ensureReadyCollection(resumableCollection)
        _ = store.saveCandidateCollectionOwner(s4Owner(resumable, resumableCollection, "planned"))
        let resumableDescriptor = CkbVectorSpoolDescriptor()
        resumableDescriptor.acquisitionId = resumable.acquisitionId
        resumableDescriptor.candidateVersion = resumable.candidateVersion
        resumableDescriptor.planHash = resumable.planHash
        resumableDescriptor.recordsEvidenceHash = resumable.recordsEvidenceHash
        resumableDescriptor.collection = resumableCollection
        resumableDescriptor.status = "running"
        store.saveVectorSpoolCheckpoint(resumableDescriptor)

        let status = KnowledgeStatus()
        status.activeKnowledgeVersion = "active-s4"
        status.storage.vectorActiveCollection = activeCollection
        status.storage.vectorCollection = activeCollection
        store.saveMetadata(status)
        store.writeLinesAtomically("metadata/active-snapshot.manifest", "vectorActiveCollection=${activeCollection}\n")
        let ownerTmp = Path(root).join("metadata/candidate-collection-owners/.tmp-owner-registry-interrupted")
        File.writeTo(ownerTmp, "partial-owner".toArray())
        let recovery = ckbRecoverStaleSchedulerRunsWithVectorStore(store, tracking)
        @Expect(recovery.deletedKnownStaging, true)
        @Expect(tracking.wasDeleted(orphanCollection), true)
        @Expect(tracking.wasDeleted(oldCommittedCollection), true)
        @Expect(tracking.wasDeleted(activeCollection), false)
        @Expect(tracking.wasDeleted(mismatchCollection), false)
        @Expect(tracking.wasDeleted(resumableCollection), false)
        @Expect(s4Contains(recovery.diagnostics, "candidate_owner_preserved_active"), true)
        @Expect(s4Contains(recovery.diagnostics, "candidate_owner_preserved_mismatch"), true)
        @Expect(s4Contains(recovery.diagnostics, "candidate_owner_preserved_resumable"), true)
        @Expect(exists(ownerTmp), false)
        @Expect(s4Contains(recovery.diagnostics, "candidate_owner_stale_temps_removed:count=1"), true)
        @Expect(store.loadCandidateCollectionOwner(orphanCollection).state, "cleaned")
        @Expect(store.loadCandidateCollectionOwner(oldCommittedCollection).state, "cleaned")

        let unknownRoot = "target/p5-s4-n01-owner-unknown"
        s4EnsureEmptyDir(unknownRoot)
        let unknownStore = FileKnowledgeStore(unknownRoot)
        let unknownBackend = S4TrackingVectorStore()
        let unknown = s4Context("p5-candidate-owner-invalid-utf8", "candidate-owner-invalid-utf8")
        let unknownCollection = s4StableCollection(unknown)
        _ = unknownBackend.ensureReadyCollection(unknownCollection)
        let savedUnknown = unknownStore.saveCandidateCollectionOwner(s4Owner(unknown, unknownCollection, "planned"))
        File.writeTo(Path(unknownRoot).join(savedUnknown.relativePath), [UInt8(255), UInt8(254)])
        unknownStore.writeLinesAtomically("metadata/candidate-collection-owners/malformed-owner.ckb", "{malformed-owner")
        let unknownStatus = KnowledgeStatus()
        unknownStatus.storage.vectorActiveCollection = "active-authority"
        unknownStatus.storage.vectorCollection = "active-authority"
        unknownStore.saveMetadata(unknownStatus)
        unknownStore.writeLinesAtomically("metadata/active-snapshot.manifest", "vectorActiveCollection=active-authority\n")
        let unknownRecovery = ckbRecoverStaleSchedulerRunsWithVectorStore(unknownStore, unknownBackend)
        @Expect(unknownBackend.wasDeleted(unknownCollection), false)
        @Expect(s4Contains(unknownRecovery.diagnostics, "candidate_owner_preserved_unknown"), true)

        for (mode in ["missing", "empty", "malformed", "invalid_utf8", "mismatch"]) {
            let authorityRoot = "target/p5-s4-n01-active-authority-${mode}"
            s4EnsureEmptyDir(authorityRoot)
            let authorityStore = FileKnowledgeStore(authorityRoot)
            let authorityBackend = S4TrackingVectorStore()
            let authority = s4Context("p5-candidate-owner-authority-${mode}", "candidate-owner-authority-${mode}")
            let authorityCollection = s4StableCollection(authority)
            _ = authorityBackend.ensureReadyCollection(authorityCollection)
            _ = authorityStore.saveCandidateCollectionOwner(s4Owner(authority, authorityCollection, "committed_active"))
            if (mode == "empty") {
                authorityStore.writeLinesAtomically("metadata/status.ckb", "")
                authorityStore.writeLinesAtomically("metadata/active-snapshot.manifest", "")
            } else if (mode == "malformed") {
                authorityStore.writeLinesAtomically("metadata/status.ckb", "malformed=true\n")
                authorityStore.writeLinesAtomically("metadata/active-snapshot.manifest", "malformed=true\n")
            } else if (mode == "invalid_utf8") {
                authorityStore.writeLinesAtomically("metadata/status.ckb", "vectorActiveCollection=active-a\n")
                File.writeTo(Path(authorityRoot).join("metadata/active-snapshot.manifest"), [UInt8(255), UInt8(254)])
            } else if (mode == "mismatch") {
                authorityStore.writeLinesAtomically("metadata/status.ckb", "vectorActiveCollection=active-a\n")
                authorityStore.writeLinesAtomically("metadata/active-snapshot.manifest", "vectorActiveCollection=active-b\n")
            }
            let authorityRecovery = ckbRecoverStaleSchedulerRunsWithVectorStore(authorityStore, authorityBackend)
            @Expect(authorityBackend.wasDeleted(authorityCollection), false)
            @Expect(s4Contains(authorityRecovery.diagnostics, "candidate_owner_preserved_active_authority_unavailable"), true)
        }
    }

    @TestCase
    public func p5S4E2EAProcessCrashResumesPathCandidateVectorAndCleansOwner(): Unit {
        let root = "target/p5-s4-e2e-a"
        s4EnsureEmptyDir(root)
        for (phase in ["page", "path", "source"]) {
            let phaseRoot = "${root}/${phase}"
            s4EnsureEmptyDir(phaseRoot)
            let crash = s4LaunchAndKillCrashFixture(phaseRoot, phase)
            @Expect(crash.ready, true)
            @Expect(crash.pid > 0, true)
            @Expect(crash.killed, true)
            @Expect(crash.exitCode == 0, false)
            @Expect(crash.orphanFree, true)
            let resumed = s4ResumeRemoteCrash(phaseRoot)
            @Expect(resumed.result.ok, true)
            @Expect(resumed.inventory.complete, true)
            @Expect(resumed.inventory.completedPaths.size, 2)
            @Expect(resumed.runner.calls, if (phase == "page") { 3 } else if (phase == "path") { 1 } else { 0 })
            if (phase == "page") {
                @Expect(resumed.runner.requests.size, 3)
                @Expect(resumed.runner.requests[0], "${SourceKinds.GITCODE_TREE}:2:")
                @Expect(resumed.runner.requests[1], "${SourceKinds.GITCODE_SOURCE}:1:docs/a.md")
                @Expect(resumed.runner.requests[2], "${SourceKinds.GITCODE_SOURCE}:1:docs/b.md")
            } else if (phase == "path") {
                @Expect(resumed.runner.contentCalls, 1)
                @Expect(resumed.runner.paths[0], "docs/b.md")
                @Expect(resumed.runner.requests.size, 1)
                @Expect(resumed.runner.requests[0], "${SourceKinds.GITCODE_SOURCE}:1:docs/b.md")
            } else {
                @Expect(resumed.runner.requests.size, 0)
            }
            let baseline = s4FreshRemoteBaseline("${phaseRoot}-baseline")
            @Expect(s4FetchEvidence(resumed.result, resumed.inventory),
                s4FetchEvidence(baseline.result, baseline.inventory))
            let hydrated = s4ResumeRemoteCrash(phaseRoot)
            @Expect(hydrated.runner.calls, 0)
            @Expect(s4Contains(hydrated.result.diagnostics, "release_source_completed_hydrated"), true)
        }

        let candidateRoot = "${root}/candidate"
        s4EnsureEmptyDir(candidateRoot)
        let candidateCrash = s4LaunchAndKillCrashFixture(candidateRoot, "candidate")
        @Expect(candidateCrash.ready, true)
        @Expect(candidateCrash.killed, true)
        @Expect(candidateCrash.exitCode == 0, false)
        @Expect(candidateCrash.orphanFree, true)
        let candidateStore = FileKnowledgeStore("${candidateRoot}/store")
        let crashRecords = s4CandidateCrashRecords()
        let crashCheckpoint = candidateStore.readText("candidate-artifacts/candidate-crash/checkpoint.ckb")
        let committedCandidateBatches = s4IntField(crashCheckpoint, "completedBatches")
        let totalCandidateBatches = s4IntField(crashCheckpoint, "totalBatches")
        @Expect(committedCandidateBatches > 0, true)
        @Expect(committedCandidateBatches < totalCandidateBatches, true)
        let resumedCandidate = candidateStore.saveCandidateSnapshotImmutable(
            s4RawRecords(crashRecords), crashRecords, "candidate-crash")
        let candidateBaselineRoot = "${candidateRoot}-baseline"
        s4EnsureEmptyDir(candidateBaselineRoot)
        let candidateBaseline = FileKnowledgeStore(candidateBaselineRoot).saveCandidateSnapshotImmutable(
            s4RawRecords(crashRecords), crashRecords, "candidate-crash")
        @Expect(resumedCandidate.ok, true)
        @Expect(resumedCandidate.manifestEvidenceHash, candidateBaseline.manifestEvidenceHash)
        @Expect(resumedCandidate.reusedBatchCount, committedCandidateBatches)
        @Expect(resumedCandidate.writtenBatchCount, totalCandidateBatches - committedCandidateBatches)
        @Expect(resumedCandidate.peakBufferedRecords <= 256, true)
        @Expect(s4CountTmpFiles(Path(candidateRoot)), 0)

        let vectorRoot = "${root}/vector"
        s4EnsureEmptyDir(vectorRoot)
        let vectorCrash = s4LaunchAndKillCrashFixture(vectorRoot, "vector")
        @Expect(vectorCrash.ready, true)
        @Expect(vectorCrash.killed, true)
        @Expect(vectorCrash.exitCode == 0, false)
        @Expect(vectorCrash.orphanFree, true)
        let vectorStore = FileKnowledgeStore("${vectorRoot}/store")
        let records = s4NormalizedRecords(129, 0)
        s4ApplyValidationCoverage(records)
        let vectorContext = s4Context("p5-candidate-vector-crash", "candidate-vector-crash", records: records)
        let vectorCollection = s4StableCollection(vectorContext)
        let beforeResume = vectorStore.loadVectorSpoolCheckpoint(vectorContext, vectorCollection)
        @Expect(beforeResume.valid, true)
        @Expect(beforeResume.completed, 128)
        let tracking = S4TrackingVectorStore()
        let resumeProvider = S4EmbeddingProvider(64)
        let resumeKb = KnowledgeBase(FakeClock(0), resumeProvider, tracking, LocalGraphStore())
        let vector = resumeKb.buildVectorIndexForRecordsDurable(records, vectorCollection,
            vectorStore, vectorContext)
        @Expect(vector.ok, true)
        @Expect(resumeProvider.embeddedItems, 1)
        @Expect(vector.spool.batchRelativePaths.size, 2)
        @Expect(vector.peakBufferedRecords <= CkbCandidateDurableSchema.VECTOR_LOOKUP_BATCH_SIZE, true)
        @Expect(vector.peakBufferedBytes <= CkbCandidateDurableSchema.VECTOR_MAX_BUFFER_BYTES, true)
        let vectorBaselineRoot = "${vectorRoot}-baseline"
        s4EnsureEmptyDir(vectorBaselineRoot)
        let vectorBaseline = KnowledgeBase(FakeClock(0), S4EmbeddingProvider(64), LocalVectorStore(),
            LocalGraphStore()).buildVectorIndexForRecordsDurable(records, vectorCollection,
            FileKnowledgeStore(vectorBaselineRoot), vectorContext)
        @Expect(vectorBaseline.ok, true)
        @Expect(s4VectorSpoolEvidence(vector.spool), s4VectorSpoolEvidence(vectorBaseline.spool))

        let raw = s4RawRecords(records)
        let promotionProvider = S4EmbeddingProvider(64)
        let promotionKb = s4KnowledgeBaseWithRecordsAndProvider(records, raw, tracking,
            promotionProvider, "old-active-e2e")
        @Expect(promotionKb.status().activeKnowledgeVersion, "old-active-e2e")
        let candidate = vectorStore.saveCandidateSnapshotImmutable(raw, records, vectorContext.candidateVersion)
        @Expect(candidate.ok, true)
        promotionProvider.reset()
        let upsertsBeforePromotion = tracking.upsertBatchCalls
        let promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(promotionKb,
            vectorStore, vectorContext.candidateVersion, records, acquisitionContext: vectorContext)
        @Expect(promotion.ok, true)
        @Expect(promotion.activePromoted, true)
        @Expect(promotion.validation.status, "candidate_validation_passed")
        @Expect(promotionProvider.embeddedItems, 0)
        @Expect(tracking.upsertBatchCalls, upsertsBeforePromotion)
        @Expect(vectorStore.loadCandidateCollectionOwner(vectorCollection).state, "committed_active")
        @Expect(vectorStore.has("metadata/vector-builds/${vectorContext.acquisitionId}/checkpoint.ckb"), false)
        let reloaded = KnowledgeBase(FakeClock(0), S4EmbeddingProvider(64), tracking, LocalGraphStore())
        @Expect(reloaded.restoreActiveSnapshot(vectorStore.loadActiveSnapshot()), true)
        @Expect(reloaded.status().storage.indexCount, 129)
        @Expect(reloaded.status().storage.vectorIndexCount, 129)
        let recovery = ckbRecoverStaleSchedulerRunsWithVectorStore(vectorStore, tracking)
        @Expect(tracking.wasDeleted(vectorCollection), false)
        @Expect(s4Contains(recovery.diagnostics, "candidate_owner_preserved_active"), true)
        @Expect(s4CountTmpFiles(Path(root)), 0)
    }

    @TestCase
    public func s4E2EAChildCrashFixture(): Unit {
        if (getVariable("CKB_P5_S4_E2E_CHILD") != Some("1")) {
            @Expect(true, true)
            return
        }
        let root = s4Env("CKB_P5_S4_E2E_ROOT")
        let phase = s4Env("CKB_P5_S4_E2E_PHASE")
        let store = FileKnowledgeStore("${root}/store")
        if (phase == "point_id") {
            File.writeTo(Path(root).join("point-id.txt"), ckbVectorPointId(s4Normalized(7, changed: false)).toArray())
            @Expect(true, true)
            return
        } else if (phase == "candidate") {
            let records = s4CandidateCrashRecords()
            _ = store.saveCandidateSnapshotImmutable(s4RawRecords(records), records, "candidate-crash")
            File.writeTo(Path(root).join("candidate-completed-unexpected"), "completed".toArray())
            sleep(Duration.second * 30)
        } else if (phase == "vector") {
            let records = s4NormalizedRecords(129, 0)
            s4ApplyValidationCoverage(records)
            let context = s4Context("p5-candidate-vector-crash", "candidate-vector-crash", records: records)
            _ = KnowledgeBase(FakeClock(0), S4CrashEmbeddingProvider("${root}/vector.ready"),
                LocalVectorStore(), LocalGraphStore()).buildVectorIndexForRecordsDurable(records,
                s4StableCollection(context), store, context)
        } else {
            let profile = ckbSyncProfileForScheduleTask("cangjie_release_full_sync")
            let source = s4ReleaseSource()
            let result = CkbScheduledProfileFetchResult()
            result.releasePlan.planHash = "p5-plan-s4-e2e-remote"
            let inventory = ckbReleaseInventoryForSource(source)
            result.releaseInventories.add(inventory)
            if (phase == "source") {
                ckbFetchReleaseRemoteSource(S4ReleaseRunner(),
                    SourceRequestBuilder(gitCodeApiRoot: "https://fixture.invalid/api/v5"), source,
                    profile, result, inventory, CkbRuntimeConfig(), store)
                let runKey = result.releaseAcquisitionKeys[0]
                let checkpoint = ckbLoadReleaseResumeCheckpoint(store, runKey)
                checkpoint.phase = "content"
                checkpoint.sourceCompleteArtifactPath = ""
                ckbSaveReleaseResumeCheckpoint(store, runKey, checkpoint)
                _ = launch("/bin/rm", ["-f", "${root}/store/${ckbReleaseArtifactRelativePath(runKey, CkbReleaseArtifactKinds.SOURCE_COMPLETE)}"]).wait()
                File.writeTo(Path(root).join("source.ready"), "ready".toArray())
                sleep(Duration.second * 30)
            } else {
                ckbFetchReleaseRemoteSource(S4ReleaseRunner(crashMarker: "${root}/${phase}.ready",
                    crashPhase: phase), SourceRequestBuilder(gitCodeApiRoot: "https://fixture.invalid/api/v5"),
                    source, profile, result, inventory, CkbRuntimeConfig(), store)
            }
        }
        // The parent must kill this process while the runner is sleeping.
        @Expect(false, true)
    }
}

private class S4CrashRun {
    var ready: Bool = false
    var killed: Bool = false
    var orphanFree: Bool = false
    var pid: Int64 = 0
    var exitCode: Int64 = 0

    init() {}
}

private class S4RemoteRun {
    let result: CkbScheduledProfileFetchResult
    let inventory: CkbReleaseSourceInventory
    let runner: S4ReleaseRunner

    init(result: CkbScheduledProfileFetchResult, inventory: CkbReleaseSourceInventory,
        runner: S4ReleaseRunner) {
        this.result = result
        this.inventory = inventory
        this.runner = runner
    }
}

private class S4EmbeddingProvider <: EmbeddingProvider {
    let batchSize: Int64
    var calls: Int64 = 0
    var embeddedItems: Int64 = 0

    init(batchSize: Int64) { this.batchSize = batchSize }

    public func embed(texts: ArrayList<String>, model: String, dimensions: Int64): EmbeddingBatch {
        this.calls += 1
        this.embeddedItems += texts.size
        let batch = EmbeddingBatch()
        batch.requested = texts.size
        batch.batchSize = this.batchSize
        batch.status = this.status()
        for (_ in texts) {
            let vector = ArrayList<Float64>()
            vector.add(1.0); vector.add(2.0); vector.add(3.0)
            batch.vectors.add(vector)
        }
        batch.succeeded = texts.size
        batch
    }

    public func embedWithDeadline(texts: ArrayList<String>, model: String, dimensions: Int64,
        deadlineAtMillis: Int64): EmbeddingBatch { this.embed(texts, model, dimensions) }

    public func status(): EmbeddingStatus {
        let status = EmbeddingStatus()
        status.provider = "s4-fixture"
        status.model = "s4-model"
        status.dimensions = 3
        status.batchSize = this.batchSize
        status.maxBatchBytes = 1048576
        status.maxTextBytes = 8192
        status.state = EmbeddingProviderState.READY
        status
    }

    func reset(): Unit { this.calls = 0; this.embeddedItems = 0 }
}

private class S4TrackingVectorStore <: VectorStore {
    let delegate: LocalVectorStore = LocalVectorStore()
    var upsertBatchCalls: Int64 = 0
    var recreateCalls: Int64 = 0
    var deleteCollectionCalls: Int64 = 0
    var failUpsertAt: Int64 = -1
    let deleted: HashSet<String> = HashSet<String>()

    public func upsert(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.delegate.upsert(collection, vectors)
    }
    public func upsertBatch(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.upsertBatchWithDeadline(collection, vectors, 0)
    }
    public func upsertBatchWithDeadline(collection: String, vectors: ArrayList<VectorRecord>, deadlineAtMillis: Int64): VectorStoreStatus {
        this.upsertBatchCalls += 1
        if (this.upsertBatchCalls == this.failUpsertAt) {
            let status = this.delegate.status(collection)
            status.state = EmbeddingProviderState.DEGRADED
            status.degradedReason = "s4_injected_vector_batch_failure"
            return status
        }
        this.delegate.upsertBatchWithDeadline(collection, vectors, deadlineAtMillis)
    }
    public func search(collection: String, queryVector: ArrayList<Float64>, filters: VectorSearchFilters,
        topK: Int64): ArrayList<VectorSearchResult> { this.delegate.search(collection, queryVector, filters, topK) }
    public func status(collection: String): VectorStoreStatus { this.delegate.status(collection) }
    public func ensureReadyCollection(collection: String): VectorStoreStatus { this.delegate.ensureReadyCollection(collection) }
    public func clear(collection: String): VectorStoreStatus { this.delegate.clear(collection) }
    public func deleteCollection(collection: String): VectorStoreStatus {
        this.deleteCollectionCalls += 1
        this.deleted.add(collection)
        this.delegate.deleteCollection(collection)
    }
    public func recreate(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.recreateCalls += 1
        this.delegate.recreate(collection, vectors)
    }
    public func recreateWithDeadline(collection: String, vectors: ArrayList<VectorRecord>, deadlineAtMillis: Int64): VectorStoreStatus {
        this.recreateCalls += 1
        this.delegate.recreateWithDeadline(collection, vectors, deadlineAtMillis)
    }
    public func backup(collection: String): VectorBackup { this.delegate.backup(collection) }
    public func backupWithDeadline(collection: String, deadlineAtMillis: Int64): VectorBackup {
        this.delegate.backupWithDeadline(collection, deadlineAtMillis)
    }
    public func lookupBatchWithDeadline(collection: String, pointIds: ArrayList<String>, deadlineAtMillis: Int64): VectorLookupResult {
        this.delegate.lookupBatchWithDeadline(collection, pointIds, deadlineAtMillis)
    }
    public func restore(backup: VectorBackup): VectorStoreStatus { this.delegate.restore(backup) }
    func wasDeleted(collection: String): Bool { this.deleted.contains(collection) }
}

private class S4StageCapture <: CkbStagedRebuildStageSink {
    let events: ArrayList<String> = ArrayList<String>()

    public func onStagedRebuildStage(progress: CkbStagedRebuildStageProgress): Unit {
        this.events.add("${progress.stage}|${progress.status}|${progress.itemCount}")
    }

    func contains(needle: String): Bool { s4Contains(this.events, needle) }
}

private class S4QdrantExecutor <: HttpRequestExecutor {
    let responseBody: String
    var calls: Int64 = 0
    let methods: ArrayList<String> = ArrayList<String>()
    let urls: ArrayList<String> = ArrayList<String>()
    let bodies: ArrayList<String> = ArrayList<String>()

    init(responseBody: String) { this.responseBody = responseBody }

    public func execute(request: HttpExecutionRequest): HttpExecutionResponse {
        this.calls += 1
        this.methods.add(request.method)
        this.urls.add(request.url)
        this.bodies.add(request.body)
        let response = HttpExecutionResponse()
        response.statusCode = 200
        response.status = "http_200"
        response.contentType = "application/json"
        response.body = this.responseBody
        response
    }
    public func get(request: HttpExecutionRequest): HttpExecutionResponse { this.execute(request) }
}

private class S4ScaleQdrantExecutor <: HttpRequestExecutor {
    let totalRecords: Int64
    let reusableCount: Int64
    var candidateCollection: String = ""
    var activeCount: Int64 = 0
    var candidateCount: Int64 = 0
    var retrieveCalls: Int64 = 0
    var totalRetrieveIds: Int64 = 0
    var totalRetrieveFound: Int64 = 0
    var maxRetrieveIds: Int64 = 0
    var candidateUpsertCalls: Int64 = 0
    var scrollCalls: Int64 = 0
    var identityMismatch: Bool = false

    init(totalRecords: Int64, reusableCount: Int64) {
        this.totalRecords = totalRecords
        this.reusableCount = reusableCount
        this.activeCount = totalRecords
    }

    public func execute(request: HttpExecutionRequest): HttpExecutionResponse {
        let response = HttpExecutionResponse()
        response.statusCode = 200
        response.status = "http_200"
        response.contentType = "application/json"
        if (request.url.contains("/points/scroll")) {
            this.scrollCalls += 1
            response.body = "{\"status\":\"ok\",\"result\":{\"points\":[],\"next_page_offset\":null}}"
            return response
        }
        let collection = s4QdrantCollectionFromUrl(request.url)
        if (request.method == "POST" && request.url.endsWith("/points")) {
            let start = this.retrieveCalls * CkbCandidateDurableSchema.VECTOR_BATCH_SIZE
            let end = if (start + CkbCandidateDurableSchema.VECTOR_BATCH_SIZE < this.totalRecords) {
                start + CkbCandidateDurableSchema.VECTOR_BATCH_SIZE
            } else { this.totalRecords }
            let requested = end - start
            this.retrieveCalls += 1
            this.totalRetrieveIds += requested * 2
            if (requested * 2 > this.maxRetrieveIds) { this.maxRetrieveIds = requested * 2 }
            let body = StringBuilder()
            body.append("{\"status\":\"ok\",\"result\":[")
            var found: Int64 = 0
            for (index in start..end) {
                let candidateRecord = s4ScaleRecord(index, index >= this.reusableCount)
                let expectedPoint = ckbVectorPointId(candidateRecord)
                let expectedLegacy = ckbLegacyVectorPointId(candidateRecord, index)
                if (!request.body.contains(qdrantStablePointId(expectedPoint)) || !request.body.contains(qdrantStablePointId(expectedLegacy))) { this.identityMismatch = true }
                if (index < this.reusableCount) {
                    if (found > 0) { body.append(",") }
                    let legacy = s4Vector(s4ScaleRecord(index, false))
                    legacy.pointId = ckbLegacyVectorPointId(s4ScaleRecord(index, false), index)
                    body.append(s4QdrantPointJson(legacy))
                    found += 1
                }
            }
            if (end < this.totalRecords) {
                let nextRecord = s4ScaleRecord(end, end >= this.reusableCount)
                let nextPoint = ckbVectorPointId(nextRecord)
                let nextLegacy = ckbLegacyVectorPointId(nextRecord, end)
                if (request.body.contains(qdrantStablePointId(nextPoint)) || request.body.contains(qdrantStablePointId(nextLegacy))) { this.identityMismatch = true }
            }
            this.totalRetrieveFound += found
            body.append("]}")
            response.body = body.toString()
            return response
        }
        if (request.method == "DELETE") {
            if (collection == "active") { this.activeCount = 0 }
            if (collection == this.candidateCollection) { this.candidateCount = 0 }
            response.body = "{\"status\":\"ok\",\"result\":true}"
            return response
        }
        if (request.method == "PUT" && request.url.contains("/points?wait=true")) {
            let count = s4CountOccurrences(request.body, "\"ckb_id\"")
            if (collection == "active") { this.activeCount += count }
            if (collection == this.candidateCollection) { this.candidateCount += count; this.candidateUpsertCalls += 1 }
            response.body = "{\"status\":\"ok\",\"result\":{\"status\":\"acknowledged\"}}"
            return response
        }
        if (request.method == "PUT") {
            response.body = "{\"status\":\"ok\",\"result\":true}"
            return response
        }
        let count = if (collection == "active") { this.activeCount } else if (collection == this.candidateCollection) { this.candidateCount } else { 0 }
        response.body = "{\"status\":\"ok\",\"result\":{\"status\":\"green\",\"points_count\":${count},\"config\":{\"params\":{\"vectors\":{\"size\":3,\"distance\":\"Cosine\"}}}}}"
        response
    }

    public func get(request: HttpExecutionRequest): HttpExecutionResponse { this.execute(request) }
}

private class S4ReleaseRunner <: SourceFetchRunner {
    let crashMarker: String
    let crashPhase: String
    let fallbackRawPath: String
    var calls: Int64 = 0
    var contentCalls: Int64 = 0
    let paths: ArrayList<String> = ArrayList<String>()
    let requests: ArrayList<String> = ArrayList<String>()

    init(crashMarker!: String = "", crashPhase!: String = "path", fallbackRawPath!: String = "") {
        this.crashMarker = crashMarker
        this.crashPhase = crashPhase
        this.fallbackRawPath = fallbackRawPath
    }

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        this.calls += 1
        this.requests.add("${request.kind}:${request.page}:${request.path}")
        let result = SourceFetchResult()
        result.ok = true
        result.status = "ok"
        result.statusCode = 200
        result.sourceUrl = request.url
        result.repo = request.repo
        result.ref = request.ref
        result.path = request.path
        result.normalizedType = request.kind
        result.attempts = 1
        if (request.kind == SourceKinds.GITCODE_BRANCH) {
            result.contentType = "application/json"
            result.body = "[{\"name\":\"release-1.0.0\",\"commit\":{\"id\":\"${S4_COMMIT}\"}}]"
        } else if (request.kind == SourceKinds.GITCODE_TREE) {
            if (request.page == 2 && this.crashMarker != "" && this.crashPhase == "page") {
                this.blockForCrash()
            }
            result.contentType = "application/json"
            result.body = if (request.page != 1) { "[]" } else if (request.repo == "Cangjie/cangjie_runtime") {
                "[{\"path\":\"src/runtime.cj\",\"type\":\"blob\"}]"
            } else if (request.repo == "Cangjie/cangjie_stdx") {
                "[{\"path\":\"src/stdx.cj\",\"type\":\"blob\"}]"
            } else if (request.repo == "Cangjie/cangjie_tools") {
                "[{\"path\":\"tools/guide.md\",\"type\":\"blob\"}]"
            } else {
                "[{\"path\":\"docs/a.md\",\"type\":\"blob\"},{\"path\":\"docs/b.md\",\"type\":\"blob\"}]"
            }
        } else if (request.kind == SourceKinds.GITCODE_SOURCE) {
            this.contentCalls += 1
            this.paths.add(request.path)
            if (request.path == "docs/b.md" && this.crashMarker != "" && this.crashPhase == "path") {
                this.blockForCrash()
            }
            if (request.path == this.fallbackRawPath && request.sourceVariant == "raw") {
                result.ok = false
                result.status = "not_found"
                result.statusCode = 404
                result.attempts = 2
                result.body = ""
                result.contentType = "application/json"
            } else if (request.path == this.fallbackRawPath && request.sourceVariant == "contents") {
                result.contentType = "application/json"
                result.body = "{\"type\":\"file\",\"encoding\":\"base64\",\"content\":\"ZmFsbGJhY2sgYm9keQ==\",\"path\":\"${request.path}\",\"sha\":\"${S4_COMMIT}\",\"html_url\":\"${request.url}\"}"
            } else {
                result.contentType = "text/markdown"
                result.body = "# ${request.path}\n仓颉🙂 durable resume\n"
            }
            result.commit = S4_COMMIT
        }
        result
    }

    private func blockForCrash(): Unit {
        File.writeTo(Path(this.crashMarker), "ready".toArray())
        sleep(Duration.second * 30)
    }
}

private class S4CrashEmbeddingProvider <: EmbeddingProvider {
    let marker: String
    var calls: Int64 = 0

    init(marker: String) { this.marker = marker }

    public func embed(texts: ArrayList<String>, model: String, dimensions: Int64): EmbeddingBatch {
        this.calls += 1
        if (this.calls == 3) {
            File.writeTo(Path(this.marker), "ready".toArray())
            sleep(Duration.second * 30)
        }
        let provider = S4EmbeddingProvider(64)
        provider.embed(texts, model, dimensions)
    }

    public func embedWithDeadline(texts: ArrayList<String>, model: String, dimensions: Int64,
        deadlineAtMillis: Int64): EmbeddingBatch { this.embed(texts, model, dimensions) }

    public func status(): EmbeddingStatus { S4EmbeddingProvider(64).status() }
}

private func s4ReleaseSource(): CkbReleaseSourcePlan {
    let source = CangjieVersionSource()
    source.targetVersion = "1.0.0"
    source.sourceSet = CangjieSourceSets.DOCS
    source.sourceFamily = "docs"
    source.sourceRepo = "Cangjie/cangjie_docs"
    source.sourceRef = "release-1.0.0"
    source.refKind = "branch"
    ckbReleaseSourcePlan(source, "1.0.0")
}

private func s4Normalized(index: Int64, changed!: Bool = false): NormalizedRecord {
    let record = NormalizedRecord()
    record.sourceId = "s4-record-${index}"
    record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    record.title = "仓颉🙂 title ${index}"
    record.chunk = if (changed) { "changed candidate chunk ${index} 中文🙂" } else { "stable active chunk ${index} 中文🙂" }
    record.citation = "https://fixture.invalid/docs/${index}"
    record.metadata.sourceId = record.sourceId
    record.metadata.sourceType = SourceTypes.DOC
    record.metadata.sourceUrl = record.citation
    record.metadata.repo = "Cangjie/cangjie_docs"
    record.metadata.path = "docs/${index}.md"
    record.metadata.targetVersion = "1.0.0"
    record.metadata.sourceSet = CangjieSourceSets.DOCS
    record.metadata.knowledgeVersion = "active"
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.TRUSTED
    record
}

private func s4ScaleRecord(index: Int64, changed: Bool): NormalizedRecord {
    if (index < 3 && !changed) {
        let coverage = ArrayList<NormalizedRecord>()
        coverage.add(s4ScaleBaseRecord(0, false))
        coverage.add(s4ScaleBaseRecord(1, false))
        coverage.add(s4ScaleBaseRecord(2, false))
        s4ApplyValidationCoverage(coverage)
        return coverage[index]
    }
    s4ScaleBaseRecord(index, changed)
}

private func s4ScaleBaseRecord(index: Int64, changed: Bool): NormalizedRecord {
    let record = NormalizedRecord()
    record.sourceId = "r${index}"
    record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    record.title = "t"
    record.chunk = if (changed) { "b${index}" } else { "a${index}" }
    record.citation = "c${index}"
    record.metadata.sourceId = record.sourceId
    record.metadata.sourceType = SourceTypes.DOC
    record.metadata.sourceUrl = record.citation
    record.metadata.repo = "r"
    record.metadata.path = "d/${index}"
    record.metadata.targetVersion = "1.0.0"
    record.metadata.sourceSet = CangjieSourceSets.DOCS
    record.metadata.knowledgeVersion = "active"
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.TRUSTED
    record
}

private func s4ScaleRecords(count: Int64, changedFrom: Int64): ArrayList<NormalizedRecord> {
    let records = ArrayList<NormalizedRecord>()
    for (index in 0..count) { records.add(s4ScaleRecord(index, index >= changedFrom && changedFrom > 0)) }
    s4ApplyValidationCoverage(records)
    records
}

private func s4NormalizedRecords(count: Int64, changedFrom: Int64): ArrayList<NormalizedRecord> {
    let records = ArrayList<NormalizedRecord>()
    for (index in 0..count) { records.add(s4Normalized(index, changed: index >= changedFrom && changedFrom > 0)) }
    records
}

private func s4ApplyValidationCoverage(records: ArrayList<NormalizedRecord>): Unit {
    if (records.size < 3) { return }
    records[0].recordKind = CangjieTypedRecordKinds.SYMBOL_CARD
    records[0].title = "ArrayList.add"
    records[0].chunk = "symbolKey=ArrayList.add\nmodule=std.collection\nsignature=func add(value: T): Unit\naliases=ArrayList.add;add"
    records[0].metadata.sourceSet = CangjieSourceSets.STD
    records[0].metadata.sourceType = SourceTypes.REPO
    records[0].metadata.versionResolutionId = "vr-std-s4"
    records[1].recordKind = CangjieTypedRecordKinds.DOC_SECTION
    records[1].title = "ArrayList.add docs"
    records[1].chunk = "ArrayList.add appends values. Do not use append."
    records[1].metadata.versionResolutionId = "vr-docs-s4"
    records[2].recordKind = CangjieTypedRecordKinds.TOOL_MANUAL
    records[2].title = "cjpm test"
    records[2].chunk = "Run cjpm test to execute package tests."
    records[2].metadata.sourceSet = CangjieSourceSets.TOOLS
    records[2].metadata.path = "tools/cjpm.md"
    records[2].metadata.versionResolutionId = "vr-tools-s4"
}

private func s4RawRecords(records: ArrayList<NormalizedRecord>): ArrayList<RawRecord> {
    let out = ArrayList<RawRecord>()
    for (record in records) {
        let raw = RawRecord()
        raw.sourceId = record.sourceId
        raw.title = record.title
        raw.content = record.chunk
        raw.contentHash = ckbReleaseEvidenceHash(raw.content)
        raw.metadata = record.metadata
        out.add(raw)
    }
    out
}

private func s4Vector(record: NormalizedRecord): VectorRecord {
    let vector = VectorRecord()
    vector.id = record.sourceId
    vector.pointId = ckbVectorPointId(record)
    vector.title = record.title
    vector.chunk = record.chunk
    vector.citation = record.citation
    vector.metadata = record.metadata
    vector.vector.add(1.0); vector.vector.add(2.0); vector.vector.add(3.0)
    vector
}

private func s4Context(acquisitionId: String, candidateVersion: String, records!: ArrayList<NormalizedRecord> = ArrayList<NormalizedRecord>()): CkbCandidateAcquisitionContext {
    for (record in records) { record.metadata.candidateVersion = candidateVersion }
    let context = CkbCandidateAcquisitionContext()
    context.acquisitionId = acquisitionId
    context.schedulerRunId = "scheduler-${acquisitionId}"
    context.taskId = "cangjie_release_full_sync"
    context.candidateVersion = candidateVersion
    context.planHash = "plan-${candidateVersion}"
    context.recordsEvidenceHash = ckbCandidateRecordsEvidenceHash(records, stagedCandidateVersion: candidateVersion)
    context
}

private func s4ActiveKnowledgeBase(vectorStore: VectorStore, activeVersion: String): KnowledgeBase {
    let provider = S4EmbeddingProvider(2)
    let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
    let records = s4NormalizedRecords(4, 0)
    s4ApplyValidationCoverage(records)
    let snapshot = ActiveSnapshot()
    snapshot.valid = true
    snapshot.activeVersion = activeVersion
    snapshot.activeStateSource = "persisted"
    snapshot.vectorActiveCollection = "active-old"
    snapshot.vectorCandidateCollection = "candidate"
    snapshot.hasVectorArtifact = true
    let raw = s4RawRecords(records)
    for (item in raw) { snapshot.rawRecords.add(item) }
    for (record in records) {
        snapshot.normalizedRecords.add(record)
        snapshot.activeIndex.add(record)
        snapshot.vectorRecords.add(s4Vector(record))
    }
    _ = kb.restoreActiveSnapshot(snapshot)
    kb
}

private func s4StableCollection(context: CkbCandidateAcquisitionContext): String {
    ckbCandidateStableCollection(context)
}

private func s4Owner(context: CkbCandidateAcquisitionContext, collection: String, state: String): CkbCandidateCollectionOwner {
    let owner = CkbCandidateCollectionOwner()
    owner.valid = true
    owner.collection = collection
    owner.acquisitionId = context.acquisitionId
    owner.schedulerRunId = context.schedulerRunId
    owner.taskId = context.taskId
    owner.candidateVersion = context.candidateVersion
    owner.planHash = context.planHash
    owner.recordsEvidenceHash = context.recordsEvidenceHash
    owner.state = state
    owner
}

private func s4QdrantRetrieveBody(record: VectorRecord): String {
    "{\"status\":\"ok\",\"result\":[{\"id\":1,\"payload\":{\"ckb_id\":\"${record.id}\",\"title\":\"仓颉🙂 title 7\",\"chunk\":\"stable active chunk 7 中文🙂\",\"citation\":\"https://fixture.invalid/docs/7\",\"sourceId\":\"${record.metadata.sourceId}\",\"sourceType\":\"doc\",\"sourceUrl\":\"https://fixture.invalid/docs/7\",\"repo\":\"Cangjie/cangjie_docs\",\"path\":\"docs/7.md\",\"targetVersion\":\"1.0.0\",\"sourceSet\":\"docs\",\"knowledgeVersion\":\"active\",\"trustLevel\":\"official\",\"reviewState\":\"trusted\"},\"vector\":[1.0,2.0,3.0]}]}"
}

private func s4QdrantPointJson(record: VectorRecord): String {
    "{\"id\":${qdrantStablePointId(record.pointId)},\"payload\":{\"ckb_id\":\"${ckbScheduledFetchJsonEscape(record.id)}\",\"pointId\":\"${ckbScheduledFetchJsonEscape(record.pointId)}\",\"title\":\"${ckbScheduledFetchJsonEscape(record.title)}\",\"chunk\":\"${ckbScheduledFetchJsonEscape(record.chunk)}\",\"citation\":\"${ckbScheduledFetchJsonEscape(record.citation)}\",\"sourceId\":\"${ckbScheduledFetchJsonEscape(record.metadata.sourceId)}\",\"sourceType\":\"${ckbScheduledFetchJsonEscape(record.metadata.sourceType)}\",\"sourceUrl\":\"${ckbScheduledFetchJsonEscape(record.metadata.sourceUrl)}\",\"repo\":\"${ckbScheduledFetchJsonEscape(record.metadata.repo)}\",\"path\":\"${ckbScheduledFetchJsonEscape(record.metadata.path)}\",\"targetVersion\":\"${ckbScheduledFetchJsonEscape(record.metadata.targetVersion)}\",\"sourceSet\":\"${ckbScheduledFetchJsonEscape(record.metadata.sourceSet)}\",\"versionResolutionId\":\"${ckbScheduledFetchJsonEscape(record.metadata.versionResolutionId)}\",\"knowledgeVersion\":\"${ckbScheduledFetchJsonEscape(record.metadata.knowledgeVersion)}\",\"trustLevel\":\"${ckbScheduledFetchJsonEscape(record.metadata.trustLevel)}\",\"reviewState\":\"${ckbScheduledFetchJsonEscape(record.metadata.reviewState)}\"},\"vector\":[1.0,2.0,3.0]}"
}

private func s4QdrantCollectionFromUrl(url: String): String {
    let parts = url.split("/collections/")
    if (parts.size != 2) { return "" }
    let suffix = parts[1].split("/")
    if (suffix.size == 0) { return "" }
    suffix[0]
}

private func s4CountOccurrences(value: String, needle: String): Int64 {
    if (needle == "") { return 0 }
    let parts = value.split(needle)
    if (parts.size == 0) { return 0 }
    parts.size - 1
}

private func s4EstimatedVectorBufferedBytes(record: NormalizedRecord): Int64 {
    ckbVectorSourceBufferedBytes(record, 3, ordinal: 0)
}

private func s4VectorByteBoundaryRecord(targetBytes: Int64, candidateVersion: String): NormalizedRecord {
    let record = s4Normalized(999999, changed: false)
    record.metadata.symbol = "符号🙂|\\\n"
    record.metadata.sourceUrl = "https://fixture.invalid/字面\\n与\\p|🙂"
    record.metadata.repo = "Cangjie\\repo|仓颉"
    record.metadata.path = "C:\\new\\path\\p|仓颉🙂.cj"
    record.metadata.commit = "0123456789abcdef"
    record.metadata.docVersion = "文档🙂"
    record.metadata.versionResolutionId = "解析🙂"
    record.metadata.crawlAt = "2026-07-11T00:00:00Z"
    record.metadata.indexedAt = "2026-07-11T00:00:01Z"
    record.metadata.candidateVersion = candidateVersion
    record.metadata.license = "Apache-2.0"
    record.metadata.repoVisibility = "public"
    record.metadata.derivedFrom = ["来源|一🙂", "source\\two\nline"]
    record.chunk = ""
    record.citation = "c"
    var remaining = targetBytes - s4EstimatedVectorBufferedBytes(record)
    if (remaining > 1) {
        record.chunk = s4RepeatAscii("x", remaining / 2)
    }
    remaining = targetBytes - s4EstimatedVectorBufferedBytes(record)
    if (remaining > 0) { record.citation += s4RepeatAscii("y", remaining) }
    for (_ in 0..16) {
        let current = s4EstimatedVectorBufferedBytes(record)
        if (current <= targetBytes) { break }
        let remove = (current - targetBytes + 1) / 2
        if (remove > 0 && record.chunk.size >= remove) { record.chunk = record.chunk[0..record.chunk.size - remove] }
    }
    let exactPadding = targetBytes - s4EstimatedVectorBufferedBytes(record)
    if (exactPadding > 0) { record.metadata.license += s4RepeatAscii("z", exactPadding) }
    record
}

private func s4RepeatAscii(value: String, count: Int64): String {
    let out = StringBuilder()
    for (_ in 0..count) { out.append(value) }
    out.toString()
}

private func s4AssertEvalSourceCompleteCrashWindowResumesWithoutReads(): Unit {
    let root = "target/p5-s4-b01-eval-complete-window"
    s4EnsureEmptyDir(root)
    let evalRoot = "${root}/eval"
    s4WriteEvalFixture(evalRoot)
    let config = CkbRuntimeConfig()
    config.networkEnabled = true
    config.firstInitEvalRoot = evalRoot
    config.firstInitTargetVersion = "1.0.0"
    config.benchmarkGapTargetVersion = "1.0.0"
    let manifest = s4FiveSourceManifest()
    let profile = ckbSyncProfileForScheduleTask("cangjie_release_full_sync")
    let store = FileKnowledgeStore("${root}/store")
    let first = fetchScheduledProfileSources(profile, S4ReleaseRunner(), config, store, manifest)
    @Expect(first.ok, true)
    var evalKey = CkbScheduledFetchRunKey()
    for (key in first.releaseAcquisitionKeys) {
        if (key.sourceIdentity.contains("eval")) { evalKey = key }
    }
    @Expect(evalKey.acquisitionId != "", true)
    let checkpoint = ckbLoadReleaseResumeCheckpoint(store, evalKey)
    @Expect(checkpoint.valid, true)
    @Expect(checkpoint.phase, "completed")
    checkpoint.phase = "content"
    checkpoint.sourceCompleteArtifactPath = ""
    ckbSaveReleaseResumeCheckpoint(store, evalKey, checkpoint)
    _ = launch("/bin/rm", ["-f", "${root}/store/${ckbReleaseArtifactRelativePath(evalKey, CkbReleaseArtifactKinds.SOURCE_COMPLETE)}"]).wait()
    let secondRunner = S4ReleaseRunner()
    let second = fetchScheduledProfileSources(profile, secondRunner, config, store, manifest)
    @Expect(second.ok, true)
    @Expect(secondRunner.calls, 0)
    @Expect(s4Contains(second.diagnostics, "release_eval_partial_resumed:"), true)
    @Expect(s4Contains(second.diagnostics, "localReads=0"), true)
    @Expect(ckbLoadReleaseResumeCheckpoint(store, evalKey).phase, "completed")
}

private func s4AssertRemoteCompletedHydrateExact(): Unit {
    let root = "target/p5-s4-u01-remote-hydrate"
    s4EnsureEmptyDir(root)
    let store = FileKnowledgeStore(root)
    let profile = ckbSyncProfileForScheduleTask("cangjie_release_full_sync")
    let source = s4ReleaseSource()
    let first = CkbScheduledProfileFetchResult()
    let firstInventory = ckbReleaseInventoryForSource(source)
    first.releaseInventories.add(firstInventory)
    let firstRunner = S4ReleaseRunner(fallbackRawPath: "docs/b.md")
    ckbFetchReleaseRemoteSource(firstRunner, SourceRequestBuilder(gitCodeApiRoot: "https://fixture.invalid/api/v5"),
        source, profile, first, firstInventory, CkbRuntimeConfig(), store)
    @Expect(first.ok, true)
    @Expect(firstInventory.complete, true)
    @Expect(firstRunner.calls, 6)

    let second = CkbScheduledProfileFetchResult()
    let secondInventory = ckbReleaseInventoryForSource(source)
    second.releaseInventories.add(secondInventory)
    let secondRunner = S4ReleaseRunner()
    ckbFetchReleaseRemoteSource(secondRunner, SourceRequestBuilder(gitCodeApiRoot: "https://fixture.invalid/api/v5"),
        source, profile, second, secondInventory, CkbRuntimeConfig(), store)
    @Expect(second.ok, true)
    @Expect(secondInventory.complete, true)
    @Expect(secondRunner.calls, 0)
    @Expect(second.contentRecords.size, first.contentRecords.size)
    @Expect(second.controlEvidence.size, first.controlEvidence.size)
    @Expect(s4FetchEvidence(second, secondInventory), s4FetchEvidence(first, firstInventory))
    for (index in 0..first.contentRecords.size) {
        let actual = second.contentRecords[index]
        let expected = first.contentRecords[index]
        @Expect(actual.sourceId, expected.sourceId); @Expect(actual.sourceType, expected.sourceType)
        @Expect(actual.sourceFamily, expected.sourceFamily); @Expect(actual.sourceSet, expected.sourceSet); @Expect(actual.title, expected.title)
        @Expect(actual.releaseSource.canonicalIdentity, expected.releaseSource.canonicalIdentity)
        @Expect(actual.request.kind, expected.request.kind); @Expect(actual.request.method, expected.request.method)
        @Expect(actual.request.url, expected.request.url); @Expect(actual.request.repo, expected.request.repo)
        @Expect(actual.request.ref, expected.request.ref); @Expect(actual.request.path, expected.request.path)
        @Expect(actual.request.accept, expected.request.accept); @Expect(actual.request.authHint, expected.request.authHint)
        @Expect(actual.request.status, expected.request.status); @Expect(actual.request.diagnostic, expected.request.diagnostic)
        @Expect(actual.request.page, expected.request.page); @Expect(actual.request.perPage, expected.request.perPage)
        @Expect(actual.request.purpose, expected.request.purpose); @Expect(actual.request.sourceVariant, expected.request.sourceVariant)
        @Expect(actual.request.paginationParam, expected.request.paginationParam); @Expect(actual.request.perPageParam, expected.request.perPageParam)
        @Expect(actual.request.timeoutMillis, expected.request.timeoutMillis); @Expect(actual.request.retryCount, expected.request.retryCount)
        @Expect(actual.request.repoVisibility, expected.request.repoVisibility)
        @Expect(actual.fetch.ok, expected.fetch.ok); @Expect(actual.fetch.status, expected.fetch.status)
        @Expect(actual.fetch.statusCode, expected.fetch.statusCode); @Expect(actual.fetch.body, expected.fetch.body)
        @Expect(actual.fetch.commit, expected.fetch.commit); @Expect(actual.fetch.sourceUrl, expected.fetch.sourceUrl)
        @Expect(actual.fetch.normalizedType, expected.fetch.normalizedType); @Expect(actual.fetch.etag, expected.fetch.etag)
        @Expect(actual.fetch.lastModified, expected.fetch.lastModified); @Expect(actual.fetch.truncated, expected.fetch.truncated)
        @Expect(actual.fetch.contentType, expected.fetch.contentType); @Expect(actual.fetch.bytes, expected.fetch.bytes)
        @Expect(actual.fetch.bodyHash, expected.fetch.bodyHash); @Expect(actual.fetch.retryAfterSeconds, expected.fetch.retryAfterSeconds)
        @Expect(actual.fetch.attempts, expected.fetch.attempts); @Expect(actual.fetch.transportErrorClass, expected.fetch.transportErrorClass)
        @Expect(actual.fetch.transportDiagnostic, expected.fetch.transportDiagnostic); @Expect(actual.fetch.curlExitCode, expected.fetch.curlExitCode)
        @Expect(actual.fetch.repo, expected.fetch.repo); @Expect(actual.fetch.ref, expected.fetch.ref)
        @Expect(actual.fetch.path, expected.fetch.path); @Expect(actual.fetch.repoVisibility, expected.fetch.repoVisibility)
    }
    for (index in 0..first.controlEvidence.size) {
        @Expect(second.controlEvidence[index].kind, first.controlEvidence[index].kind)
        @Expect(second.controlEvidence[index].sourceIdentity, first.controlEvidence[index].sourceIdentity)
        @Expect(second.controlEvidence[index].sourceSet, first.controlEvidence[index].sourceSet)
        @Expect(second.controlEvidence[index].repo, first.controlEvidence[index].repo)
        @Expect(second.controlEvidence[index].originalRef, first.controlEvidence[index].originalRef)
        @Expect(second.controlEvidence[index].resolvedCommit, first.controlEvidence[index].resolvedCommit)
        @Expect(second.controlEvidence[index].path, first.controlEvidence[index].path)
        @Expect(second.controlEvidence[index].page, first.controlEvidence[index].page)
        @Expect(second.controlEvidence[index].status, first.controlEvidence[index].status)
        @Expect(second.controlEvidence[index].bodyHash, first.controlEvidence[index].bodyHash)
        @Expect(second.controlEvidence[index].attemptCount, first.controlEvidence[index].attemptCount)
        @Expect(second.controlEvidence[index].objectCount, first.controlEvidence[index].objectCount)
        @Expect(second.controlEvidence[index].fileCount, first.controlEvidence[index].fileCount)
    }
}

private func s4AssertRemoteSourceCompleteCrashWindowResumesWithoutRequests(): Unit {
    let root = "target/p5-s4-b01-remote-complete-window"
    s4EnsureEmptyDir(root)
    let store = FileKnowledgeStore(root)
    let profile = ckbSyncProfileForScheduleTask("cangjie_release_full_sync")
    let source = s4ReleaseSource()
    let first = CkbScheduledProfileFetchResult()
    first.releasePlan.planHash = "p5-plan-s4-b01-remote-complete"
    let firstInventory = ckbReleaseInventoryForSource(source)
    first.releaseInventories.add(firstInventory)
    ckbFetchReleaseRemoteSource(S4ReleaseRunner(), SourceRequestBuilder(gitCodeApiRoot: "https://fixture.invalid/api/v5"),
        source, profile, first, firstInventory, CkbRuntimeConfig(), store)
    @Expect(first.ok, true)
    @Expect(first.releaseAcquisitionKeys.size, 1)
    let runKey = first.releaseAcquisitionKeys[0]
    let checkpoint = ckbLoadReleaseResumeCheckpoint(store, runKey)
    @Expect(checkpoint.valid, true)
    @Expect(checkpoint.phase, "completed")
    checkpoint.phase = "content"
    checkpoint.sourceCompleteArtifactPath = ""
    ckbSaveReleaseResumeCheckpoint(store, runKey, checkpoint)
    @Expect(launch("/bin/rm", ["-f", "${root}/${ckbReleaseArtifactRelativePath(runKey, CkbReleaseArtifactKinds.SOURCE_COMPLETE)}"]).wait(), 0)
    let releaseTmp = Path(root).join("${ckbReleaseAcquisitionRoot(runKey)}/pages/.tmp-interrupted-page-write")
    File.writeTo(releaseTmp, "partial-page".toArray())

    let second = CkbScheduledProfileFetchResult()
    second.releasePlan.planHash = first.releasePlan.planHash
    let secondInventory = ckbReleaseInventoryForSource(source)
    second.releaseInventories.add(secondInventory)
    let runner = S4ReleaseRunner()
    ckbFetchReleaseRemoteSource(runner, SourceRequestBuilder(gitCodeApiRoot: "https://fixture.invalid/api/v5"),
        source, profile, second, secondInventory, CkbRuntimeConfig(), store)
    @Expect(second.ok, true)
    @Expect(secondInventory.complete, true)
    @Expect(runner.calls, 0)
    @Expect(exists(releaseTmp), false)
    @Expect(s4Contains(second.diagnostics, "release_acquisition_stale_temps_removed"), true)
    @Expect(s4Contains(second.diagnostics, "release_tree_page_artifact_hydrated"), true)
    @Expect(s4Contains(second.diagnostics, "release_content_artifact_hydrated"), true)
    @Expect(s4FetchEvidence(second, secondInventory), s4FetchEvidence(first, firstInventory))
    @Expect(ckbLoadReleaseResumeCheckpoint(store, runKey).phase, "completed")
}

private func s4AssertReleaseCursorCrashMatrix(): Unit {
    for (unit in ["page", "path", "source_complete"]) {
        for (cursorCommitted in [false, true]) {
            let suffix = if (cursorCommitted) { "committed" } else { "uncommitted" }
            let root = "target/p5-s4-b01-release-${unit}-${suffix}"
            s4EnsureEmptyDir(root)
            let baseline = s4ResumeRemoteCrash(root)
            @Expect(baseline.result.ok, true)
            @Expect(baseline.inventory.complete, true)
            let store = FileKnowledgeStore("${root}/store")
            let runKey = baseline.result.releaseAcquisitionKeys[0]
            let checkpoint = ckbLoadReleaseResumeCheckpoint(store, runKey)
            @Expect(checkpoint.valid, true)
            let completeArtifact = ckbLoadReleaseContentArtifact(store, runKey,
                CkbReleaseArtifactKinds.SOURCE_COMPLETE)
            @Expect(completeArtifact.valid, true)

            if (unit == "source_complete" && cursorCommitted) {
                // Fully committed is the zero-redo side of the source-complete gate.
                ()
            } else {
                checkpoint.phase = if (unit == "page") { "tree_page" } else { "content" }
                checkpoint.sourceCompleteArtifactPath = ""
                s4RemoveString(checkpoint.artifactEvidenceHashes, completeArtifact.evidenceHash)
                if (unit != "source_complete") {
                    @Expect(launch("/bin/rm", ["-f", Path("${root}/store").join(
                        completeArtifact.relativePath).toString()]).wait(), 0)
                }
                if (unit == "page") {
                    let page = ckbLoadReleaseContentArtifact(store, runKey,
                        CkbReleaseArtifactKinds.TREE_PAGE, ordinal: 2)
                    @Expect(page.valid, true)
                    if (!cursorCommitted) {
                        s4RemoveString(checkpoint.pageArtifactPaths, page.relativePath)
                        s4RemoveString(checkpoint.artifactEvidenceHashes, page.evidenceHash)
                        checkpoint.nextPage = 2
                    }
                } else if (unit == "path") {
                    let content = ckbLoadReleaseContentArtifact(store, runKey,
                        CkbReleaseArtifactKinds.CONTENT, logicalPath: "docs/b.md")
                    @Expect(content.valid, true)
                    if (!cursorCommitted) {
                        s4RemoveString(checkpoint.contentArtifactPaths, content.relativePath)
                        s4RemoveString(checkpoint.artifactEvidenceHashes, content.evidenceHash)
                        s4RemoveString(checkpoint.completedPaths, "docs/b.md")
                    }
                }
                ckbSaveReleaseResumeCheckpoint(store, runKey, checkpoint)
            }

            let resumed = s4ResumeRemoteCrash(root)
            let expectedRedo = if (!cursorCommitted && (unit == "page" || unit == "path")) { 1 } else { 0 }
            @Expect(resumed.result.ok, true)
            @Expect(resumed.inventory.complete, true)
            @Expect(resumed.runner.calls, expectedRedo)
            @Expect(resumed.runner.contentCalls, if (!cursorCommitted && unit == "path") { 1 } else { 0 })
            if (!cursorCommitted && unit == "page") {
                @Expect(s4Contains(resumed.result.diagnostics, "release_tree_page_artifact_uncommitted"), true)
            } else if (!cursorCommitted && unit == "path") {
                @Expect(s4Contains(resumed.result.diagnostics, "release_content_artifact_uncommitted"), true)
            } else if (!cursorCommitted && unit == "source_complete") {
                @Expect(s4Contains(resumed.result.diagnostics, "release_completed_checkpoint_rejected"), true)
            }
            @Expect(s4FetchEvidence(resumed.result, resumed.inventory),
                s4FetchEvidence(baseline.result, baseline.inventory))
            let terminal = ckbLoadReleaseResumeCheckpoint(store, runKey)
            @Expect(terminal.valid, true)
            @Expect(terminal.phase, "completed")
            @Expect(terminal.completedPaths.size, terminal.plannedPaths.size)
            @Expect(terminal.sourceCompleteArtifactPath != "", true)
            @Expect(s4CountTmpFiles(Path(root)), 0)
        }
    }
}

private func s4AssertCandidateCursorCrashMatrix(): Unit {
    for (count in [Int64(0), Int64(1), Int64(256), Int64(257)]) {
        let root = "target/p5-s4-b01-candidate-cursor-${count}"
        s4EnsureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let records = s4NormalizedRecords(count, 0)
        let raw = s4RawRecords(records)
        let version = "candidate-cursor-${count}"
        let first = store.saveCandidateSnapshotImmutable(raw, records, version)
        @Expect(first.ok, true)
        let committed = store.saveCandidateSnapshotImmutable(raw, records, version)
        @Expect(committed.ok, true)
        @Expect(committed.immutableReused, true)
        @Expect(committed.reusedBatchCount, first.batchCount)
        @Expect(committed.writtenBatchCount, 0)

        @Expect(launch("/bin/rm", ["-f", Path(root).join(
            "candidate-artifacts/${version}/manifest.ckb").toString()]).wait(), 0)
        let committedBatches = if (first.batchCount > 0) { first.batchCount - 1 } else { 0 }
        let phase = if (first.batchCount > 0) { "batch_committed" } else { "normalized_committed" }
        let evidence = ckbReleaseEvidenceHash("${version}|${phase}|${committedBatches}|${first.batchCount}|${first.manifestEvidenceHash}")
        store.writeLinesAtomically("candidate-artifacts/${version}/checkpoint.ckb",
            "schemaVersion=${CkbCandidateDurableSchema.VERSION}\nversion=${version}\nphase=${phase}\ncompletedBatches=${committedBatches}\ntotalBatches=${first.batchCount}\nmanifestEvidenceHash=${first.manifestEvidenceHash}\nupdatedAtMillis=1\nevidenceHash=${evidence}\n")
        if (first.batchCount > 0) {
            @Expect(store.has("candidate-artifacts/${version}/batches/batch-${first.batchCount - 1}.ckb"), true)
        }
        let resumed = store.saveCandidateSnapshotImmutable(raw, records, version)
        @Expect(resumed.ok, true)
        @Expect(resumed.manifestEvidenceHash, first.manifestEvidenceHash)
        @Expect(resumed.reusedBatchCount, committedBatches)
        @Expect(resumed.writtenBatchCount, if (first.batchCount > 0) { 1 } else { 0 })
        @Expect(store.has("candidate-artifacts/${version}/manifest.ckb"), true)
        @Expect(store.readText("candidate-artifacts/${version}/checkpoint.ckb").contains("phase=completed"), true)

        // Crash before the first batch cursor: even pre-existing batch files are
        // uncommitted and every boundary unit must be rebuilt exactly once.
        @Expect(launch("/bin/rm", ["-f", Path(root).join(
            "candidate-artifacts/${version}/manifest.ckb").toString()]).wait(), 0)
        let beforeFirstEvidence = ckbReleaseEvidenceHash(
            "${version}|normalized_committed|0|${first.batchCount}|${first.manifestEvidenceHash}")
        store.writeLinesAtomically("candidate-artifacts/${version}/checkpoint.ckb",
            "schemaVersion=${CkbCandidateDurableSchema.VERSION}\nversion=${version}\nphase=normalized_committed\ncompletedBatches=0\ntotalBatches=${first.batchCount}\nmanifestEvidenceHash=${first.manifestEvidenceHash}\nupdatedAtMillis=2\nevidenceHash=${beforeFirstEvidence}\n")
        let restarted = store.saveCandidateSnapshotImmutable(raw, records, version)
        @Expect(restarted.ok, true)
        @Expect(restarted.manifestEvidenceHash, first.manifestEvidenceHash)
        @Expect(restarted.reusedBatchCount, 0)
        @Expect(restarted.writtenBatchCount, first.batchCount)
        @Expect(store.readText("candidate-artifacts/${version}/checkpoint.ckb").contains("phase=completed"), true)
        @Expect(s4CountTmpFiles(Path(root)), 0)
    }
}

private func s4AssertVectorCursorCrashMatrix(): Unit {
    for (count in [Int64(0), Int64(1), CkbCandidateDurableSchema.VECTOR_BATCH_SIZE,
        CkbCandidateDurableSchema.VECTOR_BATCH_SIZE + 1]) {
        let root = "target/p5-s4-b01-vector-cursor-${count}"
        s4EnsureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        let records = s4NormalizedRecords(count, 0)
        let context = s4Context("p5-vector-cursor-${count}", "candidate-vector-cursor-${count}",
            records: records)
        let collection = s4StableCollection(context)
        let backend = S4TrackingVectorStore()
        let firstProvider = S4EmbeddingProvider(64)
        let first = KnowledgeBase(FakeClock(0), firstProvider, backend, LocalGraphStore())
            .buildVectorIndexForRecordsDurable(records, collection, store, context)
        @Expect(first.ok, true)
        let upsertsAfterFirst = backend.upsertBatchCalls
        let committedProvider = S4EmbeddingProvider(64)
        let committed = KnowledgeBase(FakeClock(0), committedProvider, backend, LocalGraphStore())
            .buildVectorIndexForRecordsDurable(records, collection, store, context)
        @Expect(committed.ok, true)
        @Expect(committedProvider.embeddedItems, 0)
        @Expect(backend.upsertBatchCalls, upsertsAfterFirst)

        let partial = CkbVectorSpoolDescriptor()
        partial.acquisitionId = context.acquisitionId
        partial.candidateVersion = context.candidateVersion
        partial.planHash = context.planHash
        partial.recordsEvidenceHash = context.recordsEvidenceHash
        partial.collection = collection
        partial.status = "running"
        partial.total = count
        partial.batchSize = first.spool.batchSize
        partial.peakBufferedRecords = first.spool.peakBufferedRecords
        partial.peakBufferedBytes = first.spool.peakBufferedBytes
        let committedBatchCount = if (first.spool.batchRelativePaths.size > 0) {
            first.spool.batchRelativePaths.size - 1
        } else { 0 }
        for (index in 0..committedBatchCount) {
            partial.batchRelativePaths.add(first.spool.batchRelativePaths[index])
            partial.batchEvidenceHashes.add(first.spool.batchEvidenceHashes[index])
            partial.batchRecordCounts.add(first.spool.batchRecordCounts[index])
            let batchCount = try { Int64.parse(first.spool.batchRecordCounts[index]) } catch (_: Exception) { -1 }
            partial.completed += batchCount
            partial.embedded += batchCount
        }
        @Expect(launch("/bin/rm", ["-f", Path(root).join(
            first.spool.manifestRelativePath).toString()]).wait(), 0)
        store.saveVectorSpoolCheckpoint(partial)
        if (first.spool.batchRelativePaths.size > 0) {
            @Expect(store.has(first.spool.batchRelativePaths[first.spool.batchRelativePaths.size - 1]), true)
        }
        let redoProvider = S4EmbeddingProvider(64)
        let upsertsBeforeRedo = backend.upsertBatchCalls
        let resumed = KnowledgeBase(FakeClock(0), redoProvider, backend, LocalGraphStore())
            .buildVectorIndexForRecordsDurable(records, collection, store, context)
        let redoCount = count - partial.completed
        @Expect(resumed.ok, true)
        @Expect(redoProvider.embeddedItems, redoCount)
        @Expect(backend.upsertBatchCalls - upsertsBeforeRedo, if (redoCount > 0) { 1 } else { 0 })
        @Expect(s4VectorSpoolEvidence(resumed.spool), s4VectorSpoolEvidence(first.spool))
        @Expect(resumed.spool.status, "completed")
        @Expect(resumed.spool.completed, count)
        @Expect(store.has(resumed.spool.manifestRelativePath), true)
        @Expect(store.readText(resumed.spool.checkpointRelativePath).contains("status=completed"), true)

        // Crash before the first vector cursor: the backend may already contain
        // uncommitted writes, but the durable cursor requires every batch redo.
        let beforeFirst = CkbVectorSpoolDescriptor()
        beforeFirst.acquisitionId = context.acquisitionId
        beforeFirst.candidateVersion = context.candidateVersion
        beforeFirst.planHash = context.planHash
        beforeFirst.recordsEvidenceHash = context.recordsEvidenceHash
        beforeFirst.collection = collection
        beforeFirst.status = "running"
        beforeFirst.total = count
        beforeFirst.batchSize = first.spool.batchSize
        @Expect(launch("/bin/rm", ["-f", Path(root).join(
            resumed.spool.manifestRelativePath).toString()]).wait(), 0)
        store.saveVectorSpoolCheckpoint(beforeFirst)
        let restartProvider = S4EmbeddingProvider(64)
        let upsertsBeforeRestart = backend.upsertBatchCalls
        let restarted = KnowledgeBase(FakeClock(0), restartProvider, backend, LocalGraphStore())
            .buildVectorIndexForRecordsDurable(records, collection, store, context)
        @Expect(restarted.ok, true)
        @Expect(restartProvider.embeddedItems, count)
        @Expect(backend.upsertBatchCalls - upsertsBeforeRestart, first.spool.batchRelativePaths.size)
        @Expect(s4VectorSpoolEvidence(restarted.spool), s4VectorSpoolEvidence(first.spool))
        @Expect(store.readText(restarted.spool.checkpointRelativePath).contains("status=completed"), true)
        @Expect(s4CountTmpFiles(Path(root)), 0)
    }
}

private func s4RemoveString(values: ArrayList<String>, expected: String): Unit {
    for (index in 0..values.size) {
        if (values[index] == expected) {
            values.remove(at: index)
            return
        }
    }
}

private func s4FetchEvidence(result: CkbScheduledProfileFetchResult, inventory: CkbReleaseSourceInventory): String {
    let out = StringBuilder()
    out.append("${inventory.sourceIdentity}|${inventory.resolvedCommit}|${inventory.pagesScanned}|${inventory.objectsSeen}|${inventory.filesSeen}|${inventory.contentBytes}")
    for (path in inventory.plannedPaths) { out.append("|planned=${path}") }
    for (path in inventory.completedPaths) { out.append("|completed=${path}") }
    for (record in result.contentRecords) { out.append("|record=${record.sourceId}:${record.request.path}:${record.fetch.bodyHash}:${record.fetch.commit}") }
    for (evidence in result.controlEvidence) { out.append("|control=${evidence.kind}:${evidence.path}:${evidence.bodyHash}:${evidence.objectCount}:${evidence.fileCount}") }
    ckbReleaseEvidenceHash(out.toString())
}

private func s4FiveSourceManifest(): CangjieVersionManifest {
    let manifest = CangjieVersionManifest()
    manifest.defaultTargetVersion = "1.0.0"
    s4AddManifestSource(manifest, CangjieSourceSets.DOCS, "docs", "Cangjie/cangjie_docs")
    s4AddManifestSource(manifest, CangjieSourceSets.STD, "stdlib", "Cangjie/cangjie_runtime")
    s4AddManifestSource(manifest, CangjieSourceSets.STDX, "stdx", "Cangjie/cangjie_stdx")
    s4AddManifestSource(manifest, CangjieSourceSets.TOOLS, "tools", "Cangjie/cangjie_tools")
    s4AddManifestSource(manifest, CangjieSourceSets.EVAL_SUPPORT, "eval-support", "CangjieCommunityKnowledgeBase/Cangjie-HumanEval")
    manifest
}

private func s4AddManifestSource(manifest: CangjieVersionManifest, sourceSet: String, family: String, repo: String): Unit {
    let source = CangjieVersionSource()
    source.targetVersion = "1.0.0"
    source.sourceSet = sourceSet
    source.sourceFamily = family
    source.sourceRepo = repo
    source.sourceRef = "release-1.0.0"
    source.refKind = if (sourceSet == CangjieSourceSets.EVAL_SUPPORT) { "local" } else { "branch" }
    manifest.sources.add(source)
}

private func s4WriteEvalFixture(root: String): Unit {
    let caseRoot = Path(root).join("CJ-HUMANEVAL-P5-S4")
    Directory.create(caseRoot.join("starter/src"), recursive: true)
    Directory.create(caseRoot.join("tests"), recursive: true)
    File.writeTo(caseRoot.join("prompt.md"), "# 仓颉🙂 prompt\n实现函数。\n".toArray())
    File.writeTo(caseRoot.join("metadata.json"), "{\"id\":\"CJ-HUMANEVAL-P5-S4\"}\n".toArray())
    File.writeTo(caseRoot.join("starter/src/eval_support.cj"), "package fixture\npublic class EvalValue {}\n".toArray())
    File.writeTo(caseRoot.join("tests/TestMain.cj"), "package fixture\npublic func visible(): Unit {}\n".toArray())
}

private func s4EnsureEmptyDir(path: String): Unit {
    if (exists(Path(path))) { _ = launch("/bin/rm", ["-rf", path]).wait() }
    Directory.create(Path(path), recursive: true)
}

private func s4LaunchAndKillCrashFixture(root: String, phase: String): S4CrashRun {
    let result = S4CrashRun()
    let pidPath = Path(root).join("child.pid")
    let command = "echo $$ > ${pidPath}; ${s4ChildCommand(root, phase)}"
    let process = launch("/bin/zsh", ["-c", command], stdOut: ProcessRedirect.Pipe,
        stdErr: ProcessRedirect.Pipe)
    var waited = false
    try {
        result.ready = if (phase == "candidate") {
            s4WaitForCandidatePartialCheckpoint(Path(root).join("store/candidate-artifacts/candidate-crash/checkpoint.ckb"),
                Path(root).join("candidate-completed-unexpected"), 15000)
        } else {
            s4WaitForPath(Path(root).join("${phase}.ready"), 10000)
        }
        result.pid = s4ReadInt(pidPath)
        if (result.ready && result.pid > 0 && s4PidAlive(result.pid)) {
            result.killed = launch("/bin/kill", ["-9", "${result.pid}"]).wait() == 0
        }
        result.exitCode = process.wait()
        waited = true
    } finally {
        if (result.pid == 0) { result.pid = s4ReadInt(pidPath) }
        if (result.pid > 0 && s4PidAlive(result.pid)) {
            _ = launch("/bin/kill", ["-9", "${result.pid}"]).wait()
        }
        if (!waited) {
            try { result.exitCode = process.wait() } catch (_: Exception) { result.exitCode = -1 }
        }
        result.orphanFree = result.pid > 0 && !s4PidAlive(result.pid)
    }
    result
}

private func s4ChildCommand(root: String, phase: String): String {
    var dyldLibraryPath = ""
    if (let Some(value) <- getVariable("DYLD_LIBRARY_PATH")) { dyldLibraryPath = value }
    let childPrelude = ckbSchedulerWorkerShellPreludeWithHeap(dyldLibraryPath, "")
    "${childPrelude}export CKB_P5_S4_E2E_CHILD=1; export CKB_P5_S4_E2E_ROOT=${root}; export CKB_P5_S4_E2E_PHASE=${phase}; exec target/release/unittest_bin/cangjie_community_knowledge_base_test --filter='*CkbS4DurableResumeTest.s4E2EAChildCrashFixture' --no-color --no-progress"
}

private func s4WaitForCandidatePartialCheckpoint(checkpoint: Path, completedMarker: Path,
    timeoutMillis: Int64): Bool {
    var waited: Int64 = 0
    while (waited < timeoutMillis) {
        if (exists(completedMarker)) { return false }
        if (exists(checkpoint)) {
            let text = try { String.fromUtf8(File.readFrom(checkpoint)) } catch (_: Exception) { "" }
            let completed = s4IntField(text, "completedBatches")
            let total = s4IntField(text, "totalBatches")
            if (text.contains("phase=batch_committed") && completed > 0 && completed < total) { return true }
        }
        sleep(Duration.millisecond)
        waited += 1
    }
    false
}

private func s4ResumeRemoteCrash(root: String): S4RemoteRun {
    let store = FileKnowledgeStore("${root}/store")
    let profile = ckbSyncProfileForScheduleTask("cangjie_release_full_sync")
    let source = s4ReleaseSource()
    let result = CkbScheduledProfileFetchResult()
    result.releasePlan.planHash = "p5-plan-s4-e2e-remote"
    let inventory = ckbReleaseInventoryForSource(source)
    result.releaseInventories.add(inventory)
    let runner = S4ReleaseRunner()
    ckbFetchReleaseRemoteSource(runner, SourceRequestBuilder(gitCodeApiRoot: "https://fixture.invalid/api/v5"),
        source, profile, result, inventory, CkbRuntimeConfig(), store)
    S4RemoteRun(result, inventory, runner)
}

private func s4FreshRemoteBaseline(root: String): S4RemoteRun {
    s4EnsureEmptyDir(root)
    s4ResumeRemoteCrash(root)
}

private func s4CandidateCrashRecords(): ArrayList<NormalizedRecord> {
    let records = s4NormalizedRecords(4097, 0)
    let padding = s4RepeatAscii("x", 2048)
    for (record in records) { record.chunk += padding }
    records
}

private func s4IntField(text: String, key: String): Int64 {
    for (line in text.split("\n")) {
        let parts = line.split("=")
        if (parts.size == 2 && parts[0] == key) {
            return try { Int64.parse(parts[1]) } catch (_: Exception) { -1 }
        }
    }
    -1
}

private func s4VectorSpoolEvidence(descriptor: CkbVectorSpoolDescriptor): String {
    let out = StringBuilder()
    out.append("${descriptor.total}|${descriptor.completed}|${descriptor.reused}|${descriptor.embedded}|${descriptor.failed}")
    for (index in 0..descriptor.batchRelativePaths.size) {
        out.append("|${descriptor.batchEvidenceHashes[index]}:${descriptor.batchRecordCounts[index]}")
    }
    ckbReleaseEvidenceHash(out.toString())
}

private func s4KnowledgeBaseWithRecords(records: ArrayList<NormalizedRecord>, raw: ArrayList<RawRecord>,
    vectorStore: VectorStore, activeVersion: String): KnowledgeBase {
    s4KnowledgeBaseWithRecordsAndProvider(records, raw, vectorStore, S4EmbeddingProvider(64),
        activeVersion)
}

private func s4KnowledgeBaseWithRecordsAndProvider(records: ArrayList<NormalizedRecord>,
    raw: ArrayList<RawRecord>, vectorStore: VectorStore, provider: EmbeddingProvider,
    activeVersion: String): KnowledgeBase {
    let kb = KnowledgeBase(FakeClock(0), provider, vectorStore, LocalGraphStore())
    let snapshot = ActiveSnapshot()
    snapshot.valid = true
    snapshot.activeVersion = activeVersion
    snapshot.activeStateSource = "persisted"
    snapshot.vectorActiveCollection = "active-old"
    snapshot.vectorCandidateCollection = "candidate"
    snapshot.hasVectorArtifact = true
    for (item in raw) { snapshot.rawRecords.add(item) }
    for (record in records) {
        snapshot.normalizedRecords.add(record)
        snapshot.activeIndex.add(record)
        snapshot.vectorRecords.add(s4Vector(record))
    }
    _ = kb.restoreActiveSnapshot(snapshot)
    kb
}

private func s4PidAlive(pid: Int64): Bool {
    pid > 0 && launch("/bin/sh", ["-c", "kill -0 ${pid} 2>/dev/null"]).wait() == 0
}

private func s4Contains(values: ArrayList<String>, needle: String): Bool {
    for (value in values) { if (value.contains(needle)) { return true } }
    false
}

private func s4CountTmpFiles(path: Path): Int64 {
    if (!exists(path)) { return 0 }
    var count: Int64 = 0
    try {
        for (entry in Directory.readFrom(path)) {
            let child = path.join(entry.name)
            if (entry.isDirectory()) { count += s4CountTmpFiles(child) }
            else if (entry.isRegular() && entry.name.startsWith(".tmp-")) { count += 1 }
        }
    } catch (_: Exception) { () }
    count
}

private func s4WaitForPath(path: Path, timeoutMillis: Int64): Bool {
    var waited: Int64 = 0
    while (waited < timeoutMillis) {
        if (exists(path)) { return true }
        sleep(Duration.millisecond * 20)
        waited += 20
    }
    exists(path)
}

private func s4ReadInt(path: Path): Int64 {
    try { Int64.parse(String.fromUtf8(File.readFrom(path)).trimAscii()) } catch (_: Exception) { 0 }
}

private func s4ReadText(path: Path): String {
    try { String.fromUtf8(File.readFrom(path)) } catch (_: Exception) { "" }
}

private func s4SafeReadPipe(pipe: InputStream): String {
    try { StringReader<InputStream>(pipe).readToEnd() } catch (_: Exception) { "invalid_response_encoding" }
}

private func s4TextField(value: String, key: String): String {
    for (line in value.split("\n")) {
        let parts = line.split("=")
        if (parts.size == 2 && parts[0] == key) { return parts[1] }
    }
    ""
}

private func s4Env(name: String): String {
    if (let Some(value) <- getVariable(name)) { return value }
    ""
}
