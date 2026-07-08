package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.*
import std.fs.{Directory, File, Path, exists}

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
        @Expect(resolution.diagnostic, "exact_source_ref_not_resolved")
        @Expect(resolution.sources.size, 0)
    }

    @TestCase
    public func p1Bnd002ExactPolicyRequiresSourceRef(): Unit {
        let resolution = resolveCangjieVersion(cangjieVersionSelector(targetVersion: "1.0.0", sourceSet: "docs", versionPolicy: "exact"), defaultCangjieVersionManifest())

        @Expect(resolution.ok, false)
        @Expect(resolution.diagnostic, "exact_source_ref_required")
        @Expect(resolution.diagnostics.contains("exact_source_ref_required"), true)
    }

    @TestCase
    public func p1Pos000Release100ExposesDashAndSlashRefAliases(): Unit {
        let aliases = cangjieSourceRefAliasesForTargetVersion("1.0.0")

        @Expect(aliases.size, 2)
        @Expect(aliases.contains("release/1.0"), true)
        @Expect(aliases.contains("release-1.0.0"), true)
    }

    @TestCase
    public func p1Pos001BuildsManifestFromLocalRootsWithoutOfflineBaseline(): Unit {
        let root = "target/p1-version-manifest-local-roots"
        cangjieP1WriteFile(Path(root).join("docs/dev-guide/summary.md"), "# docs\n")
        cangjieP1WriteFile(Path(root).join("tools/tools/summary.md"), "# tools\n")
        cangjieP1WriteFile(Path(root).join("std/src/std/collection/a.cj"), "package std.collection\npublic class A {}\n")
        cangjieP1WriteFile(Path(root).join("stdx/src/stdx/http/client.cj"), "package stdx.http\npublic class HttpClient {}\n")
        cangjieP1WriteFile(Path(root).join("eval/CJ-HUMANEVAL-000/prompt.md"), "# task\n")
        cangjieP1WriteGitMetadata("${root}/docs", "p1-docs-commit")
        cangjieP1WriteGitMetadata("${root}/tools", "p1-tools-commit")
        cangjieP1WriteGitMetadata("${root}/std", "p1-std-commit")
        cangjieP1WriteGitMetadata("${root}/stdx", "p1-stdx-commit")
        cangjieP1WriteGitMetadata("${root}/eval", "p1-eval-commit")

        let manifest = buildCangjieVersionManifestFromRoots(targetVersion: "1.0.0",
            docsRoot: "${root}/docs",
            toolDocsRoot: "${root}/tools",
            stdRoot: "${root}/std",
            stdxRoot: "${root}/stdx",
            evalRoot: "${root}/eval")
        let std = resolveCangjieVersion(cangjieVersionSelector(targetVersion: "1.0.0", sourceSet: "std"), manifest)

        @Expect(manifest.sources.size, 5)
        @Expect(manifest.degraded, false)
        @Expect(std.ok, true)
        @Expect(std.sources[0].sourceRef, "release-1.0.0")
        @Expect(std.sources[0].resolvedCommit, "p1-std-commit")
        @Expect(std.sources[0].contentHash.startsWith("sha256:mh"), true)
        @Expect(std.sources[0].rootKind, "git-root")
        @Expect(std.sources[0].resolvedCommit.contains("offline-baseline"), false)
    }

    @TestCase
    public func p1Bnd003ExplicitNonGitRootReturnsDegradedManifest(): Unit {
        let root = "target/p1-version-manifest-non-git"
        cangjieP1WriteFile(Path(root).join("docs/dev-guide/summary.md"), "# docs\n")

        let manifest = buildCangjieVersionManifestFromRoots(targetVersion: "1.0.0", docsRoot: "${root}/docs")

        @Expect(manifest.degraded, true)
        @Expect(manifest.sources.size, 0)
        @Expect(manifest.diagnostics.contains("docs_git_metadata_missing"), true)
    }

    @TestCase
    public func p3Pos001StoreRoundTripsActiveVersionManifest(): Unit {
        let store = FileKnowledgeStore("target/p3-version-manifest-store")
        let manifest = defaultCangjieVersionManifest()

        store.saveCangjieVersionManifest(manifest)
        let loaded = store.loadCangjieVersionManifest()
        let docs = resolveCangjieVersion(cangjieVersionSelector(targetVersion: "1.0.0", sourceSet: "docs", sourceRef: "release-1.0.0", versionPolicy: "exact"), loaded)

        @Expect(store.has("metadata/cangjie-version-manifest.ckb"), true)
        @Expect(loaded.manifestVersion, manifest.manifestVersion)
        @Expect(loaded.defaultTargetVersion, manifest.defaultTargetVersion)
        @Expect(loaded.sources.size, manifest.sources.size)
        @Expect(loaded.sources[0].rootKind, "offline-baseline")
        @Expect(docs.ok, true)
        @Expect(docs.sources[0].sourceRepo, "Cangjie/cangjie_docs")
    }

    @TestCase
    public func p3Bnd001ManifestDetectsOfflineBaselineAndComputesEvidenceHash(): Unit {
        let offline = defaultCangjieVersionManifest()
        let local = buildCangjieVersionManifestFromRoots(targetVersion: "1.0.0")

        @Expect(cangjieManifestHasOfflineBaseline(offline), true)
        @Expect(cangjieManifestEvidenceHash(offline) != "", true)
        @Expect(cangjieManifestEvidenceHash(local) != "", true)
    }

    @TestCase
    public func stB001UnsupportedSourceSetReturnsDiagnostic(): Unit {
        let resolution = resolveCangjieVersion(cangjieVersionSelector(targetVersion: "1.0.0", sourceSet: "private-src", versionPolicy: "exact"), defaultCangjieVersionManifest())

        @Expect(resolution.ok, false)
        @Expect(resolution.diagnostic, "unsupported_source_set")
        @Expect(resolution.diagnostics.contains("unsupported_source_set:private-src"), true)
    }
}

private func cangjieP1WriteFile(path: Path, text: String): Unit {
    if (!exists(path.parent)) {
        Directory.create(path.parent, recursive: true)
    }
    File.writeTo(path, text.toArray())
}

private func cangjieP1WriteGitMetadata(root: String, commit: String): Unit {
    cangjieP1WriteFile(Path(root).join(".git/HEAD"), "ref: refs/heads/release-1.0.0\n")
    cangjieP1WriteFile(Path(root).join(".git/refs/heads/release-1.0.0"), commit)
}
