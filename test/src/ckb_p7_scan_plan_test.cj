package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}
import std.process.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbP7ScanPlanTest {
    @TestCase
    public func p7S2U01BuildsStable440PlanWithThreeBoundedBatches(): Unit {
        let records = p7S2Records(440)
        let one = ckbBuildBenchmarkGapScanPlan(records, "canonical-中文🙂-440", "1.0.0")
        let two = ckbBuildBenchmarkGapScanPlan(records, "canonical-中文🙂-440", "1.0.0")

        @Expect(one.valid, true)
        @Expect(one.schemaVersion, "ckb-benchmark-gap-scan-plan-v1")
        @Expect(one.total, 440)
        @Expect(one.batchSize, 200)
        @Expect(one.nextOffset, 0)
        @Expect(one.inputSha256.size, 64)
        @Expect(one.planHash.size, 64)
        @Expect(one.planHash, two.planHash)
        @Expect(one.checksum, two.checksum)
        @Expect(ckbBenchmarkGapBatchEnd(440, 0, 200), 200)
        @Expect(ckbBenchmarkGapBatchEnd(440, 200, 200), 400)
        @Expect(ckbBenchmarkGapBatchEnd(440, 400, 200), 440)

        records[439].sourceId = "changed-canonical-source"
        let changed = ckbBuildBenchmarkGapScanPlan(records, "canonical-中文🙂-440", "1.0.0")
        @Expect(changed.planHash == one.planHash, false)

        let contentRecords = p7S2Records(440)
        contentRecords[439].chunk += "\nKnowledge: changed transformation 中文🙂"
        let contentChanged = ckbBuildBenchmarkGapScanPlan(contentRecords, "canonical-中文🙂-440", "1.0.0")
        @Expect(contentChanged.planHash == one.planHash, false)
    }

    @TestCase
    public func p7S2B01BatchRangesCoverZeroOne199200201And440ExactlyOnce(): Unit {
        let totals: Array<Int64> = [0, 1, 199, 200, 201, 440]
        let expected: Array<String> = ["", "1", "199", "200", "200,1", "200,200,40"]
        for (i in 0..totals.size) {
            let total = totals[i]
            var offset: Int64 = 0
            let sizes = ArrayList<String>()
            var covered: Int64 = 0
            while (offset < total) {
                let end = ckbBenchmarkGapBatchEnd(total, offset, ckbBenchmarkGapCurationBatchSize())
                @Expect(end > offset, true)
                sizes.add("${end - offset}")
                covered += end - offset
                offset = end
            }
            @Expect(p7S2Join(sizes), expected[i])
            @Expect(covered, total)
            @Expect(offset, total)
        }
    }

    @TestCase
    public func p7S2P01ClaimCheckpointReloadAdvancesRevisionAndOwner(): Unit {
        let root = "target/p7-s2-p01-claim-reload"
        p7S2Empty(root)
        let store = FileKnowledgeStore(root)
        let built = ckbBuildBenchmarkGapScanPlan(p7S2Records(440), "claim-440", "1.0.0")
        let saved = ckbSaveBenchmarkGapScanPlan(store, built)
        let first = ckbClaimBenchmarkGapScanPlan(store, saved.planHash, saved.inputSha256, saved.targetVersion, "owner-a", 100, 20)
        let held = ckbClaimBenchmarkGapScanPlan(store, saved.planHash, saved.inputSha256, saved.targetVersion, "owner-b", 101, 20)
        let checkpoint = ckbCheckpointBenchmarkGapScanPlan(store, saved.planHash, saved.inputSha256, saved.targetVersion, "owner-a", first.plan.revision, 0, 200, 102)
        let reloadedStore = FileKnowledgeStore(root)
        let second = ckbClaimBenchmarkGapScanPlan(reloadedStore, saved.planHash, saved.inputSha256, saved.targetVersion, "owner-b", 103, 20)

        @Expect(first.claimed, true)
        @Expect(first.startOffset, 0)
        @Expect(first.endOffset, 200)
        @Expect(first.plan.revision, 1)
        @Expect(held.claimed, false)
        @Expect(held.errorCode, "benchmark_gap_scan_plan_lease_held")
        @Expect(checkpoint.valid, true)
        @Expect(checkpoint.nextOffset, 200)
        @Expect(checkpoint.revision, 2)
        @Expect(checkpoint.state, "checkpointed")
        @Expect(second.claimed, true)
        @Expect(second.startOffset, 200)
        @Expect(second.endOffset, 400)
        @Expect(second.plan.revision, 3)
        @Expect(second.plan.owner, "owner-b")
    }

    @TestCase
    public func p7S2N01RejectsCorruptionIdentityLeaseStaleRevisionAndWriteFailure(): Unit {
        let root = "target/p7-s2-n01-fail-closed"
        p7S2Empty(root)
        let store = FileKnowledgeStore(root)
        let built = ckbBuildBenchmarkGapScanPlan(p7S2Records(201), "negative-201", "1.0.0")
        let saved = ckbSaveBenchmarkGapScanPlan(store, built)
        let wrongInput = ckbLoadBenchmarkGapScanPlan(store, saved.planHash, ckbReleaseEvidenceHash("different"), saved.targetVersion)
        let first = ckbClaimBenchmarkGapScanPlan(store, saved.planHash, saved.inputSha256, saved.targetVersion, "owner-a", 1000, 50)
        let held = ckbClaimBenchmarkGapScanPlan(store, saved.planHash, saved.inputSha256, saved.targetVersion, "owner-b", 1001, 50)
        let stale = ckbCheckpointBenchmarkGapScanPlan(store, saved.planHash, saved.inputSha256, saved.targetVersion, "owner-a", first.plan.revision - 1, 0, 200, 1002)
        let stillZero = ckbLoadBenchmarkGapScanPlan(store, saved.planHash, saved.inputSha256, saved.targetVersion)

        @Expect(wrongInput.valid, false)
        @Expect(wrongInput.errorCode, "benchmark_gap_scan_plan_identity_mismatch")
        @Expect(held.claimed, false)
        @Expect(held.errorCode, "benchmark_gap_scan_plan_lease_held")
        @Expect(stale.valid, false)
        @Expect(stale.errorCode, "benchmark_gap_scan_plan_revision_conflict")
        @Expect(stillZero.nextOffset, 0)

        let planPath = "metadata/benchmark-gap-curation/plans/${saved.planHash}.ckb"
        let original = store.readText(planPath)
        store.writeLinesAtomically(planPath, original.replace("checksum=${stillZero.checksum}", "checksum=broken"))
        let corrupt = ckbLoadBenchmarkGapScanPlan(store, saved.planHash, saved.inputSha256, saved.targetVersion)
        @Expect(corrupt.valid, false)
        @Expect(corrupt.errorCode, "benchmark_gap_scan_plan_checksum_mismatch")

        File.writeTo(Path(root).join(planPath), [UInt8(255), UInt8(254), UInt8(253)])
        let binary = ckbLoadBenchmarkGapScanPlan(store, saved.planHash, saved.inputSha256, saved.targetVersion)
        @Expect(binary.valid, false)
        @Expect(binary.errorCode, "benchmark_gap_scan_plan_invalid_response_encoding")

        let writeRoot = "target/p7-s2-n01-write-failure"
        p7S2Empty(writeRoot)
        let writeStore = FileKnowledgeStore(writeRoot)
        Directory.create(Path(writeRoot).join("metadata/benchmark-gap-curation"), recursive: true)
        File.writeTo(Path(writeRoot).join("metadata/benchmark-gap-curation/plans"), "not-a-directory".toArray())
        let writeFailed = ckbSaveBenchmarkGapScanPlan(writeStore,
            ckbBuildBenchmarkGapScanPlan(p7S2Records(1), "write-failure", "1.0.0"))
        @Expect(writeFailed.valid, false)
        @Expect(writeFailed.errorCode, "benchmark_gap_scan_plan_write_failed")
    }

    @TestCase
    public func p7E2E02CrashBeforeAndAfterCheckpointResumesOnlyConfirmedOffset(): Unit {
        let root = "target/p7-e2e02-scan-crash-resume"
        p7S2Empty(root)
        let store = FileKnowledgeStore(root)
        let saved = ckbSaveBenchmarkGapScanPlan(store,
            ckbBuildBenchmarkGapScanPlan(p7S2Records(440), "crash-resume-440", "1.0.0"))
        let crashed = ckbClaimBenchmarkGapScanPlan(store, saved.planHash, saved.inputSha256, saved.targetVersion, "crashed-owner", 100, 10)
        let recovered = ckbClaimBenchmarkGapScanPlan(FileKnowledgeStore(root), saved.planHash, saved.inputSha256, saved.targetVersion, "recovered-owner", 111, 10)
        let one = ckbCheckpointBenchmarkGapScanPlan(store, saved.planHash, saved.inputSha256, saved.targetVersion, "recovered-owner", recovered.plan.revision, 0, 200, 112)
        let twoClaim = ckbClaimBenchmarkGapScanPlan(FileKnowledgeStore(root), saved.planHash, saved.inputSha256, saved.targetVersion, "owner-2", 113, 10)
        let two = ckbCheckpointBenchmarkGapScanPlan(store, saved.planHash, saved.inputSha256, saved.targetVersion, "owner-2", twoClaim.plan.revision, 200, 400, 114)
        let threeClaim = ckbClaimBenchmarkGapScanPlan(FileKnowledgeStore(root), saved.planHash, saved.inputSha256, saved.targetVersion, "owner-3", 115, 10)
        let complete = ckbCheckpointBenchmarkGapScanPlan(store, saved.planHash, saved.inputSha256, saved.targetVersion, "owner-3", threeClaim.plan.revision, 400, 440, 116)

        @Expect(crashed.startOffset, 0)
        @Expect(recovered.startOffset, 0)
        @Expect(one.nextOffset, 200)
        @Expect(twoClaim.startOffset, 200)
        @Expect(two.nextOffset, 400)
        @Expect(threeClaim.startOffset, 400)
        @Expect(threeClaim.endOffset, 440)
        @Expect(complete.valid, true)
        @Expect(complete.state, "complete")
        @Expect(complete.nextOffset, 440)
    }

    @TestCase
    public func p7E2E03TenClaimantsProduceOneOwnerAndOneTerminalPlan(): Unit {
        let root = "target/p7-e2e03-scan-cas"
        p7S2Empty(root)
        let store = FileKnowledgeStore(root)
        let saved = ckbSaveBenchmarkGapScanPlan(store,
            ckbBuildBenchmarkGapScanPlan(p7S2Records(440), "cas-440", "1.0.0"))
        var claims: Int64 = 0
        var held: Int64 = 0
        var ownerClaim = CkbBenchmarkGapScanClaimResult()
        for (i in 0..10) {
            let claim = ckbClaimBenchmarkGapScanPlan(FileKnowledgeStore(root), saved.planHash,
                saved.inputSha256, saved.targetVersion, "owner-${i}", 100, 50)
            if (claim.claimed) { claims += 1; ownerClaim = claim } else if (claim.errorCode == "benchmark_gap_scan_plan_lease_held") { held += 1 }
        }
        @Expect(claims, 1)
        @Expect(held, 9)
        var current = ckbCheckpointBenchmarkGapScanPlan(store, saved.planHash, saved.inputSha256,
            saved.targetVersion, ownerClaim.plan.owner, ownerClaim.plan.revision, 0, 200, 101)
        for (round in 1..3) {
            let claim = ckbClaimBenchmarkGapScanPlan(store, saved.planHash, saved.inputSha256,
                saved.targetVersion, "round-${round}", 101 + round * 2, 50)
            current = ckbCheckpointBenchmarkGapScanPlan(store, saved.planHash, saved.inputSha256,
                saved.targetVersion, claim.plan.owner, claim.plan.revision, claim.startOffset, claim.endOffset, 102 + round * 2)
        }
        let terminal = ckbClaimBenchmarkGapScanPlan(store, saved.planHash, saved.inputSha256,
            saved.targetVersion, "late-owner", 200, 50)
        @Expect(current.state, "complete")
        @Expect(current.nextOffset, 440)
        @Expect(terminal.claimed, false)
        @Expect(terminal.errorCode, "benchmark_gap_scan_plan_terminal")
    }
}

private func p7S2Records(count: Int64): ArrayList<NormalizedRecord> {
    let inputs = ArrayList<CangjieBenchmarkGapInput>()
    for (i in 0..count) {
        let input = CangjieBenchmarkGapInput()
        input.caseId = "CJ-HUMANEVAL-P7-${i}"
        input.benchmark = "Cangjie-HumanEval"
        input.taskText = "Use ArrayList.add for 中文🙂 visible input ${i}."
        input.visibleTestExcerpt = "assert solve([1,2]) == 3"
        input.compilerOutput = "compile_error"
        input.missingKnowledge = "G-ARRAYLIST"
        input.interfaceId = "KI-02"
        input.contentFamily = "KC-02"
        input.updateMechanism = "KU-11"
        input.targetVersion = "1.0.0"
        input.officialCitation = "https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection"
        inputs.add(input)
    }
    let curated = curateBenchmarkGapRecords(inputs, targetVersion: "1.0.0")
    if (!curated.ok) { return ArrayList<NormalizedRecord>() }
    curated.records
}

private func p7S2Empty(path: String): Unit {
    if (exists(Path(path))) { _ = launch("/bin/rm", ["-rf", path]).wait() }
    Directory.create(Path(path), recursive: true)
}

private func p7S2Join(values: ArrayList<String>): String {
    var out = ""
    for (i in 0..values.size) { if (i > 0) { out += "," }; out += values[i] }
    out
}
