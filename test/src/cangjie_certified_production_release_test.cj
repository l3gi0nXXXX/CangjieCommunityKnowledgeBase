package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbCertifiedProductionReleaseTest {
    @TestCase
    public func p8Ut01CanonicalConflictUsesOnlyNewerCertifiedRevision(): Unit {
        let old = p8Items([p8Item("语法🙂", 1, "old")])
        let newer = p8Items([p8Item("语法🙂", 2, "new")])
        let resolved = ckbResolveCertifiedKnowledgeRecords(old, newer)
        @Expect(resolved.size, 1)
        @Expect(resolved[0].revision, 2)
        @Expect(resolved[0].record.chunk, "knowledge-new-中文🙂")
        @Expect(ckbCertifiedKnowledgeRecordsDiagnostic(resolved), "ok")
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
        let records = p8CoverageItems(1)
        let proof = p8Proof(records, "ckb-p8-pos")
        let root = "target/p8-pos-${proof.candidateChecksum}-${ckbCoreNowMillis()}".replace(":", "-")
        let kb = newOfflineKnowledgeBase()
        let store = FileKnowledgeStore(root); let key = p8ReleaseKey("pos")
        let report = ckbPublishCertifiedKnowledgeWithReleaseState(kb, store, key, "ckb-p8-pos-candidate", kb.status().activeKnowledgeVersion, ArrayList<CkbCertifiedKnowledgeRecord>(), records, proof)
        @Expect(report.ok, true)
        @Expect(report.status, "certified_production_published")
        @Expect(report.activeVersion, "ckb-p8-pos-active")
        @Expect(report.promotion.snapshotPointerCommitted, true)
        @Expect(ckbLoadReleaseAcquisitionState(store, key).state, "certified_active")
    }

    @TestCase
    public func p8Neg01UncertifiedTamperedAndVectorMismatchAreFailClosed(): Unit {
        let records = p8CoverageItems(1)
        let store = FileKnowledgeStore("target/p8-neg-store")
        let kb = newOfflineKnowledgeBase()
        let noCert = p8Proof(records, "ckb-p8-neg"); noCert.certification.ok = false
        let denied = ckbPublishCertifiedKnowledge(kb, store, "ckb-p8-neg-candidate", "", ArrayList<CkbCertifiedKnowledgeRecord>(), records, noCert)
        @Expect(denied.ok, false); @Expect(denied.diagnostic, "p7_strict_certification_required"); @Expect(store.loadActiveSnapshotPointer().valid, false)
        let tampered = p8Proof(records, "ckb-p8-neg"); tampered.candidateChecksum = p8Hash("tampered")
        @Expect(ckbCertifiedProductionProofDiagnostic(tampered, records), "candidate_checksum_mismatch")
        let vectorMismatch = p8Proof(records, "ckb-p8-neg"); vectorMismatch.vectorCount -= 1
        @Expect(ckbCertifiedProductionProofDiagnostic(vectorMismatch, records), "store_index_vector_count_mismatch")
        let conflict = p8Items([p8Item("same", 1, "a"), p8Item("same", 2, "b")])
        @Expect(ckbCertifiedKnowledgeRecordsDiagnostic(conflict), "canonical_identity_conflict")
    }

    @TestCase
    public func p8E2e01CandidateStagingActiveReloadAndQueryProofStayBound(): Unit {
        let records = p8CoverageItems(64)
        let proof = p8Proof(records, "ckb-p8-e2e")
        let store = FileKnowledgeStore("target/p8-e2e-${proof.candidateChecksum}-${ckbCoreNowMillis()}".replace(":", "-"))
        let kb = newOfflineKnowledgeBase()
        let key = p8ReleaseKey("e2e")
        let report = ckbPublishCertifiedKnowledgeWithReleaseState(kb, store, key, "ckb-p8-e2e-candidate", kb.status().activeKnowledgeVersion, ArrayList<CkbCertifiedKnowledgeRecord>(), records, proof)
        let pointer = store.loadActiveSnapshotPointer()
        let reloaded = store.loadActiveSnapshot()
        @Expect(report.ok, true)
        @Expect(pointer.valid, true)
        @Expect(pointer.activeVersion, "ckb-p8-e2e-active")
        @Expect(reloaded.valid, true)
        @Expect(reloaded.normalizedRecords.size, records.size)
        @Expect(proof.stdioQueryProofHash, proof.httpQueryProofHash)
        @Expect(report.evidenceHash.startsWith("sha256:"), true)
        @Expect(store.has("teacher-solutions"), false)
        @Expect(store.has("certification-transcript.jsonl"), false)
        let state = ckbLoadReleaseAcquisitionState(store, key)
        @Expect(state.valid, true); @Expect(state.certifiedVersion, proof.certifiedKnowledgeVersion); @Expect(state.certificationFingerprint, proof.certificationFingerprint)
    }
}

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
    let proof = CkbProductionReleaseProof(); proof.certification.ok = true; proof.certification.total = 164; proof.certification.unitPass = 164; proof.certification.unitPassAt1 = 164; proof.certification.group = CkbAbcdeGroups.C; proof.certification.datasetVersion = "cangjie-humaneval-164-v1"; proof.certification.knowledgeVersion = version; proof.certification.modelFingerprint = p8Hash("fingerprint"); proof.certificationFingerprint = proof.certification.modelFingerprint; proof.certifiedKnowledgeVersion = version; proof.candidateCount = records.size; proof.indexCount = records.size; proof.vectorCount = records.size; proof.candidateChecksum = ckbCertifiedKnowledgeRecordsChecksum(records); proof.versionManifestHash = p8Hash("manifest-${version}"); proof.stdioQueryProofHash = ckbCertifiedProductionQueryProofHash(version, proof.candidateChecksum, proof.versionManifestHash); proof.httpQueryProofHash = proof.stdioQueryProofHash; proof
}

private func p8Items(items: Array<CkbCertifiedKnowledgeRecord>): ArrayList<CkbCertifiedKnowledgeRecord> { let out = ArrayList<CkbCertifiedKnowledgeRecord>(); for (item in items) { out.add(item) }; out }
private func p8Hash(value: String): String { benchmarkGapSha256(value) }
private func p8ReleaseKey(id: String): CkbScheduledFetchRunKey { let key = CkbScheduledFetchRunKey(); key.acquisitionId = "p8-${id}"; key.planningIdentityHash = p8Hash("planning-${id}"); key.runIdentityHash = p8Hash("run-${id}"); key }
