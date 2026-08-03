public package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashMap}
import std.fs.{File, Path, canonicalize, exists, rename, remove}
import std.sort.*
import stdx.encoding.json.*

// P8 is deliberately a gate and orchestration layer over the established
// candidate -> staging -> active transaction. It never writes active files.
public class CkbCertifiedKnowledgeRecord {
    public var canonicalIdentity: String = ""
    public var revision: Int64 = 0
    public var evidenceHash: String = ""
    public var record: NormalizedRecord = NormalizedRecord()
    public init() {}
}

public class CkbProductionReleaseProof {
    public var p6PreflightJson: String = ""
    public var p6RunManifestJson: String = ""
    public var p7ResultsJsonl: String = ""
    public var authorityManifestJsonl: String = ""
    public var p7GateJson: String = ""
    public var p7RunRoot: String = ""
    public var p7ArtifactManifestHash: String = ""
    public var candidateArtifactJsonl: String = ""
    public var indexArtifactJson: String = ""
    public var vectorArtifactJson: String = ""
    public var stdioQueryPayload: String = ""
    public var httpQueryPayload: String = ""
    public var versionManifestJson: String = ""
    public var studentLeakageArtifactJson: String = ""
    public var anonymousQueryArtifactJson: String = ""
    public var anonymousAtomQueryArtifactJson: String = ""
    public var restLeakageArtifactJson: String = ""
    public var mcpStdioLeakageArtifactJson: String = ""
    public var mcpHttpLeakageArtifactJson: String = ""
    public var authorityIsolationArtifactJson: String = ""
    public var atomTestArtifactJson: String = ""
    public var studentLeakageProofJson: String = ""
    public var frozenCandidateManifestJson:String=""
    public var frozenCandidateManifestHash:String=""
    public init() {}
}

public class CkbProductionReleaseReport {
    public var ok: Bool = false
    public var status: String = "blocked"
    public var diagnostic: String = ""
    public var certifiedKnowledgeVersion: String = ""
    public var activeVersion: String = ""
    public var candidateCount: Int64 = 0
    public var replacedCount: Int64 = 0
    public var unchangedCount: Int64 = 0
    public var removedCount: Int64 = 0
    public var evidenceHash: String = ""
    public var promotion: CangjieCandidatePromotionResult = CangjieCandidatePromotionResult()
    public init() {}
}

private class CkbP8LeakageAuthorityResult{var ok:Bool=false;var diagnostic:String="authority_manifest_invalid";var certification:CkbStrictCertificationGateResult=CkbStrictCertificationGateResult();var authority:CangjieBenchmarkLeakageAuthority=CangjieBenchmarkLeakageAuthority();init(){}}
public func ckbP8FrozenSourceDiagnostic(sourcePath:String,targetPath:String,manifestJson:String):String{if(ckbControlContainsSecret(manifestJson)){return "secret_artifact_forbidden"};try{let source=ckbP8CanonicalStorePath(sourcePath);let target=ckbP8CanonicalStorePath(targetPath);if(source==target){return "frozen_candidate_source_must_differ_from_target"};ckbFrozenCandidateManifestDiagnostic(FileKnowledgeStore(source),manifestJson)}catch(_:Exception){"frozen_candidate_store_invalid"}}
private func ckbP8CanonicalStorePath(path:String):String{canonicalize(Path(path).parent).toString()+"/"+Path(path).fileName}

public func ckbResolveCertifiedKnowledgeRecords(existing: ArrayList<CkbCertifiedKnowledgeRecord>, incoming: ArrayList<CkbCertifiedKnowledgeRecord>): ArrayList<CkbCertifiedKnowledgeRecord> {
    let byIdentity = HashMap<String, CkbCertifiedKnowledgeRecord>()
    for (item in existing) {
        if (ckbP8RecordDiagnostic(item) == "ok") { byIdentity[item.canonicalIdentity] = item }
    }
    for (item in incoming) {
        if (ckbP8RecordDiagnostic(item) != "ok") { continue }
        match (byIdentity.get(item.canonicalIdentity)) {
            case Some(old) =>
                // Exact evidence is idempotent. A different evidence record is
                // accepted only as a strictly newer certified revision.
                if (item.evidenceHash == old.evidenceHash || item.revision > old.revision) {
                    byIdentity[item.canonicalIdentity] = item
                }
            case None => byIdentity[item.canonicalIdentity] = item
        }
    }
    let out = ArrayList<CkbCertifiedKnowledgeRecord>()
    for ((_, value) in byIdentity) { out.add(value) }
    out
}

public func ckbCertifiedKnowledgeRecordsDiagnostic(records: ArrayList<CkbCertifiedKnowledgeRecord>): String {
    let identities = HashMap<String, String>()
    for (item in records) {
        let diagnostic = ckbP8RecordDiagnostic(item)
        if (diagnostic != "ok") { return diagnostic }
        match (identities.get(item.canonicalIdentity)) {
            case Some(evidence) => if (evidence != item.evidenceHash) { return "canonical_identity_conflict" } else { return "canonical_identity_duplicate" }
            case None => identities[item.canonicalIdentity] = item.evidenceHash
        }
    }
    "ok"
}

public func ckbCertifiedStudentRecordGateDiagnostic(records:ArrayList<CkbCertifiedKnowledgeRecord>,authority:CangjieBenchmarkLeakageAuthority):String{for(item in records){let diagnostic=cangjieStudentRecordDiagnostic(item.record,authority:authority);if(!diagnostic.ok){return diagnostic.code}};"ok"}

public func ckbCertifiedReplacementDiagnostic(existing:ArrayList<CkbCertifiedKnowledgeRecord>,incoming:ArrayList<CkbCertifiedKnowledgeRecord>):String{for(newItem in incoming){for(oldItem in existing){if(newItem.canonicalIdentity==oldItem.canonicalIdentity&&newItem.evidenceHash!=oldItem.evidenceHash&&newItem.revision<=oldItem.revision){return "certified_revision_conflict"}}};"ok"}
private func ckbP8ExistingActiveDiagnostic(kb:KnowledgeBase,existing:ArrayList<CkbCertifiedKnowledgeRecord>):String{let active=kb.activeRecordSnapshot();if(active.size!=existing.size){return "existing_active_count_mismatch"};let declared=ArrayList<NormalizedRecord>();for(item in existing){declared.add(item.record)};if(ckbCertifiedNormalizedRecordsChecksum(active)!=ckbCertifiedNormalizedRecordsChecksum(declared)){return "existing_active_content_mismatch"};"ok"}

public func ckbCertifiedProductionProofDiagnostic(proof: CkbProductionReleaseProof, records: ArrayList<CkbCertifiedKnowledgeRecord>): String {
    if(ckbCertificationPreflightSealDiagnostic(proof.p6PreflightJson,proof.p6RunManifestJson)!="ok"){return "p6_seal_artifact_mismatch"}
    if(proof.p7RunRoot.trimAscii()==""||!ckbP8Hash(proof.p7ArtifactManifestHash)){return "p7_artifact_run_required"}
    let runPreflight=ckbP8ReadArtifact(proof.p7RunRoot+"/preflight.json");let runManifest=ckbP8ReadArtifact(proof.p7RunRoot+"/run-manifest.json");if(!runPreflight.ok||!runManifest.ok||runPreflight.text!=proof.p6PreflightJson||runManifest.text!=proof.p6RunManifestJson){return "p6_p7_byte_binding_mismatch"}
    let authorityResult=ckbP8ValidatedLeakageAuthority(proof);if(!authorityResult.ok){return authorityResult.diagnostic};let certification=authorityResult.certification
    if (!certification.ok || certification.artifactManifestHash!=proof.p7ArtifactManifestHash || proof.p7GateJson != renderCkbStrictCertificationGateJson(certification) || proof.p7ResultsJsonl!=ckbP8ReadArtifact(proof.p7RunRoot+"/results.jsonl").text) { return "p7_gate_artifact_mismatch" }
    let recordDiagnostic = ckbCertifiedKnowledgeRecordsDiagnostic(records)
    if (recordDiagnostic != "ok") { return recordDiagnostic }
    let studentDiagnostic=ckbP8CertifiedStudentLeakageDiagnostic(records,authorityResult.authority);if(studentDiagnostic!="ok"){return studentDiagnostic}
    let checksum = ckbCertifiedKnowledgeRecordsChecksum(records)
    if(proof.studentLeakageProofJson.trimAscii()==""){return "student_leakage_proof_required"}
    let p6Binding=ckbP8P6BindingDiagnostic(proof,checksum);if(p6Binding!="ok"){return p6Binding}
    if(proof.frozenCandidateManifestJson.trimAscii()==""||proof.frozenCandidateManifestHash!=benchmarkGapSha256(proof.frozenCandidateManifestJson)){return "frozen_candidate_manifest_required"}
    if(!proof.frozenCandidateManifestJson.contains("\"schemaVersion\":\"ckb-frozen-candidate-v2\"")||!proof.studentLeakageProofJson.contains("\"schemaVersion\":\"ckb-student-leakage-seal-v2\"")){return "student_leakage_proof_v2_required"}
    if(ckbFrozenCandidateManifestIntegrityDiagnostic(proof.frozenCandidateManifestJson,expectedCandidateChecksum:checksum,expectedLeakageProofHash:benchmarkGapSha256(proof.studentLeakageProofJson),expectedKnowledgeVersion:certification.knowledgeVersion)!="ok"){return "frozen_candidate_manifest_invalid"}
    if(ckbP8FrozenV2ArtifactsDiagnostic(proof)!="ok"){return "frozen_candidate_manifest_invalid"}
    let leakage=ckbP8StudentLeakageProofDiagnostic(proof,records,checksum);if(leakage!="ok"){return leakage}
    if (proof.candidateArtifactJsonl != ckbRenderCertifiedCandidateArtifact(records)) { return "candidate_artifact_mismatch" }
    let indexDiagnostic = ckbP8CountArtifactDiagnostic(proof.indexArtifactJson, "index", records.size, checksum)
    if (indexDiagnostic != "ok") { return indexDiagnostic }
    let vectorDiagnostic = ckbP8CountArtifactDiagnostic(proof.vectorArtifactJson, "vector", records.size, checksum)
    if (vectorDiagnostic != "ok") { return vectorDiagnostic }
    let manifestDiagnostic = ckbP8ManifestDiagnostic(proof.versionManifestJson, certification.knowledgeVersion, checksum)
    if (manifestDiagnostic != "ok") { return manifestDiagnostic }
    let expectedQuery=ckbRenderCertifiedQueryPayload(certification.knowledgeVersion,records);if(ckbCanonicalizeCertifiedQueryPayload(proof.stdioQueryPayload)!=("ok",expectedQuery)||ckbCanonicalizeCertifiedQueryPayload(proof.httpQueryPayload)!=("ok",expectedQuery)){return "transport_query_proof_mismatch"}
    "ok"
}

public func ckbCertifiedKnowledgeRecordsChecksum(records: ArrayList<CkbCertifiedKnowledgeRecord>): String {
    let normalized=ArrayList<NormalizedRecord>();for(item in records){normalized.add(item.record)};ckbCertifiedNormalizedRecordsChecksum(normalized)
}

public func ckbCertifiedNormalizedRecordsChecksum(records:ArrayList<NormalizedRecord>):String{let seeds=ArrayList<String>();for(record in records){seeds.add(ckbP8NormalizedRecordSeed(record))};let sorted=seeds.toArray();sort(sorted);let seed=StringBuilder();for(value in sorted){seed.append(ckbP8Part(value))};benchmarkGapSha256(seed.toString())}
public func ckbCertifiedNormalizedRecordSeed(record:NormalizedRecord):String{ckbP8NormalizedRecordSeed(record)}
private func ckbP8P6BindingDiagnostic(proof:CkbProductionReleaseProof,checksum:String):String{try{let m=JsonValue.fromStr(proof.p6RunManifestJson).asObject();let ph=ckbP8String(m,"preflightHash");let rh=ckbP8String(m,"runManifestHash");if(ckbP8String(m,"candidateChecksum")!=checksum||ckbP8String(m,"studentLeakageProofHash")!=benchmarkGapSha256(proof.studentLeakageProofJson)||ckbP8String(m,"frozenCandidateManifestHash")!=proof.frozenCandidateManifestHash){return "p6_candidate_binding_mismatch"};var saw=false;for(line in proof.p7ResultsJsonl.split("\n")){if(line.trimAscii()==""){continue};let row=parseCkbCertificationEvidence(line);saw=true;if(row.preflightHash!=ph||row.runManifestHash!=rh){return "p6_p7_lineage_mismatch"}};if(!saw){return "p6_p7_lineage_mismatch"};"ok"}catch(_:Exception){"p6_candidate_binding_mismatch"}}
private func ckbP8StudentLeakageProofDiagnostic(proof:CkbProductionReleaseProof,records:ArrayList<CkbCertifiedKnowledgeRecord>,checksum:String):String{let normalized=ArrayList<NormalizedRecord>();for(item in records){normalized.add(item.record)};if(ckbCertifiedNormalizedRecordsChecksum(normalized)!=checksum){return "student_knowledge_leakage_blocked"};if(ckbCandidateTrustSealDiagnostic(proof.studentLeakageProofJson,normalized,proof.studentLeakageArtifactJson,proof.anonymousQueryArtifactJson,proof.authorityIsolationArtifactJson,proof.atomTestArtifactJson,restText:proof.restLeakageArtifactJson,mcpStdioText:proof.mcpStdioLeakageArtifactJson,mcpHttpText:proof.mcpHttpLeakageArtifactJson,anonymousQueryText:proof.anonymousAtomQueryArtifactJson)!="ok"){return "student_leakage_proof_mismatch"};"ok"}

private func ckbP8ValidatedLeakageAuthority(proof:CkbProductionReleaseProof):CkbP8LeakageAuthorityResult{let result=CkbP8LeakageAuthorityResult();result.certification=ckbStrictCertificationGateFromRunRoot(proof.p7RunRoot,proof.authorityManifestJsonl);if(!result.certification.ok){result.diagnostic="p7_gate_artifact_mismatch";return result};let manifest=parseCangjieHumanEvalAuthorityManifest(proof.authorityManifestJsonl);if(!manifest.ok||manifest.rows.size!=164){return result};let records=ArrayList<NormalizedRecord>();for(row in manifest.rows){let record=NormalizedRecord();record.sourceId=row.caseId;record.recordKind=CangjieTypedRecordKinds.EVAL_SUPPORT;record.title=row.signature;record.chunk=row.prompt;record.citation=row.caseId;record.metadata.sourceId=row.caseId;record.metadata.sourceSet=CangjieSourceSets.EVAL_SUPPORT;record.metadata.path=row.caseId;record.metadata.symbol=row.signature;record.metadata.targetVersion=row.targetVersion;record.metadata.derivedFrom=[row.promptHash,row.metadataHash,row.starterHash,row.testsHash,row.translationHash,row.caseHash];records.add(record)};result.authority=buildCangjieBenchmarkLeakageAuthority(records);result.ok=true;result.diagnostic="ok";result}
private func ckbP8CertifiedStudentLeakageDiagnostic(records:ArrayList<CkbCertifiedKnowledgeRecord>,authority:CangjieBenchmarkLeakageAuthority):String{let diagnostic=ckbCertifiedStudentRecordGateDiagnostic(records,authority);if(diagnostic!="ok"){return diagnostic};let normalized=ArrayList<NormalizedRecord>();for(item in records){normalized.add(item.record)};if(!ckbBuildStudentLeakageReport(normalized,authority:authority).ok){return "student_knowledge_leakage_blocked"};"ok"}
private func ckbP8FrozenV2ArtifactsDiagnostic(proof:CkbProductionReleaseProof):String{try{let m=JsonValue.fromStr(proof.frozenCandidateManifestJson).asObject();if(ckbP8String(m,"schemaVersion")!="ckb-frozen-candidate-v2"||ckbP8String(m,"anonymousQueryArtifactHash")!=benchmarkGapSha256(proof.anonymousQueryArtifactJson)||ckbP8String(m,"anonymousAtomQueryArtifactHash")!=benchmarkGapSha256(proof.anonymousAtomQueryArtifactJson)||ckbP8String(m,"restLeakageArtifactHash")!=benchmarkGapSha256(proof.restLeakageArtifactJson)||ckbP8String(m,"mcpStdioLeakageArtifactHash")!=benchmarkGapSha256(proof.mcpStdioLeakageArtifactJson)||ckbP8String(m,"mcpHttpLeakageArtifactHash")!=benchmarkGapSha256(proof.mcpHttpLeakageArtifactJson)||ckbP8String(m,"authorityIsolationArtifactHash")!=benchmarkGapSha256(proof.authorityIsolationArtifactJson)||ckbP8String(m,"atomTestArtifactHash")!=benchmarkGapSha256(proof.atomTestArtifactJson)){return "frozen_candidate_v2_artifact_mismatch"};"ok"}catch(_:Exception){"frozen_candidate_v2_artifact_mismatch"}}

public class CkbCertifiedProductionPreCommitGate <: CangjieCandidatePreCommitGate {
    private let kb: KnowledgeBase
    private let expectedCandidateVersion: String
    private let expectedBaseActiveVersion: String
    private let proof: CkbProductionReleaseProof
    private let records: ArrayList<CkbCertifiedKnowledgeRecord>
    public init(kb:KnowledgeBase,expectedCandidateVersion: String, expectedBaseActiveVersion: String, proof: CkbProductionReleaseProof, records: ArrayList<CkbCertifiedKnowledgeRecord>) {
        this.kb=kb
        this.expectedCandidateVersion = expectedCandidateVersion
        this.expectedBaseActiveVersion = expectedBaseActiveVersion
        this.proof = proof
        this.records = records
    }
    public func evaluate(candidateVersion: String, activeVersion: String): CangjieCandidatePreCommitGateResult {
        let result = CangjieCandidatePreCommitGateResult()
        var diagnostic=ckbCertifiedStudentRecordGateDiagnostic(this.records,CangjieBenchmarkLeakageAuthority())
        if(diagnostic=="ok"){diagnostic=ckbCertifiedProductionProofDiagnostic(this.proof,this.records)}
        if(diagnostic=="ok"){diagnostic=ckbP8LiveStagingDiagnostic(this.kb,this.records)}
        if (diagnostic == "ok" && candidateVersion != this.expectedCandidateVersion) { diagnostic = "candidate_version_binding_mismatch" }
        if (diagnostic == "ok" && activeVersion != this.expectedBaseActiveVersion) { diagnostic = "active_version_changed_before_commit" }
        result.passed = diagnostic == "ok"
        result.terminal = true
        result.status = if (result.passed) { "certified_production_gate_passed" } else { diagnostic }
        result.evidenceHash = if (result.passed) { ckbP8ProofEvidence(this.proof) } else { "" }
        if (!result.passed) { result.diagnostics.add(diagnostic) }
        result
    }
}

public func ckbPublishCertifiedKnowledge(kb: KnowledgeBase, store: FileKnowledgeStore, candidateVersion: String, expectedBaseActiveVersion: String, existing: ArrayList<CkbCertifiedKnowledgeRecord>, incoming: ArrayList<CkbCertifiedKnowledgeRecord>, proof: CkbProductionReleaseProof, forceFailure!: Bool = false, snapshotFaultInjector!:CkbActiveSnapshotFaultInjector=NoopCkbActiveSnapshotFaultInjector()): CkbProductionReleaseReport {
    let report = CkbProductionReleaseReport()
    let certification = ckbStrictCertificationGateFromRunRoot(proof.p7RunRoot, proof.authorityManifestJsonl)
    report.certifiedKnowledgeVersion = certification.knowledgeVersion
    report.activeVersion = kb.status().activeKnowledgeVersion
    let activeDiagnostic=ckbP8ExistingActiveDiagnostic(kb,existing);if(activeDiagnostic!="ok"){report.diagnostic=activeDiagnostic;report.status=activeDiagnostic;return report}
    let incomingDiagnostic = ckbCertifiedKnowledgeRecordsDiagnostic(incoming)
    if (incomingDiagnostic != "ok") { report.diagnostic = incomingDiagnostic; report.status = incomingDiagnostic; return report }
    report.candidateCount = incoming.size
    for (newItem in incoming) {
        var found = false
        for (oldItem in existing) {
            if (oldItem.canonicalIdentity == newItem.canonicalIdentity) { found = true; if (oldItem.evidenceHash == newItem.evidenceHash) { report.unchangedCount += 1 } else { report.replacedCount += 1 }; break }
        }
        if (!found) { () }
    }
    for(oldItem in existing){var retained=false;for(newItem in incoming){if(oldItem.canonicalIdentity==newItem.canonicalIdentity){retained=true;break}};if(!retained){report.removedCount+=1}}
    let releaseGate = cangjieCertifiedProductionReleaseGate(proof, incoming)
    let diagnostic = releaseGate.diagnostic
    if (diagnostic != "ok") { report.diagnostic = diagnostic; report.status = diagnostic; return report }
    if (candidateVersion != "${certification.knowledgeVersion}-candidate") { report.diagnostic = "candidate_certified_version_mismatch"; report.status = report.diagnostic; return report }
    let normalized = ArrayList<NormalizedRecord>(); for (item in incoming) { normalized.add(item.record) }
    let gate = CkbCertifiedProductionPreCommitGate(kb,candidateVersion, expectedBaseActiveVersion, proof, incoming)
    let expectedPointerHash=ckbActiveSnapshotPointerIdentityHash(store.loadActiveSnapshotPointer())
    report.promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb, store, candidateVersion, normalized, forceFailure: forceFailure, preCommitGate: gate, expectedBaseActiveVersion: expectedBaseActiveVersion,expectedBaseActivePointerHash:expectedPointerHash,snapshotFaultInjector:snapshotFaultInjector)
    report.ok = report.promotion.ok && report.promotion.activePromoted && report.promotion.snapshotPointerCommitted && report.promotion.activeVersion == cangjieActiveVersionForCandidate(candidateVersion)
    report.status = if (report.ok) { "certified_production_published" } else { report.promotion.validation.status }
    report.diagnostic = if (report.ok) { "ok" } else { report.status }
    report.activeVersion = report.promotion.activeVersion
    report.evidenceHash = if (report.ok) { benchmarkGapSha256(ckbP8Part(ckbP8ProofEvidence(proof))+ckbP8Part(report.activeVersion)+ckbP8Part(ckbCertifiedKnowledgeRecordsChecksum(incoming))) } else { "" }
    report
}

func ckbPublishCertifiedKnowledgeWithReleaseState(kb: KnowledgeBase, store: FileKnowledgeStore, releaseKey: CkbScheduledFetchRunKey, candidateVersion: String, expectedBaseActiveVersion: String, existing: ArrayList<CkbCertifiedKnowledgeRecord>, incoming: ArrayList<CkbCertifiedKnowledgeRecord>, proof: CkbProductionReleaseProof, forceFailure!: Bool = false,forcePostCommitArtifactFailure!:Bool=false,snapshotFaultInjector!:CkbActiveSnapshotFaultInjector=NoopCkbActiveSnapshotFaultInjector()): CkbProductionReleaseReport {
    let gate = cangjieCertifiedProductionReleaseGate(proof, incoming)
    let certification = ckbStrictCertificationGateFromRunRoot(proof.p7RunRoot, proof.authorityManifestJsonl)
    let activeDiagnostic=ckbP8ExistingActiveDiagnostic(kb,existing);let incomingDiagnostic=ckbCertifiedKnowledgeRecordsDiagnostic(incoming);let versionOk=candidateVersion=="${certification.knowledgeVersion}-candidate";let baseOk=expectedBaseActiveVersion==kb.status().activeKnowledgeVersion
    if(!gate.ok||activeDiagnostic!="ok"||incomingDiagnostic!="ok"||!versionOk||!baseOk){return ckbPublishCertifiedKnowledge(kb,store,candidateVersion,expectedBaseActiveVersion,existing,incoming,proof,forceFailure:forceFailure,snapshotFaultInjector:snapshotFaultInjector)}
    ckbMarkReleaseAcquisitionState(store, releaseKey, "certified_staging", candidateVersion: candidateVersion, activeVersion: expectedBaseActiveVersion, certifiedVersion: certification.knowledgeVersion, certificationFingerprint: certification.modelFingerprint)
    let report = ckbPublishCertifiedKnowledge(kb, store, candidateVersion, expectedBaseActiveVersion, existing, incoming, proof, forceFailure: forceFailure,snapshotFaultInjector:snapshotFaultInjector)
    if (report.ok) {
        if(!forcePostCommitArtifactFailure){ckbMarkReleaseAcquisitionState(store, releaseKey, "certified_active", candidateVersion: candidateVersion, activeVersion: report.activeVersion, certifiedVersion: certification.knowledgeVersion, certificationFingerprint: certification.modelFingerprint)}
        let loaded = ckbLoadReleaseAcquisitionState(store, releaseKey)
        if (forcePostCommitArtifactFailure||!loaded.valid || loaded.state != "certified_active" || loaded.certifiedVersion != certification.knowledgeVersion || loaded.certificationFingerprint != certification.modelFingerprint || loaded.activeVersion != report.activeVersion) {
            report.status = "published_degraded"; report.diagnostic = "post_commit_artifact_failed"
        }
    }
    report
}

private func ckbP8RecordDiagnostic(item: CkbCertifiedKnowledgeRecord): String {
    if (item.canonicalIdentity.trimAscii() == "") { return "canonical_identity_required" }
    if (item.revision < 1) { return "revision_invalid" }
    if (item.record.sourceId.trimAscii() == "" || item.record.chunk.trimAscii() == "") { return "knowledge_record_incomplete" }
    if (!ckbP8Hash(item.evidenceHash) || item.evidenceHash != ckbCertifiedKnowledgeRecordEvidenceHash(item)) { return "record_evidence_hash_invalid" }
    "ok"
}

public func ckbCertifiedKnowledgeRecordEvidenceHash(item: CkbCertifiedKnowledgeRecord): String {
    benchmarkGapSha256(ckbP8Part(item.canonicalIdentity)+ckbP8Part("${item.revision}")+ckbP8Part(ckbP8NormalizedRecordSeed(item.record)))
}

public func ckbCertifiedProductionQueryProofHash(version: String, candidateChecksum: String, versionManifestHash: String): String {
    benchmarkGapSha256("${version}|${candidateChecksum}|${versionManifestHash}|stdio-http-query-parity")
}

private func ckbP8ProofEvidence(proof: CkbProductionReleaseProof): String {
    let seed=StringBuilder();for(value in [proof.p6PreflightJson,proof.p6RunManifestJson,proof.p7ResultsJsonl,proof.authorityManifestJsonl,proof.p7GateJson,proof.candidateArtifactJsonl,proof.indexArtifactJson,proof.vectorArtifactJson,proof.stdioQueryPayload,proof.httpQueryPayload,proof.versionManifestJson,proof.studentLeakageArtifactJson,proof.anonymousQueryArtifactJson,proof.authorityIsolationArtifactJson,proof.atomTestArtifactJson,proof.studentLeakageProofJson]){seed.append(ckbP8Part(value))};benchmarkGapSha256(seed.toString())
}
private func ckbP8LiveStagingDiagnostic(kb:KnowledgeBase,records:ArrayList<CkbCertifiedKnowledgeRecord>):String{let actual=kb.candidateRecordSnapshot();if(actual.size!=records.size){return "candidate_staging_count_mismatch"};let expected=ArrayList<NormalizedRecord>();for(item in records){expected.add(item.record)};if(ckbP8StagingRecordsChecksum(actual)!=ckbP8StagingRecordsChecksum(expected)){return "candidate_staging_content_mismatch"};"ok"}
private func ckbP8StagingRecordsChecksum(records:ArrayList<NormalizedRecord>):String{let rows=ArrayList<String>();for(record in records){let m=record.metadata;let original=m.candidateVersion;m.candidateVersion="";rows.add(ckbP8NormalizedRecordSeed(record));m.candidateVersion=original};let sorted=rows.toArray();sort(sorted);let seed=StringBuilder();for(row in sorted){seed.append(ckbP8Part(row))};benchmarkGapSha256(seed.toString())}

public func ckbRenderCertifiedCandidateArtifact(records:ArrayList<CkbCertifiedKnowledgeRecord>):String{let rows=ArrayList<String>();for(item in records){let r=item.record;let m=r.metadata;var derived="";for(i in 0..m.derivedFrom.size){if(i>0){derived+=","};derived+="\"${ckbP8Escape(m.derivedFrom[i])}\""};rows.add("{\"identity\":\"${ckbP8Escape(item.canonicalIdentity)}\",\"revision\":${item.revision},\"evidenceHash\":\"${item.evidenceHash}\",\"sourceId\":\"${ckbP8Escape(r.sourceId)}\",\"kind\":\"${ckbP8Escape(r.recordKind)}\",\"title\":\"${ckbP8Escape(r.title)}\",\"content\":\"${ckbP8Escape(r.chunk)}\",\"citation\":\"${ckbP8Escape(r.citation)}\",\"requiresReview\":${r.requiresReview},\"metadata\":{\"sourceId\":\"${ckbP8Escape(m.sourceId)}\",\"sourceType\":\"${ckbP8Escape(m.sourceType)}\",\"sourceUrl\":\"${ckbP8Escape(m.sourceUrl)}\",\"repo\":\"${ckbP8Escape(m.repo)}\",\"path\":\"${ckbP8Escape(m.path)}\",\"symbol\":\"${ckbP8Escape(m.symbol)}\",\"commit\":\"${ckbP8Escape(m.commit)}\",\"docVersion\":\"${ckbP8Escape(m.docVersion)}\",\"targetVersion\":\"${ckbP8Escape(m.targetVersion)}\",\"sourceSet\":\"${ckbP8Escape(m.sourceSet)}\",\"versionResolutionId\":\"${ckbP8Escape(m.versionResolutionId)}\",\"crawlAt\":\"${ckbP8Escape(m.crawlAt)}\",\"indexedAt\":\"${ckbP8Escape(m.indexedAt)}\",\"knowledgeVersion\":\"${ckbP8Escape(m.knowledgeVersion)}\",\"candidateVersion\":\"${ckbP8Escape(m.candidateVersion)}\",\"contentSize\":${m.contentSize},\"trustLevel\":\"${ckbP8Escape(m.trustLevel)}\",\"reviewState\":\"${ckbP8Escape(m.reviewState)}\",\"license\":\"${ckbP8Escape(m.license)}\",\"repoVisibility\":\"${ckbP8Escape(m.repoVisibility)}\",\"derivedFrom\":[${derived}]}}")};let sorted=rows.toArray();sort(sorted);var out="";for(row in sorted){out+=row+"\n"};out}
public func ckbRenderCertifiedCountArtifact(kind:String,records:ArrayList<CkbCertifiedKnowledgeRecord>):String{"{\"kind\":\"${kind}\",\"count\":${records.size},\"recordsChecksum\":\"${ckbCertifiedKnowledgeRecordsChecksum(records)}\"}"}
public func ckbRenderCertifiedVersionManifest(version:String,records:ArrayList<CkbCertifiedKnowledgeRecord>):String{"{\"certifiedVersion\":\"${ckbP8Escape(version)}\",\"candidateVersion\":\"${ckbP8Escape(version)}-candidate\",\"candidateChecksum\":\"${ckbCertifiedKnowledgeRecordsChecksum(records)}\"}"}
public func ckbRenderCertifiedQueryPayload(version:String,records:ArrayList<CkbCertifiedKnowledgeRecord>):String{let ids=ArrayList<String>();for(item in records){ids.add(item.canonicalIdentity)};let a=ids.toArray();sort(a);var out="";for(i in 0..a.size){if(i>0){out+=","};out+="\"${ckbP8Escape(a[i])}\""};"{\"ok\":true,\"knowledgeVersion\":\"${ckbP8Escape(version)}\",\"atomIds\":[${out}],\"contentHash\":\"${ckbCertifiedKnowledgeRecordsChecksum(records)}\",\"citation\":\"verified\"}"}
public func ckbCanonicalizeCertifiedQueryPayload(raw:String):(String,String){try{let o=JsonValue.fromStr(raw).asObject();if(!o.get("ok").getOrThrow().asBool().getValue()){return ("business_not_ok","")};let version=ckbP8String(o,"knowledgeVersion");let hash=ckbP8String(o,"contentHash");let citation=ckbP8String(o,"citation");let ids=ArrayList<String>();for(v in o.get("atomIds").getOrThrow().asArray().getItems()){ids.add(v.asString().getValue())};let a=ids.toArray();sort(a);var joined="";for(i in 0..a.size){if(i>0){joined+=","};joined+="\"${ckbP8Escape(a[i])}\""};("ok","{\"ok\":true,\"knowledgeVersion\":\"${ckbP8Escape(version)}\",\"atomIds\":[${joined}],\"contentHash\":\"${ckbP8Escape(hash)}\",\"citation\":\"${ckbP8Escape(citation)}\"}")}catch(_:Exception){("malformed_query_payload","")}}
private func ckbP8CountArtifactDiagnostic(raw:String,kind:String,count:Int64,checksum:String):String{try{let o=JsonValue.fromStr(raw).asObject();if(ckbP8String(o,"kind")!=kind||ckbP8Int(o,"count")!=count||ckbP8String(o,"recordsChecksum")!=checksum){"${kind}_artifact_mismatch"}else{"ok"}}catch(_:Exception){"${kind}_artifact_malformed"}}
private func ckbP8ManifestDiagnostic(raw:String,version:String,checksum:String):String{try{let o=JsonValue.fromStr(raw).asObject();if(ckbP8String(o,"certifiedVersion")!=version||ckbP8String(o,"candidateVersion")!="${version}-candidate"||ckbP8String(o,"candidateChecksum")!=checksum){"version_manifest_mismatch"}else{"ok"}}catch(_:Exception){"version_manifest_malformed"}}
private func ckbP8QueryPayloadDiagnostic(raw:String,version:String,records:ArrayList<CkbCertifiedKnowledgeRecord>):String{if(raw!=ckbRenderCertifiedQueryPayload(version,records)){"query_payload_mismatch"}else{"ok"}}
private func ckbP8String(o:JsonObject,k:String):String{o.get(k).getOrThrow().asString().getValue()}
private func ckbP8Int(o:JsonObject,k:String):Int64{o.get(k).getOrThrow().asInt().getValue()}
private func ckbP8Escape(v:String):String{v.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r").replace("\t","\\t")}
private func ckbP8SameRecord(a:NormalizedRecord,b:NormalizedRecord):Bool{ckbP8NormalizedRecordSeed(a)==ckbP8NormalizedRecordSeed(b)}
private func ckbP8NormalizedRecordSeed(record:NormalizedRecord):String{let m=record.metadata;let seed=StringBuilder();for(value in [record.sourceId,record.recordKind,record.title,record.chunk,record.citation,"${record.score}","${record.requiresReview}",m.sourceId,m.sourceType,m.sourceUrl,m.repo,m.path,m.symbol,m.commit,m.docVersion,m.targetVersion,m.sourceSet,m.versionResolutionId,m.crawlAt,m.indexedAt,m.knowledgeVersion,m.candidateVersion,"${m.contentSize}",m.trustLevel,m.reviewState,m.license,m.repoVisibility]){seed.append(ckbP8Part(value))};seed.append(ckbP8Part("${m.derivedFrom.size}"));for(value in m.derivedFrom){seed.append(ckbP8Part(value))};seed.toString()}
private func ckbP8Part(value:String):String{"${value.toArray().size}:${value}"}

private func ckbP8Hash(value: String): Bool {
    if (!value.startsWith("sha256:") || value.toRuneArray().size != 71) { return false }
    for (rune in value.toRuneArray()[7..71]) { if (!((rune >= r'0' && rune <= r'9') || (rune >= r'a' && rune <= r'f'))) { return false } }
    true
}

public func runCkbCertifiedProductionPublishCli(args:Array<String>,kb:KnowledgeBase,store:FileKnowledgeStore,storePath:String):Int64{
    let parsed=ckbP8CliArgs(args);if(parsed[0]!="ok"){println("usage error: ${parsed[0]}");return 2};let controlPath=parsed[1]
    try{
        let o=JsonValue.fromStr(ckbP8ReadOrThrow(controlPath)).asObject();let declaredStore=ckbP8String(o,"store");let acceptancePath=ckbP8String(o,"acceptanceReportPath")
        if(canonicalize(Path(declaredStore)).toString()!=canonicalize(Path(storePath)).toString()){println("publish blocked: explicit_store_mismatch");return 1}
        if(ckbP8PathInside(acceptancePath,storePath)){println("publish blocked: acceptance_report_must_be_outside_store");return 1}
        let proof=CkbProductionReleaseProof()
        proof.p6PreflightJson=ckbP8ReadOrThrow(ckbP8String(o,"p6PreflightPath"));proof.p6RunManifestJson=ckbP8ReadOrThrow(ckbP8String(o,"p6RunManifestPath"));proof.p7ResultsJsonl=ckbP8ReadOrThrow(ckbP8String(o,"p7ResultsPath"));proof.p7RunRoot=ckbP8String(o,"p7RunRoot");proof.p7ArtifactManifestHash=ckbP8String(o,"p7ArtifactManifestHash");proof.authorityManifestJsonl=ckbP8ReadOrThrow(ckbP8String(o,"authorityManifestPath"));proof.p7GateJson=ckbP8ReadOrThrow(ckbP8String(o,"p7GatePath"));proof.candidateArtifactJsonl=ckbP8ReadOrThrow(ckbP8String(o,"resolvedCandidatePath"));proof.indexArtifactJson=ckbP8ReadOrThrow(ckbP8String(o,"indexArtifactPath"));proof.vectorArtifactJson=ckbP8ReadOrThrow(ckbP8String(o,"vectorArtifactPath"));proof.stdioQueryPayload=ckbP8ReadOrThrow(ckbP8String(o,"stdioQueryProofPath"));proof.httpQueryPayload=ckbP8ReadOrThrow(ckbP8String(o,"httpQueryProofPath"));proof.versionManifestJson=ckbP8ReadOrThrow(ckbP8String(o,"versionManifestPath"));proof.studentLeakageArtifactJson=ckbP8ReadOrThrow(ckbP8String(o,"studentLeakageArtifactPath"));proof.anonymousQueryArtifactJson=ckbP8ReadOrThrow(ckbP8String(o,"anonymousQueryArtifactPath"));proof.authorityIsolationArtifactJson=ckbP8ReadOrThrow(ckbP8String(o,"authorityIsolationArtifactPath"));proof.atomTestArtifactJson=ckbP8ReadOrThrow(ckbP8String(o,"atomTestArtifactPath"));proof.studentLeakageProofJson=ckbP8ReadOrThrow(ckbP8String(o,"studentLeakageProofPath"))
        proof.frozenCandidateManifestJson=ckbP8ReadOrThrow(ckbP8String(o,"frozenCandidateManifestPath"));proof.frozenCandidateManifestHash=benchmarkGapSha256(proof.frozenCandidateManifestJson)
        for(raw in [proof.p6PreflightJson,proof.p6RunManifestJson,proof.p7ResultsJsonl,proof.authorityManifestJsonl,proof.p7GateJson,proof.candidateArtifactJsonl,proof.indexArtifactJson,proof.vectorArtifactJson,proof.stdioQueryPayload,proof.httpQueryPayload,proof.versionManifestJson,proof.studentLeakageArtifactJson,proof.anonymousQueryArtifactJson,proof.authorityIsolationArtifactJson,proof.atomTestArtifactJson,proof.studentLeakageProofJson,proof.frozenCandidateManifestJson]){if(ckbControlContainsSecret(raw)){println("publish blocked: secret_artifact_forbidden");return 1}}
        let frozenDiagnostic=ckbP8FrozenSourceDiagnostic(ckbP8String(o,"frozenCandidateStore"),storePath,proof.frozenCandidateManifestJson);if(frozenDiagnostic!="ok"){println("publish blocked: ${frozenDiagnostic}");return 1}
        let existing=ckbP8ParseRecords(ckbP8ReadOrThrow(ckbP8String(o,"existingActivePath")));let incoming=ckbP8ParseRecords(ckbP8ReadOrThrow(ckbP8String(o,"incomingCandidatePath")))
        let diagnostic=ckbCertifiedProductionProofDiagnostic(proof,incoming);if(diagnostic!="ok"){println("publish blocked: ${diagnostic}");return 1}
        let candidateVersion=ckbP8String(o,"candidateVersion");let expectedActive=ckbP8String(o,"expectedBaseActiveVersion");let key=CkbScheduledFetchRunKey();key.acquisitionId=ckbP8String(o,"releaseId");key.planningIdentityHash=benchmarkGapSha256(key.acquisitionId+"|planning");key.runIdentityHash=benchmarkGapSha256(key.acquisitionId+"|run")
        let report=ckbPublishCertifiedKnowledgeWithReleaseState(kb,store,key,candidateVersion,expectedActive,existing,incoming,proof);let snapshot=store.loadActiveSnapshot();let reloadAccepted=report.ok&&snapshot.valid&&snapshot.activeVersion==report.activeVersion&&snapshot.normalizedRecords.size==incoming.size
        let service=CkbCommandLoopService(CkbRuntimeConfig(),store);_=service.start();let status=service.handleLine("status").text;let query="{\"taskId\":\"P8-ACCEPTANCE\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"Validate Cangjie knowledge 中文🙂\",\"signature\":\"func acceptance(): Unit\",\"targetVersion\":\"1.0.0\",\"sourceSet\":\"all\",\"versionPolicy\":\"default\"}";let http=ckbApiHandle(service,"POST","/v1/cangjie/task-knowledge-pack",query,[]);let stdio=CkbMcpStdioServer(service).handleRequest("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"cangjie_task_knowledge_pack\",\"arguments\":${query}}}")
        let statusAccepted=status.contains(report.activeVersion);let httpAccepted=http.contains("\"ok\":true")&&http.contains(report.activeVersion);let stdioAccepted=stdio.contains("\"result\"")&&stdio.contains(report.activeVersion);let accepted=reloadAccepted&&statusAccepted&&httpAccepted&&stdioAccepted
        let finalAccepted=accepted||report.ok;let publishStatus=if(report.ok&&!accepted){"published_degraded"}else{report.status}
        let output="{\"ok\":${finalAccepted},\"publishStatus\":\"${ckbP8Escape(publishStatus)}\",\"activeVersion\":\"${ckbP8Escape(report.activeVersion)}\",\"reload\":${reloadAccepted},\"statusAcceptance\":${statusAccepted},\"stdioAcceptance\":${stdioAccepted},\"httpAcceptance\":${httpAccepted},\"queryParity\":${stdioAccepted&&httpAccepted},\"evidenceHash\":\"${ckbP8Escape(report.evidenceHash)}\"}"
        let acceptanceTmp="${acceptancePath}.tmp-${benchmarkGapSha256(output).replace("sha256:","")}";try{File.writeTo(Path(acceptanceTmp),output.toArray());rename(acceptanceTmp,to:acceptancePath,overwrite:true)}catch(_:Exception){try{remove(acceptanceTmp)}catch(_:Exception){};if(report.ok){println("{\"ok\":true,\"publishStatus\":\"published_degraded\",\"activeVersion\":\"${ckbP8Escape(report.activeVersion)}\",\"diagnostic\":\"post_commit_artifact_failed\"}");return 0};throw Exception("acceptance_report_write_failed")};println(output);if(finalAccepted){0}else{1}
    }catch(e:Exception){let diagnostic=if(e.message=="invalid_response_encoding"){"invalid_response_encoding"}else if(e.message=="artifact_read_failed"){"artifact_read_failed"}else{"malformed_json"};println("publish blocked: ${diagnostic}");1}
}

public func ckbP8CliArgs(args:Array<String>):(String,String){let seen=HashMap<String,Bool>();var command=false;var control="";var store=false;var i:Int64=0;while(i<args.size){let a=args[i];if(a=="cangjie-certified-production-publish"&&!command){command=true;i+=1;continue};if(a!="--control-manifest"&&a!="--store"&&a!="--config"){return("unknown_argument:${a}","")};if(seen.contains(a)){return("duplicate_argument:${a}","")};if(i+1>=args.size||args[i+1].startsWith("--")){return("missing_argument_value:${a}","")};seen[a]=true;if(a=="--control-manifest"){control=args[i+1]};if(a=="--store"){store=true};i+=2};if(!command){return("command_required","")};if(control==""){return("required_argument_missing:--control-manifest","")};if(!store){return("required_argument_missing:--store","")};("ok",control)}
private func ckbP8ParseRecords(raw:String):ArrayList<CkbCertifiedKnowledgeRecord>{let out=ArrayList<CkbCertifiedKnowledgeRecord>();for(line in raw.split("\n")){if(line.trimAscii()==""){continue};let o=JsonValue.fromStr(line).asObject();let item=CkbCertifiedKnowledgeRecord();item.canonicalIdentity=ckbP8String(o,"identity");item.revision=ckbP8Int(o,"revision");item.evidenceHash=ckbP8String(o,"evidenceHash");let r=NormalizedRecord();r.sourceId=ckbP8String(o,"sourceId");r.recordKind=ckbP8String(o,"kind");r.title=ckbP8String(o,"title");r.chunk=ckbP8String(o,"content");r.citation=ckbP8String(o,"citation");r.metadata.sourceId=r.sourceId;r.metadata.targetVersion=ckbP8String(o,"targetVersion");r.metadata.versionResolutionId=ckbP8String(o,"versionResolutionId");item.record=r;out.add(item)};out}
public class CkbP8ArtifactReadResult{public var ok:Bool=false;public var text:String="";public var diagnostic:String="";public init(){}}
public func ckbP8ReadArtifact(path:String):CkbP8ArtifactReadResult{let result=CkbP8ArtifactReadResult();try{let bytes=File.readFrom(Path(path));try{result.text=String.fromUtf8(bytes);result.ok=true}catch(_:Exception){result.diagnostic="invalid_response_encoding"}}catch(_:Exception){result.diagnostic="artifact_read_failed"};result}
private func ckbP8ReadOrThrow(path:String):String{let result=ckbP8ReadArtifact(path);if(!result.ok){throw Exception(result.diagnostic)};result.text}
private func ckbP8PathInside(path:String,root:String):Bool{let p=canonicalize(Path(path).parent).toString()+"/"+Path(path).fileName;let r=canonicalize(Path(root)).toString();p==r||p.startsWith(r+"/")}
