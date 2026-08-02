package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashSet}
import std.fs.{Path, canonicalize, exists}
import std.sort.*
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

public class CkbPortableLocalRoot {
    public var sourceId: String = ""
    public var kind: String = ""
    public var localRoot: String = ""
    public init() {}
}

public class CkbPortablePathRule {
    public var id: String = ""
    public var category: String = ""
    public var action: String = ""
    public init() {}
}

public class CkbPortableLocalRootMap {
    public var schemaVersion: String = ""
    public var roots: ArrayList<CkbPortableLocalRoot> = ArrayList<CkbPortableLocalRoot>()
    public init() {}
}

public class CkbPortablePathContext {
    public var policy: CkbPortablePathPolicy = CkbPortablePathPolicy()
    public var localRoots: CkbPortableLocalRootMap = CkbPortableLocalRootMap()
    public var apiRoutes: ArrayList<String> = ArrayList<String>()
    public init() {}
}

public class CkbPortablePathResult {
    public var ok: Bool = false
    public var diagnostic: String = "not_classified"
    public var value: String = ""
    public var category: String = ""
    public var ruleId: String = ""
    public var changed: Bool = false
    public init() {}
}

public class CkbPortablePathFinding {
    public var sourceId: String = ""
    public var field: String = ""
    public var category: String = ""
    public var ruleId: String = ""
    // This value is process-private and must only be consumed by an injected HMAC provider.
    public var privateValue: String = ""
    public init() {}
}

public class CkbPortableTextResult {
    public var ok: Bool = true
    public var diagnostic: String = "ok"
    public var value: String = ""
    public var changedCount: Int64 = 0
    public var findings: ArrayList<CkbPortablePathFinding> = ArrayList<CkbPortablePathFinding>()
    public init() {}
}

public class CkbPortableTypedRecordResult {
    public var ok: Bool = false
    public var diagnostic: String = "not_normalized"
    public var changedCount: Int64 = 0
    public var record: CangjieTypedRecord = CangjieTypedRecord()
    public var findings: ArrayList<CkbPortablePathFinding> = ArrayList<CkbPortablePathFinding>()
    public init() {}
}

public class CkbPortableRawRecordResult {
    public var ok: Bool = false
    public var diagnostic: String = "not_normalized"
    public var changedCount: Int64 = 0
    public var record: RawRecord = RawRecord()
    public var findings: ArrayList<CkbPortablePathFinding> = ArrayList<CkbPortablePathFinding>()
    public init() {}
}

public class CkbPortablePathScanReport {
    public var ready: Bool = true
    public var diagnostic: String = "ok"
    public var scannedFieldCount: Int64 = 0
    public var machinePathCount: Int64 = 0
    public var unmappedCount: Int64 = 0
    public var findings: ArrayList<CkbPortablePathFinding> = ArrayList<CkbPortablePathFinding>()
    public init() {}
}

public class CkbStudentVisiblePathInput {
    public var rawRecords: ArrayList<RawRecord> = ArrayList<RawRecord>()
    public var normalizedRecords: ArrayList<NormalizedRecord> = ArrayList<NormalizedRecord>()
    public var activeRecords: ArrayList<NormalizedRecord> = ArrayList<NormalizedRecord>()
    public var vectorRecords: ArrayList<VectorRecord> = ArrayList<VectorRecord>()
    public var graph: GraphBuildResult = GraphBuildResult()
    public var transportPayloads: ArrayList<String> = ArrayList<String>()
    public init() {}
}

public interface CkbPortablePathHmacProvider {
    func recordId(value: String): String
}

public class CkbHmacSha256PathIdProvider <: CkbPortablePathHmacProvider {
    private let key: Array<UInt8>

    public init(key: Array<UInt8>) {
        let copy = ArrayList<UInt8>()
        for (byte in key) { copy.add(byte) }
        this.key = copy.toArray()
    }

    public func recordId(value: String): String {
        if (this.key.size == 0) { return "" }
        "hsha256:${ckbPortableHex(ckbPortableHmacSha256(this.key, value.toArray()))}"
    }
}

public class CkbPortableRecordPreservationProof {
    public var ready: Bool = false
    public var diagnostic: String = "record_count_mismatch"
    public var typedInputCount: Int64 = 0
    public var typedOutputCount: Int64 = 0
    public var rawInputCount: Int64 = 0
    public var rawOutputCount: Int64 = 0
    public var typedInputHash: String = ""
    public var typedOutputHash: String = ""
    public var rawInputHash: String = ""
    public var rawOutputHash: String = ""
    // Pair aggregates are private migration evidence and must not enter public reports.
    public var typedPairCount: Int64 = 0
    public var rawPairCount: Int64 = 0
    public var typedPairAggregateHash: String = ""
    public var rawPairAggregateHash: String = ""
    public init() {}
}

public func parseCkbPortableLocalRootMap(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbPortableLocalRootMap) {
    let map = CkbPortableLocalRootMap()
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (ckbPortableContractFailure("invalid_response_encoding"), map)
    }
    try {
        let object = JsonValue.fromStr(text).asObject()
        if (object.size() != 2) {
            return (ckbPortableContractFailure("portable_local_root_map_field_contract_invalid"), map)
        }
        map.schemaVersion = object.get("schemaVersion").getOrThrow().asString().getValue()
        for (value in object.get("roots").getOrThrow().asArray().getItems()) {
            let row = value.asObject()
            if (row.size() != 3) {
                return (ckbPortableContractFailure("portable_local_root_map_field_contract_invalid"),
                    CkbPortableLocalRootMap())
            }
            let root = CkbPortableLocalRoot()
            root.sourceId = row.get("sourceId").getOrThrow().asString().getValue()
            root.kind = row.get("kind").getOrThrow().asString().getValue()
            root.localRoot = row.get("localRoot").getOrThrow().asString().getValue()
            map.roots.add(root)
        }
    } catch (_: Exception) {
        return (ckbPortableContractFailure("portable_local_root_map_field_contract_invalid"),
            CkbPortableLocalRootMap())
    }
    (ckbPortableContractSuccess(), map)
}

public func validateCkbPortableLocalRootMap(map: CkbPortableLocalRootMap,
    allowedSourceIds: Array<String>): CkbReproContractResult {
    if (map.schemaVersion != "ckb-portable-local-root-map-v1" || map.roots.size == 0) {
        return ckbPortableContractFailure("portable_local_root_map_invalid")
    }
    let allowed = HashSet<String>(allowedSourceIds)
    let seen = HashSet<String>()
    for (root in map.roots) {
        if (!allowed.contains(root.sourceId) || !ckbPortableRootKind(root.kind) ||
            root.localRoot.trimAscii() != root.localRoot || !exists(Path(root.localRoot))) {
            return ckbPortableContractFailure("portable_local_root_invalid")
        }
        let canonical = try { canonicalize(Path(root.localRoot)).toString() } catch (_: Exception) {
            return ckbPortableContractFailure("portable_local_root_invalid")
        }
        if (canonical != root.localRoot || !Path(canonical).isAbsolute()) {
            return ckbPortableContractFailure("portable_local_root_not_canonical")
        }
        let identity = "${root.sourceId}|${root.kind}|${canonical}"
        if (seen.contains(identity)) {
            return ckbPortableContractFailure("portable_local_root_duplicate")
        }
        seen.add(identity)
    }
    for (i in 0..map.roots.size) {
        for (j in i + 1..map.roots.size) {
            if (ckbPortablePathBoundaryPrefix(map.roots[i].localRoot, map.roots[j].localRoot) ||
                ckbPortablePathBoundaryPrefix(map.roots[j].localRoot, map.roots[i].localRoot)) {
                return ckbPortableContractFailure("portable_local_roots_overlap")
            }
        }
    }
    ckbPortableContractSuccess()
}

public func validateCkbPortablePathPolicyForBuild(
    policy: CkbPortablePathPolicy): CkbReproContractResult {
    let base = validateCkbPortablePathPolicy(policy)
    if (!base.ok) { return base }
    if (policy.sourceRootRuleId != "source-lock-repository-commit-tree-relative-v1") {
        return ckbPortableContractFailure("path_policy_source_root_rule_invalid")
    }
    if (!ckbPortableExactStrings(policy.allowlist, ["/usr/bin/env", "/dev/null"])) {
        return ckbPortableContractFailure("path_policy_allowlist_invalid")
    }
    if (!ckbPortableExactStrings(policy.placeholders, [
        "{{CKB_PATH:PROJECT_ROOT}}", "{{CKB_PATH:SOURCE_ROOT}}",
        "{{CKB_PATH:USER_HOME}}", "{{CKB_PATH:SDK_ROOT}}",
        "{{CKB_PATH:INSTALL_ROOT}}", "{{CKB_PATH:BUILD_ROOT}}",
        "{{CKB_PATH:TMPDIR}}", "{{CKB_PATH:ABSOLUTE}}"
    ])) {
        return ckbPortableContractFailure("path_policy_placeholder_invalid")
    }
    let expected = [
        "source_locator|source_lock_relative",
        "declared_project_root|placeholder",
        "user_home|placeholder",
        "sdk_install_build_tmp|explicit_root_placeholder",
        "runtime_state|exclude",
        "non_filesystem_slash_text|preserve",
        "absolute_path_semantics_example|semantic_placeholder",
        "unmapped|fail"
    ]
    let actual = ArrayList<String>()
    for (category in policy.categories) {
        actual.add("${category.id}|${category.action}")
    }
    if (!ckbPortableExactStrings(actual, expected)) {
        return ckbPortableContractFailure("path_policy_categories_invalid")
    }
    ckbPortableContractSuccess()
}

public func buildCkbPortablePathRules(
    policy: CkbPortablePathPolicy): ArrayList<CkbPortablePathRule> {
    let rules = ArrayList<CkbPortablePathRule>()
    for (category in policy.categories) {
        let rule = CkbPortablePathRule()
        rule.id = "portable_${category.id}"
        rule.category = category.id
        rule.action = category.action
        rules.add(rule)
    }
    rules
}

public func validateCkbPortablePathContext(
    context: CkbPortablePathContext): CkbReproContractResult {
    let policy = validateCkbPortablePathPolicyForBuild(context.policy)
    if (!policy.ok) { return policy }
    if (context.localRoots.schemaVersion != "ckb-portable-local-root-map-v1" ||
        context.localRoots.roots.size == 0) {
        return ckbPortableContractFailure("portable_local_root_map_invalid")
    }
    for (route in context.apiRoutes) {
        if (!route.startsWith("/") || route.contains("..") ||
            route.contains("\\") || route.trimAscii() != route) {
            return ckbPortableContractFailure("portable_api_route_invalid")
        }
    }
    ckbPortableContractSuccess()
}

public func classifyCkbPathOccurrence(value: String, field: String, sourceId: String,
    context: CkbPortablePathContext): CkbPortablePathResult {
    let result = CkbPortablePathResult()
    result.value = value
    if (value == "") { return ckbPortableClassified(result, "non_filesystem_slash_text", "empty", value) }
    if (value.contains("{{CKB_PATH:")) {
        return ckbPortableClassified(result, "non_filesystem_slash_text", "portable_placeholder", value)
    }
    if (ckbPortableNetworkLocator(value) || ckbPortableApiRoute(value, context) ||
        ckbPortableRelativeText(value)) {
        return ckbPortableClassified(result, "non_filesystem_slash_text", "preserve_non_filesystem", value)
    }
    for (allowed in context.policy.allowlist) {
        if (value == allowed) {
            return ckbPortableClassified(result, "non_filesystem_slash_text", "absolute_allowlist", value)
        }
    }
    for (root in context.localRoots.roots) {
        let offset = ckbPortableIndexOf(value, root.localRoot)
        if (offset >= 0) {
            let end = offset + root.localRoot.size
            if (end == value.size || ckbPortablePathSeparator(value, end)) {
                let suffix = value[end..value.size]
                let placeholder = "{{CKB_PATH:${root.kind}}}"
                let mapped = value[0..offset] + placeholder + suffix
                let category = if (root.kind == "PROJECT_ROOT" || root.kind == "SOURCE_ROOT") {
                    "declared_project_root"
                } else { "sdk_install_build_tmp" }
                return ckbPortableClassified(result, category,
                    "local_root_${root.kind.toAsciiLower()}", mapped)
            }
        }
    }
    let home = ckbPortableHomePath(value)
    if (home[0] == "ok") {
        return ckbPortableClassified(result, "user_home", "portable_user_home", home[1])
    }
    let temporary = ckbPortableTemporaryPath(value)
    if (temporary[0] == "ok") {
        return ckbPortableClassified(result, "sdk_install_build_tmp", "portable_tmpdir", temporary[1])
    }
    if (ckbPortableRuntimeStatePath(value)) {
        result.diagnostic = "runtime_state_path_not_knowledge"
        result.category = "runtime_state"
        result.ruleId = "exclude_runtime_state"
        return result
    }
    if (ckbPortableAbsolutePath(value)) {
        if (ckbPortableLocatorField(field)) {
            result.diagnostic = "unmapped_absolute_path"
            result.category = "unmapped"
            result.ruleId = "unmapped_source_locator"
            return result
        }
        return ckbPortableClassified(result, "absolute_path_semantics_example",
            "portable_absolute_semantics", ckbPortableAbsolutePlaceholder(value))
    }
    ckbPortableClassified(result, "non_filesystem_slash_text", "preserve_plain_text", value)
}

public func normalizeCkbKnowledgeText(value: String, field: String, sourceId: String,
    context: CkbPortablePathContext): CkbPortableTextResult {
    let result = CkbPortableTextResult()
    let runes = value.toRuneArray()
    let out = StringBuilder()
    var token = StringBuilder()
    for (rune in runes) {
        if (ckbPortableTokenDelimiter(rune)) {
            ckbPortableFlushToken(result, token.toString(), field, sourceId, context, out)
            token = StringBuilder()
            out.append(rune)
        } else {
            token.append(rune)
        }
    }
    ckbPortableFlushToken(result, token.toString(), field, sourceId, context, out)
    result.value = out.toString()
    if (!result.ok && result.diagnostic == "ok") { result.diagnostic = "unmapped_absolute_path" }
    result
}

public func normalizeCkbMetadataLocator(value: String, field: String, sourceId: String,
    context: CkbPortablePathContext): CkbPortablePathResult {
    let classified = classifyCkbPathOccurrence(value, field, sourceId, context)
    if (!classified.ok || value == "") { return classified }
    if (field == "repo" && classified.changed) {
        let failed = CkbPortablePathResult()
        failed.value = value; failed.category = "unmapped"; failed.ruleId = "unmapped_repository"
        failed.diagnostic = "unmapped_absolute_path"
        return failed
    }
    if (field == "path") {
        for (root in context.localRoots.roots) {
            if (value == root.localRoot || value.startsWith(root.localRoot + "/")) {
                let suffix = value[root.localRoot.size..value.size]
                return ckbPortableClassified(CkbPortablePathResult(), "source_locator",
                    "source_lock_relative", ckbPortableTrimLeadingSlash(suffix))
            }
        }
        if (ckbPortableSafeRelativePath(value)) {
            return ckbPortableClassified(CkbPortablePathResult(), "non_filesystem_slash_text",
                "relative_locator", value)
        }
        let failed = CkbPortablePathResult()
        failed.value = value; failed.category = "unmapped"; failed.ruleId = "unmapped_source_locator"
        failed.diagnostic = "unmapped_absolute_path"
        return failed
    }
    if (field == "sourceUrl" || field == "derivedFrom") {
        for (root in context.localRoots.roots) {
            let offset = ckbPortableIndexOf(value, root.localRoot)
            if (offset >= 0) {
                let suffix = ckbPortableTrimLeadingSlash(
                    value[offset + root.localRoot.size..value.size])
                return ckbPortableClassified(CkbPortablePathResult(), "source_locator",
                    "source_lock_portable_locator", "ckb-source://${root.sourceId}/${suffix}")
            }
        }
    }
    classified
}

public func scanCkbTypedRecordPathOccurrences(record: CangjieTypedRecord,
    context: CkbPortablePathContext): CkbPortablePathScanReport {
    let report = CkbPortablePathScanReport()
    ckbPortableScanFields(report, [
        "sourceId", "title", "content", "citation", "sourceSet", "sourceFamily",
        "path", "heading", "sectionId", "symbol", "toolName", "command", "caseId",
        "versionResolutionId", "targetVersion", "sourceRef", "refKind",
        "resolvedCommit", "trustLevel", "reviewState", "diagnostic"
    ], [
        record.sourceId, record.title, record.content, record.citation, record.sourceSet,
        record.sourceFamily, record.path, record.heading, record.sectionId, record.symbol,
        record.toolName, record.command, record.caseId, record.versionResolutionId,
        record.targetVersion, record.sourceRef, record.refKind, record.resolvedCommit,
        record.trustLevel, record.reviewState, record.diagnostic
    ], record.sourceId, context)
    ckbPortableFinalizeScan(report)
}

public func scanCkbRawPathOccurrences(record: RawRecord,
    context: CkbPortablePathContext): CkbPortablePathScanReport {
    let report = CkbPortablePathScanReport()
    ckbPortableScanFields(report, [
        "sourceId", "title", "content", "metadata.sourceId", "metadata.sourceUrl",
        "metadata.repo", "metadata.path", "metadata.symbol", "metadata.commit",
        "metadata.docVersion", "metadata.targetVersion", "metadata.sourceSet",
        "metadata.versionResolutionId", "metadata.crawlAt", "metadata.indexedAt",
        "metadata.knowledgeVersion", "metadata.candidateVersion", "metadata.trustLevel",
        "metadata.reviewState", "metadata.license", "metadata.repoVisibility"
    ], [
        record.sourceId, record.title, record.content, record.metadata.sourceId,
        record.metadata.sourceUrl, record.metadata.repo, record.metadata.path,
        record.metadata.symbol, record.metadata.commit, record.metadata.docVersion,
        record.metadata.targetVersion, record.metadata.sourceSet,
        record.metadata.versionResolutionId, record.metadata.crawlAt,
        record.metadata.indexedAt, record.metadata.knowledgeVersion,
        record.metadata.candidateVersion, record.metadata.trustLevel,
        record.metadata.reviewState, record.metadata.license, record.metadata.repoVisibility
    ], record.sourceId, context)
    for (value in record.metadata.derivedFrom) {
        ckbPortableScanText(report, value, "metadata.derivedFrom", record.sourceId, context)
    }
    ckbPortableFinalizeScan(report)
}

public func normalizeCkbTypedRecordPortablePaths(record: CangjieTypedRecord,
    context: CkbPortablePathContext): CkbPortableTypedRecordResult {
    let result = CkbPortableTypedRecordResult()
    let copy = ckbPortableCopyTyped(record)
    let source = normalizeCkbKnowledgeText(copy.sourceId, "sourceId", copy.sourceId, context)
    let title = normalizeCkbKnowledgeText(copy.title, "title", copy.sourceId, context)
    let content = normalizeCkbKnowledgeText(copy.content, "content", copy.sourceId, context)
    let citation = normalizeCkbKnowledgeText(copy.citation, "citation", copy.sourceId, context)
    let path = normalizeCkbMetadataLocator(copy.path, "path", copy.sourceId, context)
    let sourceRef = normalizeCkbKnowledgeText(copy.sourceRef, "sourceRef", copy.sourceId, context)
    let commit = normalizeCkbKnowledgeText(copy.resolvedCommit, "resolvedCommit", copy.sourceId, context)
    for (text in [source, title, content, citation, sourceRef, commit]) {
        ckbPortableAddFindings(result.findings, text.findings)
        result.changedCount += text.changedCount
        if (!text.ok && result.diagnostic == "not_normalized") {
            result.diagnostic = text.diagnostic
        }
    }
    if (!path.ok && copy.path != "") { result.diagnostic = path.diagnostic }
    if ((!source.ok || !title.ok || !content.ok || !citation.ok || !sourceRef.ok ||
        !commit.ok) || (!path.ok && copy.path != "")) {
        result.record = copy
        return result
    }
    copy.sourceId = source.value; copy.title = title.value; copy.content = content.value
    copy.citation = citation.value; copy.path = path.value; copy.sourceRef = sourceRef.value
    copy.resolvedCommit = commit.value
    if (path.changed) { result.changedCount += 1 }
    let extras = [
        normalizeCkbKnowledgeText(copy.sourceSet, "sourceSet", copy.sourceId, context),
        normalizeCkbKnowledgeText(copy.sourceFamily, "sourceFamily", copy.sourceId, context),
        normalizeCkbKnowledgeText(copy.heading, "heading", copy.sourceId, context),
        normalizeCkbKnowledgeText(copy.sectionId, "sectionId", copy.sourceId, context),
        normalizeCkbKnowledgeText(copy.symbol, "symbol", copy.sourceId, context),
        normalizeCkbKnowledgeText(copy.toolName, "toolName", copy.sourceId, context),
        normalizeCkbKnowledgeText(copy.command, "command", copy.sourceId, context),
        normalizeCkbKnowledgeText(copy.caseId, "caseId", copy.sourceId, context),
        normalizeCkbKnowledgeText(copy.versionResolutionId, "versionResolutionId", copy.sourceId, context),
        normalizeCkbKnowledgeText(copy.targetVersion, "targetVersion", copy.sourceId, context),
        normalizeCkbKnowledgeText(copy.refKind, "refKind", copy.sourceId, context),
        normalizeCkbKnowledgeText(copy.trustLevel, "trustLevel", copy.sourceId, context),
        normalizeCkbKnowledgeText(copy.reviewState, "reviewState", copy.sourceId, context),
        normalizeCkbKnowledgeText(copy.diagnostic, "diagnostic", copy.sourceId, context)
    ]
    for (text in extras) {
        ckbPortableAddFindings(result.findings, text.findings)
        result.changedCount += text.changedCount
        if (!text.ok) {
            result.diagnostic = text.diagnostic; result.record = copy
            return result
        }
    }
    copy.sourceSet = extras[0].value; copy.sourceFamily = extras[1].value
    copy.heading = extras[2].value; copy.sectionId = extras[3].value
    copy.symbol = extras[4].value; copy.toolName = extras[5].value
    copy.command = extras[6].value; copy.caseId = extras[7].value
    copy.versionResolutionId = extras[8].value
    copy.targetVersion = extras[9].value; copy.refKind = extras[10].value
    copy.trustLevel = extras[11].value; copy.reviewState = extras[12].value
    copy.diagnostic = extras[13].value
    copy.contentHash = cangjieTypedRecordContentHash(copy.sourceId, copy.content)
    let validation = validateCkbPortableTypedRecord(copy, context)
    if (!validation.ok) { result.diagnostic = validation.diagnostic; result.record = copy; return result }
    result.record = copy; result.ok = true; result.diagnostic = "ok"
    result
}

public func normalizeCkbRawRecordPortablePaths(record: RawRecord,
    context: CkbPortablePathContext): CkbPortableRawRecordResult {
    let result = CkbPortableRawRecordResult()
    let copy = RawRecord()
    copy.sourceId = record.sourceId; copy.title = record.title; copy.content = record.content
    copy.contentHash = record.contentHash; copy.requiresReview = record.requiresReview
    copy.metadata = cangjieCopyKnowledgeMetadata(record.metadata)
    let source = normalizeCkbKnowledgeText(copy.sourceId, "sourceId", copy.sourceId, context)
    let title = normalizeCkbKnowledgeText(copy.title, "title", copy.sourceId, context)
    let content = normalizeCkbKnowledgeText(copy.content, "content", copy.sourceId, context)
    if (!source.ok || !title.ok || !content.ok) {
        result.diagnostic = if (!source.ok) { source.diagnostic }
            else if (!title.ok) { title.diagnostic } else { content.diagnostic }
        result.record = copy; return result
    }
    copy.sourceId = source.value; copy.title = title.value; copy.content = content.value
    copy.metadata.sourceId = copy.sourceId
    result.changedCount = source.changedCount + title.changedCount + content.changedCount
    ckbPortableAddFindings(result.findings, source.findings)
    ckbPortableAddFindings(result.findings, title.findings)
    ckbPortableAddFindings(result.findings, content.findings)
    let metadata = ckbPortableNormalizeMetadata(copy.metadata, copy.sourceId, context)
    if (!metadata[0].ok) { result.diagnostic = metadata[0].diagnostic; result.record = copy; return result }
    copy.metadata = metadata[1]
    copy.metadata.contentSize = copy.content.size
    copy.contentHash = cangjieTypedRecordContentHash(copy.sourceId, copy.content)
    let validation = validateCkbPortableMetadata(copy.metadata, context)
    if (!validation.ok) { result.diagnostic = validation.diagnostic; result.record = copy; return result }
    result.record = copy; result.ok = true; result.diagnostic = "ok"
    result
}

public func validateCkbPortableTypedRecord(record: CangjieTypedRecord,
    context: CkbPortablePathContext): CkbReproContractResult {
    let scan = scanCkbTypedRecordPathOccurrences(record, context)
    if (!scan.ready) { return ckbPortableContractFailure(scan.diagnostic) }
    if (record.contentHash != cangjieTypedRecordContentHash(record.sourceId, record.content)) {
        return ckbPortableContractFailure("portable_typed_content_hash_mismatch")
    }
    ckbPortableContractSuccess()
}

public func validateCkbPortableMetadata(metadata: KnowledgeMetadata,
    context: CkbPortablePathContext): CkbReproContractResult {
    if (metadata.path != "" && !ckbPortableSafeRelativePath(metadata.path)) {
        return ckbPortableContractFailure("unmapped_absolute_path")
    }
    if (metadata.sourceUrl != "" && !metadata.sourceUrl.startsWith("http://") &&
        !metadata.sourceUrl.startsWith("https://") &&
        !metadata.sourceUrl.startsWith("ckb-source://")) {
        return ckbPortableContractFailure("portable_source_url_invalid")
    }
    if (metadata.repo.contains("{{CKB_PATH:") || ckbPortableAbsolutePath(metadata.repo)) {
        return ckbPortableContractFailure("portable_repository_invalid")
    }
    for (value in metadata.derivedFrom) {
        if (ckbPortableAbsolutePath(value) || value.contains("{{CKB_PATH:")) {
            return ckbPortableContractFailure("portable_derived_from_invalid")
        }
    }
    ckbPortableContractSuccess()
}

public func scanCkbStudentVisiblePaths(input: CkbStudentVisiblePathInput,
    context: CkbPortablePathContext): CkbPortablePathScanReport {
    let report = CkbPortablePathScanReport()
    for (record in input.rawRecords) {
        ckbPortableMergeScan(report, scanCkbRawPathOccurrences(record, context))
    }
    for (record in input.normalizedRecords) { ckbPortableScanNormalized(report, record, context) }
    for (record in input.activeRecords) { ckbPortableScanNormalized(report, record, context) }
    for (record in input.vectorRecords) {
        ckbPortableScanText(report, record.id, "vector.id", record.id, context)
        ckbPortableScanText(report, record.pointId, "vector.pointId", record.id, context)
        ckbPortableScanText(report, record.title, "vector.title", record.id, context)
        ckbPortableScanText(report, record.chunk, "vector.chunk", record.id, context)
        ckbPortableScanText(report, record.citation, "vector.citation", record.id, context)
        ckbPortableScanMetadata(report, record.metadata, record.id, context)
    }
    for (node in input.graph.nodes) {
        ckbPortableScanText(report, node.nodeId, "graph.nodeId", node.sourceId, context)
        ckbPortableScanText(report, node.label, "graph.label", node.sourceId, context)
        ckbPortableScanText(report, node.sourceId, "graph.sourceId", node.sourceId, context)
    }
    for (edge in input.graph.edges) {
        ckbPortableScanText(report, edge.edgeId, "graph.edgeId", edge.sourceId, context)
        ckbPortableScanText(report, edge.fromNodeId, "graph.fromNodeId", edge.sourceId, context)
        ckbPortableScanText(report, edge.toNodeId, "graph.toNodeId", edge.sourceId, context)
        ckbPortableScanText(report, edge.sourceId, "graph.sourceId", edge.sourceId, context)
    }
    for (payload in input.transportPayloads) {
        ckbPortableScanText(report, payload, "transport.payload", "transport", context)
    }
    report.ready = report.machinePathCount == 0 && report.unmappedCount == 0
    if (!report.ready && report.diagnostic == "ok") { report.diagnostic = "student_visible_path_finding" }
    report
}

public func buildCkbPortablePathPrivateReport(report: CkbPortablePathScanReport,
    provider: CkbPortablePathHmacProvider): String {
    let rows = ArrayList<String>()
    for (finding in report.findings) {
        let id = provider.recordId(finding.privateValue)
        if (!id.startsWith("hsha256:")) { return "{\"ready\":false,\"diagnostic\":\"hmac_provider_invalid\"}" }
        rows.add("${finding.sourceId}|${finding.field}|${finding.category}|${finding.ruleId}|${id}")
    }
    let ordered = rows.toArray(); sort(ordered)
    var out = "{\"ready\":${report.ready},\"unmappedCount\":${report.unmappedCount},\"findings\":["
    for (i in 0..ordered.size) {
        if (i > 0) { out += "," }
        let parts = ordered[i].split("|")
        out += "{\"sourceId\":\"${ckbPortableJson(parts[0])}\",\"field\":\"${ckbPortableJson(parts[1])}\"," +
            "\"category\":\"${ckbPortableJson(parts[2])}\",\"ruleId\":\"${ckbPortableJson(parts[3])}\"," +
            "\"recordId\":\"${parts[4]}\"}"
    }
    out + "]}"
}

public func buildCkbPortablePathPublicReport(report: CkbPortablePathScanReport): String {
    let rows = ArrayList<String>()
    for (finding in report.findings) {
        rows.add("${finding.sourceId}|${finding.field}|${finding.category}|${finding.ruleId}")
    }
    let ordered = rows.toArray(); sort(ordered)
    var out = "{\"ready\":${report.ready},\"scannedFieldCount\":${report.scannedFieldCount}," +
        "\"machinePathCount\":${report.machinePathCount},\"unmappedCount\":${report.unmappedCount}," +
        "\"findings\":["
    for (i in 0..ordered.size) {
        if (i > 0) { out += "," }
        let parts = ordered[i].split("|")
        out += "{\"sourceId\":\"${ckbPortableJson(parts[0])}\",\"field\":\"${ckbPortableJson(parts[1])}\"," +
            "\"category\":\"${ckbPortableJson(parts[2])}\",\"ruleId\":\"${ckbPortableJson(parts[3])}\"}"
    }
    out + "]}"
}

public func canonicalCkbPortableTypedRecord(record: CangjieTypedRecord): String {
    ckbPortableCanonicalFields([
        record.recordKind, record.sourceId, record.title, record.content, record.citation,
        record.sourceSet, record.sourceFamily, record.path, record.heading, record.sectionId,
        record.symbol, record.toolName, record.command, record.caseId, record.contentHash,
        record.versionResolutionId, record.targetVersion, record.sourceRef, record.refKind,
        record.resolvedCommit, record.trustLevel, record.reviewState, record.diagnostic
    ])
}

public func canonicalCkbPortableRawRecord(record: RawRecord): String {
    let fields = ArrayList<String>()
    for (value in [record.sourceId, record.title, record.content, record.contentHash,
        "${record.requiresReview}", ckbPortableCanonicalMetadata(record.metadata)]) {
        fields.add(value)
    }
    ckbPortableCanonicalFields(fields.toArray())
}

public func buildCkbPortableRecordPreservationProof(
    typedInput: Array<CangjieTypedRecord>, typedOutput: Array<CangjieTypedRecord>,
    rawInput: Array<RawRecord>, rawOutput: Array<RawRecord>,
    context: CkbPortablePathContext): CkbPortableRecordPreservationProof {
    let proof = CkbPortableRecordPreservationProof()
    proof.typedInputCount = typedInput.size; proof.typedOutputCount = typedOutput.size
    proof.rawInputCount = rawInput.size; proof.rawOutputCount = rawOutput.size
    proof.typedInputHash = ckbPortableTypedCollectionHash(typedInput)
    proof.typedOutputHash = ckbPortableTypedCollectionHash(typedOutput)
    proof.rawInputHash = ckbPortableRawCollectionHash(rawInput)
    proof.rawOutputHash = ckbPortableRawCollectionHash(rawOutput)
    if (proof.typedInputCount != proof.typedOutputCount ||
        proof.rawInputCount != proof.rawOutputCount) {
        return proof
    }
    let typedMapping = ckbPortableExpectedTypedMapping(typedInput, context)
    if (!typedMapping[0].ok) {
        proof.diagnostic = typedMapping[0].diagnostic
        return proof
    }
    proof.typedPairCount = typedMapping[2].size
    proof.typedPairAggregateHash = ckbPortableCollectionHash(typedMapping[2])
    if (!ckbPortableExactStrings(
        typedMapping[1], ckbPortableTypedCanonicalRows(typedOutput).toArray())) {
        proof.diagnostic = "typed_record_mapping_mismatch"
        return proof
    }
    let rawMapping = ckbPortableExpectedRawMapping(rawInput, context)
    if (!rawMapping[0].ok) {
        proof.diagnostic = rawMapping[0].diagnostic
        return proof
    }
    proof.rawPairCount = rawMapping[2].size
    proof.rawPairAggregateHash = ckbPortableCollectionHash(rawMapping[2])
    if (!ckbPortableExactStrings(
        rawMapping[1], ckbPortableRawCanonicalRows(rawOutput).toArray())) {
        proof.diagnostic = "raw_record_mapping_mismatch"
        return proof
    }
    proof.ready = true
    proof.diagnostic = "ok"
    proof
}

private func ckbPortableNormalizeMetadata(metadata: KnowledgeMetadata, sourceId: String,
    context: CkbPortablePathContext): (CkbReproContractResult, KnowledgeMetadata) {
    let copy = cangjieCopyKnowledgeMetadata(metadata)
    copy.sourceId = sourceId
    let sourceUrl = normalizeCkbMetadataLocator(copy.sourceUrl, "sourceUrl", sourceId, context)
    let repo = normalizeCkbMetadataLocator(copy.repo, "repo", sourceId, context)
    let path = normalizeCkbMetadataLocator(copy.path, "path", sourceId, context)
    if ((!sourceUrl.ok && copy.sourceUrl != "") || (!repo.ok && copy.repo != "") ||
        (!path.ok && copy.path != "")) {
        let diagnostic = if (!sourceUrl.ok) { sourceUrl.diagnostic }
            else if (!repo.ok) { repo.diagnostic } else { path.diagnostic }
        return (ckbPortableContractFailure(diagnostic), copy)
    }
    copy.sourceUrl = sourceUrl.value; copy.repo = repo.value; copy.path = path.value
    let derived = ArrayList<String>()
    for (value in copy.derivedFrom) {
        let normalized = normalizeCkbMetadataLocator(value, "derivedFrom", sourceId, context)
        if (!normalized.ok) { return (ckbPortableContractFailure(normalized.diagnostic), copy) }
        derived.add(normalized.value)
    }
    copy.derivedFrom = derived.toArray()
    for (field in 0..15) {
        let current = ckbPortableMetadataString(copy, field)
        let normalized = normalizeCkbKnowledgeText(current, ckbPortableMetadataField(field), sourceId, context)
        if (!normalized.ok) { return (ckbPortableContractFailure(normalized.diagnostic), copy) }
        ckbPortableSetMetadataString(copy, field, normalized.value)
    }
    (ckbPortableContractSuccess(), copy)
}

private func ckbPortableMetadataString(metadata: KnowledgeMetadata, field: Int64): String {
    if (field == 0) { return metadata.symbol }
    if (field == 1) { return metadata.commit }
    if (field == 2) { return metadata.docVersion }
    if (field == 3) { return metadata.targetVersion }
    if (field == 4) { return metadata.sourceSet }
    if (field == 5) { return metadata.versionResolutionId }
    if (field == 6) { return metadata.crawlAt }
    if (field == 7) { return metadata.indexedAt }
    if (field == 8) { return metadata.knowledgeVersion }
    if (field == 9) { return metadata.candidateVersion }
    if (field == 10) { return metadata.sourceType }
    if (field == 11) { return metadata.trustLevel }
    if (field == 12) { return metadata.reviewState }
    if (field == 13) { return metadata.license }
    if (field == 14) { return metadata.repoVisibility }
    ""
}

private func ckbPortableMetadataField(field: Int64): String {
    if (field == 0) { return "metadata.symbol" }
    if (field == 1) { return "metadata.commit" }
    if (field == 2) { return "metadata.docVersion" }
    if (field == 3) { return "metadata.targetVersion" }
    if (field == 4) { return "metadata.sourceSet" }
    if (field == 5) { return "metadata.versionResolutionId" }
    if (field == 6) { return "metadata.crawlAt" }
    if (field == 7) { return "metadata.indexedAt" }
    if (field == 8) { return "metadata.knowledgeVersion" }
    if (field == 9) { return "metadata.candidateVersion" }
    if (field == 10) { return "metadata.sourceType" }
    if (field == 11) { return "metadata.trustLevel" }
    if (field == 12) { return "metadata.reviewState" }
    if (field == 13) { return "metadata.license" }
    "metadata.repoVisibility"
}

private func ckbPortableSetMetadataString(metadata: KnowledgeMetadata, field: Int64, value: String): Unit {
    if (field == 0) { metadata.symbol = value }
    else if (field == 1) { metadata.commit = value }
    else if (field == 2) { metadata.docVersion = value }
    else if (field == 3) { metadata.targetVersion = value }
    else if (field == 4) { metadata.sourceSet = value }
    else if (field == 5) { metadata.versionResolutionId = value }
    else if (field == 6) { metadata.crawlAt = value }
    else if (field == 7) { metadata.indexedAt = value }
    else if (field == 8) { metadata.knowledgeVersion = value }
    else if (field == 9) { metadata.candidateVersion = value }
    else if (field == 10) { metadata.sourceType = value }
    else if (field == 11) { metadata.trustLevel = value }
    else if (field == 12) { metadata.reviewState = value }
    else if (field == 13) { metadata.license = value }
    else if (field == 14) { metadata.repoVisibility = value }
}

private func ckbPortableCopyTyped(record: CangjieTypedRecord): CangjieTypedRecord {
    let copy = CangjieTypedRecord()
    copy.recordKind = record.recordKind; copy.sourceId = record.sourceId
    copy.title = record.title; copy.content = record.content; copy.citation = record.citation
    copy.sourceSet = record.sourceSet; copy.sourceFamily = record.sourceFamily
    copy.path = record.path; copy.heading = record.heading; copy.sectionId = record.sectionId
    copy.symbol = record.symbol; copy.toolName = record.toolName; copy.command = record.command
    copy.caseId = record.caseId; copy.contentHash = record.contentHash
    copy.versionResolutionId = record.versionResolutionId; copy.targetVersion = record.targetVersion
    copy.sourceRef = record.sourceRef; copy.refKind = record.refKind
    copy.resolvedCommit = record.resolvedCommit; copy.trustLevel = record.trustLevel
    copy.reviewState = record.reviewState; copy.diagnostic = record.diagnostic
    copy
}

private func ckbPortableScanNormalized(report: CkbPortablePathScanReport,
    record: NormalizedRecord, context: CkbPortablePathContext): Unit {
    ckbPortableScanFields(report, ["sourceId", "title", "chunk", "citation"],
        [record.sourceId, record.title, record.chunk, record.citation],
        record.sourceId, context)
    ckbPortableScanMetadata(report, record.metadata, record.sourceId, context)
}

private func ckbPortableScanMetadata(report: CkbPortablePathScanReport,
    metadata: KnowledgeMetadata, sourceId: String, context: CkbPortablePathContext): Unit {
    let raw = RawRecord(); raw.sourceId = sourceId; raw.metadata = metadata
    ckbPortableMergeScan(report, scanCkbRawPathOccurrences(raw, context))
}

private func ckbPortableScanText(report: CkbPortablePathScanReport, value: String,
    field: String, sourceId: String, context: CkbPortablePathContext): Unit {
    report.scannedFieldCount += 1
    let normalized = normalizeCkbKnowledgeText(value, field, sourceId, context)
    if (!normalized.ok) {
        report.ready = false
        report.diagnostic = normalized.diagnostic
    }
    for (finding in normalized.findings) {
        report.findings.add(finding)
        if (finding.category == "unmapped") { report.unmappedCount += 1 }
        else { report.machinePathCount += 1 }
    }
}

private func ckbPortableScanFields(report: CkbPortablePathScanReport,
    fields: Array<String>, values: Array<String>, sourceId: String,
    context: CkbPortablePathContext): Unit {
    if (fields.size != values.size) {
        report.ready = false; report.diagnostic = "portable_scan_field_contract_invalid"
        return
    }
    for (i in 0..fields.size) {
        ckbPortableScanText(report, values[i], fields[i], sourceId, context)
    }
}

private func ckbPortableMergeScan(target: CkbPortablePathScanReport,
    source: CkbPortablePathScanReport): Unit {
    target.scannedFieldCount += source.scannedFieldCount
    target.machinePathCount += source.machinePathCount
    target.unmappedCount += source.unmappedCount
    if (!source.ready) { target.ready = false; target.diagnostic = source.diagnostic }
    for (finding in source.findings) { target.findings.add(finding) }
}

private func ckbPortableFinalizeScan(report: CkbPortablePathScanReport):
    CkbPortablePathScanReport {
    report.ready = report.machinePathCount == 0 && report.unmappedCount == 0
    if (!report.ready && report.diagnostic == "ok") {
        report.diagnostic = "student_visible_path_finding"
    }
    report
}

private func ckbPortableFlushToken(result: CkbPortableTextResult, token: String,
    field: String, sourceId: String, context: CkbPortablePathContext, out: StringBuilder): Unit {
    if (token == "") { return }
    let classified = classifyCkbPathOccurrence(token, field, sourceId, context)
    out.append(if (classified.ok) { classified.value } else { token })
    if (!classified.ok) {
        result.ok = false; result.diagnostic = classified.diagnostic
        let finding = CkbPortablePathFinding()
        finding.sourceId = ckbPortablePublicSourceId(sourceId, context); finding.field = field
        finding.category = classified.category; finding.ruleId = classified.ruleId
        finding.privateValue = token; result.findings.add(finding)
    } else if (classified.changed) {
        result.changedCount += 1
        let finding = CkbPortablePathFinding()
        finding.sourceId = ckbPortablePublicSourceId(sourceId, context); finding.field = field
        finding.category = classified.category; finding.ruleId = classified.ruleId
        finding.privateValue = token; result.findings.add(finding)
    }
}

private func ckbPortableTokenDelimiter(rune: Rune): Bool {
    rune == r' ' || rune == r'\n' || rune == r'\r' || rune == r'\t' ||
    rune == r'(' || rune == r')' || rune == r'[' || rune == r']' ||
    rune == r'"' || rune == r'\'' ||
    rune == r',' || rune == r';'
}

private func ckbPortableClassified(result: CkbPortablePathResult, category: String,
    ruleId: String, value: String): CkbPortablePathResult {
    result.ok = true; result.diagnostic = "ok"; result.category = category
    result.ruleId = ruleId; result.changed = result.value != value; result.value = value
    result
}

private func ckbPortableNetworkLocator(value: String): Bool {
    let lower = value.toAsciiLower()
    lower.startsWith("http://") || lower.startsWith("https://") ||
    lower.startsWith("ckb-source://") || lower.startsWith("git@") ||
    lower.startsWith("ssh://")
}

private func ckbPortableApiRoute(value: String, context: CkbPortablePathContext): Bool {
    for (route in context.apiRoutes) {
        if (value == route || value.startsWith(route + "?") || value.startsWith(route + "#")) {
            return true
        }
    }
    false
}

private func ckbPortableRelativeText(value: String): Bool {
    if (ckbPortableAbsolutePath(value) || value.startsWith("file://")) { return false }
    if (value.contains("/") || value.contains("\\")) {
        for (part in value.replace("\\", "/").split("/")) {
            if (part == "..") { return false }
        }
    }
    true
}

private func ckbPortableAbsolutePath(value: String): Bool {
    if (value.startsWith("/") || value.startsWith("\\\\") || value.startsWith("file://")) {
        return true
    }
    let runes = value.toRuneArray()
    runes.size >= 3 && ((runes[0] >= r'A' && runes[0] <= r'Z') ||
        (runes[0] >= r'a' && runes[0] <= r'z')) &&
        runes[1] == r':' && (runes[2] == r'\\' || runes[2] == r'/')
}

private func ckbPortableHomePath(value: String): (String, String) {
    var prefix = ""
    var path = value
    if (path.startsWith("file://")) { prefix = "file://"; path = path["file://".size..path.size] }
    let slash = path.replace("\\", "/")
    let parts = slash.split("/")
    var suffixStart: Int64 = -1
    if (parts.size >= 4 && parts[0] == "" &&
        (parts[1] == "Users" || parts[1] == "home")) { suffixStart = 3 }
    if (parts.size >= 4 && parts[0].endsWith(":") && parts[1] == "Users") { suffixStart = 3 }
    if (parts.size >= 6 && parts[0] == "" && parts[1] == "" &&
        parts[3] == "Users") { suffixStart = 5 }
    if (suffixStart < 0) { return ("miss", value) }
    let suffix = ckbPortableJoin(parts, suffixStart, "/")
    let separator = if (value.contains("\\") && prefix == "") { "\\" } else { "/" }
    let rendered = if (suffix == "") { prefix + "{{CKB_PATH:USER_HOME}}" }
        else { prefix + "{{CKB_PATH:USER_HOME}}" + separator + suffix.replace("/", separator) }
    ("ok", rendered)
}

private func ckbPortableTemporaryPath(value: String): (String, String) {
    for (root in ["/tmp", "/var/tmp", "C:\\Temp", "C:/Temp"]) {
        if (value == root || value.startsWith(root + "/") || value.startsWith(root + "\\")) {
            return ("ok", "{{CKB_PATH:TMPDIR}}" + value[root.size..value.size])
        }
    }
    ("miss", value)
}

private func ckbPortableRuntimeStatePath(value: String): Bool {
    let lower = value.toAsciiLower().replace("\\", "/")
    lower.contains("/metadata/transactions/") || lower.contains("/runtime-home/") ||
        lower.contains("/sessions/") || lower.endsWith(".log")
}

private func ckbPortableAbsolutePlaceholder(value: String): String {
    if (value.startsWith("file://")) {
        return "file://{{CKB_PATH:ABSOLUTE}}" + value["file://".size..value.size]
    }
    if (value.startsWith("/")) { return "{{CKB_PATH:ABSOLUTE}}" + value }
    "{{CKB_PATH:ABSOLUTE}}/" + value
}

private func ckbPortableLocatorField(field: String): Bool {
    field == "path" || field == "repo" || field == "sourceUrl" ||
        field == "derivedFrom" || field == "metadata.path" ||
        field == "metadata.repo" || field == "metadata.sourceUrl" ||
        field == "metadata.derivedFrom"
}

private func ckbPortableSafeRelativePath(value: String): Bool {
    if (value == "" || ckbPortableAbsolutePath(value) || value.contains("\\") ||
        value.trimAscii() != value) { return false }
    for (part in value.split("/")) {
        if (part == "" || part == "." || part == "..") { return false }
    }
    true
}

private func ckbPortableTrimLeadingSlash(value: String): String {
    var out = value
    while (out.startsWith("/") || out.startsWith("\\")) { out = out[1..out.size] }
    out
}

private func ckbPortablePathBoundaryPrefix(parent: String, child: String): Bool {
    parent == child || child.startsWith(parent + "/") || child.startsWith(parent + "\\")
}

private func ckbPortablePathSeparator(value: String, index: Int64): Bool {
    if (index < 0 || index >= value.size) { return false }
    value[index..index + 1] == "/" || value[index..index + 1] == "\\"
}

private func ckbPortableIndexOf(value: String, needle: String): Int64 {
    match (value.indexOf(needle)) {
        case Some(index) => index
        case None => -1
    }
}

private func ckbPortablePublicSourceId(sourceId: String,
    context: CkbPortablePathContext): String {
    for (root in context.localRoots.roots) {
        if (sourceId.contains(root.localRoot)) { return root.sourceId }
    }
    if (ckbPortableAbsolutePath(sourceId) || sourceId.contains("/Users/") ||
        sourceId.contains("/home/") || sourceId.contains("\\")) {
        return "unmapped-source"
    }
    sourceId
}

private func ckbPortableRootKind(kind: String): Bool {
    kind == "PROJECT_ROOT" || kind == "SOURCE_ROOT" || kind == "SDK_ROOT" ||
        kind == "INSTALL_ROOT" || kind == "BUILD_ROOT"
}

private func ckbPortableExactStrings(actual: ArrayList<String>, expected: Array<String>): Bool {
    if (actual.size != expected.size) { return false }
    let left = actual.toArray(); let right = expected.clone()
    sort(left); sort(right)
    for (i in 0..left.size) { if (left[i] != right[i]) { return false } }
    true
}

private func ckbPortableJoin(parts: Array<String>, start: Int64, separator: String): String {
    let out = StringBuilder()
    for (i in start..parts.size) {
        if (i > start) { out.append(separator) }
        out.append(parts[i])
    }
    out.toString()
}

private func ckbPortableContractSuccess(): CkbReproContractResult {
    let result = CkbReproContractResult(); result.ok = true; result.diagnostic = "ok"; result
}

private func ckbPortableContractFailure(diagnostic: String): CkbReproContractResult {
    let result = CkbReproContractResult(); result.diagnostic = diagnostic; result
}

private func ckbPortableAddFindings(target: ArrayList<CkbPortablePathFinding>,
    source: ArrayList<CkbPortablePathFinding>): Unit {
    for (finding in source) { target.add(finding) }
}

private func ckbPortableCanonicalFields(fields: Array<String>): String {
    let out = StringBuilder()
    for (value in fields) { out.append("${value.toArray().size}:${value}") }
    out.toString()
}

private func ckbPortableCanonicalMetadata(metadata: KnowledgeMetadata): String {
    let fields = ArrayList<String>()
    for (value in [
        metadata.sourceId, metadata.sourceType, metadata.sourceUrl, metadata.repo,
        metadata.path, metadata.symbol, metadata.commit, metadata.docVersion,
        metadata.targetVersion, metadata.sourceSet, metadata.versionResolutionId,
        metadata.crawlAt, metadata.indexedAt, metadata.knowledgeVersion,
        metadata.candidateVersion, "${metadata.contentSize}", metadata.trustLevel,
        metadata.reviewState, metadata.license, metadata.repoVisibility
    ]) { fields.add(value) }
    for (value in metadata.derivedFrom) { fields.add(value) }
    ckbPortableCanonicalFields(fields.toArray())
}

private func ckbPortableTypedCollectionHash(records: Array<CangjieTypedRecord>): String {
    ckbPortableCollectionHash(ckbPortableTypedCanonicalRows(records))
}

private func ckbPortableRawCollectionHash(records: Array<RawRecord>): String {
    ckbPortableCollectionHash(ckbPortableRawCanonicalRows(records))
}

private func ckbPortableTypedCanonicalRows(
    records: Array<CangjieTypedRecord>): ArrayList<String> {
    let rows = ArrayList<String>()
    for (record in records) { rows.add(canonicalCkbPortableTypedRecord(record)) }
    rows
}

private func ckbPortableRawCanonicalRows(records: Array<RawRecord>): ArrayList<String> {
    let rows = ArrayList<String>()
    for (record in records) { rows.add(canonicalCkbPortableRawRecord(record)) }
    rows
}

private func ckbPortableExpectedTypedMapping(records: Array<CangjieTypedRecord>,
    context: CkbPortablePathContext):
    (CkbReproContractResult, ArrayList<String>, ArrayList<String>) {
    let expected = ArrayList<String>()
    let pairs = ArrayList<String>()
    for (record in records) {
        let normalized = normalizeCkbTypedRecordPortablePaths(record, context)
        if (!normalized.ok) {
            return (ckbPortableContractFailure(normalized.diagnostic),
                ArrayList<String>(), ArrayList<String>())
        }
        let inputCanonical = canonicalCkbPortableTypedRecord(record)
        let outputCanonical = canonicalCkbPortableTypedRecord(normalized.record)
        expected.add(outputCanonical)
        pairs.add(ckbPortableCanonicalFields([inputCanonical, outputCanonical]))
    }
    (ckbPortableContractSuccess(), expected, pairs)
}

private func ckbPortableExpectedRawMapping(records: Array<RawRecord>,
    context: CkbPortablePathContext):
    (CkbReproContractResult, ArrayList<String>, ArrayList<String>) {
    let expected = ArrayList<String>()
    let pairs = ArrayList<String>()
    for (record in records) {
        let normalized = normalizeCkbRawRecordPortablePaths(record, context)
        if (!normalized.ok) {
            return (ckbPortableContractFailure(normalized.diagnostic),
                ArrayList<String>(), ArrayList<String>())
        }
        let inputCanonical = canonicalCkbPortableRawRecord(record)
        let outputCanonical = canonicalCkbPortableRawRecord(normalized.record)
        expected.add(outputCanonical)
        pairs.add(ckbPortableCanonicalFields([inputCanonical, outputCanonical]))
    }
    (ckbPortableContractSuccess(), expected, pairs)
}

private func ckbPortableCollectionHash(rows: ArrayList<String>): String {
    let ordered = rows.toArray(); sort(ordered)
    let out = StringBuilder()
    var previous = ""; var ordinal: Int64 = 0
    for (row in ordered) {
        if (row == previous) { ordinal += 1 } else { previous = row; ordinal = 0 }
        out.append("${row.toArray().size}:${row}:${ordinal}\n")
    }
    "sha256:${ckbPortableHex(ckbPortableSha256(out.toString().toArray()))}"
}

private func ckbPortableHmacSha256(key: Array<UInt8>, message: Array<UInt8>): Array<UInt8> {
    var material = key
    if (material.size > 64) { material = ckbPortableSha256(material) }
    let innerPad = ArrayList<UInt8>(); let outerPad = ArrayList<UInt8>()
    for (i in 0..64) {
        let byte = if (i < material.size) { material[i] } else { UInt8(0) }
        innerPad.add(byte ^ UInt8(0x36))
        outerPad.add(byte ^ UInt8(0x5c))
    }
    let inner = SHA256(); inner.write(innerPad.toArray()); inner.write(message)
    let outer = SHA256(); outer.write(outerPad.toArray()); outer.write(inner.finish())
    outer.finish()
}

private func ckbPortableSha256(bytes: Array<UInt8>): Array<UInt8> {
    let digest = SHA256(); digest.write(bytes); digest.finish()
}

private func ckbPortableHex(bytes: Array<UInt8>): String {
    let out = StringBuilder()
    for (byte in bytes) {
        out.append(ckbPortableNibble(byte / UInt8(16)))
        out.append(ckbPortableNibble(byte % UInt8(16)))
    }
    out.toString()
}

private func ckbPortableNibble(value: UInt8): String {
    if (value < UInt8(10)) { return "${value}" }
    if (value == UInt8(10)) { return "a" }; if (value == UInt8(11)) { return "b" }
    if (value == UInt8(12)) { return "c" }; if (value == UInt8(13)) { return "d" }
    if (value == UInt8(14)) { return "e" }; "f"
}

private func ckbPortableJson(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"")
        .replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
}
