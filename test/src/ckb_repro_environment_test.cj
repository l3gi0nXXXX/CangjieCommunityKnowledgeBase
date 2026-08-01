package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists, remove}
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.json.JsonValue

private class P6FakeRunner <: CkbReproRunnerInvoker {
    public var count: Int64 = 0
    public var args: Array<String> = Array<String>()
    public init() {}
    public func run(value: Array<String>): Int64 {
        this.count += 1
        this.args = value
        0
    }
}

private class P6FakeEnvironmentProbe <: CkbReproEnvironmentProbe {
    public var result: CkbReproEnvironmentProbeResult
    public var calls: Int64 = 0
    public init(value: CkbReproEnvironmentProbeResult) { this.result = value }
    public func inspect(attested: CkbReproEnvironmentLock,
        attestedInputHash: String):
        CkbReproEnvironmentProbeResult {
        this.calls += 1
        this.result
    }
}

@Test
public class CkbReproEnvironmentTest {
    @TestCase
    public func p6Ut01EnvironmentAndAuthorityContractsAreCanonical(): Unit {
        let environment = parseCkbReproEnvironmentLock(
            p6Read("../reproducibility/manifests/environment-lock.json"))
        @Expect(environment[0].ok, true)
        let environmentValidation = validateCkbReproEnvironmentLock(environment[1])
        @Expect(environmentValidation.ok, true)
        @Expect(environment[1].identityStatus, "planned")
        @Expect(validateCkbReproEnvironmentLock(environment[1],
            mode: "execution").diagnostic, "environment_identity_not_frozen")
        let critical = parseCkbRunCriticalFilesManifest(
            p6Read("../reproducibility/manifests/run-critical-files.json"))
        @Expect(critical[0].ok, true)
        let criticalContract = validateCkbRunCriticalFilesManifest(
            critical[1], "..", mode: "contract")
        let criticalExecution = validateCkbRunCriticalFilesManifest(
            critical[1], "..", mode: "execution")
        @Expect(criticalContract.ok, true)
        @Expect(criticalExecution.ok, true)
        @Expect(environment[1].runCriticalFilesManifestHash,
            criticalContract.manifestHash)
        @Expect(environment[1].runCriticalTreeHash,
            criticalExecution.treeHash)
        let environmentAgain = parseCkbReproEnvironmentLock(
            environmentValidation.canonicalJson.toArray())
        @Expect(environmentAgain[0].ok, true)
        @Expect(renderCkbReproEnvironmentLock(environmentAgain[1]),
            environmentValidation.canonicalJson)

        let blocked = parseCkbAuthorityDeliveryManifest(
            p6Read("../reproducibility/manifests/authority-delivery.json"))
        @Expect(blocked[0].ok, true)
        @Expect(selectCkbAuthorityDeliveryMode(blocked[1]).diagnostic, "blocked")

        let authorityBytes = p6SyntheticAuthorityBytes()
        let authority = parseCangjieHumanEvalAuthorityManifest(
            String.fromUtf8(authorityBytes))
        @Expect(authority.ok, true)
        @Expect(authority.rows.size, 164)
        let bundled = p6BundledDelivery(authorityBytes, authority.datasetVersion)
        let publicRebuild = p6PublicDelivery(authorityBytes,
            authority.datasetVersion)
        @Expect(selectCkbAuthorityDeliveryMode(bundled).diagnostic, "bundled")
        @Expect(selectCkbAuthorityDeliveryMode(publicRebuild).diagnostic,
            "public_rebuild")
        let bundledResult = buildCkbReproAuthorityBundle(bundled,
            authorityBytes, "/tmp/ckb-p6/bundled", "/tmp/ckb-store",
            "/tmp/ckb-student")
        let publicResult = buildCkbReproAuthorityFromPublicSource(publicRebuild,
            authorityBytes, "/tmp/ckb-p6/public", "/tmp/ckb-store",
            "/tmp/ckb-student")
        @Expect(bundledResult.ok, true)
        @Expect(publicResult.ok, true)
        @Expect(bundledResult.presentCount, 164)
        @Expect(publicResult.presentCount, 164)
        @Expect(bundledResult.treeHash, publicResult.treeHash)
        let publicAgain = parseCkbAuthorityDeliveryManifest(
            renderCkbAuthorityDeliveryManifest(publicRebuild).toArray())
        @Expect(publicAgain[0].ok, true)
        @Expect(renderCkbAuthorityDeliveryManifest(publicAgain[1]),
            renderCkbAuthorityDeliveryManifest(publicRebuild))
    }

    @TestCase
    public func p6Bnd01HeapEncodingTimeoutAndTransportBoundariesFailClosed(): Unit {
        @Expect(parseCkbReproEnvironmentLock([0xff, 0xfe])[0].diagnostic,
            "invalid_response_encoding")
        @Expect(parseCkbAuthorityDeliveryManifest([0xff, 0xfe])[0].diagnostic,
            "invalid_response_encoding")
        let expected = p6FrozenEnvironment()
        let seal = p6CertificationSeal()
        @Expect(ckbCertificationPreflightSealDiagnostic(seal[0], seal[1]), "ok")
        for (raw in ["", "仓颉🙂", "4095MB"]) {
            let heap = ckbServiceHeapPreflight(raw)
            let result = runCkbReproEnvironmentPreflight(expected, expected,
                heap, seal[0], seal[1])
            @Expect(result.ok, false)
            @Expect(result.startAllowed, false)
            @Expect(result.diagnostic, heap.errorCode)
            @Expect(result.heapResult.requiredHeapMiB, heap.requiredHeapMiB)
            @Expect(result.heapResult.actualHeapMiB, heap.actualHeapMiB)
        }
        @Expect(runCkbReproEnvironmentPreflight(expected, expected,
            ckbServiceHeapPreflight("4096MB"), seal[0], seal[1]).ok, true)

        for (timeout in [Int64(0), Int64(3601)]) {
            let invalid = p6FrozenEnvironment()
            invalid.timeoutSeconds = timeout
            @Expect(validateCkbReproEnvironmentLock(invalid,
                mode: "execution").diagnostic,
                "environment_experiment_contract_invalid")
        }
        for (timeout in [Int64(1), Int64(3600)]) {
            let boundary = p6FrozenEnvironment()
            boundary.timeoutSeconds = timeout
            @Expect(validateCkbReproEnvironmentLock(boundary,
                mode: "execution").ok, true)
        }
        let transport = p6FrozenEnvironment()
        transport.mcpTransport = "invalid"
        @Expect(validateCkbReproEnvironmentLock(transport,
            mode: "execution").diagnostic,
            "environment_experiment_contract_invalid")
        let encoding = p6FrozenEnvironment()
        encoding.glmBaseUrl = "https://服务.example/v1"
        @Expect(validateCkbReproEnvironmentLock(encoding,
            mode: "execution").ok, true)
        let localProvider = p6FrozenEnvironment()
        localProvider.glmBaseUrl = "https://127.0.0.1/v1"
        @Expect(validateCkbReproEnvironmentLock(localProvider,
            mode: "execution").diagnostic,
            "environment_provider_identity_invalid")
        let missingKey = p6FrozenEnvironment()
        missingKey.glmCredentialEnv = ""
        @Expect(validateCkbReproEnvironmentLock(missingKey,
            mode: "execution").diagnostic,
            "environment_provider_identity_invalid")
        let embeddingDrift = p6FrozenEnvironment()
        embeddingDrift.embeddingModel = ""
        @Expect(validateCkbReproEnvironmentLock(embeddingDrift,
            mode: "execution").diagnostic,
            "environment_embedding_identity_invalid")
        let claudeDrift = p6FrozenEnvironment()
        claudeDrift.claudeCodeVersion = ""
        @Expect(validateCkbReproEnvironmentLock(claudeDrift,
            mode: "execution").diagnostic,
            "environment_tool_identity_required")
        let osDrift = p6FrozenEnvironment()
        osDrift.certifiedPlatform = "Linux"
        @Expect(validateCkbReproEnvironmentLock(osDrift,
            mode: "execution").diagnostic,
            "environment_platform_unsupported")

        @Expect(parseCkbReproPreflightCliArgs([
            "ckb-repro-preflight", "--environment-lock", "/tmp/expected.json",
            "--observed-environment", "/tmp/observed.json",
            "--certification-preflight", "/tmp/preflight.json",
            "--certification-run-manifest", "/tmp/run-manifest.json",
            "--json"]).valid, true)
        @Expect(parseCkbReproPreflightCliArgs([
            "ckb-repro-preflight", "--environment-lock", "/tmp/expected.json",
            "--observed-environment", "/tmp/observed.json",
            "--certification-preflight", "/tmp/preflight.json",
            "--certification-run-manifest", "/tmp/run-manifest.json",
            "--json", "--json"]).diagnostic,
            "duplicate_argument:--json")
        @Expect(parseCkbReproPreflightCliArgs([
            "ckb-repro-preflight", "--token", "secret"]).diagnostic,
            "unknown_argument:--token")
    }

    @TestCase
    public func p6Pos01TypedIdentityBuildsExplicitRunnerArgumentsOnce(): Unit {
        let lock = p6FrozenEnvironment()
        let reference = parseCkbReproReferenceManifest(
            p6Read("../reproducibility/manifests/historical-reference-run.json"))[1]
        let inputs = p6RunnerInputs()
        let built = buildCkbReproRunnerArgs(reference, lock, inputs)
        @Expect(built[0].ok, true)
        let parsed = parseCkbAbcdeRunnerOptions(built[1])
        @Expect(parsed.runMode, "certification")
        @Expect(parsed.datasetRoot, inputs.datasetRoot)
        @Expect(parsed.manifestPath, inputs.authorityManifestPath)
        @Expect(parsed.runsRoot, inputs.runsRoot)
        @Expect(parsed.docsRoot, inputs.docsRoot)
        @Expect(parsed.caseStart, 0)
        @Expect(parsed.caseEnd, 163)
        @Expect(parsed.groups.size, 1)
        @Expect(parsed.groups[0], CkbAbcdeGroups.D)
        @Expect(parsed.candidateVersion, "portable-candidate-v1")
        @Expect(parsed.knowledgeVersion, "portable-knowledge-v1")
        @Expect(built[0].canonicalJson.contains("\"strictPassed\""), false)
        @Expect(built[0].canonicalJson.contains("historical_pre_portable"), false)

        let seal = p6CertificationSeal()
        let preflight = runCkbReproEnvironmentPreflight(lock, lock,
            ckbServiceHeapPreflight("4GB"), seal[0], seal[1])
        let runner = P6FakeRunner()
        @Expect(runCkbReproCertifiedStudent(reference, lock, inputs,
            preflight, runner), 0)
        @Expect(runner.count, 1)
        @Expect(runner.args, built[1])

        let rendered = renderCkbProviderTemplate(lock)
        @Expect(rendered.contains("GLM_API_KEY"), true)
        @Expect(rendered.contains("CKB_EMBEDDING_TOKEN"), true)
        @Expect(rendered.contains("Authorization"), false)
        @Expect(rendered.contains("Bearer "), false)

        let cliInputs = CkbReproPreflightCliInputs()
        cliInputs.expected = lock
        cliInputs.observed = lock
        cliInputs.heap = ckbServiceHeapPreflight("4GB")
        cliInputs.certificationPreflightJson = seal[0]
        cliInputs.certificationRunManifestJson = seal[1]
        let cli = executeCkbReproPreflightCliAdapter(
            parseCkbReproPreflightCliArgs([
                "ckb-repro-preflight", "--environment-lock", "/tmp/expected.json",
                "--observed-environment", "/tmp/observed.json",
                "--certification-preflight", "/tmp/preflight.json",
                "--certification-run-manifest", "/tmp/run-manifest.json"]),
            cliInputs)
        @Expect(cli.ok, true)
        let human = renderCkbReproPreflightCliHuman(cli, lock)
        @Expect(human.contains("preflight: passed"), true)
        @Expect(human.contains("{\""), false)
        @Expect(human.contains(lock.glmBaseUrl), false)
        @Expect(human.contains(lock.glmCredentialEnv), false)
        let json = renderCkbReproPreflightCliJson(cli, lock)
        @Expect(json.startsWith("{"), true)
        @Expect(json.contains(lock.glmBaseUrl), false)
        @Expect(json.contains(lock.glmCredentialEnv), false)
        let controlLock = p6FrozenEnvironment()
        controlLock.certifiedPlatform = "macOS\u{0001}"
        @Expect(try { JsonValue.fromStr(
            renderCkbReproPreflightCliJson(cli, controlLock)); true }
            catch (_: Exception) { false }, true)
    }

    @TestCase
    public func p6Neg01DriftBlockedAuthorityAndPathAttacksNeverStartRunner(): Unit {
        let lock = p6FrozenEnvironment()
        let drift = p6FrozenEnvironment()
        drift.glmModel = "wrong"
        let seal = p6CertificationSeal()
        let failed = runCkbReproEnvironmentPreflight(lock, drift,
            ckbServiceHeapPreflight("4GB"), seal[0], seal[1])
        @Expect(failed.ok, false)
        @Expect(failed.startAllowed, false)

        let reference = parseCkbReproReferenceManifest(
            p6Read("../reproducibility/manifests/historical-reference-run.json"))[1]
        let runner = P6FakeRunner()
        @Expect(runCkbReproCertifiedStudent(reference, lock, p6RunnerInputs(),
            failed, runner), 1)
        @Expect(runner.count, 0)
        let missingSeal = runCkbReproEnvironmentPreflight(lock, lock,
            ckbServiceHeapPreflight("4GB"), "", "")
        @Expect(missingSeal.diagnostic, "preflight_manifest_seal_mismatch")
        @Expect(runCkbReproCertifiedStudent(reference, lock, p6RunnerInputs(),
            missingSeal, runner), 1)
        let tamperedSeal = runCkbReproEnvironmentPreflight(lock, lock,
            ckbServiceHeapPreflight("4GB"),
            seal[0].replace("\"ok\":true", "\"ok\":false"), seal[1])
        @Expect(tamperedSeal.diagnostic, "preflight_manifest_seal_mismatch")
        @Expect(runCkbReproCertifiedStudent(reference, lock, p6RunnerInputs(),
            tamperedSeal, runner), 1)
        @Expect(runner.count, 0)

        let blocked = parseCkbAuthorityDeliveryManifest(
            p6Read("../reproducibility/manifests/authority-delivery.json"))[1]
        @Expect(validateCkbReproAuthorityDelivery(blocked, Array<UInt8>(),
            "", "/tmp/ckb-output", "/tmp/ckb-store",
            "/tmp/ckb-student").diagnostic,
            "authority_delivery_blocked")

        let authorityBytes = p6SyntheticAuthorityBytes()
        let parsedAuthority = parseCangjieHumanEvalAuthorityManifest(
            String.fromUtf8(authorityBytes))
        let publicRebuild = p6PublicDelivery(authorityBytes,
            parsedAuthority.datasetVersion)
        for (output in ["/tmp/ckb-store", "/tmp/ckb-store/authority",
            "/tmp/ckb-student/authority", "/tmp"]) {
            @Expect(validateCkbReproAuthorityDelivery(publicRebuild,
                authorityBytes, parsedAuthority.datasetVersion, output,
                "/tmp/ckb-store", "/tmp/ckb-student").diagnostic,
                "authority_output_root_forbidden")
        }
        for (output in ["target/output", "/tmp/../tmp/output",
            "/tmp//output", "/tmp\\output", " /tmp/output"]) {
            @Expect(validateCkbReproAuthorityDelivery(publicRebuild,
                authorityBytes, parsedAuthority.datasetVersion, output,
                "/tmp/ckb-store", "/tmp/ckb-student").diagnostic,
                "authority_output_root_invalid")
        }
        @Expect(validateCkbReproAuthorityDelivery(publicRebuild,
            authorityBytes, parsedAuthority.datasetVersion,
            "/tmp/ckb-store2", "/tmp/ckb-store",
            "/tmp/ckb-student").ok, true)
        let sourceDrift = p6PublicDelivery(authorityBytes,
            parsedAuthority.datasetVersion)
        sourceDrift.commit = "latest"
        @Expect(selectCkbAuthorityDeliveryMode(sourceDrift).ok, false)
        let licenseDrift = p6PublicDelivery(authorityBytes,
            parsedAuthority.datasetVersion)
        licenseDrift.licenseEvidenceHash = ""
        @Expect(selectCkbAuthorityDeliveryMode(licenseDrift).ok, false)
        let builderDrift = p6PublicDelivery(authorityBytes,
            parsedAuthority.datasetVersion)
        builderDrift.builderHash = "sha256:invalid"
        @Expect(selectCkbAuthorityDeliveryMode(builderDrift).ok, false)
        let datasetDrift = p6PublicDelivery(authorityBytes,
            parsedAuthority.datasetVersion)
        datasetDrift.datasetVersion = "cangjie-humaneval-164-sha256:wrong"
        @Expect(validateCkbReproAuthorityDelivery(datasetDrift, authorityBytes,
            datasetDrift.datasetVersion, "/tmp/ckb-p6/public",
            "/tmp/ckb-store", "/tmp/ckb-student").ok, false)
    }

    @TestCase
    public func p6Neg01CopiedObservedCannotOverrideActualProbe(): Unit {
        let expected = p6FrozenEnvironment()
        let inputs = CkbReproPreflightCliInputs()
        inputs.expected = expected
        inputs.observed = expected
        inputs.heap = ckbServiceHeapPreflight("4GB")
        let seal = p6CertificationSeal()
        inputs.certificationPreflightJson = seal[0]
        inputs.certificationRunManifestJson = seal[1]
        let options = parseCkbReproPreflightCliArgs([
            "ckb-repro-preflight", "--environment-lock", "/tmp/expected.json",
            "--observed-environment", "/tmp/observed.json",
            "--certification-preflight", "/tmp/preflight.json",
            "--certification-run-manifest", "/tmp/run-manifest.json"])

        let drifted = CkbReproEnvironmentProbeResult()
        drifted.ok = true
        drifted.observed = p6FrozenEnvironment()
        drifted.attestedInputHash = p6Hash(
            renderCkbReproEnvironmentLock(inputs.observed))
        drifted.observed.timeoutSeconds = 3599
        let driftProbe = P6FakeEnvironmentProbe(drifted)
        let blocked = executeCkbReproPreflightCliAdapterWithProbe(
            options, inputs, driftProbe)
        @Expect(blocked.ok, false)
        @Expect(blocked.diagnostic, "environment_identity_drift")
        @Expect(driftProbe.calls, 1)

        let unavailable = CkbReproEnvironmentProbeResult()
        unavailable.diagnostic = "environment_probe_unavailable"
        @Expect(executeCkbReproPreflightCliAdapterWithProbe(options, inputs,
            P6FakeEnvironmentProbe(unavailable)).diagnostic,
            "environment_probe_unavailable")

        let matched = CkbReproEnvironmentProbeResult()
        matched.ok = true
        matched.observed = p6FrozenEnvironment()
        matched.attestedInputHash = p6Hash(
            renderCkbReproEnvironmentLock(inputs.observed))
        @Expect(executeCkbReproPreflightCliAdapterWithProbe(options, inputs,
            P6FakeEnvironmentProbe(matched)).ok, true)

        @Expect(runCkbReproPreflightCliAdapter(options).diagnostic,
            "environment_attestation_authority_unavailable")
        let untrusted = CkbReproAttestationAuthority()
        untrusted.signingFingerprint =
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        untrusted.frozen = false
        @Expect(runCkbReproPreflightCliAdapter(options, untrusted).diagnostic,
            "environment_attestation_authority_unavailable")
    }

    @TestCase
    public func p6Bnd01ActualProbeIsHashBoundBoundedAndUtf8Safe(): Unit {
        let expected = p6FrozenEnvironment()
        let inputs = CkbReproPreflightCliInputs()
        inputs.expected = expected
        inputs.observed = expected
        inputs.heap = ckbServiceHeapPreflight("4GB")
        let seal = p6CertificationSeal()
        inputs.certificationPreflightJson = seal[0]
        inputs.certificationRunManifestJson = seal[1]
        let options = parseCkbReproPreflightCliArgs([
            "ckb-repro-preflight", "--environment-lock", "/tmp/expected.json",
            "--observed-environment", "/tmp/observed.json",
            "--certification-preflight", "/tmp/preflight.json",
            "--certification-run-manifest", "/tmp/run-manifest.json"])

        let unbound = CkbReproEnvironmentProbeResult()
        unbound.ok = true
        unbound.observed = p6FrozenEnvironment()
        unbound.attestedInputHash = p6Hash("different-attestation")
        @Expect(executeCkbReproPreflightCliAdapterWithProbe(options, inputs,
            P6FakeEnvironmentProbe(unbound)).diagnostic,
            "environment_attestation_input_mismatch")

        @Expect(ckbReproSdkExecutableHash("sdk-binary".toArray()),
            p6Hash("sdk-binary"))
        @Expect(ckbReproSdkExecutableHash("sdk-binary-2".toArray()) ==
            ckbReproSdkExecutableHash("sdk-binary".toArray()), false)

        let unicode = ckbReproNormalizeProbeOutput(
            "仓颉🙂\nversion".toArray(), 64)
        @Expect(unicode[0], "ok")
        @Expect(unicode[1], "仓颉🙂 version")
        @Expect(ckbReproNormalizeProbeOutput([0xff, 0xfe], 64)[0],
            "environment_probe_invalid_encoding")
        @Expect(ckbReproNormalizeProbeOutput("ok\u{0001}bad".toArray(), 64)[0],
            "environment_probe_control_character")
        @Expect(ckbReproNormalizeProbeOutput(
            "/Users/private/repository".toArray(), 64)[0],
            "environment_probe_path_leak")
        for (path in ["/mnt", "/Volumes/private", "/data/release", "/etc"]) {
            @Expect(ckbReproNormalizeProbeOutput(path.toArray(), 64)[0],
                "environment_probe_path_leak")
        }
        for (safe in ["https://provider.example/v1/models", "/v2/models",
            "/knowledge/search", "/guide/install"]) {
            @Expect(ckbReproNormalizeProbeOutput(safe.toArray(), 128)[0],
                "ok")
        }
        let long = ArrayList<UInt8>()
        for (_ in 0..4096) { long.add(all: "🙂".toArray()) }
        @Expect(ckbReproNormalizeProbeOutput(long.toArray(), 256)[0],
            "environment_probe_output_too_large")

        let concurrent = ckbReproBoundedProbeCommand("/bin/sh", ["-c",
            "i=0; while [ $i -lt 12000 ]; do printf x; printf y >&2; i=$((i+1)); done"],
            8192)
        @Expect(concurrent[0], Int64(0))
        @Expect(concurrent[1], "environment_probe_output_too_large")

        let production = CkbReproFilesystemEnvironmentProbe().inspect(
            expected, p6Hash(renderCkbReproEnvironmentLock(expected)))
        @Expect(production.ok, false)
        @Expect(production.diagnostic, "environment_probe_unavailable")
        @Expect(production.observed.glmProvider, "")
    }

    @TestCase
    public func p6Reg01MirrorsConfigsManifestAndCriticalContractStayStable(): Unit {
        @Expect(p6MirrorEquivalent("../src/ckb_repro_environment.cj",
            "src/ckb_repro_environment.cj"), true)
        @Expect(p6MirrorEquivalent("../src/ckb_repro_authority_bundle.cj",
            "src/ckb_repro_authority_bundle.cj"), true)
        let manifest = parseCangjieHumanEvalAuthorityManifest(String.fromUtf8(
            p6SyntheticAuthorityBytes()))
        @Expect(manifest.ok, true)
        @Expect(manifest.rows.size, 164)
        let critical = parseCkbRunCriticalFilesManifest(
            p6Read("../reproducibility/manifests/run-critical-files.json"))
        @Expect(critical[0].ok, true)
        @Expect(validateCkbRunCriticalFilesManifest(critical[1], "..",
            mode: "contract").ok, true)
        for (path in [
            "../reproducibility/manifests/environment-lock.json",
            "../reproducibility/manifests/authority-delivery.json",
            "../reproducibility/manifests/authority-source-materials.json",
            "../reproducibility/configs/provider.example.env",
            "../reproducibility/configs/ckb.example.conf",
            "../reproducibility/configs/claude-mcp.example.json",
            "../reproducibility/configs/experiment-profile.json"
        ]) {
            let text = String.fromUtf8(p6Read(path)).toAsciiLower()
            @Expect(text.contains("/users/"), false)
            @Expect(text.contains("authorization"), false)
            @Expect(text.contains("bearer "), false)
            @Expect(text.contains("password="), false)
        }
    }
}

private func p6FrozenEnvironment(): CkbReproEnvironmentLock {
    let lock = CkbReproEnvironmentLock()
    lock.schemaVersion = "ckb-repro-environment-v1"
    lock.identityStatus = "frozen"
    lock.certifiedPlatform = "macOS"
    lock.cpuArchitecture = "arm64"
    lock.cangjieSdkVersion = "1.0.0"
    lock.cangjieSdkHash = p6Hash("sdk")
    lock.opensslVersion = "3"
    lock.serviceHeap = "4GB"
    lock.qdrantImageDigest = p6Hash("qdrant")
    lock.runCandidateCommit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    lock.runCriticalFilesManifestHash = p6Hash("critical-manifest")
    lock.runCriticalTreeHash = p6Hash("critical-tree")
    lock.claudeCodeVersion = "test-version"
    lock.glmProvider = "openai-compatible"
    lock.glmBaseUrl = "https://provider.example/v1"
    lock.glmModel = "GLM-5.2"
    lock.glmCredentialEnv = "GLM_API_KEY"
    lock.embeddingProvider = "ollama"
    lock.embeddingModel = "bge-m3:latest"
    lock.embeddingDimension = 1024
    lock.embeddingCredentialEnv = "CKB_EMBEDDING_TOKEN"
    lock.archiveTool = "tar+zstd"
    lock.archiveToolVersion = "test-version"
    lock.experimentGroup = CkbAbcdeGroups.D
    lock.ckbRequired = true
    lock.localDocsPolicy = "disabled"
    lock.modelEffort = "max"
    lock.modelBudget = "unbounded"
    lock.timeoutSeconds = 3600
    lock.transportRetryBudget = 10
    lock.promptHash = p6Hash("prompt")
    lock.mcpCommand = "ckb mcp-http"
    lock.mcpTransport = "mcp_http"
    lock.sandboxCapability = "macos-sandbox-exec"
    lock.datasetVersion =
        "cangjie-humaneval-164-sha256:3a12d5a5283daa492dd489c1a97ebc457b71e72d90669fbc965e165566386b33"
    lock.authorityDeliveryHash = p6Hash("authority-delivery")
    lock
}

private func p6BundledDelivery(authority: Array<UInt8>,
    datasetVersion: String): CkbAuthorityDeliveryManifest {
    let manifest = CkbAuthorityDeliveryManifest()
    manifest.schemaVersion = "ckb-authority-delivery-v1"
    manifest.mode = "bundled"
    manifest.licenseId = "fixture-permissive"
    manifest.licenseEvidenceHash = p6Hash("fixture-license")
    manifest.redistributionAllowed = true
    manifest.bundleHash = p6Hash("fixture-bundle")
    manifest.authorityHash = p6Hash(String.fromUtf8(authority))
    manifest.datasetVersion = datasetVersion
    manifest
}

private func p6PublicDelivery(authority: Array<UInt8>,
    datasetVersion: String): CkbAuthorityDeliveryManifest {
    let manifest = CkbAuthorityDeliveryManifest()
    manifest.schemaVersion = "ckb-authority-delivery-v1"
    manifest.mode = "public_rebuild"
    manifest.licenseId = "fixture-public-build"
    manifest.licenseEvidenceHash = p6Hash("fixture-license")
    manifest.anonymousPublicAccess = true
    manifest.repository = "https://example.test/public-authority"
    manifest.commit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    manifest.tree = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    manifest.path = "dataset"
    let fileHash = p6Hash("fixture-file")
    manifest.fileHashes.add("dataset/fixture.txt|${fileHash}")
    manifest.builderHash = p6Hash("fixture-builder")
    manifest.sourceMaterialsHash = p6Hash("fixture-source-materials")
    manifest.authorityHash = p6Hash(String.fromUtf8(authority))
    manifest.datasetVersion = datasetVersion
    manifest
}

private func p6RunnerInputs(): CkbReproRunnerInputs {
    let inputs = CkbReproRunnerInputs()
    inputs.runId = "p6-fixture"
    inputs.repoRoot = "target/repository"
    inputs.runsRoot = "target/runs"
    inputs.datasetRoot = "target/authority"
    inputs.authorityManifestPath = "target/authority/manifest.jsonl"
    inputs.ckbBin = "target/bin/ckb"
    inputs.ckbConfig = "target/config/ckb.conf"
    inputs.ckbStore = "target/store"
    inputs.ckbHttpBase = "http://127.0.0.1:18890"
    inputs.claudeBin = "target/bin/claude"
    inputs.docsRoot = "target/docs"
    inputs.candidateVersion = "portable-candidate-v1"
    inputs.knowledgeVersion = "portable-knowledge-v1"
    inputs.providerIdentityHash = p6Hash("provider")
    inputs.providerIdentityArtifactPath = "target/provider.json"
    inputs.frozenCandidateManifestPath = "target/candidate.json"
    inputs.certificationPreflightPath = "target/preflight.json"
    inputs.certificationRunManifestPath = "target/run-manifest.json"
    inputs
}

private func p6CertificationSeal(): (String, String) {
    let fingerprint = p6Hash("fingerprint")
    let candidate = p6Hash("candidate")
    let leakage = p6Hash("leakage")
    let frozen = p6Hash("frozen")
    let binary = p6Hash("binary")
    let launch = p6Hash("launch")
    let command = p6Hash("command")
    let provider = p6Hash("provider")
    let preflight =
        "{\"ok\":true,\"startAllowed\":true,\"diagnostic\":\"ok\"," +
        "\"fingerprint\":\"${fingerprint}\"," +
        "\"candidateChecksum\":\"${candidate}\"," +
        "\"studentLeakageProofHash\":\"${leakage}\"," +
        "\"frozenCandidateManifestHash\":\"${frozen}\"," +
        "\"certificationBinaryHash\":\"${binary}\"," +
        "\"certificationHttpLaunchSpecHash\":\"${launch}\"," +
        "\"certificationHttpCommandHash\":\"${command}\"," +
        "\"transportRetryBudget\":10,\"modelTimeoutSeconds\":3600," +
        "\"certificationPassAt1\":null,\"violations\":[]}"
    let preflightHash = p6Hash(preflight)
    let runId = "p6-sealed-fixture"
    let model = "GLM-5.2"
    let claude = "test-version"
    let transport = CkbAbcdeGroups.D
    let runManifestHash = p6Hash(
        p6SealPart(runId) + p6SealPart(preflightHash) +
        p6SealPart(fingerprint) + p6SealPart(provider) +
        p6SealPart(model) + p6SealPart(claude) +
        p6SealPart(transport) + p6SealPart("10") +
        p6SealPart("3600") + p6SealPart(candidate) +
        p6SealPart(leakage) + p6SealPart(frozen) +
        p6SealPart(binary) + p6SealPart(launch) + p6SealPart(command))
    let manifest =
        "{\"runId\":\"${runId}\",\"startAllowed\":true," +
        "\"fingerprint\":\"${fingerprint}\"," +
        "\"providerIdentityHash\":\"${provider}\"," +
        "\"modelVersion\":\"${model}\"," +
        "\"claudeCodeVersion\":\"${claude}\"," +
        "\"certificationTransport\":\"${transport}\"," +
        "\"transportRetryBudget\":10,\"modelTimeoutSeconds\":3600," +
        "\"candidateChecksum\":\"${candidate}\"," +
        "\"studentLeakageProofHash\":\"${leakage}\"," +
        "\"frozenCandidateManifestHash\":\"${frozen}\"," +
        "\"certificationBinaryHash\":\"${binary}\"," +
        "\"certificationHttpLaunchSpecHash\":\"${launch}\"," +
        "\"certificationHttpCommandHash\":\"${command}\"," +
        "\"preflightHash\":\"${preflightHash}\"," +
        "\"runManifestHash\":\"${runManifestHash}\"," +
        "\"certificationPassAt1\":null}"
    (preflight, manifest)
}

private func p6SealPart(value: String): String {
    "${value.toArray().size}:${value}"
}

private func p6Hash(value: String): String {
    benchmarkGapSha256(value)
}

private func p6SyntheticAuthorityBytes(): Array<UInt8> {
    let root = Path("target/p6-synthetic-authority")
    if (!exists(root)) {
        for (i in 0..164) {
            let caseRoot = root.join(p6CaseId(i))
            Directory.create(caseRoot.join("starter"), recursive: true)
            Directory.create(caseRoot.join("tests"), recursive: true)
            Directory.create(caseRoot.join("translation"), recursive: true)
            File.writeTo(caseRoot.join("prompt.md"),
                "Implement fixture_${i}; no benchmark case content.\n".toArray())
            File.writeTo(caseRoot.join("metadata.json"),
                "{\"targetVersion\":\"1.0.0\",\"signature\":\"public func fixture_${i}(): Int64\"}".toArray())
            File.writeTo(caseRoot.join("starter/solution.cj"),
                "package fixture\npublic func fixture_${i}(): Int64 { 0 }\n".toArray())
            File.writeTo(caseRoot.join("tests/TestMain.cj"),
                "package fixture_test\n// synthetic verifier fixture ${i}\n".toArray())
            File.writeTo(caseRoot.join("translation/source.txt"),
                "synthetic-${i}\n".toArray())
        }
    }
    let manifest = buildCangjieHumanEvalManifest(root.toString(), "")
    if (!manifest.ok) { return Array<UInt8>() }
    cangjieHumanEvalRenderAuthorityManifest(manifest).toArray()
}

private func p6CaseId(index: Int64): String {
    if (index < 10) { return "CJ-HUMANEVAL-00${index}" }
    if (index < 100) { return "CJ-HUMANEVAL-0${index}" }
    "CJ-HUMANEVAL-${index}"
}

private func p6Read(path: String): Array<UInt8> {
    File.readFrom(Path(path))
}

private func p6MirrorEquivalent(sourcePath: String, mirrorPath: String): Bool {
    let source = try { String.fromUtf8(p6Read(sourcePath)) }
        catch (_: Exception) { return false }
    let mirror = try { String.fromUtf8(p6Read(mirrorPath)) }
        catch (_: Exception) { return false }
    mirror.replace("package cangjie_community_knowledge_base_test",
        "package cangjie_community_knowledge_base") == source
}
