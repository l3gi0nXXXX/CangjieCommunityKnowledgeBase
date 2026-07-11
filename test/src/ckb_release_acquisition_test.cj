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

    @TestCase
    public func p5S5U01PreparedBundleUsesSingleRefreshedManifestAndBoundedEvidence(): Unit {
        let fixture = ckbS5ReleaseFixture("target/p5-s5-u01", 1)
        @Expect(fixture.task.ok, true)
        let firstPointer = fixture.store.loadActiveSnapshotPointer()
        let firstManifest = fixture.store.loadActiveCangjieVersionManifest()
        let second = CkbSchedulerTaskRunner(fixture.kb, fixture.config, fixture.store,
            sourceRunner: CkbReleaseFullRunner(2)).runTask(
            "cangjie_release_full_sync", "0", ckbCoreNowMillis() + 435000)
        let pointer = fixture.store.loadActiveSnapshotPointer()
        let manifest = fixture.store.loadActiveCangjieVersionManifest()
        let freshness = fixture.store.loadActiveCangjieCorpusFreshness()
        let snapshot = fixture.store.loadActiveSnapshot()
        let txRoot = "transactions/${pointer.txId}"

        @Expect(second.ok, true)
        @Expect(pointer.valid, true)
        @Expect(pointer.txId == firstPointer.txId, false)
        @Expect(pointer.companionMode, CkbActiveSnapshotCompanionMode.RELEASE)
        @Expect(pointer.manifestHash, ckbReleaseCompanionEvidenceHash(
            fixture.store.readText("${txRoot}/metadata/cangjie-version-manifest.ckb")))
        @Expect(pointer.freshnessHash, ckbReleaseCompanionEvidenceHash(
            fixture.store.readText("${txRoot}/metadata/cangjie-freshness.ckb")))
        @Expect(pointer.coverageHash, ckbReleaseCompanionEvidenceHash(
            fixture.store.readText("${txRoot}/metadata/cangjie-release-coverage.ckb")))
        @Expect(manifest.sources.size, 5)
        @Expect(freshness.sources.size, 5)
        @Expect(manifest.diagnostics.size <= 64, true)
        @Expect(firstManifest.manifestVersion, CangjieVersionManifestVersions.V2)
        @Expect(manifest.manifestVersion, CangjieVersionManifestVersions.V2)
        for (source in manifest.sources) {
            if (source.sourceSet != CangjieSourceSets.EVAL_SUPPORT) {
                @Expect(source.resolvedCommit, "2222222222222222222222222222222222222222")
            }
        }
        for (record in snapshot.activeIndex) {
            if (record.sourceId.startsWith("p5typed-") &&
                record.metadata.sourceSet != CangjieSourceSets.EVAL_SUPPORT) {
                let selector = cangjieVersionSelector(targetVersion: "1.0.0",
                    sourceSet: record.metadata.sourceSet)
                let expectedB = resolveCangjieVersion(selector, manifest).versionResolutionId
                let oldA = resolveCangjieVersion(selector, firstManifest).versionResolutionId
                let selectedB = ckbReleaseTestManifestSource(manifest,
                    record.metadata.sourceSet)
                @Expect(record.metadata.commit, "2222222222222222222222222222222222222222")
                @Expect(record.metadata.commit, selectedB.resolvedCommit)
                @Expect(record.metadata.commit.contains("1111111111111111"), false)
                @Expect(record.metadata.versionResolutionId, expectedB)
                @Expect(record.metadata.versionResolutionId == oldA, false)
            }
        }

        let docsSelector = cangjieVersionSelector(targetVersion: "1.0.0",
            sourceSet: CangjieSourceSets.DOCS)
        let activeDocsResolution = resolveCangjieVersion(docsSelector, manifest)
        let consumer = CkbCommandLoopService(fixture.config, fixture.store,
            sourceRunner: DisabledNetworkFetchRunner())
        @Expect(consumer.cangjieResolveVersion(docsSelector).versionResolutionId,
            activeDocsResolution.versionResolutionId)
        let strictRequest = CangjieServingSearchRequest()
        strictRequest.query = "new-a-token"
        strictRequest.sourceSet = CangjieSourceSets.DOCS
        strictRequest.targetVersion = "1.0.0"
        strictRequest.versionResolutionId = activeDocsResolution.versionResolutionId
        strictRequest.budget = 5
        let strictV2 = searchHybridServingIndex(buildCangjieServingIndex(snapshot.activeIndex,
            activeKnowledgeVersion: pointer.activeVersion), strictRequest)
        @Expect(strictV2.hits.size > 0, true)

        let v1Manifest = ckbReleaseTestManifest()
        let v1Resolution = resolveCangjieVersion(docsSelector, v1Manifest)
        var v1Seed = "${v1Resolution.targetVersion}:${v1Resolution.versionPolicy}:${v1Resolution.diagnostic}"
        for (source in v1Resolution.sources) {
            v1Seed += "|${source.sourceSet}:${source.sourceRepo}:${source.sourceRef}:${source.resolvedCommit}:${source.contentHash}"
        }
        @Expect(v1Manifest.manifestVersion, CangjieVersionManifestVersions.V1)
        @Expect(v1Resolution.versionResolutionId,
            "cangjie-version-${stableSummaryHash(v1Seed)}")
        let legacyRoot = "target/p5-s5-u01-v1-persisted"
        ckbReleaseTestEnsureEmptyDir(legacyRoot)
        let legacyStore = FileKnowledgeStore(legacyRoot)
        let legacyRaw = RawRecord()
        legacyRaw.sourceId = "legacy-v1-doc"
        legacyRaw.title = "Legacy V1 document"
        legacyRaw.content = "legacy-v1-token"
        legacyRaw.contentHash = ckbReleaseEvidenceHash(legacyRaw.content)
        legacyRaw.metadata.sourceId = legacyRaw.sourceId
        legacyRaw.metadata.sourceType = SourceTypes.DOC
        legacyRaw.metadata.sourceSet = CangjieSourceSets.DOCS
        legacyRaw.metadata.targetVersion = "1.0.0"
        legacyRaw.metadata.versionResolutionId = v1Resolution.versionResolutionId
        legacyRaw.metadata.knowledgeVersion = "legacy-v1-active"
        legacyRaw.metadata.commit = v1Resolution.sources[0].resolvedCommit
        legacyRaw.metadata.trustLevel = TrustLevels.OFFICIAL
        legacyRaw.metadata.reviewState = ReviewStates.TRUSTED
        let legacyRecord = NormalizedRecord()
        legacyRecord.sourceId = legacyRaw.sourceId
        legacyRecord.recordKind = CangjieTypedRecordKinds.DOC_SECTION
        legacyRecord.title = legacyRaw.title
        legacyRecord.chunk = legacyRaw.content
        legacyRecord.citation = "legacy-v1-doc"
        legacyRecord.metadata = legacyRaw.metadata
        let legacyRawRecords = ArrayList<RawRecord>()
        legacyRawRecords.add(legacyRaw)
        let legacyRecords = ArrayList<NormalizedRecord>()
        legacyRecords.add(legacyRecord)
        let legacyStatus = KnowledgeStatus()
        legacyStatus.activeKnowledgeVersion = "legacy-v1-active"
        legacyStatus.storage.rawCount = 1
        legacyStatus.storage.normalizedCount = 1
        legacyStatus.storage.indexCount = 1
        legacyStatus.storage.textIndexCount = 1
        legacyStatus.storage.vectorActiveCollection = "legacy-v1-vector"
        let legacyTx = legacyStore.writeActiveSnapshotTransaction(legacyStatus,
            legacyRawRecords, legacyRecords, legacyRecords, ArrayList<VectorRecord>(),
            "legacy-v1-vector", GraphBuildResult(), persistVectorFile: false)
        @Expect(legacyTx.ok, true)
        let legacyLoaded = newKnowledgeBaseFromStore(legacyStore)
        @Expect(legacyLoaded.source, "persisted")
        let strictV1 = lookupDocSection(buildCangjieServingIndex(
            legacyLoaded.kb.activeRecordSnapshot(), activeKnowledgeVersion: "legacy-v1-active"),
            "legacy-v1-doc", sourceSet: CangjieSourceSets.DOCS,
            targetVersion: "1.0.0",
            versionResolutionId: v1Resolution.versionResolutionId, budget: 5)
        @Expect(strictV1.hits.size, 1)

        let noisyManifest = ckbS5CopyManifest(manifest)
        for (i in 0..100) {
            noisyManifest.diagnostics.add("重复诊断🙂-${i % 70}")
            noisyManifest.diagnostics.add("重复诊断🙂-${i % 70}")
        }
        let fetchStore = FileKnowledgeStore("target/p5-s5-u01-fetch")
        ckbReleaseTestEnsureEmptyDir(fetchStore.rootPath())
        let fetch = fetchScheduledProfileSources(ckbReleaseTestProfile(),
            CkbReleaseFullRunner(2), fixture.config, fetchStore,
            ckbReleaseTestManifest())
        var stableEvidence = ""
        var stableRender = ""
        for (i in 0..100) {
            let bundle = ckbPrepareReleaseCommitBundle(ckbReleaseTestProfile(), fetch,
                noisyManifest, "ckb-p5-s5-u01-${i}-candidate",
                "ckb-p5-s5-u01-${i}-active", ArrayList<String>(), ArrayList<String>())
            @Expect(bundle.valid, true)
            @Expect(bundle.diagnostics.size <= 64, true)
            @Expect(ckbS5StringsUnique(bundle.diagnostics), true)
            let render = ckbRenderCangjieVersionManifestArtifact(bundle.manifest)
            @Expect(bundle.manifest.diagnostics.size <= 64, true)
            if (i == 0) {
                stableEvidence = bundle.manifestEvidenceHash
                stableRender = render
            } else {
                @Expect(bundle.manifestEvidenceHash, stableEvidence)
                @Expect(render, stableRender)
            }
        }
    }

    @TestCase
    public func p5S5B01AllCommitFaultsHaveDeterministicRollbackOrRollForwardAndRepair(): Unit {
        let fixture = ckbS5ReleaseFixture("target/p5-s5-b01", 2)
        @Expect(fixture.task.ok, true)
        let oldPointer = fixture.store.loadActiveSnapshotPointer()
        let oldPointerText = fixture.store.readText("metadata/active-snapshot.manifest")
        let oldEvidence = ckbS5ActiveCompanionEvidence(fixture.store)
        let oldCommit = fixture.store.readText("transactions/${oldPointer.txId}/COMMIT")
        let prePointerFaults: Array<String> = [
            CkbActiveSnapshotFaultPoints.MANIFEST,
            CkbActiveSnapshotFaultPoints.FRESHNESS,
            CkbActiveSnapshotFaultPoints.COVERAGE,
            CkbActiveSnapshotFaultPoints.COMMIT,
            CkbActiveSnapshotFaultPoints.POINTER_BEFORE
        ]
        for (point in prePointerFaults) {
            let failed = ckbS5WriteCopyForward(fixture.store, point)
            @Expect(failed.ok, false)
            @Expect(failed.pointerCommitted, false)
            @Expect(fixture.store.readText("metadata/active-snapshot.manifest"), oldPointerText)
            @Expect(ckbS5ActiveCompanionEvidence(fixture.store), oldEvidence)
            @Expect(fixture.store.readText("transactions/${oldPointer.txId}/COMMIT"), oldCommit)
        }

        let bindingFetchRoot = "target/p5-s5-b01-bundle-binding"
        ckbReleaseTestEnsureEmptyDir(bindingFetchRoot)
        let bindingFetch = fetchScheduledProfileSources(ckbReleaseTestProfile(),
            CkbReleaseFullRunner(2), fixture.config,
            FileKnowledgeStore(bindingFetchRoot), ckbReleaseTestManifest())
        @Expect(bindingFetch.ok, true)
        let bindingLoaded = newKnowledgeBaseFromStore(fixture.store)
        let bindingStatus = bindingLoaded.kb.status()
        let bindingSnapshot = fixture.store.loadActiveSnapshot()
        let bindingGraph = bindingLoaded.kb.activeGraphBuild()
        for (mode in ["candidate", "freshness", "manifest_version", "aggregate"]) {
            let bundle = ckbPrepareReleaseCommitBundle(ckbReleaseTestProfile(),
                bindingFetch, fixture.store.loadActiveCangjieVersionManifest(),
                bindingStatus.candidateKnowledgeVersion,
                bindingStatus.activeKnowledgeVersion,
                ArrayList<String>(), ArrayList<String>())
            @Expect(bundle.valid, true)
            if (mode == "candidate") {
                bundle.candidateVersion += "-tampered"
                bundle.freshness.candidateKnowledgeVersion = bundle.candidateVersion
            } else if (mode == "freshness") {
                bundle.freshness.activeKnowledgeVersion += "-tampered"
            } else if (mode == "manifest_version") {
                bundle.manifest.manifestVersion = CangjieVersionManifestVersions.V1
            }
            ckbS5RehashReleaseBundle(bundle)
            if (mode == "aggregate") {
                bundle.evidenceHash = ckbReleaseCompanionEvidenceHash("tampered-aggregate")
            }
            let rejected = fixture.store.writeActiveSnapshotTransaction(bindingStatus,
                bindingSnapshot.rawRecords, bindingSnapshot.normalizedRecords,
                bindingSnapshot.activeIndex, bindingSnapshot.vectorRecords,
                bindingSnapshot.vectorActiveCollection, bindingGraph,
                persistVectorFile: bindingSnapshot.hasVectorArtifact,
                releaseBundle: bundle)
            @Expect(rejected.ok, false)
            @Expect(rejected.pointerCommitted, false)
            @Expect(rejected.txId, "")
            @Expect(rejected.failureDiagnostic.startsWith(
                "release_commit_bundle_"), true)
            @Expect(fixture.store.readText("metadata/active-snapshot.manifest"),
                oldPointerText)
            @Expect(ckbS5ActiveCompanionEvidence(fixture.store), oldEvidence)
        }

        for (mode in ["active_identity", "source_indexed_at"]) {
            let tamperedCopy = fixture.store.loadActiveSnapshotCompanionCopy()
            @Expect(tamperedCopy.valid, true)
            let originalFreshness = tamperedCopy.freshnessText
            if (mode == "active_identity") {
                tamperedCopy.freshnessText = tamperedCopy.freshnessText.replace(
                    "activeKnowledgeVersion=${bindingStatus.activeKnowledgeVersion}\n",
                    "activeKnowledgeVersion=${bindingStatus.activeKnowledgeVersion}-tampered\n")
            } else {
                tamperedCopy.freshnessText = tamperedCopy.freshnessText.replace(
                    "|${bindingStatus.activeKnowledgeVersion}|", "|tampered-indexed-at|")
            }
            @Expect(tamperedCopy.freshnessText == originalFreshness, false)
            tamperedCopy.freshnessHash = ckbReleaseCompanionEvidenceHash(
                tamperedCopy.freshnessText)
            let rejectedCopy = fixture.store.writeActiveSnapshotTransaction(bindingStatus,
                bindingSnapshot.rawRecords, bindingSnapshot.normalizedRecords,
                bindingSnapshot.activeIndex, bindingSnapshot.vectorRecords,
                bindingSnapshot.vectorActiveCollection, bindingGraph,
                persistVectorFile: bindingSnapshot.hasVectorArtifact,
                companionCopy: tamperedCopy)
            @Expect(rejectedCopy.ok, false)
            @Expect(rejectedCopy.pointerCommitted, false)
            @Expect(rejectedCopy.txId, "")
            @Expect(rejectedCopy.failureDiagnostic,
                "active_companion_restore_semantic_mismatch")
            @Expect(fixture.store.readText("metadata/active-snapshot.manifest"),
                oldPointerText)
            @Expect(ckbS5ActiveCompanionEvidence(fixture.store), oldEvidence)
        }

        let durableCandidateVersion = "ckb-p5-s5-b01-durable-candidate"
        let durableCandidate = fixture.store.saveCandidateSnapshotImmutable(
            bindingSnapshot.rawRecords, bindingSnapshot.activeIndex,
            durableCandidateVersion)
        let durableRawPath =
            "raw/candidate/${durableCandidateVersion}/records.ckb"
        let durableManifestPath =
            "candidate-artifacts/${durableCandidateVersion}/manifest.ckb"
        let durableCheckpointPath =
            "candidate-artifacts/${durableCandidateVersion}/checkpoint.ckb"
        let durableRawEvidence = ckbReleaseEvidenceHash(
            fixture.store.readText(durableRawPath))
        let durableManifest = fixture.store.readText(durableManifestPath)
        let durableCheckpoint = fixture.store.readText(durableCheckpointPath)
        @Expect(durableCandidate.ok, true)
        @Expect(durableRawEvidence == ckbReleaseEvidenceHash(""), false)
        @Expect(durableManifest == "", false)
        @Expect(durableCheckpoint == "", false)

        let pointerAfter = ckbS5WriteCopyForward(fixture.store,
            CkbActiveSnapshotFaultPoints.POINTER_AFTER)
        @Expect(pointerAfter.ok, true)
        @Expect(pointerAfter.pointerCommitted, true)
        @Expect(pointerAfter.txId == oldPointer.txId, false)
        @Expect(fixture.store.loadActiveSnapshot().valid, true)
        @Expect(newKnowledgeBaseFromStore(fixture.store).source, "persisted")
        @Expect(ckbReleaseEvidenceHash(fixture.store.readText(durableRawPath)),
            durableRawEvidence)
        @Expect(fixture.store.readText(durableManifestPath), durableManifest)
        @Expect(fixture.store.readText(durableCheckpointPath), durableCheckpoint)
        @Expect(ckbS5RootAtomicTmpCount(fixture.store.rootPath()), 0)

        fixture.store.writeLinesAtomically("index/active.version", "stale-live-shadow\n")
        let liveFailure = ckbS5WriteCopyForward(fixture.store,
            CkbActiveSnapshotFaultPoints.LIVE_SHADOW)
        @Expect(liveFailure.ok, true)
        @Expect(liveFailure.pointerCommitted, true)
        @Expect(liveFailure.liveShadowConsistent, false)
        @Expect(fixture.store.loadActiveSnapshot().valid, true)
        let repaired = fixture.store.repairActiveLiveShadowFromManifest()
        @Expect(repaired.ok, true)
        @Expect(repaired.repairPerformed, true)
        @Expect(repaired.liveShadowConsistent, true)
        @Expect(ckbReleaseEvidenceHash(fixture.store.readText(durableRawPath)),
            durableRawEvidence)
        @Expect(fixture.store.readText(durableManifestPath), durableManifest)
        let reusedCandidate = fixture.store.saveCandidateSnapshotImmutable(
            bindingSnapshot.rawRecords, bindingSnapshot.activeIndex,
            durableCandidateVersion)
        @Expect(reusedCandidate.ok, true)
        @Expect(reusedCandidate.immutableReused, true)
        @Expect(reusedCandidate.status, "candidate_immutable_reused")
        @Expect(ckbS5RootAtomicTmpCount(fixture.store.rootPath()), 0)

        let invalidLivePaths: Array<String> = [
            "normalized/records.ckb",
            "metadata/active-cangjie-version-manifest.ckb",
            "index/vector-${fixture.store.loadActiveSnapshotPointer().vectorActiveCollection}.ckb"
        ]
        for (relative in invalidLivePaths) {
            File.writeTo(Path(fixture.store.rootPath()).join(relative),
                [UInt8(255), UInt8(254), UInt8(253)])
            @Expect(fixture.store.loadActiveSnapshot().valid, true)
            let binaryRepair = fixture.store.repairActiveLiveShadowFromManifest()
            @Expect(binaryRepair.ok, true)
            @Expect(binaryRepair.liveShadowConsistent, true)
        }

        let frozenRoot = "target/p5-s5-b01-frozen"
        ckbReleaseTestEnsureEmptyDir(frozenRoot)
        let frozenStore = FileKnowledgeStore(frozenRoot,
            txClock: CkbS5FrozenTxClock(1770000000000))
        let frozenKb = newOfflineKnowledgeBase()
        let first = frozenKb.persistActiveSnapshot(frozenStore)
        let firstBytes = frozenStore.readText("transactions/${first.txId}/COMMIT")
        let second = frozenKb.persistActiveSnapshot(frozenStore)
        let secondBytes = frozenStore.readText("transactions/${second.txId}/COMMIT")
        @Expect(first.txId == second.txId, false)
        @Expect(frozenStore.readText("transactions/${first.txId}/COMMIT"), firstBytes)
        let third = ckbS5WriteCopyForward(frozenStore,
            CkbActiveSnapshotFaultPoints.POINTER_BEFORE)
        @Expect(third.pointerCommitted, false)
        @Expect(frozenStore.loadActiveSnapshotPointer().txId, second.txId)
        @Expect(frozenStore.readText("transactions/${first.txId}/COMMIT"), firstBytes)
        @Expect(frozenStore.readText("transactions/${second.txId}/COMMIT"), secondBytes)

        let consumeRoot = "target/p5-s5-b01-consume-degraded"
        ckbReleaseTestEnsureEmptyDir(consumeRoot)
        let consumeStore = FileKnowledgeStore(consumeRoot)
        let consumePlan = ckbBuildReleaseFullSyncPlan(ckbReleaseTestProfile(),
            ckbReleaseTestManifest(), "1.0.0")
        let normalKey = ckbReleaseScheduledFetchRunKey(ckbReleaseTestProfile(),
            consumePlan.sources[0], consumePlan.planHash)
        let blockedKey = ckbReleaseScheduledFetchRunKey(ckbReleaseTestProfile(),
            consumePlan.sources[1], consumePlan.planHash)
        ckbMarkReleaseAcquisitionState(consumeStore, normalKey, "active")
        Directory.create(Path(consumeRoot).join(
            "${ckbReleaseAcquisitionRoot(blockedKey)}/state.json"), recursive: true)
        let consumeDiagnostics = ArrayList<String>()
        let consumeKeys = ArrayList<CkbScheduledFetchRunKey>()
        consumeKeys.add(normalKey)
        consumeKeys.add(blockedKey)
        let pointerBeforeConsume = fixture.store.readText("metadata/active-snapshot.manifest")
        let evidenceBeforeConsume = ckbS5ActiveCompanionEvidence(fixture.store)
        let consumed = ckbConsumeReleaseAcquisitionStatesBestEffort(consumeStore,
            consumeKeys, "candidate-consume",
            oldPointer.activeVersion, consumeDiagnostics)
        @Expect(consumed.consumed, 1)
        @Expect(consumed.failed, 1)
        @Expect(ckbLoadReleaseAcquisitionState(consumeStore, normalKey).state,
            "consumed")
        @Expect(ckbLoadReleaseAcquisitionState(consumeStore, blockedKey).state ==
            "consumed", false)
        @Expect(consumeDiagnostics.size, 1)
        @Expect(consumeDiagnostics[0].startsWith(
            "release_acquisition_consume_degraded:"), true)
        @Expect(consumeDiagnostics[0].size <= 320, true)
        @Expect(consumeDiagnostics[0].contains(consumeRoot), false)
        @Expect(fixture.task.ok, true)
        @Expect(fixture.store.readText("metadata/active-snapshot.manifest"),
            pointerBeforeConsume)
        @Expect(ckbS5ActiveCompanionEvidence(fixture.store), evidenceBeforeConsume)
        _ = launch("/bin/rm", ["-rf", Path(consumeRoot).join(
            "${ckbReleaseAcquisitionRoot(blockedKey)}/state.json").toString()]).wait()
        ckbMarkReleaseAcquisitionState(consumeStore, blockedKey, "active")
        @Expect(ckbReleaseAcquisitionCanResume(consumeStore, blockedKey), true)

        let mismatchSnapshot = frozenStore.loadActiveSnapshot()
        let mismatchLoaded = newKnowledgeBaseFromStore(frozenStore)
        let mismatchStatus = mismatchLoaded.kb.status()
        let mismatchGraph = mismatchLoaded.kb.activeGraphBuild()
        let pointerBeforeMismatch = frozenStore.readText("metadata/active-snapshot.manifest")
        let mismatch = frozenStore.writeActiveSnapshotTransaction(mismatchStatus,
            mismatchSnapshot.rawRecords, mismatchSnapshot.normalizedRecords,
            mismatchSnapshot.activeIndex, mismatchSnapshot.vectorRecords,
            "wrong-collection", mismatchGraph)
        @Expect(mismatch.ok, false)
        @Expect(mismatch.failureDiagnostic, "active_snapshot_identity_invalid")
        @Expect(frozenStore.readText("metadata/active-snapshot.manifest"), pointerBeforeMismatch)
    }

    @TestCase
    public func p5S5P01NewProcessLoadsSameTransactionAndBackupRestorePreservesExternalMetadata(): Unit {
        let fixture = ckbS5ReleaseFixture("target/p5-s5-p01", 2)
        @Expect(fixture.task.ok, true)
        let pointer = fixture.store.loadActiveSnapshotPointer()
        let loaded = newKnowledgeBaseFromStore(fixture.store)
        let service = CkbCommandLoopService(fixture.config, fixture.store,
            sourceRunner: DisabledNetworkFetchRunner())
        let activeManifest = service.activeVersionManifest()
        let activeFreshness = service.cangjieCorpusFreshness()
        let query = cangjie_evidence_pack(loaded.kb, "new-a-token", 5)
        @Expect(pointer.valid, true)
        @Expect(pointer.companionMode, CkbActiveSnapshotCompanionMode.RELEASE)
        @Expect(loaded.source, "persisted")
        @Expect(query.docEvidence.size + query.sourceEvidence.size > 0, true)
        @Expect(activeManifest.sources.size, 5)
        @Expect(activeFreshness.sources.size, 5)
        @Expect(activeFreshness.activeKnowledgeVersion, pointer.activeVersion)
        @Expect(activeFreshness.degraded, false)
        for (source in activeFreshness.sources) {
            if (source.sourceSet != CangjieSourceSets.EVAL_SUPPORT) {
                @Expect(source.resolvedCommit,
                    "2222222222222222222222222222222222222222")
            }
        }
        @Expect(ckbReleaseTestManifestSource(activeManifest, CangjieSourceSets.DOCS).resolvedCommit,
            "2222222222222222222222222222222222222222")
        @Expect(ckbS5LiveShadowEqualsTransaction(fixture.store, pointer), true)
        let noOpRepair = fixture.store.repairActiveLiveShadowFromManifest()
        @Expect(noOpRepair.ok, true)
        @Expect(noOpRepair.repairPerformed, false)

        let genericTaskRoot = "target/p5-s5-p01-generic-task"
        ckbReleaseTestEnsureEmptyDir(genericTaskRoot)
        @Expect(fixture.store.backupActiveSnapshot(genericTaskRoot).ok, true)
        let genericTaskStore = FileKnowledgeStore(genericTaskRoot)
        genericTaskStore.saveCangjieVersionManifest(ckbReleaseTestManifest())
        @Expect(genericTaskStore.loadCangjieVersionManifest().manifestVersion,
            CangjieVersionManifestVersions.V1)
        let genericBeforePointer = genericTaskStore.loadActiveSnapshotPointer()
        let genericTaskRunner = CkbS5GenericDeltaRunner()
        let genericTaskKb = newKnowledgeBaseFromStore(genericTaskStore).kb
        let genericTask = CkbSchedulerTaskRunner(genericTaskKb, fixture.config,
            genericTaskStore, sourceRunner: genericTaskRunner).runTask(
                "cangjie_source_event_sync", "0", ckbCoreNowMillis() + 125000)
        let genericTaskPointer = genericTaskStore.loadActiveSnapshotPointer()
        let genericTaskManifest = genericTaskStore.loadActiveCangjieVersionManifest()
        let genericTaskFreshness = genericTaskStore.loadActiveCangjieCorpusFreshness()
        let genericResolution = resolveCangjieVersion(cangjieVersionSelector(
            targetVersion: "1.0.0", sourceSet: CangjieSourceSets.STD),
            genericTaskManifest)
        @Expect(genericTask.ok, true)
        @Expect(genericTaskRunner.calls > 0, true)
        @Expect(genericTaskPointer.valid, true)
        @Expect(genericTaskPointer.companionMode,
            CkbActiveSnapshotCompanionMode.COPY_FORWARD)
        @Expect(genericTaskPointer.manifestHash, genericBeforePointer.manifestHash)
        @Expect(genericTaskPointer.coverageHash, genericBeforePointer.coverageHash)
        @Expect(genericTaskManifest.manifestVersion,
            CangjieVersionManifestVersions.V2)
        @Expect(genericResolution.ok, true)
        @Expect(genericResolution.versionResolutionId.startsWith(
            "cangjie-version-v2-"), true)
        var genericDeltaFound = false
        for (record in genericTaskStore.loadActiveSnapshot().activeIndex) {
            if (record.metadata.symbol == "p5S5GenericV2Only") {
                genericDeltaFound = true
                @Expect(record.metadata.versionResolutionId,
                    genericResolution.versionResolutionId)
            }
        }
        @Expect(genericDeltaFound, true)
        let genericServing = buildCangjieServingIndex(
            genericTaskStore.loadActiveSnapshot().activeIndex,
            activeKnowledgeVersion: genericTaskPointer.activeVersion)
        let genericStrict = lookupExactSymbol(genericServing,
            "p5S5GenericV2Only", sourceSet: CangjieSourceSets.STD,
            targetVersion: "1.0.0",
            versionResolutionId: genericResolution.versionResolutionId, budget: 5)
        @Expect(genericStrict.ok, true)
        @Expect(genericStrict.hits.size > 0, true)
        @Expect(genericTaskFreshness.activeKnowledgeVersion,
            genericTaskPointer.activeVersion)
        @Expect(genericTaskFreshness.candidateKnowledgeVersion,
            genericTask.candidateVersion)
        for (source in genericTaskFreshness.sources) {
            @Expect(source.indexedAt, genericTaskPointer.activeVersion)
        }

        let lifecycleSourceRoot = "target/p5-s5-p01-lifecycle-source"
        let lifecycleBackupRoot = "target/p5-s5-p01-lifecycle-backup"
        let lifecycleRestoreRoot = "target/p5-s5-p01-lifecycle-restored"
        ckbReleaseTestEnsureEmptyDir(lifecycleSourceRoot)
        ckbReleaseTestEnsureEmptyDir(lifecycleBackupRoot)
        ckbReleaseTestEnsureEmptyDir(lifecycleRestoreRoot)
        @Expect(fixture.store.backupActiveSnapshot(lifecycleSourceRoot).ok, true)
        let lifecycleSource = FileKnowledgeStore(lifecycleSourceRoot)
        let failedCandidateVersion = "ckb-p5-s5-p01-failed-candidate"
        let failedLifecycle = cangjiePromoteCandidateRecordsAfterValidationWithVersion(
            newKnowledgeBaseFromStore(lifecycleSource).kb, lifecycleSource,
            failedCandidateVersion, lifecycleSource.loadActiveSnapshot().activeIndex,
            forceFailure: true)
        @Expect(failedLifecycle.ok, false)
        @Expect(failedLifecycle.validation.ok, false)
        @Expect(newKnowledgeBaseFromStore(lifecycleSource).kb.status().candidateKnowledgeVersion,
            failedCandidateVersion)
        @Expect(newKnowledgeBaseFromStore(lifecycleSource).kb.status().failedCandidateVersion,
            failedCandidateVersion)

        let lifecycleBackup = lifecycleSource.backupActiveSnapshot(lifecycleBackupRoot)
        let lifecycleBackupStore = FileKnowledgeStore(lifecycleBackupRoot)
        let lifecycleRestoreStore = FileKnowledgeStore(lifecycleRestoreRoot)
        let lifecycleRestore = lifecycleRestoreStore.restoreActiveSnapshotBackup(
            lifecycleBackupRoot)
        @Expect(lifecycleBackup.ok, true)
        @Expect(lifecycleRestore.ok, true)
        for (copiedStore in [lifecycleBackupStore, lifecycleRestoreStore]) {
            let copiedPointer = copiedStore.loadActiveSnapshotPointer()
            let copiedTxStatus = copiedStore.loadMetadataStatus()
            let copiedManifest = copiedStore.loadActiveCangjieVersionManifest()
            let copiedFreshness = copiedStore.loadActiveCangjieCorpusFreshness()
            let copiedReload = newKnowledgeBaseFromStore(copiedStore)
            @Expect(copiedPointer.valid, true)
            @Expect(copiedPointer.companionMode,
                CkbActiveSnapshotCompanionMode.COPY_FORWARD)
            @Expect(copiedManifest.manifestVersion, CangjieVersionManifestVersions.V2)
            @Expect(copiedManifest.sources.size, 5)
            @Expect(copiedFreshness.sources.size, copiedManifest.sources.size)
            @Expect(copiedFreshness.activeKnowledgeVersion,
                copiedTxStatus.activeVersion)
            @Expect(copiedFreshness.candidateKnowledgeVersion,
                copiedTxStatus.candidateVersion)
            @Expect(copiedFreshness.failedCandidateVersion,
                copiedTxStatus.failedVersion)
            @Expect(copiedFreshness.targetVersion,
                copiedManifest.defaultTargetVersion)
            @Expect(copiedTxStatus.candidateVersion == failedCandidateVersion, false)
            @Expect(copiedTxStatus.failedVersion == failedCandidateVersion, false)
            for (source in copiedFreshness.sources) {
                @Expect(source.indexedAt, copiedTxStatus.activeVersion)
                let manifestSource = ckbReleaseTestManifestSource(copiedManifest,
                    source.sourceSet)
                @Expect(source.resolvedCommit, manifestSource.resolvedCommit)
                @Expect(source.contentHash, manifestSource.contentHash)
                @Expect(source.targetVersion, manifestSource.targetVersion)
            }
            @Expect(copiedReload.source, "persisted")
            @Expect(copiedReload.kb.status().candidateKnowledgeVersion,
                failedCandidateVersion)
            @Expect(copiedReload.kb.status().failedCandidateVersion,
                failedCandidateVersion)
            @Expect(copiedStore.has(
                "candidate-artifacts/${failedCandidateVersion}/status.ckb"), false)
            let lifecycleRepair = copiedStore.repairActiveLiveShadowFromManifest()
            @Expect(lifecycleRepair.ok, true)
            @Expect(lifecycleRepair.repairPerformed, false)
            let repairedReload = newKnowledgeBaseFromStore(copiedStore)
            @Expect(repairedReload.kb.status().candidateKnowledgeVersion,
                failedCandidateVersion)
            @Expect(repairedReload.kb.status().failedCandidateVersion,
                failedCandidateVersion)
            copiedStore.writeLinesAtomically("index/active.ckb", "damaged-live-shadow\n")
            let performedRepair = copiedStore.repairActiveLiveShadowFromManifest()
            @Expect(performedRepair.ok, true)
            @Expect(performedRepair.repairPerformed, true)
            @Expect(performedRepair.liveShadowConsistent, true)
            let repairedAfterDamage = newKnowledgeBaseFromStore(copiedStore)
            @Expect(repairedAfterDamage.source, "persisted")
            @Expect(repairedAfterDamage.kb.status().candidateKnowledgeVersion,
                failedCandidateVersion)
            @Expect(repairedAfterDamage.kb.status().failedCandidateVersion,
                failedCandidateVersion)
        }

        let markerBackupRoot = "target/p5-s5-p01-marker-degraded"
        let markerRestoreRoot = "target/p5-s5-p01-marker-restored"
        ckbReleaseTestEnsureEmptyDir(markerBackupRoot)
        ckbReleaseTestEnsureEmptyDir(markerRestoreRoot)
        Directory.create(Path(markerBackupRoot).join("metadata/backup.ckb"),
            recursive: true)
        let markerBackup = fixture.store.backupActiveSnapshot(markerBackupRoot)
        let markerStore = FileKnowledgeStore(markerBackupRoot)
        @Expect(markerBackup.ok, true)
        @Expect(markerBackup.diagnostic.startsWith("backup_marker_degraded:"), true)
        @Expect(markerStore.loadActiveSnapshotPointer().valid, true)
        @Expect(markerStore.loadActiveSnapshot().valid, true)
        @Expect(markerStore.loadActiveSnapshotPointer().manifestHash, pointer.manifestHash)
        @Expect(markerStore.loadActiveSnapshotPointer().freshnessHash, pointer.freshnessHash)
        @Expect(markerStore.loadActiveSnapshotPointer().coverageHash, pointer.coverageHash)
        let markerRestored = FileKnowledgeStore(markerRestoreRoot)
        @Expect(markerRestored.restoreActiveSnapshotBackup(markerBackupRoot).ok, true)
        @Expect(markerRestored.loadActiveSnapshot().valid, true)

        let backupRoot = "target/p5-s5-p01-backup"
        let restoreRoot = "target/p5-s5-p01-restored"
        ckbReleaseTestEnsureEmptyDir(backupRoot)
        ckbReleaseTestEnsureEmptyDir(restoreRoot)
        let backup = fixture.store.backupActiveSnapshot(backupRoot)
        let restoredStore = FileKnowledgeStore(restoreRoot,
            txClock: CkbS5FrozenTxClock(1888000000000))
        let restored = restoredStore.restoreActiveSnapshotBackup(backupRoot)
        let backupPointer = FileKnowledgeStore(backupRoot).loadActiveSnapshotPointer()
        let restoredPointer = restoredStore.loadActiveSnapshotPointer()
        @Expect(backup.ok, true)
        @Expect(backup.files, markerBackup.files + 1)
        @Expect(restored.ok, true)
        @Expect(backupPointer.companionMode, CkbActiveSnapshotCompanionMode.COPY_FORWARD)
        @Expect(backupPointer.manifestHash, pointer.manifestHash)
        @Expect(backupPointer.freshnessHash, pointer.freshnessHash)
        @Expect(backupPointer.coverageHash, pointer.coverageHash)
        @Expect(restoredPointer.txId == backupPointer.txId, false)
        @Expect(restoredPointer.companionMode, CkbActiveSnapshotCompanionMode.COPY_FORWARD)
        @Expect(restoredPointer.manifestHash, pointer.manifestHash)
        @Expect(restoredPointer.freshnessHash, pointer.freshnessHash)
        @Expect(restoredPointer.coverageHash, pointer.coverageHash)
        @Expect(newKnowledgeBaseFromStore(restoredStore).source, "persisted")
        @Expect(cangjie_evidence_pack(newKnowledgeBaseFromStore(restoredStore).kb,
            "new-a-token", 5).citations.size > 0, true)

        let genericLoaded = newKnowledgeBaseFromStore(restoredStore)
        let genericCandidate = "ckb-p5-s5-p01-generic-candidate"
        let genericPromotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(
            genericLoaded.kb, restoredStore, genericCandidate,
            restoredStore.loadActiveSnapshot().activeIndex)
        let genericPointer = restoredStore.loadActiveSnapshotPointer()
        let genericFreshness = restoredStore.loadActiveCangjieCorpusFreshness()
        @Expect(genericPromotion.ok, true)
        @Expect(genericPromotion.validation.status, "candidate_validation_passed")
        @Expect(genericPointer.valid, true)
        @Expect(genericPointer.companionMode,
            CkbActiveSnapshotCompanionMode.COPY_FORWARD)
        @Expect(genericPointer.manifestHash, restoredPointer.manifestHash)
        @Expect(genericPointer.coverageHash, restoredPointer.coverageHash)
        @Expect(genericPointer.freshnessHash == restoredPointer.freshnessHash, false)
        @Expect(genericFreshness.activeKnowledgeVersion, genericPointer.activeVersion)
        @Expect(genericFreshness.candidateKnowledgeVersion,
            genericPromotion.candidateVersion)
        for (source in genericFreshness.sources) {
            @Expect(source.indexedAt, genericPointer.activeVersion)
        }
        let genericService = CkbCommandLoopService(fixture.config, restoredStore,
            sourceRunner: DisabledNetworkFetchRunner())
        let servedGenericFreshness = genericService.cangjieCorpusFreshness()
        @Expect(servedGenericFreshness.degraded, false)
        @Expect(ckbReleaseTestDiagnosticsContain(servedGenericFreshness.diagnostics,
            "active_freshness_transaction_identity_invalid"), false)
        @Expect(genericService.queryEvidencePack("new-a-token", 5).citations.size > 0,
            true)

        let externalRoot = "target/p5-s5-p01-external"
        let externalBackup = "target/p5-s5-p01-external-backup"
        let externalRestore = "target/p5-s5-p01-external-restored"
        ckbReleaseTestEnsureEmptyDir(externalRoot)
        ckbReleaseTestEnsureEmptyDir(externalBackup)
        ckbReleaseTestEnsureEmptyDir(externalRestore)
        let externalStore = FileKnowledgeStore(externalRoot)
        let snapshot = fixture.store.loadActiveSnapshot()
        let sourceLoaded = newKnowledgeBaseFromStore(fixture.store)
        let externalStatus = sourceLoaded.kb.status()
        externalStatus.storage.vectorBackend = "qdrant"
        externalStatus.storage.vectorState = EmbeddingProviderState.READY
        externalStatus.storage.vectorCollection = "qdrant_active"
        externalStatus.storage.vectorActiveCollection = "qdrant_active"
        externalStatus.storage.vectorCandidateCollection = "qdrant_candidate"
        externalStatus.storage.vectorIndexCount = snapshot.activeIndex.size
        externalStatus.storage.vectorDimension = 1024
        externalStatus.storage.graphBackend = "external-graph"
        externalStatus.storage.graphState = EmbeddingProviderState.READY
        externalStatus.storage.graphNodeCount = 123
        externalStatus.storage.graphEdgeCount = 456
        externalStatus.storage.graphIndexCount = 456
        let externalTx = externalStore.writeActiveSnapshotTransaction(externalStatus,
            snapshot.rawRecords, snapshot.normalizedRecords, snapshot.activeIndex,
            ArrayList<VectorRecord>(), "qdrant_active", sourceLoaded.kb.activeGraphBuild(),
            persistVectorFile: false,
            companionCopy: fixture.store.loadActiveSnapshotCompanionCopy())
        @Expect(externalTx.ok, true)
        @Expect(externalStore.backupActiveSnapshot(externalBackup).ok, true)
        let externalRestoredStore = FileKnowledgeStore(externalRestore)
        @Expect(externalRestoredStore.restoreActiveSnapshotBackup(externalBackup).ok, true)
        let externalMetadata = externalRestoredStore.loadMetadataStatus()
        @Expect(externalMetadata.vectorBackend, "qdrant")
        @Expect(externalMetadata.vectorState, EmbeddingProviderState.READY)
        @Expect(externalMetadata.vectorActiveCollection, "qdrant_active")
        @Expect(externalMetadata.vectorIndexCount, snapshot.activeIndex.size)
        @Expect(externalMetadata.vectorDimension, 1024)
        @Expect(externalMetadata.graphBackend, "external-graph")
        @Expect(externalMetadata.graphState, EmbeddingProviderState.READY)
        @Expect(externalMetadata.graphNodeCount, 123)
        @Expect(externalMetadata.graphEdgeCount, 456)
        @Expect(externalMetadata.graphIndexCount, 456)

        let noneSourceRoot = "target/p5-s5-p01-none-source"
        let noneBackupRoot = "target/p5-s5-p01-none-backup"
        let noneRestoreRoot = "target/p5-s5-p01-none-over-release"
        ckbReleaseTestEnsureEmptyDir(noneSourceRoot)
        ckbReleaseTestEnsureEmptyDir(noneBackupRoot)
        ckbReleaseTestEnsureEmptyDir(noneRestoreRoot)
        let noneSource = FileKnowledgeStore(noneSourceRoot)
        let noneStatus = sourceLoaded.kb.status()
        let noneTx = noneSource.writeActiveSnapshotTransaction(noneStatus,
            snapshot.rawRecords, snapshot.normalizedRecords, snapshot.activeIndex,
            snapshot.vectorRecords, noneStatus.storage.vectorActiveCollection,
            sourceLoaded.kb.activeGraphBuild())
        @Expect(noneTx.ok, true)
        @Expect(noneTx.companionMode, CkbActiveSnapshotCompanionMode.NONE)
        noneSource.saveCangjieVersionManifest(ckbReleaseTestManifest())
        let nonePlanning = CkbCommandLoopService(fixture.config, noneSource,
            sourceRunner: DisabledNetworkFetchRunner()).activeVersionManifest()
        @Expect(nonePlanning.manifestVersion, CangjieVersionManifestVersions.V1)
        @Expect(nonePlanning.sources.size, 5)
        @Expect(noneSource.backupActiveSnapshot(noneBackupRoot).ok, true)

        let noneRestore = FileKnowledgeStore(noneRestoreRoot)
        @Expect(noneRestore.restoreActiveSnapshotBackup(backupRoot).ok, true)
        @Expect(noneRestore.has("metadata/active-cangjie-version-manifest.ckb"), true)
        @Expect(noneRestore.has("metadata/active-cangjie-freshness.ckb"), true)
        @Expect(noneRestore.has("metadata/active-cangjie-release-coverage.ckb"), true)
        noneRestore.writeLinesAtomically("metadata/cangjie-version-manifest.ckb", "planning-manifest\n")
        noneRestore.writeLinesAtomically("metadata/cangjie-freshness.ckb", "planning-freshness\n")
        noneRestore.writeLinesAtomically("metadata/cangjie-release-coverage.ckb", "planning-coverage\n")
        @Expect(noneRestore.restoreActiveSnapshotBackup(noneBackupRoot).ok, true)
        @Expect(noneRestore.loadActiveSnapshotPointer().companionMode,
            CkbActiveSnapshotCompanionMode.NONE)
        @Expect(noneRestore.has("metadata/active-cangjie-version-manifest.ckb"), false)
        @Expect(noneRestore.has("metadata/active-cangjie-freshness.ckb"), false)
        @Expect(noneRestore.has("metadata/active-cangjie-release-coverage.ckb"), false)
        @Expect(noneRestore.readText("metadata/cangjie-version-manifest.ckb"), "planning-manifest\n")
        @Expect(noneRestore.readText("metadata/cangjie-freshness.ckb"), "planning-freshness\n")
        @Expect(noneRestore.readText("metadata/cangjie-release-coverage.ckb"), "planning-coverage\n")

        noneRestore.writeLinesAtomically("metadata/active-cangjie-version-manifest.ckb", "stale\n")
        noneRestore.writeLinesAtomically("metadata/active-cangjie-freshness.ckb", "stale\n")
        noneRestore.writeLinesAtomically("metadata/active-cangjie-release-coverage.ckb", "stale\n")
        let noneRepair = noneRestore.repairActiveLiveShadowFromManifest()
        @Expect(noneRepair.ok, true)
        @Expect(noneRepair.repairPerformed, true)
        @Expect(noneRepair.liveShadowConsistent, true)
        @Expect(noneRepair.removedFiles.size, 3)
        @Expect(noneRestore.has("metadata/active-cangjie-version-manifest.ckb"), false)
        @Expect(noneRestore.has("metadata/active-cangjie-freshness.ckb"), false)
        @Expect(noneRestore.has("metadata/active-cangjie-release-coverage.ckb"), false)
        @Expect(noneRestore.readText("metadata/cangjie-version-manifest.ckb"), "planning-manifest\n")
        @Expect(noneRestore.readText("metadata/cangjie-freshness.ckb"), "planning-freshness\n")
        @Expect(noneRestore.readText("metadata/cangjie-release-coverage.ckb"), "planning-coverage\n")
    }

    @TestCase
    public func p5S5N01FetchVectorValidationCommitSnapshotAndV2TamperFailClosed(): Unit {
        let fixture = ckbS5ReleaseFixture("target/p5-s5-n01", 2)
        @Expect(fixture.task.ok, true)
        let oldPointer = fixture.store.readText("metadata/active-snapshot.manifest")
        let oldEvidence = ckbS5AuthoritativeSnapshotEvidence(fixture.store)
        let fetchFailure = CkbSchedulerTaskRunner(fixture.kb, fixture.config, fixture.store,
            sourceRunner: CkbReleaseFailureRunner("malformed_branch")).runTask(
            "cangjie_release_full_sync", "0", ckbCoreNowMillis() + 435000)
        @Expect(fetchFailure.ok, false)
        @Expect(fixture.store.readText("metadata/active-snapshot.manifest"), oldPointer)
        @Expect(ckbS5AuthoritativeSnapshotEvidence(fixture.store), oldEvidence)

        let validationLoaded = newKnowledgeBaseFromStore(fixture.store)
        let records = fixture.store.loadActiveSnapshot().activeIndex
        let validationFailure = cangjiePromoteCandidateRecordsAfterValidationWithVersion(
            validationLoaded.kb, fixture.store, "ckb-p5-s5-validation-candidate", records,
            forceFailure: true)
        @Expect(validationFailure.ok, false)
        @Expect(fixture.store.readText(
            "candidate-artifacts/${validationFailure.candidateVersion}/status.ckb").contains(
            "state=failed"), true)
        @Expect(fixture.store.readText("metadata/active-snapshot.manifest"), oldPointer)
        @Expect(ckbS5AuthoritativeSnapshotEvidence(fixture.store), oldEvidence)

        let downProvider = CkbS5DownEmbeddingProvider()
        let vectorKb = KnowledgeBase(FakeClock(0), downProvider,
            LocalVectorStore(), LocalGraphStore())
        @Expect(vectorKb.restoreActiveSnapshot(fixture.store.loadActiveSnapshot()), true)
        let changedRecords = fixture.store.loadActiveSnapshot().activeIndex
        changedRecords[0].sourceId = "p5typed-forced-new-vector-identity"
        changedRecords[0].chunk += " forced-new-vector-content"
        let vectorFailure = cangjiePromoteCandidateRecordsAfterValidationWithVersion(
            vectorKb, fixture.store, "ckb-p5-s5-vector-candidate", changedRecords)
        @Expect(vectorFailure.ok, false)
        @Expect(vectorFailure.validation.status, "candidate_vector_failed")
        @Expect(downProvider.calls > 0, true)
        @Expect(fixture.store.readText(
            "candidate-artifacts/${vectorFailure.candidateVersion}/status.ckb").contains(
            "state=failed"), true)
        @Expect(fixture.store.readText("metadata/active-snapshot.manifest"), oldPointer)
        @Expect(ckbS5AuthoritativeSnapshotEvidence(fixture.store), oldEvidence)

        let commitLoaded = newKnowledgeBaseFromStore(fixture.store)
        let staged = commitLoaded.kb.stageCandidateRecords(
            "ckb-p5-s5-commit-candidate", records)
        var commitDiagnostic = ""
        try {
            _ = commitLoaded.kb.commitCandidateToActiveAfterVectorReady(
                cangjieActiveVersionForCandidate(staged),
                commitLoaded.kb.status().storage.vectorCandidateCollection,
                ckbS5ReadyVectorStatus(records),
                deadlineAtMillis: ckbCoreNowMillis() - 1)
        } catch (e: Exception) { commitDiagnostic = e.message }
        @Expect(commitDiagnostic.contains("deadline_exceeded:"), true)
        @Expect(fixture.store.readText("metadata/active-snapshot.manifest"), oldPointer)
        @Expect(ckbS5AuthoritativeSnapshotEvidence(fixture.store), oldEvidence)

        let snapshotLoaded = newKnowledgeBaseFromStore(fixture.store)
        let snapshotFailure = cangjiePromoteCandidateRecordsAfterValidationWithVersion(
            snapshotLoaded.kb, fixture.store, "ckb-p5-s5-snapshot-candidate", records,
            snapshotFaultInjector: CkbS5FaultInjector(CkbActiveSnapshotFaultPoints.COMMIT))
        @Expect(snapshotFailure.ok, false)
        @Expect(snapshotFailure.activePromoted, false)
        @Expect(snapshotFailure.validation.ok, false)
        @Expect(snapshotFailure.snapshotPointerCommitted, false)
        @Expect(fixture.store.readText(
            "candidate-artifacts/${snapshotFailure.candidateVersion}/status.ckb").contains(
            "state=failed"), true)
        @Expect(snapshotFailure.activeVersion,
            fixture.store.loadActiveSnapshotPointer().activeVersion)
        @Expect(fixture.store.readText("metadata/active-snapshot.manifest"), oldPointer)
        @Expect(ckbS5AuthoritativeSnapshotEvidence(fixture.store), oldEvidence)
        @Expect(ckbReleaseTestDiagnosticsContain(snapshotFailure.validation.diagnostics,
            "candidate_staging_deleted:"), true)

        let tamperRoot = "target/p5-s5-n01-schema-tamper"
        ckbReleaseTestEnsureEmptyDir(tamperRoot)
        @Expect(FileKnowledgeStore(tamperRoot).restoreActiveSnapshotBackup(
            ckbS5BackupFixture(fixture.store, "target/p5-s5-n01-backup")).ok, true)
        let tamperStore = FileKnowledgeStore(tamperRoot)
        let tamperPointerText = tamperStore.readText("metadata/active-snapshot.manifest")
        tamperStore.writeLinesAtomically("metadata/active-snapshot.manifest",
            ckbS5RemoveLines(tamperPointerText, ["schema="]))
        tamperStore.saveCangjieVersionManifest(ckbReleaseTestManifest())
        @Expect(tamperStore.loadActiveSnapshotPointer().valid, false)
        let invalidManifest = CkbCommandLoopService(fixture.config, tamperStore,
            sourceRunner: DisabledNetworkFetchRunner()).activeVersionManifest()
        @Expect(invalidManifest.sources.size, 0)
        @Expect(invalidManifest.degraded, true)
        let invalidRunner = CkbS5GenericDeltaRunner()
        let invalidTask = CkbSchedulerTaskRunner(newKnowledgeBaseFromStore(
            tamperStore).kb, fixture.config, tamperStore,
            sourceRunner: invalidRunner).runTask("cangjie_source_event_sync", "0",
                ckbCoreNowMillis() + 125000)
        @Expect(invalidTask.ok, false)
        @Expect(invalidRunner.calls, 0)
        let tamperLoaded = newKnowledgeBaseFromStore(tamperStore)
        @Expect(tamperLoaded.source, "persisted_invalid")
        @Expect(cangjie_source_search(tamperLoaded.kb, "HttpClient", 3).records.size, 0)
        let guardOptions = CkbFirstInitOptions()
        guardOptions.apply = true
        guardOptions.dryRun = false
        let guard = runCkbFirstInitializationWithActiveGuard(guardOptions, tamperStore)
        @Expect(guard.ok, false)
        @Expect(guard.persisted, false)

        let legacyLookingRoot = "target/p5-s5-n01-legacy-looking"
        ckbReleaseTestEnsureEmptyDir(legacyLookingRoot)
        @Expect(FileKnowledgeStore(legacyLookingRoot).restoreActiveSnapshotBackup(
            ckbS5BackupFixture(fixture.store, "target/p5-s5-n01-backup-2")).ok, true)
        let legacyLooking = FileKnowledgeStore(legacyLookingRoot)
        let legacyPointer = legacyLooking.readText("metadata/active-snapshot.manifest")
        legacyLooking.writeLinesAtomically("metadata/active-snapshot.manifest",
            ckbS5RemoveLines(legacyPointer,
                ["schema=", "companionMode=", "manifestHash=", "freshnessHash=", "coverageHash="]))
        @Expect(legacyLooking.loadActiveSnapshotPointer().valid, false)
        @Expect(legacyLooking.loadActiveSnapshotPointer().legacy, false)
        @Expect(newKnowledgeBaseFromStore(legacyLooking).source, "persisted_invalid")

        for (mode in ["pointer_committed", "commit_persist", "commit_schema",
            "companion_utf8", "payload_utf8", "pointer_zero",
            "pointer_whitespace", "pointer_garbage"]) {
            let damaged = ckbS5TamperedClone(fixture.store,
                "target/p5-s5-n01-${mode}", mode)
            @Expect(damaged.loadActiveSnapshotPointer().valid, false)
            @Expect(damaged.hasAuthoritativeActiveSnapshotPointer(), true)
            let damagedLoaded = newKnowledgeBaseFromStore(damaged)
            @Expect(damagedLoaded.source, "persisted_invalid")
            @Expect(cangjie_source_search(damagedLoaded.kb, "HttpClient", 3).records.size, 0)
            let damagedService = CkbCommandLoopService(fixture.config, damaged,
                sourceRunner: DisabledNetworkFetchRunner())
            let damagedManifest = damagedService.activeVersionManifest()
            let damagedFreshness = damagedService.cangjieCorpusFreshness()
            @Expect(damagedManifest.sources.size, 0)
            @Expect(damagedManifest.degraded, true)
            @Expect(damagedFreshness.degraded, true)
            @Expect(damagedFreshness.sources.size, 0)
            let damagedCollections = ckbEffectiveVectorCollections(fixture.config,
                damaged)
            @Expect(damagedCollections.valid, false)
            @Expect(damagedCollections.effectiveActiveCollection, "")
        }
    }

    @TestCase
    public func p5S5E2EAFullCandidateAndCommitBoundaryMatrixKeepOneAuthoritativeTransaction(): Unit {
        let root = "target/p5-s5-e2e-a"
        ckbReleaseTestEnsureEmptyDir(root)
        let evalRoot = "${root}/eval"
        ckbReleaseTestWriteEvalFixture(evalRoot)
        let config = ckbS5Config(evalRoot)
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(ckbReleaseTestManifest())
        let service = CkbCommandLoopService(config, store,
            sourceRunner: CkbReleaseFullRunner(2))
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_release_full_sync")
        let run = service.runSchedulerTasks(tasks, true)
        let successPointer = store.loadActiveSnapshotPointer()
        let successEvidence = ckbS5AuthoritativeSnapshotEvidence(store)
        @Expect(run.succeeded, 1)
        @Expect(run.failed, 0)
        @Expect(successPointer.valid, true)
        @Expect(successPointer.companionMode, CkbActiveSnapshotCompanionMode.RELEASE)
        @Expect(service.activeVersionManifest().sources.size, 5)
        @Expect(service.queryEvidencePack("new-a-token", 5).citations.size > 0, true)

        let matrixFetchRoot = "${root}/matrix-fetch"
        ckbReleaseTestEnsureEmptyDir(matrixFetchRoot)
        let matrixFetch = fetchScheduledProfileSources(ckbReleaseTestProfile(),
            CkbReleaseFullRunner(2), config, FileKnowledgeStore(matrixFetchRoot),
            ckbReleaseTestManifest())
        let matrixManifest = service.activeVersionManifest()

        var faultIndex: Int64 = 0
        for (point in [CkbActiveSnapshotFaultPoints.MANIFEST,
            CkbActiveSnapshotFaultPoints.FRESHNESS,
            CkbActiveSnapshotFaultPoints.COVERAGE,
            CkbActiveSnapshotFaultPoints.COMMIT,
            CkbActiveSnapshotFaultPoints.POINTER_BEFORE]) {
            let beforeVersion = store.loadActiveSnapshotPointer().activeVersion
            let faultKb = newKnowledgeBaseFromStore(store).kb
            let candidateVersion = "ckb-p5-s5-e2e-pre-${faultIndex}-candidate"
            let bundle = ckbPrepareReleaseCommitBundle(ckbReleaseTestProfile(), matrixFetch,
                matrixManifest, candidateVersion,
                cangjieActiveVersionForCandidate(candidateVersion),
                ArrayList<String>(), ArrayList<String>())
            @Expect(bundle.valid, true)
            let failed = cangjiePromoteCandidateRecordsAfterValidationWithVersion(
                faultKb, store, candidateVersion, store.loadActiveSnapshot().activeIndex,
                releaseBundle: bundle,
                snapshotFaultInjector: CkbS5FaultInjector(point))
            @Expect(failed.ok, false)
            @Expect(failed.activePromoted, false)
            @Expect(failed.validation.ok, false)
            @Expect(failed.snapshotPointerCommitted, false)
            @Expect(failed.activeVersion, beforeVersion)
            @Expect(faultKb.status().activeKnowledgeVersion, beforeVersion)
            @Expect(store.loadActiveSnapshotPointer().txId, successPointer.txId)
            @Expect(ckbS5AuthoritativeSnapshotEvidence(store), successEvidence)
            let failedReload = newKnowledgeBaseFromStore(store)
            @Expect(failedReload.source, "persisted")
            @Expect(failedReload.kb.status().candidateKnowledgeVersion,
                failed.candidateVersion)
            @Expect(failedReload.kb.status().failedCandidateVersion,
                failed.candidateVersion)
            let failedArtifact = store.readText(
                "candidate-artifacts/${failed.candidateVersion}/status.ckb")
            @Expect(failedArtifact.contains("activeVersion=${beforeVersion}"), true)
            @Expect(failedArtifact.contains("state=failed"), true)
            @Expect(ckbReleaseTestDiagnosticsContain(failed.validation.diagnostics,
                "candidate_staging_deleted:"), true)
            faultIndex += 1
        }

        let pointerAfterKb = newKnowledgeBaseFromStore(store).kb
        let pointerAfterCandidate = "ckb-p5-s5-e2e-pointer-after-candidate"
        let pointerAfterBundle = ckbPrepareReleaseCommitBundle(ckbReleaseTestProfile(),
            matrixFetch, matrixManifest, pointerAfterCandidate,
            cangjieActiveVersionForCandidate(pointerAfterCandidate),
            ArrayList<String>(), ArrayList<String>())
        let pointerAfter = cangjiePromoteCandidateRecordsAfterValidationWithVersion(
            pointerAfterKb, store, pointerAfterCandidate,
            store.loadActiveSnapshot().activeIndex,
            releaseBundle: pointerAfterBundle,
            snapshotFaultInjector: CkbS5FaultInjector(CkbActiveSnapshotFaultPoints.POINTER_AFTER))
        @Expect(pointerAfter.ok, true)
        @Expect(pointerAfter.activePromoted, true)
        @Expect(pointerAfter.validation.ok, true)
        @Expect(pointerAfter.validation.status, "candidate_validation_passed")
        @Expect(pointerAfter.snapshotPointerCommitted, true)
        @Expect(pointerAfter.snapshotLiveShadowConsistent, true)
        @Expect(store.loadActiveSnapshotPointer().activeVersion, pointerAfter.activeVersion)
        @Expect(newKnowledgeBaseFromStore(store).source, "persisted")
        let pointerAfterStatus = pointerAfterKb.vectorCollectionStatus(
            store.loadActiveSnapshotPointer().vectorActiveCollection)
        @Expect(pointerAfterStatus.state, EmbeddingProviderState.READY)
        @Expect(pointerAfterStatus.count, store.loadActiveSnapshot().activeIndex.size)

        let liveKb = newKnowledgeBaseFromStore(store).kb
        let liveCandidate = "ckb-p5-s5-e2e-live-shadow-candidate"
        let liveBundle = ckbPrepareReleaseCommitBundle(ckbReleaseTestProfile(), matrixFetch,
            matrixManifest, liveCandidate, cangjieActiveVersionForCandidate(liveCandidate),
            ArrayList<String>(), ArrayList<String>())
        let rolledForward = cangjiePromoteCandidateRecordsAfterValidationWithVersion(
            liveKb, store, liveCandidate,
            store.loadActiveSnapshot().activeIndex,
            releaseBundle: liveBundle,
            snapshotFaultInjector: CkbS5FaultInjector(CkbActiveSnapshotFaultPoints.LIVE_SHADOW))
        @Expect(rolledForward.ok, true)
        @Expect(rolledForward.activePromoted, true)
        @Expect(rolledForward.validation.ok, true)
        @Expect(rolledForward.validation.status, "candidate_validation_passed")
        @Expect(rolledForward.snapshotPointerCommitted, true)
        @Expect(rolledForward.snapshotLiveShadowConsistent, false)
        @Expect(ckbReleaseTestDiagnosticsContain(rolledForward.validation.diagnostics,
            "candidate_active_live_shadow_degraded"), true)
        let liveVectorStatus = liveKb.vectorCollectionStatus(
            store.loadActiveSnapshotPointer().vectorActiveCollection)
        @Expect(liveVectorStatus.state, EmbeddingProviderState.READY)
        @Expect(liveVectorStatus.count, store.loadActiveSnapshot().activeIndex.size)
        @Expect(newKnowledgeBaseFromStore(store).source, "persisted")
        @Expect(store.loadActiveCangjieVersionManifest().sources.size, 5)
        @Expect(store.loadActiveCangjieCorpusFreshness().sources.size, 5)
        let reloadedService = CkbCommandLoopService(config, store,
            sourceRunner: DisabledNetworkFetchRunner())
        @Expect(reloadedService.cangjieCorpusFreshness().activeKnowledgeVersion,
            rolledForward.activeVersion)
        @Expect(reloadedService.queryEvidencePack("new-a-token", 5).citations.size > 0, true)
    }
}

private class CkbS5ReleaseFixture {
    var config: CkbRuntimeConfig = CkbRuntimeConfig()
    var store: FileKnowledgeStore = FileKnowledgeStore("target/p5-s5-unused")
    var kb: KnowledgeBase = newOfflineKnowledgeBase()
    var task: SchedulerTaskResult = SchedulerTaskResult()

    init() {}
}

private func ckbS5Config(evalRoot: String): CkbRuntimeConfig {
    let config = CkbRuntimeConfig()
    config.networkEnabled = true
    config.firstInitEvalRoot = evalRoot
    config.firstInitTargetVersion = "1.0.0"
    config.benchmarkGapTargetVersion = "1.0.0"
    config
}

private func ckbS5CopyManifest(source: CangjieVersionManifest): CangjieVersionManifest {
    let out = CangjieVersionManifest()
    out.manifestVersion = source.manifestVersion
    out.defaultTargetVersion = source.defaultTargetVersion
    out.degraded = source.degraded
    for (diagnostic in source.diagnostics) { out.diagnostics.add(diagnostic) }
    for (item in source.sources) {
        let copied = CangjieVersionSource()
        copied.targetVersion = item.targetVersion
        copied.sourceSet = item.sourceSet
        copied.sourceFamily = item.sourceFamily
        copied.sourceRepo = item.sourceRepo
        copied.sourceRef = item.sourceRef
        copied.refKind = item.refKind
        copied.resolvedCommit = item.resolvedCommit
        copied.contentHash = item.contentHash
        copied.rootKind = item.rootKind
        out.sources.add(copied)
    }
    out
}

private func ckbS5StringsUnique(values: ArrayList<String>): Bool {
    let seen = HashSet<String>()
    for (value in values) {
        if (seen.contains(value)) { return false }
        seen.add(value)
    }
    true
}

private func ckbS5RootAtomicTmpCount(root: String): Int64 {
    var count: Int64 = 0
    for (entry in Directory.readFrom(Path(root))) {
        if (entry.name.startsWith(".tmp-")) { count += 1 }
    }
    count
}

private func ckbS5ReleaseFixture(root: String, generation: Int64): CkbS5ReleaseFixture {
    ckbReleaseTestEnsureEmptyDir(root)
    let fixture = CkbS5ReleaseFixture()
    let evalRoot = "${root}/eval"
    ckbReleaseTestWriteEvalFixture(evalRoot)
    fixture.config = ckbS5Config(evalRoot)
    fixture.store = FileKnowledgeStore("${root}/store")
    fixture.store.saveCangjieVersionManifest(ckbReleaseTestManifest())
    fixture.kb = newOfflineKnowledgeBase()
    fixture.task = CkbSchedulerTaskRunner(fixture.kb, fixture.config, fixture.store,
        sourceRunner: CkbReleaseFullRunner(generation)).runTask(
        "cangjie_release_full_sync", "0", ckbCoreNowMillis() + 435000)
    fixture
}

private func ckbS5ActiveCompanionEvidence(store: FileKnowledgeStore): String {
    let pointer = store.loadActiveSnapshotPointer()
    if (!pointer.valid) { return "invalid:${pointer.diagnostic}" }
    let txRoot = "transactions/${pointer.txId}"
    "tx=${pointer.txId}|pointer=${ckbReleaseEvidenceHash(store.readText("metadata/active-snapshot.manifest"))}|" +
        "manifest=${ckbReleaseEvidenceHash(store.readText("${txRoot}/metadata/cangjie-version-manifest.ckb"))}|" +
        "freshness=${ckbReleaseEvidenceHash(store.readText("${txRoot}/metadata/cangjie-freshness.ckb"))}|" +
        "coverage=${ckbReleaseEvidenceHash(store.readText("${txRoot}/metadata/cangjie-release-coverage.ckb"))}|" +
        "liveManifest=${ckbReleaseEvidenceHash(store.readText("metadata/active-cangjie-version-manifest.ckb"))}|" +
        "liveFreshness=${ckbReleaseEvidenceHash(store.readText("metadata/active-cangjie-freshness.ckb"))}|" +
        "liveCoverage=${ckbReleaseEvidenceHash(store.readText("metadata/active-cangjie-release-coverage.ckb"))}|" +
        "liveStatus=${ckbReleaseEvidenceHash(store.readText("metadata/status.ckb"))}|" +
        "liveRaw=${ckbReleaseEvidenceHash(store.readText("raw/records.ckb"))}|" +
        "liveIndex=${ckbReleaseEvidenceHash(store.readText("index/active.ckb"))}|" +
        "planningManifest=${ckbReleaseEvidenceHash(store.readText("metadata/cangjie-version-manifest.ckb"))}|" +
        "operationalFreshness=${ckbReleaseEvidenceHash(store.readText("metadata/cangjie-freshness.ckb"))}"
}

private func ckbS5AuthoritativeSnapshotEvidence(store: FileKnowledgeStore): String {
    let pointer = store.loadActiveSnapshotPointer()
    if (!pointer.valid) { return "invalid:${pointer.diagnostic}" }
    let txRoot = "transactions/${pointer.txId}"
    "tx=${pointer.txId}|pointer=${ckbReleaseEvidenceHash(store.readText("metadata/active-snapshot.manifest"))}|" +
        "manifest=${ckbReleaseEvidenceHash(store.readText("${txRoot}/metadata/cangjie-version-manifest.ckb"))}|" +
        "freshness=${ckbReleaseEvidenceHash(store.readText("${txRoot}/metadata/cangjie-freshness.ckb"))}|" +
        "coverage=${ckbReleaseEvidenceHash(store.readText("${txRoot}/metadata/cangjie-release-coverage.ckb"))}|" +
        "liveManifest=${ckbReleaseEvidenceHash(store.readText("metadata/active-cangjie-version-manifest.ckb"))}|" +
        "liveFreshness=${ckbReleaseEvidenceHash(store.readText("metadata/active-cangjie-freshness.ckb"))}|" +
        "liveCoverage=${ckbReleaseEvidenceHash(store.readText("metadata/active-cangjie-release-coverage.ckb"))}|" +
        "activeStatus=${ckbReleaseEvidenceHash(ckbS5ActiveOnlyStatusEvidence(store.readText("metadata/status.ckb")))}|" +
        "liveRaw=${ckbReleaseEvidenceHash(store.readText("raw/records.ckb"))}|" +
        "liveIndex=${ckbReleaseEvidenceHash(store.readText("index/active.ckb"))}"
}

private func ckbS5ActiveOnlyStatusEvidence(text: String): String {
    let out = StringBuilder()
    for (line in text.split("\n")) {
        if (line.startsWith("active=") || line.startsWith("activeStateSource=") ||
            line.startsWith("rawCount=") || line.startsWith("normalizedCount=") ||
            line.startsWith("indexCount=") || line.startsWith("textIndexCount=") ||
            line.startsWith("vectorIndexCount=") || line.startsWith("symbolIndexCount=") ||
            line.startsWith("graphIndexCount=") || line.startsWith("vectorBackend=") ||
            line.startsWith("vectorState=") || line.startsWith("vectorCollection=") ||
            line.startsWith("vectorActiveCollection=") || line.startsWith("vectorDimension=") ||
            line.startsWith("vectorDegradedReason=") || line.startsWith("graphBackend=") ||
            line.startsWith("graphState=") || line.startsWith("graphNodeCount=") ||
            line.startsWith("graphEdgeCount=") || line.startsWith("indexManifestActive=")) {
            out.append(line)
            out.append("\n")
        }
    }
    out.toString()
}

private func ckbS5LiveShadowEqualsTransaction(store: FileKnowledgeStore,
    pointer: CkbActiveSnapshotPointer): Bool {
    if (!pointer.valid) { return false }
    let txRoot = "transactions/${pointer.txId}"
    let vectorRelative = "index/vector-${pointer.vectorActiveCollection}.ckb"
    store.readText("raw/records.ckb") == store.readText("${txRoot}/raw/records.ckb") &&
        store.readText("normalized/records.ckb") == store.readText("${txRoot}/normalized/records.ckb") &&
        store.readText("index/active.version") == store.readText("${txRoot}/index/active.version") &&
        store.readText("index/active.ckb") == store.readText("${txRoot}/index/active.ckb") &&
        store.readText("index/graph-nodes.ckb") == store.readText("${txRoot}/index/graph-nodes.ckb") &&
        store.readText("index/graph-edges.ckb") == store.readText("${txRoot}/index/graph-edges.ckb") &&
        store.readText("metadata/status.ckb") == store.readText("${txRoot}/metadata/status.ckb") &&
        store.readText(vectorRelative) == store.readText("${txRoot}/${vectorRelative}") &&
        store.readText("metadata/active-cangjie-version-manifest.ckb") ==
            store.readText("${txRoot}/metadata/cangjie-version-manifest.ckb") &&
        store.readText("metadata/active-cangjie-freshness.ckb") ==
            store.readText("${txRoot}/metadata/cangjie-freshness.ckb") &&
        store.readText("metadata/active-cangjie-release-coverage.ckb") ==
            store.readText("${txRoot}/metadata/cangjie-release-coverage.ckb")
}

private func ckbS5WriteCopyForward(store: FileKnowledgeStore,
    point: String): CkbActiveSnapshotTransactionResult {
    let loaded = newKnowledgeBaseFromStore(store)
    let snapshot = store.loadActiveSnapshot()
    let graph = loaded.kb.activeGraphBuild()
    store.writeActiveSnapshotTransaction(loaded.kb.status(), snapshot.rawRecords,
        snapshot.normalizedRecords, snapshot.activeIndex, snapshot.vectorRecords,
        snapshot.vectorActiveCollection, graph,
        persistVectorFile: snapshot.hasVectorArtifact,
        faultInjector: CkbS5FaultInjector(point))
}

private func ckbS5RehashReleaseBundle(bundle: CkbReleaseCommitBundle): Unit {
    bundle.manifestEvidenceHash = ckbReleaseCompanionEvidenceHash(
        ckbRenderCangjieVersionManifestArtifact(bundle.manifest))
    bundle.freshnessEvidenceHash = ckbReleaseCompanionEvidenceHash(
        ckbRenderCangjieFreshnessArtifact(bundle.freshness))
    bundle.coverageEvidenceHash = ckbReleaseCompanionEvidenceHash(
        ckbRenderReleaseCoverageArtifact(bundle.coverage, bundle.removed))
    bundle.evidenceHash = ckbReleaseCompanionEvidenceHash(
        "manifest=${bundle.manifestEvidenceHash}|freshness=${bundle.freshnessEvidenceHash}|" +
        "coverage=${bundle.coverageEvidenceHash}|removed=${bundle.removed.aggregateEvidenceHash}|" +
        "candidate=${bundle.candidateVersion}|active=${bundle.activeVersion}")
}

private class CkbS5FaultInjector <: CkbActiveSnapshotFaultInjector {
    let point: String

    init(point: String) { this.point = point }

    public func checkpoint(point: String): Unit {
        if (point == this.point) { throw Exception("fixture_fault:${point}") }
    }
}

private class CkbS5FrozenTxClock <: CkbActiveSnapshotTxClock {
    let value: Int64
    init(value: Int64) { this.value = value }
    public func nowMillis(): Int64 { this.value }
}

private class CkbS5DownEmbeddingProvider <: EmbeddingProvider {
    public var calls: Int64 = 0

    public func embed(texts: ArrayList<String>, model: String,
        dimensions: Int64): EmbeddingBatch {
        this.calls += 1
        let batch = EmbeddingBatch()
        batch.requested = texts.size
        batch.failed = texts.size
        batch.status = this.status()
        batch
    }

    public func embedWithDeadline(texts: ArrayList<String>, model: String,
        dimensions: Int64, deadlineAtMillis: Int64): EmbeddingBatch {
        this.embed(texts, model, dimensions)
    }

    public func status(): EmbeddingStatus {
        let status = EmbeddingStatus()
        status.provider = "fixture-down"
        status.model = "fixture"
        status.dimensions = 16
        status.batchSize = 4
        status.production = true
        status.state = EmbeddingProviderState.DOWN
        status.degradedReason = "fixture_embedding_down"
        status
    }
}

private func ckbS5ReadyVectorStatus(records: ArrayList<NormalizedRecord>): VectorStoreStatus {
    let status = VectorStoreStatus()
    status.backend = "local-file"
    status.collection = "candidate"
    status.activeCollection = "active"
    status.candidateCollection = "candidate"
    status.dimension = 16
    status.count = records.size
    status.state = EmbeddingProviderState.READY
    status
}

private func ckbS5BackupFixture(store: FileKnowledgeStore, backupRoot: String): String {
    ckbReleaseTestEnsureEmptyDir(backupRoot)
    _ = store.backupActiveSnapshot(backupRoot)
    backupRoot
}

private func ckbS5TamperedClone(source: FileKnowledgeStore, root: String,
    mode: String): FileKnowledgeStore {
    let backupRoot = "${root}-backup"
    ckbReleaseTestEnsureEmptyDir(backupRoot)
    ckbReleaseTestEnsureEmptyDir(root)
    _ = source.backupActiveSnapshot(backupRoot)
    let store = FileKnowledgeStore(root)
    _ = store.restoreActiveSnapshotBackup(backupRoot)
    let pointer = store.loadActiveSnapshotPointer()
    if (mode == "pointer_committed") {
        store.writeLinesAtomically("metadata/active-snapshot.manifest",
            store.readText("metadata/active-snapshot.manifest").replace(
                "committed=true", "committed=false"))
    } else if (mode == "commit_persist") {
        store.writeLinesAtomically("transactions/${pointer.txId}/COMMIT",
            store.readText("transactions/${pointer.txId}/COMMIT").replace(
                "persistVectorFile=true", "persistVectorFile=invalid"))
    } else if (mode == "commit_schema") {
        store.writeLinesAtomically("transactions/${pointer.txId}/COMMIT",
            ckbS5RemoveLines(store.readText("transactions/${pointer.txId}/COMMIT"),
                ["schema="]))
    } else if (mode == "companion_utf8") {
        File.writeTo(Path(root).join(
            "transactions/${pointer.txId}/metadata/cangjie-version-manifest.ckb"),
            [UInt8(255), UInt8(254), UInt8(253)])
    } else if (mode == "payload_utf8") {
        File.writeTo(Path(root).join("transactions/${pointer.txId}/index/active.ckb"),
            [UInt8(255), UInt8(254), UInt8(253)])
    } else if (mode == "pointer_zero") {
        File.writeTo(Path(root).join("metadata/active-snapshot.manifest"),
            "".toArray())
    } else if (mode == "pointer_whitespace") {
        store.writeLinesAtomically("metadata/active-snapshot.manifest", " \n\t\n")
    } else if (mode == "pointer_garbage") {
        store.writeLinesAtomically("metadata/active-snapshot.manifest",
            "garbage=中文🙂\n")
    }
    store
}

private func ckbS5RemoveLines(text: String, prefixes: Array<String>): String {
    let out = StringBuilder()
    for (line in text.split("\n")) {
        if (line == "") { continue }
        var remove = false
        for (prefix in prefixes) {
            if (line.startsWith(prefix)) { remove = true }
        }
        if (!remove) { out.append("${line}\n") }
    }
    out.toString()
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
            result.body = "[{\"name\":\"release-1.0.0\",\"commit\":{\"id\":\"${this.commit()}\"}}]"
        } else if (request.kind == SourceKinds.GITCODE_TREE) {
            result.contentType = "application/json"
            result.body = if (request.page == 1) { this.treeBody(request.repo) } else { "[]" }
        } else if (request.kind == SourceKinds.GITCODE_SOURCE) {
            result.contentType = if (request.path.endsWith(".cj")) { "text/plain" } else { "text/markdown" }
            result.body = this.contentBody(request.repo, request.path)
            result.commit = this.commit()
        }
        result
    }

    private func commit(): String {
        if (this.generation == 1) {
            "1111111111111111111111111111111111111111"
        } else {
            "2222222222222222222222222222222222222222"
        }
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

private class CkbS5GenericDeltaRunner <: SourceFetchRunner {
    public static let UNIQUE_TOKEN = "p5-s5-generic-v2-only-token"
    private let delegate = CkbReleaseFullRunner(2)
    public var calls: Int64 = 0

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        this.calls += 1
        let result = this.delegate.fetch(request)
        if (request.kind == SourceKinds.GITCODE_SOURCE &&
            request.repo == "Cangjie/cangjie_runtime") {
            result.contentType = "text/plain"
            result.body = "package runtime_fixture\npublic func p5S5GenericV2Only(): Unit {}\n// ${CkbS5GenericDeltaRunner.UNIQUE_TOKEN}\n"
            result.bodyHash = stableSummaryHash(result.body)
        }
        result
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
