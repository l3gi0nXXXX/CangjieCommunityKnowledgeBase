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
