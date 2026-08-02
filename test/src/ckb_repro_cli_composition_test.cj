package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.process.launch
import std.time.DateTime
import std.unittest.*
import std.unittest.testmacro.*

private func cliCompositionHash(value: String): String {
    ckbReproBundleHash(value.toArray())
}

private func cliCompositionReadUtf8(path: Path): String {
    let bytes = File.readFrom(path)
    try { String.fromUtf8(bytes) } catch (_: Exception) {
        throw Exception("fixture_invalid_response_encoding")
    }
}

private func cliCompositionRoles(mode: String): Array<String> {
    if (mode == "p3-vector-build") {
        return ["runtime_config", "path_policy", "local_root_map",
            "api_routes", "path_context"]
    }
    if (mode == "p3-snapshot-create") {
        return ["runtime_config", "path_policy", "local_root_map",
            "api_routes", "path_context"]
    }
    if (mode == "p3-snapshot-restore" || mode == "p3-snapshot-verify") {
        return ["runtime_config", "path_policy", "local_root_map",
            "api_routes", "path_context", "qdrant_manifest"]
    }
    if (mode == "p3-parity") {
        return ["runtime_config", "path_policy", "local_root_map",
            "api_routes", "path_context", "mcp_stdio_command"]
    }
    if (mode == "p4-build") {
        return ["public_build_input_manifest", "private_build_authority",
            "local_root_map", "path_context", "eval_support",
            "leakage_authority", "runtime_config"]
    }
    if (mode == "p4-promote") {
        return ["runtime_config", "path_policy", "local_root_map",
            "api_routes", "path_context"]
    }
    if (mode == "run-certify") {
        return ["logical_manifest", "qdrant_manifest", "parity_manifest",
            "path_policy", "local_root_map", "api_routes",
            "public_build_input_manifest", "private_build_authority",
            "path_context", "eval_support", "leakage_authority",
            "runtime_transport", "mcp_stdio_command", "runner_inputs",
            "runner_authority", "reference_template", "authority_manifest",
            "environment_lock", "environment_preflight",
            "run_critical_manifest", "experiment_profile"]
    }
    ["logical_manifest", "qdrant_manifest", "parity_manifest",
        "path_policy", "local_root_map", "api_routes",
        "public_build_input_manifest", "private_build_authority",
        "path_context", "eval_support", "leakage_authority",
        "runtime_transport", "mcp_stdio_command", "release_asset_authority",
        "reference_template", "environment_lock", "run_critical_manifest"]
}

private func cliCompositionPrivateAuthority(): String {
    "{\"schemaVersion\":\"ckb-repro-private-cli-authority-v1\"," +
        "\"localRootMap\":\"private-authority/local-roots.json\"," +
        "\"pathContext\":\"private-authority/path-context.json\"," +
        "\"evalSupport\":\"private-authority/eval-support.json\"," +
        "\"leakageAuthority\":\"private-authority/leakage.json\"}"
}

private func cliCompositionBuildManifest(): String {
    let manifest = CkbReproBuildInputManifest()
    manifest.schemaVersion = "ckb-repro-build-inputs-v1"
    manifest.candidateVersion = "候选🙂-v1"
    manifest.targetVersion = "public-v1"
    manifest.expectedRawCount = 7978
    for (role in ckbReproPublicBuildInputRoles()) {
        let asset = CkbReproBuildInputAsset()
        asset.role = role; asset.relativePath = "build-inputs/${role}.json"
        asset.size = 1; asset.sha256 = cliCompositionHash(role)
        manifest.assets.add(asset)
    }
    renderCkbReproBuildInputManifest(manifest)
}

private func cliCompositionPath(role: String): String {
    if (role == "private_build_authority") {
        return "private-authority/build-authority.json"
    }
    if (role == "runner_authority") {
        return "private-authority/runner-authority.json"
    }
    if (role == "local_root_map") {
        return "private-authority/local-roots.json"
    }
    if (role == "path_context") {
        return "private-authority/path-context.json"
    }
    if (role == "eval_support") {
        return "private-authority/eval-support.json"
    }
    if (role == "leakage_authority") {
        return "private-authority/leakage.json"
    }
    "assets/${role}.json"
}

private func cliCompositionContent(role: String): String {
    if (role == "private_build_authority") {
        return cliCompositionPrivateAuthority()
    }
    if (role == "runner_authority") {
        return "{\"schemaVersion\":\"ckb-repro-runner-authority-v1\"," +
            "\"credentialEnvironmentVariables\":[\"ANTHROPIC_AUTH_TOKEN\"]}"
    }
    if (role == "public_build_input_manifest") {
        return cliCompositionBuildManifest()
    }
    "资料🙂:${role}"
}

private func cliCompositionManifest(mode: String): CkbReproCliCompositionManifest {
    let manifest = CkbReproCliCompositionManifest()
    manifest.schemaVersion = "ckb-repro-cli-composition-v1"
    manifest.mode = mode
    for (role in cliCompositionRoles(mode)) {
        let content = cliCompositionContent(role)
        let asset = CkbReproCliCompositionAsset()
        asset.role = role; asset.relativePath = cliCompositionPath(role)
        asset.size = content.toArray().size
        asset.sha256 = cliCompositionHash(content)
        manifest.assets.add(asset)
    }
    manifest
}

private func cliCompositionRoot(mode: String,
    validAuthority!: Bool = true): String {
    let suffix = DateTime.now().toUnixTimeStamp().toString() +
        "-${mode.hashCode()}-${validAuthority.hashCode()}"
    let path = Path("/tmp/ckb-cli-composition-${suffix}")
    if (exists(path)) { remove(path, recursive: true) }
    Directory.create(path)
    let root = canonicalize(path).toString()
    let composition = cliCompositionManifest(mode)
    for (row in composition.assets) {
        cliCompositionWriteFile(root, row.relativePath,
            cliCompositionContent(row.role))
    }
    let compositionText = renderCkbReproCliCompositionManifest(composition)
    cliCompositionWriteFile(root,
        "reproducibility/manifests/runtime-composition.json", compositionText)
    let current = cliCompositionReadUtf8(Path(
        "../reproducibility/manifests/environment-lock.json"))
    let hash = if (validAuthority) { cliCompositionHash(compositionText) }
        else { cliCompositionHash("wrong") }
    cliCompositionWriteFile(root,
        "reproducibility/manifests/environment-lock.json",
        current.replace("\"compositionManifestHash\": \"\"",
            "\"compositionManifestHash\": \"${hash}\""))
    root
}

private func cliCompositionWriteFile(root: String, relativePath: String,
    content: String): Unit {
    let target = Path(root).join(relativePath)
    if (!exists(target.parent)) { Directory.create(target.parent, recursive: true) }
    File.writeTo(target, content.toArray())
}

@Test
public class CkbReproCliCompositionTest {
    @TestCase
    public func parserAcceptsCanonicalUnicodeAndRejectsMalformedInputs(): Unit {
        for (mode in ["p3-vector-build", "p4-build", "run-certify",
            "release-verify"]) {
            let manifest = cliCompositionManifest(mode)
            let parsed = parseCkbReproCliCompositionManifest(
                renderCkbReproCliCompositionManifest(manifest).toArray())
            @Expect(parsed[0].ok, true)
            @Expect(parsed[1].mode, mode)
        }
        @Expect(parseCkbReproCliCompositionManifest([0xff, 0xfe])[0].diagnostic,
            "invalid_response_encoding")
        @Expect(parseCkbReproCliCompositionManifest("{".toArray())[0].diagnostic,
            "malformed_json")
        let valid = renderCkbReproCliCompositionManifest(
            cliCompositionManifest("p3-vector-build"))
        @Expect(parseCkbReproCliCompositionManifest(
            valid.replace("\"assets\":", "\"unknown\":1,\"assets\":")
                .toArray())[0].diagnostic,
            "cli_composition_field_contract_invalid")
        let longText = StringBuilder()
        for (_ in 0..40000) { longText.append("中🙂") }
        @Expect(parseCkbReproCliCompositionManifest(longText.toString().toArray())[0]
            .diagnostic, "cli_composition_size_invalid")
    }

    @TestCase
    public func modeContractsRejectDuplicatesTraversalAndCrossModeAssets(): Unit {
        let duplicate = cliCompositionManifest("p3-vector-build")
        duplicate.assets[1].role = duplicate.assets[0].role
        @Expect(validateCkbReproCliCompositionManifest(duplicate).diagnostic,
            "cli_composition_asset_invalid")
        let traversal = cliCompositionManifest("p3-vector-build")
        traversal.assets[0].relativePath = "../config.json"
        @Expect(validateCkbReproCliCompositionManifest(traversal).ok, false)
        let b = cliCompositionManifest("release-verify")
        b.assets[0].role = "runner_inputs"
        @Expect(validateCkbReproCliCompositionManifest(b).diagnostic,
            "cli_composition_asset_invalid")
        let a = cliCompositionManifest("run-certify")
        a.assets.remove(at: a.assets.size - 1)
        @Expect(validateCkbReproCliCompositionManifest(a).diagnostic,
            "cli_composition_mode_contract_invalid")
    }

    @TestCase
    public func buildAndPrivateAuthorityParsersAreStrict(): Unit {
        let build = cliCompositionBuildManifest()
        @Expect(parseCkbReproBuildInputManifest(build.toArray())[0].ok, true)
        @Expect(parseCkbReproBuildInputManifest(
            build.replace("\"assets\":", "\"extra\":0,\"assets\":")
                .toArray())[0].ok, false)
        @Expect(parseCkbReproBuildInputManifest([0xff])[0].diagnostic,
            "invalid_response_encoding")
        let authority = cliCompositionPrivateAuthority()
        @Expect(parseCkbReproCliPrivateAuthority(
            authority.toArray(), "release-verify")[0].ok, true)
        @Expect(parseCkbReproCliPrivateAuthority(
            authority.replace("}",
                ",\"credentialEnvironmentVariables\":[\"TOKEN\"]}").toArray(),
            "release-verify")[0].diagnostic,
            "private_authority_field_contract_invalid")
        for (field in ["runner", "model", "provider"]) {
            @Expect(parseCkbReproCliPrivateAuthority(authority.replace("}",
                ",\"${field}\":\"forbidden\"}").toArray(),
                "release-verify")[0].diagnostic,
                "private_authority_field_contract_invalid")
        }
        @Expect(parseCkbReproCliPrivateAuthority(
            [0xff, 0xfe], "release-verify")[0].diagnostic,
            "invalid_response_encoding")
        @Expect(parseCkbReproCliPrivateAuthority(
            "{".toArray(), "release-verify")[0].diagnostic,
            "malformed_json")
        let runner = "{\"schemaVersion\":\"ckb-repro-runner-authority-v1\"," +
            "\"credentialEnvironmentVariables\":[\"ANTHROPIC_AUTH_TOKEN\"]}"
        @Expect(parseCkbReproCliRunnerAuthority(
            runner.toArray(), "run-certify")[0].ok, true)
        @Expect(parseCkbReproCliRunnerAuthority(
            runner.replace("ANTHROPIC_AUTH_TOKEN", "TOKEN=secret").toArray(),
            "run-certify")[0].diagnostic,
            "credential_environment_variable_invalid")
        @Expect(parseCkbReproCliRunnerAuthority(
            runner.toArray(), "release-verify")[0].diagnostic,
            "runner_authority_mode_invalid")

        let root = cliCompositionRoot("p4-build")
        try {
            let changedAuthority = authority.replace(
                "private-authority/local-roots.json",
                "private-authority/other-roots.json")
            File.writeTo(Path(root).join(
                "private-authority/build-authority.json"),
                changedAuthority.toArray())
            let compositionPath = Path(root).join(
                "reproducibility/manifests/runtime-composition.json")
            let composition = cliCompositionReadUtf8(compositionPath)
                .replace(cliCompositionHash(authority),
                    cliCompositionHash(changedAuthority))
            File.writeTo(compositionPath, composition.toArray())
            let environmentPath = Path(root).join(
                "reproducibility/manifests/environment-lock.json")
            let environment = cliCompositionReadUtf8(environmentPath)
                .replace(cliCompositionHash(renderCkbReproCliCompositionManifest(
                    cliCompositionManifest("p4-build"))),
                    cliCompositionHash(composition))
            File.writeTo(environmentPath, environment.toArray())
            @Expect(loadCkbReproCliComposition(Path(root).join(
                "reproducibility/manifests/runtime-composition.json")
                .toString(), "p4-build").diagnostic,
                "private_authority_asset_mismatch")
        } finally { if (exists(Path(root))) { remove(Path(root), recursive: true) } }
    }

    @TestCase
    public func loaderReadsAuthorizedP3P4AndP8Modes(): Unit {
        for (mode in ["p3-vector-build", "p4-build", "run-certify",
            "release-verify"]) {
            let root = cliCompositionRoot(mode)
            try {
                let loaded = loadCkbReproCliComposition(Path(root).join(
                    "reproducibility/manifests/runtime-composition.json")
                    .toString(), mode)
                @Expect(loaded.ok, true)
                @Expect(loaded.assets.size, cliCompositionRoles(mode).size)
                for (asset in loaded.assets) {
                    @Expect(asset.privateAuthority,
                        asset.relativePath.startsWith("private-authority/"))
                }
            } finally { if (exists(Path(root))) { remove(Path(root), recursive: true) } }
        }
    }

    @TestCase
    public func loaderRequiresOuterAuthorityBeforeReadingDeclaredAssets(): Unit {
        @Expect(parseCkbReproCliCompositionAuthority([0xff])[0].diagnostic,
            "invalid_response_encoding")
        @Expect(parseCkbReproCliCompositionAuthority("{".toArray())[0]
            .diagnostic, "cli_composition_authority_field_contract_invalid")
        let root = cliCompositionRoot("p3-vector-build",
            validAuthority: false)
        try {
            let loaded = loadCkbReproCliComposition(Path(root).join(
                "reproducibility/manifests/runtime-composition.json")
                .toString(), "p3-vector-build")
            @Expect(loaded.ok, false)
            @Expect(loaded.diagnostic, "cli_composition_authority_mismatch")
        } finally { if (exists(Path(root))) { remove(Path(root), recursive: true) } }
    }

    @TestCase
    public func loaderRejectsHashSymlinkAndToctouDrift(): Unit {
        let root = cliCompositionRoot("p3-vector-build")
        try {
            let path = Path(root).join("assets/runtime_config.json")
            File.writeTo(path, "changed".toArray())
            @Expect(loadCkbReproCliComposition(Path(root).join(
                "reproducibility/manifests/runtime-composition.json")
                .toString(), "p3-vector-build").ok, false)
        } finally { if (exists(Path(root))) { remove(Path(root), recursive: true) } }

        let symlinkRoot = cliCompositionRoot("p3-vector-build")
        try {
            let target = Path(symlinkRoot).join("assets/runtime_config.json")
            let outside = Path("/tmp/ckb-cli-composition-outside.txt")
            File.writeTo(outside, "outside".toArray())
            remove(target)
            @Expect(launch("/bin/ln", ["-s", outside.toString(),
                target.toString()]).wait(), 0)
            @Expect(loadCkbReproCliComposition(Path(symlinkRoot).join(
                "reproducibility/manifests/runtime-composition.json")
                .toString(), "p3-vector-build").ok, false)
            remove(outside)
        } finally {
            if (exists(Path(symlinkRoot))) { remove(Path(symlinkRoot), recursive: true) }
        }

        let source = cliCompositionReadUtf8(Path(
            "../src/ckb_repro_cli_composition.cj"))
        @Expect(source.contains("observed.identity != initial.identity"), true)
        @Expect(source.contains("authorityAfter[1] != authorityBytes[1]"), true)
        @Expect(source.contains("manifestAfter[1] != manifestBytes[1]"), true)
    }
}
