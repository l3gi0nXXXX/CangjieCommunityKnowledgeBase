package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{File, Path}
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
        let incoming = p8CoverageItems(1);let kb = newOfflineKnowledgeBase();let existing=p8Existing(kb);let records=ckbResolveCertifiedKnowledgeRecords(existing,incoming)
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
        let existing=p8Existing(kb);let records=ckbResolveCertifiedKnowledgeRecords(existing,incoming)
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
        let incoming=p8CoverageItems(64);let kb=newOfflineKnowledgeBase();let existing=p8Existing(kb);let records=ckbResolveCertifiedKnowledgeRecords(existing,incoming)
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
    let proof = CkbProductionReleaseProof(); proof.authorityManifestJsonl = p8Authority(); proof.p7ResultsJsonl = p8CertificationRows(proof.authorityManifestJsonl, version); proof.p7GateJson = renderCkbStrictCertificationGateJson(ckbStrictCertificationGate(proof.p7ResultsJsonl, proof.authorityManifestJsonl)); proof.candidateArtifactJsonl = ckbRenderCertifiedCandidateArtifact(records); proof.indexArtifactJson = ckbRenderCertifiedCountArtifact("index", records); proof.vectorArtifactJson = ckbRenderCertifiedCountArtifact("vector", records); proof.versionManifestJson = ckbRenderCertifiedVersionManifest(version, records); proof.stdioQueryPayload = ckbRenderCertifiedQueryPayload(version, records); proof.httpQueryPayload = proof.stdioQueryPayload; proof
}

private func p8Items(items: Array<CkbCertifiedKnowledgeRecord>): ArrayList<CkbCertifiedKnowledgeRecord> { let out = ArrayList<CkbCertifiedKnowledgeRecord>(); for (item in items) { out.add(item) }; out }
private func p8Hash(value: String): String { benchmarkGapSha256(value) }
private func p8ReleaseKey(id: String): CkbScheduledFetchRunKey { let key = CkbScheduledFetchRunKey(); key.acquisitionId = "p8-${id}"; key.planningIdentityHash = p8Hash("planning-${id}"); key.runIdentityHash = p8Hash("run-${id}"); key }
private func p8Existing(kb:KnowledgeBase):ArrayList<CkbCertifiedKnowledgeRecord>{let out=ArrayList<CkbCertifiedKnowledgeRecord>();for(row in kb.activeRecordSnapshot()){let item=CkbCertifiedKnowledgeRecord();item.canonicalIdentity="active:${row.sourceId}";item.revision=1;item.record=row;item.evidenceHash=ckbCertifiedKnowledgeRecordEvidenceHash(item);out.add(item)};out}
private func p8Authority():String{cangjieHumanEvalRenderAuthorityManifest(buildCangjieHumanEvalManifest("cangjie_eval/cases/Cangjie-HumanEval",""))}
private func p8CertificationRows(authorityText:String,version:String):String{let authority=parseCangjieHumanEvalAuthorityManifest(authorityText);var out="";for(i in 0..authority.rows.size){let row=CkbCertificationCaseEvidence();row.runId="p8-certification";row.caseId=authority.rows[i].caseId;row.group=CkbAbcdeGroups.C;row.datasetVersion=authority.datasetVersion;row.knowledgeVersion=version;row.modelFingerprint=p8Hash("fingerprint");row.expectedModelVersion="GLM-5.2";row.observedModelVersion="GLM-5.2";row.claudeCodeVersion="claude-code-p8";row.providerIdentityHash=p8Hash("provider");row.preflightHash=p8Hash("preflight");row.runManifestHash=p8Hash("run-manifest");row.authorityCaseHash=authority.rows[i].caseHash;row.authorityTestsHash=authority.rows[i].testsHash;row.workspaceId=p8Hash("workspace-${i}");row.sessionId=p8Hash("session-${i}");row.runtimeHomeId=p8Hash("home-${i}");row.isolationEvidenceHash=p8Hash("isolation-${i}");row.answerHash=p8Hash("answer-${i}");row.transcriptHash=p8Hash("transcript-${i}");row.testHash=p8Hash("test-${i}");row.configHash=p8Hash("config-${i}");row.artifactHash=p8Hash("artifact-${i}");row.llmTurnCount=1;row.sandboxDeniedOutsideWorkspace=true;row.verifierMountedAfterAnswerFreeze=true;row.certificationPassAt1=true;sealCkbCertificationEvidence(row);out+=renderCkbCertificationEvidenceJson(row)+"\n"};out}
