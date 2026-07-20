package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.collection.HashMap
import std.convert.Parsable
import std.fs.{File, Path, canonicalize, exists}
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

public class CangjieBenchmarkGapInput {
    public var schemaVersion: String = ""
    public var datasetVersion: String = ""
    public var teacherRunId: String = ""
    public var evidenceHash: String = ""
    public var evidence: String = ""
    public var candidateHash: String = ""
    public var candidatePath: String = ""
    public var revision: Int64 = 1
    public var attempt: Int64 = 1
    public var failureTaxonomy: String = "knowledge_gap"
    public var knowledgeGapConfirmations: Int64 = 2
    public var sourceClass: String = ""
    public var caseId: String = ""
    public var benchmark: String = "Cangjie-HumanEval"
    public var taskText: String = ""
    public var visibleTestExcerpt: String = ""
    public var compilerOutput: String = ""
    public var missingKnowledge: String = ""
    public var interfaceId: String = ""
    public var contentFamily: String = ""
    public var updateMechanism: String = ""
    public var targetVersion: String = ""
    public var officialCitation: String = ""
    public var knowledgeAtomTestBundle: String = ""
    public var knowledgeAtomCandidate: Bool = false
    public var knowledgeAtomId: String = ""
    public var knowledgeText: String = ""
    public var knowledgeExample: String = ""

    public init() {}
}

public class CangjieBenchmarkGapCurationResult {
    public var ok: Bool = true
    public var accepted: Int64 = 0
    public var rejected: Int64 = 0
    public var duplicates: Int64 = 0
    public var replacements: Int64 = 0
    public var replacementAudit: ArrayList<String> = ArrayList<String>()
    public var diagnostic: String = "ok"
    public var records: ArrayList<NormalizedRecord> = ArrayList<NormalizedRecord>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class CangjieBenchmarkGapParseResult {
    public var ok: Bool = true
    public var inputs: ArrayList<CangjieBenchmarkGapInput> = ArrayList<CangjieBenchmarkGapInput>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public func curateBenchmarkGapRecords(inputs: ArrayList<CangjieBenchmarkGapInput>, targetVersion!: String = cangjieDefaultTargetVersion()): CangjieBenchmarkGapCurationResult {
    let result = CangjieBenchmarkGapCurationResult()
    let identityHashes = HashMap<String, String>()
    let identityRevisions = HashMap<String, Int64>()
    let identityIndexes = HashMap<String, Int64>()
    var itemNumber: Int64 = 0
    for (input in inputs) {
        itemNumber += 1
        normalizeBenchmarkGapInput(input, targetVersion)
        let diagnostic = validateBenchmarkGapInput(input)
        if (diagnostic != "") {
            result.rejected += 1
            result.diagnostics.add("item=${itemNumber}:errorCode=${diagnostic}")
            continue
        }
        if (input.knowledgeAtomCandidate && input.knowledgeAtomTestBundle.trimAscii() == "") {
            result.rejected += 1
            result.diagnostics.add("item=${itemNumber}:errorCode=atom_test_bundle_required")
            continue
        }
        if (input.knowledgeAtomTestBundle.trimAscii() != "") {
            let atomTests = runKnowledgeAtomTestBundle(input.knowledgeAtomTestBundle)
            if (!atomTests.ok) {
                result.rejected += 1
                result.diagnostics.add("item=${itemNumber}:errorCode=${atomTests.diagnostic}")
                continue
            }
            if((input.sourceClass=="teacher_empirical")!=(atomTests.sourceClass=="teacher_empirical")){
                result.rejected+=1;result.diagnostics.add("item=${itemNumber}:errorCode=atom_source_class_mismatch");continue
            }
            input.knowledgeAtomId = atomTests.atomId
            input.knowledgeText = atomTests.knowledgeText
            input.knowledgeExample = atomTests.example
        }
        let identity = canonicalBenchmarkGapIdentity(input)
        let canonicalHash = canonicalBenchmarkGapInputHash(input)
        match (identityHashes.get(identity)) {
            case Some(existingHash) =>
                if (existingHash == canonicalHash) {
                    result.duplicates += 1
                    continue
                }
                let existingRevision = identityRevisions.get(identity).getOrThrow()
                if (input.revision > existingRevision) {
                    let index = identityIndexes.get(identity).getOrThrow()
                    result.records[index] = benchmarkGapRecord(input, targetVersion)
                    identityHashes[identity] = canonicalHash
                    identityRevisions[identity] = input.revision
                    result.replacements += 1
                    result.replacementAudit.add("identityHash=${benchmarkGapSha256(identity)}:oldRevision=${existingRevision}:newRevision=${input.revision}:oldHash=${existingHash}:newHash=${canonicalHash}")
                    continue
                }
                result.rejected += 1
                result.diagnostics.add("item=${itemNumber}:errorCode=benchmark_gap_identity_conflict:identityHash=${stableSummaryHash(identity)}")
                continue
            case None =>
                identityHashes.add(identity, canonicalHash)
                identityRevisions.add(identity, input.revision)
                identityIndexes.add(identity, result.records.size)
        }
        result.records.add(benchmarkGapRecord(input, targetVersion))
        result.accepted += 1
    }
    if (result.accepted == 0) {
        result.ok = false
        result.diagnostic = "no_gap_records_accepted"
    }
    if (result.rejected > 0) {
        result.ok = false
        result.records.clear()
        result.diagnostic = benchmarkGapPrimaryDiagnostic(result.diagnostics)
    }
    result
}

public func parseBenchmarkGapInputsJsonl(text: String): CangjieBenchmarkGapParseResult {
    let result = CangjieBenchmarkGapParseResult()
    var lineNumber: Int64 = 0
    for (line in text.split("\n")) {
        lineNumber += 1
        let raw = line.trimAscii()
        if (raw == "") {
            continue
        }
        try {
            let object = JsonValue.fromStr(raw).asObject()
            try {
                let input = CangjieBenchmarkGapInput()
                input.schemaVersion = benchmarkGapJsonString(object, "schemaVersion")
                input.datasetVersion = benchmarkGapJsonString(object, "datasetVersion")
                input.teacherRunId = benchmarkGapJsonString(object, "teacherRunId")
                input.evidenceHash = benchmarkGapJsonString(object, "evidenceHash")
                input.evidence = benchmarkGapJsonString(object, "evidence")
                input.candidateHash = benchmarkGapJsonString(object, "candidateHash")
                input.candidatePath = benchmarkGapJsonString(object, "candidatePath")
                input.revision = benchmarkGapJsonInt(object, "revision", 1)
                input.attempt = benchmarkGapJsonInt(object, "attempt", 1)
                input.failureTaxonomy = benchmarkGapJsonString(object, "failureTaxonomy")
                if (input.failureTaxonomy == "") { input.failureTaxonomy = "knowledge_gap" }
                input.knowledgeGapConfirmations = benchmarkGapJsonInt(object, "knowledgeGapConfirmations", 2)
                input.sourceClass = benchmarkGapJsonString(object, "sourceClass").toAsciiLower()
                input.caseId = benchmarkGapJsonString(object, "caseId")
                input.benchmark = benchmarkGapJsonString(object, "benchmark")
                if (input.benchmark == "") {
                    input.benchmark = "Cangjie-HumanEval"
                }
                input.taskText = benchmarkGapJsonString(object, "taskText")
                input.visibleTestExcerpt = benchmarkGapJsonString(object, "visibleTestExcerpt")
                input.compilerOutput = benchmarkGapJsonString(object, "compilerOutput")
                input.missingKnowledge = benchmarkGapJsonString(object, "missingKnowledge")
                input.interfaceId = benchmarkGapJsonString(object, "interfaceId")
                input.contentFamily = benchmarkGapJsonString(object, "contentFamily")
                input.updateMechanism = benchmarkGapJsonString(object, "updateMechanism")
                input.targetVersion = benchmarkGapJsonString(object, "targetVersion")
                input.officialCitation = benchmarkGapJsonString(object, "officialCitation")
                match (object.get("knowledgeAtomTestBundle")) {
                    case Some(value) => input.knowledgeAtomTestBundle = value.toString()
                    case None => ()
                }
                match (object.get("knowledgeAtomCandidate")) {
                    case Some(value) => input.knowledgeAtomCandidate = value.asBool().getValue()
                    case None => ()
                }
                result.inputs.add(input)
            } catch (_: Exception) {
                result.ok = false
                result.diagnostics.add("line=${lineNumber}:errorCode=field_contract_invalid")
            }
        } catch (_: Exception) {
            result.ok = false
            result.diagnostics.add("line=${lineNumber}:errorCode=malformed_json")
        }
    }
    result
}

public func curateBenchmarkGapRecordsFromJsonl(text: String, targetVersion!: String = cangjieDefaultTargetVersion()): CangjieBenchmarkGapCurationResult {
    let parsed = parseBenchmarkGapInputsJsonl(text)
    if (!parsed.ok) {
        let result = CangjieBenchmarkGapCurationResult()
        result.ok = false
        result.rejected = parsed.diagnostics.size
        result.diagnostic = benchmarkGapPrimaryDiagnostic(parsed.diagnostics)
        for (diagnostic in parsed.diagnostics) { result.diagnostics.add(diagnostic) }
        return result
    }
    curateBenchmarkGapRecords(parsed.inputs, targetVersion: targetVersion)
}

private func normalizeBenchmarkGapInput(input: CangjieBenchmarkGapInput, fallbackTargetVersion: String): Unit {
    input.sourceClass=input.sourceClass.trimAscii().toAsciiLower()
    if (input.targetVersion.trimAscii() == "") {
        input.targetVersion = fallbackTargetVersion
    }
    if (input.interfaceId.trimAscii() == "") {
        input.interfaceId = benchmarkGapInterfaceId(input.missingKnowledge)
    }
    if (input.contentFamily.trimAscii() == "") {
        input.contentFamily = benchmarkGapContentFamily(input.missingKnowledge)
    }
    if (input.updateMechanism.trimAscii() == "") {
        input.updateMechanism = "KU-11"
    }
}

private func validateBenchmarkGapInput(input: CangjieBenchmarkGapInput): String {
    let visible = "${input.taskText}\n${input.visibleTestExcerpt}\n${input.compilerOutput}\n${input.officialCitation}\n${input.interfaceId}\n${input.contentFamily}\n${input.updateMechanism}".toAsciiLower()
    if (input.caseId.trimAscii() == "") {
        return "case_id_required"
    }
    if (input.schemaVersion != "") {
        if (input.schemaVersion != "ckb-benchmark-gap-v1") { return "unsupported_schema_version" }
        if (!benchmarkGapDatasetVersionAllowed(input.datasetVersion)) { return "dataset_version_required" }
        if (!benchmarkGapSafeIdentityPart(input.teacherRunId, 256)) { return "teacher_run_id_required" }
        if (!benchmarkGapSha256FormatAllowed(input.evidenceHash)) { return "evidence_hash_invalid" }
        if (input.evidenceHash != benchmarkGapSha256(input.evidence)) { return "evidence_hash_mismatch" }
        if (!benchmarkGapSha256FormatAllowed(input.candidateHash)) { return "candidate_hash_invalid" }
        if (input.candidateHash != canonicalBenchmarkGapCandidateHash(input)) { return "candidate_hash_mismatch" }
        if (!benchmarkGapCandidatePathAllowed(input.candidatePath)) { return "candidate_path_forbidden" }
        if (input.revision < 1) { return "revision_invalid" }
        if (input.attempt != 1) { return "first_attempt_required" }
        if(input.sourceClass=="teacher_empirical"){
            if(!input.knowledgeAtomCandidate||!benchmarkGapTeacherEmpiricalTaxonomy(input.failureTaxonomy)){return "unverified_teacher_empirical"}
        }else{
            if(input.sourceClass!=""){return "source_class_not_allowed"}
            if (input.failureTaxonomy != "knowledge_gap") { return "knowledge_gap_taxonomy_required" }
            if (input.knowledgeGapConfirmations < 2) { return "knowledge_gap_double_confirmation_required" }
        }
    }
    if (!benchmarkGapSafeIdentityPart(input.caseId, 256)) {
        return "case_id_invalid"
    }
    if (!benchmarkGapSafeIdentityPart(input.benchmark, 128)) {
        return "benchmark_invalid"
    }
    if (visible.contains("/reference/") || visible.contains("reference/") || visible.contains("\\reference\\") || visible.contains("/hidden/") || visible.contains("hidden/") || visible.contains("\\hidden\\")) {
        return "hidden_or_reference_source_rejected"
    }
    if (input.missingKnowledge.trimAscii() == "") {
        return "missing_knowledge_required"
    }
    if (benchmarkGapRuneLength(input.taskText) > 65536 || benchmarkGapRuneLength(input.visibleTestExcerpt) > 65536 || benchmarkGapRuneLength(input.compilerOutput) > 65536 || benchmarkGapRuneLength(input.missingKnowledge) > 4096) {
        return "benchmark_gap_field_too_long"
    }
    if (input.taskText.trimAscii() == "" && input.compilerOutput.trimAscii() == "") {
        return "visible_failure_signal_required"
    }
    if (input.interfaceId.trimAscii() == "") {
        return "interface_id_required"
    }
    if (input.contentFamily.trimAscii() == "") {
        return "content_family_required"
    }
    if (input.updateMechanism.trimAscii() == "") {
        return "update_mechanism_required"
    }
    if(input.sourceClass=="teacher_empirical"){
        if(input.officialCitation.trimAscii()!=""){return "unverified_teacher_empirical"}
    }else{
        if(input.officialCitation.trimAscii()==""){return "official_citation_required"}
        if(!input.officialCitation.trimAscii().toAsciiLower().startsWith("https://docs.cangjie-lang.cn/")){return "official_citation_not_allowed"}
    }
    let expectedInterface = benchmarkGapInterfaceId(input.missingKnowledge)
    if (input.interfaceId.trimAscii() != expectedInterface) {
        return "interface_mapping_mismatch:${expectedInterface}"
    }
    let expectedFamily = benchmarkGapContentFamily(input.missingKnowledge)
    if (input.contentFamily.trimAscii() != expectedFamily) {
        return "content_family_mapping_mismatch:${expectedFamily}"
    }
    let expectedUpdate = benchmarkGapUpdateMechanism(input.missingKnowledge)
    if (input.updateMechanism.trimAscii() != expectedUpdate) {
        return "update_mechanism_mapping_mismatch:${expectedUpdate}"
    }
    ""
}

public func canonicalBenchmarkGapIdentity(input: CangjieBenchmarkGapInput): String {
    "${input.benchmark.trimAscii().toAsciiLower()}:${input.datasetVersion.trimAscii().toAsciiLower()}:${input.caseId.trimAscii().toAsciiLower()}:${input.missingKnowledge.trimAscii().toAsciiUpper()}:${input.targetVersion.trimAscii().toAsciiLower()}"
}

public func canonicalBenchmarkGapCandidateHash(input: CangjieBenchmarkGapInput): String {
    benchmarkGapSha256(benchmarkGapCanonicalPart(canonicalBenchmarkGapIdentity(input)) +
        benchmarkGapCanonicalPart(input.taskText) + benchmarkGapCanonicalPart(input.visibleTestExcerpt) +
        benchmarkGapCanonicalPart(input.compilerOutput) + benchmarkGapCanonicalPart(input.missingKnowledge.trimAscii().toAsciiUpper()) +
        benchmarkGapCanonicalPart(input.interfaceId.trimAscii()) + benchmarkGapCanonicalPart(input.contentFamily.trimAscii()) +
        benchmarkGapCanonicalPart(input.updateMechanism.trimAscii()) + benchmarkGapCanonicalPart(input.targetVersion.trimAscii()) +
        benchmarkGapCanonicalPart(input.officialCitation.trimAscii()) + benchmarkGapCanonicalPart(input.knowledgeAtomTestBundle.trimAscii()) +
        benchmarkGapCanonicalPart("${input.knowledgeAtomCandidate}") + benchmarkGapCanonicalPart(input.teacherRunId) +
        benchmarkGapCanonicalPart(input.evidenceHash) + benchmarkGapCanonicalPart(input.evidence) + benchmarkGapCanonicalPart(input.candidatePath) +
        benchmarkGapCanonicalPart("${input.revision}") + benchmarkGapCanonicalPart("${input.attempt}") +
        benchmarkGapCanonicalPart(input.failureTaxonomy) + benchmarkGapCanonicalPart("${input.knowledgeGapConfirmations}")+
        (if(input.sourceClass==""){""}else{benchmarkGapCanonicalPart(input.sourceClass)}))
}

private func benchmarkGapTeacherEmpiricalTaxonomy(value:String):Bool{
    ["knowledge_gap","reasoning_error","reasoning_failure","unit_failure","test_failure"].contains(value)
}

private func canonicalBenchmarkGapInputHash(input: CangjieBenchmarkGapInput): String { canonicalBenchmarkGapCandidateHash(input) }

public func benchmarkGapCandidatePathAllowed(path: String): Bool {
    let clean = path.trimAscii().replace("\\", "/")
    let lower = clean.toAsciiLower()
    clean != "" && !clean.startsWith("/") && !clean.contains("..") && !lower.contains("teacher-solutions") &&
        !lower.contains("ckb-data") && !lower.contains("/reference/") && !lower.contains("/hidden/")
}

private func benchmarkGapSha256FormatAllowed(value: String): Bool {
    let chars = value.toRuneArray()
    if (chars.size != 71 || !value.startsWith("sha256:")) { return false }
    for (i in 7..71) {
        let ch = chars[i]
        if (!((ch >= r'0' && ch <= r'9') || (ch >= r'a' && ch <= r'f'))) { return false }
    }
    true
}

public func benchmarkGapSha256(value: String): String {
    let digest = SHA256(); digest.write(value.toArray()); let out = StringBuilder()
    for (byte in digest.finish()) { out.append(benchmarkGapHexNibble(byte / UInt8(16))); out.append(benchmarkGapHexNibble(byte % UInt8(16))) }
    "sha256:${out.toString()}"
}

public func renderAuthoritativeBenchmarkGapInput(input: CangjieBenchmarkGapInput): String {
    let source=if(input.sourceClass==""){""}else{",\"sourceClass\":\"${benchmarkGapJsonEscape(input.sourceClass)}\""}
    "{\"schemaVersion\":\"${benchmarkGapJsonEscape(input.schemaVersion)}\",\"datasetVersion\":\"${benchmarkGapJsonEscape(input.datasetVersion)}\",\"teacherRunId\":\"${benchmarkGapJsonEscape(input.teacherRunId)}\",\"evidenceHash\":\"${benchmarkGapJsonEscape(input.evidenceHash)}\",\"evidence\":\"${benchmarkGapJsonEscape(input.evidence)}\",\"candidateHash\":\"${benchmarkGapJsonEscape(input.candidateHash)}\",\"candidatePath\":\"${benchmarkGapJsonEscape(input.candidatePath)}\",\"revision\":${input.revision},\"attempt\":${input.attempt},\"failureTaxonomy\":\"${benchmarkGapJsonEscape(input.failureTaxonomy)}\",\"knowledgeGapConfirmations\":${input.knowledgeGapConfirmations}${source},\"caseId\":\"${benchmarkGapJsonEscape(input.caseId)}\",\"benchmark\":\"${benchmarkGapJsonEscape(input.benchmark)}\",\"taskText\":\"${benchmarkGapJsonEscape(input.taskText)}\",\"visibleTestExcerpt\":\"${benchmarkGapJsonEscape(input.visibleTestExcerpt)}\",\"compilerOutput\":\"${benchmarkGapJsonEscape(input.compilerOutput)}\",\"missingKnowledge\":\"${benchmarkGapJsonEscape(input.missingKnowledge)}\",\"interfaceId\":\"${benchmarkGapJsonEscape(input.interfaceId)}\",\"contentFamily\":\"${benchmarkGapJsonEscape(input.contentFamily)}\",\"updateMechanism\":\"${benchmarkGapJsonEscape(input.updateMechanism)}\",\"targetVersion\":\"${benchmarkGapJsonEscape(input.targetVersion)}\",\"officialCitation\":\"${benchmarkGapJsonEscape(input.officialCitation)}\",\"knowledgeAtomCandidate\":false}"
}

private func benchmarkGapJsonEscape(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
}

private func benchmarkGapHexNibble(value: UInt8): String { if(value==UInt8(0)){return "0"};if(value==UInt8(1)){return "1"};if(value==UInt8(2)){return "2"};if(value==UInt8(3)){return "3"};if(value==UInt8(4)){return "4"};if(value==UInt8(5)){return "5"};if(value==UInt8(6)){return "6"};if(value==UInt8(7)){return "7"};if(value==UInt8(8)){return "8"};if(value==UInt8(9)){return "9"};if(value==UInt8(10)){return "a"};if(value==UInt8(11)){return "b"};if(value==UInt8(12)){return "c"};if(value==UInt8(13)){return "d"};if(value==UInt8(14)){return "e"};"f" }

public func importAuthoritativeBenchmarkGapJsonl(exportRoot: String, candidatePath: String, targetVersion!: String = cangjieDefaultTargetVersion()): CangjieBenchmarkGapCurationResult {
    let failure = CangjieBenchmarkGapCurationResult()
    failure.ok = false
    failure.diagnostic = "authoritative_import_path_invalid"
    try {
        let root = canonicalize(Path(exportRoot)).toString().replace("\\", "/")
        let requested = Path(candidatePath)
        let joined = if (candidatePath.startsWith("/")) { requested } else { Path(root).join(candidatePath) }
        if (!exists(joined)) { return failure }
        let canonical = canonicalize(joined).toString().replace("\\", "/")
        let lower = canonical.toAsciiLower()
        if (!canonical.startsWith(root + "/") || lower.contains("/teacher-solutions/") || lower.contains("/ckb-data/") || lower.contains("/reference/") || lower.contains("/hidden/")) { return failure }
        let relative = benchmarkGapRuneSafeRemovePrefix(canonical, root + "/")
        let text = try { String.fromUtf8(File.readFrom(Path(canonical))) } catch (_: Exception) { failure.diagnostic = "invalid_response_encoding"; return failure }
        let parsed = parseBenchmarkGapInputsJsonl(text)
        if (!parsed.ok || parsed.inputs.size == 0) { failure.diagnostic = if (!parsed.ok) { benchmarkGapPrimaryDiagnostic(parsed.diagnostics) } else { "authoritative_import_empty" }; return failure }
        for (input in parsed.inputs) {
            if (input.schemaVersion == "") { failure.diagnostic = "schema_version_required"; return failure }
            if (input.candidatePath.replace("\\", "/") != relative) { failure.diagnostic = "candidate_path_binding_mismatch"; return failure }
        }
        return curateBenchmarkGapRecords(parsed.inputs, targetVersion: targetVersion)
    } catch (_: Exception) { failure }
}

private func benchmarkGapRuneSafeRemovePrefix(value: String, prefix: String): String {
    if (!value.startsWith(prefix)) { return "" }
    let chars = value.toRuneArray(); let prefixCount = prefix.toRuneArray().size; let out = StringBuilder()
    for (i in prefixCount..chars.size) { out.append(chars[i]) }
    out.toString()
}

private func benchmarkGapCanonicalPart(value: String): String {
    "${value.size}:${value}"
}

private func benchmarkGapPrimaryDiagnostic(diagnostics: ArrayList<String>): String {
    if (diagnostics.size == 0) { return "benchmark_gap_input_rejected" }
    let first = diagnostics[0]
    let marker = "errorCode="
    let parts = first.split(marker)
    if (parts.size < 2) { return "benchmark_gap_input_rejected" }
    let values = parts[1].split(":")
    if (values.size == 0) { "benchmark_gap_input_rejected" } else { values[0] }
}

private func benchmarkGapSafeIdentityPart(raw: String, maxRunes: Int64): Bool {
    let trimmed = raw.trimAscii()
    let chars = trimmed.toRuneArray()
    if (chars.size == 0 || chars.size > maxRunes) { return false }
    for (ch in chars) {
        let asciiAlphaNumeric = (ch >= r'a' && ch <= r'z') || (ch >= r'A' && ch <= r'Z') || (ch >= r'0' && ch <= r'9')
        if (!asciiAlphaNumeric && ch != r'-' && ch != r'_' && ch != r'.') { return false }
    }
    true
}

private func benchmarkGapDatasetVersionAllowed(raw: String): Bool {
    let trimmed = raw.trimAscii()
    let chars = trimmed.toRuneArray()
    if (chars.size == 0 || chars.size > 256 || chars[0] == r':' || chars[chars.size - 1] == r':') {
        return false
    }
    var colons: Int64 = 0
    for (ch in chars) {
        let asciiAlphaNumeric = (ch >= r'a' && ch <= r'z') || (ch >= r'A' && ch <= r'Z') ||
            (ch >= r'0' && ch <= r'9')
        if (ch == r':') { colons += 1 }
        if (!asciiAlphaNumeric && ch != r'-' && ch != r'_' && ch != r'.' && ch != r':') {
            return false
        }
    }
    colons <= 1
}

private func benchmarkGapRuneLength(raw: String): Int64 {
    raw.toRuneArray().size
}

private func benchmarkGapRecord(input: CangjieBenchmarkGapInput, targetVersion: String): NormalizedRecord {
    let record = NormalizedRecord()
    let resolvedTargetVersion = if (input.targetVersion.trimAscii() == "") { targetVersion } else { input.targetVersion.trimAscii() }
    record.sourceId = benchmarkGapPersistentSourceId(input)
    record.recordKind = CangjieTypedRecordKinds.EVAL_SUPPORT
    record.title = "HumanEval gap ${input.caseId}: ${input.missingKnowledge}"
    let knowledgePrefix = if (input.knowledgeText == "") { "" } else {
        "Knowledge: ${input.knowledgeText}" +
            if (input.knowledgeExample == "") { "\n" } else { "\nExample: ${input.knowledgeExample}\n" }
    }
    record.chunk = knowledgePrefix + "Task: ${input.taskText}\nVisible tests: ${input.visibleTestExcerpt}\nCompiler output: ${input.compilerOutput}\nMissing knowledge: ${input.missingKnowledge}\nInterface ID: ${input.interfaceId}\nContent family: ${input.contentFamily}\nUpdate mechanism: ${input.updateMechanism}"
    if (input.knowledgeText != "") {
        record.metadata.derivedFrom = ["knowledge-atom:${input.knowledgeAtomId}"]
    }
    record.citation = input.officialCitation
    record.requiresReview = false
    record.metadata.sourceId = record.sourceId
    record.metadata.sourceType = SourceTypes.DERIVED
    record.metadata.sourceSet = CangjieSourceSets.EVAL_SUPPORT
    record.metadata.docVersion = input.datasetVersion.trimAscii()
    record.metadata.targetVersion = resolvedTargetVersion
    record.metadata.versionResolutionId = "cangjie-${resolvedTargetVersion}-eval-support-curated"
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.REVIEWED
    record.metadata.path = "visible-benchmark/${input.benchmark}/${input.caseId}/${input.interfaceId}"
    record.metadata.symbol = "${input.interfaceId}:${input.missingKnowledge}"
    record.metadata.contentSize = record.chunk.size
    record
}

public func benchmarkGapPersistentSourceId(input: CangjieBenchmarkGapInput): String {
    "curated-gap-${benchmarkGapSha256(canonicalBenchmarkGapIdentity(input)).replace("sha256:", "")}"
}

public func overlayBenchmarkGapRecords(active: ArrayList<NormalizedRecord>, delta: ArrayList<NormalizedRecord>): ArrayList<NormalizedRecord> {
    let out = ArrayList<NormalizedRecord>()
    let seenGapPoints = HashMap<String, Bool>()
    for (record in active) {
        if (benchmarkGapRecordReplacedByDelta(record, delta)) {
            continue
        }
        let persisted = benchmarkGapMigrateLegacyRecord(record)
        if (benchmarkGapPersistedRecord(persisted)) {
            let pointId = ckbVectorPointId(persisted)
            if (seenGapPoints.contains(pointId)) {
                continue
            }
            seenGapPoints.add(pointId, true)
        }
        out.add(persisted)
    }
    for (record in delta) {
        let pointId = ckbVectorPointId(record)
        if (seenGapPoints.contains(pointId)) {
            continue
        }
        seenGapPoints.add(pointId, true)
        out.add(record)
    }
    out
}

private func benchmarkGapRecordReplacedByDelta(record: NormalizedRecord, delta: ArrayList<NormalizedRecord>): Bool {
    for (replacement in delta) {
        if (record.sourceId == replacement.sourceId) {
            return true
        }
        if (benchmarkGapPersistedRecord(record) && benchmarkGapPersistedRecord(replacement) &&
            record.metadata.path == replacement.metadata.path &&
            record.metadata.symbol == replacement.metadata.symbol &&
            record.metadata.targetVersion == replacement.metadata.targetVersion &&
            (record.metadata.docVersion == "" || replacement.metadata.docVersion == "" ||
                record.metadata.docVersion == replacement.metadata.docVersion)) {
            return true
        }
    }
    false
}

private func benchmarkGapPersistedRecord(record: NormalizedRecord): Bool {
    record.sourceId.startsWith("curated-gap-") &&
        record.recordKind == CangjieTypedRecordKinds.EVAL_SUPPORT &&
        record.metadata.sourceSet == CangjieSourceSets.EVAL_SUPPORT &&
        record.metadata.path.startsWith("visible-benchmark/")
}

public func benchmarkGapLegacyPersistentSourceId(path: String, symbol: String, targetVersion: String,
    datasetVersion: String, title: String, content: String): String {
    let identity = benchmarkGapCanonicalPart(path) + benchmarkGapCanonicalPart(symbol) +
        benchmarkGapCanonicalPart(targetVersion) + benchmarkGapCanonicalPart(datasetVersion) +
        benchmarkGapCanonicalPart(title) + benchmarkGapCanonicalPart(content)
    "curated-gap-legacy-${benchmarkGapSha256(identity).replace("sha256:", "")}"
}

private func benchmarkGapMigrateLegacyRecord(record: NormalizedRecord): NormalizedRecord {
    if (!benchmarkGapPersistedRecord(record) || !record.sourceId.startsWith("curated-gap-h")) {
        return record
    }
    let out = NormalizedRecord()
    out.sourceId = benchmarkGapLegacyPersistentSourceId(record.metadata.path, record.metadata.symbol,
        record.metadata.targetVersion, record.metadata.docVersion, record.title, record.chunk)
    out.recordKind = record.recordKind; out.title = record.title; out.chunk = record.chunk
    out.citation = record.citation; out.score = record.score
    out.metadata = cangjieCopyKnowledgeMetadata(record.metadata); out.metadata.sourceId = out.sourceId
    out.requiresReview = record.requiresReview
    out
}

private func benchmarkGapRecordKey(input: CangjieBenchmarkGapInput): String {
    "${input.interfaceId}:${input.contentFamily}:${input.updateMechanism}:${input.missingKnowledge}"
}

private func benchmarkGapInterfaceId(missingKnowledge: String): String {
    let gap = benchmarkGapPrimaryCode(missingKnowledge)
    if (gap == "G-RECIPE" || gap == "G-TIMEOUT" || gap == "G-EDGE") { return "KI-07" }
    if (gap == "G-EVALVALUE" || gap == "G-EVALENTRY") { return "KI-05" }
    if (gap == "G-ARRAYLIST" || gap == "G-STRING" || gap == "G-HASHMAP" || gap == "G-FLOAT64") { return "KI-02" }
    "KI-04"
}

private func benchmarkGapContentFamily(missingKnowledge: String): String {
    let gap = benchmarkGapPrimaryCode(missingKnowledge)
    if (gap == "G-RECIPE" || gap == "G-TIMEOUT" || gap == "G-EDGE" || gap == "G-EVALVALUE" || gap == "G-EVALENTRY") { return "KC-05" }
    if (gap == "G-ARRAYLIST" || gap == "G-STRING" || gap == "G-HASHMAP" || gap == "G-FLOAT64") { return "KC-02" }
    "KC-01"
}

private func benchmarkGapUpdateMechanism(_missingKnowledge: String): String {
    "KU-11"
}

private func benchmarkGapPrimaryCode(missingKnowledge: String): String {
    let raw = missingKnowledge.trimAscii()
    if (raw == "") {
        return "G-RECIPE"
    }
    let first = raw.split(",")[0].trimAscii().toAsciiUpper()
    if (first.startsWith("G-")) {
        return first
    }
    let lower = raw.toAsciiLower()
    if (lower.contains("arraylist")) { return "G-ARRAYLIST" }
    if (lower.contains("hashmap")) { return "G-HASHMAP" }
    if (lower.contains("string") || lower.contains("rune")) { return "G-STRING" }
    if (lower.contains("float")) { return "G-FLOAT64" }
    if (lower.contains("evalvalue")) { return "G-EVALVALUE" }
    if (lower.contains("evalentry")) { return "G-EVALENTRY" }
    if (lower.contains("int") || lower.contains("numeric")) { return "G-INT64" }
    "G-RECIPE"
}

private func benchmarkGapJsonString(object: JsonObject, field: String): String {
    match (object.get(field)) {
        case Some(value) => value.asString().getValue()
        case None => ""
    }
}

private func benchmarkGapJsonInt(object: JsonObject, field: String, fallback: Int64): Int64 {
    match (object.get(field)) {
        case Some(value) => Int64.parse(value.toString())
        case None => fallback
    }
}
