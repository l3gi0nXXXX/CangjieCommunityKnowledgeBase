package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieEvalTest {
    @TestCase
    public func ckg6Ut001ParsesValidManifestLine(): Unit {
        let line = "{\"id\":\"CKG6-EVAL-001\",\"category\":\"compile\",\"targetVersion\":\"1.0.0\",\"prompt\":\"Create a hello world main function.\",\"entryPoint\":\"fixtures/compile-basic\",\"testCommand\":\"cjpm build -i\",\"expectedKnowledgeTags\":[\"main\",\"println\"]}"

        let parsed = parseCangjieEvalManifestLine(line)

        @Expect(parsed.ok, true)
        @Expect(parsed.status, "ok")
        @Expect(parsed.evalCase.id, "CKG6-EVAL-001")
        @Expect(parsed.evalCase.category, "compile")
        @Expect(parsed.evalCase.targetVersion, "1.0.0")
        @Expect(parsed.evalCase.testCommand, "cjpm build -i")
        @Expect(parsed.evalCase.expectedKnowledgeTags.size, 2)
    }

    @TestCase
    public func ckg6Bnd001MissingRequiredFieldsReturnBadRequest(): Unit {
        let missingId = "{\"category\":\"compile\",\"targetVersion\":\"1.0.0\",\"prompt\":\"Create a main function.\",\"entryPoint\":\"fixtures/compile-basic\",\"testCommand\":\"cjpm build -i\",\"expectedKnowledgeTags\":[\"main\"]}"
        let missingCommand = "{\"id\":\"CKG6-EVAL-BAD\",\"category\":\"compile\",\"targetVersion\":\"1.0.0\",\"prompt\":\"Create a main function.\",\"entryPoint\":\"fixtures/compile-basic\",\"expectedKnowledgeTags\":[\"main\"]}"

        let parsedMissingId = parseCangjieEvalManifestLine(missingId)
        let parsedMissingCommand = parseCangjieEvalManifestLine(missingCommand)

        @Expect(parsedMissingId.ok, false)
        @Expect(parsedMissingId.status, "bad_request")
        @Expect(parsedMissingCommand.ok, false)
        @Expect(parsedMissingCommand.status, "bad_request")
    }

    @TestCase
    public func ckg6Pos001SummaryReportsFourCategoriesWithZeroMetrics(): Unit {
        let cases = ArrayList<CangjieEvalCase>()
        cases.add(cangjieEvalCase("CKG6-EVAL-COMPILE", CangjieEvalCategories.COMPILE))
        cases.add(cangjieEvalCase("CKG6-EVAL-UNIT", CangjieEvalCategories.UNIT))
        cases.add(cangjieEvalCase("CKG6-EVAL-REPAIR", CangjieEvalCategories.REPAIR))
        cases.add(cangjieEvalCase("CKG6-EVAL-API", CangjieEvalCategories.API_HALLUCINATION))

        let summary = renderCangjieEvalSummary(cases)

        @Expect(summary.contains("compileCases=1"), true)
        @Expect(summary.contains("unitCases=1"), true)
        @Expect(summary.contains("repairCases=1"), true)
        @Expect(summary.contains("apiHallucinationCases=1"), true)
        @Expect(summary.contains("compilePassRate=0"), true)
        @Expect(summary.contains("unitPassRate=0"), true)
        @Expect(summary.contains("repairPassRate=0"), true)
        @Expect(summary.contains("apiHallucinationRate=0"), true)
    }

    @TestCase
    public func ckg6Neg001RejectsUserPathsAndTokenFields(): Unit {
        let withUserPath = "{\"id\":\"CKG6-EVAL-LEAK-PATH\",\"category\":\"compile\",\"targetVersion\":\"1.0.0\",\"prompt\":\"Use a local file.\",\"entryPoint\":\"/Users/example/private\",\"testCommand\":\"cjpm build -i\",\"expectedKnowledgeTags\":[\"path\"]}"
        let withToken = "{\"id\":\"CKG6-EVAL-LEAK-TOKEN\",\"category\":\"compile\",\"targetVersion\":\"1.0.0\",\"prompt\":\"Use a token.\",\"entryPoint\":\"fixtures/compile-basic\",\"testCommand\":\"cjpm build -i\",\"token\":\"example-token\",\"expectedKnowledgeTags\":[\"secret\"]}"

        let parsedPath = parseCangjieEvalManifestLine(withUserPath)
        let parsedToken = parseCangjieEvalManifestLine(withToken)

        @Expect(parsedPath.ok, false)
        @Expect(parsedPath.status, "invalid")
        @Expect(parsedPath.evalCase.id, "")
        @Expect(parsedToken.ok, false)
        @Expect(parsedToken.status, "invalid")
        @Expect(parsedToken.evalCase.id, "")
    }
}

private func cangjieEvalCase(id: String, category: String): CangjieEvalCase {
    let evalCase = CangjieEvalCase()
    evalCase.id = id
    evalCase.category = category
    evalCase.targetVersion = "1.0.0"
    evalCase.prompt = "offline prompt"
    evalCase.entryPoint = "fixtures/${id}"
    evalCase.testCommand = "cjpm test"
    evalCase
}
