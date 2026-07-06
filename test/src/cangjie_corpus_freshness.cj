package cangjie_community_knowledge_base_test

import std.collection.ArrayList

public class CangjieCorpusFreshnessSource {
    public var sourceSet: String = ""
    public var sourceFamily: String = ""
    public var sourceRepo: String = ""
    public var sourceRef: String = ""
    public var refKind: String = ""
    public var resolvedCommit: String = ""
    public var contentHash: String = ""
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var crawlAt: String = ""
    public var indexedAt: String = ""
    public var staleness: String = "unknown"
    public var status: String = "active"

    public init() {}
}

public class CangjieCorpusFreshnessReport {
    public var ok: Bool = true
    public var activeKnowledgeVersion: String = ""
    public var candidateKnowledgeVersion: String = ""
    public var failedCandidateVersion: String = ""
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var degraded: Bool = false
    public var diagnostics: ArrayList<String> = ArrayList<String>()
    public var sources: ArrayList<CangjieCorpusFreshnessSource> = ArrayList<CangjieCorpusFreshnessSource>()

    public init() {}
}

public func cangjieCorpusFreshnessReport(status: KnowledgeStatus, manifest!: CangjieVersionManifest = defaultCangjieVersionManifest()): CangjieCorpusFreshnessReport {
    let report = CangjieCorpusFreshnessReport()
    report.activeKnowledgeVersion = status.activeKnowledgeVersion
    report.candidateKnowledgeVersion = status.candidateKnowledgeVersion
    report.failedCandidateVersion = status.failedCandidateVersion
    report.targetVersion = manifest.defaultTargetVersion
    report.degraded = true
    report.diagnostics.add("synthetic_freshness")
    if (status.activeKnowledgeVersion == "") {
        report.ok = false
        report.diagnostics.add("missing_active_knowledge_version")
    }
    if (manifest.sources.size == 0) {
        report.ok = false
        report.diagnostics.add("version_manifest_empty")
    }
    for (source in manifest.sources) {
        report.sources.add(cangjieFreshnessSourceFromManifest(source, status))
    }
    report
}

private func cangjieFreshnessSourceFromManifest(source: CangjieVersionSource, status: KnowledgeStatus): CangjieCorpusFreshnessSource {
    let item = CangjieCorpusFreshnessSource()
    item.sourceSet = source.sourceSet
    item.sourceFamily = source.sourceFamily
    item.sourceRepo = source.sourceRepo
    item.sourceRef = source.sourceRef
    item.refKind = source.refKind
    item.resolvedCommit = source.resolvedCommit
    item.contentHash = source.contentHash
    item.targetVersion = source.targetVersion
    item.crawlAt = if (source.sourceRef == "" && source.resolvedCommit == "") { "unknown" } else { "manifest" }
    item.indexedAt = status.activeKnowledgeVersion
    item.staleness = if (source.contentHash == "" || source.resolvedCommit == "") { "unknown" } else { "indexed" }
    item.status = if (status.failedCandidateVersion != "") { "active_candidate_failed" } else if (status.candidateKnowledgeVersion != "") { "active_with_candidate" } else { "active" }
    item
}

public func probeCangjieCorpusFreshness(manifest: CangjieVersionManifest, runner: SourceFetchRunner): CangjieCorpusFreshnessReport {
    let report = CangjieCorpusFreshnessReport()
    report.targetVersion = manifest.defaultTargetVersion
    if (manifest.sources.size == 0) {
        report.ok = false
        report.degraded = true
        report.diagnostics.add("version_manifest_empty")
        return report
    }
    let builder = SourceRequestBuilder()
    for (source in manifest.sources) {
        let request = cangjieFreshnessProbeRequest(builder, source)
        let fetch = SourceResponseNormalizer().normalize(request, runner.fetch(request))
        let item = cangjieFreshnessSourceFromProbe(source, fetch)
        report.sources.add(item)
        if (!fetch.ok) {
            report.ok = false
            report.degraded = true
            report.diagnostics.add("${source.sourceSet}:probe_failed:${fetch.status}")
        } else if (item.staleness == "stale" || item.staleness == "unknown") {
            report.ok = false
            report.degraded = true
            report.diagnostics.add("${source.sourceSet}:staleness_${item.staleness}")
        }
    }
    report
}

private func cangjieFreshnessProbeRequest(builder: SourceRequestBuilder, source: CangjieVersionSource): SourceFetchRequest {
    if (source.sourceSet == CangjieSourceSets.DOCS) {
        return builder.docs("https://docs.cangjie-lang.cn/docs/1.0.0/")
    }
    if (source.sourceRepo != "") {
        return builder.gitCodeRepo(source.sourceRepo, ref: if (source.sourceRef == "") { "release-1.0.0" } else { source.sourceRef })
    }
    builder.docs("https://docs.cangjie-lang.cn/docs/1.0.0/")
}

private func cangjieFreshnessSourceFromProbe(source: CangjieVersionSource, fetch: SourceFetchResult): CangjieCorpusFreshnessSource {
    let item = CangjieCorpusFreshnessSource()
    item.sourceSet = source.sourceSet
    item.sourceFamily = source.sourceFamily
    item.sourceRepo = source.sourceRepo
    item.sourceRef = if (fetch.ref != "") { fetch.ref } else { source.sourceRef }
    item.refKind = source.refKind
    item.resolvedCommit = if (fetch.commit != "") { fetch.commit } else { source.resolvedCommit }
    item.contentHash = if (fetch.bodyHash != "") { fetch.bodyHash } else { source.contentHash }
    item.targetVersion = source.targetVersion
    item.crawlAt = if (fetch.lastModified != "") { fetch.lastModified } else { "probe" }
    item.indexedAt = source.resolvedCommit
    if (!fetch.ok) {
        item.staleness = "failed"
        item.status = fetch.status
    } else if (source.contentHash == "" && source.resolvedCommit == "") {
        item.staleness = "unknown"
        item.status = "degraded"
    } else if ((source.contentHash != "" && source.contentHash == fetch.bodyHash) || (source.resolvedCommit != "" && source.resolvedCommit == fetch.commit)) {
        item.staleness = "fresh"
        item.status = "fresh"
    } else {
        item.staleness = "stale"
        item.status = "stale"
    }
    item
}

public func renderCangjieCorpusFreshnessJson(report: CangjieCorpusFreshnessReport): String {
    renderCangjieCorpusFreshnessResultJson(cangjieCorpusFreshnessResultFromReport(report))
}
