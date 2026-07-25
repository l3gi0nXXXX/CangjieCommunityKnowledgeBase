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
    public func r7Pos001AllSourceTaskPlanAddsInternalKnowledgeAtomLane(): Unit {
        let request = CangjieTaskKnowledgeRequest()
        request.taskText = "Compute a UTF-8 md5 digest 中文😀."
        request.versionSelector = cangjieVersionSelector(targetVersion: "1.0.0",
            sourceSet: CangjieSourceSets.ALL)
        let resolution = resolveCangjieVersion(request.versionSelector,
            defaultCangjieVersionManifest())

        let plan = buildCangjieTaskQueryPlan(request, resolution)

        @Expect(r3QueryPlanHasLane(plan, "knowledge_atom_lookup",
            CangjieSourceSets.KNOWLEDGE_ATOMS), true)
    }

    @TestCase
    public func r7Neg002RestrictedSourceTaskPlanDoesNotCrossIntoKnowledgeAtoms(): Unit {
        let request = CangjieTaskKnowledgeRequest()
        request.taskText = "Compute a UTF-8 md5 digest."
        request.versionSelector = cangjieVersionSelector(targetVersion: "1.0.0",
            sourceSet: CangjieSourceSets.DOCS)
        let resolution = resolveCangjieVersion(request.versionSelector,
            defaultCangjieVersionManifest())

        let plan = buildCangjieTaskQueryPlan(request, resolution)

        @Expect(r3QueryPlanHasLane(plan, "knowledge_atom_lookup",
            CangjieSourceSets.KNOWLEDGE_ATOMS), false)
    }

    @TestCase
    public func r7Neg005KnowledgeAtomSourceSetRequiresKnowledgeAtomRecordKind(): Unit {
        let malformed = r3LeakRecord("knowledge-atom-malformed", "Malformed atom",
            "Knowledge: generic digest guidance.")
        malformed.metadata.sourceSet = CangjieSourceSets.KNOWLEDGE_ATOMS
        let records = ArrayList<NormalizedRecord>()
        records.add(malformed)

        let diagnostic = cangjieStudentRecordDiagnostic(malformed)
        let projection = buildCangjieStudentServingProjection(records, "r7-malformed")

        @Expect(diagnostic.ok, false)
        @Expect(diagnostic.code, "atom_projection_invalid")
        @Expect(diagnostic.matchedField, "knowledgeAtom")
        @Expect(projection.valid, false)
        @Expect(projection.records.size, 0)
        @Expect(projection.diagnostic, "student_knowledge_leakage_blocked")
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

    @TestCase
    public func s2Ut01CollectorScansEveryStudentVisibleStringField(): Unit {
        let fields = [
            "recordKind", "sourceId", "title", "chunk", "citation",
            "metadata.sourceId", "metadata.sourceType", "metadata.sourceSet",
            "metadata.sourceUrl", "metadata.repo", "path", "symbol",
            "metadata.commit", "metadata.docVersion", "metadata.targetVersion",
            "metadata.versionResolutionId", "metadata.crawlAt",
            "metadata.indexedAt", "metadata.knowledgeVersion",
            "metadata.candidateVersion", "metadata.trustLevel",
            "metadata.reviewState", "metadata.license",
            "metadata.repoVisibility", "derivedFrom"
        ]
        for (field in fields) {
            let record = r3LeakRecord("safe-source", "safe title",
                "General Rune knowledge.")
            r3SetLeakageField(record, field,
                "前缀-cJ\u{200b}-hUmAnEvAl\u{2013}145-中文😀-后缀")
            let collected = collectCangjieStudentRecordDiagnostics(record)
            @Expect(r3CollectedContainsField(collected, field), true)
            @Expect(collected.scannedFields, 27 + record.metadata.derivedFrom.size)
        }
    }

    @TestCase
    public func s2Bnd01UnicodeEscapesLongTextAndTaskOutputAreBlocked(): Unit {
        for (value in [
            "CJ\\u002dHUMANEVAL\\u002d145",
            "visible-benchmark\\u002fCJ-HUMANEVAL-145",
            "${r3Repeat("中文😀", 4096)}cangjie_humaneval_145"
        ]) {
            let record = r3LeakRecord("safe-source", "safe title", value)
            @Expect(cangjieStudentRecordDiagnostic(record).ok, false)
        }
        let clean = r3LeakRecord("safe-source", "Human evaluation methods",
            "Unicode 中文😀 and long generic documentation are allowed.")
        @Expect(cangjieStudentRecordDiagnostic(clean).ok, true)

        let pack = CangjieTaskKnowledgePack()
        pack.taskId = "CJ-HUMANEVAL-145"
        pack.benchmark = "Cangjie-HumanEval"
        pack.knowledgeVersion = "clean-v1"
        pack.targetVersion = "1.0.0"
        let evidence = CangjieMatchedEvidence()
        evidence.sourceId = "official-rune"
        evidence.title = "Rune iteration"
        evidence.knowledge = "Iterate Unicode text by Rune."
        evidence.citation = "https://docs.cangjie-lang.cn/rune"
        pack.matchedEvidence.add(evidence)
        let task = collectCangjieTaskKnowledgeEvidenceDiagnostics(pack)
        @Expect(task.diagnostics.size > 0, true)
        @Expect(r3CollectedContainsField(task, "pack.taskId"), true)
        @Expect(r3CollectedContainsField(task, "pack.benchmark"), true)
        pack.taskId = "safe-task"
        pack.benchmark = "safe-benchmark"
        @Expect(collectCangjieTaskKnowledgeEvidenceDiagnostics(pack)
            .diagnostics.size, 0)
        evidence.provenance = "CJ-HUMANEVAL-145"
        @Expect(collectCangjieTaskKnowledgeEvidenceDiagnostics(pack)
            .diagnostics.size > 0, true)
    }

    @TestCase
    public func s2Ut01TaskPackJsonFieldMatrixHasNoUnscannedString(): Unit {
        let value = "CJ-HUMANEVAL-145"
        let pack = CangjieTaskKnowledgePack()
        pack.queryId = value; pack.taskId = value; pack.benchmark = value
        pack.knowledgeVersion = value; pack.targetVersion = value
        pack.evidenceHash = value
        pack.versionResolution.diagnostic = value
        pack.versionResolution.targetVersion = value
        pack.versionResolution.versionPolicy = value
        pack.versionResolution.versionResolutionId = value
        pack.versionResolution.diagnostics.add(value)
        let source = CangjieVersionSource()
        source.targetVersion = value; source.sourceSet = value
        source.sourceFamily = value; source.sourceRepo = value
        source.sourceRef = value; source.refKind = value
        source.resolvedCommit = value; source.contentHash = value
        pack.versionResolution.sources.add(source)
        let plan = CangjieQueryPlanItem()
        plan.interfaceId = value; plan.queryKind = value; plan.query = value
        plan.sourceSet = value; plan.symbol = value; plan.requiredTag = value
        plan.versionResolutionId = value; pack.queryPlan.add(plan)
        let required = CangjieRequiredKnowledge()
        required.tag = value; required.interfaceId = value
        required.status = value; required.reason = value
        pack.requiredKnowledge.add(required)
        let matched = CangjieMatchedEvidence()
        matched.sourceId = value; matched.title = value
        matched.citation = value; matched.provenance = value
        matched.contentHash = value; matched.knowledge = value
        matched.example = value; pack.matchedEvidence.add(matched)
        let example = CangjieExampleRecord()
        example.exampleId = value; example.title = value; example.code = value
        example.explanation = value; example.module = value
        example.symbol = value; example.citation = value
        example.sourceId = value; example.versionResolutionId = value
        example.trustLevel = value; example.reviewState = value
        example.compileStatus = value; example.provenance = value
        pack.examples.add(example)
        let negative = CangjieNegativeRuleRecord()
        negative.ruleId = value; negative.title = value
        negative.badPattern = value; negative.replacement = value
        negative.citation = value; negative.versionResolutionId = value
        negative.provenance = value; pack.negativeRules.add(negative)
        let citation = SourceReference()
        citation.sourceId = value; citation.citation = value
        citation.knowledgeVersion = value; pack.citations.add(citation)
        let covered = CangjieRequiredKnowledge()
        covered.tag = value; covered.interfaceId = value
        covered.status = value; covered.reason = value
        pack.coverage.required.add(covered)
        pack.notes.add(value); pack.diagnostics.add(value)

        let collected = collectCangjieTaskKnowledgeEvidenceDiagnostics(pack)
        @Expect(collected.scannedFields, 66)
        for (field in [
            "pack.queryId", "pack.taskId", "pack.benchmark",
            "pack.knowledgeVersion", "pack.targetVersion", "pack.evidenceHash",
            "versionResolution.diagnostic", "versionResolution.targetVersion",
            "versionResolution.versionPolicy",
            "versionResolution.versionResolutionId",
            "versionResolution.sources.targetVersion",
            "versionResolution.sources.sourceSet",
            "versionResolution.sources.sourceFamily",
            "versionResolution.sources.sourceRepo",
            "versionResolution.sources.sourceRef",
            "versionResolution.sources.refKind",
            "versionResolution.sources.resolvedCommit",
            "versionResolution.sources.contentHash",
            "versionResolution.diagnostics", "queryPlan.interfaceId",
            "queryPlan.queryKind", "queryPlan.query", "queryPlan.sourceSet",
            "queryPlan.symbol", "queryPlan.requiredTag",
            "queryPlan.versionResolutionId", "requiredKnowledge.tag",
            "requiredKnowledge.interfaceId", "requiredKnowledge.status",
            "requiredKnowledge.reason", "matchedEvidence.sourceId",
            "matchedEvidence.title", "matchedEvidence.citation",
            "matchedEvidence.provenance", "matchedEvidence.contentHash",
            "matchedEvidence.knowledge", "matchedEvidence.example",
            "examples.exampleId", "examples.sourceId", "examples.title",
            "examples.code", "examples.explanation", "examples.module",
            "examples.symbol", "examples.citation",
            "examples.versionResolutionId", "examples.trustLevel",
            "examples.reviewState", "examples.compileStatus",
            "examples.provenance", "negativeRules.ruleId",
            "negativeRules.title", "negativeRules.badPattern",
            "negativeRules.replacement", "negativeRules.citation",
            "negativeRules.versionResolutionId", "negativeRules.provenance",
            "citations.sourceId", "citations.citation",
            "citations.knowledgeVersion", "coverage.required.tag",
            "coverage.required.interfaceId", "coverage.required.status",
            "coverage.required.reason", "notes", "diagnostics"
        ]) {
            @Expect(r3CollectedContainsField(collected, field), true)
        }
    }

    @TestCase
    public func s2Pos01TaskPackProjectsPrivateVersionLineageBeforeRendering(): Unit {
        let request = CangjieTaskKnowledgeRequest()
        request.taskId = "safe-task"
        request.taskText = "Cangjie ArrayList syntax"
        let pack = buildCangjieTaskKnowledgePack(KnowledgeStatus(), request,
            defaultCangjieVersionManifest())
        let rendered = cangjieTaskKnowledgePackJson(pack).toAsciiLower()
        @Expect(rendered.contains("eval-support"), false)
        @Expect(rendered.contains("humaneval"), false)
        @Expect(collectCangjieTaskKnowledgeEvidenceDiagnostics(pack)
            .diagnostics.size, 0)
    }

    @TestCase
    public func s2Ut01FullLayerReportCollectsAllFindingsWithoutPlaintext(): Unit {
        let input = CkbStudentLeakageScanInput()
        let raw = RawRecord(); raw.sourceId = "raw-safe"
        raw.title = "safe"; raw.content = "safe"
        raw.contentHash = benchmarkGapSha256(raw.content)
        raw.metadata.sourceType = SourceTypes.DOC
        raw.metadata.sourceSet = CangjieSourceSets.DOCS
        raw.metadata.reviewState = ReviewStates.TRUSTED
        raw.metadata.trustLevel = TrustLevels.OFFICIAL
        raw.metadata.repo = "CJ-HUMANEVAL-145"
        input.rawRecords.add(raw)
        let normalized = r3LeakRecord("normalized-safe", "safe", "safe")
        normalized.metadata.commit = "CJ-HUMANEVAL-145"
        input.normalizedRecords.add(normalized)
        let serving = CangjieServingDocument()
        serving.documentId = "serving-safe"; serving.sourceId = "serving-safe"
        serving.recordKind = CangjieServingRecordKinds.DOC_SECTION
        serving.title = "safe"; serving.text = "CJ-HUMANEVAL-145"
        serving.sourceSet = CangjieSourceSets.DOCS
        serving.trustLevel = TrustLevels.OFFICIAL
        serving.reviewState = ReviewStates.TRUSTED
        input.servingDocuments.add(serving)
        let index = r3LeakRecord("index-safe", "safe", "safe")
        index.metadata.license = "CJ-HUMANEVAL-145"
        input.indexRecords.add(index)
        let indexDocument = CangjieServingDocument()
        indexDocument.documentId = "index-document-safe"
        indexDocument.sourceId = "index-document-safe"
        indexDocument.recordKind = CangjieServingRecordKinds.DOC_SECTION
        indexDocument.title = "safe"; indexDocument.text = "safe"
        indexDocument.sourceSet = CangjieSourceSets.DOCS
        indexDocument.trustLevel = TrustLevels.OFFICIAL
        indexDocument.reviewState = ReviewStates.TRUSTED
        indexDocument.rankProfile = "CJ-HUMANEVAL-145"
        input.indexDocuments.add(indexDocument)
        let exact = CangjieServingExactEntry()
        exact.lookupKind = "symbol"; exact.key = "safe"
        exact.selector = "CJ-HUMANEVAL-145"
        exact.sourceId = "safe"; exact.documentId = "safe"
        input.exactEntries.add(exact)
        let pack = CangjieTaskKnowledgePack()
        let taskEvidence = CangjieMatchedEvidence()
        taskEvidence.sourceId = "task-safe"
        taskEvidence.title = "safe"
        taskEvidence.knowledge = "CJ-HUMANEVAL-145"
        pack.matchedEvidence.add(taskEvidence)
        input.taskPacks.add(pack)
        input.authorityHash = benchmarkGapSha256("authority")
        input.candidateChecksum =
            ckbCertifiedNormalizedRecordsChecksum(input.normalizedRecords)

        let report = ckbBuildStudentLeakageReportFromLayers(input)

        @Expect(report.ok, false)
        @Expect(report.scannedRecords, 7)
        @Expect(report.scannedFields > 0, true)
        for (layer in ["raw", "normalized", "serving", "index",
            "index-document", "exact-entry", "task"]) {
            @Expect(r3ReportContainsLayer(report, layer), true)
        }
        @Expect(report.json.contains("CJ-HUMANEVAL"), false)
        @Expect(report.json.contains("中文"), false)
        @Expect(report.json.contains("\"authorityHash\""), true)
        @Expect(report.json.contains("\"candidateChecksum\""), true)
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

private func r3QueryPlanHasLane(plan: ArrayList<CangjieQueryPlanItem>, queryKind: String,
    sourceSet: String): Bool {
    for (item in plan) {
        if (item.queryKind == queryKind && item.sourceSet == sourceSet) { return true }
    }
    false
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

private func r3SetLeakageField(record: NormalizedRecord, field: String,
    value: String): Unit {
    if (field == "recordKind") { record.recordKind = value }
    else if (field == "sourceId") { record.sourceId = value }
    else if (field == "title") { record.title = value }
    else if (field == "chunk") { record.chunk = value }
    else if (field == "citation") { record.citation = value }
    else if (field == "metadata.sourceId") { record.metadata.sourceId = value }
    else if (field == "metadata.sourceType") { record.metadata.sourceType = value }
    else if (field == "metadata.sourceSet") { record.metadata.sourceSet = value }
    else if (field == "metadata.sourceUrl") { record.metadata.sourceUrl = value }
    else if (field == "metadata.repo") { record.metadata.repo = value }
    else if (field == "path") { record.metadata.path = value }
    else if (field == "symbol") { record.metadata.symbol = value }
    else if (field == "metadata.commit") { record.metadata.commit = value }
    else if (field == "metadata.docVersion") { record.metadata.docVersion = value }
    else if (field == "metadata.targetVersion") { record.metadata.targetVersion = value }
    else if (field == "metadata.versionResolutionId") {
        record.metadata.versionResolutionId = value
    } else if (field == "metadata.crawlAt") { record.metadata.crawlAt = value }
    else if (field == "metadata.indexedAt") { record.metadata.indexedAt = value }
    else if (field == "metadata.knowledgeVersion") {
        record.metadata.knowledgeVersion = value
    } else if (field == "metadata.candidateVersion") {
        record.metadata.candidateVersion = value
    } else if (field == "metadata.trustLevel") { record.metadata.trustLevel = value }
    else if (field == "metadata.reviewState") { record.metadata.reviewState = value }
    else if (field == "metadata.license") { record.metadata.license = value }
    else if (field == "metadata.repoVisibility") {
        record.metadata.repoVisibility = value
    } else if (field == "derivedFrom") { record.metadata.derivedFrom = [value] }
}

private func r3CollectedContainsField(collected: CangjieStudentKnowledgeDiagnostics,
    field: String): Bool {
    for (diagnostic in collected.diagnostics) {
        if (diagnostic.matchedField == field) { return true }
    }
    false
}

private func r3ReportContainsLayer(report: CkbStudentLeakageReport,
    layer: String): Bool {
    for (finding in report.findings) {
        if (finding.layer == layer) { return true }
    }
    false
}
