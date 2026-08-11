package cangjie_community_knowledge_base_test

import std.fs.{Directory, File, Path, canonicalize, exists, remove, rename}
import std.io.InputStream
import std.collection.ArrayList
import std.process.{ProcessRedirect, launch}
import std.unittest.*
import std.unittest.testmacro.*

private func r6O1cExisting(name: String): String {
    canonicalize(Path(name)).toString()
}

private func r6O1cNew(name: String): String {
    Path(canonicalize(Path("/tmp")).toString()).join(name).toString()
}

private func r6O1cReadPipe(pipe: InputStream): String {
    let bytes = ArrayList<UInt8>()
    let buffer = Array<UInt8>(1024, repeat: UInt8(0))
    while (true) {
        let count = pipe.read(buffer)
        if (count <= 0) { break }
        for (index in 0..count) { bytes.add(buffer[index]) }
    }
    String.fromUtf8(bytes.toArray()).trimAscii()
}

private func r6O1cSandbox(): String {
    let process = launch("mktemp", ["-d", "/tmp/ckb-r6-parity-XXXXXX"],
        stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
    let output = spawn { => r6O1cReadPipe(process.stdOutPipe) }
    let error = spawn { => r6O1cReadPipe(process.stdErrPipe) }
    let code = process.wait(); let path = output.get(); _ = error.get()
    if (code != 0 || path == "") { throw Exception("mktemp failed") }
    canonicalize(Path(path)).toString()
}

private func r6O1cOwnedRemove(path: String, files: Array<String>): Unit {
    if (!exists(Path(path))) { return }
    let identity = ckbReproDirectoryOwnershipIdentity(path)
    if (identity == "" || !ckbReproCleanupOwnedDirectory(path, identity, files)) {
        throw Exception("owned cleanup failed")
    }
}

private func r6O1cParityCleanup(sandbox: String): Unit {
    let stage = Path(sandbox).join("stage")
    if (exists(stage)) {
        r6O1cOwnedRemove(stage.join("assets").toString(),
            ["runtime_config.json", "path_policy.json", "api_routes.json",
                "mcp_stdio_command.json", "logical_manifest.json"])
        r6O1cOwnedRemove(stage.join("private-authority").toString(),
            ["local-roots.json", "path-context.json"])
        r6O1cOwnedRemove(stage.join("public-build-inputs").toString(), [])
        r6O1cOwnedRemove(stage.join("reproducibility/manifests").toString(),
            ["runtime-composition.json"])
        r6O1cOwnedRemove(stage.join("reproducibility").toString(), [])
        r6O1cOwnedRemove(stage.toString(), [])
    }
    let fixture = Path(sandbox).join("fixture")
    if (exists(fixture)) {
        for (name in ["worktree", "store-资料🙂", "user"]) {
            r6O1cOwnedRemove(fixture.join(name).toString(), [])
        }
        r6O1cOwnedRemove(fixture.toString(),
            ["ckb-仓颉🙂", "ckb-配置🙂.toml", "local-roots.json",
                "path-context.json", "logical.json"])
    }
    r6O1cOwnedRemove(sandbox, [])
}

private func r6O1cMinimalArgs(root: String): Array<String> {
    let runtime = r6O1cExisting("../assets/repro-runtime-config.json")
    let policy = r6O1cExisting("../public-build-inputs/portable-path-policy.json")
    let routes = r6O1cExisting("../public-build-inputs/api-routes.json")
    let environment = r6O1cExisting(
        "../reproducibility/manifests/environment-lock.json")
    ["ckb-repro-composition-stage", "--root", root,
        "--mode", "p3-vector-build",
        "--environment-plan", environment,
        "--attestation-authority", environment,
        "--input", "runtime_config=${runtime}",
        "--input", "path_policy=${policy}",
        "--input", "local_root_map=${runtime}",
        "--input", "api_routes=${routes}",
        "--input", "path_context=${runtime}"]
}

private func r6O1cParityLogicalManifest(): CkbLogicalSnapshotManifest {
    let value = CkbLogicalSnapshotManifest()
    value.schemaVersion = "ckb-logical-snapshot-v1"
    value.portableKnowledgeVersion = "portable-knowledge-v1"
    value.p4PortableProofHash = benchmarkGapSha256("p4")
    value.p3VectorProofHash = benchmarkGapSha256("vector")
    value.vectorState = EmbeddingProviderState.READY
    value.vectorCollection = "portable-v1"
    value.vectorCount = ckbReproReleaseRecordCount()
    value.vectorDimension = 1024
    value.rawCount = 1; value.normalizedCount = 1
    value.normalizedChecksum = benchmarkGapSha256("normalized")
    value.indexCount = 1; value.graphNodeCount = 0; value.graphEdgeCount = 0
    value.activePointerHash = benchmarkGapSha256("pointer")
    value.contaminationProofHash = benchmarkGapSha256("contamination")
    let asset = CkbLogicalSnapshotAsset()
    asset.relativePath = "transactions/portable/COMMIT"
    asset.size = 1; asset.sha256 = benchmarkGapSha256("asset")
    value.assets.add(asset)
    _ = buildCkbLogicalSnapshotManifest(value)
    value
}

private func r6O1cParityArgs(root: String, fixture: String): Array<String> {
    let fixturePath = Path(fixture)
    Directory.create(fixturePath, recursive: false)
    let worktree = fixturePath.join("worktree")
    let store = fixturePath.join("store-资料🙂")
    let user = fixturePath.join("user")
    for (path in [worktree, store, user]) { Directory.create(path) }
    let executable = fixturePath.join("ckb-仓颉🙂")
    let config = fixturePath.join("ckb-配置🙂.toml")
    File.writeTo(executable, "ckb-binary".toArray())
    File.writeTo(config, "[runtime]".toArray())

    let runtime = r6O1cExisting("../assets/repro-runtime-config.json")
    let policy = r6O1cExisting(
        "../public-build-inputs/portable-path-policy.json")
    let routes = r6O1cExisting("../public-build-inputs/api-routes.json")
    let roots = CkbPortableLocalRootMap()
    roots.schemaVersion = "ckb-portable-local-root-map-v1"
    let source = CkbPortableLocalRoot()
    source.sourceId = "repository"; source.kind = "PROJECT_ROOT"
    source.localRoot = canonicalize(worktree).toString(); roots.roots.add(source)
    let rootsPath = fixturePath.join("local-roots.json")
    let rootsText = renderCkbReproCliLocalRootMap(roots)
    File.writeTo(rootsPath, rootsText.toArray())
    let pathContext = buildAndRenderCkbReproCliPathContext(
        File.readFrom(Path(policy)), rootsText.toArray(),
        File.readFrom(Path(routes)), canonicalize(worktree).toString(),
        canonicalize(store).toString(), canonicalize(user).toString())
    let contextPath = fixturePath.join("path-context.json")
    File.writeTo(contextPath, pathContext[1].toArray())
    let logicalPath = fixturePath.join("logical.json")
    File.writeTo(logicalPath, renderCkbLogicalSnapshotManifest(
        r6O1cParityLogicalManifest()).toArray())
    let environment = r6O1cExisting(
        "../reproducibility/manifests/environment-lock.json")
    ["ckb-repro-composition-stage", "--root", root,
        "--mode", "p3-parity-build", "--prepare-only",
        "--environment-plan", environment,
        "--ckb-executable", canonicalize(executable).toString(),
        "--ckb-config", canonicalize(config).toString(),
        "--ckb-store", canonicalize(store).toString(),
        "--input", "runtime_config=${runtime}",
        "--input", "path_policy=${policy}",
        "--input", "local_root_map=${canonicalize(rootsPath)}",
        "--input", "api_routes=${routes}",
        "--input", "path_context=${canonicalize(contextPath)}",
        "--input", "logical_manifest=${canonicalize(logicalPath)}",
        "--json"]
}

private func r6O1cWithoutOption(args: Array<String>, name: String): Array<String> {
    let out = ArrayList<String>(); var index: Int64 = 0
    while (index < args.size) {
        if (args[index] == name) { index += 2; continue }
        out.add(args[index]); index += 1
    }
    out.toArray()
}

private func r6O1cReplaceOption(args: Array<String>, name: String,
    value: String): Array<String> {
    let out = args.clone()
    for (index in 0..out.size - 1) {
        if (out[index] == name) { out[index + 1] = value; break }
    }
    out
}

private class R6O1cRuntimeProbe <: CkbReproCompositionRuntimeProbe {
    let diagnostic: String
    let imageId: String
    public init(imageId: String, diagnostic!: String = "ok") {
        this.imageId = imageId; this.diagnostic = diagnostic
    }
    public func inspectQdrantImage(_: String, _: String): (String, String) {
        (this.diagnostic, this.imageId)
    }
}

@Test
public class CkbReproCompositionStageTest {
    @TestCase
    public func r6O1cUt01CanonicalModePlanHasNoSecondRoleMap(): Unit {
        @Expect(ckbReproCliCompositionRoles("p4-build").size, 9)
        @Expect(ckbReproCliCompositionRoles("p3-vector-build").size, 5)
        @Expect(ckbReproCliCompositionRoles("p3-parity-build").size, 7)
        @Expect(ckbReproCliCompositionRoles("run-certify").size, 19)
        @Expect(ckbReproCliCompositionRoleRelativePath("local_root_map"),
            "private-authority/local-roots.json")
        @Expect(ckbReproCliCompositionRoleRelativePath("unknown"), "")
    }

    @TestCase
    public func r6O1cUt02OptionsRejectGeneratedRoleAndDuplicateSource(): Unit {
        let root = r6O1cNew("r6-o1c-stage-options-unit")
        let valid = parseCkbReproCompositionStageOptions(
            r6O1cMinimalArgs(root))
        @Expect(valid.diagnostic, "ok")
        let generated = ArrayList<String>()
        generated.add(all: r6O1cMinimalArgs(root + "-generated"))
        generated.add("--input")
        generated.add("eval_support=" +
            r6O1cExisting("../assets/repro-runtime-config.json"))
        @Expect(parseCkbReproCompositionStageOptions(generated.toArray()).diagnostic,
            "composition_stage_input_invalid")
        let duplicate = ArrayList<String>()
        duplicate.add(all: r6O1cMinimalArgs(root + "-duplicate"))
        duplicate.add("--input")
        duplicate.add("runtime_config=" +
            r6O1cExisting("../assets/repro-runtime-config.json"))
        @Expect(parseCkbReproCompositionStageOptions(duplicate.toArray()).diagnostic,
            "composition_stage_input_invalid")
        for (role in ["runtime_transport", "mcp_stdio_command",
            "runner_inputs", "runner_authority", "reference_template"]) {
            let forbidden = ArrayList<String>()
            forbidden.add(all: r6O1cMinimalArgs(root + "-${role}"))
            forbidden[4] = "run-certify"
            forbidden.add("--input")
            forbidden.add("${role}=" +
                r6O1cExisting("../assets/repro-runtime-config.json"))
            @Expect(parseCkbReproCompositionStageOptions(
                forbidden.toArray()).diagnostic,
                "composition_stage_input_invalid")
        }
    }

    @TestCase
    public func r6O1cUt03RunnerAuthoritySortsAndDeduplicatesNames(): Unit {
        let built = buildCkbReproCliRunnerAuthority([
            "GLM_API_KEY", "CKB_EMBEDDING_TOKEN", "GLM_API_KEY"])
        @Expect(built[0].ok, true)
        @Expect(renderCkbReproCliRunnerAuthority(built[1]),
            "{\"schemaVersion\":\"ckb-repro-runner-authority-v1\"," +
            "\"credentialEnvironmentVariables\":[\"CKB_EMBEDDING_TOKEN\"," +
            "\"GLM_API_KEY\"]}")
    }

    @TestCase
    public func r6O1cUt04LocalRootsAreTypedAndP4InputInjectionIsForbidden(): Unit {
        let root = r6O1cExisting("..")
        let args = ArrayList<String>()
        args.add(all: r6O1cMinimalArgs(r6O1cNew("r6-o1c-local-root")))
        args.add("--local-root")
        args.add("repository|source|${root}")
        let parsed = parseCkbReproCompositionStageOptions(args.toArray())
        @Expect(parsed.diagnostic, "ok")
        @Expect(parsed.localRoots.size, 1)
        @Expect(parsed.localRoots[0].sourceId, "repository")
        let forbidden = CkbReproCompositionStageOptions()
        forbidden.root = r6O1cNew("r6-o1c-local-root-forbidden")
        forbidden.mode = "p4-build"
        forbidden.environmentPlan = r6O1cExisting(
            "../reproducibility/manifests/environment-lock.json")
        forbidden.attestationAuthority = forbidden.environmentPlan
        let injected = CkbReproCompositionStageInput()
        injected.role = "local_root_map"
        injected.path = r6O1cExisting(
            "../assets/repro-runtime-config.json")
        forbidden.inputs.add(injected)
        @Expect(validateCkbReproCompositionStageOptions(forbidden),
            "composition_stage_input_invalid")
    }

    @TestCase
    public func r6O1cPos01ParityBuildPublishesOwnedCanonicalMcpSpec(): Unit {
        let sandbox = r6O1cSandbox()
        let fixture = Path(sandbox).join("fixture").toString()
        let root = Path(sandbox).join("stage").toString()
        try {
            let args = r6O1cParityArgs(root, fixture)
            let result = runCkbReproCompositionStageCli(args)
            @Expect(result.ok, true)
            @Expect(result.providerCalls, 0)
            @Expect(result.modelCalls, 0)
            @Expect(result.runnerCalls, 0)
            @Expect(result.output.contains("providerCalls\":0"), true)
            let commandPath = Path(root).join("assets/mcp_stdio_command.json")
            let parsed = parseCkbMcpStdioCommandSpec(File.readFrom(commandPath))
            @Expect(parsed[0].ok, true)
            @Expect(parsed[1].executable,
                canonicalize(Path(fixture).join("ckb-仓颉🙂")).toString())
            @Expect(parsed[1].args.toArray(), ["--config",
                canonicalize(Path(fixture).join("ckb-配置🙂.toml")).toString(),
                "--store", canonicalize(Path(fixture).join("store-资料🙂")).toString(),
                "mcp-stdio"])
            @Expect(parsed[1].environment.toArray(), ["cjHeapSize=4GB"])
            @Expect(parsed[1].timeoutMillis, 300000)
            @Expect(exists(Path(root).join(
                "reproducibility/manifests/runtime-composition.json")), true)
        } finally {
            r6O1cParityCleanup(sandbox)
        }
    }

    @TestCase
    public func r6O1cUt05ParityBuildRequiresOwnedRuntimeInputsAndRejectsInjection(): Unit {
        let sandbox = r6O1cSandbox()
        let fixture = Path(sandbox).join("fixture").toString()
        let args = r6O1cParityArgs(Path(sandbox).join("stage").toString(), fixture)
        try {
            for (name in ["--ckb-executable", "--ckb-config", "--ckb-store"]) {
                @Expect(parseCkbReproCompositionStageOptions(
                    r6O1cWithoutOption(args, name)).diagnostic,
                    "composition_stage_p3_parity_inputs_required")
            }
            let injected = ArrayList<String>(); injected.add(all: args)
            injected.add("--input")
            injected.add("mcp_stdio_command=" +
                canonicalize(Path(fixture).join("ckb-配置🙂.toml")).toString())
            @Expect(parseCkbReproCompositionStageOptions(
                injected.toArray()).diagnostic,
                "composition_stage_input_invalid")
        } finally {
            r6O1cParityCleanup(sandbox)
        }
    }

    @TestCase
    public func r6O1cBnd07ParityBuildRejectsSymlinkAndNoncanonicalInputs(): Unit {
        let sandbox = r6O1cSandbox()
        let fixture = Path(sandbox).join("fixture").toString()
        let args = r6O1cParityArgs(Path(sandbox).join("stage").toString(), fixture)
        let link = Path(fixture).join("ckb-link")
        try {
            let executable = canonicalize(Path(fixture).join("ckb-仓颉🙂"))
            @Expect(launch("/bin/ln", ["-s", executable.toString(),
                link.toString()]).wait(), 0)
            @Expect(parseCkbReproCompositionStageOptions(
                r6O1cReplaceOption(args, "--ckb-executable",
                    link.toString())).diagnostic,
                "composition_stage_p3_parity_inputs_required")
            let noncanonical = Path(fixture).join("nested/../ckb-配置🙂.toml")
                .toString()
            @Expect(parseCkbReproCompositionStageOptions(
                r6O1cReplaceOption(args, "--ckb-config", noncanonical)).diagnostic,
                "composition_stage_p3_parity_inputs_required")
        } finally {
            if (exists(link)) { remove(link, recursive: false) }
            r6O1cParityCleanup(sandbox)
        }
    }

    @TestCase
    public func r6O1cBnd01McpRendererIsUtf8CanonicalAndRejectsBinary(): Unit {
        let spec = CkbMcpStdioCommandSpec()
        spec.schemaVersion = "ckb-mcp-stdio-command-v1"
        spec.executable = "/tmp/仓颉🙂/ckb"
        spec.timeoutMillis = 300000
        let rendered = renderCkbMcpStdioCommandSpec(spec)
        let parsed = parseCkbMcpStdioCommandSpec(rendered.toArray())
        @Expect(parsed[0].ok, true)
        @Expect(renderCkbMcpStdioCommandSpec(parsed[1]), rendered)
        @Expect(parseCkbMcpStdioCommandSpec([0xff, 0xfe])[0].diagnostic,
            "invalid_response_encoding")
    }

    @TestCase
    public func r6O1cBnd02ExistingOutputAndOverlapFailBeforeWrite(): Unit {
        let existing = r6O1cExisting("../assets")
        @Expect(parseCkbReproCompositionStageOptions(
            r6O1cMinimalArgs(existing)).diagnostic,
            "composition_stage_options_invalid")
        let root = r6O1cExisting("../assets/repro-runtime-config.json") +
            "/nested-new-root"
        @Expect(parseCkbReproCompositionStageOptions(
            r6O1cMinimalArgs(root)).diagnostic,
            "composition_stage_options_invalid")
    }

    @TestCase
    public func r6O1cBnd03FakeRuntimeProbeBindsImageAndEmptyMcp(): Unit {
        let image = benchmarkGapSha256("qdrant-image")
        let environment = CkbReproEnvironmentLock()
        environment.qdrantImageDigest = image
        let executable = r6O1cExisting(
            "../assets/repro-runtime-config.json")
        let docker = r6O1cExisting(
            "../public-build-inputs/portable-path-policy.json")
        let assets = probeAndRenderCkbReproRuntimeAssets(executable, docker,
            "http://127.0.0.1:6333",
            "http://127.0.0.1:8080/v1/cangjie/syntax-query",
            "http://127.0.0.1:8080/mcp",
            "qdrant/qdrant@${image}", 300000, environment,
            R6O1cRuntimeProbe(image))
        @Expect(assets.contract.ok, true)
        @Expect(assets.runtime.qdrantImageId, image)
        @Expect(assets.mcp.args.size, 0)
        @Expect(assets.mcp.environment.size, 0)
        @Expect(assets.mcp.executable, executable)
        @Expect(parseCkbP8OwnedLocalRuntimeAuthorityBytes(
            renderCkbP8OwnedLocalRuntimeAuthority(assets.runtime).toArray())[0].ok,
            true)
    }

    @TestCase
    public func r6O1cBnd04RuntimeProbeDriftAndNonLoopbackFailClosed(): Unit {
        let image = benchmarkGapSha256("qdrant-image")
        let environment = CkbReproEnvironmentLock()
        environment.qdrantImageDigest = image
        let executable = r6O1cExisting(
            "../assets/repro-runtime-config.json")
        let docker = r6O1cExisting(
            "../public-build-inputs/portable-path-policy.json")
        let drift = probeAndRenderCkbReproRuntimeAssets(executable, docker,
            "http://127.0.0.1:6333",
            "http://127.0.0.1:8080/v1/cangjie/syntax-query",
            "http://127.0.0.1:8080/mcp", "qdrant/qdrant@${image}",
            300000, environment,
            R6O1cRuntimeProbe(benchmarkGapSha256("other")))
        @Expect(drift.contract.diagnostic,
            "p8b_qdrant_image_authority_mismatch")
        let remote = probeAndRenderCkbReproRuntimeAssets(executable, docker,
            "http://10.0.0.1:6333",
            "http://127.0.0.1:8080/v1/cangjie/syntax-query",
            "http://127.0.0.1:8080/mcp", "qdrant/qdrant@${image}",
            300000, environment, R6O1cRuntimeProbe(image))
        @Expect(remote.contract.ok, false)
        @Expect(remote.runtime.schemaVersion, "")
    }

    @TestCase
    public func r6O1cBnd05SavedDirectoryIdentitiesRejectReplacement(): Unit {
        let root = Path(r6O1cNew("r6-o1c-identity-replacement"))
        if (exists(root)) { remove(root, recursive: true) }
        Directory.create(root, recursive: false)
        let parent = root.join("assets")
        Directory.create(parent, recursive: false)
        try {
            let rootIdentity = ckbReproDirectoryOwnershipIdentity(
                root.toString())
            let parentIdentity = ckbReproDirectoryOwnershipIdentity(
                parent.toString())
            let detached = root.join("assets-detached")
            rename(parent.toString(), to: detached.toString(), overwrite: false)
            Directory.create(parent, recursive: false)
            let descriptor = CkbReproOwnedTempDescriptor()
            descriptor.acquireBound(parent.toString(), ".payload.stage",
                "payload.json", expectedParentIdentity: parentIdentity,
                expectedGrandparentIdentity: rootIdentity)
            @Expect(descriptor.ok, false)
            @Expect(descriptor.diagnostic,
                "composition_parent_binding_invalid")
            @Expect(exists(parent.join(".payload.stage")), false)
            @Expect(exists(parent.join("payload.json")), false)
            @Expect(descriptor.cleanup(), true)
        } finally {
            if (exists(root)) { remove(root, recursive: true) }
        }
    }

    @TestCase
    public func r6O1cBnd06SavedGrandparentIdentityRejectsReplacement(): Unit {
        let container = Path(r6O1cNew("r6-o1c-grand-replacement"))
        if (exists(container)) { remove(container, recursive: true) }
        Directory.create(container, recursive: false)
        let grand = container.join("stage")
        let parent = grand.join("assets")
        Directory.create(grand, recursive: false)
        Directory.create(parent, recursive: false)
        try {
            let grandIdentity = ckbReproDirectoryOwnershipIdentity(
                grand.toString())
            let parentIdentity = ckbReproDirectoryOwnershipIdentity(
                parent.toString())
            rename(grand.toString(), to: container.join("stage-detached").toString(),
                overwrite: false)
            Directory.create(grand, recursive: false)
            Directory.create(grand.join("assets"), recursive: false)
            let descriptor = CkbReproOwnedTempDescriptor()
            descriptor.acquireBound(grand.join("assets").toString(),
                ".payload.stage", "payload.json",
                expectedParentIdentity: parentIdentity,
                expectedGrandparentIdentity: grandIdentity)
            @Expect(descriptor.ok, false)
            @Expect(descriptor.diagnostic,
                "composition_parent_binding_invalid")
            @Expect(exists(grand.join("assets/.payload.stage")), false)
            @Expect(exists(grand.join("assets/payload.json")), false)
            @Expect(descriptor.cleanup(), true)
        } finally {
            if (exists(container)) { remove(container, recursive: true) }
        }
    }

    @TestCase
    public func r6O1cNeg01UnknownModeAndRelativeInputFailClosed(): Unit {
        let args = r6O1cMinimalArgs(r6O1cNew("r6-o1c-negative")).clone()
        args[4] = "release-verify"
        @Expect(parseCkbReproCompositionStageOptions(args).diagnostic,
            "composition_stage_options_invalid")
        let relative = r6O1cMinimalArgs(r6O1cNew("r6-o1c-relative")).clone()
        relative[relative.size - 1] = "path_context=relative.json"
        @Expect(parseCkbReproCompositionStageOptions(relative).diagnostic,
            "composition_stage_input_invalid")
    }

    @TestCase
    public func r6O1cNeg02CredentialNamesNeverAcceptSecretValues(): Unit {
        let marker = "marker-secret-value-20260811"
        let invalid = buildCkbReproCliRunnerAuthority([
            "GLM_API_KEY=${marker}"])
        @Expect(invalid[0].ok, false)
        @Expect(renderCkbReproCliRunnerAuthority(invalid[1]).contains(marker),
            false)
        let valid = buildCkbReproCliRunnerAuthority(["GLM_API_KEY"])
        @Expect(valid[0].ok, true)
        @Expect(renderCkbReproCliRunnerAuthority(valid[1]).contains(marker),
            false)
    }

    @TestCase
    public func r6O1cNeg03CrossAssetTamperFailsBeforePublication(): Unit {
        let hash = benchmarkGapSha256("logical")
        let vector = benchmarkGapSha256("vector")
        let logical = CkbLogicalSnapshotManifest()
        logical.manifestHash = hash
        logical.p3VectorProofHash = vector
        logical.vectorCollection = "portable-v1"
        logical.vectorCount = 7817
        logical.vectorDimension = 1024
        logical.portableKnowledgeVersion = "knowledge-v1"
        let qdrant = CkbQdrantSnapshotManifest()
        qdrant.logicalManifestHash = hash
        qdrant.vectorProofHash = vector
        qdrant.collection = "portable-v1"
        qdrant.points = 7817
        qdrant.dimension = 1024
        let parity = CkbRetrievalParityManifest()
        parity.logicalManifestHash = hash
        parity.knowledgeVersion = "knowledge-v1"
        let build = CkbReproBuildProof()
        build.candidateVersion = "knowledge-v1"
        @Expect(validateCkbReproCompositionStageIdentity(logical, qdrant,
            parity, build).ok, true)
        qdrant.points = 7109
        @Expect(validateCkbReproCompositionStageIdentity(logical, qdrant,
            parity, build).diagnostic,
            "composition_stage_cross_asset_identity_mismatch")
    }

    @TestCase
    public func e2e05bReadinessRemainsNoModelAtOptionsBoundary(): Unit {
        let result = runCkbReproCompositionStageCli([
            "ckb-repro-composition-stage", "--mode", "run-certify", "--json"])
        @Expect(result.ok, false)
        @Expect(result.providerCalls, 0)
        @Expect(result.modelCalls, 0)
        @Expect(result.runnerCalls, 0)
        @Expect(result.output.contains("providerCalls\":0"), true)
        @Expect(ckbReproCliCompositionRoles("run-certify").size, 19)
    }
}
