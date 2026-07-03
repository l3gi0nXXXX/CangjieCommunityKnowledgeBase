package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieCorpusFreshnessTest {
    @TestCase
    public func p6Ut001FreshnessReportListsVersionedSources(): Unit {
        let report = cangjieCorpusFreshnessReport(newOfflineKnowledgeBase().status())

        @Expect(report.ok, true)
        @Expect(report.sources.size >= 5, true)
        @Expect(cangjieP6HasFreshnessSource(report, CangjieSourceSets.DOCS), true)
        @Expect(cangjieP6HasFreshnessSource(report, CangjieSourceSets.STDX), true)
        @Expect(report.sources[0].targetVersion, cangjieDefaultTargetVersion())
        @Expect(report.sources[0].contentHash != "", true)
    }

    @TestCase
    public func p6Bnd001FreshnessReportDegradesWhenManifestIsEmpty(): Unit {
        let manifest = CangjieVersionManifest()
        let report = cangjieCorpusFreshnessReport(newOfflineKnowledgeBase().status(), manifest: manifest)

        @Expect(report.ok, false)
        @Expect(report.degraded, true)
        @Expect(report.diagnostics.contains("version_manifest_empty"), true)
    }
}

private func cangjieP6HasFreshnessSource(report: CangjieCorpusFreshnessReport, sourceSet: String): Bool {
    for (source in report.sources) {
        if (source.sourceSet == sourceSet) {
            return true
        }
    }
    false
}
