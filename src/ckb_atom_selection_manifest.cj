package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashMap, HashSet}
import std.fs.{File, Path, canonicalize, exists, remove, rename}
import std.sort.*
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

public class CkbAtomSelectionOptions {
    public var manifestPath: String = ""
    public var teacherExportRoot: String = ""
    public var outputPath: String = ""
    public var proofPath: String = ""
    public init() {}
}

public class CkbAtomSelectionResult {
    public var ok: Bool = false
    public var diagnostic: String = "selection_not_run"
    public var inputRows: Int64 = 0
    public var selected: Int64 = 0
    public var aggregateJsonl: String = ""
    public var proofJson: String = ""
    public var evidenceHash: String = ""
    public init() {}
}

private class CkbAtomSelectionRow {
    var artifactPath: String = ""
    var fileSha256: String = ""
    var candidateHash: String = ""
    var atomId: String = ""
    var datasetVersion: String = ""
    var supersedes: String = ""
    var revision: Int64 = 0
    var sourceClass: String = ""
    var targetVersion: String = ""
    var atomCandidateHash: String = ""
    var atomBundleHash: String = ""
    var sourceAtomCandidateHash: String = ""
    var sourceAtomBundleHash: String = ""
    var atomHashSchema: String = ""
    var normalizedCandidateHash: String = ""
    var candidateJson: String = ""
    var knowledgeText: String = ""
    var example: String = ""
    init() {}
}

public func ckbBuildAtomSelection(options: CkbAtomSelectionOptions): CkbAtomSelectionResult {
    let result = CkbAtomSelectionResult()
    if (options.manifestPath.trimAscii() == "" || options.teacherExportRoot.trimAscii() == "" ||
        options.outputPath.trimAscii() == "" || options.proofPath.trimAscii() == "" ||
        options.outputPath == options.proofPath) {
        result.diagnostic = "selection_options_invalid"; return result
    }
    let root = try { canonicalize(Path(options.teacherExportRoot)).toString() }
        catch (_: Exception) { result.diagnostic = "teacher_export_root_invalid"; return result }
    let manifest = ckbAtomSelectionRead(options.manifestPath)
    if (manifest[0] != "ok") { result.diagnostic = manifest[0]; return result }
    let rows = ArrayList<CkbAtomSelectionRow>()
    var lineNumber: Int64 = 0
    for (line in manifest[1].split("\n")) {
        lineNumber += 1
        let raw = line.trimAscii()
        if (raw == "") { continue }
        let parsed = ckbAtomSelectionParseRow(raw)
        if (parsed[0] != "ok") { result.diagnostic = parsed[0]; return result }
        let row = parsed[1]
        let loaded = ckbAtomSelectionLoadCandidate(root, row)
        if (loaded != "ok") { result.diagnostic = loaded; return result }
        rows.add(row)
    }
    result.inputRows = rows.size
    let graph = ckbAtomSelectionGraphDiagnostic(rows)
    if (graph != "ok") { result.diagnostic = graph; return result }
    let selected = ckbAtomSelectionLeaves(rows)
    result.selected = selected.size
    result.aggregateJsonl = ckbAtomSelectionAggregate(selected)
    let aggregateCuration = curateBenchmarkGapRecordsFromJsonl(result.aggregateJsonl)
    if (result.selected > 0 && (!aggregateCuration.ok || aggregateCuration.records.size != result.selected)) {
        result.diagnostic = "normalized_aggregate_curation_failed"; return result
    }
    let manifestHash = ckbAtomSelectionManifestHash(rows)
    let aggregateHash = benchmarkGapSha256(result.aggregateJsonl)
    let setHash = ckbAtomSelectionSetHash(selected)
    let migrations = ckbAtomSelectionMigrationProof(rows)
    let proofBody = "{\"schemaVersion\":\"ckb-atom-selection-proof-v2\",\"inputRows\":${result.inputRows},\"selected\":${result.selected},\"manifestHash\":\"${manifestHash}\",\"aggregateHash\":\"${aggregateHash}\",\"selectionSetHash\":\"${setHash}\",\"schemaMigrations\":${migrations}"
    result.evidenceHash = benchmarkGapSha256(proofBody + "}")
    result.proofJson = proofBody + ",\"evidenceHash\":\"${result.evidenceHash}\"}"
    let written = ckbAtomSelectionAtomicWrite(options.outputPath, result.aggregateJsonl,
        options.proofPath, result.proofJson, result.evidenceHash)
    if (written != "ok") { result.diagnostic = written; return result }
    result.ok = true; result.diagnostic = "ok"; result
}

public func ckbAtomSelectionFileSha256(path: String): String {
    ckbAtomSelectionBytesSha256(File.readFrom(Path(path)))
}

public func runCkbAtomSelectionCli(args: Array<String>): Int64 {
    let options = CkbAtomSelectionOptions()
    var commandSeen = false
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "cangjie-atom-selection-build" && !commandSeen) {
            commandSeen = true; i += 1; continue
        }
        if (!["--manifest", "--teacher-export-root", "--output", "--proof"].contains(arg)) {
            println("atom selection blocked: unknown_argument"); return 2
        }
        if (i + 1 >= args.size) { println("atom selection blocked: missing_argument_value"); return 2 }
        let value = args[i + 1]
        if (arg == "--manifest") { if (options.manifestPath != "") { println("atom selection blocked: duplicate_argument"); return 2 }; options.manifestPath = value }
        if (arg == "--teacher-export-root") { if (options.teacherExportRoot != "") { println("atom selection blocked: duplicate_argument"); return 2 }; options.teacherExportRoot = value }
        if (arg == "--output") { if (options.outputPath != "") { println("atom selection blocked: duplicate_argument"); return 2 }; options.outputPath = value }
        if (arg == "--proof") { if (options.proofPath != "") { println("atom selection blocked: duplicate_argument"); return 2 }; options.proofPath = value }
        i += 2
    }
    if (!commandSeen) { println("atom selection blocked: command_required"); return 2 }
    let result = ckbBuildAtomSelection(options)
    println("atom selection ok=${result.ok} inputRows=${result.inputRows} selected=${result.selected} evidenceHash=${result.evidenceHash} diagnostic=${result.diagnostic}")
    if (result.ok) { 0 } else { 1 }
}

private func ckbAtomSelectionParseRow(raw: String): (String, CkbAtomSelectionRow) {
    let row = CkbAtomSelectionRow()
    for (key in ["artifactPath", "fileSha256", "candidateHash", "atomId", "datasetVersion", "supersedes"]) {
        if (raw.split("\"${key}\"").size != 2) { return ("selection_field_contract_invalid", row) }
    }
    try {
        let object = JsonValue.fromStr(raw).asObject()
        if (object.size() != 6) { return ("selection_field_contract_invalid", row) }
        row.artifactPath = ckbAtomSelectionString(object, "artifactPath")
        row.fileSha256 = ckbAtomSelectionString(object, "fileSha256")
        row.candidateHash = ckbAtomSelectionString(object, "candidateHash")
        row.atomId = ckbAtomSelectionString(object, "atomId")
        row.datasetVersion = ckbAtomSelectionString(object, "datasetVersion")
        row.supersedes = ckbAtomSelectionString(object, "supersedes")
    } catch (_: Exception) { return ("selection_field_contract_invalid", row) }
    if (!ckbAtomSelectionSafePath(row.artifactPath)) { return ("artifact_path_forbidden", row) }
    if (!ckbAtomSelectionHash(row.fileSha256) || !ckbAtomSelectionHash(row.candidateHash) ||
        (row.supersedes != "" && !ckbAtomSelectionHash(row.supersedes)) ||
        !ckbAtomSelectionIdentity(row.atomId) || !ckbAtomSelectionIdentity(row.datasetVersion)) {
        return ("selection_field_contract_invalid", row)
    }
    ("ok", row)
}

private func ckbAtomSelectionLoadCandidate(root: String, row: CkbAtomSelectionRow): String {
    let expected = Path(root).join(row.artifactPath).toString()
    let canonical = try { canonicalize(Path(expected)).toString() }
        catch (_: Exception) { return "artifact_read_failed" }
    if (canonical != expected || !canonical.startsWith(root + "/")) { return "artifact_symlink_forbidden" }
    let bytes = try { File.readFrom(Path(canonical)) } catch (_: Exception) { return "artifact_read_failed" }
    if (ckbAtomSelectionBytesSha256(bytes) != row.fileSha256) { return "artifact_sha256_mismatch" }
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) { return "invalid_response_encoding" }
    var candidateLine = ""
    for (line in text.split("\n")) {
        let clean = line.trimAscii()
        if (clean == "") { continue }
        if (candidateLine != "") { return "candidate_record_count_invalid" }
        candidateLine = clean
    }
    if (candidateLine == "") { return "candidate_record_count_invalid" }
    row.candidateJson = candidateLine
    let parsed = parseBenchmarkGapInputsJsonl(candidateLine)
    if (!parsed.ok || parsed.inputs.size != 1) { return "candidate_record_invalid" }
    let input = parsed.inputs[0]
    let exactBundle = ckbMcpJsonObjectField(candidateLine, "knowledgeAtomTestBundle")
    if (!input.knowledgeAtomCandidate || exactBundle == "") { return "knowledge_atom_candidate_required" }
    input.knowledgeAtomTestBundle = exactBundle
    if (input.candidateHash != row.candidateHash || input.candidateHash != canonicalBenchmarkGapCandidateHash(input)) {
        return "candidate_hash_mismatch"
    }
    if (input.datasetVersion != row.datasetVersion) { return "dataset_version_mismatch" }
    let sourceBundleObject = try { JsonValue.fromStr(exactBundle).asObject() }
        catch (_: Exception) { return "candidate_record_invalid" }
    row.sourceAtomCandidateHash = try { ckbAtomSelectionString(sourceBundleObject, "candidateHash") }
        catch (_: Exception) { return "candidate_record_invalid" }
    row.sourceAtomBundleHash = benchmarkGapSha256(exactBundle.trimAscii())
    let currentHash = cangjieKnowledgeAtomCandidateHash(exactBundle)
    if (row.sourceAtomCandidateHash == currentHash) {
        row.atomHashSchema = "ckb-knowledge-atom-hash-current-v1"
    } else if (row.sourceAtomCandidateHash == ckbAtomSelectionLegacyCandidateHash(exactBundle)) {
        row.atomHashSchema = "ckb-knowledge-atom-hash-legacy-8aa2969-parent"
    } else {
        return "atom_candidate_hash_mismatch"
    }
    let normalizedBundle = ckbAtomSelectionNormalizeBundle(exactBundle, row.sourceAtomCandidateHash, currentHash)
    if (normalizedBundle == "") { return "atom_candidate_hash_mismatch" }
    input.knowledgeAtomTestBundle = normalizedBundle
    let atom = runKnowledgeAtomTestBundle(normalizedBundle)
    if (!atom.ok) { return atom.diagnostic }
    if (atom.atomId != row.atomId) { return "atom_id_mismatch" }
    let bundleObject = try { JsonValue.fromStr(normalizedBundle).asObject() }
        catch (_: Exception) { return "candidate_record_invalid" }
    row.atomCandidateHash = try { ckbAtomSelectionString(bundleObject, "candidateHash") }
        catch (_: Exception) { return "candidate_record_invalid" }
    row.atomBundleHash = benchmarkGapSha256(normalizedBundle)
    input.candidateHash = canonicalBenchmarkGapCandidateHash(input)
    row.normalizedCandidateHash = input.candidateHash
    row.candidateJson = ckbAtomSelectionRenderCandidate(input)
    let one = ArrayList<CangjieBenchmarkGapInput>(); one.add(input)
    let curated = curateBenchmarkGapRecords(one)
    if (!curated.ok) { return curated.diagnostic }
    row.revision = input.revision
    row.sourceClass = atom.sourceClass
    row.targetVersion = try { JsonValue.fromStr(input.knowledgeAtomTestBundle).asObject().get("targetVersion").getOrThrow().asString().getValue() }
        catch (_: Exception) { return "candidate_record_invalid" }
    row.knowledgeText = atom.knowledgeText
    row.example = atom.example
    "ok"
}

private func ckbAtomSelectionGraphDiagnostic(rows: ArrayList<CkbAtomSelectionRow>): String {
    let byHash = HashMap<String, Int64>()
    let byRevision = HashMap<String, String>()
    let atomProvenance = HashMap<String, String>()
    for (i in 0..rows.size) {
        let row = rows[i]
        let provenanceKey = ckbAtomSelectionIdentityKey(row) + "|${row.atomCandidateHash}"
        match (atomProvenance.get(provenanceKey)) {
            case Some(existing) => if (existing != row.atomBundleHash) { return "atom_identity_provenance_conflict" }
            case None => atomProvenance.add(provenanceKey, row.atomBundleHash)
        }
        if (byHash.contains(row.candidateHash)) { return "selection_duplicate_candidate" }
        byHash.add(row.candidateHash, i)
        let key = ckbAtomSelectionIdentityKey(row) + ":${row.revision}"
        if (byRevision.contains(key)) { return "selection_revision_conflict" }
        byRevision.add(key, row.candidateHash)
    }
    for (row in rows) {
        let seen = HashSet<String>()
        var cursor = row.candidateHash
        while (cursor != "") {
            if (seen.contains(cursor)) { return "selection_cycle" }
            seen.add(cursor)
            match (byHash.get(cursor)) {
                case Some(index) => cursor = rows[index].supersedes
                case None => return "selection_dangling_supersedes"
            }
        }
    }
    let roots = HashMap<String, Int64>()
    let leaves = HashMap<String, Int64>()
    let childCount = HashMap<String, Int64>()
    for (row in rows) { childCount.add(row.candidateHash, 0) }
    for (row in rows) {
        let identity = ckbAtomSelectionIdentityKey(row)
        if (row.supersedes == "") {
            roots[identity] = match (roots.get(identity)) { case Some(value) => value + 1; case None => 1 }
            continue
        }
        let parent = rows[byHash.get(row.supersedes).getOrThrow()]
        if (ckbAtomSelectionIdentityKey(parent) != identity || row.revision <= parent.revision) {
            return "selection_revision_conflict"
        }
        childCount[row.supersedes] = childCount.get(row.supersedes).getOrThrow() + 1
        if (childCount[row.supersedes] > 1) { return "selection_conflict" }
    }
    for (row in rows) {
        let identity = ckbAtomSelectionIdentityKey(row)
        if (childCount.get(row.candidateHash).getOrThrow() == 0) {
            leaves[identity] = match (leaves.get(identity)) { case Some(value) => value + 1; case None => 1 }
        }
    }
    for (row in rows) {
        let identity = ckbAtomSelectionIdentityKey(row)
        if (roots.get(identity).getOrThrow() != 1 || leaves.get(identity).getOrThrow() != 1) {
            return "selection_conflict"
        }
    }
    "ok"
}

private func ckbAtomSelectionLeaves(rows: ArrayList<CkbAtomSelectionRow>): ArrayList<CkbAtomSelectionRow> {
    let parent = HashSet<String>()
    for (row in rows) { if (row.supersedes != "") { parent.add(row.supersedes) } }
    let keyed = HashMap<String, CkbAtomSelectionRow>()
    let keys = ArrayList<String>()
    for (row in rows) {
        if (!parent.contains(row.candidateHash)) {
            let key = "${row.atomId.toAsciiLower()}|${row.datasetVersion.toAsciiLower()}|${row.candidateHash}"
            keyed.add(key, row); keys.add(key)
        }
    }
    let ordered = keys.toArray(); sort(ordered)
    let out = ArrayList<CkbAtomSelectionRow>()
    for (key in ordered) { out.add(keyed.get(key).getOrThrow()) }
    out
}

private func ckbAtomSelectionAggregate(rows: ArrayList<CkbAtomSelectionRow>): String {
    let out = StringBuilder()
    for (row in rows) { out.append(row.candidateJson); out.append("\n") }
    out.toString()
}

private func ckbAtomSelectionManifestHash(rows: ArrayList<CkbAtomSelectionRow>): String {
    let parts = ArrayList<String>()
    for (row in rows) {
        parts.add("${row.artifactPath}|${row.fileSha256}|${row.candidateHash}|${row.atomId}|${row.datasetVersion}|${row.supersedes}|${row.revision}|${row.sourceAtomCandidateHash}|${row.sourceAtomBundleHash}|${row.atomHashSchema}|${row.atomCandidateHash}|${row.atomBundleHash}|${row.normalizedCandidateHash}")
    }
    let ordered = parts.toArray(); sort(ordered); let out = StringBuilder()
    for (part in ordered) { out.append("${part.toArray().size}:${part}") }
    benchmarkGapSha256(out.toString())
}

private func ckbAtomSelectionSetHash(rows: ArrayList<CkbAtomSelectionRow>): String {
    let out = StringBuilder()
    for (row in rows) { let part = "${row.atomId}|${row.datasetVersion}|${row.candidateHash}|${row.fileSha256}|${row.sourceAtomCandidateHash}|${row.sourceAtomBundleHash}|${row.atomHashSchema}|${row.atomCandidateHash}|${row.atomBundleHash}|${row.normalizedCandidateHash}|${row.revision}"; out.append("${part.toArray().size}:${part}") }
    benchmarkGapSha256(out.toString())
}

private func ckbAtomSelectionMigrationProof(rows: ArrayList<CkbAtomSelectionRow>): String {
    let keyed = HashMap<String, String>(); let keys = ArrayList<String>()
    for (row in rows) {
        let key = "${row.candidateHash}|${row.fileSha256}"
        let value = "{\"sourceFileSha256\":\"${row.fileSha256}\",\"sourceCandidateHash\":\"${row.candidateHash}\",\"sourceBundleCandidateHash\":\"${row.sourceAtomCandidateHash}\",\"sourceBundleContentHash\":\"${row.sourceAtomBundleHash}\",\"sourceBundleHashSchema\":\"${row.atomHashSchema}\",\"normalizedBundleCandidateHash\":\"${row.atomCandidateHash}\",\"normalizedBundleContentHash\":\"${row.atomBundleHash}\",\"normalizedCandidateHash\":\"${row.normalizedCandidateHash}\"}"
        keyed.add(key, value); keys.add(key)
    }
    let ordered = keys.toArray(); sort(ordered); let out = StringBuilder(); out.append("[")
    for (i in 0..ordered.size) { if (i > 0) { out.append(",") }; out.append(keyed.get(ordered[i]).getOrThrow()) }
    out.append("]"); out.toString()
}

private func ckbAtomSelectionLegacyCandidateHash(bundle: String): String {
    try {
        let object = JsonValue.fromStr(bundle.trimAscii()).asObject()
        let purified = match (object.get("purificationPassed")) {
            case Some(value) => "${value.asBool().getValue()}"
            case None => ""
        }
        let tests = object.get("tests").getOrThrow().toString()
        benchmarkGapSha256(ckbAtomSelectionPart(ckbAtomSelectionString(object, "atomId")) +
            ckbAtomSelectionPart(ckbAtomSelectionString(object, "sourceClass").toAsciiLower()) +
            ckbAtomSelectionPart(ckbAtomSelectionString(object, "citation").toAsciiLower()) +
            ckbAtomSelectionPart(ckbAtomSelectionString(object, "targetVersion")) +
            ckbAtomSelectionPart(ckbAtomSelectionString(object, "knowledgeText")) +
            ckbAtomSelectionPart(purified) + ckbAtomSelectionPart(tests))
    } catch (_: Exception) { "" }
}

private func ckbAtomSelectionNormalizeBundle(bundle: String, declaredHash: String, currentHash: String): String {
    try {
        let canonical = JsonValue.fromStr(bundle.trimAscii()).asObject().toString()
        let marker = "\"candidateHash\":\"${declaredHash}\""
        if (canonical.split(marker).size != 2) { return "" }
        canonical.replace(marker, "\"candidateHash\":\"${currentHash}\"")
    } catch (_: Exception) { "" }
}

private func ckbAtomSelectionRenderCandidate(input: CangjieBenchmarkGapInput): String {
    let source = if (input.sourceClass == "") { "" } else { ",\"sourceClass\":\"${ckbAtomSelectionEscape(input.sourceClass)}\"" }
    "{\"schemaVersion\":\"${ckbAtomSelectionEscape(input.schemaVersion)}\",\"datasetVersion\":\"${ckbAtomSelectionEscape(input.datasetVersion)}\",\"teacherRunId\":\"${ckbAtomSelectionEscape(input.teacherRunId)}\",\"evidenceHash\":\"${ckbAtomSelectionEscape(input.evidenceHash)}\",\"evidence\":\"${ckbAtomSelectionEscape(input.evidence)}\",\"candidateHash\":\"${input.candidateHash}\",\"candidatePath\":\"${ckbAtomSelectionEscape(input.candidatePath)}\",\"revision\":${input.revision},\"attempt\":${input.attempt},\"failureTaxonomy\":\"${ckbAtomSelectionEscape(input.failureTaxonomy)}\",\"knowledgeGapConfirmations\":${input.knowledgeGapConfirmations}${source},\"caseId\":\"${ckbAtomSelectionEscape(input.caseId)}\",\"benchmark\":\"${ckbAtomSelectionEscape(input.benchmark)}\",\"taskText\":\"${ckbAtomSelectionEscape(input.taskText)}\",\"visibleTestExcerpt\":\"${ckbAtomSelectionEscape(input.visibleTestExcerpt)}\",\"compilerOutput\":\"${ckbAtomSelectionEscape(input.compilerOutput)}\",\"missingKnowledge\":\"${ckbAtomSelectionEscape(input.missingKnowledge)}\",\"interfaceId\":\"${ckbAtomSelectionEscape(input.interfaceId)}\",\"contentFamily\":\"${ckbAtomSelectionEscape(input.contentFamily)}\",\"updateMechanism\":\"${ckbAtomSelectionEscape(input.updateMechanism)}\",\"targetVersion\":\"${ckbAtomSelectionEscape(input.targetVersion)}\",\"officialCitation\":\"${ckbAtomSelectionEscape(input.officialCitation)}\",\"knowledgeAtomTestBundle\":${input.knowledgeAtomTestBundle},\"knowledgeAtomCandidate\":true}"
}

private func ckbAtomSelectionPart(value: String): String { "${value.toArray().size}:${value}" }

private func ckbAtomSelectionAtomicWrite(outputPath: String, output: String, proofPath: String,
    proof: String, evidenceHash: String): String {
    let suffix = evidenceHash.replace("sha256:", "")
    let outputTmp = "${outputPath}.tmp-${suffix}"
    let proofTmp = "${proofPath}.tmp-${suffix}"
    try {
        File.writeTo(Path(outputTmp), output.toArray())
        File.writeTo(Path(proofTmp), proof.toArray())
        rename(outputTmp, to: outputPath, overwrite: true)
        rename(proofTmp, to: proofPath, overwrite: true)
        "ok"
    } catch (_: Exception) {
        try { if (exists(Path(outputTmp))) { remove(outputTmp) } } catch (_: Exception) {}
        try { if (exists(Path(proofTmp))) { remove(proofTmp) } } catch (_: Exception) {}
        "selection_atomic_write_failed"
    }
}

private func ckbAtomSelectionRead(path: String): (String, String) {
    let bytes = try { File.readFrom(Path(path)) } catch (_: Exception) { return ("manifest_read_failed", "") }
    try { ("ok", String.fromUtf8(bytes)) } catch (_: Exception) { ("invalid_response_encoding", "") }
}

private func ckbAtomSelectionSafePath(value: String): Bool {
    let clean = value.trimAscii()
    if (clean == "" || clean != value || clean.startsWith("/") || clean.startsWith("~") ||
        clean.contains("\\") || clean.toAsciiLower().contains("hidden") ||
        clean.toAsciiLower().contains("reference") || clean.toAsciiLower().contains("solution")) { return false }
    for (part in clean.split("/")) { if (part == "" || part == "." || part == "..") { return false } }
    true
}

private func ckbAtomSelectionIdentity(value: String): Bool {
    let runes = value.toRuneArray()
    if (value.trimAscii() == "" || runes.size > 256) { return false }
    for (r in runes) { if (r == r'\n' || r == r'\r' || r == r'\t' || r == r'/' || r == r'\\') { return false } }
    true
}

private func ckbAtomSelectionIdentityKey(row: CkbAtomSelectionRow): String {
    "${row.atomId.trimAscii().toAsciiLower()}|${row.datasetVersion.trimAscii().toAsciiLower()}"
}

private func ckbAtomSelectionString(object: JsonObject, key: String): String {
    object.get(key).getOrThrow().asString().getValue()
}

private func ckbAtomSelectionBytesSha256(bytes: Array<UInt8>): String {
    let digest = SHA256(); digest.write(bytes); let out = StringBuilder()
    for (byte in digest.finish()) { out.append(ckbAtomSelectionNibble(byte / UInt8(16))); out.append(ckbAtomSelectionNibble(byte % UInt8(16))) }
    "sha256:${out.toString()}"
}

private func ckbAtomSelectionHash(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 71 || !value.startsWith("sha256:")) { return false }
    for (i in 7..71) { let r = runes[i]; if (!((r >= r'0' && r <= r'9') || (r >= r'a' && r <= r'f'))) { return false } }
    true
}

private func ckbAtomSelectionNibble(value: UInt8): String {
    if(value==UInt8(0)){return "0"};if(value==UInt8(1)){return "1"};if(value==UInt8(2)){return "2"};if(value==UInt8(3)){return "3"};if(value==UInt8(4)){return "4"};if(value==UInt8(5)){return "5"};if(value==UInt8(6)){return "6"};if(value==UInt8(7)){return "7"};if(value==UInt8(8)){return "8"};if(value==UInt8(9)){return "9"};if(value==UInt8(10)){return "a"};if(value==UInt8(11)){return "b"};if(value==UInt8(12)){return "c"};if(value==UInt8(13)){return "d"};if(value==UInt8(14)){return "e"};"f"
}

private func ckbAtomSelectionEscape(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
}
