package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}

public class CangjieDocCorpusLimits {
    public static let MAX_SECTION_BYTES: Int64 = 60000
}

public class CangjieDocSourceRecord {
    public var sourceId: String = ""
    public var path: String = ""
    public var content: String = ""
    public var sourceUrl: String = ""
    public var repo: String = ""
    public var sourceSet: String = CangjieSourceSets.DOCS
    public var sourceFamily: String = "docs"
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var sourceRef: String = ""
    public var refKind: String = "branch"
    public var resolvedCommit: String = ""
    public var versionResolutionId: String = ""

    public init() {}
}

public func scanCangjieDocsRoot(root: String, resolution: CangjieVersionResolution): CangjieTypedRecordResult {
    scanCangjieDocsRoot(root, resolution, cangjieDocsDefaultRelativePaths())
}

public func scanCangjieDocsRootFull(root: String, resolution: CangjieVersionResolution): CangjieTypedRecordResult {
    let paths = discoverCangjieDocsRelativePaths(root)
    scanCangjieDocsRoot(root, resolution, paths)
}

public func discoverCangjieDocsRelativePaths(root: String): ArrayList<String> {
    let paths = ArrayList<String>()
    if (!cangjieDocsRootAllowed(root)) {
        return paths
    }
    cangjieDiscoverDocsRelativePaths(Path(root), "", paths)
    paths
}

public func scanCangjieDocsRoot(root: String, resolution: CangjieVersionResolution, relativePaths: ArrayList<String>): CangjieTypedRecordResult {
    let result = CangjieTypedRecordResult()
    if (!cangjieDocsRootAllowed(root)) {
        result.addDiagnostic("invalid_docs_root")
        return result
    }
    if (relativePaths.size == 0) {
        result.addDiagnostic("empty_docs_path_manifest")
        return result
    }
    for (relative in relativePaths) {
        let clean = cangjieCleanRelativePath(relative)
        if (!cangjieRelativeDocsPathAllowed(clean)) {
            result.diagnostics.add("invalid_docs_path:${relative}")
            continue
        }
        let read = cangjieReadTextFile(Path(root).join(clean))
        if (!read.ok) {
            result.diagnostics.add("${read.status}:${clean}")
            continue
        }
        let source = cangjieDocSourceFromText(clean, read.text, resolution)
        let sections = splitCangjieDocSections(source)
        for (diagnostic in sections.diagnostics) {
            result.diagnostics.add(diagnostic)
        }
        for (section in sections.records) {
            result.records.add(section)
            let tools = extractToolManualSections(section)
            for (toolDiagnostic in tools.diagnostics) {
                result.diagnostics.add(toolDiagnostic)
            }
            for (tool in tools.records) {
                result.records.add(tool)
            }
        }
    }
    if (result.records.size == 0) {
        result.ok = false
        if (result.diagnostics.size == 0) {
            result.diagnostics.add("no_docs_records")
        }
    }
    result
}

public func splitCangjieDocSections(source: CangjieDocSourceRecord): CangjieTypedRecordResult {
    if (source.path.toAsciiLower().endsWith(".html")) {
        return splitCangjieHtmlSections(source)
    }
    splitMarkdownSections(source)
}

public func splitMarkdownSections(source: CangjieDocSourceRecord): CangjieTypedRecordResult {
    let result = CangjieTypedRecordResult()
    if (!cangjieRelativeDocsPathAllowed(source.path)) {
        result.addDiagnostic("invalid_docs_path")
        return result
    }
    if (source.content.trimAscii() == "") {
        result.addDiagnostic("empty_markdown")
        return result
    }

    var heading = "Document"
    var current = StringBuilder()
    var index: Int64 = 0
    var inFence = false
    for (line in source.content.split("\n")) {
        let trimmed = line.trimAscii()
        if (trimmed.startsWith("```")) {
            inFence = !inFence
            current.append(line)
            current.append("\n")
            continue
        }
        if (!inFence && cangjieMarkdownHeadingLevel(trimmed) > 0) {
            index = cangjieAddDocSection(result, source, heading, index, current.toString())
            current = StringBuilder()
            heading = cangjieMarkdownHeadingText(trimmed)
        }
        current.append(line)
        current.append("\n")
    }
    index = cangjieAddDocSection(result, source, heading, index, current.toString())
    if (result.records.size == 0) {
        result.addDiagnostic("no_markdown_sections")
    }
    result
}

public func splitCangjieHtmlSections(source: CangjieDocSourceRecord): CangjieTypedRecordResult {
    let htmlSource = CangjieDocSourceRecord()
    htmlSource.sourceId = source.sourceId
    htmlSource.path = source.path
    htmlSource.content = cangjieHtmlToPseudoMarkdown(source.content)
    htmlSource.sourceUrl = source.sourceUrl
    htmlSource.repo = source.repo
    htmlSource.sourceSet = source.sourceSet
    htmlSource.sourceFamily = source.sourceFamily
    htmlSource.targetVersion = source.targetVersion
    htmlSource.sourceRef = source.sourceRef
    htmlSource.refKind = source.refKind
    htmlSource.resolvedCommit = source.resolvedCommit
    htmlSource.versionResolutionId = source.versionResolutionId
    let result = splitMarkdownSections(htmlSource)
    if (result.records.size == 0) {
        result.addDiagnostic("no_html_sections")
    }
    result
}

public func extractToolManualSections(section: CangjieTypedRecord): CangjieTypedRecordResult {
    let result = CangjieTypedRecordResult()
    if (!cangjieSectionLooksLikeToolManual(section)) {
        return result
    }
    let tool = CangjieTypedRecord()
    tool.recordKind = CangjieTypedRecordKinds.TOOL_MANUAL
    tool.sourceId = "${section.sourceId}:tool"
    tool.title = "Tool manual: ${section.heading}"
    tool.content = section.content
    tool.citation = section.citation
    tool.sourceSet = CangjieSourceSets.TOOLS
    tool.sourceFamily = "tools"
    tool.path = section.path
    tool.heading = section.heading
    tool.sectionId = "${section.sectionId}:tool"
    tool.toolName = cangjieToolNameFromPath(section.path)
    tool.command = cangjieToolCommandFromHeading(section.heading, section.content, tool.toolName)
    tool.contentHash = cangjieTypedRecordContentHash(tool.sourceId, tool.content)
    tool.versionResolutionId = section.versionResolutionId
    tool.targetVersion = section.targetVersion
    tool.sourceRef = section.sourceRef
    tool.refKind = section.refKind
    tool.resolvedCommit = section.resolvedCommit
    tool.trustLevel = section.trustLevel
    tool.reviewState = section.reviewState
    result.records.add(tool)
    result
}

public func cangjieTypedNormalizeRawRecord(record: RawRecord): CangjieTypedRecordResult {
    let result = CangjieTypedRecordResult()
    if (!cangjieRawRecordSupportsTypedDoc(record)) {
        return result
    }
    let source = CangjieDocSourceRecord()
    source.sourceId = record.sourceId
    source.path = record.metadata.path
    source.content = record.content
    source.sourceUrl = record.metadata.sourceUrl
    source.repo = record.metadata.repo
    source.sourceSet = if (record.metadata.sourceSet != "") { record.metadata.sourceSet } else { cangjieSourceSetForDocPath(record.metadata.path, record.metadata.sourceUrl) }
    source.sourceFamily = if (source.sourceSet == CangjieSourceSets.TOOLS) { "tools" } else { "docs" }
    source.targetVersion = record.metadata.targetVersion
    source.sourceRef = record.metadata.docVersion
    source.refKind = "branch"
    source.resolvedCommit = record.metadata.commit
    source.versionResolutionId = record.metadata.versionResolutionId
    let sections = splitCangjieDocSections(source)
    for (diagnostic in sections.diagnostics) {
        result.diagnostics.add(diagnostic)
    }
    for (section in sections.records) {
        section.trustLevel = record.metadata.trustLevel
        section.reviewState = record.metadata.reviewState
        result.records.add(section)
        let tools = extractToolManualSections(section)
        for (toolDiagnostic in tools.diagnostics) {
            result.diagnostics.add(toolDiagnostic)
        }
        for (tool in tools.records) {
            result.records.add(tool)
        }
    }
    result.ok = sections.ok
    result
}

public func cangjieSourceSetForDocPath(path: String, sourceUrl: String): String {
    let value = "${path}\n${sourceUrl}".toAsciiLower()
    if (value.contains("/tools/") || value.contains("cmd-tools") || value.contains("cjpm") || value.contains("cjc") || value.contains("cjfmt")) {
        return CangjieSourceSets.TOOLS
    }
    CangjieSourceSets.DOCS
}

private class CangjieReadTextResult {
    var ok: Bool = false
    var status: String = "not_started"
    var text: String = ""

    init() {}
}

private func cangjieDocsDefaultRelativePaths(): ArrayList<String> {
    let paths = ArrayList<String>()
    paths.add("dev-guide/summary_cjnative_EN.md")
    paths.add("tools/summary_cjnative_EN.md")
    paths
}

private func cangjieDocsRootAllowed(root: String): Bool {
    let clean = root.trimAscii()
    clean != "" && !clean.contains("\u{0}") && !clean.contains("/.ssh") && !clean.contains("/.config") && exists(Path(clean))
}

private func cangjieRelativeDocsPathAllowed(path: String): Bool {
    let clean = cangjieCleanRelativePath(path)
    if (clean == "" || clean.startsWith("/") || clean.contains("..") || clean.contains("\u{0}")) {
        return false
    }
    clean.endsWith(".md") || clean.endsWith(".markdown") || clean.endsWith(".html")
}

private func cangjieCleanRelativePath(path: String): String {
    path.trimAscii().replace("\\", "/")
}

private func cangjieDiscoverDocsRelativePaths(root: Path, relativeRoot: String, out: ArrayList<String>): Unit {
    try {
        for (entry in Directory.readFrom(root)) {
            let name = entry.name.trimAscii()
            if (name == "" || name.startsWith(".")) {
                continue
            }
            if (cangjieDocsIgnoredDirName(name)) {
                continue
            }
            let relative = if (relativeRoot == "") { name } else { "${relativeRoot}/${name}" }
            if (entry.isDirectory()) {
                cangjieDiscoverDocsRelativePaths(entry.path, relative, out)
            } else if (entry.isRegular() && cangjieRelativeDocsPathAllowed(relative)) {
                cangjieInsertSortedString(out, relative)
            }
        }
    } catch (_: Exception) {
        return
    }
}

private func cangjieDocsIgnoredDirName(name: String): Bool {
    let lower = name.toAsciiLower()
    lower == ".git" || lower == "target" || lower == "node_modules" || lower == "build" || lower == "dist"
}

private func cangjieInsertSortedString(out: ArrayList<String>, value: String): Unit {
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

private func cangjieReadTextFile(path: Path): CangjieReadTextResult {
    let result = CangjieReadTextResult()
    if (!exists(path)) {
        result.status = "docs_file_not_found"
        return result
    }
    try {
        result.text = String.fromUtf8(File.readFrom(path))
        result.ok = true
        result.status = "ok"
    } catch (_: Exception) {
        result.status = "invalid_docs_file_encoding"
        result.text = ""
    }
    result
}

private func cangjieDocSourceFromText(relative: String, text: String, resolution: CangjieVersionResolution): CangjieDocSourceRecord {
    let source = CangjieDocSourceRecord()
    source.sourceId = "docs-${cangjieSafeId(relative)}"
    source.path = relative
    source.content = text
    source.sourceSet = cangjieSourceSetForDocPath(relative, "")
    source.sourceFamily = if (source.sourceSet == CangjieSourceSets.TOOLS) { "tools" } else { "docs" }
    source.targetVersion = resolution.targetVersion
    source.versionResolutionId = resolution.versionResolutionId
    if (resolution.sources.size > 0) {
        for (candidate in resolution.sources) {
            if (candidate.sourceSet == source.sourceSet) {
                source.repo = candidate.sourceRepo
                source.sourceRef = candidate.sourceRef
                source.refKind = candidate.refKind
                source.resolvedCommit = candidate.resolvedCommit
                break
            }
        }
        if (source.repo == "") {
            source.repo = resolution.sources[0].sourceRepo
            source.sourceRef = resolution.sources[0].sourceRef
            source.refKind = resolution.sources[0].refKind
            source.resolvedCommit = resolution.sources[0].resolvedCommit
        }
    }
    source.sourceUrl = if (source.repo != "") { "${source.repo}:${relative}" } else { relative }
    source
}

private func cangjieMarkdownHeadingLevel(line: String): Int64 {
    var level: Int64 = 0
    for (ch in line.toRuneArray()) {
        if (ch == r'#') {
            level += 1
        } else {
            break
        }
    }
    if (level > 0 && level <= 6) {
        return level
    }
    0
}

private func cangjieMarkdownHeadingText(line: String): String {
    let out = StringBuilder()
    var afterMarks = false
    for (ch in line.toRuneArray()) {
        if (!afterMarks && ch == r'#') {
            continue
        }
        afterMarks = true
        out.append(ch)
    }
    let text = out.toString().trimAscii()
    if (text == "") { "Document" } else { text }
}

private func cangjieHtmlToPseudoMarkdown(html: String): String {
    let out = StringBuilder()
    for (line in html.split("\n")) {
        let trimmed = line.trimAscii()
        let lower = trimmed.toAsciiLower()
        if (cangjieHtmlLineLooksLikeHeading(lower)) {
            out.append("# ")
            out.append(cangjieStripHtmlTags(trimmed).trimAscii())
            out.append("\n")
        } else {
            let text = cangjieStripHtmlTags(trimmed).trimAscii()
            if (text != "") {
                out.append(text)
                out.append("\n")
            }
        }
    }
    out.toString()
}

private func cangjieHtmlLineLooksLikeHeading(lower: String): Bool {
    lower.contains("<h1") || lower.contains("<h2") || lower.contains("<h3") || lower.contains("<h4") || lower.contains("<h5") || lower.contains("<h6")
}

private func cangjieStripHtmlTags(raw: String): String {
    let out = StringBuilder()
    var inTag = false
    for (ch in raw.toRuneArray()) {
        if (ch == r'<') {
            inTag = true
            continue
        }
        if (ch == r'>') {
            inTag = false
            continue
        }
        if (!inTag) {
            out.append(ch)
        }
    }
    out.toString().replace("&lt;", "<").replace("&gt;", ">").replace("&amp;", "&")
}

private func cangjieAddDocSection(result: CangjieTypedRecordResult, source: CangjieDocSourceRecord, heading: String, index: Int64, content: String): Int64 {
    let clean = content.trimAscii()
    if (clean == "") {
        return index
    }
    let record = CangjieTypedRecord()
    record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    record.sourceId = "${source.sourceId}:section:${index}"
    record.title = "${heading} (${source.path})"
    record.content = if (content.size > CangjieDocCorpusLimits.MAX_SECTION_BYTES) { utf8SafePrefix(content, CangjieDocCorpusLimits.MAX_SECTION_BYTES) } else { content }
    if (content.size > CangjieDocCorpusLimits.MAX_SECTION_BYTES) {
        record.diagnostic = "section_truncated"
        result.diagnostics.add("section_truncated:${source.path}:${index}")
    }
    record.path = source.path
    record.heading = heading
    record.sectionId = "${source.path}#${index}-${stableSummaryHash(heading)}"
    record.contentHash = cangjieTypedRecordContentHash(record.sourceId, record.content)
    record.citation = cangjieDocCitation(source, record.sectionId)
    record.sourceSet = source.sourceSet
    record.sourceFamily = source.sourceFamily
    record.targetVersion = source.targetVersion
    record.sourceRef = source.sourceRef
    record.refKind = source.refKind
    record.resolvedCommit = source.resolvedCommit
    record.versionResolutionId = source.versionResolutionId
    record.trustLevel = TrustLevels.OFFICIAL
    record.reviewState = ReviewStates.TRUSTED
    result.records.add(record)
    index + 1
}

private func cangjieDocCitation(source: CangjieDocSourceRecord, sectionId: String): String {
    let base = if (source.repo != "") { "${source.repo}:${source.path}" } else if (source.sourceUrl != "") { source.sourceUrl } else { source.path }
    if (source.sourceRef != "") {
        return "${base}@${source.sourceRef}#${sectionId}"
    }
    "${base}#${sectionId}"
}

private func cangjieRawRecordSupportsTypedDoc(record: RawRecord): Bool {
    if (record.content.trimAscii() == "") {
        return false
    }
    record.metadata.sourceType == SourceTypes.DOC || record.metadata.sourceType == SourceTypes.WEBSITE || record.metadata.sourceSet == CangjieSourceSets.DOCS || record.metadata.sourceSet == CangjieSourceSets.TOOLS
}

private func cangjieSectionLooksLikeToolManual(section: CangjieTypedRecord): Bool {
    let value = "${section.sourceSet}\n${section.path}\n${section.heading}\n${utf8SafePrefix(section.content, 2000)}".toAsciiLower()
    value.contains("tools") || value.contains("cmd-tools") || value.contains("cjpm") || value.contains("cjc") || value.contains("cjfmt") || value.contains("cjdb")
}

private func cangjieToolNameFromPath(path: String): String {
    let parts = path.split("/")
    var leaf = if (parts.size > 0) { parts[parts.size - 1] } else { path }
    leaf = leaf.replace("_manual.md", "").replace("_manual.html", "").replace(".md", "").replace(".markdown", "").replace(".html", "")
    if (leaf == "") { "cangjie-tool" } else { leaf }
}

private func cangjieToolCommandFromHeading(heading: String, content: String, fallback: String): String {
    let lower = "${heading}\n${utf8SafePrefix(content, 1000)}".toAsciiLower()
    for (command in ["test", "build", "run", "clean", "init", "update", "debug", "list", "compile"]) {
        if (lower.contains(" ${command}") || lower.contains("${fallback} ${command}") || lower.contains("`${command}`")) {
            return command
        }
    }
    fallback
}

private func cangjieSafeId(raw: String): String {
    let out = StringBuilder()
    for (ch in raw.toRuneArray()) {
        if ((ch >= r'a' && ch <= r'z') || (ch >= r'A' && ch <= r'Z') || (ch >= r'0' && ch <= r'9')) {
            out.append(ch)
        } else {
            out.append(r'-')
        }
    }
    out.toString()
}
