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
    item.crawlAt = "manifest"
    item.indexedAt = status.activeKnowledgeVersion
    item.staleness = if (source.contentHash == "" || source.resolvedCommit == "") { "unknown" } else { "fresh" }
    item.status = if (status.failedCandidateVersion != "") { "active_candidate_failed" } else if (status.candidateKnowledgeVersion != "") { "active_with_candidate" } else { "active" }
    item
}

public func renderCangjieCorpusFreshnessJson(report: CangjieCorpusFreshnessReport): String {
    renderCangjieCorpusFreshnessResultJson(cangjieCorpusFreshnessResultFromReport(report))
}
