package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashMap}
import std.sort.*

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
    public var certification: CkbStrictCertificationGateResult = CkbStrictCertificationGateResult()
    public var certificationFingerprint: String = ""
    public var certifiedKnowledgeVersion: String = ""
    public var candidateChecksum: String = ""
    public var candidateCount: Int64 = 0
    public var indexCount: Int64 = 0
    public var vectorCount: Int64 = 0
    public var stdioQueryProofHash: String = ""
    public var httpQueryProofHash: String = ""
    public var versionManifestHash: String = ""
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
    public var evidenceHash: String = ""
    public var promotion: CangjieCandidatePromotionResult = CangjieCandidatePromotionResult()
    public init() {}
}

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

public func ckbCertifiedProductionProofDiagnostic(proof: CkbProductionReleaseProof, records: ArrayList<CkbCertifiedKnowledgeRecord>): String {
    if (!proof.certification.ok || proof.certification.diagnostics.size != 0 || proof.certification.total != 164 || proof.certification.unitPass != 164 || proof.certification.unitPassAt1 != 164 || proof.certification.failed != 0 || proof.certification.invalid != 0 || proof.certification.retryUsed != 0 || proof.certification.fallbackUsed != 0 || proof.certification.referenceExposure != 0 || proof.certification.hiddenTestExposure != 0 || proof.certification.teacherExposure != 0 || proof.certification.crossCaseExposure != 0 || (proof.certification.group != CkbAbcdeGroups.C && proof.certification.group != CkbAbcdeGroups.D) || proof.certification.datasetVersion == "") { return "p7_strict_certification_required" }
    if (!ckbP8Hash(proof.certificationFingerprint) || proof.certificationFingerprint != proof.certification.modelFingerprint) { return "certification_fingerprint_mismatch" }
    if (proof.certifiedKnowledgeVersion == "" || proof.certification.knowledgeVersion != proof.certifiedKnowledgeVersion) { return "certified_knowledge_version_mismatch" }
    let recordDiagnostic = ckbCertifiedKnowledgeRecordsDiagnostic(records)
    if (recordDiagnostic != "ok") { return recordDiagnostic }
    if (proof.candidateCount != records.size || proof.indexCount != records.size || proof.vectorCount != records.size) { return "store_index_vector_count_mismatch" }
    let checksum = ckbCertifiedKnowledgeRecordsChecksum(records)
    if (!ckbP8Hash(proof.candidateChecksum) || proof.candidateChecksum != checksum) { return "candidate_checksum_mismatch" }
    if (!ckbP8Hash(proof.versionManifestHash)) { return "version_manifest_hash_invalid" }
    let expectedQueryProof = ckbCertifiedProductionQueryProofHash(proof.certifiedKnowledgeVersion, proof.candidateChecksum, proof.versionManifestHash)
    if (proof.stdioQueryProofHash != expectedQueryProof || proof.httpQueryProofHash != expectedQueryProof) { return "transport_query_proof_mismatch" }
    "ok"
}

public func ckbCertifiedKnowledgeRecordsChecksum(records: ArrayList<CkbCertifiedKnowledgeRecord>): String {
    let identities = ArrayList<String>()
    for (item in records) { identities.add("${item.canonicalIdentity}|${item.revision}|${item.evidenceHash}") }
    // stableSummaryHash is order-sensitive; normalize without relying on map order.
    let sorted = identities.toArray()
    sort(sorted)
    let seed = StringBuilder()
    for (identity in sorted) { seed.append("${identity.toArray().size}:${identity}") }
    benchmarkGapSha256(seed.toString())
}

public class CkbCertifiedProductionPreCommitGate <: CangjieCandidatePreCommitGate {
    private let expectedCandidateVersion: String
    private let expectedBaseActiveVersion: String
    private let proof: CkbProductionReleaseProof
    private let records: ArrayList<CkbCertifiedKnowledgeRecord>
    public init(expectedCandidateVersion: String, expectedBaseActiveVersion: String, proof: CkbProductionReleaseProof, records: ArrayList<CkbCertifiedKnowledgeRecord>) {
        this.expectedCandidateVersion = expectedCandidateVersion
        this.expectedBaseActiveVersion = expectedBaseActiveVersion
        this.proof = proof
        this.records = records
    }
    public func evaluate(candidateVersion: String, activeVersion: String): CangjieCandidatePreCommitGateResult {
        let result = CangjieCandidatePreCommitGateResult()
        var diagnostic = ckbCertifiedProductionProofDiagnostic(this.proof, this.records)
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

public func ckbPublishCertifiedKnowledge(kb: KnowledgeBase, store: FileKnowledgeStore, candidateVersion: String, expectedBaseActiveVersion: String, existing: ArrayList<CkbCertifiedKnowledgeRecord>, incoming: ArrayList<CkbCertifiedKnowledgeRecord>, proof: CkbProductionReleaseProof, forceFailure!: Bool = false): CkbProductionReleaseReport {
    let report = CkbProductionReleaseReport()
    report.certifiedKnowledgeVersion = proof.certifiedKnowledgeVersion
    report.activeVersion = kb.status().activeKnowledgeVersion
    let incomingDiagnostic = ckbCertifiedKnowledgeRecordsDiagnostic(incoming)
    if (incomingDiagnostic != "ok") { report.diagnostic = incomingDiagnostic; report.status = incomingDiagnostic; return report }
    let resolved = ckbResolveCertifiedKnowledgeRecords(existing, incoming)
    report.candidateCount = resolved.size
    for (newItem in incoming) {
        var found = false
        for (oldItem in existing) {
            if (oldItem.canonicalIdentity == newItem.canonicalIdentity) { found = true; if (oldItem.evidenceHash == newItem.evidenceHash) { report.unchangedCount += 1 } else if (newItem.revision > oldItem.revision) { report.replacedCount += 1 }; break }
        }
        if (!found) { () }
    }
    let releaseGate = cangjieCertifiedProductionReleaseGate(proof, resolved)
    let diagnostic = releaseGate.diagnostic
    if (diagnostic != "ok") { report.diagnostic = diagnostic; report.status = diagnostic; return report }
    if (candidateVersion != "${proof.certifiedKnowledgeVersion}-candidate") { report.diagnostic = "candidate_certified_version_mismatch"; report.status = report.diagnostic; return report }
    let normalized = ArrayList<NormalizedRecord>(); for (item in resolved) { normalized.add(item.record) }
    let gate = CkbCertifiedProductionPreCommitGate(candidateVersion, expectedBaseActiveVersion, proof, resolved)
    report.promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb, store, candidateVersion, normalized, forceFailure: forceFailure, preCommitGate: gate, expectedBaseActiveVersion: expectedBaseActiveVersion)
    report.ok = report.promotion.ok && report.promotion.activePromoted && report.promotion.snapshotPointerCommitted && report.promotion.activeVersion == cangjieActiveVersionForCandidate(candidateVersion)
    report.status = if (report.ok) { "certified_production_published" } else { report.promotion.validation.status }
    report.diagnostic = if (report.ok) { "ok" } else { report.status }
    report.activeVersion = report.promotion.activeVersion
    report.evidenceHash = if (report.ok) { benchmarkGapSha256(ckbP8ProofEvidence(proof) + "|" + report.activeVersion + "|" + proof.candidateChecksum) } else { "" }
    report
}

func ckbPublishCertifiedKnowledgeWithReleaseState(kb: KnowledgeBase, store: FileKnowledgeStore, releaseKey: CkbScheduledFetchRunKey, candidateVersion: String, expectedBaseActiveVersion: String, existing: ArrayList<CkbCertifiedKnowledgeRecord>, incoming: ArrayList<CkbCertifiedKnowledgeRecord>, proof: CkbProductionReleaseProof, forceFailure!: Bool = false): CkbProductionReleaseReport {
    let resolved = ckbResolveCertifiedKnowledgeRecords(existing, incoming)
    let gate = cangjieCertifiedProductionReleaseGate(proof, resolved)
    if (!gate.ok) { return ckbPublishCertifiedKnowledge(kb, store, candidateVersion, expectedBaseActiveVersion, existing, incoming, proof, forceFailure: forceFailure) }
    ckbMarkReleaseAcquisitionState(store, releaseKey, "certified_staging", candidateVersion: candidateVersion, activeVersion: expectedBaseActiveVersion, certifiedVersion: proof.certifiedKnowledgeVersion, certificationFingerprint: proof.certificationFingerprint)
    let report = ckbPublishCertifiedKnowledge(kb, store, candidateVersion, expectedBaseActiveVersion, existing, incoming, proof, forceFailure: forceFailure)
    if (report.ok) {
        ckbMarkReleaseAcquisitionState(store, releaseKey, "certified_active", candidateVersion: candidateVersion, activeVersion: report.activeVersion, certifiedVersion: proof.certifiedKnowledgeVersion, certificationFingerprint: proof.certificationFingerprint)
        let loaded = ckbLoadReleaseAcquisitionState(store, releaseKey)
        if (!loaded.valid || loaded.state != "certified_active" || loaded.certifiedVersion != proof.certifiedKnowledgeVersion || loaded.certificationFingerprint != proof.certificationFingerprint || loaded.activeVersion != report.activeVersion) {
            report.ok = false; report.status = "certified_release_state_reload_failed"; report.diagnostic = report.status; report.evidenceHash = ""
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
    let record = item.record
    benchmarkGapSha256("${item.canonicalIdentity.toArray().size}:${item.canonicalIdentity}|${item.revision}|${record.sourceId.toArray().size}:${record.sourceId}|${record.recordKind.toArray().size}:${record.recordKind}|${record.title.toArray().size}:${record.title}|${record.chunk.toArray().size}:${record.chunk}|${record.citation.toArray().size}:${record.citation}|${record.metadata.targetVersion}|${record.metadata.versionResolutionId}")
}

public func ckbCertifiedProductionQueryProofHash(version: String, candidateChecksum: String, versionManifestHash: String): String {
    benchmarkGapSha256("${version}|${candidateChecksum}|${versionManifestHash}|stdio-http-query-parity")
}

private func ckbP8ProofEvidence(proof: CkbProductionReleaseProof): String {
    benchmarkGapSha256("${proof.certificationFingerprint}|${proof.certifiedKnowledgeVersion}|${proof.candidateChecksum}|${proof.candidateCount}|${proof.indexCount}|${proof.vectorCount}|${proof.stdioQueryProofHash}|${proof.httpQueryProofHash}|${proof.versionManifestHash}")
}

private func ckbP8Hash(value: String): Bool {
    if (!value.startsWith("sha256:") || value.toRuneArray().size != 71) { return false }
    for (rune in value.toRuneArray()[7..71]) { if (!((rune >= r'0' && rune <= r'9') || (rune >= r'a' && rune <= r'f'))) { return false } }
    true
}
