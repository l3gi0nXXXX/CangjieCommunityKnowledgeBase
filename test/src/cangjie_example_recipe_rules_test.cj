package cangjie_community_knowledge_base_test

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieExampleRecipeRulesTest {
    @TestCase
    public func p3Ut002BuildsExampleFromCodeFence(): Unit {
        let record = cangjieP3ExampleRecord("r1", "ArrayList example", "```cangjie\nlet xs = ArrayList<Int64>()\nxs.add(1)\n```")

        let examples = buildExampleRecords(record)

        @Expect(examples.size, 1)
        @Expect(examples[0].code.contains("xs.add(1)"), true)
        @Expect(examples[0].citation, "test:r1")
    }

    @TestCase
    public func p3Neg001RecipeWithoutEvidenceIsRejected(): Unit {
        let gaps = ArrayList<String>()
        gaps.add("G-ARRAYLIST")

        let result = buildRecipeRuleRecords(gaps, ArrayList<NormalizedRecord>())

        @Expect(result.records.size, 0)
        @Expect(result.diagnostics.contains("recipe_evidence_missing"), true)
    }

    @TestCase
    public func p3Pos001RecipeWithTrustedEvidenceIsBuilt(): Unit {
        let gaps = ArrayList<String>()
        gaps.add("ArrayList")
        let evidence = ArrayList<NormalizedRecord>()
        evidence.add(cangjieP3ExampleRecord("r1", "ArrayList official docs", "ArrayList.add official docs"))

        let result = buildRecipeRuleRecords(gaps, evidence)

        @Expect(result.records.size, 1)
        @Expect(result.records[0].reviewed, true)
        @Expect(result.records[0].evidenceCitation, "test:r1")
    }
}

private func cangjieP3ExampleRecord(sourceId: String, title: String, chunk: String): NormalizedRecord {
    let record = NormalizedRecord()
    record.sourceId = sourceId
    record.title = title
    record.chunk = chunk
    record.citation = "test:${sourceId}"
    record.metadata.sourceId = sourceId
    record.metadata.sourceType = SourceTypes.DOC
    record.metadata.sourceSet = CangjieSourceSets.DOCS
    record.metadata.targetVersion = cangjieDefaultTargetVersion()
    record.metadata.versionResolutionId = "v1"
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.TRUSTED
    record
}
