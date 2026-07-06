package cangjie_community_knowledge_base_test

import std.collection.*
import std.fs.{Directory, File, Path, exists}
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieDocCorpusTest {
    @TestCase
    public func p2Ut001SplitsMarkdownSectionsWithUtf8AndCodeFence(): Unit {
        let source = CangjieDocSourceRecord()
        source.sourceId = "fixture-doc"
        source.path = "dev-guide/source_en/collections/collection_arraylist.md"
        source.content = "# 标题😀\nintro\n```cangjie\n# not heading\n```\n## API\nArrayList.add\n"
        source.versionResolutionId = "cangjie-1.0.0-docs-release-1.0.0"

        let result = splitMarkdownSections(source)

        @Expect(result.ok, true)
        @Expect(result.records.size, 2)
        @Expect(result.records[0].recordKind, CangjieTypedRecordKinds.DOC_SECTION)
        @Expect(result.records[0].heading, "标题😀")
        @Expect(result.records[0].content.contains("# not heading"), true)
        @Expect(result.records[1].heading, "API")
        @Expect(result.records[1].contentHash.startsWith("h"), true)
    }

    @TestCase
    public func p2Bnd001RejectsFixtureOutsideRelativeMarkdownPath(): Unit {
        let source = CangjieDocSourceRecord()
        source.sourceId = "bad-doc"
        source.path = "../real/user/file.md"
        source.content = "# Bad\n"

        let result = splitMarkdownSections(source)

        @Expect(result.ok, false)
        @Expect(result.diagnostics.contains("invalid_docs_path"), true)
        @Expect(result.records.size, 0)
    }

    @TestCase
    public func p2Pos001ScansExplicitDocsManifestAndExtractsToolManual(): Unit {
        let root = "target/p2-docs-fixture"
        let devGuideDir = Path(root).join("dev-guide")
        let toolsDir = Path(root).join("tools/source_en/cmd-tools")
        if (!exists(devGuideDir)) {
            Directory.create(devGuideDir, recursive: true)
        }
        if (!exists(toolsDir)) {
            Directory.create(toolsDir, recursive: true)
        }
        File.writeTo(Path(root).join("dev-guide/summary_cjnative_EN.md"), "# Dev Guide\n仓颉 ArrayList\n".toArray())
        File.writeTo(Path(root).join("tools/source_en/cmd-tools/cjpm_manual.md"), "# cjpm\nUse cjpm build and cjpm test.\n".toArray())
        let paths = ArrayList<String>()
        paths.add("dev-guide/summary_cjnative_EN.md")
        paths.add("tools/source_en/cmd-tools/cjpm_manual.md")

        let result = scanCangjieDocsRoot(root, resolveCangjieVersion(cangjieVersionSelector(targetVersion: "1.0.0", sourceSet: CangjieSourceSets.ALL), defaultCangjieVersionManifest()), paths)

        @Expect(result.ok, true)
        @Expect(result.records.size >= 3, true)
        @Expect(cangjieDocTestContainsKind(result, CangjieTypedRecordKinds.DOC_SECTION), true)
        @Expect(cangjieDocTestContainsKind(result, CangjieTypedRecordKinds.TOOL_MANUAL), true)
    }

    @TestCase
    public func p2Pos003DiscoversRecursiveMarkdownAndHtmlDocs(): Unit {
        let root = "target/p2-docs-recursive-fixture"
        let docsDir = Path(root).join("dev-guide/source_en/api")
        let toolsDir = Path(root).join("tools/source_en/cmd-tools")
        if (!exists(docsDir)) {
            Directory.create(docsDir, recursive: true)
        }
        if (!exists(toolsDir)) {
            Directory.create(toolsDir, recursive: true)
        }
        File.writeTo(Path(root).join("dev-guide/source_en/api/arraylist.md"), "# ArrayList\nArrayList.add appends values.\n".toArray())
        File.writeTo(Path(root).join("tools/source_en/cmd-tools/cjpm_manual.html"), "<html><body><h1>cjpm test</h1><p>Use cjpm test to run tests.</p></body></html>".toArray())

        let paths = discoverCangjieDocsRelativePaths(root)
        let result = scanCangjieDocsRootFull(root, resolveCangjieVersion(cangjieVersionSelector(targetVersion: "1.0.0", sourceSet: CangjieSourceSets.ALL), defaultCangjieVersionManifest()))

        @Expect(paths.contains("dev-guide/source_en/api/arraylist.md"), true)
        @Expect(paths.contains("tools/source_en/cmd-tools/cjpm_manual.html"), true)
        @Expect(result.ok, true)
        @Expect(cangjieDocTestContainsKind(result, CangjieTypedRecordKinds.DOC_SECTION), true)
        @Expect(cangjieDocTestContainsTool(result, "cjpm", "test"), true)
    }

    @TestCase
    public func p2Bnd003DiscoverySkipsHiddenBuildAndUnsupportedFiles(): Unit {
        let root = "target/p2-docs-hidden-fixture"
        let goodDir = Path(root).join("docs")
        let hiddenDir = Path(root).join(".git")
        let targetDir = Path(root).join("target")
        if (!exists(goodDir)) {
            Directory.create(goodDir, recursive: true)
        }
        if (!exists(hiddenDir)) {
            Directory.create(hiddenDir, recursive: true)
        }
        if (!exists(targetDir)) {
            Directory.create(targetDir, recursive: true)
        }
        File.writeTo(Path(root).join("docs/ok.md"), "# OK\n".toArray())
        File.writeTo(Path(root).join(".git/private.md"), "# Private\n".toArray())
        File.writeTo(Path(root).join("target/generated.md"), "# Generated\n".toArray())
        File.writeTo(Path(root).join("docs/binary.bin"), "not docs\n".toArray())

        let paths = discoverCangjieDocsRelativePaths(root)

        @Expect(paths.contains("docs/ok.md"), true)
        @Expect(paths.contains(".git/private.md"), false)
        @Expect(paths.contains("target/generated.md"), false)
        @Expect(paths.contains("docs/binary.bin"), false)
    }

    @TestCase
    public func p2Neg001InvalidDocsRootDoesNotReadRealEnvironment(): Unit {
        let result = scanCangjieDocsRoot("/Users/l3gi0n/.ssh", resolveCangjieVersion(cangjieVersionSelector(targetVersion: "1.0.0"), defaultCangjieVersionManifest()), ArrayList<String>())

        @Expect(result.ok, false)
        @Expect(result.diagnostics.contains("invalid_docs_root"), true)
        @Expect(result.records.size, 0)
    }
}

private func cangjieDocTestContainsKind(result: CangjieTypedRecordResult, kind: String): Bool {
    for (record in result.records) {
        if (record.recordKind == kind) {
            return true
        }
    }
    false
}

private func cangjieDocTestContainsTool(result: CangjieTypedRecordResult, tool: String, command: String): Bool {
    for (record in result.records) {
        if (record.recordKind == CangjieTypedRecordKinds.TOOL_MANUAL && record.toolName == tool && record.command == command) {
            return true
        }
    }
    false
}
