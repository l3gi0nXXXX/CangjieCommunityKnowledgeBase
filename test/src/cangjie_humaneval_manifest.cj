package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashSet}
import std.fs.{Directory, File, Path, exists}
import std.process.launch
import std.sort.*
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

public class CangjieHumanEvalManifestRow {
    public var caseId: String = ""
    public var datasetVersion: String = ""
    public var targetVersion: String = ""
    public var signature: String = ""
    public var prompt: String = ""
    public var promptHash: String = ""
    public var metadataHash: String = ""
    public var starterHash: String = ""
    public var testsHash: String = ""
    public var translationHash: String = ""
    public var caseHash: String = ""
    public var expectedKnowledgeTags: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class CangjieHumanEvalManifestResult {
    public var ok: Bool = true
    public var datasetRoot: String = ""
    public var datasetVersion: String = ""
    public var rows: ArrayList<CangjieHumanEvalManifestRow> = ArrayList<CangjieHumanEvalManifestRow>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}

    public func addDiagnostic(value: String): Unit {
        this.ok = false
        this.diagnostics.add(value)
    }
}

// Builds the CKB-owned authority from dataset files. outputPath may be empty for
// callers that only need an in-memory, read-only validation.
public func buildCangjieHumanEvalManifest(datasetRoot: String, outputPath: String): CangjieHumanEvalManifestResult {
    let result = CangjieHumanEvalManifestResult()
    result.datasetRoot = datasetRoot
    let root = Path(datasetRoot)
    if (!exists(root)) {
        result.addDiagnostic("dataset_root_not_found")
        return result
    }
    let names = ArrayList<String>()
    try {
        for (entry in Directory.readFrom(root)) {
            if (entry.isDirectory() && entry.name.startsWith("CJ-HUMANEVAL-")) {
                names.add(entry.name)
            }
        }
    } catch (_: Exception) {
        result.addDiagnostic("dataset_root_read_failed")
        return result
    }
    sort(names)
    for (name in names) {
        let row = cangjieHumanEvalBuildManifestRow(root.join(name), name)
        result.rows.add(row)
        if (row.caseHash == "") {
            result.addDiagnostic("case_read_failed:${name}")
        }
    }
    result.datasetVersion = cangjieHumanEvalDatasetVersion(result.rows)
    for (row in result.rows) {
        row.datasetVersion = result.datasetVersion
    }
    let validated = validateCangjieHumanEvalManifest(result, datasetRoot)
    if (!validated.ok) {
        result.ok = false
        for (diagnostic in validated.diagnostics) { result.diagnostics.add(diagnostic) }
    }
    if (outputPath != "" && result.ok) {
        try {
            let target = Path(outputPath)
            if (!exists(target.parent)) { Directory.create(target.parent, recursive: true) }
            let rendered = cangjieHumanEvalRenderAuthorityManifest(result)
            let tmpIdentity = cangjieHumanEvalManifestHash((outputPath + result.datasetVersion).toArray()).replace("sha256:", "")
            let tmp = target.parent.join(".tmp-${tmpIdentity}")
            File.writeTo(tmp, rendered.toArray())
            let readback = cangjieHumanEvalManifestReadUtf8(tmp)
            if (!readback[0] || readback[1] != rendered || !parseCangjieHumanEvalAuthorityManifest(readback[1]).ok) {
                _ = launch("/bin/rm", ["-f", tmp.toString()]).wait(); result.addDiagnostic("manifest_write_verify_failed"); return result
            }
            if (launch("/bin/mv", ["-f", tmp.toString(), target.toString()]).wait() != 0) {
                _ = launch("/bin/rm", ["-f", tmp.toString()]).wait(); result.addDiagnostic("manifest_atomic_replace_failed"); return result
            }
        } catch (_: Exception) {
            result.addDiagnostic("manifest_write_failed")
        }
    }
    result
}

public func runCangjieHumanEvalManifestBuild(args: Array<String>): Int64 {
    var datasetRoot = ""; var outputPath = ""; var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "cangjie-humaneval-manifest-build") { i += 1; continue }
        if ((arg == "--dataset-root" || arg == "--output") && i + 1 >= args.size) { println("usage error: missing value for ${arg}"); return 2 }
        if (arg == "--dataset-root") { datasetRoot = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--output") { outputPath = args[i + 1].trimAscii(); i += 2; continue }
        println("usage error: unknown cangjie-humaneval-manifest-build argument"); return 2
    }
    if (datasetRoot == "" || outputPath == "") { println("usage error: cangjie-humaneval-manifest-build requires --dataset-root and --output"); return 2 }
    let result = buildCangjieHumanEvalManifest(datasetRoot, outputPath)
    if (!result.ok) { println("authority manifest build failed diagnostics=${result.diagnostics.size}"); return 1 }
    println("authority manifest built rows=${result.rows.size} datasetVersion=${result.datasetVersion}"); 0
}

public func validateCangjieHumanEvalManifest(manifest: CangjieHumanEvalManifestResult, datasetRoot: String): CangjieHumanEvalManifestResult {
    let out = CangjieHumanEvalManifestResult()
    out.datasetRoot = datasetRoot
    out.datasetVersion = manifest.datasetVersion
    if (manifest.rows.size != 164) { out.addDiagnostic("manifest_case_count:${manifest.rows.size}:164") }
    let seen = HashSet<String>()
    for (i in 0..manifest.rows.size) {
        let row = manifest.rows[i]
        let expected = cangjieHumanEvalCaseId(i)
        if (row.caseId != expected) { out.addDiagnostic("manifest_case_id_not_contiguous:${i}:${row.caseId}:${expected}") }
        if (seen.contains(row.caseId)) { out.addDiagnostic("manifest_duplicate_case_id:${row.caseId}") } else { seen.add(row.caseId) }
        if (row.datasetVersion == "" || row.datasetVersion != manifest.datasetVersion) { out.addDiagnostic("manifest_dataset_version_mismatch:${row.caseId}") }
        if (row.signature == "") { out.addDiagnostic("manifest_signature_missing:${row.caseId}") }
        for (field in [row.promptHash, row.metadataHash, row.starterHash, row.testsHash, row.translationHash, row.caseHash]) {
            if (!cangjieHumanEvalManifestValidHash(field)) { out.addDiagnostic("manifest_hash_invalid:${row.caseId}") }
        }
        if (row.caseHash != cangjieHumanEvalManifestRowHash(row)) { out.addDiagnostic("manifest_case_hash_invalid:${row.caseId}") }
        if (datasetRoot != "" && exists(Path(datasetRoot).join(row.caseId))) {
            let actual = cangjieHumanEvalBuildManifestRow(Path(datasetRoot).join(row.caseId), row.caseId)
            if (actual.caseHash != row.caseHash) { out.addDiagnostic("manifest_case_hash_mismatch:${row.caseId}") }
        }
    }
    if (manifest.datasetVersion != cangjieHumanEvalDatasetVersion(manifest.rows)) { out.addDiagnostic("manifest_dataset_hash_mismatch") }
    out.rows = manifest.rows
    out
}

public func cangjieHumanEvalAuthorityDatasetDiagnostic(manifest: CangjieHumanEvalManifestResult, declaredDatasetVersion: String): String {
    if (!manifest.ok || manifest.rows.size != 164 || manifest.datasetVersion == "") {
        return "authority_manifest_invalid"
    }
    if (declaredDatasetVersion != manifest.datasetVersion) {
        return "authority_dataset_version_mismatch"
    }
    "ok"
}

// Parses the authority with stdx JSON only. All string fields and tag arrays
// fail closed on malformed JSON or a wrong JSON type; no String byte slicing is
// used for model-controlled or Unicode-capable values.
public func parseCangjieHumanEvalAuthorityManifest(text: String): CangjieHumanEvalManifestResult {
    let parsed = CangjieHumanEvalManifestResult()
    var lineNumber: Int64 = 0
    for (line in text.split("\n")) {
        lineNumber += 1
        let raw = line.trimAscii()
        if (raw == "") { continue }
        try {
            let object = JsonValue.fromStr(raw).asObject()
            if (cangjieHumanEvalAuthorityString(object, "schemaVersion") != "cangjie-humaneval-authority-v1") {
                parsed.addDiagnostic("authority_schema_invalid:${lineNumber}")
                continue
            }
            let row = CangjieHumanEvalManifestRow()
            row.caseId = cangjieHumanEvalAuthorityString(object, "caseId")
            row.datasetVersion = cangjieHumanEvalAuthorityString(object, "datasetVersion")
            row.targetVersion = cangjieHumanEvalAuthorityString(object, "targetVersion")
            row.signature = cangjieHumanEvalAuthorityString(object, "signature")
            row.prompt = cangjieHumanEvalAuthorityString(object, "prompt")
            row.promptHash = cangjieHumanEvalAuthorityString(object, "promptHash")
            row.metadataHash = cangjieHumanEvalAuthorityString(object, "metadataHash")
            row.starterHash = cangjieHumanEvalAuthorityString(object, "starterHash")
            row.testsHash = cangjieHumanEvalAuthorityString(object, "testsHash")
            row.translationHash = cangjieHumanEvalAuthorityString(object, "translationHash")
            row.caseHash = cangjieHumanEvalAuthorityString(object, "caseHash")
            cangjieHumanEvalAuthorityTags(object, "requiredKnowledgeTags", row.expectedKnowledgeTags)
            parsed.rows.add(row)
        } catch (_: Exception) {
            parsed.addDiagnostic("authority_json_invalid:${lineNumber}")
        }
    }
    if (parsed.rows.size > 0) {
        parsed.datasetVersion = parsed.rows[0].datasetVersion
        let validated = validateCangjieHumanEvalManifest(parsed, "")
        if (!validated.ok) {
            parsed.ok = false
            for (diagnostic in validated.diagnostics) { parsed.diagnostics.add(diagnostic) }
        }
    } else {
        parsed.addDiagnostic("authority_manifest_empty")
    }
    parsed
}

public func cangjieHumanEvalAuthorityRowForCase(text: String, caseId: String): ?CangjieHumanEvalManifestRow {
    let manifest = parseCangjieHumanEvalAuthorityManifest(text)
    if (!manifest.ok) { return None }
    for (row in manifest.rows) { if (row.caseId == caseId) { return Some(row) } }
    None
}

// Model-visible output intentionally excludes verifier paths, test/translation
// hashes, test commands, reference material, and solution bodies.
public func renderModelVisibleManifest(manifest: CangjieHumanEvalManifestResult): String {
    var out = ""
    for (row in manifest.rows) {
        let visiblePrompt = row.prompt.replace("starter/src/solution.cj", "implementation file")
        out += "{\"schemaVersion\":\"cangjie-humaneval-model-v1\",\"caseId\":\"${row.caseId}\",\"datasetVersion\":\"${row.datasetVersion}\",\"targetVersion\":\"${row.targetVersion}\",\"signature\":\"${cangjieHumanEvalManifestJsonEscape(row.signature)}\",\"prompt\":\"${cangjieHumanEvalManifestJsonEscape(visiblePrompt)}\",\"promptHash\":\"${row.promptHash}\",\"starterHash\":\"${row.starterHash}\",\"requiredKnowledgeTags\":${cangjieHumanEvalManifestTagsJson(row.expectedKnowledgeTags)}}\n"
    }
    out
}

// Verifier output contains integrity hashes and dataset-relative paths, but no
// test/reference body. It must remain outside the model process allowlist.
public func renderVerifierManifest(manifest: CangjieHumanEvalManifestResult): String {
    var out = ""
    for (row in manifest.rows) {
        out += "{\"schemaVersion\":\"cangjie-humaneval-verifier-v1\",\"caseId\":\"${row.caseId}\",\"datasetVersion\":\"${row.datasetVersion}\",\"caseHash\":\"${row.caseHash}\",\"metadataHash\":\"${row.metadataHash}\",\"testsHash\":\"${row.testsHash}\",\"translationHash\":\"${row.translationHash}\",\"testsPath\":\"${row.caseId}/tests\",\"translationPath\":\"${row.caseId}/translation\"}\n"
    }
    out
}

public func cangjieHumanEvalRenderAuthorityManifest(manifest: CangjieHumanEvalManifestResult): String {
    var out = ""
    for (row in manifest.rows) {
        out += "{\"schemaVersion\":\"cangjie-humaneval-authority-v1\",\"id\":\"${row.caseId}\",\"caseId\":\"${row.caseId}\",\"category\":\"unit\",\"datasetVersion\":\"${row.datasetVersion}\",\"targetVersion\":\"${row.targetVersion}\",\"signature\":\"${cangjieHumanEvalManifestJsonEscape(row.signature)}\",\"prompt\":\"${cangjieHumanEvalManifestJsonEscape(row.prompt)}\",\"entryPoint\":\"${row.caseId}/starter\",\"testCommand\":\"verifier-owned\",\"promptHash\":\"${row.promptHash}\",\"metadataHash\":\"${row.metadataHash}\",\"starterHash\":\"${row.starterHash}\",\"testsHash\":\"${row.testsHash}\",\"translationHash\":\"${row.translationHash}\",\"caseHash\":\"${row.caseHash}\",\"expectedKnowledgeTags\":${cangjieHumanEvalManifestTagsJson(row.expectedKnowledgeTags)},\"requiredKnowledgeTags\":${cangjieHumanEvalManifestTagsJson(row.expectedKnowledgeTags)}}\n"
    }
    out
}

private func cangjieHumanEvalBuildManifestRow(caseRoot: Path, caseId: String): CangjieHumanEvalManifestRow {
    let row = CangjieHumanEvalManifestRow()
    row.caseId = caseId
    let prompt = cangjieHumanEvalManifestReadUtf8(caseRoot.join("prompt.md"))
    let metadata = cangjieHumanEvalManifestReadUtf8(caseRoot.join("metadata.json"))
    let starter = cangjieHumanEvalManifestDirectoryHash(caseRoot.join("starter"))
    let tests = cangjieHumanEvalManifestDirectoryHash(caseRoot.join("tests"))
    let translation = cangjieHumanEvalManifestDirectoryHash(caseRoot.join("translation"))
    if (!prompt[0] || !metadata[0] || starter == "" || tests == "" || translation == "") { return row }
    row.prompt = prompt[1]
    row.targetVersion = cangjieHumanEvalManifestJsonString(metadata[1], "targetVersion")
    row.signature = cangjieHumanEvalManifestJsonString(metadata[1], "signature")
    row.promptHash = cangjieHumanEvalManifestHash(prompt[1].toArray())
    row.metadataHash = cangjieHumanEvalManifestHash(metadata[1].toArray())
    row.starterHash = starter
    row.testsHash = tests
    row.translationHash = translation
    for (tag in cangjieHumanEvalManifestInferTags("${prompt[1]}\n${row.signature}")) { row.expectedKnowledgeTags.add(tag) }
    row.caseHash = cangjieHumanEvalManifestRowHash(row)
    row
}

private func cangjieHumanEvalManifestRowHash(row: CangjieHumanEvalManifestRow): String {
    cangjieHumanEvalManifestHash("${row.caseId}|${row.targetVersion}|${row.signature}|${row.promptHash}|${row.metadataHash}|${row.starterHash}|${row.testsHash}|${row.translationHash}".toArray())
}

private func cangjieHumanEvalManifestValidHash(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 71) { return false }
    let prefix = [r's', r'h', r'a', r'2', r'5', r'6', r':']
    for (i in 0..prefix.size) { if (runes[i] != prefix[i]) { return false } }
    for (i in 7..runes.size) {
        let rune = runes[i]
        if (!((rune >= r'0' && rune <= r'9') || (rune >= r'a' && rune <= r'f'))) { return false }
    }
    true
}

private func cangjieHumanEvalAuthorityString(object: JsonObject, key: String): String {
    match (object.get(key)) {
        case Some(value) => value.asString().getValue()
        case None => throw Exception("missing authority field")
    }
}

private func cangjieHumanEvalAuthorityTags(object: JsonObject, key: String, out: ArrayList<String>): Unit {
    match (object.get(key)) {
        case Some(value) => for (item in value.asArray().getItems()) { out.add(item.asString().getValue()) }
        case None => throw Exception("missing authority tags")
    }
}

private func cangjieHumanEvalManifestDirectoryHash(root: Path): String {
    if (!exists(root)) { return "" }
    let files = ArrayList<String>()
    cangjieHumanEvalManifestCollectFiles(root, "", files)
    sort(files)
    let digest = SHA256()
    for (relative in files) {
        let bytes = try { File.readFrom(root.join(relative)) } catch (_: Exception) { return "" }
        digest.write("${relative.size}:${relative}:${bytes.size}:".toArray())
        digest.write(bytes)
    }
    cangjieHumanEvalManifestFinishHash(digest)
}

private func cangjieHumanEvalManifestCollectFiles(current: Path, relativePrefix: String, files: ArrayList<String>): Unit {
    try {
        for (entry in Directory.readFrom(current)) {
            let relative = if (relativePrefix == "") { entry.name } else { "${relativePrefix}/${entry.name}" }
            if (entry.isDirectory()) {
                cangjieHumanEvalManifestCollectFiles(entry.path, relative, files)
            } else {
                files.add(relative)
            }
        }
    } catch (_: Exception) {}
}

private func cangjieHumanEvalDatasetVersion(rows: ArrayList<CangjieHumanEvalManifestRow>): String {
    let digest = SHA256()
    for (row in rows) { digest.write("${row.caseId}|${row.caseHash}\n".toArray()) }
    "cangjie-humaneval-164-${cangjieHumanEvalManifestFinishHash(digest)}"
}

private func cangjieHumanEvalManifestHash(bytes: Array<UInt8>): String {
    let digest = SHA256(); digest.write(bytes); cangjieHumanEvalManifestFinishHash(digest)
}

private func cangjieHumanEvalManifestFinishHash(digest: SHA256): String {
    let out = StringBuilder()
    for (byte in digest.finish()) {
        out.append(cangjieHumanEvalManifestHex(byte / UInt8(16)))
        out.append(cangjieHumanEvalManifestHex(byte % UInt8(16)))
    }
    "sha256:${out.toString()}"
}

private func cangjieHumanEvalManifestHex(value: UInt8): String {
    if (value < UInt8(10)) { return "${value}" }
    if (value == UInt8(10)) { return "a" }; if (value == UInt8(11)) { return "b" }
    if (value == UInt8(12)) { return "c" }; if (value == UInt8(13)) { return "d" }
    if (value == UInt8(14)) { return "e" }; "f"
}

private func cangjieHumanEvalManifestReadUtf8(path: Path): (Bool, String) {
    try { (true, String.fromUtf8(File.readFrom(path))) } catch (_: Exception) { (false, "") }
}

private func cangjieHumanEvalManifestJsonString(raw: String, key: String): String {
    try {
        let object = JsonValue.fromStr(raw).asObject()
        match (object.get(key)) {
            case Some(value) => value.asString().getValue()
            case None => ""
        }
    } catch (_: Exception) { "" }
}

private func cangjieHumanEvalManifestInferTags(text: String): ArrayList<String> {
    let tags = ArrayList<String>()
    let lower = text.toAsciiLower()
    cangjieHumanEvalManifestAddTag(tags, lower.contains("arraylist") || lower.contains("array<"), "ArrayList")
    cangjieHumanEvalManifestAddTag(tags, lower.contains("string") || lower.contains("rune"), "String")
    cangjieHumanEvalManifestAddTag(tags, lower.contains("hashmap"), "HashMap")
    cangjieHumanEvalManifestAddTag(tags, lower.contains("hashset"), "HashSet")
    cangjieHumanEvalManifestAddTag(tags, lower.contains("float64"), "Float64")
    cangjieHumanEvalManifestAddTag(tags, lower.contains("int64"), "Int64")
    cangjieHumanEvalManifestAddTag(tags, lower.contains("bool"), "Bool")
    cangjieHumanEvalManifestAddTag(tags, lower.contains("option"), "Option")
    if (tags.size == 0) { tags.add("Cangjie syntax") }
    tags
}

private func cangjieHumanEvalManifestAddTag(tags: ArrayList<String>, condition: Bool, value: String): Unit {
    if (condition && !tags.contains(value)) { tags.add(value) }
}

private func cangjieHumanEvalManifestTagsJson(tags: ArrayList<String>): String {
    var out = "["
    for (i in 0..tags.size) { if (i > 0) { out += "," }; out += "\"${cangjieHumanEvalManifestJsonEscape(tags[i])}\"" }
    out + "]"
}

private func cangjieHumanEvalManifestJsonEscape(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
}

private func cangjieHumanEvalCaseId(index: Int64): String {
    if (index < 10) { return "CJ-HUMANEVAL-00${index}" }
    if (index < 100) { return "CJ-HUMANEVAL-0${index}" }
    "CJ-HUMANEVAL-${index}"
}
