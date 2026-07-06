package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.*

@Test
public class CangjieCapabilityContractTest {
    private func service(name: String): CkbCommandLoopService {
        CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/${name}"))
    }

    private func request(): CangjieTaskKnowledgeRequest {
        let req = CangjieTaskKnowledgeRequest()
        req.taskId = "CJ-HUMANEVAL-000"
        req.benchmark = "Cangjie-HumanEval"
        req.taskText = "Implement an ArrayList helper."
        req.signature = "func solve(xs: ArrayList<Int64>): Int64"
        req.imports.add("std.collection.ArrayList")
        req.expectedKnowledgeTags.add("ArrayList")
        req.expectedKnowledgeTags.add("symbol")
        req.versionSelector = cangjieVersionSelector(targetVersion: "1.0.0", sourceSet: "stdx", sourceRef: "release-1.0.0", versionPolicy: "exact")
        req
    }

    @TestCase
    public func p1Pos001TaskKnowledgePackIncludesVersionPlanAndCoverage(): Unit {
        let pack = this.service("p1-pos-001").cangjieTaskKnowledgePack(this.request())

        @Expect(pack.versionResolution.ok, true)
        @Expect(pack.versionResolution.versionPolicy, "exact")
        @Expect(pack.queryPlan.size > 0, true)
        @Expect(pack.coverage.requiredCount, 2)
        @Expect(pack.coverage.missingCount, 0)
        @Expect(pack.coverage.coveragePass, true)
        @Expect(pack.notes.contains("task_knowledge_contract_skeleton"), true)
    }

    @TestCase
    public func p1Neg001EmptyTaskAndSignatureIsRejectedByValidator(): Unit {
        let req = CangjieTaskKnowledgeRequest()

        @Expect(validateCangjieTaskKnowledgeRequest(req), "task_or_signature_required")
    }

    @TestCase
    public func p1Neg002MissingExactRefDegradesTaskPack(): Unit {
        let req = this.request()
        req.versionSelector = cangjieVersionSelector(targetVersion: "1.0.0", sourceSet: "stdx", sourceRef: "missing-release", versionPolicy: "exact")
        let pack = this.service("p1-neg-002").cangjieTaskKnowledgePack(req)

        @Expect(pack.versionResolution.ok, false)
        @Expect(pack.versionResolution.diagnostic, "exact_source_ref_not_resolved")
        @Expect(pack.degraded, true)
        @Expect(pack.coverage.coveragePass, false)
        @Expect(pack.diagnostics.contains("exact_source_ref_not_resolved"), true)
    }

    @TestCase
    public func p1Bnd001OversizedStarterCodeIsTruncatedDiagnosticOnly(): Unit {
        let req = this.request()
        var text = ""
        for (_ in 0..(CangjieCapabilityLimits.MAX_TEXT_CHARS + 8)) {
            text += "x"
        }
        req.starterCodeExcerpt = text
        let pack = this.service("p1-bnd-001").cangjieTaskKnowledgePack(req)

        @Expect(pack.truncated, true)
        @Expect(pack.diagnostics.contains("starter_code_excerpt_truncated"), true)
        @Expect(pack.versionResolution.ok, true)
    }

    @TestCase
    public func p1Pos002LegacyKnowledgePackStillCallableButMarkedDegraded(): Unit {
        let pack = this.service("p1-pos-002").cangjieKnowledgePack("ArrayList usage", targetVersion: "1.0.0", budget: 1)

        @Expect(pack.queryId.startsWith("cangjie-"), true)
        @Expect(pack.notes.contains("legacy_endpoint_degraded"), true)
        @Expect(pack.degraded, true)
    }

    @TestCase
    public func p6Ut001ExactSymbolHelperReturnsHitAndExactMiss(): Unit {
        let kb = p6ExactLookupKnowledgeBase()

        let hit = cangjieExactSymbolLookup(kb, "ArrayList.add", sourceSet: CangjieSourceSets.STD, targetVersion: "1.0.0")
        let miss = cangjieExactSymbolLookup(kb, "ArrayList.removeAll", sourceSet: CangjieSourceSets.STD, targetVersion: "1.0.0")

        @Expect(hit.degraded, false)
        @Expect(hit.records.size, 1)
        @Expect(hit.records[0].metadata.symbol, "ArrayList.add")
        @Expect(miss.degraded, true)
        @Expect(miss.records.size, 0)
        @Expect(miss.fallbackReason, "exact_miss")
    }

    @TestCase
    public func p6Bnd001ExactSymbolDoesNotCrossTargetVersionOrSourceSet(): Unit {
        let kb = p6ExactLookupKnowledgeBase()

        let std10 = cangjieExactSymbolLookup(kb, "ArrayList.add", sourceSet: CangjieSourceSets.STD, targetVersion: "1.0.0")
        let stdx20 = cangjieExactSymbolLookup(kb, "ArrayList.add", sourceSet: CangjieSourceSets.STDX, targetVersion: "2.0.0")
        let wrongVersion = cangjieExactSymbolLookup(kb, "ArrayList.add", sourceSet: CangjieSourceSets.STD, targetVersion: "2.0.0")

        @Expect(std10.records.size, 1)
        @Expect(std10.records[0].metadata.sourceSet, CangjieSourceSets.STD)
        @Expect(std10.records[0].metadata.targetVersion, "1.0.0")
        @Expect(stdx20.records.size, 1)
        @Expect(stdx20.records[0].metadata.sourceSet, CangjieSourceSets.STDX)
        @Expect(stdx20.records[0].metadata.targetVersion, "2.0.0")
        @Expect(wrongVersion.degraded, true)
        @Expect(wrongVersion.records.size, 0)
    }

    @TestCase
    public func p6Pos001CapabilityEndpointsReturnExactNonDegradedPacks(): Unit {
        let service = CangjieCapabilityService(p6ExactLookupKnowledgeBase())

        let symbol = service.symbolLookup("ArrayList.add", sourceSet: CangjieSourceSets.STD, targetVersion: "1.0.0")
        let section = service.docSection("docs/dev-guide/arrays.md#0-array-section", targetVersion: "1.0.0")
        let tool = service.toolManual("cjpm", command: "test", targetVersion: "1.0.0")

        @Expect(symbol.degraded, false)
        @Expect(symbol.notes.contains("exact_symbol_lookup_endpoint"), true)
        @Expect(symbol.notes.contains("exact_hit"), true)
        @Expect(symbol.apiItems.size, 1)
        @Expect(symbol.apiItems[0].symbol, "ArrayList.add")
        @Expect(section.degraded, false)
        @Expect(section.notes.contains("exact_doc_section_endpoint"), true)
        @Expect(section.items.size, 1)
        @Expect(section.items[0].kind, "doc_section")
        @Expect(tool.degraded, false)
        @Expect(tool.notes.contains("exact_tool_manual_endpoint"), true)
        @Expect(tool.items.size, 1)
        @Expect(tool.items[0].content.contains("cjpm test"), true)
    }

    @TestCase
    public func p6Neg001UnknownToolCommandReturnsMissWithoutUnrelatedDocs(): Unit {
        let service = CangjieCapabilityService(p6ExactLookupKnowledgeBase())

        let pack = service.toolManual("cjpm", command: "publish", targetVersion: "1.0.0")

        @Expect(pack.degraded, true)
        @Expect(pack.notes.contains("exact_miss"), true)
        @Expect(pack.items.size, 0)
        @Expect(pack.apiItems.size, 0)
        @Expect(pack.citations.size, 0)
    }
}

public func p6ExactLookupKnowledgeBase(): KnowledgeBase {
    let kb = newOfflineKnowledgeBase()
    let records = ArrayList<CangjieTypedRecord>()
    records.add(p6ExactSymbolRecord("ArrayList.add", "std.collection", CangjieSourceSets.STD, "1.0.0"))
    records.add(p6ExactSymbolRecord("ArrayList.add", "stdx.collection", CangjieSourceSets.STDX, "2.0.0"))
    records.add(p6ExactDocRecord())
    records.add(p6ExactToolRecord())
    kb.loadFirstInitializationTypedRecords(records, "p6-exact-candidate")
    _ = kb.promoteFirstInitializationCandidate("p6-exact-active")
    kb
}

public func p6PersistExactLookupStore(name: String): FileKnowledgeStore {
    let store = FileKnowledgeStore("target/${name}")
    let kb = p6ExactLookupKnowledgeBase()
    kb.persistActiveSnapshot(store)
    store
}

private func p6ExactSymbolRecord(symbol: String, module: String, sourceSet: String, targetVersion: String): CangjieTypedRecord {
    let record = CangjieTypedRecord()
    record.recordKind = CangjieTypedRecordKinds.SYMBOL_CARD
    record.sourceId = "p6-symbol-${sourceSet}-${targetVersion.replace(".", "-")}"
    record.title = "Symbol: ${symbol}"
    record.content = "symbolKey=${symbol}\nmodule=${module}\nimportLine=import ${module}.*\nsignature=public func ${symbol.split(".")[1]}(value: Int64): Unit\navailability=stable"
    record.citation = "Cangjie/${sourceSet}@release-${targetVersion}:src/${symbol}.cj#${symbol}"
    record.sourceSet = sourceSet
    record.sourceFamily = if (sourceSet == CangjieSourceSets.STDX) { "stdx" } else { "stdlib" }
    record.path = "src/${symbol}.cj"
    record.symbol = symbol
    record.sectionId = "${module}#${symbol}"
    record.targetVersion = targetVersion
    record.sourceRef = "release-${targetVersion}"
    record.versionResolutionId = "cangjie-${targetVersion}-${sourceSet}-release-${targetVersion}"
    record.trustLevel = TrustLevels.OFFICIAL
    record.reviewState = ReviewStates.TRUSTED
    record
}

private func p6ExactDocRecord(): CangjieTypedRecord {
    let record = CangjieTypedRecord()
    record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    record.sourceId = "p6-doc-array-section"
    record.title = "Arrays (docs/dev-guide/arrays.md)"
    record.content = "ArrayList.add appends one value and keeps insertion order."
    record.path = "docs/dev-guide/arrays.md"
    record.heading = "Arrays"
    record.sectionId = "docs/dev-guide/arrays.md#0-array-section"
    record.citation = "docs/dev-guide/arrays.md@release-1.0.0#docs/dev-guide/arrays.md#0-array-section"
    record.sourceSet = CangjieSourceSets.DOCS
    record.sourceFamily = "docs"
    record.targetVersion = "1.0.0"
    record.sourceRef = "release-1.0.0"
    record.versionResolutionId = "cangjie-1.0.0-docs-release-1.0.0"
    record.trustLevel = TrustLevels.OFFICIAL
    record.reviewState = ReviewStates.TRUSTED
    record
}

private func p6ExactToolRecord(): CangjieTypedRecord {
    let record = CangjieTypedRecord()
    record.recordKind = CangjieTypedRecordKinds.TOOL_MANUAL
    record.sourceId = "p6-tool-cjpm-test"
    record.title = "Tool manual: cjpm test"
    record.content = "Use cjpm test to run Cangjie package tests."
    record.path = "docs/tools/cjpm_manual.md"
    record.heading = "cjpm test"
    record.sectionId = "docs/tools/cjpm_manual.md#cjpm-test"
    record.citation = "docs/tools/cjpm_manual.md@release-1.0.0#cjpm-test"
    record.sourceSet = CangjieSourceSets.TOOLS
    record.sourceFamily = "tools"
    record.toolName = "cjpm"
    record.command = "test"
    record.targetVersion = "1.0.0"
    record.sourceRef = "release-1.0.0"
    record.versionResolutionId = "cangjie-1.0.0-tools-release-1.0.0"
    record.trustLevel = TrustLevels.OFFICIAL
    record.reviewState = ReviewStates.TRUSTED
    record
}
