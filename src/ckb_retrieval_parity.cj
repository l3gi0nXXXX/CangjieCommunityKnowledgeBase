package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.sort.*

public class CkbRetrievalParityHit {
    public var logicalId: String = ""
    public var contentHash: String = ""
    public var citation: String = ""
    public var rank: Int64 = 0
    public init() {}
}

public class CkbRetrievalParityResponse {
    public var ok: Bool = false
    public var diagnostic: String = ""
    public var knowledgeVersion: String = ""
    public var hits: ArrayList<CkbRetrievalParityHit> =
        ArrayList<CkbRetrievalParityHit>()
    public var rawBytes: Array<UInt8> = Array<UInt8>()
    public init() {}
}

public interface CkbRetrievalParityBackend {
    func query(transport: String, query: String):
        CkbRetrievalParityResponse
}

public class CkbRetrievalParityManifest {
    public var schemaVersion: String = "ckb-retrieval-parity-v1"
    public var knowledgeVersion: String = ""
    public var logicalManifestHash: String = ""
    public var query: String = ""
    public var transports: ArrayList<String> = ArrayList<String>()
    public var canonicalResultHash: String = ""
    public init() {}
}

public class CkbRetrievalParityResult {
    public var ok: Bool = false
    public var diagnostic: String = "retrieval_parity_not_run"
    public var manifest: CkbRetrievalParityManifest =
        CkbRetrievalParityManifest()
    public init() {}
}

public func validateCkbRetrievalParityQuery(
    query: String): CkbReproContractResult {
    let lowered = query.toAsciiLower()
    for (forbidden in [
        "humaneval", "pass@1", "hidden test", "reference solution",
        "teacher solution", "case 0", "case 1", "case id"
    ]) {
        if (lowered.contains(forbidden)) {
            return ckbRetrievalParityFailure(
                "retrieval_parity_benchmark_query_forbidden")
        }
    }
    if (query.trimAscii() == "" || query.size > 500) {
        return ckbRetrievalParityFailure(
            "retrieval_parity_query_invalid")
    }
    ckbRetrievalParitySuccess()
}

public func buildCkbRetrievalParityManifest(knowledgeVersion: String,
    logicalManifestHash: String, backend: CkbRetrievalParityBackend):
    CkbRetrievalParityResult {
    let result = CkbRetrievalParityResult()
    let query = "仓颉语言中如何按 Rune 安全遍历 UTF-8 字符串？"
    if (!validateCkbRetrievalParityQuery(query).ok ||
        knowledgeVersion == "" ||
        !ckbRetrievalParityHashValid(logicalManifestHash)) {
        result.diagnostic = "retrieval_parity_identity_invalid"
        return result
    }
    let transports = ["rest", "mcp_stdio", "mcp_http"]
    var expected: String = ""
    for (transport in transports) {
        let response = backend.query(transport, query)
        let canonical = ckbRetrievalParityCanonicalResponse(response)
        if (canonical[0] != "ok") {
            result.diagnostic = canonical[0]
            return result
        }
        if (response.knowledgeVersion != knowledgeVersion) {
            result.diagnostic = "retrieval_parity_knowledge_version_mismatch"
            return result
        }
        if (expected == "") { expected = canonical[1] }
        if (canonical[1] != expected) {
            result.diagnostic = "retrieval_parity_result_mismatch"
            return result
        }
        result.manifest.transports.add(transport)
    }
    result.manifest.knowledgeVersion = knowledgeVersion
    result.manifest.logicalManifestHash = logicalManifestHash
    result.manifest.query = query
    result.manifest.canonicalResultHash =
        benchmarkGapSha256(expected)
    result.ok = true
    result.diagnostic = "ok"
    result
}

public func verifyCkbRetrievalParityManifest(
    manifest: CkbRetrievalParityManifest,
    backend: CkbRetrievalParityBackend): CkbRetrievalParityResult {
    let result = CkbRetrievalParityResult()
    result.manifest = manifest
    if (manifest.schemaVersion != "ckb-retrieval-parity-v1" ||
        manifest.knowledgeVersion == "" ||
        !ckbRetrievalParityHashValid(manifest.logicalManifestHash) ||
        !ckbRetrievalParityHashValid(manifest.canonicalResultHash) ||
        !validateCkbRetrievalParityQuery(manifest.query).ok ||
        manifest.transports.size != 3) {
        result.diagnostic = "retrieval_parity_manifest_invalid"
        return result
    }
    var expected: String = ""
    for (transport in manifest.transports) {
        let response = backend.query(transport, manifest.query)
        let canonical = ckbRetrievalParityCanonicalResponse(response)
        if (canonical[0] != "ok") {
            result.diagnostic = canonical[0]
            return result
        }
        if (response.knowledgeVersion != manifest.knowledgeVersion) {
            result.diagnostic = "retrieval_parity_knowledge_version_mismatch"
            return result
        }
        if (expected == "") { expected = canonical[1] }
        if (canonical[1] != expected ||
            benchmarkGapSha256(canonical[1]) !=
                manifest.canonicalResultHash) {
            result.diagnostic = "retrieval_parity_result_mismatch"
            return result
        }
    }
    result.ok = true
    result.diagnostic = "ok"
    result
}

private func ckbRetrievalParityCanonicalResponse(
    response: CkbRetrievalParityResponse): (String, String) {
    if (!response.ok) {
        return (if (response.diagnostic == "") {
            "retrieval_parity_transport_failed"
        } else { response.diagnostic }, "")
    }
    if (response.rawBytes.size > 0) {
        let decoded = try { String.fromUtf8(response.rawBytes) } catch (_: Exception) {
            return ("invalid_response_encoding", "")
        }
        if (decoded == "") { return ("retrieval_parity_empty_response", "") }
    }
    let rows = ArrayList<String>()
    for (hit in response.hits) {
        if (hit.logicalId == "" || hit.rank <= 0 ||
            !ckbRetrievalParityHashValid(hit.contentHash)) {
            return ("retrieval_parity_hit_invalid", "")
        }
        rows.add("${hit.rank}|${hit.logicalId}|${hit.contentHash}|${hit.citation}")
    }
    if (rows.size == 0) { return ("retrieval_parity_empty_response", "") }
    let ordered = rows.toArray()
    sort(ordered)
    var out = ""
    for (row in ordered) { out += "${row}\n" }
    ("ok", out)
}

private func ckbRetrievalParityHashValid(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 71 || !value.startsWith("sha256:")) { return false }
    for (i in 7..runes.size) {
        if (!((runes[i] >= r'0' && runes[i] <= r'9') ||
            (runes[i] >= r'a' && runes[i] <= r'f'))) { return false }
    }
    true
}

private func ckbRetrievalParityFailure(
    diagnostic: String): CkbReproContractResult {
    let result = CkbReproContractResult()
    result.diagnostic = diagnostic
    result
}

private func ckbRetrievalParitySuccess(): CkbReproContractResult {
    let result = CkbReproContractResult()
    result.ok = true
    result.diagnostic = "ok"
    result
}
