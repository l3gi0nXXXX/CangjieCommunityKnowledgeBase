package cangjie_community_knowledge_base_test

import std.collection.*
import std.fs.*
import std.process.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbP7CommitContractTest {
    @TestCase public func p7S6U01SixGatesAndTerminalIdentityAreStrict():Unit {
        let gates=ckbSchedulerTaskContractForName("cangjie_benchmark_gap_curation").requiredValidationGates
        @Expect(gates.size,6);@Expect(gates[0],"curation_input_verified");@Expect(gates[5],"curation_checkpoint_verified")
        let fixture=p7S6Fixture("u01",2);let terminal=ckbFinalizeBenchmarkGapTerminal(fixture[0],fixture[1],"active-u01","tx-u01")
        @Expect(terminal.valid,true);@Expect(terminal.completed,terminal.total)
        @Expect(ckbLoadBenchmarkGapTerminal(fixture[0],terminal.planHash,terminal.transactionId).valid,true)
    }

    @TestCase public func p7S6B01IncompleteProofCannotReplaceLastSuccess():Unit {
        let fixture=p7S6Fixture("b01",2);let store=fixture[0];let complete=fixture[1]
        let first=ckbFinalizeBenchmarkGapTerminal(store,complete,"active-a","tx-a");@Expect(first.valid,true)
        let before=store.readText("metadata/benchmark-gap-curation-last-success.ckb")
        complete.state="checkpointed";complete.nextProofOffset=1
        let rejected=ckbFinalizeBenchmarkGapTerminal(store,complete,"active-b","tx-b")
        @Expect(rejected.valid,false);@Expect(store.readText("metadata/benchmark-gap-curation-last-success.ckb"),before)
    }

    @TestCase public func p7S6P01CompleteProofGatePassesExactlyOnce():Unit {
        let fixture=p7S6Fixture("p01",4);let gate=CkbBenchmarkGapPreCommitGate(fixture[0],fixture[1],fixture[2],0)
        let pass=gate.evaluate(fixture[1].candidateVersion,fixture[1].baseActiveVersion)
        @Expect(pass.passed,true);@Expect(pass.status,"query_proof_complete")
        let again=gate.evaluate(fixture[1].candidateVersion,fixture[1].baseActiveVersion)
        @Expect(again.passed,true);@Expect(again.evidenceHash,pass.evidenceHash)
    }

    @TestCase public func p7S6N01WrongBaseAndChecksumFailClosed():Unit {
        let fixture=p7S6Fixture("n01",2);let gate=CkbBenchmarkGapPreCommitGate(fixture[0],fixture[1],fixture[2],0)
        let mismatch=gate.evaluate(fixture[1].candidateVersion,"wrong-active")
        @Expect(mismatch.passed,false);@Expect(mismatch.terminal,true)
        let terminal=ckbFinalizeBenchmarkGapTerminal(fixture[0],fixture[1],"active-n01","tx-n01")
        fixture[0].writeLinesAtomically("metadata/benchmark-gap-curation/runs/${terminal.planHash}/terminal/tx-n01.ckb","broken\n")
        @Expect(ckbLoadBenchmarkGapTerminal(fixture[0],terminal.planHash,"tx-n01").valid,false)
    }

    @TestCase public func p7E2E01ProofArtifactsPrecedeTerminal():Unit { let f=p7S6Fixture("e01",5);@Expect(f[0].has("metadata/benchmark-gap-curation/runs/${f[1].planHash}/proof-checkpoint.ckb"),true);@Expect(ckbFinalizeBenchmarkGapTerminal(f[0],f[1],"active-e01","tx-e01").valid,true) }
    @TestCase public func p7E2E02TerminalWriteIsIdempotent():Unit { let f=p7S6Fixture("e02",3);let a=ckbFinalizeBenchmarkGapTerminal(f[0],f[1],"active-e02","tx-e02");let b=ckbFinalizeBenchmarkGapTerminal(f[0],f[1],"active-e02","tx-e02");@Expect(a.checksum,b.checksum);@Expect(b.valid,true) }
    @TestCase public func p7E2E03TenClaimantsObserveTerminalProof():Unit { let f=p7S6Fixture("e03",10);var passed:Int64=0;for(_ in 0..10){let g=CkbBenchmarkGapPreCommitGate(f[0],f[1],f[2],0);if(g.evaluate(f[1].candidateVersion,f[1].baseActiveVersion).passed){passed+=1}};@Expect(passed,10) }
    @TestCase public func p7E2E04UnicodeIdentityDoesNotLeakIntoTerminalPointer():Unit { let f=p7S6Fixture("中文😀token=secret",2);let t=ckbFinalizeBenchmarkGapTerminal(f[0],f[1],"active-e04","tx-e04");let pointer=f[0].readText("metadata/benchmark-gap-curation-last-success.ckb");@Expect(t.valid,true);@Expect(pointer.contains("token=secret"),false) }
    @TestCase public func p7E2E05TerminalKeepsImmutableProofEvidence():Unit { let f=p7S6Fixture("e05",4);let hash=f[1].aggregateEvidenceHash;let t=ckbFinalizeBenchmarkGapTerminal(f[0],f[1],"active-e05","tx-e05");let run="metadata/benchmark-gap-curation/runs/${f[1].planHash}";Directory.create(Path(f[0].root.toString()).join("${run}/commit.lock"),recursive:true);let cleanup=ckbCleanupBenchmarkGapCurationRun(f[0],t);@Expect(t.proofEvidenceHash,hash);@Expect(f[0].has("${run}/proofs"),true);@Expect(cleanup.ok,true);@Expect(cleanup.intentCommitted,true);@Expect(cleanup.locksRemoved,true);@Expect(cleanup.spoolRemoved,true);@Expect(f[0].readText("${run}/commit-intent.ckb").contains("state=committed"),true);@Expect(exists(f[0].root.join("${run}/commit.lock")),false) }
    @TestCase public func p7E2E06FinalizeCrashBoundariesResumeIdempotently():Unit {
        let beforeTerminal=p7S6Fixture("e06-terminal",2)
        try { _=ckbFinalizeBenchmarkGapTerminal(beforeTerminal[0],beforeTerminal[1],"active-e06-a","tx-e06-a",faultInjector:P7S6FinalizeFault("terminal_before")) } catch (_:Exception) {}
        @Expect(beforeTerminal[0].has("metadata/benchmark-gap-curation/runs/${beforeTerminal[1].planHash}/terminal/tx-e06-a.ckb"),false)
        @Expect(ckbFinalizeBenchmarkGapTerminal(beforeTerminal[0],beforeTerminal[1],"active-e06-a","tx-e06-a").valid,true)
        let beforePointer=p7S6Fixture("e06-pointer",2)
        try { _=ckbFinalizeBenchmarkGapTerminal(beforePointer[0],beforePointer[1],"active-e06-b","tx-e06-b",faultInjector:P7S6FinalizeFault("last_success_before")) } catch (_:Exception) {}
        @Expect(beforePointer[0].has("metadata/benchmark-gap-curation/runs/${beforePointer[1].planHash}/terminal/tx-e06-b.ckb"),true)
        @Expect(beforePointer[0].has("metadata/benchmark-gap-curation-last-success.ckb"),false)
        @Expect(ckbFinalizeBenchmarkGapTerminal(beforePointer[0],beforePointer[1],"active-e06-b","tx-e06-b").valid,true)
    }
}

private class P7S6FinalizeFault <: CkbBenchmarkGapFinalizeFaultInjector {
    let point:String
    init(point:String){this.point=point}
    public func checkpoint(point:String):Unit { if(point==this.point){throw Exception("fixture_fault:${point}")} }
}

private func p7S6Fixture(name:String,total:Int64):(FileKnowledgeStore,CkbBenchmarkGapProofCheckpoint,ArrayList<NormalizedRecord>){
    let root="target/p7-s6-${ckbReleaseEvidenceHash(name)}";if(exists(Path(root))){_=launch("/bin/rm",["-rf",root]).wait()};let store=FileKnowledgeStore(root)
    let records=ArrayList<NormalizedRecord>();for(i in 0..total){let r=NormalizedRecord();r.sourceId="case-${i}-${ckbReleaseEvidenceHash(name)}";r.recordKind="negative_rule";r.title="case ${i}";r.chunk="Task: 中文😀 ${i}\nMissing knowledge: G-ARRAYLIST";r.citation="https://docs.cangjie-lang.cn/${i}";r.metadata.targetVersion="1.0.0";r.metadata.sourceSet=CangjieSourceSets.EVAL_SUPPORT;records.add(r)}
    let input="fixture-${name}-${total}";let plan=ckbBuildBenchmarkGapScanPlan(records,input,"1.0.0",runId:"run-${ckbReleaseEvidenceHash(name)}",batchSize:200);var saved=ckbSaveBenchmarkGapScanPlan(store,plan);saved.state="complete";saved.nextOffset=saved.total;saved=ckbSaveBenchmarkGapScanPlan(store,saved)
    let candidate="candidate-${ckbReleaseEvidenceHash(name)}";let proofExpected=ckbNewBenchmarkGapProofCheckpoint(saved,candidate,"base-active",ckbCandidateRecordsEvidenceHash(records,stagedCandidateVersion:candidate));var proof=ckbSaveBenchmarkGapProofCheckpoint(store,proofExpected)
    while(proof.nextProofOffset<proof.total){let claim=ckbClaimBenchmarkGapProofCheckpoint(store,proofExpected,"owner",ckbCoreNowMillis(),60000);let record=records[claim.checkpoint.nextProofOffset];let p=ckbBenchmarkGapProofForCandidate(record,candidate,"base-active");proof=ckbAdvanceBenchmarkGapProofCursor(store,claim.checkpoint,record,p,ckbCoreNowMillis()+1)}
    (store,proof,records)
}
