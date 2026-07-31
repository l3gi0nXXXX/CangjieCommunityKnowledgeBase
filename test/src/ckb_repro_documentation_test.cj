package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{File, Path, exists}
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
        @Expect(root.contains("## 复现 HumanEval 151/164"), true)
        @Expect(root.contains("UNPUBLISHED_W3_DRAFT"), true)
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
    public func p7DraftQuickStartCannotMasqueradeAsPublished(): Unit {
        let root = p7Read("../README.md")
        let quick = p7Read("../docs/reproducibility/quick-start.md")
        for (text in [root, quick]) {
            @Expect(text.contains("UNPUBLISHED_W3_DRAFT"), true)
            @Expect(text.contains("PENDING_W4_CLI_REGISTRATION"), true)
            @Expect(text.contains("不可发布"), true)
        }
        @Expect(quick.contains("ckb-humaneval-151-repro-v1.0.0"), false)
        @Expect(quick.contains("strictPassed=151"), false)
    }

    @TestCase
    public func p7DraftStrictEvidenceCannotClaimPortable151(): Unit {
        let strict = p7Read("../docs/reproducibility/verify-strict-pass-at-1.md")
        @Expect(strict.contains("UNPUBLISHED_P8_A_REFERENCE"), true)
        @Expect(strict.contains("UNAVAILABLE_UNTIL_W7"), true)
        @Expect(strict.contains("历史迁移基线"), true)
        @Expect(strict.contains("portable strict pass@1=151/164"), false)
        @Expect(strict.contains("cangjie-humaneval-strict-score"), true)
        @Expect(strict.contains("待 W4 激活"), true)
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
            "sk-live-", "Bearer ey", "PRIVATE-TOKEN:"
        ]) {
            @Expect(docs.contains(forbidden), false)
        }
        @Expect(docs.contains("\${CKB_ROOT}"), true)
        @Expect(docs.contains("\${REPRO_ROOT}"), true)
        @Expect(docs.contains("\${TMPDIR:-/tmp}"), true)
        @Expect(docs.contains("路径可包含空格"), true)
        @Expect(docs.contains("export cjHeapSize=4GB"), true)
        @Expect(docs.contains("export DYLD_LIBRARY_PATH="), true)
        @Expect(docs.contains("docs/service-http-operations.md"), true)
    }

    @TestCase
    public func productionValidatorAcceptsCurrentDraft(): Unit {
        let evidence = validateCkbReproDocumentation(
            P7RepositoryDocumentationReader(), "..",
            CKB_REPRO_DOCUMENTATION_MODE_DRAFT, Array<String>())
        @Expect(evidence.ok, true)
        @Expect(evidence.diagnostic, "documentation_valid")
        @Expect(evidence.requiredDocumentCount, 11)
        @Expect(evidence.discoveredDocumentCount, 11)
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
}

private class P7RepositoryDocumentationReader <: CkbReproDocumentationReader {
    public func list(root: String): ArrayList<String> {
        let out = ArrayList<String>()
        for (relative in requiredCkbReproDocumentationFiles()) {
            if (exists(Path("${root}/${relative}"))) { out.add(relative) }
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

    public func list(root: String): ArrayList<String> {
        let out = ArrayList<String>()
        for (path in paths) { out.add(path) }
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
    "# 手册\n\n目的：验证可复现流程。\n\n通过标准：退出码为 0。\n\n" +
        "失败处理：立即停止，不绕过门禁。\n\n" + p7ModeMarkers(draft) +
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

private func p7RequiredDocuments(): Array<String> {
    [
        "docs/reproducibility/README.md",
        "docs/reproducibility/quick-start.md",
        "docs/reproducibility/restore-knowledge-base.md",
        "docs/reproducibility/rebuild-from-source.md",
        "docs/reproducibility/configure-claude-glm.md",
        "docs/reproducibility/run-humaneval-164.md",
        "docs/reproducibility/verify-strict-pass-at-1.md",
        "docs/reproducibility/result-interpretation.md",
        "docs/reproducibility/troubleshooting.md",
        "docs/reproducibility/release-maintainer-runbook.md"
    ]
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
