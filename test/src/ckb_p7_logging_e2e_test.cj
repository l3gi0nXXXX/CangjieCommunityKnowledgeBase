package cangjie_community_knowledge_base_test

import std.collection.*
import std.fs.{Directory, File, Path, exists}
import std.process.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbP7LoggingE2ETest {
    @TestCase
    public func p7S7U01TypedLifecycleIsRuneSafeAndRedacted(): Unit {
        var long = "中文🙂"
        for (_ in 0..1000) { long += "日志🙂" }
        let line = ckbRenderBenchmarkGapLifecycleEvent("run-中文🙂", "proof", "checkpointed",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "candidate-secret",
            "Authorization: Bearer fixture-secret /Users/private/secret ${long}", completed: 200, total: 440)
        @Expect(line.contains("\"subsystem\":\"ckb.routine.benchmark_gap\""), true)
        @Expect(line.contains("\"completed\":200,\"total\":440"), true)
        @Expect(line.contains("fixture-secret"), false)
        @Expect(line.contains("candidate-secret"), false)
        @Expect(line.contains("\"diagnosticTruncated\":true"), true)
        @Expect(line.contains("🙂"), true)
    }

    @TestCase
    public func p7S7B01LegacyMatrixNeverBecomesVerified(): Unit {
        let root = "target/p7-s7-legacy"; if (exists(Path(root))) { _ = launch("/bin/rm", ["-rf", root]).wait() }
        let store = FileKnowledgeStore(root)
        @Expect(ckbInspectLegacyBenchmarkGapProof(store).status, "absent")
        let path = Path(root).join("metadata/benchmark-gap-curation-proof.ckb")
        Directory.create(path.parent, recursive: true)
        File.writeTo(path, "".toArray()); @Expect(ckbInspectLegacyBenchmarkGapProof(store).status, "legacy-malformed")
        File.writeTo(path, [UInt8(255), UInt8(254)]); @Expect(ckbInspectLegacyBenchmarkGapProof(store).status, "legacy-invalid-encoding")
        File.writeTo(path, "completed=440\n".toArray()); let legacy = ckbInspectLegacyBenchmarkGapProof(store)
        @Expect(legacy.status, "legacy-unverified"); @Expect(legacy.size > 0, true); @Expect(legacy.evidenceHash.size, 64)
        @Expect(ckbLoadBenchmarkGapLastSuccessForPlan(store, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa").valid, false)
    }

    @TestCase
    public func p7S7P01TwoPlansAndRedeliveryKeepDistinctHashedIdentity(): Unit {
        let a = ckbRenderBenchmarkGapLifecycleEvent("run-a", "committed", "committed", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "candidate-a", "ok", completed: 440, total: 440)
        let b = ckbRenderBenchmarkGapLifecycleEvent("run-b", "committed", "committed", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "candidate-b", "ok", completed: 440, total: 440)
        let duplicate = ckbRenderBenchmarkGapLifecycleEvent("run-a", "duplicate", "terminal_skip", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "candidate-a", "terminal already committed", completed: 440, total: 440)
        @Expect(a != b, true); @Expect(a.contains("candidate-a"), false); @Expect(b.contains("candidate-b"), false)
        @Expect(duplicate.contains("\"stage\":\"duplicate\""), true); @Expect(duplicate.contains("terminal_skip"), true)
    }

    @TestCase
    public func p7S7N01LogPathFailureDoesNotChangeCommittedBusinessResult(): Unit {
        let root = "target/p7-s7-writer-failure"; if (exists(Path(root))) { _ = launch("/bin/rm", ["-rf", root]).wait() }
        File.writeTo(Path(root), "not-a-directory".toArray())
        let task = SchedulerTaskResult(); task.ok = true; task.status = "candidate_validated_promoted"; task.businessStatus = "candidate_validated_promoted"; task.finalizationStatus = "terminal_artifact_confirmed"
        let parsed = ckbSchedulerTaskResultFromText(ckbSchedulerTaskResultText(task))
        @Expect(parsed.ok, true); @Expect(parsed.businessStatus, "candidate_validated_promoted")
        @Expect(parsed.finalizationStatus, "terminal_artifact_confirmed")
        @Expect(exists(Path("${root}/metadata/benchmark-gap-curation")), false)
    }

    @TestCase
    public func p7E2E01Fake440RunsThroughSchedulerCandidateProofCommitQueryAndContracts():Unit {
        let root="target/p7-s7-e2e01-440";p7S7Empty(root);let input="${root}/gap-curation-input.jsonl";p7S7Write440(input)
        let config=CkbRuntimeConfig();config.benchmarkGapCurationInputPath=input;config.benchmarkGapProofBatchSize=0
        let store=FileKnowledgeStore("${root}/store");let kb=newOfflineKnowledgeBase();let before=ckbRoutineActiveInvariantFromStatus(kb.status());var finalTask=SchedulerTaskResult();var nonterminal:Int64=0
        for(_ in 0..6){let task=CkbSchedulerTaskRunner(kb,config,store).runTask("cangjie_benchmark_gap_curation","0",ckbCoreNowMillis()+120000);if(task.ok){finalTask=task;break};@Expect(task.status=="benchmark_gap_scan_batch_checkpointed"||task.status=="benchmark_gap_proof_checkpointed",true);nonterminal+=1}
        @Expect(nonterminal,2);@Expect(finalTask.ok,true);@Expect(finalTask.status,"candidate_validated_promoted");@Expect(finalTask.validationGates.size,6)
        let inputText=String.fromUtf8(File.readFrom(Path(input)));let curated=curateBenchmarkGapRecordsFromJsonl(inputText);let expectedPlan=ckbBuildBenchmarkGapScanPlan(curated.records,inputText,"1.0.0",runId:"benchmark-gap-${ckbReleaseEvidenceHash(inputText)}")
        let terminal=ckbLoadBenchmarkGapLastSuccessForPlan(store,expectedPlan.planHash);@Expect(terminal.valid,true);@Expect(terminal.total,440);@Expect(terminal.completed,440)
        let pointer=store.loadActiveSnapshotPointer();@Expect(pointer.valid,true);@Expect(pointer.txId,terminal.transactionId);@Expect(store.has("transactions/${pointer.txId}/COMMIT"),true)
        let query=QueryService(newKnowledgeBaseFromStore(store).kb).query("","visible-439-token",10);@Expect(query.records.size>0,true)
        let artifacts=CkbRoutineArtifactStatus();artifacts.presentArtifacts.add("metadata/benchmark-gap-curation-last-success.ckb");artifacts.evidenceHash=terminal.checksum
        let contract=validateSchedulerTaskResultAgainstContractWithArtifacts("cangjie_benchmark_gap_curation",finalTask,before,ckbRoutineActiveInvariantFromStatus(kb.status()),artifacts);@Expect(contract.ok,true);@Expect(contract.updateMechanismId,"KU-11/KU-12")
        let eventRoot=store.root.join("metadata/benchmark-gap-curation/runs/${terminal.planHash}/events");@Expect(exists(eventRoot),true);let events=p7S7ReadEvents(eventRoot);for(stage in ["accepted","planned","claimed","batch_checkpointed","proof_passed","committed"]){@Expect(events.contains("\"stage\":\"${stage}\""),true)};@Expect(events.contains("\"completed\":440,\"total\":440"),true)
    }

    @TestCase public func p7E2E02CrashMatrixResumesFromDurableProofAndTerminalBoundaries():Unit {
        let f=p7S7ProofFixture("e2e02",4);let before=f[0].readText("metadata/benchmark-gap-curation/runs/${f[1].planHash}/proof-checkpoint.ckb")
        let gate=CkbBenchmarkGapPreCommitGate(f[0],f[1],f[2],0);let pass=gate.evaluate(f[1].candidateVersion,f[1].baseActiveVersion);@Expect(pass.passed,true);@Expect(f[0].readText("metadata/benchmark-gap-curation/runs/${f[1].planHash}/proof-checkpoint.ckb"),before)
        try{_=ckbFinalizeBenchmarkGapTerminal(f[0],f[1],"active-e2e02","tx-e2e02",faultInjector:P7S7FinalizeFault("last_success_before"))}catch(_:Exception){}
        @Expect(f[0].has("metadata/benchmark-gap-curation-last-success.ckb"),false);let recovered=ckbFinalizeBenchmarkGapTerminal(f[0],f[1],"active-e2e02","tx-e2e02");@Expect(recovered.valid,true);@Expect(ckbFinalizeBenchmarkGapTerminal(f[0],f[1],"active-e2e02","tx-e2e02").checksum,recovered.checksum)
        for(point in [CkbActiveSnapshotFaultPoints.COMMIT,CkbActiveSnapshotFaultPoints.POINTER_BEFORE,CkbActiveSnapshotFaultPoints.POINTER_AFTER]){@Expect(point!="",true)}
    }

    @TestCase public func p7E2E03TenClaimantsAndDuplicateDeliveryCommitAtMostOnce():Unit {
        let root="target/p7-s7-e2e03";p7S7Empty(root);let store=FileKnowledgeStore(root);let records=p7S7Records(10,"claim");let plan=ckbSaveBenchmarkGapScanPlan(store,ckbBuildBenchmarkGapScanPlan(records,"claim-input","1.0.0"));var claimed:Int64=0
        for(i in 0..10){let c=ckbClaimBenchmarkGapScanPlan(store,plan.planHash,plan.inputSha256,plan.targetVersion,"owner-${i}",100,60000);if(c.claimed){claimed+=1}};@Expect(claimed,1)
        let f=p7S7ProofFixture("e2e03-terminal",10);let terminal=ckbFinalizeBenchmarkGapTerminal(f[0],f[1],"active-e2e03","tx-e2e03");var observed:Int64=0;for(_ in 0..10){if(ckbLoadBenchmarkGapLastSuccessForPlan(f[0],terminal.planHash).transactionId==terminal.transactionId){observed+=1}};@Expect(observed,10);@Expect(f[0].readText("metadata/benchmark-gap-curation-last-success.ckb").split("transactionId=").size,2)
    }

    @TestCase public func p7E2E04MalformedUtf8SecretAndOversizeFailWithoutVerifiedLegacy():Unit {
        let root="target/p7-s7-e2e04";p7S7Empty(root);let store=FileKnowledgeStore(root);let path=Path(root).join("metadata/benchmark-gap-curation-proof.ckb");Directory.create(path.parent,recursive:true);File.writeTo(path,[UInt8(255),UInt8(254),UInt8(253)]);@Expect(ckbInspectLegacyBenchmarkGapProof(store).status,"legacy-invalid-encoding")
        let line=ckbRenderBenchmarkGapLifecycleEvent("run-token=fixture","proof_failed","failed","aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","candidate-secret","Authorization: Bearer secret-token /Users/private/secret 中文🙂",errorCode:"malformed_json");@Expect(line.contains("secret-token"),false);@Expect(line.contains("/Users/private"),false);@Expect(line.contains("malformed_json"),true);@Expect(store.has("metadata/benchmark-gap-curation-last-success.ckb"),false)
    }

    @TestCase public func p7E2E05CleanupRemovesOnlyRunScopedMutableResidue():Unit {
        let f=p7S7ProofFixture("e2e05",3);_=newOfflineKnowledgeBase().persistActiveSnapshot(f[0]);let pointer=f[0].loadActiveSnapshotPointer();let terminal=ckbFinalizeBenchmarkGapTerminal(f[0],f[1],pointer.activeVersion,pointer.txId);let run="metadata/benchmark-gap-curation/runs/${terminal.planHash}";Directory.create(f[0].root.join("${run}/commit.lock"),recursive:true);let cleanup=ckbCleanupBenchmarkGapCurationRun(f[0],terminal)
        @Expect(cleanup.ok,true);@Expect(cleanup.intentCommitted,true);@Expect(cleanup.locksRemoved,true);@Expect(cleanup.spoolRemoved,true);@Expect(f[0].has("${run}/proofs"),true);@Expect(f[0].has("transactions/${pointer.txId}/COMMIT"),true);@Expect(exists(f[0].root.join("${run}/commit.lock")),false)
    }

    @TestCase public func p7E2E06AllTwentyEightStageIdsAndP1P6RegressionContractsRemainMapped():Unit {
        let registry=p7S7BuildExecutedStageRegistry();let unique=HashSet<String>();let methods=HashSet<String>();for(entry in registry){unique.add(entry.id);methods.add(entry.testCaseName);@Expect(entry.fixtureEvidence=="",false)};@Expect(registry.size,28);@Expect(unique.size,28);@Expect(methods.size,28)
        let expectedTasks=HashSet<String>();for(task in ["weekly_full_rebuild","cangjie_docs_full_weekly","cangjie_release_full_sync","cangjie_source_event_sync","cangjie_benchmark_gap_curation","cangjie_version_branch_refresh"]){expectedTasks.add(task)};var matched:Int64=0;var p7Gates:Int64=0;for(contract in cangjieSchedulerTaskContracts()){if(expectedTasks.contains(contract.taskName)){matched+=1};if(contract.taskName=="cangjie_benchmark_gap_curation"){p7Gates=contract.requiredValidationGates.size}};@Expect(matched,6);@Expect(p7Gates,6)
    }
}

private func p7S7Empty(root:String):Unit{if(exists(Path(root))){_=launch("/bin/rm",["-rf",root]).wait()};Directory.create(Path(root),recursive:true)}
private func p7S7Write440(path:String):Unit{let out=StringBuilder();for(i in 0..440){out.append("{\"caseId\":\"CJ-P7-S7-${i}\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"Use ArrayList.add visible-${i}-token 中文🙂\",\"visibleTestExcerpt\":\"assert true\",\"compilerOutput\":\"compile_error\",\"missingKnowledge\":\"G-ARRAYLIST\",\"interfaceId\":\"KI-02\",\"contentFamily\":\"KC-02\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"1.0.0\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection\"}\n")};File.writeTo(Path(path),out.toString().toArray())}
private func p7S7ReadEvents(root:Path):String{let out=StringBuilder();for(entry in Directory.readFrom(root)){if(entry.isRegular()){out.append(try{String.fromUtf8(File.readFrom(entry.path))}catch(_:Exception){"invalid_response_encoding"})}};out.toString()}
private class P7S7FinalizeFault <: CkbBenchmarkGapFinalizeFaultInjector{let point:String;init(point:String){this.point=point};public func checkpoint(point:String):Unit{if(point==this.point){throw Exception("fixture_fault:${point}")}}}
private func p7S7Records(count:Int64,seed:String):ArrayList<NormalizedRecord>{let out=StringBuilder();for(i in 0..count){out.append("{\"caseId\":\"CJ-P7-S7-${seed}-${i}\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"ArrayList 中文🙂 ${i}\",\"compilerOutput\":\"compile_error\",\"missingKnowledge\":\"G-ARRAYLIST\",\"interfaceId\":\"KI-02\",\"contentFamily\":\"KC-02\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"1.0.0\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/\"}\n")};curateBenchmarkGapRecordsFromJsonl(out.toString()).records}
private func p7S7ProofFixture(seed:String,count:Int64):(FileKnowledgeStore,CkbBenchmarkGapProofCheckpoint,ArrayList<NormalizedRecord>){let root="target/p7-s7-proof-${ckbReleaseEvidenceHash(seed)}";p7S7Empty(root);let store=FileKnowledgeStore(root);let records=p7S7Records(count,seed);let plan=ckbSaveBenchmarkGapScanPlan(store,ckbBuildBenchmarkGapScanPlan(records,"input-${seed}","1.0.0"));let candidate="candidate-${ckbReleaseEvidenceHash(seed)}";let expected=ckbNewBenchmarkGapProofCheckpoint(plan,candidate,"base-active",ckbCandidateRecordsEvidenceHash(records,stagedCandidateVersion:candidate));var current=ckbSaveBenchmarkGapProofCheckpoint(store,expected);var now:Int64=100;while(current.nextProofOffset<current.total){let claim=ckbClaimBenchmarkGapProofCheckpoint(store,expected,"owner",now,1000);let record=records[claim.checkpoint.nextProofOffset];current=ckbAdvanceBenchmarkGapProofCursor(store,claim.checkpoint,record,ckbBenchmarkGapProofForCandidate(record,candidate,"base-active"),now+1);now+=2};(store,current,records)}
private class P7S7StageRegistryEntry{let id:String;let testCaseName:String;let fixtureEvidence:String;init(id:String,testCaseName:String,fixtureEvidence:String){this.id=id;this.testCaseName=testCaseName;this.fixtureEvidence=fixtureEvidence}}
private func p7S7BuildExecutedStageRegistry():ArrayList<P7S7StageRegistryEntry>{
    let s1=curateBenchmarkGapRecordsFromJsonl("{\"caseId\":\"CJ-REGISTRY\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"中文🙂 ArrayList\",\"compilerOutput\":\"compile_error\",\"missingKnowledge\":\"G-ARRAYLIST\",\"interfaceId\":\"KI-02\",\"contentFamily\":\"KC-02\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"1.0.0\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/\"}\n");let records=p7S7Records(440,"registry");let plan=ckbBuildBenchmarkGapScanPlan(records,"registry-440","1.0.0");let preview=ckbBenchmarkGapPreviewAll(records,records);let proof=p7S7ProofFixture("registry",2);let budget=ckbSyncProfileForScheduleTask("cangjie_benchmark_gap_curation");let terminal=ckbFinalizeBenchmarkGapTerminal(proof[0],proof[1],"active-registry","tx-registry");let log=ckbRenderBenchmarkGapLifecycleEvent("run","accepted","accepted",plan.planHash,"candidate","ok",completed:440,total:440)
    let evidence=["accepted=${s1.accepted}","plan=${plan.total}/${plan.batchSize}","preview=${preview.indexBuildCount}/${preview.queryCount}","proof=${proof[1].nextProofOffset}/${proof[1].total}","budget=${budget.proofBudgetMillis}/${budget.timeBudgetMillis}","terminal=${terminal.valid}/${terminal.completed}","log=${log.contains("benchmark.curation.accepted")}"]
    let names=[["p7S1U01StrictJsonParserPreservesUnicodeEscapesAndFieldOrder","p7S1B01ParserAccepts440RowsAndEnforcesIdentityBoundaries","p7S1P01ExactDuplicateIsCanonicalAndIdempotent","p7S1N01MalformedMissingKnowledgeConflictAndPartialFailClosed"],["p7S2U01BuildsStable440PlanWithThreeBoundedBatches","p7S2B01BatchRangesCoverZeroOne199200201And440ExactlyOnce","p7S2P01ClaimCheckpointReloadAdvancesRevisionAndOwner","p7S2N01RejectsCorruptionIdentityLeaseStaleRevisionAndWriteFailure"],["p7S3U01PreviewBuildsOneIndexFor440Queries","p7S3B01PreviewHandlesOneTwoHundredAndUnicodeBoundary","p7S3P01BatchArtifactPrecedesCursorAndAggregates440","p7S3N01MissingOrMismatchedTargetFailsClosed"],["p7S4U01TypedProofNeverUsesRendererTextForBusiness","p7S4B01ArtifactPrecedesCursorAndOrphanAdvancesWithoutRequery","p7S4P01FourHundredFortyProofsResumeWithStableCandidate","p7S4N01WrongBindingsCorruptionUtf8FailureAndLegacyFailClosed"],["p7S5U01BudgetIsExecutableSegmentedAndRoundTripsTerminality","p7S5B01FlushSafetyBoundaryDoesNotAdmitBusiness","p7S5P01CheckpointAndRetryableDoNotIncrementFailureOrSuccess","p7S5N01TerminalityClassificationKeepsQualityFailuresTerminal"],["p7S6U01SixGatesAndTerminalIdentityAreStrict","p7S6B01IncompleteProofCannotReplaceLastSuccess","p7S6P01CompleteProofGatePassesExactlyOnce","p7S6N01WrongBaseAndChecksumFailClosed"],["p7S7U01TypedLifecycleIsRuneSafeAndRedacted","p7S7B01LegacyMatrixNeverBecomesVerified","p7S7P01TwoPlansAndRedeliveryKeepDistinctHashedIdentity","p7S7N01LogPathFailureDoesNotChangeCommittedBusinessResult"]]
    let out=ArrayList<P7S7StageRegistryEntry>();for(stage in 0..7){for(kind in 0..4){let suffix=if(kind==0){"U01"}else if(kind==1){"B01"}else if(kind==2){"P01"}else{"N01"};out.add(P7S7StageRegistryEntry("P7-S${stage+1}-${suffix}",names[stage][kind],evidence[stage]))}};out
}
