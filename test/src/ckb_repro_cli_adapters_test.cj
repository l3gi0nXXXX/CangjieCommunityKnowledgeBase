package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.unittest.*
import std.unittest.testmacro.*

private class P234ReleaseCliFake <: CkbReleaseCliAdapter {
    public var calls: Int64 = 0
    public var fail: Bool = false
    public var explode: Bool = false
    public var customSummary: String = ""
    public func execute(options: CkbReleaseCliOptions): CkbReleaseCliOperationResult {
        if (this.explode) { throw Exception("Authorization=secret 中文🙂") }
        this.calls += 1
        let out = CkbReleaseCliOperationResult()
        out.ok = !this.fail
        out.diagnostic = if (this.fail) { "invalid_response_encoding" } else { "ok" }
        out.summary = if (this.customSummary == "") {
            "版本=portable-仓颉🙂 图=ready"
        } else { this.customSummary }
        out
    }
}

private class P234P3CliFake <: CkbP3CliAdapter {
    public var calls: Int64 = 0
    public var fail: Bool = false
    public var cleaned: Bool = false
    public var explode: Bool = false
    public func execute(options: CkbP3CliOptions): CkbP3CliOperationResult {
        if (this.explode) { throw Exception("token=secret") }
        this.calls += 1
        let out = CkbP3CliOperationResult()
        out.ok = !this.fail
        out.diagnostic = if (this.fail) { "invalid_response_encoding" } else { "ok" }
        out.summary = "collection=仓颉🙂 points=7978 dimension=1024"
        if (this.fail) { this.cleaned = true }
        out
    }
}

private class P234VectorDependency <: CkbPortableVectorBuildBackend {
    public func collectionExists(collection: String): Bool { false }
    public func createEmpty(collection: String, dimension: Int64,
        distance: String): CkbReproContractResult { CkbReproContractResult() }
    public func stagedRebuild(collection: String): CkbPortableVectorBuildEvidence {
        CkbPortableVectorBuildEvidence()
    }
    public func deleteCollection(collection: String): Unit {}
}
private class P234SnapshotDependency <: CkbQdrantSnapshotExecutor {
    public var restored: Bool = false
    public func execute(request: CkbQdrantSnapshotRequest): CkbQdrantSnapshotResponse {
        let out = CkbQdrantSnapshotResponse()
        if (request.method == "GET") { out.statusCode = 404 }
        else { this.restored = true; out.statusCode = 200 }
        out
    }
}
private class P234ParityDependency <: CkbRetrievalParityBackend {
    public func query(transport: String, query: String): CkbRetrievalParityResponse {
        CkbRetrievalParityResponse()
    }
}
private class P234VerificationDependency <: CkbP3VerificationInputProvider {
    public func visibleInput(collection: String): CkbStudentVisiblePathInput {
        CkbStudentVisiblePathInput()
    }
    public func pathContext(collection: String): CkbPortablePathContext {
        CkbPortablePathContext()
    }
}

private class P234P4CliFake <: CkbP4CliAdapter {
    public var calls: Int64 = 0
    public var fail: Bool = false
    public var cleaned: Bool = false
    public var explode: Bool = false
    public func execute(options: CkbP4CliOptions): CkbP4CliOperationResult {
        if (this.explode) { throw Exception("Bearer secret") }
        this.calls += 1
        let out = CkbP4CliOperationResult()
        out.ok = !this.fail
        out.diagnostic = if (this.fail) { "promotion_pointer_commit_failed" } else { "ok" }
        out.summary = "portable candidate 仓颉🙂 ready"
        if (this.fail) { this.cleaned = true }
        out
    }
}
private class P234BuildDependency <: CkbReproBuildBackend {
    public func run(stage: String,
        input: CkbReproPipelineInput): CkbReproBackendResult {
        CkbReproBackendResult(true, "ok")
    }
}
private class P234PromotionDependency <: CkbPortablePromotionBackend {
    public var commits: Int64 = 0
    public func readCurrent(): CkbPortablePromotionState {
        CkbPortablePromotionState("old", p234Hash("pointer"), "old-vector")
    }
    public func restoreVector(options: CkbPortablePromotionOptions): Bool { true }
    public func validateVector(options: CkbPortablePromotionOptions): Bool { true }
    public func commitPointer(options: CkbPortablePromotionOptions): Bool {
        this.commits += 1; true
    }
    public func readBack(options: CkbPortablePromotionOptions): Bool { true }
    public func cleanupOld(): Bool { true }
    public func cleanupStaging(): Unit {}
}

@Test
public class CkbReproCliAdaptersTest {
    @TestCase
    public func p2Bnd01CliAdapterRejectsAmbiguousArgsAndKeepsUtf8(): Unit {
        let fake = P234ReleaseCliFake()
        @Expect(executeCkbReleaseCliAdapter([
            "ckb-release-export", "--store-root", "/tmp/仓颉🙂",
            "--logical-proof", "l", "--vector-proof", "v",
            "--output", "/tmp/out", "--output", "/tmp/again"
        ], fake).diagnostic, "duplicate_argument:--output")
        @Expect(executeCkbReleaseCliAdapter([
            "ckb-release-import", "--archive", "a", "--target-root"
        ], fake).diagnostic, "missing_argument_value:--target-root")
        @Expect(runCkbReleaseCli(["ckb-release-import"]).diagnostic,
            "required_argument_missing:--archive")
        let defaults = CkbReleaseCliOptions()
        defaults.mode = "import"
        let policy = ckbDefaultReleasePathPolicy(defaults)
        @Expect(exists(Path(policy.worktreeRoot).join(".git")), true)
        @Expect(policy.worktreeRoot == canonicalize(Path(".")).toString(), false)
        @Expect(policy.productionStoreRoot,
            "${policy.worktreeRoot}/target/ckb-data")
        @Expect(policy.userConfigRoot.contains(
            "/.config/cangjie-community-knowledge-base"), true)
        let jsonError = executeCkbReleaseCliAdapter([
            "ckb-release-import", "--archive", "a", "--json"
        ], fake)
        @Expect(jsonError.output.startsWith("{"), true)
        @Expect(jsonError.output.contains("\"ok\":false"), true)
        @Expect(fake.calls, 0)
    }

    @TestCase
    public func p2Pos01CliAdapterRendersHumanUnlessJsonExplicit(): Unit {
        let fake = P234ReleaseCliFake()
        let args = ["ckb-release-import", "--archive", "/tmp/a",
            "--target-root", "/tmp/b"]
        let human = runCkbReleaseCli(args, fake)
        @Expect(human.ok, true)
        @Expect(human.output.contains("仓颉🙂"), true)
        @Expect(human.output.contains("\"ok\""), false)
        let json = executeCkbReleaseCliAdapter(
            ["ckb-release-import", "--archive", "/tmp/a",
             "--target-root", "/tmp/c", "--json"], fake)
        @Expect(json.output.contains("\"ok\":true"), true)

        let root = Path("target/p234-release-production")
        if (exists(root)) { remove(root, recursive: true) }
        Directory.create(root, recursive: true)
        let payload = CkbReleaseArchivePayload(); payload.path = "仓颉🙂/binary.bin"
        payload.bytes = Array<UInt8>(200000, repeat: UInt8(0xff))
        payload.bytes[1] = 0x00; payload.bytes[2] = 0xfe
        let values = ArrayList<CkbReleaseArchivePayload>(); values.add(payload)
        let backend = CkbPortableReleaseArchiveBackend()
        let archive = root.join("snapshot.ckb-release").toString()
        @Expect(backend.create(archive, values).ok, true)
        @Expect(backend.enumerate(archive).entries[0].path, payload.path)
        @Expect(backend.readRegular(archive, payload.path).bytes, payload.bytes)
        @Expect(backend.maxBufferBytes <= 65536, true)
        remove(root, recursive: true)
    }

    @TestCase
    public func p2Neg01CliAdapterPreservesFailureWithoutRawPayload(): Unit {
        let fake = P234ReleaseCliFake(); fake.fail = true
        let result = executeCkbReleaseCliAdapter([
            "ckb-release-import", "--archive", "/tmp/a",
            "--target-root", "/tmp/b"
        ], fake)
        @Expect(result.ok, false)
        @Expect(result.exitCode, 1)
        @Expect(result.output.contains("invalid_response_encoding"), true)
        @Expect(result.output.contains("\"result\""), false)
        fake.fail = false; fake.explode = true
        let isolated = executeCkbReleaseCliAdapter([
            "ckb-release-import", "--archive", "/tmp/a",
            "--target-root", "/tmp/b"
        ], fake)
        @Expect(isolated.diagnostic, "release_adapter_execution_failed")
        @Expect(isolated.output.contains("secret"), false)
        fake.explode = false
        fake.customSummary = p234LongControlSummary()
        let rendered = runCkbReleaseCli([
            "ckb-release-import", "--archive", "/tmp/a",
            "--target-root", "/tmp/b", "--json"
        ], fake)
        @Expect(rendered.output.contains("\t"), false)
        @Expect(rendered.output.contains("\\t"), true)
        @Expect(rendered.output.size < 800, true)
    }

    @TestCase
    public func p3Bnd01CliAdapterRejectsCrossModeAndMissingValues(): Unit {
        let fake = P234P3CliFake()
        @Expect(executeCkbP3CliAdapter([
            "ckb-qdrant-snapshot", "create", "--endpoint", "http://127.0.0.1:1",
            "--collection", "c", "--logical-manifest", "l", "--vector-proof", "v",
            "--output-root", "/tmp/o", "--snapshot", "wrong"
        ], fake).diagnostic, "argument_not_allowed:create:--snapshot")
        @Expect(executeCkbP3CliAdapter([
            "ckb-portable-vector-build", "--candidate-root", "c",
            "--environment-lock", "e", "--output-proof"
        ], fake).diagnostic, "missing_argument_value:--output-proof")
        @Expect(parseCkbP3CliOptions(["ckb-qdrant-snapshot", "create"]).diagnostic,
            "required_argument_missing:--endpoint")
        @Expect(fake.calls, 0)
    }

    @TestCase
    public func p3Pos01CliAdapterRunsRestoreAndParityHumanOutput(): Unit {
        let fake = P234P3CliFake()
        let restore = runCkbP3Cli([
            "ckb-qdrant-snapshot", "restore", "--endpoint", "http://127.0.0.1:1",
            "--target-collection", "new", "--snapshot", "s", "--manifest", "m"
        ], fake)
        @Expect(restore.ok, true)
        @Expect(restore.output.contains("points=7978"), true)
        @Expect(restore.output.contains("\"ok\""), false)
        @Expect(executeCkbP3CliAdapter([
            "ckb-retrieval-parity", "--mode", "verify", "--manifest", "m",
            "--rest-endpoint", "http://127.0.0.1:1", "--mcp-stdio-command", "cmd",
            "--mcp-http-endpoint", "http://127.0.0.1:2"
        ], fake).ok, true)

        let root = Path("target/p234-p3-production")
        if (exists(root)) { remove(root, recursive: true) }
        Directory.create(root, recursive: true)
        let bytes: Array<UInt8> = [0xff, 0x00, 0xfe, 0x41]
        let manifest = CkbQdrantSnapshotManifest()
        manifest.schemaVersion = "ckb-qdrant-snapshot-v1"
        manifest.imageDigest = p234Hash("image"); manifest.qdrantMinorVersion = "1.14"
        manifest.collection = "source"; manifest.distance = "Cosine"
        manifest.dimension = 1024; manifest.points = 7978
        manifest.snapshotSha256 = ckbQdrantSnapshotBytesHash(bytes)
        manifest.logicalManifestHash = p234Hash("logical")
        manifest.vectorProofHash = p234Hash("vector")
        manifest.payloadCanonicalHash = p234Hash("payload")
        let built = buildCkbQdrantSnapshotManifest(manifest)
        File.writeTo(root.join("snapshot.bin"), bytes)
        File.writeTo(root.join("manifest.json"), built.canonicalJson.toArray())
        let snapshotDependency = P234SnapshotDependency()
        let production = newCkbP3ProductionAdapter(P234VectorDependency(),
            snapshotDependency, P234ParityDependency(), P234VerificationDependency(),
            CkbReleasePathPolicy())
        let actual = runCkbP3Cli(["ckb-qdrant-snapshot", "restore", "--endpoint",
            "http://127.0.0.1:1", "--target-collection", "restored",
            "--snapshot", root.join("snapshot.bin").toString(), "--manifest",
            root.join("manifest.json").toString()], production)
        @Expect(actual.ok, true); @Expect(snapshotDependency.restored, true)
        remove(root, recursive: true)
    }

    @TestCase
    public func p3Pos02CliAdapterRunsPortableVectorBuild(): Unit {
        let fake = P234P3CliFake()
        let result = executeCkbP3CliAdapter([
            "ckb-portable-vector-build", "--candidate-root", "candidate",
            "--environment-lock", "environment.json", "--output-proof", "proof.json",
            "--json"
        ], fake)
        @Expect(result.ok, true)
        @Expect(result.output.contains("\"ok\":true"), true)
    }

    @TestCase
    public func p3ProductionBusinessFactoryLeavesOnlyTransportDependencies(): Unit {
        let root = Path("target/p234-p3-business-factory")
        if (exists(root)) { remove(root, recursive: true) }
        Directory.create(root, recursive: true)
        let store = FileKnowledgeStore(root.toString())
        let pathContext = CkbPortablePathContext()
        pathContext.apiRoutes.add("/v1/query")
        let provider = CkbStoreVerificationInputProvider(store, pathContext)
        @Expect(provider.visibleInput("portable").rawRecords.size, 0)
        @Expect(provider.pathContext("portable").apiRoutes[0], "/v1/query")

        let adapter = newCkbP3BusinessProductionAdapter(
            DeterministicEmbeddingProvider(EmbeddingConfig()), store,
            LocalVectorStore(), pathContext,
            P234SnapshotDependency(), P234ParityDependency(),
            CkbReleasePathPolicy())
        @Expect(adapter is CkbP3CliAdapter, true)
        remove(root, recursive: true)
    }

    @TestCase
    public func p3Neg01CliAdapterContainsInvalidUtf8Failure(): Unit {
        let fake = P234P3CliFake(); fake.fail = true
        let result = executeCkbP3CliAdapter([
            "ckb-qdrant-snapshot", "verify", "--endpoint", "http://127.0.0.1:1",
            "--collection", "c", "--manifest", "m", "--logical-manifest", "l"
        ], fake)
        @Expect(result.diagnostic, "invalid_response_encoding")
        @Expect(result.output.contains("\"result\""), false)
        fake.fail = false; fake.explode = true
        @Expect(executeCkbP3CliAdapter([
            "ckb-qdrant-snapshot", "verify", "--endpoint", "http://127.0.0.1:1",
            "--collection", "c", "--manifest", "m", "--logical-manifest", "l"
        ], fake).diagnostic, "p3_adapter_execution_failed")
    }

    @TestCase
    public func p3Neg02CliAdapterReportsCleanupOnBackendFailure(): Unit {
        let fake = P234P3CliFake(); fake.fail = true
        let result = executeCkbP3CliAdapter([
            "ckb-portable-vector-build", "--candidate-root", "candidate",
            "--environment-lock", "environment.json", "--output-proof", "proof.json"
        ], fake)
        @Expect(result.ok, false)
        @Expect(fake.cleaned, true)
    }

    @TestCase
    public func p4Bnd01CliAdapterRejectsUnknownDuplicateAndImplicitTargets(): Unit {
        let fake = P234P4CliFake()
        @Expect(executeCkbP4CliAdapter([
            "ckb-repro-build", "--output-root", "out", "--temporary-root", "tmp",
            "--unknown", "x"
        ], fake).diagnostic, "unknown_argument:--unknown")
        @Expect(executeCkbP4CliAdapter([
            "ckb-repro-promote", "--production-store", "p"
        ], fake).diagnostic, "required_argument_missing:--qdrant-endpoint")
        @Expect(parseCkbP4CliOptions(["ckb-repro-build"]).diagnostic,
            "required_argument_missing:--output-root")
        @Expect(fake.calls, 0)
    }

    @TestCase
    public func p4Pos01CliAdapterRunsBuildWithExplicitRoots(): Unit {
        let fake = P234P4CliFake()
        let result = runCkbP4Cli([
            "ckb-repro-build", "--output-root", "/tmp/out 仓颉🙂",
            "--temporary-root", "/tmp/temp 仓颉🙂"
        ], fake)
        @Expect(result.ok, true)
        @Expect(result.output.contains("仓颉🙂"), true)
        @Expect(result.output.contains("\"ok\""), false)
    }

    @TestCase
    public func p4Pos03CliAdapterRequiresAndRunsApply(): Unit {
        let fake = P234P4CliFake()
        let result = executeCkbP4CliAdapter(p234PromotionArgs(true), fake)
        @Expect(result.ok, true)
        @Expect(fake.calls, 1)

        let root = Path("target/p234-p4-production")
        if (exists(root)) { remove(root, recursive: true) }
        Directory.create(root, recursive: true)
        let candidate = "{\"candidateVersion\":\"portable-v1\"," +
            "\"candidateManifestHash\":\"${p234Hash("candidate")}\"," +
            "\"p2ProofHash\":\"${p234Hash("p2")}\",\"p3ProofHash\":\"${p234Hash("p3")}\"," +
            "\"p5ProofHash\":\"${p234Hash("p5")}\",\"p8AProofHash\":\"${p234Hash("p8a")}\"," +
            "\"identity\":\"portable-identity\",\"p8StrictPassed\":151}"
        let p8b = "{\"ready\":true,\"candidateVersion\":\"portable-v1\"," +
            "\"identity\":\"portable-identity\",\"p8BProofHash\":\"${p234Hash("p8b")}\"}"
        File.writeTo(root.join("candidate.json"), candidate.toArray())
        File.writeTo(root.join("p8b.json"), p8b.toArray())
        let productionRoot = root.join("production")
        Directory.create(productionRoot, recursive: true)
        let dependency = P234PromotionDependency()
        let production = newCkbP4ProductionAdapter(CkbReproBuildRequest(),
            P234BuildDependency(), dependency)
        let actual = runCkbP4Cli(["ckb-repro-promote", "--production-store",
            canonicalize(productionRoot).toString(), "--qdrant-endpoint",
            "http://127.0.0.1:6333", "--expected-active-version", "old",
            "--candidate-manifest", root.join("candidate.json").toString(),
            "--p8-b-report", root.join("p8b.json").toString(), "--apply"], production)
        @Expect(actual.ok, true); @Expect(dependency.commits, 1)

        let transport = P234SnapshotDependency()
        let business = newCkbP4BusinessProductionAdapter(
            CkbReproBuildRequest(), FileKnowledgeStore(productionRoot.toString()),
            FileKnowledgeStore(productionRoot.toString()), Array<UInt8>(),
            CkbQdrantSnapshotManifest(), CkbLogicalSnapshotManifest(),
            "portable-staging", transport, CkbPortablePathContext())
        @Expect(business is CkbP4CliAdapter, true)
        let concretePromotion = CkbPortableProductionPromotionBackend(
            FileKnowledgeStore(productionRoot.toString()),
            FileKnowledgeStore(productionRoot.toString()), Array<UInt8>(),
            CkbQdrantSnapshotManifest(), CkbLogicalSnapshotManifest(),
            "portable-staging", transport, CkbPortablePathContext())
        concretePromotion.cleanupStaging()
        @Expect(transport.restored, true)
        remove(root, recursive: true)
    }

    @TestCase
    public func p4Neg03CliAdapterNeverExecutesWithoutApplyAndContainsFailure(): Unit {
        let fake = P234P4CliFake()
        @Expect(executeCkbP4CliAdapter(
            p234PromotionArgs(false), fake).diagnostic, "promotion_apply_required")
        @Expect(fake.calls, 0)
        fake.fail = true
        let failed = executeCkbP4CliAdapter(p234PromotionArgs(true), fake)
        @Expect(failed.ok, false)
        @Expect(fake.cleaned, true)
        fake.fail = false; fake.explode = true
        @Expect(executeCkbP4CliAdapter(p234PromotionArgs(true), fake).diagnostic,
            "p4_adapter_execution_failed")
    }
}

private func p234LongControlSummary(): String {
    var out = "仓颉🙂\tAuthorization=secret"
    for (_ in 0..300) { out += "界" }
    out
}

private func p234Hash(value: String): String { benchmarkGapSha256(value) }

private func p234PromotionArgs(apply: Bool): Array<String> {
    let values = ArrayList<String>()
    for (value in ["ckb-repro-promote", "--production-store", "/tmp/production",
        "--qdrant-endpoint", "http://127.0.0.1:6333",
        "--expected-active-version", "old", "--candidate-manifest", "candidate.json",
        "--p8-b-report", "p8-b.json"]) { values.add(value) }
    if (apply) { values.add("--apply") }
    values.toArray()
}
