package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashMap}
import std.fs.{Directory, File, Path, canonicalize, exists, remove, rename}
import std.sort.*
import stdx.encoding.json.*

public class CkbCandidatePrecertOptions {
    public var selectedAtomsPath: String = ""
    public var outputRoot: String = ""
    public var candidateVersion: String = ""
    public var authorityStore: String = ""
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
// Its ten artifacts become visible together only after every trust check passes.
public func ckbBuildCandidatePrecertSeal(store: FileKnowledgeStore,
    options: CkbCandidatePrecertOptions,
    faultInjector!: CkbCandidatePrecertFaultInjector = NoopCkbCandidatePrecertFaultInjector()
): CkbCandidatePrecertResult {
    let result = CkbCandidatePrecertResult()
    if (options.selectedAtomsPath.trimAscii() == "" ||
        options.outputRoot.trimAscii() == "" ||
        options.candidateVersion.trimAscii() == "" ||
        options.authorityStore.trimAscii() == "") {
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

    let candidate = store.loadCandidateSnapshotImmutable(options.candidateVersion)
    if (!candidate.valid) { result.diagnostic = candidate.diagnostic; return result }
    let authorityStore = FileKnowledgeStore(options.authorityStore)
    let canonicalAuthority = try { canonicalize(authorityStore.root).toString() }
        catch (_: Exception) {
            result.diagnostic = "authority_store_invalid"; return result
        }
    if (canonicalAuthority == canonicalStore ||
        canonicalAuthority.startsWith(canonicalStore + "/") ||
        canonicalStore.startsWith(canonicalAuthority + "/")) {
        result.diagnostic = "authority_store_must_be_separate"; return result
    }
    let authority = ckbLoadBenchmarkLeakageAuthority(authorityStore)
    if (!authority.ok || authority.authorityRecordCount <= 0 || !ckbCandidatePrecertHash(authority.authorityHash)) {
        result.diagnostic = if (authority.ok) { "authority_isolation_proof_required" } else { authority.diagnostic }
        return result
    }
    if (candidate.authorityHash != authority.authorityHash) {
        result.diagnostic = "candidate_authority_hash_mismatch"; return result
    }
    var activeEvalCount: Int64 = 0; var normalizedEvalCount: Int64 = 0
    for (record in candidate.activeIndex) {
        if (record.recordKind == CangjieTypedRecordKinds.EVAL_SUPPORT ||
            record.metadata.sourceSet == CangjieSourceSets.EVAL_SUPPORT) { activeEvalCount += 1 }
    }
    for (record in candidate.normalizedRecords) {
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
        let matched = ckbCandidatePrecertMatch(curated.records[i],
            candidate.normalizedRecords, candidate.activeIndex)
        if (matched[0] != "ok") { result.diagnostic = matched[0]; return result }
        atoms.add(matched[1])
    }
    result.selectedCount = atoms.size; result.atomTestCount = tests
    let feed = buildServingDocuments(candidate.normalizedRecords)
    let index = buildCangjieStudentServingIndex(candidate.activeIndex,
        activeKnowledgeVersion: candidate.version)
    if (!feed.ok || feed.diagnostics.size > 0) {
        result.diagnostic = "student_serving_feed_rejected"; return result
    }
    if (index.documents.size == 0 || index.records.size == 0 ||
        index.diagnostics.size > 0) {
        result.diagnostic = "student_serving_index_rejected"; return result
    }
    let taskPacks = ckbCandidatePrecertTaskPacks(candidate, atoms)
    let scan = CkbStudentLeakageScanInput()
    scan.rawRecords = candidate.rawRecords
    scan.normalizedRecords = candidate.normalizedRecords
    scan.servingDocuments = feed.documents
    scan.indexRecords = index.records
    scan.indexDocuments = index.documents
    scan.exactEntries = index.exactEntries
    scan.taskPacks = taskPacks
    scan.authorityHash = authority.authorityHash
    scan.candidateChecksum = candidate.candidateChecksum
    let leakage = ckbBuildStudentLeakageReportFromLayers(scan,
        authority: authority.authority)
    if (!leakage.ok) { result.diagnostic = "student_knowledge_leakage_blocked"; return result }
    let query = ckbBuildAnonymousAtomQueryReport(candidate.activeIndex, atoms)
    if (!query.ok) { result.diagnostic = "anonymous_query_proof_required"; return result }
    let serving = ckbCandidatePrecertTransportReport(candidate, atoms,
        canonicalOutput, benchmarkGapSha256(query.jsonl), authority.authority)
    if (!serving.ok) {
        result.diagnostic = serving.diagnostic; return result
    }
    let authorityText = "{\"ok\":true,\"authorityCount\":${authority.authorityRecordCount},\"authorityHash\":\"${authority.authorityHash}\",\"activeEvalCount\":0,\"normalizedEvalCount\":0,\"immutableManifestHash\":\"${candidate.immutableManifestHash}\",\"cleanManifestHash\":\"${candidate.cleanManifestHash}\",\"materializationManifestEvidenceHash\":\"${candidate.manifestEvidenceHash}\"}\n"
    let orderedEvidence = bundleEvidence.toArray(); sort(orderedEvidence); let evidenceSeed = StringBuilder()
    for (value in orderedEvidence) { evidenceSeed.append("${value.toArray().size}:${value}") }
    let atomBody = "{\"ok\":${failed == 0 && passed == tests},\"diagnostic\":\"validated\",\"bundleCount\":${atoms.size},\"testCount\":${tests},\"passed\":${passed},\"failed\":${failed},\"selectedAtomsHash\":\"${benchmarkGapSha256(selectedText[1])}\",\"bundleEvidenceHash\":\"${benchmarkGapSha256(evidenceSeed.toString())}\""
    let atomText = atomBody + ",\"evidenceHash\":\"${benchmarkGapSha256(atomBody + "}")}\"}\n"
    let gate = cangjieCandidateOnlyPreCertificationGate(candidate.normalizedRecords,
        leakage.json, serving.summaryJson, authorityText, atomText,
        restText: serving.restJson, mcpStdioText: serving.mcpStdioJson,
        mcpHttpText: serving.mcpHttpJson, anonymousQueryText: query.jsonl)
    if (!gate.ok) { result.diagnostic = gate.diagnostic; return result }
    let sealText = ckbRenderCandidateTrustSeal(candidate.normalizedRecords, leakage.json,
        serving.summaryJson, authorityText, atomText,
        restText: serving.restJson, mcpStdioText: serving.mcpStdioJson,
        mcpHttpText: serving.mcpHttpJson, anonymousQueryText: query.jsonl)
    let seal = sealText + "\n"
    if (ckbCandidateTrustSealDiagnostic(seal, candidate.normalizedRecords,
        leakage.json, serving.summaryJson, authorityText, atomText,
        restText: serving.restJson, mcpStdioText: serving.mcpStdioJson,
        mcpHttpText: serving.mcpHttpJson,
        anonymousQueryText: query.jsonl) != "ok") {
        result.diagnostic = "student_leakage_proof_mismatch"; return result
    }
    result.candidateChecksum = candidate.candidateChecksum
    result.trustSealHash = benchmarkGapSha256(seal)
    let summaryBody = "{\"schemaVersion\":\"ckb-candidate-precert-summary-v2\",\"ok\":true,\"status\":\"pass\",\"selectedCount\":${atoms.size},\"atomTestCount\":${tests},\"candidateChecksum\":\"${result.candidateChecksum}\",\"candidateVersion\":\"${ckbCandidatePrecertEscape(candidate.version)}\",\"immutableManifestHash\":\"${candidate.immutableManifestHash}\",\"cleanManifestHash\":\"${candidate.cleanManifestHash}\",\"leakageArtifactHash\":\"${benchmarkGapSha256(leakage.json)}\",\"anonymousQueryArtifactHash\":\"${benchmarkGapSha256(query.jsonl)}\",\"servingLeakageArtifactHash\":\"${benchmarkGapSha256(serving.summaryJson)}\",\"restArtifactHash\":\"${benchmarkGapSha256(serving.restJson)}\",\"mcpStdioArtifactHash\":\"${benchmarkGapSha256(serving.mcpStdioJson)}\",\"mcpHttpArtifactHash\":\"${benchmarkGapSha256(serving.mcpHttpJson)}\",\"authorityIsolationArtifactHash\":\"${benchmarkGapSha256(authorityText)}\",\"atomTestArtifactHash\":\"${benchmarkGapSha256(atomText)}\",\"candidateTrustSealHash\":\"${result.trustSealHash}\""
    result.summaryHash = benchmarkGapSha256(summaryBody + "}")
    let summary = summaryBody + ",\"evidenceHash\":\"${result.summaryHash}\"}"
    let artifacts = [
        ("student-leakage-report.jsonl", leakage.json),
        ("anonymous-atom-query-report.jsonl", query.jsonl),
        ("student-serving-leakage-report.json", serving.summaryJson),
        ("student-serving-rest-report.json", serving.restJson),
        ("student-serving-mcp-stdio-report.json", serving.mcpStdioJson),
        ("student-serving-mcp-http-report.json", serving.mcpHttpJson),
        ("authority-isolation.json", authorityText),
        ("atom-test-summary.json", atomText),
        ("candidate-trust-seal.json", seal),
        ("candidate-precert-summary.json", summary + "\n")
    ]
    let write = ckbCandidatePrecertPublish(Path(canonicalOutput), artifacts, store,
        candidate.version, candidate.immutableManifestHash,
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
        if (arg != "--selected-atoms" && arg != "--output-root" &&
            arg != "--candidate-version" && arg != "--authority-store") {
            println("candidate pre-cert blocked: unknown_argument"); return 2
        }
        if (i + 1 >= args.size) { println("candidate pre-cert blocked: missing_argument_value"); return 2 }
        if (arg == "--selected-atoms") {
            if (options.selectedAtomsPath != "") { println("candidate pre-cert blocked: duplicate_argument"); return 2 }
            options.selectedAtomsPath = args[i + 1]
        } else if (arg == "--output-root") {
            if (options.outputRoot != "") { println("candidate pre-cert blocked: duplicate_argument"); return 2 }
            options.outputRoot = args[i + 1]
        } else if (arg == "--candidate-version") {
            if (options.candidateVersion != "") { println("candidate pre-cert blocked: duplicate_argument"); return 2 }
            options.candidateVersion = args[i + 1]
        } else {
            if (options.authorityStore != "") { println("candidate pre-cert blocked: duplicate_argument"); return 2 }
            options.authorityStore = args[i + 1]
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
    store: FileKnowledgeStore, candidateVersion: String,
    immutableManifestHash: String,
    faultInjector!: CkbCandidatePrecertFaultInjector = NoopCkbCandidatePrecertFaultInjector()): String {
    let temp = Path(output.toString() + ".tmp-" + benchmarkGapSha256(
        immutableManifestHash + output.toString()).replace("sha256:", ""))
    try {
        if (exists(temp)) { remove(temp, recursive: true) }
        Directory.create(temp, recursive: false)
        for (artifact in artifacts) {
            let path = temp.join(artifact[0]); File.writeTo(path, artifact[1].toArray())
            if (String.fromUtf8(File.readFrom(path)) != artifact[1]) { throw Exception("artifact_readback_mismatch") }
        }
        faultInjector.checkpoint("before_candidate_check")
        let first = store.loadCandidateSnapshotImmutable(candidateVersion)
        if (!first.valid || first.immutableManifestHash != immutableManifestHash) {
            remove(temp, recursive: true); return "candidate_precert_candidate_drift"
        }
        faultInjector.checkpoint("before_publish")
        let second = store.loadCandidateSnapshotImmutable(candidateVersion)
        if (!second.valid || second.immutableManifestHash != immutableManifestHash) {
            remove(temp, recursive: true); return "candidate_precert_candidate_drift"
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

private func ckbCandidatePrecertTaskPacks(candidate: CkbImmutableCandidateSnapshot,
    atoms: ArrayList<NormalizedRecord>): ArrayList<CangjieTaskKnowledgePack> {
    let packs = ArrayList<CangjieTaskKnowledgePack>()
    if (candidate.activeIndex.size == 0) { return packs }
    let kb = newOfflineKnowledgeBase()
    kb.stageCandidateRecords(candidate.version, candidate.activeIndex)
    if (!kb.promoteCandidateToActive(candidate.version)) { return packs }
    let manifest = defaultCangjieVersionManifest()
    if (atoms.size == 0) {
        let request = CangjieTaskKnowledgeRequest()
        request.taskId = "anonymous-generic-probe"
        request.taskText = "Cangjie function and collection syntax"
        request.versionSelector.targetVersion = cangjieDefaultTargetVersion()
        request.budget = CangjieCapabilityLimits.DEFAULT_BUDGET
        packs.add(buildCangjieTaskKnowledgePackForFixedVersion(kb, request,
            manifest, candidate.version))
        return packs
    }
    for (i in 0..atoms.size) {
        let atom = atoms[i]
        let request = CangjieTaskKnowledgeRequest()
        request.taskId = "anonymous-atom-probe-${i}"
        request.taskText = atom.title + "\n" + atom.chunk
        request.versionSelector.targetVersion = if (atom.metadata.targetVersion == "") {
            cangjieDefaultTargetVersion()
        } else { atom.metadata.targetVersion }
        request.budget = CangjieCapabilityLimits.DEFAULT_BUDGET
        packs.add(buildCangjieTaskKnowledgePackForFixedVersion(kb, request,
            manifest, candidate.version))
    }
    packs
}

private func ckbCandidatePrecertTransportReport(
    candidate: CkbImmutableCandidateSnapshot,
    atoms: ArrayList<NormalizedRecord>,
    canonicalOutput: String,
    anonymousQueryArtifactHash: String,
    authority: CangjieBenchmarkLeakageAuthority): CkbStudentServingLeakageReport {
    var report = CkbStudentServingLeakageReport()
    let runtimeRoot = Path(canonicalOutput + ".transport-runtime")
    if (exists(runtimeRoot)) {
        report.diagnostic = "candidate_precert_transport_runtime_exists"
        return report
    }
    try {
        Directory.create(runtimeRoot, recursive: true)
        let runtimeStore = FileKnowledgeStore(runtimeRoot.toString())
        let kb = newOfflineKnowledgeBase()
        kb.stageCandidateRecords(candidate.version, candidate.activeIndex)
        if (!kb.promoteCandidateToActive(candidate.version)) {
            report.diagnostic = "candidate_precert_transport_stage_failed"
        } else if (!kb.persistActiveSnapshot(runtimeStore).ok) {
            report.diagnostic = "candidate_precert_transport_persist_failed"
        } else {
            let service = CkbCommandLoopService(CkbRuntimeConfig(), runtimeStore)
            report = ckbBuildStudentServingLeakageReport(service,
                ckbCandidatePrecertTransportProbes(atoms),
                anonymousQueryArtifactHash: anonymousQueryArtifactHash,
                authority: authority)
        }
    } catch (_: Exception) {
        report = CkbStudentServingLeakageReport()
        report.diagnostic = "candidate_precert_transport_runtime_failed"
    }
    try {
        if (exists(runtimeRoot)) { remove(runtimeRoot, recursive: true) }
    } catch (_: Exception) {
        report.ok = false
        report.diagnostic = "candidate_precert_transport_cleanup_failed"
    }
    report
}

private func ckbCandidatePrecertTransportProbes(
    atoms: ArrayList<NormalizedRecord>): ArrayList<CkbStudentServingProbe> {
    let probes = ArrayList<CkbStudentServingProbe>()
    probes.add(ckbCandidatePrecertTransportProbe("case-identity",
        "CJ-HUMANEVAL-000", true))
    probes.add(ckbCandidatePrecertTransportProbe("unicode-path-variant",
        "cangjie\\u002dhumaneval/中文😀/visible\\u002dbenchmark/prompt.md", true))
    if (atoms.size == 0) {
        probes.add(ckbCandidatePrecertTransportProbe("anonymous-generic",
            "Cangjie function and collection syntax", false))
    } else {
        for (i in 0..atoms.size) {
            probes.add(ckbCandidatePrecertTransportProbe("anonymous-atom-${i}",
                ckbBenchmarkGapAnonymousQuery(atoms[i]), false))
        }
    }
    probes
}

private func ckbCandidatePrecertTransportProbe(id: String, query: String,
    expectedBlocked: Bool): CkbStudentServingProbe {
    let probe = CkbStudentServingProbe()
    probe.probeId = id
    probe.query = query
    probe.expectedBlocked = expectedBlocked
    probe
}

private func ckbCandidatePrecertEscape(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"")
        .replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
}
