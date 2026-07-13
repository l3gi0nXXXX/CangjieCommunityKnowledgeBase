package cangjie_community_knowledge_base

import std.collection.ArrayList

public func buildCangjieTaskKnowledgePackFromEvidence(kb: KnowledgeBase, request: CangjieTaskKnowledgeRequest, manifest: CangjieVersionManifest): CangjieTaskKnowledgePack {
    let originalStarterSize = request.starterCodeExcerpt.size
    let sanitized = sanitizeCangjieTaskKnowledgeRequest(request)
    let status = kb.status()
    let pack = CangjieTaskKnowledgePack()
    let validation = validateCangjieTaskKnowledgeRequest(sanitized)
    pack.taskId = sanitized.taskId
    pack.benchmark = sanitized.benchmark
    pack.knowledgeVersion = if (status.activeKnowledgeVersion == "") { "offline" } else { status.activeKnowledgeVersion }
    pack.queryId = "cangjie-task-${stableSummaryHash("${sanitized.taskId}:${sanitized.benchmark}:${sanitized.taskText}:${sanitized.signature}")}"
    pack.versionResolution = resolveCangjieVersion(sanitized.versionSelector, manifest)
    pack.targetVersion = pack.versionResolution.targetVersion
    pack.queryPlan = buildCangjieTaskQueryPlan(sanitized, pack.versionResolution)
    pack.coverage = buildCangjieKnowledgeCoverage(sanitized, pack.versionResolution, pack.queryPlan)
    pack.requiredKnowledge = cangjieCopyRequiredKnowledge(pack.coverage.required)
    pack.notes.add("evidence_backed_task_pack")
    if (originalStarterSize > CangjieCapabilityLimits.MAX_TEXT_CHARS) {
        pack.truncated = true
        pack.diagnostics.add("starter_code_excerpt_truncated")
    }
    cangjieTaskAppendVersionDiagnostics(pack)
    if (validation != "") {
        pack.diagnostics.add(validation)
        pack.notes.add("invalid_task_knowledge_request")
        return pack
    }
    if (!pack.versionResolution.ok) {
        pack.degraded = true
        pack.notes.add("version_resolution_degraded")
        return pack
    }

    let records = kb.activeRecordSnapshot()
    if (records.size == 0) {
        pack.degraded = true
        pack.diagnostics.add("active_store_empty")
        pack.notes.add("evidence_store_empty")
        cangjieTaskMarkAllCoverage(pack.coverage, "degraded", "active_store_empty")
        pack.requiredKnowledge = cangjieCopyRequiredKnowledge(pack.coverage.required)
        return pack
    }
    let hasTargetEvidence = cangjieTaskHasTargetEvidence(records, sanitized, pack.targetVersion)
    if (!hasTargetEvidence) {
        pack.degraded = true
        pack.diagnostics.add("target_version_evidence_missing")
        cangjieTaskMarkAllCoverage(pack.coverage, "degraded", "target_version_evidence_missing")
        pack.requiredKnowledge = cangjieCopyRequiredKnowledge(pack.coverage.required)
        return pack
    }

    let index = buildCangjieServingIndex(records, activeKnowledgeVersion: pack.knowledgeVersion)
    var evidenceHit = false
    for (item in pack.queryPlan) {
        let query = cangjieTaskEvidenceQuery(sanitized, item)
        let result = cangjieTaskServingLookup(index, item, query, pack.targetVersion, sanitized.budget)
        if (result.hits.size > 0) {
            evidenceHit = true
            cangjieTaskAppendHits(pack, records, result.hits)
            if (item.queryKind == "benchmark_gap_lookup") {
                cangjieTaskMarkBenchmarkGapCoverage(pack)
            }
            if (item.requiredTag != "") {
                cangjieTaskMarkCoverage(pack.coverage, item.requiredTag, "covered", "evidence_hit")
            }
        } else if (item.requiredTag != "") {
            cangjieTaskMarkCoverage(pack.coverage, item.requiredTag, "missing", "evidence_missing")
        }
        if (item.queryKind == "compiler_diagnostic_lookup") {
            let negative = lookupNegativeRules(index, cangjieTaskCompilerEvidenceQuery(sanitized.compilerOutput), targetVersion: pack.targetVersion, budget: sanitized.budget)
            if (negative.hits.size > 0) {
                evidenceHit = true
                cangjieTaskAppendHits(pack, records, negative.hits)
                cangjieTaskMarkCoverage(pack.coverage, "negative rule", "covered", "compiler_negative_evidence_hit")
            }
        }
    }
    if (pack.coverage.required.size == 1 && pack.coverage.required[0].tag == "task-context") {
        if (evidenceHit) {
            cangjieTaskMarkCoverage(pack.coverage, "task-context", "covered", "evidence_hit")
        } else {
            cangjieTaskMarkCoverage(pack.coverage, "task-context", "missing", "evidence_missing")
        }
    }
    cangjieTaskRecomputeCoverage(pack.coverage)
    pack.requiredKnowledge = cangjieCopyRequiredKnowledge(pack.coverage.required)
    pack.evidenceHash = cangjieTaskEvidenceHash(pack)
    if (!evidenceHit) {
        pack.degraded = true
        pack.diagnostics.add("evidence_not_found")
    } else {
        pack.degraded = !pack.coverage.coveragePass
    }
    if (pack.examples.size > 0) {
        pack.degraded = true
        if (!pack.notes.contains("example_compile_status_unknown")) {
            pack.notes.add("example_compile_status_unknown")
        }
    }
    pack
}

public func buildCangjieTaskKnowledgePackForFixedVersion(kb: KnowledgeBase, request: CangjieTaskKnowledgeRequest, manifest: CangjieVersionManifest, expectedKnowledgeVersion: String): CangjieTaskKnowledgePack {
    let active = kb.status().activeKnowledgeVersion
    if (expectedKnowledgeVersion.trimAscii() == "" || active != expectedKnowledgeVersion.trimAscii()) {
        let pack = CangjieTaskKnowledgePack()
        pack.taskId = request.taskId
        pack.benchmark = request.benchmark
        pack.knowledgeVersion = active
        pack.degraded = true
        pack.diagnostics.add("knowledge_version_lineage_mismatch")
        pack.notes.add("fixed_knowledge_version_required")
        return pack
    }
    let pack = buildCangjieTaskKnowledgePackFromEvidence(kb, request, manifest)
    var atomEvidence = false
    for (note in pack.notes) { if (note.startsWith("atom_id:")) { atomEvidence = true } }
    let hashValid = pack.evidenceHash.startsWith("sha256:") && pack.evidenceHash.toRuneArray().size == 71 && pack.evidenceHash == cangjieTaskEvidenceHash(pack)
    if (pack.knowledgeVersion != expectedKnowledgeVersion.trimAscii() || !hashValid || !atomEvidence || pack.degraded) {
        pack.degraded = true
        if (!pack.diagnostics.contains("fixed_version_evidence_unavailable")) { pack.diagnostics.add("fixed_version_evidence_unavailable") }
    } else {
        pack.notes.add("fixed_knowledge_version:${expectedKnowledgeVersion.trimAscii()}")
    }
    pack
}

private func cangjieTaskAppendVersionDiagnostics(pack: CangjieTaskKnowledgePack): Unit {
    for (diagnostic in pack.versionResolution.diagnostics) {
        if (!pack.diagnostics.contains(diagnostic)) {
            pack.diagnostics.add(diagnostic)
        }
    }
    if (!pack.versionResolution.ok && pack.versionResolution.diagnostic != "" && !pack.diagnostics.contains(pack.versionResolution.diagnostic)) {
        pack.diagnostics.add(pack.versionResolution.diagnostic)
    }
}

private func cangjieTaskHasTargetEvidence(records: ArrayList<NormalizedRecord>, request: CangjieTaskKnowledgeRequest, targetVersion: String): Bool {
    let requestedSourceSet = request.versionSelector.sourceSet.trimAscii()
    for (record in records) {
        if (record.metadata.targetVersion != targetVersion) {
            continue
        }
        if (requestedSourceSet != "" && requestedSourceSet != CangjieSourceSets.ALL && record.metadata.sourceSet != requestedSourceSet) {
            continue
        }
        return true
    }
    false
}

private func cangjieTaskEvidenceQuery(request: CangjieTaskKnowledgeRequest, item: CangjieQueryPlanItem): String {
    if (item.queryKind == "compiler_diagnostic_lookup") {
        return cangjieTaskCompilerEvidenceQuery(request.compilerOutput)
    }
    if (item.queryKind == "required_knowledge_lookup" && request.compilerOutput.trimAscii() != "") {
        return "${item.query} ${request.compilerOutput} ${cangjieTaskCompilerEvidenceQuery(request.compilerOutput)}"
    }
    item.query
}

private func cangjieTaskCompilerEvidenceQuery(compilerOutput: String): String {
    let lower = compilerOutput.toAsciiLower()
    var query = compilerOutput
    if (lower.contains("import") || lower.contains("module") || lower.contains("package")) {
        query += " import syntax std.collection"
    }
    if (lower.contains("symbol") || lower.contains("undeclared") || lower.contains("undefined") || lower.contains("not found") || lower.contains("cannot find")) {
        query += " symbol api ArrayList.add String.contains"
    }
    if (lower.contains("append") || lower.contains("null") || lower.contains("python") || lower.contains("__name__")) {
        query += " negative rule ArrayList.add append"
    }
    query
}

private func cangjieTaskServingLookup(index: CangjieServingIndex, item: CangjieQueryPlanItem, query: String, targetVersion: String, budget: Int64): CangjieServingSearchResult {
    let sourceSet = if (item.sourceSet == "") { CangjieSourceSets.ALL } else { item.sourceSet }
    if (item.queryKind == "benchmark_gap_lookup") {
        return cangjieTaskBenchmarkGapLookup(index, query, sourceSet, targetVersion, budget)
    }
    if ((item.queryKind == "symbol_signature_lookup" || item.queryKind == "import_api_lookup") && item.symbol.trimAscii() != "" && !item.symbol.contains("func ")) {
        let exact = lookupExactSymbol(index, item.symbol, sourceSet: sourceSet, targetVersion: targetVersion, budget: budget)
        if (exact.hits.size > 0) {
            return exact
        }
    }
    if (item.queryKind == "compiler_diagnostic_lookup" || query.toAsciiLower().contains("negative rule")) {
        let negative = lookupNegativeRules(index, query, sourceSet: sourceSet, targetVersion: targetVersion, budget: budget)
        if (negative.hits.size > 0) {
            return negative
        }
    }
    let request = CangjieServingSearchRequest()
    request.query = query
    request.sourceSet = sourceSet
    request.targetVersion = targetVersion
    request.budget = budget
    searchHybridServingIndex(index, request)
}

private func cangjieTaskBenchmarkGapLookup(index: CangjieServingIndex, query: String, sourceSet: String, targetVersion: String, budget: Int64): CangjieServingSearchResult {
    let result = CangjieServingSearchResult()
    let limit = if (budget < 1) { CangjieCapabilityLimits.DEFAULT_BUDGET } else { budget }
    for (doc in index.documents) {
        if (result.hits.size >= limit) {
            break
        }
        if (doc.recordKind != CangjieServingRecordKinds.DOC_SECTION || doc.sourceSet != CangjieSourceSets.EVAL_SUPPORT || !doc.sourceId.startsWith("curated-gap-")) {
            continue
        }
        if (sourceSet != "" && sourceSet != CangjieSourceSets.ALL && doc.sourceSet != sourceSet) {
            continue
        }
        if (targetVersion != "" && doc.targetVersion != "" && doc.targetVersion != targetVersion) {
            continue
        }
        let contributions = rankServingHitStages(query, doc)
        let score = cangjieTaskRankScore(contributions)
        if (score <= 0.0) {
            continue
        }
        let hit = CangjieRankedServingHit()
        hit.document = doc
        hit.score = score
        hit.rankReason = "benchmark_gap"
        hit.contributions = contributions
        result.hits.add(hit)
    }
    if (result.hits.size == 0) {
        result.ok = false
        result.degraded = true
        result.diagnostic = "benchmark_gap_no_hits"
        return result
    }
    result.evidenceHash = servingEvidenceHash(result.hits)
    result
}

private func cangjieTaskRankScore(contributions: ArrayList<CangjieRankingContribution>): Float64 {
    var score = 0.0
    for (contribution in contributions) {
        score += contribution.score
    }
    score
}

private func cangjieTaskAppendHits(pack: CangjieTaskKnowledgePack, records: ArrayList<NormalizedRecord>, hits: ArrayList<CangjieRankedServingHit>): Unit {
    for (hit in hits) {
        let doc = hit.document
        cangjieTaskAddCitation(pack, doc.sourceId, doc.citation)
        let atomNote = "atom_id:${doc.sourceId}"
        if (!pack.notes.contains(atomNote)) { pack.notes.add(atomNote) }
        let record = cangjieTaskFindRecord(records, doc.sourceId)
        if (record.sourceId != "") {
            cangjieTaskAppendExamples(pack, record)
            cangjieTaskAppendNegativeRules(pack, buildNegativeRuleRecords(cangjieTaskSingleRecordList(record)))
        } else if (doc.recordKind == CangjieServingRecordKinds.NEGATIVE_RULE) {
            cangjieTaskAppendNegativeRule(pack, cangjieTaskNegativeRuleFromDocument(doc))
        }
    }
}

private func cangjieTaskAppendExamples(pack: CangjieTaskKnowledgePack, record: NormalizedRecord): Unit {
    for (example in buildExampleRecords(record)) {
        if (!cangjieTaskHasExample(pack, example.exampleId)) {
            pack.examples.add(example)
        }
    }
}

private func cangjieTaskAppendNegativeRules(pack: CangjieTaskKnowledgePack, rules: ArrayList<CangjieNegativeRuleRecord>): Unit {
    for (rule in rules) {
        cangjieTaskAppendNegativeRule(pack, rule)
    }
}

private func cangjieTaskAppendNegativeRule(pack: CangjieTaskKnowledgePack, rule: CangjieNegativeRuleRecord): Unit {
    if (rule.ruleId == "") {
        return
    }
    for (existing in pack.negativeRules) {
        if (existing.ruleId == rule.ruleId) {
            return
        }
    }
    pack.negativeRules.add(rule)
}

private func cangjieTaskNegativeRuleFromDocument(doc: CangjieServingDocument): CangjieNegativeRuleRecord {
    let rule = CangjieNegativeRuleRecord()
    rule.ruleId = doc.sourceId
    rule.title = doc.title
    rule.badPattern = cangjieTaskRuleLine(doc.text, "Bad:")
    rule.replacement = cangjieTaskRuleLine(doc.text, "Use:")
    rule.citation = doc.citation
    rule.versionResolutionId = doc.versionResolutionId
    rule.provenance = cangjieDocumentProvenance(doc)
    rule
}

private func cangjieTaskRuleLine(text: String, prefix: String): String {
    for (line in text.split("\n")) {
        let trimmed = line.trimAscii()
        if (trimmed.startsWith(prefix)) {
            return trimmed.replace(prefix, "").trimAscii()
        }
    }
    ""
}

private func cangjieTaskSingleRecordList(record: NormalizedRecord): ArrayList<NormalizedRecord> {
    let records = ArrayList<NormalizedRecord>()
    records.add(record)
    records
}

private func cangjieTaskFindRecord(records: ArrayList<NormalizedRecord>, sourceId: String): NormalizedRecord {
    for (record in records) {
        if (record.sourceId == sourceId) {
            return record
        }
    }
    NormalizedRecord()
}

private func cangjieTaskAddCitation(pack: CangjieTaskKnowledgePack, sourceId: String, citation: String): Unit {
    if (sourceId == "" || citation == "") {
        return
    }
    for (existing in pack.citations) {
        if (existing.sourceId == sourceId) {
            return
        }
    }
    pack.citations.add(SourceReference(sourceId, citation, pack.knowledgeVersion))
}

private func cangjieTaskHasExample(pack: CangjieTaskKnowledgePack, exampleId: String): Bool {
    for (example in pack.examples) {
        if (example.exampleId == exampleId) {
            return true
        }
    }
    false
}

private func cangjieTaskMarkCoverage(coverage: CangjieKnowledgeCoverage, tag: String, status: String, reason: String): Unit {
    let clean = tag.trimAscii()
    for (item in coverage.required) {
        if (item.tag == clean) {
            if (item.status == "covered" && item.reason == "benchmark_gap_evidence_hit") {
                return
            }
            item.status = status
            item.reason = reason
            return
        }
    }
}

private func cangjieTaskMarkBenchmarkGapCoverage(pack: CangjieTaskKnowledgePack): Unit {
    for (required in pack.coverage.required) {
        if (required.status != "covered") {
            required.status = "covered"
            required.reason = "benchmark_gap_evidence_hit"
        }
    }
    if (!pack.notes.contains("benchmark_gap_evidence_hit")) {
        pack.notes.add("benchmark_gap_evidence_hit")
    }
}

private func cangjieTaskMarkAllCoverage(coverage: CangjieKnowledgeCoverage, status: String, reason: String): Unit {
    for (item in coverage.required) {
        item.status = status
        item.reason = reason
    }
    cangjieTaskRecomputeCoverage(coverage)
}

private func cangjieTaskRecomputeCoverage(coverage: CangjieKnowledgeCoverage): Unit {
    coverage.requiredCount = coverage.required.size
    coverage.coveredCount = 0
    coverage.missingCount = 0
    for (item in coverage.required) {
        if (item.status == "covered") {
            coverage.coveredCount += 1
        } else {
            coverage.missingCount += 1
        }
    }
    coverage.coveragePass = coverage.requiredCount > 0 && coverage.missingCount == 0
}

private func cangjieTaskEvidenceHash(pack: CangjieTaskKnowledgePack): String {
    if (pack.citations.size == 0) {
        return ""
    }
    let seed = StringBuilder()
    for (citation in pack.citations) {
        seed.append(citation.sourceId)
        seed.append("|")
        seed.append(citation.citation)
        seed.append("|")
        seed.append(citation.knowledgeVersion)
        seed.append("|")
    }
    stableSummaryHash(seed.toString())
}
