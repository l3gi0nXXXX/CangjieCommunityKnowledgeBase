package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.time.DateTime
import std.unittest.*
import std.unittest.testmacro.*
import stdx.crypto.digest.SHA256

@Test
public class CkbReproCliTypedAssetsTest {
    @TestCase
    public func runtimeConfigIsStrictAndUtf8Safe(): Unit {
        let config = typedRuntime()
        let text = renderCkbReproCliRuntimeConfig(config)
        let parsed = parseCkbReproCliRuntimeConfigBytes(text.toArray())
        @Expect(parsed[0].ok, true)
        @Expect(parsed[1].embeddingModel, "嵌入🙂-v1")
        @Expect(parseCkbReproCliRuntimeConfigBytes(
            text.replace("\"networkEnabled\":false",
                "\"networkEnabled\":false,\"unknown\":1").toArray())[0].ok,
            false)
        let invalid = parseCkbReproCliRuntimeConfigBytes(
            [UInt8(0x7b), UInt8(0xff), UInt8(0x7d)])
        @Expect(invalid[0].diagnostic, "invalid_response_encoding")
    }

    @TestCase
    public func runtimeConfigRejectsCredentialAndUnboundedValues(): Unit {
        let config = typedRuntime()
        config.vectorEndpoint = "https://token@example.invalid"
        @Expect(parseCkbReproCliRuntimeConfigBytes(
            renderCkbReproCliRuntimeConfig(config).toArray())[0].ok, false)
        config.vectorEndpoint = "http://127.0.0.1:6333"
        config.vectorDimensions = 65537
        @Expect(parseCkbReproCliRuntimeConfigBytes(
            renderCkbReproCliRuntimeConfig(config).toArray())[0].ok, false)
    }

    @TestCase
    public func pathContextCombinesFourAuthorizedAssets(): Unit {
        let root = typedRoot("path")
        let policy = typedPortablePolicy()
        let policyText = renderCkbPortablePathPolicy(policy)
        let map = CkbPortableLocalRootMap()
        map.schemaVersion = "ckb-portable-local-root-map-v1"
        let source = CkbPortableLocalRoot()
        source.sourceId = "docs-中文🙂"; source.kind = "SOURCE_ROOT"
        source.localRoot = root; map.roots.add(source)
        let mapText = renderCkbReproCliLocalRootMap(map)
        let routes = ArrayList<String>(); routes.add("/v1/cangjie/task")
        let routesText = renderCkbReproApiRoutes(routes)
        let context = typedPathContext(policyText, mapText, routesText,
            "/tmp/ckb-typed-worktree", "/tmp/ckb-typed-production",
            "/tmp/ckb-typed-user")
        let parsed = parseCkbReproCliPathContextBytes(policyText.toArray(),
            mapText.toArray(), routesText.toArray(), context.toArray())
        @Expect(parsed[0].ok, true)
        @Expect(parsed[1].pathContext.apiRoutes.size, 1)
        @Expect(parsed[1].releasePathPolicy.productionStoreRoot,
            "/tmp/ckb-typed-production")
        let leakage = CangjieBenchmarkLeakageAuthority()
        leakage.fingerprints.add("abcdefghijklmnopqrstuvwx")
        leakage.fingerprintSet.add("abcdefghijklmnopqrstuvwx")
        @Expect(composeCkbReproCliPrivateBuildAuthority(
            typedEvalSupport(), leakage, parsed[1],
            "${root}/nested/rebuild-temporary", "${root}/runtime")[0].ok,
            true)
        remove(Path(root), recursive: true)
    }

    @TestCase
    public func pathContextRejectsHashDriftTraversalAndDuplicateRoots(): Unit {
        let root = typedRoot("path-negative")
        let policyText = renderCkbPortablePathPolicy(typedPortablePolicy())
        let map = CkbPortableLocalRootMap()
        map.schemaVersion = "ckb-portable-local-root-map-v1"
        for (_ in 0..2) {
            let source = CkbPortableLocalRoot(); source.sourceId = "docs"
            source.kind = "SOURCE_ROOT"; source.localRoot = root
            map.roots.add(source)
        }
        let mapText = renderCkbReproCliLocalRootMap(map)
        let routes = ArrayList<String>(); routes.add("/v1/task")
        let routesText = renderCkbReproApiRoutes(routes)
        let context = typedPathContext(policyText, mapText, routesText,
            "/tmp/ckb-typed-worktree", "/tmp/../escape", "/tmp/user")
        @Expect(parseCkbReproCliPathContextBytes(policyText.toArray(),
            mapText.toArray(), routesText.toArray(), context.toArray())[0].ok,
            false)
        remove(Path(root), recursive: true)
    }

    @TestCase
    public func evalSupportParsesCanonicalSnapshotAndRejectsLeakage(): Unit {
        let snapshot = typedEvalSupport()
        let text = renderCkbReproCliEvalSupport(snapshot)
        let parsed = parseCkbReproCliEvalSupportBytes(text.toArray())
        @Expect(parsed[0].diagnostic, "ok")
        @Expect(parsed[0].ok, true)
        @Expect(parsed[1].recordCount, 4)
        snapshot.jsonl = snapshot.jsonl.replace("visible helper",
            "canonical_solution")
        snapshot.checksum = benchmarkGapSha256("${snapshot.schemaVersion}:" +
            "${snapshot.datasetVersion}:${snapshot.revision}:${snapshot.jsonl}")
        snapshot.authorityHash = snapshot.checksum
        @Expect(parseCkbReproCliEvalSupportBytes(
            renderCkbReproCliEvalSupport(snapshot).toArray())[0].ok, false)
    }

    @TestCase
    public func leakageAuthorityRequiresSortedCanonicalPrivateData(): Unit {
        let authority = CangjieBenchmarkLeakageAuthority()
        authority.fingerprints.add("知识原子abcdefghijklmnopqrst")
        authority.fingerprintSet.add("知识原子abcdefghijklmnopqrst")
        authority.fingerprints.add("abcdefghijklmnopqrstuvwx")
        authority.fingerprintSet.add("abcdefghijklmnopqrstuvwx")
        let text = renderCkbReproCliLeakageAuthority(authority)
        @Expect(parseCkbReproCliLeakageAuthorityBytes(text.toArray())[0].ok,
            true)
        let dirty = text.replace("abcdefghijklmnopqrstuvwx",
            "/Users/alice/private/token")
        @Expect(parseCkbReproCliLeakageAuthorityBytes(dirty.toArray())[0].ok,
            false)
    }

    @TestCase
    public func runnerInputsAreModeBoundAndRejectUnknownFields(): Unit {
        let inputs = typedRunnerInputs()
        let text = renderCkbReproCliRunnerInputs(inputs)
        let parsed = parseCkbReproCliRunnerInputsBytes(
            text.toArray(), "run-certify")
        @Expect(parsed[0].ok, true)
        @Expect(parsed[1].runId, "run-中文🙂")
        @Expect(parsed[1].observedEnvironmentPath,
            "/tmp/private/observed-environment.json")
        @Expect(parseCkbReproCliRunnerInputsBytes(
            text.toArray(), "release-verify")[0].diagnostic,
            "runner_inputs_mode_invalid")
        @Expect(parseCkbReproCliRunnerInputsBytes(text.replace(
            "\"runId\":", "\"unknown\":true,\"runId\":").toArray(),
            "run-certify")[0].ok, false)
        @Expect(parseCkbReproCliRunnerInputsBytes(text.replace(
            "/tmp/private/observed-environment.json", "relative.json")
            .toArray(), "run-certify")[0].ok, false)
    }

    @TestCase
    public func p8BTransportAcceptsOnlyCanonicalLoopbackEndpoints(): Unit {
        let fixture = typedP8BExecutable("transport")
        let executable = fixture[1]
        let valid = typedP8BTransport(executable)
        let parsed = parseCkbP8OwnedLocalRuntimeAuthorityBytes(valid.toArray())
        @Expect(parsed[0].diagnostic, "ok")
        @Expect(parsed[1].qdrantEndpoint, "http://127.0.0.1:6333")
        let environment = CkbReproEnvironmentLock()
        environment.qdrantImageDigest = "sha256:" +
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        @Expect(validateCkbP8BTransportEnvironment(
            parsed[1], environment).ok, true)
        environment.qdrantImageDigest = "sha256:" +
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        @Expect(validateCkbP8BTransportEnvironment(
            parsed[1], environment).diagnostic,
            "p8b_qdrant_image_authority_mismatch")
        @Expect(parseCkbP8OwnedLocalRuntimeAuthorityBytes(valid.replace(
            "\"ckbExecutableSha256\":\"sha256:",
            "\"ckbExecutableSha256\":\"sha256:0").toArray())[0].ok, false)
        @Expect(parseCkbP8OwnedLocalRuntimeAuthorityBytes(valid.replace(
            "qdrant/qdrant@sha256:",
            "qdrant/qdrant:latest@sha256:").toArray())[0].ok, false)
        for (invalid in [
            valid.replace("127.0.0.1:6333", "localhost:6333"),
            valid.replace("127.0.0.1:6333", "0.0.0.0:6333"),
            valid.replace("http://127.0.0.1:6333", "https://127.0.0.1:6333"),
            valid.replace("127.0.0.1:6333", "用户@127.0.0.1:6333"),
            valid.replace("127.0.0.1:6333", "127.0.0.1:6333?令牌=🙂"),
            valid.replace("/mcp", "/mcp#片段🙂")
        ]) {
            @Expect(parseCkbP8OwnedLocalRuntimeAuthorityBytes(
                invalid.toArray())[0].diagnostic,
                "p8b_runtime_transport_invalid")
        }
        remove(Path(fixture[0]), recursive: true)
    }

    @TestCase
    public func p8BStdioRejectsArgsEnvironmentAndExecutableMismatch(): Unit {
        let fixture = typedP8BExecutable("stdio")
        let executable = fixture[1]
        let transport = parseCkbP8OwnedLocalRuntimeAuthorityBytes(
            typedP8BTransport(executable).toArray())[1]
        let valid = "{\"schemaVersion\":\"ckb-mcp-stdio-command-v1\"," +
            "\"executable\":\"${executable}\",\"args\":[]," +
            "\"environment\":[],\"timeoutMillis\":10000}"
        @Expect(parseCkbP8BMcpStdioCommand(
            valid.toArray(), transport)[0].ok, true)
        for (invalid in [
            valid.replace("\"args\":[]", "\"args\":[\"mcp-stdio\"]"),
            valid.replace("\"environment\":[]",
                "\"environment\":[\"PATH=/tmp\"]"),
            valid.replace(executable, "/bin/sh")
        ]) {
            @Expect(parseCkbP8BMcpStdioCommand(
                invalid.toArray(), transport)[0].ok, false)
        }
        @Expect(parseCkbP8BMcpStdioCommand(
            [UInt8(0xff)], transport)[0].diagnostic,
            "invalid_response_encoding")
        remove(Path(fixture[0]), recursive: true)
    }

    @TestCase
    public func p8BProcessRevalidatesExecutableBeforeDelegate(): Unit {
        let fixture = typedP8BExecutable("process")
        let executable = fixture[1]
        let transport = parseCkbP8OwnedLocalRuntimeAuthorityBytes(
            typedP8BTransport(executable).toArray())[1]
        let command = "{\"schemaVersion\":\"ckb-mcp-stdio-command-v1\"," +
            "\"executable\":\"${executable}\",\"args\":[]," +
            "\"environment\":[],\"timeoutMillis\":10000}"
        let spec = parseCkbP8BMcpStdioCommand(
            command.toArray(), transport)[1]
        for (value in ["--config", "/tmp/owned.conf", "--store",
            "/tmp/owned-store", "mcp-stdio"]) { spec.args.add(value) }
        spec.environment.add("cjHeapSize=4GB")
        let delegate = TypedAssetsProcessDelegate()
        let checked = CkbP8BIdentityCheckedProcessExecutor(transport,
            "/tmp/owned.conf", "/tmp/owned-store", delegate: delegate)
        @Expect(checked.execute(spec, "{}".toArray()).diagnostic, "ok")
        @Expect(delegate.calls, 1)
        transport.ckbExecutableSha256 = "sha256:" +
            "0000000000000000000000000000000000000000000000000000000000000000"
        @Expect(checked.execute(spec, "{}".toArray()).diagnostic,
            "p8b_ckb_executable_identity_invalid")
        @Expect(delegate.calls, 1)
        remove(Path(fixture[0]), recursive: true)
    }

    @TestCase
    public func privateAuthorityRejectsProtectedAndNoncanonicalTargets(): Unit {
        let root = typedRoot("authority")
        let path = CkbReproCliPathContextAsset()
        path.pathContext.policy = typedPortablePolicy()
        path.pathContext.localRoots.schemaVersion =
            "ckb-portable-local-root-map-v1"
        let source = CkbPortableLocalRoot(); source.sourceId = "docs"
        source.kind = "SOURCE_ROOT"; source.localRoot = root
        path.pathContext.localRoots.roots.add(source)
        path.releasePathPolicy.worktreeRoot = root
        path.releasePathPolicy.productionStoreRoot = "/tmp/production"
        path.releasePathPolicy.userConfigRoot = "/tmp/user"
        let eval = typedEvalSupport()
        let leakage = CangjieBenchmarkLeakageAuthority()
        leakage.fingerprints.add("abcdefghijklmnopqrstuvwx")
        leakage.fingerprintSet.add("abcdefghijklmnopqrstuvwx")
        let suffix = DateTime.now().toUnixTimeStamp().toString()
        let tmp = Path(root).parent.toString()
        let composed = composeCkbReproCliPrivateBuildAuthority(eval, leakage,
            path, "${tmp}/ckb-typed-temporary-${suffix}",
            "${tmp}/ckb-typed-output-${suffix}")
        @Expect(composed[0].ok, true)
        @Expect(composed[1].leakageHash,
            ckbReproLeakageAuthorityHash(leakage))
        @Expect(composeCkbReproCliPrivateBuildAuthority(eval, leakage, path,
            "${root}/tmp", "${root}/out")[0].ok, false)
        @Expect(composeCkbReproCliPrivateBuildAuthority(eval, leakage, path,
            "/tmp/../escape", "/tmp/output")[0].ok, false)
        remove(Path(root), recursive: true)
    }
}

private class TypedAssetsProcessDelegate <:
    CkbRetrievalParityProcessExecutor {
    var calls: Int64 = 0
    public init() {}
    public func execute(spec: CkbMcpStdioCommandSpec,
        request: Array<UInt8>): CkbRetrievalParityProcessResponse {
        this.calls += 1
        let out = CkbRetrievalParityProcessResponse()
        out.exitCode = 0; out.diagnostic = "ok"; out
    }
}

private func typedP8BTransport(executable: String): String {
    let executableHash = ckbTypedAssetsTestFileHash(executable)
    "{\"schemaVersion\":\"ckb-repro-p8-owned-local-runtime-v1\"," +
        "\"qdrantEndpoint\":\"http://127.0.0.1:6333\"," +
        "\"restEndpoint\":\"http://127.0.0.1:18081/v1/cangjie/syntax-query\"," +
        "\"mcpHttpEndpoint\":\"http://127.0.0.1:18081/mcp\"," +
        "\"ckbExecutable\":\"${executable}\"," +
        "\"ckbExecutableSha256\":\"${executableHash}\"," +
        "\"dockerExecutable\":\"${executable}\"," +
        "\"dockerExecutableSha256\":\"${executableHash}\"," +
        "\"qdrantImageReference\":\"qdrant/qdrant@sha256:" +
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"," +
        "\"qdrantImageId\":\"sha256:" +
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," +
        "\"timeoutMillis\":10000}"
}

private func ckbTypedAssetsTestFileHash(path: String): String {
    let digest = SHA256(); digest.write(File.readFrom(Path(path)))
    let out = StringBuilder()
    let digits = "0123456789abcdef".toRuneArray()
    for (byte in digest.finish()) {
        out.append(digits[Int64(byte / UInt8(16))])
        out.append(digits[Int64(byte % UInt8(16))])
    }
    "sha256:${out.toString()}"
}

private func typedP8BExecutable(name: String): (String, String) {
    let root = typedRoot("p8b-${name}")
    let path = Path(root).join("ckb-test-executable")
    File.writeTo(path, "ckb-test-executable-${name}\n".toArray())
    (root, canonicalize(path).toString())
}

private func typedRuntime(): CkbRuntimeConfig {
    let value = CkbRuntimeConfig()
    value.networkEnabled = false
    value.embeddingProvider = "deterministic"
    value.embeddingModel = "嵌入🙂-v1"
    value.embeddingDimensions = 16
    value.embeddingEndpoint = ""
    value.embeddingBatchSize = 16
    value.embeddingMaxBatchBytes = 65536
    value.embeddingMaxTextBytes = 8192
    value.embeddingTotalTimeoutMillis = 0
    value.embeddingTimeoutMillis = 10000
    value.embeddingRetryCount = 2
    value.embeddingAllowPrivateEndpoint = false
    value.vectorBackend = "qdrant"
    value.vectorActiveCollection = "active"
    value.vectorCandidateCollection = "candidate"
    value.vectorEndpoint = "http://127.0.0.1:6333"
    value.vectorDimensions = 16
    value.vectorDistance = "Cosine"
    value.vectorTimeoutMillis = 10000
    value.vectorRetryCount = 2
    value.vectorAllowPrivateEndpoint = true
    value.timeoutMillis = 10000; value.retryCount = 2
    value.networkProxy = ""; value.networkEnvProxyEnabled = false
    value.networkNoProxy = ""; value.networkInsecureSkipTlsVerify = false
    value.networkCaFile = ""; value.networkAllowPrivateNetwork = true
    value.networkAllowedHosts = "127.0.0.1"
    value
}

private func typedPortablePolicy(): CkbPortablePathPolicy {
    let policy = CkbPortablePathPolicy()
    policy.schemaVersion = "ckb-portable-path-policy-v1"
    policy.baselineState = "historicalPrePortableBaseline"
    policy.unmappedAction = "fail"
    policy.sourceRootRuleId = "source-lock-repository-commit-tree-relative-v1"
    for (value in ["/usr/bin/env", "/dev/null"]) { policy.allowlist.add(value) }
    for (value in ["PROJECT_ROOT", "SOURCE_ROOT", "USER_HOME", "SDK_ROOT",
        "INSTALL_ROOT", "BUILD_ROOT", "TMPDIR", "ABSOLUTE"]) {
        policy.placeholders.add("{{CKB_PATH:${value}}}")
    }
    for (value in ["sourceId", "sourceUrl", "repo", "path", "derivedFrom",
        "title", "content", "chunk", "citation"]) {
        policy.fieldCoverage.add(value)
    }
    for (pair in ["source_locator|source_lock_relative",
        "declared_project_root|placeholder", "user_home|placeholder",
        "sdk_install_build_tmp|explicit_root_placeholder",
        "runtime_state|exclude", "non_filesystem_slash_text|preserve",
        "absolute_path_semantics_example|semantic_placeholder",
        "unmapped|fail"]) {
        let parts = pair.split("|"); let row = CkbPortablePathCategory()
        row.id = parts[0]; row.action = parts[1]; policy.categories.add(row)
    }
    policy
}

private func typedPathContext(policy: String, roots: String, routes: String,
    worktree: String, production: String, user: String): String {
    "{\"schemaVersion\":\"ckb-repro-path-context-v1\"," +
        "\"portablePolicyHash\":\"${ckbReproBundleHash(policy.toArray())}\"," +
        "\"localRootMapHash\":\"${ckbReproBundleHash(roots.toArray())}\"," +
        "\"apiRoutesHash\":\"${ckbReproBundleHash(routes.toArray())}\"," +
        "\"worktreeRoot\":\"${worktree}\",\"productionStoreRoot\":" +
        "\"${production}\",\"userConfigRoot\":\"${user}\"}"
}

private func typedEvalSupport(): CangjieEvalSupportSnapshot {
    let snapshot = CangjieEvalSupportSnapshot()
    snapshot.datasetVersion = "cangjie-eval-v1"
    let rows = ArrayList<String>()
    rows.add(typedEvalRow(snapshot.datasetVersion, "prompt", "prompt.md",
        "public prompt text"))
    rows.add(typedEvalRow(snapshot.datasetVersion, "metadata", "metadata.json",
        "public metadata text"))
    rows.add(typedEvalRow(snapshot.datasetVersion, "eval_support",
        "starter/src/eval_support.cj", "public EvalValue helper"))
    rows.add(typedEvalRow(snapshot.datasetVersion, "visible_test_helpers",
        "tests/TestMain.cj", "visible helper"))
    for (row in rows) { snapshot.jsonl += row + "\n" }
    snapshot.recordCount = 4
    snapshot.checksum = benchmarkGapSha256("${snapshot.schemaVersion}:" +
        "${snapshot.datasetVersion}:${snapshot.revision}:${snapshot.jsonl}")
    snapshot.authorityHash = snapshot.checksum
    snapshot
}

private func typedEvalRow(version: String, family: String, path: String,
    content: String): String {
    let caseId = "CJ-HUMANEVAL-000"
    let sourceId = "eval-support-${caseId}-${family}"
    "{\"schemaVersion\":\"ckb-eval-support-v1\",\"datasetVersion\":\"" +
        "${version}\",\"revision\":1,\"sourceId\":\"${sourceId}\"," +
        "\"caseId\":\"${caseId}\",\"sourceFamily\":\"${family}\"," +
        "\"path\":\"${path}\",\"contentHash\":\"" +
        "${benchmarkGapSha256("${sourceId}\n${content}")}\",\"title\":\"title\"," +
        "\"citation\":\"${caseId}:${path}\",\"content\":\"${content}\"," +
        "\"targetVersion\":\"1.0.0\"}"
}

private func typedRunnerInputs(): CkbReproRunnerInputs {
    let value = CkbReproRunnerInputs(); value.runId = "run-中文🙂"
    value.repoRoot = "/tmp/repo"; value.runsRoot = "/tmp/repo/runs"
    value.datasetRoot = "/tmp/dataset"
    value.authorityManifestPath = "/tmp/private/authority.json"
    value.ckbBin = "/tmp/bin/ckb"; value.ckbConfig = "/tmp/config/ckb.conf"
    value.ckbStore = "/tmp/store"; value.ckbHttpBase = "http://127.0.0.1:18890"
    value.claudeBin = "/tmp/bin/claude"; value.docsRoot = "/tmp/docs"
    value.candidateVersion = "candidate-v1"; value.knowledgeVersion = "v1"
    value.providerIdentityHash = benchmarkGapSha256("provider")
    value.providerIdentityArtifactPath = "/tmp/private/provider.json"
    value.frozenCandidateManifestPath = "/tmp/private/candidate.json"
    value.observedEnvironmentPath = "/tmp/private/observed-environment.json"
    value.certificationPreflightPath = "/tmp/private/preflight.json"
    value.certificationRunManifestPath = "/tmp/private/run.json"
    value
}

private func typedRoot(name: String): String {
    let path = Path("/tmp/ckb-typed-${name}-" +
        DateTime.now().toUnixTimeStamp().toString())
    if (exists(path)) { remove(path, recursive: true) }
    Directory.create(path, recursive: true)
    canonicalize(path).toString()
}
