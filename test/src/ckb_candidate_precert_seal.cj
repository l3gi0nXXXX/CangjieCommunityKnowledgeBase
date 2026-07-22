package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashMap}
import std.fs.{Directory, File, Path, canonicalize, exists, remove, rename}
import std.sort.*
import stdx.encoding.json.*

public class CkbCandidatePrecertOptions {
    public var selectedAtomsPath: String = ""
    public var outputRoot: String = ""
    public init() {}
}

public class CkbCandidatePrecertResult {
    public var ok: Bool = false
    public var diagnostic: String = "candidate_precert_not_run"
    public var selectedCount: Int64 = 0
    public var atomTestCount: Int64 = 0
    public var candidateChecksum: String = ""
    public var trustSealHash: String = ""
    public var summaryHash: String = ""
    public init() {}
}

public interface CkbCandidatePrecertFaultInjector { func checkpoint(point: String): Unit }
public class NoopCkbCandidatePrecertFaultInjector <: CkbCandidatePrecertFaultInjector {
    public func checkpoint(_point: String): Unit {}
}

// Candidate pre-certification is read-only with respect to the knowledge store.
// Its six artifacts become visible together only after every trust check passes.
public func ckbBuildCandidatePrecertSeal(store: FileKnowledgeStore,
    options: CkbCandidatePrecertOptions,
    faultInjector!: CkbCandidatePrecertFaultInjector = NoopCkbCandidatePrecertFaultInjector()
): CkbCandidatePrecertResult {
    let result = CkbCandidatePrecertResult()
    if (options.selectedAtomsPath.trimAscii() == "" || options.outputRoot.trimAscii() == "") {
        result.diagnostic = "candidate_precert_options_invalid"; return result
    }
    let output = Path(options.outputRoot)
    if (exists(output)) { result.diagnostic = "candidate_precert_output_exists"; return result }
    let outputParent = try { canonicalize(output.parent).toString() }
        catch (_: Exception) { result.diagnostic = "candidate_precert_output_parent_invalid"; return result }
    let canonicalOutput = Path(outputParent).join(output.fileName).toString()
    let canonicalStore = try { canonicalize(store.root).toString() }
        catch (_: Exception) { result.diagnostic = "candidate_precert_store_invalid"; return result }
    if (canonicalOutput == canonicalStore || canonicalOutput.startsWith(canonicalStore + "/")) {
        result.diagnostic = "candidate_precert_output_inside_store"; return result
    }
    let selectedText = ckbCandidatePrecertReadUtf8(options.selectedAtomsPath)
    if (selectedText[0] != "ok") { result.diagnostic = selectedText[0]; return result }
    let parsed = parseBenchmarkGapInputsJsonl(selectedText[1])
    if (!parsed.ok) { result.diagnostic = "selected_atoms_malformed"; return result }

    let pointer = store.loadActiveSnapshotPointer()
    if (!pointer.valid) { result.diagnostic = "active_snapshot_pointer_required"; return result }
    let pointerHash = ckbActiveSnapshotPointerIdentityHash(pointer)
    let snapshot = store.loadActiveSnapshot()
    if (!snapshot.valid) { result.diagnostic = "active_snapshot_invalid"; return result }
    let authority = ckbLoadBenchmarkLeakageAuthority(store)
    if (!authority.ok || authority.authorityRecordCount <= 0 || !ckbCandidatePrecertHash(authority.authorityHash)) {
        result.diagnostic = if (authority.ok) { "authority_isolation_proof_required" } else { authority.diagnostic }
        return result
    }
    var activeEvalCount: Int64 = 0; var normalizedEvalCount: Int64 = 0
    for (record in snapshot.activeIndex) {
        if (record.recordKind == CangjieTypedRecordKinds.EVAL_SUPPORT ||
            record.metadata.sourceSet == CangjieSourceSets.EVAL_SUPPORT) { activeEvalCount += 1 }
    }
    for (record in snapshot.normalizedRecords) {
        if (record.recordKind == CangjieTypedRecordKinds.EVAL_SUPPORT ||
            record.metadata.sourceSet == CangjieSourceSets.EVAL_SUPPORT) { normalizedEvalCount += 1 }
    }
    if (activeEvalCount != 0 || normalizedEvalCount != 0) {
        result.diagnostic = "active_eval_support_forbidden"; return result
    }

    let declaredAtoms = HashMap<String, Bool>()
    for (input in parsed.inputs) {
        let declared = validateKnowledgeAtomTestBundle(input.knowledgeAtomTestBundle)
        if (!declared.ok) { result.diagnostic = declared.diagnostic; return result }
        let key = "${declared.atomId}:${input.targetVersion.toAsciiLower()}"
        if (declaredAtoms.contains(key)) { result.diagnostic = "duplicate_selected_atom"; return result }
        declaredAtoms.add(key, true)
    }
    let curated = curateBenchmarkGapRecords(parsed.inputs)
    if (parsed.inputs.size > 0 && (!curated.ok || curated.records.size != parsed.inputs.size)) {
        result.diagnostic = "selected_atoms_curation_failed"; return result
    }
    let atoms = ArrayList<NormalizedRecord>()
    let seen = HashMap<String, Bool>()
    var tests: Int64 = 0
    var passed: Int64 = 0
    var failed: Int64 = 0
    let bundleEvidence = ArrayList<String>()
    for (i in 0..parsed.inputs.size) {
        let input = parsed.inputs[i]
        if (!input.knowledgeAtomCandidate || input.knowledgeAtomTestBundle.trimAscii() == "") {
            result.diagnostic = "knowledge_atom_candidate_required"; return result
        }
        let tested = runKnowledgeAtomTestBundle(input.knowledgeAtomTestBundle)
        if (!tested.ok) { result.diagnostic = tested.diagnostic; return result }
        let key = "${tested.atomId}:${input.targetVersion.toAsciiLower()}"
        if (seen.contains(key)) { result.diagnostic = "duplicate_selected_atom"; return result }
        seen.add(key, true); tests += tested.total; passed += tested.passed; failed += tested.failed
        bundleEvidence.add("${tested.atomId}|${cangjieKnowledgeAtomCandidateHash(input.knowledgeAtomTestBundle)}|${benchmarkGapSha256(input.knowledgeAtomTestBundle.trimAscii())}")
        let matched = ckbCandidatePrecertMatch(curated.records[i], snapshot.normalizedRecords,
            snapshot.activeIndex)
        if (matched[0] != "ok") { result.diagnostic = matched[0]; return result }
        atoms.add(matched[1])
    }
    result.selectedCount = atoms.size; result.atomTestCount = tests
    let leakage = ckbBuildStudentLeakageReport(snapshot.normalizedRecords, authority: authority.authority)
    if (!leakage.ok) { result.diagnostic = "student_knowledge_leakage_blocked"; return result }
    let query = ckbBuildAnonymousAtomQueryReport(snapshot.activeIndex, atoms)
    if (!query.ok) { result.diagnostic = "anonymous_query_proof_required"; return result }
    let authorityText = "{\"ok\":true,\"authorityCount\":${authority.authorityRecordCount},\"authorityHash\":\"${authority.authorityHash}\",\"activeEvalCount\":0,\"normalizedEvalCount\":0}\n"
    let orderedEvidence = bundleEvidence.toArray(); sort(orderedEvidence); let evidenceSeed = StringBuilder()
    for (value in orderedEvidence) { evidenceSeed.append("${value.toArray().size}:${value}") }
    let atomBody = "{\"ok\":${failed == 0 && passed == tests},\"diagnostic\":\"validated\",\"bundleCount\":${atoms.size},\"testCount\":${tests},\"passed\":${passed},\"failed\":${failed},\"selectedAtomsHash\":\"${benchmarkGapSha256(selectedText[1])}\",\"bundleEvidenceHash\":\"${benchmarkGapSha256(evidenceSeed.toString())}\""
    let atomText = atomBody + ",\"evidenceHash\":\"${benchmarkGapSha256(atomBody + "}")}\"}\n"
    let gate = cangjieCandidateOnlyPreCertificationGate(snapshot.normalizedRecords,
        leakage.json, query.jsonl, authorityText, atomText)
    if (!gate.ok) { result.diagnostic = gate.diagnostic; return result }
    let sealText = ckbRenderCandidateTrustSeal(snapshot.normalizedRecords, leakage.json,
        query.jsonl, authorityText, atomText)
    let seal = sealText + "\n"
    if (ckbCandidateTrustSealDiagnostic(seal, snapshot.normalizedRecords, leakage.json,
        query.jsonl, authorityText, atomText) != "ok") {
        result.diagnostic = "student_leakage_proof_mismatch"; return result
    }
    result.candidateChecksum = ckbCertifiedNormalizedRecordsChecksum(snapshot.normalizedRecords)
    result.trustSealHash = benchmarkGapSha256(seal)
    let summaryBody = "{\"schemaVersion\":\"ckb-candidate-precert-summary-v1\",\"ok\":true,\"status\":\"pass\",\"selectedCount\":${atoms.size},\"atomTestCount\":${tests},\"candidateChecksum\":\"${result.candidateChecksum}\",\"activePointerHash\":\"${pointerHash}\",\"leakageArtifactHash\":\"${benchmarkGapSha256(leakage.json)}\",\"anonymousQueryArtifactHash\":\"${benchmarkGapSha256(query.jsonl)}\",\"authorityIsolationArtifactHash\":\"${benchmarkGapSha256(authorityText)}\",\"atomTestArtifactHash\":\"${benchmarkGapSha256(atomText)}\",\"candidateTrustSealHash\":\"${result.trustSealHash}\""
    result.summaryHash = benchmarkGapSha256(summaryBody + "}")
    let summary = summaryBody + ",\"evidenceHash\":\"${result.summaryHash}\"}"
    let artifacts = [
        ("student-leakage-report.jsonl", leakage.json),
        ("anonymous-atom-query-report.jsonl", query.jsonl),
        ("authority-isolation.json", authorityText),
        ("atom-test-summary.json", atomText),
        ("candidate-trust-seal.json", seal),
        ("candidate-precert-summary.json", summary + "\n")
    ]
    let write = ckbCandidatePrecertPublish(Path(canonicalOutput), artifacts, store, pointerHash,
        faultInjector: faultInjector)
    if (write != "ok") { result.diagnostic = write; return result }
    result.ok = true; result.diagnostic = "ok"; result
}

public func runCkbCandidatePrecertCli(args: Array<String>, store: FileKnowledgeStore): Int64 {
    let options = CkbCandidatePrecertOptions(); var commandSeen = false; var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "cangjie-candidate-precert-seal" && !commandSeen) { commandSeen = true; i += 1; continue }
        if (arg == "--store" && i + 1 < args.size) { i += 2; continue }
        if (arg != "--selected-atoms" && arg != "--output-root") {
            println("candidate pre-cert blocked: unknown_argument"); return 2
        }
        if (i + 1 >= args.size) { println("candidate pre-cert blocked: missing_argument_value"); return 2 }
        if (arg == "--selected-atoms") {
            if (options.selectedAtomsPath != "") { println("candidate pre-cert blocked: duplicate_argument"); return 2 }
            options.selectedAtomsPath = args[i + 1]
        } else {
            if (options.outputRoot != "") { println("candidate pre-cert blocked: duplicate_argument"); return 2 }
            options.outputRoot = args[i + 1]
        }
        i += 2
    }
    if (!commandSeen) { println("candidate pre-cert blocked: command_required"); return 2 }
    let result = ckbBuildCandidatePrecertSeal(store, options)
    println("candidate pre-cert ok=${result.ok} selected=${result.selectedCount} atomTests=${result.atomTestCount} candidateChecksum=${result.candidateChecksum} trustSealHash=${result.trustSealHash} diagnostic=${result.diagnostic}")
    if (result.ok) { 0 } else { 1 }
}

private func ckbCandidatePrecertMatch(expected: NormalizedRecord,
    normalized: ArrayList<NormalizedRecord>, active: ArrayList<NormalizedRecord>): (String, NormalizedRecord) {
    let none = NormalizedRecord(); var normalizedCount: Int64 = 0; var activeCount: Int64 = 0
    var normalizedMatch = none; var activeMatch = none
    for (record in normalized) { if (record.sourceId == expected.sourceId) { normalizedCount += 1; normalizedMatch = record } }
    for (record in active) { if (record.sourceId == expected.sourceId) { activeCount += 1; activeMatch = record } }
    if (normalizedCount != 1 || activeCount != 1) { return ("selected_atom_not_active", none) }
    expected.metadata.knowledgeVersion = activeMatch.metadata.knowledgeVersion
    expected.metadata.candidateVersion = activeMatch.metadata.candidateVersion
    let expectedHash = ckbCandidatePrecertRecordHash(expected)
    if (expectedHash != ckbCandidatePrecertRecordHash(normalizedMatch) ||
        expectedHash != ckbCandidatePrecertRecordHash(activeMatch)) {
        return ("selected_atom_active_content_mismatch", none)
    }
    ("ok", activeMatch)
}

private func ckbCandidatePrecertRecordHash(record: NormalizedRecord): String {
    let one = ArrayList<NormalizedRecord>(); one.add(record); ckbCertifiedNormalizedRecordsChecksum(one)
}

private func ckbCandidatePrecertPublish(output: Path, artifacts: Array<(String, String)>,
    store: FileKnowledgeStore, pointerHash: String,
    faultInjector!: CkbCandidatePrecertFaultInjector = NoopCkbCandidatePrecertFaultInjector()): String {
    let temp = Path(output.toString() + ".tmp-" + benchmarkGapSha256(pointerHash + output.toString()).replace("sha256:", ""))
    try {
        if (exists(temp)) { remove(temp, recursive: true) }
        Directory.create(temp, recursive: false)
        for (artifact in artifacts) {
            let path = temp.join(artifact[0]); File.writeTo(path, artifact[1].toArray())
            if (String.fromUtf8(File.readFrom(path)) != artifact[1]) { throw Exception("artifact_readback_mismatch") }
        }
        faultInjector.checkpoint("before_pointer_check")
        if (ckbActiveSnapshotPointerIdentityHash(store.loadActiveSnapshotPointer()) != pointerHash) {
            remove(temp, recursive: true); return "candidate_precert_active_pointer_drift"
        }
        faultInjector.checkpoint("before_publish")
        if (ckbActiveSnapshotPointerIdentityHash(store.loadActiveSnapshotPointer()) != pointerHash) {
            remove(temp, recursive: true); return "candidate_precert_active_pointer_drift"
        }
        rename(temp, to: output, overwrite: false)
        "ok"
    } catch (_: Exception) {
        try { if (exists(temp)) { remove(temp, recursive: true) } } catch (_: Exception) {}
        "candidate_precert_artifact_write_failed"
    }
}

private func ckbCandidatePrecertReadUtf8(path: String): (String, String) {
    if (!exists(Path(path))) { return ("selected_atoms_not_found", "") }
    try { ("ok", String.fromUtf8(File.readFrom(Path(path)))) }
    catch (_: Exception) { ("invalid_response_encoding", "") }
}

private func ckbCandidatePrecertHash(value: String): Bool {
    if (!value.startsWith("sha256:") || value.toRuneArray().size != 71) { return false }
    for (r in value.toRuneArray()[7..71]) {
        if (!((r >= r'0' && r <= r'9') || (r >= r'a' && r <= r'f'))) { return false }
    }
    true
}
