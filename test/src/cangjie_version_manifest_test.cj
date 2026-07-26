package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.*
import std.fs.{Directory, File, Path, exists}
import std.process.launch

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
        cangjieP1WriteFile(Path(root).join(".git"), "not-a-git-marker\n")

        let manifest = buildCangjieVersionManifestFromRoots(targetVersion: "1.0.0", docsRoot: "${root}/docs")

        @Expect(manifest.degraded, true)
        @Expect(manifest.sources.size, 0)
        @Expect(manifest.diagnostics.contains("docs_git_metadata_missing"), true)
    }

    // S6F-UT-01 + S6F-POS-01
    @TestCase
    public func s6fUt001RepoSubdirectoryUsesAncestorGitAndHashesOnlyContentRoot(): Unit {
        let root = "target/s6f-version-manifest-repo"
        let docs = "${root}/content/docs/dev-guide"
        cangjieP1WriteGitMetadata(root, "s6f-repo-commit")
        cangjieP1WriteFile(Path(docs).join("summary.md"), "# docs\n")
        cangjieP1WriteFile(Path(root).join("outside.txt"), "outside-v1\n")

        let first = buildCangjieVersionManifestFromRoots(targetVersion: "1.0.0", docsRoot: docs)
        cangjieP1WriteFile(Path(root).join("outside.txt"), "outside-v2\n")
        let siblingChanged = buildCangjieVersionManifestFromRoots(targetVersion: "1.0.0", docsRoot: docs)
        cangjieP1WriteFile(Path(docs).join("summary.md"), "# docs changed\n")
        let contentChanged = buildCangjieVersionManifestFromRoots(targetVersion: "1.0.0", docsRoot: docs)

        @Expect(first.degraded, false)
        @Expect(first.sources.size, 2)
        @Expect(first.sources[0].resolvedCommit, "s6f-repo-commit")
        @Expect(first.sources[0].rootKind, "git-root")
        @Expect(siblingChanged.sources[0].contentHash, first.sources[0].contentHash)
        @Expect(contentChanged.sources[0].contentHash != first.sources[0].contentHash, true)
    }

    // S6F-BND-01
    @TestCase
    public func s6fBnd001MultiLevelWorktreeSubdirectoryUsesCommonGitMetadata(): Unit {
        let root = "target/s6f-version-manifest-worktree"
        let worktree = "${root}/worktree"
        let commonDir = "${root}/repo/.git"
        let gitDir = "${commonDir}/worktrees/worktree-entry"
        let docs = "${worktree}/nested/content/docs"
        cangjieP1WriteFile(Path(worktree).join(".git"), "gitdir: ../repo/.git/worktrees/worktree-entry\n")
        cangjieP1WriteFile(Path(gitDir).join("gitdir"), "../../../../worktree/.git\n")
        cangjieP1WriteFile(Path(gitDir).join("commondir"), "../..\n")
        cangjieP1WriteFile(Path(gitDir).join("HEAD"), "ref: refs/heads/release-1.0.0\n")
        cangjieP1WriteFile(Path(commonDir).join("refs/heads/release-1.0.0"), "s6f-worktree-commit\n")
        cangjieP1WriteFile(Path(docs).join("summary.md"), "# worktree docs\n")

        let manifest = buildCangjieVersionManifestFromRoots(targetVersion: "1.0.0", docsRoot: docs)

        @Expect(manifest.degraded, false)
        @Expect(manifest.sources.size, 2)
        @Expect(manifest.sources[0].resolvedCommit, "s6f-worktree-commit")
        @Expect(manifest.sources[0].rootKind, "git-worktree")
    }

    // S6F-NEG-01
    @TestCase
    public func s6fNeg001DamagedOrUnboundGitdirFailsClosedAtNearestMarker(): Unit {
        let root = "target/s6f-version-manifest-invalid"
        let damagedDocs = "${root}/damaged/docs"
        cangjieP1WriteGitMetadata(root, "must-not-be-used")
        cangjieP1WriteFile(Path(root).join("damaged/.git"), "gitdir: ../missing-git-dir\n")
        cangjieP1WriteFile(Path(damagedDocs).join("summary.md"), "# damaged\n")
        let damaged = buildCangjieVersionManifestFromRoots(targetVersion: "1.0.0", docsRoot: damagedDocs)

        let unboundRoot = "${root}/unbound"
        let unboundDocs = "${unboundRoot}/docs"
        let externalGit = "${root}/external-git"
        cangjieP1WriteFile(Path(unboundRoot).join(".git"), "gitdir: ../external-git\n")
        cangjieP1WriteFile(Path(externalGit).join("HEAD"), "s6f-unbound-commit\n")
        cangjieP1WriteFile(Path(unboundDocs).join("summary.md"), "# unbound\n")
        let unbound = buildCangjieVersionManifestFromRoots(targetVersion: "1.0.0", docsRoot: unboundDocs)

        let externalCommonRoot = "${root}/external-common"
        let externalCommonDocs = "${externalCommonRoot}/docs"
        let externalCommonGit = "${root}/external-common-git"
        let externalCommon = "${root}/external-common-dir"
        cangjieP1WriteFile(Path(externalCommonRoot).join(".git"), "gitdir: ../external-common-git\n")
        cangjieP1WriteFile(Path(externalCommonGit).join("gitdir"), "../external-common/.git\n")
        cangjieP1WriteFile(Path(externalCommonGit).join("HEAD"), "s6f-external-common-commit\n")
        cangjieP1WriteFile(Path(externalCommonGit).join("commondir"), "../external-common-dir\n")
        cangjieP1WriteFile(Path(externalCommon).join("HEAD"), "s6f-external-common-head\n")
        cangjieP1WriteFile(Path(externalCommonDocs).join("summary.md"), "# external common\n")
        let externalCommonManifest = buildCangjieVersionManifestFromRoots(targetVersion: "1.0.0",
            docsRoot: externalCommonDocs)

        let emptyCommonRoot = "${root}/empty-common"
        let emptyCommonDocs = "${emptyCommonRoot}/docs"
        let emptyCommonGit = "${root}/empty-common-git"
        cangjieP1WriteFile(Path(emptyCommonRoot).join(".git"), "gitdir: ../empty-common-git\n")
        cangjieP1WriteFile(Path(emptyCommonGit).join("gitdir"), "../empty-common/.git\n")
        cangjieP1WriteFile(Path(emptyCommonGit).join("HEAD"), "s6f-empty-common-commit\n")
        cangjieP1WriteFile(Path(emptyCommonGit).join("commondir"), "\n")
        cangjieP1WriteFile(Path(emptyCommonDocs).join("summary.md"), "# empty common\n")
        let emptyCommon = buildCangjieVersionManifestFromRoots(targetVersion: "1.0.0",
            docsRoot: emptyCommonDocs)

        let traversalRoot = "${root}/ref-traversal"
        let traversalDocs = "${traversalRoot}/docs"
        cangjieP1WriteFile(Path(traversalRoot).join(".git/HEAD"), "ref: refs/heads/../../../outside-ref\n")
        cangjieP1WriteFile(Path(traversalRoot).join("outside-ref"), "s6f-traversal-commit\n")
        cangjieP1WriteFile(Path(traversalDocs).join("summary.md"), "# traversal\n")
        let traversal = buildCangjieVersionManifestFromRoots(targetVersion: "1.0.0",
            docsRoot: traversalDocs)

        let configRoot = "${root}/config-ref"
        let configDocs = "${configRoot}/docs"
        let configSentinel = "s6f-config-must-not-be-resolved"
        cangjieP1WriteFile(Path(configRoot).join(".git/HEAD"), "ref: config\n")
        cangjieP1WriteFile(Path(configRoot).join(".git/config"), configSentinel)
        cangjieP1WriteFile(Path(configDocs).join("summary.md"), "# config ref\n")
        let configRef = buildCangjieVersionManifestFromRoots(targetVersion: "1.0.0",
            docsRoot: configDocs)

        let looseSymlinkRoot = "${root}/loose-ref-symlink"
        let looseSymlinkDocs = "${looseSymlinkRoot}/docs"
        let looseSentinel = "s6f-loose-ref-must-not-be-resolved"
        cangjieP1WriteFile(Path(looseSymlinkRoot).join(".git/HEAD"), "ref: refs/heads/escape\n")
        cangjieP1WriteFile(Path(looseSymlinkRoot).join("outside-ref"), looseSentinel)
        cangjieP1WriteFile(Path(looseSymlinkDocs).join("summary.md"), "# loose ref symlink\n")
        Directory.create(Path(looseSymlinkRoot).join(".git/refs/heads"), recursive: true)
        @Expect(launch("/bin/rm", ["-f", "${looseSymlinkRoot}/.git/refs/heads/escape"]).wait(), 0)
        @Expect(launch("/bin/ln", ["-s", "../../../outside-ref",
            "${looseSymlinkRoot}/.git/refs/heads/escape"]).wait(), 0)
        let looseSymlink = buildCangjieVersionManifestFromRoots(targetVersion: "1.0.0",
            docsRoot: looseSymlinkDocs)

        let symlinkRoot = "${root}/git-symlink"
        let symlinkDocs = "${symlinkRoot}/docs"
        let symlinkGit = "${root}/git-symlink-external"
        cangjieP1WriteFile(Path(symlinkDocs).join("summary.md"), "# symlink\n")
        cangjieP1WriteFile(Path(symlinkGit).join("HEAD"), "s6f-symlink-commit\n")
        @Expect(launch("/bin/rm", ["-f", "${symlinkRoot}/.git"]).wait(), 0)
        @Expect(launch("/bin/ln", ["-s", "../git-symlink-external", "${symlinkRoot}/.git"]).wait(), 0)
        let symlink = buildCangjieVersionManifestFromRoots(targetVersion: "1.0.0",
            docsRoot: symlinkDocs)

        @Expect(damaged.degraded, true)
        @Expect(damaged.sources.size, 0)
        @Expect(damaged.diagnostics.contains("docs_git_metadata_missing"), true)
        @Expect(unbound.degraded, true)
        @Expect(unbound.sources.size, 0)
        @Expect(unbound.diagnostics.contains("docs_git_metadata_missing"), true)
        @Expect(externalCommonManifest.degraded, true)
        @Expect(externalCommonManifest.sources.size, 0)
        @Expect(externalCommonManifest.diagnostics.contains("docs_git_metadata_missing"), true)
        @Expect(emptyCommon.degraded, true)
        @Expect(emptyCommon.sources.size, 0)
        @Expect(emptyCommon.diagnostics.contains("docs_git_metadata_missing"), true)
        @Expect(traversal.degraded, true)
        @Expect(traversal.sources.size, 0)
        @Expect(traversal.diagnostics.contains("docs_git_ref_commit_missing"), true)
        @Expect(configRef.degraded, true)
        @Expect(configRef.sources.size, 0)
        @Expect(configRef.diagnostics.contains("docs_git_ref_commit_missing"), true)
        @Expect(configRef.diagnostics.toString().contains(configSentinel), false)
        @Expect(looseSymlink.degraded, true)
        @Expect(looseSymlink.sources.size, 0)
        @Expect(looseSymlink.diagnostics.contains("docs_git_ref_commit_missing"), true)
        @Expect(looseSymlink.diagnostics.toString().contains(looseSentinel), false)
        @Expect(symlink.degraded, true)
        @Expect(symlink.sources.size, 0)
        @Expect(symlink.diagnostics.contains("docs_git_metadata_missing"), true)
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
        let derived = resolveCangjieVersion(cangjieVersionSelector(targetVersion: "1.0.0", sourceSet: CangjieSourceSets.KNOWLEDGE_ATOMS, versionPolicy: "exact"), defaultCangjieVersionManifest())

        @Expect(resolution.ok, false)
        @Expect(resolution.diagnostic, "unsupported_source_set")
        @Expect(resolution.diagnostics.contains("unsupported_source_set:private-src"), true)
        @Expect(derived.ok, false)
        @Expect(derived.diagnostic, "unsupported_source_set")
        @Expect(derived.diagnostics.contains("unsupported_source_set:knowledge-atoms"), true)
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
