package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashSet}
import std.fs.{Directory, File, Path, exists}
import std.process.*
import std.sort.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbReleaseAcquisitionTest {
    @TestCase
    public func p5S3U01PlanIdentityLogicalIdsCheckpointAndCoreUpdatesAreDeterministic(): Unit {
        let profile = ckbReleaseTestProfile()
        let baseline = ckbReleaseTestManifest()
        let baselinePlan = ckbBuildReleaseFullSyncPlan(profile, baseline, "1.0.0")

        @Expect(baselinePlan.ok, true)
        @Expect(baselinePlan.sources.size, 5)
        @Expect(baselinePlan.missingSourceSets.size, 0)
        @Expect(baselinePlan.planHash.startsWith("p5-plan-"), true)

        let persisted = ckbReleaseTestManifest()
        let persistedEval = ckbReleaseTestManifestSource(persisted, CangjieSourceSets.EVAL_SUPPORT)
        persistedEval.sourceRepo = "ckb-local://eval-support"
        persistedEval.refKind = "local"
        let persistedPlan = ckbBuildReleaseFullSyncPlan(profile, persisted, "1.0.0")
        @Expect(persistedPlan.ok, true)
        @Expect(ckbReleaseTestPlanSource(baselinePlan, CangjieSourceSets.EVAL_SUPPORT).canonicalIdentity,
            ckbReleaseTestPlanSource(persistedPlan, CangjieSourceSets.EVAL_SUPPORT).canonicalIdentity)
        @Expect(baselinePlan.planHash, persistedPlan.planHash)

        let duplicate = ckbReleaseTestManifest()
        let duplicateEval = CangjieVersionSource()
        duplicateEval.targetVersion = "1.0.0"
        duplicateEval.sourceSet = CangjieSourceSets.EVAL_SUPPORT
        duplicateEval.sourceFamily = "eval-support"
        duplicateEval.sourceRepo = "ckb-local://eval-support"
        duplicateEval.sourceRef = "release/1.0"
        duplicateEval.refKind = "local"
        duplicate.sources.add(duplicateEval)
        let duplicatePlan = ckbBuildReleaseFullSyncPlan(profile, duplicate, "1.0.0")
        @Expect(duplicatePlan.ok, false)
        @Expect(duplicatePlan.status.startsWith(CkbReleaseAcquisitionStatus.DUPLICATE_SOURCE_IDENTITY), true)

        let docs = ckbReleaseTestPlanSource(baselinePlan, CangjieSourceSets.DOCS)
        let longPath = ckbReleaseTestLongPath(700)
        let rawId = ckbReleaseCanonicalRawId(docs, longPath)
        @Expect(rawId.startsWith("p5raw-"), true)
        @Expect(rawId.size < 100, true)
        @Expect(rawId, ckbReleaseCanonicalRawId(docs, longPath))
        @Expect(ckbReleaseCanonicalRawKey(docs, longPath).contains("%E8%B7%AF%E5%BE%84"), true)

        let a1 = ckbReleaseTestTyped("Heading 中文🙂", "content-one")
        let a2 = ckbReleaseTestTyped("Heading 中文🙂", "content-two")
        let unrelated = ckbReleaseTestTyped("Unrelated", "other")
        let allocatorOne = CkbReleaseLogicalIdAllocator()
        let firstA = allocatorOne.typedId(docs, longPath, a1)
        let duplicateA = allocatorOne.typedId(docs, longPath, a2)
        let allocatorTwo = CkbReleaseLogicalIdAllocator()
        _ = allocatorTwo.typedId(docs, "other.md", unrelated)
        let afterUnrelatedA = allocatorTwo.typedId(docs, longPath, a2)
        @Expect(firstA.startsWith("p5typed-"), true)
        @Expect(firstA.size < 100, true)
        @Expect(firstA, afterUnrelatedA)
        @Expect(firstA == duplicateA, false)

        let paths = ArrayList<String>()
        paths.add("docs/a,b.md")
        paths.add("文档/emoji🙂-\"quoted\".md")
        paths.add("docs/Authorization-Bearer-fixture-secret.md")
        let encoded = ckbScheduledFetchPathsJson(paths)
        let decoded = ArrayList<String>()
        @Expect(ckbScheduledFetchDecodePathsJson(encoded, decoded), true)
        @Expect(decoded.size, paths.size)
        @Expect(decoded[0], paths[0])
        @Expect(decoded[1], paths[1])
        @Expect(decoded[2], paths[2])
        @Expect(encoded.contains("fixture-secret"), true)

        let fullRoot = "target/p5-s3-u01-three-pages"
        ckbReleaseTestEnsureEmptyDir(fullRoot)
        let fullEvalRoot = "${fullRoot}/eval"
        ckbReleaseTestWriteEvalFixture(fullEvalRoot)
        let fullConfig = CkbRuntimeConfig()
        fullConfig.networkEnabled = true
        fullConfig.firstInitEvalRoot = fullEvalRoot
        fullConfig.firstInitTargetVersion = "1.0.0"
        fullConfig.benchmarkGapTargetVersion = "1.0.0"
        let threePageRunner = CkbReleaseThreePageRunner()
        let fullFetch = fetchScheduledProfileSources(profile, threePageRunner, fullConfig, FileKnowledgeStore("${fullRoot}/store"), baseline)
        @Expect(fullFetch.ok, true)
        @Expect(fullFetch.releaseInventories.size, 5)
        @Expect(fullFetch.contentRecords.size, 16)
        @Expect(ckbReleaseTestScheduledRecordsHaveAllSets(fullFetch.contentRecords), true)
        @Expect(ckbReleaseTestInventoriesExactAndComplete(fullFetch.releaseInventories), true)
        @Expect(ckbReleaseTestRemoteInventoriesHaveThreePages(fullFetch.releaseInventories), true)
        @Expect(ckbReleaseTestContentHasNoControlRecords(fullFetch.contentRecords), true)
        @Expect(ckbReleaseTestControlEvidenceHasRefAndTree(fullFetch.controlEvidence), true)

        let sampleRunner = CkbP4SampleRunner()
        let docsProfile = ckbSyncProfileForScheduleTask("cangjie_docs_full_weekly")
        let docsFetch = fetchScheduledProfileSources(docsProfile, sampleRunner, fullConfig, FileKnowledgeStore("${fullRoot}/p4-store"), baseline)
        @Expect(docsFetch.ok, true)
        @Expect(sampleRunner.treePage2Calls, 0)
        @Expect(sampleRunner.sourceCalls, 4)

        let kb = newOfflineKnowledgeBase()
        let first = ckbReleaseTestFetch("first body", "commit-a")
        let second = ckbReleaseTestFetch("second body", "commit-b")
        @Expect(kb.ingestFetchResult("duplicate-A", SourceTypes.REPO, first, "A", TrustLevels.OFFICIAL, ReviewStates.TRUSTED), true)
        @Expect(kb.ingestFetchResult("duplicate-B", SourceTypes.REPO, second, "B", TrustLevels.OFFICIAL, ReviewStates.TRUSTED), true)
        let update = ckbReleaseTestFetch("updated body", "commit-a2")
        @Expect(kb.ingestFetchResult("duplicate-A", SourceTypes.REPO, update, "A2", TrustLevels.OFFICIAL, ReviewStates.TRUSTED), true)
        let rawAfterUpdate = kb.rawRecordSnapshot()
        @Expect(ckbReleaseTestRawContent(rawAfterUpdate, "duplicate-A"), "updated body")
        @Expect(ckbReleaseTestRawContent(rawAfterUpdate, "duplicate-B"), "second body")

        let rollback = kb.activeSnapshotForRollback()
        rollback.normalizedRecords.clear()
        @Expect(kb.restoreActiveSnapshot(rollback), true)
        let originalChunk = kb.activeRecordSnapshot()[0].chunk
        rollback.activeIndex[0].chunk = "snapshot-mutated"
        rollback.activeIndex[0].metadata.path = "snapshot-mutated-path"
        rollback.rawRecords[0].content = "snapshot-mutated-raw"
        @Expect(kb.activeRecordSnapshot()[0].chunk, originalChunk)
        @Expect(kb.activeRecordSnapshot()[0].metadata.path == "snapshot-mutated-path", false)
        @Expect(kb.rawRecordSnapshot()[0].content == "snapshot-mutated-raw", false)

        let wrongOwner = ckbReleaseTestRaw("p5raw-same", "old", "other-owner")
        let current = ckbReleaseTestRaw("p5raw-same", "new", "scheduled:cangjie_release_full_sync")
        let currentList = ArrayList<RawRecord>()
        currentList.add(current)
        let oldList = ArrayList<RawRecord>()
        oldList.add(wrongOwner)
        kb.replaceRawRecords(oldList)
        let overlay = kb.rawRecordSnapshotOverlayForOwner("scheduled:cangjie_release_full_sync", "1.0.0", ArrayList<String>(), currentList)
        @Expect(overlay.size, 1)
        @Expect(overlay[0].content, "new")
    }

    @TestCase
    public func p5S3B01InventoryBoundariesStrictJsonUnicodeAndSafeDiagnosticsFailClosed(): Unit {
        let profile = ckbReleaseTestProfile()
        let source = ckbReleaseTestPlanSource(ckbBuildReleaseFullSyncPlan(profile, ckbReleaseTestManifest(), "1.0.0"), CangjieSourceSets.DOCS)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let builder = SourceRequestBuilder(gitCodeApiRoot: "https://fixture.invalid/api/v5")

        source.maxNonEmptyPages = 0
        let zero = ckbReleaseTestRemoteRun("target/p5-s3-b01-zero", source, profile, config, builder, CkbReleaseBoundaryRunner(0, 1, "# zero"))
        @Expect(zero[0].ok, false)
        @Expect(zero[0].status, "release_source_empty")
        @Expect(zero[1].complete, false)
        @Expect(zero[1].nonEmptyPages, 0)
        @Expect(zero[1].pagesScanned, 1)

        source.maxNonEmptyPages = 1
        source.maxObjects = 10
        source.maxFiles = 10
        source.maxBytes = 1000
        let exact = ckbReleaseTestRemoteRun("target/p5-s3-b01-exact", source, profile, config, builder, CkbReleaseBoundaryRunner(1, 1, "# exact 中文🙂"))
        @Expect(exact[0].ok, true)
        @Expect(exact[1].complete, true)
        @Expect(exact[1].explicitEnd, true)
        @Expect(exact[1].nonEmptyPages, 1)
        @Expect(exact[1].pagesScanned, 2)
        @Expect(exact[1].plannedPaths.size, 1)
        @Expect(exact[1].completedPaths.size, 1)

        let pageOverflow = ckbReleaseTestRemoteRun("target/p5-s3-b01-page-over", source, profile, config, builder, CkbReleaseBoundaryRunner(2, 1, "# overflow"))
        @Expect(pageOverflow[0].ok, false)
        @Expect(pageOverflow[0].status, CkbReleaseAcquisitionStatus.INVENTORY_LIMIT_EXCEEDED)
        @Expect(pageOverflow[1].complete, false)
        @Expect(ckbReleaseTestDiagnosticsContain(pageOverflow[0].diagnostics, "dimension=nonempty_pages"), true)

        source.maxNonEmptyPages = 2
        source.maxObjects = 1
        source.maxFiles = 10
        let objectOverflow = ckbReleaseTestRemoteRun("target/p5-s3-b01-object-over", source, profile, config, builder, CkbReleaseBoundaryRunner(1, 2, "# objects"))
        @Expect(objectOverflow[0].status, CkbReleaseAcquisitionStatus.INVENTORY_LIMIT_EXCEEDED)
        @Expect(ckbReleaseTestDiagnosticsContain(objectOverflow[0].diagnostics, "dimension=objects"), true)

        source.maxObjects = 10
        source.maxFiles = 1
        let fileOverflow = ckbReleaseTestRemoteRun("target/p5-s3-b01-file-over", source, profile, config, builder, CkbReleaseBoundaryRunner(1, 2, "# files"))
        @Expect(fileOverflow[0].status, CkbReleaseAcquisitionStatus.INVENTORY_LIMIT_EXCEEDED)
        @Expect(ckbReleaseTestDiagnosticsContain(fileOverflow[0].diagnostics, "dimension=files"), true)

        source.maxFiles = 10
        source.maxBytes = 2
        let byteOverflow = ckbReleaseTestRemoteRun("target/p5-s3-b01-byte-over", source, profile, config, builder, CkbReleaseBoundaryRunner(1, 1, "中文🙂"))
        @Expect(byteOverflow[0].status, CkbReleaseAcquisitionStatus.INVENTORY_LIMIT_EXCEEDED)
        @Expect(ckbReleaseTestDiagnosticsContain(byteOverflow[0].diagnostics, "dimension=bytes"), true)

        let empty = ckbReleaseParseTreePage(CangjieSourceSets.DOCS, "[]")
        let malformed = ckbReleaseParseTreePage(CangjieSourceSets.DOCS, "{bad-json")
        let unknownType = ckbReleaseParseTreePage(CangjieSourceSets.DOCS, "[{\"path\":\"docs/a.md\",\"type\":\"mystery\"}]")
        let truncatedJson = ckbReleaseParseTreePage(CangjieSourceSets.DOCS, "{\"tree\":[],\"truncated\":true}")
        @Expect(empty.ok, true)
        @Expect(empty.explicitEnd, true)
        @Expect(malformed.status, CkbReleaseAcquisitionStatus.MALFORMED_JSON)
        @Expect(unknownType.status, CkbReleaseAcquisitionStatus.MALFORMED_JSON)
        @Expect(truncatedJson.truncated, true)
        @Expect(truncatedJson.status, CkbReleaseAcquisitionStatus.INVENTORY_LIMIT_EXCEEDED)
        @Expect(ckbReleaseNormalizeSourcePath("docs/a\u{0008}.md"), "")
        @Expect(ckbReleaseNormalizeSourcePath("docs/a\u{000C}.md"), "")
        @Expect(ckbReleaseNormalizeSourcePath("docs/a\u{001B}.md"), "")
        @Expect(ckbReleaseNormalizeSourcePath("docs/a\u{007F}.md"), "")
        @Expect(ckbReleaseNormalizeSourcePath("docs/a\u{0085}.md"), "")

        let unicodePath = CkbReleaseFullRunner.STABLE_A_PATH
        let request = builder.gitCodeReleaseSourceRawWithFetchRef("Cangjie/cangjie_docs", "release-1.0.0", "0123456789abcdef0123456789abcdef01234567", unicodePath)
        @Expect(request.path, CkbReleaseFullRunner.STABLE_A_PATH)
        @Expect(request.url.contains("%20"), true)
        @Expect(request.url.contains("%3F"), true)
        @Expect(request.url.contains("%23"), true)
        @Expect(request.url.contains("%26"), true)
        @Expect(request.url.contains("%3D"), true)
        @Expect(request.url.contains("%3A"), true)
        @Expect(request.url.contains("%2C"), true)
        @Expect(request.url.contains("%22"), true)
        @Expect(request.url.contains("%E8%B7%AF%E5%BE%84"), true)
        @Expect(request.url.contains("%F0%9F%99%82"), true)
        @Expect(request.url.contains("路径"), false)

        let sensitiveRunner = CkbReleaseBoundaryRunner(1, 1, "# safe")
        sensitiveRunner.pathPrefix = "docs/Authorization-Bearer-fixture-secret/Users/private/路径🙂"
        let safe = ckbReleaseTestRemoteRun("target/p5-s3-b01-safe", source, profile, config, builder, sensitiveRunner)
        let joined = ckbReleaseTestJoin(safe[0].diagnostics)
        @Expect(joined.contains("fixture-secret"), false)
        @Expect(joined.contains("/Users/private"), false)
        @Expect(joined.size < 12000, true)

        source.maxBytes = 1000
        let malformedContents = ckbReleaseTestRemoteRun("target/p5-s3-b01-contents-malformed", source, profile, config, builder, CkbReleaseContentsFailureRunner("malformed"))
        let invalidUtf8Contents = ckbReleaseTestRemoteRun("target/p5-s3-b01-contents-utf8", source, profile, config, builder, CkbReleaseContentsFailureRunner("invalid_utf8"))
        let binaryContents = ckbReleaseTestRemoteRun("target/p5-s3-b01-contents-binary", source, profile, config, builder, CkbReleaseContentsFailureRunner("binary"))
        @Expect(malformedContents[0].status, CkbReleaseAcquisitionStatus.MALFORMED_JSON)
        @Expect(invalidUtf8Contents[0].status, "invalid_response_encoding")
        @Expect(binaryContents[0].status, "unsupported_binary")
        @Expect(malformedContents[0].contentRecords.size, 0)
        @Expect(invalidUtf8Contents[0].contentRecords.size, 0)
        @Expect(binaryContents[0].contentRecords.size, 0)
    }

    @TestCase
    public func p5S3P01PersistedManifestReloadSecondRunKeepsLogicalIdsAndCountsStable(): Unit {
        let root = "target/p5-s3-p01-two-runs"
        ckbReleaseTestEnsureEmptyDir(root)
        let evalRoot = "${root}/eval"
        ckbReleaseTestWriteEvalFixture(evalRoot)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.firstInitEvalRoot = evalRoot
        config.firstInitTargetVersion = "1.0.0"
        config.benchmarkGapTargetVersion = "1.0.0"
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(ckbReleaseTestManifest())
        let kb = newOfflineKnowledgeBase()
        let preRaw = kb.rawRecordSnapshot()
        let legacy = ckbReleaseTestRaw("scheduled-cangjie_release_full_sync-legacy-doc-control", "legacy control body", "2026-01-01T00:00:00Z")
        legacy.metadata.sourceSet = CangjieSourceSets.DOCS
        legacy.metadata.repo = ""
        let protected = ckbReleaseTestRaw("scheduled-cangjie_source_event_sync-protected", "protected source event", "scheduled:cangjie_source_event_sync")
        protected.metadata.sourceSet = CangjieSourceSets.STD
        protected.metadata.repo = "Cangjie/cangjie_runtime"
        preRaw.add(legacy)
        preRaw.add(protected)
        kb.replaceRawRecords(preRaw)

        let firstRunner = CkbReleaseFullRunner(1)
        let first = CkbSchedulerTaskRunner(kb, config, store, sourceRunner: firstRunner).runTask(
            "cangjie_release_full_sync", "0", ckbCoreNowMillis() + 435000)
        @Expect(first.ok, true)
        @Expect(first.status, "candidate_validated_promoted")
        @Expect(firstRunner.networkCalls, 17)
        @Expect(ckbReleaseTestRunnerSawKind(firstRunner, SourceKinds.CANGJIE_DOCS), false)
        @Expect(ckbReleaseTestRunnerSawRepo(firstRunner, "CangjieCommunityKnowledgeBase/Cangjie-HumanEval"), false)
        @Expect(ckbReleaseTestRunnerSawPath(firstRunner, CkbReleaseFullRunner.STABLE_A_PATH), true)
        @Expect(ckbReleaseTestRunnerSawEncodedUrl(firstRunner, "%20"), true)
        @Expect(ckbReleaseTestRunnerSawEncodedUrl(firstRunner, "%3F"), true)
        @Expect(ckbReleaseTestRunnerSawEncodedUrl(firstRunner, "%23"), true)
        @Expect(ckbReleaseTestRunnerSawEncodedUrl(firstRunner, "%26"), true)
        @Expect(ckbReleaseTestRunnerSawEncodedUrl(firstRunner, "%3D"), true)
        @Expect(ckbReleaseTestRunnerSawEncodedUrl(firstRunner, "%3A"), true)
        @Expect(ckbReleaseTestRunnerSawEncodedUrl(firstRunner, "%22"), true)
        @Expect(ckbReleaseTestRunnerSawEncodedUrl(firstRunner, "%2C"), true)

        let firstManifest = store.loadCangjieVersionManifest()
        @Expect(firstManifest.degraded, false)
        @Expect(ckbReleaseTestManifestSource(firstManifest, CangjieSourceSets.EVAL_SUPPORT).sourceRepo,
            "CangjieCommunityKnowledgeBase/Cangjie-HumanEval")
        let firstPlan = ckbBuildReleaseFullSyncPlan(ckbReleaseTestProfile(), firstManifest, "1.0.0")
        @Expect(firstPlan.ok, true)
        let firstSnapshot = store.loadActiveSnapshot()
        @Expect(firstSnapshot.valid, true)
        @Expect(ckbReleaseTestRawContent(firstSnapshot.rawRecords, legacy.sourceId), "")
        @Expect(ckbReleaseTestRawContent(firstSnapshot.rawRecords, protected.sourceId), "protected source event")
        @Expect(firstSnapshot.normalizedRecords.size, firstSnapshot.activeIndex.size)
        @Expect(firstSnapshot.vectorRecords.size, firstSnapshot.activeIndex.size)
        let firstRawIds = ckbReleaseTestP5RawIds(firstSnapshot.rawRecords)
        let firstTypedIds = ckbReleaseTestP5TypedIds(firstSnapshot.activeIndex)
        let firstA = ckbReleaseTestRawByPath(firstSnapshot.rawRecords, CkbReleaseFullRunner.STABLE_A_PATH)
        let firstB = ckbReleaseTestRawByPath(firstSnapshot.rawRecords, CkbReleaseFullRunner.REMOVED_B_PATH)
        let firstATypedId = ckbReleaseTestNormalizedIdByPath(firstSnapshot.activeIndex, CkbReleaseFullRunner.STABLE_A_PATH)
        let firstBTypedId = ckbReleaseTestNormalizedIdByPath(firstSnapshot.activeIndex, CkbReleaseFullRunner.REMOVED_B_PATH)
        let firstEvalIds = ckbReleaseTestTypedIdsForSet(firstSnapshot.activeIndex, CangjieSourceSets.EVAL_SUPPORT)
        @Expect(firstRawIds == "", false)
        @Expect(firstTypedIds == "", false)
        @Expect(firstA.sourceId == "", false)
        @Expect(firstB.sourceId == "", false)
        @Expect(firstATypedId == "", false)
        @Expect(ckbReleaseTestUniqueRawIds(firstSnapshot.rawRecords), true)
        @Expect(ckbReleaseTestUniqueNormalizedIds(firstSnapshot.activeIndex), true)

        let reloadedKb = newOfflineKnowledgeBase()
        @Expect(reloadedKb.restoreActiveSnapshot(firstSnapshot), true)
        let secondRunner = CkbReleaseFullRunner(2)
        let second = CkbSchedulerTaskRunner(reloadedKb, config, store, sourceRunner: secondRunner).runTask(
            "cangjie_release_full_sync", "0", ckbCoreNowMillis() + 435000)
        @Expect(second.ok, true)
        @Expect(second.status, "candidate_validated_promoted")
        @Expect(secondRunner.networkCalls, 17)
        @Expect(second.candidateVersion == first.candidateVersion, false)
        @Expect(second.activeVersion == first.activeVersion, false)

        let secondManifest = store.loadCangjieVersionManifest()
        let secondPlan = ckbBuildReleaseFullSyncPlan(ckbReleaseTestProfile(), secondManifest, "1.0.0")
        @Expect(secondPlan.ok, true)
        @Expect(secondPlan.planHash, firstPlan.planHash)
        @Expect(ckbReleaseTestManifestSource(secondManifest, CangjieSourceSets.EVAL_SUPPORT).sourceRepo,
            "CangjieCommunityKnowledgeBase/Cangjie-HumanEval")
        let secondSnapshot = store.loadActiveSnapshot()
        @Expect(secondSnapshot.valid, true)
        @Expect(secondSnapshot.rawRecords.size, firstSnapshot.rawRecords.size)
        @Expect(secondSnapshot.normalizedRecords.size, firstSnapshot.normalizedRecords.size)
        @Expect(secondSnapshot.activeIndex.size, firstSnapshot.activeIndex.size)
        @Expect(secondSnapshot.vectorRecords.size, firstSnapshot.vectorRecords.size)
        let secondA = ckbReleaseTestRawByPath(secondSnapshot.rawRecords, CkbReleaseFullRunner.STABLE_A_PATH)
        let secondB = ckbReleaseTestRawByPath(secondSnapshot.rawRecords, CkbReleaseFullRunner.REMOVED_B_PATH)
        let secondC = ckbReleaseTestRawByPath(secondSnapshot.rawRecords, CkbReleaseFullRunner.ADDED_C_PATH)
        @Expect(secondA.sourceId, firstA.sourceId)
        @Expect(secondA.contentHash == firstA.contentHash, false)
        @Expect(secondA.content.contains("new-a-token"), true)
        @Expect(secondB.sourceId, "")
        @Expect(secondC.sourceId == "", false)
        @Expect(ckbReleaseTestNormalizedIdByPath(secondSnapshot.activeIndex, CkbReleaseFullRunner.STABLE_A_PATH), firstATypedId)
        @Expect(ckbReleaseTestTypedIdsForSet(secondSnapshot.activeIndex, CangjieSourceSets.EVAL_SUPPORT), firstEvalIds)
        @Expect(ckbReleaseTestSnapshotContains(secondSnapshot, "old-a-token"), false)
        @Expect(ckbReleaseTestSnapshotContains(secondSnapshot, "removed-b-token"), false)
        @Expect(ckbReleaseTestSnapshotContains(secondSnapshot, "new-a-token"), true)
        @Expect(ckbReleaseTestSnapshotContains(secondSnapshot, "new-c-token"), true)
        let expectedRemovedRaw = ArrayList<String>()
        expectedRemovedRaw.add(firstB.sourceId)
        let expectedRemovedNormalized = ArrayList<String>()
        expectedRemovedNormalized.add(firstBTypedId)
        @Expect(ckbReleaseTestDiagnosticsContain(second.validationDiagnostics, "release_reconciliation_removed_raw:count=1|evidenceHash=${ckbReleaseRemovedIdsEvidenceHash(expectedRemovedRaw)}"), true)
        @Expect(ckbReleaseTestDiagnosticsContain(second.validationDiagnostics, "release_reconciliation_removed_normalized:count=1|evidenceHash=${ckbReleaseRemovedIdsEvidenceHash(expectedRemovedNormalized)}"), true)
        let query = QueryService(reloadedKb)
        @Expect(query.query("", "old-a-token", 10).records.size, 0)
        @Expect(query.query("", "removed-b-token", 10).records.size, 0)
        @Expect(query.query("", "new-a-token", 10).records.size > 0, true)
        @Expect(query.query("", "new-c-token", 10).records.size > 0, true)
        @Expect(ckbReleaseTestUniqueRawIds(secondSnapshot.rawRecords), true)
        @Expect(ckbReleaseTestUniqueNormalizedIds(secondSnapshot.activeIndex), true)
        let status = reloadedKb.status()
        @Expect(status.storage.normalizedCount, status.storage.indexCount)
        @Expect(status.storage.vectorIndexCount, status.storage.indexCount)
    }

    @TestCase
    public func p5S3N01AcquisitionFailuresKeepActiveStateAndInvalidUtf8NeverRetries(): Unit {
        let root = "target/p5-s3-n01"
        ckbReleaseTestEnsureEmptyDir(root)
        let evalRoot = "${root}/eval"
        ckbReleaseTestWriteEvalFixture(evalRoot)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.firstInitEvalRoot = evalRoot
        config.firstInitTargetVersion = "1.0.0"
        config.benchmarkGapTargetVersion = "1.0.0"

        for (missingSet in ckbReleaseRequiredSourceSets()) {
            let familyStore = FileKnowledgeStore("${root}/missing-${missingSet}")
            familyStore.saveCangjieVersionManifest(ckbReleaseTestManifestWithout(missingSet))
            let familyBefore = ckbReleaseTestStoreStateEvidence(familyStore)
            let familyKb = newOfflineKnowledgeBase()
            let familyRunner = CkbReleaseFailureRunner("normal")
            let familyResult = CkbSchedulerTaskRunner(familyKb, config, familyStore, sourceRunner: familyRunner).runTask(
                "cangjie_release_full_sync", "0", ckbCoreNowMillis() + 435000)
            @Expect(familyResult.ok, false)
            @Expect(familyResult.status, "required_source_family_missing:${missingSet}")
            @Expect(familyRunner.calls, 0)
            @Expect(ckbReleaseTestStoreStateEvidence(familyStore), familyBefore)
        }

        let missingStore = FileKnowledgeStore("${root}/missing-store")
        let missingManifest = ckbReleaseTestManifestWithout(CangjieSourceSets.TOOLS)
        missingStore.saveCangjieVersionManifest(missingManifest)
        let missingKb = newOfflineKnowledgeBase()
        let missingSentinel = ckbReleaseTestRaw("p5raw-acquisition-sentinel", "sentinel-body", "scheduled:cangjie_release_full_sync")
        let missingRaw = missingKb.rawRecordSnapshot()
        missingRaw.add(missingSentinel)
        missingKb.replaceRawRecords(missingRaw)
        let missingBefore = missingKb.status()
        let missingRunner = CkbReleaseFailureRunner("normal")
        let missing = CkbSchedulerTaskRunner(missingKb, config, missingStore, sourceRunner: missingRunner).runTask(
            "cangjie_release_full_sync", "0", ckbCoreNowMillis() + 435000)
        @Expect(missing.ok, false)
        @Expect(missing.status, "required_source_family_missing:tools")
        @Expect(missingRunner.calls, 0)
        @Expect(missingKb.status().activeKnowledgeVersion, missingBefore.activeKnowledgeVersion)
        @Expect(missingKb.status().storage.indexCount, missingBefore.storage.indexCount)
        @Expect(ckbReleaseTestRawContent(missingKb.rawRecordSnapshot(), missingSentinel.sourceId), "sentinel-body")
        @Expect(cangjieManifestEvidenceHash(missingStore.loadCangjieVersionManifest()), cangjieManifestEvidenceHash(missingManifest))

        let emptyStore = FileKnowledgeStore("${root}/empty-store")
        emptyStore.saveCangjieVersionManifest(ckbReleaseTestManifest())
        let emptyStoreBefore = ckbReleaseTestStoreStateEvidence(emptyStore)
        let emptyKb = newOfflineKnowledgeBase()
        let emptyBefore = emptyKb.status()
        let emptyRunner = CkbReleaseFailureRunner("ineligible")
        let empty = CkbSchedulerTaskRunner(emptyKb, config, emptyStore, sourceRunner: emptyRunner).runTask(
            "cangjie_release_full_sync", "0", ckbCoreNowMillis() + 435000)
        @Expect(empty.ok, false)
        @Expect(empty.status, "release_source_empty")
        @Expect(emptyRunner.calls, 3)
        @Expect(emptyKb.status().activeKnowledgeVersion, emptyBefore.activeKnowledgeVersion)
        @Expect(emptyKb.status().storage.rawCount, emptyBefore.storage.rawCount)
        @Expect(emptyKb.status().storage.indexCount, emptyBefore.storage.indexCount)
        @Expect(ckbReleaseTestStoreStateEvidence(emptyStore), emptyStoreBefore)

        let truncatedStore = FileKnowledgeStore("${root}/truncated-store")
        truncatedStore.saveCangjieVersionManifest(ckbReleaseTestManifest())
        let truncatedStoreBefore = ckbReleaseTestStoreStateEvidence(truncatedStore)
        let truncatedKb = newOfflineKnowledgeBase()
        let truncatedBefore = truncatedKb.status()
        let truncatedRunner = CkbReleaseFailureRunner("truncated")
        let truncated = CkbSchedulerTaskRunner(truncatedKb, config, truncatedStore, sourceRunner: truncatedRunner).runTask(
            "cangjie_release_full_sync", "0", ckbCoreNowMillis() + 435000)
        @Expect(truncated.ok, false)
        @Expect(truncated.status, CkbReleaseAcquisitionStatus.INVENTORY_LIMIT_EXCEEDED)
        @Expect(truncatedRunner.calls, 2)
        @Expect(truncatedKb.status().activeKnowledgeVersion, truncatedBefore.activeKnowledgeVersion)
        @Expect(truncatedKb.status().storage.indexCount, truncatedBefore.storage.indexCount)
        @Expect(ckbReleaseTestStoreStateEvidence(truncatedStore), truncatedStoreBefore)

        let malformedStore = FileKnowledgeStore("${root}/malformed-store")
        malformedStore.saveCangjieVersionManifest(ckbReleaseTestManifest())
        let malformedStoreBefore = ckbReleaseTestStoreStateEvidence(malformedStore)
        let malformedKb = newOfflineKnowledgeBase()
        let malformedBefore = malformedKb.status()
        let malformedRunner = CkbReleaseFailureRunner("malformed_branch")
        let malformed = CkbSchedulerTaskRunner(malformedKb, config, malformedStore, sourceRunner: malformedRunner).runTask(
            "cangjie_release_full_sync", "0", ckbCoreNowMillis() + 435000)
        @Expect(malformed.ok, false)
        @Expect(malformed.status, CkbReleaseAcquisitionStatus.MALFORMED_JSON)
        @Expect(malformedRunner.calls, 1)
        @Expect(malformedKb.status().activeKnowledgeVersion, malformedBefore.activeKnowledgeVersion)
        @Expect(ckbReleaseTestStoreStateEvidence(malformedStore), malformedStoreBefore)

        let unavailableConfig = CkbRuntimeConfig()
        unavailableConfig.networkEnabled = true
        unavailableConfig.firstInitEvalRoot = ""
        unavailableConfig.firstInitTargetVersion = "1.0.0"
        unavailableConfig.benchmarkGapTargetVersion = "1.0.0"
        let unavailableStore = FileKnowledgeStore("${root}/unavailable-eval-store")
        unavailableStore.saveCangjieVersionManifest(ckbReleaseTestManifest())
        let unavailableStoreBefore = ckbReleaseTestStoreStateEvidence(unavailableStore)
        let unavailableKb = newOfflineKnowledgeBase()
        let unavailableBefore = unavailableKb.status()
        let unavailableRunner = CkbReleaseFullRunner(1)
        let unavailable = CkbSchedulerTaskRunner(unavailableKb, unavailableConfig, unavailableStore, sourceRunner: unavailableRunner).runTask(
            "cangjie_release_full_sync", "0", ckbCoreNowMillis() + 435000)
        @Expect(unavailable.ok, false)
        @Expect(unavailable.status, "eval_support_source_unavailable")
        @Expect(unavailableRunner.networkCalls, 17)
        @Expect(unavailableKb.status().activeKnowledgeVersion, unavailableBefore.activeKnowledgeVersion)
        @Expect(ckbReleaseTestStoreStateEvidence(unavailableStore), unavailableStoreBefore)

        let invalidEvalRoot = "${root}/invalid-eval"
        ckbReleaseTestWriteEvalFixture(invalidEvalRoot)
        File.writeTo(Path(invalidEvalRoot).join("CJ-HUMANEVAL-P5-S3/prompt.md"), [UInt8(255), UInt8(254), UInt8(253)])
        let invalidEvalConfig = CkbRuntimeConfig()
        invalidEvalConfig.networkEnabled = true
        invalidEvalConfig.firstInitEvalRoot = invalidEvalRoot
        invalidEvalConfig.firstInitTargetVersion = "1.0.0"
        invalidEvalConfig.benchmarkGapTargetVersion = "1.0.0"
        let invalidEvalStore = FileKnowledgeStore("${root}/invalid-eval-store")
        invalidEvalStore.saveCangjieVersionManifest(ckbReleaseTestManifest())
        let invalidEvalStoreBefore = ckbReleaseTestStoreStateEvidence(invalidEvalStore)
        let invalidEvalKb = newOfflineKnowledgeBase()
        let invalidEvalBefore = invalidEvalKb.status()
        let invalidEval = CkbSchedulerTaskRunner(invalidEvalKb, invalidEvalConfig, invalidEvalStore, sourceRunner: CkbReleaseFullRunner(1)).runTask(
            "cangjie_release_full_sync", "0", ckbCoreNowMillis() + 435000)
        @Expect(invalidEval.ok, false)
        @Expect(invalidEval.status, "eval_support_artifact_invalid_encoding")
        @Expect(invalidEvalKb.status().activeKnowledgeVersion, invalidEvalBefore.activeKnowledgeVersion)
        @Expect(ckbReleaseTestStoreStateEvidence(invalidEvalStore), invalidEvalStoreBefore)

        let validBytes = "中文🙂".toArray()
        let validDecode = ckbNativeHttpDecodeUtf8Bytes(validBytes)
        let invalidDecode = ckbNativeHttpDecodeUtf8Bytes([UInt8(240), UInt8(40), UInt8(140), UInt8(40)])
        @Expect(validDecode[0], true)
        @Expect(validDecode[1], "中文🙂")
        @Expect(invalidDecode[0], false)
        @Expect(invalidDecode[1], "")
        let classified = ckbNativeHttpClassifyException("invalid_response_encoding Authorization: Bearer fixture-secret /Users/private")
        @Expect(classified.transportErrorClass, "invalid_response_encoding")
        @Expect(classified.transportDiagnostic, "invalid_response_encoding")
        let invalidExecutor = CkbInvalidEncodingHttpExecutor()
        let invalidRequest = SourceRequestBuilder().gitCodeOrgRepos("cangjie")
        invalidRequest.retryCount = 3
        let invalidFetch = HttpSourceFetchRunner(config, executor: invalidExecutor).fetch(invalidRequest)
        @Expect(invalidFetch.ok, false)
        @Expect(invalidFetch.statusCode, 0)
        @Expect(invalidFetch.status, "invalid_response_encoding")
        @Expect(invalidFetch.transportErrorClass, "invalid_response_encoding")
        @Expect(invalidFetch.body, "")
        @Expect(invalidFetch.attempts, 1)
        @Expect(invalidExecutor.calls, 1)
    }

    @TestCase
    public func p5S3E2EAServiceSchedulerRunsFiveSourceReleaseEndToEndWithoutRealNetwork(): Unit {
        let root = "target/p5-s3-e2e-a"
        ckbReleaseTestEnsureEmptyDir(root)
        let evalRoot = "${root}/eval"
        ckbReleaseTestWriteEvalFixture(evalRoot)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.firstInitEvalRoot = evalRoot
        config.firstInitTargetVersion = "1.0.0"
        config.benchmarkGapTargetVersion = "1.0.0"
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(ckbReleaseTestManifest())
        let runner = CkbReleaseFullRunner(2)
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_release_full_sync")

        let run = service.runSchedulerTasks(tasks, true)

        @Expect(run.ran, 1)
        @Expect(run.succeeded, 1)
        @Expect(run.failed, 0)
        @Expect(run.degraded, 0)
        @Expect(run.details.contains("candidate_validated_promoted"), true)
        @Expect(runner.networkCalls, 17)
        @Expect(ckbReleaseTestRunnerSawKind(runner, SourceKinds.CANGJIE_DOCS), false)
        @Expect(ckbReleaseTestRunnerSawRepo(runner, "CangjieCommunityKnowledgeBase/Cangjie-HumanEval"), false)
        let snapshot = store.loadActiveSnapshot()
        @Expect(snapshot.valid, true)
        @Expect(snapshot.rawRecords.size > 0, true)
        @Expect(snapshot.normalizedRecords.size, snapshot.activeIndex.size)
        @Expect(snapshot.vectorRecords.size, snapshot.activeIndex.size)
        @Expect(ckbReleaseTestHasAllP5SourceSets(snapshot.activeIndex), true)
        @Expect(ckbReleaseTestSnapshotContains(snapshot, "new-a-token"), true)
        @Expect(ckbReleaseTestSnapshotContains(snapshot, "new-c-token"), true)
        @Expect(ckbReleaseTestSnapshotContains(snapshot, "\"type\":\"blob\""), false)
        @Expect(ckbReleaseTestSnapshotContains(snapshot, "\"commit\":{\"id\""), false)
        @Expect(ckbReleaseTestVectorContains(snapshot.vectorRecords, "\"type\":\"blob\""), false)
        @Expect(ckbReleaseTestVectorContains(snapshot.vectorRecords, "\"commit\":{\"id\""), false)
        @Expect(ckbBuildReleaseFullSyncPlan(ckbReleaseTestProfile(), store.loadCangjieVersionManifest(), "1.0.0").ok, true)
    }
}

private class CkbReleaseFullRunner <: SourceFetchRunner {
    public static let STABLE_A_PATH: String = "docs/API ?#&=:路径🙂,\"quote\" A.md"
    public static let REMOVED_B_PATH: String = "docs/removed-B.md"
    public static let ADDED_C_PATH: String = "docs/added-C.md"

    var calls: ArrayList<SourceFetchRequest> = ArrayList<SourceFetchRequest>()
    var networkCalls: Int64 = 0
    let generation: Int64

    init(generation: Int64) {
        this.generation = generation
    }

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        this.calls.add(request)
        this.networkCalls += 1
        let result = SourceFetchResult()
        result.sourceUrl = request.url
        result.repo = request.repo
        result.ref = request.ref
        result.path = request.path
        result.normalizedType = request.kind
        result.attempts = 1
        result.ok = true
        result.status = "ok"
        result.statusCode = 200
        if (request.kind == SourceKinds.GITCODE_BRANCH) {
            result.contentType = "application/json"
            result.body = "[{\"name\":\"release-1.0.0\",\"commit\":{\"id\":\"0123456789abcdef0123456789abcdef01234567\"}}]"
        } else if (request.kind == SourceKinds.GITCODE_TREE) {
            result.contentType = "application/json"
            result.body = if (request.page == 1) { this.treeBody(request.repo) } else { "[]" }
        } else if (request.kind == SourceKinds.GITCODE_SOURCE) {
            result.contentType = if (request.path.endsWith(".cj")) { "text/plain" } else { "text/markdown" }
            result.body = this.contentBody(request.repo, request.path)
            result.commit = "0123456789abcdef0123456789abcdef01234567"
        }
        result
    }

    private func treeBody(repo: String): String {
        if (repo == "Cangjie/cangjie_docs") {
            let second = if (this.generation == 1) { CkbReleaseFullRunner.REMOVED_B_PATH } else { CkbReleaseFullRunner.ADDED_C_PATH }
            return "[{\"path\":\"${ckbScheduledFetchJsonEscape(CkbReleaseFullRunner.STABLE_A_PATH)}\",\"type\":\"blob\"},{\"path\":\"${ckbScheduledFetchJsonEscape(second)}\",\"type\":\"blob\"}]"
        }
        let path = if (repo == "Cangjie/cangjie_runtime") {
            "src/runtime_fixture.cj"
        } else if (repo == "Cangjie/cangjie_stdx") {
            "src/stdx_fixture.cj"
        } else {
            "tools/guide.md"
        }
        "[{\"path\":\"${ckbScheduledFetchJsonEscape(path)}\",\"type\":\"blob\"}]"
    }

    private func contentBody(repo: String, path: String): String {
        if (repo == "Cangjie/cangjie_docs") {
            if (path == CkbReleaseFullRunner.STABLE_A_PATH) {
                return "# Stable A\n${if (this.generation == 1) { "old-a-token" } else { "new-a-token" }}\n"
            }
            if (path == CkbReleaseFullRunner.REMOVED_B_PATH) {
                return "# Removed B\nremoved-b-token\n"
            }
            return "# Added C\nnew-c-token\n"
        }
        if (repo == "Cangjie/cangjie_runtime") {
            return "package runtime_fixture\npublic func runtimeFixture(): Unit {}\n"
        }
        if (repo == "Cangjie/cangjie_stdx") {
            return "package stdx_fixture\npublic func stdxFixture(): Unit {}\n"
        }
        if (repo == "Cangjie/cangjie_tools") {
            return "# cjpm test\nRun cjpm clean, cjpm build -i, and cjpm test.\n"
        }
        "# Cangjie API 路径🙂\nArrayList and HashMap are standard collections.\n"
    }
}

private class CkbReleaseFailureRunner <: SourceFetchRunner {
    let mode: String
    var calls: Int64 = 0

    init(mode: String) {
        this.mode = mode
    }

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        this.calls += 1
        let result = SourceFetchResult()
        result.sourceUrl = request.url
        result.repo = request.repo
        result.ref = request.ref
        result.path = request.path
        result.normalizedType = request.kind
        result.attempts = 1
        result.ok = true
        result.status = "ok"
        result.statusCode = 200
        if (request.kind == SourceKinds.GITCODE_BRANCH) {
            result.contentType = "application/json"
            result.body = if (this.mode == "malformed_branch") {
                "{malformed"
            } else {
                "[{\"name\":\"release-1.0.0\",\"commit\":{\"id\":\"0123456789abcdef0123456789abcdef01234567\"}}]"
            }
        } else if (request.kind == SourceKinds.GITCODE_TREE) {
            result.contentType = "application/json"
            if (this.mode == "truncated") {
                result.ok = false
                result.status = "server_error"
                result.statusCode = 500
                result.truncated = true
                result.body = "truncated tree response"
            } else if (this.mode == "ineligible") {
                result.body = if (request.page == 1) { "[{\"path\":\"assets/logo.png\",\"type\":\"blob\"}]" } else { "[]" }
            } else {
                result.body = if (request.page == 1) { "[{\"path\":\"docs/a.md\",\"type\":\"blob\"}]" } else { "[]" }
            }
        } else if (request.kind == SourceKinds.GITCODE_SOURCE) {
            result.contentType = "text/markdown"
            result.body = "# fixture\ncontent\n"
            result.commit = "0123456789abcdef0123456789abcdef01234567"
        }
        result
    }
}

private class CkbReleaseContentsFailureRunner <: SourceFetchRunner {
    let mode: String

    init(mode: String) {
        this.mode = mode
    }

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        let result = SourceFetchResult()
        result.sourceUrl = request.url
        result.repo = request.repo
        result.ref = request.ref
        result.path = request.path
        result.normalizedType = request.kind
        result.attempts = 1
        if (request.kind == SourceKinds.GITCODE_BRANCH) {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.contentType = "application/json"
            result.body = "[{\"name\":\"release-1.0.0\",\"commit\":{\"id\":\"0123456789abcdef0123456789abcdef01234567\"}}]"
        } else if (request.kind == SourceKinds.GITCODE_TREE) {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.contentType = "application/json"
            result.body = if (request.page == 1) { "[{\"path\":\"docs/a.md\",\"type\":\"blob\"}]" } else { "[]" }
        } else if (request.kind == SourceKinds.GITCODE_SOURCE && request.sourceVariant == "raw") {
            result.ok = false
            result.status = "not_found"
            result.statusCode = 404
            result.contentType = "text/plain"
            result.body = "raw unavailable"
        } else if (request.kind == SourceKinds.GITCODE_SOURCE) {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.contentType = "application/json"
            result.body = if (this.mode == "malformed") {
                "{malformed"
            } else if (this.mode == "invalid_utf8") {
                "{\"type\":\"file\",\"path\":\"docs/a.md\",\"encoding\":\"base64\",\"content\":\"/w==\",\"sha\":\"0123456789abcdef0123456789abcdef01234567\"}"
            } else {
                "{\"type\":\"file\",\"path\":\"docs/a.md\",\"encoding\":\"base64\",\"content\":\"AAE=\",\"sha\":\"0123456789abcdef0123456789abcdef01234567\"}"
            }
        }
        result
    }
}

private class CkbInvalidEncodingHttpExecutor <: HttpRequestExecutor {
    var calls: Int64 = 0

    public func execute(request: HttpExecutionRequest): HttpExecutionResponse {
        this.calls += 1
        let response = HttpExecutionResponse()
        if (this.calls == 1) {
            response.status = "invalid_response_encoding"
            response.statusCode = 0
            response.body = ""
            response.transportErrorClass = "invalid_response_encoding"
            response.transportDiagnostic = "invalid_response_encoding"
        } else {
            response.status = "http_200"
            response.statusCode = 200
            response.body = "[]"
            response.contentType = "application/json"
        }
        response
    }

    public func get(request: HttpExecutionRequest): HttpExecutionResponse {
        this.execute(request)
    }
}

private class CkbReleaseBoundaryRunner <: SourceFetchRunner {
    let nonEmptyPages: Int64
    let filesPerPage: Int64
    let content: String
    var pathPrefix: String = "docs/路径🙂"

    init(nonEmptyPages: Int64, filesPerPage: Int64, content: String) {
        this.nonEmptyPages = nonEmptyPages
        this.filesPerPage = filesPerPage
        this.content = content
    }

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        let result = SourceFetchResult()
        result.sourceUrl = request.url
        result.repo = request.repo
        result.ref = request.ref
        result.path = request.path
        result.normalizedType = request.kind
        result.attempts = 1
        result.statusCode = 200
        result.status = "ok"
        result.ok = true
        if (request.kind == SourceKinds.GITCODE_BRANCH) {
            result.contentType = "application/json"
            result.body = "[{\"name\":\"release-1.0.0\",\"commit\":{\"id\":\"0123456789abcdef0123456789abcdef01234567\"}}]"
        } else if (request.kind == SourceKinds.GITCODE_TREE) {
            result.contentType = "application/json"
            result.body = this.treeBody(request.page)
        } else if (request.kind == SourceKinds.GITCODE_SOURCE) {
            result.contentType = "text/markdown"
            result.body = this.content
            result.commit = "0123456789abcdef0123456789abcdef01234567"
        }
        result
    }

    private func treeBody(page: Int64): String {
        if (page > this.nonEmptyPages) { return "[]" }
        let body = StringBuilder()
        body.append("[")
        for (i in 0..this.filesPerPage) {
            if (i > 0) { body.append(",") }
            body.append("{\"path\":\"")
            body.append(ckbScheduledFetchJsonEscape("${this.pathPrefix}-${page}-${i}.md"))
            body.append("\",\"type\":\"blob\"}")
        }
        body.append("]")
        body.toString()
    }
}

private class CkbReleaseThreePageRunner <: SourceFetchRunner {
    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        let result = SourceFetchResult()
        result.sourceUrl = request.url
        result.repo = request.repo
        result.ref = request.ref
        result.path = request.path
        result.normalizedType = request.kind
        result.attempts = 1
        result.ok = true
        result.status = "ok"
        result.statusCode = 200
        if (request.kind == SourceKinds.GITCODE_BRANCH) {
            result.contentType = "application/json"
            result.body = "[{\"name\":\"release-1.0.0\",\"commit\":{\"id\":\"0123456789abcdef0123456789abcdef01234567\"}}]"
        } else if (request.kind == SourceKinds.GITCODE_TREE) {
            result.contentType = "application/json"
            result.body = if (request.page <= 3) {
                "[{\"path\":\"${ckbScheduledFetchJsonEscape(this.path(request.repo, request.page))}\",\"type\":\"blob\"}]"
            } else {
                "[]"
            }
        } else if (request.kind == SourceKinds.GITCODE_SOURCE) {
            result.contentType = if (request.path.endsWith(".cj")) { "text/plain" } else { "text/markdown" }
            result.body = if (request.path.endsWith(".cj")) {
                "package three_page\npublic func page${request.path.size}(): Unit {}\n"
            } else {
                "# Page ${request.path}\nthree-page-content\n"
            }
            result.commit = "0123456789abcdef0123456789abcdef01234567"
        }
        result
    }

    private func path(repo: String, page: Int64): String {
        if (repo == "Cangjie/cangjie_runtime" || repo == "Cangjie/cangjie_stdx") {
            return "src/page-${page}.cj"
        }
        if (repo == "Cangjie/cangjie_tools") {
            return "tools/page-${page}.md"
        }
        "docs/page-${page}.md"
    }
}

private class CkbP4SampleRunner <: SourceFetchRunner {
    var treePage2Calls: Int64 = 0
    var sourceCalls: Int64 = 0

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        let result = SourceFetchResult()
        result.sourceUrl = request.url
        result.repo = request.repo
        result.ref = request.ref
        result.path = request.path
        result.normalizedType = request.kind
        result.attempts = 1
        result.ok = true
        result.status = "ok"
        result.statusCode = 200
        if (request.kind == SourceKinds.GITCODE_BRANCH) {
            result.contentType = "application/json"
            result.body = "[{\"name\":\"release-1.0.0\",\"commit\":{\"id\":\"0123456789abcdef0123456789abcdef01234567\"}}]"
        } else if (request.kind == SourceKinds.GITCODE_TREE) {
            result.contentType = "application/json"
            if (request.page == 2) { this.treePage2Calls += 1 }
            let body = StringBuilder()
            body.append("[")
            for (i in 0..6) {
                if (i > 0) { body.append(",") }
                body.append("{\"path\":\"docs/sample-${i}.md\",\"type\":\"blob\"}")
            }
            body.append("]")
            result.body = body.toString()
        } else if (request.kind == SourceKinds.GITCODE_SOURCE) {
            this.sourceCalls += 1
            result.contentType = "text/markdown"
            result.body = "# P4 sample\ncontent\n"
            result.commit = "0123456789abcdef0123456789abcdef01234567"
        } else if (request.kind == SourceKinds.CANGJIE_DOCS) {
            result.contentType = "text/html"
            result.body = "<h1>fixture docs</h1>"
        }
        result
    }
}

private func ckbReleaseTestRemoteRun(root: String, source: CkbReleaseSourcePlan, profile: CkbScheduleTaskProfile, config: CkbRuntimeConfig, builder: SourceRequestBuilder, runner: SourceFetchRunner): (CkbScheduledProfileFetchResult, CkbReleaseSourceInventory) {
    ckbReleaseTestEnsureEmptyDir(root)
    let result = CkbScheduledProfileFetchResult()
    let inventory = ckbReleaseInventoryForSource(source)
    result.releaseInventories.add(inventory)
    ckbFetchReleaseRemoteSource(runner, builder, source, profile, result, inventory, config, FileKnowledgeStore("${root}/store"))
    (result, inventory)
}

private func ckbReleaseTestProfile(): CkbScheduleTaskProfile {
    ckbSyncProfileForScheduleTask("cangjie_release_full_sync")
}

private func ckbReleaseTestManifest(): CangjieVersionManifest {
    let manifest = CangjieVersionManifest()
    manifest.defaultTargetVersion = "1.0.0"
    ckbReleaseTestAddSource(manifest, CangjieSourceSets.DOCS, "docs", "Cangjie/cangjie_docs")
    ckbReleaseTestAddSource(manifest, CangjieSourceSets.STD, "stdlib", "Cangjie/cangjie_runtime")
    ckbReleaseTestAddSource(manifest, CangjieSourceSets.STDX, "stdx", "Cangjie/cangjie_stdx")
    ckbReleaseTestAddSource(manifest, CangjieSourceSets.TOOLS, "tools", "Cangjie/cangjie_tools")
    ckbReleaseTestAddSource(manifest, CangjieSourceSets.EVAL_SUPPORT, "eval-support", "CangjieCommunityKnowledgeBase/Cangjie-HumanEval")
    manifest
}

private func ckbReleaseTestManifestWithout(excludedSourceSet: String): CangjieVersionManifest {
    let source = ckbReleaseTestManifest()
    let out = CangjieVersionManifest()
    out.defaultTargetVersion = source.defaultTargetVersion
    for (item in source.sources) {
        if (item.sourceSet != excludedSourceSet) { out.sources.add(item) }
    }
    out
}

private func ckbReleaseTestAddSource(manifest: CangjieVersionManifest, sourceSet: String, family: String, repo: String): Unit {
    let source = CangjieVersionSource()
    source.targetVersion = "1.0.0"
    source.sourceSet = sourceSet
    source.sourceFamily = family
    source.sourceRepo = repo
    source.sourceRef = "release-1.0.0"
    source.refKind = "branch"
    source.resolvedCommit = "offline-${sourceSet}"
    source.contentHash = "sha256:${sourceSet}"
    manifest.sources.add(source)
}

private func ckbReleaseTestManifestSource(manifest: CangjieVersionManifest, sourceSet: String): CangjieVersionSource {
    for (source in manifest.sources) {
        if (source.sourceSet == sourceSet) { return source }
    }
    CangjieVersionSource()
}

private func ckbReleaseTestPlanSource(plan: CkbReleaseFullSyncPlan, sourceSet: String): CkbReleaseSourcePlan {
    for (source in plan.sources) {
        if (source.sourceSet == sourceSet) { return source }
    }
    CkbReleaseSourcePlan()
}

private func ckbReleaseTestTyped(heading: String, content: String): CangjieTypedRecord {
    let record = CangjieTypedRecord()
    record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    record.heading = heading
    record.content = content
    record
}

private func ckbReleaseTestFetch(body: String, commit: String): SourceFetchResult {
    let fetch = SourceFetchResult()
    fetch.ok = true
    fetch.status = "ok"
    fetch.statusCode = 200
    fetch.body = body
    fetch.bodyHash = ckbReleaseEvidenceHash(body)
    fetch.sourceUrl = "https://fixture.invalid/source"
    fetch.repo = "Fixture/repo"
    fetch.ref = "release-1.0.0"
    fetch.path = "src/a.cj"
    fetch.commit = commit
    fetch
}

private func ckbReleaseTestRaw(sourceId: String, content: String, owner: String): RawRecord {
    let raw = RawRecord()
    raw.sourceId = sourceId
    raw.content = content
    raw.contentHash = ckbReleaseEvidenceHash(content)
    raw.metadata.sourceId = sourceId
    raw.metadata.crawlAt = owner
    raw.metadata.targetVersion = "1.0.0"
    raw
}

private func ckbReleaseTestRawContent(records: ArrayList<RawRecord>, sourceId: String): String {
    for (record in records) {
        if (record.sourceId == sourceId) { return record.content }
    }
    ""
}

private func ckbReleaseTestLongPath(repeatCount: Int64): String {
    let out = StringBuilder()
    out.append("docs/")
    for (_ in 0..repeatCount) { out.append("路径🙂") }
    out.append(".md")
    out.toString()
}

private func ckbReleaseTestDiagnosticsContain(values: ArrayList<String>, needle: String): Bool {
    for (value in values) {
        if (value.contains(needle)) { return true }
    }
    false
}

private func ckbReleaseTestJoin(values: ArrayList<String>): String {
    let out = StringBuilder()
    for (value in values) {
        out.append(value)
        out.append("\n")
    }
    out.toString()
}

private func ckbReleaseTestWriteEvalFixture(root: String): Unit {
    let caseRoot = Path(root).join("CJ-HUMANEVAL-P5-S3")
    Directory.create(caseRoot.join("starter/src"), recursive: true)
    Directory.create(caseRoot.join("tests"), recursive: true)
    File.writeTo(caseRoot.join("prompt.md"), "# Prompt 中文🙂\nImplement the visible fixture.\n".toArray())
    File.writeTo(caseRoot.join("metadata.json"), "{\"id\":\"CJ-HUMANEVAL-P5-S3\"}\n".toArray())
    File.writeTo(caseRoot.join("starter/src/eval_support.cj"), "package fixture\npublic class EvalValue {}\npublic class EvalEntry {}\n".toArray())
    File.writeTo(caseRoot.join("tests/TestMain.cj"), "package fixture\npublic class VisibleTestHelper {}\n".toArray())
}

private func ckbReleaseTestRunnerSawKind(runner: CkbReleaseFullRunner, kind: String): Bool {
    for (request in runner.calls) {
        if (request.kind == kind) { return true }
    }
    false
}

private func ckbReleaseTestRunnerSawRepo(runner: CkbReleaseFullRunner, repo: String): Bool {
    for (request in runner.calls) {
        if (request.repo == repo) { return true }
    }
    false
}

private func ckbReleaseTestRunnerSawPath(runner: CkbReleaseFullRunner, path: String): Bool {
    for (request in runner.calls) {
        if (request.path == path) { return true }
    }
    false
}

private func ckbReleaseTestRunnerSawEncodedUrl(runner: CkbReleaseFullRunner, fragment: String): Bool {
    for (request in runner.calls) {
        if (request.path == CkbReleaseFullRunner.STABLE_A_PATH && request.url.contains(fragment)) { return true }
    }
    false
}

private func ckbReleaseTestP5RawIds(records: ArrayList<RawRecord>): String {
    let ids = ArrayList<String>()
    for (record in records) {
        if (record.sourceId.startsWith("p5raw-")) { ids.add(record.sourceId) }
    }
    let ordered = ids.toArray()
    sort(ordered)
    ckbReleaseTestJoinIdArray(ordered)
}

private func ckbReleaseTestP5TypedIds(records: ArrayList<NormalizedRecord>): String {
    let ids = ArrayList<String>()
    for (record in records) {
        if (record.sourceId.startsWith("p5typed-")) { ids.add(record.sourceId) }
    }
    let ordered = ids.toArray()
    sort(ordered)
    ckbReleaseTestJoinIdArray(ordered)
}

private func ckbReleaseTestJoinIdArray(values: Array<String>): String {
    let out = StringBuilder()
    for (value in values) {
        if (out.toString() != "") { out.append(",") }
        out.append(value)
    }
    out.toString()
}

private func ckbReleaseTestUniqueRawIds(records: ArrayList<RawRecord>): Bool {
    let ids = HashSet<String>()
    for (record in records) {
        if (record.sourceId == "" || ids.contains(record.sourceId)) { return false }
        ids.add(record.sourceId)
    }
    true
}

private func ckbReleaseTestUniqueNormalizedIds(records: ArrayList<NormalizedRecord>): Bool {
    let ids = HashSet<String>()
    for (record in records) {
        if (record.sourceId == "" || ids.contains(record.sourceId)) { return false }
        ids.add(record.sourceId)
    }
    true
}

private func ckbReleaseTestRawByPath(records: ArrayList<RawRecord>, path: String): RawRecord {
    for (record in records) {
        if (record.sourceId.startsWith("p5raw-") && record.metadata.path == path) { return record }
    }
    RawRecord()
}

private func ckbReleaseTestNormalizedIdByPath(records: ArrayList<NormalizedRecord>, path: String): String {
    for (record in records) {
        if (record.sourceId.startsWith("p5typed-") && record.metadata.path == path) { return record.sourceId }
    }
    ""
}

private func ckbReleaseTestTypedIdsForSet(records: ArrayList<NormalizedRecord>, sourceSet: String): String {
    let ids = ArrayList<String>()
    for (record in records) {
        if (record.sourceId.startsWith("p5typed-") && record.metadata.sourceSet == sourceSet) { ids.add(record.sourceId) }
    }
    let ordered = ids.toArray()
    sort(ordered)
    ckbReleaseTestJoinIdArray(ordered)
}

private func ckbReleaseTestSnapshotContains(snapshot: ActiveSnapshot, needle: String): Bool {
    for (record in snapshot.rawRecords) {
        if (record.content.contains(needle)) { return true }
    }
    for (record in snapshot.activeIndex) {
        if (record.chunk.contains(needle)) { return true }
    }
    false
}

private func ckbReleaseTestVectorContains(records: ArrayList<VectorRecord>, needle: String): Bool {
    for (record in records) {
        if (record.title.contains(needle) || record.chunk.contains(needle) || record.citation.contains(needle)) { return true }
    }
    false
}

private func ckbReleaseTestHasAllP5SourceSets(records: ArrayList<NormalizedRecord>): Bool {
    let sets = HashSet<String>()
    for (record in records) {
        if (record.sourceId.startsWith("p5typed-")) { sets.add(record.metadata.sourceSet) }
    }
    sets.contains(CangjieSourceSets.DOCS) &&
        sets.contains(CangjieSourceSets.STD) &&
        sets.contains(CangjieSourceSets.STDX) &&
        sets.contains(CangjieSourceSets.TOOLS) &&
        sets.contains(CangjieSourceSets.EVAL_SUPPORT)
}

private func ckbReleaseTestStoreStateEvidence(store: FileKnowledgeStore): String {
    let manifest = store.readText("metadata/cangjie-version-manifest.ckb")
    let freshness = store.readText("metadata/cangjie-freshness.ckb")
    "manifest=${ckbReleaseEvidenceHash(manifest)}|freshness=${ckbReleaseEvidenceHash(freshness)}"
}

private func ckbReleaseTestScheduledRecordsHaveAllSets(records: ArrayList<CkbScheduledSourceRecord>): Bool {
    let sets = HashSet<String>()
    for (record in records) { sets.add(record.sourceSet) }
    sets.contains(CangjieSourceSets.DOCS) && sets.contains(CangjieSourceSets.STD) &&
        sets.contains(CangjieSourceSets.STDX) && sets.contains(CangjieSourceSets.TOOLS) &&
        sets.contains(CangjieSourceSets.EVAL_SUPPORT)
}

private func ckbReleaseTestInventoriesExactAndComplete(inventories: ArrayList<CkbReleaseSourceInventory>): Bool {
    for (inventory in inventories) {
        if (!inventory.complete || !inventory.explicitEnd || inventory.plannedPaths.size == 0 || inventory.plannedPaths.size != inventory.completedPaths.size) {
            return false
        }
        for (path in inventory.plannedPaths) {
            if (!inventory.completedPathSet.contains(path)) { return false }
        }
    }
    true
}

private func ckbReleaseTestRemoteInventoriesHaveThreePages(inventories: ArrayList<CkbReleaseSourceInventory>): Bool {
    for (inventory in inventories) {
        if (inventory.sourceSet == CangjieSourceSets.EVAL_SUPPORT) { continue }
        if (inventory.nonEmptyPages != 3 || inventory.pagesScanned != 4 || inventory.plannedPaths.size != 3) { return false }
    }
    true
}

private func ckbReleaseTestContentHasNoControlRecords(records: ArrayList<CkbScheduledSourceRecord>): Bool {
    for (record in records) {
        if (!record.fetch.ok || record.request.kind != SourceKinds.GITCODE_SOURCE || record.request.purpose == "source_tree" || record.request.purpose == "branch_list" || record.request.purpose == "branch_ref") {
            return false
        }
    }
    true
}

private func ckbReleaseTestControlEvidenceHasRefAndTree(evidence: ArrayList<CkbReleaseControlEvidence>): Bool {
    var refSeen = false
    var treeSeen = false
    for (item in evidence) {
        if (item.kind == "ref_resolution") { refSeen = true }
        if (item.kind == "tree_page") { treeSeen = true }
    }
    refSeen && treeSeen
}

private func ckbReleaseTestEnsureEmptyDir(path: String): Unit {
    if (exists(Path(path))) {
        _ = launch("/bin/rm", ["-rf", path]).wait()
    }
    Directory.create(Path(path), recursive: true)
}
