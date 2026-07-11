package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.collection.HashMap
import std.collection.HashSet
import std.sort.*
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

class CkbReleaseAcquisitionStatus {
    static let OK: String = "ok"
    static let MALFORMED_JSON: String = "malformed_json"
    static let INVENTORY_LIMIT_EXCEEDED: String = "release_inventory_limit_exceeded"
    static let UNSAFE_PATH: String = "unsafe_source_path"
    static let DUPLICATE_SOURCE_IDENTITY: String = "duplicate_release_source_identity"
    static let DUPLICATE_LOGICAL_RECORD_ID: String = "duplicate_logical_record_id"
}

class CkbReleaseAcquisitionPolicy {
    static let SELECTOR_VERSION: String = "p5-release-selector-v2"
    // EVAL_SUPPORT may be represented by the remote bootstrap repository in
    // the baseline manifest or by the persisted local snapshot URI after a
    // successful run. Its logical source identity must not change between
    // those two physical acquisition representations.
    static let EVAL_SUPPORT_CANONICAL_REPO: String = "ckb/eval-support"
    static let DEFAULT_MAX_NON_EMPTY_PAGES: Int64 = 20
    static let TOOLS_MAX_NON_EMPTY_PAGES: Int64 = 50
    static let DEFAULT_MAX_OBJECTS: Int64 = 2000
    static let TOOLS_MAX_OBJECTS: Int64 = 5000
}

class CkbReleaseSourcePlan {
    var source: CangjieVersionSource = CangjieVersionSource()
    var sourceSet: String = ""
    var sourceFamily: String = ""
    var normalizedRepo: String = ""
    var targetVersion: String = ""
    var originalRef: String = ""
    var refKind: String = ""
    var selectorVersion: String = CkbReleaseAcquisitionPolicy.SELECTOR_VERSION
    var includePolicy: String = ""
    var excludePolicy: String = "root-or-segment=target,generated,build,vendor,binary"
    var maxNonEmptyPages: Int64 = CkbReleaseAcquisitionPolicy.DEFAULT_MAX_NON_EMPTY_PAGES
    var maxObjects: Int64 = CkbReleaseAcquisitionPolicy.DEFAULT_MAX_OBJECTS
    var maxFiles: Int64 = CkbReleaseAcquisitionPolicy.DEFAULT_MAX_OBJECTS
    var maxBytes: Int64 = CkbReleaseAcquisitionPolicy.DEFAULT_MAX_OBJECTS * SourceLimits.MAX_FILE_BYTES
    var canonicalIdentity: String = ""

    init() {}
}

class CkbReleaseFullSyncPlan {
    var ok: Bool = false
    var status: String = "not_started"
    var targetVersion: String = ""
    var selectorVersion: String = CkbReleaseAcquisitionPolicy.SELECTOR_VERSION
    var planHash: String = ""
    var requiredSourceSets: ArrayList<String> = ArrayList<String>()
    var missingSourceSets: ArrayList<String> = ArrayList<String>()
    var sources: ArrayList<CkbReleaseSourcePlan> = ArrayList<CkbReleaseSourcePlan>()
    var diagnostics: ArrayList<String> = ArrayList<String>()

    init() {}
}

class CkbReleaseSourceInventory {
    var sourceIdentity: String = ""
    var sourceSet: String = ""
    var sourceFamily: String = ""
    var repo: String = ""
    var originalRef: String = ""
    var resolvedCommit: String = ""
    var status: String = "not_started"
    var complete: Bool = false
    var explicitEnd: Bool = false
    var pagesScanned: Int64 = 0
    var nonEmptyPages: Int64 = 0
    var objectsSeen: Int64 = 0
    var filesSeen: Int64 = 0
    var contentBytes: Int64 = 0
    var plannedPaths: ArrayList<String> = ArrayList<String>()
    var completedPaths: ArrayList<String> = ArrayList<String>()
    let plannedPathSet: HashSet<String> = HashSet<String>()
    let completedPathSet: HashSet<String> = HashSet<String>()

    init() {}
}

class CkbReleaseControlEvidence {
    var kind: String = ""
    var sourceIdentity: String = ""
    var sourceSet: String = ""
    var repo: String = ""
    var originalRef: String = ""
    var resolvedCommit: String = ""
    var path: String = ""
    var page: Int64 = 0
    var status: String = ""
    var bodyHash: String = ""
    var attemptCount: Int64 = 0
    var objectCount: Int64 = 0
    var fileCount: Int64 = 0

    init() {}
}

class CkbReleaseTreePageParseResult {
    var ok: Bool = false
    var status: String = CkbReleaseAcquisitionStatus.MALFORMED_JSON
    var explicitEnd: Bool = false
    var truncated: Bool = false
    var objectsSeen: Int64 = 0
    var filesSeen: Int64 = 0
    var directoriesSeen: Int64 = 0
    var eligiblePaths: ArrayList<String> = ArrayList<String>()

    init() {}
}

class CkbReleaseLogicalIdAllocator {
    private let occurrences: HashMap<String, Int64> = HashMap<String, Int64>()

    init() {}

    func typedId(source: CkbReleaseSourcePlan, path: String, record: CangjieTypedRecord): String {
        let baseSubkey = ckbReleaseTypedBaseSubkey(record)
        let baseId = ckbReleaseCanonicalTypedId(source, path, record.recordKind, baseSubkey)
        let occurrence = match (this.occurrences.get(baseId)) {
            case Some(value) => value
            case None => 0
        }
        this.occurrences[baseId] = occurrence + 1
        if (occurrence == 0) {
            return baseId
        }
        ckbReleaseCanonicalTypedId(source, path, record.recordKind, "${baseSubkey}|duplicate=${occurrence}")
    }
}

func ckbBuildReleaseFullSyncPlan(profile: CkbScheduleTaskProfile, manifest: CangjieVersionManifest, targetVersion: String): CkbReleaseFullSyncPlan {
    let plan = CkbReleaseFullSyncPlan()
    plan.targetVersion = if (targetVersion.trimAscii() == "") { cangjieDefaultTargetVersion() } else { targetVersion.trimAscii() }
    let profileSourceSets = ArrayList<String>()
    for (family in profile.sourceFamilies) {
        let sourceSet = ckbReleaseSourceSetForFamily(family)
        if (sourceSet != "" && !ckbReleaseStringListContains(profileSourceSets, sourceSet)) {
            profileSourceSets.add(sourceSet)
        }
    }
    // KU-09 is exactly the five release families. A malformed profile must
    // fail closed instead of silently weakening the release contract.
    for (required in ckbReleaseRequiredSourceSets()) {
        plan.requiredSourceSets.add(required)
    }
    let identities = ArrayList<String>()
    let identitySet = HashSet<String>()
    for (source in manifest.sources) {
        if (!ckbReleaseRequiredSourceSet(source.sourceSet) || !ckbReleaseStringListContains(profileSourceSets, source.sourceSet)) {
            continue
        }
        let sourcePlan = ckbReleaseSourcePlan(source, plan.targetVersion)
        if (sourcePlan.normalizedRepo == "" || sourcePlan.originalRef == "") {
            plan.status = "manifest_source_missing:${source.sourceSet}"
            plan.diagnostics.add("manifest_source_missing:${source.sourceSet}")
            return plan
        }
        if (identitySet.contains(sourcePlan.canonicalIdentity)) {
            plan.status = "${CkbReleaseAcquisitionStatus.DUPLICATE_SOURCE_IDENTITY}:${sourcePlan.canonicalIdentity}"
            plan.diagnostics.add(plan.status)
            return plan
        }
        identities.add(sourcePlan.canonicalIdentity)
        identitySet.add(sourcePlan.canonicalIdentity)
        plan.sources.add(sourcePlan)
    }
    for (required in plan.requiredSourceSets) {
        if (!ckbReleasePlanHasSourceSet(plan, required)) {
            plan.missingSourceSets.add(required)
        }
    }
    if (plan.missingSourceSets.size > 0) {
        plan.status = "required_source_family_missing:${ckbReleaseJoin(plan.missingSourceSets, ",")}"
        plan.diagnostics.add(plan.status)
        return plan
    }
    let seed = StringBuilder()
    seed.append("target=")
    seed.append(ckbReleaseCanonicalField(plan.targetVersion))
    seed.append("|selector=")
    seed.append(plan.selectorVersion)
    let orderedIdentities = identities.toArray()
    sort(orderedIdentities)
    for (identity in orderedIdentities) {
        seed.append("|source=")
        seed.append(identity)
    }
    plan.planHash = "p5-plan-${ckbReleaseSha256(seed.toString())}"
    plan.ok = true
    plan.status = CkbReleaseAcquisitionStatus.OK
    plan
}

func ckbReleaseSourcePlan(source: CangjieVersionSource, targetVersion: String): CkbReleaseSourcePlan {
    let plan = CkbReleaseSourcePlan()
    plan.source = source
    plan.sourceSet = source.sourceSet.trimAscii()
    plan.sourceFamily = if (source.sourceFamily.trimAscii() == "") { ckbReleaseFamilyForSourceSet(plan.sourceSet) } else { source.sourceFamily.trimAscii() }
    plan.normalizedRepo = if (plan.sourceSet == CangjieSourceSets.EVAL_SUPPORT && ckbReleaseEvalSourceRepoAccepted(source.sourceRepo)) {
        CkbReleaseAcquisitionPolicy.EVAL_SUPPORT_CANONICAL_REPO
    } else {
        ckbReleaseNormalizeRepo(source.sourceRepo)
    }
    plan.targetVersion = if (targetVersion.trimAscii() == "") { cangjieDefaultTargetVersion() } else { targetVersion.trimAscii() }
    plan.originalRef = source.sourceRef.trimAscii()
    plan.refKind = if (source.refKind.trimAscii() == "") { "branch" } else { source.refKind.trimAscii() }
    plan.includePolicy = ckbReleaseIncludePolicy(plan.sourceSet)
    if (plan.sourceSet == CangjieSourceSets.TOOLS) {
        plan.maxNonEmptyPages = CkbReleaseAcquisitionPolicy.TOOLS_MAX_NON_EMPTY_PAGES
        plan.maxObjects = CkbReleaseAcquisitionPolicy.TOOLS_MAX_OBJECTS
        plan.maxFiles = CkbReleaseAcquisitionPolicy.TOOLS_MAX_OBJECTS
        plan.maxBytes = CkbReleaseAcquisitionPolicy.TOOLS_MAX_OBJECTS * SourceLimits.MAX_FILE_BYTES
    }
    if (plan.sourceSet == CangjieSourceSets.EVAL_SUPPORT) {
        plan.maxNonEmptyPages = 0
        plan.maxObjects = CkbReleaseAcquisitionPolicy.DEFAULT_MAX_OBJECTS
        plan.maxFiles = CkbReleaseAcquisitionPolicy.DEFAULT_MAX_OBJECTS
        plan.maxBytes = CkbReleaseAcquisitionPolicy.DEFAULT_MAX_OBJECTS * SourceLimits.MAX_FILE_BYTES
    }
    plan.canonicalIdentity = ckbReleaseCanonicalSourceIdentity(plan.sourceSet, plan.normalizedRepo, plan.targetVersion, plan.originalRef)
    plan
}

func ckbReleaseRequiredSourceSets(): ArrayList<String> {
    // Lexicographic order is part of the missing-family status contract.
    let out = ArrayList<String>()
    out.add(CangjieSourceSets.DOCS)
    out.add(CangjieSourceSets.EVAL_SUPPORT)
    out.add(CangjieSourceSets.STD)
    out.add(CangjieSourceSets.STDX)
    out.add(CangjieSourceSets.TOOLS)
    out
}

func ckbReleasePlanHasSourceSet(plan: CkbReleaseFullSyncPlan, sourceSet: String): Bool {
    for (source in plan.sources) {
        if (source.sourceSet == sourceSet) {
            return true
        }
    }
    false
}

func ckbReleaseAllInventoriesComplete(plan: CkbReleaseFullSyncPlan, inventories: ArrayList<CkbReleaseSourceInventory>): Bool {
    if (!plan.ok || inventories.size != plan.sources.size) {
        return false
    }
    for (source in plan.sources) {
        var found = false
        for (inventory in inventories) {
            if (inventory.sourceIdentity != source.canonicalIdentity) {
                continue
            }
            found = true
            if (!inventory.complete || !inventory.explicitEnd || inventory.status != CkbReleaseAcquisitionStatus.OK || inventory.plannedPaths.size == 0 || inventory.completedPaths.size == 0 || !ckbReleaseSameStringSet(inventory.plannedPaths, inventory.completedPaths)) {
                return false
            }
        }
        if (!found) {
            return false
        }
    }
    true
}

func ckbReleaseParseTreePage(sourceSet: String, body: String): CkbReleaseTreePageParseResult {
    let result = CkbReleaseTreePageParseResult()
    let eligible = HashSet<String>()
    try {
        let root = JsonValue.fromStr(body)
        var items = try {
            root.asArray().getItems()
        } catch (_: Exception) {
            let object = root.asObject()
            match (object.get("truncated")) {
                case Some(value) =>
                    if (value.asBool().getValue()) {
                        result.status = CkbReleaseAcquisitionStatus.INVENTORY_LIMIT_EXCEEDED
                        result.truncated = true
                        return result
                    }
                case None => ()
            }
            match (object.get("tree")) {
                case Some(value) => value.asArray().getItems()
                case None => throw Exception("tree array missing")
            }
        }
        if (items.size == 0) {
            result.ok = true
            result.status = CkbReleaseAcquisitionStatus.OK
            result.explicitEnd = true
            return result
        }
        for (item in items) {
            let object = item.asObject()
            let rawPath = ckbReleaseJsonString(object, "path")
            let itemType = ckbReleaseJsonString(object, "type").toAsciiLower()
            if (rawPath == "" || itemType == "") {
                throw Exception("tree object missing path or type")
            }
            let path = ckbReleaseNormalizeSourcePath(rawPath)
            if (path == "") {
                result.status = CkbReleaseAcquisitionStatus.UNSAFE_PATH
                return result
            }
            result.objectsSeen += 1
            if (itemType == "tree") {
                result.directoriesSeen += 1
                continue
            }
            if (itemType == "commit") {
                continue
            }
            if (itemType != "blob") {
                throw Exception("unsupported tree object type")
            }
            result.filesSeen += 1
            if (ckbReleasePathEligible(sourceSet, path) && !eligible.contains(path)) {
                eligible.add(path)
                result.eligiblePaths.add(path)
            }
        }
        result.ok = true
        result.status = CkbReleaseAcquisitionStatus.OK
    } catch (_: Exception) {
        result.ok = false
        result.status = CkbReleaseAcquisitionStatus.MALFORMED_JSON
    }
    result
}

func ckbReleaseNormalizeSourcePath(raw: String): String {
    if (raw == "" || raw.trimAscii() == "" || raw.startsWith("/") || raw.contains("\\") || raw.contains("\u{0000}") || raw.contains("\n") || raw.contains("\r") || raw.contains("\t")) {
        return ""
    }
    let parts = raw.split("/")
    for (part in parts) {
        if (part == "" || part == "." || part == "..") {
            return ""
        }
    }
    for (ch in raw.toRuneArray()) {
        let code = UInt32(ch)
        if (code <= 31u32 || (code >= 127u32 && code <= 159u32)) {
            return ""
        }
    }
    raw
}

func ckbReleasePercentEncodePath(path: String): String {
    let normalized = ckbReleaseNormalizeSourcePath(path)
    if (normalized == "") {
        return ""
    }
    let out = StringBuilder()
    for (byte in normalized.toArray()) {
        if (byte == UInt8(47)) {
            out.append("/")
        } else if (ckbReleaseUnreservedByte(byte)) {
            out.append(String.fromUtf8([byte]))
        } else {
            out.append("%")
            out.append(ckbReleaseHexByte(byte / UInt8(16)))
            out.append(ckbReleaseHexByte(byte % UInt8(16)))
        }
    }
    out.toString()
}

func ckbReleaseCanonicalSourceIdentity(sourceSet: String, repo: String, targetVersion: String, originalRef: String): String {
    "sourceSet=${ckbReleaseCanonicalField(sourceSet)}|repo=${ckbReleaseCanonicalField(repo.toAsciiLower())}|targetVersion=${ckbReleaseCanonicalField(targetVersion)}|lineage=${ckbReleaseCanonicalField(ckbReleaseRefLineage(targetVersion, originalRef))}"
}

func ckbReleaseCanonicalRawId(source: CkbReleaseSourcePlan, path: String): String {
    "p5raw-${ckbReleaseSha256(ckbReleaseCanonicalRawKey(source, path))}"
}

func ckbReleaseCanonicalTypedId(source: CkbReleaseSourcePlan, path: String, recordKind: String, subkey: String): String {
    "p5typed-${ckbReleaseSha256(ckbReleaseCanonicalTypedKey(source, path, recordKind, subkey))}"
}

func ckbReleaseCanonicalRawKey(source: CkbReleaseSourcePlan, path: String): String {
    "${source.canonicalIdentity}|path=${ckbReleaseCanonicalField(path)}|recordKind=raw|subkey=whole"
}

func ckbReleaseCanonicalTypedKey(source: CkbReleaseSourcePlan, path: String, recordKind: String, subkey: String): String {
    "${source.canonicalIdentity}|path=${ckbReleaseCanonicalField(path)}|recordKind=${ckbReleaseCanonicalField(recordKind)}|subkey=${ckbReleaseCanonicalField(subkey)}"
}

func ckbReleaseTypedBaseSubkey(record: CangjieTypedRecord): String {
    if (record.recordKind == CangjieTypedRecordKinds.DOC_SECTION) {
        return "heading=${record.heading}"
    }
    if (record.recordKind == CangjieTypedRecordKinds.TOOL_MANUAL) {
        return "tool=${record.toolName}|command=${record.command}|section=${record.heading}"
    }
    if (record.recordKind == CangjieTypedRecordKinds.EVAL_SUPPORT) {
        return "case=${record.caseId}|family=${record.sourceFamily}"
    }
    if (record.recordKind == CangjieTypedRecordKinds.SYMBOL_CARD) {
        return "symbol=${record.symbol}|section=${record.sectionId}"
    }
    if (record.recordKind == CangjieTypedRecordKinds.MODULE_TREE || record.recordKind == CangjieTypedRecordKinds.AVAILABILITY) {
        return "symbol=${record.symbol}|kind=${record.recordKind}"
    }
    "whole"
}

func ckbReleaseInventoryFailure(inventory: CkbReleaseSourceInventory, status: String): Unit {
    inventory.complete = false
    inventory.explicitEnd = false
    inventory.status = status
}

func ckbReleaseInventoryPlanPath(inventory: CkbReleaseSourceInventory, path: String): Bool {
    if (inventory.plannedPathSet.contains(path)) { return false }
    inventory.plannedPathSet.add(path)
    inventory.plannedPaths.add(path)
    true
}

func ckbReleaseInventoryCompletePath(inventory: CkbReleaseSourceInventory, path: String): Bool {
    if (inventory.completedPathSet.contains(path)) { return false }
    inventory.completedPathSet.add(path)
    inventory.completedPaths.add(path)
    true
}

func ckbReleaseInventorySortPaths(inventory: CkbReleaseSourceInventory): Unit {
    let planned = inventory.plannedPaths.toArray()
    sort(planned)
    inventory.plannedPaths.clear()
    inventory.plannedPaths.add(all: planned)
    let completed = inventory.completedPaths.toArray()
    sort(completed)
    inventory.completedPaths.clear()
    inventory.completedPaths.add(all: completed)
}

private func ckbReleaseRequiredSourceSet(sourceSet: String): Bool {
    sourceSet == CangjieSourceSets.DOCS || sourceSet == CangjieSourceSets.STD || sourceSet == CangjieSourceSets.STDX || sourceSet == CangjieSourceSets.TOOLS || sourceSet == CangjieSourceSets.EVAL_SUPPORT
}

private func ckbReleaseFamilyForSourceSet(sourceSet: String): String {
    if (sourceSet == CangjieSourceSets.DOCS) { return "docs" }
    if (sourceSet == CangjieSourceSets.STD) { return "stdlib" }
    if (sourceSet == CangjieSourceSets.STDX) { return "stdx" }
    if (sourceSet == CangjieSourceSets.TOOLS) { return "tools" }
    if (sourceSet == CangjieSourceSets.EVAL_SUPPORT) { return "eval-support" }
    ""
}

private func ckbReleaseSourceSetForFamily(family: String): String {
    let value = family.trimAscii().toAsciiLower()
    if (value == "docs") { return CangjieSourceSets.DOCS }
    if (value == "std" || value == "stdlib") { return CangjieSourceSets.STD }
    if (value == "stdx") { return CangjieSourceSets.STDX }
    if (value == "tools") { return CangjieSourceSets.TOOLS }
    if (value == "eval-support" || value == "eval_support") { return CangjieSourceSets.EVAL_SUPPORT }
    ""
}

private func ckbReleaseRefLineage(targetVersion: String, originalRef: String): String {
    let target = if (targetVersion.trimAscii() == "") { cangjieDefaultTargetVersion() } else { targetVersion.trimAscii() }
    let ref = originalRef.trimAscii()
    for (alias in cangjieSourceRefAliasesForTargetVersion(target)) {
        if (ref == alias) { return "release:${target}" }
    }
    if (ref == "release-${target}" || ref == "release/${target}") {
        return "release:${target}"
    }
    ref
}

private func ckbReleaseIncludePolicy(sourceSet: String): String {
    if (sourceSet == CangjieSourceSets.DOCS) { return "directories=any;extensions=.md,.markdown,.json,.toml" }
    if (sourceSet == CangjieSourceSets.STD) { return "directories=any;extensions=.cj,.md,.markdown;exact-or-suffix=cjpm.toml" }
    if (sourceSet == CangjieSourceSets.STDX) { return "directories=any;extensions=.cj,.md,.markdown;exact-or-suffix=cjpm.toml" }
    if (sourceSet == CangjieSourceSets.TOOLS) { return "directories=any;extensions=.cj,.md,.markdown,.sh,.py,.json,.yaml,.yml,.toml" }
    if (sourceSet == CangjieSourceSets.EVAL_SUPPORT) { return "source=explicit-root-or-active-snapshot;recordKind=eval_support" }
    ""
}

private func ckbReleasePathEligible(sourceSet: String, path: String): Bool {
    let lower = path.toAsciiLower()
    if (lower.startsWith("target/") || lower.contains("/target/") || lower.startsWith("generated/") || lower.contains("/generated/") || lower.startsWith("build/") || lower.contains("/build/") || lower.startsWith("vendor/") || lower.contains("/vendor/") || lower.startsWith("binary/") || lower.contains("/binary/")) {
        return false
    }
    if (sourceSet == CangjieSourceSets.DOCS) {
        return lower.endsWith(".md") || lower.endsWith(".markdown") || lower.endsWith(".json") || lower.endsWith(".toml")
    }
    if (sourceSet == CangjieSourceSets.STD || sourceSet == CangjieSourceSets.STDX) {
        return lower.endsWith(".cj") || lower.endsWith(".md") || lower.endsWith(".markdown") || lower.endsWith("cjpm.toml")
    }
    if (sourceSet == CangjieSourceSets.TOOLS) {
        return lower.endsWith(".cj") || lower.endsWith(".md") || lower.endsWith(".markdown") || lower.endsWith(".sh") || lower.endsWith(".py") || lower.endsWith(".json") || lower.endsWith(".yaml") || lower.endsWith(".yml") || lower.endsWith(".toml")
    }
    false
}

private func ckbReleaseNormalizeRepo(raw: String): String {
    let parts = raw.trimAscii().split("/")
    if (parts.size != 2) { return "" }
    let owner = parts[0].trimAscii()
    let repo = parts[1].trimAscii()
    if (!ckbReleaseSafeRepoPart(owner) || !ckbReleaseSafeRepoPart(repo)) { return "" }
    "${owner}/${repo}"
}

private func ckbReleaseEvalSourceRepoAccepted(raw: String): Bool {
    let value = raw.trimAscii()
    value == "ckb-local://eval-support" || ckbReleaseNormalizeRepo(value) != ""
}

private func ckbReleaseSafeRepoPart(value: String): Bool {
    if (value == "" || value == "." || value == ".." || value.contains("..")) { return false }
    for (byte in value.toArray()) {
        if (!((byte >= UInt8(65) && byte <= UInt8(90)) || (byte >= UInt8(97) && byte <= UInt8(122)) || (byte >= UInt8(48) && byte <= UInt8(57)) || byte == UInt8(45) || byte == UInt8(46) || byte == UInt8(95))) {
            return false
        }
    }
    true
}

private func ckbReleaseCanonicalField(value: String): String {
    let out = StringBuilder()
    for (byte in value.toArray()) {
        if (ckbReleaseUnreservedByte(byte)) {
            out.append(String.fromUtf8([byte]))
        } else {
            out.append("%")
            out.append(ckbReleaseHexByte(byte / UInt8(16)))
            out.append(ckbReleaseHexByte(byte % UInt8(16)))
        }
    }
    out.toString()
}

private func ckbReleaseUnreservedByte(byte: UInt8): Bool {
    (byte >= UInt8(65) && byte <= UInt8(90)) || (byte >= UInt8(97) && byte <= UInt8(122)) || (byte >= UInt8(48) && byte <= UInt8(57)) || byte == UInt8(45) || byte == UInt8(46) || byte == UInt8(95) || byte == UInt8(126)
}

private func ckbReleaseHexByte(value: UInt8): String {
    if (value < UInt8(10)) { return String.fromUtf8([UInt8(48) + value]) }
    String.fromUtf8([UInt8(55) + value])
}

private func ckbReleaseJsonString(object: JsonObject, key: String): String {
    match (object.get(key)) {
        case Some(value) => try { value.asString().getValue() } catch (_: Exception) { "" }
        case None => ""
    }
}

private func ckbReleaseStringListContains(items: ArrayList<String>, value: String): Bool {
    for (item in items) { if (item == value) { return true } }
    false
}

private func ckbReleaseSameStringSet(left: ArrayList<String>, right: ArrayList<String>): Bool {
    if (left.size != right.size) { return false }
    let rightSet = HashSet<String>(right)
    if (rightSet.size != right.size) { return false }
    let leftSet = HashSet<String>(left)
    if (leftSet.size != left.size) { return false }
    for (item in leftSet) { if (!rightSet.contains(item)) { return false } }
    true
}

private func ckbReleaseSha256(value: String): String {
    let digest = SHA256()
    digest.write(value.toArray())
    let out = StringBuilder()
    for (byte in digest.finish()) {
        out.append(ckbReleaseHexByte(byte / UInt8(16)))
        out.append(ckbReleaseHexByte(byte % UInt8(16)))
    }
    out.toString()
}

func ckbReleaseEvidenceHash(value: String): String {
    ckbReleaseSha256(value)
}

private func ckbReleaseJoin(items: ArrayList<String>, separator: String): String {
    let out = StringBuilder()
    for (i in 0..items.size) {
        if (i > 0) { out.append(separator) }
        out.append(items[i])
    }
    out.toString()
}
