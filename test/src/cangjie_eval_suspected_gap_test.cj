package cangjie_community_knowledge_base_test

import std.fs.{Directory, File, Path, exists}
import std.process.launch
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieEvalSuspectedGapTest {
    @TestCase
    public func p5GapUt01StructuredRetrievalMustBindCurrentCase(): Unit {
        let context = "{\"taskId\":\"CJ-HUMANEVAL-011\",\"taskText\":\"中文😀\"}"
        let missing = p5StructuredToolResult("\"diagnostic\":\"missing_citation\",\"coverage\":{\"coveragePass\":false,\"missingCount\":1}")
        @Expect(ckbAbcdeHasBoundStructuredMissingEvidenceForTest("CJ-HUMANEVAL-011", context, missing), true)
        @Expect(ckbAbcdeHasBoundStructuredMissingEvidenceForTest("CJ-HUMANEVAL-012", context, missing), false)
        @Expect(ckbAbcdeHasBoundStructuredMissingEvidenceForTest("CJ-HUMANEVAL-011", "{\"taskId\":\"CJ-HUMANEVAL-011-other\"}", missing), false)
    }

    @TestCase
    public func p5GapPositive01CompileFailureWithBoundMissingEvidenceIsSuspectedOnly(): Unit {
        let root = p5GapRoot("positive")
        p5WriteGapArtifacts(root, "CJ-HUMANEVAL-011", p5StructuredToolResult("\"requiredKnowledge\":[{\"status\":\"missing\",\"reason\":\"evidence_missing\"}],\"coveragePass\":false"))
        let evidence = ckbAbcdeTriageEvidenceForTest(p5GapOptions(), "CJ-HUMANEVAL-011", 1, "compile_error", false, false, 0, 1, root)
        @Expect(evidence.contains("\"suspectedKnowledgeGap\":true"), true)
        @Expect(evidence.contains("\"retrievalDiagnostic\":\"structured_missing_evidence\""), true)
        @Expect(triageEvalFailure(evidence).category, "knowledge_gap")
        @Expect(evidence.contains("Authorization"), false)
        @Expect(evidence.contains("secret-token"), false)
    }

    @TestCase
    public func p5GapNegative01OperationalAndOrdinaryFailuresNeverBecomeSuspected(): Unit {
        let root = p5GapRoot("negative")
        p5WriteGapArtifacts(root, "CJ-HUMANEVAL-011", p5StructuredToolResult("\"diagnostic\":\"missing_citation\""))
        let options = p5GapOptions()
        for (entry in [
            ("test_failure", false, false, Int64(0), Int64(1)),
            ("tool_failure", false, false, Int64(0), Int64(1)),
            ("environment_failure", false, false, Int64(2), Int64(1)),
            ("compile_error", false, true, Int64(0), Int64(1)),
            ("none", true, false, Int64(0), Int64(0))
        ]) {
            let evidence = ckbAbcdeTriageEvidenceForTest(options, "CJ-HUMANEVAL-011", 1, entry[0], entry[1], entry[2], entry[3], entry[4], root)
            @Expect(evidence.contains("\"suspectedKnowledgeGap\":false"), true)
        }
    }

    @TestCase
    public func p5GapPositive02CoveragePassConflictingWithCompilerMemberFactIsSuspected(): Unit {
        let root = p5GapRoot("coverage-conflict")
        p5WriteGapArtifacts(root, "CJ-HUMANEVAL-016", p5StructuredToolResult("\"coverage\":{\"coveragePass\":true,\"missingCount\":0}"))
        File.writeTo(Path(root).join("test.log"), "error: 'toLower' is not a member of struct 'String'\nerror: 'put' is not a member of class 'HashSet<Rune>'\n".toArray())
        let evidence = ckbAbcdeTriageEvidenceForTest(p5GapOptions(), "CJ-HUMANEVAL-016", 1, "compile_error", false, false, 0, 1, root)
        @Expect(evidence.contains("\"suspectedKnowledgeGap\":true"), true)
        @Expect(evidence.contains("\"retrievalDiagnostic\":\"coverage_compiler_member_conflict\""), true)
        @Expect(triageEvalFailure(evidence).category, "knowledge_gap")
    }

    @TestCase
    public func p5GapNegative02CoveragePassWithSyntaxOrLogicFailureIsNotSuspected(): Unit {
        let root = p5GapRoot("coverage-no-conflict")
        p5WriteGapArtifacts(root, "CJ-HUMANEVAL-016", p5StructuredToolResult("\"coveragePass\":true"))
        for (failure in ["error: expected token ')'", "assertion failed: expected 1 actual 0"]) {
            File.writeTo(Path(root).join("test.log"), failure.toArray())
            let evidence = ckbAbcdeTriageEvidenceForTest(p5GapOptions(), "CJ-HUMANEVAL-016", 1, "compile_error", false, false, 0, 1, root)
            @Expect(evidence.contains("\"suspectedKnowledgeGap\":false"), true)
        }
    }

    @TestCase
    public func p5GapBoundary01MalformedEchoAndUnstructuredTextFailClosed(): Unit {
        let context = "{\"taskId\":\"CJ-HUMANEVAL-011\"}"
        let assistantEcho = "{\"type\":\"assistant\",\"message\":{\"text\":\"missing_citation 中文😀 secret-token\"}}"
        let malformed = "{\"type\":\"user\",\"type\":\"tool_result\",\"diagnostic\":\"missing_citation\""
        let ordinaryTool = p5StructuredToolResult("\"diagnostic\":\"ok\",\"coveragePass\":true")
        @Expect(ckbAbcdeHasBoundStructuredMissingEvidenceForTest("CJ-HUMANEVAL-011", context, assistantEcho), false)
        @Expect(ckbAbcdeHasBoundStructuredMissingEvidenceForTest("CJ-HUMANEVAL-011", context, malformed), false)
        @Expect(ckbAbcdeHasBoundStructuredMissingEvidenceForTest("CJ-HUMANEVAL-011", context, ordinaryTool), false)
    }

    @TestCase
    public func p5GapE2e01FirstAttemptArtifactDrivesClassifierEntryWithoutConfirmation(): Unit {
        let root = p5GapRoot("e2e")
        p5WriteGapArtifacts(root, "CJ-HUMANEVAL-011", p5StructuredToolResult("\"diagnostic\":\"missing_citation\",\"requiredKnowledge\":[{\"status\":\"missing\"}]"))
        let evidence = ckbAbcdeTriageEvidenceForTest(p5GapOptions(), "CJ-HUMANEVAL-011", 2, "compile_error", false, false, 0, 1, root)
        let triage = triageEvalFailure(evidence)
        @Expect(triage.ok, true)
        @Expect(triage.category, "knowledge_gap")
        @Expect(triage.route, "knowledge_gap")
        @Expect(evidence.contains("confirmed"), false)
    }
}

private func p5GapOptions(): CkbAbcdeRunnerOptions {
    let options = CkbAbcdeRunnerOptions()
    options.runId = "run-gap"
    options.datasetVersion = "dataset-v1"
    options.runMode = "development"
    options.explicitRunMode = true
    options
}

private func p5GapRoot(name: String): String {
    let root = "target/p5-suspected-gap-${name}"
    if (exists(Path(root))) { _ = launch("/bin/rm", ["-rf", root]).wait() }
    Directory.create(Path(root), recursive: true)
    root
}

private func p5WriteGapArtifacts(root: String, caseId: String, transcript: String): Unit {
    File.writeTo(Path(root).join("canonical-task-context.json"), "{\"taskId\":\"${caseId}\",\"taskText\":\"知识😀\"}".toArray())
    File.writeTo(Path(root).join("claude-transcript.attempt-1.jsonl"), (transcript + "\n").toArray())
}

private func p5StructuredToolResult(fields: String): String {
    "{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"tool_result\"}]},\"tool_use_result\":{\"structuredContent\":{${fields}}}}"
}
