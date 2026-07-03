package cangjie_community_knowledge_base_test

import std.collection.ArrayList

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

    public init() {}
}

public class CangjieVersionManifest {
    public var manifestVersion: String = "cangjie-version-manifest-v1"
    public var defaultTargetVersion: String = cangjieDefaultTargetVersion()
    public var sources: ArrayList<CangjieVersionSource> = ArrayList<CangjieVersionSource>()

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
    for (source in manifest.sources) {
        if (cangjieVersionSourceMatches(source, selector, sourceSet, resolution.targetVersion)) {
            resolution.sources.add(cangjieCopyVersionSource(source))
        }
    }
    if (resolution.sources.size == 0) {
        resolution.diagnostic = "version_not_resolved"
        resolution.diagnostics.add("version_not_resolved")
        resolution.versionResolutionId = cangjieVersionResolutionId(resolution)
        return resolution
    }
    resolution.ok = true
    resolution.diagnostic = if (resolution.defaulted) { "target_version_defaulted" } else { "ok" }
    if (policy == CangjieVersionPolicies.EXACT && selector.sourceRef.trimAscii() == "") {
        resolution.diagnostics.add("exact_policy_without_source_ref")
    }
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
    source
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
    out
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
