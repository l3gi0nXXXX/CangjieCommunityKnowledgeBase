package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}

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
    public var manifestVersion: String = "cangjie-version-manifest-v1"
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
        resolution.versionResolutionId = cangjieVersionResolutionId(resolution)
        return resolution
    }
    if (policy == CangjieVersionPolicies.EXACT && selector.sourceRef.trimAscii() == "") {
        resolution.diagnostic = "exact_source_ref_required"
        resolution.diagnostics.add("exact_source_ref_required")
        resolution.versionResolutionId = cangjieVersionResolutionId(resolution)
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
        resolution.versionResolutionId = cangjieVersionResolutionId(resolution)
        return resolution
    }
    resolution.ok = true
    resolution.diagnostic = if (resolution.defaulted) { "target_version_defaulted" } else { "ok" }
    resolution.versionResolutionId = cangjieVersionResolutionId(resolution)
    resolution
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

private class CangjieManifestHashState {
    var hash: Int64 = 5381
    var bytes: Int64 = 0
    var files: Int64 = 0

    init() {}
}

private func cangjieManifestGitInfo(root: String, targetVersion: String, contentHash: String): CangjieManifestGitInfo {
    let info = CangjieManifestGitInfo()
    let gitDir = cangjieManifestGitDir(root)
    if (gitDir == "") {
        info.diagnostic = "git_metadata_missing"
        return info
    }
    info.rootKind = if (gitDir == "${root}/.git") { "git-root" } else { "git-worktree" }
    let head = cangjieManifestReadText("${gitDir}/HEAD")
    if (head == "") {
        info.diagnostic = "git_head_missing"
        return info
    }
    if (head.startsWith("ref: ")) {
        let ref = head[5..head.size].trimAscii()
        info.sourceRef = cangjieManifestSourceRefFromGitRef(ref)
        info.refKind = "branch"
        let commit = cangjieManifestReadText("${gitDir}/${ref}")
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

private func cangjieManifestGitDir(root: String): String {
    let dotGit = "${root}/.git"
    if (exists(Path("${dotGit}/HEAD"))) {
        return dotGit
    }
    if (!exists(Path(dotGit))) {
        return ""
    }
    let text = cangjieManifestReadText(dotGit)
    if (!text.startsWith("gitdir:")) {
        return ""
    }
    let value = text[7..text.size].trimAscii()
    if (value == "" || value.contains("\u{0}")) {
        return ""
    }
    if (value.startsWith("/")) {
        return value
    }
    "${root}/${value}"
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

private func cangjieVersionResolutionId(resolution: CangjieVersionResolution): String {
    var seed = "${resolution.targetVersion}:${resolution.versionPolicy}:${resolution.diagnostic}"
    for (source in resolution.sources) {
        seed += "|${source.sourceSet}:${source.sourceRepo}:${source.sourceRef}:${source.resolvedCommit}:${source.contentHash}"
    }
    "cangjie-version-${stableSummaryHash(seed)}"
}
