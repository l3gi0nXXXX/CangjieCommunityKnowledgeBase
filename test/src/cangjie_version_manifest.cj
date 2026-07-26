package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists}

public class CangjieVersionPolicies {
    public static let DEFAULT: String = "default"
    public static let EXACT: String = "exact"
}

public class CangjieSourceSets {
    public static let ALL: String = "all"
    public static let DOCS: String = "docs"
    public static let STD: String = "std"
    public static let STDX: String = "stdx"
    public static let TOOLS: String = "tools"
    public static let EVAL_SUPPORT: String = "eval-support"
    public static let KNOWLEDGE_ATOMS: String = "knowledge-atoms"
}

public class CangjieVersionManifestVersions {
    public static let V1: String = "cangjie-version-manifest-v1"
    public static let V2: String = "cangjie-version-manifest-v2"
}

public class CangjieVersionSelector {
    public var targetVersion: String = ""
    public var sourceSet: String = CangjieSourceSets.ALL
    public var sourceFamily: String = ""
    public var sourceRepo: String = ""
    public var sourceRef: String = ""
    public var refKind: String = ""
    public var versionPolicy: String = CangjieVersionPolicies.DEFAULT
    public var includePrerelease: Bool = false

    public init() {}
}

public class CangjieVersionSource {
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var sourceSet: String = ""
    public var sourceFamily: String = ""
    public var sourceRepo: String = ""
    public var sourceRef: String = ""
    public var refKind: String = "branch"
    public var resolvedCommit: String = ""
    public var contentHash: String = ""
    public var rootKind: String = ""

    public init() {}
}

public class CangjieVersionManifest {
    public var manifestVersion: String = CangjieVersionManifestVersions.V1
    public var defaultTargetVersion: String = cangjieDefaultTargetVersion()
    public var degraded: Bool = false
    public var sources: ArrayList<CangjieVersionSource> = ArrayList<CangjieVersionSource>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class CangjieVersionResolution {
    public var ok: Bool = false
    public var diagnostic: String = ""
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var versionPolicy: String = CangjieVersionPolicies.DEFAULT
    public var versionResolutionId: String = ""
    public var defaulted: Bool = false
    public var sources: ArrayList<CangjieVersionSource> = ArrayList<CangjieVersionSource>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public func defaultCangjieVersionManifest(): CangjieVersionManifest {
    let manifest = CangjieVersionManifest()
    manifest.sources.add(cangjieManifestSource(CangjieSourceSets.DOCS, "docs", "Cangjie/cangjie_docs", "release-1.0.0", "branch", "offline-baseline-docs", "sha256:ckb-docs-1-0-0"))
    manifest.sources.add(cangjieManifestSource(CangjieSourceSets.STD, "stdlib", "Cangjie/cangjie_runtime", "release-1.0.0", "branch", "offline-baseline-std", "sha256:ckb-std-1-0-0"))
    manifest.sources.add(cangjieManifestSource(CangjieSourceSets.STDX, "stdx", "Cangjie/cangjie_stdx", "release-1.0.0", "branch", "offline-baseline-stdx", "sha256:ckb-stdx-1-0-0"))
    manifest.sources.add(cangjieManifestSource(CangjieSourceSets.TOOLS, "tools", "Cangjie/cangjie_tools", "release-1.0.0", "branch", "offline-baseline-tools", "sha256:ckb-tools-1-0-0"))
    manifest.sources.add(cangjieManifestSource(CangjieSourceSets.EVAL_SUPPORT, "eval-support", "CangjieCommunityKnowledgeBase/Cangjie-HumanEval", "release-1.0.0", "branch", "offline-baseline-eval", "sha256:ckb-eval-1-0-0"))
    manifest
}

public func cangjieSourceRefAliasesForTargetVersion(targetVersion: String): ArrayList<String> {
    let aliases = ArrayList<String>()
    let version = if (targetVersion.trimAscii() == "") { cangjieDefaultTargetVersion() } else { targetVersion.trimAscii() }
    if (version == "1.0.0") {
        aliases.add("release/1.0")
        aliases.add("release-1.0.0")
    }
    aliases
}

public func buildCangjieVersionManifestFromRoots(targetVersion!: String = "", docsRoot!: String = "", toolDocsRoot!: String = "", stdRoot!: String = "", stdxRoot!: String = "", evalRoot!: String = ""): CangjieVersionManifest {
    let manifest = CangjieVersionManifest()
    manifest.defaultTargetVersion = if (targetVersion.trimAscii() == "") { cangjieDefaultTargetVersion() } else { targetVersion.trimAscii() }
    let explicitRoot = cangjieManifestAnyRootConfigured(docsRoot, toolDocsRoot, stdRoot, stdxRoot, evalRoot)
    cangjieManifestAddRootSource(manifest, CangjieSourceSets.DOCS, "docs", "Cangjie/cangjie_docs", docsRoot)
    let toolsRoot = if (toolDocsRoot.trimAscii() == "") { docsRoot } else { toolDocsRoot }
    cangjieManifestAddRootSource(manifest, CangjieSourceSets.TOOLS, "tools", "Cangjie/cangjie_tools", toolsRoot)
    cangjieManifestAddRootSource(manifest, CangjieSourceSets.STD, "stdlib", "Cangjie/cangjie_runtime", stdRoot)
    cangjieManifestAddRootSource(manifest, CangjieSourceSets.STDX, "stdx", "Cangjie/cangjie_stdx", stdxRoot)
    cangjieManifestAddRootSource(manifest, CangjieSourceSets.EVAL_SUPPORT, "eval-support", "CangjieCommunityKnowledgeBase/Cangjie-HumanEval", evalRoot)
    if (manifest.sources.size == 0) {
        if (explicitRoot) {
            manifest.degraded = true
            if (manifest.diagnostics.size == 0) {
                manifest.diagnostics.add("version_manifest_no_valid_roots")
            }
            return manifest
        }
        return defaultCangjieVersionManifest()
    }
    manifest
}

public func resolveCangjieVersion(selector: CangjieVersionSelector, manifest: CangjieVersionManifest): CangjieVersionResolution {
    let resolution = CangjieVersionResolution()
    let policy = cangjieCleanVersionPolicy(selector.versionPolicy)
    let sourceSet = cangjieCleanSourceSet(selector.sourceSet)
    let version = cangjieNormalizeTargetVersionResult(selector.targetVersion)
    resolution.targetVersion = version.value
    resolution.versionPolicy = policy
    resolution.defaulted = version.normalized
    if (version.normalized && version.diagnostic != "") {
        resolution.diagnostics.add(version.diagnostic)
    }
    if (!cangjieSourceSetAllowed(sourceSet)) {
        resolution.diagnostic = "unsupported_source_set"
        resolution.diagnostics.add("unsupported_source_set:${sourceSet}")
        resolution.versionResolutionId = cangjieVersionResolutionId(resolution,
            manifest.manifestVersion)
        return resolution
    }
    if (policy == CangjieVersionPolicies.EXACT && selector.sourceRef.trimAscii() == "") {
        resolution.diagnostic = "exact_source_ref_required"
        resolution.diagnostics.add("exact_source_ref_required")
        resolution.versionResolutionId = cangjieVersionResolutionId(resolution,
            manifest.manifestVersion)
        return resolution
    }
    for (source in manifest.sources) {
        if (cangjieVersionSourceMatches(source, selector, sourceSet, resolution.targetVersion)) {
            resolution.sources.add(cangjieCopyVersionSource(source))
        }
    }
    if (resolution.sources.size == 0) {
        resolution.diagnostic = if (policy == CangjieVersionPolicies.EXACT) { "exact_source_ref_not_resolved" } else { "version_not_resolved" }
        resolution.diagnostics.add(resolution.diagnostic)
        resolution.versionResolutionId = cangjieVersionResolutionId(resolution,
            manifest.manifestVersion)
        return resolution
    }
    resolution.ok = true
    resolution.diagnostic = if (resolution.defaulted) { "target_version_defaulted" } else { "ok" }
    resolution.versionResolutionId = cangjieVersionResolutionId(resolution,
        manifest.manifestVersion)
    resolution
}

// Student responses may describe public documentation sources, but benchmark
// authority and eval-support lineage remain private even when the caller uses
// the aggregate "all" selector.
public func cangjieStudentVersionResolution(
    source: CangjieVersionResolution): CangjieVersionResolution {
    let out = CangjieVersionResolution()
    out.ok = source.ok
    out.diagnostic = source.diagnostic
    out.targetVersion = source.targetVersion
    out.versionPolicy = source.versionPolicy
    out.versionResolutionId = source.versionResolutionId
    out.defaulted = source.defaulted
    for (item in source.sources) {
        if (item.sourceSet == CangjieSourceSets.EVAL_SUPPORT ||
            item.sourceFamily.toAsciiLower().contains("eval-support") ||
            item.sourceRepo.toAsciiLower().contains("humaneval")) {
            continue
        }
        out.sources.add(item)
    }
    for (diagnostic in source.diagnostics) { out.diagnostics.add(diagnostic) }
    if (source.ok && source.sources.size > 0 && out.sources.size == 0) {
        out.ok = false
        out.diagnostic = "student_source_not_visible"
        out.diagnostics.add("student_source_not_visible")
    }
    out
}

public func cangjieVersionSelector(targetVersion!: String = "", sourceSet!: String = "", sourceFamily!: String = "", sourceRepo!: String = "", sourceRef!: String = "", refKind!: String = "", versionPolicy!: String = "", includePrerelease!: Bool = false): CangjieVersionSelector {
    let selector = CangjieVersionSelector()
    selector.targetVersion = targetVersion
    selector.sourceSet = if (sourceSet.trimAscii() == "") { CangjieSourceSets.ALL } else { sourceSet.trimAscii() }
    selector.sourceFamily = sourceFamily.trimAscii()
    selector.sourceRepo = sourceRepo.trimAscii()
    selector.sourceRef = sourceRef.trimAscii()
    selector.refKind = refKind.trimAscii()
    selector.versionPolicy = cangjieCleanVersionPolicy(versionPolicy)
    selector.includePrerelease = includePrerelease
    selector
}

public func cangjieManifestHasOfflineBaseline(manifest: CangjieVersionManifest): Bool {
    for (source in manifest.sources) {
        if (source.rootKind == "offline-baseline" || source.resolvedCommit.startsWith("offline-baseline")) {
            return true
        }
    }
    false
}

public func cangjieManifestEvidenceHash(manifest: CangjieVersionManifest): String {
    let text = StringBuilder()
    text.append(manifest.manifestVersion)
    text.append("|")
    text.append(manifest.defaultTargetVersion)
    text.append("|")
    text.append("${manifest.degraded}")
    for (diagnostic in manifest.diagnostics) {
        text.append("|diagnostic:")
        text.append(diagnostic)
    }
    for (source in manifest.sources) {
        text.append("|source:")
        text.append(source.targetVersion)
        text.append(":")
        text.append(source.sourceSet)
        text.append(":")
        text.append(source.sourceFamily)
        text.append(":")
        text.append(source.sourceRepo)
        text.append(":")
        text.append(source.sourceRef)
        text.append(":")
        text.append(source.refKind)
        text.append(":")
        text.append(source.resolvedCommit)
        text.append(":")
        text.append(source.contentHash)
        text.append(":")
        text.append(source.rootKind)
    }
    stableSummaryHash(text.toString())
}

public func cangjieManifestEvalSupportLocalSource(targetVersion: String, sourceRef: String, resolvedCommit: String, contentHash: String): CangjieVersionSource {
    let source = CangjieVersionSource()
    source.targetVersion = if (targetVersion.trimAscii() == "") { cangjieDefaultTargetVersion() } else { targetVersion.trimAscii() }
    source.sourceSet = CangjieSourceSets.EVAL_SUPPORT
    source.sourceFamily = "eval-support"
    source.sourceRepo = "ckb-local://eval-support"
    source.sourceRef = if (sourceRef.trimAscii() == "") { source.targetVersion } else { sourceRef.trimAscii() }
    source.refKind = "local"
    source.resolvedCommit = resolvedCommit.trimAscii()
    source.contentHash = contentHash.trimAscii()
    source.rootKind = "local-eval-support"
    source
}

private func cangjieManifestSource(sourceSet: String, sourceFamily: String, sourceRepo: String, sourceRef: String, refKind: String, resolvedCommit: String, contentHash: String): CangjieVersionSource {
    let source = CangjieVersionSource()
    source.targetVersion = cangjieDefaultTargetVersion()
    source.sourceSet = sourceSet
    source.sourceFamily = sourceFamily
    source.sourceRepo = sourceRepo
    source.sourceRef = sourceRef
    source.refKind = refKind
    source.resolvedCommit = resolvedCommit
    source.contentHash = contentHash
    source.rootKind = "offline-baseline"
    source
}

private func cangjieManifestAddRootSource(manifest: CangjieVersionManifest, sourceSet: String, sourceFamily: String, sourceRepo: String, root: String): Unit {
    let cleanRoot = root.trimAscii()
    if (cleanRoot == "") {
        return
    }
    if (!cangjieManifestRootAllowed(cleanRoot)) {
        cangjieManifestMarkDegraded(manifest, "${sourceSet}_root_invalid")
        return
    }
    let hash = cangjieManifestRootContentHash(cleanRoot)
    let git = cangjieManifestGitInfo(cleanRoot, manifest.defaultTargetVersion, hash)
    if (!git.ok) {
        cangjieManifestMarkDegraded(manifest, "${sourceSet}_${git.diagnostic}")
        return
    }
    let source = cangjieManifestSource(sourceSet, sourceFamily, sourceRepo, git.sourceRef, git.refKind, git.resolvedCommit, hash)
    source.targetVersion = manifest.defaultTargetVersion
    source.rootKind = git.rootKind
    manifest.sources.add(source)
}

private class CangjieManifestGitInfo {
    var ok: Bool = false
    var diagnostic: String = "git_metadata_missing"
    var sourceRef: String = ""
    var refKind: String = "local"
    var resolvedCommit: String = ""
    var rootKind: String = ""

    init() {}
}

private class CangjieManifestGitLocation {
    var ok: Bool = false
    var gitDir: String = ""
    var commonDir: String = ""
    var rootKind: String = ""

    init() {}
}

private class CangjieManifestHashState {
    var hash: Int64 = 5381
    var bytes: Int64 = 0
    var files: Int64 = 0

    init() {}
}

private func cangjieManifestGitInfo(root: String, targetVersion: String, contentHash: String): CangjieManifestGitInfo {
    let info = CangjieManifestGitInfo()
    let location = cangjieManifestGitLocation(root)
    if (!location.ok) {
        info.diagnostic = "git_metadata_missing"
        return info
    }
    info.rootKind = location.rootKind
    let head = cangjieManifestReadText("${location.gitDir}/HEAD")
    if (head == "") {
        info.diagnostic = "git_head_missing"
        return info
    }
    if (head.startsWith("ref: ")) {
        let ref = head[5..head.size].trimAscii()
        info.sourceRef = cangjieManifestSourceRefFromGitRef(ref)
        info.refKind = "branch"
        let commit = cangjieManifestGitRefCommit(location, ref)
        if (commit != "") {
            info.resolvedCommit = commit
            info.ok = true
            info.diagnostic = "ok"
        }
        if (!info.ok) {
            info.diagnostic = "git_ref_commit_missing"
        }
        return info
    }
    info.sourceRef = head
    info.refKind = "commit"
    info.resolvedCommit = head
    info.ok = true
    info.diagnostic = "ok"
    info
}

private func cangjieManifestGitLocation(root: String): CangjieManifestGitLocation {
    let location = CangjieManifestGitLocation()
    var current = try {
        canonicalize(Path(root))
    } catch (_: Exception) {
        return location
    }
    while (true) {
        let marker = current.join(".git")
        if (exists(marker.join("HEAD"))) {
            let gitDir = try {
                canonicalize(marker).toString()
            } catch (_: Exception) {
                return location
            }
            if (gitDir != marker.toString()) {
                return location
            }
            location.ok = true
            location.gitDir = gitDir
            location.commonDir = gitDir
            location.rootKind = "git-root"
            return location
        }
        if (exists(marker)) {
            return cangjieManifestWorktreeGitLocation(current, marker)
        }
        let parent = current.parent
        if (parent.toString() == current.toString()) {
            return location
        }
        current = parent
    }
    location
}

private func cangjieManifestWorktreeGitLocation(worktreeRoot: Path, marker: Path): CangjieManifestGitLocation {
    let location = CangjieManifestGitLocation()
    let text = cangjieManifestReadText(marker.toString())
    if (!text.startsWith("gitdir:")) {
        return location
    }
    let value = text[7..text.size].trimAscii()
    if (value == "" || value.contains("\u{0}")) {
        return location
    }
    let candidate = if (value.startsWith("/")) { Path(value) } else { worktreeRoot.join(value) }
    let gitDir = try {
        canonicalize(candidate).toString()
    } catch (_: Exception) {
        return location
    }
    if (!exists(Path(gitDir).join("HEAD")) || !cangjieManifestWorktreeBindingValid(gitDir, marker)) {
        return location
    }
    let commonDir = cangjieManifestWorktreeCommonGitDir(gitDir)
    if (commonDir == "") {
        return location
    }
    location.ok = true
    location.gitDir = gitDir
    location.commonDir = commonDir
    location.rootKind = "git-worktree"
    location
}

private func cangjieManifestWorktreeBindingValid(gitDir: String, marker: Path): Bool {
    let binding = cangjieManifestReadText("${gitDir}/gitdir")
    if (binding == "" || binding.contains("\u{0}")) {
        return false
    }
    let boundMarker = if (binding.startsWith("/")) { Path(binding) } else { Path(gitDir).join(binding) }
    try {
        canonicalize(boundMarker).toString() == canonicalize(marker).toString()
    } catch (_: Exception) {
        false
    }
}

private func cangjieManifestWorktreeCommonGitDir(gitDir: String): String {
    let marker = Path(gitDir).join("commondir")
    let value = cangjieManifestReadText("${gitDir}/commondir")
    if (!exists(marker) || value == "" || value.contains("\u{0}") || value.startsWith("/")) {
        return ""
    }
    let commonDir = try {
        canonicalize(Path(gitDir).join(value)).toString()
    } catch (_: Exception) {
        return ""
    }
    let worktrees = Path(gitDir).parent
    if (worktrees.fileName != "worktrees" || worktrees.parent.toString() != commonDir) {
        return ""
    }
    commonDir
}

private func cangjieManifestGitRefCommit(location: CangjieManifestGitLocation, ref: String): String {
    if (!cangjieManifestGitRefValid(ref)) {
        return ""
    }
    let local = cangjieManifestReadContainedGitRef(location.gitDir, ref)
    if (local != "") {
        return local
    }
    cangjieManifestReadContainedGitRef(location.commonDir, ref)
}

private func cangjieManifestGitRefValid(ref: String): Bool {
    if (!ref.startsWith("refs/") || ref == "refs/" || ref.contains("\u{0}") ||
        ref.contains("\t") || ref.contains("\n") || ref.contains("\r") || ref.contains("\u{7f}") ||
        ref.endsWith("/") || ref.contains("//") || ref.contains("\\") || ref.contains("..") ||
        ref.contains("~") || ref.contains("^") || ref.contains(":") || ref.contains("?") ||
        ref.contains("*") || ref.contains("[") || ref.contains("@{")) {
        return false
    }
    for (part in ref.split("/")) {
        if (part == "" || part.startsWith(".") || part.endsWith(".") || part.endsWith(".lock")) {
            return false
        }
        for (ch in part.toRuneArray()) {
            if (ch <= r' ') {
                return false
            }
        }
    }
    true
}

private func cangjieManifestReadContainedGitRef(root: String, ref: String): String {
    let canonicalRoot = try {
        canonicalize(Path(root)).toString()
    } catch (_: Exception) {
        return ""
    }
    let target = try {
        canonicalize(Path(root).join(ref)).toString()
    } catch (_: Exception) {
        return ""
    }
    if (!target.startsWith("${canonicalRoot}/")) {
        return ""
    }
    cangjieManifestReadText(target)
}

private func cangjieManifestSourceRefFromGitRef(ref: String): String {
    if (ref.startsWith("refs/heads/")) {
        return ref[11..ref.size]
    }
    if (ref.startsWith("refs/tags/")) {
        return ref[10..ref.size]
    }
    ref
}

private func cangjieManifestReadText(path: String): String {
    if (path.trimAscii() == "" || !exists(Path(path))) {
        return ""
    }
    try {
        String.fromUtf8(File.readFrom(Path(path))).trimAscii()
    } catch (_: Exception) {
        ""
    }
}

private func cangjieManifestRootContentHash(root: String): String {
    let state = CangjieManifestHashState()
    let files = ArrayList<String>()
    cangjieManifestCollectFiles(Path(root), "", files)
    for (relative in files) {
        cangjieManifestHashString(state, relative)
        try {
            cangjieManifestHashBytes(state, File.readFrom(Path(root).join(relative)))
            state.files += 1
        } catch (_: Exception) {
            cangjieManifestHashString(state, "unreadable:${relative}")
        }
    }
    "sha256:mh${state.hash}-${state.files}-${state.bytes}"
}

private func cangjieManifestCollectFiles(root: Path, relativeRoot: String, out: ArrayList<String>): Unit {
    try {
        for (entry in Directory.readFrom(root)) {
            let name = entry.name.trimAscii()
            if (name == "" || cangjieManifestIgnoredName(name)) {
                continue
            }
            let relative = if (relativeRoot == "") { name } else { "${relativeRoot}/${name}" }
            if (entry.isDirectory()) {
                cangjieManifestCollectFiles(entry.path, relative, out)
            } else if (entry.isRegular()) {
                cangjieManifestInsertSortedString(out, relative)
            }
        }
    } catch (_: Exception) {
        return
    }
}

private func cangjieManifestHashString(state: CangjieManifestHashState, text: String): Unit {
    cangjieManifestHashBytes(state, text.toArray())
}

private func cangjieManifestHashBytes(state: CangjieManifestHashState, bytes: Array<UInt8>): Unit {
    let modulus: Int64 = 2147483647
    for (b in bytes) {
        state.hash = ((state.hash * 33) % modulus + (Int64(b) % modulus)) % modulus
        state.bytes += 1
    }
    if (state.hash == 0) {
        state.hash = 1
    }
}

private func cangjieManifestRootAllowed(root: String): Bool {
    root != "" && !root.contains("\u{0}") && !root.contains("/.ssh") && !root.contains("/.config") && exists(Path(root))
}

private func cangjieManifestIgnoredName(name: String): Bool {
    let lower = name.toAsciiLower()
    lower == ".git" || lower == "target" || lower == "node_modules" || lower == "build" || lower == "dist"
}

private func cangjieManifestInsertSortedString(out: ArrayList<String>, value: String): Unit {
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

private func cangjieManifestSafeId(raw: String): String {
    let out = StringBuilder()
    for (ch in raw.toRuneArray()) {
        if ((ch >= r'a' && ch <= r'z') || (ch >= r'A' && ch <= r'Z') || (ch >= r'0' && ch <= r'9')) {
            out.append(ch)
        } else {
            out.append("-")
        }
    }
    let value = out.toString().toAsciiLower()
    if (value == "") { "unknown" } else { value }
}

private func cangjieCopyVersionSource(source: CangjieVersionSource): CangjieVersionSource {
    let out = CangjieVersionSource()
    out.targetVersion = source.targetVersion
    out.sourceSet = source.sourceSet
    out.sourceFamily = source.sourceFamily
    out.sourceRepo = source.sourceRepo
    out.sourceRef = source.sourceRef
    out.refKind = source.refKind
    out.resolvedCommit = source.resolvedCommit
    out.contentHash = source.contentHash
    out.rootKind = source.rootKind
    out
}

private func cangjieManifestAnyRootConfigured(docsRoot: String, toolDocsRoot: String, stdRoot: String, stdxRoot: String, evalRoot: String): Bool {
    docsRoot.trimAscii() != "" ||
        toolDocsRoot.trimAscii() != "" ||
        stdRoot.trimAscii() != "" ||
        stdxRoot.trimAscii() != "" ||
        evalRoot.trimAscii() != ""
}

private func cangjieManifestMarkDegraded(manifest: CangjieVersionManifest, diagnostic: String): Unit {
    manifest.degraded = true
    manifest.diagnostics.add(diagnostic)
}

private func cangjieCleanVersionPolicy(raw: String): String {
    let policy = raw.trimAscii().toAsciiLower()
    if (policy == CangjieVersionPolicies.EXACT) {
        return CangjieVersionPolicies.EXACT
    }
    CangjieVersionPolicies.DEFAULT
}

private func cangjieCleanSourceSet(raw: String): String {
    let value = raw.trimAscii().toAsciiLower()
    if (value == "") {
        return CangjieSourceSets.ALL
    }
    value
}

private func cangjieSourceSetAllowed(value: String): Bool {
    value == CangjieSourceSets.ALL ||
        value == CangjieSourceSets.DOCS ||
        value == CangjieSourceSets.STD ||
        value == CangjieSourceSets.STDX ||
        value == CangjieSourceSets.TOOLS ||
        value == CangjieSourceSets.EVAL_SUPPORT
}

private func cangjieVersionSourceMatches(source: CangjieVersionSource, selector: CangjieVersionSelector, sourceSet: String, targetVersion: String): Bool {
    if (source.targetVersion != targetVersion) {
        return false
    }
    if (sourceSet != CangjieSourceSets.ALL && source.sourceSet != sourceSet) {
        return false
    }
    if (selector.sourceFamily.trimAscii() != "" && source.sourceFamily != selector.sourceFamily.trimAscii()) {
        return false
    }
    if (selector.sourceRepo.trimAscii() != "" && source.sourceRepo != selector.sourceRepo.trimAscii()) {
        return false
    }
    if (selector.sourceRef.trimAscii() != "" && source.sourceRef != selector.sourceRef.trimAscii()) {
        return false
    }
    if (selector.refKind.trimAscii() != "" && source.refKind != selector.refKind.trimAscii()) {
        return false
    }
    true
}

private func cangjieVersionResolutionId(resolution: CangjieVersionResolution,
    manifestVersion: String): String {
    var seed = "${resolution.targetVersion}:${resolution.versionPolicy}:${resolution.diagnostic}"
    for (source in resolution.sources) {
        seed += "|${source.sourceSet}:${source.sourceRepo}:${source.sourceRef}:${source.resolvedCommit}:${source.contentHash}"
    }
    if (manifestVersion == CangjieVersionManifestVersions.V2) {
        return "cangjie-version-v2-${ckbReleaseEvidenceHash(seed)}"
    }
    // V1 and unknown legacy manifests retain the historical identifier so
    // persisted records remain query-compatible after upgrade.
    "cangjie-version-${stableSummaryHash(seed)}"
}
