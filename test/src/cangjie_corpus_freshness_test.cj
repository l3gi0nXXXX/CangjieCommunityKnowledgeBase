package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.*

@Test
public class CangjieCorpusFreshnessTest {
    @TestCase
    public func p6Ut001FreshnessReportListsVersionedSources(): Unit {
        let report = cangjieCorpusFreshnessReport(newOfflineKnowledgeBase().status())

        @Expect(report.ok, true)
        @Expect(report.degraded, false)
        @Expect(report.diagnostics.contains("synthetic_freshness"), false)
        @Expect(report.sources.size >= 5, true)
        @Expect(cangjieP6HasFreshnessSource(report, CangjieSourceSets.DOCS), true)
        @Expect(cangjieP6HasFreshnessSource(report, CangjieSourceSets.STDX), true)
        @Expect(report.sources[0].targetVersion, cangjieDefaultTargetVersion())
        @Expect(report.sources[0].contentHash != "", true)
        @Expect(report.sources[0].indexedAt != "", true)
    }

    @TestCase
    public func p6Bnd001FreshnessReportDegradesWhenManifestIsEmpty(): Unit {
        let manifest = CangjieVersionManifest()
        let report = cangjieCorpusFreshnessReport(newOfflineKnowledgeBase().status(), manifest: manifest)

        @Expect(report.ok, false)
        @Expect(report.degraded, true)
        @Expect(report.diagnostics.contains("version_manifest_empty"), true)
    }

    @TestCase
    public func p6Pos001ProbeUsesLocalManifestWithoutNetworkFetch(): Unit {
        let manifest = CangjieVersionManifest()
        let source = CangjieVersionSource()
        source.targetVersion = cangjieDefaultTargetVersion()
        source.sourceSet = CangjieSourceSets.EVAL_SUPPORT
        source.sourceFamily = "eval-support"
        source.sourceRepo = "CangjieCommunityKnowledgeBase/Cangjie-HumanEval"
        source.sourceRef = "main"
        source.refKind = "branch"
        source.resolvedCommit = "local-eval-commit"
        source.contentHash = "sha256:local-eval"
        source.rootKind = "git-root"
        manifest.sources.add(source)
        let runner = P6CountingFetchRunner()

        let report = probeCangjieCorpusFreshness(manifest, runner)

        @Expect(report.ok, true)
        @Expect(report.degraded, false)
        @Expect(runner.calls, 0)
        @Expect(report.sources[0].staleness, "fresh")
    }

    @TestCase
    public func p6Bnd002ProbeMarksOfflineBaselineAsDegradedWithoutNetworkFetch(): Unit {
        let runner = P6CountingFetchRunner()

        let report = probeCangjieCorpusFreshness(defaultCangjieVersionManifest(), runner)

        @Expect(report.ok, false)
        @Expect(report.degraded, true)
        @Expect(runner.calls, 0)
        @Expect(cangjieP6HasFreshnessStaleness(report, "offline_baseline"), true)
    }

    @TestCase
    public func p3U1ProbeFallbackCommitPreventsFalseStaleWhenBodyHashDiffers(): Unit {
        let manifest = cangjieP3SingleRemoteManifest("old-commit", "sha256:old")
        let runner = P3StaticFreshnessRunner(true, "ok", "", "sha256:new")

        let report = probeCangjieCorpusFreshness(manifest, runner)

        @Expect(report.ok, true)
        @Expect(report.degraded, false)
        @Expect(report.sources[0].resolvedCommit, "old-commit")
        @Expect(report.sources[0].staleness, "fresh")
        @Expect(report.sources[0].status, "fresh")
        @Expect(report.diagnostics.contains("tools:staleness_stale"), false)
    }

    @TestCase
    public func p3U3ProbeReportsStaleSignalWithoutFailingWhenCommitChanges(): Unit {
        let manifest = cangjieP3SingleRemoteManifest("old-commit", "sha256:old")
        let runner = P3StaticFreshnessRunner(true, "ok", "new-commit", "sha256:new")

        let report = probeCangjieCorpusFreshness(manifest, runner)

        @Expect(report.ok, true)
        @Expect(report.degraded, false)
        @Expect(report.sources[0].staleness, "stale")
        @Expect(report.sources[0].status, "stale_signal")
        @Expect(report.diagnostics.contains("tools:staleness_stale"), true)
        @Expect(report.diagnostics.contains("freshness_stale_signal:tools:Cangjie/cangjie_tools"), true)
    }

    @TestCase
    public func p3U4ProbeFailureStillDegradesFreshnessReport(): Unit {
        let manifest = cangjieP3SingleRemoteManifest("old-commit", "sha256:old")
        let runner = P3StaticFreshnessRunner(false, "timeout", "", "")

        let report = probeCangjieCorpusFreshness(manifest, runner)

        @Expect(report.ok, false)
        @Expect(report.degraded, true)
        @Expect(report.sources[0].staleness, "failed")
        @Expect(report.diagnostics.contains("tools:probe_failed:timeout"), true)
    }
}

private func cangjieP3SingleRemoteManifest(commit: String, contentHash: String): CangjieVersionManifest {
    let manifest = CangjieVersionManifest()
    manifest.defaultTargetVersion = cangjieDefaultTargetVersion()
    let source = CangjieVersionSource()
    source.targetVersion = cangjieDefaultTargetVersion()
    source.sourceSet = CangjieSourceSets.TOOLS
    source.sourceFamily = "tools"
    source.sourceRepo = "Cangjie/cangjie_tools"
    source.sourceRef = "release-1.0.0"
    source.refKind = "branch"
    source.resolvedCommit = commit
    source.contentHash = contentHash
    manifest.sources.add(source)
    manifest
}

private func cangjieP6HasFreshnessSource(report: CangjieCorpusFreshnessReport, sourceSet: String): Bool {
    for (source in report.sources) {
        if (source.sourceSet == sourceSet) {
            return true
        }
    }
    false
}

private func cangjieP6HasFreshnessStaleness(report: CangjieCorpusFreshnessReport, staleness: String): Bool {
    for (source in report.sources) {
        if (source.staleness == staleness) {
            return true
        }
    }
    false
}

private class P6CountingFetchRunner <: SourceFetchRunner {
    var calls: Int64 = 0

    init() {}

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        this.calls += 1
        let result = SourceFetchResult()
        result.ok = false
        result.status = "should_not_fetch"
        result
    }
}

private class P3StaticFreshnessRunner <: SourceFetchRunner {
    let ok: Bool
    let status: String
    let commit: String
    let bodyHash: String

    init(ok: Bool, status: String, commit: String, bodyHash: String) {
        this.ok = ok
        this.status = status
        this.commit = commit
        this.bodyHash = bodyHash
    }

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        let result = SourceFetchResult()
        result.ok = this.ok
        result.status = this.status
        result.commit = this.commit
        result.bodyHash = this.bodyHash
        result.repo = request.repo
        result.ref = request.ref
        result.sourceUrl = request.url
        result
    }
}
