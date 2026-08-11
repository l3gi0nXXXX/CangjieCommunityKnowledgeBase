package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashSet}
import std.fs.{File, Path, exists}
import std.sort.*
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

public class CkbReproContractResult {
    public var ok: Bool = false
    public var diagnostic: String = "not_validated"
    public var canonicalJson: String = ""
    public var manifestHash: String = ""
    public var treeHash: String = ""
    public var plannedCount: Int64 = 0
    public var presentCount: Int64 = 0
    public init() {}
}

public class CkbReproReferenceManifest {
    public var schemaVersion: String = ""
    public var baselineKind: String = ""
    public var evidenceStatus: String = ""
    public var releaseRepository: String = ""
    public var releaseRepositoryUrl: String = ""
    public var releaseBranch: String = ""
    public var observedRemote: String = ""
    public var runId: String = ""
    public var knowledgeVersion: String = ""
    public var vectorProofHash: String = ""
    public var datasetVersion: String = ""
    public var runnerCommit: String = ""
    public var claudeCodeVersion: String = ""
    public var model: String = ""
    public var modelFingerprint: String = ""
    public var providerFingerprint: String = ""
    public var experimentGroup: String = ""
    public var toolTransport: String = ""
    public var mcpTransport: String = ""
    public var ckbRequired: Bool = false
    public var localDocsPolicy: String = ""
    public var modelEffort: String = ""
    public var modelBudget: String = ""
    public var timeoutSeconds: Int64 = 0
    public var transportRetryBudget: Int64 = 0
    public var promptHash: String = ""
    public var resultsHash: String = ""
    public var runCriticalTreeHash: String = ""
    public var certifiedRunInputHash: String = ""
    public var totalCases: Int64 = 0
    public var rawPassed: Int64 = 0
    public var strictPassed: Int64 = 0
    public var strictFailed: Int64 = 0
    public var businessFailed: Int64 = 0
    public var protocolInvalid: Int64 = 0
    public var transportUnresolved: Int64 = 0
    public var missingEvidence: ArrayList<String> = ArrayList<String>()
    public init() {}
}

public class CkbPortablePathCategory {
    public var id: String = ""
    public var action: String = ""
    public init() {}
}

public class CkbPortablePathPolicy {
    public var schemaVersion: String = ""
    public var baselineState: String = ""
    public var unmappedAction: String = ""
    public var sourceRootRuleId: String = ""
    public var allowlist: ArrayList<String> = ArrayList<String>()
    public var placeholders: ArrayList<String> = ArrayList<String>()
    public var fieldCoverage: ArrayList<String> = ArrayList<String>()
    public var categories: ArrayList<CkbPortablePathCategory> = ArrayList<CkbPortablePathCategory>()
    public init() {}
}

public class CkbRunCriticalFile {
    public var path: String = ""
    public var status: String = ""
    public var sha256: String = ""
    public init() {}
}

public class CkbRunCriticalFilesManifest {
    public var schemaVersion: String = ""
    public var files: ArrayList<CkbRunCriticalFile> = ArrayList<CkbRunCriticalFile>()
    public init() {}
}

public class CkbHistoricalEvidenceFile {
    public var path: String = ""
    public var sha256: String = ""
    public init() {}
}

public class CkbHistoricalReferenceEvidence {
    public var schemaVersion: String = ""
    public var referenceCommit: String = ""
    public var modelProfileRole: String = ""
    public var modelProfileCount: Int64 = 0
    public var modelEffort: String = ""
    public var maxBudgetUsdState: String = ""
    public var modelBudgetDerivation: String = ""
    public var timeoutSeconds: Int64 = 0
    public var promptRole: String = ""
    public var promptCount: Int64 = 0
    public var promptAggregation: String = ""
    public var promptHash: String = ""
    public var vectorRole: String = ""
    public var vectorProofHash: String = ""
    public var vectorState: String = ""
    public var vectorTotal: Int64 = 0
    public var vectorDimension: Int64 = 0
    public var vectorFailed: Int64 = 0
    public var runCriticalRole: String = ""
    public var runCriticalCount: Int64 = 0
    public var runCriticalAggregation: String = ""
    public var runCriticalTreeHash: String = ""
    public var runCriticalFiles: ArrayList<CkbHistoricalEvidenceFile> = ArrayList<CkbHistoricalEvidenceFile>()
    public init() {}
}

public func parseCkbReproReferenceManifest(bytes: Array<UInt8>): (CkbReproContractResult, CkbReproReferenceManifest) {
    let manifest = CkbReproReferenceManifest()
    let decoded = ckbReproDecode(bytes)
    if (decoded[0] != "ok") { return (ckbReproFailure(decoded[0]), manifest) }
    try {
        let object = JsonValue.fromStr(decoded[1]).asObject()
        if (object.size() != 36 && object.size() != 37) {
            return (ckbReproFailure("reference_field_contract_invalid"), manifest)
        }
        manifest.schemaVersion = ckbReproString(object, "schemaVersion")
        manifest.baselineKind = ckbReproString(object, "baselineKind")
        manifest.evidenceStatus = ckbReproString(object, "evidenceStatus")
        manifest.releaseRepository = ckbReproString(object, "releaseRepository")
        manifest.releaseRepositoryUrl = ckbReproString(object, "releaseRepositoryUrl")
        manifest.releaseBranch = ckbReproString(object, "releaseBranch")
        manifest.observedRemote = ckbReproString(object, "observedRemote")
        manifest.runId = ckbReproString(object, "runId")
        manifest.knowledgeVersion = ckbReproString(object, "knowledgeVersion")
        manifest.vectorProofHash = ckbReproString(object, "vectorProofHash")
        manifest.datasetVersion = ckbReproString(object, "datasetVersion")
        manifest.runnerCommit = ckbReproString(object, "runnerCommit")
        manifest.claudeCodeVersion = ckbReproString(object, "claudeCodeVersion")
        manifest.model = ckbReproString(object, "model")
        manifest.modelFingerprint = ckbReproString(object, "modelFingerprint")
        manifest.providerFingerprint = ckbReproString(object, "providerFingerprint")
        manifest.experimentGroup = ckbReproString(object, "experimentGroup")
        manifest.toolTransport = ckbReproString(object, "toolTransport")
        manifest.mcpTransport = ckbReproString(object, "mcpTransport")
        manifest.ckbRequired = ckbReproBool(object, "ckbRequired")
        manifest.localDocsPolicy = ckbReproString(object, "localDocsPolicy")
        manifest.modelEffort = ckbReproString(object, "modelEffort")
        manifest.modelBudget = ckbReproString(object, "modelBudget")
        manifest.timeoutSeconds = ckbReproInt(object, "timeoutSeconds")
        manifest.transportRetryBudget = ckbReproInt(object, "transportRetryBudget")
        manifest.promptHash = ckbReproString(object, "promptHash")
        manifest.resultsHash = ckbReproString(object, "resultsHash")
        manifest.runCriticalTreeHash = ckbReproString(object, "runCriticalTreeHash")
        if (object.size() == 37) {
            manifest.certifiedRunInputHash = ckbReproString(object, "certifiedRunInputHash")
        }
        manifest.totalCases = ckbReproInt(object, "totalCases")
        manifest.rawPassed = ckbReproInt(object, "rawPassed")
        manifest.strictPassed = ckbReproInt(object, "strictPassed")
        manifest.strictFailed = ckbReproInt(object, "strictFailed")
        manifest.businessFailed = ckbReproInt(object, "businessFailed")
        manifest.protocolInvalid = ckbReproInt(object, "protocolInvalid")
        manifest.transportUnresolved = ckbReproInt(object, "transportUnresolved")
        if (!ckbReproStringArray(object, "missingEvidence", manifest.missingEvidence)) {
            return (ckbReproFailure("reference_field_contract_invalid"), CkbReproReferenceManifest())
        }
    } catch (_: Exception) {
        return (ckbReproFailure("reference_field_contract_invalid"), CkbReproReferenceManifest())
    }
    (ckbReproSuccess(), manifest)
}

public func validateCkbReproReferenceManifest(manifest: CkbReproReferenceManifest,
    mode!: String = "contract"): CkbReproContractResult {
    if (manifest.schemaVersion != "ckb-repro-reference-v1" ||
        (manifest.baselineKind != "historical_pre_portable" && manifest.baselineKind != "portable_release")) {
        return ckbReproFailure("identity_mismatch")
    }
    if (manifest.releaseRepository != "l3gi0nXXXX/CangjieCommunityKnowledgeBase" ||
        manifest.releaseRepositoryUrl != "https://github.com/l3gi0nXXXX/CangjieCommunityKnowledgeBase" ||
        manifest.releaseBranch != "main" ||
        normalizeCkbReproRepositoryRemote(manifest.observedRemote) != manifest.releaseRepository) {
        return ckbReproFailure("release_repository_mismatch")
    }
    if (manifest.runId == "" || manifest.knowledgeVersion == "" || manifest.datasetVersion == "" ||
        manifest.runnerCommit == "" || manifest.claudeCodeVersion == "" || manifest.model == "" ||
        manifest.modelFingerprint != "claude-code-glm-5.2" ||
        manifest.experimentGroup == "" || manifest.toolTransport == "" || manifest.mcpTransport == "" ||
        !manifest.ckbRequired || manifest.localDocsPolicy == "") {
        return ckbReproFailure("identity_mismatch")
    }
    if (manifest.totalCases != 164 || manifest.strictPassed < 0 ||
        manifest.strictPassed + manifest.strictFailed != 164 ||
        manifest.businessFailed + manifest.protocolInvalid + manifest.transportUnresolved != manifest.strictFailed ||
        manifest.transportUnresolved < 0 || manifest.rawPassed < manifest.strictPassed ||
        manifest.rawPassed > 164) {
        return ckbReproFailure("invalid_aggregate")
    }
    for (hash in [manifest.providerFingerprint, manifest.resultsHash]) {
        if (!ckbReproHashValid(hash)) { return ckbReproFailure("hash_mismatch") }
    }
    if (manifest.certifiedRunInputHash != "" &&
        !ckbReproHashValid(manifest.certifiedRunInputHash)) {
        return ckbReproFailure("hash_mismatch")
    }
    if (manifest.baselineKind == "portable_release" &&
        manifest.evidenceStatus == "complete" &&
        manifest.certifiedRunInputHash == "") {
        return ckbReproFailure("certified_run_input_hash_required")
    }
    if (manifest.evidenceStatus == "complete") {
        if (manifest.missingEvidence.size != 0 || !ckbReproHashValid(manifest.vectorProofHash) ||
            !ckbReproHashValid(manifest.promptHash) || !ckbReproHashValid(manifest.runCriticalTreeHash) ||
            manifest.modelEffort == "" || manifest.modelBudget == "" ||
            manifest.timeoutSeconds <= 0 || manifest.transportRetryBudget < 0) {
            return ckbReproFailure("identity_mismatch")
        }
    } else if (manifest.evidenceStatus == "incomplete" &&
        manifest.baselineKind == "historical_pre_portable" && mode == "contract") {
        if (manifest.missingEvidence.size == 0) { return ckbReproFailure("identity_mismatch") }
    } else {
        return ckbReproFailure("identity_evidence_incomplete")
    }
    let canonical = renderCkbReproReferenceManifest(manifest)
    let result = ckbReproSuccess()
    result.canonicalJson = canonical
    result.manifestHash = ckbReproSha256(canonical.toArray())
    result
}

public func renderCkbReproReferenceManifest(manifest: CkbReproReferenceManifest): String {
    let certified = if (manifest.certifiedRunInputHash == "") {
        ""
    } else {
        ",\"certifiedRunInputHash\":\"${ckbReproEscape(manifest.certifiedRunInputHash)}\""
    }
    "{\"schemaVersion\":\"${ckbReproEscape(manifest.schemaVersion)}\"," +
    "\"baselineKind\":\"${ckbReproEscape(manifest.baselineKind)}\"," +
    "\"evidenceStatus\":\"${ckbReproEscape(manifest.evidenceStatus)}\"," +
    "\"releaseRepository\":\"${ckbReproEscape(manifest.releaseRepository)}\"," +
    "\"releaseRepositoryUrl\":\"${ckbReproEscape(manifest.releaseRepositoryUrl)}\"," +
    "\"releaseBranch\":\"${ckbReproEscape(manifest.releaseBranch)}\"," +
    "\"observedRemote\":\"${ckbReproEscape(manifest.observedRemote)}\"," +
    "\"runId\":\"${ckbReproEscape(manifest.runId)}\"," +
    "\"knowledgeVersion\":\"${ckbReproEscape(manifest.knowledgeVersion)}\"," +
    "\"vectorProofHash\":\"${ckbReproEscape(manifest.vectorProofHash)}\"," +
    "\"datasetVersion\":\"${ckbReproEscape(manifest.datasetVersion)}\"," +
    "\"runnerCommit\":\"${ckbReproEscape(manifest.runnerCommit)}\"," +
    "\"claudeCodeVersion\":\"${ckbReproEscape(manifest.claudeCodeVersion)}\"," +
    "\"model\":\"${ckbReproEscape(manifest.model)}\"," +
    "\"modelFingerprint\":\"${ckbReproEscape(manifest.modelFingerprint)}\"," +
    "\"providerFingerprint\":\"${ckbReproEscape(manifest.providerFingerprint)}\"," +
    "\"experimentGroup\":\"${ckbReproEscape(manifest.experimentGroup)}\"," +
    "\"toolTransport\":\"${ckbReproEscape(manifest.toolTransport)}\"," +
    "\"mcpTransport\":\"${ckbReproEscape(manifest.mcpTransport)}\"," +
    "\"ckbRequired\":${manifest.ckbRequired}," +
    "\"localDocsPolicy\":\"${ckbReproEscape(manifest.localDocsPolicy)}\"," +
    "\"modelEffort\":\"${ckbReproEscape(manifest.modelEffort)}\"," +
    "\"modelBudget\":\"${ckbReproEscape(manifest.modelBudget)}\"," +
    "\"timeoutSeconds\":${manifest.timeoutSeconds}," +
    "\"transportRetryBudget\":${manifest.transportRetryBudget}," +
    "\"promptHash\":\"${ckbReproEscape(manifest.promptHash)}\"," +
    "\"resultsHash\":\"${ckbReproEscape(manifest.resultsHash)}\"," +
    "\"runCriticalTreeHash\":\"${ckbReproEscape(manifest.runCriticalTreeHash)}\"" +
    certified + "," +
    "\"totalCases\":${manifest.totalCases},\"rawPassed\":${manifest.rawPassed}," +
    "\"strictPassed\":${manifest.strictPassed},\"strictFailed\":${manifest.strictFailed}," +
    "\"businessFailed\":${manifest.businessFailed},\"protocolInvalid\":${manifest.protocolInvalid}," +
    "\"transportUnresolved\":${manifest.transportUnresolved}," +
    "\"missingEvidence\":${ckbReproStringArrayJson(manifest.missingEvidence)}}"
}

public func runCkbReproManifestVerify(bytes: Array<UInt8>, mode!: String = "execution"): CkbReproContractResult {
    let parsed = parseCkbReproReferenceManifest(bytes)
    if (!parsed[0].ok) { return parsed[0] }
    validateCkbReproReferenceManifest(parsed[1], mode: mode)
}

public func parseCkbHistoricalReferenceEvidence(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbHistoricalReferenceEvidence) {
    let evidence = CkbHistoricalReferenceEvidence()
    let decoded = ckbReproDecode(bytes)
    if (decoded[0] != "ok") { return (ckbReproFailure(decoded[0]), evidence) }
    try {
        let object = JsonValue.fromStr(decoded[1]).asObject()
        if (object.size() != 23) {
            return (ckbReproFailure("historical_evidence_field_contract_invalid"), evidence)
        }
        evidence.schemaVersion = ckbReproString(object, "schemaVersion")
        evidence.referenceCommit = ckbReproString(object, "referenceCommit")
        evidence.modelProfileRole = ckbReproString(object, "modelProfileRole")
        evidence.modelProfileCount = ckbReproInt(object, "modelProfileCount")
        evidence.modelEffort = ckbReproString(object, "modelEffort")
        evidence.maxBudgetUsdState = ckbReproString(object, "maxBudgetUsdState")
        evidence.modelBudgetDerivation = ckbReproString(object, "modelBudgetDerivation")
        evidence.timeoutSeconds = ckbReproInt(object, "timeoutSeconds")
        evidence.promptRole = ckbReproString(object, "promptRole")
        evidence.promptCount = ckbReproInt(object, "promptCount")
        evidence.promptAggregation = ckbReproString(object, "promptAggregation")
        evidence.promptHash = ckbReproString(object, "promptHash")
        evidence.vectorRole = ckbReproString(object, "vectorRole")
        evidence.vectorProofHash = ckbReproString(object, "vectorProofHash")
        evidence.vectorState = ckbReproString(object, "vectorState")
        evidence.vectorTotal = ckbReproInt(object, "vectorTotal")
        evidence.vectorDimension = ckbReproInt(object, "vectorDimension")
        evidence.vectorFailed = ckbReproInt(object, "vectorFailed")
        evidence.runCriticalRole = ckbReproString(object, "runCriticalRole")
        evidence.runCriticalCount = ckbReproInt(object, "runCriticalCount")
        evidence.runCriticalAggregation = ckbReproString(object, "runCriticalAggregation")
        evidence.runCriticalTreeHash = ckbReproString(object, "runCriticalTreeHash")
        for (value in object.get("runCriticalFiles").getOrThrow().asArray().getItems()) {
            let row = value.asObject()
            if (row.size() != 2) {
                return (ckbReproFailure("historical_evidence_field_contract_invalid"),
                    CkbHistoricalReferenceEvidence())
            }
            let file = CkbHistoricalEvidenceFile()
            file.path = ckbReproString(row, "path")
            file.sha256 = ckbReproString(row, "sha256")
            evidence.runCriticalFiles.add(file)
        }
    } catch (_: Exception) {
        return (ckbReproFailure("historical_evidence_field_contract_invalid"),
            CkbHistoricalReferenceEvidence())
    }
    (ckbReproSuccess(), evidence)
}

public func validateCkbHistoricalReferenceEvidence(evidence: CkbHistoricalReferenceEvidence,
    reference: CkbReproReferenceManifest): CkbReproContractResult {
    if (evidence.schemaVersion != "ckb-historical-reference-evidence-v1" ||
        evidence.referenceCommit != reference.runnerCommit ||
        evidence.modelProfileRole != "student_model_transport_profile" ||
        evidence.modelProfileCount != 164 || evidence.modelEffort != "max" ||
        evidence.maxBudgetUsdState != "empty_all_164" ||
        evidence.modelBudgetDerivation != "empty_maxBudgetUsd_means_runner_amount_limit_unset" ||
        evidence.timeoutSeconds != 3600 ||
        evidence.promptRole != "student_final_prompt" || evidence.promptCount != 164 ||
        evidence.promptAggregation != "relative_path_tab_sha256_newline_c_sort" ||
        evidence.vectorRole != "frozen_runtime_vector_reconcile_current" ||
        evidence.vectorState != "ready" || evidence.vectorTotal != 7978 ||
        evidence.vectorDimension != 1024 || evidence.vectorFailed != 0 ||
        evidence.runCriticalRole != "reference_commit_run_critical_sources" ||
        evidence.runCriticalCount != 27 ||
        evidence.runCriticalAggregation != "relative_path_tab_sha256_newline_c_sort") {
        return ckbReproFailure("historical_evidence_identity_mismatch")
    }
    if (evidence.promptHash != "sha256:ead9caab8e06210cf513b2785b4ddd1273ad93d1a790968033309399e779bdba" ||
        evidence.vectorProofHash != "sha256:f22e6110f8d6b8a5562b45ed1cde138e38169455a3cc8b4eb50d4ac02a165808" ||
        evidence.runCriticalTreeHash != computeCkbHistoricalEvidenceTreeHash(evidence) ||
        evidence.runCriticalTreeHash != "sha256:be5aab72f3e477a1d23aa1f3f53c79f701dfaad5dfc361c44ae7b4ba24458fc2") {
        return ckbReproFailure("historical_evidence_hash_mismatch")
    }
    if (reference.evidenceStatus != "complete" || reference.missingEvidence.size != 0 ||
        reference.modelEffort != evidence.modelEffort || reference.modelBudget != "unbounded" ||
        reference.timeoutSeconds != evidence.timeoutSeconds ||
        reference.promptHash != evidence.promptHash ||
        reference.vectorProofHash != evidence.vectorProofHash ||
        reference.runCriticalTreeHash != evidence.runCriticalTreeHash) {
        return ckbReproFailure("historical_evidence_reference_mismatch")
    }
    ckbReproSuccess()
}

public func computeCkbHistoricalEvidenceTreeHash(evidence: CkbHistoricalReferenceEvidence): String {
    if (evidence.runCriticalFiles.size != 27) { return "" }
    let rows = ArrayList<String>()
    let seen = HashSet<String>()
    for (file in evidence.runCriticalFiles) {
        if (!ckbReproSafeRelativeSourcePath(file.path) || !ckbReproHashValid(file.sha256) ||
            seen.contains(file.path)) { return "" }
        seen.add(file.path)
        rows.add("${file.path}\t${file.sha256}\n")
    }
    let ordered = rows.toArray(); sort(ordered)
    let seed = StringBuilder()
    for (row in ordered) { seed.append(row) }
    ckbReproSha256(seed.toString().toArray())
}

public func normalizeCkbReproRepositoryRemote(remote: String): String {
    var value = remote.trimAscii()
    if (value.endsWith(".git")) { value = value[0..value.size - 4] }
    if (value.startsWith("git@github.com:")) { return value["git@github.com:".size..value.size] }
    if (value.startsWith("ssh://git@github.com/")) { return value["ssh://git@github.com/".size..value.size] }
    if (value.startsWith("https://github.com/")) { return value["https://github.com/".size..value.size] }
    ""
}

public func parseCkbPortablePathPolicy(bytes: Array<UInt8>): (CkbReproContractResult, CkbPortablePathPolicy) {
    let policy = CkbPortablePathPolicy()
    let decoded = ckbReproDecode(bytes)
    if (decoded[0] != "ok") { return (ckbReproFailure(decoded[0]), policy) }
    try {
        let object = JsonValue.fromStr(decoded[1]).asObject()
        if (object.size() != 8) { return (ckbReproFailure("path_policy_field_contract_invalid"), policy) }
        policy.schemaVersion = ckbReproString(object, "schemaVersion")
        policy.baselineState = ckbReproString(object, "baselineState")
        policy.unmappedAction = ckbReproString(object, "unmappedAction")
        policy.sourceRootRuleId = ckbReproString(object, "sourceRootRuleId")
        if (!ckbReproStringArray(object, "allowlist", policy.allowlist) ||
            !ckbReproStringArray(object, "placeholders", policy.placeholders) ||
            !ckbReproStringArray(object, "fieldCoverage", policy.fieldCoverage)) {
            return (ckbReproFailure("path_policy_field_contract_invalid"), CkbPortablePathPolicy())
        }
        for (value in object.get("categories").getOrThrow().asArray().getItems()) {
            let row = value.asObject()
            if (row.size() != 2) { return (ckbReproFailure("path_policy_field_contract_invalid"), CkbPortablePathPolicy()) }
            let category = CkbPortablePathCategory()
            category.id = ckbReproString(row, "id")
            category.action = ckbReproString(row, "action")
            policy.categories.add(category)
        }
    } catch (_: Exception) {
        return (ckbReproFailure("path_policy_field_contract_invalid"), CkbPortablePathPolicy())
    }
    (ckbReproSuccess(), policy)
}

public func validateCkbPortablePathPolicy(policy: CkbPortablePathPolicy): CkbReproContractResult {
    if (policy.schemaVersion != "ckb-portable-path-policy-v1" ||
        policy.baselineState != "historicalPrePortableBaseline" ||
        policy.unmappedAction != "fail" || policy.sourceRootRuleId == "" ||
        policy.categories.size != 8) { return ckbReproFailure("path_policy_invalid") }
    let expectedFields = ["sourceId", "sourceUrl", "repo", "path", "derivedFrom",
        "title", "content", "chunk", "citation"]
    for (field in expectedFields) {
        if (!ckbReproContains(policy.fieldCoverage, field)) { return ckbReproFailure("path_policy_field_coverage_incomplete") }
    }
    for (value in policy.allowlist) {
        if (value != "/usr/bin/env" && value != "/dev/null") {
            return ckbReproFailure("path_policy_allowlist_invalid")
        }
    }
    for (value in policy.placeholders) {
        if (!value.startsWith("{{CKB_PATH:") || !value.endsWith("}}")) {
            return ckbReproFailure("path_policy_placeholder_invalid")
        }
    }
    let canonical = renderCkbPortablePathPolicy(policy)
    let result = ckbReproSuccess()
    result.canonicalJson = canonical
    result.manifestHash = ckbReproSha256(canonical.toArray())
    result
}

public func renderCkbPortablePathPolicy(policy: CkbPortablePathPolicy): String {
    let categories = ArrayList<String>()
    for (row in policy.categories) {
        categories.add("${row.id}|${row.action}")
    }
    let ordered = categories.toArray(); sort(ordered)
    var categoryJson = "["
    for (i in 0..ordered.size) {
        if (i > 0) { categoryJson += "," }
        let parts = ordered[i].split("|")
        categoryJson += "{\"id\":\"${ckbReproEscape(parts[0])}\",\"action\":\"${ckbReproEscape(parts[1])}\"}"
    }
    categoryJson += "]"
    "{\"schemaVersion\":\"${ckbReproEscape(policy.schemaVersion)}\"," +
    "\"baselineState\":\"${ckbReproEscape(policy.baselineState)}\"," +
    "\"unmappedAction\":\"${ckbReproEscape(policy.unmappedAction)}\"," +
    "\"sourceRootRuleId\":\"${ckbReproEscape(policy.sourceRootRuleId)}\"," +
    "\"allowlist\":${ckbReproSortedStringArrayJson(policy.allowlist)}," +
    "\"placeholders\":${ckbReproSortedStringArrayJson(policy.placeholders)}," +
    "\"fieldCoverage\":${ckbReproSortedStringArrayJson(policy.fieldCoverage)}," +
    "\"categories\":${categoryJson}}"
}

public func parseCkbRunCriticalFilesManifest(bytes: Array<UInt8>): (CkbReproContractResult, CkbRunCriticalFilesManifest) {
    let manifest = CkbRunCriticalFilesManifest()
    let decoded = ckbReproDecode(bytes)
    if (decoded[0] != "ok") { return (ckbReproFailure(decoded[0]), manifest) }
    try {
        let object = JsonValue.fromStr(decoded[1]).asObject()
        if (object.size() != 2) { return (ckbReproFailure("run_critical_field_contract_invalid"), manifest) }
        manifest.schemaVersion = ckbReproString(object, "schemaVersion")
        for (value in object.get("files").getOrThrow().asArray().getItems()) {
            let row = value.asObject()
            if (row.size() != 3) { return (ckbReproFailure("run_critical_field_contract_invalid"), CkbRunCriticalFilesManifest()) }
            let file = CkbRunCriticalFile()
            file.path = ckbReproString(row, "path")
            file.status = ckbReproString(row, "status")
            file.sha256 = ckbReproString(row, "sha256")
            manifest.files.add(file)
        }
    } catch (_: Exception) {
        return (ckbReproFailure("run_critical_field_contract_invalid"), CkbRunCriticalFilesManifest())
    }
    (ckbReproSuccess(), manifest)
}

public func validateCkbRunCriticalFilesManifest(manifest: CkbRunCriticalFilesManifest,
    repositoryRoot: String, mode!: String = "contract"): CkbReproContractResult {
    if (manifest.schemaVersion != "ckb-run-critical-files-v1" || manifest.files.size == 0) {
        return ckbReproFailure("run_critical_manifest_invalid")
    }
    if (mode != "contract" && mode != "execution") { return ckbReproFailure("run_critical_mode_invalid") }
    let seen = HashSet<String>()
    for (file in manifest.files) {
        if (!ckbReproSafeRelativeSourcePath(file.path)) { return ckbReproFailure("run_critical_path_invalid") }
        if (seen.contains(file.path)) { return ckbReproFailure("run_critical_path_duplicate") }
        seen.add(file.path)
        if (file.status != "planned" && file.status != "present") {
            return ckbReproFailure("run_critical_status_invalid")
        }
        let path = Path(repositoryRoot).join(file.path)
        if (file.status == "planned") {
            if (mode == "execution") { return ckbReproFailure("run_critical_manifest_not_frozen") }
            if (exists(path)) { return ckbReproFailure("run_critical_planned_file_exists") }
        } else {
            if (!exists(path)) { return ckbReproFailure("run_critical_file_missing") }
            if (!ckbReproHashValid(file.sha256)) { return ckbReproFailure("hash_mismatch") }
            let bytes = try { File.readFrom(path) } catch (_: Exception) {
                return ckbReproFailure("run_critical_file_missing")
            }
            if (ckbReproSha256(bytes) != file.sha256) { return ckbReproFailure("hash_mismatch") }
        }
    }
    for (required in [
        "src/main.cj",
        "src/cangjie_eval_abcde_runner.cj",
        "src/cangjie_strict_certification.cj",
        "src/cangjie_eval_knowledge_audit.cj",
        "src/cangjie_certification_control_cli.cj",
        "src/cangjie_certification_preflight.cj",
        "src/cangjie_certification_s4.cj",
        "src/cangjie_completion_context.cj",
        "src/cangjie_humaneval_manifest.cj",
        "src/cangjie_humaneval_pass1_gate.cj",
        "src/cangjie_humaneval_plus_authority.cj",
        "src/cangjie_humaneval_strict_score.cj",
        "src/cangjie_student_agents_rules.cj",
        "src/cangjie_student_context_bundle.cj",
        "src/cangjie_student_skill_gate.cj",
        "src/cangjie_teacher_context_candidate_v2.cj",
        "src/cangjie_first_initialization.cj",
        "src/cangjie_typed_records.cj",
        "src/cangjie_routine_clean_candidate.cj",
        "src/cangjie_release_gate.cj",
        "src/ckb_candidate_runtime_materialize.cj",
        "src/native_http_transport.cj",
        "src/native_tls_bootstrap.cj",
        "src/core.cj",
        "src/services.cj",
        "src/service_api.cj",
        "src/service_http.cj",
        "src/cangjie_serving_query.cj",
        "src/cangjie_serving_index.cj",
        "src/cangjie_serving_client.cj",
        "src/cangjie_retrieval_ranker.cj",
        "src/cangjie_task_knowledge_builder.cj",
        "src/cangjie_capability.cj",
        "src/cangjie_interface_results.cj",
        "src/mcp_protocol.cj",
        "src/mcp_stdio.cj",
        "src/mcp_http.cj",
        "src/ckb_repro_manifest.cj",
        "src/ckb_repro_release.cj",
        "src/ckb_qdrant_snapshot.cj",
        "src/ckb_retrieval_parity.cj",
        "src/ckb_portable_vector_build.cj",
        "src/ckb_repro_build.cj",
        "src/ckb_repro_build_inputs.cj",
        "src/ckb_pinned_source_backend.cj",
        "src/ckb_public_evidence.cj",
        "src/ckb_repro_cli_composition.cj",
        "src/ckb_repro_composition_stage.cj",
        "src/ckb_repro_attestation_authority_writer.cj",
        "src/ckb_repro_cli_typed_assets.cj",
        "src/ckb_repro_cli_runtime_loader.cj",
        "src/ckb_repro_cli_runtime_p3.cj",
        "src/ckb_repro_cli_runtime_p4.cj",
        "src/ckb_repro_cli_runtime_p8_factory.cj",
        "src/ckb_repro_cli_runtime_a.cj",
        "src/ckb_repro_cli_runtime_b.cj",
        "src/ckb_repro_p8_owned_lifecycle.cj",
        "src/ckb_repro_documentation.cj",
        "src/ckb_portable_path_normalizer.cj",
        "src/ckb_repro_bundle.cj",
        "src/ckb_repro_authority_bundle.cj",
        "src/ckb_repro_environment.cj",
        "src/ckb_repro_verify.cj"
    ]) {
        if (!seen.contains(required)) { return ckbReproFailure("run_critical_manifest_incomplete") }
    }
    let canonical = renderCkbRunCriticalFilesManifest(manifest)
    let result = ckbReproSuccess()
    result.canonicalJson = canonical
    result.manifestHash = ckbReproSha256(canonical.toArray())
    for (file in manifest.files) {
        if (file.status == "planned") { result.plannedCount += 1 } else { result.presentCount += 1 }
    }
    if (mode == "execution") { result.treeHash = computeCkbRunCriticalTreeHash(manifest, repositoryRoot) }
    result
}

public func renderCkbRunCriticalFilesManifest(manifest: CkbRunCriticalFilesManifest): String {
    let rows = ArrayList<String>()
    for (file in manifest.files) {
        rows.add("${file.path}|${file.status}|${file.sha256}")
    }
    let ordered = rows.toArray(); sort(ordered)
    var files = "["
    for (i in 0..ordered.size) {
        if (i > 0) { files += "," }
        let parts = ordered[i].split("|")
        files += "{\"path\":\"${ckbReproEscape(parts[0])}\",\"status\":\"${ckbReproEscape(parts[1])}\",\"sha256\":\"${ckbReproEscape(parts[2])}\"}"
    }
    files += "]"
    "{\"schemaVersion\":\"${ckbReproEscape(manifest.schemaVersion)}\",\"files\":${files}}"
}

public func computeCkbRunCriticalTreeHash(manifest: CkbRunCriticalFilesManifest,
    repositoryRoot: String): String {
    let rows = ArrayList<String>()
    for (file in manifest.files) {
        if (file.status != "present") { return "" }
        let path = Path(repositoryRoot).join(file.path)
        let bytes = try { File.readFrom(path) } catch (_: Exception) { return "" }
        rows.add("${file.path}|${ckbReproSha256(bytes)}")
    }
    let ordered = rows.toArray(); sort(ordered)
    let seed = StringBuilder()
    for (row in ordered) { seed.append("${row.toArray().size}:${row}") }
    ckbReproSha256(seed.toString().toArray())
}

private func ckbReproDecode(bytes: Array<UInt8>): (String, String) {
    try { ("ok", String.fromUtf8(bytes)) } catch (_: Exception) { ("invalid_response_encoding", "") }
}

private func ckbReproSuccess(): CkbReproContractResult {
    let result = CkbReproContractResult(); result.ok = true; result.diagnostic = "ok"; result
}

private func ckbReproFailure(diagnostic: String): CkbReproContractResult {
    let result = CkbReproContractResult(); result.diagnostic = diagnostic; result
}

private func ckbReproString(object: JsonObject, key: String): String {
    object.get(key).getOrThrow().asString().getValue()
}

private func ckbReproInt(object: JsonObject, key: String): Int64 {
    object.get(key).getOrThrow().asInt().getValue()
}

private func ckbReproBool(object: JsonObject, key: String): Bool {
    object.get(key).getOrThrow().asBool().getValue()
}

private func ckbReproStringArray(object: JsonObject, key: String, out: ArrayList<String>): Bool {
    try {
        for (value in object.get(key).getOrThrow().asArray().getItems()) {
            out.add(value.asString().getValue())
        }
        true
    } catch (_: Exception) { false }
}

private func ckbReproHashValid(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 71 || !value.startsWith("sha256:")) { return false }
    for (i in 7..71) {
        let r = runes[i]
        if (!((r >= r'0' && r <= r'9') || (r >= r'a' && r <= r'f'))) { return false }
    }
    true
}

private func ckbReproSafeRelativeSourcePath(value: String): Bool {
    if (!value.startsWith("src/") || value.startsWith("/") || value.contains("\\") ||
        value.contains("*") || value.contains("?") || value.contains("[") || value.trimAscii() != value) {
        return false
    }
    for (part in value.split("/")) { if (part == "" || part == "." || part == "..") { return false } }
    value.endsWith(".cj")
}

private func ckbReproContains(values: ArrayList<String>, expected: String): Bool {
    for (value in values) { if (value == expected) { return true } }
    false
}

private func ckbReproStringArrayJson(values: ArrayList<String>): String {
    var out = "["
    for (i in 0..values.size) {
        if (i > 0) { out += "," }
        out += "\"${ckbReproEscape(values[i])}\""
    }
    out + "]"
}

private func ckbReproSortedStringArrayJson(values: ArrayList<String>): String {
    let ordered = values.toArray(); sort(ordered)
    let copy = ArrayList<String>(); for (value in ordered) { copy.add(value) }
    ckbReproStringArrayJson(copy)
}

private func ckbReproEscape(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")
        .replace("\r", "\\r").replace("\t", "\\t")
}

private func ckbReproSha256(bytes: Array<UInt8>): String {
    let digest = SHA256(); digest.write(bytes); let out = StringBuilder()
    for (byte in digest.finish()) {
        out.append(ckbReproNibble(byte / UInt8(16)))
        out.append(ckbReproNibble(byte % UInt8(16)))
    }
    "sha256:${out.toString()}"
}

private func ckbReproNibble(value: UInt8): String {
    if(value==UInt8(0)){return "0"};if(value==UInt8(1)){return "1"};if(value==UInt8(2)){return "2"};if(value==UInt8(3)){return "3"};if(value==UInt8(4)){return "4"};if(value==UInt8(5)){return "5"};if(value==UInt8(6)){return "6"};if(value==UInt8(7)){return "7"};if(value==UInt8(8)){return "8"};if(value==UInt8(9)){return "9"};if(value==UInt8(10)){return "a"};if(value==UInt8(11)){return "b"};if(value==UInt8(12)){return "c"};if(value==UInt8(13)){return "d"};if(value==UInt8(14)){return "e"};"f"
}
