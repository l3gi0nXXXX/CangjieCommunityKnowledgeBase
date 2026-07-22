package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{File, Path}
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbCertifiedProductionReleaseTest {
    // T-R5-UT RED: release evidence must change when any Student-visible
    // metadata changes, even if the rendered title/content stay identical.
    @TestCase
    public func r5Ut01StudentVisibleMetadataParticipatesInCandidateHash(): Unit {
        let item = p8Item("metadata-only", 1, "stable")
        let records = p8Items([item])
        let beforeRecord = ckbCertifiedKnowledgeRecordEvidenceHash(item)
        let beforeCandidate = ckbCertifiedKnowledgeRecordsChecksum(records)
        item.record.metadata.path = "docs/changed-中文🙂.md"
        item.record.metadata.symbol = "Changed.symbol"
        item.record.metadata.sourceSet = CangjieSourceSets.TOOLS
        item.record.metadata.derivedFrom = ["changed-origin"]
        let afterRecord = ckbCertifiedKnowledgeRecordEvidenceHash(item)
        item.evidenceHash = afterRecord
        let afterCandidate = ckbCertifiedKnowledgeRecordsChecksum(records)
        @Expect(afterRecord == beforeRecord, false)
        @Expect(afterCandidate == beforeCandidate, false)
        let scoreRecord = ckbCertifiedKnowledgeRecordEvidenceHash(item)
        let scoreCandidate = ckbCertifiedKnowledgeRecordsChecksum(records)
        item.record.score = 0.75
        @Expect(ckbCertifiedKnowledgeRecordEvidenceHash(item) == scoreRecord, false)
        item.evidenceHash = ckbCertifiedKnowledgeRecordEvidenceHash(item)
        @Expect(ckbCertifiedKnowledgeRecordsChecksum(records) == scoreCandidate, false)
    }

    // T-R5-POS RED: P8 publishes the complete clean incoming set. Existing
    // records are comparison evidence only and must not survive implicitly.
    @TestCase
    public func r5Pos01CertifiedPublishReplacesActiveWithExactIncoming(): Unit {
        let kb = newOfflineKnowledgeBase()
        let existing = p8Existing(kb)
        let incoming = p8CoverageItems(1)
        let proof = p8Proof(incoming, "ckb-r5-replace")
        let root = "target/r5-replace-${ckbCoreNowMillis()}"
        let store = FileKnowledgeStore(root)
        let report = ckbPublishCertifiedKnowledge(kb, store, "ckb-r5-replace-candidate",
            kb.status().activeKnowledgeVersion, existing, incoming, proof)
        @Expect(report.ok, true)
        @Expect(report.candidateCount, incoming.size)
        @Expect(report.removedCount, existing.size)
        @Expect(store.loadActiveSnapshot().normalizedRecords.size, incoming.size)
    }

    @TestCase
    public func r5Neg01P6LeakageBindingTamperFailsClosed():Unit{let records=p8CoverageItems(1);let proof=p8Proof(records,"ckb-r5-p6");proof.studentLeakageProofJson=proof.studentLeakageProofJson.replace("\"status\":\"pass\"","\"status\":\"fail\"");@Expect(ckbCertifiedProductionProofDiagnostic(proof,records),"p6_candidate_binding_mismatch")}

    @TestCase
    public func r5Neg02MissingLeakageProofFailsClosed():Unit{let records=p8CoverageItems(1);let proof=p8Proof(records,"ckb-r5-missing");proof.studentLeakageProofJson="";@Expect(ckbCertifiedProductionProofDiagnostic(proof,records),"student_leakage_proof_required")}

    @TestCase
    public func r5Bnd01InvalidUtf8ArtifactHasStableDiagnostic():Unit{let path=Path("target/r5-invalid-utf8-${ckbCoreNowMillis()}.json");File.writeTo(path,[0xff,0xfe]);let result=ckbP8ReadArtifact(path.toString());@Expect(result.ok,false);@Expect(result.diagnostic,"invalid_response_encoding");let missing=ckbP8ReadArtifact("target/r5-missing-${ckbCoreNowMillis()}.json");@Expect(missing.ok,false);@Expect(missing.diagnostic,"artifact_read_failed")}

    @TestCase
    public func r5Pos02PostCommitArtifactFailureIsPublishedDegraded():Unit{let kb=newOfflineKnowledgeBase();let existing=p8Existing(kb);let incoming=p8CoverageItems(1);let proof=p8Proof(incoming,"ckb-r5-degraded");let store=FileKnowledgeStore("target/r5-degraded-${ckbCoreNowMillis()}");let report=ckbPublishCertifiedKnowledgeWithReleaseState(kb,store,p8ReleaseKey("degraded"),"ckb-r5-degraded-candidate",kb.status().activeKnowledgeVersion,existing,incoming,proof,forcePostCommitArtifactFailure:true);@Expect(report.ok,true);@Expect(report.status,"published_degraded");@Expect(report.diagnostic,"post_commit_artifact_failed");@Expect(store.loadActiveSnapshotPointer().valid,true)}

    @TestCase
    public func r5Neg03PointerCasConflictPreservesCompetingCommit():Unit{let kb=newOfflineKnowledgeBase();let existing=p8Existing(kb);let incoming=p8CoverageItems(1);let proof=p8Proof(incoming,"ckb-r5-cas");let store=FileKnowledgeStore("target/r5-cas-${ckbCoreNowMillis()}");let injector=R5CompetingPointerInjector(store);let report=ckbPublishCertifiedKnowledge(kb,store,"ckb-r5-cas-candidate",kb.status().activeKnowledgeVersion,existing,incoming,proof,snapshotFaultInjector:injector);let pointer=store.loadActiveSnapshotPointer();@Expect(report.ok,false);@Expect(report.status,"active_snapshot_pointer_cas_conflict");@Expect(pointer.valid,true);@Expect(pointer.txId,injector.competingTxId)}

    @TestCase
    public func r5Pos03FrozenManifestBindsCommittedTransactionAndTrustInputs():Unit{let kb=newOfflineKnowledgeBase();let existing=p8Existing(kb);let incoming=p8CoverageItems(1);let proof=p8Proof(incoming,"ckb-r5-freeze");let store=FileKnowledgeStore("target/r5-freeze-${ckbCoreNowMillis()}");let published=ckbPublishCertifiedKnowledge(kb,store,"ckb-r5-freeze-candidate",kb.status().activeKnowledgeVersion,existing,incoming,proof);@Expect(published.ok,true);let snapshot=store.loadActiveSnapshot();let leakage=ckbBuildStudentLeakageReport(snapshot.normalizedRecords).json;let query="{\"ok\":true,\"indexBuildCount\":1,\"failed\":0}";let authority="{\"ok\":true,\"authorityCount\":164,\"authorityHash\":\"${p8Hash("freeze-authority")}\",\"activeEvalCount\":0}";let atoms="{\"ok\":true,\"diagnostic\":\"validated\"}";let seal=ckbRenderCandidateTrustSeal(snapshot.normalizedRecords,leakage,query,authority,atoms);let options=CkbFrozenCandidateSealOptions();options.expectedKnowledgeVersion=snapshot.activeVersion;options.expectedCandidateChecksum=ckbCertifiedNormalizedRecordsChecksum(snapshot.normalizedRecords);options.inputHash=p8Hash("input");options.configHash=p8Hash("config");options.modelHash=p8Hash("model");options.studentLeakageProofJson=seal;options.studentLeakageArtifactJson=leakage;options.anonymousQueryArtifactJson=query;options.authorityIsolationArtifactJson=authority;options.atomTestArtifactJson=atoms;let first=ckbBuildFrozenCandidateSeal(store,options);@Expect(first.ok,true);@Expect(ckbFrozenCandidateManifestDiagnostic(store,first.manifestJson),"ok");let target=FileKnowledgeStore("target/r5-production-target-${ckbCoreNowMillis()}");let targetBefore=ckbActiveSnapshotPointerIdentityHash(target.loadActiveSnapshotPointer());@Expect(ckbP8FrozenSourceDiagnostic(store.root.toString(),target.root.toString(),first.manifestJson),"ok");@Expect(ckbP8FrozenSourceDiagnostic(target.root.toString(),target.root.toString(),first.manifestJson),"frozen_candidate_source_must_differ_from_target");@Expect(ckbActiveSnapshotPointerIdentityHash(target.loadActiveSnapshotPointer()),targetBefore);let secret=first.manifestJson.replace("{","{\"token\":\"must-not-land\",");@Expect(ckbP8FrozenSourceDiagnostic(store.root.toString(),target.root.toString(),secret),"secret_artifact_forbidden");let pointer=store.loadActiveSnapshotPointer();File.writeTo(store.root.join("transactions").join(pointer.txId).join("metadata/frozen-tamper.bin"),[0xff,0x00]);@Expect(ckbFrozenCandidateManifestDiagnostic(store,first.manifestJson),"frozen_candidate_manifest_drift");@Expect(ckbP8FrozenSourceDiagnostic(store.root.toString(),target.root.toString(),first.manifestJson),"frozen_candidate_manifest_drift");@Expect(ckbActiveSnapshotPointerIdentityHash(target.loadActiveSnapshotPointer()),targetBefore);let second=ckbBuildFrozenCandidateSeal(store,options);@Expect(second.ok,true);@Expect(second.evidenceHash==first.evidenceHash,false);let driftStore=FileKnowledgeStore("target/r5-freeze-drift-${ckbCoreNowMillis()}");_=kb.persistActiveSnapshot(driftStore);let drift=ckbBuildFrozenCandidateSeal(driftStore,options,faultInjector:R5FrozenPointerDriftInjector(driftStore));@Expect(drift.ok,false);@Expect(drift.diagnostic,"frozen_active_pointer_drift");options.studentLeakageProofJson="";@Expect(ckbBuildFrozenCandidateSeal(store,options).diagnostic,"student_leakage_proof_mismatch")}

    @TestCase
    public func r5Neg04FrozenManifestAndPublishFailuresPreservePointer():Unit{let kb=newOfflineKnowledgeBase();let existing=p8Existing(kb);let incoming=p8CoverageItems(1);let store=FileKnowledgeStore("target/r5-neg-pointer-${ckbCoreNowMillis()}");let before=store.loadActiveSnapshotPointer();let proof=p8Proof(incoming,"ckb-r5-neg-pointer");proof.frozenCandidateManifestJson="{}";proof.frozenCandidateManifestHash=p8Hash(proof.frozenCandidateManifestJson);@Expect(ckbFrozenCandidateManifestIntegrityDiagnostic(proof.frozenCandidateManifestJson),"frozen_candidate_manifest_invalid");@Expect(ckbCertifiedProductionProofDiagnostic(proof,incoming),"p6_candidate_binding_mismatch");proof.studentLeakageProofJson="";let missing=ckbPublishCertifiedKnowledge(kb,store,"ckb-r5-neg-pointer-candidate",kb.status().activeKnowledgeVersion,existing,incoming,proof);let afterMissing=store.loadActiveSnapshotPointer();@Expect(missing.ok,false);@Expect(ckbActiveSnapshotPointerIdentityHash(afterMissing),ckbActiveSnapshotPointerIdentityHash(before));let polluted=p8CoverageItems(1);polluted[0].record.chunk="CJ-HUMANEVAL-001 canonical_solution";polluted[0].evidenceHash=ckbCertifiedKnowledgeRecordEvidenceHash(polluted[0]);let pollutedReport=ckbPublishCertifiedKnowledge(kb,store,"ckb-r5-neg-pointer-candidate",kb.status().activeKnowledgeVersion,existing,polluted,p8Proof(polluted,"ckb-r5-neg-pointer"));let afterPolluted=store.loadActiveSnapshotPointer();@Expect(pollutedReport.ok,false);@Expect(ckbActiveSnapshotPointerIdentityHash(afterPolluted),ckbActiveSnapshotPointerIdentityHash(before))}

    @TestCase
    public func p8CliBnd01ExplicitStoreUnknownDuplicateAndMissingFailClosed(): Unit {
        @Expect(ckbP8CliArgs(["cangjie-certified-production-publish", "--control-manifest", "proof.json"])[0], "required_argument_missing:--store")
        @Expect(ckbP8CliArgs(["cangjie-certified-production-publish", "--store", "a", "--store", "b", "--control-manifest", "proof.json"])[0], "duplicate_argument:--store")
        @Expect(ckbP8CliArgs(["cangjie-certified-production-publish", "--store", "a", "--unknown", "b"])[0], "unknown_argument:--unknown")
        @Expect(ckbP8CliArgs(["cangjie-certified-production-publish", "--store", "a", "--control-manifest", "proof.json"])[0], "ok")
    }

    @TestCase
    public func p8Ut01CanonicalConflictUsesOnlyNewerCertifiedRevision(): Unit {
        let old = p8Items([p8Item("语法🙂", 1, "old")])
        let newer = p8Items([p8Item("语法🙂", 2, "new")])
        let resolved = ckbResolveCertifiedKnowledgeRecords(old, newer)
        @Expect(resolved.size, 1)
        @Expect(resolved[0].revision, 2)
        @Expect(resolved[0].record.chunk, "knowledge-new-中文🙂")
        @Expect(ckbCertifiedKnowledgeRecordsDiagnostic(resolved), "ok")
        let q1="{\"ok\":true,\"knowledgeVersion\":\"v\",\"atomIds\":[\"b\",\"a\"],\"contentHash\":\"h\",\"citation\":\"verified\"}";let q2="{\"citation\":\"verified\",\"contentHash\":\"h\",\"atomIds\":[\"a\",\"b\"],\"knowledgeVersion\":\"v\",\"ok\":true}";let c1=ckbCanonicalizeCertifiedQueryPayload(q1);let c2=ckbCanonicalizeCertifiedQueryPayload(q2);@Expect(c1[0],c2[0]);@Expect(c1[1],c2[1])
    }

    @TestCase
    public func p8Bnd01ZeroSingleAndBatchReplacementCountsAreExact(): Unit {
        let base = p8Items([p8Item("id-a", 1, "a"), p8Item("id-b", 1, "b")])
        @Expect(ckbResolveCertifiedKnowledgeRecords(base, ArrayList<CkbCertifiedKnowledgeRecord>()).size, 2)
        let one = ckbResolveCertifiedKnowledgeRecords(base, p8Items([p8Item("id-a", 2, "a2")]))
        @Expect(one.size, 2)
        var batch = ArrayList<CkbCertifiedKnowledgeRecord>()
        for (i in 0..300) { batch.add(p8Item("batch-${i}", 1, "值-${i}-🙂")) }
        @Expect(ckbResolveCertifiedKnowledgeRecords(ArrayList<CkbCertifiedKnowledgeRecord>(), batch).size, 300)
    }

    @TestCase
    public func p8Pos01CertifiedCandidatePromotesThroughActiveTransaction(): Unit {
        let incoming = p8CoverageItems(1);let kb = newOfflineKnowledgeBase();let existing=p8Existing(kb);let records=incoming
        let proof = p8Proof(records, "ckb-p8-pos")
        let root = "target/p8-pos-${ckbCertifiedKnowledgeRecordsChecksum(records)}-${ckbCoreNowMillis()}".replace(":", "-")
        let store = FileKnowledgeStore(root); let key = p8ReleaseKey("pos")
        let report = ckbPublishCertifiedKnowledgeWithReleaseState(kb, store, key, "ckb-p8-pos-candidate", kb.status().activeKnowledgeVersion, existing, incoming, proof)
        @Expect(report.ok, true)
        @Expect(report.status, "certified_production_published")
        @Expect(report.activeVersion, "ckb-p8-pos-active")
        @Expect(report.promotion.snapshotPointerCommitted, true)
        @Expect(ckbLoadReleaseAcquisitionState(store, key).state, "certified_active")
    }

    @TestCase
    public func p8Neg01UncertifiedTamperedAndVectorMismatchAreFailClosed(): Unit {
        let incoming = p8CoverageItems(1)
        let store = FileKnowledgeStore("target/p8-neg-store")
        let kb = newOfflineKnowledgeBase()
        let existing=p8Existing(kb);let records=incoming
        let noCert = p8Proof(records, "ckb-p8-neg"); noCert.p7GateJson = noCert.p7GateJson.replace("\"ok\":true", "\"ok\":false")
        let denied = ckbPublishCertifiedKnowledge(kb, store, "ckb-p8-neg-candidate", kb.status().activeKnowledgeVersion, existing, incoming, noCert)
        @Expect(denied.ok, false); @Expect(denied.diagnostic, "p7_gate_artifact_mismatch"); @Expect(store.loadActiveSnapshotPointer().valid, false)
        let tampered = p8Proof(records, "ckb-p8-neg"); tampered.candidateArtifactJsonl = tampered.candidateArtifactJsonl.replace("knowledge", "tampered")
        @Expect(ckbCertifiedProductionProofDiagnostic(tampered, records), "candidate_artifact_mismatch")
        let vectorMismatch = p8Proof(records, "ckb-p8-neg"); vectorMismatch.vectorArtifactJson = vectorMismatch.vectorArtifactJson.replace("\"count\":${records.size}", "\"count\":0")
        @Expect(ckbCertifiedProductionProofDiagnostic(vectorMismatch, records), "vector_artifact_mismatch")
        let queryTamper=p8Proof(records,"ckb-p8-neg");queryTamper.httpQueryPayload=queryTamper.httpQueryPayload.replace("\"citation\":\"verified\"","\"citation\":\"tampered\"");@Expect(ckbCertifiedProductionProofDiagnostic(queryTamper,records),"transport_query_proof_mismatch")
        let manifestTamper=p8Proof(records,"ckb-p8-neg");manifestTamper.versionManifestJson=manifestTamper.versionManifestJson.replace("ckb-p8-neg-candidate","wrong-candidate");@Expect(ckbCertifiedProductionProofDiagnostic(manifestTamper,records),"version_manifest_mismatch")
        let resultTamper=p8Proof(records,"ckb-p8-neg");resultTamper.p7ResultsJsonl=resultTamper.p7ResultsJsonl.replace("\"retryUsed\":false","\"retryUsed\":true");@Expect(ckbCertifiedProductionProofDiagnostic(resultTamper,records),"p7_gate_artifact_mismatch")
        let conflict = p8Items([p8Item("same", 1, "a"), p8Item("same", 2, "b")])
        @Expect(ckbCertifiedKnowledgeRecordsDiagnostic(conflict), "canonical_identity_conflict")
        @Expect(ckbCertifiedReplacementDiagnostic(p8Items([p8Item("same",2,"old")]),p8Items([p8Item("same",2,"different")])),"certified_revision_conflict")
        let omitted=ArrayList<CkbCertifiedKnowledgeRecord>();for(i in 1..existing.size){omitted.add(existing[i])};let omittedResolved=ckbResolveCertifiedKnowledgeRecords(omitted,incoming);let omittedKey=p8ReleaseKey("omitted");let omittedReport=ckbPublishCertifiedKnowledgeWithReleaseState(kb,store,omittedKey,"ckb-p8-neg-candidate",kb.status().activeKnowledgeVersion,omitted,incoming,p8Proof(omittedResolved,"ckb-p8-neg"));@Expect(omittedReport.diagnostic,"existing_active_count_mismatch");@Expect(ckbLoadReleaseAcquisitionState(store,omittedKey).status,"not_found")
        @Expect(store.loadActiveSnapshotPointer().valid,false)
    }

    @TestCase
    public func p8E2e01CandidateStagingActiveReloadAndQueryProofStayBound(): Unit {
        let incoming=p8CoverageItems(64);let kb=newOfflineKnowledgeBase();let existing=p8Existing(kb);let records=incoming
        let proof = p8Proof(records, "ckb-p8-e2e")
        let store = FileKnowledgeStore("target/p8-e2e-${ckbCertifiedKnowledgeRecordsChecksum(records)}-${ckbCoreNowMillis()}".replace(":", "-"))
        let key = p8ReleaseKey("e2e")
        let report = ckbPublishCertifiedKnowledgeWithReleaseState(kb, store, key, "ckb-p8-e2e-candidate", kb.status().activeKnowledgeVersion, existing, incoming, proof)
        let pointer = store.loadActiveSnapshotPointer()
        let reloaded = store.loadActiveSnapshot()
        @Expect(report.ok, true)
        @Expect(pointer.valid, true)
        @Expect(pointer.activeVersion, "ckb-p8-e2e-active")
        @Expect(reloaded.valid, true)
        @Expect(reloaded.normalizedRecords.size, records.size)
        @Expect(proof.stdioQueryPayload, proof.httpQueryPayload)
        @Expect(report.evidenceHash.startsWith("sha256:"), true)
        @Expect(store.has("teacher-solutions"), false)
        @Expect(store.has("certification-transcript.jsonl"), false)
        let state = ckbLoadReleaseAcquisitionState(store, key)
        @Expect(state.valid, true); @Expect(state.certifiedVersion, "ckb-p8-e2e"); @Expect(state.certificationFingerprint, p8Hash("fingerprint"))
    }
}

private class R5CompetingPointerInjector <: CkbActiveSnapshotFaultInjector {
    let store: FileKnowledgeStore
    public var competingTxId: String = ""
    var injected: Bool = false
    public init(store: FileKnowledgeStore) { this.store = store }
    public func checkpoint(point: String): Unit {
        if (point == CkbActiveSnapshotFaultPoints.POINTER_BEFORE && !injected) {
            injected = true
            let competing = newOfflineKnowledgeBase()
            let committed = competing.persistActiveSnapshot(store)
            competingTxId = committed.txId
        }
    }
}

private class R5FrozenPointerDriftInjector <: CkbFrozenCandidateFaultInjector { let store:FileKnowledgeStore;public init(store:FileKnowledgeStore){this.store=store};public func checkpoint():Unit{_=newOfflineKnowledgeBase().persistActiveSnapshot(this.store)} }

private func p8Item(identity: String, revision: Int64, content: String): CkbCertifiedKnowledgeRecord {
    let item = CkbCertifiedKnowledgeRecord(); item.canonicalIdentity = identity; item.revision = revision
    item.record = p8Record("${identity}-${revision}", CangjieTypedRecordKinds.DOC_SECTION, "Knowledge ${content}", "knowledge-${content}-中文🙂", CangjieSourceSets.DOCS)
    item.evidenceHash = ckbCertifiedKnowledgeRecordEvidenceHash(item)
    item
}

private func p8CoverageItems(extra: Int64): ArrayList<CkbCertifiedKnowledgeRecord> {
    let out = ArrayList<CkbCertifiedKnowledgeRecord>()
    out.add(p8Wrapped("symbol", CangjieTypedRecordKinds.SYMBOL_CARD, "ArrayList.add", "symbolKey=ArrayList.add\nmodule=std.collection\nsignature=func add(value: T): Unit\naliases=ArrayList.add;add", CangjieSourceSets.STD))
    out.add(p8Wrapped("doc", CangjieTypedRecordKinds.DOC_SECTION, "ArrayList.add docs", "ArrayList.add appends values. Do not use append. 中文🙂", CangjieSourceSets.DOCS))
    out.add(p8Wrapped("tool", CangjieTypedRecordKinds.TOOL_MANUAL, "cjpm test", "Run cjpm test to execute package tests.", CangjieSourceSets.TOOLS))
    for (i in 0..extra) { out.add(p8Wrapped("extra-${i}", CangjieTypedRecordKinds.DOC_SECTION, "Extra ${i}", "extra knowledge ${i}", CangjieSourceSets.DOCS)) }
    out
}

private func p8Wrapped(id: String, kind: String, title: String, chunk: String, sourceSet: String): CkbCertifiedKnowledgeRecord {
    let item = CkbCertifiedKnowledgeRecord(); item.canonicalIdentity = "p8:${id}"; item.revision = 1; item.record = p8Record(id, kind, title, chunk, sourceSet); item.evidenceHash = ckbCertifiedKnowledgeRecordEvidenceHash(item); item
}

private func p8Record(id: String, kind: String, title: String, chunk: String, sourceSet: String): NormalizedRecord {
    let record = NormalizedRecord(); record.sourceId = id; record.recordKind = kind; record.title = title; record.chunk = chunk; record.citation = "https://docs.cangjie-lang.cn/docs/1.0.0/${id}"; record.metadata.sourceId = id; record.metadata.sourceType = if (sourceSet == CangjieSourceSets.STD) { SourceTypes.REPO } else { SourceTypes.DOC }; record.metadata.sourceSet = sourceSet; record.metadata.targetVersion = "1.0.0"; record.metadata.versionResolutionId = "p8-vr-${id}"; record.metadata.path = if (kind == CangjieTypedRecordKinds.TOOL_MANUAL) { "tools/${id}.md" } else { "docs/${id}.md" }; record.metadata.trustLevel = TrustLevels.OFFICIAL; record.metadata.reviewState = ReviewStates.TRUSTED; record
}

private func p8Proof(records: ArrayList<CkbCertifiedKnowledgeRecord>, version: String): CkbProductionReleaseProof {
    let proof=CkbProductionReleaseProof();let normalized=ArrayList<NormalizedRecord>();for(item in records){normalized.add(item.record)}
    proof.studentLeakageArtifactJson=ckbBuildStudentLeakageReport(normalized).json
    proof.anonymousQueryArtifactJson="{\"ok\":true,\"indexBuildCount\":1,\"failed\":0}"
    proof.authorityIsolationArtifactJson="{\"ok\":true,\"authorityCount\":164,\"authorityHash\":\"${p8Hash("authority")}\",\"activeEvalCount\":0}"
    proof.atomTestArtifactJson="{\"ok\":true,\"diagnostic\":\"validated\"}"
    proof.studentLeakageProofJson=ckbRenderCandidateTrustSeal(normalized,proof.studentLeakageArtifactJson,proof.anonymousQueryArtifactJson,proof.authorityIsolationArtifactJson,proof.atomTestArtifactJson)
    let checksum=ckbCertifiedKnowledgeRecordsChecksum(records);let leakageHash=p8Hash(proof.studentLeakageProofJson);let fingerprint=p8Hash("fingerprint");proof.frozenCandidateManifestJson=p8FrozenManifest(version,checksum,leakageHash);proof.frozenCandidateManifestHash=p8Hash(proof.frozenCandidateManifestJson)
    proof.p6PreflightJson="{\"ok\":true,\"startAllowed\":true,\"diagnostic\":\"ok\",\"fingerprint\":\"${fingerprint}\",\"candidateChecksum\":\"${checksum}\",\"studentLeakageProofHash\":\"${leakageHash}\",\"frozenCandidateManifestHash\":\"${proof.frozenCandidateManifestHash}\",\"certificationPassAt1\":null,\"violations\":[]}"
    let preflightHash=p8Hash(proof.p6PreflightJson);let runManifestHash=p8Hash(p8Part("p8-certification")+p8Part(preflightHash)+p8Part(fingerprint)+p8Part(p8Hash("provider"))+p8Part("GLM-5.2")+p8Part("claude-code-p8")+p8Part(CkbAbcdeGroups.C)+p8Part(checksum)+p8Part(leakageHash)+p8Part(proof.frozenCandidateManifestHash))
    proof.p6RunManifestJson="{\"runId\":\"p8-certification\",\"startAllowed\":true,\"fingerprint\":\"${fingerprint}\",\"providerIdentityHash\":\"${p8Hash("provider")}\",\"modelVersion\":\"GLM-5.2\",\"claudeCodeVersion\":\"claude-code-p8\",\"certificationTransport\":\"${CkbAbcdeGroups.C}\",\"candidateChecksum\":\"${checksum}\",\"studentLeakageProofHash\":\"${leakageHash}\",\"frozenCandidateManifestHash\":\"${proof.frozenCandidateManifestHash}\",\"preflightHash\":\"${preflightHash}\",\"runManifestHash\":\"${runManifestHash}\",\"certificationPassAt1\":null}"
    proof.authorityManifestJsonl=p8Authority();proof.p7ResultsJsonl=p8CertificationRows(proof.authorityManifestJsonl,version,preflightHash,runManifestHash);proof.p7GateJson=renderCkbStrictCertificationGateJson(ckbStrictCertificationGate(proof.p7ResultsJsonl,proof.authorityManifestJsonl));proof.candidateArtifactJsonl=ckbRenderCertifiedCandidateArtifact(records);proof.indexArtifactJson=ckbRenderCertifiedCountArtifact("index",records);proof.vectorArtifactJson=ckbRenderCertifiedCountArtifact("vector",records);proof.versionManifestJson=ckbRenderCertifiedVersionManifest(version,records);proof.stdioQueryPayload=ckbRenderCertifiedQueryPayload(version,records);proof.httpQueryPayload=proof.stdioQueryPayload;proof
}

private func p8Items(items: Array<CkbCertifiedKnowledgeRecord>): ArrayList<CkbCertifiedKnowledgeRecord> { let out = ArrayList<CkbCertifiedKnowledgeRecord>(); for (item in items) { out.add(item) }; out }
private func p8Hash(value: String): String { benchmarkGapSha256(value) }
private func p8Part(value:String):String{"${value.toArray().size}:${value}"}
private func p8FrozenManifest(version:String,candidate:String,leakage:String):String{let body="{\"schemaVersion\":\"ckb-frozen-candidate-v1\",\"knowledgeVersion\":\"${version}\",\"txIdHash\":\"${p8Hash("tx")}\",\"activePointerHash\":\"${p8Hash("pointer")}\",\"transactionHash\":\"${p8Hash("transaction")}\",\"candidateChecksum\":\"${candidate}\",\"inputHash\":\"${p8Hash("input")}\",\"configHash\":\"${p8Hash("config")}\",\"modelHash\":\"${p8Hash("model")}\",\"studentLeakageProofHash\":\"${leakage}\",\"authorityIsolationArtifactHash\":\"${p8Hash("authority")}\",\"anonymousQueryArtifactHash\":\"${p8Hash("query")}\",\"atomTestArtifactHash\":\"${p8Hash("atom")}\"";body+",\"evidenceHash\":\"${p8Hash(body+"}")}\"}"}
private func p8ReleaseKey(id: String): CkbScheduledFetchRunKey { let key = CkbScheduledFetchRunKey(); key.acquisitionId = "p8-${id}"; key.planningIdentityHash = p8Hash("planning-${id}"); key.runIdentityHash = p8Hash("run-${id}"); key }
private func p8Existing(kb:KnowledgeBase):ArrayList<CkbCertifiedKnowledgeRecord>{let out=ArrayList<CkbCertifiedKnowledgeRecord>();for(row in kb.activeRecordSnapshot()){let item=CkbCertifiedKnowledgeRecord();item.canonicalIdentity="active:${row.sourceId}";item.revision=1;item.record=row;item.evidenceHash=ckbCertifiedKnowledgeRecordEvidenceHash(item);out.add(item)};out}
private func p8Authority():String{cangjieHumanEvalRenderAuthorityManifest(buildCangjieHumanEvalManifest("cangjie_eval/cases/Cangjie-HumanEval",""))}
private func p8CertificationRows(authorityText:String,version:String,preflightHash:String,runManifestHash:String):String{let authority=parseCangjieHumanEvalAuthorityManifest(authorityText);var out="";for(i in 0..authority.rows.size){let row=CkbCertificationCaseEvidence();row.runId="p8-certification";row.caseId=authority.rows[i].caseId;row.group=CkbAbcdeGroups.C;row.datasetVersion=authority.datasetVersion;row.knowledgeVersion=version;row.modelFingerprint=p8Hash("fingerprint");row.expectedModelVersion="GLM-5.2";row.observedModelVersion="GLM-5.2";row.claudeCodeVersion="claude-code-p8";row.providerIdentityHash=p8Hash("provider");row.preflightHash=preflightHash;row.runManifestHash=runManifestHash;row.authorityCaseHash=authority.rows[i].caseHash;row.authorityTestsHash=authority.rows[i].testsHash;row.workspaceId=p8Hash("workspace-${i}");row.sessionId=p8Hash("session-${i}");row.runtimeHomeId=p8Hash("home-${i}");row.isolationEvidenceHash=p8Hash("isolation-${i}");row.answerHash=p8Hash("answer-${i}");row.transcriptHash=p8Hash("transcript-${i}");row.testHash=p8Hash("test-${i}");row.configHash=p8Hash("config-${i}");row.artifactHash=p8Hash("artifact-${i}");row.sampleAttemptCount=1;row.llmTurnCount=21;row.sandboxDeniedOutsideWorkspace=true;row.verifierMountedAfterAnswerFreeze=true;row.certificationPassAt1=true;sealCkbCertificationEvidence(row);out+=renderCkbCertificationEvidenceJson(row)+"\n"};out}
