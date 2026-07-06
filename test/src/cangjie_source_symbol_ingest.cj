package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}

public class CangjieSourceSymbolLimits {
    public static let MAX_SIGNATURE_LINES: Int64 = 8
    public static let MAX_RECORD_CONTENT_BYTES: Int64 = 12000
}

private class CangjieSourceSymbolReadResult {
    var ok: Bool = false
    var status: String = "not_started"
    var text: String = ""

    init() {}
}

public func scanCangjieSourceSymbolsRoot(root: String, sourceSet: String, resolution: CangjieVersionResolution): CangjieTypedRecordResult {
    let result = CangjieTypedRecordResult()
    let cleanSet = cangjieSourceSymbolCleanSourceSet(sourceSet)
    if (cleanSet == "") {
        result.addDiagnostic("invalid_source_symbol_source_set")
        return result
    }
    if (!cangjieSourceSymbolRootAllowed(root)) {
        result.addDiagnostic("invalid_source_symbol_root")
        return result
    }
    let paths = discoverCangjieSourceRelativePaths(root)
    if (paths.size == 0) {
        result.addDiagnostic("no_cangjie_source_files")
        return result
    }
    for (relative in paths) {
        let read = cangjieReadSourceSymbolText(Path(root).join(relative))
        if (!read.ok) {
            result.diagnostics.add("${read.status}:${relative}")
            continue
        }
        let fileResult = extractCangjieSourceSymbolRecords(relative, read.text, cleanSet, resolution)
        for (diagnostic in fileResult.diagnostics) {
            result.diagnostics.add("${relative}:${diagnostic}")
        }
        for (record in fileResult.records) {
            result.records.add(record)
        }
        result.ok = result.ok && fileResult.ok
    }
    if (!cangjieSourceSymbolHasKind(result, CangjieTypedRecordKinds.SYMBOL_CARD)) {
        result.addDiagnostic("no_source_symbol_records")
    }
    result
}

public func discoverCangjieSourceRelativePaths(root: String): ArrayList<String> {
    let paths = ArrayList<String>()
    if (!cangjieSourceSymbolRootAllowed(root)) {
        return paths
    }
    cangjieDiscoverSourceRelativePaths(Path(root), "", paths)
    paths
}

public func extractCangjieSourceSymbolRecords(relativePath: String, content: String, sourceSet: String, resolution: CangjieVersionResolution): CangjieTypedRecordResult {
    let result = CangjieTypedRecordResult()
    let cleanPath = cangjieCleanSourceSymbolRelativePath(relativePath)
    let cleanSet = cangjieSourceSymbolCleanSourceSet(sourceSet)
    if (!cangjieSourceSymbolRelativePathAllowed(cleanPath)) {
        result.addDiagnostic("invalid_source_symbol_path")
        return result
    }
    if (cleanSet == "") {
        result.addDiagnostic("invalid_source_symbol_source_set")
        return result
    }
    if (content.trimAscii() == "") {
        result.addDiagnostic("empty_source_symbol_file")
        return result
    }

    let source = cangjieSourceSymbolResolveSource(cleanSet, resolution)
    let moduleName = cangjieSourceSymbolModuleName(cleanPath, content)
    let imports = cangjieSourceSymbolImports(content)
    result.records.add(cangjieSourceModuleTreeRecord(cleanPath, moduleName, imports, cleanSet, resolution, source))
    result.records.add(cangjieSourceAvailabilityRecord(cleanPath, moduleName, cleanSet, resolution, source))

    let lines = content.split("\n")
    var currentReceiver = ""
    var receiverDepth: Int64 = -1
    var braceDepth: Int64 = 0
    var i: Int64 = 0
    while (i < lines.size) {
        let raw = cangjieSourceStripLineComment(lines[i]).trimAscii()
        let beforeDepth = braceDepth
        if (raw.startsWith("public class ") || raw.startsWith("public struct ") || raw.startsWith("public enum ") || raw.startsWith("public interface ")) {
            let typeName = cangjieSourceSymbolNameAfterTypePrefix(raw)
            if (typeName != "") {
                result.records.add(cangjieSourceSymbolCardRecord(cleanPath, moduleName, imports, typeName, raw, "", cleanSet, resolution, source, false, ""))
                currentReceiver = typeName
                receiverDepth = beforeDepth
            }
        } else if (raw.startsWith("extend ")) {
            let receiver = cangjieSourceSymbolNameAfterPrefix(raw, "extend ")
            if (receiver != "") {
                currentReceiver = receiver
                receiverDepth = beforeDepth
            }
        } else if (raw.startsWith("public func ")) {
            let signature = cangjieSourceCollectSignature(lines, i)
            let funcName = cangjieSourceSymbolNameAfterPrefix(raw, "public func ")
            if (funcName != "") {
                let incomplete = !signature.contains(")")
                let diagnostic = if (incomplete) { "symbol_signature_incomplete" } else { "" }
                let symbolKey = if (currentReceiver != "") { "${currentReceiver}.${funcName}" } else { funcName }
                result.records.add(cangjieSourceSymbolCardRecord(cleanPath, moduleName, imports, symbolKey, signature, currentReceiver, cleanSet, resolution, source, incomplete, diagnostic))
                if (incomplete) {
                    result.addDiagnostic("${symbolKey}:symbol_signature_incomplete")
                }
            }
        }
        braceDepth += cangjieSourceCountRune(raw, r'{')
        braceDepth -= cangjieSourceCountRune(raw, r'}')
        if (braceDepth < 0) {
            braceDepth = 0
        }
        if (currentReceiver != "" && receiverDepth >= 0 && braceDepth <= receiverDepth && raw.contains("}")) {
            currentReceiver = ""
            receiverDepth = -1
        }
        i += 1
    }
    if (!cangjieSourceSymbolHasKind(result, CangjieTypedRecordKinds.SYMBOL_CARD)) {
        result.addDiagnostic("no_source_symbol_records")
    }
    result
}

private func cangjieSourceSymbolHasKind(result: CangjieTypedRecordResult, kind: String): Bool {
    for (record in result.records) {
        if (record.recordKind == kind) {
            return true
        }
    }
    false
}

private func cangjieSourceModuleTreeRecord(relativePath: String, moduleName: String, imports: ArrayList<String>, sourceSet: String, resolution: CangjieVersionResolution, source: CangjieVersionSource): CangjieTypedRecord {
    let record = cangjieSourceBaseRecord(relativePath, moduleName, sourceSet, resolution, source)
    record.recordKind = CangjieTypedRecordKinds.MODULE_TREE
    record.sourceId = "source-module-${sourceSet}-${cangjieSourceSafeId(relativePath)}"
    record.title = "Module tree: ${moduleName}"
    record.symbol = moduleName
    record.heading = moduleName
    record.sectionId = "${moduleName}#module"
    record.content = "module=${moduleName}\nimports=${cangjieSourceJoinImports(imports)}\npath=${relativePath}"
    record.contentHash = cangjieTypedRecordContentHash(record.sourceId, record.content)
    record
}

private func cangjieSourceAvailabilityRecord(relativePath: String, moduleName: String, sourceSet: String, resolution: CangjieVersionResolution, source: CangjieVersionSource): CangjieTypedRecord {
    let record = cangjieSourceBaseRecord(relativePath, moduleName, sourceSet, resolution, source)
    record.recordKind = CangjieTypedRecordKinds.AVAILABILITY
    record.sourceId = "source-availability-${sourceSet}-${cangjieSourceSafeId(relativePath)}"
    record.title = "Availability: ${moduleName}"
    record.symbol = moduleName
    record.heading = "stable"
    record.sectionId = "${moduleName}#availability"
    record.content = "availability=stable\ntargetVersion=${resolution.targetVersion}\nsourceSet=${sourceSet}\nsourceRef=${source.sourceRef}"
    record.contentHash = cangjieTypedRecordContentHash(record.sourceId, record.content)
    record
}

private func cangjieSourceSymbolCardRecord(relativePath: String, moduleName: String, imports: ArrayList<String>, symbolKey: String, signature: String, receiver: String, sourceSet: String, resolution: CangjieVersionResolution, source: CangjieVersionSource, incomplete: Bool, diagnostic: String): CangjieTypedRecord {
    let record = cangjieSourceBaseRecord(relativePath, moduleName, sourceSet, resolution, source)
    let cleanSignature = cangjieSourceNormalizeSignature(signature)
    record.recordKind = CangjieTypedRecordKinds.SYMBOL_CARD
    record.sourceId = "source-symbol-${sourceSet}-${cangjieSourceSafeId(relativePath)}-${cangjieSourceSafeId(symbolKey)}"
    record.title = "Symbol: ${symbolKey}"
    record.symbol = symbolKey
    record.heading = moduleName
    record.sectionId = "${moduleName}#${symbolKey}"
    record.content = cangjieSourceSymbolCardContent(symbolKey, moduleName, imports, cleanSignature, receiver, "stable", diagnostic)
    record.citation = "${source.sourceRepo}@${source.resolvedCommit}:${relativePath}#${symbolKey}"
    record.contentHash = cangjieTypedRecordContentHash(record.sourceId, record.content)
    record.diagnostic = diagnostic
    if (incomplete) {
        record.reviewState = ReviewStates.REVIEWED
    }
    record
}

private func cangjieSourceBaseRecord(relativePath: String, moduleName: String, sourceSet: String, resolution: CangjieVersionResolution, source: CangjieVersionSource): CangjieTypedRecord {
    let record = CangjieTypedRecord()
    record.sourceSet = sourceSet
    record.sourceFamily = if (sourceSet == CangjieSourceSets.STDX) { "stdx" } else { "stdlib" }
    record.path = relativePath
    record.targetVersion = resolution.targetVersion
    record.versionResolutionId = resolution.versionResolutionId
    record.sourceRef = source.sourceRef
    record.refKind = source.refKind
    record.resolvedCommit = source.resolvedCommit
    record.trustLevel = TrustLevels.OFFICIAL
    record.reviewState = ReviewStates.TRUSTED
    record.citation = "${source.sourceRepo}@${source.resolvedCommit}:${relativePath}#${moduleName}"
    record
}

private func cangjieSourceSymbolCardContent(symbolKey: String, moduleName: String, imports: ArrayList<String>, signature: String, receiver: String, availability: String, diagnostic: String): String {
    "symbolKey=${symbolKey}\nmodule=${moduleName}\nimportLine=${cangjieSourceBestImport(imports, moduleName)}\nsignature=${signature}\nreceiver=${receiver}\nparams=${cangjieSourceParams(signature)}\nreturnType=${cangjieSourceReturnType(signature)}\navailability=${availability}\ndiagnostic=${diagnostic}"
}

private func cangjieSourceSymbolResolveSource(sourceSet: String, resolution: CangjieVersionResolution): CangjieVersionSource {
    for (source in resolution.sources) {
        if (source.sourceSet == sourceSet) {
            return source
        }
    }
    let source = CangjieVersionSource()
    source.sourceSet = sourceSet
    source.sourceFamily = if (sourceSet == CangjieSourceSets.STDX) { "stdx" } else { "stdlib" }
    source.sourceRepo = if (sourceSet == CangjieSourceSets.STDX) { "Cangjie/cangjie_stdx" } else { "Cangjie/cangjie_runtime" }
    source.sourceRef = "release-${resolution.targetVersion}"
    source.refKind = "branch"
    source.resolvedCommit = "unresolved-source"
    source.targetVersion = resolution.targetVersion
    source
}

private func cangjieSourceSymbolCleanSourceSet(sourceSet: String): String {
    let clean = sourceSet.trimAscii().toAsciiLower()
    if (clean == CangjieSourceSets.STD || clean == CangjieSourceSets.STDX) {
        return clean
    }
    ""
}

private func cangjieSourceSymbolRootAllowed(root: String): Bool {
    let clean = root.trimAscii()
    clean != "" && !clean.contains("\u{0}") && !clean.contains("..") && !clean.contains("/.ssh") && !clean.contains("/.config") && exists(Path(clean))
}

private func cangjieSourceSymbolRelativePathAllowed(path: String): Bool {
    let clean = cangjieCleanSourceSymbolRelativePath(path)
    if (clean == "" || clean.startsWith("/") || clean.contains("..") || clean.contains("\u{0}")) {
        return false
    }
    clean.endsWith(".cj")
}

private func cangjieCleanSourceSymbolRelativePath(path: String): String {
    path.trimAscii().replace("\\", "/")
}

private func cangjieDiscoverSourceRelativePaths(root: Path, relativeRoot: String, out: ArrayList<String>): Unit {
    try {
        for (entry in Directory.readFrom(root)) {
            let name = entry.name.trimAscii()
            if (name == "" || name.startsWith(".") || cangjieSourceIgnoredDirName(name)) {
                continue
            }
            let relative = if (relativeRoot == "") { name } else { "${relativeRoot}/${name}" }
            if (entry.isDirectory()) {
                cangjieDiscoverSourceRelativePaths(entry.path, relative, out)
            } else if (entry.isRegular() && cangjieSourceSymbolRelativePathAllowed(relative)) {
                cangjieSourceInsertSortedString(out, relative)
            }
        }
    } catch (_: Exception) {
        return
    }
}

private func cangjieSourceIgnoredDirName(name: String): Bool {
    let lower = name.toAsciiLower()
    lower == ".git" || lower == "target" || lower == "node_modules" || lower == "build" || lower == "dist"
}

private func cangjieSourceInsertSortedString(out: ArrayList<String>, value: String): Unit {
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

private func cangjieReadSourceSymbolText(path: Path): CangjieSourceSymbolReadResult {
    let result = CangjieSourceSymbolReadResult()
    if (!exists(path)) {
        result.status = "source_symbol_file_not_found"
        return result
    }
    try {
        result.text = String.fromUtf8(File.readFrom(path))
        result.ok = true
        result.status = "ok"
    } catch (_: Exception) {
        result.status = "invalid_source_symbol_encoding"
        result.text = ""
    }
    result
}

private func cangjieSourceSymbolModuleName(relativePath: String, content: String): String {
    for (line in content.split("\n")) {
        let trimmed = cangjieSourceStripLineComment(line).trimAscii()
        if (trimmed.startsWith("package ")) {
            let moduleName = cangjieSourceSymbolNameAfterPrefix(trimmed, "package ")
            if (moduleName != "") {
                return moduleName
            }
        }
    }
    cangjieSourceModuleFromPath(relativePath)
}

private func cangjieSourceModuleFromPath(relativePath: String): String {
    let clean = relativePath.replace("\\", "/")
    let parts = clean.split("/")
    if (parts.size <= 1) {
        return clean.replace(".cj", "")
    }
    var moduleName = ""
    var i: Int64 = 0
    while (i < parts.size - 1) {
        if (parts[i] != "src") {
            if (moduleName != "") {
                moduleName += "."
            }
            moduleName += parts[i]
        }
        i += 1
    }
    if (moduleName == "") { "default" } else { moduleName }
}

private func cangjieSourceSymbolImports(content: String): ArrayList<String> {
    let imports = ArrayList<String>()
    for (line in content.split("\n")) {
        let trimmed = cangjieSourceStripLineComment(line).trimAscii()
        if (trimmed.startsWith("import ")) {
            imports.add(trimmed)
        }
    }
    imports
}

private func cangjieSourceBestImport(imports: ArrayList<String>, moduleName: String): String {
    for (line in imports) {
        if (line.contains(moduleName)) {
            return line
        }
    }
    if (imports.size > 0) { imports[0] } else { "" }
}

private func cangjieSourceJoinImports(imports: ArrayList<String>): String {
    var out = ""
    for (line in imports) {
        if (out != "") {
            out += "; "
        }
        out += line
    }
    out
}

private func cangjieSourceStripLineComment(line: String): String {
    let parts = line.split("//")
    if (parts.size == 0) { line } else { parts[0] }
}

private func cangjieSourceSymbolNameAfterTypePrefix(line: String): String {
    for (prefix in ["public class ", "public struct ", "public enum ", "public interface "]) {
        if (line.startsWith(prefix)) {
            return cangjieSourceSymbolNameAfterPrefix(line, prefix)
        }
    }
    ""
}

private func cangjieSourceSymbolNameAfterPrefix(line: String, prefix: String): String {
    let parts = line.split(prefix)
    if (parts.size < 2) {
        return ""
    }
    cangjieSourceLeadingIdentifier(parts[1].trimAscii())
}

private func cangjieSourceLeadingIdentifier(raw: String): String {
    let out = StringBuilder()
    for (ch in raw.toRuneArray()) {
        if ((ch >= r'a' && ch <= r'z') || (ch >= r'A' && ch <= r'Z') || (ch >= r'0' && ch <= r'9') || ch == r'_') {
            out.append(ch)
        } else {
            break
        }
    }
    out.toString()
}

private func cangjieSourceCollectSignature(lines: Array<String>, start: Int64): String {
    var out = ""
    var i = start
    var consumed: Int64 = 0
    while (i < lines.size && consumed < CangjieSourceSymbolLimits.MAX_SIGNATURE_LINES) {
        let trimmed = cangjieSourceStripLineComment(lines[i]).trimAscii()
        if (trimmed != "") {
            if (out != "") {
                out += " "
            }
            out += trimmed
        }
        if (trimmed.contains(")") || trimmed.contains("{")) {
            break
        }
        i += 1
        consumed += 1
    }
    cangjieSourceNormalizeSignature(out)
}

private func cangjieSourceNormalizeSignature(signature: String): String {
    var clean = signature.trimAscii()
    if (clean.contains("{")) {
        clean = clean.split("{")[0].trimAscii()
    }
    if (clean.size > CangjieSourceSymbolLimits.MAX_RECORD_CONTENT_BYTES) {
        return utf8SafePrefix(clean, CangjieSourceSymbolLimits.MAX_RECORD_CONTENT_BYTES)
    }
    clean
}

private func cangjieSourceParams(signature: String): String {
    if (!signature.contains("(") || !signature.contains(")")) {
        return ""
    }
    let parts = signature.split("(")
    if (parts.size < 2) {
        return ""
    }
    parts[1].split(")")[0]
}

private func cangjieSourceReturnType(signature: String): String {
    if (!signature.contains("):")) {
        return ""
    }
    let parts = signature.split("):")
    if (parts.size < 2) {
        return ""
    }
    parts[1].trimAscii()
}

private func cangjieSourceCountRune(line: String, needle: Rune): Int64 {
    var count: Int64 = 0
    for (ch in line.toRuneArray()) {
        if (ch == needle) {
            count += 1
        }
    }
    count
}

private func cangjieSourceSafeId(raw: String): String {
    let out = StringBuilder()
    for (ch in raw.toRuneArray()) {
        if ((ch >= r'a' && ch <= r'z') || (ch >= r'A' && ch <= r'Z') || (ch >= r'0' && ch <= r'9')) {
            out.append(ch)
        } else {
            out.append("-")
        }
    }
    let value = out.toString().toAsciiLower()
    if (value == "") { "source" } else { value }
}
