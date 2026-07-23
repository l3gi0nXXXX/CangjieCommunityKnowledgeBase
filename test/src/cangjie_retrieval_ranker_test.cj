package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieRetrievalRankerTest {
    @TestCase
    public func p4Ut001ExactSymbolRanksAboveDocSection(): Unit {
        let docs = ArrayList<CangjieServingDocument>()
        docs.add(cangjieP4RankDoc(CangjieServingRecordKinds.DOC_SECTION, "ArrayList.add docs", "ArrayList.add docs", ""))
        docs.add(cangjieP4RankDoc(CangjieServingRecordKinds.SYMBOL_CARD, "ArrayList.add", "func add(value: T): Unit", "ArrayList.add"))

        let hits = rankServingHits("ArrayList.add", docs, 2)

        @Expect(hits.size, 2)
        @Expect(hits[0].document.recordKind, CangjieServingRecordKinds.SYMBOL_CARD)
        @Expect(hits[0].rankReason, "exact_symbol_or_symbol_card")
        @Expect(cangjieP4RankHasStage(hits[0], "exact_boost"), true)
        @Expect(cangjieP4RankHasStage(hits[0], "source_trust"), true)
        @Expect(cangjieP4RankHasStage(hits[0], "symbol_module_match"), true)
        @Expect(hits[0].score > hits[1].score, true)
    }

    @TestCase
    public func p4Ut002AliasAndModuleStagesRankBeforeBroadLexical(): Unit {
        let docs = ArrayList<CangjieServingDocument>()
        let aliasDoc = cangjieP4RankDoc(CangjieServingRecordKinds.SYMBOL_CARD, "ArrayList.add", "func add(value: T): Unit\naliases=pushValue", "ArrayList.add")
        aliasDoc.module = "std.collection"
        let broadDoc = cangjieP4RankDoc(CangjieServingRecordKinds.DOC_SECTION, "pushValue collection notes", "pushValue collection notes", "")
        docs.add(broadDoc)
        docs.add(aliasDoc)

        let hits = rankServingHits("std.collection pushValue", docs, 2)

        @Expect(hits.size, 2)
        @Expect(hits[0].document.symbolKey, "ArrayList.add")
        @Expect(cangjieP4RankHasStage(hits[0], "alias_match"), true)
        @Expect(cangjieP4RankHasStage(hits[0], "module_match"), true)
        @Expect(cangjieP4RankHasStage(hits[0], "recency"), true)
    }

    @TestCase
    public func p4Neg001RejectedDocumentsAreExcluded(): Unit {
        let docs = ArrayList<CangjieServingDocument>()
        let doc = cangjieP4RankDoc(CangjieServingRecordKinds.SYMBOL_CARD, "ArrayList.add", "func add(value: T): Unit", "ArrayList.add")
        doc.rejected = true
        docs.add(doc)

        let hits = rankServingHits("ArrayList.add", docs, 2)

        @Expect(hits.size, 0)
    }

    @TestCase
    public func f4RankStagesExposeNegativeRuleAndLexicalContributions(): Unit {
        let docs = ArrayList<CangjieServingDocument>()
        docs.add(cangjieP4RankDoc(CangjieServingRecordKinds.NEGATIVE_RULE, "Negative Cangjie rule: arraylist_add_not_append", "Bad: .append(...)\nUse: ArrayList.add(...)", ""))

        let hits = rankServingHits("ArrayList append", docs, 1)

        @Expect(hits.size, 1)
        @Expect(cangjieP4RankHasStage(hits[0], "negative_rule_relevance"), true)
        @Expect(cangjieP4RankHasStage(hits[0], "lexical_overlap"), true)
        @Expect(hits[0].score > 0.0, true)
    }

    @TestCase
    public func r7Neg002VerboseTaskDoesNotExactBoostShortSymbolSubstring(): Unit {
        let docs = ArrayList<CangjieServingDocument>()
        docs.add(cangjieP4RankDoc(CangjieServingRecordKinds.SYMBOL_CARD,
            "at", "public func at(n: Int64): Option<T>", "at"))

        let hits = rankServingHits("calculate a digest value at runtime", docs, 1)

        @Expect(hits.size, 1)
        @Expect(cangjieP4RankHasReason(hits[0], "exact_symbol_match"), false)
    }

    @TestCase
    public func r7Neg001IrrelevantKnowledgeAtomIsNotBoostedIntoResults(): Unit {
        let docs = ArrayList<CangjieServingDocument>()
        let atom = cangjieP4RankDoc(CangjieServingRecordKinds.DOC_SECTION,
            "Anonymous rune atom", "Rune scalar conversion", "")
        atom.sourceSet = CangjieSourceSets.KNOWLEDGE_ATOMS
        atom.rankProfile = CangjieTypedRecordKinds.KNOWLEDGE_ATOM
        atom.sourceId = "knowledge-atom-unrelated"
        docs.add(atom)

        let hits = rankServingHits("md5 digest", docs, 1)

        @Expect(hits.size, 0)
    }

    @TestCase
    public func r7Bnd001ExactSymbolUsesTokenBoundaryAndKeepsPunctuation(): Unit {
        let docs = ArrayList<CangjieServingDocument>()
        docs.add(cangjieP4RankDoc(CangjieServingRecordKinds.SYMBOL_CARD,
            "String", "public class String", "String"))
        docs.add(cangjieP4RankDoc(CangjieServingRecordKinds.SYMBOL_CARD,
            "ArrayList.add", "public func add(value: T): Unit", "ArrayList.add"))

        let substring = rankServingHits("substring helper", docs, 2)
        let punctuated = rankServingHits("call ArrayList.add(value)", docs, 2)

        @Expect(substring.size, 0)
        @Expect(cangjieP4RankHasReason(punctuated[0], "exact_symbol_match"), true)
        @Expect(punctuated[0].document.symbolKey, "ArrayList.add")
    }

    @TestCase
    public func r7Pos003KnowledgeAtomSpecificitySurvivesGrowingCorpusBudgets(): Unit {
        let docs = ArrayList<CangjieServingDocument>()
        for (i in 0..12) {
            let generic = cangjieP4RankDoc(CangjieServingRecordKinds.DOC_SECTION,
                "Generic atom ${i}", "String return Option helper common value", "")
            generic.sourceSet = CangjieSourceSets.KNOWLEDGE_ATOMS
            generic.sourceId = "knowledge-atom-generic-${i}"
            docs.add(generic)
        }
        let relevant = cangjieP4RankDoc(CangjieServingRecordKinds.DOC_SECTION,
            "Digest atom", "md5 digest UInt32 rotate hexadecimal", "")
        relevant.sourceSet = CangjieSourceSets.KNOWLEDGE_ATOMS
        relevant.sourceId = "knowledge-atom-relevant"
        docs.add(relevant)

        let budgetOne = rankKnowledgeAtomHits(
            "Implement md5 digest for String return Option", docs, 1)
        let budgetTen = rankKnowledgeAtomHits(
            "Implement md5 digest for String return Option", docs, 10)
        let budgetTwenty = rankKnowledgeAtomHits(
            "Implement md5 digest for String return Option", docs, 20)

        @Expect(budgetOne.size, 1)
        @Expect(budgetOne[0].document.sourceId, relevant.sourceId)
        @Expect(cangjieP4RankHasStage(budgetOne[0], "knowledge_atom_specificity"), true)
        @Expect(budgetTen.size, 10)
        @Expect(cangjieP4RankContainsSource(budgetTen, relevant.sourceId), true)
        @Expect(budgetTwenty.size, 13)
    }

    @TestCase
    public func r7Neg004RejectedKnowledgeAtomNeverEntersSpecificityRanking(): Unit {
        let docs = ArrayList<CangjieServingDocument>()
        let rejected = cangjieP4RankDoc(CangjieServingRecordKinds.DOC_SECTION,
            "Digest atom", "md5 digest", "")
        rejected.sourceSet = CangjieSourceSets.KNOWLEDGE_ATOMS
        rejected.sourceId = "knowledge-atom-rejected"
        rejected.rejected = true
        docs.add(rejected)

        let hits = rankKnowledgeAtomHits("md5 digest", docs, 10)

        @Expect(hits.size, 0)
    }
}

private func cangjieP4RankDoc(kind: String, title: String, text: String, symbol: String): CangjieServingDocument {
    let doc = CangjieServingDocument()
    doc.documentId = "doc-${title}"
    doc.recordKind = kind
    doc.title = title
    doc.text = text
    doc.symbolKey = symbol
    doc.trustLevel = TrustLevels.OFFICIAL
    doc.reviewState = ReviewStates.TRUSTED
    doc.targetVersion = cangjieDefaultTargetVersion()
    doc.versionResolutionId = "v1"
    doc.contentHash = stableSummaryHash("${title}:${text}:${symbol}")
    doc
}

private func cangjieP4RankHasStage(hit: CangjieRankedServingHit, stage: String): Bool {
    for (contribution in hit.contributions) {
        if (contribution.stage == stage && contribution.score != 0.0) {
            return true
        }
    }
    false
}

private func cangjieP4RankHasReason(hit: CangjieRankedServingHit, reason: String): Bool {
    for (contribution in hit.contributions) {
        if (contribution.reason == reason && contribution.score != 0.0) { return true }
    }
    false
}

private func cangjieP4RankContainsSource(hits: ArrayList<CangjieRankedServingHit>,
    sourceId: String): Bool {
    for (hit in hits) {
        if (hit.document.sourceId == sourceId) { return true }
    }
    false
}
