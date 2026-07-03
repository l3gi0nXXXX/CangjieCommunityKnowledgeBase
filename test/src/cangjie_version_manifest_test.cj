package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieVersionManifestTest {
    @TestCase
    public func p1Ut001ResolvesExactDocsAndStdxRefs(): Unit {
        let manifest = defaultCangjieVersionManifest()
        let docs = resolveCangjieVersion(cangjieVersionSelector(targetVersion: "1.0.0", sourceSet: "docs", sourceRef: "release-1.0.0", versionPolicy: "exact"), manifest)
        let stdx = resolveCangjieVersion(cangjieVersionSelector(targetVersion: "1.0.0", sourceSet: "stdx", sourceRef: "release-1.0.0", versionPolicy: "exact"), manifest)

        @Expect(docs.ok, true)
        @Expect(docs.targetVersion, "1.0.0")
        @Expect(docs.sources.size, 1)
        @Expect(docs.sources[0].sourceRepo, "Cangjie/cangjie_docs")
        @Expect(stdx.ok, true)
        @Expect(stdx.sources.size, 1)
        @Expect(stdx.sources[0].sourceRepo, "Cangjie/cangjie_stdx")
    }

    @TestCase
    public func p1Bnd001ExactMissingRefDoesNotFallback(): Unit {
        let resolution = resolveCangjieVersion(cangjieVersionSelector(targetVersion: "1.0.0", sourceSet: "docs", sourceRef: "missing-release", versionPolicy: "exact"), defaultCangjieVersionManifest())

        @Expect(resolution.ok, false)
        @Expect(resolution.diagnostic, "version_not_resolved")
        @Expect(resolution.sources.size, 0)
    }

    @TestCase
    public func stB001UnsupportedSourceSetReturnsDiagnostic(): Unit {
        let resolution = resolveCangjieVersion(cangjieVersionSelector(targetVersion: "1.0.0", sourceSet: "private-src", versionPolicy: "exact"), defaultCangjieVersionManifest())

        @Expect(resolution.ok, false)
        @Expect(resolution.diagnostic, "unsupported_source_set")
        @Expect(resolution.diagnostics.contains("unsupported_source_set:private-src"), true)
    }
}
