package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashSet}

public let CKB_REPRO_DOCUMENTATION_MODE_DRAFT: String = "draft"
public let CKB_REPRO_DOCUMENTATION_MODE_RELEASE: String = "release"

public class CkbReproDocumentationRead {
    public var found: Bool = false
    public var bytes: Array<UInt8> = Array<UInt8>()
    public init() {}
}

public let CKB_REPRO_DOCUMENTATION_ENTRY_REGULAR: String = "regular"
public let CKB_REPRO_DOCUMENTATION_ENTRY_DIRECTORY: String = "directory"
public let CKB_REPRO_DOCUMENTATION_ENTRY_SYMLINK: String = "symlink"
public let CKB_REPRO_DOCUMENTATION_ENTRY_OUTSIDE: String = "outside"

public class CkbReproDocumentationEntry {
    public var relativePath: String = ""
    public var kind: String = ""
    public init() {}
}

public class CkbReproDocumentationScan {
    public var ok: Bool = false
    public var diagnostic: String = "documentation_not_scanned"
    public var findingCount: Int64 = 0
    public init() {}
}

public class CkbReproDocumentationEvidence {
    public var ok: Bool = false
    public var mode: String = ""
    public var diagnostic: String = "documentation_not_validated"
    public var requiredDocumentCount: Int64 = 0
    public var discoveredDocumentCount: Int64 = 0
    public var placeholderFindingCount: Int64 = 0
    public var pathSecretFindingCount: Int64 = 0
    public var commandFindingCount: Int64 = 0
    public var brokenLinkCount: Int64 = 0
    public init() {}
}

// The caller defines the documentation surface returned by list. The reader is
// deliberately read-only so release verification cannot mutate its candidate.
public interface CkbReproDocumentationReader {
    func list(root: String): ArrayList<CkbReproDocumentationEntry>
    func read(root: String, relativePath: String): CkbReproDocumentationRead
}

public func requiredCkbReproDocumentationFiles(): Array<String> {
    [
        "README.md",
        "docs/reproducibility/README.md",
        "docs/reproducibility/quick-start.md",
        "docs/reproducibility/restore-knowledge-base.md",
        "docs/reproducibility/rebuild-from-source.md",
        "docs/reproducibility/configure-claude-glm.md",
        "docs/reproducibility/run-humaneval-164.md",
        "docs/reproducibility/verify-strict-pass-at-1.md",
        "docs/reproducibility/result-interpretation.md",
        "docs/reproducibility/troubleshooting.md",
        "docs/reproducibility/release-maintainer-runbook.md"
    ]
}

public func scanCkbReproDocumentationPlaceholders(
    text: String, mode: String): CkbReproDocumentationScan {
    let out = CkbReproDocumentationScan()
    if (!p7DocumentationModeValid(mode)) {
        out.diagnostic = "documentation_mode_invalid"
        out.findingCount = 1
        return out
    }
    let markers = [
        "UNPUBLISHED_W3_DRAFT",
        "PENDING_W4_CLI_REGISTRATION",
        "UNPUBLISHED_P8_A_REFERENCE",
        "UNAVAILABLE_UNTIL_W7"
    ]
    if (mode == CKB_REPRO_DOCUMENTATION_MODE_DRAFT) {
        for (marker in markers) {
            if (!text.contains(marker)) { out.findingCount += 1 }
        }
        if (out.findingCount > 0) {
            out.diagnostic = "documentation_draft_placeholder_missing"
            return out
        }
    } else {
        for (marker in markers) {
            if (text.contains(marker)) { out.findingCount += 1 }
        }
        if (out.findingCount > 0) {
            out.diagnostic = "documentation_placeholder_forbidden"
            return out
        }
    }
    out.ok = true
    out.diagnostic = "documentation_placeholders_valid"
    out
}

public func scanCkbReproDocumentationPathsAndSecrets(
    text: String): CkbReproDocumentationScan {
    let out = CkbReproDocumentationScan()
    let lower = text.toAsciiLower()
    if (p7DocumentationContainsPrivatePath(lower)) { out.findingCount += 1 }
    if (p7DocumentationContainsCredential(text)) { out.findingCount += 1 }
    if (p7DocumentationContainsBypass(lower)) { out.findingCount += 1 }
    if (p7DocumentationContainsBenchmarkPayload(lower)) {
        out.findingCount += 1
    }
    if (out.findingCount > 0) {
        out.diagnostic = "documentation_path_or_secret_forbidden"
        return out
    }
    out.ok = true
    out.diagnostic = "documentation_paths_and_secrets_valid"
    out
}

public func validateCkbReproDocumentationCommands(
    text: String, mode: String,
    registeredCommands: Array<String>): CkbReproDocumentationScan {
    let out = CkbReproDocumentationScan()
    if (!p7DocumentationModeValid(mode)) {
        out.diagnostic = "documentation_mode_invalid"
        out.findingCount = 1
        return out
    }
    let allowed = HashSet<String>()
    if (mode == CKB_REPRO_DOCUMENTATION_MODE_DRAFT) {
        allowed.add("ckb-repro-build")
        allowed.add("cangjie-humaneval-strict-score")
    } else {
        for (command in registeredCommands) { allowed.add(command) }
    }
    for (command in p7DocumentationCommandTokens(text)) {
        if (!allowed.contains(command)) { out.findingCount += 1 }
    }
    if (out.findingCount > 0) {
        out.diagnostic = "documentation_command_unknown"
        return out
    }
    out.ok = true
    out.diagnostic = "documentation_commands_valid"
    out
}

public func validateCkbReproDocumentation(
    reader: CkbReproDocumentationReader, root: String, mode: String,
    registeredCommands: Array<String>): CkbReproDocumentationEvidence {
    let evidence = CkbReproDocumentationEvidence()
    evidence.mode = mode
    let required = requiredCkbReproDocumentationFiles()
    evidence.requiredDocumentCount = required.size
    if (!p7DocumentationModeValid(mode)) {
        evidence.diagnostic = "documentation_mode_invalid"
        return evidence
    }

    let listed = reader.list(root)
    let expected = HashSet<String>()
    for (path in required) { expected.add(path) }
    let seen = HashSet<String>()
    for (entry in listed) {
        let path = entry.relativePath
        if (!p7DocumentationRelativePathValid(path)) {
            evidence.diagnostic = "documentation_entry_path_invalid"
            return evidence
        }
        if (entry.kind != CKB_REPRO_DOCUMENTATION_ENTRY_REGULAR) {
            evidence.diagnostic = "documentation_entry_type_forbidden"
            return evidence
        }
        if (!p7DocumentationReleaseSurface(path)) { continue }
        evidence.discoveredDocumentCount += 1
        if (seen.contains(path)) {
            evidence.diagnostic = "documentation_entry_duplicate"
            return evidence
        }
        seen.add(path)
        if (!expected.contains(path)) {
            evidence.diagnostic = "documentation_extra_release_entry"
            return evidence
        }
    }
    for (path in required) {
        if (!seen.contains(path)) {
            evidence.diagnostic = "documentation_required_file_missing"
            return evidence
        }
    }

    let texts = ArrayList<String>()
    for (path in required) {
        let item = reader.read(root, path)
        if (!item.found) {
            evidence.diagnostic = "documentation_required_file_missing"
            return evidence
        }
        let decoded = p7DocumentationDecode(item.bytes)
        if (decoded[0] != "ok") {
            evidence.diagnostic = decoded[0]
            return evidence
        }
        if (path != "README.md" &&
            !p7DocumentationRequiredSectionsPresent(decoded[1])) {
            evidence.diagnostic = "documentation_required_section_missing"
            return evidence
        }
        texts.add(decoded[1])
    }

    if (mode == CKB_REPRO_DOCUMENTATION_MODE_DRAFT) {
        for (entryIndex in [Int64(0), Int64(2)]) {
            if (!texts[entryIndex].contains("UNPUBLISHED_W3_DRAFT") ||
                !texts[entryIndex].contains(
                    "PENDING_W4_CLI_REGISTRATION")) {
                evidence.diagnostic =
                    "documentation_entrypoint_placeholder_missing"
                return evidence
            }
        }
    }

    let corpus = p7DocumentationJoin(texts)
    let placeholders = scanCkbReproDocumentationPlaceholders(corpus, mode)
    evidence.placeholderFindingCount = placeholders.findingCount
    if (!placeholders.ok) {
        evidence.diagnostic = placeholders.diagnostic
        return evidence
    }
    let pathsAndSecrets = scanCkbReproDocumentationPathsAndSecrets(corpus)
    evidence.pathSecretFindingCount = pathsAndSecrets.findingCount
    if (!pathsAndSecrets.ok) {
        evidence.diagnostic = pathsAndSecrets.diagnostic
        return evidence
    }
    let commands = validateCkbReproDocumentationCommands(
        corpus, mode, registeredCommands)
    evidence.commandFindingCount = commands.findingCount
    if (!commands.ok) {
        evidence.diagnostic = commands.diagnostic
        return evidence
    }

    for (i in 0..required.size) {
        let linkCheck = p7ValidateDocumentationLinks(
            reader, root, required[i], texts[i])
        evidence.brokenLinkCount += linkCheck.findingCount
        if (!linkCheck.ok) {
            evidence.diagnostic = linkCheck.diagnostic
            return evidence
        }
    }
    evidence.ok = true
    evidence.diagnostic = "documentation_valid"
    evidence
}

private func p7DocumentationModeValid(mode: String): Bool {
    mode == CKB_REPRO_DOCUMENTATION_MODE_DRAFT ||
        mode == CKB_REPRO_DOCUMENTATION_MODE_RELEASE
}

private func p7DocumentationDecode(bytes: Array<UInt8>): (String, String) {
    try { ("ok", String.fromUtf8(bytes)) }
    catch (_: Exception) { ("invalid_response_encoding", "") }
}

private func p7DocumentationRelativePathValid(path: String): Bool {
    if (path == "" || path.startsWith("/") || path.contains("\\") ||
        path.contains("\n") || path.contains("\r") ||
        path.startsWith("../") || path.contains("/../") ||
        path.startsWith("./") || path.contains("/./") ||
        path.contains("//")) {
        return false
    }
    for (part in path.split("/")) {
        if (part == "" || part == "." || part == "..") { return false }
    }
    true
}

private func p7DocumentationReleaseSurface(path: String): Bool {
    path == "README.md" ||
        path.startsWith("docs/reproducibility/")
}

private func p7DocumentationRequiredSectionsPresent(text: String): Bool {
    for (section in [
        "目的", "工作目录", "命令", "预期输出", "通过标准", "失败处理"
    ]) {
        var found = false
        for (line in text.split("\n")) {
            let trimmed = line.trimAscii()
            if (trimmed.startsWith("${section}：") ||
                trimmed.startsWith("${section}:")) {
                found = true
                break
            }
        }
        if (!found) { return false }
    }
    true
}

private func p7DocumentationContainsPrivatePath(lower: String): Bool {
    p7DocumentationContainsForbiddenPosixPath(lower) ||
        lower.contains(":\\users\\") || lower.contains(":/users/") ||
        p7DocumentationContainsDriveAbsolutePath(lower) ||
        p7DocumentationContainsUncAbsolutePath(lower)
}

private func p7DocumentationContainsForbiddenPosixPath(value: String): Bool {
    let runes = value.toRuneArray()
    var index: Int64 = 0
    while (index < runes.size) {
        if (runes[index] != r'/' ||
            !p7DocumentationPosixPathBoundary(runes, index)) {
            index += 1
            continue
        }
        let token = StringBuilder()
        var end = index
        while (end < runes.size &&
            !p7DocumentationPosixPathDelimiter(runes[end])) {
            token.append(runes[end])
            end += 1
        }
        let path = token.toString()
        if (!p7DocumentationPublicPosixPath(path) &&
            !p7DocumentationPublicApiRoute(path)) {
            return true
        }
        index = if (end > index) { end } else { index + 1 }
    }
    false
}

private func p7DocumentationPosixPathBoundary(
    runes: Array<Rune>, index: Int64): Bool {
    if (index == 0) { return true }
    let previous = runes[index - 1]
    if (previous == r'>') {
        return !p7DocumentationPlaceholderSuffix(runes, index)
    }
    previous == r' ' || previous == r'\t' ||
        previous == r'\n' || previous == r'\r' ||
        previous == r'"' || previous == r'\'' ||
        previous == r'`' || previous == r'(' ||
        previous == r'[' || previous == r'{' ||
        previous == r'=' ||
        previous == r'|'
}

private func p7DocumentationPlaceholderSuffix(
    runes: Array<Rune>, slashIndex: Int64): Bool {
    if (slashIndex < 2 || runes[slashIndex - 1] != r'>') { return false }
    var index = slashIndex - 2
    while (index >= 0) {
        let rune = runes[index]
        if (rune == r'<') { return true }
        if (rune == r' ' || rune == r'\t' || rune == r'\n' ||
            rune == r'\r' || rune == r'"' || rune == r'\'' ||
            rune == r'`' || rune == r'=') {
            return false
        }
        index -= 1
    }
    false
}

private func p7DocumentationPosixPathDelimiter(rune: Rune): Bool {
    rune == r' ' || rune == r'\t' || rune == r'\n' || rune == r'\r' ||
        rune == r'"' || rune == r'\'' || rune == r'`' ||
        rune == r')' || rune == r']' || rune == r'}' ||
        rune == r'|' || rune == r',' || rune == r';' ||
        rune == r':'
}

private func p7DocumentationPublicPosixPath(path: String): Bool {
    path == "/" ||
        path == "/tmp" || path.startsWith("/tmp/") ||
        path == "/dev/null" ||
        path == "/opt/homebrew/opt/openssl@3/lib" ||
        path == "/etc/ssl/cert.pem" ||
        path == "/path/to/cangjie"
}

private func p7DocumentationPublicApiRoute(path: String): Bool {
    path.startsWith("/api/") || path.startsWith("/repos/") ||
        path == "/mcp" || path.startsWith("/mcp/") ||
        path == "/health" || path == "/status" ||
        path == "/metrics"
}

private func p7DocumentationContainsCredential(value: String): Bool {
    let lower = value.toAsciiLower()
    lower.contains("sk-live-") || lower.contains("sk-proj-") ||
        lower.contains("ghp_") || lower.contains("bearer ey") ||
        p7DocumentationContainsUpperCredentialPrefix(value, "AKIA", 12) ||
        p7DocumentationContainsUpperCredentialPrefix(value, "ASIA", 12) ||
        p7DocumentationContainsMixedCredentialPrefix(value, "AIza", 10) ||
        lower.contains("github_pat_") ||
        lower.contains("glpat-") || lower.contains("xoxb-") ||
        lower.contains("xoxp-") || lower.contains("xoxa-") ||
        lower.contains("xoxr-") || lower.contains("xoxs-") ||
        lower.contains("ya29.") ||
        lower.contains("-----begin private key-----") ||
        lower.contains("private-token:") ||
        lower.contains("authorization:") ||
        lower.contains("x-api-key:")
}

private func p7DocumentationContainsBypass(lower: String): Bool {
    lower.contains("git add -f")
}

private func p7DocumentationContainsBenchmarkPayload(lower: String): Bool {
    // This gate detects observable benchmark identifiers and answer/test
    // markers. It cannot prove that unmarked prose is semantically unrelated.
    lower.contains("canonical_solution") || lower.contains("solution.cj") ||
        lower.contains("teacher-solutions") ||
        lower.contains("reference_solution") ||
        lower.contains("reference solution") ||
        lower.contains("teacher solution") ||
        lower.contains("hidden_test") ||
        lower.contains("hidden tests payload") ||
        p7DocumentationContainsHumanEvalCaseAfter(lower, "humaneval_") ||
        p7DocumentationContainsHumanEvalCaseAfter(lower, "humaneval/") ||
        p7DocumentationContainsHumanEvalCaseAfter(lower, "humaneval-") ||
        p7DocumentationContainsHumanEvalCaseAfter(lower, "humaneval.case.")
}

private func p7DocumentationContainsDriveAbsolutePath(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size < 3) { return false }
    for (index in 0..=(runes.size - 3)) {
        let boundary = index == 0 ||
            !((runes[index - 1] >= r'a' && runes[index - 1] <= r'z') ||
                (runes[index - 1] >= r'A' && runes[index - 1] <= r'Z'))
        if (boundary &&
            ((runes[index] >= r'a' && runes[index] <= r'z') ||
            (runes[index] >= r'A' && runes[index] <= r'Z')) &&
            runes[index + 1] == r':' &&
            (runes[index + 2] == r'\\' || runes[index + 2] == r'/')) {
            return true
        }
    }
    false
}

private func p7DocumentationContainsUncAbsolutePath(value: String): Bool {
    value.contains("\\\\")
}

private func p7DocumentationContainsUpperCredentialPrefix(
    value: String, prefix: String, minimumFollowing: Int64): Bool {
    let runes = value.toRuneArray()
    let prefixRunes = prefix.toRuneArray()
    if (runes.size < prefixRunes.size + minimumFollowing) { return false }
    for (start in 0..=(runes.size - prefixRunes.size - minimumFollowing)) {
        var matches = true
        for (offset in 0..prefixRunes.size) {
            if (runes[start + offset] != prefixRunes[offset]) {
                matches = false
                break
            }
        }
        if (!matches) { continue }
        for (offset in 0..minimumFollowing) {
            let rune = runes[start + prefixRunes.size + offset]
            if (!((rune >= r'A' && rune <= r'Z') ||
                (rune >= r'0' && rune <= r'9'))) {
                matches = false
                break
            }
        }
        if (matches) { return true }
    }
    false
}

private func p7DocumentationContainsMixedCredentialPrefix(
    value: String, prefix: String, minimumFollowing: Int64): Bool {
    let runes = value.toRuneArray()
    let prefixRunes = prefix.toRuneArray()
    if (runes.size < prefixRunes.size + minimumFollowing) { return false }
    for (start in 0..=(runes.size - prefixRunes.size - minimumFollowing)) {
        var matches = true
        for (offset in 0..prefixRunes.size) {
            if (runes[start + offset] != prefixRunes[offset]) {
                matches = false
                break
            }
        }
        if (matches) { return true }
    }
    false
}

private func p7DocumentationContainsHumanEvalCaseAfter(
    value: String, prefix: String): Bool {
    let valueRunes = value.toRuneArray()
    let prefixRunes = prefix.toRuneArray()
    if (prefixRunes.size == 0 || valueRunes.size < prefixRunes.size) {
        return false
    }
    for (start in 0..=(valueRunes.size - prefixRunes.size)) {
        var matches = true
        for (offset in 0..prefixRunes.size) {
            if (valueRunes[start + offset] != prefixRunes[offset]) {
                matches = false
                break
            }
        }
        if (!matches) { continue }
        var next = start + prefixRunes.size
        var caseId: Int64 = 0
        var digitCount: Int64 = 0
        while (next < valueRunes.size &&
            valueRunes[next] >= r'0' && valueRunes[next] <= r'9') {
            if (digitCount < 3) {
                caseId = caseId * 10 +
                    Int64(UInt32(valueRunes[next])) -
                    Int64(UInt32(r'0'))
            }
            digitCount += 1
            next += 1
        }
        if (digitCount > 0 && digitCount <= 3 && caseId <= 163) {
            return true
        }
    }
    false
}

private func p7DocumentationJoin(values: ArrayList<String>): String {
    let out = StringBuilder()
    for (value in values) {
        out.append(value)
        out.append("\n")
    }
    out.toString()
}

private func p7DocumentationCommandTokens(text: String): ArrayList<String> {
    let out = ArrayList<String>()
    let runes = text.toRuneArray()
    var token = StringBuilder()
    var index: Int64 = 0
    while (index <= runes.size) {
        let atEnd = index == runes.size
        let rune = if (atEnd) { r' ' } else { runes[index] }
        if (!atEnd && p7DocumentationCommandRune(rune)) {
            token.append(rune)
        } else {
            let value = token.toString()
            if (p7DocumentationCommandName(value) &&
                !p7DocumentationKnownArtifactName(value)) {
                out.add(value)
            }
            token = StringBuilder()
        }
        index += 1
    }
    out
}

private func p7DocumentationKnownArtifactName(value: String): Bool {
    value == "ckb-repro-placeholders.txt"
}

private func p7DocumentationCommandRune(rune: Rune): Bool {
    (rune >= r'a' && rune <= r'z') ||
        (rune >= r'A' && rune <= r'Z') ||
        (rune >= r'0' && rune <= r'9') ||
        rune == r'-' || rune == r'.'
}

private func p7DocumentationCommandName(value: String): Bool {
    value.startsWith("ckb-release-") ||
        value.startsWith("ckb-repro-") ||
        value.startsWith("cangjie-humaneval-")
}

private func p7ValidateDocumentationLinks(
    reader: CkbReproDocumentationReader, root: String, sourcePath: String,
    text: String): CkbReproDocumentationScan {
    let out = CkbReproDocumentationScan()
    let runes = text.toRuneArray()
    var index: Int64 = 0
    while (index < runes.size) {
        if (runes[index] != r']' || index + 1 >= runes.size ||
            runes[index + 1] != r'(') {
            index += 1
            continue
        }
        var end = index + 2
        while (end < runes.size && runes[end] != r')' &&
            runes[end] != r'\n' && runes[end] != r'\r') {
            end += 1
        }
        if (end >= runes.size || runes[end] != r')') {
            out.findingCount = 1
            out.diagnostic = "documentation_link_malformed"
            return out
        }
        let targetBuilder = StringBuilder()
        for (i in (index + 2)..end) { targetBuilder.append(runes[i]) }
        let target = targetBuilder.toString()
        if (target == "") {
            out.findingCount = 1
            out.diagnostic = "documentation_link_malformed"
            return out
        }
        if (!p7DocumentationExternalLink(target)) {
            let targetParts = p7DocumentationLinkParts(target)
            let resolved = if (targetParts[0] == "") {
                sourcePath
            } else {
                p7DocumentationResolveLink(sourcePath, targetParts[0])
            }
            let linked = if (resolved == sourcePath) {
                CkbReproDocumentationRead()
            } else {
                reader.read(root, resolved)
            }
            if (resolved == "" ||
                (resolved != sourcePath && !linked.found)) {
                out.findingCount = 1
                out.diagnostic = "documentation_link_broken"
                return out
            }
            if (targetParts[2] == "fragment") {
                if (targetParts[1] == "") {
                    out.findingCount = 1
                    out.diagnostic = "documentation_link_malformed"
                    return out
                }
                let linkedText = if (resolved == sourcePath) {
                    ("ok", text)
                } else {
                    p7DocumentationDecode(linked.bytes)
                }
                if (linkedText[0] != "ok") {
                    out.findingCount = 1
                    out.diagnostic = linkedText[0]
                    return out
                }
                if (!p7DocumentationAnchorExists(
                    linkedText[1], targetParts[1])) {
                    out.findingCount = 1
                    out.diagnostic = "documentation_link_anchor_missing"
                    return out
                }
            }
        }
        index = end + 1
    }
    out.ok = true
    out.diagnostic = "documentation_links_valid"
    out
}

private func p7DocumentationExternalLink(target: String): Bool {
    target.startsWith("https://") || target.startsWith("http://") ||
        target.startsWith("mailto:")
}

private func p7DocumentationResolveLink(
    sourcePath: String, target: String): String {
    if (target == "" || target.startsWith("/") ||
        target.contains("\\") || target.contains("?")) {
        return ""
    }
    let parts = ArrayList<String>()
    let sourceParts = sourcePath.split("/")
    for (i in 0..(sourceParts.size - 1)) { parts.add(sourceParts[i]) }
    for (part in target.split("/")) {
        if (part == "" || part == ".") { continue }
        if (part == "..") {
            if (parts.size == 0) { return "" }
            parts.remove(at: parts.size - 1)
        } else {
            parts.add(part)
        }
    }
    if (parts.size == 0) { return "" }
    let out = StringBuilder()
    for (i in 0..parts.size) {
        if (i > 0) { out.append("/") }
        out.append(parts[i])
    }
    out.toString()
}

private func p7DocumentationLinkParts(value: String):
    (String, String, String) {
    let path = StringBuilder()
    let anchor = StringBuilder()
    var fragment = false
    for (rune in value.runes()) {
        if (!fragment && rune == r'#') {
            fragment = true
            continue
        }
        if (fragment) { anchor.append(rune) } else { path.append(rune) }
    }
    (path.toString(), anchor.toString(),
        if (fragment) { "fragment" } else { "none" })
}

private func p7DocumentationAnchorExists(
    text: String, expected: String): Bool {
    let canonicalExpected = p7DocumentationCanonicalAnchor(expected)
    if (canonicalExpected == "") { return false }
    if (p7DocumentationExplicitAnchorExists(text, expected)) { return true }
    let occupied = HashSet<String>()
    for (line in text.split("\n")) {
        let heading = p7DocumentationHeadingText(line)
        if (heading == "") { continue }
        let base = p7DocumentationCanonicalAnchor(heading)
        if (base == "") { continue }
        var candidate = base
        var suffix: Int64 = 0
        while (occupied.contains(candidate)) {
            suffix += 1
            candidate = "${base}-${suffix}"
        }
        occupied.add(candidate)
        if (candidate == canonicalExpected) {
            return true
        }
    }
    false
}

private func p7DocumentationHeadingText(line: String): String {
    let runes = line.trimAscii().toRuneArray()
    if (runes.size < 2 || runes[0] != r'#') { return "" }
    var index: Int64 = 0
    while (index < runes.size && runes[index] == r'#') { index += 1 }
    if (index >= runes.size || runes[index] != r' ') { return "" }
    while (index < runes.size && runes[index] == r' ') { index += 1 }
    let out = StringBuilder()
    while (index < runes.size) {
        out.append(runes[index])
        index += 1
    }
    out.toString()
}

private func p7DocumentationExplicitAnchorExists(
    text: String, expected: String): Bool {
    var fenced = false
    for (line in text.split("\n")) {
        let trimmed = line.trimAscii()
        if (trimmed.startsWith("```")) {
            fenced = !fenced
            continue
        }
        if (fenced) { continue }
        let visible = p7DocumentationOutsideInlineCode(line)
        let runes = visible.toRuneArray()
        var index: Int64 = 0
        while (index < runes.size) {
            if (runes[index] != r'<') {
                index += 1
                continue
            }
            var end = index + 1
            while (end < runes.size && runes[end] != r'>') { end += 1 }
            if (end >= runes.size) { break }
            let tagBuilder = StringBuilder()
            for (i in index..=end) { tagBuilder.append(runes[i]) }
            let tag = tagBuilder.toString().replace("\t", " ")
            let lower = tag.toAsciiLower()
            let opening = lower.size > 2 && lower.startsWith("<") &&
                !lower.startsWith("</") && !lower.startsWith("<!")
            if (opening &&
                (p7DocumentationHtmlAttribute(tag, "id", expected) ||
                    (lower.startsWith("<a ") &&
                        p7DocumentationHtmlAttribute(
                            tag, "name", expected)))) {
                return true
            }
            index = end + 1
        }
    }
    false
}

private func p7DocumentationHtmlAttribute(
    tag: String, attribute: String, expected: String): Bool {
    tag.contains(" ${attribute}=\"${expected}\"") ||
        tag.contains(" ${attribute}='${expected}'")
}

private func p7DocumentationOutsideInlineCode(line: String): String {
    let out = StringBuilder()
    var code = false
    for (rune in line.runes()) {
        if (rune == r'`') {
            code = !code
        } else if (!code) {
            out.append(rune)
        }
    }
    out.toString()
}

// This is the GitHub-style subset required by the public runbooks: link labels
// and inline-code text remain visible, Markdown destinations and code markers
// are removed, ASCII/CJK punctuation is removed, Unicode whitespace becomes
// '-', and duplicate headings are suffixed by AnchorExists with -1, -2, ...
private func p7DocumentationCanonicalAnchor(value: String): String {
    let visible = p7DocumentationHeadingVisibleText(value)
    let normalized = ArrayList<Rune>()
    var pendingDash = false
    for (rune in visible.toAsciiLower().runes()) {
        if ((rune >= r'a' && rune <= r'z') ||
            (rune >= r'0' && rune <= r'9') ||
            (rune > r'\u{007f}' &&
                !p7DocumentationUnicodeWhitespace(rune) &&
                !p7DocumentationUnicodePunctuation(rune))) {
            if (pendingDash && normalized.size > 0 &&
                normalized[normalized.size - 1] != r'-') {
                normalized.add(r'-')
            }
            pendingDash = false
            normalized.add(rune)
        } else if (rune == r'-') {
            pendingDash = false
            if (normalized.size > 0 &&
                normalized[normalized.size - 1] != r'-') {
                normalized.add(rune)
            }
        } else if (rune == r' ' || rune == r'\t' ||
            p7DocumentationUnicodeWhitespace(rune)) {
            pendingDash = true
        }
    }
    let out = StringBuilder()
    for (rune in normalized) { out.append(rune) }
    out.toString()
}

private func p7DocumentationHeadingVisibleText(value: String): String {
    let runes = value.toRuneArray()
    let out = StringBuilder()
    var index: Int64 = 0
    while (index < runes.size) {
        if (runes[index] == r'`') {
            index += 1
            continue
        }
        if (runes[index] == r'[') {
            var labelEnd = index + 1
            while (labelEnd < runes.size && runes[labelEnd] != r']') {
                out.append(runes[labelEnd])
                labelEnd += 1
            }
            if (labelEnd < runes.size && labelEnd + 1 < runes.size &&
                runes[labelEnd + 1] == r'(') {
                var destinationEnd = labelEnd + 2
                while (destinationEnd < runes.size &&
                    runes[destinationEnd] != r')') {
                    destinationEnd += 1
                }
                index = if (destinationEnd < runes.size) {
                    destinationEnd + 1
                } else {
                    labelEnd + 1
                }
                continue
            }
            index = labelEnd + 1
            continue
        }
        out.append(runes[index])
        index += 1
    }
    out.toString()
}

private func p7DocumentationUnicodeWhitespace(rune: Rune): Bool {
    (rune >= r'\u{2000}' && rune <= r'\u{200a}') ||
        rune == r'\u{202f}' || rune == r'\u{205f}' ||
        rune == r'\u{3000}'
}

private func p7DocumentationUnicodePunctuation(rune: Rune): Bool {
    (rune >= r'\u{2010}' && rune <= r'\u{206f}') ||
        (rune >= r'\u{3001}' && rune <= r'\u{303f}') ||
        (rune >= r'\u{ff01}' && rune <= r'\u{ff0f}') ||
        (rune >= r'\u{ff1a}' && rune <= r'\u{ff20}') ||
        (rune >= r'\u{ff3b}' && rune <= r'\u{ff40}') ||
        (rune >= r'\u{ff5b}' && rune <= r'\u{ff65}')
}
