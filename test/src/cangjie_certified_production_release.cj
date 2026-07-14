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
    public var p7ResultsJsonl: String = ""
    public var authorityManifestJsonl: String = ""
    public var p7GateJson: String = ""
    public var candidateArtifactJsonl: String = ""
    public var indexArtifactJson: String = ""
    public var vectorArtifactJson: String = ""
    public var stdioQueryPayload: String = ""
    public var httpQueryPayload: String = ""
    public var versionManifestJson: String = ""
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

public func ckbCertifiedReplacementDiagnostic(existing:ArrayList<CkbCertifiedKnowledgeRecord>,incoming:ArrayList<CkbCertifiedKnowledgeRecord>):String{for(newItem in incoming){for(oldItem in existing){if(newItem.canonicalIdentity==oldItem.canonicalIdentity&&newItem.evidenceHash!=oldItem.evidenceHash&&newItem.revision<=oldItem.revision){return "certified_revision_conflict"}}};"ok"}
private func ckbP8ExistingActiveDiagnostic(kb:KnowledgeBase,existing:ArrayList<CkbCertifiedKnowledgeRecord>):String{let active=kb.activeRecordSnapshot();if(active.size!=existing.size){return "existing_active_count_mismatch"};for(item in existing){var found=false;for(row in active){if(ckbP8SameRecord(row,item.record)){found=true;break}};if(!found){return "existing_active_content_mismatch"}};"ok"}

public func ckbCertifiedProductionProofDiagnostic(proof: CkbProductionReleaseProof, records: ArrayList<CkbCertifiedKnowledgeRecord>): String {
    let certification = ckbStrictCertificationGate(proof.p7ResultsJsonl, proof.authorityManifestJsonl)
    if (!certification.ok || proof.p7GateJson != renderCkbStrictCertificationGateJson(certification)) { return "p7_gate_artifact_mismatch" }
    let recordDiagnostic = ckbCertifiedKnowledgeRecordsDiagnostic(records)
    if (recordDiagnostic != "ok") { return recordDiagnostic }
    let checksum = ckbCertifiedKnowledgeRecordsChecksum(records)
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
    let identities = ArrayList<String>()
    for (item in records) { identities.add("${item.canonicalIdentity}|${item.revision}|${item.evidenceHash}|${item.record.sourceId}|${item.record.recordKind}|${item.record.title}|${item.record.chunk}|${item.record.citation}|${item.record.metadata.targetVersion}|${item.record.metadata.versionResolutionId}") }
    // stableSummaryHash is order-sensitive; normalize without relying on map order.
    let sorted = identities.toArray()
    sort(sorted)
    let seed = StringBuilder()
    for (identity in sorted) { seed.append("${identity.toArray().size}:${identity}") }
    benchmarkGapSha256(seed.toString())
}

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
        var diagnostic = ckbCertifiedProductionProofDiagnostic(this.proof, this.records)
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

public func ckbPublishCertifiedKnowledge(kb: KnowledgeBase, store: FileKnowledgeStore, candidateVersion: String, expectedBaseActiveVersion: String, existing: ArrayList<CkbCertifiedKnowledgeRecord>, incoming: ArrayList<CkbCertifiedKnowledgeRecord>, proof: CkbProductionReleaseProof, forceFailure!: Bool = false): CkbProductionReleaseReport {
    let report = CkbProductionReleaseReport()
    let certification = ckbStrictCertificationGate(proof.p7ResultsJsonl, proof.authorityManifestJsonl)
    report.certifiedKnowledgeVersion = certification.knowledgeVersion
    report.activeVersion = kb.status().activeKnowledgeVersion
    let activeDiagnostic=ckbP8ExistingActiveDiagnostic(kb,existing);if(activeDiagnostic!="ok"){report.diagnostic=activeDiagnostic;report.status=activeDiagnostic;return report}
    let incomingDiagnostic = ckbCertifiedKnowledgeRecordsDiagnostic(incoming)
    if (incomingDiagnostic != "ok") { report.diagnostic = incomingDiagnostic; report.status = incomingDiagnostic; return report }
    let replacementDiagnostic=ckbCertifiedReplacementDiagnostic(existing,incoming);if(replacementDiagnostic!="ok"){report.diagnostic=replacementDiagnostic;report.status=replacementDiagnostic;return report}
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
    if (candidateVersion != "${certification.knowledgeVersion}-candidate") { report.diagnostic = "candidate_certified_version_mismatch"; report.status = report.diagnostic; return report }
    let normalized = ArrayList<NormalizedRecord>(); for (item in resolved) { normalized.add(item.record) }
    let gate = CkbCertifiedProductionPreCommitGate(kb,candidateVersion, expectedBaseActiveVersion, proof, resolved)
    report.promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb, store, candidateVersion, normalized, forceFailure: forceFailure, preCommitGate: gate, expectedBaseActiveVersion: expectedBaseActiveVersion)
    report.ok = report.promotion.ok && report.promotion.activePromoted && report.promotion.snapshotPointerCommitted && report.promotion.activeVersion == cangjieActiveVersionForCandidate(candidateVersion)
    report.status = if (report.ok) { "certified_production_published" } else { report.promotion.validation.status }
    report.diagnostic = if (report.ok) { "ok" } else { report.status }
    report.activeVersion = report.promotion.activeVersion
    report.evidenceHash = if (report.ok) { benchmarkGapSha256(ckbP8ProofEvidence(proof) + "|" + report.activeVersion + "|" + ckbCertifiedKnowledgeRecordsChecksum(resolved)) } else { "" }
    report
}

func ckbPublishCertifiedKnowledgeWithReleaseState(kb: KnowledgeBase, store: FileKnowledgeStore, releaseKey: CkbScheduledFetchRunKey, candidateVersion: String, expectedBaseActiveVersion: String, existing: ArrayList<CkbCertifiedKnowledgeRecord>, incoming: ArrayList<CkbCertifiedKnowledgeRecord>, proof: CkbProductionReleaseProof, forceFailure!: Bool = false): CkbProductionReleaseReport {
    let resolved = ckbResolveCertifiedKnowledgeRecords(existing, incoming)
    let gate = cangjieCertifiedProductionReleaseGate(proof, resolved)
    let certification = ckbStrictCertificationGate(proof.p7ResultsJsonl, proof.authorityManifestJsonl)
    let activeDiagnostic=ckbP8ExistingActiveDiagnostic(kb,existing);let incomingDiagnostic=ckbCertifiedKnowledgeRecordsDiagnostic(incoming);let replacementDiagnostic=ckbCertifiedReplacementDiagnostic(existing,incoming);let versionOk=candidateVersion=="${certification.knowledgeVersion}-candidate";let baseOk=expectedBaseActiveVersion==kb.status().activeKnowledgeVersion
    if(!gate.ok||activeDiagnostic!="ok"||incomingDiagnostic!="ok"||replacementDiagnostic!="ok"||!versionOk||!baseOk){return ckbPublishCertifiedKnowledge(kb,store,candidateVersion,expectedBaseActiveVersion,existing,incoming,proof,forceFailure:forceFailure)}
    ckbMarkReleaseAcquisitionState(store, releaseKey, "certified_staging", candidateVersion: candidateVersion, activeVersion: expectedBaseActiveVersion, certifiedVersion: certification.knowledgeVersion, certificationFingerprint: certification.modelFingerprint)
    let report = ckbPublishCertifiedKnowledge(kb, store, candidateVersion, expectedBaseActiveVersion, existing, incoming, proof, forceFailure: forceFailure)
    if (report.ok) {
        ckbMarkReleaseAcquisitionState(store, releaseKey, "certified_active", candidateVersion: candidateVersion, activeVersion: report.activeVersion, certifiedVersion: certification.knowledgeVersion, certificationFingerprint: certification.modelFingerprint)
        let loaded = ckbLoadReleaseAcquisitionState(store, releaseKey)
        if (!loaded.valid || loaded.state != "certified_active" || loaded.certifiedVersion != certification.knowledgeVersion || loaded.certificationFingerprint != certification.modelFingerprint || loaded.activeVersion != report.activeVersion) {
            report.status = "active_committed_state_degraded"; report.diagnostic = report.status
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
    benchmarkGapSha256(proof.p7GateJson + proof.candidateArtifactJsonl + proof.indexArtifactJson + proof.vectorArtifactJson + proof.stdioQueryPayload + proof.httpQueryPayload + proof.versionManifestJson)
}
private func ckbP8LiveStagingDiagnostic(kb:KnowledgeBase,records:ArrayList<CkbCertifiedKnowledgeRecord>):String{let actual=kb.candidateRecordSnapshot();if(actual.size!=records.size){return "candidate_staging_count_mismatch"};for(item in records){var found=false;for(row in actual){if(row.sourceId==item.record.sourceId&&row.recordKind==item.record.recordKind&&row.title==item.record.title&&row.chunk==item.record.chunk&&row.citation==item.record.citation){found=true;break}};if(!found){return "candidate_staging_content_mismatch"}};"ok"}

public func ckbRenderCertifiedCandidateArtifact(records: ArrayList<CkbCertifiedKnowledgeRecord>): String { let rows=ArrayList<String>();for(item in records){rows.add("{\"identity\":\"${ckbP8Escape(item.canonicalIdentity)}\",\"revision\":${item.revision},\"evidenceHash\":\"${item.evidenceHash}\",\"sourceId\":\"${ckbP8Escape(item.record.sourceId)}\",\"kind\":\"${ckbP8Escape(item.record.recordKind)}\",\"title\":\"${ckbP8Escape(item.record.title)}\",\"content\":\"${ckbP8Escape(item.record.chunk)}\",\"citation\":\"${ckbP8Escape(item.record.citation)}\",\"targetVersion\":\"${ckbP8Escape(item.record.metadata.targetVersion)}\",\"versionResolutionId\":\"${ckbP8Escape(item.record.metadata.versionResolutionId)}\"}")};let sorted=rows.toArray();sort(sorted);var out="";for(row in sorted){out+=row+"\n"};out }
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
private func ckbP8SameRecord(a:NormalizedRecord,b:NormalizedRecord):Bool{a.sourceId==b.sourceId&&a.recordKind==b.recordKind&&a.title==b.title&&a.chunk==b.chunk&&a.citation==b.citation&&a.metadata.targetVersion==b.metadata.targetVersion&&a.metadata.versionResolutionId==b.metadata.versionResolutionId}

private func ckbP8Hash(value: String): Bool {
    if (!value.startsWith("sha256:") || value.toRuneArray().size != 71) { return false }
    for (rune in value.toRuneArray()[7..71]) { if (!((rune >= r'0' && rune <= r'9') || (rune >= r'a' && rune <= r'f'))) { return false } }
    true
}

public func runCkbCertifiedProductionPublishCli(args:Array<String>,kb:KnowledgeBase,store:FileKnowledgeStore,storePath:String):Int64{
    let parsed=ckbP8CliArgs(args);if(parsed[0]!="ok"){println("usage error: ${parsed[0]}");return 2};let controlPath=parsed[1]
    try{
        let o=JsonValue.fromStr(ckbP8Read(controlPath)).asObject();let declaredStore=ckbP8String(o,"store");let acceptancePath=ckbP8String(o,"acceptanceReportPath")
        if(canonicalize(Path(declaredStore)).toString()!=canonicalize(Path(storePath)).toString()){println("publish blocked: explicit_store_mismatch");return 1}
        if(ckbP8PathInside(acceptancePath,storePath)){println("publish blocked: acceptance_report_must_be_outside_store");return 1}
        let proof=CkbProductionReleaseProof();proof.p7ResultsJsonl=ckbP8Read(ckbP8String(o,"p7ResultsPath"));proof.authorityManifestJsonl=ckbP8Read(ckbP8String(o,"authorityManifestPath"));proof.p7GateJson=ckbP8Read(ckbP8String(o,"p7GatePath"));proof.candidateArtifactJsonl=ckbP8Read(ckbP8String(o,"resolvedCandidatePath"));proof.indexArtifactJson=ckbP8Read(ckbP8String(o,"indexArtifactPath"));proof.vectorArtifactJson=ckbP8Read(ckbP8String(o,"vectorArtifactPath"));proof.stdioQueryPayload=ckbP8Read(ckbP8String(o,"stdioQueryProofPath"));proof.httpQueryPayload=ckbP8Read(ckbP8String(o,"httpQueryProofPath"));proof.versionManifestJson=ckbP8Read(ckbP8String(o,"versionManifestPath"))
        for(raw in [proof.p7ResultsJsonl,proof.authorityManifestJsonl,proof.p7GateJson,proof.candidateArtifactJsonl,proof.indexArtifactJson,proof.vectorArtifactJson,proof.stdioQueryPayload,proof.httpQueryPayload,proof.versionManifestJson]){if(ckbControlContainsSecret(raw)){println("publish blocked: secret_artifact_forbidden");return 1}}
        let existing=ckbP8ParseRecords(ckbP8Read(ckbP8String(o,"existingActivePath")));let incoming=ckbP8ParseRecords(ckbP8Read(ckbP8String(o,"incomingCandidatePath")));let resolved=ckbResolveCertifiedKnowledgeRecords(existing,incoming)
        let diagnostic=ckbCertifiedProductionProofDiagnostic(proof,resolved);if(diagnostic!="ok"){println("publish blocked: ${diagnostic}");return 1}
        let candidateVersion=ckbP8String(o,"candidateVersion");let expectedActive=ckbP8String(o,"expectedBaseActiveVersion");let key=CkbScheduledFetchRunKey();key.acquisitionId=ckbP8String(o,"releaseId");key.planningIdentityHash=benchmarkGapSha256(key.acquisitionId+"|planning");key.runIdentityHash=benchmarkGapSha256(key.acquisitionId+"|run")
        let report=ckbPublishCertifiedKnowledgeWithReleaseState(kb,store,key,candidateVersion,expectedActive,existing,incoming,proof);let snapshot=store.loadActiveSnapshot();let reloadAccepted=report.ok&&snapshot.valid&&snapshot.activeVersion==report.activeVersion&&snapshot.normalizedRecords.size==resolved.size
        let service=CkbCommandLoopService(CkbRuntimeConfig(),store);_=service.start();let status=service.handleLine("status").text;let query="{\"taskId\":\"P8-ACCEPTANCE\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"Validate Cangjie knowledge 中文🙂\",\"signature\":\"func acceptance(): Unit\",\"targetVersion\":\"1.0.0\",\"sourceSet\":\"all\",\"versionPolicy\":\"default\"}";let http=ckbApiHandle(service,"POST","/v1/cangjie/task-knowledge-pack",query,[]);let stdio=CkbMcpStdioServer(service).handleRequest("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"cangjie_task_knowledge_pack\",\"arguments\":${query}}}")
        let statusAccepted=status.contains(report.activeVersion);let httpAccepted=http.contains("\"ok\":true")&&http.contains(report.activeVersion);let stdioAccepted=stdio.contains("\"result\"")&&stdio.contains(report.activeVersion);let accepted=reloadAccepted&&statusAccepted&&httpAccepted&&stdioAccepted
        let output="{\"ok\":${accepted},\"publishStatus\":\"${ckbP8Escape(report.status)}\",\"activeVersion\":\"${ckbP8Escape(report.activeVersion)}\",\"reload\":${reloadAccepted},\"statusAcceptance\":${statusAccepted},\"stdioAcceptance\":${stdioAccepted},\"httpAcceptance\":${httpAccepted},\"queryParity\":${stdioAccepted&&httpAccepted},\"evidenceHash\":\"${ckbP8Escape(report.evidenceHash)}\"}"
        let acceptanceTmp="${acceptancePath}.tmp-${benchmarkGapSha256(output).replace("sha256:","")}";try{File.writeTo(Path(acceptanceTmp),output.toArray());rename(acceptanceTmp,to:acceptancePath,overwrite:true)}catch(e:Exception){try{remove(acceptanceTmp)}catch(_:Exception){};throw e};println(output);if(accepted){0}else{1}
    }catch(_:Exception){println("publish blocked: malformed_or_unreadable_artifact");1}
}

public func ckbP8CliArgs(args:Array<String>):(String,String){let seen=HashMap<String,Bool>();var command=false;var control="";var store=false;var i:Int64=0;while(i<args.size){let a=args[i];if(a=="cangjie-certified-production-publish"&&!command){command=true;i+=1;continue};if(a!="--control-manifest"&&a!="--store"&&a!="--config"){return("unknown_argument:${a}","")};if(seen.contains(a)){return("duplicate_argument:${a}","")};if(i+1>=args.size||args[i+1].startsWith("--")){return("missing_argument_value:${a}","")};seen[a]=true;if(a=="--control-manifest"){control=args[i+1]};if(a=="--store"){store=true};i+=2};if(!command){return("command_required","")};if(control==""){return("required_argument_missing:--control-manifest","")};if(!store){return("required_argument_missing:--store","")};("ok",control)}
private func ckbP8ParseRecords(raw:String):ArrayList<CkbCertifiedKnowledgeRecord>{let out=ArrayList<CkbCertifiedKnowledgeRecord>();for(line in raw.split("\n")){if(line.trimAscii()==""){continue};let o=JsonValue.fromStr(line).asObject();let item=CkbCertifiedKnowledgeRecord();item.canonicalIdentity=ckbP8String(o,"identity");item.revision=ckbP8Int(o,"revision");item.evidenceHash=ckbP8String(o,"evidenceHash");let r=NormalizedRecord();r.sourceId=ckbP8String(o,"sourceId");r.recordKind=ckbP8String(o,"kind");r.title=ckbP8String(o,"title");r.chunk=ckbP8String(o,"content");r.citation=ckbP8String(o,"citation");r.metadata.sourceId=r.sourceId;r.metadata.targetVersion=ckbP8String(o,"targetVersion");r.metadata.versionResolutionId=ckbP8String(o,"versionResolutionId");item.record=r;out.add(item)};out}
private func ckbP8Read(path:String):String{String.fromUtf8(File.readFrom(Path(path)))}
private func ckbP8PathInside(path:String,root:String):Bool{let p=canonicalize(Path(path).parent).toString()+"/"+Path(path).fileName;let r=canonicalize(Path(root)).toString();p==r||p.startsWith(r+"/")}
