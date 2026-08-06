package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashMap, HashSet}
import std.convert.Parsable
import std.fs.{Directory, File, OpenMode, Path, exists, remove, rename}
import std.io.StringReader
import std.process.launch
import std.sort.*
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

// Frozen upstream identity. Production callers cannot replace any of these values.
public let CKB_HUMANEVAL_PLUS_AUTHORITY_SCHEMA = "ckb-humaneval-plus-authority-v1"
public let CKB_HUMANEVAL_PLUS_EVALUATOR_COMMIT = "437e6936d3fad9487e891c24e4509b9561b95e3a"
public let CKB_HUMANEVAL_PLUS_RELEASE_REPOSITORY = "https://github.com/evalplus/humanevalplus_release.git"
public let CKB_HUMANEVAL_PLUS_RELEASE_TAG = "v0.1.10"
public let CKB_HUMANEVAL_PLUS_RELEASE_TAG_OBJECT = "ea5804b59b8a7837cb2faa1b10273fa804cdea5c"
public let CKB_HUMANEVAL_PLUS_RELEASE_COMMIT = "68cd26d53a0dec69f85eafe1f82a2a74155a2bd6"
public let CKB_HUMANEVAL_PLUS_RELEASE_URL = "https://github.com/evalplus/humanevalplus_release/releases/download/v0.1.10/HumanEvalPlus.jsonl.gz"
public let CKB_HUMANEVAL_PLUS_GZIP_HASH = "sha256:272720b90ac375502c8ed23cd791c2a93dfb22a911641a494da74a426c09f101"
public let CKB_HUMANEVAL_PLUS_JSONL_HASH = "sha256:42526ec0e7d5f3ee0b06d6ced98f8c8bae3d76519151bfb3d36f79010645bd7f"
public let CKB_HUMANEVAL_PLUS_DEFECT_DISPOSITION = "not_applicable_to_frozen_cangjie_signature"
public let CKB_HUMANEVAL_PLUS_EXPECTED_CASES: Int64 = 164
public let CKB_HUMANEVAL_PLUS_EXPECTED_CALLS: Int64 = 122683

public class CangjieHumanEvalPlusAuthorityRow {
    public var schemaVersion = ""
    public var evaluatorCommit = ""
    public var releaseRepository = ""
    public var releaseTag = ""
    public var releaseTagObject = ""
    public var releaseCommit = ""
    public var releaseUrl = ""
    public var releaseGzipHash = ""
    public var releaseJsonlHash = ""
    public var sourceAssetHash = ""
    public var sourceTaskId = ""
    public var caseId = ""
    public var plusOrdinal: Int64 = -1
    public var status = ""
    public var reviewed = false
    public var rawInputHash = ""
    public var publicSignatureHash = ""
    public var projectionContractHash = ""
    public var projectedInputType = ""
    public var projectedExpectedType = ""
    public var projectedInputHash = ""
    public var projectedExpectedHash = ""
    public var oracleHash = ""
    public var assertionId = ""
    public var assertionHash = ""
    public var verifierHash = ""
    public var semanticDisposition = ""
    public var defectStage = ""
    public var defectReason = ""
    public var defectPath = ""
    public var defectEvidenceHash = ""
    public var reviewEvidenceHash = ""
    public init() {}
}

public class CangjieHumanEvalPlusAuthorityResult {
    public var ok = false
    public var diagnostic = "authority_not_built"
    public var caseCount: Int64 = 0
    public var callCount: Int64 = 0
    public var executableCount: Int64 = 0
    public var benchmarkDefectCount: Int64 = 0
    public var sourceAssetHash = ""
    public var canonicalJson = ""
    public var authorityHash = ""
    public let caseCounts = HashMap<String, Int64>()
    public let caseExecutableCounts = HashMap<String, Int64>()
    public let rows = ArrayList<CangjieHumanEvalPlusAuthorityRow>()
    public init() {}
}

private let ckbPlusFields = [
    "schemaVersion", "evaluatorCommit", "releaseRepository", "releaseTag",
    "releaseTagObject", "releaseCommit", "releaseUrl", "releaseGzipHash",
    "releaseJsonlHash", "sourceAssetHash", "sourceTaskId", "caseId", "plusOrdinal",
    "status", "reviewed", "rawInputHash", "publicSignatureHash",
    "projectionContractHash", "projectedInputType", "projectedExpectedType",
    "projectedInputHash", "projectedExpectedHash", "oracleHash", "assertionId",
    "assertionHash", "verifierHash", "semanticDisposition", "defectStage",
    "defectReason", "defectPath", "defectEvidenceHash", "reviewEvidenceHash"
]

// Public parsing is structural. Fixed production identity and counts are enforced by validate/build.
func parseCangjieHumanEvalPlusAuthority(
    bytes: Array<UInt8>
): CangjieHumanEvalPlusAuthorityResult {
    let out = CangjieHumanEvalPlusAuthorityResult()
    let raw = try {
        String.fromUtf8(bytes)
    } catch (_: Exception) {
        out.diagnostic = "invalid_response_encoding"
        return out
    }
    try {
        for (line in raw.split("\n")) {
            let text = line.trimAscii()
            if (text == "") { continue }
            let object = JsonValue.fromStr(text).asObject()
            if (object.getFields().size != ckbPlusFields.size ||
                !ckbPlusUniqueFields(text)) {
                out.diagnostic = "authority_unknown_or_duplicate_field"
                return out
            }
            out.rows.add(ckbPlusParseRow(object))
        }
    } catch (_: Exception) {
        out.diagnostic = "malformed_json"
        return out
    }
    out.diagnostic = "ok"
    out
}

// Production validation is permanently fixed to all 164 cases and 122683 Plus calls.
func validateCangjieHumanEvalPlusAuthority(
    parsed: CangjieHumanEvalPlusAuthorityResult
): CangjieHumanEvalPlusAuthorityResult {
    ckbPlusValidate(parsed, CKB_HUMANEVAL_PLUS_EXPECTED_CASES,
        CKB_HUMANEVAL_PLUS_EXPECTED_CALLS)
}

// Production build deliberately exposes no count or source-identity override.
func buildCangjieHumanEvalPlusAuthority(
    bytes: Array<UInt8>
): CangjieHumanEvalPlusAuthorityResult {
    ckbPlusBuild(bytes, CKB_HUMANEVAL_PLUS_EXPECTED_CASES,
        CKB_HUMANEVAL_PLUS_EXPECTED_CALLS)
}

func renderCangjieHumanEvalPlusAuthority(
    result: CangjieHumanEvalPlusAuthorityResult
): String {
    let indexed = HashMap<String, CangjieHumanEvalPlusAuthorityRow>()
    for (row in result.rows) {
        indexed.add("${row.sourceTaskId}|${row.plusOrdinal}", row)
    }
    let out = StringBuilder()
    for (caseIndex in 0..result.caseCount) {
        let caseId = ckbPlusCaseId(caseIndex)
        for (ordinal in 0..result.caseCounts[caseId]) {
            out.append(ckbPlusRenderRow(indexed["HumanEval/${caseIndex}|${ordinal}"]))
            out.append("\n")
        }
    }
    out.toString()
}

public func runCangjieHumanEvalPlusAuthorityBuild(args: Array<String>): Int64 {
    var authorityRoot = ""
    var datasetRoot = ""
    var output = ""
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "cangjie-humaneval-plus-authority-build") { i += 1; continue }
        if ((arg == "--authority-root" || arg == "--dataset-root" || arg == "--output") &&
            i + 1 >= args.size) {
            println("plus authority build usage error")
            return 2
        }
        if (arg == "--authority-root") { authorityRoot = args[i + 1]; i += 2; continue }
        if (arg == "--dataset-root") { datasetRoot = args[i + 1]; i += 2; continue }
        if (arg == "--output") { output = args[i + 1]; i += 2; continue }
        println("plus authority build usage error")
        return 2
    }
    if (authorityRoot == "" || datasetRoot == "" || output == "") {
        println("plus authority build usage error")
        return 2
    }
    let built = buildCangjieHumanEvalPlusCompactAuthority(authorityRoot, datasetRoot)
    if (!built.ok) {
        println("plus authority build blocked: ${built.diagnostic}")
        return 1
    }
    if (!ckbPlusCompactAtomicWrite(Path(output), built.compactJson, built.authorityHash)) {
        println("plus authority build blocked: authority_output_write_failed")
        return 1
    }
    println("plus authority built: cases=${built.caseCount} calls=${built.total} " +
        "executable=${built.executable} benchmark_defect=${built.defect} " +
        "hash=${built.authorityHash}")
    0
}

private func ckbPlusBuild(bytes: Array<UInt8>, expectedCaseCount: Int64,
    expectedCallCount: Int64): CangjieHumanEvalPlusAuthorityResult {
    let out = ckbPlusValidate(parseCangjieHumanEvalPlusAuthority(bytes),
        expectedCaseCount, expectedCallCount)
    if (out.diagnostic != "ok") { return out }
    out.canonicalJson = renderCangjieHumanEvalPlusAuthority(out)
    out.authorityHash = benchmarkGapSha256(out.canonicalJson)
    out.ok = true
    out
}

// Every call is accounted for once; evidence rules differ by executable/defect status.
private func ckbPlusValidate(parsed: CangjieHumanEvalPlusAuthorityResult,
    expectedCaseCount: Int64, expectedCallCount: Int64): CangjieHumanEvalPlusAuthorityResult {
    if (parsed.diagnostic != "ok") { return parsed }
    let stableKeys = HashSet<String>()
    let assertionIds = HashSet<String>()
    let assertionHashes = HashSet<String>()
    let caseVerifiers = HashMap<String, String>()
    for (row in parsed.rows) {
        let identity = ckbPlusIdentityDiagnostic(row)
        if (identity != "ok") { parsed.diagnostic = identity; return parsed }
        let caseIndex = ckbPlusCaseIndex(row, expectedCaseCount)
        if (caseIndex < 0) { parsed.diagnostic = "case_identity_invalid"; return parsed }
        if (row.plusOrdinal < 0) { parsed.diagnostic = "plus_ordinal_invalid"; return parsed }
        let stableKey = "${row.sourceAssetHash}|${row.sourceTaskId}|${row.plusOrdinal}"
        if (stableKeys.contains(stableKey)) {
            parsed.diagnostic = "duplicate_stable_key"; return parsed
        }
        stableKeys.add(stableKey)
        if (!row.reviewed || !ckbPlusHash(row.reviewEvidenceHash)) {
            parsed.diagnostic = "review_required"; return parsed
        }
        if (!ckbPlusHash(row.rawInputHash) || !ckbPlusHash(row.publicSignatureHash) ||
            !ckbPlusHash(row.projectionContractHash)) {
            parsed.diagnostic = "projection_identity_invalid"; return parsed
        }
        let status = ckbPlusStatusDiagnostic(row, assertionIds, assertionHashes,
            caseVerifiers)
        if (status != "ok") { parsed.diagnostic = status; return parsed }
        ckbPlusIncrement(parsed.caseCounts, row.caseId)
        if (row.status == "executable") {
            ckbPlusIncrement(parsed.caseExecutableCounts, row.caseId)
            parsed.executableCount += 1
        } else {
            parsed.benchmarkDefectCount += 1
        }
    }
    parsed.callCount = Int64(parsed.rows.size)
    if (parsed.callCount != expectedCallCount) {
        parsed.diagnostic = "call_count_mismatch"; return parsed
    }
    parsed.sourceAssetHash = CKB_HUMANEVAL_PLUS_JSONL_HASH
    for (caseIndex in 0..expectedCaseCount) {
        let caseId = ckbPlusCaseId(caseIndex)
        if (!parsed.caseCounts.contains(caseId)) {
            parsed.diagnostic = "case_missing"; return parsed
        }
        if (!parsed.caseExecutableCounts.contains(caseId) ||
            parsed.caseExecutableCounts[caseId] <= 0) {
            parsed.diagnostic = "case_executable_missing"; return parsed
        }
        for (ordinal in 0..parsed.caseCounts[caseId]) {
            let key = "${CKB_HUMANEVAL_PLUS_JSONL_HASH}|HumanEval/${caseIndex}|${ordinal}"
            if (!stableKeys.contains(key)) {
                parsed.diagnostic = "plus_ordinal_not_contiguous"; return parsed
            }
        }
    }
    if (parsed.executableCount + parsed.benchmarkDefectCount != parsed.callCount) {
        parsed.diagnostic = "status_count_mismatch"; return parsed
    }
    parsed.caseCount = expectedCaseCount
    parsed.diagnostic = "ok"
    parsed
}

private func ckbPlusIdentityDiagnostic(row: CangjieHumanEvalPlusAuthorityRow): String {
    if (row.schemaVersion != CKB_HUMANEVAL_PLUS_AUTHORITY_SCHEMA ||
        row.evaluatorCommit != CKB_HUMANEVAL_PLUS_EVALUATOR_COMMIT ||
        row.releaseRepository != CKB_HUMANEVAL_PLUS_RELEASE_REPOSITORY ||
        row.releaseTag != CKB_HUMANEVAL_PLUS_RELEASE_TAG ||
        row.releaseTagObject != CKB_HUMANEVAL_PLUS_RELEASE_TAG_OBJECT ||
        row.releaseCommit != CKB_HUMANEVAL_PLUS_RELEASE_COMMIT ||
        row.releaseUrl != CKB_HUMANEVAL_PLUS_RELEASE_URL ||
        row.releaseGzipHash != CKB_HUMANEVAL_PLUS_GZIP_HASH ||
        row.releaseJsonlHash != CKB_HUMANEVAL_PLUS_JSONL_HASH) {
        return "source_identity_drift"
    }
    if (row.sourceAssetHash != CKB_HUMANEVAL_PLUS_JSONL_HASH) {
        return "source_asset_hash_mismatch"
    }
    "ok"
}

private func ckbPlusStatusDiagnostic(row: CangjieHumanEvalPlusAuthorityRow,
    assertionIds: HashSet<String>, assertionHashes: HashSet<String>,
    caseVerifiers: HashMap<String, String>): String {
    if (row.status == "executable") {
        if (row.projectedInputType == "" || row.projectedExpectedType == "" ||
            !ckbPlusHash(row.projectedInputHash) || !ckbPlusHash(row.projectedExpectedHash) ||
            !ckbPlusHash(row.oracleHash) || !ckbPlusHash(row.assertionHash) ||
            !ckbPlusHash(row.verifierHash) || row.assertionId == "") {
            return "executable_evidence_invalid"
        }
        if (row.semanticDisposition != "" || row.defectStage != "" ||
            row.defectReason != "" || row.defectPath != "" || row.defectEvidenceHash != "") {
            return "executable_defect_evidence_forbidden"
        }
        if (assertionIds.contains(row.assertionId) || assertionHashes.contains(row.assertionHash)) {
            return "duplicate_assertion"
        }
        assertionIds.add(row.assertionId)
        assertionHashes.add(row.assertionHash)
        if (caseVerifiers.contains(row.caseId) &&
            caseVerifiers[row.caseId] != row.verifierHash) {
            return "case_verifier_drift"
        }
        if (!caseVerifiers.contains(row.caseId)) {
            caseVerifiers.add(row.caseId, row.verifierHash)
        }
        return "ok"
    }
    if (row.status != "benchmark_defect") { return "status_invalid" }
    if (row.projectedInputType != "" || row.projectedExpectedType != "" ||
        row.projectedInputHash != "" || row.projectedExpectedHash != "" ||
        row.oracleHash != "" || row.assertionId != "" || row.assertionHash != "" ||
        row.verifierHash != "") {
        return "defect_executable_evidence_forbidden"
    }
    if (row.semanticDisposition != CKB_HUMANEVAL_PLUS_DEFECT_DISPOSITION ||
        row.defectPath == "" || row.defectPath.toArray().size > 256 ||
        !ckbPlusHash(row.defectEvidenceHash) || !ckbPlusDefectReason(row.defectStage,
            row.defectReason)) {
        return "defect_evidence_invalid"
    }
    "ok"
}

private func ckbPlusDefectReason(stage: String, reason: String): Bool {
    if (stage == "input") {
        return ckbPlusOneOf(reason, [
            "input_evalvalue_bigint", "input_evalvalue_nonempty_list",
            "input_evalvalue_nonempty_map", "input_arraylist_expected_object",
            "input_arraylist_expected_string", "input_int64_got_bool",
            "input_int64_got_float", "input_int64_got_list", "input_int64_got_null",
            "input_int64_got_string", "input_plain_bigint"
        ])
    }
    if (stage == "output") {
        return ckbPlusOneOf(reason, [
            "output_evalvalue_bigint", "output_int64_got_bool", "output_int64_got_float",
            "output_int64_got_null", "output_int64_got_string", "output_plain_bigint"
        ])
    }
    false
}

private func ckbPlusCaseIndex(row: CangjieHumanEvalPlusAuthorityRow,
    expectedCaseCount: Int64): Int64 {
    let index = try {
        Int64.parse(row.sourceTaskId.replace("HumanEval/", ""))
    } catch (_: Exception) {
        return -1
    }
    if (index < 0 || index >= expectedCaseCount ||
        row.sourceTaskId != "HumanEval/${index}" || row.caseId != ckbPlusCaseId(index)) {
        return -1
    }
    index
}

private func ckbPlusParseRow(object: JsonObject): CangjieHumanEvalPlusAuthorityRow {
    let row = CangjieHumanEvalPlusAuthorityRow()
    row.schemaVersion = ckbPlusString(object, "schemaVersion")
    row.evaluatorCommit = ckbPlusString(object, "evaluatorCommit")
    row.releaseRepository = ckbPlusString(object, "releaseRepository")
    row.releaseTag = ckbPlusString(object, "releaseTag")
    row.releaseTagObject = ckbPlusString(object, "releaseTagObject")
    row.releaseCommit = ckbPlusString(object, "releaseCommit")
    row.releaseUrl = ckbPlusString(object, "releaseUrl")
    row.releaseGzipHash = ckbPlusString(object, "releaseGzipHash")
    row.releaseJsonlHash = ckbPlusString(object, "releaseJsonlHash")
    row.sourceAssetHash = ckbPlusString(object, "sourceAssetHash")
    row.sourceTaskId = ckbPlusString(object, "sourceTaskId")
    row.caseId = ckbPlusString(object, "caseId")
    row.plusOrdinal = ckbPlusInt(object, "plusOrdinal")
    row.status = ckbPlusString(object, "status")
    row.reviewed = ckbPlusBool(object, "reviewed")
    row.rawInputHash = ckbPlusString(object, "rawInputHash")
    row.publicSignatureHash = ckbPlusString(object, "publicSignatureHash")
    row.projectionContractHash = ckbPlusString(object, "projectionContractHash")
    row.projectedInputType = ckbPlusString(object, "projectedInputType")
    row.projectedExpectedType = ckbPlusString(object, "projectedExpectedType")
    row.projectedInputHash = ckbPlusString(object, "projectedInputHash")
    row.projectedExpectedHash = ckbPlusString(object, "projectedExpectedHash")
    row.oracleHash = ckbPlusString(object, "oracleHash")
    row.assertionId = ckbPlusString(object, "assertionId")
    row.assertionHash = ckbPlusString(object, "assertionHash")
    row.verifierHash = ckbPlusString(object, "verifierHash")
    row.semanticDisposition = ckbPlusString(object, "semanticDisposition")
    row.defectStage = ckbPlusString(object, "defectStage")
    row.defectReason = ckbPlusString(object, "defectReason")
    row.defectPath = ckbPlusString(object, "defectPath")
    row.defectEvidenceHash = ckbPlusString(object, "defectEvidenceHash")
    row.reviewEvidenceHash = ckbPlusString(object, "reviewEvidenceHash")
    row
}

private func ckbPlusWriteValidated(path: Path,
    built: CangjieHumanEvalPlusAuthorityResult, expectedCaseCount: Int64,
    expectedCallCount: Int64): Bool {
    let temporary = path.parent.join(".plus-authority-${built.authorityHash.replace("sha256:", "")}.tmp")
    try {
        if (!exists(path.parent)) { Directory.create(path.parent, recursive: true) }
        if (exists(temporary)) { remove(temporary) }
        File.writeTo(temporary, built.canonicalJson.toArray())
        let temporaryBytes = File.readFrom(temporary)
        let temporaryText = try {
            String.fromUtf8(temporaryBytes)
        } catch (_: Exception) {
            remove(temporary); return false
        }
        let checked = ckbPlusBuild(temporaryBytes, expectedCaseCount, expectedCallCount)
        if (!checked.ok || temporaryText != built.canonicalJson ||
            checked.authorityHash != built.authorityHash) {
            remove(temporary); return false
        }
        rename(temporary, to: path, overwrite: true)
        let finalBytes = File.readFrom(path)
        let finalText = try {
            String.fromUtf8(finalBytes)
        } catch (_: Exception) {
            return false
        }
        let finalChecked = ckbPlusBuild(finalBytes, expectedCaseCount, expectedCallCount)
        finalChecked.ok && finalText == built.canonicalJson &&
            finalChecked.authorityHash == built.authorityHash
    } catch (_: Exception) {
        try { if (exists(temporary)) { remove(temporary) } } catch (_: Exception) { () }
        false
    }
}

private func ckbPlusString(object: JsonObject, key: String): String {
    object.get(key).getOrThrow().asString().getValue()
}
private func ckbPlusInt(object: JsonObject, key: String): Int64 {
    object.get(key).getOrThrow().asInt().getValue()
}
private func ckbPlusBool(object: JsonObject, key: String): Bool {
    object.get(key).getOrThrow().asBool().getValue()
}
private func ckbPlusHash(value: String): Bool {
    if (!value.startsWith("sha256:")) { return false }
    let hex = value.replace("sha256:", "")
    if (hex.size != 64) { return false }
    for (c in hex.toRuneArray()) {
        if (!((c >= r'0' && c <= r'9') || (c >= r'a' && c <= r'f'))) { return false }
    }
    true
}
private func ckbPlusOneOf(value: String, allowed: Array<String>): Bool {
    for (item in allowed) { if (value == item) { return true } }
    false
}
private func ckbPlusUniqueFields(raw: String): Bool {
    for (field in ckbPlusFields) {
        if (raw.split("\"${field}\"").size != 2) { return false }
    }
    true
}
private func ckbPlusIncrement(counts: HashMap<String, Int64>, key: String): Unit {
    if (counts.contains(key)) { counts[key] = counts[key] + 1 } else { counts.add(key, 1) }
}
private func ckbPlusCaseId(index: Int64): String {
    if (index < 10) { "CJ-HUMANEVAL-00${index}" }
    else if (index < 100) { "CJ-HUMANEVAL-0${index}" }
    else { "CJ-HUMANEVAL-${index}" }
}
private func ckbPlusEscape(value: String): String {
    let out = StringBuilder()
    for (c in value.toRuneArray()) {
        if (c == r'\\') { out.append("\\\\") }
        else if (c == r'\"') { out.append("\\\"") }
        else if (c == r'\n') { out.append("\\n") }
        else if (c == r'\r') { out.append("\\r") }
        else if (c == r'\t') { out.append("\\t") }
        else { out.append(c) }
    }
    out.toString()
}
private func ckbPlusRenderRow(r: CangjieHumanEvalPlusAuthorityRow): String {
    "{\"schemaVersion\":\"${ckbPlusEscape(r.schemaVersion)}\"," +
        "\"evaluatorCommit\":\"${r.evaluatorCommit}\",\"releaseRepository\":\"${ckbPlusEscape(r.releaseRepository)}\"," +
        "\"releaseTag\":\"${r.releaseTag}\",\"releaseTagObject\":\"${r.releaseTagObject}\"," +
        "\"releaseCommit\":\"${r.releaseCommit}\",\"releaseUrl\":\"${ckbPlusEscape(r.releaseUrl)}\"," +
        "\"releaseGzipHash\":\"${r.releaseGzipHash}\",\"releaseJsonlHash\":\"${r.releaseJsonlHash}\"," +
        "\"sourceAssetHash\":\"${r.sourceAssetHash}\",\"sourceTaskId\":\"${r.sourceTaskId}\"," +
        "\"caseId\":\"${r.caseId}\",\"plusOrdinal\":${r.plusOrdinal},\"status\":\"${r.status}\"," +
        "\"reviewed\":${r.reviewed},\"rawInputHash\":\"${r.rawInputHash}\"," +
        "\"publicSignatureHash\":\"${r.publicSignatureHash}\",\"projectionContractHash\":\"${r.projectionContractHash}\"," +
        "\"projectedInputType\":\"${ckbPlusEscape(r.projectedInputType)}\",\"projectedExpectedType\":\"${ckbPlusEscape(r.projectedExpectedType)}\"," +
        "\"projectedInputHash\":\"${r.projectedInputHash}\",\"projectedExpectedHash\":\"${r.projectedExpectedHash}\"," +
        "\"oracleHash\":\"${r.oracleHash}\",\"assertionId\":\"${ckbPlusEscape(r.assertionId)}\"," +
        "\"assertionHash\":\"${r.assertionHash}\",\"verifierHash\":\"${r.verifierHash}\"," +
        "\"semanticDisposition\":\"${r.semanticDisposition}\",\"defectStage\":\"${r.defectStage}\"," +
        "\"defectReason\":\"${r.defectReason}\",\"defectPath\":\"${ckbPlusEscape(r.defectPath)}\"," +
        "\"defectEvidenceHash\":\"${r.defectEvidenceHash}\",\"reviewEvidenceHash\":\"${r.reviewEvidenceHash}\"}"
}

public let CKB_HUMANEVAL_PLUS_COMPACT_SCHEMA = "ckb-humaneval-plus-compact-authority-v1"

public class CangjieHumanEvalPlusCompactCase {
    public var caseIndex: Int64 = -1
    public var total: Int64 = 0
    public var executable: Int64 = 0
    public var defect: Int64 = 0
    public var ledgerHash = ""
    public var defectHash = ""
    public var testMainSha256 = ""
    public var cjpmSha256 = ""
    public var directorySha256 = ""
    public init() {}
}

public class CangjieHumanEvalPlusCompactResult {
    public var ok = false
    public var diagnostic = "compact_authority_not_built"
    public var caseCount: Int64 = 0
    public var total: Int64 = 0
    public var executable: Int64 = 0
    public var defect: Int64 = 0
    public var compactJson = ""
    public var authorityHash = ""
    public var sourceLockHash = ""
    public var ledgerArtifactHash = ""
    public var defectArtifactHash = ""
    public var summaryArtifactHash = ""
    public var testsManifestHash = ""
    public var testsManifestArtifactHash = ""
    public let cases = ArrayList<CangjieHumanEvalPlusCompactCase>()
    public init() {}
}

private class CkbPlusCompactDefectEvidence {
    var inputHash = ""
    var outputHash = ""
    var evidenceHash = ""
    public init() {}
}

// The production compact entry scans verbose ledgers but retains only 164 case aggregates.
public func buildCangjieHumanEvalPlusCompactAuthority(authorityRoot: String,
    datasetRoot: String): CangjieHumanEvalPlusCompactResult {
    if (!ckbPlusCompactGitIgnoreAllowed(authorityRoot, datasetRoot, 164)) {
        let blocked = CangjieHumanEvalPlusCompactResult()
        blocked.diagnostic = "compact_authority_ignored_or_git_scope_invalid"
        return blocked
    }
    ckbPlusCompactBuild(authorityRoot, datasetRoot, 164, 122683, 116997, 5686)
}

public func validateCangjieHumanEvalPlusCompactAuthority(authorityRoot: String,
    datasetRoot: String): CangjieHumanEvalPlusCompactResult {
    buildCangjieHumanEvalPlusCompactAuthority(authorityRoot, datasetRoot)
}

public func renderCangjieHumanEvalPlusCompactAuthority(
    result: CangjieHumanEvalPlusCompactResult): String {
    result.compactJson
}

private func ckbPlusCompactBuild(authorityRoot: String, datasetRoot: String,
    expectedCases: Int64, expectedTotal: Int64, expectedExecutable: Int64,
    expectedDefect: Int64): CangjieHumanEvalPlusCompactResult {
    let out = CangjieHumanEvalPlusCompactResult()
    let root = Path(authorityRoot)
    let source = ckbPlusCompactReadUtf8(root.join("source-lock.json"))
    if (source[0] != "ok") { out.diagnostic = source[0]; return out }
    let lock = ckbPlusCompactSourceLock(source[1], out)
    if (lock != "ok") { out.diagnostic = lock; return out }

    let summaryPath = root.join("projection-summary.json")
    let ledgerPath = root.join("canonical-output-hash-ledger.jsonl")
    let defectPath = root.join("projection-defects.jsonl")
    if (!ckbPlusCompactArtifactHash(summaryPath, out.summaryArtifactHash) ||
        !ckbPlusCompactArtifactHash(ledgerPath, out.ledgerArtifactHash) ||
        !ckbPlusCompactArtifactHash(defectPath, out.defectArtifactHash)) {
        out.diagnostic = "source_lock_artifact_hash_mismatch"; return out
    }
    let summary = ckbPlusCompactReadUtf8(summaryPath)
    if (summary[0] != "ok") { out.diagnostic = summary[0]; return out }
    let summaryDiagnostic = ckbPlusCompactSummary(summary[1], out, expectedCases,
        expectedTotal, expectedExecutable, expectedDefect)
    if (summaryDiagnostic != "ok") { out.diagnostic = summaryDiagnostic; return out }

    let defectEvidence = HashMap<String, CkbPlusCompactDefectEvidence>()
    let defectDiagnostic = ckbPlusCompactDefects(defectPath, out, defectEvidence,
        expectedDefect)
    if (defectDiagnostic != "ok") { out.diagnostic = defectDiagnostic; return out }
    let ledgerDiagnostic = ckbPlusCompactLedger(ledgerPath, out, defectEvidence,
        expectedTotal, expectedDefect)
    if (ledgerDiagnostic != "ok") { out.diagnostic = ledgerDiagnostic; return out }

    let manifestPath = root.join("tests-plus-manifest.json")
    let manifest = ckbPlusCompactReadUtf8(manifestPath)
    if (manifest[0] != "ok") { out.diagnostic = manifest[0]; return out }
    let actualManifestHash = benchmarkGapSha256(manifest[1]).replace("sha256:", "")
    if (actualManifestHash != out.testsManifestArtifactHash) {
        out.diagnostic = "source_lock_tests_manifest_hash_mismatch"; return out
    }
    out.testsManifestHash = "sha256:${actualManifestHash}"
    let testsDiagnostic = ckbPlusCompactTestsManifest(manifest[1], datasetRoot, out,
        expectedCases, expectedTotal, expectedExecutable, expectedDefect)
    if (testsDiagnostic != "ok") { out.diagnostic = testsDiagnostic; return out }

    out.caseCount = expectedCases
    out.total = expectedTotal
    out.executable = expectedExecutable
    out.defect = expectedDefect
    out.compactJson = ckbPlusCompactRender(out)
    out.authorityHash = benchmarkGapSha256(out.compactJson)
    out.ok = true
    out.diagnostic = "ok"
    out
}

private func ckbPlusCompactSourceLock(raw: String,
    out: CangjieHumanEvalPlusCompactResult): String {
    try {
        let object = JsonValue.fromStr(raw.trimAscii()).asObject()
        if (object.getFields().size != 13 ||
            ckbPlusString(object, "schemaVersion") != "ckb-humaneval-plus-source-lock-v1" ||
            ckbPlusString(object, "evaluatorCommit") != CKB_HUMANEVAL_PLUS_EVALUATOR_COMMIT ||
            ckbPlusString(object, "releaseRepository") != CKB_HUMANEVAL_PLUS_RELEASE_REPOSITORY ||
            ckbPlusString(object, "releaseTag") != CKB_HUMANEVAL_PLUS_RELEASE_TAG ||
            ckbPlusString(object, "releaseTagObject") != CKB_HUMANEVAL_PLUS_RELEASE_TAG_OBJECT ||
            ckbPlusString(object, "releaseCommit") != CKB_HUMANEVAL_PLUS_RELEASE_COMMIT ||
            ckbPlusString(object, "releaseAssetUrl") != CKB_HUMANEVAL_PLUS_RELEASE_URL ||
            ckbPlusString(object, "gzipSha256") != CKB_HUMANEVAL_PLUS_GZIP_HASH.replace("sha256:", "") ||
            ckbPlusString(object, "decompressedJsonlSha256") != CKB_HUMANEVAL_PLUS_JSONL_HASH.replace("sha256:", "")) {
            return "source_lock_identity_invalid"
        }
        let hashes = object.get("artifactHashes").getOrThrow().asObject()
        if (hashes.getFields().size != 4) { return "source_lock_schema_invalid" }
        out.ledgerArtifactHash = ckbPlusString(hashes, "canonical-output-hash-ledger.jsonl")
        out.defectArtifactHash = ckbPlusString(hashes, "projection-defects.jsonl")
        out.summaryArtifactHash = ckbPlusString(hashes, "projection-summary.json")
        out.testsManifestArtifactHash = ckbPlusString(hashes, "tests-plus-manifest.json")
        if (!ckbPlusBareHash(out.ledgerArtifactHash)) { return "source_lock_ledger_hash_invalid" }
        if (!ckbPlusBareHash(out.defectArtifactHash)) { return "source_lock_defect_hash_invalid" }
        if (!ckbPlusBareHash(out.summaryArtifactHash)) { return "source_lock_summary_hash_invalid" }
        if (!ckbPlusBareHash(out.testsManifestArtifactHash)) { return "source_lock_tests_hash_invalid" }
        let oracle = object.get("oracleSemantics").getOrThrow().asObject()
        let schemas = object.get("schemas").getOrThrow().asObject()
        if (oracle.getFields().size != 2 ||
            ckbPlusString(oracle, "id") != "heplus-fixed-core-v1" ||
            ckbPlusString(oracle, "definition") == "" || schemas.getFields().size != 6 ||
            ckbPlusString(schemas, "canonicalOutputHashLedger") != "ckb-humaneval-plus-canonical-output-hash-v1" ||
            ckbPlusString(schemas, "projectionDefects") != "ckb-humaneval-plus-projection-defect-v1" ||
            ckbPlusString(schemas, "projectionSummary") != "ckb-humaneval-plus-projection-summary-v1" ||
            ckbPlusString(schemas, "sourceLock") != "ckb-humaneval-plus-source-lock-v1" ||
            ckbPlusString(schemas, "taggedPythonValue") != "ckb-tagged-python-value-v1" ||
            ckbPlusString(schemas, "testsPlusManifest") != "ckb-humaneval-plus-tests-plus-manifest-v1") {
            return "source_lock_nested_schema_invalid"
        }
        let canonicalHash = object.get("sourceLockCanonicalHash").getOrThrow().asObject()
        let value = ckbPlusString(canonicalHash, "value")
        if (canonicalHash.getFields().size != 3 || ckbPlusString(canonicalHash, "algorithm") != "sha256" ||
            ckbPlusString(canonicalHash, "scope") != "canonical source-lock JSON with sourceLockCanonicalHash omitted" ||
            !ckbPlusBareHash(value)) { return "source_lock_self_hash_invalid" }
        let canonicalParts = raw.trimAscii().split(",\"sourceLockCanonicalHash\":")
        if (canonicalParts.size != 2 ||
            benchmarkGapSha256(canonicalParts[0] + "}\n").replace("sha256:", "") != value) {
            return "source_lock_self_hash_mismatch"
        }
        out.sourceLockHash = "sha256:${value}"
        "ok"
    } catch (_: Exception) { "source_lock_malformed_json" }
}

private func ckbPlusCompactArtifactHash(path: Path, expected: String): Bool {
    try {
        benchmarkGapSha256(String.fromUtf8(File.readFrom(path))).replace("sha256:", "") == expected
    } catch (_: Exception) { false }
}

private func ckbPlusCompactSummary(raw: String, out: CangjieHumanEvalPlusCompactResult,
    expectedCases: Int64, expectedTotal: Int64, expectedExecutable: Int64,
    expectedDefect: Int64): String {
    try {
        let object = JsonValue.fromStr(raw.trimAscii()).asObject()
        if (object.getFields().size != 14 ||
            ckbPlusString(object, "schemaVersion") != "ckb-humaneval-plus-projection-summary-v1" ||
            ckbPlusString(object, "sourceAssetSha256") != CKB_HUMANEVAL_PLUS_GZIP_HASH.replace("sha256:", "") ||
            ckbPlusInt(object, "caseCount") != expectedCases ||
            ckbPlusInt(object, "total") != expectedTotal ||
            ckbPlusInt(object, "executable") != expectedExecutable ||
            ckbPlusInt(object, "defect") != expectedDefect ||
            ckbPlusInt(object, "canonicalExceptions") != 0) {
            return "projection_summary_identity_or_count_invalid"
        }
        let cases = object.get("cases").getOrThrow().asArray().getItems()
        if (cases.size != expectedCases) { return "projection_summary_case_count_invalid" }
        for (index in 0..cases.size) {
            let item = cases[index].asObject()
            if (item.getFields().size != 9 || ckbPlusInt(item, "case") != index) {
                return "projection_summary_case_order_invalid"
            }
            let row = CangjieHumanEvalPlusCompactCase()
            row.caseIndex = index
            row.total = ckbPlusInt(item, "total")
            row.executable = ckbPlusInt(item, "executable")
            row.defect = ckbPlusInt(item, "defect")
            if (row.total != row.executable + row.defect || row.executable <= 0) {
                return "projection_summary_case_counts_invalid"
            }
            out.cases.add(row)
        }
        "ok"
    } catch (_: Exception) { "projection_summary_malformed_json" }
}

private func ckbPlusCompactDefects(path: Path, out: CangjieHumanEvalPlusCompactResult,
    evidence: HashMap<String, CkbPlusCompactDefectEvidence>, expectedDefect: Int64): String {
    var count: Int64 = 0
    var previousCase: Int64 = -1
    var previousIndex: Int64 = -1
    try {
        try (file = File(path, OpenMode.Read)) {
            let reader = StringReader(file)
            while (true) {
                let line = if (let Some(value) <- reader.readln()) { value } else { break }
                if (line == "") { continue }
                let object = JsonValue.fromStr(line).asObject()
                if (object.getFields().size != 7 ||
                    ckbPlusString(object, "schemaVersion") != "ckb-humaneval-plus-projection-defect-v1" ||
                    ckbPlusString(object, "oracleSemanticsId") != "heplus-fixed-core-v1") {
                    return "projection_defect_schema_invalid"
                }
                let caseIndex = ckbPlusInt(object, "case")
                let index = ckbPlusInt(object, "index")
                if (caseIndex < 0 || caseIndex >= out.cases.size || index < 0 ||
                    index >= out.cases[Int64(caseIndex)].total || caseIndex < previousCase ||
                    (caseIndex == previousCase && index <= previousIndex)) {
                    return "projection_defect_order_or_key_invalid"
                }
                let rawHash = ckbPlusString(object, "rawInputSha256")
                let outputHash = ckbPlusString(object, "canonicalOutputSha256")
                if (!ckbPlusBareHash(rawHash) || !ckbPlusBareHash(outputHash)) {
                    return "projection_defect_hash_invalid"
                }
                let reasons = object.get("reasons").getOrThrow().asArray().getItems()
                if (reasons.size == 0) { return "projection_defect_reason_missing" }
                for (reasonValue in reasons) {
                    let reason = reasonValue.asObject()
                    if (reason.getFields().size != 3 || !ckbPlusCompactReason(
                        ckbPlusString(reason, "stage"), ckbPlusString(reason, "reason")) ||
                        !ckbPlusString(reason, "path").startsWith("$") ||
                        ckbPlusString(reason, "path").toArray().size > 256) {
                        return "projection_defect_reason_invalid"
                    }
                }
                let key = "${caseIndex}|${index}"
                if (evidence.contains(key)) { return "projection_defect_duplicate" }
                let item = CkbPlusCompactDefectEvidence()
                item.inputHash = rawHash
                item.outputHash = outputHash
                item.evidenceHash = benchmarkGapSha256(line)
                evidence.add(key, item)
                previousCase = caseIndex
                previousIndex = index
                count += 1
            }
        }
    } catch (_: Exception) { return "projection_defect_invalid_encoding_or_json" }
    if (count != expectedDefect) { return "projection_defect_count_invalid" }
    "ok"
}

private func ckbPlusCompactLedger(path: Path, out: CangjieHumanEvalPlusCompactResult,
    defects: HashMap<String, CkbPlusCompactDefectEvidence>, expectedTotal: Int64,
    expectedDefect: Int64): String {
    var count: Int64 = 0
    var caseIndex: Int64 = 0
    var index: Int64 = 0
    var matchedDefects: Int64 = 0
    let caseDigests = ArrayList<SHA256>()
    for (_ in 0..out.cases.size) { caseDigests.add(SHA256()) }
    try {
        try (file = File(path, OpenMode.Read)) {
            let reader = StringReader(file)
            while (true) {
                let line = if (let Some(value) <- reader.readln()) { value } else { break }
                if (line == "") { continue }
                while (caseIndex < out.cases.size && index >= out.cases[caseIndex].total) {
                    caseIndex += 1; index = 0
                }
                let object = JsonValue.fromStr(line).asObject()
                if (caseIndex >= out.cases.size || object.getFields().size != 6 ||
                    ckbPlusInt(object, "case") != caseIndex || ckbPlusInt(object, "index") != index ||
                    ckbPlusString(object, "oracleSemanticsId") != "heplus-fixed-core-v1") {
                    return "output_hash_ledger_order_or_schema_invalid"
                }
                let inputHash = ckbPlusString(object, "inputSha256")
                let outputHash = ckbPlusString(object, "outputSha256")
                let outputType = ckbPlusString(object, "outputType")
                if (!ckbPlusBareHash(inputHash) || !ckbPlusBareHash(outputHash) ||
                    !ckbPlusOneOf(outputType, ["bool","dict","float","int","list","none","string","tuple"])) {
                    return "output_hash_ledger_value_invalid"
                }
                let key = "${caseIndex}|${index}"
                if (defects.contains(key)) {
                    let defect = defects[key]
                    if (defect.inputHash != inputHash || defect.outputHash != outputHash) {
                        return "projection_defect_ledger_evidence_mismatch"
                    }
                    out.cases[caseIndex].defectHash = benchmarkGapSha256(
                        out.cases[caseIndex].defectHash + defect.evidenceHash)
                    matchedDefects += 1
                }
                caseDigests[caseIndex].write((line + "\n").toArray())
                count += 1
                index += 1
            }
        }
    } catch (_: Exception) { return "output_hash_ledger_invalid_encoding_or_json" }
    if (count != expectedTotal || matchedDefects != expectedDefect) {
        return "output_hash_ledger_count_or_defect_coverage_invalid"
    }
    for (i in 0..out.cases.size) { out.cases[i].ledgerHash = ckbPlusCompactFinishHash(caseDigests[i]) }
    "ok"
}

private func ckbPlusCompactTestsManifest(raw: String, datasetRoot: String,
    out: CangjieHumanEvalPlusCompactResult, expectedCases: Int64, expectedTotal: Int64,
    expectedExecutable: Int64, expectedDefect: Int64): String {
    try {
        let object = JsonValue.fromStr(raw.trimAscii()).asObject()
        if (object.getFields().size != 12 ||
            ckbPlusString(object, "schemaVersion") != "ckb-humaneval-plus-tests-plus-manifest-v1" ||
            ckbPlusString(object, "sourceAssetSha256") != CKB_HUMANEVAL_PLUS_GZIP_HASH.replace("sha256:", "") ||
            ckbPlusString(object, "evaluatorCommit") != CKB_HUMANEVAL_PLUS_EVALUATOR_COMMIT ||
            ckbPlusString(object, "projectionDefectsSha256") != out.defectArtifactHash ||
            ckbPlusString(object, "directoryHashAlgorithm") != "sha256 over sorted relative files; for each file: relative.size:relative:bytes.size: then raw bytes" ||
            ckbPlusString(object, "directoryAggregateHashAlgorithm") != "sha256 over sorted cases; for each case: caseId.size:caseId:directorySha256.size:directorySha256" ||
            ckbPlusInt(object, "caseCount") != expectedCases ||
            ckbPlusInt(object, "sourceCount") != expectedTotal ||
            ckbPlusInt(object, "executableCount") != expectedExecutable ||
            ckbPlusInt(object, "defectCount") != expectedDefect) {
            return "tests_plus_manifest_identity_or_count_invalid"
        }
        let cases = object.get("cases").getOrThrow().asArray().getItems()
        if (cases.size != expectedCases) { return "tests_plus_manifest_case_count_invalid" }
        for (i in 0..cases.size) {
            let item = cases[i].asObject()
            if (item.getFields().size != 7 || ckbPlusString(item, "caseId") != ckbPlusCaseId(i) ||
                ckbPlusInt(item, "sourceCount") != out.cases[i].total ||
                ckbPlusInt(item, "executableCount") != out.cases[i].executable ||
                ckbPlusInt(item, "defectCount") != out.cases[i].defect) {
                return "tests_plus_manifest_case_identity_or_count_invalid"
            }
            let testHash = ckbPlusString(item, "testMainSha256")
            let cjpmHash = ckbPlusString(item, "tomlSha256")
            let directoryHash = ckbPlusString(item, "directorySha256")
            let testsRoot = Path(datasetRoot).join("cases/Cangjie-HumanEval/${ckbPlusCaseId(i)}/tests-plus")
            if (ckbPlusCompactFileHash(testsRoot.join("TestMain.cj")) != testHash ||
                ckbPlusCompactFileHash(testsRoot.join("cjpm.executable.toml")) != cjpmHash ||
                ckbPlusCompactDirectoryHash(testsRoot) != directoryHash) {
                return "tests_plus_manifest_file_drift"
            }
            out.cases[i].testMainSha256 = testHash
            out.cases[i].cjpmSha256 = cjpmHash
            out.cases[i].directorySha256 = directoryHash
        }
        if (ckbPlusString(object, "directoryAggregateSha256") !=
            ckbPlusCompactDirectoryAggregateHash(out.cases)) {
            return "tests_plus_manifest_directory_aggregate_invalid"
        }
        "ok"
    } catch (_: Exception) { "tests_plus_manifest_malformed_json" }
}

private func ckbPlusCompactRender(out: CangjieHumanEvalPlusCompactResult): String {
    let body = StringBuilder()
    for (row in out.cases) {
        body.append("{\"schemaVersion\":\"${CKB_HUMANEVAL_PLUS_COMPACT_SCHEMA}\"," +
            "\"caseId\":\"${ckbPlusCaseId(row.caseIndex)}\",\"sourceTaskId\":\"HumanEval/${row.caseIndex}\"," +
            "\"total\":${row.total},\"executable\":${row.executable},\"defect\":${row.defect}," +
            "\"ledgerHash\":\"${row.ledgerHash}\",\"defectHash\":\"${row.defectHash}\"," +
            "\"testMainSha256\":\"${row.testMainSha256}\",\"cjpmSha256\":\"${row.cjpmSha256}\"," +
            "\"directorySha256\":\"${row.directorySha256}\"}\n")
    }
    let bodyHash = benchmarkGapSha256(body.toString())
    body.append("{\"schemaVersion\":\"ckb-humaneval-plus-compact-authority-global-v1\"," +
        "\"sourceAssetHash\":\"${CKB_HUMANEVAL_PLUS_JSONL_HASH}\",\"caseCount\":${out.cases.size}," +
        "\"total\":${out.total},\"executable\":${out.executable},\"defect\":${out.defect}," +
        "\"sourceLockHash\":\"${out.sourceLockHash}\",\"ledgerArtifactHash\":\"sha256:${out.ledgerArtifactHash}\"," +
        "\"defectArtifactHash\":\"sha256:${out.defectArtifactHash}\",\"summaryArtifactHash\":\"sha256:${out.summaryArtifactHash}\"," +
        "\"testsManifestHash\":\"${out.testsManifestHash}\",\"caseSummariesHash\":\"${bodyHash}\"}\n")
    body.toString()
}

private func ckbPlusCompactReason(stage: String, reason: String): Bool {
    let input = ["EvalValue_integer_out_of_Int64_range", "EvalValue_nonempty_list_payload_unsupported",
        "EvalValue_nonempty_map_payload_unsupported", "expected_ArrayList_got_dict",
        "expected_ArrayList_got_string", "expected_Int64_got_bool", "expected_Int64_got_float",
        "expected_Int64_got_list", "expected_Int64_got_none", "expected_Int64_got_string",
        "integer_out_of_Int64_range"]
    let output = ["EvalValue_integer_out_of_Int64_range", "expected_Int64_got_bool",
        "expected_Int64_got_float", "expected_Int64_got_list", "expected_Int64_got_none",
        "expected_Int64_got_string", "integer_out_of_Int64_range"]
    (stage == "input" && ckbPlusOneOf(reason, input)) ||
        (stage == "output" && ckbPlusOneOf(reason, output))
}

private func ckbPlusCompactReadUtf8(path: Path): (String, String) {
    if (!exists(path)) { return ("compact_authority_input_missing", "") }
    try { ("ok", String.fromUtf8(File.readFrom(path))) }
    catch (_: Exception) { ("compact_authority_invalid_encoding", "") }
}

private func ckbPlusCompactFileHash(path: Path): String {
    try { benchmarkGapSha256(String.fromUtf8(File.readFrom(path))).replace("sha256:", "") }
    catch (_: Exception) { "" }
}

private func ckbPlusCompactDirectoryHash(root: Path): String {
    if (!exists(root)) { return "" }
    let files = ArrayList<String>()
    ckbPlusCompactCollectFiles(root, "", files)
    sort(files)
    let digest = SHA256()
    for (relative in files) {
        let bytes = try { File.readFrom(root.join(relative)) } catch (_: Exception) { return "" }
        digest.write("${relative.size}:${relative}:${bytes.size}:".toArray())
        digest.write(bytes)
    }
    ckbPlusCompactFinishHash(digest).replace("sha256:", "")
}

private func ckbPlusCompactDirectoryAggregateHash(
    cases: ArrayList<CangjieHumanEvalPlusCompactCase>): String {
    let digest = SHA256()
    for (row in cases) {
        let caseId = ckbPlusCaseId(row.caseIndex)
        digest.write("${caseId.size}:${caseId}:${row.directorySha256.size}:${row.directorySha256}".toArray())
    }
    ckbPlusCompactFinishHash(digest).replace("sha256:", "")
}

private func ckbPlusCompactCollectFiles(current: Path, prefix: String,
    files: ArrayList<String>): Unit {
    try {
        for (entry in Directory.readFrom(current)) {
            let relative = if (prefix == "") { entry.name } else { "${prefix}/${entry.name}" }
            if (entry.isDirectory()) { ckbPlusCompactCollectFiles(entry.path, relative, files) }
            else { files.add(relative) }
        }
    } catch (_: Exception) { () }
}

private func ckbPlusCompactFinishHash(digest: SHA256): String {
    let result = StringBuilder()
    for (byte in digest.finish()) {
        result.append(ckbPlusCompactHex(byte / UInt8(16)))
        result.append(ckbPlusCompactHex(byte % UInt8(16)))
    }
    "sha256:${result.toString()}"
}

private func ckbPlusCompactHex(value: UInt8): String {
    if (value < UInt8(10)) { "${value}" }
    else { ["a","b","c","d","e","f"][Int64(value - UInt8(10))] }
}

private func ckbPlusBareHash(value: String): Bool {
    if (value.size != 64) { return false }
    for (c in value.toRuneArray()) {
        if (!((c >= r'0' && c <= r'9') || (c >= r'a' && c <= r'f'))) { return false }
    }
    true
}

private func ckbPlusCompactAtomicWrite(path: Path, text: String, expectedHash: String): Bool {
    let temporary = path.parent.join(".compact-plus-authority.tmp")
    try {
        if (!exists(path.parent)) { Directory.create(path.parent, recursive: true) }
        if (exists(temporary)) { remove(temporary) }
        File.writeTo(temporary, text.toArray())
        let readback = String.fromUtf8(File.readFrom(temporary))
        if (readback != text || benchmarkGapSha256(readback) != expectedHash) {
            remove(temporary); return false
        }
        rename(temporary, to: path, overwrite: true)
        String.fromUtf8(File.readFrom(path)) == text
    } catch (_: Exception) {
        try { if (exists(temporary)) { remove(temporary) } } catch (_: Exception) { () }
        false
    }
}

private func ckbPlusCompactGitIgnoreAllowed(authorityRoot: String,
    datasetRoot: String, caseCount: Int64): Bool {
    let args = ArrayList<String>()
    args.add("check-ignore")
    args.add(Path(authorityRoot).join("tests-plus-manifest.json").toString())
    for (i in 0..caseCount) {
        let root = Path(datasetRoot).join(
            "cases/Cangjie-HumanEval/${ckbPlusCaseId(i)}/tests-plus")
        args.add(root.join("TestMain.cj").toString())
        args.add(root.join("cjpm.executable.toml").toString())
    }
    try { launch("git", args.toArray()).wait() == 1 } catch (_: Exception) { false }
}
