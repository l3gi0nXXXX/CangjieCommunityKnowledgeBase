package cangjie_community_knowledge_base_test

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieKnowledgeLeakageGateTest {
    @TestCase
    public func r3Ut001AllStudentEntrypointsUseOneGate(): Unit {
        let record = r3LeakRecord("safe-source", "HumanEval case CJ-HUMANEVAL-145", "Knowledge: unsafe")
        let records = ArrayList<NormalizedRecord>()
        records.add(record)
        let diagnostic = cangjieStudentRecordDiagnostic(record)
        let feed = buildServingDocuments(records)
        let index = buildCangjieStudentServingIndex(records)
        let pack = CangjieTaskKnowledgePack()
        let evidence = CangjieMatchedEvidence()
        evidence.sourceId = record.sourceId
        evidence.title = record.title
        evidence.knowledge = record.chunk
        pack.matchedEvidence.add(evidence)
        let packDiagnostic = validateCangjieTaskKnowledgeEvidence(pack)

        @Expect(diagnostic.ok, false)
        @Expect(diagnostic.code, "student_knowledge_leakage_blocked")
        @Expect(feed.documents.size, 0)
        @Expect(index.documents.size, 0)
        @Expect(packDiagnostic.code, diagnostic.code)
    }

    @TestCase
    public func r3Bnd001EveryPublishableFieldRejectsMixedCaseUnicodeWithoutEcho(): Unit {
        for (field in ["title", "chunk", "citation", "sourceId", "path", "symbol", "derivedFrom"]) {
            let record = r3LeakRecord("safe-source", "safe title", "Knowledge: Rune-safe 中文🙂")
            let token = "前缀 cJ-hUmAnEvAl-145 后缀🙂"
            if (field == "title") { record.title = token }
            if (field == "chunk") { record.chunk = token }
            if (field == "citation") { record.citation = token }
            if (field == "sourceId") { record.sourceId = token; record.metadata.sourceId = token }
            if (field == "path") { record.metadata.path = token }
            if (field == "symbol") { record.metadata.symbol = token }
            if (field == "derivedFrom") { record.metadata.derivedFrom = [token] }
            let diagnostic = cangjieStudentRecordDiagnostic(record)
            @Expect(diagnostic.ok, false)
            @Expect(diagnostic.matchedField, field)
            @Expect(diagnostic.code.contains("CJ-HUMANEVAL"), false)
            @Expect(diagnostic.code.contains("中文"), false)
        }
        let oversized = r3LeakRecord("safe-source", "safe title", "Knowledge: ${r3Repeat("中文🙂", 5000)} CJ-HUMANEVAL-145")
        @Expect(cangjieStudentRecordDiagnostic(oversized).ok, false)

        let authorityRecords = ArrayList<NormalizedRecord>()
        authorityRecords.add(r3LeakRecord("authority-safe-id", "authority title", "Task: prefix\nVisible sample line unique中文🙂-abcdefghijklmnop\nTask: suffix"))
        let authority = buildCangjieBenchmarkLeakageAuthority(authorityRecords)
        let copiedFragment = r3LeakRecord("safe-source", "safe title", "Visible sample line unique中文🙂-abcdefghijklmnop")
        @Expect(cangjieStudentRecordDiagnostic(copiedFragment, authority: authority).ok, false)

        let compositePack = CangjieTaskKnowledgePack()
        let evidence = CangjieMatchedEvidence()
        evidence.title = "Task: calculate values"
        evidence.knowledge = "Visible tests: sample values"
        evidence.example = "Compiler output: success"
        compositePack.matchedEvidence.add(evidence)
        let compositeDiagnostic = validateCangjieTaskKnowledgeEvidence(compositePack)
        @Expect(compositeDiagnostic.ok, false)
        @Expect(compositeDiagnostic.code, "student_knowledge_leakage_blocked")
        @Expect(compositeDiagnostic.matchedField, "matchedEvidence")
    }

    @TestCase
    public func r3Pos001AnonymousRuneAtomRemainsStudentVisible(): Unit {
        let atom = r3AtomRecord("knowledge-atom-rune", "Knowledge: UTF-8 字节与 Rune 边界\nExample: utf8SafePrefix(text, 8) 🙂")
        let records = ArrayList<NormalizedRecord>()
        records.add(atom)
        let diagnostic = cangjieStudentRecordDiagnostic(atom)
        let index = buildCangjieStudentServingIndex(records)
        let request = CangjieServingSearchRequest()
        request.query = "UTF-8 字节 Rune 边界"
        request.sourceSet = CangjieSourceSets.KNOWLEDGE_ATOMS
        request.targetVersion = "1.0.0"
        request.budget = 3
        let result = searchHybridServingIndex(index, request)

        @Expect(diagnostic.ok, true)
        @Expect(result.hits.size > 0, true)
        @Expect(r3HitsContainSource(result, atom.sourceId), true)
    }

    @TestCase
    public func r3Neg001TaskIdentityDoesNotEnterKnowledgeSelection(): Unit {
        let resolution = resolveCangjieVersion(cangjieVersionSelector(targetVersion: "1.0.0", sourceSet: CangjieSourceSets.ALL), defaultCangjieVersionManifest())
        let first = CangjieTaskKnowledgeRequest()
        first.taskId = "CJ-HUMANEVAL-014"
        first.benchmark = "Cangjie-HumanEval"
        first.taskText = "UTF-8 字节与 Rune 边界"
        first.expectedKnowledgeTags.add("String")
        let second = CangjieTaskKnowledgeRequest()
        second.taskId = "CJ-HUMANEVAL-145"
        second.benchmark = "Other-Benchmark"
        second.taskText = first.taskText
        second.expectedKnowledgeTags.add("String")
        let firstPlan = buildCangjieTaskQueryPlan(first, resolution)
        let secondPlan = buildCangjieTaskQueryPlan(second, resolution)

        @Expect(r3QueryPlanSeed(firstPlan), r3QueryPlanSeed(secondPlan))
        @Expect(r3QueryPlanSeed(firstPlan).contains("benchmark_gap_lookup"), false)
        @Expect(r3QueryPlanSeed(firstPlan).contains("CJ-HUMANEVAL"), false)
    }

    @TestCase
    public func r3Arch001StudentGateSeparatesAuthorityCurationAndServingPlanes(): Unit {
        let authorityRecords = ArrayList<NormalizedRecord>()
        authorityRecords.add(r3LeakRecord("eval-support-CJ-HUMANEVAL-145-prompt", "HumanEval prompt", "Task: private benchmark prompt"))
        let authority = buildCangjieBenchmarkLeakageAuthority(authorityRecords)
        let curation = r3LeakRecord("curated-gap-private", "curation artifact", "Task: x\nVisible tests: y\nCompiler output: z")
        curation.metadata.sourceSet = CangjieSourceSets.EVAL_SUPPORT
        let student = r3AtomRecord("knowledge-atom-safe", "Knowledge: Rune iteration is Unicode-safe.")
        let records = ArrayList<NormalizedRecord>()
        records.add(curation)
        records.add(student)
        let internalIndex = buildCangjieServingIndex(records)
        let studentIndex = buildCangjieStudentServingIndex(records)

        @Expect(cangjieStudentRecordDiagnostic(curation, authority: authority).ok, false)
        @Expect(cangjieStudentRecordDiagnostic(student, authority: authority).ok, true)
        @Expect(r3IndexContainsSource(internalIndex, curation.sourceId), true)
        @Expect(r3IndexContainsSource(studentIndex, curation.sourceId), false)
        @Expect(r3IndexContainsSource(studentIndex, student.sourceId), true)
        @Expect(r3IndexDiagnosticContains(studentIndex, "eval_support_not_student_visible"), true)
        @Expect(r3IndexDiagnosticContains(studentIndex, curation.sourceId), false)
        let tools = ckbMcpToolNames()
        @Expect(tools.contains("cangjie_eval_authority_read"), false)
        @Expect(tools.contains("cangjie_curation_read"), false)
    }
}

private func r3LeakRecord(sourceId: String, title: String, chunk: String): NormalizedRecord {
    let record = NormalizedRecord()
    record.sourceId = sourceId
    record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    record.title = title
    record.chunk = chunk
    record.citation = "test:safe"
    record.metadata.sourceId = sourceId
    record.metadata.sourceType = SourceTypes.DERIVED
    record.metadata.sourceSet = CangjieSourceSets.DOCS
    record.metadata.path = "docs/safe.md"
    record.metadata.symbol = "Rune.safe"
    record.metadata.targetVersion = "1.0.0"
    record.metadata.versionResolutionId = "cangjie-1.0.0-docs-r3"
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.TRUSTED
    record
}

public func r3AtomRecord(sourceId: String, chunk: String): NormalizedRecord {
    let record = r3LeakRecord(sourceId, "Knowledge atom RUNE-SAFETY", chunk)
    record.recordKind = CangjieTypedRecordKinds.KNOWLEDGE_ATOM
    record.citation = "teacher-empirical://candidate/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    record.metadata.sourceSet = CangjieSourceSets.KNOWLEDGE_ATOMS
    record.metadata.path = "knowledge-atom/KC-01/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    record.metadata.symbol = "KI-02:RUNE-SAFETY"
    record.metadata.derivedFrom = ["knowledge-atom:RUNE-SAFETY"]
    record
}

private func r3QueryPlanSeed(plan: ArrayList<CangjieQueryPlanItem>): String {
    let out = StringBuilder()
    for (item in plan) {
        out.append("${item.queryKind}|${item.query}|${item.sourceSet}|${item.symbol}|${item.requiredTag}\n")
    }
    out.toString()
}

private func r3HitsContainSource(result: CangjieServingSearchResult, sourceId: String): Bool {
    for (hit in result.hits) { if (hit.document.sourceId == sourceId) { return true } }
    false
}

private func r3IndexContainsSource(index: CangjieServingIndex, sourceId: String): Bool {
    for (document in index.documents) { if (document.sourceId == sourceId) { return true } }
    false
}

private func r3IndexDiagnosticContains(index: CangjieServingIndex, token: String): Bool {
    for (diagnostic in index.diagnostics) { if (diagnostic.contains(token)) { return true } }
    false
}

private func r3Repeat(value: String, count: Int64): String {
    let out = StringBuilder()
    for (_ in 0..count) { out.append(value) }
    out.toString()
}
