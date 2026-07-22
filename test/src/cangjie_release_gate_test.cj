package cangjie_community_knowledge_base_test

import std.fs.{Directory, File, Path, exists}
import std.collection.ArrayList
import std.process.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieReleaseGateTest {
    @TestCase
    public func tR4NegRoutineAcceptanceRejectsMissingOrNonZeroTrustProof(): Unit {
        let cleanLeakage = "{\"ok\":true,\"leakageCount\":0}\n"
        let cleanQueries = "{\"ok\":true,\"indexBuildCount\":1,\"failed\":0}\n"
        @Expect(cangjieRoutineTrustProofDiagnostic(cleanLeakage, cleanQueries), "ok")
        @Expect(cangjieRoutineTrustProofDiagnostic("{\"ok\":false,\"leakageCount\":1}", cleanQueries),
            "candidate_leakage_proof_required")
        @Expect(cangjieRoutineTrustProofDiagnostic(cleanLeakage,
            "{\"ok\":false,\"indexBuildCount\":1,\"failed\":1}"), "anonymous_query_proof_required")
        @Expect(cangjieRoutineTrustProofDiagnostic(cleanLeakage, ""), "anonymous_query_proof_required")
        let forgedLeakage = "{\"ok\":false,\"leakageCount\":1,\"message\":\"\\\"ok\\\":true \\\"leakageCount\\\":0\"}"
        let forgedQuery = "{\"ok\":false,\"indexBuildCount\":0,\"failed\":1,\"message\":\"\\\"ok\\\":true \\\"indexBuildCount\\\":1 \\\"failed\\\":0\"}"
        @Expect(cangjieRoutineTrustProofDiagnostic(forgedLeakage, cleanQueries),
            "candidate_leakage_proof_required")
        @Expect(cangjieRoutineTrustProofDiagnostic(cleanLeakage, forgedQuery),
            "anonymous_query_proof_required")
        let duplicateLeakage = "{\"ok\":false,\"ok\":true,\"leakageCount\":1,\"leakageCount\":0}"
        let duplicateQuery = "{\"ok\":false,\"ok\":true,\"indexBuildCount\":0,\"indexBuildCount\":1,\"failed\":1,\"failed\":0}"
        @Expect(cangjieRoutineTrustProofDiagnostic(duplicateLeakage, cleanQueries),
            "candidate_leakage_proof_required")
        @Expect(cangjieRoutineTrustProofDiagnostic(cleanLeakage, duplicateQuery),
            "anonymous_query_proof_required")
        let duplicateAuthority = "{\"ok\":false,\"ok\":true,\"authorityCount\":0,\"authorityCount\":164,\"authorityHash\":\"${benchmarkGapSha256("authority")}\",\"activeEvalCount\":1,\"activeEvalCount\":0}"
        let duplicateAtom = "{\"ok\":false,\"ok\":true,\"diagnostic\":\"failed\"}"
        let cleanAuthority = "{\"ok\":true,\"authorityCount\":164,\"authorityHash\":\"${benchmarkGapSha256("authority")}\",\"activeEvalCount\":0}"
        let cleanAtom = "{\"ok\":true,\"diagnostic\":\"validated\"}"
        @Expect(cangjieCandidateOnlyPreCertificationGate(ArrayList<NormalizedRecord>(), cleanLeakage,
            cleanQueries, duplicateAuthority, cleanAtom).diagnostic, "authority_isolation_proof_required")
        @Expect(cangjieCandidateOnlyPreCertificationGate(ArrayList<NormalizedRecord>(), cleanLeakage,
            cleanQueries, cleanAuthority, duplicateAtom).diagnostic, "atom_test_proof_required")
    }

    @TestCase
    public func f8Ut001ReleaseGateFakeAllPass(): Unit {
        let fixture = f8WriteFirstInitFixture("target/f8-ut-fixture", true)
        let runRoot = "target/f8-ut-run"
        f8WritePass1Files(runRoot, true)
        f8EnsureEmptyDir("target/f8-ut-store")
        let options = f8ReleaseGateOptions(runRoot, fixture)
        options.schedulerTaskNames.add("cangjie_docs_full_weekly")
        let store = FileKnowledgeStore("target/f8-ut-store")

        let report = cangjieKnowledgeReleaseGate(options, f8ReleaseGateRuntimeConfig(), store, sourceRunner: F9ReleaseGateFreshRunner())
        let json = renderCangjieKnowledgeReleaseGateJson(report)

        @Expect(report.ok, true)
        @Expect(report.releaseGate, "pass")
        @Expect(json.contains("\"releaseGate\":\"pass\""), true)
        @Expect(f8HasStep(report, "E2E-01-first-init", true), true)
        @Expect(f8HasStep(report, "E2E-02-route-probe", true), true)
        @Expect(f8HasStep(report, "E2E-03-scheduler-forced-run", true), true)
        @Expect(f8HasStep(report, "E2E-07-routine-update-full-run", true), true)
        @Expect(f8HasStep(report, "E2E-04-transport-parity", true), true)
        @Expect(f8HasStep(report, "E2E-05-pass1-gate", true), true)
        @Expect(f8HasStep(report, "P0A-routine-runtime-readiness", true), true)
        @Expect(f8HasStep(report, "E2E-08-routine-update-due-run", true), true)
        @Expect(f8HasStep(report, "E2E-10-access-and-mcp-readonly-boundary", true), true)
        @Expect(f8HasStep(report, "E2E-11-scheduler-loop-lifecycle", true), true)
        @Expect(f8HasStep(report, "E2E-12-interface-e2e", true), true)
        @Expect(f8HasStep(report, "E2E-13-source-event-e2e", true), true)
        @Expect(f8HasStep(report, "E2E-14-plan-closure", true), true)
        @Expect(exists(Path("${runRoot}/release-gate.json")), true)
        @Expect(exists(Path("${runRoot}/release-gate-steps.jsonl")), true)
        @Expect(exists(Path("${runRoot}/route-probe.jsonl")), true)
        @Expect(String.fromUtf8(File.readFrom(Path("${runRoot}/route-probe.jsonl"))).contains("\"evidenceHash\""), true)
        @Expect(exists(Path("${runRoot}/scheduler-forced-run.jsonl")), true)
        @Expect(exists(Path("${runRoot}/routine-update-full-run.jsonl")), true)
        @Expect(exists(Path("${runRoot}/routine-update-task-matrix.jsonl")), true)
        @Expect(exists(Path("${runRoot}/transport-parity.jsonl")), true)
        @Expect(exists(Path("${runRoot}/transport-parity-rest.json")), true)
        @Expect(exists(Path("${runRoot}/transport-parity-stdio.json")), true)
        @Expect(exists(Path("${runRoot}/transport-parity-http.json")), true)
        @Expect(exists(Path("${runRoot}/pass1-gate.json")), true)
        @Expect(exists(Path("${runRoot}/routine-update-runtime-readiness.jsonl")), true)
        @Expect(exists(Path("${runRoot}/routine-update-due-run.jsonl")), true)
        @Expect(exists(Path("${runRoot}/routine-update-access-boundary.jsonl")), true)
        @Expect(exists(Path("${runRoot}/routine-update-mcp-readonly-boundary.jsonl")), true)
        @Expect(exists(Path("${runRoot}/routine-update-scheduler-loop-lifecycle.jsonl")), true)
        @Expect(exists(Path("${runRoot}/routine-update-interface-e2e.jsonl")), true)
        @Expect(exists(Path("${runRoot}/routine-update-source-event-e2e.jsonl")), true)
        let sourceEventE2e = String.fromUtf8(File.readFrom(Path("${runRoot}/routine-update-source-event-e2e.jsonl")))
        @Expect(sourceEventE2e.contains("\"repositoryChangedEventStatus\":202"), true)
        @Expect(sourceEventE2e.contains("\"duplicateEventStatus\":200"), true)
        @Expect(sourceEventE2e.contains("\"duplicateEventDeduped\":true"), true)
        @Expect(sourceEventE2e.contains("\"repositoryInboxQueued\":true"), true)
        @Expect(sourceEventE2e.contains("\"ingressDidNotSynchronize\":true"), true)
        @Expect(sourceEventE2e.contains("\"workerConsumed\":true"), true)
        @Expect(exists(Path("${runRoot}/routine-update-plan-closure.jsonl")), true)
        @Expect(String.fromUtf8(File.readFrom(Path("${runRoot}/routine-update-plan-closure.jsonl"))).contains("\"status\":\"passed\""), true)
        @Expect(String.fromUtf8(File.readFrom(Path("${runRoot}/routine-update-due-run.jsonl"))).contains("candidate_validated_promoted"), true)
        @Expect(String.fromUtf8(File.readFrom(Path("${runRoot}/routine-update-active-invariant.jsonl"))).contains("\"activeInvariantPreserved\":true"), true)
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
        f8EnsureEmptyDir("target/f8-pos-store")
        let store = FileKnowledgeStore("target/f8-pos-store")

        let exitCode = runCangjieKnowledgeReleaseGate(f8ReleaseGateArgs(runRoot, fixture), config: f8ReleaseGateRuntimeConfig(), store: store, sourceRunner: F9ReleaseGateFreshRunner())

        @Expect(exitCode, 0)
        @Expect(exists(Path("${runRoot}/release-gate.md")), true)
        @Expect(String.fromUtf8(File.readFrom(Path("${runRoot}/release-gate.json"))).contains("\"releaseGate\":\"pass\""), true)
        @Expect(store.has("index/active.ckb"), true)
        @Expect(String.fromUtf8(File.readFrom(Path("${runRoot}/routine-update-due-run.jsonl"))).contains("candidate_validated_promoted"), true)
    }

    @TestCase
    public func f8Neg001Pass1MismatchFailsWholeReleaseGate(): Unit {
        let fixture = f8WriteFirstInitFixture("target/f8-neg-fixture", true)
        let runRoot = "target/f8-neg-run"
        f8WritePass1Files(runRoot, false)
        f8EnsureEmptyDir("target/f8-neg-store")
        let options = f8ReleaseGateOptions(runRoot, fixture)
        options.schedulerTaskNames.add("cangjie_docs_full_weekly")

        let report = cangjieKnowledgeReleaseGate(options, f8ReleaseGateRuntimeConfig(), FileKnowledgeStore("target/f8-neg-store"), sourceRunner: F9ReleaseGateFreshRunner())

        @Expect(report.ok, false)
        @Expect(report.releaseGate, "fail")
        @Expect(f8HasStep(report, "E2E-05-pass1-gate", false), true)
        @Expect(f8DiagnosticsContain(report, "E2E-05-pass1-gate"), true)
        @Expect(exists(Path("${runRoot}/gap-curation-input.jsonl")), true)
    }

    @TestCase
    public func p9Pos001ReleaseGateDefaultSchedulerRunsAllRoutineTasks(): Unit {
        let fixture = f8WriteFirstInitFixture("target/p9-default-fixture", true)
        let runRoot = "target/p9-default-run"
        f8WritePass1Files(runRoot, true)
        f8EnsureEmptyDir("target/p9-default-store")
        let options = f8ReleaseGateOptions(runRoot, fixture)
        let store = FileKnowledgeStore("target/p9-default-store")

        let report = cangjieKnowledgeReleaseGate(options, f8ReleaseGateRuntimeConfig(), store, sourceRunner: F9ReleaseGateFreshRunner())
        let scheduler = String.fromUtf8(File.readFrom(Path("${runRoot}/routine-update-task-results.jsonl")))
        let dueRun = String.fromUtf8(File.readFrom(Path("${runRoot}/routine-update-due-run.jsonl")))
        let acceptance = String.fromUtf8(File.readFrom(Path("${runRoot}/routine-update-acceptance-matrix.jsonl")))

        @Expect(report.ok, true)
        @Expect(f8HasStep(report, "P7-routine-update-contract", true), true)
        @Expect(f8HasStep(report, "E2E-08-routine-update-due-run", true), true)
        @Expect(f8HasStep(report, "E2E-07-routine-update-full-run", true), true)
        @Expect(f8HasStep(report, "P9-routine-update-rollback", true), true)
        @Expect(f8HasStep(report, "P9-routine-update-acceptance", true), true)
        @Expect(f8HasStep(report, "E2E-14-plan-closure", true), true)
        @Expect(exists(Path("${runRoot}/routine-update-contract.jsonl")), true)
        @Expect(exists(Path("${runRoot}/routine-update-task-results.jsonl")), true)
        @Expect(exists(Path("${runRoot}/routine-update-full-run.jsonl")), true)
        @Expect(exists(Path("${runRoot}/routine-update-task-matrix.jsonl")), true)
        @Expect(exists(Path("${runRoot}/routine-update-active-invariant.jsonl")), true)
        @Expect(exists(Path("${runRoot}/routine-update-rollback.jsonl")), true)
        @Expect(exists(Path("${runRoot}/routine-update-plan-closure.jsonl")), true)
        @Expect(scheduler.contains("\"ran\":13"), true)
        @Expect(scheduler.contains("routine_contract"), true)
        @Expect(dueRun.contains("\"failed\":0"), true)
        @Expect(dueRun.contains("candidate_validated_promoted"), true)
        @Expect(acceptance.contains("\"status\":\"failed\""), false)
    }

    @TestCase
    public func p0GateRoutineLiveShapeMetadata400TreeOkEvalLocalPasses(): Unit {
        let fixture = f8WriteFirstInitFixture("target/p0-live-shape-fixture", true)
        let runRoot = "target/p0-live-shape-run"
        f8WritePass1Files(runRoot, true)
        f8EnsureEmptyDir("target/p0-live-shape-store")
        let options = f8ReleaseGateOptions(runRoot, fixture)
        let store = FileKnowledgeStore("target/p0-live-shape-store")

        let report = cangjieKnowledgeReleaseGate(options, f8ReleaseGateRuntimeConfig(), store, sourceRunner: F9ReleaseGateFreshRunner())
        let scheduler = String.fromUtf8(File.readFrom(Path("${runRoot}/routine-update-task-results.jsonl")))
        let dueRun = String.fromUtf8(File.readFrom(Path("${runRoot}/routine-update-due-run.jsonl")))

        @Expect(report.ok, true)
        @Expect(f8HasStep(report, "E2E-07-routine-update-full-run", true), true)
        @Expect(scheduler.contains("\"ran\":13"), true)
        @Expect(scheduler.contains("kind=gitcode_tree"), true)
        @Expect(scheduler.contains("kind=gitcode_repo"), false)
        @Expect(dueRun.contains("\"failed\":0"), true)
        @Expect(dueRun.contains("candidate_validated_promoted"), true)
    }

    @TestCase
    public func p3Neg01ReleaseGateRejectsInvalidAtomBundle(): Unit {
        let fixture = f8WriteFirstInitFixture("target/p3-atom-gate-fixture", true)
        let runRoot = "target/p3-atom-gate-run"
        f8WritePass1Files(runRoot, true)
        f8WriteFile(Path("${runRoot}/knowledge-atoms.jsonl"), p3Rehash(p3ValidBundle().replace(",${p3BoundaryTest()}", "")) + "\n")
        f8EnsureEmptyDir("target/p3-atom-gate-store")
        let report = cangjieKnowledgeReleaseGate(f8ReleaseGateOptions(runRoot, fixture), f8ReleaseGateRuntimeConfig(), FileKnowledgeStore("target/p3-atom-gate-store"), sourceRunner: F9ReleaseGateFreshRunner())

        @Expect(report.ok, false)
        @Expect(f8HasStep(report, "P3-knowledge-atom-tests", false), true)
        @Expect(f8DiagnosticsContain(report, "missing_atom_test_category"), true)
    }

    @TestCase
    public func p3Bnd01ReleaseGateRequiresArtifactForDeclaredCandidate(): Unit {
        let fixture = f8WriteFirstInitFixture("target/p3-atom-missing-fixture", true)
        let runRoot = "target/p3-atom-missing-run"
        f8WritePass1Files(runRoot, true)
        f8WriteFile(Path("${runRoot}/gap-curation-input.jsonl"), p3CandidateCuration(p3ValidBundle()))
        f8EnsureEmptyDir("target/p3-atom-missing-store")
        let report = cangjieKnowledgeReleaseGate(f8ReleaseGateOptions(runRoot, fixture), f8ReleaseGateRuntimeConfig(), FileKnowledgeStore("target/p3-atom-missing-store"), sourceRunner: F9ReleaseGateFreshRunner())

        @Expect(report.ok, false)
        @Expect(f8HasStep(report, "P3-knowledge-atom-tests", false), true)
        @Expect(f8DiagnosticsContain(report, "knowledge_atom_artifact_required"), true)
    }

    @TestCase
    public func p3Neg02ReleaseGateRejectsMalformedAndMismatchedCandidateSets(): Unit {
        let one = p3ValidBundle()
        let two = p3Rehash(one.replace("G-ARRAYLIST-RUNE", "G-ARRAYLIST-RUNE-SECOND"))
        let malformed = p3AtomGateReport("malformed", "{\n", "")
        let falseType = p3AtomGateReport("false-type", "{\"knowledgeAtomCandidate\":\"true\"}\n", "")
        let duplicateDeclared = p3AtomGateReport("dup-declared", p3CandidateCuration(one) + p3CandidateCuration(one), one + "\n")
        let missing = p3AtomGateReport("missing", p3CandidateCuration(one) + p3CandidateCuration(two), one + "\n")
        let extra = p3AtomGateReport("extra", p3CandidateCuration(one), one + "\n" + two + "\n")
        let mismatch = p3AtomGateReport("mismatch", p3CandidateCuration(one), two + "\n")
        let duplicateActual = p3AtomGateReport("dup-actual", p3CandidateCuration(one), one + "\n" + one + "\n")

        @Expect(f8DiagnosticsContain(malformed, "malformed_gap_curation_input"), true)
        @Expect(f8DiagnosticsContain(falseType, "malformed_gap_curation_input"), true)
        @Expect(f8DiagnosticsContain(duplicateDeclared, "duplicate_declared_knowledge_atom"), true)
        @Expect(f8DiagnosticsContain(missing, "knowledge_atom_set_mismatch"), true)
        @Expect(f8DiagnosticsContain(extra, "knowledge_atom_set_mismatch"), true)
        @Expect(f8DiagnosticsContain(mismatch, "knowledge_atom_set_mismatch"), true)
        @Expect(f8DiagnosticsContain(duplicateActual, "duplicate_knowledge_atom"), true)
    }

    @TestCase
    public func p3Pos01ReleaseGateAcceptsExactDeclaredAtomSet(): Unit {
        let atom = p3ValidBundle()
        let report = p3AtomGateReport("exact-set", p3CandidateCuration(atom), atom + "\n")
        @Expect(f8HasStep(report, "P3-knowledge-atom-tests", true), true)
        @Expect(f8DiagnosticsContain(report, "knowledge_atom_set_mismatch"), false)
    }
}

private func p3AtomGateReport(name:String,curation:String,atoms:String):CangjieKnowledgeReleaseGateReport{let fixture=f8WriteFirstInitFixture("target/p3-atom-${name}-fixture",true);let runRoot="target/p3-atom-${name}-run";f8WritePass1Files(runRoot,true);f8WriteFile(Path("${runRoot}/gap-curation-input.jsonl"),curation);if(atoms!=""){f8WriteFile(Path("${runRoot}/knowledge-atoms.jsonl"),atoms)};f8EnsureEmptyDir("target/p3-atom-${name}-store");cangjieKnowledgeReleaseGate(f8ReleaseGateOptions(runRoot,fixture),f8ReleaseGateRuntimeConfig(),FileKnowledgeStore("target/p3-atom-${name}-store"),sourceRunner:F9ReleaseGateFreshRunner())}

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

private func f8ReleaseGateRuntimeConfig(): CkbRuntimeConfig {
    let config = CkbRuntimeConfig()
    config.networkEnabled = true
    config.networkAllowedHosts = "gitcode.com,docs.cangjie-lang.cn,cangjie-lang.cn"
    config.timeoutMillis = 10000
    config.retryCount = 1
    config
}

private func f8WritePass1Files(runRoot: String, pass: Bool): Unit {
    f8EnsureEmptyDir(runRoot)
    f8WriteFile(Path("${runRoot}/manifest.jsonl"), f8ManifestLine("CJ-HUMANEVAL-000", "Implement ArrayList helper.", "[\"ArrayList\",\"Cangjie syntax\"]") + "\n")
    let dPass = pass
    let results = f8ResultLine("CJ-HUMANEVAL-000", CangjieHumanEvalPass1GateGroups.C, true, "none", false, "cangjie_task_knowledge_pack") + "\n" +
        f8ResultLine("CJ-HUMANEVAL-000", CangjieHumanEvalPass1GateGroups.D, dPass, if (dPass) { "none" } else { "compile_error" }, false, "cangjie_task_knowledge_pack") + "\n"
    f8WriteFile(Path("${runRoot}/results.jsonl"), results)
}

private func f8WriteFirstInitFixture(root: String, includeTool: Bool): F8FirstInitFixturePaths {
    f8EnsureEmptyDir(root)
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
    f8WriteGitMetadata(fixture.docsRoot, "f8-docs-commit")
    f8WriteGitMetadata(fixture.stdRoot, "f8-std-commit")
    f8WriteGitMetadata(fixture.stdxRoot, "f8-stdx-commit")
    f8WriteGitMetadata(fixture.evalRoot, "f8-eval-commit")
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

private func f8EnsureEmptyDir(root: String): Unit {
    if (exists(Path(root))) {
        _ = launch("/bin/rm", ["-rf", root]).wait()
    }
    f8EnsureDir(root)
}

private func f8WriteFile(path: Path, text: String): Unit {
    if (!exists(path.parent)) {
        Directory.create(path.parent, recursive: true)
    }
    File.writeTo(path, text.toArray())
}

private func f8WriteGitMetadata(root: String, commit: String): Unit {
    f8WriteFile(Path(root).join(".git/HEAD"), "ref: refs/heads/release-1.0.0\n")
    f8WriteFile(Path(root).join(".git/refs/heads/release-1.0.0"), commit)
}

private class F9ReleaseGateFreshRunner <: SourceFetchRunner {
    init() {}

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        let result = SourceFetchResult()
        result.sourceUrl = request.url
        result.repo = request.repo
        result.ref = request.ref
        result.path = request.path
        result.normalizedType = request.kind
        if (request.kind == SourceKinds.GITCODE_REPO) {
            result.ok = false
            result.status = "http_400"
            result.statusCode = 400
            result.body = "Invalid header parameter: private-token, required"
            result.bodyHash = stableSummaryHash(result.body)
            result.bytes = result.body.size
            return result
        }
        result.ok = true
        result.status = "ok"
        result.statusCode = 200
        result.commit = this.expectedCommit(request)
        result.lastModified = "2026-07-07T00:00:00Z"
        result.body = this.bodyFor(request)
        result.bodyHash = stableSummaryHash(result.body)
        result.contentType = if (request.accept == "text/html") { "text/html" } else if (request.kind == SourceKinds.GITCODE_SOURCE && request.sourceVariant == "raw") { "text/plain" } else { "application/json" }
        result.bytes = result.body.size
        result
    }

    private func bodyFor(request: SourceFetchRequest): String {
        if (request.kind == SourceKinds.GITCODE_BRANCH && request.purpose == "branch_ref") {
            return "{\"name\":\"${request.ref}\",\"commit\":{\"id\":\"${this.resolvedCommitForBranch(request)}\",\"sha\":\"${this.resolvedCommitForBranch(request)}\"}}"
        }
        if (request.kind == SourceKinds.GITCODE_BRANCH) {
            let commit = this.resolvedCommitForBranch(request)
            return "[{\"name\":\"main\",\"commit\":{\"id\":\"${commit}\",\"sha\":\"${commit}\"}},{\"name\":\"release-1.0.0\",\"commit\":{\"id\":\"${commit}\",\"sha\":\"${commit}\"}},{\"name\":\"release/1.0\",\"commit\":{\"id\":\"${commit}\",\"sha\":\"${commit}\"}}]"
        }
        if (request.kind == SourceKinds.GITCODE_TREE) {
            if (request.page > 1) {
                return "{\"tree\":[],\"sha\":\"${this.expectedCommit(request)}\"}"
            }
            return "{\"tree\":[{\"path\":\"src/release_gate_fixture.cj\",\"type\":\"blob\"},{\"path\":\"README.md\",\"type\":\"blob\"}],\"sha\":\"${this.expectedCommit(request)}\"}"
        }
        if (request.kind == SourceKinds.GITCODE_SOURCE && request.path.endsWith(".cj")) {
            return "package releasegate\npublic func releaseGateFixture(): Unit {}\n"
        }
        if (request.kind == SourceKinds.GITCODE_SOURCE) {
            return "# Release gate source\nArrayList.add HashMap String.contains cjpm test Cangjie docs tutorial\n"
        }
        "fake ${request.kind} ${request.repo} ${request.path} ArrayList.add HashMap String.contains cjpm test Cangjie docs tutorial"
    }

    private func resolvedCommitForBranch(request: SourceFetchRequest): String {
        let repo = request.repo.toAsciiLower()
        if (repo == "cangjie/cangjie_runtime") {
            return "1111111111111111111111111111111111111111"
        }
        if (repo == "cangjie/cangjie_stdx") {
            return "2222222222222222222222222222222222222222"
        }
        if (repo == "cangjie/cangjie_tools") {
            return "3333333333333333333333333333333333333333"
        }
        if (repo == "cangjiecommunityknowledgebase/cangjie-humaneval") {
            return "4444444444444444444444444444444444444444"
        }
        "0000000000000000000000000000000000000000"
    }

    private func expectedCommit(request: SourceFetchRequest): String {
        let repo = request.repo.toAsciiLower()
        if (request.kind == SourceKinds.CANGJIE_DOCS) {
            return "0000000000000000000000000000000000000000"
        }
        if (repo == "cangjie/cangjie_docs") {
            return "0000000000000000000000000000000000000000"
        }
        if (repo == "cangjie/cangjie_tools") {
            return "3333333333333333333333333333333333333333"
        }
        if (repo == "cangjie/cangjie_runtime") {
            return "1111111111111111111111111111111111111111"
        }
        if (repo == "cangjie/cangjie_stdx") {
            return "2222222222222222222222222222222222222222"
        }
        if (repo == "cangjiecommunityknowledgebase/cangjie-humaneval") {
            return "4444444444444444444444444444444444444444"
        }
        "0000000000000000000000000000000000000000"
    }
}
