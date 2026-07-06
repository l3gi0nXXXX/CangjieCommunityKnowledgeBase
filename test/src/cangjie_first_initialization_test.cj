package cangjie_community_knowledge_base_test

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieFirstInitializationTest {
    @TestCase
    public func p0Pos001ParsesExplicitOptions(): Unit {
        let options = parseCkbFirstInitOptions([
            "--dry-run",
            "--docs-root", "target/fixtures/docs",
            "--tool-docs-root", "target/fixtures/tools",
            "--std-root", "target/fixtures/std",
            "--stdx-root", "target/fixtures/stdx",
            "--eval-root", "target/fixtures/eval",
            "--target-version", "1.0.0"
        ])

        @Expect(options.dryRun, true)
        @Expect(options.apply, false)
        @Expect(options.docsRoot, "target/fixtures/docs")
        @Expect(options.toolDocsRoot, "target/fixtures/tools")
        @Expect(options.stdRoot, "target/fixtures/std")
        @Expect(options.stdxRoot, "target/fixtures/stdx")
        @Expect(options.evalRoot, "target/fixtures/eval")
        @Expect(options.targetVersion, "1.0.0")
        @Expect(options.diagnostics.size, 0)
    }

    @TestCase
    public func p0Neg001RejectsApplyAndDryRunConflict(): Unit {
        let options = parseCkbFirstInitOptions(["--apply", "--dry-run", "--target-version", "1.0.0"])

        @Expect(options.diagnostics.contains("apply_and_dry_run_conflict"), true)
    }

    @TestCase
    public func p0Bnd001RejectsUnsafePathsWithoutReadingFiles(): Unit {
        let options = parseCkbFirstInitOptions(["--docs-root", "../real-docs", "--eval-root", "/tmp/hidden/case"])

        @Expect(options.diagnostics.contains("invalid_docs_root"), true)
        @Expect(options.diagnostics.contains("invalid_eval_root"), true)
    }

    @TestCase
    public func p0Ut001RendersHumanReadableResultWithoutRawJson(): Unit {
        let result = CkbFirstInitResult()
        result.ok = true
        result.dryRun = true
        result.validation.ok = true
        result.activeVersion = "ckb-test-active"
        let summary = CkbFirstInitSourceSummary()
        summary.name = "docs"
        summary.ok = true
        summary.fileCount = 2
        summary.recordCount = 5
        result.sources.add(summary)

        let rendered = renderCkbFirstInitResult(result)

        @Expect(rendered.contains("first-init preflight ok=true"), true)
        @Expect(rendered.contains("source docs ok=true files=2 records=5"), true)
        @Expect(rendered.contains("\"ok\""), false)
    }
}
