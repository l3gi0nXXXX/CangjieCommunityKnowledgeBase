package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}
import std.process.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbP7ProofTest {
    @TestCase
    public func p7S4U01TypedProofNeverUsesRendererTextForBusiness(): Unit {
        let record = p7S4Records(1)[0]
        let passed = ckbBenchmarkGapProofForCandidate(record, "candidate-u", "active-u")
        let failed = ckbBenchmarkGapProofForCandidate(record, "candidate-u", "active-u", forcedStatus: "failed")
        let retryable = ckbBenchmarkGapProofForCandidate(record, "candidate-u", "active-u", forcedStatus: "retryable")
        record.metadata.derivedFrom = ["knowledge-atom:G-RANGE"]
        let missingAtom = ckbBenchmarkGapProofForCandidate(record, "candidate-u", "active-u")
        let rendered = ckbRenderBenchmarkGapProofDiagnostic(failed) + ":coveragePass=true"
        @Expect(passed.valid, true); @Expect(passed.status, "passed"); @Expect(passed.coveragePass, true); @Expect(passed.citationCount, 1); @Expect(passed.evidenceHash.size, 64)
        @Expect(failed.valid, true); @Expect(failed.status, "failed"); @Expect(failed.coveragePass, false)
        @Expect(retryable.valid, true); @Expect(retryable.status, "retryable"); @Expect(retryable.errorCode, "candidate_query_retryable")
        @Expect(missingAtom.valid, true); @Expect(missingAtom.status, "failed"); @Expect(missingAtom.errorCode, "candidate_atom_knowledge_missing")
        @Expect(rendered.contains("coveragePass=true"), true); @Expect(failed.coveragePass, false)
    }

    @TestCase
    public func p7S4B01ArtifactPrecedesCursorAndOrphanAdvancesWithoutRequery(): Unit {
        let root = "target/p7-s4-b01-artifact-cursor"; p7S4Empty(root); let store = FileKnowledgeStore(root)
        let records = p7S4Records(5); let plan = p7S4Plan(store, records, "b01")
        let expected = p7S4Checkpoint(plan, records); let initial = ckbSaveBenchmarkGapProofCheckpoint(store, expected)
        let first = ckbClaimBenchmarkGapProofCheckpoint(store, expected, "crash-owner", 100, 10)
        let proof = ckbBenchmarkGapProofForCandidate(records[0], expected.candidateVersion, expected.baseActiveVersion)
        let artifact = ckbSaveBenchmarkGapProofArtifact(store, first.checkpoint, proof)
        let before = ckbLoadBenchmarkGapProofCheckpoint(store, expected)
        let recovered = ckbClaimBenchmarkGapProofCheckpoint(store, expected, "resume-owner", 111, 10)
        let loaded = ckbLoadBenchmarkGapProofArtifact(store, recovered.checkpoint, proof.caseIdentity, proof.recordHash)
        let advanced = ckbAdvanceBenchmarkGapProofCursor(store, recovered.checkpoint, records[0], loaded, 112)
        @Expect(initial.nextProofOffset, 0); @Expect(artifact.valid, true); @Expect(before.nextProofOffset, 0)
        @Expect(recovered.claimed, true); @Expect(loaded.valid, true); @Expect(advanced.valid, true); @Expect(advanced.nextProofOffset, 1)
        @Expect(advanced.aggregateEvidenceHash.size, 64)
    }

    @TestCase
    public func p7S4P01FourHundredFortyProofsResumeWithStableCandidate(): Unit {
        let root = "target/p7-s4-p01-440"; p7S4Empty(root); let store = FileKnowledgeStore(root)
        let records = p7S4Records(440); let plan = p7S4Plan(store, records, "p01"); let expected = p7S4Checkpoint(plan, records)
        _ = ckbSaveBenchmarkGapProofCheckpoint(store, expected)
        var proofCalls: Int64 = 0; var current = expected; var now: Int64 = 1000
        while (true) {
            let loaded = ckbLoadBenchmarkGapProofCheckpoint(FileKnowledgeStore(root), expected)
            if (loaded.valid && loaded.state == "complete") { current = loaded; break }
            let claim = ckbClaimBenchmarkGapProofCheckpoint(FileKnowledgeStore(root), expected, "owner-${now}", now, 20)
            let record = records[claim.checkpoint.nextProofOffset]
            let generated = ckbBenchmarkGapProofForCandidate(record, expected.candidateVersion, expected.baseActiveVersion); proofCalls += 1
            current = ckbAdvanceBenchmarkGapProofCursor(store, claim.checkpoint, record, generated, now + 1)
            now += 2
        }
        @Expect(current.state, "complete"); @Expect(current.nextProofOffset, 440); @Expect(proofCalls, 440)
        @Expect(current.candidateVersion, expected.candidateVersion); @Expect(current.baseActiveVersion, "active-before")
        @Expect(exists(Path(root).join("index/active.ckb")), false)
    }

    @TestCase
    public func p7S4N01WrongBindingsCorruptionUtf8FailureAndLegacyFailClosed(): Unit {
        let root = "target/p7-s4-n01"; p7S4Empty(root); let store = FileKnowledgeStore(root)
        let records = p7S4Records(2); let plan = p7S4Plan(store, records, "n01"); let expected = p7S4Checkpoint(plan, records)
        let saved = ckbSaveBenchmarkGapProofCheckpoint(store, expected)
        let wrong = p7S4Checkpoint(plan, records); wrong.candidateVersion = "wrong-candidate"
        @Expect(ckbLoadBenchmarkGapProofCheckpoint(store, wrong).errorCode, "benchmark_gap_proof_checkpoint_identity_mismatch")
        let claim = ckbClaimBenchmarkGapProofCheckpoint(store, expected, "owner", 100, 20)
        let proof = ckbBenchmarkGapProofForCandidate(records[0], expected.candidateVersion, expected.baseActiveVersion)
        _ = ckbSaveBenchmarkGapProofArtifact(store, claim.checkpoint, proof)
        let artifactPath = Path(root).join("metadata/benchmark-gap-curation/runs/${plan.planHash}/proofs/${proof.recordHash}.ckb")
        File.writeTo(artifactPath, [UInt8(255), UInt8(254)])
        @Expect(ckbLoadBenchmarkGapProofArtifact(store, claim.checkpoint, proof.caseIdentity, proof.recordHash).errorCode, "benchmark_gap_proof_artifact_invalid_response_encoding")
        @Expect(ckbLoadBenchmarkGapProofCheckpoint(store, expected).nextProofOffset, 0)

        let legacyRoot = "target/p7-s4-n01-legacy"; p7S4Empty(legacyRoot); let legacyStore = FileKnowledgeStore(legacyRoot)
        legacyStore.writeLinesAtomically("metadata/benchmark-gap-curation-proof.ckb", "status=success\ncompleted=440\n")
        let legacy = ckbLoadBenchmarkGapProofCheckpoint(legacyStore, expected)
        @Expect(legacy.valid, false); @Expect(legacy.errorCode, "legacy-unverified"); @Expect(legacy.nextProofOffset, 0)
        @Expect(saved.valid, true)
    }

    @TestCase
    public func p7E2E01PlanCandidateProofAlignWithoutActiveCommit(): Unit {
        let root = "target/p7-e2e01-proof-chain"; p7S4Empty(root); let store = FileKnowledgeStore(root)
        let records = p7S4Records(20); let plan = p7S4Plan(store, records, "e2e01"); let expected = p7S4Checkpoint(plan, records)
        _ = ckbSaveBenchmarkGapProofCheckpoint(store, expected); let complete = p7S4RunAll(store, records, expected, 200)
        @Expect(plan.planHash, complete.planHash); @Expect(complete.inputSha256, plan.inputSha256); @Expect(complete.state, "complete")
        @Expect(complete.nextProofOffset, 20); @Expect(exists(Path(root).join("index/active.ckb")), false)
    }

    @TestCase
    public func p7E2E02CrashAtArtifactCursorBoundaryMatchesCleanBaseline(): Unit {
        let records = p7S4Records(8)
        let cleanRoot = "target/p7-e2e02-proof-clean"; p7S4Empty(cleanRoot); let cleanStore = FileKnowledgeStore(cleanRoot); let cleanPlan = p7S4Plan(cleanStore, records, "same"); let cleanExpected = p7S4Checkpoint(cleanPlan, records); _ = ckbSaveBenchmarkGapProofCheckpoint(cleanStore, cleanExpected); let clean = p7S4RunAll(cleanStore, records, cleanExpected, 300)
        let crashRoot = "target/p7-e2e02-proof-crash"; p7S4Empty(crashRoot); let crashStore = FileKnowledgeStore(crashRoot); let crashPlan = p7S4Plan(crashStore, records, "same"); let crashExpected = p7S4Checkpoint(crashPlan, records); _ = ckbSaveBenchmarkGapProofCheckpoint(crashStore, crashExpected)
        let claim = ckbClaimBenchmarkGapProofCheckpoint(crashStore, crashExpected, "crash", 300, 10); let orphan = ckbBenchmarkGapProofForCandidate(records[0], crashExpected.candidateVersion, crashExpected.baseActiveVersion); _ = ckbSaveBenchmarkGapProofArtifact(crashStore, claim.checkpoint, orphan)
        let recovered = ckbClaimBenchmarkGapProofCheckpoint(FileKnowledgeStore(crashRoot), crashExpected, "recover", 311, 10); let loaded = ckbLoadBenchmarkGapProofArtifact(crashStore, recovered.checkpoint, orphan.caseIdentity, orphan.recordHash); _ = ckbAdvanceBenchmarkGapProofCursor(crashStore, recovered.checkpoint, records[0], loaded, 312)
        let crashed = p7S4RunAll(crashStore, records, crashExpected, 320)
        @Expect(crashed.state, clean.state); @Expect(crashed.nextProofOffset, clean.nextProofOffset); @Expect(crashed.aggregateEvidenceHash, clean.aggregateEvidenceHash)
    }

    @TestCase
    public func p7E2E03TenClaimantsYieldOneOwnerAndTerminalDoesNotReclaim(): Unit {
        let root = "target/p7-e2e03-proof-claims"; p7S4Empty(root); let store = FileKnowledgeStore(root); let records = p7S4Records(1); let plan = p7S4Plan(store, records, "e2e03"); let expected = p7S4Checkpoint(plan, records); _ = ckbSaveBenchmarkGapProofCheckpoint(store, expected)
        var claimed: Int64 = 0; var held: Int64 = 0; var owner = CkbBenchmarkGapProofClaimResult()
        for (i in 0..10) { let one = ckbClaimBenchmarkGapProofCheckpoint(FileKnowledgeStore(root), expected, "owner-${i}", 100, 20); if (one.claimed) { claimed += 1; owner = one } else if (one.errorCode == "benchmark_gap_proof_lease_held") { held += 1 } }
        let proof = ckbBenchmarkGapProofForCandidate(records[0], expected.candidateVersion, expected.baseActiveVersion); let complete = ckbAdvanceBenchmarkGapProofCursor(store, owner.checkpoint, records[0], proof, 101)
        let terminal = ckbClaimBenchmarkGapProofCheckpoint(store, expected, "late", 200, 20)
        @Expect(claimed, 1); @Expect(held, 9); @Expect(complete.state, "complete"); @Expect(terminal.claimed, false); @Expect(terminal.errorCode, "benchmark_gap_proof_terminal")
    }

    @TestCase
    public func p7E2E04UnicodeSecretLikeIdentityIsHashedInDiagnostics(): Unit {
        let record = p7S4Records(1)[0]; record.sourceId = "中文🙂-Authorization-Bearer-secret"
        let proof = ckbBenchmarkGapProofForCandidate(record, "candidate-safe", "active-safe")
        let diagnostic = ckbRenderBenchmarkGapProofDiagnostic(proof)
        @Expect(proof.valid, true); @Expect(diagnostic.contains(record.sourceId), false); @Expect(diagnostic.contains("Bearer-secret"), false); @Expect(diagnostic.contains("caseIdentityHash="), true)
    }
}

private func p7S4Plan(store: FileKnowledgeStore, records: ArrayList<NormalizedRecord>, seed: String): CkbBenchmarkGapScanPlan { ckbSaveBenchmarkGapScanPlan(store, ckbBuildBenchmarkGapScanPlan(records, "p7-s4-${seed}", "1.0.0")) }
private func p7S4Checkpoint(plan: CkbBenchmarkGapScanPlan, records: ArrayList<NormalizedRecord>): CkbBenchmarkGapProofCheckpoint { let candidate="candidate-${plan.planHash}";ckbNewBenchmarkGapProofCheckpoint(plan,candidate,"active-before",ckbCandidateRecordsEvidenceHash(records,stagedCandidateVersion:candidate)) }
private func p7S4RunAll(store: FileKnowledgeStore, records: ArrayList<NormalizedRecord>, expected: CkbBenchmarkGapProofCheckpoint, startNow: Int64): CkbBenchmarkGapProofCheckpoint { var current=expected;var now=startNow;while(true){let loaded=ckbLoadBenchmarkGapProofCheckpoint(store,expected);if(loaded.valid&&loaded.state=="complete"){return loaded};let claim=ckbClaimBenchmarkGapProofCheckpoint(store,expected,"run-${now}",now,20);let record=records[claim.checkpoint.nextProofOffset];let proof=ckbBenchmarkGapProofForCandidate(record,expected.candidateVersion,expected.baseActiveVersion);current=ckbAdvanceBenchmarkGapProofCursor(store,claim.checkpoint,record,proof,now+1);now+=2};current }
private func p7S4Records(count: Int64): ArrayList<NormalizedRecord> { var text="";for(i in 0..count){text+="{\"caseId\":\"CJ-P7-S4-${i}\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"中文🙂 ArrayList ${i}\",\"compilerOutput\":\"compile_error\",\"missingKnowledge\":\"G-ARRAYLIST\",\"interfaceId\":\"KI-02\",\"contentFamily\":\"KC-02\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"1.0.0\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/\"}\n"};curateBenchmarkGapRecordsFromJsonl(text).records }
private func p7S4Empty(root: String): Unit { if(exists(Path(root))){_=launch("/bin/rm",["-rf",root]).wait()};Directory.create(Path(root),recursive:true) }
