package cangjie_community_knowledge_base_test

import std.collection.*
import std.fs.{Directory, File, Path, exists}
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
        @Expect(rendered.contains("queryCheck="), false)
        @Expect(rendered.contains("\"ok\""), false)
    }

    @TestCase
    public func p4Ut001LoadsTypedRecordsIntoCandidateWithoutDroppingKinds(): Unit {
        let fixture = ckbFirstInitWriteFullFixture("target/p4-first-init-load", true)
        let options = ckbFirstInitOptionsForFixture(fixture, false)
        let assembly = assembleCkbFirstInitializationRecords(options)
        let kb = newOfflineKnowledgeBase()

        let candidate = kb.loadFirstInitializationTypedRecords(assembly.records, ckbFirstInitCandidateVersion("1.0.0"))

        @Expect(candidate, "ckb-first-init-1-0-0-candidate")
        @Expect(kb.rawRecordCount(), assembly.records.size)
        @Expect(kb.normalizedRecordCount(), assembly.records.size)
        @Expect(kb.candidateRecordSnapshot().size, assembly.records.size)
    }

    @TestCase
    public func p4Bnd001DedupesDuplicateTypedRecordsDeterministically(): Unit {
        let records = ArrayList<CangjieTypedRecord>()
        let first = CangjieTypedRecord()
        first.recordKind = CangjieTypedRecordKinds.DOC_SECTION
        first.sourceId = "dup"
        first.content = "same"
        first.contentHash = "h1"
        let second = CangjieTypedRecord()
        second.recordKind = CangjieTypedRecordKinds.DOC_SECTION
        second.sourceId = "dup"
        second.content = "same"
        second.contentHash = "h1"
        records.add(first)
        records.add(second)

        let deduped = dedupeCkbFirstInitializationRecords(records)

        @Expect(deduped.size, 1)
        @Expect(deduped[0].sourceId, "dup")
    }

    @TestCase
    public func p4Pos001RunsFullFixtureApplyAndPersistsActiveSnapshot(): Unit {
        let fixture = ckbFirstInitWriteFullFixture("target/p4-first-init-apply", true)
        let options = ckbFirstInitOptionsForFixture(fixture, true)
        let store = FileKnowledgeStore("target/p4-first-init-apply-store")

        let result = runCkbFirstInitialization(options, store)
        let loaded = newKnowledgeBaseFromStore(store)
        let status = cangjie_knowledge_status(loaded.kb)
        let rendered = renderCkbFirstInitResult(result)

        @Expect(result.ok, true)
        @Expect(result.persisted, true)
        @Expect(result.validation.ok, true)
        @Expect(result.activeVersion, "ckb-first-init-1-0-0-active")
        @Expect(status.activeKnowledgeVersion, "ckb-first-init-1-0-0-active")
        @Expect(status.activeStateSource, "first_initialization")
        @Expect(store.has("raw/records.ckb"), true)
        @Expect(store.has("normalized/records.ckb"), true)
        @Expect(store.has("index/active.ckb"), true)
        @Expect(store.has("index/vector-active.ckb"), true)
        @Expect(store.has("index/graph-nodes.ckb"), true)
        @Expect(rendered.contains("queryCheck=symbol:ArrayList.add=hit"), true)
    }

    @TestCase
    public func p4Neg001ValidationFailureWritesCandidateButKeepsOldActive(): Unit {
        let fixture = ckbFirstInitWriteFullFixture("target/p4-first-init-missing-tool", false)
        let store = FileKnowledgeStore("target/p4-first-init-fail-store")
        let beforeKb = newOfflineKnowledgeBase()
        let rebuild = ckbRebuildIndex(beforeKb, store)
        let before = cangjie_knowledge_status(beforeKb).activeKnowledgeVersion
        let options = ckbFirstInitOptionsForFixture(fixture, true)

        let result = runCkbFirstInitialization(options, store)
        let loaded = newKnowledgeBaseFromStore(store)
        let after = cangjie_knowledge_status(loaded.kb)

        @Expect(rebuild.ok, true)
        @Expect(result.ok, false)
        @Expect(result.validation.ok, false)
        @Expect(result.validation.failedGates.contains("missing_tool_cjpm_test"), true)
        @Expect(after.activeKnowledgeVersion, before)
        @Expect(store.has("raw/candidate/${result.candidateVersion}/records.ckb"), true)
        @Expect(store.has("index/active.ckb"), true)
    }

    @TestCase
    public func p5Ut001ParsesCangjieInitializeDryRunCommand(): Unit {
        let options = parseCkbFirstInitOptions([
            "cangjie-initialize",
            "--dry-run",
            "--docs-root", "target/p5-cli/docs",
            "--std-root", "target/p5-cli/std",
            "--stdx-root", "target/p5-cli/stdx",
            "--eval-root", "target/p5-cli/eval",
            "--target-version", "1.0.0"
        ])

        @Expect(options.dryRun, true)
        @Expect(options.apply, false)
        @Expect(options.docsRoot, "target/p5-cli/docs")
        @Expect(options.stdRoot, "target/p5-cli/std")
        @Expect(options.stdxRoot, "target/p5-cli/stdx")
        @Expect(options.evalRoot, "target/p5-cli/eval")
        @Expect(options.diagnostics.size, 0)
    }

    @TestCase
    public func p5Bnd001AlreadyInitializedStoreNoOpsWithoutRewritingActive(): Unit {
        let fixture = ckbFirstInitWriteFullFixture("target/p5-noop-fixture", true)
        let store = FileKnowledgeStore("target/p5-noop-store")
        let options = ckbFirstInitOptionsForFixture(fixture, true)
        let first = runCkbFirstInitializationWithActiveGuard(options, store)

        let second = runCkbFirstInitializationWithActiveGuard(options, store)

        @Expect(first.ok, true)
        @Expect(second.ok, true)
        @Expect(second.persisted, false)
        @Expect(second.activeVersion, first.activeVersion)
        @Expect(second.diagnostics.contains("already_initialized"), true)
    }

    @TestCase
    public func p5Pos001ServiceStartAutoInitializesEmptyStoreWhenEnabled(): Unit {
        let fixture = ckbFirstInitWriteFullFixture("target/p5-auto-service-fixture", true)
        let store = FileKnowledgeStore("target/p5-auto-service-store")
        let config = ckbFirstInitRuntimeForFixture(fixture)
        let service = CkbCommandLoopService(config, store)

        let started = service.start()
        let status = service.statusSnapshot()

        @Expect(started.contains("service_started"), true)
        @Expect(status.activeKnowledgeVersion, "ckb-first-init-1-0-0-active")
        @Expect(status.activeStateSource, "first_initialization")
        @Expect(store.has("index/active.ckb"), true)
    }

    @TestCase
    public func p5Neg001AdminInitializeRequiresAuthorizationAndDoesNotWriteStore(): Unit {
        let fixture = ckbFirstInitWriteFullFixture("target/p5-admin-denied-fixture", true)
        let store = FileKnowledgeStore("target/p5-admin-denied-store")
        let config = CkbRuntimeConfig()
        let service = CkbCommandLoopService(config, store)
        service.start()

        let body = "{\"apply\":true,\"docsRoot\":\"${fixture.docsRoot}\",\"stdRoot\":\"${fixture.stdRoot}\",\"stdxRoot\":\"${fixture.stdxRoot}\",\"evalRoot\":\"${fixture.evalRoot}\",\"targetVersion\":\"1.0.0\"}"
        let response = ckbApiHandle(service, "POST", "/v1/admin/initialize", body, [])

        @Expect(response.contains("\"ok\":false"), true)
        @Expect(response.contains("ckb.unauthorized"), true)
        @Expect(store.has("index/active.ckb"), false)
    }
}

private class CkbFirstInitFixturePaths {
    var docsRoot: String = ""
    var stdRoot: String = ""
    var stdxRoot: String = ""
    var evalRoot: String = ""

    init() {}
}

private func ckbFirstInitWriteFullFixture(root: String, includeTool: Bool): CkbFirstInitFixturePaths {
    let fixture = CkbFirstInitFixturePaths()
    fixture.docsRoot = "${root}/docs"
    fixture.stdRoot = "${root}/std"
    fixture.stdxRoot = "${root}/stdx"
    fixture.evalRoot = "${root}/eval"
    ckbFirstInitWriteFile(Path(fixture.docsRoot).join("dev-guide/source_en/api/collections.md"), "# Collections\nArrayList.add and HashMap are collection APIs.\n")
    if (includeTool) {
        ckbFirstInitWriteFile(Path(fixture.docsRoot).join("tools/source_en/cmd-tools/cjpm_manual.md"), "# cjpm test\nUse cjpm test to run package tests.\n")
    }
    ckbFirstInitWriteFile(Path(fixture.stdRoot).join("src/std/collection/arraylist.cj"), """
package std.collection
public class ArrayList<T> {
    public func add(value: T): Unit {}
}
public class HashMap<K, V> {}
""")
    ckbFirstInitWriteFile(Path(fixture.stdRoot).join("src/std/core/string.cj"), """
package std.core
extend String {
    public func contains(pattern: String): Bool {}
}
""")
    ckbFirstInitWriteFile(Path(fixture.stdxRoot).join("src/stdx/options/option.cj"), "package stdx.options\npublic enum Option<T> { Some | None }\n")
    let caseRoot = Path(fixture.evalRoot).join("CJ-HUMANEVAL-000")
    ckbFirstInitWriteFile(caseRoot.join("prompt.md"), "# Task\nUse EvalValue and EvalEntry.\n")
    ckbFirstInitWriteFile(caseRoot.join("metadata.json"), "{\"id\":\"CJ-HUMANEVAL-000\"}\n")
    ckbFirstInitWriteFile(caseRoot.join("starter/src/eval_support.cj"), "public class EvalValue {}\npublic class EvalEntry {}\n")
    ckbFirstInitWriteFile(caseRoot.join("tests/TestMain.cj"), "public func helper(): Unit {}\nmain() {}\n")
    fixture
}

private func ckbFirstInitOptionsForFixture(fixture: CkbFirstInitFixturePaths, apply: Bool): CkbFirstInitOptions {
    let options = CkbFirstInitOptions()
    options.docsRoot = fixture.docsRoot
    options.stdRoot = fixture.stdRoot
    options.stdxRoot = fixture.stdxRoot
    options.evalRoot = fixture.evalRoot
    options.targetVersion = "1.0.0"
    options.apply = apply
    options.dryRun = !apply
    options
}

private func ckbFirstInitRuntimeForFixture(fixture: CkbFirstInitFixturePaths): CkbRuntimeConfig {
    let config = CkbRuntimeConfig()
    config.firstInitEnabled = true
    config.firstInitDocsRoot = fixture.docsRoot
    config.firstInitStdRoot = fixture.stdRoot
    config.firstInitStdxRoot = fixture.stdxRoot
    config.firstInitEvalRoot = fixture.evalRoot
    config.firstInitTargetVersion = "1.0.0"
    config
}

private func ckbFirstInitWriteFile(path: Path, text: String): Unit {
    if (!exists(path.parent)) {
        Directory.create(path.parent, recursive: true)
    }
    File.writeTo(path, text.toArray())
}
