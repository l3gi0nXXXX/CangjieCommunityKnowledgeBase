package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashSet}

public let CKB_REPRO_DOCUMENTATION_MODE_DRAFT: String = "draft"
public let CKB_REPRO_DOCUMENTATION_MODE_RELEASE: String = "release"

public class CkbReproDocumentationRead {
    public var found: Bool = false
    public var bytes: Array<UInt8> = Array<UInt8>()
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
    func list(root: String): ArrayList<String>
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
    for (forbidden in [
        "/users/", "/home/", "c:\\users\\", "/var/folders/",
        "git add -f", "canonical_solution", "solution.cj",
        "teacher-solutions", "sk-live-", "bearer ey",
        "private-token:", "authorization: bearer", "x-api-key:"
    ]) {
        if (lower.contains(forbidden)) { out.findingCount += 1 }
    }
    if (lower.contains("humaneval/") &&
        (lower.contains("hidden_test") || lower.contains("hidden test") ||
            lower.contains("reference solution"))) {
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
    evidence.discoveredDocumentCount = listed.size
    let expected = HashSet<String>()
    for (path in required) { expected.add(path) }
    let seen = HashSet<String>()
    for (path in listed) {
        if (!p7DocumentationRelativePathValid(path)) {
            evidence.diagnostic = "documentation_entry_path_invalid"
            return evidence
        }
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
            (!decoded[1].contains("目的") ||
                !decoded[1].contains("通过标准") ||
                !decoded[1].contains("失败处理"))) {
            evidence.diagnostic = "documentation_required_section_missing"
            return evidence
        }
        texts.add(decoded[1])
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
            let followedByDot = !atEnd && rune == r'.'
            if (!followedByDot && p7DocumentationCommandName(value)) {
                out.add(value)
            }
            token = StringBuilder()
        }
        index += 1
    }
    out
}

private func p7DocumentationCommandRune(rune: Rune): Bool {
    (rune >= r'a' && rune <= r'z') ||
        (rune >= r'A' && rune <= r'Z') ||
        (rune >= r'0' && rune <= r'9') || rune == r'-'
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
        if (!p7DocumentationExternalOrAnchorLink(target)) {
            let resolved = p7DocumentationResolveLink(sourcePath, target)
            if (resolved == "" || !reader.read(root, resolved).found) {
                out.findingCount = 1
                out.diagnostic = "documentation_link_broken"
                return out
            }
        }
        index = end + 1
    }
    out.ok = true
    out.diagnostic = "documentation_links_valid"
    out
}

private func p7DocumentationExternalOrAnchorLink(target: String): Bool {
    target.startsWith("#") || target.startsWith("https://") ||
        target.startsWith("http://") || target.startsWith("mailto:")
}

private func p7DocumentationResolveLink(
    sourcePath: String, target: String): String {
    let withoutFragment = p7DocumentationBeforeFragment(target)
    if (withoutFragment == "" || withoutFragment.startsWith("/") ||
        withoutFragment.contains("\\") ||
        withoutFragment.contains("?")) {
        return ""
    }
    let parts = ArrayList<String>()
    let sourceParts = sourcePath.split("/")
    for (i in 0..(sourceParts.size - 1)) { parts.add(sourceParts[i]) }
    for (part in withoutFragment.split("/")) {
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

private func p7DocumentationBeforeFragment(value: String): String {
    let out = StringBuilder()
    for (rune in value.runes()) {
        if (rune == r'#') { break }
        out.append(rune)
    }
    out.toString()
}
