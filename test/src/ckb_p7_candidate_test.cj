package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, Path, exists}
import std.process.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbP7CandidateTest {
    @TestCase
    public func p7S3U01PreviewBuildsOneIndexFor440Queries(): Unit {
        let records = p7S3Records(440)
        let preview = ckbBenchmarkGapPreviewAll(records, records)
        @Expect(preview.ok, true)
        @Expect(preview.indexBuildCount, 1)
        @Expect(preview.queryCount, 440)
        @Expect(preview.passed, 440)
    }

    @TestCase
    public func p7S3B01PreviewHandlesOneTwoHundredAndUnicodeBoundary(): Unit {
        for (count in [Int64(1), Int64(200)]) {
            let records = p7S3Records(count)
            let preview = ckbBenchmarkGapPreviewAll(records, records)
            @Expect(preview.ok, true)
            @Expect(preview.indexBuildCount, 1)
            @Expect(preview.queryCount, count)
        }
        let unicode = p7S3Records(1)
        unicode[0].chunk += "\n中文🙂"
        @Expect(ckbBenchmarkGapPreviewAll(unicode, unicode).ok, true)
    }

    @TestCase
    public func p7S3P01BatchArtifactPrecedesCursorAndAggregates440(): Unit {
        let root = "target/p7-s3-p01"
        p7S3Empty(root)
        let store = FileKnowledgeStore(root)
        let records = p7S3Records(440)
        let plan = ckbSaveBenchmarkGapScanPlan(store,
            ckbBuildBenchmarkGapScanPlan(records, "p7-s3-440", "1.0.0"))
        var current = plan
        var now: Int64 = 100
        while (current.state != "complete") {
            let claim = ckbClaimBenchmarkGapScanPlan(store, plan.planHash, plan.inputSha256,
                plan.targetVersion, "owner", now, 50)
            let batch = ckbSaveBenchmarkGapCandidateBatch(store, plan, records,
                claim.startOffset, claim.endOffset)
            @Expect(batch.ok, true)
            current = ckbCheckpointBenchmarkGapScanPlan(store, plan.planHash, plan.inputSha256,
                plan.targetVersion, "owner", claim.plan.revision, claim.startOffset,
                claim.endOffset, now + 1)
            now += 2
        }
        let aggregate = ckbLoadBenchmarkGapCandidateBatches(store, plan, records)
        @Expect(current.nextOffset, 440)
        @Expect(aggregate.ok, true)
        @Expect(aggregate.written, 440)
    }

    @TestCase
    public func p7S3N01MissingOrMismatchedTargetFailsClosed(): Unit {
        let records = p7S3Records(2)
        records[1].sourceId = "missing-preview-target"
        records[1].metadata.sourceId = records[1].sourceId
        let missing = ArrayList<NormalizedRecord>()
        missing.add(records[0])
        let preview = ckbBenchmarkGapPreviewAll(missing, records)
        @Expect(preview.ok, false)
        @Expect(preview.errorCode, "benchmark_gap_preview_target_missed")

        let root = "target/p7-s3-n01"
        p7S3Empty(root)
        let store = FileKnowledgeStore(root)
        let plan = ckbSaveBenchmarkGapScanPlan(store,
            ckbBuildBenchmarkGapScanPlan(records, "p7-s3-negative", "1.0.0"))
        @Expect(ckbLoadBenchmarkGapCandidateBatches(store, plan, records).ok, false)
        @Expect(plan.nextOffset, 0)
    }
}

private func p7S3Records(count: Int64): ArrayList<NormalizedRecord> {
    var text = ""
    for (index in 0..count) {
        text += "{\"caseId\":\"CJ-P7-S3-${index}\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"ArrayList task ${index}\",\"compilerOutput\":\"compile_error\",\"missingKnowledge\":\"G-ARRAYLIST\",\"interfaceId\":\"KI-02\",\"contentFamily\":\"KC-02\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"1.0.0\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/\"}\n"
    }
    curateBenchmarkGapRecordsFromJsonl(text).records
}

private func p7S3Empty(root: String): Unit {
    if (exists(Path(root))) { _ = launch("/bin/rm", ["-rf", root]).wait() }
    Directory.create(Path(root), recursive: true)
}
