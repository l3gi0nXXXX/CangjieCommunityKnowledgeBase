package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.process.launch
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbReproDocumentationTest {
    @TestCase
    public func reproDocumentationRequiredFilesExist(): Unit {
        for (relative in p7RequiredDocuments()) {
            @Expect(exists(Path("../${relative}")), true)
            let text = p7Read("../${relative}")
            @Expect(text.contains("目的"), true)
            @Expect(text.contains("通过标准"), true)
            @Expect(text.contains("失败处理"), true)
        }
        let root = p7Read("../README.md")
        @Expect(root.contains("## 复现 HumanEval 158/164"), true)
        @Expect(root.contains("strict pass@1 为 158/164"), true)
        @Expect(root.contains("UNPUBLISHED_W3_DRAFT"), false)
        @Expect(root.contains("docs/reproducibility/README.md"), true)
    }

    @TestCase
    public func reproDocumentationLinksResolve(): Unit {
        let links = [
            "docs/reproducibility/README.md",
            "docs/reproducibility/quick-start.md",
            "docs/reproducibility/restore-knowledge-base.md",
            "docs/reproducibility/rebuild-from-source.md",
            "docs/reproducibility/configure-claude-glm.md",
            "docs/reproducibility/freeze-humaneval-authority-delivery.md",
            "docs/reproducibility/run-humaneval-164.md",
            "docs/reproducibility/verify-strict-pass-at-1.md",
            "docs/reproducibility/result-interpretation.md",
            "docs/reproducibility/troubleshooting.md",
            "docs/reproducibility/release-maintainer-runbook.md",
            "docs/service-http-operations.md"
        ]
        let all = p7DocumentationText()
        for (relative in links) {
            @Expect(exists(Path("../${relative}")), true)
            @Expect(all.contains(relative), true)
        }
    }

    @TestCase
    public func p7ReleaseQuickStartUsesFrozenW7Identity(): Unit {
        let root = p7Read("../README.md")
        let quick = p7Read("../docs/reproducibility/quick-start.md")
        for (text in [root, quick]) {
            @Expect(text.contains("UNPUBLISHED_W3_DRAFT"), false)
            @Expect(text.contains("PENDING_W4_CLI_REGISTRATION"), false)
            @Expect(text.contains("ckb-first-init-1-0-0-candidate"), true)
        }
        @Expect(quick.contains(".strictPassed == 158"), true)
        @Expect(quick.contains("CKB_RELEASE_URL"), false)
    }

    @TestCase
    public func p7ReleaseStrictEvidenceReportsPortable158(): Unit {
        let strict = p7Read("../docs/reproducibility/verify-strict-pass-at-1.md")
        @Expect(strict.contains("UNPUBLISHED_P8_A_REFERENCE"), false)
        @Expect(strict.contains("UNAVAILABLE_UNTIL_W7"), false)
        @Expect(strict.contains("历史迁移基线"), true)
        @Expect(strict.contains("portable raw 160/164、strict 158/164"), true)
        @Expect(strict.contains("strict 158 >= 151"), true)
        @Expect(strict.contains("待 W4 激活"), false)
    }

    @TestCase
    public func p7NegativeGatesStopBeforeRunnerOrPublish(): Unit {
        let docs = p7DocumentationText()
        for (marker in [
            "missing_asset_stop",
            "hash_mismatch_stop",
            "model_identity_mismatch_stop",
            "leakage_finding_stop",
            "authority_delivery_blocked_stop",
            "transport_unresolved_stop"
        ]) {
            @Expect(docs.contains(marker), true)
        }
        @Expect(docs.contains("门禁失败后不得继续 Runner 或发布"), true)
    }

    @TestCase
    public func reproDocumentationExamplesArePortableAndSecretFree(): Unit {
        let docs = p7DocumentationText()
        for (forbidden in [
            "/Users/", "/home/", "C:\\Users\\", "git add -f",
            "canonical_solution", "solution.cj", "teacher-solutions",
            "sk-live-", "Bearer ey", "PRIVATE-TOKEN:",
            "/path/to/cangjie", "/opt/homebrew/opt/openssl@3",
            "/etc/ssl/cert.pem"
        ]) {
            @Expect(docs.contains(forbidden), false)
        }
        @Expect(docs.contains("\${CKB_ROOT}"), true)
        @Expect(docs.contains("\${REPRO_ROOT}"), true)
        @Expect(docs.contains("\${TMPDIR:-/tmp}"), true)
        @Expect(docs.contains("路径可包含空格"), true)
        @Expect(docs.contains("export cjHeapSize=4GB"), true)
        @Expect(docs.contains(
            "OPENSSL_ROOT=\"\${OPENSSL_ROOT:-$(brew --prefix openssl@3)}\""),
            true)
        @Expect(docs.contains(
            "DYLD_LIBRARY_PATH=\"\${OPENSSL_ROOT}/lib:"), true)
        @Expect(docs.contains("export DYLD_LIBRARY_PATH="), true)
        @Expect(docs.contains("docs/service-http-operations.md"), true)
    }

    @TestCase
    public func productionValidatorAcceptsCurrentReleaseDocumentation(): Unit {
        let evidence = validateCkbReproDocumentation(
            P7RepositoryDocumentationReader(), "..",
            CKB_REPRO_DOCUMENTATION_MODE_RELEASE,
            p7ReleaseRegisteredCommands())
        @Expect(evidence.ok, true)
        @Expect(evidence.diagnostic, "documentation_valid")
        @Expect(evidence.requiredDocumentCount, 12)
        @Expect(evidence.discoveredDocumentCount, 12)
        @Expect(evidence.placeholderFindingCount, 0)
        @Expect(evidence.pathSecretFindingCount, 0)
        @Expect(evidence.commandFindingCount, 0)
        @Expect(evidence.brokenLinkCount, 0)
    }

    @TestCase
    public func productionValidatorSeparatesDraftAndReleasePlaceholderModes(): Unit {
        let draft = p7FakeDocumentation(true)
        let draftResult = validateCkbReproDocumentation(
            draft, "/tmp/CKB 复现🙂", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
            Array<String>())
        @Expect(draftResult.ok, true)

        let prematureRelease = validateCkbReproDocumentation(
            draft, "/tmp/CKB 复现🙂", CKB_REPRO_DOCUMENTATION_MODE_RELEASE,
            ["ckb-repro-build", "cangjie-humaneval-strict-score"])
        @Expect(prematureRelease.ok, false)
        @Expect(prematureRelease.diagnostic, "documentation_placeholder_forbidden")

        let release = p7FakeDocumentation(false)
        let releaseResult = validateCkbReproDocumentation(
            release, "/tmp/CKB 复现🙂", CKB_REPRO_DOCUMENTATION_MODE_RELEASE,
            ["ckb-repro-build", "cangjie-humaneval-strict-score"])
        @Expect(releaseResult.ok, true)
    }

    @TestCase
    public func productionValidatorRejectsMissingExtraAndBrokenLink(): Unit {
        let missing = p7FakeDocumentation(true)
        missing.remove("docs/reproducibility/troubleshooting.md")
        let missingResult = validateCkbReproDocumentation(
            missing, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
            Array<String>())
        @Expect(missingResult.diagnostic, "documentation_required_file_missing")

        let extra = p7FakeDocumentation(true)
        extra.put("docs/reproducibility/extra-release-entry.md",
            p7ValidDocument(true))
        let extraResult = validateCkbReproDocumentation(
            extra, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
            Array<String>())
        @Expect(extraResult.diagnostic, "documentation_extra_release_entry")

        let broken = p7FakeDocumentation(true)
        broken.put("docs/reproducibility/quick-start.md",
            p7ValidDocument(true) + "\n[断链](missing.md)\n")
        let brokenResult = validateCkbReproDocumentation(
            broken, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
            Array<String>())
        @Expect(brokenResult.diagnostic, "documentation_link_broken")
        @Expect(brokenResult.brokenLinkCount, 1)
    }

    @TestCase
    public func productionValidatorRejectsUnknownCommandAndBypassInstruction(): Unit {
        let unknown = p7FakeDocumentation(false)
        unknown.put("docs/reproducibility/quick-start.md",
            p7ValidDocument(false) + "\n`ckb-repro-unknown`\n")
        let unknownResult = validateCkbReproDocumentation(
            unknown, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_RELEASE,
            ["ckb-repro-build", "cangjie-humaneval-strict-score"])
        @Expect(unknownResult.diagnostic, "documentation_command_unknown")

        let bypass = p7FakeDocumentation(true)
        bypass.put("docs/reproducibility/quick-start.md",
            p7ValidDocument(true) + "\ngit add -f ignored-secret\n")
        let bypassResult = validateCkbReproDocumentation(
            bypass, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
            Array<String>())
        @Expect(bypassResult.diagnostic, "documentation_path_or_secret_forbidden")
    }

    @TestCase
    public func productionValidatorRejectsPrivatePathsSecretsAndSolutionPayloads(): Unit {
        for (forbidden in [
            "/Users/alice/private/ckb-data",
            "/home/alice/private/ckb-data",
            "C:\\Users\\alice\\private\\ckb-data",
            "sk-live-real-looking-secret-value",
            "Bearer eyJhbGciOiJIUzI1NiJ9.payload",
            "canonical_solution: func solve()",
            "HumanEval/042 hidden_test_payload"
        ]) {
            let reader = p7FakeDocumentation(true)
            reader.put("docs/reproducibility/quick-start.md",
                p7ValidDocument(true) + "\n${forbidden}\n")
            let result = validateCkbReproDocumentation(
                reader, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
                Array<String>())
            @Expect(result.ok, false)
            @Expect(result.diagnostic, "documentation_path_or_secret_forbidden")
            @Expect(result.diagnostic.contains(forbidden), false)
        }
    }

    @TestCase
    public func productionValidatorHandlesUtf8AndMalformedInputSafely(): Unit {
        let unicode = p7FakeDocumentation(true)
        unicode.put("docs/reproducibility/quick-start.md",
            p7ValidDocument(true) + "\n中文步骤与 emoji 🙂🚀 保持完整。\n")
        @Expect(validateCkbReproDocumentation(
            unicode, "/tmp/CKB 复现🙂", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
            Array<String>()).ok, true)

        let invalid = p7FakeDocumentation(true)
        invalid.putBytes("docs/reproducibility/quick-start.md",
            [UInt8(0xff), UInt8(0xfe), UInt8(0xfd)])
        let invalidResult = validateCkbReproDocumentation(
            invalid, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
            Array<String>())
        @Expect(invalidResult.diagnostic, "invalid_response_encoding")
        @Expect(invalidResult.diagnostic.contains("ff"), false)

        let malformed = p7FakeDocumentation(true)
        malformed.put("docs/reproducibility/quick-start.md",
            p7ValidDocument(true) + "\n[损坏链接](missing.md\n")
        let malformedResult = validateCkbReproDocumentation(
            malformed, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
            Array<String>())
        @Expect(malformedResult.diagnostic, "documentation_link_malformed")
    }

    @TestCase
    public func productionValidatorRejectsDisguisedUnknownCommands(): Unit {
        for (unknown in [
            "ckb-repro-unknown.sh", "ckb-repro-unknown.",
            "ckb-repro-build.sh", "ckb-repro-unknown.json",
            "ckb-repro-unknown.txt"
        ]) {
            let reader = p7FakeDocumentation(false)
            reader.put("docs/reproducibility/quick-start.md",
                p7ValidDocument(false) + "\n`${unknown}`\n")
            let result = validateCkbReproDocumentation(
                reader, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_RELEASE,
                ["ckb-repro-build", "cangjie-humaneval-strict-score"])
            @Expect(result.diagnostic, "documentation_command_unknown")
        }
        let asset = p7FakeDocumentation(false)
        asset.put("docs/reproducibility/quick-start.md",
            p7ValidDocument(false) + "\n`ckb-repro-placeholders.txt`\n")
        @Expect(validateCkbReproDocumentation(
            asset, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_RELEASE,
            ["ckb-repro-build", "cangjie-humaneval-strict-score"]).ok, true)
    }

    @TestCase
    public func productionValidatorRejectsPathSecretAndBenchmarkCategories(): Unit {
        for (forbidden in [
            "/root/.ssh/id_ed25519",
            "D:\\Users\\alice\\.ssh\\id_ed25519",
            "E:/Users/alice/.ssh/id_ed25519",
            "ghp_exampleCredentialPayload0123456789",
            "sk-proj-exampleCredentialPayload0123456789",
            "Authorization: Basic Zm9vOmJhcg==",
            "/Volumes/PrivateDisk/ckb-data",
            "/private/company/ckb-data",
            "/srv/private/ckb-data",
            "/opt/internal/ckb-data",
            "\\\\server\\private\\ckb-data",
            "Z:\\private\\ckb-data",
            "AKIAIOSFODNN7EXAMPLE",
            "ASIAIOSFODNN7EXAMPLE",
            "AIzaSyExampleCredentialPayload",
            "github_pat_exampleCredentialPayload",
            "glpat-exampleCredentialPayload",
            "xoxb-exampleCredentialPayload",
            "ya29.exampleCredentialPayload",
            "-----BEGIN PRIVATE KEY-----",
            "Authorization: Digest credential-payload",
            "HumanEval_42",
            "HumanEval-42",
            "problem_id=HumanEval/042",
            "reference_solution: func solve()",
            "teacher solution payload",
            "hidden tests payload"
        ]) {
            let reader = p7FakeDocumentation(true)
            reader.put("docs/reproducibility/quick-start.md",
                p7ValidDocument(true) + "\n${forbidden}\n")
            let result = validateCkbReproDocumentation(
                reader, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
                Array<String>())
            @Expect(result.diagnostic, "documentation_path_or_secret_forbidden")
            @Expect(result.diagnostic.contains(forbidden), false)
        }
    }

    @TestCase
    public func productionValidatorRequiresAllSixRunbookSections(): Unit {
        for (section in [
            "目的", "工作目录", "命令", "预期输出", "通过标准", "失败处理"
        ]) {
            let reader = p7FakeDocumentation(true)
            reader.put("docs/reproducibility/quick-start.md",
                p7ValidDocument(true).replace(section, "已删除段落"))
            let result = validateCkbReproDocumentation(
                reader, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
                Array<String>())
            @Expect(result.diagnostic, "documentation_required_section_missing")
        }
    }

    @TestCase
    public func productionValidatorValidatesUnicodeAndCrossFileAnchors(): Unit {
        let valid = p7FakeDocumentation(true)
        valid.put("docs/reproducibility/quick-start.md",
            p7ValidDocument(true) +
                "\n## 中文 锚点🙂\n[本页](#中文-锚点🙂)\n" +
                "[跨页](troubleshooting.md#故障-处理)\n")
        valid.put("docs/reproducibility/troubleshooting.md",
            p7ValidDocument(true) + "\n## 故障 处理\n")
        @Expect(validateCkbReproDocumentation(
            valid, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
            Array<String>()).ok, true)

        let localMissing = p7FakeDocumentation(true)
        localMissing.put("docs/reproducibility/quick-start.md",
            p7ValidDocument(true) + "\n[本页](#不存在)\n")
        @Expect(validateCkbReproDocumentation(
            localMissing, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
            Array<String>()).diagnostic, "documentation_link_anchor_missing")

        let crossMissing = p7FakeDocumentation(true)
        crossMissing.put("docs/reproducibility/quick-start.md",
            p7ValidDocument(true) +
                "\n[跨页](troubleshooting.md#不存在)\n")
        @Expect(validateCkbReproDocumentation(
            crossMissing, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
            Array<String>()).diagnostic, "documentation_link_anchor_missing")
    }

    @TestCase
    public func productionValidatorCanonicalizesGithubStyleAnchors(): Unit {
        let valid = p7FakeDocumentation(true)
        valid.put("docs/reproducibility/quick-start.md",
            p7ValidDocument(true) +
                "\n## 中文，标题！\n[中文](#中文标题)\n" +
                "## [链接 标题](https://example.invalid) 与 `代码`\n" +
                "[链接标题](#链接-标题-与-代码)\n" +
                "## 重复 标题\n## 重复 标题\n" +
                "[重复一](#重复-标题)\n[重复二](#重复-标题-1)\n" +
                "<a name=\"custom-anchor\"></a>\n" +
                "<section id='custom-id'></section>\n" +
                "[自定义一](#custom-anchor)\n[自定义二](#custom-id)\n")
        @Expect(validateCkbReproDocumentation(
            valid, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
            Array<String>()).ok, true)

        let missingDuplicate = p7FakeDocumentation(true)
        missingDuplicate.put("docs/reproducibility/quick-start.md",
            p7ValidDocument(true) +
                "\n## 重复 标题\n## 重复 标题\n" +
                "[不存在的第三个](#重复-标题-2)\n")
        @Expect(validateCkbReproDocumentation(
            missingDuplicate, "/tmp/repro",
            CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
            Array<String>()).diagnostic, "documentation_link_anchor_missing")
    }

    @TestCase
    public func productionValidatorUsesGlobalGithubSlugOccupancy(): Unit {
        let valid = p7FakeDocumentation(true)
        valid.put("docs/reproducibility/quick-start.md",
            p7ValidDocument(true) +
                "\n## Foo\n## Foo-1\n## Foo\n" +
                "[first](#foo)\n[occupied](#foo-1)\n[third](#foo-2)\n")
        @Expect(validateCkbReproDocumentation(
            valid, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
            Array<String>()).ok, true)

        let missing = p7FakeDocumentation(true)
        missing.put("docs/reproducibility/quick-start.md",
            p7ValidDocument(true) +
                "\n## Foo\n## Foo-1\n## Foo\n" +
                "[wrong duplicate](#foo-3)\n")
        @Expect(validateCkbReproDocumentation(
            missing, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
            Array<String>()).diagnostic, "documentation_link_anchor_missing")
    }

    @TestCase
    public func productionValidatorRejectsAnchorTextThatIsNotHtml(): Unit {
        for (example in [
            "```html\n<a name=\"fake-anchor\"></a>\n```",
            "   ````html\n<a name=\"fake-anchor\"></a>\n````",
            "~~~~~html\n<a name=\"fake-anchor\"></a>\n~~~~~~",
            "    <a name=\"fake-anchor\"></a>",
            "\t<a name=\"fake-anchor\"></a>",
            "`<a name=\"fake-anchor\"></a>`",
            "&lt;a name=\"fake-anchor\"&gt;",
            "<div data-name=\"fake-anchor\"></div>"
        ]) {
            let reader = p7FakeDocumentation(true)
            reader.put("docs/reproducibility/quick-start.md",
                p7ValidDocument(true) + "\n${example}\n" +
                    "[must not resolve](#fake-anchor)\n")
            @Expect(validateCkbReproDocumentation(
                reader, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
                Array<String>()).diagnostic,
                "documentation_link_anchor_missing")
        }
    }

    @TestCase
    public func productionValidatorEnumeratesRealReaderSurface(): Unit {
        let reader = p7FakeDocumentation(true)
        reader.put("docs/service-http-operations.md", "# Service\n")
        reader.put("src/main.cj", "package fake\n")
        @Expect(validateCkbReproDocumentation(
            reader, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
            Array<String>()).ok, true)

        reader.put("docs/reproducibility/undeclared.md",
            p7ValidDocument(true))
        @Expect(validateCkbReproDocumentation(
            reader, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
            Array<String>()).diagnostic, "documentation_extra_release_entry")
    }

    @TestCase
    public func productionValidatorRequiresDraftMarkersAtPublicEntrypoints(): Unit {
        for (path in [
            "README.md", "docs/reproducibility/quick-start.md"
        ]) {
            let reader = p7FakeDocumentation(true)
            let original = if (path == "README.md") {
                p7ValidRootDocument(true)
            } else {
                p7ValidDocument(true)
            }
            reader.put(path, original.replace(
                "UNPUBLISHED_W3_DRAFT", "REMOVED_DRAFT_MARKER"))
            let result = validateCkbReproDocumentation(
                reader, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
                Array<String>())
            @Expect(result.diagnostic,
                "documentation_entrypoint_placeholder_missing")
        }
    }

    @TestCase
    public func productionRepositoryReaderEnumeratesFilesystemSurface(): Unit {
        @Expect(validateCkbReproDocumentation(
            P7RepositoryDocumentationReader(), "..",
            CKB_REPRO_DOCUMENTATION_MODE_RELEASE,
            p7ReleaseRegisteredCommands()).ok, true)

        let root = "target/p7-documentation-reader-surface"
        if (exists(Path(root))) { remove(Path(root), recursive: true) }
        try {
            p7CopyDocumentationSurface("..", root)
            let before = validateCkbReproDocumentation(
                P7RepositoryDocumentationReader(), root,
                CKB_REPRO_DOCUMENTATION_MODE_RELEASE,
                p7ReleaseRegisteredCommands())
            @Expect(before.ok, true)
            File.writeTo(
                Path("${root}/docs/reproducibility/undeclared.md"),
                p7ValidDocument(true).toArray())
            let after = validateCkbReproDocumentation(
                P7RepositoryDocumentationReader(), root,
                CKB_REPRO_DOCUMENTATION_MODE_RELEASE,
                p7ReleaseRegisteredCommands())
            @Expect(after.diagnostic, "documentation_extra_release_entry")
        } finally {
            if (exists(Path(root))) { remove(Path(root), recursive: true) }
        }
    }

    @TestCase
    public func productionRepositoryReaderRecursesAndRejectsNonRegularEntries(): Unit {
        let nestedRoot = "target/p7-documentation-reader-nested"
        p7ResetDocumentationSurface(nestedRoot)
        try {
            Directory.create(
                Path("${nestedRoot}/docs/reproducibility/audit"),
                recursive: true)
            File.writeTo(Path(
                "${nestedRoot}/docs/reproducibility/audit/notes.txt"),
                "safe nested file".toArray())
            @Expect(validateCkbReproDocumentation(
                P7RepositoryDocumentationReader(), nestedRoot,
                CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
                Array<String>()).diagnostic,
                "documentation_entry_type_forbidden")
        } finally {
            if (exists(Path(nestedRoot))) {
                remove(Path(nestedRoot), recursive: true)
            }
        }

        let directoryRoot = "target/p7-documentation-reader-directory"
        p7ResetDocumentationSurface(directoryRoot)
        try {
            Directory.create(Path(
                "${directoryRoot}/docs/reproducibility/directory.md"),
                recursive: true)
            @Expect(validateCkbReproDocumentation(
                P7RepositoryDocumentationReader(), directoryRoot,
                CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
                Array<String>()).diagnostic,
                "documentation_entry_type_forbidden")
        } finally {
            if (exists(Path(directoryRoot))) {
                remove(Path(directoryRoot), recursive: true)
            }
        }

        let emptyDirectoryRoot =
            "target/p7-documentation-reader-empty-directory"
        p7ResetDocumentationSurface(emptyDirectoryRoot)
        try {
            Directory.create(Path(
                "${emptyDirectoryRoot}/docs/reproducibility/empty"),
                recursive: true)
            @Expect(validateCkbReproDocumentation(
                P7RepositoryDocumentationReader(), emptyDirectoryRoot,
                CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
                Array<String>()).diagnostic,
                "documentation_entry_type_forbidden")
        } finally {
            if (exists(Path(emptyDirectoryRoot))) {
                remove(Path(emptyDirectoryRoot), recursive: true)
            }
        }

        let nestedEmptyDirectoryRoot =
            "target/p7-documentation-reader-nested-empty-directory"
        p7ResetDocumentationSurface(nestedEmptyDirectoryRoot)
        try {
            Directory.create(Path(
                "${nestedEmptyDirectoryRoot}/docs/reproducibility/" +
                    "outer/inner"),
                recursive: true)
            @Expect(validateCkbReproDocumentation(
                P7RepositoryDocumentationReader(),
                nestedEmptyDirectoryRoot,
                CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
                Array<String>()).diagnostic,
                "documentation_entry_type_forbidden")
        } finally {
            if (exists(Path(nestedEmptyDirectoryRoot))) {
                remove(Path(nestedEmptyDirectoryRoot), recursive: true)
            }
        }

        let symlinkRoot = "target/p7-documentation-reader-symlink"
        let outside = Path("target/p7-documentation-outside.md")
        p7ResetDocumentationSurface(symlinkRoot)
        File.writeTo(outside, "outside".toArray())
        try {
            let target = canonicalize(outside).toString()
            let link = Path(
                "${symlinkRoot}/docs/reproducibility/linked.md")
            @Expect(launch("/bin/ln", ["-s", target, link.toString()])
                .wait(), 0)
            @Expect(validateCkbReproDocumentation(
                P7RepositoryDocumentationReader(), symlinkRoot,
                CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
                Array<String>()).diagnostic,
                "documentation_entry_type_forbidden")
        } finally {
            if (exists(Path(symlinkRoot))) {
                remove(Path(symlinkRoot), recursive: true)
            }
            if (exists(outside)) { remove(outside) }
        }
    }

    @TestCase
    public func productionValidatorUsesMinimalPublicPosixPathAllowlist(): Unit {
        let allowed = p7FakeDocumentation(true)
        allowed.put("docs/reproducibility/quick-start.md",
            p7ValidDocument(true) +
                "\nhttps://example.invalid/private/company\n" +
                "GET /api/v1/status\n/usr/bin/env\n/dev/null\n")
        @Expect(validateCkbReproDocumentation(
            allowed, "/tmp/repro", CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
            Array<String>()).ok, true)

        for (forbiddenPath in [
            "/tmp/private",
            "/opt/homebrew/opt/openssl@3/lib",
            "/etc/ssl/cert.pem",
            "/path/to/cangjie"
        ]) {
            let forbidden = p7FakeDocumentation(true)
            forbidden.put("docs/reproducibility/quick-start.md",
                p7ValidDocument(true) + "\n${forbiddenPath}\n")
            @Expect(validateCkbReproDocumentation(
                forbidden, "/tmp/repro",
                CKB_REPRO_DOCUMENTATION_MODE_DRAFT,
                Array<String>()).diagnostic,
                "documentation_path_or_secret_forbidden")
        }
    }
}

private class P7RepositoryDocumentationReader <: CkbReproDocumentationReader {
    public func list(root: String):
        ArrayList<CkbReproDocumentationEntry> {
        let out = ArrayList<CkbReproDocumentationEntry>()
        let canonicalRoot = try {
            canonicalize(Path(root))
        } catch (_: Exception) {
            return out
        }
        for (entry in Directory.readFrom(canonicalRoot)) {
            if (entry.name == "README.md") {
                out.add(p7FilesystemDocumentationEntry(
                    canonicalRoot, entry.path, "README.md"))
            }
        }
        let documentationRoot =
            canonicalRoot.join("docs/reproducibility")
        if (!exists(documentationRoot)) { return out }
        let canonicalDocumentationRoot = try {
            canonicalize(documentationRoot)
        } catch (_: Exception) {
            out.add(p7DocumentationEntry(
                "docs/reproducibility", CKB_REPRO_DOCUMENTATION_ENTRY_SYMLINK))
            return out
        }
        if (canonicalDocumentationRoot.toString() !=
            documentationRoot.toString()) {
            let kind = if (p7FilesystemWithin(
                canonicalRoot, canonicalDocumentationRoot)) {
                CKB_REPRO_DOCUMENTATION_ENTRY_SYMLINK
            } else {
                CKB_REPRO_DOCUMENTATION_ENTRY_OUTSIDE
            }
            out.add(p7DocumentationEntry("docs/reproducibility", kind))
            return out
        }
        try {
            p7CollectFilesystemDocumentation(
                canonicalRoot, canonicalDocumentationRoot, "", out)
        } catch (_: Exception) {
            out.add(p7DocumentationEntry(
                "docs/reproducibility",
                CKB_REPRO_DOCUMENTATION_ENTRY_DIRECTORY))
        }
        out
    }

    public func read(root: String, relativePath: String):
        CkbReproDocumentationRead {
        let out = CkbReproDocumentationRead()
        let path = Path("${root}/${relativePath}")
        if (!exists(path)) { return out }
        out.found = true
        try {
            out.bytes = File.readFrom(path)
        } catch (_: Exception) {
            out.found = false
        }
        out
    }
}

private class P7FakeDocumentationReader <: CkbReproDocumentationReader {
    private let paths = ArrayList<String>()
    private let values = ArrayList<Array<UInt8>>()

    public func put(path: String, text: String): Unit {
        putBytes(path, text.toArray())
    }

    public func putBytes(path: String, bytes: Array<UInt8>): Unit {
        let index = indexOf(path)
        if (index >= 0) {
            values[index] = bytes
            return
        }
        paths.add(path)
        values.add(bytes)
    }

    public func remove(path: String): Unit {
        let index = indexOf(path)
        if (index >= 0) {
            paths.remove(at: index)
            values.remove(at: index)
        }
    }

    public func list(root: String):
        ArrayList<CkbReproDocumentationEntry> {
        let out = ArrayList<CkbReproDocumentationEntry>()
        for (path in paths) {
            out.add(p7DocumentationEntry(
                path, CKB_REPRO_DOCUMENTATION_ENTRY_REGULAR))
        }
        out
    }

    public func read(root: String, relativePath: String):
        CkbReproDocumentationRead {
        let out = CkbReproDocumentationRead()
        let index = indexOf(relativePath)
        if (index < 0) { return out }
        out.found = true
        out.bytes = values[index]
        out
    }

    private func indexOf(path: String): Int64 {
        for (index in 0..paths.size) {
            if (paths[index] == path) { return index }
        }
        -1
    }
}

private func p7CollectFilesystemDocumentation(
    root: Path, current: Path, prefix: String,
    out: ArrayList<CkbReproDocumentationEntry>): Unit {
    for (entry in Directory.readFrom(current)) {
        let nested = if (prefix == "") {
            entry.name
        } else {
            "${prefix}/${entry.name}"
        }
        let relative = "docs/reproducibility/${nested}"
        let classified = p7FilesystemDocumentationEntry(
            root, entry.path, relative)
        out.add(classified)
        if (classified.kind ==
            CKB_REPRO_DOCUMENTATION_ENTRY_DIRECTORY) {
            p7CollectFilesystemDocumentation(
                root, entry.path, nested, out)
        }
    }
}

private func p7FilesystemDocumentationEntry(
    root: Path, path: Path, relative: String):
    CkbReproDocumentationEntry {
    let canonical = try {
        canonicalize(path)
    } catch (_: Exception) {
        return p7DocumentationEntry(
            relative, CKB_REPRO_DOCUMENTATION_ENTRY_SYMLINK)
    }
    if (!p7FilesystemWithin(root, canonical)) {
        return p7DocumentationEntry(
            relative, CKB_REPRO_DOCUMENTATION_ENTRY_OUTSIDE)
    }
    if (canonical.toString() != path.toString()) {
        return p7DocumentationEntry(
            relative, CKB_REPRO_DOCUMENTATION_ENTRY_SYMLINK)
    }
    var directory = false
    var regular = false
    for (entry in Directory.readFrom(path.parent)) {
        if (entry.name == path.fileName) {
            directory = entry.isDirectory()
            regular = entry.isRegular()
            break
        }
    }
    if (regular) {
        p7DocumentationEntry(
            relative, CKB_REPRO_DOCUMENTATION_ENTRY_REGULAR)
    } else if (directory) {
        p7DocumentationEntry(
            relative, CKB_REPRO_DOCUMENTATION_ENTRY_DIRECTORY)
    } else {
        p7DocumentationEntry(
            relative, CKB_REPRO_DOCUMENTATION_ENTRY_SYMLINK)
    }
}

private func p7FilesystemWithin(root: Path, candidate: Path): Bool {
    let base = root.toString()
    let value = candidate.toString()
    value == base || value.startsWith("${base}/")
}

private func p7DocumentationEntry(
    relativePath: String, kind: String): CkbReproDocumentationEntry {
    let out = CkbReproDocumentationEntry()
    out.relativePath = relativePath
    out.kind = kind
    out
}

private func p7FakeDocumentation(draft: Bool): P7FakeDocumentationReader {
    let reader = P7FakeDocumentationReader()
    for (relative in requiredCkbReproDocumentationFiles()) {
        reader.put(relative, if (relative == "README.md") {
            p7ValidRootDocument(draft)
        } else {
            p7ValidDocument(draft)
        })
    }
    reader
}

private func p7ValidRootDocument(draft: Bool): String {
    "# CKB\n" + p7ModeMarkers(draft) +
        "\n[复现导航](docs/reproducibility/README.md)\n"
}

private func p7ValidDocument(draft: Bool): String {
    "# 手册\n\n目的：验证可复现流程。\n\n工作目录：`\${CKB_ROOT}`。\n\n" +
        "命令：执行只读检查。\n\n预期输出：诊断为 valid。\n\n" +
        "通过标准：退出码为 0。\n\n失败处理：立即停止，不绕过门禁。\n\n" +
        p7ModeMarkers(draft) +
        "\n`\${CKB_ROOT}` `\${REPRO_ROOT}` 中文🙂\n"
}

private func p7ModeMarkers(draft: Bool): String {
    if (draft) {
        "UNPUBLISHED_W3_DRAFT PENDING_W4_CLI_REGISTRATION " +
            "UNPUBLISHED_P8_A_REFERENCE UNAVAILABLE_UNTIL_W7"
    } else {
        "PUBLISHED"
    }
}

private func p7CopyDocumentationSurface(
    sourceRoot: String, targetRoot: String): Unit {
    Directory.create(Path("${targetRoot}/docs/reproducibility"),
        recursive: true)
    for (relative in requiredCkbReproDocumentationFiles()) {
        let target = Path("${targetRoot}/${relative}")
        if (!exists(target.parent)) {
            Directory.create(target.parent, recursive: true)
        }
        File.writeTo(target,
            File.readFrom(Path("${sourceRoot}/${relative}")))
    }
    File.writeTo(Path("${targetRoot}/docs/service-http-operations.md"),
        File.readFrom(Path(
            "${sourceRoot}/docs/service-http-operations.md")))
}

private func p7ResetDocumentationSurface(root: String): Unit {
    if (exists(Path(root))) { remove(Path(root), recursive: true) }
    p7CopyDocumentationSurface("..", root)
}

private func p7RequiredDocuments(): Array<String> {
    [
        "docs/reproducibility/README.md",
        "docs/reproducibility/quick-start.md",
        "docs/reproducibility/restore-knowledge-base.md",
        "docs/reproducibility/rebuild-from-source.md",
        "docs/reproducibility/configure-claude-glm.md",
        "docs/reproducibility/freeze-humaneval-authority-delivery.md",
        "docs/reproducibility/run-humaneval-164.md",
        "docs/reproducibility/verify-strict-pass-at-1.md",
        "docs/reproducibility/result-interpretation.md",
        "docs/reproducibility/troubleshooting.md",
        "docs/reproducibility/release-maintainer-runbook.md"
    ]
}

private func p7ReleaseRegisteredCommands(): Array<String> {
    ["cangjie-humaneval-pass1-gate", "ckb-authority-bundle",
        "ckb-release-import", "ckb-repro-build", "ckb-repro-verify"]
}

private func p7DocumentationText(): String {
    let out = StringBuilder()
    out.append(p7Read("../README.md"))
    out.append("\n")
    for (relative in p7RequiredDocuments()) {
        out.append(p7Read("../${relative}"))
        out.append("\n")
    }
    out.toString()
}

private func p7Read(path: String): String {
    try {
        String.fromUtf8(File.readFrom(Path(path)))
    } catch (_: Exception) {
        ""
    }
}
