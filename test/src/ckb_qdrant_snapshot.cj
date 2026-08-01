package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashSet}
import std.fs.{Directory, File, OpenMode, Path, canonicalize, exists, remove, rename}
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

public class CkbQdrantSnapshotManifest {
    public var schemaVersion: String = ""
    public var imageDigest: String = ""
    public var qdrantMinorVersion: String = ""
    public var collection: String = ""
    public var distance: String = ""
    public var dimension: Int64 = 0
    public var points: Int64 = 0
    public var snapshotSha256: String = ""
    public var logicalManifestHash: String = ""
    public var vectorProofHash: String = ""
    public var payloadCanonicalHash: String = ""
    public var manifestHash: String = ""
    public init() {}
}

public class CkbQdrantSnapshotContract {
    public var ok: Bool = false
    public var diagnostic: String = "not_validated"
    public var canonicalJson: String = ""
    public var manifestHash: String = ""
    public init() {}
}

public class CkbQdrantSnapshotIdentity {
    public var collection: String = ""
    public var logicalManifestHash: String = ""
    public var vectorProofHash: String = ""
    public init() {}
}

public class CkbQdrantSnapshotRequest {
    public var method: String = "GET"
    public var path: String = ""
    public var contentType: String = ""
    public var bodyBytes: Array<UInt8> = Array<UInt8>()
    public init() {}
}

public class CkbQdrantSnapshotResponse {
    public var statusCode: Int64 = 0
    public var bodyBytes: Array<UInt8> = Array<UInt8>()
    public var diagnostic: String = ""
    public init() {}
}

public interface CkbQdrantSnapshotExecutor {
    func execute(request: CkbQdrantSnapshotRequest):
        CkbQdrantSnapshotResponse
}

public class CkbQdrantSnapshotCreateResult {
    public var ok: Bool = false
    public var diagnostic: String = "snapshot_create_not_run"
    public var snapshotName: String = ""
    public init() {}
}

public class CkbQdrantSnapshotDownloadResult {
    public var ok: Bool = false
    public var diagnostic: String = "snapshot_download_not_run"
    public var bytes: Array<UInt8> = Array<UInt8>()
    public var sha256: String = ""
    public init() {}
}

public class CkbQdrantSnapshotRestoreResult {
    public var ok: Bool = false
    public var diagnostic: String = "snapshot_restore_not_run"
    public init() {}
}

public class CkbQdrantRestoredStatus {
    public var state: String = ""
    public var collection: String = ""
    public var count: Int64 = 0
    public var dimension: Int64 = 0
    public var distance: String = ""
    public var payloadCanonicalHash: String = ""
    public init() {}
}

public class CkbQdrantSnapshotVerification {
    public var ok: Bool = false
    public var ready: Bool = false
    public var diagnostic: String = "snapshot_not_verified"
    public init() {}
}

public class CkbP3CliOptions {
    public var command: String = ""
    public var mode: String = ""
    public var endpoint: String = ""
    public var collection: String = ""
    public var targetCollection: String = ""
    public var candidateRoot: String = ""
    public var environmentLock: String = ""
    public var outputProof: String = ""
    public var logicalManifest: String = ""
    public var vectorProof: String = ""
    public var outputRoot: String = ""
    public var snapshot: String = ""
    public var manifest: String = ""
    public var restEndpoint: String = ""
    public var mcpStdioCommand: String = ""
    public var mcpHttpEndpoint: String = ""
    public var json: Bool = false
    public var diagnostic: String = "not_parsed"
    public init() {}
}

public class CkbP3CliOperationResult {
    public var ok: Bool = false
    public var diagnostic: String = "not_run"
    public var summary: String = ""
    public init() {}
}

public class CkbP3CliExecution {
    public var ok: Bool = false
    public var exitCode: Int64 = 2
    public var diagnostic: String = "not_run"
    public var output: String = ""
    public init() {}
}

public interface CkbP3CliAdapter {
    func execute(options: CkbP3CliOptions): CkbP3CliOperationResult
}

public func parseCkbP3CliOptions(args: Array<String>): CkbP3CliOptions {
    let out = CkbP3CliOptions()
    if (args.size == 0) { out.diagnostic = "p3_command_required"; return out }
    out.command = args[0]
    var i: Int64 = 1
    if (out.command == "ckb-qdrant-snapshot") {
        if (i >= args.size || (args[i] != "create" && args[i] != "restore" && args[i] != "verify")) {
            out.diagnostic = "qdrant_snapshot_mode_required"; return out
        }
        out.mode = args[i]; i += 1
    } else if (out.command == "ckb-portable-vector-build") { out.mode = "build" }
    else if (out.command == "ckb-retrieval-parity") { out.mode = "parity" }
    else { out.diagnostic = "p3_command_required"; return out }
    let seen = HashSet<String>()
    while (i < args.size) {
        let arg = args[i]
        if (arg == "--json") {
            if (seen.contains(arg)) { out.diagnostic = "duplicate_argument:${arg}"; return out }
            seen.add(arg); out.json = true; i += 1; continue
        }
        if (!ckbP3CliKnown(arg)) { out.diagnostic = "unknown_argument:${arg}"; return out }
        if (!ckbP3CliAllowed(out.mode, arg)) {
            out.diagnostic = "argument_not_allowed:${out.mode}:${arg}"; return out
        }
        if (seen.contains(arg)) { out.diagnostic = "duplicate_argument:${arg}"; return out }
        if (i + 1 >= args.size || args[i + 1].startsWith("--")) {
            out.diagnostic = "missing_argument_value:${arg}"; return out
        }
        seen.add(arg); let value = args[i + 1]
        if (arg == "--endpoint") { out.endpoint = value }
        else if (arg == "--collection") { out.collection = value }
        else if (arg == "--target-collection") { out.targetCollection = value }
        else if (arg == "--candidate-root") { out.candidateRoot = value }
        else if (arg == "--environment-lock") { out.environmentLock = value }
        else if (arg == "--output-proof") { out.outputProof = value }
        else if (arg == "--logical-manifest") { out.logicalManifest = value }
        else if (arg == "--vector-proof") { out.vectorProof = value }
        else if (arg == "--output-root") { out.outputRoot = value }
        else if (arg == "--snapshot") { out.snapshot = value }
        else if (arg == "--manifest") { out.manifest = value }
        else if (arg == "--mode") { if (value != "verify") { out.diagnostic = "invalid_argument_value:--mode"; return out } }
        else if (arg == "--rest-endpoint") { out.restEndpoint = value }
        else if (arg == "--mcp-stdio-command") { out.mcpStdioCommand = value }
        else if (arg == "--mcp-http-endpoint") { out.mcpHttpEndpoint = value }
        i += 2
    }
    out.diagnostic = validateCkbP3CliOptions(out); out
}

public func validateCkbP3CliOptions(out: CkbP3CliOptions): String {
    for (pair in ckbP3CliRequired(out)) {
        if (pair[1] == "") { return "required_argument_missing:${pair[0]}" }
    }
    for (endpoint in [out.endpoint, out.restEndpoint, out.mcpHttpEndpoint]) {
        if (endpoint != "" && !(endpoint.startsWith("http://") || endpoint.startsWith("https://"))) {
            return "invalid_endpoint"
        }
    }
    "ok"
}

public func executeCkbP3CliAdapter(args: Array<String>, adapter: CkbP3CliAdapter): CkbP3CliExecution {
    let options = parseCkbP3CliOptions(args)
    if (options.diagnostic != "ok") { return ckbP3CliFailure(options.diagnostic, args.contains("--json")) }
    let result = try { adapter.execute(options) } catch (_: Exception) {
        return ckbP3CliFailure("p3_adapter_execution_failed", options.json)
    }
    let out = CkbP3CliExecution()
    out.ok = result.ok; out.exitCode = if (result.ok) { 0 } else { 1 }
    out.diagnostic = result.diagnostic
    out.output = if (options.json) { renderCkbP3CliJson(result) } else { renderCkbP3CliHuman(result) }
    out
}

public interface CkbP3VerificationInputProvider {
    func visibleInput(collection: String): CkbStudentVisiblePathInput
    func pathContext(collection: String): CkbPortablePathContext
}

public class CkbStoreVerificationInputProvider <:
    CkbP3VerificationInputProvider {
    private let store: FileKnowledgeStore
    private let context: CkbPortablePathContext
    public init(store: FileKnowledgeStore, context: CkbPortablePathContext) {
        this.store = store; this.context = context
    }
    public func visibleInput(collection: String): CkbStudentVisiblePathInput {
        let out = CkbStudentVisiblePathInput()
        let snapshot = this.store.loadActiveSnapshot()
        if (!snapshot.valid || snapshot.vectorActiveCollection != collection) {
            return out
        }
        for (record in snapshot.rawRecords) { out.rawRecords.add(record) }
        for (record in snapshot.normalizedRecords) { out.normalizedRecords.add(record) }
        for (record in snapshot.activeIndex) { out.activeRecords.add(record) }
        for (record in snapshot.vectorRecords) { out.vectorRecords.add(record) }
        out
    }
    public func pathContext(collection: String): CkbPortablePathContext {
        this.context
    }
}

public class CkbP3ProductionAdapter <: CkbP3CliAdapter {
    private let vectorBackend: CkbPortableVectorBuildBackend
    private let snapshotExecutor: CkbQdrantSnapshotExecutor
    private let parityBackend: CkbRetrievalParityBackend
    private let verificationProvider: CkbP3VerificationInputProvider
    private let pathPolicy: CkbReleasePathPolicy
    public init(vectorBackend: CkbPortableVectorBuildBackend,
        snapshotExecutor: CkbQdrantSnapshotExecutor,
        parityBackend: CkbRetrievalParityBackend,
        verificationProvider: CkbP3VerificationInputProvider,
        pathPolicy: CkbReleasePathPolicy) {
        this.vectorBackend = vectorBackend; this.snapshotExecutor = snapshotExecutor
        this.parityBackend = parityBackend; this.verificationProvider = verificationProvider
        this.pathPolicy = pathPolicy
    }

    public func execute(options: CkbP3CliOptions): CkbP3CliOperationResult {
        if (options.mode == "build") { return this.buildVectors(options) }
        if (options.mode == "create") { return this.createSnapshot(options) }
        if (options.mode == "restore") { return this.restoreSnapshot(options) }
        if (options.mode == "verify") { return this.verifySnapshot(options) }
        this.verifyParity(options)
    }

    private func buildVectors(options: CkbP3CliOptions): CkbP3CliOperationResult {
        let out = CkbP3CliOperationResult()
        let buildProof = ckbP3LoadBuildProof(options.candidateRoot)
        if (!buildProof[0].ok) { out.diagnostic = buildProof[0].diagnostic; return out }
        let environment = ckbP3LoadEnvironment(options.environmentLock)
        if (!environment[0].ok) { out.diagnostic = environment[0].diagnostic; return out }
        let store = FileKnowledgeStore(options.candidateRoot)
        let pointer = store.loadActiveSnapshotPointer(); let metadata = store.loadMetadataStatus()
        if (!pointer.valid || !metadata.valid) { out.diagnostic = "portable_vector_candidate_invalid"; return out }
        let buildOptions = CkbPortableVectorBuildOptions()
        buildOptions.candidateVersion = pointer.activeVersion
        buildOptions.p4PortableProofHash = buildProof[1].preservationHash
        buildOptions.runtimeVectorState = metadata.vectorState
        buildOptions.runtimeVectorDegradedReason = metadata.vectorDegradedReason
        buildOptions.runtimeVectorCount = metadata.vectorIndexCount
        let result = buildCkbPortableReferenceVectors(buildOptions, buildProof[1],
            environment[1], this.vectorBackend)
        if (!result.ready) { out.diagnostic = result.diagnostic; return out }
        let write = ckbP3WriteNewFile(options.outputProof,
            renderCkbPortableVectorProof(result.proof), this.pathPolicy)
        if (write != "ok") { out.diagnostic = write; return out }
        out.ok = true; out.diagnostic = "ok"
        out.summary = "collection=${result.proof.collection} points=${result.proof.count} " +
            "dimension=${result.proof.dimension}"; out
    }

    private func createSnapshot(options: CkbP3CliOptions): CkbP3CliOperationResult {
        let out = CkbP3CliOperationResult()
        let logical = ckbP3LoadLogicalManifest(options.logicalManifest)
        if (!logical[0].ok) { out.diagnostic = logical[0].diagnostic; return out }
        let vector = parseCkbPortableVectorProofFile(options.vectorProof)
        if (!vector[0].ok) { out.diagnostic = vector[0].diagnostic; return out }
        if (vector[1].collection != options.collection ||
            logical[1].vectorCollection != options.collection ||
            logical[1].p3VectorProofHash != vector[1].vectorProofHash) {
            out.diagnostic = "qdrant_snapshot_identity_mismatch"; return out
        }
        let identity = CkbQdrantSnapshotIdentity(); identity.collection = options.collection
        identity.logicalManifestHash = logical[1].manifestHash
        identity.vectorProofHash = vector[1].vectorProofHash
        let created = createCkbQdrantSnapshot(identity, this.snapshotExecutor)
        if (!created.ok) { out.diagnostic = created.diagnostic; return out }
        let downloaded = downloadCkbQdrantSnapshot(identity, created.snapshotName,
            this.snapshotExecutor)
        if (!downloaded.ok) { out.diagnostic = downloaded.diagnostic; return out }
        let manifest = CkbQdrantSnapshotManifest()
        manifest.schemaVersion = "ckb-qdrant-snapshot-v1"
        manifest.imageDigest = vector[1].qdrantImageDigest
        manifest.qdrantMinorVersion = "1.14"; manifest.collection = options.collection
        manifest.distance = vector[1].distance; manifest.dimension = vector[1].dimension
        manifest.points = vector[1].count; manifest.snapshotSha256 = downloaded.sha256
        manifest.logicalManifestHash = logical[1].manifestHash
        manifest.vectorProofHash = vector[1].vectorProofHash
        manifest.payloadCanonicalHash = vector[1].payloadCanonicalHash
        let built = buildCkbQdrantSnapshotManifest(manifest)
        if (!built.ok) { out.diagnostic = built.diagnostic; return out }
        let write = ckbP3WriteSnapshotDirectory(options.outputRoot, downloaded.bytes,
            built.canonicalJson, this.pathPolicy)
        if (write != "ok") { out.diagnostic = write; return out }
        out.ok = true; out.diagnostic = "ok"
        out.summary = "collection=${manifest.collection} points=${manifest.points} " +
            "dimension=${manifest.dimension}"; out
    }

    private func restoreSnapshot(options: CkbP3CliOptions): CkbP3CliOperationResult {
        let out = CkbP3CliOperationResult(); let manifest = ckbP3LoadSnapshotManifest(options.manifest)
        if (!manifest[0].ok) { out.diagnostic = manifest[0].diagnostic; return out }
        let bytes = try { File.readFrom(Path(options.snapshot)) } catch (_: Exception) {
            out.diagnostic = "qdrant_snapshot_file_unreadable"; return out
        }
        let result = restoreCkbQdrantSnapshot(options.targetCollection, bytes,
            manifest[1], this.snapshotExecutor)
        out.ok = result.ok; out.diagnostic = result.diagnostic
        out.summary = "collection=${options.targetCollection}"; out
    }

    private func verifySnapshot(options: CkbP3CliOptions): CkbP3CliOperationResult {
        let out = CkbP3CliOperationResult(); let manifest = ckbP3LoadSnapshotManifest(options.manifest)
        if (!manifest[0].ok) { out.diagnostic = manifest[0].diagnostic; return out }
        let logical = ckbP3LoadLogicalManifest(options.logicalManifest)
        if (!logical[0].ok) { out.diagnostic = logical[0].diagnostic; return out }
        let request = CkbQdrantSnapshotRequest(); request.method = "GET"
        request.path = "/collections/${options.collection}"
        let response = this.snapshotExecutor.execute(request)
        let status = parseCkbQdrantRestoredStatus(response.bodyBytes,
            options.collection, manifest[1].payloadCanonicalHash)
        if (!status[0].ok) { out.diagnostic = status[0].diagnostic; return out }
        let verified = verifyRestoredCkbQdrantSnapshot(status[1], manifest[1], logical[1],
            this.verificationProvider.visibleInput(options.collection),
            this.verificationProvider.pathContext(options.collection))
        out.ok = verified.ok; out.diagnostic = verified.diagnostic
        out.summary = "collection=${options.collection} points=${status[1].count} " +
            "dimension=${status[1].dimension}"; out
    }

    private func verifyParity(options: CkbP3CliOptions): CkbP3CliOperationResult {
        let out = CkbP3CliOperationResult(); let manifest = ckbP3LoadParityManifest(options.manifest)
        if (!manifest[0].ok) { out.diagnostic = manifest[0].diagnostic; return out }
        let result = verifyCkbRetrievalParityManifest(manifest[1], this.parityBackend)
        out.ok = result.ok; out.diagnostic = result.diagnostic
        out.summary = "knowledgeVersion=${manifest[1].knowledgeVersion} transports=3"; out
    }
}

// Binary Qdrant HTTP and REST/MCP parity remain explicit transport seams.
// Vector rebuilding and verification input loading are production-owned here.
public func newCkbP3BusinessProductionAdapter(embeddingProvider: EmbeddingProvider,
    candidateStore: FileKnowledgeStore, vectorStore: VectorStore,
    pathContext: CkbPortablePathContext,
    snapshotExecutor: CkbQdrantSnapshotExecutor,
    parityBackend: CkbRetrievalParityBackend,
    pathPolicy: CkbReleasePathPolicy,
    deadlineAtMillis!: Int64 = 0): CkbP3CliAdapter {
    CkbP3ProductionAdapter(
        CkbPortableVectorProductionBackend(embeddingProvider, candidateStore, vectorStore,
            pathContext, deadlineAtMillis: deadlineAtMillis),
        snapshotExecutor, parityBackend,
        CkbStoreVerificationInputProvider(candidateStore, pathContext),
        pathPolicy)
}

public func newCkbP3ProductionAdapter(vectorBackend: CkbPortableVectorBuildBackend,
    snapshotExecutor: CkbQdrantSnapshotExecutor, parityBackend: CkbRetrievalParityBackend,
    verificationProvider: CkbP3VerificationInputProvider,
    pathPolicy: CkbReleasePathPolicy): CkbP3CliAdapter {
    CkbP3ProductionAdapter(vectorBackend, snapshotExecutor, parityBackend,
        verificationProvider, pathPolicy)
}
public func runCkbP3Cli(args: Array<String>, context: CkbP3CliAdapter): CkbP3CliExecution {
    executeCkbP3CliAdapter(args, context)
}
public func renderCkbP3CliHuman(result: CkbP3CliOperationResult): String {
    if (result.ok) { "CKB portable vector operation completed. ${ckbP3CliSafe(result.summary)}\n" }
    else { "CKB portable vector operation failed: ${ckbP3CliSafe(result.diagnostic)}\n" }
}
public func renderCkbP3CliJson(result: CkbP3CliOperationResult): String {
    "{\"ok\":${result.ok},\"diagnostic\":\"${ckbP3CliJson(result.diagnostic)}\"," +
        "\"summary\":\"${ckbP3CliJson(result.summary)}\"}"
}

private func ckbP3CliKnown(arg: String): Bool { ["--endpoint", "--collection", "--target-collection",
    "--candidate-root", "--environment-lock", "--output-proof", "--logical-manifest",
    "--vector-proof", "--output-root", "--snapshot", "--manifest", "--mode",
    "--rest-endpoint", "--mcp-stdio-command", "--mcp-http-endpoint"].contains(arg) }
private func ckbP3CliAllowed(mode: String, arg: String): Bool {
    if (mode == "build") { return ["--candidate-root", "--environment-lock", "--output-proof"].contains(arg) }
    if (mode == "create") { return ["--endpoint", "--collection", "--logical-manifest", "--vector-proof", "--output-root"].contains(arg) }
    if (mode == "restore") { return ["--endpoint", "--target-collection", "--snapshot", "--manifest"].contains(arg) }
    if (mode == "verify") { return ["--endpoint", "--collection", "--manifest", "--logical-manifest"].contains(arg) }
    ["--mode", "--manifest", "--rest-endpoint", "--mcp-stdio-command", "--mcp-http-endpoint"].contains(arg)
}
private func ckbP3CliRequired(out: CkbP3CliOptions): Array<(String, String)> {
    if (out.mode == "build") { return [("--candidate-root", out.candidateRoot), ("--environment-lock", out.environmentLock), ("--output-proof", out.outputProof)] }
    if (out.mode == "create") { return [("--endpoint", out.endpoint), ("--collection", out.collection), ("--logical-manifest", out.logicalManifest), ("--vector-proof", out.vectorProof), ("--output-root", out.outputRoot)] }
    if (out.mode == "restore") { return [("--endpoint", out.endpoint), ("--target-collection", out.targetCollection), ("--snapshot", out.snapshot), ("--manifest", out.manifest)] }
    if (out.mode == "verify") { return [("--endpoint", out.endpoint), ("--collection", out.collection), ("--manifest", out.manifest), ("--logical-manifest", out.logicalManifest)] }
    [("--mode", if (out.mode == "parity") { "verify" } else { "" }), ("--manifest", out.manifest), ("--rest-endpoint", out.restEndpoint), ("--mcp-stdio-command", out.mcpStdioCommand), ("--mcp-http-endpoint", out.mcpHttpEndpoint)]
}
private func ckbP3CliFailure(diagnostic: String, json: Bool): CkbP3CliExecution {
    let result = CkbP3CliOperationResult(); result.diagnostic = diagnostic
    let out = CkbP3CliExecution(); out.diagnostic = diagnostic
    out.output = if (json) { renderCkbP3CliJson(result) } else { renderCkbP3CliHuman(result) }; out
}
private func ckbP3CliSafe(value: String): String { let runes = redactSensitive(value).toRuneArray(); let n = if (runes.size < 160) { runes.size } else { 160 }; let out = StringBuilder(); for (i in 0..n) { out.append(runes[i]) }; out.toString() }
private func ckbP3CliJson(value: String): String { let out = StringBuilder(); let hex = "0123456789abcdef".toRuneArray(); for (rune in ckbP3CliSafe(value).runes()) { if (rune == r'"') { out.append("\\\"") } else if (rune == r'\\') { out.append("\\\\") } else if (rune == r'\n') { out.append("\\n") } else if (rune == r'\r') { out.append("\\r") } else if (rune == r'\t') { out.append("\\t") } else if (UInt32(rune) < 0x20u32) { let code = UInt32(rune); out.append("\\u00"); out.append(hex[Int64(code / 16u32)]); out.append(hex[Int64(code % 16u32)]) } else { out.append(rune) } }; out.toString() }

public func renderCkbPortableVectorProof(proof: CkbPortableVectorProof): String {
    "{\"collection\":\"${ckbQdrantSnapshotJson(proof.collection)}\"," +
        "\"candidateVersion\":\"${ckbQdrantSnapshotJson(proof.candidateVersion)}\"," +
        "\"p4PortableProofHash\":\"${proof.p4PortableProofHash}\"," +
        "\"qdrantImageDigest\":\"${proof.qdrantImageDigest}\"," +
        "\"embeddingProvider\":\"${ckbQdrantSnapshotJson(proof.embeddingProvider)}\"," +
        "\"embeddingModel\":\"${ckbQdrantSnapshotJson(proof.embeddingModel)}\"," +
        "\"count\":${proof.count},\"dimension\":${proof.dimension}," +
        "\"distance\":\"${ckbQdrantSnapshotJson(proof.distance)}\"," +
        "\"payloadCanonicalHash\":\"${proof.payloadCanonicalHash}\"," +
        "\"vectorProofHash\":\"${proof.vectorProofHash}\"," +
        "\"vectorState\":\"READY\",\"proofReal\":true}"
}

public func parseCkbPortableVectorProofFile(path: String):
    (CkbReproContractResult, CkbPortableVectorProof) {
    let read = ckbP3ReadBoundedUtf8(path, "portable_vector_proof")
    if (read[0] != "ok") {
        return (ckbP3ContractFailure(read[0]), CkbPortableVectorProof())
    }
    parseCkbPortableVectorProofBytes(read[1].toArray())
}

public func parseCkbPortableVectorProofBytes(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbPortableVectorProof) {
    let proof = CkbPortableVectorProof()
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (ckbP3ContractFailure("invalid_response_encoding"), proof)
    }
    try {
        let object = JsonValue.fromStr(text).asObject()
        if (object.size() != 13) {
            return (ckbP3ContractFailure(
                "portable_vector_proof_field_contract_invalid"), proof)
        }
        proof.collection = ckbP3RequiredString(object, "collection")
        proof.candidateVersion = ckbP3RequiredString(object, "candidateVersion")
        proof.p4PortableProofHash = ckbP3RequiredString(object, "p4PortableProofHash")
        proof.qdrantImageDigest = ckbP3RequiredString(object, "qdrantImageDigest")
        proof.embeddingProvider = ckbP3RequiredString(object, "embeddingProvider")
        proof.embeddingModel = ckbP3RequiredString(object, "embeddingModel")
        proof.count = ckbP3RequiredInt(object, "count")
        proof.dimension = ckbP3RequiredInt(object, "dimension")
        proof.distance = ckbP3RequiredString(object, "distance")
        proof.payloadCanonicalHash = ckbP3RequiredString(object, "payloadCanonicalHash")
        proof.vectorProofHash = ckbP3RequiredString(object, "vectorProofHash")
        if (ckbP3RequiredString(object, "vectorState") != "READY" ||
            !ckbP3RequiredBool(object, "proofReal")) {
            return (ckbP3ContractFailure("portable_vector_proof_not_real_ready"), proof)
        }
    } catch (_: Exception) {
        return (ckbP3ContractFailure("portable_vector_proof_malformed_json"), proof)
    }
    for (hash in [proof.p4PortableProofHash, proof.qdrantImageDigest,
        proof.payloadCanonicalHash, proof.vectorProofHash]) {
        if (!ckbQdrantSnapshotHashValid(hash)) {
            return (ckbP3ContractFailure("portable_vector_proof_invalid"), proof)
        }
    }
    if (proof.vectorProofHash != ckbPortableVectorProofHash(proof)) {
        return (ckbP3ContractFailure("portable_vector_proof_hash_mismatch"), proof)
    }
    if (!ckbQdrantSnapshotCollectionValid(proof.collection) || proof.count != 7978 ||
        proof.dimension != 1024 || proof.distance.toAsciiLower() != "cosine") {
        return (ckbP3ContractFailure("portable_vector_proof_invalid"), proof)
    }
    (ckbP3ContractSuccess(), proof)
}

private func ckbP3LoadBuildProof(candidateRoot: String):
    (CkbReproContractResult, CkbReproBuildProof) {
    let proof = CkbReproBuildProof()
    let read = ckbP3ReadBoundedUtf8(
        Path(candidateRoot).join("repro-build-proof.json").toString(), "p4_proof")
    if (read[0] != "ok") { return (ckbP3ContractFailure(read[0]), proof) }
    try {
        let object = JsonValue.fromStr(read[1]).asObject()
        proof.logicalReady = ckbP3RequiredBool(object, "logicalReady")
        proof.diagnostic = ckbP3RequiredString(object, "diagnostic")
        proof.sourceLockHash = ckbP3RequiredString(object, "sourceLockHash")
        proof.typedCount = ckbP3RequiredInt(object, "typedCount")
        proof.rawCount = ckbP3RequiredInt(object, "rawCount")
        proof.selectedCount = ckbP3RequiredInt(object, "selectedCount")
        proof.excludedCount = ckbP3RequiredInt(object, "excludedCount")
        proof.evalSupportPersisted = ckbP3RequiredInt(object, "evalSupportPersisted")
        proof.vectorCount = ckbP3RequiredInt(object, "vectorCount")
        proof.vectorState = ckbP3RequiredString(object, "vectorState")
        proof.candidateVersion = ckbP3RequiredString(object, "candidateVersion")
        proof.typedPairAggregateHash =
            ckbP3RequiredString(object, "typedPairAggregateHash")
        proof.rawPairAggregateHash =
            ckbP3RequiredString(object, "rawPairAggregateHash")
        proof.preservationHash = ckbP3RequiredString(object, "preservationHash")
    } catch (_: Exception) { return (ckbP3ContractFailure("p4_proof_malformed_json"), proof) }
    if (!proof.logicalReady || proof.diagnostic != "ok" || proof.vectorState != "DEGRADED" ||
        proof.vectorCount != 0 || proof.candidateVersion == "" ||
        !ckbQdrantSnapshotHashValid(proof.typedPairAggregateHash) ||
        !ckbQdrantSnapshotHashValid(proof.rawPairAggregateHash) ||
        !ckbQdrantSnapshotHashValid(proof.preservationHash)) {
        return (ckbP3ContractFailure("p4_proof_invalid"), proof)
    }
    if (proof.preservationHash != ckbReproBuildPreservationHash(proof)) {
        return (ckbP3ContractFailure("p4_proof_hash_mismatch"), proof)
    }
    (ckbP3ContractSuccess(), proof)
}

private func ckbP3LoadEnvironment(path: String):
    (CkbReproContractResult, CkbReproEnvironmentLock) {
    let read = ckbP3ReadBoundedBytes(path, "environment_lock")
    if (read[0] != "ok") {
        return (ckbP3ContractFailure(read[0]), CkbReproEnvironmentLock())
    }
    let parsed = parseCkbReproEnvironmentLock(read[1])
    if (!parsed[0].ok) { return parsed }
    (validateCkbReproEnvironmentLock(parsed[1], mode: "execution"), parsed[1])
}

private func ckbP3LoadLogicalManifest(path: String):
    (CkbLogicalSnapshotContract, CkbLogicalSnapshotManifest) {
    let read = ckbP3ReadBoundedBytes(path, "logical_manifest")
    if (read[0] != "ok") {
        return (ckbQdrantLogicalFailure(read[0]), CkbLogicalSnapshotManifest())
    }
    let parsed = parseCkbLogicalSnapshotManifest(read[1])
    if (!parsed[0].ok) { return parsed }
    (validateCkbLogicalSnapshotManifest(parsed[1]), parsed[1])
}

private func ckbP3LoadSnapshotManifest(path: String):
    (CkbQdrantSnapshotContract, CkbQdrantSnapshotManifest) {
    let read = ckbP3ReadBoundedBytes(path, "qdrant_snapshot_manifest")
    if (read[0] != "ok") {
        return (ckbQdrantSnapshotFailure(read[0]),
            CkbQdrantSnapshotManifest())
    }
    let parsed = parseCkbQdrantSnapshotManifest(read[1])
    if (!parsed[0].ok) { return parsed }
    (validateCkbQdrantSnapshotManifest(parsed[1]), parsed[1])
}

private func ckbP3LoadParityManifest(path: String):
    (CkbReproContractResult, CkbRetrievalParityManifest) {
    let manifest = CkbRetrievalParityManifest()
    let read = ckbP3ReadBoundedUtf8(path, "retrieval_parity")
    if (read[0] != "ok") { return (ckbP3ContractFailure(read[0]), manifest) }
    try {
        let object = JsonValue.fromStr(read[1]).asObject()
        manifest.schemaVersion = ckbP3RequiredString(object, "schemaVersion")
        manifest.knowledgeVersion = ckbP3RequiredString(object, "knowledgeVersion")
        manifest.logicalManifestHash = ckbP3RequiredString(object, "logicalManifestHash")
        manifest.query = ckbP3RequiredString(object, "query")
        manifest.canonicalResultHash = ckbP3RequiredString(object, "canonicalResultHash")
        for (item in object.get("transports").getOrThrow().asArray().getItems()) {
            manifest.transports.add(item.asString().getValue())
        }
    } catch (_: Exception) { return (ckbP3ContractFailure("retrieval_parity_malformed_json"), manifest) }
    if (manifest.transports.toArray() != ["rest", "mcp_stdio", "mcp_http"]) {
        return (ckbP3ContractFailure("retrieval_parity_manifest_invalid"), manifest)
    }
    (ckbP3ContractSuccess(), manifest)
}

public func ckbP3WriteNewFile(path: String, text: String,
    policy: CkbReleasePathPolicy): String {
    let diagnostic = ckbP3NewOutputDiagnostic(path, policy)
    if (diagnostic != "ok") { return diagnostic }
    let temporary = ckbP3OwnedTemporary(path, "proof")
    if (temporary == "") { return "p3_output_commit_failed" }
    try {
        File.writeTo(Path(temporary), text.toArray())
        rename(temporary, to: path, overwrite: false); "ok"
    } catch (_: Exception) { "p3_output_commit_failed" }
    finally { if (exists(Path(temporary))) { try { remove(Path(temporary), recursive: true) } catch (_: Exception) { () } } }
}

public func ckbP3WriteSnapshotDirectory(path: String, snapshot: Array<UInt8>,
    manifest: String, policy: CkbReleasePathPolicy): String {
    let diagnostic = ckbP3NewOutputDiagnostic(path, policy)
    if (diagnostic != "ok") { return diagnostic }
    let temporary = ckbP3OwnedTemporary(path, "snapshot")
    if (temporary == "") { return "p3_output_commit_failed" }
    try {
        Directory.create(Path(temporary), recursive: false)
        File.writeTo(Path(temporary).join("snapshot.bin"), snapshot)
        File.writeTo(Path(temporary).join("manifest.json"), manifest.toArray())
        let check = parseCkbQdrantSnapshotManifest(
            File.readFrom(Path(temporary).join("manifest.json")))
        if (!check[0].ok || ckbQdrantSnapshotBytesHash(
            File.readFrom(Path(temporary).join("snapshot.bin"))) != check[1].snapshotSha256) {
            return "qdrant_snapshot_output_verification_failed"
        }
        rename(temporary, to: path, overwrite: false); "ok"
    } catch (_: Exception) { "p3_output_commit_failed" }
    finally { if (exists(Path(temporary))) { try { remove(Path(temporary), recursive: true) } catch (_: Exception) { () } } }
}

private func ckbP3OwnedTemporary(path: String, kind: String): String {
    for (value in 0..64) {
        let candidate = "${path}.tmp-${kind}-owned-${value}"
        if (!exists(Path(candidate))) { return candidate }
    }
    ""
}

private func ckbP3ReadBoundedBytes(path: String, kind: String):
    (String, Array<UInt8>) {
    let bytes = ArrayList<UInt8>()
    try {
        try (file = File(Path(path), OpenMode.Read)) {
            while (true) {
                let buffer = Array<UInt8>(16000, repeat: UInt8(0))
                let count = file.read(buffer)
                if (count < 0 || count > buffer.size) {
                    return ("${kind}_read_failed", Array<UInt8>())
                }
                if (count == 0) { break }
                if (bytes.size > 65536 - count) {
                    return ("${kind}_size_invalid", Array<UInt8>())
                }
                for (i in 0..count) { bytes.add(buffer[i]) }
            }
        }
    } catch (_: Exception) { return ("${kind}_unreadable", Array<UInt8>()) }
    ("ok", bytes.toArray())
}

private func ckbP3ReadBoundedUtf8(path: String, kind: String): (String, String) {
    let read = ckbP3ReadBoundedBytes(path, kind)
    if (read[0] != "ok") { return (read[0], "") }
    try { ("ok", String.fromUtf8(read[1])) }
    catch (_: Exception) { ("invalid_response_encoding", "") }
}

private func ckbP3NewOutputDiagnostic(pathText: String,
    policy: CkbReleasePathPolicy): String {
    if (pathText == "" || !pathText.startsWith("/") || pathText != pathText.trimAscii() ||
        pathText.contains("//") || pathText.contains("/../") || pathText.contains("/./") ||
        exists(Path(pathText)) || !exists(Path(pathText).parent)) { return "p3_output_path_invalid" }
    let parent = try { canonicalize(Path(pathText).parent).toString() }
        catch (_: Exception) { return "p3_output_path_invalid" }
    if (Path(parent).join(Path(pathText).fileName).toString() != pathText) {
        return "p3_output_path_invalid"
    }
    for (root in [policy.worktreeRoot, policy.productionStoreRoot, policy.userConfigRoot]) {
        let protected = ckbP3CanonicalPolicyRoot(root)
        if (protected != "" && (pathText == protected ||
            pathText.startsWith("${protected}/") ||
            protected.startsWith("${pathText}/"))) {
            return "p3_output_path_forbidden"
        }
    }
    "ok"
}

private func ckbP3CanonicalPolicyRoot(value: String): String {
    if (value == "" || !value.startsWith("/")) { return "" }
    let path = Path(value)
    if (exists(path)) {
        return try { canonicalize(path).toString() } catch (_: Exception) { "" }
    }
    let parent = try { canonicalize(path.parent) } catch (_: Exception) { return "" }
    parent.join(path.fileName).toString()
}

private func ckbP3RequiredString(object: JsonObject, key: String): String {
    object.get(key).getOrThrow().asString().getValue()
}
private func ckbP3RequiredInt(object: JsonObject, key: String): Int64 {
    object.get(key).getOrThrow().asInt().getValue()
}
private func ckbP3RequiredBool(object: JsonObject, key: String): Bool {
    object.get(key).getOrThrow().asBool().getValue()
}
private func ckbP3ContractSuccess(): CkbReproContractResult {
    let result = CkbReproContractResult(); result.ok = true; result.diagnostic = "ok"; result
}
private func ckbP3ContractFailure(diagnostic: String): CkbReproContractResult {
    let result = CkbReproContractResult(); result.diagnostic = diagnostic; result
}
private func ckbQdrantLogicalFailure(diagnostic: String): CkbLogicalSnapshotContract {
    let result = CkbLogicalSnapshotContract(); result.diagnostic = diagnostic; result
}

public func parseCkbQdrantRestoredStatus(bytes: Array<UInt8>,
    collection: String, payloadCanonicalHash: String):
    (CkbQdrantSnapshotContract, CkbQdrantRestoredStatus) {
    let status = CkbQdrantRestoredStatus()
    status.collection = collection
    status.payloadCanonicalHash = payloadCanonicalHash
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (ckbQdrantSnapshotFailure("invalid_response_encoding"), status)
    }
    try {
        let object = JsonValue.fromStr(text).asObject()
        let result = object.get("result").getOrThrow().asObject()
        status.state = ckbQdrantSnapshotString(result, "status")
        status.count = ckbQdrantSnapshotInt(result, "points_count")
        let config = result.get("config").getOrThrow().asObject()
        let params = config.get("params").getOrThrow().asObject()
        let vectors = params.get("vectors").getOrThrow().asObject()
        status.dimension = ckbQdrantSnapshotInt(vectors, "size")
        status.distance = ckbQdrantSnapshotString(vectors, "distance")
    } catch (_: Exception) {
        return (ckbQdrantSnapshotFailure(
            "qdrant_snapshot_status_response_invalid"),
            CkbQdrantRestoredStatus())
    }
    (ckbQdrantSnapshotSuccess(), status)
}

public func parseCkbQdrantSnapshotManifest(bytes: Array<UInt8>):
    (CkbQdrantSnapshotContract, CkbQdrantSnapshotManifest) {
    let manifest = CkbQdrantSnapshotManifest()
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (ckbQdrantSnapshotFailure("invalid_response_encoding"), manifest)
    }
    try {
        let object = JsonValue.fromStr(text).asObject()
        if (object.size() != 12) {
            return (ckbQdrantSnapshotFailure(
                "qdrant_snapshot_field_contract_invalid"), manifest)
        }
        manifest.schemaVersion = ckbQdrantSnapshotString(object, "schemaVersion")
        manifest.imageDigest = ckbQdrantSnapshotString(object, "imageDigest")
        manifest.qdrantMinorVersion =
            ckbQdrantSnapshotString(object, "qdrantMinorVersion")
        manifest.collection = ckbQdrantSnapshotString(object, "collection")
        manifest.distance = ckbQdrantSnapshotString(object, "distance")
        manifest.dimension = ckbQdrantSnapshotInt(object, "dimension")
        manifest.points = ckbQdrantSnapshotInt(object, "points")
        manifest.snapshotSha256 =
            ckbQdrantSnapshotString(object, "snapshotSha256")
        manifest.logicalManifestHash =
            ckbQdrantSnapshotString(object, "logicalManifestHash")
        manifest.vectorProofHash =
            ckbQdrantSnapshotString(object, "vectorProofHash")
        manifest.payloadCanonicalHash =
            ckbQdrantSnapshotString(object, "payloadCanonicalHash")
        manifest.manifestHash =
            ckbQdrantSnapshotString(object, "manifestHash")
    } catch (_: Exception) {
        return (ckbQdrantSnapshotFailure(
            "qdrant_snapshot_field_contract_invalid"),
            CkbQdrantSnapshotManifest())
    }
    (ckbQdrantSnapshotSuccess(), manifest)
}

public func buildCkbQdrantSnapshotManifest(
    manifest: CkbQdrantSnapshotManifest): CkbQdrantSnapshotContract {
    let structural = ckbQdrantSnapshotValidateStructure(manifest)
    if (!structural.ok) { return structural }
    manifest.manifestHash = ckbQdrantSnapshotBytesHash(
        ckbQdrantSnapshotManifestBody(manifest).toArray())
    let result = ckbQdrantSnapshotSuccess()
    result.manifestHash = manifest.manifestHash
    result.canonicalJson = renderCkbQdrantSnapshotManifest(manifest)
    result
}

public func validateCkbQdrantSnapshotManifest(
    manifest: CkbQdrantSnapshotManifest): CkbQdrantSnapshotContract {
    let structural = ckbQdrantSnapshotValidateStructure(manifest)
    if (!structural.ok) { return structural }
    let expected = ckbQdrantSnapshotBytesHash(
        ckbQdrantSnapshotManifestBody(manifest).toArray())
    if (manifest.manifestHash != expected) {
        return ckbQdrantSnapshotFailure(
            "qdrant_snapshot_manifest_hash_mismatch")
    }
    let result = ckbQdrantSnapshotSuccess()
    result.manifestHash = expected
    result.canonicalJson = renderCkbQdrantSnapshotManifest(manifest)
    result
}

public func renderCkbQdrantSnapshotManifest(
    manifest: CkbQdrantSnapshotManifest): String {
    ckbQdrantSnapshotManifestBody(manifest) +
        ",\"manifestHash\":\"${manifest.manifestHash}\"}"
}

public func createCkbQdrantSnapshot(identity: CkbQdrantSnapshotIdentity,
    executor: CkbQdrantSnapshotExecutor): CkbQdrantSnapshotCreateResult {
    let result = CkbQdrantSnapshotCreateResult()
    if (!ckbQdrantSnapshotIdentityValid(identity)) {
        result.diagnostic = "qdrant_snapshot_identity_invalid"
        return result
    }
    let request = CkbQdrantSnapshotRequest()
    request.method = "POST"
    request.path =
        "/collections/${identity.collection}/snapshots"
    let response = executor.execute(request)
    if (response.statusCode < 200 || response.statusCode >= 300) {
        result.diagnostic = "qdrant_snapshot_create_failed"
        return result
    }
    let text = try { String.fromUtf8(response.bodyBytes) } catch (_: Exception) {
        result.diagnostic = "invalid_response_encoding"
        return result
    }
    try {
        let object = JsonValue.fromStr(text).asObject()
        let payload = object.get("result").getOrThrow().asObject()
        result.snapshotName = payload.get("name").getOrThrow().
            asString().getValue()
    } catch (_: Exception) {
        result.diagnostic = "qdrant_snapshot_response_invalid"
        return result
    }
    if (!ckbQdrantSnapshotNameValid(result.snapshotName)) {
        result.diagnostic = "qdrant_snapshot_name_invalid"
        return result
    }
    result.ok = true
    result.diagnostic = "ok"
    result
}

public func downloadCkbQdrantSnapshot(identity: CkbQdrantSnapshotIdentity,
    snapshotName: String, executor: CkbQdrantSnapshotExecutor):
    CkbQdrantSnapshotDownloadResult {
    let result = CkbQdrantSnapshotDownloadResult()
    if (!ckbQdrantSnapshotIdentityValid(identity) ||
        !ckbQdrantSnapshotNameValid(snapshotName)) {
        result.diagnostic = "qdrant_snapshot_identity_invalid"
        return result
    }
    let request = CkbQdrantSnapshotRequest()
    request.method = "GET"
    request.path =
        "/collections/${identity.collection}/snapshots/${snapshotName}"
    let response = executor.execute(request)
    if (response.statusCode < 200 || response.statusCode >= 300 ||
        response.bodyBytes.size == 0) {
        result.diagnostic = "qdrant_snapshot_download_failed"
        return result
    }
    // Snapshot bytes are intentionally never decoded as UTF-8.
    result.bytes = response.bodyBytes.clone()
    result.sha256 = ckbQdrantSnapshotBytesHash(result.bytes)
    result.ok = true
    result.diagnostic = "ok"
    result
}

public func restoreCkbQdrantSnapshot(targetCollection: String,
    snapshotBytes: Array<UInt8>, manifest: CkbQdrantSnapshotManifest,
    executor: CkbQdrantSnapshotExecutor): CkbQdrantSnapshotRestoreResult {
    let result = CkbQdrantSnapshotRestoreResult()
    let validation = validateCkbQdrantSnapshotManifest(manifest)
    if (!validation.ok) { result.diagnostic = validation.diagnostic; return result }
    if (!ckbQdrantSnapshotCollectionValid(targetCollection)) {
        result.diagnostic = "qdrant_snapshot_target_invalid"
        return result
    }
    if (ckbQdrantSnapshotBytesHash(snapshotBytes) !=
        manifest.snapshotSha256) {
        result.diagnostic = "qdrant_snapshot_hash_mismatch"
        return result
    }
    let statusRequest = CkbQdrantSnapshotRequest()
    statusRequest.method = "GET"
    statusRequest.path = "/collections/${targetCollection}"
    let status = executor.execute(statusRequest)
    if (status.statusCode != 404) {
        result.diagnostic = "qdrant_snapshot_target_exists"
        return result
    }
    let restoreRequest = CkbQdrantSnapshotRequest()
    restoreRequest.method = "PUT"
    restoreRequest.path =
        "/collections/${targetCollection}/snapshots/upload"
    restoreRequest.contentType = "application/octet-stream"
    restoreRequest.bodyBytes = snapshotBytes.clone()
    let response = executor.execute(restoreRequest)
    if (response.statusCode < 200 || response.statusCode >= 300) {
        result.diagnostic = "qdrant_snapshot_restore_failed"
        return result
    }
    result.ok = true
    result.diagnostic = "ok"
    result
}

public func verifyRestoredCkbQdrantSnapshot(
    status: CkbQdrantRestoredStatus,
    manifest: CkbQdrantSnapshotManifest,
    logical: CkbLogicalSnapshotManifest,
    visible: CkbStudentVisiblePathInput,
    context: CkbPortablePathContext): CkbQdrantSnapshotVerification {
    let result = CkbQdrantSnapshotVerification()
    let validation = validateCkbQdrantSnapshotManifest(manifest)
    if (!validation.ok) { result.diagnostic = validation.diagnostic; return result }
    if (logical.manifestHash != manifest.logicalManifestHash ||
        logical.p3VectorProofHash != manifest.vectorProofHash ||
        logical.vectorCollection != manifest.collection ||
        logical.vectorCount != manifest.points ||
        logical.vectorDimension != manifest.dimension) {
        result.diagnostic = "qdrant_logical_manifest_mismatch"
        return result
    }
    if (status.state != "green" || status.count != manifest.points ||
        status.dimension != manifest.dimension ||
        status.distance.toAsciiLower() != manifest.distance.toAsciiLower()) {
        result.diagnostic = "qdrant_restored_status_mismatch"
        return result
    }
    if (status.payloadCanonicalHash != manifest.payloadCanonicalHash) {
        result.diagnostic = "qdrant_payload_hash_mismatch"
        return result
    }
    let pathReport = scanCkbStudentVisiblePaths(visible, context)
    if (!pathReport.ready) {
        result.diagnostic = "qdrant_payload_path_finding"
        return result
    }
    result.ok = true
    result.ready = true
    result.diagnostic = "ok"
    result
}

public func ckbQdrantSnapshotBytesHash(bytes: Array<UInt8>): String {
    let digest = SHA256()
    digest.write(bytes)
    let out = StringBuilder()
    for (byte in digest.finish()) {
        out.append(ckbQdrantSnapshotNibble(byte / UInt8(16)))
        out.append(ckbQdrantSnapshotNibble(byte % UInt8(16)))
    }
    "sha256:${out.toString()}"
}

private func ckbQdrantSnapshotValidateStructure(
    manifest: CkbQdrantSnapshotManifest): CkbQdrantSnapshotContract {
    if (manifest.schemaVersion != "ckb-qdrant-snapshot-v1" ||
        !ckbQdrantSnapshotHashValid(manifest.imageDigest) ||
        !ckbQdrantSnapshotCollectionValid(manifest.collection) ||
        manifest.distance.toAsciiLower() != "cosine") {
        return ckbQdrantSnapshotFailure("qdrant_snapshot_identity_invalid")
    }
    if (manifest.qdrantMinorVersion != "1.14") {
        return ckbQdrantSnapshotFailure(
            "qdrant_snapshot_minor_version_mismatch")
    }
    if (manifest.points != 7978) {
        return ckbQdrantSnapshotFailure("qdrant_snapshot_points_mismatch")
    }
    if (manifest.dimension != 1024) {
        return ckbQdrantSnapshotFailure(
            "qdrant_snapshot_dimension_mismatch")
    }
    for (hash in [manifest.snapshotSha256, manifest.logicalManifestHash,
        manifest.vectorProofHash, manifest.payloadCanonicalHash]) {
        if (!ckbQdrantSnapshotHashValid(hash)) {
            return ckbQdrantSnapshotFailure("qdrant_snapshot_hash_invalid")
        }
    }
    ckbQdrantSnapshotSuccess()
}

private func ckbQdrantSnapshotManifestBody(
    manifest: CkbQdrantSnapshotManifest): String {
    "{\"schemaVersion\":\"${ckbQdrantSnapshotJson(manifest.schemaVersion)}\"," +
    "\"imageDigest\":\"${manifest.imageDigest}\"," +
    "\"qdrantMinorVersion\":\"${manifest.qdrantMinorVersion}\"," +
    "\"collection\":\"${ckbQdrantSnapshotJson(manifest.collection)}\"," +
    "\"distance\":\"${ckbQdrantSnapshotJson(manifest.distance)}\"," +
    "\"dimension\":${manifest.dimension},\"points\":${manifest.points}," +
    "\"snapshotSha256\":\"${manifest.snapshotSha256}\"," +
    "\"logicalManifestHash\":\"${manifest.logicalManifestHash}\"," +
    "\"vectorProofHash\":\"${manifest.vectorProofHash}\"," +
    "\"payloadCanonicalHash\":\"${manifest.payloadCanonicalHash}\""
}

private func ckbQdrantSnapshotIdentityValid(
    identity: CkbQdrantSnapshotIdentity): Bool {
    ckbQdrantSnapshotCollectionValid(identity.collection) &&
        ckbQdrantSnapshotHashValid(identity.logicalManifestHash) &&
        ckbQdrantSnapshotHashValid(identity.vectorProofHash)
}

private func ckbQdrantSnapshotCollectionValid(value: String): Bool {
    if (value == "" || value.size > 120) { return false }
    for (rune in value.runes()) {
        if (!((rune >= r'a' && rune <= r'z') ||
            (rune >= r'A' && rune <= r'Z') ||
            (rune >= r'0' && rune <= r'9') ||
            rune == r'-' || rune == r'_')) { return false }
    }
    true
}

private func ckbQdrantSnapshotNameValid(value: String): Bool {
    if (value == "" || value.size > 200 || value.contains("..")) {
        return false
    }
    for (rune in value.runes()) {
        if (!((rune >= r'a' && rune <= r'z') ||
            (rune >= r'A' && rune <= r'Z') ||
            (rune >= r'0' && rune <= r'9') ||
            rune == r'-' || rune == r'_' || rune == r'.')) {
            return false
        }
    }
    true
}

private func ckbQdrantSnapshotHashValid(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 71 || !value.startsWith("sha256:")) { return false }
    for (i in 7..runes.size) {
        if (!((runes[i] >= r'0' && runes[i] <= r'9') ||
            (runes[i] >= r'a' && runes[i] <= r'f'))) { return false }
    }
    true
}

private func ckbQdrantSnapshotString(
    object: JsonObject, key: String): String {
    object.get(key).getOrThrow().asString().getValue()
}

private func ckbQdrantSnapshotInt(
    object: JsonObject, key: String): Int64 {
    object.get(key).getOrThrow().asInt().getValue()
}

private func ckbQdrantSnapshotJson(value: String): String {
    let out = StringBuilder()
    let hex = "0123456789abcdef".toRuneArray()
    for (rune in value.runes()) {
        if (rune == r'"') { out.append("\\\"") }
        else if (rune == r'\\') { out.append("\\\\") }
        else if (rune == r'\n') { out.append("\\n") }
        else if (rune == r'\r') { out.append("\\r") }
        else if (rune == r'\t') { out.append("\\t") }
        else if (UInt32(rune) < 0x20u32) {
            let code = UInt32(rune); out.append("\\u00")
            out.append(hex[Int64(code / 16u32)])
            out.append(hex[Int64(code % 16u32)])
        } else { out.append(rune) }
    }
    out.toString()
}

private func ckbQdrantSnapshotNibble(value: UInt8): Rune {
    if (value < UInt8(10)) {
        return Rune(UInt32(value) + UInt32(r'0'))
    }
    Rune(UInt32(value - UInt8(10)) + UInt32(r'a'))
}

private func ckbQdrantSnapshotFailure(
    diagnostic: String): CkbQdrantSnapshotContract {
    let result = CkbQdrantSnapshotContract()
    result.diagnostic = diagnostic
    result
}

private func ckbQdrantSnapshotSuccess(): CkbQdrantSnapshotContract {
    let result = CkbQdrantSnapshotContract()
    result.ok = true
    result.diagnostic = "ok"
    result
}
