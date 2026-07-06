package cangjie_community_knowledge_base_test

import std.fs.{Directory, File, Path, exists}
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieReleaseGateTest {
    @TestCase
    public func f8Ut001ReleaseGateFakeAllPass(): Unit {
        let fixture = f8WriteFirstInitFixture("target/f8-ut-fixture", true)
        let runRoot = "target/f8-ut-run"
        f8WritePass1Files(runRoot, true)
        let options = f8ReleaseGateOptions(runRoot, fixture)
        options.schedulerTaskNames.add("cangjie_docs_full_weekly")
        let store = FileKnowledgeStore("target/f8-ut-store")

        let report = cangjieKnowledgeReleaseGate(options, CkbRuntimeConfig(), store, sourceRunner: FakeSourceFetchRunner())
        let json = renderCangjieKnowledgeReleaseGateJson(report)

        @Expect(report.ok, true)
        @Expect(report.releaseGate, "pass")
        @Expect(json.contains("\"releaseGate\":\"pass\""), true)
        @Expect(f8HasStep(report, "E2E-01-first-init", true), true)
        @Expect(f8HasStep(report, "E2E-02-route-probe", true), true)
        @Expect(f8HasStep(report, "E2E-03-scheduler-forced-run", true), true)
        @Expect(f8HasStep(report, "E2E-04-transport-parity", true), true)
        @Expect(f8HasStep(report, "E2E-05-pass1-gate", true), true)
        @Expect(exists(Path("${runRoot}/release-gate.json")), true)
        @Expect(exists(Path("${runRoot}/route-probe.jsonl")), true)
        @Expect(exists(Path("${runRoot}/transport-parity.jsonl")), true)
    }

    @TestCase
    public func f8Bnd001ReleaseGateMissingRunRootReturnsUsageFailure(): Unit {
        let manifest = "target/f8-bnd-manifest.jsonl"
        f8WriteFile(Path(manifest), f8ManifestLine("CJ-HUMANEVAL-000", "Use ArrayList.", "[\"ArrayList\"]") + "\n")

        let exitCode = runCangjieKnowledgeReleaseGate(["cangjie-knowledge-release-gate", "--manifest", manifest])

        @Expect(exitCode, 2)
        @Expect(exists(Path("target/f8-bnd-run/release-gate.json")), false)
    }

    @TestCase
    public func f8Pos001CliReleaseGateWritesReproducibleArtifacts(): Unit {
        let fixture = f8WriteFirstInitFixture("target/f8-pos-fixture", true)
        let runRoot = "target/f8-pos-run"
        f8WritePass1Files(runRoot, true)
        let store = FileKnowledgeStore("target/f8-pos-store")

        let exitCode = runCangjieKnowledgeReleaseGate(f8ReleaseGateArgs(runRoot, fixture), store: store, sourceRunner: FakeSourceFetchRunner())

        @Expect(exitCode, 0)
        @Expect(exists(Path("${runRoot}/release-gate.md")), true)
        @Expect(String.fromUtf8(File.readFrom(Path("${runRoot}/release-gate.json"))).contains("\"releaseGate\":\"pass\""), true)
        @Expect(store.has("index/active.ckb"), true)
    }

    @TestCase
    public func f8Neg001Pass1MismatchFailsWholeReleaseGate(): Unit {
        let fixture = f8WriteFirstInitFixture("target/f8-neg-fixture", true)
        let runRoot = "target/f8-neg-run"
        f8WritePass1Files(runRoot, false)
        let options = f8ReleaseGateOptions(runRoot, fixture)
        options.schedulerTaskNames.add("cangjie_docs_full_weekly")

        let report = cangjieKnowledgeReleaseGate(options, CkbRuntimeConfig(), FileKnowledgeStore("target/f8-neg-store"), sourceRunner: FakeSourceFetchRunner())

        @Expect(report.ok, false)
        @Expect(report.releaseGate, "fail")
        @Expect(f8HasStep(report, "E2E-05-pass1-gate", false), true)
        @Expect(f8DiagnosticsContain(report, "E2E-05-pass1-gate"), true)
        @Expect(exists(Path("${runRoot}/gap-curation-input.jsonl")), true)
    }
}

private class F8FirstInitFixturePaths {
    var docsRoot: String = ""
    var stdRoot: String = ""
    var stdxRoot: String = ""
    var evalRoot: String = ""

    init() {}
}

private func f8ReleaseGateOptions(runRoot: String, fixture: F8FirstInitFixturePaths): CangjieKnowledgeReleaseGateOptions {
    let options = CangjieKnowledgeReleaseGateOptions()
    options.runRoot = runRoot
    options.manifestPath = "${runRoot}/manifest.jsonl"
    options.expectedTotal = 1
    options.expectedPass = 1
    options.docsRoot = fixture.docsRoot
    options.stdRoot = fixture.stdRoot
    options.stdxRoot = fixture.stdxRoot
    options.evalRoot = fixture.evalRoot
    options.targetVersion = "1.0.0"
    options
}

private func f8ReleaseGateArgs(runRoot: String, fixture: F8FirstInitFixturePaths): Array<String> {
    [
        "cangjie-knowledge-release-gate",
        "--run-root", runRoot,
        "--manifest", "${runRoot}/manifest.jsonl",
        "--expected-total", "1",
        "--expected-pass", "1",
        "--docs-root", fixture.docsRoot,
        "--std-root", fixture.stdRoot,
        "--stdx-root", fixture.stdxRoot,
        "--eval-root", fixture.evalRoot,
        "--target-version", "1.0.0",
        "--scheduler-tasks", "cangjie_docs_full_weekly"
    ]
}

private func f8WritePass1Files(runRoot: String, pass: Bool): Unit {
    f8EnsureDir(runRoot)
    f8WriteFile(Path("${runRoot}/manifest.jsonl"), f8ManifestLine("CJ-HUMANEVAL-000", "Implement ArrayList helper.", "[\"ArrayList\",\"Cangjie syntax\"]") + "\n")
    let dPass = pass
    let results = f8ResultLine("CJ-HUMANEVAL-000", CangjieHumanEvalPass1GateGroups.C, true, "none", false, "cangjie_task_knowledge_pack") + "\n" +
        f8ResultLine("CJ-HUMANEVAL-000", CangjieHumanEvalPass1GateGroups.D, dPass, if (dPass) { "none" } else { "compile_error" }, false, "cangjie_task_knowledge_pack") + "\n"
    f8WriteFile(Path("${runRoot}/results.jsonl"), results)
}

private func f8WriteFirstInitFixture(root: String, includeTool: Bool): F8FirstInitFixturePaths {
    let fixture = F8FirstInitFixturePaths()
    fixture.docsRoot = "${root}/docs"
    fixture.stdRoot = "${root}/std"
    fixture.stdxRoot = "${root}/stdx"
    fixture.evalRoot = "${root}/eval"
    f8WriteFile(Path(fixture.docsRoot).join("dev-guide/source_en/api/collections.md"), "# Collections\nArrayList.add and HashMap are collection APIs.\nString.contains supports string matching.\n")
    if (includeTool) {
        f8WriteFile(Path(fixture.docsRoot).join("tools/source_en/cmd-tools/cjpm_manual.md"), "# cjpm test\nUse cjpm test to run package tests.\n")
    }
    f8WriteFile(Path(fixture.stdRoot).join("src/std/collection/arraylist.cj"), """
package std.collection
public class ArrayList<T> {
    public func add(value: T): Unit {}
}
public class HashMap<K, V> {}
""")
    f8WriteFile(Path(fixture.stdRoot).join("src/std/core/string.cj"), """
package std.core
extend String {
    public func contains(pattern: String): Bool {}
}
""")
    f8WriteFile(Path(fixture.stdxRoot).join("src/stdx/options/option.cj"), "package stdx.options\npublic enum Option<T> { Some | None }\n")
    let caseRoot = Path(fixture.evalRoot).join("CJ-HUMANEVAL-000")
    f8WriteFile(caseRoot.join("prompt.md"), "# Task\nUse EvalValue and EvalEntry.\n")
    f8WriteFile(caseRoot.join("metadata.json"), "{\"id\":\"CJ-HUMANEVAL-000\"}\n")
    f8WriteFile(caseRoot.join("starter/src/eval_support.cj"), "public class EvalValue {}\npublic class EvalEntry {}\n")
    f8WriteFile(caseRoot.join("tests/TestMain.cj"), "public func helper(): Unit {}\nmain() {}\n")
    fixture
}

private func f8ManifestLine(caseId: String, prompt: String, tagsJson: String): String {
    "{\"id\":\"${caseId}\",\"category\":\"unit\",\"targetVersion\":\"1.0.0\",\"prompt\":\"${prompt}\",\"entryPoint\":\"cases/${caseId}/starter\",\"testCommand\":\"cjpm run\",\"expectedKnowledgeTags\":${tagsJson}}"
}

private func f8ResultLine(caseId: String, group: String, passAt1: Bool, failureType: String, protocolViolation: Bool, toolEvidence: String): String {
    "{\"runId\":\"unit\",\"benchmark\":\"Cangjie-HumanEval\",\"caseId\":\"${caseId}\",\"group\":\"${group}\",\"unitPassAt1\":${passAt1},\"failureType\":\"${failureType}\",\"protocolViolation\":${protocolViolation},\"toolEvidence\":\"${toolEvidence}\"}"
}

private func f8HasStep(report: CangjieKnowledgeReleaseGateReport, id: String, ok: Bool): Bool {
    for (step in report.steps) {
        if (step.id == id && step.ok == ok) {
            return true
        }
    }
    false
}

private func f8DiagnosticsContain(report: CangjieKnowledgeReleaseGateReport, needle: String): Bool {
    for (diagnostic in report.diagnostics) {
        if (diagnostic.contains(needle)) {
            return true
        }
    }
    false
}

private func f8EnsureDir(root: String): Unit {
    if (!exists(Path(root))) {
        Directory.create(Path(root), recursive: true)
    }
}

private func f8WriteFile(path: Path, text: String): Unit {
    if (!exists(path.parent)) {
        Directory.create(path.parent, recursive: true)
    }
    File.writeTo(path, text.toArray())
}
