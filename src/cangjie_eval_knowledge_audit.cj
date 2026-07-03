package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.convert.Parsable
import std.fs.{File, Path, exists}

public class CkbCdGapAuditGroups {
    public static let C: String = "C-ckb-mcp-stdio"
    public static let D: String = "D-ckb-mcp-http"
}

public class CkbCdGapAuditOptions {
    public var runRoot: String = ""
    public var manifestPath: String = "test/cangjie_eval/cangjie_humaneval_manifest.jsonl"
    public var format: String = "markdown"
    public var help: Bool = false

    public init() {}
}

public class CkbCdGapAuditResultRow {
    public var ok: Bool = false
    public var diagnostic: String = ""
    public var raw: String = ""
    public var caseId: String = ""
    public var group: String = ""
    public var unitPassAt1: Bool = false
    public var protocolViolation: Bool = false
    public var firstClaudeExitCode: Int64 = -1
    public var claudeExitCode: Int64 = -1
    public var testExitCode: Int64 = -1
    public var failureType: String = ""

    public init() {}
}

public class CkbCdGapAuditCaseSummary {
    public var caseId: String = ""
    public var cStatus: String = "missing_result"
    public var dStatus: String = "missing_result"
    public var cFailureType: String = ""
    public var dFailureType: String = ""
    public var tags: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class CkbCdGapTagCount {
    public var tag: String = ""
    public var count: Int64 = 0

    public init(tag: String, count: Int64) {
        this.tag = tag
        this.count = count
    }
}

public class CkbCdGapAuditSummary {
    public var ok: Bool = true
    public var runRoot: String = ""
    public var manifestPath: String = ""
    public var manifestCaseCount: Int64 = 0
    public var parsedResultRows: Int64 = 0
    public var cTotal: Int64 = 0
    public var dTotal: Int64 = 0
    public var cPassAt1: Int64 = 0
    public var dPassAt1: Int64 = 0
    public var cdFailureUnion: Int64 = 0
    public var cdDualFailure: Int64 = 0
    public var cOnlyFailure: Int64 = 0
    public var dOnlyFailure: Int64 = 0
    public var diagnostics: ArrayList<String> = ArrayList<String>()
    public var cases: ArrayList<CkbCdGapAuditCaseSummary> = ArrayList<CkbCdGapAuditCaseSummary>()
    public var tagCounts: ArrayList<CkbCdGapTagCount> = ArrayList<CkbCdGapTagCount>()

    public init() {}

    public func addDiagnostic(message: String): Unit {
        this.ok = false
        this.diagnostics.add(message)
    }
}

public func parseCkbCdGapAuditOptions(args: Array<String>): CkbCdGapAuditOptions {
    let options = CkbCdGapAuditOptions()
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "cangjie-eval-knowledge-audit") {
            i += 1
            continue
        }
        if (arg == "--help" || arg == "-h") {
            options.help = true
            i += 1
            continue
        }
        if ((arg == "--run-root" || arg == "--run") && i + 1 < args.size) {
            options.runRoot = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--manifest" && i + 1 < args.size) {
            options.manifestPath = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--format" && i + 1 < args.size) {
            options.format = args[i + 1].trimAscii()
            i += 2
            continue
        }
        i += 1
    }
    options
}

public func runCangjieEvalKnowledgeAudit(args: Array<String>): Int64 {
    let options = parseCkbCdGapAuditOptions(args)
    if (options.help) {
        print(ckbCdGapAuditUsage())
        return 0
    }
    if (options.runRoot == "") {
        println("usage error: cangjie-eval-knowledge-audit requires --run-root <path>")
        return 2
    }
    let summary = auditCkbCdKnowledgeGapsFromFiles(options.runRoot, options.manifestPath)
    if (options.format == "json") {
        print(renderCkbCdGapAuditJson(summary))
    } else {
        print(renderCkbCdGapAuditMarkdown(summary))
    }
    if (summary.ok) { 0 } else { 1 }
}

public func auditCkbCdKnowledgeGapsFromFiles(runRoot: String, manifestPath: String): CkbCdGapAuditSummary {
    let summary = CkbCdGapAuditSummary()
    summary.runRoot = runRoot
    summary.manifestPath = manifestPath
    if (!exists(Path(runRoot))) {
        summary.addDiagnostic("run_root_not_found:${runRoot}")
        return summary
    }
    let resultsPath = "${runRoot}/results.jsonl"
    if (!exists(Path(resultsPath))) {
        summary.addDiagnostic("results_not_found:${resultsPath}")
        return summary
    }
    if (!exists(Path(manifestPath))) {
        summary.addDiagnostic("manifest_not_found:${manifestPath}")
        return summary
    }
    auditCkbCdKnowledgeGapsFromText(ckbCdGapReadText(resultsPath), ckbCdGapReadText(manifestPath), runRoot, manifestPath)
}

public func auditCkbCdKnowledgeGapsFromText(resultsText: String, manifestText: String, runRoot: String, manifestPath: String): CkbCdGapAuditSummary {
    let manifest = parseCangjieEvalManifest(manifestText)
    let rows = parseCkbCdGapAuditResults(resultsText)
    summarizeCdKnowledgeGaps(rows, manifest, runRoot, manifestPath)
}

public func parseCkbCdGapAuditResults(text: String): ArrayList<CkbCdGapAuditResultRow> {
    let rows = ArrayList<CkbCdGapAuditResultRow>()
    for (line in text.split("\n")) {
        if (line.trimAscii() == "") {
            continue
        }
        rows.add(parseCkbCdGapAuditResultLine(line))
    }
    rows
}

public func parseCkbCdGapAuditResultLine(line: String): CkbCdGapAuditResultRow {
    let row = CkbCdGapAuditResultRow()
    let raw = line.trimAscii()
    row.raw = raw
    if (raw == "" || !raw.startsWith("{") || !raw.endsWith("}")) {
        row.diagnostic = "malformed_result_row"
        return row
    }
    row.caseId = ckbCdGapJsonStringField(raw, "caseId").trimAscii()
    row.group = ckbCdGapJsonStringField(raw, "group").trimAscii()
    row.unitPassAt1 = ckbCdGapJsonBoolField(raw, "unitPassAt1")
    row.protocolViolation = ckbCdGapJsonBoolField(raw, "protocolViolation")
    row.firstClaudeExitCode = ckbCdGapJsonIntField(raw, "firstClaudeExitCode", -1)
    row.claudeExitCode = ckbCdGapJsonIntField(raw, "claudeExitCode", -1)
    row.testExitCode = ckbCdGapJsonIntField(raw, "testExitCode", -1)
    row.failureType = ckbCdGapJsonStringField(raw, "failureType").trimAscii()
    if (row.caseId == "" || row.group == "") {
        row.diagnostic = "missing_result_field"
        return row
    }
    if (!ckbCdGapSupportedGroup(row.group)) {
        row.diagnostic = "unsupported_group"
        return row
    }
    row.ok = true
    row
}

public func classifyPassAt1(row: CkbCdGapAuditResultRow): String {
    if (row.unitPassAt1) {
        return "ok"
    }
    if (row.protocolViolation) {
        return "protocol_violation"
    }
    if (row.failureType == "timeout" || row.firstClaudeExitCode == 124 || row.claudeExitCode == 124) {
        return "timeout"
    }
    if (row.failureType == "unit_failure" || (row.firstClaudeExitCode == 0 && row.testExitCode != 0)) {
        return "unit_failure"
    }
    if (row.failureType != "" && row.failureType != "none") {
        return row.failureType
    }
    "compile_error"
}

public func summarizeCdKnowledgeGaps(
    rows: ArrayList<CkbCdGapAuditResultRow>,
    manifest: CangjieEvalManifestSummary,
    runRoot: String,
    manifestPath: String
): CkbCdGapAuditSummary {
    let summary = CkbCdGapAuditSummary()
    summary.runRoot = runRoot
    summary.manifestPath = manifestPath
    summary.manifestCaseCount = manifest.cases.size
    if (manifest.invalidLines > 0) {
        summary.addDiagnostic("manifest_invalid_lines:${manifest.invalidLines}")
        for (diagnostic in manifest.diagnostics) {
            summary.diagnostics.add("manifest:${diagnostic}")
        }
    }

    for (row in rows) {
        if (!row.ok) {
            summary.addDiagnostic("${row.diagnostic}:${ckbCdGapCompactRaw(row.raw)}")
            continue
        }
        summary.parsedResultRows += 1
        if (ckbCdGapManifestIndex(manifest.cases, row.caseId) < 0) {
            summary.addDiagnostic("missing_manifest_case:${row.caseId}")
        }
        if (row.group == CkbCdGapAuditGroups.C) {
            summary.cTotal += 1
            if (row.unitPassAt1) {
                summary.cPassAt1 += 1
            }
        } else if (row.group == CkbCdGapAuditGroups.D) {
            summary.dTotal += 1
            if (row.unitPassAt1) {
                summary.dPassAt1 += 1
            }
        }
    }

    for (evalCase in manifest.cases) {
        let cIndex = ckbCdGapFindRow(rows, evalCase.id, CkbCdGapAuditGroups.C)
        let dIndex = ckbCdGapFindRow(rows, evalCase.id, CkbCdGapAuditGroups.D)
        let caseSummary = CkbCdGapAuditCaseSummary()
        caseSummary.caseId = evalCase.id
        caseSummary.tags = evalCase.expectedKnowledgeTags
        if (cIndex >= 0) {
            caseSummary.cStatus = classifyPassAt1(rows[cIndex])
            caseSummary.cFailureType = rows[cIndex].failureType
        } else {
            summary.addDiagnostic("missing_result_case_group:${evalCase.id}:C")
        }
        if (dIndex >= 0) {
            caseSummary.dStatus = classifyPassAt1(rows[dIndex])
            caseSummary.dFailureType = rows[dIndex].failureType
        } else {
            summary.addDiagnostic("missing_result_case_group:${evalCase.id}:D")
        }
        let cFailed = caseSummary.cStatus != "ok"
        let dFailed = caseSummary.dStatus != "ok"
        if (cFailed || dFailed) {
            summary.cdFailureUnion += 1
            ckbCdGapAddTags(summary.tagCounts, evalCase.expectedKnowledgeTags)
        }
        if (cFailed && dFailed) {
            summary.cdDualFailure += 1
        } else if (cFailed) {
            summary.cOnlyFailure += 1
        } else if (dFailed) {
            summary.dOnlyFailure += 1
        }
        summary.cases.add(caseSummary)
    }
    summary
}

public func renderCkbCdGapAuditMarkdown(summary: CkbCdGapAuditSummary): String {
    var out = "# C/D Knowledge Gap Audit\n\n"
    out += "- ok: ${summary.ok}\n"
    out += "- runRoot: `${summary.runRoot}`\n"
    out += "- manifestPath: `${summary.manifestPath}`\n"
    out += "- manifestCaseCount: ${summary.manifestCaseCount}\n"
    out += "- parsedResultRows: ${summary.parsedResultRows}\n"
    out += "- C pass@1: ${summary.cPassAt1}/${summary.cTotal}\n"
    out += "- D pass@1: ${summary.dPassAt1}/${summary.dTotal}\n"
    out += "- C/D failure union: ${summary.cdFailureUnion}\n"
    out += "- dual failure: ${summary.cdDualFailure}\n"
    out += "- C-only failure: ${summary.cOnlyFailure}\n"
    out += "- D-only failure: ${summary.dOnlyFailure}\n\n"
    out += "## Diagnostics\n\n"
    if (summary.diagnostics.size == 0) {
        out += "- none\n\n"
    } else {
        for (diagnostic in summary.diagnostics) {
            out += "- `${ckbCdGapEscapeMarkdown(diagnostic)}`\n"
        }
        out += "\n"
    }
    out += "## Tag Counts\n\n"
    out += "| tag | failedCaseCount |\n"
    out += "| --- | --- |\n"
    for (tag in summary.tagCounts) {
        out += "| ${ckbCdGapEscapeMarkdown(tag.tag)} | ${tag.count} |\n"
    }
    out += "\n## Case Matrix\n\n"
    out += "| caseId | C status | D status | tags |\n"
    out += "| --- | --- | --- | --- |\n"
    for (caseSummary in summary.cases) {
        out += "| ${caseSummary.caseId} | ${caseSummary.cStatus} | ${caseSummary.dStatus} | ${ckbCdGapJoin(caseSummary.tags, ", ")} |\n"
    }
    out
}

public func renderCkbCdGapAuditJson(summary: CkbCdGapAuditSummary): String {
    var diagnostics = ""
    for (i in 0..summary.diagnostics.size) {
        if (i > 0) {
            diagnostics += ","
        }
        diagnostics += "\"${ckbCdGapJsonEscape(summary.diagnostics[i])}\""
    }
    var tagCounts = ""
    for (i in 0..summary.tagCounts.size) {
        if (i > 0) {
            tagCounts += ","
        }
        let tag = summary.tagCounts[i]
        tagCounts += "{\"tag\":\"${ckbCdGapJsonEscape(tag.tag)}\",\"failedCaseCount\":${tag.count}}"
    }
    var cases = ""
    for (i in 0..summary.cases.size) {
        if (i > 0) {
            cases += ","
        }
        let caseSummary = summary.cases[i]
        cases += "{\"caseId\":\"${ckbCdGapJsonEscape(caseSummary.caseId)}\",\"cStatus\":\"${ckbCdGapJsonEscape(caseSummary.cStatus)}\",\"dStatus\":\"${ckbCdGapJsonEscape(caseSummary.dStatus)}\",\"tags\":[${ckbCdGapJsonStringArray(caseSummary.tags)}]}"
    }
    "{\"ok\":${summary.ok},\"runRoot\":\"${ckbCdGapJsonEscape(summary.runRoot)}\",\"manifestPath\":\"${ckbCdGapJsonEscape(summary.manifestPath)}\",\"manifestCaseCount\":${summary.manifestCaseCount},\"parsedResultRows\":${summary.parsedResultRows},\"cTotal\":${summary.cTotal},\"dTotal\":${summary.dTotal},\"cPassAt1\":${summary.cPassAt1},\"dPassAt1\":${summary.dPassAt1},\"cdFailureUnion\":${summary.cdFailureUnion},\"cdDualFailure\":${summary.cdDualFailure},\"cOnlyFailure\":${summary.cOnlyFailure},\"dOnlyFailure\":${summary.dOnlyFailure},\"diagnostics\":[${diagnostics}],\"tagCounts\":[${tagCounts}],\"cases\":[${cases}]}\n"
}

public func ckbCdGapAuditUsage(): String {
    "Usage: cangjie_community_knowledge_base cangjie-eval-knowledge-audit --run-root <path> [--manifest <manifest.jsonl>] [--format markdown|json]\n"
}

private func ckbCdGapSupportedGroup(group: String): Bool {
    group == CkbCdGapAuditGroups.C || group == CkbCdGapAuditGroups.D
}

private func ckbCdGapManifestIndex(cases: ArrayList<CangjieEvalCase>, caseId: String): Int64 {
    for (i in 0..cases.size) {
        if (cases[i].id == caseId) {
            return i
        }
    }
    -1
}

private func ckbCdGapFindRow(rows: ArrayList<CkbCdGapAuditResultRow>, caseId: String, group: String): Int64 {
    for (i in 0..rows.size) {
        if (rows[i].ok && rows[i].caseId == caseId && rows[i].group == group) {
            return i
        }
    }
    -1
}

private func ckbCdGapAddTags(counts: ArrayList<CkbCdGapTagCount>, tags: ArrayList<String>): Unit {
    for (tag in tags) {
        let idx = ckbCdGapTagIndex(counts, tag)
        if (idx >= 0) {
            counts[idx].count += 1
        } else {
            counts.add(CkbCdGapTagCount(tag, 1))
        }
    }
}

private func ckbCdGapTagIndex(counts: ArrayList<CkbCdGapTagCount>, tag: String): Int64 {
    for (i in 0..counts.size) {
        if (counts[i].tag == tag) {
            return i
        }
    }
    -1
}

private func ckbCdGapReadText(path: String): String {
    try {
        String.fromUtf8(File.readFrom(Path(path)))
    } catch (_: Exception) {
        ""
    }
}

private func ckbCdGapJsonStringField(text: String, field: String): String {
    let marker = "\"${field}\""
    let parts = text.split(marker)
    if (parts.size <= 1) {
        return ""
    }
    let afterKey = parts[1]
    let colonParts = afterKey.split(":")
    if (colonParts.size <= 1) {
        return ""
    }
    var tail = afterKey
    match (afterKey.indexOf(":")) {
        case Some(colon) => tail = afterKey[colon + 1..].trimAscii()
        case None => return ""
    }
    if (!tail.startsWith("\"")) {
        return ""
    }
    let valueTail = tail[1..]
    match (valueTail.indexOf("\"")) {
        case Some(end) => valueTail[..end]
        case None => ""
    }
}

private func ckbCdGapJsonBoolField(text: String, field: String): Bool {
    let raw = ckbCdGapJsonScalarField(text, field)
    raw.startsWith("true")
}

private func ckbCdGapJsonIntField(text: String, field: String, fallback: Int64): Int64 {
    let raw = ckbCdGapJsonScalarField(text, field)
    if (raw == "") {
        return fallback
    }
    try {
        Int64.parse(raw)
    } catch (_: Exception) {
        fallback
    }
}

private func ckbCdGapJsonScalarField(text: String, field: String): String {
    let marker = "\"${field}\""
    let parts = text.split(marker)
    if (parts.size <= 1) {
        return ""
    }
    let afterKey = parts[1]
    var tail = ""
    match (afterKey.indexOf(":")) {
        case Some(colon) => tail = afterKey[colon + 1..].trimAscii()
        case None => return ""
    }
    var end: Int64 = tail.size
    match (tail.indexOf(",")) {
        case Some(idx) => end = idx
        case None => ()
    }
    match (tail.indexOf("}")) {
        case Some(idx) => if (idx < end) { end = idx }
        case None => ()
    }
    tail[..end].trimAscii()
}

private func ckbCdGapCompactRaw(raw: String): String {
    let trimmed = raw.trimAscii().replace("\n", " ").replace("\r", " ")
    let runes = trimmed.toRuneArray()
    if (runes.size <= 80) {
        return trimmed
    }
    let out = StringBuilder()
    for (i in 0..80) {
        out.append(runes[i])
    }
    out.toString() + "..."
}

private func ckbCdGapJoin(values: ArrayList<String>, separator: String): String {
    var out = ""
    for (i in 0..values.size) {
        if (i > 0) {
            out += separator
        }
        out += values[i]
    }
    out
}

private func ckbCdGapJsonStringArray(values: ArrayList<String>): String {
    var out = ""
    for (i in 0..values.size) {
        if (i > 0) {
            out += ","
        }
        out += "\"${ckbCdGapJsonEscape(values[i])}\""
    }
    out
}

private func ckbCdGapJsonEscape(raw: String): String {
    raw.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
}

private func ckbCdGapEscapeMarkdown(raw: String): String {
    raw.replace("|", "\\|")
}
