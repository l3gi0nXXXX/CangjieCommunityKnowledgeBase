package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove, rename}
import std.process.launch
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.json.JsonValue

private class P6FakeRunner <: CkbReproRunnerInvoker {
    public var count: Int64 = 0
    public var args: Array<String> = Array<String>()
    public var history: ArrayList<Array<String>> = ArrayList<Array<String>>()
    public var failAtCall: Int64 = 0
    public var evaluatedSeal: String = ""
    public var generationSeal: String =
        "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    public init() {}
    private func record(value: Array<String>): Int64 {
        this.count += 1
        this.args = value
        this.history.add(value)
        if (this.failAtCall == this.count) { 1 } else { 0 }
    }
    public func generate(value: Array<String>, runRoot: String):
        (Int64, String) {
        let code = this.record(value)
        (code, if (code == 0) { this.generationSeal } else { "" })
    }
    public func evaluate(value: Array<String>, runRoot: String,
        expectedGenerationSeal: String): Int64 {
        this.evaluatedSeal = expectedGenerationSeal
        this.record(value)
    }
}

private class P6PartialAuthorityArchiveBackend <: CkbReleaseArchiveBackend {
    private let delegate = CkbPortableReleaseArchiveBackend()
    public func create(path: String,
        values: ArrayList<CkbReleaseArchivePayload>): CkbReleaseArchiveOperation {
        File.writeTo(Path(path), "partial archive 中文🙂".toArray())
        CkbReleaseArchiveOperation()
    }
    public func enumerate(path: String): CkbReleaseArchiveListing {
        this.delegate.enumerate(path)
    }
    public func readRegular(path: String, relative: String):
        CkbReleaseArchiveRead {
        this.delegate.readRegular(path, relative)
    }
    public func supportsStreaming(): Bool { this.delegate.supportsStreaming() }
    public func createFromFiles(path: String,
        values: ArrayList<CkbReleaseArchivePayload>): CkbReleaseArchiveOperation {
        this.delegate.createFromFiles(path, values)
    }
    public func extractRegularToFile(path: String, relative: String,
        output: String, size: Int64, hash: String): CkbReleaseArchiveOperation {
        this.delegate.extractRegularToFile(path, relative, output, size, hash)
    }
    public func extractAllRegularToDirectory(path: String, output: String,
        manifest: CkbLogicalSnapshotManifest): CkbReleaseArchiveOperation {
        this.delegate.extractAllRegularToDirectory(path, output, manifest)
    }
    public func archiveHash(path: String): String {
        this.delegate.archiveHash(path)
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
        @Expect(String.fromUtf8(p6Read(
            "../reproducibility/manifests/run-critical-files.json")).contains(
            "src/ckb_repro_authority_bundle.cj"), true)
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
        let bundle = p6AuthorityBundleFixture(authorityBytes,
            authority.datasetVersion, "positive")
        let bundled = bundle.manifest
        let publicRebuild = p6PublicDelivery(authorityBytes,
            authority.datasetVersion)
        @Expect(selectCkbAuthorityDeliveryMode(bundled).diagnostic, "bundled")
        @Expect(selectCkbAuthorityDeliveryMode(publicRebuild).diagnostic,
            "public_rebuild")
        let bundledResult = buildCkbReproAuthorityBundle(bundled,
            bundle.path, authorityBytes, "/tmp/ckb-p6/bundled",
            "/tmp/ckb-store", "/tmp/ckb-student", policy: bundle.policy)
        let publicResult = buildCkbReproAuthorityFromPublicSource(publicRebuild,
            authorityBytes, "/tmp/ckb-p6/public", "/tmp/ckb-store",
            "/tmp/ckb-student")
        @Expect(bundledResult.ok, true)
        @Expect(publicResult.diagnostic,
            "authority_public_rebuild_not_executable")
        @Expect(bundledResult.presentCount, 164)
        @Expect(ckbReproProbeAuthorityDelivery(
            renderCkbAuthorityDeliveryManifest(bundled).toArray(),
            authorityBytes, bundle.path, policy: bundle.policy), "ok")
        @Expect(ckbAuthorityDeliveryReadyForExecution(publicRebuild), false)
        let publicAgain = parseCkbAuthorityDeliveryManifest(
            renderCkbAuthorityDeliveryManifest(publicRebuild).toArray())
        @Expect(publicAgain[0].ok, true)
        @Expect(renderCkbAuthorityDeliveryManifest(publicAgain[1]),
            renderCkbAuthorityDeliveryManifest(publicRebuild))
    }

    @TestCase
    public func p6Ut02AuthorityBundleSealAndVerifyCliAreDeterministic(): Unit {
        let root = Path("target/p6-authority-cli")
        if (exists(root)) { remove(root, recursive: true) }
        Directory.create(root, recursive: true)
        let canonical = canonicalize(root).toString()
        let authority = p6SyntheticAuthorityBytes()
        let parsed = parseCangjieHumanEvalAuthorityManifest(
            String.fromUtf8(authority))
        let fixture = p6AuthorityBundleFixture(authority,
            parsed.datasetVersion, "cli-materials")
        let authorityPath = "${canonical}/authority-中文🙂.jsonl"
        let sourceLockPath = "${canonical}/source-lock.json"
        let releaseAssetPath = "${canonical}/HumanEvalPlus.jsonl.gz"
        let releaseLicensePath = "${canonical}/release-LICENSE"
        let evaluatorLicensePath = "${canonical}/evaluator-LICENSE"
        File.writeTo(Path(authorityPath), authority)
        File.writeTo(Path(sourceLockPath), fixture.sourceLock)
        File.writeTo(Path(releaseAssetPath), fixture.releaseAsset)
        File.writeTo(Path(releaseLicensePath), fixture.releaseLicense)
        File.writeTo(Path(evaluatorLicensePath), fixture.evaluatorLicense)

        let archiveA = "${canonical}/direct-a.tar.zst"
        let archiveB = "${canonical}/direct-b.tar.zst"
        let sealedA = sealCkbExecutionAuthorityDelivery(authority,
            fixture.sourceLock, fixture.releaseAsset, fixture.releaseLicense,
            fixture.evaluatorLicense, archiveA, policy: fixture.policy)
        let sealedB = sealCkbExecutionAuthorityDelivery(authority,
            fixture.sourceLock, fixture.releaseAsset, fixture.releaseLicense,
            fixture.evaluatorLicense, archiveB, policy: fixture.policy)
        @Expect(sealedA.ok, true)
        @Expect(sealedB.ok, true)
        @Expect(File.readFrom(Path(archiveA)), File.readFrom(Path(archiveB)))
        @Expect(sealedA.canonicalJson, sealedB.canonicalJson)

        let conflictArchive = "${canonical}/direct-conflict.tar.zst"
        let conflictId = benchmarkGapSha256(
            conflictArchive + fixture.policy.authorityHash).replace(
                "sha256:", "")
        let conflictRoot = Path(
            "${conflictArchive}.seal-${conflictId}.tmp")
        Directory.create(conflictRoot, recursive: false)
        let conflict = sealCkbExecutionAuthorityDelivery(authority,
            fixture.sourceLock, fixture.releaseAsset, fixture.releaseLicense,
            fixture.evaluatorLicense, conflictArchive,
            policy: fixture.policy)
        @Expect(conflict.diagnostic, "authority_bundle_temporary_conflict")
        @Expect(exists(Path(conflictArchive)), false)
        remove(conflictRoot, recursive: true)
        let partialArchive = "${canonical}/direct-partial.tar.zst"
        let partial = sealCkbExecutionAuthorityDelivery(authority,
            fixture.sourceLock, fixture.releaseAsset, fixture.releaseLicense,
            fixture.evaluatorLicense, partialArchive,
            policy: fixture.policy,
            backend: P6PartialAuthorityArchiveBackend())
        @Expect(partial.diagnostic, "authority_bundle_create_failed")
        @Expect(exists(Path(partialArchive)), false)
        let partialId = benchmarkGapSha256(
            partialArchive + fixture.policy.authorityHash).replace(
                "sha256:", "")
        @Expect(exists(Path(
            "${partialArchive}.seal-${partialId}.tmp")), false)

        let cleanupRoot = Path("${canonical}/cleanup-owned")
        Directory.create(cleanupRoot, recursive: false)
        File.writeTo(cleanupRoot.join("bundle.tmp"), "owned".toArray())
        let cleanupIdentity = ckbReproDirectoryOwnershipIdentity(
            cleanupRoot.toString())
        let movedCleanupRoot = Path("${canonical}/cleanup-owned-moved")
        rename(cleanupRoot.toString(), to: movedCleanupRoot.toString(),
            overwrite: false)
        Directory.create(cleanupRoot, recursive: false)
        File.writeTo(cleanupRoot.join("sentinel.txt"),
            "replacement 中文🙂".toArray())
        @Expect(ckbReproCleanupOwnedDirectory(cleanupRoot.toString(),
            cleanupIdentity, ["bundle.tmp"]), false)
        @Expect(exists(cleanupRoot.join("sentinel.txt")), true)
        @Expect(exists(movedCleanupRoot.join("bundle.tmp")), true)
        remove(cleanupRoot, recursive: true)
        remove(movedCleanupRoot, recursive: true)

        let finalRaceRoot = Path("${canonical}/cleanup-final-race")
        Directory.create(finalRaceRoot, recursive: false)
        File.writeTo(finalRaceRoot.join("bundle.tmp"), "owned".toArray())
        let finalRaceIdentity = ckbReproDirectoryOwnershipIdentity(
            finalRaceRoot.toString())
        let finalRaceMoved = Path("${canonical}/cleanup-final-race-moved")
        let replacement = "replacement 中文🙂".toArray()
        @Expect(ckbReproCleanupOwnedDirectory(finalRaceRoot.toString(),
            finalRaceIdentity, ["bundle.tmp"],
            beforeFinalDirectoryUnlink: { =>
                rename(finalRaceRoot.toString(),
                    to: finalRaceMoved.toString(), overwrite: false)
                File.writeTo(finalRaceRoot, replacement)
            }), false)
        @Expect(File.readFrom(finalRaceRoot), replacement)
        @Expect(exists(finalRaceMoved), true)
        remove(finalRaceRoot)
        remove(finalRaceMoved, recursive: true)

        let finalDirectoryRoot = Path("${canonical}/cleanup-final-directory")
        Directory.create(finalDirectoryRoot, recursive: false)
        File.writeTo(finalDirectoryRoot.join("bundle.tmp"), "owned".toArray())
        let finalDirectoryIdentity = ckbReproDirectoryOwnershipIdentity(
            finalDirectoryRoot.toString())
        let finalDirectoryMoved = Path(
            "${canonical}/cleanup-final-directory-moved")
        @Expect(ckbReproCleanupOwnedDirectory(finalDirectoryRoot.toString(),
            finalDirectoryIdentity, ["bundle.tmp"],
            beforeFinalDirectoryUnlink: { =>
                rename(finalDirectoryRoot.toString(),
                    to: finalDirectoryMoved.toString(), overwrite: false)
                Directory.create(finalDirectoryRoot, recursive: false)
                File.writeTo(finalDirectoryRoot.join("sentinel.txt"),
                    replacement)
            }), false)
        @Expect(File.readFrom(finalDirectoryRoot.join("sentinel.txt")),
            replacement)
        remove(finalDirectoryRoot, recursive: true)
        remove(finalDirectoryMoved, recursive: true)

        let finalLinkRoot = Path("${canonical}/cleanup-final-link")
        Directory.create(finalLinkRoot, recursive: false)
        File.writeTo(finalLinkRoot.join("bundle.tmp"), "owned".toArray())
        let finalLinkIdentity = ckbReproDirectoryOwnershipIdentity(
            finalLinkRoot.toString())
        let finalLinkMoved = Path("${canonical}/cleanup-final-link-moved")
        @Expect(ckbReproCleanupOwnedDirectory(finalLinkRoot.toString(),
            finalLinkIdentity, ["bundle.tmp"],
            beforeFinalDirectoryUnlink: { =>
                rename(finalLinkRoot.toString(),
                    to: finalLinkMoved.toString(), overwrite: false)
                _ = launch("/bin/ln", ["-s", finalLinkMoved.toString(),
                    finalLinkRoot.toString()]).wait()
            }), false)
        @Expect(exists(finalLinkRoot), true)
        remove(finalLinkRoot)
        remove(finalLinkMoved, recursive: true)

        let outputRoot = "${canonical}/delivery"
        let sealArgs = ["ckb-authority-bundle", "seal", "--authority",
            authorityPath, "--source-lock", sourceLockPath, "--release-asset",
            releaseAssetPath, "--release-license", releaseLicensePath,
            "--evaluator-license", evaluatorLicensePath, "--output-root",
            outputRoot]
        let sealed = runCkbAuthorityBundleCli(sealArgs,
            policy: fixture.policy)
        @Expect(sealed.exitCode, 0)
        @Expect(sealed.output.contains("authority bundle: sealed"), true)
        @Expect(sealed.output.contains("{\""), false)
        @Expect(exists(Path(outputRoot).join("authority-delivery.json")), true)
        @Expect(exists(Path(outputRoot).join(
            "cangjie-humaneval-authority.tar.zst")), true)
        @Expect(runCkbAuthorityBundleCli(sealArgs,
            policy: fixture.policy).diagnostic,
            "authority_bundle_output_invalid")

        let verified = runCkbAuthorityBundleCli([
            "ckb-authority-bundle", "verify", "--authority", authorityPath,
            "--delivery-root", outputRoot, "--json"], policy: fixture.policy)
        @Expect(verified.exitCode, 0)
        @Expect(JsonValue.fromStr(verified.output).asObject().get("ok")
            .getOrThrow().asBool().getValue(), true)
        @Expect(verified.output.contains("\"presentCount\":164"), true)

        let extra = Path(outputRoot).join("unexpected.txt")
        File.writeTo(extra, "unexpected 中文🙂".toArray())
        @Expect(runCkbAuthorityBundleCli([
            "ckb-authority-bundle", "verify", "--authority", authorityPath,
            "--delivery-root", outputRoot], policy: fixture.policy).diagnostic,
            "authority_bundle_layout_invalid")
        remove(extra)
        let archiveOutput = Path(outputRoot).join(
            "cangjie-humaneval-authority.tar.zst")
        let archiveBytes = File.readFrom(archiveOutput)
        File.writeTo(archiveOutput, "tampered".toArray())
        @Expect(runCkbAuthorityBundleCli([
            "ckb-authority-bundle", "verify", "--authority", authorityPath,
            "--delivery-root", outputRoot], policy: fixture.policy).exitCode, 1)
        File.writeTo(archiveOutput, archiveBytes)
        remove(archiveOutput)
        @Expect(launch("/bin/ln", ["-s", authorityPath,
            archiveOutput.toString()]).wait(), 0)
        @Expect(runCkbAuthorityBundleCli([
            "ckb-authority-bundle", "verify", "--authority", authorityPath,
            "--delivery-root", outputRoot], policy: fixture.policy).diagnostic,
            "authority_bundle_layout_invalid")
        remove(archiveOutput)
        File.writeTo(archiveOutput, archiveBytes)
        let deliveryLink = "${canonical}/delivery-root-link"
        @Expect(launch("/bin/ln", ["-s", outputRoot, deliveryLink]).wait(), 0)
        @Expect(runCkbAuthorityBundleCli([
            "ckb-authority-bundle", "verify", "--authority", authorityPath,
            "--delivery-root", deliveryLink], policy: fixture.policy).diagnostic,
            "authority_bundle_input_invalid")
        let failedJson = runCkbAuthorityBundleCli([
            "ckb-authority-bundle", "verify", "--authority", authorityPath,
            "--delivery-root", deliveryLink, "--json"], policy: fixture.policy)
        @Expect(JsonValue.fromStr(failedJson.output).asObject().get("ok")
            .getOrThrow().asBool().getValue(), false)

        @Expect(parseCkbAuthorityBundleCliArgs([
            "ckb-authority-bundle", "public_rebuild"]).diagnostic,
            "authority_bundle_action_invalid")
        @Expect(parseCkbAuthorityBundleCliArgs([
            "ckb-authority-bundle", "verify", "--authority", authorityPath,
            "--delivery-root", outputRoot, "--json", "--json"]).diagnostic,
            "duplicate_argument:--json")
        @Expect(parseCkbAuthorityBundleCliArgs([
            "ckb-authority-bundle", "verify", "--authority", "relative",
            "--delivery-root", outputRoot]).diagnostic,
            "authority_bundle_path_invalid")
        let oversized = StringBuilder()
        for (_ in 0..4097) { oversized.append("界") }
        @Expect(parseCkbAuthorityBundleCliArgs([
            "ckb-authority-bundle", "verify", "--authority",
            oversized.toString(), "--delivery-root", outputRoot]).diagnostic,
            "cli_argument_too_long")

        let symlink = "${canonical}/authority-link.jsonl"
        @Expect(launch("/bin/ln", ["-s", authorityPath, symlink]).wait(), 0)
        let linkedArgs = sealArgs.clone()
        linkedArgs[3] = symlink
        linkedArgs[13] = "${canonical}/delivery-link"
        @Expect(runCkbAuthorityBundleCli(linkedArgs,
            policy: fixture.policy).diagnostic,
            "authority_bundle_input_read_failed")
        let fifo = "${canonical}/authority.fifo"
        @Expect(launch("/usr/bin/mkfifo", [fifo]).wait(), 0)
        let fifoArgs = sealArgs.clone()
        fifoArgs[3] = fifo
        fifoArgs[13] = "${canonical}/delivery-fifo"
        @Expect(runCkbAuthorityBundleCli(fifoArgs,
            policy: fixture.policy).diagnostic,
            "authority_bundle_input_read_failed")

        File.writeTo(Path(outputRoot).join("authority-delivery.json"),
            [UInt8(0xff)])
        let rejected = runCkbAuthorityBundleCli([
            "ckb-authority-bundle", "verify", "--authority", authorityPath,
            "--delivery-root", outputRoot], policy: fixture.policy)
        @Expect(rejected.exitCode, 1)
        @Expect(rejected.output.contains("authority bundle: blocked"), true)
        remove(root, recursive: true)
    }

    @TestCase
    public func p6Ut02SingleCommitPreflightAcceptsOnlyMatchingCleanCandidate(): Unit {
        let root = Path("target/p6-single-commit-preflight")
        if (exists(root)) { remove(root, recursive: true) }
        Directory.create(root, recursive: true)
        let canonical = canonicalize(root).toString()
        let lockPath = "${canonical}/environment-lock.json"
        let preflightPath = "${canonical}/certification-preflight.json"
        let runManifestPath = "${canonical}/certification-run-manifest.json"
        let commit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        let expected = p6FrozenEnvironment()
        expected.attestationAuthorityHash = ""
        File.writeTo(Path(lockPath),
            renderCkbReproEnvironmentLock(expected).toArray())
        let seal = p6CertificationSeal()
        File.writeTo(Path(preflightPath), seal[0].toArray())
        File.writeTo(Path(runManifestPath), seal[1].toArray())

        let observed = p6FrozenEnvironment()
        observed.attestationAuthorityHash = ""
        let matching = CkbReproEnvironmentProbeResult()
        matching.ok = true
        matching.observed = observed
        matching.attestedInputHash =
            ckbReproObservedEnvironmentProjectionHash(observed)
        matching.attestationEvidenceCommit = commit
        let accepted = runCkbReproSingleCommitPreflight(lockPath,
            preflightPath, runManifestPath, canonical, commit, "4GB",
            probe: P6FakeEnvironmentProbe(matching))
        @Expect(accepted.ok, true)
        @Expect(accepted.startAllowed, true)
        @Expect(accepted.attestationEvidenceCommit, commit)

        matching.attestationEvidenceCommit =
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        @Expect(runCkbReproSingleCommitPreflight(lockPath, preflightPath,
            runManifestPath, canonical, commit, "4GB",
            probe: P6FakeEnvironmentProbe(matching)).diagnostic,
            "git_candidate_checkout_mismatch")
        @Expect(runCkbReproSingleCommitPreflight(lockPath, preflightPath,
            runManifestPath, canonical, "not-a-commit", "4GB",
            probe: P6FakeEnvironmentProbe(matching)).diagnostic,
            "git_run_candidate_invalid")
        remove(root, recursive: true)
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
        let publicHttpProvider = p6FrozenEnvironment()
        publicHttpProvider.glmBaseUrl = "http://113.46.219.251:8080/"
        @Expect(validateCkbReproEnvironmentLock(publicHttpProvider,
            mode: "execution").ok, true)
        let localProvider = p6FrozenEnvironment()
        localProvider.glmBaseUrl = "https://127.0.0.1/v1"
        @Expect(validateCkbReproEnvironmentLock(localProvider,
            mode: "execution").diagnostic,
            "environment_provider_identity_invalid")
        let unsupportedProviderScheme = p6FrozenEnvironment()
        unsupportedProviderScheme.glmBaseUrl = "ftp://provider.example/v1"
        @Expect(validateCkbReproEnvironmentLock(unsupportedProviderScheme,
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
    public func p6Pos01TypedIdentityBuildsExplicitTwoPhaseRunnerArguments(): Unit {
        let lock = p6FrozenEnvironment()
        let reference = parseCkbReproReferenceManifest(
            p6Read("../reproducibility/manifests/reference-run.json"))[1]
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
        @Expect(parsed.generationProtocol, "completion-only-v1")
        @Expect(parsed.samplesPerCase, 1)
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
        @Expect(runner.count, 2)
        @Expect(runner.history[0].contains("--generate-only"), true)
        @Expect(runner.history[0].contains("--evaluate-frozen"), false)
        @Expect(runner.history[1].contains("--evaluate-frozen"), true)
        @Expect(runner.history[1].contains("base,plus"), true)
        @Expect(runner.evaluatedSeal,
            "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        let generationFailure = P6FakeRunner()
        generationFailure.failAtCall = 1
        @Expect(runCkbReproCertifiedStudent(reference, lock, inputs,
            preflight, generationFailure), 1)
        @Expect(generationFailure.count, 1)
        let evaluationFailure = P6FakeRunner()
        evaluationFailure.failAtCall = 2
        @Expect(runCkbReproCertifiedStudent(reference, lock, inputs,
            preflight, evaluationFailure), 1)
        @Expect(evaluationFailure.count, 2)
        let invalidSeal = P6FakeRunner()
        invalidSeal.generationSeal = ""
        @Expect(runCkbReproCertifiedStudent(reference, lock, inputs,
            preflight, invalidSeal), 1)
        @Expect(invalidSeal.count, 1)

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
        @Expect(ckbAuthorityDeliveryReadyForExecution(blocked), false)
        @Expect(ckbReproProbeAuthorityDelivery(
            renderCkbAuthorityDeliveryManifest(blocked).toArray(),
            Array<UInt8>(), ""), "environment_probe_authority_invalid")
        @Expect(validateCkbReproAuthorityDelivery(blocked, "",
            Array<UInt8>(), "", "/tmp/ckb-output", "/tmp/ckb-store",
            "/tmp/ckb-student").diagnostic,
            "authority_delivery_blocked")

        let authorityBytes = p6SyntheticAuthorityBytes()
        let parsedAuthority = parseCangjieHumanEvalAuthorityManifest(
            String.fromUtf8(authorityBytes))
        let bundle = p6AuthorityBundleFixture(authorityBytes,
            parsedAuthority.datasetVersion, "negative-positive")
        let publicRebuild = p6PublicDelivery(authorityBytes,
            parsedAuthority.datasetVersion)
        @Expect(validateCkbExecutionAuthorityDelivery(
            renderCkbAuthorityDeliveryManifest(publicRebuild).toArray(),
            authorityBytes, bundle.path, policy: bundle.policy).diagnostic,
            "authority_public_rebuild_not_executable")
        @Expect(ckbReproProbeAuthorityDelivery(
            renderCkbAuthorityDeliveryManifest(publicRebuild).toArray(),
            authorityBytes, bundle.path, policy: bundle.policy),
            "environment_probe_authority_invalid")
        for (output in ["/tmp/ckb-store", "/tmp/ckb-store/authority",
            "/tmp/ckb-student/authority", "/tmp"]) {
            @Expect(validateCkbReproAuthorityDelivery(bundle.manifest,
                bundle.path, authorityBytes, parsedAuthority.datasetVersion,
                output, "/tmp/ckb-store", "/tmp/ckb-student",
                policy: bundle.policy).diagnostic,
                "authority_output_root_forbidden")
        }
        for (output in ["target/output", "/tmp/../tmp/output",
            "/tmp//output", "/tmp\\output", " /tmp/output"]) {
            @Expect(validateCkbReproAuthorityDelivery(bundle.manifest,
                bundle.path, authorityBytes, parsedAuthority.datasetVersion,
                output, "/tmp/ckb-store", "/tmp/ckb-student",
                policy: bundle.policy).diagnostic,
                "authority_output_root_invalid")
        }
        let ambiguous = bundle.manifest
        ambiguous.anonymousPublicAccess = true
        @Expect(selectCkbAuthorityDeliveryMode(ambiguous).diagnostic,
            "authority_delivery_mode_ambiguous")
        let expectedTamperDiagnostics = [
            ("release-license", "authority_license_bytes_mismatch"),
            ("evaluator-license", "authority_license_bytes_mismatch"),
            ("license-swap", "authority_license_bytes_mismatch"),
            ("empty-license", "authority_bundle_layout_invalid"),
            ("source-lock", "authority_bundle_source_lock_mismatch"),
            ("license-evidence", "authority_license_evidence_invalid"),
            ("invalid-evidence-utf8", "invalid_response_encoding"),
            ("index", "authority_bundle_manifest_invalid"),
            ("invalid-index-utf8", "invalid_response_encoding"),
            ("oversized-index", "authority_bundle_layout_invalid"),
            ("authority", "authority_bundle_authority_mismatch"),
            ("extra", "authority_bundle_layout_invalid")
        ]
        for (entry in expectedTamperDiagnostics) {
            let altered = p6AuthorityBundleFixture(authorityBytes,
                parsedAuthority.datasetVersion, entry[0])
            @Expect(validateCkbExecutionAuthorityDelivery(
                renderCkbAuthorityDeliveryManifest(altered.manifest).toArray(),
                authorityBytes, altered.path, policy: altered.policy).diagnostic,
                entry[1])
            @Expect(ckbReproProbeAuthorityDelivery(
                renderCkbAuthorityDeliveryManifest(altered.manifest).toArray(),
                authorityBytes, altered.path, policy: altered.policy),
                "environment_probe_authority_invalid")
        }
        for (missing in ["missing-index", "missing-source-lock",
            "missing-authority", "missing-license-evidence",
            "missing-release-license", "missing-evaluator-license"]) {
            let altered = p6AuthorityBundleFixture(authorityBytes,
                parsedAuthority.datasetVersion, missing)
            @Expect(validateCkbExecutionAuthorityDelivery(
                renderCkbAuthorityDeliveryManifest(altered.manifest).toArray(),
                authorityBytes, altered.path, policy: altered.policy).diagnostic,
                "authority_bundle_layout_invalid")
        }
        let wrongBundleHash = p6AuthorityBundleFixture(authorityBytes,
            parsedAuthority.datasetVersion, "wrong-bundle-hash")
        wrongBundleHash.manifest.bundleHash = p6Hash("wrong-bundle")
        @Expect(validateCkbExecutionAuthorityDelivery(
            renderCkbAuthorityDeliveryManifest(
                wrongBundleHash.manifest).toArray(), authorityBytes,
            wrongBundleHash.path, policy: wrongBundleHash.policy).diagnostic,
            "authority_bundle_hash_mismatch")
        let wrongPolicy = p6AuthorityBundleFixture(authorityBytes,
            parsedAuthority.datasetVersion, "wrong-policy")
        wrongPolicy.policy.releaseCommit =
            "cccccccccccccccccccccccccccccccccccccccc"
        @Expect(validateCkbExecutionAuthorityDelivery(
            renderCkbAuthorityDeliveryManifest(wrongPolicy.manifest).toArray(),
            authorityBytes, wrongPolicy.path,
            policy: wrongPolicy.policy).diagnostic,
            "authority_license_evidence_invalid")
        let wrongAuthorityPolicy = p6AuthorityBundleFixture(authorityBytes,
            parsedAuthority.datasetVersion, "wrong-authority-policy")
        wrongAuthorityPolicy.policy.authorityHash = p6Hash("other-authority")
        @Expect(validateCkbExecutionAuthorityDelivery(
            renderCkbAuthorityDeliveryManifest(
                wrongAuthorityPolicy.manifest).toArray(), authorityBytes,
            wrongAuthorityPolicy.path,
            policy: wrongAuthorityPolicy.policy).diagnostic,
            "authority_trust_policy_mismatch")
        let invalidBytes = [UInt8(0xff)]
        let invalid = p6AuthorityBundleFixture(invalidBytes,
            parsedAuthority.datasetVersion, "invalid-utf8")
        @Expect(validateCkbExecutionAuthorityDelivery(
            renderCkbAuthorityDeliveryManifest(invalid.manifest).toArray(),
            invalidBytes, invalid.path, policy: invalid.policy).diagnostic,
            "invalid_response_encoding")
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
        let production = String.fromUtf8(File.readFrom(Path(
            "../src/ckb_repro_environment.cj")))
        @Expect(production.contains(
            "\"CKB_REPRO_COMPOSITION_MANIFEST\", \"\""), true)
        @Expect(production.contains("Path(repositoryRoot).join(\n" +
            "        target.compositionManifestPath)"), false)
        @Expect(p6MirrorEquivalent("../src/ckb_repro_authority_bundle.cj",
            "src/ckb_repro_authority_bundle.cj"), true)
        let manifest = parseCangjieHumanEvalAuthorityManifest(String.fromUtf8(
            p6SyntheticAuthorityBytes()))
        @Expect(manifest.ok, true)
        @Expect(manifest.rows.size, 164)
        let originalPlusHash = manifest.rows[0].plusTestsHash
        @Expect(originalPlusHash.startsWith("sha256:"), true)
        let plusTest = Path("target/p6-synthetic-authority/CJ-HUMANEVAL-000/tests-plus/TestMain.cj")
        File.writeTo(plusTest, "package fixture_plus_test\n// drifted synthetic verifier fixture 0\n".toArray())
        let drifted = buildCangjieHumanEvalManifest(
            "target/p6-synthetic-authority", "")
        @Expect(drifted.ok, true)
        @Expect(drifted.rows[0].plusTestsHash == originalPlusHash, false)
        @Expect(validateCangjieHumanEvalManifest(manifest,
            "target/p6-synthetic-authority").ok, false)
        p6WriteSyntheticPlusFixture(
            Path("target/p6-synthetic-authority/CJ-HUMANEVAL-000"), 0)
        let restored = buildCangjieHumanEvalManifest(
            "target/p6-synthetic-authority", "")
        @Expect(restored.ok, true)
        @Expect(restored.rows[0].plusTestsHash, originalPlusHash)
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
        "cangjie-humaneval-164-sha256:72aa7564b350583eff660722aa54487334079b2c92207d3906898953f72f90f6"
    lock.authorityDeliveryHash = p6Hash("authority-delivery")
    lock.attestationAuthorityManifestPath =
        "reproducibility/manifests/environment-attestation-authority.json"
    lock.attestationAuthorityHash = p6Hash("attestation-authority")
    lock
}

private class P6AuthorityBundleFixture {
    public var manifest: CkbAuthorityDeliveryManifest =
        CkbAuthorityDeliveryManifest()
    public var policy: CkbAuthorityTrustPolicy = CkbAuthorityTrustPolicy()
    public var path: String = ""
    public var releaseLicense: Array<UInt8> = Array<UInt8>()
    public var evaluatorLicense: Array<UInt8> = Array<UInt8>()
    public var sourceLock: Array<UInt8> = Array<UInt8>()
    public var releaseAsset: Array<UInt8> = Array<UInt8>()
    public init() {}
}

private func p6AuthorityBundleFixture(authority: Array<UInt8>,
    datasetVersion: String, suffix: String): P6AuthorityBundleFixture {
    let fixture = P6AuthorityBundleFixture()
    let policy = CkbAuthorityTrustPolicy()
    let releaseLicense = "fixture release LICENSE 中文🔒".toArray()
    let evaluatorLicense = "fixture evaluator LICENSE".toArray()
    let sourceLock = "fixture-source-lock".toArray()
    policy.releaseRepository = "https://example.test/release"
    policy.releaseCommit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    policy.releaseTree = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    policy.releaseLicenseSize = releaseLicense.size
    policy.releaseLicenseHash = ckbReproBundleHash(releaseLicense)
    policy.evaluatorRepository = "https://example.test/evaluator"
    policy.evaluatorCommit = "cccccccccccccccccccccccccccccccccccccccc"
    policy.evaluatorTree = "dddddddddddddddddddddddddddddddddddddddd"
    policy.evaluatorLicenseSize = evaluatorLicense.size
    policy.evaluatorLicenseHash = ckbReproBundleHash(evaluatorLicense)
    policy.releaseLicenseId = "fixture-release-license"
    policy.evaluatorLicenseId = "fixture-evaluator-license"
    policy.deliveryLicenseId = "fixture-delivery-license"
    policy.releaseAssetHash = p6Hash("fixture-release-asset")
    policy.sourceLockHash = ckbReproBundleHash(sourceLock)
    policy.authorityHash = ckbReproBundleHash(authority)
    policy.datasetVersion = datasetVersion

    var licenseEvidence =
        "{\"schemaVersion\":\"ckb-authority-license-evidence-v1\",\"licenses\":[" +
        "{\"role\":\"humanevalplus-release\",\"bundlePath\":\"licenses/humanevalplus-release-LICENSE\",\"repository\":\"${policy.releaseRepository}\",\"commit\":\"${policy.releaseCommit}\",\"tree\":\"${policy.releaseTree}\",\"sourcePath\":\"LICENSE\",\"size\":${policy.releaseLicenseSize},\"sha256\":\"${policy.releaseLicenseHash}\",\"licenseId\":\"${policy.releaseLicenseId}\"}," +
        "{\"role\":\"evalplus-evaluator\",\"bundlePath\":\"licenses/evalplus-evaluator-LICENSE\",\"repository\":\"${policy.evaluatorRepository}\",\"commit\":\"${policy.evaluatorCommit}\",\"tree\":\"${policy.evaluatorTree}\",\"sourcePath\":\"LICENSE\",\"size\":${policy.evaluatorLicenseSize},\"sha256\":\"${policy.evaluatorLicenseHash}\",\"licenseId\":\"${policy.evaluatorLicenseId}\"}]}"
    if (suffix == "license-evidence") {
        licenseEvidence = licenseEvidence.replace(
            "\"fixture-release-license\"", "\"wrong-license\"")
    }
    let authorityHash = ckbReproBundleHash(authority)
    let licenseEvidenceBytes = if (suffix == "invalid-evidence-utf8") {
        [UInt8(0xff)]
    } else { licenseEvidence.toArray() }
    let licenseEvidenceHash = ckbReproBundleHash(licenseEvidenceBytes)
    var index =
        "{\"schemaVersion\":\"ckb-authority-bundle-manifest-v1\"," +
        "\"datasetVersion\":\"${datasetVersion}\"," +
        "\"authorityPath\":\"authority/cangjie_humaneval_manifest.jsonl\"," +
        "\"authorityHash\":\"${authorityHash}\"," +
        "\"licenseEvidencePath\":\"licenses/LICENSE-EVIDENCE.json\"," +
        "\"licenseEvidenceHash\":\"${licenseEvidenceHash}\"," +
        "\"sourceLockPath\":\"authority/HumanEvalPlus-v0.1.10/source-lock.json\"," +
        "\"sourceLockHash\":\"${policy.sourceLockHash}\"," +
        "\"releaseAssetHash\":\"${policy.releaseAssetHash}\"," +
        "\"evaluatorCommit\":\"${policy.evaluatorCommit}\"}"
    if (suffix == "index") {
        index = index.replace("ckb-authority-bundle-manifest-v1",
            "ckb-authority-bundle-manifest-v0")
    }

    let payloads = ArrayList<CkbReleaseArchivePayload>()
    if (suffix != "missing-index") {
        p6AuthorityPayload(payloads, "AUTHORITY-BUNDLE-MANIFEST.json",
            if (suffix == "invalid-index-utf8") { [UInt8(0xff)] }
            else if (suffix == "oversized-index") {
                Array<UInt8>(1024 * 1024 + 1, repeat: UInt8(1))
            } else { index.toArray() })
    }
    if (suffix != "missing-source-lock") {
        p6AuthorityPayload(payloads,
            "authority/HumanEvalPlus-v0.1.10/source-lock.json",
            if (suffix == "source-lock") {
                "tampered-source-lock".toArray()
            } else { sourceLock })
    }
    if (suffix != "missing-authority") {
        p6AuthorityPayload(payloads,
            "authority/cangjie_humaneval_manifest.jsonl",
            if (suffix == "authority") {
                "tampered-authority".toArray()
            } else { authority })
    }
    if (suffix != "missing-license-evidence") {
        p6AuthorityPayload(payloads, "licenses/LICENSE-EVIDENCE.json",
            licenseEvidenceBytes)
    }
    if (suffix != "missing-evaluator-license") {
        p6AuthorityPayload(payloads, "licenses/evalplus-evaluator-LICENSE",
            if (suffix == "evaluator-license") {
                "tampered evaluator".toArray()
            } else if (suffix == "license-swap") { releaseLicense }
            else { evaluatorLicense })
    }
    if (suffix != "missing-release-license") {
        p6AuthorityPayload(payloads,
            "licenses/humanevalplus-release-LICENSE",
            if (suffix == "release-license") {
                "篡改🔒".toArray()
            } else if (suffix == "empty-license") {
                Array<UInt8>()
            } else if (suffix == "license-swap") { evaluatorLicense }
            else { releaseLicense })
    }
    if (suffix == "extra") {
        p6AuthorityPayload(payloads, "unexpected.txt", "unexpected".toArray())
    }

    let root = Path("target/p6-authority-bundles")
    if (!exists(root)) { Directory.create(root, recursive: true) }
    let archivePath = root.join("${suffix}.tar.zst")
    if (exists(archivePath)) { remove(archivePath, recursive: true) }
    let backend = CkbPortableReleaseArchiveBackend()
    backend.create(archivePath.toString(), payloads)

    let manifest = CkbAuthorityDeliveryManifest()
    manifest.schemaVersion = "ckb-authority-delivery-v1"
    manifest.mode = "bundled"
    manifest.licenseId = policy.deliveryLicenseId
    manifest.licenseEvidenceHash = licenseEvidenceHash
    manifest.redistributionAllowed = true
    manifest.bundleHash = backend.archiveHash(archivePath.toString())
    manifest.authorityHash = authorityHash
    manifest.datasetVersion = datasetVersion
    fixture.manifest = manifest
    fixture.policy = policy
    fixture.path = archivePath.toString()
    fixture.releaseLicense = releaseLicense
    fixture.evaluatorLicense = evaluatorLicense
    fixture.sourceLock = sourceLock
    fixture.releaseAsset = "fixture-release-asset".toArray()
    fixture
}

private func p6AuthorityPayload(values: ArrayList<CkbReleaseArchivePayload>,
    path: String, bytes: Array<UInt8>): Unit {
    let payload = CkbReleaseArchivePayload()
    payload.path = path
    payload.bytes = bytes
    values.add(payload)
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
    let skillBundle = p6Hash("skill-bundle")
    let sampling = p6Hash("sampling-capability")
    let outputSchema = p6Hash("output-schema")
    let lineage = p6Hash("lineage")
    let preflight =
        "{\"ok\":true,\"startAllowed\":true,\"diagnostic\":\"ok\"," +
        "\"fingerprint\":\"${fingerprint}\"," +
        "\"providerIdentityHash\":\"${provider}\"," +
        "\"candidateChecksum\":\"${candidate}\"," +
        "\"studentLeakageProofHash\":\"${leakage}\"," +
        "\"frozenCandidateManifestHash\":\"${frozen}\"," +
        "\"skillBundleHash\":\"${skillBundle}\",\"skillCount\":1,\"contentBytes\":1," +
        "\"assetLineage\":\"independent\",\"lineageProofHash\":\"${lineage}\"," +
        "\"samplingCapabilityHash\":\"${sampling}\"," +
        "\"generationProtocol\":\"completion-only-v1\",\"samplesPerCase\":1," +
        "\"outputSchemaHash\":\"${outputSchema}\"," +
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
        p6SealPart(skillBundle) + p6SealPart(sampling) +
        p6SealPart("completion-only-v1") + p6SealPart("1") +
        p6SealPart(outputSchema) + p6SealPart("1") + p6SealPart("1") +
        p6SealPart("independent") + p6SealPart(lineage) +
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
        "\"skillBundleHash\":\"${skillBundle}\",\"skillCount\":1,\"contentBytes\":1," +
        "\"assetLineage\":\"independent\",\"lineageProofHash\":\"${lineage}\"," +
        "\"samplingCapabilityHash\":\"${sampling}\"," +
        "\"generationProtocol\":\"completion-only-v1\",\"samplesPerCase\":1," +
        "\"outputSchemaHash\":\"${outputSchema}\"," +
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
            Directory.create(caseRoot.join("tests-plus"), recursive: true)
            Directory.create(caseRoot.join("translation"), recursive: true)
            File.writeTo(caseRoot.join("prompt.md"),
                "Implement fixture_${i}; no benchmark case content.\n".toArray())
            File.writeTo(caseRoot.join("metadata.json"),
                "{\"targetVersion\":\"1.0.0\",\"signature\":\"public func fixture_${i}(): Int64\"}".toArray())
            File.writeTo(caseRoot.join("starter/solution.cj"),
                "package fixture\npublic func fixture_${i}(): Int64 { 0 }\n".toArray())
            File.writeTo(caseRoot.join("tests/TestMain.cj"),
                "package fixture_test\n// synthetic verifier fixture ${i}\n".toArray())
            p6WriteSyntheticPlusFixture(caseRoot, i)
            File.writeTo(caseRoot.join("translation/source.txt"),
                "synthetic-${i}\n".toArray())
        }
    }
    // Upgrade a cache created by an older fixture contract without replacing unrelated files.
    for (i in 0..164) {
        p6WriteSyntheticPlusFixture(root.join(p6CaseId(i)), i)
    }
    let manifest = buildCangjieHumanEvalManifest(root.toString(), "")
    if (!manifest.ok) { return Array<UInt8>() }
    cangjieHumanEvalRenderAuthorityManifest(manifest).toArray()
}

private func p6WriteSyntheticPlusFixture(caseRoot: Path, index: Int64): Unit {
    if (!exists(caseRoot.join("tests-plus"))) {
        Directory.create(caseRoot.join("tests-plus"), recursive: true)
    }
    File.writeTo(caseRoot.join("tests-plus/TestMain.cj"),
        "package fixture_plus_test\n// synthetic plus verifier fixture ${index}\n".toArray())
    File.writeTo(caseRoot.join("tests-plus/cjpm.executable.toml"),
        "[package]\nname = \"fixture_plus_${index}\"\noutput-type = \"executable\"\n".toArray())
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
