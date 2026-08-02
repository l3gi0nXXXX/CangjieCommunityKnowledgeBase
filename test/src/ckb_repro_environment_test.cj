package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
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
        attestedInputHash: String, evidenceRepositoryRoot: String):
        CkbReproEnvironmentProbeResult {
        this.calls += 1
        this.result
    }
}

private class P6FakeGitProbeRunner <: CkbReproGitProbeRunner {
    public var command: String = ""
    public var args: Array<String> = Array<String>()
    public func run(value: String, arguments: Array<String>): (Int64, String) {
        this.command = value
        this.args = arguments
        (0, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    }
}

private class P6FakeGitEvidenceRunner <: CkbReproGitProbeRunner {
    public var dirty: Bool = false
    public var ancestor: Bool = true
    public var commitExists: Bool = true
    public var head: String = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    public var changedPaths: String =
        "reproducibility/manifests/environment-lock.json " +
        "reproducibility/manifests/environment-attestation-authority.json"
    public let calls = ArrayList<String>()
    public func run(command: String, args: Array<String>): (Int64, String) {
        var joined = ""
        for (arg in args) {
            if (joined != "") { joined += " " }
            joined += arg
        }
        this.calls.add(joined)
        if (joined.contains("cat-file")) {
            return (if (this.commitExists) { 0 } else { 1 }, "")
        }
        if (joined.contains("status")) {
            return (0, if (this.dirty) { " M src/main.cj" } else { "" })
        }
        if (joined.contains("merge-base")) {
            return (if (this.ancestor) { 0 } else { 1 }, "")
        }
        if (joined.contains("diff") && joined.contains("--quiet")) {
            if (joined.contains(":(exclude)")) {
                return (if (this.changedPaths.contains("src/main.cj")) {
                    1
                } else { 0 }, "")
            }
            if (joined.contains(
                "reproducibility/manifests/environment-lock.json")) {
                return (if (this.changedPaths.contains(
                    "reproducibility/manifests/environment-lock.json")) {
                    1
                } else { 0 }, "")
            }
            if (joined.contains(
                "reproducibility/manifests/environment-attestation-authority.json")) {
                return (if (this.changedPaths.contains(
                    "reproducibility/manifests/environment-attestation-authority.json")) {
                    1
                } else { 0 }, "")
            }
        }
        if (joined.contains("rev-parse")) { return (0, this.head) }
        (1, "")
    }
}

private class P6RealGitEvidenceRunner <: CkbReproGitProbeRunner {
    public func run(command: String, args: Array<String>): (Int64, String) {
        let result = ckbReproBoundedProbeCommand(command, args, 1024 * 1024)
        (if (result[1] == "ok") { result[0] } else { 127 }, result[2])
    }
}

private class P6FakeSignatureVerifier <:
    CkbReproAttestationSignatureVerifier {
    public var result: CkbReproAttestationSignatureResult
    public var calls: Int64 = 0
    public init(fingerprint: String) {
        this.result = CkbReproAttestationSignatureResult()
        this.result.ok = true; this.result.diagnostic = "ok"
        this.result.signingFingerprint = fingerprint
    }
    public func verify(path: String): CkbReproAttestationSignatureResult {
        this.calls += 1; this.result
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
        @Expect(environment[1].attestationAuthorityManifestPath,
            "reproducibility/manifests/environment-attestation-authority.json")
        @Expect(environment[1].attestationAuthorityHash, "")
        @Expect(environment[1].compositionManifestPath,
            "reproducibility/manifests/runtime-composition.json")
        @Expect(environment[1].compositionManifestHash, "")
        @Expect(validateCkbReproEnvironmentLock(environment[1],
            mode: "execution").diagnostic, "environment_identity_not_frozen")
        let plannedLockPath = canonicalize(Path(
            "../reproducibility/manifests/environment-lock.json")).toString()
        @Expect(loadCkbReproPreflightAuthority(plannedLockPath)[0].diagnostic,
            "environment_identity_not_frozen")
        @Expect(exists(Path(
            "../reproducibility/manifests/environment-attestation-authority.json")),
            true)
        @Expect(exists(Path(
            "../reproducibility/environment-attestation-authority.schema.json")),
            true)
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

        let explicit = p6ExplicitCliArgs()
        let withJson = ArrayList<String>()
        withJson.add(all: explicit); withJson.add("--json")
        @Expect(parseCkbReproPreflightCliArgs(withJson.toArray()).valid, true)
        @Expect(parseCkbReproPreflightCliArgs(explicit).signingFingerprint,
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
        withJson.add("--json")
        @Expect(parseCkbReproPreflightCliArgs(withJson.toArray()).diagnostic,
            "duplicate_argument:--json")
        @Expect(parseCkbReproPreflightCliArgs([
            "ckb-repro-preflight", "--environment-lock", "/tmp/expected.json",
            "--observed-environment", "/tmp/observed.json",
            "--certification-preflight", "/tmp/preflight.json",
            "--certification-run-manifest", "/tmp/run-manifest.json"
        ]).diagnostic, "required_argument_missing")
        @Expect(parseCkbReproPreflightCliArgs([
            "ckb-repro-preflight", "--token", "secret"]).diagnostic,
            "unknown_argument:--token")
        for (forbidden in ["--attestation-authority-path",
            "--attestation-authority-hash", "--observed-environment-hash"]) {
            @Expect(parseCkbReproPreflightCliArgs([
                "ckb-repro-preflight", forbidden, "untrusted"]).diagnostic,
                "unknown_argument:${forbidden}")
        }
        let invalidAuthority = parseCkbReproPreflightCliArgs(p6ExplicitCliArgs())
        invalidAuthority.signingFingerprint = "not-a-fingerprint"
        @Expect(validateCkbReproPreflightCliOptions(invalidAuthority).diagnostic,
            "environment_attestation_authority_invalid")
        invalidAuthority.signingFingerprint =
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        invalidAuthority.observedEnvironmentProjectionHash = "sha256:invalid"
        @Expect(validateCkbReproPreflightCliOptions(invalidAuthority).diagnostic,
            "environment_attestation_authority_invalid")
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
            parseCkbReproPreflightCliArgs(p6ExplicitCliArgs()),
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
        let options = parseCkbReproPreflightCliArgs(p6ExplicitCliArgs())

        let drifted = CkbReproEnvironmentProbeResult()
        drifted.ok = true
        drifted.observed = p6FrozenEnvironment()
        drifted.attestedInputHash =
            ckbReproObservedEnvironmentProjectionHash(inputs.observed)
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
        matched.attestedInputHash =
            ckbReproObservedEnvironmentProjectionHash(inputs.observed)
        matched.attestationEvidenceCommit =
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        let matchedResult = executeCkbReproPreflightCliAdapterWithProbe(
            options, inputs, P6FakeEnvironmentProbe(matched))
        @Expect(matchedResult.ok, true)
        @Expect(matchedResult.attestationEvidenceCommit,
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")

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
    public func p6Neg02AttestationAuthorityRequiresIndependentAnchor(): Unit {
        let first = p6AuthorityManifest(
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            "sha256:${"a" * 64}")
        let second = p6AuthorityManifest(
            "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
            "sha256:${"b" * 64}")
        let firstLoaded = loadCkbReproVerifiedAttestationAuthority(
            first.toArray(), p6Hash(first))
        let secondLoaded = loadCkbReproVerifiedAttestationAuthority(
            second.toArray(), p6Hash(second))
        @Expect(firstLoaded[0].ok, true)
        @Expect(secondLoaded[0].ok, true)
        let options = parseCkbReproPreflightCliArgs(p6ExplicitCliArgs())
        @Expect(runCkbReproPreflightCliAdapter(
            options, secondLoaded[1]).diagnostic,
            "environment_attestation_authority_mismatch")

        @Expect(loadCkbReproVerifiedAttestationAuthority(
            first.toArray(), p6Hash(second))[0].diagnostic,
            "environment_attestation_authority_anchor_mismatch")
        @Expect(loadCkbReproVerifiedAttestationAuthority(
            first.replace("\"status\":\"frozen\"",
                "\"status\":\"planned\"").toArray(), p6Hash(first))[0].ok,
            false)
        @Expect(loadCkbReproVerifiedAttestationAuthority(
            first.replace("}", ",\"extra\":true}").toArray(),
            p6Hash(first))[0].ok, false)
        @Expect(loadCkbReproVerifiedAttestationAuthority(
            [0xff, 0xfe], p6Hash(first))[0].diagnostic,
            "invalid_response_encoding")
        @Expect(loadCkbReproVerifiedAttestationAuthority(
            "{bad".toArray(), p6Hash(first))[0].diagnostic,
            "environment_attestation_authority_malformed")

        let root = Path("target/p6-independent-authority")
        if (exists(root)) { remove(root, recursive: true) }
        Directory.create(root, recursive: true)
        let canonical = canonicalize(root).toString()
        let observed = p6FrozenEnvironment()
        let observedText = renderCkbReproEnvironmentLock(observed)
        let observedHash = ckbReproObservedEnvironmentProjectionHash(observed)
        let anchoredText = p6AuthorityManifest(
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", observedHash)
        let anchored = loadCkbReproVerifiedAttestationAuthority(
            anchoredText.toArray(), p6Hash(anchoredText))
        @Expect(anchored[0].ok, true)
        File.writeTo(Path(canonical).join("expected.json"),
            observedText.toArray())
        File.writeTo(Path(canonical).join("observed.json"),
            observedText.toArray())
        let seal = p6CertificationSeal()
        File.writeTo(Path(canonical).join("preflight.json"), seal[0].toArray())
        File.writeTo(Path(canonical).join("run-manifest.json"),
            seal[1].toArray())
        let bounded = parseCkbReproPreflightCliArgs([
            "ckb-repro-preflight", "--environment-lock",
            "${canonical}/expected.json", "--observed-environment",
            "${canonical}/observed.json", "--certification-preflight",
            "${canonical}/preflight.json", "--certification-run-manifest",
            "${canonical}/run-manifest.json", "--signing-fingerprint",
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            "--observed-environment-projection-hash", observedHash])
        let wrongKey = P6FakeSignatureVerifier(
            "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB")
        let probeResult = CkbReproEnvironmentProbeResult()
        probeResult.diagnostic = "must_not_run"
        let probe = P6FakeEnvironmentProbe(probeResult)
        @Expect(runCkbReproPreflightCliAdapterWithAuthorityDependencies(
            bounded, anchored[1], wrongKey, probe).diagnostic,
            "environment_attestation_signature_invalid")
        @Expect(wrongKey.calls, 1)
        @Expect(probe.calls, 0)

        let repo = Path(canonical).join("repo")
        let manifests = repo.join("reproducibility/manifests")
        Directory.create(manifests, recursive: true)
        let repoCanonical = canonicalize(repo).toString()
        let frozen = p6FrozenEnvironment()
        let projection = ckbReproObservedEnvironmentProjectionHash(frozen)
        let frozenAuthority = p6AuthorityManifest(
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", projection)
        frozen.attestationAuthorityHash = p6Hash(frozenAuthority)
        let lockPath = Path(repoCanonical).join(
            "reproducibility/manifests/environment-lock.json")
        let authorityPath = Path(repoCanonical).join(
            frozen.attestationAuthorityManifestPath)
        File.writeTo(lockPath,
            renderCkbReproEnvironmentLock(frozen).toArray())
        File.writeTo(authorityPath, frozenAuthority.toArray())
        @Expect(loadCkbReproPreflightAuthority(lockPath.toString())[0].ok,
            true)

        let fullLockHash = p6Hash(renderCkbReproEnvironmentLock(frozen))
        let circularAuthority = p6AuthorityManifest(
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", fullLockHash)
        frozen.attestationAuthorityHash = p6Hash(circularAuthority)
        File.writeTo(lockPath,
            renderCkbReproEnvironmentLock(frozen).toArray())
        File.writeTo(authorityPath, circularAuthority.toArray())
        @Expect(loadCkbReproPreflightAuthority(lockPath.toString())[0].diagnostic,
            "environment_attestation_input_mismatch")

        frozen.attestationAuthorityHash = p6Hash(frozenAuthority)
        File.writeTo(lockPath,
            renderCkbReproEnvironmentLock(frozen).toArray())
        let driftedAuthority = frozenAuthority.replace(
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB")
        File.writeTo(authorityPath, driftedAuthority.toArray())
        @Expect(loadCkbReproPreflightAuthority(lockPath.toString())[0].diagnostic,
            "environment_attestation_authority_anchor_mismatch")

        frozen.attestationAuthorityManifestPath =
            "reproducibility/manifests/other-authority.json"
        File.writeTo(lockPath,
            renderCkbReproEnvironmentLock(frozen).toArray())
        @Expect(loadCkbReproPreflightAuthority(lockPath.toString())[0].diagnostic,
            "environment_attestation_authority_invalid")
        remove(root, recursive: true)
    }

    @TestCase
    public func p6Neg03ProjectionExcludesOnlyAuthorityHash(): Unit {
        let base = p6FrozenEnvironment()
        let baseProjection = ckbReproObservedEnvironmentProjectionHash(base)
        let baseFull = validateCkbReproEnvironmentLock(base,
            mode: "execution")

        let authorityHashDrift = p6FrozenEnvironment()
        authorityHashDrift.attestationAuthorityHash = p6Hash("other-authority")
        let authorityFull = validateCkbReproEnvironmentLock(
            authorityHashDrift, mode: "execution")
        @Expect(ckbReproObservedEnvironmentProjectionHash(authorityHashDrift),
            baseProjection)
        @Expect(authorityFull.manifestHash == baseFull.manifestHash, false)
        @Expect(authorityFull.treeHash == baseFull.treeHash, false)

        let commitDrift = p6FrozenEnvironment()
        commitDrift.runCandidateCommit =
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        let commitFull = validateCkbReproEnvironmentLock(commitDrift,
            mode: "execution")
        @Expect(ckbReproObservedEnvironmentProjectionHash(commitDrift) ==
            baseProjection, false)
        @Expect(commitFull.manifestHash == baseFull.manifestHash, false)
        @Expect(commitFull.treeHash, baseFull.treeHash)

        let timeoutDrift = p6FrozenEnvironment()
        timeoutDrift.timeoutSeconds = 3599
        @Expect(ckbReproObservedEnvironmentProjectionHash(timeoutDrift) ==
            baseProjection, false)
        let providerDrift = p6FrozenEnvironment()
        providerDrift.glmProvider = "different-provider"
        @Expect(ckbReproObservedEnvironmentProjectionHash(providerDrift) ==
            baseProjection, false)
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
        let options = parseCkbReproPreflightCliArgs(p6ExplicitCliArgs())

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
            expected, ckbReproObservedEnvironmentProjectionHash(expected),
            "")
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

    @TestCase
    public func p6Reg02GitCommitProbeIsBoundToCanonicalRepositoryRoot(): Unit {
        let root = Path("target/p6-git-probe/repository")
        if (exists(root.parent)) { remove(root.parent, recursive: true) }
        Directory.create(root, recursive: true)
        let canonicalRoot = canonicalize(root).toString()
        let runner = P6FakeGitProbeRunner()
        let result = ckbReproProbeGitCommit(canonicalRoot, runner)
        @Expect(result[0], Int64(0))
        @Expect(result[1], "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        @Expect(runner.command, "git")
        @Expect(runner.args,
            ["-C", canonicalRoot, "rev-parse", "HEAD"])
        for (invalid in ["", root.toString(), canonicalRoot + "/missing"]) {
            let blocked = P6FakeGitProbeRunner()
            @Expect(ckbReproProbeGitCommit(invalid, blocked)[0], Int64(127))
            @Expect(blocked.command, "")
        }
        remove(root.parent, recursive: true)
    }

    @TestCase
    public func p6Reg03RunCandidateAndEvidenceCommitsDoNotSelfReference(): Unit {
        let root = Path("target/p6-evidence-commit/repository")
        if (exists(root.parent)) { remove(root.parent, recursive: true) }
        Directory.create(root, recursive: true)
        let canonicalRoot = canonicalize(root).toString()
        let manifests = Path(canonicalRoot).join(
            "reproducibility/manifests")
        Directory.create(manifests, recursive: true)
        let lockPath = manifests.join("environment-lock.json")
        let authorityPath = manifests.join(
            "environment-attestation-authority.json")
        File.writeTo(lockPath, "lock".toArray())
        File.writeTo(authorityPath, "authority".toArray())
        let candidate = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        let valid = P6FakeGitEvidenceRunner()
        let accepted = ckbReproValidateEvidenceCommit(
            canonicalRoot, candidate, valid)
        @Expect(accepted[0], "ok")
        @Expect(accepted[1],
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")

        let dirty = P6FakeGitEvidenceRunner(); dirty.dirty = true
        @Expect(ckbReproValidateEvidenceCommit(
            canonicalRoot, candidate, dirty)[0], "git_worktree_dirty")
        let unrelated = P6FakeGitEvidenceRunner()
        unrelated.changedPaths =
            "reproducibility/manifests/environment-lock.json " +
            "reproducibility/manifests/environment-attestation-authority.json " +
            "src/main.cj"
        @Expect(ckbReproValidateEvidenceCommit(
            canonicalRoot, candidate, unrelated)[0],
            "git_evidence_commit_scope_invalid")
        let incomplete = P6FakeGitEvidenceRunner()
        incomplete.changedPaths =
            "reproducibility/manifests/environment-lock.json"
        @Expect(ckbReproValidateEvidenceCommit(
            canonicalRoot, candidate, incomplete)[0],
            "git_evidence_commit_incomplete")
        remove(authorityPath)
        @Expect(ckbReproValidateEvidenceCommit(
            canonicalRoot, candidate, valid)[0],
            "git_evidence_commit_incomplete")
        File.writeTo(authorityPath, "authority".toArray())
        let missing = P6FakeGitEvidenceRunner(); missing.commitExists = false
        @Expect(ckbReproValidateEvidenceCommit(
            canonicalRoot, candidate, missing)[0],
            "git_run_candidate_missing")
        let candidateCheckout = P6FakeGitEvidenceRunner()
        candidateCheckout.head = candidate
        @Expect(ckbReproValidateCandidateCheckout(
            canonicalRoot, candidate, candidateCheckout)[0], "ok")
        candidateCheckout.head =
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        @Expect(ckbReproValidateCandidateCheckout(
            canonicalRoot, candidate, candidateCheckout)[0],
            "git_candidate_checkout_mismatch")
        remove(root.parent, recursive: true)
    }

    @TestCase
    public func p6Reg04RealGitEvidenceCommitTopologyIsExact(): Unit {
        let root = Path("target/p6-real-git/repository")
        if (exists(root.parent)) { remove(root.parent, recursive: true) }
        Directory.create(root.join("src"), recursive: true)
        let manifests = root.join("reproducibility/manifests")
        Directory.create(manifests, recursive: true)
        File.writeTo(root.join("src/main.cj"), "main A".toArray())
        File.writeTo(manifests.join("environment-lock.json"),
            "planned lock".toArray())
        File.writeTo(manifests.join(
            "environment-attestation-authority.json"),
            "planned authority".toArray())
        let canonical = canonicalize(root).toString()
        let runner = P6RealGitEvidenceRunner()
        @Expect(runner.run("git", ["init", "--quiet", canonical])[0],
            Int64(0))
        @Expect(runner.run("git", ["-C", canonical, "add", "."])[0],
            Int64(0))
        @Expect(runner.run("git", ["-C", canonical, "-c",
            "user.name=CKB Test", "-c", "user.email=ckb@example.invalid",
            "commit", "--quiet", "-m", "candidate A"])[0], Int64(0))
        let candidate = runner.run("git", ["-C", canonical,
            "rev-parse", "HEAD"])[1]

        File.writeTo(manifests.join("environment-lock.json"),
            "frozen lock".toArray())
        File.writeTo(manifests.join(
            "environment-attestation-authority.json"),
            "frozen authority".toArray())
        @Expect(runner.run("git", ["-C", canonical, "add", "."])[0],
            Int64(0))
        @Expect(runner.run("git", ["-C", canonical, "-c",
            "user.name=CKB Test", "-c", "user.email=ckb@example.invalid",
            "commit", "--quiet", "-m", "evidence B"])[0], Int64(0))
        let evidence = runner.run("git", ["-C", canonical,
            "rev-parse", "HEAD"])[1]
        let accepted = ckbReproValidateEvidenceCommit(
            canonical, candidate, runner)
        @Expect(accepted[0], "ok")
        @Expect(accepted[1], evidence)

        remove(root.join("src/main.cj"))
        @Expect(runner.run("git", ["-C", canonical, "add", "-A"])[0],
            Int64(0))
        @Expect(runner.run("git", ["-C", canonical, "-c",
            "user.name=CKB Test", "-c", "user.email=ckb@example.invalid",
            "commit", "--quiet", "-m", "forbidden C"])[0], Int64(0))
        @Expect(ckbReproValidateEvidenceCommit(
            canonical, candidate, runner)[0],
            "git_evidence_commit_scope_invalid")
        remove(root.parent, recursive: true)
    }
}

public func p6FrozenEnvironment(): CkbReproEnvironmentLock {
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
    lock.compositionManifestPath =
        "reproducibility/manifests/runtime-composition.json"
    lock.compositionManifestHash = p6Hash("composition-manifest")
    lock.claudeCodeVersion = "test-version"
    lock.glmProvider = "openai-compatible"
    lock.glmBaseUrl = "https://provider.example/v1"
    lock.glmModel = "GLM-5.2"
    lock.modelFingerprint = "claude-code-glm-5.2"
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
    lock.attestationAuthorityManifestPath =
        "reproducibility/manifests/environment-attestation-authority.json"
    lock.attestationAuthorityHash = p6Hash("attestation-authority")
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

public func p6RunnerInputs(): CkbReproRunnerInputs {
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

private func p6ExplicitCliArgs(): Array<String> {
    ["ckb-repro-preflight", "--environment-lock",
        "/tmp/reproducibility/manifests/environment-lock.json",
        "--observed-environment", "/tmp/observed.json",
        "--certification-preflight", "/tmp/preflight.json",
        "--certification-run-manifest", "/tmp/run-manifest.json",
        "--signing-fingerprint", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "--observed-environment-projection-hash", "sha256:${"a" * 64}"]
}

private func p6AuthorityManifest(fingerprint: String,
    observedHash: String): String {
    let source = "release://ckb/environment-attestation-authority-v1"
    "{\"schemaVersion\":\"ckb-repro-environment-attestation-authority-v1\"," +
        "\"status\":\"frozen\",\"signingFingerprint\":\"${fingerprint}\"," +
        "\"observedEnvironmentProjectionHash\":\"${observedHash}\"," +
        "\"authoritySource\":\"${source}\"," +
        "\"authoritySourceHash\":\"${p6Hash(source)}\"}"
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
