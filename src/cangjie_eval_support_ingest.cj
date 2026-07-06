package cangjie_community_knowledge_base

import std.fs.{File, Path, exists}

public class CangjieEvalSupportPaths {
    public static let PROMPT: String = "prompt.md"
    public static let METADATA: String = "metadata.json"
    public static let EVAL_SUPPORT: String = "starter/src/eval_support.cj"
    public static let VISIBLE_TESTS: String = "tests/TestMain.cj"
}

public func extractEvalSupportRecords(caseRoot: String): CangjieTypedRecordResult {
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
    cangjieAddEvalSupportFile(result, resolvedRoot, caseId, CangjieEvalSupportPaths.PROMPT, "prompt", "HumanEval prompt")
    cangjieAddEvalSupportFile(result, resolvedRoot, caseId, CangjieEvalSupportPaths.METADATA, "metadata", "HumanEval metadata")
    cangjieAddEvalSupportFile(result, resolvedRoot, caseId, CangjieEvalSupportPaths.EVAL_SUPPORT, "eval_support", "EvalValue and EvalEntry fixture types")
    cangjieAddEvalSupportFile(result, resolvedRoot, caseId, CangjieEvalSupportPaths.VISIBLE_TESTS, "visible_test_helpers", "Visible test helper types")
    if (result.records.size == 0) {
        result.ok = false
        if (result.diagnostics.size == 0) {
            result.diagnostics.add("no_eval_support_records")
        }
    }
    result
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

private func cangjieAddEvalSupportFile(result: CangjieTypedRecordResult, caseRoot: String, caseId: String, relative: String, sourceFamily: String, title: String): Unit {
    if (!cangjieEvalSupportRelativePathAllowed(relative)) {
        result.addDiagnostic("forbidden_reference_solution_source")
        return
    }
    let read = cangjieReadEvalSupportText(Path(caseRoot).join(relative))
    if (!read.ok) {
        result.diagnostics.add("${read.status}:${relative}")
        return
    }
    var content = read.text
    if (relative == CangjieEvalSupportPaths.VISIBLE_TESTS) {
        content = cangjieEvalVisibleTestHelpersOnly(read.text)
    }
    if (content.trimAscii() == "") {
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
    record.versionResolutionId = "cangjie-1.0.0-eval-support-release-1.0.0"
    record.targetVersion = cangjieDefaultTargetVersion()
    record.sourceRef = "release-1.0.0"
    record.refKind = "branch"
    record.resolvedCommit = "offline-baseline-eval"
    record.trustLevel = TrustLevels.OFFICIAL
    record.reviewState = ReviewStates.TRUSTED
    result.records.add(record)
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
        result.text = String.fromUtf8(File.readFrom(path))
        result.ok = true
        result.status = "ok"
    } catch (_: Exception) {
        result.status = "invalid_eval_support_encoding"
        result.text = ""
    }
    result
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
