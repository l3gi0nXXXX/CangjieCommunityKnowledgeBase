package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.convert.Parsable
import std.fs.{Directory, File, Path, exists}
import stdx.encoding.json.*

public class CangjieEvalSupportSnapshot {
    public var ok: Bool = true
    public var schemaVersion: String = "ckb-eval-support-v1"
    public var datasetVersion: String = ""
    public var revision: Int64 = 1
    public var recordCount: Int64 = 0
    public var authorityHash: String = ""
    public var checksum: String = ""
    public var jsonl: String = ""
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class CangjieEvalSupportAuthorityLoadResult {
    public var ok: Bool = false
    public var diagnostic: String = "eval_support_authority_not_loaded"
    public var snapshot: CangjieEvalSupportSnapshot = CangjieEvalSupportSnapshot()
    public var records: ArrayList<CangjieTypedRecord> = ArrayList<CangjieTypedRecord>()

    public init() {}
}

public class CangjieEvalSupportPaths {
    public static let PROMPT: String = "prompt.md"
    public static let METADATA: String = "metadata.json"
    public static let EVAL_SUPPORT: String = "starter/src/eval_support.cj"
    public static let VISIBLE_TESTS: String = "tests/TestMain.cj"
}

public func extractEvalSupportRecords(caseRoot: String, version!: CangjieVersionResolution = cangjieDefaultEvalSupportResolution()): CangjieTypedRecordResult {
    let result = CangjieTypedRecordResult()
    let cleanRoot = caseRoot.trimAscii()
    if (!cangjieEvalSupportCaseRootAllowed(cleanRoot)) {
        result.addDiagnostic("forbidden_reference_solution_source")
        return result
    }
    let resolvedRoot = cangjieEvalSupportResolveCaseRoot(cleanRoot)
    if (resolvedRoot == "") {
        result.ok = false
        result.addDiagnostic("eval_support_case_root_not_found")
        return result
    }
    let caseId = cangjieCaseIdFromRoot(cleanRoot)
    cangjieAddEvalSupportFile(result, resolvedRoot, caseId, CangjieEvalSupportPaths.PROMPT, "prompt", "HumanEval prompt", version)
    cangjieAddEvalSupportFile(result, resolvedRoot, caseId, CangjieEvalSupportPaths.METADATA, "metadata", "HumanEval metadata", version)
    cangjieAddEvalSupportFile(result, resolvedRoot, caseId, CangjieEvalSupportPaths.EVAL_SUPPORT, "eval_support", "EvalValue and EvalEntry fixture types", version)
    cangjieAddEvalSupportFile(result, resolvedRoot, caseId, CangjieEvalSupportPaths.VISIBLE_TESTS, "visible_test_helpers", "Visible test helper types", version)
    if (result.records.size == 0) {
        result.ok = false
        if (result.diagnostics.size == 0) {
            result.diagnostics.add("no_eval_support_records")
        }
    }
    result
}

public func discoverCangjieHumanEvalCaseRoots(datasetRoot: String): ArrayList<String> {
    let roots = ArrayList<String>()
    let cleanRoot = datasetRoot.trimAscii()
    if (!cangjieEvalSupportDatasetRootAllowed(cleanRoot)) {
        return roots
    }
    let resolvedRoot = cangjieEvalSupportResolveCaseRoot(cleanRoot)
    if (resolvedRoot == "") {
        return roots
    }
    try {
        for (entry in Directory.readFrom(Path(resolvedRoot))) {
            if (entry.isDirectory() && entry.name.startsWith("CJ-HUMANEVAL-")) {
                cangjieInsertEvalCaseRoot(roots, "${entry.path}")
            }
        }
    } catch (_: Exception) {
        return roots
    }
    roots
}

public func extractAllEvalSupportRecords(datasetRoot: String, version!: CangjieVersionResolution = cangjieDefaultEvalSupportResolution()): CangjieTypedRecordResult {
    let result = CangjieTypedRecordResult()
    let cleanRoot = datasetRoot.trimAscii()
    if (!cangjieEvalSupportDatasetRootAllowed(cleanRoot)) {
        result.addDiagnostic("invalid_eval_support_dataset_root")
        return result
    }
    let roots = discoverCangjieHumanEvalCaseRoots(cleanRoot)
    if (roots.size == 0) {
        result.addDiagnostic("no_eval_support_case_roots")
        return result
    }
    for (root in roots) {
        let caseResult = extractEvalSupportRecords(root, version: version)
        for (diagnostic in caseResult.diagnostics) {
            result.diagnostics.add("${cangjieCaseIdFromRoot(root)}:${diagnostic}")
        }
        for (record in caseResult.records) {
            result.records.add(record)
        }
        result.ok = result.ok && caseResult.ok
    }
    let safety = validateEvalSupportRecordSafety(result.records)
    for (diagnostic in safety.diagnostics) {
        result.addDiagnostic(diagnostic)
    }
    if (result.records.size == 0 && result.diagnostics.size == 0) {
        result.addDiagnostic("no_eval_support_records")
    }
    result
}

public func extractEvalSupportRecordAt(datasetRoot: String, logicalPath: String, version!: CangjieVersionResolution = cangjieDefaultEvalSupportResolution()): CangjieTypedRecordResult {
    let result = CangjieTypedRecordResult()
    let cleanRoot = datasetRoot.trimAscii()
    let cleanPath = logicalPath.replace("\\", "/").trimAscii()
    let parts = cleanPath.split("/")
    if (!cangjieEvalSupportDatasetRootAllowed(cleanRoot) || parts.size < 2) { result.addDiagnostic("invalid_eval_support_logical_path"); return result }
    let caseId = parts[0]
    var relative = ""
    for (allowed in [CangjieEvalSupportPaths.PROMPT, CangjieEvalSupportPaths.METADATA, CangjieEvalSupportPaths.EVAL_SUPPORT, CangjieEvalSupportPaths.VISIBLE_TESTS]) { if (cleanPath == "${caseId}/${allowed}") { relative = allowed } }
    if (relative == "" || !caseId.startsWith("CJ-HUMANEVAL-") || caseId.contains("..") || !cangjieEvalSupportRelativePathAllowed(relative)) { result.addDiagnostic("invalid_eval_support_logical_path"); return result }
    let resolvedRoot = cangjieEvalSupportResolveCaseRoot("${cleanRoot}/${caseId}")
    if (resolvedRoot == "") { result.addDiagnostic("eval_support_case_root_not_found"); return result }
    let sourceFamily = if (relative == CangjieEvalSupportPaths.PROMPT) { "prompt" } else if (relative == CangjieEvalSupportPaths.METADATA) { "metadata" } else if (relative == CangjieEvalSupportPaths.EVAL_SUPPORT) { "eval_support" } else { "visible_test_helpers" }
    let title = if (relative == CangjieEvalSupportPaths.PROMPT) { "HumanEval prompt" } else if (relative == CangjieEvalSupportPaths.METADATA) { "HumanEval metadata" } else if (relative == CangjieEvalSupportPaths.EVAL_SUPPORT) { "EvalValue and EvalEntry fixture types" } else { "Visible test helper types" }
    cangjieAddEvalSupportFile(result, resolvedRoot, caseId, relative, sourceFamily, title, version)
    if (result.records.size != 1) { result.addDiagnostic("eval_support_logical_path_not_found") }
    result
}

public func validateEvalSupportRecordSafety(records: ArrayList<CangjieTypedRecord>): CangjieTypedRecordResult {
    let result = CangjieTypedRecordResult()
    for (record in records) {
        let value = "${record.sourceId}\n${record.path}\n${record.citation}".toAsciiLower().replace("\\", "/")
        let content = record.content.toAsciiLower()
        if (record.path.startsWith("/") || record.path.contains("..") || value.contains("/reference/") || value.contains("/hidden/") || value.contains("solution.cj") || value.contains("teacher-solutions") || value.contains("ckb-data") || content.contains("canonical_solution") || content.contains("@expect(") || content.contains("assert(") || content.contains("main():")) {
            result.addDiagnostic("forbidden_reference_solution_source:${record.sourceId}")
        }
    }
    result
}

public func buildVersionedEvalSupportSnapshot(datasetRoot: String, datasetVersion: String,
    revision!: Int64 = 1,
    version!: CangjieVersionResolution = cangjieDefaultEvalSupportResolution()): CangjieEvalSupportSnapshot {
    let snapshot = CangjieEvalSupportSnapshot()
    snapshot.datasetVersion = datasetVersion.trimAscii()
    snapshot.revision = revision
    if (!cangjieEvalSupportVersionPartAllowed(snapshot.datasetVersion) || revision < 1) {
        snapshot.ok = false
        snapshot.diagnostics.add("invalid_eval_support_snapshot_identity")
        return snapshot
    }
    let extracted = extractAllEvalSupportRecords(datasetRoot, version: version)
    if (!extracted.ok) {
        snapshot.ok = false
        for (diagnostic in extracted.diagnostics) { snapshot.diagnostics.add(diagnostic) }
        return snapshot
    }
    let safety = validateEvalSupportRecordSafety(extracted.records)
    if (!safety.ok) {
        snapshot.ok = false
        for (diagnostic in safety.diagnostics) { snapshot.diagnostics.add(diagnostic) }
        return snapshot
    }
    let out = StringBuilder()
    for (record in extracted.records) {
        out.append("{\"schemaVersion\":\"ckb-eval-support-v1\",\"datasetVersion\":\"")
        out.append(cangjieEvalSupportJsonEscape(snapshot.datasetVersion))
        out.append("\",\"revision\":${revision},\"sourceId\":\"")
        out.append(cangjieEvalSupportJsonEscape(record.sourceId))
        out.append("\",\"caseId\":\"")
        out.append(cangjieEvalSupportJsonEscape(record.caseId))
        out.append("\",\"sourceFamily\":\"")
        out.append(cangjieEvalSupportJsonEscape(record.sourceFamily))
        out.append("\",\"path\":\"")
        out.append(cangjieEvalSupportJsonEscape(record.path))
        out.append("\",\"contentHash\":\"")
        out.append(benchmarkGapSha256("${record.sourceId}\n${record.content}"))
        out.append("\",\"title\":\"")
        out.append(cangjieEvalSupportJsonEscape(record.title))
        out.append("\",\"citation\":\"")
        out.append(cangjieEvalSupportJsonEscape(record.citation))
        out.append("\",\"content\":\"")
        out.append(cangjieEvalSupportJsonEscape(record.content))
        out.append("\",\"targetVersion\":\"")
        out.append(cangjieEvalSupportJsonEscape(record.targetVersion))
        out.append("\"}\n")
    }
    snapshot.recordCount = extracted.records.size
    snapshot.jsonl = out.toString()
    snapshot.checksum = benchmarkGapSha256("${snapshot.schemaVersion}:${snapshot.datasetVersion}:${snapshot.revision}:${snapshot.jsonl}")
    snapshot.authorityHash = snapshot.checksum
    snapshot
}

public func validateVersionedEvalSupportSnapshot(snapshot: CangjieEvalSupportSnapshot): CangjieEvalSupportSnapshot {
    let result = CangjieEvalSupportSnapshot()
    result.schemaVersion = snapshot.schemaVersion
    result.datasetVersion = snapshot.datasetVersion
    result.revision = snapshot.revision
    result.recordCount = snapshot.recordCount
    result.authorityHash = snapshot.authorityHash
    result.checksum = snapshot.checksum
    result.jsonl = snapshot.jsonl
    if (snapshot.schemaVersion != "ckb-eval-support-v1" || !cangjieEvalSupportVersionPartAllowed(snapshot.datasetVersion) || snapshot.revision < 1) {
        result.ok = false; result.diagnostics.add("invalid_eval_support_snapshot_identity"); return result
    }
    if (!snapshot.authorityHash.startsWith("sha256:") || snapshot.authorityHash != snapshot.checksum ||
        snapshot.checksum != benchmarkGapSha256("${snapshot.schemaVersion}:${snapshot.datasetVersion}:${snapshot.revision}:${snapshot.jsonl}")) {
        result.ok = false; result.diagnostics.add("eval_support_snapshot_checksum_mismatch"); return result
    }
    var count: Int64 = 0
    let caseIds = ArrayList<String>()
    let familyKeys = ArrayList<String>()
    for (line in snapshot.jsonl.split("\n")) {
        let raw = line.trimAscii()
        if (raw == "") { continue }
        try {
            let object = JsonValue.fromStr(raw).asObject()
            let schema = cangjieEvalSupportJsonString(object, "schemaVersion")
            let version = cangjieEvalSupportJsonString(object, "datasetVersion")
            let path = cangjieEvalSupportJsonString(object, "path")
            let sourceId = cangjieEvalSupportJsonString(object, "sourceId")
            let contentHash = cangjieEvalSupportJsonString(object, "contentHash")
            let content = cangjieEvalSupportJsonString(object, "content")
            let title = cangjieEvalSupportJsonString(object, "title")
            let citation = cangjieEvalSupportJsonString(object, "citation")
            let caseId = cangjieEvalSupportJsonString(object, "caseId")
            let sourceFamily = cangjieEvalSupportJsonString(object, "sourceFamily")
            let rowRevision = cangjieEvalSupportJsonInt(object, "revision", 0)
            let safetyText = content.toAsciiLower()
            if (schema != snapshot.schemaVersion || version != snapshot.datasetVersion || rowRevision != snapshot.revision || sourceId == "" || title == "" || citation == "" || caseId == "" || !sourceId.contains(caseId) || !citation.startsWith(caseId + ":") || !cangjieEvalSupportRelativePathAllowed(path) || contentHash != benchmarkGapSha256("${sourceId}\n${content}") || safetyText.contains("canonical_solution") || safetyText.contains("@expect(") || safetyText.contains("assert(") || safetyText.contains("main():")) {
                result.ok = false; result.diagnostics.add("eval_support_snapshot_record_invalid"); return result
            }
            if (!cangjieEvalSupportKnownFamily(sourceFamily)) {
                result.ok = false; result.diagnostics.add("eval_support_snapshot_family_unknown"); return result
            }
            let familyKey = "${caseId}:${sourceFamily}"
            if (familyKeys.contains(familyKey)) {
                result.ok = false; result.diagnostics.add("eval_support_snapshot_family_duplicate"); return result
            }
            familyKeys.add(familyKey)
            if (!caseIds.contains(caseId)) { caseIds.add(caseId) }
            count += 1
        } catch (_: Exception) { result.ok = false; result.diagnostics.add("malformed_eval_support_snapshot"); return result }
    }
    if (count != snapshot.recordCount) { result.ok = false; result.diagnostics.add("eval_support_snapshot_count_mismatch"); return result }
    if (caseIds.size == 0) { result.ok = false; result.diagnostics.add("eval_support_snapshot_no_cases"); return result }
    for (caseId in caseIds) {
        for (family in ["prompt", "metadata", "eval_support", "visible_test_helpers"]) {
            if (!familyKeys.contains("${caseId}:${family}")) {
                result.ok = false; result.diagnostics.add("eval_support_snapshot_family_missing:${caseId}:${family}"); return result
            }
        }
    }
    result
}

private func cangjieEvalSupportKnownFamily(sourceFamily: String): Bool {
    sourceFamily == "prompt" || sourceFamily == "metadata" || sourceFamily == "eval_support" ||
        sourceFamily == "visible_test_helpers"
}

public func cangjieEvalSupportAuthoritySnapshotPath(): String {
    "metadata/eval-authority/first-init/snapshot.jsonl"
}

public func cangjieEvalSupportAuthorityManifestPath(): String {
    "metadata/eval-authority/first-init/manifest.ckb"
}

public func persistVersionedEvalSupportSnapshot(store: FileKnowledgeStore,
    snapshot: CangjieEvalSupportSnapshot): Bool {
    let validated = validateVersionedEvalSupportSnapshot(snapshot)
    if (!snapshot.ok || !validated.ok) {
        return false
    }
    let manifest = StringBuilder()
    manifest.append("schemaVersion=${snapshot.schemaVersion}\n")
    manifest.append("datasetVersion=${snapshot.datasetVersion}\n")
    manifest.append("revision=${snapshot.revision}\n")
    manifest.append("recordCount=${snapshot.recordCount}\n")
    manifest.append("authorityHash=${snapshot.authorityHash}\n")
    manifest.append("checksum=${snapshot.checksum}\n")
    try {
        store.writeLinesAtomically(cangjieEvalSupportAuthoritySnapshotPath(), snapshot.jsonl)
        store.writeLinesAtomically(cangjieEvalSupportAuthorityManifestPath(), manifest.toString())
        return store.readText(cangjieEvalSupportAuthoritySnapshotPath()) == snapshot.jsonl &&
            store.readText(cangjieEvalSupportAuthorityManifestPath()) == manifest.toString()
    } catch (_: Exception) {
        return false
    }
}

public func loadVersionedEvalSupportAuthority(store: FileKnowledgeStore): CangjieEvalSupportAuthorityLoadResult {
    let result = CangjieEvalSupportAuthorityLoadResult()
    let snapshotPath = store.root.join(cangjieEvalSupportAuthoritySnapshotPath())
    let manifestPath = store.root.join(cangjieEvalSupportAuthorityManifestPath())
    if (!exists(snapshotPath) || !exists(manifestPath)) {
        result.diagnostic = "eval_support_authority_not_found"
        return result
    }
    let snapshotText = try {
        String.fromUtf8(File.readFrom(snapshotPath))
    } catch (_: Exception) {
        result.diagnostic = "eval_support_authority_invalid_response_encoding"
        return result
    }
    let manifestText = try {
        String.fromUtf8(File.readFrom(manifestPath))
    } catch (_: Exception) {
        result.diagnostic = "eval_support_authority_manifest_invalid_response_encoding"
        return result
    }
    let snapshot = CangjieEvalSupportSnapshot()
    snapshot.schemaVersion = cangjieEvalSupportManifestField(manifestText, "schemaVersion")
    snapshot.datasetVersion = cangjieEvalSupportManifestField(manifestText, "datasetVersion")
    snapshot.revision = cangjieEvalSupportManifestInt(manifestText, "revision", 0)
    snapshot.recordCount = cangjieEvalSupportManifestInt(manifestText, "recordCount", -1)
    snapshot.authorityHash = cangjieEvalSupportManifestField(manifestText, "authorityHash")
    snapshot.checksum = cangjieEvalSupportManifestField(manifestText, "checksum")
    snapshot.jsonl = snapshotText
    let validated = validateVersionedEvalSupportSnapshot(snapshot)
    if (!validated.ok) {
        result.diagnostic = if (validated.diagnostics.size > 0) { validated.diagnostics[0] } else { "eval_support_authority_invalid" }
        return result
    }
    for (line in snapshotText.split("\n")) {
        let raw = line.trimAscii(); if (raw == "") { continue }
        try {
            let object = JsonValue.fromStr(raw).asObject()
            let record = CangjieTypedRecord()
            record.recordKind = CangjieTypedRecordKinds.EVAL_SUPPORT
            record.sourceId = cangjieEvalSupportJsonString(object, "sourceId")
            record.caseId = cangjieEvalSupportJsonString(object, "caseId")
            record.sourceFamily = cangjieEvalSupportJsonString(object, "sourceFamily")
            record.path = cangjieEvalSupportJsonString(object, "path")
            record.contentHash = cangjieEvalSupportJsonString(object, "contentHash")
            record.title = cangjieEvalSupportJsonString(object, "title")
            record.citation = cangjieEvalSupportJsonString(object, "citation")
            record.content = cangjieEvalSupportJsonString(object, "content")
            record.targetVersion = cangjieEvalSupportJsonString(object, "targetVersion")
            record.sourceSet = CangjieSourceSets.EVAL_SUPPORT
            record.sourceRef = snapshot.datasetVersion
            record.refKind = "local"
            record.trustLevel = TrustLevels.OFFICIAL
            record.reviewState = ReviewStates.TRUSTED
            result.records.add(record)
        } catch (_: Exception) {
            result.records.clear(); result.diagnostic = "malformed_eval_support_snapshot"
            return result
        }
    }
    result.ok = result.records.size == snapshot.recordCount
    result.diagnostic = if (result.ok) { "ok" } else { "eval_support_snapshot_count_mismatch" }
    result.snapshot = snapshot
    result
}

private func cangjieEvalSupportManifestField(text: String, key: String): String {
    let prefix = "${key}="
    var found = ""
    for (line in text.split("\n")) {
        if (line.startsWith(prefix)) {
            if (found != "") { return "" }
            found = line.replace(prefix, "").trimAscii()
        }
    }
    found
}

private func cangjieEvalSupportManifestInt(text: String, key: String, fallback: Int64): Int64 {
    try { Int64.parse(cangjieEvalSupportManifestField(text, key)) } catch (_: Exception) { fallback }
}

private func cangjieEvalSupportJsonString(object: JsonObject, field: String): String {
    match (object.get(field)) { case Some(value) => value.asString().getValue(); case None => "" }
}

private func cangjieEvalSupportJsonInt(object: JsonObject, field: String, fallback: Int64): Int64 {
    match (object.get(field)) { case Some(value) => try { Int64.parse(value.toString()) } catch (_: Exception) { fallback }; case None => fallback }
}

private func cangjieEvalSupportVersionPartAllowed(value: String): Bool {
    let chars = value.toRuneArray()
    if (chars.size == 0 || chars.size > 256) { return false }
    for (ch in chars) {
        let alphaNumeric = (ch >= r'a' && ch <= r'z') || (ch >= r'A' && ch <= r'Z') || (ch >= r'0' && ch <= r'9')
        if (!alphaNumeric && ch != r'-' && ch != r'_' && ch != r'.') { return false }
    }
    true
}

private func cangjieEvalSupportJsonEscape(value: String): String {
    let out = StringBuilder()
    for (ch in value.toRuneArray()) {
        if (ch == r'\\') { out.append("\\\\") }
        else if (ch == r'\"') { out.append("\\\"") }
        else if (ch == r'\n') { out.append("\\n") }
        else if (ch == r'\r') { out.append("\\r") }
        else if (ch == r'\t') { out.append("\\t") }
        else { out.append(ch) }
    }
    out.toString()
}

public func runCangjieTypedIngestSmoke(args: Array<String>): Int64 {
    let docsRoot = cangjieTypedSmokeArg(args, "--docs-root")
    let caseRoot = cangjieTypedSmokeArg(args, "--case-root")
    if (docsRoot == "" || caseRoot == "") {
        println("usage error: cangjie-typed-ingest-smoke requires --docs-root <path> --case-root <path>")
        return 2
    }
    let version = resolveCangjieVersion(cangjieVersionSelector(targetVersion: "1.0.0", sourceSet: CangjieSourceSets.ALL), defaultCangjieVersionManifest())
    let docs = scanCangjieDocsRoot(docsRoot, version)
    let eval = extractEvalSupportRecords(caseRoot)
    let docsOk = docs.ok && cangjieTypedSmokeCount(docs, CangjieTypedRecordKinds.DOC_SECTION) > 0
    let toolsOk = cangjieTypedSmokeCount(docs, CangjieTypedRecordKinds.TOOL_MANUAL) > 0
    let evalOk = eval.ok && cangjieTypedSmokeCount(eval, CangjieTypedRecordKinds.EVAL_SUPPORT) >= 3
    let ok = docsOk && toolsOk && evalOk
    println("typed-ingest-smoke ok=${ok}")
    println("docsRecords=${docs.records.size} docSections=${cangjieTypedSmokeCount(docs, CangjieTypedRecordKinds.DOC_SECTION)} toolManuals=${cangjieTypedSmokeCount(docs, CangjieTypedRecordKinds.TOOL_MANUAL)} docsDiagnostics=${cangjieTypedSmokeDiagnostics(docs)}")
    println("evalRecords=${eval.records.size} evalSupportRecords=${cangjieTypedSmokeCount(eval, CangjieTypedRecordKinds.EVAL_SUPPORT)} evalDiagnostics=${cangjieTypedSmokeDiagnostics(eval)}")
    if (ok) { 0 } else { 1 }
}

public func cangjieEvalVisibleTestHelpersOnly(text: String): String {
    let parts = text.split("\nmain")
    if (parts.size == 0) {
        return text
    }
    parts[0]
}

private class CangjieEvalSupportReadResult {
    var ok: Bool = false
    var status: String = "not_started"
    var text: String = ""

    init() {}
}

private func cangjieAddEvalSupportFile(result: CangjieTypedRecordResult, caseRoot: String, caseId: String, relative: String, sourceFamily: String, title: String, version: CangjieVersionResolution): Unit {
    if (!cangjieEvalSupportRelativePathAllowed(relative)) {
        result.addDiagnostic("forbidden_reference_solution_source")
        return
    }
    let read = cangjieReadEvalSupportText(Path(caseRoot).join(relative))
    if (!read.ok) {
        result.ok = false
        result.diagnostics.add("${read.status}:${relative}")
        return
    }
    var content = read.text
    if (relative == CangjieEvalSupportPaths.VISIBLE_TESTS) {
        content = cangjieEvalVisibleTestHelpersOnly(read.text)
    }
    if (content.trimAscii() == "") {
        result.ok = false
        result.diagnostics.add("empty_eval_support_source:${relative}")
        return
    }
    let record = CangjieTypedRecord()
    record.recordKind = CangjieTypedRecordKinds.EVAL_SUPPORT
    record.sourceId = "eval-support-${caseId}-${sourceFamily}"
    record.title = "${title}: ${caseId}"
    record.content = content
    record.citation = "${caseId}:${relative}"
    record.sourceSet = CangjieSourceSets.EVAL_SUPPORT
    record.sourceFamily = sourceFamily
    record.path = relative
    record.heading = title
    record.sectionId = "${caseId}#${sourceFamily}"
    record.caseId = caseId
    record.contentHash = cangjieTypedRecordContentHash(record.sourceId, record.content)
    let metadata = cangjieEvalSupportVersionMetadata(version)
    record.versionResolutionId = metadata.versionResolutionId
    record.targetVersion = metadata.targetVersion
    record.sourceRef = metadata.sourceRef
    record.refKind = metadata.refKind
    record.resolvedCommit = metadata.resolvedCommit
    record.trustLevel = TrustLevels.OFFICIAL
    record.reviewState = ReviewStates.TRUSTED
    result.records.add(record)
}

private class CangjieEvalSupportVersionMetadata {
    var targetVersion: String = cangjieDefaultTargetVersion()
    var sourceRef: String = "release-1.0.0"
    var refKind: String = "branch"
    var resolvedCommit: String = "offline-baseline-eval"
    var versionResolutionId: String = "cangjie-1.0.0-eval-support-release-1.0.0"

    init() {}
}

private func cangjieEvalSupportVersionMetadata(version: CangjieVersionResolution): CangjieEvalSupportVersionMetadata {
    let metadata = CangjieEvalSupportVersionMetadata()
    metadata.targetVersion = if (version.targetVersion.trimAscii() == "") { cangjieDefaultTargetVersion() } else { version.targetVersion.trimAscii() }
    if (version.versionResolutionId.trimAscii() != "") {
        metadata.versionResolutionId = version.versionResolutionId.trimAscii()
    }
    if (version.sources.size > 0) {
        let source = version.sources[0]
        if (source.sourceRef.trimAscii() != "") {
            metadata.sourceRef = source.sourceRef.trimAscii()
        }
        if (source.refKind.trimAscii() != "") {
            metadata.refKind = source.refKind.trimAscii()
        }
        if (source.resolvedCommit.trimAscii() != "") {
            metadata.resolvedCommit = source.resolvedCommit.trimAscii()
        }
    }
    metadata
}

private func cangjieDefaultEvalSupportResolution(): CangjieVersionResolution {
    resolveCangjieVersion(cangjieVersionSelector(targetVersion: cangjieDefaultTargetVersion(), sourceSet: CangjieSourceSets.EVAL_SUPPORT), defaultCangjieVersionManifest())
}

private func cangjieEvalSupportCaseRootAllowed(root: String): Bool {
    if (root == "" || root.contains("\u{0}") || root.contains("..")) {
        return false
    }
    let lower = root.toAsciiLower().replace("\\", "/")
    if (lower.contains("/reference/") || lower.endsWith("/reference") || lower.contains("/hidden/") || lower.endsWith("/hidden")) {
        return false
    }
    true
}

private func cangjieEvalSupportDatasetRootAllowed(root: String): Bool {
    if (root == "" || root.contains("\u{0}") || root.contains("..")) {
        return false
    }
    let lower = root.toAsciiLower().replace("\\", "/")
    if (lower.contains("/reference/") || lower.endsWith("/reference") || lower.contains("/hidden/") || lower.endsWith("/hidden") || lower.contains("/.ssh") || lower.contains("/.config")) {
        return false
    }
    cangjieEvalSupportResolveCaseRoot(root) != ""
}

private func cangjieInsertEvalCaseRoot(out: ArrayList<String>, value: String): Unit {
    var i: Int64 = 0
    while (i < out.size) {
        if (out[i] > value) {
            out.add(value, at: i)
            return
        }
        if (out[i] == value) {
            return
        }
        i += 1
    }
    out.add(value)
}

private func cangjieEvalSupportResolveCaseRoot(root: String): String {
    if (exists(Path(root))) {
        return root
    }
    let normalized = root.replace("\\", "/")
    if (normalized.startsWith("test/cangjie_eval/")) {
        let candidate = normalized.replace("test/cangjie_eval/", "cangjie_eval/")
        if (exists(Path(candidate))) {
            return candidate
        }
    }
    ""
}

private func cangjieEvalSupportRelativePathAllowed(relative: String): Bool {
    let lower = relative.trimAscii().toAsciiLower().replace("\\", "/")
    if (lower == "" || lower.startsWith("/") || lower.contains("..")) {
        return false
    }
    !(lower.contains("/reference/") || lower.endsWith("/reference") || lower.contains("/hidden/") || lower.endsWith("/hidden") || lower.contains("solution.cj"))
}

private func cangjieReadEvalSupportText(path: Path): CangjieEvalSupportReadResult {
    let result = CangjieEvalSupportReadResult()
    if (!exists(path)) {
        result.status = "eval_support_file_not_found"
        return result
    }
    try {
        let bytes = File.readFrom(path)
        if (!cangjieEvalSupportUtf8Valid(bytes)) {
            result.status = "invalid_eval_support_encoding"
            return result
        }
        result.text = String.fromUtf8(bytes)
        result.ok = true
        result.status = "ok"
    } catch (_: Exception) {
        result.status = "invalid_eval_support_encoding"
        result.text = ""
    }
    result
}

private func cangjieEvalSupportUtf8Valid(bytes: Array<UInt8>): Bool {
    var i: Int64 = 0
    while (i < bytes.size) {
        let first = bytes[i]
        if (first <= 0x7f) {
            i += 1
            continue
        }
        var continuationCount: Int64 = 0
        if (first >= 0xc2 && first <= 0xdf) {
            continuationCount = 1
        } else if (first >= 0xe0 && first <= 0xef) {
            continuationCount = 2
        } else if (first >= 0xf0 && first <= 0xf4) {
            continuationCount = 3
        } else {
            return false
        }
        if (i + continuationCount >= bytes.size) {
            return false
        }
        var offset: Int64 = 1
        while (offset <= continuationCount) {
            let next = bytes[i + offset]
            if (next < 0x80 || next > 0xbf) {
                return false
            }
            offset += 1
        }
        let second = bytes[i + 1]
        if ((first == 0xe0 && second < 0xa0) || (first == 0xed && second > 0x9f) ||
            (first == 0xf0 && second < 0x90) || (first == 0xf4 && second > 0x8f)) {
            return false
        }
        i += continuationCount + 1
    }
    true
}

private func cangjieCaseIdFromRoot(root: String): String {
    let parts = root.replace("\\", "/").split("/")
    if (parts.size == 0) {
        return "unknown-case"
    }
    let leaf = parts[parts.size - 1].trimAscii()
    if (leaf == "") { "unknown-case" } else { leaf }
}

private func cangjieTypedSmokeArg(args: Array<String>, name: String): String {
    var i: Int64 = 0
    while (i < args.size) {
        if (args[i] == name && i + 1 < args.size) {
            return args[i + 1].trimAscii()
        }
        i += 1
    }
    ""
}

private func cangjieTypedSmokeCount(result: CangjieTypedRecordResult, kind: String): Int64 {
    var count: Int64 = 0
    for (record in result.records) {
        if (record.recordKind == kind) {
            count += 1
        }
    }
    count
}

private func cangjieTypedSmokeDiagnostics(result: CangjieTypedRecordResult): String {
    if (result.diagnostics.size == 0) {
        return "none"
    }
    let out = StringBuilder()
    for (diagnostic in result.diagnostics) {
        if (out.toString() != "") {
            out.append(",")
        }
        out.append(diagnostic)
    }
    out.toString()
}
